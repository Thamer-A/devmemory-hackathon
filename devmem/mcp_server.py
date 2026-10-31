"""DevMemory as an MCP server (stdio, JSON-RPC 2.0, stdlib only). Works with any MCP client:
Claude Code, Codex CLI, Cursor, Claude Desktop, VS Code, ...

  devmem mcp --project <dir>

Tools:
  get_context_pack(task, budget?)   the task-specific pack (requirements, origin sessions, files, STALE flags)
  list_sessions()                   captured sessions with freshness
  read_session(id)                  one session's prompt, outcome, files and edits
  begin_session()                   snapshot the project before working
  end_session(prompt, summary?)     record the diff since begin_session as a session; the summary is
                                    stored labelled as the assistant's own report
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from . import generic
from .pack import build_pack, freshness, load_sessions
from .scan import scan
from .store import store_path

PROTOCOLS = ("2025-06-18", "2025-03-26", "2024-11-05")

TOOLS = [
    {"name": "get_context_pack",
     "description": "Get DevMemory's compact, source-linked context for a coding task in this project: the user's "
                    "earlier requirements (verbatim), past sessions relevant to the task, the relevant files and lines, "
                    "and STALE warnings where code changed since a memory was recorded. Call this first, before "
                    "exploring the project.",
     "inputSchema": {"type": "object", "properties": {
         "task": {"type": "string", "description": "the user's request, verbatim"},
         "budget": {"type": "integer", "description": "token budget (default 1500)"}}, "required": ["task"]}},
    {"name": "list_sessions", "description": "List captured past sessions with their freshness status.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "read_session", "description": "Read one captured session (prompt, outcome, files, edits) by id prefix.",
     "inputSchema": {"type": "object", "properties": {"id": {"type": "string"}}, "required": ["id"]}},
    {"name": "begin_session", "description": "Start recording: snapshot the project before you make changes.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "end_session",
     "description": "Finish recording: DevMemory diffs the project against begin_session and stores the session, so "
                    "future sessions can retrieve it. Pass the user's request verbatim as prompt.",
     "inputSchema": {"type": "object", "properties": {
         "prompt": {"type": "string", "description": "the user's request, verbatim"},
         "summary": {"type": "string", "description": "short summary of what you did and decided"},
         "client": {"type": "string", "description": "name of the AI tool, e.g. codex, cursor"}},
         "required": ["prompt"]}},
]


class Server:
    def __init__(self, project: Path, store: Path | None = None):
        self.project = Path(project).resolve()
        self.store = Path(store or store_path(self.project))

    def call(self, name: str, args: dict) -> str:
        self.store.mkdir(parents=True, exist_ok=True)  # every call is logged: what the client asked memory for
        with open(self.store / "mcp_calls.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps({"ts": generic._now(), "tool": name, "args": args}, ensure_ascii=False) + "\n")
        if name == "get_context_pack":
            scan(self.project, self.store)
            text, info = build_pack(self.project, self.store, args["task"], budget=int(args.get("budget") or 1500))
            return text
        if name == "list_sessions":
            rows = []
            for s in load_sessions(self.store):
                fr = freshness(s, self.project)
                rows.append(f"{str(s.get('session_id'))[:8]}  {s.get('started_at', '')[:16]}  {s.get('provider', '')}  "
                            f"{fr['status']}  {(s.get('prompt') or '')[:100]!r}")
            return "\n".join(rows) or "no sessions captured yet"
        if name == "read_session":
            for s in load_sessions(self.store):
                if str(s.get("session_id", "")).startswith(args["id"]):
                    keep = {k: s.get(k) for k in ("session_id", "started_at", "provider", "capture_method", "prompt",
                                                  "result_text", "result_source", "files_edited")}
                    keep["freshness"] = freshness(s, self.project)
                    keep["edits"] = [{k: t.get(k) for k in ("tool", "file", "old", "new") if t.get(k)}
                                     for t in s.get("tool_calls", []) if t.get("tool") in ("Edit", "Write")][:20]
                    return json.dumps(keep, indent=1, ensure_ascii=False)
            return f"no session with id {args['id']!r}"
        if name == "begin_session":
            generic.begin(self.project, self.store)
            return "recording started"
        if name == "end_session":
            client = args.get("client") or "mcp-client"
            meta = generic.end(self.project, args["prompt"], provider=client, store=self.store,
                               summary=args.get("summary"),
                               summary_source="assistant self-report" if args.get("summary") else None)
            s = json.loads(meta.read_text(encoding="utf-8"))
            return f"recorded session {s['session_id'][:8]}: {len(s['files_edited'])} files changed"
        raise KeyError(name)

    def handle(self, msg: dict) -> dict | None:
        mid, method, params = msg.get("id"), msg.get("method"), msg.get("params") or {}
        if mid is None:  # notification
            return None
        if method == "initialize":
            ver = params.get("protocolVersion")
            res = {"protocolVersion": ver if ver in PROTOCOLS else PROTOCOLS[0],
                   "capabilities": {"tools": {}},
                   "serverInfo": {"name": "devmemory", "version": "0.1"},
                   "instructions": "Before working on a task in this project, call get_context_pack with the user's "
                                   "request. To remember your work for later sessions, call begin_session before "
                                   "editing and end_session when done."}
        elif method == "ping":
            res = {}
        elif method == "tools/list":
            res = {"tools": TOOLS}
        elif method == "tools/call":
            try:
                text = self.call(params.get("name"), params.get("arguments") or {})
                res = {"content": [{"type": "text", "text": text}], "isError": False}
            except KeyError as e:
                return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": f"unknown tool {e}"}}
            except Exception as e:  # tool errors go back to the model, not the transport
                res = {"content": [{"type": "text", "text": f"error: {e}"}], "isError": True}
        else:
            return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"method not found: {method}"}}
        return {"jsonrpc": "2.0", "id": mid, "result": res}


def serve(project: Path, store: Path | None = None) -> int:
    srv = Server(project, store)
    stdin = open(sys.stdin.fileno(), "r", encoding="utf-8", newline="\n", closefd=False)
    stdout = open(sys.stdout.fileno(), "w", encoding="utf-8", newline="\n", closefd=False)
    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            stdout.write(json.dumps({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}}) + "\n")
            stdout.flush()
            continue
        out = srv.handle(msg)
        if out is not None:
            stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
            stdout.flush()
    return 0

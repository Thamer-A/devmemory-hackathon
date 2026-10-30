"""Session capture: run (or import) a headless Claude Code session and store its record.

Record layout under <project>/.devmemory/sessions/:
  <stamp>_<sid8>.jsonl       raw stream-json, exactly as the CLI emitted it
  <stamp>_<sid8>.meta.json   deterministic digest: prompt, visible assistant text, tool calls,
                             touched files with content hashes at capture time, usage metrics
No LLM is called to build the digest. Hidden reasoning is never available or stored; only
the assistant-visible text that the CLI emits.
"""
from __future__ import annotations

import json
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from .claude_cli import FILE_EDIT_TOOLS, FILE_READ_TOOLS, parse_stream, run_claude, _rel
from .store import hash_files, store_path


def _digest(stream_path: Path, project: Path) -> dict:
    """Extract visible, source-linked facts from a stream-json record."""
    texts, tools, errors = [], [], []
    for i, line in enumerate(stream_path.read_text(encoding="utf-8", errors="replace").splitlines()):
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        if e.get("type") == "assistant":
            for b in e.get("message", {}).get("content", []) or []:
                if b.get("type") == "text" and b.get("text", "").strip():
                    texts.append({"line": i, "text": b["text"].strip()})
                elif b.get("type") == "tool_use":
                    inp = b.get("input") or {}
                    entry = {"line": i, "tool": b.get("name")}
                    if inp.get("file_path"):
                        entry["file"] = _rel(inp["file_path"], project)
                    if b.get("name") == "Bash":
                        entry["command"] = str(inp.get("command", ""))[:300]
                    if b.get("name") in ("Grep", "Glob"):
                        entry["pattern"] = str(inp.get("pattern", ""))[:200]
                    if b.get("name") == "Edit":
                        entry["old"] = str(inp.get("old_string", ""))[:400]
                        entry["new"] = str(inp.get("new_string", ""))[:400]
                    tools.append(entry)
        elif e.get("type") == "user" and isinstance(e.get("message", {}).get("content"), list):
            for b in e["message"]["content"]:
                if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("is_error"):
                    errors.append({"line": i, "error": str(b.get("content"))[:300]})
    return {"assistant_text": texts, "tool_calls": tools, "errors": errors}


def record_session(project: Path, stream_path: Path, prompt: str, started_at: str,
                   extra: dict | None = None, store: Path | None = None) -> Path:
    """Store a finished stream-json file as a session record and write its digest."""
    project = Path(project)
    metrics = parse_stream(stream_path, project)
    sid = (metrics.get("session_id") or "unknown")[:8]
    stamp = started_at.replace(":", "").replace("-", "")[:15]
    sessions = Path(store or store_path(project)) / "sessions"
    sessions.mkdir(parents=True, exist_ok=True)
    base = sessions / f"{stamp}_{sid}"
    raw_dest = base.with_suffix(".jsonl")
    if Path(stream_path).resolve() != raw_dest.resolve():
        shutil.copyfile(stream_path, raw_dest)
    touched = set(metrics["files_read"]) | set(metrics["files_edited"])
    touched = {t for t in touched if not t.startswith("/") and ":" not in t}
    meta = {
        "session_id": metrics.get("session_id"),
        "started_at": started_at,
        "provider": "claude-code",
        "capture_method": "stream-json",
        "model": metrics.get("model"),
        "prompt": prompt,
        "result_text": metrics.get("result_text"),
        "raw_record": raw_dest.name,
        "files_read": sorted(set(metrics["files_read"])),
        "files_edited": sorted(set(metrics["files_edited"])),
        "file_hashes_at_capture": hash_files(project, touched),
        "usage": {k: metrics.get(k) for k in ("input_tokens", "output_tokens", "cache_read_tokens",
                                               "cache_creation_tokens", "cost_usd_list", "num_turns",
                                               "duration_ms")},
        **_digest(raw_dest, project),
        **(extra or {}),
    }
    meta_path = base.with_suffix(".meta.json")
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")
    return meta_path


def run_and_capture(project: Path, prompt: str, model: str = "haiku", max_turns: int = 30,
                    isolated: bool = True, store: Path | None = None) -> Path:
    """Run a session in `project` and record it in `store` (default <project>/.devmemory)."""
    project = Path(project).resolve()
    started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    # Stream to a temp file outside the project so the agent never sees a half-written record.
    tmp = Path(tempfile.mkdtemp(prefix="devmem-cap-")) / "incoming.jsonl"
    run_claude(prompt, project, tmp, model=model, max_turns=max_turns, isolated=isolated)
    meta = record_session(project, tmp, prompt, started, store=store)
    shutil.rmtree(tmp.parent, ignore_errors=True)
    return meta

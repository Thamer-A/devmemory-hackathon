"""Tool-agnostic capture: works with any AI coding tool (Codex, Cursor, Aider, Gemini CLI, ...).

DevMemory cannot read every tool's private transcript, so this adapter records what it can
observe directly: the user's prompt, the project's text files before and after the session
(the diff becomes the session's edits), the tool's visible output, and, where the tool
offers a documented export (e.g. `codex exec --json` / `-o`), its events and final message.
The record has the same shape as a Claude Code capture, so packs, retrieval and line-level
freshness work unchanged. Fields the tool did not expose are left empty, never guessed.

  devmem wrap --prompt "<task>" -- <command ...>   run any CLI agent; {prompt}/{pack_file} in its args
  devmem begin / devmem end --prompt "<task>"      bracket a session in an IDE tool (Cursor, Copilot)
  devmem codex "<task>"                            Codex CLI adapter (pack in, JSONL events captured)
"""
from __future__ import annotations

import difflib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

from .store import MAX_TEXT_BYTES, hash_files, iter_files, store_path

MAX_SNIPPET = 1500


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def snapshot(project: Path) -> dict[str, str]:
    """Text content of every indexable file (same ignores as the scanner; secrets excluded)."""
    snap = {}
    for rel in iter_files(project):
        p = project / rel
        try:
            if p.stat().st_size > MAX_TEXT_BYTES:
                continue
            snap[rel] = p.read_bytes().decode("utf-8").replace("\r\n", "\n")
        except (OSError, UnicodeDecodeError):
            continue
    return snap


def diff_edits(before: dict[str, str], after: dict[str, str]) -> tuple[list[dict], list[str], str]:
    """Per-hunk Edit entries (old/new text), changed files, and a unified diff for the raw record."""
    edits, changed, udiff = [], [], []
    for rel in sorted(set(before) | set(after)):
        a, b = before.get(rel), after.get(rel)
        if a == b:
            continue
        changed.append(rel)
        al, bl = (a or "").splitlines(), (b or "").splitlines()
        udiff += difflib.unified_diff(al, bl, f"a/{rel}", f"b/{rel}", lineterm="")
        if a is None:
            edits.append({"tool": "Write", "file": rel, "new": (b or "")[:MAX_SNIPPET * 2]})
            continue
        if b is None:
            edits.append({"tool": "Delete", "file": rel, "old": a[:MAX_SNIPPET]})
            continue
        for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, al, bl, autojunk=False).get_opcodes():
            if op != "equal":
                edits.append({"tool": "Edit", "file": rel, "old": "\n".join(al[i1:i2])[:MAX_SNIPPET],
                              "new": "\n".join(bl[j1:j2])[:MAX_SNIPPET]})
    return edits, changed, "\n".join(udiff)


def record_generic(project: Path, prompt: str, before: dict, after: dict, started_at: str, provider: str,
                   store: Path | None = None, result_text: str | None = None, output_text: str = "",
                   events: list[dict] | None = None, model: str | None = None, usage: dict | None = None,
                   command: list[str] | None = None, summary_source: str | None = None,
                   errors: list[str] | None = None) -> Path:
    project = Path(project)
    sid = uuid.uuid4().hex
    stamp = started_at.replace(":", "").replace("-", "")[:15]
    sessions = Path(store or store_path(project)) / "sessions"
    sessions.mkdir(parents=True, exist_ok=True)
    base = sessions / f"{stamp}_{sid[:8]}"
    edits, changed, udiff = diff_edits(before, after)
    raw = [{"type": "prompt", "text": prompt, "ts": started_at}]
    if command:
        raw.append({"type": "command", "argv": command})
    raw += [{"type": "tool_event", "event": e} for e in (events or [])]
    if output_text:
        raw.append({"type": "output", "text": output_text})
    if result_text:
        raw.append({"type": "final_message", "text": result_text, "source": summary_source or provider})
    raw.append({"type": "file_changes", "files": changed, "unified_diff": udiff, "ts": _now()})
    raw_path = base.with_suffix(".jsonl")
    raw_path.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in raw) + "\n", encoding="utf-8")
    meta = {
        "session_id": sid,
        "started_at": started_at,
        "provider": provider,
        "capture_method": "snapshot-diff" + (" + tool-json" if events else ""),
        "model": model,
        "prompt": prompt,
        "result_text": result_text,
        # who wrote result_text (tool output, assistant self-report, user); never left implicit
        "result_source": (summary_source or provider) if result_text else "not available",
        "raw_record": raw_path.name,
        "files_read": [],  # not observable without the tool's transcript
        "files_edited": [c for c in changed if c in after],
        "files_deleted": [c for c in changed if c not in after],
        "file_hashes_at_capture": hash_files(project, [c for c in changed if c in after]),
        "usage": usage or {},
        "assistant_text": [{"line": len(raw) - 2, "text": result_text}] if result_text else [],
        "tool_calls": edits,
        "errors": [{"error": e[:300]} for e in (errors or [])],
    }
    meta_path = base.with_suffix(".meta.json")
    meta_path.write_text(json.dumps(meta, indent=1, ensure_ascii=False), encoding="utf-8")
    return meta_path


# ---- begin / end: bracket a session in a tool DevMemory cannot launch (IDE agents) ----

def _pending(store: Path) -> Path:
    return Path(store) / "pending.json"


def begin(project: Path, store: Path | None = None) -> Path:
    store = Path(store or store_path(project))
    store.mkdir(parents=True, exist_ok=True)
    p = _pending(store)
    p.write_text(json.dumps({"started_at": _now(), "snapshot": snapshot(project)}), encoding="utf-8")
    return p


def end(project: Path, prompt: str, provider: str = "manual", store: Path | None = None,
        summary: str | None = None, summary_source: str | None = None, model: str | None = None) -> Path:
    store = Path(store or store_path(project))
    p = _pending(store)
    if not p.exists():
        raise RuntimeError("no session in progress: run `devmem begin` first")
    state = json.loads(p.read_text(encoding="utf-8"))
    meta = record_generic(project, prompt, state["snapshot"], snapshot(project), state["started_at"], provider,
                          store=store, result_text=summary, summary_source=summary_source, model=model)
    p.unlink()
    return meta


# ---- wrap: any CLI agent ----

def wrap(project: Path, prompt: str, command: list[str], provider: str = "cli", store: Path | None = None,
         budget: int = 1500, with_pack: bool = True) -> Path:
    """Run `command` in the project. `{prompt}` in its args becomes pack + task, `{pack_file}` a file path."""
    from .pack import build_pack
    from .scan import scan
    project = Path(project).resolve()
    store = Path(store or store_path(project))
    scan(project, store)
    pack = build_pack(project, store, prompt, budget=budget)[0] if with_pack else ""
    tmp = Path(tempfile.mkdtemp(prefix="devmem-wrap-"))
    pack_file = tmp / "context_pack.md"
    pack_file.write_text(pack, encoding="utf-8")
    full = f"{pack}\n\n---\n\n{prompt}" if pack else prompt
    argv = [a.replace("{prompt}", full).replace("{pack_file}", str(pack_file)) for a in command]
    before, started = snapshot(project), _now()
    proc = subprocess.run(argv, cwd=project, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          env={**os.environ, "DEVMEM_PACK_FILE": str(pack_file)})
    out = (proc.stdout or "") + (("\n[stderr]\n" + proc.stderr) if proc.stderr else "")
    meta = record_generic(project, prompt, before, snapshot(project), started, provider, store=store,
                          output_text=out[-20000:], command=[command[0], "..."],
                          result_text=(proc.stdout or "").strip()[-2000:] or None, summary_source="tool stdout")
    shutil.rmtree(tmp, ignore_errors=True)
    return meta


# ---- Codex CLI adapter (documented flags: exec --json, -o/--output-last-message, -C, --sandbox) ----

def _find_usage(events: list[dict]) -> dict:
    """Sum any token-usage objects present in the JSONL events (field names vary by version)."""
    tot: dict = {}
    def walk(x):
        if isinstance(x, dict):
            if "input_tokens" in x and isinstance(x.get("input_tokens"), int):
                for k in ("input_tokens", "cached_input_tokens", "output_tokens"):
                    if isinstance(x.get(k), int):
                        tot[k] = tot.get(k, 0) + x[k]
                return
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    for e in events:
        if e.get("type") in ("turn.completed", "token_count") or "usage" in e:
            walk(e)
    return tot


def codex(project: Path, prompt: str, model: str | None = None, store: Path | None = None,
          budget: int = 1500, with_pack: bool = True, sandbox: str = "workspace-write", mcp: bool = False,
          isolated: bool = False) -> Path:
    """Run `codex exec` on the task. with_pack: pack prepended to the prompt. mcp: instead expose DevMemory as an
    MCP server for this run only (-c overrides; the user's Codex config is not modified). isolated: ignore the
    user's Codex config (no personal plugins/MCP servers such as computer use), as in our benchmark runs."""
    from .pack import build_pack
    from .scan import scan
    project = Path(project).resolve()
    store = Path(store or store_path(project))
    scan(project, store)
    pack = build_pack(project, store, prompt, budget=budget)[0] if with_pack else ""
    full = f"{pack}\n\n---\n\n{prompt}" if pack else prompt
    tmp = Path(tempfile.mkdtemp(prefix="devmem-codex-"))
    last = tmp / "last.txt"
    exe = shutil.which("codex") or "codex"
    cmd = [exe, "exec", "--json", "--skip-git-repo-check", "--sandbox", sandbox, "-C", str(project), "-o", str(last)]
    if model:
        cmd += ["-m", model]
    if isolated:  # keep only the Windows sandbox mode, without which the workspace is read-only on Windows
        cmd += ["--ignore-user-config"] + (["-c", 'windows.sandbox="elevated"'] if os.name == "nt" else [])
    if mcp:
        repo = Path(__file__).resolve().parent.parent.as_posix()
        args = ["-m", "devmem.cli", "mcp", "--project", project.as_posix(), "--store", store.as_posix()]
        cmd += ["-c", f'mcp_servers.devmemory.command="{Path(sys.executable).as_posix()}"',
                "-c", "mcp_servers.devmemory.args=" + json.dumps(args),
                "-c", f'mcp_servers.devmemory.env={{PYTHONPATH="{repo}"}}']
        for tool in ("get_context_pack", "list_sessions", "read_session", "begin_session", "end_session"):
            # headless exec cannot ask the user, so DevMemory's own tools are pre-approved for this run
            cmd += ["-c", f'mcp_servers.devmemory.tools.{tool}.approval_mode="approve"']
    before, started = snapshot(project), _now()
    proc = subprocess.run(cmd + ["-"], input=full, cwd=project, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    events = []
    for line in (proc.stdout or "").splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    result = last.read_text(encoding="utf-8", errors="replace").strip() if last.exists() else None
    errs = [str(e.get("message") or (e.get("error") or {}).get("message") or (e.get("item") or {}).get("message"))
            for e in events if e.get("type") in ("error", "turn.failed") or (e.get("item") or {}).get("type") == "error"]
    meta = record_generic(project, prompt, before, snapshot(project), started, "codex-cli" + (" + devmemory-mcp" if mcp else ""), store=store,
                          result_text=result, summary_source="codex final message (-o)", events=events,
                          output_text=(proc.stderr or "")[-4000:], model=model, usage=_find_usage(events),
                          command=["codex", "exec", "--json"], errors=errs)
    shutil.rmtree(tmp, ignore_errors=True)
    return meta

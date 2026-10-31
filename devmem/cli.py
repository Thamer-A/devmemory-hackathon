"""devmem command line.

  devmem scan    [--project P]                       build map (0 LLM tokens)
  devmem run     "<prompt>" [--project P] [--model M] run headless claude and capture the session
  devmem import  STREAM.jsonl --prompt "<prompt>"     record an existing stream-json file
  devmem pack    "<task>" [--budget N] [--mode full|static|nofresh] [--out FILE]
  devmem status  [--project P]                        sessions + freshness overview
  devmem hook                                         UserPromptSubmit hook: stdin JSON -> pack on stdout
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from .capture import record_session, run_and_capture
from .pack import build_pack, freshness, load_sessions
from .scan import scan
from .store import store_path


def _store(a) -> Path:
    return Path(a.store) if getattr(a, "store", None) else store_path(Path(a.project))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="devmem")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("scan", "run", "import", "pack", "status", "hook", "ui", "app"):
        p = sub.add_parser(name)
        p.add_argument("--project", default=None if name == "app" else ".")
        if name == "app":
            p.add_argument("--dry-run", action="store_true", help="print the browser command and exit")
            p.add_argument("--port", type=int, default=0)
        p.add_argument("--store", help="memory store dir (default <project>/.devmemory)")
        if name == "ui":
            p.add_argument("--port", type=int, default=8765)
            p.add_argument("--no-browser", action="store_true")
        if name == "run":
            p.add_argument("prompt")
            p.add_argument("--model", default="sonnet")
            p.add_argument("--max-turns", type=int, default=40)
        if name == "import":
            p.add_argument("stream")
            p.add_argument("--prompt", required=True)
        if name in ("pack", "hook"):
            p.add_argument("task", nargs="?" if name == "hook" else None)
            p.add_argument("--budget", type=int, default=1500)
            p.add_argument("--mode", default="full", choices=["full", "static", "nofresh"])
            p.add_argument("--out")
    a = ap.parse_args(argv)
    if a.cmd == "app":
        from .app import run_app
        proj = Path(a.project).resolve() if a.project else None
        return run_app(proj, Path(a.store) if a.store else None, dry_run=a.dry_run, port=a.port)
    project = Path(a.project).resolve()

    if a.cmd == "ui":
        from .ui_server import serve
        serve(project, _store(a), port=a.port, open_browser=not a.no_browser)
    elif a.cmd == "scan":
        m = scan(project, _store(a))
        print(f"indexed {len(m['files'])} files, 0 LLM tokens -> {_store(a) / 'PROJECT.md'}")
    elif a.cmd == "run":
        scan(project, _store(a))
        meta = run_and_capture(project, a.prompt, model=a.model, max_turns=a.max_turns,
                               isolated=False, store=_store(a))
        print(f"captured -> {meta}")
    elif a.cmd == "import":
        started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        print(record_session(project, Path(a.stream), a.prompt, started, store=_store(a)))
    elif a.cmd in ("pack", "hook"):
        task = a.task
        if a.cmd == "hook":  # Claude Code UserPromptSubmit hook: JSON on stdin, context on stdout
            payload = json.load(sys.stdin)
            task = payload.get("prompt", "")
            project = Path(payload.get("cwd") or project)
        store = Path(a.store) if a.store else store_path(project)
        if a.cmd == "hook":
            scan(project, store)  # ~tens of ms; keeps the map in step with the working tree
        text, info = build_pack(project, store, task, budget=a.budget, mode=a.mode)
        if a.out:
            Path(a.out).write_text(text, encoding="utf-8")
        sys.stdout.write(text)
        if a.cmd == "pack":
            print(json.dumps({k: v for k, v in info.items() if k != "files"}), file=sys.stderr)
    elif a.cmd == "status":
        sessions = load_sessions(_store(a))
        print(f"{len(sessions)} captured sessions in {_store(a)}")
        for s in sessions:
            fr = freshness(s, project)
            print(f"  {s.get('started_at', '')[:16]}  {str(s.get('session_id'))[:8]}  {fr['status']:<15} "
                  f"{(s.get('prompt') or '')[:70]!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Build the P1 history fixtures: run the scripted session-0 prompts with real headless Claude Code
on a temp copy of the project, capture each with devmem, commit each session's edits.

  python -m bench.make_history P1

Writes:
  bench/projects/<P>/devmemory/sessions/*.jsonl|*.meta.json   (captured records)
  bench/projects/<P>/game/...                                  (project after the sessions)
The copy runs outside this repo so the repo's own CLAUDE.md/AGENTS.md never load.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
from devmem.capture import run_and_capture  # noqa: E402


def main(project_id: str):
    proj = REPO / "bench" / "projects" / project_id
    script = json.loads((proj / "history_script.json").read_text(encoding="utf-8"))
    work = Path(tempfile.mkdtemp(prefix=f"devmem-hist-{project_id}-")) / "game"
    shutil.copytree(proj / "game", work, ignore=shutil.ignore_patterns(".devmemory", ".git"))
    store = proj / "devmemory"
    (store / "sessions").mkdir(parents=True, exist_ok=True)
    for s in script["sessions"]:
        meta = run_and_capture(work, s["prompt"], model=script.get("model", "haiku"), store=store)
        m = json.loads(meta.read_text(encoding="utf-8"))
        m["script_id"], m["script_kind"] = s["id"], s["kind"]
        meta.write_text(json.dumps(m, indent=1), encoding="utf-8")
        print(f"{s['id']}: {meta.name} edited={m['files_edited']} cost=${m['usage']['cost_usd_list']}")
    # copy the post-session project back (sessions' edits become project state)
    shutil.rmtree(proj / "game")
    shutil.copytree(work, proj / "game", ignore=shutil.ignore_patterns(".devmemory", ".git"))
    print("work copy:", work)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "P1")

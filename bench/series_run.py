"""Multi-session build benchmark: run a series of prompts, each in a FRESH headless session,
on one evolving project, under one condition.

  python -m bench.series_run --series blade --condition devmemory --tag r1
  conditions: none | agentsmd | devmemory

none       nothing carries over between sessions except the code itself
agentsmd   a starter AGENTS.md (+ CLAUDE.md -> @AGENTS.md) the agent is told to keep updated
devmemory  every session is captured; before each step: scan + context pack via --append-system-prompt
           (the store lives OUTSIDE the project dir, so the agent never browses raw records)

Per-step rows and a final graded row go to results/series_<series>.jsonl; the final project is
copied to results/series/<series>/<condition>_<tag>/ for building and playtesting.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
from bench.run import RESULTS, RUN_ROOT, git, rmtree_force  # noqa: E402
from devmem.capture import record_session  # noqa: E402
from devmem.claude_cli import run_claude  # noqa: E402
from devmem.pack import build_pack  # noqa: E402
from devmem.scan import scan  # noqa: E402


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--series", required=True)
    ap.add_argument("--condition", required=True, choices=["none", "agentsmd", "devmemory"])
    ap.add_argument("--tag", default="r1")
    ap.add_argument("--model")
    ap.add_argument("--budget", type=int, default=2000)
    ap.add_argument("--steps", help="comma list of step ids to run (default all)")
    a = ap.parse_args(argv)

    sdir = REPO / "bench" / "series" / a.series
    spec = json.loads((sdir / "series.json").read_text(encoding="utf-8"))
    model = a.model or spec.get("model", "sonnet")
    name = f"series_{a.series}_{a.condition}_{a.tag}"
    work = RUN_ROOT / name / "project"
    store = RUN_ROOT / name / "devmemory"
    raw_dir = RESULTS / "raw" / name
    out = RESULTS / f"series_{a.series}.jsonl"
    if not a.steps:
        rmtree_force(RUN_ROOT / name)
        shutil.copytree(sdir / "scaffold", work)
        if a.condition == "agentsmd":
            (work / "AGENTS.md").write_text(spec["agents_md"], encoding="utf-8")
            (work / "CLAUDE.md").write_text("@AGENTS.md\n", encoding="utf-8")
        git(work, "init", "-q")
        git(work, "-c", "core.autocrlf=false", "add", "-A")
        git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", "scaffold")

    steps = [s for s in spec["steps"] if not a.steps or s["id"] in a.steps.split(",")]
    for s in steps:
        pack_text, info = None, {}
        if a.condition == "devmemory":
            t0 = time.time()
            scan(work, store)
            pack_text, info = build_pack(work, store, s["prompt"], budget=a.budget, mode="full")
            info["pack_build_s"] = round(time.time() - t0, 3)
            raw_dir.mkdir(parents=True, exist_ok=True)
            (raw_dir / f"{s['id']}.pack.md").write_text(pack_text, encoding="utf-8")
        started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        raw = raw_dir / f"{s['id']}.jsonl"
        m = run_claude(s["prompt"], work, raw, model=model, max_turns=spec.get("max_turns", 60),
                       append_system_prompt=pack_text, timeout_s=spec.get("timeout_s", 1500))
        if a.condition == "devmemory":
            record_session(work, raw, s["prompt"], started, store=store, extra={"series_step": s["id"]})
        git(work, "-c", "core.autocrlf=false", "add", "-A")
        stat = git(work, "diff", "--cached", "--shortstat").strip()
        git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", s["id"])
        row = {"series": a.series, "condition": a.condition, "tag": a.tag, "step": s["id"], "model": model,
               "ts": started, "diffstat": stat, "pack_tokens_est": info.get("tokens_est", 0),
               "pack_items": info.get("items", 0), "pack_stale": info.get("stale", 0),
               **{k: m.get(k) for k in ("exit_code", "subtype", "is_error", "num_turns", "cost_usd_list",
                                        "duration_ms", "wall_s", "input_tokens", "output_tokens",
                                        "cache_read_tokens", "cache_creation_tokens", "total_input_tokens",
                                        "tool_calls", "tool_counts", "search_calls", "files_read_unique",
                                        "tool_errors", "rate_limit")}}
        with open(out, "a", encoding="utf-8") as f:
            f.write(json.dumps(row) + "\n")
        print(f"{a.condition} {s['id']}: turns={row['num_turns']} cost=${row['cost_usd_list']} "
              f"tok={row['total_input_tokens']} pack={row['pack_tokens_est']} {stat}", file=sys.stderr)

    spec_g = importlib.util.spec_from_file_location("series_grade", sdir / "grade.py")
    gmod = importlib.util.module_from_spec(spec_g)
    spec_g.loader.exec_module(gmod)
    g = gmod.grade(work)
    final = {"series": a.series, "condition": a.condition, "tag": a.tag, "step": "FINAL", "model": model, **g}
    with open(out, "a", encoding="utf-8") as f:
        f.write(json.dumps(final) + "\n")
    dest = RESULTS / "series" / a.series / f"{a.condition}_{a.tag}"
    rmtree_force(dest)
    shutil.copytree(work, dest, ignore=shutil.ignore_patterns(".git"))
    print(f"{a.condition} FINAL adherence={g['adherence']} ({g['passed_checks']}/{g['total_checks']}) -> {dest}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

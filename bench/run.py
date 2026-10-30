"""Benchmark runner: conditions x tasks x repeats, headless Claude Code, automatic graders.

Usage (from repo root):
  python -m bench.run --suite dev1 --tasks P1:A1,P1:D1 --conditions C0,C3 --models haiku --repeats 3
  python -m bench.run --suite dev1 --split dev --conditions all --repeats 3 --jobs 3

Each run: fresh copy of the project in a temp dir OUTSIDE this repo (so no parent CLAUDE.md
leaks in) -> git baseline commit -> optional context (C1 CLAUDE.md / DevMemory pack via
--append-system-prompt) -> `claude -p` -> grade the resulting tree/diff -> one JSONL row.
`--repeats` are independent re-runs (the CLI has no sampling seed).
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
from devmem.claude_cli import run_claude  # noqa: E402

BENCH = REPO / "bench"
RESULTS = REPO / "results"
RUN_ROOT = Path(tempfile.gettempdir()) / "devmem-runs"


def rmtree_force(path: Path) -> None:
    """Remove a work dir even when git left read-only object files (Windows)."""
    import os
    import stat

    def onexc(func, p, _exc):
        os.chmod(p, stat.S_IWRITE)
        func(p)
    if Path(path).exists():
        shutil.rmtree(path, onexc=onexc)

# condition -> how context is delivered. Model is chosen separately (--models) so C4 is a
# cross of (C3, cheap model) vs (C0/C1, strong model) from the same table.
CONDITIONS = {
    "C0": {"desc": "bare session", "claude_md": False, "pack": None},
    "C1": {"desc": "hand-written CLAUDE.md baseline", "claude_md": True, "pack": None},
    "C2": {"desc": "DevMemory static project map only", "claude_md": False, "pack": "static"},
    "C3": {"desc": "full DevMemory (map + history + freshness)", "claude_md": False, "pack": "full"},
    "C3nofresh": {"desc": "C3 without freshness flags (ablation)", "claude_md": False, "pack": "nofresh"},
}


def load_tasks(selector: str | None, split: str | None, types: str | None = None) -> list[dict]:
    tasks = []
    for tj in sorted((BENCH / "tasks").glob("*/*/task.json")):
        t = json.loads(tj.read_text(encoding="utf-8"))
        t["dir"] = tj.parent
        key = f"{t['project']}:{t['id']}"
        if selector and key not in selector.split(","):
            continue
        if types and t.get("type") not in types.split(","):
            continue
        if split and t.get("split") != split:
            continue
        tasks.append(t)
    return tasks


def git(work: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=work, capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def prepare_workdir(task: dict, cond: dict, run_id: str) -> Path:
    src = BENCH / "projects" / task["project"] / "game"
    work = RUN_ROOT / run_id
    rmtree_force(work)
    shutil.copytree(src, work, ignore=shutil.ignore_patterns(".devmemory", ".git"))
    if cond["claude_md"]:
        shutil.copyfile(BENCH / "projects" / task["project"] / "CLAUDE.baseline.md", work / "CLAUDE.md")
    git(work, "init", "-q")
    git(work, "-c", "core.autocrlf=false", "add", "-A")
    git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", "base")
    return work


def build_pack(task: dict, mode: str, budget: int) -> tuple[str, dict]:
    from devmem.pack import build_pack as _build  # lazy: pack module may not exist yet
    proj = BENCH / "projects" / task["project"]
    t0 = time.time()
    text, info = _build(proj / "game", proj / "devmemory", task["prompt"], budget=budget, mode=mode)
    info["pack_build_s"] = round(time.time() - t0, 3)
    return text, info


def grade(task: dict, work: Path) -> dict:
    git(work, "-c", "core.autocrlf=false", "add", "-A")
    diff = git(work, "diff", "--cached", "HEAD")
    changed = [l for l in git(work, "diff", "--cached", "--name-only", "HEAD").splitlines() if l]
    spec = importlib.util.spec_from_file_location(f"grade_{task['project']}_{task['id']}", task["dir"] / "grade.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    try:
        res = mod.grade(work, diff, changed)
    except Exception as exc:  # a crashing grader is a failed run, recorded as such
        res = {"passed": False, "checks": {"grader_exception": False}, "error": repr(exc)[:300]}
    res["changed_files"] = changed
    res["diff_lines"] = diff.count("\n")
    res["_diff"] = diff
    return res


def one_run(task: dict, cname: str, model: str, rep: int, suite: str, budget: int, keep: bool) -> dict:
    cond = CONDITIONS[cname]
    run_id = f"{suite}_{task['project']}-{task['id']}_{cname}_{model}_r{rep}_{uuid.uuid4().hex[:6]}"
    work = prepare_workdir(task, cond, run_id)
    pack_text, pack_info = None, {}
    if cond["pack"]:
        pack_text, pack_info = build_pack(task, cond["pack"], budget)
    raw = RESULTS / "raw" / suite / f"{run_id}.jsonl"
    m = run_claude(task["prompt"], work, raw, model=model, max_turns=task.get("max_turns", 30),
                   append_system_prompt=pack_text)
    g = grade(task, work)
    # saved diff lets any grader fix be re-applied to past runs (bench/regrade.py) without new LLM calls
    raw.with_suffix(".diff").write_text(g.pop("_diff"), encoding="utf-8", newline="\n")
    if pack_text:
        (raw.with_suffix(".pack.md")).write_text(pack_text, encoding="utf-8")
    row = {
        "suite": suite, "run_id": run_id, "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "code_rev": git(REPO, "rev-parse", "--short", "HEAD").strip(),
        "project": task["project"], "task": task["id"], "type": task["type"], "split": task.get("split"),
        "condition": cname, "model": model, "repeat": rep,
        "passed": bool(g.get("passed")) and m.get("exit_code") == 0, "checks": g.get("checks"),
        "grader_error": g.get("error"), "changed_files": g["changed_files"], "diff_lines": g["diff_lines"],
        "pack_tokens_est": pack_info.get("tokens_est", 0), "pack_items": pack_info.get("items", 0),
        "pack_stale_flags": pack_info.get("stale", 0), "pack_build_s": pack_info.get("pack_build_s"),
        **{k: m.get(k) for k in ("model", "exit_code", "subtype", "is_error", "num_turns", "cost_usd_list",
                                 "duration_ms", "wall_s", "input_tokens", "output_tokens", "cache_read_tokens",
                                 "cache_creation_tokens", "total_input_tokens", "tool_calls", "tool_counts",
                                 "search_calls", "files_read_unique", "tool_errors", "rate_limit")},
    }
    row["model"] = model  # requested alias; resolved id is in the raw stream
    if not keep:
        rmtree_force(work)
    return row


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--suite", required=True, help="name for this batch, e.g. dev1")
    ap.add_argument("--tasks", help="comma list of PROJECT:ID")
    ap.add_argument("--split", choices=["dev", "heldout"])
    ap.add_argument("--types", help="comma list of task types (code,history,stale,unrelated)")
    ap.add_argument("--conditions", default="C0", help="comma list or 'all'")
    ap.add_argument("--models", default="haiku")
    ap.add_argument("--repeats", type=int, default=1)
    ap.add_argument("--budget", type=int, default=1500, help="pack token budget (estimated tokens)")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--keep", action="store_true", help="keep work dirs for inspection")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args(argv)
    if a.split == "heldout" and not a.dry:
        print("Held-out split requested: this is the one-time final run.", file=sys.stderr)
    tasks = load_tasks(a.tasks, a.split, a.types)
    conds = list(CONDITIONS) if a.conditions == "all" else a.conditions.split(",")
    jobs = [(t, c, m, r) for r in range(a.repeats) for t in tasks for c in conds for m in a.models.split(",")]
    print(f"{len(jobs)} runs: {len(tasks)} tasks x {conds} x {a.models} x {a.repeats}", file=sys.stderr)
    if a.dry:
        return
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    if any(CONDITIONS[c]["pack"] for c in conds):
        from devmem.scan import scan
        setup_log = RESULTS / "setup_costs.jsonl"
        for pid in sorted({t["project"] for t in tasks}):
            proj = BENCH / "projects" / pid
            t0 = time.time()
            mp = scan(proj / "game", proj / "devmemory")
            rec = {"suite": a.suite, "project": pid, "scan_s": round(time.time() - t0, 3),
                   "files": len(mp["files"]), "llm_tokens": mp["llm_tokens_used"],
                   "sessions_captured": len(list((proj / "devmemory" / "sessions").glob("*.meta.json")))}
            with open(setup_log, "a", encoding="utf-8") as sf:
                sf.write(json.dumps(rec) + "\n")
            print(f"setup {rec}", file=sys.stderr)
    out = RESULTS / f"{a.suite}.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=a.jobs) as ex, open(out, "a", encoding="utf-8") as f:
        futs = [ex.submit(one_run, t, c, m, r, a.suite, a.budget, a.keep) for t, c, m, r in jobs]
        for fut in futs:
            try:
                row = fut.result()
            except Exception as exc:
                print(f"RUN FAILED: {exc!r}", file=sys.stderr)
                continue
            f.write(json.dumps(row) + "\n")
            f.flush()
            print(f"{row['task']:>4} {row['condition']:>9} {row['model']:>6} r{row['repeat']} "
                  f"{'PASS' if row['passed'] else 'fail'} tok={row['total_input_tokens']} "
                  f"cost=${row['cost_usd_list']} turns={row['num_turns']} q={row['rate_limit']}", file=sys.stderr)


if __name__ == "__main__":
    main()

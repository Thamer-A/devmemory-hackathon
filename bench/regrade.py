"""Re-grade past runs from their saved diffs with the CURRENT graders (no LLM calls).

  python -m bench.regrade dev2            # rewrites results/dev2.jsonl in place (backup kept)

Each run's diff (results/raw/<suite>/<run_id>.diff) is applied to a fresh copy of the project,
then graded. Agent-side metrics (tokens, cost, turns) are unchanged.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys

from bench.run import rmtree_force, CONDITIONS, RESULTS, grade, load_tasks, prepare_workdir


def main(suite: str) -> int:
    path = RESULTS / f"{suite}.jsonl"
    rows = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
    tasks = {(t["project"], t["id"]): t for t in load_tasks(None, None)}
    changed = 0
    for r in rows:
        d = RESULTS / "raw" / suite / f"{r['run_id']}.diff"
        if not d.exists():
            continue
        t = tasks[(r["project"], r["task"])]
        work = prepare_workdir(t, CONDITIONS[r["condition"]], "regrade_" + r["run_id"])
        if d.read_text(encoding="utf-8").strip():
            ap = subprocess.run(["git", "apply", "--whitespace=nowarn", str(d)], cwd=work, capture_output=True, text=True)
            if ap.returncode != 0:
                print(f"{r['run_id']}: diff did not apply: {ap.stderr[:200]}", file=sys.stderr)
                rmtree_force(work)
                continue
        g = grade(t, work)
        g.pop("_diff", None)
        rmtree_force(work)
        new = bool(g.get("passed")) and r.get("exit_code") == 0
        if new != r["passed"] or g.get("checks") != r.get("checks"):
            changed += 1
            print(f"{r['task']} {r['condition']} r{r['repeat']}: {r['passed']} -> {new}", file=sys.stderr)
        r["passed"], r["checks"] = new, g.get("checks")
    shutil.copyfile(path, path.with_suffix(".jsonl.bak"))
    path.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")
    print(f"regraded {len(rows)} rows, {changed} changed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))

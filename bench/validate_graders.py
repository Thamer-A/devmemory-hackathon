"""Grader validation (no LLM calls):
  negative control: the untouched project must FAIL every task's grader;
  positive control: the task's reference.patch (if present) applied to the project must PASS.

  python -m bench.validate_graders
"""
from __future__ import annotations

import shutil
import subprocess
import sys

from bench.run import rmtree_force, CONDITIONS, grade, load_tasks, prepare_workdir


def main() -> int:
    bad = 0
    for t in load_tasks(None, None):
        key = f"{t['project']}:{t['id']}"
        work = prepare_workdir(t, CONDITIONS["C0"], f"validate_{t['project']}-{t['id']}_neg")
        neg = grade(t, work)
        rmtree_force(work)
        line = f"{key:8} negative={'FAIL(ok)' if not neg['passed'] else 'PASS(BAD)'}"
        bad += neg["passed"]
        ref = t["dir"] / "reference.patch"
        if ref.exists():
            work = prepare_workdir(t, CONDITIONS["C0"], f"validate_{t['project']}-{t['id']}_pos")
            ap = subprocess.run(["git", "apply", "--whitespace=nowarn", str(ref)], cwd=work,
                                capture_output=True, text=True)
            pos = grade(t, work) if ap.returncode == 0 else {"passed": False, "checks": {"apply": ap.stderr[:200]}}
            rmtree_force(work)
            failed = [k for k, v in pos["checks"].items() if v is not True]
            line += f"  positive={'PASS(ok)' if pos['passed'] else 'FAIL(BAD) ' + str(failed)}"
            bad += not pos["passed"]
        else:
            line += "  positive=(no reference.patch)"
        print(line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

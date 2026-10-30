"""Grader for P2:C2 (stale). Hidden behavioural tests plus the project's own tests, and conventions."""
from pathlib import Path
from bench.graders.luau_rules import added_lines
from bench.graders.py_rules import convention_checks, run_pytest, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    ok, out = run_pytest(work, Path(__file__).parent / "hidden_test.py")
    c = {"tests_pass": ok}
    added = "\n".join(l for ls in added_lines(diff).values() for l in ls)
    c["no_stale_names"] = "monthly_limit" not in added and "month_status" not in added
    c.update(convention_checks(diff))
    return result(c, pytest_tail=out[-400:])

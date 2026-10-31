"""Grader for P2:E3 (history). Session S0b: legacy rows were stored day-first (14/03/2025); the
canonical form is ISO YYYY-MM-DD. Hidden behavioural tests plus the project's own tests, and conventions."""
from pathlib import Path
from bench.graders.py_rules import convention_checks, run_pytest, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    ok, out = run_pytest(work, Path(__file__).parent / "hidden_test.py")
    c = {"tests_pass": ok}
    c.update(convention_checks(diff))
    return result(c, pytest_tail=out[-400:])

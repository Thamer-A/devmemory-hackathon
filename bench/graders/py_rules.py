"""Shared grader helpers for P2 (ledgerly): convention checks on ADDED lines plus behavioural
checks by running pytest (the project's own tests and/or a hidden test file kept outside the
agent's copy)."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from bench.graders.luau_rules import added_lines, read  # noqa: F401  (re-exported for graders)

RULES = {
    "K1_no_float_money": (re.compile(r"\bfloat\s*\("), None),
    "K2_apperror_only": (re.compile(r"raise\s+(ValueError|Exception|RuntimeError|KeyError|TypeError)\b"), None),
    "K3_environ_only_in_config": (re.compile(r"os\.environ|os\.getenv"), "ledgerly/config.py"),
    "K4_connect_only_in_db": (re.compile(r"sqlite3\.connect"), "ledgerly/db.py"),
    "K5_print_only_in_ui": (re.compile(r"(?<![.\w])print\s*\("), "ledgerly/ui.py"),
    "K6_sql_only_in_repositories": (re.compile(r"\b(SELECT|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|ALTER\s+TABLE)\b"),
                                    ("ledgerly/repositories/", "ledgerly/db.py")),
}


def convention_checks(diff: str) -> dict[str, bool]:
    """Package code only (tests may use anything). True = rule respected."""
    res = {k: True for k in RULES}
    for f, lines in added_lines(diff).items():
        if not (f.startswith("ledgerly/") and f.endswith(".py")):
            continue
        for raw in lines:
            line = raw.split("#", 1)[0]
            for name, (rx, allowed) in RULES.items():
                if rx.search(line):
                    allowed_t = (allowed,) if isinstance(allowed, str) else (allowed or ())
                    if not any(f.startswith(a) for a in allowed_t):
                        res[name] = False
    return res


def run_pytest(work: Path, hidden_test: Path | None = None, timeout: int = 180) -> tuple[bool, str]:
    """Run the project's tests (plus an optional hidden test copied in at grading time only)."""
    work = Path(work)
    args = [sys.executable, "-m", "pytest", "-q", "-x", "-p", "no:cacheprovider"]
    if hidden_test is not None:
        dest = work / "tests" / f"_hidden_{hidden_test.name}"
        shutil.copyfile(hidden_test, dest)
    env = {k: v for k, v in os.environ.items() if not k.startswith("LEDGERLY")}
    try:
        p = subprocess.run(args, cwd=work, capture_output=True, text=True, timeout=timeout, env=env)
        ok, out = p.returncode == 0, (p.stdout + p.stderr)[-1500:]
    except subprocess.TimeoutExpired:
        ok, out = False, "pytest timeout"
    if hidden_test is not None:
        dest.unlink(missing_ok=True)
    return ok, out


def result(checks: dict[str, bool], **extra) -> dict:
    return {"passed": all(checks.values()), "checks": checks, **extra}

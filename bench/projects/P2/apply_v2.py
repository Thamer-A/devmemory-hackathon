#!/usr/bin/env python3
"""Apply the uncaptured v2 refactor to the ledgerly fixture project.

Renames (identifier-level, across every .py file under the target directory):
  monthly_limit            -> limit_cents
  budget_service.month_status -> budget_service.status_for_month
                              (bare identifier `month_status` -> `status_for_month`)

Usage: python apply_v2.py [TARGET_DIR]   (default: ./game next to this script)
Exits non-zero if either old name is not found.
"""

import re
import sys
from pathlib import Path

RENAMES = [
    (re.compile(r"\bmonthly_limit\b"), "limit_cents"),
    (re.compile(r"\bmonth_status\b"), "status_for_month"),
]
SKIP_DIRS = {"__pycache__", ".git", ".venv", "venv", ".pytest_cache", "node_modules"}


def python_files(root: Path):
    for path in sorted(root.rglob("*.py")):
        if not SKIP_DIRS.intersection(path.relative_to(root).parts):
            yield path


def main(argv: list[str]) -> int:
    target = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parent / "game"
    if not target.is_dir():
        print(f"error: target directory not found: {target}", file=sys.stderr)
        return 2

    totals = [0] * len(RENAMES)
    touched = []
    for path in python_files(target):
        original = path.read_bytes().decode("utf-8")
        text = original
        for i, (pattern, replacement) in enumerate(RENAMES):
            text, count = pattern.subn(replacement, text)
            totals[i] += count
        if text != original:
            path.write_bytes(text.encode("utf-8"))
            touched.append(path)

    missing = [RENAMES[i][0].pattern for i, n in enumerate(totals) if n == 0]
    if missing:
        print(f"error: old name(s) not found, refactor not applied: {missing}", file=sys.stderr)
        return 1

    for path in touched:
        print(f"updated {path.relative_to(target)}")
    print(
        f"monthly_limit -> limit_cents: {totals[0]} replacements; "
        f"month_status -> status_for_month: {totals[1]} replacements"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

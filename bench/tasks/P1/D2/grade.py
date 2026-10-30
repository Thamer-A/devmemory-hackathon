"""Grader for P1:D2 (unrelated). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    c["readme_has_rojo_serve"] = "rojo serve" in read(work, "README.md")
    c["only_readme_changed"] = changed == ["README.md"]
    c.update(convention_checks(diff))
    return result(c)

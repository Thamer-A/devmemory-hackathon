"""Grader for P1:D1 (unrelated). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    mu = src.get("src/shared/MathUtil.luau", "")
    m = re.search(r"function MathUtil\.lerp\s*\(([^)]*)\)(.*?)\nend", mu, re.S)
    c["lerp_defined"] = m is not None
    body = m.group(2) if m else ""
    c["clamps_t"] = re.search(r"clamp\(\s*t|math\.max\(\s*0[^)]*math\.min\(\s*1|math\.min\(\s*1[^)]*math\.max\(\s*0|t\s*<\s*0|t\s*>\s*1", body) is not None
    c["only_mathutil_changed"] = changed == ["src/shared/MathUtil.luau"]
    c.update(convention_checks(diff))
    return result(c)

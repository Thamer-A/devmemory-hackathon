"""Grader for P1:H4 (unrelated). Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import all_luau, convention_checks, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    mu = src.get("src/shared/MathUtil.luau", "")
    c = {}
    m = re.search(r"function\s+MathUtil\.approxEqual\s*\(([^)]*)\)[^\n]*\n(.*?)\nend\b", mu, re.S)
    c["defined"] = m is not None
    body = m.group(2) if m else ""
    c["three_params"] = m is not None and len([p for p in m.group(1).split(",") if p.strip()]) == 3
    c["uses_abs"] = "math.abs" in body
    c["inclusive_compare"] = "<=" in body or ">=" in body
    c["default_1e6"] = re.search(r"1e-6|0?\.000001|10\s*\^\s*-\s*6|1e-06", body) is not None
    c["existing_funcs_intact"] = all(f"MathUtil.{n}" in mu for n in ("round", "clamp", "formatNumber", "randomPointInPart"))
    c.update(convention_checks(diff))
    return result(c)

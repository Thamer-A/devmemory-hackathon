"""Grader for P1:H11 (unrelated). Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import all_luau, convention_checks, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    mu = src.get("src/shared/MathUtil.luau", "")
    c = {}
    m = re.search(r"function\s+MathUtil\.formatDuration\s*\(([^)]*)\)[^\n]*\n(.*?)\nend\b", mu, re.S)
    c["defined"] = m is not None
    body = "\n".join(l.split("--", 1)[0] for l in (m.group(2) if m else "").splitlines())
    c["hour_threshold"] = re.search(r"3600|60\s*\*\s*60", body) is not None
    c["zero_padded"] = "%02d" in body or re.search(r"<\s*10\b", body) is not None
    c["three_part_format"] = re.search(r"%d:%02d:%02d|:%02d:%02d", body) is not None or body.count(":") >= 3
    c["drops_fractions"] = re.search(r"math\.floor|//|math\.modf|%d", body) is not None
    c["negative_as_zero"] = re.search(r"math\.max\(\s*0|math\.max\([^)]*,\s*0\s*\)|<\s*0\b|clamp\(", body) is not None
    c["existing_funcs_intact"] = all(f"MathUtil.{n}" in mu for n in ("round", "clamp", "formatNumber", "randomPointInPart"))
    c.update(convention_checks(diff))
    return result(c)

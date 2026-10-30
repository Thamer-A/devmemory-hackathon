"""Grader for P1:H2 (history). The daily-reward numbers exist only in the captured planning session.
Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    mod = src.get("src/shared/DailyReward.luau", "")
    c["module_exists"] = bool(mod)
    c["coinsFor_defined"] = re.search(r"function\s+\w+[.:]coinsFor\s*\(", mod) is not None or \
        re.search(r"coinsFor\s*=\s*function", mod) is not None
    c["returns_module"] = re.search(r"^return\s+\w+", _code(mod), re.M) is not None
    cfg_added = _code("\n".join(add.get("src/shared/Config.luau", [])))
    mod_code = _code(mod)
    both = cfg_added + "\n" + mod_code
    c["base_20"] = re.search(r"(?<![\w.])20(?![\w.])", both) is not None
    c["per_day_10"] = re.search(r"(?<![\w.])10(?![\w.])", both) is not None
    c["cap_7"] = re.search(r"(?i)cap\w*\s*=\s*7\b", cfg_added) is not None or \
        re.search(r"(?<![\w.])7(?![\w.])", mod_code) is not None
    c["cap_applied"] = re.search(r"math\.min|clamp|if\s+[^\n]*>", mod_code) is not None
    c.update(convention_checks(diff))
    return result(c)

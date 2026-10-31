"""Grader for P1:H7 (history). Streak rules from the daily-reward planning session (S0a): UTC day
boundary, streak capped at 7 via Config.DailyStreakCap, a missed full day resets the streak to 1.
Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def _defined(mod: str, name: str) -> bool:
    return (re.search(rf"function\s+\w+[.:]{name}\s*\(", mod) is not None
            or re.search(rf"\b{name}\s*=\s*function\b", mod) is not None)


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    mod = _code(src.get("src/shared/DailyStreak.luau", ""))
    cfg_added = _code("\n".join(add.get("src/shared/Config.luau", [])))
    c["module_exists"] = bool(mod.strip())
    c["dayIndex_defined"] = _defined(mod, "dayIndex")
    c["advance_defined"] = _defined(mod, "advance")
    c["returns_module"] = re.search(r"^return\s+\w+", mod, re.M) is not None
    day_secs = r"86400|24\s*\*\s*60\s*\*\s*60|24\s*\*\s*3600|60\s*\*\s*60\s*\*\s*24|os\.date\(\s*[\"']!"
    c["utc_day_index"] = re.search(day_secs, mod) is not None or (
        re.search(r"86400", cfg_added) is not None and "Config." in mod)
    c["no_local_time"] = re.search(r"os\.date\(\s*[\"']\*t", mod) is None and "ToLocalTime" not in mod
    c["cap_7_config"] = re.search(r"\bDailyStreakCap\s*=\s*7\b", cfg_added) is not None
    c["cap_read_from_config"] = re.search(r"Config\.DailyStreakCap\b", mod) is not None
    c["cap_applied"] = re.search(r"math\.min|clamp|>=?\s*\w*[Cc]ap\b|>=?\s*Config\.", mod) is not None
    c["consecutive_increments"] = re.search(r"\+\s*1\b", mod) is not None
    c["gap_resets_to_1"] = re.search(r"return\s+1\b|(?<![=~<>])=\s*1\b(?!\s*[-+*/.])|else\s+1\b|or\s+1\b", mod) is not None
    c["same_day_nil"] = re.search(r"return\s+nil\b|then\s+nil\b", mod) is not None
    c["pure_no_coins"] = "CurrencyService" not in mod and "DataService" not in mod
    c.update(convention_checks(diff))
    return result(c)

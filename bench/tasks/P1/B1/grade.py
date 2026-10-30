"""Grader for P1:B1 (history). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    srv_add = [l for f, ls in add.items() if f.startswith("src/server") for l in ls]
    joined = "\n".join(srv_add)
    cfg = src.get("src/shared/Config.luau", "")
    c["grant_via_currency_reason"] = re.search(r'CurrencyService\.add\([^\n]*"daily_reward"', joined) is not None
    c["utc_day_boundary"] = (re.search(r'os\.date\(\s*"!', joined) or re.search(r"86400|ToUniversalTime|UnixTimestamp", joined)
                             or re.search(r"86400", cfg)) is not None
    c["no_local_time_day"] = re.search(r'os\.date\(\s*"\*t"', joined) is None
    c["streak_cap_7_config"] = re.search(r"DailyStreakCap\s*=\s*7\b", cfg) is not None
    c["streak_cap_used"] = any("DailyStreakCap" in t for f, t in src.items() if f.startswith("src/server"))
    c.update(convention_checks(diff))
    return result(c)

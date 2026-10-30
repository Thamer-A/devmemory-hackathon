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
    # reason may be passed directly or via a constant; require both in the server code the agent added
    c["grant_via_currency_reason"] = '"daily_reward"' in joined and "CurrencyService.add(" in joined
    # history-only specifics (session S0a): reward = 20 base + 10 per streak day
    all_add = "\n".join(l for f, ls in add.items() if f.endswith(".luau") for l in ls)
    c["reward_base_20"] = re.search(r"=\s*20\b|\b20\s*\+", all_add) is not None
    c["reward_per_day_10"] = re.search(r"=\s*10\b|\b10\s*\*|\*\s*10\b", all_add) is not None
    c["utc_day_boundary"] = (re.search(r'os\.date\(\s*"!', joined) or re.search(r"86400|ToUniversalTime|UnixTimestamp", joined)
                             or re.search(r"86400", cfg)) is not None
    c["no_local_time_day"] = re.search(r'os\.date\(\s*"\*t"', joined) is None
    c["streak_cap_7_config"] = re.search(r"DailyStreakCap\s*=\s*7\b", cfg) is not None
    c["streak_cap_used"] = any("DailyStreakCap" in t for f, t in src.items() if f.startswith("src/server"))
    c.update(convention_checks(diff))
    return result(c)

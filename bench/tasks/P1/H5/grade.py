"""Grader for P1:H5 (code). Kill-streak bonus. Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def _uses(text: str, key: str) -> bool:
    return re.search(rf"Config\.(\w+\.)?{re.escape(key)}\b", text) is not None


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    cfg_added = _code("\n".join(add.get("src/shared/Config.luau", [])))
    k5 = re.findall(r"(\w+)\s*=\s*5\b(?!\.)", cfg_added)
    k50 = re.findall(r"(\w+)\s*=\s*50\b(?!\.)", cfg_added)
    c["config_streak_5"] = bool(k5)
    c["config_bonus_50"] = bool(k50)
    server = "\n".join(_code(t) for f, t in src.items() if f.startswith("src/server"))
    srv_add = _code("\n".join(l for f, ls in add.items() if f.startswith("src/server") for l in ls))
    c["streak_length_from_config"] = any(_uses(server, k) for k in k5)
    c["bonus_from_config"] = any(_uses(srv_add, k) for k in k50)
    c["bonus_via_currency_service"] = "CurrencyService.add(" in srv_add
    c["resets_on_death"] = re.search(r"\bDied\b|CharacterAdded|CharacterRemoving", srv_add) is not None
    cfg = src.get("src/shared/Config.luau", "")
    c["kill_reward_kept"] = re.search(r"KillReward\s*=\s*10\b", cfg) is not None and "Config.KillReward" in server
    c.update(convention_checks(diff))
    return result(c)

"""Grader for P1:H9 (stale). Enemy damage lives in Config.Enemies[kind].damage now (session S0c still
says EnemyService.DAMAGE). Static assertions on the final tree + diff."""
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
    cfg = src.get("src/shared/Config.luau", "")
    cfg_added = _code("\n".join(add.get("src/shared/Config.luau", [])))
    k2 = re.findall(r"(\w+)\s*=\s*2(?:\.0)?\b(?!\.\d)", cfg_added)
    k30 = re.findall(r"(\w+)\s*=\s*30\b(?!\.)", cfg_added)
    c["config_multiplier_2"] = bool(k2)
    c["config_window_30"] = bool(k30)
    server = "\n".join(_code(t) for f, t in src.items() if f.startswith("src/server"))
    srv_add = _code("\n".join(l for f, ls in add.items() if f.startswith("src/server") for l in ls))
    c["multiplier_read_from_config"] = any(_uses(server, k) for k in k2)
    c["window_read_from_config"] = any(_uses(server, k) for k in k30)
    c["uses_round_time_left"] = re.search(r"getTimeLeft|timeLeft", srv_add) is not None
    enemy = _code(src.get("src/server/services/EnemyService.luau", ""))
    c["damage_still_from_config_enemies"] = re.search(r"Config\.Enemies\[[^\]]+\]\.damage|stats\.damage", enemy) is not None
    c["multiplier_applied"] = re.search(r"\*", "\n".join(_code(l) for l in add.get("src/server/services/EnemyService.luau", []))) is not None
    c["no_DAMAGE_table"] = re.search(r"\bDAMAGE\b", enemy) is None
    c["enemy_stats_unchanged"] = (re.search(r"Grunt\s*=\s*\{[^}]*damage\s*=\s*12\b", cfg) is not None and
                                  re.search(r"Brute\s*=\s*\{[^}]*damage\s*=\s*25\b", cfg) is not None)
    c.update(convention_checks(diff))
    return result(c)

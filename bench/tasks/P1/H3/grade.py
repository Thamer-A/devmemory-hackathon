"""Grader for P1:H3 (stale). Enemy stats live in Config.Enemies now, not in EnemyService.DAMAGE.
Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    c = {}
    cfg = src.get("src/shared/Config.luau", "")
    enemy = src.get("src/server/services/EnemyService.luau", "")
    m = re.search(r"Boss\s*=\s*\{([^}]*)\}", cfg)
    body = m.group(1) if m else ""
    c["boss_in_config_enemies"] = m is not None
    c["boss_health_500"] = re.search(r"health\s*=\s*500\b", body) is not None
    c["boss_speed_10"] = re.search(r"speed\s*=\s*10\b", body) is not None
    c["boss_damage_40"] = re.search(r"damage\s*=\s*40\b", body) is not None
    c["spawn_chance_in_config"] = re.search(r"=\s*0?\.05\b", cfg) is not None
    c["can_spawn"] = re.search(r"Boss", enemy) is not None
    c["placeholder_color"] = re.search(r"EnemyPlaceholderColors\s*=\s*\{[^}]*Boss\s*=", cfg, re.S) is not None
    c["no_DAMAGE_table_recreated"] = re.search(r"DAMAGE\s*=", enemy) is None
    c["existing_enemies_intact"] = (re.search(r"Grunt\s*=\s*\{[^}]*damage\s*=\s*12\b", cfg) is not None and
                                    re.search(r"Brute\s*=\s*\{[^}]*damage\s*=\s*25\b", cfg) is not None)
    c.update(convention_checks(diff))
    return result(c)

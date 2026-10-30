"""Grader for P1:C1 (stale). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    cfg = src.get("src/shared/Config.luau", "")
    enemy = src.get("src/server/services/EnemyService.luau", "")
    c["brute_damage_35_in_config"] = re.search(r"Brute\s*=\s*\{[^}]*damage\s*=\s*35\b", cfg) is not None
    c["grunt_unchanged_12"] = re.search(r"Grunt\s*=\s*\{[^}]*damage\s*=\s*12\b", cfg) is not None
    c["no_DAMAGE_table_recreated"] = re.search(r"DAMAGE\s*=", enemy) is None
    c["enemyservice_reads_config"] = "Config.Enemies" in enemy and "35" not in enemy
    c.update(convention_checks(diff))
    return result(c)

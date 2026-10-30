"""Grader for P1:A1 (code). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    c["remote_defined"] = 'define("RequestRespawn")' in src.get("src/shared/Remotes.luau", "")
    server = [t for f, t in src.items() if f.startswith("src/server") and 'get("RequestRespawn")' in t]
    c["server_handler"] = any("OnServerEvent" in t for t in server)
    c["server_respawns"] = any("LoadCharacter" in t for t in server)
    c["client_fires"] = any('get("RequestRespawn")' in t and "FireServer" in t
                            for f, t in src.items() if f.startswith("src/client"))
    c["config_delay"] = re.search(r"RespawnDelay\s*=\s*\d", src.get("src/shared/Config.luau", "")) is not None
    c["delay_from_config"] = any("Config.RespawnDelay" in t for t in server)
    c.update(convention_checks(diff))
    return result(c)

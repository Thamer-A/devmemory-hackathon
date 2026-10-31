"""Grader for P1:H8 (history). Session S0b: renaming 'Speed Coil' -> 'Speed Boots' made players lose
the item because old saves held names; old names must keep resolving to the same numeric id.
Static assertions on the final tree + diff."""
import json
import re
from pathlib import Path
from bench.graders.luau_rules import all_luau, convention_checks, read, result


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    c = {}
    cat = _code(src.get("src/shared/ItemCatalog.luau", ""))
    m = re.search(r"\[1\]\s*=\s*\{(.*?)\n\s*\}", cat, re.S)
    entry = m.group(1) if m else ""
    c["id1_renamed"] = re.search(r'name\s*=\s*"Sprint Boots"', entry) is not None
    c["id1_keeps_id_and_stats"] = (re.search(r"\bid\s*=\s*1\b", entry) is not None
                                   and re.search(r"price\s*=\s*100\b", entry) is not None
                                   and re.search(r"walkSpeedBonus\s*=\s*6\b", entry) is not None)
    c["old_name_not_an_item_name"] = re.search(r'name\s*=\s*"Speed Boots"', cat) is None
    ds = _code(src.get("src/server/services/DataService.luau", ""))
    both = ds + "\n" + cat
    # old saves may still hold the string 'Speed Boots' (or 'Speed Coil'); both must resolve to id 1
    c["old_name_still_resolves"] = (re.search(r'\[\s*"Speed Boots"\s*\]\s*=\s*1\b', both) is not None
                                    or re.search(r'"Speed Boots"', cat.replace('name = "Speed Boots"', "")) is not None)
    c["older_legacy_name_kept"] = re.search(r'"Speed Coil"', both) is not None
    c["inventory_still_ids"] = re.search(r"inventory:\s*\{\s*number\s*\}", src.get("src/shared/Types.luau", "")) is not None
    icon = re.search(r'icon\s*=\s*"([^"]+)"', entry)
    try:
        manifest = json.loads(read(work, "assets/manifest.json"))
    except ValueError:
        manifest = {}
    c["icon_resolves"] = bool(icon) and str(manifest.get(icon.group(1), "")).startswith("rbxassetid://")
    c.update(convention_checks(diff))
    return result(c)

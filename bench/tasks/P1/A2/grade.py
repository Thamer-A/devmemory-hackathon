"""Grader for P1:A2 (code). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    cat = src.get("src/shared/ItemCatalog.luau", "")
    ids = [int(x) for x in re.findall(r"\[(\d+)\]\s*=\s*\{", cat)]
    m = re.search(r"\[(\d+)\]\s*=\s*\{[^}]*Coin Magnet[^}]*\}", cat, re.S)
    c["item_added"] = m is not None
    c["unique_numeric_id"] = bool(m) and ids.count(int(m.group(1))) == 1 and int(m.group(1)) not in (1, 2, 3, 4)
    c["price_150"] = bool(m) and re.search(r"price\s*=\s*150\b", m.group(0)) is not None
    icon = re.search(r'icon\s*=\s*"([^"]+)"', m.group(0)) if m else None
    try:
        manifest = json.loads(read(work, "assets/manifest.json"))
    except ValueError:
        manifest = {}
    c["manifest_valid_json"] = bool(manifest)
    c["icon_in_manifest"] = bool(icon) and str(manifest.get(icon.group(1), "")).startswith("rbxassetid://")
    c.update(convention_checks(diff))
    return result(c)

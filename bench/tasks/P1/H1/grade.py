"""Grader for P1:H1 (code). Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    cfg_added = "\n".join(add.get("src/shared/Config.luau", []))
    keys = re.findall(r"(\w+)\s*=\s*3\b", cfg_added)
    c["config_key_value_3"] = bool(keys)
    server = {f: t for f, t in src.items() if f.startswith("src/server")}
    used = [k for k in keys if any(f"Config.{k}" in t for t in server.values())]
    c["limit_read_from_config"] = bool(used)
    shop = server.get("src/server/services/ShopService.luau", "")
    before_add = shop.split("CurrencyService.add(", 1)[0]
    helper = re.search(r"DataService\.(?!hasItem|get\b|addItem|markDirty)\w+\(", before_add) is not None
    c["check_before_charging"] = "CurrencyService.add(" in shop and (
        any(f"Config.{k}" in before_add for k in keys) or helper)
    c["counts_inventory"] = any("#" in t and "inventory" in t.lower() for t in server.values())
    c["catalog_untouched"] = "src/shared/ItemCatalog.luau" not in changed
    c.update(convention_checks(diff))
    return result(c)

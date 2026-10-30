"""Grader for P1:B2 (history). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    adm = "\n".join(add.get("src/server/services/AdminService.luau", []))
    c["command_registered"] = re.search(r'register\(\s*"(gift|give|giveitem|gift_item|giftitem)"', adm, re.I) is not None
    calls = re.findall(r"DataService\.addItem\(([^\n]*)\)", adm)
    c["uses_dataservice"] = bool(calls)
    c["stores_numeric_id"] = bool(calls) and all(".name" not in a and "Name" not in a.split(",", 1)[-1] for a in calls)
    c["resolves_via_catalog"] = re.search(r"ItemCatalog\.(getByName|getById)|tonumber\(", adm) is not None
    c["no_direct_inventory_write"] = not any(re.search(r"inventory", l) and "table.insert" in l
                                             for f, ls in add.items() if "DataService" not in f for l in ls)
    c.update(convention_checks(diff))
    return result(c)

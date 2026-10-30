"""Grader for P1:C2 (stale). Static assertions on the final tree + diff."""
import json, re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, read, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    client_add = "\n".join(l for f, ls in add.items() if f.startswith("src/client") for l in ls)
    shop = src.get("src/client/controllers/ShopController.luau", "")
    c["dialog_added"] = re.search(r"confirm", client_add, re.I) is not None
    c["fires_PurchaseItem"] = 'get("PurchaseItem")' in shop and "FireServer" in shop
    c["no_BuyItem_anywhere"] = not any("BuyItem" in t for t in src.values())
    c["remote_still_defined"] = 'define("PurchaseItem")' in src.get("src/shared/Remotes.luau", "")
    c.update(convention_checks(diff))
    return result(c)

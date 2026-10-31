"""Grader for P1:H10 (stale). The purchase remote is PurchaseItem now (session S0d still says BuyItem).
Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result

EXISTING = {"PurchaseItem", "CoinsChanged", "RoundState", "EquipItem", "InventoryChanged", "EnemyHit"}


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def _remote_refs(text: str, name: str) -> list[str]:
    """Expressions that refer to remote `name`: the get() call itself plus locals bound to it."""
    get = rf'Remotes\.get\(\s*"{name}"\s*\)'
    refs = [get]
    for var in re.findall(rf"(\w+)\s*=\s*{get}", text):
        refs.append(rf"\b{var}\b")
    return refs


def _fire_count(text: str, name: str) -> int:
    fire = "|".join(rf"(?:{r})\s*:\s*FireClient\(" for r in _remote_refs(text, name))
    direct = len(re.findall(fire, text))
    total = direct
    for fn, body in re.findall(r"local function (\w+)\s*\((.*?)\nend\b", text, re.S):
        inner = len(re.findall(fire, body))
        calls = len(re.findall(rf"(?<!function )\b{fn}\s*\(", text))
        if inner and calls:  # a helper that sends the notice: count its call sites instead
            total += calls - inner
    return total


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    remotes = _code(src.get("src/shared/Remotes.luau", ""))
    defined = set(re.findall(r'Remotes\.define\(\s*"(\w+)"\s*\)', remotes))
    candidates = (defined - EXISTING) | {"PurchaseItem"}
    shop_srv = _code(src.get("src/server/services/ShopService.luau", ""))
    shop_cli = _code(src.get("src/client/controllers/ShopController.luau", ""))
    fired = {n: _fire_count(shop_srv, n) for n in candidates}
    used = [n for n, k in fired.items() if k > 0]
    c["server_notifies_client"] = bool(used)
    c["several_rejections_reported"] = any(k >= 2 for k in fired.values())
    listen = [n for n in used if any(re.search(rf"(?:{r})\s*\.\s*OnClientEvent", shop_cli)
                                     for r in _remote_refs(shop_cli, n))]
    c["client_listens"] = bool(listen)
    cli_add = _code("\n".join(add.get("src/client/controllers/ShopController.luau", [])))
    c["client_reenables_buy"] = re.search(r"pending|refreshButtons|\.Active\s*=\s*true", cli_add) is not None
    c["client_shows_reason"] = re.search(r"\.Text\s*=|createLabel\(", cli_add) is not None
    c["no_BuyItem_anywhere"] = not any("BuyItem" in t for t in src.values())
    c["purchase_remote_intact"] = ("PurchaseItem" in defined
                                   and re.search(r'get\("PurchaseItem"\)\s*\.\s*OnServerEvent', shop_srv) is not None
                                   and re.search(r'get\("PurchaseItem"\)\s*:\s*FireServer', shop_cli) is not None)
    c.update(convention_checks(diff))
    return result(c)

"""Grader for P1:H6 (code). Lifetime coins earned, persisted with player data.
Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import added_lines, all_luau, convention_checks, result


def _code(text: str) -> str:
    return "\n".join(l.split("--", 1)[0] for l in text.splitlines())


def _block(text: str, header: str) -> str:
    m = re.search(header + r".*?\nend\b", text, re.S)
    return m.group(0) if m else ""


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    add = added_lines(diff)
    c = {}
    types_add = _code("\n".join(add.get("src/shared/Types.luau", [])))
    fields = re.findall(r"(\w+)\s*:\s*number", types_add)
    c["type_field_added"] = bool(fields)
    ds = _code(src.get("src/server/services/DataService.luau", ""))
    default = _block(ds, r"local function defaultData\(")
    stats_m = re.search(r"stats\s*=\s*\{([^}]*)\}", default)
    stats_block = stats_m.group(1) if stats_m else ""
    c["default_is_zero"] = any(re.search(rf"\b{f}\s*=\s*0\b", default) for f in fields)
    recon = _block(ds, r"local function reconcile\(")
    # a field inside the stats table is back-filled by reconcile's template.stats loop
    c["old_saves_backfilled"] = any(re.search(rf"\b{f}\b", stats_block) or re.search(rf"\b{f}\b", recon)
                                    for f in fields)
    cur = _code(src.get("src/server/services/CurrencyService.luau", ""))
    cur_add = _code("\n".join(add.get("src/server/services/CurrencyService.luau", [])))
    c["incremented_in_currency_service"] = any(
        re.search(rf"\.{f}\s*(\+=|=\s*[^=])", cur) for f in fields)
    c["only_gains_count"] = re.search(r"\bif\b[^\n]*[<>]|math\.max\(", cur_add) is not None
    c["single_entry_point_kept"] = "function CurrencyService.add(" in cur
    c.update(convention_checks(diff))
    return result(c)

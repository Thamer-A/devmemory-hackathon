"""Grader for P1:H12 (unrelated). Static assertions on the final tree + diff."""
import re
from pathlib import Path
from bench.graders.luau_rules import all_luau, convention_checks, result


def grade(work: Path, diff: str, changed: list[str]) -> dict:
    src = all_luau(work)
    maid = "\n".join(l.split("--", 1)[0] for l in src.get("src/shared/Maid.luau", "").splitlines())
    c = {}
    m = re.search(r"function\s+Maid[.:]Clean\s*\([^)]*\)(.*?)\nend\b", maid, re.S)
    body = m.group(1) if m else ""
    c["clean_handles_thread"] = re.search(r"[\"']thread[\"']", body) is not None
    c["cancels_thread"] = re.search(r"task\.cancel\(|coroutine\.close\(", body) is not None
    c["existing_kinds_kept"] = all(k in body for k in ('"RBXScriptConnection"', '"Instance"', '"function"', "Disconnect", "Destroy"))
    c["destroy_alias_kept"] = re.search(r"Maid\.Destroy\s*=\s*Maid\.Clean|function\s+Maid[.:]Destroy", maid) is not None
    c["only_maid_changed"] = changed == ["src/shared/Maid.luau"]
    c.update(convention_checks(diff))
    return result(c)

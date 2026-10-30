"""Shared grader helpers for P1 (CoinRush): parse the run diff and check project conventions K1-K5
on lines the agent ADDED. Static checks only (Luau is not executed)."""
from __future__ import annotations

import re
from pathlib import Path

PRINT_RE = re.compile(r"(?<![.\w:])(print|warn)\s*\(")
REMOTE_NEW_RE = re.compile(r'Instance\.new\(\s*["\'](RemoteEvent|RemoteFunction|UnreliableRemoteEvent)["\']')
LEADERSTATS_WRITE_RE = re.compile(r"leaderstats.*\.Value\s*=[^=]")
COINS_WRITE_RE = re.compile(r"\.coins\s*(=[^=]|\+=|-=)")


def added_lines(diff: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    cur = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            cur = line[6:] if line.startswith("+++ b/") else None
            if cur:
                out.setdefault(cur, [])
        elif cur and line.startswith("+") and not line.startswith("+++"):
            out[cur].append(line[1:])
    return out


def strip_comment(line: str) -> str:
    return line.split("--", 1)[0]


def read(work: Path, rel: str) -> str:
    p = Path(work) / rel
    return p.read_text(encoding="utf-8", errors="replace") if p.exists() else ""


def all_luau(work: Path) -> dict[str, str]:
    return {p.relative_to(work).as_posix(): p.read_text(encoding="utf-8", errors="replace")
            for p in Path(work).rglob("*.luau") if ".git" not in p.parts}


def convention_checks(diff: str) -> dict[str, bool]:
    """K1/K2/K3/K5 on added lines. True = rule respected."""
    add = added_lines(diff)
    k1 = k2 = k3 = k5 = True
    for f, lines in add.items():
        if not f.endswith(".luau"):
            continue
        for raw in lines:
            line = strip_comment(raw)
            if REMOTE_NEW_RE.search(line) and not f.endswith("shared/Remotes.luau"):
                k1 = False
            if PRINT_RE.search(line) and not f.endswith("shared/Log.luau"):
                k3 = False
            if LEADERSTATS_WRITE_RE.search(line) and "LeaderboardService" not in f:
                k2 = False
            if COINS_WRITE_RE.search(line) and not any(s in f for s in ("CurrencyService", "DataService")):
                k2 = False
            if "rbxassetid://" in line:
                k5 = False
    return {"K1_remotes_via_module": k1, "K2_currency_via_service": k2,
            "K3_logging_via_Log": k3, "K5_assets_via_manifest": k5}


def result(checks: dict[str, bool]) -> dict:
    return {"passed": all(checks.values()), "checks": checks}

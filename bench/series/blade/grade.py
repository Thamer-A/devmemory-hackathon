"""Spec-adherence checks for the final state of a Blade Swarm series build.

Static and deliberately tolerant (names may vary): each check looks for the DECISION a user
made in some session (numbers, names, colors, rules) anywhere in the Luau source. The score is
the fraction of decisions honoured at the end of the series. Gameplay and looks are judged
separately by building the place and playtesting it in Roblox Studio.
"""
from __future__ import annotations

import re
from pathlib import Path


def _src(work: Path) -> dict[str, str]:
    return {p.relative_to(work).as_posix(): p.read_text(encoding="utf-8", errors="replace")
            for p in Path(work).rglob("*.luau") if ".git" not in p.parts}


def _any(src: dict[str, str], pattern: str, flags=re.I) -> bool:
    rx = re.compile(pattern, flags)
    return any(rx.search(t) for t in src.values())


def _line_with(src: dict[str, str], must: list[str], pattern: str) -> bool:
    rx = re.compile(pattern, re.I)
    for t in src.values():
        for line in t.splitlines():
            low = line.lower()
            if all(m in low for m in must) and rx.search(line):
                return True
    return False


def _cyan_rgb(src: dict[str, str]) -> bool:
    """Any Color3.fromRGB that is cyan-ish: low red, high green and blue."""
    for t in src.values():
        for r, g, b in re.findall(r"Color3\.fromRGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)", t):
            if int(r) < 130 and int(g) > 170 and int(b) > 200:
                return True
    return False


def grade(work: Path) -> dict:
    src = _src(work)
    shared = {k: v for k, v in src.items() if k.startswith("src/shared")}
    remote_files = [k for k, v in src.items() if re.search(r'Instance\.new\(\s*"RemoteEvent"', v)]
    c = {
        # S1
        "config_module_in_shared": any(Path(k).stem.lower().startswith("config") for k in shared),
        "remotes_in_single_module": len(remote_files) == 1 and "remote" in remote_files[0].lower(),
        "start_blades_2": _any(src, r"\b\w*blade\w*count\w*\s*=\s*2\b|\b(start|base|initial)\w*blades?\w*\s*=\s*2\b"),
        "orbit_radius_7": _any(src, r"\b\w*(radius|orbit|reach)\w*\s*=\s*7(\.0)?\b"),
        "neon_cyan_blades": _any(src, r"Enum\.Material\.Neon") and (_any(src, r"cyan") or _cyan_rgb(src)),
        # S2
        "blade_damage_20": _any(src, r"\b\w*damage\w*\s*=\s*20\b"),
        "zombie_health_60": _any(src, r"\b\w*health\w*\s*=\s*60\b"),
        "leaderstats_coins_kills": _any(src, r"leaderstats") and _any(src, r'"Kills"') and _any(src, r'"Coins"'),
        # S3 (+S7 change)
        "wave1_8_zombies": _line_with(src, ["zombie"], r"=\s*8\b") or _line_with(src, ["wave"], r"=\s*8\b"),
        "plus_4_per_wave": _line_with(src, ["wave"], r"=\s*4\b") or _line_with(src, ["per"], r"=\s*4\b"),
        "break_20s": _any(src, r"\b\w*(break|intermission|shop|between|rest)\w*\s*=\s*20\b"),
        "contact_10_dps": _any(src, r"\b\w*(contact|touch|dps|persecond|attack|zombiedamage)\w*\s*=\s*10\b"),
        "health_growth_10pct_after_s7": _line_with(src, ["health"], r"\b(1\.10?|0\.10?)\b") or
                                        _any(src, r"\b\w*(growth|scal|mult)\w*\s*=\s*(1\.10?|0\.10?)\b"),
        "coins_per_kill_10_after_s7": _any(src, r"\b\w*coin\w*\s*=\s*10\b"),
        "game_over_resets_to_wave_1": _any(src, r"game\s*over|gameover") and _any(src, r"wave\w*\s*=\s*1\b"),
        # S4 (+S6)
        "upgrade_names_all": all(_any(src, re.escape(n)) for n in
                                 ["Sharper Blades", "Faster Spin", "Longer Reach", "Vitality", "Vampiric", "Greed", "Twin Spin"]),
        "upgrade_prices": all(_any(src, rf"\b{p}\b") for p in (60, 30, 35, 25, 55, 50, 120)),
        "plus_one_blade_upgrade": _any(src, r"\+1 Blade|Extra Blade|One More Blade"),
        "reroll_cost_10": _any(src, r"\b\w*reroll\w*\s*=\s*10\b"),
        "twin_spin_epic_120": _line_with(src, ["twin"], r"120|epic") and _any(src, r"Epic"),
        # S5
        "rarity_colors_defined": all(_any(src, r) for r in (r"\bCommon\b", r"\bRare\b", r"\bEpic\b")) and _any(src, r"Color3"),
        "hud_health_bar": _any(src, r"health\w*bar|hpbar|HealthFill|health_fill"),
        # S8
        "damage_numbers_billboard": _any(src, r"BillboardGui"),
        "death_burst_particles": _any(src, r"ParticleEmitter"),
    }
    n = sum(1 for v in c.values() if v)
    return {"adherence": round(n / len(c), 3), "passed_checks": n, "total_checks": len(c), "checks": c,
            "luau_files": len(src), "luau_lines": sum(t.count("\n") + 1 for t in src.values())}

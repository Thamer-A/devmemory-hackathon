"""Summarize the adaptive race log (results/adaptive_<race>.jsonl) into Markdown.

  python -m bench.adaptive_report blade

Rows after an `invalidate` marker for a condition are dropped up to the point the run resumed
(the condition was re-run from the named checkpoint).
"""
from __future__ import annotations

import collections
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

PROTOCOL_NOTES = [
    "Chase check also passes when zombies come within 6 studs (measurement could start late).",
    "The between-waves shop appearing also counts as evidence of a wave transition.",
    "From P7, bug reports include Output-window 'Infinite yield' warnings (what a user would see).",
    "Probe v2: the passive test player is kept alive during observation (a correct game-over reset hid the shop).",
    "Probe v3 + 25 s game-over window: the test player walks a slow circle (a standing player let zombies park inside "
    "the blade orbit); the reset is watched for 25 s instead of 12 s.",
    "Studio-vs-disk sync check before every playtest after the `none` Rojo server crashed (its P7-P12 were invalidated "
    "and re-run from the P6 checkpoint).",
]


def load(race: str):
    rows = [json.loads(l) for l in (REPO / "results" / f"adaptive_{race}.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    out = []
    for r in rows:
        if r.get("type") == "invalidate":
            # drop this condition's rows recorded after the LAST playtest of the checkpoint step
            c, cut = r["condition"], r["after_step"]
            idx = max((i for i, x in enumerate(out)
                       if x.get("condition") == c and x.get("step") == cut and x.get("type") == "playtest"), default=-1)
            out = [x for i, x in enumerate(out) if i <= idx or x.get("condition") != c]
            continue
        out.append(r)
    # a session re-run before its playtest (harness restart) supersedes the earlier attempt
    dedup = []
    for r in out:
        if r.get("type") == "session" and dedup:
            prev = next((x for x in reversed(dedup) if x.get("condition") == r["condition"]), None)
            if prev and prev.get("type") == "session" and prev.get("step") == r["step"]:
                dedup.remove(prev)
        dedup.append(r)
    return dedup


def main(race: str = "blade") -> int:
    rows = load(race)
    sessions = [r for r in rows if r.get("type") == "session"]
    plays = [r for r in rows if r.get("type") == "playtest"]
    conds = ["none", "agentsmd", "devmemory"]
    L = [f"# Adaptive race: {race}", "",
         "Each prompt is a fresh headless Claude Code session (Sonnet). After every session the game is playtested in "
         "Roblox Studio by the same behavioural probe; the next prompt is a bug report built from failed checks, else the "
         "next roadmap feature (10 features, cap 16 prompts). Cost = CLI list-price equivalent. One run per condition: a "
         "case study, not a statistical result.", "",
         "| Condition | Prompts | Feature prompts | Fix prompts | Total cost | Input tokens | Features reached | Failing checks at end |",
         "|---|---|---|---|---|---|---|---|"]
    for c in conds:
        s = [r for r in sessions if r["condition"] == c]
        p = [r for r in plays if r["condition"] == c]
        if not s:
            continue
        feats = sum(1 for r in s if r["kind"] == "feature")
        fixes = sum(1 for r in s if r["kind"] == "fix")
        cost = sum(r.get("cost_usd_list") or 0 for r in s)
        tok = sum(r.get("total_input_tokens") or 0 for r in s)
        last = p[-1]["failed"] if p else []
        L.append(f"| {c} | {len(s)} | {feats} | {fixes} | ${cost:.2f} | {tok:,} | {feats}/10 | {', '.join(last) or 'none'} |")
    L += ["", "## Timeline (prompt kind → failed checks after playtest)", ""]
    for c in conds:
        p = {r["step"]: r for r in plays if r["condition"] == c}
        seq = []
        for r in [x for x in sessions if x["condition"] == c]:
            f = p.get(r["step"], {}).get("failed")
            seq.append(f"{r['step']} ({'✓' if f == [] else ('✗ ' + ','.join(f)) if f else '?'})")
        L.append(f"- **{c}**: " + " → ".join(seq))
    L += ["", "## Protocol changes made during the race (applied to all conditions from that point on)", ""]
    L += [f"{i}. {n}" for i, n in enumerate(PROTOCOL_NOTES, 1)]
    out = REPO / "results" / f"adaptive_{race}_report.md"
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L))
    return 0


if __name__ == "__main__":
    sys.exit(main(*(sys.argv[1:] or ["blade"])))

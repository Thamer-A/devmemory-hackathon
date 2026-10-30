"""Summarize a multi-session series benchmark (results/series_<name>.jsonl) into Markdown.

  python -m bench.series.report blade
Final adherence is recomputed with the CURRENT grader on the saved final projects.
"""
from __future__ import annotations

import collections
import importlib.util
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent


def main(series: str) -> int:
    rows = [json.loads(l) for l in (REPO / "results" / f"series_{series}.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    spec = importlib.util.spec_from_file_location("g", REPO / "bench" / "series" / series / "grade.py")
    g = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
    steps = [r for r in rows if r["step"] != "FINAL"]
    conds = [c for c in ("none", "agentsmd", "devmemory") if any(r["condition"] == c for r in steps)]
    agg = collections.defaultdict(lambda: collections.Counter())
    per = collections.defaultdict(dict)
    for r in steps:
        a = agg[(r["condition"], r["tag"])]
        a["cost"] += r["cost_usd_list"] or 0
        a["tok"] += r["total_input_tokens"] or 0
        a["out"] += r["output_tokens"] or 0
        a["turns"] += r["num_turns"] or 0
        a["tools"] += r["tool_calls"] or 0
        a["reads"] += r["files_read_unique"] or 0
        a["wall"] += r["wall_s"] or 0
        a["pack"] += r["pack_tokens_est"] or 0
        a["steps"] += 1
        per[(r["condition"], r["tag"])][r["step"]] = r
    L = [f"# Multi-session build: {series}", "",
         "Each step is a fresh headless Claude Code session (Sonnet) on the same evolving project. "
         "Cost = CLI list-price equivalent. Adherence = decisions from earlier sessions still honoured in the final code "
         "(static checks, `bench/series/" + series + "/grade.py`). One run per condition: a case study, not a statistical result.", "",
         "| Condition | Run | Steps | Total cost | Input tokens | Output tokens | Turns | Tool calls | Files read | Pack tokens (est) | Adherence |",
         "|---|---|---|---|---|---|---|---|---|---|---|"]
    for (c, tag), a in sorted(agg.items(), key=lambda kv: conds.index(kv[0][0])):
        final = g.grade(REPO / "results" / "series" / series / f"{c}_{tag}")
        L.append(f"| {c} | {tag} | {a['steps']} | ${a['cost']:.2f} | {a['tok']:,} | {a['out']:,} | {a['turns']} | "
                 f"{a['tools']} | {a['reads']} | {a['pack']:,} | {final['passed_checks']}/{final['total_checks']} |")
    L += ["", "## Cost per step ($)", "", "| Step | " + " | ".join(f"{c}" for c in conds) + " |",
          "|---|" + "---|" * len(conds)]
    step_ids = sorted({r["step"] for r in steps}, key=lambda s: int(s[1:]))
    for sid in step_ids:
        cells = []
        for c in conds:
            r = next((per[k][sid] for k in per if k[0] == c and sid in per[k]), None)
            cells.append(f"{r['cost_usd_list']:.3f} ({(r['total_input_tokens'] or 0) // 1000}k tok)" if r else "–")
        L.append(f"| {sid} | " + " | ".join(cells) + " |")
    out = REPO / "results" / f"series_{series}_report.md"
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "blade"))

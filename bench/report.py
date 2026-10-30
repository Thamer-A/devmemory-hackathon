"""Summarize benchmark JSONL into Markdown tables.

  python -m bench.report dev1 [dev2 ...] [--out results/dev1_report.md]

Headline: cost per successful task = (sum of list-price-equivalent cost over ALL runs, failures
included) / (number of passing runs), reported only next to success rate, with an accuracy floor.
"""
from __future__ import annotations

import argparse
import json
import math
import statistics as st
from collections import defaultdict
from pathlib import Path

RESULTS = Path(__file__).resolve().parent.parent / "results"


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def load(suites: list[str]) -> list[dict]:
    rows = []
    for s in suites:
        p = RESULTS / f"{s}.jsonl"
        rows += [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]
    return rows


def summarize(rows: list[dict]) -> dict:
    g = defaultdict(list)
    for r in rows:
        g[(r["condition"], r["model"])].append(r)
    out = {}
    for key, rs in sorted(g.items()):
        n, k = len(rs), sum(r["passed"] for r in rs)
        cost = sum(r["cost_usd_list"] or 0 for r in rs)
        out[key] = {
            "runs": n, "passed": k, "rate": k / n, "ci": wilson(k, n),
            "cost_total": cost, "cost_per_run": cost / n,
            "cost_per_success": (cost / k) if k else float("inf"),
            "tok_in": st.mean(r["total_input_tokens"] or 0 for r in rs),
            "tok_out": st.mean(r["output_tokens"] or 0 for r in rs),
            "turns": st.mean(r["num_turns"] or 0 for r in rs),
            "tools": st.mean(r["tool_calls"] or 0 for r in rs),
            "searches": st.mean(r["search_calls"] or 0 for r in rs),
            "reads": st.mean(r["files_read_unique"] or 0 for r in rs),
            "wall_p50": st.median(r["wall_s"] or 0 for r in rs),
            "pack_tok": st.mean(r["pack_tokens_est"] or 0 for r in rs),
        }
    return out


def render(rows: list[dict], title: str) -> str:
    s = summarize(rows)
    base = s.get(("C1", "haiku")) or next(iter(s.values()))
    floor = max(0.8, base["rate"])
    L = [f"# {title}", "",
         f"Runs: {len(rows)}. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription "
         f"spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) "
         f"= {floor:.0%}. Pack tokens are estimates (chars/4).", "",
         "| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok "
         "| Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for (c, m), v in s.items():
        L.append(f"| {c} | {m} | {v['passed']}/{v['runs']} | {v['rate']:.0%} ({v['ci'][0]:.0%}–{v['ci'][1]:.0%}) "
                 f"| {'yes' if v['rate'] >= floor else 'no'} | {v['cost_per_run']:.4f} | **{v['cost_per_success']:.4f}** "
                 f"| {v['tok_in']:,.0f} | {v['tok_out']:,.0f} | {v['turns']:.1f} | {v['tools']:.1f} "
                 f"| {v['searches']:.1f} | {v['reads']:.1f} | {v['wall_p50']:.0f} | {v['pack_tok']:.0f} |")
    # per task matrix
    conds = sorted({(r["condition"], r["model"]) for r in rows})
    tasks = sorted({(r["project"], r["task"], r["type"]) for r in rows})
    L += ["", "## Pass matrix (passed/runs, mean input tokens)", "",
          "| Task | Type | " + " | ".join(f"{c}/{m}" for c, m in conds) + " |",
          "|---|---|" + "---|" * len(conds)]
    for p, t, ty in tasks:
        cells = []
        for c, m in conds:
            rs = [r for r in rows if r["project"] == p and r["task"] == t and r["condition"] == c and r["model"] == m]
            if rs:
                cells.append(f"{sum(r['passed'] for r in rs)}/{len(rs)} · {st.mean(r['total_input_tokens'] or 0 for r in rs)/1000:.0f}k")
            else:
                cells.append("–")
        L.append(f"| {p}:{t} | {ty} | " + " | ".join(cells) + " |")
    # failing checks
    fails = defaultdict(lambda: defaultdict(int))
    for r in rows:
        if not r["passed"]:
            for k, v in (r.get("checks") or {}).items():
                if v is not True:
                    fails[(r["task"], r["condition"])][k] += 1
    if fails:
        L += ["", "## Failed checks", ""]
        for (t, c), d in sorted(fails.items()):
            L.append(f"- {t} {c}: " + ", ".join(f"{k}×{n}" for k, n in d.items()))
    # setup cost
    sp = RESULTS / "setup_costs.jsonl"
    if sp.exists():
        recs = [json.loads(l) for l in sp.read_text(encoding="utf-8").splitlines() if l.strip()]
        if recs:
            r = recs[-1]
            L += ["", "## Setup cost", "",
                  f"Scan of {r['project']}: {r['files']} files in {r['scan_s']} s, {r['llm_tokens']} LLM tokens. "
                  f"Session capture adds no model calls (it records sessions the user runs anyway). "
                  f"Break-even vs a bare session therefore needs no amortization of LLM setup cost; the "
                  f"only per-task overhead is the injected pack, which is included in each run's tokens."]
    return "\n".join(L) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("suites", nargs="+")
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    md = render(load(a.suites), "Results: " + ", ".join(a.suites))
    out = Path(a.out) if a.out else RESULTS / f"{'_'.join(a.suites)}_report.md"
    out.write_text(md, encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()

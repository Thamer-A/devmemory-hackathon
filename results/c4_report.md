# Results: c4

Runs: 32. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 81%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | sonnet | 13/16 | 81% (57%–93%) | yes | 0.0499 | **0.0614** | 50,241 | 1,586 | 7.2 | 6.2 | 1.6 | 1.8 | 19 | 0 |
| C1 | sonnet | 12/16 | 75% (51%–90%) | no | 0.0474 | **0.0632** | 44,956 | 1,508 | 6.4 | 5.4 | 0.8 | 1.8 | 15 | 0 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/sonnet | C1/sonnet |
|---|---|---|---|
| P1:A1 | code | 2/2 · 81k | 2/2 · 49k |
| P1:A2 | code | 1/2 · 71k | 0/2 · 78k |
| P1:B1 | history | 0/2 · 26k | 0/2 · 18k |
| P1:B2 | history | 2/2 · 63k | 2/2 · 64k |
| P1:C1 | stale | 2/2 · 25k | 2/2 · 27k |
| P1:C2 | stale | 2/2 · 66k | 2/2 · 69k |
| P1:D1 | unrelated | 2/2 · 40k | 2/2 · 27k |
| P1:D2 | unrelated | 2/2 · 30k | 2/2 · 28k |

## Failed checks

- A2 C0: icon_in_manifest×1
- A2 C1: icon_in_manifest×2
- B1 C0: grant_via_currency_reason×2, reward_base_20×2, reward_per_day_10×2, utc_day_boundary×2, streak_cap_7_config×2, streak_cap_used×2
- B1 C1: grant_via_currency_reason×2, reward_base_20×2, reward_per_day_10×2, utc_day_boundary×2, streak_cap_7_config×2, streak_cap_used×2

## Setup cost

Scan of P1: 27 files in 0.029 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

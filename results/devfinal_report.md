# Results: devfinal

Runs: 134. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 88%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | haiku | 20/24 | 83% (64%–93%) | no | 0.0068 | **0.0082** | 145,990 | 4,665 | 12.5 | 11.5 | 2.0 | 3.6 | 20 | 0 |
| C0 | sonnet | 13/16 | 81% (57%–93%) | no | 0.0499 | **0.0614** | 50,241 | 1,586 | 7.2 | 6.2 | 1.6 | 1.8 | 19 | 0 |
| C1 | haiku | 21/24 | 88% (69%–96%) | yes | 0.0068 | **0.0077** | 128,029 | 4,818 | 11.3 | 10.3 | 1.2 | 2.6 | 20 | 0 |
| C1 | sonnet | 12/16 | 75% (51%–90%) | no | 0.0474 | **0.0632** | 44,956 | 1,508 | 6.4 | 5.4 | 0.8 | 1.8 | 15 | 0 |
| C2 | haiku | 19/24 | 79% (60%–91%) | no | 0.0063 | **0.0079** | 126,161 | 4,432 | 11.3 | 10.3 | 1.4 | 3.3 | 18 | 554 |
| C3 | haiku | 23/24 | 96% (80%–99%) | yes | 0.0051 | **0.0053** | 97,648 | 3,537 | 10.0 | 9.0 | 1.2 | 3.1 | 20 | 717 |
| C3nofresh | haiku | 6/6 | 100% (61%–100%) | yes | 0.0049 | **0.0049** | 80,403 | 3,737 | 7.8 | 6.8 | 1.7 | 1.2 | 21 | 636 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/haiku | C0/sonnet | C1/haiku | C1/sonnet | C2/haiku | C3/haiku | C3nofresh/haiku |
|---|---|---|---|---|---|---|---|---|
| P1:A1 | code | 3/3 · 295k | 2/2 · 81k | 3/3 · 162k | 2/2 · 49k | 3/3 · 242k | 3/3 · 153k | – |
| P1:A2 | code | 2/3 · 126k | 1/2 · 71k | 3/3 · 94k | 0/2 · 78k | 1/3 · 68k | 2/3 · 105k | – |
| P1:B1 | history | 0/3 · 351k | 0/2 · 26k | 0/3 · 405k | 0/2 · 18k | 0/3 · 387k | 3/3 · 264k | – |
| P1:B2 | history | 3/3 · 132k | 2/2 · 63k | 3/3 · 119k | 2/2 · 64k | 3/3 · 109k | 3/3 · 66k | – |
| P1:C1 | stale | 3/3 · 37k | 2/2 · 25k | 3/3 · 40k | 2/2 · 27k | 3/3 · 32k | 3/3 · 31k | 3/3 · 35k |
| P1:C2 | stale | 3/3 · 147k | 2/2 · 66k | 3/3 · 134k | 2/2 · 69k | 3/3 · 108k | 3/3 · 102k | 3/3 · 126k |
| P1:D1 | unrelated | 3/3 · 43k | 2/2 · 40k | 3/3 · 31k | 2/2 · 27k | 3/3 · 30k | 3/3 · 31k | – |
| P1:D2 | unrelated | 3/3 · 36k | 2/2 · 30k | 3/3 · 39k | 2/2 · 28k | 3/3 · 34k | 3/3 · 30k | – |

## Failed checks

- A2 C0: icon_in_manifest×2
- A2 C1: icon_in_manifest×2
- A2 C2: icon_in_manifest×2
- A2 C3: icon_in_manifest×1
- B1 C0: grant_via_currency_reason×3, reward_base_20×5, reward_per_day_10×4, utc_day_boundary×3, streak_cap_7_config×5, streak_cap_used×5
- B1 C1: reward_base_20×5, reward_per_day_10×5, streak_cap_7_config×5, streak_cap_used×5, grant_via_currency_reason×2, utc_day_boundary×2
- B1 C2: reward_base_20×2, streak_cap_7_config×3, streak_cap_used×3, reward_per_day_10×1, utc_day_boundary×1

## Setup cost

Scan of P1: 27 files in 0.024 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

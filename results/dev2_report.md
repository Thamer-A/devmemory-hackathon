# Results: dev2

Runs: 102. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 88%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | haiku | 20/24 | 83% (64%–93%) | no | 0.0068 | **0.0082** | 145,990 | 4,665 | 12.5 | 11.5 | 2.0 | 3.6 | 20 | 0 |
| C1 | haiku | 21/24 | 88% (69%–96%) | yes | 0.0068 | **0.0077** | 128,029 | 4,818 | 11.3 | 10.3 | 1.2 | 2.6 | 20 | 0 |
| C2 | haiku | 21/24 | 88% (69%–96%) | yes | 0.0060 | **0.0068** | 121,086 | 4,100 | 11.7 | 10.7 | 1.4 | 3.9 | 24 | 541 |
| C3 | haiku | 22/24 | 92% (74%–98%) | yes | 0.0055 | **0.0060** | 101,836 | 3,849 | 10.2 | 9.2 | 1.6 | 3.0 | 18 | 703 |
| C3nofresh | haiku | 6/6 | 100% (61%–100%) | yes | 0.0047 | **0.0047** | 73,616 | 3,624 | 7.8 | 6.8 | 1.5 | 1.2 | 17 | 627 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/haiku | C1/haiku | C2/haiku | C3/haiku | C3nofresh/haiku |
|---|---|---|---|---|---|---|
| P1:A1 | code | 3/3 · 295k | 3/3 · 162k | 3/3 · 246k | 3/3 · 186k | – |
| P1:A2 | code | 2/3 · 126k | 3/3 · 94k | 3/3 · 163k | 1/3 · 98k | – |
| P1:B1 | history | 0/3 · 351k | 0/3 · 405k | 0/3 · 240k | 3/3 · 259k | – |
| P1:B2 | history | 3/3 · 132k | 3/3 · 119k | 3/3 · 96k | 3/3 · 78k | – |
| P1:C1 | stale | 3/3 · 37k | 3/3 · 40k | 3/3 · 31k | 3/3 · 31k | 3/3 · 32k |
| P1:C2 | stale | 3/3 · 147k | 3/3 · 134k | 3/3 · 130k | 3/3 · 98k | 3/3 · 115k |
| P1:D1 | unrelated | 3/3 · 43k | 3/3 · 31k | 3/3 · 30k | 3/3 · 31k | – |
| P1:D2 | unrelated | 3/3 · 36k | 3/3 · 39k | 3/3 · 34k | 3/3 · 34k | – |

## Failed checks

- A2 C0: icon_in_manifest×1
- A2 C3: icon_in_manifest×2
- B1 C0: grant_via_currency_reason×1, reward_base_20×3, reward_per_day_10×2, utc_day_boundary×1, streak_cap_7_config×3, streak_cap_used×3
- B1 C1: reward_base_20×3, reward_per_day_10×3, streak_cap_7_config×3, streak_cap_used×3
- B1 C2: reward_base_20×3, reward_per_day_10×3, streak_cap_7_config×3, streak_cap_used×3, grant_via_currency_reason×1, utc_day_boundary×1

## Setup cost

Scan of P1: 27 files in 0.026 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

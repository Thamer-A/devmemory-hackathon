# Results: dev1

Runs: 32. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 88%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | haiku | 6/8 | 75% (41%–93%) | no | 0.0081 | **0.0107** | 168,077 | 5,720 | 14.5 | 13.5 | 1.4 | 5.4 | 24 | 0 |
| C1 | haiku | 7/8 | 88% (53%–98%) | yes | 0.0063 | **0.0072** | 130,494 | 4,345 | 10.6 | 9.6 | 1.1 | 2.8 | 17 | 0 |
| C2 | haiku | 7/8 | 88% (53%–98%) | yes | 0.0067 | **0.0077** | 136,926 | 4,858 | 11.6 | 10.6 | 1.2 | 4.2 | 16 | 541 |
| C3 | haiku | 7/8 | 88% (53%–98%) | yes | 0.0060 | **0.0068** | 112,557 | 4,273 | 9.4 | 8.4 | 1.2 | 2.2 | 24 | 721 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/haiku | C1/haiku | C2/haiku | C3/haiku |
|---|---|---|---|---|---|
| P1:A1 | code | 1/1 · 167k | 1/1 · 120k | 1/1 · 210k | 1/1 · 242k |
| P1:A2 | code | 0/1 · 144k | 1/1 · 74k | 1/1 · 100k | 1/1 · 110k |
| P1:B1 | history | 0/1 · 707k | 0/1 · 535k | 0/1 · 568k | 0/1 · 337k |
| P1:B2 | history | 1/1 · 124k | 1/1 · 81k | 1/1 · 59k | 1/1 · 61k |
| P1:C1 | stale | 1/1 · 48k | 1/1 · 40k | 1/1 · 42k | 1/1 · 31k |
| P1:C2 | stale | 1/1 · 73k | 1/1 · 124k | 1/1 · 56k | 1/1 · 58k |
| P1:D1 | unrelated | 1/1 · 43k | 1/1 · 30k | 1/1 · 30k | 1/1 · 30k |
| P1:D2 | unrelated | 1/1 · 39k | 1/1 · 40k | 1/1 · 30k | 1/1 · 30k |

## Failed checks

- A2 C0: icon_in_manifest×1
- B1 C0: streak_cap_7_config×1, streak_cap_used×1
- B1 C1: streak_cap_7_config×1, streak_cap_used×1
- B1 C2: streak_cap_7_config×1, streak_cap_used×1
- B1 C3: grant_via_currency_reason×1

## Setup cost

Scan of P1: 27 files in 0.026 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

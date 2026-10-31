# Results: heldout_v2

Runs: 36. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 83%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C3 | haiku | 30/36 | 83% (68%–92%) | yes | 0.0082 | **0.0099** | 180,688 | 6,013 | 14.6 | 13.6 | 0.8 | 4.0 | 24 | 1212 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C3/haiku |
|---|---|---|
| P1:H1 | code | 3/3 · 122k |
| P1:H2 | history | 3/3 · 43k |
| P1:H3 | stale | 3/3 · 180k |
| P1:H4 | unrelated | 3/3 · 32k |
| P2:A1 | code | 3/3 · 197k |
| P2:A2 | code | 3/3 · 181k |
| P2:B1 | history | 1/3 · 526k |
| P2:B2 | history | 1/3 · 436k |
| P2:C1 | stale | 3/3 · 149k |
| P2:C2 | stale | 3/3 · 114k |
| P2:D1 | unrelated | 1/3 · 134k |
| P2:D2 | unrelated | 3/3 · 54k |

## Failed checks

- B1 C3: tests_pass×2
- B2 C3: tests_pass×2
- D1 C3: tests_pass×2

## Setup cost

Scan of P2: 26 files in 0.25 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

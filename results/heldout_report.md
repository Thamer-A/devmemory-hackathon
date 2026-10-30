# Results: heldout

Runs: 201. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 80%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | haiku | 24/36 | 67% (50%–80%) | no | 0.0066 | **0.0099** | 136,782 | 4,609 | 13.7 | 12.7 | 1.1 | 3.3 | 24 | 0 |
| C0 | sonnet | 18/24 | 75% (55%–88%) | no | 0.0691 | **0.0922** | 70,005 | 2,348 | 10.1 | 9.1 | 1.4 | 2.3 | 21 | 0 |
| C1 | haiku | 26/36 | 72% (56%–84%) | no | 0.0075 | **0.0104** | 152,605 | 5,469 | 13.2 | 12.2 | 0.8 | 1.9 | 25 | 0 |
| C1 | sonnet | 18/24 | 75% (55%–88%) | no | 0.0784 | **0.1045** | 80,221 | 2,931 | 11.0 | 10.0 | 1.2 | 2.1 | 26 | 0 |
| C2 | haiku | 23/36 | 64% (48%–78%) | no | 0.0060 | **0.0094** | 113,504 | 4,364 | 12.2 | 11.2 | 0.8 | 3.9 | 21 | 630 |
| C3 | haiku | 31/36 | 86% (71%–94%) | yes | 0.0075 | **0.0087** | 150,330 | 5,682 | 14.5 | 13.5 | 0.5 | 5.1 | 21 | 913 |
| C3nofresh | haiku | 9/9 | 100% (70%–100%) | yes | 0.0064 | **0.0064** | 116,746 | 4,462 | 13.4 | 12.4 | 0.4 | 4.8 | 23 | 990 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/haiku | C0/sonnet | C1/haiku | C1/sonnet | C2/haiku | C3/haiku | C3nofresh/haiku |
|---|---|---|---|---|---|---|---|---|
| P1:H1 | code | 3/3 · 94k | 2/2 · 67k | 3/3 · 97k | 2/2 · 77k | 3/3 · 107k | 3/3 · 83k | – |
| P1:H2 | history | 0/3 · 63k | 0/2 · 26k | 0/3 · 65k | 0/2 · 18k | 0/3 · 53k | 3/3 · 62k | – |
| P1:H3 | stale | 3/3 · 153k | 2/2 · 58k | 3/3 · 115k | 2/2 · 57k | 3/3 · 89k | 3/3 · 126k | 3/3 · 92k |
| P1:H4 | unrelated | 3/3 · 43k | 2/2 · 40k | 0/3 · 70k | 0/2 · 51k | 3/3 · 32k | 3/3 · 32k | – |
| P2:A1 | code | 2/3 · 181k | 2/2 · 124k | 3/3 · 156k | 2/2 · 105k | 3/3 · 165k | 3/3 · 134k | – |
| P2:A2 | code | 2/3 · 190k | 2/2 · 87k | 3/3 · 138k | 2/2 · 76k | 3/3 · 100k | 3/3 · 108k | – |
| P2:B1 | history | 0/3 · 44k | 0/2 · 22k | 0/3 · 171k | 0/2 · 22k | 0/3 · 46k | 1/3 · 500k | – |
| P2:B2 | history | 2/3 · 387k | 2/2 · 105k | 2/3 · 406k | 2/2 · 147k | 0/3 · 297k | 3/3 · 359k | – |
| P2:C1 | stale | 3/3 · 132k | 2/2 · 48k | 3/3 · 199k | 2/2 · 122k | 3/3 · 105k | 3/3 · 129k | 3/3 · 120k |
| P2:C2 | stale | 3/3 · 186k | 2/2 · 159k | 3/3 · 239k | 2/2 · 134k | 2/3 · 222k | 3/3 · 120k | 3/3 · 138k |
| P2:D1 | unrelated | 0/3 · 113k | 0/2 · 65k | 3/3 · 113k | 2/2 · 87k | 0/3 · 98k | 0/3 · 101k | – |
| P2:D2 | unrelated | 3/3 · 53k | 2/2 · 40k | 3/3 · 63k | 2/2 · 66k | 3/3 · 50k | 3/3 · 50k | – |

## Failed checks

- A1 C0: tests_pass×1
- A2 C0: tests_pass×1
- B1 C0: tests_pass×5
- B1 C1: tests_pass×5
- B1 C2: tests_pass×3
- B1 C3: tests_pass×2
- B2 C0: tests_pass×1
- B2 C1: tests_pass×1
- B2 C2: tests_pass×3
- C2 C2: tests_pass×1
- D1 C0: tests_pass×5
- D1 C2: tests_pass×3
- D1 C3: tests_pass×3
- H2 C0: base_20×5, cap_7×5, module_exists×3, coinsFor_defined×3, returns_module×3, per_day_10×3, cap_applied×3
- H2 C1: base_20×5, per_day_10×4, cap_7×5, module_exists×3, coinsFor_defined×3, returns_module×3, cap_applied×3
- H2 C2: base_20×3, per_day_10×2, cap_7×2, module_exists×1, coinsFor_defined×1, returns_module×1, cap_applied×1
- H4 C1: default_1e6×5

## Setup cost

Scan of P2: 26 files in 0.023 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

# Results: heldout2

Runs: 192. Cost is the CLI's `total_cost_usd` (API list-price equivalent, not subscription spend). Cost per success = all-run cost / passing runs. Accuracy floor = max(80%, C1 success rate) = 80%. Pack tokens are estimates (chars/4).

| Condition | Model | Pass | Rate (95% CI) | Meets floor | $/run | **$/success** | Input tok | Output tok | Turns | Tool calls | Searches | Files read | Wall p50 s | Pack tok (est) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C0 | haiku | 38/48 | 79% (66%–88%) | no | 0.0075 | **0.0095** | 152,872 | 5,537 | 14.1 | 13.1 | 1.4 | 3.5 | 26 | 0 |
| C1 | haiku | 38/48 | 79% (66%–88%) | no | 0.0084 | **0.0106** | 180,482 | 6,112 | 13.1 | 12.1 | 1.0 | 2.3 | 30 | 0 |
| C2 | haiku | 39/48 | 81% (68%–90%) | yes | 0.0075 | **0.0093** | 156,060 | 5,603 | 12.9 | 11.9 | 1.1 | 3.3 | 25 | 615 |
| C3 | haiku | 47/48 | 98% (89%–100%) | yes | 0.0075 | **0.0076** | 148,391 | 5,297 | 12.4 | 11.4 | 0.9 | 3.2 | 29 | 1280 |

## Pass matrix (passed/runs, mean input tokens)

| Task | Type | C0/haiku | C1/haiku | C2/haiku | C3/haiku |
|---|---|---|---|---|---|
| P1:H10 | stale | 3/3 · 268k | 3/3 · 243k | 3/3 · 238k | 3/3 · 175k |
| P1:H11 | unrelated | 2/3 · 40k | 3/3 · 30k | 3/3 · 31k | 3/3 · 34k |
| P1:H12 | unrelated | 3/3 · 95k | 3/3 · 57k | 3/3 · 73k | 3/3 · 58k |
| P1:H5 | code | 3/3 · 156k | 3/3 · 191k | 3/3 · 164k | 3/3 · 189k |
| P1:H6 | code | 3/3 · 85k | 3/3 · 109k | 3/3 · 79k | 3/3 · 98k |
| P1:H7 | history | 0/3 · 50k | 0/3 · 74k | 0/3 · 70k | 3/3 · 78k |
| P1:H8 | history | 3/3 · 95k | 3/3 · 82k | 3/3 · 67k | 3/3 · 54k |
| P1:H9 | stale | 3/3 · 80k | 3/3 · 72k | 3/3 · 71k | 3/3 · 63k |
| P2:E1 | code | 2/3 · 177k | 3/3 · 243k | 3/3 · 239k | 3/3 · 222k |
| P2:E2 | code | 3/3 · 290k | 3/3 · 406k | 3/3 · 344k | 2/3 · 283k |
| P2:E3 | history | 1/3 · 318k | 0/3 · 431k | 0/3 · 356k | 3/3 · 252k |
| P2:E4 | history | 0/3 · 155k | 0/3 · 223k | 0/3 · 249k | 3/3 · 214k |
| P2:E5 | stale | 3/3 · 272k | 2/3 · 314k | 3/3 · 237k | 3/3 · 238k |
| P2:E6 | stale | 3/3 · 158k | 3/3 · 230k | 3/3 · 152k | 3/3 · 209k |
| P2:E7 | unrelated | 3/3 · 106k | 3/3 · 92k | 3/3 · 58k | 3/3 · 96k |
| P2:E8 | unrelated | 3/3 · 100k | 3/3 · 91k | 3/3 · 68k | 3/3 · 111k |

## Failed checks

- E1 C0: tests_pass×1
- E2 C3: tests_pass×1
- E3 C0: tests_pass×2
- E3 C1: tests_pass×3
- E3 C2: tests_pass×3
- E4 C0: tests_pass×3
- E4 C1: tests_pass×3
- E4 C2: tests_pass×3
- E5 C1: tests_pass×1
- H11 C0: negative_as_zero×1
- H7 C0: cap_7_config×3, cap_read_from_config×3, cap_applied×3
- H7 C1: cap_7_config×3, cap_read_from_config×3, cap_applied×3
- H7 C2: cap_7_config×3, cap_read_from_config×3, cap_applied×3

## Setup cost

Scan of P2: 26 files in 0.022 s, 0 LLM tokens. Session capture adds no model calls (it records sessions the user runs anyway). Break-even vs a bare session therefore needs no amortization of LLM setup cost; the only per-task overhead is the injected pack, which is included in each run's tokens.

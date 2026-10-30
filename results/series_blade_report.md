# Multi-session build: blade

Each step is a fresh headless Claude Code session (Sonnet) on the same evolving project. Cost = CLI list-price equivalent. Adherence = decisions from earlier sessions still honoured in the final code (static checks, `bench/series/blade/grade.py`). One run per condition: a case study, not a statistical result.

| Condition | Run | Steps | Total cost | Input tokens | Output tokens | Turns | Tool calls | Files read | Pack tokens (est) | Adherence |
|---|---|---|---|---|---|---|---|---|---|---|
| none | r1 | 8 | $1.25 | 1,055,313 | 58,414 | 122 | 114 | 33 | 0 | 24/24 |
| agentsmd | r1 | 8 | $1.39 | 1,204,101 | 70,406 | 139 | 131 | 26 | 0 | 24/24 |
| devmemory | r1 | 8 | $1.04 | 605,183 | 50,432 | 92 | 84 | 21 | 3,624 | 24/24 |

## Cost per step ($)

| Step | none | agentsmd | devmemory |
|---|---|---|---|
| S1 | 0.130 (63k tok) | 0.151 (85k tok) | 0.124 (47k tok) |
| S2 | 0.111 (62k tok) | 0.135 (64k tok) | 0.102 (51k tok) |
| S3 | 0.076 (47k tok) | 0.098 (54k tok) | 0.072 (36k tok) |
| S4 | 0.337 (329k tok) | 0.346 (239k tok) | 0.234 (110k tok) |
| S5 | 0.260 (245k tok) | 0.318 (484k tok) | 0.224 (155k tok) |
| S6 | 0.067 (80k tok) | 0.077 (57k tok) | 0.061 (51k tok) |
| S7 | 0.098 (77k tok) | 0.134 (139k tok) | 0.082 (39k tok) |
| S8 | 0.166 (149k tok) | 0.129 (77k tok) | 0.141 (113k tok) |

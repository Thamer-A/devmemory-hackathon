# STATUS (updated 2026-10-30, Fri afternoon ET)

## Done
- Telemetry check (`bench/TELEMETRY.md`) and proposal (`bench/PROPOSAL.md`). User approved; branch renamed to `main`.
- `devmem/`, all deterministic with 0 LLM tokens:
  - `claude_cli.py`: headless runner and stream-json parser
  - `capture.py`: session records plus digest with file hashes
  - `scan.py`: map, symbols, deps, remotes, config keys, observed conventions
  - `pack.py`: BM25 retrieval, line-level freshness, decision sentences, token budget
  - `cli.py`: `devmem scan|run|import|pack|status|hook`
- P1 CoinRush fixture: 27 Luau files, 5 captured session-0 runs, then an uncaptured v2 refactor. See `bench/projects/P1/PLANTED.md`.
- 8 P1 dev tasks with graders. Negative controls pass (`python -m bench.validate_graders`).
- `bench/run.py` runner, `bench/report.py` tables.
- Pilot `pilot0` (8 runs, C0/C1). Quota: 7-day meter unchanged at 18%.

## Dev results (results/devfinal_report.md)
- P1 dev, Haiku: C3 96% pass, $0.0053/success vs C1 88% $0.0077 (-31%), C0 83% $0.0082 (-35%); input tokens -24% vs C1.
- B1 (history-only) passes only with C3 (3/3; all others 0).
- C2 (static map only) is not better than C1; the gain comes from session memory.
- C3nofresh 6/6 on stale tasks: freshness flags did not change success here (agents read current code anyway).
- C4: Sonnet C0/C1 75-81% at $0.061-0.063/success (about 11x Haiku+C3).

## In progress (old)
- Held-out set frozen (12 tasks, TOTAL 1ed3462b...). Waiting for user OK (gate c) to run it.

## Next
- Read dev1, fix what the data says, then dev2 with 3 repeats and C3nofresh on the C tasks.
- P2: run `make_history P2`, then `apply_v2.py`.
- A separate agent writes and hash-freezes held-out tasks for P1 and P2. Gate (c): user OK before the held-out run.
- C4: Haiku+C3 vs Sonnet+C0/C1 on a subset.
- Charts, README with one-command repro, deck, video.

## Known issues
- Never write Python containing `\\` escapes through a bash heredoc in this environment: backslashes get collapsed. Use the Write tool.
- Don't leave the shell cwd inside a fixture dir (Windows locks it, and `rmtree` fails).
- Downloading the official `luau` CLI was blocked by the permission classifier, so P1 graders are static only.
- `total_cost_usd` is API list-price equivalent, not subscription spend.

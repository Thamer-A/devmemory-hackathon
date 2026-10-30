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

## Waiting
- Held-out set frozen (12 tasks: P1 H1–H4, P2 A1–D2; TOTAL 1ed3462b…). P2 fixture done (56 tests, 5 captured sessions, v2 refactor). Gate (c): user OK needed before the held-out run.

## Running / demo game (Fri ~3:30 PM ET)
- Held-out run started (suite `heldout`, code rev at launch logged in rows). Do not tune after seeing results.
- Demo game changed per user: "Blade Swarm" (orbiting blades vs zombie waves, coins per kill, random upgrade shop between waves). Rojo project in `demo/blade-swarm/`, written by a Sonnet subagent. CoinRush (P1) stays frozen as the benchmark fixture.
- Tooling: Rojo 7.7.1 at `C:\Users\thfal\tools\rojo-7.7.1\rojo.exe`, Rojo Studio plugin installed. Roblox Studio built-in MCP registered (`claude mcp add Roblox_Studio`, local scope). Its tools need a Claude Code restart (`claude --continue`) and "Enable Studio as MCP server" in Studio (Assistant > ... > Manage MCP Servers).
- Plan after restart: `rojo serve demo/blade-swarm/default.project.json` -> Rojo plugin Connect -> use the Studio MCP to build the map, lighting, Creator Store zombie model and props, playtest, fix -> save the place.

## Next
- Held-out run: 12 tasks × C0, C1, C2, C3 × 3 repeats (Haiku), C3nofresh on the stale tasks, C0/C1 × 2 on Sonnet. One time only, then report as-is.
- Charts, deck (8–10 slides), video (3 min or less), project page.

## Known issues
- Never write Python containing `\\` escapes through a bash heredoc in this environment: backslashes get collapsed. Use the Write tool.
- Don't leave the shell cwd inside a fixture dir (Windows locks it, and `rmtree` fails).
- Downloading the official `luau` CLI was blocked by the permission classifier, so P1 graders are static only.
- `total_cost_usd` is API list-price equivalent, not subscription spend.

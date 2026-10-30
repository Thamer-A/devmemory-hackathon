# STATUS

## Done
- Repo skeleton (`devmem/`, `bench/`, `results/`).
- Telemetry check: see `bench/TELEMETRY.md`. Tokens, list-price cost, turns, latency, tool calls and quota utilization are all available from `claude -p` json/stream-json.
- Benchmark proposal: `bench/PROPOSAL.md` (P1 Roblox synthetic, P2 Python held-out, 8 dev tasks, conditions).

## Next (blocked on user OK at gates a+b)
- Generate P1 project + PLANTED.md, session-0 history fixtures.
- Write graders for 8 dev tasks, then runner (`bench/run.py`) and report script.
- Pilot 8 runs to measure quota burn.

## Known issues
- `--bare` unusable (needs API key); isolation via `--setting-sources project --strict-mcp-config --tools ...`.
- `total_cost_usd` is API list-price equivalent, not subscription spend.
- P1 graders are static (no Luau execution) unless `lune` is added.

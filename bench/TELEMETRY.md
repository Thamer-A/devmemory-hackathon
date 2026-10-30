# Telemetry check (Hour 0–1), 2026-10-30

Claude Code 2.1.310, Windows 11, subscription auth (no API key). All runs headless via `claude -p`, model `haiku` (resolves to `claude-haiku-5-5`).

## What `--output-format json` returns (final `result` object)

| Field | Use |
|---|---|
| `usage.input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens` | token counts, summed over the run |
| `usage.output_tokens_details.thinking_tokens` | thinking tokens (count only, no content) |
| `usage.iterations[]` | per-API-call usage |
| `modelUsage.<model>.{inputTokens,outputTokens,cache*,costUSD,contextWindow}` | per-model breakdown (needed if subagents use another model) |
| `total_cost_usd` | **API list-price equivalent** (`costBasis: "list"`), not what the subscription is billed. Use as a consistent cost proxy and label it that way. |
| `num_turns`, `duration_ms`, `duration_api_ms`, `ttft_ms` | turns and latency |
| `subtype` (`success`/error), `is_error`, `terminal_reason`, `permission_denials[]` | run outcome (agent-side, not task success) |
| `session_id` | session reference for provenance |
| `subagent_stats` | subagent spawns (should be 0 in eval runs) |

## What `--output-format stream-json --verbose` adds

- `system/init`: model, tool list, MCP servers, `memory_paths`, plugins, cwd.
- `assistant` messages: each `tool_use` block (name + full input) and per-call `usage`.
- `user` messages: each `tool_result` (content, `is_error`).
- `rate_limit_event`: **subscription quota utilization**, `five_hour.utilization` and `seven_day.utilization` (0.01 and 0.18 at test time). The runner logs this before/after each batch to measure quota burn.
- `result`: same object as the json format.

So tool calls, files read and edited, and per-turn tokens can all be counted from documented output. No private transcript files are needed.

## Fixed prompt overhead (trivial "Reply OK" task)

| Flags | Prompt tokens on turn 1 |
|---|---|
| defaults (user settings, MCP connectors, full tool set) | ~31.4k |
| `--setting-sources project --strict-mcp-config` | ~24.1k |
| as above, plus `--tools Read Edit Write Glob Grep Bash` | ~8.7k |

## Eval run settings (identical across conditions)

```
claude -p "<task>" --output-format stream-json --verbose --model <m> \
  --setting-sources project --strict-mcp-config --no-session-persistence \
  --tools Read Edit Write Glob Grep Bash --permission-mode acceptEdits \
  --max-turns <cap> < /dev/null
```

- `--bare` would be the cleanest isolation, but it requires `ANTHROPIC_API_KEY`, so it can't be used with subscription auth.
- `--setting-sources project` drops the user's global settings and hooks. The project's own `CLAUDE.md`/`AGENTS.md` still load, which is how condition C1 is delivered.
- Auto-memory is keyed by cwd. Each run uses a fresh copy of the project in its own directory, so no memory leaks between runs.
- Pass `< /dev/null`. Otherwise the CLI waits 3 s for stdin.

## Sample tool run

Task: "Change MaxCoins to 250 in the config module" on a 2-file Luau project, Haiku. 5 turns (Grep, Glob, Read, Edit), 8 input + 90.5k cache-read + 8.5k cache-write + 812 output tokens, $0.0030 list-equivalent, 7.2 s. Edit verified on disk.

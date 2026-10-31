# DevMemory (working name)

Entry for the HUMAIN–Misk Future AI Builders Hackathon, **Challenge 2: Deliver AI with Less Compute**.

AI coding agents start every session cold. They re-explore the project, re-read the same files, and forget decisions made in earlier sessions. DevMemory is a local-first memory layer that fixes this cheaply. It **preserves everything** and **sends only what earns its tokens**.

1. **Scan** the project deterministically: file inventory, symbols, require/import graph, Roblox remotes/config/assets, and *observed* conventions such as "`Instance.new("RemoteEvent")` occurs only in `Remotes.luau`". This costs **0 LLM tokens** and takes about 25 ms on the test projects.
2. **Capture** every AI session through documented interfaces only: Claude Code `stream-json`, Codex `exec --json`, or, for any other tool, a snapshot diff of the project. The record keeps prompts, visible output, tool calls, edits, file hashes and usage. It contains no hidden reasoning. Fields a tool does not expose are left empty, never guessed.
3. **Pack**: for a new task, retrieve only what is relevant, within a token budget (about 1k tokens). That means:
   - the user's earlier requirements, verbatim
   - the session where the feature was first requested
   - relevant files with evidence lines, every item with its source
   - **line-level freshness**: each remembered edit is compared with the current code, and memories whose code has since changed are flagged **STALE** instead of being silently trusted.
4. **Deliver** to any tool:
   - a Claude Code `UserPromptSubmit` hook, or `--append-system-prompt`
   - an **MCP server** for any MCP client
   - the pack prepended to a CLI agent's prompt (`devmem codex`, `devmem wrap`)
   - a Markdown file

Results, methodology and every disclosure: **[RESULTS.md](RESULTS.md)** and [bench/METHODOLOGY.md](bench/METHODOLOGY.md).

## Quick start

```bash
pip install -e .                                   # stdlib only; Python 3.10+
devmem scan  --project path/to/project             # .devmemory/PROJECT.md + index (0 LLM tokens)
devmem run   "fix the shop cooldown" --project P   # headless Claude Code session, captured
devmem pack  "make the Brute deal 35 damage" --project P --budget 1500
devmem status --project P                          # captured sessions and their freshness
devmem app                                         # desktop app (memory vault, graph, Pack Lab)
```

On Windows you can also double-click `DevMemory.bat` to open the app.

**Claude Code hook** (automatic pack on every prompt), in the project's `.claude/settings.json`:
```json
{"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "devmem hook"}]}]}}
```

## Any AI tool ([docs/ANY_TOOL.md](docs/ANY_TOOL.md))

```bash
devmem mcp   --project P                           # MCP server: get_context_pack, list_sessions, read_session,
                                                   #   begin_session, end_session (tested: Claude Code, Codex)
devmem codex "<task>" [--mcp] [--isolated]         # Codex CLI with the pack; session captured
devmem wrap  --prompt "<task>" -- <cmd with {prompt}>   # any CLI agent
devmem begin ... devmem end --prompt "<task>"      # IDE agents (Cursor, Copilot): capture the diff
```

Memory recorded with one tool can be used in another. `demo/cross-tool/` gives Codex memory that was recorded in Claude Code; see RESULTS.md for the outcome.

## Demos

- `demo/BladeSwarm_Final.rbxl`: the Roblox game used for the multi-session builds. Open it in Roblox Studio.
- `demo/memory-example/blade-swarm-race/`: a real memory vault to browse in the app.
- `demo/taskboard/run_demo.py`: the three task-board apps from the web race, run side by side with the same cards.
- `demo/cross-tool/run_demo.py`: memory from Claude Code used by Codex (pack vs. MCP vs. no memory).

## Reproduce the benchmark

Requires the Claude Code CLI logged in (`claude -p` works). Runs use isolated settings (see `bench/TELEMETRY.md`).

```bash
python -m bench.validate_graders                    # every grader: unmodified project FAILS, reference PASSES (no LLM)
python -m bench.verify_freeze                       # held-out set 1 unchanged since frozen
python -m bench.verify_freeze HELDOUT2_FREEZE.txt   # held-out set 2 unchanged since frozen
python -m bench.run --suite repro --split heldout2 --conditions C0,C1,C2,C3 --models haiku --repeats 3 --jobs 4
python -m bench.report repro                        # success rate, $/success, tokens, turns, tool calls
```

The multi-session races: `bench/adaptive_run.py` (Roblox, automatic Studio playtest after every prompt) and `bench/webrace_run.py` (web app, HTTP + headless-Chrome checks).

## Layout

- `devmem/`: the tool
  - `scan.py`: deterministic map and conventions
  - `capture.py`: Claude Code session records
  - `generic.py`: capture for any tool, plus the Codex adapter
  - `pack.py`: retrieval, freshness and budget
  - `mcp_server.py`: MCP server
  - `claude_cli.py`: headless runner and stream parser
  - `ui_server.py`, `ui/`: the desktop app
- `bench/projects/P1`: "CoinRush", a synthetic Rojo/Luau Roblox game with captured history and an uncaptured refactor that makes some memories stale. `bench/projects/P2`: "ledgerly", a synthetic Python app.
- `bench/tasks/`: tasks with automatic graders.
  - **Dev:** `P1/A1..D2`.
  - **Held-out set 1:** `P1/H1..H4`, `P2/A1..D2`.
  - **Held-out set 2:** `P1/H5..H12`, `P2/E1..E8`.
  - Both held-out sets were written by a separate agent and hash-frozen before any run.
- `results/`: JSONL per run and generated reports.

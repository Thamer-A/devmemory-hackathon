# DevMemory (working name)

Entry for the HUMAIN–Misk Future AI Builders Hackathon, **Challenge 2: Deliver AI with Less Compute**.

AI coding agents start every session cold. They re-explore the project, re-read the same files, and forget decisions made in earlier sessions. DevMemory is a local-first CLI that fixes this cheaply:

1. **Scan** the project deterministically: file inventory, symbols, require/import graph, Roblox remotes/config/assets, and *observed* conventions such as "`Instance.new("RemoteEvent")` occurs only in `Remotes.luau`". This costs **0 LLM tokens** and takes about 25 ms on the test projects.
2. **Capture** AI sessions through documented interfaces only (`claude -p --output-format stream-json`). The record keeps prompts, visible assistant output, tool calls, edits, file hashes and usage. It contains no hidden reasoning and reads no private transcript formats.
3. **Pack**: for a new task, retrieve only what earns its tokens. Relevant files with evidence lines, past sessions, and decisions stated in the user's own words, within a token budget, every item with its source. **Freshness check:** each remembered edit is compared with the current code line by line, and memories whose code has since changed are flagged STALE instead of being silently trusted.
4. **Deliver** the pack through `--append-system-prompt`, or automatically through a Claude Code `UserPromptSubmit` hook (`devmem hook`).

Headline metric: **cost per successful task at an accuracy floor**. It is measured against a bare session (C0) and against the best simple alternative, a hand-written `CLAUDE.md` (C1), with setup cost included.

## Quick start

```bash
pip install -e .                       # stdlib only; Python 3.10+
devmem scan --project path/to/game     # writes .devmemory/PROJECT.md + index (0 LLM tokens)
devmem run "fix the shop cooldown" --project path/to/game     # headless claude, captured
devmem pack "make the Brute deal 35 damage" --project path/to/game --budget 1500
devmem status --project path/to/game   # captured sessions and their freshness
```

Hook delivery, in `.claude/settings.json` of the project:
```json
{"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "devmem hook"}]}]}}
```

## Reproduce the benchmark (one command per step)

Requires the Claude Code CLI logged in (`claude -p` works). Runs use isolated settings (see `bench/TELEMETRY.md`).

```bash
python -m bench.validate_graders        # every grader: unmodified project FAILS, reference solution PASSES (no LLM)
python -m bench.verify_freeze           # held-out tasks unchanged since they were frozen
python -m bench.run --suite repro --split dev --conditions all --models haiku --repeats 3 --jobs 4
python -m bench.report repro            # tables: success rate, $/success, tokens, turns, tool calls
python -m bench.regrade repro           # re-apply current graders to saved diffs (no LLM)
```

## Layout

- `devmem/`: the CLI
  - `scan.py`: deterministic map and conventions
  - `capture.py`: session records
  - `pack.py`: retrieval, freshness and budget
  - `claude_cli.py`: headless runner and stream parser
- `bench/projects/P1`: "CoinRush", a synthetic Rojo/Luau Roblox game. It has captured history sessions and an uncaptured refactor that makes some memories stale. `PLANTED.md` explains how it was generated.
- `bench/projects/P2`: "ledgerly", a synthetic Python app. Held-out only.
- `bench/tasks/`: tasks with automatic graders. `P1/A1..D2` are the dev set. `P1/H1..H4` and `P2/*` are the held-out set, written by a separate agent and hash-frozen in `bench/HELDOUT_FREEZE.txt`.
- `results/`: JSONL per run and generated reports. Raw streams and diffs are in `results/raw/`.

See `bench/METHODOLOGY.md` for the experimental design and `STATUS.md` for current state.

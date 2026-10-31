# DevMemory: test results and methodology (summary)

All numbers come from logged runs in `results/`. Cost is the Claude Code CLI's `total_cost_usd`, an **API list-price equivalent** (the runs used a subscription). Full methods are in `bench/METHODOLOGY.md`. Conditions:
- **C0 / none:** nothing carries over between sessions.
- **C1 / AGENTS.md:** a hand-written project file (in the races, one the agent is told to keep updated).
- **C2:** the DevMemory map only.
- **C3 / devmemory:** full DevMemory (map + captured sessions + freshness).

## 1. Fixed benchmark: held-out set (run once, frozen before tuning)
- 12 unseen tasks: 4 on the Roblox game P1, 8 on the Python app P2. Written by a separate agent and hash-frozen (`bench/HELDOUT_FREEZE.txt`).
- 3 repeats, Claude Haiku 5.5, Sonnet 5.5 as the model-choice comparison.

| Condition | Pass (95% CI) | Meets 80% floor | $/success | Input tok/run |
|---|---|---|---|---|
| C0 bare | 67% (50–80) | no | $0.0099 | 137k |
| C1 CLAUDE.md | 72% (56–84) | no | $0.0104 | 153k |
| C2 map only | 64% (48–78) | no | $0.0094 | 114k |
| **C3 DevMemory** | **86% (71–94)** | **yes** | **$0.0087** | 150k |
| Sonnet, bare / CLAUDE.md | 75% / 75% | no | $0.092 / $0.105 | 70k / 80k |

- **Re-run with the shipped code.** The numbers above use the code as it was when the set was frozen. Retrieval changed afterwards (the web-race fix in section 4). That fix was tuned only on the web race, so these 12 tasks were still unseen by it. DevMemory (C3) was re-run once on the same 12 tasks × 3 repeats with the current code (`results/heldout_v2_report.md`):
  - **30/36 = 83% (68–92)**, versus 31/36 before. It is still above the 80% floor and still the only condition above it.
  - **$/success $0.0099** (was $0.0087). Input tokens per run were 181k (was 150k): packs grew by about 300 tokens because of the verbatim-requirement section.
  - Per task, one dropped from 3/3 to 1/3 and one rose from 0/3 to 1/3. The developer did not inspect the failures, so the held-out tasks stay unread.
- **Per project:**
  - Roblox P1: C3 12/12 vs C0 9/12, C1 6/12, C2 9/12.
  - Python P2: C3 19/24 vs C1 **20/24**, C0 15/24, C2 14/24. On P2 the hand-written file was slightly better.
- **Dev set** (8 P1 tasks, 3 repeats, `results/devfinal_report.md`): C3 96% at $0.0053/success, vs C1 88% at $0.0077 and C0 83% at $0.0082.
- **Ablations:**
  - Map alone (C2) never beat C1. The gains come from session memory.
  - Turning off the freshness flags (C3nofresh) did not change pass rates on stale-memory tasks.
- **History-dependent tasks** (decisions that exist only in a past session): C3 solved them, and the others mostly could not. P1 B1 dev: 3/3 vs 0/3 for everyone else.

## 2. Multi-session build, scripted (8 prompts, one fresh Sonnet session each)
From `results/series_blade_report.md` and `results/series/blade/PLAYTEST.md`. One run per condition: a case study.

| | Cost | Input tokens | Turns | Decisions honoured (static) | Playable in Studio |
|---|---|---|---|---|---|
| none | $1.25 | 1.06M | 122 | 24/24 | yes (HUD counter bug) |
| AGENTS.md | $1.39 | 1.20M | 139 | 24/24 | **no: client crash** |
| **DevMemory** | **$1.04** | **0.61M** | **92** | 24/24 | **yes** |

## 3. Adaptive race, Roblox game (playtest after every prompt, next prompt by fixed rule)
From `results/adaptive_blade_report.md`. Each condition got 16 prompts.

| | Cost | Input tokens | Roadmap features reached | Failing at end |
|---|---|---|---|---|
| none | $3.41 | 3.08M | 7/10 | shop (9 fix prompts in a row) |
| AGENTS.md | $2.88 | 3.41M | 9/10 | waves, shop, HUD |
| **DevMemory** | **$2.48** | **1.85M** | 9/10 | game-over reset |

Disclosures:
- The automated playtest protocol was revised 5 times during the race. Each change applied to all conditions from that point on.
- The `none` condition's Rojo sync crashed at its P6. Its P7–P12 runs were invalidated and re-run from the checkpoint.
- A scripted test player cannot play like a human, so this race is qualitative.

## 4. Adaptive race, web app (team task board, fully automated API + headless-Chrome checks)
From `results/webrace_taskboard.jsonl`.
- **Round 1:** none and AGENTS.md finished all 8 features in 8 prompts ($0.84 / $0.76). **DevMemory got stuck** at 3/8 features after 12 prompts ($1.04).
- **Root causes of the round-1 loss:**
  - Headless mode blocked the agent's shell-based edits in its labels session. That is environment friction that hit all conditions.
  - **A real DevMemory gap:** the bug report never named the label colors, and DevMemory's pack did not carry forward the session where the user had specified them.
- **Fix:** retrieval now always carries the session where a feature was first requested (origin lineage). It also keeps the user's concrete requirements verbatim (hex colors, numbers, API paths), and it no longer treats bug reports as decisions.
- **Round 2:** all conditions re-run with the fixed retrieval, and with `node`/`curl` pre-approved for every condition. **All three built all 8 features in 8 prompts with zero fix rounds.**

  | Round 2 | Cost | Input tokens |
  |---|---|---|
  | none | $0.94 | 847k |
  | AGENTS.md | $0.79 | 633k |
  | **DevMemory** | **$0.74** | **580k** (−8% vs AGENTS.md, −32% vs none) |

  Round 2 produced no bug reports, so it did not exercise the new lineage retrieval. That fix was verified offline instead: on round 1's exact failing case, the pack now carries the original labels request with its colors. The modest edge here reflects a short project where every feature worked the first time.

## 5. Memory across tools: recorded in Claude Code, used by Codex
From `demo/cross-tool/RESULTS.md`. The task board's 8 Claude Code sessions were given to Codex CLI (`gpt-5.6-luna`).
- **Setup:** a regression replaced the label colors. The task was "put the label colors back to exactly what I originally asked for".
- **Isolation:** each run used a fresh folder outside the repo, with the user's Codex config ignored. 3 runs per variant.

| Codex variant | Exactly right | Mean input tokens | Called DevMemory |
|---|---|---|---|
| No memory | 0/3 (guessed) | 153k | n/a |
| **DevMemory pack in the prompt** | **3/3** | **68k** | n/a |
| DevMemory MCP server, optional | 0/3 | 138k | 0/3 |
| DevMemory MCP + one-line AGENTS.md | 3/3 | 138k | 3/3 |

- **An optional tool is not enough:** the agent did not think to call it. Pushing the pack was both the most accurate and the cheapest.
- **Earlier attempts not counted,** each kept with a README in `demo/cross-tool/results/`:
  - the model was unavailable;
  - the no-memory run found a sibling copy of the app by searching parent folders;
  - the user's personal plugins were loaded, including computer use;
  - the workspace was read-only;
  - token usage was missing.
- This is a case study: n = 3 per variant, on one task.

## Headline
Across the fixed held-out benchmark, DevMemory was the only condition above the accuracy floor, with the lowest cost per successful task. In multi-session building it used roughly half the input tokens of the alternatives. It is not universally better:
- On the Python held-out project, the hand-written file matched it.
- In the first web-app race it lost outright, which exposed a retrieval gap we then fixed.

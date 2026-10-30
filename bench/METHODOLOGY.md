# Evaluation methodology

## Question
Does a deterministic, source-linked context pack let a coding agent finish follow-up tasks on an existing project **correctly and for less compute** than the simple alternatives? Compute is measured in tokens, list-price cost, turns, tool calls and wall time.

## Agent and telemetry
- Agent: Claude Code 2.1.310, headless (`claude -p`). Default model Haiku 5.5 (`--model haiku`). Sonnet 5.5 is used for the model-choice comparison.
- Every run uses the same isolation: `--setting-sources project --strict-mcp-config --no-session-persistence --tools Read Edit Write Glob Grep Bash --permission-mode acceptEdits --max-turns 30`.
  - Each run gets a fresh copy of the project in a temp directory outside this repo, so no parent `CLAUDE.md` loads and auto-memory doesn't carry between runs.
- Metrics come only from documented `stream-json` output (`bench/TELEMETRY.md`): input, output and cache tokens, `total_cost_usd`, turns, tool calls, files read, and wall time.
- **Cost is the CLI's API list-price equivalent**, not what the subscription bills.
- There is no sampling seed. "Repeats" are independent re-runs.

## Conditions (identical task prompt, model and tools; only context differs)
| ID | Context given to the agent |
|---|---|
| C0 | nothing (bare session) |
| C1 | a hand-written short `CLAUDE.md` (layout + conventions), the **best simple alternative** |
| C2 | DevMemory pack, static part only (map, conventions, relevant files) |
| C3 | full DevMemory pack (C2 plus relevant past sessions, user-stated decisions, freshness flags) |
| C3nofresh | C3 with freshness flags disabled (ablation, stale tasks only) |
| C4 | model choice: Haiku + C3 vs Sonnet + C0/C1 |

The ablation chain C0 → C2 → C3 → C3nofresh isolates each component: static map, then session memory, then the freshness check. C1 shows what a human could achieve with a hand-written file and no tooling.

## Test projects (synthetic, as the organizers allow)
- **P1 CoinRush:** a Rojo-style Roblox game, 27 Luau files, about 2.4k lines. See `bench/projects/P1/PLANTED.md`.
  - Generated in three stages: (1) a model wrote v0 from a spec; (2) five scripted prior sessions ran with real headless Claude Code and were captured; (3) a hand-made, *uncaptured* refactor made two of those memories stale.
- **P2 ledgerly:** a Python CLI with 56 tests, built the same way. It is used **only** for held-out evaluation.

## Tasks and graders
- There are four task types:
  - **A, code:** answerable from the code.
  - **B, history:** needs a decision that exists mostly or only in a past session.
  - **C, stale:** a past session says something the code no longer matches.
  - **D, unrelated:** memory should stay out of the way.
- Graders are automatic assertions on the resulting files and diff. Every grader also checks the project conventions on the lines the agent added.
  - P1 graders are static, because Luau isn't executed.
  - P2 graders run the project's tests plus a hidden behavioural test.
- **Grader validation** (`bench/validate_graders.py`): the unmodified project must fail every grader (negative control), and the reference solution must pass it (positive control).
  - Grader bugs found on dev runs were fixed, then re-applied to every saved diff with `bench/regrade.py`.

## Dev / held-out split
- **Dev:** 8 P1 tasks (A1–D2). DevMemory was tuned only on these.
- **Held-out:** 4 new P1 tasks (H1–H4) plus 8 P2 tasks.
  - They were written by a **separate agent instance** and validated with both controls.
  - They were then **hash-frozen** (`bench/HELDOUT_FREEZE.txt`, TOTAL `1ed3462b…`, commit `8426810`) before any further tuning. `python -m bench.verify_freeze` confirms they are unchanged.
  - The developer agent never read the held-out prompts or graders.
  - They are run once, after the code freeze.

## Disclosures
- Two DevMemory fixes were motivated by building the P2 fixture, **before** any P2 task existed or was run:
  - The freshness check now ignores lines that the same session later rewrote.
  - The Python convention patterns and import hubs were completed after seeing P2's generated map.
- Dev-set fixes: the A1 prompt was clarified (the original didn't ask for client code), and the B1 grader was fixed (it rejected a correct solution that passed the reason string through a constant).
- The projects and history are synthetic and small. Results show the mechanism on controlled cases. They are not a claim about all codebases.

## Headline metric
`cost per success = Σ cost over all runs (failures included) / number of passing runs`. It is reported per condition, next to the success rate with a Wilson 95% CI. A condition counts only if it meets the **accuracy floor**: success ≥ max(80%, C1's rate).

Setup cost is reported separately and included in the comparison:
- The scan uses 0 LLM tokens and about 0.03 s.
- Capture records sessions the user runs anyway, with no extra model calls.
- So the only per-task overhead is the pack itself, which is already inside each run's token count.

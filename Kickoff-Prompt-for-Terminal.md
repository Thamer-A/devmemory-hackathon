# Kickoff prompt for the terminal session (Opus 5.5)

Paste everything below the line into the terminal session. It overrides anything in `Challenge-2-Project-Memory-Plan.md` and `AGENTS.md` that conflicts with it (the plan was written before the organizers' lobby answers).

First, once: make Claude Code see the project guide. Claude Code reads `CLAUDE.md`, not `AGENTS.md`, so create `CLAUDE.md` containing just `@AGENTS.md`.

---

You are helping me build a solo entry for the HUMAIN–Misk Future AI Builders Hackathon, **Challenge 2: Deliver AI with Less Compute**. Read `AGENTS.md`, `Challenge-2-Project-Memory-Plan.md`, `humain-hackathon-after-webinar.md` and `Challenge-2-details.pdf` first. Where they conflict, `humain-hackathon-after-webinar.md` (organizer answers) wins.

## Hard constraints from the organizers
- Individual entry. Final submission deadline Sat 31 Oct 2026, 8:00 PM Riyadh time (= 1:00 PM US Eastern). I want to be published by 11:00 AM ET Saturday at the latest.
- Deliverables: PPT (8–10 slides), ONE demo video of **3 minutes or less** (the plan's 3–4 min is wrong), source code (GitHub + uploaded), project page, and **test results and methodology** (held-out/unseen cases). Judges see only what I submit. There is no live demo and they run no hidden tests.
- No API keys or credits provided. Use what I already have: the Claude Code subscription on this machine. Do not call paid APIs.
- Judging: (1) task performance on unseen/held-out cases, (2) robustness and adaptation, (3) evaluation and iteration (systematic tests, regression checks, ablations showing each component contributes), (4) technical judgment vs simpler alternatives, (5) engineering quality and reproducibility, (6) communication.
- The Challenge 2 page lists five angles: model choice per task, context that earns its tokens, verification where it pays, **cost per successful task**, accuracy and latency floors. Our headline metric is cost per successful task at an accuracy floor, not raw token reduction.

## Product (unchanged core, tightened)
DevMemory (working name only): a local-first CLI that scans a project, captures session history, and builds a small source-linked context pack for a fresh session.

Design rules:
1. **Setup costs ~0 LLM tokens.** The project map is built deterministically (file tree, symbols, require/import graph, RemoteEvent/asset references, hashes). LLM enrichment is optional and its cost is counted if used.
2. **Capture via documented interfaces only**: headless `claude -p --output-format stream-json` output saved as the session record, and/or Claude Code hooks. No private transcript formats. Verify what usage/cost fields the CLI really returns before relying on them.
3. **Delivery**: `devmem pack "<task>" --budget N` writes a context pack (each item with source path/session ref, reason, token estimate). Inject via `--append-system-prompt` or a SessionStart/UserPromptSubmit hook. MCP is a stretch goal.
4. **Freshness check**: file hashes mark memory items stale when their sources changed; stale items are flagged in the pack, not silently trusted.
5. Plain Markdown/JSONL on disk. No vector DB. Keyword/path/symbol retrieval first.

## Build the evaluation harness BEFORE the features
This is what the judges score. Order of work:
1. **Hour 0–1:** run `claude -p --output-format json` on a trivial task; confirm token usage, cost, turns, duration are returned and can be logged per run. Pick the models: use a cheaper model for most eval runs to protect my subscription quota; estimate quota burn before launching big batches.
2. **Test projects.** P1: a small file-based Roblox project (Rojo-style `.luau` files), either open-source or synthetic (synthetic is allowed; document how it was generated), with planted project conventions and at least one decision that exists only in a prior session. P2: a held-out non-Roblox project (small TS or Python) we never tune on. Roblox Studio MCP is for one demo clip only. The benchmark must run headless from files so a judge can reproduce it.
3. **Task suite with automatic graders** (assertions on the resulting diff/files, not vibes). Four types: (A) answerable from the code, (B) needs a prior-session decision, (C) memory is stale or wrong, so the agent must verify, (D) unrelated task, where the pack must stay tiny and not hurt. Split into dev tasks (tune on these) and held-out tasks (touch once at the end).
4. **Conditions** (this is the ablation story): C0 bare; C1 best simple baseline, a hand-written short AGENTS.md/CLAUDE.md (the "simpler alternative" we must beat); C2 DevMemory static map only; C3 full DevMemory; C4 cheaper model + DevMemory vs stronger model without.
5. **Runner script**: one command runs conditions x tasks x N seeds (N>=3 on key tasks), logs JSONL to `results/` with tokens, cost, tool calls, wall time, pass/fail. A second script produces the tables/charts: cost per successful task, success rate, setup-cost amortization and break-even point. Re-run the whole suite after each change as the regression check.
6. Report honestly, including tasks where memory did not help or hurt. Label estimates as estimates.

## Scope cuts (do not build unless everything above is done)
Obsidian graph polish, local GUI viewer, second provider adapter, embeddings, MCP server, binary asset analysis, Unity/Unreal adapters. Mention these only as roadmap.

## Time plan (US Eastern; organizer support/mentors: Fri 7 AM–3 PM, Sat 5 AM–1 PM)
- Fri: harness + scanner + capture + retrieval, first dev-set results by evening. Book mentor slots early Friday.
- Sat 5–8 AM: held-out run, fix only what the data says. Freeze code by 8 AM.
- Sat 8–11 AM: PPT, <=3 min video, README with one-command repro, project page, publish, verify it shows as published.

## Working style and quota
- I am vibe coding most of this: work autonomously, commit often, and stop for my OK only at these gates: (a) after the telemetry check, (b) after the project/task proposal, (c) before the held-out run. Keep a short `STATUS.md` (done / next / known issues) so any fresh session, or Codex, can pick up cold.
- My Claude quota is the scarce resource (Max plan, weekly limit shared across the whole weekend). Use subagents sparingly, keep tool output small, and do not re-read large files.
- I also have a $20 Codex subscription. Codex is for overflow build work and optionally a second provider adapter (`codex exec --json`) for the robustness story. Keep Claude Code as the primary, verified eval path, and never mix token counts across providers in one comparison.

## First actions
1. Create `CLAUDE.md` -> `@AGENTS.md`, `git init`, make a repo skeleton with `README.md`, `devmem/`, `bench/`, `results/`.
2. Do the Hour 0–1 usage verification and report what telemetry is actually available.
3. Propose the P1/P2 projects and the first 8 dev tasks with their graders, then wait for my OK before building the scanner.

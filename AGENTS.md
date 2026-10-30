# Project Guide for AI Agents

## Project purpose

This folder contains planning material for the HUMAIN–Misk Future AI Builders Hackathon. The selected direction is **Challenge 2: Deliver AI With Less Compute**.

The proposed project is a local-first, project-aware memory system for AI-assisted development. It should be able to:

1. Point at an existing workspace and automatically build a useful, source-linked project vault.
2. Capture the development history that supported tools make accessible as the user works: prompts, assistant-visible responses, tool calls/results, commands, errors, file changes, and available usage metadata.
3. Preserve the accessible source record while retrieving only task-relevant context for later sessions.
4. Reduce repeated project exploration and context/token use without lowering task quality.

The product should be broadly useful for software and game development. **Roblox Studio is the initial game-development demonstration, not the product boundary.**

## Read these files first

- [Challenge-2-Project-Memory-Plan.md](Challenge-2-Project-Memory-Plan.md) — current product direction, research, proposed architecture, MVP, evaluation, risks, and demo plan. Treat this as the main planning document.
- [Hackathon-Notes-ActionItems-Checklist.md](Hackathon-Notes-ActionItems-Checklist.md) — challenge descriptions and submission requirements from the orientation.
- [Future-AI-Builders-Hackathon-HUMAIN-Orientation-Transcript.md](Future-AI-Builders-Hackathon-HUMAIN-Orientation-Transcript.md) — source transcript for details and timestamps.
- [Hackathon-Speaker-Breakdown-and-Questions.md](Hackathon-Speaker-Breakdown-and-Questions.md) — questions and presentation/demo context.

The folder currently contains planning and research files; implementation has not necessarily started. Inspect the current tree and Git status before assuming what exists or changing files.

## Product principles

- Preserve the broadest **accessible** development trace the user enables, but keep capture scoped, local-first, inspectable, and deletable.
- Do not claim to capture private/full model chain-of-thought. Store visible explanations or permitted summaries with accurate labels, and prioritize reproducible evidence such as tool calls, results, commands, and project changes.
- Distinguish observed facts from model-generated inferences. Attach source paths/session references, timestamps, confidence, and freshness where practical.
- Keep the complete archive out of routine prompts. Build compact project maps and task-specific context packs with explicit sources and token budgets.
- Treat engine-specific knowledge and the project’s own conventions as first-class. For game projects, index relationships among code, assets, scenes/places, editor state, and playtest evidence; source-code search alone is insufficient.
- Make the initial project scan useful with minimal setup. Use incremental updates for ongoing projects and capture from the first session for new ones.
- Avoid provider lock-in. Prefer documented hooks, CLI event streams, MCP, or import/export interfaces and isolate provider/engine behavior in adapters.
- Measure total setup/indexing/capture/retrieval costs together with task success, quality, latency, and repeated exploration. Do not report token savings without the setup cost and a baseline.
- Keep human-readable Markdown/export and Obsidian compatibility where useful, but do not require Obsidian to use the memory system.

## Working guidance

- Before implementing, confirm the actual Challenge 2 brief and judging criteria from the current hackathon platform if available; the orientation says challenge details may be updated there.
- Keep the scope narrow enough to demonstrate end to end. Prefer one reliable workflow and a measurable comparison over broad, unverified engine/provider support.
- For the first demo, use a small existing Roblox project and a fresh-session follow-up task. Show onboarding, captured work, retrieved context with provenance, and a playtest/result if feasible.
- Separate the reusable game-development handbook (engine/API/workflow knowledge) from project-specific memory (this game’s architecture, assets, conventions, decisions, and bugs).
- Treat community posts and creator workflows as design examples, not benchmark evidence. Verify changing APIs against current official documentation.
- Protect project data: exclude generated/build/cache folders and secrets, provide configurable exclusions/redaction, and never upload or publish project content unless the user explicitly asks.
- Preserve the user’s project and existing data. Avoid destructive cleanup, broad rewrites, or changes outside the requested scope.
- Do not invent product capabilities, benchmarks, token metrics, or implementation status. Clearly label estimates and unverified assumptions.

## Hackathon submission context

The orientation notes call for one project addressing one challenge, a working implementation being strongly recommended, a 3–4 minute demo video, a presentation, and a completed project page. The notes list a Saturday 8:00 PM publication deadline for that event; verify the current platform for authoritative timing and submission details.

## Naming

“DevMemory” is only a working name. Do not treat it as finalized or change branding across files without being asked.

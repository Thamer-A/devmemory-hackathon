# DevMemory (working name)

Entry for the HUMAIN–Misk Future AI Builders Hackathon, **Challenge 2: Deliver AI with Less Compute**.

DevMemory is a local-first CLI that scans a project deterministically (no LLM tokens), captures
AI coding sessions through documented interfaces (`claude -p --output-format stream-json`, hooks),
and builds a small, source-linked context pack for a fresh session.

Headline metric: **cost per successful task at an accuracy floor**, measured against a bare session
and a hand-written `CLAUDE.md` baseline, including setup cost.

## Layout

- `devmem/` – the CLI (scanner, capture, retrieval, pack builder)
- `bench/` – benchmark: test projects, tasks with automatic graders, runner
- `results/` – JSONL run logs and generated tables

Status: early build. See `STATUS.md`.

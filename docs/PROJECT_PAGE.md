# Project page text (paste into the hackathon platform)

**Name:** DevMemory

**Challenge:** 2: Deliver AI with Less Compute

**Tagline:** Memory that lets every new AI coding session start warm. Preserve everything, send only what earns its tokens.

## Problem
AI coding assistants start every session cold. They re-explore the project, forget decisions made in earlier chats, and re-introduce bugs that were already fixed. Over a multi-session build this burns tokens and money, and it produces broken results. In our tests, a no-memory agent spent **3.1M input tokens** building one small game. It then got stuck for **9 prompts in a row** on a single bug.

## Solution
DevMemory is a local-first CLI and desktop app for Claude Code:
1. **Scan:** a deterministic project map (files, symbols, require graph, Roblox remotes, config keys, observed conventions). It uses **0 LLM tokens** and takes about 25 ms.
2. **Capture:** every AI session, recorded through Claude Code's documented `stream-json` output. That covers prompts, visible replies, tool calls, edits and file hashes, stored as plain files.
3. **Pack:** for a new task, a context pack of about 1k tokens. It holds the user's original requirements verbatim, the session where the feature was first requested, the relevant files with exact lines, and **STALE** flags when code changed since a memory was made.
4. **Deliver:** through a Claude Code hook or `--append-system-prompt`.

An Obsidian-style desktop app lets you browse the memory vault: sessions as notes, raw records as timelines, a graph view, and a "Pack Lab" that shows exactly what a new session would receive.

## Results (all logged; methodology and disclosures in RESULTS.md)
- **Held-out benchmark:** 12 unseen tasks on a Roblox game and a Python app, written by a separate agent and hash-frozen before tuning. DevMemory scored **86%**, the only setup above the 80% accuracy floor. Its cost per successful task was the lowest at **$0.0087**, against $0.0104 for a hand-written CLAUDE.md, $0.0099 for a bare session, and $0.092 for a bigger model (Sonnet) without memory.
- **Building a game over many sessions** (automatic Roblox Studio playtest after every prompt): DevMemory used about **half the input tokens** of a no-memory agent or a self-maintained AGENTS.md (1.85M vs 3.08M and 3.41M). It was the cheapest and reached as many features as the best alternative.
- **Honest failures:**
  - In the first web-app race DevMemory lost, because its pack didn't carry the user's original spec. We fixed retrieval (origin lineage and verbatim requirement memory) and re-ran the race.
  - On the Python held-out project, a hand-written CLAUDE.md matched it.

## Built with
Python (stdlib only), Claude Code headless CLI, Roblox Studio and its built-in MCP server, Rojo, headless Chrome, and pptxgenjs.

## Links
Source code, benchmark, results and the demo memory vault are in the repository (`README.md`, `RESULTS.md`, `bench/METHODOLOGY.md`).

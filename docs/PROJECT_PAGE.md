# Project page text (paste into the hackathon platform)

**Name:** DevMemory

**Challenge:** 2: Deliver AI with Less Compute

**Tagline:** Memory that lets every new AI coding session start warm. Preserve everything, send only what earns its tokens.

## Problem
AI coding assistants start every session cold. They re-explore the project, forget decisions made in earlier chats, and re-introduce bugs that were already fixed. Over a multi-session build this burns tokens and money, and it loses the user's own requirements. On unseen tasks that depend on an earlier decision, agents without memory solved **3 of 12**. Codex, asked to restore label colors the user had chosen in an earlier session, guessed wrong **3 times out of 3**.

## Solution
DevMemory is a local-first CLI and desktop app for Claude Code:
1. **Scan:** a deterministic project map (files, symbols, require graph, Roblox remotes, config keys, observed conventions). It uses **0 LLM tokens** and takes about 25 ms.
2. **Capture:** every AI session, recorded through documented interfaces of any tool. That means Claude Code `stream-json`, Codex `--json`, or a project snapshot diff for any other agent. It covers prompts, visible replies, tool calls, edits and file hashes, stored as plain files.
3. **Pack:** for a new task, a context pack of about 1k tokens. It holds the user's original requirements verbatim, the session where the feature was first requested, the relevant files with exact lines, and **STALE** flags when code changed since a memory was made.
4. **Deliver:** through a Claude Code hook, an **MCP server** for any MCP client, or the pack placed in any agent's prompt.

An Obsidian-style desktop app lets you browse the memory vault: sessions as notes, raw records as timelines, a graph view, and a "Pack Lab" that shows exactly what a new session would receive.

## Results (all logged; methodology and disclosures in RESULTS.md)
- **Two held-out benchmarks:** 28 unseen tasks on a Roblox game and a Python app, written by a separate agent and hash-frozen before any run.
  - DevMemory was the **only setup above the 80% accuracy floor on both sets**: 83% on set 1 (86% before a later retrieval change) and **98% on set 2**. The others scored 64–81%.
  - On set 2 it had the lowest cost per successful task: **$0.0076**, against $0.0093–0.0106.
  - On tasks whose answer lives in an earlier session, it scored **12/12, against 3–4/12**.
  - A bigger model (Sonnet) without memory cost about 11× more per success and stayed under the floor.
- **Memory across tools:** Claude Code sessions, handed to Codex CLI through DevMemory, let Codex restore the user's original spec **3/3 times, against 0/3 without memory**, with **56% fewer input tokens**. Offered only as an optional MCP tool, Codex never called it. With a one-line AGENTS.md instruction it called it every time.
- **Building a game over 16 sessions** (Roblox, automatic playtest after every prompt): DevMemory used **1.85M input tokens, against 3.08M and 3.41M**, at the lowest cost. All three final builds were playable in a human check. The automated playtest was flaky, so this gap is indicative.
- **Honest failures:**
  - In the first web-app race DevMemory lost, because its pack didn't carry the user's original spec. We fixed retrieval and re-ran the race: all three setups built all 8 features, and DevMemory was the cheapest.
  - The retrieval change cost a little on held-out set 1 (86% → 83%).

## Built with
Python (stdlib only), Claude Code headless CLI, Codex CLI, MCP, Roblox Studio and its built-in MCP server, Rojo, headless Chrome, and pptxgenjs.

## Links
Source code, benchmark, results and the demo memory vault are in the repository (`README.md`, `RESULTS.md`, `bench/METHODOLOGY.md`).

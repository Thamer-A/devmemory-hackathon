# Handoff: fill in the HUMAIN hackathon project page

Paste everything below the line into a Claude in Chrome session, with the platform open and logged in.

---

You are helping me submit my hackathon project on the HUMAIN–Misk Future AI Builders Hackathon platform. I am logged in. The project edit page is:
https://humain-ai.hackathon.com/#/projects/edit/6ae4d65aa03804dd847b7681

Your job:
1. **Read before typing.** Open that page and look at every field and section it has. Tell me which fields exist before typing anything.
2. **Fill the text fields from the CONTENT below.**
   - Map each section to the closest field (name, tagline, challenge, description/problem/solution, results, technologies, links).
   - Use the text as written; you may shorten it only to fit a field's character limit, and tell me when you do.
   - Don't invent anything that isn't in the CONTENT.
3. **Don't upload files.** For file fields (presentation, video, source code), stop and tell me which field wants which file; I will attach them myself:
   - Presentation: DevMemory.pptx (a PDF version, DevMemory.pdf, is also available)
   - Demo video: DevMemory_demo.mp4 (2:31)
   - Source code: DevMemory_source.zip
4. **Don't submit or publish.** Save as a draft if there's a save button, then stop and show me a summary of what you filled in.
5. **The repository link is private.** If there is a field for it, use github.com/Thamer-A/devmemory-hackathon, but tell me it's private. I'll decide whether to make it public.

## CONTENT

**Name:** DevMemory

**Team / author:** Thamer Alhussain

**Challenge:** 2: Deliver AI with Less Compute

**Tagline:** Memory that lets every new AI coding session start warm. Preserve everything, send only what earns its tokens.

## Problem
AI coding assistants start every session from scratch. They don't remember what was decided in earlier chats, so they either re-read the whole project (burning tokens) or guess (breaking what the user asked for). Over a multi-session build, that waste adds up in compute, money and quality.

## Solution
DevMemory is a local-first memory layer for AI coding tools. It runs on the developer's machine and works in four steps:
1. **Scan:** it builds a deterministic project map: files, symbols, require graph, Roblox remotes, config keys and the project's own coding conventions. This uses **0 AI tokens** and takes milliseconds.
2. **Capture:** it records every AI session, from Claude Code (stream-json), Codex (`--json`) or any other tool (project snapshot diff). That covers prompts, visible replies, tool calls, edits and file hashes, all stored as plain files the developer can browse and delete.
3. **Pack:** for each new request, it builds a small context pack of about 1,000 tokens. The pack holds the user's earlier decisions in their exact words, the session where a feature was first asked for, the relevant files and lines, and **STALE** warnings when the code has changed since a memory was made.
4. **Deliver:** the pack reaches the AI through a Claude Code hook, an **MCP server** that works with any MCP client, or directly in any agent's prompt.

A desktop app lets the developer browse the memory: every session as a note, the raw records, a graph view, and a "Pack Lab" that shows exactly what a new session would receive.

## Example: Blade Swarm (Roblox)
We built a Roblox game, Blade Swarm, entirely by prompting, with every feature done in a fresh AI session.
- **An earlier decision:** in one session, the user picked the shop's rarity colors (Common gray, Rare blue, Epic purple).
- **The new request:** a later session, starting fresh, was asked to add an Epic upgrade "with the rarity colors we picked".
- **What DevMemory sent:** a 970-token pack holding both earlier conversations (the shop design and the color choice) verbatim, plus where the code keeps them.
- **The outcome:** the session went straight to the right file. Twin Spin arrived as an Epic upgrade in the chosen colors.

## Results (all logged; methodology and disclosures in RESULTS.md)
- **Same game, built three ways** (16 fresh sessions each: no memory, a self-maintained AGENTS.md, DevMemory): all three final builds are playable. DevMemory used **1.85M input tokens, against 3.08M and 3.41M**, at the lowest cost ($2.48 vs $3.41 / $2.88). The automated playtest in that race was flaky, so treat the gap as indicative.
- **28 unseen benchmark tasks** in two sets, written by a separate agent and hash-frozen before any run:
  - DevMemory was the **only setup above the 80% accuracy floor on both sets**.
  - On the latest set it scored **98%**, against 79–81% for the others, at the lowest cost per success (**$0.0076**).
  - On tasks whose answer lives in an earlier session, it scored **12/12, against 3–4/12**.
- **Web-app race:** all three setups built all 8 features; DevMemory was the cheapest. In round 1 it lost outright, which exposed a retrieval gap; we fixed it and report both rounds.
- **Memory across tools:** sessions recorded in Claude Code let Codex restore a user's earlier spec **3/3 times vs 0/3 without memory**, with 56% fewer input tokens.

## Built with
Python (standard library only), Claude Code headless CLI, Codex CLI, MCP, Roblox Studio and its MCP server, Rojo, headless Chrome, ffmpeg and pptxgenjs.

## Links
- **Source code:** github.com/Thamer-A/devmemory-hackathon (private; the source zip is also attached).
- **Key documents:** `README.md`, `RESULTS.md`, `bench/METHODOLOGY.md` and `docs/ANY_TOOL.md`.

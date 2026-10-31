# Cross-tool memory: recorded in Claude Code, used by Codex

**Setup**
- **Memory:** the 8 Claude Code sessions that built the task board (web race round 2, DevMemory condition), captured with stream-json and stored in `claude-code-memory/`.
- **Regression:** a restyle replaced the three label colors, everywhere in the code.
- **Task given to Codex:** "Someone changed the label colors and now they look wrong. Put the label colors back to exactly what I originally asked for."
- **Where the answer exists:** only in a past Claude Code session (the user's labels request with `#e5484d`, `#3e63dd`, `#8b8d98`).

**Agent and isolation**
- **Agent:** Codex CLI 0.149, model `gpt-5.6-luna`, through `devmem codex --isolated`.
- **Codex config:** the user's own config is ignored, so no personal plugins or MCP servers load. Only the Windows sandbox mode is kept.
- **Folders:** each run uses a fresh folder under `~/devmem-xtool/`, outside the repo. The memory store is in a separate tree, and the folder is deleted before the next run.
- **Pass:** all three hex values exactly right in `LABEL_COLORS`.

| Variant | Exactly right | Mean input tokens | Mean output tokens | Called DevMemory |
|---|---|---|---|---|
| No memory | 0/3 (guessed palettes) | 153,419 | 2,965 | n/a |
| **Pack prepended to the prompt** | **3/3** | **67,827** | **618** | n/a |
| MCP server available (optional) | 0/3 | 137,951 | 2,114 | 0/3 |
| **MCP + one-line AGENTS.md** ("call get_context_pack first") | **3/3** | 138,291 | 1,137 | 3/3 |

- Input tokens are Codex's reported `input_tokens` (cached input included), summed over the run.
- In the AGENTS.md variant, Codex also called `begin_session` and `end_session`, so it recorded its own work back into DevMemory (`results/mcp_agents_r*/agent_recorded_*.meta.json`).

**Takeaways**
- **Memory transfers across tools.** Sessions captured from Claude Code fixed a task for Codex that Codex could not solve without them.
- **Pushing the pack is cheapest.** It used 56% fewer input tokens than no memory, and it was right every time.
- **An MCP tool on its own is not enough.** The agent never thought to call it. A one-line instruction in AGENTS.md made it call DevMemory every time. That is still more tokens than pushing the pack, because the agent explores before and after the call.

**Attempts not counted** (kept in `results/attempt*/` with a README each)
- **0:** the default Codex model is not available with a ChatGPT login.
- **1:** the copies sat in sibling folders, and the no-memory run found the other copy by searching parent folders.
- **2:** the user's Codex config was loaded. The MCP variant used a computer-use server to look at open desktop windows, and DevMemory's MCP calls were blocked by the approval policy.
- **3:** ignoring the user config also dropped the Windows sandbox mode, so the workspace was read-only.
- **4:** the AGENTS.md variant was correct 3/3, but the script saved the agent's own MCP record instead of the adapter's, so token usage was missing. It was re-run.

**Scale:** this is a case study, n = 3 per variant, on one task. Reproduce with `python demo/cross-tool/run_demo.py --repeats 3`.

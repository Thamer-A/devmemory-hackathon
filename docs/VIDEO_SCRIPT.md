# Demo video: Blade Swarm, input → AI in action → output → value (target ~2:30, hard limit 3:00)

**Structure:** the organisers' tip. One representative test case from our own Roblox game, Blade Swarm, then a brief mention of the wider testing.

**Narration:** the spoken text is in `docs/VO_READ.md` (conversational version, opens with an introduction). The `>` lines below are the earlier draft, kept for the on-screen mapping.

**Reading:** about 300 words. Read calmly, roughly 120–130 words per minute, with a one-second pause between sections (the edit cuts on those pauses). Each `>` line is one breath.

**The test case:** race prompt R6 in the DevMemory build. The rarity colors were picked in an earlier session (session 8 in the app). Then a fresh session was asked to "make sure it shows up with the rarity colors we picked". All real, from the logged race.

## 1. Problem (≈0:00–0:12)
**On screen:** Blade Swarm gameplay. Title: *Every AI coding session starts cold.*
> Every AI coding session starts from zero.
> It forgets what you decided, and what you asked for.

## 2. Input (≈0:12–0:40)
**On screen:**
- The DevMemory app showing the Blade Swarm memory vault: 16 sessions, each one a prompt.
- Zoom on session 8: *"rarity colors Common = gray, Rare = blue, Epic = purple"*.
- A card with the next request: *"Add an Epic upgrade called Twin Spin: +2 blades for 120 coins. Make sure it shows up with the rarity colors we picked."*

> This is Blade Swarm, a Roblox game we built entirely by prompting, one fresh AI session at a time. DevMemory recorded every session.
> In session eight, the user picked the rarity colors: common gray, rare blue, epic purple.
> The next session is brand new. It gets: add an epic upgrade called Twin Spin, and make sure it shows up with the rarity colors we picked.

## 3. AI in action (≈0:40–1:08)
**On screen:** the actual pack DevMemory delivered for that prompt (excerpt). It contains:
- the project's own conventions;
- the shop-design session, with the rarities and prices;
- the session where the colors were picked, verbatim.

Captions: *0 AI tokens to build · about 970 tokens · the decisions, word for word.*
> That new session has never seen session eight. DevMemory has.
> Before it starts, DevMemory builds a pack of about a thousand tokens, with no AI calls at all: the session where the shop was designed, and the session where the colors were picked, word for word, plus where the code keeps them.

## 4. Output (≈1:08–1:50)
**On screen:**
1. The resulting code: `Rarity = { Common = gray, Rare = blue, Epic = purple }` and `TwinSpin … Rarity = "Epic", Cost = 120`.
2. The shop in the DevMemory build, with its rarity colors (your footage).
3. The three builds side by side, titled **Claude Base · Claude + AGENTS.md · Claude + DevMemory**, with input tokens and cost under each.

> The session goes straight to the shop config, and Twin Spin arrives as an epic upgrade, in the colors the user chose.
> We built this same game three ways, sixteen sessions each: with nothing, with a hand-kept AGENTS file, and with DevMemory.
> All three are playable. DevMemory used about half the input tokens, at the lowest cost.

## 5. Value and the wider testing (≈1:50–2:18)
**On screen:** the held-out results chart. Then a card: *Also tested: a web-app race · memory shared between Claude Code and Codex.*
> We also tested it on 28 unseen benchmark tasks, frozen before any run. DevMemory was the only setup above our 80% accuracy bar, scoring 98% on the latest set, at the lowest cost per success.
> And we raced it on a web app, and shared its memory between Claude Code and Codex. The details are in our results.

## 6. Close (≈2:18–2:30)
**On screen:** *DevMemory: preserve everything, send only what earns its tokens.* Below it: *Local-first · Claude Code, Codex, any MCP client.*
> DevMemory runs locally, with Claude Code, Codex, or any MCP tool.
> Preserve everything. Send only what earns its tokens.

## Sources for every claim
- **Session 8 and the R6 request:** `demo/memory-example/blade-swarm-race/.devmemory/sessions/` (the DevMemory race build).
- **R6 pack:** `results/raw/adaptive_blade_devmemory_r1/P9-R6.pack.md`, about 970 tokens (estimate) with 2 sessions.
- **Resulting code:** `results/adaptive/blade/devmemory_r1/src/shared/Config.lua`.
- **Honest scope of R6:** the other two builds also got the rarity colors right. They found them in the code, or in the AGENTS.md file the agent maintained, and that prompt cost all three a similar number of tokens (56–64k). The narration therefore says only what DevMemory brought, not that the others failed.
- **Race tokens:** `RESULTS.md` section 3. That race's automated playtest was flaky, so the narration says "about half" and "all three are playable" (the human check).
- **Held-out:** `RESULTS.md` sections 1 and 1b.

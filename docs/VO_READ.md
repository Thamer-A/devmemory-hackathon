# Voice-over: read aloud (about 2:20)

Pause about one second at each line marked (pause).

**1. Problem**

Every AI coding session starts from zero.

It forgets what you decided, and what you asked for.

*(pause)*

**2. Input**

This is Blade Swarm, a Roblox game we built entirely by prompting, one fresh AI session at a time. DevMemory recorded every session.

In session eight, the user picked the rarity colors: common gray, rare blue, epic purple.

The next session is brand new. It gets: add an epic upgrade called Twin Spin, and make sure it shows up with the rarity colors we picked.

*(pause)*

**3. AI in action**

That new session has never seen session eight. DevMemory has.

Before it starts, DevMemory builds a pack of about a thousand tokens, with no AI calls at all: the session where the shop was designed, and the session where the colors were picked, word for word, plus where the code keeps them.

*(pause)*

**4. Output**

The session goes straight to the shop config, and Twin Spin arrives as an epic upgrade, in the colors the user chose.

We built this same game three ways, sixteen sessions each: with nothing, with a hand-kept AGENTS file, and with DevMemory.

All three are playable. DevMemory used about half the input tokens, at the lowest cost.

*(pause)*

**5. Value and the wider testing**

We also tested it on 28 unseen benchmark tasks, frozen before any run. DevMemory was the only setup above our 80% accuracy bar, scoring 98% on the latest set, at the lowest cost per success.

And we raced it on a web app, and shared its memory between Claude Code and Codex. The details are in our results.

*(pause)*

**6. Close**

DevMemory runs locally, with Claude Code, Codex, or any MCP tool.

Preserve everything. Send only what earns its tokens.

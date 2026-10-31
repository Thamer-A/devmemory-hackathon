# Voice-over: read aloud (about 2:30)

Pause about one second at each line marked (pause).

**1. Problem**

Every AI coding session starts from zero.

It forgets what you decided, and what you asked for.

*(pause)*

**2. Input**

Here's a real test from our benchmark, on a Roblox game.

In an earlier session, the developer planned a daily login reward: twenty coins, plus ten per streak day, capped at seven days. No code yet, just the plan.

Days later, a brand-new session gets one line: add the daily reward payout, from the plan we made.

*(pause)*

**3. AI in action**

A fresh session has never seen that plan. DevMemory has.

It scanned the game with zero AI tokens, and it recorded every earlier session.

For this request it builds a small pack: the planning session, word for word, plus the rules this codebase already follows, like "coins only go through the currency service".

*(pause)*

**4. Output**

Without memory, the model guessed. It invented a fifty-coin reward, and failed three times out of three. So did a bigger model, and so did a hand-written project file.

With DevMemory, it followed the plan exactly, three times out of three, at the same cost.

*(pause)*

**5. Value and the wider testing**

We then built a whole Roblox game three ways, sixteen sessions each. All three were playable, but DevMemory used about half the input tokens.

Across 28 unseen tasks, frozen before any run, it was the only setup above our 80% accuracy bar. On the latest set it scored 98%, at the lowest cost per success, and on the Roblox tasks it went 36 for 36.

We also raced it on a web app, and shared its memory between Claude Code and Codex. The details are in our results.

*(pause)*

**6. Close**

DevMemory runs locally, with Claude Code, Codex, or any MCP tool.

Preserve everything. Send only what earns its tokens.

# Demo video: edited showcase with voice-over (target 2:50, hard limit 3:00)

About 340 words of narration, at roughly 130 words per minute with pauses. Read it in one take, calmly. Leave a one-second pause between sections; the edit uses those pauses for cuts. Each line below is one breath.

## 1. Hook (0:00–0:12)
**On screen:** DevMemory build gameplay. Title card: *Every AI coding session starts cold.*
> Every time you open a new AI coding session, it starts from zero.
> It re-reads your project, forgets what you decided last week, and loses the exact things you asked for.

## 2. What DevMemory is (0:12–0:42)
**On screen:** the DevMemory app (vault, a session note, graph, Pack Lab with a STALE flag). Captions: *Scan · Capture · Pack · Deliver.*
> DevMemory fixes that, locally.
> It scans your project with zero AI tokens, and records every AI session, from Claude Code, Codex, or any other tool, as plain files you can browse.
> When a new session starts, it sends only what matters: about a thousand tokens with your original words, the session where the feature began, the exact lines to change, and a warning if the code has moved on since.

## 3. Three ways to build the same game (0:42–1:25)
**On screen:** three-way split screen, one title card above each panel: **Claude Base · Claude + AGENTS.md · Claude + DevMemory**. Under each panel, animated counters: input tokens **3.08M · 3.41M · 1.85M**, cost **$3.41 · $2.88 · $2.48**. Small footnote: *Same AI-generated art pack in all three builds.*
> We built the same Roblox game three ways: no memory, a hand-kept AGENTS file, and DevMemory.
> Sixteen fresh sessions each, with an automatic playtest after every prompt.
> All three ended up playable.
> But DevMemory got there with 1.85 million input tokens, against 3.1 and 3.4 million, at the lowest cost.

## 4. Memory moves between tools (1:25–1:55)
**On screen:** split screen of the task board. Left: *Codex, no memory*, with wrong label colors. Right: *Codex + DevMemory*, with the exact colors. Counters: 0/3 vs 3/3, 153k vs 68k tokens.
> Memory isn't locked to one tool.
> We gave Codex memory that was recorded in Claude Code, and asked it to put back label colors the user had picked earlier.
> Without memory, it guessed wrong three times out of three.
> With DevMemory, it got them exactly right every time, with less than half the tokens.

## 5. The hard test (1:55–2:30)
**On screen:** animated bar chart of the held-out pass rates (set 1 and set 2), with the 80% floor line, then the cost-per-success bars. Callout: *History tasks: 12/12 vs 3/12.*
> Then the hard test: 28 unseen tasks in two sets, written by a separate agent and frozen before any run.
> DevMemory was the only setup above our 80% accuracy bar on both, 98% on the second set, and the cheapest per successful task.
> On tasks that depend on an earlier decision, it scored 12 out of 12. Without memory, about 3.

## 6. Honest failure (2:30–2:48)
**On screen:** the round-1 web race card ("we lost") turning into the round-2 result.
> It isn't perfect. In one race it lost, because it didn't carry the user's original request forward.
> We fixed that, re-ran the race, and we report both rounds.

## 7. Close (2:48–2:58)
**On screen:** title card: *DevMemory: preserve everything, send only what earns its tokens.*
> DevMemory. Preserve everything. Send only what earns its tokens.

## Notes for the edit
- **Every number above is in RESULTS.md.** The Roblox token gap carries a caveat in RESULTS (the automated playtest was flaky). The narration says "all three ended up playable" and doesn't claim any build was broken.
- **Footage:** `demo/footage/{none,agentsmd,devmemory}_N.mp4` (newest take of each); app screens in `docs/app-screens/`; task-board shots rendered from `demo/taskboard/`.
- **Record the voice-over:** any quiet room, with the laptop or phone mic 20–30 cm away. A WAV or M4A file is fine.

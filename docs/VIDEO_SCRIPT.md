# Demo video script (target 2:50, hard limit 3:00)

Record with the Xbox Game Bar (Win+G) or OBS, 1080p. Narrate over the shots; about 140 words per minute. Show the solution working, not the slides.

| Time | Shot (what's on screen) | Narration |
|---|---|---|
| 0:00–0:15 | Blade Swarm playing in Roblox Studio (`demo/BladeSwarm_Final.rbxl`): blades cutting through zombies, the shop opening | "Every time you open a new AI coding session, it starts cold. It re-reads your project, forgets what you decided yesterday, and re-breaks things you already fixed. That wastes tokens and time." |
| 0:15–0:40 | Terminal: `devmem scan` on the game (instant). Then the DevMemory app (`DevMemory.bat`): home screen → open the Blade Swarm example → overview | "DevMemory fixes that locally. It scans the project in milliseconds with zero LLM tokens, records every AI session through Claude Code's documented output, and keeps it all as plain files you can browse." |
| 0:40–1:05 | App: Memory Vault → a session note (prompt, outcome, files touched, edits) → a raw `.jsonl` timeline → Graph view | "Here is the memory vault: every session as a note, with the user's own words, what changed, and links between files, sessions and decisions. Nothing is paraphrased, and everything is preserved." |
| 1:05–1:30 | App: Pack Lab. Type "Make the Brute enemy deal 35 damage" and show the pack with the STALE flag and the Config line | "When a new session starts, DevMemory sends only what earns its tokens: about a thousand tokens with the original requirements, the session where a feature was first asked for, the exact lines to change, and a STALE warning when the code moved on since." |
| 1:30–2:15 | `results/adaptive_blade_report.md` table or the deck's slide 8 chart. Then the screenshot of the broken AGENTS.md build ("WAVE 0") next to the working DevMemory build | "We tested it like a real developer would. The same prompts were sent to three setups (nothing, a self-updated AGENTS.md, and DevMemory), with a fresh session per prompt and an automatic Roblox Studio playtest after every step. DevMemory built the game with about half the input tokens and the lowest cost. One of the other builds passed every code check but crashed in Studio." |
| 2:15–2:40 | Deck slide 7 (held-out chart) | "On twelve unseen tasks, frozen before tuning, DevMemory was the only setup above our 80% accuracy floor, at the lowest cost per successful task. That's about eleven times cheaper than a bigger model without memory." |
| 2:40–2:55 | Deck slide 9 (what failed) | "It isn't perfect. In our first web-app race it lost, because it didn't carry forward the user's original spec. We fixed that, re-ran the race, and report both rounds." |
| 2:55–3:00 | Title slide / repo | "DevMemory: preserve everything, send only what earns its tokens." |

Tips:
- Prepare each window before recording: Studio with the place open and Play pressed, the app on the Blade Swarm example, the deck open.
- Keep cursor movement slow. Cut dead time in editing (the ffmpeg skill or Clipchamp).
- If over 3:00, trim the 1:30–2:15 segment first.

# Voice-over: read aloud (about 2:40)

Talk like you're explaining it to a friend. Take a short breath at each (pause); I'll cut the video on those pauses.

**1. Intro and problem**

Salam alaikum, my name is Thamer Alhussain, and this is my solution to Challenge 2: delivering AI with less compute. It's called DevMemory.

If you've ever coded with AI, you know the problem. Every new chat starts from scratch. It doesn't remember what you decided yesterday, so it either digs through your whole project again, or it just guesses.

*(pause)*

**2. The example**

So we built a Roblox game, Blade Swarm, entirely by prompting, with every feature done in a brand-new AI session. DevMemory quietly recorded each one.

In one session, we picked the colors for the shop's rarities: gray for common, blue for rare, purple for epic.

A few sessions later, a fresh session was asked to add an epic upgrade called Twin Spin, and to use "the rarity colors we picked". That session had never seen the conversation where we picked them.

*(pause)*

**3. What DevMemory does**

That's where DevMemory comes in. Before the AI even starts, it puts together a small briefing, about a thousand tokens, and it doesn't use any AI to build it.

It pulls out the two conversations that matter, the shop design and the color choice, in our exact words, and points to the file where the colors live.

*(pause)*

**4. The result**

So the AI goes straight to the right file, and Twin Spin comes in as an epic upgrade, in purple, just like we asked.

Then we built the same game three times: once with no memory, once with a notes file the AI kept for itself, and once with DevMemory. All three ended up playable, but DevMemory got there with about half the tokens, and it was the cheapest.

*(pause)*

**5. Testing beyond one game**

I didn't want to rely on one game, so I also tested it on 28 tasks it had never seen, locked in before a single test ran. DevMemory was the only setup that cleared our 80% accuracy bar on both test sets. On the latest one it scored 98%, at the lowest cost per correct answer.

I also tried it on a web app, and even handed its memory from Claude Code over to Codex. All the details are in the repo.

*(pause)*

**6. Close**

DevMemory runs on your own machine, and it works with Claude Code, Codex, or any tool that supports MCP.

The idea is simple: keep everything, but only send what's actually worth the tokens. Thanks for watching.

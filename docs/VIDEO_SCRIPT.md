# Demo video: one Roblox test case, input → AI in action → output → value (target ~2:40, hard limit 3:00)

Structure follows the organisers' tip: one representative test case, then a brief mention of the wider testing. About 310 words. Read calmly, roughly 120–130 words per minute, with a one-second pause between sections (the edit cuts on those pauses). Each `>` line is one breath.

**The test case:** held-out task P1 H2, from the frozen set. It was run before anyone looked at it; it was opened only afterwards, to make this video.

## 1. Problem (≈0:00–0:13)
**On screen:** Roblox gameplay. Title: *Every AI coding session starts cold.*
> Every AI coding session starts from zero.
> It forgets what you decided, and what you asked for.

## 2. Input (≈0:13–0:40)
**On screen:** a card for the earlier planning session in a Roblox game, with the decisions highlighted: *20 coins plus 10 per streak day · cap 7 days · Config.DailyStreakCap · coins only through CurrencyService*. Then *Days later, a fresh session:* "Add the daily reward payout calculation from the plan we made…"
> Here's a real test from our benchmark, on a Roblox game.
> In an earlier session, the developer planned a daily login reward: twenty coins, plus ten per streak day, capped at seven days. No code yet, just the plan.
> Days later, a brand-new session gets one line: add the daily reward payout, from the plan we made.

## 3. AI in action (≈0:40–1:12)
**On screen:** the actual pack DevMemory delivered (excerpt). The planning session is quoted verbatim, alongside the game's own rules found in the code. Captions: *0 AI tokens to build · the plan, word for word · the project's own rules*.
> A fresh session has never seen that plan. DevMemory has.
> It scanned the game with zero AI tokens, and it recorded every earlier session.
> For this request it builds a small pack: the planning session, word for word, plus the rules this codebase already follows, like "coins only go through the currency service".

## 4. Output (≈1:12–1:42)
**On screen:** the code side by side. Left, *Claude, no memory*: `DailyRewardBaseCoins = 50` (invented). Right, *Claude + DevMemory*: `DailyRewardBase = 20`, `PerStreakDay = 10`, `DailyStreakCap = 7`. Badges: *0 of 3 correct (a bigger model and a hand-written CLAUDE.md also failed every time)* vs *3 of 3 correct, at the same token cost*.
> Without memory, the model guessed. It invented a fifty-coin reward, and failed three times out of three. So did a bigger model, and so did a hand-written project file.
> With DevMemory, it followed the plan exactly, three times out of three, at the same cost.

## 5. Value and the wider testing (≈1:42–2:30)
**On screen:** the three Roblox builds side by side, **Claude Base · Claude + AGENTS.md · Claude + DevMemory**, with their input-token counts. Then the held-out chart. Then a card: *Also tested: a web-app race · memory shared between Claude Code and Codex*.
> We then built a whole Roblox game three ways, sixteen sessions each. All three were playable, but DevMemory used about half the input tokens.
> Across 28 unseen tasks, frozen before any run, it was the only setup above our 80% accuracy bar. On the latest set it scored 98%, at the lowest cost per success, and on the Roblox tasks it went 36 for 36.
> We also raced it on a web app, and shared its memory between Claude Code and Codex. The details are in our results.

## 6. Close (≈2:30–2:42)
**On screen:** *DevMemory: preserve everything, send only what earns its tokens.* Below: *Local-first · Claude Code, Codex, any MCP client.*
> DevMemory runs locally, with Claude Code, Codex, or any MCP tool.
> Preserve everything. Send only what earns its tokens.

## Sources for every claim
- **H2 results:** `results/heldout.jsonl`. With Haiku 5.5: C3 3/3, C0, C1 and C2 0/3. With Sonnet 5.5: bare and CLAUDE.md 0/2. Mean input tokens: C3 62k vs C0 63k.
- **Code shown:** `results/raw/heldout/heldout_P1-H2_C0_haiku_r0_*.diff` and `heldout_P1-H2_C3_haiku_r0_*.diff`. Pack: `heldout_P1-H2_C3_haiku_r0_*.pack.md`.
- **Roblox held-out:** C3 36/36 across sets 1 and 2 (12/12 and 24/24).
- **Roblox race tokens:** `RESULTS.md` section 3. The playtest there was flaky, so the narration says "about half" and "all three were playable" (the human check).

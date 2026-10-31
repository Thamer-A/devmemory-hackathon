# Demo video: one test case, input → AI in action → output → value (target ~2:45, hard limit 3:00)

Structure follows the organisers' tip: one representative test case, then a brief mention of the wider testing. About 300 words. Read calmly, roughly 120–130 words per minute, with a one-second pause between sections (the edit cuts on those pauses). Each `>` line is one breath.

## 1. Problem (≈0:00–0:14)
**On screen:** Roblox gameplay. Title: *Every AI coding session starts cold.*
> Every AI coding session starts from zero.
> It forgets what you decided, and what you asked for.

## 2. Input (≈0:14–0:40)
**On screen:** the DevMemory app showing an earlier Claude Code session, with the user's words highlighted: *Bug (red #e5484d), Feature (blue #3e63dd), Chore (gray #8b8d98)*. Then a card: *Later, the app is restyled and the colors drift.* Then the new request, typed: *"Put the label colors back to exactly what I originally asked for."* → **Codex**.
> Here's a real example.
> In an earlier session with Claude Code, a user picked exact label colors: red, blue and gray.
> Later, the app was restyled, and the colors drifted.
> Now the user asks a different AI tool, Codex: put the label colors back to exactly what I originally asked for.

## 3. AI in action (≈0:40–1:18)
**On screen:** DevMemory's Pack Lab. The token meter shows 861 tokens, and the original session is listed with a *partly stale* flag. Captions: *0 AI tokens to scan · finds the session where the colors were chosen · ~860-token pack · STALE where code changed*. Then a terminal card: `devmem codex "Put the label colors back…"`, and Codex's reply: *Restored … Bug #e5484d, Feature #3e63dd, Chore #8b8d98*.
> Codex has never seen that conversation. DevMemory has.
> It scanned the project with zero AI tokens, and it recorded every earlier session.
> For this request, it builds a pack of about 860 tokens: the original session, with the user's exact words, flagged partly stale because the code has changed since.
> Codex gets that pack, and goes straight to the right file.

## 4. Output (≈1:18–1:46)
**On screen:** split screen of the two task boards. Left: *Codex, no memory*, with green "Chore" tags. Right: *Codex + DevMemory*, with the exact gray. Counters: *0 of 3 right · 153k tokens* vs *3 of 3 right · 68k tokens*.
> Without memory, Codex guessed, and got the colors wrong three times out of three.
> With DevMemory, it restored them exactly, every time, with less than half the tokens.

## 5. Value and the wider testing (≈1:46–2:30)
**On screen:** the held-out results chart (both sets, 80% floor). Then the three Roblox builds side by side, titled **Claude Base · Claude + AGENTS.md · Claude + DevMemory**, with their input-token counts.
> That's the pattern across all our testing.
> On 28 unseen tasks, frozen before any run, DevMemory was the only setup above our 80% accuracy bar on both sets, 98% on the second, and the cheapest per successful task.
> And when we built the same Roblox game three ways, sixteen sessions each, all three were playable, but DevMemory used about half the input tokens.

## 6. Close (≈2:30–2:42)
**On screen:** *DevMemory: preserve everything, send only what earns its tokens.* Below: *Local-first · Claude Code, Codex, any MCP client.*
> DevMemory runs locally, and works with Claude Code, Codex, or any MCP tool.
> Preserve everything. Send only what earns its tokens.

## Sources for every claim
- **Test case:** `demo/cross-tool/RESULTS.md` (isolated Codex runs, n = 3 per variant).
- **Held-out numbers:** `RESULTS.md` sections 1 and 1b.
- **Roblox tokens:** `RESULTS.md` section 3. That race's playtest was flaky, so the narration claims only "about half the input tokens" and "all three playable" (the human check).

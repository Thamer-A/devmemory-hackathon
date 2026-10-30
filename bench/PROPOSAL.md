# Benchmark proposal (gate b): projects and first 8 dev tasks

Status: **proposal, awaiting OK**. Nothing here is built yet.

## P1: "CoinRush", a synthetic Rojo-style Roblox project (dev + held-out tasks)

- About 35–45 `.luau` files, about 3–4k LOC: `default.project.json`, `src/shared` (Config, Remotes, Log, Assets, ItemCatalog, MathUtil, Types), `src/server/services` (Currency, Data, Shop, Round, Enemy, Leaderboard), `src/client/controllers` (UI, HUD, Shop, Input), `assets/manifest.json` (name to rbxassetid).
- Synthetic because the graders need planted conventions and decisions whose ground truth we know. Claude generates it in this repo, and the generation method and planted facts are documented in `bench/projects/P1/PLANTED.md`, which is stored **outside** the copy the agent sees.
- It has to be big enough that blind exploration actually costs tokens. Otherwise there is nothing to save.

**Planted conventions (visible in code, and listed in the C1 CLAUDE.md):**
- K1: Remotes are declared only via `Remotes.define("Name")` in `shared/Remotes.luau`. Never `Instance.new("RemoteEvent")`.
- K2: Currency changes only go through `CurrencyService.add(player, amount, reason)` with a reason string.
- K3: Logging uses `Log.info/warn(tag, ...)`. No `print` in `src/`.
- K4: Tunables live in `shared/Config.luau`, with no magic numbers in services.
- K5: Asset IDs only come from `Assets.get("name")`, backed by the manifest.

**History-only facts:** these exist only in captured prior sessions. They come from real scripted `claude -p` "session 0" runs, captured with stream-json and committed as fixtures.
- H1, a pending plan: "The daily reward grants via `CurrencyService.add(..., "daily_reward")`, resets at 00:00 UTC, and the streak caps at 7 (`Config.DailyStreakCap`)."
- H2, a rejected approach: "Inventory is stored as numeric ItemCatalog IDs, never item names. Names caused breakage on rename."
- S1, which goes stale: a session says enemy damage is in `EnemyService.DAMAGE`. A later commit moves it to `Config.Enemies[name].damage`.
- S2, which goes stale: a session refers to remote `BuyItem`. A later commit renames it to `PurchaseItem`.

## P2: a small Python project, held-out only (never tuned on)

A synthetic CLI app of about 15 files, for example an expense/inventory tracker. Its graders run **pytest** behavior tests, so they are stronger than static checks. It follows the same pattern: 3–4 conventions (integer cents, `AppError` subclasses, repository layer, settings in `config.py`), one history-only decision and one stale fact. Its tasks are written and **hash-frozen** (the SHA-256 is committed) before retrieval tuning starts, and nobody looks at them again until the held-out run.

## First 8 dev tasks (P1)

Graders are Python functions over the final file tree and git diff in `bench/tasks/P1/<id>/grade.py`. Every grader also checks the global rules K1–K5 against the diff (no `print`, no raw RemoteEvent, no direct leaderstats writes, no new magic numbers in services).

| ID | Type | Task prompt (to agent) | Grader asserts |
|---|---|---|---|
| A1 | code | "Add a RequestRespawn remote: client fires it, server respawns the player after a configurable delay." | `Remotes.define("RequestRespawn")`; server handler connected; `Config.RespawnDelay` exists and is used; K1–K5 |
| A2 | code | "Add a Coin Magnet item to the shop for 150 coins." | new ItemCatalog entry with a unique numeric id, price 150, icon via `Assets.get`, and a manifest entry; K1–K5 |
| B1 | history | "Implement the daily reward we planned last session." | uses `CurrencyService.add` with `"daily_reward"`; UTC reset (`os.date("!*t")` or equivalent); `Config.DailyStreakCap = 7` used |
| B2 | history | "Add an admin command to gift an item to a player." | inventory write stores a numeric id (no item-name keys); goes through DataService; K1–K5 |
| C1 | stale | "Make the Brute enemy deal 35 damage." | `Config.Enemies.Brute.damage == 35`; no `DAMAGE` table recreated in EnemyService |
| C2 | stale | "Add a confirm dialog before the client sends a shop purchase." | client fires `PurchaseItem`; no `BuyItem` anywhere; dialog in ShopController |
| D1 | unrelated | "Add `MathUtil.lerp(a, b, t)` that clamps t to [0, 1]." | function exists with clamp; no other files changed; **pack ≤ 300 tokens** (C2/C3) |
| D2 | unrelated | "Document `rojo serve` usage in the README." | README contains a `rojo serve` section; only README changed; pack ≤ 300 tokens |

Limitation: P1 graders are static, because Luau isn't executed. If `lune` installs cleanly, the pure-logic checks (lerp, streak cap) get optional behavior tests. P2's pytest graders are the behavioral counterweight.

## Conditions and ablations

- **C0** bare. **C1** hand-written short CLAUDE.md (conventions plus layout, written once at project start, not updated after sessions). **C2** DevMemory static map only. **C3** full DevMemory (map + history + freshness). **C4** Haiku + C3 vs Sonnet + C0/C1.
- Extra ablation: **C3-nofresh** (freshness flags off), run on the C tasks only, to show the stale check matters.
- Accuracy floor: a condition counts only if its success rate is ≥ C1's and ≥ 80%. Headline: cost per successful task, using API-list-price equivalent, with setup cost amortized.

## Quota plan

- Dev suite = 8 tasks × 5 conditions × 3 seeds = 120 Haiku runs, plus a Sonnet subset for C4.
- Before the full suite: a **pilot of 8 runs** (C0 + C3 on 4 tasks). Log the `seven_day.utilization` delta from `rate_limit_event` and extrapolate. Current seven-day utilization is 18%.

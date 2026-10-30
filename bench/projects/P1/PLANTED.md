# P1 "CoinRush": how it was generated and what is planted

This file sits outside `game/`. Eval runs copy only `game/`, so agents never see it.

## Generation (synthetic, allowed by the organizers)
1. **v0 code:** a Claude Sonnet subagent wrote the project (27 files, about 2.3k lines of Luau) from a written spec. It is Rojo-style and follows conventions K1–K5. Commit `cfbf1d1`.
2. **Session 0:** `python -m bench.make_history P1` ran five scripted prompts (`history_script.json`) with real headless Claude Code (Haiku) on a temp copy. Each run was captured through `stream-json` into `devmemory/sessions/`, and its edits became project state.
3. **v2 refactor:** an uncaptured human-style refactor done by hand, standing in for work outside any AI session. Enemy damage moved from `EnemyService.DAMAGE` to `Config.Enemies[kind].damage`, and the remote `BuyItem` was renamed to `PurchaseItem`. Commit `1a37b83`.

## Planted facts
| ID | Fact | Where the truth lives |
|---|---|---|
| K1 | Remotes are created only via `Remotes.define` | code |
| K2 | Coins change only via `CurrencyService.add(player, amount, reason)` | code |
| K3 | Logging uses `Log.*`; no `print`/`warn` | code |
| K4 | Tunables live in `Config.luau` | code |
| K5 | Asset ids come only from `Assets.get`, backed by `assets/manifest.json` | code |
| H1 | Daily reward: reason `"daily_reward"`, UTC day boundary, 20 + 10/streak day, streak cap 7 | **session S0a only** |
| H2 | Inventory stores numeric ItemCatalog ids, never names, because renames broke saves | code + rationale in S0b |
| S1 | S0c says damage is in `EnemyService.DAMAGE` | **stale** after v2 |
| S2 | S0d refers to remote `BuyItem` | **stale** after v2 |

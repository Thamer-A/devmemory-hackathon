# CoinRush

Roblox round-based coin-collecting game, synced with Rojo (`default.project.json`).

## Layout
- `src/shared/` (ReplicatedStorage.Shared): Config, Remotes, Log, Assets, ItemCatalog, MathUtil, Types, Signal, Maid
- `src/server/services/` (ServerScriptService): Data, Currency, Leaderboard, Shop, Round, Enemy, CoinPickup, Admin services; `Main.server.luau` inits/starts them
- `src/client/controllers/` (StarterPlayerScripts): UI, HUD, Shop, Inventory, Input controllers
- `assets/manifest.json`: asset name -> rbxassetid

## Conventions
- Remotes: declare with `Remotes.define("Name")` in `src/shared/Remotes.luau`, use via `Remotes.get("Name")`. Never `Instance.new("RemoteEvent")` elsewhere.
- Coins change only via `CurrencyService.add(player, amount, reason)` with a reason string. Don't write leaderstats or data coins directly.
- Logging: `Log.info/warn/error(tag, ...)`. No `print`/`warn` in src.
- Tunables go in `src/shared/Config.luau`; no magic numbers in services.
- Asset ids only via `Assets.get("Name")` backed by `assets/manifest.json`.

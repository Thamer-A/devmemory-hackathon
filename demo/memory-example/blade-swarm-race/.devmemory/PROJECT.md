# project — project map

Engine: roblox (rojo). Files indexed: 16. Built deterministically (0 LLM tokens) at 2026-10-31T00:16:57+00:00.

## Rojo mapping
- `src/shared` -> ReplicatedStorage.Shared
- `src/server` -> ServerScriptService.Server
- `src/client` -> StarterPlayer.StarterPlayerScripts.Client

## Conventions (observed)
- `Instance.new("RemoteEvent")` occurs only in src/shared/Remotes.lua (observed); go through that module instead of repeating it.
- `print/warn` occurs nowhere in source (observed); avoid introducing it.
- `rbxassetid literal` occurs nowhere in source (observed); avoid introducing it.
- Tunables live in `src/shared/Config.lua` (80 keys, used by 10 files); add new constants there.

## Files
- `default.project.json`
- `src/client/BladeOrbit.client.lua`
- `src/client/CombatFx.client.lua`
- `src/client/Hud.client.lua`
- `src/client/ShopUi.client.lua`
- `src/client/UiKit.lua` — fn: corner, label, panel, stroke
- `src/server/Blades.server.lua`
- `src/server/Coins.lua` — fn: add, trySpend
- `src/server/Graveyard.server.lua`
- `src/server/Leaderboard.server.lua`
- `src/server/Shop.lua` — fn: close, open
- `src/server/Zombies.server.lua`
- `src/shared/BladeMath.lua` — fn: getOffset
- `src/shared/Config.lua` — 80 config keys
- `src/shared/Remotes.lua`

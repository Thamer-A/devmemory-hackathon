# game — project map

Engine: roblox (rojo). Files indexed: 27. Built deterministically (0 LLM tokens) at 2026-10-30T18:28:08+00:00.

## Rojo mapping
- `src/shared` -> ReplicatedStorage.Shared
- `assets/manifest.json` -> ReplicatedStorage.Shared.AssetManifest
- `src/server` -> ServerScriptService.Server
- `src/client` -> StarterPlayer.StarterPlayerScripts.Client

## Conventions (observed)
- `DataStore access` occurs only in src/server/services/DataService.luau (observed); go through that module instead of repeating it.
- `Instance.new("RemoteEvent")` occurs only in src/shared/Remotes.luau (observed); go through that module instead of repeating it.
- `data.coins writes` occurs only in src/server/services/CurrencyService.luau, src/server/services/DataService.luau (observed); go through that module instead of repeating it.
- `leaderstats writes` occurs only in src/server/services/LeaderboardService.luau (observed); go through that module instead of repeating it.
- `print/warn` occurs only in src/shared/Log.luau (observed); go through that module instead of repeating it.
- `rbxassetid literal` occurs nowhere in source (observed); avoid introducing it.
- `Log.warn(...)` is the shared entry point, called from 10 files.
- `Remotes.get(...)` is the shared entry point, called from 8 files.
- `Log.info(...)` is the shared entry point, called from 7 files.
- `CurrencyService.add(...)` is the shared entry point, called from 5 files.
- `Assets.get(...)` is the shared entry point, called from 4 files.
- `UIController.createLabel(...)` is the shared entry point, called from 3 files.
- `UIController.createPanel(...)` is the shared entry point, called from 3 files.
- `ItemCatalog.getById(...)` is the shared entry point, called from 3 files.
- Tunables live in `src/shared/Config.luau` (35 keys, used by 7 files); add new constants there.

## Files
- `default.project.json`
- `assets/manifest.json`
- `src/client/Main.client.luau`
- `src/client/controllers/HUDController.luau` — fn: init, start; remotes: CoinsChanged, EnemyHit, RoundState
- `src/client/controllers/InputController.luau` — fn: init, start
- `src/client/controllers/InventoryController.luau` — fn: init, start; remotes: EquipItem, InventoryChanged
- `src/client/controllers/ShopController.luau` — fn: init, start; remotes: InventoryChanged, PurchaseItem
- `src/client/controllers/UIController.luau` — fn: createButton, createLabel, createPanel, getPanel, getRoot, getTheme, init, toggle
- `src/server/Main.server.luau`
- `src/server/services/AdminService.luau` — fn: init, register, start
- `src/server/services/CoinPickupService.luau` — fn: getCoinCount, init, start
- `src/server/services/CurrencyService.luau` — fn: add, canAfford, get, init; remotes: CoinsChanged
- `src/server/services/DataService.luau` — fn: addItem, get, hasItem, incrementStat, init, markDirty, save, setEquipped; remotes: InventoryChanged
- `src/server/services/EnemyService.luau` — fn: getEnemyCount, init; remotes: EnemyHit
- `src/server/services/LeaderboardService.luau` — fn: init, set, start
- `src/server/services/RoundService.luau` — fn: getState, getTimeLeft, init, isPlaying, start; remotes: RoundState
- `src/server/services/ShopService.luau` — fn: init, start; remotes: EquipItem, PurchaseItem
- `src/shared/Assets.luau` — fn: get, getNumericId, has
- `src/shared/Config.luau` — 35 config keys
- `src/shared/ItemCatalog.luau` — fn: all, getById, getByName
- `src/shared/Log.luau` — fn: error, info, warn
- `src/shared/Maid.luau` — fn: new, Clean, Give
- `src/shared/MathUtil.luau` — fn: clamp, formatNumber, randomPointInPart, round
- `src/shared/Remotes.luau` — fn: define, get; defines remotes: CoinsChanged, EnemyHit, EquipItem, InventoryChanged, PurchaseItem, RoundState
- `src/shared/Signal.luau` — fn: new, Disconnect, new, Connect, DisconnectAll, Fire, Once, Wait
- `src/shared/Types.luau`

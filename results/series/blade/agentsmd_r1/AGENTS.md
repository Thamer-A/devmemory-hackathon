# Blade Swarm

Roblox game built with Rojo (`default.project.json`). Code lives in `src/shared`, `src/server`, `src/client`.

Keep this file up to date: after every change, record the design decisions (numbers, names, colors, rules) and where things live, so the next session can continue without re-reading everything.

## Layout
- `src/shared/Config.lua` - ALL tunable numbers (`Config.Blades`). Add new tunables here, never inline.
- `src/shared/Remotes.lua` - the only place RemoteEvents are defined (`EVENT_NAMES` list). Holds `BuyOffer` (slot) and `RerollOffers` (client -> server), plus `HitFx` and `CoinFx` (server -> client, cosmetic).
- `src/shared/BladeMath.lua` - `offset(index, count, t)` returns orbit offset + angle, driven by `workspace:GetServerTimeNow()` so server and clients agree.
- `src/server/init.server.lua` - sets player attribute `BladeCount` (starts at `Config.Blades.StartCount`) on join. Server owns the count.
- `src/client/init.client.lua` - renders every player's blades locally (anchored parts in `workspace.Blades`) on RenderStepped; reacts to `BladeCount` attribute changes.

- `src/server/Zombies.lua` - `Zombies.start()` (called from init.server): spawns zombies, chases nearest player, server-side blade hit detection, awards kills/coins. Zombies live in `workspace.Zombies`.
- `src/shared/Upgrades.lua` - `byId` lookup + derived stats read from player attributes `Up_<Id>` (stack counts): damageMult, spinMult, reachBonus, maxHealth, healPerKill, coinMult. `BladeMath.offset` takes an optional 4th arg `player` to apply Reach/Spin.
- `src/server/Shop.lua` - between-wave shop, all purchase logic. `Shop.open()/close()` are called from the wave loop in Zombies; `Shop.initPlayer` from init.server.
- `src/client/ShopUI.lua` - view only; panel bottom-center (above the HUD), 3 cards + Reroll button, fires remotes.
- `src/client/UIKit.lua` - shared helpers (`panel`, `label`, `corner`, `stroke`) using the `Config.UI` palette.
- `src/client/HudUI.lua` - always-on HUD (see Design decisions). Required from init.client before ShopUI.
- `src/client/FxUI.lua` - cosmetic effects only, tunables in `Config.Fx`. Listens to server -> client remotes `HitFx` (position, damage, killed; FireAllClients from `damage` in Zombies) and `CoinFx` (position, coins; FireClient to the killer only). Required from init.client after ShopUI.
- Leaderboard: `leaderstats` folder on each player with IntValues `Coins` and `Kills` (created in init.server).

## Design decisions
- Zombies: 60 health, blade hit = 20 damage (3 hits), Humanoid-based, WalkSpeed 10, gray-green box (2x5x1.5), spawn at a random point on the square ring at +-88 studs (inside the walls), one every 1.5s, max 25 alive. Re-target nearest living player every 0.25s via `Humanoid:MoveTo`. All numbers in `Config.Zombies`.
- Hit detection: each Heartbeat, blade positions = player root + `BladeMath.offset(i, count, GetServerTimeNow())`; hit if within `HitRadius` 4 studs of zombie root; each blade has a 0.5s cooldown per zombie. Killer gets credit.
- Rewards: 10 coins + 1 kill per zombie kill (`Config.Rewards.CoinsPerKill`).
- Waves (`Config.Waves`, logic in `Zombies.start`): wave 1 = 8 zombies, +4 per wave. A wave's zombies spawn one per `SpawnInterval` (still capped by `MaxAlive` 25 alive). Next wave starts 20s after the previous wave is fully killed (wave 1 starts immediately once a player is in). Health compounds x1.10 per wave (`Z.Health * 1.10^(wave-1)`). Current wave is the `workspace` attribute `Wave` (0 before start). Zombies also publishes workspace attrs `ZombiesLeft` (unspawned + alive) and `NextWaveAt` (server time the next wave starts; 0 while a wave is running).
- Game over (`resetRun` in `Zombies.start`): when wave >= 1 and every player is dead, the run resets: zombies destroyed, Shop closed, wave back to 0 (wave 1 starts right after), all `Up_<Id>` attrs cleared, `BladeCount` back to `StartCount`, Coins and Kills zeroed, everyone `LoadCharacter()`ed. The Heartbeat loop is paused (`resetting`) until respawns finish.
- Contact damage: a living zombie whose root is within `ContactRadius` 3.5 studs of a player root deals `ContactDps` 10/s (each zombie stacks), applied per Heartbeat via `Humanoid:TakeDamage` in `processContactDamage`.
- Blades: start 2, orbit radius 7 studs, neon cyan (0,255,255), size 0.4x1.2x3.5, orbit 180 deg/s, self-spin 720 deg/s, vertical bob 0.6 studs, Trail + PointLight glow.
- Blades are visual only on the client (no collisions). Kill detection is server-side using `BladeMath` positions.
- Blade count replicates via player attribute, not a RemoteEvent.

- Shop (`Config.Shop`, `Config.Upgrades`): opens when a wave (>=1) is fully killed, closes when the next wave starts (the 20s break). Each player gets 3 distinct random offers, picked by rarity weight (Common 70 / Rare 30 / Epic 10). Buying marks that slot sold (empty). Reroll = 10 coins, rerolls all 3 slots. Server validates: shop open, slot holds an offer, enough coins. Replication: workspace attr `ShopOpen`, player attr `ShopOffers` ("Id,Id,Id", sold = empty). Rarity colors (`Config.Shop.RarityColors`): Common gray (160,165,175), Rare blue (70,140,255), Epic purple (170,90,235). Epic upgrades render in purple via the same `RarityColors` lookup in ShopUI.
- Upgrades (all stackable, additive per stack, cost in coins): Blade +1 blade (Rare, 60); Damage +25% blade damage (Common, 30); Spin +20% orbit and self-spin speed (Common, 30); Reach +2 studs orbit radius, hit radius unchanged (Common, 35); Vitality +25 max HP, heals that amount, reapplied on respawn (Common, 25); Vampiric heal 2 HP per kill (Rare, 55); Greed +25% coins per kill, rounded (Rare, 50); Twin Spin (`TwinSpin`) +2 blades (Epic, 120; bumps `BladeCount` like Blade, handled in `Shop.apply`). Base max HP 100 (`Config.Player`). Spin/Reach purchases make blades visibly jump once (angle = t*speed).

- UI style (`Config.UI`): dark navy panels (14,20,40), rounded corners (12), faint cyan (0,255,255) outline; gold (255,205,60) is reserved for coins/costs. HUD: top-center panel with `WAVE n`, `Zombies: n`, and `Next wave: Ns` (cyan during the break, "Fight!" dim otherwise); bottom-left health bar (red->green by ratio, "hp / max"); bottom-right gold coin counter. Shop cards: rarity-colored outline + rarity label, name, description, gold cost; sold cards dim and read SOLD; Reroll button is cyan.

- Combat FX (`Config.Fx`): every blade hit shows a floating damage number (white 20pt, rises 4 studs over 0.7s, fades, small random horizontal scatter); the killing blow is orange (255,120,60) 26pt and triggers a burst at the zombie (24 green gibs + 12 cyan sparks, 0.6s). The killer also sees a gold "+coins" popup (uses `Config.UI.Coins`, 28pt, rises 5 studs over 1s) with the actual coins awarded (after Greed). Effects are client-side billboards/ParticleEmitters cleaned up with Debris; no gameplay state. Zombies destroyed by game-over reset show no FX.

## Roadmap (not built)
More Epic upgrades; wave-start / game-over banners (game over has no UI yet).

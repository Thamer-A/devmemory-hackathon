# Blade Swarm

Roblox game built with Rojo (`default.project.json`). Code lives in `src/shared`, `src/server`, `src/client`.

Keep this file up to date: after every change, record the design decisions (numbers, names, colors, rules) and where things live, so the next session can continue without re-reading everything.

## Rules
- All tunable numbers live in `src/shared/Config.luau` (never hardcode them elsewhere).
- Every RemoteEvent is declared in `EVENT_NAMES` in `src/shared/Remotes.luau` (server creates them, `Remotes.get(name)` fetches). Currently: `ShopBuy`, `ShopReroll` (client->server requests; state is replicated via Player/workspace attributes) and one-shot server->client effect events `DamageNumber`, `ZombieDeathFx`, `CoinPopup` (see "Done: combat effects").

## Game concept
Players have blades orbiting them; zombies swarm in waves; blades kill zombies; kills give coins; between waves the player buys random upgrades.

## Done: blade orbit (step 1)
- Decisions: start with 2 blades (`Config.Blades.StartCount`), orbit radius 7 studs, neon cyan `Color3.fromRGB(0,255,255)`, Neon material.
- Other Config.Blades values: OrbitSpeed 2.5 rad/s, SpinSpeed 14 rad/s (roll on own axis), HeightOffset 0.5, bob amplitude 0.6 @ 3 rad/s, blade size (0.3,1.2,4) wedge, PointLight (brightness 2, range 8), Trail (lifetime 0.35, width 1.2).
- `src/shared/BladeOrbit.luau`: `getCFrame(center, index, count, t)` is pure and deterministic from `workspace:GetServerTimeNow()`, so the server can reuse it later for hit detection and agree with clients.
- `src/server/BladeService.server.luau`: sets Player attribute `BladeCount` (= StartCount) on join. Upgrades should change this attribute.
- `src/client/BladeVisuals.client.luau`: each client renders anchored, non-colliding blade parts for ALL players in `workspace.LocalBlades` on RenderStepped; hides them when the character is dead/missing.
- Blade damage is now handled server-side by ZombieService (see step 2).
- Untested in Studio (no Roblox tooling here): run `rojo serve` and check it.

## Done: zombies (step 2)
- `src/server/ZombieService.server.luau` (numbers in `Config.Zombies` and `Config.Blades.Hit*`):
  - Zombie = Model in `workspace.Zombies`: `HumanoidRootPart` box (2,5,1.5), green `Color3.fromRGB(86,130,66)`, Humanoid health 60, WalkSpeed 10, server network owner.
  - Spawns every 1.5s at a random point on the arena edge (6 studs inside the +-90 walls), max 15 alive.
  - Chases the nearest living player with `Humanoid:MoveTo`, retargeting every 0.25s.
  - Hit detection is server-side on Heartbeat: blade positions from `BladeOrbit.getCFrame(root, i, BladeCount, GetServerTimeNow())`; hit = blade within `HitRadius` 3.5 of zombie root. 20 damage per hit (3 hits to kill); same blade re-hits the same zombie only after `HitCooldown` 0.5s.
  - Kill: +5 coins (`CoinsPerKill`) and +1 kill for the player whose blade landed the final hit.
  - Leaderboard: `leaderstats` folder per player with IntValues `Coins` and `Kills` (created in ZombieService).
- Zombies deal no damage to players yet; no waves yet (continuous spawning). Untested in Studio.
- Next: waves, zombie attacks, upgrade shop (spend `Coins`, change `BladeCount`).

## Done: zombies, blade damage, coins (step 2)
- All numbers in `Config.Zombies`: Health 60, WalkSpeed 10, MaxAlive 15, SpawnInterval 1.5s, SpawnEdgeInset 6, ArenaHalfSize 90 (arena 180x180 at origin, matches `default.project.json`), Size (2,5,1.5), color green `Color3.fromRGB(86,130,66)`, CoinsPerKill 5.
- Added to `Config.Blades`: HitDamage 20, HitRadius 3.5 studs (blade center to zombie root), HitCooldown 0.5s (per blade, per zombie).
- `src/server/ZombieService.server.luau` does everything server-side:
  - Spawns zombies (a Model with a HumanoidRootPart + Humanoid, in `workspace.Zombies`) at a random point on the arena edge, up to MaxAlive.
  - Every 0.25s each zombie `MoveTo`s the nearest living player.
  - Hit detection runs on Heartbeat: it uses `BladeOrbit.getCFrame` with `GetServerTimeNow()` and each player's `BladeCount` attribute.
  - Kill credit: +1 Kills and +CoinsPerKill Coins on the killer's `leaderstats` (IntValues `Coins`, `Kills`, created on join, which shows the Roblox leaderboard). Dead zombies are destroyed after 1s.
- Not done yet: zombies don't damage players; no waves; no upgrade shop (it should change `BladeCount` and spend `Coins`).
- Untested in Studio.

## Done: waves + contact damage (step 3)
- Numbers in `Config.Waves`: FirstWaveZombies 8, ZombiesPerWave +4 each wave, BreakSeconds 20, HealthGrowth 0.15 (compounding: health = `Zombies.Health * 1.15^(wave-1)`).
- Wave loop is at the bottom of `ZombieService.server.luau` (replaced the continuous spawner). Spawns one zombie per `SpawnInterval`, never more than `MaxAlive` alive; the wave ends when all its zombies are spawned and dead, then a 20s break, then the next wave. Waves are endless.
- State is replicated via workspace attributes: `Wave` (current number) and `BreakSecondsLeft` (0 during a wave). No UI yet.
- Contact damage: `Config.Zombies.ContactDamagePerSecond` 10, `ContactRadius` 4 studs (zombie root to player root); applied each Heartbeat as `TakeDamage(10*dt)` per touching zombie (stacks across zombies).
- This supersedes the "no waves / zombies deal no damage" notes above. Not done: wave/break UI, upgrade shop (spend `Coins`, change `BladeCount`) during breaks, player respawn/game-over rules. Untested in Studio.

## Done: upgrade shop (step 4)
- Config in `Config.Shop`: 3 offers per player (`OffersPerPlayer`), reroll 10 coins (`RerollCost`, replaces all 3), rarity roll weights Common 70 / Rare 30, rarity colors (Common grey, Rare blue `80,160,255`), `Upgrades` list, `Defaults`. `Config.Player.BaseMaxHealth` 100.
- Upgrades (each adds `Amount` to a Player attribute, unlimited stacking, additive): +1 Blade (Rare, 60, `BladeCount`+1); Sharper Blades (Common, 30, `DamageMult`+0.25); Faster Spin (Common, 30, `SpinMult`+0.2); Longer Reach (Common, 35, `ReachBonus`+2 studs of orbit radius, so hit reach grows too); Vitality (Common, 25, `MaxHealthBonus`+25, also heals 25); Vampiric (Rare, 55, `HealOnKill`+2 HP); Greed (Rare, 50, `CoinMult`+0.25).
- `src/server/BladeService.server.luau` initializes all stat attributes (from `Config.Shop.Defaults`) and applies max HP (base + `MaxHealthBonus`) on spawn/change. Upgrades persist across respawns, not across sessions (no saving).
- `src/server/ShopService.server.luau`: server-authoritative. Open only while workspace `BreakSecondsLeft` > 0; offers rolled per player (distinct, weighted by rarity) when the break starts, cleared when it ends. Replicated as Player attribute `ShopOffers` (comma-separated upgrade Ids; empty entry = already bought). Buy/reroll remotes validate: shop open, slot is an integer with an offer, enough `Coins`. A bought slot stays empty until reroll.
- `ZombieService` uses `DamageMult` (hit damage), `ReachBonus`/`SpinMult` (passed to `BladeOrbit.getCFrame`, new optional args), `CoinMult` (kill coins = round(5 * mult)), `HealOnKill`.
- `src/client/ShopUI.client.luau`: bottom-center panel with 3 cards + reroll button, visible during breaks; display only. `BladeVisuals` passes reach/spin so clients match the server.
- Not done: game-over/respawn rules. Untested in Studio.

## Done: HUD + shop restyle (step 5)
- Theme in `Config.UI`: navy panel `14,20,38` (cards/bars `26,36,62`), cyan accent `0,255,255` (outlines, wave title), gold `255,205,60` (coins, prices), health green `70,220,130` -> red `255,80,80` at <=30% HP, corner radius 12, panel transparency 0.12.
- Rarity colors (`Config.Shop.RarityColors`): Common gray `160,165,175`, Rare blue `80,160,255`, Epic purple `175,90,255`. Weights Common 65 / Rare 25 / Epic 10. New Epic upgrades: Blade Storm (+2 blades, 110), Titan Heart (+75 max HP, 90), Twin Spin (+2 blades, 120; `Config.Shop.Upgrades`, Id `TwinSpin`). Shop UI colors cards by `RarityColors[Rarity]`, so new upgrades only need a Config entry.
- `src/shared/UIKit.luau`: shared helpers (`panel`, `label`, `corner`, `stroke`); use these for any new UI.
- `src/client/HUD.client.luau`: top-center wave panel (WAVE n, NEXT WAVE countdown that shows "FIGHT!" during a wave, ZOMBIES LEFT), top-right coins (reads `leaderstats.Coins`), bottom-left health bar (local Humanoid; text `hp / max`).
- `src/client/ShopUI.client.luau`: restyled; cards have a rarity band/outline, rarity tag, name, description, gold price (red if unaffordable, card dimmed); sold slots show SOLD.
- New workspace attribute `ZombiesLeft` (alive + not yet spawned this wave), maintained in `ZombieService`.
- Gotcha: don't name a child GUI object `Name` (it shadows `Instance.Name`); the card title label is `ItemName`.

## Fix: contact damage (playtest)
- Playtest report: zombies didn't hurt players. Couldn't reproduce (no Studio); changed contact check in `ZombieService` to use horizontal (XZ) distance <= `ContactRadius` and set zombie `Humanoid.RequiresNeck = false` (rig has no Head). If it still fails, suspect blades killing zombies (reach ~10.5 studs) before they get within 4 studs, or add debug prints in `updateContactDamage`.

## Done: balance + game over (step 6)
- Playtest tuning: `Config.Waves.HealthGrowth` 0.15 -> 0.10 (health = `Zombies.Health * 1.10^(wave-1)`); `Config.Zombies.CoinsPerKill` 5 -> 10 (still multiplied by `CoinMult`). These supersede the 15% / 5-coin numbers above.
- Game over (bottom of `ZombieService.server.luau`): when every player has a Humanoid at 0 HP, `gameOver` is set; the wave loop exits and `resetRun()` destroys all zombies, sets `BreakSecondsLeft` 0, resets every player's `BladeCount` + `Config.Shop.Defaults` upgrade attributes and `Coins` to 0 (Kills kept), calls `LoadCharacter()`, then restarts at wave 1. No game-over UI yet. Untested in Studio.

## Fix: contact damage, round 2 (playtest)
- Still no damage reported; still can't reproduce (no Studio). Changes: `Config.Zombies.ContactRadius` 4 -> 5; contact damage now does `humanoid.Health -= dps*dt` instead of `TakeDamage` (a ForceField would block TakeDamage). SpawnLocation has Duration 0, so no spawn ForceField is expected.
- If it still fails, suspects: blades kill zombies before they get within 5 studs (blade reach ~10.5), or default Roblox health regen; add prints in `updateContactDamage`.

## Fix: wave stall / HUD / shop (playtest round 3)
- Reported: never reached wave 2, no shop, no visible HUD. Not reproducible without Studio; fixes are from code review, still untested.
- `ZombieService`: each zombie now also leaves `zombies`/`aliveCount` on `Humanoid.Died` or `Destroying` (before, only a blade kill did, so any other death left the wave stuck). Attribute reads (`CoinMult`, `DamageMult`, `HealOnKill`) are nil-safe.
- `HUD` and `ShopUI` ScreenGuis: `IgnoreGuiInset = true`, `ZIndexBehavior.Sibling`, DisplayOrder 10 (HUD) / 20 (shop).
- If wave 2 is still not reached: the player may be dying first (game over silently restarts at wave 1; no game-over UI). Check the Studio Output for script errors.

## Done: combat effects (step 7)
- Numbers in `Config.Effects`: `DamageNumber` (cream text, size 26, rises 4 studs over 0.7s, jitter 1.5), `DeathBurst` (green `120,200,80` particles, 24, lifetime 0.6), `CoinPopup` (gold `Config.UI.Gold`, size 30, rises 6 studs over 1.1s).
- `ZombieService` fires remotes: `DamageNumber(pos, damage)` on every blade hit and `ZombieDeathFx(pos)` on a blade kill (FireAllClients); `CoinPopup(pos, coins)` to the killer only (coins after `CoinMult`). Zombies dying other ways show no burst.
- (Round 4 note, see "Fix: HUD / shop not visible" at the bottom.)
- `src/client/CombatFx.client.luau`: display only; temporary anchored invisible parts (BillboardGui text / ParticleEmitter) in `workspace.LocalFx`, cleaned by Debris. Untested in Studio.

## Fix: HUD / shop not visible (playtest round 4)
- Reported: no shop offers between waves, no proper HUD. No Studio here, so the root cause is NOT confirmed (HUD/ShopUI/ShopService logic looked correct on review).
- Change: HUD and ShopUI now WaitForChild the Shared folder and each module instead of indexing ReplicatedStorage.Shared.X directly.
- The shop only opens after a wave is fully cleared (BreakSecondsLeft > 0). If a wave never clears or all players die, no shop or break timer appears.
- Next step needs the Studio Output window (client + server errors) to find the real cause.

## Fix: no coins/kills + no game over (playtest round 5)
- Coins/kills bug (found by review): a blade kill drops `Humanoid.Health` to <= 0, whose `Died` handler (`forget`) removed the zombie from `zombies` before `killZombie` ran, and `killZombie` returned early on `not zombies[model]`. It now guards with `state.rewarded`, so the killer gets Kills/Coins/popup/heal exactly once.
- Game over: detection (all players' Humanoids at 0 HP, on Heartbeat) now spawns `resetRun` on its own thread instead of relying on the wave loop. `resetRun` bumps `runGeneration`; the wave loop (spawn and break waits) exits when its generation is stale, waits for `gameOver` to clear, then restarts at wave 1. Reset contents unchanged (zombies cleared, Coins/upgrades reset, Kills kept, `LoadCharacter`). Still no game-over UI. Untested in Studio.

## Fix: no game over on death (playtest round 6)
- Cause not confirmed (no Studio). Polling `Humanoid.Health <= 0` could miss a death (e.g. character removed/respawned first), so game over never triggered.
- `ZombieService`: deaths are now tracked per player in `deadPlayers` via `Humanoid.Died` (cleared on `CharacterAdded`/reset); `allPlayersDead()` checks that table. `resetRun()` wraps `resetRunInner()` in `pcall` and always clears `gameOver` (prints `[ZombieService] all players dead - resetting to wave 1`; warns on failure); `LoadCharacter` is pcall'd too. Reset contents unchanged. If it still fails, check Studio Output for that print/warn. Untested in Studio.

## Done: graveyard at dusk (step 8)
- All numbers in `Config.Arena` (seed, torch spacing/light, decor ring radii, counts, colors, `Lighting` block).
- `src/server/ArenaDecor.server.luau` builds everything at runtime into `workspace.Decor` (deterministic `Random` from `Config.Arena.Seed`): lighting (ClockTime 17.6, warm ambient, fog, `Atmosphere` haze, `ColorCorrection`), floor recolored to dead-grass `62,66,50`, torches on top of the walls (post + Fire + orange PointLight, every 22 studs), cobblestone merlons along the wall tops, 60 gravestones (slate, leaning, rounded top or cross) and 26 recursive-branch dead trees.
- Decor only in the square ring 58..86 studs from the origin (middle stays clear; zombies spawn at 84, so they walk through the decor). All decor is `CanCollide=false`/`CanQuery=false` so it never blocks players or zombies.
- Walls/floor still come from `default.project.json`. Untested in Studio (many torch PointLights with shadows off; raise `TorchSpacing` if it lags).

## Fix: no coins/kills (playtest round 7)
- Cause not confirmed (no Studio). Hardened `ZombieService`: each blade hit records `state.lastAttacker`; the zombie's `Humanoid.Died` handler (`forget`) now calls `killZombie` itself when a recorded attacker killed it, so the reward no longer depends on the hit loop's post-damage check. `killZombie` (forward-declared) awards Kills/Coins/popup/heal FIRST, then sets Health 0, fires the death FX and schedules destroy, so an effects error can't skip the reward. Still guarded by `state.rewarded` (once only). Untested in Studio.

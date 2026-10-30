# Blade Swarm

A small co-op arena survival game for Roblox. Spinning blades orbit you, zombies swarm in
waves, every kill drops coins, and between waves a roguelite shop offers three random upgrades
(reroll for a price, then click Ready). Waves get harder; if everyone dies the run resets to wave 1.

## Controls

- Move: WASD / left thumbstick (the blades fight for you)
- Shop: click a card's price to buy, "Reroll" for new offers, "READY" to skip the timer
- Camera: default Roblox camera, zoom limits 25 to 45 studs (right-drag to tilt it more top-down)

## Sync with Rojo

```
rojo serve
```

Then connect from the Rojo plugin in Studio. The project only defines scripts:

- `ReplicatedStorage.Shared` from `src/shared`
- `ServerScriptService.Server` from `src/server`
- `StarterPlayer.StarterPlayerScripts.Client` from `src/client`

The map, lighting and zombie model live in the place file, not in this repo.

## Studio objects the code looks for (all optional)

- `ServerStorage.ZombieTemplate`: a Model with a Humanoid, HumanoidRootPart and PrimaryPart.
  If missing, a green R15 zombie is built with `Players:CreateHumanoidModelFromDescription`
  (and a plain block zombie if that call fails).
- `Workspace.ZombieSpawns`: a Folder of Parts. Zombies spawn at random points on them.
  If missing, zombies spawn on a ring of `Config.SpawnRingRadius` around `Config.ArenaCenter`.
- If the template has no server-side `Animate` script, a default R15 walk animation is played
  on it while it moves.

Tunables (wave scaling, stats, prices, colors) are all in `src/shared/Config.luau`; the
upgrade pool is `src/shared/Upgrades.luau`.

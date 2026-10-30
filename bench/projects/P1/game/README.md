# CoinRush

CoinRush is a small round-based Roblox arcade game. Players collect coins that spawn around the arena, fight off waves of Grunt and Brute enemies, and survive until the timer runs out to earn a round reward. Coins are spent in the shop on boosts and cosmetics, and all progress is saved with DataStores.

## Build

```
rojo build -o CoinRush.rbxlx
```

Open the generated place file in Roblox Studio.

## Layout

- `default.project.json` - Rojo project file.
- `assets/manifest.json` - map of asset names to `rbxassetid://` ids.
- `src/shared` - modules available to both server and client (config, remotes, catalog, utilities).
- `src/server` - server bootstrap and services (data, currency, shop, rounds, enemies, coins, admin).
- `src/client` - client bootstrap and UI/input controllers.

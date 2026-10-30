# Blade Swarm series: Studio playtests (2026-10-30)

## Method
- Each final project was built with Rojo 7.7.1 into a place and opened in Roblox Studio on an empty arena (no map dressing, no zombie model). Each was played for 30 s through the Studio MCP (`start_stop_play`), standing still at spawn.
- Server state was read with `execute_luau`, and the Output log with `get_console_output`. Screenshots are in `screens/`.
- Before each run, the place was checked to contain only its own scripts. A first attempt was discarded: the Rojo plugin had auto-synced the reference game's code into the test windows. Rojo was then stopped, and the places were reopened clean.
- `rbxassetid://203785492` warnings appear in every place, the reference included. They come from Studio itself, not the games.

## Results

| Condition | Script errors | Blades render | Kills / coins in 30 s | HUD | Notes |
|---|---|---|---|---|---|
| none | 0 | yes | 6 / 60 | wave, status, zombies left, health, coins | "Zombies left" stays at 8 after kills (HUD bug) |
| agentsmd | **1 (client crash)** | **no** | **0 / 0** | stuck at "WAVE 0", empty coin panel | `HudUI.lua` and `ShopUI.lua` are required as modules but return nothing. The client entry script errors before it renders blades. The game is unplayable. |
| devmemory | 0 | yes | 7 / 70 | wave, zombies left (updates), coins, health | the label "NEXT WAVE" shows "FIGHT!" during a wave (cosmetic) |
| reference Blade Swarm (hand-directed, MCP-polished) | 0 | yes | (played to wave 7 by the user earlier) | full HUD, shop cards, stats chips | adds a map, lighting and a Creator Store zombie model |

## Takeaways
- The static spec-adherence check scored all three 24/24, but one of the three builds was **unplayable**. Static checks are not enough: a playtest gate is needed. The Studio MCP makes that gate automatable.
- One run per condition: this is a case study, not a statistical result.

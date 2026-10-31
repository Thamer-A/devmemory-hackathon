# Adaptive race: blade

Each prompt is a fresh headless Claude Code session (Sonnet). After every session the game is playtested in Roblox Studio by the same behavioural probe; the next prompt is a bug report built from failed checks, else the next roadmap feature (10 features, cap 16 prompts). Cost = CLI list-price equivalent. One run per condition: a case study, not a statistical result.

| Condition | Prompts | Feature prompts | Fix prompts | Total cost | Input tokens | Features reached | Failing checks at end |
|---|---|---|---|---|---|---|---|
| none | 16 | 7 | 9 | $3.41 | 3,083,552 | 7/10 | shop_offers |
| agentsmd | 16 | 9 | 7 | $2.88 | 3,410,995 | 9/10 | waves_advance, shop_offers, hud_visible |
| devmemory | 16 | 9 | 7 | $2.48 | 1,846,255 | 9/10 | game_over_reset |

## Timeline (prompt kind → failed checks after playtest)

- **none**: P1-R1 (✓) → P2-R2 (✓) → P3-R3 (✓) → P4-R4 (✓) → P5-R5 (✓) → P6-R6 (✓) → P7-R7 (✗ waves_advance,shop_offers,hud_visible) → P8-fix (✗ waves_advance,shop_offers) → P9-fix (✗ waves_advance,shop_offers) → P10-fix (✗ waves_advance,shop_offers) → P11-fix (✗ waves_advance,shop_offers) → P12-fix (✗ game_over_reset) → P13-fix (✗ waves_advance,shop_offers) → P14-fix (✗ waves_advance,shop_offers) → P15-fix (✗ waves_advance,shop_offers) → P16-fix (✗ shop_offers)
- **agentsmd**: P1-R1 (✓) → P2-R2 (✓) → P3-R3 (✓) → P4-R4 (✓) → P5-R5 (✓) → P6-R6 (✓) → P7-R7 (✗ player_damaged) → P8-fix (✗ player_damaged) → P9-fix (✗ waves_advance,shop_offers,hud_visible) → P10-fix (✓) → P11-R8 (✗ shop_offers,hud_visible) → P12-fix (✗ kills_and_coins,game_over_reset) → P13-fix (✗ game_over_reset) → P14-fix (✓) → P15-R9 (✗ kills_and_coins) → P16-fix (✗ waves_advance,shop_offers,hud_visible)
- **devmemory**: P1-R1 (✓) → P2-R2 (✓) → P3-R3 (✓) → P4-R4 (✗ shop_offers) → P5-fix (✗ player_damaged,shop_offers) → P6-fix (✗ waves_advance,shop_offers) → P7-fix (✓) → P8-R5 (✓) → P9-R6 (✓) → P10-R7 (✗ no_errors,zombies_spawn,zombies_chase,kills_and_coins,waves_advance,player_damaged,shop_offers,hud_visible) → P11-fix (✓) → P12-R8 (✗ player_damaged,shop_offers,hud_visible) → P13-fix (✗ waves_advance,shop_offers,hud_visible) → P14-fix (✓) → P15-R9 (✗ game_over_reset) → P16-fix (✗ game_over_reset)

## Protocol changes made during the race (applied to all conditions from that point on)

1. Chase check also passes when zombies come within 6 studs (measurement could start late).
2. The between-waves shop appearing also counts as evidence of a wave transition.
3. From P7, bug reports include Output-window 'Infinite yield' warnings (what a user would see).
4. Probe v2: the passive test player is kept alive during observation (a correct game-over reset hid the shop).
5. Probe v3 + 25 s game-over window: the test player walks a slow circle (a standing player let zombies park inside the blade orbit); the reset is watched for 25 s instead of 12 s.
6. Studio-vs-disk sync check before every playtest after the `none` Rojo server crashed (its P7-P12 were invalidated and re-run from the P6 checkpoint).

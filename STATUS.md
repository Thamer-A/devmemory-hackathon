# STATUS (updated Fri 30 Oct, evening ET)

## Results so far
- **Fixed benchmark (P1 dev, P1+P2 held-out):** `results/devfinal_report.md`, `results/heldout_report.md`. Held-out headline: C3 86% pass at $0.0087/success vs C1 72% $0.0104, C0 67% $0.0099, Sonnet ~$0.09–0.10. C3 is the only condition at the 80% floor.
- **8-prompt scripted series (Sonnet):** `results/series_blade_report.md` and `results/series/blade/PLAYTEST.md`.
  - DevMemory: $1.04 and 605k input tokens. AGENTS.md: $1.39 and 1.20M. None: $1.25 and 1.06M.
  - All three honour 24/24 decisions statically, but the AGENTS.md build crashes in Studio.

## In progress: adaptive race (`bench/adaptive_run.py`, `bench/adaptive/blade/race.json`)
- **Loop:** one fresh Sonnet session per prompt → Studio playtest with the probes → next prompt chosen by a fixed rule: a bug report from the failed checks if anything failed, otherwise the next roadmap item (R1–R10). Cap of 16 prompts.
- **Work dirs:** `%TEMP%/devmem-runs/adaptive_blade_<cond>_r1/` (project, devmemory store, `state.json`). Log: `results/adaptive_blade.jsonl`.
- **Rojo serve ports:** none 34873, agentsmd 34874, devmemory 34875. These are detached `rojo.exe` processes; kill them at the end.
- **Studio windows:** race_none, race_agentsmd, race_devmemory, built with the probes baked in from `demo/build/race_<c>.project.json`.
- **Commands:**
  - `python -m bench.adaptive_parallel --race blade --conditions ...` runs the next session.
  - `python -m bench.adaptive_run record ... --server JSON --client JSON [--gameover JSON]` records a playtest.
  - `python -m bench.adaptive_run status --race blade` shows progress.
- **Protocol changes made mid-race (all conditions, disclose these):**
  1. The chase check also passes when zombies come within 6 studs.
  2. The shop appearing also counts as proof of a wave transition.
  3. From P7, bug reports include Output-window "Infinite yield" warnings.
  4. Probe v2 (`observeAlive`) keeps the test player alive; added after game over hid the shop.

### Race incident (19:15 ET)
- The Rojo server for `none` (port 34873) crashed at 17:22, during P6 (Rojo panic on a deleted file). From P7 on, the `none` Studio window tested stale P6 code, so none's P7–P12 results are INVALID. Two of its fix sessions made no changes.
- The agentsmd and devmemory windows were verified in sync (byte counts match).
- Low memory then killed the round-13 sessions (no partial edits) and the UI server. Each of the 4 Studio windows uses about 2 GB.
- Fix going forward: verify Studio matches the files before every playtest; restart Rojo when it dies.

## Also built today
- DevMemory UI: `python -m devmem ui --project P --store S`, an Obsidian-style local app.
- Blade Swarm showcase: `demo/blade-swarm` (code) and `demo/BladeSwarm_Final.rbxl` (place with map, lighting and zombie model). `demo/blade-swarm/studio/build_map.luau` rebuilds the map.

## Next
- Finish the race, then write its report and screenshots.
- Second race on a web app (the user chose option B; the team task board is my recommendation, awaiting confirmation).
- Deck (8–10 slides), video (3 min or less), project page. Target: published by 11 AM ET Sat.

## Known issues
- Never write Python containing `\\` through a bash heredoc here; use the Write tool.
- Don't leave the shell cwd inside fixture dirs.
- The Rojo plugin can auto-connect new windows. Check each window holds the right code before playtesting.

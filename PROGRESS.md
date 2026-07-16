# Progress

> Status of the Roblox Lightbike Tron Game project.

---

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| A | Foundation (shared state, types, RemoteEvents) | Complete |
| B | Local Movement (input buffer + grid snapping) | Complete |
| C | Server Authority (fixed tick + state broadcasting) | Complete |
| D | Collision (axis-aligned math intersection) | Complete |
| E | Interpolation + Visuals (snapshot buffer + Lerp) | Partial - basic enemy rendering works, BikeVisuals is a stub |
| F | AI Bots (flood-fill pathfinding) | Not implemented - AIBot.luau is an empty stub |

---

## Current State

Phases A-E (partial) are implemented. Key features:

- Client-side prediction with input buffering and grid-snapped 90 degree turns
- Server authority with fixed-rate tick (30 Hz), ping-compensated turn validation, and UnreliableRemoteEvent state broadcasting
- Decorative trails - server-authoritative trail parts with client-side instant feedback
- Math-based collision - axis-aligned line intersection (no raycasts or Touched) with self-hit and other-player detection
- Arena bounds - configurable size (default 4096), kills players who exit
- Enemy interpolation - snapshot-based rendering of other players
- Character anchoring - HumanoidRootPart is anchored/made transparent instead of using PrimaryPart = nil, preventing unintended fall deaths
- Material constants - TRAIL_MATERIAL and BIKE_MATERIAL replace hardcoded Enum.Material.Neon

## Not Yet Implemented

- Safe zone - never written
- AI bots - stub only
- Bike glow / death particles - stub only
- Bloom / dark arena lighting - not in source (was applied directly in Studio, lost on rebuild)

## What's Next

- Implement AIBot.luau (flood-fill pathfinding)
- Implement BikeVisuals.luau (glow, particles, death FX)
- Add safe zone spawn protection
- Tune lighting/bloom in default.project.json

---

## Workflow Rules (Active)

These rules must be followed during development to avoid data loss or stale builds:

| Rule | Detail |
|------|--------|
| Source files are the source of truth | All permanent changes go into src/ or default.project.json. MCP/Roblox Studio is for temporary inspection only. |
| rojo build to rebuild | Always run `rojo build -o "Roblox Tron Game.rbxlx"` to create a fresh place file. Do not edit the .rbxlx directly. |
| Avoid BOM corruption | Use `[System.IO.File]::WriteAllText(path, content)` in PowerShell (UTF-8 no BOM). Never use `Set-Content -Encoding UTF8` which adds BOM bytes and breaks scripts. |
| Commit to git | Changes must be committed (git add -A; git commit; git push) to persist permanently. |
| rojo serve for live dev | Run `rojo serve` in the project directory. Connect the Rojo Studio plugin to localhost:34872 for instant file sync. Kill stale serve processes with `Stop-Process -Name rojo` before restarting. |
| Close Studio for clean builds | If using .rbxlx directly (not rojo serve), close Studio before rebuilding to avoid .rbxlx.lock conflicts. |

---

## Constants (tunable in src/shared/Constants.luau)

| Constant | Value | Notes |
|----------|-------|-------|
| BIKE_SPEED | 60 | studs/sec |
| BIKE_SIZE | (2, 1, 4) | bike part dimensions |
| TURN_ANGLE | 90 | degrees |
| GRID_SIZE | 2 | studs per grid cell |
| ARENA_SIZE | 4096 | half-extent = 2048 |
| TICK_RATE | 30 | server ticks per second |
| TRAIL_HEIGHT | 3 | trail part height |
| TRAIL_WIDTH | 0.5 | trail part width |
| TRAIL_FADE_TIME | 10 | seconds before trail autodeletes |
| TRAIL_MATERIAL | SmoothPlastic | trail part material |
| BIKE_MATERIAL | SmoothPlastic | bike part material |
| MAX_TURN_RATE | 8 | max turns/sec per player |
| INTERP_DELAY | 0.1 | render-in-the-past for enemies |
| SPAWN_Y | 1 | bike center Y |
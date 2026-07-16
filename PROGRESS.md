# Progress

> Status of the Roblox Lightbike Tron Game project.

---

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| A | Foundation (shared state, types, RemoteEvents) | ✅ Complete |
| B | Local Movement (input buffer + grid snapping) | ✅ Complete |
| C | Server Authority (fixed tick + state broadcasting) | ✅ Complete |
| D | Collision (axis-aligned math intersection) | ✅ Complete |
| E | Interpolation + Visuals (snapshot buffer + Lerp) | ⚠️ Partial — basic enemy rendering works, BikeVisuals is a stub |
| F | AI Bots (flood-fill pathfinding) | ❌ Not implemented — AIBot.luau is an empty stub |

---

## Current State

Phases A–D are fully implemented. Phases E–F are incomplete. Key features:

- **Client-side prediction** with input buffering and grid-snapped 90° turns
- **Server authority** with fixed-rate tick (30 Hz), ping-compensated turn validation, and UnreliableRemoteEvent state broadcasting
- **Decorative trails** — server-authoritative trail parts with client-side instant feedback
- **Math-based collision** — axis-aligned line intersection (no raycasts or .Touched)
- **Enemy interpolation** — basic snapshot rendering
- **Respawn** — server revives via CharacterAdded

## Not Yet Implemented

- **Safe zone** — never written
- **AI bots** — stub only
- **Bike glow / death particles** — stub only
- **Bloom / dark arena lighting** — not in source (was applied directly in Studio, lost on rebuild)

## What's Next

- Implement AIBot.luau (flood-fill pathfinding)
- Implement BikeVisuals.luau (glow, particles, death FX)
- Add safe zone spawn protection
- Tune lighting/bloom in default.project.json

---

## ⚠️ Workflow Rule: Source Files Are Permanent, MCP Is Not

**Do NOT use MCP for changes you want to keep.** MCP modifications (execute_luau, setting Lighting properties, inserting parts) live only in the current Studio session and the .rbxlx file. When you run `rojo build`, they are permanently lost.

**Always make permanent changes in the Rojo project:**

| What | Where |
|------|-------|
| Game logic | `src/client/*.luau`, `src/server/*.luau` |
| Shared config | `src/shared/Constants.luau`, `src/shared/Types.luau` |
| Lighting, Bloom, instances | `default.project.json` |
| Visual effects code | `src/client/BikeVisuals.luau` |

**Workflow to make changes stick:**
1. Edit the source file
2. Run `rojo build -o "Roblox Tron Game.rbxlx"` to rebuild
3. Open in Studio and test
4. Commit to git

**MCP is for temporary use only:**
- Inspecting console output (`get_console_output`)
- Taking screenshots (`screen_capture`)
- Debugging (never saved)

---

## Constants (tunable in src/shared/Constants.luau)

| Constant | Value | Notes |
|----------|-------|-------|
| BIKE_SPEED | 60 | studs/sec |
| GRID_SIZE | 2 | studs per grid cell |
| ARENA_SIZE | 512 | half-extent = 256 |
| TICK_RATE | 30 | server ticks per second |
| TRAIL_FADE_TIME | 10 | seconds before trail autodeletes |
| SPAWN_Y | 1 | bike center Y |

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
| E | Interpolation + Visuals (snapshot buffer + Lerp) | ✅ Complete |
| F | AI Bots (flood-fill pathfinding) | ✅ Complete |

---

## Current State

All phases A-F are implemented and functional. Key features:

- **Client-side prediction** with input buffering and grid-snapped 90° turns
- **Server authority** with fixed-rate tick (30 Hz), ping-compensated turn validation, and UnreliableRemoteEvent state broadcasting
- **Decorative trails** — server-authoritative trail parts with client-side instant feedback
- **Math-based collision** — axis-aligned line intersection (no raycasts or .Touched)
- **Enemy interpolation** — snapshot buffer + Lerp for smooth enemy bikes
- **AI bots** — flood-fill pathfinding, turns treated identical to human players
- **Safe zone** — configurable no-trail radius around spawn; prevents trail rendering until bike exits
- **Respawn** — server revives via CharacterAdded
- **Visible safe zone boundary** — semi-transparent yellow walls with glowing corner pillars for testing

## Known Issues

None.

## What's Next

Polish and tuning:
- Dark arena + bloom lighting via MCP
- Grid floor texture
- Bike glow / trail shimmer effects
- Death explosion particles
- Camera FOV punch tuning

---

## Constants (tunable in src/shared/Constants.luau)

| Constant | Value | Notes |
|----------|-------|-------|
| SAFE_ZONE_RADIUS | 150 | No trail until bike exits this radius |
| BIKE_SPEED | 60 | studs/sec |
| GRID_SIZE | 2 | studs per grid cell |
| ARENA_SIZE | 4096 | half-extent = 2048 |
| TICK_RATE | 30 | server ticks per second |
| TRAIL_FADE_TIME | 10 | seconds before trail autodeletes |
| SPAWN_Y | 1 | bike center Y |
| MATERIAL | SmoothPlastic | swap in one place |

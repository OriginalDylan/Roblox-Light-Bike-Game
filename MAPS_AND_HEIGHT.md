# Maps, Height (Bridges/Ramps) & Jump Power-ups — Feasibility & Implementation Plan

Status: Design document (no code changes yet). Date: 2026-08-14.

## 1. Goal
1. Multiple maps (with variety).
2. Maps with Z-Y height differences: elevated bridges, ramps.
3. Power-ups that let you jump over trails (leaving your own trail in the air
   in an arc).

## 2. Why this is a rework, not a feature flag
The game is fundamentally 2D: all movement, collision, broadcast and AI assume a
flat plane at SPAWN_Y.

### Current 2D dependencies
| Concern | Where | Assumption |
|---------|-------|-----------|
| Movement | `server/GameStateManager.serverTick`, `createPlayerState` | position moves only in XZ; Y fixed at SPAWN_Y |
| Collision | `shared/GameState.luau`, `server/CollisionService.luau` | 2D XZ axis-aligned segment intersection; no height |
| Broadcast | `GameStateManager.broadcastState` | snapshot only x,z,dx,dz (no Y) |
| Trail rendering | `TrailManager`, `LocalTrailRenderer`, `EnemyInterpolation` | parts placed at fixed ground Y |
| Arena | `shared/Constants.ARENA_SIZE`, `default.project.json` | single hardcoded square arena |
| AI bots | `server/AIBot.luau` | flat-grid flood-fill pathing |

## 3. Feature breakdown

### 3.1 More maps (flat) — Low/Moderate effort
- Map config list (bounds, walls/obstacles, spawn points, layout).
- Selection/rotation (random or UI).
- Thread per-map data through `isInsideArena`, spawn points, bot pathing, reset.
- Feasible and low-risk; mostly replacing hardcoded arena/Constants with map data.

### 3.2 Z-Y height (bridges, ramps) — High effort, core rework
Height breaks the 2D model:
- **Collision**: bikes/trails at different Y overlapping in XZ must NOT collide.
  Collision must become Y-band aware (core rewrite of GameStateHelpers +
  CollisionService). Ramps need elevation functions per map.
- **Movement**: Y changes with XZ on ramps; bridges hold Y; need per-map height
  attributes and Y integration.
- **Broadcast/interpolation**: snapshot gains Y; enemy rendering becomes 3D.
- **Trail rendering**: trail parts need per-segment Y (currently hardcoded ground Y).
- **AI**: pathing on a heightmap is much harder than flat flood-fill.

Net: effectively migrates the game from 2D to 2.5D/3D — touches nearly every module.

### 3.3 Jump power-up (arc over trails) — Moderate, but blockered on 3.2
- Requires Y-aware collision to skip segments below the rider's current height.
- "Trail in an arc": straight segments can't draw a curve, so decompose the jump
  into a polyline of small straight segments at incrementing/decrementing Y.
  Each is a normal segment at its own elevation -> fits existing collision model.
- Power-up lifecycle (pickup spawn, effect timing, HUD) is straightforward.

## 4. Cross-cutting insight: share one collision rewrite with free steering
Free steering (see FREE_STEERING.md) *also* requires generalizing segment
intersection. Height requires making that intersection 3D/Y-aware. Doing them
separately wastes work. Recommendation: rewrite the collision segment math ONCE
to arbitrary-orientation, Y-aware segments, and both features build on top.

## 5. Recommended order
1. Flat multi-map support (independent, cheap).
2. Rewrite collision once to arbitrary-orientation + Y-aware segments
   (unblocks free steering AND height).
3. Ramps/bridges on the Y-aware core.
4. Jump power-up + arc-trail polyline.

## 6. Phased implementation plan
Phase 1 — Map system (flat)
- Add `shared/Maps.luau` with a map-definition table (name, halfSize, spawns,
  walls, optional layoutLoadout).
- `shared/GameState.isInsideArena(x,z,map)` + `server/GameStateManager` spawn/reset
  read the active map.
- Map selection/rotation + expose active map on HUD if desired.

Phase 2 — Collision core rewrite (shared enabler)
- `shared/GameState.luau`: generalize makeSegment/segmentsIntersect to arbitrary
  orientation AND a vertical (Y) band check.
- `server/CollisionService`: replace axis-only shortcuts with general segment
  checks that compare segment Y-bands; keep self-collision.
- Add Y to broadcast snapshot and enemy rendering.

Phase 3 — Height maps
- Elevation model per map: ramp/horizon/bridge definitions; `elevationAt(x,z)`.
- Movement integration of Y (climb/fall on ramps, bridge edges).
- Trail parts placed at each segment's Y.
- AI: height-aware avoidance (or bots restricted to flat lanes initially).

Phase 4 — Jump power-up + arc trail
- Power-up spawn/magnet/effect; jump state raises bike Y over time.
- Jumping disables collision with segments below the bike's Y-band.
- Arc trail = polyline of small segments laid along the jump parabola; add each
  to trailHistory at its own Y.

Phase 5 — Polish
- Per-map lighting/spawn FX, HUD for power-ups, victory/restart on any map.

## 7. Risks / open questions
- Self-collision with elevated/arc trails and high turn rate — may need per-frame
  segment sampling.
- AI competitiveness on height maps; consider restricting bots to flat lanes.
- Replication bandwidth growth (Y + more segments).
- Map selection UX (auto-rotate vs player choice).
- How jump interacts with "phantom bike" / SpawnSync and restart overlays.
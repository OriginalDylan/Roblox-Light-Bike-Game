# Free Steering — Feasibility & Implementation Plan

Status: Design document (no code changes yet). Date: 2026-08-14.

## 1. Goal
Add free (continuous/analog) steering to the lightbikes, alongside the current
90-degree grid turn mode, without breaking the working grid game.

## 2. Why this is a rework, not a toggle
The entire movement, collision and AI logic assumes axis-aligned 90-degree turns.

### Current dependencies on 90 / grid turns
| Concern | Where | Assumption |
|---------|-------|-----------|
| Movement | `server/GameStateManager.serverTick`, `applyTurn` | moves along fixed-axis `direction`, snaps turns |
| Turn validation | `server/LightbikeServer.validateAndApplyTurn` | rejects `|dx|+|dz| ~= 1` (axis-aligned only) + ping-comp distance check |
| Collision | `shared/GameState.luau`, `server/CollisionService.luau` | `isHorizontal`/`isVertical`, `segmentsIntersect` for axis-aligned segments only, "same axis" shortcut |
| Client control | `client/LightbikeController` | `queueTurn(+-90)`, `GRID_SIZE` snapping, discrete input buffer |
| AI bots | `server/AIBot.luau` | distance scoring + grid flood-fill pathing |
| Trail rendering | `TrailManager`, `LocalTrailRenderer`, `EnemyInterpolation` | axis-aligned box sizing (CFrame.lookAt already handles arbitrary angles) |

## 3. Free-steering design
- Continuous heading `theta` per rider; direction = (cos,0,sin) of theta.
- A/D held -> turn at a max angular rate (e.g. ~200-300 deg/s), configurable.
- Optional light "turn radius" feel via finite turn rate (no instant turns).
- Position integration unchanged at BIKE_SPEED along current heading.
- Trail segments become arbitrary-orientation segments.

## 4. Per-area impact
| Area | Effort | Notes |
|------|--------|-------|
| Movement + replication | Moderate | Continuous heading; replicate heading/rotation; drop input buffer |
| Turn validation / anti-cheat | Moderate-High | Rate-based angular limit instead of snap-distance check |
| Collision math | High | Replace axis-aligned intersection with general segment intersection; harden self-collision tracking |
| AI bots | High | Flood-fill/grid pathing is incompatible; needs steering-aware dodge/avoid or limited pathing |
| Trail rendering | Low-Moderate | Mostly works; ensure trail follows arbitrary angles cleanly |
| Tuning | Low | Add STEER_RATE, control mode constant |

## 5. Recommended approach: dual control mode
Introduce a shared `CONTROL_MODE = "GRID" | "FREE"` constant (in
`shared/Constants.luau`). Keep the working grid path intact; gate free-steering
behind the new mode across:
- `client/LightbikeController` (input + prediction)
- `server/LightbikeServer` (validation)
- `server/GameStateManager` (movement integration)
- `shared/GameState.luau` + `server/CollisionService` (collision)
- `server/AIBot` (AI decision)

This lets free steering ship and be tuned without regressing the grid game.

## 6. Phased implementation plan
Phase 1 — Foundation & movement (free direction)
- Add `CONTROL_MODE` + `STEER_RATE` to `shared/Constants.luau`.
- `shared/GameState.luau`: generalize `makeSegment`/`segmentsIntersect` to
  arbitrary orientations (keep axis-aligned fast path for GRID mode).
- `client/LightbikeController`: continuous heading, A/D press-and-hold steering,
  remove grid snapping/input buffer in FREE mode.
- `server/GameStateManager`: integrate continuous heading; new applyHeading.
- `server/LightbikeServer`: rate-based turn validation in FREE mode.

Phase 2 — Collision
- `shared/GameState.luau`: general segment intersection (orientation-aware).
- `server/CollisionService`: replace "same axis" shortcuts with general
  segment-vs-segment + segment-vs-segment checks; keep self-collision.
- Verify both modes pass the same sanity tests.

Phase 3 — AI (largest risk)
- Temporarily keep bots on simple dodge-and-extend using lookahead probes, or
  a lightweight steering-based avoidance; optionally keep grid flood-fill only
  in GRID mode.

Phase 4 — Rendering & feel
- Trail parts: ensure CFrame/sizing correct for arbitrary angles (already
  lookAt-based; validate length/SIZE math).
- Tune STEER_RATE, camera smoothing in FREE mode.

Phase 5 — Polish
- Restart/victory overlays, spawn sync, phantom-bike fixes already land for
  both modes.
- Add a quick verdict: keep FREE as default only after AI feels fair.

## 7. Risks / open questions
- Self-collision at high turn rate (tight loops) — may need per-frame segment
  sampling.
- AI fairness under free steering — decide whether bots stay grid-pathed or
  get simplified avoidance.
- Replication bandwidth of continuous heading vs discrete turns.
- Whether to offer FREE to bots at all in the first pass (recommended: no).
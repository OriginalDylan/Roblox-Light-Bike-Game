# Roblox Tron Game

A Tron Lightbike game built with Roblox and Rojo 7.6.1.

## Features

- **Client-side prediction** with input buffering and grid-snapped 90-degree turns
- **Server authority** with fixed 30 Hz tick rate and ping-compensated turn validation
- **Math-based collision** — axis-aligned line segment intersection (no raycasts, no .Touched)
- **Arena bounds** — configurable size, kills players who exit
- **Decorative trails** with fade-out animation
- **Enemy interpolation** — snapshot-based rendering of other players

## Controls

| Key | Action |
|-----|--------|
| A | Turn left 90° |
| D | Turn right 90° |

## Getting Started

### Prerequisites

- [Rojo](https://rojo.space) 7.x
- Roblox Studio with the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#plugin) installed

### Build

`ash
rojo build -o "Roblox Tron Game.rbxlx"
`

### Develop (live sync)

`ash
rojo serve
`

Then in Roblox Studio, open the Rojo plugin and connect to localhost:34872. Source file changes sync instantly.

## Project Structure

`
src/
  shared/       # Shared code (constants, types, game state math)
    Constants.luau    # All tunable game parameters
    GameState.luau    # Segment math helpers (intersection, arena check)
    Types.luau        # Type definitions
  server/       # Server-authoritative code
    GameStateManager.luau   # Fixed-rate tick loop, state broadcasting
    CollisionService.luau   # Collision detection
    LightbikeServer.luau    # Turn validation with ping compensation
    TrailManager.luau       # Visual trail parts with fade
    MatchManager.luau       # Death event handling
    AIBot.luau              # Stub (not implemented)
  client/       # Client-side code
    LightbikeController.luau    # Input handling, bike movement, camera
    LocalTrailRenderer.luau     # Client-side trail rendering
    EnemyInterpolation.luau     # Snapshot-based enemy rendering
    BikeVisuals.luau            # Stub (not implemented)
default.project.json    # Rojo project definition
`

## Configuration

Edit src/shared/Constants.luau to tune game parameters:

- BIKE_SPEED, ARENA_SIZE, TICK_RATE
- TRAIL_WIDTH, TRAIL_HEIGHT, TRAIL_FADE_TIME
- GRID_SIZE for turn snapping
- Player colors and materials
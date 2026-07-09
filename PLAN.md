# TRON LIGHTBIKE GAME - BUILD PLAN

> Target: A fast, low-latency multiplayer Lightbike game in Roblox. Built with OpenCode + Rojo + Roblox Studio MCP.

---

## 0 | Current State (audited)

| Item | Status |
|------|--------|
| Rojo project (`default.project.json`) | Initialized - maps src/client to StarterPlayerScripts, src/server to ServerScriptService, src/shared to ReplicatedStorage |
| Git repo | Initialized |
| Rokit + Rojo 7.7.0 | Installed (rokit.toml) |
| Roblox Studio MCP | Connected - Studio in Edit mode, Place1 loaded |
| Rojo Studio Plugin | Installed and connected (green indicator) |
| Baseplate in Workspace | Present |
| Source files | Stubs only (print("Hello world")) - clean slate |

> OpenCode (this agent) will use Rojo to write/edit .luau files on disk, and use the MCP to inspect the live game, tweak Lighting, read console output, and capture screenshots.

---

## 1 | The Architecture - "The Low-Latency Secret"

The single most important rule: **the client never waits for the server.** The game is built on six pillars.

### Pillar 1 - Client-Side Prediction with Input Buffering
- The player's device owns the bike's movement and turning. Input -> instant local state change -> render.
- No round-trip to the server for "permission to turn." This is what makes 90-degree turns feel snappy.
- **Input Buffer (Pac-Man style):** If a player presses a turn key slightly before reaching a grid intersection, the input is queued and executed the millisecond the bike crosses the next valid turn point. This prevents "I pressed turn but it didn't register" frustration.
- **Grid Snapping:** Force turns to snap to a hidden grid (e.g., every 2 studs). If the player presses turn slightly early, the client queues the turn and executes it at the next grid intersection. Keeps trails perfectly aligned.

### Pillar 2 - Server Verification with Ping Compensation
- The client fires a RemoteEvent (`TurnEvent`) with `turnPosition` (Vector3), `newDirection` (Vector3), `timestamp` (number, via `os.clock()`).
- The server validates plausibility using **timestamp-based ping compensation**: it calculates backward to verify if the player's claimed turn position is mathematically valid based on their previous speed, direction, and the time elapsed since their last turn.
- Distance check: if distance from last known position to `turnPosition` exceeds `BIKE_SPEED * (now - lastTurnTime) * 1.2` -> reject and optionally kick/flag.
- The server also runs the authoritative death check so a player can't lie about surviving.

### Pillar 3 - Authoritative Server Tick (Fixed Rate)
- The server does **not** run physics. It acts as a fast, strict referee validating math.
- Use `RunService.Heartbeat` on the server to step the game state forward at a fixed interval (e.g., 20 or 30 times per second).
- Each tick, the server advances every active bike's position: `pos += direction * BIKE_SPEED * dt`.
- Each tick, the server packages the entire game state (all active turn points and current directions) and fires it to all clients via a single **`UnreliableRemoteEvent`** (faster and better for real-time updates than standard RemoteEvents - dropped packets are fine since the next tick re-sends the full state).

### Pillar 4 - Axis-Aligned Math Collision (No Raycasts, No .Touched)
- Because movement is locked to 90-degree turns, all trails are straight lines on the X or Z axis (Y is constant). Collision detection is incredibly cheap with pure math.
- **Intersection Logic:** On every tick, check the player's current active line segment against all saved line segments in the arena.
- **The Math:**
  - If a trail is on the X-axis (horizontal) and your bike is moving on the Z-axis (vertical), a collision happens if your bike's Z coordinate crosses the trail's Z coordinate AND your bike's X coordinate is between the trail's `StartX` and `EndX`.
  - Same logic applies for the inverse (trail on Z-axis, bike moving on X-axis).
  - Self-collision: check against your own trail segments (excluding the most recent one you just turned from).
- **Head-to-Head Resolution:** If two players crash into each other head-on, the server checks the exact timestamps. Whoever entered the coordinate space first survives, or trigger a mutual destruction tie.
- Trail parts in the Workspace are **purely decorative** - Anchored, CanCollide=false, Material=Neon. They exist only for visuals. Collision is the math, not the parts.

### Pillar 5 - Client Interpolation for Enemy Bikes
- Other players must look perfectly smooth, even if the server updates only 20-30 times per second.
- **Snapshot Buffer:** When the client receives the server state via `UnreliableRemoteEvent`, save it in a buffer. Always render enemy bikes slightly in the past (roughly ping + one server tick, usually 50-100ms).
- **Linear Interpolation (Lerp):** To draw an enemy, look at their position in Snapshot A and Snapshot B. Use `Vector3:Lerp()` to smoothly glide their visual model between those two points based on the current render frame.
- **Dynamic Visual Trails:** On the client, generate a single anchored Part for every finalized line segment in the state data. Size it dynamically based on the distance between the start and end coordinates.

### Pillar 6 - Visuals Over Physics
- Trail parts are Anchored=true, CanCollide=false, Material=Neon. They are purely decorative.
- Zero physics cost for hundreds of trail segments.
- The bike itself is also Anchored and moved via code, not Roblox physics.
- Bike can be a basic Part (Phase B), upgraded to a MeshPart later (Phase E).

---

## 2 | Data Structures

### GameState (shared)
The arena and all players. A player's trail history is an array of coordinate pairs:

    trailHistory = {
      {startX, startZ, endX, endZ},  -- finalized segment
      {startX, startZ, endX, endZ},  -- finalized segment
      ...
    }

The "active" (growing) segment is NOT in the array - it is computed live from `lastTurnPosition` to `currentPosition`.

### Velocity Vectors
Directions are locked to four fixed vectors:
- `Vector3.new(1, 0, 0)`   - East
- `Vector3.new(-1, 0, 0)`  - West
- `Vector3.new(0, 0, 1)`   - South
- `Vector3.new(0, 0, -1)`  - North

### Per-Player Server State
    {
      player = Player,
      bikePart = Part,
      direction = Vector3,
      position = Vector3,
      lastTurnPosition = Vector3,
      lastTurnTime = number,
      trailHistory = {{startX, startZ, endX, endZ}, ...},
      alive = boolean,
      color = Color3,
    }

---

## 3 | Folder Structure (Rojo project)

Target layout inside src/:

    src/
      client/                              // StarterPlayerScripts (runs on each player's device)
        init.client.luau                   // Bootstrapper: requires all client modules
        LightbikeController.luau           // Core: input, movement, local turning, camera, input buffer
        LocalTrailRenderer.luau            // Client-side trail segment drawing for instant feedback
        EnemyInterpolation.luau            // Snapshot buffer + Lerp for smooth enemy bike rendering
        BikeVisuals.client.luau            // Local FX: bike glow, ignition particles, death explosion

      server/                              // ServerScriptService (runs once, server-side)
        init.server.luau                   // Bootstrapper: requires all server modules
        LightbikeServer.luau              // Core: listens TurnEvent, validates with ping comp, manages bikes
        GameStateManager.luau             // Maintains authoritative state, fixed tick loop, broadcasts via UnreliableRemoteEvent
        TrailManager.luau                 // Creates/stretches/fades trail parts (decorative only)
        CollisionService.luau             // Math-based line intersection -> death detection
        MatchManager.luau                 // Round flow, spawns, scoring, respawns, AI bot management
        AIBot.luau                         // Flood-fill pathfinding for AI opponents

      shared/                              // ReplicatedStorage (shared between client and server)
        Constants.luau                     // Tunable values: SPEED, GRID_SIZE, TURN_ANGLE, TRAIL_HEIGHT, colors
        Types.luau                         // Luau type definitions shared by client/server
        GameState.luau                     // Shared game state module (arena, players, trail history format)

### Constants.luau - the tuning knob file

    return {
        BIKE_SPEED       = 60,       -- studs/sec; fast but playable
        BIKE_SIZE        = Vector3.new(2, 1, 4),
        TURN_ANGLE       = 90,       -- 90-degree grid turns
        GRID_SIZE        = 2,        -- studs per grid cell (for grid snapping)
        ARENA_SIZE       = 512,      -- arena bounds in studs
        TICK_RATE        = 30,       -- server ticks per second
        TRAIL_HEIGHT     = 3,
        TRAIL_WIDTH      = 0.5,
        TRAIL_FADE_TIME  = 10,       -- seconds before a trail deletes itself
        MAX_TURN_RATE    = 8,        -- anti-cheat: max turns/sec
        INTERP_DELAY     = 0.1,      -- 100ms render-in-the-past for enemy bikes
        COLORS = {                   -- player palette
            Color3.fromRGB(0, 255, 255),   -- Cyan
            Color3.fromRGB(255, 128, 0),   -- Orange
            Color3.fromRGB(255, 0, 255),   -- Magenta
            Color3.fromRGB(0, 255, 0),     -- Green
        },
    }

### RemoteEvents in default.project.json

    "ReplicatedStorage": {
      "TurnEvent": { "$className": "RemoteEvent" },
      "StateUpdate": { "$className": "UnreliableRemoteEvent" },
      "ReplicateTurn": { "$className": "RemoteEvent" },
      "Shared": { "$path": "src/shared" }
    }

- **TurnEvent** - Client -> Server: `{turnPosition, newDirection, timestamp}`
- **StateUpdate** - Server -> All Clients (UnreliableRemoteEvent): full game state snapshot every tick
- **ReplicateTurn** - Server -> All Clients: verified turn broadcast (used for immediate turn feedback before next state tick)

---

## 4 | Build Phases - One System at a Time

> Rule enforced while coding: one module per session. Never say "make the whole game." Build incrementally, test each piece.

---

### PHASE A - Foundation and Shared State
Goal: Get the scaffolding in place so later scripts can just require things.

**A.1** - Update `default.project.json` to add `TurnEvent` (RemoteEvent), `StateUpdate` (UnreliableRemoteEvent), and `ReplicateTurn` (RemoteEvent) under ReplicatedStorage.

**A.2** - Write `src/shared/Constants.luau` with the table above.

**A.3** - Write `src/shared/Types.luau` with Luau type definitions for PlayerState, TrailSegment, GameStateSnapshot.

**A.4** - Write `src/shared/GameState.luau` - shared module defining the arena, trail history format, and helper functions (e.g., `isHorizontal(segment)`, `segmentsIntersect(segA, segB)`).

**A.5** - Update `src/client/init.client.luau` and `src/server/init.server.luau` to be minimal bootstrappers that require all modules (even if they are empty stubs) - proves the load order works.

**Checkpoint:** `rojo serve` -> enter Play Solo -> both client and server print their loaded module list with no errors. RemoteEvents appear in ReplicatedStorage in the Studio explorer.

---

### PHASE B - Local Movement Controller (the heart)
Goal: A single player can press Play, spawn as a Part instead of a humanoid, fly forward, and turn 90 degrees.

**B.1** - `LightbikeController.luau` (client). Responsibilities:
1. On character spawn, hide/destroy the default StarterCharacter (replace with a simple Part).
2. Create a Part (the bike): Anchored=true, CanCollide=false, Material=Neon, color from `Constants.COLORS`.
3. Maintain a direction vector (one of four fixed vectors, default `Vector3.new(0, 0, -1)`) and a position vector.
4. Every `RenderStepped`: `position += direction * BIKE_SPEED * deltaTime`. Set the bike Part's CFrame to look along direction.
5. **Input Buffer:** Bind A -> rotate direction -90 about Y; D -> +90 about Y. If the turn would happen between grid intersections, queue it and execute at the next grid snap point. Apply instantly (no tween - this is what makes it feel like Tron).
6. On each turn: fire `TurnEvent:FireServer(turnPosition, newDirection, os.clock())`.
7. Lock the camera: offset behind+above the bike, `CameraType = Scriptable`, lerp the CFrame for smoothness, bump `FieldOfView` up slightly with speed for a sense of velocity.

**B.2** - `LocalTrailRenderer.luau` (client). Responsibilities:
1. Every frame, locally spawn a thin Neon part from the last turn point to the current bike position - purely visual so the player sees their own trail instantly.
2. These local trail parts get cleaned up when the server's authoritative trail reaches the same segment (to avoid duplication).

**Checkpoint:** Play Solo - bike spawns, moves forward at constant speed, A/D snap-turn with grid snapping, camera follows, trail draws behind you. No server code needed yet.

---

### PHASE C - Server Authority, State Broadcasting, and Trails
Goal: Server listens, validates, maintains authoritative state, broadcasts to all clients, and draws decorative trails.

**C.1** - `LightbikeServer.luau` (server). Responsibilities:
1. `TurnEvent.OnServerEvent` -> receive `player`, `turnPos`, `newDir`, `timestamp`.
2. **Ping compensation anti-cheat:** Compute distance from the player's last known position to `turnPos`. If greater than `BIKE_SPEED * (now - lastTurnTime) * 1.2` -> reject and optionally kick/flag. Use the timestamp to calculate backward and verify the turn position is mathematically valid.
3. Store the turn in the per-player state table. Finalize the previous trail segment into `trailHistory`.
4. Replicate the verified turn to all clients via `ReplicateTurn` for immediate feedback.

**C.2** - `GameStateManager.luau` (server). Responsibilities:
1. Every `Heartbeat`, advance each active bike: `pos += dir * BIKE_SPEED * dt`.
2. Maintain the authoritative `GameState` (all players, their trail histories, current positions, directions, alive status).
3. Package the full state into a snapshot and fire via `StateUpdate:FireAllClients(snapshot)` every tick (at `TICK_RATE` Hz, throttled).

**C.3** - `TrailManager.luau` (server). Responsibilities:
1. On each verified turn, create an Anchored + CanCollide=false + Neon Part stretching from the player's last turn position to their current turn position.
2. Each Heartbeat, stretch the current (growing) trail segment endpoint to the bike's live position.
3. When `TRAIL_FADE_TIME` elapses after a segment stops growing, tween Transparency from 0 to 1 over 1s then `Destroy()`.

**Checkpoint:** Two-player Play test (Studio's "Two Players" start). Both see each other's bikes and trails. State updates broadcast correctly. Turning is replicated.

---

### PHASE D - Math-Based Collision and Death
Goal: Detect crashes using axis-aligned line intersection math.

**D.1** - `CollisionService.luau` (server). The kill logic. Responsibilities:
1. Every tick, for each active bike, check the player's current line segment (from `lastTurnPosition` to `currentPosition`) against all saved trail segments in the arena (all players' trails, including their own except the most recent segment).
2. **Intersection math:**
   - If a trail segment is horizontal (along X-axis) and the bike's active segment is vertical (along Z-axis): collision if bike's Z crosses the trail's Z AND bike's X is within `[trail.StartX, trail.EndX]`.
   - If a trail segment is vertical (along Z-axis) and the bike's active segment is horizontal (along X-axis): collision if bike's X crosses the trail's X AND bike's Z is within `[trail.StartZ, trail.EndZ]`.
   - Parallel segments (same axis): collision if they overlap on the shared axis AND share the same cross-axis coordinate.
3. **Arena bounds check:** if the bike's position exits `[-ARENA_SIZE/2, ARENA_SIZE/2]` on X or Z -> kill.
4. **Head-to-head:** If two players' active segments intersect on the same tick, compare timestamps. Earlier timestamp survives, or mutual destruction on tie.
5. On death: call `MatchManager:KillBike(player)`.

**D.2** - `MatchManager.luau` (server). Initial responsibilities:
1. `KillBike(player)`: mark player as dead, destroy their bike part, trigger trail fade on their segments, notify clients.
2. Basic round flow: countdown -> spawn bikes at grid points with divergent initial directions -> on single survivor (or all dead) -> end round -> restart.

**Checkpoint:** Two-player Play test. Turning one into the other's trail kills the offender. Arena walls kill. Head-to-head crashes resolve correctly.

---

### PHASE E - Enemy Interpolation and Visual Polish
Goal: Enemy bikes look smooth at all ping levels. Game looks like Tron.

**E.1** - `EnemyInterpolation.luau` (client). Responsibilities:
1. Listen for `StateUpdate` (UnreliableRemoteEvent) from server.
2. Store received snapshots in a ring buffer (keep last 2-3 snapshots).
3. For each enemy bike, render it `INTERP_DELAY` seconds in the past.
4. Use `Vector3:Lerp()` between Snapshot A and Snapshot B positions based on current render frame time.
5. Draw/update enemy trail segments from the snapshot's `trailHistory` data.

**E.2** - `BikeVisuals.client.luau` (client). Responsibilities:
1. Bike glow: PointLight child on the bike Part, Neon material.
2. Ignition particles: ParticleEmitter burst on spawn.
3. Death explosion: burst of neon shards + ParticleEmitter, brief slow-motion (TimeScale) on the local client.
4. Trail shimmer: subtle SurfaceLight or animated Texture on trail parts.

**E.3** - Lighting and arena visuals (via MCP):
- Set `Lighting.Ambient = Color3.new(0,0,0)`, add `BloomEffect` (Intensity 1.2, Size 24, Threshold 0.8), set `Lighting.Technology = Future`.
- Grid floor: large Part with neon-grid texture or MaterialVariant.
- Use MCP `screen_capture` to verify visuals, `get_console_output` to catch warnings.

**E.4** - Bike 3D Model (optional upgrade from basic Part):
- **Option A (best performance):** Model in Blender, export `.fbx`, import as MeshPart.
- **Option B (quickest):** Search Creator Store for "Cyber Bike" or "Sci-Fi Motorcycle", filter by Meshes. Check polygon count.
- **Option C (classic Roblox):** Build from primitive Parts (wedges, blocks, cylinders), weld into a Model.

**Checkpoint:** Play test with simulated latency. Enemy bikes are smooth. Visuals look like Tron - dark arena, neon glow, bloom. Screenshots confirm.

---

### PHASE F - AI Bots (Flood-Fill Survival)
Goal: Single-player practice against AI opponents.

**F.1** - `AIBot.luau` (server). Responsibilities:
1. **Grid conversion:** The AI views the arena as a 2D array (grid of 1s and 0s, where 1 = trail wall). Convert all trail segments to grid cells.
2. **Flood-fill check:** Every few ticks, run flood-fill on the AI's immediate left, right, and forward paths. Count open grid spaces in each direction.
3. **Decision making:** Always choose the direction with the most open space (largest flood-fill bucket). Never trap itself in a small box.
4. Execute the chosen turn via the same `TurnEvent` path as a human player (the server treats AI and human turns identically).

**Checkpoint:** Play Solo with 3 AI bots. They survive reasonably long and don't immediately trap themselves. Fun to play against.

---

## 5 | Visuals and Polish (use Roblox Studio MCP for these)

Once movement works, use the MCP tools (not Rojo) for live visual iteration so we can see changes without rebuilding:

| Task | MCP approach |
|------|--------------|
| Dark arena + bloom | `execute_luau` to set Lighting.Ambient, add BloomEffect, set Technology = Future. Then `screen_capture` to verify. |
| Grid floor | Insert a large Part with a custom neon-grid texture (MaterialVariant via `generate_material`), or a Texture decal repeating a grid PNG. |
| Bike glow | `inspect_instance` on the bike Part, tweak Material=Neon, Color, and add a PointLight child. |
| Trail shimmer | Add a subtle SurfaceLight to each trail, or an animated Texture. |
| Camera FOV punch | Tune the FOV lerp values in LightbikeController after watching a `screen_capture` during playtest. |
| Debug readout | `get_console_output` after a playtest to catch any nil or math warnings. |

Workflow: Edit code via Rojo (local files) -> `start_stop_play` (playtest) -> `get_console_output` + `screen_capture` to diagnose and tweak visuals live -> `start_stop_play` (stop) to return to edit mode.

---

## 6 | Iteration Discipline

- **One module per session.** Test (Play Solo) before moving on.
- Keep `Constants.luau` as the single source of tunable truth - never hardcode speed/size in a script body.
- Commit to git after every green checkpoint (A, B, C, D, E, F).
- If something breaks during a playtest, run `get_console_output` first, then fix the file via Rojo, then re-test. Don't guess.
- If a concept feels too complex for the current phase, defer it - the plan is layered so each phase works without the next.

---

## 7 | Suggested First Session Actions (in order)

1. Update `default.project.json` to add `TurnEvent`, `StateUpdate` (UnreliableRemoteEvent), and `ReplicateTurn` RemoteEvents under ReplicatedStorage.
2. Write `src/shared/Constants.luau`.
3. Write `src/shared/Types.luau`.
4. Write `src/shared/GameState.luau` (with segment intersection helper functions).
5. Create stub files for all client and server modules.
6. Update `init.client.luau` and `init.server.luau` to require all stubs.
7. Playtest via MCP (`start_stop_play`) and verify no load errors.
8. Commit to git as "feat: foundation - constants, types, state, remote events, bootstrappers".

That is the first deliverable slice. Everything after that builds on this foundation.

---

## 8 | Phase Priority Summary

| Phase | Goal | Key Innovation |
|-------|------|----------------|
| A | Foundation | Shared state, types, RemoteEvents |
| B | Local Movement | Input buffer + grid snapping |
| C | Server Authority | Fixed tick + UnreliableRemoteEvent broadcasting |
| D | Collision | Axis-aligned math intersection (no raycasts) |
| E | Interpolation + Visuals | Snapshot buffer + Lerp + Tron aesthetics |
| F | AI Bots | Flood-fill pathfinding |

---

*No code belongs in init.*.luau other than requires - all logic lives in named modules.*

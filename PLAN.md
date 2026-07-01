# TRON LIGHTBIKE GAME - BUILD PLAN

> Target: A fast, low-latency multiplayer Lightbike game in Roblox. Built with OpenCode + Rojo + Roblox Studio MCP.

---

## 0 | Current State (audited)

| Item | Status |
|------|--------|
| Rojo project (`default.project.json`) | Initialized - maps src/client to StarterPlayerScripts, src/server to ServerScriptService, src/shared to ReplicatedStorage |
| Git repo | Initialized |
| Rokit + Rojo 7.6.1 | Installed (rokit.toml) |
| Roblox Studio MCP | Connected - Studio in Edit mode, Place1 loaded |
| Baseplate in Workspace | Present |
| Source files | Stubs only (print("Hello world")) - clean slate |

### What you still need to do before coding starts
1. Build and open the place file - run `rojo build -o "Roblox Tron Game.rbxlx"` then open the .rbxlx in Roblox Studio.
2. Start the Rojo live-sync server - run `rojo serve` in the project root. Confirm the Studio plugin shows a green "Connected" indicator.
3. Enable HTTP Requests in Studio: Game Settings -> Security -> Enable HTTP Requests. Optional now but needed later for any web calls.
4. Keep both Rojo (for code) and the MCP connection (for debugging/visuals) running throughout.

> OpenCode (this agent) will use Rojo to write/edit .luau files on disk, and use the MCP to inspect the live game, tweak Lighting, read console output, and capture screenshots.

---

## 1 | The Architecture - "The Low-Latency Secret"

The single most important rule: **the client never waits for the server.** Four pillars enforce this.

### Pillar 1 - Client-Side Prediction
- The player's device owns the bike's movement and turning. Input -> instant local state change -> render.
- No round-trip to the server for "permission to turn." This is what makes 90-degree turns feel snappy.

### Pillar 2 - Server Verification (not server authority over movement)
- The client fires a RemoteEvent (TurnEvent) with turnPosition (Vector3), newDirection (Vector3), timestamp (number).
- The server validates plausibility (is the distance between turns within max-speed * delta-time * tolerance?) to catch exploiters, then replicates the turn to all other clients.
- The server also runs the authoritative death check (raycast collision) so a player can't lie about surviving.

### Pillar 3 - Raycast Hitboxes (no .Touched)
- At Lightbike speeds, Roblox physics .Touched events are unreliable - bikes clip through trails.
- Instead, every frame the server casts a short ray from just ahead of the bike's nose to its current position. If that ray intersects any trail part or arena wall -> player is dead.
- Clients do the same locally for instant visual feedback and the server confirms.

### Pillar 4 - Visuals Over Physics
- Trail parts are Anchored=true, CanCollide=false, Material=Neon. They are purely decorative - collision is the raycast math, not the part geometry.
- This means zero physics cost for hundreds of trail segments.

---

## 2 | Folder Structure (Rojo project)

Target layout inside src/:

    src/
      client/                          // StarterPlayerScripts (runs on each player's device)
        init.client.luau               // Bootstrapper: requires all client modules
        LightbikeController.luau       // Core: input, movement, local turning, camera
        BikeVisuals.client.luau        // Local FX: bike glow, ignition particles, death explosion
        LocalTrailRenderer.luau        // Client-side trail segment drawing for instant feedback

      server/                          // ServerScriptService (runs once, server-side)
        init.server.luau                // Bootstrapper: requires all server modules
        LightbikeServer.luau           // Core: listens TurnEvent, validates, replicates, manages bikes
        TrailManager.luau              // Creates/stretches/fades trail parts, cleanup
        CollisionService.luau           // Heartbeat raycast loop -> death detection
        MatchManager.luau              // (Later) round flow, spawns, scoring, respawns

      shared/                          // ReplicatedStorage (shared between client and server)
        Constants.luau                 // Tunable values: SPEED, GRID_SIZE, TURN_ANGLE, TRAIL_HEIGHT, colors
        TurnEvent.luau                 // RemoteEvent definition (or created via Studio MCP)
        Types.luau                     // (Optional) Luau type definitions shared by client/server

### Constants.luau - the tuning knob file

    return {
        BIKE_SPEED       = 60,       -- studs/sec; fast but playable
        BIKE_SIZE        = Vector3.new(2, 1, 4),
        TURN_ANGLE       = 90,       -- 90-degree grid turns
        RAYCAST_DISTANCE = 6,        -- how far ahead the nose ray looks each frame
        TRAIL_HEIGHT     = 3,
        TRAIL_WIDTH      = 0.5,
        TRAIL_FADE_TIME  = 10,       -- seconds before a trail deletes itself
        MAX_TURN_RATE    = 8,        -- anti-cheat: max turns/sec
        COLORS = {                   -- player palette
            Color3.fromRGB(0, 255, 255),   -- Cyan
            Color3.fromRGB(255, 128, 0),   -- Orange
            Color3.fromRGB(255, 0, 255),   -- Magenta
            Color3.fromRGB(0, 255, 0),     -- Green
        },
    }

---

## 3 | Build Phases - One System at a Time

> Rule enforced while coding: one module per session. Never say "make the whole game." Build incrementally, test each piece.

---

### PHASE A - Foundation and Shared State
Goal: Get the scaffolding in place so later scripts can just require things.

A.1 - Write src/shared/Constants.luau with the table above.

A.2 - Create the TurnEvent RemoteEvent. Declare it in default.project.json under ReplicatedStorage so it survives Rojo rebuilds:

    "ReplicatedStorage": {
      "TurnEvent": { "$className": "RemoteEvent" },
      "ReplicateTurn": { "$className": "RemoteEvent" },
      "Shared": { "$path": "src/shared" }
    }

A.3 - Update src/client/init.client.luau and src/server/init.server.luau to be minimal bootstrappers that just require the other modules (even if they are empty stubs) - this proves the load order works.

Checkpoint: rojo serve -> enter Play Solo -> both client and server print their loaded module list with no errors.

---

### PHASE B - Local Movement Controller (the heart)
Goal: A single player can press Play, spawn as a Part instead of a humanoid, fly forward, and turn 90 degrees.

B.1 - LightbikeController.luau (client). Responsibilities:
1. On character spawn, hide/destroy the default StarterCharacter (we will replace it with a simple Part).
2. Create a Part (the bike), set Anchored=true, CanCollide=false, Material=Neon, color from Constants.COLORS.
3. Maintain a direction vector (Vector3.new(0,0,-1) by default) and a position vector.
4. Every RenderStepped: position += direction * BIKE_SPEED * deltaTime. Set the bike Part's CFrame to look along direction.
5. Bind A -> rotate direction -90 about Y; D -> +90 about Y. Apply instantly (no tween - this is what makes it feel like Tron).
6. On each turn: fire TurnEvent:FireServer(turnPosition, newDirection).
7. Lock the camera: offset behind+above the bike, CameraType = Scriptable, lerp the CFrame for smoothness, bump FieldOfView up slightly with speed for a sense of velocity.

B.2 - LocalTrailRenderer.luau (client). Responsibilities:
1. Every frame, locally spawn a thin Neon part from the last turn point to the current bike position - purely visual so the player sees their own trail instantly.
2. These local trail parts get cleaned up when the server's authoritative trail reaches the same segment (to avoid duplication).

Checkpoint: Play Solo - bike spawns, moves forward at constant speed, A/D snap-turn, camera follows, trail draws behind you. No server code yet.

---

### PHASE C - Server Authority and Trail Generation
Goal: Server listens, validates, draws the authoritative trail, replicates to other clients.

C.1 - LightbikeServer.luau (server). Responsibilities:
1. TurnEvent.OnServerEvent -> receive player, turnPos, newDir, timestamp.
2. Anti-cheat: compute distance from the player's last known position to turnPos. If greater than BIKE_SPEED * (now - lastTurnTime) * 1.2 -> reject and optionally kick/flag.
3. Store the turn in a per-player table: lastTurnPos, currentDir, bikePart.
4. Replicate the verified turn to all other clients via a second RemoteEvent (ReplicateTurn) so their local copy of this player's bike turns at the right spot.

C.2 - TrailManager.luau (server). Responsibilities:
1. On each verified turn, create an Anchored + CanCollide=false + Neon Part stretching from the player's last turn position to their current turn position.
2. Each Heartbeat, stretch the current (growing) trail segment endpoint to the bike's live position (the server tracks the bike position each frame by advancing pos += dir * speed * dt).
3. When TRAIL_FADE_TIME elapses after a segment stops growing, tween its Transparency from 0 to 1 over 1s then Destroy().

C.3 - CollisionService.luau (server). The kill logic. Responsibilities:
1. Every Heartbeat, for each active bike, cast a ray from bikePosition forward along its direction by RAYCAST_DISTANCE.
2. If the ray hits a part in the trailParts set (any player's trail, including their own) or an arena wall -> call MatchManager:KillBike(player).
3. Also support a "wall of light" map boundary: if the ray exits the arena bounds, kill.

Checkpoint: Two-player Play test (use Studio's "Two Players" start). Both see each other's bikes and trails. Turning one into the other's trail kills the offender.

---

### PHASE D - Death, Respawn and Match Flow (later)
- MatchManager.luau: round start countdown, spawn bikes at grid points with divergent initial directions, track podium/scoring, respawn losers to a spectate or next-round queue.
- Death FX: BikeVisuals.client.luau - explosion of neon shards + ParticleEmitter, brief slow-motion (TimeScale) on the local client.

---

## 4 | Visuals and Polish (use Roblox Studio MCP for these)

Once movement works, use the MCP tools (not Rojo) for live visual iteration so we can see changes without rebuilding:

| Task | MCP approach |
|------|--------------|
| Dark arena + bloom | execute_luau to set Lighting.Ambient = Color3.new(0,0,0), add a BloomEffect (Intensity 1.2, Size 24, Threshold 0.8), set Lighting.Technology = Future. Then screen_capture to verify. |
| Grid floor | Insert a large Part with a custom neon-grid texture (MaterialVariant via generate_material), or a Texture decal repeating a grid PNG. |
| Bike glow | inspect_instance on the bike Part, tweak Material=Neon, Color, and add a PointLight child. |
| Trail shimmer | Add a subtle SurfaceLight to each trail, or an animated Texture. |
| Camera FOV punch | Tune the FOV lerp values in LightbikeController after watching a screen_capture during playtest. |
| Debug readout | get_console_output after a playtest to catch any nil or raycast warnings. |

Workflow: I edit code via Rojo (local files), then use MCP start_stop_play -> playtest -> get_console_output + screen_capture to diagnose and tweak visuals live, then start_stop_play (stop) to return to edit mode.

---

## 5 | Iteration Discipline

- One module per session. Test (Play Solo) before moving on.
- Keep Constants.luau as the single source of tunable truth - never hardcode speed/size in a script body.
- Commit to git after every green checkpoint (A, B, C, D).
- If something breaks during a playtest, run get_console_output first, then fix the file via Rojo, then re-test. Don't guess.

---

## 6 | Suggested First Session Actions (in order)

1. Update default.project.json to add the TurnEvent and ReplicateTurn RemoteEvents under ReplicatedStorage.
2. Write src/shared/Constants.luau.
3. Write src/client/LightbikeController.luau (Phase B.1).
4. Update src/client/init.client.luau to require it.
5. Playtest via MCP (start_stop_play) and screen_capture - verify the bike spawns, moves, and turns.
6. Commit to git as "feat: client movement controller".

That is the first deliverable slice. Everything after that builds on this foundation.

---

*No code belongs in init.*.luau other than requires - all logic lives in named modules.*

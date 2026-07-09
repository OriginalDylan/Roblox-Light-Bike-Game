--[[
    Types.luau
    ==========
    Luau type definitions shared between client and server.
    These keep the data structures consistent across the network boundary.
]]

-- A single finalized trail segment stored as coordinate pairs.
-- Movement is axis-aligned, so each segment is either horizontal (X-axis) or vertical (Z-axis).
-- startY/endY are omitted because Y is constant (SPAWN_Y).
export type TrailSegment = {
    startX: number,
    startZ: number,
    endX: number,
    endZ: number,
}

-- Per-player state tracked on the server.
-- The server owns this table; clients receive snapshots of it.
export type PlayerState = {
    player: Player,
    bikePart: Part?,
    direction: Vector3,
    position: Vector3,
    lastTurnPosition: Vector3,
    lastTurnTime: number,
    trailHistory: { TrailSegment },
    alive: boolean,
    color: Color3,
    colorIndex: number,
}

-- A single player's data within a state snapshot, serialized for network transit.
-- Vector3s are broken into components to keep the payload small.
export type PlayerSnapshot = {
    userId: number,
    posX: number,
    posZ: number,
    dirX: number,
    dirZ: number,
    alive: boolean,
    colorIndex: number,
    trail: { TrailSegment },
}

-- The full game state snapshot broadcast to all clients every tick via UnreliableRemoteEvent.
export type GameStateSnapshot = {
    tick: number,
    players: { PlayerSnapshot },
}

-- Input buffer entry for queued turns (client-side grid snapping).
export type QueuedTurn = {
    newDirection: Vector3,
    timestamp: number,
}

return nil

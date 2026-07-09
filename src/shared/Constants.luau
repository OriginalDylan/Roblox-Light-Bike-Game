--[[
    Constants.luau
    ==============
    Single source of truth for all tunable game parameters.
    Every module requires this instead of hardcoding values.
]]

return {
    -- Bike physics
    BIKE_SPEED       = 60,                 -- studs/sec; fast but playable
    BIKE_SIZE        = Vector3.new(2, 1, 4),
    TURN_ANGLE       = 90,                 -- 90-degree grid turns

    -- Grid
    GRID_SIZE        = 2,                  -- studs per grid cell (for grid snapping)
    ARENA_SIZE       = 512,                -- arena bounds in studs (half-extent = 256)

    -- Server tick
    TICK_RATE        = 30,                 -- server ticks per second
    TICK_INTERVAL    = 1 / 30,             -- seconds per tick (1 / TICK_RATE)

    -- Trail visuals
    TRAIL_HEIGHT     = 3,
    TRAIL_WIDTH      = 0.5,
    TRAIL_FADE_TIME  = 10,                 -- seconds before a trail deletes itself

    -- Anti-cheat
    MAX_TURN_RATE    = 8,                  -- max turns/sec per player

    -- Interpolation
    INTERP_DELAY     = 0.1,                -- 100ms render-in-the-past for enemy bikes

    -- Player colors (palette cycles by player index)
    COLORS = {
        Color3.fromRGB(0, 255, 255),       -- Cyan (Player 1)
        Color3.fromRGB(255, 128, 0),       -- Orange (Player 2)
        Color3.fromRGB(255, 0, 255),       -- Magenta (Player 3)
        Color3.fromRGB(0, 255, 0),         -- Green (Player 4)
    },

    -- Fixed direction vectors (90-degree movement only)
    DIRECTIONS = {
        EAST  = Vector3.new(1, 0, 0),
        WEST  = Vector3.new(-1, 0, 0),
        SOUTH = Vector3.new(0, 0, 1),
        NORTH = Vector3.new(0, 0, -1),
    },

    -- Spawn Y coordinate (bike height above floor)
    SPAWN_Y          = 1,                  -- bike center Y position
}

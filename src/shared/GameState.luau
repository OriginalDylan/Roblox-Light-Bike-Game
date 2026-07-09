--[[
    GameState.luau
    ==============
    Shared helper functions for trail segment math.
    Used by both the server (CollisionService) and the client (EnemyInterpolation).

    Because all movement is locked to 90-degree turns, every trail segment is either
    horizontal (along the X-axis, Z is constant) or vertical (along the Z-axis, X is constant).
    This makes intersection checks incredibly cheap - pure arithmetic, no raycasts.
]]

local Constants = require(script.Parent.Constants)

local GameState = {}

------------------------------------------------------------
-- Segment classification
------------------------------------------------------------

-- Returns true if a segment runs along the X-axis (horizontal).
-- A horizontal segment has constant Z; startX and endX differ.
function GameState.isHorizontal(seg)
    return seg.startZ == seg.endZ
end

-- Returns true if a segment runs along the Z-axis (vertical).
-- A vertical segment has constant X; startZ and endZ differ.
function GameState.isVertical(seg)
    return seg.startX == seg.endX
end

------------------------------------------------------------
-- Segment intersection (axis-aligned only)
------------------------------------------------------------

--[[
    segmentsIntersect(segA, segB)
    Returns true if two axis-aligned segments cross each other.

    Cases:
    1. Perpendicular: one horizontal, one vertical.
       They intersect if the vertical segment's X is within the horizontal segment's X range
       AND the horizontal segment's Z is within the vertical segment's Z range.

    2. Parallel (both horizontal or both vertical):
       They intersect (overlap) if they share the same constant coordinate
       AND their ranges on the other axis overlap.
]]
function GameState.segmentsIntersect(segA, segB)
    local aHorizontal = GameState.isHorizontal(segA)
    local bHorizontal = GameState.isHorizontal(segB)

    if aHorizontal ~= bHorizontal then
        -- Perpendicular case: one is horizontal, one is vertical
        local hSeg, vSeg
        if aHorizontal then
            hSeg = segA
            vSeg = segB
        else
            hSeg = segB
            vSeg = segA
        end

        -- hSeg: Z is constant, X ranges from startX to endX
        -- vSeg: X is constant, Z ranges from startZ to endZ
        local hMinX = math.min(hSeg.startX, hSeg.endX)
        local hMaxX = math.max(hSeg.startX, hSeg.endX)
        local vMinZ = math.min(vSeg.startZ, vSeg.endZ)
        local vMaxZ = math.max(vSeg.startZ, vSeg.endZ)

        -- Intersection: vSeg.X is within [hMinX, hMaxX] AND hSeg.Z is within [vMinZ, vMaxZ]
        return vSeg.startX >= hMinX and vSeg.startX <= hMaxX
           and hSeg.startZ >= vMinZ and hSeg.startZ <= vMaxZ
    else
        -- Parallel case: both on the same axis
        if aHorizontal then
            -- Both horizontal: Z must match, X ranges must overlap
            if segA.startZ ~= segB.startZ then
                return false
            end
            local aMinX = math.min(segA.startX, segA.endX)
            local aMaxX = math.max(segA.startX, segA.endX)
            local bMinX = math.min(segB.startX, segB.endX)
            local bMaxX = math.max(segB.startX, segB.endX)
            return aMinX <= bMaxX and bMinX <= aMaxX
        else
            -- Both vertical: X must match, Z ranges must overlap
            if segA.startX ~= segB.startX then
                return false
            end
            local aMinZ = math.min(segA.startZ, segA.endZ)
            local aMaxZ = math.max(segA.startZ, segA.endZ)
            local bMinZ = math.min(segB.startZ, segB.endZ)
            local bMaxZ = math.max(segB.startZ, segB.endZ)
            return aMinZ <= bMaxZ and bMinZ <= aMaxZ
        end
    end
end

------------------------------------------------------------
-- Point-vs-segment collision
------------------------------------------------------------

--[[
    pointHitsSegment(x, z, seg)
    Returns true if the point (x, z) lies on the segment.
    Used for checking if a bike's current position crosses a trail.
]]
function GameState.pointHitsSegment(x, z, seg)
    if GameState.isHorizontal(seg) then
        -- Horizontal segment: Z must match, X must be within range
        if z ~= seg.startZ then return false end
        local minX = math.min(seg.startX, seg.endX)
        local maxX = math.max(seg.startX, seg.endX)
        return x >= minX and x <= maxX
    else
        -- Vertical segment: X must match, Z must be within range
        if x ~= seg.startX then return false end
        local minZ = math.min(seg.startZ, seg.endZ)
        local maxZ = math.max(seg.startZ, seg.endZ)
        return z >= minZ and z <= maxZ
    end
end

------------------------------------------------------------
-- Arena bounds
------------------------------------------------------------

--[[
    isInsideArena(x, z)
    Returns true if the coordinate is within the arena bounds.
]]
function GameState.isInsideArena(x, z)
    local half = Constants.ARENA_SIZE / 2
    return x >= -half and x <= half and z >= -half and z <= half
end

------------------------------------------------------------
-- Segment creation helper
------------------------------------------------------------

--[[
    makeSegment(startX, startZ, endX, endZ)
    Creates a TrailSegment table from two coordinate pairs.
]]
function GameState.makeSegment(startX, startZ, endX, endZ)
    return {
        startX = startX,
        startZ = startZ,
        endX = endX,
        endZ = endZ,
    }
end

------------------------------------------------------------
-- Active segment (the growing one from last turn to current pos)
------------------------------------------------------------

--[[
    getActiveSegment(lastTurnPos, currentPos)
    Returns a TrailSegment representing the segment from the last turn point
    to the bike's current position. This is the "live" segment that hasn't
    been finalized yet.
]]
function GameState.getActiveSegment(lastTurnPos, currentPos)
    return GameState.makeSegment(
        lastTurnPos.X, lastTurnPos.Z,
        currentPos.X, currentPos.Z
    )
end

return GameState

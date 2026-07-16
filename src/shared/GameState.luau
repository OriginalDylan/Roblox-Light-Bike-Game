local Constants = require(script.Parent.Constants)

local GameState = {}

function GameState.isHorizontal(seg)
    return seg.startZ == seg.endZ
end

function GameState.isVertical(seg)
    return seg.startX == seg.endX
end

function GameState.segmentsIntersect(segA, segB)
    local aHorizontal = GameState.isHorizontal(segA)
    local bHorizontal = GameState.isHorizontal(segB)

    if aHorizontal ~= bHorizontal then
        local hSeg, vSeg
        if aHorizontal then
            hSeg = segA
            vSeg = segB
        else
            hSeg = segB
            vSeg = segA
        end

        local hMinX = math.min(hSeg.startX, hSeg.endX)
        local hMaxX = math.max(hSeg.startX, hSeg.endX)
        local vMinZ = math.min(vSeg.startZ, vSeg.endZ)
        local vMaxZ = math.max(vSeg.startZ, vSeg.endZ)

        return vSeg.startX >= hMinX and vSeg.startX <= hMaxX
           and hSeg.startZ >= vMinZ and hSeg.startZ <= vMaxZ
    else
        if aHorizontal then
            if segA.startZ ~= segB.startZ then
                return false
            end
            local aMinX = math.min(segA.startX, segA.endX)
            local aMaxX = math.max(segA.startX, segA.endX)
            local bMinX = math.min(segB.startX, segB.endX)
            local bMaxX = math.max(segB.startX, segB.endX)
            return aMinX <= bMaxX and bMinX <= aMaxX
        else
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

function GameState.pointHitsSegment(x, z, seg)
    if GameState.isHorizontal(seg) then
        if z ~= seg.startZ then return false end
        local minX = math.min(seg.startX, seg.endX)
        local maxX = math.max(seg.startX, seg.endX)
        return x >= minX and x <= maxX
    else
        if x ~= seg.startX then return false end
        local minZ = math.min(seg.startZ, seg.endZ)
        local maxZ = math.max(seg.startZ, seg.endZ)
        return z >= minZ and z <= maxZ
    end
end

function GameState.isInsideArena(x, z)
    local half = Constants.ARENA_SIZE / 2
    return x >= -half and x <= half and z >= -half and z <= half
end

function GameState.makeSegment(startX, startZ, endX, endZ)
    return {
        startX = startX,
        startZ = startZ,
        endX = endX,
        endZ = endZ,
    }
end

function GameState.getActiveSegment(lastTurnPos, currentPos)
    return GameState.makeSegment(
        lastTurnPos.X, lastTurnPos.Z,
        currentPos.X, currentPos.Z
    )
end

return GameState
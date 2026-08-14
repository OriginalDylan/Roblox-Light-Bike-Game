--[[
    LocalTrailRenderer.luau
    ========================
    Client-side visual trail for the LOCAL player's bike only.

    NOTE: This is one of TWO parallel trail systems:
      1. LocalTrailRenderer (this file)    -> client-only decorative parts for your own bike
      2. TrailManager (server/TrailManager) -> server-authoritative parts + collision math

    They MUST stay in sync. Any change to how trails are created/destroyed may
    need to be applied in BOTH files (e.g. on death/reset). Server collision uses
    GameState trail segments, NOT these parts, so leftover local parts are purely
    cosmetic -- but they will linger in Workspace if not tracked and cleared.

    RULE: every part created here must be tracked and destroyed in clear(), or a
    death/respawn will leave orphaned trail parts that the player can drive through.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local LocalTrailRenderer = {}

local activePart = nil
local segments: { Part } = {} -- finalized (turned) trail parts, tracked for cleanup
local color = Constants.COLORS[1]

local function makePart()
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Material = Constants.TRAIL_MATERIAL
    p.Color = color
    p.Parent = Workspace
    return p
end

function LocalTrailRenderer.init(initialPos: Vector3, initialDir: Vector3)
    if activePart then
        activePart:Destroy()
    end
    activePart = makePart()
    local endPos = initialPos + initialDir * Constants.TRAIL_WIDTH
    local mid = (initialPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - initialPos.X
    local dz = endPos.Z - initialPos.Z
    activePart.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, Constants.TRAIL_WIDTH)
    activePart.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
end

function LocalTrailRenderer.update(currentPos: Vector3, lastTurnPos: Vector3)
    if not activePart then return end
    local startPos = lastTurnPos
    local endPos = currentPos
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
    activePart.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    activePart.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
end

-- A turn finalizes the previous segment into a permanent part.
-- IMPORTANT: keep it in `segments` so clear() can destroy it later.
function LocalTrailRenderer.finalizeSegment(startPos: Vector3, endPos: Vector3)
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
    local seg = makePart()
    seg.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    seg.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
    table.insert(segments, seg)
end

function LocalTrailRenderer.setColor(c: Color3)
    color = c
    if activePart then
        activePart.Color = c
    end
end

-- Remove ALL local trail parts (active + every finalized segment).
-- Called on death and on respawn. If this is ever reduced to only removing
-- activePart, old finalized segments will be left visible (no collision),
-- so keep destroying every entry in `segments`.
function LocalTrailRenderer.clear()
    if activePart then
        activePart:Destroy()
        activePart = nil
    end
    for _, seg in segments do
        seg:Destroy()
    end
    table.clear(segments)
end

return LocalTrailRenderer
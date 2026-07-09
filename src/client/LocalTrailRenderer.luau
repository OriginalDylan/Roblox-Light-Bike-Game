--[[
    LocalTrailRenderer.luau
    =======================
    Draws the player's own trail instantly on the client.
    Spawns Neon parts from last turn point to current bike position.
    Local trails get cleaned up when the server authoritatively covers the same segment.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local LocalTrailRenderer = {}

-- Trail parts created locally (to be cleaned up by server authority later)
local localTrailSegments: { Part } = {}
local lastTrailPosition: Vector3? = nil

local function createTrailPart()
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = Constants.COLORS[1]
    part.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, Constants.TRAIL_WIDTH)
    part.CFrame = CFrame.new(0, -1000, 0)
    part.Parent = Workspace
    return part
end

function LocalTrailRenderer.update(currentPosition: Vector3, lastTurnPosition: Vector3, currentDirection: Vector3, color: Color3?)
    local usedColor = color or Constants.COLORS[1]

    if not lastTrailPosition or lastTrailPosition ~= lastTurnPosition then
        lastTrailPosition = lastTurnPosition
        localTrailSegments = {}
    end

    if not lastTrailPosition then
        lastTrailPosition = lastTurnPosition
        return
    end

    while #localTrailSegments > 100 do
        local old = table.remove(localTrailSegments, 1)
        if old then old:Destroy() end
    end

    local seg = createTrailPart()
    seg.Color = usedColor

    local startPos = lastTurnPosition
    local endPos = currentPosition
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
    seg.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    seg.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))

    table.insert(localTrailSegments, seg)
end

function LocalTrailRenderer.clear()
    for _, seg in localTrailSegments do
        seg:Destroy()
    end
    localTrailSegments = {}
    lastTrailPosition = nil
end

return LocalTrailRenderer

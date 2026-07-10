local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local LocalTrailRenderer = {}
local activePart = nil
local color = Constants.COLORS[1]

local function makePart()
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.Neon
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

function LocalTrailRenderer.finalizeSegment(startPos: Vector3, endPos: Vector3)
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
    local seg = makePart()
    seg.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    seg.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
end

function LocalTrailRenderer.setColor(c: Color3)
    color = c
    if activePart then
        activePart.Color = c
    end
end

function LocalTrailRenderer.clear()
    if activePart then
        activePart:Destroy()
        activePart = nil
    end
end

return LocalTrailRenderer
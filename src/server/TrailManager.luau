--[[
    TrailManager.luau
    =================
    Server-side decorative trail part management.
    - Creates Anchored+Neon trail parts for each finalized segment
    - Stretches the active (growing) segment each tick
    - Fades and destroys segments after TRAIL_FADE_TIME
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)

local TrailManager = {}

local trailData = {} -- player -> {segments: {Part}, activePart: Part, lastLength: number}

function TrailManager.init()
    print("[TrailManager] Initialized")
end

function TrailManager.addPlayer(player, color)
    trailData[player] = {
        segments = {},
        activePart = nil,
        lastLength = 0,
        color = color,
    }
end

function TrailManager.removePlayer(player)
    local data = trailData[player]
    if data then
        for _, part in data.segments do
            part:Destroy()
        end
        if data.activePart then
            data.activePart:Destroy()
        end
        trailData[player] = nil
    end
end

function TrailManager.onTurn(player, turnPos, lastTurnPos)
    local data = trailData[player]
    if not data then return end

    -- Finalize the active segment: replace the growing part with a permanent one
    if data.activePart then
        data.activePart:Destroy()
        data.activePart = nil
    end

    local startPos = lastTurnPos
    local endPos = turnPos
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)

    local seg = Instance.new("Part")
    seg.Anchored = true
    seg.CanCollide = false
    seg.Material = Enum.Material.Neon
    seg.Color = data.color
    seg.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    seg.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
    seg.Parent = Workspace

    table.insert(data.segments, seg)

    task.delay(Constants.TRAIL_FADE_TIME, function()
        if seg and seg.Parent then
            local tween = game:GetService("TweenService"):Create(seg, TweenInfo.new(1), { Transparency = 1 })
            tween:Play()
            tween.Completed:Connect(function()
                seg:Destroy()
            end)
        end
    end)
end

function TrailManager.updateActiveSegment(player, currentPos, lastTurnPos)
    local data = trailData[player]
    if not data then return end

    if not data.activePart then
        data.activePart = Instance.new("Part")
        data.activePart.Anchored = true
        data.activePart.CanCollide = false
        data.activePart.Material = Enum.Material.Neon
        data.activePart.Color = data.color
        data.activePart.Parent = Workspace
    end

    local startPos = lastTurnPos
    local endPos = currentPos
    local mid = (startPos + endPos) / 2
    mid = Vector3.new(mid.X, Constants.TRAIL_HEIGHT / 2 - 0.5, mid.Z)
    local dx = endPos.X - startPos.X
    local dz = endPos.Z - startPos.Z
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)

    data.activePart.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    data.activePart.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
end

return TrailManager

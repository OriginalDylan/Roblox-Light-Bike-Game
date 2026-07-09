--[[
    EnemyInterpolation.luau
    =======================
    Listens for StateUpdate (UnreliableRemoteEvent) from the server
    and renders other players' bikes / trails.
    Phase C: Basic direct positioning (no Lerp yet).
    Phase E: Adds snapshot buffer + Lerp for smooth movement.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateUpdate = ReplicatedStorage:WaitForChild("StateUpdate")

local Constants = require(ReplicatedStorage.Shared.Constants)

local EnemyInterpolation = {}

local enemyBikes = {} -- userId -> {bike: Part, trails: {Part}}

function EnemyInterpolation.init()
    StateUpdate.OnClientEvent:Connect(function(snapshot)
        renderSnapshot(snapshot)
    end)
    print("[EnemyInterpolation] Initialized")
end

function renderSnapshot(snapshot)
    for _, ps in snapshot.p do
        if ps.u == Players.LocalPlayer.UserId then
            continue
        end

        local data = enemyBikes[ps.u]
        if not data then
            local bike = Instance.new("Part")
            bike.Anchored = true
            bike.CanCollide = false
            bike.Material = Enum.Material.Neon
            bike.Color = Constants.COLORS[ps.c] or Constants.COLORS[1]
            bike.Size = Constants.BIKE_SIZE
            bike.Parent = Workspace

            data = { bike = bike, trails = {} }
            enemyBikes[ps.u] = data
        end

        local pos = Vector3.new(ps.x, Constants.SPAWN_Y, ps.z)
        local dir = Vector3.new(ps.dx, 0, ps.dz)

        data.bike.CFrame = CFrame.lookAt(pos, pos + dir)

        renderEnemyTrails(data, ps.h, Constants.COLORS[ps.c] or Constants.COLORS[1])
    end

    for userId, data in enemyBikes do
        local found = false
        for _, ps in snapshot.p do
            if ps.u == userId then
                found = true
                break
            end
        end
        if not found then
            data.bike:Destroy()
            for _, t in data.trails do
                t:Destroy()
            end
            enemyBikes[userId] = nil
        end
    end
end

function renderEnemyTrails(data, trailHistory, color)
    for i = 1, math.min(#trailHistory, #data.trails) do
        local part = data.trails[i]
        local seg = trailHistory[i]
        local midX = (seg.startX + seg.endX) / 2
        local midZ = (seg.startZ + seg.endZ) / 2
        local dx = seg.endX - seg.startX
        local dz = seg.endZ - seg.startZ
        local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
        part.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
        part.CFrame = CFrame.lookAt(
            Vector3.new(midX, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ),
            Vector3.new(midX + dx, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ + dz)
        )
    end

    for i = #data.trails + 1, #trailHistory do
        local seg = trailHistory[i]
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = color
        part.Parent = Workspace
        table.insert(data.trails, part)

        local midX = (seg.startX + seg.endX) / 2
        local midZ = (seg.startZ + seg.endZ) / 2
        local dx = seg.endX - seg.startX
        local dz = seg.endZ - seg.startZ
        local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
        part.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
        part.CFrame = CFrame.lookAt(
            Vector3.new(midX, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ),
            Vector3.new(midX + dx, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ + dz)
        )
    end

    while #data.trails > #trailHistory do
        local part = table.remove(data.trails)
        part:Destroy()
    end
end

return EnemyInterpolation

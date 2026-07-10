--[[
    EnemyInterpolation.luau
    =======================
    Listens for StateUpdate (UnreliableRemoteEvent) from the server
    and renders other players' bikes and trails.
    Phase C: Basic direct positioning (no Lerp yet).
    Phase E: Adds snapshot buffer and Lerp for smooth movement.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateUpdate = ReplicatedStorage:WaitForChild("StateUpdate")
local ReplicateTurn = ReplicatedStorage:WaitForChild("ReplicateTurn")

local Constants = require(ReplicatedStorage.Shared.Constants)

local EnemyInterpolation = {}

local enemyData = {}

function EnemyInterpolation.init()
    StateUpdate.OnClientEvent:Connect(function(snapshot)
        renderSnapshot(snapshot)
    end)

    ReplicateTurn.OnClientEvent:Connect(function(userId, segment)
        onReplicateTurn(userId, segment)
    end)

    print("[EnemyInterpolation] Initialized")
end

function ensureEnemyData(userId, colorIndex)
    local data = enemyData[userId]
    if data then return data end

    local bike = Instance.new("Part")
    bike.Anchored = true
    bike.CanCollide = false
    bike.Material = Enum.Material.Neon
    bike.Color = Constants.COLORS[colorIndex] or Constants.COLORS[1]
    bike.Size = Constants.BIKE_SIZE
    bike.Parent = Workspace

    local activeTrail = Instance.new("Part")
    activeTrail.Anchored = true
    activeTrail.CanCollide = false
    activeTrail.Material = Enum.Material.Neon
    activeTrail.Color = Constants.COLORS[colorIndex] or Constants.COLORS[1]
    activeTrail.Parent = Workspace

    data = {
        bike = bike,
        trails = {},
        activeTrail = activeTrail,
    }
    enemyData[userId] = data
    return data
end

function destroyEnemyData(userId)
    local data = enemyData[userId]
    if not data then return end
    data.bike:Destroy()
    data.activeTrail:Destroy()
    for _, t in data.trails do
        t:Destroy()
    end
    enemyData[userId] = nil
end

function onReplicateTurn(userId, segment)
    if userId == Players.LocalPlayer.UserId then return end
    local data = enemyData[userId]
    if not data then return end

    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = data.bike.Color
    part.Parent = Workspace

    local midX = (segment.sx + segment.ex) / 2
    local midZ = (segment.sz + segment.ez) / 2
    local dx = segment.ex - segment.sx
    local dz = segment.ez - segment.sz
    local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
    part.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
    part.CFrame = CFrame.lookAt(
        Vector3.new(midX, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ),
        Vector3.new(midX + dx, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ + dz)
    )
    table.insert(data.trails, part)
end

function renderSnapshot(snapshot)
    for _, ps in snapshot.p do
        if ps.u == Players.LocalPlayer.UserId then
            continue
        end

        local data = ensureEnemyData(ps.u, ps.c)

        if not ps.a then
            data.bike.Transparency = 1
            data.activeTrail.Transparency = 1
            continue
        end

        data.bike.Transparency = 0
        local pos = Vector3.new(ps.x, Constants.SPAWN_Y, ps.z)
        local dir = Vector3.new(ps.dx, 0, ps.dz)
        data.bike.CFrame = CFrame.lookAt(pos, pos + dir)

        data.activeTrail.Transparency = 0
        if ps.lx ~= nil and ps.lz ~= nil then
            local midX = (ps.lx + ps.x) / 2
            local midZ = (ps.lz + ps.z) / 2
            local dx = ps.x - ps.lx
            local dz = ps.z - ps.lz
            local length = math.max(math.abs(dx), math.abs(dz), Constants.TRAIL_WIDTH)
            data.activeTrail.Size = Vector3.new(Constants.TRAIL_WIDTH, Constants.TRAIL_HEIGHT, length)
            data.activeTrail.CFrame = CFrame.lookAt(
                Vector3.new(midX, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ),
                Vector3.new(midX + dx, Constants.TRAIL_HEIGHT / 2 - 0.5, midZ + dz)
            )
        end
    end

    for userId, data in enemyData do
        local found = false
        for _, ps in snapshot.p do
            if ps.u == userId then
                found = true
                break
            end
        end
        if not found then
            destroyEnemyData(userId)
        end
    end
end

return EnemyInterpolation
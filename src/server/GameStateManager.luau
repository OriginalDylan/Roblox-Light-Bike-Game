local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateUpdate = ReplicatedStorage:WaitForChild("StateUpdate")
local ReplicateTurn = ReplicatedStorage:WaitForChild("ReplicateTurn")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)
local TrailManager = require(script.Parent.TrailManager)
local CollisionService = require(script.Parent.CollisionService)
local MatchManager = require(script.Parent.MatchManager)

local GameStateManager = {}

local playerStates = {}
local tickAccumulator = 0
local tickNumber = 0

function GameStateManager.getPlayerStates()
    return playerStates
end

function GameStateManager.init()
    Players.PlayerAdded:Connect(function(player)
        createPlayerState(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        removePlayerState(player)
    end)
    for _, player in Players:GetPlayers() do
        createPlayerState(player)
    end

    RunService.Heartbeat:Connect(function(dt)
        tickAccumulator = tickAccumulator + dt
        while tickAccumulator >= Constants.TICK_INTERVAL do
            tickAccumulator = tickAccumulator - Constants.TICK_INTERVAL
            serverTick(Constants.TICK_INTERVAL)
        end
    end)

    print("[GameStateManager] Initialized")
end

function createPlayerState(player)
    local color = Constants.COLORS[3]
    local spawnPos = Vector3.new(0, Constants.SPAWN_Y, 0)

    local bike = Instance.new("Part")
    bike.Name = player.Name .. "Bike"
    bike.Anchored = true
    bike.CanCollide = false
    bike.Material = Constants.BIKE_MATERIAL
    bike.Color = color
    bike.Size = Constants.BIKE_SIZE
    bike.CFrame = CFrame.lookAt(spawnPos, spawnPos + Constants.DIRECTIONS.NORTH)
    bike.Parent = Workspace

    local state = {
        player = player,
        bikePart = bike,
        direction = Constants.DIRECTIONS.NORTH,
        position = spawnPos,
        lastTurnPosition = spawnPos,
        lastTurnTime = os.clock(),
        trailHistory = {},
        alive = true,
        color = color,
        colorIndex = 3,
    }
    playerStates[player] = state
    TrailManager.addPlayer(player, color)
    print("[GameStateManager] Player added:", player.Name)
end

function removePlayerState(player)
    local state = playerStates[player]
    if state then
        if state.bikePart then
            state.bikePart:Destroy()
        end
        TrailManager.removePlayer(player)
        playerStates[player] = nil
        print("[GameStateManager] Player removed:", player.Name)
    end
end

function serverTick(dt)
    tickNumber = tickNumber + 1
    for _, state in playerStates do
        if state.alive and not state.isAI then
            state.position = state.position + state.direction * Constants.BIKE_SPEED * dt
            if state.bikePart then
                state.bikePart.CFrame = CFrame.lookAt(state.position, state.position + state.direction)
            end
            TrailManager.updateActiveSegment(state.player, state.position, state.lastTurnPosition)
        end
    end

    local dead = CollisionService.checkAll(playerStates)
    for player, _ in dead do
        local state = playerStates[player]
        if not state or not state.alive then continue end
        state.alive = false
        state.trailHistory = {}
        if state.bikePart then
            state.bikePart:Destroy()
            state.bikePart = nil
        end
        TrailManager.onDeath(player, state.position, state.lastTurnPosition)
        MatchManager.killBike(player)
    end
    broadcastState()
end

function broadcastState()
    local snapshot = { t = tickNumber, p = {} }
    for _, state in playerStates do
        local ps = {
            u = state.player.UserId,
            x = state.position.X,
            z = state.position.Z,
            dx = state.direction.X,
            dz = state.direction.Z,
            a = state.alive,
            c = state.colorIndex,
            lx = state.lastTurnPosition.X,
            lz = state.lastTurnPosition.Z,
        }
        snapshot.p[#snapshot.p + 1] = ps
    end
    StateUpdate:FireAllClients(snapshot)
end

function GameStateManager.applyTurn(player, turnPos, newDir)
    local state = playerStates[player]
    if not state or not state.alive then return end

    local seg = GameStateHelpers.makeSegment(
        state.lastTurnPosition.X, state.lastTurnPosition.Z,
        turnPos.X, turnPos.Z
    )
    table.insert(state.trailHistory, seg)
    ReplicateTurn:FireAllClients(player.UserId, seg)

    TrailManager.onTurn(player, turnPos, state.lastTurnPosition)
    state.lastTurnPosition = turnPos
    state.position = turnPos
    state.direction = newDir
    state.lastTurnTime = os.clock()
end

return GameStateManager

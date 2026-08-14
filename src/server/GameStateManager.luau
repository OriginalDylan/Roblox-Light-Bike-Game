local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateUpdate = ReplicatedStorage:WaitForChild("StateUpdate")
local ReplicateTurn = ReplicatedStorage:WaitForChild("ReplicateTurn")
local RestartEvent = ReplicatedStorage:WaitForChild("RestartEvent")
local SpawnSync = ReplicatedStorage:WaitForChild("SpawnSync")
local VictoryEvent = ReplicatedStorage:WaitForChild("VictoryEvent")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)
local TrailManager = require(script.Parent.TrailManager)
local CollisionService = require(script.Parent.CollisionService)
local MatchManager = require(script.Parent.MatchManager)

local GameStateManager = {}

local playerStates = {}
local tickAccumulator = 0
local tickNumber = 0
local aiBots = {}
local aiBotModule = nil
local matchOver = false

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

    -- Spawn AI bots (lazy require to avoid circular dep)
    aiBotModule = require(script.Parent.AIBot)
    spawnAIBots(aiBotModule)

    RestartEvent.OnServerEvent:Connect(function()
        GameStateManager.resetGame()
    end)

    SpawnSync.OnServerEvent:Connect(function(player)
        resyncPlayerToSpawn(player)
    end)

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

    -- NOTE: no server bike part for human players. The client renders its own
    -- bike locally (LightbikeController) and other clients render it via
    -- EnemyInterpolation from the broadcast snapshot. A server part here caused
    -- double-rendering and the "phantom bike ahead" on spawn.
    local state = {
        player = player,
        bikePart = nil,
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

function spawnAIBots(AIBot)
    -- Always spawn the configured number of bots, independent of current player
    -- count, so the field is consistent on initial boot and after Play Again.
    local botCount = Constants.AI_BOT_COUNT

    local spawnConfigs = {
        { pos = Vector3.new(-200, Constants.SPAWN_Y, -200), dir = Constants.DIRECTIONS.EAST,  color = 2 },
        { pos = Vector3.new(200, Constants.SPAWN_Y, 200),   dir = Constants.DIRECTIONS.WEST,  color = 5 },
        { pos = Vector3.new(-200, Constants.SPAWN_Y, 200),  dir = Constants.DIRECTIONS.SOUTH, color = 4 },
    }

    local difficulties = { "EASY", "MEDIUM", "HARD" }

    for i = 1, math.min(botCount, #spawnConfigs) do
        local cfg = spawnConfigs[i]
        local diff = difficulties[i] or "EASY"
        local bot = AIBot.new(diff, cfg.pos, cfg.dir, cfg.color)
        local fakePlayer = bot:spawn()
        table.insert(aiBots, bot)
    end

    print("[GameStateManager] Spawned " .. #aiBots .. " AI bots")
end


function resyncPlayerToSpawn(player)
    local state = playerStates[player]
    if not state then return end

    -- Snap the server-side authority back to spawn so it matches the client
    -- predicted position (the client fires SpawnSync as soon as its bike spawns,
    -- before it has moved). Without this the server gets a head start and becomes
    -- the "phantom" bike ahead that killed players at the wall before their own bike.
    state.position = Vector3.new(0, Constants.SPAWN_Y, 0)
    state.lastTurnPosition = state.position
    state.direction = Constants.DIRECTIONS.NORTH
    state.lastTurnTime = os.clock()
    state.trailHistory = {}
    state.alive = true
    TrailManager.removePlayer(player)
    TrailManager.addPlayer(player, state.color)
    print("[GameStateManager] Player resynced to spawn")
end

-- Only fires once per match: the last surviving human wins when all other
-- humans and every AI bot are dead.
function checkVictory()
    if matchOver then return end

    local aliveHuman = nil
    local humanCount = 0
    for plr, state in playerStates do
        if typeof(plr) == "Instance" and state.alive then
            humanCount += 1
            aliveHuman = plr
        end
    end

    local aliveBots = 0
    for _, bot in aiBots do
        if bot.state and bot.state.alive then
            aliveBots += 1
        end
    end

    if humanCount == 1 and aliveBots == 0 then
        matchOver = true
        print("[GameStateManager] Victory for " .. aliveHuman.Name)
        VictoryEvent:FireClient(aliveHuman)
    end
end
function GameStateManager.resetGame()
    matchOver = false

    -- Clean up and remove AI bots
    for _, bot in ipairs(aiBots) do
        bot:cleanup()
    end
    aiBots = {}

    -- Reset all real human players
    local humanPlayers = {}
    for plr in playerStates do
        if typeof(plr) == "Instance" then
            table.insert(humanPlayers, plr)
        end
    end
    for _, plr in ipairs(humanPlayers) do
        removePlayerState(plr)
        createPlayerState(plr)
        if plr.Parent then
            plr:LoadCharacter()
        end
    end

    -- Respawn AI bots fresh
    if aiBotModule then
        spawnAIBots(aiBotModule)
    end

    print("[GameStateManager] Game reset by Play Again")
end

function serverTick(dt)
    tickNumber = tickNumber + 1

    -- 1. Move human players
    for _, state in playerStates do
        if state.alive and not state.isAI then
            state.position = state.position + state.direction * Constants.BIKE_SPEED * dt
            if state.bikePart then
                state.bikePart.CFrame = CFrame.lookAt(state.position, state.position + state.direction)
            end
            TrailManager.updateActiveSegment(state.player, state.position, state.lastTurnPosition)
        end
    end

    -- 2. Tick AI bots (they move + think + possibly turn)
    for _, bot in aiBots do
        if bot.state and bot.state.alive then
            bot:tick(dt)
        end
    end

    -- 3. Collision check (after ALL movement this tick)
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

    -- 4. Victory check (after all deaths processed)
    checkVictory()

    -- 5. Broadcast state
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
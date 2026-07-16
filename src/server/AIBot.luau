local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateManager = require(script.Parent.GameStateManager)
local TrailManager = require(script.Parent.TrailManager)

local AIBot = {}

function AIBot.init()
    local fakePlayer = {
        UserId = 9999,
        Name = "AI_Bot",
    }

    local aiSpeed = Constants.AI_SPEED
    local colorIndex = 2
    local color = Constants.COLORS[colorIndex]
    local spawnPos = Vector3.new(-200, Constants.SPAWN_Y, -200)

    local bike = Instance.new("Part")
    bike.Name = "AIBot_Bike"
    bike.Anchored = true
    bike.CanCollide = false
    bike.Material = Constants.BIKE_MATERIAL
    bike.Color = color
    bike.Size = Constants.BIKE_SIZE
    bike.CFrame = CFrame.lookAt(spawnPos, spawnPos + Constants.DIRECTIONS.EAST)
    bike.Parent = Workspace

    local state = {
        player = fakePlayer,
        bikePart = bike,
        direction = Constants.DIRECTIONS.EAST,
        position = spawnPos,
        lastTurnPosition = spawnPos,
        lastTurnTime = os.clock(),
        trailHistory = {},
        alive = true,
        color = color,
        colorIndex = colorIndex,
        isAI = true,
    }

    local playerStates = GameStateManager.getPlayerStates()
    playerStates[fakePlayer] = state
    TrailManager.addPlayer(fakePlayer, color)

    local PATH = {
        { dir = Constants.DIRECTIONS.EAST,  dur = 3.0 },
        { dir = Constants.DIRECTIONS.SOUTH, dur = 3.0 },
        { dir = Constants.DIRECTIONS.WEST,  dur = 3.0 },
        { dir = Constants.DIRECTIONS.NORTH, dur = 3.0 },
    }
    local pathIdx = 1
    local pathTimer = 0
    local tickAcc = 0

    RunService.Heartbeat:Connect(function(dt)
        if not state.alive then return end

        tickAcc = tickAcc + dt
        while tickAcc >= Constants.TICK_INTERVAL do
            tickAcc = tickAcc - Constants.TICK_INTERVAL

            state.position = state.position + state.direction * aiSpeed * Constants.TICK_INTERVAL
            if state.bikePart then
                state.bikePart.CFrame = CFrame.lookAt(state.position, state.position + state.direction)
            end
            TrailManager.updateActiveSegment(fakePlayer, state.position, state.lastTurnPosition)

            pathTimer = pathTimer + Constants.TICK_INTERVAL
            local cur = PATH[pathIdx]
            if pathTimer >= cur.dur then
                pathTimer = 0
                pathIdx = pathIdx % #PATH + 1
                local next = PATH[pathIdx]
                GameStateManager.applyTurn(fakePlayer, state.position, next.dir)
            end
        end
    end)

    print("[AIBot] Initialized - spawned at", spawnPos, "speed", aiSpeed)
end

return AIBot

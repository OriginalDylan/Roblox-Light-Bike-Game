--[[
    LightbikeServer.luau
    ====================
    Server-side turn validation and replication.
    - Listens for TurnEvent from clients
    - Ping compensation: validates turn distance is within speed * elapsed * 1.2
    - Rejects invalid turns (cheating, lag exploits)
    - Calls GameStateManager.applyTurn() for valid turns
    - Broadcasts via ReplicateTurn for immediate feedback
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TurnEvent = ReplicatedStorage:WaitForChild("TurnEvent")
local ReplicateTurn = ReplicatedStorage:WaitForChild("ReplicateTurn")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateManager = require(script.Parent.GameStateManager)

local LightbikeServer = {}

function LightbikeServer.init()
    TurnEvent.OnServerEvent:Connect(function(player, turnPos, newDir, timestamp)
        validateAndApplyTurn(player, turnPos, newDir, timestamp)
    end)
    print("[LightbikeServer] Initialized")
end

function validateAndApplyTurn(player, turnPos, newDir, timestamp)
    local states = GameStateManager.getPlayerStates()
    local state = states[player]
    if not state or not state.alive then return end

    -- Validate newDir is perpendicular to current direction (dot product ≈ 0)
    local dot = state.direction.X * newDir.X + state.direction.Z * newDir.Z
    if math.abs(dot) > 0.1 then
        return
    end

    -- Validate newDir is a unit vector on X or Z
    if math.abs(newDir.X) + math.abs(newDir.Z) ~= 1 then
        return
    end

    -- Ping compensation: distance check
    local now = os.clock()
    local elapsed = now - state.lastTurnTime
    local maxDistance = Constants.BIKE_SPEED * math.max(elapsed, 0.016) * 1.2
    local actualDistance = (turnPos - state.lastTurnPosition).Magnitude
    if actualDistance > maxDistance then
        return
    end

    GameStateManager.applyTurn(player, turnPos, newDir)

    ReplicateTurn:FireAllClients(player, turnPos, newDir)
end

return LightbikeServer

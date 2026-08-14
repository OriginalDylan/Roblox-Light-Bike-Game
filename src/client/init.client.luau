--[[
    init.client.luau
    ================
    Client bootstrapper. Requires and initializes all client modules.
    No game logic lives here - only the load order.
]]

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local GameState = require(game.ReplicatedStorage.Shared.GameState)

local LightbikeController = require(script.LightbikeController)

local EnemyInterpolation = require(script.EnemyInterpolation)
local BikeVisuals = require(script.BikeVisuals)
local VictoryUI = require(script.VictoryUI)

local VictoryEvent = game.ReplicatedStorage:WaitForChild("VictoryEvent")

print("[Client] Bootstrapping Tron Lightbike client modules...")
print("[Client] Constants loaded: BIKE_SPEED =", Constants.BIKE_SPEED, "| ARENA_SIZE =", Constants.ARENA_SIZE)
print("[Client] GameState helpers loaded: segmentsIntersect, pointHitsSegment, isInsideArena")

-- When all other riders are dead, this player wins: stop the bike and show the overlay.
VictoryEvent.OnClientEvent:Connect(function()
    LightbikeController.freeze()
    VictoryUI.show()
end)

LightbikeController.init()
EnemyInterpolation.init()

print("[Client] All client modules initialized successfully.")

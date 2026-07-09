--[[
    init.server.luau
    ================
    Server bootstrapper. Requires and initializes all server modules.
    No game logic lives here - only the load order.
]]

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local GameState = require(game.ReplicatedStorage.Shared.GameState)

local LightbikeServer = require(script.LightbikeServer)
local GameStateManager = require(script.GameStateManager)
local TrailManager = require(script.TrailManager)
local CollisionService = require(script.CollisionService)
local MatchManager = require(script.MatchManager)
local AIBot = require(script.AIBot)

print("[Server] Bootstrapping Tron Lightbike server modules...")
print("[Server] Constants loaded: BIKE_SPEED =", Constants.BIKE_SPEED, "| TICK_RATE =", Constants.TICK_RATE)
print("[Server] GameState helpers loaded: segmentsIntersect, pointHitsSegment, isInsideArena")

-- Initialize modules (stubs for now - they just print in Phase A)
TrailManager.init()
GameStateManager.init()
LightbikeServer.init()
CollisionService.init()
MatchManager.init()
AIBot.init()

print("[Server] All server modules initialized successfully.")

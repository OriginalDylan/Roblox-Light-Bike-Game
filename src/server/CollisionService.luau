local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)

local CollisionService = {}

function CollisionService.init()
    print("[CollisionService] Initialized")
end

function CollisionService.checkAll(playerStates)
    local dead = {}
    for player, state in pairs(playerStates) do
        if not state.alive then continue end
        if dead[player] then continue end

        if not GameStateHelpers.isInsideArena(state.position.X, state.position.Z) then
            dead[player] = true
        end

        local active = GameStateHelpers.getActiveSegment(state.lastTurnPosition, state.position)

        for i = 1, #state.trailHistory - 1 do
            if GameStateHelpers.segmentsIntersect(active, state.trailHistory[i]) then
                dead[player] = true
                break
            end
        end

        for otherPlayer, otherState in pairs(playerStates) do
            if otherPlayer == player then continue end

            for _, seg in pairs(otherState.trailHistory) do
                if GameStateHelpers.segmentsIntersect(active, seg) then
                    dead[player] = true
                    break
                end
            end

            if otherState.alive then
                local otherActive = GameStateHelpers.getActiveSegment(otherState.lastTurnPosition, otherState.position)
                local sameAxis = (GameStateHelpers.isHorizontal(active) and GameStateHelpers.isHorizontal(otherActive) and active.startZ == otherActive.startZ)
                    or (GameStateHelpers.isVertical(active) and GameStateHelpers.isVertical(otherActive) and active.startX == otherActive.startX)
                if sameAxis and GameStateHelpers.segmentsIntersect(active, otherActive) then
                    dead[player] = true
                    dead[otherPlayer] = true
                end
            end
        end
    end
    return dead
end

return CollisionService

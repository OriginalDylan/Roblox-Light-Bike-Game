local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)

local CollisionService = {}

function CollisionService.init()
    print("[CollisionService] Initialized")
end

local EPSILON = 0.1

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

        local dx = active.endX - active.startX
        local dz = active.endZ - active.startZ
        local segLen = math.max(math.abs(dx), math.abs(dz))
        local checkActive
        if segLen > EPSILON then
            local ratio = EPSILON / segLen
            checkActive = GameStateHelpers.makeSegment(
                active.startX + dx * ratio,
                active.startZ + dz * ratio,
                active.endX,
                active.endZ
            )
        end

        for otherPlayer, otherState in pairs(playerStates) do
            if otherPlayer == player then continue end

            if checkActive then
                for _, seg in pairs(otherState.trailHistory) do
                    if GameStateHelpers.segmentsIntersect(checkActive, seg) then
                        dead[player] = true
                        break
                    end
                end
            end

            if otherState.alive then
                local otherActive = GameStateHelpers.getActiveSegment(otherState.lastTurnPosition, otherState.position)
                if GameStateHelpers.segmentsIntersect(active, otherActive) then
                    dead[player] = true
                    dead[otherPlayer] = true
                end
            end
        end
    end
    return dead
end

return CollisionService

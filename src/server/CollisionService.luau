local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)

local CollisionService = {}
local diagTick = 0

function CollisionService.init()
    print("[CollisionService] Initialized")
end

function CollisionService.checkAll(playerStates)
    local dead = {}
    diagTick = diagTick + 1
    for player, state in pairs(playerStates) do
        if not state.alive then continue end
        if dead[player] then continue end

        if not GameStateHelpers.isInsideArena(state.position.X, state.position.Z) then
            dead[player] = true
            print("[DIAG] OUT OF BOUNDS:", player.Name)
        end

        local active = GameStateHelpers.getActiveSegment(state.lastTurnPosition, state.position)

        if diagTick % 15 == 0 then
            print("[DIAG] tick", diagTick, "trail:", #state.trailHistory, "active:", active.startX, active.startZ, "->", active.endX, active.endZ)
            for i = 1, #state.trailHistory do
                local s = state.trailHistory[i]
                print("[DIAG]   seg", i, ":", s.startX, s.startZ, "->", s.endX, s.endZ)
            end
        end

        for i = 1, #state.trailHistory - 1 do
            if GameStateHelpers.segmentsIntersect(active, state.trailHistory[i]) then
                dead[player] = true
                print("[DIAG] SELF HIT:", player.Name, "seg", i)
                break
            end
        end

        for otherPlayer, otherState in pairs(playerStates) do
            if otherPlayer == player then continue end

            for _, seg in pairs(otherState.trailHistory) do
                if GameStateHelpers.segmentsIntersect(active, seg) then
                    dead[player] = true
                    print("[DIAG] OTHER TRAIL HIT:", player.Name, "->", otherPlayer.Name)
                    break
                end
            end

            if otherState.alive then
                local otherActive = GameStateHelpers.getActiveSegment(otherState.lastTurnPosition, otherState.position)
                if GameStateHelpers.segmentsIntersect(active, otherActive) then
                    dead[player] = true
                    dead[otherPlayer] = true
                    print("[DIAG] HEAD TO HEAD:", player.Name, "<->", otherPlayer.Name)
                end
            end
        end
    end
    return dead
end

return CollisionService
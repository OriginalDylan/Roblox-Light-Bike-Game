local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)

local CollisionService = {}

function CollisionService.init()
    print("[CollisionService] Initialized")
end

function CollisionService.checkAll(playerStates)
    local dead = {}
    local players = {}
    for player, state in pairs(playerStates) do
        if state.alive then
            table.insert(players, {player = player, state = state})
        end
    end

    for _, p in ipairs(players) do
        local player, state = p.player, p.state
        if not GameStateHelpers.isInsideArena(state.position.X, state.position.Z) then
            print("[COLLISION] " .. player.Name .. " OUT OF BOUNDS at " .. tostring(state.position))
            dead[player] = true
        else
            local active = GameStateHelpers.getActiveSegment(state.lastTurnPosition, state.position)
            for i = 1, #state.trailHistory - 1 do
                if GameStateHelpers.segmentsIntersect(active, state.trailHistory[i]) then
                    print("[COLLISION] " .. player.Name .. " SELF-COLLISION at " .. tostring(state.position))
                    dead[player] = true
                    break
                end
            end
        end
    end

    for i = 1, #players do
        local pi = players[i]
        local playerA, stateA = pi.player, pi.state
        if dead[playerA] then continue end

        local activeA = GameStateHelpers.getActiveSegment(stateA.lastTurnPosition, stateA.position)

        for j = i + 1, #players do
            local pj = players[j]
            local playerB, stateB = pj.player, pj.state
            if dead[playerB] then continue end

            local activeB = GameStateHelpers.getActiveSegment(stateB.lastTurnPosition, stateB.position)

            local aHitBtrail = false
            for _, seg in ipairs(stateB.trailHistory) do
                if GameStateHelpers.segmentsIntersect(activeA, seg) then
                    aHitBtrail = true
                    break
                end
            end

            local bHitAtrail = false
            for _, seg in ipairs(stateA.trailHistory) do
                if GameStateHelpers.segmentsIntersect(activeB, seg) then
                    bHitAtrail = true
                    break
                end
            end

            local activeHit = GameStateHelpers.segmentsIntersect(activeA, activeB)

            if aHitBtrail or activeHit then
                print("[COLLISION] " .. playerA.Name .. " HIT " .. playerB.Name .. " trail")
                dead[playerA] = true
            end
            if bHitAtrail or activeHit then
                print("[COLLISION] " .. playerB.Name .. " HIT " .. playerA.Name .. " trail")
                dead[playerB] = true
            end
        end
    end

    return dead
end

return CollisionService
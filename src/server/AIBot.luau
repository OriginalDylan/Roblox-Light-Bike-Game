local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameStateHelpers = require(ReplicatedStorage.Shared.GameState)
local GameStateManager = require(script.Parent.GameStateManager)
local TrailManager = require(script.Parent.TrailManager)

local AIBot = {}
AIBot.__index = AIBot

local nextBotId = 0

local function rotateLeft(dir)
    return Vector3.new(dir.Z, 0, -dir.X)
end

local function rotateRight(dir)
    return Vector3.new(-dir.Z, 0, dir.X)
end

local function segmentsEqual(a, b)
    return a.startX == b.startX and a.startZ == b.startZ
       and a.endX == b.endX and a.endZ == b.endZ
end

local function getAllTrailSegments(playerStates, excludePlayer)
    local segments = {}
    for player, state in playerStates do
        for _, seg in state.trailHistory do
            table.insert(segments, seg)
        end
        if state.alive and player ~= excludePlayer then
            table.insert(segments, GameStateHelpers.getActiveSegment(state.lastTurnPosition, state.position))
        end
    end
    return segments
end

function AIBot.new(difficulty, spawnPos, initialDir, colorIndex)
    nextBotId = nextBotId + 1
    local self = setmetatable({}, AIBot)
    self.botId = nextBotId
    self.profile = Constants.AI_DIFFICULTY[difficulty] or Constants.AI_DIFFICULTY.EASY
    self.difficulty = difficulty
    self.reactionCounter = 0
    self.ticksSinceFloodFill = 0
    self.tickAcc = 0
    self.spawnPos = spawnPos
    self.initialDir = initialDir
    self.colorIndex = colorIndex
    self.connection = nil
    self.state = nil
    self.cleanedUp = false
    return self
end

function AIBot:start()
    local fakePlayer = {
        UserId = 10000 + self.botId,
        Name = "AI_Bot_" .. self.botId,
    }

    local color = Constants.COLORS[self.colorIndex]
    local spawnPos = self.spawnPos

    local bike = Instance.new("Part")
    bike.Name = "AIBot_" .. self.botId .. "_Bike"
    bike.Anchored = true
    bike.CanCollide = false
    bike.Material = Constants.BIKE_MATERIAL
    bike.Color = color
    bike.Size = Constants.BIKE_SIZE
    bike.CFrame = CFrame.lookAt(spawnPos, spawnPos + self.initialDir)
    bike.Parent = Workspace

    self.state = {
        player = fakePlayer,
        bikePart = bike,
        direction = self.initialDir,
        position = spawnPos,
        lastTurnPosition = spawnPos,
        lastTurnTime = os.clock(),
        trailHistory = {},
        alive = true,
        color = color,
        colorIndex = self.colorIndex,
        isAI = true,
    }

    local playerStates = GameStateManager.getPlayerStates()
    playerStates[fakePlayer] = self.state
    TrailManager.addPlayer(fakePlayer, color)

    self.connection = RunService.Heartbeat:Connect(function(dt)
        self:tick(dt)
    end)

    print("[AIBot] Bot " .. self.botId .. " (" .. self.difficulty .. ") spawned at", spawnPos)
end

function AIBot:tick(dt)
    if self.cleanedUp then return end
    if not self.state then return end
    if not self.state.alive then
        self:cleanup()
        return
    end

    self.tickAcc = self.tickAcc + dt
    while self.tickAcc >= Constants.TICK_INTERVAL do
        self.tickAcc = self.tickAcc - Constants.TICK_INTERVAL

        self.state.position = self.state.position + self.state.direction * Constants.BIKE_SPEED * Constants.TICK_INTERVAL
        if self.state.bikePart then
            self.state.bikePart.CFrame = CFrame.lookAt(self.state.position, self.state.position + self.state.direction)
        end
        TrailManager.updateActiveSegment(self.state.player, self.state.position, self.state.lastTurnPosition)

        self:think()
    end
end

function AIBot:think()
    if self.reactionCounter > 0 then
        self.reactionCounter = self.reactionCounter - 1
        return
    end

    local playerStates = GameStateManager.getPlayerStates()
    local allSegments = getAllTrailSegments(playerStates, self.state.player)

    local directions = {
        { dir = self.state.direction, name = "straight" },
        { dir = rotateLeft(self.state.direction), name = "left" },
        { dir = rotateRight(self.state.direction), name = "right" },
    }

    local safeDirections = {}
    for _, d in directions do
        if self:isDirectionSafe(d.dir, allSegments, self.profile.lookaheadStuds) then
            table.insert(safeDirections, d)
        end
    end

    if #safeDirections == 0 then
        self.reactionCounter = self.profile.reactionDelayTicks
        return
    end

    if #safeDirections == 1 then
        self:executeTurn(safeDirections[1].dir)
        self.reactionCounter = self.profile.reactionDelayTicks
        return
    end

    if math.random() < self.profile.mistakeChance then
        local randomChoice = safeDirections[math.random(#safeDirections)]
        self:executeTurn(randomChoice.dir)
        self.reactionCounter = self.profile.reactionDelayTicks
        return
    end

    local useFloodFill = self.profile.floodFillEnabled
        and (self.ticksSinceFloodFill >= self.profile.floodFillInterval)

    local bestDir = nil
    local bestScore = -math.huge

    for _, d in safeDirections do
        local score = self:scoreDirection(d.dir, allSegments, playerStates, useFloodFill)
        if score > bestScore then
            bestScore = score
            bestDir = d.dir
        end
    end

    if useFloodFill then
        self.ticksSinceFloodFill = 0
    else
        self.ticksSinceFloodFill = self.ticksSinceFloodFill + 1
    end

    if bestDir then
        self:executeTurn(bestDir)
    end

    self.reactionCounter = self.profile.reactionDelayTicks
end

function AIBot:isDirectionSafe(direction, allSegments, lookaheadStuds)
    local pos = self.state.position
    local endX = pos.X + direction.X * lookaheadStuds
    local endZ = pos.Z + direction.Z * lookaheadStuds

    if not GameStateHelpers.isInsideArena(endX, endZ) then
        return false
    end

    local projected = GameStateHelpers.makeSegment(pos.X, pos.Z, endX, endZ)

    for _, seg in allSegments do
        if GameStateHelpers.segmentsIntersect(projected, seg) then
            return false
        end
    end

    return true
end

function AIBot:scoreDirection(direction, allSegments, playerStates, useFloodFill)
    local pos = self.state.position
    local candidateX = pos.X + direction.X * Constants.GRID_SIZE
    local candidateZ = pos.Z + direction.Z * Constants.GRID_SIZE

    local probeDirections = {
        direction,
        rotateLeft(direction),
        rotateRight(direction),
    }

    local totalDistance = 0
    local maxProbe = self.profile.lookaheadStuds * 2

    for _, probeDir in probeDirections do
        local dist = self:distanceToObstacle(candidateX, candidateZ, probeDir, allSegments, maxProbe)
        totalDistance = totalDistance + dist
    end

    local score = totalDistance

    if self.profile.aggressionWeight > 0 then
        local strategicScore = self:strategicScore(candidateX, candidateZ, direction, playerStates)
        score = score * (1 - self.profile.aggressionWeight) + strategicScore * self.profile.aggressionWeight
    end

    if useFloodFill then
        local floodScore = self:floodFillScore(candidateX, candidateZ, allSegments)
        if floodScore > 0 then
            score = score * 0.3 + floodScore * 0.7
        end
    end

    return score
end

function AIBot:distanceToObstacle(startX, startZ, direction, allSegments, maxDist)
    local probeEndX = startX + direction.X * maxDist
    local probeEndZ = startZ + direction.Z * maxDist
    local probe = GameStateHelpers.makeSegment(startX, startZ, probeEndX, probeEndZ)
    local minDist = maxDist

    for _, seg in allSegments do
        if GameStateHelpers.segmentsIntersect(probe, seg) then
            if GameStateHelpers.isHorizontal(probe) then
                if GameStateHelpers.isVertical(seg) then
                    local dist = math.abs(seg.startX - startX)
                    if dist < minDist then minDist = dist end
                else
                    local segMinX = math.min(seg.startX, seg.endX)
                    local overlapStart = math.max(segMinX, startX)
                    local dist = math.max(0, overlapStart - startX)
                    if dist < minDist then minDist = dist end
                end
            else
                if GameStateHelpers.isHorizontal(seg) then
                    local dist = math.abs(seg.startZ - startZ)
                    if dist < minDist then minDist = dist end
                else
                    local segMinZ = math.min(seg.startZ, seg.endZ)
                    local overlapStart = math.max(segMinZ, startZ)
                    local dist = math.max(0, overlapStart - startZ)
                    if dist < minDist then minDist = dist end
                end
            end
        end
    end

    local half = Constants.ARENA_SIZE / 2
    if direction.X > 0 then
        minDist = math.min(minDist, half - startX)
    elseif direction.X < 0 then
        minDist = math.min(minDist, startX + half)
    end
    if direction.Z > 0 then
        minDist = math.min(minDist, half - startZ)
    elseif direction.Z < 0 then
        minDist = math.min(minDist, startZ + half)
    end

    return minDist
end

function AIBot:strategicScore(candidateX, candidateZ, direction, playerStates)
    local score = 0
    local predictTicks = 10

    for _, state in playerStates do
        if state.isAI then continue end
        if not state.alive then continue end

        local predictedX = state.position.X + state.direction.X * Constants.BIKE_SPEED * Constants.TICK_INTERVAL * predictTicks
        local predictedZ = state.position.Z + state.direction.Z * Constants.BIKE_SPEED * Constants.TICK_INTERVAL * predictTicks

        local distToPredicted = math.sqrt((candidateX - predictedX)^2 + (candidateZ - predictedZ)^2)
        local currentDist = math.sqrt((self.state.position.X - predictedX)^2 + (self.state.position.Z - predictedZ)^2)

        if distToPredicted < currentDist then
            score = score + (currentDist - distToPredicted)
        end
    end

    return score
end

function AIBot:floodFillScore(startX, startZ, allSegments)
    local cellSize = 64
    local cellBudget = 300

    local function cellKey(cx, cz)
        return cx .. "," .. cz
    end

    local function isCellFree(cx, cz)
        local worldX = cx * cellSize + cellSize / 2
        local worldZ = cz * cellSize + cellSize / 2
        if not GameStateHelpers.isInsideArena(worldX, worldZ) then
            return false
        end
        for _, seg in allSegments do
            if GameStateHelpers.pointHitsSegment(worldX, worldZ, seg) then
                return false
            end
        end
        return true
    end

    local startCX = math.floor(startX / cellSize)
    local startCZ = math.floor(startZ / cellSize)

    local visited = {}
    local queue = { { startCX, startCZ } }
    local queueIdx = 1
    local count = 0

    while queueIdx <= #queue and count < cellBudget do
        local cell = queue[queueIdx]
        queueIdx = queueIdx + 1
        local key = cellKey(cell[1], cell[2])
        if not visited[key] then
            visited[key] = true
            if isCellFree(cell[1], cell[2]) then
                count = count + 1
                local neighbors = {
                    { cell[1] + 1, cell[2] },
                    { cell[1] - 1, cell[2] },
                    { cell[1], cell[2] + 1 },
                    { cell[1], cell[2] - 1 },
                }
                for _, n in neighbors do
                    table.insert(queue, n)
                end
            end
        end
    end

    return count
end

function AIBot:executeTurn(direction)
    if direction == self.state.direction then
        return
    end

    local currentDist = (self.state.position - self.state.lastTurnPosition).Magnitude
    if currentDist < self.profile.minSegmentLength then
        return
    end

    GameStateManager.applyTurn(self.state.player, self.state.position, direction)
end

function AIBot:cleanup()
    if self.cleanedUp then return end
    self.cleanedUp = true
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    if self.state then
        local playerStates = GameStateManager.getPlayerStates()
        if playerStates[self.state.player] then
            playerStates[self.state.player] = nil
        end
        TrailManager.removePlayer(self.state.player)
        self.state = nil
    end
    print("[AIBot] Bot " .. self.botId .. " cleaned up")
end

function AIBot.init()
    local playerCount = #Players:GetPlayers()
    local botCount = math.max(Constants.AI_BOT_COUNT - playerCount, 0)
    if botCount <= 0 then
        botCount = 1
    end

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
        bot:start()
    end

    print("[AIBot] Initialized " .. math.min(botCount, #spawnConfigs) .. " bots")
end

return AIBot
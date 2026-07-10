--[[
    LightbikeController.luau
    ========================
    Core client-side bike controller.
    - Replaces StarterCharacter with a Neon Part bike
    - Grid-snapped 90 degree movement with input buffering
    - Scriptable camera locked behind/above the bike
    - Fires TurnEvent to server on each turn
    - Drives LocalTrailRenderer each frame
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TurnEvent = ReplicatedStorage:WaitForChild("TurnEvent")
local DeathEvent = ReplicatedStorage:WaitForChild("DeathEvent")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameState = require(ReplicatedStorage.Shared.GameState)
local LocalTrailRenderer = require(script.Parent.LocalTrailRenderer)


local LightbikeController = {}

local bike: Part? = nil
local direction: Vector3 = Constants.DIRECTIONS.NORTH
local position: Vector3 = Vector3.new(0, Constants.SPAWN_Y, 0)
local lastTurnPosition: Vector3 = position
local alive: boolean = false
local inputBuffer: { Vector3 } = {}
local turnCooldown: number = 0
local cameraLerpSpeed: number = 8
local inputConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local playerColor: Color3 = Constants.COLORS[1]

function LightbikeController.init()
    local player = Players.LocalPlayer
    if not player then
        player = Players.PlayerAdded:Wait()
    end

    player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        spawnBike(char)
    end)

    DeathEvent.OnClientEvent:Connect(function()
        LightbikeController.destroy()
    end)

    playerColor = Constants.COLORS[(player.UserId - 1) % #Constants.COLORS + 1]

    if player.Character then
        spawnBike(player.Character)
    end
end

function spawnBike(char: Model)
    if bike then
        bike:Destroy()
        bike = nil
    end
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    alive = true
    direction = Constants.DIRECTIONS.NORTH
    position = Vector3.new(0, Constants.SPAWN_Y, 0)
    lastTurnPosition = position
    inputBuffer = {}
    turnCooldown = 0


    char:SetAttribute("TronBike", true)
    for _, child in char:GetChildren() do
        if child:IsA("BasePart") then
            child.Transparency = 1
        end
    end
    char.PrimaryPart = nil

    bike = Instance.new("Part")
    bike.Name = "Lightbike"
    bike.Anchored = true
    bike.CanCollide = false
    bike.Material = Enum.Material.Neon
    bike.Color = playerColor
    bike.Size = Constants.BIKE_SIZE
    bike.CFrame = CFrame.lookAt(position, position + direction)
    bike.Parent = Workspace

    LocalTrailRenderer.clear()
    LocalTrailRenderer.setColor(playerColor)
    LocalTrailRenderer.init(position, direction)

    local camera = Workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    local bikeCF = CFrame.lookAt(position, position + direction)
    local camOffset = bikeCF:VectorToWorldSpace(Vector3.new(0, 8, 16))
    camera.CFrame = CFrame.lookAt(position + camOffset, position + direction * 10 + Vector3.new(0, 2, 0))

    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not alive then return end
        if input.KeyCode == Enum.KeyCode.A then
            queueTurn(1)
        elseif input.KeyCode == Enum.KeyCode.D then
            queueTurn(-1)
        end
    end)

    renderConnection = RunService.RenderStepped:Connect(function(dt)
        if not alive or not bike then return end
        tickBike(dt)

        updateCamera(dt)
    end)
end

function queueTurn(sign: number)
    local newDir = CFrame.Angles(0, math.rad(sign * Constants.TURN_ANGLE), 0) * direction
    newDir = Vector3.new(math.round(newDir.X), 0, math.round(newDir.Z))
    table.insert(inputBuffer, newDir)
end

function tickBike(dt: number)
    turnCooldown = turnCooldown - dt

    local moveAmount = Constants.BIKE_SPEED * dt
    position = position + direction * moveAmount

    if #inputBuffer > 0 then
        if Constants.GRID_SIZE > 0 then
            local onCrossAxis = direction.X ~= 0 and position.Z or position.X
            local aligned = math.abs(math.round(onCrossAxis / Constants.GRID_SIZE) * Constants.GRID_SIZE - onCrossAxis) < moveAmount * 1.5
            if aligned then
                local newDir = inputBuffer[1]
                turnComplete(newDir)
                table.remove(inputBuffer, 1)
            end
        else
            local newDir = inputBuffer[1]
            turnComplete(newDir)
            table.remove(inputBuffer, 1)
        end
    end

    if turnCooldown <= 0 and #inputBuffer > 0 then
        if not positionSnapping() then
            turnComplete(inputBuffer[1])
            table.remove(inputBuffer, 1)
        end
    end

    bike.CFrame = CFrame.lookAt(position, position + direction)
    LocalTrailRenderer.update(position, lastTurnPosition)
end

function positionSnapping(): boolean
    if Constants.GRID_SIZE <= 0 then return false end
    if direction.X ~= 0 then
        local snapZ = math.round(position.Z / Constants.GRID_SIZE) * Constants.GRID_SIZE
        return math.abs(position.Z - snapZ) > 0.1
    else
        local snapX = math.round(position.X / Constants.GRID_SIZE) * Constants.GRID_SIZE
        return math.abs(position.X - snapX) > 0.1
    end
end

function turnComplete(newDir: Vector3)
    LocalTrailRenderer.finalizeSegment(lastTurnPosition, position)
    direction = newDir
    lastTurnPosition = position
    turnCooldown = 0.05
    TurnEvent:FireServer(lastTurnPosition, direction, os.clock())
end

function updateCamera(dt: number)
    local camera = Workspace.CurrentCamera
    local bikeCF = CFrame.lookAt(position, position + direction)
    local offset = bikeCF:VectorToWorldSpace(Vector3.new(0, 8, 16))
    local targetPos = position + offset
    local targetLook = position + direction * 10 + Vector3.new(0, 2, 0)
    local targetCF = CFrame.lookAt(targetPos, targetLook)
    local smoothFactor = 1 - math.exp(-cameraLerpSpeed * dt)
    camera.CFrame = targetCF
    camera.FieldOfView = 90 + (Constants.BIKE_SPEED / 10)
end

function LightbikeController.destroy()
    if bike then
        bike:Destroy()
        bike = nil
    end
    LocalTrailRenderer.clear()
    alive = false
end

return LightbikeController
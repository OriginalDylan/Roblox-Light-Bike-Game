local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RestartEvent = ReplicatedStorage:WaitForChild("RestartEvent")

local DeathUI = {}

local gui: ScreenGui? = nil

function DeathUI.init()
    if gui then return end

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    gui = Instance.new("ScreenGui")
    gui.Name = "DeathUI"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.6
    overlay.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(0.6, 0.15)
    title.Position = UDim2.fromScale(0.2, 0.3)
    title.BackgroundTransparency = 1
    title.Text = "You blew up!"
    title.TextSize = 48
    title.TextColor3 = Color3.new(0, 1, 1)
    title.Font = Enum.Font.GothamBlack
    title.Parent = gui

    local button = Instance.new("TextButton")
    button.Name = "PlayAgain"
    button.Size = UDim2.fromScale(0.4, 0.12)
    button.Position = UDim2.fromScale(0.3, 0.55)
    button.BackgroundColor3 = Color3.new(0, 0.5, 1)
    button.Text = "Play Again"
    button.TextSize = 32
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBlack
    button.Parent = gui

    button.Activated:Connect(function()
        RestartEvent:FireServer()
        DeathUI.hide()
    end)
end

function DeathUI.show()
    DeathUI.init()
    if gui then
        gui.Enabled = true
    end
end

function DeathUI.hide()
    if gui then
        gui.Enabled = false
    end
end

return DeathUI
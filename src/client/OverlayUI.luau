local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RestartEvent = ReplicatedStorage:WaitForChild("RestartEvent")

--[[
    OverlayUI.luau
    ==============
    Single reusable end-of-round screen. Used for both death and victory:
    show(title, accentColor) displays a dim overlay + title + "Play Again"
    button, which fires RestartEvent (server resets the whole match).

    Thin wrappers: DeathUI -> "You blew up!", VictoryUI -> "You Win!".
]]

local OverlayUI = {}

local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil

function OverlayUI.init()
    if gui then return end

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    gui = Instance.new("ScreenGui")
    gui.Name = "OverlayUI"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.6
    overlay.Parent = gui

    titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.fromScale(0.6, 0.15)
    titleLabel.Position = UDim2.fromScale(0.2, 0.3)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextSize = 48
    titleLabel.TextColor3 = Color3.new(0, 1, 1)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.Parent = gui

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
        OverlayUI.hide()
    end)
end

function OverlayUI.show(title: string, accent: Color3)
    OverlayUI.init()
    if titleLabel then
        titleLabel.Text = title
        titleLabel.TextColor3 = accent
    end
    if gui then
        gui.Enabled = true
    end
end

function OverlayUI.hide()
    if gui then
        gui.Enabled = false
    end
end

return OverlayUI
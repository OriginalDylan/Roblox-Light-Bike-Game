local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeathEvent = ReplicatedStorage:WaitForChild("DeathEvent")

local MatchManager = {}

function MatchManager.init()
    print("[MatchManager] Initialized")
end

function MatchManager.killBike(player)
    DeathEvent:FireClient(player)
end

return MatchManager
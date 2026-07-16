local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeathEvent = ReplicatedStorage:WaitForChild("DeathEvent")

local MatchManager = {}

function MatchManager.init()
    print("[MatchManager] Initialized")
end

function MatchManager.killBike(player)
    if typeof(player) == "Instance" then
        DeathEvent:FireClient(player)
    end
end

return MatchManager

-- Thin wrapper: victory overlay.
local OverlayUI = require(script.Parent.OverlayUI)

local VictoryUI = {}

function VictoryUI.show()
    OverlayUI.show("You Win!", Color3.fromRGB(255, 215, 0))
end

function VictoryUI.hide()
    OverlayUI.hide()
end

return VictoryUI
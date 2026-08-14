-- Thin wrapper: death overlay.
local OverlayUI = require(script.Parent.OverlayUI)

local DeathUI = {}

function DeathUI.show()
    OverlayUI.show("You blew up!", Color3.new(0, 1, 1))
end

function DeathUI.hide()
    OverlayUI.hide()
end

return DeathUI
---@class SharedInit
local SharedInit = {}

---@description Initialize all shared components
function SharedInit.initialize()
    local Callbacks = require("shared/lib/callbacks")
    Callbacks.initialize(IsDuplicityVersion())
    
    print("^5[SUCCESS] ^3Shared Libraries^7 initialized")
    
    if GetCurrentResourceName() ~= "powerac" then
        print("^3Power Anticheat detected in resource: ^7" .. GetCurrentResourceName())
    end
end

return SharedInit 
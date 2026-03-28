---@class BravUI
BravUI = BravUI or {}

BravUI.version = "2.0.0"
BravUI.modules = {}

local defaults = {
    general = {
        welcomeMessage = true,
    },
    positions = {},
}

local function OnAddonLoaded(event, addonName)
    if addonName ~= "BravUI" then return end

    BravLib.Storage.Init(defaults)
    BravUI:LoadModules()

    BravLib.Event.Unregister("ADDON_LOADED", OnAddonLoaded)
    BravLib.Debug("BravUI initialized")
end

local function OnPlayerLogin()
    if BravLib.API.Get("general", "welcomeMessage") then
        BravLib.Print("v" .. BravUI.version .. " loaded. Type |cFF00FFFF/brav|r to open settings.")
    end
    BravLib.Event.Unregister("PLAYER_LOGIN", OnPlayerLogin)
end

BravLib.Event.Register("ADDON_LOADED", OnAddonLoaded)
BravLib.Event.Register("PLAYER_LOGIN", OnPlayerLogin)

function BravUI:RegisterModule(name, module)
    if self.modules[name] then
        BravLib.Warn("Module '" .. name .. "' already registered")
        return
    end
    module.name = name
    module.enabled = false
    self.modules[name] = module
    BravLib.Debug("Module registered: " .. name)
end

function BravUI:GetModule(name)
    return self.modules[name]
end

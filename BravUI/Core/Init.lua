---@class BravUI
BravUI = BravUI or {}

BravUI.version = "2.0.1-alpha"
BravUI.modules = {}

local defaults = {
    general = {
        welcomeMessage = true,
        useClassColor  = true,
    },
    positions  = {},
    unitframes = {
        player = {
            width          = 220,
            showPower      = true,
            showClassPower = true,
            height = {
                hp         = 26,
                power      = 10,
                classPower = 7,
            },
            colors = {
                useClassColor  = true,
                usePowerColor  = true,
            },
            text = {},
            cast = {
                enabled    = true,
                anchor     = "POWER_BOTTOM",
                x          = 0,
                y          = 0,
                w          = 220,
                h          = 16,
                spellSize  = 12,
                timeSize   = 12,
                colors = {
                    normal         = { r = 1.0, g = 0.8, b = 0.0 },
                    notInterruptible = { r = 0.6, g = 0.6, b = 0.6 },
                },
            },
            buffs = {
                enabled       = true,
                count         = 16,
                iconSize      = 22,
                spacing       = 2,
                growDirection = "RIGHT",
                combatOnly    = false,
            },
            debuffs = {
                enabled       = true,
                count         = 8,
                iconSize      = 22,
                spacing       = 2,
                growDirection = "RIGHT",
                combatOnly    = false,
            },
        },
        tot = {
            width     = 180,
            showPower = true,
            height = {
                hp    = 22,
                power = 8,
            },
            colors = {
                useClassColor = true,
                usePowerColor = true,
                useReaction   = true,
            },
            text = {},
        },
        pet = {
            width     = 120,
            showPower = true,
            height = {
                hp    = 18,
                power = 6,
            },
            colors = {
                useClassColor = false,
                usePowerColor = true,
            },
            text = {},
            cast = {
                enabled   = true,
                anchor    = "POWER_BOTTOM",
                x         = 0,
                y         = 0,
                w         = 120,
                h         = 14,
                spellSize = 10,
                timeSize  = 10,
                colors = {
                    normal           = { r = 1.0, g = 0.8, b = 0.0 },
                    notInterruptible = { r = 0.6, g = 0.6, b = 0.6 },
                },
            },
        },
        focus = {
            width          = 180,
            showPower      = true,
            height = {
                hp    = 22,
                power = 8,
            },
            colors = {
                useClassColor  = true,
                usePowerColor  = true,
                useReaction    = true,
            },
            text = {},
        },
        target = {
            cast = {
                enabled   = true,
                anchor    = "POWER_BOTTOM",
                x         = 0,
                y         = 0,
                w         = 220,
                h         = 16,
                spellSize = 12,
                timeSize  = 12,
                colors = {
                    normal           = { r = 1.0, g = 0.8, b = 0.0 },
                    notInterruptible = { r = 0.6, g = 0.6, b = 0.6 },
                },
            },
            width            = 220,
            showPower        = true,
            rangeEnabled     = true,
            outOfRangeAlpha  = 0.4,
            height = {
                hp    = 26,
                power = 10,
            },
            colors = {
                useClassColor  = true,
                usePowerColor  = true,
                useReaction    = true,
            },
            text = {},
            buffs = {
                enabled       = true,
                count         = 16,
                iconSize      = 22,
                spacing       = 2,
                growDirection = "RIGHT",
                combatOnly    = false,
            },
            debuffs = {
                enabled       = true,
                count         = 8,
                iconSize      = 22,
                spacing       = 2,
                growDirection = "RIGHT",
                combatOnly    = false,
            },
        },
        group = {
            cast = {
                enabled = true,
                colors = {
                    normal           = { r = 1.0, g = 0.8, b = 0.0 },
                    channel          = { r = 0.3, g = 0.7, b = 1.0 },
                    notInterruptible = { r = 0.6, g = 0.6, b = 0.6 },
                },
            },
            enabled         = true,
            width           = 220,
            showPower       = true,
            showClassPower  = false,
            spacing         = 8,
            rangeEnabled    = true,
            outOfRangeAlpha = 0.4,
            showRole        = true,
            showLeader      = true,
            scale           = 1.0,
            posX            = -350,
            posY            = -200,
            height = {
                hp         = 26,
                power      = 10,
                classPower = 7,
            },
            colors = {
                useClassColor = true,
                usePowerColor = true,
            },
            text = {},
        },
        raid15 = {
            enabled         = true,
            width           = 120,
            showPower       = true,
            columns         = 5,
            spacing         = 4,
            rowSpacing      = 4,
            rangeEnabled    = true,
            outOfRangeAlpha = 0.4,
            showRole        = true,
            showLeader      = true,
            groupBySubgroup = false,
            showGroupLabel  = true,
            scale           = 1.0,
            posX            = -350,
            posY            = -200,
            height = {
                hp    = 20,
                power = 6,
            },
            colors = {
                useClassColor = true,
                usePowerColor = true,
            },
            text = {},
        },
        raid25 = {
            enabled         = true,
            width           = 100,
            showPower       = true,
            columns         = 5,
            spacing         = 3,
            rowSpacing      = 3,
            rangeEnabled    = true,
            outOfRangeAlpha = 0.4,
            showRole        = true,
            showLeader      = true,
            groupBySubgroup = false,
            showGroupLabel  = true,
            scale           = 1.0,
            posX            = -350,
            posY            = -200,
            height = {
                hp    = 18,
                power = 5,
            },
            colors = {
                useClassColor = true,
                usePowerColor = true,
            },
            text = {},
        },
        raid40 = {
            enabled         = true,
            width           = 80,
            showPower       = false,
            columns         = 8,
            spacing         = 2,
            rowSpacing      = 2,
            rangeEnabled    = true,
            outOfRangeAlpha = 0.4,
            showRole        = true,
            showLeader      = true,
            groupBySubgroup = false,
            showGroupLabel  = true,
            scale           = 1.0,
            posX            = -350,
            posY            = -200,
            height = {
                hp    = 16,
                power = 4,
            },
            colors = {
                useClassColor = true,
                usePowerColor = true,
            },
            text = {},
        },
    },
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

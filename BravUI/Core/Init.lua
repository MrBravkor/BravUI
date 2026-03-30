---@class BravUI
BravUI = BravUI or {}

BravUI.version = "2.0.5-alpha"
BravUI.modules = {}

local defaults = {
    general = {
        welcomeMessage = true,
        useClassColor  = true,
        hideBlizzardUI = true,
        font           = "russo",
        globalFontSize = 12,
    },
    positions  = {
        VehicleExit  = { x = 0,    y = -150 },
        PlayerBuffs  = { x = 0,    y = -160 },
        PlayerDebuffs = { x = 0,   y = -186 },
        TargetBuffs  = { x = 0,    y = -290 },
        TargetDebuffs = { x = 0,   y = -316 },
        ["Barre 1"]   = { x = 0,   y = -360 },
        ["Barre 2"]   = { x = 0,   y = -400 },
        ["Barre 3"]   = { x = 0,   y = -440 },
        ["Barre 4"]   = { x = 0,   y = -480 },
        ["Barre 5"]   = { x = 0,   y = -520 },
        ["Barre 6"]   = { x = 0,   y = -560 },
        ["Barre 7"]   = { x = 0,   y = -600 },
        ["Barre 8"]   = { x = 0,   y = -640 },
        Familiers      = { x = 0,   y = -680 },
        Postures       = { x = 0,   y = -720 },
        ["Panneau Chat"] = { x = -735, y = -430 },
        ["InfoBar"]      = { x = 0,    y = 390 },
    },
    minimap = {
        enabled          = true,
        point            = "TOPRIGHT",
        relPoint         = "TOPRIGHT",
        x                = -30,
        y                = -30,
        panelWidth       = 250,
        panelHeight      = 250,
        opacity          = 0.75,
        showHeader       = true,
        showFooter       = true,
        showClock        = true,
        showCalendar     = true,
        showTracking     = true,
        showCompartment  = true,
        hideAddonButtons = true,
        headerIconSize   = 16,
        mailIconSize     = 18,
        diffIconSize     = 24,
        compartIconSize  = 20,
        iconColor        = { r = 1, g = 1, b = 1 },
        mailIconColor    = { r = 1, g = 1, b = 1 },
        diffIconColor    = { r = 1, g = 1, b = 1 },
        compartIconColor = { r = 1, g = 1, b = 1 },
        headerFontSize   = 11,
        clockFontSize    = 11,
        footerFontSize   = 11,
        guildFontSize    = 11,
        clockFormat      = "24h",
        zoneTextColor    = { r = 1, g = 1, b = 1 },
        clockTextColor   = { r = 1, g = 1, b = 1 },
        contactsTextColor = { r = 1, g = 1, b = 1 },
        guildTextColor   = { r = 1, g = 1, b = 1 },
    },
    unitframes = {
        player = {
            enabled        = true,
            scale          = 1,
            posX           = 0,
            posY           = -200,
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
            text = {
                name  = { enabled = true, anchor = "LEFT",   size = 13, offsetX = 6,  offsetY = 0 },
                hp    = { enabled = true, anchor = "RIGHT",  size = 13, offsetX = -6, offsetY = 0, format = "VALUE_PERCENT" },
                power = { enabled = true, anchor = "CENTER", size = 11, format = "VALUE" },
            },
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
            enabled   = true,
            scale     = 1,
            posX      = 0,
            posY      = -285,
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
            text = {
                name  = { enabled = true, anchor = "LEFT",   size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true, anchor = "RIGHT",  size = 10, offsetX = -4, offsetY = 0, format = "VALUE_PERCENT" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
            },
        },
        pet = {
            enabled   = true,
            scale     = 1,
            posX      = -200,
            posY      = -200,
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
            text = {
                name  = { enabled = true, anchor = "LEFT",   size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true, anchor = "RIGHT",  size = 10, offsetX = -4, offsetY = 0, format = "VALUE_PERCENT" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
            },
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
            enabled        = true,
            scale          = 1,
            posX           = 0,
            posY           = -320,
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
            text = {
                name  = { enabled = true, anchor = "LEFT",   size = 11, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true, anchor = "RIGHT",  size = 11, offsetX = -4, offsetY = 0, format = "VALUE_PERCENT" },
                power = { enabled = true, anchor = "CENTER", size = 10, format = "VALUE" },
            },
        },
        target = {
            enabled          = true,
            scale            = 1,
            posX             = 0,
            posY             = -250,
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
            text = {
                name  = { enabled = true, anchor = "LEFT",   size = 13, offsetX = 6,  offsetY = 0 },
                hp    = { enabled = true, anchor = "RIGHT",  size = 13, offsetX = -6, offsetY = 0, format = "VALUE_PERCENT" },
                power = { enabled = true, anchor = "CENTER", size = 11, format = "VALUE" },
                level = { enabled = true, size = 12 },
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
            scale           = 1,
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
            text = {
                name  = { enabled = true,  size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  size = 10, offsetX = -4, offsetY = 0 },
                power = { enabled = false, size = 8 },
            },
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
            scale           = 1,
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
            text = {
                name  = { enabled = true,  size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  size = 10, offsetX = -4, offsetY = 0 },
                power = { enabled = false, size = 8 },
            },
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
            scale           = 1,
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
            text = {
                name  = { enabled = true,  size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  size = 10, offsetX = -4, offsetY = 0 },
                power = { enabled = false, size = 8 },
            },
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
            scale           = 1,
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
            text = {
                name  = { enabled = true,  size = 9,  offsetX = 3,  offsetY = 0 },
                hp    = { enabled = false, size = 9,  offsetX = -3, offsetY = 0 },
                power = { enabled = false, size = 8 },
            },
        },
    },
    chat = {
        enabled = true,
        locked = true,
        panelWidth = 450,
        panelHeight = 220,
        opacity = 0.75,
        tabOpacity = 0.85,
        fontSize = 12,
        tabFontSize = 12,
        tabHeight = 15,
        useClassColor = false,
        tabTextColor = { r = 1, g = 1, b = 1 },
        useClassColorActive = true,
        activeTabTextColor = { r = 1, g = 1, b = 1 },
        showTabUnderline = true,
        fadeTabs = false,
        fadeTabsAlpha = 0.45,
        editBoxBorderByChannel = true,
        infobar = {
            height = 22,
            opacity = 0.75,
            fontSize = 11,
            showSpec = true,
            showGold = true,
            showDurability = true,
            showPerf = true,
        },
    },
    actionbars = {
        enabled          = true,
        buttonSize       = 36,
        buttonSpacing    = 2,
        showKeybinds     = true,
        showMacroNames   = false,
        showEmptySlots   = true,
        showCooldownText = true,
        bars             = {},
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

-- ============================================================================
-- SLASH COMMANDS (registered in core so they work with LoadOnDemand menu)
-- ============================================================================

SLASH_BRAV1 = "/brav"
SlashCmdList["BRAV"] = function()
    local loaded = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loaded then pcall(loaded, "BravUI_Menu") end
    if BravUI.Menu and BravUI.Menu.Toggle then
        BravUI.Menu:Toggle()
    end
end

SLASH_BRAVMOVE1 = "/bravmove"
SlashCmdList["BRAVMOVE"] = function()
    if BravUI.Mover and BravUI.Mover.Toggle then
        BravUI.Mover:Toggle()
    elseif BravUI.Move and BravUI.Move.Toggle then
        BravUI.Move.Toggle()
    end
end

SLASH_BRAVRESET1 = "/bravreset"
SlashCmdList["BRAVRESET"] = function()
    BravLib.Storage.Reset()
    BravLib.Print("Settings reset to defaults. Reload UI to apply.")
end

SLASH_BRAVDEBUG1 = "/bravdebug"
SlashCmdList["BRAVDEBUG"] = function()
    BravLib.debug = not BravLib.debug
    BravLib.Print("Debug mode: " .. (BravLib.debug and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

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

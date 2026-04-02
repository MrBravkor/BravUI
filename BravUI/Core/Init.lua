---@class BravUI
BravUI = BravUI or {}

BravUI.version = "2.0.8-alpha"
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
        ["Meter Panel"]  = { x = 200,  y = -300 },
        ["Timer M+"]     = { x = 0,    y = 200 },
        ["Barre XP"]     = { x = 0,    y = 0 },
        ["Barre Rep"]    = { x = 0,    y = -25 },
        ["Barre Honneur"] = { x = 0,   y = -50 },
        ["Barre Ressource"] = { x = 0, y = -232 },
        ["Queue Eye"]       = { x = 0, y = -100 },
        ["CDM Essentiels"]  = { x = 0, y = 0 },
        ["CDM Utilitaires"] = { x = 0, y = 0 },
        ["CDM Buffs Icone"] = { x = 0, y = 0 },
        ["CDM Buffs Barre"] = { x = 0, y = 0 },
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
            backgrounds = {
                hp         = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power      = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                classPower = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                segments   = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                cast  = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
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
            showRole           = true,
            roleIconSize       = 14,
            roleIconAnchor     = "CENTER",
            roleIconOffsetX    = 0,
            roleIconOffsetY    = 0,
            showLeader         = true,
            leaderIconSize     = 12,
            leaderIconAnchor   = "TOPLEFT",
            leaderIconOffsetX  = 0,
            leaderIconOffsetY  = 0,
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
            },
            text = {
                name  = { enabled = true,  anchor = "LEFT",   size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  anchor = "RIGHT",  size = 10, offsetX = -4, offsetY = 0, format = "VALUE" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
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
            showRole           = true,
            roleIconSize       = 14,
            roleIconAnchor     = "CENTER",
            roleIconOffsetX    = 0,
            roleIconOffsetY    = 0,
            showLeader         = true,
            leaderIconSize     = 12,
            leaderIconAnchor   = "TOPLEFT",
            leaderIconOffsetX  = 0,
            leaderIconOffsetY  = 0,
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
            },
            text = {
                name  = { enabled = true,  anchor = "LEFT",   size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  anchor = "RIGHT",  size = 10, offsetX = -4, offsetY = 0, format = "VALUE" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
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
            showRole           = true,
            roleIconSize       = 14,
            roleIconAnchor     = "CENTER",
            roleIconOffsetX    = 0,
            roleIconOffsetY    = 0,
            showLeader         = true,
            leaderIconSize     = 12,
            leaderIconAnchor   = "TOPLEFT",
            leaderIconOffsetX  = 0,
            leaderIconOffsetY  = 0,
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
            },
            text = {
                name  = { enabled = true,  anchor = "LEFT",   size = 10, offsetX = 4,  offsetY = 0 },
                hp    = { enabled = true,  anchor = "RIGHT",  size = 10, offsetX = -4, offsetY = 0, format = "VALUE" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
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
            showRole           = true,
            roleIconSize       = 14,
            roleIconAnchor     = "CENTER",
            roleIconOffsetX    = 0,
            roleIconOffsetY    = 0,
            showLeader         = true,
            leaderIconSize     = 12,
            leaderIconAnchor   = "TOPLEFT",
            leaderIconOffsetX  = 0,
            leaderIconOffsetY  = 0,
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
            backgrounds = {
                hp    = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
                power = { enabled = true, alpha = 0.55, color = { r = 0, g = 0, b = 0 } },
            },
            text = {
                name  = { enabled = true,  anchor = "LEFT",   size = 9,  offsetX = 3,  offsetY = 0 },
                hp    = { enabled = false, anchor = "RIGHT",  size = 9,  offsetX = -3, offsetY = 0, format = "VALUE" },
                power = { enabled = false, anchor = "CENTER", size = 8,  format = "VALUE" },
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
    meter = {
        enabled        = true,
        barHeight      = 16,
        barSpacing     = 1,
        fontSize       = 9,
        showRank       = true,
        showPercent    = true,
        classColors    = true,
        maxBars        = 50,
        layout         = 2,
        panelWidth     = 440,
        panelHeight    = 223,
        opacity        = 0.75,
        tabHeight      = 15,
        windowOpacity  = 0.8,
        timerEnabled   = true,
        summaryEnabled = true,
        timerScale     = 1.0,
    },
    afk = {
        enabled = true,
    },
    expbar = {
        enabled         = true,
        width           = 450,
        height          = 20,
        hideAtMaxLevel  = true,
        useClassColor   = false,
        barColor        = { r = 0.58, g = 0.40, b = 0.93 },
        alpha           = 1.0,
        bgAlpha         = 0.55,
        showBorder      = true,
        showText        = true,
        showLeftText    = true,
        showRightText   = true,
        textFormat      = "value_percent",
        textAnchor      = "CENTER",
        leftTextAnchor  = "LEFT",
        rightTextAnchor = "RIGHT",
        fontSize        = 12,
        leftFontSize    = 13,
        rightFontSize   = 13,
        centerTextColor = { r = 1, g = 1, b = 1 },
        leftTextColor   = { r = 1, g = 1, b = 1 },
        rightTextColor  = { r = 1, g = 1, b = 1 },
    },
    repbar = {
        enabled         = true,
        width           = 450,
        height          = 20,
        hideNoFaction   = true,
        alpha           = 1.0,
        bgAlpha         = 0.55,
        showBorder      = true,
        showText        = true,
        showLeftText    = true,
        showRightText   = true,
        textFormat      = "value_percent",
        textAnchor      = "CENTER",
        leftTextAnchor  = "LEFT",
        rightTextAnchor = "RIGHT",
        fontSize        = 12,
        leftFontSize    = 13,
        rightFontSize   = 13,
        centerTextColor = { r = 1, g = 1, b = 1 },
        leftTextColor   = { r = 1, g = 1, b = 1 },
        rightTextColor  = { r = 1, g = 1, b = 1 },
    },
    honorbar = {
        enabled         = true,
        width           = 450,
        height          = 20,
        alwaysShow      = false,
        barColor        = { r = 1.0, g = 0.71, b = 0.0 },
        alpha           = 1.0,
        bgAlpha         = 0.55,
        showBorder      = true,
        showText        = true,
        showLeftText    = true,
        showRightText   = true,
        textFormat      = "value_percent",
        textAnchor      = "CENTER",
        leftTextAnchor  = "LEFT",
        rightTextAnchor = "RIGHT",
        fontSize        = 12,
        leftFontSize    = 13,
        rightFontSize   = 13,
        centerTextColor = { r = 1, g = 1, b = 1 },
        leftTextColor   = { r = 1, g = 1, b = 1 },
        rightTextColor  = { r = 1, g = 1, b = 1 },
    },
    cursor = {
        enabled       = true,
        scale         = 1.0,
        alpha         = 1.0,
        showMainRing  = true,
        mainRingSize  = 90,
        showReticle   = true,
        reticleSize   = 8,
        showGCD       = true,
        gcdSize       = 44,
        gcdFillDrain  = "fill",
        gcdRotation   = 12,
        showCast      = true,
        castSize      = 140,
        castFillDrain = "fill",
        castRotation  = 12,
        enableTrail   = false,
        trailDuration = 0.5,
        trailDensity  = 0.005,
        trailScale    = 1.0,
        trailMinMove  = 0.5,
        combatOnly    = false,
        shiftAction   = "None",
        ctrlAction    = "None",
        altAction     = "None",
        pingDuration  = 0.5,
        pingStartSize = 200,
        pingEndSize   = 60,
        crossDuration = 1.5,
        crossGap      = 35,
    },

    -- ── Combat Log ───────────────────────────────────────────────────────────
    combatlog = {
        enabled           = true,
        chatNotify        = true,
        showIndicator     = true,

        -- Donjons
        dungeonNormal     = false,
        dungeonHeroic     = false,
        dungeonMythic     = true,
        dungeonMythicPlus = true,
        dungeonTimewalking = false,

        -- Raids
        raidLFR           = false,
        raidNormal        = true,
        raidHeroic        = true,
        raidMythic        = true,

        -- PvP
        arena             = false,
        battleground      = false,
    },

    -- ── Cooldown ─────────────────────────────────────────────────────────────
    cooldown = {
        enabled = true,

        -- Ancre commune
        offsetX = 0,
        offsetY = -220,
        width   = 220,
        gap     = 4,

        -- Cooldown Manager (Blizzard CooldownViewer restyle)
        cdm = {
            enabled        = true,
            iconSize       = 36,
            iconSpacing    = 2,
            iconBorder     = true,
            iconBorderSize = 1,
            iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
            cdFontSize     = 12,
            cdFontOutline  = "OUTLINE",
            stackFontSize  = 10,
            stackFontOutline = "OUTLINE",
            swipeR = 0, swipeG = 0, swipeB = 0, swipeA = 0.7,
            smartVisibility = true,
            opacity = {
                Essential = 1.0,
                Utility   = 1.0,
                BuffIcon  = 1.0,
                BuffBar   = 1.0,
                Custom    = 1.0,
            },
        },

        -- Barre primaire (mana/rage/energy...)
        primary = {
            enabled         = true,
            height          = 12,
            width           = 220,
            texture         = "Interface\\Buttons\\WHITE8X8",
            border          = true,
            borderSize      = 1,
            borderColor     = { r = 0, g = 0, b = 0, a = 1 },
            showText        = true,
            textFormat      = "value",
            fontSize        = 11,
            alpha           = 1.0,
            bgAlpha         = 0.55,
            showBorder      = true,
            -- Ancrage au viewer CDM
            anchorToViewer  = true,
            anchorPoint     = "TOP",
            anchorOffsetX   = 0,
            anchorOffsetY   = -2,
            flexibleWidth   = true,
            -- Couleur
            useClassColor   = false,
            usePowerColor   = true,
            barColor        = { r = 0, g = 0.44, b = 0.87 },
            centerTextColor = { r = 1, g = 1, b = 1 },
        },

        -- Barre secondaire (combo/holy/runes...)
        secondary = {
            enabled      = true,
            height       = 10,
            width        = 220,
            segmentGap   = 3,
            offsetX      = 0,
            offsetY      = 0,
            texture      = "Interface\\Buttons\\WHITE8X8",
            border       = true,
            borderSize   = 1,
            borderColor  = { r = 0, g = 0, b = 0, a = 1 },
            usePowerColor = true,
            alpha        = 1.0,
        },

        -- Cast Bar
        castbar = {
            enabled        = true,
            height         = 12,
            texture        = "Interface\\Buttons\\WHITE8X8",
            border         = true,
            borderSize     = 1,
            borderColor    = { r = 0, g = 0, b = 0, a = 1 },
            showSpellName  = true,
            showTimer      = true,
            colorNormal    = { r = 1,   g = 0.82, b = 0 },
            colorInterrupt = { r = 1,   g = 0.3,  b = 0.3 },
            alpha          = 1.0,
        },

        -- Visibilite globale
        hideOutOfCombat = false,
        hideInVehicle   = true,
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

SLASH_BRAVMETER1 = "/bd"
SLASH_BRAVMETER2 = "/bravmeter"
SlashCmdList["BRAVMETER"] = function(msg)
    if BravUI.Meter and BravUI.Meter.HandleSlash then
        BravUI.Meter:HandleSlash(msg)
    end
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

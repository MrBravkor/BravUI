-- BravUI/Modules/Meter/MPlus.lua
-- Fused port of v1 MPlus/Tracker.lua + MPlus/TimerUI.lua + MPlus/SummaryUI.lua
-- No AceAddon, no external dependencies
-- Requires BravUI.Meter to be initialized (by Bars.lua)

local BravUI = BravUI
local U = BravUI.Utils

local F          = BravLib.Format
local DM         = BravLib.DamageMeter
local TEX        = F.TEX_WHITE
local Number     = F.Number
local SafeFormat = F.SafeFormat
local TimeF      = F.Time
local TimeMMSS   = F.TimeMMSS
local MakeFont   = F.MakeFont
local MakeSep    = F.MakeSep
local ApplyShadow = F.ApplyShadow

local function GetDB()
    return BravLib.API.GetModule("meter") or {}
end

local function GetFont()
    return U.GetFont()
end

local function GetClassColor()
    return U.GetClassColor("player")
end

local function ClassColor(class)
    if not class then return 0.5, 0.5, 0.5 end
    local c = RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

-- ############################################################################
-- PART 1: TRACKER
-- M+ run data collection — events, encounters, deaths, loot, CC
-- ############################################################################

local Tracker = {}

-- ---------------------------------------------------------------------------
-- CC SPELLS TABLE
-- ---------------------------------------------------------------------------

local CC_SPELLS = {
    -- Mage
    [118]    = true,  -- Polymorph
    [28271]  = true,  -- Polymorph (Turtle)
    [28272]  = true,  -- Polymorph (Pig)
    [61025]  = true,  -- Polymorph (Serpent)
    [61305]  = true,  -- Polymorph (Black Cat)
    [61780]  = true,  -- Polymorph (Turkey)
    [126819] = true,  -- Polymorph (Porcupine)
    [161353] = true,  -- Polymorph (Polar Bear)
    [161354] = true,  -- Polymorph (Monkey)
    [161355] = true,  -- Polymorph (Penguin)
    [161372] = true,  -- Polymorph (Peacock)
    [277787] = true,  -- Polymorph (Direhorn)
    [277792] = true,  -- Polymorph (Bumblebee)
    [391622] = true,  -- Polymorph (Duck)
    -- Druid
    [2637]   = true,  -- Hibernate
    [33786]  = true,  -- Cyclone
    [99]     = true,  -- Incapacitating Roar
    [339]    = true,  -- Entangling Roots
    [102359] = true,  -- Mass Entanglement
    -- Hunter
    [187650] = true,  -- Freezing Trap
    [3355]   = true,  -- Freezing Trap (debuff)
    [19386]  = true,  -- Wyvern Sting
    [213691] = true,  -- Scatter Shot
    [162480] = true,  -- Steel Trap
    [117526] = true,  -- Binding Shot
    -- Paladin
    [20066]  = true,  -- Repentance
    [853]    = true,  -- Hammer of Justice
    [105421] = true,  -- Blinding Light
    [115750] = true,  -- Blinding Light (old)
    [10326]  = true,  -- Turn Evil
    -- Priest
    [605]    = true,  -- Mind Control
    [8122]   = true,  -- Psychic Scream
    [9484]   = true,  -- Shackle Undead
    [200196] = true,  -- Holy Word: Chastise
    [88625]  = true,  -- Holy Word: Chastise (stun)
    [64044]  = true,  -- Psychic Horror
    -- Rogue
    [6770]   = true,  -- Sap
    [2094]   = true,  -- Blind
    [1776]   = true,  -- Gouge
    [1833]   = true,  -- Cheap Shot
    [408]    = true,  -- Kidney Shot
    -- Shaman
    [51514]  = true,  -- Hex
    [210873] = true,  -- Hex (Compy)
    [211004] = true,  -- Hex (Spider)
    [211010] = true,  -- Hex (Snake)
    [211015] = true,  -- Hex (Cockroach)
    [269352] = true,  -- Hex (Skeletal Hatchling)
    [277778] = true,  -- Hex (Zandalari Tendonripper)
    [277784] = true,  -- Hex (Wicker Mongrel)
    [309328] = true,  -- Hex (Living Honey)
    [118905] = true,  -- Static Charge (Capacitor Totem)
    -- Warlock
    [710]    = true,  -- Banish
    [5782]   = true,  -- Fear
    [6358]   = true,  -- Seduction
    [118699] = true,  -- Fear (AoE)
    [30283]  = true,  -- Shadowfury
    [6789]   = true,  -- Mortal Coil
    [196364] = true,  -- Unstable Affliction silence
    -- Warrior
    [5246]   = true,  -- Intimidating Shout
    [132168] = true,  -- Shockwave
    [132169] = true,  -- Storm Bolt
    -- Death Knight
    [108194] = true,  -- Asphyxiate
    [221562] = true,  -- Asphyxiate (Blood)
    [207167] = true,  -- Blinding Sleet
    [47528]  = true,  -- Mind Freeze (for completeness)
    -- Demon Hunter
    [217832] = true,  -- Imprison
    [221527] = true,  -- Imprison (Detainment)
    [179057] = true,  -- Chaos Nova
    [200166] = true,  -- Metamorphosis stun
    [211881] = true,  -- Fel Eruption
    -- Monk
    [115078] = true,  -- Paralysis
    [119381] = true,  -- Leg Sweep
    [198909] = true,  -- Song of Chi-Ji
    [116706] = true,  -- Disable
    -- Evoker
    [360806] = true,  -- Sleep Walk
    [372245] = true,  -- Terror of the Skies
}

-- ---------------------------------------------------------------------------
-- ROLE PRIORITY (for sorting)
-- ---------------------------------------------------------------------------

local ROLE_PRIORITY = {
    TANK    = 1,
    HEALER  = 2,
    DAMAGER = 3,
    NONE    = 4,
}

-- ---------------------------------------------------------------------------
-- INTERNAL STATE
-- ---------------------------------------------------------------------------

local currentRun = nil
local lastRun    = nil
local isRunning  = false

-- ---------------------------------------------------------------------------
-- CALLBACK SYSTEM
-- ---------------------------------------------------------------------------

local callbacks = {}

local function RegisterCallback(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    table.insert(callbacks[event], fn)
end

local function FireCallbacks(event, ...)
    if not callbacks[event] then return end
    for _, fn in ipairs(callbacks[event]) do
        pcall(fn, event, ...)
    end
end

Tracker.RegisterCallback = RegisterCallback
Tracker.FireCallbacks    = FireCallbacks

-- ---------------------------------------------------------------------------
-- GROUP SCANNING
-- ---------------------------------------------------------------------------

local function ScanGroup()
    local players = {}
    local numGroup = GetNumGroupMembers()
    if numGroup == 0 then
        -- Solo
        local name = UnitName("player")
        local _, class = UnitClass("player")
        local role = "DAMAGER"
        local guid = UnitGUID("player")
        local specIndex = GetSpecialization() or 0
        local specID, specName, _, specIcon
        if specIndex > 0 then
            specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
        end
        players[guid] = {
            name     = name,
            class    = class,
            role     = role,
            guid     = guid,
            specID   = specID,
            specName = specName,
            specIcon = specIcon,
            damage   = 0,
            healing  = 0,
            damageTaken = 0,
            avoidable   = 0,
            interrupts  = 0,
            dispels     = 0,
            cc          = 0,
            deaths      = 0,
            dps         = 0,
            hps         = 0,
            loot        = {},
        }
        return players
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numGroup do
        local unit = prefix .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            local role = UnitGroupRolesAssigned(unit) or "NONE"
            local guid = UnitGUID(unit)
            local specID, specName, specIcon
            if C_Inspect and C_Inspect.RequestInspect then
                -- We'll try to get spec from inspect data if available
            end
            -- For the local player, get spec directly
            if UnitIsUnit(unit, "player") then
                local specIndex = GetSpecialization() or 0
                if specIndex > 0 then
                    specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
                end
            end
            players[guid] = {
                name     = name,
                class    = class,
                role     = role,
                guid     = guid,
                specID   = specID,
                specName = specName,
                specIcon = specIcon,
                damage   = 0,
                healing  = 0,
                damageTaken = 0,
                avoidable   = 0,
                interrupts  = 0,
                dispels     = 0,
                cc          = 0,
                deaths      = 0,
                dps         = 0,
                hps         = 0,
                loot        = {},
            }
        end
    end
    return players
end

-- ---------------------------------------------------------------------------
-- GET KEYSTONE INFO
-- ---------------------------------------------------------------------------

local function GetKeystoneInfo()
    local info = {}
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then
        local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
        info.mapID     = mapID
        info.name      = name or "Unknown"
        info.timeLimit = timeLimit or 0

        local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo()
        info.level   = level or 0
        info.affixes = affixes or {}
        info.wasEnergized = wasEnergized
    end
    return info
end

-- ---------------------------------------------------------------------------
-- INIT RUN
-- ---------------------------------------------------------------------------

local function InitRun()
    local keyInfo = GetKeystoneInfo()
    local players = ScanGroup()

    currentRun = {
        -- Keystone info
        mapID       = keyInfo.mapID,
        dungeonName = keyInfo.name or "Unknown",
        level       = keyInfo.level or 0,
        affixes     = keyInfo.affixes or {},
        timeLimit   = keyInfo.timeLimit or 0,

        -- Timing
        startTime   = GetTime(),
        endTime     = nil,
        elapsed     = 0,
        completed   = false,
        inTime      = false,

        -- Players
        players     = players,

        -- Encounters
        encounters  = {},
        currentEncounter = nil,

        -- Deaths
        deaths      = {},
        totalDeaths = 0,

        -- Loot
        loot        = {},

        -- CC
        totalCC     = 0,

        -- Score
        scoreGain   = nil,
    }

    isRunning = true
    FireCallbacks("RUN_START", currentRun)
end

-- ---------------------------------------------------------------------------
-- FINALIZE RUN
-- ---------------------------------------------------------------------------

local function FinalizeRun()
    if not currentRun then return end

    currentRun.endTime   = GetTime()
    currentRun.elapsed   = currentRun.endTime - currentRun.startTime
    currentRun.completed = true

    -- Check timing
    if currentRun.timeLimit and currentRun.timeLimit > 0 then
        currentRun.inTime = (currentRun.elapsed <= currentRun.timeLimit)
    end

    -- Collect DM stats per player if available
    if DM:IsAvailable() then
        local modes = { "damage", "healing", "damageTaken", "interrupts", "dispels", "avoidable" }
        for _, mode in ipairs(modes) do
            local sorted = DM:GetSorted(mode, 0)
            for _, entry in ipairs(sorted) do
                pcall(function()
                    local guid = entry.guid
                    if guid and currentRun.players[guid] then
                        local p = currentRun.players[guid]
                        if mode == "damage" then
                            p.damage = entry.value or 0
                            p.dps    = entry.perSecond or 0
                        elseif mode == "healing" then
                            p.healing = entry.value or 0
                            p.hps     = entry.perSecond or 0
                        elseif mode == "damageTaken" then
                            p.damageTaken = entry.value or 0
                        elseif mode == "interrupts" then
                            p.interrupts = entry.value or 0
                        elseif mode == "dispels" then
                            p.dispels = entry.value or 0
                        elseif mode == "avoidable" then
                            p.avoidable = entry.value or 0
                        end
                    end
                end)
            end
        end
    end

    -- Score gain from C_ChallengeMode
    if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        pcall(function()
            currentRun.scoreGain = C_ChallengeMode.GetOverallDungeonScore()
        end)
    end

    lastRun   = currentRun
    isRunning = false

    FireCallbacks("RUN_END", currentRun)
end

-- ---------------------------------------------------------------------------
-- CLEAR RUN
-- ---------------------------------------------------------------------------

local function ClearRun()
    if currentRun then
        lastRun = currentRun
    end
    currentRun = nil
    isRunning  = false
    FireCallbacks("RUN_RESET")
end

-- ---------------------------------------------------------------------------
-- CLEU HANDLERS
-- ---------------------------------------------------------------------------

local function OnUnitDied(destGUID, destName)
    if not currentRun then return end
    -- Check if it's a player in our group
    if currentRun.players[destGUID] then
        currentRun.totalDeaths = currentRun.totalDeaths + 1
        currentRun.players[destGUID].deaths = (currentRun.players[destGUID].deaths or 0) + 1
        table.insert(currentRun.deaths, {
            time   = GetTime() - currentRun.startTime,
            guid   = destGUID,
            name   = destName or currentRun.players[destGUID].name,
            boss   = currentRun.currentEncounter,
        })
        FireCallbacks("PLAYER_DEATH", destGUID, destName)
    end
end

local function OnSpellCastSuccess(sourceGUID, sourceName, spellID)
    if not currentRun then return end
    if not CC_SPELLS[spellID] then return end
    -- Check if the caster is in our group
    if currentRun.players[sourceGUID] then
        currentRun.players[sourceGUID].cc = (currentRun.players[sourceGUID].cc or 0) + 1
        currentRun.totalCC = currentRun.totalCC + 1
        FireCallbacks("CC_USED", sourceGUID, sourceName, spellID)
    end
end

-- ---------------------------------------------------------------------------
-- ENCOUNTER HANDLERS
-- ---------------------------------------------------------------------------

local function OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    if not currentRun then return end
    local enc = {
        id        = encounterID,
        name      = encounterName,
        startTime = GetTime() - currentRun.startTime,
        endTime   = nil,
        success   = false,
    }
    table.insert(currentRun.encounters, enc)
    currentRun.currentEncounter = encounterName
    FireCallbacks("ENCOUNTER_START", enc)
end

local function OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if not currentRun then return end
    -- Find the matching encounter
    for i = #currentRun.encounters, 1, -1 do
        local enc = currentRun.encounters[i]
        if enc.id == encounterID and not enc.endTime then
            enc.endTime = GetTime() - currentRun.startTime
            enc.success = (success == 1)
            break
        end
    end
    currentRun.currentEncounter = nil
    FireCallbacks("ENCOUNTER_END", encounterID, encounterName, success)
end

-- ---------------------------------------------------------------------------
-- LOOT HANDLER
-- ---------------------------------------------------------------------------

local function OnChatMsgLoot(msg)
    if not currentRun then return end
    -- Parse loot message: "PlayerName receives loot: [Item]"
    -- or "You receive loot: [Item]"
    local player, itemLink = nil, nil

    -- English pattern
    itemLink = msg:match("|c.-|Hitem:.-|h%[.-%]|h|r")
    if not itemLink then return end

    -- Try to find player name
    player = msg:match("^(.+) receives? loot")
    if not player then
        -- "You receive loot" case
        if msg:match("^You receive") then
            player = UnitName("player")
        end
    end

    if player and itemLink then
        local entry = {
            player   = player,
            itemLink = itemLink,
            time     = GetTime() - currentRun.startTime,
        }
        table.insert(currentRun.loot, entry)

        -- Also add to the player's personal loot list
        for _, p in pairs(currentRun.players) do
            if p.name == player then
                table.insert(p.loot, entry)
                break
            end
        end

        FireCallbacks("LOOT_RECEIVED", entry)
    end
end

-- ---------------------------------------------------------------------------
-- MAIN EVENT DISPATCHER
-- ---------------------------------------------------------------------------

local function HandleTrackerEvent(event, ...)
    if event == "CHALLENGE_MODE_START" then
        InitRun()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        FinalizeRun()
    elseif event == "CHALLENGE_MODE_RESET" then
        ClearRun()
    elseif event == "ENCOUNTER_START" then
        OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd(...)
    elseif event == "CHAT_MSG_LOOT" then
        OnChatMsgLoot(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Rescan group if run is active
        if currentRun and isRunning then
            local newPlayers = ScanGroup()
            for guid, data in pairs(newPlayers) do
                if not currentRun.players[guid] then
                    currentRun.players[guid] = data
                end
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
        if subEvent == "UNIT_DIED" then
            OnUnitDied(destGUID, destName)
        elseif subEvent == "SPELL_CAST_SUCCESS" then
            OnSpellCastSuccess(sourceGUID, sourceName, spellID)
        end
    end
end

-- ---------------------------------------------------------------------------
-- EVENT FRAME (raw frame for CLEU + WoW events)
-- ---------------------------------------------------------------------------

-- Utilise BravLib.Event pour éviter le taint (BravUI a des SecureFrames)
-- CLEU nécessite un frame dédié — créé après PLAYER_LOGIN via C_Timer
local trackerFrame = nil

local function RegisterTrackerEvents()
    trackerFrame = CreateFrame("Frame")
    trackerFrame:SetScript("OnEvent", function(_, event, ...)
        HandleTrackerEvent(event, ...)
    end)
    trackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    trackerFrame:RegisterEvent("CHAT_MSG_LOOT")
end

BravLib.Event.Register("PLAYER_LOGIN", function()
    -- Différer la création du frame pour sortir du contexte tainté
    C_Timer.After(0, function()
        RegisterTrackerEvents()
    end)
end)

-- Events standards via BravLib (pas de taint)
BravLib.Event.Register("CHALLENGE_MODE_START", function()
    HandleTrackerEvent("CHALLENGE_MODE_START")
end)
BravLib.Event.Register("CHALLENGE_MODE_COMPLETED", function()
    HandleTrackerEvent("CHALLENGE_MODE_COMPLETED")
end)
BravLib.Event.Register("CHALLENGE_MODE_RESET", function()
    HandleTrackerEvent("CHALLENGE_MODE_RESET")
end)
BravLib.Event.Register("ENCOUNTER_START", function(_, ...)
    HandleTrackerEvent("ENCOUNTER_START", ...)
end)
BravLib.Event.Register("ENCOUNTER_END", function(_, ...)
    HandleTrackerEvent("ENCOUNTER_END", ...)
end)
BravLib.Event.Register("GROUP_ROSTER_UPDATE", function()
    HandleTrackerEvent("GROUP_ROSTER_UPDATE")
end)

-- ---------------------------------------------------------------------------
-- TEST DATA
-- ---------------------------------------------------------------------------

local function GenerateTestRun()
    local playerGUID = UnitGUID("player")
    local _, playerClass = UnitClass("player")
    local playerName = UnitName("player")

    local testPlayers = {}

    -- Add local player
    testPlayers[playerGUID] = {
        name     = playerName,
        class    = playerClass,
        role     = "DAMAGER",
        guid     = playerGUID,
        specID   = nil,
        specName = nil,
        specIcon = nil,
        damage   = 45000000,
        healing  = 1200000,
        damageTaken = 8500000,
        avoidable   = 320000,
        interrupts  = 18,
        dispels     = 4,
        cc          = 12,
        deaths      = 1,
        dps         = 125000,
        hps         = 3500,
        loot        = {},
    }

    -- Add fake group members
    local fakeMembers = {
        { name = "TestTank",    class = "WARRIOR",    role = "TANK",    damage = 22000000, healing = 6500000, damageTaken = 32000000, avoidable = 80000,  interrupts = 24, dispels = 0,  cc = 8,  deaths = 0, dps = 61000,  hps = 18000 },
        { name = "TestHealer",  class = "PRIEST",     role = "HEALER",  damage = 8000000,  healing = 52000000, damageTaken = 4200000, avoidable = 120000, interrupts = 2,  dispels = 22, cc = 3,  deaths = 0, dps = 22000,  hps = 145000 },
        { name = "TestDPS1",    class = "ROGUE",      role = "DAMAGER", damage = 52000000, healing = 800000,  damageTaken = 7800000,  avoidable = 450000, interrupts = 32, dispels = 0,  cc = 15, deaths = 2, dps = 144000, hps = 2200 },
        { name = "TestDPS2",    class = "MAGE",       role = "DAMAGER", damage = 48000000, healing = 600000,  damageTaken = 6200000,  avoidable = 180000, interrupts = 14, dispels = 0,  cc = 20, deaths = 1, dps = 133000, hps = 1600 },
    }

    for i, m in ipairs(fakeMembers) do
        local fakeGUID = "Player-0000-0000000" .. i
        testPlayers[fakeGUID] = {
            name        = m.name,
            class       = m.class,
            role        = m.role,
            guid        = fakeGUID,
            specID      = nil,
            specName    = nil,
            specIcon    = nil,
            damage      = m.damage,
            healing     = m.healing,
            damageTaken = m.damageTaken,
            avoidable   = m.avoidable,
            interrupts  = m.interrupts,
            dispels     = m.dispels,
            cc          = m.cc,
            deaths      = m.deaths,
            dps         = m.dps,
            hps         = m.hps,
            loot        = {},
        }
    end

    local testRun = {
        mapID       = 375,
        dungeonName = "Mists of Tirna Scithe",
        level       = 15,
        affixes     = { 9, 124, 6 },
        timeLimit   = 1800,
        startTime   = GetTime() - 1650,
        endTime     = GetTime(),
        elapsed     = 1650,
        completed   = true,
        inTime      = true,
        players     = testPlayers,
        encounters  = {
            { id = 2400, name = "Ingra Maloch",    startTime = 120,  endTime = 210,  success = true },
            { id = 2401, name = "Mistcaller",      startTime = 520,  endTime = 620,  success = true },
            { id = 2402, name = "Tred'ova",        startTime = 1100, endTime = 1250, success = true },
        },
        currentEncounter = nil,
        deaths = {
            { time = 350,  guid = playerGUID,             name = playerName,   boss = nil },
            { time = 720,  guid = "Player-0000-00000003", name = "TestDPS1",   boss = "Mistcaller" },
            { time = 1150, guid = "Player-0000-00000003", name = "TestDPS1",   boss = "Tred'ova" },
            { time = 1200, guid = "Player-0000-00000004", name = "TestDPS2",   boss = "Tred'ova" },
        },
        totalDeaths = 4,
        loot = {},
        totalCC = 58,
        scoreGain = 142,
    }

    return testRun
end

Tracker.GenerateTestRun = GenerateTestRun

-- ---------------------------------------------------------------------------
-- PUBLIC API
-- ---------------------------------------------------------------------------

function Tracker.IsRunning()
    return isRunning
end

function Tracker.GetCurrentRun()
    return currentRun
end

function Tracker.GetLastRun()
    return lastRun
end

function Tracker.GetRolePriority(role)
    return ROLE_PRIORITY[role] or ROLE_PRIORITY.NONE
end

-- Expose on namespace
BravUI.Meter.MPlus = Tracker


-- ############################################################################
-- PART 2: TIMER UI
-- Live M+ timer display during active runs
-- ############################################################################

local Timer = {}

-- ---------------------------------------------------------------------------
-- CONSTANTS
-- ---------------------------------------------------------------------------

local TIMER_WIDTH      = 300
local TIMER_HEIGHT     = 180
local UPDATE_INTERVAL  = 0.1
local DEATH_PENALTY    = 5

-- Threshold multipliers for key upgrade levels
local THRESHOLD_3 = 0.6   -- +3 if completed within 60% of time limit
local THRESHOLD_2 = 0.8   -- +2 if completed within 80% of time limit

-- Colors
local COLOR_GREEN   = { r = 0.2,  g = 0.9,  b = 0.2  }
local COLOR_YELLOW  = { r = 0.9,  g = 0.9,  b = 0.2  }
local COLOR_RED     = { r = 0.9,  g = 0.2,  b = 0.2  }
local COLOR_GRAY    = { r = 0.5,  g = 0.5,  b = 0.5  }
local COLOR_WHITE   = { r = 1.0,  g = 1.0,  b = 1.0  }
local COLOR_GOLD    = { r = 1.0,  g = 0.84, b = 0.0  }
local COLOR_BG      = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
local COLOR_BAR_BG  = { r = 0.12, g = 0.12, b = 0.12, a = 1.0  }
local COLOR_ACCENT  = nil -- set dynamically from class color

-- ---------------------------------------------------------------------------
-- TIMER STATE
-- ---------------------------------------------------------------------------

local timerFrame    = nil
local isVisible     = false
local isTestMode    = false
local testStartTime = nil
local timerElapsed  = 0

-- Boss rows pool
local bossRowPool = {}
local activeBossRows = 0

-- ---------------------------------------------------------------------------
-- BOSS ROW POOL
-- ---------------------------------------------------------------------------

local function AcquireBossRow(parent, index)
    if bossRowPool[index] then
        bossRowPool[index]:Show()
        return bossRowPool[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row:SetPoint("LEFT", 8, 0)
    row:SetPoint("RIGHT", -8, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

    row.name = MakeFont(row, 11)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(160)
    row.name:SetWordWrap(false)

    row.status = MakeFont(row, 11)
    row.status:SetPoint("RIGHT", -4, 0)
    row.status:SetJustifyH("RIGHT")

    row.time = MakeFont(row, 10)
    row.time:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.time:SetJustifyH("RIGHT")
    row.time:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)

    bossRowPool[index] = row
    return row
end

-- ---------------------------------------------------------------------------
-- GET SCENARIO DATA (boss progress + forces)
-- ---------------------------------------------------------------------------

local function GetScenarioData()
    local data = {
        bosses    = {},
        forces    = nil,
        maxForces = nil,
    }

    local _, _, numSteps = C_Scenario.GetStepInfo()
    if not numSteps or numSteps == 0 then return data end

    local GetCriteria = (C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo)
                     or (C_Scenario and C_Scenario.GetCriteriaInfo)
    if not GetCriteria then return data end

    for i = 1, numSteps do
        local ok, info = pcall(GetCriteria, i)
        if not ok then info = nil end
        if info then
            local criteriaString = info.description or ""
            local completed      = info.completed
            local quantity        = info.quantity or 0
            local totalQuantity  = info.totalQuantity or 0

            -- The last step is "Enemy Forces"
            if i == numSteps then
                data.forces    = quantity
                data.maxForces = totalQuantity
            else
                table.insert(data.bosses, {
                    name      = criteriaString,
                    completed = completed,
                    quantity  = quantity,
                    total     = totalQuantity,
                })
            end
        end
    end

    return data
end

-- ---------------------------------------------------------------------------
-- CREATE TIMER FRAME
-- ---------------------------------------------------------------------------

local function CreateTimerFrame()
    if timerFrame then return timerFrame end

    local cr, cg, cb = GetClassColor()
    COLOR_ACCENT = { r = cr, g = cg, b = cb }

    local f = CreateFrame("Frame", "BravUI_MPlusTimer", UIParent, "BackdropTemplate")
    f:SetSize(TIMER_WIDTH, TIMER_HEIGHT)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = TEX,
        edgeFile = TEX,
        edgeSize = 1,
    })
    f:SetBackdropColor(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, COLOR_BG.a)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Accent line at top
    local accent = f:CreateTexture(nil, "OVERLAY")
    accent:SetTexture(TEX)
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    accent:SetVertexColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 1)
    f.accent = accent

    -- Header: dungeon name + level
    f.dungeonText = MakeFont(f, 13)
    f.dungeonText:SetPoint("TOP", f, "TOP", 0, -8)
    f.dungeonText:SetTextColor(1, 1, 1, 1)

    f.levelText = MakeFont(f, 11)
    f.levelText:SetPoint("TOP", f.dungeonText, "BOTTOM", 0, -2)
    f.levelText:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 1)

    -- Timer bar background
    local barBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    barBG:SetHeight(20)
    barBG:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -42)
    barBG:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -42)
    barBG:SetBackdrop({
        bgFile   = TEX,
        edgeFile = TEX,
        edgeSize = 1,
    })
    barBG:SetBackdropColor(COLOR_BAR_BG.r, COLOR_BAR_BG.g, COLOR_BAR_BG.b, COLOR_BAR_BG.a)
    barBG:SetBackdropBorderColor(0, 0, 0, 0.6)
    f.barBG = barBG

    -- Timer bar fill
    local barFill = barBG:CreateTexture(nil, "ARTWORK")
    barFill:SetTexture(TEX)
    barFill:SetPoint("TOPLEFT", barBG, "TOPLEFT", 1, -1)
    barFill:SetPoint("BOTTOMLEFT", barBG, "BOTTOMLEFT", 1, 1)
    barFill:SetWidth(1)
    barFill:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 0.8)
    f.barFill = barFill

    -- Tick marks for +3 and +2 thresholds
    local tick3 = barBG:CreateTexture(nil, "OVERLAY")
    tick3:SetTexture(TEX)
    tick3:SetSize(1, 18)
    tick3:SetVertexColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.7)
    f.tick3 = tick3

    local tick2 = barBG:CreateTexture(nil, "OVERLAY")
    tick2:SetTexture(TEX)
    tick2:SetSize(1, 18)
    tick2:SetVertexColor(0.7, 0.7, 0.7, 0.5)
    f.tick2 = tick2

    -- Tick labels
    f.tick3Label = MakeFont(barBG, 8)
    f.tick3Label:SetPoint("BOTTOM", tick3, "TOP", 0, 1)
    f.tick3Label:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.8)
    f.tick3Label:SetText("+3")

    f.tick2Label = MakeFont(barBG, 8)
    f.tick2Label:SetPoint("BOTTOM", tick2, "TOP", 0, 1)
    f.tick2Label:SetTextColor(0.7, 0.7, 0.7, 0.6)
    f.tick2Label:SetText("+2")

    -- Timer text
    f.timerText = MakeFont(f, 14)
    f.timerText:SetPoint("LEFT", barBG, "LEFT", 4, 0)
    f.timerText:SetTextColor(1, 1, 1, 1)

    f.remainText = MakeFont(f, 10)
    f.remainText:SetPoint("RIGHT", barBG, "RIGHT", -4, 0)
    f.remainText:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b, 1)

    -- Separator after bar
    local sep1 = MakeSep(f)
    sep1:SetPoint("TOPLEFT", barBG, "BOTTOMLEFT", -8, -4)
    sep1:SetPoint("TOPRIGHT", barBG, "BOTTOMRIGHT", 8, -4)

    -- Boss section container
    f.bossContainer = CreateFrame("Frame", nil, f)
    f.bossContainer:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 8, -2)
    f.bossContainer:SetPoint("TOPRIGHT", sep1, "BOTTOMRIGHT", -8, -2)
    f.bossContainer:SetHeight(100)

    -- Forces bar at bottom
    local forcesBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    forcesBG:SetHeight(14)
    forcesBG:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    forcesBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
    forcesBG:SetBackdrop({
        bgFile   = TEX,
        edgeFile = TEX,
        edgeSize = 1,
    })
    forcesBG:SetBackdropColor(COLOR_BAR_BG.r, COLOR_BAR_BG.g, COLOR_BAR_BG.b, COLOR_BAR_BG.a)
    forcesBG:SetBackdropBorderColor(0, 0, 0, 0.5)
    f.forcesBG = forcesBG

    local forcesFill = forcesBG:CreateTexture(nil, "ARTWORK")
    forcesFill:SetTexture(TEX)
    forcesFill:SetPoint("TOPLEFT", forcesBG, "TOPLEFT", 1, -1)
    forcesFill:SetPoint("BOTTOMLEFT", forcesBG, "BOTTOMLEFT", 1, 1)
    forcesFill:SetWidth(1)
    forcesFill:SetVertexColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.7)
    f.forcesFill = forcesFill

    f.forcesText = MakeFont(forcesBG, 9)
    f.forcesText:SetPoint("CENTER", forcesBG, "CENTER", 0, 0)
    f.forcesText:SetTextColor(1, 1, 1, 1)

    -- Deaths counter
    f.deathsText = MakeFont(f, 10)
    f.deathsText:SetPoint("BOTTOMRIGHT", forcesBG, "TOPRIGHT", 0, 2)
    f.deathsText:SetJustifyH("RIGHT")
    f.deathsText:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 1)

    -- Move system
    if BravUI.Move and BravUI.Move.Enable then
        BravUI.Move.Enable(f, "Timer M+")
    end

    f:Hide()
    timerFrame = f
    return f
end

-- ---------------------------------------------------------------------------
-- UPDATE TIMER (called every UPDATE_INTERVAL)
-- ---------------------------------------------------------------------------

local function UpdateTimer(self, elapsed)
    if not timerFrame or not timerFrame:IsShown() then return end

    local run = nil
    local timeLimit = 0

    if isTestMode then
        run = Tracker.GetLastRun() or Tracker.GetCurrentRun()
        if not run then return end
        timerElapsed = GetTime() - (testStartTime or GetTime())
        timeLimit = run.timeLimit or 1800
    else
        run = Tracker.GetCurrentRun()
        if not run then
            timerFrame:Hide()
            isVisible = false
            return
        end
        timerElapsed = GetTime() - run.startTime
        timeLimit = run.timeLimit or 0
    end

    -- Update header
    timerFrame.dungeonText:SetText(run.dungeonName or "Unknown")
    timerFrame.levelText:SetText("+" .. (run.level or 0))

    -- Update timer text
    timerFrame.timerText:SetText(TimeMMSS(timerElapsed))

    -- Remaining time
    if timeLimit > 0 then
        local remaining = timeLimit - timerElapsed
        if remaining > 0 then
            timerFrame.remainText:SetText("+" .. TimeMMSS(remaining))
            timerFrame.remainText:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            timerFrame.remainText:SetText("-" .. TimeMMSS(math.abs(remaining)))
            timerFrame.remainText:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        end

        -- Bar fill
        local barWidth = timerFrame.barBG:GetWidth() - 2
        local pct = math.min(timerElapsed / timeLimit, 1.0)
        timerFrame.barFill:SetWidth(math.max(1, barWidth * pct))

        -- Bar color based on timing
        if pct <= THRESHOLD_3 then
            timerFrame.barFill:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 0.8)
        elseif pct <= THRESHOLD_2 then
            timerFrame.barFill:SetVertexColor(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, 0.8)
        elseif pct <= 1.0 then
            timerFrame.barFill:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.8)
        else
            timerFrame.barFill:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.4)
        end

        -- Tick positions
        local tick3Pos = THRESHOLD_3 * barWidth
        local tick2Pos = THRESHOLD_2 * barWidth
        timerFrame.tick3:SetPoint("LEFT", timerFrame.barBG, "LEFT", tick3Pos + 1, 0)
        timerFrame.tick2:SetPoint("LEFT", timerFrame.barBG, "LEFT", tick2Pos + 1, 0)

        -- Tick labels
        timerFrame.tick3Label:SetText("+3 " .. TimeMMSS(timeLimit * THRESHOLD_3))
        timerFrame.tick2Label:SetText("+2 " .. TimeMMSS(timeLimit * THRESHOLD_2))
    else
        timerFrame.remainText:SetText("")
        timerFrame.barFill:SetWidth(1)
    end

    -- Update boss rows
    if not isTestMode then
        local scenarioData = GetScenarioData()
        local numBosses = #scenarioData.bosses

        for i = 1, numBosses do
            local row = AcquireBossRow(timerFrame.bossContainer, i)
            local boss = scenarioData.bosses[i]
            row:SetPoint("TOP", timerFrame.bossContainer, "TOP", 0, -((i - 1) * 20))
            row.name:SetText(boss.name or "Boss " .. i)

            if boss.completed then
                row.status:SetText("DONE")
                row.status:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
                -- Find matching encounter for time display
                if run.encounters then
                    for _, enc in ipairs(run.encounters) do
                        if enc.name == boss.name and enc.endTime then
                            row.time:SetText(TimeMMSS(enc.endTime))
                            break
                        end
                    end
                end
            else
                row.status:SetText("")
                row.time:SetText("")
            end

            row.icon:SetTexture("Interface/Icons/Achievement_Boss_General_DragonSoul")
        end

        -- Hide extra rows
        for i = numBosses + 1, #bossRowPool do
            if bossRowPool[i] then
                bossRowPool[i]:Hide()
            end
        end

        -- Update forces
        if scenarioData.forces and scenarioData.maxForces and scenarioData.maxForces > 0 then
            local pct = scenarioData.forces / scenarioData.maxForces
            local forcesBarWidth = timerFrame.forcesBG:GetWidth() - 2
            timerFrame.forcesFill:SetWidth(math.max(1, forcesBarWidth * math.min(pct, 1.0)))
            timerFrame.forcesText:SetText(string.format("Forces: %d/%d (%.1f%%)", scenarioData.forces, scenarioData.maxForces, pct * 100))

            if pct >= 1.0 then
                timerFrame.forcesFill:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 0.7)
            else
                timerFrame.forcesFill:SetVertexColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.7)
            end
        else
            timerFrame.forcesFill:SetWidth(1)
            timerFrame.forcesText:SetText("Forces: --/--")
        end
    else
        -- Test mode: show fake bosses from the test run
        if run.encounters then
            for i, enc in ipairs(run.encounters) do
                local row = AcquireBossRow(timerFrame.bossContainer, i)
                row:SetPoint("TOP", timerFrame.bossContainer, "TOP", 0, -((i - 1) * 20))
                row.name:SetText(enc.name or "Boss " .. i)
                row.status:SetText("DONE")
                row.status:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
                row.time:SetText(TimeMMSS(enc.endTime or 0))
                row.icon:SetTexture("Interface/Icons/Achievement_Boss_General_DragonSoul")
            end
            for i = #run.encounters + 1, #bossRowPool do
                if bossRowPool[i] then bossRowPool[i]:Hide() end
            end
        end
        timerFrame.forcesFill:SetWidth(timerFrame.forcesBG:GetWidth() - 2)
        timerFrame.forcesText:SetText("Forces: 300/300 (100%)")
        timerFrame.forcesFill:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 0.7)
    end

    -- Deaths display
    local deaths = 0
    if run then
        deaths = run.totalDeaths or 0
    end
    if deaths > 0 then
        local penalty = deaths * DEATH_PENALTY
        timerFrame.deathsText:SetText(string.format("Deaths: %d (-%ds)", deaths, penalty))
        timerFrame.deathsText:Show()
    else
        timerFrame.deathsText:Hide()
    end

    -- Dynamic height based on content
    local numBossRows = 0
    if not isTestMode then
        local sd = GetScenarioData()
        numBossRows = #sd.bosses
    elseif run and run.encounters then
        numBossRows = #run.encounters
    end
    local newHeight = 42 + 20 + 6 + (numBossRows * 20) + 6 + 14 + 12 + 16
    timerFrame:SetHeight(math.max(TIMER_HEIGHT, newHeight))
end

-- ---------------------------------------------------------------------------
-- SHOW / HIDE / TOGGLE
-- ---------------------------------------------------------------------------

function Timer.Show()
    local f = CreateTimerFrame()
    f:Show()
    isVisible = true
    isTestMode = false

    -- Start OnUpdate
    f:SetScript("OnUpdate", function(self, elapsed)
        self._updateAcc = (self._updateAcc or 0) + elapsed
        if self._updateAcc >= UPDATE_INTERVAL then
            self._updateAcc = 0
            UpdateTimer(self, elapsed)
        end
    end)
end

function Timer.Hide()
    if timerFrame then
        timerFrame:Hide()
        timerFrame:SetScript("OnUpdate", nil)
    end
    isVisible = false
    isTestMode = false
end

function Timer.Toggle()
    if isVisible then
        Timer.Hide()
    else
        Timer.Show()
    end
end

function Timer.ShowTest()
    local testRun = GenerateTestRun()
    lastRun = testRun

    local f = CreateTimerFrame()
    f:Show()
    isVisible   = true
    isTestMode  = true
    testStartTime = GetTime()

    f:SetScript("OnUpdate", function(self, elapsed)
        self._updateAcc = (self._updateAcc or 0) + elapsed
        if self._updateAcc >= UPDATE_INTERVAL then
            self._updateAcc = 0
            UpdateTimer(self, elapsed)
        end
    end)
end

function Timer.IsVisible()
    return isVisible
end

-- ---------------------------------------------------------------------------
-- CALLBACKS: RUN_START -> show, RUN_END -> hide
-- ---------------------------------------------------------------------------

RegisterCallback("RUN_START", function()
    Timer.Show()
end)

RegisterCallback("RUN_END", function()
    -- Keep timer visible briefly after run ends, then hide
    C_Timer.After(3, function()
        if not Tracker.IsRunning() then
            Timer.Hide()
        end
    end)
end)

RegisterCallback("RUN_RESET", function()
    Timer.Hide()
end)

-- ---------------------------------------------------------------------------
-- RECONNECTION: check for active challenge mode on login
-- ---------------------------------------------------------------------------

BravLib.Event.Register("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(2, function()
        if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
            local mapID = C_ChallengeMode.GetActiveChallengeMapID()
            if mapID and mapID > 0 then
                -- A challenge mode is already active, initialize tracking
                if not Tracker.IsRunning() then
                    -- Attempt to resume
                    InitRun()
                    Timer.Show()
                end
            end
        end
    end)
end)

-- Expose on namespace
BravUI.Meter.Timer = Timer


-- ############################################################################
-- PART 3: SUMMARY UI
-- Post-run summary window
-- ############################################################################

-- ---------------------------------------------------------------------------
-- CONSTANTS
-- ---------------------------------------------------------------------------

local WINDOW_WIDTH  = 780
local WINDOW_HEIGHT = 290
local ROW_HEIGHT    = 22
local HEADER_HEIGHT_S = 50
local TIMELINE_HEIGHT = 30
local TABLE_HEADER_H = 20

-- Column definitions (16 columns)
local COLUMNS = {
    { key = "spec",       label = "",            width = 20,  align = "CENTER" },
    { key = "role",       label = "",            width = 18,  align = "CENTER" },
    { key = "name",       label = "Name",        width = 90,  align = "LEFT"   },
    { key = "loot",       label = "",            width = 18,  align = "CENTER" },
    { key = "score",      label = "Score",       width = 45,  align = "RIGHT"  },
    { key = "dps",        label = "DPS",         width = 55,  align = "RIGHT"  },
    { key = "hps",        label = "HPS",         width = 50,  align = "RIGHT"  },
    { key = "damage",     label = "Damage",      width = 60,  align = "RIGHT"  },
    { key = "healing",    label = "Healing",     width = 60,  align = "RIGHT"  },
    { key = "damageTaken",label = "Dmg Taken",   width = 60,  align = "RIGHT"  },
    { key = "avoidable",  label = "Avoidable",   width = 55,  align = "RIGHT"  },
    { key = "interrupts", label = "Ints",        width = 35,  align = "RIGHT"  },
    { key = "dispels",    label = "Disp",        width = 35,  align = "RIGHT"  },
    { key = "cc",         label = "CC",          width = 30,  align = "RIGHT"  },
    { key = "deaths",     label = "Deaths",      width = 40,  align = "RIGHT"  },
}

-- Role icons and texcoords
local ROLE_ICONS = "Interface/LFGFrame/UI-LFG-ICON-PORTRAITROLES"
local ROLE_TEXCOORDS = {
    TANK    = { 0.0,  0.25, 0.25, 0.5  },
    HEALER  = { 0.25, 0.5,  0.0,  0.25 },
    DAMAGER = { 0.25, 0.5,  0.25, 0.5  },
    NONE    = { 0.25, 0.5,  0.25, 0.5  },
}

-- ---------------------------------------------------------------------------
-- SUMMARY STATE
-- ---------------------------------------------------------------------------

local summaryFrame  = nil
local playerRows    = {}
local headerElements = {}
local timelineElements = {}
local tableHeaderElements = {}
local lootElements  = {}

-- ---------------------------------------------------------------------------
-- SORTED PLAYERS
-- ---------------------------------------------------------------------------

local function GetSortedPlayers(run)
    if not run or not run.players then return {} end
    local sorted = {}
    for guid, p in pairs(run.players) do
        p.guid = guid
        table.insert(sorted, p)
    end
    table.sort(sorted, function(a, b)
        local ra = ROLE_PRIORITY[a.role] or 4
        local rb = ROLE_PRIORITY[b.role] or 4
        if ra ~= rb then return ra < rb end
        -- Same role: sort by DPS descending
        return (a.dps or 0) > (b.dps or 0)
    end)
    return sorted
end

-- ---------------------------------------------------------------------------
-- CREATE SUMMARY FRAME
-- ---------------------------------------------------------------------------

local function CreateSummaryFrame()
    if summaryFrame then return summaryFrame end

    local f = CreateFrame("Frame", "BravUI_MPlusSummary", UIParent, "BackdropTemplate")
    f:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(20)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = TEX,
        edgeFile = TEX,
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- ESC-closable
    table.insert(UISpecialFrames, "BravUI_MPlusSummary")

    -- Top accent line
    local accent = f:CreateTexture(nil, "OVERLAY")
    accent:SetTexture(TEX)
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local cr, cg, cb = GetClassColor()
    accent:SetVertexColor(cr, cg, cb, 1)
    f.accent = accent

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    closeBtn:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
    closeBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    summaryFrame = f
    return f
end

-- ---------------------------------------------------------------------------
-- CREATE HEADER (dungeon name, level, affixes, timing)
-- ---------------------------------------------------------------------------

local function CreateHeader(parent, run)
    -- Clear previous header elements
    for _, el in ipairs(headerElements) do
        if el.Hide then el:Hide() end
    end
    wipe(headerElements)

    -- Dungeon name
    local title = MakeFont(parent, 16)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)
    title:SetTextColor(1, 1, 1, 1)
    title:SetText((run.dungeonName or "Unknown") .. "  +" .. (run.level or 0))
    table.insert(headerElements, title)

    -- Affixes
    local affixText = MakeFont(parent, 10)
    affixText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    affixText:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
    local affixNames = {}
    if run.affixes then
        for _, affixID in ipairs(run.affixes) do
            if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
                local name = C_ChallengeMode.GetAffixInfo(affixID)
                if name then
                    table.insert(affixNames, name)
                end
            end
        end
    end
    affixText:SetText(table.concat(affixNames, " / "))
    table.insert(headerElements, affixText)

    -- Timing result (right side)
    local timingText = MakeFont(parent, 14)
    timingText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -10)
    timingText:SetJustifyH("RIGHT")
    table.insert(headerElements, timingText)

    if run.completed then
        local elapsed = run.elapsed or 0
        local timeLimit = run.timeLimit or 0
        local diff = timeLimit - elapsed

        timingText:SetText(TimeMMSS(elapsed))

        if run.inTime then
            timingText:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            timingText:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        end

        -- Delta time
        local deltaText = MakeFont(parent, 11)
        deltaText:SetPoint("TOPRIGHT", timingText, "BOTTOMRIGHT", 0, -1)
        deltaText:SetJustifyH("RIGHT")
        table.insert(headerElements, deltaText)

        if diff >= 0 then
            deltaText:SetText("+" .. TimeMMSS(diff))
            deltaText:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            deltaText:SetText("-" .. TimeMMSS(math.abs(diff)))
            deltaText:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        end
    else
        timingText:SetText("In Progress")
        timingText:SetTextColor(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end

    -- Deaths summary
    if run.totalDeaths and run.totalDeaths > 0 then
        local deathsLabel = MakeFont(parent, 10)
        deathsLabel:SetPoint("TOPLEFT", affixText, "BOTTOMLEFT", 0, -2)
        deathsLabel:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        deathsLabel:SetText(string.format("Deaths: %d  (-%ds)", run.totalDeaths, run.totalDeaths * DEATH_PENALTY))
        table.insert(headerElements, deathsLabel)
    end
end

-- ---------------------------------------------------------------------------
-- CREATE TIMELINE (boss segments on horizontal bar)
-- ---------------------------------------------------------------------------

local function CreateTimeline(parent, run, yOffset)
    -- Clear previous
    for _, el in ipairs(timelineElements) do
        if el.Hide then el:Hide() end
    end
    wipe(timelineElements)

    if not run or not run.encounters or #run.encounters == 0 then return yOffset end

    local totalTime = run.elapsed or run.timeLimit or 1800
    if totalTime <= 0 then totalTime = 1 end

    local barWidth = WINDOW_WIDTH - 24
    local barX = 12

    -- Timeline background
    local bg = parent:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(TEX)
    bg:SetHeight(12)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", barX, yOffset)
    bg:SetWidth(barWidth)
    bg:SetVertexColor(0.12, 0.12, 0.12, 1)
    table.insert(timelineElements, bg)

    -- Boss segments
    for i, enc in ipairs(run.encounters) do
        if enc.startTime and enc.endTime then
            local startPct = enc.startTime / totalTime
            local endPct   = enc.endTime / totalTime
            local segWidth = math.max(2, (endPct - startPct) * barWidth)
            local segX     = startPct * barWidth

            local seg = parent:CreateTexture(nil, "OVERLAY")
            seg:SetTexture(TEX)
            seg:SetHeight(12)
            seg:SetWidth(segWidth)
            seg:SetPoint("TOPLEFT", bg, "TOPLEFT", segX, 0)
            table.insert(timelineElements, seg)

            if enc.success then
                seg:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 0.7)
            else
                seg:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.7)
            end

            -- Boss name label below
            local label = MakeFont(parent, 8)
            label:SetPoint("TOP", seg, "BOTTOM", 0, -1)
            label:SetTextColor(0.7, 0.7, 0.7)
            label:SetText(enc.name or ("Boss " .. i))
            table.insert(timelineElements, label)
        end
    end

    -- Death markers on timeline
    if run.deaths then
        for _, death in ipairs(run.deaths) do
            if death.time and death.time > 0 then
                local deathPct = death.time / totalTime
                local marker = parent:CreateTexture(nil, "OVERLAY", nil, 2)
                marker:SetTexture(TEX)
                marker:SetSize(2, 14)
                marker:SetPoint("TOP", bg, "TOPLEFT", deathPct * barWidth, 1)
                marker:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.9)
                table.insert(timelineElements, marker)
            end
        end
    end

    -- Time marks
    local numMarks = 4
    for i = 1, numMarks do
        local markTime = (totalTime / (numMarks + 1)) * i
        local markPct  = markTime / totalTime
        local mark = parent:CreateTexture(nil, "OVERLAY")
        mark:SetTexture(TEX)
        mark:SetSize(1, 12)
        mark:SetPoint("TOPLEFT", bg, "TOPLEFT", markPct * barWidth, 0)
        mark:SetVertexColor(0.3, 0.3, 0.3, 0.5)
        table.insert(timelineElements, mark)

        local markLabel = MakeFont(parent, 7)
        markLabel:SetPoint("BOTTOM", bg, "TOPLEFT", markPct * barWidth, 1)
        markLabel:SetTextColor(0.4, 0.4, 0.4)
        markLabel:SetText(TimeMMSS(markTime))
        table.insert(timelineElements, markLabel)
    end

    return yOffset - TIMELINE_HEIGHT
end

-- ---------------------------------------------------------------------------
-- CREATE TABLE HEADER (column headers with separators)
-- ---------------------------------------------------------------------------

local function CreateTableHeader(parent, yOffset)
    for _, el in ipairs(tableHeaderElements) do
        if el.Hide then el:Hide() end
    end
    wipe(tableHeaderElements)

    -- Separator above
    local sep = MakeSep(parent)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    table.insert(tableHeaderElements, sep)

    local xOff = 12
    for _, col in ipairs(COLUMNS) do
        local header = MakeFont(parent, 9)
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOffset - 4)
        header:SetWidth(col.width)
        header:SetJustifyH(col.align)
        header:SetTextColor(0.6, 0.6, 0.6)
        header:SetText(col.label)
        header:SetWordWrap(false)
        table.insert(tableHeaderElements, header)
        xOff = xOff + col.width + 2
    end

    -- Separator below
    local sep2 = MakeSep(parent)
    sep2:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset - TABLE_HEADER_H)
    sep2:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset - TABLE_HEADER_H)
    table.insert(tableHeaderElements, sep2)

    return yOffset - TABLE_HEADER_H - 2
end

-- ---------------------------------------------------------------------------
-- CREATE PLAYER ROW
-- ---------------------------------------------------------------------------

local function CreatePlayerRow(parent, playerData, yOffset, rowIndex)
    local row = playerRows[rowIndex]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT", parent, "LEFT", 8, 0)
        row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
        row.cells = {}
        playerRows[rowIndex] = row
    end

    row:SetPoint("TOP", parent, "TOP", 0, yOffset)
    row:Show()

    -- Clear old cells
    for _, cell in pairs(row.cells) do
        if cell.Hide then cell:Hide() end
    end
    wipe(row.cells)

    local xOff = 4
    local cr, cg, cb = ClassColor(playerData.class)

    for _, col in ipairs(COLUMNS) do
        if col.key == "spec" then
            -- Spec icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -3)
            if playerData.specIcon then
                icon:SetTexture(playerData.specIcon)
            else
                icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
            end
            row.cells[col.key] = icon

        elseif col.key == "role" then
            -- Role icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -4)
            icon:SetTexture(ROLE_ICONS)
            local tc = ROLE_TEXCOORDS[playerData.role] or ROLE_TEXCOORDS.NONE
            icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
            row.cells[col.key] = icon

        elseif col.key == "name" then
            local fs = MakeFont(row, 11)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            fs:SetTextColor(cr, cg, cb)
            fs:SetText(playerData.name or "Unknown")
            row.cells[col.key] = fs

        elseif col.key == "loot" then
            -- Loot indicator
            if playerData.loot and #playerData.loot > 0 then
                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(14, 14)
                icon:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -4)
                icon:SetTexture("Interface/Icons/INV_Misc_Bag_10")
                row.cells[col.key] = icon
            end

        elseif col.key == "score" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
            fs:SetText(playerData.scoreGain and tostring(playerData.scoreGain) or "--")
            row.cells[col.key] = fs

        elseif col.key == "dps" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(1, 1, 1)
            local val = SafeFormat(playerData.dps)
            fs:SetText(val or Number(playerData.dps or 0))
            row.cells[col.key] = fs

        elseif col.key == "hps" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.3, 0.9, 0.3)
            local val = SafeFormat(playerData.hps)
            fs:SetText(val or Number(playerData.hps or 0))
            row.cells[col.key] = fs

        elseif col.key == "damage" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.9, 0.9, 0.9)
            local val = SafeFormat(playerData.damage, true)
            fs:SetText(val or Number(playerData.damage or 0))
            row.cells[col.key] = fs

        elseif col.key == "healing" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.3, 0.9, 0.3)
            local val = SafeFormat(playerData.healing, true)
            fs:SetText(val or Number(playerData.healing or 0))
            row.cells[col.key] = fs

        elseif col.key == "damageTaken" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.8, 0.4, 0.4)
            local val = SafeFormat(playerData.damageTaken, true)
            fs:SetText(val or Number(playerData.damageTaken or 0))
            row.cells[col.key] = fs

        elseif col.key == "avoidable" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            local avd = playerData.avoidable or 0
            if avd > 0 then
                fs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
            else
                fs:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
            end
            local val = SafeFormat(avd, true)
            fs:SetText(val or Number(avd))
            row.cells[col.key] = fs

        elseif col.key == "interrupts" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.6, 0.8, 1.0)
            fs:SetText(tostring(playerData.interrupts or 0))
            row.cells[col.key] = fs

        elseif col.key == "dispels" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.5, 0.9, 0.9)
            fs:SetText(tostring(playerData.dispels or 0))
            row.cells[col.key] = fs

        elseif col.key == "cc" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            fs:SetTextColor(0.9, 0.7, 0.3)
            fs:SetText(tostring(playerData.cc or 0))
            row.cells[col.key] = fs

        elseif col.key == "deaths" then
            local fs = MakeFont(row, 10)
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOff, -5)
            fs:SetWidth(col.width)
            fs:SetJustifyH("RIGHT")
            local d = playerData.deaths or 0
            if d > 0 then
                fs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
            else
                fs:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
            end
            fs:SetText(tostring(d))
            row.cells[col.key] = fs
        end

        xOff = xOff + col.width + 2
    end

    -- Row background (alternating)
    if not row.bg then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(TEX)
    end
    if rowIndex % 2 == 0 then
        row.bg:SetVertexColor(0.08, 0.08, 0.08, 0.5)
    else
        row.bg:SetVertexColor(0.05, 0.05, 0.05, 0.3)
    end

    return yOffset - ROW_HEIGHT
end

-- ---------------------------------------------------------------------------
-- CREATE LOOT SECTION (loot icons at bottom)
-- ---------------------------------------------------------------------------

local function CreateLootSection(parent, run, yOffset)
    for _, el in ipairs(lootElements) do
        if el.Hide then el:Hide() end
    end
    wipe(lootElements)

    if not run or not run.loot or #run.loot == 0 then return yOffset end

    -- Separator
    local sep = MakeSep(parent)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset - 4)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset - 4)
    table.insert(lootElements, sep)

    local lootLabel = MakeFont(parent, 9)
    lootLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset - 10)
    lootLabel:SetTextColor(0.6, 0.6, 0.6)
    lootLabel:SetText("Loot:")
    table.insert(lootElements, lootLabel)

    local xOff = 50
    for i, entry in ipairs(run.loot) do
        if i > 10 then break end -- Max 10 loot icons

        local itemLink = entry.itemLink
        if itemLink then
            local _, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemLink)
            if not itemTexture then
                -- Fallback: try extracting from link
                local itemID = itemLink:match("item:(%d+)")
                if itemID then
                    itemTexture = C_Item.GetItemIconByID(tonumber(itemID))
                end
            end

            local icon = CreateFrame("Button", nil, parent)
            icon:SetSize(20, 20)
            icon:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOffset - 6)
            table.insert(lootElements, icon)

            local tex = icon:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(itemTexture or "Interface/Icons/INV_Misc_QuestionMark")
            icon.tex = tex

            -- Tooltip on hover
            icon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Player name below icon
            local nameLabel = MakeFont(icon, 7)
            nameLabel:SetPoint("TOP", icon, "BOTTOM", 0, -1)
            nameLabel:SetTextColor(0.6, 0.6, 0.6)
            nameLabel:SetText(entry.player or "")
            table.insert(lootElements, nameLabel)

            xOff = xOff + 28
        end
    end

    return yOffset - 34
end

-- ---------------------------------------------------------------------------
-- SHOW SUMMARY
-- ---------------------------------------------------------------------------

function Tracker.ShowSummary(run)
    run = run or lastRun
    if not run then return end

    local f = CreateSummaryFrame()

    -- Build content
    CreateHeader(f, run)

    local yOff = -HEADER_HEIGHT_S
    yOff = CreateTimeline(f, run, yOff)
    yOff = CreateTableHeader(f, yOff)

    -- Player rows
    local sorted = GetSortedPlayers(run)
    for i = 1, #sorted do
        yOff = CreatePlayerRow(f, sorted[i], yOff, i)
    end

    -- Hide extra rows
    for i = #sorted + 1, #playerRows do
        if playerRows[i] then
            playerRows[i]:Hide()
        end
    end

    -- Loot section
    yOff = CreateLootSection(f, run, yOff)

    -- Adjust window height
    local totalHeight = math.abs(yOff) + 12
    f:SetHeight(math.max(WINDOW_HEIGHT, totalHeight))

    -- Fade-in animation
    f:SetAlpha(0)
    f:Show()

    local fadeIn = f:CreateAnimationGroup()
    local alpha = fadeIn:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.3)
    alpha:SetSmoothing("OUT")
    fadeIn:SetScript("OnFinished", function()
        f:SetAlpha(1)
    end)
    fadeIn:Play()
end

function Tracker.HideSummary()
    if summaryFrame then
        summaryFrame:Hide()
    end
end

function Tracker.ToggleSummary()
    if summaryFrame and summaryFrame:IsShown() then
        Tracker.HideSummary()
    else
        Tracker.ShowSummary()
    end
end

-- ---------------------------------------------------------------------------
-- AUTO-SHOW SUMMARY ON RUN END
-- ---------------------------------------------------------------------------

RegisterCallback("RUN_END", function(_, run)
    C_Timer.After(1, function()
        Tracker.ShowSummary(run)
    end)
end)

-- ---------------------------------------------------------------------------
-- TEST SUMMARY
-- ---------------------------------------------------------------------------

function Tracker.ShowTestSummary()
    local testRun = GenerateTestRun()
    Tracker.ShowSummary(testRun)
end

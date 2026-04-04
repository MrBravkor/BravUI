-- BravUI/Modules/Meter/Meter.lua
-- Module principal : registration, combat state, refresh ticker, slash commands, test data
-- Utilise C_DamageMeter (Midnight 12.0+)

local BravUI = BravUI

-- ============================================================================
-- NAMESPACE
-- ============================================================================

BravUI.Meter = BravUI.Meter or {}
local BD = BravUI.Meter

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local Meter = {}
BravUI:RegisterModule("Interface.Meter", Meter)

-- ============================================================================
-- LOCAL REFERENCES
-- ============================================================================

local F  = BravLib.Format
local DM = BravLib.DamageMeter

local function GetDB()
    return BravLib.API.GetModule("meter") or {}
end

-- ============================================================================
-- COMBAT STATE
-- ============================================================================

local inCombat = false
local combatStartTime = 0
local refreshTicker = nil
local REFRESH_INTERVAL = 0.5

local function RefreshAll()
    local Panel = BD.Panel
    if Panel and Panel.RefreshBars then
        Panel.RefreshBars()
    end
end

local function StartRefreshTicker()
    if refreshTicker then return end
    refreshTicker = C_Timer.NewTicker(REFRESH_INTERVAL, RefreshAll)
end

local function StopRefreshTicker()
    if refreshTicker then
        refreshTicker:Cancel()
        refreshTicker = nil
    end
end

function BD:IsInCombat()
    return inCombat
end

function BD:GetCombatTime()
    if inCombat then
        return GetTime() - combatStartTime
    end
    return 0
end

-- ============================================================================
-- SEGMENT METADATA (instance tracking)
-- ============================================================================

local function SaveSegmentMeta()
    local db = GetDB()
    if not db then return end
    if not db.segmentMeta then db.segmentMeta = {} end

    local inInstance, instanceType = IsInInstance()
    local name, _, difficultyID, difficultyName = GetInstanceInfo()

    -- Snapshot des segments actuels pour tagger les nouveaux
    local segs = DM:GetSegments()
    if not segs then return end

    for _, seg in ipairs(segs) do
        local segName = seg.name and tostring(seg.name) or nil
        if segName and not db.segmentMeta[segName] then
            db.segmentMeta[segName] = {
                isInstance     = inInstance or false,
                instanceType   = instanceType or "none",
                instanceName   = inInstance and name or nil,
                difficultyName = inInstance and difficultyName or nil,
                difficultyID   = inInstance and difficultyID or nil,
            }
        end
    end
end

-- ============================================================================
-- COMBAT EVENTS
-- ============================================================================

local function OnRegenDisabled()
    if not inCombat then
        inCombat = true
        combatStartTime = GetTime()
        StartRefreshTicker()
        -- Enregistrer le contexte instance pour ce segment
        C_Timer.After(0.5, SaveSegmentMeta)
    end
end

local function OnRegenEnabled()
    C_Timer.After(2, function()
        if not InCombatLockdown() then
            inCombat = false
            local inInstance, instanceType = IsInInstance()
            local keepTicker = inInstance and (instanceType == "party" or instanceType == "raid")
            if not keepTicker then
                StopRefreshTicker()
            end
            RefreshAll()
        end
    end)
end

local function OnEncounterStart()
    inCombat = true
    combatStartTime = GetTime()
    StartRefreshTicker()
    C_Timer.After(0.5, SaveSegmentMeta)
end

local function OnEncounterEnd()
    inCombat = false
    StopRefreshTicker()
    RefreshAll()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function BD:Reset()
    DM:Reset()
    -- Nettoyer les métadonnées de segments
    local db = GetDB()
    if db then db.segmentMeta = {} end
    RefreshAll()
end

function BD:GetSegmentMeta(segName)
    local db = GetDB()
    if not db or not db.segmentMeta then return nil end
    return db.segmentMeta[segName]
end

--- Génère un rapport formaté pour un mode/segment donné.
--- @param mode string "damage"|"healing"
--- @param segId number segment ID (0, -1, ou N)
--- @param maxEntries number|nil nombre max d'entrées (défaut 5)
--- @return table|nil lines liste de strings formatées
function BD:GetReport(mode, segId, maxEntries)
    maxEntries = maxEntries or 5
    local data = DM:GetSorted(mode, segId or 0)
    if not data or #data == 0 then return nil end

    local suffix = (mode == "healing") and "HPS" or "DPS"
    local count = math.min(maxEntries, #data)
    local lines = {}

    for i = 1, count do
        local e = data[i]
        local ok, line = pcall(function()
            return string.format("%d. %s %s (%s %s)",
                i, e.name or "?",
                F.Number(e.value),
                F.Number(e.perSecond or 0),
                suffix)
        end)
        if ok and line then
            lines[#lines + 1] = line
        end
    end

    return #lines > 0 and lines or nil
end

-- ============================================================================
-- TEST DATA
-- ============================================================================

local testActive = false
local testTicker = nil

local TEST_CLASSES = {
    { class = "WARRIOR",     specIcon = 132355,  names = { "Bravkor", "Bladefury", "Ironclad", "Rageborn" } },
    { class = "ROGUE",       specIcon = 236270,  names = { "Shadowmeld", "Ambush", "Nightblade", "Toxin" } },
    { class = "MAGE",        specIcon = 135810,  names = { "Pyroblaster", "Frostbolt", "Arcanist", "Blizzara" } },
    { class = "WARLOCK",     specIcon = 136145,  names = { "Felstorm", "Soulfire", "Doomguard", "Curseweaver" } },
    { class = "DRUID",       specIcon = 136096,  names = { "Moonfire", "Starfall", "Wildgrowth", "Sunbeam" } },
    { class = "SHAMAN",      specIcon = 136048,  names = { "Windfury", "Lavaburn", "Tidecaller", "Stormrage" } },
    { class = "PALADIN",     specIcon = 135873,  names = { "Retribution", "Crusader", "Lightbringer", "Avenger" } },
    { class = "HUNTER",      specIcon = 236179,  names = { "Marksmanship", "Steadyshot", "Beastlord", "Snipeshot" } },
    { class = "PRIEST",      specIcon = 136207,  names = { "Voidform", "Mindblast", "Holypriest", "Discipline" } },
    { class = "DEATHKNIGHT", specIcon = 135773,  names = { "Frostscythe", "Obliterate", "Runekeeper", "Plaguebane" } },
    { class = "MONK",        specIcon = 608940,  names = { "Stormkick", "Tigerpalm", "Zenmaster", "Mistweaver" } },
    { class = "DEMONHUNTER", specIcon = 1247266, names = { "Eyebeam", "Chaostrike", "Felrush", "Havocblade" } },
    { class = "EVOKER",      specIcon = 4622471, names = { "Eternity", "Dreamscale", "Firestorm", "Chronowarden" } },
}

local TEST_CLASSES_HEAL = {
    { class = "DRUID",   specIcon = 136041,  names = { "Restoration", "Lifebinder", "Rejuvenate", "Bloomkeeper" } },
    { class = "PALADIN", specIcon = 135920,  names = { "Holylight", "Lightbeacon", "Divinehand", "Sacredvow" } },
    { class = "PRIEST",  specIcon = 135940,  names = { "Discipline", "Renew", "Penance", "Spiritguard" } },
    { class = "MONK",    specIcon = 608951,  names = { "Mistweaver", "Zenmaster", "Vivify", "Jadegale" } },
    { class = "SHAMAN",  specIcon = 252995,  names = { "Riptide", "Tidecaller", "Healingrain", "Spiritlink" } },
    { class = "EVOKER",  specIcon = 4622472, names = { "Preservation", "Dreamscale", "Emeraldbloom", "Timewarden" } },
}

local function GenerateTestPlayers(templates, count, topValue, topPS)
    local data = {}
    local nTemplates = #templates
    local decay = (topValue - 1000) / (count - 1)
    local decayPS = (topPS - 300) / (count - 1)

    for i = 1, count do
        local tpl = templates[((i - 1) % nTemplates) + 1]
        local nameIdx = math.floor((i - 1) / nTemplates) + 1
        local name = tpl.names[nameIdx] or (tpl.names[1] .. nameIdx)
        local val = math.floor(topValue - (i - 1) * decay)
        local ps = math.floor(topPS - (i - 1) * decayPS)

        data[i] = {
            name      = name,
            guid      = "Player-Test-" .. i,
            class     = tpl.class,
            value     = math.max(100, val),
            perSecond = math.max(30, ps),
            specIcon  = tpl.specIcon,
            isLocal   = (i == 1),
            index     = i,
        }
    end
    return data
end

local function ShuffleTestData(data)
    for _, entry in ipairs(data) do
        local rngV = 1 + (math.random() - 0.5) * 0.30
        local rngP = 1 + (math.random() - 0.5) * 0.30
        entry.value = math.max(100, math.floor(entry.value * rngV))
        entry.perSecond = math.max(30, math.floor(entry.perSecond * rngP))
    end
    table.sort(data, function(a, b) return a.value > b.value end)
    for i, entry in ipairs(data) do
        entry.index = i
    end
end

local function ToggleTestData()
    local Panel = BD.Panel
    local Bars = BD.Bars

    if testActive then
        if testTicker then testTicker:Cancel(); testTicker = nil end
        if Panel and Panel.ClearTestData then Panel.ClearTestData() end
        testActive = false
        RefreshAll()
        BravLib.Print("Mode test |cffff3333d\195\169sactiv\195\169|r.")
    else
        -- S'assurer que le panel existe
        if Panel and Panel.Setup then Panel.Setup() end

        local sessionInfo = {
            duration = 180,
            totalAmount = 1500000,
            maxAmount = 187420,
            name = "Test",
        }

        local dmgData = GenerateTestPlayers(TEST_CLASSES, 50, 187420, 62473)
        local healData = GenerateTestPlayers(TEST_CLASSES_HEAL, 50, 142300, 47433)

        if Panel and Panel.SetTestData then
            Panel.SetTestData(dmgData, healData, sessionInfo)
        end

        testTicker = C_Timer.NewTicker(0.2, function()
            if not testActive then return end
            ShuffleTestData(dmgData)
            ShuffleTestData(healData)
            sessionInfo.duration = sessionInfo.duration + 1
            sessionInfo.totalAmount = sessionInfo.totalAmount + math.random(5000, 15000)
            if Panel and Panel.SetTestData then
                Panel.SetTestData(dmgData, healData, sessionInfo)
            end
        end)

        testActive = true
        BravLib.Print("Mode test |cff33ff33activ\195\169|r — /bd test pour d\195\169sactiver.")
    end
end

local function ToggleTestDataStatic()
    local Panel = BD.Panel

    if testActive then
        if testTicker then testTicker:Cancel(); testTicker = nil end
        if Panel and Panel.ClearTestData then Panel.ClearTestData() end
        testActive = false
        RefreshAll()
    else
        if Panel and Panel.Setup then Panel.Setup() end

        local sessionInfo = {
            duration = 180,
            totalAmount = 1500000,
            maxAmount = 187420,
            name = "Test",
        }

        local dmgData = GenerateTestPlayers(TEST_CLASSES, 50, 187420, 62473)
        local healData = GenerateTestPlayers(TEST_CLASSES_HEAL, 50, 142300, 47433)

        if Panel and Panel.SetTestData then
            Panel.SetTestData(dmgData, healData, sessionInfo)
        end

        testActive = true
    end
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function Meter:Enable()
    local db = GetDB()
    if db.enabled == false then return end

    -- Vérifier que C_DamageMeter existe (Midnight 12.0+)
    if not C_DamageMeter then
        BravLib.Print("|cffff3333C_DamageMeter indisponible.|r")
        return
    end

    -- Combat events
    BravLib.Event.Register("PLAYER_REGEN_DISABLED", OnRegenDisabled)
    BravLib.Event.Register("PLAYER_REGEN_ENABLED", OnRegenEnabled)
    BravLib.Event.Register("ENCOUNTER_START", OnEncounterStart)
    BravLib.Event.Register("ENCOUNTER_END", OnEncounterEnd)

    -- Si déjà en combat au login
    inCombat = InCombatLockdown()
    if inCombat then
        combatStartTime = GetTime()
        StartRefreshTicker()
    end

    -- Setup du panel (délai pour laisser l'UI finir de charger)
    C_Timer.After(2, function()
        if db.enabled == false then return end

        local Panel = BD.Panel
        if Panel and Panel.Setup then
            Panel.Setup()
        end

        -- Initial refresh
        RefreshAll()
    end)
end

function Meter:Disable()
    StopRefreshTicker()
    BravLib.Event.Unregister("PLAYER_REGEN_DISABLED", OnRegenDisabled)
    BravLib.Event.Unregister("PLAYER_REGEN_ENABLED", OnRegenEnabled)
    BravLib.Event.Unregister("ENCOUNTER_START", OnEncounterStart)
    BravLib.Event.Unregister("ENCOUNTER_END", OnEncounterEnd)

    local Panel = BD.Panel
    if Panel and Panel.Hide then Panel.Hide() end
end

function Meter:Refresh()
    local Panel = BD.Panel
    if Panel and Panel.Refresh then Panel.Refresh() end
end

-- ============================================================================
-- SLASH COMMANDS (enregistrés dans Init.lua, dispatch ici)
-- ============================================================================

function BD:HandleSlash(msg)
    msg = (msg or ""):lower():trim()

    if msg == "test" then
        ToggleTestData()

    elseif msg == "testfix" then
        ToggleTestDataStatic()

    elseif msg == "reset" then
        self:Reset()
        BravLib.Print("Reset.")

    elseif msg == "toggle" then
        local Panel = self.Panel
        if Panel and Panel.Toggle then Panel.Toggle() end

    elseif msg == "current" then
        local Panel = self.Panel
        if Panel and Panel.SetSegment then Panel.SetSegment(0) end

    elseif msg == "overall" then
        local Panel = self.Panel
        if Panel and Panel.SetSegment then Panel.SetSegment(-1) end

    elseif msg == "report" or msg == "report dmg" or msg == "report damage" then
        local Panel = self.Panel
        local segId = Panel and Panel.GetSegmentId and Panel.GetSegmentId() or 0
        local lines = self:GetReport("damage", segId, 10)
        if not lines then
            BravLib.Print("Aucune donn\195\169e DPS.")
            return
        end
        print("|cFF00FFFFBravUI|r — D\195\169g\195\162ts (top " .. #lines .. "):")
        for _, line in ipairs(lines) do print("  " .. line) end

    elseif msg == "report heal" or msg == "report healing" then
        local Panel = self.Panel
        local segId = Panel and Panel.GetSegmentId and Panel.GetSegmentId() or 0
        local lines = self:GetReport("healing", segId, 10)
        if not lines then
            BravLib.Print("Aucune donn\195\169e HPS.")
            return
        end
        print("|cFF00FFFFBravUI|r — Soins (top " .. #lines .. "):")
        for _, line in ipairs(lines) do print("  " .. line) end

    elseif msg == "mplus" then
        local MPlus = self.MPlus
        if MPlus and MPlus.ShowSummary then MPlus:ShowSummary() end

    elseif msg == "mplus test" then
        local MPlus = self.MPlus
        if MPlus then
            MPlus:GenerateTestRun()
            MPlus:ShowSummary()
            BravLib.Print("Summary M+ test affich\195\169.")
        end

    elseif msg == "timer" then
        local Timer = self.Timer
        if Timer and Timer.Toggle then Timer:Toggle() end

    elseif msg == "timer test" then
        local Timer = self.Timer
        if Timer and Timer.ShowTest then
            Timer:ShowTest()
            BravLib.Print("Timer M+ test affich\195\169.")
        end

    else
        BravLib.Print("Commandes:")
        print("  /bd test — Barres de test (toggle)")
        print("  /bd reset — Reset les donn\195\169es")
        print("  /bd toggle — Afficher/masquer les fen\195\170tres")
        print("  /bd current — Segment en cours")
        print("  /bd overall — Segment overall")
        print("  /bd report — Rapport DPS")
        print("  /bd report heal — Rapport HPS")
        print("  /bd mplus — Afficher le summary M+")
        print("  /bd mplus test — Summary M+ avec donn\195\169es test")
        print("  /bd timer — Afficher/masquer le timer M+")
        print("  /bd timer test — Timer M+ avec donn\195\169es test")
    end
end

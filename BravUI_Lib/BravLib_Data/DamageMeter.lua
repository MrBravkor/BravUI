local BravLib = BravLib

-- ============================================================================
-- BravLib.DamageMeter — Wrapper C_DamageMeter (Midnight 12.0+)
-- Fournit GetSorted(), GetSpellBreakdown(), GetSegments(), GetSessionInfo(), Reset()
-- Secret-safe : pcall pour l'arithmétique et les comparaisons
-- ============================================================================

BravLib.DamageMeter = {}
local DM = BravLib.DamageMeter

-- ============================================================================
-- ENUMS (initialisés au premier appel)
-- ============================================================================

local MODE_TO_TYPE = nil
local SESSION_CURRENT = nil
local SESSION_OVERALL = nil
local enumsReady = false

local function InitEnums()
    if enumsReady then return true end
    if not Enum or not Enum.DamageMeterType or not Enum.DamageMeterSessionType then
        return false
    end

    MODE_TO_TYPE = {
        damage      = Enum.DamageMeterType.DamageDone,
        damageTaken = Enum.DamageMeterType.DamageTaken,
        healing     = Enum.DamageMeterType.HealingDone,
        interrupts  = Enum.DamageMeterType.Interrupts,
        dispels     = Enum.DamageMeterType.Dispels,
        avoidable   = Enum.DamageMeterType.AvoidableDamageTaken,
    }
    SESSION_CURRENT = Enum.DamageMeterSessionType.Current
    SESSION_OVERALL = Enum.DamageMeterSessionType.Overall

    enumsReady = true
    return true
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function IsAvailable()
    return C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and true or false
end

local function GetSpellName(spellID)
    if not spellID then return "?" end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and name then return name end
    end
    return "?"
end

local function GetSession(segmentId, dmType)
    if not IsAvailable() or not InitEnums() then return nil end

    if segmentId == 0 then
        return C_DamageMeter.GetCombatSessionFromType(SESSION_CURRENT, dmType)
    elseif segmentId == -1 then
        return C_DamageMeter.GetCombatSessionFromType(SESSION_OVERALL, dmType)
    else
        local sessions = C_DamageMeter.GetAvailableCombatSessions()
        if sessions and sessions[segmentId] then
            return C_DamageMeter.GetCombatSessionFromID(sessions[segmentId].sessionID, dmType)
        end
    end
    return nil
end

-- ============================================================================
-- API PUBLIQUE
-- ============================================================================

--- Vérifie si C_DamageMeter est disponible (Midnight 12.0+)
--- @return boolean
function DM:IsAvailable()
    return IsAvailable() and InitEnums()
end

--- Retourne la liste triée des joueurs pour un mode/segment.
--- Chaque entrée: {name, guid, class, value, perSecond, specIcon, isLocal, index}
--- name/guid/value/perSecond peuvent être SECRET en combat.
--- @param mode string "damage"|"healing"|"damageTaken"|"interrupts"|"dispels"|"avoidable"
--- @param segmentId number 0=current, -1=overall, N=historique
--- @return table data, table|nil session
function DM:GetSorted(mode, segmentId)
    if not IsAvailable() or not InitEnums() then return {} end

    local dmType = MODE_TO_TYPE[mode] or MODE_TO_TYPE.damage
    local session = GetSession(segmentId or 0, dmType)
    if not session or not session.combatSources then return {}, nil end

    local result = {}
    for i, src in ipairs(session.combatSources) do
        result[i] = {
            name      = src.name,
            guid      = src.sourceGUID,
            class     = src.classFilename,
            value     = src.totalAmount,
            perSecond = src.amountPerSecond,
            specIcon  = src.specIconID,
            isLocal   = src.isLocalPlayer,
            index     = i,
        }
    end

    return result, session
end

--- Retourne le breakdown de sorts pour un joueur.
--- guid peut être SECRET — C_DamageMeter accepte ses propres secrets.
--- @param guid any GUID du joueur (peut être secret)
--- @param mode string
--- @param segmentId number
--- @return table spells
function DM:GetSpellBreakdown(guid, mode, segmentId)
    if not IsAvailable() or not guid then return {} end
    if not InitEnums() then return {} end

    local dmType = MODE_TO_TYPE[mode] or MODE_TO_TYPE.damage
    local spellContainer

    local ok
    if segmentId == 0 then
        ok, spellContainer = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
            SESSION_CURRENT, dmType, guid)
        if not ok then spellContainer = nil end
    elseif segmentId == -1 then
        ok, spellContainer = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
            SESSION_OVERALL, dmType, guid)
        if not ok then spellContainer = nil end
    else
        local sessions = C_DamageMeter.GetAvailableCombatSessions()
        if sessions and sessions[segmentId] then
            ok, spellContainer = pcall(C_DamageMeter.GetCombatSessionSourceFromID,
                sessions[segmentId].sessionID, dmType, guid)
            if not ok then spellContainer = nil end
        end
    end

    if not spellContainer or not spellContainer.combatSpells then return {} end

    local result = {}

    local function FindGroup(sid)
        for _, g in ipairs(result) do
            local match = false
            pcall(function()
                if g.spellID == sid then match = true end
            end)
            if match then return g end
        end
        return nil
    end

    for _, spell in ipairs(spellContainer.combatSpells) do
        local sid = spell.spellID
        local group = FindGroup(sid)

        if not group then
            group = {
                spellID   = sid,
                name      = GetSpellName(sid),
                value     = spell.totalAmount,
                perSecond = spell.amountPerSecond,
                overkill  = spell.overkillAmount,
                details   = spell.combatSpellDetails,
            }
            result[#result + 1] = group
        else
            pcall(function() group.value = group.value + spell.totalAmount end)
            pcall(function() group.perSecond = group.perSecond + spell.amountPerSecond end)
            pcall(function() group.overkill = group.overkill + (spell.overkillAmount or 0) end)
        end
    end

    pcall(function()
        table.sort(result, function(a, b) return a.value > b.value end)
    end)

    return result
end

--- Liste des sessions expirées (historiques).
--- @return table sessions [{sessionID, name, durationSeconds}]
function DM:GetSegments()
    if not IsAvailable() then return {} end
    return C_DamageMeter.GetAvailableCombatSessions() or {}
end

--- Infos d'une session (durée, total, nom).
--- @param segmentId number
--- @param mode string
--- @return table|nil info {duration, totalAmount, maxAmount, name}
function DM:GetSessionInfo(segmentId, mode)
    if not IsAvailable() or not InitEnums() then return nil end

    local dmType = MODE_TO_TYPE[mode] or MODE_TO_TYPE.damage
    local session = GetSession(segmentId or 0, dmType)
    if not session then return nil end

    return {
        duration    = session.durationSeconds,
        totalAmount = session.totalAmount,
        maxAmount   = session.maxAmount,
        name        = session.name,
    }
end

--- Reset toutes les sessions C_DamageMeter.
function DM:Reset()
    if IsAvailable() and C_DamageMeter.ResetAllCombatSessions then
        C_DamageMeter.ResetAllCombatSessions()
    end
end

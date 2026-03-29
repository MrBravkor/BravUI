local BravLib = BravLib

BravLib.Storage = {}

local Storage = BravLib.Storage

-- ============================================================================
-- LOCALS
-- ============================================================================

local db           = nil   -- reference vers BravUI_DB (root)
local activeDB     = nil   -- reference vers le profil actif (ce que GetDB retourne)
local defaults     = {}
local charKey      = nil   -- "Name - Realm", resolu apres PLAYER_LOGIN

local DB_VERSION = 2

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetCharKey()
    if charKey then return charKey end
    local ok, key = pcall(function()
        return UnitName("player") .. " - " .. GetRealmName()
    end)
    if ok and key and key ~= " - " and key ~= "Unknown - Unknown" then
        charKey = key
    end
    return charKey
end

local function EnsureMeta()
    db._meta = db._meta or {}
    db._meta.version = DB_VERSION
    db._meta.activeProfile = db._meta.activeProfile or "Default"
    db._meta.charProfiles = db._meta.charProfiles or {}
    db._meta.specProfiles = db._meta.specProfiles or {}
    db._meta.useSpecProfiles = db._meta.useSpecProfiles or {}
    db._meta.roleProfiles = db._meta.roleProfiles or {}   -- { charKey = { TANK="x", HEALER="y", DAMAGER="z" } }
    db._meta.useRoleProfiles = db._meta.useRoleProfiles or {}
    -- profileMode: "global" (all chars share one profile) or "perChar" (each char gets its own)
    -- nil = not yet chosen (wizard needed)
    db._meta.globalProfileName = db._meta.globalProfileName or "Default"
end

local function EnsureProfiles()
    db.profiles = db.profiles or {}
end

local function EnsureGlobal()
    db.global = db.global or {}
end

local function ProfileExists(name)
    return db.profiles and db.profiles[name] ~= nil
end

local function ResolveActiveProfileName()
    local mode = db._meta.profileMode

    -- Mode global : tout le monde utilise le meme profil
    if mode == "global" then
        return db._meta.globalProfileName or "Default"
    end

    -- Mode perChar (ou nil/pas encore choisi) : mapping par personnage
    local key = GetCharKey()
    if key and db._meta.charProfiles[key] then
        return db._meta.charProfiles[key]
    end

    return db._meta.activeProfile or "Default"
end

local function SetActiveDB()
    local name = ResolveActiveProfileName()
    if not ProfileExists(name) then
        db.profiles[name] = BravLib.CopyTable(defaults)
    end
    activeDB = db.profiles[name]
end

-- ============================================================================
-- MIGRATION (flat DB → profils)
-- ============================================================================

local function MigrateFromFlat()
    if db._meta then return false end

    BravLib.Debug("Storage: migrating flat DB to profiles")

    local flatData = {}
    local globalData = db.global or {}

    -- extraire toutes les cles de config (pas _meta, profiles, global)
    for k, v in pairs(db) do
        if k ~= "_meta" and k ~= "profiles" and k ~= "global" then
            flatData[k] = v
        end
    end

    -- nettoyer les cles flat de la racine
    for k in pairs(flatData) do
        db[k] = nil
    end
    db.global = nil

    -- construire la nouvelle structure
    EnsureMeta()
    EnsureProfiles()
    EnsureGlobal()

    -- restaurer les donnees globales
    for k, v in pairs(globalData) do
        db.global[k] = v
    end

    -- creer le profil Default avec les anciennes donnees
    local profileData = BravLib.CopyTable(defaults)
    BravLib.TableMerge(profileData, flatData)
    db.profiles["Default"] = profileData

    -- assigner le char actuel au profil Default
    local key = GetCharKey()
    if key then
        db._meta.charProfiles[key] = "Default"
    end

    BravLib.Debug("Storage: migration complete")
    return true
end

-- ============================================================================
-- INIT
-- ============================================================================

function Storage.Init(defaultsTable)
    defaults = defaultsTable or {}

    if type(BravUI_DB) ~= "table" then
        BravUI_DB = {}
    end
    db = BravUI_DB

    -- migration si format ancien (flat)
    MigrateFromFlat()

    -- s'assurer que la structure existe
    EnsureMeta()
    EnsureProfiles()
    EnsureGlobal()

    -- creer le profil Default s'il n'existe pas
    if not ProfileExists("Default") then
        db.profiles["Default"] = BravLib.CopyTable(defaults)
    end

    -- merger les defaults dans chaque profil existant (nouvelles cles)
    for name, profile in pairs(db.profiles) do
        BravLib.TableMerge(profile, defaults)
    end

    -- resoudre le profil actif
    SetActiveDB()

    BravLib.Debug("Storage initialized (profile: " .. ResolveActiveProfileName() .. ")")
end

-- ============================================================================
-- ACCESSEURS DE BASE
-- ============================================================================

function Storage.GetDB()
    return activeDB
end

function Storage.GetGlobal()
    return db and db.global or {}
end

function Storage.GetMeta()
    return db and db._meta or {}
end

function Storage.GetDefaults()
    return BravLib.CopyTable(defaults)
end

function Storage.GetRawDB()
    return db
end

-- ============================================================================
-- GESTION DES PROFILS
-- ============================================================================

function Storage.GetActiveProfileName()
    return ResolveActiveProfileName()
end

function Storage.GetProfileList()
    local list = {}
    if db and db.profiles then
        for name in pairs(db.profiles) do
            list[#list + 1] = name
        end
    end
    table.sort(list)
    return list
end

function Storage.SetActiveProfile(name)
    if not ProfileExists(name) then
        BravLib.Warn("Storage: profile '" .. tostring(name) .. "' does not exist")
        return false
    end

    local key = GetCharKey()
    if key then
        db._meta.charProfiles[key] = name
    end
    db._meta.activeProfile = name

    SetActiveDB()
    BravLib.Hooks.Fire("PROFILE_CHANGED", name)
    BravLib.Debug("Storage: switched to profile '" .. name .. "'")
    return true
end

function Storage.CreateProfile(name, copyFrom)
    if not name or name == "" then return false end
    if ProfileExists(name) then
        BravLib.Warn("Storage: profile '" .. name .. "' already exists")
        return false
    end

    if copyFrom and ProfileExists(copyFrom) then
        db.profiles[name] = BravLib.CopyTable(db.profiles[copyFrom])
    else
        db.profiles[name] = BravLib.CopyTable(defaults)
    end

    BravLib.Debug("Storage: created profile '" .. name .. "'")
    return true
end

function Storage.DeleteProfile(name)
    if not ProfileExists(name) then return false end

    -- compter les profils
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if count <= 1 then
        BravLib.Warn("Storage: cannot delete the last profile")
        return false
    end

    -- si c'est le profil actif, switcher vers un autre
    local activeName = ResolveActiveProfileName()
    if activeName == name then
        for other in pairs(db.profiles) do
            if other ~= name then
                Storage.SetActiveProfile(other)
                break
            end
        end
    end

    -- nettoyer les references dans charProfiles
    for k, v in pairs(db._meta.charProfiles) do
        if v == name then
            db._meta.charProfiles[k] = ResolveActiveProfileName()
        end
    end

    -- nettoyer les references dans specProfiles
    for k, specs in pairs(db._meta.specProfiles) do
        for specIdx, profName in pairs(specs) do
            if profName == name then
                specs[specIdx] = nil
            end
        end
    end

    db.profiles[name] = nil
    BravLib.Debug("Storage: deleted profile '" .. name .. "'")
    return true
end

function Storage.CopyProfile(from, to)
    if not ProfileExists(from) then return false end
    if not to or to == "" then return false end
    if ProfileExists(to) then
        BravLib.Warn("Storage: profile '" .. to .. "' already exists")
        return false
    end

    db.profiles[to] = BravLib.CopyTable(db.profiles[from])
    BravLib.Debug("Storage: copied '" .. from .. "' → '" .. to .. "'")
    return true
end

function Storage.RenameProfile(old, new)
    if not ProfileExists(old) then return false end
    if not new or new == "" then return false end
    if ProfileExists(new) then
        BravLib.Warn("Storage: profile '" .. new .. "' already exists")
        return false
    end

    db.profiles[new] = db.profiles[old]
    db.profiles[old] = nil

    -- mettre a jour les references
    if db._meta.activeProfile == old then
        db._meta.activeProfile = new
    end
    for k, v in pairs(db._meta.charProfiles) do
        if v == old then db._meta.charProfiles[k] = new end
    end
    for k, specs in pairs(db._meta.specProfiles) do
        for specIdx, profName in pairs(specs) do
            if profName == old then specs[specIdx] = new end
        end
    end

    -- re-resoudre si on a renomme le profil actif
    SetActiveDB()
    BravLib.Debug("Storage: renamed '" .. old .. "' → '" .. new .. "'")
    return true
end

function Storage.ResetProfile(name)
    name = name or ResolveActiveProfileName()
    if not ProfileExists(name) then return false end

    wipe(db.profiles[name])
    BravLib.TableMerge(db.profiles[name], BravLib.CopyTable(defaults))

    -- rafraichir si c'est le profil actif
    if name == ResolveActiveProfileName() then
        SetActiveDB()
        BravLib.Hooks.Fire("PROFILE_CHANGED", name)
    end

    BravLib.Debug("Storage: reset profile '" .. name .. "' to defaults")
    return true
end

function Storage.Reset()
    Storage.ResetProfile(ResolveActiveProfileName())
end

-- ============================================================================
-- PER-SPEC
-- ============================================================================

function Storage.SetSpecProfile(specIndex, profileName)
    local key = GetCharKey()
    if not key then return false end

    db._meta.specProfiles[key] = db._meta.specProfiles[key] or {}
    db._meta.specProfiles[key][specIndex] = profileName
    BravLib.Debug("Storage: spec " .. specIndex .. " → profile '" .. tostring(profileName) .. "'")
    return true
end

function Storage.GetSpecProfile(specIndex)
    local key = GetCharKey()
    if not key then return nil end
    local specs = db._meta.specProfiles[key]
    return specs and specs[specIndex] or nil
end

-- ============================================================================
-- PROFILE MODE (global vs perChar)
-- ============================================================================

function Storage.GetProfileMode()
    return db and db._meta and db._meta.profileMode or nil
end

function Storage.SetProfileMode(mode)
    if mode ~= "global" and mode ~= "perChar" then return end
    db._meta.profileMode = mode

    if mode == "global" then
        -- en mode global, on s'assure que le profil global existe
        local gp = db._meta.globalProfileName or "Default"
        if not ProfileExists(gp) then
            db.profiles[gp] = BravLib.CopyTable(defaults)
        end
    end

    SetActiveDB()
    BravLib.Hooks.Fire("PROFILE_CHANGED", ResolveActiveProfileName())
    BravLib.Debug("Storage: profile mode set to '" .. mode .. "'")
end

function Storage.GetGlobalProfileName()
    return db and db._meta and db._meta.globalProfileName or "Default"
end

function Storage.SetGlobalProfileName(name)
    if not ProfileExists(name) then return false end
    db._meta.globalProfileName = name
    if db._meta.profileMode == "global" then
        SetActiveDB()
        BravLib.Hooks.Fire("PROFILE_CHANGED", name)
    end
    return true
end

--- Auto-assign profile for a new character based on current profileMode.
-- Called at PLAYER_LOGIN when the char has no mapping yet.
-- Returns true if this char was already known, false if it's new.
function Storage.AutoAssignNewChar()
    local key = GetCharKey()
    if not key then return true end -- can't resolve yet

    -- char already has a mapping → nothing to do
    if db._meta.charProfiles[key] then return true end

    local mode = db._meta.profileMode

    if mode == "global" then
        -- assign the global profile
        local gp = db._meta.globalProfileName or "Default"
        db._meta.charProfiles[key] = gp
        SetActiveDB()
        BravLib.Debug("Storage: new char '" .. key .. "' → global profile '" .. gp .. "'")
        return false

    elseif mode == "perChar" then
        -- create a personal profile copied from Default
        if not ProfileExists(key) then
            Storage.CreateProfile(key, "Default")
        end
        db._meta.charProfiles[key] = key
        SetActiveDB()
        BravLib.Debug("Storage: new char '" .. key .. "' → personal profile")
        return false
    end

    -- mode == nil → first install, wizard needed
    return false
end

-- ============================================================================
-- PER-SPEC
-- ============================================================================

function Storage.SetUseSpecProfiles(enabled)
    local key = GetCharKey()
    if not key then return end
    db._meta.useSpecProfiles[key] = enabled or nil
end

function Storage.GetUseSpecProfiles()
    local key = GetCharKey()
    if not key then return false end
    return db._meta.useSpecProfiles[key] == true
end

-- ============================================================================
-- PER-ROLE
-- ============================================================================

function Storage.SetRoleProfile(role, profileName)
    local key = GetCharKey()
    if not key then return false end
    db._meta.roleProfiles[key] = db._meta.roleProfiles[key] or {}
    db._meta.roleProfiles[key][role] = profileName
    BravLib.Debug("Storage: role " .. role .. " → profile '" .. tostring(profileName) .. "'")
    return true
end

function Storage.GetRoleProfile(role)
    local key = GetCharKey()
    if not key then return nil end
    local roles = db._meta.roleProfiles[key]
    return roles and roles[role] or nil
end

function Storage.SetUseRoleProfiles(enabled)
    local key = GetCharKey()
    if not key then return end
    db._meta.useRoleProfiles[key] = enabled or nil
end

function Storage.GetUseRoleProfiles()
    local key = GetCharKey()
    if not key then return false end
    return db._meta.useRoleProfiles[key] == true
end

-- ============================================================================
-- SPEC/ROLE CHANGE HANDLER
-- ============================================================================

local function OnSpecChanged()
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if not specIndex then return end

    local targetProfile = nil

    -- per-role a la priorite sur per-spec
    if Storage.GetUseRoleProfiles() then
        local role = GetSpecializationRole and GetSpecializationRole(specIndex) or nil
        if role then
            targetProfile = Storage.GetRoleProfile(role)
        end
    elseif Storage.GetUseSpecProfiles() then
        targetProfile = Storage.GetSpecProfile(specIndex)
    end

    if not targetProfile then return end
    if not ProfileExists(targetProfile) then return end

    local current = ResolveActiveProfileName()
    if current == targetProfile then return end

    Storage.SetActiveProfile(targetProfile)
    BravLib.Print("Profil switch: " .. targetProfile)
end

-- ============================================================================
-- IMPORT / EXPORT (fonctions de base, Serialize.lua fournit l'encodage)
-- ============================================================================

local EXPORT_PREFIX = "BravUI"
local EXPORT_VERSION = 1

function Storage.ExportProfile(name)
    name = name or ResolveActiveProfileName()
    if not ProfileExists(name) then return nil end

    if not BravLib.Serialize then
        BravLib.Warn("Storage: Serialize module not loaded")
        return nil
    end

    local data = BravLib.CopyTable(db.profiles[name])
    local serialized = BravLib.Serialize(data)
    local compressed = BravLib.Compress(serialized)
    local encoded = BravLib.Base64Encode(compressed)
    return EXPORT_PREFIX .. ":" .. EXPORT_VERSION .. ":" .. encoded
end

function Storage.ImportProfile(name, importString)
    if not name or name == "" then return false, "invalid name" end
    if not importString or importString == "" then return false, "empty string" end

    if not BravLib.Deserialize then
        BravLib.Warn("Storage: Serialize module not loaded")
        return false, "serialize module missing"
    end

    -- parser le header BravUI:version:data
    local prefix, versionStr, encoded = importString:match("^(%w+):(%d+):(.+)$")

    if prefix ~= EXPORT_PREFIX then
        BravLib.Warn("Storage: not a BravUI export string")
        return false, "not a BravUI export"
    end

    local version = tonumber(versionStr)
    if not version or version > EXPORT_VERSION then
        BravLib.Warn("Storage: unsupported export version " .. tostring(versionStr))
        return false, "unsupported version"
    end

    local decoded = BravLib.Base64Decode(encoded)
    if not decoded then
        BravLib.Warn("Storage: invalid import data (base64)")
        return false, "invalid base64"
    end

    local decompressed = BravLib.Decompress(decoded)
    if not decompressed then
        BravLib.Warn("Storage: invalid import data (decompress)")
        return false, "invalid compressed data"
    end

    local ok, data = pcall(BravLib.Deserialize, decompressed)
    if not ok or type(data) ~= "table" then
        BravLib.Warn("Storage: invalid import data (deserialize)")
        return false, "invalid data"
    end

    -- merger avec les defaults pour s'assurer que toutes les cles existent
    local profileData = BravLib.CopyTable(defaults)
    BravLib.TableMerge(profileData, data)

    if ProfileExists(name) then
        wipe(db.profiles[name])
        db.profiles[name] = profileData
    else
        db.profiles[name] = profileData
    end

    BravLib.Debug("Storage: imported profile '" .. name .. "'")
    return true
end

-- ============================================================================
-- EVENT REGISTRATION (per-spec)
-- ============================================================================

local function RegisterSpecEvent()
    if BravLib.Event and BravLib.Event.Register then
        BravLib.Event.Register("ACTIVE_TALENT_GROUP_CHANGED", OnSpecChanged)
        BravLib.Event.Register("PLAYER_SPECIALIZATION_CHANGED", OnSpecChanged)
    end
end

-- appeler apres Init pour etre sur que BravLib.Event existe
local function TryAutoAssign()
    GetCharKey()
    if not charKey then return false end
    if not db then return false end

    local isNew = not Storage.AutoAssignNewChar()
    SetActiveDB()

    if isNew then
        BravLib.Hooks.Fire("PROFILE_CHANGED", ResolveActiveProfileName())
    end
    return true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    RegisterSpecEvent()
    self:UnregisterAllEvents()

    -- tenter l'auto-assign immediatement
    if TryAutoAssign() then return end

    -- si charKey pas encore dispo, retry avec un court delai
    local retries = 0
    local ticker
    ticker = C_Timer.NewTicker(0.5, function()
        retries = retries + 1
        if TryAutoAssign() or retries >= 10 then
            ticker:Cancel()
        end
    end)
end)

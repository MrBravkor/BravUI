-- BravUI — Configuration & profils (système maison, sans dépendance)
--
-- Modèle : des profils nommés, une affectation par « contexte ». Le contexte
-- est le personnage, ou le personnage+spécialisation si l'option perSpec est
-- active pour ce personnage. ns.db pointe toujours vers le profil actif
-- (fusionné avec les valeurs par défaut).
--
-- La base ne connaît AUCUN module : chaque module contribue ses propres
-- réglages par défaut via ns.Config:RegisterDefaults("clé", { ... }) lors de
-- son chargement.
--
-- Structure de BravUIDB :
--   profiles    = { [nomProfil] = { ... réglages ... } }
--   assignments = { [cléContexte] = nomProfil }
--   options     = { perSpec = { [cléPerso] = true } }
--   version     = <schéma>

local addonName, ns = ...

local Config = {}
ns.Config = Config

-- Version de schéma (pour d'éventuelles migrations futures).
local DB_VERSION = 1

-- Registre des valeurs par défaut, alimenté par les modules (voir
-- RegisterDefaults). Vide tant qu'aucun module n'est chargé.
local defaults = {}
Config.defaults = defaults

--------------------------------------------------------------------------------
-- Helpers internes
--------------------------------------------------------------------------------
-- Remplit récursivement dst avec les clés manquantes de src (sans écraser
-- les valeurs déjà réglées par l'utilisateur).
local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return name .. " - " .. realm
end

local function GetActiveSpecID()
    local index = GetSpecialization and GetSpecialization()
    if not index then return 0 end
    local id = GetSpecializationInfo(index)
    return id or 0
end

-- Clé de contexte : personnage seul, ou personnage+spé si perSpec actif.
local function GetContextKey(root)
    local charKey = GetCharKey()
    if root.options.perSpec[charKey] then
        return charKey .. " @spec:" .. GetActiveSpecID()
    end
    return charKey
end

--------------------------------------------------------------------------------
-- Défauts contribués par les modules
--------------------------------------------------------------------------------
-- Appelé au chargement d'un module (avant Initialize). Si la config est déjà
-- prête (module chargé à chaud, cas rare), on refusionne dans le profil actif.
function Config:RegisterDefaults(key, tbl)
    defaults[key] = tbl
    if self.root and ns.db then
        CopyDefaults(ns.db, defaults)
    end
end

--------------------------------------------------------------------------------
-- Initialisation (appelée à ADDON_LOADED)
--------------------------------------------------------------------------------
function Config:Initialize()
    -- BravUIDB est déclaré via "## SavedVariables" dans le .toc.
    BravUIDB = BravUIDB or {}
    local root = BravUIDB
    root.version     = root.version or DB_VERSION
    root.profiles    = root.profiles or {}
    root.assignments = root.assignments or {}
    root.options     = root.options or {}
    root.options.perSpec = root.options.perSpec or {}

    self.root = root

    -- Applique le profil actif -> renseigne ns.db.
    self:ApplyActiveProfile(true)

    -- Recharge le profil quand la spé change (utile si perSpec actif).
    ns.EventBus:Register("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit == "player" then
            self:ApplyActiveProfile(false)
        end
    end)
end

--------------------------------------------------------------------------------
-- Profil actif
--------------------------------------------------------------------------------
function Config:GetActiveProfileName()
    local root = self.root
    local key = GetContextKey(root)
    return (root.assignments[key] or "Default"), key
end

-- (Re)calcule le profil actif et met à jour ns.db. Si initial est faux, notifie
-- les modules pour qu'ils se rafraîchissent.
function Config:ApplyActiveProfile(initial)
    local root = self.root
    local profileName, contextKey = self:GetActiveProfileName()

    root.assignments[contextKey] = profileName          -- persiste l'affectation
    root.profiles[profileName] = root.profiles[profileName] or {}
    local profile = root.profiles[profileName]
    CopyDefaults(profile, defaults)                     -- garantit toutes les clés

    self.activeName = profileName
    ns.db = profile                                     -- table lue par les modules

    if not initial then
        ns:RefreshModules()
    end
end

--------------------------------------------------------------------------------
-- API de gestion (utilisée par le slash, et plus tard par une UI d'options)
--------------------------------------------------------------------------------
function Config:GetProfiles()
    local out = {}
    for name in pairs(self.root.profiles) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- Affecte un profil (créé si besoin) au contexte courant.
function Config:SetProfile(name)
    local _, contextKey = self:GetActiveProfileName()
    self.root.assignments[contextKey] = name
    self.root.profiles[name] = self.root.profiles[name] or {}
    self:ApplyActiveProfile(false)
end

-- Réinitialise le profil actif aux valeurs par défaut.
function Config:ResetActiveProfile()
    self.root.profiles[self.activeName] = {}
    self:ApplyActiveProfile(false)
end

-- Active/désactive la séparation par spécialisation pour ce personnage.
function Config:SetPerSpec(enabled)
    local charKey = GetCharKey()
    self.root.options.perSpec[charKey] = enabled and true or nil
    self:ApplyActiveProfile(false)
end

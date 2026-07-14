-- BravUI — Cœur / Initialisation
-- Établit le namespace privé, le registre de modules et le cycle de vie.
-- Aucune dépendance externe.

local addonName, ns = ...

-- Seules globales exposées : BravUI (débogage / slash) et BravUIDB (SavedVariables).
_G.BravUI = ns

ns.name = addonName
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "dev"

--------------------------------------------------------------------------------
-- Affichage console
--------------------------------------------------------------------------------
local PREFIX = "|cff00ccffBravUI|r: "
function ns:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = tostring(msg):format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

--------------------------------------------------------------------------------
-- Registre de modules
-- Un module = une table avec, en option : OnInitialize / OnEnable / OnDisable /
-- OnProfileChanged. Le cœur les orchestre. Ajouter un module = 1 fichier +
-- 1 appel à ns:RegisterModule, sans toucher au cœur.
--------------------------------------------------------------------------------
ns.modules = {}
ns.moduleOrder = {}

function ns:RegisterModule(name, module)
    assert(type(name) == "string", "RegisterModule : nom invalide")
    assert(not self.modules[name], "RegisterModule : module déjà enregistré : " .. name)
    module = module or {}
    module.name = name
    module.enabled = false
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
    return module
end

function ns:GetModule(name)
    return self.modules[name]
end

function ns:EnableModule(name)
    local m = self.modules[name]
    if not m or m.enabled then return end
    m.enabled = true
    if m.OnEnable then
        -- Une erreur dans un module ne doit pas casser le cœur.
        local ok, err = pcall(m.OnEnable, m)
        if not ok then
            m.enabled = false
            self:Print("Erreur à l'activation du module '%s' : %s", name, err)
        end
    end
end

function ns:DisableModule(name)
    local m = self.modules[name]
    if not m or not m.enabled then return end
    m.enabled = false
    if m.OnDisable then m:OnDisable() end
end

-- Propage un changement de profil actif à tous les modules activés.
function ns:RefreshModules()
    for i = 1, #self.moduleOrder do
        local m = self.modules[self.moduleOrder[i]]
        if m.enabled and m.OnProfileChanged then
            m:OnProfileChanged()
        end
    end
end

--------------------------------------------------------------------------------
-- Cycle de vie (bootstrap autonome, indépendant de l'EventBus)
--------------------------------------------------------------------------------
local function OnAddonLoaded()
    -- SavedVariables disponibles : on prépare la config, puis on initialise.
    ns.Config:Initialize()
    for i = 1, #ns.moduleOrder do
        local m = ns.modules[ns.moduleOrder[i]]
        if m.OnInitialize then
            local ok, err = pcall(m.OnInitialize, m)
            if not ok then ns:Print("Erreur OnInitialize '%s' : %s", m.name, err) end
        end
    end
end

local function OnPlayerLogin()
    for i = 1, #ns.moduleOrder do
        ns:EnableModule(ns.moduleOrder[i])
    end
    -- Message de bienvenue en jeu (une fois par connexion / reload).
    ns:Print(ns.L["LOGIN"], ns.version)
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        OnPlayerLogin()
    end
end)

--------------------------------------------------------------------------------
-- Commande slash
--------------------------------------------------------------------------------
SLASH_BRAV1 = "/brav"
SlashCmdList["BRAV"] = function(input)
    input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local L = ns.L
    if input == "reset" then
        ns.Config:ResetActiveProfile()
        ns:Print(L["PROFILE_RESET"])
    elseif input == "perspec on" then
        ns.Config:SetPerSpec(true)
        ns:Print(L["PERSPEC_ON"])
    elseif input == "perspec off" then
        ns.Config:SetPerSpec(false)
        ns:Print(L["PERSPEC_OFF"])
    elseif input == "profile" then
        ns:Print(L["PROFILE_CURRENT"], ns.Config.activeName or "?")
    else
        ns:Print(L["HELP_HEADER"], ns.version)
        ns:Print(L["HELP_PROFILE"])
        ns:Print(L["HELP_PERSPEC"])
        ns:Print(L["HELP_RESET"])
    end
end

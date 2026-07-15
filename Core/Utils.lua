-- BravUI — Utilitaires partagés

local addonName, ns = ...

local U = {}
ns.Utils = U

--------------------------------------------------------------------------------
-- Couleurs
--------------------------------------------------------------------------------
-- Couleur de classe d'un joueur (retail : C_ClassColor / RAID_CLASS_COLORS).
function U.GetClassColor(unit)
    local _, class = UnitClass(unit)
    if class then
        if C_ClassColor and C_ClassColor.GetClassColor then
            local c = C_ClassColor.GetClassColor(class)
            if c then return c.r, c.g, c.b end
        end
        local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if rc then return rc.r, rc.g, rc.b end
    end
    return 1, 1, 1
end

-- Couleur d'une unité : classe si joueur, sinon couleur de réaction (PNJ).
function U.GetReactionColor(unit)
    if UnitIsPlayer(unit) then
        return U.GetClassColor(unit)
    end
    -- UnitReaction peut être SECRET pour une cible en 12.0 : indexer une table avec
    -- une clé secrète lève une erreur. On ne l'utilise que si elle est LISIBLE.
    local reaction = UnitReaction(unit, "player")
    if reaction and not (issecretvalue and issecretvalue(reaction))
        and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
        local c = FACTION_BAR_COLORS[reaction]
        return c.r, c.g, c.b
    end
    return 0.6, 0.6, 0.6
end

--------------------------------------------------------------------------------
-- Formatage
--------------------------------------------------------------------------------
-- Abrège un grand nombre (1234567 -> "1.2M"). Équivalent maison de
-- AbbreviateNumbers, pour un contrôle total du rendu.
function U.FormatNumber(value)
    -- Valeur « secrète » (retail 12.0+) : le moteur interdit toute comparaison
    -- ou arithmétique dessus côté addon. Impossible de l'abréger — l'appelant
    -- doit la passer directement à un widget (StatusBar / FontString). Filet de
    -- sécurité pour ne jamais lever d'erreur si on nous en passe une.
    if issecretvalue and issecretvalue(value) then
        return "?"
    end
    value = value or 0
    if value >= 1e9 then
        return string.format("%.1fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.1fM", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.1fk", value / 1e3)
    end
    return string.format("%d", value)
end

--------------------------------------------------------------------------------
-- Sécurité combat (taboo / fonctions protégées)
-- Certaines actions sur les cadres sécurisés (SetPoint, SetSize, Show/Hide…)
-- sont interdites pendant le combat. RunWhenSafe exécute immédiatement si hors
-- combat, sinon diffère au prochain PLAYER_REGEN_ENABLED. Une seule frame,
-- une file d'attente, aucune fuite mémoire.
--------------------------------------------------------------------------------
local safeFrame = CreateFrame("Frame")
local safeQueue = {}

safeFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    -- On sort du combat : on vide la file. Les fonctions ajoutées pendant
    -- l'exécution s'exécutent immédiatement (hors combat), pas besoin de
    -- réarmer l'événement.
    local n = #safeQueue
    for i = 1, n do
        local fn = safeQueue[i]
        safeQueue[i] = nil
        local ok, err = pcall(fn)
        if not ok then ns:Print("RunWhenSafe : %s", err) end
    end
end)

function U.RunWhenSafe(fn)
    if InCombatLockdown() then
        safeQueue[#safeQueue + 1] = fn
        safeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        fn()
    end
end

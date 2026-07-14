-- BravUI — Bus d'événements central
--
-- UNE seule frame écoute les événements *broadcast* et les redistribue aux
-- abonnés. NE PAS l'utiliser pour les événements unitaires (UNIT_*) : ceux-ci
-- sont enregistrés directement sur chaque cadre via RegisterUnitEvent, ce qui
-- laisse le moteur du jeu filtrer par unité (bien plus performant qu'un
-- RegisterEvent global qui réveillerait notre code pour toutes les unités).

local addonName, ns = ...

local EventBus = {}
ns.EventBus = EventBus

local frame = CreateFrame("Frame")
local callbacks = {} -- [event] = { [fn] = true }

frame:SetScript("OnEvent", function(_, event, ...)
    local list = callbacks[event]
    if not list then return end
    for fn in pairs(list) do
        fn(event, ...)
    end
end)

-- Abonne une fonction à un événement. fn(event, ...) reçoit les mêmes
-- arguments que l'événement Blizzard.
function EventBus:Register(event, fn)
    local list = callbacks[event]
    if not list then
        list = {}
        callbacks[event] = list
        frame:RegisterEvent(event)
    end
    list[fn] = true
end

-- Désabonne. La frame cesse d'écouter l'événement quand plus personne n'y est
-- abonné.
function EventBus:Unregister(event, fn)
    local list = callbacks[event]
    if not list then return end
    list[fn] = nil
    if not next(list) then
        callbacks[event] = nil
        frame:UnregisterEvent(event)
    end
end

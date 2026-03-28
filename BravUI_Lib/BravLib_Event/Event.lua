local BravLib = BravLib

BravLib.Event = {}

local frame = CreateFrame("Frame")
local registry = {}

frame:SetScript("OnEvent", function(_, event, ...)
    if not registry[event] then return end
    for _, callback in ipairs(registry[event]) do
        callback(event, ...)
    end
end)

function BravLib.Event.Register(event, callback)
    if not registry[event] then
        registry[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(registry[event], callback)
end

function BravLib.Event.Unregister(event, callback)
    if not registry[event] then return end
    for i = #registry[event], 1, -1 do
        if registry[event][i] == callback then
            table.remove(registry[event], i)
            break
        end
    end
    if #registry[event] == 0 then
        registry[event] = nil
        frame:UnregisterEvent(event)
    end
end

function BravLib.Event.Fire(event, ...)
    if not registry[event] then return end
    for _, callback in ipairs(registry[event]) do
        callback(event, ...)
    end
end

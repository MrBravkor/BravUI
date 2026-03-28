local BravLib = BravLib

local PREFIX = "|cFFFFFFFFBrav|r|cFF00FFFFui|r: "
local WARN_COLOR = "|cFFFFD700"
local DEBUG_COLOR = "|cFF888888"

function BravLib.Print(...)
    local msg = ""
    for i = 1, select("#", ...) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(select(i, ...))
    end
    print(PREFIX .. msg)
end

function BravLib.Warn(...)
    local msg = ""
    for i = 1, select("#", ...) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(select(i, ...))
    end
    print(PREFIX .. WARN_COLOR .. msg .. "|r")
end

function BravLib.Debug(...)
    if not BravLib.debug then return end
    local msg = ""
    for i = 1, select("#", ...) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(select(i, ...))
    end
    print(PREFIX .. DEBUG_COLOR .. "[Debug] " .. msg .. "|r")
end

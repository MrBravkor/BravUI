local BravLib = BravLib

function BravLib.Capitalize(str)
    if type(str) ~= "string" or str == "" then return str end
    return str:sub(1, 1):upper() .. str:sub(2)
end

function BravLib.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function BravLib.TableMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            BravLib.TableMerge(target[k], v)
        elseif target[k] == nil then
            if type(v) == "table" then
                target[k] = BravLib.CopyTable(v)
            else
                target[k] = v
            end
        end
    end
    return target
end

function BravLib.DeepApply(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            BravLib.DeepApply(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

function BravLib.CopyTable(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = BravLib.CopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

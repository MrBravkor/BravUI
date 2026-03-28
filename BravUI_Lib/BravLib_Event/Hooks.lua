local BravLib = BravLib

BravLib.Hooks = {}

local hooks = {}

function BravLib.Hooks.Register(hook, callback)
    if not hooks[hook] then
        hooks[hook] = {}
    end
    table.insert(hooks[hook], callback)
end

function BravLib.Hooks.Fire(hook, ...)
    if not hooks[hook] then return end
    for _, callback in ipairs(hooks[hook]) do
        callback(...)
    end
end

function BravLib.Hooks.Unregister(hook, callback)
    if not hooks[hook] then return end
    for i = #hooks[hook], 1, -1 do
        if hooks[hook][i] == callback then
            table.remove(hooks[hook], i)
            break
        end
    end
    if #hooks[hook] == 0 then
        hooks[hook] = nil
    end
end

local BravLib = BravLib

BravLib.API = {}

function BravLib.API.Get(module, key)
    local db = BravLib.Storage.GetDB()
    if not db then return nil end
    if not db[module] then return nil end
    return db[module][key]
end

function BravLib.API.Set(module, key, value)
    local db = BravLib.Storage.GetDB()
    if not db then return end
    if not db[module] then
        db[module] = {}
    end
    db[module][key] = value
    BravLib.Hooks.Fire("CONFIG_CHANGED", module, key, value)
end

function BravLib.API.GetModule(module)
    local db = BravLib.Storage.GetDB()
    if not db then return {} end
    return db[module] or {}
end

function BravLib.API.GetDefaults(module)
    local db = BravLib.Storage.GetDB()
    -- Returns a copy to prevent mutation
    if not db or not db[module] then return {} end
    return BravLib.CopyTable(db[module])
end

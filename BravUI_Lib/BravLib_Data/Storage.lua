local BravLib = BravLib

BravLib.Storage = {}

local db = nil
local defaults = {}

function BravLib.Storage.Init(defaultsTable)
    defaults = defaultsTable or {}

    if type(BravUI_DB) ~= "table" then
        BravUI_DB = {}
    end

    BravLib.TableMerge(BravUI_DB, defaults)
    db = BravUI_DB

    BravLib.Debug("Storage initialized")
end

function BravLib.Storage.GetDB()
    return db
end

function BravLib.Storage.GetDefaults()
    return BravLib.CopyTable(defaults)
end

function BravLib.Storage.Reset()
    if not db then return end
    wipe(db)
    BravLib.TableMerge(db, BravLib.CopyTable(defaults))
    BravLib.Debug("Storage reset to defaults")
end

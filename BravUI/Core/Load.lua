local BravUI = BravUI

-- ============================================================================
-- FRAME MAP (clé menu → clé BravUI.Frames)
-- ============================================================================

local UNIT_MAP = {
  player = "Player", target = "Target", tot   = "ToT",
  pet    = "Pet",    focus  = "Focus",  group = "Group",
  raid15 = "Raid15", raid25 = "Raid25", raid40 = "Raid40",
}

-- ============================================================================
-- HOOKS MENU → MODULES
-- ============================================================================

BravLib.Hooks.Register("APPLY_UNIT", function(which)
  local ns = BravUI.Frames and BravUI.Frames[UNIT_MAP[which]]
  if not ns then return end
  if ns.Refresh then pcall(ns.Refresh)
  elseif ns.ApplyFromDB then pcall(ns.ApplyFromDB) end
  if ns.RefreshAuras then pcall(ns.RefreshAuras) end
end)

BravLib.Hooks.Register("RESET_UNIT", function(which)
  local db  = BravLib.Storage.GetDB()
  local def = BravLib.Storage.GetDefaults()
  if db and db.unitframes and def and def.unitframes and def.unitframes[which] then
    db.unitframes[which] = def.unitframes[which]
  end
  BravLib.Hooks.Fire("APPLY_UNIT", which)
end)

BravLib.Hooks.Register("APPLY_ALL", function()
  for _, ns in pairs(BravUI.Frames or {}) do
    if ns.ApplyFromDB then pcall(ns.ApplyFromDB) end
  end
end)

BravLib.Hooks.Register("APPLY_ACTIONBARS", function()
  local mod = BravUI:GetModule("Misc.ActionBars")
  if mod and mod.enabled and mod.Refresh then pcall(mod.Refresh, mod) end
end)

BravLib.Hooks.Register("APPLY_CHAT", function()
  local mod = BravUI:GetModule("Interface.Chat")
  if mod and mod.enabled and mod.Refresh then pcall(mod.Refresh, mod) end
end)

BravLib.Hooks.Register("APPLY_INFOBAR", function()
  local mod = BravUI:GetModule("Interface.Chat")
  if mod and mod.enabled and mod.RefreshInfoBar then pcall(mod.RefreshInfoBar, mod) end
end)

BravLib.Hooks.Register("APPLY_MINIMAP", function()
  local mod = BravUI:GetModule("Interface.Minimap")
  if mod and mod.enabled and mod.Refresh then pcall(mod.Refresh, mod) end
end)

BravLib.Hooks.Register("RESET_MINIMAP", function()
  local db  = BravLib.Storage.GetDB()
  local def = BravLib.Storage.GetDefaults()
  if db and def and def.minimap then db.minimap = def.minimap end
  BravLib.Hooks.Fire("APPLY_MINIMAP")
end)

BravLib.Hooks.Register("APPLY_FONT", function()
  -- Les modules qui gèrent la police écoutent ce hook directement
end)

-- ============================================================================
-- HIDE BLIZZARD UI
-- ============================================================================

-- Only hide what BravUI modules replace
-- Uses RegisterStateDriver to avoid taint
local BLIZZARD_FRAMES = {
  "PlayerFrame", "TargetFrame", "TargetFrameToT",
  "FocusFrame", "FocusFrameToT",
  "PetFrame", "PartyFrame",
  "CompactRaidFrameManager",
}

local function ApplyHideBlizzardUI()
  local hide = BravLib.API.Get("general", "hideBlizzardUI")
  if hide == false then return end
  -- Default: hide (nil or true)
  for _, name in ipairs(BLIZZARD_FRAMES) do
    local frame = _G[name]
    if frame then
      RegisterStateDriver(frame, "visibility", "hide")
    end
  end
end

BravLib.Event.Register("PLAYER_ENTERING_WORLD", ApplyHideBlizzardUI)

function BravUI:LoadModules()
    for name, module in pairs(self.modules) do
        if module.Init then
            local ok, err = pcall(module.Init, module)
            if not ok then
                BravLib.Warn("Error initializing module '" .. name .. "': " .. tostring(err))
            end
        end
    end

    for name, module in pairs(self.modules) do
        if module.Enable then
            local ok, err = pcall(module.Enable, module)
            if ok then
                module.enabled = true
            else
                BravLib.Warn("Error enabling module '" .. name .. "': " .. tostring(err))
            end
        end
    end

    BravLib.Debug("All modules loaded")
end

function BravUI:DisableModule(name)
    local module = self.modules[name]
    if not module then return end
    if module.Disable then
        pcall(module.Disable, module)
    end
    module.enabled = false
end

function BravUI:EnableModule(name)
    local module = self.modules[name]
    if not module or module.enabled then return end
    if module.Enable then
        local ok, err = pcall(module.Enable, module)
        if ok then
            module.enabled = true
        else
            BravLib.Warn("Error enabling module '" .. name .. "': " .. tostring(err))
        end
    end
end

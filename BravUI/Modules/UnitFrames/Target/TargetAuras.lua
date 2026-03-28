-- BravUI/Modules/UnitFrames/Target/TargetAuras.lua
-- Buffs + Debuffs on Target frame (2 independent containers)
--
-- Secret-safe via AurasShared factory.
-- Each container movable independently via BravUI.Move.

if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then return end
if not BravUI or not BravUI.AurasShared then return end

BravUI.Frames        = BravUI.Frames or {}
BravUI.Frames.Target = BravUI.Frames.Target or {}

local AS = BravUI.AurasShared

-- ============================================================================
-- CONFIG GETTERS
-- ============================================================================
local function GetBuffsCfg()
  local db = BravLib.Storage.GetDB()
  return db and db.unitframes and db.unitframes.target and db.unitframes.target.buffs
end

local function GetDebuffsCfg()
  local db = BravLib.Storage.GetDB()
  return db and db.unitframes and db.unitframes.target and db.unitframes.target.debuffs
end

-- ============================================================================
-- CREATE AURA BARS
-- ============================================================================
local TargetBuffs = AS.CreateAuraBar({
  frameName     = "BravUI_TargetBuffs",
  unit          = "target",
  isDebuff      = false,
  getCfg        = GetBuffsCfg,
  moverName     = "TargetBuffs",
  defaultPos    = { x = 0, y = -290 },
  defaultAnchor = function()
    return BravUI.Frames.Target and BravUI.Frames.Target.CastFrame
  end,
})

local TargetDebuffs = AS.CreateAuraBar({
  frameName     = "BravUI_TargetDebuffs",
  unit          = "target",
  isDebuff      = true,
  getCfg        = GetDebuffsCfg,
  moverName     = "TargetDebuffs",
  defaultPos    = { x = 0, y = -316 },
  defaultAnchor = function()
    return TargetBuffs.Container
  end,
})

-- ============================================================================
-- EXPOSE
-- ============================================================================
BravUI.Frames.Target.RefreshAuras = function()
  TargetBuffs.Refresh()
  TargetDebuffs.Refresh()
end

-- ============================================================================
-- EVENTS (dirty flag + 50ms throttle)
-- ============================================================================
local dirty          = false
local flushScheduled = false

local function FlushDirty()
  flushScheduled = false
  if not dirty then return end
  dirty = false
  TargetBuffs.Update()
  TargetDebuffs.Update()
end

local function MarkDirty()
  dirty = true
  if not flushScheduled then
    flushScheduled = true
    C_Timer.After(0.05, FlushDirty)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then
    TargetBuffs.ApplyFromDB()
    TargetDebuffs.ApplyFromDB()

    BravUI.Frames.Target.BuffsContainer   = TargetBuffs.Container
    BravUI.Frames.Target.DebuffsContainer = TargetDebuffs.Container

    C_Timer.After(0.2, function()
      TargetBuffs.Update()
      TargetDebuffs.Update()
    end)

    C_Timer.After(1.5, function()
      TargetBuffs.RegisterMover()
      TargetDebuffs.RegisterMover()
    end)
    return
  end

  if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    TargetBuffs.Update()
    TargetDebuffs.Update()
    return
  end

  if event == "UNIT_AURA" and unit == "target" then
    MarkDirty()
  end
end)

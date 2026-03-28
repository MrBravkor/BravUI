-- BravUI/Modules/UnitFrames/Player/PlayerAuras.lua
-- Buffs + Debuffs on Player frame (2 independent containers)
--
-- Secret-safe via AurasShared factory.
-- Each container movable independently via BravUI.Move.

if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then return end
if not BravUI or not BravUI.AurasShared then return end

BravUI.Frames        = BravUI.Frames or {}
BravUI.Frames.Player = BravUI.Frames.Player or {}

local AS = BravUI.AurasShared

-- ============================================================================
-- CONFIG GETTERS
-- ============================================================================
local function GetBuffsCfg()
  local db = BravLib.Storage.GetDB()
  return db and db.unitframes and db.unitframes.player and db.unitframes.player.buffs
end

local function GetDebuffsCfg()
  local db = BravLib.Storage.GetDB()
  return db and db.unitframes and db.unitframes.player and db.unitframes.player.debuffs
end

-- ============================================================================
-- CREATE AURA BARS
-- ============================================================================
local PlayerBuffs = AS.CreateAuraBar({
  frameName     = "BravUI_PlayerBuffs",
  unit          = "player",
  isDebuff      = false,
  getCfg        = GetBuffsCfg,
  moverName     = "PlayerBuffs",
  defaultPos    = { x = 0, y = -160 },
  defaultAnchor = function()
    return BravUI.Frames.Player and BravUI.Frames.Player.CastFrame
  end,
})

local PlayerDebuffs = AS.CreateAuraBar({
  frameName     = "BravUI_PlayerDebuffs",
  unit          = "player",
  isDebuff      = true,
  getCfg        = GetDebuffsCfg,
  moverName     = "PlayerDebuffs",
  defaultPos    = { x = 0, y = -186 },
  defaultAnchor = function()
    return PlayerBuffs.Container
  end,
})

-- ============================================================================
-- EXPOSE
-- ============================================================================
BravUI.Frames.Player.RefreshAuras = function()
  PlayerBuffs.Refresh()
  PlayerDebuffs.Refresh()
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
  PlayerBuffs.Update()
  PlayerDebuffs.Update()
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
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then
    PlayerBuffs.ApplyFromDB()
    PlayerDebuffs.ApplyFromDB()

    BravUI.Frames.Player.BuffsContainer   = PlayerBuffs.Container
    BravUI.Frames.Player.DebuffsContainer = PlayerDebuffs.Container

    C_Timer.After(0.2, function()
      PlayerBuffs.Update()
      PlayerDebuffs.Update()
    end)

    C_Timer.After(1.5, function()
      PlayerBuffs.RegisterMover()
      PlayerDebuffs.RegisterMover()
    end)
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    PlayerBuffs.Update()
    PlayerDebuffs.Update()
    return
  end

  if event == "UNIT_AURA" and unit == "player" then
    MarkDirty()
  end
end)

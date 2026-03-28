-- BravUI/Modules/UnitFrames/Player/PlayerHealPredict.lua
-- Heal Prediction + Absorb overlay on Player frame
-- Shows incoming heals (green) and absorb shields (white) on the HP bar.

BravUI.Frames        = BravUI.Frames or {}
BravUI.Frames.Player = BravUI.Frames.Player or {}

local U = BravUI.Utils

-- ============================================================================
-- CREATE BARS (delayed until Player HP bar exists)
-- ============================================================================
local bars = nil

local function EnsureBars()
  if bars then return true end
  local hp = BravUI.Frames.Player and BravUI.Frames.Player.HPBar
  if not hp then return false end
  bars = U.CreateHealPredictBars(hp)
  return true
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function UpdateHealPredict()
  if not EnsureBars() then return end
  local hp = BravUI.Frames.Player.HPBar
  U.UpdateHealPredictBars("player", hp, bars)
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
  UpdateHealPredict()
end

local function MarkDirty()
  dirty = true
  if not flushScheduled then
    flushScheduled = true
    C_Timer.After(0.05, FlushDirty)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("UNIT_HEALTH")
ev:RegisterEvent("UNIT_MAXHEALTH")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("UNIT_HEAL_PREDICTION")
ev:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(0.2, UpdateHealPredict)
    return
  end

  if unit == "player" then
    MarkDirty()
  end
end)

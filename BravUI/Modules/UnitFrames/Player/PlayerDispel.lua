-- BravUI/Modules/UnitFrames/Player/PlayerDispel.lua
-- Dispel overlay on Player frame (DandersFrames-style)
-- Uses C_CurveUtil color curves — 100% secret-safe, no string comparisons.
-- Shows 4 StatusBar borders + gradient + atlas icon when a dispellable debuff is active.

if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
if not BravUI or not BravUI.AurasShared then return end

BravUI.Frames        = BravUI.Frames or {}
BravUI.Frames.Player = BravUI.Frames.Player or {}

local U = BravUI.Utils

-- ============================================================================
-- CREATE OVERLAY (delayed until Player HP bar exists)
-- ============================================================================
local dispelOverlay = nil

local function EnsureOverlay()
  if dispelOverlay then return true end
  local hp = BravUI.Frames.Player and BravUI.Frames.Player.HPBar
  if not hp then return false end
  dispelOverlay = U.CreateDispelOverlay(hp)
  return true
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function UpdateDispel()
  if not EnsureOverlay() then return end
  local hp = BravUI.Frames.Player.HPBar
  U.UpdateDispelOverlay("player", hp, dispelOverlay)
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
  UpdateDispel()
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
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(0.2, UpdateDispel)
    return
  end

  if event == "UNIT_AURA" and unit == "player" then
    MarkDirty()
  end
end)

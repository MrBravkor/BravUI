-- BravUI/Modules/UnitFrames/HealPredictOverlay.lua
-- Heal Prediction + Absorb overlay pour Group (party 1-4) et Raid (15/25/40).
-- Affiche les soins entrants (vert) et les boucliers d'absorption (blanc) sur les HP bars.

BravUI.Frames = BravUI.Frames or {}

local U = BravUI.Utils

local CONFIGS = {
  { frameName = "Group",  maxMembers = 4  },
  { frameName = "Raid15", maxMembers = 15 },
  { frameName = "Raid25", maxMembers = 25 },
  { frameName = "Raid40", maxMembers = 40 },
}

-- ============================================================================
-- BAR STORAGE
-- ============================================================================
local memberBars = {}

local function EnsureBars(cfg)
  local key = cfg.frameName
  if memberBars[key] then return true end
  local rf = BravUI.Frames[key]
  if not rf or not rf.Members then return false end
  memberBars[key] = {}
  for i = 1, cfg.maxMembers do
    local mf = rf.Members[i]
    if mf and mf.HPBar then
      memberBars[key][i] = U.CreateHealPredictBars(mf.HPBar)
    end
  end
  return memberBars[key][1] ~= nil
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function UpdateMember(cfg, i)
  local key  = cfg.frameName
  local bars = memberBars[key] and memberBars[key][i]
  if not bars then return end
  local rf = BravUI.Frames[key]
  local mf = rf and rf.Members and rf.Members[i]
  if not mf or not mf:IsShown() then
    if bars.heal   then bars.heal:Hide()   end
    if bars.absorb then bars.absorb:Hide() end
    return
  end
  U.UpdateHealPredictBars(mf.unit, mf.HPBar, bars)
end

local function UpdateAllForConfig(cfg)
  if not EnsureBars(cfg) then return end
  for i = 1, cfg.maxMembers do UpdateMember(cfg, i) end
end

local function UpdateAll()
  for _, cfg in ipairs(CONFIGS) do UpdateAllForConfig(cfg) end
end

-- ============================================================================
-- EVENTS (dirty flag + 50ms throttle)
-- ============================================================================
local dirtySlots     = {}
local flushScheduled = false

local function FlushDirty()
  flushScheduled = false
  for _, entry in ipairs(dirtySlots) do UpdateMember(entry[1], entry[2]) end
  wipe(dirtySlots)
end

local function MarkDirty(cfg, idx)
  dirtySlots[#dirtySlots + 1] = { cfg, idx }
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
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
     or event == "GROUP_ROSTER_UPDATE" then
    C_Timer.After(0.3, UpdateAll)
    return
  end

  for _, cfg in ipairs(CONFIGS) do
    local key = cfg.frameName
    if not memberBars[key] then EnsureBars(cfg) end
    if memberBars[key] then
      local rf = BravUI.Frames[key]
      if rf and rf.Members then
        for i = 1, cfg.maxMembers do
          local mf = rf.Members[i]
          if mf then
            local ok, match = pcall(function() return mf.unit == unit end)
            if ok and match then MarkDirty(cfg, i); return end
          end
        end
      end
    end
  end
end)

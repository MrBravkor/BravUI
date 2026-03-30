-- BravUI/Modules/UnitFrames/Group/GroupCast.lua
-- Group CastBars (party members 1-4)
-- Shows spell icon, cast bar, spell name, time remaining

BravUI.Frames       = BravUI.Frames or {}
BravUI.Frames.Group = BravUI.Frames.Group or {}

local function FONT_PATH() return BravUI.Utils.GetFont() end

local U                  = BravUI.Utils
local Create1pxBorder    = U.Create1pxBorder
local CreateBarBackground = U.CreateBarBackground

-- ============================================================================
-- CONFIG
-- ============================================================================
local MAX_PARTY = 4
local CAST_H    = 10
local ICON_PAD  = 2

local CAST_COLOR_NORMAL          = { r = 1.0, g = 0.8, b = 0.0 }
local CAST_COLOR_NOT_INTERRUPTIBLE = { r = 0.6, g = 0.6, b = 0.6 }
local CAST_COLOR_CHANNEL         = { r = 0.3, g = 0.7, b = 1.0 }

-- ============================================================================
-- DB CONFIG GETTER
-- ============================================================================
local function GetCastConfig()
  local db = BravLib.Storage.GetDB()
  return db and db.unitframes and db.unitframes.group and db.unitframes.group.cast
end

-- ============================================================================
-- CAST BAR FACTORY
-- ============================================================================
local castBars = {}

local function CreatePartyCastBar(index)
  local unit         = "party" .. index
  local parentFrames = BravUI.Frames.Group and BravUI.Frames.Group.Frames
  local parentFrame  = parentFrames and parentFrames[index]
                       or _G["BravUI_PartyFrame" .. index]

  local castFrame = CreateFrame("Frame", "BravUI_PartyCast" .. index, parentFrame or UIParent)
  castFrame:SetSize(CAST_H * 14, CAST_H)   -- placeholder, repositioned in PositionCastBars
  castFrame:EnableMouse(false)
  castFrame:Hide()

  -- Icon
  local iconFrame = CreateFrame("Frame", nil, castFrame, "BackdropTemplate")
  iconFrame:SetSize(CAST_H, CAST_H)
  iconFrame:SetPoint("LEFT", castFrame, "LEFT", 0, 0)
  Create1pxBorder(iconFrame)
  iconFrame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
  iconFrame:SetBackdropColor(0, 0, 0, 0.55)

  local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
  iconTex:SetAllPoints(iconFrame)
  iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  castFrame.Icon      = iconTex
  castFrame.IconFrame = iconFrame

  -- Bar
  local bar = CreateFrame("StatusBar", nil, castFrame)
  bar:SetPoint("LEFT",  iconFrame,  "RIGHT",  ICON_PAD, 0)
  bar:SetPoint("RIGHT", castFrame,  "RIGHT",  0, 0)
  bar:SetHeight(CAST_H)
  bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:SetStatusBarColor(CAST_COLOR_NORMAL.r, CAST_COLOR_NORMAL.g, CAST_COLOR_NORMAL.b)
  Create1pxBorder(bar)
  CreateBarBackground(bar)
  castFrame.Bar = bar

  -- Spark
  local spark = bar:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface/CastingBar/UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  spark:SetSize(12, CAST_H * 1.4)
  spark:Hide()
  castFrame.Spark = spark

  -- Spell name
  local spellText = bar:CreateFontString(nil, "OVERLAY")
  spellText:SetPoint("LEFT", bar, "LEFT", 4, 0)
  spellText:SetJustifyH("LEFT")
  pcall(function() spellText:SetFont(FONT_PATH(), 8, "OUTLINE") end)
  spellText:SetTextColor(1, 1, 1, 0.9)
  castFrame.SpellText = spellText

  -- State
  castFrame.__unit             = unit
  castFrame.__index            = index
  castFrame.__active           = false
  castFrame.__isChannel        = false
  castFrame.__startTime        = 0
  castFrame.__endTime          = 0
  castFrame.__notInterruptible = false

  return castFrame
end

for i = 1, MAX_PARTY do
  castBars[i] = CreatePartyCastBar(i)
end

BravUI.Frames.Group.CastBars = castBars

-- ============================================================================
-- POSITION CAST BARS
-- ============================================================================
local function PositionCastBars()
  local parentFrames = BravUI.Frames.Group and BravUI.Frames.Group.Frames

  for i = 1, MAX_PARTY do
    local castBar    = castBars[i]
    local parentFrame = parentFrames and parentFrames[i]
    if parentFrame and castBar then
      castBar:SetParent(parentFrame)
      castBar:ClearAllPoints()
      castBar:SetPoint("TOPLEFT",  parentFrame, "BOTTOMLEFT",  0, -2)
      castBar:SetPoint("TOPRIGHT", parentFrame, "BOTTOMRIGHT", 0, -2)
    end
  end
end

-- ============================================================================
-- UPDATE CAST BAR
-- ============================================================================
local function SetCastColors(castBar, notInterruptible, isChannel)
  if not castBar or not castBar.Bar then return end
  local cfg    = GetCastConfig()
  local colors = cfg and cfg.colors
  if notInterruptible then
    local c = (colors and colors.notInterruptible) or CAST_COLOR_NOT_INTERRUPTIBLE
    castBar.Bar:SetStatusBarColor(c.r or 0.6, c.g or 0.6, c.b or 0.6)
  elseif isChannel then
    local c = (colors and colors.channel) or CAST_COLOR_CHANNEL
    castBar.Bar:SetStatusBarColor(c.r or 0.3, c.g or 0.7, c.b or 1.0)
  else
    local c = (colors and colors.normal) or CAST_COLOR_NORMAL
    castBar.Bar:SetStatusBarColor(c.r or 1.0, c.g or 0.8, c.b or 0.0)
  end
end

local function StopCast(castBar)
  if not castBar then return end
  castBar.__active    = false
  castBar.__isChannel = false
  castBar.__startTime, castBar.__endTime = 0, 0
  castBar.Bar:SetValue(0)
  castBar.SpellText:SetText("")
  castBar.Icon:SetTexture(nil)
  castBar.Spark:Hide()
  castBar:Hide()
end

local function StartOrRefreshCast(castBar)
  if not castBar then return end

  local unit = castBar.__unit
  local ok1  = pcall(function() if not UnitExists(unit) then error() end end)
  if not ok1 then StopCast(castBar); return end

  local name, texture, startMS, endMS, notInterruptible
  local isChannel = false

  pcall(function()
    local n, _, tex, sMS, eMS, _, _, ni = UnitCastingInfo(unit)
    if n then name, texture, startMS, endMS, notInterruptible = n, tex, sMS, eMS, ni end
  end)

  if not name then
    pcall(function()
      local n, _, tex, sMS, eMS, _, ni = UnitChannelInfo(unit)
      if n then
        name, texture, startMS, endMS, notInterruptible = n, tex, sMS, eMS, ni
        isChannel = true
      end
    end)
  end

  if not name then StopCast(castBar); return end

  local ok2 = pcall(function()
    castBar.__startTime        = (startMS or 0) / 1000
    castBar.__endTime          = (endMS   or 0) / 1000
    castBar.__notInterruptible = notInterruptible and true or false
  end)
  if not ok2 then StopCast(castBar); return end

  castBar.__active    = true
  castBar.__isChannel = isChannel

  SetCastColors(castBar, castBar.__notInterruptible, isChannel)

  if texture and texture ~= "" then
    castBar.Icon:SetTexture(texture)
    castBar.IconFrame:Show()
  else
    castBar.Icon:SetTexture(nil)
    castBar.IconFrame:Hide()
  end

  local displayName = name or ""
  if #displayName > 14 then displayName = string.sub(displayName, 1, 13) .. ".." end
  castBar.SpellText:SetText(displayName)

  local dur = castBar.__endTime - castBar.__startTime
  if dur <= 0 then dur = 0.001 end
  castBar.Bar:SetMinMaxValues(0, dur)

  castBar:Show()
  castBar.Spark:Show()
end

local function UpdateCastBar(castBar)
  if not castBar or not castBar.__active then return end

  local now = GetTime()
  if castBar.__endTime <= 0 or now >= castBar.__endTime then
    StopCast(castBar)
    return
  end

  local dur = castBar.__endTime - castBar.__startTime
  if dur <= 0 then dur = 0.001 end

  local value, pct
  if castBar.__isChannel then
    local remain = castBar.__endTime - now
    if remain < 0 then remain = 0 end
    value = remain
    pct   = remain / dur
  else
    local elapsed = now - castBar.__startTime
    if elapsed < 0 then elapsed = 0 end
    if elapsed > dur then elapsed = dur end
    value = elapsed
    pct   = elapsed / dur
  end

  castBar.Bar:SetValue(value)

  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
  local w = castBar.Bar:GetWidth() or 1
  castBar.Spark:ClearAllPoints()
  castBar.Spark:SetPoint("CENTER", castBar.Bar, "LEFT", w * pct, 0)
end

-- ============================================================================
-- EVENTS
-- ============================================================================
local ev = CreateFrame("Frame", "BravUI_GroupCast_EventFrame")

ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")

for i = 1, MAX_PARTY do
  local u = "party" .. i
  ev:RegisterUnitEvent("UNIT_SPELLCAST_START",           u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP",            u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED",          u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED",     u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED",         u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",   u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",    u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE",  u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE",   u)
  ev:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", u)
end

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    PositionCastBars()
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    PositionCastBars()
    for i = 1, MAX_PARTY do
      local ok = pcall(function() if not UnitExists("party" .. i) then error() end end)
      if not ok then StopCast(castBars[i]) end
    end
    return
  end

  if unit then
    for i = 1, MAX_PARTY do
      if castBars[i].__unit == unit then
        if event == "UNIT_SPELLCAST_START"
          or event == "UNIT_SPELLCAST_CHANNEL_START"
          or event == "UNIT_SPELLCAST_DELAYED"
          or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
          or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
          or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
          StartOrRefreshCast(castBars[i])
        elseif event == "UNIT_SPELLCAST_STOP"
          or event == "UNIT_SPELLCAST_FAILED"
          or event == "UNIT_SPELLCAST_INTERRUPTED"
          or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
          StopCast(castBars[i])
        end
        break
      end
    end
  end
end)

ev:SetScript("OnUpdate", function()
  for i = 1, MAX_PARTY do
    if castBars[i].__active then UpdateCastBar(castBars[i]) end
  end
end)

-- ============================================================================
-- PUBLIC API
-- ============================================================================
BravUI.Frames.Group.RefreshCastBars = function()
  PositionCastBars()
  for i = 1, MAX_PARTY do StartOrRefreshCast(castBars[i]) end
end

BravUI.Frames.Group.StopAllCasts = function()
  for i = 1, MAX_PARTY do StopCast(castBars[i]) end
end

C_Timer.After(0.3, PositionCastBars)

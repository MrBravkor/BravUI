-- BravUI/Modules/UnitFrames/Target.lua

local U                   = BravUI.Utils
local SafeUnitIsDead      = U.SafeUnitIsDead
local Create1pxBorder     = U.Create1pxBorder
local CreateBarBackground  = U.CreateBarBackground
local ApplyBG             = U.ApplyBG
local AbbrevAny           = U.AbbrevForSetText

local FONT_PATH = BravLib.Media.Get("font", "uf") or BravLib.Media.Get("font", "default") or STANDARD_TEXT_FONT

-- ============================================================================
-- CONFIG
-- ============================================================================
local GAP       = 0
local HP_H      = 26
local POWER_H   = 10
local DEFAULT_W = 220

-- ============================================================================
-- DB CONFIG GETTERS
-- ============================================================================
local GetConfig, GetConfigValue, GetHeightConfig, GetColorConfig, GetTextConfig =
  U.MakeConfigGetters("target")

local _, _, GetPlayerHeightConfig = U.MakeConfigGetters("player")

-- ============================================================================
-- ROOT FRAME
-- ============================================================================
local CLASSPOWER_H = 7

local f = CreateFrame("Frame", "BravUI_TargetFrame", UIParent)
f:SetSize(DEFAULT_W, CLASSPOWER_H + HP_H + GAP + POWER_H)
f:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:Hide()

-- ============================================================================
-- SECURE CLICK OVERLAY
-- ============================================================================
local clickOverlay      = U.CreateClickOverlay("BravUI_TargetClickOverlay", "target")
local clickOverlayDirty = false

local function SyncClickOverlay()
  if not U.SyncClickOverlay(clickOverlay, f) then
    clickOverlayDirty = true
    return
  end
  clickOverlayDirty = false
end

SyncClickOverlay()
clickOverlay:Show()

U.HookOverlaySync(f, SyncClickOverlay)

-- ============================================================================
-- BAR FRAMES
-- ============================================================================
local hpFrame = CreateFrame("Frame", "BravUI_Target_HPFrame", f)
hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -CLASSPOWER_H)
hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -CLASSPOWER_H)
hpFrame:SetHeight(HP_H)
hpFrame:EnableMouse(false)

local powerFrame = CreateFrame("Frame", "BravUI_Target_PowerFrame", f)
powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, -GAP)
powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, -GAP)
powerFrame:SetHeight(POWER_H)
powerFrame:EnableMouse(false)

local castFrame = CreateFrame("Frame", "BravUI_Target_CastFrame", f)
castFrame:SetPoint("TOPLEFT",  powerFrame, "BOTTOMLEFT",  0, -GAP)
castFrame:SetPoint("TOPRIGHT", powerFrame, "BOTTOMRIGHT", 0, -GAP)
castFrame:SetHeight(14)
castFrame:EnableMouse(false)

-- ============================================================================
-- HEALTH BAR
-- ============================================================================
local hp          = U.CreateBar(hpFrame)
local hpNameText  = U.CreateText(hp, "LEFT",  "LEFT",  13,  6, 0)
hpNameText:SetNonSpaceWrap(false)
hpNameText:SetMaxLines(1)
hpNameText:SetWidth(DEFAULT_W * 0.45)

local hpStatsText = U.CreateText(hp, "RIGHT", "RIGHT", 13, -6, 0)

local hpTextWrapper = CreateFrame("Frame", "BravUI_Target_HPTextWrapper", hp)
hpTextWrapper:SetSize(150, 30)
hpTextWrapper:SetPoint("TOPLEFT", hpNameText, "TOPLEFT", -5, 5)
hpTextWrapper:SetMovable(true)
hpTextWrapper:EnableMouse(true)
hpTextWrapper:RegisterForDrag("LeftButton")
hpTextWrapper:SetScript("OnDragStart", function()
  if InCombatLockdown() then return end
  hpNameText:StartMoving()
end)
hpTextWrapper:SetScript("OnDragStop", function()
  hpNameText:StopMovingOrSizing()
end)

-- ============================================================================
-- POWER BAR
-- ============================================================================
local power     = U.CreateBar(powerFrame)
local powerText = U.CreateText(power, "CENTER", "CENTER", 11, 0, 0)

local powerTextWrapper = CreateFrame("Frame", "BravUI_Target_PowerTextWrapper", power)
powerTextWrapper:SetSize(100, 20)
powerTextWrapper:SetPoint("CENTER", powerText, "CENTER", 0, 0)
powerTextWrapper:SetMovable(true)
powerTextWrapper:EnableMouse(true)
powerTextWrapper:RegisterForDrag("LeftButton")
powerTextWrapper:SetScript("OnDragStart", function()
  if InCombatLockdown() then return end
  powerText:StartMoving()
end)
powerTextWrapper:SetScript("OnDragStop", function()
  powerText:StopMovingOrSizing()
end)

-- ============================================================================
-- CAST BAR
-- ============================================================================
local castBar = U.CreateBar(castFrame)
castBar:Hide()

local castIcon = castBar:CreateTexture(nil, "OVERLAY")
castIcon:SetSize(14, 14)
castIcon:SetPoint("LEFT", castBar, "LEFT", 2, 0)
castIcon:Hide()

local castNameText = castBar:CreateFontString(nil, "OVERLAY")
castNameText:SetPoint("LEFT", castIcon, "RIGHT", 4, 0)
castNameText:SetJustifyH("LEFT")
castNameText:SetFontObject("GameFontHighlightSmall")
pcall(function() castNameText:SetFont(FONT_PATH, 10, "OUTLINE") end)

local castTimeText = castBar:CreateFontString(nil, "OVERLAY")
castTimeText:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
castTimeText:SetJustifyH("RIGHT")
castTimeText:SetFontObject("GameFontHighlightSmall")
pcall(function() castTimeText:SetFont(FONT_PATH, 10, "OUTLINE") end)

-- ============================================================================
-- ICONS
-- ============================================================================
local rezHolder = U.CreateRezIcon(hp, 16)
local wmHolder  = U.CreateWMIcon(hp, 16)

-- ============================================================================
-- APPLY FROM DB
-- ============================================================================
local function ApplyFromDB()
  if InCombatLockdown() then return end

  local cfg = GetConfig() or {}
  local w   = cfg.width or DEFAULT_W
  f:SetWidth(w)
  hpFrame:SetWidth(w)
  powerFrame:SetWidth(w)

  local showPower = cfg.showPower ~= false

  local cpH  = GetPlayerHeightConfig("classPower", CLASSPOWER_H)
  local hpH  = GetHeightConfig("hp",    HP_H)
  local pwrH = GetHeightConfig("power", POWER_H)

  if showPower then powerFrame:Show(); power:Show()
  else              powerFrame:Hide(); power:Hide()
  end

  hpFrame:SetHeight(hpH)
  powerFrame:SetHeight(showPower and pwrH or 0.001)
  hp:SetHeight(hpH)
  power:SetHeight(pwrH)

  hpFrame:ClearAllPoints()
  hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -cpH)
  hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -cpH)

  local totalH = cpH + hpH
  if showPower then totalH = totalH + pwrH + GAP end
  f:SetHeight(totalH)

  powerFrame:ClearAllPoints()
  powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, showPower and -GAP or 0)
  powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, showPower and -GAP or 0)

  U.ApplyTextConfig(hpNameText,  GetTextConfig("name"),  hp,    "LEFT",   13,  6, 0)
  U.ApplyTextConfig(hpStatsText, GetTextConfig("hp"),    hp,    "RIGHT",  13, -6, 0)
  U.ApplyTextConfig(powerText,   GetTextConfig("power"), power, "CENTER", 11,  0, 0)

  SyncClickOverlay()
end

-- ============================================================================
-- COLORS + BG
-- ============================================================================
local function ApplyAllBackgrounds()
  ApplyBG(hp,      "target", "hp")
  ApplyBG(power,   "target", "power")
  ApplyBG(castBar, "target", "cast")
end

local function UpdateColors()
  if not UnitExists("target") then return end
  local colorCfg = GetColorConfig()
  U.UpdateHPColor("target", hp, colorCfg, { allowReaction = true })
  U.UpdatePowerColor("target", power, colorCfg)
  ApplyAllBackgrounds()
end

-- ============================================================================
-- BLIZZARD SOURCES
-- ============================================================================
local function GetBlizzardTargetHealthBar()
  if TargetFrame and TargetFrame.healthbar then return TargetFrame.healthbar end
  if TargetFrame and TargetFrame.HealthBar  then return TargetFrame.HealthBar  end
  if _G.TargetFrameHealthBar               then return _G.TargetFrameHealthBar end
  return nil
end

local function GetBlizzardTargetPowerBar()
  if TargetFrame and TargetFrame.manabar  then return TargetFrame.manabar  end
  if TargetFrame and TargetFrame.ManaBar  then return TargetFrame.ManaBar  end
  if TargetFrame and TargetFrame.powerBar then return TargetFrame.powerBar end
  if _G.TargetFrameManaBar               then return _G.TargetFrameManaBar end
  return nil
end

-- ============================================================================
-- TEXT CACHE
-- ============================================================================
local cachedHP  = "?"
local cachedPct = "?"

local function RefreshTargetText()
  pcall(function() hpNameText:SetText(UnitName("target") or "") end)

  local fmt   = "VALUE_PERCENT"
  local hpCfg = GetTextConfig("hp")
  if hpCfg and hpCfg.format then fmt = hpCfg.format end

  pcall(function()
    if     fmt == "VALUE"         then hpStatsText:SetText(cachedHP)
    elseif fmt == "PERCENT"       then hpStatsText:SetText(cachedPct)
    elseif fmt == "PERCENT_VALUE" then hpStatsText:SetText(cachedPct .. " | " .. cachedHP)
    elseif fmt == "NONE"          then hpStatsText:SetText("")
    else                               hpStatsText:SetText(cachedHP .. " | " .. cachedPct)
    end
  end)
end

local function RefreshPowerText()
  local pwrFmt = "VALUE"
  local pwrCfg = GetTextConfig("power")
  if pwrCfg and pwrCfg.format then pwrFmt = pwrCfg.format end

  if pwrFmt == "NONE" then powerText:SetText(""); return end

  local curP = UnitPower("target") or 0
  powerText:SetText(AbbrevAny(curP))
end

-- ============================================================================
-- MIRROR BLIZZARD
-- ============================================================================
local function HookBlizzardMirrorOnce()
  local hb = GetBlizzardTargetHealthBar()
  if hb and not hb.__BravUI_TargetMirrorHooked then
    hb.__BravUI_TargetMirrorHooked = true

    if hb.SetMinMaxValues then
      hooksecurefunc(hb, "SetMinMaxValues", function(_bar, minV, maxV)
        pcall(hp.SetMinMaxValues, hp, minV, maxV)
      end)
    end

    local blizzPctFS = nil
    pcall(function()
      if hb.LeftText    then blizzPctFS = hb.LeftText;    return end
      if hb.TextString  then blizzPctFS = hb.TextString;  return end
      if hb.RightText   then blizzPctFS = hb.RightText;   return end
      local container = TargetFrame
        and TargetFrame.TargetFrameContent
        and TargetFrame.TargetFrameContent.TargetFrameContentMain
        and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
      if container then
        if container.LeftText      then blizzPctFS = container.LeftText;      return end
        if container.HealthBarText then blizzPctFS = container.HealthBarText; return end
        if container.RightText     then blizzPctFS = container.RightText;     return end
      end
    end)

    if hb.SetValue then
      hooksecurefunc(hb, "SetValue", function(_bar, v)
        pcall(hp.SetValue, hp, v)
        cachedHP = AbbrevAny(v)
        pcall(function()
          if blizzPctFS and blizzPctFS.GetText then
            cachedPct = blizzPctFS:GetText()
          end
        end)
        RefreshTargetText()
      end)
    end

    if hb.GetMinMaxValues then
      local ok, minV, maxV = pcall(hb.GetMinMaxValues, hb)
      if ok then pcall(hp.SetMinMaxValues, hp, minV, maxV) end
    end
    if hb.GetValue then
      local ok, v = pcall(hb.GetValue, hb)
      if ok then pcall(hp.SetValue, hp, v); cachedHP = AbbrevAny(v) end
    end
    pcall(function()
      if blizzPctFS and blizzPctFS.GetText then cachedPct = blizzPctFS:GetText() end
    end)
  end

  local pb = GetBlizzardTargetPowerBar()
  if pb and not pb.__BravUI_TargetPowerMirrorHooked then
    pb.__BravUI_TargetPowerMirrorHooked = true

    if pb.SetMinMaxValues then
      hooksecurefunc(pb, "SetMinMaxValues", function(_bar, minV, maxV)
        pcall(power.SetMinMaxValues, power, minV, maxV)
      end)
    end
    if pb.SetValue then
      hooksecurefunc(pb, "SetValue", function(_bar, v)
        pcall(power.SetValue, power, v)
        RefreshPowerText()
      end)
    end

    if pb.GetMinMaxValues then
      local ok, minV, maxV = pcall(pb.GetMinMaxValues, pb)
      if ok then pcall(power.SetMinMaxValues, power, minV, maxV) end
    end
    if pb.GetValue then
      local ok, v = pcall(pb.GetValue, pb)
      if ok then pcall(power.SetValue, power, v); RefreshPowerText() end
    end
  end
end

-- ============================================================================
-- RANGE CHECK
-- ============================================================================
local RANGE_CHECK_INTERVAL = 0.2
local isOutOfRange         = false
local rangeCheckTicker     = nil

local function UpdateRangeAlpha()
  local existsOK, existsVal = pcall(UnitExists, "target")
  if not existsOK then return end
  local hasTarget = false
  pcall(function() if existsVal then hasTarget = true end end)
  if not hasTarget then return end

  local cfg         = GetConfig()
  local rangeEnabled = (cfg == nil) or (cfg.rangeEnabled ~= false)
  if not rangeEnabled then
    if isOutOfRange then isOutOfRange = false; f:SetAlpha(1.0) end
    return
  end

  local oorAlpha   = (cfg and cfg.outOfRangeAlpha) or 0.4
  local outOfRange = U.IsUnitOutOfRange("target")

  if not outOfRange then
    if isOutOfRange then isOutOfRange = false; f:SetAlpha(1.0) end
  else
    if not isOutOfRange then isOutOfRange = true; f:SetAlpha(oorAlpha) end
  end
end

local function StartRangeCheck()
  if rangeCheckTicker then return end
  rangeCheckTicker = C_Timer.NewTicker(RANGE_CHECK_INTERVAL, UpdateRangeAlpha)
end

local function StopRangeCheck()
  if rangeCheckTicker then rangeCheckTicker:Cancel(); rangeCheckTicker = nil end
  isOutOfRange = false
  f:SetAlpha(1.0)
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function Update()
  if not UnitExists("target") then
    if not InCombatLockdown() then f:Hide() end
    StopRangeCheck()
    return
  end

  if SafeUnitIsDead("target") then
    hp:SetMinMaxValues(0, 1); hp:SetValue(0)
    hp:SetStatusBarColor(0.4, 0.1, 0.1)
    power:SetMinMaxValues(0, 1); power:SetValue(0)
    power:SetStatusBarColor(0.2, 0.2, 0.2)
    pcall(function() hpNameText:SetText(UnitName("target") or "") end)
    hpStatsText:SetText("Mort")
    powerText:SetText("")
    U.UpdateRezIcon("target", rezHolder)
    wmHolder:Hide()
    ApplyAllBackgrounds()
    if not InCombatLockdown() then f:Show(); SyncClickOverlay() end
    StartRangeCheck()
    return
  end

  HookBlizzardMirrorOnce()
  UpdateColors()

  pcall(function()
    local maxHP = UnitHealthMax("target") or 1
    local curHP = UnitHealth("target")    or 0
    hp:SetMinMaxValues(0, maxHP)
    hp:SetValue(curHP)
    cachedHP = AbbrevAny(curHP)
  end)

  pcall(function()
    local hb2 = GetBlizzardTargetHealthBar()
    if hb2 then
      local fs = hb2.LeftText or hb2.TextString or hb2.RightText
      if fs and fs.GetText then cachedPct = fs:GetText() end
    end
  end)

  pcall(function()
    local maxP = UnitPowerMax("target") or 1
    local curP = UnitPower("target")    or 0
    power:SetMinMaxValues(0, maxP)
    power:SetValue(curP)
  end)

  ApplyAllBackgrounds()
  RefreshTargetText()
  U.UpdateRezIcon("target", rezHolder)
  U.UpdateWMIcon("target", wmHolder)

  if not InCombatLockdown() then f:Show(); SyncClickOverlay() end

  StartRangeCheck()
  UpdateRangeAlpha()
end

-- ============================================================================
-- EVENTS
-- ============================================================================
local MarkTargetDirty = U.CreateThrottler(0.05, Update)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UNIT_NAME_UPDATE")
ev:RegisterEvent("UNIT_CONNECTION")
ev:RegisterEvent("INCOMING_RESURRECT_CHANGED")
ev:RegisterEvent("UNIT_FLAGS")
ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
ev:RegisterEvent("UNIT_HEALTH")
ev:RegisterEvent("UNIT_MAXHEALTH")
ev:RegisterEvent("UNIT_POWER_UPDATE")
ev:RegisterEvent("UNIT_MAXPOWER")
ev:RegisterEvent("UNIT_DISPLAYPOWER")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_REGEN_ENABLED" then
    if clickOverlayDirty then SyncClickOverlay() end
    return
  end
  if event == "PLAYER_LOGIN" then
    ApplyFromDB()
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    Update()
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    ApplyFromDB()
    C_Timer.After(0,   Update)
    C_Timer.After(0.2, Update)
    return
  end
  if event == "INCOMING_RESURRECT_CHANGED"
  or event == "UNIT_FLAGS"
  or event == "PLAYER_FLAGS_CHANGED" then
    MarkTargetDirty()
    return
  end
  if unit == "target" then MarkTargetDirty() end
end)

C_Timer.After(0,   Update)
C_Timer.After(0.2, Update)

-- ============================================================================
-- EXPOSE
-- ============================================================================
BravUI.Frames         = BravUI.Frames or {}
BravUI.Frames.Target  = {
  Root              = f,
  ClickOverlay      = clickOverlay,
  HPFrame           = hpFrame,
  PowerFrame        = powerFrame,
  CastFrame         = castFrame,
  HPBar             = hp,
  PowerBar          = power,
  CastBar           = castBar,
  HPText            = hpNameText,
  HPStatsText       = hpStatsText,
  HPTextWrapper     = hpTextWrapper,
  PowerText         = powerText,
  PowerTextWrapper  = powerTextWrapper,
  RezHolder         = rezHolder,
  WMHolder          = wmHolder,
  ApplyFromDB       = ApplyFromDB,
  Refresh           = function()
    ApplyFromDB()
    UpdateColors()
    Update()
  end,
}

function BravUI:RefreshTargetUF()
  ApplyFromDB()
  UpdateColors()
  Update()
end

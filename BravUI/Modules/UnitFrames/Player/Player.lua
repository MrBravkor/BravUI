-- BravUI/Modules/UnitFrames/Player.lua
-- Player UnitFrame

local U                   = BravUI.Utils
local Create1pxBorder     = U.Create1pxBorder
local CreateBarBackground  = U.CreateBarBackground
local ApplyBG             = U.ApplyBG
local Abbrev              = U.AbbrevForSetText
local SafeUnitIsDead      = U.SafeUnitIsDead

-- ============================================================================
-- CONFIG
-- ============================================================================
local GAP          = 0
local CLASSPOWER_H = 7
local HP_H         = 26
local POWER_H      = 10
local DEFAULT_W    = 220

-- ============================================================================
-- DB CONFIG GETTERS
-- ============================================================================
local GetConfig, GetConfigValue, GetHeightConfig, GetColorConfig, GetTextConfig =
  U.MakeConfigGetters("player")

-- ============================================================================
-- FRAME (invisible container)
-- ============================================================================
local f = CreateFrame("Frame", "BravUI_PlayerFrame", UIParent)
f:SetSize(DEFAULT_W, CLASSPOWER_H + GAP + HP_H + GAP + POWER_H)
f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")

-- ============================================================================
-- SECURE CLICK OVERLAY
-- ============================================================================
local clickOverlay      = U.CreateClickOverlay("BravUI_PlayerClickOverlay", "player")
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
-- INDEPENDENT BAR FRAMES
-- ============================================================================
local classPowerFrame = CreateFrame("Frame", "BravUI_Player_ClassPowerFrame", f)
classPowerFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
classPowerFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
classPowerFrame:SetHeight(CLASSPOWER_H)
classPowerFrame:EnableMouse(false)

local hpFrame = CreateFrame("Frame", "BravUI_Player_HPFrame", f)
hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -(CLASSPOWER_H + GAP))
hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -(CLASSPOWER_H + GAP))
hpFrame:SetHeight(HP_H)
hpFrame:EnableMouse(false)

local powerFrame = CreateFrame("Frame", "BravUI_Player_PowerFrame", f)
powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, -GAP)
powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, -GAP)
powerFrame:SetHeight(POWER_H)
powerFrame:EnableMouse(false)

-- ============================================================================
-- CLASS POWER (top)
-- ============================================================================
local classPower = CreateFrame("StatusBar", "BravUI_Player_ClassPowerBar", classPowerFrame)
classPower:ClearAllPoints()
classPower:SetAllPoints(classPowerFrame)
classPower:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
classPower:SetMinMaxValues(0, 1)
classPower:Hide()
classPower:EnableMouse(false)
Create1pxBorder(classPower)
CreateBarBackground(classPower)

local segments    = {}
local segmentsMax = 0

local function HideSegments()
  for i = 1, segmentsMax do
    if segments[i] then segments[i]:Hide() end
  end
end

local function EnsureSegments(n)
  if n <= 0 then return end
  if segmentsMax ~= n then HideSegments(); segmentsMax = n end

  for i = 1, n do
    if not segments[i] then
      local s = CreateFrame("StatusBar", nil, classPowerFrame)
      s:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
      s:SetMinMaxValues(0, 1)
      s:SetValue(1)
      s:Hide()
      s:EnableMouse(false)
      segments[i] = s
      Create1pxBorder(s)
      CreateBarBackground(s)
    end
  end

  local w   = classPowerFrame:GetWidth() or (f:GetWidth() or DEFAULT_W)
  local gap = 3
  local segW = (w - (n - 1) * gap) / n
  local h    = classPowerFrame:GetHeight() or CLASSPOWER_H

  for i = 1, n do
    local s = segments[i]
    s:ClearAllPoints()
    if i == 1 then
      s:SetPoint("TOPLEFT", classPowerFrame, "TOPLEFT", 0, 0)
    else
      s:SetPoint("TOPLEFT", segments[i - 1], "TOPRIGHT", gap, 0)
    end
    s:SetSize(segW, h)
  end
end

local function ShowSegments(cur, max)
  EnsureSegments(max)
  for i = 1, max do
    local s = segments[i]
    s:Show()
    s:SetAlpha(i <= cur and 1 or 0.18)
  end
  classPower:Hide()
end

classPowerFrame:SetScript("OnSizeChanged", function()
  if segmentsMax and segmentsMax > 0 then EnsureSegments(segmentsMax) end
end)

-- ============================================================================
-- HEALTH BAR
-- ============================================================================
local hp         = U.CreateBar(hpFrame)
local hpNameText = U.CreateText(hp, "LEFT",  "LEFT",  13,  6, 0)
local hpStatsText = U.CreateText(hp, "RIGHT", "RIGHT", 13, -6, 0)

local hpTextWrapper = CreateFrame("Frame", "BravUI_Player_HPTextWrapper", hp)
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
-- Icons (Leader, Assist, Combat, Rez, WarMode)
-- ============================================================================
local leaderIcon = U.CreateLeaderIcon(hp, 16)
local assistIcon = U.CreateAssistIcon(hp, leaderIcon, 13)

local COMBAT_SIZE = 30
local combatIcon  = hp:CreateTexture(nil, "OVERLAY", nil, 2)
combatIcon:SetSize(COMBAT_SIZE, COMBAT_SIZE)
combatIcon:SetTexture("Interface/CharacterFrame/UI-StateIcon")
combatIcon:SetTexCoord(0.5, 1, 0, 0.5)
combatIcon:SetPoint("CENTER", hp, "CENTER", 0, 0)
combatIcon:Hide()

local rezHolder = U.CreateRezIcon(hp, 16)
local wmHolder  = U.CreateWMIcon(hp, 16)

-- ============================================================================
-- PLAYER HP TEXT (via Blizzard PlayerFrame hook)
-- ============================================================================
local cachedHP  = "0"
local cachedPct = "0%"

local function RefreshHPText()
  local nameCfg = GetTextConfig("name")
  if nameCfg and nameCfg.enabled == false then
    hpNameText:SetText("")
  else
    local name = UnitName("player") or ""
    hpNameText:SetText(name ~= "" and U.TruncateName(name, 10) or "")
  end

  local hpCfg = GetTextConfig("hp")
  if hpCfg and hpCfg.enabled == false then
    hpStatsText:SetText("")
    return
  end

  local fmt = "VALUE_PERCENT"
  if hpCfg and hpCfg.format then fmt = hpCfg.format end

  if     fmt == "VALUE"         then hpStatsText:SetText(cachedHP)
  elseif fmt == "PERCENT"       then hpStatsText:SetText(cachedPct)
  elseif fmt == "PERCENT_VALUE" then hpStatsText:SetText(cachedPct .. " | " .. cachedHP)
  elseif fmt == "NONE"          then hpStatsText:SetText("")
  else                               hpStatsText:SetText(cachedHP .. " | " .. cachedPct)
  end
end

local function GetBlizzardPlayerHealthBar()
  if PlayerFrame and PlayerFrame.healthbar  then return PlayerFrame.healthbar  end
  if PlayerFrame and PlayerFrame.HealthBar  then return PlayerFrame.HealthBar  end
  if _G.PlayerFrameHealthBar               then return _G.PlayerFrameHealthBar end
  return nil
end

local function HookBlizzardPlayerHPTextOnce()
  local bbar = GetBlizzardPlayerHealthBar()
  if not bbar or bbar.__BravUI_PlayerHPTextHooked then return end
  bbar.__BravUI_PlayerHPTextHooked = true

  hooksecurefunc(bbar, "SetValue", function(_bar, v)
    cachedHP = Abbrev(v)
    local lt = _bar.LeftText
    if lt and lt.GetText then
      local t = lt:GetText()
      if type(t) == "string" then cachedPct = t end
    end
    RefreshHPText()
  end)

  if bbar.GetValue    then cachedHP  = Abbrev(bbar:GetValue()) end
  if bbar.LeftText and bbar.LeftText.GetText then
    local t = bbar.LeftText:GetText()
    if type(t) == "string" then cachedPct = t end
  end

  RefreshHPText()
end

-- ============================================================================
-- POWER BAR
-- ============================================================================
local power      = U.CreateBar(powerFrame)
local powerText  = U.CreateText(power, "CENTER", "CENTER", 11, 0, 0)

local powerTextWrapper = CreateFrame("Frame", "BravUI_Player_PowerTextWrapper", power)
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
-- SECONDARY POWER
-- ============================================================================
local secondaryPowerType = nil

local SEGMENT_TYPES = {
  [Enum.PowerType.ComboPoints]   = true,
  [Enum.PowerType.HolyPower]     = true,
  [Enum.PowerType.SoulShards]    = true,
  [Enum.PowerType.Chi]           = true,
  [Enum.PowerType.ArcaneCharges] = true,
}

local CLASS_POWER_PRIORITY = {
  Enum.PowerType.ComboPoints,
  Enum.PowerType.HolyPower,
  Enum.PowerType.SoulShards,
  Enum.PowerType.Chi,
  Enum.PowerType.ArcaneCharges,
  Enum.PowerType.Runes,
}

local function PickSecondaryPowerType()
  secondaryPowerType = nil
  local _, mainPowerType = UnitPowerType("player")
  for _, pType in ipairs(CLASS_POWER_PRIORITY) do
    if pType ~= mainPowerType then
      local maxP = UnitPowerMax("player", pType)
      if maxP and maxP > 0 then
        secondaryPowerType = pType
        return
      end
    end
  end
end

local SetBarColorByKey = U.SetBarColorByKey

local function ApplyAllBackgrounds()
  ApplyBG(hp,         "player", "hp")
  ApplyBG(power,      "player", "power")
  ApplyBG(classPower, "player", "classPower")
  local segCfgKey = "segments"
  for i = 1, segmentsMax do
    local s = segments[i]
    if s then
      local db  = BravLib.Storage.GetDB()
      local uf  = db and db.unitframes and db.unitframes.player
      local hasSeg = uf and uf.backgrounds and uf.backgrounds[segCfgKey]
      ApplyBG(s, "player", hasSeg and segCfgKey or "classPower")
    end
  end
end

local function UpdateColors()
  local colorCfg = GetColorConfig()
  U.UpdateHPColor("player", hp, colorCfg)
  U.UpdatePowerColor("player", power, colorCfg)

  if secondaryPowerType then
    local useClassCP = not colorCfg or colorCfg.useClassColorCP ~= false
    local customCP   = colorCfg and colorCfg.classPowerCustom

    if not useClassCP and customCP and customCP.r then
      classPower:SetStatusBarColor(customCP.r, customCP.g, customCP.b)
      for i = 1, segmentsMax do
        if segments[i] then segments[i]:SetStatusBarColor(customCP.r, customCP.g, customCP.b) end
      end
    else
      if SEGMENT_TYPES[secondaryPowerType] then
        local sc = PowerBarColor and PowerBarColor[secondaryPowerType]
        local r, g, b = 0.9, 0.9, 0.9
        if sc and sc.r then r, g, b = sc.r, sc.g, sc.b end
        for i = 1, segmentsMax do
          if segments[i] then segments[i]:SetStatusBarColor(r, g, b) end
        end
      else
        SetBarColorByKey(classPower, secondaryPowerType)
      end
    end
  end

  ApplyAllBackgrounds()
end

-- ============================================================================
-- APPLY FROM DB
-- ============================================================================
local function ApplyFromDB()
  if InCombatLockdown() then return end

  local cfg = GetConfig() or {}

  if cfg.enabled == false then f:Hide(); return end
  f:Show()

  local s = U.ClampNum(cfg.scale, 0.5, 2.0, 1.0)
  f:SetScale(s)

  local px = U.ClampNum(cfg.posX, -2000, 2000, 0)
  local py = U.ClampNum(cfg.posY, -2000, 2000, -200)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", px / s, py / s)

  local w   = cfg.width or DEFAULT_W
  f:SetWidth(w)
  classPowerFrame:SetWidth(w)
  hpFrame:SetWidth(w)
  powerFrame:SetWidth(w)

  local showPower      = cfg.showPower      ~= false
  local showClassPower = cfg.showClassPower ~= false

  local cpH  = GetHeightConfig("classPower", CLASSPOWER_H)
  local hpH  = GetHeightConfig("hp",         HP_H)
  local pwrH = GetHeightConfig("power",      POWER_H)

  if showPower then powerFrame:Show(); power:Show()
  else              powerFrame:Hide(); power:Hide()
  end

  if showClassPower then
    classPowerFrame:Show()
  else
    classPowerFrame:Hide()
    classPower:Hide()
    HideSegments()
  end

  classPowerFrame:SetHeight(showClassPower and cpH or 0.001)
  hpFrame:SetHeight(hpH)
  powerFrame:SetHeight(showPower and pwrH or 0.001)

  classPower:SetHeight(cpH)
  hp:SetHeight(hpH)
  power:SetHeight(pwrH)

  local totalH = hpH
  if showClassPower then totalH = totalH + cpH  + GAP end
  if showPower      then totalH = totalH + pwrH + GAP end
  f:SetHeight(totalH)

  hpFrame:ClearAllPoints()
  if showClassPower then
    hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -(cpH + GAP))
    hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -(cpH + GAP))
  else
    hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  end

  powerFrame:ClearAllPoints()
  powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, showPower and -GAP or 0)
  powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, showPower and -GAP or 0)

  U.ApplyTextConfig(hpNameText,  GetTextConfig("name"),  hp,    "LEFT",   13,  6, 0)
  U.ApplyTextConfig(hpStatsText, GetTextConfig("hp"),    hp,    "RIGHT",  13, -6, 0)
  U.ApplyTextConfig(powerText,   GetTextConfig("power"), power, "CENTER", 11,  0, 0)

  if segmentsMax and segmentsMax > 0 then EnsureSegments(segmentsMax) end
  SyncClickOverlay()
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function Update()
  local unit = "player"
  local cfg  = GetConfig() or {}

  if cfg.enabled == false then f:Hide(); return end

  local showClassPowerOpt = cfg.showClassPower ~= false

  if not secondaryPowerType or not showClassPowerOpt then
    HideSegments(); classPower:Hide()
  else
    local curSP = UnitPower(unit, secondaryPowerType)    or 0
    local maxSP = UnitPowerMax(unit, secondaryPowerType) or 0

    if maxSP > 0 then
      if SEGMENT_TYPES[secondaryPowerType] then
        ShowSegments(curSP, maxSP)
      else
        HideSegments()
        classPower:Show()
        classPower:SetMinMaxValues(0, maxSP)
        classPower:SetValue(curSP)
      end
    else
      HideSegments(); classPower:Hide()
    end
  end

  ApplyAllBackgrounds()

  if SafeUnitIsDead(unit) then
    hp:SetMinMaxValues(0, 1); hp:SetValue(0)
    hp:SetStatusBarColor(0.4, 0.1, 0.1)
    power:SetMinMaxValues(0, 1); power:SetValue(0)
    power:SetStatusBarColor(0.2, 0.2, 0.2)
    local nameCfg = GetTextConfig("name")
    if not nameCfg or nameCfg.enabled ~= false then
      hpNameText:SetText(U.TruncateName(UnitName(unit) or "", 10))
    end
    local hpCfg = GetTextConfig("hp")
    if not hpCfg or hpCfg.enabled ~= false then
      hpStatsText:SetText("Mort")
    end
    powerText:SetText("")
    U.UpdateRezIcon("player", rezHolder)
    wmHolder:Hide()
    return
  end

  local curHP = UnitHealth(unit)    or 0
  local maxHP = UnitHealthMax(unit) or 1
  hp:SetMinMaxValues(0, maxHP)
  hp:SetValue(curHP)

  local curP = UnitPower(unit)    or 0
  local maxP = UnitPowerMax(unit) or 1
  power:SetMinMaxValues(0, maxP)
  power:SetValue(curP)

  local pwrCfg = GetTextConfig("power")
  if pwrCfg and pwrCfg.enabled == false then
    powerText:SetText("")
  else
    local pwrFmt = "VALUE"
    if pwrCfg and pwrCfg.format then pwrFmt = pwrCfg.format end
    if pwrFmt == "NONE" then
      powerText:SetText("")
    else
      powerText:SetText(Abbrev(curP))
    end
  end

  U.UpdateLeaderIcons("player", leaderIcon, assistIcon)
  U.UpdateRezIcon("player", rezHolder)
  U.UpdateWMIcon("player", wmHolder)
end

-- ============================================================================
-- EVENT THROTTLE
-- ============================================================================
local MarkPlayerDirty = U.CreateThrottler(0.05, function()
  HookBlizzardPlayerHPTextOnce()
  Update()
end)

-- ============================================================================
-- EVENTS
-- ============================================================================
local _inCombat = InCombatLockdown()

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_DISPLAYPOWER")
f:RegisterEvent("UNIT_POWER_UPDATE")
f:RegisterEvent("UNIT_MAXPOWER")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("UNIT_NAME_UPDATE")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PARTY_LEADER_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("INCOMING_RESURRECT_CHANGED")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")

f:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_REGEN_DISABLED" then
    _inCombat = true
    combatIcon:Show()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    _inCombat = false
    combatIcon:Hide()
    if clickOverlayDirty then SyncClickOverlay() end
    return
  end
  if event == "INCOMING_RESURRECT_CHANGED" then
    MarkPlayerDirty()
    return
  end
  if unit and unit ~= "player" then return end

  if event == "PLAYER_LOGIN"
  or event == "PLAYER_ENTERING_WORLD"
  or event == "PLAYER_SPECIALIZATION_CHANGED"
  or event == "PLAYER_TARGET_CHANGED" then
    ApplyFromDB()
    PickSecondaryPowerType()
    UpdateColors()
    HookBlizzardPlayerHPTextOnce()
    Update()
    if _inCombat then combatIcon:Show() else combatIcon:Hide() end
    return
  end

  if event == "UNIT_DISPLAYPOWER" then
    PickSecondaryPowerType()
    UpdateColors()
  end

  MarkPlayerDirty()
end)

-- ============================================================================
-- INIT (delayed)
-- ============================================================================
C_Timer.After(0.1, function()
  ApplyFromDB()
  PickSecondaryPowerType()
  UpdateColors()
  HookBlizzardPlayerHPTextOnce()
  Update()
end)

-- ============================================================================
-- EXPOSE (pour refresh externe depuis menu)
-- ============================================================================
BravUI.Frames         = BravUI.Frames or {}
BravUI.Frames.Player  = {
  Root            = f,
  ClickOverlay    = clickOverlay,
  ClassPowerFrame = classPowerFrame,
  HPFrame         = hpFrame,
  PowerFrame      = powerFrame,
  CastAnchor      = powerFrame,
  ClassPowerBar   = classPower,
  HPBar           = hp,
  PowerBar        = power,
  HPText          = hpNameText,
  HPStatsText     = hpStatsText,
  PowerText       = powerText,
  PowerTextWrapper = powerTextWrapper,
  HPTextWrapper   = hpTextWrapper,
  Segments        = segments,
  LeaderIcon      = leaderIcon,
  AssistIcon      = assistIcon,
  CombatIcon      = combatIcon,
  RezHolder       = rezHolder,
  WMHolder        = wmHolder,
  ApplyFromDB     = ApplyFromDB,
  Refresh         = function()
    ApplyFromDB()
    RefreshHPText()
    UpdateColors()
    Update()
  end,
}

function BravUI:RefreshPlayerUF()
  ApplyFromDB()
  RefreshHPText()
  UpdateColors()
  Update()
end

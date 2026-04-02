-- BravUI/Modules/Misc/AFK.lua
-- Mode AFK — overlay cinématique (barres top/bottom + infos joueur/système/timer)
-- Portage v2 : no Ace, no external dependencies

local BravUI = BravUI
local U = BravUI.Utils
local GetClassColor = function() return U.GetClassColor("player") end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local AFK = {}
BravUI:RegisterModule("Misc.AFK", AFK)

-- ============================================================================
-- DB HELPER
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("afk") or {}
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local LOGOUT_SECONDS = 30 * 60  -- 30 minutes

-- ============================================================================
-- STATE
-- ============================================================================

AFK.isAFK            = false
AFK.startTime        = nil
AFK.elapsed          = 0
AFK.ticker           = nil
AFK.uiParentWasShown = nil
AFK.pendingUIAction  = nil

-- ============================================================================
-- HELPERS
-- ============================================================================

function AFK:FormatTime(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then
    return string.format("%02d:%02d:%02d", h, m, s)
  end
  return string.format("%02d:%02d", m, s)
end

function AFK:GetLogoutRemaining()
  if not self.isAFK or not self.startTime then return nil end
  return LOGOUT_SECONDS - (GetTime() - self.startTime)
end

-- ============================================================================
-- UIParent HANDLING
-- ============================================================================

function AFK:HideGameUI()
  if InCombatLockdown() then
    self.pendingUIAction = "hide"
    return
  end
  self.uiParentWasShown = UIParent:IsShown()
  if self.uiParentWasShown then UIParent:Hide() end
end

function AFK:ShowGameUI()
  if InCombatLockdown() then
    self.pendingUIAction = "show"
    return
  end
  if self.uiParentWasShown then UIParent:Show() end
  self.uiParentWasShown = nil
end

function AFK:ApplyPendingUIAction()
  if not self.pendingUIAction or InCombatLockdown() then return end
  if self.pendingUIAction == "hide" then self:HideGameUI() end
  if self.pendingUIAction == "show" then self:ShowGameUI() end
  self.pendingUIAction = nil
end

-- ============================================================================
-- AFK LIFECYCLE
-- ============================================================================

function AFK:EnterAFK()
  local db = GetDB()
  if db.enabled == false then return end

  self.isAFK    = true
  self.startTime = GetTime()
  self.elapsed   = 0

  self:HideGameUI()
  self:ShowUI()
  self:UpdateUI()
end

function AFK:LeaveAFK()
  self.isAFK     = false
  self.startTime = nil
  self.elapsed   = 0

  self:HideUI()
  self:ShowGameUI()

  -- Re-applique les frames BravUI après que UIParent:Show() restaure le layout Blizzard
  C_Timer.After(0.1, function()
    BravLib.Hooks.Fire("APPLY_ALL")
  end)
end

-- ============================================================================
-- TICKER
-- ============================================================================

function AFK:EnsureTicker()
  if self.ticker then return end
  self.ticker = C_Timer.NewTicker(1, function()
    if self.isAFK and self.startTime then
      self.elapsed = GetTime() - self.startTime
      self:UpdateUI()
    end
  end)
end

-- ============================================================================
-- MEDIA
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"

local P = {
  BG    = { 0.06, 0.06, 0.08, 0.96 },
  MUTED = { 0.50, 0.50, 0.55, 1 },
}

local BAR_H       = 95
local SIDE_MARGIN = 30
local LINE1_Y     = 12
local LINE_SPACING = 4
local SEP_WIDTH   = 80
local SEP_MARGIN  = 30

local function GetLogo()
  return BravLib.Media.Get("texture", "logo")
      or "Interface/AddOns/BravUI_Lib/BravLib_Media/Logo/BravUI_64x64.tga"
end

-- ============================================================================
-- API HELPERS
-- ============================================================================

local function GetAddOnMeta(name, field)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(name, field)
  end
  if GetAddOnMetadata then
    return GetAddOnMetadata(name, field)
  end
end

local function GetNumAddOnsCompat()
  if C_AddOns and C_AddOns.GetNumAddOns then
    return C_AddOns.GetNumAddOns()
  end
  if GetNumAddOns then return GetNumAddOns() end
  return 0
end

-- ============================================================================
-- DATA BUILDERS
-- ============================================================================

local function GetSpecName()
  if not GetSpecialization then return nil end
  local i = GetSpecialization()
  if not i then return nil end
  local _, name = GetSpecializationInfo(i)
  return name
end

local function GetPlayerLine1()
  local name  = UnitName("player") or "Player"
  local level = UnitLevel("player") or 0
  return string.format("Nom : %s  |  Lvl : %d", name, level)
end

local function GetPlayerLine2()
  local className = select(1, UnitClass("player")) or "Classe"
  local spec = GetSpecName()
  if spec then
    return string.format("Classe : %s  |  Spe : %s", className, spec)
  end
  return string.format("Classe : %s", className)
end

local function GetZoneLine1()
  return string.format("Zone : %s", GetRealZoneText() or "Zone inconnue")
end

local function GetZoneLine2()
  local sub  = GetSubZoneText() or ""
  local zone = GetRealZoneText() or ""
  if sub ~= "" and sub ~= zone then return sub end
  return ""
end

local function GetSystemLine1()
  local v       = GetAddOnMeta("BravUI", "Version") or "dev"
  local gameVer = GetBuildInfo() or "?"
  return string.format("BravUI : v%s  |  WoW : %s", v, gameVer)
end

local function GetSystemLine2()
  local addons = GetNumAddOnsCompat()
  local mem    = (collectgarbage("count") or 0) / 1024
  return string.format("AddOns : %d  |  Lua : %.1fMb", addons, mem)
end

local function IsAddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

local ICON_CHECK = "|A:common-icon-checkmark:12:12|a"

local function GetPluginsLine()
  local cdm = IsAddonLoaded("BravUI_Cooldown")
  local sct = IsAddonLoaded("BravUI_CombatText")
  if cdm and sct then return "CDM | SCT charge " .. ICON_CHECK end
  if cdm then return "CDM charge " .. ICON_CHECK end
  if sct then return "SCT charge " .. ICON_CHECK end
  return nil
end

local function GetTimeLine1()
  local h, m   = GetGameTime()
  local realTime = date("%H:%M")
  return string.format("Jeu : %02dh%02d  |  Reel : %s", h, m, realTime)
end

local function GetTimeLine2()
  local fps          = GetFramerate and math.floor(GetFramerate() + 0.5) or 0
  local _, _, home, world = GetNetStats()
  home, world = home or 0, world or 0
  return string.format("FPS : %d  |  Latence : %d/%dms", fps, home, world)
end

-- ============================================================================
-- SEPARATOR HELPER
-- ============================================================================

local function CreateSeparator(parent, r, g, b, width, alpha)
  local sep = parent:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetWidth(width or 80)
  sep:SetColorTexture(r, g, b, alpha or 0.15)
  return sep
end

-- ============================================================================
-- UI CREATION
-- ============================================================================

function AFK:CreateUI()
  if self.frame then return end

  local font = U.GetFont()
  local r, g, b = GetClassColor()

  local f = CreateFrame("Frame", "BravUI_AFKOverlay", WorldFrame)
  f:SetAllPoints(WorldFrame)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:Hide()

  -- ── Top bar ──
  local top = f:CreateTexture(nil, "BACKGROUND")
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(BAR_H)
  top:SetColorTexture(P.BG[1], P.BG[2], P.BG[3], P.BG[4])

  local topLine = f:CreateTexture(nil, "BORDER")
  topLine:SetPoint("TOP", top, "BOTTOM")
  topLine:SetPoint("LEFT")
  topLine:SetPoint("RIGHT")
  topLine:SetHeight(1)
  topLine:SetColorTexture(r, g, b, 0.20)

  -- ── Bottom bar ──
  local bottom = f:CreateTexture(nil, "BACKGROUND")
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(BAR_H)
  bottom:SetColorTexture(P.BG[1], P.BG[2], P.BG[3], P.BG[4])

  local bottomLine = f:CreateTexture(nil, "BORDER")
  bottomLine:SetPoint("BOTTOM", bottom, "TOP")
  bottomLine:SetPoint("LEFT")
  bottomLine:SetPoint("RIGHT")
  bottomLine:SetHeight(1)
  bottomLine:SetColorTexture(r, g, b, 0.20)

  -- ============================================
  -- TOP BAR CONTENT
  -- ============================================
  local topWrap = CreateFrame("Frame", nil, f)
  topWrap:SetSize(1400, 90)
  topWrap:SetPoint("CENTER", f, "TOP", 0, -(BAR_H / 2))

  -- LEFT: Player info
  local playerLine1 = topWrap:CreateFontString(nil, "ARTWORK")
  playerLine1:SetPoint("LEFT", topWrap, "LEFT", SIDE_MARGIN, LINE1_Y)
  U.SafeSetFont(playerLine1, font, 12)
  playerLine1:SetText(GetPlayerLine1())
  playerLine1:SetTextColor(r, g, b)

  local playerLine2 = topWrap:CreateFontString(nil, "ARTWORK")
  playerLine2:SetPoint("TOPLEFT", playerLine1, "BOTTOMLEFT", 0, -LINE_SPACING)
  U.SafeSetFont(playerLine2, font, 11)
  playerLine2:SetText(GetPlayerLine2())
  playerLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  -- CENTER: Logo + BravUI AFK
  local logo = topWrap:CreateTexture(nil, "ARTWORK")
  logo:SetSize(48, 48)
  logo:SetPoint("CENTER", topWrap, "CENTER", -50, 0)
  logo:SetTexture(GetLogo())

  local title = topWrap:CreateFontString(nil, "ARTWORK")
  title:SetPoint("LEFT", logo, "RIGHT", 10, 8)
  U.SafeSetFont(title, font, 18)
  title:SetText("BravUI")
  title:SetTextColor(r, g, b)

  local afkText = topWrap:CreateFontString(nil, "ARTWORK")
  afkText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  U.SafeSetFont(afkText, font, 11)
  afkText:SetText("Mode AFK")
  afkText:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  local sepTop1 = CreateSeparator(topWrap, r, g, b, SEP_WIDTH, 0.15)
  sepTop1:SetPoint("RIGHT", logo, "LEFT", -SEP_MARGIN, 0)

  local sepTop2 = CreateSeparator(topWrap, r, g, b, SEP_WIDTH, 0.15)
  sepTop2:SetPoint("LEFT", title, "RIGHT", SEP_MARGIN, -8)

  -- RIGHT: Zone info
  local zoneLine1 = topWrap:CreateFontString(nil, "ARTWORK")
  zoneLine1:SetPoint("RIGHT", topWrap, "RIGHT", -SIDE_MARGIN, LINE1_Y)
  U.SafeSetFont(zoneLine1, font, 12)
  zoneLine1:SetText(GetZoneLine1())
  zoneLine1:SetTextColor(r, g, b)

  local zoneLine2 = topWrap:CreateFontString(nil, "ARTWORK")
  zoneLine2:SetPoint("TOPRIGHT", zoneLine1, "BOTTOMRIGHT", 0, -LINE_SPACING)
  U.SafeSetFont(zoneLine2, font, 11)
  zoneLine2:SetText(GetZoneLine2())
  zoneLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  f.sepTop1 = sepTop1
  f.sepTop2 = sepTop2

  -- ============================================
  -- BOTTOM BAR CONTENT
  -- ============================================
  local bottomWrap = CreateFrame("Frame", nil, f)
  bottomWrap:SetSize(1400, 90)
  bottomWrap:SetPoint("CENTER", f, "BOTTOM", 0, (BAR_H / 2))

  -- LEFT: System info
  local systemLine1 = bottomWrap:CreateFontString(nil, "ARTWORK")
  systemLine1:SetPoint("LEFT", bottomWrap, "LEFT", SIDE_MARGIN, LINE1_Y)
  U.SafeSetFont(systemLine1, font, 12)
  systemLine1:SetText(GetSystemLine1())
  systemLine1:SetTextColor(r, g, b)

  local pluginsLine = bottomWrap:CreateFontString(nil, "ARTWORK")
  U.SafeSetFont(pluginsLine, font, 11)
  pluginsLine:SetTextColor(r, g, b)
  local pluginsText = GetPluginsLine()
  if pluginsText then
    pluginsLine:SetPoint("TOPLEFT", systemLine1, "BOTTOMLEFT", 0, -LINE_SPACING)
    pluginsLine:SetText(pluginsText)
    pluginsLine:Show()
  else
    pluginsLine:Hide()
  end

  local systemLine2 = bottomWrap:CreateFontString(nil, "ARTWORK")
  systemLine2:SetPoint("TOPLEFT", pluginsText and pluginsLine or systemLine1, "BOTTOMLEFT", 0, -LINE_SPACING)
  U.SafeSetFont(systemLine2, font, 11)
  systemLine2:SetText(GetSystemLine2())
  systemLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  -- CENTER: Timer AFK
  local timer = bottomWrap:CreateFontString(nil, "ARTWORK")
  timer:SetPoint("CENTER", bottomWrap, "CENTER", 0, 12)
  U.SafeSetFont(timer, font, 36)
  timer:SetText("00:00")
  timer:SetTextColor(r, g, b)

  local logoutTimer = bottomWrap:CreateFontString(nil, "ARTWORK")
  logoutTimer:SetPoint("TOP", timer, "BOTTOM", 0, -2)
  U.SafeSetFont(logoutTimer, font, 12)
  logoutTimer:SetText("Deco : --:--")
  logoutTimer:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  local sep1 = CreateSeparator(bottomWrap, r, g, b, SEP_WIDTH, 0.15)
  sep1:SetPoint("RIGHT", timer, "LEFT", -SEP_MARGIN, 0)

  local sep2 = CreateSeparator(bottomWrap, r, g, b, SEP_WIDTH, 0.15)
  sep2:SetPoint("LEFT", timer, "RIGHT", SEP_MARGIN, 0)

  -- RIGHT: Time/FPS
  local timeLine1 = bottomWrap:CreateFontString(nil, "ARTWORK")
  timeLine1:SetPoint("RIGHT", bottomWrap, "RIGHT", -SIDE_MARGIN, LINE1_Y)
  U.SafeSetFont(timeLine1, font, 12)
  timeLine1:SetText(GetTimeLine1())
  timeLine1:SetTextColor(r, g, b)

  local timeLine2 = bottomWrap:CreateFontString(nil, "ARTWORK")
  timeLine2:SetPoint("TOPRIGHT", timeLine1, "BOTTOMRIGHT", 0, -LINE_SPACING)
  U.SafeSetFont(timeLine2, font, 11)
  timeLine2:SetText(GetTimeLine2())
  timeLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])

  f.sep1 = sep1
  f.sep2 = sep2

  -- ============================================
  -- STORE REFERENCES
  -- ============================================
  self.frame          = f
  self.timerText      = timer
  self.logoutTimerText = logoutTimer
  self.playerLine1    = playerLine1
  self.playerLine2    = playerLine2
  self.zoneLine1      = zoneLine1
  self.zoneLine2      = zoneLine2
  self.systemLine1    = systemLine1
  self.pluginsLine    = pluginsLine
  self.systemLine2    = systemLine2
  self.timeLine1      = timeLine1
  self.timeLine2      = timeLine2
  self.topLine        = topLine
  self.bottomLine     = bottomLine
end

-- ============================================================================
-- SHOW / HIDE / UPDATE
-- ============================================================================

function AFK:ShowUI()
  self:CreateUI()

  local r, g, b = GetClassColor()

  if self.playerLine1 then self.playerLine1:SetText(GetPlayerLine1()) ; self.playerLine1:SetTextColor(r, g, b) end
  if self.playerLine2 then self.playerLine2:SetText(GetPlayerLine2()) ; self.playerLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3]) end
  if self.zoneLine1   then self.zoneLine1:SetText(GetZoneLine1())     ; self.zoneLine1:SetTextColor(r, g, b) end
  if self.zoneLine2   then self.zoneLine2:SetText(GetZoneLine2())     ; self.zoneLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3]) end
  if self.systemLine1 then self.systemLine1:SetText(GetSystemLine1()) ; self.systemLine1:SetTextColor(r, g, b) end
  if self.systemLine2 then self.systemLine2:SetText(GetSystemLine2()) ; self.systemLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3]) end
  if self.timeLine1   then self.timeLine1:SetText(GetTimeLine1())     ; self.timeLine1:SetTextColor(r, g, b) end
  if self.timeLine2   then self.timeLine2:SetText(GetTimeLine2())     ; self.timeLine2:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3]) end

  if self.pluginsLine then
    local pluginsText = GetPluginsLine()
    if pluginsText then
      self.pluginsLine:SetText(pluginsText)
      self.pluginsLine:SetTextColor(r, g, b)
      self.pluginsLine:Show()
    else
      self.pluginsLine:Hide()
    end
  end

  if self.topLine    then self.topLine:SetColorTexture(r, g, b, 0.20) end
  if self.bottomLine then self.bottomLine:SetColorTexture(r, g, b, 0.20) end
  if self.frame.sep1    then self.frame.sep1:SetColorTexture(r, g, b, 0.15) end
  if self.frame.sep2    then self.frame.sep2:SetColorTexture(r, g, b, 0.15) end
  if self.frame.sepTop1 then self.frame.sepTop1:SetColorTexture(r, g, b, 0.15) end
  if self.frame.sepTop2 then self.frame.sepTop2:SetColorTexture(r, g, b, 0.15) end

  self.frame:Show()
end

function AFK:HideUI()
  if self.frame then self.frame:Hide() end
end

function AFK:UpdateUI()
  local r, g, b = GetClassColor()

  if self.timerText then
    self.timerText:SetText(self:FormatTime(self.elapsed))
    self.timerText:SetTextColor(r, g, b)
  end

  if self.logoutTimerText then
    local rem = self:GetLogoutRemaining()
    if not rem then
      self.logoutTimerText:SetText("Deco : --:--")
      self.logoutTimerText:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])
    elseif rem <= 0 then
      self.logoutTimerText:SetText("Deco imminente !")
      self.logoutTimerText:SetTextColor(1, 0.3, 0.3)
    elseif rem <= 300 then
      self.logoutTimerText:SetText("Deco : " .. self:FormatTime(rem))
      self.logoutTimerText:SetTextColor(1, 0.6, 0.3)
    else
      self.logoutTimerText:SetText("Deco : " .. self:FormatTime(rem))
      self.logoutTimerText:SetTextColor(P.MUTED[1], P.MUTED[2], P.MUTED[3])
    end
  end

  if self.timeLine1 then self.timeLine1:SetText(GetTimeLine1()) end
  if self.timeLine2 then self.timeLine2:SetText(GetTimeLine2()) end
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function AFK:Enable()
  local db = GetDB()
  if db.enabled == false then return end

  self:EnsureTicker()

  local function EvaluateAFK()
    local isAFK = UnitIsAFK("player")
    if isAFK and not AFK.isAFK then
      AFK:EnterAFK()
    elseif not isAFK and AFK.isAFK then
      AFK:LeaveAFK()
    end
  end

  BravLib.Event.Register("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit == "player" then EvaluateAFK() end
  end)

  BravLib.Event.Register("PLAYER_ENTERING_WORLD", function()
    EvaluateAFK()
  end)

  BravLib.Event.Register("PLAYER_REGEN_ENABLED", function()
    AFK:ApplyPendingUIAction()
  end)

  C_Timer.After(0, EvaluateAFK)
end

function AFK:Disable()
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
  self:LeaveAFK()
end

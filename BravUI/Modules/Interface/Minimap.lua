-- BravUI/Modules/Interface/Minimap.lua
-- Minimap custom panel — borders class-colored, header/footer, zone text, clock

local BravUI = BravUI
local U = BravUI.Utils

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local Minimap = {}
BravUI:RegisterModule("Interface.Minimap", Minimap)

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX      = "Interface/Buttons/WHITE8x8"
local BORDER_W = 2
local TAB_ZONE = 22
local BOT_ZONE = 22

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("minimap") or {}
end

local function GetFont()
  return BravUI.Utils.GetFont()
end

local function GetClassColor()
  return U.GetClassColor("player")
end

local function MakeBorder(parent, cr, cg, cb)
  local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  t:SetTexture(TEX)
  t:SetVertexColor(cr, cg, cb, 1)
  return t
end

local function StripTextures(frame)
  if not frame or not frame.GetRegions then return end
  for i = 1, select("#", frame:GetRegions()) do
    local r = select(i, frame:GetRegions())
    if r and r.GetObjectType and r:GetObjectType() == "Texture" then
      r:SetTexture(nil)
      r:Hide()
    end
  end
end

local function Kill(frame)
  if not frame then return end
  frame:Hide()
  frame:SetAlpha(0)
  frame.Show = function() end
end

local function SafeHide(frame)
  if not frame then return end
  frame:Hide()
  frame:SetAlpha(0)
end

local function TintFrameTextures(frame, r, g, b, a)
  if not frame then return end
  a = a or 0.8
  for i = 1, select("#", frame:GetRegions()) do
    local reg = select(i, frame:GetRegions())
    if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" and reg:IsShown() then
      reg:SetDesaturated(true)
      reg:SetVertexColor(r, g, b, a)
    end
  end
  for i = 1, select("#", frame:GetChildren()) do
    local child = select(i, frame:GetChildren())
    if child and child.GetRegions then
      for j = 1, select("#", child:GetRegions()) do
        local reg = select(j, child:GetRegions())
        if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" and reg:IsShown() then
          reg:SetDesaturated(true)
          reg:SetVertexColor(r, g, b, a)
        end
      end
    end
  end
end

-- ============================================================================
-- TRACKING BUTTON (noms varient selon version WoW)
-- ============================================================================

local function GetTrackingButton()
  if _G.MiniMapTrackingButton then return _G.MiniMapTrackingButton end
  if _G.MiniMapTracking then return _G.MiniMapTracking end
  if _G.MinimapCluster then
    if _G.MinimapCluster.TrackingFrame then return _G.MinimapCluster.TrackingFrame end
    if _G.MinimapCluster.Tracking then return _G.MinimapCluster.Tracking end
    if _G.MinimapCluster.MiniMapTracking then return _G.MinimapCluster.MiniMapTracking end
  end
  return nil
end

-- ============================================================================
-- COUNTS (Contacts / Guilde)
-- ============================================================================

local function GetContactCount()
  local online = 0
  pcall(function()
    if _G.C_FriendList and _G.C_FriendList.GetNumOnlineFriends then
      local n = _G.C_FriendList.GetNumOnlineFriends()
      if n and type(n) == "number" then online = online + n end
    end
  end)
  pcall(function()
    if _G.BNGetNumFriends then
      local numTotal, numOnline = _G.BNGetNumFriends()
      if numOnline and type(numOnline) == "number" then online = online + numOnline end
    end
  end)
  return online
end

local function GetGuildCount()
  if not _G.IsInGuild or not _G.IsInGuild() then return 0, 0 end
  if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
    pcall(_G.C_GuildInfo.GuildRoster)
  elseif type(_G.GuildRoster) == "function" then
    pcall(_G.GuildRoster)
  end
  if type(_G.GetNumGuildMembers) == "function" then
    local total, online = _G.GetNumGuildMembers()
    return (online or 0), (total or 0)
  end
  return 0, 0
end

-- ============================================================================
-- PURGE BLIZZARD
-- ============================================================================

local function PurgeBlizzardRoundArt()
  if _G.MinimapBorder then Kill(_G.MinimapBorder) end
  if _G.MinimapBorderTop then Kill(_G.MinimapBorderTop) end

  if _G.MinimapCompassTexture then Kill(_G.MinimapCompassTexture) end
  if _G.MinimapCompassFrame then StripTextures(_G.MinimapCompassFrame) end
  if _G.MinimapNorthTag then Kill(_G.MinimapNorthTag) end

  Kill(_G.MinimapZoomIn)
  Kill(_G.MinimapZoomOut)
  local mm = _G.Minimap
  if mm then
    if mm.ZoomIn then Kill(mm.ZoomIn) end
    if mm.ZoomOut then Kill(mm.ZoomOut) end
    for i = 1, select("#", mm:GetChildren()) do
      local child = select(i, mm:GetChildren())
      if child and not child:IsForbidden() then
        local n = child.GetName and child:GetName() or ""
        if n:find("Zoom", 1, true) then Kill(child) end
      end
    end
  end
  local mc = _G.MinimapCluster
  if mc then
    if mc.ZoomIn then Kill(mc.ZoomIn) end
    if mc.ZoomOut then Kill(mc.ZoomOut) end
  end

  if _G.MinimapToggleButton then StripTextures(_G.MinimapToggleButton) end

  if mc then
    StripTextures(mc)
    if mc.BorderTop then Kill(mc.BorderTop) end
    if mc.MinimapContainer then StripTextures(mc.MinimapContainer) end
    if mc.Overlay then Kill(mc.Overlay) end
  end

  if _G.MinimapHeaderUnderlayFrame then Kill(_G.MinimapHeaderUnderlayFrame) end

  local zoneBtn = (mc and mc.ZoneTextButton) or _G.MinimapZoneTextButton
  if zoneBtn then Kill(zoneBtn) end

  if not _G.TimeManagerClockButton and _G.LoadAddOn then
    pcall(_G.LoadAddOn, "Blizzard_TimeManager")
  end
  if _G.TimeManagerClockButton then Kill(_G.TimeManagerClockButton) end

  local elpBtn = _G.ExpansionLandingPageMinimapButton
  if elpBtn then
    elpBtn:Hide()
    elpBtn:SetAlpha(0)
    if not elpBtn._bravV2Hooked then
      hooksecurefunc(elpBtn, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
      elpBtn._bravV2Hooked = true
    end
  end
end

-- ============================================================================
-- HIDE ADDON MINIMAP BUTTONS (LibDBIcon, etc.)
-- ============================================================================

local SAFE_CHILDREN = {
  ["BravUI_MinimapV2"] = true,
}

local function HideAddonMinimapButtons()
  local mm = _G.Minimap
  if not mm then return end

  for i = 1, select("#", mm:GetChildren()) do
    local child = select(i, mm:GetChildren())
    if child and not child:IsForbidden() then
      local n = child.GetName and child:GetName() or ""
      if n:find("LibDBIcon", 1, true)
         or n:find("MinimapButton", 1, true)
         or (n ~= "" and not SAFE_CHILDREN[n] and child:IsShown()
             and child.GetObjectType and child:GetObjectType() == "Button"
             and not n:find("Minimap", 1, true)) then
        child:Hide()
        child:SetAlpha(0)
        if not child._bravHidden then
          hooksecurefunc(child, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
          child._bravHidden = true
        end
      end
    end
  end

  local bd = _G.MinimapBackdrop
  if bd then
    for i = 1, select("#", bd:GetChildren()) do
      local child = select(i, bd:GetChildren())
      if child and not child:IsForbidden() then
        local n = child.GetName and child:GetName() or ""
        if n:find("LibDBIcon", 1, true) then
          child:Hide()
          child:SetAlpha(0)
          if not child._bravHidden then
            hooksecurefunc(child, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
            child._bravHidden = true
          end
        end
      end
    end
  end
end

-- ============================================================================
-- APPLY LAYOUT
-- ============================================================================

local function ApplyLayout(panel, db)
  local showHeader = db.showHeader ~= false
  local showFooter = db.showFooter ~= false
  local showCal    = showHeader and db.showCalendar ~= false
  local showTrack  = showHeader and db.showTracking ~= false
  local showClk    = showHeader and db.showClock ~= false
  local showComp   = db.showCompartment ~= false

  local mapW = db.panelWidth or 250
  local mapH = db.panelHeight or 250

  local hdrH   = showHeader and TAB_ZONE or 0
  local ftrH   = showFooter and BOT_ZONE or 0
  local hdrSep = showHeader and 1 or 0
  local ftrSep = showFooter and 1 or 0
  local totalH = BORDER_W + hdrH + hdrSep + mapH + ftrSep + ftrH + BORDER_W
  local totalW = mapW + BORDER_W * 2
  panel:SetSize(totalW, totalH)

  panel._bg:SetVertexColor(0, 0, 0, db.opacity or 0.75)

  if panel._tabZone then
    if showHeader then panel._tabZone:Show() else panel._tabZone:Hide() end
  end
  if panel._tabSep then
    if showHeader then panel._tabSep:Show() else panel._tabSep:Hide() end
  end

  local hdrIconSz = db.headerIconSize or 16
  local mailSz    = db.mailIconSize or 18
  local diffSz    = db.diffIconSize or 24
  local compartSz = db.compartIconSize or 20

  if showHeader then
    if panel._calendarHolder then
      panel._calendarHolder:SetSize(hdrIconSz, hdrIconSz)
      if panel._calendar then pcall(panel._calendar.SetSize, panel._calendar, hdrIconSz, hdrIconSz) end
      if showCal then panel._calendarHolder:Show() else panel._calendarHolder:Hide() end
    end
    if panel._trackHolder then
      panel._trackHolder:SetSize(hdrIconSz, hdrIconSz)
      if panel._tracking then pcall(panel._tracking.SetSize, panel._tracking, hdrIconSz, hdrIconSz) end
      panel._trackHolder:ClearAllPoints()
      if showCal then
        panel._trackHolder:SetPoint("LEFT", panel._calendarHolder, "RIGHT", 4, 0)
      else
        panel._trackHolder:SetPoint("LEFT", panel._tabZone, "LEFT", 4, -1)
      end
      if showTrack then panel._trackHolder:Show() else panel._trackHolder:Hide() end
    end
    if panel._clockBtn then
      if showClk then panel._clockBtn:Show() else panel._clockBtn:Hide() end
    end
    if panel._zoneBtn then
      panel._zoneBtn:ClearAllPoints()
      if showTrack and panel._trackHolder then
        panel._zoneBtn:SetPoint("LEFT", panel._trackHolder, "RIGHT", 4, 0)
      elseif showCal and panel._calendarHolder then
        panel._zoneBtn:SetPoint("LEFT", panel._calendarHolder, "RIGHT", 4, 0)
      else
        panel._zoneBtn:SetPoint("LEFT", panel._tabZone, "LEFT", 4, 0)
      end
      if showClk and panel._clockBtn then
        panel._zoneBtn:SetPoint("RIGHT", panel._clockBtn, "LEFT", -4, 0)
      else
        panel._zoneBtn:SetPoint("RIGHT", panel._tabZone, "RIGHT", -4, 0)
      end
      panel._zoneBtn:SetPoint("TOP", panel._tabZone, "TOP", 0, 0)
      panel._zoneBtn:SetPoint("BOTTOM", panel._tabZone, "BOTTOM", 0, 0)
    end
  end

  if panel._botZone then
    if showFooter then panel._botZone:Show() else panel._botZone:Hide() end
  end
  if panel._botSep then
    if showFooter then panel._botSep:Show() else panel._botSep:Hide() end
  end

  if showFooter then
    local half = math.floor(mapW / 2)
    if panel._contactsBtn then panel._contactsBtn:SetWidth(half) end
    if panel._guildBtn then panel._guildBtn:SetWidth(half) end
  end

  if panel._content then
    panel._content:ClearAllPoints()
    if showHeader and panel._tabSep then
      panel._content:SetPoint("TOPLEFT", panel._tabSep, "BOTTOMLEFT", 0, 0)
    else
      panel._content:SetPoint("TOPLEFT", panel, "TOPLEFT", BORDER_W, -BORDER_W)
    end
    if showFooter and panel._botSep then
      panel._content:SetPoint("BOTTOMRIGHT", panel._botSep, "TOPRIGHT", 0, 0)
    else
      panel._content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_W, BORDER_W)
    end
  end

  if panel._compartHolder then
    panel._compartHolder:SetSize(compartSz, compartSz)
    if showComp then panel._compartHolder:Show() else panel._compartHolder:Hide() end
  end

  if panel._mailHolder then
    panel._mailHolder:SetSize(mailSz, mailSz)
    if panel._mail then pcall(panel._mail.SetSize, panel._mail, mailSz, mailSz) end
  end
  if panel._diffHolder then
    panel._diffHolder:SetSize(diffSz, diffSz)
    if panel._difficulty then pcall(panel._difficulty.SetSize, panel._difficulty, diffSz, diffSz) end
  end

  local font = GetFont()
  local hdrFS = db.headerFontSize or 11
  local clkFS = db.clockFontSize or 11
  local ftrFS = db.footerFontSize or 11
  local gldFS = db.guildFontSize or 11

  if panel._clockBtn and panel._clockBtn._text then
    pcall(panel._clockBtn._text.SetFont, panel._clockBtn._text, font, clkFS, "OUTLINE")
  end
  if panel._zoneText then
    pcall(panel._zoneText.SetFont, panel._zoneText, font, hdrFS, "OUTLINE")
  end
  if panel._contactsBtn and panel._contactsBtn._text then
    pcall(panel._contactsBtn._text.SetFont, panel._contactsBtn._text, font, ftrFS, "OUTLINE")
  end
  if panel._guildBtn and panel._guildBtn._text then
    pcall(panel._guildBtn._text.SetFont, panel._guildBtn._text, font, gldFS, "OUTLINE")
  end
  if panel._compartHolder and panel._compartHolder._countText then
    pcall(panel._compartHolder._countText.SetFont, panel._compartHolder._countText, font, math.max(8, compartSz - 10), "OUTLINE")
  end

  -- Position (Move system {x,y} ou DB defaults)
  local pos = BravLib.API.Get("positions", "Minimap")
  if pos and pos.x and pos.y then
    -- format Move system (CENTER-based)
    local fs = panel:GetScale() or 1
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", pos.x / fs, pos.y / fs)
  else
    panel:ClearAllPoints()
    panel:SetPoint(
      db.point or "TOPRIGHT",
      UIParent,
      db.relPoint or "TOPRIGHT",
      db.x or -30,
      db.y or -30
    )
  end
end

-- ============================================================================
-- PANEL CREATION
-- ============================================================================

local function CreatePanel(db)
  local name = "BravUI_MinimapV2"
  local panel = _G[name]

  if not panel then
    panel = CreateFrame("Frame", name, UIParent)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(0)
    panel:SetClampedToScreen(true)

    -- Background
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX)
    bg:SetAllPoints(panel)
    panel._bg = bg

    -- Header zone
    local tabZone = CreateFrame("Frame", nil, panel)
    tabZone:SetPoint("TOPLEFT", panel, "TOPLEFT", BORDER_W, -BORDER_W)
    tabZone:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -BORDER_W, -BORDER_W)
    tabZone:SetHeight(TAB_ZONE)
    panel._tabZone = tabZone

    -- Calendar holder
    local calendarHolder = CreateFrame("Frame", nil, tabZone)
    calendarHolder:SetSize(16, 16)
    calendarHolder:SetPoint("LEFT", tabZone, "LEFT", 4, -1)
    panel._calendarHolder = calendarHolder

    -- Tracking holder
    local trackHolder = CreateFrame("Frame", nil, tabZone)
    trackHolder:SetSize(16, 16)
    trackHolder:SetPoint("LEFT", calendarHolder, "RIGHT", 4, 0)
    panel._trackHolder = trackHolder

    -- Clock button
    local font = GetFont()
    local clockBtn = CreateFrame("Button", nil, tabZone)
    clockBtn:SetSize(40, 22)
    clockBtn:SetPoint("RIGHT", tabZone, "RIGHT", -4, 0)
    local clockText = clockBtn:CreateFontString(nil, "OVERLAY")
    clockText:SetFont(font, 11, "OUTLINE")
    clockText:SetPoint("CENTER", clockBtn, "CENTER", 0, -1)
    clockText:SetJustifyH("RIGHT")
    clockBtn._text = clockText
    clockBtn:SetScript("OnClick", function()
      if not _G.TimeManagerFrame and _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_TimeManager")
      end
      if _G.TimeManagerFrame then
        if _G.TimeManagerFrame:IsShown() then
          _G.TimeManagerFrame:Hide()
        else
          _G.TimeManagerFrame:Show()
        end
      end
    end)
    clockBtn:SetScript("OnEnter", function(self) self._text:SetAlpha(1) end)
    clockBtn:SetScript("OnLeave", function(self) self._text:SetAlpha(0.8) end)
    clockBtn._elapsed = 0
    local function FormatClock(h, m)
      local mdb = GetDB()
      if mdb.clockFormat == "12h" then
        local suffix = h >= 12 and "PM" or "AM"
        h = h % 12
        if h == 0 then h = 12 end
        return format("%d:%02d %s", h, m, suffix)
      end
      return format("%02d:%02d", h, m)
    end
    clockBtn:SetScript("OnUpdate", function(self, dt)
      self._elapsed = self._elapsed + dt
      if self._elapsed < 1 then return end
      self._elapsed = 0
      local t = date("*t")
      self._text:SetText(FormatClock(t.hour, t.min))
    end)
    local t = date("*t")
    clockText:SetText(FormatClock(t.hour, t.min))
    clockText:SetAlpha(0.8)
    panel._clockBtn = clockBtn

    -- Zone text button
    local zoneBtn = CreateFrame("Button", nil, tabZone)
    zoneBtn:SetPoint("LEFT", calendarHolder, "RIGHT", 4, 0)
    zoneBtn:SetPoint("RIGHT", clockBtn, "LEFT", -4, 0)
    zoneBtn:SetPoint("TOP", tabZone, "TOP", 0, 0)
    zoneBtn:SetPoint("BOTTOM", tabZone, "BOTTOM", 0, 0)
    local zoneText = zoneBtn:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(font, 11, "OUTLINE")
    zoneText:SetPoint("TOPLEFT", zoneBtn, "TOPLEFT", 0, -1)
    zoneText:SetPoint("BOTTOMRIGHT", zoneBtn, "BOTTOMRIGHT", 0, -1)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetJustifyV("MIDDLE")
    zoneText:SetWordWrap(false)
    zoneBtn:SetScript("OnClick", function() ToggleWorldMap() end)
    panel._zoneBtn = zoneBtn
    panel._zoneText = zoneText

    -- Header separator
    local tabSep = panel:CreateTexture(nil, "ARTWORK")
    tabSep:SetTexture(TEX)
    tabSep:SetHeight(1)
    tabSep:SetPoint("TOPLEFT", tabZone, "BOTTOMLEFT", 0, 0)
    tabSep:SetPoint("TOPRIGHT", tabZone, "BOTTOMRIGHT", 0, 0)
    panel._tabSep = tabSep

    -- Footer zone
    local botZone = CreateFrame("Frame", nil, panel)
    botZone:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_W, BORDER_W)
    botZone:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_W, BORDER_W)
    botZone:SetHeight(BOT_ZONE)
    panel._botZone = botZone

    -- Footer separator
    local botSep = panel:CreateTexture(nil, "ARTWORK")
    botSep:SetTexture(TEX)
    botSep:SetHeight(1)
    botSep:SetPoint("BOTTOMLEFT", botZone, "TOPLEFT", 0, 0)
    botSep:SetPoint("BOTTOMRIGHT", botZone, "TOPRIGHT", 0, 0)
    panel._botSep = botSep

    -- Content zone (clipped)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", tabSep, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", botSep, "TOPRIGHT", 0, 0)
    content:SetClipsChildren(true)
    panel._content = content

    -- Mail holder (top-left overlay)
    local mailHolder = CreateFrame("Frame", nil, panel)
    mailHolder:SetSize(18, 18)
    mailHolder:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    mailHolder:SetFrameStrata("TOOLTIP")
    mailHolder:SetFrameLevel(900)
    mailHolder.Layout = function() end
    local mailTex = mailHolder:CreateTexture(nil, "OVERLAY")
    mailTex:SetTexture("Interface\\Icons\\INV_Letter_15")
    mailTex:SetAllPoints()
    mailTex:SetDesaturated(true)
    mailTex:SetVertexColor(1, 1, 1, 0.9)
    mailHolder._icon = mailTex
    mailHolder:Hide()
    panel._mailHolder = mailHolder

    -- Difficulty holder (top-right overlay)
    local diffHolder = CreateFrame("Frame", nil, panel)
    diffHolder:SetSize(24, 24)
    diffHolder:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2)
    diffHolder:SetFrameStrata("TOOLTIP")
    diffHolder:SetFrameLevel(900)
    local diffTex = diffHolder:CreateTexture(nil, "OVERLAY")
    diffTex:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    diffTex:SetAllPoints()
    diffTex:SetDesaturated(true)
    diffTex:SetVertexColor(1, 1, 1, 0.9)
    diffHolder._icon = diffTex
    diffHolder:Hide()
    panel._diffHolder = diffHolder

    -- Addon compartment holder (bottom-left overlay)
    local compartHolder = CreateFrame("Frame", nil, panel)
    compartHolder:SetSize(20, 20)
    compartHolder:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 4, 4)
    compartHolder:SetFrameStrata("TOOLTIP")
    compartHolder:SetFrameLevel(900)

    local cBorders = {}
    local cT = compartHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    cT:SetTexture(TEX); cT:SetPoint("TOPLEFT"); cT:SetPoint("TOPRIGHT"); cT:SetHeight(1)
    cBorders.top = cT
    local cB = compartHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    cB:SetTexture(TEX); cB:SetPoint("BOTTOMLEFT"); cB:SetPoint("BOTTOMRIGHT"); cB:SetHeight(1)
    cBorders.bottom = cB
    local cL = compartHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    cL:SetTexture(TEX); cL:SetPoint("TOPLEFT"); cL:SetPoint("BOTTOMLEFT"); cL:SetWidth(1)
    cBorders.left = cL
    local cR = compartHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    cR:SetTexture(TEX); cR:SetPoint("TOPRIGHT"); cR:SetPoint("BOTTOMRIGHT"); cR:SetWidth(1)
    cBorders.right = cR
    compartHolder._borders = cBorders

    local cBg = compartHolder:CreateTexture(nil, "BACKGROUND")
    cBg:SetTexture(TEX); cBg:SetAllPoints(); cBg:SetVertexColor(0, 0, 0, 0.6)
    compartHolder._bg = cBg

    local cCount = compartHolder:CreateFontString(nil, "OVERLAY")
    cCount:SetFont(font, 10, "OUTLINE")
    cCount:SetPoint("CENTER", compartHolder, "CENTER", 0, 0)
    cCount:SetJustifyH("CENTER")
    compartHolder._countText = cCount

    panel._compartHolder = compartHolder

    -- Contacts button (left half of footer)
    local contactsBtn = CreateFrame("Button", nil, botZone)
    contactsBtn:SetPoint("TOPLEFT", botZone, "TOPLEFT", 0, 0)
    contactsBtn:SetPoint("BOTTOMLEFT", botZone, "BOTTOMLEFT", 0, 0)
    local contactsText = contactsBtn:CreateFontString(nil, "OVERLAY")
    contactsText:SetFont(font, 11, "OUTLINE")
    contactsText:SetPoint("CENTER")
    contactsText:SetJustifyH("CENTER")
    contactsBtn._text = contactsText
    contactsBtn:SetScript("OnClick", function()
      if _G.ToggleFriendsFrame then _G.ToggleFriendsFrame() end
    end)
    panel._contactsBtn = contactsBtn

    -- Guild button (right half of footer)
    local guildBtn = CreateFrame("Button", nil, botZone)
    guildBtn:SetPoint("TOPRIGHT", botZone, "TOPRIGHT", 0, 0)
    guildBtn:SetPoint("BOTTOMRIGHT", botZone, "BOTTOMRIGHT", 0, 0)
    local guildText = guildBtn:CreateFontString(nil, "OVERLAY")
    guildText:SetFont(font, 11, "OUTLINE")
    guildText:SetPoint("CENTER")
    guildText:SetJustifyH("CENTER")
    guildBtn._text = guildText
    guildBtn:SetScript("OnClick", function()
      if _G.IsInGuild and _G.IsInGuild() then
        if _G.ToggleGuildFrame then _G.ToggleGuildFrame() end
      end
    end)
    panel._guildBtn = guildBtn
  end

  -- Class borders (created once)
  if not panel._borders then
    local cr, cg, cb = GetClassColor()
    local PU = PixelUtil
    local borders = {}

    local top = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(top, "TOPLEFT", panel, "TOPLEFT", 0, 0)
    PU.SetPoint(top, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    PU.SetHeight(top, BORDER_W)
    borders.top = top

    local bot = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(bot, "BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    PU.SetPoint(bot, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    PU.SetHeight(bot, BORDER_W)
    borders.bottom = bot

    local left = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(left, "TOPLEFT", panel, "TOPLEFT", 0, 0)
    PU.SetPoint(left, "BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    PU.SetWidth(left, BORDER_W)
    borders.left = left

    local right = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(right, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    PU.SetPoint(right, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    PU.SetWidth(right, BORDER_W)
    borders.right = right

    panel._borders = borders
  end

  ApplyLayout(panel, db)

  return panel
end

-- ============================================================================
-- PLACE MINIMAP INSIDE CONTENT
-- ============================================================================

local function PlaceMinimapInContent(mm, content, db)
  if not mm or not content then return end

  mm:SetParent(content)
  mm:ClearAllPoints()
  mm:SetAllPoints(content)

  mm:SetMaskTexture(TEX)
  mm:SetFrameStrata("LOW")
  mm:SetFrameLevel(content:GetFrameLevel() + 2)

  local w = db.panelWidth or 250
  local h = db.panelHeight or 250
  mm:SetScale(1)
  mm:SetSize(w, h)
end

-- ============================================================================
-- REFRESH COLORS
-- ============================================================================

local function RefreshColors(panel, db)
  if not panel then return end
  db = db or {}
  local r, g, b = GetClassColor()

  local ic = db.iconColor or { r = 1, g = 1, b = 1 }
  local ir, ig, ib = ic.r or 1, ic.g or 1, ic.b or 1
  local ztc = db.zoneTextColor or { r = 1, g = 1, b = 1 }
  local ctc = db.clockTextColor or { r = 1, g = 1, b = 1 }
  local cntc = db.contactsTextColor or { r = 1, g = 1, b = 1 }
  local gtc = db.guildTextColor or { r = 1, g = 1, b = 1 }

  if panel._borders then
    for _, tex in pairs(panel._borders) do
      if tex and tex.SetVertexColor then
        tex:SetVertexColor(r, g, b, 1)
      end
    end
  end

  if panel._tabSep then panel._tabSep:SetVertexColor(r, g, b, 0.5) end
  if panel._botSep then panel._botSep:SetVertexColor(r, g, b, 0.5) end

  if panel._zoneText then
    panel._zoneText:SetTextColor(ztc.r or 1, ztc.g or 1, ztc.b or 1, 1)
  end
  if panel._clockBtn and panel._clockBtn._text then
    panel._clockBtn._text:SetTextColor(ctc.r or 1, ctc.g or 1, ctc.b or 1, 0.8)
  end
  if panel._contactsBtn and panel._contactsBtn._text then
    panel._contactsBtn._text:SetTextColor(cntc.r or 1, cntc.g or 1, cntc.b or 1, 1)
  end
  if panel._guildBtn and panel._guildBtn._text then
    panel._guildBtn._text:SetTextColor(gtc.r or 1, gtc.g or 1, gtc.b or 1, 1)
  end

  TintFrameTextures(panel._tracking, ir, ig, ib, 0.8)
  TintFrameTextures(panel._calendar, ir, ig, ib, 0.8)

  local mic = db.mailIconColor or { r = 1, g = 1, b = 1 }
  if panel._mailHolder and panel._mailHolder._icon then
    panel._mailHolder._icon:SetVertexColor(mic.r or 1, mic.g or 1, mic.b or 1, 0.9)
  end
  local dic = db.diffIconColor or { r = 1, g = 1, b = 1 }
  if panel._diffHolder and panel._diffHolder._icon then
    panel._diffHolder._icon:SetVertexColor(dic.r or 1, dic.g or 1, dic.b or 1, 0.9)
  end

  if panel._mailHolder then
    local hasMail = _G.HasNewMail and _G.HasNewMail()
    if hasMail or panel._mailHolder._preview then
      panel._mailHolder:Show()
    else
      panel._mailHolder:Hide()
    end
  end
  if panel._diffHolder then
    local inInstance = _G.IsInInstance and _G.IsInInstance()
    if inInstance or panel._diffHolder._preview then
      panel._diffHolder:Show()
    else
      panel._diffHolder:Hide()
    end
  end

  local cic = db.compartIconColor or { r = 1, g = 1, b = 1 }
  local ccr, ccg, ccb = cic.r or 1, cic.g or 1, cic.b or 1
  local ch = panel._compartHolder
  if ch then
    if ch._borders then
      for _, tex in pairs(ch._borders) do
        if tex and tex.SetVertexColor then tex:SetVertexColor(ccr, ccg, ccb, 0.8) end
      end
    end
    if ch._countText then
      local count = 0
      pcall(function()
        local acf = _G.AddonCompartmentFrame
        if acf and acf.registeredAddons then
          count = #acf.registeredAddons
        end
      end)
      ch._countText:SetText(count > 0 and tostring(count) or "")
      ch._countText:SetTextColor(ccr, ccg, ccb, 1)
    end
  end
end

-- ============================================================================
-- BOTTOM UPDATE (Contacts / Guild)
-- ============================================================================

local function UpdateBottom(panel, db)
  if not panel then return end
  db = db or {}
  local cntc = db.contactsTextColor or { r = 1, g = 1, b = 1 }
  local gtc = db.guildTextColor or { r = 1, g = 1, b = 1 }

  if panel._contactsBtn and panel._contactsBtn._text then
    local fo = GetContactCount()
    panel._contactsBtn._text:SetText("Contact : |cff00ff00" .. fo .. "|r")
    panel._contactsBtn._text:SetTextColor(cntc.r or 1, cntc.g or 1, cntc.b or 1, 1)
  end

  if panel._guildBtn and panel._guildBtn._text then
    local go, gt = GetGuildCount()
    if gt == 0 then
      panel._guildBtn._text:SetText("Guilde : |cff66666600|r")
    else
      panel._guildBtn._text:SetText("Guilde : |cff00ff00" .. go .. "|r")
    end
    panel._guildBtn._text:SetTextColor(gtc.r or 1, gtc.g or 1, gtc.b or 1, 1)
  end
end

-- ============================================================================
-- ZONE TEXT UPDATE
-- ============================================================================

local function UpdateZoneText(panel)
  if not panel or not panel._zoneText then return end
  local sub = GetSubZoneText()
  local zone = (sub and sub ~= "") and sub or (GetZoneText() or GetMinimapZoneText() or "")
  panel._zoneText:SetText(zone)
end

-- ============================================================================
-- APPLY SKIN (main entry point)
-- ============================================================================

local function ApplySkin()
  local mm = _G.Minimap
  if not mm then return end

  local db = GetDB()

  -- Hide v1 frame if present
  local v1Frame = _G.BravUI_MinimapFrame
  if v1Frame then v1Frame:Hide() end

  local panel = CreatePanel(db)
  Minimap._panel = panel

  PurgeBlizzardRoundArt()
  if db.hideAddonButtons ~= false then
    HideAddonMinimapButtons()
  end
  PlaceMinimapInContent(mm, panel._content, db)

  -- Reparent Blizzard tracking button
  if panel._trackHolder and not panel._trackingDone then
    local tracking = GetTrackingButton()
    if tracking then
      tracking:Show()
      tracking:SetAlpha(1)
      tracking:SetParent(panel._trackHolder)
      tracking:ClearAllPoints()
      tracking:SetPoint("CENTER", panel._trackHolder, "CENTER", 0, 0)
      tracking:SetFrameStrata("TOOLTIP")
      tracking:SetFrameLevel(panel._trackHolder:GetFrameLevel() + 999)
      if tracking.SetSize then pcall(tracking.SetSize, tracking, 16, 16) end
      if tracking.EnableMouse then tracking:EnableMouse(true) end
      if tracking.Background then tracking.Background:Hide() end
      if tracking.ButtonBorder then tracking.ButtonBorder:Hide() end
      panel._tracking = tracking
      panel._trackingDone = true
    end
  end

  -- Reparent Blizzard calendar
  if panel._calendarHolder and not panel._calendarDone then
    local calendar = _G.GameTimeFrame
    if calendar then
      calendar:Show()
      calendar:SetAlpha(1)
      calendar:SetParent(panel._calendarHolder)
      calendar:ClearAllPoints()
      calendar:SetPoint("CENTER", panel._calendarHolder, "CENTER", 0, 0)
      calendar:SetFrameStrata("TOOLTIP")
      calendar:SetFrameLevel(panel._calendarHolder:GetFrameLevel() + 999)
      if calendar.SetSize then pcall(calendar.SetSize, calendar, 16, 16) end
      if calendar.EnableMouse then calendar:EnableMouse(true) end
      panel._calendar = calendar
      panel._calendarDone = true
    end
  end

  -- Hide Blizzard mail, use custom icon
  if panel._mailHolder and not panel._mailDone then
    local mailFrame = _G.MiniMapMailFrame
    if not mailFrame and _G.MinimapCluster then
      local ind = _G.MinimapCluster.IndicatorFrame
      if ind then mailFrame = ind.MailFrame or ind.Mail end
    end
    if mailFrame then
      pcall(mailFrame.Hide, mailFrame)
      pcall(mailFrame.SetAlpha, mailFrame, 0)
      if not mailFrame._bravHideHooked then
        hooksecurefunc(mailFrame, "Show", function(self) pcall(self.SetAlpha, self, 0) end)
        mailFrame._bravHideHooked = true
      end
    end
    local hasMail = _G.HasNewMail and _G.HasNewMail()
    if hasMail or panel._mailHolder._preview then
      panel._mailHolder:Show()
    else
      panel._mailHolder:Hide()
    end
    panel._mailDone = true
  end

  -- Hide Blizzard difficulty, use custom icon
  if panel._diffHolder and not panel._diffDone then
    local diffFrame = _G.MiniMapInstanceDifficulty
    if not diffFrame and _G.MinimapCluster then
      diffFrame = _G.MinimapCluster.InstanceDifficulty
    end
    if diffFrame then
      pcall(diffFrame.Hide, diffFrame)
      pcall(diffFrame.SetAlpha, diffFrame, 0)
      if not diffFrame._bravHideHooked then
        hooksecurefunc(diffFrame, "Show", function(self) pcall(self.SetAlpha, self, 0) end)
        diffFrame._bravHideHooked = true
      end
    end
    local guildDiff = _G.GuildInstanceDifficulty
    if guildDiff then
      pcall(guildDiff.Hide, guildDiff)
      pcall(guildDiff.SetAlpha, guildDiff, 0)
      if not guildDiff._bravHideHooked then
        hooksecurefunc(guildDiff, "Show", function(self) pcall(self.SetAlpha, self, 0) end)
        guildDiff._bravHideHooked = true
      end
    end
    local inInstance = _G.IsInInstance and _G.IsInInstance()
    if inInstance or panel._diffHolder._preview then
      panel._diffHolder:Show()
    else
      panel._diffHolder:Hide()
    end
    panel._diffDone = true
  end

  -- Reparent addon compartment (invisible, click → dropdown)
  if panel._compartHolder and not panel._compartDone then
    local acf = _G.AddonCompartmentFrame
    if acf then
      acf:SetParent(panel._compartHolder)
      acf:ClearAllPoints()
      acf:SetAllPoints(panel._compartHolder)
      acf:SetFrameStrata("TOOLTIP")
      acf:SetFrameLevel(panel._compartHolder:GetFrameLevel() + 999)
      acf:SetAlpha(0)
      acf:EnableMouse(true)
      panel._compartment = acf
      panel._compartDone = true
    end
  end

  UpdateZoneText(panel)
  UpdateBottom(panel, db)
  RefreshColors(panel, db)

  -- Event driver (once)
  if not panel._zoneEventDriver then
    local ev = CreateFrame("Frame", nil, panel)
    ev:RegisterEvent("ZONE_CHANGED")
    ev:RegisterEvent("ZONE_CHANGED_INDOORS")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("FRIENDLIST_UPDATE")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    ev:RegisterEvent("GUILD_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_GUILD_UPDATE")
    ev:RegisterEvent("UPDATE_PENDING_MAIL")
    ev:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    ev:RegisterEvent("UPDATE_INSTANCE_INFO")
    ev:SetScript("OnEvent", function(_, event)
      if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
         or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        UpdateZoneText(panel)
        if panel._diffHolder then
          local inInstance = _G.IsInInstance and _G.IsInInstance()
          if inInstance or panel._diffHolder._preview then
            panel._diffHolder:Show()
          else
            panel._diffHolder:Hide()
          end
        end
      end
      if event == "UPDATE_PENDING_MAIL" then
        if panel._mailHolder then
          local hasMail = _G.HasNewMail and _G.HasNewMail()
          if hasMail or panel._mailHolder._preview then
            panel._mailHolder:Show()
          else
            panel._mailHolder:Hide()
          end
        end
        C_Timer.After(0.1, function() RefreshColors(panel, GetDB()) end)
      end
      if event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" then
        if panel._diffHolder then
          local inInstance = _G.IsInInstance and _G.IsInInstance()
          if inInstance or panel._diffHolder._preview then
            panel._diffHolder:Show()
          else
            panel._diffHolder:Hide()
          end
        end
      end
      UpdateBottom(panel, GetDB())
    end)
    panel._zoneEventDriver = ev
  end

  panel:Show()

  -- Edit Mode: hide MinimapCluster selection
  local mc = _G.MinimapCluster
  if mc and not mc._bravV2EditHooked then
    mc._bravV2EditHooked = true
    if mc.HighlightSystem then
      hooksecurefunc(mc, "HighlightSystem", function(self)
        if self.Selection then self.Selection:Hide() end
        if self.isHighlighted then self.isHighlighted = false end
      end)
    end
    if mc.SelectSystem then
      hooksecurefunc(mc, "SelectSystem", function(self)
        if self.Selection then self.Selection:Hide() end
        if self.isSelected then self.isSelected = false end
      end)
    end
  end

  -- Enable movement via BravUI.Move
  if not panel._moveDone then
    BravUI.Move.Enable(panel, "Minimap")
    panel._moveDone = true
  end
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function Minimap:Init()
  -- Nothing to init before Enable
end

function Minimap:Enable()
  local db = GetDB()
  if db.enabled == false then return end

  local function TryApply()
    if _G.Minimap then
      ApplySkin()
      return true
    end
    return false
  end

  if TryApply() then return end

  C_Timer.After(0, TryApply)
  C_Timer.After(0.2, TryApply)
  C_Timer.After(1.0, TryApply)
end

function Minimap:Disable()
  if self._panel then
    self._panel:Hide()
  end
end

function Minimap:Refresh()
  if self._panel then
    local db = GetDB()
    ApplyLayout(self._panel, db)
    local mm = _G.Minimap
    if mm then
      mm:SetSize(db.panelWidth or 250, db.panelHeight or 250)
    end
    RefreshColors(self._panel, db)
    UpdateBottom(self._panel, db)
    UpdateZoneText(self._panel)
  end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

local function MMPrint(msg)
  print("|cff00ff88BravUI Minimap:|r " .. msg)
end

local function MMHelp()
  MMPrint("Commandes disponibles:")
  MMPrint("  /bravmm w <num> - Largeur carte")
  MMPrint("  /bravmm h <num> - Hauteur carte")
  MMPrint("  /bravmm opacity <0-1> - Opacite")
  MMPrint("  /bravmm reset - Reinitialiser")
end

SLASH_BRAVMM1 = "/bravmm"
SlashCmdList["BRAVMM"] = function(msg)
  msg = msg or ""
  local cmd, val = msg:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()

  local db = GetDB()
  if not db then
    MMPrint("Module minimap pas pret.")
    return
  end

  if cmd == "" or cmd == "help" then
    MMHelp()
    return
  end

  if cmd == "w" or cmd == "width" then
    local n = tonumber(val)
    if not n then MMHelp() return end
    BravLib.API.Set("minimap", "panelWidth", n)
    Minimap:Refresh()
    MMPrint("Largeur carte = " .. n)
    return
  end

  if cmd == "h" or cmd == "height" then
    local n = tonumber(val)
    if not n then MMHelp() return end
    BravLib.API.Set("minimap", "panelHeight", n)
    Minimap:Refresh()
    MMPrint("Hauteur carte = " .. n)
    return
  end

  if cmd == "opacity" then
    local n = tonumber(val)
    if not n then MMHelp() return end
    n = math.max(0, math.min(1, n))
    BravLib.API.Set("minimap", "opacity", n)
    Minimap:Refresh()
    MMPrint("Opacite = " .. n)
    return
  end

  if cmd == "reset" then
    local def = BravLib.Storage.GetDefaults()
    if def and def.minimap then
      local current = BravLib.Storage.GetDB()
      if current then current.minimap = def.minimap end
    end
    Minimap:Refresh()
    MMPrint("Reinitialisation OK")
    return
  end

  MMHelp()
end

-- BravUI/Modules/Chat/Chat.lua
-- Chat panel + InfoBar (combined v1 Chat/Init + Chat/Skin + InfoBar/Init)
-- No AceAddon, no external dependencies

local BravUI = BravUI
local U = BravUI.Utils
local GetFont = U.GetFont
local GetClassColor = function() return U.GetClassColor("player") end
local IsSecret = U.IsSecret
local HardString = U.HardString

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local Chat = {}
BravUI:RegisterModule("Interface.Chat", Chat)

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"
local NUM_WINDOWS = NUM_CHAT_WINDOWS or 10
local INSET = 5
local TAB_GAP = 6
local BORDER_W = 2

-- ============================================================================
-- DB HELPERS
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("chat") or {}
end

local function GetIBDb()
  local db = GetDB()
  return db.infobar or {}
end

local function GetInfoBarH()
  return GetIBDb().height or 22
end

local function GetInfoBarOpacity()
  return GetIBDb().opacity or 0.75
end

-- ============================================================================
-- GENERIC UI HELPERS
-- ============================================================================

local function Hide(f)
  if not f then return end
  f:Hide()
  f:SetAlpha(0)
end

local function StripTextures(f)
  if not f or not f.GetRegions then return end
  for _, region in pairs({ f:GetRegions() }) do
    if region and region.SetTexture then
      region:SetTexture(nil)
      region:Hide()
    end
  end
end

local function SoftInvisible(frame)
  if not frame or frame._bravSoftInvis then return end
  frame._bravSoftInvis = true
  frame:SetAlpha(0)
  StripTextures(frame)
  hooksecurefunc(frame, "SetAlpha", function(self, a)
    if self._bravLock then return end
    if a and a > 0 then
      self._bravLock = true
      self:SetAlpha(0)
      self._bravLock = false
    end
  end)
end

local function PermanentHide(frame)
  if not frame or frame._bravPermHidden then return end
  frame._bravPermHidden = true
  frame:Hide()
  frame:SetAlpha(0)
  StripTextures(frame)
  hooksecurefunc(frame, "Show", function(self)
    if self._bravLock then return end
    self._bravLock = true
    self:Hide()
    self._bravLock = false
  end)
  hooksecurefunc(frame, "SetAlpha", function(self, a)
    if self._bravLock then return end
    if a and a > 0 then
      self._bravLock = true
      self:SetAlpha(0)
      self._bravLock = false
    end
  end)
end

local function KillTexture(tex)
  if not tex or tex._bravKilled then return end
  tex._bravKilled = true
  pcall(function() tex:SetTexture(nil) end)
  pcall(function() tex:SetAlpha(0) end)
  pcall(function() tex:Hide() end)
  pcall(function() tex:SetAtlas("") end)
  hooksecurefunc(tex, "SetTexture", function(self)
    if self._bravLock then return end
    self._bravLock = true
    pcall(function() self:SetTexture(nil) end)
    pcall(function() self:SetAlpha(0) end)
    self._bravLock = false
  end)
  hooksecurefunc(tex, "Show", function(self)
    if self._bravLock then return end
    self._bravLock = true
    pcall(function() self:Hide() end)
    self._bravLock = false
  end)
  hooksecurefunc(tex, "SetAlpha", function(self, a)
    if self._bravLock then return end
    if a and a > 0 then
      self._bravLock = true
      pcall(function() self:SetAlpha(0) end)
      self._bravLock = false
    end
  end)
  if tex.SetAtlas then
    hooksecurefunc(tex, "SetAtlas", function(self)
      if self._bravLock then return end
      self._bravLock = true
      pcall(function() self:SetAtlas("") end)
      pcall(function() self:SetAlpha(0) end)
      self._bravLock = false
    end)
  end
end

-- ============================================================================
-- CHANNEL BORDER COLORS
-- ============================================================================

local CHANNEL_COLORS = {
  SAY            = { 1.0, 1.0, 1.0 },
  YELL           = { 1.0, 0.25, 0.25 },
  WHISPER        = { 1.0, 0.5, 1.0 },
  BN_WHISPER     = { 0.0, 0.8, 1.0 },
  PARTY          = { 0.67, 0.67, 1.0 },
  RAID           = { 1.0, 0.5, 0.0 },
  GUILD          = { 0.25, 1.0, 0.25 },
  OFFICER        = { 0.25, 0.75, 0.25 },
  INSTANCE_CHAT  = { 1.0, 0.5, 0.0 },
  CHANNEL        = { 1.0, 0.75, 0.75 },
  EMOTE          = { 1.0, 0.5, 0.25 },
}

-- ============================================================================
-- TAB HELPERS (forward declarations)
-- ============================================================================

local RefreshOneTab, RefreshAllTabs, IsTabSelected, SimpleStripTab
local _overflowBtn, _overflowDropdown, _overflowEntries

local function IsTabSelected_fn(tab)
  local name = tab:GetName()
  if not name then return false end
  local cfName = name:gsub("Tab$", "")
  local cf = _G[cfName]
  if not cf then return false end
  return cf == SELECTED_CHAT_FRAME or cf == _G.SELECTED_DOCK_FRAME
end
IsTabSelected = IsTabSelected_fn

-- Simple strip: remove texture regions only (no hooks, no child hiding)
local function SimpleStripTab_fn(tab)
  for _, region in pairs({ tab:GetRegions() }) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      if not region._isBravTexture then
        region:SetTexture(nil)
        region:SetAlpha(0)
        region:Hide()
      end
    end
  end
  local texNames = {
    "Left", "Middle", "Right",
    "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
    "LeftSelected", "MiddleSelected", "RightSelected",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
  }
  for _, name in ipairs(texNames) do
    local tex = tab[name]
    if tex then tex:SetTexture(nil); tex:SetAlpha(0); tex:Hide() end
  end
  if tab.GetHighlightTexture then
    local hl = tab:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
  end
end
SimpleStripTab = SimpleStripTab_fn

-- Refresh a single tab (color, underline, fade)
local function RefreshOneTab_fn(t)
  if not t or not t:IsShown() then return end
  if t._bravFlashing then return end
  local txt = t.Text or _G[t:GetName() .. "Text"]
  local selected = IsTabSelected(t)
  local db = GetDB()
  local fade = db.fadeTabs
  local classColor = db.useClassColor
  local tc = db.tabTextColor
  local classColorActive = db.useClassColorActive
  local atc = db.activeTabTextColor

  t._bravColorGuard = true
  if txt then
    if selected then
      if classColorActive ~= false then
        local cr, cg, cb = GetClassColor()
        txt:SetTextColor(cr, cg, cb, 1)
      else
        txt:SetTextColor(atc and atc.r or 1, atc and atc.g or 1, atc and atc.b or 1, 1)
      end
    elseif classColor then
      local cr, cg, cb = GetClassColor()
      txt:SetTextColor(cr, cg, cb, fade and (db.fadeTabsAlpha or 0.45) or 0.7)
    else
      local tr = tc and tc.r or 1
      local tg = tc and tc.g or 1
      local tb = tc and tc.b or 1
      txt:SetTextColor(tr, tg, tb, fade and (db.fadeTabsAlpha or 0.45) or 1)
    end
  end
  t._bravColorGuard = false
  if t._bravUnderline then
    t._bravUnderline:SetShown(selected and db.showTabUnderline ~= false)
  end
end
RefreshOneTab = RefreshOneTab_fn

local function RefreshAllTabs_fn()
  for i = 1, NUM_WINDOWS do
    RefreshOneTab(_G["ChatFrame" .. i .. "Tab"])
  end
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local cf = _G[frameName]
      if cf and cf.isTemporary then
        RefreshOneTab(_G[frameName .. "Tab"])
      end
    end
  end
end
RefreshAllTabs = RefreshAllTabs_fn

-- ============================================================================
-- PANEL CREATION
-- ============================================================================

local INFOBAR_RATIOS = { 0.35, 0.15, 0.15, 0.35 }

local function LayoutInfoBarSections(bar, panelWidth)
  if not bar or not bar._sections then return end
  local offsets = { 0 }
  for i = 1, #INFOBAR_RATIOS do
    offsets[i + 1] = offsets[i] + panelWidth * INFOBAR_RATIOS[i]
  end
  if bar._sep1 then bar._sep1:ClearAllPoints(); bar._sep1:SetPoint("CENTER", bar, "LEFT", offsets[2], 0); bar._sep1:Show() end
  if bar._sep2 then bar._sep2:ClearAllPoints(); bar._sep2:SetPoint("CENTER", bar, "LEFT", offsets[3], 0); bar._sep2:Show() end
  if bar._sep3 then bar._sep3:ClearAllPoints(); bar._sep3:SetPoint("CENTER", bar, "LEFT", offsets[4], 0); bar._sep3:Show() end
  for i, btn in ipairs(bar._sections) do
    if i <= #INFOBAR_RATIOS then
      btn:ClearAllPoints()
      btn:SetPoint("LEFT", bar, "LEFT", offsets[i], 0)
      btn:SetSize(panelWidth * INFOBAR_RATIOS[i], GetInfoBarH())
    end
  end
end

local function ClearInfoBarSections(bar)
  if not bar then return end
  if bar._specText then bar._specText:SetText("") end
  if bar._goldText then bar._goldText:SetText("") end
  if bar._durabilityText then bar._durabilityText:SetText("") end
  if bar._perfText then bar._perfText:SetText("") end
  if bar._sep1 then bar._sep1:Hide() end
  if bar._sep2 then bar._sep2:Hide() end
  if bar._sep3 then bar._sep3:Hide() end
end

local function RefreshInfoBarStyle(bar, panelWidth)
  if not bar then return end
  local h = GetInfoBarH()
  local alpha = GetInfoBarOpacity()
  bar:SetHeight(h)
  if bar._bg then bar._bg:SetVertexColor(0, 0, 0, alpha) end
  if bar._sections then
    for _, btn in ipairs(bar._sections) do btn:SetHeight(h) end
  end
end

local function CreatePanel(db)
  local panel = CreateFrame("Frame", "BravUI_ChatPanel", UIParent)
  panel:SetFrameStrata("LOW")
  panel:SetFrameLevel(0)
  panel:SetClampedToScreen(true)

  -- Tab zone background
  local tabBg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
  tabBg:SetTexture(TEX)
  tabBg:SetVertexColor(0, 0, 0, db.tabOpacity or 0.85)
  tabBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  tabBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  tabBg:SetHeight((db.tabHeight or 15) + 3)
  panel._tabBg = tabBg

  -- Content background
  local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetTexture(TEX)
  bg:SetVertexColor(0, 0, 0, db.opacity or 0.75)
  bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -((db.tabHeight or 15) + 3))
  bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  panel._bg = bg

  -- Class border (top, left, right — no bottom, InfoBar closes the panel)
  local cr, cg, cb = GetClassColor()
  local PU = PixelUtil
  local borders = {}
  local top = panel:CreateTexture(nil, "OVERLAY", nil, 7)
  top:SetTexture(TEX); top:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(top, "TOPLEFT", panel, "TOPLEFT", 0, 0)
  PU.SetPoint(top, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  PU.SetHeight(top, BORDER_W)
  borders.top = top
  local left = panel:CreateTexture(nil, "OVERLAY", nil, 7)
  left:SetTexture(TEX); left:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(left, "TOPLEFT", panel, "TOPLEFT", 0, 0)
  PU.SetPoint(left, "BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
  PU.SetWidth(left, BORDER_W)
  borders.left = left
  local right = panel:CreateTexture(nil, "OVERLAY", nil, 7)
  right:SetTexture(TEX); right:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(right, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  PU.SetPoint(right, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  PU.SetWidth(right, BORDER_W)
  borders.right = right
  panel._borders = borders

  -- Tab separator
  local sep = panel:CreateTexture(nil, "ARTWORK")
  sep:SetTexture(TEX)
  sep:SetVertexColor(cr, cg, cb, 0.5)
  sep:SetHeight(1)
  panel._tabSep = sep

  -- ==========================================================================
  -- INFOBAR ZONE (bottom of panel)
  -- ==========================================================================
  local bar = CreateFrame("Frame", "BravUI_ChatInfoBar", panel)
  bar:SetHeight(GetInfoBarH())
  bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  local barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  barBg:SetTexture(TEX)
  barBg:SetVertexColor(0, 0, 0, GetInfoBarOpacity())
  barBg:SetAllPoints(bar)
  bar._bg = barBg

  -- InfoBar borders
  local barBorders = {}
  local bTop = bar:CreateTexture(nil, "OVERLAY", nil, 7)
  bTop:SetTexture(TEX); bTop:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(bTop, "TOPLEFT", bar, "TOPLEFT", 0, 0)
  PU.SetPoint(bTop, "TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  PU.SetHeight(bTop, BORDER_W)
  barBorders.top = bTop
  local bBot = bar:CreateTexture(nil, "OVERLAY", nil, 7)
  bBot:SetTexture(TEX); bBot:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(bBot, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  PU.SetPoint(bBot, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  PU.SetHeight(bBot, BORDER_W)
  barBorders.bottom = bBot
  local bLeft = bar:CreateTexture(nil, "OVERLAY", nil, 7)
  bLeft:SetTexture(TEX); bLeft:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(bLeft, "TOPLEFT", bar, "TOPLEFT", 0, 0)
  PU.SetPoint(bLeft, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  PU.SetWidth(bLeft, BORDER_W)
  barBorders.left = bLeft
  local bRight = bar:CreateTexture(nil, "OVERLAY", nil, 7)
  bRight:SetTexture(TEX); bRight:SetVertexColor(cr, cg, cb, 1)
  PU.SetPoint(bRight, "TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  PU.SetPoint(bRight, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  PU.SetWidth(bRight, BORDER_W)
  barBorders.right = bRight
  bar._borders = barBorders

  -- InfoBar separators
  local function MakeInfoBarSep(parent)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetTexture(TEX)
    local sr, sg, sb = GetClassColor()
    s:SetVertexColor(sr, sg, sb, 0.5)
    s:SetSize(1, 14)
    return s
  end
  bar._sep1 = MakeInfoBarSep(bar)
  bar._sep2 = MakeInfoBarSep(bar)
  bar._sep3 = MakeInfoBarSep(bar)

  -- InfoBar section buttons
  local FONT_PATH = GetFont()
  local SECTION_CLICKS = {
    function() if InCombatLockdown() then return end
      if PlayerSpellsMicroButton then PlayerSpellsMicroButton:Click()
      elseif TalentMicroButton then TalentMicroButton:Click() end
    end,
    function() if InCombatLockdown() then return end; ToggleAllBags() end,
    function() if InCombatLockdown() then return end
      if CharacterMicroButton then CharacterMicroButton:Click() end
    end,
    function() end,
  }
  local ibFs = GetIBDb().fontSize or 11
  local function MakeInfoBarSection(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(120, GetInfoBarH())
    local txt = btn:CreateFontString(nil, "OVERLAY")
    txt:SetFontObject("GameFontHighlightSmall")
    pcall(function() txt:SetFont(FONT_PATH, ibFs, "OUTLINE") end)
    txt:SetPoint("CENTER")
    txt:SetTextColor(1, 1, 1, 1)
    btn:SetScript("OnEnter", function() txt:SetTextColor(1, 1, 0, 1) end)
    btn:SetScript("OnLeave", function() txt:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnClick", onClick)
    btn._text = txt
    return btn, txt
  end

  local sections = {}
  local sectionTexts = {}
  for i = 1, 4 do
    local btn, txt = MakeInfoBarSection(bar, SECTION_CLICKS[i])
    sections[i] = btn
    sectionTexts[i] = txt
  end
  bar._sections = sections
  bar._specText = sectionTexts[1]
  bar._goldText = sectionTexts[2]
  bar._durabilityText = sectionTexts[3]
  bar._perfText = sectionTexts[4]

  LayoutInfoBarSections(bar, db.panelWidth or 450)
  panel._infoBar = bar

  return panel
end

-- ============================================================================
-- CHATFRAME SKINNING
-- ============================================================================

local function SkinChatFrame(cf, i, panel, db)
  if not cf or cf._bravSkinned then return end
  cf._bravSkinned = true
  StripTextures(cf)
  if cf.Background then SoftInvisible(cf.Background) end
  if cf.clickAnywhereButton then SoftInvisible(cf.clickAnywhereButton) end
  if cf.SetFont then cf:SetFont(GetFont(), db.fontSize or 12, "") end
  local btnFrame = _G["ChatFrame" .. i .. "ButtonFrame"]
  if btnFrame then StripTextures(btnFrame); Hide(btnFrame) end
  if cf.ScrollBar then Hide(cf.ScrollBar) end
  if cf.ScrollToBottomButton then Hide(cf.ScrollToBottomButton) end
  if cf.SetBackdrop then pcall(cf.SetBackdrop, cf, nil) end
  local bgFrame = _G["ChatFrame" .. i .. "Background"]
  if bgFrame then PermanentHide(bgFrame) end
  local tabGlow = _G["ChatFrame" .. i .. "TabGlow"]
  if tabGlow then PermanentHide(tabGlow) end
  local qlf = _G["CombatLogQuickButtonFrame_Custom"]
  if qlf then PermanentHide(qlf) end
  local qlf2 = _G["CombatLogQuickButtonFrame"]
  if qlf2 then PermanentHide(qlf2) end
end

local function WrapChatFrame(cf, panel, db)
  if not cf or not panel then return end
  local tabZone = (db.tabHeight or 15) + 3
  panel:SetSize(db.panelWidth or 450, db.panelHeight or 220)
  cf:SetSize((db.panelWidth or 450) - INSET * 2, (db.panelHeight or 220) - tabZone - GetInfoBarH())
  if panel._tabSep then
    panel._tabSep:ClearAllPoints()
    panel._tabSep:SetPoint("LEFT", panel, "TOPLEFT", 0, -tabZone)
    panel._tabSep:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -tabZone)
  end
  if panel._tabBg then panel._tabBg:SetHeight(tabZone) end
  if panel._bg then
    panel._bg:ClearAllPoints()
    panel._bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -tabZone)
    panel._bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  end
end

-- ============================================================================
-- TAB SKINNING
-- ============================================================================

local function SkinTab(tab, panel, db)
  if not tab then return end
  SimpleStripTab(tab)
  tab:SetAlpha(1)
  tab:SetHeight(db.tabHeight or 15)
  tab:SetScale(1)

  local text = tab.Text or _G[tab:GetName() .. "Text"]
  if text then
    text:ClearAllPoints()
    text:SetPoint("CENTER", tab, "CENTER", 0, 0)
    text:SetFont(GetFont(), db.tabFontSize or 12, "")
    text:SetWidth(0)
    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
    tab._bravColorGuard = true
    local selected = IsTabSelected(tab)
    if selected then
      if db.useClassColorActive ~= false then
        local cr, cg, cb = GetClassColor()
        text:SetTextColor(cr, cg, cb, 1)
      else
        local atc = db.activeTabTextColor
        text:SetTextColor(atc and atc.r or 1, atc and atc.g or 1, atc and atc.b or 1, 1)
      end
    elseif db.useClassColor then
      local cr, cg, cb = GetClassColor()
      text:SetTextColor(cr, cg, cb, db.fadeTabs and (db.fadeTabsAlpha or 0.45) or 0.7)
    else
      local tc = db.tabTextColor
      text:SetTextColor(tc and tc.r or 1, tc and tc.g or 1, tc and tc.b or 1, db.fadeTabs and (db.fadeTabsAlpha or 0.45) or 1)
    end
    tab._bravColorGuard = false
    local textW = text:GetStringWidth()
    if not textW or textW < 10 then textW = 40 end
    local finalW = textW + 16
    tab._bravFixedWidth = finalW
    tab:SetWidth(finalW)
  end

  if tab._bravBg then tab._bravBg:Hide() end

  -- Underline
  if not tab._bravUnderline then
    local line = tab:CreateTexture(nil, "OVERLAY")
    line._isBravTexture = true
    line:SetTexture(TEX)
    local cr, cg, cb = GetClassColor()
    line:SetVertexColor(cr, cg, cb, 1)
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 2, 0)
    line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 0)
    line:Hide()
    tab._bravUnderline = line
  end
  if tab._bravUnderline then
    tab._bravUnderline:SetShown(IsTabSelected(tab))
  end

  if tab._bravHooked then return end
  tab._bravHooked = true

  -- Pre-hooks to block Blizzard repositioning
  local origSetAlpha = tab.SetAlpha
  tab.SetAlpha = function(self, a, ...)
    if self._bravOverflowed then return origSetAlpha(self, a, ...) end
    if a < 1 then return origSetAlpha(self, 1, ...) end
    return origSetAlpha(self, a, ...)
  end
  local origTabSetWidth = tab.SetWidth
  tab.SetWidth = function(self, w, ...)
    if self._bravWidthCapped or self._bravOverflowed then return origTabSetWidth(self, w, ...) end
    if self._bravFixedWidth then return origTabSetWidth(self, self._bravFixedWidth, ...) end
    return origTabSetWidth(self, w, ...)
  end
  local origSetHeight = tab.SetHeight
  tab.SetHeight = function(self, h, ...)
    if self._bravOverflowed then return origSetHeight(self, h, ...) end
    return origSetHeight(self, db.tabHeight or 15, ...)
  end
  local origSetScale = tab.SetScale
  tab.SetScale = function(self, s, ...) return origSetScale(self, 1, ...) end

  local origSetPoint = tab.SetPoint
  local origClearAllPoints = tab.ClearAllPoints
  tab._bravAllowSetPoint = false
  tab.SetPoint = function(self, ...)
    if self._bravAllowSetPoint then return origSetPoint(self, ...) end
  end
  tab.ClearAllPoints = function(self, ...)
    if self._bravAllowSetPoint then return origClearAllPoints(self, ...) end
  end

  local origTextSetWidth = text.SetWidth
  text.SetWidth = function(self, w, ...)
    if tab._bravWidthCapped then return origTextSetWidth(self, w, ...) end
    if w and w > 0 then return origTextSetWidth(self, 0, ...) end
    return origTextSetWidth(self, w, ...)
  end

  local origTextSetColor = text.SetTextColor
  text.SetTextColor = function(self, r, g, b, a, ...)
    if tab._bravColorGuard or tab._bravFlashing then
      return origTextSetColor(self, r, g, b, a, ...)
    end
    tab._bravColorGuard = true
    RefreshOneTab(tab)
    tab._bravColorGuard = false
  end

  tab:HookScript("OnShow", function(self) SimpleStripTab(self); RefreshAllTabs() end)
  tab:HookScript("OnLeave", function() RefreshAllTabs() end)
  tab:HookScript("OnClick", function() SimpleStripTab(tab); RefreshAllTabs() end)
  tab:HookScript("OnEnter", function()
    if text then
      tab._bravColorGuard = true
      local chatDb = GetDB()
      if chatDb.useClassColorActive == false then
        local atc = chatDb.activeTabTextColor
        text:SetTextColor(atc and atc.r or 1, atc and atc.g or 1, atc and atc.b or 1, 1)
      else
        local cr, cg, cb = GetClassColor()
        text:SetTextColor(cr, cg, cb, 1)
      end
      tab._bravColorGuard = false
    end
  end)
end

-- ============================================================================
-- OVERFLOW DROPDOWN
-- ============================================================================

_overflowEntries = {}
local _priorityFrame

local function CreateOverflowBtn(cf1, db)
  if _overflowBtn then return _overflowBtn end
  local btn = CreateFrame("Button", "BravUI_OverflowBtn", cf1:GetParent() or UIParent)
  btn:SetHeight(db.tabHeight or 20)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(10)
  local text = btn:CreateFontString(nil, "OVERLAY")
  pcall(function() text:SetFont(GetFont(), db.tabFontSize or 12, "") end)
  text:SetPoint("CENTER")
  text:SetTextColor(1, 1, 1, 1)
  text:SetText("+ MP (0)")
  btn._text = text
  local line = btn:CreateTexture(nil, "OVERLAY")
  line._isBravTexture = true
  line:SetTexture(TEX)
  local cr, cg, cb = GetClassColor()
  line:SetVertexColor(cr, cg, cb, 1)
  line:SetHeight(2)
  line:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 0)
  line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 0)
  line:Hide()
  btn._bravUnderline = line
  btn:SetScript("OnEnter", function()
    local r, g, b = GetClassColor()
    text:SetTextColor(r, g, b, 1)
  end)
  btn:SetScript("OnLeave", function()
    if not btn._bravFlashing then text:SetTextColor(1, 1, 1, 1) end
  end)
  btn:SetScript("OnClick", function() ToggleOverflowDropdown() end)
  btn:Hide()
  _overflowBtn = btn
  return btn
end

local function CreateOverflowDropdown()
  if _overflowDropdown then return _overflowDropdown end
  local dd = CreateFrame("Frame", "BravUI_OverflowDropdown", UIParent)
  dd:SetWidth(160)
  dd:SetFrameStrata("DIALOG")
  dd:SetFrameLevel(200)
  dd:SetClampedToScreen(true)
  local bg = dd:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX)
  bg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
  bg:SetAllPoints()
  local cr, cg, cb = GetClassColor()
  -- borders
  local function AB(f, r, g, b, a)
    local t1 = f:CreateTexture(nil, "BORDER"); t1:SetTexture(TEX); t1:SetVertexColor(r, g, b, a or 1)
    t1:SetPoint("TOPLEFT"); t1:SetPoint("TOPRIGHT"); t1:SetHeight(1)
    local t2 = f:CreateTexture(nil, "BORDER"); t2:SetTexture(TEX); t2:SetVertexColor(r, g, b, a or 1)
    t2:SetPoint("BOTTOMLEFT"); t2:SetPoint("BOTTOMRIGHT"); t2:SetHeight(1)
    local t3 = f:CreateTexture(nil, "BORDER"); t3:SetTexture(TEX); t3:SetVertexColor(r, g, b, a or 1)
    t3:SetPoint("TOPLEFT"); t3:SetPoint("BOTTOMLEFT"); t3:SetWidth(1)
    local t4 = f:CreateTexture(nil, "BORDER"); t4:SetTexture(TEX); t4:SetVertexColor(r, g, b, a or 1)
    t4:SetPoint("TOPRIGHT"); t4:SetPoint("BOTTOMRIGHT"); t4:SetWidth(1)
  end
  AB(dd, cr, cg, cb, 0.8)
  dd._buttons = {}
  dd:Hide()
  dd:SetScript("OnUpdate", function(self)
    if not self:IsShown() then return end
    if IsMouseButtonDown("LeftButton") then
      local isUs = self:IsMouseOver()
      if not isUs and _overflowBtn then isUs = _overflowBtn:IsMouseOver() end
      if not isUs then
        for _, b in ipairs(self._buttons) do
          if b:IsMouseOver() then isUs = true; break end
        end
      end
      if not isUs then self:Hide() end
    end
  end)
  _overflowDropdown = dd
  return dd
end

local function RefreshOverflowDropdown()
  local dd = _overflowDropdown
  if not dd then return end
  local entries = _overflowEntries
  local font = GetFont()
  local cr, cg, cb = GetClassColor()
  for _, btn in ipairs(dd._buttons) do btn:Hide() end
  local y = -2
  local ROW_H = 22
  for i, entry in ipairs(entries) do
    local btn = dd._buttons[i]
    if not btn then
      btn = CreateFrame("Button", nil, dd)
      btn:SetHeight(ROW_H)
      dd._buttons[#dd._buttons + 1] = btn
      local btnBg = btn:CreateTexture(nil, "BACKGROUND")
      btnBg:SetTexture(TEX); btnBg:SetVertexColor(0, 0, 0, 0); btnBg:SetAllPoints()
      btn._bg = btnBg
      local btnTxt = btn:CreateFontString(nil, "OVERLAY")
      pcall(function() btnTxt:SetFont(font, 11, "") end)
      btnTxt:SetPoint("LEFT", btn, "LEFT", 8, 0)
      btnTxt:SetJustifyH("LEFT")
      btn._text = btnTxt
      local dot = btn:CreateTexture(nil, "OVERLAY")
      dot:SetTexture(TEX); dot:SetSize(6, 6)
      dot:SetPoint("RIGHT", btn, "RIGHT", -6, 0); dot:Hide()
      btn._dot = dot
      btn:SetScript("OnEnter", function()
        btnBg:SetVertexColor(cr, cg, cb, 0.2)
        btn._text:SetTextColor(cr, cg, cb, 1)
      end)
      btn:SetScript("OnLeave", function()
        btnBg:SetVertexColor(0, 0, 0, 0)
        btn._text:SetTextColor(0.9, 0.9, 0.9, 1)
      end)
    end
    local shortName = entry.contactName and entry.contactName:match("^([^%-]+)") or "?"
    btn._text:SetText(shortName)
    btn._text:SetTextColor(0.9, 0.9, 0.9, 1)
    btn._bg:SetVertexColor(0, 0, 0, 0)
    if entry.tab and entry.tab._bravFlashing then
      local line = entry.tab._bravUnderline
      if line then
        local lr, lg, lb = line:GetVertexColor()
        btn._dot:SetVertexColor(lr, lg, lb, 1); btn._dot:Show()
      else btn._dot:Hide() end
    else btn._dot:Hide() end
    btn:SetPoint("TOPLEFT", dd, "TOPLEFT", 2, y)
    btn:SetPoint("TOPRIGHT", dd, "TOPRIGHT", -2, y)
    local tabRef = entry.tab
    local frameRef = entry.frameName
    btn:SetScript("OnClick", function()
      dd:Hide()
      local chatFrame = _G[frameRef]
      if chatFrame then
        _priorityFrame = chatFrame
        if tabRef._bravOverflowed then tabRef._bravOverflowed = false; tabRef:SetAlpha(1) end
        FCF_Tab_OnClick(tabRef)
        C_Timer.After(0, function()
          if Chat.panel then LayoutTabs(Chat.panel, GetDB()) end
        end)
      end
    end)
    btn:Show()
    y = y - ROW_H
  end
  dd:SetHeight(math.max(#entries * ROW_H + 4, ROW_H))
end

function ToggleOverflowDropdown()
  local dd = CreateOverflowDropdown()
  if dd:IsShown() then dd:Hide(); return end
  if _overflowBtn then
    dd:ClearAllPoints()
    dd:SetPoint("TOPLEFT", _overflowBtn, "BOTTOMLEFT", 0, -2)
  end
  RefreshOverflowDropdown()
  dd:Show()
end

-- Overflow flash helpers
local function FlashOverflowBtn(r, g, b)
  local btn = _overflowBtn
  if not btn or not btn:IsShown() then return end
  local line = btn._bravUnderline
  if not line then return end
  if btn._bravFlashing then line:SetVertexColor(r, g, b, 1); return end
  btn._bravFlashing = true
  line:SetVertexColor(r, g, b, 1); line:Show()
  local text = btn._text
  local elapsed = 0
  if not btn._bravFlashFrame then btn._bravFlashFrame = CreateFrame("Frame", nil, btn) end
  btn._bravFlashFrame:SetScript("OnUpdate", function(self, dt)
    if not btn._bravFlashing then self:SetScript("OnUpdate", nil); return end
    elapsed = elapsed + dt
    local alpha = 0.6 + 0.4 * math.sin(elapsed * math.pi * 2)
    line:SetAlpha(alpha)
    if text then text:SetTextColor(r, g, b, alpha) end
  end)
end

local function StopFlashOverflowBtn()
  local btn = _overflowBtn
  if not btn or not btn._bravFlashing then return end
  btn._bravFlashing = false
  if btn._bravFlashFrame then btn._bravFlashFrame:SetScript("OnUpdate", nil) end
  if btn._bravUnderline then btn._bravUnderline:Hide(); btn._bravUnderline:SetAlpha(1) end
  if btn._text then btn._text:SetTextColor(1, 1, 1, 1) end
end

local function UpdateOverflowFlash()
  local anyFlashing = false
  local fr, fg, fb = 1, 1, 1
  for _, entry in ipairs(_overflowEntries) do
    if entry.tab and entry.tab._bravFlashing then
      anyFlashing = true
      local line = entry.tab._bravUnderline
      if line then fr, fg, fb = line:GetVertexColor() end
      break
    end
  end
  if anyFlashing then FlashOverflowBtn(fr, fg, fb) else StopFlashOverflowBtn() end
end

-- ============================================================================
-- TAB LAYOUT
-- ============================================================================

local function LayoutTabs(panel, db)
  local cf1 = _G.ChatFrame1
  if not cf1 then return end
  -- Unlock SetPoint for all tabs
  local unlockedTabs = {}
  for i = 1, NUM_WINDOWS do
    local t = _G["ChatFrame" .. i .. "Tab"]
    if t then t._bravAllowSetPoint = true; unlockedTabs[#unlockedTabs + 1] = t end
  end
  if type(CHAT_FRAMES) == "table" then
    for _, fn in ipairs(CHAT_FRAMES) do
      local cf = _G[fn]
      if cf and cf.isTemporary then
        local t = _G[fn .. "Tab"]
        if t then t._bravAllowSetPoint = true; unlockedTabs[#unlockedTabs + 1] = t end
      end
    end
  end
  local maxWidth = cf1:GetWidth() + INSET * 2
  local overflowBtn = CreateOverflowBtn(cf1, db)
  overflowBtn._text:SetText("+ MP (9)")
  local overflowW = (overflowBtn._text:GetStringWidth() or 50) + 16
  local x = 0
  -- Permanent tabs
  for i = 1, NUM_WINDOWS do
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab and tab:IsShown() then
      SimpleStripTab(tab)
      tab:ClearAllPoints()
      tab:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", x, 1)
      tab:SetHeight(db.tabHeight or 15)
      tab:SetScale(1)
      local w = tab._bravFixedWidth or tab:GetWidth()
      tab:SetWidth(w)
      x = x + w + TAB_GAP
    end
  end
  -- Collect temp tabs
  local tempTabs = {}
  local priorityFrame = _priorityFrame or SELECTED_CHAT_FRAME or SELECTED_DOCK_FRAME
  local priorityEntry
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local cf = _G[frameName]
      if cf and cf.isTemporary and not cf._bravClosed then
        local tab = _G[frameName .. "Tab"]
        if tab then
          local entry = { tab = tab, frameName = frameName, cf = cf }
          if cf == priorityFrame then priorityEntry = entry
          else tempTabs[#tempTabs + 1] = entry end
        end
      end
    end
  end
  if priorityEntry then table.insert(tempTabs, 1, priorityEntry) end
  -- Truncate long names
  local MAX_NAME_LEN = 8
  for _, entry in ipairs(tempTabs) do
    entry.tab._bravWidthCapped = false
    entry.tab._bravFixedWidth = nil
    SimpleStripTab(entry.tab)
    local txt = entry.tab.Text or _G[entry.tab:GetName() .. "Text"]
    if txt and txt.GetText then
      local ok, rawText = pcall(txt.GetText, txt)
      if ok and rawText and type(rawText) == "string" and #rawText > MAX_NAME_LEN then
        entry.tab._bravWidthCapped = true
        txt:SetText(rawText:sub(1, MAX_NAME_LEN) .. "..")
        txt:SetWidth(0)
        local textW = txt:GetStringWidth()
        if not textW or textW < 10 then textW = 40 end
        entry.tab:SetWidth(textW + 16)
      end
    end
    entry._width = entry.tab:GetWidth()
  end
  local totalTempW = 0
  for _, entry in ipairs(tempTabs) do totalTempW = totalTempW + entry._width + TAB_GAP end
  local visibleTemps, overflowList = {}, {}
  if x + totalTempW <= maxWidth then
    for _, entry in ipairs(tempTabs) do visibleTemps[#visibleTemps + 1] = entry end
  else
    local tempX = x
    for _, entry in ipairs(tempTabs) do
      if tempX + entry._width + TAB_GAP + overflowW + TAB_GAP <= maxWidth then
        visibleTemps[#visibleTemps + 1] = entry
        tempX = tempX + entry._width + TAB_GAP
      else
        overflowList[#overflowList + 1] = entry
      end
    end
  end
  for _, entry in ipairs(visibleTemps) do
    entry.tab._bravOverflowed = false
    entry.tab:SetAlpha(1)
    entry.tab:SetWidth(entry._width)
    entry.tab:ClearAllPoints()
    entry.tab:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", x, 1)
    entry.tab:SetHeight(db.tabHeight or 15)
    entry.tab:SetScale(1)
    entry.tab:Show()
    x = x + entry._width + TAB_GAP
  end
  for _, entry in ipairs(overflowList) do
    entry.tab:ClearAllPoints()
    entry.tab:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
    entry.tab:SetAlpha(0)
    entry.tab._bravOverflowed = true
  end
  _overflowEntries = {}
  for _, entry in ipairs(overflowList) do
    local contactName = entry.cf._bravContactName
    if not contactName then
      local txt = entry.tab.Text or _G[entry.tab:GetName() .. "Text"]
      if txt and txt.GetText then
        local ok, raw = pcall(txt.GetText, txt)
        if ok and raw and type(raw) == "string" and not IsSecret(raw) then contactName = raw end
      end
    end
    _overflowEntries[#_overflowEntries + 1] = { tab = entry.tab, frameName = entry.frameName, contactName = contactName or "?" }
  end
  if #overflowList > 0 then
    overflowBtn._text:SetText("+ MP (" .. #overflowList .. ")")
    local btnW = (overflowBtn._text:GetStringWidth() or 40) + 16
    overflowBtn:SetWidth(btnW)
    overflowBtn:ClearAllPoints()
    overflowBtn:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", x, 1)
    overflowBtn:SetHeight(db.tabHeight or 15)
    overflowBtn:Show()
    UpdateOverflowFlash()
    if _overflowDropdown and _overflowDropdown:IsShown() then RefreshOverflowDropdown() end
  else
    overflowBtn:Hide()
    StopFlashOverflowBtn()
    if _overflowDropdown then _overflowDropdown:Hide() end
  end
  for _, t in ipairs(unlockedTabs) do t._bravAllowSetPoint = false end
end

-- ============================================================================
-- TAB FLASH
-- ============================================================================

local function FlashTab(tabIndex, r, g, b)
  local tab = _G["ChatFrame" .. tabIndex .. "Tab"]
  if not tab then return end
  if IsTabSelected(tab) then return end
  if tab._bravOverflowed then
    tab._bravFlashing = true
    if tab._bravUnderline then tab._bravUnderline:SetVertexColor(r, g, b, 1) end
    FlashOverflowBtn(r, g, b)
    if _overflowDropdown and _overflowDropdown:IsShown() then RefreshOverflowDropdown() end
    return
  end
  if not tab._bravUnderline then
    if Chat.panel then SkinTab(tab, Chat.panel, GetDB()) end
  end
  local line = tab._bravUnderline
  if not line then return end
  if tab._bravFlashing then line:SetVertexColor(r, g, b, 1); return end
  tab._bravFlashing = true
  line:SetVertexColor(r, g, b, 1); line:Show(); line:SetAlpha(1)
  local text = tab.Text or _G[tab:GetName() .. "Text"]
  local elapsed = 0
  if not tab._bravFlashFrame then tab._bravFlashFrame = CreateFrame("Frame", nil, tab) end
  tab._bravFlashFrame:SetScript("OnUpdate", function(self, dt)
    if not tab._bravFlashing then self:SetScript("OnUpdate", nil); return end
    elapsed = elapsed + dt
    local alpha = 0.6 + 0.4 * math.sin(elapsed * math.pi * 2)
    line:SetAlpha(alpha)
    if text then text:SetTextColor(r, g, b, alpha) end
  end)
end

local function StopFlashTab(tabIndex)
  local tab = _G["ChatFrame" .. tabIndex .. "Tab"]
  if not tab or not tab._bravFlashing then return end
  tab._bravFlashing = false
  if tab._bravFlashFrame then tab._bravFlashFrame:SetScript("OnUpdate", nil) end
  if tab._bravUnderline then
    local cr, cg, cb = GetClassColor()
    tab._bravUnderline:SetVertexColor(cr, cg, cb, 1)
    tab._bravUnderline:SetAlpha(1)
    tab._bravUnderline:SetShown(IsTabSelected(tab))
  end
  RefreshOneTab(tab)
  UpdateOverflowFlash()
end

-- ============================================================================
-- EDITBOX SKINNING
-- ============================================================================

local function SkinEditBox(eb, cf, panel, db)
  if not eb or not cf then return end
  for _, region in pairs({ eb:GetRegions() }) do
    if region then
      local objType = region.GetObjectType and region:GetObjectType()
      if objType == "Texture" then region:SetTexture(nil); region:SetAlpha(0); region:Hide() end
    end
  end
  local texNames = { "Left", "Mid", "Right", "Middle", "FocusLeft", "FocusMid", "FocusRight", "FocusMiddle",
    "LeftTex", "MidTex", "RightTex", "TopTex", "BottomTex", "TopLeft", "TopRight", "BottomLeft", "BottomRight" }
  for _, name in ipairs(texNames) do
    local tex = eb[name]
    if tex then
      if tex.SetTexture then tex:SetTexture(nil) end
      if tex.SetAlpha then tex:SetAlpha(0) end
      if tex.Hide then tex:Hide() end
    end
  end
  if eb.SetBackdrop then eb:SetBackdrop(nil) end
  eb:SetHeight(GetInfoBarH())
  eb:SetTextInsets(5, 5, 2, 2)
  eb:SetFont(GetFont(), db.fontSize or 12, "")
  eb:ClearAllPoints()
  eb:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
  eb:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  eb:SetFrameStrata("MEDIUM")
  eb:Hide()

  -- Background
  if not eb._bravBg then
    local bg2 = CreateFrame("Frame", nil, eb, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bg2:SetFrameLevel(math.max(1, eb:GetFrameLevel() - 1))
    eb._bravBg = bg2
  end
  eb._bravBg:ClearAllPoints()
  eb._bravBg:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 1)
  eb._bravBg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, -1)
  eb._bravBg:SetBackdrop({ bgFile = TEX })
  eb._bravBg:SetBackdropColor(0, 0, 0, 0.9)
  eb._bravBg:Show()

  -- Class color border
  if not eb._bravBorders then
    local ecr, ecg, ecb = GetClassColor()
    local PU = PixelUtil
    local ebg = eb._bravBg
    local eTop = ebg:CreateTexture(nil, "OVERLAY", nil, 7)
    eTop:SetTexture(TEX); eTop:SetVertexColor(ecr, ecg, ecb, 1)
    PU.SetPoint(eTop, "TOPLEFT", ebg, "TOPLEFT", 0, 0); PU.SetPoint(eTop, "TOPRIGHT", ebg, "TOPRIGHT", 0, 0); PU.SetHeight(eTop, BORDER_W)
    local eBot = ebg:CreateTexture(nil, "OVERLAY", nil, 7)
    eBot:SetTexture(TEX); eBot:SetVertexColor(ecr, ecg, ecb, 1)
    PU.SetPoint(eBot, "BOTTOMLEFT", ebg, "BOTTOMLEFT", 0, 0); PU.SetPoint(eBot, "BOTTOMRIGHT", ebg, "BOTTOMRIGHT", 0, 0); PU.SetHeight(eBot, BORDER_W)
    local eLeft = ebg:CreateTexture(nil, "OVERLAY", nil, 7)
    eLeft:SetTexture(TEX); eLeft:SetVertexColor(ecr, ecg, ecb, 1)
    PU.SetPoint(eLeft, "TOPLEFT", ebg, "TOPLEFT", 0, 0); PU.SetPoint(eLeft, "BOTTOMLEFT", ebg, "BOTTOMLEFT", 0, 0); PU.SetWidth(eLeft, BORDER_W)
    local eRight = ebg:CreateTexture(nil, "OVERLAY", nil, 7)
    eRight:SetTexture(TEX); eRight:SetVertexColor(ecr, ecg, ecb, 1)
    PU.SetPoint(eRight, "TOPRIGHT", ebg, "TOPRIGHT", 0, 0); PU.SetPoint(eRight, "BOTTOMRIGHT", ebg, "BOTTOMRIGHT", 0, 0); PU.SetWidth(eRight, BORDER_W)
    eb._bravBorders = { eTop, eBot, eLeft, eRight }
  end

  -- Custom cursor
  if not eb._bravCursor then
    local cursor = eb:CreateTexture(nil, "OVERLAY", nil, 7)
    cursor:SetColorTexture(1, 1, 1, 0.9)
    cursor:SetSize(1, db.fontSize or 12)
    cursor:Hide()
    cursor._isBravCursor = true
    eb._bravCursor = cursor
    local blinkTime, blinkOn = 0, true
    eb:HookScript("OnUpdate", function(self, elapsed)
      if not self:HasFocus() then cursor:Hide(); return end
      blinkTime = blinkTime + elapsed
      if blinkTime >= 0.53 then blinkTime = blinkTime - 0.53; blinkOn = not blinkOn end
      cursor:SetShown(blinkOn)
      local cursorPos = self:GetCursorPosition() or 0
      local text2 = self:GetText() or ""
      local _, size = self:GetFont()
      size = size or 12
      cursor:SetHeight(size + 2)
      cursor:ClearAllPoints()
      local beforeText = text2:sub(1, cursorPos)
      local measure = self._bravMeasure
      if not measure then measure = self:CreateFontString(nil, "BACKGROUND"); measure:Hide(); self._bravMeasure = measure end
      local font = self:GetFont()
      measure:SetFont(font or GetFont(), size, "")
      measure:SetText(beforeText)
      local textW = measure:GetUnboundedStringWidth() or measure:GetStringWidth() or 0
      if self.header and self.header:IsShown() then
        cursor:SetPoint("LEFT", self.header, "RIGHT", textW, 0)
      else
        cursor:SetPoint("LEFT", self, "LEFT", 5 + textW, 0)
      end
    end)
    eb:HookScript("OnEditFocusGained", function() blinkTime = 0; blinkOn = true; cursor:Show() end)
    eb:HookScript("OnEditFocusLost", function() cursor:Hide() end)
  end

  if not eb._bravFocusHooked then
    eb._bravFocusHooked = true
    eb:HookScript("OnEditFocusGained", function(self)
      pcall(self.Show, self)
      for _, region in pairs({ self:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
          if not region._isBravCursor then region:SetTexture(nil); region:SetAlpha(0); region:Hide() end
        end
      end
      if db.editBoxBorderByChannel and self._bravBorders then
        local chatType = self:GetAttribute("chatType") or "SAY"
        local col = CHANNEL_COLORS[chatType] or CHANNEL_COLORS.SAY
        for _, tex in ipairs(self._bravBorders) do tex:SetVertexColor(col[1], col[2], col[3], 1) end
      end
    end)
    eb:HookScript("OnEditFocusLost", function(self) pcall(self.Hide, self) end)
  end
  if not eb._bravHeaderHooked then
    eb._bravHeaderHooked = true
    hooksecurefunc("ChatEdit_UpdateHeader", function(editbox)
      if editbox ~= eb then return end
      if not db.editBoxBorderByChannel or not eb._bravBorders then return end
      local chatType = editbox:GetAttribute("chatType") or "SAY"
      local col = CHANNEL_COLORS[chatType] or CHANNEL_COLORS.SAY
      for _, tex in ipairs(eb._bravBorders) do tex:SetVertexColor(col[1], col[2], col[3], 1) end
    end)
  end
end

-- ============================================================================
-- MISC SKINNING FUNCTIONS
-- ============================================================================

local function SetupFade(panel, db)
  for i = 1, NUM_WINDOWS do
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab then tab:SetAlpha(1) end
  end
end

local function SkinTemporary(cf, panel, db)
  if not cf or cf._bravTempSkinned then return end
  cf._bravTempSkinned = true
  local name = cf:GetName()
  StripTextures(cf)
  if cf.SetFont then cf:SetFont(GetFont(), db.fontSize or 12, "") end
  local btnFrame = name and _G[name .. "ButtonFrame"]
  if btnFrame then StripTextures(btnFrame); Hide(btnFrame) end
  local tab = name and _G[name .. "Tab"]
  if tab then SkinTab(tab, panel, db) end
  local eb = name and _G[name .. "EditBox"]
  if eb then SkinEditBox(eb, cf, panel, db) end
end

local function LayoutDock(panel, db)
  local dock = _G.GeneralDockManager
  local cf1 = _G.ChatFrame1
  if not dock or not cf1 then return end
  if not InCombatLockdown() then
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", 0, 1)
    dock:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", 0, 1)
    dock:SetHeight(db.tabHeight or 15)
  end
  StripTextures(dock)
  local scrollFrame = _G.GeneralDockManagerScrollFrame
  if scrollFrame then
    StripTextures(scrollFrame)
    if not scrollFrame._bravStripped then
      scrollFrame._bravStripped = true
      for _, region in pairs({ scrollFrame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then KillTexture(region) end
      end
    end
    if scrollFrame.GetScrollChild then
      local sc = scrollFrame:GetScrollChild()
      if sc then StripTextures(sc); if sc.SetBackdrop then pcall(sc.SetBackdrop, sc, nil) end end
    end
    if scrollFrame.SetBackdrop then pcall(scrollFrame.SetBackdrop, scrollFrame, nil) end
  end
  if dock.SetBackdrop then pcall(dock.SetBackdrop, dock, nil) end
  local overflow = _G.GeneralDockManagerOverflowButton
  if overflow then Hide(overflow) end
end

local function StripAllChatFrames(db)
  for i = 1, NUM_WINDOWS do
    local cf = _G["ChatFrame" .. i]
    if cf then StripTextures(cf); if cf.SetBackdrop then pcall(cf.SetBackdrop, cf, nil) end end
  end
end

local function RefreshColors(panel)
  if not panel then return end
  local r, g, b = GetClassColor()
  if panel._borders then
    for _, tex in pairs(panel._borders) do
      if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, 1) end
    end
  end
  if panel._tabSep then panel._tabSep:SetVertexColor(r, g, b, 0.5) end
  local function RefreshTabColor(tab, chatFrame)
    if not tab then return end
    if tab._bravUnderline then tab._bravUnderline:SetVertexColor(r, g, b, 1) end
  end
  for i = 1, NUM_WINDOWS do RefreshTabColor(_G["ChatFrame" .. i .. "Tab"], _G["ChatFrame" .. i]) end
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local cf = _G[frameName]
      if cf and cf.isTemporary then RefreshTabColor(_G[frameName .. "Tab"], cf) end
    end
  end
  if panel._infoBar then
    local ib = panel._infoBar
    if ib._borders then for _, tex in pairs(ib._borders) do if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, 1) end end end
    if ib._sep1 then ib._sep1:SetVertexColor(r, g, b, 0.5) end
    if ib._sep2 then ib._sep2:SetVertexColor(r, g, b, 0.5) end
    if ib._sep3 then ib._sep3:SetVertexColor(r, g, b, 0.5) end
  end
end

local function RefreshFonts(panel, db)
  if not panel or not db then return end
  local font = GetFont()
  for i = 1, NUM_WINDOWS do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.SetFont then pcall(cf.SetFont, cf, font, db.fontSize or 12, "") end
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab then
      local txt = tab.Text or _G[tab:GetName() .. "Text"]
      if txt and txt.SetFont then pcall(txt.SetFont, txt, font, db.tabFontSize or 12, "") end
    end
  end
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local cf = _G[frameName]
      if cf and cf.isTemporary then
        if cf.SetFont then pcall(cf.SetFont, cf, font, db.fontSize or 12, "") end
        local tab = _G[frameName .. "Tab"]
        if tab then
          local txt = tab.Text or _G[tab:GetName() .. "Text"]
          if txt and txt.SetFont then pcall(txt.SetFont, txt, font, db.tabFontSize or 12, "") end
        end
      end
    end
  end
  for i = 1, NUM_WINDOWS do
    local eb = _G["ChatFrame" .. i .. "EditBox"]
    if eb and eb.SetFont then pcall(eb.SetFont, eb, font, db.fontSize or 12, "") end
  end
end

-- ============================================================================
-- INFOBAR DATA FUNCTIONS
-- ============================================================================

local specText, goldText, durabilityText, perfText
local infoBarFrame  -- standalone frame
local cachedLoadoutName

local INVENTORY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17 }

local function FindActiveLoadoutName()
  if not (C_ClassTalents and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetNodeInfo) then return nil end
  local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
  if not specID then return nil end
  local activeConfigID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
  if not activeConfigID then return nil end
  local configIDs = C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetConfigIDsBySpecID(specID)
  if not configIDs or #configIDs == 0 then return nil end
  local activeInfo = C_Traits.GetConfigInfo(activeConfigID)
  if not activeInfo or not activeInfo.treeIDs or #activeInfo.treeIDs == 0 then return nil end
  local treeID = activeInfo.treeIDs[1]
  local nodeIDs = C_Traits.GetTreeNodes and C_Traits.GetTreeNodes(treeID)
  if not nodeIDs then return nil end
  local activeFingerprint = {}
  for _, nodeID in ipairs(nodeIDs) do
    local ok, nodeInfo = pcall(C_Traits.GetNodeInfo, activeConfigID, nodeID)
    if ok and nodeInfo and nodeInfo.ranksPurchased and nodeInfo.ranksPurchased > 0 then
      local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or 0
      activeFingerprint[nodeID] = nodeInfo.ranksPurchased * 1000 + entryID
    end
  end
  for _, cid in ipairs(configIDs) do
    local ok, info = pcall(C_Traits.GetConfigInfo, cid)
    if ok and info and type(info.name) == "string" and info.name ~= "" then
      local match = true
      local hasNodes = false
      for nodeID, activeVal in pairs(activeFingerprint) do
        local ok2, lnInfo = pcall(C_Traits.GetNodeInfo, cid, nodeID)
        if ok2 and lnInfo then
          hasNodes = true
          local lnRanks = lnInfo.ranksPurchased or 0
          local lnEntry = lnInfo.activeEntry and lnInfo.activeEntry.entryID or 0
          if lnRanks * 1000 + lnEntry ~= activeVal then match = false; break end
        else match = false; break end
      end
      if match and hasNodes then return info.name end
    end
  end
  return nil
end

local function GetSpecText()
  if not GetSpecialization then return "\226\128\148" end
  local idx = GetSpecialization()
  if not idx then return "\226\128\148" end
  local _, specName = GetSpecializationInfo(idx)
  if not specName then return "\226\128\148" end
  if cachedLoadoutName then return specName .. " | " .. cachedLoadoutName end
  return specName
end

local GOLD_ICON = "|TInterface/MoneyFrame/UI-GoldIcon:0|t"
local function GetGoldText()
  local money = GetMoney() or 0
  local gold = math.floor(money / 10000)
  if gold >= 10000 then return format("%.1fk%s", gold / 1000, GOLD_ICON)
  else return format("%d%s", gold, GOLD_ICON) end
end

local function GetDurabilityText()
  local current, maximum = 0, 0
  for _, slotId in ipairs(INVENTORY_SLOTS) do
    local cur, max = GetInventoryItemDurability(slotId)
    if cur and max and max > 0 then current = current + cur; maximum = maximum + max end
  end
  if maximum == 0 then return "\226\128\148" end
  local pct = math.floor((current / maximum) * 100)
  local r, g, b = 0.2, 1.0, 0.2
  if pct < 25 then r, g, b = 1.0, 0.2, 0.2
  elseif pct < 50 then r, g, b = 1.0, 0.6, 0.0
  elseif pct < 75 then r, g, b = 1.0, 1.0, 0.0 end
  return format("|cff%02x%02x%02x%d%%|r", r * 255, g * 255, b * 255, pct)
end

local function ColorByValue(val, low, mid)
  if val < low then return "|cff33ff33"
  elseif val < mid then return "|cffffff00"
  else return "|cffff3333" end
end

local function GetPerfText()
  local fps = math.floor(GetFramerate())
  local _, _, homeMS, worldMS = GetNetStats()
  homeMS = math.floor(homeMS); worldMS = math.floor(worldMS)
  return format("%s%d|r fps  %s%d|r / %s%d|r ms",
    ColorByValue(1000 / math.max(fps, 1), 33, 66), fps,
    ColorByValue(homeMS, 100, 200), homeMS,
    ColorByValue(worldMS, 100, 200), worldMS)
end

local function RefreshLoadoutName() cachedLoadoutName = FindActiveLoadoutName() end

local function UpdateInfoBar()
  local ibDb = GetIBDb()
  if specText then specText:SetText(ibDb.showSpec ~= false and GetSpecText() or "") end
  if goldText then goldText:SetText(ibDb.showGold ~= false and GetGoldText() or "") end
  if durabilityText then durabilityText:SetText(ibDb.showDurability ~= false and GetDurabilityText() or "") end
  if perfText then perfText:SetText(ibDb.showPerf ~= false and GetPerfText() or "") end
end

-- ============================================================================
-- INFOBAR STANDALONE MODE
-- ============================================================================

local function CreateInfoBarStandalone()
  if infoBarFrame then return end
  local ibDb = GetIBDb()
  local h = ibDb.height or 22
  local alpha = ibDb.opacity or 0.75

  local f = CreateFrame("Frame", "BravUI_InfoBar", UIParent)
  f:SetSize(480, h)
  f:SetPoint("TOP", UIParent, "TOP", 0, -4)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)

  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetTexture(TEX); bg:SetVertexColor(0, 0, 0, alpha); bg:SetAllPoints(f)
  f._bg = bg

  U.CreateClassBorder(f)
  f:SetMovable(true)
  f:EnableMouse(false)

  local cr, cg, cb = GetClassColor()
  local function MakeSep()
    local s = f:CreateTexture(nil, "ARTWORK")
    s:SetTexture(TEX); s:SetVertexColor(cr, cg, cb, 0.5); s:SetSize(1, 14)
    return s
  end
  f._sep1 = MakeSep(); f._sep1:SetPoint("CENTER", f, "LEFT", 120, 0)
  f._sep2 = MakeSep(); f._sep2:SetPoint("CENTER", f, "LEFT", 240, 0)
  f._sep3 = MakeSep(); f._sep3:SetPoint("CENTER", f, "LEFT", 360, 0)

  local FONT_PATH = GetFont()
  local fs = ibDb.fontSize or 11
  local function MakeSection(parent, x, width, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, h)
    btn:SetPoint("LEFT", parent, "LEFT", x, 0)
    local txt = btn:CreateFontString(nil, "OVERLAY")
    txt:SetFontObject("GameFontHighlightSmall")
    pcall(function() txt:SetFont(FONT_PATH, fs, "OUTLINE") end)
    txt:SetPoint("CENTER"); txt:SetTextColor(1, 1, 1, 1)
    btn:SetScript("OnEnter", function() txt:SetTextColor(1, 1, 0, 1) end)
    btn:SetScript("OnLeave", function() txt:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnClick", function() if InCombatLockdown() then return end; onClick() end)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    btn:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    return txt
  end

  f._specText = MakeSection(f, 0, 120, function()
    if PlayerSpellsMicroButton then PlayerSpellsMicroButton:Click()
    elseif TalentMicroButton then TalentMicroButton:Click() end
  end)
  f._goldText = MakeSection(f, 120, 120, function() ToggleAllBags() end)
  f._durabilityText = MakeSection(f, 240, 120, function()
    if CharacterMicroButton then CharacterMicroButton:Click() end
  end)
  f._perfText = MakeSection(f, 360, 120, function() end)

  f:Show()
  infoBarFrame = f

  -- Register with Move system
  BravUI.Move.Enable(f, "InfoBar")
end

-- ============================================================================
-- INFOBAR BIND / UNBIND
-- ============================================================================

local _boundZone

local function BindInfoBar(barFrame)
  if not barFrame then return end
  if infoBarFrame then infoBarFrame:Hide() end
  _boundZone = barFrame
  specText = barFrame._specText
  goldText = barFrame._goldText
  durabilityText = barFrame._durabilityText
  perfText = barFrame._perfText
  RefreshLoadoutName()
  UpdateInfoBar()
end

local function UnbindInfoBar()
  _boundZone = nil
  if not infoBarFrame then CreateInfoBarStandalone() else infoBarFrame:Show() end
  if infoBarFrame then
    specText = infoBarFrame._specText
    goldText = infoBarFrame._goldText
    durabilityText = infoBarFrame._durabilityText
    perfText = infoBarFrame._perfText
  end
  UpdateInfoBar()
end

-- ============================================================================
-- WHISPER HISTORY
-- ============================================================================

local _liveContacts = {}

local function SafeString(val)
  if val == nil then return nil end
  if not IsSecret(val) and type(val) == "string" then return val ~= "" and val or nil end
  if IsSecret(val) then
    local chars = {}
    for i = 1, 100 do
      local ok, b = pcall(string.byte, val, i)
      if not ok then break end
      if type(b) ~= "number" or IsSecret(b) then break end
      if b == 0 then break end
      chars[#chars + 1] = string.char(b)
    end
    if #chars > 0 then local s = table.concat(chars); if s ~= "" then return s end end
  end
  local hs = HardString(val)
  if hs == nil or IsSecret(hs) then return nil end
  if type(hs) == "string" and hs ~= "" then return hs end
  return nil
end

local function ReadTabText(cf)
  if not cf then return nil end
  local cfName = cf:GetName()
  if not cfName then return nil end
  local tab = _G[cfName .. "Tab"]
  if not tab then return nil end
  local txt = tab.Text or _G[cfName .. "TabText"]
  if not txt or not txt.GetText then return nil end
  local ok, raw = pcall(txt.GetText, txt)
  if not ok then return nil end
  return SafeString(raw)
end

local function TagWhisperFrame(cf, contactName)
  if not cf or not contactName or contactName == "" then return end
  cf._bravContactName = contactName
end

local function TagWhisperFrameFromTab(cf)
  if not cf or cf._bravContactName then return end
  local name = ReadTabText(cf)
  if name and name ~= "" then cf._bravContactName = name end
end

local function TagAllTempFrames()
  if not CHAT_FRAMES then return end
  for _, frameName in ipairs(CHAT_FRAMES) do
    local cf = _G[frameName]
    if cf and cf.isTemporary and not cf._bravContactName then TagWhisperFrameFromTab(cf) end
  end
end

local function FindUntaggedTempFrame()
  if not CHAT_FRAMES then return nil end
  for i = #CHAT_FRAMES, 1, -1 do
    local cf = _G[CHAT_FRAMES[i]]
    if cf and cf.isTemporary and not cf._bravContactName then return cf end
  end
  return nil
end

local function FindWhisperFrame(playerName)
  if not CHAT_FRAMES then return nil end
  for _, frameName in ipairs(CHAT_FRAMES) do
    local cf = _G[frameName]
    if cf and cf.isTemporary and cf._bravContactName == playerName then return cf end
  end
  return nil
end

local function PurgeContacts(contacts, maxAgeDays, maxContacts)
  local now = time()
  local maxAge = (maxAgeDays or 30) * 86400
  for name, data in pairs(contacts) do
    if data.lastSeen and (now - data.lastSeen) > maxAge then contacts[name] = nil end
  end
  local sorted = {}
  for name, data in pairs(contacts) do sorted[#sorted + 1] = { name = name, lastSeen = data.lastSeen or 0 } end
  table.sort(sorted, function(a, b) return a.lastSeen > b.lastSeen end)
  for i = (maxContacts or 50) + 1, #sorted do contacts[sorted[i].name] = nil end
end

local function SaveWhisperMessage(contactName, text, r, g, b)
  local contact = _liveContacts[contactName]
  if not contact then
    _liveContacts[contactName] = { messages = {}, lastSeen = time() }
    contact = _liveContacts[contactName]
  end
  contact.messages = contact.messages or {}
  contact.lastSeen = time()
  contact._tabOpen = true
  contact.messages[#contact.messages + 1] = { text = text, r = r, g = g, b = b, t = time() }
  local maxMessages = 100
  while #contact.messages > maxMessages do table.remove(contact.messages, 1) end
  pcall(function()
    local charDB = BravLib.Storage.GetCharDB()
    if charDB then
      charDB.whisperHistory = charDB.whisperHistory or { contacts = {} }
      charDB.whisperHistory.contacts = charDB.whisperHistory.contacts or {}
      charDB.whisperHistory.contacts[contactName] = contact
    end
  end)
end

local function RestoreWhisperTabs()
  local sorted = {}
  for name, data in pairs(_liveContacts) do
    if data._tabOpen then sorted[#sorted + 1] = { name = name, data = data } end
  end
  if #sorted == 0 then return end
  table.sort(sorted, function(a, b) return (a.data.lastSeen or 0) > (b.data.lastSeen or 0) end)
  Chat._restoringWhispers = true
  for _, entry in ipairs(sorted) do
    local name = entry.name
    local data = entry.data
    if not FindWhisperFrame(name) then
      local chatType = data._isBN and "BN_WHISPER" or "WHISPER"
      FCF_OpenTemporaryWindow(chatType, name)
      local cf = FindUntaggedTempFrame()
      if cf then
        TagWhisperFrame(cf, name)
        local shortName = name:match("^([^%-]+)") or name
        if shortName ~= name then
          local cfName = cf:GetName()
          if cfName then
            local tab = _G[cfName .. "Tab"]
            if tab then
              local txt = tab.Text or _G[cfName .. "TabText"]
              if txt and txt.SetText then txt:SetText(shortName) end
            end
          end
        end
      end
      cf = FindWhisperFrame(name)
      if cf and data.messages and #data.messages > 0 then
        Chat._bravReplaying = true
        for _, msg in ipairs(data.messages) do
          if msg.text and type(msg.text) == "string" then cf:AddMessage(msg.text, msg.r or 1, msg.g or 1, msg.b or 1) end
        end
        Chat._bravReplaying = false
      end
    end
  end
  Chat._restoringWhispers = false
end

local function InstallWhisperHooks()
  if Chat._whisperHooksInstalled then return end
  Chat._whisperHooksInstalled = true

  hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType, ...)
    if Chat._restoringWhispers then return end
    if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then return end
    C_Timer.After(0.1, function()
      TagAllTempFrames()
      if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
          local cf = _G[frameName]
          if cf and cf.isTemporary then
            local tab = _G[frameName .. "Tab"]
            if tab then
              local txt = tab.Text or _G[frameName .. "TabText"]
              if txt and txt.GetText then
                local ok, raw = pcall(txt.GetText, txt)
                if ok and raw and not IsSecret(raw) and type(raw) == "string" then
                  local short = raw:match("^([^%-]+)")
                  if short and short ~= raw then txt:SetText(short) end
                end
              end
            end
          end
        end
      end
    end)
  end)

  local _lastInTime, _lastOutTime = {}, {}

  local function IncomingFilter(chatFrame, event, msg, sender, ...)
    if Chat._bravReplaying then return false end
    local isBN = (event == "CHAT_MSG_BN_WHISPER")
    if isBN and (not chatFrame or not chatFrame.isTemporary) then return false end
    local evTime = GetTime()
    C_Timer.After(0.2, function()
      pcall(function()
        TagAllTempFrames()
        local contactName
        if isBN then contactName = (chatFrame and chatFrame._bravContactName) or ReadTabText(chatFrame) end
        if not contactName then contactName = SafeString(sender) end
        if not contactName then
          if CHAT_FRAMES then
            for i = #CHAT_FRAMES, 1, -1 do
              local cf = _G[CHAT_FRAMES[i]]
              if cf and cf.isTemporary then
                local n = cf._bravContactName or ReadTabText(cf)
                if n then contactName = n; if not cf._bravContactName then cf._bravContactName = n end; break end
              end
            end
          end
        end
        if not contactName then return end
        if _lastInTime[contactName] == evTime then return end
        _lastInTime[contactName] = evTime
        local cf = FindWhisperFrame(contactName)
        if not cf then local ucf = FindUntaggedTempFrame(); if ucf then TagWhisperFrame(ucf, contactName) end end
        if not _liveContacts[contactName] then _liveContacts[contactName] = { messages = {}, lastSeen = time() } end
        _liveContacts[contactName].lastSeen = time()
        _liveContacts[contactName]._isBN = isBN
        local mr, mg, mb = isBN and 0.0 or 1.0, isBN and 1.0 or 0.5, isBN and 0.965 or 1.0
        local msgText = SafeString(msg)
        if msgText then
          local timestamp = date("%H:%M")
          local shortName = contactName:match("^([^%-]+)") or contactName
          local colorHex = format("%02x%02x%02x", mr * 255, mg * 255, mb * 255)
          local formatted
          if isBN then formatted = "|cff" .. colorHex .. timestamp .. " [" .. shortName .. "] chuchote : " .. msgText .. "|r"
          else formatted = "|cff" .. colorHex .. "[" .. timestamp .. "] " .. shortName .. " chuchote : " .. msgText .. "|r" end
          SaveWhisperMessage(contactName, formatted, mr, mg, mb)
        end
        local colorKey = isBN and "BN_WHISPER" or "WHISPER"
        if Chat._flashWhisperTabForContact then Chat._flashWhisperTabForContact(contactName, colorKey) end
      end)
    end)
    return false
  end

  local function OutgoingFilter(chatFrame, event, msg, target, ...)
    if Chat._bravReplaying then return false end
    local isBN = (event == "CHAT_MSG_BN_WHISPER_INFORM")
    if isBN and (not chatFrame or not chatFrame.isTemporary) then return false end
    local evTime = GetTime()
    C_Timer.After(0.2, function()
      pcall(function()
        TagAllTempFrames()
        local contactName
        if isBN then contactName = (chatFrame and chatFrame._bravContactName) or ReadTabText(chatFrame) end
        if not contactName then contactName = SafeString(target) end
        if not contactName then
          if CHAT_FRAMES then
            for i = #CHAT_FRAMES, 1, -1 do
              local cf = _G[CHAT_FRAMES[i]]
              if cf and cf.isTemporary then
                local n = cf._bravContactName or ReadTabText(cf)
                if n then contactName = n; if not cf._bravContactName then cf._bravContactName = n end; break end
              end
            end
          end
        end
        if not contactName then return end
        if _lastOutTime[contactName] == evTime then return end
        _lastOutTime[contactName] = evTime
        local cf = FindWhisperFrame(contactName)
        if not cf then local ucf = FindUntaggedTempFrame(); if ucf then TagWhisperFrame(ucf, contactName) end end
        if not _liveContacts[contactName] then _liveContacts[contactName] = { messages = {}, lastSeen = time() } end
        _liveContacts[contactName].lastSeen = time()
        _liveContacts[contactName]._isBN = isBN
        local msgText = SafeString(msg)
        if msgText then
          local timestamp = date("%H:%M")
          local mr, mg, mb = isBN and 0.0 or 1.0, isBN and 1.0 or 0.5, isBN and 0.965 or 1.0
          local colorHex = format("%02x%02x%02x", mr * 255, mg * 255, mb * 255)
          local shortTarget = contactName:match("^([^%-]+)") or contactName
          local formatted
          if isBN then formatted = "|cff" .. colorHex .. timestamp .. " A [" .. shortTarget .. "] : " .. msgText .. "|r"
          else formatted = "|cff" .. colorHex .. "[" .. timestamp .. "] A " .. shortTarget .. " : " .. msgText .. "|r" end
          SaveWhisperMessage(contactName, formatted, mr, mg, mb)
        end
      end)
    end)
    return false
  end

  for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do
    ChatFrame_AddMessageEventFilter(ev, IncomingFilter)
  end
  for _, ev in ipairs({ "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM" }) do
    ChatFrame_AddMessageEventFilter(ev, OutgoingFilter)
  end
end

local function InitWhisperHistory()
  local charDB = BravLib.Storage.GetCharDB()
  if not charDB then return end
  charDB.whisperHistory = charDB.whisperHistory or { enabled = true, maxAgeDays = 30, maxContacts = 50, maxMessages = 100, contacts = {} }
  local wh = charDB.whisperHistory
  if wh.enabled == false then return end
  wh.contacts = wh.contacts or {}
  for name, data in pairs(wh.contacts) do
    _liveContacts[name] = { messages = data.messages or {}, lastSeen = data.lastSeen or 0, _tabOpen = data._tabOpen, _isBN = data._isBN }
  end
  PurgeContacts(_liveContacts, wh.maxAgeDays, wh.maxContacts)
  wh.contacts = {}
  for name, data in pairs(_liveContacts) do wh.contacts[name] = data end
  C_Timer.After(0.5, function()
    RestoreWhisperTabs()
    if Chat.panel then
      if type(CHAT_FRAMES) == "table" then
        for _, frameName in ipairs(CHAT_FRAMES) do
          local cf = _G[frameName]
          if cf and cf.isTemporary then SkinTemporary(cf, Chat.panel, GetDB()) end
        end
      end
      LayoutTabs(Chat.panel, GetDB())
    end
    InstallWhisperHooks()
  end)
  SLASH_BRAVCHAT1 = "/bravchat"
  SlashCmdList.BRAVCHAT = function() Chat:ToggleHistoryFrame() end
end

-- ============================================================================
-- /BRAVCHAT HISTORY VIEWER
-- ============================================================================

local historyFrame

function Chat:ToggleHistoryFrame()
  if historyFrame and historyFrame:IsShown() then historyFrame:Hide(); return end
  if not historyFrame then self:CreateHistoryFrame() end
  self:RefreshHistoryFrame()
  historyFrame:Show()
end

function Chat:CreateHistoryFrame()
  local FONT_PATH = GetFont()
  local CONTACT_W = 140
  local cr, cg, cb = GetClassColor()

  local function AddBorder(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BORDER"); t:SetTexture(TEX); t:SetVertexColor(r, g, b, a or 1)
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    local b2 = frame:CreateTexture(nil, "BORDER"); b2:SetTexture(TEX); b2:SetVertexColor(r, g, b, a or 1)
    b2:SetPoint("BOTTOMLEFT"); b2:SetPoint("BOTTOMRIGHT"); b2:SetHeight(1)
    local l = frame:CreateTexture(nil, "BORDER"); l:SetTexture(TEX); l:SetVertexColor(r, g, b, a or 1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    local r2 = frame:CreateTexture(nil, "BORDER"); r2:SetTexture(TEX); r2:SetVertexColor(r, g, b, a or 1)
    r2:SetPoint("TOPRIGHT"); r2:SetPoint("BOTTOMRIGHT"); r2:SetWidth(1)
  end

  local function MakeScrollFrame(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self2, delta)
      local cur = self2:GetVerticalScroll()
      local maxVal = math.max(child:GetHeight() - self2:GetHeight(), 0)
      self2:SetVerticalScroll(math.min(math.max(cur - delta * 24, 0), maxVal))
    end)
    return sf, child
  end

  local f = CreateFrame("Frame", "BravUI_WhisperHistory", UIParent)
  f:SetSize(600, 420); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(TEX); bg:SetVertexColor(0.05, 0.05, 0.05, 0.95); bg:SetAllPoints()
  AddBorder(f, cr, cg, cb, 1)

  -- Title
  local titleBar = CreateFrame("Frame", nil, f); titleBar:SetHeight(28)
  titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  local titleBg = titleBar:CreateTexture(nil, "BACKGROUND", nil, 1); titleBg:SetTexture(TEX); titleBg:SetVertexColor(0.1, 0.1, 0.1, 0.95); titleBg:SetAllPoints()
  local titleText = titleBar:CreateFontString(nil, "OVERLAY")
  pcall(function() titleText:SetFont(FONT_PATH, 13, "OUTLINE") end)
  titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0); titleText:SetText("Historique MP"); titleText:SetTextColor(cr, cg, cb, 1)
  local closeBtn = CreateFrame("Button", nil, titleBar); closeBtn:SetSize(20, 20); closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
  local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
  pcall(function() closeTxt:SetFont(FONT_PATH, 14, "OUTLINE") end)
  closeTxt:SetPoint("CENTER"); closeTxt:SetText("X"); closeTxt:SetTextColor(1, 1, 1, 1)
  closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.3, 0.3, 1) end)
  closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(1, 1, 1, 1) end)
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  local titleSep = f:CreateTexture(nil, "ARTWORK"); titleSep:SetTexture(TEX); titleSep:SetVertexColor(cr, cg, cb, 0.5); titleSep:SetHeight(1)
  titleSep:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT"); titleSep:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT")

  -- Contact list
  local contactPanel = CreateFrame("Frame", nil, f); contactPanel:SetWidth(CONTACT_W)
  contactPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1); contactPanel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 31)
  local contactBg = contactPanel:CreateTexture(nil, "BACKGROUND", nil, 1); contactBg:SetTexture(TEX); contactBg:SetVertexColor(0.08, 0.08, 0.08, 0.95); contactBg:SetAllPoints()
  local contactScroll, contactContent = MakeScrollFrame(contactPanel)
  contactScroll:SetPoint("TOPLEFT"); contactScroll:SetPoint("BOTTOMRIGHT"); contactContent:SetWidth(CONTACT_W)
  f._contactContent = contactContent
  local vSep = f:CreateTexture(nil, "ARTWORK"); vSep:SetTexture(TEX); vSep:SetVertexColor(cr, cg, cb, 0.4); vSep:SetWidth(1)
  vSep:SetPoint("TOPLEFT", contactPanel, "TOPRIGHT"); vSep:SetPoint("BOTTOMLEFT", contactPanel, "BOTTOMRIGHT")

  -- Message area
  local msgScroll, msgContent = MakeScrollFrame(f)
  msgScroll:SetPoint("TOPLEFT", contactPanel, "TOPRIGHT", 2, -4); msgScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 31)
  msgContent:SetWidth(600 - CONTACT_W - 10)
  f._msgArea = msgScroll; f._msgContent = msgContent

  -- Bottom bar
  local botBar = CreateFrame("Frame", nil, f); botBar:SetHeight(30)
  botBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1); botBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  local botBg = botBar:CreateTexture(nil, "BACKGROUND", nil, 1); botBg:SetTexture(TEX); botBg:SetVertexColor(0.08, 0.08, 0.08, 0.95); botBg:SetAllPoints()
  local botSep = f:CreateTexture(nil, "ARTWORK"); botSep:SetTexture(TEX); botSep:SetVertexColor(cr, cg, cb, 0.3); botSep:SetHeight(1)
  botSep:SetPoint("BOTTOMLEFT", botBar, "TOPLEFT"); botSep:SetPoint("BOTTOMRIGHT", botBar, "TOPRIGHT")

  local function MakeActionBtn(parent, label, anchorPoint, xOff, onClick)
    local btn = CreateFrame("Button", nil, parent); btn:SetSize(140, 22); btn:SetPoint(anchorPoint, parent, anchorPoint, xOff, 0)
    local btnBg2 = btn:CreateTexture(nil, "BACKGROUND"); btnBg2:SetTexture(TEX); btnBg2:SetVertexColor(0.15, 0.15, 0.15, 0.9); btnBg2:SetAllPoints()
    local btnTxt = btn:CreateFontString(nil, "OVERLAY")
    pcall(function() btnTxt:SetFont(FONT_PATH, 11, "OUTLINE") end)
    btnTxt:SetPoint("CENTER"); btnTxt:SetText(label); btnTxt:SetTextColor(1, 1, 1, 1)
    btn:SetScript("OnEnter", function() btnTxt:SetTextColor(1, 1, 0, 1) end)
    btn:SetScript("OnLeave", function() btnTxt:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnClick", onClick)
    return btn
  end

  MakeActionBtn(botBar, "Supprimer", "LEFT", 6, function()
    if not f._selectedContact then return end
    _liveContacts[f._selectedContact] = nil
    pcall(function()
      local charDB = BravLib.Storage.GetCharDB()
      if charDB and charDB.whisperHistory and charDB.whisperHistory.contacts then
        charDB.whisperHistory.contacts[f._selectedContact] = nil
      end
    end)
    f._selectedContact = nil
    Chat:RefreshHistoryFrame()
  end)

  MakeActionBtn(botBar, "Ouvrir MP", "RIGHT", -6, function()
    if not f._selectedContact then return end
    local name = f._selectedContact
    local data = _liveContacts[name]
    if not FindWhisperFrame(name) then
      local chatType = (data and data._isBN) and "BN_WHISPER" or "WHISPER"
      FCF_OpenTemporaryWindow(chatType, name)
      C_Timer.After(0.05, function()
        local cf = FindUntaggedTempFrame()
        if cf then TagWhisperFrame(cf, name) end
      end)
    end
    C_Timer.After(0.1, function()
      local cf = FindWhisperFrame(name)
      if cf and data and data.messages then
        Chat._bravReplaying = true
        for _, msg in ipairs(data.messages) do
          if msg.text and type(msg.text) == "string" then cf:AddMessage(msg.text, msg.r or 1, msg.g or 1, msg.b or 1) end
        end
        Chat._bravReplaying = false
      end
    end)
    f:Hide()
  end)

  f:Hide()
  historyFrame = f
end

function Chat:RefreshHistoryFrame()
  if not historyFrame then return end
  local FONT_PATH = GetFont()
  local cr, cg, cb = GetClassColor()
  local contactContent = historyFrame._contactContent
  if contactContent._buttons then
    for _, btn in ipairs(contactContent._buttons) do btn:Hide(); btn:SetParent(nil) end
  end
  contactContent._buttons = {}
  local sorted = {}
  for name, data in pairs(_liveContacts) do sorted[#sorted + 1] = { name = name, data = data } end
  table.sort(sorted, function(a, b) return (a.data.lastSeen or 0) > (b.data.lastSeen or 0) end)
  if not historyFrame._selectedContact and #sorted > 0 then historyFrame._selectedContact = sorted[1].name end
  local y = 0
  for _, entry in ipairs(sorted) do
    local name = entry.name
    local msgCount = entry.data.messages and #entry.data.messages or 0
    local btn = CreateFrame("Button", nil, contactContent); btn:SetHeight(24)
    btn:SetPoint("TOPLEFT", contactContent, "TOPLEFT", 0, -y); btn:SetPoint("TOPRIGHT", contactContent, "TOPRIGHT", 0, -y)
    local isSelected = (historyFrame._selectedContact == name)
    local bg2 = btn:CreateTexture(nil, "BACKGROUND"); bg2:SetTexture(TEX); bg2:SetAllPoints()
    bg2:SetVertexColor(isSelected and cr or 0, isSelected and cg or 0, isSelected and cb or 0, isSelected and 0.2 or 0)
    if isSelected then
      local accent = btn:CreateTexture(nil, "ARTWORK"); accent:SetTexture(TEX); accent:SetVertexColor(cr, cg, cb, 1); accent:SetWidth(2)
      accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT")
    end
    local btnTxt = btn:CreateFontString(nil, "OVERLAY")
    pcall(function() btnTxt:SetFont(FONT_PATH, 11, "OUTLINE") end)
    btnTxt:SetPoint("LEFT", btn, "LEFT", 8, 0); btnTxt:SetJustifyH("LEFT")
    local shortName = name:match("^([^%-]+)") or name
    btnTxt:SetText(shortName .. "  |cff888888(" .. msgCount .. ")|r")
    btnTxt:SetTextColor(isSelected and cr or 0.8, isSelected and cg or 0.8, isSelected and cb or 0.8, 1)
    btn:SetScript("OnEnter", function()
      if historyFrame._selectedContact ~= name then bg2:SetVertexColor(0.2, 0.2, 0.2, 0.5); btnTxt:SetTextColor(1, 1, 1, 1) end
    end)
    btn:SetScript("OnLeave", function()
      if historyFrame._selectedContact ~= name then bg2:SetVertexColor(0, 0, 0, 0); btnTxt:SetTextColor(0.8, 0.8, 0.8, 1) end
    end)
    btn:SetScript("OnClick", function() historyFrame._selectedContact = name; Chat:RefreshHistoryFrame() end)
    contactContent._buttons[#contactContent._buttons + 1] = btn
    y = y + 24
  end
  contactContent:SetHeight(math.max(y, 1))
  self:RefreshHistoryMessages()
end

function Chat:RefreshHistoryMessages()
  if not historyFrame then return end
  local contactName = historyFrame._selectedContact
  if not contactName then return end
  local data = _liveContacts[contactName]
  local FONT_PATH = GetFont()
  local msgContent = historyFrame._msgContent
  if msgContent._lines then
    for _, fs in ipairs(msgContent._lines) do fs:Hide(); fs:SetParent(nil) end
  end
  msgContent._lines = {}
  if not data or not data.messages or #data.messages == 0 then
    local empty = msgContent:CreateFontString(nil, "OVERLAY")
    pcall(function() empty:SetFont(FONT_PATH, 11, "") end)
    empty:SetPoint("TOPLEFT", msgContent, "TOPLEFT", 5, -5)
    empty:SetText("Aucun message sauvegard\195\169.")
    empty:SetTextColor(0.5, 0.5, 0.5, 1)
    msgContent._lines[1] = empty; msgContent:SetHeight(30)
    return
  end
  local y = -5
  local contentWidth = historyFrame._msgArea:GetWidth() - 20
  for _, msg in ipairs(data.messages) do
    local fs = msgContent:CreateFontString(nil, "OVERLAY")
    pcall(function() fs:SetFont(FONT_PATH, 11, "") end)
    fs:SetPoint("TOPLEFT", msgContent, "TOPLEFT", 5, y)
    fs:SetWidth(contentWidth); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
    fs:SetText(msg.text or ""); fs:SetTextColor(msg.r or 1, msg.g or 1, msg.b or 1, 1)
    msgContent._lines[#msgContent._lines + 1] = fs
    y = y - (fs:GetStringHeight() or 14) - 2
  end
  msgContent:SetHeight(math.abs(y) + 10)
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function Chat:Enable()
  local db = GetDB()
  if db.enabled == false then
    -- InfoBar standalone only
    C_Timer.After(1, function()
      CreateInfoBarStandalone()
      RefreshLoadoutName()
      UpdateInfoBar()
      self:SetupInfoBarEvents()
    end)
    return
  end

  -- Immediately hide all Blizzard chat visuals to avoid flash
  for i = 1, NUM_WINDOWS do
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab then
      if tab.Left then tab.Left:SetAlpha(0) end
      if tab.Middle then tab.Middle:SetAlpha(0) end
      if tab.Right then tab.Right:SetAlpha(0) end
    end
    local cf = _G["ChatFrame" .. i]
    if cf then StripTextures(cf); if cf.SetBackdrop then pcall(cf.SetBackdrop, cf, nil) end end
    local bg = _G["ChatFrame" .. i .. "Background"]
    if bg then bg:SetAlpha(0) end
    local btnFrame = _G["ChatFrame" .. i .. "ButtonFrame"]
    if btnFrame then btnFrame:SetAlpha(0) end
    local tabGlow = _G["ChatFrame" .. i .. "TabGlow"]
    if tabGlow then tabGlow:SetAlpha(0) end
  end
  local menuBtn = _G.ChatFrameMenuButton
  if menuBtn then menuBtn:Hide(); menuBtn:SetAlpha(0) end
  local qjBtn = _G.QuickJoinToastButton
  if qjBtn then qjBtn:Hide(); qjBtn:SetAlpha(0) end

  -- Defer full setup to let chat frames finish loading
  C_Timer.After(0.5, function() self:Setup() end)
end

function Chat:SetupInfoBarEvents()
  -- FPS/MS ticker
  C_Timer.NewTicker(1, function()
    if perfText then
      local ibDb = GetIBDb()
      perfText:SetText(ibDb.showPerf ~= false and GetPerfText() or "")
    end
  end)

  -- Loadout tracking
  if C_ClassTalents and C_ClassTalents.LoadConfig then
    hooksecurefunc(C_ClassTalents, "LoadConfig", function(configID)
      if configID and C_Traits and C_Traits.GetConfigInfo then
        local ok, info = pcall(C_Traits.GetConfigInfo, configID)
        if ok and info and type(info.name) == "string" and info.name ~= "" then
          cachedLoadoutName = info.name
          C_Timer.After(0.5, UpdateInfoBar)
        end
      end
    end)
  end

  BravLib.Event.Register("PLAYER_MONEY", function() UpdateInfoBar() end)
  BravLib.Event.Register("UPDATE_INVENTORY_DURABILITY", function() UpdateInfoBar() end)
  BravLib.Event.Register("PLAYER_SPECIALIZATION_CHANGED", function()
    C_Timer.After(0.3, function() RefreshLoadoutName(); UpdateInfoBar() end)
  end)
  BravLib.Event.Register("TRAIT_CONFIG_UPDATED", function()
    C_Timer.After(0.5, function() RefreshLoadoutName(); UpdateInfoBar() end)
  end)
  BravLib.Event.Register("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0.5, UpdateInfoBar) end)
  BravLib.Event.Register("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(2, function() RefreshLoadoutName(); UpdateInfoBar() end)
  end)
end

function Chat:Setup()
  if self._setup then return end
  self._setup = true

  local db = GetDB()
  self.panel = CreatePanel(db)

  -- Skin all chat frames
  for i = 1, NUM_WINDOWS do
    local cf = _G["ChatFrame" .. i]
    if cf then SkinChatFrame(cf, i, self.panel, db) end
  end

  -- Position panel
  local pos = BravLib.API.Get("positions", "Panneau Chat")
  self.panel:ClearAllPoints()
  if pos and pos.x and pos.y then
    self.panel:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
  else
    self.panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  end

  -- Size panel + cf1
  local cf1 = _G.ChatFrame1
  if cf1 then WrapChatFrame(cf1, self.panel, db) end

  -- Skin tabs
  for i = 1, NUM_WINDOWS do
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab then SkinTab(tab, self.panel, db) end
  end

  -- Skin editboxes
  for i = 1, NUM_WINDOWS do
    local eb = _G["ChatFrame" .. i .. "EditBox"]
    local cf = _G["ChatFrame" .. i]
    if eb and cf then SkinEditBox(eb, cf, self.panel, db) end
  end

  LayoutDock(self.panel, db)
  LayoutTabs(self.panel, db)
  SetupFade(self.panel, db)

  -- Bind InfoBar to panel zone
  if self.panel._infoBar then
    BindInfoBar(self.panel._infoBar)
    self.panel._infoBar:Show()
  end

  -- Register mover
  BravUI.Move.Enable(self.panel, "Panneau Chat")

  -- Hide Blizzard UI elements
  local menuBtn = _G.ChatFrameMenuButton
  if menuBtn then menuBtn:Hide(); menuBtn:SetAlpha(0) end
  local qjBtn = _G.QuickJoinToastButton
  if qjBtn then
    qjBtn:Hide(); qjBtn:SetAlpha(0)
    hooksecurefunc(qjBtn, "Show", function(self2) self2:Hide() end)
  end
  local qjToast = _G.QuickJoinToastButton and _G.QuickJoinToastButton.Toast
  if qjToast then qjToast:Hide(); qjToast:SetAlpha(0) end

  -- Anchor cf1 inside panel
  if cf1 then
    cf1:SetClampRectInsets(0, 0, 0, 0)
    cf1:SetClampedToScreen(false)
    cf1:SetMovable(true)
    cf1:SetUserPlaced(true)
    local realSetPoint = cf1.SetPointBase or cf1.SetPoint
    local realClearAll = cf1.ClearAllPointsBase or cf1.ClearAllPoints
    local function ForcePosition()
      if not self.panel then return end
      realClearAll(cf1)
      local tabZone = (db.tabHeight or 15) + 3
      realSetPoint(cf1, "TOPLEFT", self.panel, "TOPLEFT", INSET, -tabZone)
      cf1:SetSize((db.panelWidth or 450) - INSET * 2, (db.panelHeight or 220) - tabZone - GetInfoBarH())
    end
    cf1.SetPoint = function() ForcePosition() end
    cf1.ClearAllPoints = function(self2, ...) realClearAll(self2) end
    ForcePosition()
    C_Timer.After(0, ForcePosition)
    C_Timer.After(1, ForcePosition)
  end

  self:InstallHooks()

  -- Delayed tab refresh
  local function DelayedTabRefresh()
    for i = 1, NUM_WINDOWS do
      local tab = _G["ChatFrame" .. i .. "Tab"]
      if tab and tab:IsShown() then
        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if text then
          text:SetFont(GetFont(), db.tabFontSize or 12, "")
          text:SetWidth(0)
          local textW = text:GetStringWidth()
          if textW and textW >= 10 then tab:SetWidth(textW + 16) end
        end
      end
    end
    LayoutTabs(self.panel, db)
  end
  C_Timer.After(0.1, DelayedTabRefresh)
  C_Timer.After(0.5, DelayedTabRefresh)

  -- Whisper history
  InitWhisperHistory()

  -- InfoBar events
  self:SetupInfoBarEvents()

  -- Hook cf1 size changes
  if cf1 and not cf1._bravSizeHooked then
    cf1._bravSizeHooked = true
    cf1:HookScript("OnSizeChanged", function()
      if not self.panel then return end
      C_Timer.After(0, function()
        WrapChatFrame(cf1, self.panel, db)
        LayoutTabs(self.panel, db)
        LayoutDock(self.panel, db)
        if self.panel._infoBar then LayoutInfoBarSections(self.panel._infoBar, db.panelWidth or 450) end
      end)
    end)
  end
end

-- ============================================================================
-- HOOKS
-- ============================================================================

function Chat:InstallHooks()
  if self._hooksInstalled then return end
  self._hooksInstalled = true
  local db = GetDB()
  local panel = self.panel

  local function ReskinAll()
    pcall(StripAllChatFrames, db)
    pcall(LayoutDock, panel, db)
    pcall(function()
      for i = 1, NUM_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then SkinTab(tab, panel, db) end
      end
    end)
    pcall(LayoutTabs, panel, db)
  end

  if _G.FCF_DockUpdateTabs then
    hooksecurefunc("FCF_DockUpdateTabs", function()
      pcall(StripAllChatFrames, db)
      pcall(LayoutDock, panel, db)
      pcall(RefreshAllTabs)
      pcall(LayoutTabs, panel, db)
    end)
  end

  if _G.FCF_OpenTemporaryWindow then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      C_Timer.After(0, function()
        pcall(function()
          if type(CHAT_FRAMES) == "table" then
            for _, frameName in ipairs(CHAT_FRAMES) do
              local cf = _G[frameName]
              if cf and cf.isTemporary then cf._bravClosed = nil; SkinTemporary(cf, panel, db) end
            end
          end
        end)
        pcall(LayoutTabs, panel, db)
      end)
    end)
  end

  if _G.FCF_DockUpdate then
    hooksecurefunc("FCF_DockUpdate", function()
      pcall(StripAllChatFrames, db)
      pcall(LayoutDock, panel, db)
      pcall(RefreshAllTabs)
      pcall(function()
        if type(CHAT_FRAMES) == "table" then
          for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary then SkinTemporary(cf, panel, db) end
          end
        end
      end)
      pcall(LayoutTabs, panel, db)
    end)
  end

  BravLib.Event.Register("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(0.1, function()
      pcall(ReskinAll)
      pcall(function()
        if type(CHAT_FRAMES) == "table" then
          for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary then SkinTemporary(cf, panel, db) end
          end
        end
      end)
      pcall(LayoutTabs, panel, db)
    end)
  end)

  if _G.FCF_Close then
    hooksecurefunc("FCF_Close", function(chatFrame)
      if chatFrame then
        local cfName = chatFrame:GetName()
        if cfName then
          local idx = cfName:match("ChatFrame(%d+)")
          if idx then StopFlashTab(tonumber(idx)) end
        end
        chatFrame._bravClosed = true
        if chatFrame.isTemporary then
          local contactName = chatFrame._bravContactName
          if not contactName then
            local tab = cfName and _G[cfName .. "Tab"]
            if tab then
              local txt = tab.Text or _G[cfName .. "TabText"]
              if txt and txt.GetText then
                local ok, raw = pcall(txt.GetText, txt)
                if ok and raw and not IsSecret(raw) and type(raw) == "string" and raw ~= "" then contactName = raw end
              end
            end
          end
          if contactName and _liveContacts[contactName] then
            _liveContacts[contactName]._tabOpen = false
            pcall(function()
              local charDB = BravLib.Storage.GetCharDB()
              if charDB and charDB.whisperHistory and charDB.whisperHistory.contacts and charDB.whisperHistory.contacts[contactName] then
                charDB.whisperHistory.contacts[contactName]._tabOpen = false
              end
            end)
          end
        end
      end
      C_Timer.After(0, function() ReskinAll(); pcall(LayoutTabs, panel, db) end)
    end)
  end

  if _G.FCF_Tab_OnClick then
    hooksecurefunc("FCF_Tab_OnClick", function(chatFrame)
      RefreshAllTabs()
      if chatFrame then
        local cfName = chatFrame:GetName()
        if cfName then
          local idx = cfName:match("ChatFrame(%d+)")
          if idx then StopFlashTab(tonumber(idx)) end
        end
      end
    end)
  end

  if _G.FCF_SelectDockFrame then
    hooksecurefunc("FCF_SelectDockFrame", function(chatFrame)
      if chatFrame and chatFrame.isTemporary then _priorityFrame = chatFrame end
      RefreshAllTabs()
      if chatFrame then
        local cfName = chatFrame:GetName()
        if cfName then
          local idx = cfName:match("ChatFrame(%d+)")
          if idx then StopFlashTab(tonumber(idx)) end
        end
      end
    end)
  end

  -- Flash on whispers
  local FLASH_EVENTS = { CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER" }

  local function FlashWhisperTabForContact(contactName, colorKey)
    local colors = CHANNEL_COLORS[colorKey]
    if not colors then return end
    local visibleFrame = SELECTED_CHAT_FRAME or _G.ChatFrame1
    local allFrames = CHAT_FRAMES or {}
    for _, frameName in ipairs(allFrames) do
      local cf = _G[frameName]
      if cf and cf ~= visibleFrame then
        local idx = frameName:match("ChatFrame(%d+)")
        if idx then
          idx = tonumber(idx)
          if cf.isTemporary then
            if cf._bravContactName == contactName then FlashTab(idx, colors[1], colors[2], colors[3]) end
          else
            local msgs = { GetChatWindowMessages(idx) }
            for _, msgType in ipairs(msgs) do
              if msgType == colorKey then FlashTab(idx, colors[1], colors[2], colors[3]); break end
            end
          end
        end
      end
    end
  end
  Chat._flashWhisperTabForContact = FlashWhisperTabForContact

  for event, colorKey in pairs(FLASH_EVENTS) do
    BravLib.Event.Register(event, function()
      C_Timer.After(0.1, function()
        local visibleFrame = SELECTED_CHAT_FRAME or _G.ChatFrame1
        local colors = CHANNEL_COLORS[colorKey]
        if not colors then return end
        for _, frameName in ipairs(CHAT_FRAMES or {}) do
          local cf = _G[frameName]
          if cf and cf ~= visibleFrame and not cf.isTemporary then
            local idx = frameName:match("ChatFrame(%d+)")
            if idx then
              idx = tonumber(idx)
              local msgs = { GetChatWindowMessages(idx) }
              for _, msgType in ipairs(msgs) do
                if msgType == colorKey then FlashTab(idx, colors[1], colors[2], colors[3]); break end
              end
            end
          end
        end
      end)
    end)
  end
end

-- ============================================================================
-- APPLY LAYOUT
-- ============================================================================

function Chat:ApplyLayout()
  if not self.panel then return end
  local db = GetDB()
  local cf1 = _G.ChatFrame1
  if cf1 then WrapChatFrame(cf1, self.panel, db) end
  if self.panel._bg then self.panel._bg:SetVertexColor(0, 0, 0, db.opacity) end
  if self.panel._tabBg then self.panel._tabBg:SetVertexColor(0, 0, 0, db.tabOpacity or 0.85) end

  -- InfoBar
  if self.panel._infoBar then
    BindInfoBar(self.panel._infoBar)
    LayoutInfoBarSections(self.panel._infoBar, db.panelWidth or 450)
    RefreshInfoBarStyle(self.panel._infoBar, db.panelWidth or 450)
  end

  -- Re-anchor cf1
  if cf1 then
    local realSetPoint = cf1.SetPointBase or cf1.SetPoint
    local realClearAll = cf1.ClearAllPointsBase or cf1.ClearAllPoints
    local tabZone = (db.tabHeight or 15) + 3
    realClearAll(cf1)
    realSetPoint(cf1, "TOPLEFT", self.panel, "TOPLEFT", INSET, -tabZone)
    cf1:SetSize((db.panelWidth or 450) - INSET * 2, (db.panelHeight or 220) - tabZone - GetInfoBarH())
  end

  RefreshAllTabs()
end

-- ============================================================================
-- REFRESH (called by APPLY_CHAT hook)
-- ============================================================================

function Chat:Refresh()
  local db = GetDB()
  if db.enabled == false then
    UnbindInfoBar()
    return
  end
  if not self._setup then self:Setup(); return end
  self:ApplyLayout()
  if self.panel then
    LayoutTabs(self.panel, db)
    RefreshColors(self.panel)
    RefreshFonts(self.panel, db)
  end
end

function Chat:RefreshInfoBar()
  local ibDb = GetIBDb()
  local fp = GetFont()
  local fs = ibDb.fontSize or 11
  if specText then pcall(specText.SetFont, specText, fp, fs, "OUTLINE") end
  if goldText then pcall(goldText.SetFont, goldText, fp, fs, "OUTLINE") end
  if durabilityText then pcall(durabilityText.SetFont, durabilityText, fp, fs, "OUTLINE") end
  if perfText then pcall(perfText.SetFont, perfText, fp, fs, "OUTLINE") end

  if _boundZone then
    UpdateInfoBar()
  elseif infoBarFrame then
    infoBarFrame:SetHeight(ibDb.height or 22)
    if infoBarFrame._bg then infoBarFrame._bg:SetVertexColor(0, 0, 0, ibDb.opacity or 0.75) end
    local r, g, b = GetClassColor()
    if infoBarFrame._sep1 then infoBarFrame._sep1:SetVertexColor(r, g, b, 0.5) end
    if infoBarFrame._sep2 then infoBarFrame._sep2:SetVertexColor(r, g, b, 0.5) end
    if infoBarFrame._sep3 then infoBarFrame._sep3:SetVertexColor(r, g, b, 0.5) end
    UpdateInfoBar()
  else
    CreateInfoBarStandalone()
    UpdateInfoBar()
  end
end

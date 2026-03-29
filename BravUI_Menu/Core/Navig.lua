-- BravUI_Menu/Core/Navig.lua
-- Fenêtre principale, navigation sidebar, zone de contenu

local M = BravUI.Menu
local T = M.Theme

-- ============================================================================
-- NAV BUTTON SetActive (lit les couleurs dynamiquement)
-- ============================================================================

local function NavBtnSetActive(self, active)
  local cr, cg, cb = M:GetClassColor()
  self._isActive = active
  if active then
    self._accent:Show()
    self._accent:SetColorTexture(cr, cg, cb, 1)
    self._label:SetTextColor(cr, cg, cb, 1)
    self:SetBackdropColor(cr * 0.12, cg * 0.12, cb * 0.12, 0.80)
    self:SetBackdropBorderColor(cr, cg, cb, 0.35)
  else
    self._accent:Hide()
    self._label:SetTextColor(0.78, 0.78, 0.80, 1)
    self:SetBackdropColor(0.08, 0.08, 0.10, 0.60)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end
end

-- ============================================================================
-- FOOTER BUTTON
-- ============================================================================

local function CreateFooterButton(parent, text, style)
  local isPrimary = (style == "primary")
  local isDanger  = (style == "danger")

  local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  btn:SetSize(100, 28)
  btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  btn:SetBackdropBorderColor(unpack(T.BORDER))
  btn._style = style

  local label = btn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  btn._label = label

  if isPrimary then
    local function ApplyPrimaryColors(b)
      local cr, cg, cb = M:GetClassColor()
      b:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
      b._label:SetTextColor(cr, cg, cb, 1)
    end
    ApplyPrimaryColors(btn)

    btn:SetScript("OnEnter", function(self)
      local cr, cg, cb = M:GetClassColor()
      self:SetBackdropColor(cr * 0.25, cg * 0.25, cb * 0.25, 1)
      self:SetBackdropBorderColor(cr, cg, cb, 0.50)
    end)
    btn:SetScript("OnLeave", function(self)
      local cr, cg, cb = M:GetClassColor()
      self:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
      self:SetBackdropBorderColor(unpack(T.BORDER))
    end)
    btn._applyColors = ApplyPrimaryColors

  elseif isDanger then
    btn:SetBackdropColor(0.25, 0.05, 0.05, 0.90)
    label:SetTextColor(0.90, 0.30, 0.30, 1)

    btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(0.40, 0.08, 0.08, 1)
      self:SetBackdropBorderColor(0.90, 0.30, 0.30, 0.50)
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(0.25, 0.05, 0.05, 0.90)
      self:SetBackdropBorderColor(unpack(T.BORDER))
    end)

  else
    btn:SetBackdropColor(unpack(T.BTN))
    label:SetTextColor(unpack(T.TEXT))

    btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(unpack(T.BTN_HOVER))
      self:SetBackdropBorderColor(1, 1, 1, 0.20)
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(unpack(T.BTN))
      self:SetBackdropBorderColor(unpack(T.BORDER))
    end)
  end

  return btn
end

-- ============================================================================
-- MAIN FRAME
-- ============================================================================

function M:CreateMainFrame()
  if self.Frame then return self.Frame end

  local cr, cg, cb = self:GetClassColor()

  local f = CreateFrame("Frame", "BravUI_MenuFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(T.W, T.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")

  f:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  f:SetBackdropColor(unpack(T.BG))
  f:SetBackdropBorderColor(cr, cg, cb, 0.40)

  -- ── HEADER ──
  local header = CreateFrame("Frame", nil, f)
  header:SetHeight(T.HEADER_H)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

  local dragZone = CreateFrame("Frame", nil, f)
  dragZone:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
  dragZone:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -275, 0)
  dragZone:EnableMouse(true)
  dragZone:RegisterForDrag("LeftButton")
  dragZone:SetFrameLevel(header:GetFrameLevel() + 10)
  local _dragging = false
  dragZone:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    _dragging = true
    f:StartMoving()
  end)
  dragZone:SetScript("OnDragStop", function()
    _dragging = false
    f:StopMovingOrSizing()
  end)
  dragZone:SetScript("OnMouseUp", function()
    if _dragging then
      _dragging = false
      f:StopMovingOrSizing()
    end
  end)
  f:SetScript("OnHide", function()
    if _dragging then
      _dragging = false
      f:StopMovingOrSizing()
    end
  end)

  f._headerLine = M:CreateLine(header, "BOTTOM", { cr, cg, cb, 0.20 })

  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetSize(32, 32)
  logo:SetPoint("LEFT", header, "LEFT", T.PAD + 4, 0)
  logo:SetTexture(T.LOGO_PATH)

  local title = header:CreateFontString(nil, "OVERLAY")
  M:SafeFont(title, 15, "OUTLINE")
  title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  title:SetText("BravUI")
  title:SetTextColor(cr, cg, cb, 1)
  f._title = title

  local version = header:CreateFontString(nil, "OVERLAY")
  M:SafeFont(version, 9, "OUTLINE")
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)
  local ver = "v" .. (C_AddOns.GetAddOnMetadata("BravUI", "Version") or "2.0")
  version:SetText(ver)
  version:SetTextColor(unpack(T.MUTED))
  f._version = version

  local closeBtn = CreateFooterButton(header, "X", "danger")
  closeBtn:SetSize(28, 24)
  closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)
  closeBtn:SetScript("OnClick", function() f:Hide() end)

  -- ── SEARCH BOX ──
  local searchBox = CreateFrame("EditBox", nil, header, BackdropTemplateMixin and "BackdropTemplate" or nil)
  searchBox:SetSize(220, 26)
  searchBox:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
  searchBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  searchBox:SetBackdropColor(unpack(T.PANEL))
  searchBox:SetBackdropBorderColor(unpack(T.BORDER))
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(40)
  searchBox:SetTextInsets(8, 24, 0, 0)
  M:SafeFont(searchBox, 11, "OUTLINE")
  searchBox:SetTextColor(unpack(T.TEXT))
  searchBox:SetFrameLevel(header:GetFrameLevel() + 5)

  local placeholder = searchBox:CreateFontString(nil, "OVERLAY")
  M:SafeFont(placeholder, 11, "OUTLINE")
  placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
  placeholder:SetText((M.L and M.L["search_placeholder"]) or "Rechercher...")
  placeholder:SetTextColor(unpack(T.MUTED))
  searchBox._placeholder = placeholder

  local clearBtn = CreateFrame("Button", nil, searchBox)
  clearBtn:SetSize(14, 14)
  clearBtn:SetPoint("RIGHT", searchBox, "RIGHT", -6, 0)
  clearBtn:Hide()
  local clearLabel = clearBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(clearLabel, 10, "OUTLINE")
  clearLabel:SetPoint("CENTER")
  clearLabel:SetText("x")
  clearLabel:SetTextColor(unpack(T.MUTED))
  clearBtn:SetScript("OnEnter", function() clearLabel:SetTextColor(1, 1, 1, 1) end)
  clearBtn:SetScript("OnLeave", function() clearLabel:SetTextColor(unpack(T.MUTED)) end)
  clearBtn:SetScript("OnClick", function()
    searchBox:SetText("")
    searchBox:ClearFocus()
  end)

  searchBox:SetScript("OnTextChanged", function(self, userInput)
    local text = self:GetText()
    local hasText = text and text ~= ""
    placeholder:SetShown(not hasText)
    clearBtn:SetShown(hasText)

    local norm = M.NormalizeSearch and hasText and M.NormalizeSearch(text) or nil
    if norm == "" then norm = nil end
    M._searchTerm = norm

    if norm then
      for _, btn in ipairs(f._navButtons or {}) do
        local pageMatch = M:PageHasMatches(btn._pageId, norm)
        btn:SetAlpha(pageMatch and 1 or 0.35)
      end
      if not M:PageHasMatches(M._activePage, norm) then
        local target = M:FindFirstMatchingPage(norm)
        if target and target ~= M._activePage then
          f:OpenPage(target, true)
        end
      end
    else
      for _, btn in ipairs(f._navButtons or {}) do
        btn:SetAlpha(1)
      end
    end

    if M._activePage and M._pageRefreshFn then
      pcall(M._pageRefreshFn)
    end
  end)
  searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
  end)
  searchBox:SetScript("OnEditFocusGained", function(self)
    local cr2, cg2, cb2 = M:GetClassColor()
    self:SetBackdropBorderColor(cr2, cg2, cb2, 0.60)
  end)
  searchBox:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)
  f._searchBox = searchBox

  -- ── SIDEBAR ──
  local sidebar = CreateFrame("Frame", nil, f)
  sidebar:SetWidth(T.SIDEBAR_W)
  sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -T.HEADER_H)
  sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, T.FOOTER_H)
  sidebar:SetFrameLevel(f:GetFrameLevel() + 5)
  M:SetBG(sidebar, T.SIDEBAR)
  f._sidebar = sidebar

  local sidebarLine = sidebar:CreateTexture(nil, "ARTWORK")
  sidebarLine:SetWidth(1)
  sidebarLine:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  sidebarLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
  sidebarLine:SetColorTexture(cr, cg, cb, 0.15)
  f._sidebarLine = sidebarLine

  f._navButtons = {}

  -- ── FOOTER ──
  local footer = CreateFrame("Frame", nil, f)
  footer:SetHeight(T.FOOTER_H)
  footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  f._footerLine = M:CreateLine(footer, "TOP", { cr, cg, cb, 0.15 })

  local L = M.L
  local closeFooterBtn = CreateFooterButton(footer, (L and L["frame_close"]) or "Fermer", "danger")
  closeFooterBtn:SetPoint("RIGHT", footer, "RIGHT", -T.PAD, 0)
  closeFooterBtn:SetScript("OnClick", function() f:Hide() end)
  f._closeFooterBtn = closeFooterBtn

  local applyBtn = CreateFooterButton(footer, (L and L["frame_apply"]) or "Appliquer", "primary")
  applyBtn:SetPoint("RIGHT", closeFooterBtn, "LEFT", -8, 0)
  applyBtn:SetScript("OnClick", function()
    BravLib.Hooks.Fire("APPLY_ALL")
  end)
  f._applyBtn = applyBtn

  local editBtn = CreateFooterButton(footer, (L and L["frame_edit"]) or "Editer")
  editBtn:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)
  editBtn:SetScript("OnClick", function()
    f:Hide()
    BravUI.Move.Toggle()
  end)
  f._editBtn = editBtn

  -- ── CONTENT AREA ──
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", T.SIDEBAR_W, -T.HEADER_H)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, T.FOOTER_H)

  local SCROLLBAR_W   = 4
  local SCROLLBAR_PAD = 2

  local scroll = CreateFrame("ScrollFrame", nil, content)
  scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -(SCROLLBAR_W + SCROLLBAR_PAD * 2), 0)

  local scrollChild = CreateFrame("Frame", nil, scroll)
  local initW = T.W - T.SIDEBAR_W - SCROLLBAR_W - SCROLLBAR_PAD * 2
  scrollChild:SetWidth(initW)
  scroll:SetScrollChild(scrollChild)
  f._scrollChild = scrollChild
  f._scroll = scroll

  -- Scrollbar
  local track = CreateFrame("Frame", nil, content)
  track:SetWidth(SCROLLBAR_W)
  track:SetPoint("TOPRIGHT", content, "TOPRIGHT", -SCROLLBAR_PAD, -2)
  track:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -SCROLLBAR_PAD, 2)
  local trackBg = track:CreateTexture(nil, "BACKGROUND")
  trackBg:SetAllPoints()
  trackBg:SetColorTexture(1, 1, 1, 0.03)

  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(SCROLLBAR_W)
  thumb:SetPoint("TOP", track, "TOP", 0, 0)
  thumb:SetHeight(40)
  local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
  thumbTex:SetAllPoints()
  thumbTex:SetColorTexture(cr, cg, cb, 0.25)
  thumb._tex = thumbTex
  f._thumb = thumb

  thumb:EnableMouse(true)
  thumb:SetScript("OnEnter", function(self)
    local r, g, b = M:GetClassColor()
    self._tex:SetColorTexture(r, g, b, 0.50)
  end)
  thumb:SetScript("OnLeave", function(self)
    if not self._dragging then
      local r, g, b = M:GetClassColor()
      self._tex:SetColorTexture(r, g, b, 0.25)
    end
  end)

  local function UpdateThumb()
    local childH = scrollChild:GetHeight() or 1
    local viewH  = scroll:GetHeight() or 1
    if childH <= viewH then thumb:Hide(); return end
    thumb:Show()
    local ratio   = viewH / childH
    local trackH  = track:GetHeight()
    local thumbH  = math.max(20, trackH * ratio)
    thumb:SetHeight(thumbH)
    local scrollMax = childH - viewH
    local scrollVal = scroll:GetVerticalScroll()
    local scrollPct = scrollVal / scrollMax
    local thumbTravel = trackH - thumbH
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -(scrollPct * thumbTravel))
  end

  scroll:SetScript("OnScrollRangeChanged", function()
    local childH    = scrollChild:GetHeight() or 1
    local viewH     = scroll:GetHeight() or 1
    local maxScroll = math.max(0, childH - viewH)
    if scroll:GetVerticalScroll() > maxScroll then
      scroll:SetVerticalScroll(maxScroll)
    end
    UpdateThumb()
  end)
  scroll:SetScript("OnVerticalScroll", function() UpdateThumb() end)

  local function OnMouseWheel(_, delta)
    local step    = 40
    local current = scroll:GetVerticalScroll()
    local childH  = scrollChild:GetHeight() or 1
    local viewH   = scroll:GetHeight() or 1
    local maxScroll = math.max(0, childH - viewH)
    local newVal    = math.max(0, math.min(maxScroll, current - delta * step))
    scroll:SetVerticalScroll(newVal)
  end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", OnMouseWheel)
  scrollChild:EnableMouseWheel(true)
  scrollChild:SetScript("OnMouseWheel", OnMouseWheel)
  content:EnableMouseWheel(true)
  content:SetScript("OnMouseWheel", OnMouseWheel)

  thumb:RegisterForDrag("LeftButton")
  thumb:SetScript("OnDragStart", function(self)
    self._dragging = true
    local r, g, b = M:GetClassColor()
    self._tex:SetColorTexture(r, g, b, 0.65)
    local _, cursorY = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    self._dragStartCursor = cursorY / s
    self._dragStartScroll = scroll:GetVerticalScroll()
  end)
  thumb:SetScript("OnDragStop", function(self)
    self._dragging = false
    local r, g, b = M:GetClassColor()
    self._tex:SetColorTexture(r, g, b, 0.25)
  end)
  thumb:SetScript("OnUpdate", function(self)
    if not self._dragging then return end
    local _, cursorY = GetCursorPosition()
    local s  = UIParent:GetEffectiveScale()
    local dy = self._dragStartCursor - cursorY / s
    local trackH     = track:GetHeight()
    local thumbH     = self:GetHeight()
    local thumbTravel = trackH - thumbH
    if thumbTravel <= 0 then return end
    local childH    = scrollChild:GetHeight() or 1
    local viewH     = scroll:GetHeight() or 1
    local maxScroll = math.max(0, childH - viewH)
    local scrollDelta = (dy / thumbTravel) * maxScroll
    local newVal = math.max(0, math.min(maxScroll, self._dragStartScroll + scrollDelta))
    scroll:SetVerticalScroll(newVal)
  end)

  content:SetScript("OnSizeChanged", function(self, w)
    scrollChild:SetWidth(w - (SCROLLBAR_W + SCROLLBAR_PAD * 2))
    UpdateThumb()
  end)

  f._contentHost = content

  -- ── ESC to close ──
  tinsert(UISpecialFrames, "BravUI_MenuFrame")

  -- ── CACHE INVALIDATION ──
  BravLib.Hooks.Register("PROFILE_CHANGED", function()
    M:InvalidatePageCache()
    local active = M:GetActivePage()
    if active and f:IsShown() and f.OpenPage then
      f:OpenPage(active)
    end
  end)
  BravLib.Hooks.Register("SETTINGS_RESET", function()
    M:InvalidatePageCache()
    local active = M:GetActivePage()
    if active and f:IsShown() and f.OpenPage then
      f:OpenPage(active)
    end
  end)

  -- ── METHODS ──

  function f:RebuildSidebar()
    for _, btn in ipairs(self._navButtons) do btn:Hide() end

    local pages = M:GetOrderedPages()
    local y     = 10
    local PAD_X = 8

    for i, page in ipairs(pages) do
      local btn = self._navButtons[i]

      if not btn then
        btn = CreateFrame("Button", nil, sidebar, BackdropTemplateMixin and "BackdropTemplate" or nil)
        btn:SetSize(T.SIDEBAR_W - PAD_X * 2, 30)
        btn:SetFrameLevel(sidebar:GetFrameLevel() + 2)
        btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
        btn:SetBackdropColor(0.08, 0.08, 0.10, 0.60)
        btn:SetBackdropBorderColor(unpack(T.BORDER))

        local accent = btn:CreateTexture(nil, "OVERLAY")
        accent:SetSize(2, 18)
        accent:SetPoint("LEFT", btn, "LEFT", 4, 0)
        accent:Hide()
        btn._accent = accent

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", btn, "LEFT", 14, 0)
        btn._label = label

        btn._pageId  = page.id
        btn.SetActive = NavBtnSetActive

        btn:SetScript("OnEnter", function(self)
          if not self._isActive then
            self:SetBackdropColor(0.12, 0.12, 0.14, 0.80)
            self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
            self._label:SetTextColor(1, 1, 1, 1)
          end
        end)
        btn:SetScript("OnLeave", function(self)
          self:SetActive(self._isActive)
        end)
        btn:SetScript("OnClick", function(self)
          if M.Frame and M.Frame.OpenPage then
            M.Frame:OpenPage(self._pageId)
          end
        end)

        self._navButtons[i] = btn
      else
        btn._pageId = page.id
      end

      local lbl = (M.L and M.L["page_" .. page.id]) or page.title
      btn._label:SetText(lbl)
      btn:ClearAllPoints()
      btn:SetPoint("TOP", sidebar, "TOP", 0, -y)
      btn:SetActive(page.id == M._activePage)
      btn:Show()

      y = y + 34
    end

    if M.L then
      if self._closeFooterBtn then self._closeFooterBtn._label:SetText(M.L["frame_close"] or "Fermer") end
      if self._applyBtn       then self._applyBtn._label:SetText(M.L["frame_apply"] or "Appliquer") end
      if self._editBtn        then self._editBtn._label:SetText(M.L["frame_edit"] or "Editer") end
    end
  end

  function f:OpenPage(pageId, keepSearch)
    if not pageId then return end

    if M._activePage and M._activePage ~= pageId then
      M:HidePage(M._activePage)
    end

    if not keepSearch then
      if self._searchBox then
        self._searchBox:SetText("")
        self._searchBox:ClearFocus()
      end
      M._searchTerm = nil
      for _, btn in ipairs(self._navButtons or {}) do
        btn:SetAlpha(1)
      end
    end
    M._pageRefreshFn = nil

    M._activePage = pageId

    local pageFrame = M:BuildPageInto(pageId, self._scrollChild)
    if pageFrame then pageFrame:Show() end

    for _, btn in ipairs(self._navButtons) do
      btn:SetActive(btn._pageId == pageId)
    end

    self._scroll:SetVerticalScroll(0)
  end

  function f:RefreshColors()
    local cr, cg, cb = M:GetClassColor()

    self:SetBackdropBorderColor(cr, cg, cb, 0.40)

    if self._headerLine  then self._headerLine:SetColorTexture(cr, cg, cb, 0.20) end
    if self._title       then self._title:SetTextColor(cr, cg, cb, 1) end
    if self._sidebarLine then self._sidebarLine:SetColorTexture(cr, cg, cb, 0.15) end
    if self._footerLine  then self._footerLine:SetColorTexture(cr, cg, cb, 0.15) end

    if self._thumb and self._thumb._tex then
      self._thumb._tex:SetColorTexture(cr, cg, cb, 0.25)
    end
    if self._searchBox and self._searchBox:HasFocus() then
      self._searchBox:SetBackdropBorderColor(cr, cg, cb, 0.60)
    end
    if self._applyBtn and self._applyBtn._applyColors then
      self._applyBtn._applyColors(self._applyBtn)
    end
    for _, btn in ipairs(self._navButtons) do
      btn:SetActive(btn._isActive)
    end

    if M._activePage and not (ColorPickerFrame and ColorPickerFrame:IsShown()) then
      local scrollPos = self._scroll and self._scroll:GetVerticalScroll() or 0
      M:InvalidatePageCache(M._activePage)
      self:OpenPage(M._activePage)
      if self._scroll and scrollPos > 0 then
        self._scroll:SetVerticalScroll(scrollPos)
      end
    end
  end

  f:Hide()
  self.Frame = f
  return f
end

-- ============================================================================
-- TOGGLE
-- ============================================================================

function M:Toggle()
  local f = self:CreateMainFrame()

  if f:IsShown() then
    f:Hide()
    return
  end

  f:ClearAllPoints()
  f:SetPoint("CENTER")
  f:Show()
  f:RebuildSidebar()

  local active = self:GetActivePage()
  if active and self.Pages[active] then
    f:OpenPage(active)
  else
    local pages = self:GetOrderedPages()
    if pages[1] then f:OpenPage(pages[1].id) end
  end

  if not M._allPagesPrebuilt then
    M._allPagesPrebuilt = true
    local savedActive    = M._activePage
    local savedRefreshFn = M._pageRefreshFn
    for _, page in ipairs(self:GetOrderedPages()) do
      if page.id ~= savedActive and not M._pageCache[page.id] then
        M._activePage = page.id
        pcall(M.BuildPageInto, M, page.id, f._scrollChild)
        if M._pageCache[page.id] then M._pageCache[page.id]:Hide() end
      end
    end
    M._activePage    = savedActive
    M._pageRefreshFn = savedRefreshFn
  end
end

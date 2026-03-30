-- BravUI_Menu/Core/Widgets.lua
-- Declarative options engine
-- Pages = data tables, engine renders widgets + auto-layout

local M = BravUI.Menu
local T = M.Theme
local GAP = 8

-- ============================================================================
-- DB HELPERS (dot-path access)
-- ============================================================================

local _pathCache = {}

local function SplitPath(path)
  if _pathCache[path] then return _pathCache[path] end
  local parts = {}
  for seg in path:gmatch("[^%.]+") do
    parts[#parts + 1] = seg
  end
  _pathCache[path] = parts
  return parts
end

local function DBGet(path)
  local db = BravLib.Storage.GetDB()
  if not db then return nil end
  local parts = SplitPath(path)
  local t = db
  for i = 1, #parts do
    if type(t) ~= "table" then return nil end
    t = t[parts[i]]
  end
  return t
end

local function DBSet(path, value)
  local db = BravLib.Storage.GetDB()
  if not db then return end
  local parts = SplitPath(path)
  local t = db
  for i = 1, #parts - 1 do
    if type(t[parts[i]]) ~= "table" then t[parts[i]] = {} end
    t = t[parts[i]]
  end
  t[parts[#parts]] = value
end

-- ============================================================================
-- SHARED FLYOUT (one per menu, reused by all dropdowns)
-- ============================================================================

local function EnsureFlyout()
  if M._flyout then return M._flyout end

  local fly = CreateFrame("Frame", "BravUI_MenuFlyout", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  fly:SetFrameStrata("FULLSCREEN_DIALOG")
  fly:SetFrameLevel(990)
  fly:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  fly:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
  fly:SetBackdropBorderColor(unpack(T.BORDER))
  fly:Hide()
  fly:EnableMouse(true)

  local blocker = CreateFrame("Button", nil, UIParent)
  blocker:SetAllPoints(UIParent)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  blocker:SetFrameLevel(989)
  blocker:Hide()
  blocker:SetScript("OnClick", function() fly:Hide() end)
  fly._blocker = blocker

  fly:SetScript("OnShow", function() blocker:Show() end)
  fly:SetScript("OnHide", function()
    blocker:Hide()
    fly._activeDD = nil
  end)

  fly._items = {}
  M._flyout = fly
  return fly
end

local function ShowFlyout(ddBtn, items, currentValue, onSelect)
  local fly = EnsureFlyout()
  local cr, cg, cb = M:GetClassColor()

  for _, item in ipairs(fly._items) do item:Hide() end

  local ITEM_H = 24
  local FLY_W = ddBtn:GetWidth()
  local count = #items
  fly:SetSize(FLY_W, count * ITEM_H + 4)
  fly:ClearAllPoints()
  fly:SetPoint("TOPLEFT", ddBtn, "BOTTOMLEFT", 0, -2)

  for i, entry in ipairs(items) do
    local btn = fly._items[i]
    if not btn then
      btn = CreateFrame("Button", nil, fly)
      btn:SetHeight(ITEM_H)

      local bg = btn:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(1, 1, 1, 0)
      btn._bg = bg

      local label = btn:CreateFontString(nil, "OVERLAY")
      M:SafeFont(label, 11, "OUTLINE")
      label:SetPoint("LEFT", 10, 0)
      btn._label = label

      local check = M:CreateCheckmark(btn)
      btn._check = check

      btn:SetScript("OnEnter", function(self) self._bg:SetColorTexture(1, 1, 1, 0.06) end)
      btn:SetScript("OnLeave", function(self) self._bg:SetColorTexture(1, 1, 1, 0) end)

      fly._items[i] = btn
    end

    btn:SetPoint("TOPLEFT", fly, "TOPLEFT", 2, -(2 + (i - 1) * ITEM_H))
    btn:SetPoint("RIGHT", fly, "RIGHT", -2, 0)
    btn._label:SetText(entry.text)
    btn._label:SetTextColor(unpack(T.TEXT))

    local isSelected = (entry.value == currentValue)
    btn._check:SetTextColor(cr, cg, cb, 1)
    if isSelected then btn._check:Show() else btn._check:Hide() end

    btn:SetScript("OnClick", function()
      fly:Hide()
      if onSelect then onSelect(entry.value, entry.text) end
    end)
    btn:Show()
  end

  fly._activeDD = ddBtn
  fly:Show()
end

-- expose ShowFlyout on M for custom pages (e.g. Profils)
function M:ShowFlyout(ddBtn, items, currentValue, onSelect)
  ShowFlyout(ddBtn, items, currentValue, onSelect)
end

-- ============================================================================
-- WIDGET BUILDERS
-- ============================================================================

local BUILDERS = {}

local function SpecGet(spec)
  if spec.get then return spec.get() end
  if spec.db then return DBGet(spec.db) end
  return nil
end

local function SpecSet(spec, value)
  if spec.set then spec.set(value)
  elseif spec.db then DBSet(spec.db, value) end
end

-- HEADER
function BUILDERS.header(parent, spec, _)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  local H = 28
  f:SetHeight(H)

  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(2)
  line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  line:SetColorTexture(cr, cg, cb, 0.35)

  local textX = 2

  if spec.icon then
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", f, "LEFT", 2, -2)
    if type(spec.icon) == "string" and spec.icon:find("Interface") then
      icon:SetTexture(spec.icon)
    else
      local ok = pcall(icon.SetAtlas, icon, spec.icon)
      if not ok then icon:SetTexture(spec.icon) end
    end
    icon:SetVertexColor(cr, cg, cb, 0.9)
    textX = 20
  end

  local fs = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(fs, 13, "OUTLINE")
  fs:SetPoint("LEFT", f, "LEFT", textX, -2)
  fs:SetText(spec.label or "")
  fs:SetTextColor(1, 1, 1, 1)

  return { frame = f, height = H }
end

-- SEPARATOR
function BUILDERS.separator(parent, spec, _)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(14)

  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(2)
  line:SetPoint("LEFT", f, "LEFT", 0, 0)
  line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  line:SetColorTexture(cr, cg, cb, 0.25)

  return { frame = f, height = 14 }
end

-- LABEL
function BUILDERS.label(parent, spec, _)
  local f = CreateFrame("Frame", nil, parent)
  local fs = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(fs, spec.size or 11, "OUTLINE")
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  fs:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  fs:SetTextColor(unpack(spec.color or T.MUTED))
  fs:SetText(spec.text or "")
  if spec.wrap ~= false then fs:SetWordWrap(true) end
  local h = math.max(fs:GetStringHeight() + 4, 16)
  f:SetHeight(h)
  f:SetScript("OnSizeChanged", function()
    local nh = math.max(fs:GetStringHeight() + 4, 16)
    f:SetHeight(nh)
  end)
  return { frame = f, height = h, _getHeight = function() return f:GetHeight() end }
end

-- INFO
function BUILDERS.info(parent, spec, _)
  local f = CreateFrame("Frame", nil, parent)
  local fs = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(fs, spec.size or 11, "OUTLINE")
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  fs:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  fs:SetWordWrap(true)

  local function UpdateVisual()
    if spec.getValue then
      local text, color = spec.getValue()
      fs:SetText(text or "")
      fs:SetTextColor(unpack(color or spec.color or T.MUTED))
    end
    local h = math.max(fs:GetStringHeight() + 4, 16)
    f:SetHeight(h)
  end
  UpdateVisual()
  f:SetScript("OnSizeChanged", function()
    local h = math.max(fs:GetStringHeight() + 4, 16)
    f:SetHeight(h)
  end)
  return { frame = f, height = math.max(f:GetHeight(), 16), refresh = UpdateVisual, _getHeight = function() return f:GetHeight() end }
end

-- DIVIDER
function BUILDERS.divider(parent, spec, _)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(12)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", f, "LEFT", 0, 0)
  line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  line:SetColorTexture(0.4, 0.4, 0.4, spec.alpha or 0.18)
  return { frame = f, height = 12 }
end

-- TOGGLE
function BUILDERS.toggle(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Button", nil, parent)
  f:SetHeight(28)

  local S = 14
  local box = CreateFrame("Frame", nil, f)
  box:SetSize(S, S)
  box:SetPoint("LEFT", f, "LEFT", 2, 0)

  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.04, 0.06, 1)

  local bL = box:CreateTexture(nil, "BORDER")
  bL:SetSize(1, S) bL:SetPoint("LEFT") bL:SetColorTexture(unpack(T.BORDER))
  local bR = box:CreateTexture(nil, "BORDER")
  bR:SetSize(1, S) bR:SetPoint("RIGHT") bR:SetColorTexture(unpack(T.BORDER))
  local bT = box:CreateTexture(nil, "BORDER")
  bT:SetSize(S, 1) bT:SetPoint("TOP") bT:SetColorTexture(unpack(T.BORDER))
  local bB = box:CreateTexture(nil, "BORDER")
  bB:SetSize(S, 1) bB:SetPoint("BOTTOM") bB:SetColorTexture(unpack(T.BORDER))
  local borders = { bL, bR, bT, bB }

  local fill = box:CreateTexture(nil, "ARTWORK")
  fill:SetSize(8, 8)
  fill:SetPoint("CENTER")
  fill:SetColorTexture(cr, cg, cb, 0.90)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("LEFT", box, "RIGHT", 8, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local function SetBorderColor(r, g, b, a)
    for _, t in ipairs(borders) do t:SetColorTexture(r, g, b, a) end
  end

  local function UpdateVisual()
    local val = SpecGet(spec)
    if val then
      fill:Show()
      SetBorderColor(cr, cg, cb, 0.60)
    else
      fill:Hide()
      SetBorderColor(unpack(T.BORDER))
    end
  end

  f:SetScript("OnClick", function()
    local cur = SpecGet(spec)
    SpecSet(spec, not cur)
    UpdateVisual()
    if refreshFn then refreshFn() end
  end)

  f:SetScript("OnEnter", function()
    if not SpecGet(spec) then
      SetBorderColor(0.35, 0.35, 0.40, 1)
    end
  end)
  f:SetScript("OnLeave", function() UpdateVisual() end)

  UpdateVisual()

  return { frame = f, height = 28, refresh = UpdateVisual }
end

-- RADIO TOGGLE
function BUILDERS.radio_toggle(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(28)

  local items = spec.values or {}
  local radios = {}
  local S = 14

  local function SetBoxBorder(borders, r, g, b, a)
    for _, t in ipairs(borders) do t:SetColorTexture(r, g, b, a) end
  end

  local function UpdateVisual()
    local cur = SpecGet(spec)
    for _, rd in ipairs(radios) do
      if rd.value == cur then
        rd.fill:Show()
        SetBoxBorder(rd.borders, cr, cg, cb, 0.60)
      else
        rd.fill:Hide()
        SetBoxBorder(rd.borders, unpack(T.BORDER))
      end
    end
  end

  for i, entry in ipairs(items) do
    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(S)
    if i == 1 then
      btn:SetPoint("LEFT", f, "LEFT", 0, 0)
    else
      btn:SetPoint("LEFT", f, "CENTER", 0, 0)
    end

    local box = CreateFrame("Frame", nil, btn)
    box:SetSize(S, S)
    box:SetPoint("LEFT", btn, "LEFT", 0, 0)

    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 1)

    local bL = box:CreateTexture(nil, "BORDER")
    bL:SetSize(1, S) bL:SetPoint("LEFT") bL:SetColorTexture(unpack(T.BORDER))
    local bR = box:CreateTexture(nil, "BORDER")
    bR:SetSize(1, S) bR:SetPoint("RIGHT") bR:SetColorTexture(unpack(T.BORDER))
    local bT = box:CreateTexture(nil, "BORDER")
    bT:SetSize(S, 1) bT:SetPoint("TOP") bT:SetColorTexture(unpack(T.BORDER))
    local bB = box:CreateTexture(nil, "BORDER")
    bB:SetSize(S, 1) bB:SetPoint("BOTTOM") bB:SetColorTexture(unpack(T.BORDER))
    local borders = { bL, bR, bT, bB }

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetSize(8, 8)
    fill:SetPoint("CENTER")
    fill:SetColorTexture(cr, cg, cb, 0.90)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 11, "OUTLINE")
    lbl:SetPoint("LEFT", box, "RIGHT", 6, 0)
    lbl:SetText(entry.text or "")
    lbl:SetTextColor(unpack(T.TEXT))

    btn:SetWidth(300)

    local value = entry.value
    btn:SetScript("OnClick", function()
      SpecSet(spec, value)
      UpdateVisual()
      if refreshFn then refreshFn() end
    end)
    btn:SetScript("OnEnter", function()
      if SpecGet(spec) ~= value then
        SetBoxBorder(borders, 0.35, 0.35, 0.40, 1)
      end
    end)
    btn:SetScript("OnLeave", function() UpdateVisual() end)

    radios[#radios + 1] = { fill = fill, borders = borders, value = value }
  end

  UpdateVisual()

  return { frame = f, height = 28, refresh = UpdateVisual }
end

-- TOGGLE PAIR
function BUILDERS.toggle_pair(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(28)

  local items = spec.items or {}
  local S = 14
  local toggles = {}

  local function SetBoxBorder(borders, r, g, b, a)
    for _, t in ipairs(borders) do t:SetColorTexture(r, g, b, a) end
  end

  for i, item in ipairs(items) do
    if i > 2 then break end

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(S)
    if i == 1 then
      btn:SetPoint("LEFT", f, "LEFT", 2, 0)
    else
      btn:SetPoint("LEFT", f, "CENTER", 2, 0)
    end
    btn:SetWidth(300)

    local box = CreateFrame("Frame", nil, btn)
    box:SetSize(S, S)
    box:SetPoint("LEFT", btn, "LEFT", 0, 0)

    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 1)

    local bL = box:CreateTexture(nil, "BORDER")
    bL:SetSize(1, S) bL:SetPoint("LEFT") bL:SetColorTexture(unpack(T.BORDER))
    local bR = box:CreateTexture(nil, "BORDER")
    bR:SetSize(1, S) bR:SetPoint("RIGHT") bR:SetColorTexture(unpack(T.BORDER))
    local bT = box:CreateTexture(nil, "BORDER")
    bT:SetSize(S, 1) bT:SetPoint("TOP") bT:SetColorTexture(unpack(T.BORDER))
    local bB = box:CreateTexture(nil, "BORDER")
    bB:SetSize(S, 1) bB:SetPoint("BOTTOM") bB:SetColorTexture(unpack(T.BORDER))
    local borders = { bL, bR, bT, bB }

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetSize(8, 8)
    fill:SetPoint("CENTER")
    fill:SetColorTexture(cr, cg, cb, 0.90)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 11, "OUTLINE")
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetText(item.label or "")
    lbl:SetTextColor(unpack(T.TEXT))

    local tgl = { fill = fill, borders = borders, item = item }

    local function UpdateOne()
      local val = item.get and item.get()
      if val then
        fill:Show()
        SetBoxBorder(borders, cr, cg, cb, 0.60)
      else
        fill:Hide()
        SetBoxBorder(borders, unpack(T.BORDER))
      end
    end

    btn:SetScript("OnClick", function()
      local cur = item.get and item.get()
      if item.set then item.set(not cur) end
      UpdateOne()
      if refreshFn then refreshFn() end
    end)
    btn:SetScript("OnEnter", function()
      if not (item.get and item.get()) then
        SetBoxBorder(borders, 0.35, 0.35, 0.40, 1)
      end
    end)
    btn:SetScript("OnLeave", function() UpdateOne() end)

    tgl.refresh = UpdateOne
    toggles[#toggles + 1] = tgl
  end

  local function RefreshAll()
    for _, tgl in ipairs(toggles) do tgl.refresh() end
  end
  RefreshAll()

  return { frame = f, height = 28, refresh = RefreshAll }
end

-- SLIDER
function BUILDERS.slider(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(50)

  local sMin = spec.min or 0
  local sMax = spec.max or 100
  local sStep = spec.step or 1
  local sDec = spec.decimals or 0
  local fmt = "%." .. sDec .. "f"

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local valBox = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  valBox:SetSize(60, 18)
  valBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  valBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  valBox:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
  valBox:SetBackdropBorderColor(unpack(T.BORDER))
  valBox:SetAutoFocus(false)
  valBox:SetJustifyH("CENTER")
  M:SafeFont(valBox, 10, "OUTLINE")
  valBox:SetTextColor(unpack(T.TEXT))

  local TRACK_H = 4
  local track = CreateFrame("Frame", nil, f)
  track:SetHeight(TRACK_H)
  track:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -28)
  track:SetPoint("RIGHT", f, "RIGHT", 0, 0)

  local trackBg = track:CreateTexture(nil, "BACKGROUND")
  trackBg:SetAllPoints()
  trackBg:SetColorTexture(0.04, 0.04, 0.06, 1)

  local fill = track:CreateTexture(nil, "ARTWORK")
  fill:SetHeight(TRACK_H)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetColorTexture(cr, cg, cb, 0.25)

  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetSize(12, 12)
  local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
  thumbTex:SetAllPoints()
  thumbTex:SetColorTexture(cr, cg, cb, 0.70)
  thumb._tex = thumbTex

  local function Clamp(v) return math.max(sMin, math.min(sMax, v)) end

  local function SnapToStep(v)
    v = Clamp(v)
    if sStep > 0 then v = math.floor(v / sStep + 0.5) * sStep end
    return tonumber(string.format(fmt, v))
  end

  local function GetPct(v) return (v - sMin) / math.max(sMax - sMin, 0.001) end

  local function UpdateVisual()
    local val = SpecGet(spec) or sMin
    val = Clamp(val)
    valBox:SetText(string.format(fmt, val))
    local pct = GetPct(val)
    local tw = track:GetWidth()
    if tw > 0 then
      fill:SetWidth(math.max(1, tw * pct))
      thumb:ClearAllPoints()
      thumb:SetPoint("CENTER", track, "LEFT", tw * pct, 0)
    end
  end

  track:EnableMouse(true)
  local dragging = false

  local function SetFromMouse()
    local cx = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
    local left = track:GetLeft() or 0
    local tw = track:GetWidth()
    if tw <= 0 then return end
    local pct = math.max(0, math.min(1, (cx - left) / tw))
    local val = SnapToStep(sMin + pct * (sMax - sMin))
    SpecSet(spec, val)
    UpdateVisual()
  end

  track:SetScript("OnMouseDown", function()
    dragging = true
    SetFromMouse()
  end)
  track:SetScript("OnMouseUp", function()
    dragging = false
    if refreshFn then refreshFn() end
  end)
  track:SetScript("OnUpdate", function()
    if dragging then SetFromMouse() end
  end)

  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function()
    dragging = true
    SetFromMouse()
  end)
  thumb:SetScript("OnMouseUp", function()
    dragging = false
    if refreshFn then refreshFn() end
  end)

  valBox:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
      SpecSet(spec, SnapToStep(v))
      UpdateVisual()
      if refreshFn then refreshFn() end
    end
    self:ClearFocus()
  end)
  valBox:SetScript("OnEscapePressed", function(self)
    UpdateVisual()
    self:ClearFocus()
  end)

  track:EnableMouseWheel(true)
  track:SetScript("OnMouseWheel", function(self, delta)
    local p = self:GetParent()
    while p do
      local handler = p:GetScript("OnMouseWheel")
      if handler then handler(p, delta); return end
      p = p:GetParent()
    end
  end)

  UpdateVisual()
  f:SetScript("OnSizeChanged", function() UpdateVisual() end)

  return { frame = f, height = 50, refresh = UpdateVisual }
end

-- DROPDOWN
function BUILDERS.dropdown(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(48)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local dd = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  dd:SetHeight(26)
  dd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
  dd:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  dd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  dd:SetBackdropColor(unpack(T.BTN))
  dd:SetBackdropBorderColor(unpack(T.BORDER))

  local ddText = dd:CreateFontString(nil, "OVERLAY")
  M:SafeFont(ddText, 11, "OUTLINE")
  ddText:SetPoint("LEFT", 10, 0)
  ddText:SetTextColor(unpack(T.TEXT))

  local arrow = M:CreateDropdownArrow(dd)

  local function GetDisplayText(val)
    if spec.values then
      for _, v in ipairs(spec.values) do
        if v.value == val then return v.text end
      end
    end
    return tostring(val or "")
  end

  local function UpdateVisual()
    local val = SpecGet(spec)
    ddText:SetText(GetDisplayText(val))
  end

  dd:SetScript("OnClick", function(self)
    local fly = EnsureFlyout()
    if fly:IsShown() and fly._activeDD == self then
      fly:Hide()
      return
    end
    ShowFlyout(self, spec.values or {}, SpecGet(spec), function(val)
      SpecSet(spec, val)
      UpdateVisual()
      if refreshFn then refreshFn() end
    end)
  end)

  dd:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
  end)
  dd:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)

  UpdateVisual()

  return { frame = f, height = 48, refresh = UpdateVisual }
end

-- COLOR PICKER
-- ── Color Picker Popup (shared, reused) ──
local _colorPopup

local COLOR_PRESETS = {
  -- Colonnes = teintes (rouge → orange → jaune → vert → cyan → bleu → violet → rose)
  -- Lignes = du plus vif au plus sombre

  -- row 1: vif / saturé
  { 1.0, 0.0, 0.0 }, { 1.0, 0.5, 0.0 }, { 1.0, 1.0, 0.0 }, { 0.0, 1.0, 0.0 },
  { 0.0, 1.0, 1.0 }, { 0.0, 0.0, 1.0 }, { 0.5, 0.0, 1.0 }, { 1.0, 0.0, 1.0 },

  -- row 2: clair
  { 1.0, 0.4, 0.4 }, { 1.0, 0.7, 0.4 }, { 1.0, 1.0, 0.4 }, { 0.4, 1.0, 0.4 },
  { 0.4, 1.0, 1.0 }, { 0.4, 0.4, 1.0 }, { 0.7, 0.4, 1.0 }, { 1.0, 0.4, 1.0 },

  -- row 3: pastel
  { 1.0, 0.7, 0.7 }, { 1.0, 0.85, 0.7 }, { 1.0, 1.0, 0.7 }, { 0.7, 1.0, 0.7 },
  { 0.7, 1.0, 1.0 }, { 0.7, 0.7, 1.0 }, { 0.85, 0.7, 1.0 }, { 1.0, 0.7, 1.0 },

  -- row 4: moyen
  { 0.8, 0.0, 0.0 }, { 0.8, 0.4, 0.0 }, { 0.8, 0.8, 0.0 }, { 0.0, 0.8, 0.0 },
  { 0.0, 0.8, 0.8 }, { 0.0, 0.0, 0.8 }, { 0.4, 0.0, 0.8 }, { 0.8, 0.0, 0.8 },

  -- row 5: sombre
  { 0.5, 0.0, 0.0 }, { 0.5, 0.25, 0.0 }, { 0.5, 0.5, 0.0 }, { 0.0, 0.5, 0.0 },
  { 0.0, 0.5, 0.5 }, { 0.0, 0.0, 0.5 }, { 0.25, 0.0, 0.5 }, { 0.5, 0.0, 0.5 },

  -- row 6: neutres (blanc → noir)
  { 1.0, 1.0, 1.0 }, { 0.85, 0.85, 0.85 }, { 0.7, 0.7, 0.7 }, { 0.55, 0.55, 0.55 },
  { 0.4, 0.4, 0.4 }, { 0.25, 0.25, 0.25 }, { 0.12, 0.12, 0.12 }, { 0.0, 0.0, 0.0 },
}

local function RGBToHex(r, g, b)
  return string.format("%02X%02X%02X",
    math.floor((r or 1) * 255 + 0.5),
    math.floor((g or 1) * 255 + 0.5),
    math.floor((b or 1) * 255 + 0.5))
end

local function HexToRGB(hex)
  hex = hex:gsub("^#", "")
  if #hex ~= 6 then return nil end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not r or not g or not b then return nil end
  return r / 255, g / 255, b / 255
end

local function GetOrCreateColorPopup()
  if _colorPopup then return _colorPopup end

  local COLS      = 8
  local SSIZE     = 22
  local SPAD      = 3
  local PAD       = 12
  local PREV_W    = 28
  local BRIGHT_W  = 18
  local GAP_H     = 8
  local ROWS      = math.ceil(#COLOR_PRESETS / COLS)
  local gridW     = COLS * (SSIZE + SPAD) - SPAD
  local gridH     = ROWS * (SSIZE + SPAD) - SPAD
  local BRIGHT_STEPS = 10
  local BRIGHT_H  = gridH

  local HEADER_H = 20
  local topRowW  = PREV_W + GAP_H + BRIGHT_W + GAP_H + gridW
  local totalW   = topRowW + PAD * 2
  local totalH   = PAD + HEADER_H + GAP_H + gridH + GAP_H + 22 + GAP_H + 22 + PAD

  local popup = CreateFrame("Frame", "BravUI_ColorPopup", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  popup:SetSize(totalW, totalH)
  popup:SetPoint("CENTER")
  popup:SetFrameStrata("DIALOG")
  popup:SetFrameLevel(200)
  popup:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  popup:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
  popup:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)
  popup:EnableMouse(true)
  popup:SetMovable(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  popup:Hide()

  -- header
  local headerText = popup:CreateFontString(nil, "OVERLAY")
  M:SafeFont(headerText, 11, "OUTLINE")
  headerText:SetPoint("TOP", popup, "TOP", 0, -PAD)
  headerText:SetText("Palette de couleurs")
  headerText:SetTextColor(unpack(T.TEXT))

  -- close button (red X)
  local closeBtn = CreateFrame("Button", nil, popup)
  closeBtn:SetSize(16, 16)
  closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -6, -6)
  local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(closeLabel, 12, "OUTLINE")
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("X")
  closeLabel:SetTextColor(0.8, 0.2, 0.2, 1)
  closeBtn:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 0.3, 0.3, 1) end)
  closeBtn:SetScript("OnLeave", function() closeLabel:SetTextColor(0.8, 0.2, 0.2, 1) end)
  closeBtn:SetScript("OnClick", function() popup:Hide() end)

  -- base color (before brightness), stored for brightness slider
  local baseR, baseG, baseB = 1, 0, 0
  local brightness = 1.0

  local function ApplyColor()
    local r = baseR * brightness
    local g = baseG * brightness
    local b = baseB * brightness
    if popup._onPick then popup._onPick(r, g, b) end
  end

  -- ── Left: preview bar (selected color) ──
  local preview = CreateFrame("Frame", nil, popup, BackdropTemplateMixin and "BackdropTemplate" or nil)
  preview:SetSize(PREV_W, gridH)
  preview:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -(PAD + HEADER_H + GAP_H))
  preview:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  preview:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)
  popup._preview = preview

  -- ── Middle: brightness slider ──
  local brightFrame = CreateFrame("Frame", nil, popup, BackdropTemplateMixin and "BackdropTemplate" or nil)
  brightFrame:SetSize(BRIGHT_W, BRIGHT_H)
  brightFrame:SetPoint("TOPLEFT", preview, "TOPRIGHT", GAP_H, 0)
  brightFrame:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  brightFrame:SetBackdropColor(0, 0, 0, 1)
  brightFrame:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)

  -- brightness gradient steps (top = bright, bottom = dark)
  local brightSteps = {}
  local stepH = BRIGHT_H / BRIGHT_STEPS
  for i = 0, BRIGHT_STEPS - 1 do
    local t = CreateFrame("Button", nil, brightFrame)
    t:SetSize(BRIGHT_W - 2, stepH)
    t:SetPoint("TOPLEFT", brightFrame, "TOPLEFT", 1, -(1 + i * stepH))
    local tex = t:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    t._tex = tex
    t._pct = 1.0 - (i / BRIGHT_STEPS)
    brightSteps[i + 1] = t
  end

  local function UpdateBrightnessBar()
    for _, s in ipairs(brightSteps) do
      local p = s._pct
      s._tex:SetColorTexture(baseR * p, baseG * p, baseB * p, 1)
    end
  end

  -- brightness thumb — simple thin line with bright outline
  local thumbBg = brightFrame:CreateTexture(nil, "OVERLAY", nil, 1)
  thumbBg:SetHeight(6)
  thumbBg:SetColorTexture(0, 0, 0, 1)

  local thumbFill = brightFrame:CreateTexture(nil, "OVERLAY", nil, 2)
  thumbFill:SetHeight(2)
  thumbFill:SetColorTexture(1, 1, 1, 1)

  local function UpdateBrightnessThumb()
    local pct = 1.0 - brightness
    local y = pct * (BRIGHT_H - 2)
    thumbBg:ClearAllPoints()
    thumbBg:SetPoint("TOPLEFT", brightFrame, "TOPLEFT", -1, -y + 2)
    thumbBg:SetPoint("TOPRIGHT", brightFrame, "TOPRIGHT", 1, -y + 2)
    thumbFill:ClearAllPoints()
    thumbFill:SetPoint("TOPLEFT", brightFrame, "TOPLEFT", 0, -y)
    thumbFill:SetPoint("TOPRIGHT", brightFrame, "TOPRIGHT", 0, -y)
  end

  for _, s in ipairs(brightSteps) do
    s:SetScript("OnClick", function(self)
      brightness = self._pct
      UpdateBrightnessThumb()
      ApplyColor()
    end)
  end

  -- brightness drag
  brightFrame:EnableMouse(true)
  local brightDragging = false

  local function SetBrightnessFromMouse()
    local _, cy = GetCursorPosition()
    cy = cy / UIParent:GetEffectiveScale()
    local top = brightFrame:GetTop() or 0
    local h = brightFrame:GetHeight()
    if h <= 0 then return end
    local pct = math.max(0, math.min(1, (top - cy) / h))
    brightness = 1.0 - pct
    UpdateBrightnessThumb()
    ApplyColor()
  end

  brightFrame:SetScript("OnMouseDown", function()
    brightDragging = true
    SetBrightnessFromMouse()
  end)
  brightFrame:SetScript("OnMouseUp", function() brightDragging = false end)
  brightFrame:SetScript("OnUpdate", function()
    if brightDragging then SetBrightnessFromMouse() end
  end)

  -- ── Right: color grid ──
  local gridAnchor = CreateFrame("Frame", nil, popup)
  gridAnchor:SetSize(gridW, gridH)
  gridAnchor:SetPoint("TOPLEFT", brightFrame, "TOPRIGHT", GAP_H, 0)

  local swatches = {}
  for i, c in ipairs(COLOR_PRESETS) do
    local idx = i - 1
    local col = idx % COLS
    local row = math.floor(idx / COLS)
    local sw = CreateFrame("Button", nil, gridAnchor, BackdropTemplateMixin and "BackdropTemplate" or nil)
    sw:SetSize(SSIZE, SSIZE)
    sw:SetPoint("TOPLEFT", gridAnchor, "TOPLEFT",
      col * (SSIZE + SPAD), -(row * (SSIZE + SPAD)))
    sw:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    sw:SetBackdropColor(c[1], c[2], c[3], 1)
    sw:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)
    sw:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.8) end)
    sw:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.15, 0.15, 0.18, 1) end)
    sw:SetScript("OnClick", function()
      baseR, baseG, baseB = c[1], c[2], c[3]
      brightness = 1.0
      UpdateBrightnessBar()
      UpdateBrightnessThumb()
      ApplyColor()
    end)
    swatches[i] = sw
  end

  -- ── Hex input row ──
  local hexRow = CreateFrame("Frame", nil, popup)
  hexRow:SetSize(topRowW, 22)
  hexRow:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -(PAD + HEADER_H + GAP_H + gridH + GAP_H))

  local hexLabel = hexRow:CreateFontString(nil, "OVERLAY")
  M:SafeFont(hexLabel, 10, "OUTLINE")
  hexLabel:SetPoint("LEFT", 0, 0)
  hexLabel:SetText("#")
  hexLabel:SetTextColor(unpack(T.MUTED))

  local hexBox = CreateFrame("EditBox", nil, hexRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
  hexBox:SetHeight(22)
  hexBox:SetPoint("LEFT", hexLabel, "RIGHT", 4, 0)
  hexBox:SetPoint("RIGHT", hexRow, "RIGHT", 0, 0)
  hexBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  hexBox:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
  hexBox:SetBackdropBorderColor(unpack(T.BORDER))
  hexBox:SetAutoFocus(false)
  hexBox:SetJustifyH("CENTER")
  hexBox:SetMaxLetters(6)
  M:SafeFont(hexBox, 10, "OUTLINE")
  hexBox:SetTextColor(unpack(T.TEXT))
  popup._hexBox = hexBox

  hexBox:SetScript("OnEnterPressed", function(self)
    local r, g, b = HexToRGB(self:GetText())
    if r then
      baseR, baseG, baseB = r, g, b
      brightness = 1.0
      UpdateBrightnessBar()
      UpdateBrightnessThumb()
      ApplyColor()
    end
    self:ClearFocus()
  end)
  hexBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  -- ── Buttons row ──
  local btnRow = CreateFrame("Frame", nil, popup)
  btnRow:SetSize(topRowW, 22)
  btnRow:SetPoint("TOPLEFT", hexRow, "BOTTOMLEFT", 0, -GAP_H)

  local btnW = math.floor((topRowW - 4) / 2)

  local okBtn = CreateFrame("Button", nil, btnRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
  okBtn:SetSize(btnW, 22)
  okBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
  okBtn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  okBtn:SetBackdropColor(unpack(T.BTN))
  okBtn:SetBackdropBorderColor(unpack(T.BORDER))
  local okLbl = okBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(okLbl, 10, "OUTLINE")
  okLbl:SetPoint("CENTER")
  okLbl:SetText("OK")
  okLbl:SetTextColor(unpack(T.TEXT))
  okBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(T.BTN_HOVER)) end)
  okBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(T.BTN)) end)
  okBtn:SetScript("OnClick", function() popup:Hide() end)

  local resetBtn = CreateFrame("Button", nil, btnRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
  resetBtn:SetSize(btnW, 22)
  resetBtn:SetPoint("RIGHT", btnRow, "RIGHT", 0, 0)
  resetBtn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  resetBtn:SetBackdropColor(unpack(T.BTN))
  resetBtn:SetBackdropBorderColor(unpack(T.BORDER))
  local resetLbl = resetBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(resetLbl, 10, "OUTLINE")
  resetLbl:SetPoint("CENTER")
  resetLbl:SetText("Reset")
  resetLbl:SetTextColor(unpack(T.TEXT))
  resetBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(T.BTN_HOVER)) end)
  resetBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(T.BTN)) end)
  resetBtn:SetScript("OnClick", function()
    if popup._onReset then popup._onReset() end
  end)

  popup:SetScript("OnHide", function()
    if popup._onClose then popup._onClose() end
    popup._onPick = nil
    popup._onClose = nil
    popup._onReset = nil
  end)

  -- expose internals for init
  popup._setBase = function(r, g, b)
    baseR, baseG, baseB = r, g, b
    brightness = 1.0
    UpdateBrightnessBar()
    UpdateBrightnessThumb()
  end

  _colorPopup = popup
  return popup
end

function BUILDERS.color(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(28)

  local anchor = spec.halfIndent and "CENTER" or "LEFT"

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("LEFT", f, anchor, 26, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local swatch = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  swatch:SetSize(18, 18)
  swatch:SetPoint("LEFT", f, anchor, 0, 0)
  swatch:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  swatch:SetBackdropBorderColor(unpack(T.BORDER))

  local function UpdateVisual()
    local col = SpecGet(spec)
    if type(col) == "table" then
      swatch:SetBackdropColor(col.r or 1, col.g or 1, col.b or 1, 1)
    else
      swatch:SetBackdropColor(1, 1, 1, 1)
    end
  end

  swatch:SetScript("OnClick", function()
    local col = SpecGet(spec)
    if type(col) ~= "table" then col = { r = 1, g = 1, b = 1 } end

    local popup = GetOrCreateColorPopup()
    popup._preview:SetBackdropColor(col.r or 1, col.g or 1, col.b or 1, 1)
    popup._hexBox:SetText(RGBToHex(col.r, col.g, col.b))
    popup._setBase(col.r or 1, col.g or 1, col.b or 1)

    popup._onPick = function(r, g, b)
      local tbl = SpecGet(spec) or {}
      tbl.r, tbl.g, tbl.b = r, g, b
      SpecSet(spec, tbl)
      UpdateVisual()
      popup._preview:SetBackdropColor(r, g, b, 1)
      popup._hexBox:SetText(RGBToHex(r, g, b))
      if refreshFn then refreshFn() end
    end

    popup._onReset = function()
      if not spec.db then return end
      local parts = SplitPath(spec.db)
      local def = BravLib.Storage.GetDefaults()
      local val = def
      for i = 1, #parts do
        if type(val) ~= "table" then val = nil; break end
        val = val[parts[i]]
      end
      if type(val) == "table" and val.r then
        SpecSet(spec, { r = val.r, g = val.g, b = val.b })
      else
        -- no default exists — clear the custom color
        local db = BravLib.Storage.GetDB()
        if db then
          local t = db
          for i = 1, #parts - 1 do
            if type(t[parts[i]]) ~= "table" then return end
            t = t[parts[i]]
          end
          t[parts[#parts]] = nil
        end
      end
      UpdateVisual()
      local c = SpecGet(spec)
      if type(c) == "table" and c.r then
        popup._preview:SetBackdropColor(c.r, c.g, c.b, 1)
        popup._hexBox:SetText(RGBToHex(c.r, c.g, c.b))
      else
        popup._preview:SetBackdropColor(1, 1, 1, 1)
        popup._hexBox:SetText("FFFFFF")
      end
      if refreshFn then refreshFn() end
    end

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    popup:Show()
  end)

  swatch:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(cr, cg, cb, 0.50)
  end)
  swatch:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)

  UpdateVisual()

  return { frame = f, height = 28, refresh = UpdateVisual }
end

-- INPUT
function BUILDERS.input(parent, spec, refreshFn)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(48)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local box = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  box:SetHeight(24)
  box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
  box:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  box:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  box:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
  box:SetBackdropBorderColor(unpack(T.BORDER))
  box:SetAutoFocus(false)
  box:SetTextInsets(8, 8, 0, 0)
  M:SafeFont(box, 11, "OUTLINE")
  box:SetTextColor(unpack(T.TEXT))

  local function UpdateVisual()
    local val = SpecGet(spec)
    box:SetText(val ~= nil and tostring(val) or "")
  end

  local function Commit()
    local text = box:GetText()
    local val = spec.number and tonumber(text) or text
    if val ~= nil then
      SpecSet(spec, val)
      if refreshFn then refreshFn() end
    end
    box:ClearFocus()
  end

  box:SetScript("OnEnterPressed", Commit)
  box:SetScript("OnEscapePressed", function(self)
    UpdateVisual()
    self:ClearFocus()
  end)

  UpdateVisual()

  return { frame = f, height = 48, refresh = UpdateVisual }
end

-- BUTTON
function BUILDERS.button(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(32)

  local btn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  btn:SetSize(spec.width or 140, 26)
  btn:SetPoint("LEFT", f, "LEFT", 0, 0)
  btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  btn:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
  btn:SetBackdropBorderColor(unpack(T.BORDER))

  local label = btn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(cr, cg, cb, 1)

  btn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(cr * 0.25, cg * 0.25, cb * 0.25, 1)
    self:SetBackdropBorderColor(cr, cg, cb, 0.50)
  end)
  btn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)

  if spec.onClick then
    btn:SetScript("OnClick", function(self)
      spec.onClick(self)
      if refreshFn then refreshFn() end
    end)
  end

  return { frame = f, height = 32 }
end

-- BUTTON ROW
function BUILDERS.button_row(parent, spec, _)
  local cr, cg, cb = M:GetClassColor()
  local btns = spec.buttons or {}
  local count = #btns
  if count == 0 then return { frame = CreateFrame("Frame", nil, parent), height = 0 } end

  local ROW_H = 30
  local BTN_H = 24
  local BTN_GAP = 6

  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(ROW_H)

  local prev
  for i, bSpec in ipairs(btns) do
    local col = CreateFrame("Frame", nil, f)
    col:SetHeight(ROW_H)
    if i == 1 then
      col:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    else
      col:SetPoint("TOPLEFT", prev, "TOPRIGHT", BTN_GAP, 0)
    end
    if i == count then
      col:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    else
      col:SetWidth(1)
    end
    prev = col

    local btn = CreateFrame("Button", nil, col, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
    btn:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", 0, ROW_H - BTN_H)
    btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    btn:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
    btn:SetBackdropBorderColor(unpack(T.BORDER))

    local label = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(label, 11, "OUTLINE")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(bSpec.label or "")
    label:SetTextColor(cr, cg, cb, 1)

    btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(cr * 0.25, cg * 0.25, cb * 0.25, 1)
      self:SetBackdropBorderColor(cr, cg, cb, 0.50)
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
      self:SetBackdropBorderColor(unpack(T.BORDER))
    end)

    if bSpec.onClick then
      btn:SetScript("OnClick", bSpec.onClick)
    end

    if not f._cols then f._cols = {} end
    f._cols[i] = col
  end

  f:SetScript("OnSizeChanged", function(self, w)
    if not self._cols or w < 1 then return end
    local n = #self._cols
    local colW = (w - BTN_GAP * (n - 1)) / n
    for idx, col in ipairs(self._cols) do
      col:SetWidth(math.max(colW, 1))
    end
  end)

  return { frame = f, height = ROW_H }
end

-- BUTTON SELECT
function BUILDERS.button_select(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(48)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local items = spec.values or {}
  local BTN_H = 24
  local BTN_GAP = 2
  local BTN_TOP = 22
  local btns = {}

  local function UpdateVisual()
    local cur = SpecGet(spec)
    for i, b in ipairs(btns) do
      if items[i].value == cur then
        b._bd:SetBackdropColor(cr, cg, cb, 0.90)
        b._bd:SetBackdropBorderColor(cr, cg, cb, 0.60)
        b._label:SetTextColor(1, 1, 1, 1)
      else
        b._bd:SetBackdropColor(unpack(T.PANEL))
        b._bd:SetBackdropBorderColor(unpack(T.BORDER))
        b._label:SetTextColor(unpack(T.TEXT))
      end
    end
  end

  for i, entry in ipairs(items) do
    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(BTN_H)

    local bd = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bd:SetAllPoints()
    bd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    btn._bd = bd

    local lbl = bd:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 10, "OUTLINE")
    lbl:SetPoint("CENTER", 0, 0)
    lbl:SetText(entry.text or "")
    btn._label = lbl

    local value = entry.value

    btn:SetScript("OnClick", function()
      SpecSet(spec, value)
      UpdateVisual()
      if refreshFn then refreshFn() end
    end)

    btn:SetScript("OnEnter", function()
      if SpecGet(spec) ~= value then
        bd:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)
      end
    end)
    btn:SetScript("OnLeave", function() UpdateVisual() end)

    btns[i] = btn
  end

  local function LayoutButtons()
    local pw = f:GetWidth()
    if pw < 1 or #btns == 0 then return end
    local btnW = (pw - BTN_GAP * (#btns - 1)) / #btns
    for i, btn in ipairs(btns) do
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (btnW + BTN_GAP), -BTN_TOP)
      btn:SetWidth(btnW)
    end
  end

  f:SetScript("OnSizeChanged", function() LayoutButtons() end)
  LayoutButtons()
  UpdateVisual()

  return { frame = f, height = 48, refresh = UpdateVisual }
end

-- ANCHOR GRID (3x3)
function BUILDERS.anchor_grid(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(100)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local CELL_H   = 24
  local CELL_GAP = 2
  local GRID_TOP = 22
  local LABELS   = { "Haut Gauche", "Haut", "Haut Droite", "Gauche", "Centre", "Droite", "Bas Gauche", "Bas", "Bas Droite" }
  local VALUES   = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT",    "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
  }

  local cells = {}

  local function UpdateVisual()
    local cur = SpecGet(spec)
    for i, cell in ipairs(cells) do
      if VALUES[i] == cur then
        cell._bd:SetBackdropColor(cr, cg, cb, 0.90)
        cell._bd:SetBackdropBorderColor(cr, cg, cb, 0.60)
        cell._label:SetTextColor(1, 1, 1, 1)
      else
        cell._bd:SetBackdropColor(unpack(T.PANEL))
        cell._bd:SetBackdropBorderColor(unpack(T.BORDER))
        cell._label:SetTextColor(unpack(T.TEXT))
      end
    end
  end

  for i = 1, 9 do
    local row = math.floor((i - 1) / 3)
    local col = (i - 1) % 3

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(CELL_H)

    local bd = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bd:SetAllPoints()
    bd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    btn._bd = bd

    local lbl = bd:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 10, "OUTLINE")
    lbl:SetPoint("CENTER", 0, 0)
    lbl:SetText(LABELS[i])
    btn._label = lbl

    local value = VALUES[i]

    btn:SetScript("OnClick", function()
      SpecSet(spec, value)
      UpdateVisual()
      if refreshFn then refreshFn() end
    end)

    btn:SetScript("OnEnter", function()
      if SpecGet(spec) ~= value then
        bd:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)
      end
    end)
    btn:SetScript("OnLeave", function() UpdateVisual() end)

    cells[i] = btn
    btn._row = row
    btn._col = col
  end

  local function LayoutGrid()
    local pw = f:GetWidth()
    if pw < 1 then return end
    local cellW = (pw - CELL_GAP * 2) / 3
    for i, btn in ipairs(cells) do
      local x = btn._col * (cellW + CELL_GAP)
      local y = -(GRID_TOP + btn._row * (CELL_H + CELL_GAP))
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      btn:SetWidth(cellW)
    end
  end

  f:SetScript("OnSizeChanged", function() LayoutGrid() end)
  LayoutGrid()
  UpdateVisual()

  return { frame = f, height = 100, refresh = UpdateVisual }
end

-- CORNER GRID (2x2)
function BUILDERS.corner_grid(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(74)

  local label = f:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 11, "OUTLINE")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  label:SetText(spec.label or "")
  label:SetTextColor(unpack(T.TEXT))

  local CELL_H   = 24
  local CELL_GAP = 2
  local GRID_TOP = 22
  local LABELS   = { "Haut Gauche", "Haut Droite", "Bas Gauche", "Bas Droite" }
  local VALUES   = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

  local cells = {}

  local function UpdateVisual()
    local cur = SpecGet(spec)
    for i, cell in ipairs(cells) do
      if VALUES[i] == cur then
        cell._bd:SetBackdropColor(cr, cg, cb, 0.90)
        cell._bd:SetBackdropBorderColor(cr, cg, cb, 0.60)
        cell._label:SetTextColor(1, 1, 1, 1)
      else
        cell._bd:SetBackdropColor(unpack(T.PANEL))
        cell._bd:SetBackdropBorderColor(unpack(T.BORDER))
        cell._label:SetTextColor(unpack(T.TEXT))
      end
    end
  end

  for i = 1, 4 do
    local row = math.floor((i - 1) / 2)
    local col = (i - 1) % 2

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(CELL_H)

    local bd = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bd:SetAllPoints()
    bd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    btn._bd = bd

    local lbl = bd:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 10, "OUTLINE")
    lbl:SetPoint("CENTER", 0, 0)
    lbl:SetText(LABELS[i])
    btn._label = lbl

    local value = VALUES[i]

    btn:SetScript("OnClick", function()
      SpecSet(spec, value)
      UpdateVisual()
      if refreshFn then refreshFn() end
    end)

    btn:SetScript("OnEnter", function()
      if SpecGet(spec) ~= value then
        bd:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)
      end
    end)
    btn:SetScript("OnLeave", function() UpdateVisual() end)

    cells[i] = btn
    btn._row = row
    btn._col = col
  end

  local function LayoutGrid()
    local pw = f:GetWidth()
    if pw < 1 then return end
    local cellW = (pw - CELL_GAP) / 2
    for i, btn in ipairs(cells) do
      local x = btn._col * (cellW + CELL_GAP)
      local y = -(GRID_TOP + btn._row * (CELL_H + CELL_GAP))
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      btn:SetWidth(cellW)
    end
  end

  f:SetScript("OnSizeChanged", function() LayoutGrid() end)
  LayoutGrid()
  UpdateVisual()

  return { frame = f, height = 74, refresh = UpdateVisual }
end

-- GROUP (collapsible section)
function BUILDERS.group(parent, spec, refreshFn)
  local cr, cg, cb = M:GetClassColor()
  local collapsed = spec.collapsed ~= false

  local f = CreateFrame("Frame", nil, parent)

  local header = CreateFrame("Button", nil, f)
  header:SetHeight(26)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  header:SetPoint("RIGHT", f, "RIGHT", 0, 0)

  local hBg = header:CreateTexture(nil, "BACKGROUND")
  hBg:SetAllPoints()
  hBg:SetColorTexture(cr, cg, cb, 0.06)

  local arrow = M:CreateGroupArrow(header, 10, { cr, cg, cb, 1 })
  arrow:SetPoint("LEFT", header, "LEFT", 8, 0)

  local labelAnchor = arrow
  local labelOffX = 6

  if spec.icon then
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    if type(spec.icon) == "string" and spec.icon:find("Interface") then
      icon:SetTexture(spec.icon)
    else
      local ok = pcall(icon.SetAtlas, icon, spec.icon)
      if not ok then icon:SetTexture(spec.icon) end
    end
    icon:SetVertexColor(cr, cg, cb, 0.9)
    labelAnchor = icon
    labelOffX = 4
  end

  local hLabel = header:CreateFontString(nil, "OVERLAY")
  M:SafeFont(hLabel, 11, "OUTLINE")
  hLabel:SetPoint("LEFT", labelAnchor, "RIGHT", labelOffX, 0)
  hLabel:SetText(spec.label or "")
  hLabel:SetTextColor(unpack(T.TEXT))

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -GAP)
  content:SetPoint("RIGHT", f, "RIGHT", 0, 0)

  local childWidgets = {}
  local childHeight = 0
  if spec.children then
    childHeight, childWidgets = M:BuildOptions(content, spec.children, refreshFn)
  end
  content:SetHeight(math.max(childHeight, 1))

  local function UpdateState()
    if collapsed then
      arrow:SetCollapsed(true)
      content:Hide()
      f:SetHeight(26)
    else
      arrow:SetCollapsed(false)
      content:Show()
      f:SetHeight(26 + GAP + content:GetHeight())
    end
  end

  header:SetScript("OnClick", function()
    collapsed = not collapsed
    UpdateState()
    if refreshFn then refreshFn() end
  end)

  header:SetScript("OnEnter", function() hBg:SetColorTexture(cr, cg, cb, 0.10) end)
  header:SetScript("OnLeave", function() hBg:SetColorTexture(cr, cg, cb, 0.06) end)

  UpdateState()

  local function GetHeight()
    if collapsed then return 26 end
    return 26 + GAP + content:GetHeight()
  end

  local function RefreshGroup()
    M:RefreshLayout(content, childWidgets)
    UpdateState()
  end

  return { frame = f, height = GetHeight(), refresh = RefreshGroup, _getHeight = GetHeight, _childWidgets = childWidgets }
end

-- ============================================================================
-- SEARCH HELPERS
-- ============================================================================

local function NormalizeSearch(s)
  if not s or type(s) ~= "string" then return "" end
  s = s:lower()
  s = s:gsub("\195(.)", function(b)
    local c = string.byte(b)
    if c >= 160 and c <= 164 or c >= 128 and c <= 132 then return "a" end
    if c >= 168 and c <= 171 or c >= 136 and c <= 139 then return "e" end
    if c >= 172 and c <= 175 or c >= 140 and c <= 143 then return "i" end
    if c >= 178 and c <= 182 or c >= 146 and c <= 150 then return "o" end
    if c >= 185 and c <= 188 or c >= 153 and c <= 156 then return "u" end
    if c == 167 or c == 135 then return "c" end
    if c == 177 or c == 145 then return "n" end
    return ""
  end)
  return s
end
M.NormalizeSearch = NormalizeSearch

local function ExtractSearchLabels(specs)
  local labels = {}
  for _, spec in ipairs(specs) do
    if spec.label then
      if type(spec.label) == "table" then
        for _, lbl in ipairs(spec.label) do
          if type(lbl) == "string" then labels[#labels + 1] = NormalizeSearch(lbl) end
        end
      else
        labels[#labels + 1] = NormalizeSearch(spec.label)
      end
    end
    if spec.text then labels[#labels + 1] = NormalizeSearch(spec.text) end
    if spec.values then
      for _, v in ipairs(spec.values) do
        if v.text then labels[#labels + 1] = NormalizeSearch(v.text) end
      end
    end
    if spec.items then
      for _, item in ipairs(spec.items) do
        if item.label then labels[#labels + 1] = NormalizeSearch(item.label) end
      end
    end
    if spec.children then
      local childLabels = ExtractSearchLabels(spec.children)
      for _, l in ipairs(childLabels) do labels[#labels + 1] = l end
    end
    if spec.tabs then
      for _, tab in ipairs(spec.tabs) do
        if tab.label then labels[#labels + 1] = NormalizeSearch(tab.label) end
        if tab.children then
          local childLabels = ExtractSearchLabels(tab.children)
          for _, l in ipairs(childLabels) do labels[#labels + 1] = l end
        end
      end
    end
  end
  return labels
end

M._pageSearchData = M._pageSearchData or {}

function M:PageHasMatches(pageId, normalizedTerm)
  if not normalizedTerm or normalizedTerm == "" then return true end
  local labels = self._pageSearchData[pageId]
  if not labels then return true end
  for _, l in ipairs(labels) do
    if string.find(l, normalizedTerm, 1, true) then return true end
  end
  return false
end

function M:FindFirstMatchingPage(normalizedTerm)
  if not normalizedTerm or normalizedTerm == "" then return nil end
  for _, page in ipairs(self._pageOrder or {}) do
    local labels = self._pageSearchData[page.id]
    if labels then
      for _, l in ipairs(labels) do
        if string.find(l, normalizedTerm, 1, true) then return page.id end
      end
    end
  end
  return nil
end

-- ============================================================================
-- BUILD OPTIONS
-- ============================================================================

function M:BuildOptions(host, specs, refreshFn)
  if refreshFn then
    M._pageRefreshFn = refreshFn
    host._refreshFn = refreshFn
  end

  local db = BravLib.Storage.GetDB()
  local widgets = {}
  local y = 0

  for _, spec in ipairs(specs) do
    local builder = BUILDERS[spec.type]
    if builder then
      local w = builder(host, spec, refreshFn)
      w.spec = spec

      local isHidden = spec.hidden and db and spec.hidden(db)
      if isHidden then
        w.frame:Hide()
      else
        w.frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
        w.frame:SetPoint("RIGHT", host, "RIGHT", 0, 0)
        local h = w._getHeight and w._getHeight() or w.height
        y = y + h + GAP
      end

      widgets[#widgets + 1] = w
    end
  end

  host:SetHeight(math.max(y, 1))

  if M._activePage then
    M._pageSearchData = M._pageSearchData or {}
    M._pageSearchData[M._activePage] = ExtractSearchLabels(specs)
  end

  return y, widgets
end

-- ============================================================================
-- REFRESH LAYOUT
-- ============================================================================

local function WidgetMatchesSearch(spec, searchTerm)
  if not searchTerm then return true end
  local label = spec.label or spec.text
  if label and string.find(NormalizeSearch(label), searchTerm, 1, true) then return true end
  if spec.values then
    for _, v in ipairs(spec.values) do
      if v.text and string.find(NormalizeSearch(v.text), searchTerm, 1, true) then return true end
    end
  end
  if spec.items then
    for _, item in ipairs(spec.items) do
      if item.label and string.find(NormalizeSearch(item.label), searchTerm, 1, true) then return true end
    end
  end
  return false
end

local function GroupMatchesSearch(w, searchTerm)
  if not searchTerm then return true end
  if w.spec.label and string.find(NormalizeSearch(w.spec.label), searchTerm, 1, true) then return true end
  if w._childWidgets then
    for _, child in ipairs(w._childWidgets) do
      if WidgetMatchesSearch(child.spec, searchTerm) then return true end
    end
  end
  if w.spec.tabs then
    for _, tab in ipairs(w.spec.tabs) do
      if tab.label and string.find(NormalizeSearch(tab.label), searchTerm, 1, true) then return true end
      if tab.children then
        for _, childSpec in ipairs(tab.children) do
          if WidgetMatchesSearch(childSpec, searchTerm) then return true end
        end
      end
    end
  end
  return false
end

function M:RefreshLayout(host, widgets)
  local db = BravLib.Storage.GetDB()
  local searchTerm = M._searchTerm
  local y = 0

  local headerVisible = {}
  if searchTerm then
    local currentHeader
    for _, w in ipairs(widgets) do
      local t = w.spec.type
      if t == "header" then
        currentHeader = w
        headerVisible[w] = false
      elseif currentHeader then
        local matches = false
        if t == "group" or t == "subtabs" then
          matches = GroupMatchesSearch(w, searchTerm)
        elseif t ~= "divider" and t ~= "separator" then
          matches = WidgetMatchesSearch(w.spec, searchTerm)
        end
        if matches then headerVisible[currentHeader] = true end
      end
    end
  end

  for _, w in ipairs(widgets) do
    local t = w.spec.type
    local isHidden = w.spec.hidden and db and w.spec.hidden(db)

    if not isHidden and searchTerm then
      if t == "header" then
        isHidden = not headerVisible[w]
      elseif t == "divider" or t == "separator" then
        isHidden = true
      elseif t == "group" or t == "subtabs" then
        isHidden = not GroupMatchesSearch(w, searchTerm)
      else
        isHidden = not WidgetMatchesSearch(w.spec, searchTerm)
      end
    end

    if isHidden then
      w.frame:Hide()
    else
      w.frame:ClearAllPoints()
      local indent = w.spec.indent
      if indent == "half" then
        w.frame:SetPoint("TOP", host, "TOP", 0, -y)
        w.frame:SetPoint("LEFT", host, "CENTER", 0, 0)
      else
        w.frame:SetPoint("TOPLEFT", host, "TOPLEFT", indent or 0, -y)
      end
      w.frame:SetPoint("RIGHT", host, "RIGHT", 0, 0)
      w.frame:Show()

      if w.refresh then w.refresh() end

      local h = w._getHeight and w._getHeight() or w.height
      y = y + h + GAP
    end
  end

  host:SetHeight(math.max(y, 1))
end

-- ============================================================================
-- SPLIT SPECS BY HEADER
-- ============================================================================

local function SplitSpecsByHeader(specs)
  local tabs = {}
  local current = nil

  for _, spec in ipairs(specs) do
    if spec.type == "header" then
      current = { label = spec.label, specs = {} }
      tabs[#tabs + 1] = current
    else
      if not current then
        current = { label = "General", specs = {} }
        tabs[#tabs + 1] = current
      end
      current.specs[#current.specs + 1] = spec
    end
  end

  return tabs
end

local function CountHeaders(specs)
  local n = 0
  for _, spec in ipairs(specs) do
    if spec.type == "header" then n = n + 1 end
  end
  return n
end

-- ============================================================================
-- TAB BUTTON FACTORY
-- ============================================================================

local TAB_H = 26

local function CreateTabBtn(parent, text, fontSize)
  local btn = CreateFrame("Button", nil, parent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  btn:SetHeight(TAB_H)
  btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })

  local label = btn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, fontSize or 10, "OUTLINE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  btn._label = label

  local textW = label:GetStringWidth() or 0
  if textW < 5 then textW = #text * 7 end
  btn:SetWidth(math.max(textW + 16, 42))

  function btn:SetActive(isActive)
    local r, g, b = M:GetClassColor()
    if isActive then
      self:SetBackdropColor(r * 0.15, g * 0.15, b * 0.15, 0.90)
      self:SetBackdropBorderColor(r, g, b, 0.60)
      self._label:SetTextColor(r, g, b, 1)
    else
      self:SetBackdropColor(unpack(T.BTN))
      self:SetBackdropBorderColor(unpack(T.BORDER))
      self._label:SetTextColor(unpack(T.TEXT))
    end
  end

  return btn
end

-- ============================================================================
-- RECYCLER
-- ============================================================================

local _recycler = _recycler or CreateFrame("Frame")
_recycler:Hide()

local function ClearHost(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    child:Hide()
    child:ClearAllPoints()
    child:SetParent(_recycler)
  end
end

-- ============================================================================
-- SUBTABS
-- ============================================================================

local SUBTAB_H = 26

local function CreateSubTabBtn(parent, text)
  local btn = CreateFrame("Button", nil, parent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  btn:SetHeight(SUBTAB_H)
  btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })

  local label = btn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 9, "OUTLINE")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  btn._label = label

  local textW = label:GetStringWidth() or 0
  if textW < 5 then textW = #text * 7 end
  btn:SetWidth(math.max(textW + 16, 42))

  function btn:SetActive(isActive)
    local r, g, b = M:GetClassColor()
    if isActive then
      self:SetBackdropColor(r * 0.15, g * 0.15, b * 0.15, 0.90)
      self:SetBackdropBorderColor(r, g, b, 0.60)
      self._label:SetTextColor(r, g, b, 1)
    else
      self:SetBackdropColor(unpack(T.BTN))
      self:SetBackdropBorderColor(unpack(T.BORDER))
      self._label:SetTextColor(unpack(T.TEXT))
    end
  end

  return btn
end

function BUILDERS.subtabs(parent, spec, refreshFn)
  local f = CreateFrame("Frame", nil, parent)

  local tabBar = CreateFrame("Frame", nil, f)
  tabBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  tabBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  tabBar:SetHeight(SUBTAB_H)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
  content:SetPoint("RIGHT", f, "RIGHT", 0, 0)

  local OVERHEAD = SUBTAB_H + 8

  local activeIdx = 1
  local currentWidgets = nil
  local tabs = spec.tabs or {}

  local function UpdateHeight()
    local contentH = content:GetHeight()
    f:SetHeight(OVERHEAD + contentH)
  end

  local function DoRefresh()
    if currentWidgets then
      M:RefreshLayout(content, currentWidgets)
    end
    UpdateHeight()
    if refreshFn then refreshFn() end
  end

  local function BuildSubTabContent()
    ClearHost(content)
    local tab = tabs[activeIdx]
    if not tab or not tab.children then
      content:SetHeight(1)
      UpdateHeight()
      return
    end

    local totalH
    totalH, currentWidgets = M:BuildOptions(content, tab.children, DoRefresh)
    content:SetHeight(math.max(totalH, 1))
    UpdateHeight()
  end

  local tabBtns = {}
  local x = 0
  for i, tab in ipairs(tabs) do
    local btn = CreateSubTabBtn(tabBar, tab.label or ("Tab " .. i))
    btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
    btn._tabIdx = i

    btn:SetScript("OnEnter", function(self)
      if activeIdx ~= self._tabIdx then
        self:SetBackdropColor(unpack(T.BTN_HOVER))
        self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
      end
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetActive(activeIdx == self._tabIdx)
    end)
    btn:SetScript("OnClick", function(self)
      activeIdx = self._tabIdx
      for _, b in ipairs(tabBtns) do
        b:SetActive(b._tabIdx == activeIdx)
      end
      BuildSubTabContent()
    end)

    x = x + btn:GetWidth() + 2
    tabBtns[#tabBtns + 1] = btn
  end

  for _, b in ipairs(tabBtns) do
    b:SetActive(b._tabIdx == 1)
  end
  BuildSubTabContent()

  local function GetHeight()
    return OVERHEAD + content:GetHeight()
  end

  local function RefreshSubtabs()
    if currentWidgets then
      M:RefreshLayout(content, currentWidgets)
    end
    UpdateHeight()
  end

  local allChildWidgets = {}
  if currentWidgets then
    for _, w in ipairs(currentWidgets) do
      allChildWidgets[#allChildWidgets + 1] = w
    end
  end

  return { frame = f, height = GetHeight(), refresh = RefreshSubtabs, _getHeight = GetHeight, _childWidgets = allChildWidgets }
end

-- ============================================================================
-- REGISTER PAGE WRAPPER
-- ============================================================================

local _origRegisterPage = M.RegisterPage

function M:RegisterPage(id, order, title, buildOrSpecs, opts)
  if type(buildOrSpecs) == "table" then
    local specs = buildOrSpecs

    M._pageSearchData = M._pageSearchData or {}
    M._pageSearchData[id] = ExtractSearchLabels(specs)

    local onChanged = opts and opts.onChanged
    local noTabs = opts and opts.noTabs
    local numHeaders = CountHeaders(specs)

    if numHeaders <= 1 or noTabs then
      local buildFn = function(container, add)
        local host = CreateFrame("Frame", nil, container)
        host:SetPoint("TOPLEFT", container, "TOPLEFT", T.PAD, -T.PAD)
        host:SetPoint("TOPRIGHT", container, "TOPRIGHT", -T.PAD, -T.PAD)
        add(host)

        local widgets
        local totalH

        local function DoRefresh()
          M:RefreshLayout(host, widgets)
          local newH = host:GetHeight() + T.PAD * 2
          container:SetHeight(newH)
          local scrollChild = container:GetParent()
          if scrollChild and scrollChild.SetHeight then scrollChild:SetHeight(newH) end
          if not M._searchTerm and onChanged then onChanged() end
        end

        totalH, widgets = M:BuildOptions(host, specs, DoRefresh)
        host:SetHeight(math.max(totalH, 1))
        local initH = host:GetHeight() + T.PAD * 2
        container:SetHeight(initH)
        local scrollChild = container:GetParent()
        if scrollChild and scrollChild.SetHeight then scrollChild:SetHeight(initH) end
      end

      _origRegisterPage(self, id, order, title, buildFn, opts)
      return
    end

    local buildFn = function(container, add)
      local PAD = T.PAD
      local tabSections = SplitSpecsByHeader(specs)

      local hasAnySubtabs = false
      for _, section in ipairs(tabSections) do
        if section.specs[1] and section.specs[1].type == "subtabs" then
          hasAnySubtabs = true
          break
        end
      end

      local tabBar = CreateFrame("Frame", nil, container)
      tabBar:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, -PAD)
      tabBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -PAD, -PAD)
      tabBar:SetHeight(TAB_H)
      add(tabBar)

      local sep = container:CreateTexture(nil, "ARTWORK")
      sep:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
      sep:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -4)
      sep:SetHeight(1)
      local r, g, b = M:GetClassColor()
      sep:SetColorTexture(r, g, b, 0.35)

      local settingsBar, settingsBtns
      if hasAnySubtabs then
        settingsBar = CreateFrame("Frame", nil, container)
        settingsBar:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)
        settingsBar:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -4)
        settingsBar:SetHeight(TAB_H)
        settingsBtns = {}
      end

      local host = CreateFrame("Frame", nil, container)
      if settingsBar then
        host:SetPoint("TOPLEFT", settingsBar, "BOTTOMLEFT", 0, -8)
        host:SetPoint("TOPRIGHT", settingsBar, "BOTTOMRIGHT", 0, -8)
      else
        host:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -8)
        host:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -8)
      end
      add(host)

      local OVERHEAD_NORMAL  = PAD + TAB_H + 4 + 1 + 8
      local OVERHEAD_SUBTABS = PAD + TAB_H + 4 + 1 + 4 + TAB_H + 8

      local activeIdx = 1
      local activeSubIdx = 1
      local currentWidgets = nil
      local usingSubtabs = false

      local function UpdateHeight()
        local oh = usingSubtabs and OVERHEAD_SUBTABS or OVERHEAD_NORMAL
        local contentH = host:GetHeight()
        local totalH = oh + contentH + PAD
        container:SetHeight(math.max(totalH, 1))
        local scrollChild = container:GetParent()
        if scrollChild and scrollChild.SetHeight then scrollChild:SetHeight(math.max(totalH, 1)) end
      end

      local function DoRefresh()
        if currentWidgets then
          M:RefreshLayout(host, currentWidgets)
        end
        UpdateHeight()
        if not M._searchTerm and onChanged then onChanged() end
      end

      local function ClearSettingsBtns()
        if not settingsBtns then return end
        for _, btn in ipairs(settingsBtns) do
          btn:Hide()
          btn:ClearAllPoints()
          btn:SetParent(_recycler)
        end
        wipe(settingsBtns)
      end

      local _activeSubTabs
      local function BuildSubContent()
        ClearHost(host)
        local tab = _activeSubTabs and _activeSubTabs[activeSubIdx]
        if tab and tab.children then
          local totalH
          totalH, currentWidgets = M:BuildOptions(host, tab.children, DoRefresh)
          host:SetHeight(math.max(totalH, 1))
        else
          currentWidgets = nil
          host:SetHeight(1)
        end
        UpdateHeight()
      end

      local function BuildSettingsTabBtns(subtabSpec)
        ClearSettingsBtns()
        activeSubIdx = 1
        _activeSubTabs = subtabSpec.tabs or {}

        local btnX = 0
        for i, tab in ipairs(_activeSubTabs) do
          local btn = CreateTabBtn(settingsBar, tab.label, 9)
          btn._subIdx = i

          btn:SetScript("OnEnter", function(self)
            if activeSubIdx ~= self._subIdx then
              self:SetBackdropColor(unpack(T.BTN_HOVER))
              self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
            end
          end)
          btn:SetScript("OnLeave", function(self)
            self:SetActive(activeSubIdx == self._subIdx)
          end)
          btn:SetScript("OnClick", function(self)
            activeSubIdx = self._subIdx
            for _, b in ipairs(settingsBtns) do b:SetActive(b._subIdx == activeSubIdx) end
            BuildSubContent()
          end)

          btn:SetPoint("TOPLEFT", settingsBar, "TOPLEFT", btnX, 0)
          btnX = btnX + btn:GetWidth() + 2
          settingsBtns[#settingsBtns + 1] = btn
        end

        for _, b in ipairs(settingsBtns) do b:SetActive(b._subIdx == activeSubIdx) end
        BuildSubContent()
      end

      local function BuildTabContent()
        ClearHost(host)
        local section = tabSections[activeIdx]
        if not section then return end

        if section.specs[1] and section.specs[1].type == "subtabs" and settingsBar then
          usingSubtabs = true
          settingsBar:Show()
          host:ClearAllPoints()
          host:SetPoint("TOPLEFT", settingsBar, "BOTTOMLEFT", 0, -8)
          host:SetPoint("TOPRIGHT", settingsBar, "BOTTOMRIGHT", 0, -8)
          BuildSettingsTabBtns(section.specs[1])
        else
          usingSubtabs = false
          _activeSubTabs = nil
          if settingsBar then
            settingsBar:Hide()
            ClearSettingsBtns()
            host:ClearAllPoints()
            host:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -8)
            host:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -8)
          end
          local totalH
          totalH, currentWidgets = M:BuildOptions(host, section.specs, DoRefresh)
          host:SetHeight(math.max(totalH, 1))
          UpdateHeight()
        end
      end

      local tabBtns = {}
      local x = 0
      for i, section in ipairs(tabSections) do
        local btn = CreateTabBtn(tabBar, section.label)
        btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
        btn._tabIdx = i

        btn:SetScript("OnEnter", function(self)
          if activeIdx ~= self._tabIdx then
            self:SetBackdropColor(unpack(T.BTN_HOVER))
            self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
          end
        end)
        btn:SetScript("OnLeave", function(self)
          self:SetActive(activeIdx == self._tabIdx)
        end)
        btn:SetScript("OnClick", function(self)
          activeIdx = self._tabIdx
          for _, b in ipairs(tabBtns) do
            b:SetActive(b._tabIdx == activeIdx)
          end
          BuildTabContent()
          local scroll = container:GetParent() and container:GetParent():GetParent()
          if scroll and scroll.SetVerticalScroll then
            scroll:SetVerticalScroll(0)
          end
        end)

        x = x + btn:GetWidth() + 2
        tabBtns[#tabBtns + 1] = btn
      end

      for _, b in ipairs(tabBtns) do
        b:SetActive(b._tabIdx == 1)
      end
      BuildTabContent()
    end

    _origRegisterPage(self, id, order, title, buildFn, opts)
  else
    _origRegisterPage(self, id, order, title, buildOrSpecs, opts)
  end
end

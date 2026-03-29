-- BravUI/Core/Move.lua
-- Global edit mode: /bravmove toggles unlock mode for registered frames
-- Snap, grid, control panel, category filters

local BravUI = BravUI

local TEX  = "Interface/Buttons/WHITE8x8"

local function GetFont()
  return BravLib.Media.Get("font", "default") or STANDARD_TEXT_FONT
end

local function GetClassColor()
  return BravUI.Utils.GetClassColor("player")
end

-- ============================================================================
-- REGISTRY
-- ============================================================================

local _registry = {}
local _active = false
local _activeInputPanel = nil

BravUI.Mover = {}
BravUI.Move  = {}
local Mover = BravUI.Mover

local _ufRegistered = false
local EnsureUFRegistered

-- ============================================================================
-- SNAP / MAGNETISM
-- ============================================================================

local SNAP_THRESHOLD = 10
local _guideH, _guideV

-- ============================================================================
-- GRID
-- ============================================================================

local GRID_SIZE = 64
local _gridLines = {}
local _gridVisible = true
local _gridCreated = false

local function CreateGrid()
  if _gridCreated then return end
  _gridCreated = true

  local cr, cg, cb = GetClassColor()
  local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
  local centerX, centerY = pw / 2, ph / 2

  local function AddLine(isVertical, offset, isCenter)
    local line = UIParent:CreateTexture(nil, "BACKGROUND", nil, -7)
    line:SetTexture(TEX)
    line:SetVertexColor(cr, cg, cb, isCenter and 0.35 or 0.12)
    if isVertical then
      line:SetWidth(1)
      line:SetPoint("BOTTOM", UIParent, "BOTTOM", offset, 0)
      line:SetPoint("TOP", UIParent, "TOP", offset, 0)
    else
      line:SetHeight(1)
      line:SetPoint("LEFT", UIParent, "LEFT", 0, offset)
      line:SetPoint("RIGHT", UIParent, "RIGHT", 0, offset)
    end
    line:Hide()
    _gridLines[#_gridLines + 1] = line
  end

  AddLine(true, 0, true)
  for i = 1, math.ceil(centerX / GRID_SIZE) do
    AddLine(true, i * GRID_SIZE, false)
    AddLine(true, -i * GRID_SIZE, false)
  end
  AddLine(false, 0, true)
  for i = 1, math.ceil(centerY / GRID_SIZE) do
    AddLine(false, i * GRID_SIZE, false)
    AddLine(false, -i * GRID_SIZE, false)
  end
end

local function ShowGrid()
  CreateGrid()
  for _, line in ipairs(_gridLines) do line:Show() end
  _gridVisible = true
end

local function HideGrid()
  for _, line in ipairs(_gridLines) do line:Hide() end
  _gridVisible = false
end

local function ToggleGrid()
  if _gridVisible then HideGrid() else ShowGrid() end
end

-- ============================================================================
-- GUIDE LINES
-- ============================================================================

local function EnsureGuides()
  if _guideV then return end
  local cr, cg, cb = GetClassColor()

  _guideV = UIParent:CreateTexture(nil, "OVERLAY", nil, 7)
  _guideV:SetTexture(TEX)
  _guideV:SetVertexColor(cr, cg, cb, 0.6)
  _guideV:SetWidth(1)
  _guideV:Hide()

  _guideH = UIParent:CreateTexture(nil, "OVERLAY", nil, 7)
  _guideH:SetTexture(TEX)
  _guideH:SetVertexColor(cr, cg, cb, 0.6)
  _guideH:SetHeight(1)
  _guideH:Hide()
end

local function ShowGuideV(screenX)
  EnsureGuides()
  _guideV:ClearAllPoints()
  _guideV:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", screenX, 0)
  _guideV:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenX, UIParent:GetHeight())
  _guideV:Show()
end

local function ShowGuideH(screenY)
  EnsureGuides()
  _guideH:ClearAllPoints()
  _guideH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, screenY)
  _guideH:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", UIParent:GetWidth(), screenY)
  _guideH:Show()
end

local function HideGuides()
  if _guideV then _guideV:Hide() end
  if _guideH then _guideH:Hide() end
end

-- ============================================================================
-- SNAP HELPERS
-- ============================================================================

local function CollectSnapEdges(excludeName)
  local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
  local xEdges = { 0, pw, pw / 2 }
  local yEdges = { 0, ph, ph / 2 }

  for name, entry in pairs(_registry) do
    if name ~= excludeName and entry.overlay and entry.overlay:IsShown() then
      local ov = entry.overlay
      local l, r = ov:GetLeft(), ov:GetRight()
      local b, t = ov:GetBottom(), ov:GetTop()
      if l and r and b and t then
        xEdges[#xEdges + 1] = l
        xEdges[#xEdges + 1] = r
        xEdges[#xEdges + 1] = (l + r) / 2
        yEdges[#yEdges + 1] = b
        yEdges[#yEdges + 1] = t
        yEdges[#yEdges + 1] = (b + t) / 2
      end
    end
  end
  return xEdges, yEdges
end

local function FindClosest(val, edges, threshold)
  local best, bestDist
  for i = 1, #edges do
    local d = math.abs(val - edges[i])
    if d < threshold and (not bestDist or d < bestDist) then
      best, bestDist = edges[i], d
    end
  end
  return best, bestDist
end

local function SnapAxisX(wantCenterX, halfW, xEdges)
  local sL, dL = FindClosest(wantCenterX - halfW, xEdges, SNAP_THRESHOLD)
  local sR, dR = FindClosest(wantCenterX + halfW, xEdges, SNAP_THRESHOLD)
  local sC, dC = FindClosest(wantCenterX, xEdges, SNAP_THRESHOLD)

  local best, bestD, guideX
  if sL and (not bestD or dL < bestD) then best, bestD, guideX = sL + halfW, dL, sL end
  if sR and (not bestD or dR < bestD) then best, bestD, guideX = sR - halfW, dR, sR end
  if sC and (not bestD or dC < bestD) then best, bestD, guideX = sC, dC, sC end
  return best, guideX
end

local function SnapAxisY(wantCenterY, halfH, yEdges)
  local sB, dB = FindClosest(wantCenterY - halfH, yEdges, SNAP_THRESHOLD)
  local sT, dT = FindClosest(wantCenterY + halfH, yEdges, SNAP_THRESHOLD)
  local sC, dC = FindClosest(wantCenterY, yEdges, SNAP_THRESHOLD)

  local best, bestD, guideY
  if sB and (not bestD or dB < bestD) then best, bestD, guideY = sB + halfH, dB, sB end
  if sT and (not bestD or dT < bestD) then best, bestD, guideY = sT - halfH, dT, sT end
  if sC and (not bestD or dC < bestD) then best, bestD, guideY = sC, dC, sC end
  return best, guideY
end

-- ============================================================================
-- OVERLAY VISUAL BOUNDS HELPER
-- ============================================================================

local function AnchorOverlayToVisual(ov, fr)
  local s = fr:GetScale() or 1
  ov:ClearAllPoints()
  if math.abs(s - 1) < 0.001 then
    ov:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
    ov:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
    return
  end
  ov:SetSize(fr:GetWidth() * s, fr:GetHeight() * s)
  local point, relTo, relPoint, px, py = fr:GetPoint()
  ov:SetPoint(point, relTo or UIParent, relPoint or point,
    (px or 0) * s, (py or 0) * s)
end

-- ============================================================================
-- REGISTRY API
-- ============================================================================

function Mover:Register(name, frame, dbFunc, defaults, opts)
  if not name or not frame then return end
  _registry[name] = {
    frame = frame,
    coverFrame = opts and opts.coverFrame,
    dbFunc = dbFunc,
    defaults = defaults or { x = 0, y = 0 },
    onSave   = opts and opts.onSave,
    onReset  = opts and opts.onReset,
    category = opts and opts.category or "divers",
    menuPage = opts and opts.menuPage,
    overlay  = nil,
  }

  if _active then
    self:ShowOverlay(name)
  end
end

function Mover:Unregister(name)
  if not _registry[name] then return end
  self:HideOverlay(name)
  _registry[name] = nil
end

function Mover:UpdateCoverFrame(name, newFrame)
  if _registry[name] then
    _registry[name].coverFrame = newFrame
  end
end

-- ============================================================================
-- OVERLAY CREATION
-- ============================================================================

local function CreateOverlay(entry, name)
  local frame = entry.frame
  if not frame then return nil end

  local cr, cg, cb = GetClassColor()
  local FONT = GetFont()

  local ov = CreateFrame("Frame", "BravUI_Mover_" .. name:gsub("%s", ""), UIParent)
  ov:SetFrameStrata("FULLSCREEN_DIALOG")
  ov:SetFrameLevel(500)
  ov:EnableMouse(true)
  ov:SetMovable(true)
  ov:SetClampedToScreen(true)

  local cover = entry.coverFrame or frame
  AnchorOverlayToVisual(ov, cover)
  ov._cover = cover

  -- Background
  local bg = ov:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX)
  bg:SetVertexColor(0, 0, 0, 0.7)
  bg:SetAllPoints()

  -- Borders (2px class color)
  local BW = 2
  local function MakeBorder(point1, point2, isHoriz)
    local t = ov:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX)
    t:SetVertexColor(cr, cg, cb, 1)
    if isHoriz then
      t:SetHeight(BW)
      t:SetPoint("TOPLEFT", ov, point1, 0, 0)
      t:SetPoint("TOPRIGHT", ov, point2, 0, 0)
    else
      t:SetWidth(BW)
      t:SetPoint("TOPLEFT", ov, point1, 0, 0)
      t:SetPoint("BOTTOMLEFT", ov, point2, 0, 0)
    end
    return t
  end
  MakeBorder("TOPLEFT", "TOPRIGHT", true)
  MakeBorder("BOTTOMLEFT", "BOTTOMRIGHT", true)
  MakeBorder("TOPLEFT", "BOTTOMLEFT", false)
  local r = ov:CreateTexture(nil, "OVERLAY", nil, 7)
  r:SetTexture(TEX); r:SetVertexColor(cr, cg, cb, 1); r:SetWidth(BW)
  r:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 0, 0)
  r:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", 0, 0)

  -- Label
  local label = ov:CreateFontString(nil, "OVERLAY")
  pcall(label.SetFont, label, FONT, 11, "OUTLINE")
  label:SetPoint("CENTER", ov, "CENTER", 0, 0)
  label:SetText(name)
  label:SetTextColor(cr, cg, cb, 1)
  ov._label = label

  -- ========================================================================
  -- INPUT PANEL (X/Y + Reset)
  -- ========================================================================
  local PANEL_W, PANEL_H = 170, 48
  local panel = CreateFrame("Frame", nil, ov)
  panel:SetSize(PANEL_W, PANEL_H)
  panel:SetPoint("TOP", ov, "BOTTOM", 0, -4)
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(501)
  panel:EnableMouse(true)

  local pBg = panel:CreateTexture(nil, "BACKGROUND")
  pBg:SetTexture(TEX); pBg:SetVertexColor(0.06, 0.06, 0.06, 0.92); pBg:SetAllPoints()

  local function PanelBorder(p1, p2, w, h)
    local t = panel:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX); t:SetVertexColor(cr, cg, cb, 0.7)
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  PanelBorder("TOPLEFT", "TOPRIGHT", nil, 1)
  PanelBorder("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  PanelBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)
  PanelBorder("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

  local function MakeEditBox(parent, labelText, anchorPoint, anchorTo, anchorRel, ox, oy)
    local lbl = parent:CreateFontString(nil, "OVERLAY")
    pcall(lbl.SetFont, lbl, FONT, 10, "OUTLINE")
    lbl:SetPoint(anchorPoint, anchorTo, anchorRel, ox, oy)
    lbl:SetText(labelText)
    lbl:SetTextColor(0.7, 0.7, 0.7, 1)

    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(50, 18)
    eb:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
    eb:SetAutoFocus(false)
    pcall(eb.SetFont, eb, FONT, 10, "")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetNumeric(false)
    eb:SetMaxLetters(7)

    local ebBg = eb:CreateTexture(nil, "BACKGROUND")
    ebBg:SetTexture(TEX); ebBg:SetVertexColor(0.12, 0.12, 0.12, 1); ebBg:SetAllPoints()

    local function EBBorder(p1, p2, w, h)
      local t = eb:CreateTexture(nil, "OVERLAY")
      t:SetTexture(TEX); t:SetVertexColor(0.3, 0.3, 0.3, 1)
      t:SetPoint(p1); t:SetPoint(p2)
      if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    EBBorder("TOPLEFT", "TOPRIGHT", nil, 1)
    EBBorder("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    EBBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)
    EBBorder("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    eb:HookScript("OnEditFocusGained", function(self)
      for _, region in pairs({ self:GetRegions() }) do
        if region.GetDrawLayer and region:GetDrawLayer() == "OVERLAY" then
          region:SetVertexColor(cr, cg, cb, 1)
        end
      end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
      for _, region in pairs({ self:GetRegions() }) do
        if region.GetDrawLayer and region:GetDrawLayer() == "OVERLAY" then
          region:SetVertexColor(0.3, 0.3, 0.3, 1)
        end
      end
    end)

    return eb
  end

  local ebX = MakeEditBox(panel, "X", "LEFT", panel, "TOPLEFT", 8, -14)
  local ebY = MakeEditBox(panel, "Y", "LEFT", panel, "TOP", 5, -14)
  ov._ebX = ebX
  ov._ebY = ebY

  local function GetCurrentCoords()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local fs = frame:GetScale() or 1
    local point, _, relPoint, px, py = frame:GetPoint()
    if point == "CENTER" and relPoint == "CENTER" and px and py then
      return math.floor(px * fs + 0.5), math.floor(py * fs + 0.5)
    end
    local left   = frame:GetLeft()
    local bottom = frame:GetBottom()
    if left and bottom then
      local cx = math.floor((left + frame:GetWidth() / 2) * fs - pw / 2 + 0.5)
      local cy = math.floor((bottom + frame:GetHeight() / 2) * fs - ph / 2 + 0.5)
      return cx, cy
    end
    return 0, 0
  end

  local function UpdateCoords()
    local cx, cy = GetCurrentCoords()
    ebX:SetText(tostring(cx))
    ebY:SetText(tostring(cy))
  end
  ov._updateCoords = UpdateCoords

  local function ApplyFromInputs()
    local nx = tonumber(ebX:GetText())
    local ny = tonumber(ebY:GetText())
    if not nx or not ny then return end

    local fs = frame:GetScale() or 1
    frame._moverDragging = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", nx / fs, ny / fs)
    frame._moverDragging = nil
    AnchorOverlayToVisual(ov, cover)
    Mover:SavePosition(name)
  end

  ebX:SetScript("OnEnterPressed", function(self) ApplyFromInputs(); self:ClearFocus() end)
  ebY:SetScript("OnEnterPressed", function(self) ApplyFromInputs(); self:ClearFocus() end)
  ebX:SetScript("OnTabPressed", function(self) ApplyFromInputs(); ebY:SetFocus() end)
  ebY:SetScript("OnTabPressed", function(self) ApplyFromInputs(); ebX:SetFocus() end)
  ebX:SetScript("OnEscapePressed", function(self) UpdateCoords(); self:ClearFocus() end)
  ebY:SetScript("OnEscapePressed", function(self) UpdateCoords(); self:ClearFocus() end)

  -- Reset button
  local resetBtn = CreateFrame("Button", nil, panel)
  resetBtn:SetSize(PANEL_W - 16, 16)
  resetBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 4)

  local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
  resetBg:SetTexture(TEX); resetBg:SetVertexColor(0.15, 0.15, 0.15, 1); resetBg:SetAllPoints()

  local resetTxt = resetBtn:CreateFontString(nil, "OVERLAY")
  pcall(resetTxt.SetFont, resetTxt, FONT, 9, "OUTLINE")
  resetTxt:SetPoint("CENTER")
  resetTxt:SetText("Reset")
  resetTxt:SetTextColor(0.8, 0.8, 0.8, 1)

  resetBtn:SetScript("OnEnter", function() resetTxt:SetTextColor(cr, cg, cb, 1) end)
  resetBtn:SetScript("OnLeave", function() resetTxt:SetTextColor(0.8, 0.8, 0.8, 1) end)
  resetBtn:SetScript("OnClick", function()
    Mover:ResetPosition(name)
    UpdateCoords()
  end)

  UpdateCoords()

  -- Panel hover show/hide
  panel:Hide()
  local hideTimer = nil

  local function CancelHide()
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
  end

  local function ScheduleHide()
    CancelHide()
    hideTimer = C_Timer.NewTimer(0.15, function()
      hideTimer = nil
      if not panel:IsMouseOver() and not ov:IsMouseOver() then
        panel:Hide()
      end
    end)
  end

  ov:SetScript("OnEnter", function()
    CancelHide()
    if _activeInputPanel and _activeInputPanel ~= panel then
      _activeInputPanel:Hide()
    end
    _activeInputPanel = panel
    panel:ClearAllPoints()
    local bottom = ov:GetBottom()
    if bottom and bottom < 60 then
      panel:SetPoint("BOTTOM", ov, "TOP", 0, 4)
    else
      panel:SetPoint("TOP", ov, "BOTTOM", 0, -4)
    end
    panel:Show()
  end)
  ov:SetScript("OnLeave", ScheduleHide)
  panel:SetScript("OnEnter", CancelHide)
  panel:SetScript("OnLeave", ScheduleHide)

  -- ========================================================================
  -- DRAG HANDLERS (cursor-based with snap)
  -- ========================================================================
  ov:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not InCombatLockdown() then
      local scale = UIParent:GetEffectiveScale()
      local curX, curY = GetCursorPosition()
      self._initCurX = curX / scale
      self._initCurY = curY / scale

      local fs = frame:GetScale() or 1
      local point, _, relPoint, px, py = frame:GetPoint()
      if point == "CENTER" and relPoint == "CENTER" and px and py then
        self._initFrameX = px * fs
        self._initFrameY = py * fs
      else
        local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
        local fl = frame:GetLeft()
        local fb = frame:GetBottom()
        if fl and fb then
          self._initFrameX = (fl + frame:GetWidth() / 2) * fs - pw / 2
          self._initFrameY = (fb + frame:GetHeight() / 2) * fs - ph / 2
        else
          self._initFrameX = 0
          self._initFrameY = 0
        end
      end

      if not (point == "CENTER" and relPoint == "CENTER") then
        frame._moverDragging = true
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", self._initFrameX / fs, self._initFrameY / fs)
        frame._moverDragging = nil
      end

      self._dragging = true
    elseif button == "RightButton" then
      Mover:ResetPosition(name)
      UpdateCoords()
    end
  end)

  ov:SetScript("OnMouseUp", function(self)
    if self._dragging then
      self._dragging = false
      HideGuides()
      AnchorOverlayToVisual(self, cover)
      Mover:SavePosition(name)
      UpdateCoords()
    end
  end)

  ov:SetScript("OnUpdate", function(self)
    if not self._dragging then return end

    local scale = UIParent:GetEffectiveScale()
    local curX, curY = GetCursorPosition()
    local dx = curX / scale - self._initCurX
    local dy = curY / scale - self._initCurY

    local fx = self._initFrameX + dx
    local fy = self._initFrameY + dy

    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local cs = (cover or frame):GetScale() or 1
    local halfW = ((cover:GetWidth() or frame:GetWidth()) * cs) / 2
    local halfH = ((cover:GetHeight() or frame:GetHeight()) * cs) / 2

    local screenX = math.max(halfW, math.min(pw - halfW, fx + pw / 2))
    local screenY = math.max(halfH, math.min(ph - halfH, fy + ph / 2))

    local doSnap = (dx * dx + dy * dy) > 25
    local guideX, guideY
    if doSnap then
      local xEdges, yEdges = CollectSnapEdges(name)
      local snappedX, gx = SnapAxisX(screenX, halfW, xEdges)
      local snappedY, gy = SnapAxisY(screenY, halfH, yEdges)
      if snappedX then screenX = snappedX; guideX = gx end
      if snappedY then screenY = snappedY; guideY = gy end
    end

    local finalX = screenX - pw / 2
    local finalY = screenY - ph / 2

    local fs = frame:GetScale() or 1
    frame._moverDragging = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", finalX / fs, finalY / fs)
    frame._moverDragging = nil
    AnchorOverlayToVisual(self, cover)

    if guideX then ShowGuideV(guideX) else if _guideV then _guideV:Hide() end end
    if guideY then ShowGuideH(guideY) else if _guideH then _guideH:Hide() end end

    ebX:SetText(tostring(math.floor(finalX + 0.5)))
    ebY:SetText(tostring(math.floor(finalY + 0.5)))
  end)

  return ov
end

-- ============================================================================
-- OVERLAY SHOW / HIDE
-- ============================================================================

function Mover:ShowOverlay(name)
  local entry = _registry[name]
  if not entry or not entry.frame then return end

  if not entry.overlay then
    entry.overlay = CreateOverlay(entry, name)
  end

  if entry.overlay then
    local cover = entry.coverFrame or entry.frame
    AnchorOverlayToVisual(entry.overlay, cover)
    entry.overlay:Show()
    if entry.overlay._updateCoords then entry.overlay._updateCoords() end
  end
end

function Mover:HideOverlay(name)
  local entry = _registry[name]
  if entry and entry.overlay then
    entry.overlay:Hide()
  end
end

-- ============================================================================
-- SAVE POSITION
-- ============================================================================

function Mover:SavePosition(name)
  local entry = _registry[name]
  if not entry or not entry.frame or not entry.dbFunc then return end

  local db, keyX, keyY = entry.dbFunc()
  if not db or not keyX or not keyY then return end

  local frame = entry.frame
  local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
  local fs = frame:GetScale() or 1
  local cx, cy

  local point, relTo, relPoint, px, py = frame:GetPoint()
  if point == "CENTER" and relPoint == "CENTER" and px and py then
    cx, cy = px * fs, py * fs
  else
    local left   = frame:GetLeft()
    local bottom = frame:GetBottom()
    if left and bottom then
      cx = (left + frame:GetWidth() / 2) * fs - pw / 2
      cy = (bottom + frame:GetHeight() / 2) * fs - ph / 2
    else
      return
    end
  end

  db[keyX] = math.floor(cx + 0.5)
  db[keyY] = math.floor(cy + 0.5)

  frame._moverDragging = true
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", db[keyX] / fs, db[keyY] / fs)
  frame._moverDragging = nil

  if entry.onSave then
    pcall(entry.onSave, db, db[keyX], db[keyY])
  end
end

-- ============================================================================
-- RESET POSITION
-- ============================================================================

function Mover:ResetPosition(name)
  local entry = _registry[name]
  if not entry or not entry.frame or not entry.dbFunc then return end

  local db, keyX, keyY = entry.dbFunc()
  if not db or not keyX or not keyY then return end

  local def = entry.defaults or { x = 0, y = 0 }
  db[keyX] = def.x
  db[keyY] = def.y

  if entry.onReset then
    pcall(entry.onReset, db)
  else
    local fs = entry.frame:GetScale() or 1
    entry.frame._moverDragging = true
    entry.frame:ClearAllPoints()
    entry.frame:SetPoint("CENTER", UIParent, "CENTER", def.x / fs, def.y / fs)
    entry.frame._moverDragging = nil
  end

  if entry.overlay then
    local cover = entry.coverFrame or entry.frame
    AnchorOverlayToVisual(entry.overlay, cover)
  end

  BravLib.Print(name .. " — position reinitialisee.")
end

-- ============================================================================
-- CONTROL PANEL
-- ============================================================================

local CATEGORIES = {
  { key = "all",    label = "Tout" },
  { key = "uf",     label = "Cadre" },
  { key = "bars",   label = "Actions" },
  { key = "data",   label = "Donn\195\169es" },
  { key = "divers", label = "Divers" },
}

local _controlPanel = nil
local _activeCategory = "all"
local _catButtons = {}

local function CreateControlPanel()
  if _controlPanel then return _controlPanel end

  local cr, cg, cb = GetClassColor()
  local FONT = GetFont()

  local f = CreateFrame("Frame", "BravUI_MoverPanel", UIParent)
  f:SetSize(380, 80)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(510)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX); bg:SetVertexColor(0.06, 0.06, 0.06, 0.95); bg:SetAllPoints()

  local BW = 2
  local function Border(p1, p2, isHoriz)
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX); t:SetVertexColor(cr, cg, cb, 1)
    if isHoriz then
      t:SetHeight(BW); t:SetPoint("TOPLEFT", f, p1); t:SetPoint("TOPRIGHT", f, p2)
    else
      t:SetWidth(BW); t:SetPoint("TOPLEFT", f, p1); t:SetPoint("BOTTOMLEFT", f, p2)
    end
  end
  Border("TOPLEFT", "TOPRIGHT", true)
  Border("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Border("TOPLEFT", "BOTTOMLEFT", false)
  local rb = f:CreateTexture(nil, "OVERLAY", nil, 7)
  rb:SetTexture(TEX); rb:SetVertexColor(cr, cg, cb, 1); rb:SetWidth(BW)
  rb:SetPoint("TOPRIGHT", f, "TOPRIGHT"); rb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")

  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  -- Category buttons
  local topRow = CreateFrame("Frame", nil, f)
  topRow:SetSize(356, 28)
  topRow:SetPoint("TOP", f, "TOP", 0, -8)

  local prevBtn = nil
  for i, cat in ipairs(CATEGORIES) do
    local btn = CreateFrame("Button", nil, topRow)
    btn:SetSize(68, 28)
    if prevBtn then
      btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    else
      btn:SetPoint("LEFT", topRow, "LEFT", 0, 0)
    end

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetTexture(TEX); btnBg:SetAllPoints()
    btn._bg = btnBg

    local btnTxt = btn:CreateFontString(nil, "OVERLAY")
    pcall(btnTxt.SetFont, btnTxt, FONT, 10, "OUTLINE")
    btnTxt:SetPoint("CENTER"); btnTxt:SetText(cat.label)
    btn._text = btnTxt
    btn._catKey = cat.key

    btn:SetScript("OnClick", function()
      _activeCategory = cat.key
      Mover:ApplyFilter()
      Mover:UpdateCategoryButtons()
    end)
    btn:SetScript("OnEnter", function(self)
      if self._catKey ~= _activeCategory then self._bg:SetVertexColor(0.2, 0.2, 0.2, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
      if self._catKey ~= _activeCategory then self._bg:SetVertexColor(0.12, 0.12, 0.12, 1) end
    end)

    _catButtons[i] = btn
    prevBtn = btn
  end

  -- Bottom row: Reset All + Finish
  local botRow = CreateFrame("Frame", nil, f)
  botRow:SetSize(262, 28)
  botRow:SetPoint("TOP", topRow, "BOTTOM", 0, -8)

  local resetAllBtn = CreateFrame("Button", nil, botRow)
  resetAllBtn:SetSize(160, 28)
  resetAllBtn:SetPoint("LEFT", botRow, "LEFT", 0, 0)

  local raBg = resetAllBtn:CreateTexture(nil, "BACKGROUND")
  raBg:SetTexture(TEX); raBg:SetVertexColor(0.15, 0.15, 0.15, 1); raBg:SetAllPoints()
  resetAllBtn._bg = raBg

  local raTxt = resetAllBtn:CreateFontString(nil, "OVERLAY")
  pcall(raTxt.SetFont, raTxt, FONT, 10, "OUTLINE")
  raTxt:SetPoint("CENTER"); raTxt:SetText("Remise par d\195\169faut")
  raTxt:SetTextColor(0.8, 0.8, 0.8, 1)

  resetAllBtn:SetScript("OnEnter", function(self)
    self._bg:SetVertexColor(0.25, 0.25, 0.25, 1); raTxt:SetTextColor(1, 0.4, 0.4, 1)
  end)
  resetAllBtn:SetScript("OnLeave", function(self)
    self._bg:SetVertexColor(0.15, 0.15, 0.15, 1); raTxt:SetTextColor(0.8, 0.8, 0.8, 1)
  end)
  resetAllBtn:SetScript("OnClick", function()
    for n, entry in pairs(_registry) do
      if _activeCategory == "all" or entry.category == _activeCategory then
        Mover:ResetPosition(n)
        if entry.overlay and entry.overlay._updateCoords then entry.overlay._updateCoords() end
      end
    end
  end)

  local finishBtn = CreateFrame("Button", nil, botRow)
  finishBtn:SetSize(94, 28)
  finishBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 8, 0)

  local finBg = finishBtn:CreateTexture(nil, "BACKGROUND")
  finBg:SetTexture(TEX); finBg:SetVertexColor(cr * 0.3, cg * 0.3, cb * 0.3, 1); finBg:SetAllPoints()
  finishBtn._bg = finBg

  local finTxt = finishBtn:CreateFontString(nil, "OVERLAY")
  pcall(finTxt.SetFont, finTxt, FONT, 10, "OUTLINE")
  finTxt:SetPoint("CENTER"); finTxt:SetText("Terminer"); finTxt:SetTextColor(cr, cg, cb, 1)

  finishBtn:SetScript("OnEnter", function(self) self._bg:SetVertexColor(cr * 0.5, cg * 0.5, cb * 0.5, 1) end)
  finishBtn:SetScript("OnLeave", function(self) self._bg:SetVertexColor(cr * 0.3, cg * 0.3, cb * 0.3, 1) end)
  finishBtn:SetScript("OnClick", function() Mover:Exit() end)

  f:Hide()
  _controlPanel = f
  return f
end

function Mover:UpdateCategoryButtons()
  local cr, cg, cb = GetClassColor()
  for _, btn in ipairs(_catButtons) do
    if btn._catKey == _activeCategory then
      btn._bg:SetVertexColor(cr * 0.4, cg * 0.4, cb * 0.4, 1)
      btn._text:SetTextColor(cr, cg, cb, 1)
    else
      btn._bg:SetVertexColor(0.12, 0.12, 0.12, 1)
      btn._text:SetTextColor(0.7, 0.7, 0.7, 1)
    end
  end
end

function Mover:ApplyFilter()
  for name, entry in pairs(_registry) do
    if _activeCategory == "all" or entry.category == _activeCategory then
      self:ShowOverlay(name)
    else
      self:HideOverlay(name)
    end
  end
end

-- ============================================================================
-- TOGGLE EDIT MODE
-- ============================================================================

function Mover:IsActive()
  return _active
end

function Mover:Enter()
  if _active then return end
  if InCombatLockdown() then
    BravLib.Warn("Impossible en combat.")
    return
  end
  _active = true

  -- Force UF registration if not done yet
  EnsureUFRegistered()

  _activeCategory = "all"
  for name in pairs(_registry) do
    self:ShowOverlay(name)
  end

  local panel = CreateControlPanel()
  if panel then
    self:UpdateCategoryButtons()
    panel:Show()
  end

  ShowGrid()

  BravLib.Print("Edit Mode |cff00ff00ON|r — Deplace tes elements puis clique Terminer.")
end

function Mover:Exit()
  if not _active then return end
  _active = false

  for name in pairs(_registry) do
    self:SavePosition(name)
    self:HideOverlay(name)
  end

  HideGuides()
  HideGrid()
  if _controlPanel then
    _controlPanel:Hide()
  end

  BravLib.Print("Edit Mode |cffff0000OFF|r — Positions sauvegardees.")
end

function Mover:Toggle()
  if _active then self:Exit() else self:Enter() end
end

-- ============================================================================
-- COMPAT: BravUI.Move.* (used by modules)
-- ============================================================================

function BravUI.Move.Enable(frame, name)
  -- Lire les defaults pour ce frame
  local def = BravLib.Storage.GetDefaults()
  local defPos = def and def.positions and def.positions[name]
  local defXY = { x = defPos and defPos.x or 0, y = defPos and defPos.y or 0 }

  -- Simple registration: saves/restores from positions DB
  Mover:Register(name, frame, function()
    local db = BravLib.Storage.GetDB()
    if not db then return end
    db.positions = db.positions or {}
    db.positions[name] = db.positions[name] or {}
    return db.positions[name], "x", "y"
  end, defXY, { category = "divers" })

  -- Restore saved position
  local db = BravLib.Storage.GetDB()
  if db and db.positions and db.positions[name] then
    local pos = db.positions[name]
    if pos.x and pos.y then
      local fs = frame:GetScale() or 1
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", pos.x / fs, pos.y / fs)
    end
  end
end

function BravUI.Move.Toggle()
  Mover:Toggle()
end

function BravUI.Move.Unlock()
  Mover:Enter()
end

function BravUI.Move.Lock()
  Mover:Exit()
end

function BravUI.Move.IsUnlocked()
  return _active
end

-- ============================================================================
-- AUTO-REGISTER UNITFRAMES
-- ============================================================================

local UF_LIST = {
  { name = "Joueur",    fkey = "Player",  dbKey = "player" },
  { name = "Cible",     fkey = "Target",  dbKey = "target" },
  { name = "CdC",       fkey = "ToT",     dbKey = "tot" },
  { name = "Focus",     fkey = "Focus",   dbKey = "focus" },
  { name = "Familier",  fkey = "Pet",     dbKey = "pet" },
  { name = "Groupe",    fkey = "Group",   dbKey = "group" },
  { name = "Raid 15",   fkey = "Raid15",  dbKey = "raid15" },
  { name = "Raid 25",   fkey = "Raid25",  dbKey = "raid25" },
  { name = "Raid 40",   fkey = "Raid40",  dbKey = "raid40" },
}

local function RegisterUnitFrames()
  local frames = BravUI.Frames
  if not frames then return end

  local count = 0
  for _, entry in ipairs(UF_LIST) do
    local ft = frames[entry.fkey]
    local root = ft and (ft.Root or ft)
    if root and root.SetPoint and not _registry[entry.name] then
      local def = BravLib.Storage.GetDefaults()
      local defUF = def and def.unitframes and def.unitframes[entry.dbKey]
      local defPos = { x = defUF and defUF.posX or 0, y = defUF and defUF.posY or 0 }
      Mover:Register(entry.name, root, function()
        local db = BravLib.Storage.GetDB()
        if not db or not db.unitframes then return end
        local uf = db.unitframes[entry.dbKey]
        if uf then return uf, "posX", "posY" end
      end, defPos, { category = "uf", menuPage = "unitframes" })
      count = count + 1
    end
  end
  BravLib.Debug("Mover: " .. count .. " UnitFrames registered")
end

-- ============================================================================
-- RESTORE ALL POSITIONS (utilisé au chargement + switch de profil)
-- ============================================================================

local function RestoreAllPositions()
  for name, entry in pairs(_registry) do
    if entry.frame and entry.dbFunc then
      local db, keyX, keyY = entry.dbFunc()
      if db and keyX and keyY and db[keyX] and db[keyY] then
        local fs = entry.frame:GetScale() or 1
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("CENTER", UIParent, "CENTER", db[keyX] / fs, db[keyY] / fs)
      end
    end
  end
end

-- Register on Enter too (in case PLAYER_LOGIN already fired)
EnsureUFRegistered = function()
  if _ufRegistered then return end
  _ufRegistered = true
  RegisterUnitFrames()
end

BravLib.Event.Register("PLAYER_ENTERING_WORLD", function()
  C_Timer.After(1, function()
    EnsureUFRegistered()
    RestoreAllPositions()
  end)
end)

-- ============================================================================
-- ESC TO EXIT
-- ============================================================================

local escFrame = CreateFrame("Frame", "BravUI_MoverEscHandler", UIParent)
escFrame:SetScript("OnKeyDown", function(self, key)
  if InCombatLockdown() then return end
  if key == "ESCAPE" and _active then
    self:SetPropagateKeyboardInput(false)
    Mover:Exit()
  else
    self:SetPropagateKeyboardInput(true)
  end
end)
escFrame:SetPropagateKeyboardInput(true)

-- ============================================================================
-- PROFILE SWITCH: re-appliquer toutes les positions + settings
-- ============================================================================

BravLib.Hooks.Register("PROFILE_CHANGED", function()
  -- d'abord re-appliquer les settings (qui repositionnent les frames depuis la DB)
  BravLib.Hooks.Fire("APPLY_ALL")
  BravLib.Hooks.Fire("APPLY_MINIMAP")
  BravLib.Hooks.Fire("APPLY_FONT")
  -- puis restaurer les positions du Move system (a le dernier mot)
  C_Timer.After(0.1, RestoreAllPositions)
end)

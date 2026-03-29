-- BravUI_Menu/Core/Init.lua
-- Namespace, theme constants, helpers

BravUI.Menu = BravUI.Menu or {}
local M = BravUI.Menu

-- ============================================================================
-- THEME
-- ============================================================================

local _classColorCache

local function GetClassColor()
  -- Custom color override from General settings
  local useClassColor = BravLib.API.Get("general", "useClassColor")
  local customColor   = BravLib.API.Get("general", "customColor")
  if useClassColor == false and customColor then
    return customColor.r or 0.20, customColor.g or 0.85, customColor.b or 0.90
  end

  -- Default: class color (cached)
  if _classColorCache then return unpack(_classColorCache) end
  local _, cls = UnitClass("player")
  if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
    local c = RAID_CLASS_COLORS[cls]
    _classColorCache = { c.r, c.g, c.b }
  else
    _classColorCache = { 0.20, 0.85, 0.90 }
  end
  return unpack(_classColorCache)
end

M.Theme = {
  -- Dimensions
  W = 900,
  H = 620,
  SIDEBAR_W = 170,
  TAB_BAR_H = 36,
  HEADER_H = 48,
  FOOTER_H = 40,
  PAD = 16,

  -- Colors
  BG        = { 0.06, 0.06, 0.08, 0.96 },
  SIDEBAR   = { 0.04, 0.04, 0.06, 1 },
  PANEL     = { 0.09, 0.09, 0.11, 1 },
  BORDER    = { 0.15, 0.15, 0.18, 1 },
  TEXT      = { 0.93, 0.93, 0.93, 1 },
  MUTED     = { 0.50, 0.50, 0.55, 1 },
  HOVER     = { 0.12, 0.12, 0.14, 1 },
  BTN       = { 0.10, 0.10, 0.12, 0.80 },
  BTN_HOVER = { 0.16, 0.16, 0.18, 0.90 },

  -- Font
  FONT = BravLib.Media.Get("font", "default"),

  -- Textures
  TEX = "Interface/Buttons/WHITE8x8",

  -- Extra fields
  FONT_PATH = BravLib.Media.Get("font", "default"),
  LOGO_PATH = "Interface/AddOns/BravUI_Lib/BravLib_Media/Logo/BravUI_64x64.tga",
  TEX_WHITE = "Interface/Buttons/WHITE8x8",
  ACCENT    = { 0.20, 0.85, 0.90, 1.00 },
  BTN_ON    = { 0.14, 0.14, 0.14, 0.90 },
  TOPBAR    = { 0.00, 0.00, 0.00, 0.35 },
  TAB_ACTIVE          = { 0.12, 0.12, 0.12, 0.80 },
  TAB_INACTIVE        = { 0, 0, 0, 0.30 },
  TAB_INACTIVE_BORDER = { 1, 1, 1, 0.12 },
  FLYOUT_BG = { 0.05, 0.05, 0.05, 0.95 },
}

-- ============================================================================
-- HELPERS
-- ============================================================================

function M:GetClassColor()
  return GetClassColor()
end

function M:InvalidateColorCache()
  _classColorCache = nil
end

function M:SafeFont(fs, size, flags)
  if not fs then return end
  local font = BravLib.Media.Get("font", "default")
  local ok = pcall(function()
    fs:SetFont(font, size or 12, flags or "OUTLINE")
  end)
  if not ok then
    pcall(function()
      fs:SetFont("Fonts/FRIZQT__.TTF", size or 12, flags or "OUTLINE")
    end)
  end
end

-- Police système pour les glyphes Unicode non supportés par Russo_One
function M:SystemFont(fs, size, flags)
  if not fs then return end
  pcall(fs.SetFont, fs, "Fonts/FRIZQT__.TTF", size or 10, flags or "OUTLINE")
end

-- Glyphes Font_Icons.ttf (variantes bold)
local ICON_ARROW_DOWN  = "m"
local ICON_ARROW_UP    = "p"
local ICON_ARROW_LEFT  = "n"
local ICON_ARROW_RIGHT = "o"
local ICON_CHECK       = "N"
local ICON_GEAR        = "w"
local ICON_TOOLS       = "y"

-- Helper interne : crée un FontString avec Font_Icons
local function CreateIconFS(parent, text, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  pcall(fs.SetFont, fs, BravLib.Media.Get("font", "icons"), size or 10, "OUTLINE")
  fs:SetText(text)
  local c = color or M.Theme.MUTED
  fs:SetTextColor(c[1] or 0.5, c[2] or 0.5, c[3] or 0.5, c[4] or 1)
  return fs
end

-- Crée une flèche dropdown (▼) via Font_Icons
function M:CreateDropdownArrow(parent, size, color)
  local fs = CreateIconFS(parent, ICON_ARROW_DOWN, size or 10, color)
  fs:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
  return fs
end

-- Crée une flèche de groupe (▸ collapsed / ▾ expanded) via Font_Icons
function M:CreateGroupArrow(parent, size, color)
  local fs = CreateIconFS(parent, ICON_ARROW_RIGHT, size or 10, color)

  function fs:SetCollapsed(collapsed)
    fs:SetText(collapsed and ICON_ARROW_RIGHT or ICON_ARROW_DOWN)
  end

  return fs
end

-- Crée une coche (✓) via Font_Icons
function M:CreateCheckmark(parent, size, color)
  local fs = CreateIconFS(parent, ICON_CHECK, size or 10, color)
  fs:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
  return fs
end

function M:SetBG(frame, color)
  if not frame then return end
  local tex = frame:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints()
  tex:SetColorTexture(unpack(color or self.Theme.BG))
  return tex
end

function M:CreateLine(parent, anchor, color, thickness)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(thickness or 1)
  if anchor == "TOP" then
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  elseif anchor == "BOTTOM" then
    line:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  end
  line:SetColorTexture(unpack(color or self.Theme.BORDER))
  return line
end

-- ============================================================================
-- DB HELPER
-- ============================================================================

function M:GetModuleDB(key)
  return BravLib.API.GetModule(key)
end

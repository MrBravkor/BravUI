-- BravUI/Modules/Misc/VehicleExit.lua
-- Bouton custom de sortie de véhicule / démontage
--
-- SecureActionButtonTemplate + RegisterStateDriver = zero taint.
-- Visible en véhicule ([vehicleui]) ou sur monture ([mounted]).
-- Masque le bouton Blizzard natif.

BravUI.Frames       = BravUI.Frames or {}
BravUI.Frames.Player = BravUI.Frames.Player or {}

local U             = BravUI.Utils
local GetClassColor = U.GetClassColor

-- ============================================================================
-- CONFIG
-- ============================================================================
local BTN_SIZE    = 28
local CROSS_PAD   = 8
local CROSS_THICK = 2
local CROSS_COLOR = { 0.85, 0.22, 0.18, 1 }
local CROSS_HOVER = { 1.00, 0.40, 0.30, 1 }

-- ============================================================================
-- HIDE BLIZZARD DEFAULT VEHICLE EXIT BUTTON
-- ============================================================================
local _hider = CreateFrame("Frame")
_hider:Hide()

local function KillBlizzardFrame(f)
  if not f then return end
  pcall(RegisterStateDriver, f, "visibility", "hide")
  if f.ClearAllPoints then pcall(f.ClearAllPoints, f) end
  pcall(function() f:SetParent(_hider) end)
  pcall(function() f:UnregisterAllEvents() end)
end

local function HideBlizzardVehicleBtn()
  KillBlizzardFrame(MainMenuBarVehicleLeaveButton)
  KillBlizzardFrame(OverrideActionBarLeaveFrameLeaveButton)
end

-- ============================================================================
-- BUTTON (SecureActionButton — safe in combat)
-- ============================================================================
local btn = CreateFrame("Button", "BravUI_VehicleExitBtn", UIParent,
  "SecureActionButtonTemplate")

btn:SetSize(BTN_SIZE, BTN_SIZE)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(100)
btn:SetClampedToScreen(true)
btn:EnableMouse(true)

btn:RegisterForClicks("AnyUp", "AnyDown")
btn:SetAttribute("type",      "macro")
btn:SetAttribute("macrotext", "/leavevehicle [vehicleui]\n/dismount [mounted]")

-- ============================================================================
-- POSITION
-- ============================================================================
local function ApplyPosition()
  local pos = BravLib.API.Get("positions", "VehicleExit")
  local px = pos and pos.x or 0
  local py = pos and pos.y or -150
  local fs = btn:GetScale() or 1
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", UIParent, "CENTER", px / fs, py / fs)
end

-- ============================================================================
-- STYLE
-- ============================================================================
local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.06, 0.06, 0.08, 0.95)

-- 1px border (class color)
local borderTextures = {}
local function MakeBorderTex(p1, r1, p2, r2, w, h)
  local t = btn:CreateTexture(nil, "OVERLAY", nil, 7)
  t:SetPoint(p1, btn, r1, 0, 0)
  t:SetPoint(p2, btn, r2, 0, 0)
  if w then t:SetWidth(w)  end
  if h then t:SetHeight(h) end
  borderTextures[#borderTextures + 1] = t
  return t
end

MakeBorderTex("TOPLEFT",     "TOPLEFT",     "TOPRIGHT",    "TOPRIGHT",    nil, 1)
MakeBorderTex("BOTTOMLEFT",  "BOTTOMLEFT",  "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
MakeBorderTex("TOPLEFT",     "TOPLEFT",     "BOTTOMLEFT",  "BOTTOMLEFT",  1, nil)
MakeBorderTex("TOPRIGHT",    "TOPRIGHT",    "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

local function UpdateBorderColor()
  local r, g, b = GetClassColor("player")
  for _, t in ipairs(borderTextures) do
    t:SetColorTexture(r, g, b, 1)
  end
end

-- ============================================================================
-- CROSS ICON
-- ============================================================================
local P = CROSS_PAD

local line1 = btn:CreateLine(nil, "ARTWORK")
line1:SetThickness(CROSS_THICK)
line1:SetColorTexture(CROSS_COLOR[1], CROSS_COLOR[2], CROSS_COLOR[3], CROSS_COLOR[4])
line1:SetStartPoint("TOPLEFT",     btn,  P, -P)
line1:SetEndPoint(  "BOTTOMRIGHT", btn, -P,  P)

local line2 = btn:CreateLine(nil, "ARTWORK")
line2:SetThickness(CROSS_THICK)
line2:SetColorTexture(CROSS_COLOR[1], CROSS_COLOR[2], CROSS_COLOR[3], CROSS_COLOR[4])
line2:SetStartPoint("TOPRIGHT",  btn, -P, -P)
line2:SetEndPoint(  "BOTTOMLEFT", btn,  P,  P)

-- ============================================================================
-- VISIBILITY
-- ============================================================================
RegisterStateDriver(btn, "visibility", "[vehicleui] show; [mounted] show; hide")

-- ============================================================================
-- TOOLTIP + HOVER
-- ============================================================================
btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  local label
  if CanExitVehicle and CanExitVehicle() then
    label = LEAVE_VEHICLE or "Quitter le véhicule"
  else
    label = BINDING_NAME_DISMOUNT or "Descendre de monture"
  end
  GameTooltip:SetText(label, 1, 1, 1)
  GameTooltip:Show()

  line1:SetColorTexture(CROSS_HOVER[1], CROSS_HOVER[2], CROSS_HOVER[3], CROSS_HOVER[4])
  line2:SetColorTexture(CROSS_HOVER[1], CROSS_HOVER[2], CROSS_HOVER[3], CROSS_HOVER[4])
end)

btn:SetScript("OnLeave", function()
  GameTooltip:Hide()
  line1:SetColorTexture(CROSS_COLOR[1], CROSS_COLOR[2], CROSS_COLOR[3], CROSS_COLOR[4])
  line2:SetColorTexture(CROSS_COLOR[1], CROSS_COLOR[2], CROSS_COLOR[3], CROSS_COLOR[4])
end)

-- ============================================================================
-- INIT
-- ============================================================================
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
  HideBlizzardVehicleBtn()
  UpdateBorderColor()
  ApplyPosition()

  C_Timer.After(1.5, function()
    BravUI.Move.Enable(btn, "VehicleExit")
  end)
end)

-- Expose
BravUI.Frames.Player.VehicleExitBtn                  = btn
BravUI.Frames.Player.VehicleExitBtn.UpdateBorderColor = UpdateBorderColor

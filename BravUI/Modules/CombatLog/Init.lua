-- BravUI/Modules/CombatLog/Init.lua
-- Combat log manager (LoggerHead replacement)
-- Shows a confirmation popup when entering a tracked instance
-- Portage v2 : no Ace, no external dependencies

local BravUI = BravUI
local U = BravUI.Utils
local P = BravUI.Print
local GetClassColor = function() return U.GetClassColor("player") end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local CL = {}
BravUI:RegisterModule("Misc.CombatLog", CL)
BravUI.CombatLog = CL

-- ============================================================================
-- DB HELPER
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("combatlog") or {}
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"

local function GetFont()
  return U.GetFont()
end

-- ============================================================================
-- DIFFICULTY MAP — difficultyID -> DB toggle key
-- ============================================================================

local DIFFICULTY_MAP = {
  -- Donjons
  [1]  = "dungeonNormal",
  [2]  = "dungeonHeroic",
  [23] = "dungeonMythic",
  [8]  = "dungeonMythicPlus",
  [24] = "dungeonTimewalking",

  -- Raids
  [14] = "raidNormal",
  [15] = "raidHeroic",
  [16] = "raidMythic",
  [17] = "raidLFR",
  [7]  = "raidLFR",
  [3]  = "raidNormal",
  [4]  = "raidNormal",
  [5]  = "raidHeroic",
  [6]  = "raidHeroic",
}

-- ============================================================================
-- STATE
-- ============================================================================

local isLogging = false
local container       -- combined indicator frame
local confirmFrame    -- popup frame

-- ============================================================================
-- DECISION: Should we prompt in this zone?
-- ============================================================================

local function ShouldLog(db)
  if not db or not db.enabled then return false end

  local _, instanceType, difficultyID = GetInstanceInfo()

  if instanceType == "none" then return false end

  if instanceType == "arena" then
    return db.arena == true
  end

  if instanceType == "pvp" then
    return db.battleground == true
  end

  if instanceType == "scenario" then
    return db.dungeonNormal == true
  end

  if instanceType == "party" then
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
      and C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then
      return db.dungeonMythicPlus == true
    end
    local diffKey = DIFFICULTY_MAP[difficultyID]
    if diffKey then
      return db[diffKey] == true
    end
    return db.dungeonNormal == true
  end

  if instanceType == "raid" then
    local diffKey = DIFFICULTY_MAP[difficultyID]
    if diffKey then
      return db[diffKey] == true
    end
    return db.raidNormal == true
  end

  return false
end

-- ============================================================================
-- TOGGLE LOGGING
-- ============================================================================

local function EnableLogging(db)
  local current = LoggingCombat()
  if not current then
    LoggingCombat(true)
  end
  isLogging = true
  if db and db.chatNotify ~= false and P then
    local instName = select(1, GetInstanceInfo()) or "Unknown"
    P:Info("|cff00ff00Combat log activé|r — " .. instName)
  end
  CL:UpdateIndicator()
end

local function DisableLogging(db)
  local current = LoggingCombat()
  if current then
    LoggingCombat(false)
  end
  isLogging = false
  if db and db.chatNotify ~= false and P then
    P:Info("|cffff6666Combat log désactivé|r")
  end
  CL:UpdateIndicator()
end

-- ============================================================================
-- COMBINED CONTAINER — Queue Eye (top) + Log status (bottom)
-- Single movable frame via /bravmove
-- ============================================================================

local function CreateIndicator()
  if container then return end

  local eye = _G.QueueStatusButton
  local eyeH = eye and math.max(eye:GetHeight(), 32) or 32
  local eyeW = eye and math.max(eye:GetWidth(), 32) or 32
  local statusH = 20
  local gap = 4
  local totalW = math.max(eyeW, 100)
  local totalH = eyeH + gap + statusH

  -- Container frame
  local f = CreateFrame("Frame", "BravUI_CombatLogContainer", UIParent)
  f:SetSize(totalW, totalH)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(50)

  -- Adopt the eye into the container
  if eye then
    eye:SetParent(f)
    eye:ClearAllPoints()
    eye:SetPoint("TOP", f, "TOP", 0, 0)
  end

  -- Status bar (below the eye)
  local bar = CreateFrame("Frame", nil, f)
  bar:SetSize(totalW, statusH)
  bar:SetPoint("TOP", f, "TOP", 0, -(eyeH + gap))

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX)
  bg:SetVertexColor(0, 0, 0, 0.75)
  bg:SetAllPoints(bar)

  bar._borders = U.CreateClassBorder(bar)

  local fontPath = GetFont()
  local text = bar:CreateFontString(nil, "OVERLAY")
  text:SetFont(fontPath, 11, "OUTLINE")
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  text:SetText("Log actif")
  text:SetTextColor(0.2, 0.9, 0.2, 1)
  f._text = text
  f._bar = bar

  -- Register with /bravmove
  if BravUI.Move and BravUI.Move.Enable then
    BravUI.Move.Enable(f, "Queue Eye")
  end

  f:Hide()
  container = f
end

function CL:UpdateIndicator()
  if not container then return end

  local db = GetDB()
  if not db or not db.enabled or db.showIndicator == false then
    container:Hide()
    return
  end

  -- Show in instance, hide outside
  local _, instanceType = GetInstanceInfo()
  if instanceType == "none" then
    container:Hide()
    return
  end

  -- Refresh class color on status bar border
  if container._bar and container._bar._borders and U.UpdateClassBorderColors then
    U.UpdateClassBorderColors(container._bar._borders)
  end

  if isLogging then
    container._text:SetText("Log actif")
    container._text:SetTextColor(0.2, 0.9, 0.2, 1)
  else
    container._text:SetText("Log inactif")
    container._text:SetTextColor(0.9, 0.2, 0.2, 1)
  end

  container:Show()
end

-- ============================================================================
-- CONFIRMATION POPUP — BravUI-styled dialog
-- ============================================================================

local function CreateConfirmFrame()
  if confirmFrame then return end

  local cr, cg, cb = GetClassColor()
  local fontPath = GetFont()

  local f = CreateFrame("Frame", "BravUI_CombatLogConfirm", UIParent)
  f:SetSize(320, 120)
  f:SetPoint("TOP", UIParent, "TOP", 0, -180)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(200)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  -- Dark background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX)
  bg:SetVertexColor(0.06, 0.06, 0.06, 0.95)
  bg:SetAllPoints()

  -- Class-colored border
  f._borders = U.CreateClassBorder(f)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY")
  title:SetFont(fontPath, 13, "OUTLINE")
  title:SetPoint("TOP", f, "TOP", 0, -12)
  title:SetTextColor(cr, cg, cb, 1)
  f._title = title

  -- Instance name (line 2)
  local instText = f:CreateFontString(nil, "OVERLAY")
  instText:SetFont(fontPath, 11, "OUTLINE")
  instText:SetPoint("TOP", title, "BOTTOM", 0, -6)
  instText:SetTextColor(0.9, 0.9, 0.9, 1)
  f._instText = instText

  -- Helper: create a styled button
  local function MakeButton(label, width, color)
    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(width, 26)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetTexture(TEX)
    btnBg:SetVertexColor(color[1], color[2], color[3], 0.25)
    btnBg:SetAllPoints()
    btn._bg = btnBg

    -- 1px borders
    local function BtnBorder(anchor1, anchor2, w, h)
      local t = btn:CreateTexture(nil, "OVERLAY")
      t:SetTexture(TEX)
      t:SetVertexColor(color[1], color[2], color[3], 0.6)
      t:SetPoint(anchor1)
      t:SetPoint(anchor2)
      if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    BtnBorder("TOPLEFT", "TOPRIGHT", nil, 1)
    BtnBorder("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    BtnBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)
    BtnBorder("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    local txt = btn:CreateFontString(nil, "OVERLAY")
    txt:SetFont(fontPath, 11, "OUTLINE")
    txt:SetPoint("CENTER")
    txt:SetText(label)
    txt:SetTextColor(color[1], color[2], color[3], 1)
    btn._text = txt

    btn:SetScript("OnEnter", function()
      btnBg:SetVertexColor(color[1], color[2], color[3], 0.45)
    end)
    btn:SetScript("OnLeave", function()
      btnBg:SetVertexColor(color[1], color[2], color[3], 0.25)
    end)

    return btn
  end

  -- YES button (green)
  local btnYes = MakeButton("Activer", 120, { 0.2, 0.9, 0.2 })
  btnYes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 25, 14)
  btnYes:SetScript("OnClick", function()
    EnableLogging(GetDB())
    f:Hide()
  end)

  -- NO button (red)
  local btnNo = MakeButton("Non", 120, { 0.9, 0.3, 0.3 })
  btnNo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 14)
  btnNo:SetScript("OnClick", function()
    f:Hide()
    CL:UpdateIndicator()
  end)

  f:Hide()
  confirmFrame = f
end

local function ShowConfirmPopup(instName, diffName)
  CreateConfirmFrame()
  if not confirmFrame then return end

  local cr, cg, cb = GetClassColor()

  if confirmFrame._title then
    confirmFrame._title:SetText("|cff33ffccBravUI|r — Combat Log")
  end

  if confirmFrame._instText then
    local label = instName or "Instance"
    if diffName and diffName ~= "" then
      label = label .. "  |cff888888(" .. diffName .. ")|r"
    end
    confirmFrame._instText:SetText(label)
  end

  if confirmFrame._borders and U.UpdateClassBorderColors then
    U.UpdateClassBorderColors(confirmFrame._borders)
  end

  confirmFrame:Show()
end

-- ============================================================================
-- ZONE EVALUATION
-- ============================================================================

function CL:EvaluateZone()
  local db = GetDB()
  if not db or not db.enabled then
    if isLogging then DisableLogging(db or {}) end
    if confirmFrame then confirmFrame:Hide() end
    return
  end

  local instName, instanceType, difficultyID, diffName = GetInstanceInfo()

  -- Leaving instance → auto-disable + hide popup + hide indicator
  if instanceType == "none" then
    if confirmFrame then confirmFrame:Hide() end
    if isLogging then DisableLogging(db) end
    self:UpdateIndicator()
    return
  end

  -- Already logging → stay, no popup
  if isLogging then return end

  -- Should we prompt?
  if ShouldLog(db) then
    ShowConfirmPopup(instName, diffName)
  end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function CL:Enable()
  local db = GetDB()
  if not db.enabled then return end

  CreateIndicator()

  -- Zone/instance change events
  BravLib.Event.Register("PLAYER_ENTERING_WORLD", function()
    CL:EvaluateZone()
  end)
  BravLib.Event.Register("ZONE_CHANGED_NEW_AREA", function()
    CL:EvaluateZone()
  end)

  -- M+ specific
  BravLib.Event.Register("CHALLENGE_MODE_START", function()
    CL:EvaluateZone()
  end)
  BravLib.Event.Register("CHALLENGE_MODE_COMPLETED", function()
    C_Timer.After(1, function() CL:EvaluateZone() end)
  end)

  -- Spec change: update indicator color
  BravLib.Event.Register("PLAYER_SPECIALIZATION_CHANGED", function()
    C_Timer.After(0.3, function() CL:UpdateIndicator() end)
  end)

  -- Initial evaluation (delayed for login)
  C_Timer.After(1, function() CL:EvaluateZone() end)
end

function CL:Disable()
  if isLogging then
    LoggingCombat(false)
    isLogging = false
    if P then
      P:Info("|cffff6666Combat log désactivé|r (module désactivé)")
    end
  end

  if container then container:Hide() end
  if confirmFrame then confirmFrame:Hide() end
end

function CL:Refresh()
  local db = GetDB()

  if not db.enabled then
    if isLogging then
      LoggingCombat(false)
      isLogging = false
    end
    if container then container:Hide() end
    if confirmFrame then confirmFrame:Hide() end
    return
  end

  CreateIndicator()
  self:EvaluateZone()
end

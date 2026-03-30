-- BravUI/Modules/ActionBars/ActionBars.lua
-- BravBars system: reparents Blizzard action buttons into custom frames
-- Port v1 → v2: no AceAddon, no LibKeyBound, no BravUI.Media

local U = BravUI.Utils
local GetFont = U.GetFont
local GetClassColor = U.GetClassColor

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local ActionBars = {}
BravUI:RegisterModule("Misc.ActionBars", ActionBars)

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX_WHITE      = "Interface/Buttons/WHITE8x8"
local BORDER_COLOR   = { 0, 0, 0, 0.9 }
local BG_COLOR       = { 0.05, 0.05, 0.05, 0.85 }
local HIGHLIGHT_COLOR = { 1, 1, 1, 0.15 }
local PUSHED_COLOR   = { 0.8, 0.8, 0.8, 0.25 }
local CHECKED_COLOR  = { 0.3, 0.7, 0.3, 0.35 }
local BORDER_SIZE    = 1

-- ============================================================================
-- DB HELPERS
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("actionbars") or {}
end

-- ============================================================================
-- UI HIDER FRAME
-- ============================================================================

local UIHider = CreateFrame("Frame", "BravUI_UIHider")
UIHider:Hide()

-- ============================================================================
-- HIDE BLIZZARD BAR ARTWORK
-- ============================================================================

local blizzardArtworkHidden = false

local function HideAllRegions(frame)
  if not frame then return end
  pcall(function()
    for i = 1, frame:GetNumRegions() do
      local region = select(i, frame:GetRegions())
      if region then
        if region.SetTexture then region:SetTexture(nil) end
        if region.SetAtlas then region:SetAtlas(nil) end
        if region.SetAlpha then region:SetAlpha(0) end
        if region.Hide then region:Hide() end
      end
    end
    for i = 1, frame:GetNumChildren() do
      local child = select(i, frame:GetChildren())
      if child and not child:IsForbidden() then
        local name = child:GetName() or ""
        if not name:find("Button%d") then
          HideAllRegions(child)
        end
      end
    end
  end)
end

local function DeepHideArt(frame, depth)
  if not frame or frame:IsForbidden() then return end
  depth = depth or 0
  if depth > 10 then return end

  pcall(function()
    for i = 1, frame:GetNumRegions() do
      local reg = select(i, frame:GetRegions())
      if reg and not reg:IsForbidden() then
        if reg.GetAtlas then
          local atlas = reg:GetAtlas()
          if atlas and (atlas:find("UI%-HUD%-ActionBar") or atlas:find("EndCap") or atlas:find("hud%-MainMenuBar")) then
            reg:SetAlpha(0); reg:Hide()
            if reg.SetTexture then reg:SetTexture(nil) end
            if reg.SetAtlas then reg:SetAtlas(nil) end
          end
        end
        if reg.GetTexture then
          local tex = reg:GetTexture()
          if tex and type(tex) == "string" and (tex:find("EndCap") or tex:find("Gryphon") or tex:find("hud") or tex:find("MainMenuBar")) then
            reg:SetAlpha(0); reg:Hide()
            if reg.SetTexture then reg:SetTexture(nil) end
          end
        end
      end
    end
  end)

  pcall(function()
    for i = 1, frame:GetNumChildren() do
      local child = select(i, frame:GetChildren())
      if child and not child:IsForbidden() then
        local cname = child:GetName() or ""
        if not cname:find("Button%d") and not cname:find("^BravBar") then
          if cname:find("EndCap") or cname:find("Gryphon") or cname:find("ArtFrame") then
            child:SetParent(UIHider)
          else
            DeepHideArt(child, depth + 1)
          end
        end
      end
    end
  end)
end

local function HideBlizzardArtwork()
  if blizzardArtworkHidden then return end
  blizzardArtworkHidden = true

  local barFrames = {}
  if MainMenuBar then table.insert(barFrames, MainMenuBar) end
  if MainActionBar then table.insert(barFrames, MainActionBar) end

  for _, bar in ipairs(barFrames) do
    HideAllRegions(bar)
    bar:EnableMouse(false)
    local artKeys = { "EndCaps", "BorderArt", "ActionBarArtFrame", "Background" }
    for _, key in ipairs(artKeys) do
      if bar[key] then bar[key]:SetParent(UIHider) end
    end
  end

  local framesToHide = {
    MainMenuBarArtFrame, MainMenuBarArtFrameBackground,
    MainMenuBarLeftEndCap, MainMenuBarRightEndCap,
    StatusTrackingBarManager, MainStatusTrackingBarContainer,
    ActionBarDownButton, ActionBarUpButton, MainMenuBarPageNumber,
    MicroButtonAndBagsBar, BagsBar, MainMenuBarBackpackButton,
    OverrideActionBar,
  }
  for _, frame in ipairs(framesToHide) do
    if frame then frame:SetParent(UIHider) end
  end

  local barRegionFrames = {
    MultiBarBottomLeft, MultiBarBottomRight,
    MultiBarLeft, MultiBarRight,
    MultiBar5, MultiBar6, MultiBar7,
    StanceBar, StanceBarFrame,
    PetActionBar, PetActionBarFrame,
  }
  for _, frame in ipairs(barRegionFrames) do
    if frame then
      HideAllRegions(frame)
      frame:EnableMouse(false)
    end
  end

  local texturesToHide = {
    "MainMenuBarTexture0", "MainMenuBarTexture1",
    "MainMenuBarTexture2", "MainMenuBarTexture3",
    "MainMenuBarMaxLevelBar",
  }
  for _, n in ipairs(texturesToHide) do
    local tex = _G[n]
    if tex then
      if tex.SetTexture then tex:SetTexture(nil) end
      if tex.SetAlpha then tex:SetAlpha(0) end
      if tex.Hide then tex:Hide() end
    end
  end

  local function LateHide()
    for _, bar in ipairs(barFrames) do
      if bar then
        HideAllRegions(bar)
        bar:EnableMouse(false)
        DeepHideArt(bar)
      end
    end
  end
  C_Timer.After(0.1, LateHide)
  C_Timer.After(0.5, LateHide)
  C_Timer.After(1.0, LateHide)
  C_Timer.After(2.0, LateHide)
  C_Timer.After(5.0, LateHide)
end

-- ============================================================================
-- KEYBIND MODE (replaces LibKeyBound)
-- ============================================================================

local KeyBindMode = { active = false, overlays = {}, bindingSet = nil, header = nil }

local function ShortenHotkey(text)
  if not text or type(text) ~= "string" then return "" end
  text = text:gsub("\194\160", " ")
  text = strtrim(text)
  if text == "" then return "" end
  if text == _G.RANGE_INDICATOR or text == "\194\183" or text == "\183" then return "" end
  text = text:gsub("^a%-", "A")
  text = text:gsub("^s%-", "S")
  text = text:gsub("^c%-", "C")
  text = text:gsub("^NUMPAD", "N")
  text = text:gsub("^Num ", "N")
  text = text:gsub("MOUSEWHEELUP", "MwU")
  text = text:gsub("MOUSEWHEELDOWN", "MwD")
  text = text:gsub("BUTTON", "M")
  return text
end

local function GetBindingCommand(button)
  if button.commandName then return button.commandName end
  local btnName = button:GetName() or ""
  if btnName:match("^ActionButton(%d+)$") then
    return "ACTIONBUTTON" .. btnName:match("^ActionButton(%d+)$")
  elseif btnName:match("^MultiBarBottomLeftButton(%d+)$") then
    return "MULTIACTIONBAR1BUTTON" .. btnName:match("(%d+)$")
  elseif btnName:match("^MultiBarBottomRightButton(%d+)$") then
    return "MULTIACTIONBAR2BUTTON" .. btnName:match("(%d+)$")
  elseif btnName:match("^MultiBarRightButton(%d+)$") then
    return "MULTIACTIONBAR3BUTTON" .. btnName:match("(%d+)$")
  elseif btnName:match("^MultiBarLeftButton(%d+)$") then
    return "MULTIACTIONBAR4BUTTON" .. btnName:match("(%d+)$")
  elseif btnName:match("^PetActionButton(%d+)$") then
    return "BONUSACTIONBUTTON" .. btnName:match("(%d+)$")
  elseif btnName:match("^StanceButton(%d+)$") then
    return "SHAPESHIFTBUTTON" .. btnName:match("(%d+)$")
  end
  return nil
end

local function GetCurrentHotkey(button)
  local cmd = button._BravUI_BindingCommand
  if cmd then
    local key = GetBindingKey(cmd)
    if key then return ShortenHotkey(GetBindingText(key)) end
  end
  return ""
end

local function CreateKeyBindOverlay(button)
  if button._BravUI_KBOverlay then return button._BravUI_KBOverlay end

  local ov = CreateFrame("Button", nil, button)
  ov:SetAllPoints()
  ov:SetFrameStrata("FULLSCREEN_DIALOG")
  ov:SetFrameLevel(900)
  ov:EnableKeyboard(true)
  ov:EnableMouse(true)
  ov:RegisterForClicks("AnyUp")

  local bg = ov:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX_WHITE)
  bg:SetVertexColor(0, 0, 0, 0.6)
  bg:SetAllPoints()

  local text = ov:CreateFontString(nil, "OVERLAY")
  pcall(text.SetFont, text, GetFont(), 12, "OUTLINE")
  text:SetPoint("CENTER")
  text:SetTextColor(1, 0.82, 0, 1)
  ov._text = text

  ov:SetScript("OnEnter", function(self)
    self._text:SetTextColor(0, 1, 0, 1)
    self:EnableKeyboard(true)
  end)
  ov:SetScript("OnLeave", function(self)
    self._text:SetTextColor(1, 0.82, 0, 1)
    self:EnableKeyboard(false)
  end)

  ov:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      KeyBindMode:Exit()
      return
    end
    -- Ignore modifier keys alone
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
    or key == "LALT" or key == "RALT" then return end

    local cmd = button._BravUI_BindingCommand
    if not cmd then return end

    -- Build full key with modifiers
    local mods = ""
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    local fullKey = mods .. key

    SetBinding(fullKey, cmd)
    SaveBindings(KeyBindMode.bindingSet or GetCurrentBindingSet())
    self._text:SetText(ShortenHotkey(GetBindingText(fullKey)))

    -- Update the button's custom hotkey FontString
    if button._BravUI_Hotkey then
      local short = ShortenHotkey(GetBindingText(fullKey))
      if short == "" then
        button._BravUI_Hotkey:SetText("")
        button._BravUI_Hotkey:SetAlpha(0)
        button._BravUI_Hotkey._BravUI_Empty = true
      else
        button._BravUI_Hotkey:SetText(short)
        button._BravUI_Hotkey:SetAlpha(1)
        button._BravUI_Hotkey._BravUI_Empty = false
      end
    end
  end)

  ov:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" then
      -- Right-click clears binding
      local cmd = button._BravUI_BindingCommand
      if cmd then
        local key1, key2 = GetBindingKey(cmd)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SaveBindings(KeyBindMode.bindingSet or GetCurrentBindingSet())
        self._text:SetText("")
        if button._BravUI_Hotkey then
          button._BravUI_Hotkey:SetText("")
          button._BravUI_Hotkey:SetAlpha(0)
          button._BravUI_Hotkey._BravUI_Empty = true
        end
      end
    end
  end)

  ov:Hide()
  button._BravUI_KBOverlay = ov
  return ov
end

-- ============================================================================
-- KEYBIND HEADER (floating panel at top of screen)
-- ============================================================================

local function CreateKeybindHeader()
  if KeyBindMode.header then return KeyBindMode.header end

  local cr, cg, cb = GetClassColor("player")
  local FONT = GetFont()

  local f = CreateFrame("Frame", "BravUI_KeyBindHeader", UIParent)
  f:SetSize(420, 52)
  f:SetPoint("TOP", UIParent, "TOP", 0, -20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(950)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(TEX_WHITE)
  bg:SetVertexColor(0.06, 0.06, 0.06, 0.95)
  bg:SetAllPoints()

  -- 1px class-colored border
  local function MakeBorder(p1, p2, w, h)
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX_WHITE); t:SetVertexColor(cr, cg, cb, 1)
    t:SetPoint(p1, f, p1, 0, 0); t:SetPoint(p2, f, p2, 0, 0)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  MakeBorder("TOPLEFT", "TOPRIGHT", nil, 1)
  MakeBorder("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  MakeBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)
  MakeBorder("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY")
  pcall(title.SetFont, title, FONT, 12, "OUTLINE")
  title:SetPoint("TOP", f, "TOP", 0, -6)
  title:SetText("Mode Raccourcis")
  title:SetTextColor(cr, cg, cb, 1)

  -- Toggle buttons: Personnage / Compte
  local function CreateToggleBtn(parent, label, anchorPoint, anchorTo, anchorRel, ox, oy)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(120, 18)
    btn:SetPoint(anchorPoint, anchorTo, anchorRel, ox, oy)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetTexture(TEX_WHITE)
    btnBg:SetAllPoints()
    btn._bg = btnBg

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    pcall(btnText.SetFont, btnText, FONT, 10, "OUTLINE")
    btnText:SetPoint("CENTER")
    btnText:SetText(label)
    btn._label = btnText

    return btn
  end

  local btnPerso = CreateToggleBtn(f, "Personnage", "TOPLEFT", title, "BOTTOM", -125, -4)
  local btnCompte = CreateToggleBtn(f, "Compte", "LEFT", btnPerso, "RIGHT", 6, 0)

  local function UpdateToggleVisuals()
    local set = KeyBindMode.bindingSet or GetCurrentBindingSet()
    if set == 1 then
      btnPerso._bg:SetVertexColor(cr, cg, cb, 0.4)
      btnPerso._label:SetTextColor(1, 1, 1, 1)
      btnCompte._bg:SetVertexColor(0.15, 0.15, 0.15, 1)
      btnCompte._label:SetTextColor(0.5, 0.5, 0.5, 1)
    else
      btnPerso._bg:SetVertexColor(0.15, 0.15, 0.15, 1)
      btnPerso._label:SetTextColor(0.5, 0.5, 0.5, 1)
      btnCompte._bg:SetVertexColor(cr, cg, cb, 0.4)
      btnCompte._label:SetTextColor(1, 1, 1, 1)
    end
  end
  f._updateToggle = UpdateToggleVisuals

  btnPerso:SetScript("OnClick", function()
    KeyBindMode.bindingSet = 1
    -- Persist to DB
    local db = BravLib.Storage.GetDB()
    if db and db.actionbars then db.actionbars.bindingSet = 1 end
    UpdateToggleVisuals()
  end)

  btnCompte:SetScript("OnClick", function()
    KeyBindMode.bindingSet = 2
    local db = BravLib.Storage.GetDB()
    if db and db.actionbars then db.actionbars.bindingSet = 2 end
    UpdateToggleVisuals()
  end)

  -- Quit button
  local quitBtn = CreateFrame("Button", nil, f)
  quitBtn:SetSize(50, 18)
  quitBtn:SetPoint("LEFT", btnCompte, "RIGHT", 6, 0)

  local quitBg = quitBtn:CreateTexture(nil, "BACKGROUND")
  quitBg:SetTexture(TEX_WHITE)
  quitBg:SetVertexColor(0.5, 0.1, 0.1, 0.6)
  quitBg:SetAllPoints()

  local quitText = quitBtn:CreateFontString(nil, "OVERLAY")
  pcall(quitText.SetFont, quitText, FONT, 10, "OUTLINE")
  quitText:SetPoint("CENTER")
  quitText:SetText("Quitter")
  quitText:SetTextColor(1, 0.4, 0.4, 1)

  quitBtn:SetScript("OnClick", function() KeyBindMode:Exit() end)

  -- Instructions
  local info = f:CreateFontString(nil, "OVERLAY")
  pcall(info.SetFont, info, FONT, 9, "OUTLINE")
  info:SetPoint("BOTTOM", f, "BOTTOM", 0, 4)
  info:SetText("Survolez + touche = bind  |  Clic droit = effacer  |  ESC = quitter")
  info:SetTextColor(0.6, 0.6, 0.6, 1)

  f:Hide()
  KeyBindMode.header = f
  return f
end

-- ============================================================================
-- KEYBIND MODE ENTER / EXIT
-- ============================================================================

function KeyBindMode:Enter()
  if self.active then return end
  self.active = true

  -- Load persisted bindingSet from DB
  local db = BravLib.Storage.GetDB()
  if db and db.actionbars and db.actionbars.bindingSet then
    self.bindingSet = db.actionbars.bindingSet
  else
    self.bindingSet = GetCurrentBindingSet()
  end

  -- Show header
  local header = CreateKeybindHeader()
  header._updateToggle()
  header:Show()

  -- Show overlays on all buttons
  local bars = BravUI.Frames.ActionBars and BravUI.Frames.ActionBars.bars
  if not bars then return end

  for _, bar in pairs(bars) do
    if bar.buttons then
      for _, button in ipairs(bar.buttons) do
        local ov = CreateKeyBindOverlay(button)
        ov._text:SetText(GetCurrentHotkey(button))
        ov:Show()
        ov:EnableKeyboard(false)
        table.insert(self.overlays, ov)
      end
    end
  end
end

function KeyBindMode:Exit()
  if not self.active then return end
  self.active = false

  for _, ov in ipairs(self.overlays) do
    ov:Hide()
    ov:EnableKeyboard(false)
  end
  wipe(self.overlays)

  if self.header then self.header:Hide() end

  print("|cff33ffccBravUI:|r Raccourcis sauvegardes.")
end

function KeyBindMode:Toggle()
  if self.active then self:Exit() else self:Enter() end
end

-- Slash command
SLASH_BRAVBIND1 = "/bravbind"
SlashCmdList["BRAVBIND"] = function() KeyBindMode:Toggle() end

-- ============================================================================
-- BAR CONFIGURATION
-- ============================================================================

local BAR_BUTTONS = {
  [1] = { prefix = "ActionButton",              count = 12 },
  [2] = { prefix = "MultiBarBottomLeftButton",  count = 12 },
  [3] = { prefix = "MultiBarBottomRightButton", count = 12 },
  [4] = { prefix = "MultiBarRightButton",       count = 12 },
  [5] = { prefix = "MultiBarLeftButton",        count = 12 },
  [6] = { prefix = "MultiBar5Button",           count = 12 },
  [7] = { prefix = "MultiBar6Button",           count = 12 },
  [8] = { prefix = "MultiBar7Button",           count = 12 },
  ["pet"]    = { prefix = "PetActionButton", count = 10 },
  ["stance"] = { prefix = "StanceButton",    count = 10 },
}

local BAR_CONFIG = {
  [1] = { key = "bar1", defaultY = 40 },
  [2] = { key = "bar2", defaultY = 80 },
  [3] = { key = "bar3", defaultY = 120 },
  [4] = { key = "bar4", defaultY = 160 },
  [5] = { key = "bar5", defaultY = 200 },
  [6] = { key = "bar6", defaultY = 240 },
  [7] = { key = "bar7", defaultY = 280 },
  [8] = { key = "bar8", defaultY = 320 },
  ["pet"]    = { key = "barPet",    defaultY = 360 },
  ["stance"] = { key = "barStance", defaultY = 400 },
}

local BAR_MOVER_NAMES = {
  [1] = "Barre 1", [2] = "Barre 2", [3] = "Barre 3", [4] = "Barre 4",
  [5] = "Barre 5", [6] = "Barre 6", [7] = "Barre 7", [8] = "Barre 8",
  ["pet"] = "Familiers", ["stance"] = "Postures",
}

-- ============================================================================
-- BRAVBAR CLASS
-- ============================================================================

local BravBar = {}
BravBar.__index = BravBar

local BravBars = {}

-- ============================================================================
-- EMPTY SLOT VISIBILITY
-- ============================================================================

local function UpdateEmptySlotVisibility(button, db)
  if not button or not button._BravUI_Backdrop then return end
  local showEmpty = db.showEmptySlots ~= false
  local hasAction = false
  if button.HasAction then
    hasAction = button:HasAction()
  elseif button.action then
    hasAction = HasAction(button.action)
  end
  if hasAction then
    button._BravUI_Backdrop:Show()
    button:SetAlpha(1)
  else
    if showEmpty then
      button._BravUI_Backdrop:Show()
      button:SetAlpha(1)
    else
      button._BravUI_Backdrop:Hide()
      button:SetAlpha(0)
    end
  end
end

-- ============================================================================
-- CREATE BRAVBAR
-- ============================================================================

function BravBar:Create(barId, db)
  local self = setmetatable({}, BravBar)
  self.id = barId
  self.db = db
  self.buttons = {}
  self.config = BAR_CONFIG[barId]
  self.buttonInfo = BAR_BUTTONS[barId]

  local frameName = "BravBar" .. tostring(barId)
  local frame = CreateFrame("Frame", frameName, UIParent)
  frame:SetSize(100, 100)
  frame:SetClampedToScreen(true)
  frame:Show()
  self.frame = frame

  self:GrabButtons()
  return self
end

-- ============================================================================
-- GRAB BLIZZARD BUTTONS
-- ============================================================================

function BravBar:GrabButtons()
  local info = self.buttonInfo
  if not info then return end

  -- Stance/pet: only grab buttons that actually have a form/action
  local maxCount = info.count
  if self.id == "stance" and GetNumShapeshiftForms then
    local n = GetNumShapeshiftForms()
    if n and n > 0 then maxCount = n end
  end

  for i = 1, maxCount do
    local buttonName = info.prefix .. i
    local button = _G[buttonName]
    if button and not button:IsForbidden() then
      button:SetParent(self.frame)
      button:Show()
      button:SetAlpha(1)
      -- Ensure click registration after reparent (TWW requires AnyDown for press-cast)
      pcall(button.RegisterForClicks, button, "AnyDown", "AnyUp")
      self:SkinButton(button)
      table.insert(self.buttons, button)
    end
  end
end

-- ============================================================================
-- SKIN BUTTON
-- ============================================================================

function BravBar:SkinButton(button)
  if not button then return end
  if button._BravUI_Skinned then return end
  button._BravUI_Skinned = true

  local db   = self.db
  local name = button:GetName() or ""

  -- Store binding command
  button._BravUI_BindingCommand = GetBindingCommand(button)

  local icon             = button.icon or _G[name .. "Icon"]
  local normalTexture    = button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture())
  local border           = button.Border or _G[name .. "Border"]
  local hotkey           = button.HotKey or _G[name .. "HotKey"]
  local count            = button.Count or _G[name .. "Count"]
  local macroName        = button.Name or _G[name .. "Name"]
  local cooldown         = button.cooldown or _G[name .. "Cooldown"]
  local floatingBG       = _G[name .. "FloatingBG"]
  local highlightTexture = button.HighlightTexture or _G[name .. "HighlightTexture"] or (button.GetHighlightTexture and button:GetHighlightTexture())
  local pushedTexture    = button.PushedTexture or _G[name .. "PushedTexture"] or (button.GetPushedTexture and button:GetPushedTexture())
  local checkedTexture   = button.CheckedTexture or _G[name .. "CheckedTexture"] or (button.GetCheckedTexture and button:GetCheckedTexture())
  local flash            = button.Flash or _G[name .. "Flash"]

  -- Hide default border/background
  if normalTexture then normalTexture:SetTexture(nil); normalTexture:Hide() end
  if border then border:SetTexture(nil); border:Hide() end
  if floatingBG then floatingBG:Hide() end

  -- Hide TWW HUD atlas regions
  for j = 1, button:GetNumRegions() do
    local reg = select(j, button:GetRegions())
    if reg and not reg:IsForbidden() and reg.GetAtlas then
      local atlas = reg:GetAtlas()
      if atlas and atlas:find("UI%-HUD%-ActionBar") then
        reg:SetAlpha(0); reg:Hide()
      end
    end
  end

  for j = 1, button:GetNumChildren() do
    local child = select(j, button:GetChildren())
    if child and not child:IsForbidden() and not child._BravUI_Ours and child ~= cooldown then
      for k = 1, child:GetNumRegions() do
        local reg = select(k, child:GetRegions())
        if reg and not reg:IsForbidden() and reg.GetAtlas then
          local atlas = reg:GetAtlas()
          if atlas and atlas:find("UI%-HUD%-ActionBar") then
            reg:SetAlpha(0); reg:Hide()
          end
        end
      end
    end
  end

  -- Style icon
  if icon then
    icon:SetTexCoord(0, 1, 0, 1)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Style highlight
  if highlightTexture then
    highlightTexture:SetTexture(TEX_WHITE)
    highlightTexture:SetVertexColor(unpack(HIGHLIGHT_COLOR))
    highlightTexture:ClearAllPoints()
    highlightTexture:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    highlightTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Style pushed
  if pushedTexture then
    pushedTexture:SetTexture(TEX_WHITE)
    pushedTexture:SetVertexColor(unpack(PUSHED_COLOR))
    pushedTexture:ClearAllPoints()
    pushedTexture:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    pushedTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Style checked
  if checkedTexture then
    checkedTexture:SetTexture(TEX_WHITE)
    checkedTexture:SetVertexColor(unpack(CHECKED_COLOR))
    checkedTexture:ClearAllPoints()
    checkedTexture:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    checkedTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Style flash
  if flash then
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    flash:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Custom backdrop
  if not button._BravUI_Backdrop then
    local backdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    backdrop:SetBackdrop({ bgFile = TEX_WHITE, edgeFile = TEX_WHITE, edgeSize = BORDER_SIZE })
    backdrop:SetBackdropColor(unpack(BG_COLOR))
    backdrop:SetBackdropBorderColor(unpack(BORDER_COLOR))
    backdrop:EnableMouse(false)
    backdrop._BravUI_Ours = true
    button._BravUI_Backdrop = backdrop
  end

  -- Hook SetNormalTexture
  if not button._BravUI_NormalHooked then
    button._BravUI_NormalHooked = true
    hooksecurefunc(button, "SetNormalTexture", function(btn)
      local nt = btn:GetNormalTexture()
      if nt then nt:SetTexture(nil); nt:SetAlpha(0) end
    end)
  end

  -- Hotkey: hide Blizzard's, create ours
  if hotkey then
    hotkey:SetAlpha(0)
    if not hotkey._BravUI_AlphaHooked then
      hotkey._BravUI_AlphaHooked = true
      hooksecurefunc(hotkey, "SetAlpha", function(self, a)
        if a and a > 0 then self:SetAlpha(0) end
      end)
    end

    if not button._BravUI_Hotkey then
      button._BravUI_Hotkey = button:CreateFontString(nil, "OVERLAY")
    end
    local bravHK = button._BravUI_Hotkey
    pcall(bravHK.SetFont, bravHK, GetFont(), 10, "OUTLINE")

    local function SyncHotkey(fs, text)
      local s = ShortenHotkey(text)
      if s == "" then
        fs:SetText(""); fs:SetAlpha(0); fs._BravUI_Empty = true
      else
        fs:SetText(s); fs:SetAlpha(1); fs._BravUI_Empty = false
      end
    end

    SyncHotkey(bravHK, hotkey:GetText())

    if not hotkey._BravUI_TextSyncHooked then
      hotkey._BravUI_TextSyncHooked = true
      hooksecurefunc(hotkey, "SetText", function(self, text)
        if button._BravUI_Hotkey then SyncHotkey(button._BravUI_Hotkey, text) end
      end)
    end

    bravHK:ClearAllPoints()
    bravHK:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
  end

  -- Count
  if count then
    pcall(count.SetFont, count, GetFont(), 11, "OUTLINE")
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  end

  -- Macro name: hide Blizzard's, create ours
  if macroName then
    macroName:SetAlpha(0)
    if not macroName._BravUI_AlphaHooked then
      macroName._BravUI_AlphaHooked = true
      hooksecurefunc(macroName, "SetAlpha", function(self, a)
        if a and a > 0 then self:SetAlpha(0) end
      end)
    end

    if not button._BravUI_MacroName then
      button._BravUI_MacroName = button:CreateFontString(nil, "OVERLAY")
    end
    local bravMN = button._BravUI_MacroName
    pcall(bravMN.SetFont, bravMN, GetFont(), 9, "OUTLINE")

    local function SyncMacroName(fs, text)
      local s = (text and type(text) == "string") and strtrim(text) or ""
      if s == "" then
        fs:SetText(""); fs:SetAlpha(0); fs._BravUI_Empty = true
      else
        fs:SetText(s); fs:SetAlpha(1); fs._BravUI_Empty = false
      end
    end

    SyncMacroName(bravMN, macroName:GetText())

    if not macroName._BravUI_TextSyncHooked then
      macroName._BravUI_TextSyncHooked = true
      hooksecurefunc(macroName, "SetText", function(self, text)
        if button._BravUI_MacroName then SyncMacroName(button._BravUI_MacroName, text) end
      end)
    end

    bravMN:ClearAllPoints()
    bravMN:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
  end

  -- Cooldown
  if cooldown then
    cooldown:ClearAllPoints()
    cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    if cooldown.SetHideCountdownNumbers then
      cooldown:SetHideCountdownNumbers(not db.showCooldownText)
    end

    if not cooldown._BravUI_CDColorHooked then
      cooldown._BravUI_CDColorHooked = true
      local function ApplyCDStyle(cd)
        local c  = cd._BravUI_CDTextColor
        local sz = cd._BravUI_CDFontSize
        if not c and not sz then return end
        for j = 1, cd:GetNumRegions() do
          local reg = select(j, cd:GetRegions())
          if reg and reg:IsObjectType("FontString") then
            if c then reg:SetTextColor(c[1], c[2], c[3]) end
            if sz then pcall(reg.SetFont, reg, GetFont(), sz, "OUTLINE") end
          end
        end
        for j = 1, cd:GetNumChildren() do
          local child = select(j, cd:GetChildren())
          if child then
            for k = 1, child:GetNumRegions() do
              local reg = select(k, child:GetRegions())
              if reg and reg:IsObjectType("FontString") then
                if c then reg:SetTextColor(c[1], c[2], c[3]) end
                if sz then pcall(reg.SetFont, reg, GetFont(), sz, "OUTLINE") end
              end
            end
          end
        end
      end
      cooldown:HookScript("OnShow", function(cd) ApplyCDStyle(cd) end)
      local elapsed = 0
      cooldown:HookScript("OnUpdate", function(cd, dt)
        elapsed = elapsed + dt
        if elapsed > 0.2 then elapsed = 0; ApplyCDStyle(cd) end
      end)
    end
  end

  -- Autocastable / AutoCastShine (pet buttons)
  local autocastable = _G[name .. "AutoCastable"]
  if autocastable then
    autocastable:SetTexture(nil); autocastable:SetAlpha(0); autocastable:Hide()
  end
  local autocast = button.AutoCastShine or _G[name .. "AutoCastShine"]
  if autocast then
    autocast:ClearAllPoints()
    autocast:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    autocast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
  end

  -- Pet button specifics
  if name:match("^PetActionButton") then
    local function KillTexture(tex)
      if not tex then return end
      if tex.SetTexture then tex:SetTexture(nil) end
      if tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
      if tex.SetVertexColor then tex:SetVertexColor(0, 0, 0, 0) end
      if tex.SetAlpha then tex:SetAlpha(0) end
      if tex.Hide then tex:Hide() end
    end

    KillTexture(normalTexture)

    for j = 1, button:GetNumRegions() do
      local reg = select(j, button:GetRegions())
      if reg and not reg:IsForbidden() and reg:GetObjectType() == "Texture" and reg ~= icon and not reg._BravUI_Ours then
        KillTexture(reg)
        if not reg._BravUI_Blocked then
          reg._BravUI_Blocked = true
          hooksecurefunc(reg, "SetTexture", function(self, t)
            if t and t ~= "" and t ~= TEX_WHITE then
              self:SetTexture(nil); self:SetVertexColor(0, 0, 0, 0); self:SetAlpha(0)
            end
          end)
          hooksecurefunc(reg, "Show", function(self)
            local t = self:GetTexture()
            if t and t ~= "" and t ~= TEX_WHITE then
              self:SetTexture(nil); self:SetVertexColor(0, 0, 0, 0); self:SetAlpha(0)
            end
          end)
        end
      end
    end

    for j = 1, button:GetNumChildren() do
      local child = select(j, button:GetChildren())
      if child and not child:IsForbidden() and child ~= cooldown and not child._BravUI_Ours and child ~= autocast then
        child:SetAlpha(0)
        if child.Hide then child:Hide() end
        for k = 1, child:GetNumRegions() do
          KillTexture(select(k, child:GetRegions()))
        end
      end
    end

    -- Pet active border
    if not button._BravUI_PetActiveBorder then
      local petIdx = tonumber(name:match("(%d+)$")) or 0
      local bSize  = 2
      local bColor = { 0, 1, 0, 1 }

      local function MakePetBorder(p1, p2, w, h)
        local t = button:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture(TEX_WHITE); t:SetVertexColor(unpack(bColor))
        t:SetPoint(p1, button, p1, 0, 0); t:SetPoint(p2, button, p2, 0, 0)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        t._BravUI_Ours = true; t:Hide()
        return t
      end

      button._BravUI_PetActiveBorder = {
        MakePetBorder("TOPLEFT", "TOPRIGHT", nil, bSize),
        MakePetBorder("BOTTOMLEFT", "BOTTOMRIGHT", nil, bSize),
        MakePetBorder("TOPLEFT", "BOTTOMLEFT", bSize, nil),
        MakePetBorder("TOPRIGHT", "BOTTOMRIGHT", bSize, nil),
      }
      button._BravUI_PetIdx = petIdx
    end

    local function ReKillPetTextures(btn)
      local btnIcon = btn.icon or _G[btn:GetName() .. "Icon"]
      KillTexture(btn:GetNormalTexture())
      for j = 1, btn:GetNumRegions() do
        local reg = select(j, btn:GetRegions())
        if reg and not reg:IsForbidden() and reg:GetObjectType() == "Texture" and reg ~= btnIcon and not reg._BravUI_Ours then
          KillTexture(reg)
        end
      end
    end

    if button.Update and not button._BravUI_UpdateHooked then
      button._BravUI_UpdateHooked = true
      hooksecurefunc(button, "Update", function(btn) ReKillPetTextures(btn) end)
    end
  end

  -- Empty slot hook
  if not button._BravUI_EmptyHooked then
    button._BravUI_EmptyHooked = true
    button._BravUI_DB = db
    if button.Update then
      hooksecurefunc(button, "Update", function(btn)
        UpdateEmptySlotVisibility(btn, btn._BravUI_DB or db)
      end)
    end
    button:HookScript("OnShow", function(btn)
      C_Timer.After(0.1, function()
        if btn and btn._BravUI_DB then UpdateEmptySlotVisibility(btn, btn._BravUI_DB) end
      end)
    end)
    C_Timer.After(0.2, function()
      if button and button._BravUI_DB then UpdateEmptySlotVisibility(button, button._BravUI_DB) end
    end)
  end
end

-- ============================================================================
-- BAR SETTINGS
-- ============================================================================

local function BarSetting(barDB, globalDB, key, default)
  if barDB[key] ~= nil then return barDB[key] end
  if globalDB[key] ~= nil then return globalDB[key] end
  return default
end

function BravBar:GetBarSettings()
  local db     = self.db
  local config = self.config
  db.bars = db.bars or {}
  db.bars[config.key] = db.bars[config.key] or {}
  local barDB = db.bars[config.key]

  return {
    enabled         = barDB.enabled ~= false,
    origin          = barDB.origin or "TOPLEFT",
    x               = barDB.x,
    y               = barDB.y or config.defaultY,
    buttonsPerRow   = barDB.buttonsPerRow or #self.buttons,
    alpha           = barDB.alpha or 1,
    mouseover       = barDB.mouseover or false,
    mouseoverAlpha  = barDB.mouseoverAlpha or 0,
    hideInCombat    = barDB.hideInCombat or false,
    hideOutOfCombat = barDB.hideOutOfCombat or false,
    combatAlpha     = barDB.combatAlpha or 1,
    buttonSize      = barDB.buttonSize or db.buttonSize or 36,
    buttonSpacing   = barDB.buttonSpacing or db.buttonSpacing or 2,
    showKeybinds    = BarSetting(barDB, db, "showKeybinds", true),
    showMacroNames  = BarSetting(barDB, db, "showMacroNames", false),
    showEmptySlots  = BarSetting(barDB, db, "showEmptySlots", true),
    showCooldownText = BarSetting(barDB, db, "showCooldownText", true),
    visibleButtons  = barDB.visibleButtons or #self.buttons,
    padding         = barDB.padding or 0,
    borderEnabled   = barDB.borderEnabled or false,
    borderUseClass  = barDB.borderUseClass ~= false,
    borderColor     = barDB.borderColor,
    borderSize      = barDB.borderSize or 1,
    textColor       = barDB.textColor or db.textColor,
    macroTextColor  = barDB.macroTextColor or db.macroTextColor,
    cooldownTextColor = barDB.cooldownTextColor,
    hotkeyAnchor    = barDB.hotkeyAnchor or db.hotkeyAnchor or "TOPRIGHT",
    macroAnchor     = barDB.macroAnchor or db.macroAnchor or "BOTTOM",
    hotkeyFontSize  = barDB.hotkeyFontSize or 10,
    macroFontSize   = barDB.macroFontSize or 10,
    cdFontSize      = barDB.cdFontSize or 12,
    iconZoom        = type(barDB.iconZoom) == "number" and barDB.iconZoom or 7,
  }
end

-- ============================================================================
-- UPDATE POSITION & LAYOUT
-- ============================================================================

function BravBar:UpdatePosition()
  local settings     = self:GetBarSettings()
  local buttonSize   = settings.buttonSize
  local buttonSpacing = settings.buttonSpacing
  local padding      = settings.padding
  local buttonsPerRow = settings.buttonsPerRow
  local visibleButtons = settings.visibleButtons

  if buttonsPerRow <= 0 or buttonsPerRow > #self.buttons then buttonsPerRow = #self.buttons end
  if visibleButtons <= 0 or visibleButtons > #self.buttons then visibleButtons = #self.buttons end

  local numCols   = math.min(visibleButtons, buttonsPerRow)
  local numRows   = math.ceil(visibleButtons / numCols)
  local frameWidth  = numCols * buttonSize + (numCols - 1) * buttonSpacing + padding * 2
  local frameHeight = numRows * buttonSize + (numRows - 1) * buttonSpacing + padding * 2
  self.frame:SetSize(frameWidth, frameHeight)

  -- Position from Move system (CENTER-based) or bar defaults
  local moverName = BAR_MOVER_NAMES[self.id]
  local pos = moverName and BravLib.API.Get("positions", moverName)
  local px = pos and pos.x or (settings.x or 0)
  local py = pos and pos.y or (settings.y or BAR_CONFIG[self.id].defaultY)
  local fs = self.frame:GetScale() or 1
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", px / fs, py / fs)

  local origin = settings.origin or "TOPLEFT"
  local flipH  = (origin == "TOPRIGHT" or origin == "BOTTOMRIGHT")
  local flipV  = (origin == "BOTTOMLEFT" or origin == "BOTTOMRIGHT")

  for i, button in ipairs(self.buttons) do
    if i > visibleButtons then
      button:Hide()
    else
      button:Show(); button:SetAlpha(1)
      local col = (i - 1) % numCols
      local row = math.floor((i - 1) / numCols)
      if flipH then col = (numCols - 1) - col end
      if flipV then row = (numRows - 1) - row end
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
        padding + col * (buttonSize + buttonSpacing),
        -(padding + row * (buttonSize + buttonSpacing)))
      button:SetSize(buttonSize, buttonSize)
    end
  end

  -- Border color
  local br, bg, bb, ba = unpack(BORDER_COLOR)
  if settings.borderEnabled then
    if settings.borderUseClass then
      local r, g, b = GetClassColor("player")
      br, bg, bb, ba = r, g, b, 1
    elseif settings.borderColor then
      br = settings.borderColor.r or 1
      bg = settings.borderColor.g or 1
      bb = settings.borderColor.b or 1
      ba = 1
    else
      br, bg, bb, ba = 1, 1, 1, 1
    end
  end

  -- Text colors
  local tr, tg, tb = 1, 1, 1
  if settings.textColor then
    tr = settings.textColor.r or 1; tg = settings.textColor.g or 1; tb = settings.textColor.b or 1
  end
  local mr, mg, mb = tr, tg, tb
  if settings.macroTextColor then
    mr = settings.macroTextColor.r or 1; mg = settings.macroTextColor.g or 1; mb = settings.macroTextColor.b or 1
  end

  local ANCHOR_OFFSETS = {
    TOPLEFT     = { "TOPLEFT",      2, -2 },
    TOP         = { "TOP",          0, -2 },
    TOPRIGHT    = { "TOPRIGHT",    -2, -2 },
    LEFT        = { "LEFT",         2,  0 },
    CENTER      = { "CENTER",       0,  0 },
    RIGHT       = { "RIGHT",       -2,  0 },
    BOTTOMLEFT  = { "BOTTOMLEFT",   2,  2 },
    BOTTOM      = { "BOTTOM",       0,  2 },
    BOTTOMRIGHT = { "BOTTOMRIGHT", -2,  2 },
  }

  for i, button in ipairs(self.buttons) do
    if i <= visibleButtons then
      -- Hotkey
      local bravHK = button._BravUI_Hotkey
      if bravHK then
        bravHK:SetAlpha((settings.showKeybinds and not bravHK._BravUI_Empty) and 1 or 0)
        bravHK:SetTextColor(tr, tg, tb)
        pcall(bravHK.SetFont, bravHK, GetFont(), settings.hotkeyFontSize, "OUTLINE")
        local hk = ANCHOR_OFFSETS[settings.hotkeyAnchor] or ANCHOR_OFFSETS["TOPRIGHT"]
        bravHK:ClearAllPoints(); bravHK:SetPoint(hk[1], button, hk[1], hk[2], hk[3])
      end
      -- Macro name
      local bravMN = button._BravUI_MacroName
      if bravMN then
        bravMN:SetAlpha((settings.showMacroNames and not bravMN._BravUI_Empty) and 1 or 0)
        bravMN:SetTextColor(mr, mg, mb)
        pcall(bravMN.SetFont, bravMN, GetFont(), settings.macroFontSize, "OUTLINE")
        local mk = ANCHOR_OFFSETS[settings.macroAnchor] or ANCHOR_OFFSETS["BOTTOM"]
        bravMN:ClearAllPoints(); bravMN:SetPoint(mk[1], button, mk[1], mk[2], mk[3])
      end
      -- Count color
      local cnt = button.Count or _G[(button:GetName() or "") .. "Count"]
      if cnt then cnt:SetTextColor(tr, tg, tb) end
      -- Cooldown text
      local cd = button.cooldown or _G[(button:GetName() or "") .. "Cooldown"]
      if cd then
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not settings.showCooldownText) end
        local cdr, cdg, cdb
        if settings.cooldownTextColor then
          cdr = settings.cooldownTextColor.r or 1
          cdg = settings.cooldownTextColor.g or 1
          cdb = settings.cooldownTextColor.b or 1
        end
        cd._BravUI_CDTextColor = cdr and { cdr, cdg, cdb } or nil
        cd._BravUI_CDFontSize  = settings.cdFontSize
      end
      -- Icon zoom
      local btnIcon = button.icon or button.Icon
      if btnIcon then
        local z = (settings.iconZoom or 0) / 100
        btnIcon:SetTexCoord(z, 1 - z, z, 1 - z)
      end
      -- Empty slots
      UpdateEmptySlotVisibility(button, { showEmptySlots = settings.showEmptySlots })
      -- Backdrop border
      if button._BravUI_Backdrop then
        local bdSize = settings.borderEnabled and settings.borderSize or BORDER_SIZE
        button._BravUI_Backdrop:SetBackdrop({ bgFile = TEX_WHITE, edgeFile = TEX_WHITE, edgeSize = bdSize })
        button._BravUI_Backdrop:SetBackdropColor(unpack(BG_COLOR))
        button._BravUI_Backdrop:SetBackdropBorderColor(br, bg, bb, ba)
        local ic = button.icon or button.Icon
        if ic then
          ic:ClearAllPoints()
          ic:SetPoint("TOPLEFT", button, "TOPLEFT", bdSize, -bdSize)
          ic:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -bdSize, bdSize)
        end
        local cd2 = button.cooldown or _G[(button:GetName() or "") .. "Cooldown"]
        if cd2 then
          cd2:ClearAllPoints()
          cd2:SetPoint("TOPLEFT", button, "TOPLEFT", bdSize, -bdSize)
          cd2:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -bdSize, bdSize)
        end
      end
    end
  end

  self:SetupVisibility(settings)
end

-- ============================================================================
-- VISIBILITY
-- ============================================================================

function BravBar:SetupVisibility(settings)
  local frame = self.frame

  if settings.hideInCombat then
    RegisterStateDriver(frame, "visibility", "[nocombat] show; hide")
  elseif settings.hideOutOfCombat then
    RegisterStateDriver(frame, "visibility", "[combat] show; hide")
  else
    UnregisterStateDriver(frame, "visibility")
    frame:Show()
  end

  if not frame._bravCombatFrame then
    local cf = CreateFrame("Frame")
    cf:RegisterEvent("PLAYER_REGEN_DISABLED")
    cf:RegisterEvent("PLAYER_REGEN_ENABLED")
    cf:SetScript("OnEvent", function(_, event)
      if not frame._bravCombatAlpha then return end
      if event == "PLAYER_REGEN_DISABLED" then
        frame:SetAlpha(frame._bravCombatAlpha)
      else
        frame:SetAlpha(frame._bravNormalAlpha or 1)
      end
    end)
    frame._bravCombatFrame = cf
  end

  local normalAlpha = settings.alpha
  frame._bravNormalAlpha = normalAlpha
  frame._bravCombatAlpha = (settings.combatAlpha < 1) and settings.combatAlpha or nil

  if frame._bravCombatAlpha and InCombatLockdown() then
    frame:SetAlpha(frame._bravCombatAlpha)
  else
    frame:SetAlpha(normalAlpha)
  end

  if settings.mouseover then
    local restAlpha = settings.mouseoverAlpha
    if not InCombatLockdown() or not frame._bravCombatAlpha then
      frame:SetAlpha(restAlpha)
    end
    frame._bravMouseover  = true
    frame._bravRestAlpha  = restAlpha
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(f) f:SetAlpha(f._bravNormalAlpha or 1) end)
    frame:SetScript("OnLeave", function(f)
      if f._bravCombatAlpha and InCombatLockdown() then
        f:SetAlpha(f._bravCombatAlpha)
      else
        f:SetAlpha(f._bravRestAlpha or 0)
      end
    end)
    for _, btn in ipairs(self.buttons) do
      if not btn._bravMouseoverHooked then
        btn._bravMouseoverHooked = true
        btn:HookScript("OnEnter", function()
          local p = btn:GetParent()
          if p and p._bravMouseover then p:SetAlpha(p._bravNormalAlpha or 1) end
        end)
        btn:HookScript("OnLeave", function()
          local p = btn:GetParent()
          if p and p._bravMouseover then
            if p._bravCombatAlpha and InCombatLockdown() then
              p:SetAlpha(p._bravCombatAlpha)
            else
              p:SetAlpha(p._bravRestAlpha or 0)
            end
          end
        end)
      end
    end
  else
    frame._bravMouseover = false
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    frame:EnableMouse(false)
  end
end

function BravBar:Show() self.frame:Show() end
function BravBar:Hide() self.frame:Hide() end

-- ============================================================================
-- PET OVERLAY REFRESH
-- ============================================================================

local function RefreshAllPetBorders()
  if not BravBars.pet then return end
  for _, btn in ipairs(BravBars.pet.buttons) do
    local borders = btn._BravUI_PetActiveBorder
    local idx     = btn._BravUI_PetIdx
    if borders and idx and idx > 0 and GetPetActionInfo then
      local _, _, _, isActive = GetPetActionInfo(idx)
      local active = false
      if isActive ~= nil then
        local ok, result = pcall(function() return isActive == true end)
        active = not ok or result
      end
      for _, b in ipairs(borders) do
        if active then b:Show() else b:Hide() end
      end
    end
  end
end

-- ============================================================================
-- MOVER REGISTRATION (CENTER-based, like UnitFrames)
-- ============================================================================

local function RegisterBarMover(barId, frame)
  local moverName = BAR_MOVER_NAMES[barId]
  if not moverName or not BravUI.Move or not BravUI.Move.Enable then return end
  BravUI.Move.Enable(frame, moverName)
end

-- ============================================================================
-- CREATE ALL BARS
-- ============================================================================

local function CreateBravBars(db)
  for _, bar in pairs(BravBars) do
    if bar.frame then bar.frame:Hide() end
  end
  BravBars = {}

  -- Bars 1-8
  for barId = 1, 8 do
    local config = BAR_CONFIG[barId]
    db.bars = db.bars or {}
    db.bars[config.key] = db.bars[config.key] or {}
    if barId >= 6 and barId <= 8 and db.bars[config.key].enabled == nil then
      db.bars[config.key].enabled = false
    end
    if db.bars[config.key].enabled ~= false then
      local bar = BravBar:Create(barId, db)
      bar:UpdatePosition()
      BravBars[barId] = bar
      RegisterBarMover(barId, bar.frame)
    end
  end

  -- Pet bar
  local petConfig = BAR_CONFIG["pet"]
  db.bars = db.bars or {}
  db.bars[petConfig.key] = db.bars[petConfig.key] or {}
  if db.bars[petConfig.key].enabled ~= false then
    local bar = BravBar:Create("pet", db)
    bar:UpdatePosition()
    BravBars.pet = bar
    RegisterStateDriver(bar.frame, "visibility", "[pet] show; hide")
    RegisterBarMover("pet", bar.frame)

    if PetActionBar_Update and not BravUI._petBarUpdateHooked then
      BravUI._petBarUpdateHooked = true
      hooksecurefunc("PetActionBar_Update", RefreshAllPetBorders)
    end
    if not BravUI._petBarEventFrame then
      local evf = CreateFrame("Frame")
      evf:RegisterEvent("PET_BAR_UPDATE")
      evf:RegisterEvent("UNIT_PET")
      evf:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
      evf:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_PET" and unit ~= "player" then return end
        C_Timer.After(0.15, RefreshAllPetBorders)
      end)
      BravUI._petBarEventFrame = evf
    end
  end

  -- Stance bar
  local stanceConfig = BAR_CONFIG["stance"]
  db.bars = db.bars or {}
  db.bars[stanceConfig.key] = db.bars[stanceConfig.key] or {}
  if db.bars[stanceConfig.key].enabled ~= false then
    local bar = BravBar:Create("stance", db)
    bar:UpdatePosition()
    BravBars.stance = bar
    RegisterBarMover("stance", bar.frame)
  end
end

-- ============================================================================
-- REFRESH BARS (live update from menu)
-- ============================================================================

local function RefreshBars(db)
  if not BravBars then return end
  db.bars = db.bars or {}

  -- Bars 1-8
  for barId = 1, 8 do
    local config = BAR_CONFIG[barId]
    db.bars[config.key] = db.bars[config.key] or {}
    local barDB   = db.bars[config.key]
    local enabled = barDB.enabled ~= false
    local bar     = BravBars[barId]

    if enabled and not bar then
      bar = BravBar:Create(barId, db)
      bar:UpdatePosition()
      BravBars[barId] = bar
      RegisterBarMover(barId, bar.frame)
    elseif not enabled and bar then
      bar.frame:Hide()
    elseif enabled and bar then
      bar.frame:Show()
    end
  end

  -- Pet bar
  local petConfig = BAR_CONFIG["pet"]
  db.bars[petConfig.key] = db.bars[petConfig.key] or {}
  local petEnabled = db.bars[petConfig.key].enabled ~= false
  local petBar     = BravBars.pet
  if petEnabled and not petBar then
    petBar = BravBar:Create("pet", db)
    petBar:UpdatePosition()
    BravBars.pet = petBar
    RegisterStateDriver(petBar.frame, "visibility", "[pet] show; hide")
    RegisterBarMover("pet", petBar.frame)
  elseif not petEnabled and petBar then
    UnregisterStateDriver(petBar.frame, "visibility"); petBar.frame:Hide()
  elseif petEnabled and petBar then
    RegisterStateDriver(petBar.frame, "visibility", "[pet] show; hide")
  end

  -- Stance bar
  local stanceConfig = BAR_CONFIG["stance"]
  db.bars[stanceConfig.key] = db.bars[stanceConfig.key] or {}
  local stanceEnabled = db.bars[stanceConfig.key].enabled ~= false
  local stanceBar     = BravBars.stance
  if stanceEnabled and not stanceBar then
    stanceBar = BravBar:Create("stance", db)
    stanceBar:UpdatePosition()
    BravBars.stance = stanceBar
    RegisterBarMover("stance", stanceBar.frame)
  elseif not stanceEnabled and stanceBar then
    stanceBar.frame:Hide()
  elseif stanceEnabled and stanceBar then
    stanceBar.frame:Show()
  end

  -- Refresh all active bars
  for _, bar in pairs(BravBars) do
    if bar.frame:IsShown() then
      bar.db = db
      for _, button in ipairs(bar.buttons) do
        button._BravUI_DB = db
        button._BravUI_Skinned = nil
        if button._BravUI_Backdrop then
          button._BravUI_Backdrop:Hide()
          button._BravUI_Backdrop = nil
        end
        bar:SkinButton(button)
      end
      bar:UpdatePosition()
    end
  end
end

-- ============================================================================
-- EMPTY SLOT EVENT HANDLER
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
  C_Timer.After(0.1, function()
    local db = GetDB()
    for _, bar in pairs(BravBars) do
      if bar and bar.buttons then
        for _, button in ipairs(bar.buttons) do
          UpdateEmptySlotVisibility(button, db)
        end
      end
    end
  end)
end)

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function ActionBars:Enable()
  local db = GetDB()
  if db.enabled == false then return end

  local function DoEnable()
    if InCombatLockdown() then
      local function OnRegenEnabled()
        BravLib.Event.Unregister("PLAYER_REGEN_ENABLED", OnRegenEnabled)
        DoEnable()
      end
      BravLib.Event.Register("PLAYER_REGEN_ENABLED", OnRegenEnabled)
      return
    end

    CreateBravBars(db)
    HideBlizzardArtwork()

    -- Expose
    BravUI.Frames = BravUI.Frames or {}
    BravUI.Frames.ActionBars = {
      bars    = BravBars,
      Refresh = function() RefreshBars(GetDB()) end,
    }
  end

  -- Defer to PLAYER_LOGIN so Blizzard bar frames are fully created
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    DoEnable()
  end)
end

function ActionBars:Refresh()
  local db = GetDB()
  if db.enabled == false then return end
  RefreshBars(db)
end

function ActionBars:Disable()
  for _, bar in pairs(BravBars) do
    if bar.frame then bar.frame:Hide() end
  end
end

-- BravUI/Core/EscMenu.lua
-- Game Menu (Escape) — visual overlay approach
-- Dark overlays ON TOP of Blizzard buttons/frame.
-- All overlays have EnableMouse(false) so clicks pass through natively.

-- ============================================================================
-- Constants
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"
local BACKDROP_TPL = BackdropTemplateMixin and "BackdropTemplate" or nil

local BG        = { 0.06, 0.06, 0.08, 0.96 }
local BTN_BG    = { 0.14, 0.14, 0.14, 0.95 }
local BTN_HOVER = { 0.20, 0.20, 0.20, 0.95 }
local TEXT_CLR  = { 0.93, 0.93, 0.93, 1 }

-- ============================================================================
-- Helpers
-- ============================================================================

local function GetClassColor()
  return BravUI.Utils.GetClassColor("player")
end

local function GetFont()
  return BravUI.Utils.GetFont()
end

local function SafeSetFont(fs, size, flags)
  if not fs or not fs.SetFont then return end
  local ok = pcall(fs.SetFont, fs, GetFont(), size or 13, flags or "OUTLINE")
  if not ok then
    pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size or 13, flags or "OUTLINE")
  end
end

-- ============================================================================
-- Slash command execution (for BravUI button)
-- ============================================================================

local function FindSlashKey(slash)
  for k, v in pairs(_G) do
    if type(k) == "string" and k:match("^SLASH_") then
      if type(v) == "string" and v == slash then
        local key = k:match("^SLASH_([%w_]+)%d+$")
        if key and SlashCmdList and type(SlashCmdList[key]) == "function" then
          return key
        end
      end
    end
  end
end

local function ExecuteSlashNow(slash)
  local key = FindSlashKey(slash)
  if key then
    local handler = SlashCmdList[key]
    if handler then
      pcall(handler, "")
      return true
    end
  end
  return false
end

-- ============================================================================
-- State
-- ============================================================================

local backdrop
local overlayMap = {}
local lastHovered = nil

-- ============================================================================
-- Backdrop
-- ============================================================================

local function EnsureBackdrop()
  if backdrop then return end

  backdrop = CreateFrame("Frame", "BravUI_GameMenu_BD", GameMenuFrame, BACKDROP_TPL)
  backdrop:SetAllPoints()
  backdrop:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 1)
  backdrop:EnableMouse(false)
  backdrop:SetBackdrop({ bgFile = TEX, edgeFile = TEX, edgeSize = 1 })
  backdrop:SetBackdropColor(unpack(BG))

  if GameMenuFrame.Header then
    local hc = CreateFrame("Frame", nil, GameMenuFrame, BACKDROP_TPL)
    hc:SetPoint("TOPLEFT", GameMenuFrame.Header, "TOPLEFT", 8, -2)
    hc:SetPoint("BOTTOMRIGHT", GameMenuFrame.Header, "BOTTOMRIGHT", -8, 12)
    hc:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 55)
    hc:EnableMouse(false)
    hc:SetBackdrop({ bgFile = TEX, edgeFile = TEX, edgeSize = 1 })
    hc:SetBackdropColor(0.06, 0.06, 0.08, 1)
    hc:SetBackdropBorderColor(0, 0, 0, 0)
    backdrop._headerCover = hc
  end

  local titleFrame = CreateFrame("Frame", nil, GameMenuFrame)
  titleFrame:SetAllPoints()
  titleFrame:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 60)
  titleFrame:EnableMouse(false)
  local title = titleFrame:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOP", GameMenuFrame, "TOP", 0, 5)
  backdrop._title = title
  backdrop._titleFrame = titleFrame
end

-- ============================================================================
-- Strip Blizzard visuals
-- ============================================================================

local STRIP_KEYS = {
  "Left", "Middle", "Right", "Mid",
  "LeftDisabled", "MiddleDisabled", "RightDisabled",
  "TopLeft", "TopRight", "BottomLeft", "BottomRight",
  "TopMiddle", "MiddleLeft", "MiddleRight",
  "BottomMiddle", "MiddleMiddle",
  "Border", "Background", "Cover",
}

local function StripRegions(frame)
  if not frame or not frame.GetRegions then return end
  for _, region in pairs({ frame:GetRegions() }) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      pcall(region.SetAlpha, region, 0)
    end
  end
end

local function KillTexture(tex)
  if not tex then return end
  pcall(function()
    tex:SetAlpha(0)
    tex:SetVertexColor(0, 0, 0, 0)
  end)
end

local function StripButton(btn)
  if not btn then return end
  for _, key in ipairs(STRIP_KEYS) do
    if btn[key] then KillTexture(btn[key]) end
  end
  KillTexture(btn:GetNormalTexture())
  KillTexture(btn:GetPushedTexture())
  KillTexture(btn:GetDisabledTexture())
  KillTexture(btn:GetHighlightTexture())
  StripRegions(btn)
  local fs = btn:GetFontString()
  if fs then pcall(fs.SetAlpha, fs, 0) end
end

local function StripBlizzardVisuals()
  if not GameMenuFrame then return end

  if GameMenuFrame.NineSlice then
    pcall(GameMenuFrame.NineSlice.SetAlpha, GameMenuFrame.NineSlice, 0)
  end
  StripRegions(GameMenuFrame)

  if GameMenuFrame.Header then
    pcall(GameMenuFrame.Header.SetAlpha, GameMenuFrame.Header, 0)
    if GameMenuFrame.Header.NineSlice then
      pcall(GameMenuFrame.Header.NineSlice.Hide, GameMenuFrame.Header.NineSlice)
    end
    StripRegions(GameMenuFrame.Header)
    if GameMenuFrame.Header.GetChildren then
      for _, child in pairs({ GameMenuFrame.Header:GetChildren() }) do
        if child and not child.SetBackdropBorderColor then
          pcall(child.SetAlpha, child, 0)
        end
      end
    end
  end

  if GameMenuFrame.buttonPool then
    for btn in GameMenuFrame.buttonPool:EnumerateActive() do
      StripButton(btn)
    end
  end
  local container = GameMenuFrame.ButtonContainer or GameMenuFrame
  if container.GetChildren then
    for _, child in pairs({ container:GetChildren() }) do
      if child and child:IsObjectType("Button") then
        StripButton(child)
      end
    end
  end

  local function KillBadges(frame)
    if not frame then return end
    if frame.GetRegions then
      for _, r in pairs({ frame:GetRegions() }) do
        pcall(function()
          if r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if t and type(t) == "string" then
              local up = t:upper():gsub("%s+", "")
              if up == "NOUVEAU" or up == "NEW" then
                r:SetAlpha(0)
                r:SetText("")
              end
            end
          end
        end)
      end
    end
    if frame.GetChildren then
      for _, child in pairs({ frame:GetChildren() }) do
        if child then
          pcall(function()
            if child.GetText then
              local t = child:GetText()
              if t and type(t) == "string" then
                local up = t:upper():gsub("%s+", "")
                if up == "NOUVEAU" or up == "NEW" then
                  child:SetAlpha(0)
                end
              end
            end
          end)
          KillBadges(child)
        end
      end
    end
  end
  KillBadges(GameMenuFrame)
end

-- ============================================================================
-- Button overlay
-- ============================================================================

local function ApplyHover(ov)
  local cr, cg, cb = GetClassColor()
  ov:SetBackdropBorderColor(cr, cg, cb, 0.85)
  ov:SetBackdropColor(unpack(BTN_HOVER))
  if ov._fs then ov._fs:SetTextColor(cr, cg, cb, 1) end
end

local function ApplyNormal(ov)
  ov:SetBackdropBorderColor(0, 0, 0, 0.9)
  ov:SetBackdropColor(unpack(BTN_BG))
  if ov._fs then ov._fs:SetTextColor(unpack(TEXT_CLR)) end
end

local function StyleButton(btn)
  if not btn or not btn.GetObjectType then return end
  if btn:GetObjectType() ~= "Button" then return end

  local ov = overlayMap[btn]
  if not ov then
    ov = CreateFrame("Frame", nil, btn, BACKDROP_TPL)
    ov:SetAllPoints()
    ov:SetFrameLevel(btn:GetFrameLevel() + 10)
    ov:EnableMouse(false)
    ov:SetBackdrop({ bgFile = TEX, edgeFile = TEX, edgeSize = 1 })

    local fs = ov:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    ov._fs = fs

    overlayMap[btn] = ov
  end

  local text = ""
  pcall(function() text = btn:GetText() or "" end)
  SafeSetFont(ov._fs, 13, "OUTLINE")
  ov._fs:SetText(text)

  if btn.IsMouseOver and btn:IsMouseOver() then
    ApplyHover(ov)
  else
    ApplyNormal(ov)
  end

  ov:Show()
end

-- ============================================================================
-- Hover ticker
-- ============================================================================

local hoverTicker = CreateFrame("Frame")
hoverTicker:Hide()
hoverTicker:SetScript("OnUpdate", function()
  local hovered = nil
  for btn, ov in pairs(overlayMap) do
    if btn:IsShown() and btn.IsMouseOver and btn:IsMouseOver() then
      hovered = btn
      break
    end
  end

  if hovered == lastHovered then return end

  if lastHovered then
    local ov = overlayMap[lastHovered]
    if ov then ApplyNormal(ov) end
  end

  if hovered then
    local ov = overlayMap[hovered]
    if ov then ApplyHover(ov) end
  end

  lastHovered = hovered
end)

-- ============================================================================
-- Style all buttons
-- ============================================================================

local function StyleAllButtons()
  if not GameMenuFrame then return end

  if GameMenuFrame.buttonPool then
    for btn in GameMenuFrame.buttonPool:EnumerateActive() do
      StyleButton(btn)
    end
  end

  local container = GameMenuFrame.ButtonContainer or GameMenuFrame
  if container.GetChildren then
    for _, child in pairs({ container:GetChildren() }) do
      if child and child:IsObjectType("Button") then
        StyleButton(child)
      end
    end
  end
end

-- ============================================================================
-- BravUI button in game menu
-- ============================================================================

local function GetChildren(frame)
  local t = {}
  if not frame then return t end
  local i = 1
  while true do
    local child = select(i, frame:GetChildren())
    if not child then break end
    t[#t + 1] = child
    i = i + 1
  end
  return t
end

local function FindAddonsButton(container)
  if not container then return nil end
  if _G.GameMenuButtonAddons and _G.GameMenuButtonAddons:GetParent() == container then
    return _G.GameMenuButtonAddons
  end
  if ADDONS then
    for _, c in ipairs(GetChildren(container)) do
      if c.GetText then
        local ok, t = pcall(c.GetText, c)
        if ok and t == ADDONS then return c end
      end
    end
  end
  return nil
end

local function EnsureBravUIButton()
  if not GameMenuFrame then return end

  local container = GameMenuFrame.ButtonContainer or GameMenuFrame
  local addonsBtn = FindAddonsButton(container)
  if not addonsBtn then return end

  local btn = _G.GameMenuButtonBravUI
  if not btn then
    local template = GameMenuFrame.buttonTemplate
    if not template or template == "" then
      template = "MainMenuFrameButtonTemplate"
    end

    local ok, result = pcall(CreateFrame, "Button", "GameMenuButtonBravUI", container, template)
    if not ok then
      result = CreateFrame("Button", "GameMenuButtonBravUI", container)
      if result.SetNormalFontObject then
        result:SetNormalFontObject("GameFontNormalLarge")
      end
    end

    btn = result
    _G.GameMenuButtonBravUI = btn

    btn:SetText("BravUI")
    btn:SetScript("OnClick", function()
      HideUIPanel(GameMenuFrame)
      ExecuteSlashNow("/brav")
    end)
  else
    if btn:GetParent() ~= container then
      btn:SetParent(container)
    end
  end

  btn:Show()
  StyleButton(btn)

  local ov = overlayMap[btn]
  if ov then
    if not ov._accent then
      local accent = ov:CreateTexture(nil, "OVERLAY")
      accent:SetHeight(2)
      accent:SetPoint("BOTTOMLEFT", 1, 1)
      accent:SetPoint("BOTTOMRIGHT", -1, 1)
      ov._accent = accent
    end
    local cr, cg, cb = GetClassColor()
    ov._accent:SetColorTexture(cr, cg, cb, 0.65)
    ov._accent:Show()
  end

  local buttons = {}
  for _, c in ipairs(GetChildren(container)) do
    if c ~= btn and c.layoutIndex and type(c.layoutIndex) == "number" then
      buttons[#buttons + 1] = c
    end
  end

  table.sort(buttons, function(a, b)
    return (a.layoutIndex or 0) < (b.layoutIndex or 0)
  end)

  local idx = 1
  local inserted = false
  for _, b in ipairs(buttons) do
    if b == addonsBtn and not inserted then
      btn.layoutIndex = idx
      idx = idx + 1
      inserted = true
    end
    b.layoutIndex = idx
    idx = idx + 1
  end
  if not inserted then
    btn.layoutIndex = idx
  end

  GameMenuFrame.dirty = true
  if GameMenuFrame.Layout then
    GameMenuFrame:Layout()
  elseif GameMenuFrame_UpdateVisibleButtons then
    GameMenuFrame_UpdateVisibleButtons()
  end
end

-- ============================================================================
-- Full style pass
-- ============================================================================

local function FullStyle()
  EnsureBackdrop()
  StripBlizzardVisuals()

  local cr, cg, cb = GetClassColor()
  backdrop:SetBackdropBorderColor(cr, cg, cb, 0.85)

  if backdrop._headerCover then
    backdrop._headerCover:SetBackdropBorderColor(cr, cg, cb, 0.85)
  end

  local titleText = "Menu de jeu"
  pcall(function()
    local ht = GameMenuFrame.Header and (GameMenuFrame.Header.Text or GameMenuFrame.Header.text)
    if ht then
      local t = ht:GetText()
      if t and type(t) == "string" and t ~= "" then titleText = t end
    end
  end)
  SafeSetFont(backdrop._title, 14, "OUTLINE")
  backdrop._title:SetText(titleText)
  backdrop._title:SetTextColor(cr, cg, cb, 1)

  StyleAllButtons()
  EnsureBravUIButton()
end

-- ============================================================================
-- Init
-- ============================================================================

local function Init()
  if not GameMenuFrame then return end

  GameMenuFrame:HookScript("OnShow", function()
    FullStyle()
    lastHovered = nil
    hoverTicker:Show()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if GameMenuFrame:IsShown() then
          FullStyle()
        end
      end)
    end
  end)

  GameMenuFrame:HookScript("OnHide", function()
    hoverTicker:Hide()
    lastHovered = nil
  end)

  if GameMenuFrame.InitButtons then
    hooksecurefunc(GameMenuFrame, "InitButtons", function()
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          if GameMenuFrame:IsShown() then
            StyleAllButtons()
          end
        end)
      end
    end)
  end
end

-- ============================================================================
-- Boot
-- ============================================================================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(0.5, Init)
end)

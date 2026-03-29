-- BravUI_Menu/Core/Wizard.lua
-- First-install wizard (single-frame, 3 steps)
-- Animated transitions: fade + slide between steps

local M = BravUI.Menu
local T = M.Theme
local U = BravUI.Utils
local L = M.L

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

local FADE_IN_DURATION  = 0.25
local FADE_OUT_DURATION = 0.15
local SLIDE_PX          = 25
local CONTENT_X         = 30

local function SafePlay(ag)
  if not ag then return false end
  local ok = pcall(ag.Play, ag)
  return ok
end

local function SetupFadeIn(frame, duration)
  local ok, ag = pcall(function()
    local g = frame:CreateAnimationGroup()
    local alpha = g:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(duration or FADE_IN_DURATION)
    alpha:SetSmoothing("OUT")
    g:SetScript("OnFinished", function() frame:SetAlpha(1) end)
    return g
  end)
  return ok and ag or nil
end

local function SetupFadeOut(frame, duration)
  local ok, ag = pcall(function()
    local g = frame:CreateAnimationGroup()
    local alpha = g:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(duration or FADE_OUT_DURATION)
    alpha:SetSmoothing("IN")
    g:SetScript("OnFinished", function() frame:SetAlpha(0) end)
    return g
  end)
  return ok and ag or nil
end

-- ============================================================================
-- CHOICE BUTTON
-- ============================================================================

local function CreateChoiceButton(parent, text, subtext, cr, cg, cb)
  local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  btn:SetSize(185, 50)
  btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  btn:SetBackdropColor(unpack(T.BTN))
  btn:SetBackdropBorderColor(unpack(T.BORDER))

  local label = btn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(label, 13, "OUTLINE")
  label:SetPoint("CENTER", 0, subtext and 6 or 0)
  label:SetText(text)
  label:SetTextColor(unpack(T.TEXT))
  btn._label = label

  if subtext then
    local sub = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(sub, 9, "OUTLINE")
    sub:SetPoint("CENTER", 0, -10)
    sub:SetText(subtext)
    sub:SetTextColor(unpack(T.MUTED))
  end

  btn._selected = false

  function btn:SetSelected(sel)
    self._selected = sel
    if sel then
      self:SetBackdropColor(cr * 0.20, cg * 0.20, cb * 0.20, 0.95)
      self:SetBackdropBorderColor(cr, cg, cb, 0.60)
      self._label:SetTextColor(cr, cg, cb, 1)
    else
      self:SetBackdropColor(unpack(T.BTN))
      self:SetBackdropBorderColor(unpack(T.BORDER))
      self._label:SetTextColor(unpack(T.TEXT))
    end
  end

  btn:SetScript("OnEnter", function(self)
    if not self._selected then
      self:SetBackdropColor(unpack(T.BTN_HOVER))
      self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
    end
  end)
  btn:SetScript("OnLeave", function(self)
    if not self._selected then
      self:SetBackdropColor(unpack(T.BTN))
      self:SetBackdropBorderColor(unpack(T.BORDER))
    end
  end)

  return btn
end

-- ============================================================================
-- WIPE CONTENT
-- ============================================================================

local function WipeContent(content)
  for _, child in ipairs({ content:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({ content:GetRegions() }) do
    region:Hide()
  end
end

-- ============================================================================
-- STEP INDICATOR (3 dots)
-- ============================================================================

local function CreateStepIndicator(parent, cr, cg, cb)
  local dots = {}
  local DOT_SIZE = 8
  local DOT_GAP = 12
  local totalW = 2 * DOT_SIZE + 1 * DOT_GAP

  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(totalW, DOT_SIZE)
  holder:SetPoint("BOTTOM", parent, "BOTTOM", 0, 62)

  for i = 1, 2 do
    local dot = holder:CreateTexture(nil, "ARTWORK")
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetPoint("LEFT", holder, "LEFT", (i - 1) * (DOT_SIZE + DOT_GAP), 0)
    dots[i] = dot
  end

  local indicator = { holder = holder, dots = dots }

  function indicator:SetStep(step)
    for i, dot in ipairs(self.dots) do
      if i == step then
        dot:SetColorTexture(cr, cg, cb, 0.90)
      elseif i < step then
        dot:SetColorTexture(cr, cg, cb, 0.30)
      else
        dot:SetColorTexture(0.3, 0.3, 0.3, 0.40)
      end
    end
  end

  return indicator
end

-- ============================================================================
-- STEP BUILDERS
-- ============================================================================

local function BuildStep1_Welcome(wiz)
  local cr, cg, cb = M:GetClassColor()
  local c = wiz.content

  wiz.title:SetText(L["wiz_step1_title"])
  wiz.subtitle:SetText(L["wiz_step1_subtitle"])

  local logo = c:CreateTexture(nil, "ARTWORK")
  logo:SetSize(48, 48)
  logo:SetPoint("TOP", c, "TOP", 0, 0)
  logo:SetTexture("Interface/AddOns/BravUI_Lib/BravLib_Media/Logo/BravUI_64x64")

  local msg = c:CreateFontString(nil, "OVERLAY")
  M:SafeFont(msg, 11, "OUTLINE")
  msg:SetPoint("TOP", logo, "BOTTOM", 0, -16)
  msg:SetWidth(380)
  msg:SetJustifyH("CENTER")
  msg:SetText(L["wiz_step1_message"])
  msg:SetTextColor(0.80, 0.80, 0.80, 1)

  local label = wiz.continueBtn._label
  label:SetText(L["wiz_continue"])
  label:SetTextColor(cr, cg, cb, 1)
end

local function BuildStep2_Profile(wiz)
  local cr, cg, cb = M:GetClassColor()
  local c = wiz.content
  wiz._selectedProfile = "personal"

  wiz.title:SetText(L["wiz_step3_title"] or "Profil")
  wiz.subtitle:SetText(L["wiz_step3_subtitle"] or "")

  local TEXTS = {
    personal = L["wiz_step3_desc_perso"] or "",
    global   = L["wiz_step3_desc_global"] or "",
  }

  local desc = c:CreateFontString(nil, "OVERLAY")
  M:SafeFont(desc, 11, "OUTLINE")
  desc:SetPoint("TOP", c, "TOP", 0, 0)
  desc:SetWidth(400)
  desc:SetJustifyH("CENTER")
  desc:SetTextColor(0.80, 0.80, 0.80, 1)
  desc:SetSpacing(2)

  local btnPerso = CreateChoiceButton(c, L["wiz_step3_btn_perso"] or "Personnel", L["wiz_step3_btn_perso_sub"], cr, cg, cb)
  btnPerso:SetPoint("LEFT", c, "CENTER", -195, -24)

  local btnGlobal = CreateChoiceButton(c, L["wiz_step3_btn_global"] or "Global", L["wiz_step3_btn_global_sub"], cr, cg, cb)
  btnGlobal:SetPoint("LEFT", btnPerso, "RIGHT", 10, 0)

  local function Select(choice)
    wiz._selectedProfile = choice
    btnPerso:SetSelected(choice == "personal")
    btnGlobal:SetSelected(choice == "global")
    desc:SetText(TEXTS[choice] or TEXTS.personal)
  end

  btnPerso:SetScript("OnClick", function() Select("personal") end)
  btnGlobal:SetScript("OnClick", function() Select("global") end)
  Select("personal")

  local label = wiz.continueBtn._label
  label:SetText(L["wiz_finish"] or "Terminer")
  label:SetTextColor(cr, cg, cb, 1)
end

local BUILDERS = { BuildStep1_Welcome, BuildStep2_Profile }

-- ============================================================================
-- APPLY PROFILE (step 3 logic)
-- ============================================================================

local function ApplyProfileChoice(wiz)
  local Storage = BravLib.Storage

  if wiz._selectedProfile == "personal" then
    -- Mode per-character
    Storage.SetProfileMode("perChar")

    -- Creer un profil au nom du personnage
    local nameOk, charKey = pcall(function()
      return UnitName("player") .. " - " .. GetRealmName()
    end)
    if nameOk and charKey then
      if not Storage.GetRawDB().profiles[charKey] then
        Storage.CreateProfile(charKey, "Default")
      end
      Storage.SetActiveProfile(charKey)
      BravLib.Print(format(L["wiz_profile_personal_msg"] or "Personal profile active: %s", charKey))
    end
  else
    -- Mode global : creer un profil "Global" et l'utiliser pour tous les chars
    Storage.SetProfileMode("global")
    if not Storage.GetRawDB().profiles["Global"] then
      Storage.CreateProfile("Global", "Default")
    end
    Storage.SetGlobalProfileName("Global")
    Storage.SetActiveProfile("Global")
    BravLib.Print(L["wiz_profile_global_msg"] or "Global profile active.")
  end
end

-- ============================================================================
-- STEP TRANSITION (animated)
-- ============================================================================

local function NextStep(wiz)
  if wiz._transitioning then return end

  wiz.step = wiz.step + 1

  if wiz.step == 2 then
    BravUI_DB = BravUI_DB or {}
    BravUI_DB.global = BravUI_DB.global or {}
    BravUI_DB.global._welcomeSeen = true
  end

  if wiz.step > 2 then
    ApplyProfileChoice(wiz)

    if M.InvalidatePageCache then M:InvalidatePageCache() end
    if M.Frame then
      if M.Frame.RebuildSidebar then M.Frame:RebuildSidebar() end
      local active = M.GetActivePage and M:GetActivePage()
      if active and M.Frame.OpenPage then M.Frame:OpenPage(active) end
    end

    if wiz._overlayFadeOut then
      wiz._transitioning = true
      wiz._overlayFadeOut:SetScript("OnFinished", function()
        wiz.overlay:Hide()
        wiz.overlay:SetAlpha(1)
        wiz._transitioning = false
      end)
      if not SafePlay(wiz._overlayFadeOut) then
        wiz.overlay:Hide()
        wiz._transitioning = false
      end
    else
      wiz.overlay:Hide()
    end
    return
  end

  local function BuildStepContent()
    WipeContent(wiz.content)
    BUILDERS[wiz.step](wiz)
    if wiz.stepIndicator then
      wiz.stepIndicator:SetStep(wiz.step)
    end
  end

  if wiz.step > 1 then
    wiz._transitioning = true
    local c = wiz.content
    local f = wiz.frame
    local elapsed = 0
    local phase = "out"

    SafePlay(wiz._titleFadeOut)

    c:SetScript("OnUpdate", function(self, dt)
      elapsed = elapsed + dt

      if phase == "out" then
        local p = math.min(elapsed / FADE_OUT_DURATION, 1)
        local e = p * p
        self:SetAlpha(1 - e)
        self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X - SLIDE_PX * e, -80)
        if p >= 1 then
          phase = "in"
          elapsed = 0
          self:SetAlpha(0)
          BuildStepContent()
          self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X + SLIDE_PX, -80)
          if wiz._titleFadeIn and wiz._titleHolder then
            wiz._titleHolder:SetAlpha(0)
            if not SafePlay(wiz._titleFadeIn) then
              wiz._titleHolder:SetAlpha(1)
            end
          end
        end

      elseif phase == "in" then
        local p = math.min(elapsed / FADE_IN_DURATION, 1)
        local e = 1 - (1 - p) * (1 - p)
        self:SetAlpha(e)
        self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X + SLIDE_PX * (1 - e), -80)
        if p >= 1 then
          self:SetAlpha(1)
          self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -80)
          self:SetScript("OnUpdate", nil)
          wiz._transitioning = false
          if wiz.backBtn then wiz.backBtn:SetShown(wiz.step > 1) end
        end
      end
    end)
  else
    BuildStepContent()
    if wiz.backBtn then wiz.backBtn:Hide() end
  end
end

-- ============================================================================
-- PREV STEP (reverse animated transition)
-- ============================================================================

local function PrevStep(wiz)
  if wiz._transitioning then return end
  if wiz.step <= 1 then return end

  wiz.step = wiz.step - 1

  local function BuildContent()
    WipeContent(wiz.content)
    BUILDERS[wiz.step](wiz)
    if wiz.stepIndicator then
      wiz.stepIndicator:SetStep(wiz.step)
    end
  end

  wiz._transitioning = true
  local c = wiz.content
  local f = wiz.frame
  local elapsed = 0
  local phase = "out"

  SafePlay(wiz._titleFadeOut)

  c:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt

    if phase == "out" then
      local p = math.min(elapsed / FADE_OUT_DURATION, 1)
      local e = p * p
      self:SetAlpha(1 - e)
      self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X + SLIDE_PX * e, -80)
      if p >= 1 then
        phase = "in"
        elapsed = 0
        self:SetAlpha(0)
        BuildContent()
        self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X - SLIDE_PX, -80)
        if wiz._titleFadeIn and wiz._titleHolder then
          wiz._titleHolder:SetAlpha(0)
          if not SafePlay(wiz._titleFadeIn) then
            wiz._titleHolder:SetAlpha(1)
          end
        end
      end

    elseif phase == "in" then
      local p = math.min(elapsed / FADE_IN_DURATION, 1)
      local e = 1 - (1 - p) * (1 - p)
      self:SetAlpha(e)
      self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X - SLIDE_PX * (1 - e), -80)
      if p >= 1 then
        self:SetAlpha(1)
        self:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -80)
        self:SetScript("OnUpdate", nil)
        wiz._transitioning = false
        if wiz.backBtn then wiz.backBtn:SetShown(wiz.step > 1) end
      end
    end
  end)
end

-- ============================================================================
-- CREATE WIZARD FRAME
-- ============================================================================

local function CreateWizardFrame()
  local cr, cg, cb = M:GetClassColor()
  local wiz = {}

  local overlay = CreateFrame("Frame", "BravUI_WizardOverlay", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:SetFrameLevel(950)
  overlay:EnableMouse(true)

  local shade = overlay:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  shade:SetColorTexture(0, 0, 0, 0.65)
  wiz.overlay = overlay

  wiz._overlayFadeIn = SetupFadeIn(overlay, 0.15)
  wiz._overlayFadeOut = SetupFadeOut(overlay, 0.20)

  local f = CreateFrame("Frame", "BravUI_WizardFrame", overlay, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(480, 300)
  f:SetPoint("CENTER", 0, 40)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(951)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  f:SetBackdropColor(unpack(T.BG))
  f:SetBackdropBorderColor(cr, cg, cb, 0.50)
  wiz.frame = f

  -- Close button
  local closeBtn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  closeBtn:SetSize(28, 24)
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  closeBtn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  closeBtn:SetBackdropColor(0.25, 0.05, 0.05, 0.90)
  closeBtn:SetBackdropBorderColor(unpack(T.BORDER))

  local xLabel = closeBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(xLabel, 11, "OUTLINE")
  xLabel:SetPoint("CENTER", 0, 0)
  xLabel:SetText("X")
  xLabel:SetTextColor(0.90, 0.30, 0.30, 1)

  closeBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.40, 0.08, 0.08, 1)
    self:SetBackdropBorderColor(0.90, 0.30, 0.30, 0.50)
  end)
  closeBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.25, 0.05, 0.05, 0.90)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)
  closeBtn:SetScript("OnClick", function()
    if wiz._overlayFadeOut then
      wiz._overlayFadeOut:SetScript("OnFinished", function()
        overlay:Hide()
        overlay:SetAlpha(1)
      end)
      if not SafePlay(wiz._overlayFadeOut) then
        overlay:Hide()
      end
    else
      overlay:Hide()
    end
  end)
  wiz.closeBtn = closeBtn

  -- Title holder
  local titleHolder = CreateFrame("Frame", nil, f)
  titleHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  titleHolder:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  titleHolder:SetHeight(68)
  wiz._titleHolder = titleHolder
  wiz._titleFadeIn = SetupFadeIn(titleHolder, 0.35)
  wiz._titleFadeOut = SetupFadeOut(titleHolder, 0.15)

  local title = titleHolder:CreateFontString(nil, "OVERLAY")
  M:SafeFont(title, 15, "OUTLINE")
  title:SetPoint("TOP", f, "TOP", 0, -24)
  title:SetTextColor(cr, cg, cb, 1)
  wiz.title = title

  local subtitle = titleHolder:CreateFontString(nil, "OVERLAY")
  M:SafeFont(subtitle, 10, "OUTLINE")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
  subtitle:SetTextColor(unpack(T.MUTED))
  wiz.subtitle = subtitle

  local div = f:CreateTexture(nil, "ARTWORK")
  div:SetHeight(1)
  div:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -68)
  div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -68)
  div:SetColorTexture(cr, cg, cb, 0.25)
  wiz.divider = div

  -- Content area
  local content = CreateFrame("Frame", nil, f)
  content:SetSize(420, 160)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -80)
  wiz.content = content

  wiz.stepIndicator = CreateStepIndicator(f, cr, cg, cb)

  -- Continue button
  local contBtn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  contBtn:SetSize(160, 32)
  contBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 22)
  contBtn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  contBtn:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.90)
  contBtn:SetBackdropBorderColor(unpack(T.BORDER))

  local contLabel = contBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(contLabel, 12, "OUTLINE")
  contLabel:SetPoint("CENTER", 0, 0)
  contLabel:SetText(L["wiz_continue"])
  contLabel:SetTextColor(cr, cg, cb, 1)
  contBtn._label = contLabel

  contBtn:SetScript("OnEnter", function(self)
    local r, g, b = M:GetClassColor()
    self:SetBackdropColor(r * 0.25, g * 0.25, b * 0.25, 1)
    self:SetBackdropBorderColor(r, g, b, 0.50)
  end)
  contBtn:SetScript("OnLeave", function(self)
    local r, g, b = M:GetClassColor()
    self:SetBackdropColor(r * 0.15, g * 0.15, b * 0.15, 0.90)
    self:SetBackdropBorderColor(unpack(T.BORDER))
  end)
  contBtn:SetScript("OnClick", function() NextStep(wiz) end)
  wiz.continueBtn = contBtn

  -- Back button
  local backBtn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  backBtn:SetSize(32, 32)
  backBtn:SetPoint("RIGHT", contBtn, "LEFT", -8, 0)
  backBtn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
  backBtn:SetBackdropColor(unpack(T.BTN))
  backBtn:SetBackdropBorderColor(unpack(T.BORDER))
  backBtn:Hide()

  local backLabel = backBtn:CreateFontString(nil, "OVERLAY")
  M:SafeFont(backLabel, 14, "OUTLINE")
  backLabel:SetPoint("CENTER", 0, 0)
  backLabel:SetText("<")
  backLabel:SetTextColor(unpack(T.MUTED))

  backBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(unpack(T.BTN_HOVER))
    self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
    backLabel:SetTextColor(unpack(T.TEXT))
  end)
  backBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(unpack(T.BTN))
    self:SetBackdropBorderColor(unpack(T.BORDER))
    backLabel:SetTextColor(unpack(T.MUTED))
  end)
  backBtn:SetScript("OnClick", function() PrevStep(wiz) end)
  wiz.backBtn = backBtn

  wiz.step = 0
  wiz._transitioning = false
  return wiz
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M:ShowWizard()
  if not self._wizard then
    local ok, result = pcall(CreateWizardFrame)
    if not ok then
      BravLib.Warn("Wizard: " .. tostring(result))
      return
    end
    self._wizard = result
  end

  local wiz = self._wizard
  if not wiz or not wiz.overlay then return end

  wiz.step = 0
  wiz._transitioning = false
  wiz.content:SetScript("OnUpdate", nil)
  wiz.content:SetAlpha(1)
  wiz.content:SetPoint("TOPLEFT", wiz.frame, "TOPLEFT", CONTENT_X, -80)
  WipeContent(wiz.content)
  NextStep(wiz)

  wiz.overlay:SetAlpha(1)
  wiz.overlay:Show()
  if wiz._overlayFadeIn then
    wiz.overlay:SetAlpha(0)
    if not SafePlay(wiz._overlayFadeIn) then
      wiz.overlay:SetAlpha(1)
    end
  end
end

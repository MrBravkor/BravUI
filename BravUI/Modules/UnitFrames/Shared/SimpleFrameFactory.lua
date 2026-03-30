-- BravUI/Modules/UnitFrames/SimpleFrameFactory.lua
-- Factory pour les frames simples HP+Power+Nom (Focus, Pet, TargetOfTarget).
-- Élimine ~650 lignes de code quasi-identique sur 3 fichiers.
--
-- Champs de cfg :
--   unit            (string)    unité WoW, ex. "focus"
--   dbKey           (string)    clé DB sous unitframes.*, ex. "focus"
--   frameName       (string)    clé dans BravUI.Frames[frameName], ex. "Focus"
--   globalName      (string)    nom global du SecureActionButton (click overlay)
--   defaultPos      (table)     {x, y} offset de l'ancre CENTER
--   defaultW        (number)
--   defaultHpH      (number)
--   defaultPwrH     (number)
--   textSizes       (table)     {name, hp, pwr}, optionnel
--   throttleRate    (number)    intervalle du dirty-flush, défaut 0.1
--   deadText        (string)    texte affiché quand l'unité est morte
--   previewName     (string)    nom affiché en mode aperçu
--   previewHp       (number)    valeur HP aperçu (0-100)
--   previewHpText   (string)    libellé HP aperçu (override optionnel)
--   previewPwr      (number)    valeur power aperçu (0-100)
--   previewPwrText  (string)    libellé power aperçu (override optionnel)
--   previewUseClass (bool)      true = couleur de classe du joueur pour la HP bar en aperçu
--   previewHpColor  (table)     {r,g,b} couleur HP aperçu (fallback si classe indisponible)
--   extraHideCheck  (function)  () → bool ; condition de masquage supplémentaire
--   extraEvents     (table)     events supplémentaires à enregistrer
--   onExtraEvent    (function)  (event, unit, ctx) → bool ; return true = géré (pas de vérif unit)
--   publicFnName    (string)    nom de la méthode BravUI, ex. "UpdateFocusUF"
--
-- ctx passé à onExtraEvent :
--   ctx.ApplyFromDB, ctx.Update, ctx.MarkDirty, ctx.SyncClickOverlay

BravUI.SimpleFrameFactory = {}

local U              = BravUI.Utils
local TEX            = "Interface/Buttons/WHITE8x8"
local Abbrev         = U.AbbrevForSetText
local SafeUnitExists = U.SafeUnitExists
local SafeUnitIsDead = U.SafeUnitIsDead
local WriteNameToFS  = U.WriteNameToFS

function BravUI.SimpleFrameFactory.Create(cfg)
  local UNIT      = cfg.unit
  local DB_KEY    = cfg.dbKey
  local DEF_W     = cfg.defaultW    or 180
  local HP_H      = cfg.defaultHpH  or 22
  local PWR_H     = cfg.defaultPwrH or 8
  local GAP       = 0
  local DEAD_TEXT = cfg.deadText    or "Dead"
  local THROTTLE  = cfg.throttleRate or 0.1
  local TS_NAME   = (cfg.textSizes and cfg.textSizes.name) or 11
  local TS_HP     = (cfg.textSizes and cfg.textSizes.hp)   or 11
  local TS_PWR    = (cfg.textSizes and cfg.textSizes.pwr)  or 9

  local previewHpR, previewHpG, previewHpB = 0.2, 0.8, 0.2
  if cfg.previewHpColor then
    previewHpR = cfg.previewHpColor[1]
    previewHpG = cfg.previewHpColor[2]
    previewHpB = cfg.previewHpColor[3]
  end

  -- ============================================================================
  -- DB
  -- ============================================================================
  local GetConfig, _, _, GetColorConfig, GetTextConfig = U.MakeConfigGetters(DB_KEY)

  -- ============================================================================
  -- ROOT FRAME
  -- ============================================================================
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(DEF_W, HP_H + PWR_H)
  f:SetPoint("CENTER", UIParent, "CENTER", cfg.defaultPos.x, cfg.defaultPos.y)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetAlpha(0)

  local function ShowFrame() f:SetAlpha(1) end
  local function HideFrame() f:SetAlpha(0) end

  -- ============================================================================
  -- CLICK OVERLAY
  -- ============================================================================
  local clickOverlay = U.CreateClickOverlay(cfg.globalName, UNIT)

  local function SyncClickOverlay()
    U.SyncClickOverlay(clickOverlay, f)
  end

  SyncClickOverlay()
  U.HookOverlaySync(f, SyncClickOverlay, { moverGuard = true })

  -- ============================================================================
  -- HP BAR
  -- ============================================================================
  local hpFrame = CreateFrame("Frame", nil, f)
  hpFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
  hpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  hpFrame:SetHeight(HP_H)
  hpFrame:EnableMouse(false)

  local hp          = U.CreateBar(hpFrame, TEX)
  local hpNameText  = U.CreateText(hp, "LEFT",  "LEFT",  TS_NAME,  4, 0)
  local hpValueText = U.CreateText(hp, "RIGHT", "RIGHT", TS_HP,   -4, 0)

  -- ============================================================================
  -- POWER BAR
  -- ============================================================================
  local powerFrame = CreateFrame("Frame", nil, f)
  powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, -GAP)
  powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, -GAP)
  powerFrame:SetHeight(PWR_H)
  powerFrame:EnableMouse(false)

  local power     = U.CreateBar(powerFrame, TEX)
  local powerText = U.CreateText(power, "CENTER", "CENTER", TS_PWR, 0, 0)

  -- ============================================================================
  -- NAMESPACE
  -- ============================================================================
  local ns = {
    Root         = f,
    HPFrame      = hpFrame,
    PowerFrame   = powerFrame,
    HPBar        = hp,
    PowerBar     = power,
    PowerText    = powerText,
    HPNameText   = hpNameText,
    HPValueText  = hpValueText,
    ClickOverlay = clickOverlay,
  }
  BravUI.Frames[cfg.frameName] = ns

  -- ============================================================================
  -- PREVIEW STATE
  -- ============================================================================
  local previewMode = false

  -- ============================================================================
  -- APPLY FROM DB
  -- ============================================================================
  local function ApplyFromDB()
    if InCombatLockdown() then return end
    local c    = GetConfig() or {}

    if c.enabled == false then
      HideFrame()
      if clickOverlay then clickOverlay:Hide() end
      return
    end

    local s = U.ClampNum(c.scale, 0.5, 2.0, 1.0)
    f:SetScale(s)

    local px = U.ClampNum(c.posX, -2000, 2000, cfg.defaultPos.x)
    local py = U.ClampNum(c.posY, -2000, 2000, cfg.defaultPos.y)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", px / s, py / s)

    local w    = c.width or DEF_W
    local hpH  = (c.height and c.height.hp)    or HP_H
    local pwrH = (c.height and c.height.power) or PWR_H

    f:SetWidth(w)
    hpFrame:SetWidth(w)
    hpFrame:SetHeight(hpH)
    hp:SetHeight(hpH)

    local showPower = c.showPower ~= false
    if showPower then
      powerFrame:SetHeight(pwrH)
      power:SetHeight(pwrH)
      powerFrame:Show()
      f:SetHeight(hpH + GAP + pwrH)
    else
      powerFrame:Hide()
      f:SetHeight(hpH)
    end

    powerFrame:ClearAllPoints()
    powerFrame:SetPoint("TOPLEFT",  hpFrame, "BOTTOMLEFT",  0, -GAP)
    powerFrame:SetPoint("TOPRIGHT", hpFrame, "BOTTOMRIGHT", 0, -GAP)

    U.ApplyTextConfig(hpNameText,  GetTextConfig("name"),  hp,    "LEFT",   TS_NAME,  4, 0)
    U.ApplyTextConfig(hpValueText, GetTextConfig("hp"),    hp,    "RIGHT",  TS_HP,   -4, 0)
    U.ApplyTextConfig(powerText,   GetTextConfig("power"), power, "CENTER", TS_PWR,   0, 0)

    SyncClickOverlay()
  end
  ns.ApplyFromDB = ApplyFromDB

  -- ============================================================================
  -- UPDATE
  -- ============================================================================
  local function Update()
    if previewMode then return end

    local c = GetConfig() or {}
    if c.enabled == false then
      HideFrame()
      if not InCombatLockdown() and clickOverlay then clickOverlay:Hide() end
      return
    end

    local exists    = SafeUnitExists(UNIT)
    local extraHide = cfg.extraHideCheck and cfg.extraHideCheck() or false

    if not exists or extraHide then
      HideFrame()
      if not InCombatLockdown() then
        if clickOverlay then clickOverlay:Hide() end
      end
      return
    end

    if SafeUnitIsDead(UNIT) then
      hp:SetMinMaxValues(0, 1)
      hp:SetValue(0)
      hp:SetStatusBarColor(0.4, 0.1, 0.1)
      power:SetMinMaxValues(0, 1)
      power:SetValue(0)
      power:SetStatusBarColor(0.2, 0.2, 0.2)
      local nameCfg = GetTextConfig("name")
      if not nameCfg or nameCfg.enabled ~= false then
        WriteNameToFS(hpNameText, UNIT)
      end
      local hpCfg = GetTextConfig("hp")
      if not hpCfg or hpCfg.enabled ~= false then
        hpValueText:SetText(DEAD_TEXT)
      end
      local pwrCfg = GetTextConfig("power")
      if not pwrCfg or pwrCfg.enabled ~= false then
        powerText:SetText("")
      end
      ShowFrame()
      if not InCombatLockdown() then
        if clickOverlay then clickOverlay:Show() end
        SyncClickOverlay()
      end
      return
    end

    pcall(function()
      hp:SetMinMaxValues(0, UnitHealthMax(UNIT))
      hp:SetValue(UnitHealth(UNIT))
    end)

    local hpCfg = GetTextConfig("hp")
    if hpCfg and hpCfg.enabled == false then
      hpValueText:SetText("")
    else
      local hpFmt = "VALUE"
      if hpCfg and hpCfg.format then hpFmt = hpCfg.format end
      if hpFmt == "NONE" then
        hpValueText:SetText("")
      else
        pcall(function() hpValueText:SetText(Abbrev(UnitHealth(UNIT))) end)
      end
    end

    local nameCfg = GetTextConfig("name")
    if not nameCfg or nameCfg.enabled ~= false then
      WriteNameToFS(hpNameText, UNIT)
    end

    pcall(function()
      power:SetMinMaxValues(0, UnitPowerMax(UNIT))
      power:SetValue(UnitPower(UNIT))
    end)

    local pwrCfg = GetTextConfig("power")
    if pwrCfg and pwrCfg.enabled == false then
      powerText:SetText("")
    else
      local pwrFmt = "VALUE"
      if pwrCfg and pwrCfg.format then pwrFmt = pwrCfg.format end
      if pwrFmt == "NONE" then
        powerText:SetText("")
      else
        pcall(function() powerText:SetText(Abbrev(UnitPower(UNIT))) end)
      end
    end

    local colorCfg = GetColorConfig()
    local colorOpts = cfg.allowReaction and { allowReaction = true } or nil
    U.UpdateHPColor(UNIT, hp, colorCfg, colorOpts)
    U.UpdatePowerColor(UNIT, power, colorCfg)
    ShowFrame()
    if not InCombatLockdown() then
      if clickOverlay then clickOverlay:Show() end
      SyncClickOverlay()
    end
  end

  -- ============================================================================
  -- THROTTLE
  -- ============================================================================
  local MarkDirty = U.CreateTickerThrottler(THROTTLE, function() Update() end)

  -- ============================================================================
  -- EVENTS
  -- ============================================================================
  local ctx = {
    ApplyFromDB      = ApplyFromDB,
    Update           = Update,
    MarkDirty        = MarkDirty,
    SyncClickOverlay = SyncClickOverlay,
  }

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("UNIT_HEALTH")
  ev:RegisterEvent("UNIT_MAXHEALTH")
  ev:RegisterEvent("UNIT_POWER_UPDATE")
  ev:RegisterEvent("UNIT_MAXPOWER")
  ev:RegisterEvent("UNIT_NAME_UPDATE")
  for _, e in ipairs(cfg.extraEvents or {}) do ev:RegisterEvent(e) end

  ev:SetScript("OnEvent", function(_, event, unit)
    if previewMode and event ~= "PLAYER_LOGIN" then return end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
      ApplyFromDB()
      Update()
      return
    end

    if cfg.onExtraEvent and cfg.onExtraEvent(event, unit, ctx) then return end

    if U.SafeUnitIs(unit, UNIT) then MarkDirty() end
  end)

  -- ============================================================================
  -- PREVIEW MODE
  -- ============================================================================
  local function SetPreviewMode(enabled)
    previewMode = enabled
    if enabled then
      ApplyFromDB()
      hp:SetMinMaxValues(0, 100)
      hp:SetValue(cfg.previewHp or 72)
      if cfg.previewUseClass then
        local _, cls = UnitClass("player")
        local c = RAID_CLASS_COLORS and cls and RAID_CLASS_COLORS[cls]
        if c then hp:SetStatusBarColor(c.r, c.g, c.b)
        else      hp:SetStatusBarColor(previewHpR, previewHpG, previewHpB) end
      else
        hp:SetStatusBarColor(previewHpR, previewHpG, previewHpB)
      end
      hpNameText:SetText(cfg.previewName or UNIT)
      hpValueText:SetText(cfg.previewHpText or tostring(cfg.previewHp or 72))
      power:SetMinMaxValues(0, 100)
      power:SetValue(cfg.previewPwr or 85)
      local pc = PowerBarColor and PowerBarColor["MANA"]
      if pc then power:SetStatusBarColor(pc.r, pc.g, pc.b)
      else       power:SetStatusBarColor(0.2, 0.4, 0.8) end
      powerText:SetText(cfg.previewPwrText or tostring(cfg.previewPwr or 85))
      ShowFrame()
      if clickOverlay then clickOverlay:Hide() end
      SyncClickOverlay()
    else
      Update()
    end
  end

  ns.SetPreviewMode = SetPreviewMode
  ns.TogglePreview  = function() SetPreviewMode(not previewMode); return previewMode end
  ns.IsPreviewMode  = function() return previewMode end
  ns.Refresh        = function()
    if previewMode then SetPreviewMode(true) else ApplyFromDB(); Update() end
  end

  if cfg.publicFnName then
    BravUI[cfg.publicFnName] = function()
      if previewMode then SetPreviewMode(true) else ApplyFromDB(); Update() end
    end
  end

  return ns
end

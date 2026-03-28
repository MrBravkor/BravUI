-- BravUI/Modules/UnitFrames/CastBarFactory.lua
-- Factory pour les cast bars simples (Player, Pet, Target).
-- Élimine ~1100 lignes de code quasi-identique sur 3 fichiers.
--
-- Champs de cfg :
--   unit                (string)   unité WoW, ex. "player"
--   dbKey               (string)   clé DB sous unitframes.*, ex. "player"
--   frameName           (string)   clé dans BravUI.Frames[frameName], ex. "Player"
--   globalPrefix        (string)   préfixe des noms de frames globaux, ex. "BravUI_Player"
--   defaultW            (number)   largeur par défaut
--   defaultH            (number)   hauteur par défaut
--   defaultSpellSize    (number)   taille de police du nom du sort
--   defaultTimeSize     (number)   taille de police du timer
--   refreshEvents       (table)    events (sans unit) qui déclenchent ApplyLayout+StartOrRefresh
--   preUnitRefreshEvent (string)   event géré avant le filtre unit (ex. "UNIT_PET")

BravUI.CastBarFactory = {}

local FONT_PATH = BravLib.Media.Get("font", "uf") or BravLib.Media.Get("font", "default") or STANDARD_TEXT_FONT
local ICON_PAD  = 2

local U                  = BravUI.Utils
local Create1pxBorder    = U.Create1pxBorder
local CreateBarBackground = U.CreateBarBackground

function BravUI.CastBarFactory.Create(cfg)
  local UNIT     = cfg.unit
  local DB_KEY   = cfg.dbKey
  local DEF_W    = cfg.defaultW         or 200
  local DEF_H    = cfg.defaultH         or 16
  local DEF_SS   = cfg.defaultSpellSize or 12
  local DEF_TS   = cfg.defaultTimeSize  or 12

  local refreshEvents = cfg.refreshEvents or {}

  -- ============================================================================
  -- DB
  -- ============================================================================
  local function GetCastCfg()
    local db = BravLib.Storage.GetDB()
    return db and db.unitframes and db.unitframes[DB_KEY] and db.unitframes[DB_KEY].cast
  end

  -- ============================================================================
  -- FRAMES (lazy)
  -- ============================================================================
  local castFrame, castBar, spark, spellText, timeText
  local iconFrame, iconTex

  local function EnsureFrames()
    if castFrame then return true end

    local ns   = BravUI.Frames[cfg.frameName]
    local root = ns and ns.Root
    if not root then return false end

    local baseLevel = (root.GetFrameLevel and root:GetFrameLevel() or 1)

    castFrame = CreateFrame("Frame", cfg.globalPrefix .. "_CastFrame", root)
    castFrame:EnableMouse(false)
    castFrame:Hide()

    -- Icône
    iconFrame = CreateFrame("Frame", cfg.globalPrefix .. "_CastIconFrame", castFrame, "BackdropTemplate")
    iconFrame:SetFrameLevel(baseLevel + 2)
    Create1pxBorder(iconFrame)
    iconFrame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    iconFrame:SetBackdropColor(0, 0, 0, 0.55)

    iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconFrame)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Barre
    castBar = CreateFrame("StatusBar", cfg.globalPrefix .. "_CastBar", castFrame)
    castBar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    castBar:SetFrameLevel(baseLevel + 2)
    castBar:EnableMouse(false)
    Create1pxBorder(castBar)
    CreateBarBackground(castBar)

    spark = castBar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface/CastingBar/UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:Hide()

    spellText = castBar:CreateFontString(nil, "OVERLAY")
    spellText:SetPoint("LEFT", castBar, "LEFT", 6, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetFontObject("GameFontHighlightSmall")

    timeText = castBar:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", castBar, "RIGHT", -6, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetFontObject("GameFontHighlightSmall")

    -- Exposition dans le namespace
    local ns2 = BravUI.Frames[cfg.frameName]
    ns2.CastFrame     = castFrame
    ns2.CastBar       = castBar
    ns2.CastIconFrame = iconFrame
    ns2.CastIcon      = iconTex
    ns2.CastSpellText = spellText
    ns2.CastTimeText  = timeText

    return true
  end

  -- ============================================================================
  -- LAYOUT
  -- ============================================================================
  local function ApplyLayout()
    if not EnsureFrames() then return end

    local c = GetCastCfg()
    if not c or c.enabled == false then castFrame:Hide(); return end

    local ns         = BravUI.Frames[cfg.frameName]
    local root       = ns.Root
    local powerFrame = ns.PowerFrame
    local hpFrame    = ns.HPFrame

    local anchorFrame = powerFrame or hpFrame or root
    if c.anchor == "HP_BOTTOM" then
      anchorFrame = hpFrame or powerFrame or root
    elseif c.anchor == "ROOT" then
      anchorFrame = root
    end

    local x = tonumber(c.x) or 0
    local y = tonumber(c.y) or 0
    local w = tonumber(c.w) or DEF_W
    local h = tonumber(c.h) or DEF_H

    castFrame:ClearAllPoints()
    if anchorFrame == root then
      castFrame:SetPoint("BOTTOM", root, "BOTTOM", x, y)
    else
      castFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", x, y)
    end
    castFrame:SetSize(w, h)

    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("LEFT", castFrame, "LEFT", 0, 0)
    iconFrame:SetSize(h, h)

    castBar:ClearAllPoints()
    castBar:SetPoint("LEFT",  iconFrame, "RIGHT", ICON_PAD, 0)
    castBar:SetPoint("RIGHT", castFrame, "RIGHT", 0, 0)
    castBar:SetHeight(h)

    spark:SetSize(18, h * 1.6)

    local ss = tonumber(c.spellSize) or DEF_SS
    local ts = tonumber(c.timeSize)  or DEF_TS
    pcall(function() spellText:SetFont(FONT_PATH, ss, "OUTLINE") end)
    pcall(function() timeText:SetFont( FONT_PATH, ts, "OUTLINE") end)
  end

  BravUI.Frames[cfg.frameName].SetCastLayout = function(opts)
    local c = GetCastCfg()
    if type(opts) == "table" then
      for k, v in pairs(opts) do c[k] = v end
    end
    ApplyLayout()
  end

  -- ============================================================================
  -- ÉTAT DU CAST
  -- ============================================================================
  local castActive           = false
  local castIsChannel        = false
  local castStart            = 0
  local castEnd              = 0
  local castNotInterruptible = false

  local function SetColors()
    if not castBar then return end
    local c      = GetCastCfg()
    local colors = c and c.colors
    if castNotInterruptible then
      local col = colors and colors.notInterruptible
      if col and col.r then castBar:SetStatusBarColor(col.r, col.g, col.b)
      else castBar:SetStatusBarColor(0.6, 0.6, 0.6) end
    else
      local col = colors and colors.normal
      if col and col.r then castBar:SetStatusBarColor(col.r, col.g, col.b)
      else castBar:SetStatusBarColor(1.0, 0.8, 0.0) end
    end
  end

  local function Stop()
    castActive    = false
    castIsChannel = false
    castStart, castEnd = 0, 0
    if not castFrame then return end
    castBar:SetValue(0)
    spellText:SetText("")
    timeText:SetText("")
    iconTex:SetTexture(nil)
    spark:Hide()
    castFrame:Hide()
  end

  local function SetIconFromTexture(texture)
    if not iconTex then return end
    if texture and texture ~= "" then
      iconTex:SetTexture(texture)
      iconFrame:Show()
    else
      iconTex:SetTexture(nil)
      iconFrame:Hide()
    end
  end

  local function ComputeAndDisplay(now)
    local dur = castEnd - castStart
    if dur <= 0 then dur = 0.001 end

    local value, remain, elapsed
    if castIsChannel then
      remain  = castEnd - now
      if remain < 0 then remain = 0 end
      value   = remain
      elapsed = dur - remain
    else
      elapsed = now - castStart
      if elapsed < 0 then elapsed = 0 end
      if elapsed > dur then elapsed = dur end
      value  = elapsed
      remain = dur - elapsed
    end

    castBar:SetMinMaxValues(0, dur)
    castBar:SetValue(value)

    if castIsChannel then
      timeText:SetText(string.format("%.1f | %.1f", remain, dur))
    else
      timeText:SetText(string.format("%.1f | %.1f", elapsed, dur))
    end

    return dur, remain, elapsed
  end

  local function StartOrRefresh()
    if not EnsureFrames() then return end
    ApplyLayout()

    local name, texture, startMS, endMS, notInterruptible
    local isCasting, isChanneling = false, false

    pcall(function()
      local n, _, tex, sMS, eMS, _, _, ni = UnitCastingInfo(UNIT)
      if n then
        name, texture, startMS, endMS, notInterruptible = n, tex, sMS, eMS, ni
        isCasting = true
      end
    end)

    if not isCasting then
      pcall(function()
        local n, _, tex, sMS, eMS, _, ni = UnitChannelInfo(UNIT)
        if n then
          name, texture, startMS, endMS, notInterruptible = n, tex, sMS, eMS, ni
          isChanneling = true
        end
      end)
    end

    if not isCasting and not isChanneling then Stop(); return end

    castIsChannel         = isChanneling
    castNotInterruptible  = notInterruptible and true or false
    SetColors()

    castStart = (startMS or 0) / 1000
    castEnd   = (endMS   or 0) / 1000
    castActive = true

    pcall(function() spellText:SetText(name or "") end)
    SetIconFromTexture(texture)
    castFrame:Show()
    spark:Show()

    ComputeAndDisplay(GetTime())
  end

  -- ============================================================================
  -- ONUPDATE
  -- ============================================================================
  local function OnCastUpdate()
    if not castActive then return end
    local now = GetTime()
    if castEnd <= 0 or now >= castEnd then Stop(); return end

    local dur, remain, elapsed = ComputeAndDisplay(now)

    local w   = castBar:GetWidth() or 1
    local pct = castIsChannel and (remain / dur) or (elapsed / dur)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", castBar, "LEFT", w * pct, 0)
  end

  -- ============================================================================
  -- EVENTS
  -- ============================================================================
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("UNIT_SPELLCAST_START")
  ev:RegisterEvent("UNIT_SPELLCAST_STOP")
  ev:RegisterEvent("UNIT_SPELLCAST_FAILED")
  ev:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  ev:RegisterEvent("UNIT_SPELLCAST_DELAYED")
  ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
  ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
  ev:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
  ev:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
  for _, e in ipairs(refreshEvents) do ev:RegisterEvent(e) end
  if cfg.preUnitRefreshEvent then ev:RegisterEvent(cfg.preUnitRefreshEvent) end

  ev:SetScript("OnUpdate", function(_, _elapsed) OnCastUpdate() end)

  ev:SetScript("OnEvent", function(_, event, unit)
    -- Event géré avant le filtre unit (ex. UNIT_PET)
    if cfg.preUnitRefreshEvent and event == cfg.preUnitRefreshEvent then
      ApplyLayout()
      StartOrRefresh()
      return
    end

    -- Filtre unit
    if unit and unit ~= UNIT then return end

    -- Refresh (login / events sans unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
      ApplyLayout(); StartOrRefresh(); return
    end

    for _, e in ipairs(refreshEvents) do
      if event == e then ApplyLayout(); StartOrRefresh(); return end
    end

    -- Cast start / update
    if event == "UNIT_SPELLCAST_START"
      or event == "UNIT_SPELLCAST_CHANNEL_START"
      or event == "UNIT_SPELLCAST_DELAYED"
      or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
      or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
      or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
      StartOrRefresh(); return
    end

    -- Cast stop
    if event == "UNIT_SPELLCAST_STOP"
      or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED"
      or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      Stop(); return
    end
  end)

  C_Timer.After(0, function() ApplyLayout(); StartOrRefresh() end)
end

-- BravUI/Modules/Cooldown/CastBar.lua
-- Barre d'incantation joueur sous UtilityCooldownViewer
-- Portage v2 depuis BravUI_Cooldown standalone

local NS = BravUI.Cooldown
local U  = BravUI.Utils
local TEX = NS.TEX or "Interface/Buttons/WHITE8x8"

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local CastBarMod = {}
BravUI:RegisterModule("Cooldown.CastBar", CastBarMod)

-- ============================================================================
-- DB
-- ============================================================================

local function GetDB()
    local cd = BravLib.API.GetModule("cooldown")
    if not cd then return {} end
    return cd.castbar or {}
end

-- ============================================================================
-- LOCALS
-- ============================================================================

local castFrame, castBar, spark, spellText, timeText
local iconFrame, iconTex
local initialized = false
local utilityViewer

local castActive = false
local castIsChannel = false
local castStart = 0
local castEnd = 0
local castNotInterruptible = false

local BAR_HEIGHT = 22
local ICON_PAD = 2
local CAST_BAR_WIDTH = 250

local updater = CreateFrame("Frame")
updater:Hide()

-- ============================================================================
-- POSITION
-- ============================================================================

local function UpdatePosition()
    if not castFrame or not utilityViewer then return end

    local db = GetDB()
    local offX = db.offsetX or 0
    local offY = db.offsetY or -4

    castFrame:ClearAllPoints()
    castFrame:SetPoint("TOP", utilityViewer, "BOTTOM", offX, offY)
    castFrame:SetWidth(db.width or CAST_BAR_WIDTH)
end

-- ============================================================================
-- CREATION
-- ============================================================================

local function CreateCastBar(anchor)
    if castFrame then return end

    local fontPath = U.GetFont()
    local db = GetDB()
    local h = db.height or BAR_HEIGHT
    local fontSize = db.fontSize or 11

    castFrame = CreateFrame("Frame", "BravUI_Cooldown_CastBar", UIParent)
    castFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    castFrame:SetHeight(h)
    castFrame:SetWidth(db.width or CAST_BAR_WIDTH)
    castFrame:EnableMouse(false)
    castFrame:Hide()

    iconFrame = CreateFrame("Frame", nil, castFrame)
    iconFrame:SetPoint("LEFT", castFrame, "LEFT", 0, 0)
    iconFrame:SetSize(h, h)
    NS.CreateClassBorder(iconFrame)
    NS.CreateBarBackground(iconFrame)

    iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconFrame)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    castBar = CreateFrame("StatusBar", "BravUI_Cooldown_CastStatusBar", castFrame)
    castBar:SetPoint("LEFT", iconFrame, "RIGHT", ICON_PAD, 0)
    castBar:SetPoint("RIGHT", castFrame, "RIGHT", 0, 0)
    castBar:SetHeight(h)
    castBar:SetStatusBarTexture(TEX)
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    castBar:EnableMouse(false)
    NS.CreateClassBorder(castBar)
    NS.CreateBarBackground(castBar)

    spark = castBar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface/CastingBar/UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(18, h * 1.6)
    spark:Hide()

    spellText = castBar:CreateFontString(nil, "OVERLAY")
    spellText:SetPoint("LEFT", castBar, "LEFT", 4, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetFontObject(GameFontNormal)
    pcall(function() spellText:SetFont(fontPath, fontSize, "OUTLINE") end)

    timeText = castBar:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetFontObject(GameFontNormal)
    pcall(function() timeText:SetFont(fontPath, fontSize, "OUTLINE") end)

    -- Apply text color
    local tc = db.textColor
    if tc then
        spellText:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
        timeText:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
    end
end

-- ============================================================================
-- BACKGROUND
-- ============================================================================

local function ApplyBackground()
    local db = GetDB()
    local frames = { castBar, iconFrame }
    for _, frame in ipairs(frames) do
        if frame and frame._bg then
            if db.showBackground ~= false then
                local bc = db.bgColor
                frame._bg:SetVertexColor(bc and bc.r or 0, bc and bc.g or 0, bc and bc.b or 0, db.bgAlpha or 0.55)
                frame._bg:Show()
            else
                frame._bg:Hide()
            end
        end
    end
end

-- ============================================================================
-- COLORS
-- ============================================================================

local function SetColors()
    if not castBar then return end
    local db = GetDB()
    if castNotInterruptible then
        local c = db.colorInterrupt
        if c then
            castBar:SetStatusBarColor(c.r or 1, c.g or 0.3, c.b or 0.3)
        else
            castBar:SetStatusBarColor(0.6, 0.6, 0.6)
        end
    else
        local c = db.colorNormal
        if c then
            castBar:SetStatusBarColor(c.r or 1, c.g or 0.82, c.b or 0)
        else
            castBar:SetStatusBarColor(1.0, 0.8, 0.0)
        end
    end
end

-- ============================================================================
-- STOP
-- ============================================================================

local function Stop()
    castActive = false
    castIsChannel = false
    castStart, castEnd = 0, 0
    updater:Hide()
    if not castFrame then return end
    if previewMode then return end
    castBar:SetValue(0)
    spellText:SetText("")
    timeText:SetText("")
    iconTex:SetTexture(nil)
    spark:Hide()
    castFrame:Hide()
end

-- ============================================================================
-- START / REFRESH
-- ============================================================================

local function StartOrRefresh()
    if not castFrame then return end
    if previewMode then return end

    local db = GetDB()
    if db.enabled == false then
        Stop()
        return
    end

    local name, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo("player")
    if name then
        castIsChannel = false
    else
        name, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo("player")
        if not name then
            Stop()
            return
        end
        castIsChannel = true
    end

    castNotInterruptible = notInterruptible and true or false
    SetColors()

    castStart = (startMS or 0) / 1000
    castEnd   = (endMS or 0) / 1000

    castActive = true
    spellText:SetText(name or "")

    if db.showIcon ~= false and texture and texture ~= "" then
        iconTex:SetTexture(texture)
        iconFrame:Show()
        castBar:ClearAllPoints()
        castBar:SetPoint("LEFT", iconFrame, "RIGHT", ICON_PAD, 0)
        castBar:SetPoint("RIGHT", castFrame, "RIGHT", 0, 0)
    else
        iconTex:SetTexture(nil)
        iconFrame:Hide()
        castBar:ClearAllPoints()
        castBar:SetPoint("LEFT", castFrame, "LEFT", 0, 0)
        castBar:SetPoint("RIGHT", castFrame, "RIGHT", 0, 0)
    end

    castFrame:Show()
    spark:Show()
    updater:Show()

    local dur = castEnd - castStart
    if dur <= 0 then dur = 0.001 end
    castBar:SetMinMaxValues(0, dur)

    local now = GetTime()
    local value, remain, elapsed
    if castIsChannel then
        remain = castEnd - now
        if remain < 0 then remain = 0 end
        value = remain
        elapsed = dur - remain
    else
        elapsed = now - castStart
        if elapsed < 0 then elapsed = 0 end
        if elapsed > dur then elapsed = dur end
        value = elapsed
        remain = dur - elapsed
    end

    castBar:SetValue(value)

    if castIsChannel then
        timeText:SetText(string.format("%.1f | %.1f", remain, dur))
    else
        timeText:SetText(string.format("%.1f | %.1f", elapsed, dur))
    end
end

-- ============================================================================
-- ON UPDATE
-- ============================================================================

local function OnUpdate()
    local now = GetTime()
    if castEnd <= 0 or now >= castEnd then
        Stop()
        return
    end

    local dur = castEnd - castStart
    if dur <= 0 then dur = 0.001 end

    local value, remain, elapsed
    if castIsChannel then
        remain = castEnd - now
        if remain < 0 then remain = 0 end
        value = remain
        elapsed = dur - remain
    else
        elapsed = now - castStart
        if elapsed < 0 then elapsed = 0 end
        if elapsed > dur then elapsed = dur end
        value = elapsed
        remain = dur - elapsed
    end

    castBar:SetValue(value)

    if castIsChannel then
        timeText:SetText(string.format("%.1f | %.1f", remain, dur))
    else
        timeText:SetText(string.format("%.1f | %.1f", elapsed, dur))
    end

    local w = castBar:GetWidth() or 1
    local pct = castIsChannel and (remain / dur) or (elapsed / dur)
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    spark:SetPoint("CENTER", castBar, "LEFT", w * pct, 0)
end

updater:SetScript("OnUpdate", function() OnUpdate() end)

-- ============================================================================
-- UPDATE BORDER COLORS
-- ============================================================================

local function UpdateBorderColors()
    local r, g, b = NS.GetBorderColor()

    local frames = { castBar, iconFrame }
    for _, frame in ipairs(frames) do
        if frame and frame._borders then
            for _, tex in pairs(frame._borders) do
                tex:SetVertexColor(r, g, b, 1)
            end
        end
    end
end

-- ============================================================================
-- INIT
-- ============================================================================

local function TryInit()
    if initialized then return end
    if NS._cdmOff then return end

    local db = GetDB()
    if db.enabled == false then return end

    utilityViewer = _G["UtilityCooldownViewer"]
    if not utilityViewer then return end

    CreateCastBar(utilityViewer)
    UpdatePosition()

    -- Register in Move system
    if BravUI.Mover and BravUI.Mover.Register and castFrame then
        local def = BravLib.Storage.GetDefaults()
        local defPos = def and def.positions and def.positions["Barre Incantation"]
        local defXY = { x = defPos and defPos.x or 0, y = defPos and defPos.y or -260 }

        BravUI.Mover:Register("Barre Incantation", castFrame, function()
            local pdb = BravLib.Storage.GetDB()
            if not pdb then return end
            pdb.positions = pdb.positions or {}
            pdb.positions["Barre Incantation"] = pdb.positions["Barre Incantation"] or {}
            return pdb.positions["Barre Incantation"], "x", "y"
        end, defXY, { category = "cooldown" })
    end

    initialized = true
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("UNIT_SPELLCAST_START")
        self:RegisterEvent("UNIT_SPELLCAST_STOP")
        self:RegisterEvent("UNIT_SPELLCAST_FAILED")
        self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
        self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
        self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")

        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdatePosition()
            StartOrRefresh()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdatePosition()
            StartOrRefresh()
        end)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.3, function()
            UpdateBorderColors()
            UpdatePosition()
        end)
        return
    end

    if unit and unit ~= "player" then return end

    if not initialized then TryInit() end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        StartOrRefresh()
        return
    end

    if event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        Stop()
        return
    end
end)

-- ============================================================================
-- APPLY LAYOUT (appele depuis Init.lua NS.ApplySpecLayout)
-- ============================================================================

function NS.ApplyCastBarLayout(layout)
    if not layout or not castFrame then return end

    if layout.enabled == false then
        Stop()
        castFrame:Hide()
        return
    end

    local h = layout.height or BAR_HEIGHT
    local w = layout.width or CAST_BAR_WIDTH

    BAR_HEIGHT = h
    CAST_BAR_WIDTH = w

    castFrame:SetHeight(h)
    castFrame:SetWidth(w)
    if castBar then castBar:SetHeight(h) end
    if iconFrame then iconFrame:SetSize(h, h) end
    if spark then spark:SetSize(18, h * 1.6) end

    if utilityViewer then
        UpdatePosition()
    end

    StartOrRefresh()
end

-- ============================================================================
-- PREVIEW MODE
-- ============================================================================

local previewMode = false
local previewTicker = nil

function NS.SetCastBarPreview(enabled)
    if not castFrame then
        if enabled then TryInit() end
        if not castFrame then return end
    end

    previewMode = enabled

    if enabled then
        local db = GetDB()
        local h = db.height or BAR_HEIGHT

        -- Apply current settings
        BravLib.Hooks.Fire("APPLY_COOLDOWN_CASTBAR")

        -- Show with dummy data
        castNotInterruptible = false
        SetColors()

        local dur = 2.0
        castBar:SetMinMaxValues(0, dur)

        if db.showIcon ~= false then
            iconTex:SetTexture("Interface/Icons/Spell_Nature_Lightning")
            iconFrame:Show()
        end

        if db.showSpellName ~= false then
            spellText:SetText("Eclair")
            spellText:Show()
        end

        castFrame:Show()
        spark:Show()

        -- Animate preview bar back and forth
        local elapsed = 0
        local direction = 1
        if previewTicker then previewTicker:Cancel() end
        previewTicker = C_Timer.NewTicker(0.016, function()
            if not previewMode then return end
            elapsed = elapsed + 0.016 * direction
            if elapsed >= dur then elapsed = dur; direction = -1 end
            if elapsed <= 0 then elapsed = 0; direction = 1 end

            castBar:SetValue(elapsed)
            local remain = dur - elapsed
            if db.showTimer ~= false then
                timeText:SetText(string.format("%.1f | %.1f", elapsed, dur))
                timeText:Show()
            end

            local w = castBar:GetWidth() or 1
            local pct = elapsed / dur
            spark:ClearAllPoints()
            spark:SetPoint("CENTER", castBar, "LEFT", w * pct, 0)
        end)
    else
        if previewTicker then
            previewTicker:Cancel()
            previewTicker = nil
        end
        Stop()
    end
end

function NS.IsCastBarPreview()
    return previewMode
end

-- ============================================================================
-- MODULE ENABLE / DISABLE
-- ============================================================================

function CastBarMod:Enable()
    BravLib.Hooks.Register("APPLY_COOLDOWN_CASTBAR", function()
        if not castFrame then return end
        local db = GetDB()

        -- Size
        local h = db.height or BAR_HEIGHT
        local w = db.width or CAST_BAR_WIDTH
        castFrame:SetHeight(h)
        castFrame:SetWidth(w)
        if castBar then castBar:SetHeight(h) end
        if iconFrame then
            iconFrame:SetSize(h, h)
            if db.showIcon == false then iconFrame:Hide() else iconFrame:Show() end
        end
        if spark then spark:SetSize(18, h * 1.6) end

        -- Icon anchor
        if castBar then
            castBar:ClearAllPoints()
            if db.showIcon == false then
                castBar:SetPoint("LEFT", castFrame, "LEFT", 0, 0)
            else
                castBar:SetPoint("LEFT", iconFrame, "RIGHT", ICON_PAD, 0)
            end
            castBar:SetPoint("RIGHT", castFrame, "RIGHT", 0, 0)
        end

        -- Borders + background
        UpdateBorderColors()
        ApplyBackground()

        -- Text
        local fontPath = U.GetFont()
        local fontSize = db.fontSize or 11
        pcall(function() spellText:SetFont(fontPath, fontSize, "OUTLINE") end)
        pcall(function() timeText:SetFont(fontPath, fontSize, "OUTLINE") end)
        local tc = db.textColor
        if tc then
            spellText:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
            timeText:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
        end

        -- Visibility
        if db.showSpellName == false then spellText:Hide() else spellText:Show() end
        if db.showTimer == false then timeText:Hide() else timeText:Show() end

        -- Apply position live from sliders
        local posDB = BravLib.Storage.GetDB()
        local pos = posDB and posDB.positions and posDB.positions["Barre Incantation"]
        if pos then
            castFrame:ClearAllPoints()
            local fs = castFrame:GetScale() or 1
            castFrame:SetPoint("CENTER", UIParent, "CENTER", (pos.x or 0) / fs, (pos.y or 0) / fs)
        end

        -- Re-apply preview dummy data if active
        if previewMode then
            castNotInterruptible = false
            SetColors()
            if db.showIcon ~= false then
                iconTex:SetTexture("Interface/Icons/Spell_Nature_Lightning")
                iconFrame:Show()
            end
            if db.showSpellName ~= false then
                spellText:SetText("Eclair")
                spellText:Show()
            end
            castFrame:Show()
            spark:Show()
        else
            StartOrRefresh()
        end
    end)
end

function CastBarMod:Disable()
    Stop()
    if castFrame then castFrame:Hide() end
end

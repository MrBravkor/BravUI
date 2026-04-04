-- BravUI/Modules/Cooldown/ResourceBar.lua
-- Barre de ressource primaire (mana/rage/energy/focus/fury...)
-- Position libre via Move system

local NS = BravUI.Cooldown
local U  = BravUI.Utils
local TEX = NS.TEX or "Interface/Buttons/WHITE8x8"

local ResourceBar = {}
BravUI:RegisterModule("Cooldown.ResourceBar", ResourceBar)

-- ============================================================================
-- LOCALS
-- ============================================================================

local bar, barText, barBg
local initialized = false

local function GetDB()
    local cd = BravLib.API.GetModule("cooldown")
    return cd and cd.primary or {}
end

-- ============================================================================
-- BORDER (black 1px)
-- ============================================================================

local function CreateBlackBorder(frame)
    local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture(TEX); top:SetVertexColor(0, 0, 0, 1); top:SetHeight(1)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)

    local bot = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    bot:SetTexture(TEX); bot:SetVertexColor(0, 0, 0, 1); bot:SetHeight(1)
    bot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
    bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)

    local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture(TEX); left:SetVertexColor(0, 0, 0, 1); left:SetWidth(1)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)

    local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture(TEX); right:SetVertexColor(0, 0, 0, 1); right:SetWidth(1)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
end

-- ============================================================================
-- CREATE
-- ============================================================================

local function Create()
    if bar then return end

    local db = GetDB()

    local f = CreateFrame("StatusBar", "BravUI_ResourceBar", UIParent)
    f:SetStatusBarTexture(TEX)
    f:SetMinMaxValues(0, 1)
    f:SetSize(db.width or 220, db.height or 12)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(50)
    f:EnableMouse(false)

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX)
    bg:SetVertexColor(0, 0, 0, db.bgAlpha or 0.55)
    bg:SetAllPoints(f)
    barBg = bg

    CreateBlackBorder(f)

    local txt = f:CreateFontString(nil, "OVERLAY")
    txt:SetPoint("CENTER", f, "CENTER")
    txt:SetFontObject(GameFontNormal)
    pcall(function() txt:SetFont(U.GetFont(), db.fontSize or 11, "OUTLINE") end)
    txt:SetShadowOffset(1, -1)
    txt:SetShadowColor(0, 0, 0, 0.8)
    txt:SetTextColor(1, 1, 1, 1)

    f:Show()
    bar = f
    barText = txt
end

-- ============================================================================
-- APPLY SIZE (from DB)
-- ============================================================================

local function ApplySize()
    if not bar then return end
    local db = GetDB()
    bar:SetSize(db.width or 220, db.height or 12)
end

-- ============================================================================
-- UPDATE (secret-safe)
-- ============================================================================

local function Update()
    if not bar or not barText then return end

    local db = GetDB()
    if db.enabled == false then bar:Hide() return end

    local ok = pcall(function()
        local curP = UnitPower("player")
        local maxP = UnitPowerMax("player")

        bar:SetMinMaxValues(0, maxP)
        bar:SetValue(curP)

        if db.showText ~= false then
            local fmt = db.textFormat or "value_only"
            if fmt == "value" then
                barText:SetText(AbbreviateNumbers(curP) .. " / " .. AbbreviateNumbers(maxP))
            else
                barText:SetText(AbbreviateNumbers(curP))
            end
            barText:Show()
        else
            barText:Hide()
        end

        local mode = db.colorMode or "power"
        if mode == "power" then
            local _, pToken = UnitPowerType("player")
            local c = PowerBarColor and pToken and PowerBarColor[pToken]
            if c and c.r then
                bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            else
                bar:SetStatusBarColor(0, 0.44, 0.87, 1)
            end
        elseif mode == "class" then
            local cr, cg, cb = U.GetClassColor("player")
            bar:SetStatusBarColor(cr, cg, cb, 1)
        else
            local bc = db.barColor
            bar:SetStatusBarColor(bc and bc.r or 0, bc and bc.g or 0.44, bc and bc.b or 0.87, 1)
        end

        bar:Show()
    end)

    if not ok then bar:Hide() end
end

-- ============================================================================
-- INIT
-- ============================================================================

local function TryInit()
    if initialized or NS._cdmOff then return end

    local db = GetDB()
    if db.enabled == false then return end

    Create()
    Update()

    -- Register in Move system (position handled entirely by Move)
    if BravUI.Mover and BravUI.Mover.Register and bar then
        local def = BravLib.Storage.GetDefaults()
        local defPos = def and def.positions and def.positions["Barre Ressource"]
        local defXY = { x = defPos and defPos.x or 0, y = defPos and defPos.y or -232 }

        BravUI.Mover:Register("Barre Ressource", bar, function()
            local pdb = BravLib.Storage.GetDB()
            if not pdb then return end
            pdb.positions = pdb.positions or {}
            pdb.positions["Barre Ressource"] = pdb.positions["Barre Ressource"] or {}
            return pdb.positions["Barre Ressource"], "x", "y"
        end, defXY, { category = "cooldown" })
    end

    initialized = true
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("UNIT_POWER_FREQUENT")
        self:RegisterEvent("UNIT_MAXPOWER")
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")

        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            Update()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            TryInit()
            Update()
        end)
        return
    end

    if event == "UNIT_DISPLAYPOWER" then
        if arg1 ~= "player" then return end
        C_Timer.After(0.1, Update)
        return
    end

    if arg1 == "player" then
        if not initialized then TryInit() end
        Update()
    end
end)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function NS.ApplyResourceBarLayout()
    if not bar then return end
    local db = GetDB()
    if db.enabled == false then bar:Hide() return end
    ApplySize()
    Update()
    bar:Show()
end

-- ============================================================================
-- MODULE ENABLE / DISABLE
-- ============================================================================

function ResourceBar:Enable()
    BravLib.Hooks.Register("APPLY_COOLDOWN_RESOURCE", function()
        if not bar then return end
        local db = GetDB()
        pcall(function() barText:SetFont(U.GetFont(), db.fontSize or 11, "OUTLINE") end)
        local anchor = db.textAnchor or "CENTER"
        barText:ClearAllPoints()
        barText:SetPoint(anchor, bar, anchor, 0, 0)
        local tc = db.centerTextColor
        barText:SetTextColor(tc and tc.r or 1, tc and tc.g or 1, tc and tc.b or 1, 1)
        if barBg then
            if db.showBackground ~= false then
                barBg:Show()
                local bc = db.bgColor
                barBg:SetVertexColor(bc and bc.r or 0, bc and bc.g or 0, bc and bc.b or 0, db.bgAlpha or 0.55)
            else
                barBg:Hide()
            end
        end
        ApplySize()

        -- Apply position live from sliders
        local posDB = BravLib.Storage.GetDB()
        local pos = posDB and posDB.positions and posDB.positions["Barre Ressource"]
        if pos then
            bar:ClearAllPoints()
            local fs = bar:GetScale() or 1
            bar:SetPoint("CENTER", UIParent, "CENTER", (pos.x or 0) / fs, (pos.y or 0) / fs)
        end

        Update()
    end)
end

function ResourceBar:Disable()
    if bar then bar:Hide() end
end

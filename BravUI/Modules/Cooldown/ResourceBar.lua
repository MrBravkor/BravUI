-- BravUI/Modules/Cooldown/ResourceBar.lua
-- Barre de ressource primaire (mana/rage/energy/focus/fury...)
-- Ancrage au EssentialCooldownViewer natif de Blizzard
-- Portage v2 depuis BravUI_Cooldown standalone

local NS = BravUI.Cooldown
local U  = BravUI.Utils
local TEX = NS.TEX or "Interface/Buttons/WHITE8x8"

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local ResourceBar = {}
BravUI:RegisterModule("Cooldown.ResourceBar", ResourceBar)

-- ============================================================================
-- DB
-- ============================================================================

local function GetDB()
    local cd = BravLib.API.GetModule("cooldown")
    if not cd then return {} end
    return cd.primary or {}
end

-- ============================================================================
-- LOCALS
-- ============================================================================

local bar, barText
local viewer
local initialized = false

-- ============================================================================
-- CREATION
-- ============================================================================

local function CreateResourceBar(anchor)
    if bar then return end

    local db = GetDB()
    local fontPath = U.GetFont()
    local width  = db.width  or 220
    local height = db.height or 12
    local offX = db.anchorOffsetX or 0
    local offY = db.anchorOffsetY or -2

    local f = CreateFrame("StatusBar", "BravUI_ResourceBar", UIParent)
    f:SetPoint("TOP", anchor, "BOTTOM", offX, offY)
    f:SetSize(width, height)
    f:SetStatusBarTexture(TEX)
    f:SetMinMaxValues(0, 1)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(50)
    f:EnableMouse(false)
    NS.CreateClassBorder(f)
    NS.CreateBarBackground(f)

    local txt = f:CreateFontString(nil, "OVERLAY")
    txt:SetPoint("CENTER", f, "CENTER")
    txt:SetFontObject(GameFontNormal)
    pcall(function() txt:SetFont(fontPath, db.fontSize or 11, "OUTLINE") end)
    txt:SetShadowOffset(1, -1)
    txt:SetShadowColor(0, 0, 0, 0.8)
    txt:SetTextColor(1, 1, 1, 1)

    f:Show()

    bar = f
    barText = txt
end

-- ============================================================================
-- POSITION
-- ============================================================================

local function UpdatePosition()
    if not bar or not viewer then return end

    local db = GetDB()
    local offX = db.anchorOffsetX or 0
    local offY = db.anchorOffsetY or -2

    if db.anchorToViewer ~= false then
        local cx, _, bottomY = NS.GetViewerIconBounds(viewer)
        bar:ClearAllPoints()
        if cx and bottomY then
            bar:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx + offX, bottomY + offY)
        else
            bar:SetPoint("TOP", viewer, "BOTTOM", offX, offY)
        end
    end

    if db.flexibleWidth and db.anchorToViewer ~= false then
        local vw = viewer:GetWidth()
        if vw and vw > 0 then
            bar:SetWidth(vw)
        end
    else
        bar:SetWidth(db.width or 220)
    end
end

-- ============================================================================
-- UPDATE
-- ============================================================================

local function Update()
    if not bar or not barText then return end

    local db = GetDB()
    if db.enabled == false then
        bar:Hide()
        return
    end

    local ok = pcall(function()
        local curP = UnitPower("player")
        local maxP = UnitPowerMax("player")

        if not maxP or maxP <= 0 then
            bar:Hide()
            return
        end

        bar:Show()
        bar:SetMinMaxValues(0, maxP)
        bar:SetValue(curP)

        -- Texte
        local curStr = NS.Abbrev(curP)
        local maxStr = NS.Abbrev(maxP)
        barText:SetText(curStr .. " / " .. maxStr)
        barText:Show()

        -- Couleur
        if db.useClassColor then
            local cr, cg, cb = U.GetClassColor("player")
            bar:SetStatusBarColor(cr, cg, cb, 0.85)
        elseif db.usePowerColor ~= false then
            local _, pToken = UnitPowerType("player")
            local c = PowerBarColor and pToken and PowerBarColor[pToken]
            if c and c.r then
                bar:SetStatusBarColor(c.r, c.g, c.b, 0.85)
            elseif db.barColor then
                bar:SetStatusBarColor(db.barColor.r or 0, db.barColor.g or 0.44, db.barColor.b or 0.87, 0.85)
            else
                bar:SetStatusBarColor(0, 0.44, 0.87, 0.85)
            end
        elseif db.barColor then
            bar:SetStatusBarColor(db.barColor.r or 0, db.barColor.g or 0.44, db.barColor.b or 0.87, 0.85)
        else
            bar:SetStatusBarColor(0, 0.44, 0.87, 0.85)
        end
    end)

    if not ok then
        bar:Hide()
    end
end

local function UpdateBorderColors()
    if not bar or not bar._borders then return end
    local r, g, b = NS.GetBorderColor()
    for _, tex in pairs(bar._borders) do
        tex:SetVertexColor(r, g, b, 1)
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

    viewer = _G["EssentialCooldownViewer"]
    if not viewer then return end

    CreateResourceBar(viewer)
    Update()

    initialized = true
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_POWER_FREQUENT")
        self:RegisterEvent("UNIT_MAXPOWER")
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdatePosition()
            Update()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdatePosition()
            Update()
        end)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_DISPLAYPOWER" then
        if event == "UNIT_DISPLAYPOWER" and arg1 ~= "player" then return end
        C_Timer.After(0.3, function()
            UpdateBorderColors()
            UpdatePosition()
            Update()
        end)
        return
    end

    if arg1 == "player" then
        if not initialized then TryInit() end
        Update()
    end
end)

-- ============================================================================
-- APPLY LAYOUT (appele depuis Init.lua NS.ApplySpecLayout)
-- ============================================================================

function NS.ApplyResourceBarLayout(layout)
    if not bar then return end

    if layout and layout.enabled == false then
        bar:Hide()
        return
    end

    bar:SetHeight((layout and layout.height) or 12)
    UpdatePosition()
    bar:Show()
    Update()
end

-- ============================================================================
-- MODULE ENABLE / DISABLE
-- ============================================================================

function ResourceBar:Enable()
    BravLib.Hooks.Register("APPLY_COOLDOWN_RESOURCE", function()
        if not bar then return end
        local db = GetDB()
        UpdateBorderColors()
        pcall(function()
            barText:SetFont(U.GetFont(), db.fontSize or 11, "OUTLINE")
        end)
        UpdatePosition()
        Update()
    end)
end

function ResourceBar:Disable()
    if bar then bar:Hide() end
end

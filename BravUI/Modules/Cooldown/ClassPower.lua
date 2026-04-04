-- BravUI/Modules/Cooldown/ClassPower.lua
-- Segments de puissance de classe (combo/holy/runes/chi/arcane/shards)
-- Ancre au-dessus de EssentialCooldownViewer
-- Portage v2 depuis BravUI_Cooldown standalone

local NS = BravUI.Cooldown
local U  = BravUI.Utils
local TEX = NS.TEX or "Interface/Buttons/WHITE8x8"

NS.ClassPowerSkin = NS.ClassPowerSkin or {}
local Skin = NS.ClassPowerSkin

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local ClassPowerMod = {}
BravUI:RegisterModule("Cooldown.ClassPower", ClassPowerMod)

-- ============================================================================
-- DB
-- ============================================================================

local function GetDB()
    local cd = BravLib.API.GetModule("cooldown")
    if not cd then return {} end
    return cd.secondary or {}
end

-- ============================================================================
-- VISUEL: Conteneur principal + segments
-- ============================================================================

function Skin:Create(anchor, db)
    if self.frame then return self.frame end

    if db then self._layout = db end

    local height = db and db.height or 10
    local width = db and db.width or 220
    local offsetX = db and db.offsetX or 0
    local offsetY = db and db.offsetY or 0

    local container = CreateFrame("Frame", "BravUI_Cooldown_ClassPower", UIParent)
    container:SetPoint("BOTTOM", anchor, "TOP", offsetX, offsetY)
    container:SetSize(width, height)
    container:EnableMouse(false)
    container:Show()

    self.frame = container
    self.anchor = anchor
    self.segments = {}
    self.segmentsMax = 0

    return container
end

-- ============================================================================
-- POSITION
-- ============================================================================

function Skin:UpdatePosition(db)
    if not self.frame or not self.anchor then return end

    if db then self._layout = db end
    local lay = self._layout

    local width = lay and lay.width or 220
    local offsetX = lay and lay.offsetX or 0
    local offsetY = lay and lay.offsetY or 0

    local cx, topY = NS.GetViewerIconBounds(self.anchor)
    self.frame:ClearAllPoints()
    if cx and topY then
        self.frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx + offsetX, topY + offsetY)
    else
        self.frame:SetPoint("BOTTOM", self.anchor, "TOP", offsetX, offsetY)
    end
    self.frame:SetWidth(width)
end

-- ============================================================================
-- SEGMENTS
-- ============================================================================

function Skin:EnsureSegments(n, db)
    n = tonumber(tostring(n)) or 0
    if not self.frame or n <= 0 then return end

    if db then self._layout = db end
    local lay = self._layout

    local height = lay and lay.height or 10
    local gap = lay and lay.segmentGap or 3

    if self.segmentsMax ~= n then
        self:HideSegments()
        self.segmentsMax = n
    end

    for i = 1, n do
        if not self.segments[i] then
            local s = CreateFrame("StatusBar", nil, self.frame)
            s:SetStatusBarTexture(TEX)
            s:SetMinMaxValues(0, 1)
            s:SetValue(1)
            s:Hide()
            s:EnableMouse(false)
            NS.CreateClassBorder(s)
            NS.CreateBarBackground(s)
            self.segments[i] = s
        end
    end

    local totalW = self.frame:GetWidth()
    if totalW <= 0 then totalW = 220 end
    local segW = (totalW - (n - 1) * gap) / n

    for i = 1, n do
        local s = self.segments[i]
        s:ClearAllPoints()
        if i == 1 then
            s:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        else
            s:SetPoint("TOPLEFT", self.segments[i - 1], "TOPRIGHT", gap, 0)
        end
        s:SetSize(segW, height)
    end
end

function Skin:ShowSegments(cur, max)
    max = tonumber(tostring(max)) or 0
    cur = tonumber(tostring(cur)) or 0
    self:EnsureSegments(max)
    for i = 1, max do
        local s = self.segments[i]
        s:Show()
        s:SetAlpha(i <= cur and 1 or 0.18)
    end
end

function Skin:HideSegments()
    for i = 1, (tonumber(tostring(self.segmentsMax)) or 0) do
        if self.segments[i] then
            self.segments[i]:Hide()
        end
    end
end

function Skin:SetSegmentColor(powerType)
    local db = GetDB()
    local mode = db.colorMode or "power"
    local r, g, b = 0.7, 0.7, 0.7

    if mode == "class" then
        r, g, b = U.GetClassColor("player")
    elseif mode == "custom" then
        local bc = db.barColor
        r = bc and bc.r or 0.7
        g = bc and bc.g or 0.7
        b = bc and bc.b or 0.7
    else
        local c = PowerBarColor and PowerBarColor[powerType]
        if c and c.r then
            r, g, b = c.r, c.g, c.b
        end
    end

    for i = 1, (tonumber(tostring(self.segmentsMax)) or 0) do
        local s = self.segments[i]
        if s then
            s:SetStatusBarColor(r, g, b)
        end
    end
end

function Skin:UpdateBackground()
    local db = GetDB()
    for i = 1, (tonumber(tostring(self.segmentsMax)) or 0) do
        local s = self.segments[i]
        if s and s._bg then
            if db.showBackground ~= false then
                local bc = db.bgColor
                s._bg:SetVertexColor(bc and bc.r or 0, bc and bc.g or 0, bc and bc.b or 0, db.bgAlpha or 0.55)
                s._bg:Show()
            else
                s._bg:Hide()
            end
        end
    end
end

function Skin:UpdateBorderColors()
    local r, g, b = NS.GetBorderColor()
    for i = 1, (tonumber(tostring(self.segmentsMax)) or 0) do
        local s = self.segments[i]
        if s and s._borders then
            for _, tex in pairs(s._borders) do
                tex:SetVertexColor(r, g, b, 1)
            end
        end
    end
end

function Skin:OnContainerResize()
    local n = tonumber(tostring(self.segmentsMax)) or 0
    if n > 0 then
        self:EnsureSegments(n)
    end
end

-- ============================================================================
-- APPLY LAYOUT (appele depuis Init.lua NS.ApplySpecLayout)
-- ============================================================================

function NS.ApplyClassPowerLayout(layout)
    if not layout then return end
    local S = NS.ClassPowerSkin
    if not S or not S.frame then return end

    if layout.enabled == false then
        S:HideSegments()
        S.frame:Hide()
        return
    end

    S.frame:SetHeight(layout.height or 10)
    S:UpdatePosition(layout)

    local n = tonumber(tostring(S.segmentsMax)) or 0
    if n > 0 then
        S:EnsureSegments(n, layout)
    end

    S.frame:Show()
    if NS._UpdateClassPower then NS._UpdateClassPower() end
end

-- ============================================================================
-- DETECTION DU TYPE DE POUVOIR
-- ============================================================================

local CLASS_POWER_PRIORITY = {
    Enum.PowerType.ComboPoints,
    Enum.PowerType.HolyPower,
    Enum.PowerType.SoulShards,
    Enum.PowerType.Chi,
    Enum.PowerType.ArcaneCharges,
    Enum.PowerType.Runes,
}

local secondaryPowerType = nil
local isRunePower = false

local function PickSecondaryPowerType()
    secondaryPowerType = nil
    isRunePower = false
    local mainPowerType = UnitPowerType("player")

    for _, pType in ipairs(CLASS_POWER_PRIORITY) do
        if pType ~= mainPowerType then
            local ok, maxP = pcall(UnitPowerMax, "player", pType)
            if ok then
                local gt = false
                pcall(function() if maxP and maxP > 0 then gt = true end end)
                if gt then
                    secondaryPowerType = pType
                    isRunePower = (pType == Enum.PowerType.Runes)
                    return
                end
            end
        end
    end
end

-- ============================================================================
-- RUNE COUNTING
-- ============================================================================

local function CountReadyRunes()
    local ready = 0
    for i = 1, 6 do
        local ok, start, dur, runeReady = pcall(GetRuneCooldown, i)
        if ok then
            local isReady = false
            pcall(function() if runeReady then isReady = true end end)
            if isReady then
                ready = ready + 1
            end
        end
    end
    return ready, 6
end

-- ============================================================================
-- MISE A JOUR
-- ============================================================================

local function UpdateClassPower()
    local S = NS.ClassPowerSkin
    if not S or not S.frame then return end

    local db = GetDB()
    if db.enabled == false then
        S:HideSegments()
        S.frame:Hide()
        return
    end

    if not secondaryPowerType then
        S:HideSegments()
        S.frame:Hide()
        return
    end

    local curN, maxN

    if isRunePower then
        curN, maxN = CountReadyRunes()
    else
        local okC, cur = pcall(UnitPower, "player", secondaryPowerType)
        local okM, max = pcall(UnitPowerMax, "player", secondaryPowerType)
        if not okC or not okM then return end

        curN, maxN = 0, 0
        pcall(function() local s = tostring(cur); curN = tonumber(s) or 0 end)
        pcall(function() local s = tostring(max); maxN = tonumber(s) or 0 end)
    end

    local hasMax = false
    pcall(function() if maxN > 0 then hasMax = true end end)
    if not hasMax then
        S:HideSegments()
        S.frame:Hide()
        return
    end

    S.frame:Show()
    S:ShowSegments(curN, maxN)
    S:SetSegmentColor(secondaryPowerType)
end

NS._UpdateClassPower = UpdateClassPower

-- ============================================================================
-- INIT
-- ============================================================================

local initialized = false
local runeTicker = nil

local function TryInit()
    if initialized then return end
    if NS._cdmOff then return end

    local db = GetDB()
    if db.enabled == false then return end

    local S = NS.ClassPowerSkin
    if not S then return end

    local viewer = _G["EssentialCooldownViewer"]
    if not viewer then return end

    S:Create(viewer, db)

    S.frame:SetScript("OnSizeChanged", function()
        S:OnContainerResize()
    end)

    PickSecondaryPowerType()
    UpdateClassPower()

    if isRunePower and not runeTicker then
        runeTicker = C_Timer.NewTicker(0.1, UpdateClassPower)
    end

    -- Register in Move system
    if BravUI.Mover and BravUI.Mover.Register and S.frame then
        local def = BravLib.Storage.GetDefaults()
        local defPos = def and def.positions and def.positions["Puissance Classe"]
        local defXY = { x = defPos and defPos.x or 0, y = defPos and defPos.y or -200 }

        BravUI.Mover:Register("Puissance Classe", S.frame, function()
            local pdb = BravLib.Storage.GetDB()
            if not pdb then return end
            pdb.positions = pdb.positions or {}
            pdb.positions["Puissance Classe"] = pdb.positions["Puissance Classe"] or {}
            return pdb.positions["Puissance Classe"], "x", "y"
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
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_POWER_UPDATE")
        self:RegisterEvent("UNIT_MAXPOWER")
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("RUNE_POWER_UPDATE")

        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdateClassPower()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, TryInit)
        C_Timer.After(1.5, function()
            TryInit()
            UpdateClassPower()
        end)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.3, function()
            if runeTicker then
                runeTicker:Cancel()
                runeTicker = nil
            end

            PickSecondaryPowerType()
            local S = NS.ClassPowerSkin
            if S then
                S:UpdateBorderColors()
            end
            UpdateClassPower()

            if isRunePower and not runeTicker then
                runeTicker = C_Timer.NewTicker(0.1, UpdateClassPower)
            end
        end)
        return
    end

    if event == "UNIT_DISPLAYPOWER" then
        if arg1 == "player" then
            PickSecondaryPowerType()
            UpdateClassPower()
        end
        return
    end

    if event == "RUNE_POWER_UPDATE" then
        if not initialized then TryInit() end
        UpdateClassPower()
        return
    end

    if arg1 == "player" then
        if not initialized then TryInit() end
        UpdateClassPower()
    end
end)

-- ============================================================================
-- MODULE ENABLE / DISABLE
-- ============================================================================

function ClassPowerMod:Enable()
    BravLib.Hooks.Register("APPLY_COOLDOWN_CLASSPOWER", function()
        local S = NS.ClassPowerSkin
        if not S or not S.frame then return end

        local db = GetDB()

        S:UpdateBorderColors()
        S:UpdateBackground()

        -- Apply size
        S.frame:SetHeight(db.height or 10)
        S.frame:SetWidth(db.width or 220)
        local n = tonumber(tostring(S.segmentsMax)) or 0
        if n > 0 then S:EnsureSegments(n, db) end

        -- Apply position live from sliders
        local posDB = BravLib.Storage.GetDB()
        local pos = posDB and posDB.positions and posDB.positions["Puissance Classe"]
        if pos then
            S.frame:ClearAllPoints()
            local fs = S.frame:GetScale() or 1
            S.frame:SetPoint("CENTER", UIParent, "CENTER", (pos.x or 0) / fs, (pos.y or 0) / fs)
        end

        UpdateClassPower()
    end)
end

function ClassPowerMod:Disable()
    local S = NS.ClassPowerSkin
    if S then
        S:HideSegments()
        if S.frame then S.frame:Hide() end
    end
    if runeTicker then
        runeTicker:Cancel()
        runeTicker = nil
    end
end

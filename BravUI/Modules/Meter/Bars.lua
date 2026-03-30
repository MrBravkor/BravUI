-- BravUI/Modules/Meter/Bars.lua
-- Factory barres DPS/HPS + Panel conteneur (skin, layouts, tabs, menus)
-- Port fidèle de UI/Bars.lua + DetailsPanel/Skin.lua + DetailsPanel/Init.lua

local BravUI = BravUI
BravUI.Meter = BravUI.Meter or {}

local F  = BravLib.Format
local DM = BravLib.DamageMeter
local TEX = F.TEX_WHITE

local function GetDB()     return BravLib.API.GetModule("meter") or {} end
local function GetFont()   return BravUI.Utils.GetFont() end
local function GetClassColor() return BravUI.Utils.GetClassColor("player") end

local function ClassColor(class)
    if not class then return 0.5, 0.5, 0.5 end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

-- ============================================================================
-- PART 1 — PANEL SKIN (port fidèle de DetailsPanel/Skin.lua)
-- ============================================================================

local Skin = {}
local BORDER_W = 2

local function GetInfoBarH() return 22 end
local function GetInfoBarOpacity() return 0.75 end

local function MakeBorder(parent, cr, cg, cb)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX)
    t:SetVertexColor(cr, cg, cb, 1)
    return t
end

function Skin.CreatePanel(db)
    local panel = CreateFrame("Frame", "BravUI_MeterPanel", UIParent)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(0)
    panel:SetSize(db.panelWidth or 440, db.panelHeight or 223)
    panel:SetClampedToScreen(true)

    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX)
    bg:SetVertexColor(0, 0, 0, db.opacity or 0.75)
    bg:SetAllPoints(panel)
    panel._bg = bg

    local cr, cg, cb = GetClassColor()
    local PU = PixelUtil

    -- CLASS BORDERS (top, left, right — no bottom, InfoBar closes it)
    local borders = {}

    local bTop = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(bTop, "TOPLEFT", panel, "TOPLEFT", 0, 0)
    PU.SetPoint(bTop, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    PU.SetHeight(bTop, BORDER_W)
    borders.top = bTop

    local bLeft = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(bLeft, "TOPLEFT", panel, "TOPLEFT", 0, 0)
    PU.SetPoint(bLeft, "BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    PU.SetWidth(bLeft, BORDER_W)
    borders.left = bLeft

    local bRight = MakeBorder(panel, cr, cg, cb)
    PU.SetPoint(bRight, "TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    PU.SetPoint(bRight, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    PU.SetWidth(bRight, BORDER_W)
    borders.right = bRight

    panel._borders = borders

    -- TAB SEPARATOR
    local tabZoneTotal = db._tabZoneTotal or db._tabZone or 29
    local tabSep = panel:CreateTexture(nil, "ARTWORK")
    tabSep:SetTexture(TEX)
    tabSep:SetVertexColor(cr, cg, cb, 0.5)
    tabSep:SetHeight(1)
    tabSep:SetPoint("LEFT", panel, "TOPLEFT", 0, -tabZoneTotal)
    tabSep:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -tabZoneTotal)
    panel._tabSep = tabSep

    -- CONTENT ZONE
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", BORDER_W, -(tabZoneTotal + 1))
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_W, GetInfoBarH() + BORDER_W)
    content:SetClipsChildren(true)
    panel._content = content

    -- INFOBAR
    local bar = CreateFrame("Frame", "BravUI_MeterPanelInfoBar", panel)
    bar:SetHeight(GetInfoBarH())
    bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    barBg:SetTexture(TEX)
    barBg:SetVertexColor(0, 0, 0, GetInfoBarOpacity())
    barBg:SetAllPoints(bar)
    bar._bg = barBg

    local barBorders = {}
    local bbTop = MakeBorder(bar, cr, cg, cb)
    PU.SetPoint(bbTop, "TOPLEFT", bar, "TOPLEFT", 0, 0)
    PU.SetPoint(bbTop, "TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    PU.SetHeight(bbTop, BORDER_W)
    barBorders.top = bbTop

    local bbBot = MakeBorder(bar, cr, cg, cb)
    PU.SetPoint(bbBot, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    PU.SetPoint(bbBot, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    PU.SetHeight(bbBot, BORDER_W)
    barBorders.bottom = bbBot

    local bbLeft = MakeBorder(bar, cr, cg, cb)
    PU.SetPoint(bbLeft, "TOPLEFT", bar, "TOPLEFT", 0, 0)
    PU.SetPoint(bbLeft, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    PU.SetWidth(bbLeft, BORDER_W)
    barBorders.left = bbLeft

    local bbRight = MakeBorder(bar, cr, cg, cb)
    PU.SetPoint(bbRight, "TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    PU.SetPoint(bbRight, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    PU.SetWidth(bbRight, BORDER_W)
    barBorders.right = bbRight

    bar._borders = barBorders

    -- Section separators
    local function MakeInfoBarSep(parent)
        local s = parent:CreateTexture(nil, "ARTWORK")
        s:SetTexture(TEX)
        s:SetVertexColor(cr, cg, cb, 0.5)
        s:SetSize(1, 14)
        s:Hide()
        return s
    end
    bar._sep1 = MakeInfoBarSep(bar)
    bar._sep2 = MakeInfoBarSep(bar)
    bar._sep3 = MakeInfoBarSep(bar)

    -- Section buttons (4 clickable zones)
    local FONT_PATH = GetFont()
    local SECTION_CLICKS = {
        function()
            if InCombatLockdown() then return end
            if PlayerSpellsMicroButton then PlayerSpellsMicroButton:Click()
            elseif TalentMicroButton then TalentMicroButton:Click() end
        end,
        function()
            if InCombatLockdown() then return end
            ToggleAllBags()
        end,
        function()
            if InCombatLockdown() then return end
            if CharacterMicroButton then CharacterMicroButton:Click() end
        end,
        function() end,
    }

    local ibFs = 11
    local function MakeInfoBarSection(parent, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(120, GetInfoBarH())

        local txt = btn:CreateFontString(nil, "OVERLAY")
        txt:SetFontObject("GameFontHighlightSmall")
        pcall(function() txt:SetFont(FONT_PATH, ibFs, "OUTLINE") end)
        txt:SetPoint("CENTER")
        txt:SetTextColor(1, 1, 1, 1)

        btn:SetScript("OnEnter", function() txt:SetTextColor(1, 1, 0, 1) end)
        btn:SetScript("OnLeave", function() txt:SetTextColor(1, 1, 1, 1) end)
        btn:SetScript("OnClick", onClick)

        btn._text = txt
        return btn, txt
    end

    local sections = {}
    local sectionTexts = {}
    for i = 1, 4 do
        local btn, txt = MakeInfoBarSection(bar, SECTION_CLICKS[i])
        sections[i] = btn
        sectionTexts[i] = txt
    end
    bar._sections = sections
    bar._specText = sectionTexts[1]
    bar._goldText = sectionTexts[2]
    bar._durabilityText = sectionTexts[3]
    bar._perfText = sectionTexts[4]

    panel._infoBar = bar

    return panel
end

-- ============================================================================
-- Skin helpers
-- ============================================================================

local INFOBAR_RATIOS = { 0.35, 0.15, 0.15, 0.35 }

function Skin.LayoutInfoBarSections(bar, panelWidth)
    if not bar or not bar._sections then return end
    local offsets = { 0 }
    for i = 1, #INFOBAR_RATIOS do
        offsets[i + 1] = offsets[i] + panelWidth * INFOBAR_RATIOS[i]
    end
    if bar._sep1 then bar._sep1:ClearAllPoints(); bar._sep1:SetPoint("CENTER", bar, "LEFT", offsets[2], 0); bar._sep1:Show() end
    if bar._sep2 then bar._sep2:ClearAllPoints(); bar._sep2:SetPoint("CENTER", bar, "LEFT", offsets[3], 0); bar._sep2:Show() end
    if bar._sep3 then bar._sep3:ClearAllPoints(); bar._sep3:SetPoint("CENTER", bar, "LEFT", offsets[4], 0); bar._sep3:Show() end
    for i, btn in ipairs(bar._sections) do
        if i <= #INFOBAR_RATIOS then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bar, "LEFT", offsets[i], 0)
            btn:SetSize(panelWidth * INFOBAR_RATIOS[i], GetInfoBarH())
        end
    end
end

function Skin.ClearInfoBarSections(bar)
    if not bar then return end
    if bar._specText then bar._specText:SetText("") end
    if bar._goldText then bar._goldText:SetText("") end
    if bar._durabilityText then bar._durabilityText:SetText("") end
    if bar._perfText then bar._perfText:SetText("") end
    if bar._sep1 then bar._sep1:Hide() end
    if bar._sep2 then bar._sep2:Hide() end
    if bar._sep3 then bar._sep3:Hide() end
end

function Skin.RefreshInfoBarStyle(bar, panelWidth)
    if not bar then return end
    local h = GetInfoBarH()
    local alpha = GetInfoBarOpacity()
    bar:SetHeight(h)
    if bar._bg then bar._bg:SetVertexColor(0, 0, 0, alpha) end
    if bar._sections then
        for _, btn in ipairs(bar._sections) do btn:SetHeight(h) end
    end
end

function Skin.RefreshColors(panel)
    if not panel then return end
    local r, g, b = GetClassColor()
    if panel._borders then
        for _, tex in pairs(panel._borders) do
            if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, 1) end
        end
    end
    if panel._tabSep then panel._tabSep:SetVertexColor(r, g, b, 0.5) end
    if panel._infoBar and panel._infoBar._borders then
        for _, tex in pairs(panel._infoBar._borders) do
            if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, 1) end
        end
    end
end

function Skin.RefreshPanel(panel, db)
    if not panel or not db then return end
    panel:SetSize(db.panelWidth or 440, db.panelHeight or 223)
    if panel._bg then panel._bg:SetVertexColor(0, 0, 0, db.opacity or 0.75) end
    Skin.RefreshInfoBarStyle(panel._infoBar, db.panelWidth or 440)
    local tabZoneTotal = db._tabZoneTotal or db._tabZone or 29
    if panel._tabSep then
        panel._tabSep:ClearAllPoints()
        panel._tabSep:SetPoint("LEFT", panel, "TOPLEFT", 0, -tabZoneTotal)
        panel._tabSep:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -tabZoneTotal)
    end
    if panel._content then
        panel._content:ClearAllPoints()
        panel._content:SetPoint("TOPLEFT", panel, "TOPLEFT", BORDER_W, -(tabZoneTotal + 1))
        panel._content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_W, GetInfoBarH() + BORDER_W)
    end
    Skin.RefreshColors(panel)
end

-- ============================================================================
-- PART 2 — BARS FACTORY STUB (sera complété avec le vrai port de UI/Bars.lua)
-- ============================================================================

local Bars = {}

local MODE_INFO = {
    damage      = { label = "D\195\169g\195\162ts Inflig\195\169s", suffix = "DPS",  detailPrefix = "D\195\169g\195\162ts inflig\195\169s de ", statLabel = "D\195\169g\195\162ts" },
    damageTaken = { label = "D\195\169g\195\162ts Subis",           suffix = "DTPS", detailPrefix = "D\195\169g\195\162ts subis par ",          statLabel = "D\195\169g\195\162ts" },
    healing     = { label = "Soins Prodigu\195\169s",               suffix = "HPS",  detailPrefix = "Soins prodigu\195\169s de ",               statLabel = "Soins" },
    interrupts  = { label = "Interruptions",                       suffix = "INT",  detailPrefix = "Interruptions de ",                        statLabel = "Interruptions" },
    dispels     = { label = "Dissipations",                        suffix = "DISP", detailPrefix = "Dissipations de ",                         statLabel = "Dissipations" },
    avoidable   = { label = "D\195\169g\195\162ts \195\137vitables", suffix = "ADPS", detailPrefix = "D\195\169g\195\162ts \195\169vitables de ", statLabel = "D\195\169g\195\162ts" },
}

local MODE_ORDER = { "damage", "damageTaken", "healing", "interrupts", "dispels", "avoidable" }

local BAR_BG_ALPHA  = 0.25
local HEADER_HEIGHT = 18
local ICON_PADDING  = 2

function Bars.New(fixedMode)
    local inst = {}

    local container = nil
    local headerFrame = nil
    local headerVisible = true
    local selectedSegmentId = 0
    local scrollOffset = 0
    local barPool = {}
    local activeBars = {}
    local testData = nil
    local testSessionInfo = nil

    -- SEGMENT
    function inst:SetSegment(id)
        selectedSegmentId = id or 0
        scrollOffset = 0
        inst:Refresh()
    end
    function inst:GetSegmentId() return selectedSegmentId end
    function inst:CycleSegment(direction)
        local segs = DM:GetSegments()
        local maxIdx = segs and #segs or 0
        if direction > 0 then
            if selectedSegmentId == 0 then selectedSegmentId = -1
            elseif selectedSegmentId == -1 then selectedSegmentId = (maxIdx > 0) and 1 or 0
            else selectedSegmentId = (selectedSegmentId < maxIdx) and (selectedSegmentId + 1) or 0 end
        else
            if selectedSegmentId == 0 then selectedSegmentId = (maxIdx > 0) and maxIdx or -1
            elseif selectedSegmentId == -1 then selectedSegmentId = 0
            else selectedSegmentId = selectedSegmentId - 1; if selectedSegmentId < 1 then selectedSegmentId = -1 end end
        end
        scrollOffset = 0
        inst:Refresh()
    end

    -- MODE
    function inst:SetMode(m) fixedMode = m; scrollOffset = 0; inst:Refresh() end
    function inst:GetMode() return fixedMode end

    -- CONTAINER
    function inst:SetContainer(c)
        container = c
        if container then
            container:EnableMouseWheel(true)
            container:SetScript("OnMouseWheel", function(_, delta)
                scrollOffset = scrollOffset + (delta > 0 and -3 or 3)
                inst:Refresh()
            end)
        end
    end
    function inst:GetContainer() return container end

    -- HEADER VISIBLE
    function inst:SetHeaderVisible(v)
        headerVisible = v
        if headerFrame then
            if v then headerFrame:Show() else headerFrame:Hide() end
        end
    end

    -- TEST DATA
    function inst:SetTestData(data, info) testData = data; testSessionInfo = info; scrollOffset = 0; inst:Refresh() end
    function inst:ClearTestData() testData = nil; testSessionInfo = nil; scrollOffset = 0 end
    function inst:HasTestData() return testData ~= nil end

    -- ======================================================================
    -- BAR CREATION
    -- ======================================================================
    local function CreateBar(parent)
        local db = GetDB()
        local barH = db.barHeight or 16
        local fontSize = db.fontSize or 9
        local font = GetFont()

        local bar = CreateFrame("Button", nil, parent)
        bar:SetHeight(barH)

        local bgTex = bar:CreateTexture(nil, "BACKGROUND")
        bgTex:SetTexture(TEX)
        bgTex:SetVertexColor(0, 0, 0, BAR_BG_ALPHA)
        bgTex:SetAllPoints(bar)
        bar._bg = bgTex

        local icon = bar:CreateTexture(nil, "OVERLAY")
        icon:SetSize(barH, barH)
        icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        bar._icon = icon

        local statusBar = bar:CreateTexture(nil, "ARTWORK")
        statusBar:SetTexture(TEX)
        statusBar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 0, 0)
        statusBar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 0, 0)
        bar._bar = statusBar

        local rightText = bar:CreateFontString(nil, "OVERLAY")
        rightText:SetFont(font, fontSize, "OUTLINE")
        rightText:SetShadowOffset(1, -1)
        rightText:SetShadowColor(0, 0, 0, 0.6)
        rightText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        rightText:SetJustifyH("RIGHT")
        rightText:SetWordWrap(false)
        bar._rightText = rightText

        local rankText = bar:CreateFontString(nil, "OVERLAY")
        rankText:SetFont(font, fontSize, "OUTLINE")
        rankText:SetShadowOffset(1, -1)
        rankText:SetShadowColor(0, 0, 0, 0.6)
        rankText:SetPoint("LEFT", icon, "RIGHT", ICON_PADDING, 0)
        rankText:SetJustifyH("LEFT")
        rankText:SetWordWrap(false)
        rankText:Hide()
        bar._rankText = rankText

        local leftText = bar:CreateFontString(nil, "OVERLAY")
        leftText:SetFont(font, fontSize, "OUTLINE")
        leftText:SetShadowOffset(1, -1)
        leftText:SetShadowColor(0, 0, 0, 0.6)
        leftText:SetPoint("LEFT", icon, "RIGHT", ICON_PADDING, 0)
        leftText:SetPoint("RIGHT", rightText, "LEFT", -4, 0)
        leftText:SetJustifyH("LEFT")
        leftText:SetWordWrap(false)
        bar._leftText = leftText

        bar:SetScript("OnEnter", function(self)
            if self._bg then self._bg:SetVertexColor(0.15, 0.15, 0.15, 0.5) end
        end)
        bar:SetScript("OnLeave", function(self)
            if self._bg then self._bg:SetVertexColor(0, 0, 0, BAR_BG_ALPHA) end
        end)

        bar:EnableMouse(true)
        bar:RegisterForClicks("LeftButtonUp")

        bar._targetWidth = 0
        bar._currentWidth = 0

        return bar
    end

    local function AcquireBar(parent, index)
        local bar = barPool[index]
        if not bar then
            bar = CreateBar(parent)
            barPool[index] = bar
        end
        bar:SetParent(parent)
        bar:Show()
        return bar
    end

    local function HideAllBars()
        for _, bar in ipairs(barPool) do
            bar:Hide()
            bar._guid = nil
            bar._name = nil
            bar._targetWidth = 0
            bar._currentWidth = 0
            if bar._icon then bar._icon:Hide() end
            if bar._rankText then bar._rankText:Hide() end
        end
        activeBars = {}
    end

    -- ======================================================================
    -- ANIMATION DRIVER
    -- ======================================================================
    local LERP_SPEED = 8
    local animFrame = CreateFrame("Frame")
    animFrame:SetScript("OnUpdate", function(_, elapsed)
        if #activeBars == 0 then return end
        local dt = math.min(elapsed * LERP_SPEED, 1)
        for _, bar in ipairs(activeBars) do
            local target = bar._targetWidth
            if target and target > 0 then
                local cur = bar._currentWidth or 0
                local diff = target - cur
                if diff ~= 0 then
                    if math.abs(diff) < 0.5 then
                        bar._currentWidth = target
                        bar._bar:SetWidth(target)
                    else
                        local newW = cur + diff * dt
                        bar._currentWidth = newW
                        bar._bar:SetWidth(newW)
                    end
                end
            end
        end
    end)

    -- ======================================================================
    -- HEADER
    -- ======================================================================
    local function CreateHeader(parent)
        local db = GetDB()
        local font = GetFont()
        local fontSize = (db.fontSize or 9) + 1

        local frame = CreateFrame("Button", nil, parent)
        frame:SetHeight(HEADER_HEIGHT)
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(TEX)
        bg:SetVertexColor(0, 0, 0, 0.4)
        bg:SetAllPoints(frame)

        local modeText = frame:CreateFontString(nil, "OVERLAY")
        modeText:SetFont(font, fontSize, "OUTLINE")
        modeText:SetPoint("LEFT", frame, "LEFT", 4, 0)
        modeText:SetJustifyH("LEFT")
        frame._modeText = modeText

        local infoText = frame:CreateFontString(nil, "OVERLAY")
        infoText:SetFont(font, fontSize - 1, "OUTLINE")
        infoText:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        infoText:SetJustifyH("RIGHT")
        infoText:SetTextColor(0.7, 0.7, 0.7)
        frame._infoText = infoText

        return frame
    end

    local function GetSegmentLabel()
        if selectedSegmentId == 0 then return "En cours"
        elseif selectedSegmentId == -1 then return "Overall"
        else return "Segment #" .. selectedSegmentId end
    end

    local function UpdateHeader(sessionInfo)
        if not headerFrame then return end
        if not headerVisible then headerFrame:Hide(); return end
        headerFrame:Show()

        local modeInfo = MODE_INFO[fixedMode] or MODE_INFO.damage
        headerFrame._modeText:SetText(modeInfo.label .. " \226\128\148 " .. GetSegmentLabel())

        local info = ""
        if sessionInfo then
            local duration = sessionInfo.duration or 0
            local BD = BravUI.Meter
            if selectedSegmentId == 0 and BD and BD.IsInCombat and BD:IsInCombat() then
                duration = BD:GetCombatTime()
            end
            if duration and type(duration) == "number" and duration > 0 then
                local m = math.floor(duration / 60)
                local s = math.floor(duration % 60)
                local totalPS = F.SafeDiv(sessionInfo.totalAmount, duration)
                if totalPS then
                    info = string.format("%d:%02d  |  %s %s", m, s, F.Number(totalPS), modeInfo.suffix)
                else
                    info = string.format("%d:%02d", m, s)
                end
            end
        end
        headerFrame._infoText:SetText(info)
    end

    -- ======================================================================
    -- REFRESH
    -- ======================================================================
    function inst:Refresh()
        if not container then return end

        local db = GetDB()

        if not headerFrame then headerFrame = CreateHeader(container) end
        if not headerVisible then headerFrame:Hide() end

        HideAllBars()

        local data, sessionInfo
        if testData then
            data = testData
            sessionInfo = testSessionInfo
        else
            if not DM or not DM:IsAvailable() then return end
            data = DM:GetSorted(fixedMode, selectedSegmentId)
            sessionInfo = DM:GetSessionInfo(selectedSegmentId, fixedMode)
        end

        UpdateHeader(sessionInfo)

        if not data or #data == 0 then return end

        -- Recalculer perSecond
        if not testData then
            local duration = nil
            if sessionInfo and sessionInfo.duration then
                local okD, dVal = pcall(function()
                    if type(sessionInfo.duration) == "number" and sessionInfo.duration > 0 then return sessionInfo.duration end
                    return nil
                end)
                if okD and dVal then duration = dVal end
            end
            local BD = BravUI.Meter
            if selectedSegmentId == 0 and BD and BD.IsInCombat and BD:IsInCombat() then
                local ct = BD:GetCombatTime()
                if ct and ct > 0 then duration = ct end
            end
            if duration and duration > 0 then
                for _, entry in ipairs(data) do
                    local ownPS = F.SafeDiv(entry.value, duration)
                    if ownPS then entry.perSecond = ownPS end
                end
            end
        end

        local barH = db.barHeight or 16
        local spacing = db.barSpacing or 1
        local maxBars = testData and #data or (db.maxBars or 50)
        local headerH = headerVisible and (HEADER_HEIGHT + spacing) or 0
        local font = GetFont()
        local fontSize = db.fontSize or 9

        local containerH = container:GetHeight()
        local visibleBars = math.floor((containerH - headerH) / (barH + spacing))
        visibleBars = math.max(1, math.min(visibleBars, maxBars))

        local totalEntries = math.min(#data, maxBars)
        local maxScroll = math.max(0, totalEntries - visibleBars)
        if scrollOffset > maxScroll then scrollOffset = maxScroll end
        if scrollOffset < 0 then scrollOffset = 0 end

        local maxVal = nil
        if #data > 0 and data[1].value then
            local ok, v = pcall(function()
                local n = data[1].value
                if type(n) == "number" and n > 0 then return n end
                return nil
            end)
            if ok and v then maxVal = v end
        end

        local totalAmount = nil
        if sessionInfo and sessionInfo.totalAmount then
            local ok, v = pcall(function()
                local n = sessionInfo.totalAmount
                if type(n) == "number" and n > 0 then return n end
                return nil
            end)
            if ok and v then totalAmount = v end
        end

        for i = 1, visibleBars do
            local dataIdx = i + scrollOffset
            if dataIdx > totalEntries then break end

            local entry = data[dataIdx]
            local bar = AcquireBar(container, i)
            bar:SetHeight(barH)
            bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(headerH + (i - 1) * (barH + spacing)))
            bar:SetPoint("RIGHT", container, "RIGHT", 0, 0)

            bar._leftText:SetFont(font, fontSize, "OUTLINE")
            bar._rightText:SetFont(font, fontSize, "OUTLINE")

            local r, g, b
            if db.classColors == false then r, g, b = 0.6, 0.6, 0.6
            else r, g, b = ClassColor(entry.class) end

            local pct
            if maxVal then pct = F.SafeDiv(entry.value, maxVal) end
            if not pct then pct = math.max(0.05, 1 - (dataIdx - 1) * 0.04) end

            local newWidth = math.max(1, (bar:GetWidth() - barH) * pct)
            bar._targetWidth = newWidth
            if bar._currentWidth == 0 then
                bar._currentWidth = newWidth
                bar._bar:SetWidth(newWidth)
            end
            bar._bar:SetVertexColor(r, g, b, 0.7)

            -- Icône spec
            bar._icon:SetSize(barH, barH)
            if entry.specIcon and entry.specIcon > 0 then
                bar._icon:SetTexture(entry.specIcon)
                bar._icon:SetTexCoord(0, 1, 0, 1)
                bar._icon:Show()
            elseif entry.class then
                bar._icon:SetTexture(nil)
                bar._icon:SetAtlas("classicon-" .. string.lower(entry.class))
                bar._icon:Show()
            else
                bar._icon:Hide()
            end

            -- Rank + Nom
            bar._rankText:SetFont(font, fontSize, "OUTLINE")
            bar._rankText:ClearAllPoints()
            bar._rankText:SetPoint("LEFT", bar._icon, "RIGHT", ICON_PADDING, 0)
            if db.showRank then
                bar._rankText:SetText(dataIdx .. ".")
                bar._rankText:SetTextColor(1, 1, 1)
                bar._rankText:Show()
                bar._leftText:ClearAllPoints()
                bar._leftText:SetPoint("LEFT", bar._rankText, "RIGHT", -2, 0)
                bar._leftText:SetPoint("RIGHT", bar._rightText, "LEFT", -4, 0)
            else
                bar._rankText:Hide()
                bar._leftText:ClearAllPoints()
                bar._leftText:SetPoint("LEFT", bar._icon, "RIGHT", ICON_PADDING, 0)
                bar._leftText:SetPoint("RIGHT", bar._rightText, "LEFT", -4, 0)
            end
            bar._leftText:SetText(entry.name or "")
            bar._leftText:SetTextColor(1, 1, 1)

            -- Texte droit
            local fmtPS = F.SafeFormat(entry.perSecond)
            local fmtVal = F.SafeFormat(entry.value, true)
            local wantPct = db.showPercent ~= false

            if fmtPS then
                local rightStr = fmtPS
                local extra = nil
                if fmtVal and totalAmount and wantPct then
                    local pctVal = F.SafeDiv(entry.value, totalAmount)
                    if pctVal then extra = fmtVal .. " | " .. string.format("%.1f%%", pctVal * 100)
                    else extra = fmtVal end
                elseif fmtVal then extra = fmtVal
                elseif totalAmount and wantPct then
                    local pctVal = F.SafeDiv(entry.value, totalAmount)
                    if pctVal then extra = string.format("%.1f%%", pctVal * 100) end
                end
                if extra then rightStr = rightStr .. " (" .. extra .. ")" end
                bar._rightText:SetText(rightStr)
            elseif fmtVal then
                bar._rightText:SetText(fmtVal)
            else
                pcall(function() bar._rightText:SetText(entry.perSecond or entry.value or "") end)
            end
            bar._rightText:SetTextColor(0.9, 0.9, 0.9)

            bar._guid = entry.guid
            bar._name = entry.name
            bar._class = entry.class

            activeBars[i] = bar
        end
    end

    return inst
end

-- ============================================================================
-- PART 3 — PANEL CONTROLLER (port fidèle de DetailsPanel/Init.lua)
-- ============================================================================

local Panel = {}

-- State
Panel._frame = nil
Panel._bars = {}
Panel._containers = {}
Panel._tabs = {}
Panel._seps = {}
Panel._connected = false
Panel._accentR = 0.8
Panel._accentG = 0.8
Panel._accentB = 0.8

-- Constants
local DEFAULT_POINT = "BOTTOMRIGHT"
local DEFAULT_X     = -20
local DEFAULT_Y     = 35

local ALL_MODES = {
    { mode = "damage",      label = "D\195\169g\195\162ts Inflig\195\169s" },
    { mode = "damageTaken", label = "D\195\169g\195\162ts Subis" },
    { mode = "avoidable",   label = "D\195\169g\195\162ts \195\137vitables" },
    { mode = "healing",     label = "Soins Prodigu\195\169s" },
    { mode = "interrupts",  label = "Interruptions" },
    { mode = "dispels",     label = "Dissipations" },
}

local DEFAULT_MODE_IDX = { 1, 4, 2, 5 }

local PAD = 1
local LAYOUTS = {
    [1] = {
        { { "TOPLEFT", "TOPLEFT", 0, 0 },     { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } },
    },
    [2] = {
        { { "TOPLEFT", "TOPLEFT", 0, 0 },     { "BOTTOMRIGHT", "BOTTOM", -PAD, 0 } },
        { { "TOPLEFT", "TOP", PAD, 0 },       { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } },
    },
    [3] = {
        { { "TOPLEFT", "TOPLEFT", 0, 0 },     { "BOTTOMRIGHT", "CENTER", -PAD, PAD } },
        { { "TOPLEFT", "TOP", PAD, 0 },       { "BOTTOMRIGHT", "RIGHT", 0, PAD } },
        { { "TOPLEFT", "LEFT", 0, -PAD },     { "BOTTOMRIGHT", "BOTTOM", -PAD, 0 } },
    },
    [4] = {
        { { "TOPLEFT", "TOPLEFT", 0, 0 },     { "BOTTOMRIGHT", "CENTER", -PAD, PAD } },
        { { "TOPLEFT", "TOP", PAD, 0 },       { "BOTTOMRIGHT", "RIGHT", 0, PAD } },
        { { "TOPLEFT", "LEFT", 0, -PAD },     { "BOTTOMRIGHT", "BOTTOM", -PAD, 0 } },
        { { "TOPLEFT", "CENTER", PAD, -PAD }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } },
    },
}

local LAYOUT_SEPS = {
    [1] = {},
    [2] = {
        { type = "V", "TOP", "TOP", 0, 0, "BOTTOM", "BOTTOM", 0, 0 },
    },
    [3] = {
        { type = "V", "TOP", "TOP", 0, 0,       "BOTTOM", "CENTER", 0, 0 },
        { type = "H", "LEFT", "LEFT", 0, 0,     "RIGHT", "CENTER", 0, 0 },
    },
    [4] = {
        { type = "V", "TOP", "TOP", 0, 0,       "BOTTOM", "BOTTOM", 0, 0 },
        { type = "H", "LEFT", "LEFT", 0, 0,     "RIGHT", "RIGHT", 0, 0 },
    },
}

local LAYOUT_TABS = {
    [1] = {
        { left = 0, right = 1, row = 0 },
    },
    [2] = {
        { left = 0, right = 0.5, row = 0 },
        { left = 0.5, right = 1, row = 0 },
    },
    [3] = {
        { left = 0, right = 0.5, row = 0 },
        { left = 0.5, right = 1, row = 0 },
        { left = 0, right = 0.5, row = 1 },
    },
    [4] = {
        { left = 0, right = 0.5, row = 0 },
        { left = 0.5, right = 1, row = 0 },
        { left = 0, right = 0.5, row = 1 },
        { left = 0.5, right = 1, row = 1 },
    },
}

-- ============================================================================
-- Panel.Setup
-- ============================================================================

function Panel.Setup()
    if Panel._frame then return end

    local db = GetDB()
    local layout = db.layout or 2
    local hasBottomRow = (layout >= 3)
    db._tabZone = (db.tabHeight or 15) + 3
    db._tabZoneTotal = hasBottomRow and (db._tabZone * 2) or db._tabZone

    Panel._frame = Skin.CreatePanel(db)

    local panel = Panel._frame
    panel:ClearAllPoints()
    local pos = BravLib.API.Get("positions", "Meter Panel")
    if pos and pos.x and pos.y then
        local fs = panel:GetScale() or 1
        panel:SetPoint("CENTER", UIParent, "CENTER", pos.x / fs, pos.y / fs)
    else
        panel:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
    end

    panel:Show()

    -- Register with /bravmove
    C_Timer.After(1.5, function()
        if BravUI.Move and BravUI.Move.Enable then
            BravUI.Move.Enable(panel, "Meter Panel")
        end
    end)

    Panel.ConnectMeter()
    Skin.LayoutInfoBarSections(panel._infoBar, db.panelWidth or 440)
end

-- ============================================================================
-- Panel.ConnectMeter
-- ============================================================================

function Panel.ConnectMeter()
    local panel = Panel._frame
    if not panel or not panel._content then return end
    if Panel._connected then return end

    local content = panel._content
    local db = GetDB()
    local layout = db.layout or 2
    local layoutDef = LAYOUTS[layout] or LAYOUTS[2]
    local numWindows = #layoutDef

    local cr, cg, cb = GetClassColor()
    Panel._accentR, Panel._accentG, Panel._accentB = cr, cg, cb

    -- Créer N instances Bars
    for i = 1, numWindows do
        local modeIdx = DEFAULT_MODE_IDX[i] or 1
        Panel._bars[i] = Bars.New(ALL_MODES[modeIdx].mode)
    end

    -- Créer N containers
    for i = 1, numWindows do
        local anchors = layoutDef[i]
        local c = CreateFrame("Frame", nil, content)
        c:SetPoint(anchors[1][1], content, anchors[1][2], anchors[1][3], anchors[1][4])
        c:SetPoint(anchors[2][1], content, anchors[2][2], anchors[2][3], anchors[2][4])
        c:Show()

        Panel._bars[i]:SetContainer(c)
        Panel._bars[i]:SetHeaderVisible(false)
        Panel._containers[i] = c
    end

    -- Séparateurs
    local sepDefs = LAYOUT_SEPS[layout] or {}
    for _, sd in ipairs(sepDefs) do
        local sep = content:CreateTexture(nil, "OVERLAY")
        sep:SetTexture(TEX)
        sep:SetVertexColor(cr, cg, cb, 0.4)
        if sd.type == "V" then
            sep:SetWidth(1)
            sep:SetPoint(sd[1], content, sd[2], sd[3], sd[4])
            sep:SetPoint(sd[5], content, sd[6], sd[7], sd[8])
        else
            sep:SetHeight(1)
            sep:SetPoint(sd[1], content, sd[2], sd[3], sd[4])
            sep:SetPoint(sd[5], content, sd[6], sd[7], sd[8])
        end
        Panel._seps[#Panel._seps + 1] = sep
    end

    -- Tabs
    Panel.CreateTabs()

    Panel._connected = true
end

-- ============================================================================
-- Panel.CreateTabs
-- ============================================================================

function Panel.CreateTabs()
    if Panel._tabs then
        for _, t in ipairs(Panel._tabs) do
            if t.half then t.half:Hide() end
        end
    end
    Panel._tabs = {}

    local panel = Panel._frame
    local db = GetDB()
    local layout = db.layout or 2
    local tabZone = db._tabZone or 18
    local font = GetFont()
    local fontSize = (db.tabHeight or 15) - 4
    local cr, cg, cb = GetClassColor()
    local tabDefs = LAYOUT_TABS[layout] or LAYOUT_TABS[2]

    for idx = 1, #tabDefs do
        local td = tabDefs[idx]
        local barsInst = Panel._bars[idx]
        local modeIdx = DEFAULT_MODE_IDX[idx] or 1

        local tab = Panel.CreateOneTab(panel, td, tabZone, font, fontSize, cr, cg, cb, barsInst, modeIdx, idx)
        Panel._tabs[idx] = tab
    end

    -- Séparateur horizontal entre rangées de tabs (layouts 3/4)
    if layout >= 3 then
        if not Panel._tabRowSep then
            Panel._tabRowSep = panel:CreateTexture(nil, "ARTWORK")
            Panel._tabRowSep:SetTexture(TEX)
            Panel._tabRowSep:SetHeight(1)
        end
        Panel._tabRowSep:SetVertexColor(cr, cg, cb, 0.5)
        Panel._tabRowSep:ClearAllPoints()
        Panel._tabRowSep:SetPoint("LEFT", panel, "TOPLEFT", 0, -tabZone)
        Panel._tabRowSep:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -tabZone)
        Panel._tabRowSep:Show()
    elseif Panel._tabRowSep then
        Panel._tabRowSep:Hide()
    end
end

function Panel.CreateOneTab(panel, td, tabZone, font, fontSize, cr, cg, cb, barsInst, modeIdx, slotIdx)
    local half = CreateFrame("Frame", nil, panel)
    local yOffset = -(td.row * tabZone)

    local leftPoint  = (td.left == 0) and "TOPLEFT"  or "TOP"
    local rightPoint = (td.right == 1) and "TOPRIGHT" or "TOP"

    half:ClearAllPoints()
    half:SetPoint("TOPLEFT", panel, leftPoint, 0, yOffset)
    half:SetPoint("BOTTOMRIGHT", panel, rightPoint, 0, yOffset - tabZone)

    -- Label mode
    local modeLabel = CreateFrame("Button", nil, half)
    modeLabel:SetHeight(tabZone)
    modeLabel:SetPoint("LEFT", half, "LEFT", BORDER_W + 4, 0)
    modeLabel:SetWidth(120)

    local modeLabelText = modeLabel:CreateFontString(nil, "OVERLAY")
    modeLabelText:SetFont(font, fontSize, "OUTLINE")
    modeLabelText:SetText(ALL_MODES[modeIdx].label)
    modeLabelText:SetTextColor(1, 1, 1, 0.9)
    modeLabelText:SetPoint("LEFT", modeLabel, "LEFT", 0, 0)
    modeLabelText:SetJustifyH("LEFT")

    modeLabel:RegisterForClicks("LeftButtonUp")
    modeLabel:SetScript("OnClick", function()
        modeIdx = (modeIdx % #ALL_MODES) + 1
        modeLabelText:SetText(ALL_MODES[modeIdx].label)
        if barsInst then barsInst:SetMode(ALL_MODES[modeIdx].mode) end
    end)
    modeLabel:SetScript("OnEnter", function()
        modeLabelText:SetTextColor(Panel._accentR, Panel._accentG, Panel._accentB, 1)
    end)
    modeLabel:SetScript("OnLeave", function()
        modeLabelText:SetTextColor(1, 1, 1, 0.9)
    end)

    -- Bouton reset (droite)
    local resetBtn = CreateFrame("Button", nil, half)
    resetBtn:SetSize(14, tabZone - 4)
    resetBtn:SetPoint("RIGHT", half, "RIGHT", -4, 0)
    local resetTex = resetBtn:CreateTexture(nil, "OVERLAY")
    resetTex:SetTexture("Interface/Buttons/UI-StopButton")
    resetTex:SetSize(12, 12)
    resetTex:SetPoint("CENTER")
    resetTex:SetVertexColor(cr, cg, cb, 0.7)
    resetBtn:SetScript("OnClick", function()
        DM:Reset()
        for _, inst in ipairs(Panel._bars) do
            if inst then inst:SetSegment(0); inst:Refresh() end
        end
    end)
    resetBtn:SetScript("OnEnter", function() resetTex:SetVertexColor(1, 0.3, 0.3, 1) end)
    resetBtn:SetScript("OnLeave", function() resetTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7) end)

    -- Bouton partage
    local shareBtn = CreateFrame("Button", nil, half)
    shareBtn:SetSize(14, tabZone - 4)
    shareBtn:SetPoint("RIGHT", resetBtn, "LEFT", -3, 0)
    local shareTex = shareBtn:CreateTexture(nil, "OVERLAY")
    shareTex:SetTexture("Interface/GossipFrame/ChatBubbleGossipIcon")
    shareTex:SetSize(12, 12)
    shareTex:SetPoint("CENTER")
    shareTex:SetVertexColor(cr, cg, cb, 0.7)
    shareBtn:SetScript("OnEnter", function() shareTex:SetVertexColor(1, 1, 1, 1) end)
    shareBtn:SetScript("OnLeave", function() shareTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7) end)

    -- Bouton segments
    local segBtn = CreateFrame("Button", nil, half)
    segBtn:SetSize(14, tabZone - 4)
    segBtn:SetPoint("RIGHT", shareBtn, "LEFT", -3, 0)
    local segTex = segBtn:CreateTexture(nil, "OVERLAY")
    segTex:SetTexture("Interface/BUTTONS/UI-GuildButton-PublicNote-Up")
    segTex:SetSize(12, 12)
    segTex:SetPoint("CENTER")
    segTex:SetVertexColor(cr, cg, cb, 0.7)
    segBtn:SetScript("OnEnter", function() segTex:SetVertexColor(1, 1, 1, 1) end)
    segBtn:SetScript("OnLeave", function() segTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7) end)

    -- Molette = navigation segments
    half:EnableMouseWheel(true)
    half:SetScript("OnMouseWheel", function(_, delta)
        for _, inst in ipairs(Panel._bars) do
            if inst and inst.CycleSegment then inst:CycleSegment(delta > 0 and -1 or 1) end
        end
    end)

    return {
        half = half,
        modeLabelText = modeLabelText,
        segTex = segTex,
        shareTex = shareTex,
        resetTex = resetTex,
    }
end

-- ============================================================================
-- Panel public API
-- ============================================================================

function Panel.RefreshBars()
    for _, inst in ipairs(Panel._bars) do
        if inst and inst.Refresh then inst:Refresh() end
    end
end

function Panel.Refresh()
    local panel = Panel._frame
    if not panel then return end
    local db = GetDB()
    local layout = db.layout or 2
    local hasBottomRow = (layout >= 3)
    db._tabZone = (db.tabHeight or 15) + 3
    db._tabZoneTotal = hasBottomRow and (db._tabZone * 2) or db._tabZone
    Skin.RefreshPanel(panel, db)
    Panel.RefreshColors()
    Panel.RefreshBars()
end

function Panel.RefreshColors()
    local panel = Panel._frame
    if not panel then return end
    local r, g, b = GetClassColor()
    Panel._accentR, Panel._accentG, Panel._accentB = r, g, b

    for _, sep in ipairs(Panel._seps) do
        if sep:IsShown() then sep:SetVertexColor(r, g, b, 0.4) end
    end
    if Panel._tabRowSep and Panel._tabRowSep:IsShown() then
        Panel._tabRowSep:SetVertexColor(r, g, b, 0.5)
    end
    if Panel._tabs then
        for _, tab in ipairs(Panel._tabs) do
            if tab.resetTex then tab.resetTex:SetVertexColor(r, g, b, 0.7) end
            if tab.shareTex then tab.shareTex:SetVertexColor(r, g, b, 0.7) end
            if tab.segTex   then tab.segTex:SetVertexColor(r, g, b, 0.7) end
        end
    end
end

function Panel.Toggle()
    local panel = Panel._frame
    if panel then
        if panel:IsShown() then panel:Hide() else panel:Show() end
    end
end

function Panel.Hide()
    if Panel._frame then Panel._frame:Hide() end
end

function Panel.Show()
    if Panel._frame then Panel._frame:Show() end
end

function Panel.SetTestData(dmgData, healData, sessionInfo)
    if Panel._bars[1] then Panel._bars[1]:SetTestData(dmgData, sessionInfo) end
    if Panel._bars[2] then Panel._bars[2]:SetTestData(healData, sessionInfo) end
end

function Panel.ClearTestData()
    for _, inst in ipairs(Panel._bars) do
        if inst then inst:ClearTestData() end
    end
end

function Panel.SetSegment(id)
    for _, inst in ipairs(Panel._bars) do
        if inst then inst:SetSegment(id) end
    end
end

function Panel.GetSegmentId()
    if Panel._bars[1] then return Panel._bars[1]:GetSegmentId() end
    return 0
end

-- ============================================================================
-- EXPOSE
-- ============================================================================

BravUI.Meter.Bars = Bars
BravUI.Meter.Skin = Skin
BravUI.Meter.Panel = Panel

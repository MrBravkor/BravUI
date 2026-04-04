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
-- CUSTOM TOOLTIP (style BravUI — fond noir, bordure classe, police Russo)
-- ============================================================================

local customTooltip = nil

local function ShowBravTooltip(owner, title, ...)
    if not customTooltip then
        local f = CreateFrame("Frame", "BravUI_MeterTooltip", UIParent)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(999)
        f:SetClampedToScreen(true)

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(TEX)
        bg:SetVertexColor(0, 0, 0, 0.9)
        bg:SetAllPoints(f)
        f._bg = bg

        local PU = PixelUtil
        f._borders = {}
        for _, args in ipairs({
            {"TOPLEFT", "TOPRIGHT", true},
            {"BOTTOMLEFT", "BOTTOMRIGHT", true},
            {"TOPLEFT", "BOTTOMLEFT", false},
            {"TOPRIGHT", "BOTTOMRIGHT", false},
        }) do
            local b = f:CreateTexture(nil, "OVERLAY", nil, 7)
            b:SetTexture(TEX)
            PU.SetPoint(b, args[1], f, args[1], 0, 0)
            PU.SetPoint(b, args[2], f, args[2], 0, 0)
            if args[3] then PU.SetHeight(b, 2) else PU.SetWidth(b, 2) end
            f._borders[#f._borders + 1] = b
        end

        f._title = f:CreateFontString(nil, "OVERLAY")
        f._lines = {}
        for i = 1, 4 do
            f._lines[i] = f:CreateFontString(nil, "OVERLAY")
        end

        customTooltip = f
    end

    local tt = customTooltip
    local font = GetFont()
    local cr, cg, cb = GetClassColor()
    local pad = 8

    -- Bordure couleur de classe
    for _, b in ipairs(tt._borders) do b:SetVertexColor(cr, cg, cb, 1) end

    -- Titre
    tt._title:SetFont(font, 11, "OUTLINE")
    tt._title:SetText(title)
    tt._title:SetTextColor(cr, cg, cb, 1)
    tt._title:ClearAllPoints()
    tt._title:SetPoint("TOPLEFT", tt, "TOPLEFT", pad, -pad)

    -- Lignes de description
    local lines = { ... }
    local yOff = pad + 14
    for i = 1, 4 do
        local line = tt._lines[i]
        if lines[i] then
            line:SetFont(font, 9, "OUTLINE")
            line:SetText(lines[i])
            line:SetTextColor(0.7, 0.7, 0.7)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", tt, "TOPLEFT", pad, -yOff)
            line:Show()
            yOff = yOff + 12
        else
            line:Hide()
        end
    end

    -- Taille
    local maxW = tt._title:GetStringWidth()
    for i = 1, #lines do
        local lw = tt._lines[i]:GetStringWidth()
        if lw > maxW then maxW = lw end
    end
    tt:SetSize(maxW + pad * 2 + 4, yOff + pad - 2)

    -- Position au-dessus du owner
    tt:ClearAllPoints()
    tt:SetPoint("BOTTOM", owner, "TOP", 0, 6)
    tt:Show()
end

local function HideBravTooltip()
    if customTooltip then customTooltip:Hide() end
end

-- ============================================================================
-- PART 1 — PANEL SKIN (port fidèle de DetailsPanel/Skin.lua)
-- ============================================================================

local Skin = {}
local BORDER_W = 2
local HEADER_HEIGHT = 18

local function GetInfoBarH() return 22 end
local function GetInfoBarOpacity()
    local db = GetDB()
    return db and db.footerOpacity or 0.75
end
local function GetHeaderOpacity()
    local db = GetDB()
    return db and db.headerOpacity or 0.4
end

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

    -- Tab zone bg (top of panel to tab separator) — piloté par headerOpacity
    local tabBg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    tabBg:SetTexture(TEX)
    local showBg = db.showBackground ~= false
    local headerAlpha = showBg and (db.headerOpacity or 0.4) or 0
    tabBg:SetVertexColor(0, 0, 0, headerAlpha)
    panel._tabBg = tabBg

    -- Content zone bg (below headers, above infobar) — piloté par opacity (fond)
    local contentBg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    contentBg:SetTexture(TEX)
    local bgAlpha = showBg and (db.opacity or 0.75) or 0
    contentBg:SetVertexColor(0, 0, 0, bgAlpha)
    panel._bg = contentBg

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
    local db = GetDB()
    local h = GetInfoBarH()
    local bgOff = db and db.showBackground == false
    local alpha = bgOff and 0 or GetInfoBarOpacity()
    bar:SetHeight(h)
    if bar._bg then bar._bg:SetVertexColor(0, 0, 0, alpha) end
    -- Masquer les bordures quand le fond est désactivé ou footer à 0
    if bar._borders then
        local borderAlpha = (alpha > 0) and 1 or 0
        for _, tex in pairs(bar._borders) do
            if tex and tex.SetAlpha then tex:SetAlpha(borderAlpha) end
        end
    end
    -- Masquer les séparateurs
    if alpha == 0 then
        if bar._sep1 then bar._sep1:Hide() end
        if bar._sep2 then bar._sep2:Hide() end
        if bar._sep3 then bar._sep3:Hide() end
    end
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

    local bgAlpha = (db.showBackground ~= false) and (db.opacity or 0.75) or 0
    local tabZoneTotal = db._tabZoneTotal or db._tabZone or 29

    -- Tab zone bg : top → tab separator (piloté par headerOpacity)
    if panel._tabBg then
        local headerAlpha = (db.showBackground ~= false) and (db.headerOpacity or 0.4) or 0
        panel._tabBg:ClearAllPoints()
        panel._tabBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        panel._tabBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
        panel._tabBg:SetHeight(tabZoneTotal)
        panel._tabBg:SetVertexColor(0, 0, 0, headerAlpha)
    end

    -- Content bg : tab separator → above infobar (fond principal)
    if panel._bg then
        panel._bg:ClearAllPoints()
        panel._bg:SetPoint("TOPLEFT", panel, "TOPLEFT", BORDER_W, -(tabZoneTotal + 1))
        panel._bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_W, GetInfoBarH() + BORDER_W)
        panel._bg:SetVertexColor(0, 0, 0, bgAlpha)
    end

    Skin.RefreshInfoBarStyle(panel._infoBar, db.panelWidth or 440)

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
    -- SEGMENT DROPDOWN MENU (right-click header / bouton segments)
    -- ======================================================================
    local segmentMenu = nil
    local segmentBackdrop = nil
    local segmentMenuRows = {}
    local SEGMENU_W = 240
    local SEGMENU_ROW_H = 18
    local SEGMENU_PAD = 4

    local function HideSegmentMenu()
        if segmentMenu then segmentMenu:Hide() end
        if segmentBackdrop then segmentBackdrop:Hide() end
    end

    local function FormatDuration(sec)
        if not sec or sec <= 0 then return "" end
        local m = math.floor(sec / 60)
        local s = math.floor(sec % 60)
        return string.format("%d:%02d", m, s)
    end

    local function ShowSegmentMenu()
        if segmentMenu and segmentMenu:IsShown() then HideSegmentMenu(); return end
        if not container then return end

        local font = GetFont()
        local fontSize = (GetDB().fontSize or 9)

        local items = {}

        local segs = DM:GetSegments()
        local BD_ref = BravUI.Meter
        if segs and #segs > 0 then
            for i = 1, #segs do
                local seg = segs[i]
                local name = seg.name and tostring(seg.name) or ("Segment #" .. i)
                local dur = seg.durationSeconds and FormatDuration(seg.durationSeconds) or ""

                -- Ignorer les segments Overall/En cours de l'API (on les ajoute manuellement)
                local nameLower = name:lower()
                if nameLower == "overall" or nameLower == "en cours" or nameLower == "current" then
                    -- skip
                else

                local isBoss = name:match("^%(!%)")
                local isDungeon = name:match("%+%d+")

                -- Métadonnées sauvegardées (instance tracking)
                local meta = BD_ref and BD_ref.GetSegmentMeta and BD_ref:GetSegmentMeta(name)
                local isInstance = meta and meta.isInstance

                local label, color
                if isDungeon then
                    -- M+ ou donjon avec niveau de clé
                    label = name
                    color = {1, 0.82, 0}
                elseif isBoss then
                    -- Boss (encounter)
                    label = name:gsub("^%(!%) ?", "")
                    color = {0.9, 0.3, 0.3}
                elseif isInstance then
                    -- Trash en instance (meta confirme)
                    label = "Trash"
                    color = {0.5, 0.5, 0.5}
                elseif meta and not meta.isInstance then
                    -- Monde ouvert (meta confirme) → nom original
                    label = name
                    color = {0.7, 0.7, 0.7}
                else
                    -- Pas de meta (ancien segment) → fallback sur le nom
                    label = name
                    color = {0.6, 0.6, 0.6}
                end

                items[#items + 1] = { id = i, label = label, duration = dur, color = color }

                end -- fin du filtre Overall/En cours
            end

            items[#items + 1] = { separator = true }
        end

        -- Overall et En cours en bas
        items[#items + 1] = { id = -1, label = "Overall", color = {0.6, 0.6, 0.6} }
        items[#items + 1] = { id = 0,  label = "En cours", color = {0.6, 0.6, 0.6} }

        if not segmentBackdrop then
            segmentBackdrop = CreateFrame("Button", nil, UIParent)
            segmentBackdrop:SetAllPoints(UIParent)
            segmentBackdrop:SetFrameStrata("DIALOG")
            segmentBackdrop:SetFrameLevel(100)
            segmentBackdrop:RegisterForClicks("AnyUp")
            segmentBackdrop:SetScript("OnClick", function() HideSegmentMenu() end)
        end
        segmentBackdrop:Show()

        if not segmentMenu then
            segmentMenu = CreateFrame("Frame", nil, UIParent)
            segmentMenu:SetFrameStrata("DIALOG")
            segmentMenu:SetFrameLevel(110)
            segmentMenu:SetClampedToScreen(true)

            local bg = segmentMenu:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(TEX)
            bg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
            bg:SetAllPoints(segmentMenu)

            local function Border(point1, point2, horiz)
                local b = segmentMenu:CreateTexture(nil, "BORDER")
                b:SetTexture(TEX)
                b:SetVertexColor(0.25, 0.25, 0.25, 1)
                if horiz then
                    b:SetHeight(1)
                    b:SetPoint("LEFT", segmentMenu, "LEFT", 0, 0)
                    b:SetPoint("RIGHT", segmentMenu, "RIGHT", 0, 0)
                    b:SetPoint(point1, segmentMenu, point2, 0, 0)
                else
                    b:SetWidth(1)
                    b:SetPoint("TOP", segmentMenu, "TOP", 0, 0)
                    b:SetPoint("BOTTOM", segmentMenu, "BOTTOM", 0, 0)
                    b:SetPoint(point1, segmentMenu, point2, 0, 0)
                end
            end
            Border("TOPLEFT", "TOPLEFT", true)
            Border("BOTTOMLEFT", "BOTTOMLEFT", true)
            Border("TOPLEFT", "TOPLEFT", false)
            Border("TOPRIGHT", "TOPRIGHT", false)
        end

        segmentMenu:ClearAllPoints()
        local panelFrame = BravUI.Meter.Panel and BravUI.Meter.Panel._frame
        segmentMenu:SetPoint("BOTTOMLEFT", panelFrame or container, "TOPLEFT", 0, 2)
        segmentMenu:SetWidth(SEGMENU_W)

        for _, row in ipairs(segmentMenuRows) do row:Hide() end

        local yOff = -SEGMENU_PAD
        local rowIdx = 0
        for _, item in ipairs(items) do
            if item.separator then
                rowIdx = rowIdx + 1
                local sep = segmentMenuRows[rowIdx]
                if not sep then
                    sep = CreateFrame("Frame", nil, segmentMenu)
                    segmentMenuRows[rowIdx] = sep
                end
                sep:SetHeight(7)
                sep:SetPoint("TOPLEFT", segmentMenu, "TOPLEFT", SEGMENU_PAD, yOff)
                sep:SetPoint("TOPRIGHT", segmentMenu, "TOPRIGHT", -SEGMENU_PAD, yOff)
                if not sep._line then
                    local line = sep:CreateTexture(nil, "ARTWORK")
                    line:SetTexture(TEX)
                    line:SetVertexColor(0.25, 0.25, 0.25, 1)
                    line:SetHeight(1)
                    line:SetPoint("LEFT", sep, "LEFT", 0, 0)
                    line:SetPoint("RIGHT", sep, "RIGHT", 0, 0)
                    line:SetPoint("CENTER", sep, "CENTER", 0, 0)
                    sep._line = line
                end
                sep._line:Show()
                sep:Show()
                yOff = yOff - 7
            else
                rowIdx = rowIdx + 1
                local row = segmentMenuRows[rowIdx]
                if not row then
                    row = CreateFrame("Button", nil, segmentMenu)
                    row:SetHeight(SEGMENU_ROW_H)
                    row:EnableMouse(true)
                    row:RegisterForClicks("LeftButtonUp")

                    local rowBg = row:CreateTexture(nil, "BACKGROUND")
                    rowBg:SetTexture(TEX)
                    rowBg:SetAllPoints(row)
                    rowBg:SetVertexColor(1, 1, 1, 0)
                    row._bg = rowBg

                    local label = row:CreateFontString(nil, "OVERLAY")
                    label:SetFont(font, fontSize, "OUTLINE")
                    label:SetPoint("LEFT", row, "LEFT", SEGMENU_PAD + 14, 0)
                    label:SetPoint("RIGHT", row, "RIGHT", -(SEGMENU_PAD + 40), 0)
                    label:SetJustifyH("LEFT")
                    label:SetWordWrap(false)
                    row._label = label

                    local dur = row:CreateFontString(nil, "OVERLAY")
                    dur:SetFont(font, fontSize - 1, "OUTLINE")
                    dur:SetPoint("RIGHT", row, "RIGHT", -SEGMENU_PAD, 0)
                    dur:SetJustifyH("RIGHT")
                    dur:SetTextColor(0.5, 0.5, 0.5)
                    row._dur = dur

                    -- Marqueur actif (Font_Icons "N")
                    local marker = row:CreateFontString(nil, "OVERLAY")
                    local iconFont = "Interface\\AddOns\\BravUI_Lib\\BravLib_Media\\Fonts\\Font_Icons.ttf"
                    marker:SetFont(iconFont, fontSize, "OUTLINE")
                    marker:SetPoint("LEFT", row, "LEFT", SEGMENU_PAD, 0)
                    marker:SetJustifyH("RIGHT")
                    row._marker = marker

                    row:SetScript("OnEnter", function(self)
                        self._bg:SetVertexColor(0.2, 0.6, 0.2, 0.3)
                    end)
                    row:SetScript("OnLeave", function(self)
                        self._bg:SetVertexColor(1, 1, 1, 0)
                    end)

                    segmentMenuRows[rowIdx] = row
                end

                local isActive = (item.id == selectedSegmentId)

                -- Texte
                row._label:SetText(item.label)
                row._dur:SetText(item.duration or "")

                -- Couleurs par type
                local cr, cg, cb = 0.9, 0.9, 0.9
                if item.color then
                    cr, cg, cb = item.color[1], item.color[2], item.color[3]
                end
                if isActive then
                    row._label:SetTextColor(0.33, 1, 0.33)
                    row._marker:SetText("N")
                    row._marker:SetTextColor(0.33, 1, 0.33)
                else
                    row._label:SetTextColor(cr, cg, cb)
                    row._marker:SetText("")
                end
                row._dur:SetTextColor(0.5, 0.5, 0.5)
                row:SetPoint("TOPLEFT", segmentMenu, "TOPLEFT", 0, yOff)
                row:SetPoint("TOPRIGHT", segmentMenu, "TOPRIGHT", 0, yOff)

                local segId = item.id
                row:SetScript("OnClick", function()
                    HideSegmentMenu()
                    inst:SetSegment(segId)
                end)
                row:Show()
                yOff = yOff - SEGMENU_ROW_H
            end
        end

        segmentMenu:SetHeight(-yOff + SEGMENU_PAD)
        segmentMenu:Show()
    end

    inst.ShowSegmentMenu = ShowSegmentMenu

    -- ======================================================================
    -- CUSTOM TOOLTIP (breakdown au survol)
    -- ======================================================================
    local tooltipFrame = nil
    local TOOLTIP_MAX_SPELLS = 7
    local TOOLTIP_W = 270

    local function ShowBarTooltip(bar)
        if not bar._guid then return end
        if not DM or not DM:IsAvailable() then return end

        local spells = DM:GetSpellBreakdown(bar._guid, fixedMode, selectedSegmentId)
        if not spells or #spells == 0 then return end

        local font = GetFont()
        local cr, cg, cb = ClassColor(bar._class)
        local maxSpells = math.min(#spells, TOOLTIP_MAX_SPELLS)

        local totalVal = 0
        for _, s in ipairs(spells) do
            local ok, v = pcall(function() return s.value end)
            if ok and type(v) == "number" then totalVal = totalVal + v end
        end

        if not tooltipFrame then
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetFrameStrata("TOOLTIP")
            f:SetClampedToScreen(true)

            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(TEX)
            bg:SetVertexColor(0.05, 0.05, 0.05, 0.95)
            bg:SetAllPoints(f)

            local PU = PixelUtil
            f._borders = {}
            for _, args in ipairs({
                {"TOPLEFT", "TOPRIGHT", true},
                {"BOTTOMLEFT", "BOTTOMRIGHT", true},
                {"TOPLEFT", "BOTTOMLEFT", false},
                {"TOPRIGHT", "BOTTOMRIGHT", false},
            }) do
                local b = f:CreateTexture(nil, "OVERLAY", nil, 7)
                b:SetTexture(TEX)
                PU.SetPoint(b, args[1], f, args[1], 0, 0)
                PU.SetPoint(b, args[2], f, args[2], 0, 0)
                if args[3] then PU.SetHeight(b, 1) else PU.SetWidth(b, 1) end
                f._borders[#f._borders + 1] = b
            end

            f._title = f:CreateFontString(nil, "OVERLAY")
            f._sep = f:CreateTexture(nil, "ARTWORK")
            f._sep:SetTexture(TEX)
            f._sep:SetHeight(1)

            f._hdrName  = f:CreateFontString(nil, "OVERLAY")
            f._hdrTotal = f:CreateFontString(nil, "OVERLAY")
            f._hdrPS    = f:CreateFontString(nil, "OVERLAY")
            f._hdrPct   = f:CreateFontString(nil, "OVERLAY")

            f._rows = {}
            for i = 1, TOOLTIP_MAX_SPELLS do
                f._rows[i] = {
                    icon  = f:CreateTexture(nil, "OVERLAY"),
                    name  = f:CreateFontString(nil, "OVERLAY"),
                    total = f:CreateFontString(nil, "OVERLAY"),
                    ps    = f:CreateFontString(nil, "OVERLAY"),
                    pct   = f:CreateFontString(nil, "OVERLAY"),
                }
                f._rows[i].icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            f._hint = f:CreateFontString(nil, "OVERLAY")
            tooltipFrame = f
        end

        local tt = tooltipFrame
        local pad = 8
        local rowH = 14
        local iconSz = 12

        for _, b in ipairs(tt._borders) do b:SetVertexColor(cr, cg, cb, 1) end

        tt._title:SetFont(font, 10, "OUTLINE")
        local nameOk, nameStr = pcall(tostring, bar._name)
        tt._title:SetText(nameOk and nameStr or "Joueur")
        tt._title:SetTextColor(cr, cg, cb, 1)
        tt._title:ClearAllPoints()
        tt._title:SetPoint("TOPLEFT", tt, "TOPLEFT", pad, -pad)

        tt._sep:ClearAllPoints()
        tt._sep:SetPoint("TOPLEFT", tt._title, "BOTTOMLEFT", -2, -4)
        tt._sep:SetPoint("RIGHT", tt, "RIGHT", -pad, 0)
        tt._sep:SetVertexColor(cr, cg, cb, 0.4)
        tt._sep:Show()

        local yOff = pad + 14 + 8
        local psSuffix = (MODE_INFO[fixedMode] or MODE_INFO.damage).suffix

        for _, hdr in ipairs({
            { fs = tt._hdrPct,   text = "%",       anchor = "TOPRIGHT",  xOff = -pad },
            { fs = tt._hdrPS,    text = psSuffix,   anchor = "TOPRIGHT",  xOff = -pad - 42 },
            { fs = tt._hdrTotal, text = "Total",    anchor = "TOPRIGHT",  xOff = -pad - 80 },
            { fs = tt._hdrName,  text = "Sort",     anchor = "TOPLEFT",   xOff = pad + iconSz + 4 },
        }) do
            hdr.fs:SetFont(font, 8, "OUTLINE")
            hdr.fs:SetText(hdr.text)
            hdr.fs:SetTextColor(0.5, 0.5, 0.5)
            hdr.fs:ClearAllPoints()
            hdr.fs:SetPoint(hdr.anchor, tt, hdr.anchor, hdr.xOff, -yOff)
            hdr.fs:SetJustifyH(hdr.anchor == "TOPLEFT" and "LEFT" or "RIGHT")
            hdr.fs:Show()
        end

        yOff = yOff + 14

        for i = 1, TOOLTIP_MAX_SPELLS do
            local row = tt._rows[i]
            if i <= maxSpells then
                local s = spells[i]
                local spellIcon = s.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s.spellID)

                row.icon:ClearAllPoints()
                row.icon:SetSize(iconSz, iconSz)
                row.icon:SetPoint("TOPLEFT", tt, "TOPLEFT", pad, -yOff)
                if spellIcon then row.icon:SetTexture(spellIcon); row.icon:Show()
                else row.icon:Hide() end

                row.name:SetFont(font, 9, "OUTLINE")
                row.name:SetText(s.name or "?")
                row.name:SetTextColor(1, 1, 1)
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", tt, "TOPLEFT", pad + iconSz + 4, -yOff)
                row.name:SetWidth(TOOLTIP_W - pad * 2 - iconSz - 4 - 130)
                row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false); row.name:Show()

                row.total:SetFont(font, 9, "OUTLINE")
                row.total:SetText(F.SafeFormat(s.value, true) or "?")
                row.total:SetTextColor(0.9, 0.9, 0.9)
                row.total:ClearAllPoints()
                row.total:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -pad - 80, -yOff)
                row.total:SetJustifyH("RIGHT"); row.total:Show()

                row.ps:SetFont(font, 9, "OUTLINE")
                row.ps:SetText(F.SafeFormat(s.perSecond) or "?")
                row.ps:SetTextColor(0.9, 0.9, 0.9)
                row.ps:ClearAllPoints()
                row.ps:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -pad - 42, -yOff)
                row.ps:SetJustifyH("RIGHT"); row.ps:Show()

                local pctText = ""
                if totalVal > 0 then
                    local pctVal = F.SafeDiv(s.value, totalVal)
                    if pctVal then pctText = string.format("%.1f%%", pctVal * 100) end
                end
                row.pct:SetFont(font, 9, "OUTLINE")
                row.pct:SetText(pctText)
                row.pct:SetTextColor(cr, cg, cb, 1)
                row.pct:ClearAllPoints()
                row.pct:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -pad, -yOff)
                row.pct:SetJustifyH("RIGHT"); row.pct:Show()

                yOff = yOff + rowH
            else
                row.icon:Hide(); row.name:Hide(); row.total:Hide(); row.ps:Hide(); row.pct:Hide()
            end
        end

        yOff = yOff + 4
        tt._hint:SetFont(font, 8, "OUTLINE")
        tt._hint:SetText("Clic: d\195\169tail des sorts")
        tt._hint:SetTextColor(0.4, 0.4, 0.4)
        tt._hint:ClearAllPoints()
        tt._hint:SetPoint("TOPLEFT", tt, "TOPLEFT", pad, -yOff)
        tt._hint:Show()
        yOff = yOff + 10 + pad

        tt:SetSize(TOOLTIP_W, yOff)
        tt:ClearAllPoints()
        if container then
            tt:SetPoint("BOTTOM", container, "TOP", 0, 4)
        else
            tt:SetPoint("BOTTOM", bar, "TOP", 0, 4)
        end
        tt:Show()
    end

    local function HideBarTooltip()
        if tooltipFrame then tooltipFrame:Hide() end
    end

    -- ======================================================================
    -- DETAIL WINDOW (popup spell breakdown au clic)
    -- ======================================================================
    local detailFrame = nil
    local detailBarPool = {}
    local detailGUID = nil
    local detailName = nil
    local detailClass = nil
    local detailSpecIcon = nil
    local detailScrollOffset = 0
    local detailSelectedSpell = nil

    local DW_WIDTH   = 600
    local DW_HEIGHT  = 450
    local DW_HDR_H   = 36
    local DW_ROW_H   = 18
    local DW_ROW_SP  = 1
    local DW_PAD     = 6
    local DW_ICON    = 14
    local DW_SPLIT   = 0.55
    local DW_BORDER  = 2
    local DW_GAP     = 15
    local DW_COL_TOT = 60
    local DW_COL_PCT = 48

    local HideDetailWindow, RefreshDetailWindow

    HideDetailWindow = function()
        if detailFrame then detailFrame:Hide() end
        detailGUID = nil
        detailName = nil
        detailClass = nil
        detailSpecIcon = nil
        detailScrollOffset = 0
        detailSelectedSpell = nil
    end

    local function CreateSpellRow(parent)
        local font = GetFont()
        local fs = (GetDB().fontSize or 9)

        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(DW_ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(TEX)
        bg:SetVertexColor(0, 0, 0, BAR_BG_ALPHA)
        bg:SetAllPoints(row)
        row._bg = bg

        local sbar = row:CreateTexture(nil, "BORDER")
        sbar:SetTexture(TEX)
        sbar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        sbar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row._bar = sbar

        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(DW_ICON, DW_ICON)
        icon:SetPoint("LEFT", row, "LEFT", 3, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        row._icon = icon

        local rank = row:CreateFontString(nil, "OVERLAY")
        rank:SetFont(font, fs, "OUTLINE")
        rank:SetWidth(16)
        rank:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        rank:SetJustifyH("RIGHT")
        row._rank = rank

        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetFont(font, fs, "OUTLINE")
        name:SetPoint("LEFT", rank, "RIGHT", 3, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -(DW_COL_TOT + DW_COL_PCT + 6), 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row._name = name

        local total = row:CreateFontString(nil, "OVERLAY")
        total:SetFont(font, fs, "OUTLINE")
        total:SetWidth(DW_COL_TOT)
        total:SetPoint("RIGHT", row, "RIGHT", -(DW_COL_PCT + 3), 0)
        total:SetJustifyH("RIGHT")
        row._total = total

        local pctFS = row:CreateFontString(nil, "OVERLAY")
        pctFS:SetFont(font, fs, "OUTLINE")
        pctFS:SetWidth(DW_COL_PCT)
        pctFS:SetPoint("RIGHT", row, "RIGHT", -3, 0)
        pctFS:SetJustifyH("RIGHT")
        row._pct = pctFS

        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self._spellIdx then
                if detailSelectedSpell == self._spellIdx then
                    detailSelectedSpell = nil
                else
                    detailSelectedSpell = self._spellIdx
                end
                RefreshDetailWindow()
            end
        end)

        local iconOvr = CreateFrame("Frame", nil, row)
        iconOvr:SetAllPoints(icon)
        iconOvr:EnableMouse(true)
        iconOvr:SetScript("OnEnter", function(self)
            local p = self:GetParent()
            if p._spellID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(p._spellID)
                GameTooltip:Show()
            end
        end)
        iconOvr:SetScript("OnLeave", function() GameTooltip:Hide() end)

        return row
    end

    local function AcquireDetailRow(parent, index)
        local row = detailBarPool[index]
        if not row then
            row = CreateSpellRow(parent)
            detailBarPool[index] = row
        end
        row:SetParent(parent)
        row:Show()
        return row
    end

    local function HideAllDetailRows()
        for _, row in ipairs(detailBarPool) do row:Hide() end
    end

    local function MakePanelBorder(parent, cr, cg, cb)
        local PU = PixelUtil
        local borders = {}
        for _, args in ipairs({
            {"TOPLEFT", "TOPRIGHT", true},
            {"BOTTOMLEFT", "BOTTOMRIGHT", true},
            {"TOPLEFT", "BOTTOMLEFT", false},
            {"TOPRIGHT", "BOTTOMRIGHT", false},
        }) do
            local b = parent:CreateTexture(nil, "OVERLAY", nil, 5)
            b:SetTexture(TEX)
            b:SetVertexColor(cr, cg, cb, 0.4)
            PU.SetPoint(b, args[1], parent, args[1], 0, 0)
            PU.SetPoint(b, args[2], parent, args[2], 0, 0)
            if args[3] then PU.SetHeight(b, 1) else PU.SetWidth(b, 1) end
            borders[#borders + 1] = b
        end
        return borders
    end

    RefreshDetailWindow = function()
        if not detailFrame or not detailGUID then return end
        if not DM or not DM:IsAvailable() then HideDetailWindow(); return end

        local spells = DM:GetSpellBreakdown(detailGUID, fixedMode, selectedSegmentId)
        if not spells or #spells == 0 then HideDetailWindow(); return end

        local db = GetDB()
        local font = GetFont()
        local fs = db.fontSize or 9
        local cr, cg, cb = ClassColor(detailClass)

        for _, b in ipairs(detailFrame._borders) do b:SetVertexColor(cr, cg, cb, 1) end
        for _, b in ipairs(detailFrame._p1borders) do b:SetVertexColor(cr, cg, cb, 0.4) end
        for _, b in ipairs(detailFrame._p2borders) do b:SetVertexColor(cr, cg, cb, 0.4) end

        local modeStr = (MODE_INFO[fixedMode] or MODE_INFO.damage).detailPrefix
        local nameOk, nameStr = pcall(tostring, detailName)
        local playerStr = (nameOk and nameStr) or "Joueur"
        detailFrame._title:SetFont(font, fs + 2, "OUTLINE")
        detailFrame._title:SetText(modeStr .. string.upper(playerStr))
        detailFrame._title:SetTextColor(cr, cg, cb, 1)
        detailFrame._hdrSep:SetVertexColor(cr, cg, cb, 0.6)

        if detailSpecIcon and detailSpecIcon > 0 then
            detailFrame._specIcon:SetTexture(detailSpecIcon)
            detailFrame._specIcon:Show()
        else
            detailFrame._specIcon:Hide()
        end
        detailFrame._title:ClearAllPoints()
        if detailFrame._specIcon:IsShown() then
            detailFrame._title:SetPoint("LEFT", detailFrame._specIcon, "RIGHT", 6, 0)
        else
            detailFrame._title:SetPoint("LEFT", detailFrame, "TOPLEFT", DW_PAD + 4, -(DW_HDR_H / 2))
        end

        -- Panel 2: détail du sort sélectionné
        local selSpell = nil
        if detailSelectedSpell and detailSelectedSpell <= #spells then
            selSpell = spells[detailSelectedSpell]
        end

        if selSpell then
            detailFrame._p2label:Hide()
            local selIcon = selSpell.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(selSpell.spellID)
            if selIcon then
                detailFrame._p2icon:SetTexture(selIcon); detailFrame._p2icon:Show()
            else
                detailFrame._p2icon:Hide()
            end
            detailFrame._p2name:SetFont(font, fs + 1, "OUTLINE")
            detailFrame._p2name:SetText(selSpell.name or "?")
            detailFrame._p2name:SetTextColor(cr, cg, cb, 1)
            detailFrame._p2name:Show()
            detailFrame._p2sep:SetVertexColor(cr, cg, cb, 0.3)
            detailFrame._p2sep:Show()

            local modeInfo = MODE_INFO[fixedMode] or MODE_INFO.damage
            local statLabels = {modeInfo.statLabel, "Moyenne", modeInfo.suffix}
            local statValues = {
                F.SafeFormat(selSpell.value, true) or "\226\128\148",
                F.SafeFormat(selSpell.value, true) or "\226\128\148",
                F.SafeFormat(selSpell.perSecond) or "\226\128\148",
            }
            for si = 1, 3 do
                local st = detailFrame._p2stats[si]
                st.label:SetFont(font, fs, "OUTLINE"); st.label:SetText(statLabels[si]); st.label:SetTextColor(0.6, 0.6, 0.6); st.label:Show()
                st.value:SetFont(font, fs, "OUTLINE"); st.value:SetText(statValues[si]); st.value:SetTextColor(1, 1, 1); st.value:Show()
            end
        else
            detailFrame._p2label:SetFont(font, fs, "OUTLINE")
            detailFrame._p2label:SetText("Cliquer sur un sort")
            detailFrame._p2label:SetTextColor(0.3, 0.3, 0.3); detailFrame._p2label:Show()
            detailFrame._p2icon:Hide(); detailFrame._p2name:Hide(); detailFrame._p2sep:Hide()
            for si = 1, 3 do
                detailFrame._p2stats[si].label:Hide(); detailFrame._p2stats[si].value:Hide()
            end
        end

        -- Panel 1: remplir les sorts
        HideAllDetailRows()

        local totalVal = nil
        local ok, sum = pcall(function()
            local s = 0; for _, e in ipairs(spells) do s = s + e.value end; return s
        end)
        if ok and sum and sum > 0 then totalVal = sum end

        local maxVal = nil
        if #spells > 0 then
            local ok2, v = pcall(function()
                if type(spells[1].value) == "number" and spells[1].value > 0 then return spells[1].value end
            end)
            if ok2 and v then maxVal = v end
        end

        local p1 = detailFrame._panel1
        local p1Top = 4 + DW_ROW_H + 4
        local totalSpells = math.min(#spells, 50)
        local availH = p1:GetHeight() - p1Top - 2
        local visibleRows = math.floor(availH / (DW_ROW_H + DW_ROW_SP))
        visibleRows = math.max(1, math.min(visibleRows, totalSpells))
        local maxScroll = math.max(0, totalSpells - visibleRows)
        if detailScrollOffset > maxScroll then detailScrollOffset = maxScroll end
        if detailScrollOffset < 0 then detailScrollOffset = 0 end

        local rowW = p1:GetWidth() - 4

        for i = 1, visibleRows do
            local idx = i + detailScrollOffset
            if idx > totalSpells then break end

            local spell = spells[idx]
            local row = AcquireDetailRow(p1, i)
            row:SetHeight(DW_ROW_H)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", p1, "TOPLEFT", 2, -(p1Top + (i - 1) * (DW_ROW_H + DW_ROW_SP)))
            row:SetPoint("RIGHT", p1, "RIGHT", -2, 0)

            row._spellIdx = idx
            row._spellID = spell.spellID

            local pctBar = maxVal and F.SafeDiv(spell.value, maxVal) or (1 - (idx - 1) * 0.04)
            if not pctBar then pctBar = 0.05 end
            row._bar:SetWidth(math.max(1, rowW * pctBar))
            row._bar:SetVertexColor(cr, cg, cb, 0.45)

            if detailSelectedSpell == idx then
                row._bg:SetVertexColor(cr, cg, cb, 0.15)
            else
                row._bg:SetVertexColor(0, 0, 0, BAR_BG_ALPHA)
            end

            row._rank:SetText(idx); row._rank:SetTextColor(0.5, 0.5, 0.5)

            local spellIcon = spell.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell.spellID)
            if spellIcon then row._icon:SetTexture(spellIcon); row._icon:Show() else row._icon:Hide() end

            row._name:SetText(spell.name or "?"); row._name:SetTextColor(1, 1, 1)
            row._total:SetText(F.SafeFormat(spell.value, true) or "?"); row._total:SetTextColor(0.9, 0.9, 0.9)

            local pctText = ""
            if totalVal then
                local p = F.SafeDiv(spell.value, totalVal)
                if p then pctText = string.format("%.1f%%", p * 100) end
            end
            row._pct:SetText(pctText); row._pct:SetTextColor(cr, cg, cb, 1)
        end
    end

    local function ShowDetailWindow(bar)
        if not bar._guid then return end
        if detailGUID == bar._guid then HideDetailWindow(); return end

        detailGUID = bar._guid
        detailName = bar._name
        detailClass = bar._class
        detailSpecIcon = bar._specIcon
        detailScrollOffset = 0
        detailSelectedSpell = nil
        HideBarTooltip()

        local cr, cg, cb = ClassColor(detailClass)
        local font = GetFont()
        local fs = (GetDB().fontSize or 9)

        if not detailFrame then
            local PU = PixelUtil
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetFrameStrata("HIGH"); f:SetFrameLevel(100)
            f:SetSize(DW_WIDTH, DW_HEIGHT)
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
            f:SetClampedToScreen(true); f:EnableMouse(true)

            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(TEX); bg:SetVertexColor(0.04, 0.04, 0.04, 0.97); bg:SetAllPoints(f)

            f._borders = {}
            for _, args in ipairs({
                {"TOPLEFT", "TOPRIGHT", true}, {"BOTTOMLEFT", "BOTTOMRIGHT", true},
                {"TOPLEFT", "BOTTOMLEFT", false}, {"TOPRIGHT", "BOTTOMRIGHT", false},
            }) do
                local b = f:CreateTexture(nil, "OVERLAY", nil, 7)
                b:SetTexture(TEX)
                PU.SetPoint(b, args[1], f, args[1], 0, 0)
                PU.SetPoint(b, args[2], f, args[2], 0, 0)
                if args[3] then PU.SetHeight(b, DW_BORDER) else PU.SetWidth(b, DW_BORDER) end
                f._borders[#f._borders + 1] = b
            end

            local hdrBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
            hdrBg:SetTexture(TEX); hdrBg:SetVertexColor(0.07, 0.07, 0.07, 1)
            hdrBg:SetPoint("TOPLEFT", f, "TOPLEFT", DW_BORDER, -DW_BORDER)
            hdrBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -DW_BORDER, -DW_BORDER)
            hdrBg:SetHeight(DW_HDR_H - DW_BORDER)

            f._specIcon = f:CreateTexture(nil, "OVERLAY")
            f._specIcon:SetSize(24, 24)
            f._specIcon:SetPoint("LEFT", f, "TOPLEFT", DW_PAD + 4, -(DW_HDR_H / 2))
            f._specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f._specIcon:Hide()

            f._title = f:CreateFontString(nil, "OVERLAY")
            f._title:SetPoint("LEFT", f._specIcon, "RIGHT", 6, 0)
            f._title:SetJustifyH("LEFT")

            local closeBtn = CreateFrame("Button", nil, f)
            closeBtn:SetSize(18, 18); closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
            local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
            closeTxt:SetFont(font, 13, "OUTLINE"); closeTxt:SetText("X"); closeTxt:SetTextColor(0.5, 0.5, 0.5); closeTxt:SetAllPoints(closeBtn)
            closeBtn:SetScript("OnClick", function() HideDetailWindow() end)
            closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.3, 0.3) end)
            closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.5, 0.5, 0.5) end)

            f._hdrSep = f:CreateTexture(nil, "ARTWORK")
            f._hdrSep:SetTexture(TEX); f._hdrSep:SetHeight(DW_BORDER)
            f._hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -DW_HDR_H)
            f._hdrSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -DW_HDR_H)

            local contentTop = DW_HDR_H + DW_BORDER + DW_GAP
            local contentH = DW_HEIGHT - contentTop - DW_BORDER - DW_GAP
            local contentW = DW_WIDTH - (DW_BORDER + DW_GAP) * 2
            local leftW = math.floor((contentW - DW_GAP) * DW_SPLIT)
            local rightW = contentW - leftW - DW_GAP

            -- Panel 1: sorts
            local p1 = CreateFrame("Frame", nil, f)
            p1:SetPoint("TOPLEFT", f, "TOPLEFT", DW_BORDER + DW_GAP, -contentTop)
            p1:SetSize(leftW, contentH); p1:SetClipsChildren(true)
            local p1bg = p1:CreateTexture(nil, "BACKGROUND", nil, 1)
            p1bg:SetTexture(TEX); p1bg:SetVertexColor(0.05, 0.05, 0.05, 1); p1bg:SetAllPoints(p1)
            f._panel1 = p1

            local p1hdr = CreateFrame("Frame", nil, p1)
            p1hdr:SetHeight(DW_ROW_H)
            p1hdr:SetPoint("TOPLEFT", p1, "TOPLEFT", 2, -4)
            p1hdr:SetPoint("RIGHT", p1, "RIGHT", -2, 0)

            local p1hdrBg = p1hdr:CreateTexture(nil, "BACKGROUND")
            p1hdrBg:SetTexture(TEX); p1hdrBg:SetVertexColor(1, 1, 1, 0.06); p1hdrBg:SetAllPoints(p1hdr)

            f._p1hdrRank = p1hdr:CreateFontString(nil, "OVERLAY")
            f._p1hdrRank:SetWidth(16); f._p1hdrRank:SetPoint("LEFT", p1hdr, "LEFT", 20, 0); f._p1hdrRank:SetJustifyH("CENTER")
            f._p1hdrName = p1hdr:CreateFontString(nil, "OVERLAY")
            f._p1hdrName:SetPoint("LEFT", p1hdr, "LEFT", 39, 0)
            f._p1hdrName:SetPoint("RIGHT", p1hdr, "RIGHT", -(DW_COL_TOT + DW_COL_PCT + 6), 0); f._p1hdrName:SetJustifyH("LEFT")
            f._p1hdrTot = p1hdr:CreateFontString(nil, "OVERLAY")
            f._p1hdrTot:SetWidth(DW_COL_TOT); f._p1hdrTot:SetPoint("RIGHT", p1hdr, "RIGHT", -(DW_COL_PCT + 3), 0); f._p1hdrTot:SetJustifyH("CENTER")
            f._p1hdrPct = p1hdr:CreateFontString(nil, "OVERLAY")
            f._p1hdrPct:SetWidth(DW_COL_PCT); f._p1hdrPct:SetPoint("RIGHT", p1hdr, "RIGHT", -3, 0); f._p1hdrPct:SetJustifyH("CENTER")

            local p1hdrSep = p1hdr:CreateTexture(nil, "OVERLAY", nil, 3)
            p1hdrSep:SetTexture(TEX); p1hdrSep:SetHeight(1)
            p1hdrSep:SetPoint("BOTTOMLEFT", p1hdr, "BOTTOMLEFT", 0, 0)
            p1hdrSep:SetPoint("BOTTOMRIGHT", p1hdr, "BOTTOMRIGHT", 0, 0)

            p1:EnableMouseWheel(true)
            p1:SetScript("OnMouseWheel", function(_, delta)
                detailScrollOffset = detailScrollOffset + (delta > 0 and -3 or 3)
                RefreshDetailWindow()
            end)

            -- Panel 2: détail sort
            local p2 = CreateFrame("Frame", nil, f)
            p2:SetPoint("TOPLEFT", p1, "TOPRIGHT", DW_GAP, 0)
            p2:SetSize(rightW, contentH); p2:SetClipsChildren(true)
            local p2bg = p2:CreateTexture(nil, "BACKGROUND", nil, 1)
            p2bg:SetTexture(TEX); p2bg:SetVertexColor(0.05, 0.05, 0.05, 1); p2bg:SetAllPoints(p2)
            f._panel2 = p2

            f._p2label = p2:CreateFontString(nil, "OVERLAY")
            f._p2label:SetPoint("CENTER", p2, "CENTER", 0, 0)

            local P2_PAD = 8
            local P2_ICON = 20
            local P2_STAT_H = 20

            f._p2icon = p2:CreateTexture(nil, "OVERLAY")
            f._p2icon:SetSize(P2_ICON, P2_ICON)
            f._p2icon:SetPoint("TOPLEFT", p2, "TOPLEFT", P2_PAD, -P2_PAD)
            f._p2icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); f._p2icon:Hide()

            f._p2name = p2:CreateFontString(nil, "OVERLAY")
            f._p2name:SetPoint("LEFT", f._p2icon, "RIGHT", 6, 0)
            f._p2name:SetPoint("RIGHT", p2, "RIGHT", -P2_PAD, 0)
            f._p2name:SetJustifyH("LEFT"); f._p2name:SetWordWrap(false)

            f._p2sep = p2:CreateTexture(nil, "OVERLAY", nil, 3)
            f._p2sep:SetTexture(TEX); f._p2sep:SetHeight(1)
            f._p2sep:SetPoint("TOPLEFT", p2, "TOPLEFT", 4, -(P2_PAD + P2_ICON + 6))
            f._p2sep:SetPoint("RIGHT", p2, "RIGHT", -4, 0); f._p2sep:Hide()

            f._p2stats = {}
            local statTop = P2_PAD + P2_ICON + 6 + 1 + 8
            for si = 1, 3 do
                local lbl = p2:CreateFontString(nil, "OVERLAY")
                lbl:SetPoint("TOPLEFT", p2, "TOPLEFT", P2_PAD, -(statTop + (si - 1) * P2_STAT_H))
                lbl:SetJustifyH("LEFT"); lbl:Hide()
                local val = p2:CreateFontString(nil, "OVERLAY")
                val:SetPoint("TOPRIGHT", p2, "TOPRIGHT", -P2_PAD, -(statTop + (si - 1) * P2_STAT_H))
                val:SetJustifyH("RIGHT"); val:Hide()
                f._p2stats[si] = { label = lbl, value = val }
            end

            f._p1borders = MakePanelBorder(p1, cr, cg, cb)
            f._p2borders = MakePanelBorder(p2, cr, cg, cb)

            f:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" then HideDetailWindow() end
            end)

            detailFrame = f
        end

        detailFrame:Show()
        RefreshDetailWindow()
    end

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

        bar:SetScript("OnClick", function(self)
            if self._guid then ShowDetailWindow(self) end
        end)
        bar:SetScript("OnEnter", function(self)
            if self._bg then self._bg:SetVertexColor(0.15, 0.15, 0.15, 0.5) end
            ShowBarTooltip(self)
        end)
        bar:SetScript("OnLeave", function(self)
            if self._bg then self._bg:SetVertexColor(0, 0, 0, BAR_BG_ALPHA) end
            HideBarTooltip()
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
        bg:SetVertexColor(0, 0, 0, GetHeaderOpacity())
        bg:SetAllPoints(frame)
        frame._bg = bg

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
        -- Refresh header opacity from DB
        if headerFrame and headerFrame._bg then
            local bgOff = db and db.showBackground == false
            local hAlpha = bgOff and 0 or GetHeaderOpacity()
            headerFrame._bg:SetVertexColor(0, 0, 0, hAlpha)
        end

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
        local fontSizeValues = db.fontSizeValues or fontSize

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
            bar._rightText:SetFont(font, fontSizeValues, "OUTLINE")
            bar._rightText:ClearAllPoints()
            bar._rightText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

            local r, g, b
            local colorMode = db.barColorMode or "class"
            if colorMode == "custom" and db.barCustomColor then
                local cc = db.barCustomColor
                r, g, b = cc.r or 0.3, cc.g or 0.6, cc.b or 1.0
            elseif db.classColors == false then
                r, g, b = 0.6, 0.6, 0.6
            else
                r, g, b = ClassColor(entry.class)
            end

            local pct
            if maxVal then pct = F.SafeDiv(entry.value, maxVal) end
            if not pct then pct = math.max(0.05, 1 - (dataIdx - 1) * 0.04) end

            local iconSpace = (db.showSpecIcon == false) and 0 or barH
            local newWidth = math.max(1, (bar:GetWidth() - iconSpace) * pct)
            bar._targetWidth = newWidth
            if bar._currentWidth == 0 then
                bar._currentWidth = newWidth
                bar._bar:SetWidth(newWidth)
            end
            bar._bar:SetVertexColor(r, g, b, 0.7)

            -- Icône spec/class
            if db.showSpecIcon == false then
                bar._icon:SetSize(0.001, barH)
                bar._icon:Hide()
            else
                bar._icon:SetSize(barH, barH)
                -- TODO: réactiver quand des icônes de spé custom seront disponibles
                -- local iconStyle = db.classIconStyle or "blizzard"
                local iconStyle = "blizzard"
                if iconStyle == "blizzard" then
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
                else
                    if entry.class then
                        local key = iconStyle .. "_" .. string.lower(entry.class)
                        local tex = BravLib.Media.Get("classicon", key)
                        if tex then
                            bar._icon:SetAtlas(nil)
                            bar._icon:SetTexCoord(0, 1, 0, 1)
                            bar._icon:SetTexture(tex)
                            bar._icon:Show()
                        else
                            bar._icon:Hide()
                        end
                    else
                        bar._icon:Hide()
                    end
                end
            end

            -- Rank + Nom
            local iconVisible = bar._icon:IsShown()
            local textAnchor = iconVisible and bar._icon or bar
            local textAnchorPoint = iconVisible and "RIGHT" or "LEFT"
            local textPad = iconVisible and ICON_PADDING or 4

            bar._rankText:SetFont(font, fontSize, "OUTLINE")
            bar._rankText:ClearAllPoints()
            bar._rankText:SetPoint("LEFT", textAnchor, textAnchorPoint, textPad, 0)
            if db.showRank then
                bar._rankText:SetText(dataIdx .. (db.rankSeparator or "."))
                bar._rankText:SetTextColor(1, 1, 1)
                bar._rankText:Show()
                bar._leftText:ClearAllPoints()
                bar._leftText:SetPoint("LEFT", bar._rankText, "RIGHT", -2, 0)
                bar._leftText:SetPoint("RIGHT", bar._rightText, "LEFT", -4, 0)
            else
                bar._rankText:Hide()
                bar._leftText:ClearAllPoints()
                bar._leftText:SetPoint("LEFT", textAnchor, textAnchorPoint, textPad, 0)
                bar._leftText:SetPoint("RIGHT", bar._rightText, "LEFT", -4, 0)
            end
            local displayName = entry.name or ""
            local ok, stripped = pcall(function()
                local d = displayName:find("-")
                if d then return displayName:sub(1, d - 1) end
                return displayName
            end)
            bar._leftText:SetText(ok and stripped or displayName)
            bar._leftText:SetTextColor(1, 1, 1)

            -- Texte droit (format configurable)
            local fmtPS = F.SafeFormat(entry.perSecond)
            local fmtVal = F.SafeFormat(entry.value, true)
            local pctStr
            if totalAmount then
                local pctVal = F.SafeDiv(entry.value, totalAmount)
                if pctVal then pctStr = string.format("%.1f%%", pctVal * 100) end
            end

            local textMode = db.barTextMode or 1
            local rightStr
            local ok, built = pcall(function()
                if textMode == 1 then
                    local s = fmtPS or ""
                    local extra = ""
                    if fmtVal and pctStr then extra = " (" .. fmtVal .. " | " .. pctStr .. ")"
                    elseif fmtVal then extra = " (" .. fmtVal .. ")"
                    elseif pctStr then extra = " (" .. pctStr .. ")"
                    end
                    return s .. extra
                elseif textMode == 2 then
                    local s = fmtVal or ""
                    local extra = ""
                    if fmtPS and pctStr then extra = " (" .. fmtPS .. " | " .. pctStr .. ")"
                    elseif fmtPS then extra = " (" .. fmtPS .. ")"
                    elseif pctStr then extra = " (" .. pctStr .. ")"
                    end
                    return s .. extra
                else
                    local fmt = db.barTextCustom or "dps (total | %)"
                    local sDPS = fmtPS  or ""
                    local sTOT = fmtVal or ""
                    local sPCT = pctStr or ""
                    local r = fmt
                    r = r:gsub("[Tt][Oo][Tt][Aa][Ll]", function() return sTOT end)
                    r = r:gsub("[Dd][Pp][Ss]",         function() return sDPS end)
                    r = r:gsub("%%",                   function() return sPCT end)
                    return r
                end
            end)
            rightStr = ok and built or ""
            bar._rightText:SetText(rightStr)
            bar._rightText:SetTextColor(0.9, 0.9, 0.9)

            bar._guid = entry.guid
            bar._name = entry.name
            bar._class = entry.class
            bar._specIcon = entry.specIcon

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
    Skin.RefreshPanel(panel, db)
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
    resetBtn:SetScript("OnEnter", function(self)
        resetTex:SetVertexColor(1, 0.3, 0.3, 1)
        ShowBravTooltip(self, "Reset", "Remet les compteurs \195\160 z\195\169ro")
    end)
    resetBtn:SetScript("OnLeave", function()
        resetTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7)
        HideBravTooltip()
    end)

    -- Bouton partage + panel de partage
    local shareBtn = CreateFrame("Button", nil, half)
    shareBtn:SetSize(14, tabZone - 4)
    shareBtn:SetPoint("RIGHT", resetBtn, "LEFT", -3, 0)
    local shareTex = shareBtn:CreateTexture(nil, "OVERLAY")
    shareTex:SetTexture("Interface/GossipFrame/ChatBubbleGossipIcon")
    shareTex:SetSize(12, 12)
    shareTex:SetPoint("CENTER")
    shareTex:SetVertexColor(cr, cg, cb, 0.7)

    -- Panel de partage
    local sharePanel = nil
    local sharePanelBackdrop = nil

    local CHANNELS = {
        { id = "SAY",     label = "Dire" },
        { id = "PARTY",   label = "Groupe" },
        { id = "RAID",    label = "Raid" },
        { id = "GUILD",   label = "Guilde" },
        { id = "INSTANCE_CHAT", label = "Instance" },
    }
    local selectedChannel = 1
    local selectedCount = 5

    local function HideSharePanel()
        if sharePanel then sharePanel:Hide() end
        if sharePanelBackdrop then sharePanelBackdrop:Hide() end
    end

    local function DoShare()
        if not barsInst then return end
        local mode = barsInst:GetMode()
        local modeInfo = MODE_INFO[mode] or MODE_INFO.damage
        local segId = barsInst:GetSegmentId()
        local data = DM and DM:IsAvailable() and DM:GetSorted(mode, segId)
        if not data or #data == 0 then return end
        local channel = CHANNELS[selectedChannel].id
        local maxReport = math.min(selectedCount, #data)

        -- Total global pour calculer le %
        local totalAll = 0
        for _, e in ipairs(data) do
            local ok, v = pcall(function() return e.value end)
            if ok and type(v) == "number" then totalAll = totalAll + v end
        end

        -- Durée du combat
        local durStr = ""
        local ok, info = pcall(function() return DM:GetSessionInfo(segId, mode) end)
        if ok and info and info.duration then
            local d = info.duration
            local okD, ds = pcall(function()
                local m = math.floor(d / 60)
                local s = math.floor(d % 60)
                return string.format("%d:%02d", m, s)
            end)
            if okD and ds then durStr = " - " .. ds end
        end

        local function SafeChat(msg)
            -- Retirer les escape codes WoW puis les | restants
            msg = msg:gsub("|c%x%x%x%x%x%x%x%x", "")
            msg = msg:gsub("|r", "")
            msg = msg:gsub("|H.-|h", "")
            msg = msg:gsub("|h", "")
            msg = msg:gsub("|T.-|t", "")
            msg = msg:gsub("|", "")
            return msg
        end

        local header = "--- BravUI : " .. modeInfo.label .. " (top " .. maxReport .. durStr .. ") ---"
        SendChatMessage(SafeChat(header), channel)
        for i = 1, maxReport do
            local e = data[i]
            -- Construire chaque partie séparément, tout en string safe
            local nameStr = "?"
            pcall(function() nameStr = tostring(e.name) end)
            -- Retirer le suffixe serveur
            pcall(function()
                local d = nameStr:find("-")
                if d then nameStr = nameStr:sub(1, d - 1) end
            end)
            local psStr = F.SafeFormat(e.perSecond) or "?"
            local valStr = F.SafeFormat(e.value, true) or "?"
            local pctStr = ""
            if totalAll > 0 then
                local okP, pct = pcall(function() return e.value / totalAll * 100 end)
                if okP and type(pct) == "number" then
                    pctStr = string.format("%.1f%%", pct)
                end
            end
            -- Construire la ligne dans un pcall
            local line
            pcall(function()
                line = i .. ". " .. nameStr .. " - " .. psStr .. " " .. modeInfo.suffix .. " (" .. valStr .. " / " .. pctStr .. ")"
            end)
            if line then
                SendChatMessage(SafeChat(line), channel)
            end
        end
        HideSharePanel()
    end

    local function ShowSharePanel()
        if sharePanel and sharePanel:IsShown() then HideSharePanel(); return end

        local panelFrame = BravUI.Meter.Panel and BravUI.Meter.Panel._frame

        -- Backdrop invisible pour fermer au clic extérieur
        if not sharePanelBackdrop then
            sharePanelBackdrop = CreateFrame("Button", nil, UIParent)
            sharePanelBackdrop:SetAllPoints(UIParent)
            sharePanelBackdrop:SetFrameStrata("DIALOG")
            sharePanelBackdrop:SetFrameLevel(100)
            sharePanelBackdrop:RegisterForClicks("AnyUp")
            sharePanelBackdrop:SetScript("OnClick", function() HideSharePanel() end)
        end
        sharePanelBackdrop:Show()

        local PANEL_W = 180
        local ROW_H = 18
        local PAD = 6
        local fontPath = GetFont()
        local fSize = (GetDB().fontSize or 9)

        if not sharePanel then
            sharePanel = CreateFrame("Frame", nil, UIParent)
            sharePanel:SetFrameStrata("DIALOG")
            sharePanel:SetFrameLevel(110)
            sharePanel:SetClampedToScreen(true)
            sharePanel:SetWidth(PANEL_W)

            local bg = sharePanel:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(TEX)
            bg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
            bg:SetAllPoints(sharePanel)

            -- Bordures
            for _, args in ipairs({
                {"TOPLEFT", "TOPRIGHT", true},
                {"BOTTOMLEFT", "BOTTOMRIGHT", true},
                {"TOPLEFT", "BOTTOMLEFT", false},
                {"TOPRIGHT", "BOTTOMRIGHT", false},
            }) do
                local b = sharePanel:CreateTexture(nil, "BORDER")
                b:SetTexture(TEX)
                b:SetVertexColor(0.25, 0.25, 0.25, 1)
                if args[3] then
                    b:SetHeight(1)
                    b:SetPoint(args[1], sharePanel, args[1], 0, 0)
                    b:SetPoint(args[2], sharePanel, args[2], 0, 0)
                else
                    b:SetWidth(1)
                    b:SetPoint(args[1], sharePanel, args[1], 0, 0)
                    b:SetPoint(args[2], sharePanel, args[2], 0, 0)
                end
            end

            local yOff = -PAD

            -- Titre
            local title = sharePanel:CreateFontString(nil, "OVERLAY")
            title:SetFont(fontPath, fSize + 1, "OUTLINE")
            title:SetText("Partager")
            title:SetTextColor(1, 0.82, 0)
            title:SetPoint("TOP", sharePanel, "TOP", 0, yOff)

            -- Bouton fermer (croix)
            local closeBtn = CreateFrame("Button", nil, sharePanel)
            closeBtn:SetSize(ROW_H, ROW_H)
            closeBtn:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -2, yOff + 2)
            local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
            closeTxt:SetFont(fontPath, fSize + 1, "OUTLINE")
            closeTxt:SetText("x")
            closeTxt:SetTextColor(0.6, 0.6, 0.6)
            closeTxt:SetPoint("CENTER")
            closeBtn:SetScript("OnClick", function() HideSharePanel() end)
            closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.3, 0.3) end)
            closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.6, 0.6, 0.6) end)

            yOff = yOff - ROW_H

            -- Séparateur sous le titre
            local sep = sharePanel:CreateTexture(nil, "ARTWORK")
            sep:SetTexture(TEX)
            sep:SetVertexColor(0.25, 0.25, 0.25, 1)
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            sep:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -PAD, yOff)
            yOff = yOff - 8

            -- ========== DROPDOWN CANAL ==========
            local chanLabel = sharePanel:CreateFontString(nil, "OVERLAY")
            chanLabel:SetFont(fontPath, fSize, "OUTLINE")
            chanLabel:SetText("Canal")
            chanLabel:SetTextColor(0.7, 0.7, 0.7)
            chanLabel:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            yOff = yOff - ROW_H + 2

            -- Bouton dropdown
            local dropBtn = CreateFrame("Button", nil, sharePanel)
            dropBtn:SetHeight(ROW_H + 4)
            dropBtn:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            dropBtn:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -PAD, yOff)

            local dropBg = dropBtn:CreateTexture(nil, "BACKGROUND")
            dropBg:SetTexture(TEX)
            dropBg:SetAllPoints(dropBtn)
            dropBg:SetVertexColor(0.12, 0.12, 0.12, 1)

            -- Bordure dropdown
            for _, args in ipairs({
                {"TOPLEFT", "TOPRIGHT", true},
                {"BOTTOMLEFT", "BOTTOMRIGHT", true},
                {"TOPLEFT", "BOTTOMLEFT", false},
                {"TOPRIGHT", "BOTTOMRIGHT", false},
            }) do
                local b = dropBtn:CreateTexture(nil, "BORDER")
                b:SetTexture(TEX)
                b:SetVertexColor(0.3, 0.3, 0.3, 1)
                if args[3] then
                    b:SetHeight(1)
                    b:SetPoint(args[1], dropBtn, args[1], 0, 0)
                    b:SetPoint(args[2], dropBtn, args[2], 0, 0)
                else
                    b:SetWidth(1)
                    b:SetPoint(args[1], dropBtn, args[1], 0, 0)
                    b:SetPoint(args[2], dropBtn, args[2], 0, 0)
                end
            end

            local dropText = dropBtn:CreateFontString(nil, "OVERLAY")
            dropText:SetFont(fontPath, fSize, "OUTLINE")
            dropText:SetText(CHANNELS[selectedChannel].label)
            dropText:SetTextColor(1, 1, 1)
            dropText:SetPoint("LEFT", dropBtn, "LEFT", 6, 0)
            sharePanel._dropText = dropText

            local dropArrow = dropBtn:CreateFontString(nil, "OVERLAY")
            dropArrow:SetFont(fontPath, fSize, "OUTLINE")
            dropArrow:SetText("v")
            dropArrow:SetTextColor(0.6, 0.6, 0.6)
            dropArrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)

            -- Menu déroulant du dropdown
            local dropMenu = nil
            local dropMenuRows = {}

            local function HideDropMenu()
                if dropMenu then dropMenu:Hide() end
            end

            local function ShowDropMenu()
                if dropMenu and dropMenu:IsShown() then HideDropMenu(); return end

                if not dropMenu then
                    dropMenu = CreateFrame("Frame", nil, sharePanel)
                    dropMenu:SetFrameStrata("TOOLTIP")
                    dropMenu:SetFrameLevel(120)
                    dropMenu:SetWidth(dropBtn:GetWidth())

                    local dmBg = dropMenu:CreateTexture(nil, "BACKGROUND")
                    dmBg:SetTexture(TEX)
                    dmBg:SetVertexColor(0.1, 0.1, 0.1, 0.98)
                    dmBg:SetAllPoints(dropMenu)

                    for _, args in ipairs({
                        {"TOPLEFT", "TOPRIGHT", true},
                        {"BOTTOMLEFT", "BOTTOMRIGHT", true},
                        {"TOPLEFT", "BOTTOMLEFT", false},
                        {"TOPRIGHT", "BOTTOMRIGHT", false},
                    }) do
                        local b = dropMenu:CreateTexture(nil, "BORDER")
                        b:SetTexture(TEX)
                        b:SetVertexColor(0.3, 0.3, 0.3, 1)
                        if args[3] then
                            b:SetHeight(1)
                            b:SetPoint(args[1], dropMenu, args[1], 0, 0)
                            b:SetPoint(args[2], dropMenu, args[2], 0, 0)
                        else
                            b:SetWidth(1)
                            b:SetPoint(args[1], dropMenu, args[1], 0, 0)
                            b:SetPoint(args[2], dropMenu, args[2], 0, 0)
                        end
                    end
                end

                -- Créer/rafraîchir les rows
                for ri, chan in ipairs(CHANNELS) do
                    local row = dropMenuRows[ri]
                    if not row then
                        row = CreateFrame("Button", nil, dropMenu)
                        row:SetHeight(ROW_H)
                        row:RegisterForClicks("LeftButtonUp")

                        local rBg = row:CreateTexture(nil, "BACKGROUND")
                        rBg:SetTexture(TEX)
                        rBg:SetAllPoints(row)
                        rBg:SetVertexColor(1, 1, 1, 0)
                        row._bg = rBg

                        local rLabel = row:CreateFontString(nil, "OVERLAY")
                        rLabel:SetFont(fontPath, fSize, "OUTLINE")
                        rLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
                        row._label = rLabel

                        row:SetScript("OnEnter", function(self) self._bg:SetVertexColor(0.2, 0.6, 0.2, 0.3) end)
                        row:SetScript("OnLeave", function(self) self._bg:SetVertexColor(1, 1, 1, 0) end)

                        dropMenuRows[ri] = row
                    end

                    row._label:SetText(chan.label)
                    if ri == selectedChannel then
                        row._label:SetTextColor(0.33, 1, 0.33)
                    else
                        row._label:SetTextColor(0.9, 0.9, 0.9)
                    end
                    row:SetPoint("TOPLEFT", dropMenu, "TOPLEFT", 0, -(ri - 1) * ROW_H)
                    row:SetPoint("TOPRIGHT", dropMenu, "TOPRIGHT", 0, -(ri - 1) * ROW_H)

                    local idx = ri
                    row:SetScript("OnClick", function()
                        selectedChannel = idx
                        sharePanel._dropText:SetText(CHANNELS[selectedChannel].label)
                        HideDropMenu()
                    end)
                    row:Show()
                end

                dropMenu:SetHeight(#CHANNELS * ROW_H)
                dropMenu:ClearAllPoints()
                dropMenu:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -1)
                dropMenu:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -1)
                dropMenu:Show()
            end

            dropBtn:SetScript("OnClick", ShowDropMenu)
            dropBtn:SetScript("OnEnter", function() dropBg:SetVertexColor(0.18, 0.18, 0.18, 1) end)
            dropBtn:SetScript("OnLeave", function() dropBg:SetVertexColor(0.12, 0.12, 0.12, 1) end)

            yOff = yOff - ROW_H - 12

            -- ========== SLIDER NOMBRE ==========
            local countLabel = sharePanel:CreateFontString(nil, "OVERLAY")
            countLabel:SetFont(fontPath, fSize, "OUTLINE")
            countLabel:SetTextColor(0.7, 0.7, 0.7)
            countLabel:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            sharePanel._countLabel = countLabel
            yOff = yOff - ROW_H + 2

            -- Slider track
            local SLIDER_H = 8
            local sliderFrame = CreateFrame("Frame", nil, sharePanel)
            sliderFrame:SetHeight(SLIDER_H + 10)
            sliderFrame:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            sliderFrame:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -PAD, yOff)

            local sliderTrack = sliderFrame:CreateTexture(nil, "BACKGROUND")
            sliderTrack:SetTexture(TEX)
            sliderTrack:SetVertexColor(0.15, 0.15, 0.15, 1)
            sliderTrack:SetHeight(SLIDER_H)
            sliderTrack:SetPoint("LEFT", sliderFrame, "LEFT", 0, 0)
            sliderTrack:SetPoint("RIGHT", sliderFrame, "RIGHT", 0, 0)

            -- Track border
            for _, args in ipairs({
                {"TOPLEFT", "TOPRIGHT", true},
                {"BOTTOMLEFT", "BOTTOMRIGHT", true},
            }) do
                local b = sliderFrame:CreateTexture(nil, "BORDER")
                b:SetTexture(TEX)
                b:SetVertexColor(0.3, 0.3, 0.3, 1)
                b:SetHeight(1)
                b:SetPoint("LEFT", sliderTrack, "LEFT", 0, 0)
                b:SetPoint("RIGHT", sliderTrack, "RIGHT", 0, 0)
                b:SetPoint(args[1], sliderTrack, args[1], 0, 0)
            end

            -- Fill (progression)
            local sliderFill = sliderFrame:CreateTexture(nil, "ARTWORK")
            sliderFill:SetTexture(TEX)
            local acR, acG, acB = GetClassColor()
            sliderFill:SetVertexColor(acR, acG, acB, 0.8)
            sliderFill:SetHeight(SLIDER_H)
            sliderFill:SetPoint("LEFT", sliderTrack, "LEFT", 0, 0)

            -- Thumb (curseur)
            local thumb = CreateFrame("Frame", nil, sliderFrame)
            thumb:SetSize(4, SLIDER_H + 4)
            local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
            thumbTex:SetTexture(TEX)
            thumbTex:SetVertexColor(1, 1, 1, 0.9)
            thumbTex:SetAllPoints(thumb)

            local SLIDER_MIN = 1
            local SLIDER_MAX = 25

            local function UpdateSlider()
                local pct = (selectedCount - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
                local trackW = sliderFrame:GetWidth()
                if trackW and trackW > 0 then
                    local fillW = math.max(1, pct * trackW)
                    sliderFill:SetWidth(fillW)
                    thumb:ClearAllPoints()
                    thumb:SetPoint("CENTER", sliderTrack, "LEFT", fillW, 0)
                end
                sharePanel._countLabel:SetText("Nombre : " .. selectedCount)
            end
            sharePanel._updateSlider = UpdateSlider

            -- Clic sur la track pour changer la valeur
            local sliderBtn = CreateFrame("Button", nil, sliderFrame)
            sliderBtn:SetAllPoints(sliderFrame)
            sliderBtn:RegisterForClicks("LeftButtonUp")
            sliderBtn:SetScript("OnClick", function(self)
                local x = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local left = sliderTrack:GetLeft() * scale
                local right = sliderTrack:GetRight() * scale
                if not left or not right or right <= left then return end
                local pct = (x - left) / (right - left)
                pct = math.max(0, math.min(1, pct))
                selectedCount = math.floor(SLIDER_MIN + pct * (SLIDER_MAX - SLIDER_MIN) + 0.5)
                UpdateSlider()
            end)
            -- Drag sur la track
            sliderBtn:SetScript("OnMouseDown", function(self)
                self._dragging = true
            end)
            sliderBtn:SetScript("OnMouseUp", function(self)
                self._dragging = false
            end)
            sliderBtn:SetScript("OnUpdate", function(self)
                if not self._dragging or not IsMouseButtonDown("LeftButton") then
                    self._dragging = false
                    return
                end
                local x = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local left = sliderTrack:GetLeft() * scale
                local right = sliderTrack:GetRight() * scale
                if not left or not right or right <= left then return end
                local pct = (x - left) / (right - left)
                pct = math.max(0, math.min(1, pct))
                selectedCount = math.floor(SLIDER_MIN + pct * (SLIDER_MAX - SLIDER_MIN) + 0.5)
                UpdateSlider()
            end)

            yOff = yOff - SLIDER_H - 18

            -- ========== SÉPARATEUR ==========
            local sep3 = sharePanel:CreateTexture(nil, "ARTWORK")
            sep3:SetTexture(TEX)
            sep3:SetVertexColor(0.25, 0.25, 0.25, 1)
            sep3:SetHeight(1)
            sep3:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            sep3:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -PAD, yOff)
            yOff = yOff - 6

            -- ========== BOUTON ENVOYER ==========
            local sendBtn = CreateFrame("Button", nil, sharePanel)
            sendBtn:SetHeight(ROW_H + 4)
            sendBtn:SetPoint("TOPLEFT", sharePanel, "TOPLEFT", PAD, yOff)
            sendBtn:SetPoint("TOPRIGHT", sharePanel, "TOPRIGHT", -PAD, yOff)

            local sendBg = sendBtn:CreateTexture(nil, "BACKGROUND")
            sendBg:SetTexture(TEX)
            sendBg:SetAllPoints(sendBtn)
            sendBg:SetVertexColor(0.15, 0.5, 0.15, 0.5)

            local sendTxt = sendBtn:CreateFontString(nil, "OVERLAY")
            sendTxt:SetFont(fontPath, fSize + 1, "OUTLINE")
            sendTxt:SetText("Envoyer")
            sendTxt:SetTextColor(1, 1, 1)
            sendTxt:SetPoint("CENTER")

            sendBtn:SetScript("OnClick", function()
                HideDropMenu()
                DoShare()
            end)
            sendBtn:SetScript("OnEnter", function() sendBg:SetVertexColor(0.2, 0.7, 0.2, 0.7) end)
            sendBtn:SetScript("OnLeave", function() sendBg:SetVertexColor(0.15, 0.5, 0.15, 0.5) end)

            yOff = yOff - ROW_H - 4 - PAD

            -- Hauteur totale
            sharePanel:SetHeight(-yOff)
        end

        -- Rafraîchir l'état
        sharePanel._dropText:SetText(CHANNELS[selectedChannel].label)
        C_Timer.After(0, function()
            if sharePanel._updateSlider then sharePanel._updateSlider() end
        end)

        -- Positionner au-dessus du panel
        sharePanel:ClearAllPoints()
        sharePanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        sharePanel:Show()
    end

    shareBtn:SetScript("OnClick", ShowSharePanel)
    shareBtn:SetScript("OnEnter", function(self)
        shareTex:SetVertexColor(1, 1, 1, 1)
        ShowBravTooltip(self, "Partager", "Envoie le rapport dans le chat")
    end)
    shareBtn:SetScript("OnLeave", function()
        shareTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7)
        HideBravTooltip()
    end)

    -- Bouton segments
    local segBtn = CreateFrame("Button", nil, half)
    segBtn:SetSize(14, tabZone - 4)
    segBtn:SetPoint("RIGHT", shareBtn, "LEFT", -3, 0)
    local segTex = segBtn:CreateTexture(nil, "OVERLAY")
    segTex:SetTexture("Interface/BUTTONS/UI-GuildButton-PublicNote-Up")
    segTex:SetSize(12, 12)
    segTex:SetPoint("CENTER")
    segTex:SetVertexColor(cr, cg, cb, 0.7)
    segBtn:SetScript("OnClick", function()
        if barsInst and barsInst.ShowSegmentMenu then
            barsInst.ShowSegmentMenu()
        end
    end)
    segBtn:SetScript("OnEnter", function(self)
        segTex:SetVertexColor(1, 1, 1, 1)
        ShowBravTooltip(self, "Segments", "Clic pour changer de segment", "Molette pour naviguer")
    end)
    segBtn:SetScript("OnLeave", function()
        segTex:SetVertexColor(Panel._accentR, Panel._accentG, Panel._accentB, 0.7)
        HideBravTooltip()
    end)

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

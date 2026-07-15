-- BravUI — Module Options
--
-- Menu de configuration maison (fenêtre flottante, sans dépendance). Style
-- « panneau de config » monochrome : en-tête + barre latérale de catégories +
-- zone de contenu. Widgets custom (curseurs / toggles) construits à partir de
-- frames bruts + textures (cercle, pilule) — aucun template Blizzard. Ouvert par
-- « /brav » (Core/Init.lua) et par un bouton BravUI intégré au menu ESC. Écrit
-- dans ns.db (profil actif) puis demande au module UnitFrames de se rafraîchir.

local addonName, ns = ...

local Options = {}
ns.Options = Options
local M = ns:RegisterModule("Options")

--------------------------------------------------------------------------------
-- Constantes visuelles (thème gris, accent neutre #999)
--------------------------------------------------------------------------------
local FLAT   = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\AddOns\\BravUI\\Media\\circle.tga"
local PILL   = "Interface\\AddOns\\BravUI\\Media\\pill.tga"
local FONT   = "Interface\\AddOns\\BravUI\\Media\\RussoOne-Regular.ttf"

local BG      = { 0.082, 0.082, 0.082 } -- #151515 fond principal
local SIDEBAR = { 0.067, 0.067, 0.067 } -- #111 barre latérale
local HEADERC = { 0.110, 0.110, 0.110 } -- #1c1c1c en-tête
local BORDER  = { 0.165, 0.165, 0.165 } -- #2a2a2a bordures / piste
local ACCENT  = { 0.600, 0.600, 0.600 } -- #999 accent unique
local OFFCOL  = { 0.267, 0.267, 0.267 } -- #444 toggle inactif
local TXT     = { 0.820, 0.820, 0.820 } -- texte clair
local TXTDIM  = { 0.500, 0.500, 0.500 } -- texte atténué

local function ApplyFont(fs, size, flags)
    if not fs:SetFont(FONT, size, flags) then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
end

local function UF() return ns:GetModule("UnitFrames") end

-- Applique un masque (coins arrondis) à une texture.
local function RoundMask(owner, region, maskPath)
    local m = owner:CreateMaskTexture()
    m:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(region)
    region:AddMaskTexture(m)
    return m
end

--------------------------------------------------------------------------------
-- Widgets custom
--------------------------------------------------------------------------------
-- Toggle « pilule » : piste 32x18 arrondie (#999 actif / #444 inactif) + rond
-- blanc qui glisse. get()/set(bool). :Sync() recharge sans déclencher set.
local function CreateToggle(parent, label, get, set)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(32, 18)

    local pill = t:CreateTexture(nil, "BACKGROUND")
    pill:SetTexture(FLAT); pill:SetAllPoints()
    local m = t:CreateMaskTexture()
    m:SetTexture(PILL, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(pill)
    pill:AddMaskTexture(m)

    local knob = t:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(CIRCLE); knob:SetVertexColor(1, 1, 1); knob:SetSize(14, 14)

    local lbl = t:CreateFontString(nil, "OVERLAY")
    ApplyFont(lbl, 12); lbl:SetTextColor(TXT[1], TXT[2], TXT[3])
    lbl:SetPoint("LEFT", t, "RIGHT", 9, 0); lbl:SetText(label)

    function t:SetChecked(v)
        self.checked = v and true or false
        knob:ClearAllPoints()
        if self.checked then
            pill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
            knob:SetPoint("RIGHT", t, "RIGHT", -2, 0)
        else
            pill:SetVertexColor(OFFCOL[1], OFFCOL[2], OFFCOL[3], 1)
            knob:SetPoint("LEFT", t, "LEFT", 2, 0)
        end
    end
    t:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked); set(self.checked)
    end)
    function t:Sync() self:SetChecked(get()) end
    return t
end

-- Curseur custom : piste 4px arrondie (#2a2a2a) + remplissage #999 jusqu'à la
-- poignée ronde blanche (12px). OnValueChanged n'applique que sur action
-- utilisateur -> :Sync() ne redéclenche pas set. Largeur du bloc = SLIDER_W.
local SLIDER_W = 340
local function CreateSlider(parent, label, minV, maxV, step, get, set)
    local s = CreateFrame("Slider", nil, parent)
    s:SetSize(SLIDER_W, 16) -- zone de piste (la poignée y est centrée verticalement)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(FLAT); track:SetVertexColor(BORDER[1], BORDER[2], BORDER[3], 1)
    track:SetHeight(4); track:SetPoint("LEFT"); track:SetPoint("RIGHT")

    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(FLAT); fill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    fill:SetHeight(4); fill:SetPoint("LEFT", track, "LEFT") -- largeur pilotée ci-dessous

    -- Un seul masque (taille de la piste) arrondit piste ET remplissage.
    local mask = s:CreateMaskTexture()
    mask:SetTexture(PILL, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(track)
    track:AddMaskTexture(mask); fill:AddMaskTexture(mask)

    s:SetThumbTexture(CIRCLE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(12, 12); thumb:SetVertexColor(1, 1, 1)

    local lbl = s:CreateFontString(nil, "OVERLAY")
    ApplyFont(lbl, 11); lbl:SetTextColor(TXT[1], TXT[2], TXT[3])
    lbl:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 5); lbl:SetText(label)
    local val = s:CreateFontString(nil, "OVERLAY")
    ApplyFont(val, 11); val:SetTextColor(0.65, 0.65, 0.65)
    val:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 5)
    s.valueText = val

    s:SetScript("OnValueChanged", function(self, value, user)
        value = math.floor(value + 0.5)
        val:SetText(value)
        -- Remplissage = fraction de la largeur (de gauche jusqu'à la poignée).
        local frac = (maxV > minV) and ((value - minV) / (maxV - minV)) or 0
        fill:SetWidth(math.max(1, SLIDER_W * frac))
        if user then set(value) end
    end)
    function s:Sync() self:SetValue(get()) end
    return s
end

--------------------------------------------------------------------------------
-- Fenêtre d'options
--------------------------------------------------------------------------------
local PAD = 16
local HEADER_H = 32
local SIDEBAR_W = 130

function Options:Build()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "BravUIOptionsFrame", UIParent)
    f:SetSize(520, 448)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "BravUIOptionsFrame")

    -- Bordure + corps.
    local edge = f:CreateTexture(nil, "BACKGROUND")
    edge:SetTexture(FLAT); edge:SetVertexColor(BORDER[1], BORDER[2], BORDER[3], 1); edge:SetAllPoints()
    local body = f:CreateTexture(nil, "BORDER")
    body:SetTexture(FLAT); body:SetVertexColor(BG[1], BG[2], BG[3], 1)
    body:SetPoint("TOPLEFT", 1, -1); body:SetPoint("BOTTOMRIGHT", -1, 1)

    -- En-tête (déplaçable) + bordure basse accent.
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(HEADER_H)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local htex = header:CreateTexture(nil, "ARTWORK")
    htex:SetTexture(FLAT); htex:SetVertexColor(HEADERC[1], HEADERC[2], HEADERC[3], 1); htex:SetAllPoints()
    local hline = header:CreateTexture(nil, "OVERLAY")
    hline:SetTexture(FLAT); hline:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT"); hline:SetHeight(1)
    local titleText = header:CreateFontString(nil, "OVERLAY")
    ApplyFont(titleText, 15); titleText:SetPoint("LEFT", PAD, 0)
    titleText:SetTextColor(0.88, 0.88, 0.88); titleText:SetText("BravUI")
    local subText = header:CreateFontString(nil, "OVERLAY")
    ApplyFont(subText, 12); subText:SetPoint("LEFT", titleText, "RIGHT", 6, -1)
    subText:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3]); subText:SetText("options")

    local close = CreateFrame("Button", nil, header)
    close:SetSize(24, 24); close:SetPoint("RIGHT", -6, 0)
    local cx = close:CreateFontString(nil, "OVERLAY")
    -- Glyphe via la police par défaut (Russo One n'a pas forcément « × »).
    cx:SetFont(STANDARD_TEXT_FONT, 20, ""); cx:SetAllPoints(); cx:SetJustifyH("CENTER")
    cx:SetText("×"); cx:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cx:SetTextColor(0.9, 0.9, 0.9) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3]) end)

    -- Barre latérale + séparateur.
    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", 1, -(HEADER_H + 1)); sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_W)
    local sbTex = sidebar:CreateTexture(nil, "ARTWORK")
    sbTex:SetTexture(FLAT); sbTex:SetVertexColor(SIDEBAR[1], SIDEBAR[2], SIDEBAR[3], 1); sbTex:SetAllPoints()
    local sep = f:CreateTexture(nil, "OVERLAY")
    sep:SetTexture(FLAT); sep:SetVertexColor(BORDER[1], BORDER[2], BORDER[3], 1)
    sep:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0); sep:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    sep:SetWidth(1)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0); content:SetPoint("BOTTOMRIGHT", -1, 1)

    self.controls = {}
    self.categories = {}
    local function track(w) self.controls[#self.controls + 1] = w; return w end

    -- Catégorie : item de barre latérale (fond #ffffff14 + barre gauche #999 si
    -- actif) + panneau de contenu masquable.
    local function newCategory(label)
        local idx = #self.categories + 1
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(SIDEBAR_W, 30); btn:SetPoint("TOPLEFT", 0, -(idx - 1) * 30)
        local sel = btn:CreateTexture(nil, "BACKGROUND")
        sel:SetTexture(FLAT); sel:SetVertexColor(1, 1, 1, 0.078); sel:SetAllPoints(); sel:Hide()
        local accent = btn:CreateTexture(nil, "ARTWORK")
        accent:SetTexture(FLAT); accent:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2); accent:Hide()
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(FLAT); hl:SetVertexColor(1, 1, 1, 0.04); hl:SetAllPoints()
        local t = btn:CreateFontString(nil, "OVERLAY")
        ApplyFont(t, 13); t:SetPoint("LEFT", 16, 0); t:SetText(label)
        local panel = CreateFrame("Frame", nil, content)
        panel:SetPoint("TOPLEFT", PAD, -PAD); panel:SetPoint("BOTTOMRIGHT", -PAD, PAD); panel:Hide()
        btn:SetScript("OnClick", function() self:SelectCategory(idx) end)
        self.categories[idx] = { panel = panel, sel = sel, accent = accent, text = t }
        return panel
    end

    -- Titre de section (petit label gris atténué).
    local function sectionHeader(panel, text, y)
        local h = panel:CreateFontString(nil, "OVERLAY")
        ApplyFont(h, 12); h:SetTextColor(0.55, 0.55, 0.55)
        h:SetPoint("TOPLEFT", 0, y); h:SetText(text)
        return h
    end

    -- Lien texte discret (aligné à droite), pas un gros bouton.
    local function linkButton(panel, label, y, onClick)
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(80, 16); b:SetPoint("TOPRIGHT", 0, y)
        local t = b:CreateFontString(nil, "OVERLAY")
        ApplyFont(t, 11); t:SetPoint("RIGHT"); t:SetJustifyH("RIGHT")
        t:SetText(label); t:SetTextColor(0.55, 0.55, 0.55)
        b:SetScript("OnEnter", function() t:SetTextColor(0.9, 0.9, 0.9) end)
        b:SetScript("OnLeave", function() t:SetTextColor(0.55, 0.55, 0.55) end)
        b:SetScript("OnClick", onClick)
        return b
    end

    -- Placeholder pour les catégories pas encore remplies.
    local function placeholder(panel)
        local t = panel:CreateFontString(nil, "OVERLAY")
        ApplyFont(t, 13); t:SetTextColor(0.4, 0.4, 0.4)
        t:SetPoint("TOP", 0, -40); t:SetText("À venir")
    end

    -- Contenu d'un onglet d'unité (structure de la spec Joueur).
    local function buildUnitTab(panel, unit)
        local db = function() return ns.db.unitframes[unit] end

        sectionHeader(panel, "Activation", -2)
        track(CreateToggle(panel, "Activer le cadre de vie",
            function() return db().enabled end,
            function(v) UF():SetEnabled(unit, v) end)):SetPoint("TOPLEFT", 0, -24)

        sectionHeader(panel, "Position", -56)
        linkButton(panel, "Recentrer", -56, function() UF():ResetPosition(unit) end)
        track(CreateSlider(panel, "X (horizontal)", -960, 960, 1,
            function() return db().x end,
            function(v) db().x = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -90)
        track(CreateSlider(panel, "Y (vertical)", -600, 600, 1,
            function() return db().y end,
            function(v) db().y = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -124)

        sectionHeader(panel, "Taille — vie", -156)
        track(CreateSlider(panel, "Largeur", 100, 400, 5,
            function() return db().health.width end,
            function(v) db().health.width = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -190)
        track(CreateSlider(panel, "Hauteur", 20, 100, 2,
            function() return db().health.height end,
            function(v) db().health.height = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -224)

        sectionHeader(panel, "Taille — ressource", -256)
        track(CreateSlider(panel, "Largeur", 100, 400, 5,
            function() return db().power.width end,
            function(v) db().power.width = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -290)
        track(CreateSlider(panel, "Hauteur", 5, 40, 1,
            function() return db().power.height end,
            function(v) db().power.height = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -324)
        track(CreateSlider(panel, "Écart avec la vie", 0, 20, 1,
            function() return db().power.gap end,
            function(v) db().power.gap = v; UF():RefreshAll() end)):SetPoint("TOPLEFT", 0, -358)
    end

    buildUnitTab(newCategory("Joueur"), "player")
    placeholder(newCategory("Cible"))   -- structure à dupliquer ensuite
    placeholder(newCategory("Général")) -- reste à définir

    self:SelectCategory(1)
    f:Hide() -- CreateFrame crée une frame VISIBLE : on la masque (sinon 2 clics).
    self.frame = f
    return f
end

-- Sélectionne une catégorie : affiche son panneau, met en évidence son item.
function Options:SelectCategory(idx)
    if not self.categories then return end
    for i, c in ipairs(self.categories) do
        local active = (i == idx)
        c.panel:SetShown(active)
        c.sel:SetShown(active)
        c.accent:SetShown(active)
        c.text:SetTextColor(active and 0.95 or 0.55, active and 0.95 or 0.55, active and 0.95 or 0.55)
    end
end

function Options:Refresh()
    if not self.controls then return end
    for _, w in ipairs(self.controls) do w:Sync() end
end

function Options:Toggle()
    local f = self:Build()
    if f:IsShown() then
        f:Hide()
    else
        self:Refresh()
        f:Show()
    end
end

--------------------------------------------------------------------------------
-- Bouton BravUI INTÉGRÉ au menu ESC (GameMenuFrame)
-- Approche éprouvée (façon ElvUI) : un bouton au template NATIF est ajouté au
-- cadre, puis réinséré parmi les boutons du pool à chaque Layout — placé sous
-- « Boutique », en décalant les voisins, et le cadre est agrandi.
--------------------------------------------------------------------------------
local function PositionGameMenuButton()
    local myButton = GameMenuFrame and GameMenuFrame.BravUI
    if not myButton or not GameMenuFrame.buttonPool then return end

    local anchor
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        local text = button:GetText()
        if text == BLIZZARD_STORE or text == GAMEMENU_STORE then
            anchor = button
            break
        elseif text == MACROS and not anchor then
            anchor = button
        end
    end
    if not anchor then return end

    local anchorBottom = anchor:GetBottom()
    if not anchorBottom then return end
    local h = myButton:GetHeight() + 2

    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        if button ~= anchor and button.AdjustPointsOffset then
            local top = button:GetTop()
            if top and top < anchorBottom then
                button:AdjustPointsOffset(0, -h)
            end
        end
    end

    myButton:ClearAllPoints()
    myButton:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + h)
end

local function SetupGameMenuButton()
    if not GameMenuFrame or GameMenuFrame.BravUI then return end
    local ok, button = pcall(CreateFrame, "Button", "BravUI_GameMenuButton",
        GameMenuFrame, "MainMenuFrameButtonTemplate")
    if not ok or not button then return end
    button:SetSize(200, 35)
    button:SetText("BravUI")
    local fs = button:GetFontString()
    if fs then
        local _, _, flags = fs:GetFont()
        fs:SetFont(FONT, 14, flags)
    end
    button:SetScript("OnClick", function()
        HideUIPanel(GameMenuFrame)
        Options:Toggle()
    end)
    GameMenuFrame.BravUI = button
    if GameMenuFrame.Layout then
        hooksecurefunc(GameMenuFrame, "Layout", PositionGameMenuButton)
    end
end

--------------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------------
function M:OnEnable()
    SetupGameMenuButton()
end

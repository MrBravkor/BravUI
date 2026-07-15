-- BravUI — Module Options
--
-- Menu de configuration maison (fenêtre flottante, aucune dépendance). Style
-- « panneau de config » monochrome : en-tête + barre latérale de PAGES + zone de
-- contenu. Ouvert par « /brav » (Core/Init.lua) et par un bouton BravUI intégré
-- au menu Échap.
--
-- Structure :
--   Sidebar = pages.  Page « Général » (échelle du menu) et page « Cadres
--   d'unité » (onglets Joueur / Cible / Focus / ToT). Le contenu des onglets
--   d'unité est ajouté à l'étape suivante.

local addonName, ns = ...

local Options = {}
ns.Options = Options
local M = ns:RegisterModule("Options")

--------------------------------------------------------------------------------
-- Thème (gris monochrome, accent neutre)
--------------------------------------------------------------------------------
local FLAT      = "Interface\\Buttons\\WHITE8X8"
local CIRCLE    = "Interface\\AddOns\\BravUI\\Media\\circle.tga"
local PILL      = "Interface\\AddOns\\BravUI\\Media\\pill.tga"
local MASK_THIN = "Interface\\AddOns\\BravUI\\Media\\roundmask_thin.tga" -- coins arrondis (barre fine)
local FONT      = "Interface\\AddOns\\BravUI\\Media\\RussoOne-Regular.ttf"

local BG      = { 0.086, 0.086, 0.086 } -- corps
local SIDEBAR = { 0.067, 0.067, 0.067 } -- barre latérale
local HEADERC = { 0.110, 0.110, 0.110 } -- en-tête
local BORDER  = { 0.165, 0.165, 0.165 } -- bordures / séparateur / piste
local ACCENT  = { 0.600, 0.600, 0.600 } -- accent unique
local OFFCOL  = { 0.267, 0.267, 0.267 } -- interrupteur inactif
local TXT     = { 0.860, 0.860, 0.860 } -- texte clair
local TXTDIM  = { 0.480, 0.480, 0.480 } -- texte atténué

-- Facteur global de taille de police du menu (réglage en un seul point).
local FONT_SCALE = 0.85
local function ApplyFont(fs, size, flags)
    size = math.floor(size * FONT_SCALE + 0.5)
    flags = flags or "" -- EditBox:SetFont refuse un flags nil (les FontString l'acceptent)
    if not fs:SetFont(FONT, size, flags) then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
end

-- Raccourci : texture pleine d'une couleur sur un cadre/région.
local function Fill(parent, layer, color, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(FLAT)
    t:SetVertexColor(color[1], color[2], color[3], a or 1)
    return t
end

-- Accès au module UnitFrames (pour appliquer les réglages).
local function UF() return ns:GetModule("UnitFrames") end

--------------------------------------------------------------------------------
-- Défauts (contribués au système de profils)
--------------------------------------------------------------------------------
ns.Config:RegisterDefaults("menu", { scale = 1.0 }) -- échelle de la fenêtre d'options

--------------------------------------------------------------------------------
-- Dimensions
--------------------------------------------------------------------------------
local WIDTH     = 680
local HEIGHT    = 560
local HEADER_H  = 36
local SIDEBAR_W = 152
local PAD       = 18
local SLIDER_W  = 340

--------------------------------------------------------------------------------
-- Widget : jauge (curseur) maison, simple.
-- Piste sombre arrondie + remplissage accent, SANS poignée : on clique/glisse
-- directement sur la barre. Valeur ÉDITABLE (entrée clavier applique, Échap
-- annule) avec suffixe optionnel. opts = { toText(v), fromText(str)->v|nil, suffix }.
--------------------------------------------------------------------------------
local TRACK_H = 18
local function CreateSlider(parent, label, minV, maxV, step, get, set, opts)
    opts = opts or {}
    local toText   = opts.toText   or function(v) return tostring(v) end
    local fromText = opts.fromText or function(str) return tonumber(str) end

    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(SLIDER_W, TRACK_H)
    s:EnableMouse(true)

    -- Piste + remplissage, coins arrondis (un masque pilule sur toute la jauge).
    local track = Fill(s, "BACKGROUND", BORDER); track:SetAllPoints()
    local fill = Fill(s, "ARTWORK", ACCENT)
    fill:SetPoint("TOPLEFT"); fill:SetPoint("BOTTOMLEFT"); fill:SetWidth(1)
    local mask = s:CreateMaskTexture()
    mask:SetTexture(MASK_THIN, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(s)
    track:AddMaskTexture(mask); fill:AddMaskTexture(mask)

    -- Repère d'ajustement : fine barre verticale au bord du remplissage.
    local handle = Fill(s, "OVERLAY", { 1, 1, 1 })
    handle:SetSize(2, TRACK_H)
    handle:SetPoint("CENTER", fill, "RIGHT", 0, 0)

    -- Libellé DANS la barre (gauche), blanc contouré pour rester lisible sur le
    -- remplissage comme sur le fond sombre.
    local lbl = s:CreateFontString(nil, "OVERLAY")
    ApplyFont(lbl, 11, "OUTLINE"); lbl:SetTextColor(1, 1, 1)
    lbl:SetPoint("LEFT", s, "LEFT", 9, 0); lbl:SetText(label)

    -- Zone VALEUR (droite) sur un petit cadre AU-DESSUS de la barre. Elle porte la
    -- valeur éditable + un soulignement accent PERMANENT (affordance « champ ») et
    -- une surbrillance au survol / en édition. Elle capte le clic (focus) et
    -- n'occupe que la droite -> le reste de la barre reste glissable.
    local vf = CreateFrame("Frame", nil, s)
    vf:SetFrameLevel(s:GetFrameLevel() + 2)
    vf:SetPoint("TOPRIGHT", -5, 0); vf:SetPoint("BOTTOMRIGHT", -5, 0); vf:SetWidth(48)
    vf:EnableMouse(true)
    local vbg = Fill(vf, "BACKGROUND", { 1, 1, 1 }, 0); vbg:SetAllPoints()
    local vund = Fill(vf, "ARTWORK", ACCENT, 0.55)
    vund:SetPoint("BOTTOMLEFT", 0, 3); vund:SetPoint("BOTTOMRIGHT", 0, 3); vund:SetHeight(1)

    local suffix
    if opts.suffix then
        suffix = vf:CreateFontString(nil, "OVERLAY")
        ApplyFont(suffix, 11, "OUTLINE"); suffix:SetTextColor(0.90, 0.90, 0.90)
        suffix:SetPoint("RIGHT", vf, "RIGHT", -1, 0); suffix:SetText(opts.suffix)
    end
    local edit = CreateFrame("EditBox", nil, vf)
    edit:SetSize(32, TRACK_H); edit:SetAutoFocus(false); edit:SetMaxLetters(6)
    ApplyFont(edit, 11, "OUTLINE"); edit:SetJustifyH("RIGHT"); edit:SetTextColor(1, 1, 1)
    if suffix then edit:SetPoint("RIGHT", suffix, "LEFT", -2, 0)
    else edit:SetPoint("RIGHT", vf, "RIGHT", -1, 0) end

    -- Survol / édition : surbrillance + soulignement plus vif.
    local function hlSet(a, bright)
        vbg:SetVertexColor(1, 1, 1, a)
        if bright then vund:SetVertexColor(1, 1, 1, 0.9)
        else vund:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.55) end
    end
    vf:SetScript("OnEnter", function() if not edit:HasFocus() then hlSet(0.10, false) end end)
    vf:SetScript("OnLeave", function() if not edit:HasFocus() then hlSet(0, false) end end)
    vf:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEditFocusGained", function() hlSet(0.14, true) end)
    edit:SetScript("OnEditFocusLost", function() hlSet(0, false) end)

    local function snap(v)
        v = math.min(math.max(v, minV), maxV)
        return minV + math.floor((v - minV) / step + 0.5) * step
    end
    -- Applique une valeur : maj remplissage + champ, et set() si demandé.
    local function apply(v, fromUser)
        v = snap(v)
        edit:SetText(toText(v)); edit:SetCursorPosition(0)
        local frac = (maxV > minV) and ((v - minV) / (maxV - minV)) or 0
        fill:SetWidth(math.max(1, s:GetWidth() * frac)) -- largeur réelle -> jauges variables
        if fromUser then set(v) end
    end
    -- Valeur correspondant à la position du curseur souris sur la barre.
    local function valueFromCursor()
        local mx = GetCursorPosition() / s:GetEffectiveScale()
        local frac = (mx - s:GetLeft()) / s:GetWidth()
        return minV + math.min(math.max(frac, 0), 1) * (maxV - minV)
    end

    s:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        self.dragging = true
        apply(valueFromCursor(), true)
    end)
    s:SetScript("OnMouseUp", function(self) self.dragging = false end)
    s:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if not IsMouseButtonDown("LeftButton") then self.dragging = false; return end
        apply(valueFromCursor(), true) -- glisse : suit le curseur (même hors du cadre)
    end)
    edit:SetScript("OnEnterPressed", function(self)
        local v = fromText(self:GetText())
        if v then apply(v, true) else self:SetText(toText(snap(get()))) end
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:SetText(toText(snap(get()))); self:ClearFocus() end)

    function s:Sync() apply(get(), false) end
    return s
end

--------------------------------------------------------------------------------
-- Widget : interrupteur (pilule + rond blanc glissant). get()/set(bool).
--------------------------------------------------------------------------------
local function CreateToggle(parent, label, get, set)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(28, 15)

    local pill = Fill(t, "BACKGROUND", OFFCOL); pill:SetAllPoints()
    local mask = t:CreateMaskTexture()
    mask:SetTexture(PILL, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(pill)
    pill:AddMaskTexture(mask)

    local knob = t:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(CIRCLE); knob:SetVertexColor(1, 1, 1); knob:SetSize(11, 11)

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
    t:SetScript("OnClick", function(self) self:SetChecked(not self.checked); set(self.checked) end)
    function t:Sync() self:SetChecked(get()) end
    return t
end

--------------------------------------------------------------------------------
-- Widget : sélecteur d'ancre déroulant (bouton + popup grille 3x3).
-- get()/set(pos) avec pos = "TOPLEFT"… ; :Sync() reflète la valeur courante.
--------------------------------------------------------------------------------
local ANCHOR_GRID = {
    { "TOPLEFT", "TOP", "TOPRIGHT" },
    { "LEFT", "CENTER", "RIGHT" },
    { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
}
local ANCHOR_LABELS = {
    TOPLEFT = "Haut G.", TOP = "Haut", TOPRIGHT = "Haut D.",
    LEFT = "Gauche", CENTER = "Centre", RIGHT = "Droite",
    BOTTOMLEFT = "Bas G.", BOTTOM = "Bas", BOTTOMRIGHT = "Bas D.",
}
local function CreateAnchorDropdown(parent, get, set)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(84, 18)
    Fill(btn, "BACKGROUND", { 0, 0, 0 }, 0.30):SetAllPoints()
    Fill(btn, "HIGHLIGHT", { 1, 1, 1 }, 0.08):SetAllPoints()
    local ul = Fill(btn, "ARTWORK", ACCENT, 0.5)
    ul:SetPoint("BOTTOMLEFT"); ul:SetPoint("BOTTOMRIGHT"); ul:SetHeight(1)
    local txt = btn:CreateFontString(nil, "OVERLAY")
    ApplyFont(txt, 11); txt:SetPoint("LEFT", 6, 0); txt:SetTextColor(0.85, 0.85, 0.85)
    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(STANDARD_TEXT_FONT, 9, ""); arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetText("v"); arrow:SetTextColor(0.55, 0.55, 0.55)

    -- Popup (grille 3x3), au-dessus du reste du menu.
    local pop = CreateFrame("Frame", nil, btn)
    pop:SetFrameStrata("FULLSCREEN_DIALOG"); pop:SetSize(60, 60)
    pop:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    Fill(pop, "BACKGROUND", BORDER):SetAllPoints()
    local body = Fill(pop, "BORDER", BG); body:SetPoint("TOPLEFT", 1, -1); body:SetPoint("BOTTOMRIGHT", -1, 1)
    pop:Hide()

    local cells = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local pos = ANCHOR_GRID[row][col]
            local cb = CreateFrame("Button", nil, pop)
            cb:SetSize(15, 15); cb:SetPoint("TOPLEFT", 5 + (col - 1) * 17, -(5 + (row - 1) * 17))
            Fill(cb, "BACKGROUND", BORDER):SetAllPoints()
            local dot = Fill(cb, "ARTWORK", ACCENT); dot:SetPoint("CENTER"); dot:SetSize(7, 7); dot:Hide()
            Fill(cb, "HIGHLIGHT", { 1, 1, 1 }, 0.15):SetAllPoints()
            cb.dot, cb.pos = dot, pos
            cb:SetScript("OnClick", function() set(pos); pop:Hide(); btn:Sync() end)
            cells[#cells + 1] = cb
        end
    end

    btn:SetScript("OnClick", function() pop:SetShown(not pop:IsShown()) end)
    function btn:Sync()
        local cur = get()
        txt:SetText(ANCHOR_LABELS[cur] or cur)
        for _, cb in ipairs(cells) do cb.dot:SetShown(cb.pos == cur) end
    end
    return btn
end

--------------------------------------------------------------------------------
-- Construction de la fenêtre
--------------------------------------------------------------------------------
function Options:Build()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "BravUIOptionsFrame", UIParent)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "BravUIOptionsFrame") -- Échap ferme la fenêtre

    -- Bordure (1px) + corps.
    Fill(f, "BACKGROUND", BORDER):SetAllPoints()
    local body = Fill(f, "BORDER", BG)
    body:SetPoint("TOPLEFT", 1, -1); body:SetPoint("BOTTOMRIGHT", -1, 1)

    -- En-tête (déplaçable) + ligne d'accent en bas.
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    Fill(header, "ARTWORK", HEADERC):SetAllPoints()
    local hline = Fill(header, "OVERLAY", ACCENT)
    hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT"); hline:SetHeight(1)

    local title = header:CreateFontString(nil, "OVERLAY")
    ApplyFont(title, 15); title:SetPoint("LEFT", PAD, 0)
    title:SetTextColor(0.90, 0.90, 0.90); title:SetText("BravUI")
    local sub = header:CreateFontString(nil, "OVERLAY")
    ApplyFont(sub, 12); sub:SetPoint("LEFT", title, "RIGHT", 6, -1)
    sub:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3]); sub:SetText("options")

    local close = CreateFrame("Button", nil, header)
    close:SetSize(26, 26); close:SetPoint("RIGHT", -6, 0)
    local cx = close:CreateFontString(nil, "OVERLAY")
    cx:SetFont(STANDARD_TEXT_FONT, 20, "")
    cx:SetAllPoints(); cx:SetJustifyH("CENTER"); cx:SetText("×")
    cx:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cx:SetTextColor(0.95, 0.95, 0.95) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(TXTDIM[1], TXTDIM[2], TXTDIM[3]) end)

    -- Barre latérale + séparateur vertical.
    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", 1, -(HEADER_H + 1))
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_W)
    Fill(sidebar, "ARTWORK", SIDEBAR):SetAllPoints()
    local sep = Fill(f, "OVERLAY", BORDER)
    sep:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    sep:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    sep:SetWidth(1)

    -- Zone de contenu (accueille les pages, l'une visible à la fois).
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
    content:SetPoint("BOTTOMRIGHT", -1, 1)

    self.header, self.sidebar, self.content = header, sidebar, content
    self.pages = {}
    self.controls = {}
    local function track(w) self.controls[#self.controls + 1] = w; return w end

    ----------------------------------------------------------------------------
    -- Système de pages (item de sidebar + panneau de contenu)
    ----------------------------------------------------------------------------
    local function newPage(label)
        local idx = #self.pages + 1

        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(SIDEBAR_W, 34); btn:SetPoint("TOPLEFT", 0, -(idx - 1) * 34)
        local sel = Fill(btn, "BACKGROUND", { 1, 1, 1 }, 0.06); sel:SetAllPoints(); sel:Hide()
        local accent = Fill(btn, "ARTWORK", ACCENT)
        accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2); accent:Hide()
        local hl = Fill(btn, "HIGHLIGHT", { 1, 1, 1 }, 0.04); hl:SetAllPoints()
        local t = btn:CreateFontString(nil, "OVERLAY")
        ApplyFont(t, 13); t:SetPoint("LEFT", 16, 0); t:SetText(label)

        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints(content)
        panel:Hide()

        btn:SetScript("OnClick", function() self:SelectPage(idx) end)
        self.pages[idx] = { panel = panel, sel = sel, accent = accent, text = t }
        return panel
    end

    -- Petit titre de section (gris atténué).
    local function sectionHeader(panel, text, x, y)
        local h = panel:CreateFontString(nil, "OVERLAY")
        ApplyFont(h, 12); h:SetTextColor(0.55, 0.55, 0.55)
        h:SetPoint("TOPLEFT", x, y); h:SetText(text)
        return h
    end

    ----------------------------------------------------------------------------
    -- Page « Général »
    ----------------------------------------------------------------------------
    local function buildGeneralPage(panel)
        track(CreateSlider(panel, "Échelle du menu", 0.7, 1.3, 0.05,
            function() return (ns.db.menu and ns.db.menu.scale) or 1 end,
            function(v) if ns.db.menu then ns.db.menu.scale = v end; Options:ApplyScale() end,
            {
                suffix   = "%",
                toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                fromText = function(str) local n = tonumber((str:gsub("%%", ""))); return n and n / 100 end,
            })
        ):SetPoint("TOPLEFT", PAD, -PAD - 6)
    end

    ----------------------------------------------------------------------------
    -- Page « Cadres d'unité » : onglets Joueur / Cible / Focus / ToT
    -- (contenu de chaque onglet ajouté à l'étape suivante)
    ----------------------------------------------------------------------------
    local UNIT_TABS = {
        { unit = "player",       label = "Joueur" },
        { unit = "target",       label = "Cible" },
        { unit = "focus",        label = "Focus" },
        { unit = "targettarget", label = "ToT" },
        { unit = "party",        label = "Groupe" }, -- cadres à venir (placeholder)
        { unit = "raid",         label = "Raid" },   -- cadres à venir (placeholder)
    }
    local function buildUnitsPage(panel)
        -- Barre d'onglets en haut + ligne de base.
        local bar = CreateFrame("Frame", nil, panel)
        bar:SetPoint("TOPLEFT", PAD, -PAD); bar:SetPoint("TOPRIGHT", -PAD, -PAD)
        bar:SetHeight(26)
        local base = Fill(bar, "ARTWORK", BORDER)
        base:SetPoint("BOTTOMLEFT"); base:SetPoint("BOTTOMRIGHT"); base:SetHeight(1)

        local tabs, subPanels = {}, {}
        local function selectUnit(i)
            for j, tb in ipairs(tabs) do
                local active = (i == j)
                tb.text:SetTextColor(active and 0.95 or 0.50, active and 0.95 or 0.50, active and 0.95 or 0.50)
                tb.accent:SetShown(active)
                subPanels[j]:SetShown(active)
            end
            panel.currentUnit = i
        end

        -- Contenu d'un onglet d'unité (en cours de construction, brique par brique).
        local function buildUnitContent(sp, unit)
            local function db() return ns.db.unitframes[unit] end

            -- Ligne 1 : case « Activer » + jauge « Taille globale » (côte à côte).
            -- La taille globale = échelle du cadre (vie + ressource + ressource de classe…).
            track(CreateToggle(sp, "Activer",
                function() return db().enabled end,
                function(v) UF():SetEnabled(unit, v) end)
            ):SetPoint("TOPLEFT", 2, -13)

            local size = track(CreateSlider(sp, "Taille globale", 0.5, 2.0, 0.05,
                function() return db().scale or 1 end,
                function(v) db().scale = v; UF():RefreshAll() end,
                {
                    suffix   = "%",
                    toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                    fromText = function(str) local n = tonumber((str:gsub("%%", ""))); return n and n / 100 end,
                }))
            -- Remplit le reste de la largeur (ancrée à gauche après la case et à droite).
            size:SetPoint("TOPLEFT", 110, -12)
            size:SetPoint("TOPRIGHT", 0, -12)

            -- Séparateur sous la 1re ligne.
            local sepLine = Fill(sp, "ARTWORK", BORDER)
            sepLine:SetPoint("TOPLEFT", 0, -39); sepLine:SetPoint("TOPRIGHT", 0, -39)
            sepLine:SetHeight(1)

            -- 2e niveau : sous-onglets de réglage ciblé + zone de contenu.
            -- « Classe » seulement si l'unité a RÉELLEMENT une ressource de classe (joueur
            -- d'une classe gérée) : pas d'onglet inerte pour guerrier, chasseur, etc.
            local SUB_TABS = { "Position", "Vie", "Ressource" }
            if db().classpower and UF():HasClassPower(unit) then SUB_TABS[#SUB_TABS + 1] = "Classe" end
            SUB_TABS[#SUB_TABS + 1] = "Incantation"
            local subBar = CreateFrame("Frame", nil, sp)
            subBar:SetPoint("TOPLEFT", 0, -49); subBar:SetPoint("TOPRIGHT", 0, -49)
            subBar:SetHeight(22)

            local subTabs, subContents = {}, {}
            local function selectSub(i)
                for j, stb in ipairs(subTabs) do
                    local active = (i == j)
                    stb.text:SetTextColor(active and 0.95 or 0.50, active and 0.95 or 0.50, active and 0.95 or 0.50)
                    stb.accent:SetShown(active)
                    subContents[j]:SetShown(active)
                end
            end

            -- Sous-onglet « Position » : X, Y (jauges pleine largeur) + Recentrer.
            local function buildPosition(c)
                local yy = -8
                local function slider(label, minV, maxV, get, set)
                    local s = track(CreateSlider(c, label, minV, maxV, 1, get, set))
                    s:SetPoint("TOPLEFT", 0, yy); s:SetPoint("TOPRIGHT", 0, yy)
                    yy = yy - 30
                end
                slider("Position X", -960, 960,
                    function() return db().x end,
                    function(v) db().x = v; UF():RefreshAll() end)
                slider("Position Y", -600, 600,
                    function() return db().y end,
                    function(v) db().y = v; UF():RefreshAll() end)

                -- Recentrer : lien discret à droite (réinitialise x/y aux défauts).
                local reset = CreateFrame("Button", nil, c)
                local rt = reset:CreateFontString(nil, "OVERLAY")
                ApplyFont(rt, 11); rt:SetPoint("RIGHT"); rt:SetText("Recentrer")
                rt:SetTextColor(0.55, 0.55, 0.55)
                reset:SetSize(rt:GetStringWidth() + 6, 16)
                reset:SetPoint("TOPRIGHT", 0, yy - 2)
                reset:SetScript("OnEnter", function() rt:SetTextColor(0.9, 0.9, 0.9) end)
                reset:SetScript("OnLeave", function() rt:SetTextColor(0.55, 0.55, 0.55) end)
                reset:SetScript("OnClick", function() UF():ResetPosition(unit); Options:Refresh() end)
            end

            -- Sous-onglet « Vie » : panneau de style de l'élément (modèle commun).
            local function buildLife(c)
                local yy = -8
                local pct = {
                    suffix   = "%",
                    toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                    fromText = function(s) local n = tonumber((s:gsub("%%", ""))); return n and n / 100 end,
                }
                local function slider(label, minV, maxV, step, get, set, opts)
                    local s = track(CreateSlider(c, label, minV, maxV, step, get, set, opts))
                    s:SetPoint("TOPLEFT", 0, yy); s:SetPoint("TOPRIGHT", 0, yy)
                    yy = yy - 30
                end
                local function toggleAt(x, label, get, set)
                    track(CreateToggle(c, label, get, set)):SetPoint("TOPLEFT", x, yy - 1)
                end
                local function H() return db().health end
                local function refresh(fn) return function(v) fn(v); UF():RefreshAll() end end

                -- Ligne 1 : Activer + Aperçu.
                toggleAt(2, "Activer",
                    function() return H().enabled ~= false end, refresh(function(v) H().enabled = v end))
                toggleAt(200, "Aperçu 50 %",
                    function() return UF():IsHealthPreview(unit) end,
                    function(v) UF():SetHealthPreview(unit, v) end)
                yy = yy - 26

                -- Ligne 2 : Afficher nom + lvl + ancre (déroulant).
                toggleAt(2, "Afficher nom",
                    function() return H().showName ~= false end, refresh(function(v) H().showName = v end))
                toggleAt(200, "Afficher lvl",
                    function() return H().showLevel ~= false end, refresh(function(v) H().showLevel = v end))
                track(CreateAnchorDropdown(c,
                    function() return H().namePos or "TOPLEFT" end,
                    refresh(function(v) H().namePos = v end))):SetPoint("TOPLEFT", 320, yy - 1)
                yy = yy - 26

                -- Ligne 3 : Afficher PV + % + ancre (déroulant).
                toggleAt(2, "Afficher PV",
                    function() return H().showHP ~= false end, refresh(function(v) H().showHP = v end))
                toggleAt(200, "Afficher %",
                    function() return H().showPct ~= false end, refresh(function(v) H().showPct = v end))
                track(CreateAnchorDropdown(c,
                    function() return H().valuePos or "BOTTOMRIGHT" end,
                    refresh(function(v) H().valuePos = v end))):SetPoint("TOPLEFT", 320, yy - 1)
                yy = yy - 26

                -- Ligne 3 : Bord arrondi + Inverser (sens de la barre de vie).
                toggleAt(2, "Bord arrondi",
                    function() return H().rounded ~= false end, refresh(function(v) H().rounded = v end))
                toggleAt(200, "Inverser",
                    function() return H().reverse == true end, refresh(function(v) H().reverse = v end))
                yy = yy - 26

                -- Ligne 4 : Échelle (pleine largeur).
                slider("Échelle", 0.5, 2.0, 0.05,
                    function() return H().scale or 1 end, refresh(function(v) H().scale = v end), pct)

                -- Ligne 5 : Position X + Y (demi-largeur). Plage = tout l'écran (moitié
                -- des dimensions de UIParent -> couvre du centre à chaque bord).
                -- Pos = offset de la BARRE DE VIE seule (par rapport au cadre). Le clic
                -- suit (hit rect). Plage symétrique large = moitié de l'écran + le
                -- débattement du cadre -> peut atteindre les 2 bords où qu'il soit.
                do
                    local rx = math.floor(UIParent:GetWidth() / 2 + 960)
                    local ry = math.floor(UIParent:GetHeight() / 2 + 600)
                    local sx = track(CreateSlider(c, "Pos X", -rx, rx, 1,
                        function() return H().x or 0 end, refresh(function(v) H().x = v end)))
                    sx:SetPoint("TOPLEFT", 0, yy); sx:SetWidth(225)
                    local sy = track(CreateSlider(c, "Pos Y", -ry, ry, 1,
                        function() return H().y or 0 end, refresh(function(v) H().y = v end)))
                    sy:SetPoint("TOPLEFT", 245, yy); sy:SetWidth(225)
                    yy = yy - 30
                end

                -- Taille : Largeur + Hauteur (demi-largeur).
                do
                    local sw = track(CreateSlider(c, "Largeur", 100, 400, 5,
                        function() return H().width end, refresh(function(v) H().width = v end)))
                    sw:SetPoint("TOPLEFT", 0, yy); sw:SetWidth(225)
                    local sh = track(CreateSlider(c, "Hauteur", 20, 120, 2,
                        function() return H().height end, refresh(function(v) H().height = v end)))
                    sh:SetPoint("TOPLEFT", 245, yy); sh:SetWidth(225)
                    yy = yy - 30
                end

                -- Opacité de fond (pleine largeur).
                slider("Opacité de fond", 0, 1, 0.05,
                    function() local a = H().bgAlpha; return a == nil and 0.5 or a end,
                    refresh(function(v) H().bgAlpha = v end), pct)
            end

            -- Sous-onglet « Ressource » : même modèle que Vie (sans nom/niveau, +Taille).
            local function buildPower(c)
                local yy = -8
                local pct = {
                    suffix   = "%",
                    toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                    fromText = function(s) local n = tonumber((s:gsub("%%", ""))); return n and n / 100 end,
                }
                local function slider(label, minV, maxV, step, get, set, opts)
                    local s = track(CreateSlider(c, label, minV, maxV, step, get, set, opts))
                    s:SetPoint("TOPLEFT", 0, yy); s:SetPoint("TOPRIGHT", 0, yy)
                    yy = yy - 30
                end
                local function toggleAt(x, label, get, set)
                    track(CreateToggle(c, label, get, set)):SetPoint("TOPLEFT", x, yy - 1)
                end
                local function P() return db().power end
                local function refresh(fn) return function(v) fn(v); UF():RefreshAll() end end

                -- L1 : Activer + Aperçu.
                toggleAt(2, "Activer",
                    function() return P().enabled ~= false end, refresh(function(v) P().enabled = v end))
                toggleAt(200, "Aperçu 50 %",
                    function() return UF():IsPowerPreview(unit) end,
                    function(v) UF():SetPowerPreview(unit, v) end)
                yy = yy - 26

                -- L2 : Afficher valeur + % + ancre.
                toggleAt(2, "Afficher valeur",
                    function() return P().showVal ~= false end, refresh(function(v) P().showVal = v end))
                toggleAt(200, "Afficher %",
                    function() return P().showPct ~= false end, refresh(function(v) P().showPct = v end))
                track(CreateAnchorDropdown(c,
                    function() return P().valuePos or "CENTER" end,
                    refresh(function(v) P().valuePos = v end))):SetPoint("TOPLEFT", 320, yy - 1)
                yy = yy - 26

                -- L3 : Bord arrondi + Inverser.
                toggleAt(2, "Bord arrondi",
                    function() return P().rounded ~= false end, refresh(function(v) P().rounded = v end))
                toggleAt(200, "Inverser",
                    function() return P().reverse == true end, refresh(function(v) P().reverse = v end))
                yy = yy - 26

                -- L4 : Échelle (pleine largeur).
                slider("Échelle", 0.5, 2.0, 0.05,
                    function() return P().scale or 1 end, refresh(function(v) P().scale = v end), pct)

                -- L5 : Position X + Y (demi-largeur).
                do
                    local rx = math.floor(UIParent:GetWidth() / 2 + 960)
                    local ry = math.floor(UIParent:GetHeight() / 2 + 600)
                    local sx = track(CreateSlider(c, "Pos X", -rx, rx, 1,
                        function() return P().x or 0 end, refresh(function(v) P().x = v end)))
                    sx:SetPoint("TOPLEFT", 0, yy); sx:SetWidth(225)
                    local sy = track(CreateSlider(c, "Pos Y", -ry, ry, 1,
                        function() return P().y or 0 end, refresh(function(v) P().y = v end)))
                    sy:SetPoint("TOPLEFT", 245, yy); sy:SetWidth(225)
                    yy = yy - 30
                end

                -- L6 : Taille : Largeur + Hauteur (demi-largeur).
                do
                    local sw = track(CreateSlider(c, "Largeur", 50, 400, 5,
                        function() return P().width end, refresh(function(v) P().width = v end)))
                    sw:SetPoint("TOPLEFT", 0, yy); sw:SetWidth(225)
                    local sh = track(CreateSlider(c, "Hauteur", 4, 60, 1,
                        function() return P().height end, refresh(function(v) P().height = v end)))
                    sh:SetPoint("TOPLEFT", 245, yy); sh:SetWidth(225)
                    yy = yy - 30
                end

                -- Opacité de fond (pleine largeur).
                slider("Opacité de fond", 0, 1, 0.05,
                    function() local a = P().bgAlpha; return a == nil and 0.5 or a end,
                    refresh(function(v) P().bgAlpha = v end), pct)
            end

            -- Sous-onglet « Classe » : ressource de classe (barre segmentée, pas de texte).
            local function buildClass(c)
                local yy = -8
                local pct = {
                    suffix   = "%",
                    toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                    fromText = function(s) local n = tonumber((s:gsub("%%", ""))); return n and n / 100 end,
                }
                local function slider(label, minV, maxV, step, get, set, opts)
                    local s = track(CreateSlider(c, label, minV, maxV, step, get, set, opts))
                    s:SetPoint("TOPLEFT", 0, yy); s:SetPoint("TOPRIGHT", 0, yy)
                    yy = yy - 30
                end
                local function toggleAt(x, label, get, set)
                    track(CreateToggle(c, label, get, set)):SetPoint("TOPLEFT", x, yy - 1)
                end
                local function CP() return db().classpower end
                local function refresh(fn) return function(v) fn(v); UF():RefreshAll() end end

                -- L1 : Activer + Aperçu.
                toggleAt(2, "Activer",
                    function() return CP().enabled ~= false end, refresh(function(v) CP().enabled = v end))
                toggleAt(200, "Aperçu 50 %",
                    function() return UF():IsClassPowerPreview(unit) end,
                    function(v) UF():SetClassPowerPreview(unit, v) end)
                yy = yy - 26

                -- L2 : Bord arrondi + Inverser.
                toggleAt(2, "Bord arrondi",
                    function() return CP().rounded ~= false end, refresh(function(v) CP().rounded = v end))
                toggleAt(200, "Inverser",
                    function() return CP().reverse == true end, refresh(function(v) CP().reverse = v end))
                yy = yy - 26

                -- L3 : Échelle (pleine largeur).
                slider("Échelle", 0.5, 2.0, 0.05,
                    function() return CP().scale or 1 end, refresh(function(v) CP().scale = v end), pct)

                -- L4 : Position X + Y (demi-largeur).
                do
                    local rx = math.floor(UIParent:GetWidth() / 2 + 960)
                    local ry = math.floor(UIParent:GetHeight() / 2 + 600)
                    local sx = track(CreateSlider(c, "Pos X", -rx, rx, 1,
                        function() return CP().x or 0 end, refresh(function(v) CP().x = v end)))
                    sx:SetPoint("TOPLEFT", 0, yy); sx:SetWidth(225)
                    local sy = track(CreateSlider(c, "Pos Y", -ry, ry, 1,
                        function() return CP().y or 0 end, refresh(function(v) CP().y = v end)))
                    sy:SetPoint("TOPLEFT", 245, yy); sy:SetWidth(225)
                    yy = yy - 30
                end

                -- L5 : Taille : Largeur + Hauteur (demi-largeur).
                do
                    local sw = track(CreateSlider(c, "Largeur", 50, 400, 5,
                        function() return CP().width end, refresh(function(v) CP().width = v end)))
                    sw:SetPoint("TOPLEFT", 0, yy); sw:SetWidth(225)
                    local sh = track(CreateSlider(c, "Hauteur", 4, 40, 1,
                        function() return CP().height end, refresh(function(v) CP().height = v end)))
                    sh:SetPoint("TOPLEFT", 245, yy); sh:SetWidth(225)
                    yy = yy - 30
                end

                -- Opacité de fond (pleine largeur).
                slider("Opacité de fond", 0, 1, 0.05,
                    function() local a = CP().bgAlpha; return a == nil and 0.5 or a end,
                    refresh(function(v) CP().bgAlpha = v end), pct)
            end

            -- Sous-onglet « Incantation » : castbar (icône + nom + timer).
            local function buildCast(c)
                local yy = -8
                local pct = {
                    suffix   = "%",
                    toText   = function(v) return tostring(math.floor(v * 100 + 0.5)) end,
                    fromText = function(s) local n = tonumber((s:gsub("%%", ""))); return n and n / 100 end,
                }
                local function slider(label, minV, maxV, step, get, set, opts)
                    local s = track(CreateSlider(c, label, minV, maxV, step, get, set, opts))
                    s:SetPoint("TOPLEFT", 0, yy); s:SetPoint("TOPRIGHT", 0, yy)
                    yy = yy - 30
                end
                local function toggleAt(x, label, get, set)
                    track(CreateToggle(c, label, get, set)):SetPoint("TOPLEFT", x, yy - 1)
                end
                local function CB() return db().castbar end
                local function refresh(fn) return function(v) fn(v); UF():RefreshAll() end end

                -- L1 : Activer + Aperçu.
                toggleAt(2, "Activer",
                    function() return CB().enabled ~= false end, refresh(function(v) CB().enabled = v end))
                toggleAt(200, "Aperçu",
                    function() return UF():IsCastbarPreview(unit) end,
                    function(v) UF():SetCastbarPreview(unit, v) end)
                yy = yy - 26

                -- L2 : Icône (sous Activer) + Nom (sous Aperçu) + Timer (à côté).
                toggleAt(2, "Icône",
                    function() return CB().showIcon ~= false end, refresh(function(v) CB().showIcon = v end))
                toggleAt(200, "Nom",
                    function() return CB().showName ~= false end, refresh(function(v) CB().showName = v end))
                toggleAt(320, "Timer",
                    function() return CB().showTimer ~= false end, refresh(function(v) CB().showTimer = v end))
                yy = yy - 26

                -- L3 : Bord arrondi + Inverser.
                toggleAt(2, "Bord arrondi",
                    function() return CB().rounded ~= false end, refresh(function(v) CB().rounded = v end))
                toggleAt(200, "Inverser",
                    function() return CB().reverse == true end, refresh(function(v) CB().reverse = v end))
                yy = yy - 26

                -- L4 : Échelle (pleine largeur).
                slider("Échelle", 0.5, 2.0, 0.05,
                    function() return CB().scale or 1 end, refresh(function(v) CB().scale = v end), pct)

                -- L5 : Position X + Y (demi-largeur).
                do
                    local rx = math.floor(UIParent:GetWidth() / 2 + 960)
                    local ry = math.floor(UIParent:GetHeight() / 2 + 600)
                    local sx = track(CreateSlider(c, "Pos X", -rx, rx, 1,
                        function() return CB().x or 0 end, refresh(function(v) CB().x = v end)))
                    sx:SetPoint("TOPLEFT", 0, yy); sx:SetWidth(225)
                    local sy = track(CreateSlider(c, "Pos Y", -ry, ry, 1,
                        function() return CB().y or 0 end, refresh(function(v) CB().y = v end)))
                    sy:SetPoint("TOPLEFT", 245, yy); sy:SetWidth(225)
                    yy = yy - 30
                end

                -- L6 : Taille : Largeur + Hauteur (demi-largeur).
                do
                    local sw = track(CreateSlider(c, "Largeur", 50, 400, 5,
                        function() return CB().width end, refresh(function(v) CB().width = v end)))
                    sw:SetPoint("TOPLEFT", 0, yy); sw:SetWidth(225)
                    local sh = track(CreateSlider(c, "Hauteur", 8, 40, 1,
                        function() return CB().height end, refresh(function(v) CB().height = v end)))
                    sh:SetPoint("TOPLEFT", 245, yy); sh:SetWidth(225)
                    yy = yy - 30
                end

                -- Opacité de fond (pleine largeur).
                slider("Opacité de fond", 0, 1, 0.05,
                    function() local a = CB().bgAlpha; return a == nil and 0.5 or a end,
                    refresh(function(v) CB().bgAlpha = v end), pct)
            end

            local sx = 0
            for i, lbl in ipairs(SUB_TABS) do
                local stb = CreateFrame("Button", nil, subBar)
                stb:SetHeight(22)
                local txt = stb:CreateFontString(nil, "OVERLAY")
                ApplyFont(txt, 11); txt:SetPoint("CENTER"); txt:SetText(lbl)
                stb:SetWidth(math.max(22, txt:GetStringWidth() + 12))
                stb:SetPoint("LEFT", sx, 0)
                local acc = Fill(stb, "OVERLAY", ACCENT)
                acc:SetPoint("BOTTOMLEFT"); acc:SetPoint("BOTTOMRIGHT"); acc:SetHeight(2); acc:Hide()
                stb.text, stb.accent = txt, acc
                stb:SetScript("OnClick", function() selectSub(i) end)
                subTabs[i] = stb
                sx = sx + stb:GetWidth() + 6

                -- Contenu du sous-onglet (placeholder pour l'instant).
                local c = CreateFrame("Frame", nil, sp)
                c:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -12)
                c:SetPoint("BOTTOMRIGHT", sp, "BOTTOMRIGHT", 0, 0)
                c:Hide()
                if lbl == "Position" then
                    buildPosition(c)
                elseif lbl == "Vie" then
                    buildLife(c)
                elseif lbl == "Ressource" then
                    buildPower(c)
                elseif lbl == "Classe" then
                    buildClass(c)
                elseif lbl == "Incantation" then
                    buildCast(c)
                else
                    local ph = c:CreateFontString(nil, "OVERLAY")
                    ApplyFont(ph, 12); ph:SetTextColor(0.38, 0.38, 0.38)
                    ph:SetPoint("TOP", 0, -20); ph:SetText(lbl .. " — à remplir")
                end
                subContents[i] = c
            end
            selectSub(1)
        end

        local x = 0
        for i, tabInfo in ipairs(UNIT_TABS) do
            local tb = CreateFrame("Button", nil, bar)
            tb:SetHeight(26)
            local txt = tb:CreateFontString(nil, "OVERLAY")
            ApplyFont(txt, 12); txt:SetPoint("CENTER"); txt:SetText(tabInfo.label)
            tb:SetWidth(math.max(28, txt:GetStringWidth() + 16)) -- largeur = texte -> onglets compacts
            tb:SetPoint("LEFT", x, 0)
            local acc = Fill(tb, "OVERLAY", ACCENT)
            acc:SetPoint("BOTTOMLEFT"); acc:SetPoint("BOTTOMRIGHT"); acc:SetHeight(2); acc:Hide()
            tb.text, tb.accent = txt, acc
            tb:SetScript("OnClick", function() selectUnit(i) end)
            tabs[i] = tb
            x = x + tb:GetWidth() + 4

            -- Sous-panneau de l'onglet (vide : placeholder discret pour l'instant).
            local sp = CreateFrame("Frame", nil, panel)
            sp:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
            sp:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)
            sp:Hide()
            -- Unités « réelles » (cadres existants) -> panneau complet ; Groupe/Raid
            -- (cadres pas encore créés) -> placeholder.
            if ns.db.unitframes[tabInfo.unit] then
                buildUnitContent(sp, tabInfo.unit)
            else
                local ph = sp:CreateFontString(nil, "OVERLAY")
                ApplyFont(ph, 13); ph:SetTextColor(0.38, 0.38, 0.38)
                ph:SetPoint("TOP", 0, -30); ph:SetText(tabInfo.label .. " — réglages à venir")
            end
            sp.unit = tabInfo.unit
            subPanels[i] = sp
        end
        panel.subPanels = subPanels
        selectUnit(1)
    end

    buildGeneralPage(newPage("Général"))
    buildUnitsPage(newPage("Cadres d'unité"))

    self:SelectPage(1)
    -- À la fermeture : couper l'aperçu de vie (état transitoire) -> vraies valeurs.
    f:SetScript("OnHide", function()
        local m = UF(); if m then m:ClearPreviews() end
    end)

    f:Hide() -- CreateFrame crée une frame VISIBLE : on la masque (sinon 2 clics).
    self.frame = f
    return f
end

--------------------------------------------------------------------------------
-- Sélection de page / rafraîchissement / échelle
--------------------------------------------------------------------------------
function Options:SelectPage(idx)
    if not self.pages then return end
    for i, p in ipairs(self.pages) do
        local active = (i == idx)
        p.panel:SetShown(active)
        p.sel:SetShown(active)
        p.accent:SetShown(active)
        p.text:SetTextColor(active and 0.95 or 0.55, active and 0.95 or 0.55, active and 0.95 or 0.55)
    end
    self.currentPage = idx
end

function Options:Refresh()
    if not self.controls then return end
    for _, w in ipairs(self.controls) do w:Sync() end
end

function Options:ApplyScale()
    if not self.frame then return end
    self.frame:SetScale((ns.db and ns.db.menu and ns.db.menu.scale) or 1)
end

--------------------------------------------------------------------------------
-- Ouverture / fermeture
--------------------------------------------------------------------------------
function Options:Toggle()
    local f = self:Build()
    if f:IsShown() then
        f:Hide()
    else
        self:ApplyScale()
        self:Refresh()
        f:Show()
    end
end

--------------------------------------------------------------------------------
-- Bouton BravUI INTÉGRÉ au menu Échap (GameMenuFrame)
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

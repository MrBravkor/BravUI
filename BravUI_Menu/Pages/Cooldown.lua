-- BravUI_Menu/Pages/Cooldown.lua
-- Configuration Cooldown — onglets + sous-onglets (pattern UnitFrames)

local M = BravUI.Menu
local L = M.L
local T = M.Theme

-- ============================================================================
-- HELPERS
-- ============================================================================

local _recycler = CreateFrame("Frame")
_recycler:Hide()

local function ClearHost(host)
    for _, child in ipairs({ host:GetChildren() }) do
        child:Hide()
        child:ClearAllPoints()
        child:SetParent(_recycler)
    end
end

local function LiveApply(tabKey)
    if tabKey == "essential" or tabKey == "utility" or tabKey == "buffIcon" or tabKey == "buffBar" then
        BravLib.Hooks.Fire("APPLY_COOLDOWN_CDM")
    elseif tabKey == "resource" then
        BravLib.Hooks.Fire("APPLY_COOLDOWN_RESOURCE")
    elseif tabKey == "classpower" then
        BravLib.Hooks.Fire("APPLY_COOLDOWN_CLASSPOWER")
    elseif tabKey == "castbar" then
        BravLib.Hooks.Fire("APPLY_COOLDOWN_CASTBAR")
    end
end

-- ============================================================================
-- TABS DEFINITION
-- ============================================================================

local TABS = {
    { key = "essential", label = L["cd_tab_essential"] or "Essentiels" },
    { key = "utility",   label = L["cd_tab_utility"]   or "Utilitaires" },
    { key = "buffIcon",  label = L["cd_tab_bufficon"]  or "Buffs Icônes" },
    { key = "buffBar",   label = L["cd_tab_buffbar"]   or "Buffs Barres" },
    { key = "resource",  label = L["cd_tab_resource"]  or "Ressource" },
    { key = "classpower", label = L["cd_tab_classpower"] or "Puissance" },
    { key = "castbar",   label = L["cd_tab_castbar"]   or "Incantation" },
}

-- ============================================================================
-- OPTIONS DATA
-- ============================================================================

local ORIENTATIONS = {
    { text = L["cd_orient_h"] or "Horizontale", value = "HORIZONTAL" },
    { text = L["cd_orient_v"] or "Verticale",   value = "VERTICAL" },
}

local DIRECTIONS = {
    { text = L["cd_dir_right"] or "Droite", value = "RIGHT" },
    { text = L["cd_dir_left"]  or "Gauche", value = "LEFT" },
}

local VISIBILITY = {
    { text = L["cd_vis_always"]    or "Toujours visible",  value = "ALWAYS" },
    { text = L["cd_vis_combat"]    or "En combat",         value = "COMBAT" },
    { text = L["cd_vis_outcombat"] or "Hors combat",       value = "OUTOFCOMBAT" },
}

local TEXT_FORMATS = {
    { text = L["cd_fmt_value_only"] or "Valeur",       value = "value_only" },
    { text = L["cd_fmt_value"]      or "Valeur / Max", value = "value" },
}

local ANCHOR_POINTS = {
    { text = L["cd_anchor_top"]    or "Au-dessus",  value = "TOP" },
    { text = L["cd_anchor_bottom"] or "En-dessous", value = "BOTTOM" },
}

-- ============================================================================
-- BUILD SPECS PER TAB
-- ============================================================================

local function BuildViewerSpecs(viewerKey)
    local KEY = "cooldown.cdm." .. viewerKey

    return {
        { type = "group", label = L["cd_grp_layout"] or "Disposition", children = {
            { type = "dropdown", db = KEY .. ".orientation",   label = L["cd_orientation"] or "Orientation",            values = ORIENTATIONS },
            { type = "slider",   db = KEY .. ".maxColumns",    label = L["cd_max_columns"] or "Nombre de colonnes",    min = 1, max = 12, step = 1 },
            { type = "dropdown", db = KEY .. ".iconDirection",  label = L["cd_icon_dir"] or "Direction des icônes",     values = DIRECTIONS },
            { type = "slider",   db = KEY .. ".iconSize",      label = L["cd_icon_size"] or "Taille des icônes",       min = 16, max = 64, step = 1 },
            { type = "slider",   db = KEY .. ".iconSpacing",   label = L["cd_icon_spacing"] or "Espacement des icônes", min = 0, max = 20, step = 1 },
        }},
        { type = "group", label = L["cd_grp_display"] or "Affichage", children = {
            { type = "slider",   db = KEY .. ".opacity",       label = L["cd_opacity"] or "Opacité",                    min = 0, max = 1, step = 0.01 },
            { type = "dropdown", db = KEY .. ".visibility",    label = L["cd_visibility"] or "Visibilité",              values = VISIBILITY },
            { type = "toggle",   db = KEY .. ".showTimer",     label = L["cd_show_timer"] or "Afficher le chronomètre" },
            { type = "toggle",   db = KEY .. ".showTooltips",  label = L["cd_show_tooltips"] or "Afficher les bulles d'aide" },
        }},
    }
end

local function BuildResourceSpecs()
    local KEY = "cooldown.primary"

    return {
        { type = "group", label = L["cd_grp_general"] or "Général", children = {
            { type = "toggle", db = KEY .. ".enabled", label = L["cd_enable_resource"] or "Activer la Ressource" },
        }},
        { type = "group", label = L["cd_grp_positions"] or "Positions", children = {
            -- Ancrage
            { type = "button_select", db = KEY .. ".anchorToViewer", label = L["cd_anchor_mode"] or "Ancrage", values = {
                { text = L["cd_anchor_free"] or "Ancrage libre", value = false },
                { text = (L["cd_anchor_cdm"] or "Ancrage CDM") .. " |cff666666(en dev)|r", value = true, disabled = true },
            }},
            { type = "separator" },
            -- Taille + position
            { type = "slider", db = KEY .. ".width",  label = L["cd_width"] or "Largeur",   min = 80, max = 500, step = 5 },
            { type = "slider", db = KEY .. ".height", label = L["cd_height"] or "Hauteur",  min = 4, max = 30, step = 1 },
            { type = "slider", db = "positions.Barre Ressource.x", label = L["cd_pos_x"] or "Position X", min = -800, max = 800, step = 1 },
            { type = "slider", db = "positions.Barre Ressource.y", label = L["cd_pos_y"] or "Position Y", min = -600, max = 600, step = 1 },
        }},
        { type = "group", label = L["cd_grp_color"] or "Couleur", children = {
            { type = "button_select", db = KEY .. ".colorMode", label = L["cd_color_mode"] or "Mode de couleur", values = {
                { text = L["cd_use_power_color"] or "Ressource", value = "power" },
                { text = L["cd_use_class_color"] or "Classe",    value = "class" },
                { text = L["cd_bar_color"]       or "Personnalisée", value = "custom" },
            }},
            { type = "color", db = KEY .. ".barColor", label = L["cd_bar_color_pick"] or "Couleur personnalisée",
              hidden = function(db) local p = db.cooldown and db.cooldown.primary; return not p or p.colorMode ~= "custom" end },
        }},
        { type = "group", label = L["cd_grp_background"] or "Fond", children = {
            { type = "toggle", db = KEY .. ".showBackground", label = L["cd_show_bg"] or "Activer le fond" },
            { type = "slider", db = KEY .. ".bgAlpha", label = L["cd_bg_alpha"] or "Opacité du fond", min = 0, max = 1, step = 0.05, decimals = 2,
              hidden = function(db) local p = db.cooldown and db.cooldown.primary; return p and not p.showBackground end },
            { type = "color",  db = KEY .. ".bgColor", label = L["cd_bg_color"] or "Couleur du fond",
              hidden = function(db) local p = db.cooldown and db.cooldown.primary; return p and not p.showBackground end },
        }},
        { type = "group", label = L["cd_grp_text"] or "Texte", children = {
            { type = "toggle",      db = KEY .. ".showText",       label = L["cd_show_text"] or "Afficher le texte" },
            { type = "dropdown",    db = KEY .. ".textFormat",     label = L["cd_text_format"] or "Format", values = TEXT_FORMATS },
            { type = "anchor_grid", db = KEY .. ".textAnchor",     label = L["cd_text_anchor"] or "Ancrage du texte" },
            { type = "slider",      db = KEY .. ".fontSize",       label = L["cd_font_size"] or "Taille police", min = 6, max = 18, step = 1 },
            { type = "color",       db = KEY .. ".centerTextColor", label = L["cd_text_color"] or "Couleur texte" },
        }},
    }
end

local function BuildClassPowerSpecs()
    local KEY = "cooldown.secondary"

    return {
        { type = "group", label = L["cd_grp_general"] or "Général", children = {
            { type = "toggle", db = KEY .. ".enabled", label = L["cd_enable"] or "Activer" },
        }},
        { type = "group", label = L["cd_grp_positions"] or "Positions", children = {
            -- Ancrage
            { type = "button_select", db = KEY .. ".anchorToViewer", label = L["cd_anchor_mode"] or "Ancrage", values = {
                { text = L["cd_anchor_free"] or "Ancrage libre", value = false },
                { text = (L["cd_anchor_cdm"] or "Ancrage CDM") .. " |cff666666(en dev)|r", value = true, disabled = true },
            }},
            { type = "separator" },
            -- Taille + position
            { type = "slider", db = KEY .. ".width",      label = L["cd_width"] or "Largeur",           min = 80, max = 500, step = 5 },
            { type = "slider", db = KEY .. ".height",     label = L["cd_height"] or "Hauteur segments",  min = 4, max = 30, step = 1 },
            { type = "slider", db = KEY .. ".segmentGap", label = L["cd_cp_gap"] or "Écart segments",    min = 0, max = 10, step = 1 },
            { type = "slider", db = "positions.Puissance Classe.x", label = L["cd_pos_x"] or "Position X", min = -800, max = 800, step = 1 },
            { type = "slider", db = "positions.Puissance Classe.y", label = L["cd_pos_y"] or "Position Y", min = -600, max = 600, step = 1 },
        }},
        { type = "group", label = L["cd_grp_color"] or "Couleur", children = {
            { type = "button_select", db = KEY .. ".colorMode", label = L["cd_color_mode"] or "Mode de couleur", values = {
                { text = L["cd_use_power_color"] or "Ressource", value = "power" },
                { text = L["cd_use_class_color"] or "Classe",    value = "class" },
                { text = L["cd_bar_color"]       or "Personnalisée", value = "custom" },
            }},
            { type = "color", db = KEY .. ".barColor", label = L["cd_bar_color_pick"] or "Couleur personnalisée",
              hidden = function(db) local s = db.cooldown and db.cooldown.secondary; return not s or s.colorMode ~= "custom" end },
        }},
        { type = "group", label = L["cd_grp_background"] or "Fond", children = {
            { type = "toggle", db = KEY .. ".showBackground", label = L["cd_show_bg"] or "Activer le fond" },
            { type = "slider", db = KEY .. ".bgAlpha", label = L["cd_bg_alpha"] or "Opacité du fond", min = 0, max = 1, step = 0.05, decimals = 2,
              hidden = function(db) local s = db.cooldown and db.cooldown.secondary; return s and not s.showBackground end },
            { type = "color",  db = KEY .. ".bgColor", label = L["cd_bg_color"] or "Couleur du fond",
              hidden = function(db) local s = db.cooldown and db.cooldown.secondary; return s and not s.showBackground end },
        }},
    }
end

local function BuildCastBarSpecs()
    local KEY = "cooldown.castbar"

    return {
        { type = "group", label = L["cd_grp_general"] or "Général", children = {
            { type = "toggle", db = KEY .. ".enabled",  label = L["cd_enable"] or "Activer" },
            { type = "toggle", db = KEY .. ".showIcon", label = L["cd_show_icon"] or "Afficher l'icône" },
            { type = "button", label = L["cd_preview"] or "Aperçu", onClick = function(btn)
                local NS = BravUI and BravUI.Cooldown
                if not NS or not NS.SetCastBarPreview then return end
                local newState = not NS.IsCastBarPreview()
                NS.SetCastBarPreview(newState)
                local text = newState and (L["cd_preview_hide"] or "Masquer l'aperçu") or (L["cd_preview"] or "Aperçu")
                for _, region in ipairs({ btn:GetRegions() }) do
                    if region.SetText then region:SetText(text); break end
                end
            end },
        }},
        { type = "group", label = L["cd_grp_positions"] or "Positions", children = {
            -- Ancrage
            { type = "button_select", db = KEY .. ".anchorToViewer", label = L["cd_anchor_mode"] or "Ancrage", values = {
                { text = L["cd_anchor_free"] or "Ancrage libre", value = false },
                { text = (L["cd_anchor_cdm"] or "Ancrage CDM") .. " |cff666666(en dev)|r", value = true, disabled = true },
            }},
            { type = "separator" },
            -- Taille + position
            { type = "slider", db = KEY .. ".width",  label = L["cd_width"] or "Largeur",  min = 80, max = 500, step = 5 },
            { type = "slider", db = KEY .. ".height", label = L["cd_height"] or "Hauteur", min = 4, max = 30, step = 1 },
            { type = "slider", db = "positions.Barre Incantation.x", label = L["cd_pos_x"] or "Position X", min = -800, max = 800, step = 1 },
            { type = "slider", db = "positions.Barre Incantation.y", label = L["cd_pos_y"] or "Position Y", min = -600, max = 600, step = 1 },
        }},
        { type = "group", label = L["cd_grp_color"] or "Couleur", children = {
            { type = "color", db = KEY .. ".colorNormal",    label = L["cd_color_normal"] or "Couleur normale" },
            { type = "color", db = KEY .. ".colorInterrupt", label = L["cd_color_interrupt"] or "Couleur non-interruptible" },
        }},
        { type = "group", label = L["cd_grp_background"] or "Fond", children = {
            { type = "toggle", db = KEY .. ".showBackground", label = L["cd_show_bg"] or "Activer le fond" },
            { type = "slider", db = KEY .. ".bgAlpha", label = L["cd_bg_alpha"] or "Opacité du fond", min = 0, max = 1, step = 0.05, decimals = 2,
              hidden = function(db) local c = db.cooldown and db.cooldown.castbar; return c and not c.showBackground end },
            { type = "color",  db = KEY .. ".bgColor", label = L["cd_bg_color"] or "Couleur du fond",
              hidden = function(db) local c = db.cooldown and db.cooldown.castbar; return c and not c.showBackground end },
        }},
        { type = "group", label = L["cd_grp_text"] or "Texte", children = {
            { type = "toggle",  db = KEY .. ".showSpellName",  label = L["cd_show_spell_name"] or "Afficher le nom du sort" },
            { type = "toggle",  db = KEY .. ".showTimer",      label = L["cd_show_timer"] or "Afficher le temps" },
            { type = "slider",  db = KEY .. ".fontSize",       label = L["cd_font_size"] or "Taille police", min = 6, max = 18, step = 1 },
            { type = "color",   db = KEY .. ".textColor",      label = L["cd_text_color"] or "Couleur texte" },
        }},
    }
end

local function BuildSpecs(tabKey)
    if tabKey == "essential" then return BuildViewerSpecs("essential") end
    if tabKey == "utility"   then return BuildViewerSpecs("utility") end
    if tabKey == "buffIcon"  then return BuildViewerSpecs("buffIcon") end
    if tabKey == "buffBar"   then return BuildViewerSpecs("buffBar") end
    if tabKey == "resource"  then return BuildResourceSpecs() end
    if tabKey == "classpower" then return BuildClassPowerSpecs() end
    if tabKey == "castbar"   then return BuildCastBarSpecs() end
    return {}
end

-- ============================================================================
-- SPLIT SPECS INTO SETTINGS TABS
-- ============================================================================

local function SplitSpecsIntoTabs(specs)
    local general = {}
    local tabs = {}

    for _, spec in ipairs(specs) do
        if spec.type == "group" then
            tabs[#tabs + 1] = {
                key   = spec.label,
                label = spec.label,
                specs = spec.children or {},
            }
        else
            general[#general + 1] = spec
        end
    end

    if #general > 0 then
        table.insert(tabs, 1, { key = "_general", label = L["cd_grp_general"] or "Général", specs = general })
    end
    return tabs
end

-- ============================================================================
-- PAGE
-- ============================================================================

M:RegisterPage("cooldown", 15, L["page_cooldown"] or "Cooldown", function(container, add)
    local PAD   = T.PAD
    local TAB_H = 26

    -- ── Tab button factory ──
    local function CreateTabBtn(parent, text, fontSize)
        local btn = CreateFrame("Button", nil, parent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        btn:SetHeight(TAB_H)
        btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })

        local label = btn:CreateFontString(nil, "OVERLAY")
        M:SafeFont(label, fontSize or 10, "OUTLINE")
        label:SetPoint("CENTER", 0, 0)
        label:SetText(text)
        btn._label = label

        local textW = label:GetStringWidth() or 0
        if textW < 5 then textW = #text * 7 end
        btn:SetWidth(math.max(textW + 16, 42))

        function btn:SetActive(isActive)
            local r, g, b = M:GetClassColor()
            if isActive then
                self:SetBackdropColor(r * 0.15, g * 0.15, b * 0.15, 0.90)
                self:SetBackdropBorderColor(r, g, b, 0.60)
                self._label:SetTextColor(r, g, b, 1)
            else
                self:SetBackdropColor(unpack(T.BTN))
                self:SetBackdropBorderColor(unpack(T.BORDER))
                self._label:SetTextColor(unpack(T.TEXT))
            end
        end

        return btn
    end

    -- ── Toggle général ──
    local toggleHost = CreateFrame("Frame", nil, container)
    toggleHost:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, -PAD)
    toggleHost:SetPoint("TOPRIGHT", container, "TOPRIGHT", -PAD, -PAD)
    local toggleH, toggleWidgets = M:BuildOptions(toggleHost, {
        { type = "toggle", db = "cooldown.enabled", label = L["cd_enable_module"] or "Activer le module Cooldown" },
    }, function() LiveApply("essential") end)
    toggleHost:SetHeight(math.max(toggleH, 1))

    -- ── Rangée 1 : onglets principaux ──
    local unitBar = CreateFrame("Frame", nil, container)
    unitBar:SetPoint("TOPLEFT", toggleHost, "BOTTOMLEFT", 0, -8)
    unitBar:SetPoint("TOPRIGHT", toggleHost, "BOTTOMRIGHT", 0, -8)
    unitBar:SetHeight(TAB_H)

    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", unitBar, "BOTTOMLEFT", 0, -4)
    sep:SetPoint("TOPRIGHT", unitBar, "BOTTOMRIGHT", 0, -4)
    sep:SetHeight(1)
    local r, g, b = M:GetClassColor()
    sep:SetColorTexture(r, g, b, 0.35)

    -- ── Rangée 2 : sous-onglets ──
    local settingsBar = CreateFrame("Frame", nil, container)
    settingsBar:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)
    settingsBar:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -4)
    settingsBar:SetHeight(TAB_H)

    local host = CreateFrame("Frame", nil, container)
    host:SetPoint("TOPLEFT", settingsBar, "BOTTOMLEFT", 0, -8)
    host:SetPoint("TOPRIGHT", settingsBar, "BOTTOMRIGHT", 0, -8)
    add(host)

    local activeTab      = "essential"
    local activeSettings = "_general"
    local unitBtns       = {}
    local settingsBtns   = {}
    local settingsTabs   = {}
    local currentWidgets

    local function UpdateHeight()
        local h = PAD + toggleH + 8 + TAB_H + 4 + 1 + 4 + TAB_H + 8 + host:GetHeight() + PAD
        container:SetHeight(h)
        local scrollChild = container:GetParent()
        if scrollChild and scrollChild.SetHeight then scrollChild:SetHeight(h) end
    end

    local function DoRefresh()
        if not currentWidgets then return end
        pcall(M.RefreshLayout, M, host, currentWidgets)
        pcall(UpdateHeight)
        LiveApply(activeTab)
    end

    local function BuildSettingsContent()
        ClearHost(host)
        if M._flyout and M._flyout:IsShown() then M._flyout:Hide() end

        local specs = {}
        for _, st in ipairs(settingsTabs) do
            if st.key == activeSettings then specs = st.specs; break end
        end

        local totalH
        totalH, currentWidgets = M:BuildOptions(host, specs, DoRefresh)
        host:SetHeight(math.max(totalH, 1))
        UpdateHeight()
    end

    local function BuildSettingsTabBtns()
        for _, btn in ipairs(settingsBtns) do
            btn:Hide()
            btn:ClearAllPoints()
            btn:SetParent(_recycler)
        end
        wipe(settingsBtns)

        -- Disable castbar preview when leaving the tab
        if activeTab ~= "castbar" then
            local NS = BravUI and BravUI.Cooldown
            if NS and NS.IsCastBarPreview and NS.IsCastBarPreview() then
                NS.SetCastBarPreview(false)
            end
        end

        local allSpecs = BuildSpecs(activeTab)
        settingsTabs   = SplitSpecsIntoTabs(allSpecs)
        activeSettings = settingsTabs[1] and settingsTabs[1].key or "_general"

        local btnX = 0
        for _, st in ipairs(settingsTabs) do
            local btn = CreateTabBtn(settingsBar, st.label, 9)
            btn._stKey = st.key

            btn:SetScript("OnEnter", function(self)
                if activeSettings ~= self._stKey then
                    self:SetBackdropColor(unpack(T.BTN_HOVER))
                    self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
                end
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetActive(activeSettings == self._stKey)
            end)
            btn:SetScript("OnClick", function(self)
                activeSettings = self._stKey
                for _, b2 in ipairs(settingsBtns) do b2:SetActive(b2._stKey == activeSettings) end
                BuildSettingsContent()
            end)

            btn:SetPoint("TOPLEFT", settingsBar, "TOPLEFT", btnX, 0)
            btnX = btnX + btn:GetWidth() + 2
            settingsBtns[#settingsBtns + 1] = btn
        end

        for _, b2 in ipairs(settingsBtns) do b2:SetActive(b2._stKey == activeSettings) end
        BuildSettingsContent()
    end

    -- ── Boutons principaux ──
    local btnX = 0
    for _, tab in ipairs(TABS) do
        local btn = CreateTabBtn(unitBar, tab.label, 10)
        btn._key = tab.key

        btn:SetScript("OnEnter", function(self)
            if activeTab ~= self._key then
                self:SetBackdropColor(unpack(T.BTN_HOVER))
                self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetActive(activeTab == self._key)
        end)
        btn:SetScript("OnClick", function(self)
            activeTab = self._key
            for _, b2 in ipairs(unitBtns) do b2:SetActive(b2._key == activeTab) end
            BuildSettingsTabBtns()
        end)

        btn:SetPoint("TOPLEFT", unitBar, "TOPLEFT", btnX, 0)
        btnX = btnX + btn:GetWidth() + 2
        unitBtns[#unitBtns + 1] = btn
    end

    for _, b2 in ipairs(unitBtns) do b2:SetActive(b2._key == activeTab) end
    BuildSettingsTabBtns()
end)

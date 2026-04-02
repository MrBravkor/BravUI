-- BravUI_Menu/Pages/Cooldown.lua
-- Configuration Barre de Ressource (declarative Engine page)

local M = BravUI.Menu
local L = M.L

local KEY = "cooldown.primary"

local function Refresh()
    BravLib.Hooks.Fire("APPLY_COOLDOWN_RESOURCE")
end

-- Formats de texte
local TEXT_FORMATS = {
    { text = L["cd_fmt_value"]         or "Valeur / Max",           value = "value" },
    { text = L["cd_fmt_value_only"]    or "Valeur",                 value = "value_only" },
    { text = L["cd_fmt_percent"]       or "Pourcentage",            value = "percent" },
    { text = L["cd_fmt_value_pct"]     or "Valeur ( % )",           value = "value_pct" },
    { text = L["cd_fmt_value_percent"] or "Valeur / Max ( % )",     value = "value_percent" },
}

-- Points d'ancrage
local ANCHOR_POINTS = {
    { text = L["cd_anchor_top"]    or "Au-dessus", value = "TOP" },
    { text = L["cd_anchor_bottom"] or "En-dessous", value = "BOTTOM" },
}

-- ============================================================================
-- SPECS
-- ============================================================================

local specs = {
    -- Activation
    { type = "header", label = L["cd_hdr_resource"] or "Barre de Ressource" },
    { type = "toggle", db = KEY .. ".enabled", label = L["cd_enable"] or "Activer" },
    { type = "separator" },

    -- Ancrage
    { type = "header", label = L["cd_hdr_anchor"] or "Ancrage" },
    { type = "toggle",   db = KEY .. ".anchorToViewer", label = L["cd_anchor_to_viewer"] or "Ancrer au CDM" },
    { type = "dropdown", db = KEY .. ".anchorPoint",    label = L["cd_anchor_point"] or "Position", values = ANCHOR_POINTS,
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return not (p and p.anchorToViewer) end },
    { type = "slider",   db = KEY .. ".anchorOffsetX",  label = L["cd_anchor_offset_x"] or "Decalage X", min = -100, max = 100, step = 1,
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return not (p and p.anchorToViewer) end },
    { type = "slider",   db = KEY .. ".anchorOffsetY",  label = L["cd_anchor_offset_y"] or "Decalage Y", min = -100, max = 100, step = 1,
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return not (p and p.anchorToViewer) end },
    { type = "toggle",   db = KEY .. ".flexibleWidth",  label = L["cd_flexible_width"] or "Largeur flexible",
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return not (p and p.anchorToViewer) end },
    { type = "separator" },

    -- Taille
    { type = "header", label = L["cd_hdr_size"] or "Taille" },
    { type = "slider", db = KEY .. ".width",  label = L["cd_width"] or "Largeur",  min = 80, max = 500, step = 5,
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return p and p.anchorToViewer and p.flexibleWidth end },
    { type = "slider", db = KEY .. ".height", label = L["cd_height"] or "Hauteur", min = 4, max = 30, step = 1 },
    { type = "separator" },

    -- Couleur
    { type = "header", label = L["cd_hdr_color"] or "Couleur" },
    { type = "toggle", db = KEY .. ".usePowerColor", label = L["cd_use_power_color"] or "Couleur de ressource" },
    { type = "toggle", db = KEY .. ".useClassColor", label = L["cd_use_class_color"] or "Couleur de classe",
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return p and p.usePowerColor end },
    { type = "color",  db = KEY .. ".barColor",      label = L["cd_bar_color"] or "Couleur personnalisee",
      hidden = function(db) local p = db.cooldown and db.cooldown.primary; return p and (p.usePowerColor or p.useClassColor) end },
    { type = "separator" },

    -- Texte
    { type = "header", label = L["cd_hdr_text"] or "Texte" },
    { type = "toggle",   db = KEY .. ".showText",        label = L["cd_show_text"] or "Afficher le texte" },
    { type = "dropdown", db = KEY .. ".textFormat",       label = L["cd_text_format"] or "Format", values = TEXT_FORMATS },
    { type = "slider",   db = KEY .. ".fontSize",         label = L["cd_font_size"] or "Taille police", min = 6, max = 18, step = 1 },
    { type = "color",    db = KEY .. ".centerTextColor",  label = L["cd_text_color"] or "Couleur texte" },
    { type = "separator" },

    -- Apparence
    { type = "header", label = L["cd_hdr_appearance"] or "Apparence" },
    { type = "slider", db = KEY .. ".alpha",      label = L["cd_alpha"] or "Opacite",        min = 0, max = 1, step = 0.01 },
    { type = "slider", db = KEY .. ".bgAlpha",    label = L["cd_bg_alpha"] or "Opacite fond", min = 0, max = 1, step = 0.01 },
    { type = "toggle", db = KEY .. ".showBorder", label = L["cd_show_border"] or "Afficher la bordure" },
}

M:RegisterPage("cooldown_resource", 15, L["page_cooldown_resource"] or "Ressource", specs, {
    onChanged = Refresh,
})

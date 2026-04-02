-- BravUI_Menu/Pages/DataBars.lua
-- Configuration XPBar / RepBar / HonorBar (declarative Engine page)

local M = BravUI.Menu
local L = M.L

-- Mapping clé module → clé positions (BravUI.Move)
local POS_KEYS = {
  expbar   = "Barre XP",
  repbar   = "Barre Rep",
  honorbar = "Barre Honneur",
}

local function RefreshAll()
  BravLib.Hooks.Fire("APPLY_DATABARS")
end

-- Valeurs dropdown format texte
local TEXT_FORMATS = {
  { text = L["xp_fmt_value_only"], value = "value_only" },
  { text = L["xp_fmt_value"],      value = "value" },
  { text = L["xp_fmt_value_pct"],  value = "value_percent" },
  { text = L["xp_fmt_value_pct2"], value = "value_pct" },
  { text = L["xp_fmt_pct"],        value = "percent" },
}

-- ============================================================================
-- FACTORY : génère les subtabs pour une barre
-- ============================================================================

local function BarSubtabs(key, extras)

  -- Onglet Général
  local generalChildren = {}
  for _, spec in ipairs(extras) do
    generalChildren[#generalChildren + 1] = spec
  end
  generalChildren[#generalChildren + 1] = { type = "separator" }
  generalChildren[#generalChildren + 1] = {
    type = "radio_toggle", db = key .. ".useClassColor",
    values = {
      { text = L["xp_use_class_color"],  value = true },
      { text = L["xp_use_custom_color"], value = false },
    },
  }
  generalChildren[#generalChildren + 1] = {
    type = "color", db = key .. ".barColor",
    label = L["xp_bar_color"],
    hidden = function(db)
      local node = db and db[key]
      return node and node.useClassColor
    end,
  }
  generalChildren[#generalChildren + 1] = { type = "separator" }
  generalChildren[#generalChildren + 1] = { type = "slider", db = key .. ".alpha",    label = L["xp_alpha"],      min = 0.0, max = 1.0, step = 0.01 }
  generalChildren[#generalChildren + 1] = { type = "slider", db = key .. ".bgAlpha",  label = L["xp_bg_alpha"],   min = 0.0, max = 1.0, step = 0.01 }
  generalChildren[#generalChildren + 1] = { type = "toggle", db = key .. ".showBorder", label = L["xp_show_border"] }

  -- Onglet Texte
  local textChildren = {
    { type = "toggle",     db = key .. ".showText",       label = L["xp_show_text"] },
    { type = "dropdown",   db = key .. ".textFormat",     label = L["xp_text_format"], values = TEXT_FORMATS },
    { type = "anchor_grid",db = key .. ".textAnchor",     label = L["xp_text_anchor"] },
    { type = "slider",     db = key .. ".fontSize",       label = L["xp_font_size"],        min = 6, max = 20, step = 1 },
    { type = "color",      db = key .. ".centerTextColor",label = L["xp_center_text_color"] },
    { type = "separator" },
    { type = "toggle",     db = key .. ".showLeftText",   label = L["xp_show_left_text"] },
    { type = "anchor_grid",db = key .. ".leftTextAnchor", label = L["xp_left_text_anchor"] },
    { type = "slider",     db = key .. ".leftFontSize",   label = L["xp_left_font_size"],   min = 6, max = 20, step = 1 },
    { type = "color",      db = key .. ".leftTextColor",  label = L["xp_left_text_color"] },
    { type = "separator" },
    { type = "toggle",     db = key .. ".showRightText",  label = L["xp_show_right_text"] },
    { type = "anchor_grid",db = key .. ".rightTextAnchor",label = L["xp_right_text_anchor"] },
    { type = "slider",     db = key .. ".rightFontSize",  label = L["xp_right_font_size"],  min = 6, max = 20, step = 1 },
    { type = "color",      db = key .. ".rightTextColor", label = L["xp_right_text_color"] },
  }

  -- Onglet Taille / Position
  local posKey = POS_KEYS[key]
  local sizeChildren = {
    { type = "slider", db = key .. ".width",  label = L["xp_width"],  min = 100, max = 800, step = 10 },
    { type = "slider", db = key .. ".height", label = L["xp_height"], min = 8,   max = 40,  step = 1 },
    { type = "slider", db = "positions." .. posKey .. ".x", label = L["xp_pos_x"], min = -800, max = 800, step = 1 },
    { type = "slider", db = "positions." .. posKey .. ".y", label = L["xp_pos_y"], min = -600, max = 600, step = 1 },
  }

  return { type = "subtabs", tabs = {
    { label = L["xp_grp_general"], children = generalChildren },
    { label = L["xp_grp_text"],    children = textChildren },
    { label = L["xp_grp_size"],    children = sizeChildren },
  }}
end

-- ============================================================================
-- SPECS
-- ============================================================================

local specs = {
  -- Expérience
  { type = "header", label = L["xp_hdr_exp"] },
  BarSubtabs("expbar", {
    { type = "toggle", db = "expbar.enabled",      label = L["xp_enable_exp"] },
    { type = "toggle", db = "expbar.hideAtMaxLevel",label = L["xp_hide_max"] },
  }),

  -- Réputation
  { type = "header", label = L["xp_hdr_rep"] },
  BarSubtabs("repbar", {
    { type = "toggle", db = "repbar.enabled",       label = L["xp_enable_rep"] },
    { type = "toggle", db = "repbar.hideNoFaction", label = L["xp_hide_no_faction"] },
    { type = "label",  text = L["xp_desc_rep"], size = 10 },
  }),

  -- Honneur
  { type = "header", label = L["xp_hdr_honor"] },
  BarSubtabs("honorbar", {
    { type = "toggle", db = "honorbar.enabled",    label = L["xp_enable_honor"] },
    { type = "toggle", db = "honorbar.alwaysShow", label = L["xp_honor_always"] },
    { type = "label",  text = L["xp_desc_honor"], size = 10 },
  }),
}

M:RegisterPage("expbars", 5, L["page_expbars"], specs, {
  onChanged = RefreshAll,
})

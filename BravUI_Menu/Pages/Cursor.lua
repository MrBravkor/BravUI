-- BravUI_Menu/Pages/Cursor.lua
-- Cursor module configuration (declarative Engine page)

local M = BravUI.Menu
local L = M.L

-- ============================================================================
-- DROPDOWN VALUES
-- ============================================================================

local FILL_DRAIN_VALUES = {
  { text = "Fill",  value = "fill" },
  { text = "Drain", value = "drain" },
}

local MOD_ACTION_VALUES = {
  { text = L["crs_action_none"] or "Aucun", value = "None" },
  { text = "Ping",      value = "Ping" },
  { text = "Crosshair", value = "Crosshair" },
}

-- ============================================================================
-- PAGE REGISTRATION
-- ============================================================================

M:RegisterPage("cursor", 17, L["page_cursor"] or "Curseur", {
  -- General
  { type = "header", label = L["crs_hdr_general"] or "G\195\169n\195\169ral" },
  { type = "toggle", db = "cursor.enabled",
    label = L["crs_enable"] or "Activer le curseur" },
  { type = "slider", db = "cursor.scale",
    label = L["crs_scale"] or "\195\137chelle globale", min = 0.3, max = 3.0, step = 0.1, decimals = 1 },
  { type = "slider", db = "cursor.alpha",
    label = L["crs_alpha"] or "Opacit\195\169", min = 0.1, max = 1.0, step = 0.05, decimals = 2 },
  { type = "toggle", db = "cursor.combatOnly",
    label = L["crs_combat_only"] or "Combat uniquement" },

  -- Anneau et reticule
  { type = "group", label = L["crs_group_ring"] or "Anneau et r\195\169ticule", children = {
    { type = "toggle", db = "cursor.showMainRing",
      label = L["crs_show_ring"] or "Anneau principal" },
    { type = "slider", db = "cursor.mainRingSize",
      label = L["crs_ring_size"] or "Taille anneau", min = 20, max = 200, step = 2 },
    { type = "toggle", db = "cursor.showReticle",
      label = L["crs_show_reticle"] or "R\195\169ticule central" },
    { type = "slider", db = "cursor.reticleSize",
      label = L["crs_reticle_size"] or "Taille r\195\169ticule", min = 2, max = 20, step = 1 },
  }},

  -- GCD
  { type = "group", label = L["crs_group_gcd"] or "Anneau GCD", collapsed = true, children = {
    { type = "toggle", db = "cursor.showGCD",
      label = L["crs_show_gcd"] or "Afficher le GCD" },
    { type = "slider", db = "cursor.gcdSize",
      label = L["crs_gcd_size"] or "Taille GCD", min = 20, max = 200, step = 2 },
    { type = "dropdown", db = "cursor.gcdFillDrain",
      label = L["crs_gcd_mode"] or "Mode GCD", values = FILL_DRAIN_VALUES },
    { type = "slider", db = "cursor.gcdRotation",
      label = L["crs_gcd_rotation"] or "Rotation GCD (horloge)", min = 1, max = 12, step = 1 },
  }},

  -- Cast
  { type = "group", label = L["crs_group_cast"] or "Anneau Cast", collapsed = true, children = {
    { type = "toggle", db = "cursor.showCast",
      label = L["crs_show_cast"] or "Afficher le cast" },
    { type = "slider", db = "cursor.castSize",
      label = L["crs_cast_size"] or "Taille cast", min = 40, max = 300, step = 2 },
    { type = "dropdown", db = "cursor.castFillDrain",
      label = L["crs_cast_mode"] or "Mode cast", values = FILL_DRAIN_VALUES },
    { type = "slider", db = "cursor.castRotation",
      label = L["crs_cast_rotation"] or "Rotation cast (horloge)", min = 1, max = 12, step = 1 },
  }},

  -- Trainee
  { type = "group", label = L["crs_group_trail"] or "Train\195\169e", collapsed = true, children = {
    { type = "toggle", db = "cursor.enableTrail",
      label = L["crs_trail_enable"] or "Activer la train\195\169e" },
    { type = "slider", db = "cursor.trailDuration",
      label = L["crs_trail_duration"] or "Dur\195\169e (sec)", min = 0.1, max = 2.0, step = 0.05, decimals = 2 },
    { type = "slider", db = "cursor.trailDensity",
      label = L["crs_trail_density"] or "Densit\195\169", min = 0.001, max = 0.05, step = 0.001, decimals = 3 },
    { type = "slider", db = "cursor.trailScale",
      label = L["crs_trail_scale"] or "\195\137chelle particules", min = 0.3, max = 3.0, step = 0.1, decimals = 1 },
  }},

  -- Touches modificatrices
  { type = "group", label = L["crs_group_modifiers"] or "Touches modificatrices", collapsed = true, children = {
    { type = "dropdown", db = "cursor.shiftAction",
      label = "Shift", values = MOD_ACTION_VALUES },
    { type = "dropdown", db = "cursor.ctrlAction",
      label = "Ctrl", values = MOD_ACTION_VALUES },
    { type = "dropdown", db = "cursor.altAction",
      label = "Alt", values = MOD_ACTION_VALUES },

    { type = "divider" },

    { type = "slider", db = "cursor.pingDuration",
      label = L["crs_ping_duration"] or "Dur\195\169e ping (sec)", min = 0.1, max = 2.0, step = 0.05, decimals = 2 },
    { type = "slider", db = "cursor.pingStartSize",
      label = L["crs_ping_start"] or "Taille ping d\195\169but", min = 50, max = 400, step = 10 },
    { type = "slider", db = "cursor.pingEndSize",
      label = L["crs_ping_end"] or "Taille ping fin", min = 20, max = 200, step = 5 },
    { type = "slider", db = "cursor.crossDuration",
      label = L["crs_cross_duration"] or "Dur\195\169e crosshair (sec)", min = 0.5, max = 5.0, step = 0.1, decimals = 1 },
    { type = "slider", db = "cursor.crossGap",
      label = L["crs_cross_gap"] or "\195\137cart crosshair (px)", min = 10, max = 100, step = 5 },
  }},
})

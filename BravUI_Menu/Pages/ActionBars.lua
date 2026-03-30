-- BravUI_Menu/Pages/ActionBars.lua
-- ActionBars configuration (declarative, auto-tabs + subtabs)

local M = BravUI.Menu
local L = M.L

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetActionBarsDB() return M:GetModuleDB("actionbars") end

local function GetBarDB(barKey)
  local db = GetActionBarsDB()
  if not db then return nil end
  db.bars = db.bars or {}
  db.bars[barKey] = db.bars[barKey] or {}
  return db.bars[barKey]
end

local function RefreshActionBars()
  BravLib.Hooks.Fire("APPLY_ACTIONBARS")
end


-- ============================================================================
-- PER-BAR SETTINGS
-- ============================================================================

local function BarSettings(def)
  local k      = def.key
  local maxBtn = def.buttons
  if def.dynamicCount and def.id == "stance" then
    local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    if n > 0 then maxBtn = n end
  end

  return {
    -- Activer
    { type = "toggle", label = L["ab_bar_enable"],
      get = function() local d = GetBarDB(k); return d and d.enabled ~= false end,
      set = function(v) local d = GetBarDB(k); if d then d.enabled = v end; RefreshActionBars() end },

    -- Position
    { type = "group", label = L["ab_hdr_bar_position"], children = {
      { type = "slider", label = L["ab_bar_opacity"], min = 0, max = 1, step = 0.05, decimals = 2,
        get = function() local d = GetBarDB(k); return d and d.alpha or 1 end,
        set = function(v) local d = GetBarDB(k); if d then d.alpha = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_bar_pos_x"], min = -2000, max = 2000, step = 1,
        get = function()
          local moverName = def.moverName
          local pos = BravLib.API.Get("positions", moverName)
          return pos and pos.x or 0
        end,
        set = function(v)
          local db = BravLib.Storage.GetDB()
          if db then
            db.positions = db.positions or {}
            db.positions[def.moverName] = db.positions[def.moverName] or {}
            db.positions[def.moverName].x = v
          end
          RefreshActionBars()
        end },
      { type = "slider", label = L["ab_bar_pos_y"], min = -2000, max = 2000, step = 1,
        get = function()
          local moverName = def.moverName
          local pos = BravLib.API.Get("positions", moverName)
          return pos and pos.y or 0
        end,
        set = function(v)
          local db = BravLib.Storage.GetDB()
          if db then
            db.positions = db.positions or {}
            db.positions[def.moverName] = db.positions[def.moverName] or {}
            db.positions[def.moverName].y = v
          end
          RefreshActionBars()
        end },
      { type = "button", label = L["ab_bar_reset"], width = 80, onClick = function()
        local d = GetBarDB(k)
        if d then
          d.origin = "TOPLEFT"
          d.buttonsPerRow = nil; d.alpha = 1
          d.mouseover = false; d.mouseoverAlpha = nil
          d.hideInCombat = false; d.hideOutOfCombat = false; d.combatAlpha = nil
          d.buttonSize = nil; d.buttonSpacing = nil
          d.showKeybinds = nil; d.showMacroNames = nil
          d.showEmptySlots = nil; d.showCooldownText = nil
          d.visibleButtons = nil; d.padding = nil
          d.borderEnabled = false; d.borderUseClass = true
          d.borderColor = nil; d.borderSize = nil
          d.textColor = nil; d.hotkeyAnchor = nil; d.macroAnchor = nil
          d.macroTextColor = nil; d.cooldownTextColor = nil
          d.hotkeyFontSize = nil; d.macroFontSize = nil; d.cdFontSize = nil
          d.iconZoom = nil
        end
        -- Reset position in Move system
        local db = BravLib.Storage.GetDB()
        local defs = BravLib.Storage.GetDefaults()
        if db and defs and defs.positions and defs.positions[def.moverName] then
          db.positions = db.positions or {}
          db.positions[def.moverName] = { x = defs.positions[def.moverName].x, y = defs.positions[def.moverName].y }
        end
        RefreshActionBars()
      end },
    }},

    -- Disposition
    { type = "group", label = L["ab_hdr_bar_layout"], children = {
      { type = "corner_grid", label = L["ab_bar_origin"],
        get = function() local d = GetBarDB(k); return d and d.origin or "TOPLEFT" end,
        set = function(v) local d = GetBarDB(k); if d then d.origin = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_bar_buttons_row"], min = 1, max = maxBtn, step = 1,
        get = function() local d = GetBarDB(k); return d and d.buttonsPerRow or maxBtn end,
        set = function(v) local d = GetBarDB(k); if d then d.buttonsPerRow = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_visible_buttons"], min = 1, max = maxBtn, step = 1,
        get = function() local d = GetBarDB(k); return d and d.visibleButtons or maxBtn end,
        set = function(v) local d = GetBarDB(k); if d then d.visibleButtons = v end; RefreshActionBars() end },
    }},

    -- Visibilite
    { type = "group", label = L["ab_hdr_visibility"], children = {
      { type = "toggle", label = L["ab_mouseover"],
        get = function() local d = GetBarDB(k); return d and d.mouseover or false end,
        set = function(v) local d = GetBarDB(k); if d then d.mouseover = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_mouseover_alpha"], min = 0, max = 1, step = 0.05, decimals = 2,
        get = function() local d = GetBarDB(k); return d and d.mouseoverAlpha or 0 end,
        set = function(v) local d = GetBarDB(k); if d then d.mouseoverAlpha = v end; RefreshActionBars() end },
      { type = "toggle", label = L["ab_hide_combat"],
        get = function() local d = GetBarDB(k); return d and d.hideInCombat or false end,
        set = function(v) local d = GetBarDB(k); if d then d.hideInCombat = v end; RefreshActionBars() end },
      { type = "toggle", label = L["ab_hide_ooc"],
        get = function() local d = GetBarDB(k); return d and d.hideOutOfCombat or false end,
        set = function(v) local d = GetBarDB(k); if d then d.hideOutOfCombat = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_combat_alpha"], min = 0, max = 1, step = 0.05, decimals = 2,
        get = function() local d = GetBarDB(k); return d and d.combatAlpha or 1 end,
        set = function(v) local d = GetBarDB(k); if d then d.combatAlpha = v end; RefreshActionBars() end },
    }},

    -- Apparence
    { type = "group", label = L["ab_hdr_bar_appearance"], children = {
      { type = "slider", label = L["ab_bar_btn_size"], min = 24, max = 48, step = 1,
        get = function() local d = GetBarDB(k); return d and d.buttonSize or 36 end,
        set = function(v) local d = GetBarDB(k); if d then d.buttonSize = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_bar_btn_spacing"], min = 0, max = 10, step = 1,
        get = function() local d = GetBarDB(k); return d and d.buttonSpacing or 2 end,
        set = function(v) local d = GetBarDB(k); if d then d.buttonSpacing = v end; RefreshActionBars() end },
      { type = "slider", label = L["ab_icon_zoom"], min = 0, max = 15, step = 1,
        get = function() local d = GetBarDB(k); local v = d and d.iconZoom; return type(v) == "number" and v or 7 end,
        set = function(v) local d = GetBarDB(k); if d then d.iconZoom = v end; RefreshActionBars() end },
      { type = "toggle_pair", items = {
        { label = L["ab_bar_show_keybinds"],
          get = function() local d = GetBarDB(k); return d and d.showKeybinds ~= false end,
          set = function(v) local d = GetBarDB(k); if d then d.showKeybinds = v end; RefreshActionBars() end },
        { label = L["ab_bar_show_macros"],
          get = function() local d = GetBarDB(k); if d and d.showMacroNames ~= nil then return d.showMacroNames end; return k == "bar1" or k == "bar2" or k == "bar3" end,
          set = function(v) local d = GetBarDB(k); if d then d.showMacroNames = v end; RefreshActionBars() end },
      }},
      { type = "toggle_pair", items = {
        { label = L["ab_bar_show_empty"],
          get = function() local d = GetBarDB(k); return d and d.showEmptySlots ~= false end,
          set = function(v) local d = GetBarDB(k); if d then d.showEmptySlots = v end; RefreshActionBars() end },
        { label = L["ab_bar_show_cd"],
          get = function() local d = GetBarDB(k); if d and d.showCooldownText ~= nil then return d.showCooldownText end; return k == "bar1" or k == "bar2" or k == "bar3" end,
          set = function(v) local d = GetBarDB(k); if d then d.showCooldownText = v end; RefreshActionBars() end },
      }},
    }},

    -- Contour
    { type = "group", label = L["ab_hdr_bar_border"], children = {
      { type = "toggle", label = L["ab_border_enable"],
        get = function() local d = GetBarDB(k); return d and d.borderEnabled or false end,
        set = function(v) local d = GetBarDB(k); if d then d.borderEnabled = v end; RefreshActionBars() end },
      { type = "radio_toggle", label = L["ab_border_class"],
        values = { { text = L["ab_border_class"], value = 1 }, { text = L["ab_border_custom"], value = 2 } },
        get = function() local d = GetBarDB(k); return (d and d.borderUseClass ~= false) and 1 or 2 end,
        set = function(v) local d = GetBarDB(k); if d then d.borderUseClass = (v == 1) end; RefreshActionBars() end },
      { type = "color", label = L["ab_border_color"], indent = "half",
        hidden = function() local d = GetBarDB(k); return not d or d.borderUseClass ~= false end,
        get = function() local d = GetBarDB(k); return d and d.borderColor or { r = 1, g = 1, b = 1 } end,
        set = function(tbl) local d = GetBarDB(k); if d then d.borderColor = tbl end; RefreshActionBars() end },
      { type = "slider", label = L["ab_border_size"], min = 1, max = 4, step = 1,
        get = function() local d = GetBarDB(k); return d and d.borderSize or 1 end,
        set = function(v) local d = GetBarDB(k); if d then d.borderSize = v end; RefreshActionBars() end },
    }},

    -- Textes
    { type = "group", label = L["ab_hdr_bar_text"], children = {
      { type = "color", label = L["ab_text_color"],
        get = function() local d = GetBarDB(k); return d and d.textColor or { r = 1, g = 1, b = 1 } end,
        set = function(tbl) local d = GetBarDB(k); if d then d.textColor = tbl end; RefreshActionBars() end },
      { type = "slider", label = L["ab_hotkey_font_size"], min = 6, max = 20, step = 1,
        get = function() local d = GetBarDB(k); return d and d.hotkeyFontSize or 10 end,
        set = function(v) local d = GetBarDB(k); if d then d.hotkeyFontSize = v end; RefreshActionBars() end },
      { type = "anchor_grid", label = L["ab_hotkey_anchor"],
        get = function() local d = GetBarDB(k); return d and d.hotkeyAnchor or "TOPRIGHT" end,
        set = function(v) local d = GetBarDB(k); if d then d.hotkeyAnchor = v end; RefreshActionBars() end },
      { type = "color", label = L["ab_macro_text_color"],
        get = function() local d = GetBarDB(k); return d and d.macroTextColor or { r = 1, g = 1, b = 1 } end,
        set = function(tbl) local d = GetBarDB(k); if d then d.macroTextColor = tbl end; RefreshActionBars() end },
      { type = "slider", label = L["ab_macro_font_size"], min = 6, max = 20, step = 1,
        get = function() local d = GetBarDB(k); return d and d.macroFontSize or 10 end,
        set = function(v) local d = GetBarDB(k); if d then d.macroFontSize = v end; RefreshActionBars() end },
      { type = "anchor_grid", label = L["ab_macro_anchor"],
        get = function() local d = GetBarDB(k); return d and d.macroAnchor or "BOTTOM" end,
        set = function(v) local d = GetBarDB(k); if d then d.macroAnchor = v end; RefreshActionBars() end },
      { type = "color", label = L["ab_cd_text_color"],
        get = function() local d = GetBarDB(k); return d and d.cooldownTextColor or { r = 1, g = 1, b = 1 } end,
        set = function(tbl) local d = GetBarDB(k); if d then d.cooldownTextColor = tbl end; RefreshActionBars() end },
      { type = "slider", label = L["ab_cd_font_size"], min = 6, max = 20, step = 1,
        get = function() local d = GetBarDB(k); return d and d.cdFontSize or 12 end,
        set = function(v) local d = GetBarDB(k); if d then d.cdFontSize = v end; RefreshActionBars() end },
    }},
  }
end

-- ============================================================================
-- BUILD SPECS
-- ============================================================================

local function BuildSpecs()
  local BAR_DEFS = {
    { id = 1, name = L["ab_bar1"], key = "bar1", moverName = "Barre 1", buttons = 12 },
    { id = 2, name = L["ab_bar2"], key = "bar2", moverName = "Barre 2", buttons = 12 },
    { id = 3, name = L["ab_bar3"], key = "bar3", moverName = "Barre 3", buttons = 12 },
    { id = 4, name = L["ab_bar4"], key = "bar4", moverName = "Barre 4", buttons = 12 },
    { id = 5, name = L["ab_bar5"], key = "bar5", moverName = "Barre 5", buttons = 12 },
    { id = 6, name = L["ab_bar6"], key = "bar6", moverName = "Barre 6", buttons = 12 },
    { id = 7, name = L["ab_bar7"], key = "bar7", moverName = "Barre 7", buttons = 12 },
    { id = 8, name = L["ab_bar8"], key = "bar8", moverName = "Barre 8", buttons = 12 },
    { id = "pet", name = L["ab_bar_pet"], key = "barPet", moverName = "Familiers", buttons = 10 },
    { id = "stance", name = L["ab_bar_stance"], key = "barStance", moverName = "Postures", buttons = 10, dynamicCount = true },
  }

  local specs = {
    -- Module toggle
    { type = "toggle", db = "actionbars.enabled",
      label = L["ab_enable_module"],
      set = function(v)
        local db = GetActionBarsDB()
        if db then db.enabled = v end
        print("|cff33ffccBravUI:|r " .. (L["msg_reload_short"] or "/reload pour appliquer."))
      end },

    -- Keybind button
    { type = "button", label = L["ab_keybind_btn"], width = 200,
      onClick = function()
        if SlashCmdList["BRAVBIND"] then
          SlashCmdList["BRAVBIND"]()
        else
          print("|cff33ffccBravUI:|r /bravbind non disponible.")
        end
      end },
    { type = "button_select", label = L["ab_binding_set"] or "Sauvegarder pour",
      values = {
        { text = L["ab_binding_char"] or "Ce personnage", value = 1 },
        { text = L["ab_binding_account"] or "Tous les personnages", value = 2 },
      },
      get = function()
        local db = GetActionBarsDB()
        return db and db.bindingSet or GetCurrentBindingSet()
      end,
      set = function(v)
        local db = GetActionBarsDB()
        if db then db.bindingSet = v end
      end },
    { type = "label", text = L["ab_keybind_desc"], size = 10 },

    -- Barres 1-4
    { type = "header", label = L["ab_hdr_bars_1_4"] },
    { type = "subtabs", tabs = {
      { label = L["ab_bar1"], children = BarSettings(BAR_DEFS[1]) },
      { label = L["ab_bar2"], children = BarSettings(BAR_DEFS[2]) },
      { label = L["ab_bar3"], children = BarSettings(BAR_DEFS[3]) },
      { label = L["ab_bar4"], children = BarSettings(BAR_DEFS[4]) },
    }},

    -- Barres 5-8
    { type = "header", label = L["ab_hdr_bars_5_8"] },
    { type = "subtabs", tabs = {
      { label = L["ab_bar5"], children = BarSettings(BAR_DEFS[5]) },
      { label = L["ab_bar6"], children = BarSettings(BAR_DEFS[6]) },
      { label = L["ab_bar7"], children = BarSettings(BAR_DEFS[7]) },
      { label = L["ab_bar8"], children = BarSettings(BAR_DEFS[8]) },
    }},

    -- Familier
    { type = "header", label = L["ab_bar_pet"] },
  }

  local petSettings = BarSettings(BAR_DEFS[9])
  for _, s in ipairs(petSettings) do specs[#specs + 1] = s end

  -- Postures
  specs[#specs + 1] = { type = "header", label = L["ab_bar_stance"] }
  local stanceSettings = BarSettings(BAR_DEFS[10])
  for _, s in ipairs(stanceSettings) do specs[#specs + 1] = s end

  return specs
end

-- ============================================================================
-- PAGE REGISTRATION
-- ============================================================================

M:RegisterPage("actionbars", 7, L["page_actionbars"] or "Barres d'action", BuildSpecs(), {
  onChanged = RefreshActionBars,
})

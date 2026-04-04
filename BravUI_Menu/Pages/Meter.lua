-- Pages/Meter.lua
-- BravUI Menu v2 — Meter (declaratif auto-tabs)

local M = BravUI.Menu
local L = M.L

-- ============================================================================
-- DB ACCESS — BravUI.Meter namespace
-- ============================================================================

local function GetBD()
  return BravUI and BravUI.Meter
end

local function GetDB()
  return BravLib and BravLib.API and BravLib.API.GetModule("meter") or {}
end

local function GetPanel()
  local BD = GetBD()
  return BD and BD.Panel
end

local function GetTimer()
  local BD = GetBD()
  return BD and BD.Timer
end

local function GetTracker()
  local BD = GetBD()
  return BD and BD.MPlus
end

local function ApplyRefresh()
  local Panel = GetPanel()
  if Panel and Panel.RefreshBars then Panel.RefreshBars() end
end

local function ApplyPanelSettings()
  local Panel = GetPanel()
  if Panel and Panel.Refresh then Panel.Refresh() end
end

-- ============================================================================
-- PREVIEW : test data via Meter.HandleSlash (API publique)
-- ============================================================================

local _previewActive = false

local function TogglePreview()
  local BD = GetBD()
  if BD and BD.HandleSlash then
    BD:HandleSlash("test")
    _previewActive = not _previewActive
  end
end

local function TogglePreviewStatic()
  local BD = GetBD()
  if BD and BD.HandleSlash then
    BD:HandleSlash("testfix")
  end
end

local function TogglePanel()
  local Panel = GetPanel()
  if Panel and Panel.Toggle then Panel.Toggle() end
end

local _timerPreviewActive = false
local function ToggleTimerPreview()
  local Timer = GetTimer()
  if not Timer then return end
  if _timerPreviewActive then
    if Timer.Hide then Timer.Hide() end
    _timerPreviewActive = false
  else
    if Timer.ShowTest then Timer.ShowTest() end
    _timerPreviewActive = true
  end
end

local _summaryPreviewActive = false
local function ToggleSummaryPreview()
  local Tracker = GetTracker()
  if not Tracker then return end
  if _summaryPreviewActive then
    if Tracker.HideSummary then Tracker.HideSummary() end
    _summaryPreviewActive = false
  else
    if Tracker.ShowTestSummary then
      Tracker.ShowTestSummary()
    else
      if Tracker.GenerateTestRun then Tracker.GenerateTestRun() end
      if Tracker.ShowSummary then Tracker.ShowSummary() end
    end
    _summaryPreviewActive = true
  end
end

-- ============================================================================
-- SPECS BUILDER
-- ============================================================================

local meterModule = BravUI and BravUI.Meter
local meterAvailable = meterModule and meterModule.Panel ~= nil

local function BuildSpecs()
  local specs = {}

  if not meterAvailable then
    specs[#specs + 1] = { type = "header", label = L["mtr_hdr_general"] or "G\195\169n\195\169ral" }
    specs[#specs + 1] = { type = "info", getValue = function()
      return L["mtr_not_loaded"] or "Le module Meter n'est pas charg\195\169.", { 1, 0.4, 0.4, 1 }
    end }

    -- Panneau settings toujours accessibles (db = "meter.*")
    specs[#specs + 1] = { type = "header", label = L["mtr_hdr_panel"] or "Panneau" }

    specs[#specs + 1] = { type = "dropdown", label = L["mtr_panel_layout"] or "Disposition des fen\195\170tres",
      db = "meter.layout",
      values = {
        { value = 1, text = "1 fen\195\170tre" },
        { value = 2, text = "2 fen\195\170tres (c\195\180te \195\160 c\195\180te)" },
        { value = 3, text = "3 fen\195\170tres (2\195\1512 sans bas-droite)" },
        { value = 4, text = "4 fen\195\170tres (grille 2\195\1512)" },
      },
    }

    specs[#specs + 1] = { type = "info", getValue = function()
      return L["mtr_panel_layout_info"] or "Le changement de disposition n\195\169cessite un /reload.", { 1, 0.8, 0.2, 1 }
    end }

    specs[#specs + 1] = { type = "slider", label = L["mtr_panel_width"] or "Largeur du panneau",
      db = "meter.panelWidth", min = 300, max = 700, step = 5 }
    specs[#specs + 1] = { type = "slider", label = L["mtr_panel_height"] or "Hauteur du panneau",
      db = "meter.panelHeight", min = 100, max = 400, step = 5 }
    specs[#specs + 1] = { type = "slider", label = L["mtr_panel_tab_h"] or "Hauteur des onglets",
      db = "meter.tabHeight", min = 12, max = 22, step = 1 }

    specs[#specs + 1] = { type = "toggle", label = L["mtr_panel_show_bg"] or "Afficher le fond",
      db = "meter.showBackground" }

    specs[#specs + 1] = { type = "slider", label = L["mtr_header_opacity"] or "Opacit\195\169 des onglets",
      db = "meter.headerOpacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
      hidden = function(db) return db.meter and db.meter.showBackground == false end }
    specs[#specs + 1] = { type = "slider", label = L["mtr_panel_opacity"] or "Opacit\195\169 des barres",
      db = "meter.opacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
      hidden = function(db) return db.meter and db.meter.showBackground == false end }
    specs[#specs + 1] = { type = "slider", label = L["mtr_footer_opacity"] or "Opacit\195\169 de la barre d'info",
      db = "meter.footerOpacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
      hidden = function(db) return db.meter and db.meter.showBackground == false end }

    specs[#specs + 1] = { type = "button", label = L["mtr_panel_toggle"] or "Afficher / Masquer le panneau", width = 260,
      onClick = function() TogglePanel() end }

    return specs
  end

  -- ========================================================================
  -- Tab 1 : General (toggles activation)
  -- ========================================================================
  specs[#specs + 1] = { type = "header", label = L["mtr_hdr_general"] or "G\195\169n\195\169ral" }

  specs[#specs + 1] = { type = "toggle", label = L["mtr_enable"] or "Activer le Damage Meter",
    db = "meter.enabled" }

  specs[#specs + 1] = { type = "info", getValue = function()
    return L["msg_reload_short"] or "/reload pour appliquer.", { 1, 0.8, 0.2, 1 }
  end }

  specs[#specs + 1] = { type = "toggle", label = L["mtr_timer_enabled"] or "Activer le Timer M+",
    db = "meter.timerEnabled" }

  specs[#specs + 1] = { type = "toggle", label = L["mtr_summary_enabled"] or "Panneau de fin de donjon",
    db = "meter.summaryEnabled" }

  -- ========================================================================
  -- Tab 2 : Barres (affichage + dimensions)
  -- ========================================================================
  specs[#specs + 1] = { type = "header", label = L["mtr_hdr_bars"] or "Barres" }

  specs[#specs + 1] = { type = "toggle_pair", items = {
    { label = L["mtr_show_spec_icon"] or "Afficher l'icône de spé",
      get = function() local d = BravLib.API.GetModule("meter"); return d and d.showSpecIcon ~= false end,
      set = function(v) local d = BravLib.API.GetModule("meter"); if d then d.showSpecIcon = v end end },
    { label = L["mtr_show_rank"] or "Afficher le rang",
      get = function() local d = BravLib.API.GetModule("meter"); return d and d.showRank ~= false end,
      set = function(v) local d = BravLib.API.GetModule("meter"); if d then d.showRank = v end end },
  }}

  specs[#specs + 1] = { type = "radio_toggle", label = L["mtr_bar_color_mode"] or "Couleur des barres",
    db = "meter.barColorMode",
    values = {
      { value = "class",  text = "Couleur de classe" },
      { value = "custom", text = "Couleur personnalis\195\169e" },
    },
  }

  specs[#specs + 1] = { type = "color", label = L["mtr_bar_custom_color"] or "Choisir la couleur",
    db = "meter.barCustomColor",
    halfIndent = true,
    hidden = function(db)
      return not db.meter or db.meter.barColorMode ~= "custom"
    end,
  }

  specs[#specs + 1] = { type = "button_select", label = L["mtr_rank_separator"] or "S\195\169parateur du rang",
    db = "meter.rankSeparator",
    values = {
      { value = "",   text = "Aucun" },
      { value = ".",  text = "." },
      { value = ":",  text = ":" },
      { value = ";",  text = ";" },
    },
    hidden = function(db)
      return db.meter and db.meter.showRank == false
    end,
  }

  -- TODO: réactiver quand des icônes de spé custom seront disponibles
  -- specs[#specs + 1] = { type = "dropdown", label = L["mtr_class_icon_style"] or "Style des icônes de classe",
  --   db = "meter.classIconStyle",
  --   values = {
  --     { value = "blizzard",     text = "Blizzard" },
  --     { value = "flat",         text = "Flat" },
  --     { value = "flatborder2",  text = "Flat Border" },
  --     { value = "round",        text = "Round" },
  --     { value = "square",       text = "Square" },
  --     { value = "warcraftflat", text = "Warcraft Flat" },
  --   },
  -- }

  local SLOT_VALUES = {
    { value = "dps",     text = "DPS/s" },
    { value = "total",   text = "Total" },
    { value = "percent", text = "%" },
    { value = "none",    text = "Aucun" },
  }

  specs[#specs + 1] = { type = "button_select", label = L["mtr_bar_text_mode"] or "Format du texte",
    db = "meter.barTextMode",
    values = {
      { value = 1, text = "Disposition 1",      subtext = "DPS/s ( Total | % )" },
      { value = 2, text = "Disposition 2",      subtext = "Total ( DPS/s | % )" },
      { value = 3, text = "Disposition custom", subtext = "Personnalisable" },
    },
  }

  specs[#specs + 1] = { type = "input",
    label = L["mtr_bar_custom_format"] or "Format personnalis\195\169  —  dps  total  %",
    db = "meter.barTextCustom",
    hidden = function(db) return not db.meter or db.meter.barTextMode ~= 3 end }

  specs[#specs + 1] = { type = "slider", label = L["mtr_bar_height"] or "Hauteur des barres",
    db = "meter.barHeight", min = 8, max = 32, step = 1 }

  specs[#specs + 1] = { type = "slider", label = L["mtr_bar_spacing"] or "Espacement",
    db = "meter.barSpacing", min = 0, max = 5, step = 1 }

  specs[#specs + 1] = { type = "slider", label = L["mtr_font_size"] or "Taille du rang + nom",
    db = "meter.fontSize", min = 7, max = 14, step = 1 }

  specs[#specs + 1] = { type = "slider", label = L["mtr_font_size_values"] or "Taille des valeurs",
    db = "meter.fontSizeValues", min = 7, max = 14, step = 1 }


  -- ========================================================================
  -- Tab 3 : Panneau (layout + dimensions)
  -- ========================================================================
  specs[#specs + 1] = { type = "header", label = L["mtr_hdr_panel"] or "Panneau" }

  specs[#specs + 1] = { type = "dropdown", label = L["mtr_panel_layout"] or "Disposition des fen\195\170tres",
    db = "meter.layout",
    values = {
      { value = 1, text = "1 fen\195\170tre" },
      { value = 2, text = "2 fen\195\170tres (c\195\180te \195\160 c\195\180te)" },
      { value = 3, text = "3 fen\195\170tres (2\195\1512 sans bas-droite)" },
      { value = 4, text = "4 fen\195\170tres (grille 2\195\1512)" },
    },
  }

  specs[#specs + 1] = { type = "info", getValue = function()
    return L["mtr_panel_layout_info"] or "Le changement de disposition n\195\169cessite un /reload.", { 1, 0.8, 0.2, 1 }
  end }

  specs[#specs + 1] = { type = "slider", label = L["mtr_panel_width"] or "Largeur du panneau",
    db = "meter.panelWidth", min = 300, max = 700, step = 5 }
  specs[#specs + 1] = { type = "slider", label = L["mtr_panel_height"] or "Hauteur du panneau",
    db = "meter.panelHeight", min = 100, max = 400, step = 5 }
  specs[#specs + 1] = { type = "slider", label = L["mtr_panel_tab_h"] or "Hauteur des onglets",
    db = "meter.tabHeight", min = 12, max = 22, step = 1 }

  -- Fond
  specs[#specs + 1] = { type = "toggle", label = L["mtr_panel_show_bg"] or "Afficher le fond",
    db = "meter.showBackground" }

  -- Opacités header / fond / footer
  specs[#specs + 1] = { type = "slider", label = L["mtr_header_opacity"] or "Opacit\195\169 des onglets",
    db = "meter.headerOpacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
    hidden = function(db) return db.meter and db.meter.showBackground == false end }
  specs[#specs + 1] = { type = "slider", label = L["mtr_panel_opacity"] or "Opacit\195\169 des barres",
    db = "meter.opacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
    hidden = function(db) return db.meter and db.meter.showBackground == false end }
  specs[#specs + 1] = { type = "slider", label = L["mtr_footer_opacity"] or "Opacit\195\169 de la barre d'info",
    db = "meter.footerOpacity", min = 0, max = 1.0, step = 0.05, decimals = 2,
    hidden = function(db) return db.meter and db.meter.showBackground == false end }

  specs[#specs + 1] = { type = "button_row", buttons = {
    { label = L["mtr_preview_static"] or "Aper\195\167u Fixe", onClick = function() TogglePreviewStatic() end },
    { label = L["mtr_preview_anim"] or "Aper\195\167u Anim\195\169", onClick = function() TogglePreview() end },
  } }

  -- ========================================================================
  -- Tab 4 : M+ (Timer + Summary previews)
  -- ========================================================================
  specs[#specs + 1] = { type = "header", label = L["mtr_hdr_mplus"] or "M+" }

  specs[#specs + 1] = { type = "slider", label = L["mtr_timer_scale"] or "\195\137chelle du Timer",
    db = "meter.timerScale", min = 0.5, max = 2.0, step = 0.05, decimals = 2 }

  specs[#specs + 1] = { type = "button_row", buttons = {
    { label = L["mtr_preview_timer"] or "Aper\195\167u Timer M+", onClick = function() ToggleTimerPreview() end },
    { label = L["mtr_preview_summary"] or "Aper\195\167u Fin de donjon", onClick = function() ToggleSummaryPreview() end },
  } }

  return specs
end

-- ============================================================================
-- PAGE REGISTRATION (declaratif auto-tabs)
-- ============================================================================

M:RegisterPage("meter", 15, L["page_meter"] or "Meter", BuildSpecs(), {
  onChanged = function()
    ApplyRefresh()
    ApplyPanelSettings()
  end,
})

-- Late-load detection (module charges apres le menu)
if not meterAvailable then
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(self, _, addonName)
    if addonName == "BravUI" or addonName == "BravUI_Menu" then
      meterModule = BravUI and BravUI.Meter
      meterAvailable = meterModule and meterModule.Panel ~= nil
      if meterAvailable then
        M:InvalidatePageCache("meter")
        M:RegisterPage("meter", 15, L["page_meter"] or "Meter", BuildSpecs(), {
          onChanged = function()
            ApplyRefresh()
            ApplyPanelSettings()
          end,
        })
        self:UnregisterAllEvents()
      end
    end
  end)
end

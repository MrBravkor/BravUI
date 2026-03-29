-- BravUI_Menu/Pages/General.lua
-- Paramètres d'apparence globaux

local M = BravUI.Menu
local L = M.L
local _refreshTimer

M:RegisterPage("general", 1, L["page_general"] or "General", {
  -- ═══ COULEUR ═══
  { type = "header", label = L["gen_hdr_color"] },
  { type = "toggle", db = "general.useClassColor",
    label = L["gen_use_class_color"] },
  { type = "color",  db = "general.customColor",
    label = L["gen_custom_color"],
    hidden = function(db) return db.general and db.general.useClassColor end },

  -- ═══ POLICE ═══
  { type = "header", label = L["gen_hdr_font"] },
  { type = "dropdown", db = "general.font", label = L["gen_font"],
    values = {
      { text = L["gen_font_russo"],   value = "russo" },
      { text = L["gen_font_frizqt"],  value = "frizqt" },
      { text = L["gen_font_morpheus"], value = "morpheus" },
      { text = "Arial Narrow",        value = "arialnarrow" },
      { text = L["gen_font_skurri"],  value = "skurri" },
      { text = "Nimrod",              value = "nimrod" },
    }},
  { type = "slider", db = "general.globalFontSize", label = L["gen_font_size"],
    min = 8, max = 22, step = 1 },

  -- ═══ INTERFACE BLIZZARD ═══
  { type = "header", label = L["gen_hdr_blizzard"] },
  { type = "toggle", db = "general.hideBlizzardUI",
    label = L["gen_hide_blizz_ui"] },
}, {
  noTabs = true,
  onChanged = function()
    M:InvalidateColorCache()

    BravLib.Hooks.Fire("APPLY_FONT")

    if _refreshTimer then _refreshTimer:Cancel() end
    _refreshTimer = C_Timer.NewTimer(0.15, function()
      _refreshTimer = nil
      BravLib.Hooks.Fire("APPLY_ALL")
      if M.Frame and M.Frame.RefreshColors then
        M.Frame:RefreshColors()
      end
    end)
  end,
})

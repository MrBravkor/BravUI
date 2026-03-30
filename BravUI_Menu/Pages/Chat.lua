-- BravUI_Menu/Pages/Chat.lua
-- Chat module configuration (declarative Engine page)

local M = BravUI.Menu
local L = M.L

local function RefreshChat()
  BravLib.Hooks.Fire("APPLY_CHAT")
end

local function GetDB()
  return M:GetModuleDB("chat")
end

M:RegisterPage("chat", 13, L["page_chat"] or "Chat", {

  -- ========================================================================
  -- General
  -- ========================================================================
  { type = "header", label = L["chat_hdr_general"] or "G\195\169n\195\169ral" },
  { type = "toggle", db = "chat.enabled",
    label = L["chat_enabled"] or "Activer le module Chat",
    set = function(v)
      local db = GetDB()
      if db then db.enabled = v end
      print("|cff33ffccBravUI:|r " .. (L["msg_reload_short"] or "/reload pour appliquer."))
    end },
  { type = "toggle", db = "chat.locked",
    label = L["chat_locked"] or "Verrouiller le panneau" },

  -- ========================================================================
  -- Apparence
  -- ========================================================================
  { type = "header", label = L["chat_hdr_appearance"] or "Apparence" },
  { type = "slider", db = "chat.opacity",
    label = L["chat_opacity"] or "Opacit\195\169 du fond",
    min = 0, max = 1, step = 0.05, decimals = 2 },

  { type = "group", label = L["chat_grp_tabs"] or "Onglets", children = {
    { type = "slider", db = "chat.tabOpacity",
      label = L["chat_tab_opacity"] or "Opacit\195\169 des onglets",
      min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "toggle", db = "chat.fadeTabs",
      label = L["chat_fade_tabs"] or "Fondu des onglets inactifs" },
    { type = "slider", db = "chat.fadeTabsAlpha",
      label = L["chat_fade_tabs_alpha"] or "Opacit\195\169 du fondu",
      min = 0.1, max = 0.9, step = 0.05, decimals = 2,
      hidden = function(db)
        return not (db and db.chat and db.chat.fadeTabs)
      end },
    { type = "divider" },
    { type = "label", text = L["chat_tab_active_label"] or "Onglet actif" },
    { type = "radio_toggle", db = "chat.useClassColorActive",
      values = {
        { text = L["chat_tab_active_color_class"] or "Couleur de classe", value = true },
        { text = L["chat_tab_active_color_custom"] or "Couleur personnalis\195\169e", value = false },
      }},
    { type = "color", db = "chat.activeTabTextColor",
      label = L["chat_tab_active_text_color"] or "Couleur du texte actif",
      halfIndent = true,
      hidden = function(db)
        return db and db.chat and db.chat.useClassColorActive ~= false
      end },
    { type = "toggle", db = "chat.showTabUnderline",
      label = L["chat_tab_underline"] or "Trait sous l'onglet actif" },
    { type = "divider" },
    { type = "label", text = L["chat_tab_inactive_label"] or "Onglets inactifs" },
    { type = "radio_toggle", db = "chat.useClassColor",
      values = {
        { text = L["chat_tab_color_class"] or "Couleur de classe", value = true },
        { text = L["chat_tab_color_custom"] or "Couleur personnalis\195\169e", value = false },
      }},
    { type = "color", db = "chat.tabTextColor",
      label = L["chat_tab_text_color"] or "Couleur du texte",
      halfIndent = true,
      hidden = function(db)
        return db and db.chat and db.chat.useClassColor
      end },
  }},

  { type = "group", label = L["chat_grp_editbox"] or "Zone de saisie", children = {
    { type = "toggle", db = "chat.editBoxBorderByChannel",
      label = L["chat_editbox_border"] or "Bordure color\195\169e par canal" },
  }},

  -- ========================================================================
  -- Police
  -- ========================================================================
  { type = "header", label = L["chat_hdr_font"] or "Police" },
  { type = "slider", db = "chat.fontSize",
    label = L["chat_font_size"] or "Taille du texte",
    min = 8, max = 20, step = 1 },

  { type = "group", label = L["chat_grp_tabs_font"] or "Onglets", children = {
    { type = "slider", db = "chat.tabFontSize",
      label = L["chat_tab_font_size"] or "Taille police onglets",
      min = 8, max = 16, step = 1 },
    { type = "slider", db = "chat.tabHeight",
      label = L["chat_tab_height"] or "Hauteur des onglets",
      min = 16, max = 40, step = 1 },
  }},

  -- ========================================================================
  -- Taille
  -- ========================================================================
  { type = "header", label = L["chat_hdr_size"] or "Taille" },
  { type = "slider", db = "chat.panelWidth",
    label = L["chat_panel_width"] or "Largeur du panneau",
    min = 200, max = 800, step = 5 },
  { type = "slider", db = "chat.panelHeight",
    label = L["chat_panel_height"] or "Hauteur du panneau",
    min = 80, max = 500, step = 5 },

  { type = "button", label = L["chat_btn_reset"] or "R\195\169initialiser",
    onClick = function()
      local d = GetDB()
      if d then
        d.panelWidth  = 450
        d.panelHeight = 220
        d.opacity     = 0.75
        d.tabOpacity  = 0.85
        d.fontSize    = 12
        d.tabFontSize = 12
        d.tabHeight   = 15
        d.useClassColor        = false
        d.tabTextColor         = { r = 1, g = 1, b = 1 }
        d.useClassColorActive  = true
        d.activeTabTextColor   = { r = 1, g = 1, b = 1 }
        d.showTabUnderline     = true
        d.fadeTabs             = false
        d.fadeTabsAlpha        = 0.45
        d.editBoxBorderByChannel = true
        d.locked               = true
      end
      RefreshChat()
    end },

}, {
  onChanged = RefreshChat,
})

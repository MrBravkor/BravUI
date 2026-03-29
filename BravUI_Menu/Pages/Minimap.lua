-- BravUI_Menu/Pages/Minimap.lua
-- Minimap module configuration (declarative)

local M = BravUI.Menu
local L = M.L

local function RefreshMinimap()
  BravLib.Hooks.Fire("APPLY_MINIMAP")
end

local function GetDB()
  return M:GetModuleDB("minimap")
end

M:RegisterPage("minimap", 6, L["page_minimap"] or "Minimap", {

  -- ═══ GENERAL ═══
  { type = "header", label = L["mm_hdr_general"] },
  { type = "toggle", db = "minimap.enabled",
    label = L["mm_enable"],
    set = function(v)
      local db = GetDB()
      if db then db.enabled = v end
      print("|cff33ffccBravUI:|r " .. (L["msg_reload_short"] or "/reload pour appliquer."))
    end },

  -- ═══ ELEMENTS ═══
  { type = "header", label = L["mm_hdr_elements"] },

  { type = "toggle", db = "minimap.showHeader",
    label = L["mm_show_header"] },
  { type = "toggle", db = "minimap.showCalendar",
    label = L["mm_show_calendar"],
    visible = function() local d = GetDB(); return d and d.showHeader ~= false end },
  { type = "toggle", db = "minimap.showTracking",
    label = L["mm_show_tracking"],
    visible = function() local d = GetDB(); return d and d.showHeader ~= false end },
  { type = "toggle", db = "minimap.showClock",
    label = L["mm_show_clock"],
    visible = function() local d = GetDB(); return d and d.showHeader ~= false end },
  { type = "toggle", db = "minimap.showFooter",
    label = L["mm_show_footer"] },
  { type = "toggle", db = "minimap.showCompartment",
    label = L["mm_show_compartment"] },
  { type = "toggle", db = "minimap.hideAddonButtons",
    label = L["mm_hide_addon_buttons"] },

  -- ═══ TAILLE / POSITION ═══
  { type = "header", label = L["mm_hdr_size_pos"] },
  { type = "slider", label = L["mm_size"], min = 150, max = 400, step = 10,
    get = function()
      local d = GetDB()
      return d and d.panelWidth or 250
    end,
    set = function(v)
      local d = GetDB()
      if d then d.panelWidth = v; d.panelHeight = v end
      RefreshMinimap()
    end },
  { type = "slider", db = "minimap.opacity",
    label = L["mm_bg_opacity"], min = 0, max = 1, step = 0.05, decimals = 2 },
  { type = "slider", db = "minimap.x",
    label = L["mm_offset_x"], min = -2560, max = 2560, step = 1 },
  { type = "slider", db = "minimap.y",
    label = L["mm_offset_y"], min = -1440, max = 1440, step = 1 },

  -- ═══ ICONES ═══
  { type = "header", label = L["mm_hdr_icons"] },

  { type = "group", label = L["mm_grp_header_icons"], children = {
    { type = "slider", db = "minimap.headerIconSize",
      label = L["mm_header_icon_size"], min = 8, max = 32, step = 1 },
    { type = "color", db = "minimap.iconColor",
      label = L["mm_icon_color"] },
  }},

  { type = "group", label = L["mm_grp_mail"], children = {
    { type = "slider", db = "minimap.mailIconSize",
      label = L["mm_mail_icon_size"], min = 8, max = 32, step = 1 },
    { type = "color", db = "minimap.mailIconColor",
      label = L["mm_icon_color"] },
    { type = "button", label = L["mm_preview_mail"],
      onClick = function()
        local panel = _G.BravUI_MinimapV2
        if not panel or not panel._mailHolder then return end
        local holder = panel._mailHolder
        holder._preview = not holder._preview
        if holder._preview then
          holder:Show()
        else
          local hasMail = _G.HasNewMail and _G.HasNewMail()
          if not hasMail then holder:Hide() end
        end
        RefreshMinimap()
      end },
  }},

  { type = "group", label = L["mm_grp_difficulty"], children = {
    { type = "slider", db = "minimap.diffIconSize",
      label = L["mm_diff_icon_size"], min = 8, max = 48, step = 1 },
    { type = "color", db = "minimap.diffIconColor",
      label = L["mm_icon_color"] },
    { type = "button", label = L["mm_preview_diff"],
      onClick = function()
        local panel = _G.BravUI_MinimapV2
        if not panel or not panel._diffHolder then return end
        local holder = panel._diffHolder
        holder._preview = not holder._preview
        if holder._preview then
          holder:Show()
        else
          local inInstance = _G.IsInInstance and _G.IsInInstance()
          if not inInstance then holder:Hide() end
        end
        RefreshMinimap()
      end },
  }},

  { type = "group", label = L["mm_grp_compartment"], children = {
    { type = "slider", db = "minimap.compartIconSize",
      label = L["mm_compart_icon_size"], min = 8, max = 32, step = 1 },
    { type = "color", db = "minimap.compartIconColor",
      label = L["mm_icon_color"] },
  }},

  -- ═══ TEXTES ═══
  { type = "header", label = L["mm_hdr_texts"] },

  { type = "group", label = L["mm_grp_zone"], children = {
    { type = "slider", db = "minimap.headerFontSize",
      label = L["mm_header_font_size"], min = 8, max = 24, step = 1 },
    { type = "color", db = "minimap.zoneTextColor",
      label = L["mm_zone_text_color"] },
  }},

  { type = "group", label = L["mm_grp_clock"], children = {
    { type = "slider", db = "minimap.clockFontSize",
      label = L["mm_clock_font_size"], min = 8, max = 24, step = 1 },
    { type = "button_select", db = "minimap.clockFormat",
      label = L["mm_clock_format"],
      values = {
        { value = "12h", text = "12h" },
        { value = "24h", text = "24h" },
      } },
    { type = "color", db = "minimap.clockTextColor",
      label = L["mm_clock_text_color"] },
  }},

  { type = "group", label = L["mm_grp_contacts"], children = {
    { type = "slider", db = "minimap.footerFontSize",
      label = L["mm_footer_font_size"], min = 8, max = 24, step = 1 },
    { type = "color", db = "minimap.contactsTextColor",
      label = L["mm_contacts_text_color"] },
  }},

  { type = "group", label = L["mm_grp_guild"], children = {
    { type = "slider", db = "minimap.guildFontSize",
      label = L["mm_guild_font_size"], min = 8, max = 24, step = 1 },
    { type = "color", db = "minimap.guildTextColor",
      label = L["mm_guild_text_color"] },
  }},

  { type = "button", label = L["mm_btn_reset"],
    onClick = function()
      BravLib.Hooks.Fire("RESET_MINIMAP")
    end },

}, {
  onChanged = RefreshMinimap,
})

-- BravUI_Menu/Pages/UnitFrames.lua
-- Configuration des cadres d'unité

local M = BravUI.Menu
local L = M.L
local T = M.Theme

-- ============================================================================
-- CONSTANTES
-- ============================================================================

local TABS, TEXT_FORMATS, TEXT_FORMATS_POWER, TEXT_ANCHORS, CAST_ANCHORS, ENERGY_BG_LABELS

local function _initLocaleConsts()
  TABS = {
    { key = "player",  label = L["uf_tab_player"] },
    { key = "target",  label = L["uf_tab_target"] },
    { key = "tot",     label = L["uf_tab_tot"] },
    { key = "focus",   label = L["uf_tab_focus"] },
    { key = "pet",     label = L["uf_tab_pet"] },
    { key = "group",   label = L["uf_tab_group"] },
    { key = "raid15",  label = L["uf_tab_raid15"] },
    { key = "raid25",  label = L["uf_tab_raid25"] },
    { key = "raid40",  label = L["uf_tab_raid40"] },
  }
  TEXT_FORMATS = {
    { text = L["uf_fmt_value"],         value = "VALUE" },
    { text = L["uf_fmt_percent"],       value = "PERCENT" },
    { text = L["uf_fmt_value_percent"], value = "VALUE_PERCENT" },
    { text = L["uf_fmt_percent_value"], value = "PERCENT_VALUE" },
    { text = L["uf_fmt_none"],          value = "NONE" },
  }
  TEXT_FORMATS_POWER = {
    { text = L["uf_fmt_value"], value = "VALUE" },
    { text = L["uf_fmt_none"],  value = "NONE" },
  }
  TEXT_ANCHORS = {
    { text = L["uf_anchor_left"],        value = "LEFT" },
    { text = L["uf_anchor_center"],      value = "CENTER" },
    { text = L["uf_anchor_right"],       value = "RIGHT" },
    { text = L["uf_anchor_topleft"],     value = "TOPLEFT" },
    { text = L["uf_anchor_top"],         value = "TOP" },
    { text = L["uf_anchor_topright"],    value = "TOPRIGHT" },
    { text = L["uf_anchor_bottomleft"],  value = "BOTTOMLEFT" },
    { text = L["uf_anchor_bottom"],      value = "BOTTOM" },
    { text = L["uf_anchor_bottomright"], value = "BOTTOMRIGHT" },
  }
  CAST_ANCHORS = {
    { text = L["uf_anchor_power"], value = "POWER_BOTTOM" },
    { text = L["uf_anchor_hp"],    value = "HP_BOTTOM" },
    { text = L["uf_anchor_root"],  value = "ROOT" },
  }
  ENERGY_BG_LABELS = {
    power = L["uf_bg_power"], classPower = L["uf_bg_class_power"], segments = L["uf_bg_segments"],
  }
end

local FRAME_MAP = {
  player = "Player", target = "Target", tot = "ToT",
  pet = "Pet", focus = "Focus", group = "Group",
  raid15 = "Raid15", raid25 = "Raid25", raid40 = "Raid40",
}

local PREVIEW_MAP = {
  tot = "ToT", focus = "Focus", pet = "Pet", group = "Group",
  raid15 = "Raid15", raid25 = "Raid25", raid40 = "Raid40",
}

local CAPS = {
  player = {
    hp = true, energy = true, cast = true, extra = true, auras = true,
    power = true, classPower = true,
    showPower = true, showClassPower = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power", "classPower", "segments" },
  },
  target = {
    hp = true, energy = true, cast = true, extra = true, auras = true,
    power = true, showPower = true,
    reaction = true, range = true, level = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
    castBgKeys = { "cast" },
  },
  tot = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    range = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
  },
  focus = {
    hp = true, energy = true, cast = true, extra = true,
    power = true, showPower = true,
    reaction = true, range = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
    castBgKeys = { "cast" },
  },
  pet = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    cast = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
    castBgKeys = { "cast" },
  },
  group = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    range = true, groupUnit = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
  },
  raid15 = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    range = true, raid = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
  },
  raid25 = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    range = true, raid = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
  },
  raid40 = {
    hp = true, energy = true, extra = true,
    power = true, showPower = true,
    range = true, raid = true,
    hpBgKeys = { "hp" },
    energyBgKeys = { "power" },
  },
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local _liveTimers = {}
local function LiveApply(which)
  if InCombatLockdown() then return end
  if _liveTimers[which] then _liveTimers[which]:Cancel() end
  _liveTimers[which] = C_Timer.NewTimer(0.05, function()
    _liveTimers[which] = nil
    if InCombatLockdown() then return end
    BravLib.Hooks.Fire("APPLY_UNIT", which)
  end)
end

local function CapturePosition(key, refreshFn)
  local fKey = FRAME_MAP[key]
  local frames = BravUI and BravUI.Frames
  if not fKey or not frames or not frames[fKey] then return end

  local root = frames[fKey]
  if type(root) == "table" then
    root = root.Root or root.frame or root.Main or root
  end
  if not root or not root.GetPoint then return end

  local success = pcall(function()
    local _, _, _, px, py = root:GetPoint(1)
    local x = math.floor(tonumber(px) + 0.5)
    local y = math.floor(tonumber(py) + 0.5)
    local db = BravLib.Storage.GetDB()
    if not db or not db.unitframes then return end
    local uf = db.unitframes[key]
    if not uf then return end
    uf.posX = x
    uf.posY = y
  end)

  if success then
    LiveApply(key)
    if refreshFn then refreshFn() end
  end
end

local function ResetUnit(key, refreshFn)
  if InCombatLockdown() then return end
  BravLib.Hooks.Fire("RESET_UNIT", key)
  LiveApply(key)
  if refreshFn then refreshFn() end
end

local _recycler = CreateFrame("Frame")
_recycler:Hide()

local function SetPreview(key, enabled)
  local frameName = PREVIEW_MAP[key]
  if not frameName then return end
  local frames = BravUI and BravUI.Frames
  if not frames or not frames[frameName] then return end
  local fn = frames[frameName].SetPreviewMode
  if fn then pcall(fn, enabled) end
end

local function DisableAllPreviews()
  for _, frameName in pairs(PREVIEW_MAP) do
    local frames = BravUI and BravUI.Frames
    if frames and frames[frameName] and frames[frameName].SetPreviewMode then
      pcall(frames[frameName].SetPreviewMode, false)
    end
  end
end

local function ClearHost(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    child:Hide()
    child:ClearAllPoints()
    child:SetParent(_recycler)
  end
end

-- ============================================================================
-- FACTORY DE SPECS
-- ============================================================================

local function BuildSpecs(key, onRefresh)
  local pre = "unitframes." .. key .. "."
  local cap = CAPS[key] or {}
  local specs = {}
  local function ins(s) specs[#specs + 1] = s end

  -- ═══ GENERAL ═══
  ins({ type = "header", label = L["uf_hdr_general"] })
  ins({ type = "toggle", db = pre .. "enabled", label = L["uf_enable"] })
  ins({ type = "slider", db = pre .. "scale",   label = L["uf_scale"],
    min = 0.50, max = 2.00, step = 0.05, decimals = 2 })
  ins({ type = "slider", db = pre .. "posX", label = L["uf_pos_x"],
    min = -2000, max = 2000, step = 1 })
  ins({ type = "slider", db = pre .. "posY", label = L["uf_pos_y"],
    min = -2000, max = 2000, step = 1 })

  local actionBtns = {
    { label = L["uf_btn_reset"],
      onClick = function() ResetUnit(key, onRefresh) end },
  }
  if PREVIEW_MAP[key] then
    actionBtns[#actionBtns + 1] = {
      label = L["uf_btn_preview"],
      onClick = function()
        local frameName = PREVIEW_MAP[key]
        local frames = BravUI and BravUI.Frames
        if not frames or not frames[frameName] then return end
        local isOn = false
        if frames[frameName].IsPreviewMode then
          pcall(function() isOn = frames[frameName].IsPreviewMode() end)
        end
        SetPreview(key, not isOn)
      end,
    }
  end
  ins({ type = "button_row", buttons = actionBtns })

  -- ═══ COULEUR ═══
  do
    local cc = {}
    local function ci(s) cc[#cc + 1] = s end

    if cap.hp then
      ci({ type = "header", label =  L["uf_group_hp"]  })
      ci({ type = "radio_toggle", db = pre .. "colors.useClassColor",
        values = {
          { text = "Utilisez la couleur de classe",         value = true },
          { text = "Utilisez une couleur personnalis\195\169e", value = false },
        }})
      ci({ type = "color", db = pre .. "colors.hpCustom",
        label = L["uf_hp_custom_color"],
        hidden = function(db)
          local uf = db.unitframes and db.unitframes[key]
          return uf and uf.colors and uf.colors.useClassColor
        end })
      if cap.reaction then
        ci({ type = "divider" })
        ci({ type = "toggle", db = pre .. "colors.useReaction",
          label = L["uf_use_reaction"] })
        ci({ type = "color", db = pre .. "colors.reaction.friendly",
          label = L["uf_friendly"],
          hidden = function(db)
            local uf = db.unitframes and db.unitframes[key]
            return not (uf and uf.colors and uf.colors.useReaction)
          end })
        ci({ type = "color", db = pre .. "colors.reaction.neutral",
          label = L["uf_neutral"],
          hidden = function(db)
            local uf = db.unitframes and db.unitframes[key]
            return not (uf and uf.colors and uf.colors.useReaction)
          end })
        ci({ type = "color", db = pre .. "colors.reaction.hostile",
          label = L["uf_hostile"],
          hidden = function(db)
            local uf = db.unitframes and db.unitframes[key]
            return not (uf and uf.colors and uf.colors.useReaction)
          end })
      end
    end

    if cap.power then
      ci({ type = "header", label =  L["uf_group_energy"]  })
      ci({ type = "radio_toggle", db = pre .. "colors.usePowerColor",
        values = {
          { text = "Utilisez la couleur de puissance",      value = true },
          { text = "Utilisez une couleur personnalis\195\169e", value = false },
        }})
      ci({ type = "color", db = pre .. "colors.powerCustom",
        label = L["uf_power_custom_color"],
        hidden = function(db)
          local uf = db.unitframes and db.unitframes[key]
          return uf and uf.colors and uf.colors.usePowerColor
        end })
    end

    if cap.showClassPower or cap.classPower then
      ci({ type = "header", label =  (L["uf_group_class_power"] or "Barre de classe")  })
      ci({ type = "radio_toggle", db = pre .. "colors.useClassColorCP",
        values = {
          { text = "Utilisez la couleur de classe",         value = true },
          { text = "Utilisez une couleur personnalis\195\169e", value = false },
        }})
      ci({ type = "color", db = pre .. "colors.classPowerCustom",
        label = L["uf_cp_custom_color"] or "Couleur personnalis\195\169e",
        hidden = function(db)
          local uf = db.unitframes and db.unitframes[key]
          return uf and uf.colors and uf.colors.useClassColorCP
        end })
    end

    ci({ type = "divider" })
    ci({ type = "button", label = L["uf_btn_reset"] or "Reset",
      onClick = function()
        local db = BravLib.Storage.GetDB()
        local def = BravLib.Storage.GetDefaults()
        if db and db.unitframes and def and def.unitframes and def.unitframes[key] then
          db.unitframes[key].colors = BravLib.CopyTable(def.unitframes[key].colors or {})
        end
        if onRefresh then onRefresh() end
      end })

    ins({ type = "group", label = L["uf_hdr_color"], collapsed = true, children = cc })
  end

  -- ═══ TAILLE ═══
  do
    local sc = {}
    local function si(s) sc[#sc + 1] = s end

    if cap.hp then
      si({ type = "header", label =  L["uf_group_hp"]  })
      si({ type = "slider", db = pre .. "width", label = L["uf_width"],
        min = 50, max = 500, step = 1 })
      si({ type = "slider", db = pre .. "height.hp", label = L["uf_height_hp"],
        min = 8, max = 60, step = 1 })
    end

    if cap.power then
      si({ type = "header", label =  L["uf_group_energy"]  })
      if cap.showPower then
        si({ type = "toggle", db = pre .. "showPower", label = L["uf_show_power"] })
      end
      si({ type = "slider", db = pre .. "height.power",
        label = L["uf_height_power"], min = 4, max = 30, step = 1 })
    end

    if cap.showClassPower or cap.classPower then
      si({ type = "header", label =  (L["uf_group_class_power"] or "Barre de classe")  })
      if cap.showClassPower then
        si({ type = "toggle", db = pre .. "showClassPower", label = L["uf_show_class_power"] })
      end
      if cap.classPower then
        si({ type = "slider", db = pre .. "height.classPower",
          label = L["uf_height_class_power"], min = 4, max = 20, step = 1 })
      end
    end

    ins({ type = "group", label = L["uf_hdr_size"], collapsed = true, children = sc })
  end

  -- ═══ TEXTE ═══
  do
    local tc = {}
    local function ti(s) tc[#tc + 1] = s end

    if cap.hp then
      ti({ type = "header", label =  L["uf_group_hp"]  })
      ti({ type = "toggle", db = pre .. "text.name.enabled",   label = L["uf_name_enable"] })
      ti({ type = "anchor_grid", db = pre .. "text.name.anchor", label = L["uf_name_anchor"] })
      ti({ type = "slider", db = pre .. "text.name.size",
        label = L["uf_name_size"], min = 6, max = 24, step = 1 })
      ti({ type = "slider", db = pre .. "text.name.offsetX",
        label = L["uf_name_offset_x"], min = -50, max = 50, step = 1 })
      ti({ type = "slider", db = pre .. "text.name.offsetY",
        label = L["uf_name_offset_y"], min = -50, max = 50, step = 1 })
      ti({ type = "divider" })
      ti({ type = "toggle", db = pre .. "text.hp.enabled",     label = L["uf_hp_text_enable"] })
      ti({ type = "anchor_grid", db = pre .. "text.hp.anchor", label = L["uf_hp_text_anchor"] })
      ti({ type = "slider", db = pre .. "text.hp.size",
        label = L["uf_hp_text_size"], min = 6, max = 24, step = 1 })
      ti({ type = "button_select", db = pre .. "text.hp.format",
        label = L["uf_hp_text_format"], values = TEXT_FORMATS })
      ti({ type = "slider", db = pre .. "text.hp.offsetX",
        label = L["uf_hp_text_offset_x"], min = -50, max = 50, step = 1 })
      ti({ type = "slider", db = pre .. "text.hp.offsetY",
        label = L["uf_hp_text_offset_y"], min = -50, max = 50, step = 1 })
      if cap.level then
        ti({ type = "divider" })
        ti({ type = "toggle", db = pre .. "text.level.enabled", label = L["uf_level_enable"] })
        ti({ type = "slider", db = pre .. "text.level.size",
          label = L["uf_level_size"], min = 6, max = 24, step = 1 })
      end
    end

    if cap.power then
      ti({ type = "header", label =  L["uf_group_energy"]  })
      ti({ type = "toggle", db = pre .. "text.power.enabled",     label = L["uf_power_enable"] })
      ti({ type = "anchor_grid", db = pre .. "text.power.anchor", label = L["uf_power_anchor"] })
      ti({ type = "slider", db = pre .. "text.power.size",
        label = L["uf_power_size"], min = 6, max = 24, step = 1 })
      ti({ type = "button_select", db = pre .. "text.power.format",
        label = L["uf_power_format"], values = TEXT_FORMATS_POWER })
    end

    ins({ type = "group", label = L["uf_hdr_text"], collapsed = true, children = tc })
  end

  -- ═══ FOND ═══
  do
    local fc = {}
    local function fi(s) fc[#fc + 1] = s end
    local hasBg = false

    if cap.hpBgKeys then
      for _, bgKey in ipairs(cap.hpBgKeys) do
        local bgPre = pre .. "backgrounds." .. bgKey .. "."
        fi({ type = "header", label =  L["uf_group_hp"]  })
        fi({ type = "toggle", db = bgPre .. "enabled", label = L["uf_suffix_enable"] })
        fi({ type = "slider", db = bgPre .. "alpha",
          label = L["uf_suffix_opacity"], min = 0, max = 1, step = 0.05, decimals = 2 })
        fi({ type = "color",  db = bgPre .. "color",   label = L["uf_suffix_color"] })
        hasBg = true
      end
    end

    if cap.energyBgKeys then
      for _, bgKey in ipairs(cap.energyBgKeys) do
        if bgKey == "power" then
          local bgPre = pre .. "backgrounds." .. bgKey .. "."
          local bgL = ENERGY_BG_LABELS[bgKey] or bgKey
          fi({ type = "header", label =  L["uf_group_energy"]  })
          fi({ type = "toggle", db = bgPre .. "enabled",
            label = bgL .. " - " .. L["uf_suffix_enable"] })
          fi({ type = "slider", db = bgPre .. "alpha",
            label = bgL .. " - " .. L["uf_suffix_opacity"], min = 0, max = 1, step = 0.05, decimals = 2 })
          fi({ type = "color",  db = bgPre .. "color",
            label = bgL .. " - " .. L["uf_suffix_color"] })
          hasBg = true
        end
      end

      for _, bgKey in ipairs(cap.energyBgKeys) do
        if bgKey == "classPower" or bgKey == "segments" then
          local bgPre = pre .. "backgrounds." .. bgKey .. "."
          local bgL = ENERGY_BG_LABELS[bgKey] or bgKey
          fi({ type = "header", label =  (L["uf_group_class_power"] or "Barre de classe")  })
          fi({ type = "toggle", db = bgPre .. "enabled",
            label = bgL .. " - " .. L["uf_suffix_enable"] })
          fi({ type = "slider", db = bgPre .. "alpha",
            label = bgL .. " - " .. L["uf_suffix_opacity"], min = 0, max = 1, step = 0.05, decimals = 2 })
          fi({ type = "color",  db = bgPre .. "color",
            label = bgL .. " - " .. L["uf_suffix_color"] })
          hasBg = true
        end
      end
    end

    if hasBg then
      ins({ type = "group", label = L["uf_hdr_bg"], collapsed = true, children = fc })
    end
  end

  -- ═══ BARRE D'INCANTATION ═══
  if cap.cast then
    local cc = {}
    local function ci(s) cc[#cc + 1] = s end
    local cp = pre .. "cast."

    ci({ type = "toggle", db = cp .. "enabled", label = L["uf_cast_enable"] })

    ci({ type = "header", label =  L["uf_hdr_color"]  })
    ci({ type = "color", db = cp .. "colors.normal",           label = L["uf_cast_normal"] })
    ci({ type = "color", db = cp .. "colors.notInterruptible", label = L["uf_cast_not_interrupt"] })

    ci({ type = "header", label =  L["uf_hdr_size"]  })
    ci({ type = "slider", db = cp .. "w",
      label = L["uf_cast_width"], min = 50, max = 500, step = 1 })
    ci({ type = "slider", db = cp .. "h",
      label = L["uf_cast_height"], min = 8, max = 40, step = 1 })
    ci({ type = "dropdown", db = cp .. "anchor",
      label = L["uf_cast_anchor"], values = CAST_ANCHORS })
    ci({ type = "slider", db = cp .. "x",
      label = L["uf_cast_offset_x"], min = -200, max = 200, step = 1 })
    ci({ type = "slider", db = cp .. "y",
      label = L["uf_cast_offset_y"], min = -200, max = 200, step = 1 })

    ci({ type = "header", label =  L["uf_hdr_text"]  })
    ci({ type = "slider", db = cp .. "spellSize",
      label = L["uf_cast_spell_size"], min = 6, max = 20, step = 1 })
    ci({ type = "slider", db = cp .. "timeSize",
      label = L["uf_cast_time_size"], min = 6, max = 20, step = 1 })

    if cap.castBgKeys then
      ci({ type = "header", label =  L["uf_hdr_bg"]  })
      for _, bgKey in ipairs(cap.castBgKeys) do
        local bgPre = pre .. "backgrounds." .. bgKey .. "."
        ci({ type = "toggle", db = bgPre .. "enabled", label = L["uf_suffix_enable"] })
        ci({ type = "slider", db = bgPre .. "alpha",
          label = L["uf_suffix_opacity"], min = 0, max = 1, step = 0.05, decimals = 2 })
        ci({ type = "color",  db = bgPre .. "color",   label = L["uf_suffix_color"] })
      end
    end

    ins({ type = "group", label = L["uf_group_cast"], collapsed = true, children = cc })
  end

  -- ═══ OPTIONS RAID ═══
  if cap.raid then
    local rc = {}
    rc[#rc + 1] = { type = "slider", db = pre .. "columns",
      label = L["uf_columns"], min = 1, max = 10, step = 1 }
    rc[#rc + 1] = { type = "slider", db = pre .. "spacing",
      label = L["uf_h_spacing"], min = 0, max = 20, step = 1 }
    rc[#rc + 1] = { type = "slider", db = pre .. "rowSpacing",
      label = L["uf_v_spacing"], min = 0, max = 20, step = 1 }
    rc[#rc + 1] = { type = "divider" }
    rc[#rc + 1] = { type = "toggle", db = pre .. "groupBySubgroup",
      label = L["uf_group_by_subgroup"] }
    rc[#rc + 1] = { type = "slider", db = pre .. "groupSpacing",
      label = L["uf_group_spacing"], min = 0, max = 30, step = 1 }
    rc[#rc + 1] = { type = "toggle", db = pre .. "showGroupLabel",
      label = L["uf_show_group_label"] }
    rc[#rc + 1] = { type = "slider", db = pre .. "groupLabelSize",
      label = L["uf_group_label_size"], min = 6, max = 18, step = 1 }
    rc[#rc + 1] = { type = "divider" }
    rc[#rc + 1] = { type = "toggle", db = pre .. "showRole",   label = L["uf_show_role"] }
    rc[#rc + 1] = { type = "slider", db = pre .. "roleIconOffsetX",
      label = L["uf_role_offset_x"], min = -30, max = 30, step = 1 }
    rc[#rc + 1] = { type = "slider", db = pre .. "roleIconOffsetY",
      label = L["uf_role_offset_y"], min = -30, max = 30, step = 1 }
    rc[#rc + 1] = { type = "toggle", db = pre .. "showLeader", label = L["uf_show_leader"] }

    ins({ type = "group", label = L["uf_group_raid"], collapsed = true, children = rc })
  end

  -- ═══ OPTIONS GROUPE ═══
  if cap.groupUnit then
    local gc = {}
    gc[#gc + 1] = { type = "slider", db = pre .. "spacing",
      label = L["uf_member_spacing"], min = 0, max = 20, step = 1 }
    gc[#gc + 1] = { type = "divider" }
    gc[#gc + 1] = { type = "toggle", db = pre .. "showRole",   label = L["uf_show_role"] }
    gc[#gc + 1] = { type = "slider", db = pre .. "roleIconOffsetX",
      label = L["uf_role_offset_x"], min = -30, max = 30, step = 1 }
    gc[#gc + 1] = { type = "slider", db = pre .. "roleIconOffsetY",
      label = L["uf_role_offset_y"], min = -30, max = 30, step = 1 }
    gc[#gc + 1] = { type = "toggle", db = pre .. "showLeader", label = L["uf_show_leader"] }

    ins({ type = "group", label = L["uf_group_group"], collapsed = true, children = gc })
  end

  -- ═══ AURAS ═══
  if cap.auras then
    local ac = {}
    ac[#ac + 1] = { type = "header", label =  L["uf_hdr_buffs"]  }
    ac[#ac + 1] = { type = "toggle", db = pre .. "buffs.enabled",
      label = L["uf_buffs_enable"] }
    ac[#ac + 1] = { type = "toggle", db = pre .. "buffs.combatOnly",
      label = L["uf_buffs_combat_only"] }
    ac[#ac + 1] = { type = "slider", db = pre .. "buffs.count",
      label = L["uf_buffs_count"], min = 1, max = 40, step = 1 }
    ac[#ac + 1] = { type = "slider", db = pre .. "buffs.iconSize",
      label = L["uf_buffs_icon_size"], min = 12, max = 40, step = 1 }
    ac[#ac + 1] = { type = "slider", db = pre .. "buffs.spacing",
      label = L["uf_buffs_spacing"], min = 0, max = 10, step = 1 }
    ac[#ac + 1] = { type = "dropdown", db = pre .. "buffs.growDirection",
      label = L["uf_auras_direction"], values = {
        { value = "RIGHT", text = L["uf_dir_right"] },
        { value = "LEFT",  text = L["uf_dir_left"] },
        { value = "DOWN",  text = L["uf_dir_down"] },
        { value = "UP",    text = L["uf_dir_up"] },
      }}
    ac[#ac + 1] = { type = "divider" }
    ac[#ac + 1] = { type = "header", label =  L["uf_hdr_debuffs"]  }
    ac[#ac + 1] = { type = "toggle", db = pre .. "debuffs.enabled",
      label = L["uf_debuffs_enable"] }
    ac[#ac + 1] = { type = "slider", db = pre .. "debuffs.count",
      label = L["uf_debuffs_count"], min = 1, max = 40, step = 1 }
    ac[#ac + 1] = { type = "slider", db = pre .. "debuffs.iconSize",
      label = L["uf_debuffs_icon_size"], min = 12, max = 40, step = 1 }
    ac[#ac + 1] = { type = "slider", db = pre .. "debuffs.spacing",
      label = L["uf_debuffs_spacing"], min = 0, max = 10, step = 1 }
    ac[#ac + 1] = { type = "dropdown", db = pre .. "debuffs.growDirection",
      label = L["uf_auras_direction"], values = {
        { value = "RIGHT", text = L["uf_dir_right"] },
        { value = "LEFT",  text = L["uf_dir_left"] },
        { value = "DOWN",  text = L["uf_dir_down"] },
        { value = "UP",    text = L["uf_dir_up"] },
      }}

    ins({ type = "group", label = L["uf_group_auras"], collapsed = true, children = ac })
  end

  -- ═══ EXTRA (range) ═══
  if cap.extra and cap.range then
    local xc = {}
    xc[#xc + 1] = { type = "toggle", db = pre .. "rangeEnabled",
      label = L["uf_range_enable"] }
    xc[#xc + 1] = { type = "slider", db = pre .. "outOfRangeAlpha",
      label = L["uf_range_alpha"], min = 0, max = 1, step = 0.05, decimals = 2 }

    ins({ type = "group", label = L["uf_group_extra"], collapsed = true, children = xc })
  end

  return specs
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

  table.insert(tabs, 1, { key = "_general", label = L["uf_tab_general"], specs = general })
  return tabs
end

-- ============================================================================
-- PAGE
-- ============================================================================

M:RegisterPage("unitframes", 3, L["page_unitframes"], function(container, add)
  _initLocaleConsts()
  local PAD   = T.PAD
  local TAB_H = 26

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

  -- ── Rangée 1 : onglets d'unité ──
  local unitBar = CreateFrame("Frame", nil, container)
  unitBar:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, -PAD)
  unitBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -PAD, -PAD)
  unitBar:SetHeight(TAB_H)

  local sep = container:CreateTexture(nil, "ARTWORK")
  sep:SetPoint("TOPLEFT", unitBar, "BOTTOMLEFT", 0, -4)
  sep:SetPoint("TOPRIGHT", unitBar, "BOTTOMRIGHT", 0, -4)
  sep:SetHeight(1)
  local r, g, b = M:GetClassColor()
  sep:SetColorTexture(r, g, b, 0.35)

  -- ── Rangée 2 : onglets de réglages ──
  local settingsBar = CreateFrame("Frame", nil, container)
  settingsBar:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)
  settingsBar:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -4)
  settingsBar:SetHeight(TAB_H)

  local host = CreateFrame("Frame", nil, container)
  host:SetPoint("TOPLEFT", settingsBar, "BOTTOMLEFT", 0, -8)
  host:SetPoint("TOPRIGHT", settingsBar, "BOTTOMRIGHT", 0, -8)
  add(host)

  local activeTab      = "player"
  local activeSettings = "_general"
  local unitBtns       = {}
  local settingsBtns   = {}
  local settingsTabs   = {}
  local currentWidgets

  local function UpdateHeight()
    local h = PAD + TAB_H + 4 + 1 + 4 + TAB_H + 8 + host:GetHeight() + PAD
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

    local allSpecs = BuildSpecs(activeTab, DoRefresh)
    settingsTabs   = SplitSpecsIntoTabs(allSpecs)
    activeSettings = settingsTabs[1].key

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
        for _, b in ipairs(settingsBtns) do b:SetActive(b._stKey == activeSettings) end
        BuildSettingsContent()
      end)

      btn:SetPoint("TOPLEFT", settingsBar, "TOPLEFT", btnX, 0)
      btnX = btnX + btn:GetWidth() + 2
      settingsBtns[#settingsBtns + 1] = btn
    end

    for _, b in ipairs(settingsBtns) do b:SetActive(b._stKey == activeSettings) end
    BuildSettingsContent()
  end

  -- ── Boutons d'unité ──
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
      SetPreview(activeTab, false)
      activeTab = self._key
      for _, b in ipairs(unitBtns) do b:SetActive(b._key == activeTab) end
      BuildSettingsTabBtns()
    end)

    btn:SetPoint("TOPLEFT", unitBar, "TOPLEFT", btnX, 0)
    btnX = btnX + btn:GetWidth() + 2
    unitBtns[#unitBtns + 1] = btn
  end

  for _, b in ipairs(unitBtns) do b:SetActive(b._key == activeTab) end
  BuildSettingsTabBtns()

  container:HookScript("OnHide", function()
    DisableAllPreviews()
  end)
end)

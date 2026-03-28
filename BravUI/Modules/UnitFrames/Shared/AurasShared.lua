-- BravUI/Modules/UnitFrames/AurasShared.lua
-- Shared aura display factory
--
-- Midnight 12.0: DurationObject → SetCooldownFromDurationObject pour spirals + timer.
-- Timer text rendu nativement par CooldownFrameTemplate (font custom via SetCountdownFont).
-- Utilisé par PlayerAuras.lua et TargetAuras.lua.

if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then return end

BravUI.AurasShared = {}
local AS = BravUI.AurasShared

local FONT_PATH = BravLib.Media.Get("font", "uf") or BravLib.Media.Get("font", "default") or STANDARD_TEXT_FONT
local TEX       = "Interface/Buttons/WHITE8x8"

local U             = BravUI.Utils
local GetClassColor = U.GetClassColor

-- Small font for cooldown countdown text (fits inside 22px icons)
local CD_FONT = CreateFont("BravUI_AuraCooldownFont")
pcall(function() CD_FONT:SetFont(FONT_PATH, 7, "OUTLINE") end)

-- Hidden FontString for secret value roundtrips (combatOnly filter)
local _helperFS = UIParent:CreateFontString(nil, "BACKGROUND")
pcall(function() _helperFS:SetFont(FONT_PATH, 10, "OUTLINE") end)
_helperFS:Hide()

-- ============================================================================
-- DEBUFF TYPE COLORS
-- ============================================================================
local DEBUFF_COLORS = {
  Magic   = { 0.20, 0.60, 1.00 },
  Curse   = { 0.60, 0.00, 1.00 },
  Poison  = { 0.00, 0.60, 0.10 },
  Disease = { 0.60, 0.40, 0.00 },
}
local DEBUFF_DEFAULT = { 0.80, 0.00, 0.00 }

-- ============================================================================
-- BORDER COLOR HELPERS
-- ============================================================================
local function SetSlotBorderColor(slot, r, g, b)
  for _, tex in pairs(slot.borders) do
    tex:SetVertexColor(r, g, b, 1)
  end
end

local function SetClassBorder(slot)
  local r, g, b = GetClassColor("player")
  SetSlotBorderColor(slot, r, g, b)
end

local function SafeSetDebuffBorderColor(slot, dispelName)
  local color = DEBUFF_DEFAULT
  for dtype, c in pairs(DEBUFF_COLORS) do
    local ok, match = pcall(function() return dispelName == dtype end)
    if ok and match then color = c; break end
  end
  SetSlotBorderColor(slot, color[1], color[2], color[3])
end

-- ============================================================================
-- STACK COUNT (Midnight secret-safe)
-- ============================================================================
local function SetStackCount(slot, applications)
  local ok = pcall(function()
    slot.count:SetText(C_StringUtil.TruncateWhenZero(applications))
  end)
  if ok then
    pcall(function()
      local txt = slot.count:GetText()
      if txt == "1" then slot.count:SetText("") end
    end)
    return
  end
  pcall(function() slot.count:SetText(applications) end)
  pcall(function()
    local txt = slot.count:GetText()
    if txt == nil or txt == "" or txt == "0" or txt == "1" then
      slot.count:SetText("")
    end
  end)
end

-- ============================================================================
-- COOLDOWN (Midnight 12.0: DurationObject → SetCooldownFromDurationObject)
-- ============================================================================
local function SetSlotCooldown(slot, aura, unit)
  if not slot.cd then return end

  local ok = pcall(function()
    local duration = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
    if duration then
      slot.cd:SetCooldownFromDurationObject(duration)
    else
      slot.cd:Clear()
    end
  end)
  if ok then return end

  local ok2 = pcall(function()
    slot.cd:SetCooldownFromExpirationTime(aura.expirationTime, aura.duration)
  end)
  if not ok2 then
    pcall(function()
      slot.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
    end)
  end
end

-- ============================================================================
-- SLOT FACTORY
-- ============================================================================
local function CreateIconSlot(parent, size, unitToken)
  local slot = CreateFrame("Frame", nil, parent)
  slot:SetSize(size, size)
  slot:EnableMouse(true)
  slot:SetClipsChildren(true)

  -- Black background
  local bg = slot:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(0, 0, 0, 1)
  bg:SetAllPoints()
  slot.bg = bg

  -- Spell icon
  local tex = slot:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  slot.tex = tex

  -- 1px border (4 textures for per-edge coloring)
  local borders = {}
  local PU = PixelUtil

  local function MakeBorderTex()
    local t = slot:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX)
    return t
  end

  borders.top = MakeBorderTex()
  PU.SetPoint(borders.top, "TOPLEFT",  slot, "TOPLEFT",  -1,  1)
  PU.SetPoint(borders.top, "TOPRIGHT", slot, "TOPRIGHT",  1,  1)
  PU.SetHeight(borders.top, 1)

  borders.bottom = MakeBorderTex()
  PU.SetPoint(borders.bottom, "BOTTOMLEFT",  slot, "BOTTOMLEFT",  -1, -1)
  PU.SetPoint(borders.bottom, "BOTTOMRIGHT", slot, "BOTTOMRIGHT",  1, -1)
  PU.SetHeight(borders.bottom, 1)

  borders.left = MakeBorderTex()
  PU.SetPoint(borders.left, "TOPLEFT",    slot, "TOPLEFT",    -1,  1)
  PU.SetPoint(borders.left, "BOTTOMLEFT", slot, "BOTTOMLEFT", -1, -1)
  PU.SetWidth(borders.left, 1)

  borders.right = MakeBorderTex()
  PU.SetPoint(borders.right, "TOPRIGHT",    slot, "TOPRIGHT",    1,  1)
  PU.SetPoint(borders.right, "BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
  PU.SetWidth(borders.right, 1)

  slot.borders = borders

  -- Cooldown spiral + native timer text
  local cd = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
  cd:SetAllPoints()
  cd:SetDrawBling(false)
  cd:SetDrawEdge(false)
  pcall(function() cd:SetHideCountdownNumbers(false) end)
  pcall(function() cd:SetCountdownFont("BravUI_AuraCooldownFont") end)
  pcall(function() cd:SetUseAuraDisplayTime(true) end)

  local function StyleCDText(self)
    pcall(function()
      local fs = self:GetCountdownFontString()
      if fs then fs:SetFont(FONT_PATH, 7, "OUTLINE") end
    end)
  end
  pcall(function() hooksecurefunc(cd, "SetCooldownFromDurationObject",  StyleCDText) end)
  pcall(function() hooksecurefunc(cd, "SetCooldownFromExpirationTime",  StyleCDText) end)
  pcall(function() hooksecurefunc(cd, "SetCooldown",                    StyleCDText) end)

  slot.cd = cd

  -- Stack count overlay (above cooldown)
  local overlay = CreateFrame("Frame", nil, slot)
  overlay:SetAllPoints()
  overlay:SetFrameLevel(slot:GetFrameLevel() + 3)

  local count = overlay:CreateFontString(nil, "OVERLAY")
  pcall(function() count:SetFont(FONT_PATH, 10, "OUTLINE") end)
  count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
  count:SetJustifyH("RIGHT")
  count:SetText("")
  slot.count = count

  -- Tooltip
  slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local u    = self._unit or unitToken
    local ok2

    if self._auraInstanceID then
      if self._isDebuff then
        ok2 = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, u, self._auraInstanceID)
      else
        ok2 = pcall(GameTooltip.SetUnitBuffByAuraInstanceID,  GameTooltip, u, self._auraInstanceID)
      end
      if ok2 then GameTooltip:Show(); return end
    end

    if not self._auraIndex then return end
    if self._isDebuff then
      ok2 = pcall(GameTooltip.SetUnitDebuff, GameTooltip, u, self._auraIndex)
    else
      ok2 = pcall(GameTooltip.SetUnitBuff,   GameTooltip, u, self._auraIndex)
    end
    if not ok2 then
      pcall(GameTooltip.SetUnitAura, GameTooltip, u, self._auraIndex,
        self._isDebuff and "HARMFUL" or "HELPFUL")
    end
    GameTooltip:Show()
  end)
  slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

  slot:Hide()
  return slot
end

-- ============================================================================
-- SLOT POOL / LAYOUT HELPERS
-- ============================================================================
local function EnsureSlots(pool, parent, count, size, unitToken)
  for i = #pool + 1, count do
    pool[i] = CreateIconSlot(parent, size, unitToken)
  end
  for i = 1, #pool do pool[i]:SetSize(size, size) end
end

local function HideUnusedSlots(pool, usedCount)
  for i = usedCount + 1, #pool do
    pool[i]:Hide()
    if pool[i].cd then pcall(function() pool[i].cd:Clear() end) end
  end
end

local function LayoutSlot(slot, container, index, cfg)
  local size    = cfg.iconSize    or 22
  local spacing = cfg.spacing     or 2
  local offset  = (index - 1) * (size + spacing)
  local dir     = cfg.growDirection or "RIGHT"
  slot:ClearAllPoints()
  if     dir == "LEFT"  then slot:SetPoint("TOPRIGHT",    container, "TOPRIGHT",    -offset, 0)
  elseif dir == "DOWN"  then slot:SetPoint("TOPLEFT",     container, "TOPLEFT",     0, -offset)
  elseif dir == "UP"    then slot:SetPoint("BOTTOMLEFT",  container, "BOTTOMLEFT",  0,  offset)
  else                       slot:SetPoint("TOPLEFT",     container, "TOPLEFT",     offset, 0)
  end
end

-- ============================================================================
-- EXPOSE HELPERS
-- ============================================================================
AS.SetClassBorder           = SetClassBorder
AS.SafeSetDebuffBorderColor = SafeSetDebuffBorderColor
AS.SetStackCount            = SetStackCount
AS.SetSlotCooldown          = SetSlotCooldown

-- ============================================================================
-- AURA BAR FACTORY
-- ============================================================================
function AS.CreateAuraBar(opts)
  local mod       = {}
  local slots     = {}
  local container = nil

  local function EnsureContainer()
    if container then return end
    container = CreateFrame("Frame", opts.frameName, UIParent)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(10)
    container:SetClampedToScreen(true)
    container:SetSize(200, 22)
    mod.Container = container
  end

  local function UpdateContainerSize(cfg, count)
    if not container then return end
    local size    = cfg.iconSize    or 22
    local spacing = cfg.spacing     or 2
    local total   = count * size + math.max(count - 1, 0) * spacing
    local dir     = cfg.growDirection or "RIGHT"
    if dir == "UP" or dir == "DOWN" then
      container:SetSize(size, math.max(total, 1))
    else
      container:SetSize(math.max(total, 1), size)
    end
  end

  local function Update()
    local cfg = opts.getCfg()
    if not cfg or cfg.enabled == false then
      if container then container:Hide() end
      return
    end

    EnsureContainer()

    local size     = cfg.iconSize or 22
    local maxCount = cfg.count    or 8

    UpdateContainerSize(cfg, maxCount)

    local okE, exists = pcall(UnitExists, opts.unit)
    if not okE or not exists then container:Hide(); return end

    EnsureSlots(slots, container, maxCount, size, opts.unit)

    local idx        = 0
    local getter     = opts.isDebuff
      and C_UnitAuras.GetDebuffDataByIndex
      or  C_UnitAuras.GetBuffDataByIndex
    local combatOnly = cfg.combatOnly

    for i = 1, 40 do
      if idx >= maxCount then break end
      local aura = getter(opts.unit, i)
      if not aura then break end

      -- combatOnly: skip permanent buffs (duration == 0)
      local skip = false
      if combatOnly then
        _helperFS:SetText("x")
        pcall(function()
          _helperFS:SetText(C_StringUtil.TruncateWhenZero(aura.duration))
        end)
        local txt
        pcall(function() txt = _helperFS:GetText() end)
        local isPerm  = false
        local okCmp   = pcall(function()
          if not txt or txt == "" then isPerm = true end
        end)
        if isPerm then skip = true end
      end

      if not skip then
        idx = idx + 1
        local slot = slots[idx]

        pcall(function() slot.tex:SetTexture(aura.icon) end)
        SetStackCount(slot, aura.applications)
        SetSlotCooldown(slot, aura, opts.unit)

        if opts.isDebuff then
          SafeSetDebuffBorderColor(slot, aura.dispelName)
        else
          SetClassBorder(slot)
        end

        slot._auraInstanceID = aura.auraInstanceID
        slot._auraIndex      = i
        slot._isDebuff       = opts.isDebuff
        slot._unit           = opts.unit

        LayoutSlot(slot, container, idx, cfg)
        slot:Show()
      end
    end

    HideUnusedSlots(slots, idx)

    if idx == 0 then container:Hide() else container:Show() end
  end

  local function ApplyFromDB()
    local cfg = opts.getCfg()
    if not cfg then return end

    EnsureContainer()

    -- Restaurer position sauvegardée via BravLib.API (système Move v2)
    local pos = BravLib.API.Get("positions", opts.moverName)
    if pos then
      container:ClearAllPoints()
      container:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
      return
    end

    container:ClearAllPoints()
    if opts.defaultAnchor then
      local anchor = opts.defaultAnchor()
      if anchor then
        container:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
        return
      end
    end
    container:SetPoint("CENTER", UIParent, "CENTER",
      opts.defaultPos.x, opts.defaultPos.y)
  end

  mod.Update          = Update
  mod.ApplyFromDB     = ApplyFromDB
  mod.EnsureContainer = EnsureContainer

  mod.Refresh = function()
    ApplyFromDB()
    Update()
  end

  -- Enregistrement du mover (système Move v2)
  mod.RegisterMover = function()
    EnsureContainer()
    BravUI.Move.Enable(container, opts.moverName)
  end

  return mod
end

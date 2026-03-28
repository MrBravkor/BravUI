-- BravUI/Modules/UnitFrames/Group/Group.lua
-- Group UnitFrames (Party 1-4)
-- HP: mirror Blizzard statusbar value (abbrev) | %: mirror Blizzard text (no math)

BravUI.Frames = BravUI.Frames or {}

local TEX = "Interface/Buttons/WHITE8x8"

local ROLE_TEX = {
  TANK    = BravLib.Media.Get("icon", "tank"),
  DAMAGER = BravLib.Media.Get("icon", "dps"),
  HEALER  = BravLib.Media.Get("icon", "healer"),
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================
local U                   = BravUI.Utils
local ReadText            = U.ReadText
local Abbrev              = U.AbbrevForSetText
local Create1pxBorder     = U.Create1pxBorder
local CreateBarBackground = U.CreateBarBackgroundTexture
local CreateIconFrame     = U.CreateIconFrame
local ClampNum            = U.ClampNum
local SafeUnitExists      = U.SafeUnitExists
local SafeUnitIsConnected = U.SafeUnitIsConnected
local SafeUnitIsDead      = U.SafeUnitIsDead

local function IsUnitOutOfRange(unit)
  return U.IsFriendlyOutOfRange(unit)
end

-- ============================================================================
-- CONSTANTS / DEFAULTS
-- ============================================================================
local MAX_MEMBERS     = 4
local DEFAULT_SPACING = 8
local DEFAULT_WIDTH   = 220
local ROLE_SIZE       = 18

local DEFAULT_HEIGHTS = {
  classPower = 7,
  hp         = 26,
  power      = 10,
}

local DEFAULT_BARS = {
  classPower = { x = 0, y =   0, width = 220, height =  7 },
  hp         = { x = 0, y =  -7, width = 220, height = 26 },
  power      = { x = 0, y = -33, width = 220, height = 10 },
}

-- ============================================================================
-- DB CONFIG GETTERS
-- ============================================================================
local GetConfig, GetConfigValue, GetHeightConfig, GetColorConfig, GetTextConfig = U.MakeConfigGetters("group")

local function SetRoleTex(iconTex, role)
  if not iconTex then return end
  local tex = ROLE_TEX[role]
  if tex then
    iconTex:SetTexture(tex)
    iconTex:SetVertexColor(1, 1, 1, 1)
    iconTex:Show()
  else
    iconTex:Hide()
  end
end

-- ============================================================================
-- BLIZZARD PARTY LOOKUP
-- ============================================================================
local function GetPartyMemberFrame(i)
  if PartyFrame and PartyFrame["MemberFrame" .. i] then
    return PartyFrame["MemberFrame" .. i]
  end
  if CompactPartyFrame and CompactPartyFrame["MemberFrame" .. i] then
    return CompactPartyFrame["MemberFrame" .. i]
  end
  return nil
end

local function GetBlizzardPartyHealthBar(i)
  local mf = GetPartyMemberFrame(i)
  if mf then
    return mf.healthbar or mf.HealthBar or (mf.Content and mf.Content.HealthBar) or mf.healthBar
  end

  local g1 = _G["PartyFrameMember" .. i]
  if g1 and g1.healthbar then return g1.healthbar end
  if _G["PartyMemberFrame" .. i .. "HealthBar"] then return _G["PartyMemberFrame" .. i .. "HealthBar"] end

  return nil
end

-- ============================================================================
-- LAYOUT HELPERS
-- ============================================================================
local function GetLayout()
  local cfg = GetConfig()
  if cfg then
    return { spacing = cfg.spacing or DEFAULT_SPACING, bars = cfg.bars or DEFAULT_BARS }
  end
  return { spacing = DEFAULT_SPACING, bars = DEFAULT_BARS }
end

-- ============================================================================
-- CONTAINER
-- ============================================================================
local container = CreateFrame("Frame", "BravUI_GroupFrame", UIParent)
container:SetSize(320, 260)
container:SetPoint("CENTER", UIParent, "CENTER", -350, -200)
container:SetClampedToScreen(true)
container:EnableMouse(true)
container:SetMovable(true)
container:RegisterForDrag("LeftButton")

container:SetScript("OnDragStart", function(self)
  if InCombatLockdown() then return end
  local cfg = GetConfig()
  if cfg and cfg.locked then return end
  self:StartMoving()
end)
container:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local cfg = GetConfig()
  if cfg then
    local _, _, _, x, y = self:GetPoint(1)
    cfg.posX = math.floor((x or 0) + 0.5)
    cfg.posY = math.floor((y or 0) + 0.5)
  end
end)

BravUI.Frames.Group           = BravUI.Frames.Group or {}
BravUI.Frames.Group.Root      = container
BravUI.Frames.Group.Container = container
BravUI.Frames.Group.Members   = BravUI.Frames.Group.Members or {}

local previewMode = false

-- ============================================================================
-- MEMBER FACTORY
-- ============================================================================
local function CreatePartyMember(i)
  local unit = "party" .. i

  local f = CreateFrame("Frame", "BravUI_PartyMember" .. i, container)
  f.unit  = unit
  f.index = i
  f:Hide()

  local classPowerFrame = CreateFrame("Frame", nil, f)
  local hpFrame         = CreateFrame("Frame", nil, f)
  local powerFrame      = CreateFrame("Frame", nil, f)

  classPowerFrame:SetPoint("TOPLEFT", f, "TOPLEFT", DEFAULT_BARS.classPower.x, DEFAULT_BARS.classPower.y)
  classPowerFrame:SetSize(DEFAULT_BARS.classPower.width, DEFAULT_BARS.classPower.height)

  hpFrame:SetPoint("TOPLEFT", f, "TOPLEFT", DEFAULT_BARS.hp.x, DEFAULT_BARS.hp.y)
  hpFrame:SetSize(DEFAULT_BARS.hp.width, DEFAULT_BARS.hp.height)

  powerFrame:SetPoint("TOPLEFT", f, "TOPLEFT", DEFAULT_BARS.power.x, DEFAULT_BARS.power.y)
  powerFrame:SetSize(DEFAULT_BARS.power.width, DEFAULT_BARS.power.height)

  local classPower = CreateFrame("StatusBar", nil, classPowerFrame)
  classPower:SetAllPoints(classPowerFrame)
  classPower:SetStatusBarTexture(TEX)
  classPower:SetMinMaxValues(0, 1)
  classPower:SetValue(0)
  classPower:Hide()
  CreateBarBackground(classPowerFrame, classPower)
  Create1pxBorder(classPower)

  local hp = CreateFrame("StatusBar", nil, hpFrame)
  hp:SetAllPoints(hpFrame)
  hp:SetStatusBarTexture(TEX)
  hp:SetMinMaxValues(0, 1)
  CreateBarBackground(hpFrame, hp)
  Create1pxBorder(hp)

  local roleHolder = CreateIconFrame(hp, ROLE_SIZE, "CENTER", hp, 0, 0)
  local roleIcon   = roleHolder.tex

  local leaderIcon = U.CreateLeaderIcon(hp)
  local assistIcon = U.CreateAssistIcon(hp, leaderIcon)
  local rezHolder  = U.CreateRezIcon(hp)
  local wmHolder   = U.CreateWMIcon(hp)

  local hpNameText  = U.CreateText(hp, "LEFT",  "LEFT",  13,  6, 0)
  local hpStatsText = U.CreateText(hp, "RIGHT", "RIGHT", 13, -6, 0)

  local power = CreateFrame("StatusBar", nil, powerFrame)
  power:SetAllPoints(powerFrame)
  power:SetStatusBarTexture(TEX)
  power:SetMinMaxValues(0, 1)
  CreateBarBackground(powerFrame, power)
  Create1pxBorder(power)

  local powerText = U.CreateText(power, "CENTER", "CENTER", 11, 0, 0)

  local function MakeDraggable(target, parent, w, h)
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(w, h)
    wrapper:SetPoint("CENTER", target, "CENTER", 0, 0)
    wrapper:SetMovable(true)
    wrapper:EnableMouse(true)
    wrapper:SetClampedToScreen(true)
    wrapper:RegisterForDrag("LeftButton")
    wrapper:SetScript("OnDragStart", function(self)
      if InCombatLockdown() then return end
      self:StartMoving()
    end)
    wrapper:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      target:ClearAllPoints()
      target:SetPoint("CENTER", self, "CENTER", 0, 0)
    end)
    return wrapper
  end

  local _ = MakeDraggable(hpNameText,  hp,    100, 26)
  local _ = MakeDraggable(hpStatsText, hp,    100, 26)
  local _ = MakeDraggable(powerText,   power,  80, 18)

  f.ClassPowerFrame = classPowerFrame
  f.HPFrame         = hpFrame
  f.PowerFrame      = powerFrame
  f.ClassPowerBar   = classPower
  f.HPBar           = hp
  f.PowerBar        = power
  f.HPNameText      = hpNameText
  f.HPStatsText     = hpStatsText
  f.HPText          = hpNameText  -- compat
  f.PowerText       = powerText
  f.RoleHolder      = roleHolder
  f.RoleIcon        = roleIcon
  f.LeaderIcon      = leaderIcon
  f.AssistIcon      = assistIcon
  f.RezHolder       = rezHolder
  f.WMHolder        = wmHolder

  f.__hooked  = false
  f.__bbar    = nil
  f.__hp_k    = "?"
  f.__hp_pct  = "?"

  local function RefreshHPText()
    if previewMode then return end
    local name = UnitName(f.unit)
    if U.TruncateName then name = U.TruncateName(name, 10) end
    hpNameText:SetText(name)
    pcall(function()
      hpStatsText:SetText((f.__hp_k or "?") .. " | " .. (f.__hp_pct or "?"))
    end)
  end

  local function PullPercentFromBlizzard()
    local bbar = f.__bbar
    if not bbar then return end
    pcall(function()
      local pct = ReadText(bbar.LeftText) or ReadText(bbar.TextString) or ReadText(bbar.RightText)
      f.__hp_pct = pct or f.__hp_pct
    end)
  end

  local function PullHPFromBlizzardValue()
    local bbar = f.__bbar
    if not bbar or not bbar.GetValue then return end
    pcall(function() f.__hp_k = Abbrev(bbar:GetValue()) end)
  end

  local function PullAllFromBlizzard()
    PullHPFromBlizzardValue()
    PullPercentFromBlizzard()
    RefreshHPText()
  end

  local function HookFS(fs)
    if not fs or fs.__BravUI_GroupFSHooked then return end
    fs.__BravUI_GroupFSHooked = true
    if hooksecurefunc and fs.SetText then
      hooksecurefunc(fs, "SetText", function()
        PullPercentFromBlizzard()
        RefreshHPText()
      end)
    end
  end

  local function HookBlizzardOnce()
    local bbar = GetBlizzardPartyHealthBar(f.index)
    if not bbar then return end
    if f.__hooked and f.__bbar == bbar then return end
    f.__hooked = true
    f.__bbar   = bbar
    HookFS(bbar.LeftText)
    HookFS(bbar.RightText)
    HookFS(bbar.TextString)
    PullAllFromBlizzard()
  end

  function f:ApplyLayout(layout)
    layout = layout or GetLayout()

    local cpH  = GetHeightConfig("classPower", DEFAULT_HEIGHTS.classPower)
    local hpH  = GetHeightConfig("hp",         DEFAULT_HEIGHTS.hp)
    local pwrH = GetHeightConfig("power",      DEFAULT_HEIGHTS.power)

    local cfg  = GetConfig()
    local w    = (cfg and cfg.width) or DEFAULT_WIDTH
    local showPower       = not cfg or cfg.showPower ~= false
    local showClassPower  = not cfg or cfg.showClassPower ~= false

    self.ClassPowerFrame:ClearAllPoints()
    self.HPFrame:ClearAllPoints()
    self.PowerFrame:ClearAllPoints()

    if showClassPower then
      self.ClassPowerFrame:Show()
      self.ClassPowerFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      self.ClassPowerFrame:SetSize(w, cpH)
    else
      self.ClassPowerFrame:Hide()
      self.ClassPowerFrame:SetHeight(0.001)
    end

    if showClassPower then
      self.HPFrame:SetPoint("TOPLEFT", self.ClassPowerFrame, "BOTTOMLEFT", 0, 0)
    else
      self.HPFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    end
    self.HPFrame:SetSize(w, hpH)

    if showPower then
      self.PowerFrame:Show()
      self.PowerFrame:SetPoint("TOPLEFT", self.HPFrame, "BOTTOMLEFT", 0, 0)
      self.PowerFrame:SetSize(w, pwrH)
    else
      self.PowerFrame:Hide()
      self.PowerFrame:SetHeight(0.001)
    end

    local totalH = hpH
    if showClassPower then totalH = totalH + cpH   end
    if showPower      then totalH = totalH + pwrH  end
    self:SetSize(w, totalH)
  end

  function f:ApplyTextSettings()
    U.ApplyTextConfig(hpNameText,  GetTextConfig("name"),  hp,    "LEFT",   13,  6, 0)
    U.ApplyTextConfig(hpStatsText, GetTextConfig("hp"),    hp,    "RIGHT",  13, -6, 0)
    U.ApplyTextConfig(powerText,   GetTextConfig("power"), power, "CENTER", 11,  0, 0)

    local cfg = GetConfig()
    if cfg then
      local w    = (cfg.width or DEFAULT_WIDTH)
      local halfW = (w / 2) - (ROLE_SIZE / 2)
      local hpH  = GetHeightConfig("hp", DEFAULT_HEIGHTS.hp)
      local halfH = (hpH / 2) - (ROLE_SIZE / 2)

      local rx = cfg.roleIconOffsetX or 0
      local ry = cfg.roleIconOffsetY or 0
      if rx > halfW  then rx = halfW  end
      if rx < -halfW then rx = -halfW end
      if ry > halfH  then ry = halfH  end
      if ry < -halfH then ry = -halfH end

      roleHolder:ClearAllPoints()
      roleHolder:SetPoint("CENTER", hp, "CENTER", rx, ry)
    end
  end

  function f:Update()
    local u = self.unit
    if not SafeUnitExists(u) then
      if not InCombatLockdown() then self:Hide() end
      return
    end
    if not InCombatLockdown() then self:Show() end

    if not SafeUnitIsConnected(u) then
      self:SetAlpha(0.4)
      hp:SetMinMaxValues(0, 1); hp:SetValue(0); hp:SetStatusBarColor(0.3, 0.3, 0.3)
      power:SetMinMaxValues(0, 1); power:SetValue(0); power:SetStatusBarColor(0.2, 0.2, 0.2)
      local name = UnitName(u)
      if U.TruncateName then name = U.TruncateName(name, 10) end
      hpNameText:SetText(name)
      hpStatsText:SetText("Déconnecté")
      powerText:SetText("")
      classPower:Hide(); roleHolder:Hide(); leaderIcon:Hide(); assistIcon:Hide()
      rezHolder:Hide(); wmHolder:Hide()
      return
    end

    if SafeUnitIsDead(u) then
      self:SetAlpha(0.6)
      hp:SetMinMaxValues(0, 1); hp:SetValue(0); hp:SetStatusBarColor(0.4, 0.1, 0.1)
      power:SetMinMaxValues(0, 1); power:SetValue(0); power:SetStatusBarColor(0.2, 0.2, 0.2)
      local name = UnitName(u)
      if U.TruncateName then name = U.TruncateName(name, 10) end
      hpNameText:SetText(name)
      hpStatsText:SetText("Mort")
      powerText:SetText("")
      classPower:Hide(); roleHolder:Hide(); leaderIcon:Hide(); assistIcon:Hide()
      U.UpdateRezIcon(u, rezHolder); wmHolder:Hide()
      return
    end

    HookBlizzardOnce()

    pcall(function()
      hp:SetMinMaxValues(0, UnitHealthMax(u))
      hp:SetValue(UnitHealth(u))
    end)

    f.__hp_k = Abbrev(UnitHealth(u))
    PullPercentFromBlizzard()

    pcall(function()
      power:SetMinMaxValues(0, UnitPowerMax(u))
      power:SetValue(UnitPower(u))
    end)
    powerText:SetText(Abbrev(UnitPower(u)))

    local colorCfg = GetColorConfig()
    U.UpdateHPColor(u, hp, colorCfg)
    U.UpdatePowerColor(u, power, colorCfg)
    RefreshHPText()

    local cfg       = GetConfig()
    local showRole   = (cfg == nil) or (cfg.showRole   ~= false)
    local showLeader = (cfg == nil) or (cfg.showLeader ~= false)

    if showRole then
      local role = UnitGroupRolesAssigned(u)
      if role and role ~= "NONE" then
        SetRoleTex(roleIcon, role); roleHolder:Show()
      else
        roleHolder:Hide()
      end
    else
      roleHolder:Hide()
    end

    if showLeader then
      U.UpdateLeaderIcons(u, leaderIcon, assistIcon)
    else
      leaderIcon:Hide(); assistIcon:Hide()
    end

    classPower:Hide()
    U.UpdateRezIcon(u, rezHolder)
    U.UpdateWMIcon(u, wmHolder)

    local rangeEnabled = (cfg == nil) or (cfg.rangeEnabled ~= false)
    if rangeEnabled then
      local oorAlpha = (cfg and cfg.outOfRangeAlpha) or 0.4
      self:SetAlpha(IsUnitOutOfRange(u) and oorAlpha or 1.0)
    else
      self:SetAlpha(1.0)
    end
  end

  return f
end

-- Create members
local members = {}
for i = 1, MAX_MEMBERS do
  local mf = CreatePartyMember(i)
  members[i] = mf
  BravUI.Frames.Group.Members[i] = mf
end

BravUI.Frames.Group.Frames = members

-- ============================================================================
-- CLICK OVERLAYS
-- ============================================================================
local clickOverlays  = {}
local _overlaysDirty = false

local function SyncClickOverlay(i)
  local overlay = clickOverlays[i]
  local mf      = members[i]
  if not overlay or not mf then return end
  if not U.SyncClickOverlay(overlay, mf) then
    _overlaysDirty = true
    return
  end
  if mf:IsShown() and container:IsShown() then
    overlay:Show()
  else
    overlay:Hide()
  end
end

for i = 1, MAX_MEMBERS do
  clickOverlays[i] = U.CreateClickOverlay("BravUI_PartyClickOverlay" .. i, "party" .. i)
  SyncClickOverlay(i)
end

local function SyncAllClickOverlays()
  for i = 1, MAX_MEMBERS do SyncClickOverlay(i) end
end

BravUI.Frames.Group.ClickOverlays       = clickOverlays
BravUI.Frames.Group.SyncClickOverlays   = SyncAllClickOverlays

-- ============================================================================
-- APPLY FROM DB
-- ============================================================================
local function ApplyFromDB()
  if InCombatLockdown() then return end

  local cfg = GetConfig() or {}

  local s = ClampNum(cfg.scale, 0.5, 2.0, 1.0)
  container:SetScale(s)

  local x = ClampNum(cfg.posX, -2000, 2000, -350)
  local y = ClampNum(cfg.posY, -2000, 2000, -200)
  container:ClearAllPoints()
  container:SetPoint("CENTER", UIParent, "CENTER", x, y)

  local layout  = GetLayout()
  local spacing = layout.spacing or DEFAULT_SPACING
  local w, h    = 0, 0

  for i = 1, MAX_MEMBERS do
    local mf = members[i]
    mf:ApplyLayout(layout)
    mf:ApplyTextSettings()

    mf:ClearAllPoints()
    if i == 1 then
      mf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    else
      mf:SetPoint("TOPLEFT", members[i - 1], "BOTTOMLEFT", 0, -spacing)
    end

    local fw, fh = mf:GetWidth() or 0, mf:GetHeight() or 0
    w = math.max(w, fw)
    h = h + fh
    if i > 1 then h = h + spacing end
  end

  container:SetSize(w, h)
  SyncAllClickOverlays()
end

BravUI.Frames.Group.ApplyFromDB = ApplyFromDB

-- ============================================================================
-- ROLE SORT
-- ============================================================================
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }

local function SortMembersByRole()
  local sortable = {}
  for i = 1, MAX_MEMBERS do
    local unit   = "party" .. i
    local role   = "NONE"
    local exists = SafeUnitExists(unit)
    if exists then role = UnitGroupRolesAssigned(unit) or "NONE" end
    sortable[i] = { index = i, role = role, exists = exists }
  end

  table.sort(sortable, function(a, b)
    if a.exists ~= b.exists then return a.exists end
    local ra = ROLE_ORDER[a.role] or 4
    local rb = ROLE_ORDER[b.role] or 4
    if ra ~= rb then return ra < rb end
    return a.index < b.index
  end)

  for slot = 1, MAX_MEMBERS do
    local info    = sortable[slot]
    local mf      = members[slot]
    mf.unit  = "party" .. info.index
    mf.index = info.index
    local overlay = clickOverlays[slot]
    if overlay and not InCombatLockdown() then
      overlay:SetAttribute("unit", mf.unit)
    end
  end
end

-- ============================================================================
-- UPDATE ALL
-- ============================================================================
local _updateAllPending = false

local function UpdateAll()
  if previewMode then return end

  if InCombatLockdown() then
    _updateAllPending = true
    return
  end

  _updateAllPending = false

  local cfg     = GetConfig()
  local enabled = (cfg == nil) or (cfg.enabled ~= false)
  local inGroup = IsInGroup() and not IsInRaid()
  local show    = enabled and inGroup

  container:SetShown(show)

  if show then
    SortMembersByRole()
    ApplyFromDB()
    for i = 1, MAX_MEMBERS do members[i]:Update() end
  else
    for i = 1, MAX_MEMBERS do members[i]:Hide() end
  end

  _overlaysDirty = false
  SyncAllClickOverlays()
end

BravUI.Frames.Group.UpdateAll = UpdateAll

-- ============================================================================
-- PREVIEW MODE
-- ============================================================================
local function SetPreviewMode(enabled)
  previewMode = enabled

  if enabled then
    container:Show()

    local fakeNames   = { "Tank", "Healer", "DPS1", "DPS2" }
    local fakeRoles   = { "TANK", "HEALER", "DAMAGER", "DAMAGER" }
    local fakeClasses = { "WARRIOR", "PRIEST", "MAGE", "ROGUE" }

    for i = 1, MAX_MEMBERS do
      local mf = members[i]
      mf:Show()
      mf:SetAlpha(1.0)
      mf:ApplyLayout(GetLayout())
      mf:ApplyTextSettings()

      local fakeMaxHP    = 100000
      local fakeHP       = math.random(60000, 100000)
      local fakeMaxPower = 50000
      local fakePower    = math.random(20000, 50000)

      mf.HPBar:SetMinMaxValues(0, fakeMaxHP);    mf.HPBar:SetValue(fakeHP)
      mf.PowerBar:SetMinMaxValues(0, fakeMaxPower); mf.PowerBar:SetValue(fakePower)

      mf.__hp_k   = Abbrev(fakeHP)
      mf.__hp_pct = math.floor((fakeHP / fakeMaxHP) * 100) .. "%"
      mf.HPNameText:SetText(fakeNames[i] or ("Party" .. i))
      mf.HPStatsText:SetText(mf.__hp_k .. " | " .. mf.__hp_pct)
      mf.PowerText:SetText(Abbrev(fakePower))

      local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[fakeClasses[i]]
      if classColor then
        mf.HPBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
      else
        mf.HPBar:SetStatusBarColor(0.5, 0.5, 0.5)
      end
      mf.PowerBar:SetStatusBarColor(0.0, 0.4, 1.0)

      local cfg      = GetConfig()
      local showRole = (cfg == nil) or (cfg.showRole ~= false)
      if showRole then
        SetRoleTex(mf.RoleIcon, fakeRoles[i]); mf.RoleHolder:Show()
      else
        mf.RoleHolder:Hide()
      end

      local showLeader = (cfg == nil) or (cfg.showLeader ~= false)
      if showLeader and i == 1 then
        mf.LeaderIcon:Show(); mf.AssistIcon:Hide()
      elseif showLeader and i == 2 then
        mf.LeaderIcon:Hide(); mf.AssistIcon:Show()
      else
        mf.LeaderIcon:Hide(); mf.AssistIcon:Hide()
      end
    end

    local layout  = GetLayout()
    local spacing = layout.spacing or DEFAULT_SPACING
    local w       = members[1]:GetWidth() or DEFAULT_WIDTH
    local h       = 0

    for i = 1, MAX_MEMBERS do
      local mf = members[i]
      mf:ClearAllPoints()
      if i == 1 then
        mf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
      else
        mf:SetPoint("TOPLEFT", members[i - 1], "BOTTOMLEFT", 0, -spacing)
      end
      h = h + (mf:GetHeight() or 50)
      if i > 1 then h = h + spacing end
    end

    container:SetSize(w, h)

    local cfg   = GetConfig() or {}
    local scale = ClampNum(cfg.scale, 0.5, 2.0, 1.0)
    local posX  = ClampNum(cfg.posX,  -2000, 2000, -350)
    local posY  = ClampNum(cfg.posY,  -2000, 2000, -200)
    container:SetScale(scale)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", posX, posY)

    SyncAllClickOverlays()
  else
    UpdateAll()
  end
end

BravUI.Frames.Group.SetPreviewMode = SetPreviewMode
BravUI.Frames.Group.TogglePreview  = function() SetPreviewMode(not previewMode); return previewMode end
BravUI.Frames.Group.IsPreviewMode  = function() return previewMode end

BravUI.Frames.Group.Refresh = function()
  if previewMode then SetPreviewMode(true) else ApplyFromDB(); UpdateAll() end
end

-- ============================================================================
-- EVENT THROTTLE
-- ============================================================================
local MarkDirty = U.CreateMemberThrottler(0.05, function(idx)
  if not container:IsShown() then return end
  local mf = members[idx]
  if mf then mf:Update() end
end)

local unitToSlot = {}

local function RebuildUnitMap()
  wipe(unitToSlot)
  for i = 1, MAX_MEMBERS do unitToSlot[members[i].unit] = i end
end

local _origSort = SortMembersByRole
SortMembersByRole = function(...)
  _origSort(...)
  RebuildUnitMap()
end

RebuildUnitMap()

-- ============================================================================
-- EVENTS
-- ============================================================================
local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("GROUP_ROSTER_UPDATE")
evt:RegisterEvent("UNIT_HEALTH")
evt:RegisterEvent("UNIT_MAXHEALTH")
evt:RegisterEvent("UNIT_POWER_UPDATE")
evt:RegisterEvent("UNIT_MAXPOWER")
evt:RegisterEvent("UNIT_DISPLAYPOWER")
evt:RegisterEvent("UNIT_NAME_UPDATE")
evt:RegisterEvent("UNIT_CONNECTION")
evt:RegisterEvent("INCOMING_RESURRECT_CHANGED")
evt:RegisterEvent("UNIT_FLAGS")
evt:RegisterEvent("PLAYER_FLAGS_CHANGED")
evt:RegisterEvent("PLAYER_ROLES_ASSIGNED")
evt:RegisterEvent("PARTY_LEADER_CHANGED")
evt:RegisterEvent("PLAYER_REGEN_ENABLED")

evt:SetScript("OnEvent", function(_, event, unit)
  if previewMode and event ~= "PLAYER_LOGIN" then return end

  if event == "PLAYER_LOGIN" then
    ApplyFromDB()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    if _updateAllPending then
      UpdateAll()
    elseif _overlaysDirty then
      _overlaysDirty = false
      SyncAllClickOverlays()
    end
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
     or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER"
     or event == "UNIT_DISPLAYPOWER" or event == "UNIT_NAME_UPDATE"
     or event == "UNIT_CONNECTION"
     or event == "INCOMING_RESURRECT_CHANGED"
     or event == "UNIT_FLAGS" then
    if not unit then return end
    local slot = unitToSlot[unit]
    if slot then MarkDirty(slot) end
    return
  end

  UpdateAll()

  if event == "GROUP_ROSTER_UPDATE" then
    C_Timer.After(0.3, function()
      if not previewMode then UpdateAll() end
    end)
  end
end)

C_Timer.After(0.1, UpdateAll)

-- ============================================================================
-- RANGE POLLING
-- ============================================================================
C_Timer.After(1.0, function()
  C_Timer.NewTicker(0.5, function()
    if previewMode then return end
    if not container:IsShown() then return end

    local cfg          = GetConfig()
    local rangeEnabled = (cfg == nil) or (cfg.rangeEnabled ~= false)
    if not rangeEnabled then return end

    local oorAlpha = (cfg and cfg.outOfRangeAlpha) or 0.4
    for i = 1, MAX_MEMBERS do
      local mf = members[i]
      if mf:IsShown() then
        mf:SetAlpha(IsUnitOutOfRange(mf.unit) and oorAlpha or 1.0)
      end
    end
  end)
end)

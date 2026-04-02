-- BravUI/Modules/UnitFrames/Raid/RaidFactory.lua
-- Raid UnitFrames — shared factory for Raid15/Raid25/Raid40
-- HP: mirror Blizzard statusbar value (abbrev) | %: mirror Blizzard text (no math)

BravUI.Frames      = BravUI.Frames or {}
BravUI.RaidFactory = BravUI.RaidFactory or {}

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
local Abbrev              = U.AbbrevForSetText
local ClampNum            = U.ClampNum
local Create1pxBorder     = U.Create1pxBorder
local ApplyBG             = U.ApplyBG
local CreateBarBackground = U.CreateBarBackgroundTexture
local CreateIconFrame     = U.CreateIconFrame
local SafeUnitExists      = U.SafeUnitExists
local SafeUnitIsConnected = U.SafeUnitIsConnected
local SafeUnitIsDead      = U.SafeUnitIsDead

local function IsUnitOutOfRange(unit)
  return U.IsFriendlyOutOfRange(unit)
end

local ROLE_SIZE       = 14
local ROLE_ORDER      = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local MAX_SUBGROUPS   = 8
local MEMBERS_PER_GROUP = 5
local GROUP_LABEL_HEIGHT = 14

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
-- FACTORY: BravUI.RaidFactory.Create(cfg)
-- ============================================================================
function BravUI.RaidFactory.Create(cfg)
  local dbKey        = cfg.dbKey
  local maxMembers   = cfg.maxMembers
  local defColumns   = cfg.defaultColumns
  local frameName    = cfg.frameName
  local globalPrefix = cfg.globalPrefix
  local minRaidSize  = cfg.minRaidSize
  local maxRaidSize  = cfg.maxRaidSize

  local DEF_WIDTH   = cfg.defWidth    or 120
  local DEF_HP_H    = cfg.defHpH      or 20
  local DEF_PWR_H   = cfg.defPwrH     or 6
  local DEF_SPACING = cfg.defSpacing  or 4
  local DEF_ROW_SP  = cfg.defRowSpacing or 4

  -- ============================================================================
  -- DB CONFIG GETTERS
  -- ============================================================================
  local GetConfig, _, GetHeightConfig, GetColorConfig, GetTextConfig = U.MakeConfigGetters(dbKey)

  -- ============================================================================
  -- CONTAINER
  -- ============================================================================
  local container = CreateFrame("Frame", "BravUI_" .. frameName .. "Frame", UIParent)
  container:SetSize(400, 300)
  container:SetPoint("CENTER", UIParent, "CENTER", -350, -200)
  container:SetClampedToScreen(true)
  container:EnableMouse(true)
  container:SetMovable(true)
  container:RegisterForDrag("LeftButton")

  container:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    local c = GetConfig()
    if c and c.locked then return end
    self:StartMoving()
  end)
  container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local c = GetConfig()
    if c then
      local _, _, _, x, y = self:GetPoint(1)
      c.posX = math.floor((x or 0) + 0.5)
      c.posY = math.floor((y or 0) + 0.5)
    end
  end)

  BravUI.Frames[frameName]           = BravUI.Frames[frameName] or {}
  BravUI.Frames[frameName].Root      = container
  BravUI.Frames[frameName].Container = container
  BravUI.Frames[frameName].Members   = {}

  local previewMode = false

  -- ============================================================================
  -- MEMBER FACTORY
  -- ============================================================================
  local function CreateRaidMember(i)
    local unit = "raid" .. i

    local f = CreateFrame("Frame", globalPrefix .. i, container)
    f.unit  = unit
    f.index = i
    f:Hide()

    -- HP
    local hpFrame = CreateFrame("Frame", nil, f)
    hpFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    hpFrame:SetSize(DEF_WIDTH, DEF_HP_H)

    local hp = CreateFrame("StatusBar", nil, hpFrame)
    hp:SetAllPoints(hpFrame)
    hp:SetStatusBarTexture(TEX)
    hp:SetMinMaxValues(0, 1)
    Create1pxBorder(hp)

    -- Power
    local powerFrame = CreateFrame("Frame", nil, f)
    powerFrame:SetPoint("TOPLEFT", hpFrame, "BOTTOMLEFT", 0, 0)
    powerFrame:SetSize(DEF_WIDTH, DEF_PWR_H)

    local power = CreateFrame("StatusBar", nil, powerFrame)
    power:SetAllPoints(powerFrame)
    power:SetStatusBarTexture(TEX)
    power:SetMinMaxValues(0, 1)
    Create1pxBorder(power)

    -- Icons
    local roleHolder = CreateIconFrame(hp, ROLE_SIZE, "CENTER", hp, 0, 0)
    local roleIcon   = roleHolder.tex

    local leaderIcon = U.CreateLeaderIcon(hp, 12)
    leaderIcon:ClearAllPoints()
    leaderIcon:SetPoint("TOPLEFT", hp, "TOPLEFT", -4, 12)

    local assistIcon = U.CreateAssistIcon(hp, leaderIcon, 10)
    assistIcon:ClearAllPoints()
    assistIcon:SetPoint("LEFT", leaderIcon, "RIGHT", 1, 0)

    local rezHolder = U.CreateRezIcon(hp)
    local wmHolder  = U.CreateWMIcon(hp)

    -- Texts
    local hpNameText  = U.CreateText(hp,    "LEFT",   "LEFT",   10,  4, 0)
    local hpStatsText = U.CreateText(hp,    "RIGHT",  "RIGHT",  10, -4, 0)
    local powerText   = U.CreateText(power, "CENTER", "CENTER",  8,  0, 0)

    -- Store refs
    f.HPFrame     = hpFrame
    f.PowerFrame  = powerFrame
    f.HPBar       = hp
    f.PowerBar    = power
    f.HPNameText  = hpNameText
    f.HPStatsText = hpStatsText
    f.PowerText   = powerText
    f.RoleHolder  = roleHolder
    f.RoleIcon    = roleIcon
    f.LeaderIcon  = leaderIcon
    f.AssistIcon  = assistIcon
    f.RezHolder   = rezHolder
    f.WMHolder    = wmHolder

    -- UnitHealth() is a SECRET in TWW — pass directly to AbbreviateNumbers → SetText.
    -- No arithmetic, no comparison, no concatenation on secrets.
    local function RefreshHPText()
      if previewMode then return end
      local u = f.unit
      if not SafeUnitExists(u) then
        hpNameText:SetText(""); hpStatsText:SetText("")
        return
      end
      local nameCfg = GetTextConfig("name")
      if not nameCfg or nameCfg.enabled ~= false then
        local name = UnitName(u)
        if U.TruncateName then name = U.TruncateName(name, 8) end
        hpNameText:SetText(name)
      end
      local hpCfg = GetTextConfig("hp")
      if hpCfg and hpCfg.enabled == false then
        hpStatsText:SetText("")
      else
        local fmt = (hpCfg and hpCfg.format) or "VALUE"
        if fmt == "NONE" then
          hpStatsText:SetText("")
        else
          pcall(function()
            hpStatsText:SetText(AbbreviateNumbers(UnitHealth(u)))
          end)
        end
      end
    end

    function f:ApplyLayout()
      local c    = GetConfig()
      local w    = (c and c.width) or DEF_WIDTH
      local hpH  = GetHeightConfig("hp",    DEF_HP_H)
      local pwrH = GetHeightConfig("power", DEF_PWR_H)
      local showPower = not c or c.showPower ~= false

      self.HPFrame:ClearAllPoints()
      self.PowerFrame:ClearAllPoints()
      self.HPFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      self.HPFrame:SetSize(w, hpH)

      if showPower then
        self.PowerFrame:Show()
        self.PowerFrame:SetPoint("TOPLEFT", self.HPFrame, "BOTTOMLEFT", 0, 0)
        self.PowerFrame:SetSize(w, pwrH)
      else
        self.PowerFrame:Hide()
        self.PowerFrame:SetHeight(0.001)
      end

      self:SetSize(w, hpH + (showPower and pwrH or 0))
    end

    function f:ApplyTextSettings()
      U.ApplyTextConfig(hpNameText,  GetTextConfig("name"),  hp,    "LEFT",   10,  4, 0)
      U.ApplyTextConfig(hpStatsText, GetTextConfig("hp"),    hp,    "RIGHT",  10, -4, 0)
      U.ApplyTextConfig(powerText,   GetTextConfig("power"), power, "CENTER",  8,  0, 0)

      local c = GetConfig()
      if c then
        -- Role icon: size + anchor
        local roleSize   = c.roleIconSize or ROLE_SIZE
        local roleAnchor = c.roleIconAnchor or "CENTER"
        local rx = c.roleIconOffsetX or 0
        local ry = c.roleIconOffsetY or 0
        roleHolder:SetSize(roleSize, roleSize)
        if roleIcon then roleIcon:SetSize(roleSize, roleSize) end
        roleHolder:ClearAllPoints()
        roleHolder:SetPoint(roleAnchor, hp, roleAnchor, rx, ry)

        -- Leader icon: size + anchor
        local leaderSize   = c.leaderIconSize or 12
        local leaderAnchor = c.leaderIconAnchor or "TOPLEFT"
        local lx = c.leaderIconOffsetX or 0
        local ly = c.leaderIconOffsetY or 0
        leaderIcon:SetSize(leaderSize, leaderSize)
        leaderIcon:ClearAllPoints()
        leaderIcon:SetPoint(leaderAnchor, hp, leaderAnchor, lx, ly)

        -- Assist uses same anchor as leader
        assistIcon:SetSize(leaderSize, leaderSize)
        assistIcon:ClearAllPoints()
        assistIcon:SetPoint(leaderAnchor, hp, leaderAnchor, lx, ly)
      end
    end

    function f:ApplyBackgrounds()
      ApplyBG(hp,    dbKey, "hp")
      ApplyBG(power, dbKey, "power")
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
        local nameCfg = GetTextConfig("name")
        if not nameCfg or nameCfg.enabled ~= false then
          local name = UnitName(u)
          if U.TruncateName then name = U.TruncateName(name, 8) end
          hpNameText:SetText(name)
        end
        local hpCfg = GetTextConfig("hp")
        if not hpCfg or hpCfg.enabled ~= false then
          hpStatsText:SetText("Déconnecté")
        end
        powerText:SetText("")
        roleHolder:Hide(); leaderIcon:Hide(); assistIcon:Hide()
        rezHolder:Hide(); wmHolder:Hide()
        return
      end

      if SafeUnitIsDead(u) then
        self:SetAlpha(0.6)
        hp:SetMinMaxValues(0, 1); hp:SetValue(0); hp:SetStatusBarColor(0.4, 0.1, 0.1)
        power:SetMinMaxValues(0, 1); power:SetValue(0); power:SetStatusBarColor(0.2, 0.2, 0.2)
        local nameCfg = GetTextConfig("name")
        if not nameCfg or nameCfg.enabled ~= false then
          local name = UnitName(u)
          if U.TruncateName then name = U.TruncateName(name, 8) end
          hpNameText:SetText(name)
        end
        local hpCfg = GetTextConfig("hp")
        if not hpCfg or hpCfg.enabled ~= false then
          hpStatsText:SetText("Mort")
        end
        powerText:SetText("")
        roleHolder:Hide(); leaderIcon:Hide(); assistIcon:Hide()
        U.UpdateRezIcon(u, rezHolder); wmHolder:Hide()
        return
      end

      pcall(function()
        hp:SetMinMaxValues(0, UnitHealthMax(u))
        hp:SetValue(UnitHealth(u))
      end)
      RefreshHPText()

      pcall(function()
        power:SetMinMaxValues(0, UnitPowerMax(u))
        power:SetValue(UnitPower(u))
      end)
      local pwrCfg = GetTextConfig("power")
      if pwrCfg and pwrCfg.enabled == false then
        powerText:SetText("")
      else
        local pwrFmt = (pwrCfg and pwrCfg.format) or "VALUE"
        if pwrFmt == "NONE" then
          powerText:SetText("")
        else
          pcall(function()
            powerText:SetText(Abbrev(UnitPower(u)))
          end)
        end
      end

      local colorCfg = GetColorConfig()
      U.UpdateHPColor(u, hp, colorCfg)
      U.UpdatePowerColor(u, power, colorCfg)

      local c        = GetConfig()
      local showRole = (c == nil) or (c.showRole   ~= false)
      if showRole then
        local role = UnitGroupRolesAssigned(u)
        if role and role ~= "NONE" then SetRoleTex(roleIcon, role); roleHolder:Show()
        else roleHolder:Hide() end
      else roleHolder:Hide() end

      local showLeader = (c == nil) or (c.showLeader ~= false)
      if showLeader then U.UpdateLeaderIcons(u, leaderIcon, assistIcon)
      else leaderIcon:Hide(); assistIcon:Hide() end

      U.UpdateRezIcon(u, rezHolder)
      U.UpdateWMIcon(u, wmHolder)

      local rangeEnabled = (c == nil) or (c.rangeEnabled ~= false)
      if rangeEnabled then
        local oorAlpha = (c and c.outOfRangeAlpha) or 0.4
        self:SetAlpha(IsUnitOutOfRange(u) and oorAlpha or 1.0)
      else
        self:SetAlpha(1.0)
      end
    end

    return f
  end

  -- ============================================================================
  -- CREATE MEMBERS
  -- ============================================================================
  local members = {}
  for i = 1, maxMembers do
    local mf = CreateRaidMember(i)
    members[i] = mf
    BravUI.Frames[frameName].Members[i] = mf
  end
  BravUI.Frames[frameName].Frames = members

  -- ============================================================================
  -- GROUP LABELS
  -- ============================================================================
  local groupLabels = {}
  for g = 1, MAX_SUBGROUPS do
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFontObject("GameFontHighlightSmall")
    label:SetText("G" .. g)
    label:SetTextColor(1, 1, 1, 1)
    label:Hide()
    groupLabels[g] = label
  end
  BravUI.Frames[frameName].GroupLabels = groupLabels

  -- ============================================================================
  -- CLICK OVERLAYS
  -- ============================================================================
  local clickOverlays  = {}
  local _overlaysDirty = false

  local function SyncClickOverlay(i)
    local overlay = clickOverlays[i]
    local mf      = members[i]
    if not overlay or not mf then return end
    if not U.SyncClickOverlay(overlay, mf) then _overlaysDirty = true; return end
    if mf:IsShown() and container:IsShown() then overlay:Show() else overlay:Hide() end
  end

  for i = 1, maxMembers do
    clickOverlays[i] = U.CreateClickOverlay(globalPrefix .. "ClickOverlay" .. i, "raid" .. i)
    SyncClickOverlay(i)
  end

  local function SyncAllClickOverlays()
    for i = 1, maxMembers do SyncClickOverlay(i) end
  end

  BravUI.Frames[frameName].ClickOverlays     = clickOverlays
  BravUI.Frames[frameName].SyncClickOverlays = SyncAllClickOverlays

  -- ============================================================================
  -- SORT
  -- ============================================================================
  local function SortMembers()
    if InCombatLockdown() then return end
    local c = GetConfig() or {}
    local useSubgroups = c.groupBySubgroup == true

    local sortable = {}
    for i = 1, maxMembers do
      local unit     = "raid" .. i
      local role     = "NONE"
      local subgroup = 1
      local exists   = SafeUnitExists(unit)
      if exists then
        role = UnitGroupRolesAssigned(unit) or "NONE"
        if useSubgroups then
          local _, _, sg = GetRaidRosterInfo(i)
          subgroup = sg or 1
        end
      end
      sortable[i] = { index = i, role = role, subgroup = subgroup, exists = exists }
    end

    local sortByRole = not useSubgroups and (c.sortByRole ~= false)

    table.sort(sortable, function(a, b)
      if a.exists ~= b.exists then return a.exists end
      if useSubgroups and a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end
      if sortByRole then
        local ra = ROLE_ORDER[a.role] or 4
        local rb = ROLE_ORDER[b.role] or 4
        if ra ~= rb then return ra < rb end
      end
      return a.index < b.index
    end)

    for slot = 1, maxMembers do
      local info = sortable[slot]
      local mf   = members[slot]
      mf.unit      = "raid" .. info.index
      mf.index     = info.index
      mf._subgroup = info.subgroup
      local overlay = clickOverlays[slot]
      if overlay then overlay:SetAttribute("unit", mf.unit) end
    end
  end

  -- ============================================================================
  -- APPLY FROM DB
  -- ============================================================================
  local function ApplyFromDB()
    if InCombatLockdown() then return end
    local c = GetConfig() or {}

    local raidScale = ClampNum(c.scale, 0.5, 2.0, 1.0)
    container:SetScale(raidScale)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER",
      ClampNum(c.posX, -2000, 2000, -350) / raidScale,
      ClampNum(c.posY, -2000, 2000, -200) / raidScale)

    local columns    = c.columns    or defColumns
    local spacing    = c.spacing    or DEF_SPACING
    local rowSpacing = c.rowSpacing or DEF_ROW_SP
    local mWidth     = c.width      or DEF_WIDTH

    for i = 1, maxMembers do
      members[i]:ApplyLayout()
      members[i]:ApplyTextSettings()
      members[i]:ApplyBackgrounds()
    end

    local memberH      = members[1]:GetHeight() or (DEF_HP_H + DEF_PWR_H)
    local useSubgroups = c.groupBySubgroup == true

    if useSubgroups then
      local groupSpacing   = c.groupSpacing or 2
      local showGroupLabel = c.showGroupLabel ~= false
      local labelSize      = c.groupLabelSize or 9
      local labelH         = showGroupLabel and GROUP_LABEL_HEIGHT or 0

      -- Apply font size to all group labels
      for g = 1, MAX_SUBGROUPS do
        pcall(function() groupLabels[g]:SetFont(U.GetFont(), labelSize, "OUTLINE") end)
      end

      local groups = {}
      for i = 1, maxMembers do
        local sg = members[i]._subgroup or 1
        if not groups[sg] then groups[sg] = {} end
        table.insert(groups[sg], i)
      end

      local activeGroups = {}
      for g = 1, MAX_SUBGROUPS do
        if groups[g] and #groups[g] > 0 then table.insert(activeGroups, g) end
      end

      local colHeight = labelH + MEMBERS_PER_GROUP * memberH + (MEMBERS_PER_GROUP - 1) * groupSpacing
      local groupCol, groupRow = 0, 0

      for _, gNum in ipairs(activeGroups) do
        local baseX = groupCol * (mWidth + spacing)
        local baseY = -(groupRow * (colHeight + rowSpacing))
        local label = groupLabels[gNum]

        if showGroupLabel then
          local glOffX = c.groupLabelOffsetX or 0
          local glOffY = c.groupLabelOffsetY or 0
          label:ClearAllPoints()
          label:SetPoint("TOPLEFT", container, "TOPLEFT", baseX + glOffX, baseY + glOffY)
          label:SetWidth(mWidth)
          label:SetJustifyH("CENTER")
          label:Show()
        else
          label:Hide()
        end

        for mi, slot in ipairs(groups[gNum]) do
          local mf = members[slot]
          mf:ClearAllPoints()
          mf:SetPoint("TOPLEFT", container, "TOPLEFT",
            baseX, baseY - labelH - (mi - 1) * (memberH + groupSpacing))
        end

        groupCol = groupCol + 1
        if groupCol >= columns then groupCol = 0; groupRow = groupRow + 1 end
      end

      for g = 1, MAX_SUBGROUPS do
        if not groups[g] or #groups[g] == 0 then groupLabels[g]:Hide() end
      end

      local numCols = math.max(1, math.min(#activeGroups, columns))
      local numRows = math.max(1, math.ceil(#activeGroups / columns))
      container:SetSize(
        numCols * mWidth + (numCols - 1) * spacing,
        numRows * colHeight + (numRows - 1) * rowSpacing)
    else
      for g = 1, MAX_SUBGROUPS do groupLabels[g]:Hide() end

      local col, row = 0, 0
      for i = 1, maxMembers do
        local mf = members[i]
        mf:ClearAllPoints()
        mf:SetPoint("TOPLEFT", container, "TOPLEFT",
          col * (mWidth + spacing), -(row * (memberH + rowSpacing)))
        col = col + 1
        if col >= columns then col = 0; row = row + 1 end
      end

      local numRows = math.ceil(maxMembers / columns)
      container:SetSize(
        columns * mWidth + (columns - 1) * spacing,
        numRows * memberH + (numRows - 1) * rowSpacing)
    end

    SyncAllClickOverlays()
  end

  BravUI.Frames[frameName].ApplyFromDB = ApplyFromDB

  -- ============================================================================
  -- UPDATE ALL
  -- ============================================================================
  local _updateAllPending = false

  local function UpdateAll()
    if previewMode then return end
    if InCombatLockdown() then _updateAllPending = true; return end

    _updateAllPending = false
    local c       = GetConfig()
    local enabled = (c == nil) or (c.enabled ~= false)
    local count   = GetNumGroupMembers()
    local sizeMatch = IsInRaid() and count >= minRaidSize and count <= maxRaidSize

    container:SetShown(enabled and sizeMatch)

    if container:IsShown() then
      SortMembers()
      ApplyFromDB()
      for i = 1, maxMembers do members[i]:Update() end
    else
      if not InCombatLockdown() then
        for i = 1, maxMembers do members[i]:Hide() end
      end
    end

    SyncAllClickOverlays()
  end

  BravUI.Frames[frameName].UpdateAll = UpdateAll

  -- ============================================================================
  -- PREVIEW MODE
  -- ============================================================================
  local fakeClasses = {
    "WARRIOR","PRIEST","MAGE","ROGUE","DRUID",
    "PALADIN","HUNTER","WARLOCK","SHAMAN","DEATHKNIGHT",
    "MONK","DEMONHUNTER","EVOKER","WARRIOR","PRIEST",
    "MAGE","ROGUE","DRUID","PALADIN","HUNTER",
    "WARLOCK","SHAMAN","DEATHKNIGHT","MONK","DEMONHUNTER",
    "EVOKER","WARRIOR","PRIEST","MAGE","ROGUE",
    "DRUID","PALADIN","HUNTER","WARLOCK","SHAMAN",
    "DEATHKNIGHT","MONK","DEMONHUNTER","EVOKER","WARRIOR",
  }
  local fakeRolesPool = { "TANK", "HEALER", "DAMAGER" }

  local function SetPreviewMode(enabled)
    previewMode = enabled
    if enabled then
      container:Show()
      local c = GetConfig() or {}

      for i = 1, maxMembers do
        members[i]._subgroup = math.ceil(i / MEMBERS_PER_GROUP)
      end

      for i = 1, maxMembers do
        local mf      = members[i]
        local fakeHP  = math.random(40000, 100000)
        local fakePwr = math.random(10000, 50000)

        mf:Show(); mf:SetAlpha(1.0)
        mf:ApplyLayout(); mf:ApplyTextSettings(); mf:ApplyBackgrounds()

        mf.HPBar:SetMinMaxValues(0, 100000);   mf.HPBar:SetValue(fakeHP)
        mf.PowerBar:SetMinMaxValues(0, 50000); mf.PowerBar:SetValue(fakePwr)

        mf.HPNameText:SetText("Raid" .. i)

        -- HP text: respect format config
        local hpCfg = GetTextConfig("hp")
        if hpCfg and hpCfg.enabled == false then
          mf.HPStatsText:SetText("")
        else
          local fmt = (hpCfg and hpCfg.format) or "VALUE"
          if fmt == "NONE" then mf.HPStatsText:SetText("")
          else                  mf.HPStatsText:SetText(Abbrev(fakeHP))
          end
        end

        -- Power text: respect config
        local pwrCfg = GetTextConfig("power")
        if pwrCfg and pwrCfg.enabled == false then
          mf.PowerText:SetText("")
        else
          local pwrFmt = (pwrCfg and pwrCfg.format) or "VALUE"
          if pwrFmt == "NONE" then mf.PowerText:SetText("")
          else                     mf.PowerText:SetText(Abbrev(fakePwr))
          end
        end

        -- HP color: respect config (class / custom)
        local colorCfg = GetColorConfig()
        local useClassColor = not colorCfg or colorCfg.useClassColor ~= false
        if useClassColor then
          local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[fakeClasses[i] or "WARRIOR"]
          if cc then mf.HPBar:SetStatusBarColor(cc.r, cc.g, cc.b)
          else mf.HPBar:SetStatusBarColor(0.5, 0.5, 0.5) end
        else
          local custom = colorCfg and colorCfg.hpCustom
          if custom and custom.r then mf.HPBar:SetStatusBarColor(custom.r, custom.g, custom.b)
          else mf.HPBar:SetStatusBarColor(0.2, 0.8, 0.2) end
        end

        -- Power color: respect config
        local usePowerColor = not colorCfg or colorCfg.usePowerColor ~= false
        if usePowerColor then
          mf.PowerBar:SetStatusBarColor(0.0, 0.4, 1.0)
        else
          local custom = colorCfg and colorCfg.powerCustom
          if custom and custom.r then mf.PowerBar:SetStatusBarColor(custom.r, custom.g, custom.b)
          else mf.PowerBar:SetStatusBarColor(0.2, 0.4, 0.8) end
        end

        local showRole = (c.showRole ~= false)
        if showRole then
          local role = fakeRolesPool[((i - 1) % 3) + 1]
          SetRoleTex(mf.RoleIcon, role); mf.RoleHolder:Show()
        else mf.RoleHolder:Hide() end

        local showLeader = (c.showLeader ~= false)
        if showLeader and i == 1 then mf.LeaderIcon:Show(); mf.AssistIcon:Hide()
        elseif showLeader and i == 2 then mf.LeaderIcon:Hide(); mf.AssistIcon:Show()
        else mf.LeaderIcon:Hide(); mf.AssistIcon:Hide() end
      end

      ApplyFromDB()
      SyncAllClickOverlays()
    else
      UpdateAll()
    end
  end

  BravUI.Frames[frameName].SetPreviewMode = SetPreviewMode
  BravUI.Frames[frameName].TogglePreview  = function() SetPreviewMode(not previewMode); return previewMode end
  BravUI.Frames[frameName].IsPreviewMode  = function() return previewMode end
  BravUI.Frames[frameName].Refresh        = function()
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
    for i = 1, maxMembers do unitToSlot[members[i].unit] = i end
  end

  local _origSort = SortMembers
  SortMembers = function(...) _origSort(...); RebuildUnitMap() end

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

    if event == "PLAYER_LOGIN" then ApplyFromDB(); return end

    if event == "PLAYER_REGEN_ENABLED" then
      if _overlaysDirty then _overlaysDirty = false; SyncAllClickOverlays() end
      if _updateAllPending then UpdateAll() end
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
  end)

  C_Timer.After(0.1, UpdateAll)

  -- ============================================================================
  -- RANGE POLLING
  -- ============================================================================
  C_Timer.After(1.0, function()
    C_Timer.NewTicker(0.5, function()
      if previewMode then return end
      if not container:IsShown() then return end
      local c            = GetConfig()
      local rangeEnabled = (c == nil) or (c.rangeEnabled ~= false)
      if not rangeEnabled then return end
      local oorAlpha = (c and c.outOfRangeAlpha) or 0.4
      for i = 1, maxMembers do
        local mf = members[i]
        if mf:IsShown() then
          mf:SetAlpha(IsUnitOutOfRange(mf.unit) and oorAlpha or 1.0)
        end
      end
    end)
  end)

  -- ============================================================================
  -- PUBLIC HOOK
  -- ============================================================================
  local updateKey = "Update" .. frameName .. "UF"
  BravUI[updateKey] = function()
    if previewMode then SetPreviewMode(true) else ApplyFromDB(); UpdateAll() end
  end
end

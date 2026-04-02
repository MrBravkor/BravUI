-- BravUI/Modules/Misc/DataBars.lua
-- XPBar + RepBar + HonorBar (portage v2 — fusionné Shared + Init + Skin)
-- No Ace, no external dependencies

local BravUI = BravUI
local U = BravUI.Utils

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local DataBars = {}
BravUI:RegisterModule("Misc.DataBars", DataBars)

-- ============================================================================
-- DB HELPERS
-- ============================================================================

local function GetXPDB()    return BravLib.API.GetModule("expbar")   or {} end
local function GetRepDB()   return BravLib.API.GetModule("repbar")   or {} end
local function GetHonorDB() return BravLib.API.GetModule("honorbar") or {} end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"

-- ============================================================================
-- SHARED BAR FACTORY
-- ============================================================================

local function MakeText(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(GameFontNormal)
  U.SafeSetFont(fs, U.GetFont(), size, "OUTLINE")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.8)
  fs:SetText("")
  fs:SetTextColor(1, 1, 1, 1)
  return fs
end

local function MakeBackdrop(f)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)

  local border = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetBackdrop({ edgeFile = TEX, edgeSize = 1 })
  border:SetBackdropBorderColor(0, 0, 0, 0.9)

  local accent = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  accent:SetPoint("TOPLEFT", -2, 2)
  accent:SetPoint("BOTTOMRIGHT", 2, -2)
  accent:SetBackdrop({ edgeFile = TEX, edgeSize = 1 })
  local r, g, b = U.GetClassColor("player")
  accent:SetBackdropBorderColor(r, g, b, 0.70)

  f.__bg     = bg
  f.__border = border
  f.__accent = accent
end

local ANCHOR_MAP = {
  TOPLEFT     = { "TOPLEFT",     "LEFT",    4, -2 },
  TOP         = { "TOP",         "CENTER",  0, -2 },
  TOPRIGHT    = { "TOPRIGHT",    "RIGHT",  -4, -2 },
  LEFT        = { "LEFT",        "LEFT",    4,  0 },
  CENTER      = { "CENTER",      "CENTER",  0,  0 },
  RIGHT       = { "RIGHT",       "RIGHT",  -4,  0 },
  BOTTOMLEFT  = { "BOTTOMLEFT",  "LEFT",    4,  2 },
  BOTTOM      = { "BOTTOM",      "CENTER",  0,  2 },
  BOTTOMRIGHT = { "BOTTOMRIGHT", "RIGHT",  -4,  2 },
}

local function CreateBar(frameName, r, g, b, a)
  local bar = CreateFrame("StatusBar", frameName, UIParent)
  bar:SetFrameStrata("HIGH")
  bar:SetFrameLevel(50)
  bar:SetStatusBarTexture(TEX)
  bar:SetStatusBarColor(r or 1, g or 1, b or 1, a or 0.85)

  MakeBackdrop(bar)

  bar.centerText = MakeText(bar, 12)
  bar.centerText:SetPoint("CENTER", bar, "CENTER", 0, 0)

  bar.leftText = MakeText(bar, 13)
  bar.leftText:SetPoint("RIGHT", bar, "LEFT", -10, 0)
  bar.leftText:SetJustifyH("RIGHT")

  bar.rightText = MakeText(bar, 13)
  bar.rightText:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  bar.rightText:SetJustifyH("LEFT")

  function bar:RefreshBorderColor()
    if not self.__accent then return end
    local cr, cg, cb = U.GetClassColor("player")
    self.__accent:SetBackdropBorderColor(cr, cg, cb, 0.70)
  end

  function bar:RefreshFont(centerSize, leftSize, rightSize)
    centerSize = centerSize or 12
    leftSize   = leftSize   or centerSize + 1
    rightSize  = rightSize  or centerSize + 1
    local font = U.GetFont()
    self.centerText:SetFontObject(GameFontNormal)
    self.leftText:SetFontObject(GameFontNormal)
    self.rightText:SetFontObject(GameFontNormal)
    U.SafeSetFont(self.centerText, font, centerSize, "OUTLINE")
    U.SafeSetFont(self.leftText,   font, leftSize,   "OUTLINE")
    U.SafeSetFont(self.rightText,  font, rightSize,  "OUTLINE")
  end

  function bar:ApplySettings(db)
    if not db then return end

    self:SetAlpha(db.alpha or 1.0)

    if self.__bg then
      self.__bg:SetAlpha(db.bgAlpha or 0.55)
    end

    if self.__accent then
      if db.showBorder == false then self.__accent:Hide()
      else self.__accent:Show() end
    end

    -- Center text
    if self.centerText then
      local anchor = ANCHOR_MAP[db.textAnchor] or ANCHOR_MAP["CENTER"]
      self.centerText:ClearAllPoints()
      self.centerText:SetPoint(anchor[1], self, anchor[1], anchor[3], anchor[4])
      self.centerText:SetJustifyH(anchor[2])
      if db.showText == false then self.centerText:Hide()
      else self.centerText:Show() end
      local c = db.centerTextColor
      if c then self.centerText:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
      else self.centerText:SetTextColor(1, 1, 1, 1) end
    end

    -- Left text
    if self.leftText then
      local showLeft = db.showLeftText
      if showLeft == nil then showLeft = db.showSideText end
      if showLeft == false then self.leftText:Hide()
      else
        self.leftText:Show()
        local a = ANCHOR_MAP[db.leftTextAnchor]
        if a then
          self.leftText:ClearAllPoints()
          self.leftText:SetPoint(a[1], self, a[1], a[3], a[4])
          self.leftText:SetJustifyH(a[2])
        end
      end
      local c = db.leftTextColor
      if c then self.leftText:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
      else self.leftText:SetTextColor(1, 1, 1, 1) end
    end

    -- Right text
    if self.rightText then
      local showRight = db.showRightText
      if showRight == nil then showRight = db.showSideText end
      if showRight == false then self.rightText:Hide()
      else
        self.rightText:Show()
        local a = ANCHOR_MAP[db.rightTextAnchor]
        if a then
          self.rightText:ClearAllPoints()
          self.rightText:SetPoint(a[1], self, a[1], a[3], a[4])
          self.rightText:SetJustifyH(a[2])
        end
      end
      local c = db.rightTextColor
      if c then self.rightText:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
      else self.rightText:SetTextColor(1, 1, 1, 1) end
    end
  end

  bar:Hide()
  return bar
end

-- ============================================================================
-- CENTER TEXT FORMATTING (shared by all 3 bars)
-- ============================================================================

local function SetCenterText(bar, db, cur, max)
  if db.showText == false or not bar.centerText then return end
  if not (U.IsNumber(cur) and U.IsNumber(max) and max > 0) then
    local ok, text = pcall(function()
      local c = type(AbbreviateNumbers) == "function" and AbbreviateNumbers(cur) or cur
      local m = type(AbbreviateNumbers) == "function" and AbbreviateNumbers(max) or max
      return tostring(c) .. " / " .. tostring(m)
    end)
    bar.centerText:SetText(ok and text or "")
    return
  end
  local fmt = db.textFormat or "value_percent"
  local pct    = (cur / max) * 100
  local curStr = U.AbbrevNumber(cur) or tostring(cur)
  local maxStr = U.AbbrevNumber(max) or tostring(max)
  if fmt == "value_only" then
    bar.centerText:SetText(curStr)
  elseif fmt == "percent" then
    bar.centerText:SetText(string.format("%.1f%%", pct))
  elseif fmt == "value_pct" then
    bar.centerText:SetText(string.format("%s ( %.1f%% )", curStr, pct))
  elseif fmt == "value" then
    bar.centerText:SetText(string.format("%s / %s", curStr, maxStr))
  else -- value_percent
    bar.centerText:SetText(string.format("%s / %s ( %.1f%% )", curStr, maxStr, pct))
  end
end

-- ============================================================================
-- HIDE BLIZZARD STATUS BARS
-- ============================================================================

local blizzBarsHidden = false

local function HideBlizzardBars()
  if blizzBarsHidden then return end
  blizzBarsHidden = true

  local hider = CreateFrame("Frame", "BravUI_BarHider")
  hider:Hide()

  local targets = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer" }

  local function DoHide()
    for _, name in ipairs(targets) do
      local f = _G[name]
      if f and f.SetParent then
        f:SetParent(hider)
        f:Hide()
      end
    end
  end

  DoHide()
  C_Timer.After(0.5, DoHide)
  C_Timer.After(2.0, DoHide)
end

-- ============================================================================
-- XPBAR
-- ============================================================================

local XPBar = {}

local function GetMaxLevel()
  if type(GetMaxLevelForLatestExpansion) == "function" then
    local ok, val = pcall(GetMaxLevelForLatestExpansion)
    if ok and U.IsNumber(val) then return val end
  end
  if type(MAX_PLAYER_LEVEL) == "number" and not U.IsSecret(MAX_PLAYER_LEVEL) then
    return MAX_PLAYER_LEVEL
  end
  return 90
end

local function XPShouldShow(db)
  if not db.enabled then return false end
  if db.hideAtMaxLevel then
    local level = UnitLevel("player")
    if U.IsNumber(level) and level >= GetMaxLevel() then return false end
  end
  if type(IsXPUserDisabled) == "function" then
    local ok, result = pcall(function() return IsXPUserDisabled() == true end)
    if ok and result then return false end
  end
  return true
end

function XPBar:ApplyLayout()
  if not self.bar then return end
  local db = GetXPDB()

  self.bar:SetSize(db.width or 300, db.height or 12)

  if db.useClassColor then
    local r, g, b = U.GetClassColor("player")
    self.bar:SetStatusBarColor(r, g, b, 0.85)
  elseif db.barColor then
    self.bar:SetStatusBarColor(db.barColor.r or 0.58, db.barColor.g or 0.40, db.barColor.b or 0.93, 0.85)
  end

  if self.bar.ApplySettings then self.bar:ApplySettings(db) end
end

function XPBar:Update()
  if not self.bar then return end
  local db = GetXPDB()

  if not XPShouldShow(db) then self.bar:Hide() ; return end

  local cur = UnitXP("player")
  local max = UnitXPMax("player")

  if type(cur) ~= "number" or type(max) ~= "number" then self.bar:Hide() ; return end
  if U.IsNumber(max) and max <= 0 then self.bar:Hide() ; return end

  self.bar:SetMinMaxValues(0, max)
  self.bar:SetValue(cur)
  self.bar:Show()

  local level = UnitLevel("player")
  if U.IsNumber(level) then
    local nextLevel = math.min(level + 1, GetMaxLevel())
    self.bar.leftText:SetText("Niv. " .. level)
    self.bar.rightText:SetText("Niv. " .. nextLevel)
  else
    self.bar.leftText:SetText("")
    self.bar.rightText:SetText("")
  end

  if U.IsNumber(cur) then
    SetCenterText(self.bar, db, cur, max)
  end
end

function XPBar:Init()
  local db = GetXPDB()
  if not db.enabled then return end

  if not self.bar then
    self.bar = CreateBar("BravUI_XPBar", 0.58, 0.40, 0.93, 0.85)
    BravUI.Move.Enable(self.bar, "Barre XP")
  end

  local function OnEvent() self:ApplyLayout() ; self:Update() end

  BravLib.Event.Register("PLAYER_ENTERING_WORLD", OnEvent)
  BravLib.Event.Register("PLAYER_XP_UPDATE",      OnEvent)
  BravLib.Event.Register("PLAYER_LEVEL_UP",        OnEvent)
  BravLib.Event.Register("ENABLE_XP_GAIN",         OnEvent)
  BravLib.Event.Register("DISABLE_XP_GAIN",        OnEvent)

  self:ApplyLayout()
  self:Update()
end

-- ============================================================================
-- REPBAR
-- ============================================================================

local RepBar = {}

local STANDING_COLORS = {
  [1] = { r = 0.80, g = 0.13, b = 0.13 },
  [2] = { r = 0.80, g = 0.26, b = 0.13 },
  [3] = { r = 0.75, g = 0.27, b = 0.0  },
  [4] = { r = 0.90, g = 0.70, b = 0.0  },
  [5] = { r = 0.0,  g = 0.60, b = 0.10 },
  [6] = { r = 0.0,  g = 0.70, b = 0.30 },
  [7] = { r = 0.0,  g = 0.60, b = 0.80 },
  [8] = { r = 0.60, g = 0.20, b = 0.80 },
}

local STANDING_NAMES = {
  [1] = "Hai",      [2] = "Hostile",   [3] = "Inamical",
  [4] = "Neutre",   [5] = "Amical",    [6] = "Honoré",
  [7] = "Révéré",   [8] = "Exalté",
}

local PARAGON_COLOR    = { r = 0.0,  g = 0.50, b = 0.90 }
local FRIENDSHIP_COLOR = { r = 0.88, g = 0.55, b = 0.23 }
local RENOWN_COLOR     = { r = 0.0,  g = 0.75, b = 0.95 }
local RENOWN_MAX_COLOR = { r = 0.80, g = 0.60, b = 1.00 }

local function RepShouldShow(db)
  if not db.enabled then return false end
  if db.hideNoFaction then
    if not C_Reputation or not C_Reputation.GetWatchedFactionData then return false end
    if not C_Reputation.GetWatchedFactionData() then return false end
  end
  return true
end

function RepBar:ApplyLayout()
  if not self.bar then return end
  local db = GetRepDB()

  self.bar:SetSize(db.width or 300, db.height or 12)

  if self.bar.ApplySettings then self.bar:ApplySettings(db) end
end

function RepBar:Update()
  if not self.bar then return end
  local db = GetRepDB()

  if not RepShouldShow(db) then self.bar:Hide() ; return end

  if not C_Reputation or not C_Reputation.GetWatchedFactionData then self.bar:Hide() ; return end
  local data = C_Reputation.GetWatchedFactionData()
  if not data then self.bar:Hide() ; return end

  local factionID  = data.factionID
  local name       = U.IsString(data.name)     and data.name     or "?"
  local reaction   = U.IsNumber(data.reaction) and data.reaction or 4
  local cur, max
  local standingText
  local barColor
  local isParagon, isRenown = false, false

  -- Major faction check
  local isMajor = false
  if C_Reputation.IsMajorFaction then
    local ok, res = pcall(function() return C_Reputation.IsMajorFaction(factionID) == true end)
    if ok and res then isMajor = true end
  end

  local atMaxRenown = false
  if isMajor and C_MajorFactions and C_MajorFactions.HasMaximumRenown then
    pcall(function() atMaxRenown = C_MajorFactions.HasMaximumRenown(factionID) == true end)
  end

  -- 1. Paragon
  if C_Reputation.IsFactionParagon then
    local shouldCheck = not isMajor or atMaxRenown
    if shouldCheck then
      local ok, isPara = pcall(function() return C_Reputation.IsFactionParagon(factionID) == true end)
      if ok and isPara then
        isParagon = true
        pcall(function()
          local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
          if U.IsNumber(currentValue) and U.IsNumber(threshold) and threshold > 0 then
            cur = currentValue % threshold
            max = threshold
            standingText = hasRewardPending and "Paragon !" or "Paragon"
          else
            standingText = "Paragon"
          end
        end)
        if not standingText then standingText = "Paragon" end
        barColor = PARAGON_COLOR
      end
    end
  end

  -- 2. Major Faction / Renown
  if not isParagon and isMajor and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
    isRenown = true
    pcall(function()
      local majorData = C_MajorFactions.GetMajorFactionData(factionID)
      if not majorData then return end
      local level    = U.IsNumber(majorData.renownLevel) and majorData.renownLevel or 0
      local maxLevel = U.IsNumber(majorData.maxLevel)    and majorData.maxLevel    or level
      if atMaxRenown then
        standingText = "Renom " .. level .. " (Max)"
        cur = 1 ; max = 1
        barColor = RENOWN_MAX_COLOR
      else
        standingText = "Renom " .. level .. "/" .. maxLevel
        barColor = RENOWN_COLOR
        local earned    = majorData.renownReputationEarned
        local threshold = majorData.renownLevelThreshold
        if U.IsNumber(earned) and U.IsNumber(threshold) and threshold > 0 then
          cur = earned ; max = threshold
        end
      end
    end)
  end

  -- 3. Friendship
  if not isParagon and not isRenown and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
    pcall(function()
      local friendInfo = C_GossipInfo.GetFriendshipReputation(factionID)
      if not friendInfo then return end
      local fid = friendInfo.friendshipFactionID
      if not U.IsNumber(fid) or fid <= 0 then return end

      barColor = FRIENDSHIP_COLOR
      standingText = U.IsString(friendInfo.reaction) and friendInfo.reaction or "Ami"

      local standing  = U.IsNumber(friendInfo.standing)          and friendInfo.standing          or 0
      local threshold = U.IsNumber(friendInfo.reactionThreshold) and friendInfo.reactionThreshold or 0
      local nextThres = friendInfo.nextThreshold
      if U.IsNumber(nextThres) and nextThres > 0 then
        cur = standing - threshold
        max = nextThres - threshold
      else
        cur = 1 ; max = 1
      end

      if C_GossipInfo.GetFriendshipReputationRanks then
        local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(factionID)
        if rankInfo and U.IsNumber(rankInfo.currentLevel) and U.IsNumber(rankInfo.maxLevel) then
          standingText = standingText .. " " .. rankInfo.currentLevel .. "/" .. rankInfo.maxLevel
        end
      end
    end)
  end

  -- 4. Standard standing fallback
  if not standingText then standingText = STANDING_NAMES[reaction] or "?" end
  if not barColor     then barColor = STANDING_COLORS[reaction] end

  if not cur then
    pcall(function()
      local base    = U.IsNumber(data.currentReactionThreshold) and data.currentReactionThreshold or 0
      local ceiling = U.IsNumber(data.nextReactionThreshold)    and data.nextReactionThreshold    or 0
      local standing = U.IsNumber(data.currentStanding)         and data.currentStanding          or 0
      cur = standing - base
      max = ceiling  - base
    end)
  end

  if not U.IsNumber(max) or max <= 0 then max = 1 end
  if not U.IsNumber(cur) then cur = 0 end

  self.bar:SetMinMaxValues(0, max)
  self.bar:SetValue(cur)
  self.bar:Show()

  -- Couleur : priorité user > standing
  if db.useClassColor then
    local cr, cg, cb = U.GetClassColor("player")
    self.bar:SetStatusBarColor(cr, cg, cb, 0.85)
  elseif db.barColor then
    self.bar:SetStatusBarColor(db.barColor.r or 0, db.barColor.g or 0.6, db.barColor.b or 0.1, 0.85)
  elseif barColor then
    self.bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.85)
  end

  local ok, truncName = pcall(function() return U.TruncateName(name, 25) end)
  self.bar.leftText:SetText((ok and truncName) or name)
  self.bar.rightText:SetText(standingText)

  if U.IsNumber(cur) then
    SetCenterText(self.bar, db, cur, max)
  end
end

function RepBar:Init()
  local db = GetRepDB()
  if not db.enabled then return end

  if not self.bar then
    self.bar = CreateBar("BravUI_RepBar", 0.0, 0.60, 0.10, 0.85)
    BravUI.Move.Enable(self.bar, "Barre Rep")
  end

  local function OnEvent() self:ApplyLayout() ; self:Update() end

  BravLib.Event.Register("PLAYER_ENTERING_WORLD",               OnEvent)
  BravLib.Event.Register("UPDATE_FACTION",                      OnEvent)
  if C_MajorFactions then
    BravLib.Event.Register("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", OnEvent)
    BravLib.Event.Register("MAJOR_FACTION_UNLOCKED",             OnEvent)
  end

  self:ApplyLayout()
  self:Update()
end

-- ============================================================================
-- HONORBAR
-- ============================================================================

local HonorBar = {}

local function IsInPvPZone()
  local ok, isPvP = pcall(function()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
  end)
  if ok and isPvP then return true end

  if C_PvP and C_PvP.IsWarModeDesired then
    local ok2, wm = pcall(function() return C_PvP.IsWarModeDesired() == true end)
    if ok2 and wm then return true end
  end
  return false
end

local function HonorShouldShow(db)
  if not db.enabled then return false end
  if not db.alwaysShow and not IsInPvPZone() then return false end
  return true
end

function HonorBar:ApplyLayout()
  if not self.bar then return end
  local db = GetHonorDB()

  self.bar:SetSize(db.width or 300, db.height or 12)

  if self.bar.ApplySettings then self.bar:ApplySettings(db) end
end

function HonorBar:Update()
  if not self.bar then return end
  local db = GetHonorDB()

  if not HonorShouldShow(db) then self.bar:Hide() ; return end

  local cur   = UnitHonor("player")
  local max   = UnitHonorMax("player")
  local level = UnitHonorLevel("player")

  if type(cur) ~= "number" or type(max) ~= "number" then self.bar:Hide() ; return end
  if U.IsNumber(max) and max <= 0 then self.bar:Hide() ; return end

  self.bar:SetMinMaxValues(0, max)
  self.bar:SetValue(cur)
  self.bar:Show()

  -- Couleur : priorité user > défaut gold
  if db.useClassColor then
    local cr, cg, cb = U.GetClassColor("player")
    self.bar:SetStatusBarColor(cr, cg, cb, 0.85)
  elseif db.barColor then
    self.bar:SetStatusBarColor(db.barColor.r or 1.0, db.barColor.g or 0.71, db.barColor.b or 0.0, 0.85)
  else
    self.bar:SetStatusBarColor(1.0, 0.71, 0.0, 0.85)
  end

  if U.IsNumber(level) then
    self.bar.leftText:SetText("Niv. " .. level)
    self.bar.rightText:SetText("Niv. " .. (level + 1))
  else
    self.bar.leftText:SetText("")
    self.bar.rightText:SetText("")
  end

  if U.IsNumber(cur) then
    SetCenterText(self.bar, db, cur, max)
  end
end

function HonorBar:Init()
  local db = GetHonorDB()
  if not db.enabled then return end

  if not self.bar then
    self.bar = CreateBar("BravUI_HonorBar", 1.0, 0.71, 0.0, 0.85)
    BravUI.Move.Enable(self.bar, "Barre Honneur")
  end

  local function OnEvent() self:ApplyLayout() ; self:Update() end

  BravLib.Event.Register("PLAYER_ENTERING_WORLD",    OnEvent)
  BravLib.Event.Register("HONOR_XP_UPDATE",          OnEvent)
  BravLib.Event.Register("PLAYER_PVP_KILLS_CHANGED", OnEvent)
  BravLib.Event.Register("HONOR_LEVEL_UPDATE",       OnEvent)
  BravLib.Event.Register("ZONE_CHANGED_NEW_AREA",    OnEvent)

  self:ApplyLayout()
  self:Update()
end

-- ============================================================================
-- MODULE ENABLE / DISABLE
-- ============================================================================

function DataBars:Enable()
  HideBlizzardBars()
  XPBar:Init()
  RepBar:Init()
  HonorBar:Init()

  BravLib.Hooks.Register("APPLY_DATABARS", function()
    local function Refresh(sub, getDB)
      if not sub.bar then return end
      local db = getDB()
      sub.bar:RefreshBorderColor()
      sub.bar:RefreshFont(db.fontSize, db.leftFontSize, db.rightFontSize)
      sub:ApplyLayout()
      sub:Update()
    end
    Refresh(XPBar,    GetXPDB)
    Refresh(RepBar,   GetRepDB)
    Refresh(HonorBar, GetHonorDB)
  end)
end

function DataBars:Disable()
  if XPBar.bar    then XPBar.bar:Hide()    end
  if RepBar.bar   then RepBar.bar:Hide()   end
  if HonorBar.bar then HonorBar.bar:Hide() end
end

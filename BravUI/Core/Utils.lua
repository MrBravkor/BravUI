-- BravUI/Core/Utils.lua
-- Helpers: Secret Values safe tools + common utilities

BravUI.Utils = BravUI.Utils or {}
local U = BravUI.Utils

-- ============================================================================
-- SECRET VALUES PROTECTION
-- ============================================================================

function U.IsSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, res = pcall(issecretvalue, v)
  return ok and res == true
end

function U.IsNumber(v)
  return type(v) == "number" and not U.IsSecret(v)
end

function U.IsString(v)
  return type(v) == "string" and not U.IsSecret(v)
end

function U.SafeToString(v)
  if U.IsSecret(v) then return "" end
  local ok, s = pcall(tostring, v)
  if ok and type(s) == "string" then return s end
  return ""
end

function U.HardString(v)
  local ok1, s1 = pcall(tostring, v)
  if not ok1 then return "" end
  local ok2, s2 = pcall(string.format, "%s", s1)
  if not ok2 or type(s2) ~= "string" then return "" end
  local ok3, s3 = pcall(string.format, "%s", s2)
  if ok3 and type(s3) == "string" then return s3 end
  return s2
end

-- ============================================================================
-- NUMBER FORMATTING (secret-safe)
-- ============================================================================

function U.AbbrevNumber(n)
  if not U.IsNumber(n) then return nil end
  if n >= 1000000000 then
    return string.format("%.1fb", n / 1000000000):gsub("%.0b$", "b")
  elseif n >= 1000000 then
    return string.format("%.1fm", n / 1000000):gsub("%.0m$", "m")
  elseif n >= 1000 then
    return string.format("%.1fk", n / 1000):gsub("%.0k$", "k")
  end
  return tostring(math.floor(n + 0.5))
end

function U.SafeAbbrev(v)
  if U.IsNumber(v) then
    if type(AbbreviateNumbers) == "function" then
      local ok, out = pcall(AbbreviateNumbers, v)
      if ok and out then return out end
    end
    return U.AbbrevNumber(v)
  end
  if U.IsSecret(v) then return "" end
  return tostring(v)
end

function U.AbbrevForSetText(v)
  if type(AbbreviateNumbers) == "function" then
    local ok, out = pcall(AbbreviateNumbers, v)
    if ok then return out end
  end
  local ok, s = pcall(tostring, v)
  if ok then return s end
  return ""
end

function U.FormatNumber(n)
  if not U.IsNumber(n) then return "0" end
  local formatted = tostring(math.floor(n + 0.5))
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return formatted
end

function U.FormatPercent(ratio, decimals)
  if not U.IsNumber(ratio) then return "0%" end
  decimals = decimals or 0
  local pct = ratio * 100
  if decimals > 0 then
    return string.format("%." .. decimals .. "f%%", pct)
  end
  return string.format("%d%%", math.floor(pct + 0.5))
end

-- ============================================================================
-- STRING MANIPULATION (secret-safe)
-- ============================================================================

function U.TruncateName(name, maxLen)
  maxLen = tonumber(maxLen) or 10
  if maxLen < 1 then maxLen = 1 end
  local ok, result = pcall(function()
    local s = tostring(name)
    if s == "" then return "" end
    local len = string.len(s)
    if len <= maxLen then return s end
    if maxLen <= 1 then return "…" end
    return string.sub(s, 1, maxLen - 1) .. "…"
  end)
  if ok then return result end
  return name
end

function U.Trim(s)
  if not U.IsString(s) then return "" end
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

function U.Split(s, delimiter)
  if not U.IsString(s) then return {} end
  delimiter = delimiter or ","
  local result = {}
  local pattern = string.format("([^%s]+)", delimiter)
  for match in string.gmatch(s, pattern) do
    table.insert(result, match)
  end
  return result
end

-- ============================================================================
-- COLOR HELPERS
-- ============================================================================

function U.GetClassColor(unit)
  -- Custom color override from general settings
  local gen = BravLib.API.GetModule("general")
  if gen and not gen.useClassColor and gen.customColor then
    local c = gen.customColor
    return c.r or 0.20, c.g or 0.85, c.b or 0.90, 1
  end
  unit = unit or "player"
  local _, class = UnitClass(unit)
  if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
    local c = RAID_CLASS_COLORS[class]
    return c.r, c.g, c.b, 1
  end
  return 0.6, 0.6, 0.6, 1
end

function U.GetPowerColor(powerType)
  if not powerType then
    local _, pType = UnitPowerType("player")
    powerType = pType
  end
  if PowerBarColor and PowerBarColor[powerType] then
    local c = PowerBarColor[powerType]
    return c.r, c.g, c.b, 1
  end
  return 0.5, 0.5, 0.5, 1
end

function U.SetBarColorByKey(bar, key)
  if not bar or not bar.SetStatusBarColor then return end
  local c = PowerBarColor and key and PowerBarColor[key]
  if c and c.r then
    bar:SetStatusBarColor(c.r, c.g, c.b)
  else
    bar:SetStatusBarColor(0.7, 0.7, 0.7)
  end
end

function U.GetSelectionColor(unit)
  local r, g, b = UnitSelectionColor(unit)
  if r and g and b then return r, g, b, 1 end
  return 0.5, 0.5, 0.5, 1
end

function U.ColorText(text, r, g, b)
  if not text then return "" end
  r = math.floor((r or 1) * 255)
  g = math.floor((g or 1) * 255)
  b = math.floor((b or 1) * 255)
  return string.format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

-- ============================================================================
-- POSITION / MATH HELPERS
-- ============================================================================

function U.Clamp(value, min, max)
  value = tonumber(value)
  if not value then return min end
  if value < min then return min end
  if value > max then return max end
  return value
end

function U.Round(value, decimals)
  decimals = decimals or 0
  local mult = 10 ^ decimals
  return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

function U.Distance(x1, y1, x2, y2)
  local dx = (x2 or 0) - (x1 or 0)
  local dy = (y2 or 0) - (y1 or 0)
  return math.sqrt(dx * dx + dy * dy)
end

function U.Lerp(a, b, t)
  a = tonumber(a) or 0
  b = tonumber(b) or 0
  t = U.Clamp(t or 0, 0, 1)
  return a + (b - a) * t
end

-- ============================================================================
-- FRAME / UI HELPERS
-- ============================================================================

function U.SafeSetPoint(frame, ...)
  if not frame or not frame.SetPoint then return false end
  if InCombatLockdown() then return false end
  local ok, err = pcall(frame.SetPoint, frame, ...)
  if not ok then
    BravLib.Warn("Utils SetPoint error: " .. tostring(err))
    return false
  end
  return true
end

function U.GetFrameCenter(frame)
  if not frame then return 0, 0 end
  local left   = frame:GetLeft()   or 0
  local bottom = frame:GetBottom() or 0
  local width  = frame:GetWidth()  or 0
  local height = frame:GetHeight() or 0
  return left + width / 2, bottom + height / 2
end

function U.IsFrameVisible(frame)
  if not frame then return false end
  return frame:IsShown() and frame:IsVisible()
end

-- ============================================================================
-- FONT HELPERS
-- ============================================================================

function U.SafeSetFont(fontString, path, size, flags)
  if not fontString or not fontString.SetFont then return false end
  path  = path  or "Fonts\\FRIZQT__.TTF"
  size  = tonumber(size) or 12
  flags = flags or "OUTLINE"
  local ok = pcall(fontString.SetFont, fontString, path, size, flags)
  if not ok then
    if fontString.SetFontObject then
      pcall(fontString.SetFontObject, fontString, "GameFontNormal")
    end
    return false
  end
  return true
end

function U.GetTextWidth(fontString)
  if not fontString or not fontString.GetStringWidth then return 0 end
  local ok, width = pcall(fontString.GetStringWidth, fontString)
  if ok and width then return width end
  return 0
end

-- ============================================================================
-- TABLE HELPERS
-- ============================================================================

function U.DeepCopy(src, dst)
  if type(src) ~= "table" then return src end
  dst = dst or {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = U.DeepCopy(v, {})
    else
      dst[k] = v
    end
  end
  return dst
end

function U.MergeTables(dst, src)
  if type(dst) ~= "table" then dst = {} end
  if type(src) ~= "table" then return dst end
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = v end
  end
  return dst
end

function U.TableCount(tbl)
  if type(tbl) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

function U.IsTableEmpty(tbl)
  if type(tbl) ~= "table" then return true end
  return next(tbl) == nil
end

-- ============================================================================
-- UNIT HELPERS
-- ============================================================================

function U.UnitExists(unit)
  if not unit or unit == "" then return false end
  return UnitExists(unit) == true
end

function U.GetUnitName(unit)
  if not U.UnitExists(unit) then return "" end
  local name = UnitName(unit)
  if U.IsSecret(name) then return "" end
  return U.SafeToString(name)
end

function U.GetUnitHealth(unit)
  if not U.UnitExists(unit) then return 0, 1 end
  local current = UnitHealth(unit)    or 0
  local max     = UnitHealthMax(unit) or 1
  if U.IsSecret(current) or U.IsSecret(max) then return nil, nil end
  return current, max
end

function U.GetUnitPower(unit, powerType)
  if not U.UnitExists(unit) then return 0, 1 end
  local current = UnitPower(unit, powerType)    or 0
  local max     = UnitPowerMax(unit, powerType) or 1
  if U.IsSecret(current) or U.IsSecret(max) then return nil, nil end
  return current, max
end

-- ============================================================================
-- TIME HELPERS
-- ============================================================================

function U.FormatTime(seconds)
  seconds = tonumber(seconds) or 0
  if seconds < 0 then seconds = 0 end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%d:%02d", mins, secs)
end

function U.FormatDuration(seconds)
  seconds = tonumber(seconds) or 0
  if seconds < 0 then seconds = 0 end
  if seconds < 60 then
    return string.format("%.0fs", seconds)
  elseif seconds < 3600 then
    return string.format("%.0fm", seconds / 60)
  else
    return string.format("%.1fh", seconds / 3600)
  end
end

-- ============================================================================
-- DEBUG HELPERS
-- ============================================================================

function U.PrintTable(tbl, indent, maxDepth)
  if type(tbl) ~= "table" then print(tostring(tbl)); return end
  indent   = indent   or 0
  maxDepth = maxDepth or 3
  if indent >= maxDepth then print(string.rep("  ", indent) .. "{...}"); return end
  for k, v in pairs(tbl) do
    local prefix = string.rep("  ", indent)
    if type(v) == "table" then
      print(prefix .. tostring(k) .. ":")
      U.PrintTable(v, indent + 1, maxDepth)
    else
      print(prefix .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

function U.SafePrint(...)
  local args  = {...}
  local safe  = {}
  for i, v in ipairs(args) do
    safe[i] = U.IsSecret(v) and "<secret>" or tostring(v)
  end
  print(unpack(safe))
end

-- ============================================================================
-- VALIDATION HELPERS
-- ============================================================================

function U.ValidateColor(r, g, b, a)
  r = U.Clamp(tonumber(r) or 1, 0, 1)
  g = U.Clamp(tonumber(g) or 1, 0, 1)
  b = U.Clamp(tonumber(b) or 1, 0, 1)
  a = U.Clamp(tonumber(a) or 1, 0, 1)
  return r, g, b, a
end

-- ============================================================================
-- FRAME CONSTRUCTION HELPERS
-- ============================================================================

local TEX_WHITE = "Interface/Buttons/WHITE8x8"

function U.Create1pxBorder(target, edgeSize)
  if not target or target.__brav_border then return end
  edgeSize = edgeSize or 1
  local border = CreateFrame("Frame", nil, target,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  border:SetAllPoints(target)
  border:SetFrameLevel((target.GetFrameLevel and target:GetFrameLevel() or 1) + 1)
  border:EnableMouse(false)
  border:SetBackdrop({ edgeFile = TEX_WHITE, edgeSize = edgeSize })
  border:SetBackdropBorderColor(0, 0, 0, 0.9)
  target.__brav_border = border
  return border
end

function U.CreateClassBorder(frame, anchor)
  if not frame then return end
  anchor = anchor or frame
  local r, g, b = U.GetClassColor()
  local PU = PixelUtil
  local borders = {}

  local function MakeBorderTex()
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(TEX_WHITE)
    t:SetVertexColor(r, g, b, 1)
    return t
  end

  borders.top    = MakeBorderTex()
  PU.SetPoint(borders.top, "TOPLEFT",  anchor, "TOPLEFT",  -1,  1)
  PU.SetPoint(borders.top, "TOPRIGHT", anchor, "TOPRIGHT",  1,  1)
  PU.SetHeight(borders.top, 1)

  borders.bottom = MakeBorderTex()
  PU.SetPoint(borders.bottom, "BOTTOMLEFT",  anchor, "BOTTOMLEFT",  -1, -1)
  PU.SetPoint(borders.bottom, "BOTTOMRIGHT", anchor, "BOTTOMRIGHT",  1, -1)
  PU.SetHeight(borders.bottom, 1)

  borders.left   = MakeBorderTex()
  PU.SetPoint(borders.left, "TOPLEFT",    anchor, "TOPLEFT",    -1,  1)
  PU.SetPoint(borders.left, "BOTTOMLEFT", anchor, "BOTTOMLEFT", -1, -1)
  PU.SetWidth(borders.left, 1)

  borders.right  = MakeBorderTex()
  PU.SetPoint(borders.right, "TOPRIGHT",    anchor, "TOPRIGHT",    1,  1)
  PU.SetPoint(borders.right, "BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
  PU.SetWidth(borders.right, 1)

  frame._borders = borders
  return borders
end

function U.UpdateClassBorderColors(borders)
  if not borders then return end
  local r, g, b = U.GetClassColor()
  for _, tex in pairs(borders) do
    if tex.SetVertexColor then tex:SetVertexColor(r, g, b, 1) end
  end
end

function U.CreateBarBackground(bar, r, g, b, a)
  if not bar or bar.__brav_bg then return end
  r = r or 0; g = g or 0; b = b or 0; a = a or 0.55
  local bg = CreateFrame("Frame", nil, bar,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  bg:SetPoint("TOPLEFT",     bar, "TOPLEFT",     -1,  1)
  bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT",  1, -1)
  local lvl = (bar.GetFrameLevel and bar:GetFrameLevel() or 1) - 1
  if lvl < 0 then lvl = 0 end
  bg:SetFrameLevel(lvl)
  bg:EnableMouse(false)
  bg:SetBackdrop({ bgFile = TEX_WHITE })
  bg:SetBackdropColor(r, g, b, a)
  bar.__brav_bg = bg
  return bg
end

function U.CreateBarBackgroundTexture(parent, anchor, r, g, b, a)
  if not parent or parent.__brav_bg then return end
  anchor = anchor or parent
  r = r or 0; g = g or 0; b = b or 0; a = a or 0.55
  local bg = parent:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(r, g, b, a)
  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT",     anchor, "TOPLEFT",      1, -1)
  bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1,  1)
  parent.__brav_bg = bg
  return bg
end

-- ============================================================================
-- FONTSTRING HELPERS
-- ============================================================================

function U.ReadText(fs)
  if not fs or not fs.GetText then return nil end
  local ok, t = pcall(fs.GetText, fs)
  if not ok then return nil end
  local hasValue = pcall(function() local _ = t .. "" end)
  if not hasValue then return nil end
  return t
end

-- ============================================================================
-- ICON FRAME FACTORY
-- ============================================================================

function U.CreateIconFrame(parent, size, anchorPoint, anchorTo, x, y)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(size, size)
  holder:SetPoint(anchorPoint, anchorTo, anchorPoint, x, y)
  local bg = holder:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(holder)
  bg:SetColorTexture(0, 0, 0, 0)
  local tex = holder:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(holder)
  tex:SetAlpha(0.95)
  holder.bg  = bg
  holder.tex = tex
  holder:Hide()
  return holder
end

-- ============================================================================
-- BACKGROUND HELPERS
-- ============================================================================

U.BG_DEFAULT = {
  enabled = true,
  alpha   = 0.55,
  color   = { r = 0, g = 0, b = 0 },
  texture = "Interface/Buttons/WHITE8x8",
}

function U.GetProfileBG(unitKey, barKey)
  local db  = BravLib.Storage.GetDB()
  local uf  = db and db.unitframes
  local cfg = uf and uf[unitKey]

  local global = (cfg and (cfg.bg or cfg.background)) or nil
  local per    = (cfg and cfg.backgrounds and cfg.backgrounds[barKey]) or nil

  local out = {}
  local src = per or global or U.BG_DEFAULT

  out.enabled = (src.enabled ~= nil) and src.enabled or U.BG_DEFAULT.enabled
  out.alpha   = (src.alpha   ~= nil) and src.alpha   or U.BG_DEFAULT.alpha

  local col = src.color or U.BG_DEFAULT.color
  out.r = (col.r ~= nil) and col.r or U.BG_DEFAULT.color.r
  out.g = (col.g ~= nil) and col.g or U.BG_DEFAULT.color.g
  out.b = (col.b ~= nil) and col.b or U.BG_DEFAULT.color.b

  out.texture = src.texture or U.BG_DEFAULT.texture
  return out
end

function U.ApplyBG(bar, unitKey, barKey)
  if not bar then return end
  U.CreateBarBackground(bar)
  local bg = bar.__brav_bg
  if not bg then return end
  local c = U.GetProfileBG(unitKey, barKey)
  if not c.enabled then bg:Hide(); return end
  if bg.__brav_bgfile ~= c.texture then
    bg.__brav_bgfile = c.texture
    bg:SetBackdrop({ bgFile = bg.__brav_bgfile })
  end
  bg:SetBackdropColor(c.r, c.g, c.b, c.alpha)
  bg:Show()
end

-- ============================================================================
-- CLAMP WITH FALLBACK
-- ============================================================================

function U.ClampNum(v, a, b, fallback)
  v = tonumber(v)
  if v == nil then return fallback end
  if a and v < a then v = a end
  if b and v > b then v = b end
  return v
end

-- ============================================================================
-- RANGE CHECK
-- ============================================================================

local RANGE_ITEMS_FRIENDLY = {
  [5]=8149,[8]=34368,[10]=32321,[15]=1251,[20]=21519,
  [25]=31463,[30]=1180,[35]=18904,[40]=34471,[45]=32698,
}
local RANGE_ITEMS_HOSTILE = {
  [5]=8149,[8]=34368,[10]=32321,[15]=33069,[20]=10645,
  [25]=24268,[30]=835,[35]=24269,[40]=28767,[45]=23836,
}
local SPEC_FRIENDLY_RANGE = {
  [105]=45,[102]=45,[103]=40,[104]=40,
  [257]=45,[256]=45,[258]=45,
  [65]=40,[66]=30,[70]=30,
  [264]=40,[262]=40,[263]=40,
  [270]=45,[269]=40,[268]=40,
  [1468]=30,[1467]=25,[1473]=30,
  [62]=40,[63]=40,[64]=40,
  [265]=40,[266]=40,[267]=40,
  [253]=40,[254]=40,[255]=40,
  [250]=30,[251]=30,[252]=40,
  [577]=30,[581]=30,
  [259]=30,[260]=20,[261]=25,
  [71]=30,[72]=30,[73]=30,
}
local SPEC_HOSTILE_RANGE = {
  [102]=40,[103]=5,[104]=5,[105]=40,
  [258]=40,[257]=40,[256]=40,
  [70]=5,[65]=30,[66]=5,
  [262]=40,[263]=5,[264]=40,
  [269]=5,[268]=5,[270]=40,
  [1467]=25,[1473]=25,[1468]=25,
  [62]=40,[63]=40,[64]=40,
  [265]=40,[266]=40,[267]=40,
  [253]=40,[254]=40,[255]=5,
  [250]=5,[251]=5,[252]=5,
  [577]=5,[581]=5,
  [259]=5,[260]=5,[261]=5,
  [71]=5,[72]=5,[73]=5,
}

local _rangeItemFriendly = RANGE_ITEMS_FRIENDLY[40]
local _rangeItemHostile  = RANGE_ITEMS_HOSTILE[40]

local function FindBestRangeItem(itemTable, range)
  local bestDist, bestItem = nil, nil
  for dist, itemID in pairs(itemTable) do
    if dist >= range then
      if not bestDist or dist < bestDist then bestDist = dist; bestItem = itemID end
    end
  end
  if not bestItem then
    for dist, itemID in pairs(itemTable) do
      if not bestDist or dist > bestDist then bestDist = dist; bestItem = itemID end
    end
  end
  return bestItem or itemTable[40]
end

function U.UpdateRangeCheckSpec()
  local spec = GetSpecialization()
  if not spec then return end
  local specID = GetSpecializationInfo(spec)
  if specID then
    _rangeItemFriendly = FindBestRangeItem(RANGE_ITEMS_FRIENDLY, SPEC_FRIENDLY_RANGE[specID] or 40)
    _rangeItemHostile  = FindBestRangeItem(RANGE_ITEMS_HOSTILE,  SPEC_HOSTILE_RANGE[specID]  or 40)
  end
end

local _rangeFrame = CreateFrame("Frame")
_rangeFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
_rangeFrame:RegisterEvent("PLAYER_LOGIN")
_rangeFrame:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" or unit == "player" then
    U.UpdateRangeCheckSpec()
  end
end)

function U.IsFriendlyOutOfRange(unit)
  local ok, outOfRange = pcall(function()
    local inRange, checkedRange = UnitInRange(unit)
    if checkedRange then return not inRange end
    return nil
  end)
  if ok and outOfRange ~= nil then return outOfRange end
  if not InCombatLockdown() then
    local itemOK, result = pcall(C_Item.IsItemInRange, _rangeItemFriendly, unit)
    if itemOK and result == false then return true end
  end
  return false
end

function U.IsHostileOutOfRange(unit)
  if InCombatLockdown() then return false end
  local itemOK, result = pcall(C_Item.IsItemInRange, _rangeItemHostile, unit)
  if itemOK and result == false then return true end
  return false
end

function U.IsUnitOutOfRange(unit)
  local canAssistOK, canAssist = pcall(UnitCanAssist, "player", unit)
  if canAssistOK and canAssist then
    return U.IsFriendlyOutOfRange(unit)
  else
    return U.IsHostileOutOfRange(unit)
  end
end

-- ============================================================================
-- MIDNIGHT SECRET-SAFE UNIT HELPERS
-- ============================================================================

function U.SafeUnitExists(unit)
  local ok, guid = pcall(UnitGUID, unit)
  if not ok then return false end
  local ok2, isNil = pcall(function() return guid == nil end)
  if not ok2 then return true end
  return not isNil
end

function U.SafeUnitIsConnected(unit)
  local ok, val = pcall(UnitIsConnected, unit)
  if not ok then return true end
  local ok2, isFalse = pcall(function() return val == false end)
  if not ok2 then return true end
  return not isFalse
end

function U.SafeUnitIsDead(unit)
  local ok, val = pcall(UnitIsDeadOrGhost, unit)
  if not ok then return false end
  local ok2, isTrue = pcall(function() return val == true end)
  if not ok2 then return false end
  return isTrue
end

function U.SafeUnitIs(unit, expected)
  if type(unit) ~= "string" then return false end
  local ok, result = pcall(function() return unit == expected end)
  return ok and result
end

function U.WriteNameToFS(fontString, unit)
  local ok = pcall(function() fontString:SetText(UnitName(unit)) end)
  if ok then return true end
  if GetUnitName then
    local ok2 = pcall(function() fontString:SetText(GetUnitName(unit, false)) end)
    if ok2 then return true end
  end
  return false
end

-- ============================================================================
-- DISPELLABLE DEBUFF OVERLAY
-- ============================================================================

local DISPEL_ENUM = {
  None=0, Magic=1, Curse=2, Disease=3, Poison=4, Enrage=9, Bleed=11,
}
local ALL_DISPEL_ENUMS = { 0, 1, 2, 3, 4, 9, 11 }

U.DISPEL_COLORS = {
  [1]  = { r=0.20, g=0.60, b=1.00 },
  [2]  = { r=0.60, g=0.00, b=1.00 },
  [3]  = { r=0.60, g=0.40, b=0.00 },
  [4]  = { r=0.00, g=0.60, b=0.00 },
  [9]  = { r=1.00, g=0.00, b=0.00 },
  [11] = { r=1.00, g=0.00, b=0.00 },
}

local borderCurve, gradientCurve = nil, nil
local iconCurves = {}

local function BuildElementCurve(alpha)
  if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  curve:AddPoint(0, CreateColor(0, 0, 0, 0))
  for _, enumVal in ipairs(ALL_DISPEL_ENUMS) do
    if enumVal ~= 0 then
      local c = U.DISPEL_COLORS[enumVal]
      if c then curve:AddPoint(enumVal, CreateColor(c.r, c.g, c.b, alpha)) end
    end
  end
  return curve
end

local function GetBorderCurve()
  if not borderCurve then borderCurve = BuildElementCurve(0.8) end
  return borderCurve
end

local function GetGradientCurve()
  if not gradientCurve then gradientCurve = BuildElementCurve(0.3) end
  return gradientCurve
end

local function GetIconCurve(targetEnum)
  if iconCurves[targetEnum] then return iconCurves[targetEnum] end
  if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  for _, enumVal in ipairs(ALL_DISPEL_ENUMS) do
    if enumVal == targetEnum then
      curve:AddPoint(enumVal, CreateColor(1, 1, 1, 1))
    else
      curve:AddPoint(enumVal, CreateColor(1, 1, 1, 0))
    end
  end
  iconCurves[targetEnum] = curve
  return curve
end

function U.FindDispellableAura(unit)
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
  for i = 1, 40 do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
    if not aura then break end
    if aura.dispelName ~= nil then return aura.auraInstanceID end
  end
  return nil
end

function U.CreateDispelOverlay(hpBar)
  local parent  = hpBar:GetParent() or hpBar
  local hpLevel = hpBar:GetFrameLevel() or 2

  local overlay = CreateFrame("Frame", nil, parent)
  overlay:SetAllPoints(hpBar)
  overlay:SetFrameLevel(hpLevel + 4)
  overlay:EnableMouse(false)

  local borderSize = 2
  local function CreateBorderBar()
    local bar = CreateFrame("StatusBar", nil, overlay)
    bar:SetFrameLevel(hpLevel + 5)
    bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:GetStatusBarTexture():SetBlendMode("BLEND")
    bar:EnableMouse(false)
    bar:Hide()
    return bar
  end

  overlay.borderTop = CreateBorderBar()
  overlay.borderTop:SetPoint("TOPLEFT",  overlay, "TOPLEFT",  borderSize, 0)
  overlay.borderTop:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -borderSize, 0)
  overlay.borderTop:SetHeight(borderSize)

  overlay.borderBottom = CreateBorderBar()
  overlay.borderBottom:SetPoint("BOTTOMLEFT",  overlay, "BOTTOMLEFT",   borderSize, 0)
  overlay.borderBottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -borderSize, 0)
  overlay.borderBottom:SetHeight(borderSize)

  overlay.borderLeft = CreateBorderBar()
  overlay.borderLeft:SetPoint("TOPLEFT",    overlay, "TOPLEFT",    0, 0)
  overlay.borderLeft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
  overlay.borderLeft:SetWidth(borderSize)

  overlay.borderRight = CreateBorderBar()
  overlay.borderRight:SetPoint("TOPRIGHT",    overlay, "TOPRIGHT",    0, 0)
  overlay.borderRight:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
  overlay.borderRight:SetWidth(borderSize)

  overlay.gradient = CreateFrame("StatusBar", nil, hpBar)
  overlay.gradient:SetFrameLevel(hpLevel + 2)
  overlay.gradient:SetAllPoints(hpBar)
  overlay.gradient:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
  overlay.gradient:GetStatusBarTexture():SetBlendMode("ADD")
  overlay.gradient:SetMinMaxValues(0, 1)
  overlay.gradient:SetValue(1)
  overlay.gradient:EnableMouse(false)
  overlay.gradient:Hide()

  local iconSize = 16
  local function CreateIconBar(atlasName)
    local icon = CreateFrame("StatusBar", nil, overlay)
    icon:SetFrameLevel(hpLevel + 6)
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    icon:SetMinMaxValues(0, 1)
    icon:SetValue(1)
    icon:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    icon:GetStatusBarTexture():SetAtlas(atlasName)
    icon:EnableMouse(false)
    icon:Hide()
    return icon
  end

  overlay.icons = {
    magic   = CreateIconBar("RaidFrame-Icon-DebuffMagic"),
    curse   = CreateIconBar("RaidFrame-Icon-DebuffCurse"),
    disease = CreateIconBar("RaidFrame-Icon-DebuffDisease"),
    poison  = CreateIconBar("RaidFrame-Icon-DebuffPoison"),
    bleed   = CreateIconBar("RaidFrame-Icon-DebuffBleed"),
  }

  overlay.pulseAnim = overlay:CreateAnimationGroup()
  overlay.pulseAnim:SetLooping("REPEAT")
  local fadeOut = overlay.pulseAnim:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0.3)
  fadeOut:SetDuration(0.5); fadeOut:SetOrder(1); fadeOut:SetSmoothing("IN_OUT")
  local fadeIn = overlay.pulseAnim:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0.3); fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.5); fadeIn:SetOrder(2); fadeIn:SetSmoothing("IN_OUT")

  overlay:Hide()
  return overlay
end

function U.HideDispelOverlay(overlay)
  if not overlay then return end
  if overlay.pulseAnim and overlay.pulseAnim:IsPlaying() then overlay.pulseAnim:Stop() end
  overlay:SetAlpha(1)
  overlay.borderTop:Hide(); overlay.borderBottom:Hide()
  overlay.borderLeft:Hide(); overlay.borderRight:Hide()
  overlay.gradient:Hide()
  if overlay.icons then
    for _, icon in pairs(overlay.icons) do icon:Hide() end
  end
  overlay:Hide()
end

local function ShowOverlaySecret(overlay, unit, auraInstanceID)
  if not C_UnitAuras.GetAuraDispelTypeColor then return end
  local bCurve = GetBorderCurve()
  if bCurve then
    local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, bCurve)
    if color then
      for _, key in ipairs({ "borderTop", "borderBottom", "borderLeft", "borderRight" }) do
        overlay[key]:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
        overlay[key]:Show()
      end
    end
  end
  local gCurve = GetGradientCurve()
  if gCurve then
    local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, gCurve)
    if color then
      overlay.gradient:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
      overlay.gradient:Show()
    end
  end
  local iconTypes = {
    { key="magic",   enum=DISPEL_ENUM.Magic   },
    { key="curse",   enum=DISPEL_ENUM.Curse   },
    { key="disease", enum=DISPEL_ENUM.Disease },
    { key="poison",  enum=DISPEL_ENUM.Poison  },
    { key="bleed",   enum=DISPEL_ENUM.Bleed   },
  }
  for _, t in ipairs(iconTypes) do
    local iCurve = GetIconCurve(t.enum)
    if iCurve and overlay.icons[t.key] then
      local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, iCurve)
      if color then
        overlay.icons[t.key]:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
        overlay.icons[t.key]:Show()
      end
    end
  end
  if not overlay.pulseAnim:IsPlaying() then overlay.pulseAnim:Play() end
  overlay:Show()
end

function U.UpdateDispelOverlay(unit, hpBar, overlay)
  if not unit or not hpBar or not overlay then return end
  if not UnitExists(unit) then U.HideDispelOverlay(overlay); return end
  local auraID = U.FindDispellableAura(unit)
  if not auraID then
    U.HideDispelOverlay(overlay)
    local border = hpBar.__brav_border
    if border then border:SetBackdropBorderColor(0, 0, 0, 0.9) end
    return
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil then
    ShowOverlaySecret(overlay, unit, auraID)
  else
    U.HideDispelOverlay(overlay)
  end
end

-- ============================================================================
-- HEAL PREDICTION + ABSORB BARS
-- ============================================================================

function U.CreateHealPredictBars(hpBar)
  local parent  = hpBar:GetParent() or hpBar
  local hpLevel = hpBar:GetFrameLevel() or 2

  local clipFrame = CreateFrame("Frame", nil, parent)
  clipFrame:SetAllPoints(hpBar)
  clipFrame:SetClipsChildren(true)
  clipFrame:SetFrameLevel(hpLevel + 1)
  clipFrame:EnableMouse(false)

  local absorbBar = CreateFrame("StatusBar", nil, clipFrame)
  absorbBar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
  absorbBar:SetStatusBarColor(0, 0.835, 1, 0.8)
  absorbBar:SetMinMaxValues(0, 1)
  absorbBar:SetValue(0)
  absorbBar:SetFrameLevel(hpLevel + 1)
  absorbBar:EnableMouse(false)
  absorbBar:Hide()

  local healBar = CreateFrame("StatusBar", nil, clipFrame)
  healBar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
  healBar:SetStatusBarColor(0.0, 0.8, 0.2, 0.7)
  healBar:SetMinMaxValues(0, 1)
  healBar:SetValue(0)
  healBar:SetFrameLevel(hpLevel + 2)
  healBar:EnableMouse(false)
  healBar:Hide()

  local separator = clipFrame:CreateTexture(nil, "OVERLAY", nil, 7)
  separator:SetTexture("Interface/Buttons/WHITE8x8")
  separator:SetVertexColor(1, 1, 1, 0.85)
  separator:SetWidth(1)
  separator:Hide()

  return { heal=healBar, absorb=absorbBar, clipFrame=clipFrame, separator=separator }
end

function U.UpdateHealPredictBars(unit, hpBar, bars)
  if not bars or not bars.heal or not bars.absorb then return end
  local healBar   = bars.heal
  local absorbBar = bars.absorb
  local healthFill = hpBar:GetStatusBarTexture()
  if not healthFill then healBar:Hide(); absorbBar:Hide(); return end

  local ok1, maxHP = pcall(UnitHealthMax, unit)
  if not ok1 then healBar:Hide(); absorbBar:Hide(); return end

  local incomingHeals
  if CreateUnitHealPredictionCalculator then
    if not bars.calculator then
      bars.calculator = CreateUnitHealPredictionCalculator()
    end
    pcall(function()
      local calc = bars.calculator
      calc:SetIncomingHealClampMode(1)
      calc:SetIncomingHealOverflowPercent(1.0)
      UnitGetDetailedHealPrediction(unit, "player", calc)
      local amount, fromHealer = calc:GetIncomingHeals()
      incomingHeals = fromHealer
    end)
  else
    local ok, heals = pcall(UnitGetIncomingHeals, unit, "player")
    if ok then incomingHeals = heals end
  end

  local absorb
  do
    local ok, abs = pcall(UnitGetTotalAbsorbs, unit)
    if ok then absorb = abs end
  end

  local barWidth = hpBar:GetWidth() or 100

  healBar:ClearAllPoints()
  healBar:SetPoint("TOPLEFT",    healthFill, "TOPRIGHT",    0, 0)
  healBar:SetPoint("BOTTOMLEFT", healthFill, "BOTTOMRIGHT", 0, 0)
  healBar:SetWidth(barWidth)
  pcall(function()
    healBar:SetMinMaxValues(0, maxHP)
    healBar:SetValue(incomingHeals or 0)
  end)
  local hasHeals = incomingHeals ~= nil
  if hasHeals then healBar:Show() else healBar:Hide() end

  absorbBar:ClearAllPoints()
  absorbBar:SetPoint("TOPLEFT",    healthFill, "TOPRIGHT",    0, 0)
  absorbBar:SetPoint("BOTTOMLEFT", healthFill, "BOTTOMRIGHT", 0, 0)
  absorbBar:SetWidth(barWidth)
  pcall(function()
    absorbBar:SetMinMaxValues(0, maxHP)
    absorbBar:SetValue(absorb or 0)
  end)
  absorbBar:Show()

  local sep = bars.separator
  if sep then
    if hasHeals or absorb then
      sep:ClearAllPoints()
      sep:SetPoint("TOP",    healthFill, "TOPRIGHT",    0, 0)
      sep:SetPoint("BOTTOM", healthFill, "BOTTOMRIGHT", 0, 0)
      sep:Show()
    else
      sep:Hide()
    end
  end
end

-- ============================================================================
-- UNITFRAME FACTORIES
-- ============================================================================

local UF_FONT = BravLib.Media.Get("font", "uf") or BravLib.Media.Get("font", "default") or STANDARD_TEXT_FONT
U.UF_FONT = UF_FONT

-- ============================================================
-- 1. DB CONFIG GETTERS FACTORY
-- ============================================================

function U.MakeConfigGetters(dbKey)
  local function GetConfig()
    local db = BravLib.Storage.GetDB()
    if not db or not db.unitframes then return nil end
    return db.unitframes[dbKey]
  end

  local function GetConfigValue(key, default)
    local cfg = GetConfig()
    if cfg and cfg[key] ~= nil then return cfg[key] end
    return default
  end

  local function GetHeightConfig(key, default)
    local cfg = GetConfig()
    if cfg and cfg.height and cfg.height[key] ~= nil then return cfg.height[key] end
    return default
  end

  local function GetColorConfig()
    local cfg = GetConfig()
    if cfg and cfg.colors then return cfg.colors end
    return nil
  end

  local function GetTextConfig(key)
    local cfg = GetConfig()
    if cfg and cfg.text and cfg.text[key] then return cfg.text[key] end
    return nil
  end

  return GetConfig, GetConfigValue, GetHeightConfig, GetColorConfig, GetTextConfig
end

-- ============================================================
-- 2. THROTTLE FACTORIES
-- ============================================================

function U.CreateThrottler(interval, updateFn)
  local dirty     = false
  local scheduled = false

  local function Flush()
    scheduled = false
    if not dirty then return end
    dirty = false
    updateFn()
  end

  local function MarkDirty()
    dirty = true
    if not scheduled then
      scheduled = true
      C_Timer.After(interval, Flush)
    end
  end

  return MarkDirty
end

function U.CreateTickerThrottler(interval, updateFn)
  local dirty      = false
  local applyDirty = false

  local function FlushDirty()
    if not dirty then return end
    dirty = false
    local doApply = applyDirty
    applyDirty = false
    updateFn(doApply)
  end

  C_Timer.NewTicker(interval, FlushDirty)

  local function MarkDirty(withApply)
    dirty = true
    if withApply then applyDirty = true end
  end

  return MarkDirty, FlushDirty
end

function U.CreateMemberThrottler(interval, updateFn)
  local dirtySlots = {}
  local scheduled  = false

  local function Flush()
    scheduled = false
    for slot in pairs(dirtySlots) do
      dirtySlots[slot] = nil
      updateFn(slot)
    end
  end

  local function MarkMemberDirty(slot)
    dirtySlots[slot] = true
    if not scheduled then
      scheduled = true
      C_Timer.After(interval, Flush)
    end
  end

  return MarkMemberDirty
end

-- ============================================================
-- 3. STATUSBAR FACTORY
-- ============================================================

function U.CreateBar(parent, tex)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetAllPoints(parent)
  bar:SetStatusBarTexture(tex or TEX_WHITE)
  bar:SetMinMaxValues(0, 1)
  bar:EnableMouse(false)
  U.Create1pxBorder(bar)
  U.CreateBarBackground(bar)
  return bar
end

-- ============================================================
-- 4. FONTSTRING FACTORY
-- ============================================================

function U.CreateText(parent, point, justify, fontSize, offsetX, offsetY)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetPoint(point, parent, point, offsetX or 0, offsetY or 0)
  fs:SetJustifyH(justify or point)
  fs:SetWordWrap(false)
  fs:SetFontObject("GameFontHighlightSmall")
  pcall(function() fs:SetFont(UF_FONT, fontSize or 12, "OUTLINE") end)
  return fs
end

-- ============================================================
-- 5. COLOR UPDATE HELPERS
-- ============================================================

function U.UpdateHPColor(unit, hpBar, colorCfg, opts)
  local useClassColor = not colorCfg or colorCfg.useClassColor ~= false

  if UnitIsPlayer(unit) or not (opts and opts.allowReaction) then
    if useClassColor then
      local _, class = UnitClass(unit)
      local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
      if c then
        hpBar:SetStatusBarColor(c.r, c.g, c.b)
      else
        hpBar:SetStatusBarColor(0.6, 0.6, 0.6)
      end
    else
      local custom = colorCfg and colorCfg.hpCustom
      if custom and custom.r then
        hpBar:SetStatusBarColor(custom.r, custom.g, custom.b)
      else
        hpBar:SetStatusBarColor(0.2, 0.8, 0.2)
      end
    end
  else
    local useReaction = not colorCfg or colorCfg.useReaction ~= false
    if useReaction then
      local r, g, b = UnitSelectionColor(unit)
      if r and g and b then
        hpBar:SetStatusBarColor(r, g, b)
      else
        hpBar:SetStatusBarColor(0.6, 0.6, 0.6)
      end
    else
      local custom = colorCfg and colorCfg.hpCustom
      if custom and custom.r then
        hpBar:SetStatusBarColor(custom.r, custom.g, custom.b)
      else
        hpBar:SetStatusBarColor(0.8, 0.2, 0.2)
      end
    end
  end
end

function U.UpdatePowerColor(unit, powerBar, colorCfg)
  local usePowerColor = not colorCfg or colorCfg.usePowerColor ~= false
  if usePowerColor then
    local _, pToken = UnitPowerType(unit)
    U.SetBarColorByKey(powerBar, pToken)
  else
    local custom = colorCfg and colorCfg.powerCustom
    if custom and custom.r then
      powerBar:SetStatusBarColor(custom.r, custom.g, custom.b)
    else
      powerBar:SetStatusBarColor(0.2, 0.4, 0.8)
    end
  end
end

function U.UpdateHPColorCascade(unit, hpBar)
  local ok1 = pcall(function()
    local _, class = UnitClass(unit)
    if C_ClassColor and C_ClassColor.GetClassColor then
      local cc = C_ClassColor.GetClassColor(class)
      if cc then hpBar:SetStatusBarColor(cc.r, cc.g, cc.b) end
    end
  end)
  if ok1 then return end

  local ok2 = pcall(function()
    local _, class = UnitClass(unit)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then hpBar:SetStatusBarColor(c.r, c.g, c.b) end
  end)
  if ok2 then return end

  local ok3 = pcall(function() hpBar:SetStatusBarColor(UnitSelectionColor(unit)) end)
  if not ok3 then pcall(hpBar.SetStatusBarColor, hpBar, 0.6, 0.6, 0.6) end
end

function U.UpdatePowerColorCascade(unit, powerBar)
  pcall(function()
    local _, pType = UnitPowerType(unit)
    local pc = pType and PowerBarColor and PowerBarColor[pType]
    if pc then
      powerBar:SetStatusBarColor(pc.r, pc.g, pc.b)
    else
      powerBar:SetStatusBarColor(0.5, 0.5, 0.5)
    end
  end)
end

-- ============================================================
-- 6. SECURE CLICK OVERLAY FACTORY
-- ============================================================

function U.CreateClickOverlay(globalName, unit)
  local overlay = CreateFrame("Button", globalName, UIParent, "SecureUnitButtonTemplate")
  overlay:SetFrameStrata("MEDIUM")
  overlay:SetFrameLevel(9999)
  overlay:EnableMouse(true)
  overlay:RegisterForClicks("AnyUp")
  overlay:SetAttribute("unit",    unit)
  overlay:SetAttribute("*type1",  "target")
  overlay:SetAttribute("*type2",  "togglemenu")

  overlay:SetScript("OnEnter", function(self)
    if not UnitExists(unit) then return end
    GameTooltip:Hide()
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    if type(GameTooltip_SetDefaultAnchor) == "function" then
      GameTooltip_SetDefaultAnchor(GameTooltip, self)
    else
      GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -32, 32)
    end
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
  end)

  overlay:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return overlay
end

function U.SyncClickOverlay(overlay, frame)
  if not overlay then return end
  if InCombatLockdown() then return false end
  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, 0)
  overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  return true
end

function U.HookOverlaySync(frame, syncFn, opts)
  local origSetPoint = frame.SetPoint
  frame.SetPoint = function(self, ...)
    origSetPoint(self, ...)
    if not self._moverDragging then syncFn() end
  end

  local origClearAllPoints = frame.ClearAllPoints
  frame.ClearAllPoints = function(self, ...)
    origClearAllPoints(self, ...)
    if not self._moverDragging then syncFn() end
  end

  frame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    if opts and opts.moverGuard and BravUI.Mover and BravUI.Mover:IsActive() then return end
    if not opts or not opts.moverGuard then
      if not IsAltKeyDown() then return end
    end
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    syncFn()
  end)
end

-- ============================================================
-- 7. ICON FACTORIES
-- ============================================================

local LEADER_TEX = "Interface/GroupFrame/UI-Group-LeaderIcon"
local ASSIST_TEX = "Interface/GroupFrame/UI-Group-AssistantIcon"
local REZ_TEX    = "Interface/RaidFrame/Raid-Icon-Rez"
local WM_TEX     = "Interface/TargetingFrame/UI-PVP-FFA"

function U.CreateLeaderIcon(parent, size)
  local tex = parent:CreateTexture(nil, "OVERLAY", nil, 2)
  tex:SetSize(size or 16, size or 16)
  tex:SetTexture(LEADER_TEX)
  tex:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 15)
  tex:SetAlpha(1)
  tex:Hide()
  return tex
end

function U.CreateAssistIcon(parent, leaderIcon, size)
  local tex = parent:CreateTexture(nil, "OVERLAY", nil, 2)
  tex:SetSize(size or 13, size or 13)
  tex:SetTexture(ASSIST_TEX)
  tex:SetPoint("LEFT", leaderIcon, "RIGHT", 2, 0)
  tex:SetAlpha(0.9)
  tex:Hide()
  return tex
end

function U.CreateRezIcon(parent, size)
  local holder = U.CreateIconFrame(parent, size or 16, "CENTER", parent, -10, 0)
  holder.tex:SetTexture(REZ_TEX)
  return holder
end

function U.CreateWMIcon(parent, size)
  local holder = U.CreateIconFrame(parent, size or 16, "CENTER", parent, 10, 0)
  holder.tex:SetTexture(WM_TEX)
  return holder
end

function U.UpdateRezIcon(unit, holder)
  local ok, val = pcall(UnitHasIncomingResurrection, unit)
  local hasRez = false
  if ok then
    local ok2, isTrue = pcall(function() return val == true end)
    if ok2 then hasRez = isTrue end
  end
  holder:SetShown(hasRez)
end

function U.UpdateWMIcon(unit, holder)
  if IsInInstance() then holder:Hide(); return end
  local ok, val = pcall(UnitIsPVP, unit)
  local isPvP = false
  if ok then
    local ok2, isTrue = pcall(function() return val == true end)
    if ok2 then isPvP = isTrue end
  end
  holder:SetShown(isPvP)
end

function U.UpdateLeaderIcons(unit, leaderIcon, assistIcon)
  if IsInGroup() then
    if UnitIsGroupLeader(unit) then
      leaderIcon:Show(); assistIcon:Hide()
    elseif UnitIsGroupAssistant(unit) then
      leaderIcon:Hide(); assistIcon:Show()
    else
      leaderIcon:Hide(); assistIcon:Hide()
    end
  else
    leaderIcon:Hide(); assistIcon:Hide()
  end
end

-- ============================================================
-- 8. TEXT CONFIG HELPER
-- ============================================================

local function JustifyFromPoint(pt)
  if pt:find("LEFT")  then return "LEFT"  end
  if pt:find("RIGHT") then return "RIGHT" end
  return "CENTER"
end

function U.ApplyTextConfig(fs, textCfg, parent, point, defSize, defOffX, defOffY)
  if not textCfg then return end
  if textCfg.enabled == false then fs:Hide(); return end
  fs:Show()
  local anchor = textCfg.anchor or point
  local size   = textCfg.size   or defSize
  pcall(function() fs:SetFont(UF_FONT, size, "OUTLINE") end)
  fs:SetJustifyH(JustifyFromPoint(anchor))
  fs:ClearAllPoints()
  fs:SetPoint(anchor, parent, anchor, textCfg.offsetX or defOffX, textCfg.offsetY or defOffY)
end

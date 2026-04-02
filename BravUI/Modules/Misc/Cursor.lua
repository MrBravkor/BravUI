-- BravUI/Modules/Misc/Cursor.lua
-- Cursor tracking: rings (static, GCD, cast), ping, crosshair, trail
-- Portage v2 : Init + CursorFrame + Trail fusionnés, no Ace, no external deps

local BravUI = BravUI
local U = BravUI.Utils

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local Cursor = {}
BravUI:RegisterModule("Misc.Cursor", Cursor)

-- ============================================================================
-- MEDIA
-- ============================================================================

local RING_TEX = BravLib.Media.Get("texture", "cursor_ring")
    or "Interface/AddOns/BravUI_Lib/BravLib_Media/Cursor/Ring.tga"
local DOT_TEX = BravLib.Media.Get("texture", "cursor_dot")
    or "Interface/AddOns/BravUI_Lib/BravLib_Media/Cursor/Dot.tga"

-- ============================================================================
-- DB HELPER
-- ============================================================================

local function GetDB()
  return BravLib.API.GetModule("cursor") or {}
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local GCD_SPELL_ID = 61304

-- ============================================================================
-- STATE
-- ============================================================================

local db
local cr, cg, cb = 0.2, 1.0, 0.8
local inCombat = false

local lastShift, lastCtrl, lastAlt = false, false, false

local isPingAnimating   = false
local pingTimer         = 0
local isCrosshairAnimating = false
local crosshairTimer    = 0

-- Trail
local trailPool   = {}
local trailActive = {}
local trailTimer  = 0
local trailLastX  = 0
local trailLastY  = 0

-- Frame refs
local cursorFrame, mainRing, reticle
local gcdFrame, gcdBg, castFrame, castBg
local pingTexture, crosshairFrame
local tracker

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetClassColor()
  return U.GetClassColor("player")
end

local function ClockToRadians(pos)
  local p = (pos == 12) and 0 or pos
  return p * math.pi / 6
end

-- ============================================================================
-- CROSSHAIR CREATION
-- ============================================================================

local function CreateCrosshair()
  local ch = CreateFrame("Frame", "BravUI_CrosshairFrame", UIParent)
  ch:SetFrameStrata("BACKGROUND")
  ch:SetAllPoints()
  ch:EnableMouse(false)
  ch:Hide()

  local function MakeLine(isVertical)
    local line = ch:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(cr, cg, cb, 0.5)
    if isVertical then line:SetWidth(2) else line:SetHeight(2) end
    return line
  end

  ch.Top    = MakeLine(true)
  ch.Bottom = MakeLine(true)
  ch.Left   = MakeLine(false)
  ch.Right  = MakeLine(false)

  crosshairFrame = ch
end

-- ============================================================================
-- CROSSHAIR POSITIONING
-- ============================================================================

local function UpdateCrosshairPosition()
  if not crosshairFrame then return end

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  local cx = cursorX / scale
  local cy = cursorY / scale
  local gap = (db.crossGap or 35) * (db.scale or 1.0)

  local ch = crosshairFrame
  ch.Top:ClearAllPoints()
  ch.Top:SetPoint("TOP", UIParent, "TOPLEFT", cx, 0)
  ch.Top:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, cy + gap)

  ch.Bottom:ClearAllPoints()
  ch.Bottom:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, 0)
  ch.Bottom:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx, cy - gap)

  ch.Left:ClearAllPoints()
  ch.Left:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, cy)
  ch.Left:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", cx - gap, cy)

  ch.Right:ClearAllPoints()
  ch.Right:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, cy)
  ch.Right:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx + gap, cy)
end

-- ============================================================================
-- MODIFIER KEY TRACKING
-- ============================================================================

local function HandleModAction(action)
  if not action or action == "None" then return end
  if action == "Ping" then
    isPingAnimating = true
    pingTimer = 0
    if pingTexture then
      local sz = db.pingStartSize or 200
      pingTexture:SetSize(sz, sz)
      pingTexture:SetAlpha(0.6)
      pingTexture:Show()
    end
  elseif action == "Crosshair" then
    isCrosshairAnimating = true
    crosshairTimer = 0
    if crosshairFrame then
      crosshairFrame:SetAlpha(1.0)
      crosshairFrame:Show()
      UpdateCrosshairPosition()
    end
  end
end

local function UpdateModifiers()
  local shift = IsShiftKeyDown()
  local ctrl  = IsControlKeyDown()
  local alt   = IsAltKeyDown()

  if shift and not lastShift then HandleModAction(db.shiftAction) end
  if ctrl  and not lastCtrl  then HandleModAction(db.ctrlAction)  end
  if alt   and not lastAlt   then HandleModAction(db.altAction)   end

  lastShift = shift
  lastCtrl  = ctrl
  lastAlt   = alt
end

-- ============================================================================
-- TRAIL
-- ============================================================================

local function InitTrail()
  if #trailPool > 0 then return end

  local poolSize = 200
  for i = 1, poolSize do
    local tex = UIParent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(DOT_TEX)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(cr, cg, cb, 1.0)
    tex:Hide()
    trailPool[i] = tex
  end
end

local function UpdateTrail(elapsed)
  if not db.enableTrail then return end
  if #trailPool == 0 and #trailActive == 0 then return end

  local cursorX, cursorY = GetCursorPosition()
  local uiScale = UIParent:GetEffectiveScale()

  local dx = cursorX - trailLastX
  local dy = cursorY - trailLastY
  local movement = (dx * dx + dy * dy) ^ 0.5

  trailTimer = trailTimer + elapsed

  local density = db.trailDensity or 0.005
  local minMove = db.trailMinMove or 0.5

  if trailTimer >= density and movement >= minMove and #trailPool > 0 then
    trailTimer = 0

    local elem = trailPool[#trailPool]
    trailPool[#trailPool] = nil

    elem._life    = db.trailDuration or 0.5
    elem._maxLife = elem._life

    local x = cursorX / uiScale
    local y = cursorY / uiScale
    local baseSize = 50 * (db.trailScale or 1.0)

    elem:SetSize(baseSize, baseSize)
    elem:ClearAllPoints()
    elem:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    elem:SetAlpha(1.0)
    elem:Show()

    trailActive[#trailActive + 1] = elem
    trailLastX = cursorX
    trailLastY = cursorY
  end

  for i = #trailActive, 1, -1 do
    local elem = trailActive[i]
    elem._life = elem._life - elapsed

    if elem._life <= 0 then
      elem:Hide()
      trailActive[i] = trailActive[#trailActive]
      trailActive[#trailActive] = nil
      trailPool[#trailPool + 1] = elem
    else
      local progress = elem._life / elem._maxLife
      local baseSize = 50 * (db.trailScale or 1.0)
      local size = baseSize * progress
      if size < 3 then size = 3 end
      elem:SetSize(size, size)
      elem:SetAlpha(progress)
    end
  end
end

-- ============================================================================
-- GCD / CAST HANDLERS (secret-safe)
-- ============================================================================

local function HandleGCD()
  if not gcdFrame then return end
  local ok = pcall(function()
    local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
    if not info then return end
    gcdFrame:SetCooldown(info.startTime, info.duration)
  end)
  if not ok then
    gcdFrame:SetCooldown(GetTime(), 1.5)
  end
end

local function HandleCastStart()
  if not castFrame then return end
  pcall(function()
    local _, _, _, st, et = UnitCastingInfo("player")
    if st and et then
      local dur   = (et - st) / 1000
      local start = st / 1000
      castFrame:SetReverse(db.castFillDrain == "fill")
      castFrame:SetCooldown(start, dur)
      castFrame:Show()
    end
  end)
end

local function HandleChannelStart()
  if not castFrame then return end
  pcall(function()
    local _, _, _, st, et = UnitChannelInfo("player")
    if st and et then
      local dur   = (et - st) / 1000
      local start = st / 1000
      castFrame:SetReverse(db.castFillDrain ~= "fill")
      castFrame:SetCooldown(start, dur)
      castFrame:Show()
    end
  end)
end

local function HandleCastStop()
  if castFrame then castFrame:Hide() end
end

-- ============================================================================
-- VISIBILITY
-- ============================================================================

local function UpdateVisibility(force)
  if not cursorFrame then return end
  if not db or not db.enabled then
    cursorFrame:Hide()
    return
  end
  if db.combatOnly then
    cursorFrame:SetShown(force or inCombat)
  else
    cursorFrame:Show()
  end
end

-- ============================================================================
-- ONUPDATE
-- ============================================================================

local function OnUpdate(self, elapsed)
  if not cursorFrame or not db or not db.enabled then return end
  if not cursorFrame:IsShown() then return end

  local cursorX, cursorY = GetCursorPosition()
  local uiScale = UIParent:GetScale()
  local s = db.scale or 1.0

  local cx = (cursorX / uiScale) / s
  local cy = (cursorY / uiScale) / s

  cursorFrame:ClearAllPoints()
  cursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

  UpdateTrail(elapsed)
  UpdateModifiers()

  -- Ping animation
  if isPingAnimating then
    pingTimer = pingTimer + elapsed
    local dur = db.pingDuration or 0.5
    if pingTimer >= dur then
      isPingAnimating = false
      if pingTexture then pingTexture:Hide() end
    elseif pingTexture then
      local progress = pingTimer / dur
      local startSz = db.pingStartSize or 200
      local endSz   = db.pingEndSize or 60
      local size = startSz - ((startSz - endSz) * progress)
      pingTexture:SetSize(size, size)
      pingTexture:SetAlpha((1.0 - progress) * 0.6)
    end
  end

  -- Crosshair animation
  if isCrosshairAnimating then
    crosshairTimer = crosshairTimer + elapsed
    local dur = db.crossDuration or 1.5
    if crosshairTimer >= dur then
      isCrosshairAnimating = false
      if crosshairFrame then crosshairFrame:Hide() end
    else
      local progress = crosshairTimer / dur
      local alpha = 1.0
      if progress > 0.7 then
        alpha = 1.0 - ((progress - 0.7) / 0.3)
      end
      if crosshairFrame then
        crosshairFrame:SetAlpha(alpha)
        UpdateCrosshairPosition()
      end
    end
  end
end

-- ============================================================================
-- EVENT HANDLER
-- ============================================================================

local function OnEvent(self, event, unit, ...)
  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    UpdateVisibility(true)
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
    UpdateVisibility(false)
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" then HandleGCD() end
    return
  end

  if unit and unit ~= "player" then return end

  if event == "UNIT_SPELLCAST_START" then
    HandleCastStart()
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    HandleChannelStart()
  elseif event == "UNIT_SPELLCAST_STOP"
      or event == "UNIT_SPELLCAST_CHANNEL_STOP"
      or event == "UNIT_SPELLCAST_INTERRUPTED" then
    HandleCastStop()
  end
end

-- ============================================================================
-- CURSOR FRAME CREATION
-- ============================================================================

local function InitCursor()
  if cursorFrame then return end

  cr, cg, cb = GetClassColor()

  local f = CreateFrame("Frame", "BravUI_CursorFrame", UIParent)
  f:SetSize(1, 1)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(false)
  f:EnableMouse(false)
  f:SetClampedToScreen(false)
  f:SetScale(db.scale or 1.0)
  cursorFrame = f

  -- Main ring
  if db.showMainRing then
    mainRing = f:CreateTexture(nil, "ARTWORK")
    mainRing:SetTexture(RING_TEX)
    mainRing:SetSize(db.mainRingSize or 90, db.mainRingSize or 90)
    mainRing:SetPoint("CENTER")
    mainRing:SetVertexColor(cr, cg, cb, db.alpha or 1.0)
  end

  -- Reticle dot
  if db.showReticle then
    reticle = f:CreateTexture(nil, "OVERLAY")
    reticle:SetTexture(DOT_TEX)
    reticle:SetSize(db.reticleSize or 8, db.reticleSize or 8)
    reticle:SetPoint("CENTER")
    reticle:SetVertexColor(cr, cg, cb, 1)
  end

  -- GCD ring
  if db.showGCD then
    gcdBg = CreateFrame("Cooldown", nil, f)
    gcdBg:SetSize(db.gcdSize or 44, db.gcdSize or 44)
    gcdBg:SetPoint("CENTER")
    gcdBg:SetFrameLevel(2)
    gcdBg:SetSwipeTexture(RING_TEX)
    gcdBg:SetSwipeColor(0.5, 0.5, 0.5, 0.25)
    gcdBg:SetHideCountdownNumbers(true)
    gcdBg:SetDrawEdge(false)
    gcdBg:SetDrawBling(false)
    gcdBg:SetCooldown(GetTime() - 1, 0.01)

    gcdFrame = CreateFrame("Cooldown", nil, f)
    gcdFrame:SetSize(db.gcdSize or 44, db.gcdSize or 44)
    gcdFrame:SetPoint("CENTER")
    gcdFrame:SetFrameLevel(3)
    gcdFrame:SetSwipeTexture(RING_TEX)
    gcdFrame:SetSwipeColor(cr, cg, cb, 0.9)
    gcdFrame:SetHideCountdownNumbers(true)
    gcdFrame:SetDrawEdge(false)
    gcdFrame:SetDrawBling(false)
    gcdFrame:SetReverse(db.gcdFillDrain == "fill")
    gcdFrame:SetRotation(ClockToRadians(db.gcdRotation or 12))
  end

  -- Cast ring
  if db.showCast then
    castBg = CreateFrame("Cooldown", nil, f)
    castBg:SetSize(db.castSize or 140, db.castSize or 140)
    castBg:SetPoint("CENTER")
    castBg:SetFrameLevel(2)
    castBg:SetSwipeTexture(RING_TEX)
    castBg:SetSwipeColor(0.5, 0.5, 0.5, 0.25)
    castBg:SetHideCountdownNumbers(true)
    castBg:SetDrawEdge(false)
    castBg:SetDrawBling(false)
    castBg:SetCooldown(GetTime() - 1, 0.01)

    castFrame = CreateFrame("Cooldown", nil, f)
    castFrame:SetSize(db.castSize or 140, db.castSize or 140)
    castFrame:SetPoint("CENTER")
    castFrame:SetFrameLevel(3)
    castFrame:SetSwipeTexture(RING_TEX)
    castFrame:SetSwipeColor(cr, cg, cb, 0.75)
    castFrame:SetHideCountdownNumbers(true)
    castFrame:SetDrawEdge(false)
    castFrame:SetDrawBling(false)
    castFrame:SetReverse(db.castFillDrain == "fill")
    castFrame:SetRotation(ClockToRadians(db.castRotation or 12))
    castFrame:Hide()
  end

  -- Ping texture
  pingTexture = f:CreateTexture(nil, "OVERLAY")
  pingTexture:SetTexture(RING_TEX)
  pingTexture:SetBlendMode("ADD")
  pingTexture:SetVertexColor(cr, cg, cb, 0.6)
  pingTexture:SetPoint("CENTER")
  pingTexture:Hide()

  -- Crosshair
  CreateCrosshair()

  -- Tracker frame (OnUpdate + events)
  tracker = CreateFrame("Frame", "BravUI_CursorTracker", UIParent)
  tracker:SetScript("OnUpdate", OnUpdate)

  tracker:RegisterEvent("PLAYER_REGEN_DISABLED")
  tracker:RegisterEvent("PLAYER_REGEN_ENABLED")

  if db.showGCD then
    tracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  end

  if db.showCast then
    tracker:RegisterEvent("UNIT_SPELLCAST_START")
    tracker:RegisterEvent("UNIT_SPELLCAST_STOP")
    tracker:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    tracker:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    tracker:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  end

  tracker:SetScript("OnEvent", OnEvent)

  UpdateVisibility()
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function Cursor:Enable()
  db = GetDB()
  if not db.enabled then return end

  cr, cg, cb = GetClassColor()

  InitCursor()

  if db.enableTrail then
    InitTrail()
  end
end

function Cursor:Disable()
  if cursorFrame then cursorFrame:Hide() end
  if tracker then
    tracker:SetScript("OnUpdate", nil)
    tracker:UnregisterAllEvents()
  end
  if crosshairFrame then crosshairFrame:Hide() end
end

-- Pages/Info.lua
-- BravUI Menu v2 — Info page (addon info, commands, authors, testers, guild)

local M = BravUI.Menu
local L = M.L
local T = M.Theme

-- Class atlas icons (WoW standard)
local CLASS_ATLAS = {
  PALADIN = "classicon-paladin",
  HUNTER  = "classicon-hunter",
  SHAMAN  = "classicon-shaman",
}

-- Class colors (RAID_CLASS_COLORS standard values)
local CLASS_COLORS = {
  PALADIN = { 0.96, 0.55, 0.73 },
  HUNTER  = { 0.67, 0.83, 0.45 },
  SHAMAN  = { 0.00, 0.44, 0.87 },
}

-- Slash commands
local COMMANDS = {
  { "/brav",         "Ouvrir le menu de configuration" },
  { "/bravmove",     "Deplacer les elements de l'interface" },
  { "/bravchat",     "Afficher/masquer l'historique du chat" },
  { "/bravdebug",    "Activer/desactiver le mode debug" },
}

local function GetVer(name)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(name, "Version") or "?"
  end
  return "?"
end

-- ── Fade-in animation ──
local function FadeIn(frame, duration)
  frame:SetAlpha(0)
  local ag = frame:CreateAnimationGroup()
  local anim = ag:CreateAnimation("Alpha")
  anim:SetFromAlpha(0)
  anim:SetToAlpha(1)
  anim:SetDuration(duration or 0.4)
  anim:SetSmoothing("OUT")
  ag:SetScript("OnFinished", function() frame:SetAlpha(1) end)
  ag:Play()
end

-- ── Section header with accent bar ──
local function AddSection(host, y, text)
  local cr, cg, cb = M:GetClassColor()
  local bar = host:CreateTexture(nil, "ARTWORK")
  bar:SetSize(3, 16)
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
  bar:SetColorTexture(cr, cg, cb, 0.80)

  local fs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(fs, 13, "OUTLINE")
  fs:SetPoint("LEFT", bar, "RIGHT", 8, 0)
  fs:SetText(text)
  fs:SetTextColor(cr, cg, cb, 1)
  return y + 26
end

-- ── Single text line ──
local function AddText(host, y, text, color, size)
  local fs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(fs, size or 11, "OUTLINE")
  fs:SetPoint("TOPLEFT", host, "TOPLEFT", 14, -y)
  fs:SetPoint("RIGHT", host, "RIGHT", -8, 0)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  if color then fs:SetTextColor(unpack(color)) end
  return y + (size or 11) + 5
end

-- ── Separator ──
local function AddSep(host, y)
  local cr, cg, cb = M:GetClassColor()
  local line = host:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(y + 6))
  line:SetPoint("RIGHT", host, "RIGHT", 0, 0)
  line:SetColorTexture(cr, cg, cb, 0.12)
  return y + 16
end

-- ── Version row (dot green/red, version green or hidden) ──
local function AddVersionRow(host, y, label, addonName)
  local exists = C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(addonName)
  local loaded = exists and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)

  local dot = host:CreateTexture(nil, "ARTWORK")
  dot:SetSize(6, 6)
  dot:SetPoint("TOPLEFT", host, "TOPLEFT", 18, -(y + 4))
  if loaded then
    dot:SetColorTexture(0.30, 0.90, 0.30, 1)
  else
    dot:SetColorTexture(0.90, 0.30, 0.30, 1)
  end

  local nameFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(nameFs, 11, "OUTLINE")
  nameFs:SetPoint("LEFT", dot, "RIGHT", 6, 0)
  nameFs:SetText(label)
  if loaded then
    nameFs:SetTextColor(unpack(T.TEXT))
  else
    nameFs:SetTextColor(unpack(T.MUTED))
  end

  if loaded then
    local ver = GetVer(addonName)
    local verFs = host:CreateFontString(nil, "OVERLAY")
    M:SafeFont(verFs, 10, "OUTLINE")
    verFs:SetPoint("RIGHT", host, "RIGHT", -14, 0)
    verFs:SetPoint("TOP", dot, "TOP", 0, 1)
    verFs:SetText("v" .. ver)
    verFs:SetTextColor(0.30, 0.90, 0.30, 1)
  end

  return y + 18
end

-- ── Tester row with class icon + colored name ──
local function AddTester(host, y, name, className, role)
  local clr = CLASS_COLORS[className] or { 1, 1, 1 }
  local atlas = CLASS_ATLAS[className]

  if atlas then
    local icon = host:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", host, "TOPLEFT", 18, -(y + 1))
    icon:SetAtlas(atlas)
  end

  local nameFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(nameFs, 11, "OUTLINE")
  nameFs:SetPoint("TOPLEFT", host, "TOPLEFT", atlas and 38 or 18, -y)
  nameFs:SetText(name)
  nameFs:SetTextColor(clr[1], clr[2], clr[3], 1)

  if role then
    local roleFs = host:CreateFontString(nil, "OVERLAY")
    M:SafeFont(roleFs, 10, "OUTLINE")
    roleFs:SetPoint("TOPLEFT", host, "TOPLEFT", 130, -y)
    roleFs:SetText("-  " .. role)
    roleFs:SetTextColor(unpack(T.MUTED))
  end

  return y + 20
end

-- ── Command row (cyan command + muted description, aligned column) ──
local CMD_DESC_X = 130 -- fixed X for description alignment
local function AddCommand(host, y, cmd, desc)
  local cmdFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(cmdFs, 11, "OUTLINE")
  cmdFs:SetPoint("TOPLEFT", host, "TOPLEFT", 18, -y)
  cmdFs:SetText(cmd)
  cmdFs:SetTextColor(0, 1, 1, 1)

  local descFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(descFs, 10, "OUTLINE")
  descFs:SetPoint("TOPLEFT", host, "TOPLEFT", CMD_DESC_X, -y)
  descFs:SetText("-  " .. desc)
  descFs:SetTextColor(unpack(T.MUTED))

  return y + 16
end

-- ════════════════════════════════════════════════════════════════════════════
-- PAGE
-- ════════════════════════════════════════════════════════════════════════════

M:RegisterPage("info", 97, L["page_info"] or "Info", function(parent, add)
  local host = CreateFrame("Frame", nil, parent)
  host:SetPoint("TOPLEFT", parent, "TOPLEFT", T.PAD, -T.PAD)
  host:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -T.PAD, -T.PAD)
  add(host)

  local cr, cg, cb = M:GetClassColor()
  local y = 0

  -- ── L'addon ──
  y = AddSection(host, y, L["info_section_addon"])

  local addons = {
    { L["info_addon_core"],                "BravUI" },
    { L["info_addon_lib"] or "BravUI Lib", "BravUI_Lib" },
    { L["info_addon_menu"],                "BravUI_Menu" },
    { L["info_addon_elt"],                 "!BravUI_ErrorTracker" },
  }

  for _, info in ipairs(addons) do
    y = AddVersionRow(host, y, info[1], info[2])
  end

  y = AddSep(host, y)

  -- ── Commandes ──
  y = AddSection(host, y, L["info_section_commands"] or "Commandes")

  for _, cmd in ipairs(COMMANDS) do
    y = AddCommand(host, y, cmd[1], cmd[2])
  end

  y = AddSep(host, y)

  -- ── Auteur ──
  y = AddSection(host, y, L["info_section_author"])

  local authorIcon = host:CreateTexture(nil, "ARTWORK")
  authorIcon:SetSize(14, 14)
  authorIcon:SetPoint("TOPLEFT", host, "TOPLEFT", 18, -(y + 1))
  authorIcon:SetAtlas("classicon-druid")

  local authorFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(authorFs, 11, "OUTLINE")
  authorFs:SetPoint("TOPLEFT", host, "TOPLEFT", 38, -y)
  authorFs:SetText("|cffFF7D0AMrBravkor|r  (Alias |cffFF7D0ADarkFeral|r)")

  local authorRole = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(authorRole, 10, "OUTLINE")
  authorRole:SetPoint("TOPLEFT", host, "TOPLEFT", 220, -y)
  authorRole:SetText("-  Developpeur & Designer")
  authorRole:SetTextColor(unpack(T.MUTED))
  y = y + 20

  y = AddSep(host, y)

  -- ── Testeurs ──
  y = AddSection(host, y, L["info_section_testers"])
  y = AddTester(host, y, "Godess", "HUNTER", L["info_tester_gm"] or "GM")
  y = AddTester(host, y, "Frisacalex", "PALADIN", L["info_tester_rl"] or "RL")

  y = AddSep(host, y)

  -- ── Guilde ──
  y = AddSection(host, y, L["info_section_guild"])
  y = AddText(host, y, "|cffff4444Le Sang du Dragon|r  -  |cffff4444Ysondre EU|r", T.TEXT)
  y = y + 6
  y = y + 6
  local thanksFs = host:CreateFontString(nil, "OVERLAY")
  M:SafeFont(thanksFs, 10, "OUTLINE")
  thanksFs:SetPoint("TOPLEFT", host, "TOPLEFT", 14, -y)
  thanksFs:SetPoint("RIGHT", host, "RIGHT", -8, 0)
  thanksFs:SetJustifyH("LEFT")
  thanksFs:SetWordWrap(true)
  thanksFs:SetText("Un grand merci a ma guilde pour leur soutien, leur patience... et leur tolerance. Developper BravUI en plein raid n'est pas toujours une experience de tout repos — entre les erreurs Lua en plein combat et les crashes au mauvais moment, ils ont tout vecu. Une mention speciale a Godess et Frisacalex qui se sont retrouves testeurs malgre eux — personne ne leur a demande leur avis, et malheureusement pour eux, en tant que GM et RL, ils ne pouvaient pas vraiment fuir. Merci a tous d'avoir continue a jouer malgre tout. Sans vous, BravUI ne serait pas ce qu'il est aujourd'hui.")
  thanksFs:SetTextColor(unpack(T.MUTED))
  y = y + thanksFs:GetStringHeight() + 4

  host:SetHeight(y + T.PAD)

  -- Fade-in
  FadeIn(host, 0.5)
end)

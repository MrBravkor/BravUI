-- BravUI/Modules/Cooldown/Init.lua
-- Namespace, helpers partages, bootstrap CDM
-- Portage v2 depuis BravUI_Cooldown standalone

BravUI.Cooldown = BravUI.Cooldown or {}

local NS = BravUI.Cooldown
local U  = BravUI.Utils

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TEX = "Interface/Buttons/WHITE8x8"
NS.TEX = TEX

-- ============================================================================
-- HELPERS (expose sur NS pour les sous-modules)
-- ============================================================================

function NS.GetFont()
    return U.GetFont()
end

function NS.GetBorderColor()
    local db = BravLib.API.GetModule("cooldown")
    local bc = db and db.cdm and db.cdm.iconBorderColor
    if bc and bc.r then
        return bc.r, bc.g, bc.b, 1
    end
    return U.GetClassColor("player")
end

NS.Abbrev = function(v) return U.AbbrevNumber(v) or U.SafeToString(v) end

-- ============================================================================
-- FRAME HELPERS (borders + background)
-- Version NS : compatible avec le pattern _borders / _bg du Skin
-- ============================================================================

local PU = PixelUtil

function NS.CreateClassBorder(frame)
    local r, g, b = NS.GetBorderColor()
    local borders = {}

    local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture(TEX)
    top:SetVertexColor(r, g, b, 1)
    PU.SetPoint(top, "TOPLEFT", frame, "TOPLEFT", -1, 1)
    PU.SetPoint(top, "TOPRIGHT", frame, "TOPRIGHT", 1, 1)
    PU.SetHeight(top, 1)
    borders.top = top

    local bot = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    bot:SetTexture(TEX)
    bot:SetVertexColor(r, g, b, 1)
    PU.SetPoint(bot, "BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
    PU.SetPoint(bot, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    PU.SetHeight(bot, 1)
    borders.bottom = bot

    local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture(TEX)
    left:SetVertexColor(r, g, b, 1)
    PU.SetPoint(left, "TOPLEFT", frame, "TOPLEFT", -1, 1)
    PU.SetPoint(left, "BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
    PU.SetWidth(left, 1)
    borders.left = left

    local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture(TEX)
    right:SetVertexColor(r, g, b, 1)
    PU.SetPoint(right, "TOPRIGHT", frame, "TOPRIGHT", 1, 1)
    PU.SetPoint(right, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    PU.SetWidth(right, 1)
    borders.right = right

    frame._borders = borders
end

function NS.CreateBarBackground(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX)
    bg:SetVertexColor(0, 0, 0, 1)
    bg:SetAllPoints(frame)
    frame._bg = bg
end

-- ============================================================================
-- HELPER: Icon bounds pour centrage viewer
-- ============================================================================

function NS.GetViewerIconBounds(viewer)
    if not viewer then return nil end
    local db = BravLib.API.GetModule("cooldown")
    local maxCols = (db and db.cdm and db.cdm.maxColumns) or 5

    local items = {}
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child.layoutIndex and child:IsShown() then
            items[#items + 1] = child
        end
    end
    if #items == 0 then return nil end

    table.sort(items, function(a, b) return a.layoutIndex < b.layoutIndex end)

    local first = items[1]
    local lastInRow = items[math.min(maxCols, #items)]
    local lastItem = items[#items]

    if not first or not lastInRow or not lastItem then return nil end

    local leftX = first:GetLeft()
    local rightX = lastInRow:GetRight()
    if not leftX or not rightX then return nil end

    local centerX = (leftX + rightX) / 2
    local topY = first:GetTop()
    local bottomY = lastItem:GetBottom()

    return centerX, topY, bottomY
end

-- ============================================================================
-- DB ACCESS
-- ============================================================================

function NS.GetDB()
    return BravLib.API.GetModule("cooldown") or {}
end

function NS.GetSpecLayout()
    return NS.GetDB()
end

-- ============================================================================
-- KEYBIND LOOKUP: spellID → shortest keybind
-- ============================================================================

local SLOT_TO_BINDING = {}
do
    for i = 1, 12 do SLOT_TO_BINDING[i] = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[60 + i] = "MULTIACTIONBAR1BUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[48 + i] = "MULTIACTIONBAR2BUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[24 + i] = "MULTIACTIONBAR3BUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[36 + i] = "MULTIACTIONBAR4BUTTON" .. i end
    for bar = 5, 8 do
        for i = 1, 12 do
            SLOT_TO_BINDING[132 + (bar - 5) * 12 + i] = "MULTIACTIONBAR" .. bar .. "BUTTON" .. i
        end
    end
    for i = 1, 12 do SLOT_TO_BINDING[12 + i]  = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[72 + i]  = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[84 + i]  = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[96 + i]  = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[108 + i] = "ACTIONBUTTON" .. i end
    for i = 1, 12 do SLOT_TO_BINDING[120 + i] = "ACTIONBUTTON" .. i end
end

local function ShortenKey(key)
    if not key or key == "" then return nil end
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("META%-", "M")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("BUTTON", "M")
    return key
end

local function FindKeybindForSlots(slots)
    if not slots then return nil end
    local shortest = nil
    for _, slot in ipairs(slots) do
        local cmd = SLOT_TO_BINDING[slot]
        if cmd then
            local key1 = GetBindingKey(cmd)
            if key1 then
                local short = ShortenKey(key1)
                if short and (not shortest or #short < #shortest) then
                    shortest = short
                end
            end
        end
    end
    return shortest
end

function NS.GetSpellKeybind(spellID)
    if not spellID then return nil end

    local ok, result = pcall(function()
        local slots = C_ActionBar.FindSpellActionButtons(spellID)
        local key = FindKeybindForSlots(slots)
        if key then return key end

        local baseID = C_Spell.GetBaseSpellID and C_Spell.GetBaseSpellID(spellID)
        if baseID and baseID ~= spellID then
            slots = C_ActionBar.FindSpellActionButtons(baseID)
            key = FindKeybindForSlots(slots)
            if key then return key end
        end

        local overID = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
        if overID and overID ~= spellID then
            slots = C_ActionBar.FindSpellActionButtons(overID)
            key = FindKeybindForSlots(slots)
            if key then return key end
        end

        return nil
    end)

    return ok and result or nil
end

-- ============================================================================
-- PUBLIC API (live apply)
-- ============================================================================

function NS.RefreshSkin()
    if NS._cdmOff then return end
    local Skin = NS.Skin
    if not Skin then return end

    local viewers = {
        { name = "EssentialCooldownViewer", type = "icon" },
        { name = "UtilityCooldownViewer",   type = "icon" },
        { name = "BuffIconCooldownViewer",  type = "icon" },
        { name = "BuffBarCooldownViewer",   type = "bar" },
    }

    local db = NS.GetDB()
    for _, v in ipairs(viewers) do
        local viewer = _G[v.name]
        if viewer then
            Skin:SkinViewer(viewer, v.type, db)
        end
    end
end

function NS.ApplySpecLayout()
    local layout = NS.GetSpecLayout()

    if NS.ApplyCastBarLayout then
        pcall(NS.ApplyCastBarLayout, layout.castbar)
    end

    if NS.ApplyResourceBarLayout then
        pcall(NS.ApplyResourceBarLayout, layout.primary)
    end

    if NS.ApplyClassPowerLayout then
        pcall(NS.ApplyClassPowerLayout, layout.secondary)
    end
end

function NS.RefreshAll()
    if NS._cdmOff then return end
    NS.RefreshSkin()
    NS.ApplySpecLayout()
end

-- ============================================================================
-- BOOTSTRAP (PLAYER_LOGIN)
-- ============================================================================

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local db = NS.GetDB()
    if db.enabled == false then return end

    local function TrySkin()
        if NS._cdmOff then return end
        local Skin = NS.Skin
        if not Skin then return end

        local viewers = {
            { name = "EssentialCooldownViewer", type = "icon" },
            { name = "UtilityCooldownViewer",   type = "icon" },
            { name = "BuffIconCooldownViewer",  type = "icon" },
            { name = "BuffBarCooldownViewer",   type = "bar" },
        }

        local found = false
        for _, v in ipairs(viewers) do
            local viewer = _G[v.name]
            if viewer and viewer:IsShown() then
                found = true
                Skin:SkinViewer(viewer, v.type, db)
            end
        end

        if not found then return end

        if not NS._hooked then
            NS._hooked = true

            for _, v in ipairs(viewers) do
                local viewer = _G[v.name]
                if viewer and viewer.Layout then
                    hooksecurefunc(viewer, "Layout", function()
                        local freshDB = NS.GetDB()
                        if freshDB.enabled == false then return end
                        Skin:SkinViewer(viewer, v.type, freshDB)
                    end)
                end
            end

            if CooldownViewerMixin and CooldownViewerMixin.RefreshLayout then
                hooksecurefunc(CooldownViewerMixin, "RefreshLayout", function(viewer)
                    local freshDB = NS.GetDB()
                    if freshDB.enabled == false then return end
                    local viewerType = "icon"
                    if viewer == _G["BuffBarCooldownViewer"] then
                        viewerType = "bar"
                    end
                    C_Timer.After(0, function()
                        Skin:SkinViewer(viewer, viewerType, freshDB)
                    end)
                end)
            end
        end
    end

    local function IsViewerActive(name)
        local f = _G[name]
        return f and f.IsShown and f:IsShown()
    end

    local function CheckCDMAndInit()
        local anyActive = IsViewerActive("EssentialCooldownViewer")
            or IsViewerActive("UtilityCooldownViewer")
            or IsViewerActive("BuffIconCooldownViewer")
            or IsViewerActive("BuffBarCooldownViewer")

        if not anyActive then
            NS._cdmOff = true
            C_Timer.After(3, function()
                local DURATION = 15
                local cr, cg, cb = U.GetClassColor("player")
                local FONT = U.GetFont()

                local pop = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
                pop:SetSize(360, 120)
                pop:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
                pop:SetFrameStrata("DIALOG")
                pop:SetFrameLevel(500)
                if pop.SetBackdrop then
                    pop:SetBackdrop({ bgFile = TEX, edgeFile = TEX, edgeSize = 1 })
                    pop:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
                    pop:SetBackdropBorderColor(cr, cg, cb, 1)
                end

                local title = pop:CreateFontString(nil, "OVERLAY")
                title:SetPoint("TOP", pop, "TOP", 0, -10)
                pcall(function() title:SetFont(FONT, 13, "OUTLINE") end)
                title:SetTextColor(cr, cg, cb)
                title:SetText("BravUI — Cooldown")

                local body = pop:CreateFontString(nil, "OVERLAY")
                body:SetPoint("TOP", title, "BOTTOM", 0, -8)
                body:SetPoint("LEFT", pop, "LEFT", 14, 0)
                body:SetPoint("RIGHT", pop, "RIGHT", -14, 0)
                body:SetJustifyH("CENTER")
                pcall(function() body:SetFont(FONT, 10, "") end)
                body:SetTextColor(0.85, 0.85, 0.85)
                body:SetText("Le module Cooldown sera disponible une fois le\n|cffffffffGestionnaire de temps de recharge|r active.\n|cffffa500Mode Edition|r (Echap > Mode Edition) — Niveau 10+")

                local timerBar = CreateFrame("StatusBar", nil, pop)
                timerBar:SetPoint("BOTTOMLEFT", pop, "BOTTOMLEFT", 1, 1)
                timerBar:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -1, 1)
                timerBar:SetHeight(3)
                timerBar:SetStatusBarTexture(TEX)
                timerBar:SetStatusBarColor(cr, cg, cb, 0.8)
                timerBar:SetMinMaxValues(0, DURATION)
                timerBar:SetValue(DURATION)

                pop:EnableMouse(true)
                pop:SetScript("OnMouseDown", function() pop:Hide() end)

                local elapsed = 0
                pop:SetScript("OnUpdate", function(_, dt)
                    elapsed = elapsed + dt
                    local remain = DURATION - elapsed
                    if remain <= 0 then
                        pop:Hide()
                        return
                    end
                    timerBar:SetValue(remain)
                end)
            end)
            return
        end

        TrySkin()
        NS.ApplySpecLayout()
    end

    C_Timer.After(0.5, TrySkin)
    C_Timer.After(2, CheckCDMAndInit)

    -- Keybind refresh events
    local kbFrame = CreateFrame("Frame")
    kbFrame:RegisterEvent("UPDATE_BINDINGS")
    kbFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    kbFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    kbFrame:RegisterEvent("SPELLS_CHANGED")

    local kbPending = false
    kbFrame:SetScript("OnEvent", function(_, evt)
        if kbPending then return end
        kbPending = true
        C_Timer.After(0.3, function()
            kbPending = false
            if NS.Skin and NS.Skin.UpdateKeybinds then
                NS.Skin:UpdateKeybinds()
            end
            if evt == "PLAYER_SPECIALIZATION_CHANGED" then
                NS.ApplySpecLayout()
                if NS.Skin and NS.Skin.UpdateBorderColors then
                    NS.Skin:UpdateBorderColors()
                end
            end
        end)
    end)
end)

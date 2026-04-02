-- BravUI/Modules/Cooldown/Skin.lua
-- Couche visuelle pour les frames Blizzard Cooldown Viewer
-- Portage v2 depuis BravUI_Cooldown standalone

local NS = BravUI.Cooldown
local U  = BravUI.Utils
NS.Skin = NS.Skin or {}

local Skin = NS.Skin
local TEX = NS.TEX or "Interface/Buttons/WHITE8x8"

local ICON_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local ALL_VIEWERS  = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

-- ============================================================================
-- HELPERS
-- ============================================================================

local function CreateBravUIFrame(parent)
    local r, g, b = NS.GetBorderColor()
    local PU = PixelUtil
    local result = {}

    local bg = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX)
    bg:SetVertexColor(0, 0, 0, 1)
    bg:SetAllPoints(parent)
    result.bg = bg

    local top = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture(TEX)
    top:SetVertexColor(r, g, b, 1)
    PU.SetPoint(top, "TOPLEFT", parent, "TOPLEFT", -1, 1)
    PU.SetPoint(top, "TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    PU.SetHeight(top, 1)
    result.top = top

    local bot = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    bot:SetTexture(TEX)
    bot:SetVertexColor(r, g, b, 1)
    PU.SetPoint(bot, "BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    PU.SetPoint(bot, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    PU.SetHeight(bot, 1)
    result.bottom = bot

    local left = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture(TEX)
    left:SetVertexColor(r, g, b, 1)
    PU.SetPoint(left, "TOPLEFT", parent, "TOPLEFT", -1, 1)
    PU.SetPoint(left, "BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    PU.SetWidth(left, 1)
    result.left = left

    local right = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture(TEX)
    right:SetVertexColor(r, g, b, 1)
    PU.SetPoint(right, "TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    PU.SetPoint(right, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    PU.SetWidth(right, 1)
    result.right = right

    return result
end

local function SetBorderColor(frame, r, g, b)
    if not frame then return end
    for k, tex in pairs(frame) do
        if k ~= "bg" then
            tex:SetVertexColor(r, g, b, 1)
        end
    end
end

-- ============================================================================
-- SKIN: Icon items
-- ============================================================================

function Skin:SkinIconItem(item, db)
    if not item or item._BravUI_Skinned then return end
    item._BravUI_Skinned = true

    local font = U.GetFont()

    if item.Icon then
        pcall(function()
            local masks = { item.Icon:GetMaskTextures() }
            for _, mask in ipairs(masks) do
                item.Icon:RemoveMaskTexture(mask)
            end
        end)
        item.Icon:SetTexCoord(0, 1, 0, 1)
    end

    if not item._BravUI_Frame then
        item._BravUI_Frame = CreateBravUIFrame(item)
    end

    for _, region in ipairs({ item:GetRegions() }) do
        local ok, isTarget = pcall(function()
            return region:IsObjectType("Texture")
                and region:GetDrawLayer() == "OVERLAY"
                and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay"
        end)
        if ok and isTarget then
            region:SetAlpha(0)
            break
        end
    end

    if item.Cooldown then
        item.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
    end

    if item.ChargeCount and item.ChargeCount.Current then
        item.ChargeCount.Current:SetFont(font, 14, "OUTLINE")
    end

    if item.Applications and item.Applications.Applications then
        item.Applications.Applications:SetFont(font, 14, "OUTLINE")
    end

    if not item._BravUI_Hotkey then
        local hk = item:CreateFontString(nil, "OVERLAY", nil)
        hk:SetFont(font, 10, "OUTLINE")
        hk:SetPoint("TOPRIGHT", item, "TOPRIGHT", -1, -1)
        hk:SetJustifyH("RIGHT")
        hk:SetTextColor(0.9, 0.9, 0.9, 1)
        hk:SetShadowOffset(1, -1)
        hk:SetShadowColor(0, 0, 0, 1)
        item._BravUI_Hotkey = hk
    end
end

-- ============================================================================
-- SKIN: Bar items
-- ============================================================================

function Skin:SkinBarItem(item, db)
    if not item or item._BravUI_Skinned then return end
    item._BravUI_Skinned = true

    local font = U.GetFont()

    local iconFrame = item.Icon
    if iconFrame then
        local iconTex = iconFrame.Icon
        if iconTex then
            pcall(function()
                local masks = { iconTex:GetMaskTextures() }
                for _, mask in ipairs(masks) do
                    iconTex:RemoveMaskTexture(mask)
                end
            end)
            iconTex:SetTexCoord(0, 1, 0, 1)
        end

        if not item._BravUI_IconFrame then
            item._BravUI_IconFrame = CreateBravUIFrame(iconFrame)
        end
    end

    if item.Bar then
        if item.Bar.Name then
            item.Bar.Name:SetFont(font, 12, "OUTLINE")
        end
        if item.Bar.Duration then
            item.Bar.Duration:SetFont(font, 12, "OUTLINE")
        end
    end

    if iconFrame and iconFrame.Applications then
        iconFrame.Applications:SetFont(font, 10, "OUTLINE")
    end
end

-- ============================================================================
-- LAYOUT: Reposition icons in grid (Essential only)
-- ============================================================================

function Skin:ApplyLayout(viewer, viewerType, db)
    if not viewer or viewerType == "bar" then return end
    if viewer ~= _G["EssentialCooldownViewer"] then return end

    local cdmDB = db and db.cdm
    local maxCols = cdmDB and cdmDB.maxColumns or 5
    local spacing = cdmDB and cdmDB.iconSpacing or 2

    local items = {}
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child.layoutIndex and child:IsShown() then
            table.insert(items, child)
        end
    end

    table.sort(items, function(a, b) return a.layoutIndex < b.layoutIndex end)
    if #items == 0 then return end

    local iconW = items[1]:GetWidth()
    local iconH = items[1]:GetHeight()
    if iconW == 0 then iconW = 50 end
    if iconH == 0 then iconH = 50 end

    for i, item in ipairs(items) do
        local col = (i - 1) % maxCols
        local row = math.floor((i - 1) / maxCols)

        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", viewer, "TOPLEFT",
            col * (iconW + spacing),
            -(row * (iconH + spacing))
        )
    end
end

-- ============================================================================
-- KEYBIND
-- ============================================================================

local function UpdateItemKeybind(item)
    if not item or not item._BravUI_Hotkey then return end

    local spellID
    if item.GetSpellID then
        local ok, val = pcall(item.GetSpellID, item)
        if ok then spellID = val end
    end

    local key = NS.GetSpellKeybind(spellID)
    item._BravUI_Hotkey:SetText(key or "")
end

-- ============================================================================
-- SKIN: Apply to all active items of a viewer
-- ============================================================================

function Skin:SkinViewer(viewer, viewerType, db)
    if not viewer then return end

    local isBar = (viewerType == "bar")

    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child.Icon then
            if isBar then
                self:SkinBarItem(child, db)
            else
                self:SkinIconItem(child, db)
                UpdateItemKeybind(child)
            end
        end
    end

    self:ApplyLayout(viewer, viewerType, db)
end

-- ============================================================================
-- UPDATE KEYBINDS
-- ============================================================================

function Skin:UpdateKeybinds()
    for _, vName in ipairs(ICON_VIEWERS) do
        local viewer = _G[vName]
        if viewer then
            for _, child in ipairs({ viewer:GetChildren() }) do
                if child and child._BravUI_Hotkey then
                    UpdateItemKeybind(child)
                end
            end
        end
    end
end

-- ============================================================================
-- UPDATE BORDER COLORS
-- ============================================================================

function Skin:UpdateBorderColors()
    local r, g, b = NS.GetBorderColor()

    for _, vName in ipairs(ALL_VIEWERS) do
        local viewer = _G[vName]
        if viewer then
            for _, child in ipairs({ viewer:GetChildren() }) do
                if child then
                    if child._BravUI_Frame then
                        SetBorderColor(child._BravUI_Frame, r, g, b)
                    end
                    if child._BravUI_IconFrame then
                        SetBorderColor(child._BravUI_IconFrame, r, g, b)
                    end
                end
            end
        end
    end
end

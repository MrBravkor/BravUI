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

-- Map viewer global name → DB key
local VIEWER_DB_KEY = {
    EssentialCooldownViewer  = "essential",
    UtilityCooldownViewer    = "utility",
    BuffIconCooldownViewer   = "buffIcon",
    BuffBarCooldownViewer    = "buffBar",
}

local function GetViewerDB(viewer, db)
    if not viewer or not db or not db.cdm then return nil end
    local name = viewer:GetName() or ""
    local key = VIEWER_DB_KEY[name]
    return key and db.cdm[key] or nil
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function CreateBlackBorder(frame)
    local borders = {}

    local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture(TEX)
    top:SetVertexColor(0, 0, 0, 0.7)
    top:SetHeight(3)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    borders.top = top

    local bot = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    bot:SetTexture(TEX)
    bot:SetVertexColor(0, 0, 0, 0.7)
    bot:SetHeight(3)
    bot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    borders.bottom = bot

    local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture(TEX)
    left:SetVertexColor(0, 0, 0, 0.7)
    left:SetWidth(3)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    borders.left = left

    local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture(TEX)
    right:SetVertexColor(0, 0, 0, 0.7)
    right:SetWidth(3)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    borders.right = right

    return borders
end

-- ============================================================================
-- SKIN: Icon items
-- ============================================================================

function Skin:SkinIconItem(item, db)
    if not item or item._BravUI_Skinned then return end
    item._BravUI_Skinned = true

    -- Remove masks, square icon, fill frame
    if item.Icon then
        pcall(function()
            local masks = { item.Icon:GetMaskTextures() }
            for _, mask in ipairs(masks) do
                item.Icon:RemoveMaskTexture(mask)
            end
        end)
        item.Icon:SetTexCoord(0, 1, 0, 1)
        item.Icon:ClearAllPoints()
        item.Icon:SetAllPoints(item)
    end

    -- Black border on the item frame
    if not item._BravUI_Border then
        item._BravUI_Border = CreateBlackBorder(item)
    end

    -- Hide Blizzard overlay
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

    -- Keybind overlay
    if not item._BravUI_Hotkey then
        local font = U.GetFont()
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

        -- Black border on icon frame
        if not item._BravUI_IconBorder then
            item._BravUI_IconBorder = CreateBlackBorder(iconFrame)
        end
    end
end

-- ============================================================================
-- LAYOUT: Reposition icons in grid (all icon viewers)
-- ============================================================================

function Skin:ApplyLayout(viewer, viewerType, db)
    if not viewer or viewerType == "bar" then return end

    local vdb = GetViewerDB(viewer, db)
    local maxCols     = vdb and vdb.maxColumns   or 5
    local spacing     = vdb and vdb.iconSpacing  or 6
    local iconSize    = vdb and vdb.iconSize     or 36
    local orientation = vdb and vdb.orientation   or "HORIZONTAL"
    local direction   = vdb and vdb.iconDirection or "RIGHT"

    local items = {}
    local children = { viewer:GetChildren() }
    for idx, child in ipairs(children) do
        if child and child:IsShown() and child.Icon then
            child._bravSortIdx = child.layoutIndex or idx
            items[#items + 1] = child
        end
    end

    table.sort(items, function(a, b) return a._bravSortIdx < b._bravSortIdx end)
    if direction == "LEFT" then
        local reversed = {}
        for i = #items, 1, -1 do reversed[#reversed + 1] = items[i] end
        items = reversed
    end
    if #items == 0 then return end

    -- Resize icons + force Icon texture to fill frame
    for _, item in ipairs(items) do
        item:SetSize(iconSize, iconSize)
        if item.Icon then
            item.Icon:ClearAllPoints()
            item.Icon:SetAllPoints(item)
        end
    end

    local isVertical = (orientation == "VERTICAL")

    -- Compensate frame padding so spacing=0 means icons touch visually
    local FRAME_PAD = 4
    local step = iconSize + spacing - FRAME_PAD

    local gridW, gridH

    if isVertical then
        -- Vertical: columns become rows
        local maxRows = maxCols
        local totalCols = math.ceil(#items / maxRows)

        for i, item in ipairs(items) do
            local row = (i - 1) % maxRows
            local col = math.floor((i - 1) / maxRows)

            local rowsInCol = (col < totalCols - 1) and maxRows or (#items - col * maxRows)
            local colHeight = rowsInCol * iconSize + (rowsInCol - 1) * (step - iconSize + iconSize)
            local fullHeight = maxRows * iconSize + (maxRows - 1) * (step - iconSize + iconSize)
            local offsetY = (fullHeight - colHeight) / 2

            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", viewer, "TOPLEFT",
                col * step,
                -(offsetY + row * step)
            )
        end

        gridW = totalCols * iconSize + math.max(totalCols - 1, 0) * (step - iconSize)
        gridH = maxRows   * iconSize + math.max(maxRows - 1, 0)   * (step - iconSize)
    else
        -- Horizontal
        local totalRows = math.ceil(#items / maxCols)

        for i, item in ipairs(items) do
            local row = math.floor((i - 1) / maxCols)
            local col = (i - 1) % maxCols

            local colsInRow = (row < totalRows - 1) and maxCols or (#items - row * maxCols)
            local rowWidth = colsInRow * step - (step - iconSize)
            local fullWidth = maxCols * step - (step - iconSize)
            local offsetX = (fullWidth - rowWidth) / 2

            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", viewer, "TOPLEFT",
                offsetX + col * step,
                -(row * step)
            )
        end

        gridW = maxCols * step - (step - iconSize)
        gridH = totalRows * step - (step - iconSize)
    end

    -- Resize viewer to match the grid
    if gridW > 0 and gridH > 0 then
        viewer:SetSize(gridW, gridH)
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
    local vdb = GetViewerDB(viewer, db)
    local showTimer    = not vdb or vdb.showTimer ~= false
    local showTooltips = not vdb or vdb.showTooltips ~= false

    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child.Icon then
            if isBar then
                self:SkinBarItem(child, db)
            else
                self:SkinIconItem(child, db)
                UpdateItemKeybind(child)
            end

            -- Chronomètre (cooldown text)
            if child.Cooldown then
                child.Cooldown:SetHideCountdownNumbers(not showTimer)
            end

            -- Tooltips
            if not child._BravUI_TooltipHooked then
                child._BravUI_TooltipHooked = true
                child:HookScript("OnEnter", function(self)
                    if self._BravUI_NoTooltip then
                        GameTooltip:Hide()
                    end
                end)
            end
            child._BravUI_NoTooltip = not showTooltips
        end
    end

    self:ApplyLayout(viewer, viewerType, db)

    -- Per-viewer opacity
    if vdb then
        viewer:SetAlpha(vdb.opacity or 1)
    end
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
    -- Borders are now always black, nothing to update
end

-- ============================================================================
-- VISIBILITY: combat-based show/hide per viewer
-- ============================================================================

do
    local visFrame = CreateFrame("Frame")
    visFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    visFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local function ApplyVisibility(inCombat)
        local db = NS.GetDB()
        if not db or not db.cdm then return end

        for _, vName in ipairs(ALL_VIEWERS) do
            local viewer = _G[vName]
            if viewer then
                local key = VIEWER_DB_KEY[vName]
                local vdb = key and db.cdm[key]
                local vis = vdb and vdb.visibility or "ALWAYS"

                if vis == "ALWAYS" then
                    viewer:SetShown(true)
                elseif vis == "COMBAT" then
                    viewer:SetShown(inCombat)
                elseif vis == "OUTOFCOMBAT" then
                    viewer:SetShown(not inCombat)
                end
            end
        end
    end

    visFrame:SetScript("OnEvent", function(_, event)
        ApplyVisibility(event == "PLAYER_REGEN_DISABLED")
    end)

    -- Expose pour refresh depuis le menu
    function Skin:ApplyVisibility()
        ApplyVisibility(InCombatLockdown())
    end
end

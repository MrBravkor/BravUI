local BravUI = BravUI

BravUI.Move = {}

local movers = {}
local unlocked = false

function BravUI.Move.Enable(frame, name)
    if movers[name] then return end

    local mover = CreateFrame("Frame", "BravUIMover_" .. name, UIParent)
    mover:SetAllPoints(frame)
    mover:SetFrameStrata("DIALOG")
    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.label:SetPoint("CENTER")
    mover.label:SetText(name)

    mover.bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.bg:SetAllPoints()
    mover.bg:SetColorTexture(0, 0.8, 1, 0.3)

    mover:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        BravLib.API.Set("positions", name, {point, relPoint, x, y})
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end)

    mover.frame = frame
    movers[name] = mover

    -- Restore saved position
    local pos = BravLib.API.Get("positions", name)
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end

function BravUI.Move.Unlock()
    unlocked = true
    for _, mover in pairs(movers) do
        mover:Show()
    end
    BravLib.Print("Movers unlocked. Drag to reposition.")
end

function BravUI.Move.Lock()
    unlocked = false
    for _, mover in pairs(movers) do
        mover:Hide()
    end
    BravLib.Print("Movers locked.")
end

function BravUI.Move.Toggle()
    if unlocked then
        BravUI.Move.Lock()
    else
        BravUI.Move.Unlock()
    end
end

function BravUI.Move.IsUnlocked()
    return unlocked
end

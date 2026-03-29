-- BravUI_Menu/Pages/Profils.lua
-- Profile management (custom buildFn page)
-- Create, delete, copy, share, import/export profiles + per-spec routing

local M = BravUI.Menu
local L = M.L
local T = M.Theme
local GAP = 8

local Storage = BravLib.Storage

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetAllProfiles()
    return Storage.GetProfileList()
end

local function GetAllPlayerSpecs()
    local specs = {}
    if not GetNumSpecializations then return specs end
    for i = 1, GetNumSpecializations() do
        local id, name = GetSpecializationInfo(i)
        if id then
            specs[#specs + 1] = { index = i, specID = id, name = name }
        end
    end
    return specs
end

-- ============================================================================
-- WIDGET BUILDERS (same visual style as v1 page)
-- ============================================================================

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

local function AddSep(host, y)
    local cr, cg, cb = M:GetClassColor()
    local line = host:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(y + 6))
    line:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    line:SetColorTexture(cr, cg, cb, 0.12)
    return y + 16
end

local function AddToggle(host, y, label, getFn, setFn, refreshPage)
    local cr, cg, cb = M:GetClassColor()

    local btn = CreateFrame("Button", nil, host)
    btn:SetHeight(28)
    btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    btn:SetPoint("RIGHT", host, "RIGHT", 0, 0)

    local box = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetSize(18, 18)
    box:SetPoint("LEFT", btn, "LEFT", 0, 0)
    box:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    box:SetBackdropColor(0.04, 0.04, 0.06, 1)
    box:SetBackdropBorderColor(unpack(T.BORDER))

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetSize(10, 10)
    fill:SetPoint("CENTER", box, "CENTER", 0, 0)
    fill:SetColorTexture(cr, cg, cb, 0.90)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 11, "OUTLINE")
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetText(label)
    lbl:SetTextColor(unpack(T.TEXT))

    local function UpdateVisual()
        if getFn() then
            fill:Show()
            box:SetBackdropBorderColor(cr, cg, cb, 0.60)
        else
            fill:Hide()
            box:SetBackdropBorderColor(unpack(T.BORDER))
        end
    end

    btn:SetScript("OnClick", function()
        setFn(not getFn())
        UpdateVisual()
        if refreshPage then refreshPage() end
    end)
    btn:SetScript("OnEnter", function()
        if not getFn() then box:SetBackdropBorderColor(0.35, 0.35, 0.40, 1) end
    end)
    btn:SetScript("OnLeave", function() UpdateVisual() end)
    UpdateVisual()

    return y + 28 + GAP, { frame = btn, refresh = UpdateVisual }
end

local function AddDropdown(host, y, label, getItemsFn, getFn, setFn, refreshPage)
    local cr, cg, cb = M:GetClassColor()
    local f = CreateFrame("Frame", nil, host)
    f:SetHeight(48)
    f:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    f:SetPoint("RIGHT", host, "RIGHT", 0, 0)

    local lbl = f:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 11, "OUTLINE")
    lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    lbl:SetText(label)
    lbl:SetTextColor(unpack(T.TEXT))

    local dd = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dd:SetHeight(26)
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
    dd:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    dd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    dd:SetBackdropColor(unpack(T.BTN))
    dd:SetBackdropBorderColor(unpack(T.BORDER))

    local ddText = dd:CreateFontString(nil, "OVERLAY")
    M:SafeFont(ddText, 11, "OUTLINE")
    ddText:SetPoint("LEFT", 10, 0)
    ddText:SetTextColor(unpack(T.TEXT))

    M:CreateDropdownArrow(dd)

    local function GetDisplayText(val)
        local items = getItemsFn()
        for _, v in ipairs(items) do
            if v.value == val then return v.text end
        end
        return tostring(val or "")
    end

    local function UpdateVisual()
        ddText:SetText(GetDisplayText(getFn()))
    end

    dd:SetScript("OnClick", function(self)
        local items = getItemsFn()
        local curVal = getFn()
        M:ShowFlyout(self, items, curVal, function(val)
            setFn(val)
            UpdateVisual()
            if refreshPage then refreshPage() end
        end)
    end)

    dd:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
    dd:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)
    UpdateVisual()

    return y + 48 + GAP, { frame = f, refresh = UpdateVisual, dd = dd }
end

local function AddButton(host, y, label, onClick, width)
    local cr, cg, cb = M:GetClassColor()
    local btn = CreateFrame("Button", nil, host, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(width or 140, 26)
    btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    btn:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    btn:SetBackdropColor(unpack(T.BTN))
    btn:SetBackdropBorderColor(cr, cg, cb, 0.50)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(lbl, 11, "OUTLINE")
    lbl:SetPoint("CENTER", 0, 0)
    lbl:SetText(label)
    lbl:SetTextColor(unpack(T.TEXT))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(cr * 0.12, cg * 0.12, cb * 0.12, 1)
        self:SetBackdropBorderColor(cr, cg, cb, 1)
        lbl:SetTextColor(cr, cg, cb, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(T.BTN))
        self:SetBackdropBorderColor(cr, cg, cb, 0.50)
        lbl:SetTextColor(unpack(T.TEXT))
    end)
    btn:SetScript("OnClick", onClick)

    return btn
end

local function AddButtonRow(host, y, buttons, gap)
    gap = gap or 8
    local x = 0
    for _, b in ipairs(buttons) do
        local btn = AddButton(host, y, b.label, b.onClick, b.width)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", x, -y)
        x = x + (b.width or 140) + gap
    end
    return y + 26 + GAP
end

-- Scrollable multiline EditBox (for import/export popups)
local function MakeScrollEditBox(parent, height)
    local container = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    container:SetHeight(height)
    container:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    container:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
    container:SetBackdropBorderColor(unpack(T.BORDER))

    local scroll = CreateFrame("ScrollFrame", nil, container)
    scroll:SetPoint("TOPLEFT", 6, -4)
    scroll:SetPoint("BOTTOMRIGHT", -6, 4)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(99999)
    M:SafeFont(eb, 9, "OUTLINE")
    eb:SetTextColor(unpack(T.TEXT))
    eb:SetWidth(1)
    scroll:SetScrollChild(eb)

    local function UpdateHeight()
        local text = eb:GetText()
        local sh = scroll:GetHeight()
        if not text or text == "" then eb:SetHeight(sh); return end
        local w = math.max(1, eb:GetWidth())
        local _, fh = eb:GetFont()
        fh = fh or 10
        local cpl = math.max(1, math.floor(w / (fh * 0.52)))
        local lines = 0
        for seg in (text .. "\n"):gmatch("([^\n]*)\n") do
            lines = lines + math.max(1, math.ceil(math.max(1, #seg) / cpl))
        end
        eb:SetHeight(math.max(sh, lines * (fh + 2) + 8))
    end

    scroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then eb:SetWidth(w); UpdateHeight() end
    end)
    eb:SetScript("OnTextChanged", function() UpdateHeight() end)

    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(_, delta)
        local max = scroll:GetVerticalScrollRange()
        if max <= 0 then return end
        local cur = scroll:GetVerticalScroll()
        scroll:SetVerticalScroll(math.max(0, math.min(cur - delta * 20, max)))
    end)

    eb:SetScript("OnCursorChanged", function(_, x, curY, w, h)
        curY = -curY
        local vs = scroll:GetVerticalScroll()
        local sh = scroll:GetHeight()
        if curY < vs then
            scroll:SetVerticalScroll(curY)
        elseif curY + h > vs + sh then
            scroll:SetVerticalScroll(curY + h - sh)
        end
    end)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    container:SetScript("OnShow", function()
        local w = scroll:GetWidth()
        if w and w > 0 then eb:SetWidth(w) end
        UpdateHeight()
    end)

    container._editBox = eb
    container._scroll = scroll
    container.UpdateHeight = UpdateHeight
    return container
end

-- ============================================================================
-- POPUP SYSTEM
-- ============================================================================

local _popups = {}
local _activePopup = nil

local function MakePopup(key, title, w, h)
    if _popups[key] then return _popups[key] end

    local cr, cg, cb = M:GetClassColor()

    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetFrameLevel(970)
    blocker:Hide()
    blocker:EnableMouse(true)

    local blockerBg = blocker:CreateTexture(nil, "BACKGROUND")
    blockerBg:SetAllPoints()
    blockerBg:SetColorTexture(0, 0, 0, 0.50)

    local f = CreateFrame("Frame", nil, blocker, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, h)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(975)
    f:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    f:SetBackdropBorderColor(cr, cg, cb, 0.40)
    f:EnableMouse(true)

    local titleFs = f:CreateFontString(nil, "OVERLAY")
    M:SafeFont(titleFs, 13, "OUTLINE")
    titleFs:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    titleFs:SetText(title)
    titleFs:SetTextColor(cr, cg, cb, 1)

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(closeX, 12, "OUTLINE")
    closeX:SetPoint("CENTER", 0, 0)
    closeX:SetText("X")
    closeX:SetTextColor(unpack(T.MUTED))
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(unpack(T.MUTED)) end)

    local status = f:CreateFontString(nil, "OVERLAY")
    M:SafeFont(status, 10, "OUTLINE")
    status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    status:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    status:SetTextColor(unpack(T.MUTED))
    status:SetText("")
    f._status = status

    function f:SetStatus(text, r, g, b)
        self._status:SetText(text)
        self._status:SetTextColor(r or 0.5, g or 0.5, b or 0.5, 1)
    end

    function f:ShowPopup()
        if _activePopup and _activePopup ~= blocker then _activePopup:Hide() end
        _activePopup = blocker
        self:SetStatus("")
        blocker:Show()
    end

    function f:HidePopup()
        blocker:Hide()
        _activePopup = nil
    end

    closeBtn:SetScript("OnClick", function() f:HidePopup() end)
    blocker:SetScript("OnClick", function() f:HidePopup() end)

    f._content = CreateFrame("Frame", nil, f)
    f._content:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    f._content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 32)

    _popups[key] = f
    return f
end

-- ============================================================================
-- POPUP: CREATE PROFILE
-- ============================================================================

local function BuildCreatePopup(refreshPage)
    local popup = MakePopup("create", L["prof_popup_create"], 420, 140)
    if popup._built then return popup end

    local c = popup._content

    local nameLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(nameLabel, 11, "OUTLINE")
    nameLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    nameLabel:SetText(L["prof_profile_name"])
    nameLabel:SetTextColor(unpack(T.TEXT))

    local nameBox = CreateFrame("EditBox", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    nameBox:SetHeight(26)
    nameBox:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -18)
    nameBox:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    nameBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    nameBox:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
    nameBox:SetBackdropBorderColor(unpack(T.BORDER))
    nameBox:SetAutoFocus(false)
    nameBox:SetTextInsets(8, 8, 0, 0)
    M:SafeFont(nameBox, 11, "OUTLINE")
    nameBox:SetTextColor(unpack(T.TEXT))
    nameBox:SetText(L["prof_default_name"])

    local createBtn = AddButton(c, 56, L["prof_btn_create"], function()
        local name = nameBox:GetText()
        if not name or name:trim() == "" then
            popup:SetStatus(L["prof_msg_invalid_name"], 0.9, 0.3, 0.3)
            return
        end
        name = name:trim()
        local ok = Storage.CreateProfile(name)
        if ok then
            Storage.SetActiveProfile(name)
            popup:HidePopup()
            if refreshPage then refreshPage() end
            return
        else
            popup:SetStatus((L["prof_msg_error"] or "Error: ") .. (L["prof_msg_invalid_name"] or "Name already exists"), 0.9, 0.3, 0.3)
        end
    end)
    createBtn:ClearAllPoints()
    createBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)

    popup._built = true
    return popup
end

-- ============================================================================
-- POPUP: DELETE PROFILE
-- ============================================================================

local function BuildDeletePopup(refreshPage)
    local popup = MakePopup("delete", L["prof_popup_delete"], 420, 140)
    if popup._built then return popup end

    local cr, cg, cb = M:GetClassColor()
    local c = popup._content

    local targetLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(targetLabel, 11, "OUTLINE")
    targetLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    targetLabel:SetText(L["prof_target_profile"])
    targetLabel:SetTextColor(unpack(T.TEXT))

    local targetDD = CreateFrame("Button", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    targetDD:SetHeight(26)
    targetDD:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -18)
    targetDD:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    targetDD:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    targetDD:SetBackdropColor(unpack(T.BTN))
    targetDD:SetBackdropBorderColor(unpack(T.BORDER))

    local ddText = targetDD:CreateFontString(nil, "OVERLAY")
    M:SafeFont(ddText, 11, "OUTLINE")
    ddText:SetPoint("LEFT", 10, 0)
    ddText:SetTextColor(unpack(T.TEXT))
    M:CreateDropdownArrow(targetDD)

    popup._selectedTarget = nil

    targetDD:SetScript("OnClick", function(self)
        local profiles = GetAllProfiles()
        local items = {}
        for _, name in ipairs(profiles) do
            items[#items + 1] = { text = name, value = name }
        end
        if #items <= 1 then
            popup:SetStatus(L["prof_msg_no_other"], 0.9, 0.6, 0.3)
            return
        end
        M:ShowFlyout(self, items, popup._selectedTarget, function(val)
            popup._selectedTarget = val
            ddText:SetText(val)
        end)
    end)
    targetDD:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
    targetDD:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)

    local deleteBtn = AddButton(c, 56, L["prof_btn_delete"], function()
        local target = popup._selectedTarget
        if not target or target == "" then
            popup:SetStatus(L["prof_msg_select"], 0.9, 0.6, 0.3)
            return
        end
        if target == Storage.GetActiveProfileName() then
            popup:SetStatus(L["prof_msg_cant_delete_active"], 0.9, 0.3, 0.3)
            return
        end
        local ok = Storage.DeleteProfile(target)
        if ok then
            popup._selectedTarget = nil
            popup:HidePopup()
            if refreshPage then refreshPage() end
            return
        else
            popup:SetStatus((L["prof_msg_error"] or "Error: ") .. "Cannot delete", 0.9, 0.3, 0.3)
        end
    end)
    deleteBtn:ClearAllPoints()
    deleteBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)

    popup._built = true
    return popup
end

-- ============================================================================
-- POPUP: EXPORT PROFILE
-- ============================================================================

local function BuildExportPopup()
    local popup = MakePopup("export", L["prof_popup_export"], 560, 300)
    if popup._built then return popup end

    local c = popup._content

    local codeContainer = MakeScrollEditBox(c, 180)
    codeContainer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    codeContainer:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    local codeBox = codeContainer._editBox

    local copyBtn = AddButton(c, 190, L["prof_btn_copy_code"], function()
        codeBox:SetFocus()
        codeBox:HighlightText()
        popup:SetStatus(L["prof_msg_ctrl_c"], 0.3, 0.9, 0.3)
    end, 100)
    copyBtn:ClearAllPoints()
    copyBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -190)

    popup._codeBox = codeBox
    local origShow = popup.ShowPopup
    function popup:ShowPopup()
        origShow(self)
        local code = Storage.ExportProfile()
        if code then
            codeBox:SetText(code)
            C_Timer.After(0, function() codeContainer.UpdateHeight() end)
        else
            codeBox:SetText("")
            self:SetStatus(L["prof_msg_export_error"] or "Export error", 0.9, 0.3, 0.3)
        end
    end

    popup._built = true
    return popup
end

-- ============================================================================
-- POPUP: IMPORT PROFILE
-- ============================================================================

local function BuildImportPopup(refreshPage)
    local popup = MakePopup("import", L["prof_popup_import"], 560, 380)
    if popup._built then return popup end

    local cr, cg, cb = M:GetClassColor()
    local c = popup._content

    local pasteLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(pasteLabel, 11, "OUTLINE")
    pasteLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    pasteLabel:SetText(L["prof_paste_here"])
    pasteLabel:SetTextColor(unpack(T.TEXT))

    local pasteContainer = MakeScrollEditBox(c, 140)
    pasteContainer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -18)
    pasteContainer:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    local pasteBox = pasteContainer._editBox

    local nameLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(nameLabel, 11, "OUTLINE")
    nameLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -170)
    nameLabel:SetText(L["prof_import_name"])
    nameLabel:SetTextColor(unpack(T.TEXT))

    local nameBox = CreateFrame("EditBox", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    nameBox:SetHeight(26)
    nameBox:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -188)
    nameBox:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    nameBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    nameBox:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
    nameBox:SetBackdropBorderColor(unpack(T.BORDER))
    nameBox:SetAutoFocus(false)
    nameBox:SetTextInsets(8, 8, 0, 0)
    M:SafeFont(nameBox, 11, "OUTLINE")
    nameBox:SetTextColor(unpack(T.TEXT))
    nameBox:SetText(L["prof_import_default"])

    -- Toggles: overwrite + activate
    local overwrite = true
    local activate = true
    local oy = 226

    local owBtn = CreateFrame("Button", nil, c)
    owBtn:SetHeight(22)
    owBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -oy)
    owBtn:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    local owBox = CreateFrame("Frame", nil, owBtn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    owBox:SetSize(14, 14)
    owBox:SetPoint("LEFT", owBtn, "LEFT", 0, 0)
    owBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    owBox:SetBackdropColor(0.04, 0.04, 0.06, 1)
    owBox:SetBackdropBorderColor(unpack(T.BORDER))
    local owFill = owBox:CreateTexture(nil, "ARTWORK")
    owFill:SetSize(8, 8)
    owFill:SetPoint("CENTER")
    owFill:SetColorTexture(cr, cg, cb, 0.90)
    local owLbl = owBtn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(owLbl, 10, "OUTLINE")
    owLbl:SetPoint("LEFT", owBox, "RIGHT", 6, 0)
    owLbl:SetText(L["prof_overwrite"])
    owLbl:SetTextColor(unpack(T.TEXT))
    owBtn:SetScript("OnClick", function()
        overwrite = not overwrite
        if overwrite then owFill:Show() else owFill:Hide() end
    end)

    local acBtn = CreateFrame("Button", nil, c)
    acBtn:SetHeight(22)
    acBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(oy + 24))
    acBtn:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    local acBox = CreateFrame("Frame", nil, acBtn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    acBox:SetSize(14, 14)
    acBox:SetPoint("LEFT", acBtn, "LEFT", 0, 0)
    acBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    acBox:SetBackdropColor(0.04, 0.04, 0.06, 1)
    acBox:SetBackdropBorderColor(unpack(T.BORDER))
    local acFill = acBox:CreateTexture(nil, "ARTWORK")
    acFill:SetSize(8, 8)
    acFill:SetPoint("CENTER")
    acFill:SetColorTexture(cr, cg, cb, 0.90)
    local acLbl = acBtn:CreateFontString(nil, "OVERLAY")
    M:SafeFont(acLbl, 10, "OUTLINE")
    acLbl:SetPoint("LEFT", acBox, "RIGHT", 6, 0)
    acLbl:SetText(L["prof_activate_after"])
    acLbl:SetTextColor(unpack(T.TEXT))
    acBtn:SetScript("OnClick", function()
        activate = not activate
        if activate then acFill:Show() else acFill:Hide() end
    end)

    local importBtn = AddButton(c, oy + 56, L["prof_btn_import"], function()
        local code = pasteBox:GetText()
        if not code or code:trim() == "" then
            popup:SetStatus(L["prof_msg_paste_code"], 0.9, 0.6, 0.3)
            return
        end
        local name = nameBox:GetText()
        if not name or name:trim() == "" then name = L["prof_import_default"] end
        name = name:trim()

        -- si le profil existe et overwrite desactive, ajouter un suffixe
        if not overwrite then
            local base = name
            local suffix = 1
            local rawDB = Storage.GetRawDB()
            while rawDB and rawDB.profiles and rawDB.profiles[name] do
                suffix = suffix + 1
                name = base .. " (" .. suffix .. ")"
            end
        end

        local ok, err = Storage.ImportProfile(name, code:trim())
        if ok then
            if activate then
                Storage.SetActiveProfile(name)
            end
            ReloadUI()
            return
        else
            popup:SetStatus((L["prof_msg_error"] or "Error: ") .. (err or "Invalid data"), 0.9, 0.3, 0.3)
        end
    end)
    importBtn:ClearAllPoints()
    importBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(oy + 56))

    popup._built = true
    return popup
end

-- ============================================================================
-- POPUP: SHARE PROFILE
-- ============================================================================

local function BuildSharePopup(refreshPage)
    local popup = MakePopup("share", L["prof_popup_share"], 480, 300)
    if popup._built then return popup end

    local cr, cg, cb = M:GetClassColor()
    local c = popup._content

    local CHANNELS = {
        { text = "Whisper",  value = "WHISPER" },
        { text = "Party",    value = "PARTY" },
        { text = "Raid",     value = "RAID" },
        { text = "Guild",    value = "GUILD" },
    }

    popup._shareProfile = nil
    popup._shareChannel = "WHISPER"

    -- Profile dropdown
    local profLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(profLabel, 11, "OUTLINE")
    profLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    profLabel:SetText(L["prof_profile"])
    profLabel:SetTextColor(unpack(T.TEXT))

    local profDD = CreateFrame("Button", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    profDD:SetHeight(26)
    profDD:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -18)
    profDD:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    profDD:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    profDD:SetBackdropColor(unpack(T.BTN))
    profDD:SetBackdropBorderColor(unpack(T.BORDER))
    local profText = profDD:CreateFontString(nil, "OVERLAY")
    M:SafeFont(profText, 11, "OUTLINE")
    profText:SetPoint("LEFT", 10, 0)
    profText:SetTextColor(unpack(T.TEXT))
    M:CreateDropdownArrow(profDD)

    profDD:SetScript("OnClick", function(self)
        local profiles = GetAllProfiles()
        local items = {}
        for _, name in ipairs(profiles) do
            items[#items + 1] = { text = name, value = name }
        end
        M:ShowFlyout(self, items, popup._shareProfile, function(val)
            popup._shareProfile = val
            profText:SetText(val)
        end)
    end)
    profDD:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
    profDD:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)

    -- Channel dropdown
    local chanLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(chanLabel, 11, "OUTLINE")
    chanLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)
    chanLabel:SetText(L["prof_channel"])
    chanLabel:SetTextColor(unpack(T.TEXT))

    local chanDD = CreateFrame("Button", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    chanDD:SetHeight(26)
    chanDD:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -74)
    chanDD:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    chanDD:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    chanDD:SetBackdropColor(unpack(T.BTN))
    chanDD:SetBackdropBorderColor(unpack(T.BORDER))
    local chanText = chanDD:CreateFontString(nil, "OVERLAY")
    M:SafeFont(chanText, 11, "OUTLINE")
    chanText:SetPoint("LEFT", 10, 0)
    chanText:SetTextColor(unpack(T.TEXT))
    chanText:SetText("Whisper")
    M:CreateDropdownArrow(chanDD)

    -- Target input (visible only for WHISPER)
    local targetLabel = c:CreateFontString(nil, "OVERLAY")
    M:SafeFont(targetLabel, 11, "OUTLINE")
    targetLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -112)
    targetLabel:SetText(L["prof_target_player"])
    targetLabel:SetTextColor(unpack(T.TEXT))

    local targetBox = CreateFrame("EditBox", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    targetBox:SetHeight(26)
    targetBox:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -130)
    targetBox:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    targetBox:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
    targetBox:SetBackdropColor(0.04, 0.04, 0.06, 0.80)
    targetBox:SetBackdropBorderColor(unpack(T.BORDER))
    targetBox:SetAutoFocus(false)
    targetBox:SetTextInsets(8, 8, 0, 0)
    M:SafeFont(targetBox, 11, "OUTLINE")
    targetBox:SetTextColor(unpack(T.TEXT))

    local function UpdateTargetVisibility()
        if popup._shareChannel == "WHISPER" then
            targetLabel:Show(); targetBox:Show()
        else
            targetLabel:Hide(); targetBox:Hide()
        end
    end

    chanDD:SetScript("OnClick", function(self)
        M:ShowFlyout(self, CHANNELS, popup._shareChannel, function(val, text)
            popup._shareChannel = val
            chanText:SetText(text)
            UpdateTargetVisibility()
        end)
    end)
    chanDD:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
    chanDD:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)

    -- Send button
    local sendBtn = AddButton(c, 168, L["prof_btn_send"], function()
        if not BravLib.Share then
            popup:SetStatus(L["prof_msg_ps_unavail"], 0.9, 0.6, 0.3)
            return
        end
        local prof = popup._shareProfile
        if not prof or prof == "" then
            popup:SetStatus(L["prof_msg_select"], 0.9, 0.6, 0.3)
            return
        end
        local chan = popup._shareChannel
        local target = (chan == "WHISPER") and targetBox:GetText() or nil
        if chan == "WHISPER" and (not target or target:trim() == "") then
            popup:SetStatus(L["prof_msg_enter_player"], 0.9, 0.6, 0.3)
            return
        end
        if target then target = target:trim() end

        popup:SetStatus(L["prof_msg_sending"], 0.9, 0.9, 0.3)
        BravLib.Share.Send(prof, chan, target, function(status, pct)
            if status == "ok" then
                popup:SetStatus(L["prof_msg_sent"], 0.3, 0.9, 0.3)
            elseif status == "progress" then
                popup:SetStatus(string.format(L["prof_msg_sending_pct"], pct or 0), 0.9, 0.9, 0.3)
            elseif status == "declined" then
                popup:SetStatus(L["prof_msg_declined"], 0.9, 0.3, 0.3)
            elseif status == "timeout" then
                popup:SetStatus(L["prof_msg_timeout"], 0.9, 0.6, 0.3)
            elseif status == "accepted" then
                popup:SetStatus(L["prof_msg_accepted"], 0.3, 0.9, 0.3)
            else
                popup:SetStatus(tostring(status), 0.9, 0.3, 0.3)
            end
        end)
    end)
    sendBtn:ClearAllPoints()
    sendBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -168)

    UpdateTargetVisibility()

    -- On show: prefill current profile
    local origShow = popup.ShowPopup
    function popup:ShowPopup()
        origShow(self)
        popup._shareProfile = Storage.GetActiveProfileName()
        profText:SetText(popup._shareProfile or "")
    end

    popup._built = true
    return popup
end

-- ============================================================================
-- PAGE BUILDER
-- ============================================================================

M:RegisterPage("profils", 98, L["page_profils"] or "Profils", function(parent, add)
    local host = CreateFrame("Frame", nil, parent)
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", T.PAD, -T.PAD)
    host:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -T.PAD, -T.PAD)
    add(host)

    local cr, cg, cb = M:GetClassColor()
    local y = 0

    local refreshWidgets = {}

    local function RefreshPage()
        for _, w in ipairs(refreshWidgets) do
            if w.refresh then w.refresh() end
        end
    end

    local function RebuildProfilsPage()
        M:InvalidatePageCache("profils")
        if M.Frame and M.Frame.OpenPage then
            M.Frame:OpenPage("profils")
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION 1: Gestion des profils
    -- ════════════════════════════════════════════════════════════════════════
    y = AddSection(host, y, L["prof_section_manage"])

    -- Active profile + Copy from (cote a cote)
    local leftCol = CreateFrame("Frame", nil, host)
    leftCol:SetHeight(48 + GAP)
    leftCol:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    leftCol:SetPoint("RIGHT", host, "CENTER", -6, 0)

    local rightCol = CreateFrame("Frame", nil, host)
    rightCol:SetHeight(48 + GAP)
    rightCol:SetPoint("TOPLEFT", host, "TOP", 6, -y)
    rightCol:SetPoint("RIGHT", host, "RIGHT", 0, 0)

    local _, activeDDInfo
    _, activeDDInfo = AddDropdown(leftCol, 0, L["prof_active_profile"],
        function()
            local items = {}
            for _, name in ipairs(GetAllProfiles()) do
                items[#items + 1] = { text = name, value = name }
            end
            return items
        end,
        function() return Storage.GetActiveProfileName() end,
        function(val) Storage.SetActiveProfile(val) end,
        RebuildProfilsPage
    )

    local _copySource = nil
    local _, copyDDInfo
    _, copyDDInfo = AddDropdown(rightCol, 0, L["prof_copy_from"],
        function()
            local current = Storage.GetActiveProfileName()
            local items = {}
            for _, name in ipairs(GetAllProfiles()) do
                if name ~= current then
                    items[#items + 1] = { text = name, value = name }
                end
            end
            return items
        end,
        function() return _copySource or "" end,
        function(val) _copySource = val end,
        nil
    )

    y = y + 48 + GAP

    -- Boutons: ligne 1 — Creer / Copier / Supprimer
    y = AddButtonRow(host, y, {
        { label = L["prof_btn_create"], width = 120, onClick = function()
            BuildCreatePopup(RebuildProfilsPage):ShowPopup()
        end },
        { label = L["prof_btn_copy"], width = 120, onClick = function()
            if not _copySource or _copySource == "" then return end
            local current = Storage.GetActiveProfileName()
            local rawDB = Storage.GetRawDB()
            if rawDB and rawDB.profiles and rawDB.profiles[_copySource] then
                local data = BravLib.CopyTable(rawDB.profiles[_copySource])
                wipe(rawDB.profiles[current])
                for k, v in pairs(data) do rawDB.profiles[current][k] = v end
                BravLib.Hooks.Fire("PROFILE_CHANGED", current)
                RebuildProfilsPage()
            end
        end },
        { label = L["prof_btn_delete"], width = 120, onClick = function()
            BuildDeletePopup(RebuildProfilsPage):ShowPopup()
        end },
    })

    -- Boutons: ligne 2 — Importer / Exporter / Partager
    y = AddButtonRow(host, y, {
        { label = L["prof_btn_import"], width = 120, onClick = function()
            BuildImportPopup(RebuildProfilsPage):ShowPopup()
        end },
        { label = L["prof_btn_export"], width = 120, onClick = function()
            BuildExportPopup():ShowPopup()
        end },
        { label = L["prof_btn_share"], width = 120, onClick = function()
            BuildSharePopup(RebuildProfilsPage):ShowPopup()
        end },
    })

    y = AddSep(host, y)

    -- ════════════════════════════════════════════════════════════════════════
    -- SECTION 2: Changement de profils
    -- ════════════════════════════════════════════════════════════════════════
    y = AddSection(host, y, L["prof_section_routing"])

    -- Rebuild complet quand le mode change (les positions y dependent du mode actif)
    local function RebuildPage()
        M:InvalidatePageCache("profils")
        if M.Frame and M.Frame.OpenPage then
            M.Frame:OpenPage("profils")
        end
    end

    -- Resoudre le mode effectif
    local currentMode = Storage.GetProfileMode() or "perChar"
    local isPerSpec = Storage.GetUseSpecProfiles()
    local isPerRole = Storage.GetUseRoleProfiles()
    local effectiveMode = isPerRole and "perRole" or (isPerSpec and "perSpec" or currentMode)

    local function SetMode(mode)
        if mode == "global" then
            Storage.SetProfileMode("global")
            Storage.SetUseSpecProfiles(false)
            Storage.SetUseRoleProfiles(false)
        elseif mode == "perChar" then
            Storage.SetProfileMode("perChar")
            Storage.SetUseSpecProfiles(false)
            Storage.SetUseRoleProfiles(false)

            -- Auto-creer un profil perso si le char n'en a pas
            local ok, charKey = pcall(function()
                return UnitName("player") .. " - " .. GetRealmName()
            end)
            if ok and charKey then
                local rawDB = Storage.GetRawDB()
                local needsReload = not rawDB.profiles[charKey]
                if needsReload then
                    Storage.CreateProfile(charKey, Storage.GetActiveProfileName())
                end
                Storage.SetActiveProfile(charKey)
                if needsReload then
                    ReloadUI()
                    return
                end
            end
        elseif mode == "perSpec" then
            Storage.SetProfileMode("perChar")
            Storage.SetUseSpecProfiles(true)
            Storage.SetUseRoleProfiles(false)
        elseif mode == "perRole" then
            Storage.SetProfileMode("perChar")
            Storage.SetUseSpecProfiles(false)
            Storage.SetUseRoleProfiles(true)
        end
        RebuildPage()
    end

    -- Grille 2x2 des toggles de mode
    local ROW_H = 28
    local TOGGLE_MODES = {
        { mode = "global",  label = L["prof_global_shared"] },
        { mode = "perChar", label = L["prof_per_character"] },
        { mode = "perSpec", label = L["prof_per_spec"] },
        { mode = "perRole", label = L["prof_per_role"] or "Per-role (Tank / Heal / DPS)" },
    }

    local function MakeGridToggle(parentFrame, mode, label, anchorPoint, anchorTo, anchorRel, ax, ay)
        local cr2, cg2, cb2 = M:GetClassColor()

        local btn = CreateFrame("Button", nil, parentFrame)
        btn:SetHeight(ROW_H)
        btn:SetPoint(anchorPoint, anchorTo, anchorRel, ax, ay)

        local box = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
        box:SetSize(18, 18)
        box:SetPoint("LEFT", btn, "LEFT", 0, 0)
        box:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
        box:SetBackdropColor(0.04, 0.04, 0.06, 1)
        box:SetBackdropBorderColor(unpack(T.BORDER))

        local fill = box:CreateTexture(nil, "ARTWORK")
        fill:SetSize(10, 10)
        fill:SetPoint("CENTER", box, "CENTER", 0, 0)
        fill:SetColorTexture(cr2, cg2, cb2, 0.90)

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        M:SafeFont(lbl, 11, "OUTLINE")
        lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
        lbl:SetText(label)
        lbl:SetTextColor(unpack(T.TEXT))

        local isActive = (effectiveMode == mode)
        if isActive then
            fill:Show()
            box:SetBackdropBorderColor(cr2, cg2, cb2, 0.60)
        else
            fill:Hide()
            box:SetBackdropBorderColor(unpack(T.BORDER))
        end

        btn:SetScript("OnClick", function() SetMode(mode) end)
        btn:SetScript("OnEnter", function()
            if effectiveMode ~= mode then box:SetBackdropBorderColor(0.35, 0.35, 0.40, 1) end
        end)
        btn:SetScript("OnLeave", function()
            if effectiveMode ~= mode then box:SetBackdropBorderColor(unpack(T.BORDER)) end
        end)

        return btn
    end

    -- Ligne 1 : Global | Per-char
    local tgl1 = MakeGridToggle(host, "global", L["prof_global_shared"],
        "TOPLEFT", host, "TOPLEFT", 0, -y)
    tgl1:SetPoint("RIGHT", host, "CENTER", -8, 0)

    local tgl2 = MakeGridToggle(host, "perChar", L["prof_per_character"],
        "TOPLEFT", host, "TOP", 8, -y)
    tgl2:SetPoint("RIGHT", host, "RIGHT", 0, 0)

    y = y + ROW_H + GAP

    -- Ligne 2 : Per-spec | Per-role
    local tgl3 = MakeGridToggle(host, "perSpec", L["prof_per_spec"],
        "TOPLEFT", host, "TOPLEFT", 0, -y)
    tgl3:SetPoint("RIGHT", host, "CENTER", -8, 0)

    local tgl4 = MakeGridToggle(host, "perRole", L["prof_per_role"] or "Per-role (Tank / Heal / DPS)",
        "TOPLEFT", host, "TOP", 8, -y)
    tgl4:SetPoint("RIGHT", host, "RIGHT", 0, 0)

    y = y + ROW_H + GAP

    -- Sous-section global : dropdown du profil partage
    if effectiveMode == "global" then
        local globalDDFrame = CreateFrame("Frame", nil, host)
        globalDDFrame:SetHeight(48 + GAP)
        globalDDFrame:SetPoint("TOPLEFT", host, "TOPLEFT", 24, -y)
        globalDDFrame:SetPoint("RIGHT", host, "CENTER", -6, 0)

        AddDropdown(globalDDFrame, 0, L["prof_active_profile"],
            function()
                local items = {}
                for _, name in ipairs(GetAllProfiles()) do
                    items[#items + 1] = { text = name, value = name }
                end
                return items
            end,
            function() return Storage.GetGlobalProfileName() end,
            function(val) Storage.SetGlobalProfileName(val) end,
            nil
        )
        y = y + 48 + GAP
    end

    -- Sous-section per-spec : dropdowns par specialisation
    if effectiveMode == "perSpec" then
        local specs = GetAllPlayerSpecs()
        if #specs > 0 then
            local colW = 200
            local colGap = 12
            local specStartY = y

            for i, spec in ipairs(specs) do
                local col = ((i - 1) % 2)
                local row = math.floor((i - 1) / 2)
                local xOff = 24 + col * (colW + colGap)
                local yOff = specStartY + row * (48 + GAP)

                local sf = CreateFrame("Frame", nil, host)
                sf:SetSize(colW, 48)
                sf:SetPoint("TOPLEFT", host, "TOPLEFT", xOff, -yOff)

                local sl = sf:CreateFontString(nil, "OVERLAY")
                M:SafeFont(sl, 10, "OUTLINE")
                sl:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
                sl:SetText(spec.name)
                sl:SetTextColor(unpack(T.TEXT))

                local sdd = CreateFrame("Button", nil, sf, BackdropTemplateMixin and "BackdropTemplate" or nil)
                sdd:SetHeight(24)
                sdd:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -16)
                sdd:SetPoint("RIGHT", sf, "RIGHT", 0, 0)
                sdd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
                sdd:SetBackdropColor(unpack(T.BTN))
                sdd:SetBackdropBorderColor(unpack(T.BORDER))

                local curSpecProf = Storage.GetSpecProfile(spec.index)
                    or Storage.GetActiveProfileName()

                local sddText = sdd:CreateFontString(nil, "OVERLAY")
                M:SafeFont(sddText, 10, "OUTLINE")
                sddText:SetPoint("LEFT", 8, 0)
                sddText:SetText(curSpecProf)
                sddText:SetTextColor(unpack(T.TEXT))
                M:CreateDropdownArrow(sdd, 8)

                local specIndex = spec.index
                sdd:SetScript("OnClick", function(self)
                    local profiles = GetAllProfiles()
                    local items = {}
                    for _, name in ipairs(profiles) do
                        items[#items + 1] = { text = name, value = name }
                    end
                    local cur = Storage.GetSpecProfile(specIndex) or Storage.GetActiveProfileName()
                    M:ShowFlyout(self, items, cur, function(val)
                        Storage.SetSpecProfile(specIndex, val)
                        sddText:SetText(val)
                    end)
                end)
                sdd:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
                sdd:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)
            end

            local specRows = math.ceil(#specs / 2)
            y = y + specRows * (48 + GAP)
        end
    end

    -- Sous-section per-role : 3 dropdowns (Tank / Heal / DPS)
    if effectiveMode == "perRole" then
        local ROLES = {
            { key = "TANK",    label = L["prof_role_tank"] or "Tank" },
            { key = "HEALER",  label = L["prof_role_healer"] or "Healer" },
            { key = "DAMAGER", label = L["prof_role_dps"] or "DPS" },
        }

        for _, roleInfo in ipairs(ROLES) do
            local roleFrame = CreateFrame("Frame", nil, host)
            roleFrame:SetSize(200, 48)
            roleFrame:SetPoint("TOPLEFT", host, "TOPLEFT", 24, -y)

            local rl = roleFrame:CreateFontString(nil, "OVERLAY")
            M:SafeFont(rl, 10, "OUTLINE")
            rl:SetPoint("TOPLEFT", roleFrame, "TOPLEFT", 0, 0)
            rl:SetText(roleInfo.label)
            rl:SetTextColor(unpack(T.TEXT))

            local rdd = CreateFrame("Button", nil, roleFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
            rdd:SetHeight(24)
            rdd:SetPoint("TOPLEFT", roleFrame, "TOPLEFT", 0, -16)
            rdd:SetPoint("RIGHT", roleFrame, "RIGHT", 0, 0)
            rdd:SetBackdrop({ bgFile = T.TEX, edgeFile = T.TEX, edgeSize = 1 })
            rdd:SetBackdropColor(unpack(T.BTN))
            rdd:SetBackdropBorderColor(unpack(T.BORDER))

            local curRoleProf = Storage.GetRoleProfile(roleInfo.key) or ""
            local rddText = rdd:CreateFontString(nil, "OVERLAY")
            M:SafeFont(rddText, 10, "OUTLINE")
            rddText:SetPoint("LEFT", 8, 0)
            rddText:SetText(curRoleProf ~= "" and curRoleProf or "—")
            rddText:SetTextColor(unpack(T.TEXT))
            M:CreateDropdownArrow(rdd, 8)

            local roleKey = roleInfo.key
            rdd:SetScript("OnClick", function(self)
                local profiles = GetAllProfiles()
                local items = { { text = "—", value = "" } }
                for _, name in ipairs(profiles) do
                    items[#items + 1] = { text = name, value = name }
                end
                local cur = Storage.GetRoleProfile(roleKey) or ""
                M:ShowFlyout(self, items, cur, function(val)
                    if val == "" then val = nil end
                    Storage.SetRoleProfile(roleKey, val)
                    rddText:SetText(val or "—")
                end)
            end)
            rdd:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1) end)
            rdd:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.BORDER)) end)

            y = y + 48 + GAP
        end
    end

    host:SetHeight(y + T.PAD)
end)

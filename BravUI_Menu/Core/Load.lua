-- BravUI_Menu/Core/Router.lua
-- Enregistrement des pages, ordre, cache

local M = BravUI.Menu

M.Pages       = M.Pages or {}
M._pageOrder  = M._pageOrder or {}
M._pageCache  = M._pageCache or {}
M._activePage = nil

-- ============================================================================
-- REGISTER PAGE
-- ============================================================================

function M:RegisterPage(id, order, title, buildFn, opts)
  if type(id) ~= "string" or type(buildFn) ~= "function" then return end

  self.Pages[id] = {
    id          = id,
    order       = tonumber(order) or 100,
    title       = title or id,
    build       = buildFn,
    onShow      = opts and opts.onShow,
    onHide      = opts and opts.onHide,
    statusCheck = opts and opts.statusCheck,
  }

  -- Rebuild sorted list
  self._pageOrder = {}
  for _, p in pairs(self.Pages) do
    self._pageOrder[#self._pageOrder + 1] = p
  end
  table.sort(self._pageOrder, function(a, b)
    if a.order == b.order then return a.id < b.id end
    return a.order < b.order
  end)
end

-- ============================================================================
-- QUERY
-- ============================================================================

function M:GetOrderedPages()
  return self._pageOrder
end

function M:GetActivePage()
  return self._activePage
end

-- ============================================================================
-- BUILD / CACHE
-- ============================================================================

function M:BuildPageInto(id, host)
  local page = self.Pages[id]
  if not page then return end

  -- Return cached if exists
  local cached = self._pageCache[id]
  if cached then
    cached:SetParent(host)
    cached:ClearAllPoints()
    cached:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    cached:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    cached:Show()
    local cH = cached._contentHeight or cached:GetHeight() or 1
    host:SetHeight(math.max(cH, 1))
    for _, child in ipairs(cached.__children or {}) do
      if child._refreshFn then
        M._pageRefreshFn = child._refreshFn
        break
      end
    end
    if page.onShow then pcall(page.onShow) end
    return cached
  end

  -- Build fresh
  local container = CreateFrame("Frame", nil, host)
  container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  container:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
  container.__children = {}

  local ok, err = pcall(page.build, container, function(w)
    container.__children[#container.__children + 1] = w
  end)

  if not ok then
    local fs = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    local errLabel = (M.L and M.L["msg_error_page"]) or "Erreur"
    fs:SetText("|cffff4444" .. errLabel .. ": " .. tostring(err) .. "|r")
    container:SetHeight(40)
    host:SetHeight(40)
    return container
  end

  local cH = container:GetHeight()
  if cH <= 0 then
    local maxBottom = 0
    for _, child in ipairs(container.__children) do
      local _, _, _, _, ofY = child:GetPoint()
      local h = child:GetHeight() or 0
      local bottom = (ofY and math.abs(ofY) or 0) + h
      if bottom > maxBottom then maxBottom = bottom end
    end
    cH = maxBottom
    container:SetHeight(math.max(cH, 1))
  end
  host:SetHeight(math.max(cH, 1))
  container._contentHeight = cH

  self._pageCache[id] = container
  if page.onShow then pcall(page.onShow) end
  return container
end

function M:HidePage(id)
  local cached = self._pageCache[id]
  if cached then cached:Hide() end
  local page = self.Pages[id]
  if page and page.onHide then pcall(page.onHide) end
end

function M:InvalidatePageCache(id)
  if id then
    local cached = self._pageCache[id]
    if cached then cached:Hide(); cached:SetParent(nil) end
    self._pageCache[id] = nil
  else
    for _, v in pairs(self._pageCache) do
      v:Hide(); v:SetParent(nil)
    end
    wipe(self._pageCache)
  end
end

local BravLib = BravLib

-- ============================================================================
-- BravLib.Format — Formatage de nombres, temps, widgets partagés
-- ============================================================================

BravLib.Format = {}
local F = BravLib.Format

-- ============================================================================
-- CONSTANTES
-- ============================================================================

F.TEX_WHITE = "Interface/Buttons/WHITE8x8"

-- ============================================================================
-- FORMATAGE NOMBRES
-- ============================================================================

--- Formate un nombre en K/M/B (nombres normaux uniquement)
--- @param n number
--- @return string
function F.Number(n)
    if not n or n == 0 then return "0" end
    if type(n) ~= "number" then
        local ok, s = pcall(tostring, n)
        return ok and s or "?"
    end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return string.format("%.0f", n)
end

-- ============================================================================
-- SECRET-SAFE FORMAT (AbbreviateNumbers pour Midnight 12.0+ secrets)
-- ============================================================================

local abbreviateConfigDPS
local abbreviateConfigDmg

local function InitAbbreviateConfigs()
    if abbreviateConfigDPS then return true end
    if not CreateAbbreviateConfig or not AbbreviateNumbers then return false end

    local okDPS, cfgDPS = pcall(CreateAbbreviateConfig, {
        { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 10000,    fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1000,       abbreviation = "K", significandDivisor = 100,      fractionDivisor = 10,  abbreviationIsGlobal = false },
        { breakpoint = 1,          abbreviation = "",  significandDivisor = 1,        fractionDivisor = 1,   abbreviationIsGlobal = false },
    })
    if okDPS and cfgDPS then
        abbreviateConfigDPS = { config = cfgDPS }
    end

    local okDmg, cfgDmg = pcall(CreateAbbreviateConfig, {
        { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 10000,    fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 10000,      abbreviation = "K", significandDivisor = 1000,     fractionDivisor = 1,   abbreviationIsGlobal = false },
        { breakpoint = 1000,       abbreviation = "K", significandDivisor = 100,      fractionDivisor = 10,  abbreviationIsGlobal = false },
        { breakpoint = 1,          abbreviation = "",  significandDivisor = 1,        fractionDivisor = 1,   abbreviationIsGlobal = false },
    })
    if okDmg and cfgDmg then
        abbreviateConfigDmg = { config = cfgDmg }
    end

    return abbreviateConfigDPS ~= nil
end

--- Formate un nombre normal ou secret pour affichage
--- Normaux: F.Number (comparisons + arithmétique)
--- Secrets: AbbreviateNumbers (Blizzard C function, gère les secrets)
--- @param val any nombre ou secret value
--- @param useDmgConfig boolean|nil utiliser la config dégâts (sans décimale > 10K)
--- @return string|nil
function F.SafeFormat(val, useDmgConfig)
    if not val then return nil end

    local isSecret = false
    if issecretvalue then
        local sok, sres = pcall(issecretvalue, val)
        if sok and sres then isSecret = true end
    end

    if not isSecret then
        local ok, result = pcall(function() return F.Number(val) end)
        if ok and result then return result end
    end

    InitAbbreviateConfigs()
    local cfg = useDmgConfig and abbreviateConfigDmg or abbreviateConfigDPS
    if cfg and AbbreviateNumbers then
        local ok, result = pcall(AbbreviateNumbers, val, cfg)
        if ok and result then return result end
    end

    if AbbreviateLargeNumbers then
        local ok, result = pcall(AbbreviateLargeNumbers, val)
        if ok and result then return result end
    end

    return nil
end

--- Division safe (pcall, retourne nil si erreur)
--- @param a any
--- @param b any
--- @return number|nil
function F.SafeDiv(a, b)
    if not a or not b then return nil end
    local ok, result = pcall(function() return a / b end)
    return (ok and type(result) == "number") and result or nil
end

-- ============================================================================
-- FORMATAGE TEMPS
-- ============================================================================

--- Formate un temps en "m:ss"
--- @param seconds number
--- @return string
function F.Time(seconds)
    if not seconds then return "0:00" end
    local ok, result = pcall(function()
        if seconds < 0 then seconds = 0 end
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%d:%02d", m, s)
    end)
    return ok and result or "0:00"
end

--- Formate un temps en "mm:ss"
--- @param seconds number
--- @return string
function F.TimeMMSS(seconds)
    if not seconds then return "--:--" end
    local ok, result = pcall(function()
        if seconds < 0 then return "--:--" end
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%02d:%02d", m, s)
    end)
    return ok and result or "--:--"
end

-- ============================================================================
-- WIDGETS PARTAGÉS
-- ============================================================================

--- Applique l'ombre standard sur un FontString
--- @param fs FontString
function F.ApplyShadow(fs)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
end

--- Crée un FontString OUTLINE avec ombre
--- @param parent Frame
--- @param size number
--- @param layer string|nil
--- @return FontString
function F.MakeFont(parent, size, layer)
    local font = BravUI and BravUI.Utils and BravUI.Utils.GetFont and BravUI.Utils.GetFont()
        or "Fonts/FRIZQT__.TTF"
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    pcall(function() fs:SetFont(font, size, "OUTLINE") end)
    F.ApplyShadow(fs)
    return fs
end

--- Crée un séparateur horizontal 1px
--- @param parent Frame
--- @return Texture
function F.MakeSep(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(F.TEX_WHITE)
    t:SetHeight(1)
    t:SetVertexColor(0.15, 0.15, 0.15, 1)
    return t
end

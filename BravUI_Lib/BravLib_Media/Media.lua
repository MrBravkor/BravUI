local BravLib = BravLib

BravLib.Media = {}

local media = {
    font = {},
    texture = {},
    sound = {},
}

function BravLib.Media.Register(mediaType, name, path)
    if not media[mediaType] then
        media[mediaType] = {}
    end
    media[mediaType][name] = path
end

function BravLib.Media.Get(mediaType, name)
    if not media[mediaType] then return nil end
    return media[mediaType][name]
end

function BravLib.Media.GetAll(mediaType)
    if not media[mediaType] then return {} end
    return media[mediaType]
end

-- Default WoW fonts
BravLib.Media.Register("font", "blizzard", STANDARD_TEXT_FONT)
BravLib.Media.Register("font", "number", NUMBER_FONT_NORMAL)

-- BravUI custom fonts
BravLib.Media.Register("font", "default", "Interface/AddOns/BravUI_Lib/BravLib_Media/Fonts/Russo_One.ttf")
BravLib.Media.Register("font", "uf",      "Interface/AddOns/BravUI_Lib/BravLib_Media/Fonts/Russo_One.ttf")
BravLib.Media.Register("font", "icons", "Interface/AddOns/BravUI_Lib/BravLib_Media/Fonts/Font_Icons.ttf")

-- Role icons
BravLib.Media.Register("icon", "dps",    "Interface/AddOns/BravUI_Lib/BravLib_Media/Icons/DPS.tga")
BravLib.Media.Register("icon", "healer", "Interface/AddOns/BravUI_Lib/BravLib_Media/Icons/Healer.tga")
BravLib.Media.Register("icon", "tank",   "Interface/AddOns/BravUI_Lib/BravLib_Media/Icons/Tank.tga")

-- Logo
BravLib.Media.Register("texture", "logo", "Interface/AddOns/BravUI_Lib/BravLib_Media/Logo/BravUI_64x64.tga")

-- Cursor
BravLib.Media.Register("texture", "cursor_ring", "Interface/AddOns/BravUI_Lib/BravLib_Media/Cursor/Ring.tga")
BravLib.Media.Register("texture", "cursor_dot",  "Interface/AddOns/BravUI_Lib/BravLib_Media/Cursor/Dot.tga")

-- Bars (statusbar textures)
local BAR_PATH = "Interface/AddOns/BravUI_Lib/BravLib_Media/Bars/"
BravLib.Media.Register("statusbar", "beveled",             BAR_PATH .. "M_Beveled.tga")
BravLib.Media.Register("statusbar", "colorwheel",          BAR_PATH .. "M_ColorWheel.tga")
BravLib.Media.Register("statusbar", "glass",               BAR_PATH .. "M_Glass.tga")
BravLib.Media.Register("statusbar", "glossy",              BAR_PATH .. "M_Glossy.tga")
BravLib.Media.Register("statusbar", "gradient_h",          BAR_PATH .. "M_Gradient_H.tga")
BravLib.Media.Register("statusbar", "gradient_h_rev",      BAR_PATH .. "M_Gradient_H_Rev.tga")
BravLib.Media.Register("statusbar", "gradient_v",          BAR_PATH .. "M_Gradient_V.tga")
BravLib.Media.Register("statusbar", "gradient_v_rev",      BAR_PATH .. "M_Gradient_V_Rev.tga")
BravLib.Media.Register("statusbar", "matte",               BAR_PATH .. "M_Matte.tga")
BravLib.Media.Register("statusbar", "minimalist",          BAR_PATH .. "M_Minimalist.tga")
BravLib.Media.Register("statusbar", "ring",                BAR_PATH .. "M_Ring.tga")
BravLib.Media.Register("statusbar", "smooth",              BAR_PATH .. "M_Smooth.tga")
BravLib.Media.Register("statusbar", "soft",                BAR_PATH .. "M_Soft.tga")
BravLib.Media.Register("statusbar", "stripes",             BAR_PATH .. "M_Stripes.tga")
BravLib.Media.Register("statusbar", "stripes_dense",       BAR_PATH .. "M_Stripes_Dense.tga")
BravLib.Media.Register("statusbar", "stripes_medium",      BAR_PATH .. "M_Stripes_Medium.tga")
BravLib.Media.Register("statusbar", "stripes_soft",        BAR_PATH .. "M_Stripes_Soft.tga")
BravLib.Media.Register("statusbar", "stripes_soft_wide",   BAR_PATH .. "M_Stripes_Soft_Wide.tga")
BravLib.Media.Register("statusbar", "stripes_sparse",      BAR_PATH .. "M_Stripes_Sparse.tga")
BravLib.Media.Register("statusbar", "stripes_very_dense",  BAR_PATH .. "M_Stripes_Very_Dense.tga")

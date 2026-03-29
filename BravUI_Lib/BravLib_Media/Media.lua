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

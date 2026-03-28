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
BravLib.Media.Register("font", "default", STANDARD_TEXT_FONT)
BravLib.Media.Register("font", "number", NUMBER_FONT_NORMAL)

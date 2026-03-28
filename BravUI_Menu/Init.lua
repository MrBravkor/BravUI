BravUI.Menu = BravUI.Menu or {}

-- /brav — open menu
SLASH_BRAV1 = "/brav"

SlashCmdList["BRAV"] = function()
    if BravUI.Menu.Toggle then
        BravUI.Menu:Toggle()
    else
        BravLib.Print("Menu not yet implemented.")
    end
end

-- /bravmove — toggle movers
SLASH_BRAVMOVE1 = "/bravmove"

SlashCmdList["BRAVMOVE"] = function()
    BravUI.Move.Toggle()
end

-- /bravreset — reset settings
SLASH_BRAVRESET1 = "/bravreset"

SlashCmdList["BRAVRESET"] = function()
    BravLib.Storage.Reset()
    BravLib.Print("Settings reset to defaults. Reload UI to apply.")
end

-- /bravdebug — toggle debug mode
SLASH_BRAVDEBUG1 = "/bravdebug"

SlashCmdList["BRAVDEBUG"] = function()
    BravLib.debug = not BravLib.debug
    BravLib.Print("Debug mode: " .. (BravLib.debug and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

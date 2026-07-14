local addonName, ns = ...
local L = ns.L or {}
ns.L = L

L["LOGIN"]           = "|cff00ff00v%s|r loaded — type /brav for options."

L["HELP_HEADER"]     = "version %s. Commands:"
L["HELP_PROFILE"]    = "  /brav profile — show the active profile"
L["HELP_PERSPEC"]    = "  /brav perspec on|off — separate profile per specialization"
L["HELP_RESET"]      = "  /brav reset — reset the active profile to defaults"

L["PROFILE_RESET"]   = "Active profile reset to defaults."
L["PROFILE_CURRENT"] = "Active profile: %s"
L["PERSPEC_ON"]      = "Per-specialization profiles enabled for this character."
L["PERSPEC_OFF"]     = "Per-specialization profiles disabled for this character."

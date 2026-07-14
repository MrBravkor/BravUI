local addonName, ns = ...
if GetLocale() ~= "frFR" then return end
local L = ns.L

L["LOGIN"]           = "|cff00ff00v%s|r chargée — tapez /brav pour les options."

L["HELP_HEADER"]     = "version %s. Commandes :"
L["HELP_PROFILE"]    = "  /brav profile — affiche le profil actif"
L["HELP_PERSPEC"]    = "  /brav perspec on|off — profil séparé par spécialisation"
L["HELP_RESET"]      = "  /brav reset — réinitialise le profil actif"

L["PROFILE_RESET"]   = "Profil actif réinitialisé aux valeurs par défaut."
L["PROFILE_CURRENT"] = "Profil actif : %s"
L["PERSPEC_ON"]      = "Profils par spécialisation activés pour ce personnage."
L["PERSPEC_OFF"]     = "Profils par spécialisation désactivés pour ce personnage."

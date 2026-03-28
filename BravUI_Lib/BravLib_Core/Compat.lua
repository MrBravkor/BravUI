local BravLib = BravLib

BravLib.Compat = {}

-- WoW 12.0.x compatibility layer

-- C_AddOns (moved in 10.x, old globals removed in 12.x)
if C_AddOns then
    BravLib.Compat.IsAddOnLoaded = C_AddOns.IsAddOnLoaded
    BravLib.Compat.LoadAddOn = C_AddOns.LoadAddOn
else
    BravLib.Compat.IsAddOnLoaded = IsAddOnLoaded
    BravLib.Compat.LoadAddOn = LoadAddOn
end

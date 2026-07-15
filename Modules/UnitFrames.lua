-- BravUI — Module UnitFrames
--
-- Cadres d'unité maison (aucune dépendance externe). Cette itération fournit les
-- cadres JOUEUR et CIBLE : barre de vie + barre de ressource, nom, niveau et
-- valeurs. L'ensemble est bâti autour de fabriques réutilisables (CreateBar puis
-- CreateUnitFrame) : ajouter une unité = l'ajouter à UNITS + ses défauts, sans
-- réécriture (l'ajout ultérieur de castbar / auras suivra le même principe).
--
-- Perf : les événements unitaires (UNIT_*) sont enregistrés via RegisterUnitEvent
-- directement sur chaque cadre. Le moteur filtre alors par unité et ne réveille
-- notre code que pour l'unité concernée — c'est la raison d'être de la
-- distinction avec l'EventBus (réservé aux événements broadcast).

local addonName, ns = ...
local U = ns.Utils

--------------------------------------------------------------------------------
-- Réglages par défaut (contribués au système de profils du cœur)
--------------------------------------------------------------------------------
-- Schéma imbriqué : position = ancrage CENTER + offset (x, y). La ressource a sa
-- PROPRE largeur (indépendante de la vie), centrée sous la barre de vie.
local DEFAULTS = {
    player = {
        enabled = true,       -- affiche/masque tout le cadre
        scale   = 1.0,        -- échelle globale du cadre (vie + ressource + classe…)
        x       = -260,       -- offset depuis le centre de l'écran
        y       = -140,
        health  = { width = 250, height = 50 },
        power   = { width = 250, height = 15, gap = 3 },
        castbar = { enabled = true, height = 18, gap = 3 },
        -- Ressource de classe (points de combo, puissance sacrée…). Joueur
        -- uniquement : barre segmentée AU-DESSUS de la vie (gap = espace au-dessus).
        classpower = { enabled = true, height = 10, gap = 3 },
    },
    target = {
        enabled  = true,
        scale    = 1.0,
        x        = 260,
        y        = -140,
        mirrored = true,      -- disposition inversée (nom à droite, remplissage <-)
        health   = { width = 250, height = 50 },
        power    = { width = 250, height = 15, gap = 3 },
        castbar  = { enabled = true, height = 18, gap = 3 },
    },
    -- Focus : token « réel » (events UNIT_* + PLAYER_FOCUS_CHANGED fiables), traité
    -- comme la cible. Même taille que joueur/cible (UI uniforme), placé au-dessus du joueur.
    focus = {
        enabled  = true,
        scale    = 1.0,
        x        = -260,
        y        = 45,
        health   = { width = 250, height = 50 },
        power    = { width = 250, height = 15, gap = 3 },
        castbar  = { enabled = true, height = 18, gap = 3 },
    },
    -- Cible-de-cible : token DÉRIVÉ sans event unitaire fiable -> rafraîchissement
    -- throttlé (voir CreateUnitFrame). Même taille que les autres, castbar désactivée.
    targettarget = {
        enabled  = true,
        scale    = 1.0,
        x        = 260,
        y        = 45,
        mirrored = true,
        health   = { width = 250, height = 50 },
        power    = { width = 250, height = 15, gap = 3 },
        castbar  = { enabled = true, height = 18, gap = 3 },
    },
}

-- Style/placement PAR ÉLÉMENT (modèle commun : activé, échelle, offset x/y, opacité
-- de fond, contour, bord arrondi). Ajouté ici à la barre de VIE de chaque unité
-- (les autres éléments suivront). Défauts choisis pour reproduire le rendu actuel.
for _, u in pairs(DEFAULTS) do
    local h = u.health
    h.scale  = h.scale  or 1
    h.x      = h.x      or 0
    h.y      = h.y      or 0
    if h.enabled == nil then h.enabled = true end
    if h.bgAlpha == nil then h.bgAlpha = 0.5 end -- 0 = rien, 0.5 = gris, 1 = noir
    if h.rounded == nil then h.rounded = true end
    -- Sens inversé + ancres texte : par défaut selon le MIROIR de l'unité (cible/ToT
    -- -> inversé + texte à droite ; joueur/focus -> normal + texte à gauche).
    if h.reverse == nil then h.reverse = u.mirrored == true end
    if h.showName == nil then h.showName = true end   -- afficher le nom
    if h.showLevel == nil then h.showLevel = true end -- afficher le niveau
    if h.showHP == nil then h.showHP = true end       -- afficher les PV
    if h.showPct == nil then h.showPct = true end     -- afficher le %
    h.namePos  = h.namePos  or (u.mirrored and "TOPRIGHT" or "TOPLEFT")
    h.valuePos = h.valuePos or (u.mirrored and "BOTTOMLEFT" or "BOTTOMRIGHT")

    -- Élément RESSOURCE (même modèle). Défaut : centré sous la vie.
    local p = u.power
    p.scale = p.scale or 1
    p.x = p.x or 0
    if p.y == nil then p.y = -(u.health.height / 2 + (p.gap or 3) + p.height / 2) end
    if p.enabled == nil then p.enabled = true end
    if p.bgAlpha == nil then p.bgAlpha = 0.5 end
    if p.rounded == nil then p.rounded = true end
    if p.reverse == nil then p.reverse = u.mirrored == true end
    if p.showVal == nil then p.showVal = true end -- afficher la valeur
    if p.showPct == nil then p.showPct = true end -- afficher le %
    p.valuePos = p.valuePos or "CENTER"           -- ancre valeur/% (centré par défaut)

    -- Élément RESSOURCE DE CLASSE (joueur seul). Défaut : centré au-dessus de la vie.
    local cp = u.classpower
    if cp then
        cp.scale = cp.scale or 1
        cp.x = cp.x or 0
        if cp.y == nil then cp.y = u.health.height / 2 + (cp.gap or 3) + cp.height / 2 end
        if cp.width == nil then cp.width = u.health.width end
        if cp.enabled == nil then cp.enabled = true end
        if cp.bgAlpha == nil then cp.bgAlpha = 0.5 end
        if cp.rounded == nil then cp.rounded = true end
        if cp.reverse == nil then cp.reverse = u.mirrored == true end
    end

    -- Élément INCANTATION (castbar). Défaut : centré sous la ressource.
    local cb = u.castbar
    cb.scale = cb.scale or 1
    cb.x = cb.x or 0
    if cb.y == nil then cb.y = p.y - (p.height / 2 + (cb.gap or 3) + cb.height / 2) end
    if cb.width == nil then cb.width = u.health.width end
    if cb.bgAlpha == nil then cb.bgAlpha = 0.5 end
    if cb.rounded == nil then cb.rounded = true end
    if cb.reverse == nil then cb.reverse = u.mirrored == true end
    if cb.showIcon == nil then cb.showIcon = true end
    if cb.showName == nil then cb.showName = true end
    if cb.showTimer == nil then cb.showTimer = true end
end
ns.Config:RegisterDefaults("unitframes", DEFAULTS)

-- Unités gérées par le module, dans l'ordre de création.
local UNITS = { "player", "target", "focus", "targettarget" }

-- Libellés affichés sur l'overlay d'aide au repositionnement (mode déverrouillé).
local UNIT_LABELS = {
    player = "Joueur", target = "Cible", focus = "Focus", targettarget = "Cible-cible",
}

local M = ns:RegisterModule("UnitFrames")

--------------------------------------------------------------------------------
-- Constantes visuelles
--------------------------------------------------------------------------------
local FLAT      = "Interface\\Buttons\\WHITE8X8"                           -- texture pleine -> plat
local MASK      = "Interface\\AddOns\\BravUI\\Media\\roundmask.tga"        -- coins arrondis (barre haute)
local MASK_THIN = "Interface\\AddOns\\BravUI\\Media\\roundmask_thin.tga"   -- coins arrondis (barre fine)
local FONT      = "Interface\\AddOns\\BravUI\\Media\\RussoOne-Regular.ttf" -- police BravUI (Russo One)

-- Applique la police BravUI à un FontString, avec repli sur la police du client
-- si le .ttf ne peut pas être chargé (SetFont renvoie false en cas d'échec).
local function ApplyFont(fs, size, flags)
    if not fs:SetFont(FONT, size, flags) then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
end

-- Interpolation NATIVE des barres (12.0) : StatusBar:SetValue(v, interpolation)
-- anime le remplissage côté moteur -> fluide ET compatible valeurs secrètes (le
-- smoothing Lua classique est impossible, on ne peut pas interpoler un secret ;
-- et SmoothStatusBarMixin plante chaque tick sur Midnight). nil sur un client
-- plus ancien -> mise à jour instantanée (repli propre).
local SMOOTH = Enum and Enum.StatusBarInterpolation
    and Enum.StatusBarInterpolation.ExponentialEaseOut

--------------------------------------------------------------------------------
-- Courbe de mise à l'échelle du % (vie ET ressource)
-- En 12.0, UnitHealthPercent / UnitPowerPercent renvoient une fraction SECRÈTE
-- [0-1] qu'on ne peut ni comparer ni multiplier côté Lua. Leur paramètre « curve »
-- fait la conversion côté moteur : une courbe linéaire x[0..1] -> y[0..100] que le
-- moteur évalue pour renvoyer un secret ~0-100 rendu par le widget.
--------------------------------------------------------------------------------
local pctCurve
if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
    local ok, cv = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        c:SetType(Enum.LuaCurveType.Linear)
        c:AddPoint(0, 0)
        c:AddPoint(1, 100)
        return c
    end)
    if ok then pctCurve = cv end
end

--------------------------------------------------------------------------------
-- Mises à jour d'affichage
-- Insecures (textures / fontstrings / StatusBar:SetValue) : autorisées même en
-- plein combat, contrairement au repositionnement des cadres sécurisés.
--------------------------------------------------------------------------------
-- Écrit « valeur(k) | % » dans un FontString (vie ou ressource) en gérant les
-- valeurs secrètes (12.0). getPct : closure renvoyant le % secret (0-100 via
-- courbe) ou nil si indisponible. On ne fait que PASSER les secrets aux widgets ;
-- l'abrégé (AbbreviateNumbers, portée côté C en 12.0) passe par une closure sous
-- pcall. Repli en cascade « val(k) | % » -> « val(k) » -> « val brute » -> rien.
-- (Dans un format : « %% » = un « % », « || » = une seule barre « | ».)
local function SetBarText(fs, cur, max, getPct, showVal, showPct)
    if showVal == nil then showVal = true end
    if showPct == nil then showPct = true end
    if not showVal and not showPct then fs:SetText(""); return end
    local secret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))
    if secret then
        local ok
        if showVal and showPct and AbbreviateNumbers and getPct then
            ok = pcall(function() fs:SetFormattedText("%s || %d%%", AbbreviateNumbers(cur), getPct()) end)
        elseif showPct and not showVal and getPct then
            ok = pcall(function() fs:SetFormattedText("%d%%", getPct()) end)
        elseif showVal and AbbreviateNumbers then
            ok = pcall(function() fs:SetFormattedText("%s", AbbreviateNumbers(cur)) end)
        end
        if not ok then
            if showVal then ok = pcall(fs.SetFormattedText, fs, "%d", cur) end
            if not ok then fs:SetText("") end
        end
    else
        local pct = (max > 0) and math.floor(cur / max * 100 + 0.5) or 0
        if showVal and showPct then fs:SetText(U.FormatNumber(cur) .. " || " .. pct .. "%")
        elseif showPct then fs:SetText(pct .. "%")
        else fs:SetText(U.FormatNumber(cur)) end
    end
end

-- État spécial de l'unité (nil si aucun). Booléens d'unité NON secrets, lisibles
-- normalement. Ordre = priorité d'affichage.
local function GetStatusText(unit)
    if not UnitExists(unit) then return nil end
    if not UnitIsConnected(unit) then return "Hors ligne" end
    if UnitIsGhost(unit) then return "Fantôme" end
    if UnitIsDead(unit) then return "Mort" end
    if UnitIsAFK(unit) then return "Absent" end
    if UnitIsDND(unit) then return "Occupé" end
    return nil
end

local function UpdateHealth(f)
    -- Mode APERÇU (réglage du cadre) : barre figée à 50 % pour voir le fond/contour
    -- et ajuster le style facilement. Ignore les vraies valeurs tant qu'il est actif.
    if f.healthPreview then
        f.health:SetMinMaxValues(0, 1)
        f.health:SetValue(0.5)
        f.hpText:SetText("50%")
        return
    end
    local cur, max = UnitHealth(f.unit), UnitHealthMax(f.unit)
    -- Les StatusBar Blizzard acceptent nativement les valeurs secrètes : la barre
    -- fonctionne SANS aucune comparaison de notre côté.
    f.health:SetMinMaxValues(0, max)
    f.health:SetValue(cur, SMOOTH) -- remplissage fluide (interpolation native)

    -- État spécial (mort / hors ligne / absent…) : remplace le texte des PV.
    local status = GetStatusText(f.unit)
    if status then
        f.hpText:SetText(status)
        return
    end
    SetBarText(f.hpText, cur, max, f.getHealthPct, f.showHP, f.showPct)
end

-- Faut-il afficher la barre de ressource ? En 12.0, UnitPowerMax est SECRET pour
-- les unités « restreintes » (cibles/ennemis) : impossible de lire si elle vaut 0.
-- Règle fiable : joueur -> oui (a toujours une ressource) ; PNJ -> seulement si
-- max est LISIBLE et > 0. Quand le moteur cache la valeur (secret) ou qu'elle est
-- nulle, on masque -> pas de barre de ressource parasite sur les cibles PNJ.
local function ShouldShowPower(f)
    if UnitIsPlayer(f.unit) then return true end
    local max = UnitPowerMax(f.unit)
    if issecretvalue and issecretvalue(max) then return false end
    return (max or 0) > 0
end

local function UpdatePower(f)
    if f.powerEnabled == false or not ShouldShowPower(f) then
        f.powerContainer:Hide()
        return
    end
    f.powerContainer:Show()
    -- Mode APERÇU (réglage) : barre figée à 50 %.
    if f.powerPreview then
        f.power:SetMinMaxValues(0, 1); f.power:SetValue(0.5)
        f.powerText:SetText("50%")
        return
    end
    local cur, max = UnitPower(f.unit), UnitPowerMax(f.unit)
    f.power:SetMinMaxValues(0, max)
    f.power:SetValue(cur, SMOOTH)
    -- Couleur selon le type de ressource courant (mana/rage/énergie…). Non secret.
    local ptype, token = UnitPowerType(f.unit)
    local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if c then f.power:SetStatusBarColor(c.r, c.g, c.b) end
    SetBarText(f.powerText, cur, max, f.getPowerPct, f.powerShowVal, f.powerShowPct)
end

-- « Nom | Lvl » dans un seul FontString. Nom et niveau s'affichent INDÉPENDAMMENT
-- (f.showName / f.showLevel). name et lvl peuvent être SECRETS en 12.0 : on ne
-- concatène/compare JAMAIS un secret, on le laisse rendre par SetFormattedText
-- (« %d »/« %s » acceptent les secrets), sous pcall.
local function UpdateNameLevel(f)
    local nl = f.nameLevel
    local showName  = f.showName  ~= false
    local showLevel = f.showLevel ~= false

    -- La BARRE reste colorée par la classe / réaction.
    f.health:SetStatusBarColor(U.GetReactionColor(f.unit))

    if not showName and not showLevel then nl:SetText(""); return end

    local name = UnitName(f.unit)
    local nameSecret = issecretvalue and issecretvalue(name)
    -- Nom requis mais transitoirement absent (nil / "") -> on garde l'affichage.
    if showName and (not name or (not nameSecret and name == "")) then return end

    -- Déblocage du rendu : un FontString peuplé pendant la fenêtre de chargement peut
    -- rester figé invisible, et réécrire la MÊME chaîne est un no-op (aucun re-rendu).
    -- On vide d'abord pour garantir un vrai changement d'état -> le texte se rend enfin.
    nl:SetText("")

    local lvl = UnitLevel(f.unit)
    local lvlSecret = issecretvalue and issecretvalue(lvl)
    -- « || » dans un format = une seule barre « | » (échappement du FontString).
    if showName and showLevel then
        if lvlSecret then
            if not pcall(nl.SetFormattedText, nl, "%s || |cffffd100%d|r", name, lvl) then pcall(nl.SetText, nl, name) end
        else
            local lt = (lvl and lvl > 0) and lvl or "??"
            if not pcall(nl.SetFormattedText, nl, "%s || |cffffd100%s|r", name, tostring(lt)) then pcall(nl.SetText, nl, name) end
        end
    elseif showName then
        pcall(nl.SetText, nl, name)
    else -- niveau seul
        if lvlSecret then
            if not pcall(nl.SetFormattedText, nl, "|cffffd100%d|r", lvl) then nl:SetText("") end
        else
            local lt = (lvl and lvl > 0) and lvl or "??"
            nl:SetText("|cffffd100" .. tostring(lt) .. "|r")
        end
    end
end

-- Déclarée ici, définie plus bas (après la fabrique d'indicateurs) : permet à
-- UpdateAll de la référencer sans dépendre de l'ordre de définition.
local UpdateIndicators

local function UpdateAll(f)
    UpdateNameLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
    if f.classpower then f.classpower.Update() end
    if UpdateIndicators then UpdateIndicators(f) end
end

--------------------------------------------------------------------------------
-- Événements unitaires reçus par le cadre lui-même
--------------------------------------------------------------------------------
local function OnUnitEvent(f, event)
    -- RegisterUnitEvent a déjà filtré par unité : inutile de tester l'unité.
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then
        UpdateHealth(f)
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
        or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f)
    elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" then
        UpdateNameLevel(f)
    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        UpdateIndicators(f) -- PvP (faction) / combat (autres unités)
    elseif event == "UNIT_TARGET" then
        -- La cible a changé de cible -> la cible-de-cible désigne une autre unité.
        UpdateAll(f)
    end
end

--------------------------------------------------------------------------------
-- Fabrique d'une barre arrondie : fond noir + bordure 1px + StatusBar + fond des
-- valeurs manquantes, coins arrondis via masque. Renvoie la StatusBar. Réutilisée
-- pour la vie et la ressource (et, plus tard, la cible).
--------------------------------------------------------------------------------
-- Applique/mets à jour le STYLE d'une barre : opacité du fond + coins arrondis.
-- (Pas de contour : incompatible proprement avec les coins arrondis.) Le fond n'a
-- RIEN d'opaque derrière -> peut devenir réellement transparent à 0 %.
local function StyleBar(bar, style)
    style = style or {}
    local bgAlpha = style.bgAlpha; if bgAlpha == nil then bgAlpha = 0.5 end
    local rounded = style.rounded ~= false

    -- Fond (portion vide) : 0 = rien (transparent), 0.5 = gris, 1 = noir.
    local g, a
    if bgAlpha <= 0.5 then a = bgAlpha * 2; g = 0.15
    else a = 1; g = 0.15 * (1 - (bgAlpha - 0.5) * 2) end
    bar.backdrop:SetVertexColor(g, g, g, a)

    -- Arrondi : masque = image ronde ; carré = masque plein (FLAT = tout visible).
    local tex = rounded and bar.maskPath or FLAT
    bar.mask:SetTexture(tex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
end

local function CreateBar(container, maskPath, style)
    -- Fond (portion vide) : couvre tout le conteneur, opacité réglable, RIEN d'opaque
    -- derrière -> peut devenir transparent.
    local backdrop = container:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture(FLAT)
    backdrop:SetVertexColor(0.15, 0.15, 0.15, 1)
    backdrop:SetAllPoints(container)

    -- Barre (remplissage) : remplit le conteneur.
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetStatusBarTexture(FLAT)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    bar:SetAllPoints(container)

    -- Masque arrondi commun (fond + remplissage).
    local mask = container:CreateMaskTexture(); mask:SetAllPoints(container)
    backdrop:AddMaskTexture(mask)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    bar.backdrop, bar.mask = backdrop, mask
    bar.barContainer, bar.maskPath = container, maskPath
    StyleBar(bar, style) -- opacité + arrondi initiaux
    return bar
end

-- La ZONE DE CLIC (hit rect du cadre-bouton, taille = vie de base) suit l'élément
-- vie : on ajuste ses marges pour coller à la barre déplacée (x/y) et mise à
-- l'échelle (scale), sans toucher aux autres éléments (ancrés au cadre, eux fixes).
-- Marges négatives = zone agrandie (échelle > 1). En coords locales du cadre.
local function UpdateHealthClickRegion(f, h)
    local hw, hh, hs = h.width, h.height, h.scale or 1
    local hx, hy = h.x or 0, h.y or 0
    f:SetHitRectInsets(
        hw * (1 - hs) / 2 + hx,   -- gauche
        hw * (1 - hs) / 2 - hx,   -- droite
        hh * (1 - hs) / 2 - hy,   -- haut
        hh * (1 - hs) / 2 + hy)   -- bas
end

-- Applique la disposition (normale, ou inversée « miroir » pour la cible) : sens
-- de remplissage des barres + ancrage des textes. Extrait pour pouvoir la
-- basculer à chaud depuis le menu d'options.
-- Ancre du texte nom/niveau : 9 positions dans la barre de vie {point, x, y, justif}.
local NAME_ANCHORS = {
    TOPLEFT     = { "TOPLEFT",      8, -6, "LEFT" },
    TOP         = { "TOP",          0, -6, "CENTER" },
    TOPRIGHT    = { "TOPRIGHT",    -8, -6, "RIGHT" },
    LEFT        = { "LEFT",         8,  0, "LEFT" },
    CENTER      = { "CENTER",       0,  0, "CENTER" },
    RIGHT       = { "RIGHT",       -8,  0, "RIGHT" },
    BOTTOMLEFT  = { "BOTTOMLEFT",   8,  6, "LEFT" },
    BOTTOM      = { "BOTTOM",       0,  6, "CENTER" },
    BOTTOMRIGHT = { "BOTTOMRIGHT", -8,  6, "RIGHT" },
}
local function AnchorTextTo(fs, health, pos)
    local a = NAME_ANCHORS[pos] or NAME_ANCHORS.TOPLEFT
    fs:ClearAllPoints()
    fs:SetPoint(a[1], health, a[1], a[2], a[3])
    fs:SetJustifyH(a[4])
end

-- Applique l'orientation (sens de remplissage + ancres de texte). Le sens ne dépend
-- QUE de `reverse` par élément (dont le défaut est le miroir de l'unité). Le param
-- `mirror` est conservé pour compat mais n'est plus utilisé pour le sens.
local function ApplyMirror(f, mirror)
    local uf = ns.db.unitframes[f.unit]
    local h, p = uf.health, uf.power
    f.health:SetReverseFill(h and h.reverse == true)
    f.power:SetReverseFill(p and p.reverse == true)
    AnchorTextTo(f.nameLevel, f.health, h and h.namePos or "TOPLEFT")
    AnchorTextTo(f.hpText, f.health, h and h.valuePos or "BOTTOMRIGHT")
    if f.powerText then AnchorTextTo(f.powerText, f.power, p and p.valuePos or "CENTER") end
end

-- Re-crée à neuf le FontString nom/niveau. Un FontString peuplé pendant la fenêtre de
-- chargement peut rester "figé" invisible (cf. UpdateNameLevel) ; un FontString créé
-- APRÈS cette fenêtre s'affiche de façon fiable. Appelé une fois, peu après l'entrée en
-- jeu, pour garantir des noms visibles sur tous les cadres — surtout cible/focus/ToT,
-- dont le nom n'est peuplé qu'à l'acquisition de l'unité.
local function RebuildNameLevel(f)
    local old = f.nameLevel
    local nl = f.health:CreateFontString(nil, "OVERLAY")
    ApplyFont(nl, 11, "OUTLINE")
    nl:SetWordWrap(false)
    nl:SetTextColor(1, 1, 1)
    f.nameLevel = nl
    if old then old:Hide() end
    local uf = ns.db.unitframes[f.unit]
    AnchorTextTo(nl, f.health, (uf and uf.health and uf.health.namePos) or "TOPLEFT")
    UpdateNameLevel(f)
end

--------------------------------------------------------------------------------
-- Barre d'incantation (castbar)
-- Les timings de cast peuvent être SECRETS en 12.0 (surtout ennemis, anti-
-- automatisation d'interruption). On ne compare/calcule JAMAIS start/end côté
-- Lua : on les donne à SetMinMaxValues (qui accepte les secrets) et on avance la
-- valeur en OnUpdate avec GetTime() (non secret) -> le moteur calcule le
-- remplissage. Détection du cast via le nom (1er retour), jamais comparé. Nom/icône
-- (possiblement secrets) passés aux widgets sous garde.
--------------------------------------------------------------------------------
local CAST_COLOR    = { 0.90, 0.65, 0.10 } -- incantation (or)
local CHANNEL_COLOR = { 0.20, 0.55, 0.90 } -- canalisation (bleu)
local LOCK_COLOR    = { 0.55, 0.55, 0.55 } -- non interruptible (gris)

local function CastColor(cbc, interruptible)
    local c = cbc.channel and CHANNEL_COLOR or CAST_COLOR
    if interruptible == false then c = LOCK_COLOR end
    cbc.bar:SetStatusBarColor(c[1], c[2], c[3])
end

-- OnUpdate de la castbar : branché UNIQUEMENT pendant un cast (voir StartCast/StopCast),
-- donc zéro coût à l'arrêt. Le remplissage suit le temps courant (non secret) chaque
-- frame — peu coûteux. Le texte du timer n'est reformaté qu'~10x/s : son affichage en
-- %.1f ne change pas plus vite, inutile de faire un string.format à chaque frame.
local function CastOnUpdate(self, elapsed)
    -- Remplissage throttlé à ~50 fps : fluide à l'œil, mais évite les appels superflus sur
    -- écran haute fréquence (120-144 Hz) où l'on rendrait bien plus que nécessaire.
    self.fillAccum = (self.fillAccum or 0) + elapsed
    if self.fillAccum >= 0.02 then
        self.fillAccum = 0
        self.bar:SetValue(GetTime() * 1000)
    end
    -- Timer : reformaté ~10x/s seulement (l'affichage %.1f ne change pas plus vite).
    if self.secretTime or not self.endMs then return end
    self.timerAccum = (self.timerAccum or 0) + elapsed
    if self.timerAccum < 0.1 then return end
    self.timerAccum = 0
    local rem = (self.endMs - GetTime() * 1000) / 1000
    self.timerText:SetText(string.format("%.1f", rem > 0 and rem or 0))
end

-- Démarre l'affichage d'un cast/canalisation. Renvoie true si un cast est en
-- cours, false sinon (détection via le nom, 1er retour, jamais comparé).
local function StartCast(cbc, channel)
    if not cbc.enabled then return false end
    local u = cbc.unit
    local name, disp, tex, startMs, endMs, notInt, _
    if channel then
        name, disp, tex, startMs, endMs, _, notInt = UnitChannelInfo(u)
    else
        name, disp, tex, startMs, endMs, _, _, notInt = UnitCastingInfo(u)
    end
    -- Détection secret-safe : le nom (1er retour) est nil hors incantation, présent
    -- (ou secret) pendant. « not name » est autorisé sur un secret (coercion booléenne).
    if not name then return false end

    cbc.channel = channel and true or false
    cbc.casting = true
    cbc.bar:SetReverseFill(cbc.channel ~= (cbc.reverse == true)) -- canal inverse le sens, + réglage user

    -- Timings (possiblement secrets) -> passés tels quels au widget, jamais comparés.
    pcall(cbc.bar.SetMinMaxValues, cbc.bar, startMs, endMs)
    local initVal = startMs
    if cbc.channel then initVal = endMs end
    pcall(cbc.bar.SetValue, cbc.bar, initVal)
    -- Timer : on mémorise endMs (décompte en OnUpdate) ; masqué si le timing est secret.
    cbc.endMs = endMs
    cbc.secretTime = (issecretvalue and issecretvalue(endMs)) and true or false
    if cbc.secretTime then cbc.timerText:SetText("") end

    -- Couleur : « non interruptible » seulement si LISIBLE (sinon couleur normale).
    local interruptible = true
    if issecretvalue and issecretvalue(notInt) then
        interruptible = true
    elseif notInt then
        interruptible = false
    end
    CastColor(cbc, interruptible)

    -- Nom + icône (possiblement secrets) -> widgets, sous garde.
    if not pcall(cbc.nameText.SetText, cbc.nameText, disp) then cbc.nameText:SetText("") end
    pcall(cbc.icon.SetTexture, cbc.icon, tex)

    cbc.timerAccum = 0
    cbc.fillAccum = 0
    cbc:SetScript("OnUpdate", CastOnUpdate) -- boucle active seulement pendant le cast
    cbc:Show()
    return true
end

local function StopCast(cbc)
    cbc.casting = false
    cbc:SetScript("OnUpdate", nil) -- coupe la boucle par-frame quand il n'y a plus de cast
    cbc:Hide()
end

-- Ré-évalue l'état de cast courant (changement de cible, création).
local function RefreshCast(cbc)
    if cbc.preview then return end -- l'aperçu prime sur l'état réel
    if StartCast(cbc, false) then return end
    if StartCast(cbc, true) then return end
    StopCast(cbc)
end

-- Poll pour tokens dérivés sans events de cast fiables (ex. targettarget) : affiche
-- un NOUVEAU cast, masque à la fin, mais ne réinitialise PAS un cast déjà en cours
-- (sinon la barre sauterait au début à chaque tick).
local function PollCast(cbc)
    if cbc.preview or not cbc.enabled then return end
    local casting = UnitCastingInfo(cbc.unit) or UnitChannelInfo(cbc.unit)
    if casting then
        if not cbc.casting then RefreshCast(cbc) end
    elseif cbc.casting then
        StopCast(cbc)
    end
end

-- Aperçu : affiche une incantation factice pour régler le style hors combat.
local function ShowCastPreview(cbc)
    cbc.casting = false
    cbc:SetScript("OnUpdate", nil) -- aperçu figé : pas de boucle par-frame
    cbc.channel = false
    cbc.secretTime = false
    cbc.bar:SetReverseFill(cbc.reverse or false)
    cbc.bar:SetMinMaxValues(0, 1)
    cbc.bar:SetValue(0.6)
    CastColor(cbc, true)
    cbc.nameText:SetText("Aperçu")
    cbc.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    cbc.timerText:SetText("1.5")
    cbc:Show()
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function OnCastEvent(cbc, event)
    if cbc.preview then return end -- en aperçu : on ignore les vrais casts
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        StartCast(cbc, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        StartCast(cbc, true)
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        CastColor(cbc, true)
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        CastColor(cbc, false)
    else -- STOP / CHANNEL_STOP / EMPOWER_STOP / FAILED / INTERRUPTED
        StopCast(cbc)
    end
end

-- Dispose icône / nom / timer selon le sens : normal = icône à gauche, timer à
-- droite ; inversé = icône à droite, timer à gauche (nom au milieu dans les deux cas).
local function LayoutCastInfo(cbc)
    local bar, icon, nm, tmr = cbc.bar, cbc.icon, cbc.nameText, cbc.timerText
    icon:ClearAllPoints(); tmr:ClearAllPoints(); nm:ClearAllPoints()
    if cbc.reverse then
        icon:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
        tmr:SetPoint("LEFT", bar, "LEFT", 5, 0); tmr:SetJustifyH("LEFT")
        nm:SetPoint("RIGHT", icon, "LEFT", -5, 0)
        nm:SetPoint("LEFT", tmr, "RIGHT", 5, 0); nm:SetJustifyH("RIGHT")
    else
        icon:SetPoint("LEFT", bar, "LEFT", 3, 0)
        tmr:SetPoint("RIGHT", bar, "RIGHT", -5, 0); tmr:SetJustifyH("RIGHT")
        nm:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        nm:SetPoint("RIGHT", tmr, "LEFT", -5, 0); nm:SetJustifyH("LEFT")
    end
end

-- Construit la castbar (conteneur + icône + barre + nom). Position/taille en
-- ApplyConfig. Cachée au repos, affichée pendant un cast.
local function CreateCastbar(f, unit, cfg)
    local cbc = CreateFrame("Frame", nil, f)
    cbc.unit = unit
    cbc.enabled = cfg.castbar.enabled ~= false
    cbc.reverse = cfg.castbar.reverse == true
    cbc:SetSize(cfg.castbar.width or cfg.health.width, cfg.castbar.height)

    -- Barre arrondie (même fabrique, avec style). La progression du cast = remplissage.
    local bar = CreateBar(cbc, MASK_THIN, cfg.castbar)
    cbc.bar = bar

    -- Icône du sort : petit carré légèrement arrondi (position posée par LayoutCastInfo).
    local isz = cfg.castbar.height - 5
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(isz, isz)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- rogne la bordure de l'icône
    local imask = cbc:CreateMaskTexture()
    imask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    imask:SetAllPoints(icon)
    icon:AddMaskTexture(imask)
    cbc.icon = icon

    -- Timer (temps restant).
    local tmr = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(tmr, 10, "OUTLINE")
    tmr:SetTextColor(1, 1, 1)
    cbc.timerText = tmr

    -- Nom du sort (entre l'icône et le timer).
    local nm = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(nm, 10, "OUTLINE")
    nm:SetWordWrap(false); nm:SetTextColor(1, 1, 1)
    cbc.nameText = nm

    LayoutCastInfo(cbc) -- dispose icône/nom/timer selon le sens


    cbc:SetScript("OnEvent", OnCastEvent)
    for _, ev in ipairs(CAST_EVENTS) do
        pcall(cbc.RegisterUnitEvent, cbc, ev, unit) -- pcall : certains events peuvent manquer
    end
    -- L'OnUpdate (remplissage + timer) n'est branché que pendant un cast, via
    -- StartCast/StopCast (voir CastOnUpdate) : aucune boucle par-frame à l'arrêt.

    cbc.Refresh = function() RefreshCast(cbc) end
    cbc:Hide()
    return cbc
end

--------------------------------------------------------------------------------
-- Ressource de classe (points de combo, puissance sacrée, fragments d'âme…)
-- Joueur uniquement. Barre SEGMENTÉE au-dessus de la vie : une seule StatusBar
-- remplie par le moteur (SetValue accepte les valeurs secrètes) + des séparateurs
-- verticaux posés depuis UnitPowerMax (LISIBLE pour le joueur, non restreint).
-- Secret-safe : on ne compare/calcule JAMAIS la valeur courante, on la passe au
-- widget ; seul UnitPowerMax (nombre de segments, lisible) sert au placement.
--------------------------------------------------------------------------------
local PT = Enum and Enum.PowerType

-- Type de ressource + couleur par classe. La VISIBILITÉ se décide sur la lisibilité
-- de UnitPowerMax (> 0) : gère seule les spés sans ressource (mage Feu, moine MW…).
-- Druide (points de combo en forme féline) et Chevalier de la mort (runes =
-- cooldown, pas des pips) sont traités dans une itération ultérieure.
local CLASS_POWER = PT and {
    ROGUE   = { power = PT.ComboPoints,   color = { 0.90, 0.22, 0.30 } },
    PALADIN = { power = PT.HolyPower,      color = { 0.95, 0.90, 0.55 } },
    WARLOCK = { power = PT.SoulShards,     color = { 0.62, 0.42, 0.92 } },
    MONK    = { power = PT.Chi,            color = { 0.42, 0.90, 0.62 } },
    MAGE    = { power = PT.ArcaneCharges,  color = { 0.42, 0.62, 0.95 } },
    EVOKER  = { power = PT.Essence,        color = { 0.30, 0.80, 0.75 } },
} or {}

-- (Re)pose les séparateurs verticaux pour `max` segments. Placement calculé en Lua
-- depuis `max` (entier LISIBLE) : aucune opération sur la valeur courante (secrète).
local function LayoutDividers(cpc, max)
    local w = (cpc.width or cpc:GetWidth()) -- la barre remplit tout le conteneur
    cpc.dividers = cpc.dividers or {}
    for i = 1, max - 1 do
        local d = cpc.dividers[i]
        if not d then
            d = cpc.bar:CreateTexture(nil, "OVERLAY")
            d:SetTexture(FLAT)
            d:SetVertexColor(0, 0, 0, 0.9)
            d:SetWidth(2)
            cpc.dividers[i] = d
        end
        local x = w * i / max
        d:ClearAllPoints()
        d:SetPoint("TOP", cpc.bar, "TOPLEFT", x, 0)
        d:SetPoint("BOTTOM", cpc.bar, "BOTTOMLEFT", x, 0)
        d:Show()
    end
    -- Masque les séparateurs en trop (max a diminué : talent, changement de spé).
    for i = max, #cpc.dividers do
        if cpc.dividers[i] then cpc.dividers[i]:Hide() end
    end
end

local function UpdateClassPower(cpc)
    if not cpc.enabled then cpc:Hide(); return end
    local max = UnitPowerMax("player", cpc.powerType)
    -- max secret (ne devrait pas arriver pour le joueur) ou nul/absent -> pas de
    -- ressource pour cette spé/classe -> on masque la barre.
    if (issecretvalue and issecretvalue(max)) or not max or max <= 0 then
        cpc:Hide()
        return
    end
    cpc:Show()
    if max ~= cpc.lastMax then
        cpc.lastMax = max
        LayoutDividers(cpc, max)
    end
    -- Valeur courante (possiblement secrète) : passée telle quelle, jamais comparée.
    -- Le moteur remplit la barre ; les séparateurs la découpent visuellement en pips.
    cpc.bar:SetMinMaxValues(0, max)
    if cpc.preview then
        cpc.bar:SetValue(max / 2) -- aperçu : moitié des segments remplis
    else
        cpc.bar:SetValue(UnitPower("player", cpc.powerType), SMOOTH)
    end
end

local CLASS_POWER_EVENTS = {
    "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
}

-- Construit la barre de ressource de classe (joueur). Renvoie nil si la classe n'a
-- pas de ressource ponctuelle gérée (guerrier, chasseur, druide/DK reportés…).
local function CreateClassPower(f, cfg)
    local info = CLASS_POWER[f.playerClass]
    if not info or not info.power then return nil end

    local cpc = CreateFrame("Frame", nil, f)
    cpc.powerType = info.power
    cpc.enabled   = cfg.classpower.enabled ~= false
    cpc.width     = cfg.classpower.width or cfg.health.width
    cpc:SetSize(cpc.width, cfg.classpower.height)

    -- Barre arrondie (même fabrique que vie/ressource, avec style).
    local bar = CreateBar(cpc, MASK_THIN, cfg.classpower)
    bar:SetStatusBarColor(info.color[1], info.color[2], info.color[3])
    cpc.bar = bar

    cpc:SetScript("OnEvent", function(self) UpdateClassPower(self) end)
    for _, ev in ipairs(CLASS_POWER_EVENTS) do
        pcall(cpc.RegisterUnitEvent, cpc, ev, "player") -- pcall : event possiblement absent
    end
    -- Changement de spé : la ressource peut apparaître/disparaître (mage Arcane,
    -- moine WW…). Événement broadcast (sans unité) -> ré-évaluation complète.
    ns.EventBus:Register("PLAYER_SPECIALIZATION_CHANGED", function() UpdateClassPower(cpc) end)

    -- Méthode publique (référence de table, résolue au runtime) : évite le piège de
    -- portée locale depuis UpdateAll/ApplyConfig définis plus haut/plus bas.
    cpc.Update = function() UpdateClassPower(cpc) end
    cpc:Hide()
    return cpc
end

--------------------------------------------------------------------------------
-- Indicateurs d'état (positions FIXES, non configurables)
-- Petites icônes posées autour de la barre de vie : marqueur de raid, rôle, chef,
-- PvP, combat. Chaque état peut être une valeur SECRÈTE en 12.0 (combat / PvP sur
-- une cible ennemie surtout). Règle de sûreté : on ne compare/évalue JAMAIS un
-- booléen secret (ça planterait) ; en cas de secret ou d'erreur d'API, on MASQUE
-- l'icône. Les infos de groupe (rôle / chef) et le marqueur de raid ne sont pas
-- tactiques, mais on les blinde de la même façon par précaution.
--------------------------------------------------------------------------------
local ROLE_TEX   = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local LEADER_TEX = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ASSIST_TEX = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local PVP_H_TEX  = "Interface\\TargetingFrame\\UI-PVP-Horde"
local PVP_A_TEX  = "Interface\\TargetingFrame\\UI-PVP-Alliance"
local PVP_F_TEX  = "Interface\\TargetingFrame\\UI-PVP-FFA"
local COMBAT_TEX = "Interface\\CharacterFrame\\UI-StateIcon"

-- Lit un booléen d'unité en toute sécurité. Renvoie true / false, ou nil si l'API
-- échoue OU si la valeur est SECRÈTE (on ne peut alors rien en déduire -> masquer).
local function SafeBool(fn, unit)
    if not fn then return nil end
    local ok, v = pcall(fn, unit)
    if not ok then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v and true or false
end

-- --- Mises à jour par indicateur (chacune décide Show/Hide de sa texture) --------
-- Marqueur de raid. En 12.0, GetRaidTargetIndex renvoie une valeur SECRÈTE : on ne
-- peut ni la comparer ni la concaténer dans un chemin de fichier. Contournement
-- secret-safe : un FontString avec un escape texture inline « |T...Icon_%d:t|t »
-- rempli par SetFormattedText -> le %d est substitué CÔTÉ MOTEUR (comme pour les PV),
-- ce qui insère le bon fichier de marqueur sans jamais exposer l'index à Lua. On
-- utilise les fichiers INDIVIDUELS UI-RaidTargetingIcon_1..8 (la grille
-- UI-RaidTargetingIcons ne se charge plus en 12.0).
local function UpdIndRaidMark(f, fs)
    local idx = GetRaidTargetIndex and GetRaidTargetIndex(f.unit)
    local secret = issecretvalue and issecretvalue(idx)
    -- Absent (et lisible) : rien à afficher. Si secret, on ne teste PAS `not idx`
    -- (interdit sur un secret) : on passe directement au rendu via le moteur.
    if not secret and not idx then fs:SetText(""); fs:Hide(); return end
    if pcall(fs.SetFormattedText, fs, fs.markFmt, idx) then
        fs:Show()
    else
        fs:SetText(""); fs:Hide()
    end
end

local function UpdIndRole(f, tex)
    local ok, role = pcall(UnitGroupRolesAssigned, f.unit)
    if not ok or (issecretvalue and issecretvalue(role)) then tex:Hide(); return end
    if (role == "TANK" or role == "HEALER" or role == "DAMAGER") and GetTexCoordsForRoleSmallCircle then
        tex:SetTexture(ROLE_TEX)
        tex:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
        tex:Show()
    else
        tex:Hide()
    end
end

local function UpdIndLeader(f, tex)
    if SafeBool(UnitIsGroupLeader, f.unit) then
        tex:SetTexture(LEADER_TEX); tex:SetTexCoord(0, 1, 0, 1); tex:Show(); return
    end
    if SafeBool(UnitIsGroupAssistant, f.unit) then
        tex:SetTexture(ASSIST_TEX); tex:SetTexCoord(0, 1, 0, 1); tex:Show(); return
    end
    tex:Hide()
end

local function UpdIndPvP(f, tex)
    if not SafeBool(UnitIsPVP, f.unit) then tex:Hide(); return end
    tex:SetTexCoord(0, 0.65625, 0, 0.65625) -- rogne le large padding transparent
    if SafeBool(UnitIsPVPFreeForAll, f.unit) then
        tex:SetTexture(PVP_F_TEX); tex:Show(); return
    end
    local ok, faction = pcall(UnitFactionGroup, f.unit)
    if not ok or (issecretvalue and issecretvalue(faction)) then tex:Hide(); return end
    if faction == "Horde" then
        tex:SetTexture(PVP_H_TEX); tex:Show()
    elseif faction == "Alliance" then
        tex:SetTexture(PVP_A_TEX); tex:Show()
    else
        tex:Hide()
    end
end

local function UpdIndCombat(f, tex)
    -- Pour soi, l'info est fiable et jamais secrète ; pour les autres, elle peut
    -- l'être (anti-automatisation) -> SafeBool masque en cas de secret.
    local inCombat
    if f.unit == "player" then
        inCombat = UnitAffectingCombat("player") and true or false
    else
        inCombat = SafeBool(UnitAffectingCombat, f.unit)
    end
    if inCombat then
        tex:SetTexture(COMBAT_TEX); tex:SetTexCoord(0.5, 1.0, 0.0, 0.49); tex:Show()
    else
        tex:Hide()
    end
end

-- Description des indicateurs : point d'ancrage FIXE (relatif à la barre de vie),
-- taille, et fonction de mise à jour. La rangée chef | marqueur | rôle se pose
-- au-dessus de la barre ; PvP à gauche, combat à droite (hors de la barre).
local INDICATORS = {
    -- Chef : à gauche, au niveau du nom (coin haut-gauche extérieur).
    { key = "leader",   size = 16, point = "RIGHT",  rel = "TOPLEFT", x = -2, y = -8, update = UpdIndLeader },
    -- Marqueur de raid : au-dessus, centré. `text` = rendu via FontString (escape
    -- texture inline) pour rester compatible avec l'index SECRET de la 12.0.
    { key = "raidmark", size = 15, point = "CENTER", rel = "TOP",     x =  0, y = -11, text = true, update = UpdIndRaidMark },
    -- Rôle : à droite, au milieu (symétrique du PvP).
    { key = "role",     size = 16, point = "LEFT",   rel = "RIGHT",   x =  2, y =  0, update = UpdIndRole },
    -- PvP : coin gauche DANS la barre, sous le nom.
    { key = "pvp",      size = 24, point = "LEFT",   rel = "LEFT",    x =  2, y = -6, update = UpdIndPvP },
    -- Combat : au centre de la barre de vie.
    { key = "combat",   size = 30, point = "CENTER", rel = "CENTER",  x =  0, y =  0, update = UpdIndCombat },
}

-- Construit les textures d'indicateurs (enfants de la barre de vie -> suivent son
-- échelle/position). OVERLAY sublevel élevé : au-dessus du remplissage et du texte.
local function CreateIndicators(f)
    -- Calque dédié au frame level élevé : garantit que les indicateurs passent
    -- DEVANT les autres éléments qui occupent la même zone (barre de ressource de
    -- classe au-dessus de la vie, castbar…). Enfant de la barre de vie -> suit son
    -- échelle et sa position.
    local layer = CreateFrame("Frame", nil, f.health)
    layer:SetAllPoints(f.health)
    layer:SetFrameLevel(f.health:GetFrameLevel() + 10)
    f.indicatorLayer = layer

    f.indicators = {}
    for _, spec in ipairs(INDICATORS) do
        local w
        if spec.text then
            -- FontString : porte une icône inline via un escape texture (secret-safe).
            w = layer:CreateFontString(nil, "OVERLAY")
            ApplyFont(w, spec.size)
            w:SetJustifyH("CENTER")
            -- Format pré-calculé : taille FIXE (non secrète) + %d pour l'index (secret).
            w.markFmt = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:"
                .. spec.size .. ":" .. spec.size .. "|t"
        else
            w = layer:CreateTexture(nil, "OVERLAY", nil, 7)
            w:SetSize(spec.size, spec.size)
        end
        w:SetPoint(spec.point, f.health, spec.rel, spec.x, spec.y)
        w:Hide()
        f.indicators[spec.key] = w
    end
end

-- (déclarée en forward plus haut pour UpdateAll : pas de `local` ici)
function UpdateIndicators(f)
    if not f.indicators then return end
    -- Unité absente (hors le joueur, toujours présent) : tout masquer d'un coup.
    if f.unit ~= "player" and not UnitExists(f.unit) then
        for _, tex in pairs(f.indicators) do tex:Hide() end
        return
    end
    for _, spec in ipairs(INDICATORS) do
        spec.update(f, f.indicators[spec.key])
    end
end

--------------------------------------------------------------------------------
-- Fabrique : construit un cadre d'unité complet à partir d'une config
--------------------------------------------------------------------------------
local function CreateUnitFrame(unit, cfg)
    local frameName = "BravUI_" .. unit:sub(1, 1):upper() .. unit:sub(2) .. "Frame"
    local f = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate")
    f.unit = unit
    f:SetSize(cfg.health.width, cfg.health.height)
    local ufScale = cfg.scale or 1
    f:SetScale(ufScale) -- échelle globale du cadre (vie + ressource + classe…)
    -- Offset DIVISÉ par l'échelle : l'offset d'un SetPoint est en coordonnées locales
    -- (donc mises à l'échelle) -> sans ça le cadre dériverait en changeant de taille.
    f:SetPoint("CENTER", UIParent, "CENTER", cfg.x / ufScale, cfg.y / ufScale)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    -- Interaction sécurisée : clic gauche = cibler, clic droit = menu contextuel.
    -- « togglemenu » ouvre nativement le menu d'unité au curseur à partir de
    -- l'attribut « unit » (aucune fonction maison, entièrement sécurisé).
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    -- Visibilité pilotée par le moteur selon l'existence de l'unité (sécurisé).
    -- Pour « player » le cadre est toujours affiché ; ce pilotage servira surtout
    -- lorsque la cible sera ajoutée.
    RegisterUnitWatch(f)

    -- Barre de VIE : élément INDÉPENDANT (conteneur propre centré dans le cadre-
    -- bouton). Par défaut il remplit le cadre (offset 0, même taille) -> rendu
    -- identique ; mais échelle/offset/style se règlent séparément. Le cadre-bouton
    -- (f) reste la zone cliquable.
    local hc = CreateFrame("Frame", nil, f)
    hc:SetPoint("CENTER", f, "CENTER", cfg.health.x or 0, cfg.health.y or 0)
    hc:SetSize(cfg.health.width, cfg.health.height)
    hc:SetScale(cfg.health.scale or 1)
    hc:SetShown(cfg.health.enabled ~= false)
    f.healthContainer = hc
    local health = CreateBar(hc, MASK, cfg.health)
    f.health = health
    UpdateHealthClickRegion(f, cfg.health) -- la zone de clic épouse la barre de vie

    -- Indicateurs d'état (marqueur de raid, rôle, chef, PvP, combat) : positions
    -- FIXES autour de la barre de vie (non configurables).
    CreateIndicators(f)

    -- « Nom | Lvl » : nom en blanc, niveau en doré (dans UpdateNameLevel). Position
    -- et justification posées par ApplyMirror (selon disposition normale/inversée).
    local nameLevel = health:CreateFontString(nil, "OVERLAY")
    ApplyFont(nameLevel, 11, "OUTLINE")
    nameLevel:SetWordWrap(false)
    nameLevel:SetTextColor(1, 1, 1)
    f.nameLevel = nameLevel

    -- « PV actuel | % actuel » : position posée par ApplyMirror.
    local hpText = health:CreateFontString(nil, "OVERLAY")
    ApplyFont(hpText, 11, "OUTLINE")
    hpText:SetTextColor(1, 1, 1)
    f.hpText = hpText

    -- Barre de RESSOURCE : élément indépendant (conteneur propre, largeur/échelle/
    -- position/style à lui). Défaut : centré sous la vie (offset y calculé).
    local pc = CreateFrame("Frame", nil, f)
    pc:SetSize(cfg.power.width, cfg.power.height)
    pc:SetPoint("CENTER", f, "CENTER", cfg.power.x or 0, cfg.power.y or 0)
    pc:SetScale(cfg.power.scale or 1)
    f.powerContainer = pc
    local power = CreateBar(pc, MASK_THIN, cfg.power)
    f.power = power

    -- Barre d'incantation, sous la ressource.
    local castbar = CreateCastbar(f, unit, cfg)
    castbar:SetPoint("CENTER", f, "CENTER", cfg.castbar.x or 0, cfg.castbar.y or 0)
    castbar:SetScale(cfg.castbar.scale or 1)
    f.castbar = castbar

    -- Ressource de classe (joueur uniquement) : barre segmentée AU-DESSUS de la vie,
    -- ancrage indépendant (ne perturbe pas l'empilement ressource/castbar).
    if unit == "player" then
        f.playerClass = select(2, UnitClass("player")) -- jeton de classe (non secret)
        local cp = CreateClassPower(f, cfg)
        if cp then
            cp:SetPoint("CENTER", f, "CENTER", cfg.classpower.x or 0, cfg.classpower.y or 0)
            cp:SetScale(cfg.classpower.scale or 1)
            f.classpower = cp
        end
    end

    -- Disposition normale (joueur) ou inversée « miroir » (cible).
    ApplyMirror(f, cfg.mirrored == true)

    -- Overlay d'aide au repositionnement (visible seulement en mode déverrouillé).
    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints(f)
    ov:SetFrameLevel(f:GetFrameLevel() + 10)
    local ovTex = ov:CreateTexture(nil, "BACKGROUND")
    ovTex:SetTexture(FLAT)
    ovTex:SetVertexColor(0, 0.8, 1, 0.30)
    ovTex:SetAllPoints()
    local ovTxt = ov:CreateFontString(nil, "OVERLAY")
    ApplyFont(ovTxt, 12, "OUTLINE")
    ovTxt:SetPoint("CENTER")
    ovTxt:SetText(UNIT_LABELS[unit] or unit)
    ov:Hide()
    f.unlockOverlay = ov

    -- Déplacement (activé par le mode déverrouillé du menu d'options).
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if M.unlocked and not InCombatLockdown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Recalcule l'offset depuis le centre de l'écran (ancrage CENTER + x/y).
        -- INSENSIBLE À L'ÉCHELLE : on convertit les centres en pixels écran via les
        -- échelles effectives (sinon un cadre mis à l'échelle sauverait une position
        -- décalée), puis on repasse en coordonnées UIParent pour l'offset.
        local c = ns.db.unitframes[self.unit]
        local es, eu = self:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local sx, sy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if sx and ux then
            c.x = math.floor((sx * es - ux * eu) / eu + 0.5)
            c.y = math.floor((sy * es - uy * eu) / eu + 0.5)
            local sc = self:GetScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", c.x / sc, c.y / sc)
        end
    end)

    -- « ressource actuelle | % actuel » : centré dans la barre de ressource.
    local powerText = power:CreateFontString(nil, "OVERLAY")
    ApplyFont(powerText, 10, "OUTLINE")
    powerText:SetPoint("CENTER", power, "CENTER", 0, 0)
    powerText:SetJustifyH("CENTER")
    powerText:SetTextColor(1, 1, 1)
    f.powerText = powerText

    -- Closures de % créées une fois (stables) : évitent une allocation à chaque
    -- mise à jour, et permettent de tester la disponibilité de l'API (valeur non
    -- secrète) avant l'appel — l'appel, lui, renvoie un secret.
    if UnitHealthPercent and pctCurve then
        f.getHealthPct = function() return UnitHealthPercent(f.unit, false, pctCurve) end
    end
    if UnitPowerPercent and pctCurve then
        f.getPowerPct = function() return UnitPowerPercent(f.unit, nil, false, pctCurve) end
    end

    -- Événements unitaires (filtrés par le moteur pour cette seule unité).
    f:SetScript("OnEvent", OnUnitEvent)
    f:RegisterUnitEvent("UNIT_HEALTH", unit)
    f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    f:RegisterUnitEvent("UNIT_CONNECTION", unit) -- hors ligne / reconnexion
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    f:RegisterUnitEvent("UNIT_LEVEL", unit)
    f:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
    f:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    f:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    f:RegisterUnitEvent("UNIT_FACTION", unit) -- indicateur PvP (drapeau / faction)
    f:RegisterUnitEvent("UNIT_FLAGS", unit)   -- indicateur de combat (autres unités)

    -- Certains tokens changent d'unité (ex. « target ») : un événement broadcast
    -- signale le changement -> rafraîchissement complet du cadre. RegisterUnitWatch
    -- gère, lui, l'affichage/masquage selon l'existence de l'unité.
    local changeEvent = (unit == "target" and "PLAYER_TARGET_CHANGED")
        or (unit == "focus" and "PLAYER_FOCUS_CHANGED")
        or (unit == "targettarget" and "PLAYER_TARGET_CHANGED") or nil
    if changeEvent then
        ns.EventBus:Register(changeEvent, function()
            UpdateAll(f)
            f.castbar.Refresh() -- la nouvelle unité peut être déjà en train d'incanter
        end)
    end

    -- Cible-de-cible : token DÉRIVÉ sans event unitaire fiable (UNIT_HEALTH & co. ne
    -- se déclenchent pas sur « targettarget »). On rafraîchit sur UNIT_TARGET de la
    -- cible (elle a changé de cible) ET via un poll throttlé pour suivre la vie/
    -- ressource. Compromis assumé (le seul cadre qui interroge en boucle, à 0,25 s).
    if unit == "targettarget" then
        f:RegisterUnitEvent("UNIT_TARGET", "target")
        f.pollElapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            self.pollElapsed = self.pollElapsed + dt
            if self.pollElapsed < 0.25 then return end
            self.pollElapsed = 0
            if self:IsShown() then
                UpdateHealth(self)
                UpdatePower(self)
                PollCast(self.castbar) -- events de cast non fiables sur ce token -> poll
            end
        end)
    end

    f.castbar.Refresh() -- capte un cast déjà en cours (ex. reload)
    return f
end

--------------------------------------------------------------------------------
-- (Re)positionnement / dimensionnement depuis la config active
-- SetPoint / SetSize sur un cadre sécurisé sont protégés en combat : on diffère
-- via RunWhenSafe si nécessaire.
--------------------------------------------------------------------------------
local function ApplyConfig(f, cfg)
    U.RunWhenSafe(function()
        local ufScale = cfg.scale or 1
        f:ClearAllPoints()
        f:SetScale(ufScale) -- échelle globale du cadre
        -- Offset / échelle (coords locales mises à l'échelle) -> pas de dérive.
        f:SetPoint("CENTER", UIParent, "CENTER", cfg.x / ufScale, cfg.y / ufScale)
        f:SetSize(cfg.health.width, cfg.health.height)
        -- Élément VIE indépendant : place/taille/échelle/activation + style (contour,
        -- opacité de fond, arrondi), tout modifiable à chaud depuis le menu.
        if f.healthContainer then
            local h = cfg.health
            f.healthContainer:ClearAllPoints()
            f.healthContainer:SetPoint("CENTER", f, "CENTER", h.x or 0, h.y or 0)
            f.healthContainer:SetSize(h.width, h.height)
            f.healthContainer:SetScale(h.scale or 1)
            f.healthContainer:SetShown(h.enabled ~= false)
            StyleBar(f.health, h)
            UpdateHealthClickRegion(f, h) -- la zone de clic suit la barre de vie
            f.showName  = h.showName    -- affichage nom / niveau (repris par UpdateNameLevel)
            f.showLevel = h.showLevel
            f.showHP  = h.showHP        -- affichage PV / % (repris par UpdateHealth)
            f.showPct = h.showPct
            f.hpText:SetShown((h.showHP ~= false) or (h.showPct ~= false))
        end
        if f.powerContainer then
            local p = cfg.power
            f.powerContainer:ClearAllPoints()
            f.powerContainer:SetPoint("CENTER", f, "CENTER", p.x or 0, p.y or 0)
            f.powerContainer:SetSize(p.width, p.height)
            f.powerContainer:SetScale(p.scale or 1)
            StyleBar(f.power, p)
            f.powerEnabled = p.enabled ~= false
            f.powerShowVal = p.showVal
            f.powerShowPct = p.showPct
        end
        if f.castbar then
            local cb = cfg.castbar
            f.castbar:ClearAllPoints()
            f.castbar:SetPoint("CENTER", f, "CENTER", cb.x or 0, cb.y or 0)
            f.castbar:SetSize(cb.width, cb.height)
            f.castbar:SetScale(cb.scale or 1)
            StyleBar(f.castbar.bar, cb)
            f.castbar.reverse = cb.reverse == true
            LayoutCastInfo(f.castbar) -- icône/nom/timer selon le sens
            f.castbar.icon:SetSize(cb.height - 5, cb.height - 5)
            f.castbar.icon:SetShown(cb.showIcon ~= false)
            f.castbar.nameText:SetShown(cb.showName ~= false)
            f.castbar.timerText:SetShown(cb.showTimer ~= false)
            f.castbar.enabled = cb.enabled ~= false
            if not f.castbar.enabled then
                f.castbar.casting = false; f.castbar.preview = false; f.castbar:Hide()
            elseif f.castbar.preview then
                ShowCastPreview(f.castbar)
            else
                f.castbar.Refresh()
            end
        end
        if f.classpower then
            local cp = cfg.classpower
            f.classpower:ClearAllPoints()
            f.classpower:SetPoint("CENTER", f, "CENTER", cp.x or 0, cp.y or 0)
            f.classpower:SetSize(cp.width, cp.height)
            f.classpower:SetScale(cp.scale or 1)
            f.classpower.width = cp.width
            f.classpower.enabled = cp.enabled ~= false
            StyleBar(f.classpower.bar, cp)
            f.classpower.bar:SetReverseFill(cp.reverse == true)
            f.classpower.lastMax = nil -- taille/largeur changées -> replacer les séparateurs
            f.classpower.Update()
        end
        -- Activation : masque tout le cadre si désactivé (pilotage sécurisé).
        if cfg.enabled == false then
            UnregisterUnitWatch(f)
            f:Hide()
        else
            RegisterUnitWatch(f)
        end
    end)
end

--------------------------------------------------------------------------------
-- Masquage des cadres Blizzard natifs remplacés par BravUI (joueur / cible / focus
-- / ToT + castbar joueur). On désenregistre les events et on réparente vers un
-- cadre TOUJOURS caché -> ils restent invisibles sans hook et sans risque combat
-- (le parent masqué prime, quel que soit leur propre Show). Fait une seule fois.
--------------------------------------------------------------------------------
local blizzHidden
local function HideBlizzardFrames()
    if M.blizzHidden then return end
    M.blizzHidden = true
    blizzHidden = CreateFrame("Frame"); blizzHidden:Hide()
    local function kill(fr)
        if not fr then return end
        fr:UnregisterAllEvents()
        fr:Hide()
        fr:SetParent(blizzHidden)
    end
    kill(PlayerFrame)
    kill(TargetFrame)          -- inclut la ToT (TargetFrameToT) et la castbar cible
    kill(FocusFrame)           -- inclut la castbar focus
    kill(PlayerCastingBarFrame or CastingBarFrame) -- castbar du joueur
end

--------------------------------------------------------------------------------
-- Cycle de vie du module
--------------------------------------------------------------------------------
function M:OnEnable()
    self.frames = self.frames or {}
    U.RunWhenSafe(HideBlizzardFrames) -- cacher les cadres Blizzard (différé hors combat)

    for _, unit in ipairs(UNITS) do
        local f = self.frames[unit]
        if not f then
            f = CreateUnitFrame(unit, ns.db.unitframes[unit])
            self.frames[unit] = f
        else
            RegisterUnitWatch(f) -- réactivation (cas rare) : re-piloter la visibilité
        end
        UpdateAll(f) -- première population (ou rafraîchissement à la réactivation)
    end

    -- Rafraîchissement complet à chaque (re)entrée dans le monde (reload, zone).
    self.onEnteringWorld = self.onEnteringWorld or function()
        for _, unit in ipairs(UNITS) do
            local f = self.frames[unit]
            if f then UpdateAll(f) end
        end
        -- Les FontStrings de nom créés pendant la fenêtre de chargement peuvent rester
        -- figés invisibles : on les re-crée à neuf UNE fois, peu après l'entrée en jeu
        -- (rendu prêt). Fiable pour TOUS les cadres, y compris cible/focus/ToT dont le
        -- nom n'apparaît qu'à l'acquisition de l'unité. Deux passes pour couvrir les
        -- machines plus lentes.
        if not M.namesRebuilt then
            M.namesRebuilt = true
            local function rebuildAll()
                for _, unit in ipairs(UNITS) do
                    local f = M.frames and M.frames[unit]
                    if f then RebuildNameLevel(f) end
                end
            end
            C_Timer.After(0.1, rebuildAll)
            C_Timer.After(1.0, rebuildAll)
        end
    end
    ns.EventBus:Register("PLAYER_ENTERING_WORLD", self.onEnteringWorld)

    -- Statuts du JOUEUR (mort / fantôme / absent…) : événements broadcast sans
    -- unité -> on rafraîchit le texte du cadre joueur.
    if not self.statusHooked then
        self.statusHooked = true
        local function refreshPlayer()
            if self.frames.player then UpdateHealth(self.frames.player) end
        end
        for _, ev in ipairs({ "PLAYER_FLAGS_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
            ns.EventBus:Register(ev, refreshPlayer)
        end
    end

    -- Indicateurs d'état pilotés par des événements BROADCAST (sans unité) :
    -- marqueur de raid, rôle, chef, et combat du JOUEUR (les autres unités passent
    -- par UNIT_FLAGS / UNIT_FACTION). Un seul handler rafraîchit tous les cadres.
    if not self.indicatorsHooked then
        self.indicatorsHooked = true
        local function refreshInd()
            for _, unit in ipairs(UNITS) do
                local f = self.frames[unit]
                if f then UpdateIndicators(f) end
            end
        end
        for _, ev in ipairs({
            "RAID_TARGET_UPDATE", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
            "PARTY_LEADER_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
            "PLAYER_FLAGS_CHANGED", -- statut PvP du joueur (expiration du timer, etc.)
        }) do
            ns.EventBus:Register(ev, refreshInd)
        end
    end
end

function M:OnDisable()
    if self.onEnteringWorld then
        ns.EventBus:Unregister("PLAYER_ENTERING_WORLD", self.onEnteringWorld)
    end
    if not self.frames then return end
    for _, f in pairs(self.frames) do
        UnregisterUnitWatch(f)
        U.RunWhenSafe(function() f:Hide() end)
    end
end

-- Réapplique taille/position de tous les cadres depuis la config, puis rafraîchit.
-- Public : appelé par le menu d'options après un changement de réglage.
function M:RefreshAll()
    if not self.frames then return end
    local uf = ns.db.unitframes
    for _, unit in ipairs(UNITS) do
        local f = self.frames[unit]
        if f then
            ApplyConfig(f, uf[unit])
            ApplyMirror(f, uf[unit].mirrored == true)
            UpdateAll(f)
        end
    end
end

-- Changement de profil actif : tout réappliquer.
function M:OnProfileChanged()
    self:RefreshAll()
end

-- Mode déverrouillé (menu d'options) : rend les cadres déplaçables et les affiche
-- tous (même la cible sans cible) avec un overlay d'aide. Opérations sécurisées
-- (Show/Hide, (Un)RegisterUnitWatch) différées hors combat.
function M:SetUnlocked(unlocked)
    self.unlocked = unlocked and true or false
    if not self.frames then return end
    U.RunWhenSafe(function()
        for _, unit in ipairs(UNITS) do
            local f = self.frames[unit]
            if f then
                if self.unlocked then
                    UnregisterUnitWatch(f)
                    f:Show()
                    f.unlockOverlay:Show()
                else
                    f.unlockOverlay:Hide()
                    RegisterUnitWatch(f)
                end
            end
        end
    end)
end

-- Bascule la disposition inversée d'une unité à chaud (menu d'options).
function M:SetMirrored(unit, mirror)
    mirror = mirror and true or false
    ns.db.unitframes[unit].mirrored = mirror or nil
    local f = self.frames and self.frames[unit]
    if f then
        ApplyMirror(f, mirror)
        UpdateAll(f)
    end
end

-- Réinitialise la position (offset x/y) d'une unité à sa valeur par défaut.
function M:ResetPosition(unit)
    local d, c = DEFAULTS[unit], ns.db.unitframes[unit]
    if d and c then
        c.x, c.y = d.x, d.y
        self:RefreshAll()
    end
end

-- Active/désactive tout le cadre d'une unité (toggle du menu).
function M:SetEnabled(unit, enabled)
    ns.db.unitframes[unit].enabled = (enabled ~= false)
    self:RefreshAll()
end

-- APERÇU de la barre de vie (réglage du style) : fige la barre à 50 % pour voir le
-- fond/contour. État transitoire (NON sauvegardé dans le profil).
function M:SetHealthPreview(unit, on)
    local f = self.frames and self.frames[unit]
    if not f then return end
    f.healthPreview = on and true or false
    UpdateHealth(f)
end

function M:IsHealthPreview(unit)
    local f = self.frames and self.frames[unit]
    return f and f.healthPreview or false
end

-- Aperçu de la barre de ressource (fige à 50 %). État transitoire (non sauvegardé).
function M:SetPowerPreview(unit, on)
    local f = self.frames and self.frames[unit]
    if not f then return end
    f.powerPreview = on and true or false
    UpdatePower(f)
end

function M:IsPowerPreview(unit)
    local f = self.frames and self.frames[unit]
    return f and f.powerPreview or false
end

-- Aperçu de la ressource de classe (fige à la moitié des segments).
function M:SetClassPowerPreview(unit, on)
    local f = self.frames and self.frames[unit]
    if not f or not f.classpower then return end
    f.classpower.preview = on and true or false
    f.classpower.Update()
end

function M:IsClassPowerPreview(unit)
    local f = self.frames and self.frames[unit]
    return f and f.classpower and f.classpower.preview or false
end

-- Aperçu de la castbar (incantation factice).
function M:SetCastbarPreview(unit, on)
    local f = self.frames and self.frames[unit]
    if not f or not f.castbar then return end
    f.castbar.preview = on and true or false
    if on then ShowCastPreview(f.castbar) else f.castbar.Refresh() end
end

function M:IsCastbarPreview(unit)
    local f = self.frames and self.frames[unit]
    return f and f.castbar and f.castbar.preview or false
end

-- Coupe TOUS les aperçus (ex. fermeture du menu) et restaure les vraies valeurs.
function M:ClearPreviews()
    if not self.frames then return end
    for _, f in pairs(self.frames) do
        if f.healthPreview then f.healthPreview = false; UpdateHealth(f) end
        if f.powerPreview then f.powerPreview = false; UpdatePower(f) end
        if f.classpower and f.classpower.preview then f.classpower.preview = false; f.classpower.Update() end
        if f.castbar and f.castbar.preview then f.castbar.preview = false; f.castbar.Refresh() end
    end
end

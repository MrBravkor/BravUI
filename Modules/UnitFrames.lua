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
        x       = -260,       -- offset depuis le centre de l'écran
        y       = -140,
        health  = { width = 250, height = 50 },
        power   = { width = 250, height = 15, gap = 3 },
        castbar = { enabled = true, height = 18, gap = 3 },
    },
    target = {
        enabled  = true,
        x        = 260,
        y        = -140,
        mirrored = true,      -- disposition inversée (nom à droite, remplissage <-)
        health   = { width = 250, height = 50 },
        power    = { width = 250, height = 15, gap = 3 },
        castbar  = { enabled = true, height = 18, gap = 3 },
    },
}
ns.Config:RegisterDefaults("unitframes", DEFAULTS)

-- Unités gérées par le module, dans l'ordre de création.
local UNITS = { "player", "target" }

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
local function SetBarText(fs, cur, max, getPct)
    local secret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))
    if secret then
        local ok
        if AbbreviateNumbers and getPct then
            ok = pcall(function()
                fs:SetFormattedText("%s || %d%%", AbbreviateNumbers(cur), getPct())
            end)
        end
        if not ok and AbbreviateNumbers then
            ok = pcall(function() fs:SetFormattedText("%s", AbbreviateNumbers(cur)) end)
        end
        if not ok and not pcall(fs.SetFormattedText, fs, "%d", cur) then
            fs:SetText("")
        end
    else
        local pct = (max > 0) and math.floor(cur / max * 100 + 0.5) or 0
        fs:SetText(U.FormatNumber(cur) .. " || " .. pct .. "%")
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
    SetBarText(f.hpText, cur, max, f.getHealthPct)
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
    if not ShouldShowPower(f) then
        f.powerContainer:Hide()
        return
    end
    f.powerContainer:Show()
    local cur, max = UnitPower(f.unit), UnitPowerMax(f.unit)
    f.power:SetMinMaxValues(0, max)
    f.power:SetValue(cur, SMOOTH)
    -- Couleur selon le type de ressource courant (mana/rage/énergie…). Non secret.
    local ptype, token = UnitPowerType(f.unit)
    local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if c then f.power:SetStatusBarColor(c.r, c.g, c.b) end
    SetBarText(f.powerText, cur, max, f.getPowerPct)
end

-- « Nom | Lvl » regroupés dans un seul FontString (nom en blanc, niveau en
-- doré). Nom et niveau ne sont jamais secrets : concaténation libre.
local function UpdateNameLevel(f)
    local name = UnitName(f.unit)
    -- Ne JAMAIS écraser le nom avec du vide : UnitName peut renvoyer nil de façon
    -- transitoire (ex. au retour d'AFK, un UNIT_NAME_UPDATE peut précéder la
    -- disponibilité du nom). On garde alors l'affichage précédent.
    if not name or name == "" then return end
    local lvl = UnitLevel(f.unit)
    local lvlText = (lvl and lvl > 0) and lvl or "??"
    -- La BARRE reste colorée par la classe / réaction ; seul le NOM passe en blanc.
    f.health:SetStatusBarColor(U.GetReactionColor(f.unit))
    -- « || » affiche une seule barre « | » (« | » seul est un échappement).
    f.nameLevel:SetText(name .. " || |cffffd100" .. lvlText .. "|r")
end

local function UpdateAll(f)
    UpdateNameLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
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
    end
end

--------------------------------------------------------------------------------
-- Fabrique d'une barre arrondie : fond noir + bordure 1px + StatusBar + fond des
-- valeurs manquantes, coins arrondis via masque. Renvoie la StatusBar. Réutilisée
-- pour la vie et la ressource (et, plus tard, la cible).
--------------------------------------------------------------------------------
local function CreateBar(container, maskPath)
    -- Fond / bordure noire couvrant tout le conteneur.
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(FLAT)
    bg:SetVertexColor(0, 0, 0, 1)
    bg:SetAllPoints(container)

    -- Barre, encastrée de 1px -> laisse 1px de bordure noire.
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetStatusBarTexture(FLAT)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)

    -- Fond de la barre : portion « vide » (valeurs manquantes) en gris sombre.
    local mbg = bar:CreateTexture(nil, "BACKGROUND")
    mbg:SetTexture(FLAT)
    mbg:SetVertexColor(0.15, 0.15, 0.15, 1)
    mbg:SetAllPoints(bar)

    -- Coins arrondis : SetTexCoord ne tient pas sur une StatusBar, on masque donc
    -- les textures (un masque pour la bordure, un pour la barre).
    local maskB = container:CreateMaskTexture()
    maskB:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    maskB:SetAllPoints(container)
    bg:AddMaskTexture(maskB)

    local maskF = container:CreateMaskTexture()
    maskF:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    maskF:SetAllPoints(bar)
    mbg:AddMaskTexture(maskF)
    bar:GetStatusBarTexture():AddMaskTexture(maskF)

    return bar
end

-- Applique la disposition (normale, ou inversée « miroir » pour la cible) : sens
-- de remplissage des barres + ancrage des textes. Extrait pour pouvoir la
-- basculer à chaud depuis le menu d'options.
local function ApplyMirror(f, mirror)
    f.health:SetReverseFill(mirror)
    f.power:SetReverseFill(mirror)
    local nl, hp = f.nameLevel, f.hpText
    nl:ClearAllPoints()
    hp:ClearAllPoints()
    if mirror then
        nl:SetPoint("TOPRIGHT", f.health, "TOPRIGHT", -8, -6)
        nl:SetPoint("LEFT", f.health, "LEFT", 8, 0)
        nl:SetJustifyH("RIGHT")
        hp:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT", 8, 5)
        hp:SetJustifyH("LEFT")
    else
        nl:SetPoint("TOPLEFT", f.health, "TOPLEFT", 8, -6)
        nl:SetPoint("RIGHT", f.health, "RIGHT", -8, 0)
        nl:SetJustifyH("LEFT")
        hp:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", -8, 5)
        hp:SetJustifyH("RIGHT")
    end
end

--------------------------------------------------------------------------------
-- Barre d'incantation (castbar)
-- Les timings de cast peuvent être SECRETS en 12.0 (surtout ennemis, anti-
-- automatisation d'interruption). On ne compare/calcule JAMAIS start/end côté
-- Lua : on les donne à SetMinMaxValues (qui accepte les secrets) et on avance la
-- valeur en OnUpdate avec GetTime() (non secret) -> le moteur calcule le
-- remplissage. Détection du cast via castBarID (JAMAIS secret). Nom/icône
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

-- Démarre l'affichage d'un cast/canalisation. Renvoie true si un cast est en
-- cours, false sinon (détection via castBarID, jamais secret).
local function StartCast(cbc, channel)
    if not cbc.enabled then return false end
    local u = cbc.unit
    local name, disp, tex, startMs, endMs, notInt, castBarID, _
    if channel then
        name, disp, tex, startMs, endMs, _, notInt, _, _, _, castBarID = UnitChannelInfo(u)
    else
        name, disp, tex, startMs, endMs, _, _, notInt, _, castBarID = UnitCastingInfo(u)
    end
    if not castBarID then return false end

    cbc.channel = channel and true or false
    cbc.casting = true
    cbc.bar:SetReverseFill(cbc.channel)

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

    cbc:Show()
    return true
end

local function StopCast(cbc)
    cbc.casting = false
    cbc:Hide()
end

-- Ré-évalue l'état de cast courant (changement de cible, création).
local function RefreshCast(cbc)
    if StartCast(cbc, false) then return end
    if StartCast(cbc, true) then return end
    StopCast(cbc)
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function OnCastEvent(cbc, event)
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

-- Construit la castbar (conteneur + icône + barre + nom). Position/taille en
-- ApplyConfig. Cachée au repos, affichée pendant un cast.
local function CreateCastbar(f, unit, cfg)
    local cbc = CreateFrame("Frame", nil, f)
    cbc.unit = unit
    cbc.enabled = cfg.castbar.enabled ~= false
    cbc:SetSize(cfg.health.width, cfg.castbar.height)

    -- Barre arrondie pleine largeur (fond + bordure + coins arrondis, comme les
    -- autres barres). La progression du cast = son remplissage.
    local bar = CreateBar(cbc, MASK_THIN)
    cbc.bar = bar

    -- Icône du sort : petit carré légèrement arrondi, superposé à gauche.
    local isz = cfg.castbar.height - 5
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("LEFT", bar, "LEFT", 3, 0)
    icon:SetSize(isz, isz)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- rogne la bordure de l'icône
    local imask = cbc:CreateMaskTexture()
    imask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    imask:SetAllPoints(icon)
    icon:AddMaskTexture(imask)
    cbc.icon = icon

    -- Timer (temps restant), à droite.
    local tmr = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(tmr, 10, "OUTLINE")
    tmr:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    tmr:SetJustifyH("RIGHT"); tmr:SetTextColor(1, 1, 1)
    cbc.timerText = tmr

    -- Nom du sort, entre l'icône et le timer.
    local nm = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(nm, 10, "OUTLINE")
    nm:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nm:SetPoint("RIGHT", tmr, "LEFT", -5, 0)
    nm:SetJustifyH("LEFT"); nm:SetWordWrap(false); nm:SetTextColor(1, 1, 1)
    cbc.nameText = nm

    cbc:SetScript("OnEvent", OnCastEvent)
    for _, ev in ipairs(CAST_EVENTS) do
        pcall(cbc.RegisterUnitEvent, cbc, ev, unit) -- pcall : certains events peuvent manquer
    end
    -- Avancement du remplissage (temps courant, non secret) + décompte du timer
    -- (uniquement si le timing n'est PAS secret). N'est appelé que pendant un cast.
    cbc:SetScript("OnUpdate", function(self)
        if not self.casting then return end
        self.bar:SetValue(GetTime() * 1000)
        if not self.secretTime and self.endMs then
            local rem = (self.endMs - GetTime() * 1000) / 1000
            self.timerText:SetText(string.format("%.1f", rem > 0 and rem or 0))
        end
    end)

    cbc.Refresh = function() RefreshCast(cbc) end
    cbc:Hide()
    return cbc
end

--------------------------------------------------------------------------------
-- Fabrique : construit un cadre d'unité complet à partir d'une config
--------------------------------------------------------------------------------
local function CreateUnitFrame(unit, cfg)
    local frameName = "BravUI_" .. unit:sub(1, 1):upper() .. unit:sub(2) .. "Frame"
    local f = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate")
    f.unit = unit
    f:SetSize(cfg.health.width, cfg.health.height)
    f:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
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

    -- Barre de VIE : occupe tout le cadre-bouton (zone cliquable).
    local health = CreateBar(f, MASK)
    f.health = health

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

    -- Barre de RESSOURCE : conteneur propre, LARGEUR INDÉPENDANTE, centré sous la
    -- vie (suit la position du cadre via l'ancrage TOP au bas de la vie).
    local pc = CreateFrame("Frame", nil, f)
    pc:SetSize(cfg.power.width, cfg.power.height)
    pc:SetPoint("TOP", f, "BOTTOM", 0, -cfg.power.gap)
    f.powerContainer = pc
    local power = CreateBar(pc, MASK_THIN)
    f.power = power

    -- Barre d'incantation, sous la ressource.
    local castbar = CreateCastbar(f, unit, cfg)
    castbar:SetPoint("TOP", pc, "BOTTOM", 0, -cfg.castbar.gap)
    f.castbar = castbar

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
    ovTxt:SetText(unit == "player" and "Joueur" or "Cible")
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
        local c = ns.db.unitframes[self.unit]
        local ux, uy = UIParent:GetCenter()
        local sx, sy = self:GetCenter()
        if sx and ux then
            c.x, c.y = math.floor(sx - ux + 0.5), math.floor(sy - uy + 0.5)
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", c.x, c.y)
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

    -- Certains tokens changent d'unité (ex. « target ») : un événement broadcast
    -- signale le changement -> rafraîchissement complet du cadre. RegisterUnitWatch
    -- gère, lui, l'affichage/masquage selon l'existence de l'unité.
    local changeEvent = (unit == "target" and "PLAYER_TARGET_CHANGED")
        or (unit == "focus" and "PLAYER_FOCUS_CHANGED") or nil
    if changeEvent then
        ns.EventBus:Register(changeEvent, function()
            UpdateAll(f)
            f.castbar.Refresh() -- la nouvelle unité peut être déjà en train d'incanter
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
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
        f:SetSize(cfg.health.width, cfg.health.height)
        if f.powerContainer then
            f.powerContainer:ClearAllPoints()
            f.powerContainer:SetPoint("TOP", f, "BOTTOM", 0, -cfg.power.gap)
            f.powerContainer:SetSize(cfg.power.width, cfg.power.height)
        end
        if f.castbar then
            f.castbar:ClearAllPoints()
            f.castbar:SetPoint("TOP", f.powerContainer, "BOTTOM", 0, -cfg.castbar.gap)
            f.castbar:SetSize(cfg.health.width, cfg.castbar.height)
            f.castbar.icon:SetSize(cfg.castbar.height - 5, cfg.castbar.height - 5)
            f.castbar.enabled = cfg.castbar.enabled ~= false
            if not f.castbar.enabled then f.castbar.casting = false; f.castbar:Hide() end
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
-- Cycle de vie du module
--------------------------------------------------------------------------------
function M:OnEnable()
    self.frames = self.frames or {}

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

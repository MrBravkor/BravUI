# CHANGELOG.md

---

## [2.0.9-alpha] — 04/04/2026

Meter v2 enrichi : opacité par zone, segment menu intelligent, panel de partage, tracking instance, protection secret strings.

### Meter — Opacité panneau

- Split du fond en 3 textures indépendantes : onglets (`_tabBg`), contenu (`_bg`), barre d'info (footer)
- Toggle afficher/masquer le fond + 3 sliders opacité (onglets / barres / barre d'info)
- Aperçu fixe et animé depuis le menu

### Meter — Segment menu

- Menu déroulant au-dessus du panel, liste plate chronologique
- Détection automatique : boss (rouge), donjon M+ (doré), trash d'instance (gris), monde ouvert (gris clair)
- Marqueur actif "N" via `Font_Icons.ttf`, Overall / En cours en bas
- Filtrage des doublons Overall retournés par l'API

### Meter — Segment metadata

- Tracking instance/world à chaque début de combat (`PLAYER_REGEN_DISABLED`, `ENCOUNTER_START`)
- Stockage dans `db.segmentMeta` : isInstance, instanceType, instanceName, difficultyName, difficultyID
- Distinction automatique trash d'instance vs mobs monde ouvert (épouvantail, etc.)
- Reset nettoie les métadonnées

### Meter — Panel de partage

- Panel centré avec dropdown canal (Dire, Groupe, Raid, Guilde, Instance)
- Slider draggable nombre d'entrées (1–25) avec barre de progression couleur de classe
- Format disposition 1 : `DPS/s (Total / %)` avec durée du combat dans le header
- `SafeChat()` pour nettoyer les escape codes WoW avant envoi
- Noms sans suffixe serveur, croix de fermeture

### Meter — Tooltip BravUI

- Bulle d'aide custom sur les boutons tab (segments, partager, reset)
- Fond noir (0.9 alpha), bordure 2px couleur de classe, police Russo_One
- Couleur de classe liée au réglage général `useClassColor`

### Page Menu Info

- Nouvelle page (ordre 97) : versions addons, commandes slash, auteur, testeurs, guilde

### Page Menu Cooldown

- Réécriture complète avec onglets + sous-onglets (7 onglets)
- ResourceBar, ClassPower, CastBar : position libre, colorMode 3 modes, fond/texte configurables
- CastBar preview mode, Move system pour ResourceBar/ClassPower/CastBar

### Page Menu Meter

- Réécriture complète avec API réelle, format texte barres (3 modes + custom libre)
- Toggle icône spé + rang, couleur barres (classe/custom), séparateur rang
- Icônes de classe custom (5 styles), taille police séparée rang/valeurs

### UnitFrames — Icônes de rôle

- 3 styles (Blizzard, BravUI, FFXIV), dropdown menu, refresh dynamique via `APPLY_UNIT`

### BravLib

- `DiffTable` (diff récursif), `DeepApply` (merge profond avec écrasement)
- Export profils diff defaults (réduction ~91%)

### Suppressions

- LZW Compress/Decompress — incompatible copier-coller
- Meter slider barres maximum — retiré du menu

### Corrections

- **Secret strings** — pcall sur noms joueurs, formatage texte barres sans `table.concat`
- **SendChatMessage** — `SafeChat()` retire les escape codes WoW
- **AFK** — fix taint `UnitIsAFK` secret boolean (WoW 12.x)
- **Chat whisper tabs** — fix taint `ChatHistory_GetToken`
- **Keybind CDM** — fix `GetBindingForCmd()` WoW 12.x
- **Skin CDM** — layout tous viewers, lignes centrées, filtre enfants, resize, espacement
- **Import profils** — `DeepApply` au lieu de `TableMerge`
- **Panel opacité** — `RefreshPanel()` dans `Panel.Setup()` pour ancrer les textures

### Modifications

- **Core/Init.lua** — defaults meter (`opacity`, `showBackground`, `headerOpacity`, `footerOpacity`, `segmentMeta`), defaults CDM (`colorMode`, `textAnchor`, `showBackground`, `bgColor`), positions CastBar/ClassPower, welcome message, `roleIconStyle`, `barTextMode`/`barTextCustom`
- **Meter/Meter.lua** — `SaveSegmentMeta()` enregistre le contexte instance à chaque combat, `GetSegmentMeta()` API publique, reset nettoie les métadonnées, test statique (`/bd testfix`), ticker animé 0.2s
- **Meter/Bars.lua** — panel bg split (`_tabBg` + `_bg` + footer), opacité indépendante par zone, segment menu refait (liste plate + meta instance), panel de partage (dropdown + slider + envoyer), custom tooltip BravUI, secret string protection
- **Cooldown/ResourceBar.lua** — réécriture : position libre, `colorMode` (power/class/custom), fond activable + couleur, texte avec format/ancrage/taille/couleur
- **Cooldown/ClassPower.lua** — `SetSegmentColor` 3 modes, `UpdateBackground`, hook enrichi (taille, fond, position live)
- **Cooldown/CastBar.lua** — Move system, `ApplyBackground`, preview mode, hook enrichi (taille, icône, fond, texte, position live)
- **BravUI_Menu/Pages/Cooldown.lua** — onglets + sous-onglets, Ressource/Puissance/Incantation : sous-onglets Général/Positions/Couleur/Fond/Texte
- **BravUI_Menu/Core/Widgets.lua** — `button_select` : support `disabled`, `subtext` ; `input` : boutons Valider/Reset
- **BravLib/Storage.lua** — export v2 diff defaults, import `DeepApply`, suppression LZW
- **BravLib/Serialize.lua** — ajout `DiffTable` (diff récursif avec filtre clés inconnues)
- **BravLib/Utils.lua** — ajout `DeepApply` (merge profond avec écrasement)
- **BravLib/Media.lua** — 3 styles icônes de rôle (Blizzard/BravUI/FFXIV), 5 styles icônes de classe (flat/flatborder2/round/square/warcraftflat × 13 classes)

---

## [2.0.8-alpha] — 02/04/2026

Modules AFK, DataBars, Cursor, Cooldown, CombatLog — portage v2 complet. Fix taint chat, secrets raid TWW, fond configurable.

### Module AFK

- Overlay cinématique mode AFK : barres top/bottom, infos joueur/zone/système/FPS, timer AFK + countdown déconnexion

### Module DataBars

- XPBar + RepBar + HonorBar fusionnés en un seul fichier, shared factory inliné
- Gestion Paragon/Renown/Friendship pour RepBar, masquage des barres Blizzard
- Intégration edit mode (`/bravmove`), positions synchronisées avec le menu
- Page menu DataBars complète

### Module Cursor

- Rings (static/GCD/cast), ping, crosshair, trail particules, touches modificatrices
- Page menu Cursor complète (général, anneau, GCD, cast, trainée, modifiers)

### Module Cooldown

- **Init** — namespace `BravUI.Cooldown`, helpers partagés, bootstrap CDM avec détection + popup si inactif
- **Skin** — reskin des 4 viewers Blizzard CDM (bordures classe, fond noir, swipe overlay, keybinds, layout grille)
- **ResourceBar** — barre ressource ancrée sous EssentialCooldownViewer, couleur par type de pouvoir, largeur flexible
- **CastBar** — barre incantation avec icône sort, spark, timer elapsed/remaining, gestion cast/channel
- **ClassPower** — segments puissance secondaire (combo, holy power, soul shards, chi, arcane charges, runes DK)
- Edit Mode CDM — 4 viewers enregistrés dans `/bravmove`, catégorie "Cooldown", protection combat
- Page menu Cooldown (configuration ResourceBar)

### Module CombatLog

- Détection automatique du type d'instance (donjon/raid/M+/arène/BG)
- Popup de confirmation stylé BravUI à l'entrée, indicateur "Log actif/inactif" avec bordure classe
- Auto-disable à la sortie d'instance, container QueueEye intégré au `/bravmove`

### BravLib.Media

- Logo BravUI enregistré
- Textures `cursor_ring`, `cursor_dot`
- 19 textures statusbar (beveled, glossy, smooth, stripes...)

### UnitFrames — Icônes rôle & leader

- Système d'ancrage `anchor_grid` 3x3 (TOPLEFT → BOTTOMRIGHT) + taille + offsets X/Y configurables
- Options ajoutées dans le menu pour Group et Raid
- Preview respecte la config couleurs (HP classe/custom, power type/custom) et format texte

### Corrections

- **Chat.lua** — fix taint : `hooksecurefunc` + `C_Timer.After(0)` au lieu d'override direct `SetPoint`
- **RaidFactory.lua** — fix texte HP secret-safe (TWW) : `SetText(AbbreviateNumbers(UnitHealth(u)))` directement
- **RaidFactory.lua** — fix tri sous-groupes : respect de l'ordre roster Blizzard en mode `groupBySubgroup`
- **Group.lua** — fix texte HP sécurisé avec `tostring()` sur valeurs cachées
- **Utils.lua** — fix `GetProfileBG` bug `and/or` avec `false`, `ApplyBG` support dual Texture/Frame
- **DataBars** — fix `Font not set`, clé DB `xpbar` → `expbar`, defaults v2 complétés, couleur classe/custom respectée

---

## [2.0.7-alpha] — 31/03/2026

Format texte, fond configurable, fix taint raid, fix minimap.

### Menu UnitFrames — Texte

- Format texte HP (VALUE, PERCENT, VALUE_PERCENT, PERCENT_VALUE, NONE) pour Group, Raid 15/25/40
- Format texte HP complet pour Focus, Pet, ToT (SimpleFrameFactory)
- Format texte Power (VALUE, NONE) pour Group, Raid 15/25/40
- Ajout des defaults manquants `anchor` et `format` pour group/raid — widgets anchor grid et format fonctionnels

### Menu UnitFrames — Fond

- Backgrounds configurables depuis la DB pour toutes les unit frames
- Defaults `backgrounds` ajoutes pour Player, Target, ToT, Pet, Focus
- Suppression de la Texture init (alpha fixe 0.55) qui persistait sous le fond slider dans Raid/Group
- Apercu live dans le menu (Player toujours visible, autres via preview)

### Core

- Frames Blizzard masquees via `SetAlpha(0)` au lieu de `RegisterStateDriver("hide")` — les barres/textes restent actifs pour les hooks HP/%

### Minimap

- Refonte masquage icones addon : flag reversible, hooks intelligents, re-scan retarde (2s+5s), toggle live depuis le menu

### Corrections

- Fix taint raid frames — protection `InCombatLockdown()` sur `Show()`/`Hide()` des membres raid en combat
- Fix double fond Raid/Group — `CreateBarBackgroundTexture` parasite supprime
- Fix icones addon minimap reapparaissant apres /reload

---

## [2.0.6-alpha] — 31/03/2026

Module Meter (DPS/HPS) porte en v2, tracker M+ complet, BravLib.Format et BravLib.DamageMeter.

### Module Meter

- Port complet v1 vers v2 — module integre (ex-BravUI_Meter standalone)
- Factory barres DPS/HPS avec tooltips, detail window, animation lerp
- Panel conteneur avec layouts 1/2/3/4 fenetres, tabs mode-switching
- Menus segment, partage en chat, reset
- Test data via `/bd test` (barres animees)
- Slash commands `/bd` et `/bravmeter`

### Tracker M+

- Encounters, deaths, loot, CC par joueur
- Timer live avec barres de progression +3/+2/+1
- Summary post-run : header, timeline boss, tableau joueurs, loot

### Core

- **`BravLib.Format`** : formatage partage (Number, Time, SafeFormat secret-safe, MakeFont, MakeSep)
- **`BravLib.DamageMeter`** : wrapper C_DamageMeter (GetSorted, GetSpellBreakdown, GetSegments, Reset)
- Hook `APPLY_METER` dans `Core/Load.lua`
- Defaults `meter` + positions dans `Core/Init.lua`

### Suppressions

- AugTracker (traqueur buffs Aug Evoker) — retire du port v2

### Corrections

- Flash des frames Blizzard (UnitFrames + Chat) au login/reload — masquage instantane
- MPlus crash `GetCriteriaInfo` nil — API migree de `C_Scenario` vers `C_ScenarioInfo` (Midnight)
- MPlus `table index is secret` — `entry.guid` de `C_DamageMeter` secret en combat

---

## [2.0.5-alpha] — 30/03/2026

Module Chat & InfoBar complet, fix du flash UI Blizzard.

### Module Chat

- Port complet v1 vers v2 — fichier unique sans dépendances externes
- Skinning complet du panel : onglets, editbox avec curseur custom, bordure par canal
- Système d'onglets intelligent : tabs permanents + temporaires (whispers), dropdown overflow
- Flash des onglets sur whisper entrant avec pulsation colorée
- Historique whispers par personnage (`/bravchat`)

### InfoBar

- Mode docked au panel Chat : Spec/Talent, Or, Durabilité, FPS/MS
- Mode standalone : cadre indépendant déplaçable via le Move system

### Menu

- Page Chat complète : général, apparence, police, taille, reset

### Core

- `BravLib.Storage.GetCharDB()` — données par personnage, indépendant des profils
- Hooks `APPLY_CHAT` et `APPLY_INFOBAR` dans `Core/Load.lua`
- Defaults `chat` + `infobar` + positions dans `Core/Init.lua`

### Corrections

- Flash des frames Blizzard (UnitFrames + Chat) au login/reload — masquage désormais instantané

---

## [2.0.4-alpha] — 30/03/2026

Module ActionBars complet, corrections menu UnitFrames, fix Midnight secrets.

### Module ActionBars

- Port complet v1 vers v2 — fichier unique sans dependances externes
- 10 barres (1-8, familier, postures) avec reparenting des boutons Blizzard
- Skin BravUI sur chaque bouton (backdrop, highlight, pushed, checked, flash)
- Stance bar dynamique — nombre de boutons adapte a la classe (`GetNumShapeshiftForms`)
- Visibilite per-bar : mouseover fade, masquer en combat / hors combat, alpha combat
- Per-bar settings : taille, espacement, origin, icon zoom, contour, textes, couleurs
- Positionnement CENTER synchronise avec le Move system (`/bravmove`)
- Page menu ActionBars complete avec sous-onglets par barre
- Hook `APPLY_ACTIONBARS` pour rafraichissement live depuis le menu

### Systeme de keybind (`/bravbind`)

- Mode keybind maison remplacant LibKeyBound
- Header flottant en haut de l'ecran avec bordure couleur de classe
- Toggle **Personnage / Compte** — choix du binding set persiste dans la DB
- Overlay sur chaque bouton affichant le raccourci actuel
- Hover + touche = bind, clic droit = effacer, ESC = quitter
- Combinaisons Shift/Ctrl/Alt supportees
- Toggle accessible dans la page menu ActionBars et via `/bravbind`

### Menu UnitFrames — textes et auras

- Defaults `text` remplis pour les 9 unit frames (valeurs v1 restaurees)
- Textes (nom, HP, power) respectent `enabled` dans tous les modules : Player, Target, ToT, Focus, Pet, Group, Raid
- `RefreshHPText` ajoute dans Player.Refresh pour application live
- Hook `APPLY_UNIT` appelle `RefreshAuras` — options buffs/debuffs fonctionnelles

### Menu Minimap

- Sliders Offset X/Y ecrivent dans `db.positions.Minimap` (sync Move system)

### Move system

- `BravUI.Move.Register()` expose pour les movers custom
- Clamping des saisies manuelles X/Y aux bords de l'ecran

### Corrections

- ActionBars : `SetClampedToScreen` sur les frames BravBar
- ActionBars : `RegisterForClicks("AnyDown", "AnyUp")` apres reparent (fix misclick TWW)
- CastBarFactory : `notInterruptible` (secret boolean Midnight) wrappe dans pcall
- CastBarFactory : `startMS`/`endMS` (secret numbers Midnight) arithmetique wrappee dans pcall
- Police globale : `U.GetFont()` dynamique dans tous les modules
- Target frame ne force plus `Show()` dans ApplyFromDB

---

## [2.0.3-alpha] — 29/03/2026

Systeme de profils complet, sans dependances externes.

### Profils

- Systeme complet de gestion de profils sans dependances externes
- Creation, suppression, copie, renommage et reset de profils
- Migration automatique depuis l'ancien format (v2.0.2 et anterieur)

### 4 modes de routage

- **Global** — un profil partage entre tous les personnages
- **Par personnage** — chaque personnage possede son propre profil, cree automatiquement a la premiere connexion
- **Par specialisation** — switch automatique de profil au changement de spec
- **Par role** — switch automatique selon le role (Tank / Heal / DPS), sans changer entre specs du meme role

### Import / Export / Partage

- Export compresse (LZW) avec header versionne `BravUI:1:`
- Import avec validation, switch automatique et reload
- Partage in-game entre joueurs via Whisper, Groupe, Raid ou Guilde

### Page menu Profils

- Dropdown profil actif et copie depuis un autre profil
- Popups dediees pour creer, supprimer, importer, exporter et partager
- Grille de selection du mode de routage (2x2)
- Dropdowns par spec ou par role selon le mode actif

### Positions

- Tous les elements UI ont desormais des positions par defaut
- Les positions sont sauvegardees et restaurees par profil
- Le bouton "Remise par defaut" de l'Edit Mode remet aux vraies positions d'origine

### Corrections

- Crash `SetPoint` sur des positions vides au chargement
- Positions perdues apres un `/reload`
- Page du menu qui se vidait apres un changement de profil
- Positions ecrasees lors d'un switch de profil

### Changements techniques

- `BravLib.Storage` entierement refait en profile-aware — `GetDB()` retourne toujours le profil actif, transparent pour tous les modules
- `BravLib.Serialize` — serialisation Lua maison avec parser securise (pas de `loadstring`)
- `BravLib.Compress` — compression LZW maison
- Auras et VehicleExit en positions absolues independantes (plus d'ancrage relatif)
- Wizard adapte pour le systeme de profils

---

## [2.0.2-alpha] — 29/03/2026

Menu complet, module Minimap, systeme de deplacement avance et infrastructure core.

### New Modules

- **Minimap** — panel custom avec borders class-colored, header (zone/horloge/calendrier/tracking), footer (contacts/guilde), icones courrier/difficulte/compartiment addon. Fichier unique, zero dependance externe.

### Menu System (BravUI_Menu)

- **Fenetre principale** — sidebar navigable, scrollbar custom, search box cross-page, toggle open/close
- **Moteur de widgets** — rendu declaratif complet : toggle, slider, dropdown, color picker, input, button, button_row, button_select, anchor_grid, corner_grid, group, subtabs, header, separator, label, info, divider
- **Page General** — couleur de classe / custom, police, masquage interface Blizzard
- **Page Minimap** — configuration complete : elements, taille, opacite, icones, textes, couleurs, reset
- **Page UnitFrames** — configuration par unite : taille, couleurs, textes, cast bars, auras
- **Locales** — frFR (langue principale) + enUS

### Core System

- **Setup.lua** — bootstrap premier lancement, wizard 2 etapes (bienvenue + profil), slash `/bravwelcome`
- **EscMenu.lua** — reskin du menu Escape en style BravUI, bouton d'acces rapide dans le GameMenu
- **Move.lua** — systeme de deplacement complet : snap/magnetisme entre frames, grille d'alignement, panneau de controle avec filtres par categorie, input X/Y par overlay, reset individuel ou par categorie, ESC pour quitter
- **Slash commands** — `/brav` (menu), `/bravmove` (edit mode), `/bravreset`, `/bravdebug`, `/bravmm` (minimap)
- **Masquage Blizzard** — cache automatiquement les UnitFrames Blizzard remplacees (anti-taint via RegisterStateDriver)
- **Police** — Russo One par defaut sur tous les modules

### Corrections

- Chargement menu LoadOnDemand — slash commands dans le core, `LoadAddOn` au premier appel
- Ordre de chargement TOC — Init.lua avant les locales pour eviter les nil
- Logo wizard corrige
- Toggle hideBlizzardUI branche correctement

---

## [2.0.1-alpha] — 28/03/2026

Implémentation complète du module UnitFrames et refactorisation majeure.

Toutes les frames sont couvertes : joueur, cible, focus, familier, cible-de-cible,
groupe (party 1-4) et raid (15/25/40). Trois factories partagées ont été introduites
pour éliminer ~1600 lignes de code dupliqué.

### Ajouts — Shared

- Factory auras (buffs/debuffs, cooldown spiral, stack count, tooltip, mover)
- Factory frames simples HP+Power+Nom (Focus, Pet, ToT)
- Factory cast bars avec `ComputeAndDisplay()` mutualisé
- Overlay dispel unifié Group + Raid15/25/40
- Overlay heal predict + absorb unifié Group + Raid15/25/40

### Ajouts — Player

- Frame joueur : HP, power, class power, segments, icons
- Cast bar joueur avec icône, timer, spark
- Buffs/debuffs joueur (2 containers indépendants)
- Overlay dispel joueur (secret-safe)
- Heal prediction + absorb joueur
- Frame focus : HP, power, name, preview mode
- Frame familier : HP, power, name
- Cast bar familier

### Ajouts — Target

- Frame cible : HP, power, range check, icons
- Cast bar cible
- Buffs/debuffs cible (2 containers indépendants)
- Frame cible-de-cible : HP, power, name

### Ajouts — Group & Raid

- Frames groupe party 1-4 : HP, power, rôle, icons, range, preview
- Cast bars groupe (party 1-4)
- Factory raid partagée : grille, subgroupes, labels, preview, range
- Frames raid 15, 25 et 40 membres

### Ajouts — Misc

- Bouton sortie véhicule/monture (SecureActionButton, zero taint)
- Utilitaires UI partagés (secret-safe, throttlers, color helpers, widget factories)
- Enregistrement fonts et icons de rôle (tank, healer, dps)

### Suppressions

- Overlays dispel et heal predict Group/Raid individuels — remplacés par les versions unifiées

### Modifications

- Defaults complets pour tous les modules UnitFrames
- Fichiers partagés déplacés dans `Shared/`
- Focus, Pet, ToT — refactorisés via SimpleFrameFactory
- Cast bars joueur, familier, cible — refactorisées via CastBarFactory

---

## [2.0.0] — 28/03/2026

Première version fonctionnelle de BravUI v2.

La base est en place : bibliothèque partagée (BravUI_Lib), core principal (BravUI)
et interface de configuration (BravUI_Menu) chargent proprement sur WoW 12.0.x.

### Corrections
- Compatibilité WoW 12.0.x : migration vers `C_AddOns` pour le chargement des addons
- BravUI_Menu charge au login — les commandes `/brav`, `/bravmove`, `/bravreset`, `/bravdebug` sont disponibles immédiatement

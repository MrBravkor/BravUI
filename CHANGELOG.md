# CHANGELOG.md

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

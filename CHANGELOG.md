# CHANGELOG.md

---

## [2.0.0] — 28/03/2026

Première version fonctionnelle de BravUI v2.

La base est en place : bibliothèque partagée (BravUI_Lib), core principal (BravUI)
et interface de configuration (BravUI_Menu) chargent proprement sur WoW 12.0.x.

### Corrections
- Compatibilité WoW 12.0.x : migration vers `C_AddOns` pour le chargement des addons
- BravUI_Menu charge au login — les commandes `/brav`, `/bravmove`, `/bravreset`, `/bravdebug` sont disponibles immédiatement

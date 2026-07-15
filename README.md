<div align="center">

# BravUI

**Interface modulaire et légère pour World of Warcraft — sans aucune dépendance externe.**

![Version](https://img.shields.io/badge/version-1.1.0-00ccff)
![WoW](https://img.shields.io/badge/WoW-Retail-f8b700)
![Lua](https://img.shields.io/badge/Lua-5.1%20(WoW)-2c2d72)
![Licence](https://img.shields.io/badge/licence-GPL--3.0-green)
![Dépendances](https://img.shields.io/badge/d%C3%A9pendances-aucune-brightgreen)

</div>

---

BravUI n'est **pas** une refonte complète de l'interface à la ElvUI. C'est un addon **ciblé et léger**, construit sur une base **modulaire** : un petit moteur solide sur lequel viennent se greffer des modules d'interface, un par un.

Cette version **1.1.0** greffe le premier module d'interface : les **unitframes Joueur et Cible** (barre de vie, barre de ressource, barre d'incantation, textes d'état), accompagnés d'un **menu de configuration maison**.

## ✨ Caractéristiques

- 🖼️ **Unitframes Joueur & Cible** — barre de vie, barre de ressource (largeur indépendante), barre d'incantation et textes d'état (Hors ligne / Fantôme / Mort / Absent / Occupé).
- 🔤 **Textes** — nom, niveau, valeurs de PV et pourcentage ; couleur de barre par classe / réaction ; remplissage fluide (interpolation native 12.0).
- 🖱️ **Cadre cliquable sécurisé** — clic gauche pour cibler, clic droit pour le menu contextuel.
- ⚙️ **Menu de configuration maison** — position, taille et activation par cadre, accessible via `/brav` ou le bouton **BravUI** du menu Échap.
- 🧩 **Architecture modulaire** — registre de modules avec cycle de vie (`OnInitialize` / `OnEnable` / `OnDisable`). Ajouter un module = un fichier, sans toucher au cœur.
- 💾 **Profils maison** — par personnage, ou séparés **par spécialisation**, sans dépendance type Ace3.
- 🛡️ **Sécurité combat & valeurs secrètes 12.0** — ne touche jamais aux cadres protégés en combat, compatible Midnight (vie, ressource, castbars).
- 🌍 **Localisation** français / anglais.
- 🪶 **Zéro dépendance externe** — pas d'Ace3, pas de LibStub tiers.

## 📦 Installation

1. Télécharge la dernière version.
2. Décompresse le dossier `BravUI` dans :
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. `/reload` en jeu (ou relance le client). À la connexion, un message de bienvenue s'affiche dans le chat.

## ⌨️ Commandes

Toutes les commandes passent par **`/brav`** :

| Commande            | Effet                                               |
| ------------------- | --------------------------------------------------- |
| `/brav`             | Ouvre le menu de configuration                      |
| `/brav profile`     | Affiche le profil actif                             |
| `/brav reset`       | Réinitialise le profil actif aux valeurs par défaut |
| `/brav perspec on`  | Active les profils séparés par spécialisation *     |
| `/brav perspec off` | Désactive les profils séparés par spécialisation *  |

<sub>* pour le personnage courant.</sub>

Le menu de configuration est aussi accessible via un bouton **BravUI** intégré au menu Échap.

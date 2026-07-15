<div align="center">

# BravUI

**Interface modulaire et légère pour World of Warcraft — sans aucune dépendance externe.**

![Version](https://img.shields.io/badge/version-1.2.0-00ccff)
![WoW](https://img.shields.io/badge/WoW-Retail-f8b700)
![Lua](https://img.shields.io/badge/Lua-5.1%20(WoW)-2c2d72)
![Licence](https://img.shields.io/badge/licence-GPL--3.0-green)
![Dépendances](https://img.shields.io/badge/d%C3%A9pendances-aucune-brightgreen)

</div>

---

BravUI n'est **pas** une refonte complète de l'interface à la ElvUI. C'est un addon **ciblé et léger**, construit sur une base **modulaire** : un petit moteur solide sur lequel viennent se greffer des modules d'interface, un par un.

Cette version **1.2.0** ajoute les unitframes **Focus et Cible-de-cible**, les **ressources de classe**, et un **menu de configuration construit** panneau par panneau.

## ✨ Caractéristiques

- 🧩 **Architecture modulaire** — registre de modules avec cycle de vie (`OnInitialize` / `OnEnable` / `OnDisable`). Ajouter un module = un fichier, sans toucher au cœur.
- 🖼️ **Unitframes complets** — Joueur, Cible, Focus et Cible-de-cible (ToT) : barre de vie, barre de ressource, castbar, textes (nom, niveau, PV, %, état).
- ⚔️ **Ressources de classe** — barre segmentée au-dessus de la vie du joueur (combo points, puissance sacrée, fragments d'âme, chi, charges arcaniques, essence), affichée automatiquement selon la spécialisation.
- ⚙️ **Menu de configuration par élément** — un panneau par cadre (Joueur / Cible / Focus / ToT), en sous-onglets : Position, Vie, Ressource, Classe, Incantation. Chaque barre se règle indépendamment.
- 📝 **Textes configurables** — nom, niveau, PV et % positionnables sur 9 ancres, indépendamment pour chaque cadre.
- 👁️ **Mode aperçu** par élément pour régler le style hors combat.
- 🙈 **Masquage des cadres Blizzard natifs** remplacés par BravUI.
- 💾 **Profils maison** — par personnage, ou séparés **par spécialisation**, sans dépendance type Ace3.
- 📡 **Bus d'événements central** pour les événements *broadcast*, tandis que les événements unitaires sont gérés au plus près (perf).
- 🛡️ **Sécurité combat** — garde intégrée pour ne jamais toucher aux cadres protégés en plein combat.
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

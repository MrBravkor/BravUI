<div align="center">

# BravUI

**Interface modulaire et légère pour World of Warcraft — sans aucune dépendance externe.**

![Version](https://img.shields.io/badge/version-1.0.0-00ccff)
![WoW](https://img.shields.io/badge/WoW-Retail-f8b700)
![Lua](https://img.shields.io/badge/Lua-5.1%20(WoW)-2c2d72)
![Licence](https://img.shields.io/badge/licence-GPL--3.0-green)
![Dépendances](https://img.shields.io/badge/d%C3%A9pendances-aucune-brightgreen)

</div>

---

BravUI n'est **pas** une refonte complète de l'interface à la ElvUI. C'est un addon **ciblé et léger**, construit sur une base **modulaire** : un petit moteur solide sur lequel viennent se greffer des modules d'interface, un par un.

Cette version **1.0.0 est la base seule** — le moteur. Aucun élément d'interface visible pour l'instant : c'est la fondation sur laquelle les modules (unitframes, etc.) seront ajoutés.

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
| `/brav`             | Affiche l'aide (version + commandes)                |
| `/brav profile`     | Affiche le profil actif                             |
| `/brav reset`       | Réinitialise le profil actif aux valeurs par défaut |
| `/brav perspec on`  | Active les profils séparés par spécialisation *     |
| `/brav perspec off` | Désactive les profils séparés par spécialisation *  |

<sub>* pour le personnage courant.</sub>

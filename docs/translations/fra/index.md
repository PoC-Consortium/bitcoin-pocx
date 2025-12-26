# Documentation technique Bitcoin-PoCX

**Version** : 1.0
**Base Bitcoin Core** : v30.0
**Statut** : Phase Testnet
**Dernière mise à jour** : 25-12-2025

---

## À propos de cette documentation

Ceci est la documentation technique complète de Bitcoin-PoCX, une intégration de Bitcoin Core qui ajoute la prise en charge du consensus Proof of Capacity neXt generation (PoCX). La documentation est organisée sous forme de guide navigable avec des chapitres interconnectés couvrant tous les aspects du système.

**Publics cibles** :
- **Opérateurs de nœuds** : Chapitres 1, 5, 6, 8
- **Mineurs** : Chapitres 2, 3, 7
- **Développeurs** : Tous les chapitres
- **Chercheurs** : Chapitres 3, 4, 5

## Traductions

| | | | | | |
|---|---|---|---|---|---|
| [🇩🇪 Allemand](../deu/index.md) | [🇬🇧 Anglais](../../index.md) | [🇸🇦 Arabe](../ara/index.md) | [🇧🇬 Bulgare](../bul/index.md) | [🇨🇳 Chinois](../zho/index.md) | [🇰🇷 Coréen](../kor/index.md) |
| [🇩🇰 Danois](../dan/index.md) | [🇪🇸 Espagnol](../spa/index.md) | [🇪🇪 Estonien](../est/index.md) | [🇵🇭 Filipino](../fil/index.md) | [🇫🇮 Finnois](../fin/index.md) | [🇬🇷 Grec](../ell/index.md) |
| [🇮🇱 Hébreu](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇭🇺 Hongrois](../hun/index.md) | [🇮🇩 Indonésien](../ind/index.md) | [🇮🇹 Italien](../ita/index.md) | [🇯🇵 Japonais](../jpn/index.md) |
| [🇱🇻 Letton](../lav/index.md) | [🇱🇹 Lituanien](../lit/index.md) | [🇳🇱 Néerlandais](../nld/index.md) | [🇳🇴 Norvégien](../nor/index.md) | [🇵🇱 Polonais](../pol/index.md) | [🇵🇹 Portugais](../por/index.md) |
| [🇷🇴 Roumain](../ron/index.md) | [🇷🇺 Russe](../rus/index.md) | [🇷🇸 Serbe](../srp/index.md) | [🇸🇪 Suédois](../swe/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇨🇿 Tchèque](../ces/index.md) |
| [🇹🇷 Turc](../tur/index.md) | [🇺🇦 Ukrainien](../ukr/index.md) | [🇻🇳 Vietnamien](../vie/index.md) | | | |

---

## Table des matières

### Partie I : Fondamentaux

**[Chapitre 1 : Introduction et présentation](1-introduction.md)**
Vue d'ensemble du projet, architecture, philosophie de conception, fonctionnalités clés et différences entre PoCX et Proof of Work.

**[Chapitre 2 : Format des fichiers Plot](2-plot-format.md)**
Spécification complète du format plot PoCX incluant l'optimisation SIMD, la mise à l'échelle de la preuve de travail et l'évolution du format depuis POC1/POC2.

**[Chapitre 3 : Consensus et minage](3-consensus-and-mining.md)**
Spécification technique complète du mécanisme de consensus PoCX : structure des blocs, signatures de génération, ajustement de la cible de base, processus de minage, pipeline de validation et algorithme de Time Bending.

---

### Partie II : Fonctionnalités avancées

**[Chapitre 4 : Système d'assignation de forge](4-forging-assignments.md)**
Architecture OP_RETURN uniquement pour la délégation des droits de forge : structure des transactions, conception de la base de données, machine à états, gestion des réorganisations et interface RPC.

**[Chapitre 5 : Synchronisation temporelle et sécurité](5-timing-security.md)**
Tolérance à la dérive d'horloge, mécanisme de forge défensive, anti-manipulation d'horloge et considérations de sécurité liées au timing.

**[Chapitre 6 : Paramètres réseau](6-network-parameters.md)**
Configuration Chainparams, bloc genesis, paramètres de consensus, règles coinbase, mise à l'échelle dynamique et modèle économique.

---

### Partie III : Utilisation et intégration

**[Chapitre 7 : Référence de l'interface RPC](7-rpc-reference.md)**
Référence complète des commandes RPC pour le minage, les assignations et les requêtes blockchain. Essentiel pour l'intégration des mineurs et des pools.

**[Chapitre 8 : Guide du portefeuille et de l'interface graphique](8-wallet-guide.md)**
Guide utilisateur du portefeuille Qt Bitcoin-PoCX : dialogue d'assignation de forge, historique des transactions, configuration du minage et dépannage.

---

## Navigation rapide

### Pour les opérateurs de nœuds
→ Commencer par le [Chapitre 1 : Introduction](1-introduction.md)
→ Puis consulter le [Chapitre 6 : Paramètres réseau](6-network-parameters.md)
→ Configurer le minage avec le [Chapitre 8 : Guide du portefeuille](8-wallet-guide.md)

### Pour les mineurs
→ Comprendre le [Chapitre 2 : Format Plot](2-plot-format.md)
→ Apprendre le processus dans le [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md)
→ Intégrer en utilisant le [Chapitre 7 : Référence RPC](7-rpc-reference.md)

### Pour les opérateurs de pool
→ Consulter le [Chapitre 4 : Assignations de forge](4-forging-assignments.md)
→ Étudier le [Chapitre 7 : Référence RPC](7-rpc-reference.md)
→ Implémenter en utilisant les RPC d'assignation et submit_nonce

### Pour les développeurs
→ Lire tous les chapitres séquentiellement
→ Croiser les références avec les fichiers d'implémentation mentionnés
→ Examiner la structure du répertoire `src/pocx/`
→ Compiler les versions avec [GUIX](../bitcoin/contrib/guix/README.md)

---

## Conventions de la documentation

**Références aux fichiers** : Les détails d'implémentation référencent les fichiers sources comme `chemin/vers/fichier.cpp:ligne`

**Intégration du code** : Tous les changements sont conditionnés par `#ifdef ENABLE_POCX`

**Références croisées** : Les chapitres font des liens vers les sections connexes en utilisant des liens markdown relatifs

**Niveau technique** : La documentation suppose une familiarité avec Bitcoin Core et le développement C++

---

## Compilation

### Compilation de développement

```bash
# Cloner avec les sous-modules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configurer avec PoCX activé
cmake -B build -DENABLE_POCX=ON

# Compiler
cmake --build build -j$(nproc)
```

**Variantes de compilation** :
```bash
# Avec interface graphique Qt
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Compilation debug
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dépendances** : Dépendances standard de compilation Bitcoin Core. Voir la [documentation de compilation Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) pour les exigences spécifiques à chaque plateforme.

### Compilations de version

Pour des binaires de version reproductibles, utilisez le système de compilation GUIX : Voir [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Ressources supplémentaires

**Dépôt** : [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework PoCX Core** : [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Projets connexes** :
- Plotter : Basé sur [engraver](https://github.com/PoC-Consortium/engraver)
- Mineur : Basé sur [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Comment lire cette documentation

**Lecture séquentielle** : Les chapitres sont conçus pour être lus dans l'ordre, en s'appuyant sur les concepts précédents.

**Lecture de référence** : Utilisez la table des matières pour accéder directement à des sujets spécifiques. Chaque chapitre est autonome avec des références croisées vers le matériel connexe.

**Navigation par navigateur** : Ouvrez `index.md` dans un visualiseur markdown ou un navigateur. Tous les liens internes sont relatifs et fonctionnent hors ligne.

**Export PDF** : Cette documentation peut être concaténée en un seul PDF pour une lecture hors ligne.

---

## Statut du projet

**Fonctionnalités complètes** : Toutes les règles de consensus, le minage, les assignations et les fonctionnalités du portefeuille sont implémentés.

**Documentation complète** : Les 8 chapitres sont complets et vérifiés par rapport au code source.

**Testnet actif** : Actuellement en phase testnet pour les tests communautaires.

---

## Contribuer

Les contributions à la documentation sont les bienvenues. Veuillez maintenir :
- La précision technique plutôt que la verbosité
- Des explications brèves et directes
- Aucun code ou pseudo-code dans la documentation (référencer les fichiers sources à la place)
- Uniquement ce qui est implémenté (pas de fonctionnalités spéculatives)

---

## Licence

Bitcoin-PoCX hérite de la licence MIT de Bitcoin Core. Voir `COPYING` à la racine du dépôt.

Attribution du framework PoCX Core documentée dans le [Chapitre 2 : Format Plot](2-plot-format.md).

---

**Commencer la lecture** : [Chapitre 1 : Introduction et présentation →](1-introduction.md)

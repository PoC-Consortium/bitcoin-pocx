[← Précédent : Introduction](1-introduction.md) | [📘 Table des matières](index.md) | [Suivant : Consensus et minage →](3-consensus-and-mining.md)

---

# Chapitre 2 : Spécification du format Plot PoCX

Ce document décrit le format plot PoCX, une version améliorée du format POC2 avec une sécurité renforcée, des optimisations SIMD et une preuve de travail évolutive.

## Aperçu du format

Les fichiers plot PoCX contiennent des valeurs de hachage Shabal256 pré-calculées organisées pour des opérations de minage efficaces. Suivant la tradition PoC depuis POC1, **toutes les métadonnées sont intégrées dans le nom de fichier** — il n'y a pas d'en-tête de fichier.

### Extension de fichier
- **Standard** : `.pocx` (plots terminés)
- **En cours** : `.tmp` (pendant le plotting, renommé en `.pocx` une fois terminé)

## Contexte historique et évolution des vulnérabilités

### Format POC1 (Historique)
**Deux vulnérabilités majeures (compromis temps-mémoire) :**

1. **Défaut de distribution PoW**
   - Distribution non uniforme de la preuve de travail entre les scoops
   - Les numéros de scoop bas pouvaient être calculés à la volée
   - **Impact** : Exigences de stockage réduites pour les attaquants

2. **Attaque par compression XOR** (compromis temps-mémoire de 50 %)
   - Exploitation de propriétés mathématiques pour obtenir une réduction de stockage de 50 %
   - **Impact** : Les attaquants pouvaient miner avec la moitié du stockage requis

**Optimisation de la disposition** : Disposition séquentielle basique des scoops pour l'efficacité des disques durs

### Format POC2 (Burstcoin)
- ✅ **Défaut de distribution PoW corrigé**
- ❌ **Vulnérabilité XOR-transpose non corrigée**
- **Disposition** : Optimisation séquentielle des scoops maintenue

### Format PoCX (Actuel)
- ✅ **Distribution PoW corrigée** (héritée de POC2)
- ✅ **Vulnérabilité XOR-transpose corrigée** (unique à PoCX)
- ✅ **Disposition SIMD/GPU améliorée** optimisée pour le traitement parallèle et la coalescence mémoire
- ✅ **Preuve de travail évolutive** empêche les compromis temps-mémoire à mesure que la puissance de calcul augmente (le PoW n'est effectué que lors de la création ou de la mise à niveau des fichiers plot)

## Encodage XOR-Transpose

### Le problème : compromis temps-mémoire de 50 %

Dans les formats POC1/POC2, les attaquants pouvaient exploiter la relation mathématique entre les scoops pour ne stocker que la moitié des données et calculer le reste à la volée pendant le minage. Cette « attaque par compression XOR » compromettait la garantie de stockage.

### La solution : renforcement XOR-Transpose

PoCX dérive son format de minage (X1) en appliquant un encodage XOR-transpose à des paires de warps de base (X0) :

**Pour construire le scoop S du nonce N dans un warp X1 :**
1. Prendre le scoop S du nonce N du premier warp X0 (position directe)
2. Prendre le scoop N du nonce S du second warp X0 (position transposée)
3. Appliquer XOR aux deux valeurs de 64 octets pour obtenir le scoop X1

L'étape de transposition échange les indices de scoop et de nonce. En termes matriciels — où les lignes représentent les scoops et les colonnes représentent les nonces — elle combine l'élément à la position (S, N) dans le premier warp avec l'élément à (N, S) dans le second.

### Pourquoi cela élimine l'attaque

Le XOR-transpose verrouille chaque scoop avec une ligne entière et une colonne entière des données X0 sous-jacentes. Récupérer un seul scoop X1 nécessite l'accès à des données couvrant les 4096 indices de scoop. Toute tentative de calcul des données manquantes nécessiterait de régénérer 4096 nonces complets plutôt qu'un seul nonce — supprimant la structure de coût asymétrique exploitée par l'attaque XOR.

En conséquence, stocker le warp X1 complet devient la seule stratégie viable sur le plan computationnel pour les mineurs.

## Structure des métadonnées dans le nom de fichier

Toutes les métadonnées de plot sont encodées dans le nom de fichier en utilisant ce format exact :

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Composants du nom de fichier

1. **ACCOUNT_PAYLOAD** (40 caractères hexadécimaux)
   - Payload de compte brut de 20 octets en hexadécimal majuscule
   - Indépendant du réseau (pas d'ID de réseau ni de checksum)
   - Exemple : `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 caractères hexadécimaux)
   - Valeur seed de 32 octets en hexadécimal minuscule
   - **Nouveau dans PoCX** : Seed aléatoire de 32 octets dans le nom de fichier remplace la numérotation consécutive des nonces — empêchant les chevauchements de plots
   - Exemple : `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (nombre décimal)
   - **Nouvelle unité de taille dans PoCX** : Remplace le dimensionnement basé sur les nonces de POC1/POC2
   - **Conception résistante au XOR-transpose** : Chaque warp = exactement 4096 nonces (taille de partition requise pour la transformation résistante au XOR-transpose)
   - **Taille** : 1 warp = 1073741824 octets = 1 Gio (unité pratique)
   - Exemple : `1024` (plot de 1 Tio = 1024 warps)

4. **SCALING** (décimal préfixé par X)
   - Niveau de mise à l'échelle sous forme `X{niveau}`
   - Des valeurs plus élevées = plus de preuve de travail requise
   - Exemple : `X4` (2^4 = 16× la difficulté POC2)

### Exemples de noms de fichiers
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Disposition et structure des données du fichier

### Organisation hiérarchique
```
Fichier Plot (PAS D'EN-TÊTE)
├── Scoop 0
│   ├── Warp 0 (Tous les nonces pour ce scoop/warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Constantes et tailles

| Constante       | Taille                  | Description                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 o                    | Sortie de hachage Shabal256 simple              |
| **SCOOP\_SIZE** | 64 o (2 × HASH\_SIZE)   | Paire de hachages lue lors d'un tour de minage  |
| **NUM\_SCOOPS** | 4096 (2¹²)              | Scoops par nonce ; un sélectionné par tour      |
| **NONCE\_SIZE** | 262144 o (256 Kio)      | Tous les scoops d'un nonce (plus petite unité PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 o (1 Gio)    | Plus petite unité dans PoCX                     |

### Disposition de fichier Plot optimisée SIMD

PoCX implémente un motif d'accès aux nonces compatible SIMD qui permet le traitement vectorisé de plusieurs nonces simultanément. Il s'appuie sur les concepts de la [recherche d'optimisation POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) pour maximiser le débit mémoire et l'efficacité SIMD.

---

#### Disposition séquentielle traditionnelle

Stockage séquentiel des nonces :

```
[Nonce 0: Données Scoop] [Nonce 1: Données Scoop] [Nonce 2: Données Scoop] ...
```

Inefficacité SIMD : Chaque voie SIMD a besoin du même mot à travers les nonces :

```
Mot 0 du Nonce 0 -> décalage 0
Mot 0 du Nonce 1 -> décalage 512
Mot 0 du Nonce 2 -> décalage 1024
...
```

L'accès scatter-gather réduit le débit.

---

#### Disposition optimisée SIMD de PoCX

PoCX stocke les **positions de mot à travers 16 nonces** de manière contiguë :

```
Ligne de cache (64 octets) :

Mot0_N0 Mot0_N1 Mot0_N2 ... Mot0_N15
Mot1_N0 Mot1_N1 Mot1_N2 ... Mot1_N15
...
```

**Diagramme ASCII**

```
Disposition traditionnelle :

Nonce0: [M0][M1][M2][M3]...
Nonce1: [M0][M1][M2][M3]...
Nonce2: [M0][M1][M2][M3]...

Disposition PoCX :

Mot0: [N0][N1][N2][N3]...[N15]
Mot1: [N0][N1][N2][N3]...[N15]
Mot2: [N0][N1][N2][N3]...[N15]
```

---

#### Avantages d'accès mémoire

- Une ligne de cache alimente toutes les voies SIMD.
- Élimine les opérations scatter-gather.
- Réduit les défauts de cache.
- Accès mémoire entièrement séquentiel pour le calcul vectorisé.
- Les GPU bénéficient également de l'alignement sur 16 nonces, maximisant l'efficacité du cache.

---

#### Mise à l'échelle SIMD

| SIMD       | Largeur vectorielle* | Nonces | Cycles de traitement par ligne de cache |
|------------|----------------------|--------|-----------------------------------------|
| SSE2/AVX   | 128 bits             | 4      | 4 cycles                                |
| AVX2       | 256 bits             | 8      | 2 cycles                                |
| AVX512     | 512 bits             | 16     | 1 cycle                                 |

\* Pour les opérations sur entiers

---



## Mise à l'échelle de la preuve de travail

### Niveaux de mise à l'échelle
- **X0** : Nonces de base sans encodage XOR-transpose (théorique, non utilisé pour le minage)
- **X1** : Ligne de base XOR-transpose — premier format renforcé (1× travail)
- **X2** : 2× travail X1 (XOR à travers 2 warps)
- **X3** : 4× travail X1 (XOR à travers 4 warps)
- **…**
- **Xn** : 2^(n-1) × travail X1 intégré

### Avantages
- **Difficulté PoW ajustable** : Augmente les exigences computationnelles pour suivre l'évolution du matériel
- **Longévité du format** : Permet une mise à l'échelle flexible de la difficulté de minage au fil du temps

### Mise à niveau de plot / Rétrocompatibilité

Lorsque le réseau augmente l'échelle PoW (Proof of Work) de 1, les plots existants nécessitent une mise à niveau pour maintenir la même taille effective de plot. Essentiellement, vous avez maintenant besoin de deux fois plus de PoW dans vos fichiers plot pour obtenir la même contribution à votre compte.

La bonne nouvelle est que le PoW que vous avez déjà effectué lors de la création de vos fichiers plot n'est pas perdu — vous devez simplement ajouter du PoW supplémentaire aux fichiers existants. Pas besoin de refaire le plotting.

Alternativement, vous pouvez continuer à utiliser vos plots actuels sans mise à niveau, mais notez qu'ils ne contribueront plus qu'à 50 % de leur taille effective précédente vers votre compte. Votre logiciel de minage peut mettre à l'échelle un fichier plot à la volée.

## Comparaison avec les formats historiques

| Fonctionnalité | POC1 | POC2 | PoCX |
|----------------|------|------|------|
| Distribution PoW | ❌ Défectueuse | ✅ Corrigée | ✅ Corrigée |
| Résistance XOR-Transpose | ❌ Vulnérable | ❌ Vulnérable | ✅ Corrigée |
| Optimisation SIMD | ❌ Aucune | ❌ Aucune | ✅ Avancée |
| Optimisation GPU | ❌ Aucune | ❌ Aucune | ✅ Optimisée |
| Preuve de travail évolutive | ❌ Aucune | ❌ Aucune | ✅ Oui |
| Support Seed | ❌ Aucun | ❌ Aucun | ✅ Oui |

Le format PoCX représente l'état de l'art actuel des formats de plot de preuve de capacité, corrigeant toutes les vulnérabilités connues tout en fournissant des améliorations de performance significatives pour le matériel moderne.

## Références et lectures complémentaires

- **Contexte POC1/POC2** : [Aperçu du minage Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Guide complet des formats traditionnels de minage par preuve de capacité
- **Recherche POC2×16** : [Annonce CIP : POC2×16 - Un nouveau format de plot optimisé](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Recherche originale sur l'optimisation SIMD qui a inspiré PoCX
- **Algorithme de hachage Shabal** : [Le projet Saphir : Shabal, une soumission au concours d'algorithme de hachage cryptographique du NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Spécification technique de l'algorithme Shabal256 utilisé dans le minage PoC

---

[← Précédent : Introduction](1-introduction.md) | [📘 Table des matières](index.md) | [Suivant : Consensus et minage →](3-consensus-and-mining.md)

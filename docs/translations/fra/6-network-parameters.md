[← Précédent : Synchronisation temporelle](5-timing-security.md) | [📘 Table des matières](index.md) | [Suivant : Référence RPC →](7-rpc-reference.md)

---

# Chapitre 6 : Paramètres réseau et configuration

Référence complète pour la configuration réseau Bitcoin-PoCX sur tous les types de réseaux.

---

## Table des matières

1. [Paramètres du bloc Genesis](#paramètres-du-bloc-genesis)
2. [Configuration Chainparams](#configuration-chainparams)
3. [Paramètres de consensus](#paramètres-de-consensus)
4. [Coinbase et récompenses de bloc](#coinbase-et-récompenses-de-bloc)
5. [Mise à l'échelle dynamique](#mise-à-léchelle-dynamique)
6. [Configuration réseau](#configuration-réseau)
7. [Structure du répertoire de données](#structure-du-répertoire-de-données)

---

## Paramètres du bloc Genesis

### Calcul de la cible de base

**Formule** : `genesis_base_target = 2^42 / block_time_seconds`

**Justification** :
- Chaque nonce représente 256 Kio (64 octets × 4096 scoops)
- 1 Tio = 2^22 nonces (hypothèse de capacité réseau de départ)
- Qualité minimale attendue pour n nonces ≈ 2^64 / n
- Pour 1 Tio : E(qualité) = 2^64 / 2^22 = 2^42
- Donc : base_target = 2^42 / block_time

**Valeurs calculées** :
- Mainnet/Testnet/Signet (120s) : `36650387592`
- Regtest (1s) : Utilise le mode de calibrage basse capacité

### Message Genesis

Each network has its own genesis message. See `src/kernel/chainparams.cpp` for details.

---

## Configuration Chainparams

### Paramètres Mainnet

**Identité réseau** :
- **Octets magiques** : `0xa7 0x3c 0x91 0x5e`
- **Port par défaut** : `8338`
- **HRP Bech32** : `pocx`

**Préfixes d'adresse** (Base58) :
- PUBKEY_ADDRESS : `85` (adresses commençant par 'P')
- SCRIPT_ADDRESS : `90` (adresses commençant par 'R')
- SECRET_KEY : `128`

**Timing des blocs** :
- **Temps de bloc cible** : `120` secondes (2 minutes)
- **Durée cible** : `1209600` secondes (14 jours)
- **MAX_FUTURE_BLOCK_TIME** : `15` secondes

**Récompenses de bloc** :
- **Subvention initiale** : `10 BTC`
- **Intervalle de halving** : `1050000` blocs (~4 ans)
- **Nombre de halvings** : 64 halvings maximum

**Ajustement de difficulté** :
- **Fenêtre glissante** : `24` blocs
- **Ajustement** : À chaque bloc
- **Algorithme** : Moyenne mobile exponentielle

**Délais d'assignation** :
- **Activation** : `30` blocs (~1 heure)
- **Révocation** : `720` blocs (~24 heures)

### Paramètres Testnet

**Identité réseau** :
- **Octets magiques** : `0x6d 0xf2 0x48 0xb4`
- **Port par défaut** : `18338`
- **HRP Bech32** : `tpocx`

**Préfixes d'adresse** (Base58) :
- PUBKEY_ADDRESS : `127`
- SCRIPT_ADDRESS : `132`
- SECRET_KEY : `255`

**Timing des blocs** :
- **Temps de bloc cible** : `120` secondes
- **MAX_FUTURE_BLOCK_TIME** : `15` secondes
- **Autoriser difficulté min** : `true`

**Récompenses de bloc** :
- **Subvention initiale** : `10 BTC`
- **Intervalle de halving** : `1050000` blocs

**Ajustement de difficulté** :
- **Fenêtre glissante** : `24` blocs

**Délais d'assignation** :
- **Activation** : `30` blocs (~1 heure)
- **Révocation** : `720` blocs (~24 heures)

### Paramètres Regtest

**Identité réseau** :
- **Octets magiques** : `0xfa 0xbf 0xb5 0xda`
- **Port par défaut** : `18444`
- **HRP Bech32** : `rpocx`

**Préfixes d'adresse** (compatibles Bitcoin) :
- PUBKEY_ADDRESS : `111`
- SCRIPT_ADDRESS : `196`
- SECRET_KEY : `239`

**Timing des blocs** :
- **Temps de bloc cible** : `1` seconde (minage instantané pour les tests)
- **Durée cible** : `86400` secondes (1 jour)
- **MAX_FUTURE_BLOCK_TIME** : `15` secondes

**Récompenses de bloc** :
- **Subvention initiale** : `10 BTC`
- **Intervalle de halving** : `500` blocs

**Ajustement de difficulté** :
- **Fenêtre glissante** : `24` blocs
- **Autoriser difficulté min** : `true`
- **Pas de reciblage** : `true`
- **Calibrage basse capacité** : `true` (utilise un calibrage de 16 nonces au lieu de 1 Tio)

**Délais d'assignation** :
- **Activation** : `4` blocs (~4 secondes)
- **Révocation** : `8` blocs (~8 secondes)

### Paramètres Signet

**Identité réseau** :
- **Octets magiques** : Premiers 4 octets de SHA256d(signet_challenge)
- **Port par défaut** : `38333`
- **HRP Bech32** : `tpocx`

**Timing des blocs** :
- **Temps de bloc cible** : `120` secondes
- **MAX_FUTURE_BLOCK_TIME** : `15` secondes

**Récompenses de bloc** :
- **Subvention initiale** : `10 BTC`
- **Intervalle de halving** : `1050000` blocs

**Ajustement de difficulté** :
- **Fenêtre glissante** : `24` blocs

---

## Paramètres de consensus

### Paramètres temporels

**MAX_FUTURE_BLOCK_TIME** : `15` secondes
- Spécifique à PoCX (Bitcoin utilise 2 heures)
- Justification : Le timing PoC nécessite une validation quasi temps réel
- Les blocs de plus de 15s dans le futur sont rejetés

**Avertissement de décalage temporel** : `10` secondes
- Les opérateurs sont avertis quand l'horloge du nœud dérive de >10s par rapport au temps réseau
- Aucune application, informatif uniquement

**Temps de bloc cibles** :
- Mainnet/Testnet/Signet : `120` secondes
- Regtest : `1` seconde

**TIMESTAMP_WINDOW** : `15` secondes (égal à MAX_FUTURE_BLOCK_TIME)

**Implémentation** : `src/chain.h`, `src/validation.cpp`

### Paramètres d'ajustement de difficulté

**Taille de fenêtre glissante** : `24` blocs (tous les réseaux)
- Moyenne mobile exponentielle des temps de bloc récents
- Ajustement à chaque bloc
- Réactif aux changements de capacité

**Implémentation** : `src/consensus/params.h`, logique de difficulté dans la création de bloc

### Paramètres du système d'assignation

**nForgingAssignmentDelay** (délai d'activation) :
- Mainnet : `30` blocs (~1 heure)
- Testnet : `30` blocs (~1 heure)
- Regtest : `4` blocs (~4 secondes)

**nForgingRevocationDelay** (délai de révocation) :
- Mainnet : `720` blocs (~24 heures)
- Testnet : `720` blocs (~24 heures)
- Regtest : `8` blocs (~8 secondes)

**Justification** :
- Le délai d'activation empêche la réassignation rapide pendant les courses de blocs
- Le délai de révocation fournit stabilité et empêche les abus

**Implémentation** : `src/consensus/params.h`

---

## Coinbase et récompenses de bloc

### Calendrier de subvention de bloc

**Subvention initiale** : `10 BTC` (tous les réseaux)

**Calendrier de halving** :
- Tous les `1050000` blocs (mainnet/testnet)
- Tous les `500` blocs (regtest)
- Continue pendant 64 halvings maximum

**Progression des halvings** :
```
Halving 0 : 10,00000000 BTC  (blocs 0 - 1049999)
Halving 1 :  5,00000000 BTC  (blocs 1050000 - 2099999)
Halving 2 :  2,50000000 BTC  (blocs 2100000 - 3149999)
Halving 3 :  1,25000000 BTC  (blocs 3150000 - 4199999)
...
```

**Offre totale** : ~21 millions BTC (identique à Bitcoin)

### Règles de sortie coinbase

**Destination de paiement** :
- **Sans assignation** : Le coinbase paie l'adresse de plot (proof.account_id)
- **Avec assignation** : Le coinbase paie l'adresse de forge (signataire effectif)

**Format de sortie** : P2WPKH uniquement
- Le coinbase doit payer à une adresse bech32 SegWit v0
- Générée depuis la clé publique du signataire effectif

**Résolution d'assignation** :
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implémentation** : `src/pocx/mining/block_builder.cpp:BuildBlock()`

---

## Mise à l'échelle dynamique

### Bornes de mise à l'échelle

**Objectif** : Augmenter la difficulté de génération de plot à mesure que le réseau mûrit pour empêcher l'inflation de capacité

**Structure** :
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Niveau minimum accepté
    uint32_t nPoCXTargetCompression;  // Niveau recommandé
};
```

**Relation** : `target = min + 1` (toujours un niveau au-dessus du minimum)

### Calendrier d'augmentation de la mise à l'échelle

Les niveaux de mise à l'échelle augmentent selon un **calendrier exponentiel** basé sur les intervalles de halving :

| Période | Hauteur de bloc | Halvings | Min | Cible |
|---------|-----------------|----------|-----|-------|
| Années 0-4 | 0 à 1049999 | 0 | X1 | X2 |
| Années 4-12 | 1050000 à 3149999 | 1-2 | X2 | X3 |
| Années 12-28 | 3150000 à 7349999 | 3-6 | X3 | X4 |
| Années 28-60 | 7350000 à 15749999 | 7-14 | X4 | X5 |
| Années 60-124 | 15750000 à 32549999 | 15-30 | X5 | X6 |
| Années 124+ | 32550000+ | 31+ | X6 | X7 |

**Hauteurs clés** (années → halvings → blocs) :
- Année 4 : Halving 1 au bloc 1050000
- Année 12 : Halving 3 au bloc 3150000
- Année 28 : Halving 7 au bloc 7350000
- Année 60 : Halving 15 au bloc 15750000
- Année 124 : Halving 31 au bloc 32550000

### Difficulté de niveau de mise à l'échelle

**Mise à l'échelle PoW** :
- Niveau de mise à l'échelle X0 : Ligne de base POC2 (théorique)
- Niveau de mise à l'échelle X1 : Ligne de base XOR-transpose
- Niveau de mise à l'échelle Xn : 2^(n-1) × travail X1 intégré
- Chaque niveau double le travail de génération de plot

**Alignement économique** :
- Les récompenses de bloc diminuent de moitié → la difficulté de génération de plot augmente
- Maintient la marge de sécurité : coût de création de plot > coût de consultation
- Empêche l'inflation de capacité due aux améliorations matérielles

### Validation de plot

**Règles de validation** :
- Les preuves soumises doivent avoir un niveau de mise à l'échelle ≥ minimum
- Les preuves avec mise à l'échelle > cible sont acceptées mais inefficaces
- Les preuves en dessous du minimum : rejetées (PoW insuffisant)

**Récupération des bornes** :
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implémentation** : `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configuration réseau

### Nœuds seed et seeds DNS

**Statut** : Actif (réseau principal en service depuis le 3 mai 2026)

**Seeds DNS du réseau principal** :
- `seeds.bitcoin-pocx.org`
- `bitcoin-pocx.bootseed.net`

**Seeds DNS du testnet** :
- `testnet.seeds.bitcoin-pocx.org`

**Configuration** :
- Seeds fixes fournis dans `src/pocx/pocx_seeds.h` (format BIP155)
- Connexions manuelles aux pairs également supportées via `-addnode`

**Implémentation** : `src/kernel/chainparams.cpp`

### Points de contrôle

**Point de contrôle Genesis** : Toujours bloc 0

**Points de contrôle supplémentaires** : Aucun actuellement configuré

**Futur** : Des points de contrôle seront ajoutés à mesure que le mainnet progresse

---

## Configuration du protocole P2P

### Version du protocole

**Base** : Protocole Bitcoin Core v30.2
- **Version du protocole** : Héritée de Bitcoin Core
- **Bits de service** : Services Bitcoin standard
- **Types de messages** : Messages P2P Bitcoin standard

**Extensions PoCX** :
- Les en-têtes de bloc incluent des champs spécifiques à PoCX
- Les messages de bloc incluent des données de preuve PoCX
- Les règles de validation appliquent le consensus PoCX

**Compatibilité** : Les nœuds PoCX sont incompatibles avec les nœuds Bitcoin PoW (consensus différent)

**Implémentation** : `src/protocol.h`, `src/net_processing.cpp`

---

## Structure du répertoire de données

### Répertoire par défaut

**Emplacement** : `.bitcoin/` (identique à Bitcoin Core)
- Linux : `~/.bitcoin/`
- macOS : `~/Library/Application Support/Bitcoin/`
- Windows : `%APPDATA%\Bitcoin\`

### Contenu du répertoire

```
.bitcoin/
├── blocks/              # Données de bloc
│   ├── blk*.dat        # Fichiers de bloc
│   ├── rev*.dat        # Données d'annulation
│   └── index/          # Index de bloc (LevelDB)
├── chainstate/         # Ensemble UTXO + assignations de forge (LevelDB)
├── wallets/            # Fichiers de portefeuille
│   └── wallet.dat      # Portefeuille par défaut
├── bitcoin.conf        # Fichier de configuration
├── debug.log           # Log de débogage
├── peers.dat           # Adresses des pairs
├── mempool.dat         # Persistance du mempool
└── banlist.dat         # Pairs bannis
```

### Différences clés par rapport à Bitcoin

**Base de données Chainstate** :
- Standard : Ensemble UTXO
- **Ajout PoCX** : État d'assignation de forge
- Mises à jour atomiques : UTXO + assignations mises à jour ensemble
- Données d'annulation sécurisées pour les réorgs pour les assignations

**Fichiers de bloc** :
- Format de bloc Bitcoin standard
- **Ajout PoCX** : Étendu avec les champs de preuve PoCX (account_id, seed, nonce, signature, pubkey)

### Exemple de fichier de configuration

**bitcoin.conf** :
```ini
# Sélection réseau
#testnet=1
#regtest=1

# Serveur de minage PoCX (requis pour les mineurs externes)

# Paramètres RPC
server=1
rpcuser=votre_nom_utilisateur
rpcpassword=votre_mot_de_passe
rpcallowip=127.0.0.1
rpcport=8332

# Paramètres de connexion
listen=1
port=8338
maxconnections=125

# Temps de bloc cible (informatif, appliqué par le consensus)
# 120 secondes pour mainnet/testnet
```

---

## Références de code

**Chainparams** : `src/kernel/chainparams.cpp`
**Paramètres de consensus** : `src/consensus/params.h`
**Bornes de compression** : `src/pocx/consensus/params.h`, `src/pocx/consensus/params.cpp`
**Calcul de cible de base Genesis** : `src/pocx/consensus/params.cpp`
**Logique de paiement coinbase** : `src/pocx/mining/block_builder.cpp:BuildBlock()`
**Stockage d'état d'assignation** : `src/coins.h`, `src/coins.cpp` (extensions CCoinsViewCache)

---

## Références croisées

Chapitres connexes :
- [Chapitre 2 : Format Plot](2-plot-format.md) - Niveaux de mise à l'échelle dans la génération de plot
- [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md) - Validation de mise à l'échelle, système d'assignation
- [Chapitre 4 : Assignations de forge](4-forging-assignments.md) - Paramètres de délai d'assignation
- [Chapitre 5 : Sécurité temporelle](5-timing-security.md) - Justification de MAX_FUTURE_BLOCK_TIME

---

[← Précédent : Synchronisation temporelle](5-timing-security.md) | [📘 Table des matières](index.md) | [Suivant : Référence RPC →](7-rpc-reference.md)

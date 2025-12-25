[← Précédent : Référence RPC](7-rpc-reference.md) | [📘 Table des matières](index.md)

---

# Chapitre 8 : Guide utilisateur du portefeuille et de l'interface graphique

Guide complet du portefeuille Qt Bitcoin-PoCX et de la gestion des assignations de forge.

---

## Table des matières

1. [Aperçu](#aperçu)
2. [Unités de devise](#unités-de-devise)
3. [Dialogue d'assignation de forge](#dialogue-dassignation-de-forge)
4. [Historique des transactions](#historique-des-transactions)
5. [Exigences d'adresse](#exigences-dadresse)
6. [Intégration du minage](#intégration-du-minage)
7. [Dépannage](#dépannage)
8. [Bonnes pratiques de sécurité](#bonnes-pratiques-de-sécurité)

---

## Aperçu

### Fonctionnalités du portefeuille Bitcoin-PoCX

Le portefeuille Qt Bitcoin-PoCX (`bitcoin-qt`) fournit :
- Fonctionnalités standard du portefeuille Bitcoin Core (envoi, réception, gestion des transactions)
- **Gestionnaire d'assignation de forge** : Interface graphique pour créer/révoquer les assignations de plot
- **Mode serveur de minage** : L'option `-miningserver` active les fonctionnalités liées au minage
- **Historique des transactions** : Affichage des transactions d'assignation et de révocation

### Démarrage du portefeuille

**Nœud uniquement** (sans minage) :
```bash
./build/bin/bitcoin-qt
```

**Avec minage** (active le dialogue d'assignation) :
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternative en ligne de commande** :
```bash
./build/bin/bitcoind -miningserver
```

### Exigences de minage

**Pour les opérations de minage** :
- Option `-miningserver` requise
- Portefeuille avec adresses P2WPKH et clés privées
- Plotter externe (`pocx_plotter`) pour la génération de plot
- Mineur externe (`pocx_miner`) pour le minage

**Pour le minage en pool** :
- Créer une assignation de forge vers l'adresse du pool
- Portefeuille non requis sur le serveur du pool (le pool gère les clés)

---

## Unités de devise

### Affichage des unités

Bitcoin-PoCX utilise l'unité de devise **BTCX** (pas BTC) :

| Unité | Satoshis | Affichage |
|-------|----------|-----------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **µBTCX** | 100 | 1000000,00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Paramètres de l'interface** : Préférences → Affichage → Unité

---

## Dialogue d'assignation de forge

### Accès au dialogue

**Menu** : `Portefeuille → Assignations de forge`
**Barre d'outils** : Icône de minage (visible uniquement avec l'option `-miningserver`)
**Taille de fenêtre** : 600×450 pixels

### Modes du dialogue

#### Mode 1 : Créer une assignation

**Objectif** : Déléguer les droits de forge à un pool ou une autre adresse tout en conservant la propriété du plot.

**Cas d'utilisation** :
- Minage en pool (assigner à l'adresse du pool)
- Stockage à froid (clé de minage séparée de la propriété du plot)
- Infrastructure partagée (déléguer à un portefeuille chaud)

**Exigences** :
- Adresse de plot (P2WPKH bech32, doit posséder la clé privée)
- Adresse de forge (P2WPKH bech32, différente de l'adresse de plot)
- Portefeuille déverrouillé (si chiffré)
- L'adresse de plot a des UTXOs confirmés

**Étapes** :
1. Sélectionner le mode « Créer une assignation »
2. Choisir l'adresse de plot dans la liste déroulante ou entrer manuellement
3. Entrer l'adresse de forge (pool ou délégué)
4. Cliquer sur « Envoyer l'assignation » (bouton activé quand les entrées sont valides)
5. Transaction diffusée immédiatement
6. Assignation active après `nForgingAssignmentDelay` blocs :
   - Mainnet/Testnet : 30 blocs (~1 heure)
   - Regtest : 4 blocs (~4 secondes)

**Frais de transaction** : Par défaut 10× `minRelayFee` (personnalisable)

**Structure de transaction** :
- Entrée : UTXO de l'adresse de plot (prouve la propriété)
- Sortie OP_RETURN : marqueur `POCX` + plot_address + forging_address (46 octets)
- Sortie de change : Retourné au portefeuille

#### Mode 2 : Révoquer une assignation

**Objectif** : Annuler l'assignation de forge et retourner les droits au propriétaire du plot.

**Exigences** :
- Adresse de plot (doit posséder la clé privée)
- Portefeuille déverrouillé (si chiffré)
- L'adresse de plot a des UTXOs confirmés

**Étapes** :
1. Sélectionner le mode « Révoquer l'assignation »
2. Choisir l'adresse de plot
3. Cliquer sur « Envoyer la révocation »
4. Transaction diffusée immédiatement
5. Révocation effective après `nForgingRevocationDelay` blocs :
   - Mainnet/Testnet : 720 blocs (~24 heures)
   - Regtest : 8 blocs (~8 secondes)

**Effet** :
- L'adresse de forge peut encore forger pendant la période de délai
- Le propriétaire du plot retrouve ses droits après que la révocation soit terminée
- Peut créer une nouvelle assignation ensuite

**Structure de transaction** :
- Entrée : UTXO de l'adresse de plot (prouve la propriété)
- Sortie OP_RETURN : marqueur `XCOP` + plot_address (26 octets)
- Sortie de change : Retourné au portefeuille

#### Mode 3 : Vérifier le statut d'assignation

**Objectif** : Interroger l'état d'assignation actuel pour n'importe quelle adresse de plot.

**Exigences** : Aucune (lecture seule, pas de portefeuille nécessaire)

**Étapes** :
1. Sélectionner le mode « Vérifier le statut d'assignation »
2. Entrer l'adresse de plot
3. Cliquer sur « Vérifier le statut »
4. La boîte de statut affiche l'état actuel avec les détails

**Indicateurs d'état** (code couleur) :

**Gris - UNASSIGNED**
```
UNASSIGNED - Aucune assignation n'existe
```

**Orange - ASSIGNING**
```
ASSIGNING - Assignation en attente d'activation
Adresse de forge : pocx1qforger...
Créée à la hauteur : 12000
S'active à la hauteur : 12030 (5 blocs restants)
```

**Vert - ASSIGNED**
```
ASSIGNED - Assignation active
Adresse de forge : pocx1qforger...
Créée à la hauteur : 12000
Activée à la hauteur : 12030
```

**Rouge-orange - REVOKING**
```
REVOKING - Révocation en attente
Adresse de forge : pocx1qforger... (toujours active)
Assignation créée à la hauteur : 12000
Révoquée à la hauteur : 12300
Révocation effective à la hauteur : 13020 (50 blocs restants)
```

**Rouge - REVOKED**
```
REVOKED - Assignation révoquée
Précédemment assignée à : pocx1qforger...
Assignation créée à la hauteur : 12000
Révoquée à la hauteur : 12300
Révocation effective à la hauteur : 13020
```

---

## Historique des transactions

### Affichage des transactions d'assignation

**Type** : « Assignation »
**Icône** : Icône de minage (identique aux blocs minés)

**Colonne Adresse** : Adresse de plot (adresse dont les droits de forge sont assignés)
**Colonne Montant** : Frais de transaction (négatif, transaction sortante)
**Colonne Statut** : Nombre de confirmations (0-6+)

**Détails** (au clic) :
- ID de transaction
- Adresse de plot
- Adresse de forge (parsée depuis l'OP_RETURN)
- Créée à la hauteur
- Hauteur d'activation
- Frais de transaction
- Horodatage

### Affichage des transactions de révocation

**Type** : « Révocation »
**Icône** : Icône de minage

**Colonne Adresse** : Adresse de plot
**Colonne Montant** : Frais de transaction (négatif)
**Colonne Statut** : Nombre de confirmations

**Détails** (au clic) :
- ID de transaction
- Adresse de plot
- Révoquée à la hauteur
- Hauteur effective de révocation
- Frais de transaction
- Horodatage

### Filtrage des transactions

**Filtres disponibles** :
- « Toutes » (par défaut, inclut assignations/révocations)
- Plage de dates
- Plage de montants
- Recherche par adresse
- Recherche par ID de transaction
- Recherche par libellé (si adresse libellée)

**Note** : Les transactions d'assignation/révocation apparaissent actuellement sous le filtre « Toutes ». Le filtre par type dédié n'est pas encore implémenté.

### Tri des transactions

**Ordre de tri** (par type) :
- Générée (type 0)
- Reçue (type 1-3)
- Assignation (type 4)
- Révocation (type 5)
- Envoyée (type 6+)

---

## Exigences d'adresse

### P2WPKH (SegWit v0) uniquement

**Les opérations de forge nécessitent** :
- Adresses encodées bech32 (commençant par « pocx1q » mainnet, « tpocx1q » testnet, « rpocx1q » regtest)
- Format P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hachage de clé de 20 octets

**NON supporté** :
- P2PKH (legacy, commençant par « 1 »)
- P2SH (SegWit enveloppé, commençant par « 3 »)
- P2TR (Taproot, commençant par « bc1p »)

**Justification** : Les signatures de bloc PoCX nécessitent le format witness v0 spécifique pour la validation de preuve.

### Filtrage de la liste déroulante d'adresses

**ComboBox d'adresse de plot** :
- Automatiquement peuplée avec les adresses de réception du portefeuille
- Filtre les adresses non-P2WPKH
- Affiche le format : « Libellé (adresse) » si libellée, sinon juste l'adresse
- Premier élément : « -- Entrer une adresse personnalisée -- » pour la saisie manuelle

**Saisie manuelle** :
- Valide le format à la saisie
- Doit être un P2WPKH bech32 valide
- Bouton désactivé si format invalide

### Messages d'erreur de validation

**Erreurs du dialogue** :
- « L'adresse de plot doit être P2WPKH (bech32) »
- « L'adresse de forge doit être P2WPKH (bech32) »
- « Format d'adresse invalide »
- « Aucun coin disponible à l'adresse de plot. Impossible de prouver la propriété. »
- « Impossible de créer des transactions avec un portefeuille en lecture seule »
- « Portefeuille non disponible »
- « Portefeuille verrouillé » (depuis RPC)

---

## Intégration du minage

### Exigences de configuration

**Configuration du nœud** :
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Exigences du portefeuille** :
- Adresses P2WPKH pour la propriété du plot
- Clés privées pour le minage (ou adresse de forge si utilisation des assignations)
- UTXOs confirmés pour la création de transaction

**Outils externes** :
- `pocx_plotter` : Générer les fichiers plot
- `pocx_miner` : Scanner les plots et soumettre les nonces

### Flux de travail

#### Minage solo

1. **Générer les fichiers Plot** :
   ```bash
   pocx_plotter --account <hash160_adresse_plot> --seed <32_octets> --nonces <nombre>
   ```

2. **Démarrer le nœud** avec le serveur de minage :
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configurer le mineur** :
   - Pointer vers le point de terminaison RPC du nœud
   - Spécifier les répertoires de fichiers plot
   - Configurer l'ID de compte (depuis l'adresse de plot)

4. **Démarrer le minage** :
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /chemin/vers/plots
   ```

5. **Surveiller** :
   - Le mineur appelle `get_mining_info` à chaque bloc
   - Scanne les plots pour la meilleure deadline
   - Appelle `submit_nonce` quand une solution est trouvée
   - Le nœud valide et forge le bloc automatiquement

#### Minage en pool

1. **Générer les fichiers Plot** (identique au minage solo)

2. **Créer l'assignation de forge** :
   - Ouvrir le dialogue d'assignation de forge
   - Sélectionner l'adresse de plot
   - Entrer l'adresse de forge du pool
   - Cliquer sur « Envoyer l'assignation »
   - Attendre le délai d'activation (30 blocs testnet)

3. **Configurer le mineur** :
   - Pointer vers le point de terminaison du **pool** (pas le nœud local)
   - Le pool gère le `submit_nonce` vers la chaîne

4. **Fonctionnement du pool** :
   - Le portefeuille du pool a les clés privées de l'adresse de forge
   - Le pool valide les soumissions des mineurs
   - Le pool appelle `submit_nonce` vers la blockchain
   - Le pool distribue les récompenses selon la politique du pool

### Récompenses coinbase

**Sans assignation** :
- Le coinbase paie directement l'adresse du propriétaire du plot
- Vérifier le solde dans l'adresse de plot

**Avec assignation** :
- Le coinbase paie l'adresse de forge
- Le pool reçoit les récompenses
- Le mineur reçoit sa part du pool

**Calendrier des récompenses** :
- Initial : 10 BTCX par bloc
- Halving : Tous les 1050000 blocs (~4 ans)
- Calendrier : 10 → 5 → 2,5 → 1,25 → ...

---

## Dépannage

### Problèmes courants

#### « Le portefeuille n'a pas la clé privée pour l'adresse de plot »

**Cause** : Le portefeuille ne possède pas l'adresse
**Solution** :
- Importer la clé privée via le RPC `importprivkey`
- Ou utiliser une autre adresse de plot possédée par le portefeuille

#### « Une assignation existe déjà pour ce plot »

**Cause** : Le plot est déjà assigné à une autre adresse
**Solution** :
1. Révoquer l'assignation existante
2. Attendre le délai de révocation (720 blocs testnet)
3. Créer une nouvelle assignation

#### « Format d'adresse non supporté »

**Cause** : L'adresse n'est pas P2WPKH bech32
**Solution** :
- Utiliser des adresses commençant par « pocx1q » (mainnet) ou « tpocx1q » (testnet)
- Générer une nouvelle adresse si nécessaire : `getnewaddress "" "bech32"`

#### « Frais de transaction trop bas »

**Cause** : Congestion du mempool réseau ou frais trop bas pour le relais
**Solution** :
- Augmenter le paramètre de taux de frais
- Attendre que le mempool se vide

#### « Assignation pas encore active »

**Cause** : Le délai d'activation n'est pas encore écoulé
**Solution** :
- Vérifier le statut : blocs restants jusqu'à l'activation
- Attendre que la période de délai soit terminée

#### « Aucun coin disponible à l'adresse de plot »

**Cause** : L'adresse de plot n'a pas d'UTXOs confirmés
**Solution** :
1. Envoyer des fonds à l'adresse de plot
2. Attendre 1 confirmation
3. Réessayer la création d'assignation

#### « Impossible de créer des transactions avec un portefeuille en lecture seule »

**Cause** : Le portefeuille a importé l'adresse sans clé privée
**Solution** : Importer la clé privée complète, pas seulement l'adresse

#### « Onglet Assignation de forge non visible »

**Cause** : Nœud démarré sans l'option `-miningserver`
**Solution** : Redémarrer avec `bitcoin-qt -server -miningserver`

### Étapes de débogage

1. **Vérifier le statut du portefeuille** :
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Vérifier la propriété de l'adresse** :
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Vérifier : "iswatchonly": false, "ismine": true
   ```

3. **Vérifier le statut d'assignation** :
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Voir les transactions récentes** :
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Vérifier la synchronisation du nœud** :
   ```bash
   bitcoin-cli getblockchaininfo
   # Vérifier : blocks == headers (entièrement synchronisé)
   ```

---

## Bonnes pratiques de sécurité

### Sécurité de l'adresse de plot

**Gestion des clés** :
- Stocker les clés privées de l'adresse de plot de manière sécurisée
- Les transactions d'assignation prouvent la propriété via signature
- Seul le propriétaire du plot peut créer/révoquer les assignations

**Sauvegarde** :
- Sauvegarder le portefeuille régulièrement (`dumpwallet` ou `backupwallet`)
- Stocker wallet.dat dans un emplacement sécurisé
- Enregistrer les phrases de récupération si utilisation d'un portefeuille HD

### Délégation de l'adresse de forge

**Modèle de sécurité** :
- L'adresse de forge reçoit les récompenses de bloc
- L'adresse de forge peut signer les blocs (minage)
- L'adresse de forge **ne peut pas** modifier ou révoquer l'assignation
- Le propriétaire du plot conserve le contrôle total

**Cas d'utilisation** :
- **Délégation de portefeuille chaud** : Clé de plot en stockage à froid, clé de forge dans un portefeuille chaud pour le minage
- **Minage en pool** : Déléguer au pool, conserver la propriété du plot
- **Infrastructure partagée** : Plusieurs mineurs, une adresse de forge

### Synchronisation de l'heure réseau

**Importance** :
- Le consensus PoCX nécessite une heure précise
- Une dérive d'horloge >10s déclenche un avertissement
- Une dérive d'horloge >15s empêche le minage

**Solution** :
- Garder l'horloge système synchronisée avec NTP
- Surveiller : `bitcoin-cli getnetworkinfo` pour les avertissements de décalage temporel
- Utiliser des serveurs NTP fiables

### Délais d'assignation

**Délai d'activation** (30 blocs testnet) :
- Empêche la réassignation rapide pendant les forks de chaîne
- Permet au réseau d'atteindre le consensus
- Ne peut pas être contourné

**Délai de révocation** (720 blocs testnet) :
- Fournit de la stabilité pour les pools de minage
- Empêche les attaques de « griefing » par assignation
- L'adresse de forge reste active pendant le délai

### Chiffrement du portefeuille

**Activer le chiffrement** :
```bash
bitcoin-cli encryptwallet "votre_phrase_secrete"
```

**Déverrouiller pour les transactions** :
```bash
bitcoin-cli walletpassphrase "votre_phrase_secrete" 300
```

**Bonnes pratiques** :
- Utiliser une phrase secrète forte (20+ caractères)
- Ne pas stocker la phrase secrète en texte clair
- Verrouiller le portefeuille après avoir créé les assignations

---

## Références de code

**Dialogue d'assignation de forge** : `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Affichage des transactions** : `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsing des transactions** : `src/qt/transactionrecord.cpp`
**Intégration portefeuille** : `src/pocx/assignments/transactions.cpp`
**RPCs d'assignation** : `src/pocx/rpc/assignments_wallet.cpp`
**Interface principale** : `src/qt/bitcoingui.cpp`

---

## Références croisées

Chapitres connexes :
- [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md) - Processus de minage
- [Chapitre 4 : Assignations de forge](4-forging-assignments.md) - Architecture d'assignation
- [Chapitre 6 : Paramètres réseau](6-network-parameters.md) - Valeurs de délai d'assignation
- [Chapitre 7 : Référence RPC](7-rpc-reference.md) - Détails des commandes RPC

---

[← Précédent : Référence RPC](7-rpc-reference.md) | [📘 Table des matières](index.md)

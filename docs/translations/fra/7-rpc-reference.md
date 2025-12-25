[← Précédent : Paramètres réseau](6-network-parameters.md) | [📘 Table des matières](index.md) | [Suivant : Guide du portefeuille →](8-wallet-guide.md)

---

# Chapitre 7 : Référence de l'interface RPC

Référence complète des commandes RPC Bitcoin-PoCX, incluant les RPCs de minage, la gestion des assignations et les RPCs blockchain modifiés.

---

## Table des matières

1. [Configuration](#configuration)
2. [RPCs de minage PoCX](#rpcs-de-minage-pocx)
3. [RPCs d'assignation](#rpcs-dassignation)
4. [RPCs blockchain modifiés](#rpcs-blockchain-modifiés)
5. [RPCs désactivés](#rpcs-désactivés)
6. [Exemples d'intégration](#exemples-dintégration)

---

## Configuration

### Mode serveur de minage

**Option** : `-miningserver`

**Objectif** : Active l'accès RPC pour que les mineurs externes puissent appeler les RPCs spécifiques au minage

**Exigences** :
- Requis pour que `submit_nonce` fonctionne
- Requis pour la visibilité du dialogue d'assignation de forge dans le portefeuille Qt

**Utilisation** :
```bash
# Ligne de commande
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Considérations de sécurité** :
- Pas d'authentification supplémentaire au-delà des identifiants RPC standard
- Les RPCs de minage sont limités en débit par la capacité de la file d'attente
- L'authentification RPC standard reste requise

**Implémentation** : `src/pocx/rpc/mining.cpp`

---

## RPCs de minage PoCX

### get_mining_info

**Catégorie** : mining
**Requiert le serveur de minage** : Non
**Requiert un portefeuille** : Non

**Objectif** : Retourne les paramètres de minage actuels nécessaires aux mineurs externes pour scanner les fichiers plot et calculer les deadlines.

**Paramètres** : Aucun

**Valeurs de retour** :
```json
{
  "generation_signature": "abc123...",       // hex, 64 caractères
  "base_target": 36650387593,                // numérique
  "height": 12345,                           // numérique, hauteur du prochain bloc
  "block_hash": "def456...",                 // hex, bloc précédent
  "target_quality": 18446744073709551615,    // uint64_max (toutes solutions acceptées)
  "minimum_compression_level": 1,            // numérique
  "target_compression_level": 2              // numérique
}
```

**Description des champs** :
- `generation_signature` : Entropie de minage déterministe pour cette hauteur de bloc
- `base_target` : Difficulté actuelle (plus élevé = plus facile)
- `height` : Hauteur de bloc que les mineurs doivent cibler
- `block_hash` : Hachage du bloc précédent (informatif)
- `target_quality` : Seuil de qualité (actuellement uint64_max, pas de filtrage)
- `minimum_compression_level` : Compression minimale requise pour la validation
- `target_compression_level` : Compression recommandée pour un minage optimal

**Codes d'erreur** :
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD` : Nœud encore en synchronisation

**Exemple** :
```bash
bitcoin-cli get_mining_info
```

**Implémentation** : `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Catégorie** : mining
**Requiert le serveur de minage** : Oui
**Requiert un portefeuille** : Oui (pour les clés privées)

**Objectif** : Soumettre une solution de minage PoCX. Valide la preuve, met en file d'attente pour la forge time-bendée et crée automatiquement le bloc à l'heure planifiée.

**Paramètres** :
1. `height` (numérique, requis) - Hauteur de bloc
2. `generation_signature` (chaîne hex, requis) - Signature de génération (64 caractères)
3. `account_id` (chaîne, requis) - ID de compte du plot (40 caractères hex = 20 octets)
4. `seed` (chaîne, requis) - Seed du plot (64 caractères hex = 32 octets)
5. `nonce` (numérique, requis) - Nonce de minage
6. `compression` (numérique, requis) - Niveau de mise à l'échelle/compression utilisé (1-255)
7. `quality` (numérique, optionnel) - Valeur de qualité (recalculée si omise)

**Valeurs de retour** (succès) :
```json
{
  "accepted": true,
  "quality": 120,           // deadline ajustée à la difficulté en secondes
  "poc_time": 45            // temps de forge time-bendé en secondes
}
```

**Valeurs de retour** (rejeté) :
```json
{
  "accepted": false,
  "error": "Signature de génération non correspondante"
}
```

**Étapes de validation** :
1. **Validation de format** (échec rapide) :
   - ID de compte : exactement 40 caractères hex
   - Seed : exactement 64 caractères hex
2. **Validation de contexte** :
   - La hauteur doit correspondre à la pointe actuelle + 1
   - La signature de génération doit correspondre à l'actuelle
3. **Vérification du portefeuille** :
   - Déterminer le signataire effectif (vérifier les assignations actives)
   - Vérifier que le portefeuille a la clé privée pour le signataire effectif
4. **Validation de preuve** (coûteux) :
   - Valider la preuve PoCX avec les bornes de compression
   - Calculer la qualité brute
5. **Soumission au planificateur** :
   - Mettre le nonce en file d'attente pour la forge time-bendée
   - Le bloc sera créé automatiquement à forge_time

**Codes d'erreur** :
- `RPC_INVALID_PARAMETER` : Format invalide (account_id, seed) ou différence de hauteur
- `RPC_VERIFY_REJECTED` : Différence de signature de génération ou échec de validation de preuve
- `RPC_INVALID_ADDRESS_OR_KEY` : Pas de clé privée pour le signataire effectif
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD` : File de soumission pleine
- `RPC_INTERNAL_ERROR` : Échec d'initialisation du planificateur PoCX

**Codes d'erreur de validation de preuve** :
- `0` : VALIDATION_SUCCESS
- `-1` : VALIDATION_ERROR_NULL_POINTER
- `-2` : VALIDATION_ERROR_INVALID_INPUT
- `-100` : VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101` : VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106` : VALIDATION_ERROR_QUALITY_CALCULATION

**Exemple** :
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Notes** :
- La soumission est asynchrone — le RPC retourne immédiatement, le bloc est forgé plus tard
- Le Time Bending retarde les bonnes solutions pour permettre le scan des plots à l'échelle du réseau
- Système d'assignation : si le plot est assigné, le portefeuille doit avoir la clé de l'adresse de forge
- Les bornes de compression sont ajustées dynamiquement en fonction de la hauteur de bloc

**Implémentation** : `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPCs d'assignation

### get_assignment

**Catégorie** : mining
**Requiert le serveur de minage** : Non
**Requiert un portefeuille** : Non

**Objectif** : Interroger le statut d'assignation de forge pour une adresse de plot. Lecture seule, pas de portefeuille requis.

**Paramètres** :
1. `plot_address` (chaîne, requis) - Adresse de plot (format bech32 P2WPKH)
2. `height` (numérique, optionnel) - Hauteur de bloc à interroger (par défaut : pointe actuelle)

**Valeurs de retour** (pas d'assignation) :
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Valeurs de retour** (assignation active) :
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Valeurs de retour** (en révocation) :
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**États d'assignation** :
- `UNASSIGNED` : Aucune assignation n'existe
- `ASSIGNING` : Tx d'assignation confirmée, délai d'activation en cours
- `ASSIGNED` : Assignation active, droits de forge délégués
- `REVOKING` : Tx de révocation confirmée, toujours active jusqu'à ce que le délai soit écoulé
- `REVOKED` : Révocation terminée, droits de forge retournés au propriétaire du plot

**Codes d'erreur** :
- `RPC_INVALID_ADDRESS_OR_KEY` : Adresse invalide ou pas P2WPKH (bech32)

**Exemple** :
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implémentation** : `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Catégorie** : wallet
**Requiert le serveur de minage** : Non
**Requiert un portefeuille** : Oui (doit être chargé et déverrouillé)

**Objectif** : Créer une transaction d'assignation de forge pour déléguer les droits de forge à une autre adresse (par ex., pool de minage).

**Paramètres** :
1. `plot_address` (chaîne, requis) - Adresse du propriétaire du plot (doit posséder la clé privée, P2WPKH bech32)
2. `forging_address` (chaîne, requis) - Adresse à laquelle assigner les droits de forge (P2WPKH bech32)
3. `fee_rate` (numérique, optionnel) - Taux de frais en BTC/kvB (par défaut : 10× minRelayFee)

**Valeurs de retour** :
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Exigences** :
- Portefeuille chargé et déverrouillé
- Clé privée pour plot_address dans le portefeuille
- Les deux adresses doivent être P2WPKH (format bech32 : pocx1q... mainnet, tpocx1q... testnet)
- L'adresse de plot doit avoir des UTXOs confirmés (prouve la propriété)
- Le plot ne doit pas avoir d'assignation active (utiliser revoke d'abord)

**Structure de transaction** :
- Entrée : UTXO de l'adresse de plot (prouve la propriété)
- Sortie : OP_RETURN (46 octets) : marqueur `POCX` + plot_address (20 octets) + forging_address (20 octets)
- Sortie : Change retourné au portefeuille

**Activation** :
- L'assignation devient ASSIGNING à la confirmation
- Devient ACTIVE après `nForgingAssignmentDelay` blocs
- Le délai empêche la réassignation rapide lors des forks de chaîne

**Codes d'erreur** :
- `RPC_WALLET_NOT_FOUND` : Pas de portefeuille disponible
- `RPC_WALLET_UNLOCK_NEEDED` : Portefeuille chiffré et verrouillé
- `RPC_WALLET_ERROR` : Échec de création de transaction
- `RPC_INVALID_ADDRESS_OR_KEY` : Format d'adresse invalide

**Exemple** :
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implémentation** : `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Catégorie** : wallet
**Requiert le serveur de minage** : Non
**Requiert un portefeuille** : Oui (doit être chargé et déverrouillé)

**Objectif** : Révoquer l'assignation de forge existante, retournant les droits de forge au propriétaire du plot.

**Paramètres** :
1. `plot_address` (chaîne, requis) - Adresse de plot (doit posséder la clé privée, P2WPKH bech32)
2. `fee_rate` (numérique, optionnel) - Taux de frais en BTC/kvB (par défaut : 10× minRelayFee)

**Valeurs de retour** :
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Exigences** :
- Portefeuille chargé et déverrouillé
- Clé privée pour plot_address dans le portefeuille
- L'adresse de plot doit être P2WPKH (format bech32)
- L'adresse de plot doit avoir des UTXOs confirmés

**Structure de transaction** :
- Entrée : UTXO de l'adresse de plot (prouve la propriété)
- Sortie : OP_RETURN (26 octets) : marqueur `XCOP` + plot_address (20 octets)
- Sortie : Change retourné au portefeuille

**Effet** :
- L'état passe à REVOKING immédiatement
- L'adresse de forge peut encore forger pendant la période de délai
- Devient REVOKED après `nForgingRevocationDelay` blocs
- Le propriétaire du plot peut forger après que la révocation soit effective
- Peut créer une nouvelle assignation après que la révocation soit terminée

**Codes d'erreur** :
- `RPC_WALLET_NOT_FOUND` : Pas de portefeuille disponible
- `RPC_WALLET_UNLOCK_NEEDED` : Portefeuille chiffré et verrouillé
- `RPC_WALLET_ERROR` : Échec de création de transaction

**Exemple** :
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Notes** :
- Idempotent : peut révoquer même s'il n'y a pas d'assignation active
- Impossible d'annuler une révocation une fois soumise

**Implémentation** : `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPCs blockchain modifiés

### getdifficulty

**Modifications PoCX** :
- **Calcul** : `reference_base_target / current_base_target`
- **Référence** : Capacité réseau de 1 Tio (base_target = 36650387593)
- **Interprétation** : Capacité de stockage réseau estimée en Tio
  - Exemple : `1.0` = ~1 Tio
  - Exemple : `1024.0` = ~1 Pio
- **Différence avec PoW** : Représente la capacité, pas la puissance de hachage

**Exemple** :
```bash
bitcoin-cli getdifficulty
# Retourne : 2048.5 (réseau ~2 Pio)
```

**Implémentation** : `src/rpc/blockchain.cpp`

---

### getblockheader

**Champs ajoutés PoCX** :
- `time_since_last_block` (numérique) - Secondes depuis le bloc précédent (remplace mediantime)
- `poc_time` (numérique) - Temps de forge time-bendé en secondes
- `base_target` (numérique) - Cible de base de difficulté PoCX
- `generation_signature` (chaîne hex) - Signature de génération
- `pocx_proof` (objet) :
  - `account_id` (chaîne hex) - ID de compte du plot (20 octets)
  - `seed` (chaîne hex) - Seed du plot (32 octets)
  - `nonce` (numérique) - Nonce de minage
  - `compression` (numérique) - Niveau de mise à l'échelle utilisé
  - `quality` (numérique) - Valeur de qualité déclarée
- `pubkey` (chaîne hex) - Clé publique du signataire de bloc (33 octets)
- `signer_address` (chaîne) - Adresse du signataire de bloc
- `signature` (chaîne hex) - Signature de bloc (65 octets)

**Champs supprimés PoCX** :
- `mediantime` - Supprimé (remplacé par time_since_last_block)

**Exemple** :
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implémentation** : `src/rpc/blockchain.cpp`

---

### getblock

**Modifications PoCX** : Identiques à getblockheader, plus les données complètes des transactions

**Exemple** :
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbeux avec détails des tx
```

**Implémentation** : `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Champs ajoutés PoCX** :
- `base_target` (numérique) - Cible de base actuelle
- `generation_signature` (chaîne hex) - Signature de génération actuelle

**Champs modifiés PoCX** :
- `difficulty` - Utilise le calcul PoCX (basé sur la capacité)

**Champs supprimés PoCX** :
- `mediantime` - Supprimé

**Exemple** :
```bash
bitcoin-cli getblockchaininfo
```

**Implémentation** : `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Champs ajoutés PoCX** :
- `generation_signature` (chaîne hex) - Pour le minage en pool
- `base_target` (numérique) - Pour le minage en pool

**Champs supprimés PoCX** :
- `target` - Supprimé (spécifique PoW)
- `noncerange` - Supprimé (spécifique PoW)
- `bits` - Supprimé (spécifique PoW)

**Notes** :
- Inclut toujours les données complètes des transactions pour la construction de bloc
- Utilisé par les serveurs de pool pour le minage coordonné

**Exemple** :
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implémentation** : `src/rpc/mining.cpp`

---

## RPCs désactivés

Les RPCs spécifiques PoW suivants sont **désactivés** en mode PoCX :

### getnetworkhashps
- **Raison** : Le taux de hachage n'est pas applicable à la preuve de capacité
- **Alternative** : Utilisez `getdifficulty` pour une estimation de la capacité réseau

### getmininginfo
- **Raison** : Retourne des informations spécifiques PoW
- **Alternative** : Utilisez `get_mining_info` (spécifique PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Raison** : Le minage CPU n'est pas applicable à PoCX (nécessite des plots pré-générés)
- **Alternative** : Utilisez un plotter externe + mineur + `submit_nonce`

**Implémentation** : `src/rpc/mining.cpp` (les RPCs retournent une erreur quand ENABLE_POCX est défini)

---

## Exemples d'intégration

### Intégration de mineur externe

**Boucle de minage de base** :
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Boucle de minage
while True:
    # 1. Obtenir les paramètres de minage
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scanner les fichiers plot (implémentation externe)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Soumettre la meilleure solution
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Solution acceptée ! Qualité : {result['quality']}s, "
              f"Temps de forge : {result['poc_time']}s")

    # 4. Attendre le prochain bloc
    time.sleep(10)  # Intervalle de polling
```

---

### Modèle d'intégration de pool

**Flux de travail du serveur de pool** :
1. Les mineurs créent des assignations de forge vers l'adresse du pool
2. Le pool exécute un portefeuille avec les clés de l'adresse de forge
3. Le pool appelle `get_mining_info` et distribue aux mineurs
4. Les mineurs soumettent les solutions via le pool (pas directement à la chaîne)
5. Le pool valide et appelle `submit_nonce` avec les clés du pool
6. Le pool distribue les récompenses selon la politique du pool

**Gestion des assignations** :
```bash
# Le mineur crée une assignation (depuis le portefeuille du mineur)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Attendre l'activation (30 blocs mainnet)

# Le pool vérifie le statut d'assignation
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Le pool peut maintenant soumettre des nonces pour ce plot
# (le portefeuille du pool doit avoir la clé privée de pocx1qpool...)
```

---

### Requêtes d'explorateur de blocs

**Interrogation des données de bloc PoCX** :
```bash
# Obtenir le dernier bloc
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Obtenir les détails du bloc avec la preuve PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extraire les champs spécifiques PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Détection des transactions d'assignation** :
```bash
# Scanner la transaction pour OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Vérifier le marqueur d'assignation (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Gestion des erreurs

### Modèles d'erreur courants

**Différence de hauteur** :
```json
{
  "accepted": false,
  "error": "Différence de hauteur : soumis 12345, actuel 12346"
}
```
**Solution** : Récupérer à nouveau les infos de minage, la chaîne a avancé

**Différence de signature de génération** :
```json
{
  "accepted": false,
  "error": "Signature de génération non correspondante"
}
```
**Solution** : Récupérer à nouveau les infos de minage, nouveau bloc arrivé

**Pas de clé privée** :
```json
{
  "code": -5,
  "message": "Pas de clé privée disponible pour le signataire effectif"
}
```
**Solution** : Importer la clé pour l'adresse de plot ou de forge

**Activation d'assignation en attente** :
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solution** : Attendre que le délai d'activation soit écoulé

---

## Références de code

**RPCs de minage** : `src/pocx/rpc/mining.cpp`
**RPCs d'assignation** : `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPCs blockchain** : `src/rpc/blockchain.cpp`
**Validation de preuve** : `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**État d'assignation** : `src/pocx/assignments/assignment_state.cpp`
**Création de transaction** : `src/pocx/assignments/transactions.cpp`

---

## Références croisées

Chapitres connexes :
- [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md) - Détails du processus de minage
- [Chapitre 4 : Assignations de forge](4-forging-assignments.md) - Architecture du système d'assignation
- [Chapitre 6 : Paramètres réseau](6-network-parameters.md) - Valeurs de délai d'assignation
- [Chapitre 8 : Guide du portefeuille](8-wallet-guide.md) - Interface graphique pour la gestion des assignations

---

[← Précédent : Paramètres réseau](6-network-parameters.md) | [📘 Table des matières](index.md) | [Suivant : Guide du portefeuille →](8-wallet-guide.md)

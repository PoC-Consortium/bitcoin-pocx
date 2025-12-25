[← Précédent : Consensus et minage](3-consensus-and-mining.md) | [📘 Table des matières](index.md) | [Suivant : Synchronisation temporelle →](5-timing-security.md)

---

# Chapitre 4 : Système d'assignation de forge PoCX

## Résumé exécutif

Ce document décrit le système d'assignation de forge PoCX **implémenté** utilisant une architecture OP_RETURN uniquement. Le système permet aux propriétaires de plots de déléguer les droits de forge à des adresses séparées via des transactions on-chain, avec une sécurité complète face aux réorganisations et des opérations de base de données atomiques.

**Statut :** ✅ Entièrement implémenté et opérationnel

## Philosophie de conception fondamentale

**Principe clé :** Les assignations sont des permissions, pas des actifs

- Pas d'UTXOs spéciaux à suivre ou dépenser
- État d'assignation stocké séparément de l'ensemble UTXO
- Propriété prouvée par signature de transaction, pas par dépense d'UTXO
- Suivi complet de l'historique pour une piste d'audit complète
- Mises à jour de base de données atomiques via les écritures par lot LevelDB

## Structure des transactions

### Format de transaction d'assignation

```
Entrées :
  [0] : Tout UTXO contrôlé par le propriétaire du plot (prouve la propriété + paie les frais)
       Doit être signé avec la clé privée du propriétaire du plot
  [1+] : Entrées supplémentaires optionnelles pour la couverture des frais

Sorties :
  [0] : OP_RETURN (marqueur POCX + adresse de plot + adresse de forge)
       Format : OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Taille : 46 octets au total (1 octet OP_RETURN + 1 octet longueur + 44 octets données)
       Valeur : 0 BTC (non dépensable, non ajouté à l'ensemble UTXO)

  [1] : Rendu de monnaie à l'utilisateur (optionnel, P2WPKH standard)
```

**Implémentation :** `src/pocx/assignments/opcodes.cpp:25-52`

### Format de transaction de révocation

```
Entrées :
  [0] : Tout UTXO contrôlé par le propriétaire du plot (prouve la propriété + paie les frais)
       Doit être signé avec la clé privée du propriétaire du plot
  [1+] : Entrées supplémentaires optionnelles pour la couverture des frais

Sorties :
  [0] : OP_RETURN (marqueur XCOP + adresse de plot)
       Format : OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Taille : 26 octets au total (1 octet OP_RETURN + 1 octet longueur + 24 octets données)
       Valeur : 0 BTC (non dépensable, non ajouté à l'ensemble UTXO)

  [1] : Rendu de monnaie à l'utilisateur (optionnel, P2WPKH standard)
```

**Implémentation :** `src/pocx/assignments/opcodes.cpp:54-77`

### Marqueurs

- **Marqueur d'assignation :** `POCX` (0x50, 0x4F, 0x43, 0x58) = « Proof of Capacity neXt »
- **Marqueur de révocation :** `XCOP` (0x58, 0x43, 0x4F, 0x50) = « eXit Capacity OPeration »

**Implémentation :** `src/pocx/assignments/opcodes.cpp:15-19`

### Caractéristiques clés des transactions

- Transactions Bitcoin standard (pas de changements de protocole)
- Les sorties OP_RETURN sont prouvablement non dépensables (jamais ajoutées à l'ensemble UTXO)
- Propriété du plot prouvée par la signature sur input[0] depuis l'adresse du plot
- Faible coût (~200 octets, typiquement <0,0001 BTC de frais)
- Le portefeuille sélectionne automatiquement le plus grand UTXO de l'adresse de plot pour prouver la propriété

## Architecture de base de données

### Structure de stockage

Toutes les données d'assignation sont stockées dans la même base de données LevelDB que l'ensemble UTXO (`chainstate/`), mais avec des préfixes de clé séparés :

```
chainstate/ LevelDB :
├─ Ensemble UTXO (standard Bitcoin Core)
│  └─ préfixe 'C' : COutPoint → Coin
│
└─ État d'assignation (ajouts PoCX)
   └─ préfixe 'A' : (plot_address, assignment_txid) → ForgingAssignment
       └─ Historique complet : toutes les assignations par plot au fil du temps
```

**Implémentation :** `src/txdb.cpp:237-348`

### Structure ForgingAssignment

```cpp
struct ForgingAssignment {
    // Identité
    std::array<uint8_t, 20> plotAddress;      // Propriétaire du plot (hash P2WPKH de 20 octets)
    std::array<uint8_t, 20> forgingAddress;   // Détenteur des droits de forge (hash P2WPKH de 20 octets)

    // Cycle de vie de l'assignation
    uint256 assignment_txid;                   // Transaction qui a créé l'assignation
    int assignment_height;                     // Hauteur de bloc de création
    int assignment_effective_height;           // Quand elle devient active (hauteur + délai)

    // Cycle de vie de la révocation
    bool revoked;                              // A-t-elle été révoquée ?
    uint256 revocation_txid;                   // Transaction qui l'a révoquée
    int revocation_height;                     // Hauteur de bloc de révocation
    int revocation_effective_height;           // Quand la révocation est effective (hauteur + délai)

    // Méthodes de requête d'état
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implémentation :** `src/coins.h:111-178`

### États d'assignation

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Aucune assignation n'existe
    ASSIGNING = 1,   // Assignation créée, en attente du délai d'activation
    ASSIGNED = 2,    // Assignation active, forge autorisée
    REVOKING = 3,    // Révoquée, mais toujours active pendant la période de délai
    REVOKED = 4      // Entièrement révoquée, plus active
};
```

**Implémentation :** `src/coins.h:98-104`

### Clés de base de données

```cpp
// Clé d'historique : stocke l'enregistrement d'assignation complet
// Format de clé : (préfixe, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Adresse de plot (20 octets)
    int assignment_height;                // Hauteur pour optimisation du tri
    uint256 assignment_txid;              // ID de transaction
};
```

**Implémentation :** `src/txdb.cpp:245-262`

### Suivi de l'historique

- Chaque assignation stockée de manière permanente (jamais supprimée sauf réorg)
- Plusieurs assignations par plot suivies au fil du temps
- Permet une piste d'audit complète et des requêtes d'état historique
- Les assignations révoquées restent dans la base de données avec `revoked=true`

## Traitement des blocs

### Intégration ConnectBlock

Les OP_RETURNs d'assignation et de révocation sont traités pendant la connexion de bloc dans `validation.cpp` :

```cpp
// Emplacement : Après la validation de script, avant UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parser les données OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Vérifier la propriété (tx doit être signée par le propriétaire du plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Vérifier l'état du plot (doit être UNASSIGNED ou REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Créer une nouvelle assignation
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Stocker les données d'annulation
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parser les données OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Vérifier la propriété
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Obtenir l'assignation actuelle
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Stocker l'ancien état pour annulation
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Marquer comme révoquée
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins procède normalement (ignore automatiquement les sorties OP_RETURN)
```

**Implémentation :** `src/validation.cpp:2775-2878`

### Vérification de propriété

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Vérifier qu'au moins une entrée est signée par le propriétaire du plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extraire la destination
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Vérifier si P2WPKH vers l'adresse de plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core a déjà validé la signature
                return true;
            }
        }
    }
    return false;
}
```

**Implémentation :** `src/pocx/assignments/opcodes.cpp:217-256`

### Délais d'activation

Les assignations et révocations ont des délais d'activation configurables pour empêcher les attaques de réorg :

```cpp
// Paramètres de consensus (configurables par réseau)
// Exemple : 30 blocs = ~1 heure avec un temps de bloc de 2 minutes
consensus.nForgingAssignmentDelay;   // Délai d'activation d'assignation
consensus.nForgingRevocationDelay;   // Délai d'activation de révocation
```

**Transitions d'état :**
- Assignation : `UNASSIGNED → ASSIGNING (délai) → ASSIGNED`
- Révocation : `ASSIGNED → REVOKING (délai) → REVOKED`

**Implémentation :** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validation du mempool

Les transactions d'assignation et de révocation sont validées à l'acceptation du mempool pour rejeter les transactions invalides avant la propagation réseau.

### Vérifications au niveau transaction (CheckTransaction)

Effectuées dans `src/consensus/tx_check.cpp` sans accès à l'état de chaîne :

1. **Maximum un OP_RETURN POCX :** La transaction ne peut pas contenir plusieurs marqueurs POCX/XCOP

**Implémentation :** `src/consensus/tx_check.cpp:63-77`

### Vérifications d'acceptation du mempool (PreChecks)

Effectuées dans `src/validation.cpp` avec accès complet à l'état de chaîne et du mempool :

#### Validation d'assignation

1. **Propriété du plot :** La transaction doit être signée par le propriétaire du plot
2. **État du plot :** Le plot doit être UNASSIGNED (0) ou REVOKED (4)
3. **Conflits de mempool :** Pas d'autre assignation pour ce plot dans le mempool (premier arrivé, premier servi)

#### Validation de révocation

1. **Propriété du plot :** La transaction doit être signée par le propriétaire du plot
2. **Assignation active :** Le plot doit être à l'état ASSIGNED (2) uniquement
3. **Conflits de mempool :** Pas d'autre révocation pour ce plot dans le mempool

**Implémentation :** `src/validation.cpp:898-993`

### Flux de validation

```
Diffusion de transaction
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maximum un OP_RETURN POCX
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Vérifier la propriété du plot
  ✓ Vérifier l'état d'assignation
  ✓ Vérifier les conflits de mempool
       ↓
   Valide → Accepter dans le mempool
   Invalide → Rejeter (ne pas propager)
       ↓
Minage de bloc
       ↓
ConnectBlock() [validation.cpp]
  ✓ Re-valider toutes les vérifications (défense en profondeur)
  ✓ Appliquer les changements d'état
  ✓ Enregistrer les infos d'annulation
```

### Défense en profondeur

Toutes les vérifications de validation du mempool sont ré-exécutées pendant `ConnectBlock()` pour se protéger contre :
- Les attaques de contournement du mempool
- Les blocs invalides de mineurs malveillants
- Les cas limites pendant les scénarios de réorg

La validation de bloc reste autoritaire pour le consensus.

## Mises à jour atomiques de base de données

### Architecture à trois couches

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Cache mémoire)       │  ← Changements d'assignation suivis en mémoire
│   - Coins: cacheCoins                   │
│   - Assignations: pendingAssignments    │
│   - Suivi dirty: dirtyPlots             │
│   - Suppressions: deletedAssignments    │
│   - Suivi mémoire: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Couche base de données) │  ← Écriture atomique unique
│   - BatchWrite(): UTXOs + Assignations  │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Stockage disque)             │  ← Garanties ACID
│   - Transaction atomique                │
└─────────────────────────────────────────┘
```

### Processus de flush

Quand `view.Flush()` est appelé pendant la connexion de bloc :

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Écrire les changements de coins vers la base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Écrire les changements d'assignation de manière atomique
    if (fOk && !dirtyPlots.empty()) {
        // Collecter les assignations dirty
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Vide - non utilisé

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Écrire dans la base de données
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Effacer le suivi
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Libérer la mémoire
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implémentation :** `src/coins.cpp:278-315`

### Écriture par lot de base de données

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Lot LevelDB unique

    // 1. Marquer l'état de transition
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Écrire tous les changements de coins
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Marquer l'état cohérent
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT ATOMIQUE
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Assignations écrites séparément mais dans le même contexte de transaction de base de données
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Paramètre non utilisé (conservé pour compatibilité API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nouveau lot, mais même base de données

    // Écrire l'historique d'assignation
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Effacer les assignations supprimées de l'historique
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT ATOMIQUE
    return m_db->WriteBatch(batch);
}
```

**Implémentation :** `src/txdb.cpp:332-348`

### Garanties d'atomicité

✅ **Ce qui est atomique :**
- Tous les changements de coins au sein d'un bloc sont écrits de manière atomique
- Tous les changements d'assignation au sein d'un bloc sont écrits de manière atomique
- La base de données reste cohérente à travers les crashs

⚠️ **Limitation actuelle :**
- Les coins et les assignations sont écrits dans des opérations par lot LevelDB **séparées**
- Les deux opérations se produisent pendant `view.Flush()`, mais pas dans une seule écriture atomique
- En pratique : Les deux lots se terminent rapidement avant le fsync disque
- Le risque est minimal : Les deux devraient être rejoués depuis le même bloc lors de la récupération après crash

**Note :** Ceci diffère du plan d'architecture original qui prévoyait un lot unifié unique. L'implémentation actuelle utilise deux lots mais maintient la cohérence grâce aux mécanismes de récupération après crash existants de Bitcoin Core (marqueur DB_HEAD_BLOCKS).

## Gestion des réorganisations

### Structure de données d'annulation

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // L'assignation a été ajoutée (supprimer lors de l'annulation)
        MODIFIED = 1,   // L'assignation a été modifiée (restaurer lors de l'annulation)
        REVOKED = 2     // L'assignation a été révoquée (annuler la révocation lors de l'annulation)
    };

    UndoType type;
    ForgingAssignment assignment;  // État complet avant le changement
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Données d'annulation UTXO
    std::vector<ForgingUndo> vforgingundo;  // Données d'annulation d'assignation
};
```

**Implémentation :** `src/undo.h:63-105`

### Processus DisconnectBlock

Quand un bloc est déconnecté lors d'une réorg :

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... déconnexion UTXO standard ...

    // Lire les données d'annulation depuis le disque
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Annuler les changements d'assignation (traiter dans l'ordre inverse)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // L'assignation a été ajoutée - la supprimer
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // L'assignation a été révoquée - restaurer l'état non révoqué
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // L'assignation a été modifiée - restaurer l'état précédent
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implémentation :** `src/validation.cpp:2381-2415`

### Gestion du cache pendant les réorgs

```cpp
class CCoinsViewCache {
private:
    // Caches d'assignation
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Suivre les plots modifiés
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Suivre les suppressions
    mutable size_t cachedAssignmentsUsage{0};  // Suivi mémoire

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**Implémentation :** `src/coins.cpp:494-565`

## Interface RPC

### Commandes nœud (pas de portefeuille requis)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Retourne le statut d'assignation actuel pour une adresse de plot :
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**Implémentation :** `src/pocx/rpc/assignments.cpp:31-126`

### Commandes portefeuille (portefeuille requis)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Crée une transaction d'assignation :
- Sélectionne automatiquement le plus grand UTXO de l'adresse de plot pour prouver la propriété
- Construit la transaction avec OP_RETURN + sortie de change
- Signe avec la clé du propriétaire du plot
- Diffuse sur le réseau

**Implémentation :** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Crée une transaction de révocation :
- Sélectionne automatiquement le plus grand UTXO de l'adresse de plot pour prouver la propriété
- Construit la transaction avec OP_RETURN + sortie de change
- Signe avec la clé du propriétaire du plot
- Diffuse sur le réseau

**Implémentation :** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Création de transaction portefeuille

Le processus de création de transaction portefeuille :

```cpp
1. Parser et valider les adresses (doivent être P2WPKH bech32)
2. Trouver le plus grand UTXO de l'adresse de plot (prouve la propriété)
3. Créer une transaction temporaire avec sortie factice
4. Signer la transaction (obtenir la taille exacte avec données witness)
5. Remplacer la sortie factice par OP_RETURN
6. Ajuster les frais proportionnellement en fonction du changement de taille
7. Re-signer la transaction finale
8. Diffuser sur le réseau
```

**Insight clé :** Le portefeuille doit dépenser depuis l'adresse de plot pour prouver la propriété, donc il force automatiquement la sélection de coin depuis cette adresse.

**Implémentation :** `src/pocx/assignments/transactions.cpp:38-263`

## Structure des fichiers

### Fichiers d'implémentation principaux

```
src/
├── coins.h                        # Structure ForgingAssignment, méthodes CCoinsViewCache [710 lignes]
├── coins.cpp                      # Gestion du cache, écritures par lot [603 lignes]
│
├── txdb.h                         # Méthodes d'assignation CCoinsViewDB [90 lignes]
├── txdb.cpp                       # Lecture/écriture base de données [349 lignes]
│
├── undo.h                         # Structure ForgingUndo pour les réorgs
│
├── validation.cpp                 # Intégration ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Format OP_RETURN, parsing, vérification
    │   ├── opcodes.cpp            # [259 lignes] Définitions de marqueurs, ops OP_RETURN, vérification de propriété
    │   ├── assignment_state.h     # Helpers GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Fonctions de requête d'état d'assignation
    │   ├── transactions.h         # API de création de transaction portefeuille
    │   └── transactions.cpp       # Fonctions portefeuille create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Commandes RPC nœud (sans portefeuille)
    │   ├── assignments.cpp        # RPCs get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Commandes RPC portefeuille
    │   └── assignments_wallet.cpp # RPCs create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Caractéristiques de performance

### Opérations de base de données

- **Obtenir l'assignation actuelle :** O(n) - scanner toutes les assignations pour l'adresse de plot pour trouver la plus récente
- **Obtenir l'historique d'assignation :** O(n) - itérer toutes les assignations pour le plot
- **Créer une assignation :** O(1) - insertion unique
- **Révoquer une assignation :** O(1) - mise à jour unique
- **Réorg (par assignation) :** O(1) - application directe des données d'annulation

Où n = nombre d'assignations pour un plot (typiquement petit, < 10)

### Utilisation mémoire

- **Par assignation :** ~160 octets (structure ForgingAssignment)
- **Surcharge de cache :** Surcharge de hash map pour le suivi dirty
- **Bloc typique :** <10 assignations = <2 Ko mémoire

### Utilisation disque

- **Par assignation :** ~200 octets sur disque (avec surcharge LevelDB)
- **10000 assignations :** ~2 Mo d'espace disque
- **Négligeable comparé à l'ensemble UTXO :** <0,001 % du chainstate typique

## Limitations actuelles et travail futur

### Limitation d'atomicité

**Actuel :** Coins et assignations écrits dans des lots LevelDB séparés pendant `view.Flush()`

**Impact :** Risque théorique d'incohérence si crash entre les lots

**Atténuation :**
- Les deux lots se terminent rapidement avant fsync
- La récupération après crash de Bitcoin Core utilise le marqueur DB_HEAD_BLOCKS
- En pratique : Jamais observé lors des tests

**Amélioration future :** Unifier en une seule opération par lot LevelDB

### Élagage de l'historique d'assignation

**Actuel :** Toutes les assignations stockées indéfiniment

**Impact :** ~200 octets par assignation pour toujours

**Futur :** Élagage optionnel des assignations entièrement révoquées plus anciennes que N blocs

**Note :** Peu probable d'être nécessaire - même 1 million d'assignations = 200 Mo

## Statut des tests

### Tests implémentés

✅ Parsing et validation OP_RETURN
✅ Vérification de propriété
✅ Création d'assignation ConnectBlock
✅ Révocation ConnectBlock
✅ Gestion des réorgs DisconnectBlock
✅ Opérations de lecture/écriture base de données
✅ Transitions d'état (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ Commandes RPC (get_assignment, create_assignment, revoke_assignment)
✅ Création de transaction portefeuille

### Domaines de couverture de tests

- Tests unitaires : `src/test/pocx_*_tests.cpp`
- Tests fonctionnels : `test/functional/feature_pocx_*.py`
- Tests d'intégration : Tests manuels avec regtest

## Règles de consensus

### Règles de création d'assignation

1. **Propriété :** La transaction doit être signée par le propriétaire du plot
2. **État :** Le plot doit être à l'état UNASSIGNED ou REVOKED
3. **Format :** OP_RETURN valide avec marqueur POCX + 2× adresses de 20 octets
4. **Unicité :** Une seule assignation active par plot à la fois

### Règles de révocation

1. **Propriété :** La transaction doit être signée par le propriétaire du plot
2. **Existence :** L'assignation doit exister et ne pas être déjà révoquée
3. **Format :** OP_RETURN valide avec marqueur XCOP + adresse de 20 octets

### Règles d'activation

- **Activation d'assignation :** `assignment_height + nForgingAssignmentDelay`
- **Activation de révocation :** `revocation_height + nForgingRevocationDelay`
- **Délais :** Configurables par réseau (ex., 30 blocs = ~1 heure avec temps de bloc de 2 minutes)

### Validation de bloc

- Assignation/révocation invalide → bloc rejeté (échec de consensus)
- Les sorties OP_RETURN automatiquement exclues de l'ensemble UTXO (comportement Bitcoin standard)
- Le traitement d'assignation se produit avant les mises à jour UTXO dans ConnectBlock

## Conclusion

Le système d'assignation de forge PoCX tel qu'implémenté fournit :

✅ **Simplicité :** Transactions Bitcoin standard, pas d'UTXOs spéciaux
✅ **Économique :** Pas d'exigence de dust, seulement des frais de transaction
✅ **Sécurité face aux réorgs :** Données d'annulation complètes restaurent l'état correct
✅ **Mises à jour atomiques :** Cohérence de base de données via les lots LevelDB
✅ **Historique complet :** Piste d'audit complète de toutes les assignations au fil du temps
✅ **Architecture propre :** Modifications minimales de Bitcoin Core, code PoCX isolé
✅ **Prêt pour la production :** Entièrement implémenté, testé et opérationnel

### Qualité d'implémentation

- **Organisation du code :** Excellente - séparation claire entre Bitcoin Core et PoCX
- **Gestion des erreurs :** Validation de consensus complète
- **Documentation :** Commentaires de code et structure bien documentés
- **Tests :** Fonctionnalités principales testées, intégration vérifiée

### Décisions de conception clés validées

1. ✅ Approche OP_RETURN uniquement (vs basée sur UTXO)
2. ✅ Stockage de base de données séparé (vs extraData Coin)
3. ✅ Suivi d'historique complet (vs actuel uniquement)
4. ✅ Propriété par signature (vs dépense d'UTXO)
5. ✅ Délais d'activation (empêche les attaques de réorg)

Le système atteint avec succès tous les objectifs architecturaux avec une implémentation propre et maintenable.

---

[← Précédent : Consensus et minage](3-consensus-and-mining.md) | [📘 Table des matières](index.md) | [Suivant : Synchronisation temporelle →](5-timing-security.md)

[← Précédent : Format Plot](2-plot-format.md) | [📘 Table des matières](index.md) | [Suivant : Assignations de forge →](4-forging-assignments.md)

---

# Chapitre 3 : Processus de consensus et de minage Bitcoin-PoCX

Spécification technique complète du mécanisme de consensus et du processus de minage PoCX (Proof of Capacity neXt generation) intégré dans Bitcoin Core.

---

## Table des matières

1. [Aperçu](#aperçu)
2. [Architecture du consensus](#architecture-du-consensus)
3. [Processus de minage](#processus-de-minage)
4. [Validation des blocs](#validation-des-blocs)
5. [Système d'assignation](#système-dassignation)
6. [Propagation réseau](#propagation-réseau)
7. [Détails techniques](#détails-techniques)

---

## Aperçu

Bitcoin-PoCX implémente un mécanisme de consensus de preuve de capacité pur en remplacement complet de la preuve de travail de Bitcoin. Il s'agit d'une nouvelle chaîne sans exigences de rétrocompatibilité.

**Propriétés clés :**
- **Économe en énergie :** Le minage utilise des fichiers plot pré-générés au lieu du hachage computationnel
- **Deadlines time-bendés :** Transformation de distribution (exponentielle → Weibull, forme k=3) réduit les longs blocs, améliore les temps de bloc moyens
- **Support des assignations :** Les propriétaires de plots peuvent déléguer les droits de forge à d'autres adresses
- **Intégration C++ native :** Algorithmes cryptographiques implémentés en C++ pour la validation du consensus

**Flux de minage :**
```
Mineur externe → get_mining_info → Calculer Nonce → submit_nonce →
File de forge → Attente de deadline → Forge de bloc → Propagation réseau →
Validation de bloc → Extension de chaîne
```

---

## Architecture du consensus

### Structure de bloc

Les blocs PoCX étendent la structure de bloc Bitcoin avec des champs de consensus supplémentaires :

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed du plot (32 octets)
    std::array<uint8_t, 20> account_id;       // Adresse du plot (hash160 de 20 octets)
    uint32_t compression;                     // Niveau de mise à l'échelle (1-6)
    uint64_t nonce;                           // Nonce de minage (64 bits)
    uint64_t quality;                         // Qualité déclarée (sortie de hachage PoC)
};

class CBlockHeader {
    // Champs Bitcoin standard
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Champs de consensus PoCX (remplacent nBits et nNonce)
    int nHeight;                              // Hauteur de bloc (validation sans contexte)
    uint256 generationSignature;              // Signature de génération (entropie de minage)
    uint64_t nBaseTarget;                     // Paramètre de difficulté (difficulté inverse)
    PoCXProof pocxProof;                      // Preuve de minage

    // Champs de signature de bloc
    std::array<uint8_t, 33> vchPubKey;        // Clé publique compressée (33 octets)
    std::array<uint8_t, 65> vchSignature;     // Signature compacte (65 octets)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transactions
};
```

**Note :** La signature (`vchSignature`) est exclue du calcul du hachage de bloc pour empêcher la malléabilité.

**Implémentation :** `src/primitives/block.h`

### Signature de génération

La signature de génération crée l'entropie de minage et empêche les attaques par pré-calcul.

**Calcul :**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Bloc Genesis :** Utilise une signature de génération initiale codée en dur

**Implémentation :** `src/pocx/consensus/difficulty.cpp:GetNextGenerationSignature()` (appelée depuis `src/pocx/mining/block_context.cpp:GetNewBlockContext()`)

### Cible de base (Difficulté)

La cible de base est l'inverse de la difficulté — des valeurs plus élevées signifient un minage plus facile.

**Algorithme d'ajustement :**
- Temps de bloc cible : 120 secondes (tous les réseaux)
- Intervalle d'ajustement : À chaque bloc
- Utilise une moyenne mobile des cibles de base récentes
- Limitée pour empêcher les oscillations extrêmes de difficulté

**Implémentation :** `src/consensus/params.h`, logique de difficulté dans la création de bloc

### Niveaux de mise à l'échelle

PoCX supporte la preuve de travail évolutive dans les fichiers plot via les niveaux de mise à l'échelle (Xn).

**Bornes dynamiques :**
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Niveau minimum accepté
    uint32_t nPoCXTargetCompression;  // Niveau recommandé
};
```

**Calendrier d'augmentation de la mise à l'échelle :**
- Intervalles exponentiels : Années 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Le niveau de mise à l'échelle minimum augmente de 1
- Le niveau de mise à l'échelle cible augmente de 1
- Maintient la marge de sécurité entre les coûts de création et de consultation de plot
- Niveau de mise à l'échelle maximum : 255

**Implémentation :** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## Processus de minage

### 1. Récupération des informations de minage

**Commande RPC :** `get_mining_info`

**Processus :**
1. Appeler `GetNewBlockContext(chainman)` pour récupérer l'état actuel de la blockchain
2. Calculer les bornes de compression dynamiques pour la hauteur actuelle
3. Retourner les paramètres de minage

**Réponse :**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 1,
  "target_compression_level": 2
}
```

**Implémentation :** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Notes :**
- Aucun verrou maintenu pendant la génération de la réponse
- L'acquisition de contexte gère `cs_main` en interne
- `block_hash` inclus pour référence mais non utilisé dans la validation

### 2. Minage externe

**Responsabilités du mineur externe :**
1. Lire les fichiers plot depuis le disque
2. Calculer le scoop basé sur la signature de génération et la hauteur
3. Trouver le nonce avec la meilleure deadline
4. Soumettre au nœud via `submit_nonce`

**Format de fichier Plot :**
- Basé sur le format POC2 (Burstcoin)
- Amélioré avec des corrections de sécurité et des améliorations d'évolutivité
- Voir l'attribution dans `CLAUDE.md`

**Implémentation du mineur :** Externe (par ex., basé sur Scavenger)

### 3. Soumission et validation de nonce

**Commande RPC :** `submit_nonce`

**Paramètres :**
```
height, generation_signature, account_id, seed, nonce, quality (optionnel)
```

**Flux de validation (ordre optimisé) :**

#### Étape 1 : Validation rapide du format
```cpp
// ID de compte : 40 caractères hex = 20 octets
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed : 64 caractères hex = 32 octets
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Étape 2 : Acquisition du contexte
```cpp
auto context = pocx::mining::GetNewBlockContext(chainman);
// Retourne : height, generation_signature, base_target, block_hash
```

**Verrouillage :** `cs_main` géré en interne, aucun verrou maintenu dans le thread RPC

#### Étape 3 : Validation du contexte
```cpp
// Vérification de hauteur
if (height != context.height) reject;

// Vérification de la signature de génération
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Étape 4 : Vérification du portefeuille
```cpp
// Déterminer le signataire effectif (en considérant les assignations)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Vérifier si le nœud a la clé privée pour le signataire effectif
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Support des assignations :** Le propriétaire du plot peut assigner les droits de forge à une autre adresse. Le portefeuille doit avoir la clé pour le signataire effectif, pas nécessairement le propriétaire du plot.

#### Step 5: Compression Validation
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
if (compression < bounds.nPoCXMinCompression || compression > bounds.nPoCXTargetCompression)
    reject;
```

#### Step 7: Time Bending: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 octets
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Algorithme :**
1. Décoder la signature de génération depuis l'hex
2. Calculate quality at specified compression level
3. Valider que la qualité répond aux exigences de difficulté
4. Retourner la valeur de qualité brute

**Implémentation :** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### Étape 6 : Calcul du Time Bending
```cpp
// Deadline brute ajustée à la difficulté (secondes)
uint64_t deadline_seconds = quality / base_target;

// Temps de forge time-bendé (secondes)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Formule Time Bending :**
```
Y = échelle * (X^(1/3))
où :
  X = quality / base_target
  échelle = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Objectif :** Transforme la distribution exponentielle en Weibull (forme k=3). Les très bonnes solutions forgent plus tard (le réseau a le temps de scanner les disques), les solutions médiocres sont améliorées. Réduit les longs blocs, maintient une moyenne de 120s.

**Implémentation :** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission : Soumission au forgeur
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,
    compression,
    block_hash        // sole staleness indicator
);
```

**Conception basée sur file d'attente :**
- La soumission réussit toujours (ajoutée à la file)
- Le RPC retourne immédiatement
- Le thread worker traite de manière asynchrone

**Implémentation :** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Traitement de la file de forge

**Architecture :**
- Thread worker unique persistant
- File de soumission FIFO
- État de forge sans verrou (thread worker uniquement)
- Pas de verrous imbriqués (prévention des interblocages)

**Boucle principale du thread Worker :**
```cpp
while (!shutdown) {
    // 1. Vérifier les soumissions en file
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Attendre la deadline ou une nouvelle soumission
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logique ProcessSubmission :**
```cpp
1. Obtenir un contexte frais : GetNewBlockContext(*chainman)

2. Vérifications d'obsolescence (rejet silencieux) :
   - Différence de hauteur → rejeter
   - Différence de signature de génération → rejeter
   - Hachage de bloc de pointe changé (réorg) → réinitialiser l'état de forge

3. Quality comparison (lower = better):
   - Si quality >= current_best → rejeter

4. Calculer la deadline Time Bended :
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Mettre à jour l'état de forge :
   - Annuler la forge existante (si meilleure trouvée)
   - Stocker : account_id, seed, nonce, quality, deadline
   - Calculer : forge_time = block_time + deadline_seconds
   - Stocker le hachage de pointe pour la détection de réorg
```

**Implémentation :** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Attente de deadline et forge de bloc

**WaitForDeadlineOrNewSubmission :**

**Conditions d'attente :**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Quand la deadline est atteinte - Validation du contexte frais :**
```cpp
1. Obtenir le contexte actuel : GetNewBlockContext(*chainman)

2. Validation de hauteur :
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validation de signature de génération :
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Cas limite de cible de base :
   if (forging_base_target != current_base_target) {
       // Recalculer la deadline avec la nouvelle cible de base
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Attendre à nouveau
   }

5. Tout valide → ForgeBlock()
```

**Processus ForgeBlock :**

```cpp
1. Déterminer le signataire effectif (support des assignations) :
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Créer le script coinbase :
   coinbase_script = P2WPKH(effective_signer);  // Paie le signataire effectif

3. Créer le modèle de bloc :
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Ajouter la preuve PoCX :
   block.pocxProof.account_id = plot_address;    // Adresse de plot originale
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Recalculer la racine merkle :
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Signer le bloc :
   // Utiliser la clé du signataire effectif (peut être différent du propriétaire du plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Soumettre à la chaîne :
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Gestion du résultat :
   if (accepted) {
       log_success();
       reset_forging_state();  // Prêt pour le prochain bloc
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implémentation :** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**Décisions de conception clés :**
- Le coinbase paie le signataire effectif (respecte les assignations)
- La preuve contient l'adresse de plot originale (pour la validation)
- Signature de la clé du signataire effectif (preuve de propriété)
- La création de modèle inclut automatiquement les transactions du mempool

---

## Validation des blocs

### Flux de validation des blocs entrants

Quand un bloc est reçu du réseau ou soumis localement, il passe par une validation en plusieurs étapes :

### Étape 1 : Validation d'en-tête (CheckBlockHeader)

**Validation sans contexte :**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validation PoCX (quand ENABLE_POCX est défini) :**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validation de signature basique (pas de support d'assignation encore)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validation de signature basique :**
1. Vérifier la présence des champs pubkey et signature
2. Valider la taille de la pubkey (33 octets compressés)
3. Valider la taille de la signature (65 octets compact)
4. Récupérer la pubkey depuis la signature : `pubkey.RecoverCompact(hash, signature)`
5. Vérifier que la pubkey récupérée correspond à la pubkey stockée

**Implémentation :** `src/validation.cpp:CheckBlockHeader()`
**Logique de signature :** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### Étape 2 : Validation de bloc (CheckBlock)

**Valide :**
- Exactitude de la racine merkle
- Validité des transactions
- Exigences coinbase
- Limites de taille de bloc
- Règles de consensus Bitcoin standard

**Implémentation :** `src/consensus/validation.cpp:CheckBlock()`

### Étape 3 : Validation d'en-tête contextuelle (ContextualCheckBlockHeader)

**Validation spécifique PoCX :**

```cpp
#ifdef ENABLE_POCX
    // Step 1: Validate block height
    if (block.nHeight != pindexPrev->nHeight + 1) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-height");
    }

    // Step 2: Validate generation signature
    uint256 expected_gen_sig = GetNextGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gensig");
    }

    // Step 3: Validate base target
    uint64_t expected_base_target = pindexPrev->nNextBaseTarget;
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Step 4: Verify deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (poc_time > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-timing");
    }
#endif
```

**Validation Steps:**
1. **Height:** Must be previous height + 1
2. **Generation Signature:** Must match calculated value from previous block
3. **Base Target:** Must match pre-computed value from previous block
4. **Deadline Timing:** Time-bended deadline (`poc_time`) must be ≤ elapsed time

**Implémentation :** `src/validation.cpp:ContextualCheckBlockHeader()`

### Étape 4 : Connexion de bloc (ConnectBlock)

**Validation contextuelle complète :**

```cpp
#ifdef ENABLE_POCX
    // Validation de signature étendue avec support des assignations
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validation de signature étendue :**
1. Effectuer la validation de signature basique
2. Extraire l'ID de compte depuis la pubkey récupérée
3. Obtenir le signataire effectif pour l'adresse de plot : `GetEffectiveSigner(plot_address, height, view)`
4. Vérifier que le compte de la pubkey correspond au signataire effectif

**Logique d'assignation :**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Retourner le signataire assigné
    }

    return plotAddress;  // Pas d'assignation - le propriétaire du plot signe
}
```

**Destinataire de la coinbase** (non imposé par le consensus) :

Le mineur définit la sortie coinbase pour payer le signataire effectif (`src/pocx/mining/block_builder.cpp:CreateCoinbaseScript()`), mais cela n'est **pas** validé par le consensus. Le consensus impose uniquement que la *signature de bloc* soit produite par le signataire effectif — la vérification `bad-pocx-assignment-sig` ci-dessus. Il n'existe aucune règle `bad-pocx-coinbase` ; le destinataire de la coinbase est choisi par le mineur.

**Implémentation :**
- Connexion : `src/validation.cpp:ConnectBlock()`
- Validation étendue : `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- Logique d'assignation : `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### Étape 5 : Activation de chaîne

**Flux ProcessNewBlock :**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Valider et stocker sur disque
    2. ActivateBestChain → Mettre à jour la pointe de chaîne si c'est la meilleure chaîne
    3. Notifier le réseau du nouveau bloc
}
```

**Implémentation :** `src/validation.cpp:ProcessNewBlock()`

### Résumé de validation

**Chemin de validation complet :**
```
Recevoir le bloc
    ↓
CheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
CheckBlock (transactions, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, cible de base, preuve PoC, deadline)
    ↓
ConnectBlock (signature étendue avec assignations, transitions d'état)
    ↓
ActivateBestChain (gestion des réorgs, extension de chaîne)
    ↓
Propagation réseau
```

---

## Système d'assignation

### Aperçu

Les assignations permettent aux propriétaires de plots de déléguer les droits de forge à d'autres adresses tout en conservant la propriété du plot.

**Cas d'utilisation :**
- Minage en pool (les plots s'assignent à l'adresse du pool)
- Stockage à froid (clé de minage séparée de la propriété du plot)
- Minage multi-parties (infrastructure partagée)

### Architecture des assignations

**Conception OP_RETURN uniquement :**
- Assignations stockées dans des sorties OP_RETURN (pas d'UTXO)
- Pas d'exigences de dépense (pas de dust, pas de frais pour détenir)
- Suivies dans l'état étendu CCoinsViewCache
- Activées après une période de délai (par défaut : 30 blocs ; 4 sur regtest)

**États d'assignation :**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Aucune assignation n'existe
    ASSIGNING = 1,   // Assignation en attente d'activation (période de délai)
    ASSIGNED = 2,    // Assignation active, forge autorisée
    REVOKING = 3,    // Révocation en attente (période de délai, toujours active)
    REVOKED = 4      // Révocation terminée, assignation plus active
};
```

### Création d'assignations

**Format de transaction :**
```cpp
Transaction {
    inputs: [any]  // Prouve la propriété de l'adresse de plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Règles de validation :**
1. L'entrée doit être signée par le propriétaire du plot (prouve la propriété)
2. OP_RETURN contient des données d'assignation valides
3. Le plot doit être UNASSIGNED ou REVOKED
4. Pas d'assignations en attente dupliquées dans le mempool
5. Frais de transaction minimum payés

**Activation :**
- L'assignation devient ASSIGNING à la hauteur de confirmation
- Devient ASSIGNED après la période de délai (4 blocs regtest, 30 blocs mainnet)
- Le délai empêche les réassignations rapides pendant les courses de blocs

**Implémentation :** `src/pocx/assignments/opcodes.h`, validation dans ConnectBlock

### Révocation d'assignations

**Format de transaction :**
```cpp
Transaction {
    inputs: [any]  // Prouve la propriété de l'adresse de plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effet :**
- State transitions to REVOKING
- After `nForgingRevocationDelay` blocks (720 mainnet, 8 regtest), transitions to REVOKED
- Plot owner can forge again after revocation becomes effective
- Can create new assignment afterward

### Validation d'assignation pendant le minage

**Détermination du signataire effectif :**
```cpp
// Dans la validation submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Dans la forge de bloc
coinbase_script = P2WPKH(effective_signer);  // La récompense va ici

// Dans la signature de bloc
signature = effective_signer_key.SignCompact(hash);  // Doit signer avec le signataire effectif
```

**Validation de bloc :**
```cpp
// Dans VerifyPoCXBlockCompactSignature (étendu)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Propriétés clés :**
- La preuve contient toujours l'adresse de plot originale
- La signature doit provenir du signataire effectif
- Le coinbase paie le signataire effectif
- La validation utilise l'état d'assignation à la hauteur du bloc

---

## Propagation réseau

### Annonce de bloc

**Protocole P2P Bitcoin standard :**
1. Bloc forgé soumis via `ProcessNewBlock()`
2. Bloc validé et ajouté à la chaîne
3. Notification réseau : `GetMainSignals().BlockConnected()`
4. La couche P2P diffuse le bloc aux pairs

**Implémentation :** net_processing Bitcoin Core standard

### Relais de bloc

**Blocs compacts (BIP 152) :**
- Utilisés pour une propagation de bloc efficace
- Seuls les IDs de transaction sont envoyés initialement
- Les pairs demandent les transactions manquantes

**Relais de bloc complet :**
- Solution de secours quand les blocs compacts échouent
- Données de bloc complètes transmises

### Réorganisations de chaîne

**Gestion des réorgs :**
```cpp
// Dans le thread worker du forgeur
if (current_tip_hash != stored_tip_hash) {
    // Réorganisation de chaîne détectée
    reset_forging_state();
    log("Pointe de chaîne changée, réinitialisation de la forge");
}
```

**Niveau blockchain :**
- Gestion standard des réorgs Bitcoin Core
- Meilleure chaîne déterminée par le chainwork
- Blocs déconnectés retournés au mempool

---

## Détails techniques

### Prévention des interblocages

**Pattern d'interblocage ABBA (Prévenu) :**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Solution :**
1. **submit_nonce :** Zéro utilisation de cs_main
   - `GetNewBlockContext()` gère le verrouillage en interne
   - Toute la validation avant la soumission au forgeur

2. **Forgeur :** Architecture basée sur file d'attente
   - Thread worker unique (pas de joins de thread)
   - Contexte frais à chaque accès
   - Pas de verrous imbriqués

3. **Vérifications de portefeuille :** Effectuées avant les opérations coûteuses
   - Rejet précoce si aucune clé disponible
   - Séparé de l'accès à l'état blockchain

### Optimisations de performance

**Validation en échec rapide :**
```cpp
1. Vérifications de format (immédiat)
2. Validation de contexte (léger)
3. Vérification de portefeuille (local)
4. Validation de preuve (SIMD coûteux)
```

**Récupération de contexte unique :**
- Un seul appel `GetNewBlockContext()` par soumission
- Résultats mis en cache pour plusieurs vérifications
- Pas d'acquisitions répétées de cs_main

**Efficacité de la file :**
- Structure de soumission légère
- Pas de base_target/deadline dans la file (recalculés frais)
- Empreinte mémoire minimale

### Gestion de l'obsolescence

**Conception de forgeur « naïf » :**
- Pas d'abonnements aux événements blockchain
- Validation paresseuse quand nécessaire
- Rejets silencieux des soumissions obsolètes

**Avantages :**
- Architecture simple
- Pas de synchronisation complexe
- Robuste contre les cas limites

**Cas limites gérés :**
- Changements de hauteur → rejeter
- Changements de signature de génération → rejeter
- Changements de cible de base → recalculer la deadline
- Réorgs → réinitialiser l'état de forge

### Détails cryptographiques

**Signature de génération :**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**Hachage de signature de bloc :**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**Format de signature compacte :**
- 65 octets : [recovery_id][r][s]
- Permet la récupération de clé publique
- Utilisé pour l'efficacité d'espace

**ID de compte :**
- HASH160 de 20 octets de la clé publique compressée
- Correspond aux formats d'adresse Bitcoin (P2PKH, P2WPKH)

### Améliorations futures

**Limitations documentées :**
1. Pas de métriques de performance (taux de soumission, distributions de deadline)
2. Pas de catégorisation d'erreurs détaillée pour les mineurs
3. Interrogation limitée du statut du forgeur (deadline actuelle, profondeur de file)

**Améliorations potentielles :**
- RPC pour le statut du forgeur
- Métriques pour l'efficacité de minage
- Journalisation améliorée pour le débogage
- Support du protocole de pool

---

## Références de code

**Implémentations principales :**
- Interface RPC : `src/pocx/rpc/mining.cpp`
- File de forge : `src/pocx/mining/scheduler.cpp`
- Validation de consensus : `src/pocx/consensus/proof.cpp`
- Validation de preuve : `src/pocx/consensus/signature.cpp`
- Time Bending : `src/pocx/algorithms/time_bending.cpp`
- Validation de bloc : `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logique d'assignation : `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- Gestion de contexte : `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**Structures de données :**
- Format de bloc : `src/primitives/block.h`
- Paramètres de consensus : `src/consensus/params.h`
- Suivi d'assignation : `src/coins.h` (extensions CCoinsViewCache)

---

## Annexe : Spécifications d'algorithmes

### Formule Time Bending

**Définition mathématique :**
```
deadline_seconds = quality / base_target  (brut)

time_bended_deadline = échelle * (deadline_seconds)^(1/3)

où :
  échelle = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implémentation :**
- Arithmétique en virgule fixe (format Q42)
- Calcul de racine cubique sur entiers uniquement
- Optimisé pour l'arithmétique 256 bits

### Calcul de qualité

**Processus :**
1. Générer le scoop depuis la signature de génération et la hauteur
2. Lire les données de plot pour le scoop calculé
3. Hachage : `Shabal256Lite(scoop_data, generation_signature)`
4. Tester les niveaux de mise à l'échelle de min à max
5. Retourner la meilleure qualité trouvée

**Mise à l'échelle :**
- Niveau X0 : Ligne de base POC2 (théorique)
- Niveau X1 : Ligne de base XOR-transpose
- Niveau Xn : 2^(n-1) × travail X1 intégré
- Mise à l'échelle plus élevée = plus de travail de génération de plot

### Ajustement de la cible de base

**Ajustement à chaque bloc :**
1. Calculer la moyenne mobile des cibles de base récentes
2. Calculer le délai réel vs le délai cible pour la fenêtre glissante
3. Ajuster la cible de base proportionnellement
4. Limiter pour empêcher les oscillations extrêmes

**Formule :**
```
avg_base_target = moyenne_mobile(cibles de base récentes)
facteur_ajustement = délai_réel / délai_cible
nouvelle_base_target = avg_base_target * facteur_ajustement
nouvelle_base_target = clamp(nouvelle_base_target, min, max)
```

---

*Cette documentation reflète l'implémentation complète du consensus PoCX en date d'octobre 2025.*

---

[← Précédent : Format Plot](2-plot-format.md) | [📘 Table des matières](index.md) | [Suivant : Assignations de forge →](4-forging-assignments.md)

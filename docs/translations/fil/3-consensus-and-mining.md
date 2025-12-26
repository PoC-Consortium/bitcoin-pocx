[← Nakaraan: Format ng Plot](2-plot-format.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Mga Forging Assignment →](4-forging-assignments.md)

---

# Kabanata 3: Proseso ng Bitcoin-PoCX Consensus at Mining

Kumpletong teknikal na ispesipikasyon ng mekanismo ng PoCX (Proof of Capacity neXt generation) consensus at proseso ng mining na naka-integrate sa Bitcoin Core.

---

## Talaan ng mga Nilalaman

1. [Pangkalahatang-tanaw](#pangkalahatang-tanaw)
2. [Arkitektura ng Consensus](#arkitektura-ng-consensus)
3. [Proseso ng Mining](#proseso-ng-mining)
4. [Validation ng Block](#validation-ng-block)
5. [Sistema ng Assignment](#sistema-ng-assignment)
6. [Pagpapakalat sa Network](#pagpapakalat-sa-network)
7. [Mga Teknikal na Detalye](#mga-teknikal-na-detalye)

---

## Pangkalahatang-tanaw

Nagpapatupad ang Bitcoin-PoCX ng purong mekanismo ng Proof of Capacity consensus bilang kumpletong kapalit ng Proof of Work ng Bitcoin. Ito ay isang bagong chain na walang mga kinakailangan sa backward compatibility.

**Mga Pangunahing Katangian:**
- **Energy Efficient:** Ang mining ay gumagamit ng mga pre-generated plot file sa halip na computational hashing
- **Time Bended na mga Deadline:** Pagbabago ng distribution (exponential→chi-squared) na nagpapababa ng mahabang mga block, nagpapabuti ng average block time
- **Suporta sa Assignment:** Ang mga may-ari ng plot ay maaaring magdelega ng mga karapatan sa forging sa ibang mga address
- **Native C++ Integration:** Ang mga cryptographic algorithm ay naka-implement sa C++ para sa consensus validation

**Daloy ng Mining:**
```
External Miner → get_mining_info → Kalkulahin ang Nonce → submit_nonce →
Forger Queue → Deadline Wait → Block Forging → Network Propagation →
Block Validation → Chain Extension
```

---

## Arkitektura ng Consensus

### Istruktura ng Block

Pinapalawak ng mga PoCX block ang istruktura ng block ng Bitcoin na may karagdagang mga field ng consensus:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot seed (32 byte)
    std::array<uint8_t, 20> account_id;       // Plot address (20-byte hash160)
    uint32_t compression;                     // Scaling level (1-255)
    uint64_t nonce;                           // Mining nonce (64-bit)
    uint64_t quality;                         // Claimed quality (PoC hash output)
};

class CBlockHeader {
    // Mga standard Bitcoin field
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Mga field ng PoCX consensus (pumapalit sa nBits at nNonce)
    int nHeight;                              // Block height (context-free validation)
    uint256 generationSignature;              // Generation signature (mining entropy)
    uint64_t nBaseTarget;                     // Difficulty parameter (inverse difficulty)
    PoCXProof pocxProof;                      // Mining proof

    // Mga field ng block signature
    std::array<uint8_t, 33> vchPubKey;        // Compressed public key (33 byte)
    std::array<uint8_t, 65> vchSignature;     // Compact signature (65 byte)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Mga transaksyon
};
```

**Tandaan:** Ang signature (`vchSignature`) ay hindi kasama sa block hash computation upang maiwasan ang malleability.

**Implementasyon:** `src/primitives/block.h`

### Generation Signature

Ang generation signature ay lumilikha ng mining entropy at pumipigil sa mga precomputation attack.

**Kalkulasyon:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis Block:** Gumagamit ng hardcoded initial generation signature

**Implementasyon:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Difficulty)

Ang base target ay ang kabaligtaran ng difficulty - mas mataas na halaga ay nangangahulugan ng mas madaling mining.

**Adjustment Algorithm:**
- Target na block time: 120 segundo (mainnet), 1 segundo (regtest)
- Adjustment interval: Bawat block
- Gumagamit ng moving average ng mga kamakailang base target
- Naka-clamp upang maiwasan ang matitinding pagbabago ng difficulty

**Implementasyon:** `src/consensus/params.h`, difficulty adjustment sa block creation

### Mga Scaling Level

Sinusuportahan ng PoCX ang scalable proof-of-work sa mga plot file sa pamamagitan ng mga scaling level (Xn).

**Mga Dynamic Bound:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum na tinatanggap na level
    uint8_t nPoCXTargetCompression;  // Inirerekomendang level
};
```

**Iskedyul ng Pagtaas ng Scaling:**
- Mga exponential interval: Taon 4, 12, 28, 60, 124 (halving 1, 3, 7, 15, 31)
- Ang minimum scaling level ay tumataas ng 1
- Ang target scaling level ay tumataas ng 1
- Pinapanatili ang safety margin sa pagitan ng plot creation at lookup cost
- Maximum scaling level: 255

**Implementasyon:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Proseso ng Mining

### 1. Pagkuha ng Mining Information

**RPC Command:** `get_mining_info`

**Proseso:**
1. Tawagan ang `GetNewBlockContext(chainman)` upang kunin ang kasalukuyang blockchain state
2. Kalkulahin ang mga dynamic compression bound para sa kasalukuyang taas
3. Ibalik ang mga mining parameter

**Tugon:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementasyon:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Mga Tala:**
- Walang lock na hinahawakan habang ginagawa ang tugon
- Ang context acquisition ay hinahawakan ang `cs_main` sa loob nito
- Ang `block_hash` ay kasama para sa sanggunian ngunit hindi ginagamit sa validation

### 2. External Mining

**Mga responsibilidad ng external miner:**
1. Magbasa ng mga plot file mula sa disk
2. Kalkulahin ang scoop batay sa generation signature at taas
3. Maghanap ng nonce na may pinakamahusay na deadline
4. Isumite sa node sa pamamagitan ng `submit_nonce`

**Format ng Plot File:**
- Batay sa POC2 format (Burstcoin)
- Pinahusay ng mga security fix at scalability improvement
- Tingnan ang attribution sa `CLAUDE.md`

**Implementasyon ng Miner:** External (hal., batay sa Scavenger)

### 3. Pagsusumite at Validation ng Nonce

**RPC Command:** `submit_nonce`

**Mga Parameter:**
```
height, generation_signature, account_id, seed, nonce, quality (optional)
```

**Daloy ng Validation (Na-optimize na Pagkakasunud-sunod):**

#### Hakbang 1: Mabilis na Format Validation
```cpp
// Account ID: 40 hex char = 20 byte
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex char = 32 byte
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Hakbang 2: Context Acquisition
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Nagbabalik ng: height, generation_signature, base_target, block_hash
```

**Locking:** Ang `cs_main` ay hinahawakan sa loob, walang lock na hinahawakan sa RPC thread

#### Hakbang 3: Context Validation
```cpp
// Height check
if (height != context.height) reject;

// Generation signature check
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Hakbang 4: Wallet Verification
```cpp
// Tukuyin ang effective signer (isinasaalang-alang ang mga assignment)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Suriin kung ang node ay may private key para sa effective signer
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Suporta sa Assignment:** Maaaring mag-assign ang may-ari ng plot ng mga karapatan sa forging sa ibang address. Ang wallet ay dapat may key para sa effective signer, hindi kinakailangang ang may-ari ng plot.

#### Hakbang 5: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 byte
    block_height,
    nonce,
    seed,                // 32 byte
    min_compression,
    max_compression,
    &result             // Output: quality, deadline
);
```

**Algorithm:**
1. I-decode ang generation signature mula sa hex
2. Kalkulahin ang pinakamahusay na quality sa compression range gamit ang SIMD-optimized algorithm
3. I-validate na natutugunan ng quality ang mga kinakailangan sa difficulty
4. Ibalik ang raw quality value

**Implementasyon:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Hakbang 6: Time Bending Calculation
```cpp
// Raw difficulty-adjusted deadline (segundo)
uint64_t deadline_seconds = quality / base_target;

// Time Bended forge time (segundo)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending Formula:**
```
Y = scale * (X^(1/3))
kung saan:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Layunin:** Binabago ang exponential sa chi-squared distribution. Ang mga napakagandang solusyon ay nag-fo-forge ng mas huli (ang network ay may oras na i-scan ang mga disk), ang mga mahinang solusyon ay napapabuti. Binabawasan ang mahabang mga block, pinapanatili ang 120s na average.

**Implementasyon:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Hakbang 7: Pagsusumite sa Forger
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // HINDI deadline - kinakalkula ulit sa forger
    height,
    generation_signature
);
```

**Queue-Based na Disenyo:**
- Ang pagsusumite ay laging nagtatagumpay (idinagdag sa queue)
- Ang RPC ay bumabalik kaagad
- Ang worker thread ay nagpoproseso nang asynchronous

**Implementasyon:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Pagpoproseso ng Forger Queue

**Arkitektura:**
- Isang persistent worker thread
- FIFO submission queue
- Lock-free forging state (worker thread lamang)
- Walang nested lock (deadlock prevention)

**Main Loop ng Worker Thread:**
```cpp
while (!shutdown) {
    // 1. Suriin kung may queued submission
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Maghintay ng deadline o bagong submission
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission Logic:**
```cpp
1. Kumuha ng fresh context: GetNewBlockContext(*chainman)

2. Mga staleness check (tahimik na pag-discard):
   - Height mismatch → discard
   - Generation signature mismatch → discard
   - Nagbago ang tip block hash (reorg) → reset ang forging state

3. Paghahambing ng quality:
   - Kung quality >= current_best → discard

4. Kalkulahin ang Time Bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. I-update ang forging state:
   - Kanselahin ang kasalukuyang forging (kung may nakitang mas mabuti)
   - I-store: account_id, seed, nonce, quality, deadline
   - Kalkulahin: forge_time = block_time + deadline_seconds
   - I-store ang tip hash para sa reorg detection
```

**Implementasyon:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Paghihintay ng Deadline at Block Forging

**WaitForDeadlineOrNewSubmission:**

**Mga Kondisyon ng Paghihintay:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Kapag Naabot ang Deadline - Fresh Context Validation:**
```cpp
1. Kumuha ng kasalukuyang context: GetNewBlockContext(*chainman)

2. Height validation:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generation signature validation:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Base target edge case:
   if (forging_base_target != current_base_target) {
       // Kalkulahin ulit ang deadline gamit ang bagong base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Maghintay ulit
   }

5. Lahat valid → ForgeBlock()
```

**Proseso ng ForgeBlock:**

```cpp
1. Tukuyin ang effective signer (suporta sa assignment):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Gumawa ng coinbase script:
   coinbase_script = P2WPKH(effective_signer);  // Nagbabayad sa effective signer

3. Gumawa ng block template:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Idagdag ang PoCX proof:
   block.pocxProof.account_id = plot_address;    // Orihinal na plot address
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Kalkulahin ulit ang merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Lagdaan ang block:
   // Gamitin ang key ng effective signer (maaaring iba sa may-ari ng plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Isumite sa chain:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Paghawak ng resulta:
   if (accepted) {
       log_success();
       reset_forging_state();  // Handa na para sa susunod na block
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementasyon:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Mga Pangunahing Desisyon sa Disenyo:**
- Ang coinbase ay nagbabayad sa effective signer (iginagalang ang mga assignment)
- Ang proof ay naglalaman ng orihinal na plot address (para sa validation)
- Ang signature ay mula sa key ng effective signer (patunay ng pagmamay-ari)
- Ang template creation ay awtomatikong kasama ang mga mempool transaction

---

## Validation ng Block

### Daloy ng Validation ng Incoming Block

Kapag ang isang block ay natanggap mula sa network o isinumite nang lokal, ito ay dumadaan sa validation sa maraming yugto:

### Yugto 1: Header Validation (CheckBlockHeader)

**Context-Free Validation:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX Validation (kapag naka-define ang ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Pangunahing signature validation (wala pang suporta sa assignment)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Pangunahing Signature Validation:**
1. Suriin ang pagkakaroon ng mga field ng pubkey at signature
2. I-validate ang laki ng pubkey (33 byte compressed)
3. I-validate ang laki ng signature (65 byte compact)
4. I-recover ang pubkey mula sa signature: `pubkey.RecoverCompact(hash, signature)`
5. I-verify na ang recovered pubkey ay tumutugma sa stored pubkey

**Implementasyon:** `src/validation.cpp:CheckBlockHeader()`
**Signature Logic:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Yugto 2: Block Validation (CheckBlock)

**Mga Vine-validate:**
- Kawastuhan ng merkle root
- Validity ng transaksyon
- Mga kinakailangan sa coinbase
- Mga limitasyon sa laki ng block
- Mga standard Bitcoin consensus rule

**Implementasyon:** `src/consensus/validation.cpp:CheckBlock()`

### Yugto 3: Contextual Header Validation (ContextualCheckBlockHeader)

**PoCX-Specific Validation:**

```cpp
#ifdef ENABLE_POCX
    // Hakbang 1: I-validate ang generation signature
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Hakbang 2: I-validate ang base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Hakbang 3: I-validate ang proof of capacity
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Hakbang 4: I-verify ang deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Mga Hakbang ng Validation:**
1. **Generation Signature:** Dapat tumugma sa kalkuladong halaga mula sa nakaraang block
2. **Base Target:** Dapat tumugma sa kalkulasyon ng difficulty adjustment
3. **Scaling Level:** Dapat tugunan ang network minimum (`compression >= min_compression`)
4. **Quality Claim:** Ang isinumiteng quality ay dapat tumugma sa computed quality mula sa proof
5. **Proof of Capacity:** Cryptographic proof validation (SIMD-optimized)
6. **Deadline Timing:** Ang time-bended deadline (`poc_time`) ay dapat ≤ lumipas na oras

**Implementasyon:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Yugto 4: Block Connection (ConnectBlock)

**Buong Contextual Validation:**

```cpp
#ifdef ENABLE_POCX
    // Pinahabang signature validation na may suporta sa assignment
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Pinahabang Signature Validation:**
1. Gawin ang pangunahing signature validation
2. I-extract ang account ID mula sa recovered pubkey
3. Kunin ang effective signer para sa plot address: `GetEffectiveSigner(plot_address, height, view)`
4. I-verify na ang pubkey account ay tumutugma sa effective signer

**Assignment Logic:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Ibalik ang assigned signer
    }

    return plotAddress;  // Walang assignment - ang may-ari ng plot ang lumalagda
}
```

**Implementasyon:**
- Connection: `src/validation.cpp:ConnectBlock()`
- Pinahabang validation: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Assignment logic: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Yugto 5: Chain Activation

**ProcessNewBlock Flow:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → I-validate at i-store sa disk
    2. ActivateBestChain → I-update ang chain tip kung ito ang pinakamahusay na chain
    3. Abisuhan ang network ng bagong block
}
```

**Implementasyon:** `src/validation.cpp:ProcessNewBlock()`

### Buod ng Validation

**Kumpletong Validation Path:**
```
Tanggapin ang Block
    ↓
CheckBlockHeader (pangunahing signature)
    ↓
CheckBlock (transaksyon, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC proof, deadline)
    ↓
ConnectBlock (pinahabang signature na may mga assignment, state transition)
    ↓
ActivateBestChain (paghawak ng reorg, chain extension)
    ↓
Network Propagation
```

---

## Sistema ng Assignment

### Pangkalahatang-tanaw

Pinapayagan ng mga assignment ang mga may-ari ng plot na magdelega ng mga karapatan sa forging sa ibang mga address habang pinapanatili ang pagmamay-ari ng plot.

**Mga Kaso ng Paggamit:**
- Pool mining (ang mga plot ay nag-a-assign sa pool address)
- Cold storage (ang mining key ay hiwalay sa pagmamay-ari ng plot)
- Multi-party mining (shared infrastructure)

### Arkitektura ng Assignment

**OP_RETURN-Only na Disenyo:**
- Ang mga assignment ay naka-store sa mga OP_RETURN output (walang UTXO)
- Walang mga kinakailangan sa paggastos (walang dust, walang bayarin para sa paghawak)
- Sinusubaybayan sa pinahabang state ng CCoinsViewCache
- Nag-a-activate pagkatapos ng delay period (default: 4 block)

**Mga Assignment State:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Walang assignment
    ASSIGNING = 1,   // Assignment na naghihintay ng activation (delay period)
    ASSIGNED = 2,    // Assignment active, pinapayagan ang forging
    REVOKING = 3,    // Revocation pending (delay period, aktibo pa rin)
    REVOKED = 4      // Revocation complete, hindi na aktibo ang assignment
};
```

### Paggawa ng mga Assignment

**Format ng Transaksyon:**
```cpp
Transaction {
    inputs: [any]  // Pinapatunayan ang pagmamay-ari ng plot address
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Mga Panuntunan sa Validation:**
1. Ang input ay dapat nilagdaan ng may-ari ng plot (pinapatunayan ang pagmamay-ari)
2. Ang OP_RETURN ay naglalaman ng valid na assignment data
3. Ang plot ay dapat UNASSIGNED o REVOKED
4. Walang duplicate pending assignment sa mempool
5. Naibayad na ang minimum transaction fee

**Activation:**
- Ang assignment ay nagiging ASSIGNING sa confirmation height
- Nagiging ASSIGNED pagkatapos ng delay period (4 block regtest, 30 block mainnet)
- Pinipigilan ng delay ang mabilis na reassignment sa panahon ng block race

**Implementasyon:** `src/script/forging_assignment.h`, validation sa ConnectBlock

### Pag-revoke ng mga Assignment

**Format ng Transaksyon:**
```cpp
Transaction {
    inputs: [any]  // Pinapatunayan ang pagmamay-ari ng plot address
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Epekto:**
- Agad na state transition sa REVOKED
- Ang may-ari ng plot ay maaaring mag-forge kaagad
- Maaaring gumawa ng bagong assignment pagkatapos

### Assignment Validation Habang Mining

**Pagtukoy ng Effective Signer:**
```cpp
// Sa submit_nonce validation
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Sa block forging
coinbase_script = P2WPKH(effective_signer);  // Papunta dito ang reward

// Sa block signature
signature = effective_signer_key.SignCompact(hash);  // Dapat lagdaan gamit ang effective signer
```

**Block Validation:**
```cpp
// Sa VerifyPoCXBlockCompactSignature (pinahaba)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Mga Pangunahing Katangian:**
- Ang proof ay laging naglalaman ng orihinal na plot address
- Ang signature ay dapat mula sa effective signer
- Ang coinbase ay nagbabayad sa effective signer
- Ang validation ay gumagamit ng assignment state sa block height

---

## Pagpapakalat sa Network

### Block Announcement

**Standard Bitcoin P2P Protocol:**
1. Ang forged block ay isinumite sa pamamagitan ng `ProcessNewBlock()`
2. Ang block ay na-validate at idinagdag sa chain
3. Network notification: `GetMainSignals().BlockConnected()`
4. I-broadcast ng P2P layer ang block sa mga peer

**Implementasyon:** Standard Bitcoin Core net_processing

### Block Relay

**Compact Blocks (BIP 152):**
- Ginagamit para sa mahusay na pagpapakalat ng block
- Ang mga transaction ID lamang ang ipinapadala sa simula
- Humihiling ang mga peer ng mga nawawalang transaksyon

**Full Block Relay:**
- Fallback kapag nabigo ang compact block
- Buong block data ang ipinapadala

### Mga Chain Reorganization

**Paghawak ng Reorg:**
```cpp
// Sa forger worker thread
if (current_tip_hash != stored_tip_hash) {
    // Na-detect ang chain reorganization
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Blockchain-Level:**
- Standard Bitcoin Core reorg handling
- Tinutukoy ang pinakamahusay na chain sa pamamagitan ng chainwork
- Ang mga nadisconnect na block ay bumabalik sa mempool

---

## Mga Teknikal na Detalye

### Deadlock Prevention

**ABBA Deadlock Pattern (Napigilan):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Solusyon:**
1. **submit_nonce:** Zero cs_main usage
   - Ang `GetNewBlockContext()` ay hinahawakan ang locking sa loob
   - Lahat ng validation bago ang forger submission

2. **Forger:** Queue-based na arkitektura
   - Isang worker thread (walang thread join)
   - Fresh context sa bawat access
   - Walang nested lock

3. **Mga wallet check:** Ginagawa bago ang mga mahal na operasyon
   - Maagang rejection kung walang available na key
   - Hiwalay sa blockchain state access

### Mga Performance Optimization

**Fast-Fail Validation:**
```cpp
1. Mga format check (agad)
2. Context validation (magaan)
3. Wallet verification (lokal)
4. Proof validation (mahal na SIMD)
```

**Isang Context Fetch:**
- Isang `GetNewBlockContext()` call bawat submission
- I-cache ang mga resulta para sa maraming pagsusuri
- Walang paulit-ulit na cs_main acquisition

**Queue Efficiency:**
- Magaang submission structure
- Walang base_target/deadline sa queue (kinakalkula ulit nang fresh)
- Minimal na memory footprint

### Paghawak ng Staleness

**"Stupid" Forger Design:**
- Walang mga blockchain event subscription
- Lazy validation kung kailan kailangan
- Tahimik na pag-discard ng mga stale submission

**Mga Benepisyo:**
- Simpleng arkitektura
- Walang kumplikadong synchronization
- Matibay laban sa mga edge case

**Mga Edge Case na Hinahawakan:**
- Mga pagbabago sa height → discard
- Mga pagbabago sa generation signature → discard
- Mga pagbabago sa base target → kalkulahin ulit ang deadline
- Mga reorg → reset ang forging state

### Mga Cryptographic na Detalye

**Generation Signature:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Block Signature Hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Compact Signature Format:**
- 65 byte: [recovery_id][r][s]
- Pinapayagan ang public key recovery
- Ginagamit para sa space efficiency

**Account ID:**
- 20-byte HASH160 ng compressed public key
- Tumutugma sa mga format ng Bitcoin address (P2PKH, P2WPKH)

### Mga Future Enhancement

**Mga Dokumentadong Limitasyon:**
1. Walang mga performance metric (submission rate, deadline distribution)
2. Walang detalyadong error categorization para sa mga miner
3. Limitadong forger status querying (kasalukuyang deadline, queue depth)

**Mga Potensyal na Pagpapabuti:**
- RPC para sa forger status
- Mga metric para sa mining efficiency
- Pinahusay na logging para sa debugging
- Suporta sa pool protocol

---

## Mga Sanggunian ng Code

**Mga Core Implementation:**
- RPC Interface: `src/pocx/rpc/mining.cpp`
- Forger Queue: `src/pocx/mining/scheduler.cpp`
- Consensus Validation: `src/pocx/consensus/validation.cpp`
- Proof Validation: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Block Validation: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Assignment Logic: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Context Management: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Mga Data Structure:**
- Block Format: `src/primitives/block.h`
- Consensus Parameters: `src/consensus/params.h`
- Assignment Tracking: `src/coins.h` (mga extension ng CCoinsViewCache)

---

## Appendix: Mga Algorithm Specification

### Time Bending Formula

**Mathematical Definition:**
```
deadline_seconds = quality / base_target  (raw)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

kung saan:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementasyon:**
- Fixed-point arithmetic (Q42 format)
- Integer-only cube root calculation
- Na-optimize para sa 256-bit arithmetic

### Quality Calculation

**Proseso:**
1. I-generate ang scoop mula sa generation signature at taas
2. Basahin ang plot data para sa kalkuladong scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Subukan ang mga scaling level mula min hanggang max
5. Ibalik ang pinakamahusay na quality na nakita

**Scaling:**
- Level X0: POC2 baseline (teoretikal)
- Level X1: XOR-transpose baseline
- Level Xn: 2^(n-1) × X1 work na naka-embed
- Mas mataas na scaling = mas maraming plot generation work

### Base Target Adjustment

**Bawat block na adjustment:**
1. Kalkulahin ang moving average ng mga kamakailang base target
2. Kalkulahin ang aktwal na timespan kumpara sa target timespan para sa rolling window
3. Ayusin ang base target nang proporsyonal
4. I-clamp upang maiwasan ang matitinding pagbabago

**Formula:**
```
avg_base_target = moving_average(kamakailang base target)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Sinasalamin ng dokumentasyong ito ang kumpletong implementasyon ng PoCX consensus mula Oktubre 2025.*

---

[← Nakaraan: Format ng Plot](2-plot-format.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Mga Forging Assignment →](4-forging-assignments.md)

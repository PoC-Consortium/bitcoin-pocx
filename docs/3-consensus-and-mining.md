[← Previous: Plot Format](2-plot-format.md) | [📘 Table of Contents](index.md) | [Next: Forging Assignments →](4-forging-assignments.md)

---

# Chapter 3: Bitcoin-PoCX Consensus and Mining Process

Complete technical specification of the PoCX (Proof of Capacity neXt generation) consensus mechanism and mining process integrated into Bitcoin Core.

---

## Table of Contents

1. [Overview](#overview)
2. [Consensus Architecture](#consensus-architecture)
3. [Mining Process](#mining-process)
4. [Block Validation](#block-validation)
5. [Assignment System](#assignment-system)
6. [Network Propagation](#network-propagation)
7. [Technical Details](#technical-details)

---

## Overview

Bitcoin-PoCX implements a pure Proof of Capacity consensus mechanism as a complete replacement for Bitcoin's Proof of Work. This is a new chain without backward compatibility requirements.

**Key Properties:**
- **Energy Efficient:** Mining uses pre-generated plot files instead of computational hashing
- **Time Bended Deadlines:** Distribution transformation (exponential→chi-squared) reduces long blocks, improves average block times
- **Assignment Support:** Plot owners can delegate forging rights to other addresses
- **Native C++ Integration:** Cryptographic algorithms implemented in C++ for consensus validation

**Mining Flow:**
```
External Miner → get_mining_info → Calculate Nonce → submit_nonce →
Forger Queue → Deadline Wait → Block Forging → Network Propagation →
Block Validation → Chain Extension
```

---

## Consensus Architecture

### Block Structure

PoCX blocks extend Bitcoin's block structure with additional consensus fields:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot seed (32 bytes)
    std::array<uint8_t, 20> account_id;       // Plot address (20-byte hash160)
    uint32_t compression;                     // Scaling level (1-255)
    uint64_t nonce;                           // Mining nonce (64-bit)
    uint64_t quality;                         // Claimed quality (PoC hash output)
};

class CBlockHeader {
    // Standard Bitcoin fields
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX consensus fields (replace nBits and nNonce)
    int nHeight;                              // Block height (context-free validation)
    uint256 generationSignature;              // Generation signature (mining entropy)
    uint64_t nBaseTarget;                     // Difficulty parameter (inverse difficulty)
    PoCXProof pocxProof;                      // Mining proof

    // Block signature fields
    std::array<uint8_t, 33> vchPubKey;        // Compressed public key (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Compact signature (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transactions
};
```

**Note:** The signature (`vchSignature`) is excluded from block hash computation to prevent malleability.

**Implementation:** `src/primitives/block.h`

### Generation Signature

The generation signature creates mining entropy and prevents precomputation attacks.

**Calculation:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis Block:** Uses a hardcoded initial generation signature

**Implementation:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Difficulty)

Base target is the inverse of difficulty - higher values mean easier mining.

**Adjustment Algorithm:**
- Targets block time: 120 seconds (mainnet), 1 second (regtest)
- Adjustment interval: Every block
- Uses moving average of recent base targets
- Clamped to prevent extreme difficulty swings

**Implementation:** `src/consensus/params.h`, difficulty adjustment in block creation

### Scaling Levels

PoCX supports scalable proof-of-work in plot files through scaling levels (Xn).

**Dynamic Bounds:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum accepted level
    uint8_t nPoCXTargetCompression;  // Recommended level
};
```

**Scaling Increase Schedule:**
- Exponential intervals: Years 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Minimum scaling level increases by 1
- Target scaling level increases by 1
- Maintains safety margin between plot creation and lookup costs
- Maximum scaling level: 255

**Implementation:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Mining Process

### 1. Mining Information Retrieval

**RPC Command:** `get_mining_info`

**Process:**
1. Call `GetNewBlockContext(chainman)` to fetch current blockchain state
2. Calculate dynamic compression bounds for current height
3. Return mining parameters

**Response:**
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

**Implementation:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Notes:**
- No locks held during response generation
- Context acquisition handles `cs_main` internally
- `block_hash` included for reference but not used in validation

### 2. External Mining

**External miner responsibilities:**
1. Read plot files from disk
2. Calculate scoop based on generation signature and height
3. Find nonce with best deadline
4. Submit to node via `submit_nonce`

**Plot File Format:**
- Based on POC2 format (Burstcoin)
- Enhanced with security fixes and scalability improvements
- See attribution in `CLAUDE.md`

**Miner Implementation:** External (e.g., based on Scavenger)

### 3. Nonce Submission and Validation

**RPC Command:** `submit_nonce`

**Parameters:**
```
height, generation_signature, account_id, seed, nonce, quality (optional)
```

**Validation Flow (Optimized Order):**

#### Step 1: Fast Format Validation
```cpp
// Account ID: 40 hex chars = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex chars = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Step 2: Context Acquisition
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Returns: height, generation_signature, base_target, block_hash
```

**Locking:** `cs_main` handled internally, no locks held in RPC thread

#### Step 3: Context Validation
```cpp
// Height check
if (height != context.height) reject;

// Generation signature check
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Step 4: Wallet Verification
```cpp
// Determine effective signer (considering assignments)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Check if node has private key for effective signer
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Assignment Support:** Plot owner may assign forging rights to another address. Wallet must have key for the effective signer, not necessarily the plot owner.

#### Step 5: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bytes
    block_height,
    nonce,
    seed,                // 32 bytes
    min_compression,
    max_compression,
    &result             // Output: quality, deadline
);
```

**Algorithm:**
1. Decode generation signature from hex
2. Calculate best quality in compression range using SIMD-optimized algorithms
3. Validate quality meets difficulty requirements
4. Return raw quality value

**Implementation:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Step 6: Time Bending Calculation
```cpp
// Raw difficulty-adjusted deadline (seconds)
uint64_t deadline_seconds = quality / base_target;

// Time Bended forge time (seconds)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending Formula:**
```
Y = scale * (X^(1/3))
where:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Purpose:** Transforms exponential to chi-squared distribution. Very good solutions forge later (network has time to scan disks), poor solutions improved. Reduces long blocks, maintains 120s average.

**Implementation:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 7: Forger Submission
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NOT deadline - recalculated in forger
    height,
    generation_signature
);
```

**Queue-Based Design:**
- Submission always succeeds (added to queue)
- RPC returns immediately
- Worker thread processes asynchronously

**Implementation:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger Queue Processing

**Architecture:**
- Single persistent worker thread
- FIFO submission queue
- Lock-free forging state (worker thread only)
- No nested locks (deadlock prevention)

**Worker Thread Main Loop:**
```cpp
while (!shutdown) {
    // 1. Check for queued submissions
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Wait for deadline or new submission
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission Logic:**
```cpp
1. Get fresh context: GetNewBlockContext(*chainman)

2. Staleness checks (silent discard):
   - Height mismatch → discard
   - Generation signature mismatch → discard
   - Tip block hash changed (reorg) → reset forging state

3. Quality comparison:
   - If quality >= current_best → discard

4. Calculate Time Bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Update forging state:
   - Cancel existing forging (if better found)
   - Store: account_id, seed, nonce, quality, deadline
   - Calculate: forge_time = block_time + deadline_seconds
   - Store tip hash for reorg detection
```

**Implementation:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline Wait and Block Forging

**WaitForDeadlineOrNewSubmission:**

**Wait Conditions:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**When Deadline Reached - Fresh Context Validation:**
```cpp
1. Get current context: GetNewBlockContext(*chainman)

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
       // Recalculate deadline with new base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Wait again
   }

5. All valid → ForgeBlock()
```

**ForgeBlock Process:**

```cpp
1. Determine effective signer (assignment support):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Create coinbase script:
   coinbase_script = P2WPKH(effective_signer);  // Pays effective signer

3. Create block template:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Add PoCX proof:
   block.pocxProof.account_id = plot_address;    // Original plot address
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Recalculate merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Sign block:
   // Use effective signer's key (may be different from plot owner)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Submit to chain:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Result handling:
   if (accepted) {
       log_success();
       reset_forging_state();  // Ready for next block
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementation:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Key Design Decisions:**
- Coinbase pays effective signer (respects assignments)
- Proof contains original plot address (for validation)
- Signature from effective signer's key (ownership proof)
- Template creation includes mempool transactions automatically

---

## Block Validation

### Incoming Block Validation Flow

When a block is received from the network or submitted locally, it undergoes validation in multiple stages:

### Stage 1: Header Validation (CheckBlockHeader)

**Context-Free Validation:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX Validation (when ENABLE_POCX defined):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Basic signature validation (no assignment support yet)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Basic Signature Validation:**
1. Check presence of pubkey and signature fields
2. Validate pubkey size (33 bytes compressed)
3. Validate signature size (65 bytes compact)
4. Recover pubkey from signature: `pubkey.RecoverCompact(hash, signature)`
5. Verify recovered pubkey matches stored pubkey

**Implementation:** `src/validation.cpp:CheckBlockHeader()`
**Signature Logic:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Stage 2: Block Validation (CheckBlock)

**Validates:**
- Merkle root correctness
- Transaction validity
- Coinbase requirements
- Block size limits
- Standard Bitcoin consensus rules

**Implementation:** `src/consensus/validation.cpp:CheckBlock()`

### Stage 3: Contextual Header Validation (ContextualCheckBlockHeader)

**PoCX-Specific Validation:**

```cpp
#ifdef ENABLE_POCX
    // Step 1: Validate generation signature
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Step 2: Validate base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Step 3: Validate proof of capacity
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

    // Step 4: Verify deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validation Steps:**
1. **Generation Signature:** Must match calculated value from previous block
2. **Base Target:** Must match difficulty adjustment calculation
3. **Scaling Level:** Must meet network minimum (`compression >= min_compression`)
4. **Quality Claim:** Submitted quality must match computed quality from proof
5. **Proof of Capacity:** Cryptographic proof validation (SIMD-optimized)
6. **Deadline Timing:** Time-bended deadline (`poc_time`) must be ≤ elapsed time

**Implementation:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Stage 4: Block Connection (ConnectBlock)

**Full Contextual Validation:**

```cpp
#ifdef ENABLE_POCX
    // Extended signature validation with assignment support
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Extended Signature Validation:**
1. Perform basic signature validation
2. Extract account ID from recovered pubkey
3. Get effective signer for plot address: `GetEffectiveSigner(plot_address, height, view)`
4. Verify pubkey account matches effective signer

**Assignment Logic:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Return assigned signer
    }

    return plotAddress;  // No assignment - plot owner signs
}
```

**Implementation:**
- Connection: `src/validation.cpp:ConnectBlock()`
- Extended validation: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Assignment logic: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Stage 5: Chain Activation

**ProcessNewBlock Flow:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validate and store to disk
    2. ActivateBestChain → Update chain tip if this is best chain
    3. Notify network of new block
}
```

**Implementation:** `src/validation.cpp:ProcessNewBlock()`

### Validation Summary

**Complete Validation Path:**
```
Receive Block
    ↓
CheckBlockHeader (basic signature)
    ↓
CheckBlock (transactions, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC proof, deadline)
    ↓
ConnectBlock (extended signature with assignments, state transitions)
    ↓
ActivateBestChain (reorg handling, chain extension)
    ↓
Network Propagation
```

---

## Assignment System

### Overview

Assignments allow plot owners to delegate forging rights to other addresses while maintaining plot ownership.

**Use Cases:**
- Pool mining (plots assign to pool address)
- Cold storage (mining key separate from plot ownership)
- Multi-party mining (shared infrastructure)

### Assignment Architecture

**OP_RETURN-Only Design:**
- Assignments stored in OP_RETURN outputs (no UTXO)
- No spending requirements (no dust, no fees for holding)
- Tracked in CCoinsViewCache extended state
- Activated after delay period (default: 4 blocks)

**Assignment States:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // No assignment exists
    ASSIGNING = 1,   // Assignment pending activation (delay period)
    ASSIGNED = 2,    // Assignment active, forging allowed
    REVOKING = 3,    // Revocation pending (delay period, still active)
    REVOKED = 4      // Revocation complete, assignment no longer active
};
```

### Creating Assignments

**Transaction Format:**
```cpp
Transaction {
    inputs: [any]  // Proves ownership of plot address
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validation Rules:**
1. Input must be signed by plot owner (proves ownership)
2. OP_RETURN contains valid assignment data
3. Plot must be UNASSIGNED or REVOKED
4. No duplicate pending assignments in mempool
5. Minimum transaction fee paid

**Activation:**
- Assignment becomes ASSIGNING at confirmation height
- Becomes ASSIGNED after delay period (4 blocks regtest, 30 blocks mainnet)
- Delay prevents quick reassignments during block races

**Implementation:** `src/script/forging_assignment.h`, validation in ConnectBlock

### Revoking Assignments

**Transaction Format:**
```cpp
Transaction {
    inputs: [any]  // Proves ownership of plot address
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effect:**
- Immediate state transition to REVOKED
- Plot owner can forge immediately
- Can create new assignment afterward

### Assignment Validation During Mining

**Effective Signer Determination:**
```cpp
// In submit_nonce validation
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// In block forging
coinbase_script = P2WPKH(effective_signer);  // Reward goes here

// In block signature
signature = effective_signer_key.SignCompact(hash);  // Must sign with effective signer
```

**Block Validation:**
```cpp
// In VerifyPoCXBlockCompactSignature (extended)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Key Properties:**
- Proof always contains original plot address
- Signature must be from effective signer
- Coinbase pays effective signer
- Validation uses assignment state at block height

---

## Network Propagation

### Block Announcement

**Standard Bitcoin P2P Protocol:**
1. Forged block submitted via `ProcessNewBlock()`
2. Block validated and added to chain
3. Network notification: `GetMainSignals().BlockConnected()`
4. P2P layer broadcasts block to peers

**Implementation:** Standard Bitcoin Core net_processing

### Block Relay

**Compact Blocks (BIP 152):**
- Used for efficient block propagation
- Only transaction IDs sent initially
- Peers request missing transactions

**Full Block Relay:**
- Fallback when compact blocks fail
- Complete block data transmitted

### Chain Reorganizations

**Reorg Handling:**
```cpp
// In forger worker thread
if (current_tip_hash != stored_tip_hash) {
    // Chain reorganization detected
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Blockchain-Level:**
- Standard Bitcoin Core reorg handling
- Best chain determined by chainwork
- Disconnected blocks returned to mempool

---

## Technical Details

### Deadlock Prevention

**ABBA Deadlock Pattern (Prevented):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Solution:**
1. **submit_nonce:** Zero cs_main usage
   - `GetNewBlockContext()` handles locking internally
   - All validation before forger submission

2. **Forger:** Queue-based architecture
   - Single worker thread (no thread joins)
   - Fresh context on every access
   - No nested locks

3. **Wallet checks:** Performed before expensive operations
   - Early rejection if no key available
   - Separate from blockchain state access

### Performance Optimizations

**Fast-Fail Validation:**
```cpp
1. Format checks (immediate)
2. Context validation (lightweight)
3. Wallet verification (local)
4. Proof validation (expensive SIMD)
```

**Single Context Fetch:**
- One `GetNewBlockContext()` call per submission
- Cache results for multiple checks
- No repeated cs_main acquisitions

**Queue Efficiency:**
- Lightweight submission structure
- No base_target/deadline in queue (recalculated fresh)
- Minimal memory footprint

### Staleness Handling

**"Stupid" Forger Design:**
- No blockchain event subscriptions
- Lazy validation when needed
- Silent discards of stale submissions

**Benefits:**
- Simple architecture
- No complex synchronization
- Robust against edge cases

**Edge Cases Handled:**
- Height changes → discard
- Generation signature changes → discard
- Base target changes → recalculate deadline
- Reorgs → reset forging state

### Cryptographic Details

**Generation Signature:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Block Signature Hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Compact Signature Format:**
- 65 bytes: [recovery_id][r][s]
- Allows public key recovery
- Used for space efficiency

**Account ID:**
- 20-byte HASH160 of compressed public key
- Matches Bitcoin address formats (P2PKH, P2WPKH)

### Future Enhancements

**Documented Limitations:**
1. No performance metrics (submission rates, deadline distributions)
2. No detailed error categorization for miners
3. Limited forger status querying (current deadline, queue depth)

**Potential Improvements:**
- RPC for forger status
- Metrics for mining efficiency
- Enhanced logging for debugging
- Pool protocol support

---

## Code References

**Core Implementations:**
- RPC Interface: `src/pocx/rpc/mining.cpp`
- Forger Queue: `src/pocx/mining/scheduler.cpp`
- Consensus Validation: `src/pocx/consensus/validation.cpp`
- Proof Validation: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Block Validation: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Assignment Logic: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Context Management: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Data Structures:**
- Block Format: `src/primitives/block.h`
- Consensus Parameters: `src/consensus/params.h`
- Assignment Tracking: `src/coins.h` (CCoinsViewCache extensions)

---

## Appendix: Algorithm Specifications

### Time Bending Formula

**Mathematical Definition:**
```
deadline_seconds = quality / base_target  (raw)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

where:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementation:**
- Fixed-point arithmetic (Q42 format)
- Integer-only cube root calculation
- Optimized for 256-bit arithmetic

### Quality Calculation

**Process:**
1. Generate scoop from generation signature and height
2. Read plot data for calculated scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Test scaling levels from min to max
5. Return best quality found

**Scaling:**
- Level X0: POC2 baseline (theoretical)
- Level X1: XOR-transpose baseline
- Level Xn: 2^(n-1) × X1 work embedded
- Higher scaling = more plot generation work

### Base Target Adjustment

**Every block adjustment:**
1. Calculate moving average of recent base targets
2. Calculate actual timespan vs target timespan for rolling window
3. Adjust base target proportionally
4. Clamp to prevent extreme swings

**Formula:**
```
avg_base_target = moving_average(recent base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*This documentation reflects the complete PoCX consensus implementation as of October 2025.*

---

[← Previous: Plot Format](2-plot-format.md) | [📘 Table of Contents](index.md) | [Next: Forging Assignments →](4-forging-assignments.md)

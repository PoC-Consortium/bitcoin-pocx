[← Nakaraan: Consensus at Mining](3-consensus-and-mining.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Sinkronisasyon ng Oras →](5-timing-security.md)

---

# Kabanata 4: Sistema ng PoCX Forging Assignment

## Buod ng Ehekutibo

Inilalarawan ng dokumentong ito ang **naipatupad** na sistema ng PoCX forging assignment gamit ang arkitektura na OP_RETURN-only. Pinapagana ng sistema ang mga may-ari ng plot na magdelega ng mga karapatan sa forging sa mga hiwalay na address sa pamamagitan ng mga on-chain na transaksyon, na may buong kaligtasan sa reorg at mga atomic na operasyon sa database.

**Katayuan:** ✅ Ganap na Naipatupad at Gumagana

## Pilosopiya ng Core Design

**Pangunahing Prinsipyo:** Ang mga assignment ay mga pahintulot, hindi mga asset

- Walang mga espesyal na UTXO na susubaybayan o gagastusin
- Ang assignment state ay naka-store nang hiwalay mula sa UTXO set
- Ang pagmamay-ari ay pinapatunayan ng transaction signature, hindi UTXO spending
- Buong pagsubaybay sa kasaysayan para sa kumpletong audit trail
- Mga atomic na update sa database sa pamamagitan ng LevelDB batch write

## Istruktura ng Transaksyon

### Format ng Assignment Transaction

```
Mga Input:
  [0]: Anumang UTXO na kinokontrol ng may-ari ng plot (nagpapatunay ng pagmamay-ari + nagbabayad ng fee)
       Dapat nilagdaan gamit ang private key ng may-ari ng plot
  [1+]: Opsyonal na karagdagang mga input para sa saklaw ng fee

Mga Output:
  [0]: OP_RETURN (POCX marker + plot address + forge address)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Laki: 46 byte sa kabuuan (1 byte OP_RETURN + 1 byte length + 44 byte data)
       Halaga: 0 BTC (hindi magagastos, hindi idinaragdag sa UTXO set)

  [1]: Sukli pabalik sa gumagamit (opsyonal, standard P2WPKH)
```

**Implementasyon:** `src/pocx/assignments/opcodes.cpp`

### Format ng Revocation Transaction

```
Mga Input:
  [0]: Anumang UTXO na kinokontrol ng may-ari ng plot (nagpapatunay ng pagmamay-ari + nagbabayad ng fee)
       Dapat nilagdaan gamit ang private key ng may-ari ng plot
  [1+]: Opsyonal na karagdagang mga input para sa saklaw ng fee

Mga Output:
  [0]: OP_RETURN (XCOP marker + plot address)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Laki: 26 byte sa kabuuan (1 byte OP_RETURN + 1 byte length + 24 byte data)
       Halaga: 0 BTC (hindi magagastos, hindi idinaragdag sa UTXO set)

  [1]: Sukli pabalik sa gumagamit (opsyonal, standard P2WPKH)
```

**Implementasyon:** `src/pocx/assignments/opcodes.cpp`

### Mga Marker

- **Assignment Marker:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Revocation Marker:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementasyon:** `src/pocx/assignments/opcodes.cpp`

### Mga Pangunahing Katangian ng Transaksyon

- Mga standard Bitcoin transaction (walang pagbabago sa protocol)
- Ang mga OP_RETURN output ay mapapatunayang hindi magagastos (hindi kailanman idinaragdag sa UTXO set)
- Ang pagmamay-ari ng plot ay pinapatunayan ng signature sa input[0] mula sa plot address
- Mababang gastos (~200 byte, karaniwang <0.0001 BTC fee)
- Awtomatikong pinipili ng wallet ang pinakamalaking UTXO mula sa plot address upang patunayan ang pagmamay-ari

## Arkitektura ng Database

### Istruktura ng Storage

Lahat ng assignment data ay naka-store sa parehong LevelDB database bilang UTXO set (`chainstate/`), ngunit may hiwalay na key prefix:

```
chainstate/ LevelDB:
├─ UTXO Set (Bitcoin Core standard)
│  └─ 'C' prefix: COutPoint → Coin
│
└─ Assignment State (mga karagdagan ng PoCX)
   └─ 'A' prefix: (plot_address, assignment_txid) → ForgingAssignment
       └─ Buong kasaysayan: lahat ng assignment bawat plot sa paglipas ng panahon
```

**Implementasyon:** `src/txdb.cpp`

### ForgingAssignment Structure

```cpp
struct ForgingAssignment {
    // Pagkakakilanlan
    std::array<uint8_t, 20> plotAddress;      // May-ari ng plot (20-byte P2WPKH hash)
    std::array<uint8_t, 20> forgingAddress;   // May hawak ng mga karapatan sa forging (20-byte P2WPKH hash)

    // Lifecycle ng assignment
    uint256 assignment_txid;                   // Transaksyon na lumikha ng assignment
    int assignment_height;                     // Block height noong ginawa
    int assignment_effective_height;           // Kung kailan ito magiging aktibo (height + delay)

    // Lifecycle ng revocation
    bool revoked;                              // Na-revoke ba ito?
    uint256 revocation_txid;                   // Transaksyon na nag-revoke nito
    int revocation_height;                     // Block height noong na-revoke
    int revocation_effective_height;           // Kung kailan magiging epektibo ang revocation (height + delay)

    // Mga method para sa state query
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementasyon:** `src/coins.h`

### Mga Assignment State

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Walang assignment
    ASSIGNING = 1,   // Assignment na ginawa, naghihintay ng activation delay
    ASSIGNED = 2,    // Assignment aktibo, pinapayagan ang forging
    REVOKING = 3,    // Na-revoke, ngunit aktibo pa rin sa delay period
    REVOKED = 4      // Ganap na na-revoke, hindi na aktibo
};
```

**Implementasyon:** `src/coins.h`

### Mga Database Key

```cpp
// History key: nag-iimbak ng buong assignment record
// Format ng key: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plot address (20 byte)
    int assignment_height;                // Height para sa sorting optimization
    uint256 assignment_txid;              // Transaction ID
};
```

**Implementasyon:** `src/txdb.cpp`

### Pagsubaybay sa Kasaysayan

- Ang bawat assignment ay permanenteng naka-store (hindi kailanman binubura maliban kung reorg)
- Maraming assignment bawat plot na sinusubaybayan sa paglipas ng panahon
- Pinapagana ang buong audit trail at mga historic state query
- Ang mga revoked assignment ay nananatili sa database na may `revoked=true`

## Pagpoproseso ng Block

### Integrasyon sa ConnectBlock

Ang mga assignment at revocation OP_RETURN ay pinoproseso sa panahon ng block connection sa `validation.cpp`:

```cpp
// Lokasyon: Pagkatapos ng script validation, bago ang UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // I-parse ang OP_RETURN data
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // I-verify ang pagmamay-ari (ang tx ay dapat nilagdaan ng may-ari ng plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Suriin ang plot state (dapat UNASSIGNED o REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Gumawa ng bagong assignment
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // I-store ang undo data
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // I-parse ang OP_RETURN data
            auto plot_addr = ParseRevocationOpReturn(output);

            // I-verify ang pagmamay-ari
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Kunin ang kasalukuyang assignment
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // I-store ang lumang state para sa undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Markahan bilang revoked
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

// Nagpapatuloy ang UpdateCoins nang normal (awtomatikong nilalaktawan ang mga OP_RETURN output)
```

**Implementasyon:** `src/validation.cpp:ConnectBlock()`

### Pag-verify ng Pagmamay-ari

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Suriin na kahit isang input ay nilagdaan ng may-ari ng plot
    for (const auto& input : tx.vin) {
        auto coin = view.GetCoin(input.prevout);
        if (!coin.has_value()) continue;

        // Check if P2WPKH witness program matches plot address
        int wit_version;
        std::vector<unsigned char> wit_program;
        if (!coin->out.scriptPubKey.IsWitnessProgram(wit_version, wit_program)) continue;
        if (wit_version != 0 || wit_program.size() != 20) continue;

        if (std::equal(wit_program.begin(), wit_program.end(),
                      plotAddress.begin())) {
            return true;  // Bitcoin Core already validated signature
        }
    }
    return false;
}
```

**Implementasyon:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Mga Activation Delay

Ang mga assignment at revocation ay may nako-configure na activation delay upang maiwasan ang mga reorg attack:

```cpp
// Mga consensus parameter (nako-configure bawat network)
// Halimbawa: 30 block = ~1 oras na may 2-minutong block time
consensus.nForgingAssignmentDelay;   // Delay ng activation ng assignment
consensus.nForgingRevocationDelay;   // Delay ng activation ng revocation
```

**Mga State Transition:**
- Assignment: `UNASSIGNED → ASSIGNING (delay) → ASSIGNED`
- Revocation: `ASSIGNED → REVOKING (delay) → REVOKED`

**Implementasyon:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validation sa Mempool

Ang mga transaction ng assignment at revocation ay vine-validate sa mempool acceptance upang i-reject ang mga invalid na transaksyon bago ang network propagation.

### Transaction-Level na Pagsusuri (CheckTransaction)

Ginagawa sa `src/consensus/tx_check.cpp` nang walang chain state access:

1. **Maximum na Isang POCX OP_RETURN:** Ang transaksyon ay hindi maaaring maglaman ng maraming POCX/XCOP marker

**Implementasyon:** `src/consensus/tx_check.cpp`

### Mga Pagsusuri sa Mempool Acceptance (PreChecks)

Ginagawa sa `src/validation.cpp` na may buong chain state at mempool access:

#### Assignment Validation

1. **Pagmamay-ari ng Plot:** Ang transaksyon ay dapat nilagdaan ng may-ari ng plot
2. **State ng Plot:** Ang plot ay dapat UNASSIGNED (0) o REVOKED (4)
3. **Mga Conflict sa Mempool:** Walang ibang assignment para sa plot na ito sa mempool (unang nakita ang panalo)

#### Revocation Validation

1. **Pagmamay-ari ng Plot:** Ang transaksyon ay dapat nilagdaan ng may-ari ng plot
2. **Aktibong Assignment:** Ang plot ay dapat nasa ASSIGNED (2) state lamang
3. **Mga Conflict sa Mempool:** Walang ibang revocation para sa plot na ito sa mempool

**Implementasyon:** `src/validation.cpp:PreChecks()`

### Daloy ng Validation

```
Transaction Broadcast
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Max isang POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ I-verify ang pagmamay-ari ng plot
  ✓ Suriin ang assignment state
  ✓ Suriin ang mga mempool conflict
       ↓
   Valid → Tanggapin sa Mempool
   Invalid → I-reject (huwag i-propagate)
       ↓
Block Mining
       ↓
ConnectBlock() [validation.cpp]
  ✓ I-validate ulit ang lahat ng pagsusuri (defense in depth)
  ✓ Ilapat ang mga state change
  ✓ I-record ang undo info
```

### Defense in Depth

Lahat ng mempool validation check ay muling isinasagawa sa panahon ng `ConnectBlock()` upang protektahan laban sa:
- Mga mempool bypass attack
- Mga invalid block mula sa mga malisyosong miner
- Mga edge case sa panahon ng reorg scenario

Ang block validation ang nananatiling authoritative para sa consensus.

## Mga Atomic na Database Update

### Three-Layer na Arkitektura

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Memory Cache)        │  ← Mga pagbabago sa assignment na sinusubaybayan sa memory
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Dirty tracking: dirtyPlots          │
│   - Deletions: deletedAssignments       │
│   - Memory tracking: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Database Layer)         │  ← Isang atomic write
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Disk Storage)                │  ← Mga ACID guarantee
│   - Atomic transaction                  │
└─────────────────────────────────────────┘
```

### Proseso ng Flush

Kapag tinawag ang `view.Flush()` sa panahon ng block connection:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Isulat ang mga pagbabago sa coin sa base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Isulat ang mga pagbabago sa assignment nang atomic
    if (fOk && !dirtyPlots.empty()) {
        // Kolektahin ang mga dirty assignment
        ForgingAssignmentsMap assignmentsToWrite;
        DeletedAssignmentsSet deletedToWrite;

        // Collect dirty assignments

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    auto key = std::make_pair(plotAddr, assignment.assignment_txid);
                    assignmentsToWrite[key] = assignment;
                }
            }
        }

        // Isulat sa database
        // Merge deleted assignments into assignmentsToWrite (needed for height lookup)
        // and build deletedToWrite set (plain key pairs)
        for (const auto& [key, assignment] : deletedAssignments) {
            assignmentsToWrite[key] = assignment;  // Provide assignment data for height
            deletedToWrite.insert(key);             // Mark for deletion
        }

        fOk = base->BatchWriteAssignments(assignmentsToWrite, deletedToWrite);
    }

    if (fOk) {
        cacheCoins.clear();
        ReallocateCache();
        pendingAssignments.clear();
        deletedAssignments.clear();
        dirtyPlots.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementasyon:** `src/coins.cpp:Flush()`

### Database Batch Write

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Isang LevelDB batch

    // 1. Markahan ang transition state
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Isulat ang lahat ng pagbabago sa coin
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Markahan ang consistent state
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMIC COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Mga assignment na isinulat nang hiwalay ngunit sa parehong konteksto ng database transaction
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const DeletedAssignmentsSet& deletedAssignments)  // set of (plot_addr, txid) pairs
{
    CDBBatch batch(*m_db);

    // Write all assignment history entries
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, assignment.assignment_height, txid), assignment);
    }

    // Erase deleted assignments — look up height from assignments map
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        auto it = assignments.find({plot_addr, txid});
        if (it != assignments.end()) {
            batch.Erase(AssignmentHistoryKey(plot_addr, it->second.assignment_height, txid));
        }
    }

    // ATOMIC COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementasyon:** `src/txdb.cpp:BatchWriteAssignments()`

### Mga Garantiya ng Atomicity

✅ **Ano ang atomic:**
- Lahat ng pagbabago sa coin sa loob ng isang block ay isinusulat nang atomic
- Lahat ng pagbabago sa assignment sa loob ng isang block ay isinusulat nang atomic
- Ang database ay nananatiling consistent sa mga crash

⚠️ **Kasalukuyang limitasyon:**
- Ang mga coin at assignment ay isinusulat sa **hiwalay** na LevelDB batch operation
- Parehong operasyon ay nangyayari sa panahon ng `view.Flush()`, ngunit hindi sa isang atomic write
- Sa praktika: Parehong batch ay nagkukumpleto nang mabilis bago mag-disk fsync
- Minimal ang panganib: Pareho ay kailangang i-replay mula sa parehong block sa panahon ng crash recovery

**Tandaan:** Ito ay naiiba sa orihinal na plano ng arkitektura na nananawagan para sa isang pinagsama-samang batch. Ang kasalukuyang implementasyon ay gumagamit ng dalawang batch ngunit pinapanatili ang consistency sa pamamagitan ng mga kasalukuyang mekanismo ng crash recovery ng Bitcoin Core (DB_HEAD_BLOCKS marker).

## Paghawak ng Reorg

### Istruktura ng Undo Data

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Ang assignment ay idinagdag (i-delete sa undo)
        MODIFIED = 1,   // Ang assignment ay binago (i-restore sa undo)
        REVOKED = 2     // Ang assignment ay na-revoke (i-un-revoke sa undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Buong state bago ang pagbabago
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo data
    std::vector<ForgingUndo> vforgingundo;  // Assignment undo data
};
```

**Implementasyon:** `src/undo.h`

### Proseso ng DisconnectBlock

Kapag ang isang block ay nadisconnect sa panahon ng isang reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standard UTXO disconnection ...

    // Basahin ang undo data mula sa disk
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // I-undo ang mga pagbabago sa assignment (iproseso sa reverse order)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Ang assignment ay idinagdag - alisin ito
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Ang assignment ay na-revoke - ibalik ang hindi revoked na state
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Ang assignment ay binago - ibalik ang nakaraang state
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementasyon:** `src/validation.cpp:DisconnectBlock()`

### Pamamahala ng Cache sa Panahon ng Reorg

```cpp
class CCoinsViewCache {
private:
    // Mga assignment cache
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Subaybayan ang mga binagong plot
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Subaybayan ang mga deletion
    mutable size_t cachedAssignmentsUsage{0};  // Pagsubaybay sa memory

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments[key] = assignment;
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
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }
};
```

**Implementasyon:** `src/coins.cpp`

## RPC Interface

### Mga Node Command (Hindi Kailangan ang Wallet)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Nagbabalik ng kasalukuyang assignment status para sa isang plot address:
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

**Implementasyon:** `src/pocx/rpc/assignments.cpp`

### Mga Wallet Command (Kailangan ang Wallet)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Gumagawa ng assignment transaction:
- Awtomatikong pinipili ang pinakamalaking UTXO mula sa plot address upang patunayan ang pagmamay-ari
- Bumubuo ng transaksyon na may OP_RETURN + change output
- Nilalagdaan gamit ang key ng may-ari ng plot
- Ibino-broadcast sa network

**Implementasyon:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Gumagawa ng revocation transaction:
- Awtomatikong pinipili ang pinakamalaking UTXO mula sa plot address upang patunayan ang pagmamay-ari
- Bumubuo ng transaksyon na may OP_RETURN + change output
- Nilalagdaan gamit ang key ng may-ari ng plot
- Ibino-broadcast sa network

**Implementasyon:** `src/pocx/rpc/assignments_wallet.cpp`

### Paggawa ng Wallet Transaction

Ang proseso ng paggawa ng wallet transaction:

```cpp
1. I-parse at i-validate ang mga address (dapat P2WPKH bech32)
2. Hanapin ang pinakamalaking UTXO mula sa plot address (nagpapatunay ng pagmamay-ari)
3. Gumawa ng pansamantalang transaksyon na may dummy output
4. Lagdaan ang transaksyon (makuha ang tumpak na laki kasama ang witness data)
5. Palitan ang dummy output ng OP_RETURN
6. Ayusin ang mga fee nang proporsyonal batay sa pagbabago ng laki
7. Lagdaan ulit ang final na transaksyon
8. I-broadcast sa network
```

**Pangunahing insight:** Ang wallet ay dapat gumastos mula sa plot address upang patunayan ang pagmamay-ari, kaya awtomatiko nitong pinipilit ang coin selection mula sa address na iyon.

**Implementasyon:** `src/pocx/assignments/transactions.cpp`

## Istruktura ng File

### Mga Core Implementation File

```
src/
├── coins.h                        # ForgingAssignment struct, mga CCoinsViewCache method [710 linya]
├── coins.cpp                      # Pamamahala ng cache, batch write [603 linya]
│
├── txdb.h                         # Mga CCoinsViewDB assignment method [90 linya]
├── txdb.cpp                       # Database read/write [349 linya]
│
├── undo.h                         # ForgingUndo structure para sa mga reorg
│
├── validation.cpp                 # Integrasyon ng ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN format, parsing, verification
    │   ├── opcodes.cpp            # [259 linya] Mga marker definition, OP_RETURN op, ownership check
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState helper
    │   ├── assignment_state.cpp   # Mga function ng assignment state query
    │   ├── transactions.h         # API ng paggawa ng wallet transaction
    │   └── transactions.cpp       # create_assignment, revoke_assignment wallet function
    │
    ├── rpc/
    │   ├── assignments.h          # Mga Node RPC command (walang wallet)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # Mga Wallet RPC command
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Mga Katangian ng Performance

### Mga Database Operation

- **Kunin ang kasalukuyang assignment:** O(n) - i-scan ang lahat ng assignment para sa plot address upang mahanap ang pinakabago
- **Kunin ang assignment history:** O(n) - i-iterate ang lahat ng assignment para sa plot
- **Gumawa ng assignment:** O(1) - isang insert
- **Mag-revoke ng assignment:** O(1) - isang update
- **Reorg (bawat assignment):** O(1) - direktang application ng undo data

Kung saan n = bilang ng mga assignment para sa isang plot (karaniwang maliit, < 10)

### Paggamit ng Memory

- **Bawat assignment:** ~160 byte (ForgingAssignment struct)
- **Cache overhead:** Hash map overhead para sa dirty tracking
- **Karaniwang block:** <10 assignment = <2 KB memory

### Paggamit ng Disk

- **Bawat assignment:** ~200 byte sa disk (kasama ang LevelDB overhead)
- **10000 assignment:** ~2 MB disk space
- **Maliit kumpara sa UTXO set:** <0.001% ng karaniwang chainstate

## Mga Kasalukuyang Limitasyon at Gawain sa Hinaharap

### Limitasyon sa Atomicity

**Kasalukuyan:** Ang mga coin at assignment ay isinusulat sa hiwalay na LevelDB batch sa panahon ng `view.Flush()`

**Epekto:** Teoretikal na panganib ng inconsistency kung mag-crash sa pagitan ng mga batch

**Mitigation:**
- Parehong batch ay nagkukumpleto nang mabilis bago mag-fsync
- Ang crash recovery ng Bitcoin Core ay gumagamit ng DB_HEAD_BLOCKS marker
- Sa praktika: Hindi kailanman na-observe sa testing

**Pagpapabuti sa hinaharap:** Pagsamahin sa isang LevelDB batch operation

### Pruning ng Assignment History

**Kasalukuyan:** Lahat ng assignment ay naka-store nang walang hanggan

**Epekto:** ~200 byte bawat assignment magpakailanman

**Hinaharap:** Opsyonal na pruning ng mga ganap na na-revoke na assignment na mas luma sa N block

**Tandaan:** Hindi malamang na kailanganin - kahit 1 milyong assignment = 200 MB

## Katayuan ng Testing

### Mga Naipatupad na Test

✅ OP_RETURN parsing at validation
✅ Pag-verify ng pagmamay-ari
✅ Paggawa ng assignment sa ConnectBlock
✅ Revocation sa ConnectBlock
✅ Paghawak ng reorg sa DisconnectBlock
✅ Mga database read/write operation
✅ Mga state transition (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ Mga RPC command (get_assignment, create_assignment, revoke_assignment)
✅ Paggawa ng wallet transaction

### Mga Lugar na Saklaw ng Test

- Mga unit test: `src/test/pocx_*_tests.cpp`
- Mga functional test: `test/functional/feature_pocx_*.py`
- Mga integration test: Manual testing gamit ang regtest

## Mga Patakaran ng Consensus

### Mga Patakaran sa Paggawa ng Assignment

1. **Pagmamay-ari:** Ang transaksyon ay dapat nilagdaan ng may-ari ng plot
2. **State:** Ang plot ay dapat nasa UNASSIGNED o REVOKED state
3. **Format:** Valid na OP_RETURN na may POCX marker + 2x 20-byte address
4. **Natatangi:** Isang aktibong assignment bawat plot sa isang pagkakataon

### Mga Patakaran sa Revocation

1. **Pagmamay-ari:** Ang transaksyon ay dapat nilagdaan ng may-ari ng plot
2. **Pag-iral:** Ang assignment ay dapat umiiral at hindi pa na-revoke
3. **Format:** Valid na OP_RETURN na may XCOP marker + 20-byte address

### Mga Patakaran sa Activation

- **Activation ng assignment:** `assignment_height + nForgingAssignmentDelay`
- **Activation ng revocation:** `revocation_height + nForgingRevocationDelay`
- **Mga delay:** Nako-configure bawat network (hal., 30 block = ~1 oras na may 2-minutong block time)

### Block Validation

- Invalid assignment/revocation → block rejected (consensus failure)
- Ang mga OP_RETURN output ay awtomatikong hindi kasama sa UTXO set (standard Bitcoin behavior)
- Ang pagpoproseso ng assignment ay nangyayari bago ang mga UTXO update sa ConnectBlock

## Konklusyon

Ang sistema ng PoCX forging assignment tulad ng naipatupad ay nagbibigay ng:

✅ **Simplisidad:** Mga standard Bitcoin transaction, walang espesyal na UTXO
✅ **Cost-Effective:** Walang kinakailangang dust, transaction fee lamang
✅ **Kaligtasan sa Reorg:** Komprehensibong undo data na nagbabalik sa tamang state
✅ **Mga Atomic Update:** Consistency ng database sa pamamagitan ng LevelDB batch
✅ **Buong Kasaysayan:** Kumpletong audit trail ng lahat ng assignment sa paglipas ng panahon
✅ **Malinis na Arkitektura:** Minimal na modipikasyon sa Bitcoin Core, nakahiwalay na PoCX code
✅ **Production Ready:** Ganap na naipatupad, na-test, at gumagana

### Kalidad ng Implementasyon

- **Organisasyon ng code:** Mahusay - malinaw na paghihiwalay sa pagitan ng Bitcoin Core at PoCX
- **Paghawak ng error:** Komprehensibong consensus validation
- **Dokumentasyon:** Ang mga comment sa code at istruktura ay maayos na dokumentado
- **Testing:** Na-test ang pangunahing functionality, na-verify ang integrasyon

### Mga Na-validate na Pangunahing Desisyon sa Disenyo

1. ✅ OP_RETURN-only approach (kumpara sa UTXO-based)
2. ✅ Hiwalay na database storage (kumpara sa Coin extraData)
3. ✅ Buong pagsubaybay sa kasaysayan (kumpara sa current-only)
4. ✅ Pagmamay-ari sa pamamagitan ng signature (kumpara sa UTXO spending)
5. ✅ Mga activation delay (pumipigil sa mga reorg attack)

Matagumpay na nakamit ng sistema ang lahat ng mga layunin sa arkitektura na may malinis at mapanatiling implementasyon.

---

[← Nakaraan: Consensus at Mining](3-consensus-and-mining.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Sinkronisasyon ng Oras →](5-timing-security.md)

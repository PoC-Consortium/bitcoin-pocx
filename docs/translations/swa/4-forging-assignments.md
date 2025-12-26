[← Iliyotangulia: Makubaliano na Uchimbaji](3-consensus-and-mining.md) | [Yaliyomo](index.md) | [Inayofuata: Usawazishaji wa Muda →](5-timing-security.md)

---

# Sura ya 4: Mfumo wa Ugawaji wa Kuunda wa PoCX

## Muhtasari wa Mtendaji

Hati hii inaelezea mfumo wa ugawaji wa kuunda wa PoCX **uliotekelezwa** kwa kutumia muundo wa OP_RETURN pekee. Mfumo unawezesha wamiliki wa plot kukabidhi haki za kuunda kwa anwani tofauti kupitia miamala ya on-chain, na usalama kamili wa reorg na operesheni za atomiki za hifadhidata.

**Hali:** Imetekelezwa na Inafanya Kazi Kikamilifu

## Falsafa ya Msingi ya Usanifu

**Kanuni Muhimu:** Ugawaji ni ruhusa, sio mali

- Hakuna UTXO maalum za kufuatilia au kutumia
- Hali ya ugawaji imehifadhiwa tofauti na seti ya UTXO
- Umiliki unathibitishwa na sahihi ya muamala, sio matumizi ya UTXO
- Ufuatiliaji kamili wa historia kwa rekodi kamili ya ukaguzi
- Sasisho za atomiki za hifadhidata kupitia uandishi wa kundi la LevelDB

## Muundo wa Muamala

### Muundo wa Muamala wa Ugawaji

```
Ingizo:
  [0]: UTXO yoyote inayodhibitiwa na mmiliki wa plot (inathibitisha umiliki + inalipa ada)
       Lazima isainiwe na ufunguo wa kibinafsi wa mmiliki wa plot
  [1+]: Ingizo za ziada za hiari kwa kulipia ada

Matokeo:
  [0]: OP_RETURN (alama ya POCX + anwani ya plot + anwani ya kuunda)
       Muundo: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Ukubwa: byte 46 jumla (1 byte OP_RETURN + 1 byte urefu + 44 byte data)
       Thamani: 0 BTC (haiwezi kutumika, haiongezwi kwenye seti ya UTXO)

  [1]: Chenji inarudi kwa mtumiaji (hiari, P2WPKH ya kawaida)
```

**Utekelezaji:** `src/pocx/assignments/opcodes.cpp:25-52`

### Muundo wa Muamala wa Kubatilisha

```
Ingizo:
  [0]: UTXO yoyote inayodhibitiwa na mmiliki wa plot (inathibitisha umiliki + inalipa ada)
       Lazima isainiwe na ufunguo wa kibinafsi wa mmiliki wa plot
  [1+]: Ingizo za ziada za hiari kwa kulipia ada

Matokeo:
  [0]: OP_RETURN (alama ya XCOP + anwani ya plot)
       Muundo: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Ukubwa: byte 26 jumla (1 byte OP_RETURN + 1 byte urefu + 24 byte data)
       Thamani: 0 BTC (haiwezi kutumika, haiongezwi kwenye seti ya UTXO)

  [1]: Chenji inarudi kwa mtumiaji (hiari, P2WPKH ya kawaida)
```

**Utekelezaji:** `src/pocx/assignments/opcodes.cpp:54-77`

### Alama

- **Alama ya Ugawaji:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Alama ya Kubatilisha:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Utekelezaji:** `src/pocx/assignments/opcodes.cpp:15-19`

### Sifa Muhimu za Muamala

- Miamala ya kawaida ya Bitcoin (hakuna mabadiliko ya itifaki)
- Matokeo ya OP_RETURN yanaweza kuthibitishwa kuwa hayawezi kutumika (hayaongezwi kamwe kwenye seti ya UTXO)
- Umiliki wa plot unathibitishwa na sahihi kwenye ingizo[0] kutoka anwani ya plot
- Gharama ya chini (~byte 200, kawaida <0.0001 BTC ada)
- Pochi inachagua moja kwa moja UTXO kubwa zaidi kutoka anwani ya plot kuthibitisha umiliki

## Muundo wa Hifadhidata

### Muundo wa Hifadhi

Data yote ya ugawaji imehifadhiwa katika hifadhidata sawa ya LevelDB na seti ya UTXO (`chainstate/`), lakini na viambishi tofauti vya ufunguo:

```
chainstate/ LevelDB:
├─ Seti ya UTXO (kawaida ya Bitcoin Core)
│  └─ kiambishi cha 'C': COutPoint → Coin
│
└─ Hali ya Ugawaji (nyongeza za PoCX)
   └─ kiambishi cha 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Historia kamili: ugawaji wote kwa plot kwa wakati
```

**Utekelezaji:** `src/txdb.cpp:237-348`

### Muundo wa ForgingAssignment

```cpp
struct ForgingAssignment {
    // Utambulisho
    std::array<uint8_t, 20> plotAddress;      // Mmiliki wa plot (hash ya P2WPKH ya byte 20)
    std::array<uint8_t, 20> forgingAddress;   // Mshika haki za kuunda (hash ya P2WPKH ya byte 20)

    // Mzunguko wa maisha wa ugawaji
    uint256 assignment_txid;                   // Muamala uliounda ugawaji
    int assignment_height;                     // Urefu wa bloku ulioundwa
    int assignment_effective_height;           // Wakati unakuwa hai (height + delay)

    // Mzunguko wa maisha wa kubatilisha
    bool revoked;                              // Hii imebatilishwa?
    uint256 revocation_txid;                   // Muamala ulioibatilisha
    int revocation_height;                     // Urefu wa bloku ulibatilishwa
    int revocation_effective_height;           // Wakati kubatilisha kunakuwa hai (height + delay)

    // Mbinu za hoja ya hali
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Utekelezaji:** `src/coins.h:111-178`

### Hali za Ugawaji

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Hakuna ugawaji uliopo
    ASSIGNING = 1,   // Ugawaji umeundwa, unasubiri ucheleweshaji wa uanzishaji
    ASSIGNED = 2,    // Ugawaji unafanya kazi, kuunda kunaruhusiwa
    REVOKING = 3,    // Umebatilishwa, lakini bado unafanya kazi wakati wa kipindi cha ucheleweshaji
    REVOKED = 4      // Umebatilishwa kikamilifu, haufanyi kazi tena
};
```

**Utekelezaji:** `src/coins.h:98-104`

### Funguo za Hifadhidata

```cpp
// Ufunguo wa historia: huhifadhi rekodi kamili ya ugawaji
// Muundo wa ufunguo: (kiambishi, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Anwani ya plot (byte 20)
    int assignment_height;                // Urefu kwa uboreshaji wa kupanga
    uint256 assignment_txid;              // Kitambulisho cha muamala
};
```

**Utekelezaji:** `src/txdb.cpp:245-262`

### Ufuatiliaji wa Historia

- Kila ugawaji umehifadhiwa kudumu (haufutwa kamwe isipokuwa reorg)
- Ugawaji mwingi kwa plot unafuatiliwa kwa wakati
- Inawezesha rekodi kamili ya ukaguzi na hoja za hali ya kihistoria
- Ugawaji uliobatilishwa unabaki katika hifadhidata na `revoked=true`

## Uchakataji wa Bloku

### Muungano wa ConnectBlock

OP_RETURN za ugawaji na kubatilisha zinachakatwa wakati wa muunganisho wa bloku katika `validation.cpp`:

```cpp
// Mahali: Baada ya uthibitishaji wa script, kabla ya UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Changanua data ya OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Thibitisha umiliki (tx lazima isainiwe na mmiliki wa plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Angalia hali ya plot (lazima iwe UNASSIGNED au REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Unda ugawaji mpya
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Hifadhi data ya kutengua
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Changanua data ya OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Thibitisha umiliki
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Pata ugawaji wa sasa
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Hifadhi hali ya zamani kwa kutengua
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Alama kama imebatilishwa
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

// UpdateCoins inaendelea kawaida (inaacha moja kwa moja matokeo ya OP_RETURN)
```

**Utekelezaji:** `src/validation.cpp:2775-2878`

### Uthibitishaji wa Umiliki

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Angalia kwamba angalau ingizo moja imesainiwa na mmiliki wa plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Toa lengwa
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Angalia kama P2WPKH kwa anwani ya plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core tayari imethibitisha sahihi
                return true;
            }
        }
    }
    return false;
}
```

**Utekelezaji:** `src/pocx/assignments/opcodes.cpp:217-256`

### Ucheleweshaji wa Uanzishaji

Ugawaji na kubatilisha una ucheleweshaji wa uanzishaji unaoweza kusanidiwa kuzuia mashambulizi ya reorg:

```cpp
// Vigezo vya makubaliano (vinaweza kusanidiwa kwa mtandao)
// Mfano: bloku 30 = ~saa 1 na muda wa bloku wa dakika 2
consensus.nForgingAssignmentDelay;   // Ucheleweshaji wa uanzishaji wa ugawaji
consensus.nForgingRevocationDelay;   // Ucheleweshaji wa uanzishaji wa kubatilisha
```

**Mabadiliko ya Hali:**
- Ugawaji: `UNASSIGNED → ASSIGNING (ucheleweshaji) → ASSIGNED`
- Kubatilisha: `ASSIGNED → REVOKING (ucheleweshaji) → REVOKED`

**Utekelezaji:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Uthibitishaji wa Mempool

Miamala ya ugawaji na kubatilisha inathiditishwa wakati wa kukubalika kwa mempool kukataa miamala isiyo halali kabla ya usambazaji wa mtandao.

### Ukaguzi wa Kiwango cha Muamala (CheckTransaction)

Unafanywa katika `src/consensus/tx_check.cpp` bila ufikiaji wa hali ya mtandao:

1. **OP_RETURN Moja ya POCX Zaidi:** Muamala hauwezi kuwa na alama nyingi za POCX/XCOP

**Utekelezaji:** `src/consensus/tx_check.cpp:63-77`

### Ukaguzi wa Kukubalika kwa Mempool (PreChecks)

Unafanywa katika `src/validation.cpp` na ufikiaji kamili wa hali ya mtandao na mempool:

#### Uthibitishaji wa Ugawaji

1. **Umiliki wa Plot:** Muamala lazima usainiwe na mmiliki wa plot
2. **Hali ya Plot:** Plot lazima iwe UNASSIGNED (0) au REVOKED (4)
3. **Migongano ya Mempool:** Hakuna ugawaji mwingine kwa plot hii katika mempool (kwanza kuonekana inashinda)

#### Uthibitishaji wa Kubatilisha

1. **Umiliki wa Plot:** Muamala lazima usainiwe na mmiliki wa plot
2. **Ugawaji Unaofanya Kazi:** Plot lazima iwe katika hali ya ASSIGNED (2) pekee
3. **Migongano ya Mempool:** Hakuna kubatilisha nyingine kwa plot hii katika mempool

**Utekelezaji:** `src/validation.cpp:898-993`

### Mtiririko wa Uthibitishaji

```
Kutangaza Muamala
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ OP_RETURN moja ya POCX zaidi
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Thibitisha umiliki wa plot
  ✓ Angalia hali ya ugawaji
  ✓ Angalia migongano ya mempool
       ↓
   Halali → Kubali kwenye Mempool
   Si Halali → Kataa (usisambaze)
       ↓
Uchimbaji wa Bloku
       ↓
ConnectBlock() [validation.cpp]
  ✓ Thibitisha tena ukaguzi wote (ulinzi wa kina)
  ✓ Tekeleza mabadiliko ya hali
  ✓ Rekodi habari ya kutengua
```

### Ulinzi wa Kina

Ukaguzi wote wa uthibitishaji wa mempool unafanywa tena wakati wa `ConnectBlock()` kulinda dhidi ya:
- Mashambulizi ya kupita mempool
- Bloku zisizo halali kutoka kwa wachimbaji waovu
- Hali za ukingo wakati wa hali za reorg

Uthibitishaji wa bloku unabaki kuwa wa mamlaka kwa makubaliano.

## Sasisho za Atomiki za Hifadhidata

### Muundo wa Tabaka Tatu

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Cache ya Kumbukumbu) │  ← Mabadiliko ya ugawaji yanafuatiliwa kumbukumbuni
│   - Sarafu: cacheCoins                  │
│   - Ugawaji: pendingAssignments         │
│   - Ufuatiliaji wa uchafu: dirtyPlots   │
│   - Kufutwa: deletedAssignments         │
│   - Ufuatiliaji wa kumbukumbu: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Tabaka la Hifadhidata)  │  ← Uandishi mmoja wa atomiki
│   - BatchWrite(): UTXO + Ugawaji        │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Hifadhi ya Diski)            │  ← Dhamana za ACID
│   - Muamala wa atomiki                  │
└─────────────────────────────────────────┘
```

### Mchakato wa Flush

Wakati `view.Flush()` inaitwa wakati wa muunganisho wa bloku:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Andika mabadiliko ya sarafu kwa msingi
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Andika mabadiliko ya ugawaji kwa atomiki
    if (fOk && !dirtyPlots.empty()) {
        // Kusanya ugawaji mchafu
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tupu - haitumiki

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Andika kwenye hifadhidata
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Safisha ufuatiliaji
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Achia kumbukumbu
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Utekelezaji:** `src/coins.cpp:278-315`

### Uandishi wa Kundi la Hifadhidata

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Kundi moja la LevelDB

    // 1. Alama hali ya mpito
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Andika mabadiliko yote ya sarafu
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Alama hali thabiti
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. AHIDI KWA ATOMIKI
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Ugawaji unaandikwa tofauti lakini katika muktadha sawa wa muamala wa hifadhidata
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Kigezo kisichotumika (kimebaki kwa utangamano wa API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Kundi jipya, lakini hifadhidata sawa

    // Andika historia ya ugawaji
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Futa ugawaji uliofutwa kutoka historia
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // AHIDI KWA ATOMIKI
    return m_db->WriteBatch(batch);
}
```

**Utekelezaji:** `src/txdb.cpp:332-348`

### Dhamana za Atomiki

**Ni nini atomiki:**
- Mabadiliko yote ya sarafu ndani ya bloku yanaandikwa kwa atomiki
- Mabadiliko yote ya ugawaji ndani ya bloku yanaandikwa kwa atomiki
- Hifadhidata inabaki thabiti kati ya kuanguka

**Kikwazo cha sasa:**
- Sarafu na ugawaji vinaandikwa katika operesheni **tofauti** za kundi la LevelDB
- Operesheni zote mbili zinafanyika wakati wa `view.Flush()`, lakini sio katika uandishi mmoja wa atomiki
- Kivitendo: Makundi yote mawili yanakamilika kwa haraka kabla ya disk fsync
- Hatari ni ndogo: Yote mawili yangehitajika kuchezwa tena kutoka bloku sawa wakati wa uokoaji wa kuanguka

**Kumbuka:** Hii inatofautiana na mpango wa awali wa muundo ambao uliomba kundi moja lililounganishwa. Utekelezaji wa sasa unatumia makundi mawili lakini unadumisha uthabiti kupitia taratibu zilizopo za uokoaji wa kuanguka za Bitcoin Core (alama ya DB_HEAD_BLOCKS).

## Kushughulikia Reorg

### Muundo wa Data ya Kutengua

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Ugawaji uliongezwa (futa wakati wa kutengua)
        MODIFIED = 1,   // Ugawaji ulirekebishwa (rejesha wakati wa kutengua)
        REVOKED = 2     // Ugawaji ulibatilishwa (tengua kubatilisha wakati wa kutengua)
    };

    UndoType type;
    ForgingAssignment assignment;  // Hali kamili kabla ya mabadiliko
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Data ya kutengua ya UTXO
    std::vector<ForgingUndo> vforgingundo;  // Data ya kutengua ya ugawaji
};
```

**Utekelezaji:** `src/undo.h:63-105`

### Mchakato wa DisconnectBlock

Bloku inapounganishwa wakati wa reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... kukatisha kawaida ya UTXO ...

    // Soma data ya kutengua kutoka diski
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Tengua mabadiliko ya ugawaji (chakata kwa mpangilio wa nyuma)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Ugawaji uliongezwa - ondoa
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Ugawaji ulibatilishwa - rejesha hali isiyobatilishwa
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Ugawaji ulirekebishwa - rejesha hali ya awali
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Utekelezaji:** `src/validation.cpp:2381-2415`

### Usimamizi wa Cache Wakati wa Reorg

```cpp
class CCoinsViewCache {
private:
    // Cache za ugawaji
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Fuatilia plot zilizorekebishwa
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Fuatilia kufutwa
    mutable size_t cachedAssignmentsUsage{0};  // Ufuatiliaji wa kumbukumbu

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

**Utekelezaji:** `src/coins.cpp:494-565`

## Kiolesura cha RPC

### Amri za Nodi (Hakuna Pochi Inayohitajika)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Inarudisha hali ya sasa ya ugawaji kwa anwani ya plot:
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

**Utekelezaji:** `src/pocx/rpc/assignments.cpp:31-126`

### Amri za Pochi (Pochi Inahitajika)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Inaunda muamala wa ugawaji:
- Inachagua moja kwa moja UTXO kubwa zaidi kutoka anwani ya plot kuthibitisha umiliki
- Inajenga muamala na OP_RETURN + tokeo la chenji
- Inasaini na ufunguo wa mmiliki wa plot
- Inatangaza kwenye mtandao

**Utekelezaji:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Inaunda muamala wa kubatilisha:
- Inachagua moja kwa moja UTXO kubwa zaidi kutoka anwani ya plot kuthibitisha umiliki
- Inajenga muamala na OP_RETURN + tokeo la chenji
- Inasaini na ufunguo wa mmiliki wa plot
- Inatangaza kwenye mtandao

**Utekelezaji:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Uundaji wa Muamala wa Pochi

Mchakato wa uundaji wa muamala wa pochi:

```cpp
1. Changanua na thibitisha anwani (lazima iwe P2WPKH bech32)
2. Pata UTXO kubwa zaidi kutoka anwani ya plot (inathibitisha umiliki)
3. Unda muamala wa muda na tokeo la dummy
4. Saini muamala (pata ukubwa sahihi na data ya shahidi)
5. Badilisha tokeo la dummy na OP_RETURN
6. Rekebisha ada kwa uwiano kulingana na mabadiliko ya ukubwa
7. Saini tena muamala wa mwisho
8. Tangaza kwenye mtandao
```

**Ufahamu muhimu:** Pochi lazima itumie kutoka anwani ya plot kuthibitisha umiliki, kwa hivyo inashurutisha moja kwa moja uchaguzi wa sarafu kutoka anwani hiyo.

**Utekelezaji:** `src/pocx/assignments/transactions.cpp:38-263`

## Muundo wa Faili

### Faili za Utekelezaji wa Msingi

```
src/
├── coins.h                        # Muundo wa ForgingAssignment, mbinu za CCoinsViewCache [mistari 710]
├── coins.cpp                      # Usimamizi wa cache, uandishi wa kundi [mistari 603]
│
├── txdb.h                         # Mbinu za ugawaji za CCoinsViewDB [mistari 90]
├── txdb.cpp                       # Kusoma/kuandika hifadhidata [mistari 349]
│
├── undo.h                         # Muundo wa ForgingUndo kwa reorg
│
├── validation.cpp                 # Muungano wa ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Muundo wa OP_RETURN, uchanganuzi, uthibitishaji
    │   ├── opcodes.cpp            # [mistari 259] Ufafanuzi wa alama, operesheni za OP_RETURN, ukaguzi wa umiliki
    │   ├── assignment_state.h     # Wasaidizi wa GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Kazi za hoja ya hali ya ugawaji
    │   ├── transactions.h         # API ya uundaji wa muamala wa pochi
    │   └── transactions.cpp       # Kazi za pochi za create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Amri za RPC za nodi (hakuna pochi)
    │   ├── assignments.cpp        # RPC za get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Amri za RPC za pochi
    │   └── assignments_wallet.cpp # RPC za create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Sifa za Utendaji

### Operesheni za Hifadhidata

- **Pata ugawaji wa sasa:** O(n) - changanua ugawaji wote kwa anwani ya plot kupata wa hivi karibuni
- **Pata historia ya ugawaji:** O(n) - rudia ugawaji wote kwa plot
- **Unda ugawaji:** O(1) - kuingiza moja
- **Batilisha ugawaji:** O(1) - kusasisha moja
- **Reorg (kwa ugawaji):** O(1) - matumizi ya moja kwa moja ya data ya kutengua

Ambapo n = idadi ya ugawaji kwa plot (kawaida ndogo, < 10)

### Matumizi ya Kumbukumbu

- **Kwa ugawaji:** ~byte 160 (muundo wa ForgingAssignment)
- **Gharama ya cache:** Gharama ya ramani ya hash kwa ufuatiliaji wa uchafu
- **Bloku ya kawaida:** <ugawaji 10 = kumbukumbu <2 KB

### Matumizi ya Diski

- **Kwa ugawaji:** ~byte 200 kwenye diski (na gharama ya LevelDB)
- **Ugawaji 10000:** ~2 MB nafasi ya diski
- **Haihusiani kulinganishwa na seti ya UTXO:** <0.001% ya chainstate ya kawaida

## Vikwazo vya Sasa na Kazi ya Baadaye

### Kikwazo cha Atomiki

**Sasa:** Sarafu na ugawaji vinaandikwa katika makundi tofauti ya LevelDB wakati wa `view.Flush()`

**Athari:** Hatari ya kinadharia ya kutokuwa thabiti ikiwa kuanguka kunafanyika kati ya makundi

**Upunguzaji:**
- Makundi yote mawili yanakamilika kwa haraka kabla ya fsync
- Uokoaji wa kuanguka wa Bitcoin Core unatumia alama ya DB_HEAD_BLOCKS
- Kivitendo: Haikuonekana kamwe katika majaribio

**Uboreshaji wa baadaye:** Unganisha katika operesheni moja ya kundi la LevelDB

### Kupogoa Historia ya Ugawaji

**Sasa:** Ugawaji wote umehifadhiwa bila kikomo

**Athari:** ~byte 200 kwa ugawaji milele

**Baadaye:** Kupogoa kwa hiari kwa ugawaji uliobatilishwa kikamilifu mkubwa zaidi ya bloku N

**Kumbuka:** Haiwezekani kuhitajika - hata ugawaji milioni 1 = 200 MB

## Hali ya Majaribio

### Majaribio Yaliyotekelezwa

- Uchanganuzi na uthibitishaji wa OP_RETURN
- Uthibitishaji wa umiliki
- Uundaji wa ugawaji wa ConnectBlock
- Kubatilisha kwa ConnectBlock
- Kushughulikia reorg kwa DisconnectBlock
- Operesheni za kusoma/kuandika za hifadhidata
- Mabadiliko ya hali (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- Amri za RPC (get_assignment, create_assignment, revoke_assignment)
- Uundaji wa muamala wa pochi

### Maeneo ya Majaribio

- Majaribio ya kitengo: `src/test/pocx_*_tests.cpp`
- Majaribio ya utendaji: `test/functional/feature_pocx_*.py`
- Majaribio ya muungano: Majaribio ya mikono na regtest

## Sheria za Makubaliano

### Sheria za Uundaji wa Ugawaji

1. **Umiliki:** Muamala lazima usainiwe na mmiliki wa plot
2. **Hali:** Plot lazima iwe katika hali ya UNASSIGNED au REVOKED
3. **Muundo:** OP_RETURN halali na alama ya POCX + anwani 2x za byte 20
4. **Upekee:** Ugawaji mmoja unaofanya kazi kwa plot kwa wakati

### Sheria za Kubatilisha

1. **Umiliki:** Muamala lazima usainiwe na mmiliki wa plot
2. **Uwepo:** Ugawaji lazima uwepo na usibatilishwe tayari
3. **Muundo:** OP_RETURN halali na alama ya XCOP + anwani ya byte 20

### Sheria za Uanzishaji

- **Uanzishaji wa ugawaji:** `assignment_height + nForgingAssignmentDelay`
- **Uanzishaji wa kubatilisha:** `revocation_height + nForgingRevocationDelay`
- **Ucheleweshaji:** Unaweza kusanidiwa kwa mtandao (k.m., bloku 30 = ~saa 1 na muda wa bloku wa dakika 2)

### Uthibitishaji wa Bloku

- Ugawaji/kubatilisha isiyo halali → bloku imekataliwa (kushindwa kwa makubaliano)
- Matokeo ya OP_RETURN yanatengwa moja kwa moja kutoka seti ya UTXO (tabia ya kawaida ya Bitcoin)
- Uchakataji wa ugawaji unafanyika kabla ya sasisho za UTXO katika ConnectBlock

## Hitimisho

Mfumo wa ugawaji wa kuunda wa PoCX kama ulivyotekelezwa unatoa:

- **Urahisi:** Miamala ya kawaida ya Bitcoin, hakuna UTXO maalum
- **Ufanisi wa Gharama:** Hakuna hitaji la vumbi, ada za muamala pekee
- **Usalama wa Reorg:** Data ya kina ya kutengua inarejesha hali sahihi
- **Sasisho za Atomiki:** Uthabiti wa hifadhidata kupitia makundi ya LevelDB
- **Historia Kamili:** Rekodi kamili ya ukaguzi ya ugawaji wote kwa wakati
- **Muundo Safi:** Marekebisho madogo ya Bitcoin Core, msimbo uliotengwa wa PoCX
- **Tayari kwa Uzalishaji:** Imetekelezwa kikamilifu, imejaribiwa, na inafanya kazi

### Ubora wa Utekelezaji

- **Mpangilio wa msimbo:** Bora - utenganisho wazi kati ya Bitcoin Core na PoCX
- **Kushughulikia makosa:** Uthibitishaji wa kina wa makubaliano
- **Nyaraka:** Maoni ya msimbo na muundo umeandikwa vizuri
- **Majaribio:** Utendaji wa msingi umejaribiwa, muungano umethibitishwa

### Maamuzi Muhimu ya Usanifu Yaliyothibitishwa

1. Mbinu ya OP_RETURN pekee (dhidi ya msingi wa UTXO)
2. Hifadhi tofauti ya hifadhidata (dhidi ya Coin extraData)
3. Ufuatiliaji kamili wa historia (dhidi ya sasa pekee)
4. Umiliki kwa sahihi (dhidi ya matumizi ya UTXO)
5. Ucheleweshaji wa uanzishaji (unazuia mashambulizi ya reorg)

Mfumo unafanikiwa kufikia malengo yote ya muundo na utekelezaji safi, unaoweza kudumishwa.

---

[← Iliyotangulia: Makubaliano na Uchimbaji](3-consensus-and-mining.md) | [Yaliyomo](index.md) | [Inayofuata: Usawazishaji wa Muda →](5-timing-security.md)

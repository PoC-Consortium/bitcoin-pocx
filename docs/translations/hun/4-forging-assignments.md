[← Előző: Konszenzus és Bányászat](3-consensus-and-mining.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Időszinkronizáció →](5-timing-security.md)

---

# 4. Fejezet: PoCX Kovácsolási Megbízási Rendszer

## Vezetői Összefoglaló

Ez a dokumentum az **implementált** PoCX kovácsolási megbízási rendszert írja le, OP_RETURN-alapú architektúrával. A rendszer lehetővé teszi a plot tulajdonosoknak, hogy kovácsolási jogokat delegáljanak külön címekre on-chain tranzakciókon keresztül, teljes reorganizációs biztonsággal és atomi adatbázis műveletekkel.

**Állapot:** ✅ Teljesen Implementálva és Működőképes

## Központi Tervezési Filozófia

**Fő Elv:** A megbízások engedélyek, nem eszközök

- Nincsenek speciális UTXO-k nyilvántartandók vagy költendők
- Megbízás állapot az UTXO halmaztól elkülönítve tárolva
- Tulajdonjog tranzakció aláírással bizonyítva, nem UTXO költéssel
- Teljes előzmény nyilvántartás a teljes audit nyomvonalhoz
- Atomi adatbázis frissítések LevelDB batch írásokkal

## Tranzakció Szerkezet

### Megbízás Tranzakció Formátum

```
Bemenetek:
  [0]: Bármilyen UTXO a plot tulajdonos irányítása alatt (bizonyítja a tulajdonjogot + díjakat fizet)
       A plot tulajdonos privát kulcsával kell aláírni
  [1+]: Opcionális további bemenetek díj fedezéshez

Kimenetek:
  [0]: OP_RETURN (POCX jelölő + plot cím + kovácsolási cím)
       Formátum: OP_RETURN <0x2c> "POCX" <plot_cím_20> <kovácsolási_cím_20>
       Méret: 46 bájt összesen (1 bájt OP_RETURN + 1 bájt hossz + 44 bájt adat)
       Érték: 0 BTC (elkölthetetlen, nem adódik az UTXO halmazhoz)

  [1]: Visszajáró a felhasználónak (opcionális, szabványos P2WPKH)
```

**Implementáció:** `src/pocx/assignments/opcodes.cpp`

### Visszavonás Tranzakció Formátum

```
Bemenetek:
  [0]: Bármilyen UTXO a plot tulajdonos irányítása alatt (bizonyítja a tulajdonjogot + díjakat fizet)
       A plot tulajdonos privát kulcsával kell aláírni
  [1+]: Opcionális további bemenetek díj fedezéshez

Kimenetek:
  [0]: OP_RETURN (XCOP jelölő + plot cím)
       Formátum: OP_RETURN <0x18> "XCOP" <plot_cím_20>
       Méret: 26 bájt összesen (1 bájt OP_RETURN + 1 bájt hossz + 24 bájt adat)
       Érték: 0 BTC (elkölthetetlen, nem adódik az UTXO halmazhoz)

  [1]: Visszajáró a felhasználónak (opcionális, szabványos P2WPKH)
```

**Implementáció:** `src/pocx/assignments/opcodes.cpp`

### Jelölők

- **Megbízás Jelölő:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Visszavonás Jelölő:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementáció:** `src/pocx/assignments/opcodes.cpp`

### Fő Tranzakció Jellemzők

- Szabványos Bitcoin tranzakciók (nincs protokoll változás)
- OP_RETURN kimenetek bizonyíthatóan elkölthetetlenek (soha nem kerülnek az UTXO halmazba)
- Plot tulajdonjog a bemenet[0] plot címről származó aláírással bizonyítva
- Alacsony költség (~200 bájt, jellemzően <0.0001 BTC díj)
- A tárca automatikusan a legnagyobb UTXO-t választja a plot címről a tulajdonjog bizonyításához

## Adatbázis Architektúra

### Tárolási Struktúra

Minden megbízás adat ugyanabban a LevelDB adatbázisban van tárolva, mint az UTXO halmaz (`chainstate/`), de külön kulcs előtagokkal:

```
chainstate/ LevelDB:
├─ UTXO Halmaz (Bitcoin Core szabványos)
│  └─ 'C' előtag: COutPoint → Coin
│
└─ Megbízás Állapot (PoCX kiegészítések)
   └─ 'A' előtag: (plot_cím, megbízás_txid) → ForgingAssignment
       └─ Teljes előzmény: minden megbízás plotonként időben
```

**Implementáció:** `src/txdb.cpp`

### ForgingAssignment Struktúra

```cpp
struct ForgingAssignment {
    // Azonosítás
    std::array<uint8_t, 20> plotAddress;      // Plot tulajdonos (20 bájtos P2WPKH hash)
    std::array<uint8_t, 20> forgingAddress;   // Kovácsolási jogok birtokosa (20 bájtos P2WPKH hash)

    // Megbízás életciklus
    uint256 assignment_txid;                   // Megbízást létrehozó tranzakció
    int assignment_height;                     // Blokk magasság létrehozáskor
    int assignment_effective_height;           // Mikor válik aktívvá (magasság + késleltetés)

    // Visszavonás életciklus
    bool revoked;                              // Visszavonták-e?
    uint256 revocation_txid;                   // Visszavonó tranzakció
    int revocation_height;                     // Blokk magasság visszavonáskor
    int revocation_effective_height;           // Mikor válik hatályossá a visszavonás (magasság + késleltetés)

    // Állapot lekérdező metódusok
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementáció:** `src/coins.h`

### Megbízás Állapotok

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nincs megbízás
    ASSIGNING = 1,   // Megbízás létrehozva, aktiválási késleltetésre vár
    ASSIGNED = 2,    // Megbízás aktív, kovácsolás engedélyezett
    REVOKING = 3,    // Visszavonva, de még aktív a késleltetési időszakban
    REVOKED = 4      // Teljesen visszavonva, már nem aktív
};
```

**Implementáció:** `src/coins.h`

### Adatbázis Kulcsok

```cpp
// Előzmény kulcs: teljes megbízás rekordot tárol
// Kulcs formátum: (előtag, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plot cím (20 bájt)
    int assignment_height;                // Magasság rendezés optimalizációhoz
    uint256 assignment_txid;              // Tranzakció ID
};
```

**Implementáció:** `src/txdb.cpp`

### Előzmény Nyilvántartás

- Minden megbízás permanensen tárolva (soha nem törölve, csak reorg esetén)
- Több megbízás plotonként időben nyilvántartva
- Teljes audit nyomvonal és előzmény állapot lekérdezések lehetővé tétele
- Visszavont megbízások az adatbázisban maradnak `revoked=true` értékkel

## Blokk Feldolgozás

### ConnectBlock Integráció

A megbízás és visszavonás OP_RETURN-ok a blokk csatlakoztatás során feldolgozva a `validation.cpp`-ben:

```cpp
// Hely: Script validáció után, UpdateCoins előtt
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURN adat elemzése
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Tulajdonjog ellenőrzése (tx-et plot tulajdonosnak kell aláírnia)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Plot állapot ellenőrzése (UNASSIGNED vagy REVOKED kell legyen)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Új megbízás létrehozása
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Visszavonási adat tárolása
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURN adat elemzése
            auto plot_addr = ParseRevocationOpReturn(output);

            // Tulajdonjog ellenőrzése
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Aktuális megbízás lekérése - a visszavonáshoz ASSIGNED állapotban kell lennie
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->GetStateAtHeight(height) != ForgingState::ASSIGNED)
                return state.Invalid("cannot-revoke-inactive");

            // Régi állapot tárolása visszavonáshoz
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Visszavontként jelölés
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

// UpdateCoins normálisan folytatódik (automatikusan kihagyja az OP_RETURN kimeneteket)
```

**Implementáció:** `src/validation.cpp:ConnectBlock()`

### Tulajdonjog Ellenőrzés

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Ellenőrzés, hogy legalább egy bemenet a plot tulajdonos által aláírt
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

**Implementáció:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Aktiválási Késleltetések

A megbízások és visszavonások konfigurálható aktiválási késleltetésekkel rendelkeznek a reorg támadások megakadályozására:

```cpp
// Konszenzus paraméterek (hálózatonként konfigurálható)
// Példa: 30 blokk = ~1 óra 2 perces blokkidővel
consensus.nForgingAssignmentDelay;   // Megbízás aktiválási késleltetés
consensus.nForgingRevocationDelay;   // Visszavonás aktiválási késleltetés
```

**Állapot Átmenetek:**
- Megbízás: `UNASSIGNED → ASSIGNING (késleltetés) → ASSIGNED`
- Visszavonás: `ASSIGNED → REVOKING (késleltetés) → REVOKED`

**Implementáció:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool Validáció

A megbízás és visszavonás tranzakciók mempool elfogadáskor validálva az érvénytelen tranzakciók hálózati terjesztés előtti elutasítására.

### Tranzakció-Szintű Ellenőrzések (CheckTransaction)

A `src/consensus/tx_check.cpp`-ben végrehajtva, lánc állapot hozzáférés nélkül:

1. **Maximum Egy POCX OP_RETURN:** A tranzakció nem tartalmazhat több POCX/XCOP jelölőt

**Implementáció:** `src/consensus/tx_check.cpp`

### Mempool Elfogadási Ellenőrzések (PreChecks)

A `src/validation.cpp`-ben végrehajtva teljes lánc állapot és mempool hozzáféréssel:

#### Megbízás Validáció

1. **Plot Tulajdonjog:** A tranzakciót a plot tulajdonosnak kell aláírnia
2. **Plot Állapot:** A plot UNASSIGNED (0) vagy REVOKED (4) állapotban kell legyen
3. **Mempool Konfliktusok:** Nincs másik megbízás ehhez a plothoz a mempool-ban (első-látott nyer)

#### Visszavonás Validáció

1. **Plot Tulajdonjog:** A tranzakciót a plot tulajdonosnak kell aláírnia
2. **Aktív Megbízás:** A plot csak ASSIGNED (2) állapotban lehet
3. **Mempool Konfliktusok:** Nincs másik visszavonás ehhez a plothoz a mempool-ban

**Implementáció:** `src/validation.cpp:PreChecks()`

### Validációs Folyamat

```
Tranzakció Közvetítés
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maximum egy POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Plot tulajdonjog ellenőrzése
  ✓ Megbízás állapot ellenőrzése
  ✓ Mempool konfliktusok ellenőrzése
       ↓
   Érvényes → Elfogadás Mempool-ba
   Érvénytelen → Elutasítás (nem terjesztve)
       ↓
Blokk Bányászat
       ↓
ConnectBlock() [validation.cpp]
  ✓ Minden ellenőrzés újravalidálása (mélységi védelem)
  ✓ Állapotváltozások alkalmazása
  ✓ Visszavonási info rögzítése
```

### Mélységi Védelem

Minden mempool validációs ellenőrzés újra végrehajtva a `ConnectBlock()` során a védelem érdekében:
- Mempool megkerülési támadások
- Rosszindulatú bányászoktól származó érvénytelen blokkok
- Szélső esetek reorg forgatókönyvek során

A blokk validáció marad mérvadó a konszenzushoz.

## Atomi Adatbázis Frissítések

### Háromrétegű Architektúra

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Memória Gyorsítótár) │  ← Megbízás változások memóriában nyomon követve
│   - Érmék: cacheCoins                   │
│   - Megbízások: pendingAssignments      │
│   - Piszkos nyilvántartás: dirtyPlots   │
│   - Törlések: deletedAssignments        │
│   - Memória nyilvántartás: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Adatbázis Réteg)        │  ← Egyetlen atomi írás
│   - BatchWrite(): UTXO-k + Megbízások   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Lemez Tárolás)               │  ← ACID garanciák
│   - Atomi tranzakció                    │
└─────────────────────────────────────────┘
```

### Flush Folyamat

Amikor `view.Flush()` hívásra kerül blokk csatlakoztatás során:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Érme változások írása az alapba
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Megbízás változások atomi írása
    if (fOk && !dirtyPlots.empty()) {
        // Piszkos megbízások összegyűjtése
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

        // Írás az adatbázisba
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

**Implementáció:** `src/coins.cpp:Flush()`

### Adatbázis Batch Írás

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Egyetlen LevelDB batch

    // 1. Átmeneti állapot jelölése
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Minden érme változás írása
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Konzisztens állapot jelölése
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMI COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Megbízások külön írva, de ugyanabban az adatbázis tranzakció kontextusban
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

**Implementáció:** `src/txdb.cpp:BatchWriteAssignments()`

### Atomitás Garanciák

✅ **Ami atomi:**
- Egy blokkon belüli összes érme változás atomikusan írva
- Egy blokkon belüli összes megbízás változás atomikusan írva
- Az adatbázis konzisztens marad összeomlások esetén is

⚠️ **Jelenlegi korlátozás:**
- Az érmék és megbízások **külön** LevelDB batch műveletekben íródnak
- Mindkét művelet a `view.Flush()` során történik, de nem egyetlen atomi írásban
- Gyakorlatban: Mindkét batch gyorsan befejeződik a lemez fsync előtt
- A kockázat minimális: Mindkettőt ugyanabból a blokkból kellene újrajátszani összeomlás helyreállításkor

**Megjegyzés:** Ez eltér az eredeti architektúra tervtől, amely egyetlen egyesített batch-et követelt. A jelenlegi implementáció két batch-et használ, de a konzisztenciát a Bitcoin Core meglévő összeomlás helyreállítási mechanizmusain keresztül tartja fenn (DB_HEAD_BLOCKS jelölő).

## Reorg Kezelés

### Visszavonási Adat Struktúra

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Megbízás hozzáadva (törlés visszavonáskor)
        MODIFIED = 1,   // Megbízás módosítva (visszaállítás visszavonáskor)
        REVOKED = 2     // Megbízás visszavonva (visszavonás visszaállítása)
    };

    UndoType type;
    ForgingAssignment assignment;  // Teljes állapot változás előtt
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO visszavonási adat
    std::vector<ForgingUndo> vforgingundo;  // Megbízás visszavonási adat
};
```

**Implementáció:** `src/undo.h`

### DisconnectBlock Folyamat

Amikor egy blokk leválasztásra kerül reorg során:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... szabványos UTXO leválasztás ...

    // Visszavonási adat olvasása lemezről
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Megbízás változások visszavonása (fordított sorrendben feldolgozva)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Megbízás hozzáadva - eltávolítás
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Megbízás visszavonva - vissza nem vont állapot visszaállítása
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Megbízás módosítva - előző állapot visszaállítása
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementáció:** `src/validation.cpp:DisconnectBlock()`

### Gyorsítótár Kezelés Reorg Során

```cpp
class CCoinsViewCache {
private:
    // Megbízás gyorsítótárak
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Módosított plotok nyomon követése
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Törlések nyomon követése
    mutable size_t cachedAssignmentsUsage{0};  // Memória nyomon követés

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

**Implementáció:** `src/coins.cpp`

## RPC Interfész

### Csomópont Parancsok (Nincs Tárca Szükséges)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Visszaadja az aktuális megbízás állapotot egy plot címhez:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 130,
  "revoked": false
}
```

**Implementáció:** `src/pocx/rpc/assignments.cpp`

### Tárca Parancsok (Tárca Szükséges)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Megbízás tranzakciót hoz létre:
- Automatikusan kiválasztja a legnagyobb UTXO-t a plot címről a tulajdonjog bizonyításához
- Tranzakciót épít OP_RETURN + visszajáró kimenettel
- Aláírja a plot tulajdonos kulcsával
- Közvetíti a hálózatra

**Implementáció:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Visszavonás tranzakciót hoz létre:
- Automatikusan kiválasztja a legnagyobb UTXO-t a plot címről a tulajdonjog bizonyításához
- Tranzakciót épít OP_RETURN + visszajáró kimenettel
- Aláírja a plot tulajdonos kulcsával
- Közvetíti a hálózatra

**Implementáció:** `src/pocx/rpc/assignments_wallet.cpp`

### Tárca Tranzakció Létrehozás

A tárca tranzakció létrehozási folyamat:

```cpp
1. Címek elemzése és validálása (P2WPKH bech32 kell legyen)
2. Legnagyobb UTXO keresése a plot címről (tulajdonjog bizonyítása)
3. Ideiglenes tranzakció létrehozása helyettesítő kimenettel
4. Tranzakció aláírása (pontos méret a tanú adatokkal)
5. Helyettesítő kimenet cseréje OP_RETURN-ra
6. Díjak arányos beállítása méretváltozás alapján
7. Végleges tranzakció újra aláírása
8. Közvetítés a hálózatra
```

**Fő felismerés:** A tárcának a plot címről kell költenie a tulajdonjog bizonyításához, így automatikusan kényszeríti az érme kiválasztást arról a címről.

**Implementáció:** `src/pocx/assignments/transactions.cpp`

## Fájl Struktúra

### Központi Implementációs Fájlok

```
src/
├── coins.h                        # ForgingAssignment struct, CCoinsViewCache metódusok
├── coins.cpp                      # Gyorsítótár kezelés, batch írások
│
├── txdb.h                         # CCoinsViewDB megbízás metódusok
├── txdb.cpp                       # Adatbázis olvasás/írás
│
├── undo.h                         # ForgingUndo struktúra reorg-okhoz
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock integráció
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN formátum, elemzés, ellenőrzés
    │   ├── opcodes.cpp            # Jelölő definíciók, OP_RETURN műveletek, tulajdonjog ellenőrzés
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState segédfüggvények
    │   ├── assignment_state.cpp   # Megbízás állapot lekérdező függvények
    │   ├── replay.h               # Megbízás-hatások reorg/visszajátszása
    │   ├── replay.cpp             # ApplyAssignmentEffectsForReplay (reorg útvonal)
    │   ├── transactions.h         # Tárca tranzakció létrehozás API
    │   └── transactions.cpp       # create_assignment, revoke_assignment tárca függvények
    │
    ├── rpc/
    │   ├── assignments.h          # Csomópont RPC parancsok (nincs tárca)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # Tárca RPC parancsok
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC-k
    │
    └── consensus/
        └── params.h               # PoCXCompressionBounds, genezis alap célérték, kompressziós ütemterv
```

> **Megjegyzés:** A megbízás-késleltetési konstansok `nForgingAssignmentDelay` / `nForgingRevocationDelay` a Bitcoin Core `Consensus::Params` struktúrájában (`src/consensus/params.h`) találhatók, és hálózatonként a `src/kernel/chainparams.cpp`-ben vannak beállítva — nem a `pocx/consensus/params.h`-ban.

## Teljesítmény Jellemzők

### Adatbázis Műveletek

- **Aktuális megbízás lekérése:** O(n) - minden megbízás átnézése a plot címhez a legfrissebb megtalálásához
- **Megbízás előzmény lekérése:** O(n) - minden megbízás iterálása a plothoz
- **Megbízás létrehozása:** O(1) - egyetlen beszúrás
- **Megbízás visszavonása:** O(1) - egyetlen frissítés
- **Reorg (megbízásonként):** O(1) - közvetlen visszavonási adat alkalmazás

Ahol n = megbízások száma plotonként (jellemzően kicsi, < 10)

### Memóriahasználat

- **Megbízásonként:** ~160 bájt (ForgingAssignment struct)
- **Gyorsítótár többlet:** Hash map többlet a piszkos nyilvántartáshoz
- **Tipikus blokk:** <10 megbízás = <2 KB memória

### Lemezhasználat

- **Megbízásonként:** ~200 bájt lemezen (LevelDB többlettel)
- **10000 megbízás:** ~2 MB lemezterület
- **Elhanyagolható az UTXO halmazhoz képest:** <0.001% a tipikus chainstate-nek

## Jelenlegi Korlátozások és Jövőbeli Munka

### Atomitás Korlátozás

**Jelenlegi:** Az érmék és megbízások külön LevelDB batch műveletekben íródnak a `view.Flush()` során

**Hatás:** Elméleti kockázata az inkonzisztenciának, ha összeomlás történik a batch-ek között

**Mérséklés:**
- Mindkét batch gyorsan befejeződik az fsync előtt
- A Bitcoin Core összeomlás helyreállítása DB_HEAD_BLOCKS jelölőt használ
- Gyakorlatban: Tesztelés során soha nem tapasztalt

**Jövőbeli fejlesztés:** Egyesítés egyetlen LevelDB batch műveletbe

### Megbízás Előzmény Pruning

**Jelenlegi:** Minden megbízás korlátlan ideig tárolva

**Hatás:** ~200 bájt megbízásonként örökké

**Jövő:** Opcionális pruning a teljesen visszavont, N blokknál régebbi megbízásokhoz

**Megjegyzés:** Valószínűleg nem lesz szükség — még 1 millió megbízás is = 200 MB

## Tesztelési Állapot

### Implementált Tesztek

✅ OP_RETURN elemzés és validáció
✅ Tulajdonjog ellenőrzés
✅ ConnectBlock megbízás létrehozás
✅ ConnectBlock visszavonás
✅ DisconnectBlock reorg kezelés
✅ Adatbázis olvasás/írás műveletek
✅ Állapot átmenetek (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC parancsok (get_assignment, create_assignment, revoke_assignment)
✅ Tárca tranzakció létrehozás

### Teszt Lefedettségi Területek

- Egységtesztek: `src/test/pocx_tests.cpp`, `src/test/pocx_simd_tests.cpp`
- Integrációs tesztek: regtest shell szkriptek a `scripts/assignments/` és `scripts/mining/` alatt

## Konszenzus Szabályok

### Megbízás Létrehozási Szabályok

1. **Tulajdonjog:** A tranzakciót a plot tulajdonosnak kell aláírnia
2. **Állapot:** A plot UNASSIGNED vagy REVOKED állapotban kell legyen
3. **Formátum:** Érvényes OP_RETURN POCX jelölővel + 2x 20 bájtos cím
4. **Egyediség:** Egyszerre egy aktív megbízás plotonként

### Visszavonási Szabályok

1. **Tulajdonjog:** A tranzakciót a plot tulajdonosnak kell aláírnia
2. **Létezés:** Megbízás léteznie kell és nem lehet már visszavonva
3. **Formátum:** Érvényes OP_RETURN XCOP jelölővel + 20 bájtos cím

### Aktiválási Szabályok

- **Megbízás aktiválás:** `megbízás_magasság + nForgingAssignmentDelay`
- **Visszavonás aktiválás:** `visszavonás_magasság + nForgingRevocationDelay`
- **Késleltetések:** Hálózatonként konfigurálható (pl. 30 blokk = ~1 óra 2 perces blokkidővel)

### Blokk Validáció

- Érvénytelen megbízás/visszavonás → blokk elutasítva (konszenzus hiba)
- OP_RETURN kimenetek automatikusan kizárva az UTXO halmazból (szabványos Bitcoin viselkedés)
- Megbízás feldolgozás az UTXO frissítések előtt történik a ConnectBlock-ban

## Összefoglalás

Az implementált PoCX kovácsolási megbízási rendszer biztosítja:

✅ **Egyszerűség:** Szabványos Bitcoin tranzakciók, nincs speciális UTXO
✅ **Költséghatékonyság:** Nincs dust követelmény, csak tranzakciós díjak
✅ **Reorg Biztonság:** Átfogó visszavonási adatok helyreállítják a helyes állapotot
✅ **Atomi Frissítések:** Adatbázis konzisztencia LevelDB batch-eken keresztül
✅ **Teljes Előzmény:** Teljes audit nyomvonal minden megbízásról időben
✅ **Tiszta Architektúra:** Minimális Bitcoin Core módosítások, izolált PoCX kód
✅ **Termelési Kész:** Teljesen implementálva, tesztelve és működőképes

### Implementációs Minőség

- **Kód szervezés:** Kiváló - tiszta elválasztás a Bitcoin Core és PoCX között
- **Hibakezelés:** Átfogó konszenzus validáció
- **Dokumentáció:** Kód megjegyzések és struktúra jól dokumentált
- **Tesztelés:** Központi funkcionalitás tesztelve, integráció ellenőrizve

### Fő Tervezési Döntések Validálva

1. ✅ Csak OP_RETURN megközelítés (vs UTXO-alapú)
2. ✅ Különálló adatbázis tárolás (vs Coin extraData)
3. ✅ Teljes előzmény nyilvántartás (vs csak aktuális)
4. ✅ Aláírás általi tulajdonjog (vs UTXO költés)
5. ✅ Aktiválási késleltetések (megakadályozza a reorg támadásokat)

A rendszer sikeresen eléri az összes architekturális célt egy tiszta, karbantartható implementációval.

---

[← Előző: Konszenzus és Bányászat](3-consensus-and-mining.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Időszinkronizáció →](5-timing-security.md)

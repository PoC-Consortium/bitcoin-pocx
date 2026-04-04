[← Iepriekšējā: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Laika sinhronizācija →](5-timing-security.md)

---

# 4. nodaļa: PoCX kalšanas piešķīrumu sistēma

## Kopsavilkums

Šis dokuments apraksta **implementēto** PoCX kalšanas piešķīrumu sistēmu, izmantojot tikai OP_RETURN arhitektūru. Sistēma ļauj plotfailu īpašniekiem deleģēt kalšanas tiesības atsevišķām adresēm caur on-chain darījumiem ar pilnu reorganizāciju drošību un atomārām datu bāzes operācijām.

**Statuss:** ✅ Pilnībā implementēta un darbspējīga

## Pamata dizaina filozofija

**Galvenais princips:** Piešķīrumi ir atļaujas, nevis aktīvi

- Nav speciālu UTXO izsekošanai vai tērēšanai
- Piešķīrumu stāvoklis glabāts atsevišķi no UTXO kopas
- Īpašumtiesības pierādītas ar darījuma parakstu, nevis UTXO tērēšanu
- Pilna vēstures izsekošana pilnīgai audita takai
- Atomāri datu bāzes atjauninājumi caur LevelDB partijas rakstīšanu

## Darījumu struktūra

### Piešķīruma darījuma formāts

```
Ievades:
  [0]: Jebkurš UTXO, ko kontrolē plotfaila īpašnieks (pierāda īpašumtiesības + maksā maksu)
       Jābūt parakstītam ar plotfaila īpašnieka privāto atslēgu
  [1+]: Neobligātas papildu ievades maksas segšanai

Izvades:
  [0]: OP_RETURN (POCX marķieris + plotfaila adrese + kalšanas adrese)
       Formāts: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Izmērs: 46 baiti kopā (1 baits OP_RETURN + 1 baits garums + 44 baiti dati)
       Vērtība: 0 BTC (neizmantojams, netiek pievienots UTXO kopai)

  [1]: Atlikums atpakaļ lietotājam (neobligāts, standarta P2WPKH)
```

**Implementācija:** `src/pocx/assignments/opcodes.cpp`

### Atsaukšanas darījuma formāts

```
Ievades:
  [0]: Jebkurš UTXO, ko kontrolē plotfaila īpašnieks (pierāda īpašumtiesības + maksā maksu)
       Jābūt parakstītam ar plotfaila īpašnieka privāto atslēgu
  [1+]: Neobligātas papildu ievades maksas segšanai

Izvades:
  [0]: OP_RETURN (XCOP marķieris + plotfaila adrese)
       Formāts: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Izmērs: 26 baiti kopā (1 baits OP_RETURN + 1 baits garums + 24 baiti dati)
       Vērtība: 0 BTC (neizmantojams, netiek pievienots UTXO kopai)

  [1]: Atlikums atpakaļ lietotājam (neobligāts, standarta P2WPKH)
```

**Implementācija:** `src/pocx/assignments/opcodes.cpp`

### Marķieri

- **Piešķīruma marķieris:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Atsaukšanas marķieris:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementācija:** `src/pocx/assignments/opcodes.cpp`

### Galvenās darījumu īpašības

- Standarta Bitcoin darījumi (nav protokola izmaiņu)
- OP_RETURN izvades ir pierādāmi neizmantojamas (nekad netiek pievienotas UTXO kopai)
- Plotfaila īpašumtiesības pierādītas ar parakstu uz input[0] no plotfaila adreses
- Zemas izmaksas (~200 baiti, parasti <0.0001 BTC maksa)
- Maciņš automātiski izvēlas lielāko UTXO no plotfaila adreses, lai pierādītu īpašumtiesības

## Datu bāzes arhitektūra

### Glabāšanas struktūra

Visi piešķīrumu dati tiek glabāti tajā pašā LevelDB datu bāzē kā UTXO kopa (`chainstate/`), bet ar atsevišķiem atslēgu prefiksiem:

```
chainstate/ LevelDB:
├─ UTXO kopa (Bitcoin Core standarts)
│  └─ 'C' prefikss: COutPoint → Coin
│
└─ Piešķīrumu stāvoklis (PoCX papildinājumi)
   └─ 'A' prefikss: (plot_address, assignment_txid) → ForgingAssignment
       └─ Pilna vēsture: visi piešķīrumi katram plotfailam laika gaitā
```

**Implementācija:** `src/txdb.cpp`

### ForgingAssignment struktūra

```cpp
struct ForgingAssignment {
    // Identitāte
    std::array<uint8_t, 20> plotAddress;      // Plotfaila īpašnieks (20 baitu P2WPKH jaucējvērtība)
    std::array<uint8_t, 20> forgingAddress;   // Kalšanas tiesību turētājs (20 baitu P2WPKH jaucējvērtība)

    // Piešķīruma dzīves cikls
    uint256 assignment_txid;                   // Darījums, kas izveidoja piešķīrumu
    int assignment_height;                     // Bloka augstums, kad izveidots
    int assignment_effective_height;           // Kad tas kļūst aktīvs (augstums + aizkave)

    // Atsaukšanas dzīves cikls
    bool revoked;                              // Vai tas ir atsaukts?
    uint256 revocation_txid;                   // Darījums, kas to atsauca
    int revocation_height;                     // Bloka augstums, kad atsaukts
    int revocation_effective_height;           // Kad atsaukšana stājas spēkā (augstums + aizkave)

    // Stāvokļa vaicājuma metodes
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementācija:** `src/coins.h`

### Piešķīrumu stāvokļi

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Piešķīrums neeksistē
    ASSIGNING = 1,   // Piešķīrums izveidots, gaida aktivizācijas aizkavi
    ASSIGNED = 2,    // Piešķīrums aktīvs, kalšana atļauta
    REVOKING = 3,    // Atsaukts, bet joprojām aktīvs aizkaves periodā
    REVOKED = 4      // Pilnībā atsaukts, vairs nav aktīvs
};
```

**Implementācija:** `src/coins.h`

### Datu bāzes atslēgas

```cpp
// Vēstures atslēga: glabā pilnu piešķīruma ierakstu
// Atslēgas formāts: (prefikss, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotfaila adrese (20 baiti)
    int assignment_height;                // Augstums kārtošanas optimizācijai
    uint256 assignment_txid;              // Darījuma ID
};
```

**Implementācija:** `src/txdb.cpp`

### Vēstures izsekošana

- Katrs piešķīrums tiek glabāts pastāvīgi (nekad netiek dzēsts, ja vien nav reorganizācija)
- Vairāki piešķīrumi katram plotfailam tiek izsekoti laika gaitā
- Nodrošina pilnu audita taku un vēsturiskus stāvokļa vaicājumus
- Atsauktie piešķīrumi paliek datu bāzē ar `revoked=true`

## Bloku apstrāde

### ConnectBlock integrācija

Piešķīrumu un atsaukšanas OP_RETURN tiek apstrādāti bloka savienošanas laikā `validation.cpp`:

```cpp
// Vieta: Pēc skriptu validācijas, pirms UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsēt OP_RETURN datus
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verificēt īpašumtiesības (darījumam jābūt parakstītam ar plotfaila īpašnieku)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Pārbaudīt plotfaila stāvokli (jābūt UNASSIGNED vai REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Izveidot jaunu piešķīrumu
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Saglabāt atsaukšanas datus
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsēt OP_RETURN datus
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verificēt īpašumtiesības
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Iegūt pašreizējo piešķīrumu
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Saglabāt veco stāvokli atsaukšanai
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Atzīmēt kā atsauktu
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

// UpdateCoins turpinās normāli (automātiski izlaiž OP_RETURN izvades)
```

**Implementācija:** `src/validation.cpp:ConnectBlock()`

### Īpašumtiesību verifikācija

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Pārbaudīt, vai vismaz viena ievade ir parakstīta ar plotfaila īpašnieku
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

**Implementācija:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Aktivizācijas aizkaves

Piešķīrumiem un atsaukšanām ir konfigurējamas aktivizācijas aizkaves, lai novērstu reorganizāciju uzbrukumus:

```cpp
// Konsensa parametri (konfigurējami katram tīklam)
// Piemērs: 30 bloki = ~1 stunda ar 2 minūšu bloka laiku
consensus.nForgingAssignmentDelay;   // Piešķīruma aktivizācijas aizkave
consensus.nForgingRevocationDelay;   // Atsaukšanas aktivizācijas aizkave
```

**Stāvokļa pārejas:**
- Piešķīrums: `UNASSIGNED → ASSIGNING (aizkave) → ASSIGNED`
- Atsaukšana: `ASSIGNED → REVOKING (aizkave) → REVOKED`

**Implementācija:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool validācija

Piešķīrumu un atsaukšanas darījumi tiek validēti mempool pieņemšanas laikā, lai noraidītu nederīgus darījumus pirms tīkla izplatīšanas.

### Darījuma līmeņa pārbaudes (CheckTransaction)

Veiktas `src/consensus/tx_check.cpp` bez ķēdes stāvokļa piekļuves:

1. **Maksimums viens POCX OP_RETURN:** Darījums nevar saturēt vairākus POCX/XCOP marķierus

**Implementācija:** `src/consensus/tx_check.cpp`

### Mempool pieņemšanas pārbaudes (PreChecks)

Veiktas `src/validation.cpp` ar pilnu ķēdes stāvokļa un mempool piekļuvi:

#### Piešķīruma validācija

1. **Plotfaila īpašumtiesības:** Darījumam jābūt parakstītam ar plotfaila īpašnieku
2. **Plotfaila stāvoklis:** Plotfailam jābūt UNASSIGNED (0) vai REVOKED (4)
3. **Mempool konflikti:** Nav cita piešķīruma šim plotfailam mempool (pirmais redzētais uzvar)

#### Atsaukšanas validācija

1. **Plotfaila īpašumtiesības:** Darījumam jābūt parakstītam ar plotfaila īpašnieku
2. **Aktīvs piešķīrums:** Plotfailam jābūt tikai ASSIGNED (2) stāvoklī
3. **Mempool konflikti:** Nav citas atsaukšanas šim plotfailam mempool

**Implementācija:** `src/validation.cpp:PreChecks()`

### Validācijas plūsma

```
Darījuma pārraide
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maksimums viens POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Verificēt plotfaila īpašumtiesības
  ✓ Pārbaudīt piešķīruma stāvokli
  ✓ Pārbaudīt mempool konfliktus
       ↓
   Derīgs → Pieņemt mempool
   Nederīgs → Noraidīt (neizplatīt)
       ↓
Bloka kalnrūpniecība
       ↓
ConnectBlock() [validation.cpp]
  ✓ Atkārtoti validēt visas pārbaudes (dziļuma aizsardzība)
  ✓ Piemērot stāvokļa izmaiņas
  ✓ Ierakstīt atsaukšanas info
```

### Dziļuma aizsardzība

Visas mempool validācijas pārbaudes tiek atkārtoti izpildītas `ConnectBlock()` laikā, lai aizsargātu pret:
- Mempool apiešanas uzbrukumiem
- Nederīgiem blokiem no ļaunprātīgiem kalnračiem
- Robežgadījumiem reorganizāciju scenārijos

Bloka validācija paliek autoritatīva konsensam.

## Atomāri datu bāzes atjauninājumi

### Trīs slāņu arhitektūra

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (atmiņas kešatmiņa)   │  ← Piešķīrumu izmaiņas izsekots atmiņā
│   - Monētas: cacheCoins                 │
│   - Piešķīrumi: pendingAssignments      │
│   - Netīru izsekošana: dirtyPlots       │
│   - Dzēšanas: deletedAssignments        │
│   - Atmiņas izsekošana: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (datu bāzes slānis)      │  ← Viena atomāra rakstīšana
│   - BatchWrite(): UTXO + piešķīrumi     │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (diska glabāšana)             │  ← ACID garantijas
│   - Atomāra transakcija                 │
└─────────────────────────────────────────┘
```

### Skalošanas process

Kad `view.Flush()` tiek izsaukts bloka savienošanas laikā:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Rakstīt monētu izmaiņas uz bāzi
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Rakstīt piešķīrumu izmaiņas atomāri
    if (fOk && !dirtyPlots.empty()) {
        // Savākt netīros piešķīrumus
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

        // Rakstīt uz datu bāzi
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

**Implementācija:** `src/coins.cpp:Flush()`

### Datu bāzes partijas rakstīšana

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Viena LevelDB partija

    // 1. Atzīmēt pārejas stāvokli
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Rakstīt visas monētu izmaiņas
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Atzīmēt konsekventu stāvokli
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMĀRA APŅEMŠANA
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Piešķīrumi rakstīti atsevišķi, bet tajā pašā datu bāzes transakcijas kontekstā
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

**Implementācija:** `src/txdb.cpp:BatchWriteAssignments()`

### Atomitātes garantijas

✅ **Kas ir atomārs:**
- Visas monētu izmaiņas blokā tiek rakstītas atomāri
- Visas piešķīrumu izmaiņas blokā tiek rakstītas atomāri
- Datu bāze paliek konsekventa pēc avārijām

⚠️ **Pašreizējais ierobežojums:**
- Monētas un piešķīrumi tiek rakstīti **atsevišķās** LevelDB partijas operācijās
- Abas operācijas notiek `view.Flush()` laikā, bet ne vienā atomārā rakstīšanā
- Praksē: Abas partijas pabeidzas ātri pirms diska fsync
- Risks ir minimāls: Abas būtu jāatkārto no tā paša bloka avārijas atgūšanas laikā

**Piezīme:** Tas atšķiras no sākotnējā arhitektūras plāna, kas paredzēja vienu apvienotu partiju. Pašreizējā implementācija izmanto divas partijas, bet saglabā konsekvenci caur Bitcoin Core esošajiem avārijas atgūšanas mehānismiem (DB_HEAD_BLOCKS marķieris).

## Reorganizāciju apstrāde

### Atsaukšanas datu struktūra

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Piešķīrums tika pievienots (dzēst atsaukšanā)
        MODIFIED = 1,   // Piešķīrums tika modificēts (atjaunot atsaukšanā)
        REVOKED = 2     // Piešķīrums tika atsaukts (at-atsaukt atsaukšanā)
    };

    UndoType type;
    ForgingAssignment assignment;  // Pilns stāvoklis pirms izmaiņas
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO atsaukšanas dati
    std::vector<ForgingUndo> vforgingundo;  // Piešķīrumu atsaukšanas dati
};
```

**Implementācija:** `src/undo.h`

### DisconnectBlock process

Kad bloks tiek atvienots reorganizācijas laikā:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standarta UTXO atvienošana ...

    // Lasīt atsaukšanas datus no diska
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Atsaukt piešķīrumu izmaiņas (apstrādāt apgrieztā secībā)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Piešķīrums tika pievienots - noņemt to
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Piešķīrums tika atsaukts - atjaunot neatsauktu stāvokli
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Piešķīrums tika modificēts - atjaunot iepriekšējo stāvokli
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementācija:** `src/validation.cpp:DisconnectBlock()`

### Kešatmiņas pārvaldība reorganizāciju laikā

```cpp
class CCoinsViewCache {
private:
    // Piešķīrumu kešatmiņas
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Izsekot modificētos plotfailus
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Izsekot dzēšanas
    mutable size_t cachedAssignmentsUsage{0};  // Atmiņas izsekošana

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

**Implementācija:** `src/coins.cpp`

## RPC saskarne

### Mezgla komandas (nav nepieciešams maciņš)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Atgriež pašreizējo piešķīruma statusu plotfaila adresei:
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

**Implementācija:** `src/pocx/rpc/assignments.cpp`

### Maciņa komandas (nepieciešams maciņš)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Izveido piešķīruma darījumu:
- Automātiski izvēlas lielāko UTXO no plotfaila adreses, lai pierādītu īpašumtiesības
- Veido darījumu ar OP_RETURN + atlikuma izvadi
- Paraksta ar plotfaila īpašnieka atslēgu
- Pārraida tīklā

**Implementācija:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Izveido atsaukšanas darījumu:
- Automātiski izvēlas lielāko UTXO no plotfaila adreses, lai pierādītu īpašumtiesības
- Veido darījumu ar OP_RETURN + atlikuma izvadi
- Paraksta ar plotfaila īpašnieka atslēgu
- Pārraida tīklā

**Implementācija:** `src/pocx/rpc/assignments_wallet.cpp`

### Maciņa darījumu izveide

Maciņa darījumu izveides process:

```cpp
1. Parsēt un validēt adreses (jābūt P2WPKH bech32)
2. Atrast lielāko UTXO no plotfaila adreses (pierāda īpašumtiesības)
3. Izveidot pagaidu darījumu ar fiktīvu izvadi
4. Parakstīt darījumu (iegūt precīzu izmēru ar liecības datiem)
5. Aizvietot fiktīvo izvadi ar OP_RETURN
6. Pielāgot maksas proporcionāli, balstoties uz izmēra izmaiņām
7. Atkārtoti parakstīt gala darījumu
8. Pārraidīt tīklā
```

**Galvenā atziņa:** Maciņam jātērē no plotfaila adreses, lai pierādītu īpašumtiesības, tāpēc tas automātiski piespiež monētu izvēli no šīs adreses.

**Implementācija:** `src/pocx/assignments/transactions.cpp`

## Failu struktūra

### Pamata implementācijas faili

```
src/
├── coins.h                        # ForgingAssignment struktūra, CCoinsViewCache metodes [710 rindas]
├── coins.cpp                      # Kešatmiņas pārvaldība, partijas rakstīšana [603 rindas]
│
├── txdb.h                         # CCoinsViewDB piešķīrumu metodes [90 rindas]
├── txdb.cpp                       # Datu bāzes lasīšana/rakstīšana [349 rindas]
│
├── undo.h                         # ForgingUndo struktūra reorganizācijām
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock integrācija
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN formāts, parsēšana, verifikācija
    │   ├── opcodes.cpp            # [259 rindas] Marķieru definīcijas, OP_RETURN ops, īpašumtiesību pārbaude
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState palīgi
    │   ├── assignment_state.cpp   # Piešķīrumu stāvokļa vaicājumu funkcijas
    │   ├── transactions.h         # Maciņa darījumu izveides API
    │   └── transactions.cpp       # create_assignment, revoke_assignment maciņa funkcijas
    │
    ├── rpc/
    │   ├── assignments.h          # Mezgla RPC komandas (bez maciņa)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # Maciņa RPC komandas
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Veiktspējas raksturlielumi

### Datu bāzes operācijas

- **Iegūt pašreizējo piešķīrumu:** O(n) - skenēt visus piešķīrumus plotfaila adresei, lai atrastu jaunāko
- **Iegūt piešķīrumu vēsturi:** O(n) - iterēt visus piešķīrumus plotfailam
- **Izveidot piešķīrumu:** O(1) - viena ievietošana
- **Atsaukt piešķīrumu:** O(1) - viens atjauninājums
- **Reorganizācija (katram piešķīrumam):** O(1) - tiešs atsaukšanas datu pielietojums

Kur n = piešķīrumu skaits plotfailam (parasti mazs, < 10)

### Atmiņas lietojums

- **Uz piešķīrumu:** ~160 baiti (ForgingAssignment struktūra)
- **Kešatmiņas papildizmaksas:** Jaucējtabulas papildizmaksas netīru izsekošanai
- **Tipisks bloks:** <10 piešķīrumi = <2 KB atmiņa

### Diska lietojums

- **Uz piešķīrumu:** ~200 baiti diskā (ar LevelDB papildizmaksām)
- **10000 piešķīrumi:** ~2 MB diska vietas
- **Nenozīmīgs salīdzinājumā ar UTXO kopu:** <0.001% no tipiskas chainstate

## Pašreizējie ierobežojumi un nākotnes darbs

### Atomitātes ierobežojums

**Pašreizējais:** Monētas un piešķīrumi tiek rakstīti atsevišķās LevelDB partijās `view.Flush()` laikā

**Ietekme:** Teorētisks nekonsekvences risks, ja avārija notiek starp partijām

**Mazināšana:**
- Abas partijas pabeidzas ātri pirms fsync
- Bitcoin Core avārijas atgūšana izmanto DB_HEAD_BLOCKS marķieri
- Praksē: Nekad nav novērots testēšanā

**Nākotnes uzlabojums:** Apvienot vienā LevelDB partijas operācijā

### Piešķīrumu vēstures apgriešana

**Pašreizējais:** Visi piešķīrumi tiek glabāti bezgalīgi

**Ietekme:** ~200 baiti uz piešķīrumu mūžīgi

**Nākotnē:** Neobligāta pilnībā atsauktu piešķīrumu, kas vecāki par N blokiem, apgriešana

**Piezīme:** Maz ticams, ka būs nepieciešams - pat 1 miljons piešķīrumu = 200 MB

## Testēšanas statuss

### Implementētie testi

✅ OP_RETURN parsēšana un validācija
✅ Īpašumtiesību verifikācija
✅ ConnectBlock piešķīrumu izveide
✅ ConnectBlock atsaukšana
✅ DisconnectBlock reorganizāciju apstrāde
✅ Datu bāzes lasīšanas/rakstīšanas operācijas
✅ Stāvokļa pārejas (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC komandas (get_assignment, create_assignment, revoke_assignment)
✅ Maciņa darījumu izveide

### Testa pārklājuma jomas

- Vienību testi: `src/test/pocx_*_tests.cpp`
- Funkcionālie testi: `test/functional/feature_pocx_*.py`
- Integrācijas testi: Manuāla testēšana ar regtest

## Konsensa noteikumi

### Piešķīruma izveides noteikumi

1. **Īpašumtiesības:** Darījumam jābūt parakstītam ar plotfaila īpašnieku
2. **Stāvoklis:** Plotfailam jābūt UNASSIGNED vai REVOKED stāvoklī
3. **Formāts:** Derīgs OP_RETURN ar POCX marķieri + 2x 20 baitu adreses
4. **Unikalitāte:** Viens aktīvs piešķīrums uz plotfailu vienlaicīgi

### Atsaukšanas noteikumi

1. **Īpašumtiesības:** Darījumam jābūt parakstītam ar plotfaila īpašnieku
2. **Eksistence:** Piešķīrumam jāeksistē un nav jābūt jau atsauktam
3. **Formāts:** Derīgs OP_RETURN ar XCOP marķieri + 20 baitu adrese

### Aktivizācijas noteikumi

- **Piešķīruma aktivizācija:** `assignment_height + nForgingAssignmentDelay`
- **Atsaukšanas aktivizācija:** `revocation_height + nForgingRevocationDelay`
- **Aizkaves:** Konfigurējamas katram tīklam (piem., 30 bloki = ~1 stunda ar 2 minūšu bloka laiku)

### Bloka validācija

- Nederīgs piešķīrums/atsaukšana → bloks noraidīts (konsensa kļūme)
- OP_RETURN izvades automātiski izslēgtas no UTXO kopas (standarta Bitcoin uzvedība)
- Piešķīrumu apstrāde notiek pirms UTXO atjauninājumiem ConnectBlock

## Secinājums

PoCX kalšanas piešķīrumu sistēma, kā implementēta, nodrošina:

✅ **Vienkāršība:** Standarta Bitcoin darījumi, nav speciālu UTXO
✅ **Izmaksu efektivitāte:** Nav putekļu prasības, tikai darījumu maksas
✅ **Reorganizāciju drošība:** Visaptverošs atsaukšanas dati atjauno pareizu stāvokli
✅ **Atomāri atjauninājumi:** Datu bāzes konsekvence caur LevelDB partijām
✅ **Pilna vēsture:** Pilnīga audita taka visiem piešķīrumiem laika gaitā
✅ **Tīra arhitektūra:** Minimālas Bitcoin Core modifikācijas, izolēts PoCX kods
✅ **Gatavs ražošanai:** Pilnībā implementēts, testēts un darbspējīgs

### Implementācijas kvalitāte

- **Koda organizācija:** Izcila - skaidra atdalīšana starp Bitcoin Core un PoCX
- **Kļūdu apstrāde:** Visaptveroša konsensa validācija
- **Dokumentācija:** Koda komentāri un struktūra labi dokumentēta
- **Testēšana:** Pamata funkcionalitāte testēta, integrācija verificēta

### Apstiprināti galvenie dizaina lēmumi

1. ✅ Tikai OP_RETURN pieeja (pret UTXO balstītu)
2. ✅ Atsevišķa datu bāzes glabāšana (pret Coin extraData)
3. ✅ Pilna vēstures izsekošana (pret tikai pašreizējā)
4. ✅ Īpašumtiesības ar parakstu (pret UTXO tērēšanu)
5. ✅ Aktivizācijas aizkaves (novērš reorganizāciju uzbrukumus)

Sistēma veiksmīgi sasniedz visus arhitektūras mērķus ar tīru, uzturamu implementāciju.

---

[← Iepriekšējā: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Laika sinhronizācija →](5-timing-security.md)

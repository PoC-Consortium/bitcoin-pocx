[← Ankstesnis: Konsensusas ir kasimas](3-consensus-and-mining.md) | [📘 Turinys](index.md) | [Toliau: Laiko sinchronizacija →](5-timing-security.md)

---

# 4 skyrius: PoCX kalimo priskyrimo sistema

## Vykdomoji santrauka

Šis dokumentas aprašo **įgyvendintą** PoCX kalimo priskyrimo sistemą, naudojančią tik OP_RETURN architektūrą. Sistema įgalina grafiko savininkus deleguoti kalimo teises atskiram adresui per grandinėje esančias transakcijas su pilnu reorganizacijos saugumu ir atominėmis duomenų bazės operacijomis.

**Būsena:** ✅ Pilnai įgyvendinta ir veikianti

## Pagrindinio projektavimo filosofija

**Pagrindinis principas:** Priskyrimai yra leidimai, ne turtas

- Jokių specialių UTXO sekamai ar išleisti
- Priskyrimo būsena saugoma atskirai nuo UTXO rinkinio
- Nuosavybė įrodoma transakcijos parašu, ne UTXO išleidimu
- Pilnas istorijos sekimas išsamiam audito pėdsakui
- Atominiai duomenų bazės atnaujinimai per LevelDB paketų įrašus

## Transakcijos struktūra

### Priskyrimo transakcijos formatas

```
Įvestys:
  [0]: Bet kuris UTXO valdomas grafiko savininko (įrodo nuosavybę + moka mokesčius)
       Turi būti pasirašytas grafiko savininko privačiu raktu
  [1+]: Neprivalomi papildomi įėjimai mokesčių padengimui

Išvestys:
  [0]: OP_RETURN (POCX žymeklis + grafiko adresas + kalimo adresas)
       Formatas: OP_RETURN <0x2c> "POCX" <grafiko_adr_20> <kalimo_adr_20>
       Dydis: 46 baitai iš viso (1 baitas OP_RETURN + 1 baitas ilgis + 44 baitai duomenų)
       Reikšmė: 0 BTC (neišleidžiamas, nepridedamas į UTXO rinkinį)

  [1]: Grąža naudotojui (neprivaloma, standartinis P2WPKH)
```

**Įgyvendinimas:** `src/pocx/assignments/opcodes.cpp`

### Atšaukimo transakcijos formatas

```
Įvestys:
  [0]: Bet kuris UTXO valdomas grafiko savininko (įrodo nuosavybę + moka mokesčius)
       Turi būti pasirašytas grafiko savininko privačiu raktu
  [1+]: Neprivalomi papildomi įėjimai mokesčių padengimui

Išvestys:
  [0]: OP_RETURN (XCOP žymeklis + grafiko adresas)
       Formatas: OP_RETURN <0x18> "XCOP" <grafiko_adr_20>
       Dydis: 26 baitai iš viso (1 baitas OP_RETURN + 1 baitas ilgis + 24 baitai duomenų)
       Reikšmė: 0 BTC (neišleidžiamas, nepridedamas į UTXO rinkinį)

  [1]: Grąža naudotojui (neprivaloma, standartinis P2WPKH)
```

**Įgyvendinimas:** `src/pocx/assignments/opcodes.cpp`

### Žymekliai

- **Priskyrimo žymeklis:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Atšaukimo žymeklis:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Įgyvendinimas:** `src/pocx/assignments/opcodes.cpp`

### Pagrindinės transakcijos charakteristikos

- Standartinės Bitcoin transakcijos (jokių protokolo pakeitimų)
- OP_RETURN išvestys yra įrodytinai neišleidžiamos (niekada nepridedamos į UTXO rinkinį)
- Grafiko nuosavybė įrodoma parašu ant input[0] iš grafiko adreso
- Maža kaina (~200 baitų, paprastai <0.0001 BTC mokestis)
- Piniginė automatiškai pasirenka didžiausią UTXO iš grafiko adreso nuosavybei įrodyti

## Duomenų bazės architektūra

### Saugojimo struktūra

Visi priskyrimo duomenys saugomi toje pačioje LevelDB duomenų bazėje kaip UTXO rinkinys (`chainstate/`), bet su atskirais raktų prefiksais:

```
chainstate/ LevelDB:
├─ UTXO rinkinys (Bitcoin Core standartinis)
│  └─ 'C' prefiksas: COutPoint → Coin
│
└─ Priskyrimo būsena (PoCX papildymai)
   └─ 'A' prefiksas: (grafiko_adresas, priskyrimo_txid) → ForgingAssignment
       └─ Pilna istorija: visi priskyrimai kiekvienam grafikui per laiką
```

**Įgyvendinimas:** `src/txdb.cpp`

### ForgingAssignment struktūra

```cpp
struct ForgingAssignment {
    // Tapatybė
    std::array<uint8_t, 20> plotAddress;      // Grafiko savininkas (20 baitų P2WPKH maiša)
    std::array<uint8_t, 20> forgingAddress;   // Kalimo teisių turėtojas (20 baitų P2WPKH maiša)

    // Priskyrimo gyvavimo ciklas
    uint256 assignment_txid;                   // Transakcija sukūrusi priskyrimą
    int assignment_height;                     // Bloko aukštis sukūrimo metu
    int assignment_effective_height;           // Kada tampa aktyvus (aukštis + atidėjimas)

    // Atšaukimo gyvavimo ciklas
    bool revoked;                              // Ar tai buvo atšaukta?
    uint256 revocation_txid;                   // Transakcija atšaukusi tai
    int revocation_height;                     // Bloko aukštis atšaukimo metu
    int revocation_effective_height;           // Kada atšaukimas įsigalioja (aukštis + atidėjimas)

    // Būsenos užklausų metodai
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Įgyvendinimas:** `src/coins.h`

### Priskyrimo būsenos

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nėra priskyrimo
    ASSIGNING = 1,   // Priskyrimas sukurtas, laukia aktyvacijos atidėjimo
    ASSIGNED = 2,    // Priskyrimas aktyvus, kalimas leidžiamas
    REVOKING = 3,    // Atšaukta, bet vis dar aktyvus atidėjimo periodo metu
    REVOKED = 4      // Pilnai atšaukta, nebegalioja
};
```

**Įgyvendinimas:** `src/coins.h`

### Duomenų bazės raktai

```cpp
// Istorijos raktas: saugo pilną priskyrimo įrašą
// Rakto formatas: (prefiksas, grafiko_adresas, priskyrimo_aukštis, priskyrimo_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Grafiko adresas (20 baitų)
    int assignment_height;                // Aukštis rikiavimo optimizacijai
    uint256 assignment_txid;              // Transakcijos ID
};
```

**Įgyvendinimas:** `src/txdb.cpp`

### Istorijos sekimas

- Kiekvienas priskyrimas saugomas nuolat (niekada neištrinamas, nebent reorg)
- Keli priskyrimai kiekvienam grafikui sekami per laiką
- Įgalina pilną audito pėdsaką ir istorines būsenos užklausas
- Atšaukti priskyrimai lieka duomenų bazėje su `revoked=true`

## Bloko apdorojimas

### ConnectBlock integracija

Priskyrimo ir atšaukimo OP_RETURN apdorojami bloko prijungimo metu `validation.cpp`:

```cpp
// Vieta: Po scenarijaus validacijos, prieš UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Analizuoti OP_RETURN duomenis
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Patikrinti nuosavybę (tx turi būti pasirašytas grafiko savininko)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Patikrinti grafiko būseną (turi būti UNASSIGNED arba REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Sukurti naują priskyrimą
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Saugoti atšaukimo duomenis
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Analizuoti OP_RETURN duomenis
            auto plot_addr = ParseRevocationOpReturn(output);

            // Patikrinti nuosavybę
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Gauti dabartinį priskyrimą - atšaukti galima tik ASSIGNED būsenoje
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->GetStateAtHeight(height) != ForgingState::ASSIGNED)
                return state.Invalid("cannot-revoke-inactive");

            // Saugoti seną būseną atšaukimui
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Pažymėti kaip atšauktą
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

// UpdateCoins tęsiasi normaliai (automatiškai praleidžia OP_RETURN išvestis)
```

**Įgyvendinimas:** `src/validation.cpp:ConnectBlock()`

### Nuosavybės verifikacija

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Patikrinti, kad bent vienas įėjimas pasirašytas grafiko savininko
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

**Įgyvendinimas:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Aktyvacijos atidėjimai

Priskyrimai ir atšaukimai turi konfigūruojamus aktyvacijos atidėjimus, kad būtų išvengta reorg atakų:

```cpp
// Konsensuso parametrai (konfigūruojami kiekvienam tinklui)
// Pavyzdys: 30 blokų = ~1 valanda su 2 minučių bloko laiku
consensus.nForgingAssignmentDelay;   // Priskyrimo aktyvacijos atidėjimas
consensus.nForgingRevocationDelay;   // Atšaukimo aktyvacijos atidėjimas
```

**Būsenos perėjimai:**
- Priskyrimas: `UNASSIGNED → ASSIGNING (atidėjimas) → ASSIGNED`
- Atšaukimas: `ASSIGNED → REVOKING (atidėjimas) → REVOKED`

**Įgyvendinimas:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool validacija

Priskyrimo ir atšaukimo transakcijos validuojamos mempool priėmimo metu, kad būtų atmestos negaliojančios transakcijos prieš tinklo platinimą.

### Transakcijos lygio tikrinimai (CheckTransaction)

Atliekami `src/consensus/tx_check.cpp` be grandinės būsenos prieigos:

1. **Maksimaliai vienas POCX OP_RETURN:** Transakcija negali turėti kelių POCX/XCOP žymeklių

**Įgyvendinimas:** `src/consensus/tx_check.cpp`

### Mempool priėmimo tikrinimai (PreChecks)

Atliekami `src/validation.cpp` su pilna grandinės būsenos ir mempool prieiga:

#### Priskyrimo validacija

1. **Grafiko nuosavybė:** Transakcija turi būti pasirašyta grafiko savininko
2. **Grafiko būsena:** Grafikas turi būti UNASSIGNED (0) arba REVOKED (4)
3. **Mempool konfliktai:** Jokio kito priskyrimo šiam grafikui mempool (pirmas pamatytas laimi)

#### Atšaukimo validacija

1. **Grafiko nuosavybė:** Transakcija turi būti pasirašyta grafiko savininko
2. **Aktyvus priskyrimas:** Grafikas turi būti ASSIGNED (2) būsenoje
3. **Mempool konfliktai:** Jokio kito atšaukimo šiam grafikui mempool

**Įgyvendinimas:** `src/validation.cpp:PreChecks()`

### Validacijos srautas

```
Transakcijos transliacija
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maks. vienas POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Patikrinti grafiko nuosavybę
  ✓ Patikrinti priskyrimo būseną
  ✓ Patikrinti mempool konfliktus
       ↓
   Galioja → Priimti į mempool
   Negalioja → Atmesti (neplatinti)
       ↓
Bloko kasimas
       ↓
ConnectBlock() [validation.cpp]
  ✓ Pakartotinai validuoti visus tikrinimus (gynyba gilyn)
  ✓ Pritaikyti būsenos pakeitimus
  ✓ Įrašyti atšaukimo informaciją
```

### Gynyba gilyn

Visi mempool validacijos tikrinimai pakartotinai vykdomi `ConnectBlock()` metu apsaugai nuo:
- Mempool apėjimo atakų
- Negaliojančių blokų iš kenkėjiškų kasėjų
- Ribinių atvejų reorg scenarijų metu

Bloko validacija lieka autoritetinga konsensusui.

## Atominiai duomenų bazės atnaujinimai

### Trijų sluoksnių architektūra

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Atminties podėlis)   │  ← Priskyrimo pakeitimai sekomi atmintyje
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Nešvarumų sekimas: dirtyPlots       │
│   - Ištrynimai: deletedAssignments      │
│   - Atminties sekimas: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Duomenų bazės sluoksnis)│  ← Vienas atominis įrašas
│   - BatchWrite(): UTXOs + Priskyrimai   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Disko saugykla)              │  ← ACID garantijos
│   - Atominė transakcija                 │
└─────────────────────────────────────────┘
```

### Išplovimo procesas

Kai `view.Flush()` iškviečiamas bloko prijungimo metu:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Įrašyti coin pakeitimus į bazę
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Įrašyti priskyrimo pakeitimus atomiškai
    if (fOk && !dirtyPlots.empty()) {
        // Surinkti nešvarius priskyrimus
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

        // Įrašyti į duomenų bazę
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

**Įgyvendinimas:** `src/coins.cpp:Flush()`

### Duomenų bazės paketinis įrašymas

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Vienas LevelDB paketas

    // 1. Pažymėti perėjimo būseną
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Įrašyti visus coin pakeitimus
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Pažymėti nuoseklią būseną
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMINIS PATVIRTINIMAS
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Priskyrimai įrašomi atskirai, bet toje pačioje duomenų bazės transakcijos kontekste
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

**Įgyvendinimas:** `src/txdb.cpp:BatchWriteAssignments()`

### Atomiškumo garantijos

✅ **Kas yra atomiška:**
- Visi coin pakeitimai bloke įrašomi atomiškai
- Visi priskyrimo pakeitimai bloke įrašomi atomiškai
- Duomenų bazė išlieka nuosekli per gedimus

⚠️ **Dabartinis apribojimas:**
- Coins ir priskyrimai įrašomi **atskirose** LevelDB paketų operacijose
- Abi operacijos vyksta `view.Flush()` metu, bet ne viename atominiame įraše
- Praktikoje: Abu paketai užbaigiami greitai prieš disko fsync
- Rizika minimali: Abu turėtų būti atkurti iš to paties bloko gedimo atkūrimo metu

**Pastaba:** Tai skiriasi nuo originalaus architektūros plano, kuris kvietė vienam unifikuotam paketui. Dabartinis įgyvendinimas naudoja du paketus, bet išlaiko nuoseklumą per Bitcoin Core esamus gedimo atkūrimo mechanizmus (DB_HEAD_BLOCKS žymeklis).

## Reorganizacijos tvarkymas

### Atšaukimo duomenų struktūra

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Priskyrimas buvo pridėtas (ištrinti atšaukiant)
        MODIFIED = 1,   // Priskyrimas buvo modifikuotas (atkurti atšaukiant)
        REVOKED = 2     // Priskyrimas buvo atšauktas (atšaukti atšaukimą)
    };

    UndoType type;
    ForgingAssignment assignment;  // Pilna būsena prieš pakeitimą
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO atšaukimo duomenys
    std::vector<ForgingUndo> vforgingundo;  // Priskyrimo atšaukimo duomenys
};
```

**Įgyvendinimas:** `src/undo.h`

### DisconnectBlock procesas

Kai blokas atjungiamas reorg metu:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standartinis UTXO atjungimas ...

    // Skaityti atšaukimo duomenis iš disko
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Atšaukti priskyrimo pakeitimus (apdoroti atvirkštine tvarka)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Priskyrimas buvo pridėtas - pašalinti jį
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Priskyrimas buvo atšauktas - atkurti neatšauktą būseną
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Priskyrimas buvo modifikuotas - atkurti ankstesnę būseną
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Įgyvendinimas:** `src/validation.cpp:DisconnectBlock()`

### Podėlio valdymas reorg metu

```cpp
class CCoinsViewCache {
private:
    // Priskyrimo podėliai
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Sekti modifikuotus grafikus
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Sekti ištrinimus
    mutable size_t cachedAssignmentsUsage{0};  // Atminties sekimas

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

**Įgyvendinimas:** `src/coins.cpp`

## RPC sąsaja

### Mazgo komandos (piniginė nereikalinga)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Grąžina dabartinę priskyrimo būseną grafiko adresui:
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

**Įgyvendinimas:** `src/pocx/rpc/assignments.cpp`

### Piniginės komandos (piniginė reikalinga)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Sukuria priskyrimo transakciją:
- Automatiškai pasirenka didžiausią UTXO iš grafiko adreso nuosavybei įrodyti
- Sukuria transakciją su OP_RETURN + grąžos išvestimi
- Pasirašo grafiko savininko raktu
- Transliuoja į tinklą

**Įgyvendinimas:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Sukuria atšaukimo transakciją:
- Automatiškai pasirenka didžiausią UTXO iš grafiko adreso nuosavybei įrodyti
- Sukuria transakciją su OP_RETURN + grąžos išvestimi
- Pasirašo grafiko savininko raktu
- Transliuoja į tinklą

**Įgyvendinimas:** `src/pocx/rpc/assignments_wallet.cpp`

### Piniginės transakcijos kūrimas

Piniginės transakcijos kūrimo procesas:

```cpp
1. Analizuoti ir validuoti adresus (turi būti P2WPKH bech32)
2. Rasti didžiausią UTXO iš grafiko adreso (įrodo nuosavybę)
3. Sukurti laikiną transakciją su fiktyvios išvestimi
4. Pasirašyti transakciją (gauti tikslų dydį su liudytojo duomenimis)
5. Pakeisti fiktyvią išvestį su OP_RETURN
6. Koreguoti mokesčius proporcingai pagal dydžio pakeitimą
7. Pakartotinai pasirašyti galutinę transakciją
8. Transliuoti į tinklą
```

**Pagrindinė įžvalga:** Piniginė turi išleisti iš grafiko adreso nuosavybei įrodyti, todėl automatiškai priverstinai pasirenka monetas iš to adreso.

**Įgyvendinimas:** `src/pocx/assignments/transactions.cpp`

## Failų struktūra

### Pagrindiniai įgyvendinimo failai

```
src/
├── coins.h                        # ForgingAssignment struktūra, CCoinsViewCache metodai [710 eilučių]
├── coins.cpp                      # Podėlio valdymas, paketiniai įrašai [603 eilutės]
│
├── txdb.h                         # CCoinsViewDB priskyrimo metodai [90 eilučių]
├── txdb.cpp                       # Duomenų bazės skaitymas/rašymas [349 eilutės]
│
├── undo.h                         # ForgingUndo struktūra reorganizacijoms
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock integracija
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN formatas, analizė, verifikacija
    │   ├── opcodes.cpp            # [259 eilutės] Žymeklių apibrėžimai, OP_RETURN ops, nuosavybės tikrinimas
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState pagalbininkai
    │   ├── assignment_state.cpp   # Priskyrimo būsenos užklausų funkcijos
    │   ├── replay.h               # Priskyrimo efektų reorganizacija/pakartojimas
    │   ├── replay.cpp             # ApplyAssignmentEffectsForReplay (reorganizacijos kelias)
    │   ├── transactions.h         # Piniginės transakcijos kūrimo API
    │   └── transactions.cpp       # create_assignment, revoke_assignment piniginės funkcijos
    │
    ├── rpc/
    │   ├── assignments.h          # Mazgo RPC komandos (be piniginės)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # Piniginės RPC komandos
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # PoCXCompressionBounds, genesis bazinis tikslas, suspaudimo grafikas
```

> **Pastaba:** Priskyrimo atidėjimo konstantos `nForgingAssignmentDelay` / `nForgingRevocationDelay` yra Bitcoin Core `Consensus::Params` struktūroje (`src/consensus/params.h`) ir nustatomos pagal tinklą faile `src/kernel/chainparams.cpp` — ne `pocx/consensus/params.h`.

## Našumo charakteristikos

### Duomenų bazės operacijos

- **Gauti dabartinį priskyrimą:** O(n) - nuskaityti visus priskyrimus grafiko adresui rasti naujausią
- **Gauti priskyrimo istoriją:** O(n) - iteruoti visus priskyrimus grafikui
- **Sukurti priskyrimą:** O(1) - vienas įterpimas
- **Atšaukti priskyrimą:** O(1) - vienas atnaujinimas
- **Reorg (kiekvienam priskyrimui):** O(1) - tiesioginis atšaukimo duomenų taikymas

Kur n = priskyrimų skaičius grafikui (paprastai mažas, < 10)

### Atminties naudojimas

- **Kiekvienam priskyrimui:** ~160 baitų (ForgingAssignment struktūra)
- **Podėlio pridėtiniai kaštai:** Maišos žemėlapio pridėtiniai kaštai nešvarumo sekimui
- **Tipinis blokas:** <10 priskyrimų = <2 KB atminties

### Disko naudojimas

- **Kiekvienam priskyrimui:** ~200 baitų diske (su LevelDB pridėtiniais kaštais)
- **10000 priskyrimų:** ~2 MB disko vietos
- **Nereikšminga palyginti su UTXO rinkiniu:** <0.001% tipinio chainstate

## Dabartiniai apribojimai ir ateities darbai

### Atomiškumo apribojimas

**Dabartinis:** Coins ir priskyrimai įrašomi atskiruose LevelDB paketuose `view.Flush()` metu

**Poveikis:** Teorinė nenuoseklumo rizika jei gedimas įvyksta tarp paketų

**Sušvelninimas:**
- Abu paketai užbaigiami greitai prieš fsync
- Bitcoin Core gedimo atkūrimas naudoja DB_HEAD_BLOCKS žymeklį
- Praktikoje: Niekada nepastebėta testavimo metu

**Ateities tobulinimas:** Unifikuoti į vieną LevelDB paketų operaciją

### Priskyrimo istorijos valymas

**Dabartinis:** Visi priskyrimai saugomi neribotą laiką

**Poveikis:** ~200 baitų kiekvienam priskyrimui amžinai

**Ateitis:** Neprivalomas pilnai atšauktų priskyrimų, senesnių nei N blokų, valymas

**Pastaba:** Mažai tikėtina, kad reikės - net 1 milijonas priskyrimų = 200 MB

## Testavimo būsena

### Įgyvendinti testai

✅ OP_RETURN analizė ir validacija
✅ Nuosavybės verifikacija
✅ ConnectBlock priskyrimo kūrimas
✅ ConnectBlock atšaukimas
✅ DisconnectBlock reorg tvarkymas
✅ Duomenų bazės skaitymo/rašymo operacijos
✅ Būsenos perėjimai (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC komandos (get_assignment, create_assignment, revoke_assignment)
✅ Piniginės transakcijos kūrimas

### Testų aprėpties sritys

- Vienetiniai testai: `src/test/pocx_tests.cpp`, `src/test/pocx_simd_tests.cpp`
- Integraciniai testai: regtest apvalkalo skriptai kataloguose `scripts/assignments/` ir `scripts/mining/`

## Konsensuso taisyklės

### Priskyrimo kūrimo taisyklės

1. **Nuosavybė:** Transakcija turi būti pasirašyta grafiko savininko
2. **Būsena:** Grafikas turi būti UNASSIGNED arba REVOKED būsenoje
3. **Formatas:** Galiojantis OP_RETURN su POCX žymekliu + 2x 20 baitų adresai
4. **Unikalumas:** Vienas aktyvus priskyrimas kiekvienam grafikui vienu metu

### Atšaukimo taisyklės

1. **Nuosavybė:** Transakcija turi būti pasirašyta grafiko savininko
2. **Egzistavimas:** Priskyrimas turi egzistuoti ir nebūti jau atšauktas
3. **Formatas:** Galiojantis OP_RETURN su XCOP žymekliu + 20 baitų adresas

### Aktyvacijos taisyklės

- **Priskyrimo aktyvacija:** `priskyrimo_aukštis + nForgingAssignmentDelay`
- **Atšaukimo aktyvacija:** `atšaukimo_aukštis + nForgingRevocationDelay`
- **Atidėjimai:** Konfigūruojami kiekvienam tinklui (pvz., 30 blokų = ~1 valanda su 2 minučių bloko laiku)

### Bloko validacija

- Negaliojantis priskyrimas/atšaukimas → blokas atmestas (konsensuso nesėkmė)
- OP_RETURN išvestys automatiškai neįtraukiamos į UTXO rinkinį (standartinis Bitcoin elgesys)
- Priskyrimo apdorojimas vyksta prieš UTXO atnaujinimus ConnectBlock

## Išvada

PoCX kalimo priskyrimo sistema, kaip įgyvendinta, teikia:

✅ **Paprastumas:** Standartinės Bitcoin transakcijos, jokių specialių UTXO
✅ **Ekonomiškumas:** Jokio dulkių reikalavimo, tik transakcijų mokesčiai
✅ **Reorg saugumas:** Išsamūs atšaukimo duomenys atkuria teisingą būseną
✅ **Atominiai atnaujinimai:** Duomenų bazės nuoseklumas per LevelDB paketus
✅ **Pilna istorija:** Išsamus visų priskyrimų audito pėdsakas per laiką
✅ **Švari architektūra:** Minimalūs Bitcoin Core pakeitimai, izoliuotas PoCX kodas
✅ **Gamybos paruošta:** Pilnai įgyvendinta, testuota ir veikianti

### Įgyvendinimo kokybė

- **Kodo organizacija:** Puiki - aiškus atskyrimas tarp Bitcoin Core ir PoCX
- **Klaidų tvarkymas:** Išsami konsensuso validacija
- **Dokumentacija:** Kodo komentarai ir struktūra gerai dokumentuota
- **Testavimas:** Pagrindinė funkcionalumas testuotas, integracija patikrinta

### Pagrindiniai projektavimo sprendimai patvirtinti

1. ✅ Tik OP_RETURN metodas (vs UTXO pagrįstas)
2. ✅ Atskira duomenų bazės saugykla (vs Coin extraData)
3. ✅ Pilnas istorijos sekimas (vs tik dabartinis)
4. ✅ Nuosavybė parašu (vs UTXO išleidimu)
5. ✅ Aktyvacijos atidėjimai (apsauga nuo reorg atakų)

Sistema sėkmingai pasiekia visus architektūrinius tikslus su švariu, prižiūrimu įgyvendinimu.

---

[← Ankstesnis: Konsensusas ir kasimas](3-consensus-and-mining.md) | [📘 Turinys](index.md) | [Toliau: Laiko sinchronizacija →](5-timing-security.md)

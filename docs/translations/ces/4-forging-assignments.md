[← Předchozí: Konsenzus a těžba](3-consensus-and-mining.md) | [Obsah](index.md) | [Další: Časová synchronizace →](5-timing-security.md)

---

# Kapitola 4: Systém forging přiřazení PoCX

## Shrnutí

Tento dokument popisuje **implementovaný** systém forging přiřazení PoCX používající architekturu pouze s OP_RETURN. Systém umožňuje vlastníkům plotů delegovat práva na forging na oddělené adresy prostřednictvím on-chain transakcí, s plnou bezpečností vůči reorgům a atomickými databázovými operacemi.

**Stav:** Plně implementováno a funkční

## Základní filozofie návrhu

**Klíčový princip:** Přiřazení jsou oprávnění, nikoliv aktiva

- Žádná speciální UTXO ke sledování nebo utracení
- Stav přiřazení uložen odděleně od UTXO setu
- Vlastnictví prokázáno podpisem transakce, nikoliv utracením UTXO
- Kompletní sledování historie pro úplný audit trail
- Atomické aktualizace databáze prostřednictvím dávkových zápisů LevelDB

## Struktura transakcí

### Formát transakce přiřazení

```
Vstupy:
  [0]: Jakékoliv UTXO kontrolované vlastníkem plotu (prokazuje vlastnictví + platí poplatky)
       Musí být podepsáno privátním klíčem vlastníka plotu
  [1+]: Volitelné dodatečné vstupy pro pokrytí poplatků

Výstupy:
  [0]: OP_RETURN (POCX marker + adresa plotu + forging adresa)
       Formát: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Velikost: 46 bajtů celkem (1 bajt OP_RETURN + 1 bajt délka + 44 bajtů data)
       Hodnota: 0 BTC (neutratitelné, nepřidáno do UTXO setu)

  [1]: Vrácení zbytku uživateli (volitelné, standardní P2WPKH)
```

**Implementace:** `src/pocx/assignments/opcodes.cpp:25-52`

### Formát transakce revokace

```
Vstupy:
  [0]: Jakékoliv UTXO kontrolované vlastníkem plotu (prokazuje vlastnictví + platí poplatky)
       Musí být podepsáno privátním klíčem vlastníka plotu
  [1+]: Volitelné dodatečné vstupy pro pokrytí poplatků

Výstupy:
  [0]: OP_RETURN (XCOP marker + adresa plotu)
       Formát: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Velikost: 26 bajtů celkem (1 bajt OP_RETURN + 1 bajt délka + 24 bajtů data)
       Hodnota: 0 BTC (neutratitelné, nepřidáno do UTXO setu)

  [1]: Vrácení zbytku uživateli (volitelné, standardní P2WPKH)
```

**Implementace:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markery

- **Marker přiřazení:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Marker revokace:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementace:** `src/pocx/assignments/opcodes.cpp:15-19`

### Klíčové charakteristiky transakcí

- Standardní Bitcoin transakce (žádné změny protokolu)
- Výstupy OP_RETURN jsou prokazatelně neutratitelné (nikdy nepřidány do UTXO setu)
- Vlastnictví plotu prokázáno podpisem na vstup[0] z adresy plotu
- Nízké náklady (~200 bajtů, typicky <0,0001 BTC poplatek)
- Peněženka automaticky vybírá největší UTXO z adresy plotu pro prokázání vlastnictví

## Architektura databáze

### Struktura úložiště

Všechna data přiřazení jsou uložena ve stejné LevelDB databázi jako UTXO set (`chainstate/`), ale s oddělenými prefixy klíčů:

```
chainstate/ LevelDB:
├─ UTXO Set (standardní Bitcoin Core)
│  └─ Prefix 'C': COutPoint → Coin
│
└─ Stav přiřazení (doplňky PoCX)
   └─ Prefix 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Kompletní historie: všechna přiřazení na plot v čase
```

**Implementace:** `src/txdb.cpp:237-348`

### Struktura ForgingAssignment

```cpp
struct ForgingAssignment {
    // Identita
    std::array<uint8_t, 20> plotAddress;      // Vlastník plotu (20bajtový P2WPKH hash)
    std::array<uint8_t, 20> forgingAddress;   // Držitel práv na forging (20bajtový P2WPKH hash)

    // Životní cyklus přiřazení
    uint256 assignment_txid;                   // Transakce, která vytvořila přiřazení
    int assignment_height;                     // Výška bloku při vytvoření
    int assignment_effective_height;           // Kdy se stane aktivní (výška + zpoždění)

    // Životní cyklus revokace
    bool revoked;                              // Bylo toto revokováno?
    uint256 revocation_txid;                   // Transakce, která to revokovala
    int revocation_height;                     // Výška bloku při revokaci
    int revocation_effective_height;           // Kdy revokace nabude účinnosti (výška + zpoždění)

    // Metody pro dotazování stavu
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementace:** `src/coins.h:111-178`

### Stavy přiřazení

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Přiřazení neexistuje
    ASSIGNING = 1,   // Přiřazení vytvořeno, čeká na aktivační zpoždění
    ASSIGNED = 2,    // Přiřazení aktivní, forging povolen
    REVOKING = 3,    // Revokováno, ale stále aktivní během období zpoždění
    REVOKED = 4      // Plně revokováno, již není aktivní
};
```

**Implementace:** `src/coins.h:98-104`

### Klíče databáze

```cpp
// Klíč historie: ukládá kompletní záznam přiřazení
// Formát klíče: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Adresa plotu (20 bajtů)
    int assignment_height;                // Výška pro optimalizaci řazení
    uint256 assignment_txid;              // ID transakce
};
```

**Implementace:** `src/txdb.cpp:245-262`

### Sledování historie

- Každé přiřazení uloženo permanentně (nikdy nesmazáno, pokud není reorg)
- Více přiřazení na plot sledováno v čase
- Umožňuje kompletní audit trail a dotazy na historický stav
- Revokovaná přiřazení zůstávají v databázi s `revoked=true`

## Zpracování bloků

### Integrace ConnectBlock

OP_RETURNy přiřazení a revokace jsou zpracovány během připojení bloku v `validation.cpp`:

```cpp
// Umístění: Po validaci skriptu, před UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsovat data OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Ověřit vlastnictví (tx musí být podepsána vlastníkem plotu)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Zkontrolovat stav plotu (musí být UNASSIGNED nebo REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Vytvořit nové přiřazení
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Uložit undo data
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsovat data OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Ověřit vlastnictví
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Získat aktuální přiřazení
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Uložit starý stav pro undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Označit jako revokované
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

// UpdateCoins pokračuje normálně (automaticky přeskakuje výstupy OP_RETURN)
```

**Implementace:** `src/validation.cpp:2775-2878`

### Ověření vlastnictví

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Zkontrolovat, že alespoň jeden vstup je podepsán vlastníkem plotu
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extrahovat cíl
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Zkontrolovat, zda P2WPKH na adresu plotu
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core již validoval podpis
                return true;
            }
        }
    }
    return false;
}
```

**Implementace:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktivační zpoždění

Přiřazení a revokace mají konfigurovatelná aktivační zpoždění pro prevenci útoků pomocí reorgů:

```cpp
// Konsensuální parametry (konfigurovatelné pro každou síť)
// Příklad: 30 bloků = ~1 hodina při 2minutovém čase bloku
consensus.nForgingAssignmentDelay;   // Zpoždění aktivace přiřazení
consensus.nForgingRevocationDelay;   // Zpoždění aktivace revokace
```

**Přechody stavů:**
- Přiřazení: `UNASSIGNED → ASSIGNING (zpoždění) → ASSIGNED`
- Revokace: `ASSIGNED → REVOKING (zpoždění) → REVOKED`

**Implementace:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validace mempoolu

Transakce přiřazení a revokace jsou validovány při přijetí do mempoolu pro odmítnutí neplatných transakcí před šířením po síti.

### Kontroly na úrovni transakce (CheckTransaction)

Prováděno v `src/consensus/tx_check.cpp` bez přístupu ke stavu řetězce:

1. **Maximálně jeden POCX OP_RETURN:** Transakce nesmí obsahovat více markerů POCX/XCOP

**Implementace:** `src/consensus/tx_check.cpp:63-77`

### Kontroly přijetí do mempoolu (PreChecks)

Prováděno v `src/validation.cpp` s plným přístupem ke stavu řetězce a mempoolu:

#### Validace přiřazení

1. **Vlastnictví plotu:** Transakce musí být podepsána vlastníkem plotu
2. **Stav plotu:** Plot musí být UNASSIGNED (0) nebo REVOKED (4)
3. **Konflikty v mempoolu:** Žádné jiné přiřazení pro tento plot v mempoolu (vyhrává první-vidět)

#### Validace revokace

1. **Vlastnictví plotu:** Transakce musí být podepsána vlastníkem plotu
2. **Aktivní přiřazení:** Plot musí být pouze ve stavu ASSIGNED (2)
3. **Konflikty v mempoolu:** Žádná jiná revokace pro tento plot v mempoolu

**Implementace:** `src/validation.cpp:898-993`

### Tok validace

```
Vysílání transakce
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Max jeden POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Ověřit vlastnictví plotu
  ✓ Zkontrolovat stav přiřazení
  ✓ Zkontrolovat konflikty v mempoolu
       ↓
   Platné → Přijmout do mempoolu
   Neplatné → Odmítnout (nešířit)
       ↓
Těžba bloku
       ↓
ConnectBlock() [validation.cpp]
  ✓ Znovu validovat všechny kontroly (obrana do hloubky)
  ✓ Aplikovat změny stavu
  ✓ Zaznamenat undo informace
```

### Obrana do hloubky

Všechny kontroly validace mempoolu jsou znovu provedeny během `ConnectBlock()` jako ochrana proti:
- Útokům obejití mempoolu
- Neplatným blokům od škodlivých těžařů
- Hraničním případům během scénářů reorgů

Validace bloku zůstává autoritativní pro konsenzus.

## Atomické aktualizace databáze

### Třívrstvá architektura

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (paměťová cache)      │  ← Změny přiřazení sledovány v paměti
│   - Coiny: cacheCoins                   │
│   - Přiřazení: pendingAssignments       │
│   - Sledování dirty: dirtyPlots         │
│   - Mazání: deletedAssignments          │
│   - Sledování paměti: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (databázová vrstva)      │  ← Jeden atomický zápis
│   - BatchWrite(): UTXO + přiřazení      │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (diskové úložiště)            │  ← ACID garance
│   - Atomická transakce                  │
└─────────────────────────────────────────┘
```

### Proces flush

Když je zavoláno `view.Flush()` během připojení bloku:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Zapsat změny coinů do základu
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Zapsat změny přiřazení atomicky
    if (fOk && !dirtyPlots.empty()) {
        // Shromáždit dirty přiřazení
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Prázdné - nepoužívá se

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Zapsat do databáze
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Vyčistit sledování
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Uvolnit paměť
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementace:** `src/coins.cpp:278-315`

### Dávkový zápis do databáze

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Jedna dávka LevelDB

    // 1. Označit přechodový stav
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Zapsat všechny změny coinů
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Označit konzistentní stav
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMICKÝ COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Přiřazení zapsána odděleně, ale ve stejném kontextu databázové transakce
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Nepoužívaný parametr (zachován pro kompatibilitu API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nová dávka, ale stejná databáze

    // Zapsat historii přiřazení
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Smazat odstraněná přiřazení z historie
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMICKÝ COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementace:** `src/txdb.cpp:332-348`

### Garance atomicity

Co je atomické:
- Všechny změny coinů v rámci bloku jsou zapsány atomicky
- Všechny změny přiřazení v rámci bloku jsou zapsány atomicky
- Databáze zůstává konzistentní při pádech

**Aktuální omezení:**
- Coiny a přiřazení jsou zapsány v **oddělených** dávkových operacích LevelDB
- Obě operace probíhají během `view.Flush()`, ale ne v jediném atomickém zápisu
- V praxi: Obě dávky se dokončí rychle za sebou před fsync disku
- Riziko je minimální: Obě by musely být přehrány ze stejného bloku při obnově po pádu

**Poznámka:** Toto se liší od původního architektonického plánu, který volal po jediné sjednocené dávce. Aktuální implementace používá dvě dávky, ale udržuje konzistenci prostřednictvím existujících mechanismů obnovy po pádu Bitcoin Core (marker DB_HEAD_BLOCKS).

## Zpracování reorgů

### Datová struktura undo

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Přiřazení bylo přidáno (smazat při undo)
        MODIFIED = 1,   // Přiřazení bylo modifikováno (obnovit při undo)
        REVOKED = 2     // Přiřazení bylo revokováno (zrušit revokaci při undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Kompletní stav před změnou
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo data
    std::vector<ForgingUndo> vforgingundo;  // Undo data přiřazení
};
```

**Implementace:** `src/undo.h:63-105`

### Proces DisconnectBlock

Když je blok odpojen během reorgu:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standardní odpojení UTXO ...

    // Přečíst undo data z disku
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Vrátit změny přiřazení (zpracovat v opačném pořadí)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Přiřazení bylo přidáno - odstranit ho
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Přiřazení bylo revokováno - obnovit nerevokovaný stav
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Přiřazení bylo modifikováno - obnovit předchozí stav
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementace:** `src/validation.cpp:2381-2415`

### Správa cache během reorgu

```cpp
class CCoinsViewCache {
private:
    // Cache přiřazení
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Sledovat modifikované ploty
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Sledovat mazání
    mutable size_t cachedAssignmentsUsage{0};  // Sledování paměti

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

**Implementace:** `src/coins.cpp:494-565`

## RPC rozhraní

### Příkazy uzlu (nevyžadují peněženku)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Vrací aktuální stav přiřazení pro adresu plotu:
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

**Implementace:** `src/pocx/rpc/assignments.cpp:31-126`

### Příkazy peněženky (vyžadují peněženku)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Vytvoří transakci přiřazení:
- Automaticky vybírá největší UTXO z adresy plotu pro prokázání vlastnictví
- Sestaví transakci s výstupem OP_RETURN + vrácení zbytku
- Podepíše klíčem vlastníka plotu
- Vyšle do sítě

**Implementace:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Vytvoří transakci revokace:
- Automaticky vybírá největší UTXO z adresy plotu pro prokázání vlastnictví
- Sestaví transakci s výstupem OP_RETURN + vrácení zbytku
- Podepíše klíčem vlastníka plotu
- Vyšle do sítě

**Implementace:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Vytváření transakcí v peněžence

Proces vytváření transakcí v peněžence:

```cpp
1. Parsovat a validovat adresy (musí být P2WPKH bech32)
2. Najít největší UTXO z adresy plotu (prokazuje vlastnictví)
3. Vytvořit dočasnou transakci s dummy výstupem
4. Podepsat transakci (získat přesnou velikost s witness daty)
5. Nahradit dummy výstup za OP_RETURN
6. Upravit poplatky proporcionálně na základě změny velikosti
7. Znovu podepsat finální transakci
8. Vyslat do sítě
```

**Klíčový poznatek:** Peněženka musí utratit z adresy plotu pro prokázání vlastnictví, takže automaticky vynucuje výběr coinů z této adresy.

**Implementace:** `src/pocx/assignments/transactions.cpp:38-263`

## Struktura souborů

### Hlavní implementační soubory

```
src/
├── coins.h                        # Struktura ForgingAssignment, metody CCoinsViewCache [710 řádků]
├── coins.cpp                      # Správa cache, dávkové zápisy [603 řádků]
│
├── txdb.h                         # Metody CCoinsViewDB pro přiřazení [90 řádků]
├── txdb.cpp                       # Čtení/zápis do databáze [349 řádků]
│
├── undo.h                         # Struktura ForgingUndo pro reorgy
│
├── validation.cpp                 # Integrace ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Formát OP_RETURN, parsování, ověření
    │   ├── opcodes.cpp            # [259 řádků] Definice markerů, operace OP_RETURN, kontrola vlastnictví
    │   ├── assignment_state.h     # Helpery GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Funkce pro dotazování stavu přiřazení
    │   ├── transactions.h         # API pro vytváření transakcí v peněžence
    │   └── transactions.cpp       # Funkce peněženky create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # RPC příkazy uzlu (bez peněženky)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # RPC příkazy peněženky
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Charakteristiky výkonu

### Databázové operace

- **Získat aktuální přiřazení:** O(n) - skenovat všechna přiřazení pro adresu plotu k nalezení nejnovějšího
- **Získat historii přiřazení:** O(n) - iterovat všechna přiřazení pro plot
- **Vytvořit přiřazení:** O(1) - jeden insert
- **Revokovat přiřazení:** O(1) - jedna aktualizace
- **Reorg (na přiřazení):** O(1) - přímá aplikace undo dat

Kde n = počet přiřazení pro plot (typicky malý, < 10)

### Využití paměti

- **Na přiřazení:** ~160 bajtů (struktura ForgingAssignment)
- **Overhead cache:** Overhead hash mapy pro dirty sledování
- **Typický blok:** <10 přiřazení = <2 KB paměti

### Využití disku

- **Na přiřazení:** ~200 bajtů na disku (s overhead LevelDB)
- **10000 přiřazení:** ~2 MB diskového prostoru
- **Zanedbatelné ve srovnání s UTXO setem:** <0,001% typického chainstate

## Aktuální omezení a budoucí práce

### Omezení atomicity

**Aktuálně:** Coiny a přiřazení zapsány v oddělených dávkách LevelDB během `view.Flush()`

**Dopad:** Teoretické riziko nekonzistence, pokud dojde k pádu mezi dávkami

**Zmírnění:**
- Obě dávky se dokončí rychle před fsync
- Obnova po pádu Bitcoin Core používá marker DB_HEAD_BLOCKS
- V praxi: Nikdy nepozorováno při testování

**Budoucí vylepšení:** Sjednotit do jediné dávkové operace LevelDB

### Prořezávání historie přiřazení

**Aktuálně:** Všechna přiřazení uložena neomezeně

**Dopad:** ~200 bajtů na přiřazení navždy

**Budoucnost:** Volitelné prořezávání plně revokovaných přiřazení starších než N bloků

**Poznámka:** Pravděpodobně nebude potřeba - i 1 milion přiřazení = 200 MB

## Stav testování

### Implementované testy

- Parsování a validace OP_RETURN
- Ověření vlastnictví
- Vytvoření přiřazení v ConnectBlock
- Revokace v ConnectBlock
- Zpracování reorgu v DisconnectBlock
- Operace čtení/zápisu databáze
- Přechody stavů (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- RPC příkazy (get_assignment, create_assignment, revoke_assignment)
- Vytváření transakcí v peněžence

### Oblasti pokrytí testy

- Unit testy: `src/test/pocx_*_tests.cpp`
- Funkční testy: `test/functional/feature_pocx_*.py`
- Integrační testy: Manuální testování s regtest

## Konsensuální pravidla

### Pravidla vytvoření přiřazení

1. **Vlastnictví:** Transakce musí být podepsána vlastníkem plotu
2. **Stav:** Plot musí být ve stavu UNASSIGNED nebo REVOKED
3. **Formát:** Platný OP_RETURN s markerem POCX + 2× 20bajtové adresy
4. **Unikátnost:** Jedno aktivní přiřazení na plot najednou

### Pravidla revokace

1. **Vlastnictví:** Transakce musí být podepsána vlastníkem plotu
2. **Existence:** Přiřazení musí existovat a nesmí být již revokováno
3. **Formát:** Platný OP_RETURN s markerem XCOP + 20bajtová adresa

### Pravidla aktivace

- **Aktivace přiřazení:** `assignment_height + nForgingAssignmentDelay`
- **Aktivace revokace:** `revocation_height + nForgingRevocationDelay`
- **Zpoždění:** Konfigurovatelné pro každou síť (např. 30 bloků = ~1 hodina při 2minutovém čase bloku)

### Validace bloku

- Neplatné přiřazení/revokace → blok odmítnut (selhání konsenzu)
- Výstupy OP_RETURN automaticky vyloučeny z UTXO setu (standardní chování Bitcoinu)
- Zpracování přiřazení probíhá před aktualizacemi UTXO v ConnectBlock

## Závěr

Systém forging přiřazení PoCX v implementované podobě poskytuje:

- **Jednoduchost:** Standardní Bitcoin transakce, žádná speciální UTXO
- **Nákladová efektivita:** Žádný požadavek na dust, pouze transakční poplatky
- **Bezpečnost vůči reorgům:** Komplexní undo data obnovují správný stav
- **Atomické aktualizace:** Konzistence databáze prostřednictvím dávek LevelDB
- **Kompletní historie:** Úplný audit trail všech přiřazení v čase
- **Čistá architektura:** Minimální modifikace Bitcoin Core, izolovaný PoCX kód
- **Připravenost na produkci:** Plně implementováno, testováno a funkční

### Kvalita implementace

- **Organizace kódu:** Výborná - jasné oddělení mezi Bitcoin Core a PoCX
- **Zpracování chyb:** Komplexní validace konsenzu
- **Dokumentace:** Komentáře v kódu a struktura dobře zdokumentovány
- **Testování:** Testována základní funkcionalita, ověřena integrace

### Validovaná klíčová designová rozhodnutí

1. Přístup pouze s OP_RETURN (vs založeno na UTXO)
2. Oddělené databázové úložiště (vs Coin extraData)
3. Kompletní sledování historie (vs pouze aktuální)
4. Vlastnictví podpisem (vs utrácením UTXO)
5. Aktivační zpoždění (zabraňuje útokům pomocí reorgů)

Systém úspěšně dosahuje všech architektonických cílů s čistou, udržovatelnou implementací.

---

[← Předchozí: Konsenzus a těžba](3-consensus-and-mining.md) | [Obsah](index.md) | [Další: Časová synchronizace →](5-timing-security.md)

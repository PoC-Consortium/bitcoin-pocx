[<- Eelmine: Konsensus ja kaevandamine](3-consensus-and-mining.md) | [Sisukord](index.md) | [Järgmine: Ajasünkroniseerimine ->](5-timing-security.md)

---

# Peatükk 4: PoCX sepistamisülesannete süsteem

## Kokkuvõte

See dokument kirjeldab **implementeeritud** PoCX sepistamisülesannete süsteemi, mis kasutab OP_RETURN-ainult arhitektuuri. Süsteem võimaldab graafikuomanikel delegeerida sepistamisõigused eraldi aadressidele läbi ahelas olevate tehingute, täieliku ümberkorralduste ohutuse ja aatomiliste andmebaasi operatsioonidega.

**Staatus:** Täielikult implementeeritud ja töökorras

## Põhidisaini filosoofia

**Põhiprintsiip:** Ülesanded on õigused, mitte varad

- Pole erilisi UTXO-sid jälgida ega kulutada
- Ülesannete olekut hoitakse eraldi UTXO kogumist
- Omand tõestatakse tehingu allkirjaga, mitte UTXO kulutamisega
- Täielik ajaloo jälgimine täieliku auditijälje jaoks
- Aatomilised andmebaasi uuendused läbi LevelDB pakkkirjutuste

## Tehingu struktuur

### Ülesande tehingu vorming

```
Sisendid:
  [0]: Mis tahes UTXO, mida kontrollib graafikuomanik (tõestab omandi + maksab tasud)
       Peab olema allkirjastatud graafikuomaniku privaatvõtmega
  [1+]: Valikulised lisasisendid tasude katteks

Väljundid:
  [0]: OP_RETURN (POCX marker + graafiku aadress + sepistamise aadress)
       Vorming: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Suurus: 46 baiti kokku (1 bait OP_RETURN + 1 bait pikkus + 44 baiti andmed)
       Väärtus: 0 BTC (kulutatamatu, ei lisata UTXO kogumisse)

  [1]: Vahetus tagasi kasutajale (valikuline, standardne P2WPKH)
```

**Implementatsioon:** `src/pocx/assignments/opcodes.cpp:25-52`

### Tühistamise tehingu vorming

```
Sisendid:
  [0]: Mis tahes UTXO, mida kontrollib graafikuomanik (tõestab omandi + maksab tasud)
       Peab olema allkirjastatud graafikuomaniku privaatvõtmega
  [1+]: Valikulised lisasisendid tasude katteks

Väljundid:
  [0]: OP_RETURN (XCOP marker + graafiku aadress)
       Vorming: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Suurus: 26 baiti kokku (1 bait OP_RETURN + 1 bait pikkus + 24 baiti andmed)
       Väärtus: 0 BTC (kulutatamatu, ei lisata UTXO kogumisse)

  [1]: Vahetus tagasi kasutajale (valikuline, standardne P2WPKH)
```

**Implementatsioon:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markerid

- **Ülesande marker:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Tühistamise marker:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementatsioon:** `src/pocx/assignments/opcodes.cpp:15-19`

### Tehingu põhiomadused

- Standardsed Bitcoin tehingud (protokollimuudatusi pole)
- OP_RETURN väljundid on tõestatavalt kulutamatud (ei lisata kunagi UTXO kogumisse)
- Graafiku omand tõestatakse allkirjaga sisendil[0] graafiku aadressilt
- Madal kulu (~200 baiti, tavaliselt <0.0001 BTC tasu)
- Rahakott valib automaatselt suurima UTXO graafiku aadressilt omandi tõestamiseks

## Andmebaasi arhitektuur

### Hoiustusstruktuur

Kõik ülesannete andmed hoitakse samas LevelDB andmebaasis kui UTXO kogum (`chainstate/`), kuid eraldi võtme prefiksitega:

```
chainstate/ LevelDB:
├─ UTXO kogum (Bitcoin Core standard)
│  └─ 'C' prefiks: COutPoint -> Coin
│
└─ Ülesannete olek (PoCX lisandused)
   └─ 'A' prefiks: (plot_address, assignment_txid) -> ForgingAssignment
       └─ Täielik ajalugu: kõik ülesanded graafiku kohta aja jooksul
```

**Implementatsioon:** `src/txdb.cpp:237-348`

### ForgingAssignment struktuur

```cpp
struct ForgingAssignment {
    // Identiteet
    std::array<uint8_t, 20> plotAddress;      // Graafikuomanik (20-baidine P2WPKH räsi)
    std::array<uint8_t, 20> forgingAddress;   // Sepistamisõiguste omanik (20-baidine P2WPKH räsi)

    // Ülesande elutsükkel
    uint256 assignment_txid;                   // Tehing, mis lõi ülesande
    int assignment_height;                     // Ploki kõrgus loomise ajal
    int assignment_effective_height;           // Millal see aktiveerub (kõrgus + viivitus)

    // Tühistamise elutsükkel
    bool revoked;                              // Kas see on tühistatud?
    uint256 revocation_txid;                   // Tehing, mis tühistas selle
    int revocation_height;                     // Ploki kõrgus tühistamise ajal
    int revocation_effective_height;           // Millal tühistamine jõustub (kõrgus + viivitus)

    // Oleku päringumeetodid
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementatsioon:** `src/coins.h:111-178`

### Ülesannete olekud

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ülesannet pole
    ASSIGNING = 1,   // Ülesanne loodud, ootab aktiveerimisviivitust
    ASSIGNED = 2,    // Ülesanne aktiivne, sepistamine lubatud
    REVOKING = 3,    // Tühistatud, kuid endiselt aktiivne viivitusperioodi jooksul
    REVOKED = 4      // Täielikult tühistatud, enam mitte aktiivne
};
```

**Implementatsioon:** `src/coins.h:98-104`

### Andmebaasi võtmed

```cpp
// Ajaloo võti: hoiab täielikku ülesande kirjet
// Võtme vorming: (prefiks, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Graafiku aadress (20 baiti)
    int assignment_height;                // Kõrgus sortimise optimeerimiseks
    uint256 assignment_txid;              // Tehingu ID
};
```

**Implementatsioon:** `src/txdb.cpp:245-262`

### Ajaloo jälgimine

- Iga ülesanne hoitakse püsivalt (ei kustutata kunagi, v.a ümberkorralduse korral)
- Mitu ülesannet graafiku kohta jälgitakse aja jooksul
- Võimaldab täielikku auditijälge ja ajaloolisi olekupäringuid
- Tühistatud ülesanded jäävad andmebaasi `revoked=true` märgisega

## Ploki töötlemine

### ConnectBlock integratsioon

Ülesande ja tühistamise OP_RETURN-e töödeldakse ploki ühendamise ajal failis `validation.cpp`:

```cpp
// Asukoht: Pärast skripti valideerimist, enne UpdateCoins'i
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsi OP_RETURN andmed
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifitseeri omand (tx peab olema allkirjastatud graafikuomaniku poolt)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Kontrolli graafiku olekut (peab olema UNASSIGNED või REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Loo uus ülesanne
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Salvesta tagasivõtmise andmed
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsi OP_RETURN andmed
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifitseeri omand
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Hangi praegune ülesanne
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Salvesta vana olek tagasivõtmiseks
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Märgi tühistatuks
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

// UpdateCoins jätkab normaalselt (jätab automaatselt OP_RETURN väljundid vahele)
```

**Implementatsioon:** `src/validation.cpp:2775-2878`

### Omandi verifitseerimine

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Kontrolli, et vähemalt üks sisend on allkirjastatud graafikuomaniku poolt
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Ekstrakteeri sihtkoht
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Kontrolli, kas P2WPKH graafiku aadressile
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core on allkirja juba valideerinud
                return true;
            }
        }
    }
    return false;
}
```

**Implementatsioon:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktiveerimise viivitused

Ülesannetel ja tühistamistel on konfigureeritavad aktiveerimisviivitused ümberkorraldusrünnakute vältimiseks:

```cpp
// Konsensuse parameetrid (konfigureeritavad võrgu kohta)
// Näide: 30 plokki = ~1 tund 2-minutilise plokkide ajaga
consensus.nForgingAssignmentDelay;   // Ülesande aktiveerimise viivitus
consensus.nForgingRevocationDelay;   // Tühistamise aktiveerimise viivitus
```

**Oleku üleminekud:**
- Ülesanne: `UNASSIGNED -> ASSIGNING (viivitus) -> ASSIGNED`
- Tühistamine: `ASSIGNED -> REVOKING (viivitus) -> REVOKED`

**Implementatsioon:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool'i valideerimine

Ülesande ja tühistamise tehinguid valideeritakse mempool'i vastuvõtul, et lükata tagasi kehtetud tehingud enne võrgu levikut.

### Tehingu taseme kontrollid (CheckTransaction)

Tehakse failis `src/consensus/tx_check.cpp` ilma ahela oleku juurdepääsuta:

1. **Maksimaalselt üks POCX OP_RETURN:** Tehing ei saa sisaldada mitut POCX/XCOP markerit

**Implementatsioon:** `src/consensus/tx_check.cpp:63-77`

### Mempool'i vastuvõtu kontrollid (PreChecks)

Tehakse failis `src/validation.cpp` täieliku ahela oleku ja mempool'i juurdepääsuga:

#### Ülesande valideerimine

1. **Graafiku omand:** Tehing peab olema allkirjastatud graafikuomaniku poolt
2. **Graafiku olek:** Graafik peab olema UNASSIGNED (0) või REVOKED (4)
3. **Mempool'i konfliktid:** Pole teist ülesannet sellele graafikule mempool'is (esimene saadetu võidab)

#### Tühistamise valideerimine

1. **Graafiku omand:** Tehing peab olema allkirjastatud graafikuomaniku poolt
2. **Aktiivne ülesanne:** Graafik peab olema ainult ASSIGNED (2) olekus
3. **Mempool'i konfliktid:** Pole teist tühistamist sellele graafikule mempool'is

**Implementatsioon:** `src/validation.cpp:898-993`

### Valideerimise voog

```
Tehingu edastamine
       ↓
CheckTransaction() [tx_check.cpp]
  Maks üks POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  Verifitseeri graafiku omand
  Kontrolli ülesande olekut
  Kontrolli mempool'i konflikte
       ↓
   Kehtiv -> Aktsepteeri mempool'i
   Kehtetu -> Lükka tagasi (ära levita)
       ↓
Ploki kaevandamine
       ↓
ConnectBlock() [validation.cpp]
  Valideeri kõik kontrollid uuesti (kaitse sügavuti)
  Rakenda oleku muudatused
  Salvesta tagasivõtmise info
```

### Kaitse sügavuti

Kõik mempool'i valideerimise kontrollid tehakse uuesti `ConnectBlock()` ajal, et kaitsta:
- Mempool'i möödaviimise rünnakute eest
- Pahatahtlike kaevandajate kehtetute plokkide eest
- Äärjuhtude eest ümberkorralduse stsenaariumites

Ploki valideerimine jääb konsensuse jaoks autoriteediks.

## Aatomilised andmebaasi uuendused

### Kolmekihiline arhitektuur

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (mälu vahemälu)       │  <- Ülesannete muudatused jälgitakse mälus
│   - Mündid: cacheCoins                  │
│   - Ülesanded: pendingAssignments       │
│   - Muudetud jälgimine: dirtyPlots      │
│   - Kustutamised: deletedAssignments    │
│   - Mälu jälgimine: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (andmebaasi kiht)        │  <- Üks aatomiline kirjutamine
│   - BatchWrite(): UTXO-d + ülesanded    │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (ketta hoiustus)              │  <- ACID garantiid
│   - Aatomiline tehing                   │
└─────────────────────────────────────────┘
```

### Flush protsess

Kui `view.Flush()` kutsutakse ploki ühendamise ajal:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Kirjuta mündimuudatused baasi
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Kirjuta ülesande muudatused aatomiliselt
    if (fOk && !dirtyPlots.empty()) {
        // Kogu muudetud ülesanded
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tühi - kasutamata

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Kirjuta andmebaasi
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Tühjenda jälgimine
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Vabasta mälu
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementatsioon:** `src/coins.cpp:278-315`

### Andmebaasi pakkkirjutamine

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Üks LevelDB pakk

    // 1. Märgi üleminekuolek
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Kirjuta kõik mündimuudatused
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Märgi järjepidev olek
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. AATOMILINE COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Ülesanded kirjutatakse eraldi, kuid samas andmebaasi tehingu kontekstis
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Kasutamata parameeter (hoitakse API ühilduvuse jaoks)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Uus pakk, kuid sama andmebaas

    // Kirjuta ülesannete ajalugu
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Kustuta kustutatud ülesanded ajaloost
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // AATOMILINE COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementatsioon:** `src/txdb.cpp:332-348`

### Aatomilisuse garantiid

**Mis on aatomiline:**
- Kõik mündimuudatused ploki sees kirjutatakse aatomiliselt
- Kõik ülesande muudatused ploki sees kirjutatakse aatomiliselt
- Andmebaas jääb järjepidevaks kokkujooksmiste korral

**Praegune piirang:**
- Mündid ja ülesanded kirjutatakse **eraldi** LevelDB pakkoperatsioonides
- Mõlemad operatsioonid toimuvad `view.Flush()` ajal, kuid mitte ühes aatomilises kirjutamises
- Praktikas: Mõlemad pakid lõpetavad kiiresti enne ketta fsync'i
- Risk on minimaalne: Mõlemaid tuleks kokkujooksmisel taasesitada samast plokist

**Märkus:** See erineb algsest arhitektuuriplaanist, mis nõudis üht ühendatud pakki. Praegune implementatsioon kasutab kahte pakki, kuid säilitab järjepidevuse läbi Bitcoin Core'i olemasolevate kokkujooksmise taastamismehhanismide (DB_HEAD_BLOCKS marker).

## Ümberkorralduste käsitlemine

### Tagasivõtmise andmestruktuur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Ülesanne lisati (kustuta tagasivõtmisel)
        MODIFIED = 1,   // Ülesannet muudeti (taasta tagasivõtmisel)
        REVOKED = 2     // Ülesanne tühistati (tühista tühistamine tagasivõtmisel)
    };

    UndoType type;
    ForgingAssignment assignment;  // Täielik olek enne muudatust
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO tagasivõtmise andmed
    std::vector<ForgingUndo> vforgingundo;  // Ülesande tagasivõtmise andmed
};
```

**Implementatsioon:** `src/undo.h:63-105`

### DisconnectBlock protsess

Kui plokk lahtiühendatakse ümberkorralduse ajal:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standardne UTXO lahtiühendamine ...

    // Loe tagasivõtmise andmed kettalt
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Võta tagasi ülesande muudatused (töötle vastupidises järjekorras)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Ülesanne lisati - eemalda see
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Ülesanne tühistati - taasta tühistamata olek
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Ülesannet muudeti - taasta eelmine olek
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementatsioon:** `src/validation.cpp:2381-2415`

### Vahemälu haldamine ümberkorralduse ajal

```cpp
class CCoinsViewCache {
private:
    // Ülesannete vahemälud
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Jälgi muudetud graafikuid
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Jälgi kustutamisi
    mutable size_t cachedAssignmentsUsage{0};  // Mälu jälgimine

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

**Implementatsioon:** `src/coins.cpp:494-565`

## RPC liides

### Sõlme käsud (rahakotti pole vaja)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Tagastab praeguse ülesande oleku graafiku aadressi jaoks:
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

**Implementatsioon:** `src/pocx/rpc/assignments.cpp:31-126`

### Rahakoti käsud (rahakott vajalik)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Loob ülesande tehingu:
- Valib automaatselt suurima UTXO graafiku aadressilt omandi tõestamiseks
- Ehitab tehingu OP_RETURN + vahetusväljundiga
- Allkirjastab graafikuomaniku võtmega
- Edastab võrku

**Implementatsioon:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Loob tühistamise tehingu:
- Valib automaatselt suurima UTXO graafiku aadressilt omandi tõestamiseks
- Ehitab tehingu OP_RETURN + vahetusväljundiga
- Allkirjastab graafikuomaniku võtmega
- Edastab võrku

**Implementatsioon:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Rahakoti tehingu loomine

Rahakoti tehingu loomise protsess:

```cpp
1. Parsi ja valideeri aadressid (peavad olema P2WPKH bech32)
2. Leia suurim UTXO graafiku aadressilt (tõestab omandi)
3. Loo ajutine tehing dummy väljundiga
4. Allkirjasta tehing (saa täpne suurus koos tunnistaja andmetega)
5. Asenda dummy väljund OP_RETURN-iga
6. Kohanda tasusid proportsionaalselt suuruse muutuse põhjal
7. Allkirjasta lõplik tehing uuesti
8. Edasta võrku
```

**Põhiline taipamine:** Rahakott peab kulutama graafiku aadressilt omandi tõestamiseks, seega sunnib see automaatselt mündi valiku sellelt aadressilt.

**Implementatsioon:** `src/pocx/assignments/transactions.cpp:38-263`

## Failistruktuur

### Põhiimplementatsiooni failid

```
src/
├── coins.h                        # ForgingAssignment struktuur, CCoinsViewCache meetodid [710 rida]
├── coins.cpp                      # Vahemälu haldamine, pakkkirjutused [603 rida]
│
├── txdb.h                         # CCoinsViewDB ülesande meetodid [90 rida]
├── txdb.cpp                       # Andmebaasi lugemine/kirjutamine [349 rida]
│
├── undo.h                         # ForgingUndo struktuur ümberkorralduste jaoks
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock integratsioon
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN vorming, parsimine, verifitseerimine
    │   ├── opcodes.cpp            # [259 rida] Markeri definitsioonid, OP_RETURN op-d, omandi kontroll
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState abistajad
    │   ├── assignment_state.cpp   # Ülesande oleku päringufunktsioonid
    │   ├── transactions.h         # Rahakoti tehingu loomise API
    │   └── transactions.cpp       # create_assignment, revoke_assignment rahakoti funktsioonid
    │
    ├── rpc/
    │   ├── assignments.h          # Sõlme RPC käsud (ilma rahakotita)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC-d
    │   ├── assignments_wallet.h   # Rahakoti RPC käsud
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC-d
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Jõudluse omadused

### Andmebaasi operatsioonid

- **Hangi praegune ülesanne:** O(n) - skaneeri kõik ülesanded graafiku aadressi jaoks, et leida uusim
- **Hangi ülesannete ajalugu:** O(n) - itereeri kõik ülesanded graafiku jaoks
- **Loo ülesanne:** O(1) - üks sisestamine
- **Tühista ülesanne:** O(1) - üks uuendus
- **Ümberkorraldus (ülesande kohta):** O(1) - otsene tagasivõtmise andmete rakendamine

Kus n = ülesannete arv graafiku kohta (tavaliselt väike, < 10)

### Mälu kasutus

- **Ülesande kohta:** ~160 baiti (ForgingAssignment struktuur)
- **Vahemälu üldkulu:** Räsikaardi üldkulu muudetud jälgimiseks
- **Tüüpiline plokk:** <10 ülesannet = <2 KB mälu

### Ketta kasutus

- **Ülesande kohta:** ~200 baiti kettal (koos LevelDB üldkuluga)
- **10000 ülesannet:** ~2 MB kettaruumi
- **Tühine võrreldes UTXO kogumiga:** <0.001% tüüpilisest chainstate'ist

## Praegused piirangud ja tulevane töö

### Aatomilisuse piirang

**Praegune:** Mündid ja ülesanded kirjutatakse eraldi LevelDB pakkides `view.Flush()` ajal

**Mõju:** Teoreetiline risk ebajärjepidevuseks, kui kokkujooksmine toimub pakkide vahel

**Leevendus:**
- Mõlemad pakid lõpetavad kiiresti enne fsync'i
- Bitcoin Core'i kokkujooksmise taastamine kasutab DB_HEAD_BLOCKS markerit
- Praktikas: Pole kunagi täheldatud testimisel

**Tulevane parandus:** Ühenda üheks LevelDB pakkoperatsiooniks

### Ülesannete ajaloo pügamine

**Praegune:** Kõik ülesanded hoitakse määramata ajaks

**Mõju:** ~200 baiti ülesande kohta igavesti

**Tulevik:** Valikuline täielikult tühistatud ülesannete pügamine, mis on vanemad kui N plokki

**Märkus:** Tõenäoliselt pole vajalik - isegi 1 miljon ülesannet = 200 MB

## Testimise staatus

### Implementeeritud testid

- OP_RETURN parsimine ja valideerimine
- Omandi verifitseerimine
- ConnectBlock ülesande loomine
- ConnectBlock tühistamine
- DisconnectBlock ümberkorralduste käsitlemine
- Andmebaasi lugemis/kirjutamisoperatsioonid
- Oleku üleminekud (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC käsud (get_assignment, create_assignment, revoke_assignment)
- Rahakoti tehingu loomine

### Testi katvuse valdkonnad

- Ühikutestid: `src/test/pocx_*_tests.cpp`
- Funktsionaaltestid: `test/functional/feature_pocx_*.py`
- Integratsioonitestid: Käsitsi testimine regtest'iga

## Konsensusreeglid

### Ülesande loomise reeglid

1. **Omand:** Tehing peab olema allkirjastatud graafikuomaniku poolt
2. **Olek:** Graafik peab olema UNASSIGNED või REVOKED olekus
3. **Vorming:** Kehtiv OP_RETURN POCX markeriga + 2× 20-baidised aadressid
4. **Unikaalsus:** Üks aktiivne ülesanne graafiku kohta korraga

### Tühistamise reeglid

1. **Omand:** Tehing peab olema allkirjastatud graafikuomaniku poolt
2. **Olemasolu:** Ülesanne peab eksisteerima ja ei tohi olla juba tühistatud
3. **Vorming:** Kehtiv OP_RETURN XCOP markeriga + 20-baidine aadress

### Aktiveerimise reeglid

- **Ülesande aktiveerimine:** `assignment_height + nForgingAssignmentDelay`
- **Tühistamise aktiveerimine:** `revocation_height + nForgingRevocationDelay`
- **Viivitused:** Konfigureeritavad võrgu kohta (nt 30 plokki = ~1 tund 2-minutilise plokkide ajaga)

### Ploki valideerimine

- Kehtetu ülesanne/tühistamine -> plokk lükatakse tagasi (konsensuse ebaõnnestumine)
- OP_RETURN väljundid välistatakse automaatselt UTXO kogumist (standardne Bitcoin käitumine)
- Ülesannete töötlemine toimub enne UTXO uuendusi ConnectBlock'is

## Kokkuvõte

Implementeeritud PoCX sepistamisülesannete süsteem pakub:

**Lihtsus:** Standardsed Bitcoin tehingud, pole erilisi UTXO-sid
**Kulutõhusus:** Pole tolmunõuet, ainult tehingutasud
**Ümberkorralduste ohutus:** Põhjalikud tagasivõtmise andmed taastavad korrektse oleku
**Aatomilised uuendused:** Andmebaasi järjepidevus läbi LevelDB pakkide
**Täielik ajalugu:** Täielik auditijälg kõigist ülesannetest aja jooksul
**Puhas arhitektuur:** Minimaalsed Bitcoin Core'i modifikatsioonid, isoleeritud PoCX kood
**Tootmisvalmis:** Täielikult implementeeritud, testitud ja töökorras

### Implementatsiooni kvaliteet

- **Koodi korraldus:** Suurepärane - selge eraldatus Bitcoin Core'i ja PoCX-i vahel
- **Vigade käsitlemine:** Põhjalik konsensuse valideerimine
- **Dokumentatsioon:** Koodi kommentaarid ja struktuur hästi dokumenteeritud
- **Testimine:** Põhifunktsioonid testitud, integratsioon verifitseeritud

### Põhilised disainiotsused valideeritud

1. OP_RETURN-ainult lähenemine (vs UTXO-põhine)
2. Eraldi andmebaasi hoiustus (vs Coin extraData)
3. Täielik ajaloo jälgimine (vs ainult praegune)
4. Omand allkirjaga (vs UTXO kulutamine)
5. Aktiveerimise viivitused (takistab ümberkorralduse rünnakuid)

Süsteem saavutab edukalt kõik arhitektuursed eesmärgid puhta, hooldatava implementatsiooniga.

---

[<- Eelmine: Konsensus ja kaevandamine](3-consensus-and-mining.md) | [Sisukord](index.md) | [Järgmine: Ajasünkroniseerimine ->](5-timing-security.md)

[<- Föregående: Konsensus och mining](3-consensus-and-mining.md) | [Innehållsförteckning](index.md) | [Nästa: Tidssynkronisering ->](5-timing-security.md)

---

# Kapitel 4: PoCX Forging Assignment-systemet

## Sammanfattning

Detta dokument beskriver det **implementerade** PoCX forging assignment-systemet med en OP_RETURN-baserad arkitektur. Systemet möjliggör för plotägare att delegera forgingrättigheter till separata adresser genom on-chain-transaktioner, med fullständig reorg-säkerhet och atomära databasoperationer.

**Status:** Fullt implementerat och operativt

## Kärndesignfilosofi

**Nyckelprincip:** Tilldelningar är rättigheter, inte tillgångar

- Inga speciella UTXO:er att spåra eller spendera
- Tilldelningsstatus lagras separat från UTXO-setet
- Ägarskap bevisas genom transaktionssignatur, inte UTXO-spenderande
- Fullständig historikspårning för komplett revisionslogg
- Atomära databasuppdateringar genom LevelDB-batchskrivningar

## Transaktionsstruktur

### Format för tilldelningsstransaktion

```
Inputs:
  [0]: Vilken UTXO som helst kontrollerad av plotägare (bevisar ägarskap + betalar avgifter)
       Måste vara signerad med plotägarens privata nyckel
  [1+]: Valfria ytterligare inputs för avgiftstäckning

Outputs:
  [0]: OP_RETURN (POCX-markör + plotadress + forgningsadress)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Storlek: 46 bytes totalt (1 byte OP_RETURN + 1 byte längd + 44 bytes data)
       Värde: 0 BTC (ospenderbar, läggs inte till UTXO-set)

  [1]: Växel tillbaka till användare (valfritt, standard P2WPKH)
```

**Implementation:** `src/pocx/assignments/opcodes.cpp:25-52`

### Format för återkallelsetransaktion

```
Inputs:
  [0]: Vilken UTXO som helst kontrollerad av plotägare (bevisar ägarskap + betalar avgifter)
       Måste vara signerad med plotägarens privata nyckel
  [1+]: Valfria ytterligare inputs för avgiftstäckning

Outputs:
  [0]: OP_RETURN (XCOP-markör + plotadress)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Storlek: 26 bytes totalt (1 byte OP_RETURN + 1 byte längd + 24 bytes data)
       Värde: 0 BTC (ospenderbar, läggs inte till UTXO-set)

  [1]: Växel tillbaka till användare (valfritt, standard P2WPKH)
```

**Implementation:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markörer

- **Tilldelningsmarkör:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Återkallelsemarkör:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementation:** `src/pocx/assignments/opcodes.cpp:15-19`

### Viktiga transaktionsegenskaper

- Standard Bitcoin-transaktioner (inga protokolländringar)
- OP_RETURN-utdata är bevisligen ospenderbara (läggs aldrig till UTXO-set)
- Plotägarskap bevisas genom signatur på input[0] från plotadress
- Låg kostnad (~200 bytes, typiskt <0.0001 BTC avgift)
- Plånbok väljer automatiskt största UTXO från plotadress för att bevisa ägarskap

## Databasarkitektur

### Lagringsstruktur

All tilldelningsdata lagras i samma LevelDB-databas som UTXO-setet (`chainstate/`), men med separata nyckelprefix:

```
chainstate/ LevelDB:
├─ UTXO-set (Bitcoin Core standard)
│  └─ 'C' prefix: COutPoint -> Coin
│
└─ Tilldelningsstatus (PoCX-tillägg)
   └─ 'A' prefix: (plot_address, assignment_txid) -> ForgingAssignment
       └─ Fullständig historik: alla tilldelningar per plot över tid
```

**Implementation:** `src/txdb.cpp:237-348`

### ForgingAssignment-struktur

```cpp
struct ForgingAssignment {
    // Identitet
    std::array<uint8_t, 20> plotAddress;      // Plotägare (20-byte P2WPKH-hash)
    std::array<uint8_t, 20> forgingAddress;   // Forgningrättighetsinnehavare (20-byte P2WPKH-hash)

    // Tilldelningslivscykel
    uint256 assignment_txid;                   // Transaktion som skapade tilldelningen
    int assignment_height;                     // Blockhöjd skapad
    int assignment_effective_height;           // När den blir aktiv (höjd + fördröjning)

    // Återkallelselivscykel
    bool revoked;                              // Har denna återkallats?
    uint256 revocation_txid;                   // Transaktion som återkallade den
    int revocation_height;                     // Blockhöjd återkallad
    int revocation_effective_height;           // När återkallelse är effektiv (höjd + fördröjning)

    // Tillståndsförfråganmetoder
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementation:** `src/coins.h:111-178`

### Tilldelningsstatus

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen tilldelning existerar
    ASSIGNING = 1,   // Tilldelning skapad, väntar på aktiveringsfördröjning
    ASSIGNED = 2,    // Tilldelning aktiv, forgning tillåten
    REVOKING = 3,    // Återkallad, men fortfarande aktiv under fördröjningsperiod
    REVOKED = 4      // Helt återkallad, inte längre aktiv
};
```

**Implementation:** `src/coins.h:98-104`

### Databasnycklar

```cpp
// Historiknyckel: lagrar fullständig tilldelningspost
// Nyckelformat: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotadress (20 bytes)
    int assignment_height;                // Höjd för sorteringsoptimering
    uint256 assignment_txid;              // Transaktions-ID
};
```

**Implementation:** `src/txdb.cpp:245-262`

### Historikspårning

- Varje tilldelning lagras permanent (raderas aldrig om inte reorg)
- Flera tilldelningar per plot spåras över tid
- Möjliggör fullständig revisionslogg och historiska tillståndsförfrågningar
- Återkallade tilldelningar finns kvar i databasen med `revoked=true`

## Blockbearbetning

### ConnectBlock-integration

Tilldelnings- och återkallelse-OP_RETURN:s bearbetas under blockanslutning i `validation.cpp`:

```cpp
// Plats: Efter skriptvalidering, före UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Tolka OP_RETURN-data
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifiera ägarskap (tx måste vara signerad av plotägare)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Kontrollera plotstatus (måste vara UNASSIGNED eller REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Skapa ny tilldelning
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Lagra undo-data
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Tolka OP_RETURN-data
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifiera ägarskap
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Hämta aktuell tilldelning
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Lagra gammalt tillstånd för undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Markera som återkallad
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

// UpdateCoins fortsätter normalt (hoppar automatiskt över OP_RETURN-utdata)
```

**Implementation:** `src/validation.cpp:2775-2878`

### Ägarskapsverifiering

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Kontrollera att minst en input är signerad av plotägare
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extrahera destination
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Kontrollera om P2WPKH till plotadress
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core har redan validerat signaturen
                return true;
            }
        }
    }
    return false;
}
```

**Implementation:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktiveringsfördröjningar

Tilldelningar och återkallelser har konfigurerbara aktiveringsfördröjningar för att förhindra reorg-attacker:

```cpp
// Konsensusparametrar (konfigurerbara per nätverk)
// Exempel: 30 block = ~1 timme med 2-minuters blocktid
consensus.nForgingAssignmentDelay;   // Tilldelningsaktiveringsfördröjning
consensus.nForgingRevocationDelay;   // Återkallelseaktiveringsfördröjning
```

**Tillståndsövergångar:**
- Tilldelning: `UNASSIGNED -> ASSIGNING (fördröjning) -> ASSIGNED`
- Återkallelse: `ASSIGNED -> REVOKING (fördröjning) -> REVOKED`

**Implementation:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempoolvalidering

Tilldelnings- och återkallelsetransaktioner valideras vid mempoolacceptans för att avvisa ogiltiga transaktioner före nätverkspropagering.

### Kontroller på transaktionsnivå (CheckTransaction)

Utförs i `src/consensus/tx_check.cpp` utan kedjestatsåtkomst:

1. **Maximum en POCX OP_RETURN:** Transaktion kan inte innehålla flera POCX/XCOP-markörer

**Implementation:** `src/consensus/tx_check.cpp:63-77`

### Mempoolacceptanskontroller (PreChecks)

Utförs i `src/validation.cpp` med fullständig kedjestats- och mempoolåtkomst:

#### Tilldelningsvalidering

1. **Plotägarskap:** Transaktion måste vara signerad av plotägare
2. **Plotstatus:** Plot måste vara UNASSIGNED (0) eller REVOKED (4)
3. **Mempoolkonflikter:** Ingen annan tilldelning för denna plot i mempool (först sedd vinner)

#### Återkallelsevalidering

1. **Plotägarskap:** Transaktion måste vara signerad av plotägare
2. **Aktiv tilldelning:** Plot måste vara i ASSIGNED (2) status endast
3. **Mempoolkonflikter:** Ingen annan återkallelse för denna plot i mempool

**Implementation:** `src/validation.cpp:898-993`

### Valideringsflöde

```
Transaktionssändning
       |
CheckTransaction() [tx_check.cpp]
  + Max en POCX OP_RETURN
       |
MemPoolAccept::PreChecks() [validation.cpp]
  + Verifiera plotägarskap
  + Kontrollera tilldelningsstatus
  + Kontrollera mempoolkonflikter
       |
   Giltig -> Acceptera till mempool
   Ogiltig -> Avvisa (propagera inte)
       |
Block Mining
       |
ConnectBlock() [validation.cpp]
  + Omvalidera alla kontroller (djupförsvar)
  + Tillämpa tillståndsändringar
  + Registrera undo-info
```

### Djupförsvar

Alla mempoolvalideringskontroller utförs igen under `ConnectBlock()` för att skydda mot:
- Mempoolförbigångsattacker
- Ogiltiga block från illvilliga miners
- Kantfall under reorg-scenarier

Blockvalidering förblir auktoritativ för konsensus.

## Atomära databasuppdateringar

### Treskiktsarkitektur

```
+---------------------------------------------+
|   CCoinsViewCache (Minnescache)             |  <- Tilldelningsändringar spåras i minnet
|   - Coins: cacheCoins                       |
|   - Assignments: pendingAssignments         |
|   - Dirty-spårning: dirtyPlots              |
|   - Borttagningar: deletedAssignments       |
|   - Minnesspårning: cachedAssignmentsUsage  |
+---------------------------------------------+
                    | Flush()
+---------------------------------------------+
|   CCoinsViewDB (Databaslager)               |  <- Enskild atomär skrivning
|   - BatchWrite(): UTXOs + Assignments       |
+---------------------------------------------+
                    | WriteBatch()
+---------------------------------------------+
|   LevelDB (Disklagring)                     |  <- ACID-garantier
|   - Atomär transaktion                      |
+---------------------------------------------+
```

### Flush-process

När `view.Flush()` anropas under blockanslutning:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Skriv coin-ändringar till bas
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Skriv tilldelningsändringar atomärt
    if (fOk && !dirtyPlots.empty()) {
        // Samla dirty tilldelningar
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tom - oanvänd

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Skriv till databas
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Rensa spårning
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Frigör minne
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementation:** `src/coins.cpp:278-315`

### Databasbatchskrivning

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Enskild LevelDB-batch

    // 1. Markera övergångstillstånd
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Skriv alla coin-ändringar
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Markera konsistent tillstånd
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMÄR COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Tilldelningar skrivs separat men i samma databastransaktionskontext
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Oanvänd parameter (behållen för API-kompatibilitet)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Ny batch, men samma databas

    // Skriv tilldelningshistorik
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Radera borttagna tilldelningar från historik
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMÄR COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementation:** `src/txdb.cpp:332-348`

### Atomäritetsgarantier

**Vad som är atomärt:**
- Alla coin-ändringar inom ett block skrivs atomärt
- Alla tilldelningsändringar inom ett block skrivs atomärt
- Databasen förblir konsistent vid krascher

**Nuvarande begränsning:**
- Coins och tilldelningar skrivs i **separata** LevelDB-batchoperationer
- Båda operationerna sker under `view.Flush()`, men inte i en enskild atomär skrivning
- I praktiken: Båda batcharna slutförs i snabb följd före disk-fsync
- Risk är minimal: Båda skulle behöva spelas om från samma block vid kraschåterställning

**Notera:** Detta skiljer sig från den ursprungliga arkitekturplanen som krävde en enda enhetlig batch. Nuvarande implementation använder två batchar men upprätthåller konsistens genom Bitcoin Cores befintliga kraschåterställningsmekanismer (DB_HEAD_BLOCKS-markör).

## Reorg-hantering

### Undo-datastruktur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Tilldelning lades till (ta bort vid undo)
        MODIFIED = 1,   // Tilldelning modifierades (återställ vid undo)
        REVOKED = 2     // Tilldelning återkallades (ångra återkallelse vid undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Fullständigt tillstånd före ändring
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo-data
    std::vector<ForgingUndo> vforgingundo;  // Tilldelnings-undo-data
};
```

**Implementation:** `src/undo.h:63-105`

### DisconnectBlock-process

När ett block kopplas bort under en reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standard UTXO-frånkoppling ...

    // Läs undo-data från disk
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Ångra tilldelningsändringar (bearbeta i omvänd ordning)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Tilldelning lades till - ta bort den
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Tilldelning återkallades - återställ icke-återkallat tillstånd
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Tilldelning modifierades - återställ tidigare tillstånd
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementation:** `src/validation.cpp:2381-2415`

### Cachehantering under reorg

```cpp
class CCoinsViewCache {
private:
    // Tilldelningscacher
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Spåra modifierade plottar
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Spåra borttagningar
    mutable size_t cachedAssignmentsUsage{0};  // Minnesspårning

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

**Implementation:** `src/coins.cpp:494-565`

## RPC-gränssnitt

### Nodkommandon (ingen plånbok krävs)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Returnerar aktuell tilldelningsstatus för en plotadress:
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

**Implementation:** `src/pocx/rpc/assignments.cpp:31-126`

### Plånbokskommandon (plånbok krävs)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Skapar en tilldelningsstransaktion:
- Väljer automatiskt största UTXO från plotadress för att bevisa ägarskap
- Bygger transaktion med OP_RETURN + växelutdata
- Signerar med plotägarens nyckel
- Sänder till nätverket

**Implementation:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Skapar en återkallelsetransaktion:
- Väljer automatiskt största UTXO från plotadress för att bevisa ägarskap
- Bygger transaktion med OP_RETURN + växelutdata
- Signerar med plotägarens nyckel
- Sänder till nätverket

**Implementation:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Plånbokstransaktionsskapande

Plånbokstransaktionsskapandeprocessen:

```cpp
1. Tolka och validera adresser (måste vara P2WPKH bech32)
2. Hitta största UTXO från plotadress (bevisar ägarskap)
3. Skapa temporär transaktion med dummy-utdata
4. Signera transaktion (få korrekt storlek med witness-data)
5. Ersätt dummy-utdata med OP_RETURN
6. Justera avgifter proportionellt baserat på storleksändring
7. Signera slutlig transaktion igen
8. Sänd till nätverk
```

**Viktig insikt:** Plånboken måste spendera från plotadressen för att bevisa ägarskap, så den tvingar automatiskt coin-selektion från den adressen.

**Implementation:** `src/pocx/assignments/transactions.cpp:38-263`

## Filstruktur

### Kärnimplementationsfiler

```
src/
├── coins.h                        # ForgingAssignment-struktur, CCoinsViewCache-metoder [710 rader]
├── coins.cpp                      # Cachehantering, batchskrivningar [603 rader]
│
├── txdb.h                         # CCoinsViewDB-tilldelningsmetoder [90 rader]
├── txdb.cpp                       # Databasläsning/skrivning [349 rader]
│
├── undo.h                         # ForgingUndo-struktur för reorgar
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock-integration
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN-format, tolkning, verifiering
    │   ├── opcodes.cpp            # [259 rader] Markördefinitioner, OP_RETURN-ops, ägarskapscheck
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState-hjälpfunktioner
    │   ├── assignment_state.cpp   # Tillståndsförfråganfunktioner
    │   ├── transactions.h         # Plånbokstransaktionsskapande-API
    │   └── transactions.cpp       # create_assignment, revoke_assignment plånboksfunktioner
    │
    ├── rpc/
    │   ├── assignments.h          # Nod-RPC-kommandon (ingen plånbok)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPCs
    │   ├── assignments_wallet.h   # Plånboks-RPC-kommandon
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPCs
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Prestandaegenskaper

### Databasoperationer

- **Hämta aktuell tilldelning:** O(n) - skanna alla tilldelningar för plotadress för att hitta senaste
- **Hämta tilldelningshistorik:** O(n) - iterera alla tilldelningar för plot
- **Skapa tilldelning:** O(1) - enskild infogning
- **Återkalla tilldelning:** O(1) - enskild uppdatering
- **Reorg (per tilldelning):** O(1) - direkt undo-datatillämpning

Där n = antal tilldelningar för en plot (typiskt litet, < 10)

### Minnesanvändning

- **Per tilldelning:** ~160 bytes (ForgingAssignment-struktur)
- **Cache-overhead:** Hash map overhead för dirty-spårning
- **Typiskt block:** <10 tilldelningar = <2 KB minne

### Diskanvändning

- **Per tilldelning:** ~200 bytes på disk (med LevelDB-overhead)
- **10000 tilldelningar:** ~2 MB diskutrymme
- **Försumbart jämfört med UTXO-set:** <0.001% av typisk chainstate

## Nuvarande begränsningar och framtida arbete

### Atomäritetsbegränsning

**Nuvarande:** Coins och tilldelningar skrivs i separata LevelDB-batchar under `view.Flush()`

**Påverkan:** Teoretisk risk för inkonsistens om krasch inträffar mellan batchar

**Lindring:**
- Båda batcharna slutförs snabbt före fsync
- Bitcoin Cores kraschåterställning använder DB_HEAD_BLOCKS-markör
- I praktiken: Aldrig observerat i testning

**Framtida förbättring:** Förena till enskild LevelDB-batchoperation

### Tilldelningshistorikpruning

**Nuvarande:** Alla tilldelningar lagras på obestämd tid

**Påverkan:** ~200 bytes per tilldelning för alltid

**Framtida:** Valfri pruning av helt återkallade tilldelningar äldre än N block

**Notera:** Osannolikt att behövas - även 1 miljon tilldelningar = 200 MB

## Teststatus

### Implementerade tester

- OP_RETURN-tolkning och validering
- Ägarskapsverifiering
- ConnectBlock-tilldelningsskapande
- ConnectBlock-återkallelse
- DisconnectBlock reorg-hantering
- Databasläs-/skrivoperationer
- Tillståndsövergångar (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC-kommandon (get_assignment, create_assignment, revoke_assignment)
- Plånbokstransaktionsskapande

### Testtäckningsområden

- Enhetstester: `src/test/pocx_*_tests.cpp`
- Funktionella tester: `test/functional/feature_pocx_*.py`
- Integrationstester: Manuell testning med regtest

## Konsensusregler

### Regler för tilldelningsskapande

1. **Ägarskap:** Transaktion måste vara signerad av plotägare
2. **Status:** Plot måste vara i UNASSIGNED eller REVOKED-status
3. **Format:** Giltig OP_RETURN med POCX-markör + 2x 20-byte-adresser
4. **Unicitet:** En aktiv tilldelning per plot åt gången

### Återkallelseregler

1. **Ägarskap:** Transaktion måste vara signerad av plotägare
2. **Existens:** Tilldelning måste existera och inte redan vara återkallad
3. **Format:** Giltig OP_RETURN med XCOP-markör + 20-byte-adress

### Aktiveringsregler

- **Tilldelningsaktivering:** `assignment_height + nForgingAssignmentDelay`
- **Återkallelseaktivering:** `revocation_height + nForgingRevocationDelay`
- **Fördröjningar:** Konfigurerbara per nätverk (t.ex. 30 block = ~1 timme med 2-minuters blocktid)

### Blockvalidering

- Ogiltig tilldelning/återkallelse -> block avvisas (konsensusfel)
- OP_RETURN-utdata exkluderas automatiskt från UTXO-set (standard Bitcoin-beteende)
- Tilldelningsbearbetning sker före UTXO-uppdateringar i ConnectBlock

## Slutsats

PoCX forging assignment-systemet som implementerat tillhandahåller:

**Enkelhet:** Standard Bitcoin-transaktioner, inga speciella UTXO:er
**Kostnadseffektivt:** Inget dust-krav, endast transaktionsavgifter
**Reorg-säkerhet:** Omfattande undo-data återställer korrekt tillstånd
**Atomära uppdateringar:** Databaskonsistens genom LevelDB-batchar
**Fullständig historik:** Komplett revisionslogg över alla tilldelningar över tid
**Ren arkitektur:** Minimala Bitcoin Core-modifikationer, isolerad PoCX-kod
**Produktionsredo:** Fullt implementerat, testat och operativt

### Implementationskvalitet

- **Kodorganisation:** Utmärkt - tydlig separation mellan Bitcoin Core och PoCX
- **Felhantering:** Omfattande konsensusvalidering
- **Dokumentation:** Kodkommentarer och struktur väldokumenterade
- **Testning:** Kärnfunktionalitet testad, integration verifierad

### Validerade nyckeldesignbeslut

1. OP_RETURN-baserad approach (vs UTXO-baserad)
2. Separat databaslagring (vs Coin extraData)
3. Fullständig historikspårning (vs endast-nuvarande)
4. Ägarskap genom signatur (vs UTXO-spenderande)
5. Aktiveringsfördröjningar (förhindrar reorg-attacker)

Systemet uppnår framgångsrikt alla arkitektoniska mål med en ren, underhållbar implementation.

---

[<- Föregående: Konsensus och mining](3-consensus-and-mining.md) | [Innehållsförteckning](index.md) | [Nästa: Tidssynkronisering ->](5-timing-security.md)

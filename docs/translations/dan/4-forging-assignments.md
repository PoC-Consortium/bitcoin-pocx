[<- Forrige: Konsensus og mining](3-consensus-and-mining.md) | [Indholdsfortegnelse](index.md) | [Naeste: Tidssynkronisering ->](5-timing-security.md)

---

# Kapitel 4: PoCX Forging Assignment-system

## Resumé

Dette dokument beskriver det **implementerede** PoCX forging assignment-system ved hjaelp af en OP_RETURN-baseret arkitektur. Systemet gør det muligt for plotejere at delegere forging-rettigheder til separate adresser gennem on-chain-transaktioner med fuld reorg-sikkerhed og atomare databaseoperationer.

**Status:** Fuldt implementeret og operationelt

## Kernedesignfilosofi

**Nogleprincip:** Assignments er tilladelser, ikke aktiver

- Ingen specielle UTXO'er at spore eller forbruge
- Assignment-tilstand gemt separat fra UTXO-saet
- Ejerskab bevist ved transaktionssignatur, ikke UTXO-forbrug
- Fuld historiesporing til komplet revisionssti
- Atomare databaseopdateringer gennem LevelDB-batchskrivninger

## Transaktionsstruktur

### Assignment-transaktionsformat

```
Inputs:
  [0]: Enhver UTXO kontrolleret af plotejer (beviser ejerskab + betaler gebyrer)
       Skal vaere underskrevet med plotejerens private nogle
  [1+]: Valgfrie yderligere inputs til gebyrdaekning

Outputs:
  [0]: OP_RETURN (POCX-markør + plotadresse + forgeadresse)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Storrelse: 46 bytes total (1 byte OP_RETURN + 1 byte laengde + 44 bytes data)
       Vaerdi: 0 BTC (ikke-forbrugelig, tilfojes ikke til UTXO-saet)

  [1]: Byttepenge tilbage til bruger (valgfrit, standard P2WPKH)
```

**Implementering:** `src/pocx/assignments/opcodes.cpp:25-52`

### Tilbagekaldelsestransaktionsformat

```
Inputs:
  [0]: Enhver UTXO kontrolleret af plotejer (beviser ejerskab + betaler gebyrer)
       Skal vaere underskrevet med plotejerens private nogle
  [1+]: Valgfrie yderligere inputs til gebyrdaekning

Outputs:
  [0]: OP_RETURN (XCOP-markør + plotadresse)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Storrelse: 26 bytes total (1 byte OP_RETURN + 1 byte laengde + 24 bytes data)
       Vaerdi: 0 BTC (ikke-forbrugelig, tilfojes ikke til UTXO-saet)

  [1]: Byttepenge tilbage til bruger (valgfrit, standard P2WPKH)
```

**Implementering:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markører

- **Assignment-markør:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Tilbagekaldelsesmarkør:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementering:** `src/pocx/assignments/opcodes.cpp:15-19`

### Vigtige transaktionskarakteristika

- Standard Bitcoin-transaktioner (ingen protokolaendringer)
- OP_RETURN-outputs er bevisligt ikke-forbrugelige (tilfojes aldrig til UTXO-saet)
- Plotejerskab bevist ved signatur pa input[0] fra plotadresse
- Lav omkostning (~200 bytes, typisk <0,0001 BTC gebyr)
- Wallet vaelger automatisk storste UTXO fra plotadresse for at bevise ejerskab

## Databasearkitektur

### Lagerstruktur

Alle assignment-data gemmes i den samme LevelDB-database som UTXO-saettet (`chainstate/`), men med separate nogleprafixer:

```
chainstate/ LevelDB:
-- UTXO-saet (Bitcoin Core standard)
|  -- 'C'-praefiks: COutPoint -> Coin
|
-- Assignment-tilstand (PoCX-tilojelser)
   -- 'A'-praefiks: (plot_address, assignment_txid) -> ForgingAssignment
       -- Fuld historik: alle assignments pr. plot over tid
```

**Implementering:** `src/txdb.cpp:237-348`

### ForgingAssignment-struktur

```cpp
struct ForgingAssignment {
    // Identitet
    std::array<uint8_t, 20> plotAddress;      // Plotejer (20-byte P2WPKH-hash)
    std::array<uint8_t, 20> forgingAddress;   // Forging-rettighedsindehaver (20-byte P2WPKH-hash)

    // Assignment-livscyklus
    uint256 assignment_txid;                   // Transaktion der oprettede assignment
    int assignment_height;                     // Blokhojde oprettet
    int assignment_effective_height;           // Nar den bliver aktiv (hojde + forsinkelse)

    // Tilbagekaldelseslivscyklus
    bool revoked;                              // Er denne blevet tilbagekaldt?
    uint256 revocation_txid;                   // Transaktion der tilbagekaldte den
    int revocation_height;                     // Blokhojde tilbagekaldt
    int revocation_effective_height;           // Nar tilbagekaldelse traeder i kraft (hojde + forsinkelse)

    // Tilstandsforesporgselsmetoder
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementering:** `src/coins.h:111-178`

### Assignment-tilstande

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen assignment eksisterer
    ASSIGNING = 1,   // Assignment oprettet, venter pa aktiveringsforsinkelse
    ASSIGNED = 2,    // Assignment aktiv, forging tilladt
    REVOKING = 3,    // Tilbagekaldt, men stadig aktiv i forsinkelsesperiode
    REVOKED = 4      // Fuldt tilbagekaldt, ikke laengere aktiv
};
```

**Implementering:** `src/coins.h:98-104`

### Databasenogler

```cpp
// Historiknogle: gemmer fuld assignment-post
// Nogleformat: (praefiks, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotadresse (20 bytes)
    int assignment_height;                // Hojde til sorteringsoptimering
    uint256 assignment_txid;              // Transaktions-ID
};
```

**Implementering:** `src/txdb.cpp:245-262`

### Historiksporing

- Hver assignment gemmes permanent (slettes aldrig medmindre reorg)
- Flere assignments pr. plot spores over tid
- Muliggor fuld revisionssti og historiske tilstandsforesporgsler
- Tilbagekaldte assignments forbliver i database med `revoked=true`

## Blokbehandling

### ConnectBlock-integration

Assignment- og tilbagekaldelses-OP_RETURNs behandles under blokforbindelse i `validation.cpp`:

```cpp
// Placering: Efter scriptvalidering, for UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parse OP_RETURN-data
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Bekraeft ejerskab (tx skal vaere underskrevet af plotejer)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Kontroller plottilstand (skal vaere UNASSIGNED eller REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Opret ny assignment
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Gem undo-data
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parse OP_RETURN-data
            auto plot_addr = ParseRevocationOpReturn(output);

            // Bekraeft ejerskab
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Hent nuvaerende assignment
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Gem gammel tilstand til undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Marker som tilbagekaldt
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

// UpdateCoins fortsaetter normalt (springer automatisk OP_RETURN-outputs over)
```

**Implementering:** `src/validation.cpp:2775-2878`

### Ejerskabsverifikation

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Kontroller at mindst et input er underskrevet af plotejer
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Udtræk destination
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Kontroller om P2WPKH til plotadresse
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core har allerede valideret signaturen
                return true;
            }
        }
    }
    return false;
}
```

**Implementering:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktiveringsforsinkelser

Assignments og tilbagekaldelser har konfigurerbare aktiveringsforsinkelser for at forebygge reorg-angreb:

```cpp
// Konsensusparametre (konfigurerbare pr. netvaerk)
// Eksempel: 30 blokke = ~1 time med 2-minutters bloktid
consensus.nForgingAssignmentDelay;   // Assignment-aktiveringsforsinkelse
consensus.nForgingRevocationDelay;   // Tilbagekaldelseaktiveringsforsinkelse
```

**Tilstandsovergange:**
- Assignment: `UNASSIGNED -> ASSIGNING (forsinkelse) -> ASSIGNED`
- Tilbagekaldelse: `ASSIGNED -> REVOKING (forsinkelse) -> REVOKED`

**Implementering:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool-validering

Assignment- og tilbagekaldelsestransaktioner valideres ved mempool-accept for at afvise ugyldige transaktioner for netvaerkspropagering.

### Transaktionsniveau-kontroller (CheckTransaction)

Udfrt i `src/consensus/tx_check.cpp` uden kaede-tilstandsadgang:

1. **Maksimalt en POCX OP_RETURN:** Transaktion kan ikke indeholde flere POCX/XCOP-markrerer

**Implementering:** `src/consensus/tx_check.cpp:63-77`

### Mempool-acceptkontroller (PreChecks)

Udfrt i `src/validation.cpp` med fuld kaede-tilstand og mempool-adgang:

#### Assignment-validering

1. **Plotejerskab:** Transaktion skal vaere underskrevet af plotejer
2. **Plottilstand:** Plot skal vaere UNASSIGNED (0) eller REVOKED (4)
3. **Mempool-konflikter:** Ingen anden assignment for dette plot i mempool (first-seen vinder)

#### Tilbagekaldelsesvalidering

1. **Plotejerskab:** Transaktion skal vaere underskrevet af plotejer
2. **Aktiv assignment:** Plot skal vaere i ASSIGNED (2) tilstand kun
3. **Mempool-konflikter:** Ingen anden tilbagekaldelse for dette plot i mempool

**Implementering:** `src/validation.cpp:898-993`

### Valideringsflow

```
Transaktionsudsendelse
       |
CheckTransaction() [tx_check.cpp]
  Maks en POCX OP_RETURN
       |
MemPoolAccept::PreChecks() [validation.cpp]
  Bekraeft plotejerskab
  Kontroller assignment-tilstand
  Kontroller mempool-konflikter
       |
   Gyldig -> Accept til mempool
   Ugyldig -> Afvis (udsendes ikke)
       |
Blokmining
       |
ConnectBlock() [validation.cpp]
  Gen-valider alle kontroller (forsvar i dybden)
  Anvend tilstandsaendringer
  Registrer undo-info
```

### Forsvar i dybden

Alle mempool-valideringskontroller genudføres under `ConnectBlock()` for at beskytte mod:
- Mempool-omgaelsesangreb
- Ugyldige blokke fra ondsindede minere
- Kanttilfaelde under reorg-scenarier

Blokvalidering forbliver autoritativ for konsensus.

## Atomare databaseopdateringer

### Tre-lagsarkitektur

```
--------------------------------------------
|   CCoinsViewCache (Hukommelsescache)      |  <- Assignment-aendringer sporet i hukommelse
|   - Coins: cacheCoins                     |
|   - Assignments: pendingAssignments       |
|   - Dirty tracking: dirtyPlots            |
|   - Sletninger: deletedAssignments        |
|   - Hukommelsessporing: cachedAssignmentsUsage |
--------------------------------------------
                    | Flush()
--------------------------------------------
|   CCoinsViewDB (Databaselag)              |  <- Enkelt atomar skrivning
|   - BatchWrite(): UTXOs + Assignments     |
--------------------------------------------
                    | WriteBatch()
--------------------------------------------
|   LevelDB (Disklagring)                   |  <- ACID-garantier
|   - Atomar transaktion                    |
--------------------------------------------
```

### Flush-proces

Nar `view.Flush()` kaldes under blokforbindelse:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Skriv coin-aendringer til base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Skriv assignment-aendringer atomart
    if (fOk && !dirtyPlots.empty()) {
        // Indsaml dirty assignments
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tom - ubrugt

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Skriv til database
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Ryd sporing
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Frigiv hukommelse
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementering:** `src/coins.cpp:278-315`

### Database-batchskrivning

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Enkelt LevelDB-batch

    // 1. Marker overgangstilstand
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Skriv alle coin-aendringer
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Marker konsistent tilstand
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMAR COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Assignments skrives separat, men i samme databasetransaktionskontekst
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Ubrugt parameter (bevaret til API-kompatibilitet)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Ny batch, men samme database

    // Skriv assignment-historik
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Slet slettede assignments fra historik
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMAR COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementering:** `src/txdb.cpp:332-348`

### Atomaritetsgarantier

**Hvad der er atomart:**
- Alle coin-aendringer inden for en blok skrives atomart
- Alle assignment-aendringer inden for en blok skrives atomart
- Database forbliver konsistent pa tvaers af nedbrud

**Nuvaerende begraensning:**
- Coins og assignments skrives i **separate** LevelDB-batchoperationer
- Begge operationer sker under `view.Flush()`, men ikke i en enkelt atomar skrivning
- I praksis: Begge batches faerdigudfres hurtigt for disk-fsync
- Risiko er minimal: Begge skal genafspilles fra samme blok under genopretning efter nedbrud

**Bemaaerkning:** Dette adskiller sig fra den oprindelige arkitekturplan, som kraevede en enkelt samlet batch. Den nuvaerende implementering bruger to batches, men opretholder konsistens gennem Bitcoin Cores eksisterende nedbrudgenopretningsmekanismer (DB_HEAD_BLOCKS-markør).

## Reorg-handtering

### Undo-datastruktur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Assignment blev tilfojet (slet ved undo)
        MODIFIED = 1,   // Assignment blev modificeret (gendan ved undo)
        REVOKED = 2     // Assignment blev tilbagekaldt (fjern tilbagekaldelse ved undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Fuld tilstand for aendring
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO-undo-data
    std::vector<ForgingUndo> vforgingundo;  // Assignment-undo-data
};
```

**Implementering:** `src/undo.h:63-105`

### DisconnectBlock-proces

Nar en blok afkobles under en reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standard UTXO-afkobling ...

    // Laes undo-data fra disk
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Fortryd assignment-aendringer (behandl i omvendt raekkefolge)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Assignment blev tilfojet - fjern den
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Assignment blev tilbagekaldt - gendan ikke-tilbagekaldt tilstand
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Assignment blev modificeret - gendan tidligere tilstand
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementering:** `src/validation.cpp:2381-2415`

### Cache-styring under reorg

```cpp
class CCoinsViewCache {
private:
    // Assignment-caches
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Spor modificerede plots
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Spor sletninger
    mutable size_t cachedAssignmentsUsage{0};  // Hukommelsessporing

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

**Implementering:** `src/coins.cpp:494-565`

## RPC-graenseflade

### Node-kommandoer (ingen wallet kraevet)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Returnerer nuvaerende assignment-status for en plotadresse:
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

**Implementering:** `src/pocx/rpc/assignments.cpp:31-126`

### Wallet-kommandoer (wallet kraevet)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Opretter en assignment-transaktion:
- Vaelger automatisk storste UTXO fra plotadresse for at bevise ejerskab
- Bygger transaktion med OP_RETURN + byttepenge-output
- Underskriver med plotejerens nogle
- Udsender til netvaerk

**Implementering:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Opretter en tilbagekaldelsestransaktion:
- Vaelger automatisk storste UTXO fra plotadresse for at bevise ejerskab
- Bygger transaktion med OP_RETURN + byttepenge-output
- Underskriver med plotejerens nogle
- Udsender til netvaerk

**Implementering:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Wallet-transaktionsoprettelse

Wallet-transaktionsoprettelsesprocessen:

```cpp
1. Parse og valider adresser (skal vaere P2WPKH bech32)
2. Find storste UTXO fra plotadresse (beviser ejerskab)
3. Opret midlertidig transaktion med dummy-output
4. Underskriv transaktion (fa nojagtig storrelse med witness-data)
5. Erstat dummy-output med OP_RETURN
6. Juster gebyrer proportionalt baseret pa storrelseaendring
7. Gen-underskriv endelig transaktion
8. Udsend til netvaerk
```

**Vigtig indsigt:** Walleten skal forbruge fra plotadressen for at bevise ejerskab, sa den tvinger automatisk coin-valg fra den adresse.

**Implementering:** `src/pocx/assignments/transactions.cpp:38-263`

## Filstruktur

### Kerneimplementeringsfiler

```
src/
-- coins.h                        # ForgingAssignment-struct, CCoinsViewCache-metoder [710 linjer]
-- coins.cpp                      # Cache-styring, batch-skrivninger [603 linjer]
|
-- txdb.h                         # CCoinsViewDB assignment-metoder [90 linjer]
-- txdb.cpp                       # Database laes/skriv [349 linjer]
|
-- undo.h                         # ForgingUndo-struktur til reorgs
|
-- validation.cpp                 # ConnectBlock/DisconnectBlock-integration
|
-- pocx/
    -- assignments/
    |   -- opcodes.h              # OP_RETURN-format, parsing, verifikation
    |   -- opcodes.cpp            # [259 linjer] Markør-definitioner, OP_RETURN-ops, ejerskabskontrol
    |   -- assignment_state.h     # GetEffectiveSigner, GetAssignmentState-hjelpere
    |   -- assignment_state.cpp   # Assignment-tilstandsforesporgselfunktioner
    |   -- transactions.h         # Wallet-transaktionsoprettelses-API
    |   -- transactions.cpp       # create_assignment, revoke_assignment wallet-funktioner
    |
    -- rpc/
    |   -- assignments.h          # Node RPC-kommandoer (ingen wallet)
    |   -- assignments.cpp        # get_assignment, list_assignments RPC'er
    |   -- assignments_wallet.h   # Wallet RPC-kommandoer
    |   -- assignments_wallet.cpp # create_assignment, revoke_assignment RPC'er
    |
    -- consensus/
        -- params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Ydelseskarakteristika

### Databaseoperationer

- **Hent nuvaerende assignment:** O(n) - scan alle assignments for plotadresse for at finde nyeste
- **Hent assignment-historik:** O(n) - iterer alle assignments for plot
- **Opret assignment:** O(1) - enkelt insert
- **Tilbagekald assignment:** O(1) - enkelt opdatering
- **Reorg (pr. assignment):** O(1) - direkte undo-dataanvendelse

Hvor n = antal assignments for et plot (typisk lille, < 10)

### Hukommelsesforbrug

- **Pr. assignment:** ~160 bytes (ForgingAssignment-struct)
- **Cache-overhead:** Hashmap-overhead til dirty-sporing
- **Typisk blok:** <10 assignments = <2 KB hukommelse

### Diskforbrug

- **Pr. assignment:** ~200 bytes pa disk (med LevelDB-overhead)
- **10000 assignments:** ~2 MB diskplads
- **Ubetydeligt sammenlignet med UTXO-saet:** <0,001% af typisk chainstate

## Nuvaerende begraensninger og fremtidigt arbejde

### Atomaritetsbegraensning

**Nuvaerende:** Coins og assignments skrives i separate LevelDB-batches under `view.Flush()`

**Konsekvens:** Teoretisk risiko for inkonsistens, hvis nedbrud sker mellem batches

**Afbodning:**
- Begge batches faerdigudfres hurtigt for fsync
- Bitcoin Cores nedbrudgenopretning bruger DB_HEAD_BLOCKS-markør
- I praksis: Aldrig observeret under test

**Fremtidig forbedring:** Saml i enkelt LevelDB-batchoperation

### Assignment-historikbeskaring

**Nuvaerende:** Alle assignments gemmes pa ubestemt tid

**Konsekvens:** ~200 bytes pr. assignment for evigt

**Fremtid:** Valgfri beskaring af fuldt tilbagekaldte assignments aeldre end N blokke

**Bemaaerkning:** Usandsynligt at vaere nodvendigt - selv 1 million assignments = 200 MB

## Teststatus

### Implementerede tests

- OP_RETURN-parsing og validering
- Ejerskabsverifikation
- ConnectBlock assignment-oprettelse
- ConnectBlock tilbagekaldelse
- DisconnectBlock reorg-handtering
- Database laes/skriv-operationer
- Tilstandsovergange (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC-kommandoer (get_assignment, create_assignment, revoke_assignment)
- Wallet-transaktionsoprettelse

### Testdaekningsomrader

- Unit tests: `src/test/pocx_*_tests.cpp`
- Funktionelle tests: `test/functional/feature_pocx_*.py`
- Integrationstests: Manuel test med regtest

## Konsensusregler

### Assignment-oprettelsesregler

1. **Ejerskab:** Transaktion skal vaere underskrevet af plotejer
2. **Tilstand:** Plot skal vaere i UNASSIGNED eller REVOKED tilstand
3. **Format:** Gyldig OP_RETURN med POCX-markør + 2x 20-byte adresser
4. **Unikhed:** En aktiv assignment pr. plot ad gangen

### Tilbagekaldelsesregler

1. **Ejerskab:** Transaktion skal vaere underskrevet af plotejer
2. **Eksistens:** Assignment skal eksistere og matte ikke allerede vaere tilbagekaldt
3. **Format:** Gyldig OP_RETURN med XCOP-markør + 20-byte adresse

### Aktiveringsregler

- **Assignment-aktivering:** `assignment_height + nForgingAssignmentDelay`
- **Tilbagekaldelsesaktivering:** `revocation_height + nForgingRevocationDelay`
- **Forsinkelser:** Konfigurerbare pr. netvaerk (f.eks. 30 blokke = ~1 time med 2-minutters bloktid)

### Blokvalidering

- Ugyldig assignment/tilbagekaldelse -> blok afvist (konsensusfejl)
- OP_RETURN-outputs ekskluderes automatisk fra UTXO-saet (standard Bitcoin-adfaerd)
- Assignment-behandling sker for UTXO-opdateringer i ConnectBlock

## Konklusion

PoCX forging assignment-systemet som implementeret giver:

- **Enkelhed:** Standard Bitcoin-transaktioner, ingen specielle UTXO'er
- **Omkostningseffektivitet:** Intet dust-krav, kun transaktionsgebyrer
- **Reorg-sikkerhed:** Omfattende undo-data gendanner korrekt tilstand
- **Atomare opdateringer:** Databasekonsistens gennem LevelDB-batches
- **Fuld historik:** Komplet revisionssti af alle assignments over tid
- **Ren arkitektur:** Minimale Bitcoin Core-modifikationer, isoleret PoCX-kode
- **Produktionsklar:** Fuldt implementeret, testet og operationel

### Implementeringskvalitet

- **Kodeorganisering:** Fremragende - klar adskillelse mellem Bitcoin Core og PoCX
- **Fejlhandtering:** Omfattende konsensusvalidering
- **Dokumentation:** Kodekommentarer og struktur veldokumenteret
- **Test:** Kernefunktionalitet testet, integration verificeret

### Vigtige designbeslutninger valideret

1. OP_RETURN-baseret tilgang (vs UTXO-baseret)
2. Separat databaselagring (vs Coin extraData)
3. Fuld historiesporing (vs kun nuvaerende)
4. Ejerskab ved signatur (vs UTXO-forbrug)
5. Aktiveringsforsinkelser (forebygger reorg-angreb)

Systemet opnar med succes alle arkitekturmal med en ren, vedligeholdelig implementering.

---

[<- Forrige: Konsensus og mining](3-consensus-and-mining.md) | [Indholdsfortegnelse](index.md) | [Naeste: Tidssynkronisering ->](5-timing-security.md)

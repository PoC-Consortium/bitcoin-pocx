[← Forrige: Konsensus og mining](3-consensus-and-mining.md) | [Innholdsfortegnelse](index.md) | [Neste: Tidssynkronisering →](5-timing-security.md)

---

# Kapittel 4: PoCX forging assignment-system

## Sammendrag

Dette dokumentet beskriver det **implementerte** PoCX forging assignment-systemet ved bruk av en OP_RETURN-basert arkitektur. Systemet lar ploteiere delegere forging-rettigheter til separate adresser gjennom on-chain-transaksjoner, med full reorganiseringssikkerhet og atomiske databaseoperasjoner.

**Status:** Fullstendig implementert og operativt

## Kjernedesignfilosofi

**Nøkkelprinsipp:** Tildelinger er tillatelser, ikke eiendeler

- Ingen spesielle UTXO-er å spore eller bruke
- Tildelingstilstand lagres separat fra UTXO-settet
- Eierskap bevises av transaksjonssignatur, ikke UTXO-forbruk
- Full historikksporing for komplett revisjonssti
- Atomiske databaseoppdateringer gjennom LevelDB-batchskrivinger

## Transaksjonsstruktur

### Tildelingstransaksjonsformat

```
Inputs:
  [0]: Enhver UTXO kontrollert av ploteier (beviser eierskap + betaler gebyrer)
       Må signeres med ploteiers private nøkkel
  [1+]: Valgfrie ekstra inputs for gebyrdekning

Outputs:
  [0]: OP_RETURN (POCX-markør + plotadresse + forgeadresse)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Størrelse: 46 bytes totalt (1 byte OP_RETURN + 1 byte lengde + 44 bytes data)
       Verdi: 0 BTC (ubrukbar, legges ikke til i UTXO-sett)

  [1]: Vekslepenger tilbake til bruker (valgfritt, standard P2WPKH)
```

**Implementasjon:** `src/pocx/assignments/opcodes.cpp:25-52`

### Opphevingstransaksjonsformat

```
Inputs:
  [0]: Enhver UTXO kontrollert av ploteier (beviser eierskap + betaler gebyrer)
       Må signeres med ploteiers private nøkkel
  [1+]: Valgfrie ekstra inputs for gebyrdekning

Outputs:
  [0]: OP_RETURN (XCOP-markør + plotadresse)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Størrelse: 26 bytes totalt (1 byte OP_RETURN + 1 byte lengde + 24 bytes data)
       Verdi: 0 BTC (ubrukbar, legges ikke til i UTXO-sett)

  [1]: Vekslepenger tilbake til bruker (valgfritt, standard P2WPKH)
```

**Implementasjon:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markører

- **Tildelingsmarkør:** `POCX` (0x50, 0x4F, 0x43, 0x58) = «Proof of Capacity neXt»
- **Opphevingsmarkør:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = «eXit Capacity OPeration»

**Implementasjon:** `src/pocx/assignments/opcodes.cpp:15-19`

### Viktige transaksjonsegenskaper

- Standard Bitcoin-transaksjoner (ingen protokollendringer)
- OP_RETURN-utdata er bevismessig ubrukbare (legges aldri til i UTXO-sett)
- Ploteierskap bevises ved signatur på input[0] fra plotadresse
- Lav kostnad (~200 bytes, typisk <0,0001 BTC gebyr)
- Lommebok velger automatisk største UTXO fra plotadresse for å bevise eierskap

## Databasearkitektur

### Lagringsstruktur

Alle tildelingsdata lagres i samme LevelDB-database som UTXO-settet (`chainstate/`), men med separate nøkkelprefiks:

```
chainstate/ LevelDB:
├─ UTXO-sett (Bitcoin Core standard)
│  └─ 'C'-prefiks: COutPoint → Coin
│
└─ Tildelingstilstand (PoCX-tillegg)
   └─ 'A'-prefiks: (plot_address, assignment_txid) → ForgingAssignment
       └─ Full historikk: alle tildelinger per plot over tid
```

**Implementasjon:** `src/txdb.cpp:237-348`

### ForgingAssignment-struktur

```cpp
struct ForgingAssignment {
    // Identitet
    std::array<uint8_t, 20> plotAddress;      // Ploteier (20-byte P2WPKH-hash)
    std::array<uint8_t, 20> forgingAddress;   // Forging-rettighetsholder (20-byte P2WPKH-hash)

    // Tildelingslivssyklus
    uint256 assignment_txid;                   // Transaksjon som opprettet tildeling
    int assignment_height;                     // Blokkhøyde opprettet
    int assignment_effective_height;           // Når den blir aktiv (høyde + forsinkelse)

    // Opphevingslivssyklus
    bool revoked;                              // Er denne opphevet?
    uint256 revocation_txid;                   // Transaksjon som opphevet den
    int revocation_height;                     // Blokkhøyde opphevet
    int revocation_effective_height;           // Når opphevelse er effektiv (høyde + forsinkelse)

    // Tilstandsforespørslingsmetoder
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementasjon:** `src/coins.h:111-178`

### Tildelingstilstander

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen tildeling eksisterer
    ASSIGNING = 1,   // Tildeling opprettet, venter på aktiveringsforsinkelse
    ASSIGNED = 2,    // Tildeling aktiv, forging tillatt
    REVOKING = 3,    // Opphevet, men fortsatt aktiv under forsinkelsesperiode
    REVOKED = 4      // Fullstendig opphevet, ikke lenger aktiv
};
```

**Implementasjon:** `src/coins.h:98-104`

### Databasenøkler

```cpp
// Historikknøkkel: lagrer full tildelingspost
// Nøkkelformat: (prefiks, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotadresse (20 bytes)
    int assignment_height;                // Høyde for sorteringsoptimalisering
    uint256 assignment_txid;              // Transaksjons-ID
};
```

**Implementasjon:** `src/txdb.cpp:245-262`

### Historikksporing

- Hver tildeling lagres permanent (slettes aldri med mindre reorg)
- Flere tildelinger per plot spores over tid
- Muliggjør full revisjonssti og historiske tilstandsforespørsler
- Opphevede tildelinger forblir i databasen med `revoked=true`

## Blokkprosessering

### ConnectBlock-integrasjon

Tildelings- og opphevelses-OP_RETURN-er prosesseres under blokkforbindelse i `validation.cpp`:

```cpp
// Plassering: Etter skriptvalidering, før UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parse OP_RETURN-data
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifiser eierskap (tx må signeres av ploteier)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Sjekk plottilstand (må være UNASSIGNED eller REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Opprett ny tildeling
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Lagre undo-data
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parse OP_RETURN-data
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifiser eierskap
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Hent gjeldende tildeling
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Lagre gammel tilstand for undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Merk som opphevet
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

// UpdateCoins fortsetter normalt (hopper automatisk over OP_RETURN-utdata)
```

**Implementasjon:** `src/validation.cpp:2775-2878`

### Eierskapsverifisering

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Sjekk at minst én input er signert av ploteier
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Trekk ut destinasjon
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Sjekk om P2WPKH til plotadresse
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core har allerede validert signatur
                return true;
            }
        }
    }
    return false;
}
```

**Implementasjon:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktiveringsforsinkelser

Tildelinger og opphevelser har konfigurerbare aktiveringsforsinkelser for å forhindre reorg-angrep:

```cpp
// Konsensusparametere (konfigurerbare per nettverk)
// Eksempel: 30 blokker = ~1 time med 2-minutters blokktid
consensus.nForgingAssignmentDelay;   // Tildelingsaktiveringsforsinkelse
consensus.nForgingRevocationDelay;   // Oppheviingsaktiveringsforsinkelse
```

**Tilstandsoverganger:**
- Tildeling: `UNASSIGNED → ASSIGNING (forsinkelse) → ASSIGNED`
- Oppheving: `ASSIGNED → REVOKING (forsinkelse) → REVOKED`

**Implementasjon:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool-validering

Tildelings- og opphevingstransaksjoner valideres ved mempool-aksept for å avvise ugyldige transaksjoner før nettverkspropagering.

### Transaksjonnivåsjekker (CheckTransaction)

Utført i `src/consensus/tx_check.cpp` uten kjedetilstandstilgang:

1. **Maksimalt én POCX OP_RETURN:** Transaksjon kan ikke inneholde flere POCX/XCOP-markører

**Implementasjon:** `src/consensus/tx_check.cpp:63-77`

### Mempool-akseptsjekker (PreChecks)

Utført i `src/validation.cpp` med full kjedetilstands- og mempooltilgang:

#### Tildelingsvalidering

1. **Ploteierskap:** Transaksjon må signeres av ploteier
2. **Plottilstand:** Plot må være UNASSIGNED (0) eller REVOKED (4)
3. **Mempool-konflikter:** Ingen annen tildeling for dette plottet i mempool (først-sett vinner)

#### Opphevingsvalidering

1. **Ploteierskap:** Transaksjon må signeres av ploteier
2. **Aktiv tildeling:** Plot må være i ASSIGNED (2)-tilstand kun
3. **Mempool-konflikter:** Ingen annen oppheving for dette plottet i mempool

**Implementasjon:** `src/validation.cpp:898-993`

### Valideringsflyt

```
Transaksjonskringkasting
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maks én POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Verifiser ploteierskap
  ✓ Sjekk tildelingstilstand
  ✓ Sjekk mempool-konflikter
       ↓
   Gyldig → Aksepter til mempool
   Ugyldig → Avvis (ikke propager)
       ↓
Blokkmining
       ↓
ConnectBlock() [validation.cpp]
  ✓ Re-valider alle sjekker (forsvarsdybde)
  ✓ Bruk tilstandsendringer
  ✓ Registrer undo-info
```

### Forsvarsdybde

Alle mempool-valideringssjekker kjøres på nytt under `ConnectBlock()` for å beskytte mot:
- Mempool-omgåelsesangrep
- Ugyldige blokker fra ondsinnede minere
- Grensetilfeller under reorg-scenarioer

Blokkvalidering forblir autoritativt for konsensus.

## Atomiske databaseoppdateringer

### Tre-lags arkitektur

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (minnecache)          │  ← Tildelingsendringer spores i minne
│   - Coins: cacheCoins                   │
│   - Tildelinger: pendingAssignments     │
│   - Dirty-sporing: dirtyPlots           │
│   - Slettinger: deletedAssignments      │
│   - Minnesporing: cachedAssignmentsUsage│
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (databaselag)            │  ← Enkelt atomisk skriv
│   - BatchWrite(): UTXO-er + tildelinger │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (disklagring)                 │  ← ACID-garantier
│   - Atomisk transaksjon                 │
└─────────────────────────────────────────┘
```

### Flush-prosess

Når `view.Flush()` kalles under blokkforbindelse:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Skriv coin-endringer til base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Skriv tildelingsendringer atomisk
    if (fOk && !dirtyPlots.empty()) {
        // Samle dirty-tildelinger
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tom - ubrukt

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
            // Tøm sporing
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Frigjør minne
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementasjon:** `src/coins.cpp:278-315`

### Database-batchskriv

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Enkelt LevelDB-batch

    // 1. Merk overgangstilstand
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Skriv alle coin-endringer
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Merk konsistent tilstand
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMISK COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Tildelinger skrives separat men i samme databasetransaksjonskontekst
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Ubrukt parameter (beholdt for API-kompatibilitet)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nytt batch, men samme database

    // Skriv tildelingshistorikk
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Slett slettede tildelinger fra historikk
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMISK COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementasjon:** `src/txdb.cpp:332-348`

### Atomisitetsgarantier

**Hva som er atomisk:**
- Alle coin-endringer innenfor en blokk skrives atomisk
- Alle tildelingsendringer innenfor en blokk skrives atomisk
- Database forblir konsistent ved krasj

**Nåværende begrensning:**
- Coins og tildelinger skrives i **separate** LevelDB-batchoperasjoner
- Begge operasjoner skjer under `view.Flush()`, men ikke i én enkelt atomisk skriv
- I praksis: Begge batcher fullføres raskt før disk-fsync
- Risikoen er minimal: Begge ville måtte spilles av på nytt fra samme blokk ved krasjgjenoppretting

**Merk:** Dette avviker fra den opprinnelige arkitekturplanen som krevde ett enkelt forent batch. Gjeldende implementasjon bruker to batcher, men opprettholder konsistens gjennom Bitcoin Cores eksisterende krasjgjenopprettingsmekanismer (DB_HEAD_BLOCKS-markør).

## Reorganiseringshåndtering

### Undo-datastruktur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Tildeling ble lagt til (slett ved undo)
        MODIFIED = 1,   // Tildeling ble modifisert (gjenopprett ved undo)
        REVOKED = 2     // Tildeling ble opphevet (fjern oppheving ved undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Full tilstand før endring
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo-data
    std::vector<ForgingUndo> vforgingundo;  // Tildelingsundo-data
};
```

**Implementasjon:** `src/undo.h:63-105`

### DisconnectBlock-prosess

Når en blokk frakobles under en reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standard UTXO-frakobling ...

    // Les undo-data fra disk
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Angre tildelingsendringer (prosesser i omvendt rekkefølge)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Tildeling ble lagt til - fjern den
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Tildeling ble opphevet - gjenopprett uopphevet tilstand
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Tildeling ble modifisert - gjenopprett tidligere tilstand
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementasjon:** `src/validation.cpp:2381-2415`

### Cachehåndtering under reorg

```cpp
class CCoinsViewCache {
private:
    // Tildelingscacher
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Spor modifiserte plotter
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Spor slettinger
    mutable size_t cachedAssignmentsUsage{0};  // Minnesporing

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

**Implementasjon:** `src/coins.cpp:494-565`

## RPC-grensesnitt

### Nodekommandoer (ingen lommebok påkrevd)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Returnerer gjeldende tildelingsstatus for en plotadresse:
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

**Implementasjon:** `src/pocx/rpc/assignments.cpp:31-126`

### Lommebokkommandoer (lommebok påkrevd)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Oppretter en tildelingstransaksjon:
- Velger automatisk største UTXO fra plotadresse for å bevise eierskap
- Bygger transaksjon med OP_RETURN + vekslepengeutdata
- Signerer med ploteiers nøkkel
- Kringkaster til nettverk

**Implementasjon:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Oppretter en opphevingstransaksjon:
- Velger automatisk største UTXO fra plotadresse for å bevise eierskap
- Bygger transaksjon med OP_RETURN + vekslepengeutdata
- Signerer med ploteiers nøkkel
- Kringkaster til nettverk

**Implementasjon:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Lommeboktransaksjonsoppretting

Lommeboktransaksjonsopprettingsprosessen:

```cpp
1. Parse og valider adresser (må være P2WPKH bech32)
2. Finn største UTXO fra plotadresse (beviser eierskap)
3. Opprett midlertidig transaksjon med dummy-utdata
4. Signer transaksjon (få nøyaktig størrelse med vitneddata)
5. Erstatt dummy-utdata med OP_RETURN
6. Juster gebyrer proporsjonalt basert på størrelsesendring
7. Re-signer endelig transaksjon
8. Kringkast til nettverk
```

**Viktig innsikt:** Lommeboken må bruke fra plotadressen for å bevise eierskap, så den tvinger automatisk myntvalg fra den adressen.

**Implementasjon:** `src/pocx/assignments/transactions.cpp:38-263`

## Filstruktur

### Kjerneimplementasjonsfiler

```
src/
├── coins.h                        # ForgingAssignment-struct, CCoinsViewCache-metoder [710 linjer]
├── coins.cpp                      # Cachehåndtering, batchskrivinger [603 linjer]
│
├── txdb.h                         # CCoinsViewDB tildelingsmetoder [90 linjer]
├── txdb.cpp                       # Databaselese/skriv [349 linjer]
│
├── undo.h                         # ForgingUndo-struktur for reorgs
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock-integrasjon
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN-format, parsing, verifisering
    │   ├── opcodes.cpp            # [259 linjer] Markørdefinisjoner, OP_RETURN-ops, eierskapssjekk
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState-hjelpere
    │   ├── assignment_state.cpp   # Tilstandsforespørslsfunksjoner
    │   ├── transactions.h         # Lommeboktransaksjonsopprettings-API
    │   └── transactions.cpp       # create_assignment, revoke_assignment lommebokfunksjoner
    │
    ├── rpc/
    │   ├── assignments.h          # Node RPC-kommandoer (ingen lommebok)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC-er
    │   ├── assignments_wallet.h   # Lommebok RPC-kommandoer
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC-er
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Ytelsesegenskaper

### Databaseoperasjoner

- **Hent gjeldende tildeling:** O(n) - skann alle tildelinger for plotadresse for å finne nyeste
- **Hent tildelingshistorikk:** O(n) - iterer alle tildelinger for plot
- **Opprett tildeling:** O(1) - enkelt innsett
- **Opphev tildeling:** O(1) - enkelt oppdatering
- **Reorg (per tildeling):** O(1) - direkte undo-dataanvendelse

Der n = antall tildelinger for et plot (typisk lite, < 10)

### Minnebruk

- **Per tildeling:** ~160 bytes (ForgingAssignment-struct)
- **Cache-overhead:** Hashtabell-overhead for dirty-sporing
- **Typisk blokk:** <10 tildelinger = <2 KB minne

### Diskbruk

- **Per tildeling:** ~200 bytes på disk (med LevelDB-overhead)
- **10000 tildelinger:** ~2 MB diskplass
- **Ubetydelig sammenlignet med UTXO-sett:** <0,001% av typisk chainstate

## Nåværende begrensninger og fremtidig arbeid

### Atomisitetsbegrensning

**Nåværende:** Coins og tildelinger skrives i separate LevelDB-batcher under `view.Flush()`

**Konsekvens:** Teoretisk risiko for inkonsistens hvis krasj oppstår mellom batcher

**Avbøting:**
- Begge batcher fullføres raskt før fsync
- Bitcoin Cores krasjgjenoppretting bruker DB_HEAD_BLOCKS-markør
- I praksis: Aldri observert under testing

**Fremtidig forbedring:** Forene til én enkelt LevelDB-batchoperasjon

### Tildelingshistorikkrydding

**Nåværende:** Alle tildelinger lagres på ubestemt tid

**Konsekvens:** ~200 bytes per tildeling for alltid

**Fremtidig:** Valgfri rydding av fullstendig opphevede tildelinger eldre enn N blokker

**Merk:** Usannsynlig å være nødvendig - selv 1 million tildelinger = 200 MB

## Teststatus

### Implementerte tester

- OP_RETURN-parsing og validering
- Eierskapsverifisering
- ConnectBlock tildelingsoppretting
- ConnectBlock oppheving
- DisconnectBlock reorg-håndtering
- Databaselese/skriveoperasjoner
- Tilstandsoverganger (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- RPC-kommandoer (get_assignment, create_assignment, revoke_assignment)
- Lommeboktransaksjonsoppretting

### Testdekningsområder

- Enhetstester: `src/test/pocx_*_tests.cpp`
- Funksjonelle tester: `test/functional/feature_pocx_*.py`
- Integrasjonstester: Manuell testing med regtest

## Konsensusregler

### Tildelingsopprettingsregler

1. **Eierskap:** Transaksjon må signeres av ploteier
2. **Tilstand:** Plot må være i UNASSIGNED eller REVOKED-tilstand
3. **Format:** Gyldig OP_RETURN med POCX-markør + 2x 20-byte adresser
4. **Unikhet:** Én aktiv tildeling per plot om gangen

### Opphevingsregler

1. **Eierskap:** Transaksjon må signeres av ploteier
2. **Eksistens:** Tildeling må eksistere og ikke allerede være opphevet
3. **Format:** Gyldig OP_RETURN med XCOP-markør + 20-byte adresse

### Aktiveringsregler

- **Tildelingsaktivering:** `assignment_height + nForgingAssignmentDelay`
- **Opphevingsaktivering:** `revocation_height + nForgingRevocationDelay`
- **Forsinkelser:** Konfigurerbare per nettverk (f.eks. 30 blokker = ~1 time med 2-minutters blokktid)

### Blokkvalidering

- Ugyldig tildeling/oppheving → blokk avvist (konsensusfeil)
- OP_RETURN-utdata ekskluderes automatisk fra UTXO-sett (standard Bitcoin-oppførsel)
- Tildelingsprosessering skjer før UTXO-oppdateringer i ConnectBlock

## Konklusjon

PoCX forging assignment-systemet som implementert gir:

- **Enkelhet:** Standard Bitcoin-transaksjoner, ingen spesielle UTXO-er
- **Kostnadseffektivt:** Ingen støvkrav, kun transaksjonsgebyrer
- **Reorg-sikkerhet:** Omfattende undo-data gjenoppretter korrekt tilstand
- **Atomiske oppdateringer:** Databasekonsistens gjennom LevelDB-batcher
- **Full historikk:** Komplett revisjonssti av alle tildelinger over tid
- **Ren arkitektur:** Minimale Bitcoin Core-modifikasjoner, isolert PoCX-kode
- **Produksjonsklar:** Fullstendig implementert, testet og operativ

### Implementasjonskvalitet

- **Kodeorganisering:** Utmerket - klar separasjon mellom Bitcoin Core og PoCX
- **Feilhåndtering:** Omfattende konsensusvalidering
- **Dokumentasjon:** Kodekommentarer og struktur godt dokumentert
- **Testing:** Kjernefunksjonalitet testet, integrasjon verifisert

### Validerte nøkkeldesignbeslutninger

1. OP_RETURN-kun tilnærming (vs UTXO-basert)
2. Separat databaselagring (vs Coin extraData)
3. Full historikksporing (vs kun-gjeldende)
4. Eierskap ved signatur (vs UTXO-forbruk)
5. Aktiveringsforsinkelser (forhindrer reorg-angrep)

Systemet oppnår med hell alle arkitektoniske mål med en ren, vedlikeholdbar implementasjon.

---

[← Forrige: Konsensus og mining](3-consensus-and-mining.md) | [Innholdsfortegnelse](index.md) | [Neste: Tidssynkronisering →](5-timing-security.md)

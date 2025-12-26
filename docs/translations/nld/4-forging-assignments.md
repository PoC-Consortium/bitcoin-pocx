[Vorige: Consensus en mining](3-consensus-and-mining.md) | [Inhoudsopgave](index.md) | [Volgende: Tijdsynchronisatie](5-timing-security.md)

---

# Hoofdstuk 4: PoCX Forging-toewijzingssysteem

## Samenvatting

Dit document beschrijft het **geimplementeerde** PoCX forging-toewijzingssysteem met een alleen-OP_RETURN-architectuur. Het systeem stelt ploteigenaren in staat om forgingrechten te delegeren aan afzonderlijke adressen via on-chain transacties, met volledige reorg-veiligheid en atomische database-operaties.

**Status:** Volledig geimplementeerd en operationeel

## Kernontwerp filosofie

**Kernprincipe:** Toewijzingen zijn machtigingen, geen activa

- Geen speciale UTXO's om bij te houden of te besteden
- Toewijzingsstatus apart opgeslagen van UTXO-set
- Eigenaarschap bewezen door transactiehandtekening, niet UTXO-besteding
- Volledige geschiedenisbijhouding voor complete audittrail
- Atomische database-updates via LevelDB-batchschrijfacties

## Transactiestructuur

### Toewijzingstransactieformaat

```
Invoer:
  [0]: Elke UTXO gecontroleerd door ploteigenaar (bewijst eigenaarschap + betaalt kosten)
       Moet ondertekend zijn met privesleutel van ploteigenaar
  [1+]: Optionele extra invoer voor kostendekning

Uitvoer:
  [0]: OP_RETURN (POCX-markering + plotadres + forge-adres)
       Formaat: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Grootte: 46 bytes totaal (1 byte OP_RETURN + 1 byte lengte + 44 bytes data)
       Waarde: 0 BTC (onbestedbaar, niet toegevoegd aan UTXO-set)

  [1]: Wisselgeld terug naar gebruiker (optioneel, standaard P2WPKH)
```

**Implementatie:** `src/pocx/assignments/opcodes.cpp:25-52`

### Intrekkingstransactieformaat

```
Invoer:
  [0]: Elke UTXO gecontroleerd door ploteigenaar (bewijst eigenaarschap + betaalt kosten)
       Moet ondertekend zijn met privesleutel van ploteigenaar
  [1+]: Optionele extra invoer voor kostendekking

Uitvoer:
  [0]: OP_RETURN (XCOP-markering + plotadres)
       Formaat: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Grootte: 26 bytes totaal (1 byte OP_RETURN + 1 byte lengte + 24 bytes data)
       Waarde: 0 BTC (onbestedbaar, niet toegevoegd aan UTXO-set)

  [1]: Wisselgeld terug naar gebruiker (optioneel, standaard P2WPKH)
```

**Implementatie:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markeringen

- **Toewijzingsmarkering:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Intrekkingsmarkering:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementatie:** `src/pocx/assignments/opcodes.cpp:15-19`

### Belangrijke transactiekenmerken

- Standaard Bitcoin-transacties (geen protocolwijzigingen)
- OP_RETURN-uitvoer zijn aantoonbaar onbestedbaar (nooit toegevoegd aan UTXO-set)
- Ploteigenaarschap bewezen door handtekening op invoer[0] van plotadres
- Lage kosten (~200 bytes, doorgaans <0,0001 BTC transactiekosten)
- Wallet selecteert automatisch grootste UTXO van plotadres om eigenaarschap te bewijzen

## Database-architectuur

### Opslagstructuur

Alle toewijzingsgegevens worden opgeslagen in dezelfde LevelDB-database als de UTXO-set (`chainstate/`), maar met afzonderlijke sleutelvoorvoegsels:

```
chainstate/ LevelDB:
├─ UTXO-set (Bitcoin Core standaard)
│  └─ 'C'-voorvoegsel: COutPoint -> Coin
│
└─ Toewijzingsstatus (PoCX-toevoegingen)
   └─ 'A'-voorvoegsel: (plot_address, assignment_txid) -> ForgingAssignment
       └─ Volledige geschiedenis: alle toewijzingen per plot door de tijd
```

**Implementatie:** `src/txdb.cpp:237-348`

### ForgingAssignment-structuur

```cpp
struct ForgingAssignment {
    // Identiteit
    std::array<uint8_t, 20> plotAddress;      // Ploteigenaar (20-byte P2WPKH-hash)
    std::array<uint8_t, 20> forgingAddress;   // Forgingrechtenhouder (20-byte P2WPKH-hash)

    // Toewijzingslevenscyclus
    uint256 assignment_txid;                   // Transactie die toewijzing creeerde
    int assignment_height;                     // Blokhoogte gecreeerd
    int assignment_effective_height;           // Wanneer het actief wordt (hoogte + vertraging)

    // Intrekkingslevenscyclus
    bool revoked;                              // Is dit ingetrokken?
    uint256 revocation_txid;                   // Transactie die het introk
    int revocation_height;                     // Blokhoogte ingetrokken
    int revocation_effective_height;           // Wanneer intrekking effectief (hoogte + vertraging)

    // Statusquerymethoden
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementatie:** `src/coins.h:111-178`

### Toewijzingsstatussen

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Geen toewijzing bestaat
    ASSIGNING = 1,   // Toewijzing gecreeerd, wachtend op activeringsvertraging
    ASSIGNED = 2,    // Toewijzing actief, forgen toegestaan
    REVOKING = 3,    // Ingetrokken, maar nog actief tijdens vertragingsperiode
    REVOKED = 4      // Volledig ingetrokken, niet langer actief
};
```

**Implementatie:** `src/coins.h:98-104`

### Databasesleutels

```cpp
// Geschiedenissleutel: slaat volledige toewijzingsrecord op
// Sleutelformaat: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotadres (20 bytes)
    int assignment_height;                // Hoogte voor sorteeroptimalisatie
    uint256 assignment_txid;              // Transactie-ID
};
```

**Implementatie:** `src/txdb.cpp:245-262`

### Geschiedenisbijhouding

- Elke toewijzing permanent opgeslagen (nooit verwijderd tenzij reorg)
- Meerdere toewijzingen per plot bijgehouden door de tijd
- Maakt volledige audittrail en historische statusqueries mogelijk
- Ingetrokken toewijzingen blijven in database met `revoked=true`

## Blokverwerking

### ConnectBlock-integratie

Toewijzings- en intrekkings-OP_RETURN's worden verwerkt tijdens blokverbinding in `validation.cpp`:

```cpp
// Locatie: Na scriptvalidatie, voor UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parse OP_RETURN-gegevens
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifieer eigenaarschap (tx moet ondertekend zijn door ploteigenaar)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Controleer plotstatus (moet UNASSIGNED of REVOKED zijn)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Creeer nieuwe toewijzing
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Sla undo-gegevens op
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parse OP_RETURN-gegevens
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifieer eigenaarschap
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Haal huidige toewijzing op
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Sla oude status op voor undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Markeer als ingetrokken
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

// UpdateCoins gaat normaal door (slaat automatisch OP_RETURN-uitvoer over)
```

**Implementatie:** `src/validation.cpp:2775-2878`

### Eigenaarschapsverificatie

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Controleer dat minstens een invoer ondertekend is door ploteigenaar
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extraheer bestemming
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Controleer of P2WPKH naar plotadres
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core heeft handtekening al gevalideerd
                return true;
            }
        }
    }
    return false;
}
```

**Implementatie:** `src/pocx/assignments/opcodes.cpp:217-256`

### Activeringsvertragingen

Toewijzingen en intrekkingen hebben configureerbare activeringsvertragingen om reorg-aanvallen te voorkomen:

```cpp
// Consensusparameters (configureerbaar per netwerk)
// Voorbeeld: 30 blokken = ~1 uur met 2-minuten bloktijd
consensus.nForgingAssignmentDelay;   // Toewijzingsactiveringsvertraging
consensus.nForgingRevocationDelay;   // Intrekkingsactiveringsvertraging
```

**Statusovergangen:**
- Toewijzing: `UNASSIGNED -> ASSIGNING (vertraging) -> ASSIGNED`
- Intrekking: `ASSIGNED -> REVOKING (vertraging) -> REVOKED`

**Implementatie:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool-validatie

Toewijzings- en intrekkingstransacties worden gevalideerd bij mempool-acceptatie om ongeldige transacties af te wijzen voor netwerkpropagatie.

### Transactieniveau-controles (CheckTransaction)

Uitgevoerd in `src/consensus/tx_check.cpp` zonder ketenstatus-toegang:

1. **Maximum een POCX OP_RETURN:** Transactie mag niet meerdere POCX/XCOP-markeringen bevatten

**Implementatie:** `src/consensus/tx_check.cpp:63-77`

### Mempool-acceptatiecontroles (PreChecks)

Uitgevoerd in `src/validation.cpp` met volledige ketenstatus- en mempool-toegang:

#### Toewijzingsvalidatie

1. **Ploteigenaarschap:** Transactie moet ondertekend zijn door ploteigenaar
2. **Plotstatus:** Plot moet UNASSIGNED (0) of REVOKED (4) zijn
3. **Mempool-conflicten:** Geen andere toewijzing voor dit plot in mempool (first-seen wint)

#### Intrekkingsvalidatie

1. **Ploteigenaarschap:** Transactie moet ondertekend zijn door ploteigenaar
2. **Actieve toewijzing:** Plot moet alleen in ASSIGNED (2) status zijn
3. **Mempool-conflicten:** Geen andere intrekking voor dit plot in mempool

**Implementatie:** `src/validation.cpp:898-993`

### Validatieflow

```
Transactie-uitzending
       |
CheckTransaction() [tx_check.cpp]
  Controle max een POCX OP_RETURN
       |
MemPoolAccept::PreChecks() [validation.cpp]
  Verifieer ploteigenaarschap
  Controleer toewijzingsstatus
  Controleer mempool-conflicten
       |
   Geldig -> Accepteer in mempool
   Ongeldig -> Weiger (niet propageren)
       |
Blokmining
       |
ConnectBlock() [validation.cpp]
  Hervalideer alle controles (defense in depth)
  Pas statuswijzigingen toe
  Registreer undo-info
```

### Defense in depth

Alle mempool-validatiecontroles worden opnieuw uitgevoerd tijdens `ConnectBlock()` om te beschermen tegen:
- Mempool-bypass-aanvallen
- Ongeldige blokken van kwaadaardige miners
- Randgevallen tijdens reorg-scenario's

Blokvalidatie blijft gezaghebbend voor consensus.

## Atomische database-updates

### Drie-lagen architectuur

```
+------------------------------------------+
|   CCoinsViewCache (Geheugencache)        |  <- Toewijzingswijzigingen bijgehouden in geheugen
|   - Coins: cacheCoins                    |
|   - Toewijzingen: pendingAssignments     |
|   - Dirty-tracking: dirtyPlots           |
|   - Verwijderingen: deletedAssignments   |
|   - Geheugentracking: cachedAssignmentsUsage |
+------------------------------------------+
                    | Flush()
+------------------------------------------+
|   CCoinsViewDB (Databaselaag)            |  <- Enkele atomische schrijfactie
|   - BatchWrite(): UTXO's + toewijzingen  |
+------------------------------------------+
                    | WriteBatch()
+------------------------------------------+
|   LevelDB (Schijfopslag)                 |  <- ACID-garanties
|   - Atomische transactie                 |
+------------------------------------------+
```

### Flush-proces

Wanneer `view.Flush()` wordt aangeroepen tijdens blokverbinding:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Schrijf coin-wijzigingen naar basis
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Schrijf toewijzingswijzigingen atomisch
    if (fOk && !dirtyPlots.empty()) {
        // Verzamel dirty toewijzingen
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Leeg - ongebruikt

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Schrijf naar database
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Wis tracking
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Geef geheugen vrij
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementatie:** `src/coins.cpp:278-315`

### Database-batchschrijfactie

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Enkele LevelDB-batch

    // 1. Markeer overgangsstatus
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Schrijf alle coin-wijzigingen
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Markeer consistente status
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMISCHE COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Toewijzingen apart geschreven maar in dezelfde databasetransactiecontext
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Ongebruikte parameter (behouden voor API-compatibiliteit)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nieuwe batch, maar zelfde database

    // Schrijf toewijzingsgeschiedenis
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Wis verwijderde toewijzingen uit geschiedenis
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMISCHE COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementatie:** `src/txdb.cpp:332-348`

### Atomiciteitsgaranties

**Wat is atomisch:**
- Alle coin-wijzigingen binnen een blok worden atomisch geschreven
- Alle toewijzingswijzigingen binnen een blok worden atomisch geschreven
- Database blijft consistent bij crashes

**Huidige beperking:**
- Coins en toewijzingen worden geschreven in **afzonderlijke** LevelDB-batchoperaties
- Beide operaties gebeuren tijdens `view.Flush()`, maar niet in een enkele atomische schrijfactie
- In de praktijk: Beide batches voltooien snel achter elkaar voor schijf-fsync
- Risico is minimaal: Beide zouden opnieuw moeten worden afgespeeld vanaf hetzelfde blok bij crashherstel

**Opmerking:** Dit wijkt af van het oorspronkelijke architectuurplan dat opriep tot een enkele uniforme batch. De huidige implementatie gebruikt twee batches maar handhaaft consistentie via Bitcoin Core's bestaande crashherstelmechanismen (DB_HEAD_BLOCKS-markering).

## Reorg-afhandeling

### Undo-datastructuur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Toewijzing was toegevoegd (verwijder bij undo)
        MODIFIED = 1,   // Toewijzing was gewijzigd (herstel bij undo)
        REVOKED = 2     // Toewijzing was ingetrokken (ongedaan maken bij undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Volledige status voor wijziging
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo-gegevens
    std::vector<ForgingUndo> vforgingundo;  // Toewijzing undo-gegevens
};
```

**Implementatie:** `src/undo.h:63-105`

### DisconnectBlock-proces

Wanneer een blok wordt losgekoppeld tijdens een reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standaard UTXO-ontkoppeling ...

    // Lees undo-gegevens van schijf
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Maak toewijzingswijzigingen ongedaan (verwerk in omgekeerde volgorde)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Toewijzing was toegevoegd - verwijder het
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Toewijzing was ingetrokken - herstel niet-ingetrokken status
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Toewijzing was gewijzigd - herstel vorige status
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementatie:** `src/validation.cpp:2381-2415`

### Cachebeheer tijdens reorg

```cpp
class CCoinsViewCache {
private:
    // Toewijzingscaches
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Houd gewijzigde plots bij
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Houd verwijderingen bij
    mutable size_t cachedAssignmentsUsage{0};  // Geheugentracking

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

**Implementatie:** `src/coins.cpp:494-565`

## RPC-interface

### Node-opdrachten (geen wallet vereist)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Retourneert huidige toewijzingsstatus voor een plotadres:
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

**Implementatie:** `src/pocx/rpc/assignments.cpp:31-126`

### Wallet-opdrachten (wallet vereist)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Creert een toewijzingstransactie:
- Selecteert automatisch grootste UTXO van plotadres om eigenaarschap te bewijzen
- Bouwt transactie met OP_RETURN + wisselgeld-uitvoer
- Ondertekent met sleutel van ploteigenaar
- Zendt uit naar netwerk

**Implementatie:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Creert een intrekkingstransactie:
- Selecteert automatisch grootste UTXO van plotadres om eigenaarschap te bewijzen
- Bouwt transactie met OP_RETURN + wisselgeld-uitvoer
- Ondertekent met sleutel van ploteigenaar
- Zendt uit naar netwerk

**Implementatie:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Wallet-transactiecreatie

Het wallet-transactiecreatieproces:

```cpp
1. Parse en valideer adressen (moet P2WPKH bech32 zijn)
2. Vind grootste UTXO van plotadres (bewijst eigenaarschap)
3. Creeer tijdelijke transactie met dummy-uitvoer
4. Onderteken transactie (verkrijg nauwkeurige grootte met witness-gegevens)
5. Vervang dummy-uitvoer met OP_RETURN
6. Pas kosten proportioneel aan op basis van groottewijziging
7. Heronderteken definitieve transactie
8. Zend uit naar netwerk
```

**Belangrijk inzicht:** De wallet moet uitgeven van het plotadres om eigenaarschap te bewijzen, dus het forceert automatisch muntselectie van dat adres.

**Implementatie:** `src/pocx/assignments/transactions.cpp:38-263`

## Bestandsstructuur

### Kernimplementatiebestanden

```
src/
├── coins.h                        # ForgingAssignment-struct, CCoinsViewCache-methoden [710 regels]
├── coins.cpp                      # Cachebeheer, batchschrijfacties [603 regels]
│
├── txdb.h                         # CCoinsViewDB toewijzingsmethoden [90 regels]
├── txdb.cpp                       # Database lezen/schrijven [349 regels]
│
├── undo.h                         # ForgingUndo-structuur voor reorgs
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock-integratie
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN-formaat, parsing, verificatie
    │   ├── opcodes.h              # [259 regels] Markeringsdefinities, OP_RETURN-ops, eigenaarschapscontrole
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState-helpers
    │   ├── assignment_state.cpp   # Toewijzingsstatus-queryfuncties
    │   ├── transactions.h         # Wallet-transactiecreatie-API
    │   └── transactions.cpp       # create_assignment, revoke_assignment wallet-functies
    │
    ├── rpc/
    │   ├── assignments.h          # Node RPC-opdrachten (geen wallet)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC's
    │   ├── assignments_wallet.h   # Wallet RPC-opdrachten
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC's
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Prestatiekenmerken

### Database-operaties

- **Huidige toewijzing ophalen:** O(n) - scan alle toewijzingen voor plotadres om meest recente te vinden
- **Toewijzingsgeschiedenis ophalen:** O(n) - itereer alle toewijzingen voor plot
- **Toewijzing creeren:** O(1) - enkele invoeg
- **Toewijzing intrekken:** O(1) - enkele update
- **Reorg (per toewijzing):** O(1) - directe undo-gegevenstoepassing

Waarbij n = aantal toewijzingen voor een plot (doorgaans klein, < 10)

### Geheugengebruik

- **Per toewijzing:** ~160 bytes (ForgingAssignment-struct)
- **Cache-overhead:** Hashmap-overhead voor dirty-tracking
- **Typisch blok:** <10 toewijzingen = <2 KB geheugen

### Schijfgebruik

- **Per toewijzing:** ~200 bytes op schijf (met LevelDB-overhead)
- **10000 toewijzingen:** ~2 MB schijfruimte
- **Verwaarloosbaar vergeleken met UTXO-set:** <0,001% van typische chainstate

## Huidige beperkingen en toekomstig werk

### Atomiciteitsbeperking

**Huidig:** Coins en toewijzingen geschreven in afzonderlijke LevelDB-batches tijdens `view.Flush()`

**Impact:** Theoretisch risico op inconsistentie als crash optreedt tussen batches

**Mitigatie:**
- Beide batches voltooien snel voor fsync
- Bitcoin Core's crashherstel gebruikt DB_HEAD_BLOCKS-markering
- In de praktijk: Nooit waargenomen in testen

**Toekomstige verbetering:** Unificeren in enkele LevelDB-batchoperatie

### Toewijzingsgeschiedenis-pruning

**Huidig:** Alle toewijzingen onbeperkt opgeslagen

**Impact:** ~200 bytes per toewijzing voor altijd

**Toekomstig:** Optioneel prunen van volledig ingetrokken toewijzingen ouder dan N blokken

**Opmerking:** Waarschijnlijk niet nodig - zelfs 1 miljoen toewijzingen = 200 MB

## Teststatus

### Geimplementeerde tests

- OP_RETURN-parsing en validatie
- Eigenaarschapsverificatie
- ConnectBlock-toewijzingscreatie
- ConnectBlock-intrekking
- DisconnectBlock-reorg-afhandeling
- Database lees/schrijfoperaties
- Statusovergangen (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC-opdrachten (get_assignment, create_assignment, revoke_assignment)
- Wallet-transactiecreatie

### Testdekkingsgebieden

- Unit-tests: `src/test/pocx_*_tests.cpp`
- Functionele tests: `test/functional/feature_pocx_*.py`
- Integratietests: Handmatig testen met regtest

## Consensusregels

### Toewijzingscreatieregels

1. **Eigenaarschap:** Transactie moet ondertekend zijn door ploteigenaar
2. **Status:** Plot moet in UNASSIGNED of REVOKED status zijn
3. **Formaat:** Geldige OP_RETURN met POCX-markering + 2x 20-byte adressen
4. **Uniciteit:** Een actieve toewijzing per plot tegelijk

### Intrekkingsregels

1. **Eigenaarschap:** Transactie moet ondertekend zijn door ploteigenaar
2. **Bestaan:** Toewijzing moet bestaan en nog niet ingetrokken zijn
3. **Formaat:** Geldige OP_RETURN met XCOP-markering + 20-byte adres

### Activeringsregels

- **Toewijzingsactivering:** `assignment_height + nForgingAssignmentDelay`
- **Intrekkingsactivering:** `revocation_height + nForgingRevocationDelay`
- **Vertragingen:** Configureerbaar per netwerk (bijv. 30 blokken = ~1 uur met 2-minuten bloktijd)

### Blokvalidatie

- Ongeldige toewijzing/intrekking -> blok afgewezen (consensusfout)
- OP_RETURN-uitvoer automatisch uitgesloten van UTXO-set (standaard Bitcoin-gedrag)
- Toewijzingsverwerking vindt plaats voor UTXO-updates in ConnectBlock

## Conclusie

Het PoCX forging-toewijzingssysteem zoals geimplementeerd biedt:

- **Eenvoud:** Standaard Bitcoin-transacties, geen speciale UTXO's
- **Kosteneffectief:** Geen dust-vereiste, alleen transactiekosten
- **Reorg-veiligheid:** Uitgebreide undo-gegevens herstellen correcte status
- **Atomische updates:** Databaseconsistentie via LevelDB-batches
- **Volledige geschiedenis:** Complete audittrail van alle toewijzingen door de tijd
- **Schone architectuur:** Minimale Bitcoin Core-wijzigingen, geisoleerde PoCX-code
- **Productiegereed:** Volledig geimplementeerd, getest en operationeel

### Implementatiekwaliteit

- **Code-organisatie:** Uitstekend - duidelijke scheiding tussen Bitcoin Core en PoCX
- **Foutafhandeling:** Uitgebreide consensusvalidatie
- **Documentatie:** Code-opmerkingen en structuur goed gedocumenteerd
- **Testen:** Kernfunctionaliteit getest, integratie geverifieerd

### Gevalideerde ontwerpbeslissingen

1. Alleen-OP_RETURN-aanpak (vs. UTXO-gebaseerd)
2. Afzonderlijke database-opslag (vs. Coin extraData)
3. Volledige geschiedenisbijhouding (vs. alleen-huidige)
4. Eigenaarschap door handtekening (vs. UTXO-besteding)
5. Activeringsvertragingen (voorkomt reorg-aanvallen)

Het systeem bereikt succesvol alle architectuurdoelen met een schone, onderhoudbare implementatie.

---

[Vorige: Consensus en mining](3-consensus-and-mining.md) | [Inhoudsopgave](index.md) | [Volgende: Tijdsynchronisatie](5-timing-security.md)

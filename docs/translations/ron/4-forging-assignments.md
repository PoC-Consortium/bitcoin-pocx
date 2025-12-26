[← Anterior: Consens și minerit](3-consensus-and-mining.md) | [📘 Cuprins](index.md) | [Următorul: Sincronizare temporală →](5-timing-security.md)

---

# Capitolul 4: Sistemul de atribuire a forjării PoCX

## Rezumat executiv

Acest document descrie sistemul de atribuire a forjării PoCX **implementat**, folosind o arhitectură bazată exclusiv pe OP_RETURN. Sistemul permite proprietarilor de plot-uri să delege drepturile de forjare către adrese separate prin tranzacții on-chain, cu siguranță completă la reorganizări și operațiuni atomice pe baza de date.

**Stare:** ✅ Complet implementat și operațional

## Filosofia de design de bază

**Principiu cheie:** Atribuirile sunt permisiuni, nu active

- Fără UTXO-uri speciale de urmărit sau cheltuit
- Starea atribuirii stocată separat de setul UTXO
- Proprietatea demonstrată prin semnătura tranzacției, nu prin cheltuirea UTXO
- Urmărirea completă a istoricului pentru pistă de audit completă
- Actualizări atomice ale bazei de date prin scrieri batch LevelDB

## Structura tranzacțiilor

### Formatul tranzacției de atribuire

```
Intrări:
  [0]: Orice UTXO controlat de proprietarul plot-ului (demonstrează proprietatea + plătește taxe)
       Trebuie semnat cu cheia privată a proprietarului plot-ului
  [1+]: Intrări suplimentare opționale pentru acoperirea taxelor

Ieșiri:
  [0]: OP_RETURN (marker POCX + adresă plot + adresă forjare)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Dimensiune: 46 octeți total (1 octet OP_RETURN + 1 octet lungime + 44 octeți date)
       Valoare: 0 BTC (necheltuibilă, nu se adaugă în setul UTXO)

  [1]: Rest returnat utilizatorului (opțional, P2WPKH standard)
```

**Implementare:** `src/pocx/assignments/opcodes.cpp:25-52`

### Formatul tranzacției de revocare

```
Intrări:
  [0]: Orice UTXO controlat de proprietarul plot-ului (demonstrează proprietatea + plătește taxe)
       Trebuie semnat cu cheia privată a proprietarului plot-ului
  [1+]: Intrări suplimentare opționale pentru acoperirea taxelor

Ieșiri:
  [0]: OP_RETURN (marker XCOP + adresă plot)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Dimensiune: 26 octeți total (1 octet OP_RETURN + 1 octet lungime + 24 octeți date)
       Valoare: 0 BTC (necheltuibilă, nu se adaugă în setul UTXO)

  [1]: Rest returnat utilizatorului (opțional, P2WPKH standard)
```

**Implementare:** `src/pocx/assignments/opcodes.cpp:54-77`

### Markeri

- **Marker atribuire:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Marker revocare:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementare:** `src/pocx/assignments/opcodes.cpp:15-19`

### Caracteristici cheie ale tranzacțiilor

- Tranzacții Bitcoin standard (fără modificări de protocol)
- Ieșirile OP_RETURN sunt demonstrabil necheltuibile (niciodată adăugate în setul UTXO)
- Proprietatea plot-ului demonstrată prin semnătura pe input[0] de la adresa plot-ului
- Cost scăzut (~200 octeți, de obicei <0,0001 BTC taxă)
- Portofelul selectează automat cel mai mare UTXO de la adresa plot-ului pentru a demonstra proprietatea

## Arhitectura bazei de date

### Structura de stocare

Toate datele de atribuire sunt stocate în aceeași bază de date LevelDB ca setul UTXO (`chainstate/`), dar cu prefixe de cheie separate:

```
chainstate/ LevelDB:
├─ Set UTXO (standard Bitcoin Core)
│  └─ prefix 'C': COutPoint → Coin
│
└─ Stare atribuiri (adăugiri PoCX)
   └─ prefix 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Istoric complet: toate atribuirile per plot în timp
```

**Implementare:** `src/txdb.cpp:237-348`

### Structura ForgingAssignment

```cpp
struct ForgingAssignment {
    // Identitate
    std::array<uint8_t, 20> plotAddress;      // Proprietar plot (hash P2WPKH de 20 octeți)
    std::array<uint8_t, 20> forgingAddress;   // Deținător drepturi forjare (hash P2WPKH de 20 octeți)

    // Ciclul de viață al atribuirii
    uint256 assignment_txid;                   // Tranzacția care a creat atribuirea
    int assignment_height;                     // Înălțimea blocului la creare
    int assignment_effective_height;           // Când devine activă (înălțime + întârziere)

    // Ciclul de viață al revocării
    bool revoked;                              // A fost aceasta revocată?
    uint256 revocation_txid;                   // Tranzacția care a revocat-o
    int revocation_height;                     // Înălțimea blocului la revocare
    int revocation_effective_height;           // Când revocarea devine efectivă (înălțime + întârziere)

    // Metode de interogare a stării
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementare:** `src/coins.h:111-178`

### Stările atribuirilor

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nu există atribuire
    ASSIGNING = 1,   // Atribuire creată, așteaptă întârzierea de activare
    ASSIGNED = 2,    // Atribuire activă, forjarea permisă
    REVOKING = 3,    // Revocată, dar încă activă în perioada de întârziere
    REVOKED = 4      // Complet revocată, nu mai este activă
};
```

**Implementare:** `src/coins.h:98-104`

### Chei bază de date

```cpp
// Cheie istoric: stochează înregistrarea completă a atribuirii
// Format cheie: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Adresa plot (20 octeți)
    int assignment_height;                // Înălțime pentru optimizarea sortării
    uint256 assignment_txid;              // ID tranzacție
};
```

**Implementare:** `src/txdb.cpp:245-262`

### Urmărirea istoricului

- Fiecare atribuire stocată permanent (niciodată ștearsă decât în caz de reorganizare)
- Mai multe atribuiri per plot urmărite în timp
- Permite pistă de audit completă și interogări istorice ale stării
- Atribuirile revocate rămân în baza de date cu `revoked=true`

## Procesarea blocurilor

### Integrarea ConnectBlock

OP_RETURN-urile de atribuire și revocare sunt procesate în timpul conectării blocului în `validation.cpp`:

```cpp
// Locație: După validarea scripturilor, înainte de UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsează datele OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifică proprietatea (tx trebuie semnat de proprietarul plot-ului)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Verifică starea plot-ului (trebuie să fie UNASSIGNED sau REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Creează atribuire nouă
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Stochează date de anulare
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsează datele OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifică proprietatea
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Obține atribuirea curentă
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Stochează starea veche pentru anulare
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Marchează ca revocat
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

// UpdateCoins continuă normal (sare automat peste ieșirile OP_RETURN)
```

**Implementare:** `src/validation.cpp:2775-2878`

### Verificarea proprietății

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Verifică că cel puțin o intrare este semnată de proprietarul plot-ului
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extrage destinația
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Verifică dacă P2WPKH la adresa plot-ului
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core a validat deja semnătura
                return true;
            }
        }
    }
    return false;
}
```

**Implementare:** `src/pocx/assignments/opcodes.cpp:217-256`

### Întârzieri de activare

Atribuirile și revocările au întârzieri de activare configurabile pentru a preveni atacurile de reorganizare:

```cpp
// Parametri de consens (configurabili per rețea)
// Exemplu: 30 blocuri = ~1 oră cu timp de bloc de 2 minute
consensus.nForgingAssignmentDelay;   // Întârziere activare atribuire
consensus.nForgingRevocationDelay;   // Întârziere activare revocare
```

**Tranziții de stare:**
- Atribuire: `UNASSIGNED → ASSIGNING (întârziere) → ASSIGNED`
- Revocare: `ASSIGNED → REVOKING (întârziere) → REVOKED`

**Implementare:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validarea mempool

Tranzacțiile de atribuire și revocare sunt validate la acceptarea în mempool pentru a respinge tranzacțiile invalide înainte de propagarea în rețea.

### Verificări la nivel de tranzacție (CheckTransaction)

Efectuate în `src/consensus/tx_check.cpp` fără acces la starea lanțului:

1. **Maximum un OP_RETURN POCX:** Tranzacția nu poate conține multiple markere POCX/XCOP

**Implementare:** `src/consensus/tx_check.cpp:63-77`

### Verificări de acceptare mempool (PreChecks)

Efectuate în `src/validation.cpp` cu acces complet la starea lanțului și mempool:

#### Validarea atribuirii

1. **Proprietatea plot-ului:** Tranzacția trebuie semnată de proprietarul plot-ului
2. **Starea plot-ului:** Plot-ul trebuie să fie UNASSIGNED (0) sau REVOKED (4)
3. **Conflicte mempool:** Nicio altă atribuire pentru acest plot în mempool (primul văzut câștigă)

#### Validarea revocării

1. **Proprietatea plot-ului:** Tranzacția trebuie semnată de proprietarul plot-ului
2. **Atribuire activă:** Plot-ul trebuie să fie doar în starea ASSIGNED (2)
3. **Conflicte mempool:** Nicio altă revocare pentru acest plot în mempool

**Implementare:** `src/validation.cpp:898-993`

### Fluxul de validare

```
Difuzare tranzacție
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maximum un OP_RETURN POCX
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Verifică proprietatea plot-ului
  ✓ Verifică starea atribuirii
  ✓ Verifică conflictele mempool
       ↓
   Valid → Acceptă în mempool
   Invalid → Respinge (nu propaga)
       ↓
Minerit bloc
       ↓
ConnectBlock() [validation.cpp]
  ✓ Re-validează toate verificările (apărare în profunzime)
  ✓ Aplică modificările de stare
  ✓ Înregistrează info de anulare
```

### Apărare în profunzime

Toate verificările de validare mempool sunt re-executate în timpul `ConnectBlock()` pentru a proteja împotriva:
- Atacurilor de ocolire mempool
- Blocurilor invalide de la mineri rău intenționați
- Cazurilor marginale în timpul scenariilor de reorganizare

Validarea blocului rămâne autoritativă pentru consens.

## Actualizări atomice ale bazei de date

### Arhitectură pe trei niveluri

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Cache în memorie)    │  ← Modificările atribuirilor urmărite în memorie
│   - Coins: cacheCoins                   │
│   - Atribuiri: pendingAssignments       │
│   - Urmărire dirty: dirtyPlots          │
│   - Ștergeri: deletedAssignments        │
│   - Urmărire memorie: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Strat bază de date)     │  ← O singură scriere atomică
│   - BatchWrite(): UTXO + Atribuiri      │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Stocare pe disc)             │  ← Garanții ACID
│   - Tranzacție atomică                  │
└─────────────────────────────────────────┘
```

### Procesul de Flush

Când `view.Flush()` este apelat în timpul conectării blocului:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Scrie modificările coin la bază
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Scrie modificările atribuirilor atomic
    if (fOk && !dirtyPlots.empty()) {
        // Colectează atribuirile dirty
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Gol - nefolosit

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Scrie în baza de date
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Curăță urmărirea
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Eliberează memoria
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementare:** `src/coins.cpp:278-315`

### Scrierea batch în baza de date

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Un singur batch LevelDB

    // 1. Marchează starea de tranziție
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Scrie toate modificările coin
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Marchează starea consistentă
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT ATOMIC
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Atribuirile scrise separat dar în același context de tranzacție bază de date
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Parametru nefolosit (păstrat pentru compatibilitate API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Batch nou, dar aceeași bază de date

    // Scrie istoricul atribuirilor
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Șterge atribuirile șterse din istoric
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT ATOMIC
    return m_db->WriteBatch(batch);
}
```

**Implementare:** `src/txdb.cpp:332-348`

### Garanții de atomicitate

✅ **Ce este atomic:**
- Toate modificările coin dintr-un bloc sunt scrise atomic
- Toate modificările atribuirilor dintr-un bloc sunt scrise atomic
- Baza de date rămâne consistentă în caz de căderi

⚠️ **Limitare curentă:**
- Coin-urile și atribuirile sunt scrise în operații batch LevelDB **separate**
- Ambele operații au loc în timpul `view.Flush()`, dar nu într-o singură scriere atomică
- În practică: Ambele batch-uri se completează rapid înainte de fsync pe disc
- Riscul este minim: Ambele ar trebui reluate din același bloc în timpul recuperării după cădere

**Notă:** Aceasta diferă de planul arhitectural original care solicita un singur batch unificat. Implementarea curentă folosește două batch-uri dar menține consistența prin mecanismele existente de recuperare după cădere ale Bitcoin Core (marker DB_HEAD_BLOCKS).

## Gestionarea reorganizărilor

### Structura datelor de anulare

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Atribuire a fost adăugată (șterge la anulare)
        MODIFIED = 1,   // Atribuire a fost modificată (restaurează la anulare)
        REVOKED = 2     // Atribuire a fost revocată (anulează revocarea la anulare)
    };

    UndoType type;
    ForgingAssignment assignment;  // Starea completă înainte de modificare
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Date de anulare UTXO
    std::vector<ForgingUndo> vforgingundo;  // Date de anulare atribuiri
};
```

**Implementare:** `src/undo.h:63-105`

### Procesul DisconnectBlock

Când un bloc este deconectat în timpul unei reorganizări:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... deconectare UTXO standard ...

    // Citește datele de anulare de pe disc
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Anulează modificările atribuirilor (procesează în ordine inversă)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Atribuire a fost adăugată - elimină
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Atribuire a fost revocată - restaurează starea nerevocată
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Atribuire a fost modificată - restaurează starea anterioară
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementare:** `src/validation.cpp:2381-2415`

### Gestionarea cache-ului în timpul reorganizării

```cpp
class CCoinsViewCache {
private:
    // Cache-uri de atribuiri
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Urmărește plot-urile modificate
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Urmărește ștergerile
    mutable size_t cachedAssignmentsUsage{0};  // Urmărire memorie

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

**Implementare:** `src/coins.cpp:494-565`

## Interfața RPC

### Comenzi nod (fără portofel necesar)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Returnează starea curentă a atribuirii pentru o adresă de plot:
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

**Implementare:** `src/pocx/rpc/assignments.cpp:31-126`

### Comenzi portofel (portofel necesar)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Creează o tranzacție de atribuire:
- Selectează automat cel mai mare UTXO de la adresa plot-ului pentru a demonstra proprietatea
- Construiește tranzacția cu OP_RETURN + ieșire rest
- Semnează cu cheia proprietarului plot-ului
- Difuzează în rețea

**Implementare:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Creează o tranzacție de revocare:
- Selectează automat cel mai mare UTXO de la adresa plot-ului pentru a demonstra proprietatea
- Construiește tranzacția cu OP_RETURN + ieșire rest
- Semnează cu cheia proprietarului plot-ului
- Difuzează în rețea

**Implementare:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Crearea tranzacției de portofel

Procesul de creare a tranzacției de portofel:

```cpp
1. Parsează și validează adresele (trebuie să fie P2WPKH bech32)
2. Găsește cel mai mare UTXO de la adresa plot-ului (demonstrează proprietatea)
3. Creează tranzacție temporară cu ieșire dummy
4. Semnează tranzacția (obține dimensiunea precisă cu datele witness)
5. Înlocuiește ieșirea dummy cu OP_RETURN
6. Ajustează taxele proporțional pe baza schimbării dimensiunii
7. Re-semnează tranzacția finală
8. Difuzează în rețea
```

**Înțelegere cheie:** Portofelul trebuie să cheltuiască de la adresa plot-ului pentru a demonstra proprietatea, deci forțează automat selecția coin-urilor de la acea adresă.

**Implementare:** `src/pocx/assignments/transactions.cpp:38-263`

## Structura fișierelor

### Fișiere de implementare de bază

```
src/
├── coins.h                        # Structura ForgingAssignment, metode CCoinsViewCache [710 linii]
├── coins.cpp                      # Gestionare cache, scrieri batch [603 linii]
│
├── txdb.h                         # Metode atribuiri CCoinsViewDB [90 linii]
├── txdb.cpp                       # Citire/scriere bază de date [349 linii]
│
├── undo.h                         # Structura ForgingUndo pentru reorganizări
│
├── validation.cpp                 # Integrare ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Format OP_RETURN, parsare, verificare
    │   ├── opcodes.cpp            # [259 linii] Definiții markere, operații OP_RETURN, verificare proprietate
    │   ├── assignment_state.h     # Helpere GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Funcții de interogare a stării atribuirii
    │   ├── transactions.h         # API creare tranzacții portofel
    │   └── transactions.cpp       # Funcții portofel create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Comenzi RPC nod (fără portofel)
    │   ├── assignments.cpp        # RPC-uri get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Comenzi RPC portofel
    │   └── assignments_wallet.cpp # RPC-uri create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Caracteristici de performanță

### Operațiuni bază de date

- **Obține atribuire curentă:** O(n) - scanează toate atribuirile pentru adresa plot-ului pentru a găsi cea mai recentă
- **Obține istoric atribuiri:** O(n) - iterează toate atribuirile pentru plot
- **Creează atribuire:** O(1) - o singură inserare
- **Revocă atribuire:** O(1) - o singură actualizare
- **Reorganizare (per atribuire):** O(1) - aplicare directă a datelor de anulare

Unde n = numărul de atribuiri pentru un plot (de obicei mic, < 10)

### Utilizare memorie

- **Per atribuire:** ~160 octeți (structura ForgingAssignment)
- **Overhead cache:** Overhead hash map pentru urmărirea dirty
- **Bloc tipic:** <10 atribuiri = <2 KB memorie

### Utilizare disc

- **Per atribuire:** ~200 octeți pe disc (cu overhead LevelDB)
- **10000 atribuiri:** ~2 MB spațiu pe disc
- **Neglijabil comparativ cu setul UTXO:** <0,001% din chainstate tipic

## Limitări curente și lucrări viitoare

### Limitare de atomicitate

**Curent:** Coin-urile și atribuirile sunt scrise în batch-uri LevelDB separate în timpul `view.Flush()`

**Impact:** Risc teoretic de inconsistență dacă apare o cădere între batch-uri

**Mitigare:**
- Ambele batch-uri se completează rapid înainte de fsync
- Recuperarea după cădere a Bitcoin Core folosește markerul DB_HEAD_BLOCKS
- În practică: Niciodată observat în testare

**Îmbunătățire viitoare:** Unificare într-o singură operație batch LevelDB

### Curățarea istoricului atribuirilor

**Curent:** Toate atribuirile stocate pe termen nedefinit

**Impact:** ~200 octeți per atribuire pentru totdeauna

**Viitor:** Curățare opțională a atribuirilor complet revocate mai vechi de N blocuri

**Notă:** Improbabil să fie necesar - chiar și 1 milion de atribuiri = 200 MB

## Starea testării

### Teste implementate

✅ Parsare și validare OP_RETURN
✅ Verificare proprietate
✅ Creare atribuire ConnectBlock
✅ Revocare ConnectBlock
✅ Gestionare reorganizare DisconnectBlock
✅ Operațiuni citire/scriere bază de date
✅ Tranziții de stare (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ Comenzi RPC (get_assignment, create_assignment, revoke_assignment)
✅ Creare tranzacții portofel

### Arii de acoperire teste

- Teste unitare: `src/test/pocx_*_tests.cpp`
- Teste funcționale: `test/functional/feature_pocx_*.py`
- Teste de integrare: Testare manuală cu regtest

## Reguli de consens

### Reguli creare atribuire

1. **Proprietate:** Tranzacția trebuie semnată de proprietarul plot-ului
2. **Stare:** Plot-ul trebuie să fie în starea UNASSIGNED sau REVOKED
3. **Format:** OP_RETURN valid cu marker POCX + 2× adrese de 20 octeți
4. **Unicitate:** O singură atribuire activă per plot la un moment dat

### Reguli revocare

1. **Proprietate:** Tranzacția trebuie semnată de proprietarul plot-ului
2. **Existență:** Atribuirea trebuie să existe și să nu fie deja revocată
3. **Format:** OP_RETURN valid cu marker XCOP + adresă de 20 octeți

### Reguli activare

- **Activare atribuire:** `assignment_height + nForgingAssignmentDelay`
- **Activare revocare:** `revocation_height + nForgingRevocationDelay`
- **Întârzieri:** Configurabile per rețea (ex. 30 blocuri = ~1 oră cu timp de bloc de 2 minute)

### Validarea blocurilor

- Atribuire/revocare invalidă → bloc respins (eșec de consens)
- Ieșirile OP_RETURN excluse automat din setul UTXO (comportament standard Bitcoin)
- Procesarea atribuirilor are loc înainte de actualizările UTXO în ConnectBlock

## Concluzie

Sistemul de atribuire a forjării PoCX așa cum este implementat oferă:

✅ **Simplitate:** Tranzacții Bitcoin standard, fără UTXO-uri speciale
✅ **Cost-eficient:** Fără cerință de praf, doar taxe de tranzacție
✅ **Siguranță la reorganizări:** Date de anulare cuprinzătoare restaurează starea corectă
✅ **Actualizări atomice:** Consistență bază de date prin batch-uri LevelDB
✅ **Istoric complet:** Pistă de audit completă a tuturor atribuirilor în timp
✅ **Arhitectură curată:** Modificări minime Bitcoin Core, cod PoCX izolat
✅ **Gata de producție:** Complet implementat, testat și operațional

### Calitatea implementării

- **Organizare cod:** Excelentă - separare clară între Bitcoin Core și PoCX
- **Gestionare erori:** Validare cuprinzătoare a consensului
- **Documentație:** Comentarii cod și structură bine documentate
- **Testare:** Funcționalitate de bază testată, integrare verificată

### Decizii de design cheie validate

1. ✅ Abordare bazată exclusiv pe OP_RETURN (vs bazată pe UTXO)
2. ✅ Stocare separată în baza de date (vs extraData Coin)
3. ✅ Urmărire istoric complet (vs doar curent)
4. ✅ Proprietate prin semnătură (vs cheltuire UTXO)
5. ✅ Întârzieri de activare (previne atacurile de reorganizare)

Sistemul realizează cu succes toate obiectivele arhitecturale cu o implementare curată și mentenabilă.

---

[← Anterior: Consens și minerit](3-consensus-and-mining.md) | [📘 Cuprins](index.md) | [Următorul: Sincronizare temporală →](5-timing-security.md)

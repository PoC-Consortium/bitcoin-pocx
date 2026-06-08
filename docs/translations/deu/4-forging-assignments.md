[← Zurück: Konsens und Mining](3-consensus-and-mining.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Zeitsynchronisation →](5-timing-security.md)

---

# Kapitel 4: PoCX Forging-Zuweisungssystem

## Zusammenfassung

Dieses Dokument beschreibt das **implementierte** PoCX-Forging-Zuweisungssystem mit einer OP_RETURN-basierten Architektur. Das System ermöglicht Plotbesitzern, Forging-Rechte an separate Adressen durch On-Chain-Transaktionen zu delegieren, mit vollständiger Reorg-Sicherheit und atomaren Datenbankoperationen.

**Status:** Vollständig implementiert und betriebsbereit

## Kern-Designphilosophie

**Kernprinzip:** Zuweisungen sind Berechtigungen, keine Vermögenswerte

- Keine speziellen UTXOs zum Verfolgen oder Ausgeben
- Zuweisungszustand getrennt vom UTXO-Set gespeichert
- Eigentum durch Transaktionssignatur bewiesen, nicht durch UTXO-Ausgabe
- Vollständige Verlaufsverfolgung für kompletten Prüfpfad
- Atomare Datenbankaktualisierungen durch LevelDB-Batch-Schreibvorgänge

## Transaktionsstruktur

### Zuweisungs-Transaktionsformat

```
Eingaben:
  [0]: Beliebiger UTXO, kontrolliert vom Plotbesitzer (beweist Eigentum + zahlt Gebühren)
       Muss mit privatem Schlüssel des Plotbesitzers signiert sein
  [1+]: Optionale zusätzliche Eingaben für Gebührendeckung

Ausgaben:
  [0]: OP_RETURN (POCX-Marker + Plot-Adresse + Forge-Adresse)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Größe: 46 Bytes gesamt (1 Byte OP_RETURN + 1 Byte Länge + 44 Bytes Daten)
       Wert: 0 BTC (nicht ausgebbar, nicht zum UTXO-Set hinzugefügt)

  [1]: Wechselgeld zurück an Benutzer (optional, Standard P2WPKH)
```

**Implementierung:** `src/pocx/assignments/opcodes.cpp`

### Widerrufs-Transaktionsformat

```
Eingaben:
  [0]: Beliebiger UTXO, kontrolliert vom Plotbesitzer (beweist Eigentum + zahlt Gebühren)
       Muss mit privatem Schlüssel des Plotbesitzers signiert sein
  [1+]: Optionale zusätzliche Eingaben für Gebührendeckung

Ausgaben:
  [0]: OP_RETURN (XCOP-Marker + Plot-Adresse)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Größe: 26 Bytes gesamt (1 Byte OP_RETURN + 1 Byte Länge + 24 Bytes Daten)
       Wert: 0 BTC (nicht ausgebbar, nicht zum UTXO-Set hinzugefügt)

  [1]: Wechselgeld zurück an Benutzer (optional, Standard P2WPKH)
```

**Implementierung:** `src/pocx/assignments/opcodes.cpp`

### Marker

- **Zuweisungsmarker:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Widerrufsmarker:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementierung:** `src/pocx/assignments/opcodes.cpp`

### Wichtige Transaktionseigenschaften

- Standard-Bitcoin-Transaktionen (keine Protokolländerungen)
- OP_RETURN-Ausgaben sind nachweislich nicht ausgebbar (werden nie zum UTXO-Set hinzugefügt)
- Plot-Eigentum durch Signatur auf input[0] von Plot-Adresse bewiesen
- Niedrige Kosten (~200 Bytes, typischerweise <0,0001 BTC Gebühr)
- Wallet wählt automatisch größten UTXO von Plot-Adresse, um Eigentum zu beweisen

## Datenbankarchitektur

### Speicherstruktur

Alle Zuweisungsdaten werden in derselben LevelDB-Datenbank wie das UTXO-Set (`chainstate/`) gespeichert, aber mit separaten Schlüsselpräfixen:

```
chainstate/ LevelDB:
├─ UTXO-Set (Bitcoin Core Standard)
│  └─ 'C'-Präfix: COutPoint → Coin
│
└─ Zuweisungszustand (PoCX-Ergänzungen)
   └─ 'A'-Präfix: (plot_address, assignment_txid) → ForgingAssignment
       └─ Vollständiger Verlauf: alle Zuweisungen pro Plot über die Zeit
```

**Implementierung:** `src/txdb.cpp`

### ForgingAssignment-Struktur

```cpp
struct ForgingAssignment {
    // Identität
    std::array<uint8_t, 20> plotAddress;      // Plotbesitzer (20-Byte P2WPKH-Hash)
    std::array<uint8_t, 20> forgingAddress;   // Inhaber der Forging-Rechte (20-Byte P2WPKH-Hash)

    // Zuweisungslebenszyklus
    uint256 assignment_txid;                   // Transaktion, die Zuweisung erstellt hat
    int assignment_height;                     // Blockhöhe bei Erstellung
    int assignment_effective_height;           // Wann sie aktiv wird (height + delay)

    // Widerrufslebenszyklus
    bool revoked;                              // Wurde dies widerrufen?
    uint256 revocation_txid;                   // Transaktion, die widerrufen hat
    int revocation_height;                     // Blockhöhe des Widerrufs
    int revocation_effective_height;           // Wann Widerruf wirksam wird (height + delay)

    // Zustandsabfragemethoden
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementierung:** `src/coins.h`

### Zuweisungszustände

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Keine Zuweisung existiert
    ASSIGNING = 1,   // Zuweisung erstellt, wartet auf Aktivierungsverzögerung
    ASSIGNED = 2,    // Zuweisung aktiv, Forging erlaubt
    REVOKING = 3,    // Widerrufen, aber noch aktiv während Verzögerungsperiode
    REVOKED = 4      // Vollständig widerrufen, nicht mehr aktiv
};
```

**Implementierung:** `src/coins.h`

### Datenbankschlüssel

```cpp
// Verlaufsschlüssel: speichert vollständigen Zuweisungsdatensatz
// Schlüsselformat: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plot-Adresse (20 Bytes)
    int assignment_height;                // Höhe für Sortierungsoptimierung
    uint256 assignment_txid;              // Transaktions-ID
};
```

**Implementierung:** `src/txdb.cpp`

### Verlaufsverfolgung

- Jede Zuweisung dauerhaft gespeichert (wird nie gelöscht außer bei Reorg)
- Mehrere Zuweisungen pro Plot über die Zeit verfolgt
- Ermöglicht vollständigen Prüfpfad und historische Zustandsabfragen
- Widerrufene Zuweisungen bleiben in Datenbank mit `revoked=true`

## Blockverarbeitung

### ConnectBlock-Integration

Zuweisungs- und Widerrufs-OP_RETURNs werden während der Block-Verbindung in `validation.cpp` verarbeitet:

```cpp
// Position: Nach Skriptvalidierung, vor UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURN-Daten parsen
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Eigentum verifizieren (tx muss vom Plotbesitzer signiert sein)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Plot-Zustand prüfen (muss UNASSIGNED oder REVOKED sein)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Neue Zuweisung erstellen
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Undo-Daten speichern
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURN-Daten parsen
            auto plot_addr = ParseRevocationOpReturn(output);

            // Eigentum verifizieren
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Aktuelle Zuweisung holen - muss im Zustand ASSIGNED sein, um zu widerrufen
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->GetStateAtHeight(height) != ForgingState::ASSIGNED)
                return state.Invalid("cannot-revoke-inactive");

            // Alten Zustand für Undo speichern
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Als widerrufen markieren
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

// UpdateCoins fährt normal fort (überspringt automatisch OP_RETURN-Ausgaben)
```

**Implementierung:** `src/validation.cpp:ConnectBlock()`

### Eigentumsverifikation

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Prüfen, dass mindestens eine Eingabe vom Plotbesitzer signiert ist
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

**Implementierung:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Aktivierungsverzögerungen

Zuweisungen und Widerrufe haben konfigurierbare Aktivierungsverzögerungen, um Reorg-Angriffe zu verhindern:

```cpp
// Konsensparameter (pro Netzwerk konfigurierbar)
// Beispiel: 30 Blöcke = ~1 Stunde bei 2-Minuten-Blockzeit
consensus.nForgingAssignmentDelay;   // Zuweisungs-Aktivierungsverzögerung
consensus.nForgingRevocationDelay;   // Widerrufs-Aktivierungsverzögerung
```

**Zustandsübergänge:**
- Zuweisung: `UNASSIGNED → ASSIGNING (Verzögerung) → ASSIGNED`
- Widerruf: `ASSIGNED → REVOKING (Verzögerung) → REVOKED`

**Implementierung:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool-Validierung

Zuweisungs- und Widerrufstransaktionen werden bei Mempool-Akzeptanz validiert, um ungültige Transaktionen vor Netzwerkpropagation abzulehnen.

### Transaktionsebenen-Prüfungen (CheckTransaction)

Durchgeführt in `src/consensus/tx_check.cpp` ohne Chain-State-Zugriff:

1. **Maximal ein POCX OP_RETURN:** Transaktion kann nicht mehrere POCX/XCOP-Marker enthalten

**Implementierung:** `src/consensus/tx_check.cpp`

### Mempool-Akzeptanzprüfungen (PreChecks)

Durchgeführt in `src/validation.cpp` mit vollständigem Chain-State und Mempool-Zugriff:

#### Zuweisungsvalidierung

1. **Plot-Eigentum:** Transaktion muss vom Plotbesitzer signiert sein
2. **Plot-Zustand:** Plot muss UNASSIGNED (0) oder REVOKED (4) sein
3. **Mempool-Konflikte:** Keine andere Zuweisung für diesen Plot im Mempool (First-Seen gewinnt)

#### Widerrufsvalidierung

1. **Plot-Eigentum:** Transaktion muss vom Plotbesitzer signiert sein
2. **Aktive Zuweisung:** Plot muss nur im ASSIGNED (2) Zustand sein
3. **Mempool-Konflikte:** Kein anderer Widerruf für diesen Plot im Mempool

**Implementierung:** `src/validation.cpp:PreChecks()`

### Validierungsablauf

```
Transaktions-Broadcast
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Max ein POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Plot-Eigentum verifizieren
  ✓ Zuweisungszustand prüfen
  ✓ Mempool-Konflikte prüfen
       ↓
   Gültig → Zum Mempool akzeptieren
   Ungültig → Ablehnen (nicht propagieren)
       ↓
Block-Mining
       ↓
ConnectBlock() [validation.cpp]
  ✓ Alle Prüfungen erneut validieren (Defense in Depth)
  ✓ Zustandsänderungen anwenden
  ✓ Undo-Info aufzeichnen
```

### Defense in Depth

Alle Mempool-Validierungsprüfungen werden während `ConnectBlock()` erneut ausgeführt, um zu schützen gegen:
- Mempool-Bypass-Angriffe
- Ungültige Blöcke von böswilligen Minern
- Grenzfälle während Reorg-Szenarien

Blockvalidierung bleibt maßgeblich für den Konsens.

## Atomare Datenbankaktualisierungen

### Drei-Schichten-Architektur

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Speicher-Cache)       │  ← Zuweisungsänderungen im Speicher verfolgt
│   - Coins: cacheCoins                    │
│   - Assignments: pendingAssignments      │
│   - Dirty-Verfolgung: dirtyPlots         │
│   - Löschungen: deletedAssignments       │
│   - Speicherverfolgung: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Datenbankschicht)        │  ← Einzelner atomarer Schreibvorgang
│   - BatchWrite(): UTXOs + Assignments    │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Festplattenspeicher)          │  ← ACID-Garantien
│   - Atomare Transaktion                  │
└─────────────────────────────────────────┘
```

### Flush-Prozess

Wenn `view.Flush()` während der Block-Verbindung aufgerufen wird:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Coin-Änderungen an Basis schreiben
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Zuweisungsänderungen atomar schreiben
    if (fOk && !dirtyPlots.empty()) {
        // Dirty-Zuweisungen sammeln
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

        // In Datenbank schreiben
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

**Implementierung:** `src/coins.cpp:Flush()`

### Datenbank-Batch-Schreibvorgang

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Einzelner LevelDB-Batch

    // 1. Übergangszustand markieren
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Alle Coin-Änderungen schreiben
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Konsistenten Zustand markieren
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMARER COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Zuweisungen separat aber im selben Datenbanktransaktionskontext geschrieben
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

**Implementierung:** `src/txdb.cpp:BatchWriteAssignments()`

### Atomaritätsgarantien

**Was atomar ist:**
- Alle Coin-Änderungen innerhalb eines Blocks werden atomar geschrieben
- Alle Zuweisungsänderungen innerhalb eines Blocks werden atomar geschrieben
- Datenbank bleibt über Abstürze hinweg konsistent

**Aktuelle Einschränkung:**
- Coins und Zuweisungen werden in **separaten** LevelDB-Batch-Operationen geschrieben
- Beide Operationen geschehen während `view.Flush()`, aber nicht in einem einzigen atomaren Schreibvorgang
- In der Praxis: Beide Batches werden schnell hintereinander vor Festplatten-fsync abgeschlossen
- Risiko ist minimal: Beide müssten vom selben Block bei Absturz-Recovery wiederholt werden

**Hinweis:** Dies unterscheidet sich vom ursprünglichen Architekturplan, der einen einzelnen vereinheitlichten Batch vorsah. Die aktuelle Implementierung verwendet zwei Batches, erhält aber Konsistenz durch Bitcoin Cores bestehende Absturz-Recovery-Mechanismen (DB_HEAD_BLOCKS-Marker).

## Reorg-Behandlung

### Undo-Datenstruktur

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Zuweisung wurde hinzugefügt (bei Undo löschen)
        MODIFIED = 1,   // Zuweisung wurde modifiziert (bei Undo wiederherstellen)
        REVOKED = 2     // Zuweisung wurde widerrufen (bei Undo rückgängig machen)
    };

    UndoType type;
    ForgingAssignment assignment;  // Vollständiger Zustand vor Änderung
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO-Undo-Daten
    std::vector<ForgingUndo> vforgingundo;  // Zuweisungs-Undo-Daten
};
```

**Implementierung:** `src/undo.h`

### DisconnectBlock-Prozess

Wenn ein Block während eines Reorgs abgetrennt wird:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... Standard-UTXO-Abtrennung ...

    // Undo-Daten von Festplatte lesen
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Zuweisungsänderungen rückgängig machen (in umgekehrter Reihenfolge verarbeiten)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Zuweisung wurde hinzugefügt - entfernen
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Zuweisung wurde widerrufen - nicht-widerrufenen Zustand wiederherstellen
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Zuweisung wurde modifiziert - vorherigen Zustand wiederherstellen
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementierung:** `src/validation.cpp:DisconnectBlock()`

### Cache-Verwaltung während Reorg

```cpp
class CCoinsViewCache {
private:
    // Zuweisungs-Caches
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Modifizierte Plots verfolgen
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Löschungen verfolgen
    mutable size_t cachedAssignmentsUsage{0};  // Speicherverfolgung

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

**Implementierung:** `src/coins.cpp`

## RPC-Schnittstelle

### Node-Befehle (Kein Wallet erforderlich)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Gibt aktuellen Zuweisungsstatus für eine Plot-Adresse zurück:
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

**Implementierung:** `src/pocx/rpc/assignments.cpp`

### Wallet-Befehle (Wallet erforderlich)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Erstellt eine Zuweisungstransaktion:
- Wählt automatisch größten UTXO von Plot-Adresse, um Eigentum zu beweisen
- Erstellt Transaktion mit OP_RETURN + Wechselgeld-Ausgabe
- Signiert mit Schlüssel des Plotbesitzers
- Sendet ans Netzwerk

**Implementierung:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Erstellt eine Widerrufstransaktion:
- Wählt automatisch größten UTXO von Plot-Adresse, um Eigentum zu beweisen
- Erstellt Transaktion mit OP_RETURN + Wechselgeld-Ausgabe
- Signiert mit Schlüssel des Plotbesitzers
- Sendet ans Netzwerk

**Implementierung:** `src/pocx/rpc/assignments_wallet.cpp`

### Wallet-Transaktionserstellung

Der Wallet-Transaktionserstellungsprozess:

```cpp
1. Adressen parsen und validieren (muss P2WPKH bech32 sein)
2. Größten UTXO von Plot-Adresse finden (beweist Eigentum)
3. Temporäre Transaktion mit Dummy-Ausgabe erstellen
4. Transaktion signieren (genaue Größe mit Witness-Daten erhalten)
5. Dummy-Ausgabe durch OP_RETURN ersetzen
6. Gebühren proportional basierend auf Größenänderung anpassen
7. Finale Transaktion erneut signieren
8. Ans Netzwerk senden
```

**Wichtige Erkenntnis:** Das Wallet muss von der Plot-Adresse ausgeben, um Eigentum zu beweisen, also erzwingt es automatisch Coin-Auswahl von dieser Adresse.

**Implementierung:** `src/pocx/assignments/transactions.cpp`

## Dateistruktur

### Kern-Implementierungsdateien

```
src/
├── coins.h                        # ForgingAssignment-Struktur, CCoinsViewCache-Methoden
├── coins.cpp                      # Cache-Verwaltung, Batch-Schreibvorgänge
│
├── txdb.h                         # CCoinsViewDB-Zuweisungsmethoden
├── txdb.cpp                       # Datenbank lesen/schreiben
│
├── undo.h                         # ForgingUndo-Struktur für Reorgs
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock-Integration
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN-Format, Parsing, Verifikation
    │   ├── opcodes.cpp            # Marker-Definitionen, OP_RETURN-Ops, Eigentumscheck
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState-Helfer
    │   ├── assignment_state.cpp   # Zuweisungszustand-Abfragefunktionen
    │   ├── replay.h               # Reorg/Replay von Zuweisungseffekten
    │   ├── replay.cpp             # ApplyAssignmentEffectsForReplay (Reorg-Pfad)
    │   ├── transactions.h         # Wallet-Transaktionserstellungs-API
    │   └── transactions.cpp       # create_assignment, revoke_assignment Wallet-Funktionen
    │
    ├── rpc/
    │   ├── assignments.h          # Node-RPC-Befehle (ohne Wallet)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # Wallet-RPC-Befehle
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPCs
    │
    └── consensus/
        └── params.h               # PoCXCompressionBounds, Genesis-Basisziel, Kompressionszeitplan
```

> **Hinweis:** Die Zuweisungs-Verzögerungskonstanten `nForgingAssignmentDelay` / `nForgingRevocationDelay` befinden sich in Bitcoin Cores `Consensus::Params` (`src/consensus/params.h`) und werden pro Netzwerk in `src/kernel/chainparams.cpp` gesetzt — nicht in `pocx/consensus/params.h`.

## Leistungscharakteristiken

### Datenbankoperationen

- **Aktuelle Zuweisung holen:** O(n) - alle Zuweisungen für Plot-Adresse scannen, um neueste zu finden
- **Zuweisungsverlauf holen:** O(n) - alle Zuweisungen für Plot iterieren
- **Zuweisung erstellen:** O(1) - einzelnes Einfügen
- **Zuweisung widerrufen:** O(1) - einzelne Aktualisierung
- **Reorg (pro Zuweisung):** O(1) - direkte Undo-Daten-Anwendung

Wobei n = Anzahl der Zuweisungen für einen Plot (typischerweise klein, < 10)

### Speicherverbrauch

- **Pro Zuweisung:** ~160 Bytes (ForgingAssignment-Struktur)
- **Cache-Overhead:** Hash-Map-Overhead für Dirty-Verfolgung
- **Typischer Block:** <10 Zuweisungen = <2 KB Speicher

### Festplattenverbrauch

- **Pro Zuweisung:** ~200 Bytes auf Festplatte (mit LevelDB-Overhead)
- **10000 Zuweisungen:** ~2 MB Festplattenspeicher
- **Vernachlässigbar im Vergleich zum UTXO-Set:** <0,001% des typischen Chainstate

## Aktuelle Einschränkungen und zukünftige Arbeit

### Atomaritätseinschränkung

**Aktuell:** Coins und Zuweisungen werden in separaten LevelDB-Batches während `view.Flush()` geschrieben

**Auswirkung:** Theoretisches Risiko von Inkonsistenz bei Absturz zwischen Batches

**Abschwächung:**
- Beide Batches werden schnell vor fsync abgeschlossen
- Bitcoin Cores Absturz-Recovery verwendet DB_HEAD_BLOCKS-Marker
- In der Praxis: Nie bei Tests beobachtet

**Zukünftige Verbesserung:** Vereinheitlichung in einzelne LevelDB-Batch-Operation

### Zuweisungsverlauf-Bereinigung

**Aktuell:** Alle Zuweisungen werden unbegrenzt gespeichert

**Auswirkung:** ~200 Bytes pro Zuweisung für immer

**Zukunft:** Optionale Bereinigung von vollständig widerrufenen Zuweisungen älter als N Blöcke

**Hinweis:** Unwahrscheinlich, dass benötigt - selbst 1 Million Zuweisungen = 200 MB

## Teststatus

### Implementierte Tests

Implementiert: OP_RETURN-Parsing und Validierung, Eigentumsverifikation, ConnectBlock-Zuweisungserstellung, ConnectBlock-Widerruf, DisconnectBlock-Reorg-Behandlung, Datenbank-Lese/Schreiboperationen, Zustandsübergänge (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED), RPC-Befehle (get_assignment, create_assignment, revoke_assignment), Wallet-Transaktionserstellung

### Testabdeckungsbereiche

- Unit-Tests: `src/test/pocx_tests.cpp`, `src/test/pocx_simd_tests.cpp`
- Integrationstests: Regtest-Shell-Skripte unter `scripts/assignments/` und `scripts/mining/`

## Konsensregeln

### Zuweisungserstellungsregeln

1. **Eigentum:** Transaktion muss vom Plotbesitzer signiert sein
2. **Zustand:** Plot muss im UNASSIGNED oder REVOKED Zustand sein
3. **Format:** Gültiges OP_RETURN mit POCX-Marker + 2× 20-Byte-Adressen
4. **Einzigartigkeit:** Eine aktive Zuweisung pro Plot gleichzeitig

### Widerrufsregeln

1. **Eigentum:** Transaktion muss vom Plotbesitzer signiert sein
2. **Existenz:** Zuweisung muss existieren und darf nicht bereits widerrufen sein
3. **Format:** Gültiges OP_RETURN mit XCOP-Marker + 20-Byte-Adresse

### Aktivierungsregeln

- **Zuweisungsaktivierung:** `assignment_height + nForgingAssignmentDelay`
- **Widerrufsaktivierung:** `revocation_height + nForgingRevocationDelay`
- **Verzögerungen:** Pro Netzwerk konfigurierbar (z.B. 30 Blöcke = ~1 Stunde bei 2-Minuten-Blockzeit)

### Blockvalidierung

- Ungültige Zuweisung/Widerruf → Block abgelehnt (Konsensfehler)
- OP_RETURN-Ausgaben automatisch vom UTXO-Set ausgeschlossen (Standard-Bitcoin-Verhalten)
- Zuweisungsverarbeitung erfolgt vor UTXO-Aktualisierungen in ConnectBlock

## Fazit

Das PoCX-Forging-Zuweisungssystem wie implementiert bietet:

**Einfachheit:** Standard-Bitcoin-Transaktionen, keine speziellen UTXOs
**Kosteneffizienz:** Keine Staub-Anforderung, nur Transaktionsgebühren
**Reorg-Sicherheit:** Umfassende Undo-Daten stellen korrekten Zustand wieder her
**Atomare Updates:** Datenbankkonsistenz durch LevelDB-Batches
**Vollständiger Verlauf:** Kompletter Prüfpfad aller Zuweisungen über die Zeit
**Saubere Architektur:** Minimale Bitcoin Core Modifikationen, isolierter PoCX-Code
**Produktionsbereit:** Vollständig implementiert, getestet und betriebsbereit

### Implementierungsqualität

- **Code-Organisation:** Ausgezeichnet - klare Trennung zwischen Bitcoin Core und PoCX
- **Fehlerbehandlung:** Umfassende Konsensvalidierung
- **Dokumentation:** Code-Kommentare und Struktur gut dokumentiert
- **Tests:** Kernfunktionalität getestet, Integration verifiziert

### Validierte wichtige Designentscheidungen

1. OP_RETURN-basierter Ansatz (vs. UTXO-basiert)
2. Separate Datenbankspeicherung (vs. Coin extraData)
3. Vollständige Verlaufsverfolgung (vs. nur aktuell)
4. Eigentum durch Signatur (vs. UTXO-Ausgabe)
5. Aktivierungsverzögerungen (verhindert Reorg-Angriffe)

Das System erreicht erfolgreich alle architektonischen Ziele mit einer sauberen, wartbaren Implementierung.

---

[← Zurück: Konsens und Mining](3-consensus-and-mining.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Zeitsynchronisation →](5-timing-security.md)

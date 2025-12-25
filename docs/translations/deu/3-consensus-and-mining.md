[← Zurück: Plot-Format](2-plot-format.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Forging-Zuweisungen →](4-forging-assignments.md)

---

# Kapitel 3: Bitcoin-PoCX Konsens- und Mining-Prozess

Vollständige technische Spezifikation des PoCX (Proof of Capacity neXt generation) Konsensmechanismus und Mining-Prozesses, integriert in Bitcoin Core.

---

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Konsensarchitektur](#konsensarchitektur)
3. [Mining-Prozess](#mining-prozess)
4. [Blockvalidierung](#blockvalidierung)
5. [Zuweisungssystem](#zuweisungssystem)
6. [Netzwerkpropagation](#netzwerkpropagation)
7. [Technische Details](#technische-details)

---

## Übersicht

Bitcoin-PoCX implementiert einen reinen Proof of Capacity Konsensmechanismus als vollständigen Ersatz für Bitcoins Proof of Work. Dies ist eine neue Chain ohne Rückwärtskompatibilitätsanforderungen.

**Kerneigenschaften:**
- **Energieeffizient:** Mining verwendet vorab generierte Plotdateien anstelle von rechnerischem Hashen
- **Time-Bended Deadlines:** Verteilungstransformation (exponentiell→Chi-Quadrat) reduziert lange Blöcke, verbessert durchschnittliche Blockzeiten
- **Zuweisungsunterstützung:** Plotbesitzer können Forging-Rechte an andere Adressen delegieren
- **Native C++-Integration:** Kryptografische Algorithmen in C++ für Konsensvalidierung implementiert

**Mining-Ablauf:**
```
Externer Miner → get_mining_info → Nonce berechnen → submit_nonce →
Forger-Warteschlange → Deadline-Wartezeit → Block-Forging → Netzwerkpropagation →
Blockvalidierung → Chain-Erweiterung
```

---

## Konsensarchitektur

### Blockstruktur

PoCX-Blöcke erweitern Bitcoins Blockstruktur mit zusätzlichen Konsensfeldern:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot-Seed (32 Bytes)
    std::array<uint8_t, 20> account_id;       // Plot-Adresse (20-Byte hash160)
    uint32_t compression;                     // Skalierungsstufe (1-255)
    uint64_t nonce;                           // Mining-Nonce (64-bit)
    uint64_t quality;                         // Beanspruchte Qualität (PoC-Hash-Ausgabe)
};

class CBlockHeader {
    // Standard Bitcoin-Felder
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-Konsensfelder (ersetzen nBits und nNonce)
    int nHeight;                              // Blockhöhe (kontextfreie Validierung)
    uint256 generationSignature;              // Generierungssignatur (Mining-Entropie)
    uint64_t nBaseTarget;                     // Schwierigkeitsparameter (inverse Schwierigkeit)
    PoCXProof pocxProof;                      // Mining-Beweis

    // Blocksignaturfelder
    std::array<uint8_t, 33> vchPubKey;        // Komprimierter öffentlicher Schlüssel (33 Bytes)
    std::array<uint8_t, 65> vchSignature;     // Kompakte Signatur (65 Bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaktionen
};
```

**Hinweis:** Die Signatur (`vchSignature`) wird von der Block-Hash-Berechnung ausgeschlossen, um Veränderbarkeit zu verhindern.

**Implementierung:** `src/primitives/block.h`

### Generierungssignatur

Die Generierungssignatur erzeugt Mining-Entropie und verhindert Vorberechnungsangriffe.

**Berechnung:**
```
generationSignature = SHA256(vorherige_generationSignature || vorheriger_miner_pubkey)
```

**Genesis-Block:** Verwendet eine fest kodierte initiale Generierungssignatur

**Implementierung:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Basisziel (Schwierigkeit)

Das Basisziel ist der Kehrwert der Schwierigkeit – höhere Werte bedeuten einfacheres Mining.

**Anpassungsalgorithmus:**
- Ziel-Blockzeit: 120 Sekunden (Mainnet), 1 Sekunde (Regtest)
- Anpassungsintervall: Jeder Block
- Verwendet gleitenden Durchschnitt der letzten Basisziele
- Begrenzt, um extreme Schwierigkeitsschwankungen zu verhindern

**Implementierung:** `src/consensus/params.h`, Schwierigkeitsanpassung bei Blockerstellung

### Skalierungsstufen

PoCX unterstützt skalierbares Proof-of-Work in Plotdateien durch Skalierungsstufen (Xn).

**Dynamische Grenzen:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimal akzeptierte Stufe
    uint8_t nPoCXTargetCompression;  // Empfohlene Stufe
};
```

**Zeitplan für Skalierungserhöhung:**
- Exponentielle Intervalle: Jahre 4, 12, 28, 60, 124 (Halvings 1, 3, 7, 15, 31)
- Minimale Skalierungsstufe erhöht sich um 1
- Ziel-Skalierungsstufe erhöht sich um 1
- Erhält Sicherheitsmarge zwischen Plot-Erstellungs- und Lookup-Kosten
- Maximale Skalierungsstufe: 255

**Implementierung:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Mining-Prozess

### 1. Mining-Informationsabruf

**RPC-Befehl:** `get_mining_info`

**Prozess:**
1. Rufe `GetNewBlockContext(chainman)` auf, um aktuellen Blockchain-Status zu holen
2. Berechne dynamische Kompressionsgrenzen für aktuelle Höhe
3. Gib Mining-Parameter zurück

**Antwort:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementierung:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Hinweise:**
- Keine Sperren während der Antworterzeugung gehalten
- Kontexterfassung behandelt `cs_main` intern
- `block_hash` zur Referenz enthalten, aber nicht bei Validierung verwendet

### 2. Externes Mining

**Verantwortlichkeiten des externen Miners:**
1. Plotdateien von Festplatte lesen
2. Scoop basierend auf Generierungssignatur und Höhe berechnen
3. Nonce mit bester Deadline finden
4. An Node via `submit_nonce` übermitteln

**Plotdateiformat:**
- Basiert auf POC2-Format (Burstcoin)
- Erweitert mit Sicherheitskorrekturen und Skalierbarkeitsverbesserungen
- Siehe Attribution in `CLAUDE.md`

**Miner-Implementierung:** Extern (z.B. basierend auf Scavenger)

### 3. Nonce-Übermittlung und Validierung

**RPC-Befehl:** `submit_nonce`

**Parameter:**
```
height, generation_signature, account_id, seed, nonce, quality (optional)
```

**Validierungsablauf (optimierte Reihenfolge):**

#### Schritt 1: Schnelle Formatvalidierung
```cpp
// Konto-ID: 40 Hex-Zeichen = 20 Bytes
if (account_id.length() != 40 || !IsHex(account_id)) ablehnen;

// Seed: 64 Hex-Zeichen = 32 Bytes
if (seed.length() != 64 || !IsHex(seed)) ablehnen;
```

#### Schritt 2: Kontexterfassung
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Gibt zurück: height, generation_signature, base_target, block_hash
```

**Sperrung:** `cs_main` intern behandelt, keine Sperren im RPC-Thread gehalten

#### Schritt 3: Kontextvalidierung
```cpp
// Höhenprüfung
if (height != context.height) ablehnen;

// Generierungssignaturprüfung
if (übermittelte_gen_sig != context.generation_signature) ablehnen;
```

#### Schritt 4: Wallet-Verifikation
```cpp
// Effektiven Unterzeichner bestimmen (unter Berücksichtigung von Zuweisungen)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Prüfen, ob Node privaten Schlüssel für effektiven Unterzeichner hat
if (!HaveAccountKey(effective_signer, wallet)) ablehnen;
```

**Zuweisungsunterstützung:** Plotbesitzer kann Forging-Rechte an eine andere Adresse zuweisen. Wallet muss Schlüssel für den effektiven Unterzeichner haben, nicht unbedingt den Plotbesitzer.

#### Schritt 5: Beweisvalidierung
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 Bytes
    block_height,
    nonce,
    seed,                // 32 Bytes
    min_compression,
    max_compression,
    &result             // Ausgabe: quality, deadline
);
```

**Algorithmus:**
1. Generierungssignatur aus Hex dekodieren
2. Beste Qualität im Kompressionsbereich mit SIMD-optimierten Algorithmen berechnen
3. Validieren, dass Qualität Schwierigkeitsanforderungen erfüllt
4. Rohen Qualitätswert zurückgeben

**Implementierung:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Schritt 6: Time-Bending-Berechnung
```cpp
// Roh schwierigkeitsangepasste Deadline (Sekunden)
uint64_t deadline_seconds = quality / base_target;

// Time-Bended Forge-Zeit (Sekunden)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time-Bending-Formel:**
```
Y = scale * (X^(1/3))
wobei:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Zweck:** Transformiert Exponential- zu Chi-Quadrat-Verteilung. Sehr gute Lösungen werden später geschmiedet (Netzwerk hat Zeit, Festplatten zu scannen), schlechte Lösungen werden verbessert. Reduziert lange Blöcke, erhält 120s Durchschnitt.

**Implementierung:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Schritt 7: Forger-Übermittlung
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NICHT Deadline - wird im Forger neu berechnet
    height,
    generation_signature
);
```

**Warteschlangen-basiertes Design:**
- Übermittlung ist immer erfolgreich (zur Warteschlange hinzugefügt)
- RPC kehrt sofort zurück
- Worker-Thread verarbeitet asynchron

**Implementierung:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-Warteschlangenverarbeitung

**Architektur:**
- Einzelner persistenter Worker-Thread
- FIFO-Übermittlungswarteschlange
- Sperrfreier Forging-Zustand (nur Worker-Thread)
- Keine verschachtelten Sperren (Deadlock-Prävention)

**Worker-Thread-Hauptschleife:**
```cpp
while (!shutdown) {
    // 1. Auf Warteschlangenübermittlungen prüfen
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Auf Deadline oder neue Übermittlung warten
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-Logik:**
```cpp
1. Frischen Kontext holen: GetNewBlockContext(*chainman)

2. Veraltungsprüfungen (stilles Verwerfen):
   - Höhenabweichung → verwerfen
   - Generierungssignaturabweichung → verwerfen
   - Tip-Block-Hash geändert (Reorg) → Forging-Zustand zurücksetzen

3. Qualitätsvergleich:
   - Falls quality >= current_best → verwerfen

4. Time-Bended Deadline berechnen:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Forging-Zustand aktualisieren:
   - Bestehendes Forging abbrechen (falls besseres gefunden)
   - Speichern: account_id, seed, nonce, quality, deadline
   - Berechnen: forge_time = block_time + deadline_seconds
   - Tip-Hash für Reorg-Erkennung speichern
```

**Implementierung:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline-Wartezeit und Block-Forging

**WaitForDeadlineOrNewSubmission:**

**Wartebedingungen:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Bei erreichter Deadline - Frische Kontextvalidierung:**
```cpp
1. Aktuellen Kontext holen: GetNewBlockContext(*chainman)

2. Höhenvalidierung:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generierungssignatur-Validierung:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Basisziel-Grenzfall:
   if (forging_base_target != current_base_target) {
       // Deadline mit neuem Basisziel neu berechnen
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Erneut warten
   }

5. Alles gültig → ForgeBlock()
```

**ForgeBlock-Prozess:**

```cpp
1. Effektiven Unterzeichner bestimmen (Zuweisungsunterstützung):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Coinbase-Skript erstellen:
   coinbase_script = P2WPKH(effective_signer);  // Zahlt an effektiven Unterzeichner

3. Blockvorlage erstellen:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX-Beweis hinzufügen:
   block.pocxProof.account_id = plot_address;    // Ursprüngliche Plot-Adresse
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Merkle-Root neu berechnen:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Block signieren:
   // Schlüssel des effektiven Unterzeichners verwenden (kann vom Plotbesitzer abweichen)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. An Chain übermitteln:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Ergebnisbehandlung:
   if (accepted) {
       log_success();
       reset_forging_state();  // Bereit für nächsten Block
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementierung:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Wichtige Designentscheidungen:**
- Coinbase zahlt an effektiven Unterzeichner (respektiert Zuweisungen)
- Beweis enthält ursprüngliche Plot-Adresse (für Validierung)
- Signatur vom Schlüssel des effektiven Unterzeichners (Eigentumsnachweis)
- Vorlagenerstellung schließt Mempool-Transaktionen automatisch ein

---

## Blockvalidierung

### Eingehende Blockvalidierung

Wenn ein Block vom Netzwerk empfangen oder lokal übermittelt wird, durchläuft er Validierung in mehreren Stufen:

### Stufe 1: Header-Validierung (CheckBlockHeader)

**Kontextfreie Validierung:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-Validierung (wenn ENABLE_POCX definiert):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Basis-Signaturvalidierung (noch keine Zuweisungsunterstützung)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Basis-Signaturvalidierung:**
1. Vorhandensein von Pubkey- und Signaturfeldern prüfen
2. Pubkey-Größe validieren (33 Bytes komprimiert)
3. Signaturgröße validieren (65 Bytes kompakt)
4. Pubkey aus Signatur wiederherstellen: `pubkey.RecoverCompact(hash, signature)`
5. Verifizieren, dass wiederhergestellter Pubkey mit gespeichertem Pubkey übereinstimmt

**Implementierung:** `src/validation.cpp:CheckBlockHeader()`
**Signaturlogik:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Stufe 2: Block-Validierung (CheckBlock)

**Validiert:**
- Merkle-Root-Korrektheit
- Transaktionsgültigkeit
- Coinbase-Anforderungen
- Blockgrößenlimits
- Standard Bitcoin-Konsensregeln

**Implementierung:** `src/consensus/validation.cpp:CheckBlock()`

### Stufe 3: Kontextuelle Header-Validierung (ContextualCheckBlockHeader)

**PoCX-spezifische Validierung:**

```cpp
#ifdef ENABLE_POCX
    // Schritt 1: Generierungssignatur validieren
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Schritt 2: Basisziel validieren
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Schritt 3: Proof of Capacity validieren
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Schritt 4: Deadline-Timing verifizieren
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validierungsschritte:**
1. **Generierungssignatur:** Muss mit berechnetem Wert vom vorherigen Block übereinstimmen
2. **Basisziel:** Muss mit Schwierigkeitsanpassungsberechnung übereinstimmen
3. **Skalierungsstufe:** Muss Netzwerk-Minimum erfüllen (`compression >= min_compression`)
4. **Qualitätsanspruch:** Übermittelte Qualität muss mit berechneter Qualität aus Beweis übereinstimmen
5. **Proof of Capacity:** Kryptografische Beweisvalidierung (SIMD-optimiert)
6. **Deadline-Timing:** Time-Bended Deadline (`poc_time`) muss ≤ verstrichene Zeit sein

**Implementierung:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Stufe 4: Block-Verbindung (ConnectBlock)

**Vollständige kontextuelle Validierung:**

```cpp
#ifdef ENABLE_POCX
    // Erweiterte Signaturvalidierung mit Zuweisungsunterstützung
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Erweiterte Signaturvalidierung:**
1. Basis-Signaturvalidierung durchführen
2. Konto-ID aus wiederhergestelltem Pubkey extrahieren
3. Effektiven Unterzeichner für Plot-Adresse holen: `GetEffectiveSigner(plot_address, height, view)`
4. Verifizieren, dass Pubkey-Konto mit effektivem Unterzeichner übereinstimmt

**Zuweisungslogik:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Zugewiesenen Unterzeichner zurückgeben
    }

    return plotAddress;  // Keine Zuweisung - Plotbesitzer signiert
}
```

**Implementierung:**
- Verbindung: `src/validation.cpp:ConnectBlock()`
- Erweiterte Validierung: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Zuweisungslogik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Stufe 5: Chain-Aktivierung

**ProcessNewBlock-Ablauf:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validieren und auf Festplatte speichern
    2. ActivateBestChain → Chain-Tip aktualisieren, falls beste Chain
    3. Netzwerk über neuen Block benachrichtigen
}
```

**Implementierung:** `src/validation.cpp:ProcessNewBlock()`

### Validierungszusammenfassung

**Vollständiger Validierungspfad:**
```
Block empfangen
    ↓
CheckBlockHeader (Basis-Signatur)
    ↓
CheckBlock (Transaktionen, Merkle)
    ↓
ContextualCheckBlockHeader (Gen-Sig, Basisziel, PoC-Beweis, Deadline)
    ↓
ConnectBlock (Erweiterte Signatur mit Zuweisungen, Zustandsübergänge)
    ↓
ActivateBestChain (Reorg-Behandlung, Chain-Erweiterung)
    ↓
Netzwerkpropagation
```

---

## Zuweisungssystem

### Übersicht

Zuweisungen ermöglichen Plotbesitzern, Forging-Rechte an andere Adressen zu delegieren, während sie das Plot-Eigentum behalten.

**Anwendungsfälle:**
- Pool-Mining (Plots weisen Pool-Adresse zu)
- Cold Storage (Mining-Schlüssel getrennt vom Plot-Eigentum)
- Multi-Party-Mining (gemeinsame Infrastruktur)

### Zuweisungsarchitektur

**OP_RETURN-basiertes Design:**
- Zuweisungen in OP_RETURN-Ausgaben gespeichert (kein UTXO)
- Keine Ausgabeanforderungen (kein Staub, keine Gebühren fürs Halten)
- In erweitertem CCoinsViewCache-Zustand verfolgt
- Aktiviert nach Verzögerungsperiode (Standard: 4 Blöcke)

**Zuweisungszustände:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Keine Zuweisung existiert
    ASSIGNING = 1,   // Zuweisung wartet auf Aktivierung (Verzögerungsperiode)
    ASSIGNED = 2,    // Zuweisung aktiv, Forging erlaubt
    REVOKING = 3,    // Widerruf ausstehend (Verzögerungsperiode, noch aktiv)
    REVOKED = 4      // Widerruf abgeschlossen, Zuweisung nicht mehr aktiv
};
```

### Zuweisungen erstellen

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Beweist Eigentum an Plot-Adresse
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validierungsregeln:**
1. Eingabe muss vom Plotbesitzer signiert sein (beweist Eigentum)
2. OP_RETURN enthält gültige Zuweisungsdaten
3. Plot muss UNASSIGNED oder REVOKED sein
4. Keine doppelten ausstehenden Zuweisungen im Mempool
5. Minimale Transaktionsgebühr bezahlt

**Aktivierung:**
- Zuweisung wird ASSIGNING bei Bestätigungshöhe
- Wird ASSIGNED nach Verzögerungsperiode (4 Blöcke Regtest, 30 Blöcke Mainnet)
- Verzögerung verhindert schnelle Neuzuweisungen während Block-Races

**Implementierung:** `src/script/forging_assignment.h`, Validierung in ConnectBlock

### Zuweisungen widerrufen

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Beweist Eigentum an Plot-Adresse
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effekt:**
- Sofortiger Zustandsübergang zu REVOKED
- Plotbesitzer kann sofort schmieden
- Kann danach neue Zuweisung erstellen

### Zuweisungsvalidierung beim Mining

**Bestimmung des effektiven Unterzeichners:**
```cpp
// In submit_nonce-Validierung
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) ablehnen;

// Beim Block-Forging
coinbase_script = P2WPKH(effective_signer);  // Belohnung geht hierhin

// Bei Blocksignatur
signature = effective_signer_key.SignCompact(hash);  // Muss mit effektivem Unterzeichner signieren
```

**Blockvalidierung:**
```cpp
// In VerifyPoCXBlockCompactSignature (erweitert)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) ablehnen;
```

**Kerneigenschaften:**
- Beweis enthält immer ursprüngliche Plot-Adresse
- Signatur muss vom effektiven Unterzeichner stammen
- Coinbase zahlt an effektiven Unterzeichner
- Validierung verwendet Zuweisungszustand bei Blockhöhe

---

## Netzwerkpropagation

### Blockankündigung

**Standard Bitcoin P2P-Protokoll:**
1. Geschmiedeter Block via `ProcessNewBlock()` übermittelt
2. Block validiert und zur Chain hinzugefügt
3. Netzwerkbenachrichtigung: `GetMainSignals().BlockConnected()`
4. P2P-Schicht sendet Block an Peers

**Implementierung:** Standard Bitcoin Core net_processing

### Block-Weiterleitung

**Compact Blocks (BIP 152):**
- Verwendet für effiziente Blockpropagation
- Nur Transaktions-IDs werden initial gesendet
- Peers fordern fehlende Transaktionen an

**Vollständige Block-Weiterleitung:**
- Fallback wenn Compact Blocks fehlschlagen
- Vollständige Blockdaten übertragen

### Chain-Reorganisationen

**Reorg-Behandlung:**
```cpp
// Im Forger-Worker-Thread
if (current_tip_hash != stored_tip_hash) {
    // Chain-Reorganisation erkannt
    reset_forging_state();
    log("Chain-Tip geändert, Forging zurückgesetzt");
}
```

**Blockchain-Ebene:**
- Standard Bitcoin Core Reorg-Behandlung
- Beste Chain durch Chainwork bestimmt
- Abgetrennte Blöcke kehren zum Mempool zurück

---

## Technische Details

### Deadlock-Prävention

**ABBA-Deadlock-Muster (verhindert):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Lösung:**
1. **submit_nonce:** Null cs_main-Nutzung
   - `GetNewBlockContext()` behandelt Sperrung intern
   - Alle Validierung vor Forger-Übermittlung

2. **Forger:** Warteschlangen-basierte Architektur
   - Einzelner Worker-Thread (keine Thread-Joins)
   - Frischer Kontext bei jedem Zugriff
   - Keine verschachtelten Sperren

3. **Wallet-Prüfungen:** Vor teuren Operationen durchgeführt
   - Frühe Ablehnung wenn kein Schlüssel verfügbar
   - Getrennt vom Blockchain-Zustandszugriff

### Leistungsoptimierungen

**Schnell-Fehlschlag-Validierung:**
```cpp
1. Formatprüfungen (sofort)
2. Kontextvalidierung (leichtgewichtig)
3. Wallet-Verifikation (lokal)
4. Beweisvalidierung (teuer, SIMD)
```

**Einzelner Kontextabruf:**
- Ein `GetNewBlockContext()`-Aufruf pro Übermittlung
- Ergebnisse für mehrere Prüfungen zwischenspeichern
- Keine wiederholten cs_main-Erfassungen

**Warteschlangen-Effizienz:**
- Leichtgewichtige Übermittlungsstruktur
- Kein base_target/deadline in Warteschlange (frisch neu berechnet)
- Minimaler Speicherbedarf

### Veraltungsbehandlung

**"Einfaches" Forger-Design:**
- Keine Blockchain-Event-Abonnements
- Träge Validierung bei Bedarf
- Stilles Verwerfen veralteter Übermittlungen

**Vorteile:**
- Einfache Architektur
- Keine komplexe Synchronisation
- Robust gegen Grenzfälle

**Behandelte Grenzfälle:**
- Höhenänderungen → verwerfen
- Generierungssignaturänderungen → verwerfen
- Basiszieländerungen → Deadline neu berechnen
- Reorgs → Forging-Zustand zurücksetzen

### Kryptografische Details

**Generierungssignatur:**
```cpp
SHA256(vorherige_generation_signature || vorheriger_miner_pubkey_33bytes)
```

**Block-Signatur-Hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompaktes Signaturformat:**
- 65 Bytes: [recovery_id][r][s]
- Ermöglicht Public-Key-Wiederherstellung
- Verwendet für Platzeffizienz

**Konto-ID:**
- 20-Byte HASH160 des komprimierten Public Key
- Entspricht Bitcoin-Adressformaten (P2PKH, P2WPKH)

### Zukünftige Erweiterungen

**Dokumentierte Einschränkungen:**
1. Keine Leistungsmetriken (Übermittlungsraten, Deadline-Verteilungen)
2. Keine detaillierte Fehlerkategorisierung für Miner
3. Begrenzte Forger-Statusabfrage (aktuelle Deadline, Warteschlangentiefe)

**Mögliche Verbesserungen:**
- RPC für Forger-Status
- Metriken für Mining-Effizienz
- Erweitertes Logging für Debugging
- Pool-Protokoll-Unterstützung

---

## Code-Referenzen

**Kernimplementierungen:**
- RPC-Schnittstelle: `src/pocx/rpc/mining.cpp`
- Forger-Warteschlange: `src/pocx/mining/scheduler.cpp`
- Konsensvalidierung: `src/pocx/consensus/validation.cpp`
- Beweisvalidierung: `src/pocx/consensus/pocx.cpp`
- Time-Bending: `src/pocx/algorithms/time_bending.cpp`
- Blockvalidierung: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Zuweisungslogik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Kontextverwaltung: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datenstrukturen:**
- Blockformat: `src/primitives/block.h`
- Konsensparameter: `src/consensus/params.h`
- Zuweisungsverfolgung: `src/coins.h` (CCoinsViewCache-Erweiterungen)

---

## Anhang: Algorithmusspezifikationen

### Time-Bending-Formel

**Mathematische Definition:**
```
deadline_seconds = quality / base_target  (roh)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

wobei:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementierung:**
- Festkomma-Arithmetik (Q42-Format)
- Reine Integer-Kubikwurzelberechnung
- Optimiert für 256-bit-Arithmetik

### Qualitätsberechnung

**Prozess:**
1. Scoop aus Generierungssignatur und Höhe generieren
2. Plotdaten für berechneten Scoop lesen
3. Hashen: `SHABAL256(generation_signature || scoop_data)`
4. Skalierungsstufen von min bis max testen
5. Beste gefundene Qualität zurückgeben

**Skalierung:**
- Stufe X0: POC2-Baseline (theoretisch)
- Stufe X1: XOR-Transpose-Baseline
- Stufe Xn: 2^(n-1) × X1-Arbeit eingebettet
- Höhere Skalierung = mehr Plot-Generierungsarbeit

### Basisziel-Anpassung

**Anpassung bei jedem Block:**
1. Gleitenden Durchschnitt der letzten Basisziele berechnen
2. Tatsächliche Zeitspanne vs. Ziel-Zeitspanne für rollendes Fenster berechnen
3. Basisziel proportional anpassen
4. Begrenzen, um extreme Schwankungen zu verhindern

**Formel:**
```
avg_base_target = gleitender_durchschnitt(letzte Basisziele)
adjustment_factor = tatsächliche_zeitspanne / ziel_zeitspanne
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Diese Dokumentation spiegelt die vollständige PoCX-Konsensimplementierung Stand Oktober 2025 wider.*

---

[← Zurück: Plot-Format](2-plot-format.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Forging-Zuweisungen →](4-forging-assignments.md)

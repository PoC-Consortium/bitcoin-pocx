[← Zurück: Netzwerkparameter](6-network-parameters.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Wallet-Anleitung →](8-wallet-guide.md)

---

# Kapitel 7: RPC-Schnittstellenreferenz

Vollständige Referenz für Bitcoin-PoCX RPC-Befehle, einschließlich Mining-RPCs, Zuweisungsverwaltung und modifizierter Blockchain-RPCs.

---

## Inhaltsverzeichnis

1. [Konfiguration](#konfiguration)
2. [PoCX Mining-RPCs](#pocx-mining-rpcs)
3. [Zuweisungs-RPCs](#zuweisungs-rpcs)
4. [Modifizierte Blockchain-RPCs](#modifizierte-blockchain-rpcs)
5. [Deaktivierte RPCs](#deaktivierte-rpcs)
6. [Integrationsbeispiele](#integrationsbeispiele)

---

## Konfiguration

### Mining-Server-Modus

**Flag**: `-miningserver`

**Zweck**: Aktiviert RPC-Zugang für externe Miner zum Aufruf Mining-spezifischer RPCs

**Anforderungen**:
- Erforderlich damit `submit_nonce` funktioniert
- Erforderlich für Sichtbarkeit des Forging-Zuweisungsdialogs im Qt-Wallet

**Verwendung**:
```bash
# Kommandozeile
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Sicherheitsaspekte**:
- Keine zusätzliche Authentifizierung über Standard-RPC-Anmeldedaten hinaus
- Mining-RPCs sind durch Warteschlangenkapazität ratenbegrenzt
- Standard-RPC-Authentifizierung weiterhin erforderlich

**Implementierung**: `src/pocx/rpc/mining.cpp`

---

## PoCX Mining-RPCs

### get_mining_info

**Kategorie**: mining
**Benötigt Mining-Server**: Nein
**Benötigt Wallet**: Nein

**Zweck**: Gibt aktuelle Mining-Parameter zurück, die externe Miner zum Scannen von Plotdateien und Berechnen von Deadlines benötigen.

**Parameter**: Keine

**Rückgabewerte**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 Zeichen
  "base_target": 36650387593,                // numerisch
  "height": 12345,                           // numerisch, nächste Blockhöhe
  "block_hash": "def456...",                 // hex, vorheriger Block
  "target_quality": 18446744073709551615,    // uint64_max (alle Lösungen akzeptiert)
  "minimum_compression_level": 1,            // numerisch
  "target_compression_level": 2              // numerisch
}
```

**Feldbeschreibungen**:
- `generation_signature`: Deterministische Mining-Entropie für diese Blockhöhe
- `base_target`: Aktuelle Schwierigkeit (höher = einfacher)
- `height`: Blockhöhe, die Miner anzielen sollten
- `block_hash`: Vorheriger Block-Hash (informativ)
- `target_quality`: Qualitätsschwelle (derzeit uint64_max, keine Filterung)
- `minimum_compression_level`: Für Validierung erforderliche Mindestkompression
- `target_compression_level`: Empfohlene Kompression für optimales Mining

**Fehlercodes**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node synchronisiert noch

**Beispiel**:
```bash
bitcoin-cli get_mining_info
```

**Implementierung**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategorie**: mining
**Benötigt Mining-Server**: Ja
**Benötigt Wallet**: Ja (für private Schlüssel)

**Zweck**: Übermittelt eine PoCX-Mining-Lösung. Validiert Beweis, reiht für Time-Bended Forging ein und erstellt automatisch Block zur geplanten Zeit.

**Parameter**:
1. `height` (numerisch, erforderlich) - Blockhöhe
2. `generation_signature` (string hex, erforderlich) - Generierungssignatur (64 Zeichen)
3. `account_id` (string, erforderlich) - Plot-Konto-ID (40 Hex-Zeichen = 20 Bytes)
4. `seed` (string, erforderlich) - Plot-Seed (64 Hex-Zeichen = 32 Bytes)
5. `nonce` (numerisch, erforderlich) - Mining-Nonce
6. `compression` (numerisch, erforderlich) - Verwendete Skalierungs-/Kompressionsstufe (1-255)
7. `quality` (numerisch, optional) - Qualitätswert (wird neu berechnet, falls weggelassen)

**Rückgabewerte** (Erfolg):
```json
{
  "accepted": true,
  "quality": 120,           // schwierigkeitsangepasste Deadline in Sekunden
  "poc_time": 45            // Time-Bended Forge-Zeit in Sekunden
}
```

**Rückgabewerte** (abgelehnt):
```json
{
  "accepted": false,
  "error": "Generierungssignatur stimmt nicht überein"
}
```

**Validierungsschritte**:
1. **Formatvalidierung** (Schnell-Fehlschlag):
   - Konto-ID: genau 40 Hex-Zeichen
   - Seed: genau 64 Hex-Zeichen
2. **Kontextvalidierung**:
   - Höhe muss mit aktuellem Tip + 1 übereinstimmen
   - Generierungssignatur muss mit aktueller übereinstimmen
3. **Wallet-Verifikation**:
   - Effektiven Unterzeichner bestimmen (auf aktive Zuweisungen prüfen)
   - Verifizieren, dass Wallet privaten Schlüssel für effektiven Unterzeichner hat
4. **Beweisvalidierung** (teuer):
   - PoCX-Beweis mit Kompressionsgrenzen validieren
   - Rohqualität berechnen
5. **Scheduler-Übermittlung**:
   - Nonce für Time-Bended Forging einreihen
   - Block wird automatisch zur forge_time erstellt

**Fehlercodes**:
- `RPC_INVALID_PARAMETER`: Ungültiges Format (account_id, seed) oder Höhenabweichung
- `RPC_VERIFY_REJECTED`: Generierungssignatur stimmt nicht überein oder Beweisvalidierung fehlgeschlagen
- `RPC_INVALID_ADDRESS_OR_KEY`: Kein privater Schlüssel für effektiven Unterzeichner
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Übermittlungswarteschlange voll
- `RPC_INTERNAL_ERROR`: PoCX-Scheduler konnte nicht initialisiert werden

**Beweisvalidierungs-Fehlercodes**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Beispiel**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_zeichen..." \
  999888777 \
  1
```

**Hinweise**:
- Übermittlung ist asynchron - RPC kehrt sofort zurück, Block wird später geschmiedet
- Time-Bending verzögert gute Lösungen, um netzwerkweites Plot-Scannen zu ermöglichen
- Zuweisungssystem: falls Plot zugewiesen, muss Wallet Forging-Adressschlüssel haben
- Kompressionsgrenzen werden dynamisch basierend auf Blockhöhe angepasst

**Implementierung**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Zuweisungs-RPCs

### get_assignment

**Kategorie**: mining
**Benötigt Mining-Server**: Nein
**Benötigt Wallet**: Nein

**Zweck**: Abfrage des Forging-Zuweisungsstatus für eine Plot-Adresse. Nur-Lesen, kein Wallet erforderlich.

**Parameter**:
1. `plot_address` (string, erforderlich) - Plot-Adresse (bech32 P2WPKH-Format)
2. `height` (numerisch, optional) - Abzufragende Blockhöhe (Standard: aktueller Tip)

**Rückgabewerte** (keine Zuweisung):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Rückgabewerte** (aktive Zuweisung):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Rückgabewerte** (widerrufend):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Zuweisungszustände**:
- `UNASSIGNED`: Keine Zuweisung existiert
- `ASSIGNING`: Zuweisungs-tx bestätigt, Aktivierungsverzögerung läuft
- `ASSIGNED`: Zuweisung aktiv, Forging-Rechte delegiert
- `REVOKING`: Widerrufs-tx bestätigt, noch aktiv bis Verzögerung abläuft
- `REVOKED`: Widerruf abgeschlossen, Forging-Rechte an Plotbesitzer zurückgegeben

**Fehlercodes**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Ungültige Adresse oder nicht P2WPKH (bech32)

**Beispiel**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementierung**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategorie**: wallet
**Benötigt Mining-Server**: Nein
**Benötigt Wallet**: Ja (muss geladen und entsperrt sein)

**Zweck**: Erstellt Forging-Zuweisungstransaktion zur Delegation von Forging-Rechten an eine andere Adresse (z.B. Mining-Pool).

**Parameter**:
1. `plot_address` (string, erforderlich) - Plotbesitzer-Adresse (muss privaten Schlüssel besitzen, P2WPKH bech32)
2. `forging_address` (string, erforderlich) - Adresse für Forging-Rechte-Zuweisung (P2WPKH bech32)
3. `fee_rate` (numerisch, optional) - Gebührenrate in BTC/kvB (Standard: 10× minRelayFee)

**Rückgabewerte**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Anforderungen**:
- Wallet geladen und entsperrt
- Privater Schlüssel für plot_address im Wallet
- Beide Adressen müssen P2WPKH sein (bech32-Format: pocx1q... Mainnet, tpocx1q... Testnet)
- Plot-Adresse muss bestätigte UTXOs haben (beweist Eigentum)
- Plot darf keine aktive Zuweisung haben (zuerst widerrufen)

**Transaktionsstruktur**:
- Eingabe: UTXO von Plot-Adresse (beweist Eigentum)
- Ausgabe: OP_RETURN (46 Bytes): `POCX`-Marker + plot_address (20 Bytes) + forging_address (20 Bytes)
- Ausgabe: Wechselgeld zurück ans Wallet

**Aktivierung**:
- Zuweisung wird ASSIGNING bei Bestätigung
- Wird ACTIVE nach `nForgingAssignmentDelay` Blöcken
- Verzögerung verhindert schnelle Neuzuweisung bei Chain-Forks

**Fehlercodes**:
- `RPC_WALLET_NOT_FOUND`: Kein Wallet verfügbar
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet verschlüsselt und gesperrt
- `RPC_WALLET_ERROR`: Transaktionserstellung fehlgeschlagen
- `RPC_INVALID_ADDRESS_OR_KEY`: Ungültiges Adressformat

**Beispiel**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementierung**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategorie**: wallet
**Benötigt Mining-Server**: Nein
**Benötigt Wallet**: Ja (muss geladen und entsperrt sein)

**Zweck**: Widerruft bestehende Forging-Zuweisung, gibt Forging-Rechte an Plotbesitzer zurück.

**Parameter**:
1. `plot_address` (string, erforderlich) - Plot-Adresse (muss privaten Schlüssel besitzen, P2WPKH bech32)
2. `fee_rate` (numerisch, optional) - Gebührenrate in BTC/kvB (Standard: 10× minRelayFee)

**Rückgabewerte**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Anforderungen**:
- Wallet geladen und entsperrt
- Privater Schlüssel für plot_address im Wallet
- Plot-Adresse muss P2WPKH sein (bech32-Format)
- Plot-Adresse muss bestätigte UTXOs haben

**Transaktionsstruktur**:
- Eingabe: UTXO von Plot-Adresse (beweist Eigentum)
- Ausgabe: OP_RETURN (26 Bytes): `XCOP`-Marker + plot_address (20 Bytes)
- Ausgabe: Wechselgeld zurück ans Wallet

**Effekt**:
- Zustand wechselt sofort zu REVOKING
- Forging-Adresse kann während Verzögerungsperiode noch schmieden
- Wird REVOKED nach `nForgingRevocationDelay` Blöcken
- Plotbesitzer kann nach effektivem Widerruf schmieden
- Kann nach abgeschlossenem Widerruf neue Zuweisung erstellen

**Fehlercodes**:
- `RPC_WALLET_NOT_FOUND`: Kein Wallet verfügbar
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet verschlüsselt und gesperrt
- `RPC_WALLET_ERROR`: Transaktionserstellung fehlgeschlagen

**Beispiel**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Hinweise**:
- Idempotent: kann widerrufen auch wenn keine aktive Zuweisung
- Widerruf kann nicht abgebrochen werden, sobald übermittelt

**Implementierung**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modifizierte Blockchain-RPCs

### getdifficulty

**PoCX-Modifikationen**:
- **Berechnung**: `referenz_base_target / aktuelles_base_target`
- **Referenz**: 1 TiB Netzwerkkapazität (base_target = 36650387593)
- **Interpretation**: Geschätzte Netzwerkspeicherkapazität in TiB
  - Beispiel: `1.0` = ~1 TiB
  - Beispiel: `1024.0` = ~1 PiB
- **Unterschied zu PoW**: Repräsentiert Kapazität, nicht Hash-Leistung

**Beispiel**:
```bash
bitcoin-cli getdifficulty
# Gibt zurück: 2048.5 (Netzwerk ~2 PiB)
```

**Implementierung**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX hinzugefügte Felder**:
- `time_since_last_block` (numerisch) - Sekunden seit vorherigem Block (ersetzt mediantime)
- `poc_time` (numerisch) - Time-Bended Forge-Zeit in Sekunden
- `base_target` (numerisch) - PoCX-Schwierigkeits-Basisziel
- `generation_signature` (string hex) - Generierungssignatur
- `pocx_proof` (Objekt):
  - `account_id` (string hex) - Plot-Konto-ID (20 Bytes)
  - `seed` (string hex) - Plot-Seed (32 Bytes)
  - `nonce` (numerisch) - Mining-Nonce
  - `compression` (numerisch) - Verwendete Skalierungsstufe
  - `quality` (numerisch) - Beanspruchter Qualitätswert
- `pubkey` (string hex) - Öffentlicher Schlüssel des Block-Unterzeichners (33 Bytes)
- `signer_address` (string) - Adresse des Block-Unterzeichners
- `signature` (string hex) - Blocksignatur (65 Bytes)

**PoCX entfernte Felder**:
- `mediantime` - Entfernt (ersetzt durch time_since_last_block)

**Beispiel**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementierung**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-Modifikationen**: Wie getblockheader, plus vollständige Transaktionsdaten

**Beispiel**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose mit tx-Details
```

**Implementierung**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX hinzugefügte Felder**:
- `base_target` (numerisch) - Aktuelles Basisziel
- `generation_signature` (string hex) - Aktuelle Generierungssignatur

**PoCX modifizierte Felder**:
- `difficulty` - Verwendet PoCX-Berechnung (kapazitätsbasiert)

**PoCX entfernte Felder**:
- `mediantime` - Entfernt

**Beispiel**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementierung**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX hinzugefügte Felder**:
- `generation_signature` (string hex) - Für Pool-Mining
- `base_target` (numerisch) - Für Pool-Mining

**PoCX entfernte Felder**:
- `target` - Entfernt (PoW-spezifisch)
- `noncerange` - Entfernt (PoW-spezifisch)
- `bits` - Entfernt (PoW-spezifisch)

**Hinweise**:
- Enthält weiterhin vollständige Transaktionsdaten für Block-Konstruktion
- Wird von Pool-Servern für koordiniertes Mining verwendet

**Beispiel**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementierung**: `src/rpc/mining.cpp`

---

## Deaktivierte RPCs

Die folgenden PoW-spezifischen RPCs sind im PoCX-Modus **deaktiviert**:

### getnetworkhashps
- **Grund**: Hash-Rate nicht anwendbar auf Proof of Capacity
- **Alternative**: Verwenden Sie `getdifficulty` für Netzwerkkapazitätsschätzung

### getmininginfo
- **Grund**: Gibt PoW-spezifische Informationen zurück
- **Alternative**: Verwenden Sie `get_mining_info` (PoCX-spezifisch)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Grund**: CPU-Mining nicht anwendbar auf PoCX (erfordert vorab generierte Plots)
- **Alternative**: Verwenden Sie externen Plotter + Miner + `submit_nonce`

**Implementierung**: `src/rpc/mining.cpp` (RPCs geben Fehler zurück wenn ENABLE_POCX definiert)

---

## Integrationsbeispiele

### Externe Miner-Integration

**Einfache Mining-Schleife**:
```python
import requests
import time

RPC_URL = "http://benutzer:passwort@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Mining-Schleife
while True:
    # 1. Mining-Parameter holen
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Plotdateien scannen (externe Implementierung)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Beste Lösung übermitteln
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Lösung akzeptiert! Qualität: {result['quality']}s, "
              f"Forge-Zeit: {result['poc_time']}s")

    # 4. Auf nächsten Block warten
    time.sleep(10)  # Abfrage-Intervall
```

---

### Pool-Integrationsmuster

**Pool-Server-Workflow**:
1. Miner erstellen Forging-Zuweisungen an Pool-Adresse
2. Pool betreibt Wallet mit Forging-Adressschlüsseln
3. Pool ruft `get_mining_info` auf und verteilt an Miner
4. Miner übermitteln Lösungen via Pool (nicht direkt an Chain)
5. Pool validiert und ruft `submit_nonce` mit Pool-Schlüsseln auf
6. Pool verteilt Belohnungen gemäß Pool-Richtlinie

**Zuweisungsverwaltung**:
```bash
# Miner erstellt Zuweisung (vom Wallet des Miners)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Auf Aktivierung warten (30 Blöcke Mainnet)

# Pool prüft Zuweisungsstatus
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool kann jetzt Nonces für diesen Plot übermitteln
# (Pool-Wallet muss pocx1qpool... privaten Schlüssel haben)
```

---

### Block-Explorer-Abfragen

**PoCX-Blockdaten abfragen**:
```bash
# Neuesten Block holen
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Blockdetails mit PoCX-Beweis holen
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX-spezifische Felder extrahieren
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Zuweisungstransaktionen erkennen**:
```bash
# Transaktion nach OP_RETURN scannen
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Auf Zuweisungsmarker prüfen (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Fehlerbehandlung

### Häufige Fehlermuster

**Höhenabweichung**:
```json
{
  "accepted": false,
  "error": "Höhenabweichung: übermittelt 12345, aktuell 12346"
}
```
**Lösung**: Mining-Info neu abrufen, Chain ist weitergegangen

**Generierungssignatur stimmt nicht überein**:
```json
{
  "accepted": false,
  "error": "Generierungssignatur stimmt nicht überein"
}
```
**Lösung**: Mining-Info neu abrufen, neuer Block angekommen

**Kein privater Schlüssel**:
```json
{
  "code": -5,
  "message": "Kein privater Schlüssel für effektiven Unterzeichner verfügbar"
}
```
**Lösung**: Schlüssel für Plot- oder Forging-Adresse importieren

**Zuweisungsaktivierung ausstehend**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Lösung**: Warten bis Aktivierungsverzögerung abläuft

---

## Code-Referenzen

**Mining-RPCs**: `src/pocx/rpc/mining.cpp`
**Zuweisungs-RPCs**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain-RPCs**: `src/rpc/blockchain.cpp`
**Beweisvalidierung**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Zuweisungszustand**: `src/pocx/assignments/assignment_state.cpp`
**Transaktionserstellung**: `src/pocx/assignments/transactions.cpp`

---

## Querverweise

Verwandte Kapitel:
- [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md) - Mining-Prozessdetails
- [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md) - Zuweisungssystem-Architektur
- [Kapitel 6: Netzwerkparameter](6-network-parameters.md) - Zuweisungsverzögerungswerte
- [Kapitel 8: Wallet-Anleitung](8-wallet-guide.md) - GUI für Zuweisungsverwaltung

---

[← Zurück: Netzwerkparameter](6-network-parameters.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Wallet-Anleitung →](8-wallet-guide.md)

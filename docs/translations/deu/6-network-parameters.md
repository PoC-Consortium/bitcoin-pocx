[← Zurück: Zeitsynchronisation](5-timing-security.md) | [Inhaltsverzeichnis](index.md) | [Weiter: RPC-Referenz →](7-rpc-reference.md)

---

# Kapitel 6: Netzwerkparameter und Konfiguration

Vollständige Referenz für Bitcoin-PoCX-Netzwerkkonfiguration über alle Netzwerktypen.

---

## Inhaltsverzeichnis

1. [Genesis-Block-Parameter](#genesis-block-parameter)
2. [Chainparams-Konfiguration](#chainparams-konfiguration)
3. [Konsensparameter](#konsensparameter)
4. [Coinbase und Blockbelohnungen](#coinbase-und-blockbelohnungen)
5. [Dynamische Skalierung](#dynamische-skalierung)
6. [Netzwerkkonfiguration](#netzwerkkonfiguration)
7. [Datenverzeichnisstruktur](#datenverzeichnisstruktur)

---

## Genesis-Block-Parameter

### Basisziel-Berechnung

**Formel**: `genesis_base_target = 2^42 / block_time_seconds`

**Begründung**:
- Jede Nonce repräsentiert 256 KiB (64 Bytes × 4096 Scoops)
- 1 TiB = 2^22 Nonces (angenommene Startnetzwerkkapazität)
- Erwartete Mindestqualität für n Nonces ≈ 2^64 / n
- Für 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Daher: base_target = 2^42 / block_time

**Berechnete Werte**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Verwendet Low-Capacity-Kalibrierungsmodus

### Genesis-Nachricht

Alle Netzwerke teilen die Bitcoin-Genesis-Nachricht:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementierung**: `src/kernel/chainparams.cpp`

---

## Chainparams-Konfiguration

### Mainnet-Parameter

**Netzwerkidentität**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Standard-Port**: `8888`
- **Bech32 HRP**: `pocx`

**Adresspräfixe** (Base58):
- PUBKEY_ADDRESS: `85` (Adressen beginnen mit 'P')
- SCRIPT_ADDRESS: `90` (Adressen beginnen mit 'R')
- SECRET_KEY: `128`

**Block-Timing**:
- **Blockzeit-Ziel**: `120` Sekunden (2 Minuten)
- **Ziel-Zeitspanne**: `1209600` Sekunden (14 Tage)
- **MAX_FUTURE_BLOCK_TIME**: `15` Sekunden

**Blockbelohnungen**:
- **Initiale Subvention**: `10 BTC`
- **Halving-Intervall**: `1050000` Blöcke (~4 Jahre)
- **Halving-Anzahl**: Maximal 64 Halvings

**Schwierigkeitsanpassung**:
- **Gleitendes Fenster**: `24` Blöcke
- **Anpassung**: Bei jedem Block
- **Algorithmus**: Exponentieller gleitender Durchschnitt

**Zuweisungsverzögerungen**:
- **Aktivierung**: `30` Blöcke (~1 Stunde)
- **Widerruf**: `720` Blöcke (~24 Stunden)

### Testnet-Parameter

**Netzwerkidentität**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Standard-Port**: `18888`
- **Bech32 HRP**: `tpocx`

**Adresspräfixe** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Block-Timing**:
- **Blockzeit-Ziel**: `120` Sekunden
- **MAX_FUTURE_BLOCK_TIME**: `15` Sekunden
- **Min-Schwierigkeit erlauben**: `true`

**Blockbelohnungen**:
- **Initiale Subvention**: `10 BTC`
- **Halving-Intervall**: `1050000` Blöcke

**Schwierigkeitsanpassung**:
- **Gleitendes Fenster**: `24` Blöcke

**Zuweisungsverzögerungen**:
- **Aktivierung**: `30` Blöcke (~1 Stunde)
- **Widerruf**: `720` Blöcke (~24 Stunden)

### Regtest-Parameter

**Netzwerkidentität**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Standard-Port**: `18444`
- **Bech32 HRP**: `rpocx`

**Adresspräfixe** (Bitcoin-kompatibel):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Block-Timing**:
- **Blockzeit-Ziel**: `1` Sekunde (sofortiges Mining für Tests)
- **Ziel-Zeitspanne**: `86400` Sekunden (1 Tag)
- **MAX_FUTURE_BLOCK_TIME**: `15` Sekunden

**Blockbelohnungen**:
- **Initiale Subvention**: `10 BTC`
- **Halving-Intervall**: `500` Blöcke

**Schwierigkeitsanpassung**:
- **Gleitendes Fenster**: `24` Blöcke
- **Min-Schwierigkeit erlauben**: `true`
- **Kein Retargeting**: `true`
- **Low-Capacity-Kalibrierung**: `true` (verwendet 16-Nonce-Kalibrierung statt 1 TiB)

**Zuweisungsverzögerungen**:
- **Aktivierung**: `4` Blöcke (~4 Sekunden)
- **Widerruf**: `8` Blöcke (~8 Sekunden)

### Signet-Parameter

**Netzwerkidentität**:
- **Magic Bytes**: Erste 4 Bytes von SHA256d(signet_challenge)
- **Standard-Port**: `38333`
- **Bech32 HRP**: `tpocx`

**Block-Timing**:
- **Blockzeit-Ziel**: `120` Sekunden
- **MAX_FUTURE_BLOCK_TIME**: `15` Sekunden

**Blockbelohnungen**:
- **Initiale Subvention**: `10 BTC`
- **Halving-Intervall**: `1050000` Blöcke

**Schwierigkeitsanpassung**:
- **Gleitendes Fenster**: `24` Blöcke

---

## Konsensparameter

### Timing-Parameter

**MAX_FUTURE_BLOCK_TIME**: `15` Sekunden
- PoCX-spezifisch (Bitcoin verwendet 2 Stunden)
- Begründung: PoC-Timing erfordert Echtzeit-nahe Validierung
- Blöcke mehr als 15s in der Zukunft werden abgelehnt

**Zeitoffset-Warnung**: `10` Sekunden
- Betreiber werden gewarnt, wenn Node-Uhr >10s vom Netzwerk abweicht
- Keine Durchsetzung, nur informativ

**Blockzeit-Ziele**:
- Mainnet/Testnet/Signet: `120` Sekunden
- Regtest: `1` Sekunde

**TIMESTAMP_WINDOW**: `15` Sekunden (entspricht MAX_FUTURE_BLOCK_TIME)

**Implementierung**: `src/chain.h`, `src/validation.cpp`

### Schwierigkeitsanpassungsparameter

**Gleitendes Fenster**: `24` Blöcke (alle Netzwerke)
- Exponentieller gleitender Durchschnitt der letzten Blockzeiten
- Anpassung bei jedem Block
- Reagiert auf Kapazitätsänderungen

**Implementierung**: `src/consensus/params.h`, Schwierigkeitslogik bei Blockerstellung

### Zuweisungssystem-Parameter

**nForgingAssignmentDelay** (Aktivierungsverzögerung):
- Mainnet: `30` Blöcke (~1 Stunde)
- Testnet: `30` Blöcke (~1 Stunde)
- Regtest: `4` Blöcke (~4 Sekunden)

**nForgingRevocationDelay** (Widerrufsverzögerung):
- Mainnet: `720` Blöcke (~24 Stunden)
- Testnet: `720` Blöcke (~24 Stunden)
- Regtest: `8` Blöcke (~8 Sekunden)

**Begründung**:
- Aktivierungsverzögerung verhindert schnelle Neuzuweisung während Block-Races
- Widerrufsverzögerung bietet Stabilität und verhindert Missbrauch

**Implementierung**: `src/consensus/params.h`

---

## Coinbase und Blockbelohnungen

### Blocksubventions-Zeitplan

**Initiale Subvention**: `10 BTC` (alle Netzwerke)

**Halving-Zeitplan**:
- Alle `1050000` Blöcke (Mainnet/Testnet)
- Alle `500` Blöcke (Regtest)
- Läuft für maximal 64 Halvings

**Halving-Progression**:
```
Halving 0: 10,00000000 BTC  (Blöcke 0 - 1049999)
Halving 1:  5,00000000 BTC  (Blöcke 1050000 - 2099999)
Halving 2:  2,50000000 BTC  (Blöcke 2100000 - 3149999)
Halving 3:  1,25000000 BTC  (Blöcke 3150000 - 4199999)
...
```

**Gesamtangebot**: ~21 Millionen BTC (wie bei Bitcoin)

### Coinbase-Ausgaberegeln

**Zahlungsziel**:
- **Ohne Zuweisung**: Coinbase zahlt an Plot-Adresse (proof.account_id)
- **Mit Zuweisung**: Coinbase zahlt an Forging-Adresse (effektiver Unterzeichner)

**Ausgabeformat**: Nur P2WPKH
- Coinbase muss an bech32 SegWit v0 Adresse zahlen
- Generiert aus Public Key des effektiven Unterzeichners

**Zuweisungsauflösung**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementierung**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamische Skalierung

### Skalierungsgrenzen

**Zweck**: Erhöhung der Plot-Generierungsschwierigkeit mit Netzwerkreife, um Kapazitätsinflation zu verhindern

**Struktur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimal akzeptierte Stufe
    uint8_t nPoCXTargetCompression;  // Empfohlene Stufe
};
```

**Beziehung**: `target = min + 1` (immer eine Stufe über Minimum)

### Zeitplan für Skalierungserhöhung

Skalierungsstufen erhöhen sich nach **exponentiellem Zeitplan** basierend auf Halving-Intervallen:

| Zeitraum | Blockhöhe | Halvings | Min | Ziel |
|----------|-----------|----------|-----|------|
| Jahre 0-4 | 0 bis 1049999 | 0 | X1 | X2 |
| Jahre 4-12 | 1050000 bis 3149999 | 1-2 | X2 | X3 |
| Jahre 12-28 | 3150000 bis 7349999 | 3-6 | X3 | X4 |
| Jahre 28-60 | 7350000 bis 15749999 | 7-14 | X4 | X5 |
| Jahre 60-124 | 15750000 bis 32549999 | 15-30 | X5 | X6 |
| Jahre 124+ | 32550000+ | 31+ | X6 | X7 |

**Schlüsselhöhen** (Jahre → Halvings → Blöcke):
- Jahr 4: Halving 1 bei Block 1050000
- Jahr 12: Halving 3 bei Block 3150000
- Jahr 28: Halving 7 bei Block 7350000
- Jahr 60: Halving 15 bei Block 15750000
- Jahr 124: Halving 31 bei Block 32550000

### Skalierungsstufen-Schwierigkeit

**PoW-Skalierung**:
- Skalierungsstufe X0: POC2-Baseline (theoretisch)
- Skalierungsstufe X1: XOR-Transpose-Baseline
- Skalierungsstufe Xn: 2^(n-1) × X1-Arbeit eingebettet
- Jede Stufe verdoppelt Plot-Generierungsarbeit

**Wirtschaftliche Ausrichtung**:
- Blockbelohnungen halbieren sich → Plot-Generierungsschwierigkeit steigt
- Erhält Sicherheitsmarge: Plot-Erstellungskosten > Lookup-Kosten
- Verhindert Kapazitätsinflation durch Hardware-Verbesserungen

### Plot-Validierung

**Validierungsregeln**:
- Übermittelte Beweise müssen Skalierungsstufe ≥ Minimum haben
- Beweise mit Skalierung > Ziel werden akzeptiert, aber ineffizient
- Beweise unter Minimum: abgelehnt (unzureichendes PoW)

**Grenzenabfrage**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementierung**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Netzwerkkonfiguration

### Seed-Nodes und DNS-Seeds

**Status**: Platzhalter für Mainnet-Start

**Geplante Konfiguration**:
- Seed-Nodes: Noch festzulegen
- DNS-Seeds: Noch festzulegen

**Aktueller Stand** (Testnet/Regtest):
- Keine dedizierte Seed-Infrastruktur
- Manuelle Peer-Verbindungen unterstützt via `-addnode`

**Implementierung**: `src/kernel/chainparams.cpp`

### Checkpoints

**Genesis-Checkpoint**: Immer Block 0

**Zusätzliche Checkpoints**: Derzeit keine konfiguriert

**Zukunft**: Checkpoints werden mit Mainnet-Fortschritt hinzugefügt

---

## P2P-Protokollkonfiguration

### Protokollversion

**Basis**: Bitcoin Core v30.0 Protokoll
- **Protokollversion**: Von Bitcoin Core geerbt
- **Service-Bits**: Standard Bitcoin-Dienste
- **Nachrichtentypen**: Standard Bitcoin P2P-Nachrichten

**PoCX-Erweiterungen**:
- Block-Header enthalten PoCX-spezifische Felder
- Block-Nachrichten enthalten PoCX-Beweisdaten
- Validierungsregeln erzwingen PoCX-Konsens

**Kompatibilität**: PoCX-Nodes inkompatibel mit Bitcoin PoW-Nodes (unterschiedlicher Konsens)

**Implementierung**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datenverzeichnisstruktur

### Standardverzeichnis

**Speicherort**: `.bitcoin/` (wie bei Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Verzeichnisinhalte

```
.bitcoin/
├── blocks/              # Blockdaten
│   ├── blk*.dat        # Blockdateien
│   ├── rev*.dat        # Undo-Daten
│   └── index/          # Blockindex (LevelDB)
├── chainstate/         # UTXO-Set + Forging-Zuweisungen (LevelDB)
├── wallets/            # Wallet-Dateien
│   └── wallet.dat      # Standard-Wallet
├── bitcoin.conf        # Konfigurationsdatei
├── debug.log           # Debug-Log
├── peers.dat           # Peer-Adressen
├── mempool.dat         # Mempool-Persistenz
└── banlist.dat         # Gesperrte Peers
```

### Unterschiede zu Bitcoin

**Chainstate-Datenbank**:
- Standard: UTXO-Set
- **PoCX-Ergänzung**: Forging-Zuweisungszustand
- Atomare Updates: UTXO + Zuweisungen werden zusammen aktualisiert
- Reorg-sichere Undo-Daten für Zuweisungen

**Blockdateien**:
- Standard Bitcoin-Blockformat
- **PoCX-Ergänzung**: Erweitert um PoCX-Beweisfelder (account_id, seed, nonce, signature, pubkey)

### Konfigurationsdatei-Beispiel

**bitcoin.conf**:
```ini
# Netzwerkauswahl
#testnet=1
#regtest=1

# PoCX-Mining-Server (erforderlich für externe Miner)
miningserver=1

# RPC-Einstellungen
server=1
rpcuser=ihrBenutzername
rpcpassword=ihrPasswort
rpcallowip=127.0.0.1
rpcport=8332

# Verbindungseinstellungen
listen=1
port=8888
maxconnections=125

# Blockzeit-Ziel (informativ, Konsens erzwungen)
# 120 Sekunden für Mainnet/Testnet
```

---

## Code-Referenzen

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensparameter**: `src/consensus/params.h`
**Kompressionsgrenzen**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis-Basisziel-Berechnung**: `src/pocx/consensus/params.cpp`
**Coinbase-Zahlungslogik**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Zuweisungszustandsspeicherung**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-Erweiterungen)

---

## Querverweise

Verwandte Kapitel:
- [Kapitel 2: Plot-Format](2-plot-format.md) - Skalierungsstufen bei Plot-Generierung
- [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md) - Skalierungsvalidierung, Zuweisungssystem
- [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md) - Zuweisungsverzögerungsparameter
- [Kapitel 5: Zeitsynchronisation und Sicherheit](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-Begründung

---

[← Zurück: Zeitsynchronisation](5-timing-security.md) | [Inhaltsverzeichnis](index.md) | [Weiter: RPC-Referenz →](7-rpc-reference.md)

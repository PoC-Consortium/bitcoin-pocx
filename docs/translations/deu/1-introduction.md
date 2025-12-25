[Inhaltsverzeichnis](index.md) | [Weiter: Plot-Format →](2-plot-format.md)

---

# Kapitel 1: Einführung und Übersicht

## Was ist Bitcoin-PoCX?

Bitcoin-PoCX ist eine Bitcoin Core Integration, die Unterstützung für den **Proof of Capacity neXt generation (PoCX)** Konsensmechanismus hinzufügt. Es behält die bestehende Architektur von Bitcoin Core bei und ermöglicht gleichzeitig eine energieeffiziente Proof of Capacity Mining-Alternative als vollständigen Ersatz für Proof of Work.

**Wesentliche Unterscheidung**: Dies ist eine **neue Chain** ohne Rückwärtskompatibilität mit Bitcoin PoW. PoCX-Blöcke sind konstruktionsbedingt nicht kompatibel mit PoW-Nodes.

---

## Projektidentität

- **Organisation**: Proof of Capacity Consortium
- **Projektname**: Bitcoin-PoCX
- **Vollständiger Name**: Bitcoin Core mit PoCX-Integration
- **Status**: Testnet-Phase

---

## Was ist Proof of Capacity?

Proof of Capacity (PoC) ist ein Konsensmechanismus, bei dem die Mining-Leistung proportional zum **Festplattenspeicher** statt zur Rechenleistung ist. Miner generieren vorab große Plot-Dateien mit kryptografischen Hashes und verwenden diese Plots dann, um gültige Blocklösungen zu finden.

**Energieeffizienz**: Plot-Dateien werden einmal generiert und unbegrenzt wiederverwendet. Mining verbraucht minimale CPU-Leistung – hauptsächlich Festplatten-I/O.

**PoCX-Erweiterungen**:
- Behobener XOR-Transpose-Kompressionsangriff (50% Zeit-Speicher-Kompromiss bei POC2)
- 16-Nonce-ausgerichtetes Layout für moderne Hardware
- Skalierbare Proof-of-Work bei Plot-Generierung (Xn-Skalierungsstufen)
- Native C++-Integration direkt in Bitcoin Core
- Time-Bending-Algorithmus für verbesserte Blockzeit-Verteilung

---

## Architekturübersicht

### Repository-Struktur

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX-Integration
│   └── src/pocx/        # PoCX-Implementierung
├── pocx/                # PoCX Core Framework (Submodul, schreibgeschützt)
└── docs/                # Diese Dokumentation
```

### Integrationsphilosophie

**Minimale Integrationsoberfläche**: Änderungen sind im Verzeichnis `/src/pocx/` isoliert mit sauberen Hooks in die Bitcoin Core Validierungs-, Mining- und RPC-Schichten.

**Feature-Kennzeichnung**: Alle Modifikationen unter `#ifdef ENABLE_POCX` Präprozessor-Guards. Bitcoin Core kompiliert normal, wenn deaktiviert.

**Upstream-Kompatibilität**: Regelmäßige Synchronisation mit Bitcoin Core Updates wird durch isolierte Integrationspunkte aufrechterhalten.

**Native C++-Implementierung**: Skalare kryptografische Algorithmen (Shabal256, Scoop-Berechnung, Kompression) direkt in Bitcoin Core für Konsensvalidierung integriert.

---

## Kernfunktionen

### 1. Vollständiger Konsensersatz

- **Blockstruktur**: PoCX-spezifische Felder ersetzen PoW-Nonce und Schwierigkeitsbits
  - Generierungssignatur (deterministisch Mining-Entropie)
  - Basisziel (Kehrwert der Schwierigkeit)
  - PoCX-Beweis (Konto-ID, Seed, Nonce)
  - Blocksignatur (beweist Plot-Eigentum)

- **Validierung**: 5-stufige Validierungspipeline von Header-Prüfung bis Block-Verbindung

- **Schwierigkeitsanpassung**: Anpassung bei jedem Block mit gleitendem Durchschnitt der letzten Basisziele

### 2. Time-Bending-Algorithmus

**Problem**: Traditionelle PoC-Blockzeiten folgen einer Exponentialverteilung, was zu langen Blöcken führt, wenn kein Miner eine gute Lösung findet.

**Lösung**: Verteilungstransformation von exponentiell zu Chi-Quadrat mittels Kubikwurzel: `Y = scale × (X^(1/3))`.

**Effekt**: Sehr gute Lösungen werden später geschmiedet (Netzwerk hat Zeit, alle Festplatten zu scannen, reduziert schnelle Blöcke), schlechte Lösungen werden verbessert. Durchschnittliche Blockzeit bleibt bei 120 Sekunden, lange Blöcke werden reduziert.

**Details**: [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md)

### 3. Forging-Zuweisungssystem

**Fähigkeit**: Plot-Besitzer können Forging-Rechte an andere Adressen delegieren, während sie das Plot-Eigentum behalten.

**Anwendungsfälle**:
- Pool-Mining (Plots weisen Pool-Adresse zu)
- Cold Storage (Mining-Schlüssel getrennt vom Plot-Eigentum)
- Multi-Party-Mining (gemeinsame Infrastruktur)

**Architektur**: OP_RETURN-basiertes Design – keine speziellen UTXOs, Zuweisungen werden separat in der Chainstate-Datenbank verfolgt.

**Details**: [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md)

### 4. Defensives Forging

**Problem**: Schnelle Uhren könnten Timing-Vorteile innerhalb der 15-Sekunden-Zukunftstoleranz bieten.

**Lösung**: Beim Empfang eines konkurrierenden Blocks auf gleicher Höhe wird automatisch die lokale Qualität geprüft. Falls besser, wird sofort geschmiedet.

**Effekt**: Eliminiert Anreiz zur Uhrenmanipulation – schnelle Uhren helfen nur, wenn man bereits die beste Lösung hat.

**Details**: [Kapitel 5: Zeitsynchronisation und Sicherheit](5-timing-security.md)

### 5. Dynamische Kompressionsskalierung

**Wirtschaftliche Ausrichtung**: Anforderungen an Skalierungsstufen steigen nach exponentiellem Zeitplan (Jahre 4, 12, 28, 60, 124 = Halvings 1, 3, 7, 15, 31).

**Effekt**: Mit abnehmenden Blockbelohnungen steigt die Schwierigkeit der Plot-Generierung. Erhält Sicherheitsmarge zwischen Plot-Erstellungs- und Lookup-Kosten.

**Verhindert**: Kapazitätsinflation durch schnellere Hardware im Laufe der Zeit.

**Details**: [Kapitel 6: Netzwerkparameter](6-network-parameters.md)

---

## Designphilosophie

### Code-Sicherheit

- Defensive Programmierpraktiken durchgehend
- Umfassende Fehlerbehandlung in Validierungspfaden
- Keine verschachtelten Sperren (Deadlock-Prävention)
- Atomare Datenbankoperationen (UTXO + Zuweisungen gemeinsam)

### Modulare Architektur

- Saubere Trennung zwischen Bitcoin Core Infrastruktur und PoCX-Konsens
- PoCX Core Framework liefert kryptografische Primitive
- Bitcoin Core liefert Validierungsframework, Datenbank, Netzwerk

### Leistungsoptimierungen

- Schnell-Fehlschlag-Validierungsreihenfolge (günstige Prüfungen zuerst)
- Einzelner Kontextabruf pro Einreichung (keine wiederholten cs_main-Erfassungen)
- Atomare Datenbankoperationen für Konsistenz

### Reorg-Sicherheit

- Vollständige Undo-Daten für Zuweisungszustandsänderungen
- Forging-Zustandsrücksetzung bei Chain-Tip-Änderungen
- Veraltungserkennung an allen Validierungspunkten

---

## Unterschiede zwischen PoCX und Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Mining-Ressource** | Rechenleistung (Hash-Rate) | Festplattenspeicher (Kapazität) |
| **Energieverbrauch** | Hoch (kontinuierliches Hashen) | Niedrig (nur Festplatten-I/O) |
| **Mining-Prozess** | Finde Nonce mit Hash < Ziel | Finde Nonce mit Deadline < verstrichene Zeit |
| **Schwierigkeit** | `bits`-Feld, alle 2016 Blöcke angepasst | `base_target`-Feld, bei jedem Block angepasst |
| **Blockzeit** | ~10 Minuten (Exponentialverteilung) | 120 Sekunden (time-gebended, reduzierte Varianz) |
| **Subvention** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Hardware** | ASICs (spezialisiert) | HDDs (Standardhardware) |
| **Mining-Identität** | Anonym | Plot-Besitzer oder Delegierter |

---

## Systemanforderungen

### Node-Betrieb

**Wie bei Bitcoin Core**:
- **CPU**: Moderner x86_64-Prozessor
- **Arbeitsspeicher**: 4-8 GB RAM
- **Speicher**: Neue Chain, derzeit leer (kann ~4× schneller als Bitcoin wachsen aufgrund von 2-Minuten-Blöcken und Zuweisungsdatenbank)
- **Netzwerk**: Stabile Internetverbindung
- **Uhr**: NTP-Synchronisation empfohlen für optimalen Betrieb

**Hinweis**: Plot-Dateien sind NICHT für den Node-Betrieb erforderlich.

### Mining-Anforderungen

**Zusätzliche Anforderungen für Mining**:
- **Plot-Dateien**: Vorab generiert mit `pocx_plotter` (Referenzimplementierung)
- **Miner-Software**: `pocx_miner` (Referenzimplementierung) verbindet sich via RPC
- **Wallet**: `bitcoind` oder `bitcoin-qt` mit privaten Schlüsseln für Mining-Adresse. Pool-Mining erfordert kein lokales Wallet.

---

## Erste Schritte

### 1. Bitcoin-PoCX kompilieren

```bash
# Mit Submodulen klonen
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Mit aktiviertem PoCX kompilieren
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Details**: Siehe `CLAUDE.md` im Repository-Stammverzeichnis

### 2. Node ausführen

**Nur Node**:
```bash
./build/bin/bitcoind
# oder
./build/bin/bitcoin-qt
```

**Für Mining** (aktiviert RPC-Zugang für externe Miner):
```bash
./build/bin/bitcoind -miningserver
# oder
./build/bin/bitcoin-qt -server -miningserver
```

**Details**: [Kapitel 6: Netzwerkparameter](6-network-parameters.md)

### 3. Plot-Dateien generieren

Verwenden Sie `pocx_plotter` (Referenzimplementierung) um PoCX-Format Plot-Dateien zu generieren.

**Details**: [Kapitel 2: Plot-Format](2-plot-format.md)

### 4. Mining einrichten

Verwenden Sie `pocx_miner` (Referenzimplementierung) um sich mit der RPC-Schnittstelle Ihres Nodes zu verbinden.

**Details**: [Kapitel 7: RPC-Referenz](7-rpc-reference.md) und [Kapitel 8: Wallet-Anleitung](8-wallet-guide.md)

---

## Attribution

### Plot-Format

Basiert auf POC2-Format (Burstcoin) mit Erweiterungen:
- Behobene Sicherheitslücke (XOR-Transpose-Kompressionsangriff)
- Skalierbares Proof-of-Work
- SIMD-optimiertes Layout
- Seed-Funktionalität

### Quellprojekte

- **pocx_miner**: Referenzimplementierung basiert auf [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referenzimplementierung basiert auf [engraver](https://github.com/PoC-Consortium/engraver)

**Vollständige Attribution**: [Kapitel 2: Plot-Format](2-plot-format.md)

---

## Zusammenfassung technischer Spezifikationen

- **Blockzeit**: 120 Sekunden (Mainnet), 1 Sekunde (Regtest)
- **Blocksubvention**: 10 BTC initial, Halving alle 1050000 Blöcke (~4 Jahre)
- **Gesamtangebot**: ~21 Millionen BTC (wie bei Bitcoin)
- **Zukunftstoleranz**: 15 Sekunden (Blöcke bis 15s in der Zukunft werden akzeptiert)
- **Uhren-Warnung**: 10 Sekunden (warnt Betreiber vor Zeitdrift)
- **Zuweisungsverzögerung**: 30 Blöcke (~1 Stunde)
- **Widerrufsverzögerung**: 720 Blöcke (~24 Stunden)
- **Adressformat**: P2WPKH (bech32, pocx1q...) nur für PoCX-Mining-Operationen und Forging-Zuweisungen

---

## Code-Organisation

**Bitcoin Core Modifikationen**: Minimale Änderungen an Kerndateien, Feature-gekennzeichnet mit `#ifdef ENABLE_POCX`

**Neue PoCX-Implementierung**: Isoliert im Verzeichnis `src/pocx/`

---

## Sicherheitsaspekte

### Zeitsicherheit

- 15-Sekunden-Zukunftstoleranz verhindert Netzwerkfragmentierung
- 10-Sekunden-Warnschwelle alarmiert Betreiber bei Uhrendrift
- Defensives Forging eliminiert Anreiz zur Uhrenmanipulation
- Time-Bending reduziert Auswirkungen von Zeitvarianz

**Details**: [Kapitel 5: Zeitsynchronisation und Sicherheit](5-timing-security.md)

### Zuweisungssicherheit

- OP_RETURN-basiertes Design (keine UTXO-Manipulation)
- Transaktionssignatur beweist Plot-Eigentum
- Aktivierungsverzögerungen verhindern schnelle Zustandsmanipulation
- Reorg-sichere Undo-Daten für alle Zustandsänderungen

**Details**: [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md)

### Konsenssicherheit

- Signatur vom Block-Hash ausgeschlossen (verhindert Veränderbarkeit)
- Begrenzte Signaturgrößen (verhindert DoS)
- Kompressionsgrenz-Validierung (verhindert schwache Beweise)
- Schwierigkeitsanpassung bei jedem Block (reagiert auf Kapazitätsänderungen)

**Details**: [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md)

---

## Netzwerkstatus

**Mainnet**: Noch nicht gestartet
**Testnet**: Verfügbar für Tests
**Regtest**: Voll funktionsfähig für Entwicklung

**Genesis-Block-Parameter**: [Kapitel 6: Netzwerkparameter](6-network-parameters.md)

---

## Nächste Schritte

**Zum Verständnis von PoCX**: Fahren Sie fort mit [Kapitel 2: Plot-Format](2-plot-format.md) um die Plot-Dateistruktur und Formatentwicklung kennenzulernen.

**Für Mining-Einrichtung**: Springen Sie zu [Kapitel 7: RPC-Referenz](7-rpc-reference.md) für Integrationsdetails.

**Für den Betrieb eines Nodes**: Lesen Sie [Kapitel 6: Netzwerkparameter](6-network-parameters.md) für Konfigurationsoptionen.

---

[Inhaltsverzeichnis](index.md) | [Weiter: Plot-Format →](2-plot-format.md)

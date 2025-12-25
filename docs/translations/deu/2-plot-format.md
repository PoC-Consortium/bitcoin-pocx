[← Zurück: Einführung](1-introduction.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Konsens und Mining →](3-consensus-and-mining.md)

---

# Kapitel 2: PoCX Plot-Format-Spezifikation

Dieses Dokument beschreibt das PoCX-Plot-Format, eine erweiterte Version des POC2-Formats mit verbesserter Sicherheit, SIMD-Optimierungen und skalierbarem Proof-of-Work.

## Formatübersicht

PoCX-Plot-Dateien enthalten vorberechnete Shabal256-Hashwerte, die für effiziente Mining-Operationen organisiert sind. Gemäß der PoC-Tradition seit POC1 sind **alle Metadaten im Dateinamen eingebettet** – es gibt keinen Dateiheader.

### Dateierweiterung
- **Standard**: `.pocx` (abgeschlossene Plots)
- **In Bearbeitung**: `.tmp` (während des Plottens, wird nach Abschluss in `.pocx` umbenannt)

## Historischer Kontext und Entwicklung der Schwachstellen

### POC1-Format (Veraltet)
**Zwei große Schwachstellen (Zeit-Speicher-Kompromisse):**

1. **PoW-Verteilungsfehler**
   - Ungleichmäßige Verteilung des Proof-of-Work über Scoops
   - Niedrige Scoop-Nummern konnten spontan berechnet werden
   - **Auswirkung**: Reduzierte Speicheranforderungen für Angreifer

2. **XOR-Kompressionsangriff** (50% Zeit-Speicher-Kompromiss)
   - Nutzte mathematische Eigenschaften aus, um 50% Speicherreduktion zu erreichen
   - **Auswirkung**: Angreifer konnten mit der Hälfte des erforderlichen Speichers minen

**Layout-Optimierung**: Einfaches sequenzielles Scoop-Layout für HDD-Effizienz

### POC2-Format (Burstcoin)
- ✅ **PoW-Verteilungsfehler behoben**
- ❌ **XOR-Transpose-Schwachstelle blieb ungepatcht**
- **Layout**: Behielt sequenzielle Scoop-Optimierung bei

### PoCX-Format (Aktuell)
- ✅ **PoW-Verteilung behoben** (von POC2 geerbt)
- ✅ **XOR-Transpose-Schwachstelle gepatcht** (einzigartig bei PoCX)
- ✅ **Erweitertes SIMD/GPU-Layout** optimiert für parallele Verarbeitung und Speicherkoaleszenz
- ✅ **Skalierbares Proof-of-Work** verhindert Zeit-Speicher-Kompromisse bei wachsender Rechenleistung (PoW wird nur beim Erstellen oder Upgraden von Plotdateien ausgeführt)

## XOR-Transpose-Kodierung

### Das Problem: 50% Zeit-Speicher-Kompromiss

Bei POC1/POC2-Formaten konnten Angreifer die mathematische Beziehung zwischen Scoops ausnutzen, um nur die Hälfte der Daten zu speichern und den Rest während des Minings spontan zu berechnen. Dieser "XOR-Kompressionsangriff" untergrub die Speichergarantie.

### Die Lösung: XOR-Transpose-Härtung

PoCX leitet sein Mining-Format (X1) ab, indem es XOR-Transpose-Kodierung auf Paare von Basis-Warps (X0) anwendet:

**Um Scoop S von Nonce N in einem X1-Warp zu konstruieren:**
1. Nimm Scoop S von Nonce N vom ersten X0-Warp (direkte Position)
2. Nimm Scoop N von Nonce S vom zweiten X0-Warp (transponierte Position)
3. Verknüpfe die beiden 64-Byte-Werte mit XOR, um den X1-Scoop zu erhalten

Der Transpose-Schritt tauscht Scoop- und Nonce-Indizes. In Matrixbegriffen – wobei Zeilen Scoops und Spalten Nonces darstellen – kombiniert er das Element an Position (S, N) im ersten Warp mit dem Element an (N, S) im zweiten.

### Warum dies den Angriff eliminiert

Die XOR-Transpose-Kodierung verknüpft jeden Scoop mit einer gesamten Zeile und einer gesamten Spalte der zugrundeliegenden X0-Daten. Die Wiederherstellung eines einzelnen X1-Scoops erfordert Zugriff auf Daten, die alle 4096 Scoop-Indizes umfassen. Jeder Versuch, fehlende Daten zu berechnen, würde die Neugenerierung von 4096 vollständigen Nonces erfordern statt eines einzelnen – was die asymmetrische Kostenstruktur beseitigt, die vom XOR-Angriff ausgenutzt wurde.

Folglich wird das Speichern des vollständigen X1-Warps zur einzigen rechnerisch tragfähigen Strategie für Miner.

## Dateinamen-Metadatenstruktur

Alle Plot-Metadaten sind im Dateinamen in diesem exakten Format kodiert:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Dateinamenkomponenten

1. **ACCOUNT_PAYLOAD** (40 Hex-Zeichen)
   - Rohe 20-Byte-Konto-Nutzlast als Großbuchstaben-Hex
   - Netzwerkunabhängig (keine Netzwerk-ID oder Prüfsumme)
   - Beispiel: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 Hex-Zeichen)
   - 32-Byte-Seed-Wert als Kleinbuchstaben-Hex
   - **Neu bei PoCX**: Zufälliger 32-Byte-Seed im Dateinamen ersetzt aufeinanderfolgende Nonce-Nummerierung – verhindert Plot-Überlappungen
   - Beispiel: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (Dezimalzahl)
   - **NEUE Größeneinheit bei PoCX**: Ersetzt Nonce-basierte Größenangabe von POC1/POC2
   - **XOR-Transpose-resistentes Design**: Jeder Warp = genau 4096 Nonces (Partitionsgröße erforderlich für XOR-Transpose-resistente Transformation)
   - **Größe**: 1 Warp = 1073741824 Bytes = 1 GiB (praktische Einheit)
   - Beispiel: `1024` (1 TiB Plot = 1024 Warps)

4. **SCALING** (X-präfixierte Dezimalzahl)
   - Skalierungsstufe als `X{stufe}`
   - Höhere Werte = mehr Proof-of-Work erforderlich
   - Beispiel: `X4` (2^4 = 16× POC2-Schwierigkeit)

### Beispiel-Dateinamen
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Dateilayout und Datenstruktur

### Hierarchische Organisation
```
Plot-Datei (KEIN HEADER)
├── Scoop 0
│   ├── Warp 0 (Alle Nonces für diesen Scoop/Warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Konstanten und Größen

| Konstante        | Größe                    | Beschreibung                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Einzelne Shabal256-Hash-Ausgabe                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Hash-Paar, das in einer Mining-Runde gelesen wird                |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops pro Nonce; einer wird pro Runde ausgewählt        |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Alle Scoops einer Nonce (PoC1/PoC2 kleinste Einheit) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Kleinste Einheit bei PoCX                           |

### SIMD-optimiertes Plot-Datei-Layout

PoCX implementiert ein SIMD-bewusstes Nonce-Zugriffsmuster, das vektorisierte Verarbeitung
mehrerer Nonces gleichzeitig ermöglicht. Es baut auf Konzepten aus der [POC2×16-Optimierungsforschung](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) auf, um Speicherdurchsatz und SIMD-Effizienz zu maximieren.

---

#### Traditionelles sequenzielles Layout

Sequenzielle Speicherung von Nonces:

```
[Nonce 0: Scoop-Daten] [Nonce 1: Scoop-Daten] [Nonce 2: Scoop-Daten] ...
```

SIMD-Ineffizienz: Jede SIMD-Lane benötigt dasselbe Wort über Nonces hinweg:

```
Wort 0 von Nonce 0 -> Offset 0
Wort 0 von Nonce 1 -> Offset 512
Wort 0 von Nonce 2 -> Offset 1024
...
```

Scatter-Gather-Zugriff reduziert den Durchsatz.

---

#### PoCX SIMD-optimiertes Layout

PoCX speichert **Wortpositionen über 16 Nonces** zusammenhängend:

```
Cache-Line (64 Bytes):

Wort0_N0 Wort0_N1 Wort0_N2 ... Wort0_N15
Wort1_N0 Wort1_N1 Wort1_N2 ... Wort1_N15
...
```

**ASCII-Diagramm**

```
Traditionelles Layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX-Layout:

Wort0: [N0][N1][N2][N3]...[N15]
Wort1: [N0][N1][N2][N3]...[N15]
Wort2: [N0][N1][N2][N3]...[N15]
```

---

#### Vorteile beim Speicherzugriff

- Eine Cache-Line versorgt alle SIMD-Lanes.
- Eliminiert Scatter-Gather-Operationen.
- Reduziert Cache-Misses.
- Vollständig sequenzieller Speicherzugriff für vektorisierte Berechnung.
- GPUs profitieren ebenfalls von der 16-Nonce-Ausrichtung, maximiert Cache-Effizienz.

---

#### SIMD-Skalierung

| SIMD       | Vektorbreite* | Nonces | Verarbeitungszyklen pro Cache-Line |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 Zyklen                        |
| AVX2       | 256-bit       | 8      | 2 Zyklen                        |
| AVX512     | 512-bit       | 16     | 1 Zyklus                         |

\* Für Integer-Operationen

---



## Proof-of-Work-Skalierung

### Skalierungsstufen
- **X0**: Basis-Nonces ohne XOR-Transpose-Kodierung (theoretisch, nicht für Mining verwendet)
- **X1**: XOR-Transpose-Baseline – erstes gehärtetes Format (1× Arbeit)
- **X2**: 2× X1-Arbeit (XOR über 2 Warps)
- **X3**: 4× X1-Arbeit (XOR über 4 Warps)
- **…**
- **Xn**: 2^(n-1) × X1-Arbeit eingebettet

### Vorteile
- **Anpassbare PoW-Schwierigkeit**: Erhöht Rechenanforderungen, um mit schnellerer Hardware Schritt zu halten
- **Formatlanglebigkeit**: Ermöglicht flexible Skalierung der Mining-Schwierigkeit im Laufe der Zeit

### Plot-Upgrade / Rückwärtskompatibilität

Wenn das Netzwerk die PoW (Proof of Work) Skala um 1 erhöht, benötigen bestehende Plots ein Upgrade, um die gleiche effektive Plotgröße beizubehalten. Im Wesentlichen benötigen Sie jetzt doppelt so viel PoW in Ihren Plotdateien, um den gleichen Beitrag zu Ihrem Konto zu erreichen.

Die gute Nachricht ist, dass das PoW, das Sie bereits beim Erstellen Ihrer Plotdateien geleistet haben, nicht verloren geht – Sie müssen lediglich zusätzliches PoW zu den bestehenden Dateien hinzufügen. Kein Neu-Plotten erforderlich.

Alternativ können Sie Ihre aktuellen Plots ohne Upgrade weiter verwenden, aber beachten Sie, dass sie jetzt nur noch 50% ihrer vorherigen effektiven Größe zu Ihrem Konto beitragen. Ihre Mining-Software kann eine Plotdatei spontan skalieren.

## Vergleich mit älteren Formaten

| Funktion | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW-Verteilung | ❌ Fehlerhaft | ✅ Behoben | ✅ Behoben |
| XOR-Transpose-Resistenz | ❌ Anfällig | ❌ Anfällig | ✅ Behoben |
| SIMD-Optimierung | ❌ Keine | ❌ Keine | ✅ Fortgeschritten |
| GPU-Optimierung | ❌ Keine | ❌ Keine | ✅ Optimiert |
| Skalierbares Proof-of-Work | ❌ Keine | ❌ Keine | ✅ Ja |
| Seed-Unterstützung | ❌ Keine | ❌ Keine | ✅ Ja |

Das PoCX-Format repräsentiert den aktuellen Stand der Technik bei Proof of Capacity Plot-Formaten und behebt alle bekannten Schwachstellen bei gleichzeitiger Bereitstellung erheblicher Leistungsverbesserungen für moderne Hardware.

## Referenzen und weiterführende Literatur

- **POC1/POC2-Hintergrund**: [Burstcoin Mining-Übersicht](https://www.burstcoin.community/burstcoin-mining/) - Umfassende Anleitung zu traditionellen Proof of Capacity Mining-Formaten
- **POC2×16-Forschung**: [CIP-Ankündigung: POC2×16 - Ein neues optimiertes Plot-Format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Originale SIMD-Optimierungsforschung, die PoCX inspiriert hat
- **Shabal-Hash-Algorithmus**: [Das Saphir-Projekt: Shabal, ein Beitrag zum NIST Kryptografischen Hash-Algorithmus-Wettbewerb](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Technische Spezifikation des im PoC-Mining verwendeten Shabal256-Algorithmus

---

[← Zurück: Einführung](1-introduction.md) | [Inhaltsverzeichnis](index.md) | [Weiter: Konsens und Mining →](3-consensus-and-mining.md)

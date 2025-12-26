# Bitcoin-PoCX Technische Dokumentation

**Version**: 1.0
**Bitcoin Core Basis**: v30.0
**Status**: Testnet-Phase
**Letzte Aktualisierung**: 25.12.2025

---

## Über diese Dokumentation

Dies ist die vollständige technische Dokumentation für Bitcoin-PoCX, eine Bitcoin Core Integration, die Unterstützung für den Proof of Capacity neXt generation (PoCX) Konsensmechanismus hinzufügt. Die Dokumentation ist als navigierbare Anleitung mit untereinander verknüpften Kapiteln aufgebaut, die alle Aspekte des Systems abdecken.

**Zielgruppen**:
- **Node-Betreiber**: Kapitel 1, 5, 6, 8
- **Miner**: Kapitel 2, 3, 7
- **Entwickler**: Alle Kapitel
- **Forscher**: Kapitel 3, 4, 5

---

## Übersetzungen

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabisch](../ara/index.md) | [🇧🇬 Bulgarisch](../bul/index.md) | [🇨🇳 Chinesisch](../zho/index.md) | [🇩🇰 Dänisch](../dan/index.md) | [🇪🇪 Estnisch](../est/index.md) | [🇵🇭 Filipino](../fil/index.md) |
| [🇫🇮 Finnisch](../fin/index.md) | [🇫🇷 Französisch](../fra/index.md) | [🇬🇷 Griechisch](../ell/index.md) | [🇮🇱 Hebräisch](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇮🇩 Indonesisch](../ind/index.md) |
| [🇮🇹 Italienisch](../ita/index.md) | [🇯🇵 Japanisch](../jpn/index.md) | [🇰🇷 Koreanisch](../kor/index.md) | [🇱🇻 Lettisch](../lav/index.md) | [🇱🇹 Litauisch](../lit/index.md) | [🇳🇱 Niederländisch](../nld/index.md) |
| [🇳🇴 Norwegisch](../nor/index.md) | [🇵🇱 Polnisch](../pol/index.md) | [🇵🇹 Portugiesisch](../por/index.md) | [🇷🇴 Rumänisch](../ron/index.md) | [🇷🇺 Russisch](../rus/index.md) | [🇸🇪 Schwedisch](../swe/index.md) |
| [🇷🇸 Serbisch](../srp/index.md) | [🇪🇸 Spanisch](../spa/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇨🇿 Tschechisch](../ces/index.md) | [🇹🇷 Türkisch](../tur/index.md) | [🇺🇦 Ukrainisch](../ukr/index.md) |
| [🇭🇺 Ungarisch](../hun/index.md) | [🇻🇳 Vietnamesisch](../vie/index.md) | | | | |

---

## Inhaltsverzeichnis

### Teil I: Grundlagen

**[Kapitel 1: Einführung und Übersicht](1-introduction.md)**
Projektübersicht, Architektur, Designphilosophie, Kernfunktionen und Unterschiede zwischen PoCX und Proof of Work.

**[Kapitel 2: Plot-Dateiformat](2-plot-format.md)**
Vollständige Spezifikation des PoCX-Plot-Formats einschließlich SIMD-Optimierung, Proof-of-Work-Skalierung und Formatentwicklung von POC1/POC2.

**[Kapitel 3: Konsens und Mining](3-consensus-and-mining.md)**
Vollständige technische Spezifikation des PoCX-Konsensmechanismus: Blockstruktur, Generierungssignaturen, Basisziel-Anpassung, Mining-Prozess, Validierungspipeline und Time-Bending-Algorithmus.

---

### Teil II: Erweiterte Funktionen

**[Kapitel 4: Forging-Zuweisungssystem](4-forging-assignments.md)**
OP_RETURN-basierte Architektur zur Delegation von Forging-Rechten: Transaktionsstruktur, Datenbankdesign, Zustandsautomat, Reorg-Behandlung und RPC-Schnittstelle.

**[Kapitel 5: Zeitsynchronisation und Sicherheit](5-timing-security.md)**
Uhrendrift-Toleranz, defensiver Forging-Mechanismus, Schutz vor Uhrenmanipulation und zeitbezogene Sicherheitsaspekte.

**[Kapitel 6: Netzwerkparameter](6-network-parameters.md)**
Chainparams-Konfiguration, Genesis-Block, Konsensparameter, Coinbase-Regeln, dynamische Skalierung und Wirtschaftsmodell.

---

### Teil III: Nutzung und Integration

**[Kapitel 7: RPC-Schnittstellenreferenz](7-rpc-reference.md)**
Vollständige RPC-Befehlsreferenz für Mining, Zuweisungen und Blockchain-Abfragen. Unverzichtbar für Miner- und Pool-Integration.

**[Kapitel 8: Wallet- und GUI-Anleitung](8-wallet-guide.md)**
Benutzerhandbuch für das Bitcoin-PoCX Qt-Wallet: Forging-Zuweisungsdialog, Transaktionsverlauf, Mining-Einrichtung und Fehlerbehebung.

---

## Schnellnavigation

### Für Node-Betreiber
→ Beginnen Sie mit [Kapitel 1: Einführung](1-introduction.md)
→ Lesen Sie dann [Kapitel 6: Netzwerkparameter](6-network-parameters.md)
→ Konfigurieren Sie Mining mit [Kapitel 8: Wallet-Anleitung](8-wallet-guide.md)

### Für Miner
→ Verstehen Sie [Kapitel 2: Plot-Format](2-plot-format.md)
→ Lernen Sie den Prozess in [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md)
→ Integrieren Sie mit [Kapitel 7: RPC-Referenz](7-rpc-reference.md)

### Für Pool-Betreiber
→ Lesen Sie [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md)
→ Studieren Sie [Kapitel 7: RPC-Referenz](7-rpc-reference.md)
→ Implementieren Sie mit Zuweisungs-RPCs und submit_nonce

### Für Entwickler
→ Lesen Sie alle Kapitel der Reihe nach
→ Vergleichen Sie die durchgehend notierten Implementierungsdateien
→ Untersuchen Sie die Verzeichnisstruktur `src/pocx/`
→ Erstellen Sie Releases mit [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentationskonventionen

**Dateireferenzen**: Implementierungsdetails verweisen auf Quelldateien als `pfad/zur/datei.cpp:zeile`

**Code-Integration**: Alle Änderungen sind mit `#ifdef ENABLE_POCX` Feature-gekennzeichnet

**Querverweise**: Kapitel verlinken über relative Markdown-Links auf verwandte Abschnitte

**Technisches Niveau**: Die Dokumentation setzt Vertrautheit mit Bitcoin Core und C++-Entwicklung voraus

---

## Kompilierung

### Entwicklungs-Build

```bash
# Mit Submodulen klonen
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Mit aktiviertem PoCX konfigurieren
cmake -B build -DENABLE_POCX=ON

# Kompilieren
cmake --build build -j$(nproc)
```

**Build-Varianten**:
```bash
# Mit Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debug-Build
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Abhängigkeiten**: Standard Bitcoin Core Build-Abhängigkeiten. Siehe [Bitcoin Core Build-Dokumentation](https://github.com/bitcoin/bitcoin/tree/master/doc#building) für plattformspezifische Anforderungen.

### Release-Builds

Für reproduzierbare Release-Binärdateien verwenden Sie das GUIX-Build-System: Siehe [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Zusätzliche Ressourcen

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Verwandte Projekte**:
- Plotter: Basiert auf [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Basiert auf [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Hinweise zum Lesen dieser Dokumentation

**Sequenzielles Lesen**: Kapitel sind zum sequenziellen Lesen konzipiert und bauen auf vorherigen Konzepten auf.

**Nachschlagelesen**: Verwenden Sie das Inhaltsverzeichnis, um direkt zu bestimmten Themen zu springen. Jedes Kapitel ist eigenständig mit Querverweisen zu verwandtem Material.

**Browser-Navigation**: Öffnen Sie `index.md` in einem Markdown-Viewer oder Browser. Alle internen Links sind relativ und funktionieren offline.

**PDF-Export**: Diese Dokumentation kann zu einem einzelnen PDF für Offline-Lesen zusammengefügt werden.

---

## Projektstatus

**Funktionsumfang abgeschlossen**: Alle Konsensregeln, Mining, Zuweisungen und Wallet-Funktionen implementiert.

**Dokumentation abgeschlossen**: Alle 8 Kapitel vollständig und gegen die Codebasis verifiziert.

**Testnet aktiv**: Derzeit in der Testnet-Phase für Community-Tests.

---

## Mitwirken

Beiträge zur Dokumentation sind willkommen. Bitte beachten Sie:
- Technische Genauigkeit vor Ausführlichkeit
- Kurze, prägnante Erklärungen
- Kein Code oder Pseudocode in der Dokumentation (stattdessen auf Quelldateien verweisen)
- Nur Implementiertes (keine spekulativen Funktionen)

---

## Lizenz

Bitcoin-PoCX übernimmt die MIT-Lizenz von Bitcoin Core. Siehe `COPYING` im Repository-Stammverzeichnis.

Attribution zum PoCX-Core-Framework dokumentiert in [Kapitel 2: Plot-Format](2-plot-format.md).

---

**Lesen beginnen**: [Kapitel 1: Einführung und Übersicht →](1-introduction.md)

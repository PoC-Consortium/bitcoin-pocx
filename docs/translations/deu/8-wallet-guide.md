[← Zurück: RPC-Referenz](7-rpc-reference.md) | [Inhaltsverzeichnis](index.md)

---

# Kapitel 8: Wallet- und GUI-Benutzerhandbuch

Vollständige Anleitung zum Bitcoin-PoCX Qt-Wallet und zur Forging-Zuweisungsverwaltung.

---

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Währungseinheiten](#währungseinheiten)
3. [Forging-Zuweisungsdialog](#forging-zuweisungsdialog)
4. [Transaktionsverlauf](#transaktionsverlauf)
5. [Adressanforderungen](#adressanforderungen)
6. [Mining-Integration](#mining-integration)
7. [Fehlerbehebung](#fehlerbehebung)
8. [Sicherheits-Best-Practices](#sicherheits-best-practices)

---

## Übersicht

### Bitcoin-PoCX Wallet-Funktionen

Das Bitcoin-PoCX Qt-Wallet (`bitcoin-qt`) bietet:
- Standard Bitcoin Core Wallet-Funktionalität (Senden, Empfangen, Transaktionsverwaltung)
- **Forging-Zuweisungsmanager**: GUI zum Erstellen/Widerrufen von Plot-Zuweisungen
- **Mining-Server-Modus**: `-miningserver` Flag aktiviert Mining-bezogene Funktionen
- **Transaktionsverlauf**: Anzeige von Zuweisungs- und Widerrufstransaktionen

### Starten des Wallets

**Nur Node** (kein Mining):
```bash
./build/bin/bitcoin-qt
```

**Mit Mining** (aktiviert Zuweisungsdialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Kommandozeilen-Alternative**:
```bash
./build/bin/bitcoind -miningserver
```

### Mining-Anforderungen

**Für Mining-Operationen**:
- `-miningserver` Flag erforderlich
- Wallet mit P2WPKH-Adressen und privaten Schlüsseln
- Externer Plotter (`pocx_plotter`) für Plot-Generierung
- Externer Miner (`pocx_miner`) für Mining

**Für Pool-Mining**:
- Forging-Zuweisung an Pool-Adresse erstellen
- Wallet auf Pool-Server nicht erforderlich (Pool verwaltet Schlüssel)

---

## Währungseinheiten

### Einheitenanzeige

Bitcoin-PoCX verwendet die Währungseinheit **BTCX** (nicht BTC):

| Einheit     | Satoshis  | Anzeige          |
|-------------|-----------|------------------|
| **BTCX**    | 100000000 | 1,00000000 BTCX  |
| **mBTCX**   | 100000    | 1000,00 mBTCX    |
| **µBTCX**   | 100       | 1000000,00 µBTCX |
| **satoshi** | 1         | 100000000 sat    |

**GUI-Einstellungen**: Einstellungen → Anzeige → Einheit

---

## Forging-Zuweisungsdialog

### Zugriff auf den Dialog

**Menü**: `Wallet → Forging-Zuweisungen`
**Symbolleiste**: Mining-Symbol (nur sichtbar mit `-miningserver` Flag)
**Fenstergröße**: 600×450 Pixel

### Dialog-Modi

#### Modus 1: Zuweisung erstellen

**Zweck**: Forging-Rechte an Pool oder andere Adresse delegieren, während Plot-Eigentum erhalten bleibt.

**Anwendungsfälle**:
- Pool-Mining (an Pool-Adresse zuweisen)
- Cold Storage (Mining-Schlüssel getrennt vom Plot-Eigentum)
- Gemeinsame Infrastruktur (an Hot-Wallet delegieren)

**Anforderungen**:
- Plot-Adresse (P2WPKH bech32, muss privaten Schlüssel besitzen)
- Forging-Adresse (P2WPKH bech32, unterschiedlich von Plot-Adresse)
- Wallet entsperrt (falls verschlüsselt)
- Plot-Adresse hat bestätigte UTXOs

**Schritte**:
1. Modus "Zuweisung erstellen" wählen
2. Plot-Adresse aus Dropdown wählen oder manuell eingeben
3. Forging-Adresse eingeben (Pool oder Delegierter)
4. "Zuweisung senden" klicken (Schaltfläche aktiviert wenn Eingaben gültig)
5. Transaktion wird sofort gesendet
6. Zuweisung aktiv nach `nForgingAssignmentDelay` Blöcken:
   - Mainnet/Testnet: 30 Blöcke (~1 Stunde)
   - Regtest: 4 Blöcke (~4 Sekunden)

**Transaktionsgebühr**: Standard 10× `minRelayFee` (anpassbar)

**Transaktionsstruktur**:
- Eingabe: UTXO von Plot-Adresse (beweist Eigentum)
- OP_RETURN-Ausgabe: `POCX`-Marker + plot_address + forging_address (46 Bytes)
- Wechselgeld-Ausgabe: Zurück ans Wallet

#### Modus 2: Zuweisung widerrufen

**Zweck**: Forging-Zuweisung aufheben und Rechte an Plotbesitzer zurückgeben.

**Anforderungen**:
- Plot-Adresse (muss privaten Schlüssel besitzen)
- Wallet entsperrt (falls verschlüsselt)
- Plot-Adresse hat bestätigte UTXOs

**Schritte**:
1. Modus "Zuweisung widerrufen" wählen
2. Plot-Adresse wählen
3. "Widerruf senden" klicken
4. Transaktion wird sofort gesendet
5. Widerruf wirksam nach `nForgingRevocationDelay` Blöcken:
   - Mainnet/Testnet: 720 Blöcke (~24 Stunden)
   - Regtest: 8 Blöcke (~8 Sekunden)

**Effekt**:
- Forging-Adresse kann während Verzögerungsperiode noch schmieden
- Plotbesitzer erhält Rechte nach abgeschlossenem Widerruf zurück
- Kann danach neue Zuweisung erstellen

**Transaktionsstruktur**:
- Eingabe: UTXO von Plot-Adresse (beweist Eigentum)
- OP_RETURN-Ausgabe: `XCOP`-Marker + plot_address (26 Bytes)
- Wechselgeld-Ausgabe: Zurück ans Wallet

#### Modus 3: Zuweisungsstatus prüfen

**Zweck**: Aktuellen Zuweisungszustand für beliebige Plot-Adresse abfragen.

**Anforderungen**: Keine (nur-lesen, kein Wallet erforderlich)

**Schritte**:
1. Modus "Zuweisungsstatus prüfen" wählen
2. Plot-Adresse eingeben
3. "Status prüfen" klicken
4. Statusfeld zeigt aktuellen Zustand mit Details

**Zustandsindikatoren** (farbcodiert):

**Grau - UNASSIGNED**
```
UNASSIGNED - Keine Zuweisung vorhanden
```

**Orange - ASSIGNING**
```
ASSIGNING - Zuweisung wartet auf Aktivierung
Forging-Adresse: pocx1qforger...
Erstellt bei Höhe: 12000
Aktiviert bei Höhe: 12030 (5 Blöcke verbleibend)
```

**Grün - ASSIGNED**
```
ASSIGNED - Aktive Zuweisung
Forging-Adresse: pocx1qforger...
Erstellt bei Höhe: 12000
Aktiviert bei Höhe: 12030
```

**Rotorange - REVOKING**
```
REVOKING - Widerruf ausstehend
Forging-Adresse: pocx1qforger... (noch aktiv)
Zuweisung erstellt bei Höhe: 12000
Widerrufen bei Höhe: 12300
Widerruf wirksam bei Höhe: 13020 (50 Blöcke verbleibend)
```

**Rot - REVOKED**
```
REVOKED - Zuweisung widerrufen
Vorher zugewiesen an: pocx1qforger...
Zuweisung erstellt bei Höhe: 12000
Widerrufen bei Höhe: 12300
Widerruf wirksam bei Höhe: 13020
```

---

## Transaktionsverlauf

### Anzeige von Zuweisungstransaktionen

**Typ**: "Zuweisung"
**Symbol**: Mining-Symbol (wie bei geschürften Blöcken)

**Adressspalte**: Plot-Adresse (Adresse deren Forging-Rechte zugewiesen werden)
**Betragsspalte**: Transaktionsgebühr (negativ, ausgehende Transaktion)
**Statusspalte**: Bestätigungsanzahl (0-6+)

**Details** (bei Klick):
- Transaktions-ID
- Plot-Adresse
- Forging-Adresse (aus OP_RETURN geparst)
- Erstellt bei Höhe
- Aktivierungshöhe
- Transaktionsgebühr
- Zeitstempel

### Anzeige von Widerrufstransaktionen

**Typ**: "Widerruf"
**Symbol**: Mining-Symbol

**Adressspalte**: Plot-Adresse
**Betragsspalte**: Transaktionsgebühr (negativ)
**Statusspalte**: Bestätigungsanzahl

**Details** (bei Klick):
- Transaktions-ID
- Plot-Adresse
- Widerrufen bei Höhe
- Widerruf-Wirksamkeitshöhe
- Transaktionsgebühr
- Zeitstempel

### Transaktionsfilterung

**Verfügbare Filter**:
- "Alle" (Standard, enthält Zuweisungen/Widerrufe)
- Datumsbereich
- Betragsbereich
- Suche nach Adresse
- Suche nach Transaktions-ID
- Suche nach Label (falls Adresse beschriftet)

**Hinweis**: Zuweisungs-/Widerrufstransaktionen erscheinen derzeit unter "Alle"-Filter. Dedizierter Typfilter noch nicht implementiert.

### Transaktionssortierung

**Sortierreihenfolge** (nach Typ):
- Generiert (Typ 0)
- Empfangen (Typ 1-3)
- Zuweisung (Typ 4)
- Widerruf (Typ 5)
- Gesendet (Typ 6+)

---

## Adressanforderungen

### Nur P2WPKH (SegWit v0)

**Forging-Operationen erfordern**:
- Bech32-kodierte Adressen (beginnend mit "pocx1q" Mainnet, "tpocx1q" Testnet, "rpocx1q" Regtest)
- P2WPKH-Format (Pay-to-Witness-Public-Key-Hash)
- 20-Byte-Schlüssel-Hash

**NICHT unterstützt**:
- P2PKH (Legacy, beginnend mit "1")
- P2SH (Wrapped SegWit, beginnend mit "3")
- P2TR (Taproot, beginnend mit "bc1p")

**Begründung**: PoCX-Blocksignaturen erfordern spezifisches Witness v0 Format für Beweisvalidierung.

### Adress-Dropdown-Filterung

**Plot-Adresse-ComboBox**:
- Automatisch mit Empfangsadressen des Wallets befüllt
- Filtert Nicht-P2WPKH-Adressen aus
- Zeigt Format: "Label (adresse)" falls beschriftet, sonst nur Adresse
- Erster Eintrag: "-- Benutzerdefinierte Adresse eingeben --" für manuelle Eingabe

**Manuelle Eingabe**:
- Validiert Format bei Eingabe
- Muss gültiges bech32 P2WPKH sein
- Schaltfläche deaktiviert bei ungültigem Format

### Validierungsfehlermeldungen

**Dialogfehler**:
- "Plot-Adresse muss P2WPKH (bech32) sein"
- "Forging-Adresse muss P2WPKH (bech32) sein"
- "Ungültiges Adressformat"
- "Keine Coins an der Plot-Adresse verfügbar. Eigentum kann nicht bewiesen werden."
- "Kann keine Transaktionen mit Watch-Only-Wallet erstellen"
- "Wallet nicht verfügbar"
- "Wallet gesperrt" (von RPC)

---

## Mining-Integration

### Einrichtungsanforderungen

**Node-Konfiguration**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Wallet-Anforderungen**:
- P2WPKH-Adressen für Plot-Eigentum
- Private Schlüssel für Mining (oder Forging-Adresse bei Verwendung von Zuweisungen)
- Bestätigte UTXOs für Transaktionserstellung

**Externe Werkzeuge**:
- `pocx_plotter`: Plotdateien generieren
- `pocx_miner`: Plots scannen und Nonces übermitteln

### Workflow

#### Solo-Mining

1. **Plotdateien generieren**:
   ```bash
   pocx_plotter --account <plot_adresse_hash160> --seed <32_bytes> --nonces <anzahl>
   ```

2. **Node starten** mit Mining-Server:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Miner konfigurieren**:
   - Auf Node-RPC-Endpunkt zeigen
   - Plotdatei-Verzeichnisse angeben
   - Konto-ID konfigurieren (von Plot-Adresse)

4. **Mining starten**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /pfad/zu/plots
   ```

5. **Überwachen**:
   - Miner ruft `get_mining_info` bei jedem Block auf
   - Scannt Plots nach bester Deadline
   - Ruft `submit_nonce` auf wenn Lösung gefunden
   - Node validiert und schmiedet Block automatisch

#### Pool-Mining

1. **Plotdateien generieren** (wie bei Solo-Mining)

2. **Forging-Zuweisung erstellen**:
   - Forging-Zuweisungsdialog öffnen
   - Plot-Adresse auswählen
   - Forging-Adresse des Pools eingeben
   - "Zuweisung senden" klicken
   - Auf Aktivierungsverzögerung warten (30 Blöcke Testnet)

3. **Miner konfigurieren**:
   - Auf **Pool**-Endpunkt zeigen (nicht lokaler Node)
   - Pool behandelt `submit_nonce` zur Chain

4. **Pool-Betrieb**:
   - Pool-Wallet hat private Schlüssel der Forging-Adresse
   - Pool validiert Übermittlungen von Minern
   - Pool ruft `submit_nonce` zur Blockchain auf
   - Pool verteilt Belohnungen gemäß Pool-Richtlinie

### Coinbase-Belohnungen

**Ohne Zuweisung**:
- Coinbase zahlt direkt an Plotbesitzer-Adresse
- Kontostand in Plot-Adresse prüfen

**Mit Zuweisung**:
- Coinbase zahlt an Forging-Adresse
- Pool erhält Belohnungen
- Miner erhält Anteil vom Pool

**Belohnungszeitplan**:
- Initial: 10 BTCX pro Block
- Halving: Alle 1050000 Blöcke (~4 Jahre)
- Zeitplan: 10 → 5 → 2,5 → 1,25 → ...

---

## Fehlerbehebung

### Häufige Probleme

#### "Wallet hat keinen privaten Schlüssel für Plot-Adresse"

**Ursache**: Wallet besitzt die Adresse nicht
**Lösung**:
- Privaten Schlüssel via `importprivkey` RPC importieren
- Oder andere dem Wallet gehörende Plot-Adresse verwenden

#### "Zuweisung existiert bereits für diesen Plot"

**Ursache**: Plot bereits an andere Adresse zugewiesen
**Lösung**:
1. Bestehende Zuweisung widerrufen
2. Auf Widerrufsverzögerung warten (720 Blöcke Testnet)
3. Neue Zuweisung erstellen

#### "Adressformat wird nicht unterstützt"

**Ursache**: Adresse nicht P2WPKH bech32
**Lösung**:
- Adressen verwenden, die mit "pocx1q" (Mainnet) oder "tpocx1q" (Testnet) beginnen
- Bei Bedarf neue Adresse generieren: `getnewaddress "" "bech32"`

#### "Transaktionsgebühr zu niedrig"

**Ursache**: Netzwerk-Mempool-Überlastung oder zu niedrige Relay-Gebühr
**Lösung**:
- Gebührenraten-Parameter erhöhen
- Auf Mempool-Entlastung warten

#### "Zuweisung noch nicht aktiv"

**Ursache**: Aktivierungsverzögerung noch nicht abgelaufen
**Lösung**:
- Status prüfen: verbleibende Blöcke bis Aktivierung
- Warten bis Verzögerungsperiode abgeschlossen

#### "Keine Coins an der Plot-Adresse verfügbar"

**Ursache**: Plot-Adresse hat keine bestätigten UTXOs
**Lösung**:
1. Guthaben an Plot-Adresse senden
2. Auf 1 Bestätigung warten
3. Zuweisungserstellung erneut versuchen

#### "Kann keine Transaktionen mit Watch-Only-Wallet erstellen"

**Ursache**: Wallet hat Adresse ohne privaten Schlüssel importiert
**Lösung**: Vollständigen privaten Schlüssel importieren, nicht nur Adresse

#### "Forging-Zuweisungs-Tab nicht sichtbar"

**Ursache**: Node ohne `-miningserver` Flag gestartet
**Lösung**: Neustart mit `bitcoin-qt -server -miningserver`

### Debug-Schritte

1. **Wallet-Status prüfen**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Adresseigentum verifizieren**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Prüfen: "iswatchonly": false, "ismine": true
   ```

3. **Zuweisungsstatus prüfen**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Letzte Transaktionen anzeigen**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Node-Sync prüfen**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifizieren: blocks == headers (vollständig synchronisiert)
   ```

---

## Sicherheits-Best-Practices

### Plot-Adress-Sicherheit

**Schlüsselverwaltung**:
- Private Schlüssel der Plot-Adresse sicher aufbewahren
- Zuweisungstransaktionen beweisen Eigentum via Signatur
- Nur Plotbesitzer kann Zuweisungen erstellen/widerrufen

**Backup**:
- Wallet regelmäßig sichern (`dumpwallet` oder `backupwallet`)
- wallet.dat an sicherem Ort aufbewahren
- Wiederherstellungsphrasen aufzeichnen bei HD-Wallet

### Forging-Adress-Delegation

**Sicherheitsmodell**:
- Forging-Adresse erhält Blockbelohnungen
- Forging-Adresse kann Blöcke signieren (Mining)
- Forging-Adresse **kann** Zuweisung **nicht** ändern oder widerrufen
- Plotbesitzer behält volle Kontrolle

**Anwendungsfälle**:
- **Hot-Wallet-Delegation**: Plot-Schlüssel in Cold Storage, Forging-Schlüssel in Hot-Wallet für Mining
- **Pool-Mining**: An Pool delegieren, Plot-Eigentum behalten
- **Gemeinsame Infrastruktur**: Mehrere Miner, eine Forging-Adresse

### Netzwerk-Zeitsynchronisation

**Wichtigkeit**:
- PoCX-Konsens erfordert genaue Zeit
- Uhrendrift >10s löst Warnung aus
- Uhrendrift >15s verhindert Mining

**Lösung**:
- Systemuhr mit NTP synchronisiert halten
- Überwachen: `bitcoin-cli getnetworkinfo` für Zeitoffset-Warnungen
- Zuverlässige NTP-Server verwenden

### Zuweisungsverzögerungen

**Aktivierungsverzögerung** (30 Blöcke Testnet):
- Verhindert schnelle Neuzuweisung bei Chain-Forks
- Ermöglicht Netzwerkkonsens
- Kann nicht umgangen werden

**Widerrufsverzögerung** (720 Blöcke Testnet):
- Bietet Stabilität für Mining-Pools
- Verhindert "Zuweisungs-Hopping"-Angriffe
- Forging-Adresse bleibt während Verzögerung aktiv

### Wallet-Verschlüsselung

**Verschlüsselung aktivieren**:
```bash
bitcoin-cli encryptwallet "ihre_passphrase"
```

**Für Transaktionen entsperren**:
```bash
bitcoin-cli walletpassphrase "ihre_passphrase" 300
```

**Best Practices**:
- Starke Passphrase verwenden (20+ Zeichen)
- Passphrase nicht im Klartext speichern
- Wallet nach Zuweisungserstellung sperren

---

## Code-Referenzen

**Forging-Zuweisungsdialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaktionsanzeige**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaktions-Parsing**: `src/qt/transactionrecord.cpp`
**Wallet-Integration**: `src/pocx/assignments/transactions.cpp`
**Zuweisungs-RPCs**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI-Hauptdatei**: `src/qt/bitcoingui.cpp`

---

## Querverweise

Verwandte Kapitel:
- [Kapitel 3: Konsens und Mining](3-consensus-and-mining.md) - Mining-Prozess
- [Kapitel 4: Forging-Zuweisungen](4-forging-assignments.md) - Zuweisungsarchitektur
- [Kapitel 6: Netzwerkparameter](6-network-parameters.md) - Zuweisungsverzögerungswerte
- [Kapitel 7: RPC-Referenz](7-rpc-reference.md) - RPC-Befehlsdetails

---

[← Zurück: RPC-Referenz](7-rpc-reference.md) | [Inhaltsverzeichnis](index.md)

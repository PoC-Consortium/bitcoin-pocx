[Vorige: RPC-referentie](7-rpc-reference.md) | [Inhoudsopgave](index.md)

---

# Hoofdstuk 8: Wallet- en GUI-gebruikershandleiding

Volledige handleiding voor Bitcoin-PoCX Qt-wallet en forging-toewijzingsbeheer.

---

## Inhoudsopgave

1. [Overzicht](#overzicht)
2. [Valuta-eenheden](#valuta-eenheden)
3. [Forging-toewijzingsdialoog](#forging-toewijzingsdialoog)
4. [Transactiegeschiedenis](#transactiegeschiedenis)
5. [Adresvereisten](#adresvereisten)
6. [Mining-integratie](#mining-integratie)
7. [Probleemoplossing](#probleemoplossing)
8. [Beveiligings-best practices](#beveiligings-best-practices)

---

## Overzicht

### Bitcoin-PoCX wallet-functies

De Bitcoin-PoCX Qt-wallet (`bitcoin-qt`) biedt:
- Standaard Bitcoin Core-walletfunctionaliteit (verzenden, ontvangen, transactiebeheer)
- **Forging-toewijzingsmanager**: GUI voor creeren/intrekken van plottoewijzingen
- **Miningservermodus**: `-miningserver`-vlag schakelt mininggerelateerde functies in
- **Transactiegeschiedenis**: Toewijzings- en intrekkingstransactieweergave

### De wallet starten

**Alleen node** (geen mining):
```bash
./build/bin/bitcoin-qt
```

**Met mining** (schakelt toewijzingsdialoog in):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Opdrachtregelalternatief**:
```bash
./build/bin/bitcoind -miningserver
```

### Miningvereisten

**Voor miningoperaties**:
- `-miningserver`-vlag vereist
- Wallet met P2WPKH-adressen en privesleutels
- Externe plotter (`pocx_plotter`) voor plotgeneratie
- Externe miner (`pocx_miner`) voor mining

**Voor pool-mining**:
- Creeer forging-toewijzing naar pooladres
- Wallet niet vereist op poolserver (pool beheert sleutels)

---

## Valuta-eenheden

### Eenheidsweergave

Bitcoin-PoCX gebruikt **BTCX** valuta-eenheid (niet BTC):

| Eenheid | Satoshi's | Weergave |
|---------|-----------|----------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **uBTCX** | 100 | 1000000,00 uBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI-instellingen**: Voorkeuren > Weergave > Eenheid

---

## Forging-toewijzingsdialoog

### Toegang tot de dialoog

**Menu**: `Wallet > Forging-toewijzingen`
**Werkbalk**: Miningpictogram (alleen zichtbaar met `-miningserver`-vlag)
**Venstergrootte**: 600x450 pixels

### Dialoogmodi

#### Modus 1: Toewijzing creeren

**Doel**: Delegeer forgingrechten aan pool of ander adres terwijl ploteigenaarschap behouden blijft.

**Gebruiksscenario's**:
- Pool-mining (toewijzen aan pooladres)
- Cold storage (miningsleutel gescheiden van ploteigenaarschap)
- Gedeelde infrastructuur (delegeren aan hot wallet)

**Vereisten**:
- Plotadres (P2WPKH bech32, moet privesleutel bezitten)
- Forgingadres (P2WPKH bech32, anders dan plotadres)
- Wallet ontgrendeld (indien versleuteld)
- Plotadres heeft bevestigde UTXO's

**Stappen**:
1. Selecteer "Toewijzing creeren"-modus
2. Kies plotadres uit dropdown of voer handmatig in
3. Voer forgingadres in (pool of gedelegeerde)
4. Klik "Toewijzing verzenden" (knop ingeschakeld wanneer invoer geldig)
5. Transactie wordt onmiddellijk uitgezonden
6. Toewijzing actief na `nForgingAssignmentDelay` blokken:
   - Mainnet/Testnet: 30 blokken (~1 uur)
   - Regtest: 4 blokken (~4 seconden)

**Transactiekosten**: Standaard 10x `minRelayFee` (aanpasbaar)

**Transactiestructuur**:
- Invoer: UTXO van plotadres (bewijst eigenaarschap)
- OP_RETURN-uitvoer: `POCX`-markering + plot_address + forging_address (46 bytes)
- Wisselgelduitvoer: Terug naar wallet

#### Modus 2: Toewijzing intrekken

**Doel**: Annuleer forging-toewijzing en retourneer rechten naar ploteigenaar.

**Vereisten**:
- Plotadres (moet privesleutel bezitten)
- Wallet ontgrendeld (indien versleuteld)
- Plotadres heeft bevestigde UTXO's

**Stappen**:
1. Selecteer "Toewijzing intrekken"-modus
2. Kies plotadres
3. Klik "Intrekking verzenden"
4. Transactie wordt onmiddellijk uitgezonden
5. Intrekking effectief na `nForgingRevocationDelay` blokken:
   - Mainnet/Testnet: 720 blokken (~24 uur)
   - Regtest: 8 blokken (~8 seconden)

**Effect**:
- Forgingadres kan nog steeds forgen tijdens vertragingsperiode
- Ploteigenaar krijgt rechten terug na voltooide intrekking
- Kan daarna nieuwe toewijzing maken

**Transactiestructuur**:
- Invoer: UTXO van plotadres (bewijst eigenaarschap)
- OP_RETURN-uitvoer: `XCOP`-markering + plot_address (26 bytes)
- Wisselgelduitvoer: Terug naar wallet

#### Modus 3: Toewijzingsstatus controleren

**Doel**: Vraag huidige toewijzingsstatus op voor elk plotadres.

**Vereisten**: Geen (alleen-lezen, geen wallet nodig)

**Stappen**:
1. Selecteer "Toewijzingsstatus controleren"-modus
2. Voer plotadres in
3. Klik "Status controleren"
4. Statusvak toont huidige status met details

**Statusindicatoren** (kleurgecodeerd):

**Grijs - UNASSIGNED**
```
UNASSIGNED - Geen toewijzing bestaat
```

**Oranje - ASSIGNING**
```
ASSIGNING - Toewijzing wacht op activering
Forgingadres: pocx1qforger...
Gecreeerd op hoogte: 12000
Activeert op hoogte: 12030 (5 blokken resterend)
```

**Groen - ASSIGNED**
```
ASSIGNED - Actieve toewijzing
Forgingadres: pocx1qforger...
Gecreeerd op hoogte: 12000
Geactiveerd op hoogte: 12030
```

**Rood-oranje - REVOKING**
```
REVOKING - Intrekking wachtend
Forgingadres: pocx1qforger... (nog actief)
Toewijzing gecreeerd op hoogte: 12000
Ingetrokken op hoogte: 12300
Intrekking effectief op hoogte: 13020 (50 blokken resterend)
```

**Rood - REVOKED**
```
REVOKED - Toewijzing ingetrokken
Eerder toegewezen aan: pocx1qforger...
Toewijzing gecreeerd op hoogte: 12000
Ingetrokken op hoogte: 12300
Intrekking effectief op hoogte: 13020
```

---

## Transactiegeschiedenis

### Toewijzingstransactieweergave

**Type**: "Toewijzing"
**Pictogram**: Miningpictogram (zelfde als geminde blokken)

**Adreskolom**: Plotadres (adres waarvan forgingrechten worden toegewezen)
**Bedragkolom**: Transactiekosten (negatief, uitgaande transactie)
**Statuskolom**: Bevestigingsaantal (0-6+)

**Details** (wanneer aangeklikt):
- Transactie-ID
- Plotadres
- Forgingadres (geparsed uit OP_RETURN)
- Gecreeerd op hoogte
- Activeringshoogte
- Transactiekosten
- Tijdstempel

### Intrekkingstransactieweergave

**Type**: "Intrekking"
**Pictogram**: Miningpictogram

**Adreskolom**: Plotadres
**Bedragkolom**: Transactiekosten (negatief)
**Statuskolom**: Bevestigingsaantal

**Details** (wanneer aangeklikt):
- Transactie-ID
- Plotadres
- Ingetrokken op hoogte
- Intrekking effectieve hoogte
- Transactiekosten
- Tijdstempel

### Transactiefiltering

**Beschikbare filters**:
- "Alle" (standaard, omvat toewijzingen/intrekkingen)
- Datumbereik
- Bedragbereik
- Zoeken op adres
- Zoeken op transactie-ID
- Zoeken op label (indien adres gelabeld)

**Opmerking**: Toewijzings-/intrekkingstransacties verschijnen momenteel onder "Alle"-filter. Toegewijde typefilter nog niet geimplementeerd.

### Transactiesortering

**Sorteervolgorde** (per type):
- Gegenereerd (type 0)
- Ontvangen (type 1-3)
- Toewijzing (type 4)
- Intrekking (type 5)
- Verzonden (type 6+)

---

## Adresvereisten

### Alleen P2WPKH (SegWit v0)

**Forgingoperaties vereisen**:
- Bech32-gecodeerde adressen (beginnend met "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) formaat
- 20-byte sleutelhash

**NIET ondersteund**:
- P2PKH (legacy, beginnend met "1")
- P2SH (wrapped SegWit, beginnend met "3")
- P2TR (Taproot, beginnend met "bc1p")

**Rationale**: PoCX-blokhandtekeningen vereisen specifiek witness v0-formaat voor bewijsvalidatie.

### Adresdropdown-filtering

**Plotadres ComboBox**:
- Automatisch gevuld met ontvangstadressen van wallet
- Filtert niet-P2WPKH-adressen eruit
- Toont formaat: "Label (adres)" indien gelabeld, anders alleen adres
- Eerste item: "-- Voer aangepast adres in --" voor handmatige invoer

**Handmatige invoer**:
- Valideert formaat wanneer ingevoerd
- Moet geldige bech32 P2WPKH zijn
- Knop uitgeschakeld bij ongeldig formaat

### Validatiefoutmeldingen

**Dialoogfouten**:
- "Plotadres moet P2WPKH (bech32) zijn"
- "Forgingadres moet P2WPKH (bech32) zijn"
- "Ongeldig adresformaat"
- "Geen munten beschikbaar op het plotadres. Kan eigenaarschap niet bewijzen."
- "Kan geen transacties creeren met alleen-lezen wallet"
- "Wallet niet beschikbaar"
- "Wallet vergrendeld" (van RPC)

---

## Mining-integratie

### Setupvereisten

**Node-configuratie**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Walletvereisten**:
- P2WPKH-adressen voor ploteigenaarschap
- Privesleutels voor mining (of forgingadres bij gebruik van toewijzingen)
- Bevestigde UTXO's voor transactiecreatie

**Externe tools**:
- `pocx_plotter`: Genereer plotbestanden
- `pocx_miner`: Scan plots en dien nonces in

### Workflow

#### Solo-mining

1. **Genereer plotbestanden**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <aantal>
   ```

2. **Start node** met miningserver:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configureer miner**:
   - Wijs naar node RPC-eindpunt
   - Specificeer plotbestandsmappen
   - Configureer account-ID (van plotadres)

4. **Start mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /pad/naar/plots
   ```

5. **Monitor**:
   - Miner roept `get_mining_info` aan elk blok
   - Scant plots voor beste deadline
   - Roept `submit_nonce` aan wanneer oplossing gevonden
   - Node valideert en forgt blok automatisch

#### Pool-mining

1. **Genereer plotbestanden** (zelfde als solo-mining)

2. **Creeer forging-toewijzing**:
   - Open forging-toewijzingsdialoog
   - Selecteer plotadres
   - Voer forgingadres van pool in
   - Klik "Toewijzing verzenden"
   - Wacht op activeringsvertraging (30 blokken testnet)

3. **Configureer miner**:
   - Wijs naar **pool**-eindpunt (niet lokale node)
   - Pool handelt `submit_nonce` naar keten af

4. **Pool-operatie**:
   - Pool-wallet heeft forgingadres privesleutels
   - Pool valideert indieningen van miners
   - Pool roept `submit_nonce` aan naar blockchain
   - Pool distribueert beloningen per poolbeleid

### Coinbase-beloningen

**Geen toewijzing**:
- Coinbase betaalt ploteigenaaradres direct
- Controleer saldo in plotadres

**Met toewijzing**:
- Coinbase betaalt forgingadres
- Pool ontvangt beloningen
- Miner ontvangt aandeel van pool

**Beloningsschema**:
- Initieel: 10 BTCX per blok
- Halvering: Elke 1050000 blokken (~4 jaar)
- Schema: 10 -> 5 -> 2,5 -> 1,25 -> ...

---

## Probleemoplossing

### Veelvoorkomende problemen

#### "Wallet heeft geen privesleutel voor plotadres"

**Oorzaak**: Wallet bezit het adres niet
**Oplossing**:
- Importeer privesleutel via `importprivkey` RPC
- Of gebruik ander plotadres dat wallet bezit

#### "Toewijzing bestaat al voor dit plot"

**Oorzaak**: Plot al toegewezen aan ander adres
**Oplossing**:
1. Trek bestaande toewijzing in
2. Wacht op intrekkingsvertraging (720 blokken testnet)
3. Creeer nieuwe toewijzing

#### "Adresformaat niet ondersteund"

**Oorzaak**: Adres is niet P2WPKH bech32
**Oplossing**:
- Gebruik adressen beginnend met "pocx1q" (mainnet) of "tpocx1q" (testnet)
- Genereer nieuw adres indien nodig: `getnewaddress "" "bech32"`

#### "Transactiekosten te laag"

**Oorzaak**: Netwerkmempool-congestie of kosten te laag voor relay
**Oplossing**:
- Verhoog fee rate-parameter
- Wacht op mempool-clearing

#### "Toewijzing nog niet actief"

**Oorzaak**: Activeringsvertraging nog niet verstreken
**Oplossing**:
- Controleer status: blokken resterend tot activering
- Wacht tot vertragingsperiode voltooid is

#### "Geen munten beschikbaar op het plotadres"

**Oorzaak**: Plotadres heeft geen bevestigde UTXO's
**Oplossing**:
1. Stuur fondsen naar plotadres
2. Wacht op 1 bevestiging
3. Probeer toewijzingscreatie opnieuw

#### "Kan geen transacties creeren met alleen-lezen wallet"

**Oorzaak**: Wallet importeerde adres zonder privesleutel
**Oplossing**: Importeer volledige privesleutel, niet alleen adres

#### "Forging-toewijzingstab niet zichtbaar"

**Oorzaak**: Node gestart zonder `-miningserver`-vlag
**Oplossing**: Herstart met `bitcoin-qt -server -miningserver`

### Debug-stappen

1. **Controleer walletstatus**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verifieer adreseigenaarschap**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Controleer: "iswatchonly": false, "ismine": true
   ```

3. **Controleer toewijzingsstatus**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Bekijk recente transacties**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Controleer node-synchronisatie**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifieer: blocks == headers (volledig gesynchroniseerd)
   ```

---

## Beveiligings-best practices

### Plotadresbeveiliging

**Sleutelbeheer**:
- Sla plotadres privesleutels veilig op
- Toewijzingstransacties bewijzen eigenaarschap via handtekening
- Alleen ploteigenaar kan toewijzingen creeren/intrekken

**Back-up**:
- Maak regelmatig back-up van wallet (`dumpwallet` of `backupwallet`)
- Sla wallet.dat op op veilige locatie
- Noteer herstelzinnen bij gebruik van HD-wallet

### Forgingadresdelegatie

**Beveiligingsmodel**:
- Forgingadres ontvangt blokbeloningen
- Forgingadres kan blokken ondertekenen (mining)
- Forgingadres **kan** toewijzing **niet** wijzigen of intrekken
- Ploteigenaar behoudt volledige controle

**Gebruiksscenario's**:
- **Hot wallet-delegatie**: Plotsleutel in cold storage, forgingsleutel in hot wallet voor mining
- **Pool-mining**: Delegeer aan pool, behoud ploteigenaarschap
- **Gedeelde infrastructuur**: Meerdere miners, een forgingadres

### Netwerktijdsynchronisatie

**Belang**:
- PoCX-consensus vereist nauwkeurige tijd
- Klokverschuiving >10s triggert waarschuwing
- Klokverschuiving >15s voorkomt mining

**Oplossing**:
- Houd systeemklok gesynchroniseerd met NTP
- Monitor: `bitcoin-cli getnetworkinfo` voor tijdsverschuivingswaarschuwingen
- Gebruik betrouwbare NTP-servers

### Toewijzingsvertragingen

**Activeringsvertraging** (30 blokken testnet):
- Voorkomt snelle hertoewijzing tijdens ketenvorken
- Staat netwerk toe consensus te bereiken
- Kan niet worden omzeild

**Intrekkingsvertraging** (720 blokken testnet):
- Biedt stabiliteit voor miningpools
- Voorkomt toewijzings-"griefing"-aanvallen
- Forgingadres blijft actief tijdens vertraging

### Walletversleuteling

**Versleuteling inschakelen**:
```bash
bitcoin-cli encryptwallet "uw_wachtwoordzin"
```

**Ontgrendelen voor transacties**:
```bash
bitcoin-cli walletpassphrase "uw_wachtwoordzin" 300
```

**Best practices**:
- Gebruik sterke wachtwoordzin (20+ tekens)
- Sla wachtwoordzin niet op in platte tekst
- Vergrendel wallet na creeren van toewijzingen

---

## Codereferenties

**Forging-toewijzingsdialoog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transactieweergave**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transactieparsing**: `src/qt/transactionrecord.cpp`
**Wallet-integratie**: `src/pocx/assignments/transactions.cpp`
**Toewijzings-RPC's**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI-main**: `src/qt/bitcoingui.cpp`

---

## Kruisverwijzingen

Gerelateerde hoofdstukken:
- [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md) - Miningproces
- [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md) - Toewijzingsarchitectuur
- [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md) - Toewijzingsvertragingswaarden
- [Hoofdstuk 7: RPC-referentie](7-rpc-reference.md) - RPC-opdrachtdetails

---

[Vorige: RPC-referentie](7-rpc-reference.md) | [Inhoudsopgave](index.md)

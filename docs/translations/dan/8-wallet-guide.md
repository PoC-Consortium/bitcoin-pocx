[<- Forrige: RPC-reference](7-rpc-reference.md) | [Indholdsfortegnelse](index.md)

---

# Kapitel 8: Wallet- og GUI-brugervejledning

Komplet vejledning til Bitcoin-PoCX Qt-wallet og forging assignment-styring.

---

## Indholdsfortegnelse

1. [Oversigt](#oversigt)
2. [Valutaenheder](#valutaenheder)
3. [Forging Assignment-dialog](#forging-assignment-dialog)
4. [Transaktionshistorik](#transaktionshistorik)
5. [Adressekrav](#adressekrav)
6. [Miningintegration](#miningintegration)
7. [Fejlfinding](#fejlfinding)
8. [Bedste sikkerhedspraksis](#bedste-sikkerhedspraksis)

---

## Oversigt

### Bitcoin-PoCX Wallet-funktioner

Bitcoin-PoCX Qt-wallet (`bitcoin-qt`) giver:
- Standard Bitcoin Core wallet-funktionalitet (send, modtag, transaktionsstyring)
- **Forging Assignment Manager**: GUI til oprettelse/tilbagekaldelse af plotassignments
- **Miningservertilstand**: `-miningserver`-flag aktiverer miningrelaterede funktioner
- **Transaktionshistorik**: Visning af assignment- og tilbagekaldelsestransaktioner

### Start af wallet

**Kun node** (ingen mining):
```bash
./build/bin/bitcoin-qt
```

**Med mining** (aktiverer assignment-dialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Kommandolinjealternativ**:
```bash
./build/bin/bitcoind -miningserver
```

### Miningkrav

**Til miningoperationer**:
- `-miningserver`-flag kraevet
- Wallet med P2WPKH-adresser og private nogler
- Ekstern plotter (`pocx_plotter`) til plotgenerering
- Ekstern miner (`pocx_miner`) til mining

**Til pool-mining**:
- Opret forging assignment til pooladresse
- Wallet ikke kraevet pa pool-server (pool styrer nogler)

---

## Valutaenheder

### Enhedsvisning

Bitcoin-PoCX bruger **BTCX**-valutaenhed (ikke BTC):

| Enhed | Satoshis | Visning |
|-------|----------|---------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **uBTCX** | 100 | 1000000,00 uBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI-indstillinger**: Praeferencer -> Visning -> Enhed

---

## Forging Assignment-dialog

### Adgang til dialogen

**Menu**: `Wallet -> Forging Assignments`
**Vaerktoejslinje**: Miningikon (kun synligt med `-miningserver`-flag)
**Vinduesstorrelse**: 600x450 pixels

### Dialogtilstande

#### Tilstand 1: Opret assignment

**Formal**: Deleger forging-rettigheder til pool eller anden adresse, mens plotejerskab bevares.

**Anvendelsestilfaelde**:
- Pool-mining (tildel til pooladresse)
- Cold storage (miningnogle adskilt fra plotejerskab)
- Delt infrastruktur (deleger til hot wallet)

**Krav**:
- Plotadresse (P2WPKH bech32, skal eje privat nogle)
- Forging-adresse (P2WPKH bech32, forskellig fra plotadresse)
- Wallet oplast (hvis krypteret)
- Plotadresse har bekraeftede UTXO'er

**Trin**:
1. Vaelg tilstanden "Opret assignment"
2. Vaelg plotadresse fra dropdown eller indtast manuelt
3. Indtast forging-adresse (pool eller delegeret)
4. Klik "Send assignment" (knap aktiveret, nar inputs er gyldige)
5. Transaktion udsendes ojeblikkelig
6. Assignment aktiv efter `nForgingAssignmentDelay` blokke:
   - Mainnet/Testnet: 30 blokke (~1 time)
   - Regtest: 4 blokke (~4 sekunder)

**Transaktionsgebyr**: Standard 10x `minRelayFee` (kan tilpasses)

**Transaktionsstruktur**:
- Input: UTXO fra plotadresse (beviser ejerskab)
- OP_RETURN-output: `POCX`-markor + plot_address + forging_address (46 bytes)
- Byttepenge-output: Returneret til wallet

#### Tilstand 2: Tilbagekald assignment

**Formal**: Annuller forging assignment og returner rettigheder til plotejer.

**Krav**:
- Plotadresse (skal eje privat nogle)
- Wallet oplast (hvis krypteret)
- Plotadresse har bekraeftede UTXO'er

**Trin**:
1. Vaelg tilstanden "Tilbagekald assignment"
2. Vaelg plotadresse
3. Klik "Send tilbagekaldelse"
4. Transaktion udsendes ojeblikkelig
5. Tilbagekaldelse traeder i kraft efter `nForgingRevocationDelay` blokke:
   - Mainnet/Testnet: 720 blokke (~24 timer)
   - Regtest: 8 blokke (~8 sekunder)

**Effekt**:
- Forging-adresse kan stadig forge i forsinkelsesperiode
- Plotejer genvinder rettigheder, efter tilbagekaldelse er faerdig
- Kan oprette ny assignment bagefter

**Transaktionsstruktur**:
- Input: UTXO fra plotadresse (beviser ejerskab)
- OP_RETURN-output: `XCOP`-markor + plot_address (26 bytes)
- Byttepenge-output: Returneret til wallet

#### Tilstand 3: Kontroller assignment-status

**Formal**: Forespoerg nuvaerende assignment-tilstand for enhver plotadresse.

**Krav**: Ingen (skrivebeskyttet, ingen wallet nodvendig)

**Trin**:
1. Vaelg tilstanden "Kontroller assignment-status"
2. Indtast plotadresse
3. Klik "Kontroller status"
4. Statusboks viser nuvaerende tilstand med detaljer

**Tilstandsindikatorer** (farvekodede):

**Gra - UNASSIGNED**
```
UNASSIGNED - Ingen assignment eksisterer
```

**Orange - ASSIGNING**
```
ASSIGNING - Assignment afventer aktivering
Forging-adresse: pocx1qforger...
Oprettet ved hojde: 12000
Aktiveres ved hojde: 12030 (5 blokke tilbage)
```

**Gron - ASSIGNED**
```
ASSIGNED - Aktiv assignment
Forging-adresse: pocx1qforger...
Oprettet ved hojde: 12000
Aktiveret ved hojde: 12030
```

**Rodorange - REVOKING**
```
REVOKING - Tilbagekaldelse afventer
Forging-adresse: pocx1qforger... (stadig aktiv)
Assignment oprettet ved hojde: 12000
Tilbagekaldt ved hojde: 12300
Tilbagekaldelse traeder i kraft ved hojde: 13020 (50 blokke tilbage)
```

**Rod - REVOKED**
```
REVOKED - Assignment tilbagekaldt
Tidligere tildelt til: pocx1qforger...
Assignment oprettet ved hojde: 12000
Tilbagekaldt ved hojde: 12300
Tilbagekaldelse tradte i kraft ved hojde: 13020
```

---

## Transaktionshistorik

### Assignment-transaktionsvisning

**Type**: "Assignment"
**Ikon**: Miningikon (samme som minede blokke)

**Adressekolonne**: Plotadresse (adresse, hvis forging-rettigheder tildeles)
**Belobskolonne**: Transaktionsgebyr (negativt, udgaende transaktion)
**Statuskolonne**: Bekraeftelsestal (0-6+)

**Detaljer** (nar der klikkes):
- Transaktions-ID
- Plotadresse
- Forging-adresse (parset fra OP_RETURN)
- Oprettet ved hojde
- Aktiveringshojde
- Transaktionsgebyr
- Tidsstempel

### Tilbagekaldelsestransaktionsvisning

**Type**: "Tilbagekaldelse"
**Ikon**: Miningikon

**Adressekolonne**: Plotadresse
**Belobskolonne**: Transaktionsgebyr (negativt)
**Statuskolonne**: Bekraeftelsestal

**Detaljer** (nar der klikkes):
- Transaktions-ID
- Plotadresse
- Tilbagekaldt ved hojde
- Tilbagekaldelse traeder i kraft ved hojde
- Transaktionsgebyr
- Tidsstempel

### Transaktionsfiltrering

**Tilgaengelige filtre**:
- "Alle" (standard, inkluderer assignments/tilbagekaldelser)
- Datointerval
- Belobsinterval
- Sog efter adresse
- Sog efter transaktions-ID
- Sog efter etiket (hvis adresse er maerket)

**Bemaaerkning**: Assignment-/tilbagekaldelsestransaktioner vises i oejeblikket under "Alle"-filter. Dedikeret typefilter er endnu ikke implementeret.

### Transaktionssortering

**Sorteringsraekkefolge** (efter type):
- Genereret (type 0)
- Modtaget (type 1-3)
- Assignment (type 4)
- Tilbagekaldelse (type 5)
- Sendt (type 6+)

---

## Adressekrav

### Kun P2WPKH (SegWit v0)

**Forging-operationer kraever**:
- Bech32-kodede adresser (starter med "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) format
- 20-byte noglehash

**IKKE understottet**:
- P2PKH (legacy, starter med "1")
- P2SH (wrapped SegWit, starter med "3")
- P2TR (Taproot, starter med "bc1p")

**Rationale**: PoCX-bloksignaturer kraever specifikt witness v0-format til bevisvalidering.

### Adressedropdown-filtrering

**Plotadresse-combobox**:
- Automatisk udfyldt med wallets modtageadresser
- Filtrerer ikke-P2WPKH-adresser fra
- Viser format: "Etiket (adresse)" hvis maerket, ellers bare adresse
- Forste element: "-- Indtast brugerdefineret adresse --" til manuel indtastning

**Manuel indtastning**:
- Validerer format, nar det indtastes
- Skal vaere gyldig bech32 P2WPKH
- Knap deaktiveret, hvis format er ugyldigt

### Valideringsfejlmeddelelser

**Dialogfejl**:
- "Plotadresse skal vaere P2WPKH (bech32)"
- "Forging-adresse skal vaere P2WPKH (bech32)"
- "Ugyldigt adresseformat"
- "Ingen midler tilgaengelige pa plotadressen. Kan ikke bevise ejerskab."
- "Kan ikke oprette transaktioner med watch-only wallet"
- "Wallet ikke tilgaengelig"
- "Wallet last" (fra RPC)

---

## Miningintegration

### Opsaetningskrav

**Node-konfiguration**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Wallet-krav**:
- P2WPKH-adresser til plotejerskab
- Private nogler til mining (eller forging-adresse, hvis der bruges assignments)
- Bekraeftede UTXO'er til transaktionsoprettelse

**Eksterne vaerktojer**:
- `pocx_plotter`: Generer plotfiler
- `pocx_miner`: Scan plots og indsend nonces

### Workflow

#### Solo-mining

1. **Generer plotfiler**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <antal>
   ```

2. **Start node** med miningserver:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigurer miner**:
   - Peg mod node RPC-endpoint
   - Angiv plotfilmapper
   - Konfigurer konto-ID (fra plotadresse)

4. **Start mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /sti/til/plots
   ```

5. **Overvaeg**:
   - Miner kalder `get_mining_info` hver blok
   - Scanner plots for bedste deadline
   - Kalder `submit_nonce`, nar losning findes
   - Node validerer og forger blok automatisk

#### Pool-mining

1. **Generer plotfiler** (samme som solo-mining)

2. **Opret forging assignment**:
   - Abn Forging Assignment-dialog
   - Vaelg plotadresse
   - Indtast pools forging-adresse
   - Klik "Send assignment"
   - Vent pa aktiveringsforsinkelse (30 blokke testnet)

3. **Konfigurer miner**:
   - Peg mod **pool**-endpoint (ikke lokal node)
   - Pool handterer `submit_nonce` til kaeden

4. **Pool-drift**:
   - Pool-wallet har forging-adresse private nogler
   - Pool validerer indsendelser fra minere
   - Pool kalder `submit_nonce` til blockchain
   - Pool distribuerer beloninger ifolge poolpolitik

### Coinbase-beloninger

**Ingen assignment**:
- Coinbase betaler plotejeradresse direkte
- Kontroller saldo i plotadresse

**Med assignment**:
- Coinbase betaler forging-adresse
- Pool modtager beloninger
- Miner modtager andel fra pool

**Belonningsplan**:
- Indledende: 10 BTCX pr. blok
- Halvering: Hver 1050000 blok (~4 ar)
- Plan: 10 -> 5 -> 2,5 -> 1,25 -> ...

---

## Fejlfinding

### Almindelige problemer

#### "Wallet har ikke privat nogle til plotadresse"

**Arsag**: Wallet ejer ikke adressen
**Losning**:
- Importer privat nogle via `importprivkey` RPC
- Eller brug anden plotadresse ejet af wallet

#### "Assignment eksisterer allerede for dette plot"

**Arsag**: Plot allerede tildelt til anden adresse
**Losning**:
1. Tilbagekald eksisterende assignment
2. Vent pa tilbagekaldelsesforsinkelse (720 blokke testnet)
3. Opret ny assignment

#### "Adresseformat ikke understottet"

**Arsag**: Adresse ikke P2WPKH bech32
**Losning**:
- Brug adresser, der starter med "pocx1q" (mainnet) eller "tpocx1q" (testnet)
- Generer ny adresse, hvis nodvendigt: `getnewaddress "" "bech32"`

#### "Transaktionsgebyr for lavt"

**Arsag**: Netvaerksmempool-overbelastning eller gebyr for lavt til relay
**Losning**:
- Forg gebyrsatsparameter
- Vent pa mempool-rydning

#### "Assignment endnu ikke aktiv"

**Arsag**: Aktiveringsforsinkelse ikke udlobet endnu
**Losning**:
- Kontroller status: blokke tilbage til aktivering
- Vent pa, at forsinkelsesperiode faerdigudfres

#### "Ingen midler tilgaengelige pa plotadressen"

**Arsag**: Plotadresse har ingen bekraeftede UTXO'er
**Losning**:
1. Send midler til plotadresse
2. Vent pa 1 bekraeftelse
3. Forsog assignment-oprettelse igen

#### "Kan ikke oprette transaktioner med watch-only wallet"

**Arsag**: Wallet importerede adresse uden privat nogle
**Losning**: Importer fuld privat nogle, ikke kun adresse

#### "Forging Assignment-fane ikke synlig"

**Arsag**: Node startet uden `-miningserver`-flag
**Losning**: Genstart med `bitcoin-qt -server -miningserver`

### Fejlfindingstrin

1. **Kontroller wallet-status**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Bekraeft adresseejerskab**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Kontroller: "iswatchonly": false, "ismine": true
   ```

3. **Kontroller assignment-status**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Se nylige transaktioner**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Kontroller nodesynkronisering**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Bekraeft: blocks == headers (fuldt synkroniseret)
   ```

---

## Bedste sikkerhedspraksis

### Plotadressesikkerhed

**Noglestyring**:
- Opbevar plotadresse private nogler sikkert
- Assignment-transaktioner beviser ejerskab via signatur
- Kun plotejer kan oprette/tilbagekalde assignments

**Backup**:
- Tag regelmaessigt backup af wallet (`dumpwallet` eller `backupwallet`)
- Opbevar wallet.dat pa sikker placering
- Registrer genoprettelsesfraser, hvis der bruges HD-wallet

### Forging-adressedelegering

**Sikkerhedsmodel**:
- Forging-adresse modtager blokbeloninger
- Forging-adresse kan signere blokke (mining)
- Forging-adresse **kan ikke** modificere eller tilbagekalde assignment
- Plotejer bevarer fuld kontrol

**Anvendelsestilfaelde**:
- **Hot wallet-delegering**: Plotnogle i cold storage, forging-nogle i hot wallet til mining
- **Pool-mining**: Deleger til pool, bevar plotejerskab
- **Delt infrastruktur**: Flere minere, en forging-adresse

### Netvaerkstidssynkronisering

**Vigtighed**:
- PoCX-konsensus kraever nojagtig tid
- Urdrift >10s udloser advarsel
- Urdrift >15s forebygger mining

**Losning**:
- Hold systemur synkroniseret med NTP
- Overvaeg: `bitcoin-cli getnetworkinfo` for tidsforskydningsadvarsler
- Brug palidelige NTP-servere

### Assignment-forsinkelser

**Aktiveringsforsinkelse** (30 blokke testnet):
- Forebygger hurtig omtildeling under kaedegafler
- Tillader netvaerk at na konsensus
- Kan ikke omgas

**Tilbagekaldelsesforsinkelse** (720 blokke testnet):
- Giver stabilitet til miningpools
- Forebygger assignment-"griefing"-angreb
- Forging-adresse forbliver aktiv i forsinkelsen

### Wallet-kryptering

**Aktiver kryptering**:
```bash
bitcoin-cli encryptwallet "din_adgangsfrase"
```

**Oplas til transaktioner**:
```bash
bitcoin-cli walletpassphrase "din_adgangsfrase" 300
```

**Bedste praksis**:
- Brug staerk adgangsfrase (20+ tegn)
- Gem ikke adgangsfrase i klartekst
- Las wallet efter oprettelse af assignments

---

## Kodereferencer

**Forging Assignment-dialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaktionsvisning**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaktionsparsning**: `src/qt/transactionrecord.cpp`
**Wallet-integration**: `src/pocx/assignments/transactions.cpp`
**Assignment-RPC'er**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Main**: `src/qt/bitcoingui.cpp`

---

## Krydsreferencer

Relaterede kapitler:
- [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md) - Miningproces
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Assignment-arkitektur
- [Kapitel 6: Netvaerksparametre](6-network-parameters.md) - Assignment-forsinkelsesvaerdier
- [Kapitel 7: RPC-reference](7-rpc-reference.md) - RPC-kommandodetaljer

---

[<- Forrige: RPC-reference](7-rpc-reference.md) | [Indholdsfortegnelse](index.md)

[<- Föregående: RPC-referens](7-rpc-reference.md) | [Innehållsförteckning](index.md)

---

# Kapitel 8: Plånboks- och GUI-användarguide

Fullständig guide till Bitcoin-PoCX Qt-plånboken och forging assignment-hantering.

---

## Innehållsförteckning

1. [Översikt](#översikt)
2. [Valutaenheter](#valutaenheter)
3. [Dialogrutan för forging assignment](#dialogrutan-för-forging-assignment)
4. [Transaktionshistorik](#transaktionshistorik)
5. [Adresskrav](#adresskrav)
6. [Miningintegration](#miningintegration)
7. [Felsökning](#felsökning)
8. [Säkerhetspraxis](#säkerhetspraxis)

---

## Översikt

### Bitcoin-PoCX-plånboksfunktioner

Bitcoin-PoCX Qt-plånboken (`bitcoin-qt`) tillhandahåller:
- Standard Bitcoin Core-plånboksfunktionalitet (skicka, ta emot, transaktionshantering)
- **Forging Assignment Manager**: GUI för att skapa/återkalla plottilldelningar
- **Miningserverläge**: `-miningserver`-flagga aktiverar miningrelaterade funktioner
- **Transaktionshistorik**: Visning av tilldelnings- och återkallelsetransaktioner

### Starta plånboken

**Endast nod** (ingen mining):
```bash
./build/bin/bitcoin-qt
```

**Med mining** (aktiverar tilldelningsdialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Kommandoradsalternativ**:
```bash
./build/bin/bitcoind -miningserver
```

### Miningkrav

**För miningoperationer**:
- `-miningserver`-flagga krävs
- Plånbok med P2WPKH-adresser och privata nycklar
- Extern plotter (`pocx_plotter`) för plotgenerering
- Extern miner (`pocx_miner`) för mining

**För poolmining**:
- Skapa forgingstilldelning till pooladress
- Plånbok krävs inte på poolserver (pool hanterar nycklar)

---

## Valutaenheter

### Enhetsvisning

Bitcoin-PoCX använder valutaenheten **BTCX** (inte BTC):

| Enhet | Satoshis | Visning |
|-------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI-inställningar**: Inställningar -> Visning -> Enhet

---

## Dialogrutan för forging assignment

### Åtkomst till dialogen

**Meny**: `Plånbok -> Forging Assignments`
**Verktygsfält**: Miningikon (synlig endast med `-miningserver`-flagga)
**Fönsterstorlek**: 600×450 pixlar

### Dialoglägen

#### Läge 1: Skapa tilldelning

**Syfte**: Delegera forgingsrättigheter till pool eller annan adress samtidigt som plotägarskap behålls.

**Användningsfall**:
- Poolmining (tilldela till pooladress)
- Kall lagring (miningnyckel separat från plotägarskap)
- Delad infrastruktur (delegera till varm plånbok)

**Krav**:
- Plotadress (P2WPKH bech32, måste äga privat nyckel)
- Forgingsadress (P2WPKH bech32, annorlunda än plotadress)
- Plånbok upplåst (om krypterad)
- Plotadress har bekräftade UTXO:er

**Steg**:
1. Välj läget "Skapa tilldelning"
2. Välj plotadress från rullgardinsmeny eller ange manuellt
3. Ange forgingsadress (pool eller delegat)
4. Klicka "Skicka tilldelning" (knapp aktiveras när indata är giltig)
5. Transaktion sänds omedelbart
6. Tilldelning aktiv efter `nForgingAssignmentDelay` block:
   - Mainnet/Testnet: 30 block (~1 timme)
   - Regtest: 4 block (~4 sekunder)

**Transaktionsavgift**: Standard 10× `minRelayFee` (anpassningsbar)

**Transaktionsstruktur**:
- Input: UTXO från plotadress (bevisar ägarskap)
- OP_RETURN-utdata: `POCX`-markör + plot_address + forging_address (46 bytes)
- Växelutdata: Returneras till plånbok

#### Läge 2: Återkalla tilldelning

**Syfte**: Avbryt forgingstilldelning och returnera rättigheter till plotägare.

**Krav**:
- Plotadress (måste äga privat nyckel)
- Plånbok upplåst (om krypterad)
- Plotadress har bekräftade UTXO:er

**Steg**:
1. Välj läget "Återkalla tilldelning"
2. Välj plotadress
3. Klicka "Skicka återkallelse"
4. Transaktion sänds omedelbart
5. Återkallelse effektiv efter `nForgingRevocationDelay` block:
   - Mainnet/Testnet: 720 block (~24 timmar)
   - Regtest: 8 block (~8 sekunder)

**Effekt**:
- Forgingsadress kan fortfarande forga under fördröjningsperiod
- Plotägare återfår rättigheter efter slutförd återkallelse
- Kan skapa ny tilldelning efteråt

**Transaktionsstruktur**:
- Input: UTXO från plotadress (bevisar ägarskap)
- OP_RETURN-utdata: `XCOP`-markör + plot_address (26 bytes)
- Växelutdata: Returneras till plånbok

#### Läge 3: Kontrollera tilldelningsstatus

**Syfte**: Fråga aktuell tilldelningsstatus för vilken plotadress som helst.

**Krav**: Inga (skrivskyddad, ingen plånbok behövs)

**Steg**:
1. Välj läget "Kontrollera tilldelningsstatus"
2. Ange plotadress
3. Klicka "Kontrollera status"
4. Statusrutan visar aktuellt tillstånd med detaljer

**Statusindikatorer** (färgkodade):

**Grå - UNASSIGNED (Otilldelad)**
```
UNASSIGNED - Ingen tilldelning existerar
```

**Orange - ASSIGNING (Tilldelas)**
```
ASSIGNING - Tilldelning väntar på aktivering
Forgingsadress: pocx1qforger...
Skapad vid höjd: 12000
Aktiveras vid höjd: 12030 (5 block kvar)
```

**Grön - ASSIGNED (Tilldelad)**
```
ASSIGNED - Aktiv tilldelning
Forgingsadress: pocx1qforger...
Skapad vid höjd: 12000
Aktiverad vid höjd: 12030
```

**Rödorange - REVOKING (Återkallar)**
```
REVOKING - Återkallelse väntar
Forgingsadress: pocx1qforger... (fortfarande aktiv)
Tilldelning skapad vid höjd: 12000
Återkallad vid höjd: 12300
Återkallelse effektiv vid höjd: 13020 (50 block kvar)
```

**Röd - REVOKED (Återkallad)**
```
REVOKED - Tilldelning återkallad
Tidigare tilldelad till: pocx1qforger...
Tilldelning skapad vid höjd: 12000
Återkallad vid höjd: 12300
Återkallelse effektiv vid höjd: 13020
```

---

## Transaktionshistorik

### Visning av tilldelningsstransaktioner

**Typ**: "Tilldelning"
**Ikon**: Miningikon (samma som minade block)

**Adresskolumn**: Plotadress (adress vars forgingsrättigheter tilldelas)
**Beloppskolumn**: Transaktionsavgift (negativ, utgående transaktion)
**Statuskolumn**: Bekräftelseräkning (0-6+)

**Detaljer** (vid klick):
- Transaktions-ID
- Plotadress
- Forgingsadress (tolkad från OP_RETURN)
- Skapad vid höjd
- Aktiveringshöjd
- Transaktionsavgift
- Tidsstämpel

### Visning av återkallelsetransaktioner

**Typ**: "Återkallelse"
**Ikon**: Miningikon

**Adresskolumn**: Plotadress
**Beloppskolumn**: Transaktionsavgift (negativ)
**Statuskolumn**: Bekräftelseräkning

**Detaljer** (vid klick):
- Transaktions-ID
- Plotadress
- Återkallad vid höjd
- Återkallelseeffektiv höjd
- Transaktionsavgift
- Tidsstämpel

### Transaktionsfiltrering

**Tillgängliga filter**:
- "Alla" (standard, inkluderar tilldelningar/återkallelser)
- Datumintervall
- Beloppsintervall
- Sök efter adress
- Sök efter transaktions-ID
- Sök efter etikett (om adress etiketterad)

**Notera**: Tilldelnings-/återkallelsetransaktioner visas för närvarande under "Alla"-filter. Dedikerat typfilter inte ännu implementerat.

### Transaktionssortering

**Sorteringsordning** (efter typ):
- Genererad (typ 0)
- Mottagen (typ 1-3)
- Tilldelning (typ 4)
- Återkallelse (typ 5)
- Skickad (typ 6+)

---

## Adresskrav

### Endast P2WPKH (SegWit v0)

**Forgingsoperationer kräver**:
- Bech32-kodade adresser (börjar med "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash)-format
- 20-byte nyckelhash

**STÖDS INTE**:
- P2PKH (legacy, börjar med "1")
- P2SH (wrapped SegWit, börjar med "3")
- P2TR (Taproot, börjar med "bc1p")

**Motivering**: PoCX-blocksignaturer kräver specifikt witness v0-format för bevisvalidering.

### Adressrullgardinsfiltrering

**Plotadress-ComboBox**:
- Fylls automatiskt med plånbokens mottagningsadresser
- Filtrerar bort icke-P2WPKH-adresser
- Visar format: "Etikett (adress)" om etiketterad, annars bara adress
- Första objektet: "-- Ange anpassad adress --" för manuell inmatning

**Manuell inmatning**:
- Validerar format vid inmatning
- Måste vara giltig bech32 P2WPKH
- Knapp inaktiverad om ogiltigt format

### Valideringsfelmeddelanden

**Dialogfel**:
- "Plotadress måste vara P2WPKH (bech32)"
- "Forgingsadress måste vara P2WPKH (bech32)"
- "Ogiltigt adressformat"
- "Inga coins tillgängliga på plotadressen. Kan inte bevisa ägarskap."
- "Kan inte skapa transaktioner med watch-only-plånbok"
- "Plånbok inte tillgänglig"
- "Plånbok låst" (från RPC)

---

## Miningintegration

### Konfigurationskrav

**Nodkonfiguration**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Plånbokskrav**:
- P2WPKH-adresser för plotägarskap
- Privata nycklar för mining (eller forgingsadress om tilldelningar används)
- Bekräftade UTXO:er för transaktionsskapande

**Externa verktyg**:
- `pocx_plotter`: Generera plotfiler
- `pocx_miner`: Skanna plottar och skicka nonces

### Arbetsflöde

#### Solomining

1. **Generera plotfiler**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <antal>
   ```

2. **Starta nod** med miningserver:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigurera miner**:
   - Peka på nodens RPC-endpoint
   - Ange plotfilkataloger
   - Konfigurera konto-ID (från plotadress)

4. **Starta mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /sökväg/till/plottar
   ```

5. **Övervaka**:
   - Miner anropar `get_mining_info` varje block
   - Skannar plottar för bästa deadline
   - Anropar `submit_nonce` när lösning hittas
   - Nod validerar och forgar block automatiskt

#### Poolmining

1. **Generera plotfiler** (samma som solomining)

2. **Skapa forgingstilldelning**:
   - Öppna Forging Assignment-dialog
   - Välj plotadress
   - Ange poolens forgingsadress
   - Klicka "Skicka tilldelning"
   - Vänta på aktiveringsfördröjning (30 block testnet)

3. **Konfigurera miner**:
   - Peka på **pool**-endpoint (inte lokal nod)
   - Pool hanterar `submit_nonce` till kedja

4. **Pooldrift**:
   - Poolplånbok har forgingsadressens privata nycklar
   - Pool validerar inlämningar från miners
   - Pool anropar `submit_nonce` till blockchain
   - Pool distribuerar belöningar enligt poolpolicy

### Coinbase-belöningar

**Ingen tilldelning**:
- Coinbase betalar plotägaradress direkt
- Kontrollera saldo på plotadress

**Med tilldelning**:
- Coinbase betalar forgingsadress
- Pool tar emot belöningar
- Miner tar emot andel från pool

**Belöningsschema**:
- Initial: 10 BTCX per block
- Halvering: Var 1050000:e block (~4 år)
- Schema: 10 -> 5 -> 2.5 -> 1.25 -> ...

---

## Felsökning

### Vanliga problem

#### "Plånbok har inte privat nyckel för plotadress"

**Orsak**: Plånbok äger inte adressen
**Lösning**:
- Importera privat nyckel via `importprivkey` RPC
- Eller använd annan plotadress som plånboken äger

#### "Tilldelning existerar redan för denna plot"

**Orsak**: Plot redan tilldelad till annan adress
**Lösning**:
1. Återkalla befintlig tilldelning
2. Vänta på återkallelsefördröjning (720 block testnet)
3. Skapa ny tilldelning

#### "Adressformat stöds inte"

**Orsak**: Adress inte P2WPKH bech32
**Lösning**:
- Använd adresser som börjar med "pocx1q" (mainnet) eller "tpocx1q" (testnet)
- Generera ny adress vid behov: `getnewaddress "" "bech32"`

#### "Transaktionsavgift för låg"

**Orsak**: Nätverksmempoolträngsel eller avgift för låg för relä
**Lösning**:
- Öka avgiftsgradsparameter
- Vänta på mempoolrensning

#### "Tilldelning inte ännu aktiv"

**Orsak**: Aktiveringsfördröjning har inte löpt ut ännu
**Lösning**:
- Kontrollera status: block kvar till aktivering
- Vänta på att fördröjningsperiod slutförs

#### "Inga coins tillgängliga på plotadressen"

**Orsak**: Plotadress har inga bekräftade UTXO:er
**Lösning**:
1. Skicka medel till plotadress
2. Vänta på 1 bekräftelse
3. Försök skapa tilldelning igen

#### "Kan inte skapa transaktioner med watch-only-plånbok"

**Orsak**: Plånbok importerade adress utan privat nyckel
**Lösning**: Importera fullständig privat nyckel, inte bara adress

#### "Forging Assignment-flik inte synlig"

**Orsak**: Nod startad utan `-miningserver`-flagga
**Lösning**: Starta om med `bitcoin-qt -server -miningserver`

### Felsökningssteg

1. **Kontrollera plånboksstatus**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verifiera adressägarskap**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Kontrollera: "iswatchonly": false, "ismine": true
   ```

3. **Kontrollera tilldelningsstatus**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Visa senaste transaktioner**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Kontrollera nodsynk**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifiera: blocks == headers (fullt synkad)
   ```

---

## Säkerhetspraxis

### Plotadresssäkerhet

**Nyckelhantering**:
- Lagra plotadressens privata nycklar säkert
- Tilldelningsstransaktioner bevisar ägarskap via signatur
- Endast plotägare kan skapa/återkalla tilldelningar

**Säkerhetskopiering**:
- Säkerhetskopiera plånbok regelbundet (`dumpwallet` eller `backupwallet`)
- Lagra wallet.dat på säker plats
- Anteckna återställningsfraser om HD-plånbok används

### Forgingsadressdelegering

**Säkerhetsmodell**:
- Forgingsadress tar emot blockbelöningar
- Forgingsadress kan signera block (mining)
- Forgingsadress **kan inte** modifiera eller återkalla tilldelning
- Plotägare behåller full kontroll

**Användningsfall**:
- **Varm plånboksdelegering**: Plotnyckel i kall lagring, forgingsnyckel i varm plånbok för mining
- **Poolmining**: Delegera till pool, behåll plotägarskap
- **Delad infrastruktur**: Flera miners, en forgingsadress

### Nätverkstidssynkronisering

**Betydelse**:
- PoCX-konsensus kräver korrekt tid
- Klockdrift >10s utlöser varning
- Klockdrift >15s förhindrar mining

**Lösning**:
- Håll systemklocka synkroniserad med NTP
- Övervaka: `bitcoin-cli getnetworkinfo` för tidsavvikelsevarningar
- Använd pålitliga NTP-servrar

### Tilldelningsfördröjningar

**Aktiveringsfördröjning** (30 block testnet):
- Förhindrar snabb omtilldelning under kedjeforks
- Tillåter nätverk att nå konsensus
- Kan inte förbigås

**Återkallelsefördröjning** (720 block testnet):
- Ger stabilitet för miningpooler
- Förhindrar tilldelnings-"griefing"-attacker
- Forgingsadress förblir aktiv under fördröjning

### Plånbokskryptering

**Aktivera kryptering**:
```bash
bitcoin-cli encryptwallet "ditt_lösenord"
```

**Lås upp för transaktioner**:
```bash
bitcoin-cli walletpassphrase "ditt_lösenord" 300
```

**Bästa praxis**:
- Använd starkt lösenord (20+ tecken)
- Lagra inte lösenord i klartext
- Lås plånbok efter att ha skapat tilldelningar

---

## Kodreferenser

**Forging Assignment-dialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaktionsvisning**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaktionstolkning**: `src/qt/transactionrecord.cpp`
**Plånboksintegration**: `src/pocx/assignments/transactions.cpp`
**Tilldelnings-RPC:er**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Main**: `src/qt/bitcoingui.cpp`

---

## Korsreferenser

Relaterade kapitel:
- [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md) - Miningprocess
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Tilldelningsarkitektur
- [Kapitel 6: Nätverksparametrar](6-network-parameters.md) - Tilldelningsfördröjningsvärden
- [Kapitel 7: RPC-referens](7-rpc-reference.md) - RPC-kommandodetaljer

---

[<- Föregående: RPC-referens](7-rpc-reference.md) | [Innehållsförteckning](index.md)

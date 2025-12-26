[← Forrige: RPC-referanse](7-rpc-reference.md) | [Innholdsfortegnelse](index.md)

---

# Kapittel 8: Lommebok- og GUI-brukerveiledning

Fullstendig veiledning for Bitcoin-PoCX Qt-lommeboken og forging assignment-administrasjon.

---

## Innholdsfortegnelse

1. [Oversikt](#oversikt)
2. [Valutaenheter](#valutaenheter)
3. [Forging assignment-dialog](#forging-assignment-dialog)
4. [Transaksjonshistorikk](#transaksjonshistorikk)
5. [Adressekrav](#adressekrav)
6. [Mining-integrasjon](#mining-integrasjon)
7. [Feilsøking](#feilsøking)
8. [Sikkerhetens beste praksis](#sikkerhetens-beste-praksis)

---

## Oversikt

### Bitcoin-PoCX lommebokfunksjoner

Bitcoin-PoCX Qt-lommeboken (`bitcoin-qt`) gir:
- Standard Bitcoin Core-lommebokfunksjonalitet (send, motta, transaksjonsadministrasjon)
- **Forging assignment manager**: GUI for å opprette/oppheve plottildelinger
- **Mining-servermodus**: `-miningserver`-flagg aktiverer mining-relaterte funksjoner
- **Transaksjonshistorikk**: Visning av tildelings- og opphevingstransaksjoner

### Starte lommeboken

**Kun node** (ingen mining):
```bash
./build/bin/bitcoin-qt
```

**Med mining** (aktiverer tildelingsdialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Kommandolinjealternativ**:
```bash
./build/bin/bitcoind -miningserver
```

### Mining-krav

**For miningoperasjoner**:
- `-miningserver`-flagg påkrevd
- Lommebok med P2WPKH-adresser og private nøkler
- Ekstern plotter (`pocx_plotter`) for plotgenerering
- Ekstern miner (`pocx_miner`) for mining

**For pool-mining**:
- Opprett forging-tildeling til pool-adresse
- Lommebok ikke påkrevd på pool-server (pool administrerer nøkler)

---

## Valutaenheter

### Enhetsvisning

Bitcoin-PoCX bruker **BTCX**-valutaenhet (ikke BTC):

| Enhet | Satoshis | Visning |
|-------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI-innstillinger**: Innstillinger → Visning → Enhet

---

## Forging assignment-dialog

### Åpne dialogen

**Meny**: `Lommebok → Forging-tildelinger`
**Verktøylinje**: Mining-ikon (synlig kun med `-miningserver`-flagg)
**Vindusstørrelse**: 600×450 piksler

### Dialogmoduser

#### Modus 1: Opprett tildeling

**Formål**: Deleger forging-rettigheter til pool eller en annen adresse mens du beholder ploteierskap.

**Bruksområder**:
- Pool-mining (tildel til pool-adresse)
- Kald lagring (mining-nøkkel atskilt fra ploteierskap)
- Delt infrastruktur (deleger til hot wallet)

**Krav**:
- Plotadresse (P2WPKH bech32, må eie privat nøkkel)
- Forging-adresse (P2WPKH bech32, forskjellig fra plotadresse)
- Lommebok ulåst (hvis kryptert)
- Plotadresse har bekreftede UTXO-er

**Trinn**:
1. Velg «Opprett tildeling»-modus
2. Velg plotadresse fra rullegardinmeny eller skriv inn manuelt
3. Skriv inn forging-adresse (pool eller delegat)
4. Klikk «Send tildeling» (knapp aktiveres når inputs er gyldige)
5. Transaksjon kringkastes umiddelbart
6. Tildeling aktiv etter `nForgingAssignmentDelay` blokker:
   - Mainnet/Testnett: 30 blokker (~1 time)
   - Regtest: 4 blokker (~4 sekunder)

**Transaksjonsgebyr**: Standard 10× `minRelayFee` (kan tilpasses)

**Transaksjonsstruktur**:
- Input: UTXO fra plotadresse (beviser eierskap)
- OP_RETURN-output: `POCX`-markør + plot_address + forging_address (46 bytes)
- Vekslepenge-output: Returnert til lommebok

#### Modus 2: Opphev tildeling

**Formål**: Kanseller forging-tildeling og returner rettigheter til ploteier.

**Krav**:
- Plotadresse (må eie privat nøkkel)
- Lommebok ulåst (hvis kryptert)
- Plotadresse har bekreftede UTXO-er

**Trinn**:
1. Velg «Opphev tildeling»-modus
2. Velg plotadresse
3. Klikk «Send oppheving»
4. Transaksjon kringkastes umiddelbart
5. Oppheving effektiv etter `nForgingRevocationDelay` blokker:
   - Mainnet/Testnett: 720 blokker (~24 timer)
   - Regtest: 8 blokker (~8 sekunder)

**Effekt**:
- Forging-adresse kan fortsatt forge under forsinkelsesperiode
- Ploteier gjenvinner rettigheter etter at oppheving er fullført
- Kan opprette ny tildeling etterpå

**Transaksjonsstruktur**:
- Input: UTXO fra plotadresse (beviser eierskap)
- OP_RETURN-output: `XCOP`-markør + plot_address (26 bytes)
- Vekslepenge-output: Returnert til lommebok

#### Modus 3: Sjekk tildelingsstatus

**Formål**: Spør gjeldende tildelingstilstand for enhver plotadresse.

**Krav**: Ingen (skrivebeskyttet, ingen lommebok nødvendig)

**Trinn**:
1. Velg «Sjekk tildelingsstatus»-modus
2. Skriv inn plotadresse
3. Klikk «Sjekk status»
4. Statusboks viser gjeldende tilstand med detaljer

**Tilstandsindikatorer** (fargekodede):

**Grå - UNASSIGNED**
```
UNASSIGNED - Ingen tildeling eksisterer
```

**Oransje - ASSIGNING**
```
ASSIGNING - Tildeling venter på aktivering
Forging-adresse: pocx1qforger...
Opprettet ved høyde: 12000
Aktiveres ved høyde: 12030 (5 blokker gjenstår)
```

**Grønn - ASSIGNED**
```
ASSIGNED - Aktiv tildeling
Forging-adresse: pocx1qforger...
Opprettet ved høyde: 12000
Aktivert ved høyde: 12030
```

**Rød-oransje - REVOKING**
```
REVOKING - Oppheving ventende
Forging-adresse: pocx1qforger... (fortsatt aktiv)
Tildeling opprettet ved høyde: 12000
Opphevet ved høyde: 12300
Oppheving effektiv ved høyde: 13020 (50 blokker gjenstår)
```

**Rød - REVOKED**
```
REVOKED - Tildeling opphevet
Tidligere tildelt til: pocx1qforger...
Tildeling opprettet ved høyde: 12000
Opphevet ved høyde: 12300
Oppheving effektiv ved høyde: 13020
```

---

## Transaksjonshistorikk

### Visning av tildelingstransaksjon

**Type**: «Tildeling»
**Ikon**: Mining-ikon (samme som minde blokker)

**Adressekolonne**: Plotadresse (adresse hvis forging-rettigheter tildeles)
**Beløpskolonne**: Transaksjonsgebyr (negativt, utgående transaksjon)
**Statuskolonne**: Bekreftelsesantall (0-6+)

**Detaljer** (når klikket):
- Transaksjons-ID
- Plotadresse
- Forging-adresse (parset fra OP_RETURN)
- Opprettet ved høyde
- Aktiveringshøyde
- Transaksjonsgebyr
- Tidsstempel

### Visning av opphevingstransaksjon

**Type**: «Oppheving»
**Ikon**: Mining-ikon

**Adressekolonne**: Plotadresse
**Beløpskolonne**: Transaksjonsgebyr (negativt)
**Statuskolonne**: Bekreftelsesantall

**Detaljer** (når klikket):
- Transaksjons-ID
- Plotadresse
- Opphevet ved høyde
- Oppheving effektiv høyde
- Transaksjonsgebyr
- Tidsstempel

### Transaksjonsfiltrering

**Tilgjengelige filtre**:
- «Alle» (standard, inkluderer tildelinger/opphevinger)
- Datoområde
- Beløpsområde
- Søk etter adresse
- Søk etter transaksjons-ID
- Søk etter etikett (hvis adresse er merket)

**Merk**: Tildelings-/opphevingstransaksjoner vises for øyeblikket under «Alle»-filter. Dedikert typefilter ikke ennå implementert.

### Transaksjonssortering

**Sorteringsrekkefølge** (etter type):
- Generert (type 0)
- Mottatt (type 1-3)
- Tildeling (type 4)
- Oppheving (type 5)
- Sendt (type 6+)

---

## Adressekrav

### Kun P2WPKH (SegWit v0)

**Forging-operasjoner krever**:
- Bech32-kodede adresser (starter med «pocx1q» mainnet, «tpocx1q» testnett, «rpocx1q» regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash)-format
- 20-byte nøkkelhash

**IKKE støttet**:
- P2PKH (legacy, starter med «1»)
- P2SH (wrapped SegWit, starter med «3»)
- P2TR (Taproot, starter med «bc1p»)

**Begrunnelse**: PoCX-blokksignaturer krever spesifikt witness v0-format for bevisvalidering.

### Adresserullegardin-filtrering

**Plot-adresse ComboBox**:
- Fylles automatisk med lommebokens mottaksadresser
- Filtrerer ut ikke-P2WPKH-adresser
- Viser format: «Etikett (adresse)» hvis merket, ellers bare adresse
- Første element: «-- Skriv inn egendefinert adresse --» for manuell innføring

**Manuell innføring**:
- Validerer format når skrevet inn
- Må være gyldig bech32 P2WPKH
- Knapp deaktivert hvis ugyldig format

### Valideringsfeilmeldinger

**Dialogfeil**:
- «Plotadresse må være P2WPKH (bech32)»
- «Forging-adresse må være P2WPKH (bech32)»
- «Ugyldig adresseformat»
- «Ingen mynter tilgjengelig på plotadressen. Kan ikke bevise eierskap.»
- «Kan ikke opprette transaksjoner med watch-only lommebok»
- «Lommebok ikke tilgjengelig»
- «Lommebok låst» (fra RPC)

---

## Mining-integrasjon

### Oppsettskrav

**Nodekonfigurasjon**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Lommebokkrav**:
- P2WPKH-adresser for ploteierskap
- Private nøkler for mining (eller forging-adresse hvis tildelinger brukes)
- Bekreftede UTXO-er for transaksjonsoppretting

**Eksterne verktøy**:
- `pocx_plotter`: Generer plotfiler
- `pocx_miner`: Skann plotter og send inn nonces

### Arbeidsflyt

#### Solomining

1. **Generer plotfiler**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <antall>
   ```

2. **Start node** med mining-server:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigurer miner**:
   - Pek til node RPC-endepunkt
   - Spesifiser plotfilkataloger
   - Konfigurer konto-ID (fra plotadresse)

4. **Start mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /sti/til/plotter
   ```

5. **Overvåk**:
   - Miner kaller `get_mining_info` hver blokk
   - Skanner plotter for beste deadline
   - Kaller `submit_nonce` når løsning finnes
   - Node validerer og forger blokk automatisk

#### Pool-mining

1. **Generer plotfiler** (samme som solomining)

2. **Opprett forging-tildeling**:
   - Åpne forging assignment-dialogen
   - Velg plotadresse
   - Skriv inn pools forging-adresse
   - Klikk «Send tildeling»
   - Vent på aktiveringsforsinkelse (30 blokker testnett)

3. **Konfigurer miner**:
   - Pek til **pool**-endepunkt (ikke lokal node)
   - Pool håndterer `submit_nonce` til kjede

4. **Pool-operasjon**:
   - Pool-lommebok har forging-adresse private nøkler
   - Pool validerer innsendinger fra minere
   - Pool kaller `submit_nonce` til blockchain
   - Pool distribuerer belønninger per pool-policy

### Coinbase-belønninger

**Ingen tildeling**:
- Coinbase betaler ploteieradresse direkte
- Sjekk saldo på plotadresse

**Med tildeling**:
- Coinbase betaler forging-adresse
- Pool mottar belønninger
- Miner mottar andel fra pool

**Belønningsplan**:
- Initial: 10 BTCX per blokk
- Halvering: Hver 1050000. blokk (~4 år)
- Plan: 10 → 5 → 2.5 → 1.25 → ...

---

## Feilsøking

### Vanlige problemer

#### «Lommebok har ikke privat nøkkel for plotadresse»

**Årsak**: Lommebok eier ikke adressen
**Løsning**:
- Importer privat nøkkel via `importprivkey` RPC
- Eller bruk annen plotadresse eid av lommebok

#### «Tildeling eksisterer allerede for dette plottet»

**Årsak**: Plot allerede tildelt til en annen adresse
**Løsning**:
1. Opphev eksisterende tildeling
2. Vent på opphevingsforsinkelse (720 blokker testnett)
3. Opprett ny tildeling

#### «Adresseformat ikke støttet»

**Årsak**: Adresse ikke P2WPKH bech32
**Løsning**:
- Bruk adresser som starter med «pocx1q» (mainnet) eller «tpocx1q» (testnett)
- Generer ny adresse om nødvendig: `getnewaddress "" "bech32"`

#### «Transaksjonsgebyr for lavt»

**Årsak**: Nettverks mempool-overbelastning eller gebyr for lavt for relé
**Løsning**:
- Øk gebyrrate-parameter
- Vent på mempool-tømming

#### «Tildeling ikke ennå aktiv»

**Årsak**: Aktiveringsforsinkelse ikke ennå utløpt
**Løsning**:
- Sjekk status: blokker gjenstår til aktivering
- Vent til forsinkelsesperioden er fullført

#### «Ingen mynter tilgjengelig på plotadressen»

**Årsak**: Plotadresse har ingen bekreftede UTXO-er
**Løsning**:
1. Send midler til plotadresse
2. Vent på 1 bekreftelse
3. Prøv tildelingsoppretting på nytt

#### «Kan ikke opprette transaksjoner med watch-only lommebok»

**Årsak**: Lommebok importerte adresse uten privat nøkkel
**Løsning**: Importer full privat nøkkel, ikke bare adresse

#### «Forging assignment-fane ikke synlig»

**Årsak**: Node startet uten `-miningserver`-flagg
**Løsning**: Start på nytt med `bitcoin-qt -server -miningserver`

### Feilsøkingstrinn

1. **Sjekk lommebokstatus**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verifiser adresseeierskap**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Sjekk: "iswatchonly": false, "ismine": true
   ```

3. **Sjekk tildelingsstatus**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Se nylige transaksjoner**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Sjekk nodesynkronisering**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifiser: blocks == headers (fullstendig synkronisert)
   ```

---

## Sikkerhetens beste praksis

### Plotadressesikkerhet

**Nøkkeladministrasjon**:
- Lagre plotadresse private nøkler sikkert
- Tildelingstransaksjoner beviser eierskap via signatur
- Kun ploteier kan opprette/oppheve tildelinger

**Sikkerhetskopiering**:
- Sikkerhetskopier lommebok regelmessig (`dumpwallet` eller `backupwallet`)
- Lagre wallet.dat på sikker plassering
- Registrer gjenopprettingsfraser hvis HD-lommebok brukes

### Forging-adressedelegering

**Sikkerhetsmodell**:
- Forging-adresse mottar blokkbelønninger
- Forging-adresse kan signere blokker (mining)
- Forging-adresse **kan ikke** modifisere eller oppheve tildeling
- Ploteier beholder full kontroll

**Bruksområder**:
- **Hot wallet-delegering**: Plotnøkkel i kald lagring, forging-nøkkel i hot wallet for mining
- **Pool-mining**: Deleger til pool, behold ploteierskap
- **Delt infrastruktur**: Flere minere, én forging-adresse

### Nettverkstidssynkronisering

**Viktighet**:
- PoCX-konsensus krever nøyaktig tid
- Klokkeavvik >10s utløser advarsel
- Klokkeavvik >15s forhindrer mining

**Løsning**:
- Hold systemklokken synkronisert med NTP
- Overvåk: `bitcoin-cli getnetworkinfo` for tidsavvik-advarsler
- Bruk pålitelige NTP-servere

### Tildelingsforsinkelser

**Aktiveringsforsinkelse** (30 blokker testnett):
- Forhindrer rask omtildeling under kjedegafler
- Lar nettverk oppnå konsensus
- Kan ikke omgås

**Opphevingsforsinkelse** (720 blokker testnett):
- Gir stabilitet for mining-pooler
- Forhindrer tildelings-«griefing»-angrep
- Forging-adresse forblir aktiv under forsinkelse

### Lommebokkryptering

**Aktiver kryptering**:
```bash
bitcoin-cli encryptwallet "din_passfrase"
```

**Lås opp for transaksjoner**:
```bash
bitcoin-cli walletpassphrase "din_passfrase" 300
```

**Beste praksis**:
- Bruk sterk passfrase (20+ tegn)
- Ikke lagre passfrase i ren tekst
- Lås lommebok etter å ha opprettet tildelinger

---

## Kodereferanser

**Forging assignment-dialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaksjonsvisning**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaksjonsparsing**: `src/qt/transactionrecord.cpp`
**Lommebokintegrasjon**: `src/pocx/assignments/transactions.cpp`
**Tildelings-RPC-er**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI hoved**: `src/qt/bitcoingui.cpp`

---

## Kryssreferanser

Relaterte kapitler:
- [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md) - Miningprosess
- [Kapittel 4: Forging assignments](4-forging-assignments.md) - Tildelingsarkitektur
- [Kapittel 6: Nettverksparametere](6-network-parameters.md) - Tildelingsforsinkelseverdier
- [Kapittel 7: RPC-referanse](7-rpc-reference.md) - RPC-kommandodetaljer

---

[← Forrige: RPC-referanse](7-rpc-reference.md) | [Innholdsfortegnelse](index.md)

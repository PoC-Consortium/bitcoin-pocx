[Innholdsfortegnelse](index.md) | [Neste: Plotformat →](2-plot-format.md)

---

# Kapittel 1: Introduksjon og oversikt

## Hva er Bitcoin-PoCX?

Bitcoin-PoCX er en Bitcoin Core-integrasjon som legger til støtte for **Proof of Capacity neXt generation (PoCX)**-konsensus. Den opprettholder Bitcoin Cores eksisterende arkitektur samtidig som den muliggjør et energieffektivt Proof of Capacity mining-alternativ som fullstendig erstatning for Proof of Work.

**Viktig distinksjon**: Dette er en **ny kjede** uten bakoverkompatibilitet med Bitcoin PoW. PoCX-blokker er inkompatible med PoW-noder ved design.

---

## Prosjektidentitet

- **Organisasjon**: Proof of Capacity Consortium
- **Prosjektnavn**: Bitcoin-PoCX
- **Fullt navn**: Bitcoin Core med PoCX-integrasjon
- **Status**: Testnett-fase

---

## Hva er Proof of Capacity?

Proof of Capacity (PoC) er en konsensusmekanisme der miningkraft er proporsjonal med **diskplass** i stedet for beregningskraft. Minere forhåndsgenererer store plotfiler som inneholder kryptografiske hasher, og bruker deretter disse plotfilene til å finne gyldige blokkløsninger.

**Energieffektivitet**: Plotfiler genereres én gang og gjenbrukes i det uendelige. Mining bruker minimal CPU-kraft - primært disk-I/O.

**PoCX-forbedringer**:
- Fikset XOR-transpose-komprimeringsangrep (50% tid-minne-avveining i POC2)
- 16-nonce-justert layout for moderne maskinvare
- Skalerbar proof-of-work i plotgenerering (Xn-skaleringsnivåer)
- Native C++-integrasjon direkte i Bitcoin Core
- Time Bending-algoritme for forbedret blokktidsfordeling

---

## Arkitekturoversikt

### Repository-struktur

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX-integrasjon
│   └── src/pocx/        # PoCX-implementasjon
├── pocx/                # PoCX core framework (submodul, skrivebeskyttet)
└── docs/                # Denne dokumentasjonen
```

### Integrasjonsfilosofi

**Minimal integrasjonsflate**: Endringer isolert i `/src/pocx/`-mappen med rene kroker inn i Bitcoin Core-validering, mining og RPC-lag.

**Feature-flagging**: Alle modifikasjoner under `#ifdef ENABLE_POCX`-preprosessordirektiver. Bitcoin Core bygger normalt når deaktivert.

**Oppstrømskompatibilitet**: Regelmessig synkronisering med Bitcoin Core-oppdateringer opprettholdes gjennom isolerte integrasjonspunkter.

**Native C++-implementasjon**: Skalære kryptografiske algoritmer (Shabal256, scoop-beregning, komprimering) integrert direkte i Bitcoin Core for konsensusvalidering.

---

## Hovedfunksjoner

### 1. Fullstendig konsensusutskiftning

- **Blokkstruktur**: PoCX-spesifikke felt erstatter PoW-nonce og difficulty bits
  - Generasjonssignatur (deterministisk mining-entropi)
  - Base target (invers av vanskelighetsgrad)
  - PoCX-bevis (konto-ID, seed, nonce)
  - Blokksignatur (beviser ploteierskap)

- **Validering**: 5-trinns valideringspipeline fra headersjekk gjennom blokkforbindelse

- **Vanskelighetsjustering**: Justering ved hver blokk ved bruk av glidende gjennomsnitt av nylige base targets

### 2. Time Bending-algoritme

**Problem**: Tradisjonelle PoC-blokktider følger eksponentialfordeling, som fører til lange blokker når ingen miner finner en god løsning.

**Løsning**: Fordelingstransformasjon fra eksponentiell til kjikvadrat ved bruk av kubikkrot: `Y = skala × (X^(1/3))`.

**Effekt**: Veldig gode løsninger forger senere (nettverket har tid til å skanne alle disker, reduserer raske blokker), dårlige løsninger forbedres. Gjennomsnittlig blokktid opprettholdes på 120 sekunder, lange blokker reduseres.

**Detaljer**: [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md)

### 3. Forging assignment-system

**Funksjonalitet**: Ploteiere kan delegere forging-rettigheter til andre adresser mens de beholder ploteierskap.

**Bruksområder**:
- Pool-mining (plotter tildeles til pool-adresse)
- Kald lagring (mining-nøkkel atskilt fra ploteierskap)
- Flerparts-mining (delt infrastruktur)

**Arkitektur**: OP_RETURN-kun design - ingen spesielle UTXO-er, tildelinger spores separat i chainstate-databasen.

**Detaljer**: [Kapittel 4: Forging assignments](4-forging-assignments.md)

### 4. Defensiv forging

**Problem**: Raske klokker kan gi tidsfordeler innenfor 15-sekunders fremtidstoleranse.

**Løsning**: Ved mottak av en konkurrerende blokk på samme høyde, sjekk automatisk lokal kvalitet. Hvis bedre, forg umiddelbart.

**Effekt**: Eliminerer insentiv for klokkemanipulasjon - raske klokker hjelper bare hvis du allerede har den beste løsningen.

**Detaljer**: [Kapittel 5: Tidssynkronisering og sikkerhet](5-timing-security.md)

### 5. Dynamisk komprimeringsskalering

**Økonomisk tilpasning**: Skaleringsnivåkrav øker etter eksponentiell plan (År 4, 12, 28, 60, 124 = halveringer 1, 3, 7, 15, 31).

**Effekt**: Etter hvert som blokkbelønninger reduseres, øker plotgenereringsvanskeligheten. Opprettholder sikkerhetsmargin mellom plotoppretting og oppslagskostnader.

**Forebygger**: Kapasitetsinflasjon fra raskere maskinvare over tid.

**Detaljer**: [Kapittel 6: Nettverksparametere](6-network-parameters.md)

---

## Designfilosofi

### Kodesikkerhet

- Defensive programmeringspraksiser gjennomgående
- Omfattende feilhåndtering i valideringsbaner
- Ingen nestede låser (hindrer deadlock)
- Atomiske databaseoperasjoner (UTXO + tildelinger sammen)

### Modulær arkitektur

- Ren separasjon mellom Bitcoin Core-infrastruktur og PoCX-konsensus
- PoCX core framework gir kryptografiske primitiver
- Bitcoin Core gir valideringsrammeverk, database, nettverk

### Ytelsesoptimaliseringer

- Rask-feil-valideringsrekkefølge (billige sjekker først)
- Enkelt konteksthenting per innsending (ingen gjentatte cs_main-anskaffelser)
- Atomiske databaseoperasjoner for konsistens

### Reorganiseringssikkerhet

- Full undo-data for tilstandsendringer i tildelinger
- Forging-tilstand nullstilles ved kjedetipenendringer
- Foreldelsesdeteksjon på alle valideringspunkter

---

## Hvordan PoCX skiller seg fra Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Mining-ressurs** | Beregningskraft (hashrate) | Diskplass (kapasitet) |
| **Energiforbruk** | Høyt (kontinuerlig hashing) | Lavt (kun disk-I/O) |
| **Mining-prosess** | Finn nonce med hash < mål | Finn nonce med deadline < forløpt tid |
| **Vanskelighetsgrad** | `bits`-felt, justeres hver 2016. blokk | `base_target`-felt, justeres hver blokk |
| **Blokktid** | ~10 minutter (eksponentialfordeling) | 120 sekunder (time-bended, redusert varians) |
| **Subsidie** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Maskinvare** | ASIC-er (spesialisert) | HDD-er (standardmaskinvare) |
| **Mining-identitet** | Anonym | Ploteier eller delegat |

---

## Systemkrav

### Nodedrift

**Samme som Bitcoin Core**:
- **CPU**: Moderne x86_64-prosessor
- **Minne**: 4-8 GB RAM
- **Lagring**: Ny kjede, for øyeblikket tom (kan vokse ~4× raskere enn Bitcoin på grunn av 2-minutters blokker og tildelingsdatabase)
- **Nettverk**: Stabil internettforbindelse
- **Klokke**: NTP-synkronisering anbefalt for optimal drift

**Merk**: Plotfiler er IKKE nødvendige for nodedrift.

### Mining-krav

**Tilleggskrav for mining**:
- **Plotfiler**: Forhåndsgenerert ved bruk av `pocx_plotter` (referanseimplementasjon)
- **Miner-programvare**: `pocx_miner` (referanseimplementasjon) kobler til via RPC
- **Lommebok**: `bitcoind` eller `bitcoin-qt` med private nøkler for mining-adresse. Pool-mining krever ikke lokal lommebok.

---

## Komme i gang

### 1. Bygg Bitcoin-PoCX

```bash
# Klon med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Bygg med PoCX aktivert
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detaljer**: Se `CLAUDE.md` i repository-roten

### 2. Kjør node

**Kun node**:
```bash
./build/bin/bitcoind
# eller
./build/bin/bitcoin-qt
```

**For mining** (aktiverer RPC-tilgang for eksterne minere):
```bash
./build/bin/bitcoind -miningserver
# eller
./build/bin/bitcoin-qt -server -miningserver
```

**Detaljer**: [Kapittel 6: Nettverksparametere](6-network-parameters.md)

### 3. Generer plotfiler

Bruk `pocx_plotter` (referanseimplementasjon) for å generere PoCX-format plotfiler.

**Detaljer**: [Kapittel 2: Plotformat](2-plot-format.md)

### 4. Sett opp mining

Bruk `pocx_miner` (referanseimplementasjon) for å koble til nodens RPC-grensesnitt.

**Detaljer**: [Kapittel 7: RPC-referanse](7-rpc-reference.md) og [Kapittel 8: Lommebokveiledning](8-wallet-guide.md)

---

## Attribusjon

### Plotformat

Basert på POC2-format (Burstcoin) med forbedringer:
- Fikset sikkerhetsfeil (XOR-transpose-komprimeringsangrep)
- Skalerbar proof-of-work
- SIMD-optimalisert layout
- Seed-funksjonalitet

### Kildeprosjekter

- **pocx_miner**: Referanseimplementasjon basert på [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referanseimplementasjon basert på [engraver](https://github.com/PoC-Consortium/engraver)

**Full attribusjon**: [Kapittel 2: Plotformat](2-plot-format.md)

---

## Teknisk spesifikasjonsoversikt

- **Blokktid**: 120 sekunder (mainnet), 1 sekund (regtest)
- **Blokksubsidie**: 10 BTC initialt, halvering hver 1050000. blokk (~4 år)
- **Total forsyning**: ~21 millioner BTC (samme som Bitcoin)
- **Fremtidstoleranse**: 15 sekunder (blokker inntil 15s fremover aksepteres)
- **Klokkeadvarsel**: 10 sekunder (advarer operatører om tidsavvik)
- **Tildelingsforsinkelse**: 30 blokker (~1 time)
- **Opphevelsesforsinkelse**: 720 blokker (~24 timer)
- **Adresseformat**: Kun P2WPKH (bech32, pocx1q...) for PoCX mining-operasjoner og forging assignments

---

## Kodeorganisering

**Bitcoin Core-modifikasjoner**: Minimale endringer i kjernefiler, feature-flagget med `#ifdef ENABLE_POCX`

**Ny PoCX-implementasjon**: Isolert i `src/pocx/`-mappen

---

## Sikkerhetshensyn

### Tidssikkerhet

- 15-sekunders fremtidstoleranse forhindrer nettverksfragmentering
- 10-sekunders advarselterskel varsler operatører om klokkeavvik
- Defensiv forging eliminerer insentiv for klokkemanipulasjon
- Time Bending reduserer virkningen av tidsvarians

**Detaljer**: [Kapittel 5: Tidssynkronisering og sikkerhet](5-timing-security.md)

### Tildelingssikkerhet

- OP_RETURN-kun design (ingen UTXO-manipulasjon)
- Transaksjonssignatur beviser ploteierskap
- Aktiveringsforsinkelser forhindrer rask tilstandsmanipulasjon
- Reorganiseringssikker undo-data for alle tilstandsendringer

**Detaljer**: [Kapittel 4: Forging assignments](4-forging-assignments.md)

### Konsensussikkerhet

- Signatur ekskludert fra blokkhash (forhindrer formbarhet)
- Begrensede signaturstørrelser (forhindrer DoS)
- Valdering av komprimeringsbegrensninger (forhindrer svake bevis)
- Vanskelighetsjustering ved hver blokk (responsiv til kapasitetsendringer)

**Detaljer**: [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md)

---

## Nettverksstatus

**Mainnet**: Ikke lansert ennå
**Testnett**: Tilgjengelig for testing
**Regtest**: Fullt funksjonell for utvikling

**Genesis-blokkparametere**: [Kapittel 6: Nettverksparametere](6-network-parameters.md)

---

## Neste steg

**For å forstå PoCX**: Fortsett til [Kapittel 2: Plotformat](2-plot-format.md) for å lære om plotfilstruktur og formatutvikling.

**For mining-oppsett**: Hopp til [Kapittel 7: RPC-referanse](7-rpc-reference.md) for integrasjonsdetaljer.

**For å kjøre en node**: Gjennomgå [Kapittel 6: Nettverksparametere](6-network-parameters.md) for konfigurasjonsalternativer.

---

[Innholdsfortegnelse](index.md) | [Neste: Plotformat →](2-plot-format.md)

[Indholdsfortegnelse](index.md) | [Naeste: Plotformat ->](2-plot-format.md)

---

# Kapitel 1: Introduktion og overblik

## Hvad er Bitcoin-PoCX?

Bitcoin-PoCX er en Bitcoin Core-integration, der tilfojer understottelse af **Proof of Capacity neXt generation (PoCX)**-konsensus. Den bevarer Bitcoin Cores eksisterende arkitektur, mens den muliggor et energieffektivt Proof of Capacity-miningalternativ som en komplet erstatning for Proof of Work.

**Vigtig distinktion**: Dette er en **ny kaede** uden bagudkompatibilitet med Bitcoin PoW. PoCX-blokke er inkompatible med PoW-noder designmaessigt.

---

## Projektidentitet

- **Organisation**: Proof of Capacity Consortium
- **Projektnavn**: Bitcoin-PoCX
- **Fulde navn**: Bitcoin Core med PoCX-integration
- **Status**: Testnet-fase

---

## Hvad er Proof of Capacity?

Proof of Capacity (PoC) er en konsensusmekanisme, hvor miningkraft er proportional med **diskplads** i stedet for beregningskraft. Minere forgenererer store plotfiler indeholdende kryptografiske hashes og bruger derefter disse plots til at finde gyldige bloklosninger.

**Energieffektivitet**: Plotfiler genereres en gang og genbruges pa ubestemt tid. Mining bruger minimal CPU-kraft - primaert disk-I/O.

**PoCX-forbedringer**:
- Rettet XOR-transpose-kompressionsangreb (50% tid-hukommelse-afvejning i POC2)
- 16-nonce-justeret layout til moderne hardware
- Skalerbar proof-of-work i plotgenerering (Xn-skaleringsniveauer)
- Nativ C++-integration direkte i Bitcoin Core
- Time Bending-algoritme til forbedret bloktidsfordeling

---

## Arkitekturoversigt

### Repository-struktur

```
bitcoin-pocx/
-- bitcoin/             # Bitcoin Core v30.0 + PoCX-integration
|   -- src/pocx/        # PoCX-implementering
-- pocx/                # PoCX core framework (submodul, skrivebeskyttet)
-- docs/                # Denne dokumentation
```

### Integrationsfilosofi

**Minimal integrationsoverflade**: AEndringer isoleret i `/src/pocx/`-mappen med rene hooks ind i Bitcoin Core-validering, mining og RPC-lag.

**Feature-flagning**: Alle modifikationer under `#ifdef ENABLE_POCX`-praeprocessorbeskyttelser. Bitcoin Core bygger normalt, nar det er deaktiveret.

**Upstream-kompatibilitet**: Regelmaessig synkronisering med Bitcoin Core-opdateringer vedligeholdt gennem isolerede integrationspunkter.

**Nativ C++-implementering**: Skalare kryptografiske algoritmer (Shabal256, scoop-beregning, kompression) integreret direkte i Bitcoin Core til konsensusvalidering.

---

## Noglefunktioner

### 1. Komplet konsensusudskiftning

- **Blokstruktur**: PoCX-specifikke felter erstatter PoW-nonce og difficulty bits
  - Generationssignatur (deterministisk mining-entropi)
  - Base target (omvendt af difficulty)
  - PoCX-bevis (konto-ID, seed, nonce)
  - Bloksignatur (beviser plot-ejerskab)

- **Validering**: 5-trins valideringspipeline fra header-kontrol til blokforbindelse

- **Difficulty-justering**: Justering ved hver blok ved hjaelp af glidende gennemsnit af nylige base targets

### 2. Time Bending-algoritme

**Problem**: Traditionelle PoC-bloktider folger eksponentiel fordeling, hvilket forer til lange blokke, nar ingen miner finder en god losning.

**Losning**: Fordelingstransformation fra eksponentiel til chi-kvadrat ved hjaelp af kubikrod: `Y = skala x (X^(1/3))`.

**Effekt**: Meget gode losninger forger senere (netvaerket har tid til at scanne alle diske, reducerer hurtige blokke), darlige losninger forbedres. Gennemsnitlig bloktid opretholdes pa 120 sekunder, lange blokke reduceres.

**Detaljer**: [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md)

### 3. Forging Assignment-system

**Kapabilitet**: Plotejere kan delegere forging-rettigheder til andre adresser, mens de bevarer plotejerskabet.

**Anvendelsestilfaelde**:
- Pool-mining (plots tildeles pool-adresse)
- Cold storage (mining-nogle adskilt fra plotejerskab)
- Multi-party mining (delt infrastruktur)

**Arkitektur**: OP_RETURN-baseret design - ingen specielle UTXO'er, assignments spores separat i chainstate-databasen.

**Detaljer**: [Kapitel 4: Forging Assignments](4-forging-assignments.md)

### 4. Defensiv forging

**Problem**: Hurtige ure kunne give timing-fordele inden for 15-sekunders fremtidstolerance.

**Losning**: Nar en konkurrerende blok modtages pa samme hojde, kontrolleres automatisk lokal kvalitet. Hvis bedre, forges med det samme.

**Effekt**: Eliminerer incitament til urmanipulation - hurtige ure hjaelper kun, hvis du allerede har den bedste losning.

**Detaljer**: [Kapitel 5: Tidssynkronisering og sikkerhed](5-timing-security.md)

### 5. Dynamisk kompressionsskalering

**Okonomisk tilpasning**: Krav til skaleringsniveau stiger efter eksponentiel tidsplan (ar 4, 12, 28, 60, 124 = halveringer 1, 3, 7, 15, 31).

**Effekt**: Efterhanden som blokbeloninger falder, stiger plotgenereringssvaerhedsgraden. Opretholder sikkerhedsmargin mellem plotoprettelse og opslagsomkostninger.

**Forebygger**: Kapacitetsinflation fra hurtigere hardware over tid.

**Detaljer**: [Kapitel 6: Netvaerksparametre](6-network-parameters.md)

---

## Designfilosofi

### Kodesikkerhed

- Defensiv programmeringspraksis hele vejen igennem
- Omfattende fejlhandtering i valideringsstier
- Ingen indlejrede lase (deadlock-forebyggelse)
- Atomare databaseoperationer (UTXO + assignments sammen)

### Modulaer arkitektur

- Ren adskillelse mellem Bitcoin Core-infrastruktur og PoCX-konsensus
- PoCX core framework leverer kryptografiske primitiver
- Bitcoin Core leverer valideringsramme, database, netvaerk

### Ydelsesoptimeringer

- Hurtig-fejl-valideringsraekkefolge (billige kontroller forst)
- Enkelt konteksthentning pr. indsendelse (ingen gentagne cs_main-anskaffelser)
- Atomare databaseoperationer for konsistens

### Reorg-sikkerhed

- Fulde undo-data for assignment-tilstandsaendringer
- Forging-tilstand nulstilles ved kaede-tip-aendringer
- Foraldelsesdetektering pa alle valideringspunkter

---

## Hvordan PoCX adskiller sig fra Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Mining-ressource** | Beregningskraft (hashrate) | Diskplads (kapacitet) |
| **Energiforbrug** | Hojt (kontinuerlig hashing) | Lavt (kun disk-I/O) |
| **Mining-proces** | Find nonce med hash < target | Find nonce med deadline < forlobet tid |
| **Difficulty** | `bits`-felt, justeret hver 2016 blok | `base_target`-felt, justeret ved hver blok |
| **Bloktid** | ~10 minutter (eksponentiel fordeling) | 120 sekunder (time-bended, reduceret varians) |
| **Subsidie** | 50 BTC -> 25 -> 12,5 -> ... | 10 BTC -> 5 -> 2,5 -> ... |
| **Hardware** | ASIC'er (specialiseret) | HDD'er (standardhardware) |
| **Mining-identitet** | Anonym | Plotejer eller delegeret |

---

## Systemkrav

### Node-drift

**Samme som Bitcoin Core**:
- **CPU**: Moderne x86_64-processor
- **Hukommelse**: 4-8 GB RAM
- **Lagring**: Ny kaede, i oejeblikket tom (kan vokse ~4x hurtigere end Bitcoin pa grund af 2-minutters blokke og assignment-database)
- **Netvaerk**: Stabil internetforbindelse
- **Ur**: NTP-synkronisering anbefales til optimal drift

**Bemaaerkning**: Plotfiler kraeves IKKE til node-drift.

### Mining-krav

**Yderligere krav til mining**:
- **Plotfiler**: Forgenereret ved hjaelp af `pocx_plotter` (referenceimplementering)
- **Miner-software**: `pocx_miner` (referenceimplementering) forbinder via RPC
- **Wallet**: `bitcoind` eller `bitcoin-qt` med private nogle til miningadresse. Pool-mining kraever ikke lokal wallet.

---

## Kom godt i gang

### 1. Byg Bitcoin-PoCX

```bash
# Klon med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Byg med PoCX aktiveret
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detaljer**: Se `CLAUDE.md` i repository-roden

### 2. Kor node

**Kun node**:
```bash
./build/bin/bitcoind
# eller
./build/bin/bitcoin-qt
```

**Til mining** (aktiverer RPC-adgang for eksterne minere):
```bash
./build/bin/bitcoind -miningserver
# eller
./build/bin/bitcoin-qt -server -miningserver
```

**Detaljer**: [Kapitel 6: Netvaerksparametre](6-network-parameters.md)

### 3. Generer plotfiler

Brug `pocx_plotter` (referenceimplementering) til at generere PoCX-format plotfiler.

**Detaljer**: [Kapitel 2: Plotformat](2-plot-format.md)

### 4. Opsaet mining

Brug `pocx_miner` (referenceimplementering) til at forbinde til din nodes RPC-graenseflade.

**Detaljer**: [Kapitel 7: RPC-reference](7-rpc-reference.md) og [Kapitel 8: Wallet-guide](8-wallet-guide.md)

---

## Tilskrivning

### Plotformat

Baseret pa POC2-format (Burstcoin) med forbedringer:
- Rettet sikkerhedsfejl (XOR-transpose-kompressionsangreb)
- Skalerbar proof-of-work
- SIMD-optimeret layout
- Seed-funktionalitet

### Kildeprojekter

- **pocx_miner**: Referenceimplementering baseret pa [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referenceimplementering baseret pa [engraver](https://github.com/PoC-Consortium/engraver)

**Fuld tilskrivning**: [Kapitel 2: Plotformat](2-plot-format.md)

---

## Oversigt over tekniske specifikationer

- **Bloktid**: 120 sekunder (mainnet), 1 sekund (regtest)
- **Bloksubsidie**: 10 BTC indledningsvis, halvering hver 1050000 blok (~4 ar)
- **Samlet forsyning**: ~21 millioner BTC (samme som Bitcoin)
- **Fremtidstolerance**: 15 sekunder (blokke op til 15s forud accepteres)
- **Uradvarsel**: 10 sekunder (advarer operatorer om tidsdrift)
- **Assignment-forsinkelse**: 30 blokke (~1 time)
- **Tilbagekaldelseforsinkelse**: 720 blokke (~24 timer)
- **Adresseformat**: P2WPKH (bech32, pocx1q...) kun til PoCX-miningoperationer og forging assignments

---

## Kodeorganisering

**Bitcoin Core-modifikationer**: Minimale aendringer til kernefiler, feature-flagget med `#ifdef ENABLE_POCX`

**Ny PoCX-implementering**: Isoleret i `src/pocx/`-mappen

---

## Sikkerhedsovervejelser

### Timing-sikkerhed

- 15-sekunders fremtidstolerance forebygger netvaerksfragmentering
- 10-sekunders advarselstaerskel advarer operatorer om urdrift
- Defensiv forging eliminerer incitament til urmanipulation
- Time Bending reducerer virkningen af timing-varians

**Detaljer**: [Kapitel 5: Tidssynkronisering og sikkerhed](5-timing-security.md)

### Assignment-sikkerhed

- OP_RETURN-baseret design (ingen UTXO-manipulation)
- Transaktionssignatur beviser plotejerskab
- Aktiveringsforsinkelser forebygger hurtig tilstandsmanipulation
- Reorg-sikre undo-data til alle tilstandsaendringer

**Detaljer**: [Kapitel 4: Forging Assignments](4-forging-assignments.md)

### Konsensussikkerhed

- Signatur ekskluderet fra blokhash (forebygger formbarhed)
- Begraensede signaturstorrelser (forebygger DoS)
- Kompressionsgraensevalidering (forebygger svage beviser)
- Difficulty-justering ved hver blok (responsiv over for kapacitetsaendringer)

**Detaljer**: [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md)

---

## Netvaerksstatus

**Mainnet**: Ikke lanceret endnu
**Testnet**: Tilgaengeligt til test
**Regtest**: Fuldt funktionelt til udvikling

**Genesis-blokparametre**: [Kapitel 6: Netvaerksparametre](6-network-parameters.md)

---

## Naeste skridt

**For at forsta PoCX**: Fortsaet til [Kapitel 2: Plotformat](2-plot-format.md) for at laere om plotfilstruktur og formatudvikling.

**For mining-opsaetning**: Hop til [Kapitel 7: RPC-reference](7-rpc-reference.md) for integrationsdetaljer.

**For at kore en node**: Gennemga [Kapitel 6: Netvaerksparametre](6-network-parameters.md) for konfigurationsmuligheder.

---

[Indholdsfortegnelse](index.md) | [Naeste: Plotformat ->](2-plot-format.md)

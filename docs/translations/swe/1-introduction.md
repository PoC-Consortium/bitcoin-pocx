[Innehållsförteckning](index.md) | [Nästa: Plotformat ->](2-plot-format.md)

---

# Kapitel 1: Introduktion och översikt

## Vad är Bitcoin-PoCX?

Bitcoin-PoCX är en Bitcoin Core-integration som lägger till stöd för **Proof of Capacity neXt generation (PoCX)**-konsensus. Den bevarar Bitcoin Cores befintliga arkitektur samtidigt som den möjliggör ett energieffektivt Proof of Capacity-miningalternativ som fullständig ersättning för Proof of Work.

**Viktig distinktion**: Detta är en **ny kedja** utan bakåtkompatibilitet med Bitcoin PoW. PoCX-block är inkompatibla med PoW-noder avsiktligt.

---

## Projektidentitet

- **Organisation**: Proof of Capacity Consortium
- **Projektnamn**: Bitcoin-PoCX
- **Fullständigt namn**: Bitcoin Core med PoCX-integration
- **Status**: Testnetfas

---

## Vad är Proof of Capacity?

Proof of Capacity (PoC) är en konsensusmekanism där miningkraft är proportionell mot **diskutrymme** snarare än beräkningskraft. Miners förgenererar stora plotfiler som innehåller kryptografiska hashar och använder sedan dessa plotfiler för att hitta giltiga blocklösningar.

**Energieffektivitet**: Plotfiler genereras en gång och återanvänds på obestämd tid. Mining förbrukar minimal CPU-kraft - huvudsakligen disk-I/O.

**PoCX-förbättringar**:
- Fixade XOR-transponeringskompressionssattack (50% tid-minnesavvägning i POC2)
- 16-nonce-justerad layout för modern hårdvara
- Skalbart proof-of-work i plotgenerering (Xn-skalningsnivåer)
- Native C++-integration direkt i Bitcoin Core
- Time Bending-algoritm för förbättrad blocktidsfördelning

---

## Arkitekturöversikt

### Arkivstruktur

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX-integration
│   └── src/pocx/        # PoCX-implementation
├── pocx/                # PoCX core framework (submodul, skrivskyddad)
└── docs/                # Denna dokumentation
```

### Integrationsfilosofi

**Minimal integrationsyta**: Ändringar isolerade i `/src/pocx/`-katalogen med rena kopplingar till Bitcoin Cores validerings-, mining- och RPC-lager.

**Funktionsflaggning**: Alla modifikationer under `#ifdef ENABLE_POCX`-preprocessordirektiv. Bitcoin Core bygger normalt när det är inaktiverat.

**Uppströmskompatibilitet**: Regelbunden synkronisering med Bitcoin Core-uppdateringar upprätthålls genom isolerade integrationspunkter.

**Native C++-implementation**: Skalära kryptografiska algoritmer (Shabal256, scoop-beräkning, komprimering) integrerade direkt i Bitcoin Core för konsensusvalidering.

---

## Nyckelfunktioner

### 1. Fullständig konsensusersättning

- **Blockstruktur**: PoCX-specifika fält ersätter PoW-nonce och svårighetsbitarna
  - Generationssignatur (deterministisk miningenttropi)
  - Basmål (inverterad svårighet)
  - PoCX-bevis (konto-ID, seed, nonce)
  - Blocksignatur (bevisar plotägarskap)

- **Validering**: 5-stegs valideringspipeline från headerkontroll till blockansslutning

- **Svårighetsjustering**: Justering varje block med glidande medelvärde av senaste basmålen

### 2. Time Bending-algoritm

**Problem**: Traditionella PoC-blocktider följer exponentiell fördelning, vilket leder till långa block när ingen miner hittar en bra lösning.

**Lösning**: Fördelningsomvandling från exponentiell till chi-kvadrat med kubikrot: `Y = skala × (X^(1/3))`.

**Effekt**: Mycket bra lösningar forgas senare (nätverket har tid att skanna alla diskar, minskar snabba block), dåliga lösningar förbättras. Genomsnittlig blocktid bibehålls vid 120 sekunder, långa block minskas.

**Detaljer**: [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md)

### 3. Forging Assignment-system

**Förmåga**: Plotägare kan delegera forgingrättigheter till andra adresser samtidigt som plotägarskapet bibehålls.

**Användningsfall**:
- Poolmining (plottar tilldelar till pooladress)
- Kall lagring (miningnyckel separat från plotägarskap)
- Flerpartsmining (delad infrastruktur)

**Arkitektur**: OP_RETURN-baserad design - inga speciella UTXO:er, tilldelningar spåras separat i chainstate-databasen.

**Detaljer**: [Kapitel 4: Forging Assignments](4-forging-assignments.md)

### 4. Defensiv forgning

**Problem**: Snabba klockor kan ge tidsfördelar inom 15-sekunders framtidstolerans.

**Lösning**: Vid mottagande av ett konkurrerande block på samma höjd, kontrollera automatiskt lokal kvalitet. Om bättre, forga omedelbart.

**Effekt**: Eliminerar incitament för klockmanipulation - snabba klockor hjälper bara om du redan har den bästa lösningen.

**Detaljer**: [Kapitel 5: Tidssynkronisering och säkerhet](5-timing-security.md)

### 5. Dynamisk kompressionsskalning

**Ekonomisk anpassning**: Skalningsnivåkrav ökar enligt exponentiellt schema (år 4, 12, 28, 60, 124 = halveringar 1, 3, 7, 15, 31).

**Effekt**: När blockbelöningar minskar ökar plotgenereringssvårigheten. Bibehåller säkerhetsmarginal mellan plotskapande och uppslagskostnader.

**Förhindrar**: Kapacitetsinflation från snabbare hårdvara över tid.

**Detaljer**: [Kapitel 6: Nätverksparametrar](6-network-parameters.md)

---

## Designfilosofi

### Kodsäkerhet

- Defensiv programmeringspraxis genomgående
- Omfattande felhantering i valideringsvägar
- Inga nästlade lås (deadlock-förebyggande)
- Atomära databasoperationer (UTXO + tilldelningar tillsammans)

### Modulär arkitektur

- Tydlig separation mellan Bitcoin Core-infrastruktur och PoCX-konsensus
- PoCX core framework tillhandahåller kryptografiska primitiver
- Bitcoin Core tillhandahåller valideringsramverk, databas, nätverk

### Prestandaoptimeringar

- Fail-fast-valideringsordning (billiga kontroller först)
- Enskild kontextinhämtning per inlämning (inga upprepade cs_main-förvärvningar)
- Atomära databasoperationer för konsistens

### Reorg-säkerhet

- Fullständig undo-data för tillståndändringar i tilldelningar
- Forgningtillstånd återställs vid kedjetippsändringar
- Inaktualitetsdetektering vid alla valideringspunkter

---

## Hur PoCX skiljer sig från Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Miningresurs** | Beräkningskraft (hashrate) | Diskutrymme (kapacitet) |
| **Energiförbrukning** | Hög (kontinuerlig hashning) | Låg (endast disk-I/O) |
| **Miningprocess** | Hitta nonce med hash < mål | Hitta nonce med deadline < förfluten tid |
| **Svårighet** | `bits`-fält, justeras var 2016:e block | `base_target`-fält, justeras varje block |
| **Blocktid** | ~10 minuter (exponentiell fördelning) | 120 sekunder (tidböjd, reducerad varians) |
| **Subvention** | 50 BTC -> 25 -> 12,5 -> ... | 10 BTC -> 5 -> 2,5 -> ... |
| **Hårdvara** | ASIC:ar (specialiserad) | Hårddiskar (standardhårdvara) |
| **Miningidentitet** | Anonym | Plotägare eller delegat |

---

## Systemkrav

### Noddrift

**Samma som Bitcoin Core**:
- **CPU**: Modern x86_64-processor
- **Minne**: 4-8 GB RAM
- **Lagring**: Ny kedja, för närvarande tom (kan växa ~4× snabbare än Bitcoin på grund av 2-minutersblock och tilldelningsdatabas)
- **Nätverk**: Stabil internetanslutning
- **Klocka**: NTP-synkronisering rekommenderas för optimal drift

**Notera**: Plotfiler krävs INTE för noddrift.

### Miningkrav

**Ytterligare krav för mining**:
- **Plotfiler**: Förgenererade med `pocx_plotter` (referensimplementation)
- **Miningprogramvara**: `pocx_miner` (referensimplementation) ansluter via RPC
- **Plånbok**: `bitcoind` eller `bitcoin-qt` med privata nycklar för miningadress. Poolmining kräver inte lokal plånbok.

---

## Kom igång

### 1. Bygg Bitcoin-PoCX

```bash
# Klona med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Bygg med PoCX aktiverat
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detaljer**: Se `CLAUDE.md` i arkivets rot

### 2. Kör nod

**Endast nod**:
```bash
./build/bin/bitcoind
# eller
./build/bin/bitcoin-qt
```

**För mining** (aktiverar RPC-åtkomst för externa miners):
```bash
./build/bin/bitcoind -miningserver
# eller
./build/bin/bitcoin-qt -server -miningserver
```

**Detaljer**: [Kapitel 6: Nätverksparametrar](6-network-parameters.md)

### 3. Generera plotfiler

Använd `pocx_plotter` (referensimplementation) för att generera PoCX-formaterade plotfiler.

**Detaljer**: [Kapitel 2: Plotformat](2-plot-format.md)

### 4. Konfigurera mining

Använd `pocx_miner` (referensimplementation) för att ansluta till din nods RPC-gränssnitt.

**Detaljer**: [Kapitel 7: RPC-referens](7-rpc-reference.md) och [Kapitel 8: Plånboksguide](8-wallet-guide.md)

---

## Attribution

### Plotformat

Baserat på POC2-format (Burstcoin) med förbättringar:
- Fixad säkerhetsbrist (XOR-transponeringskompressionssattack)
- Skalbart proof-of-work
- SIMD-optimerad layout
- Seed-funktionalitet

### Källprojekt

- **pocx_miner**: Referensimplementation baserad på [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referensimplementation baserad på [engraver](https://github.com/PoC-Consortium/engraver)

**Fullständig attribution**: [Kapitel 2: Plotformat](2-plot-format.md)

---

## Sammanfattning av tekniska specifikationer

- **Blocktid**: 120 sekunder (mainnet), 1 sekund (regtest)
- **Blocksubvention**: 10 BTC initialt, halvering var 1050000:e block (~4 år)
- **Total tillgång**: ~21 miljoner BTC (samma som Bitcoin)
- **Framtidstolerans**: 15 sekunder (block upp till 15s framåt accepteras)
- **Klockvarning**: 10 sekunder (varnar operatörer om tidsdrift)
- **Tilldelningsfördröjning**: 30 block (~1 timme)
- **Återkallelsefördröjning**: 720 block (~24 timmar)
- **Adressformat**: Endast P2WPKH (bech32, pocx1q...) för PoCX-miningoperationer och forging assignments

---

## Kodorganisation

**Bitcoin Core-modifikationer**: Minimala ändringar i kärnfiler, funktionsflaggade med `#ifdef ENABLE_POCX`

**Ny PoCX-implementation**: Isolerad i `src/pocx/`-katalogen

---

## Säkerhetsöverväganden

### Tidssäkerhet

- 15 sekunders framtidstolerans förhindrar nätverksfragmentering
- 10 sekunders varningströskel alerterar operatörer om klockdrift
- Defensiv forgning eliminerar incitament för klockmanipulation
- Time Bending reducerar inverkan av tidsvarians

**Detaljer**: [Kapitel 5: Tidssynkronisering och säkerhet](5-timing-security.md)

### Tilldelningssäkerhet

- OP_RETURN-baserad design (ingen UTXO-manipulation)
- Transaktionssignatur bevisar plotägarskap
- Aktiveringsfördröjningar förhindrar snabb tillståndsmanipulation
- Reorg-säker undo-data för alla tillståndsändringar

**Detaljer**: [Kapitel 4: Forging Assignments](4-forging-assignments.md)

### Konsensussäkerhet

- Signatur exkluderad från blockhash (förhindrar formbarhet)
- Begränsade signaturstorlekar (förhindrar DoS)
- Valdering av kompressionsgränser (förhindrar svaga bevis)
- Svårighetsjustering varje block (responsiv för kapacitetsändringar)

**Detaljer**: [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md)

---

## Nätverksstatus

**Mainnet**: Inte lanserat ännu
**Testnet**: Tillgängligt för testning
**Regtest**: Fullt funktionellt för utveckling

**Genesisblockparametrar**: [Kapitel 6: Nätverksparametrar](6-network-parameters.md)

---

## Nästa steg

**För att förstå PoCX**: Fortsätt till [Kapitel 2: Plotformat](2-plot-format.md) för att lära dig om plotfilstruktur och formatutveckling.

**För miningkonfiguration**: Hoppa till [Kapitel 7: RPC-referens](7-rpc-reference.md) för integrationsdetaljer.

**För att köra en nod**: Granska [Kapitel 6: Nätverksparametrar](6-network-parameters.md) för konfigurationsalternativ.

---

[Innehållsförteckning](index.md) | [Nästa: Plotformat ->](2-plot-format.md)

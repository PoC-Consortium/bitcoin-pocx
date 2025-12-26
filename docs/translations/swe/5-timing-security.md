[<- Föregående: Forging Assignments](4-forging-assignments.md) | [Innehållsförteckning](index.md) | [Nästa: Nätverksparametrar ->](6-network-parameters.md)

---

# Kapitel 5: Tidssynkronisering och säkerhet

## Översikt

PoCX-konsensus kräver exakt tidssynkronisering över nätverket. Detta kapitel dokumenterar tidsrelaterade säkerhetsmekanismer, klockdriftstolerans och defensivt forgningsbeteende.

**Nyckelmekanismer**:
- 15 sekunders framtidstolerans för blocktidsstämplar
- 10 sekunders klockdriftsvarningssystem
- Defensiv forgning (anti-klockmanipulation)
- Time Bending-algoritmintegration

---

## Innehållsförteckning

1. [Krav på tidssynkronisering](#krav-på-tidssynkronisering)
2. [Klockdriftsdetektering och varningar](#klockdriftsdetektering-och-varningar)
3. [Defensiv forgningssmekanism](#defensiv-forgningsmekanism)
4. [Säkerhetshotanalys](#säkerhetshotanalys)
5. [Bästa praxis för nodoperatörer](#bästa-praxis-för-nodoperatörer)

---

## Krav på tidssynkronisering

### Konstanter och parametrar

**Bitcoin-PoCX-konfiguration:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekunder

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekunder
```

### Valideringskontroller

**Blocktidsstämpelvalidering** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monoton kontroll: tidsstämpel >= föregående blocks tidsstämpel
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Framtidskontroll: tidsstämpel <= nu + 15 sekunder
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadline-kontroll: förfluten tid >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabell över klockdriftspåverkan

| Klockavvikelse | Kan synka? | Kan mina? | Valideringsstatus | Konkurrenseffekt |
|----------------|------------|-----------|-------------------|------------------|
| -30s långsam | NEJ - Framtidskontroll misslyckas | N/A | **DÖD NOD** | Kan inte delta |
| -14s långsam | Ja | Ja | Sen forgning, passerar validering | Förlorar races |
| 0s perfekt | Ja | Ja | Optimal | Optimal |
| +14s snabb | Ja | Ja | Tidig forgning, passerar validering | Vinner races |
| +16s snabb | Ja | NEJ - Framtidskontroll misslyckas | Kan inte propagera block | Kan synka, kan inte mina |

**Viktig insikt**: 15-sekunders fönstret är symmetriskt för deltagande (±14.9s), men snabba klockor ger orättvis konkurrensförd inom toleransen.

### Time Bending-integration

Time Bending-algoritmen (detaljerad i [Kapitel 3](3-consensus-and-mining.md#time-bending-beräkning)) omvandlar råa deadlines med kubikrot:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Interaktion med klockdrift**:
- Bättre lösningar forgas tidigare (kubikrot förstärker kvalitetsskillnader)
- Klockdrift påverkar forgningstid relativt nätverket
- Defensiv forgning säkerställer kvalitetsbaserad konkurrens trots tidsvarians

---

## Klockdriftsdetektering och varningar

### Varningssystem

Bitcoin-PoCX övervakar tidsavvikelse mellan lokal nod och nätverkspeers.

**Varningsmeddelande** (när drift överstiger 10 sekunder):
> "Din dators datum och tid verkar vara mer än 10 sekunder ur synk med nätverket, detta kan leda till PoCX-konsensusfel. Vänligen kontrollera din systemklocka."

**Implementation**: `src/node/timeoffsets.cpp`

### Designmotivation

**Varför 10 sekunder?**
- Ger 5 sekunders säkerhetsmarginal före 15-sekunders toleransgräns
- Striktare än Bitcoin Cores standard (10 minuter)
- Lämplig för PoC-tidskrav

**Förebyggande approach**:
- Tidig varning före kritiskt fel
- Tillåter operatörer att fixa problem proaktivt
- Minskar nätverksfragmentering från tidsrelaterade fel

---

## Defensiv forgningsmekanism

### Vad det är

Defensiv forgning är ett standard-minerbeteende i Bitcoin-PoCX som eliminerar tidsbaserade fördelar i blockproduktion. När din miner tar emot ett konkurrerande block på samma höjd kontrollerar den automatiskt om du har en bättre lösning. Om så är fallet forgar den omedelbart ditt block, vilket säkerställer kvalitetsbaserad konkurrens snarare än klockmanipulationsbaserad konkurrens.

### Problemet

PoCX-konsensus tillåter block med tidsstämplar upp till 15 sekunder i framtiden. Denna tolerans är nödvändig för global nätverkssynkronisering. Den skapar dock en möjlighet för klockmanipulation:

**Utan defensiv forgning:**
- Miner A: Korrekt tid, kvalitet 800 (bättre), väntar korrekt deadline
- Miner B: Snabb klocka (+14s), kvalitet 1000 (sämre), forgar 14 sekunder tidigt
- Resultat: Miner B vinner racet trots sämre proof-of-capacity-arbete

**Problemet:** Klockmanipulation ger fördel även med sämre kvalitet, vilket underminerar proof-of-capacity-principen.

### Lösningen: Tvåskiktigt försvar

#### Skikt 1: Klockdriftsvarning (förebyggande)

Bitcoin-PoCX övervakar tidsavvikelse mellan din nod och nätverkspeers. Om din klocka driftar mer än 10 sekunder från nätverkskonsensus får du en varning som alerterar dig att fixa klockproblem innan de orsakar problem.

#### Skikt 2: Defensiv forgning (reaktiv)

När en annan miner publicerar ett block på samma höjd du minar:

1. **Detektering**: Din nod identifierar samma-höjd-konkurrens
2. **Validering**: Extraherar och validerar det konkurrerande blockets kvalitet
3. **Jämförelse**: Kontrollerar om din kvalitet är bättre
4. **Respons**: Om bättre, forga ditt block omedelbart

**Resultat:** Nätverket tar emot båda blocken och väljer det med bättre kvalitet genom standard fork-resolution.

### Hur det fungerar

#### Scenario: Samma-höjd-konkurrens

```
Tid 150s: Miner B (klocka +10s) forgar med kvalitet 1000
           -> Blocktidsstämpel visar 160s (10s i framtiden)

Tid 150s: Din nod tar emot Miner B:s block
           -> Detekterar: samma höjd, kvalitet 1000
           -> Du har: kvalitet 800 (bättre!)
           -> Åtgärd: Forga omedelbart med korrekt tidsstämpel (150s)

Tid 152s: Nätverket validerar båda blocken
           -> Båda giltiga (inom 15s tolerans)
           -> Kvalitet 800 vinner (lägre = bättre)
           -> Ditt block blir kedjetipp
```

#### Scenario: Genuin reorg

```
Din mininghöjd 100, konkurrent publicerar block 99
-> Inte samma-höjd-konkurrens
-> Defensiv forgning triggas INTE
-> Normal reorg-hantering fortsätter
```

### Fördelar

**Noll incitament för klockmanipulation**
- Snabba klockor hjälper bara om du har bästa kvaliteten ändå
- Klockmanipulation blir ekonomiskt meningslöst

**Kvalitetsbaserad konkurrens upprätthålls**
- Tvingar miners att konkurrera på faktiskt proof-of-capacity-arbete
- Bevarar PoCX-konsensusintegritet

**Nätverkssäkerhet**
- Motståndskraftig mot tidsbaserade spelstrategier
- Inga konsensusändringar krävs - rent minerbeteende

**Helt automatiskt**
- Ingen konfiguration behövs
- Triggas endast när nödvändigt
- Standardbeteende i alla Bitcoin-PoCX-noder

### Avvägningar

**Minimal ökning av orphan-rate**
- Avsiktlig - attackblock blir orphans
- Inträffar endast under faktiska klockmanipulationsförsök
- Naturligt resultat av kvalitetsbaserad fork-resolution

**Kort nätverkskonkurrens**
- Nätverket ser kortvarigt två konkurrerande block
- Löses på sekunder genom standardvalidering
- Samma beteende som samtidig mining i Bitcoin

### Tekniska detaljer

**Prestandapåverkan:** Försumbar
- Triggas endast vid samma-höjd-konkurrens
- Använder minnesdata (ingen disk-I/O)
- Validering slutförs på millisekunder

**Resursanvändning:** Minimal
- ~20 rader kärnlogik
- Återanvänder befintlig valideringsinfrastruktur
- Enskild låsförvärvning

**Kompatibilitet:** Full
- Inga konsensusregeländringar
- Fungerar med alla Bitcoin Core-funktioner
- Valfri övervakning via debug-loggar

**Status**: Aktiv i alla Bitcoin-PoCX-releaser
**Först introducerad**: 2025-10-10

---

## Säkerhetshotanalys

### Snabb klocka-attack (mildrad av defensiv forgning)

**Attackvektor**:
En miner med en klocka **+14s före** kan:
1. Ta emot block normalt (verkar gamla för dem)
2. Forga block omedelbart när deadline passerar
3. Sända block som verkar 14s "tidiga" för nätverket
4. **Block accepteras** (inom 15s tolerans)
5. **Vinner races** mot ärliga miners

**Påverkan utan defensiv forgning**:
Fördelen är begränsad till 14.9 sekunder (inte tillräckligt för att hoppa över betydande PoC-arbete), men ger konsekvent fördel i blockraces.

**Mildring (defensiv forgning)**:
- Ärliga miners detekterar samma-höjd-konkurrens
- Jämför kvalitetsvärden
- Forgar omedelbart om kvaliteten är bättre
- **Resultat**: Snabb klocka hjälper bara om du redan har bästa kvalitet
- **Incitament**: Noll - klockmanipulation blir ekonomiskt meningslöst

### Långsam klocka-fel (kritiskt)

**Felläge**:
En nod **>15s efter** är katastrofalt:
- Kan inte validera inkommande block (framtidskontroll misslyckas)
- Blir isolerad från nätverket
- Kan inte mina eller synka

**Mildring**:
- Stark varning vid 10s drift ger 5-sekunders buffert före kritiskt fel
- Operatörer kan fixa klockproblem proaktivt
- Tydliga felmeddelanden guidar felsökning

---

## Bästa praxis för nodoperatörer

### Konfiguration av tidssynkronisering

**Rekommenderad konfiguration**:
1. **Aktivera NTP**: Använd Network Time Protocol för automatisk synkronisering
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Kontrollera status
   timedatectl status
   ```

2. **Verifiera klocknoggrannhet**: Kontrollera tidsavvikelse regelbundet
   ```bash
   # Kontrollera NTP-synkstatus
   ntpq -p

   # Eller med chrony
   chronyc tracking
   ```

3. **Övervaka varningar**: Titta efter Bitcoin-PoCX-klockdriftsvarningar i loggar

### För miners

**Ingen åtgärd krävs**:
- Funktionen är alltid aktiv
- Fungerar automatiskt
- Håll bara din systemklocka korrekt

**Bästa praxis**:
- Använd NTP-tidssynkronisering
- Övervaka klockdriftsvarningar
- Åtgärda varningar omgående om de dyker upp

**Förväntat beteende**:
- Solo mining: Defensiv forgning triggas sällan (ingen konkurrens)
- Nätverksmining: Skyddar mot klockmanipulationsförsök
- Transparent drift: De flesta miners märker det aldrig

### Felsökning

**Varning: "10 sekunder ur synk"**
- Åtgärd: Kontrollera och fixa systemklocksynkronisering
- Påverkan: 5-sekunders buffert före kritiskt fel
- Verktyg: NTP, chrony, systemd-timesyncd

**Fel: "time-too-new" på inkommande block**
- Orsak: Din klocka är >15 sekunder långsam
- Påverkan: Kan inte validera block, nod isolerad
- Fix: Synka systemklocka omedelbart

**Fel: Kan inte propagera forgade block**
- Orsak: Din klocka är >15 sekunder snabb
- Påverkan: Block avvisade av nätverket
- Fix: Synka systemklocka omedelbart

---

## Designbeslut och motivering

### Varför 15-sekunders tolerans?

**Motivering**:
- Bitcoin-PoCX:s variabla deadline-timing är mindre tidskritisk än fast-timing-konsensus
- 15s ger adekvat skydd samtidigt som nätverksfragmentering förhindras

**Avvägningar**:
- Tätare tolerans = mer nätverksfragmentering från mindre drift
- Lösare tolerans = mer möjlighet för tidsattacker
- 15s balanserar säkerhet och robusthet

### Varför 10-sekunders varning?

**Resonemang**:
- Ger 5-sekunders säkerhetsbuffert
- Mer lämplig för PoC än Bitcoins 10-minuters standard
- Tillåter proaktiva fixar före kritiskt fel

### Varför defensiv forgning?

**Problem som adresseras**:
- 15-sekunders tolerans möjliggör snabb-klocka-fördel
- Kvalitetsbaserad konsensus kunde undermineras av tidsmanipulation

**Lösningsfördelar**:
- Nollkostnadsförsvar (inga konsensusändringar)
- Automatisk drift
- Eliminerar attackincitament
- Bevarar proof-of-capacity-principer

### Varför ingen intra-nätverks-tidssynkronisering?

**Säkerhetsresonemang**:
- Modern Bitcoin Core tog bort peer-baserad tidsjustering
- Sårbar för Sybil-attacker på uppfattad nätverkstid
- PoCX undviker medvetet att förlita sig på nätverksinterna tidskällor
- Systemklocka är mer pålitlig än peer-konsensus
- Operatörer bör synkronisera med NTP eller motsvarande extern tidskälla
- Noder övervakar sin egen drift och avger varningar om lokal klocka avviker från senaste blocktidsstämplar

---

## Implementationsreferenser

**Kärnfiler**:
- Tidsvalidering: `src/validation.cpp:4547-4561`
- Framtidstoleranskonstant: `src/chain.h:31`
- Varningströskel: `src/node/timeoffsets.h:27`
- Tidsavvikelseövervakning: `src/node/timeoffsets.cpp`
- Defensiv forgning: `src/pocx/mining/scheduler.cpp`

**Relaterad dokumentation**:
- Time Bending-algoritm: [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md#time-bending-beräkning)
- Blockvalidering: [Kapitel 3: Blockvalidering](3-consensus-and-mining.md#blockvalidering)

---

**Genererad**: 2025-10-10
**Status**: Fullständig implementation
**Täckning**: Krav på tidssynkronisering, klockdriftshantering, defensiv forgning

---

[<- Föregående: Forging Assignments](4-forging-assignments.md) | [Innehållsförteckning](index.md) | [Nästa: Nätverksparametrar ->](6-network-parameters.md)

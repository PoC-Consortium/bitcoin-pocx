[<- Forrige: Forging Assignments](4-forging-assignments.md) | [Indholdsfortegnelse](index.md) | [Naeste: Netvaerksparametre ->](6-network-parameters.md)

---

# Kapitel 5: Tidssynkronisering og sikkerhed

## Oversigt

PoCX-konsensus kraever praecis tidssynkronisering pa tvaers af netvaerket. Dette kapitel dokumenterer tidsrelaterede sikkerhedsmekanismer, urdriftstolerance og defensiv forging-adfaerd.

**Noglemekanismer**:
- 15-sekunders fremtidstolerance for bloktidsstempler
- 10-sekunders urdriftsadvarselssystem
- Defensiv forging (anti-urmanipulation)
- Time Bending-algoritmeintegration

---

## Indholdsfortegnelse

1. [Tidssynkroniseringskrav](#tidssynkroniseringskrav)
2. [Urdriftsdetektion og advarsler](#urdriftsdetektion-og-advarsler)
3. [Defensiv forging-mekanisme](#defensiv-forging-mekanisme)
4. [Sikkerhedstrusselanalyse](#sikkerhedstrusselanalyse)
5. [Bedste praksis for node-operatorer](#bedste-praksis-for-node-operatorer)

---

## Tidssynkroniseringskrav

### Konstanter og parametre

**Bitcoin-PoCX-konfiguration:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekunder

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekunder
```

### Valideringskontroller

**Bloktidsstempelvalidering** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monoton kontrol: tidsstempel >= forrige bloks tidsstempel
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Fremtidskontrol: tidsstempel <= nu + 15 sekunder
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadline-kontrol: forlobet tid >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Urdriftskonsekvenstabel

| Uroffset | Kan synkronisere? | Kan mine? | Valideringsstatus | Konkurrenceeffekt |
|----------|-------------------|-----------|-------------------|-------------------|
| -30s langsom | NEJ - Fremtidskontrol fejler | N/A | **DOD NODE** | Kan ikke deltage |
| -14s langsom | Ja | Ja | Sen forging, bestar validering | Taber veddelob |
| 0s perfekt | Ja | Ja | Optimal | Optimal |
| +14s hurtig | Ja | Ja | Tidlig forging, bestar validering | Vinder veddelob |
| +16s hurtig | Ja | NEJ - Fremtidskontrol fejler | Kan ikke udbrede blokke | Kan synkronisere, kan ikke mine |

**Vigtig indsigt**: 15-sekunders vinduet er symmetrisk for deltagelse (+/-14,9s), men hurtige ure giver unfair konkurrencefordel inden for tolerancen.

### Time Bending-integration

Time Bending-algoritmen (detaljeret i [Kapitel 3](3-consensus-and-mining.md#time-bending-beregning)) transformerer ra deadlines ved hjaelp af kubikrod:

```
time_bended_deadline = skala x (deadline_seconds)^(1/3)
```

**Interaktion med urdrift**:
- Bedre losninger forger hurtigere (kubikrod forstaerker kvalitetsforskelle)
- Urdrift pavirker forgetid relativt til netvaerk
- Defensiv forging sikrer kvalitetsbaseret konkurrence pa trods af timingvarians

---

## Urdriftsdetektion og advarsler

### Advarselssystem

Bitcoin-PoCX overvager tidsforskydning mellem lokal node og netvaerkspeers.

**Advarselsmeddelelse** (nar drift overstiger 10 sekunder):
> "Din computers dato og tid ser ud til at vaere mere end 10 sekunder ude af synkronisering med netvaerket. Dette kan fore til PoCX-konsensusfejl. Kontroller venligst dit systemur."

**Implementering**: `src/node/timeoffsets.cpp`

### Designrationale

**Hvorfor 10 sekunder?**
- Giver 5-sekunders sikkerhedsbuffer for 15-sekunders tolerancegraense
- Strengere end Bitcoin Cores standard (10 minutter)
- Passende til PoC-timingkrav

**Forebyggende tilgang**:
- Tidlig advarsel for kritisk fejl
- Tillader operatorer at rette problemer proaktivt
- Reducerer netvaerksfragmentering fra tidsrelaterede fejl

---

## Defensiv forging-mekanisme

### Hvad det er

Defensiv forging er en standard mineradfaerd i Bitcoin-PoCX, der eliminerer timingbaserede fordele i blokproduktion. Nar din miner modtager en konkurrerende blok pa samme hojde, kontrollerer den automatisk, om du har en bedre losning. Hvis ja, forger den din blok ojeblikkelig, hvilket sikrer kvalitetsbaseret konkurrence i stedet for urmanipulationsbaseret konkurrence.

### Problemet

PoCX-konsensus tillader blokke med tidsstempler op til 15 sekunder i fremtiden. Denne tolerance er nodvendig for global netvaerkssynkronisering. Den skaber imidlertid en mulighed for urmanipulation:

**Uden defensiv forging:**
- Miner A: Korrekt tid, kvalitet 800 (bedre), venter pa korrekt deadline
- Miner B: Hurtigt ur (+14s), kvalitet 1000 (darligere), forger 14 sekunder for tidligt
- Resultat: Miner B vinder veddelobet pa trods af ringere proof-of-capacity-arbejde

**Problemet:** Urmanipulation giver fordel selv med darligere kvalitet, hvilket underminerer proof-of-capacity-princippet.

### Losningen: To-lags forsvar

#### Lag 1: Urdriftsadvarsel (forebyggende)

Bitcoin-PoCX overvager tidsforskydning mellem din node og netvaerkspeers. Hvis dit ur drifter mere end 10 sekunder fra netvaerkskonsensus, modtager du en advarsel, der advarer dig om at rette urproblemer, for de forarsager problemer.

#### Lag 2: Defensiv forging (reaktiv)

Nar en anden miner offentliggor en blok pa samme hojde, du miner:

1. **Detektion**: Din node identificerer samme-hojde-konkurrence
2. **Validering**: Udtraekker og validerer den konkurrerende bloks kvalitet
3. **Sammenligning**: Kontrollerer om din kvalitet er bedre
4. **Respons**: Hvis bedre, forger din blok ojeblikkelig

**Resultat:** Netvaerket modtager begge blokke og vaelger den med bedre kvalitet gennem standard forkoplosning.

### Hvordan det fungerer

#### Scenarie: Samme-hojde-konkurrence

```
Tid 150s: Miner B (ur +10s) forger med kvalitet 1000
          -> Bloktidsstempel viser 160s (10s i fremtiden)

Tid 150s: Din node modtager Miner B's blok
          -> Detekterer: samme hojde, kvalitet 1000
          -> Du har: kvalitet 800 (bedre!)
          -> Handling: Forg ojeblikkelig med korrekt tidsstempel (150s)

Tid 152s: Netvaerk validerer begge blokke
          -> Begge gyldige (inden for 15s tolerance)
          -> Kvalitet 800 vinder (lavere = bedre)
          -> Din blok bliver kaede-tip
```

#### Scenarie: Aegte reorg

```
Din mininghojde 100, konkurrent offentliggor blok 99
-> Ikke samme-hojde-konkurrence
-> Defensiv forging udloses IKKE
-> Normal reorg-handtering fortsaetter
```

### Fordele

**Nul incitament til urmanipulation**
- Hurtige ure hjaelper kun, hvis du allerede har den bedste kvalitet
- Urmanipulation bliver okonomisk meningslost

**Kvalitetsbaseret konkurrence haandhaevet**
- Tvinger minere til at konkurrere pa faktisk proof-of-capacity-arbejde
- Bevarer PoCX-konsensusintegritet

**Netvaerkssikkerhed**
- Modstandsdygtig over for timingbaserede spillestrategier
- Ingen konsensusaendringer kraevet - ren mineradfaerd

**Fuldt automatisk**
- Ingen konfiguration nodvendig
- Udloses kun nar nodvendigt
- Standardadfaerd i alle Bitcoin-PoCX-noder

### Afvejninger

**Minimal orphan-rateforogelse**
- Tilsigtet - angrebsblokke bliver orphaned
- Sker kun under faktiske urmanipulationsforsog
- Naturligt resultat af kvalitetsbaseret forkoplosning

**Kort netvaerkskonkurrence**
- Netvaerket ser kortvarigt to konkurrerende blokke
- Loses pa sekunder gennem standardvalidering
- Samme adfaerd som samtidig mining i Bitcoin

### Tekniske detaljer

**Ydelsespavirkning:** Ubetydelig
- Udloses kun ved samme-hojde-konkurrence
- Bruger in-memory-data (ingen disk-I/O)
- Validering faerdigudfres pa millisekunder

**Ressourceforbrug:** Minimalt
- ~20 linjer kernekode
- Genbruger eksisterende valideringsinfrastruktur
- Enkelt lasanskaffelse

**Kompatibilitet:** Fuld
- Ingen konsensusregelaendringer
- Fungerer med alle Bitcoin Core-funktioner
- Valgfri overvagning via debug-logfiler

**Status**: Aktiv i alle Bitcoin-PoCX-udgivelser
**Forst introduceret**: 2025-10-10

---

## Sikkerhedstrusselanalyse

### Hurtigt ur-angreb (afbodet af defensiv forging)

**Angrebsvektor**:
En miner med et ur **+14s foran** kan:
1. Modtage blokke normalt (de ser gamle ud for dem)
2. Forge blokke ojeblikkelig, nar deadline er passeret
3. Udsende blokke, der virker 14s "tidlige" for netvaerket
4. **Blokke accepteres** (inden for 15s tolerance)
5. **Vinder veddelob** mod aerlige minere

**Konsekvens uden defensiv forging**:
Fordelen er begraenset til 14,9 sekunder (ikke nok til at springe betydeligt PoC-arbejde over), men giver konsekvent fordel i blokveddelob.

**Afbodning (defensiv forging)**:
- AErlige minere detekterer samme-hojde-konkurrence
- Sammenligner kvalitetsvaerdier
- Forger ojeblikkelig, hvis kvalitet er bedre
- **Resultat**: Hurtigt ur hjaelper kun, hvis du allerede har bedste kvalitet
- **Incitament**: Nul - urmanipulation bliver okonomisk meningslost

### Langsomt ur-fejl (kritisk)

**Fejltilstand**:
En node **>15s bagud** er katastrofal:
- Kan ikke validere indgaende blokke (fremtidskontrol fejler)
- Bliver isoleret fra netvaerk
- Kan ikke mine eller synkronisere

**Afbodning**:
- Staerk advarsel ved 10s drift giver 5-sekunders buffer for kritisk fejl
- Operatorer kan rette urproblemer proaktivt
- Klare fejlmeddelelser guider fejlfinding

---

## Bedste praksis for node-operatorer

### Tidssynkroniseringsopsaetning

**Anbefalet konfiguration**:
1. **Aktiver NTP**: Brug Network Time Protocol til automatisk synkronisering
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Kontroller status
   timedatectl status
   ```

2. **Bekraeft urnojagdtighed**: Kontroller regelmaessigt tidsforskydning
   ```bash
   # Kontroller NTP-synkroniseringsstatus
   ntpq -p

   # Eller med chrony
   chronyc tracking
   ```

3. **Overvaeg advarsler**: Hold oje med Bitcoin-PoCX-urdriftsadvarsler i logfiler

### For minere

**Ingen handling kraevet**:
- Funktionen er altid aktiv
- Fungerer automatisk
- Hold blot dit systemur njagtigt

**Bedste praksis**:
- Brug NTP-tidssynkronisering
- Overvaeg for urdriftsadvarsler
- Adresser advarsler omgaende, hvis de dukker op

**Forventet adfaerd**:
- Solo-mining: Defensiv forging udloses sjaeldent (ingen konkurrence)
- Netvaerksmining: Beskytter mod urmanipulationsforsog
- Transparent drift: De fleste minere bemaerker det aldrig

### Fejlfinding

**Advarsel: "10 sekunder ude af synkronisering"**
- Handling: Kontroller og ret systemursynkronisering
- Konsekvens: 5-sekunders buffer for kritisk fejl
- Vaerktoojer: NTP, chrony, systemd-timesyncd

**Fejl: "time-too-new" pa indgaende blokke**
- Arsag: Dit ur er >15 sekunder langsomt
- Konsekvens: Kan ikke validere blokke, node isoleret
- Losning: Synkroniser systemur ojeblikkelig

**Fejl: Kan ikke udbrede forgede blokke**
- Arsag: Dit ur er >15 sekunder hurtigt
- Konsekvens: Blokke afvises af netvaerk
- Losning: Synkroniser systemur ojeblikkelig

---

## Designbeslutninger og rationale

### Hvorfor 15-sekunders tolerance?

**Rationale**:
- Bitcoin-PoCX variabel deadline-timing er mindre tidskritisk end fixed-timing-konsensus
- 15s giver tilstraekkelig beskyttelse, mens det forebygger netvaerksfragmentering

**Afvejninger**:
- Strammere tolerance = mere netvaerksfragmentering fra mindre drift
- Losere tolerance = mere mulighed for timingangreb
- 15s balancerer sikkerhed og robusthed

### Hvorfor 10-sekunders advarsel?

**Raesonnement**:
- Giver 5-sekunders sikkerhedsbuffer
- Mere passende for PoC end Bitcoins 10-minutters standard
- Tillader proaktive rettelser for kritisk fejl

### Hvorfor defensiv forging?

**Problem adresseret**:
- 15-sekunders tolerance muliggor hurtigt ur-fordel
- Kvalitetsbaseret konsensus kunne undermineres af timingmanipulation

**Losningsfordele**:
- Nul-omkostningsforsvar (ingen konsensusaendringer)
- Automatisk drift
- Eliminerer angrebsincitament
- Bevarer proof-of-capacity-principper

### Hvorfor ingen intra-netvaerkstidssynkronisering?

**Sikkerhedsraesonnement**:
- Moderne Bitcoin Core fjernede peer-baseret tidsjustering
- Sarbar over for Sybil-angreb pa opfattet netvaerkstid
- PoCX undgar bevidst at stole pa netvaerksinterne tidskilder
- Systemur er mere trovaerdigt end peer-konsensus
- Operatorer bor synkronisere ved hjaelp af NTP eller tilsvarende ekstern tidskilde
- Noder overvager deres egen drift og udsender advarsler, hvis lokalt ur afviger fra nylige bloktidsstempler

---

## Implementeringsreferencer

**Kernefiler**:
- Tidsvalidering: `src/validation.cpp:4547-4561`
- Fremtidstolerancekonstant: `src/chain.h:31`
- Advarselsgraensevaerdi: `src/node/timeoffsets.h:27`
- Tidsforskydningsovervagning: `src/node/timeoffsets.cpp`
- Defensiv forging: `src/pocx/mining/scheduler.cpp`

**Relateret dokumentation**:
- Time Bending-algoritme: [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md#time-bending-beregning)
- Blokvalidering: [Kapitel 3: Blokvalidering](3-consensus-and-mining.md#blokvalidering)

---

**Genereret**: 2025-10-10
**Status**: Komplet implementering
**Daekning**: Tidssynkroniseringskrav, urdrifthandtering, defensiv forging

---

[<- Forrige: Forging Assignments](4-forging-assignments.md) | [Indholdsfortegnelse](index.md) | [Naeste: Netvaerksparametre ->](6-network-parameters.md)

[← Forrige: Forging assignments](4-forging-assignments.md) | [Innholdsfortegnelse](index.md) | [Neste: Nettverksparametere →](6-network-parameters.md)

---

# Kapittel 5: Tidssynkronisering og sikkerhet

## Oversikt

PoCX-konsensus krever presis tidssynkronisering på tvers av nettverket. Dette kapittelet dokumenterer tidsrelaterte sikkerhetsmekanismer, klokkeavviktoleranse og defensiv forging-oppførsel.

**Nøkkelmekanismer**:
- 15-sekunders fremtidstoleranse for blokktidsstempler
- 10-sekunders klokkeavvik-advarselssystem
- Defensiv forging (anti-klokkemanipulasjon)
- Time Bending-algoritmeintegrasjon

---

## Innholdsfortegnelse

1. [Tidssynkroniseringskrav](#tidssynkroniseringskrav)
2. [Klokkeavviksdeteksjon og advarsler](#klokkeavviksdeteksjon-og-advarsler)
3. [Defensiv forging-mekanisme](#defensiv-forging-mekanisme)
4. [Sikkerhetsstrussel-analyse](#sikkerhetsstrussel-analyse)
5. [Beste praksis for nodeoperatører](#beste-praksis-for-nodeoperatører)

---

## Tidssynkroniseringskrav

### Konstanter og parametere

**Bitcoin-PoCX-konfigurasjon:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekunder

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekunder
```

### Valideringssjekker

**Blokktidsstempel-validering** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monoton sjekk: tidsstempel >= forrige blokks tidsstempel
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Fremtidssjekk: tidsstempel <= nå + 15 sekunder
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadline-sjekk: forløpt tid >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabell over klokkeavvik-konsekvenser

| Klokkeavvik | Kan synkronisere? | Kan mine? | Valideringsstatus | Konkurranseeffekt |
|-------------|-------------------|-----------|-------------------|-------------------|
| -30s treg | IKKE MULIG - Fremtidssjekk feiler | N/A | **DØD NODE** | Kan ikke delta |
| -14s treg | Ja | Ja | Sen forging, passerer validering | Taper konkurranser |
| 0s perfekt | Ja | Ja | Optimal | Optimal |
| +14s rask | Ja | Ja | Tidlig forging, passerer validering | Vinner konkurranser |
| +16s rask | Ja | IKKE MULIG - Fremtidssjekk feiler | Kan ikke propagere blokker | Kan synkronisere, kan ikke mine |

**Viktig innsikt**: 15-sekundersvinduet er symmetrisk for deltakelse (±14,9s), men raske klokker gir urettferdig konkurransefordel innenfor toleransen.

### Time Bending-integrasjon

Time Bending-algoritmen (detaljert i [Kapittel 3](3-consensus-and-mining.md#time-bending-beregning)) transformerer rå deadlines ved bruk av kubikkrot:

```
time_bended_deadline = skala × (deadline_seconds)^(1/3)
```

**Interaksjon med klokkeavvik**:
- Bedre løsninger forger tidligere (kubikkrot forsterker kvalitetsforskjeller)
- Klokkeavvik påvirker forgetid relativt til nettverk
- Defensiv forging sikrer kvalitetsbasert konkurranse til tross for tidsvaians

---

## Klokkeavviksdeteksjon og advarsler

### Advarselssystem

Bitcoin-PoCX overvåker tidsavvik mellom lokal node og nettverkspeers.

**Advarselsmelding** (når avvik overstiger 10 sekunder):
> «Datamaskinens dato og klokkeslett ser ut til å være mer enn 10 sekunder ute av synk med nettverket, dette kan føre til PoCX-konsensusfeil. Vennligst sjekk systemklokken.»

**Implementasjon**: `src/node/timeoffsets.cpp`

### Designbegrunnelse

**Hvorfor 10 sekunder?**
- Gir 5-sekunders sikkerhetsbuffer før 15-sekunders toleransegrense
- Strengere enn Bitcoin Cores standard (10 minutter)
- Passende for PoC-timingkrav

**Forebyggende tilnærming**:
- Tidlig advarsel før kritisk feil
- Lar operatører fikse problemer proaktivt
- Reduserer nettverksfragmentering fra tidsrelaterte feil

---

## Defensiv forging-mekanisme

### Hva det er

Defensiv forging er en standard mineroppførsel i Bitcoin-PoCX som eliminerer tidsbaserte fordeler i blokkproduksjon. Når mineren din mottar en konkurrerende blokk på samme høyde, sjekker den automatisk om du har en bedre løsning. I så fall forger den blokken din umiddelbart, noe som sikrer kvalitetsbasert konkurranse i stedet for klokkemanipulasjonsbasert konkurranse.

### Problemet

PoCX-konsensus tillater blokker med tidsstempler inntil 15 sekunder i fremtiden. Denne toleransen er nødvendig for global nettverkssynkronisering. Den skaper imidlertid en mulighet for klokkemanipulasjon:

**Uten defensiv forging:**
- Miner A: Korrekt tid, kvalitet 800 (bedre), venter riktig deadline
- Miner B: Rask klokke (+14s), kvalitet 1000 (dårligere), forger 14 sekunder tidlig
- Resultat: Miner B vinner konkurransen til tross for dårligere proof-of-capacity-arbeid

**Problemet:** Klokkemanipulasjon gir fordel selv med dårligere kvalitet, noe som undergraver proof-of-capacity-prinsippet.

### Løsningen: To-lags forsvar

#### Lag 1: Klokkeavvik-advarsel (forebyggende)

Bitcoin-PoCX overvåker tidsavvik mellom noden din og nettverkspeers. Hvis klokken din avviker mer enn 10 sekunder fra nettverkskonsensus, mottar du en advarsel som varsler deg om å fikse klokkeproblemer før de skaper problemer.

#### Lag 2: Defensiv forging (reaktiv)

Når en annen miner publiserer en blokk på samme høyde du miner:

1. **Deteksjon**: Noden din identifiserer samme-høyde-konkurranse
2. **Validering**: Trekker ut og validerer den konkurrerende blokkens kvalitet
3. **Sammenligning**: Sjekker om kvaliteten din er bedre
4. **Respons**: Hvis bedre, forger blokken din umiddelbart

**Resultat:** Nettverket mottar begge blokker og velger den med bedre kvalitet gjennom standard gaffeloppløsning.

### Hvordan det fungerer

#### Scenario: Samme-høyde-konkurranse

```
Tid 150s: Miner B (klokke +10s) forger med kvalitet 1000
          → Blokktidsstempel viser 160s (10s i fremtiden)

Tid 150s: Noden din mottar Miner Bs blokk
          → Oppdager: samme høyde, kvalitet 1000
          → Du har: kvalitet 800 (bedre!)
          → Handling: Forg umiddelbart med korrekt tidsstempel (150s)

Tid 152s: Nettverk validerer begge blokker
          → Begge gyldige (innenfor 15s toleranse)
          → Kvalitet 800 vinner (lavere = bedre)
          → Blokken din blir kjedetipp
```

#### Scenario: Ekte reorg

```
Din mininghøyde 100, konkurrent publiserer blokk 99
→ Ikke samme-høyde-konkurranse
→ Defensiv forging utløses IKKE
→ Normal reorg-håndtering fortsetter
```

### Fordeler

**Null insentiv for klokkemanipulasjon**
- Raske klokker hjelper bare hvis du allerede har beste kvalitet
- Klokkemanipulasjon blir økonomisk meningsløst

**Kvalitetsbasert konkurranse håndheves**
- Tvinger minere til å konkurrere på faktisk proof-of-capacity-arbeid
- Bevarer PoCX-konsensusintegritet

**Nettverkssikkerhet**
- Motstandsdyktig mot tidsbaserte spillstrategier
- Ingen konsensusendringer påkrevd - ren mineroppførsel

**Fullstendig automatisk**
- Ingen konfigurasjon nødvendig
- Utløses kun når nødvendig
- Standardoppførsel i alle Bitcoin-PoCX-noder

### Avveininger

**Minimal økning i foreldreløse blokker**
- Tilsiktet - angrepsblokker blir foreldreløse
- Oppstår kun under faktiske klokkemanipulasjonsforsøk
- Naturlig resultat av kvalitetsbasert gaffeloppløsning

**Kort nettverkskonkurranse**
- Nettverk ser kort to konkurrerende blokker
- Løses i løpet av sekunder gjennom standard validering
- Samme oppførsel som samtidig mining i Bitcoin

### Tekniske detaljer

**Ytelsespåvirkning:** Ubetydelig
- Utløses kun ved samme-høyde-konkurranse
- Bruker data i minne (ingen disk-I/O)
- Validering fullføres i løpet av millisekunder

**Ressursbruk:** Minimal
- ~20 linjer med kjernelogikk
- Gjenbruker eksisterende valideringsinfrastruktur
- Enkelt låsanskaffelse

**Kompatibilitet:** Full
- Ingen konsensusregelendringer
- Fungerer med alle Bitcoin Core-funksjoner
- Valgfri overvåking via feilsøkingslogger

**Status**: Aktiv i alle Bitcoin-PoCX-utgivelser
**Først introdusert**: 2025-10-10

---

## Sikkerhetsstrussel-analyse

### Rask klokke-angrep (avbøtet av defensiv forging)

**Angrepsvektor**:
En miner med en klokke **+14s foran** kan:
1. Motta blokker normalt (virker gamle for dem)
2. Forge blokker umiddelbart når deadline passerer
3. Kringkaste blokker som virker 14s «tidlige» for nettverket
4. **Blokker aksepteres** (innenfor 15s toleranse)
5. **Vinner konkurranser** mot ærlige minere

**Konsekvens uten defensiv forging**:
Fordelen er begrenset til 14,9 sekunder (ikke nok til å hoppe over betydelig PoC-arbeid), men gir konsistent fordel i blokkkonkurranser.

**Avbøting (defensiv forging)**:
- Ærlige minere oppdager samme-høyde-konkurranse
- Sammenligner kvalitetsverdier
- Forger umiddelbart hvis kvalitet er bedre
- **Resultat**: Rask klokke hjelper bare hvis du allerede har beste kvalitet
- **Insentiv**: Null - klokkemanipulasjon blir økonomisk meningsløst

### Treg klokke-feil (kritisk)

**Feilmodus**:
En node **>15s bak** er katastrofalt:
- Kan ikke validere innkommende blokker (fremtidssjekk feiler)
- Blir isolert fra nettverk
- Kan ikke mine eller synkronisere

**Avbøting**:
- Sterk advarsel ved 10s avvik gir 5-sekunders buffer før kritisk feil
- Operatører kan fikse klokkeproblemer proaktivt
- Klare feilmeldinger veileder feilsøking

---

## Beste praksis for nodeoperatører

### Oppsett av tidssynkronisering

**Anbefalt konfigurasjon**:
1. **Aktiver NTP**: Bruk Network Time Protocol for automatisk synkronisering
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Sjekk status
   timedatectl status
   ```

2. **Verifiser klokkenøyaktighet**: Sjekk tidsavvik regelmessig
   ```bash
   # Sjekk NTP-synkstatus
   ntpq -p

   # Eller med chrony
   chronyc tracking
   ```

3. **Overvåk advarsler**: Se etter Bitcoin-PoCX klokkeavvik-advarsler i logger

### For minere

**Ingen handling påkrevd**:
- Funksjonen er alltid aktiv
- Opererer automatisk
- Bare hold systemklokken nøyaktig

**Beste praksis**:
- Bruk NTP-tidssynkronisering
- Overvåk for klokkeavvik-advarsler
- Adresser advarsler umiddelbart hvis de dukker opp

**Forventet oppførsel**:
- Solomining: Defensiv forging utløses sjelden (ingen konkurranse)
- Nettverksmining: Beskytter mot klokkemanipulasjonsforsøk
- Transparent operasjon: De fleste minere legger aldri merke til det

### Feilsøking

**Advarsel: «10 sekunder ute av synk»**
- Handling: Sjekk og fiks systemklokkesynkronisering
- Konsekvens: 5-sekunders buffer før kritisk feil
- Verktøy: NTP, chrony, systemd-timesyncd

**Feil: «time-too-new» på innkommende blokker**
- Årsak: Klokken din er >15 sekunder treg
- Konsekvens: Kan ikke validere blokker, node isolert
- Fiks: Synkroniser systemklokke umiddelbart

**Feil: Kan ikke propagere forgede blokker**
- Årsak: Klokken din er >15 sekunder rask
- Konsekvens: Blokker avvist av nettverk
- Fiks: Synkroniser systemklokke umiddelbart

---

## Designbeslutninger og begrunnelse

### Hvorfor 15-sekunders toleranse?

**Begrunnelse**:
- Bitcoin-PoCX variable deadline-timing er mindre tidskritisk enn konsensus med fast timing
- 15s gir tilstrekkelig beskyttelse samtidig som nettverksfragmentering forebygges

**Avveininger**:
- Strammere toleranse = mer nettverksfragmentering fra mindre avvik
- Løsere toleranse = mer mulighet for timingangrep
- 15s balanserer sikkerhet og robusthet

### Hvorfor 10-sekunders advarsel?

**Begrunnelse**:
- Gir 5-sekunders sikkerhetsbuffer
- Mer passende for PoC enn Bitcoins 10-minutters standard
- Tillater proaktive fikser før kritisk feil

### Hvorfor defensiv forging?

**Problem som adresseres**:
- 15-sekunders toleranse muliggjør rask-klokke-fordel
- Kvalitetsbasert konsensus kunne undergraves av timingmanipulasjon

**Løsningsfordeler**:
- Nullkostnadsforsvar (ingen konsensusendringer)
- Automatisk operasjon
- Eliminerer angrepsinsentiv
- Bevarer proof-of-capacity-prinsipper

### Hvorfor ingen intern nettverkstidssynkronisering?

**Sikkerhetsbegrunnelse**:
- Moderne Bitcoin Core fjernet peer-basert tidsjustering
- Sårbar for Sybil-angrep på oppfattet nettverkstid
- PoCX unngår bevisst å stole på nettverks-interne tidskilder
- Systemklokke er mer pålitelig enn peer-konsensus
- Operatører bør synkronisere ved bruk av NTP eller tilsvarende ekstern tidskilde
- Noder overvåker sitt eget avvik og sender advarsler hvis lokal klokke avviker fra nylige blokktidsstempler

---

## Implementasjonsreferanser

**Kjernefiler**:
- Tidsvalidering: `src/validation.cpp:4547-4561`
- Fremtidstoleransekonstant: `src/chain.h:31`
- Advarselsterskel: `src/node/timeoffsets.h:27`
- Tidsavvikovervåking: `src/node/timeoffsets.cpp`
- Defensiv forging: `src/pocx/mining/scheduler.cpp`

**Relatert dokumentasjon**:
- Time Bending-algoritme: [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md#time-bending-beregning)
- Blokkvalidering: [Kapittel 3: Blokkvalidering](3-consensus-and-mining.md#blokkvalidering)

---

**Generert**: 2025-10-10
**Status**: Fullstendig implementasjon
**Dekning**: Tidssynkroniseringskrav, klokkeavvikhåndtering, defensiv forging

---

[← Forrige: Forging assignments](4-forging-assignments.md) | [Innholdsfortegnelse](index.md) | [Neste: Nettverksparametere →](6-network-parameters.md)

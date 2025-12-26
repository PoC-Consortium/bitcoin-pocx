[Vorige: Forging-toewijzingen](4-forging-assignments.md) | [Inhoudsopgave](index.md) | [Volgende: Netwerkparameters](6-network-parameters.md)

---

# Hoofdstuk 5: Tijdsynchronisatie en beveiliging

## Overzicht

PoCX-consensus vereist nauwkeurige tijdsynchronisatie over het netwerk. Dit hoofdstuk documenteert tijdgerelateerde beveiligingsmechanismen, klokverschuivingstolerantie en defensief forginggedrag.

**Belangrijkste mechanismen**:
- 15-seconden toekomsttolerantie voor bloktijdstempels
- 10-seconden klokverschuivingswaarschuwingssysteem
- Defensief forgen (anti-klokmanipulatie)
- Time Bending-algoritme-integratie

---

## Inhoudsopgave

1. [Tijdsynchronisatievereisten](#tijdsynchronisatievereisten)
2. [Klokverschuivingsdetectie en waarschuwingen](#klokverschuivingsdetectie-en-waarschuwingen)
3. [Defensief forgingmechanisme](#defensief-forgingmechanisme)
4. [Beveiligingsdreigingsanalyse](#beveiligingsdreigingsanalyse)
5. [Best practices voor node-operators](#best-practices-voor-node-operators)

---

## Tijdsynchronisatievereisten

### Constanten en parameters

**Bitcoin-PoCX-configuratie:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 seconden

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 seconden
```

### Validatiecontroles

**Bloktijdstempelvalidatie** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotone controle: tijdstempel >= tijdstempel vorig blok
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Toekomstcontrole: tijdstempel <= nu + 15 seconden
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadline-controle: verstreken tijd >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Klokverschuivingsimpacttabel

| Klokverschuiving | Kan synchroniseren? | Kan minen? | Validatiestatus | Competitief effect |
|------------------|---------------------|------------|-----------------|-------------------|
| -30s traag | NEE - Toekomstcontrole faalt | N.v.t. | **DODE NODE** | Kan niet deelnemen |
| -14s traag | Ja | Ja | Laat forgen, slaagt voor validatie | Verliest races |
| 0s perfect | Ja | Ja | Optimaal | Optimaal |
| +14s snel | Ja | Ja | Vroeg forgen, slaagt voor validatie | Wint races |
| +16s snel | Ja | NEE - Toekomstcontrole faalt | Kan blokken niet propageren | Kan synchroniseren, kan niet minen |

**Belangrijk inzicht**: Het 15-seconden venster is symmetrisch voor deelname (+-14,9s), maar snelle klokken bieden oneerlijk competitief voordeel binnen tolerantie.

### Time Bending-integratie

Time Bending-algoritme (gedetailleerd in [Hoofdstuk 3](3-consensus-and-mining.md#time-bending-berekening)) transformeert ruwe deadlines met kubuswortel:

```
time_bended_deadline = schaal x (deadline_seconden)^(1/3)
```

**Interactie met klokverschuiving**:
- Betere oplossingen forgen eerder (kubuswortel versterkt kwaliteitsverschillen)
- Klokverschuiving beinvloedt forgetijd relatief aan netwerk
- Defensief forgen zorgt voor kwaliteitsgebaseerde competitie ondanks timingvariantie

---

## Klokverschuivingsdetectie en waarschuwingen

### Waarschuwingssysteem

Bitcoin-PoCX monitort tijdsverschuiving tussen lokale node en netwerkpeers.

**Waarschuwingsbericht** (wanneer verschuiving 10 seconden overschrijdt):
> "De datum en tijd van uw computer lijken meer dan 10 seconden uit synchronisatie met het netwerk te zijn, dit kan leiden tot PoCX-consensusfout. Controleer uw systeemklok."

**Implementatie**: `src/node/timeoffsets.cpp`

### Ontwerprationale

**Waarom 10 seconden?**
- Biedt 5-seconden veiligheidsbuffer voor 15-seconden tolerantiegrens
- Strikter dan Bitcoin Core's standaard (10 minuten)
- Passend voor PoC-timingvereisten

**Preventieve aanpak**:
- Vroegtijdige waarschuwing voor kritieke fout
- Stelt operators in staat problemen proactief op te lossen
- Vermindert netwerkfragmentatie door tijdgerelateerde fouten

---

## Defensief forgingmechanisme

### Wat het is

Defensief forgen is een standaard minergedrag in Bitcoin-PoCX dat timinggebaseerde voordelen in blokproductie elimineert. Wanneer uw miner een concurrerend blok op dezelfde hoogte ontvangt, controleert het automatisch of u een betere oplossing hebt. Zo ja, dan forgt het onmiddellijk uw blok, wat zorgt voor kwaliteitsgebaseerde competitie in plaats van klokmanipulatiegebaseerde competitie.

### Het probleem

PoCX-consensus staat blokken toe met tijdstempels tot 15 seconden in de toekomst. Deze tolerantie is noodzakelijk voor wereldwijde netwerksynchronisatie. Het creert echter een mogelijkheid voor klokmanipulatie:

**Zonder defensief forgen:**
- Miner A: Correcte tijd, kwaliteit 800 (beter), wacht juiste deadline
- Miner B: Snelle klok (+14s), kwaliteit 1000 (slechter), forgt 14 seconden eerder
- Resultaat: Miner B wint de race ondanks inferieur proof-of-capacity-werk

**Het probleem:** Klokmanipulatie biedt voordeel zelfs met slechtere kwaliteit, wat het proof-of-capacity-principe ondermijnt.

### De oplossing: tweelaagse verdediging

#### Laag 1: Klokverschuivingswaarschuwing (preventief)

Bitcoin-PoCX monitort tijdsverschuiving tussen uw node en netwerkpeers. Als uw klok meer dan 10 seconden van netwerkconsensus afwijkt, ontvangt u een waarschuwing die u alert maakt om klokproblemen op te lossen voordat ze problemen veroorzaken.

#### Laag 2: Defensief forgen (reactief)

Wanneer een andere miner een blok publiceert op dezelfde hoogte als u mint:

1. **Detectie**: Uw node identificeert competitie op dezelfde hoogte
2. **Validatie**: Extraheert en valideert de kwaliteit van het concurrerende blok
3. **Vergelijking**: Controleert of uw kwaliteit beter is
4. **Respons**: Indien beter, forgt uw blok onmiddellijk

**Resultaat:** Het netwerk ontvangt beide blokken en kiest degene met betere kwaliteit via standaard fork-resolutie.

### Hoe het werkt

#### Scenario: Competitie op dezelfde hoogte

```
Tijd 150s: Miner B (klok +10s) forgt met kwaliteit 1000
           -> Bloktijdstempel toont 160s (10s in toekomst)

Tijd 150s: Uw node ontvangt blok van Miner B
           -> Detecteert: zelfde hoogte, kwaliteit 1000
           -> U hebt: kwaliteit 800 (beter!)
           -> Actie: Forge onmiddellijk met correcte tijdstempel (150s)

Tijd 152s: Netwerk valideert beide blokken
           -> Beide geldig (binnen 15s tolerantie)
           -> Kwaliteit 800 wint (lager = beter)
           -> Uw blok wordt ketentip
```

#### Scenario: Echte reorg

```
Uw mininghoogte 100, concurrent publiceert blok 99
-> Geen competitie op dezelfde hoogte
-> Defensief forgen triggert NIET
-> Normale reorg-afhandeling gaat door
```

### Voordelen

**Nul prikkel voor klokmanipulatie**
- Snelle klokken helpen alleen als u toch al de beste kwaliteit hebt
- Klokmanipulatie wordt economisch zinloos

**Kwaliteitsgebaseerde competitie afgedwongen**
- Dwingt miners om te concurreren op daadwerkelijk proof-of-capacity-werk
- Behoudt PoCX-consensusintegriteit

**Netwerkbeveiliging**
- Bestand tegen timinggebaseerde spelstrategieen
- Geen consensuswijzigingen vereist - puur minergedrag

**Volledig automatisch**
- Geen configuratie nodig
- Triggert alleen wanneer noodzakelijk
- Standaardgedrag in alle Bitcoin-PoCX-nodes

### Afwegingen

**Minimale orphan-rateverhoging**
- Opzettelijk - aanvalsblokken worden orphaned
- Treedt alleen op tijdens daadwerkelijke klokmanipulatiepogingen
- Natuurlijk resultaat van kwaliteitsgebaseerde fork-resolutie

**Korte netwerkcompetitie**
- Netwerk ziet kort twee concurrerende blokken
- Lost op in seconden via standaardvalidatie
- Zelfde gedrag als gelijktijdig minen in Bitcoin

### Technische details

**Prestatie-impact:** Verwaarloosbaar
- Alleen getriggerd bij competitie op dezelfde hoogte
- Gebruikt in-memory gegevens (geen schijf-I/O)
- Validatie voltooit in milliseconden

**Resourcegebruik:** Minimaal
- ~20 regels kernlogica
- Hergebruikt bestaande validatie-infrastructuur
- Enkele lock-acquisitie

**Compatibiliteit:** Volledig
- Geen consensusregelwijzigingen
- Werkt met alle Bitcoin Core-functies
- Optionele monitoring via debug-logs

**Status**: Actief in alle Bitcoin-PoCX-releases
**Eerst geintroduceerd**: 10-10-2025

---

## Beveiligingsdreigingsanalyse

### Snelle-klokaanval (gemitigeerd door defensief forgen)

**Aanvalsvector**:
Een miner met een klok **+14s vooruit** kan:
1. Blokken normaal ontvangen (lijken oud voor hen)
2. Blokken onmiddellijk forgen wanneer deadline verstrijkt
3. Blokken uitzenden die 14s "vroeg" lijken voor het netwerk
4. **Blokken worden geaccepteerd** (binnen 15s tolerantie)
5. **Wint races** tegen eerlijke miners

**Impact zonder defensief forgen**:
Het voordeel is beperkt tot 14,9 seconden (niet genoeg om significant PoC-werk over te slaan), maar biedt consistent voordeel in blokraces.

**Mitigatie (defensief forgen)**:
- Eerlijke miners detecteren competitie op dezelfde hoogte
- Vergelijken kwaliteitswaarden
- Forgen onmiddellijk als kwaliteit beter is
- **Resultaat**: Snelle klok helpt alleen als u al beste kwaliteit hebt
- **Prikkel**: Nul - klokmanipulatie wordt economisch zinloos

### Trage-klokfout (kritiek)

**Foutmodus**:
Een node **>15s achter** is catastrofaal:
- Kan binnenkomende blokken niet valideren (toekomstcontrole faalt)
- Wordt geisoleerd van netwerk
- Kan niet minen of synchroniseren

**Mitigatie**:
- Sterke waarschuwing bij 10s verschuiving geeft 5-seconden buffer voor kritieke fout
- Operators kunnen klokproblemen proactief oplossen
- Duidelijke foutmeldingen begeleiden probleemoplossing

---

## Best practices voor node-operators

### Tijdsynchronisatie-setup

**Aanbevolen configuratie**:
1. **Schakel NTP in**: Gebruik Network Time Protocol voor automatische synchronisatie
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Controleer status
   timedatectl status
   ```

2. **Verifieer kloknauwkeurigheid**: Controleer regelmatig tijdsverschuiving
   ```bash
   # Controleer NTP-synchronisatiestatus
   ntpq -p

   # Of met chrony
   chronyc tracking
   ```

3. **Monitor waarschuwingen**: Let op Bitcoin-PoCX-klokverschuivingswaarschuwingen in logs

### Voor miners

**Geen actie vereist**:
- Functie is altijd actief
- Werkt automatisch
- Houd gewoon uw systeemklok nauwkeurig

**Best practices**:
- Gebruik NTP-tijdsynchronisatie
- Monitor op klokverschuivingswaarschuwingen
- Pak waarschuwingen direct aan als ze verschijnen

**Verwacht gedrag**:
- Solo-mining: Defensief forgen triggert zelden (geen competitie)
- Netwerkmining: Beschermt tegen klokmanipulatiepogingen
- Transparante werking: De meeste miners merken het nooit

### Probleemoplossing

**Waarschuwing: "10 seconden uit synchronisatie"**
- Actie: Controleer en repareer systeemkloksynchronisatie
- Impact: 5-seconden buffer voor kritieke fout
- Tools: NTP, chrony, systemd-timesyncd

**Fout: "time-too-new" op binnenkomende blokken**
- Oorzaak: Uw klok is >15 seconden traag
- Impact: Kan blokken niet valideren, node geisoleerd
- Oplossing: Synchroniseer systeemklok onmiddellijk

**Fout: Kan geforede blokken niet propageren**
- Oorzaak: Uw klok is >15 seconden snel
- Impact: Blokken afgewezen door netwerk
- Oplossing: Synchroniseer systeemklok onmiddellijk

---

## Ontwerpbeslissingen en rationale

### Waarom 15-seconden tolerantie?

**Rationale**:
- Bitcoin-PoCX variabele deadline-timing is minder tijdkritisch dan fixed-timing consensus
- 15s biedt adequate bescherming terwijl netwerkfragmentatie wordt voorkomen

**Afwegingen**:
- Striktere tolerantie = meer netwerkfragmentatie door kleine verschuiving
- Losser tolerantie = meer mogelijkheid voor timingaanvallen
- 15s balanceert beveiliging en robuustheid

### Waarom 10-seconden waarschuwing?

**Redenering**:
- Biedt 5-seconden veiligheidsbuffer
- Passender voor PoC dan Bitcoin's standaard van 10 minuten
- Staat proactieve reparaties toe voor kritieke fout

### Waarom defensief forgen?

**Aangepakt probleem**:
- 15-seconden tolerantie maakt snelle-klokvoordeel mogelijk
- Kwaliteitsgebaseerde consensus kon worden ondermijnd door timingmanipulatie

**Oplossingsvoordelen**:
- Kostenloze verdediging (geen consensuswijzigingen)
- Automatische werking
- Elimineert aanvalsprikkel
- Behoudt proof-of-capacity-principes

### Waarom geen intra-netwerk tijdsynchronisatie?

**Beveiligingsredenering**:
- Moderne Bitcoin Core verwijderde peer-gebaseerde tijdaanpassing
- Kwetsbaar voor Sybil-aanvallen op waargenomen netwerktijd
- PoCX vermijdt opzettelijk vertrouwen op netwerk-interne tijdbronnen
- Systeemklok is betrouwbaarder dan peerconsensus
- Operators moeten synchroniseren met NTP of equivalente externe tijdbron
- Nodes monitoren hun eigen verschuiving en geven waarschuwingen als lokale klok afwijkt van recente bloktijdstempels

---

## Implementatiereferenties

**Kernbestanden**:
- Tijdvalidatie: `src/validation.cpp:4547-4561`
- Toekomsttolerantieconstante: `src/chain.h:31`
- Waarschuwingsdrempel: `src/node/timeoffsets.h:27`
- Tijdsverschuivingsmonitoring: `src/node/timeoffsets.cpp`
- Defensief forgen: `src/pocx/mining/scheduler.cpp`

**Gerelateerde documentatie**:
- Time Bending-algoritme: [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md#time-bending-berekening)
- Blokvalidatie: [Hoofdstuk 3: Blokvalidatie](3-consensus-and-mining.md#blokvalidatie)

---

**Gegenereerd**: 10-10-2025
**Status**: Volledige implementatie
**Dekking**: Tijdsynchronisatievereisten, klokverschuivingsafhandeling, defensief forgen

---

[Vorige: Forging-toewijzingen](4-forging-assignments.md) | [Inhoudsopgave](index.md) | [Volgende: Netwerkparameters](6-network-parameters.md)

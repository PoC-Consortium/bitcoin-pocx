[← Ankstesnis: Kalimo priskyrimai](4-forging-assignments.md) | [📘 Turinys](index.md) | [Toliau: Tinklo parametrai →](6-network-parameters.md)

---

# 5 skyrius: Laiko sinchronizacija ir saugumas

## Apžvalga

PoCX konsensusas reikalauja tikslios laiko sinchronizacijos visame tinkle. Šis skyrius dokumentuoja su laiku susijusius saugumo mechanizmus, laikrodžio nuokrypio toleranciją ir gynybinio kalimo elgesį.

**Pagrindiniai mechanizmai**:
- 15 sekundžių ateities tolerancija blokų laikų žymėms
- 10 sekundžių laikrodžio nuokrypio įspėjimo sistema
- Gynybinis kalimas (apsauga nuo laikrodžio manipuliavimo)
- Laiko lenkimo algoritmo integracija

---

## Turinys

1. [Laiko sinchronizacijos reikalavimai](#laiko-sinchronizacijos-reikalavimai)
2. [Laikrodžio nuokrypio aptikimas ir įspėjimai](#laikrodžio-nuokrypio-aptikimas-ir-įspėjimai)
3. [Gynybinio kalimo mechanizmas](#gynybinio-kalimo-mechanizmas)
4. [Saugumo grėsmių analizė](#saugumo-grėsmių-analizė)
5. [Geriausia praktika mazgų operatoriams](#geriausia-praktika-mazgų-operatoriams)

---

## Laiko sinchronizacijos reikalavimai

### Konstantos ir parametrai

**Bitcoin-PoCX konfigūracija:**
```cpp
// src/chain.h
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekundžių

// src/node/timeoffsets.h
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekundžių
```

### Validacijos tikrinimai

**Bloko laiko žymės validacija** (`src/validation.cpp:ContextualCheckBlockHeader()`):
```cpp
// 1. Monotoninė patikra: laiko žymė >= ankstesnio bloko laiko žymė
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Ateities patikra: laiko žymė <= dabar + 15 sekundžių
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Termino patikra: praėjęs laikas >= terminas
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (poc_time > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Laikrodžio nuokrypio poveikio lentelė

| Laikrodžio poslinkis | Gali sinchronizuoti? | Gali kasti? | Validacijos būsena | Konkurencinis poveikis |
|---------------------|---------------------|-------------|-------------------|----------------------|
| -30s lėtai | ❌ NE - Ateities patikra nepavyksta | N/A | **NEGYVAS MAZGAS** | Negali dalyvauti |
| -14s lėtai | ✅ Taip | ✅ Taip | Vėlyvas kalimas, praeina validaciją | Pralaimi lenktynes |
| 0s tobulas | ✅ Taip | ✅ Taip | Optimalus | Optimalus |
| +14s greitai | ✅ Taip | ✅ Taip | Ankstyvas kalimas, praeina validaciją | Laimi lenktynes ⚠️ |
| +16s greitai | ✅ Taip | ❌ Ateities patikra nepavyksta | Negali platinti blokų | Gali sinchronizuoti, negali kasti |

**Pagrindinė įžvalga**: 15 sekundžių langas yra simetriškas dalyvavimui (±14.9s), bet greiti laikrodžiai suteikia nesąžiningą konkurencinį pranašumą tolerancijos ribose.

### Laiko lenkimo integracija

Laiko lenkimo algoritmas (detaliai aprašytas [3 skyriuje](3-consensus-and-mining.md#laiko-lenkimo-skaičiavimas)) transformuoja neapdorotus terminus naudojant kubinę šaknį:

```
laiko_lenktas_terminas = skalė × (termino_sekundės)^(1/3)
```

**Sąveika su laikrodžio nuokrypiu**:
- Geresni sprendimai kalami greičiau (kubinė šaknis sustiprina kokybės skirtumus)
- Laikrodžio nuokrypis veikia kalimo laiką santykiu su tinklu
- Gynybinis kalimas užtikrina kokybe pagrįstą konkurenciją nepaisant laiko dispersijos

---

## Laikrodžio nuokrypio aptikimas ir įspėjimai

### Įspėjimo sistema

Bitcoin-PoCX stebi laiko poslinkį tarp lokalaus mazgo ir tinklo kolegų.

**Įspėjimo pranešimas** (kai nuokrypis viršija 10 sekundžių):
> "Jūsų kompiuterio data ir laikas atrodo daugiau nei 10 sekundžių nesinchronizuoti su tinklu, tai gali sukelti PoCX konsensuso nesėkmę. Prašome patikrinti sistemos laikrodį."

**Įgyvendinimas**: `src/node/timeoffsets.cpp`

### Projektavimo pagrindimas

**Kodėl 10 sekundžių?**
- Suteikia 5 sekundžių saugumo buferį prieš 15 sekundžių tolerancijos ribą
- Griežčiau nei Bitcoin Core numatytoji reikšmė (10 minučių)
- Tinkama PoC laiko reikalavimams

**Prevencinis metodas**:
- Ankstyvasis įspėjimas prieš kritinę nesėkmę
- Leidžia operatoriams proaktyviai taisyti problemas
- Sumažina tinklo fragmentaciją dėl su laiku susijusių nesėkmių

---

## Gynybinio kalimo mechanizmas

### Kas tai yra

Gynybinis kalimas yra standartinis kasėjo elgesys Bitcoin-PoCX, kuris pašalina laiko pagrįstus pranašumus blokų gamyboje. Kai jūsų kasėjas gauna konkuruojantį bloką tame pačiame aukštyje, jis automatiškai patikrina ar jūs turite geresnį sprendimą. Jei taip, jis iš karto nukala jūsų bloką, užtikrinant kokybe pagrįstą konkurenciją, o ne laikrodžio manipuliavimo pagrįstą konkurenciją.

### Problema

PoCX konsensusas leidžia blokus su laiko žymėmis iki 15 sekundžių ateityje. Ši tolerancija būtina globaliam tinklo sinchronizavimui. Tačiau tai sukuria galimybę laikrodžio manipuliavimui:

**Be gynybinio kalimo:**
- Kasėjas A: Teisingas laikas, kokybė 800 (geresnė), laukia tinkamo termino
- Kasėjas B: Greitas laikrodis (+14s), kokybė 1000 (blogesnė), nukala 14 sekundžių anksčiau
- Rezultatas: Kasėjas B laimi lenktynes nepaisant blogesnio talpos įrodymo darbo

**Problema:** Laikrodžio manipuliavimas suteikia pranašumą net su blogesne kokybe, pakenkiant talpos įrodymo principui.

### Sprendimas: Dviejų sluoksnių gynyba

#### 1 sluoksnis: Laikrodžio nuokrypio įspėjimas (prevencinis)

Bitcoin-PoCX stebi laiko poslinkį tarp jūsų mazgo ir tinklo kolegų. Jei jūsų laikrodis nukrypsta daugiau nei 10 sekundžių nuo tinklo konsensuso, gaunate įspėjimą, perspėjantį taisyti laikrodžio problemas prieš jas sukeliant problemas.

#### 2 sluoksnis: Gynybinis kalimas (reaktyvus)

Kai kitas kasėjas publikuoja bloką tame pačiame aukštyje, kurį jūs kasite:

1. **Aptikimas**: Jūsų mazgas identifikuoja to paties aukščio konkurenciją
2. **Validacija**: Išgauna ir validuoja konkuruojančio bloko kokybę
3. **Palyginimas**: Patikrina ar jūsų kokybė geresnė
4. **Atsakymas**: Jei geresnė, nukala jūsų bloką iš karto

**Rezultatas:** Tinklas gauna abu blokus ir pasirenka geresnės kokybės per standartinį šakos sprendimą.

### Kaip tai veikia

#### Scenarijus: To paties aukščio konkurencija

```
Laikas 150s: Kasėjas B (laikrodis +10s) nukala su kokybe 1000
           → Bloko laiko žymė rodo 160s (10s ateityje)

Laikas 150s: Jūsų mazgas gauna kasėjo B bloką
           → Aptinka: tas pats aukštis, kokybė 1000
           → Jūs turite: kokybę 800 (geresnė!)
           → Veiksmas: Nukala iš karto su teisinga laiko žyme (150s)

Laikas 152s: Tinklas validuoja abu blokus
           → Abu galioja (15s tolerancijos ribose)
           → Kokybė 800 laimi (mažesnė = geresnė)
           → Jūsų blokas tampa grandinės viršūne
```

#### Scenarijus: Tikra reorganizacija

```
Jūsų kasimo aukštis 100, konkurentas publikuoja bloką 99
→ Ne to paties aukščio konkurencija
→ Gynybinis kalimas NESUŽADINAMAS
→ Normalus reorg tvarkymas tęsiasi
```

### Privalumai

**Nulis paskatų laikrodžio manipuliavimui**
- Greiti laikrodžiai padeda tik jei jau turite geriausią kokybę
- Laikrodžio manipuliavimas tampa ekonomiškai beprasmis

**Kokybe pagrįsta konkurencija užtikrinta**
- Priverčia kasėjus konkuruoti tikru talpos įrodymo darbu
- Išsaugo PoCX konsensuso vientisumą

**Tinklo saugumas**
- Atsparus laiko pagrįstoms žaidimo strategijoms
- Nereikia konsensuso pakeitimų - grynai kasėjo elgesys

**Pilnai automatinis**
- Nereikia konfigūracijos
- Sužadinamas tik kai būtina
- Standartinis elgesys visuose Bitcoin-PoCX mazguose

### Kompromisai

**Minimalus našlaičių blokų padidėjimas**
- Tyčinis - atakų blokai tampa našlaičiais
- Įvyksta tik faktinių laikrodžio manipuliavimo bandymų metu
- Natūralus kokybe pagrįsto šakos sprendimo rezultatas

**Trumpa tinklo konkurencija**
- Tinklas trumpam mato du konkuruojančius blokus
- Išsprendžiama per sekundes per standartinę validaciją
- Tas pats elgesys kaip vienu metu kasant Bitcoin

### Techninės detalės

**Našumo poveikis:** Nereikšmingas
- Sužadinamas tik to paties aukščio konkurencijos metu
- Naudoja atmintyje esančius duomenis (jokių disko I/O)
- Validacija baigiasi per milisekundes

**Išteklių naudojimas:** Minimalus
- Compact implementation in `scheduler.cpp` and `defensive_forge.cpp`
- Pakartotinai naudoja esamą validacijos infrastruktūrą
- Vienas užrakto gavimas

**Suderinamumas:** Pilnas
- Jokių konsensuso taisyklių pakeitimų
- Veikia su visomis Bitcoin Core funkcijomis
- Neprivalomas stebėjimas per derinimo žurnalus

**Būsena**: Aktyvi visuose Bitcoin-PoCX leidimuose
**Pirmą kartą pristatytas**: 2025-10-10

---

## Saugumo grėsmių analizė

### Greito laikrodžio ataka (sušvelninta gynybiniu kalimu)

**Atakos vektorius**:
Kasėjas su laikrodžiu **+14s į priekį** gali:
1. Gauti blokus normaliai (atrodo seni jam)
2. Kalti blokus iš karto kai terminas praeina
3. Transliuoti blokus, kurie atrodo 14s "anksčiau" tinklui
4. **Blokai priimami** (15s tolerancijos ribose)
5. **Laimi lenktynes** prieš sąžiningus kasėjus

**Poveikis be gynybinio kalimo**:
Pranašumas ribotas iki 14.9 sekundžių (neužtenka praleisti reikšmingo PoC darbo), bet suteikia nuoseklų pranašumą blokų lenktynėse.

**Sušvelninimas (gynybinis kalimas)**:
- Sąžiningi kasėjai aptinka to paties aukščio konkurenciją
- Palygina kokybės reikšmes
- Iš karto nukala jei kokybė geresnė
- **Rezultatas**: Greitas laikrodis padeda tik jei jau turi geriausią kokybę
- **Paskata**: Nulis - laikrodžio manipuliavimas tampa ekonomiškai beprasmis

### Lėto laikrodžio nesėkmė (kritinė)

**Nesėkmės režimas**:
Mazgas **>15s atsiliekantis** yra katastrofiškas:
- Negali validuoti gaunamų blokų (ateities patikra nepavyksta)
- Tampa izoliuotas nuo tinklo
- Negali kasti ar sinchronizuoti

**Sušvelninimas**:
- Stiprus įspėjimas ties 10s nuokrypiu suteikia 5 sekundžių buferį prieš kritinę nesėkmę
- Operatoriai gali proaktyviai taisyti laikrodžio problemas
- Aiškūs klaidų pranešimai vadovauja trikčių šalinimui

---

## Geriausia praktika mazgų operatoriams

### Laiko sinchronizacijos nustatymas

**Rekomenduojama konfigūracija**:
1. **Įjungti NTP**: Naudoti tinklo laiko protokolą automatiniam sinchronizavimui
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Patikrinti būseną
   timedatectl status
   ```

2. **Patikrinti laikrodžio tikslumą**: Reguliariai tikrinti laiko poslinkį
   ```bash
   # Patikrinti NTP sinchronizacijos būseną
   ntpq -p

   # Arba su chrony
   chronyc tracking
   ```

3. **Stebėti įspėjimus**: Sekti Bitcoin-PoCX laikrodžio nuokrypio įspėjimus žurnaluose

### Kasėjams

**Jokių veiksmų nereikia**:
- Funkcija visada aktyvi
- Veikia automatiškai
- Tiesiog laikykite sistemos laikrodį tikslų

**Geriausia praktika**:
- Naudoti NTP laiko sinchronizaciją
- Stebėti laikrodžio nuokrypio įspėjimus
- Greitai reaguoti į įspėjimus jei jie pasirodo

**Tikėtinas elgesys**:
- Solo kasimas: Gynybinis kalimas retai sužadinamas (nėra konkurencijos)
- Tinklo kasimas: Apsaugo nuo laikrodžio manipuliavimo bandymų
- Skaidrus veikimas: Dauguma kasėjų niekada to nepastebi

### Trikčių šalinimas

**Įspėjimas: "10 sekundžių nesinchronizuota"**
- Veiksmas: Patikrinti ir ištaisyti sistemos laikrodžio sinchronizaciją
- Poveikis: 5 sekundžių buferis prieš kritinę nesėkmę
- Įrankiai: NTP, chrony, systemd-timesyncd

**Klaida: "time-too-new" gaunamuose blokuose**
- Priežastis: Jūsų laikrodis >15 sekundžių lėtesnis
- Poveikis: Negali validuoti blokų, mazgas izoliuotas
- Pataisymas: Iš karto sinchronizuoti sistemos laikrodį

**Klaida: Negali platinti nukaltų blokų**
- Priežastis: Jūsų laikrodis >15 sekundžių greitesnis
- Poveikis: Blokai atmetami tinklo
- Pataisymas: Iš karto sinchronizuoti sistemos laikrodį

---

## Projektavimo sprendimai ir pagrindimas

### Kodėl 15 sekundžių tolerancija?

**Pagrindimas**:
- Bitcoin-PoCX kintamas termino laikymas yra mažiau laiko kritiškas nei fiksuoto laiko konsensusas
- 15s suteikia adekvačią apsaugą kartu apsaugodamas nuo tinklo fragmentacijos

**Kompromisai**:
- Griežtesnė tolerancija = daugiau tinklo fragmentacijos nuo nedidelio nuokrypio
- Laisvesnė tolerancija = daugiau galimybių laiko atakoms
- 15s balansuoja saugumą ir tvirtumą

### Kodėl 10 sekundžių įspėjimas?

**Argumentacija**:
- Suteikia 5 sekundžių saugumo buferį
- Tinkamesnė PoC nei Bitcoin 10 minučių numatytoji reikšmė
- Leidžia proaktyvius pataisymus prieš kritinę nesėkmę

### Kodėl gynybinis kalimas?

**Sprendžiama problema**:
- 15 sekundžių tolerancija įgalina greito laikrodžio pranašumą
- Kokybe pagrįstas konsensusas galėtų būti pakenktas laiko manipuliavimu

**Sprendimo privalumai**:
- Nulinių kaštų gynyba (jokių konsensuso pakeitimų)
- Automatinis veikimas
- Pašalina atakos paskatą
- Išsaugo talpos įrodymo principus

### Kodėl nėra tinklo vidaus laiko sinchronizacijos?

**Saugumo argumentacija**:
- Šiuolaikinis Bitcoin Core pašalino kolegomis pagrįstą laiko koregavimą
- Pažeidžiamas Sybil atakomis prieš suvokiamą tinklo laiką
- PoCX tyčia vengia priklausomybės nuo tinklo vidaus laiko šaltinių
- Sistemos laikrodis patikimesnis nei kolegų konsensusas
- Operatoriai turėtų sinchronizuoti naudodami NTP ar lygiavertį išorinį laiko šaltinį
- Mazgai stebi savo nuokrypį ir išleidžia įspėjimus jei lokalus laikrodis nukrypsta nuo paskutinių blokų laiko žymių

---

## Įgyvendinimo nuorodos

**Pagrindiniai failai**:
- Laiko validacija: `src/validation.cpp:ContextualCheckBlockHeader()`
- Ateities tolerancijos konstanta: `src/chain.h`
- Įspėjimo riba: `src/node/timeoffsets.h`
- Laiko poslinkio stebėjimas: `src/node/timeoffsets.cpp`
- Gynybinis kalimas: `src/pocx/mining/scheduler.cpp`

**Susijusi dokumentacija**:
- Laiko lenkimo algoritmas: [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md#laiko-lenkimo-skaičiavimas)
- Bloko validacija: [3 skyrius: Bloko validacija](3-consensus-and-mining.md#bloko-validacija)

---

**Sugeneruota**: 2025-10-10
**Būsena**: Pilnas įgyvendinimas
**Aprėptis**: Laiko sinchronizacijos reikalavimai, laikrodžio nuokrypio tvarkymas, gynybinis kalimas

---

[← Ankstesnis: Kalimo priskyrimai](4-forging-assignments.md) | [📘 Turinys](index.md) | [Toliau: Tinklo parametrai →](6-network-parameters.md)

[📘 Turinys](index.md) | [Toliau: Grafiko formatas →](2-plot-format.md)

---

# 1 skyrius: Įvadas ir apžvalga

## Kas yra Bitcoin-PoCX?

Bitcoin-PoCX yra Bitcoin Core integracija, pridedanti **Proof of Capacity neXt generation (PoCX)** konsensuso palaikymą. Ji išlaiko esamą Bitcoin Core architektūrą, kartu įgalindama energiją taupančią Proof of Capacity kasimo alternatyvą kaip visišką Proof of Work pakaitą.

**Pagrindinis skirtumas**: Tai yra **nauja grandinė** be atgalinio suderinamumo su Bitcoin PoW. PoCX blokai pagal projektą nesuderinami su PoW mazgais.

---

## Projekto tapatybė

- **Organizacija**: Proof of Capacity Consortium
- **Projekto pavadinimas**: Bitcoin-PoCX
- **Pilnas pavadinimas**: Bitcoin Core su PoCX integracija
- **Būsena**: Pagrindinis tinklas veikia (nuo 2026 m. gegužės 3 d.)

---

## Kas yra Proof of Capacity?

Proof of Capacity (PoC) yra konsensuso mechanizmas, kuriame kasimo galia proporcinga **disko vietai**, o ne skaičiavimo galiai. Kasėjai iš anksto generuoja didelius grafiko failus, kuriuose yra kriptografiniai maišos kodai, tada naudoja šiuos grafikus galimiems bloko sprendimams rasti.

**Energijos efektyvumas**: Grafiko failai generuojami vieną kartą ir naudojami neribotą laiką. Kasimas sunaudoja minimaliai procesoriaus galios - daugiausia disko I/O.

**PoCX patobulinimai**:
- Ištaisyta XOR-transpozicijos suspaudimo ataka (50% laiko-atminties kompromisas POC2)
- 16-nonce sulygiuotas išdėstymas šiuolaikinei aparatinei įrangai
- Keičiamas darbo įrodymas grafiko generavime (Xn mastelio lygiai)
- Natūrali C++ integracija tiesiai į Bitcoin Core
- Laiko lenkimo algoritmas patobulintam bloko laiko pasiskirstymui

---

## Architektūros apžvalga

### Saugyklos struktūra

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.2 + PoCX integracija
│   └── src/pocx/        # PoCX įgyvendinimas
├── pocx/                # PoCX pagrindinis karkasas (submodulis, tik skaitymui)
└── docs/                # Ši dokumentacija
```

### Integracijos filosofija

**Minimali integracijos aplinka**: Pakeitimai izoliuoti `/src/pocx/` kataloge su švariomis jungtimis į Bitcoin Core validacijos, kasimo ir RPC sluoksnius.

**Funkcijų žymėjimas**: Visi pakeitimai pažymėti `#ifdef ENABLE_POCX` preprocesoriaus sargybiniais. Bitcoin Core kompiliuojasi normaliai, kai išjungta.

**Suderinamumas su pirminiu kodu**: Reguliarus sinchronizavimas su Bitcoin Core atnaujinimais palaikomas per izoliuotus integracijos taškus.

**Natūralus C++ įgyvendinimas**: Skalariniai kriptografiniai algoritmai (Shabal256, scoop skaičiavimas, suspaudimas) integruoti tiesiai į Bitcoin Core konsensuso validacijai.

---

## Pagrindinės funkcijos

### 1. Pilnas konsensuso pakeitimas

- **Bloko struktūra**: PoCX specifiniai laukai pakeičia PoW nonce ir sudėtingumo bitus
  - Generavimo parašas (deterministinė kasimo entropija)
  - Bazinis tikslas (sudėtingumo atvirkštinė reikšmė)
  - PoCX įrodymas (paskyros ID, sėkla, nonce)
  - Bloko parašas (įrodo grafiko nuosavybę)

- **Validacija**: 5 etapų validacijos konvejeris nuo antraštės patikros iki bloko prijungimo

- **Sudėtingumo koregavimas**: Koregavimas kiekviename bloke naudojant paskutinių bazinių tikslų slenkantį vidurkį

### 2. Laiko lenkimo algoritmas

**Problema**: Tradiciniai PoC bloko laikai seka eksponentinį pasiskirstymą, sukeliantį ilgus blokus, kai joks kasėjas neranda gero sprendimo.

**Sprendimas**: Pasiskirstymo transformacija iš eksponentinio į chi-kvadratinį naudojant kubinę šaknį: `Y = skalė × (X^(1/3))`.

**Poveikis**: Extremely fast blocks are delayed and extremely slow blocks are shortened, reducing variance while preserving average block time at 120 seconds.

**Detalės**: [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md)

### 3. Kalimo priskyrimo sistema

**Galimybė**: Grafiko savininkai gali deleguoti kalimo teises kitiems adresams, išlaikydami grafiko nuosavybę.

**Naudojimo atvejai**:
- Baseinų kasimas (grafikai priskirti baseino adresui)
- Šaltoji saugykla (kasimo raktas atskirtas nuo grafiko nuosavybės)
- Daugiašalis kasimas (bendra infrastruktūra)

**Architektūra**: Tik OP_RETURN dizainas - jokių specialių UTXO, priskyrimai sekamas atskirai chainstate duomenų bazėje.

**Detalės**: [4 skyrius: Kalimo priskyrimai](4-forging-assignments.md)

### 4. Gynybinis kalimas

**Problema**: Greiti laikrodžiai galėtų suteikti laiko pranašumą 15 sekundžių ateities tolerancijos ribose.

**Sprendimas**: Gavus konkuruojantį bloką tame pačiame aukštyje, automatiškai tikrinama vietinė kokybė. Jei geresnė, kalama iš karto.

**Poveikis**: Pašalina paskatą laikrodžio manipuliavimui - greiti laikrodžiai padeda tik jei jau turite geriausią sprendimą.

**Detalės**: [5 skyrius: Laiko sinchronizacija](5-timing-security.md)

### 5. Dinaminis suspaudimo mastelio keitimas

**Ekonominis suderinimas**: Mastelio lygio reikalavimai didėja eksponentiškai (4, 12, 28, 60, 124 metai = pusės 1, 3, 7, 15, 31).

**Poveikis**: Mažėjant bloko atlyginimu, grafiko generavimo sudėtingumas didėja. Išlaiko saugumo ribą tarp grafiko kūrimo ir paieškos kaštų.

**Apsaugo**: Nuo talpos infliacijos dėl greitesnės aparatinės įrangos laikui bėgant.

**Detalės**: [6 skyrius: Tinklo parametrai](6-network-parameters.md)

---

## Projektavimo filosofija

### Kodo saugumas

- Gynybinio programavimo praktikos visame kode
- Išsamus klaidų tvarkymas validacijos keliuose
- Jokių įdėtų užraktų (aklavietės prevencija)
- Atominės duomenų bazės operacijos (UTXO + priskyrimai kartu)

### Modulinė architektūra

- Švarus atskyrimas tarp Bitcoin Core infrastruktūros ir PoCX konsensuso
- PoCX pagrindinis karkasas teikia kriptografinius primityvus
- Bitcoin Core teikia validacijos karkasą, duomenų bazę, tinklaveiką

### Našumo optimizacijos

- Greito atmetimo validacijos tvarka (pigios patikros pirma)
- Vienas konteksto gavimas kiekvienam pateikimui (be pakartotinių cs_main užgrobimų)
- Atominės duomenų bazės operacijos nuoseklumui

### Reorganizacijos saugumas

- Pilni atšaukimo duomenys priskyrimo būsenos pakeitimams
- Kalimo būsenos atstatymas pasikeitus grandinės viršūnei
- Pasenimo aptikimas visuose validacijos taškuose

---

## Kuo PoCX skiriasi nuo Proof of Work

| Aspektas | Bitcoin (PoW) | Bitcoin-PoCX |
|----------|---------------|--------------|
| **Kasimo išteklius** | Skaičiavimo galia (maišos greitis) | Disko vieta (talpa) |
| **Energijos suvartojimas** | Didelis (nuolatinis maišymas) | Mažas (tik disko I/O) |
| **Kasimo procesas** | Rasti nonce su maišos kodu < tikslas | Rasti nonce su terminu < praėjęs laikas |
| **Sudėtingumas** | `bits` laukas, koreguojamas kas 2016 blokų | `base_target` laukas, koreguojamas kiekviename bloke |
| **Bloko laikas** | ~10 minučių (eksponentinis pasiskirstymas) | 120 sekundžių (laiko lenkimas, sumažinta dispersija) |
| **Subsidija** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Aparatinė įranga** | ASIC (specializuota) | HDD (įprastinė aparatinė įranga) |
| **Kasimo tapatybė** | Anoniminė | Grafiko savininkas arba įgaliotinis |

---

## Sistemos reikalavimai

### Mazgo veikimas

**Tokie pat kaip Bitcoin Core**:
- **Procesorius**: Šiuolaikinis x86_64 procesorius
- **Atmintis**: 4-8 GB RAM
- **Saugykla**: Nauja grandinė, šiuo metu tuščia (gali augti ~5× greičiau nei Bitcoin dėl 2 minučių blokų ir priskyrimo duomenų bazės)
- **Tinklas**: Stabilus interneto ryšys
- **Laikrodis**: Rekomenduojama NTP sinchronizacija optimaliam veikimui

**Pastaba**: Grafiko failai NĖRA reikalingi mazgo veikimui.

### Kasimo reikalavimai

**Papildomi reikalavimai kasimui**:
- **Grafiko failai**: Iš anksto sugeneruoti naudojant `pocx_plotter` (referencinis įgyvendinimas)
- **Kasėjo programinė įranga**: `pocx_miner` (referencinis įgyvendinimas) jungiasi per RPC
- **Piniginė**: `bitcoind` arba `bitcoin-qt` su privačiais raktais kasimo adresui. Baseinų kasimui nereikia vietinės piniginės.

---

## Pradžia

### 1. Kompiliuoti Bitcoin-PoCX

```bash
# Klonuoti su submoduliais
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build
cmake -B build
cmake --build build
```

**Details**: See `bitcoin/doc/build-*.md` for platform-specific build instructions

### 2. Paleisti mazgą

**Tik mazgas**:
```bash
./build/bin/bitcoind
# arba
./build/bin/bitcoin-qt
```

**Kasimui** (įjungia RPC prieigą išoriniams kasėjams):
```bash
./build/bin/bitcoind
# arba
./build/bin/bitcoin-qt -server
```

**Detalės**: [6 skyrius: Tinklo parametrai](6-network-parameters.md)

### 3. Generuoti grafiko failus

Naudokite `pocx_plotter` (referencinis įgyvendinimas) PoCX formato grafiko failams generuoti.

**Detalės**: [2 skyrius: Grafiko formatas](2-plot-format.md)

### 4. Nustatyti kasimą

Naudokite `pocx_miner` (referencinis įgyvendinimas) prisijungimui prie jūsų mazgo RPC sąsajos.

**Detalės**: [7 skyrius: RPC informacija](7-rpc-reference.md) ir [8 skyrius: Piniginės vadovas](8-wallet-guide.md)

---

## Autorystė

### Grafiko formatas

Paremtas POC2 formatu (Burstcoin) su patobulinimais:
- Ištaisyta saugumo spraga (XOR-transpozicijos suspaudimo ataka)
- Keičiamas darbo įrodymas
- SIMD optimizuotas išdėstymas
- Sėklos funkcionalumas

### Pirminiai projektai

- **pocx_miner**: Referencinis įgyvendinimas paremtas [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referencinis įgyvendinimas paremtas [engraver](https://github.com/PoC-Consortium/engraver)

**Pilna autorystė**: [2 skyrius: Grafiko formatas](2-plot-format.md)

---

## Techninių specifikacijų santrauka

- **Bloko laikas**: 120 sekundžių (pagrindinis tinklas), 1 sekundė (regtest)
- **Bloko subsidija**: 10 BTC pradinė, perpus mažėja kas 1050000 blokų (~4 metai)
- **Bendra pasiūla**: ~21 milijonų BTC (kaip Bitcoin)
- **Ateities tolerancija**: 15 sekundžių (blokai iki 15s į priekį priimami)
- **Laikrodžio įspėjimas**: 10 sekundžių (įspėja operatorius apie laiko nuokrypį)
- **Priskyrimo atidėjimas**: 30 blokų (~1 valanda)
- **Atšaukimo atidėjimas**: 720 blokų (~24 valandos)
- **Adreso formatas**: P2WPKH (bech32, pocx1q...) tik PoCX kasimo operacijoms ir kalimo priskyrimams

---

## Kodo organizacija

**Bitcoin Core pakeitimai**: Minimalūs pakeitimai pagrindiniuose failuose, pažymėti su `#ifdef ENABLE_POCX`

**Naujas PoCX įgyvendinimas**: Izoliuotas `src/pocx/` kataloge

---

## Saugumo svarstybos

### Laiko saugumas

- 15 sekundžių ateities tolerancija apsaugo nuo tinklo fragmentacijos
- 10 sekundžių įspėjimo riba informuoja operatorius apie laikrodžio nuokrypį
- Gynybinis kalimas pašalina paskatą laikrodžio manipuliavimui
- Laiko lenkimas sumažina laiko dispersijos poveikį

**Detalės**: [5 skyrius: Laiko sinchronizacija](5-timing-security.md)

### Priskyrimo saugumas

- Tik OP_RETURN dizainas (jokio UTXO manipuliavimo)
- Transakcijos parašas įrodo grafiko nuosavybę
- Aktyvacijos atidėjimai apsaugo nuo greito būsenos manipuliavimo
- Reorganizacijoms saugūs atšaukimo duomenys visiems būsenos pakeitimams

**Detalės**: [4 skyrius: Kalimo priskyrimai](4-forging-assignments.md)

### Konsensuso saugumas

- Parašas neįtrauktas į bloko maišos kodą (apsaugo nuo kintamumo)
- Riboti parašų dydžiai (apsaugo nuo DoS)
- Suspaudimo ribų validacija (apsaugo nuo silpnų įrodymų)
- Sudėtingumo koregavimas kiekviename bloke (reaguoja į talpos pokyčius)

**Detalės**: [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md)

---

## Tinklo būsena

**Pagrindinis tinklas**: Veikia (nuo 2026 m. gegužės 3 d.)
**Testinis tinklas**: Prieinamas testavimui
**Regtest**: Pilnai funkcionalus kūrimui

**Pradinio bloko parametrai**: [6 skyrius: Tinklo parametrai](6-network-parameters.md)

---

## Kiti žingsniai

**PoCX supratimui**: Tęskite su [2 skyriumi: Grafiko formatas](2-plot-format.md) kad sužinotumėte apie grafiko failų struktūrą ir formato evoliuciją.

**Kasimo nustatymui**: Pereikite prie [7 skyriaus: RPC informacija](7-rpc-reference.md) integracijos detalėms.

**Mazgo valdymui**: Peržiūrėkite [6 skyrių: Tinklo parametrai](6-network-parameters.md) konfigūracijos parinkčių.

---

[📘 Turinys](index.md) | [Toliau: Grafiko formatas →](2-plot-format.md)

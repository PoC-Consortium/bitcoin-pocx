[📘 Satura rādītājs](index.md) | [Nākamā: Plotfaila formāts →](2-plot-format.md)

---

# 1. nodaļa: Ievads un pārskats

## Kas ir Bitcoin-PoCX?

Bitcoin-PoCX ir Bitcoin Core integrācija, kas pievieno **jaunās paaudzes jaudas pierādījuma (PoCX — Proof of Capacity neXt generation)** konsensa atbalstu. Tā saglabā Bitcoin Core esošo arhitektūru, vienlaikus nodrošinot energoefektīvu jaudas pierādījuma kalnrūpniecības alternatīvu kā pilnīgu darba pierādījuma aizstājēju.

**Galvenā atšķirība**: Šī ir **jauna ķēde** bez atpakaļejošas saderības ar Bitcoin PoW. PoCX bloki pēc dizaina nav saderīgi ar PoW mezgliem.

---

## Projekta identitāte

- **Organizācija**: Proof of Capacity Consortium
- **Projekta nosaukums**: Bitcoin-PoCX
- **Pilns nosaukums**: Bitcoin Core ar PoCX integrāciju
- **Statuss**: Testnet fāze

---

## Kas ir jaudas pierādījums?

Jaudas pierādījums (PoC — Proof of Capacity) ir konsensa mehānisms, kurā kalnrūpniecības jauda ir proporcionāla **diska vietai**, nevis skaitļošanas jaudai. Kalnrači iepriekš ģenerē lielus plotfailus, kas satur kriptogrāfiskās jaucējvērtības, pēc tam izmanto šos plotfailus, lai atrastu derīgus bloku risinājumus.

**Energoefektivitāte**: Plotfaili tiek ģenerēti vienreiz un atkārtoti izmantoti bezgalīgi. Kalnrūpniecība patērē minimālu CPU jaudu — galvenokārt diska I/O.

**PoCX uzlabojumi**:
- Novērsts XOR-transpozīcijas kompresijas uzbrukums (50% laika-atmiņas kompromiss POC2)
- 16 noncu izlīdzināts izkārtojums modernai aparatūrai
- Mērogojams darba pierādījums plotfailu ģenerēšanā (Xn mērogošanas līmeņi)
- Vietēja C++ integrācija tieši Bitcoin Core
- Laika līkumo algoritms uzlabotai bloku laika sadalei

---

## Arhitektūras pārskats

### Repozitorija struktūra

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX integrācija
│   └── src/pocx/        # PoCX implementācija
├── pocx/                # PoCX pamata ietvars (apakšmodulis, tikai lasāms)
└── docs/                # Šī dokumentācija
```

### Integrācijas filozofija

**Minimāla integrācijas virsma**: Izmaiņas izolētas `/src/pocx/` direktorijā ar tīriem āķiem Bitcoin Core validācijā, kalnrūpniecībā un RPC slāņos.

**Funkciju karodziņi**: Visas modifikācijas zem `#ifdef ENABLE_POCX` preprocesora aizsargiem. Bitcoin Core būvējas normāli, kad tie ir atspējoti.

**Augšupēja saderība**: Regulāra sinhronizācija ar Bitcoin Core atjauninājumiem tiek uzturēta caur izolētiem integrācijas punktiem.

**Vietēja C++ implementācija**: Skalāri kriptogrāfiskie algoritmi (Shabal256, scoopa aprēķins, kompresija) integrēti tieši Bitcoin Core konsensa validācijai.

---

## Galvenās funkcijas

### 1. Pilnīga konsensa aizstāšana

- **Bloka struktūra**: PoCX specifiskie lauki aizstāj PoW nonces un grūtības bitus
  - Ģenerēšanas paraksts (deterministiska kalnrūpniecības entropija)
  - Bāzes mērķis (grūtības apgrieztā vērtība)
  - PoCX pierādījums (konta ID, sēkla, nonce)
  - Bloka paraksts (pierāda plotfaila īpašumtiesības)

- **Validācija**: 5 posmu validācijas cauruļvads no galvenes pārbaudes līdz bloka savienošanai

- **Grūtības pielāgošana**: Pielāgošana katru bloku, izmantojot neseno bāzes mērķu mainīgo vidējo

### 2. Laika līkumo algoritms

**Problēma**: Tradicionālais PoC bloku laiki seko eksponenciālajam sadalījumam, kas noved pie gariem blokiem, kad neviens kalnracis neatrod labu risinājumu.

**Risinājums**: Sadalījuma transformācija no eksponenciālā uz hī-kvadrāta, izmantojot kubsakni: `Y = skala × (X^(1/3))`.

**Efekts**: Ļoti labi risinājumi tiek kalti vēlāk (tīklam ir laiks skenēt visus diskus, samazina ātrus blokus), slikti risinājumi tiek uzlaboti. Vidējais bloku laiks tiek uzturēts 120 sekundēs, garie bloki samazināti.

**Detaļas**: [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md)

### 3. Kalšanas piešķīrumu sistēma

**Iespēja**: Plotfailu īpašnieki var deleģēt kalšanas tiesības citām adresēm, saglabājot plotfailu īpašumtiesības.

**Lietošanas gadījumi**:
- Pūla kalnrūpniecība (plotfaili piešķir pūla adresei)
- Aukstā glabāšana (kalnrūpniecības atslēga atdalīta no plotfailu īpašumtiesībām)
- Daudzpušu kalnrūpniecība (dalīta infrastruktūra)

**Arhitektūra**: Tikai OP_RETURN dizains — nav speciālu UTXO, piešķīrumi tiek izsekoti atsevišķi chainstate datu bāzē.

**Detaļas**: [4. nodaļa: Kalšanas piešķīrumi](4-forging-assignments.md)

### 4. Aizsardzības kalšana

**Problēma**: Ātri pulksteņi varētu nodrošināt laika priekšrocības 15 sekunžu nākotnes tolerances ietvaros.

**Risinājums**: Saņemot konkurējošu bloku tajā pašā augstumā, automātiski pārbauda lokālo kvalitāti. Ja labāka, nekavējoties kalš.

**Efekts**: Novērš stimulu pulksteņa manipulācijai — ātri pulksteņi palīdz tikai tad, ja jums jau ir labākais risinājums.

**Detaļas**: [5. nodaļa: Laika drošība](5-timing-security.md)

### 5. Dinamiskā kompresijas mērogošana

**Ekonomiskā saskaņošana**: Mērogošanas līmeņa prasības palielinās pēc eksponenciāla grafika (4., 12., 28., 60., 124. gads = 1., 3., 7., 15., 31. dalīšana uz pusēm).

**Efekts**: Samazinoties bloku atlīdzībām, plotfailu ģenerēšanas grūtība palielinās. Uztur drošības rezervi starp plotfailu izveides un meklēšanas izmaksām.

**Novērš**: Jaudas inflāciju no ātrākas aparatūras laika gaitā.

**Detaļas**: [6. nodaļa: Tīkla parametri](6-network-parameters.md)

---

## Projektēšanas filozofija

### Koda drošība

- Aizsardzības programmēšanas prakse visur
- Visaptveroša kļūdu apstrāde validācijas ceļos
- Nav ligzdotu bloķēšanu (strupceļu novēršana)
- Atomāras datu bāzes operācijas (UTXO + piešķīrumi kopā)

### Modulāra arhitektūra

- Tīra atdalīšana starp Bitcoin Core infrastruktūru un PoCX konsensus
- PoCX pamata ietvars nodrošina kriptogrāfiskos primitīvus
- Bitcoin Core nodrošina validācijas ietvaru, datu bāzi, tīklošanu

### Veiktspējas optimizācijas

- Ātrās neveiksmes validācijas secība (lētas pārbaudes vispirms)
- Viena konteksta ielāde uz iesniegumu (nav atkārtotu cs_main iegūšanu)
- Atomāras datu bāzes operācijas konsekvencei

### Reorganizāciju drošība

- Pilni atsaukšanas dati piešķīrumu stāvokļa izmaiņām
- Kalšanas stāvokļa atiestatīšana ķēdes virsotnes izmaiņās
- Novecojušuma noteikšana visos validācijas punktos

---

## Kā PoCX atšķiras no darba pierādījuma

| Aspekts | Bitcoin (PoW) | Bitcoin-PoCX |
|---------|---------------|--------------|
| **Kalnrūpniecības resurss** | Skaitļošanas jauda (jaucējātrums) | Diska vieta (jauda) |
| **Enerģijas patēriņš** | Augsts (nepārtraukta jaukšana) | Zems (tikai diska I/O) |
| **Kalnrūpniecības process** | Atrast nonce ar jaucējvērtību < mērķis | Atrast nonce ar termiņu < pagājušais laiks |
| **Grūtība** | `bits` lauks, pielāgots ik 2016 blokus | `base_target` lauks, pielāgots katru bloku |
| **Bloka laiks** | ~10 minūtes (eksponenciālais sadalījums) | 120 sekundes (laika līkumo, samazināta dispersija) |
| **Subsīdija** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Aparatūra** | ASIC (specializēta) | HDD (standarta aparatūra) |
| **Kalnrūpniecības identitāte** | Anonīma | Plotfaila īpašnieks vai pilnvarnieks |

---

## Sistēmas prasības

### Mezgla darbība

**Tāpat kā Bitcoin Core**:
- **CPU**: Moderns x86_64 procesors
- **Atmiņa**: 4-8 GB RAM
- **Krātuve**: Jauna ķēde, pašlaik tukša (var augt ~4× ātrāk nekā Bitcoin 2 minūšu bloku un piešķīrumu datu bāzes dēļ)
- **Tīkls**: Stabils interneta savienojums
- **Pulkstenis**: NTP sinhronizācija ieteicama optimālai darbībai

**Piezīme**: Plotfaili NAV nepieciešami mezgla darbībai.

### Kalnrūpniecības prasības

**Papildu prasības kalnrūpniecībai**:
- **Plotfaili**: Iepriekš ģenerēti, izmantojot `pocx_plotter` (atsauces implementācija)
- **Kalnrūpniecības programmatūra**: `pocx_miner` (atsauces implementācija) savienojas caur RPC
- **Maciņš**: `bitcoind` vai `bitcoin-qt` ar privātajām atslēgām kalnrūpniecības adresei. Pūla kalnrūpniecībai nav nepieciešams lokāls maciņš.

---

## Darba sākšana

### 1. Būvēt Bitcoin-PoCX

```bash
# Klonēt ar apakšmoduļiem
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Būvēt ar iespējotu PoCX
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detaļas**: Skatiet `CLAUDE.md` repozitorija saknē

### 2. Palaist mezglu

**Tikai mezgls**:
```bash
./build/bin/bitcoind
# vai
./build/bin/bitcoin-qt
```

**Kalnrūpniecībai** (iespējo RPC piekļuvi ārējiem kalnračiem):
```bash
./build/bin/bitcoind -miningserver
# vai
./build/bin/bitcoin-qt -server -miningserver
```

**Detaļas**: [6. nodaļa: Tīkla parametri](6-network-parameters.md)

### 3. Ģenerēt plotfailus

Izmantojiet `pocx_plotter` (atsauces implementācija), lai ģenerētu PoCX formāta plotfailus.

**Detaļas**: [2. nodaļa: Plotfaila formāts](2-plot-format.md)

### 4. Iestatīt kalnrūpniecību

Izmantojiet `pocx_miner` (atsauces implementācija), lai savienotos ar jūsu mezgla RPC saskarni.

**Detaļas**: [7. nodaļa: RPC atsauce](7-rpc-reference.md) un [8. nodaļa: Maka ceļvedis](8-wallet-guide.md)

---

## Atsauces

### Plotfaila formāts

Balstīts uz POC2 formātu (Burstcoin) ar uzlabojumiem:
- Novērsts drošības trūkums (XOR-transpozīcijas kompresijas uzbrukums)
- Mērogojams darba pierādījums
- SIMD optimizēts izkārtojums
- Sēklas funkcionalitāte

### Avota projekti

- **pocx_miner**: Atsauces implementācija balstīta uz [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Atsauces implementācija balstīta uz [engraver](https://github.com/PoC-Consortium/engraver)

**Pilnas atsauces**: [2. nodaļa: Plotfaila formāts](2-plot-format.md)

---

## Tehnisko specifikāciju kopsavilkums

- **Bloka laiks**: 120 sekundes (mainnet), 1 sekunde (regtest)
- **Bloka subsīdija**: 10 BTC sākotnēji, dalīšana uz pusēm ik 1050000 blokus (~4 gadi)
- **Kopējais piedāvājums**: ~21 miljons BTC (tāpat kā Bitcoin)
- **Nākotnes tolerance**: 15 sekundes (bloki līdz 15s uz priekšu tiek pieņemti)
- **Pulksteņa brīdinājums**: 10 sekundes (brīdina operatorus par laika nobīdi)
- **Piešķīruma aizkave**: 30 bloki (~1 stunda)
- **Atsaukšanas aizkave**: 720 bloki (~24 stundas)
- **Adrešu formāts**: Tikai P2WPKH (bech32, pocx1q...) PoCX kalnrūpniecības operācijām un kalšanas piešķīrumiem

---

## Koda organizācija

**Bitcoin Core modifikācijas**: Minimālas izmaiņas pamata failos, iezīmētas ar funkciju karodziņiem `#ifdef ENABLE_POCX`

**Jauna PoCX implementācija**: Izolēta `src/pocx/` direktorijā

---

## Drošības apsvērumi

### Laika drošība

- 15 sekunžu nākotnes tolerance novērš tīkla fragmentāciju
- 10 sekunžu brīdinājuma slieksnis brīdina operatorus par pulksteņa nobīdi
- Aizsardzības kalšana novērš stimulu pulksteņa manipulācijai
- Laika līkumo samazina laika dispersijas ietekmi

**Detaļas**: [5. nodaļa: Laika drošība](5-timing-security.md)

### Piešķīrumu drošība

- Tikai OP_RETURN dizains (nav UTXO manipulācijas)
- Darījuma paraksts pierāda plotfaila īpašumtiesības
- Aktivizācijas aizkaves novērš ātru stāvokļa manipulāciju
- Reorganizāciju droši atsaukšanas dati visām stāvokļa izmaiņām

**Detaļas**: [4. nodaļa: Kalšanas piešķīrumi](4-forging-assignments.md)

### Konsensa drošība

- Paraksts izslēgts no bloka jaucējvērtības (novērš maināmību)
- Ierobežoti parakstu izmēri (novērš DoS)
- Kompresijas robežu validācija (novērš vājus pierādījumus)
- Grūtības pielāgošana katru bloku (reaģē uz jaudas izmaiņām)

**Detaļas**: [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md)

---

## Tīkla statuss

**Mainnet**: Vēl nav palaists
**Testnet**: Pieejams testēšanai
**Regtest**: Pilnībā funkcionāls izstrādei

**Ģenēzes bloka parametri**: [6. nodaļa: Tīkla parametri](6-network-parameters.md)

---

## Nākamie soļi

**PoCX izpratnei**: Turpiniet uz [2. nodaļu: Plotfaila formāts](2-plot-format.md), lai uzzinātu par plotfailu struktūru un formāta evolūciju.

**Kalnrūpniecības iestatīšanai**: Pārejiet uz [7. nodaļu: RPC atsauce](7-rpc-reference.md) integrācijas detaļām.

**Mezgla darbināšanai**: Pārskatiet [6. nodaļu: Tīkla parametri](6-network-parameters.md) konfigurācijas opcijām.

---

[📘 Satura rādītājs](index.md) | [Nākamā: Plotfaila formāts →](2-plot-format.md)

[← Ankstesnis: Įvadas](1-introduction.md) | [📘 Turinys](index.md) | [Toliau: Konsensusas ir kasimas →](3-consensus-and-mining.md)

---

# 2 skyrius: PoCX grafiko formato specifikacija

Šis dokumentas aprašo PoCX grafiko formatą - patobulintą POC2 formato versiją su pagerintu saugumu, SIMD optimizacijomis ir keičiamu darbo įrodymu.

## Formato apžvalga

PoCX grafiko failuose yra iš anksto apskaičiuotos Shabal256 maišos reikšmės, organizuotos efektyviam kasimo operacijoms. Sekant PoC tradiciją nuo POC1, **visi metaduomenys įterpti failo pavadinime** - failo antraštės nėra.

### Failo plėtinys
- **Standartinis**: `.pocx` (užbaigti grafikai)
- **Vykdomas**: `.tmp` (kūrimo metu, pervadinama į `.pocx` kai užbaigta)

## Istorinis kontekstas ir pažeidžiamumo evoliucija

### POC1 formatas (palikimas)
**Du pagrindiniai pažeidžiamumai (laiko-atminties kompromisai):**

1. **PoW pasiskirstymo trūkumas**
   - Netolygus darbo įrodymo pasiskirstymas per scoops
   - Maži scoop numeriai galėjo būti skaičiuojami realiu laiku
   - **Poveikis**: Sumažinti saugyklos reikalavimai užpuolikams

2. **XOR suspaudimo ataka** (50% laiko-atminties kompromisas)
   - Išnaudojo matematines savybes 50% saugyklos sumažinimui
   - **Poveikis**: Užpuolikai galėjo kasti su puse reikalingos saugyklos

**Išdėstymo optimizacija**: Bazinis nuoseklus scoop išdėstymas HDD efektyvumui

### POC2 formatas (Burstcoin)
- ✅ **Ištaisytas PoW pasiskirstymo trūkumas**
- ❌ **XOR-transpozicijos pažeidžiamumas liko nepataisytas**
- **Išdėstymas**: Išlaikytas nuoseklus scoop optimizavimas

### PoCX formatas (dabartinis)
- ✅ **Ištaisytas PoW pasiskirstymas** (paveldėtas iš POC2)
- ✅ **Pataisytas XOR-transpozicijos pažeidžiamumas** (unikalus PoCX)
- ✅ **Patobulintas SIMD/GPU išdėstymas** optimizuotas lygiagrečiam apdorojimui ir atminties sujungimui
- ✅ **Keičiamas darbo įrodymas** apsaugo nuo laiko-atminties kompromisų augant skaičiavimo galiai (PoW atliekamas tik kuriant ar atnaujinant grafiko failus)

## XOR-transpozicijos kodavimas

### Problema: 50% laiko-atminties kompromisas

POC1/POC2 formatuose užpuolikai galėjo išnaudoti matematinį ryšį tarp scoops, kad saugotų tik pusę duomenų ir skaičiuotų likusią dalį kasimo metu. Ši "XOR suspaudimo ataka" pakenkė saugyklos garantijai.

### Sprendimas: XOR-transpozicijos sustiprinimas

PoCX išveda savo kasimo formatą (X1) taikydamas XOR-transpozicijos kodavimą bazinių warp poroms (X0):

**X1 warp scoop S nonce N konstrukcijai:**
1. Imkite scoop S nonce N iš pirmo X0 warp (tiesioginė pozicija)
2. Imkite scoop N nonce S iš antro X0 warp (transponuota pozicija)
3. XOR dvi 64 baitų reikšmes gauti X1 scoop

Transpozicijos žingsnis sukeičia scoop ir nonce indeksus. Matricos terminais - kur eilutės reprezentuoja scoops, o stulpeliai reprezentuoja nonces - jis sujungia elementą pozicijoje (S, N) pirmame warp su elementu pozicijoje (N, S) antrame.

### Kodėl tai pašalina ataką

XOR-transpozicija susieja kiekvieną scoop su visa eilute ir visu stulpeliu pagrindiniuose X0 duomenyse. Vieno X1 scoop atkūrimui reikia prieigos prie duomenų, apimančių visus 4096 scoop indeksus. Bet koks bandymas skaičiuoti trūkstamus duomenis pareikalautų atgeneruoti 4096 pilnus nonces, o ne vieną nonce - pašalinant asimetrinę kaštų struktūrą, kurią išnaudojo XOR ataka.

Todėl pilno X1 warp saugojimas tampa vienintele skaičiavimų požiūriu perspektyvia strategija kasėjams.

## Failo pavadinimo metaduomenų struktūra

Visi grafiko metaduomenys užkoduoti failo pavadinime šiuo tiksliu formatu:

```
{PASKYROS_DUOMENYS}_{SĖKLA}_{WARP}_{MASTELIS}.pocx
```

### Failo pavadinimo komponentai

1. **PASKYROS_DUOMENYS** (40 šešioliktainių simbolių)
   - Neapdoroti 20 baitų paskyros duomenys kaip didžiosios šešioliktainės
   - Nepriklausoma nuo tinklo (be tinklo ID ar kontrolinės sumos)
   - Pavyzdys: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SĖKLA** (64 šešioliktainių simbolių)
   - 32 baitų sėklos reikšmė kaip mažosios šešioliktainės
   - **Nauja PoCX**: Atsitiktinė 32 baitų sėkla failo pavadinime pakeičia nuoseklią nonce numeraciją - apsaugo nuo grafiko persidengimų
   - Pavyzdys: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARP** (dešimtainis skaičius)
   - **NAUJAS dydžio vienetas PoCX**: Pakeičia nonce pagrįstą dydžio nustatymą iš POC1/POC2
   - **XOR-transpozicijai atsparus dizainas**: Kiekvienas warp = tiksliai 4096 nonces (padalijimo dydis reikalingas XOR-transpozicijai atspariai transformacijai)
   - **Dydis**: 1 warp = 1073741824 baitai = 1 GiB (patogus vienetas)
   - Pavyzdys: `1024` (1 TiB grafikas = 1024 warp)

4. **MASTELIS** (X priesaginė dešimtainė)
   - Mastelio lygis kaip `X{lygis}`
   - Didesnės reikšmės = daugiau darbo įrodymo reikalaujama
   - Pavyzdys: `X4` (2^4 = 16× POC2 sudėtingumas)

### Failo pavadinimų pavyzdžiai
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Failo išdėstymas ir duomenų struktūra

### Hierarchinė organizacija
```
Grafiko failas (BE ANTRAŠTĖS)
├── Scoop 0
│   ├── Warp 0 (Visi nonces šiam scoop/warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Konstantos ir dydžiai

| Konstanta       | Dydis                   | Aprašymas                                       |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Vienos Shabal256 maišos išvestis                |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Maišos pora skaitoma kasimo raunde              |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops per nonce; vienas pasirenkamas per raundą|
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Visi nonce scoops (PoC1/PoC2 mažiausias vienetas)|
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Mažiausias vienetas PoCX                        |

### SIMD optimizuotas grafiko failo išdėstymas

PoCX įgyvendina SIMD-sąmoningą nonce prieigos šabloną, kuris įgalina vektorizuotą kelių nonces apdorojimą vienu metu. Jis remiasi konceptais iš [POC2×16 optimizavimo tyrimų](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/), siekiant maksimalaus atminties pralaidumo ir SIMD efektyvumo.

---

#### Tradicinis nuoseklus išdėstymas

Nuoseklus nonces saugojimas:

```
[Nonce 0: Scoop duomenys] [Nonce 1: Scoop duomenys] [Nonce 2: Scoop duomenys] ...
```

SIMD neefektyvumas: Kiekvienai SIMD juostai reikia to paties žodžio per nonces:

```
Žodis 0 iš Nonce 0 -> poslinkis 0
Žodis 0 iš Nonce 1 -> poslinkis 512
Žodis 0 iš Nonce 2 -> poslinkis 1024
...
```

Išsklaidytas prieigos būdas sumažina pralaidumą.

---

#### PoCX SIMD optimizuotas išdėstymas

PoCX saugo **žodžių pozicijas per 16 nonces** greta:

```
Podėlio eilutė (64 baitai):

Žodis0_N0 Žodis0_N1 Žodis0_N2 ... Žodis0_N15
Žodis1_N0 Žodis1_N1 Žodis1_N2 ... Žodis1_N15
...
```

**ASCII diagrama**

```
Tradicinis išdėstymas:

Nonce0: [Ž0][Ž1][Ž2][Ž3]...
Nonce1: [Ž0][Ž1][Ž2][Ž3]...
Nonce2: [Ž0][Ž1][Ž2][Ž3]...

PoCX išdėstymas:

Žodis0: [N0][N1][N2][N3]...[N15]
Žodis1: [N0][N1][N2][N3]...[N15]
Žodis2: [N0][N1][N2][N3]...[N15]
```

---

#### Atminties prieigos privalumai

- Viena podėlio eilutė tiekia visoms SIMD juostoms.
- Pašalina išsklaidymo-surinkimo operacijas.
- Sumažina podėlio praleidimus.
- Visiškai nuosekli atminties prieiga vektorizuotiems skaičiavimams.
- GPU taip pat gauna naudos iš 16-nonce sulygiavimo, maksimizuojant podėlio efektyvumą.

---

#### SIMD mastelio keitimas

| SIMD       | Vektoriaus plotis* | Nonces | Apdorojimo ciklai per podėlio eilutę |
|------------|-------------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit           | 4      | 4 ciklai                        |
| AVX2       | 256-bit           | 8      | 2 ciklai                        |
| AVX512     | 512-bit           | 16     | 1 ciklas                        |

\* Sveikųjų skaičių operacijoms

---



## Darbo įrodymo mastelio keitimas

### Mastelio lygiai
- **X0**: Baziniai nonces be XOR-transpozicijos kodavimo (teorinis, nenaudojamas kasimui)
- **X1**: XOR-transpozicijos bazinė linija - pirmasis sustiprintas formatas (1× darbas)
- **X2**: 2× X1 darbas (XOR per 2 warps)
- **X3**: 4× X1 darbas (XOR per 4 warps)
- **...**
- **Xn**: 2^(n-1) × X1 darbas įterptas

### Privalumai
- **Reguliuojamas PoW sudėtingumas**: Padidina skaičiavimo reikalavimus neatsilikti nuo greitesnės aparatinės įrangos
- **Formato ilgaamžiškumas**: Įgalina lankstų kasimo sudėtingumo mastelio keitimą laikui bėgant

### Grafiko atnaujinimas / atgalinis suderinamumas

Kai tinklas padidina PoW (darbo įrodymo) mastelį 1, esamiems grafikams reikia atnaujinimo, kad išlaikytų tą patį efektyvų grafiko dydį. Iš esmės, dabar jums reikia dvigubai daugiau PoW jūsų grafiko failuose, kad pasiektumėte tą patį indėlį į jūsų paskyrą.

Gera žinia ta, kad PoW, kurį jau atlikote kurdami savo grafiko failus, neprarandamas - jums tiesiog reikia pridėti papildomą PoW prie esamų failų. Nereikia pergeneruoti.

Alternatyviai, galite toliau naudoti savo dabartinius grafikus neatnaujindami, tačiau atminkite, kad dabar jie sudarys tik 50% ankstesnio efektyvaus dydžio jūsų paskyroje. Jūsų kasimo programinė įranga gali masteliuoti grafiko failą realiu laiku.

## Palyginimas su palikimo formatais

| Funkcija | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW pasiskirstymas | ❌ Klaidingas | ✅ Ištaisytas | ✅ Ištaisytas |
| XOR-transpozicijos atsparumas | ❌ Pažeidžiamas | ❌ Pažeidžiamas | ✅ Ištaisytas |
| SIMD optimizacija | ❌ Nėra | ❌ Nėra | ✅ Pažangi |
| GPU optimizacija | ❌ Nėra | ❌ Nėra | ✅ Optimizuota |
| Keičiamas darbo įrodymas | ❌ Nėra | ❌ Nėra | ✅ Taip |
| Sėklos palaikymas | ❌ Nėra | ❌ Nėra | ✅ Taip |

PoCX formatas reprezentuoja dabartinę pažangiausią Proof of Capacity grafiko formatų būseną, sprendžiant visus žinomus pažeidžiamumus ir kartu teikiant reikšmingus našumo patobulinimus šiuolaikinei aparatinei įrangai.

## Nuorodos ir papildoma literatūra

- **POC1/POC2 pagrindai**: [Burstcoin kasimo apžvalga](https://www.burstcoin.community/burstcoin-mining/) - išsamus tradicinių Proof of Capacity kasimo formatų vadovas
- **POC2×16 tyrimai**: [CIP skelbimas: POC2×16 - naujas optimizuotas grafiko formatas](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - originalūs SIMD optimizavimo tyrimai, kurie įkvėpė PoCX
- **Shabal maišos algoritmas**: [Saphir projektas: Shabal, pateikimas NIST kriptografinių maišos algoritmų konkursui](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Shabal256 algoritmo, naudojamo PoC kasime, techninė specifikacija

---

[← Ankstesnis: Įvadas](1-introduction.md) | [📘 Turinys](index.md) | [Toliau: Konsensusas ir kasimas →](3-consensus-and-mining.md)

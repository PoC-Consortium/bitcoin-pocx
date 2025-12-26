[<- Eelmine: Sissejuhatus](1-introduction.md) | [Sisukord](index.md) | [Järgmine: Konsensus ja kaevandamine ->](3-consensus-and-mining.md)

---

# Peatükk 2: PoCX graafikuvormingu spetsifikatsioon

See dokument kirjeldab PoCX graafikuvormingut, mis on POC2 vormingu täiustatud versioon parema turvalisuse, SIMD optimeerimiste ja skaleeritava tööst tuletatud tõestusega.

## Vormingu ülevaade

PoCX graafikufailid sisaldavad eelarvutatud Shabal256 räsiväärtusi, mis on korraldatud tõhusateks kaevandamisoperatsioonideks. Järgides PoC traditsiooni alates POC1-st, **kõik metaandmed on manustatud failinimes** - faili päist pole.

### Faililaiend
- **Standardne**: `.pocx` (valmis graafikud)
- **Pooleli**: `.tmp` (graafikukoostamise ajal, nimetatakse ümber `.pocx`-ks, kui valmis)

## Ajalooline kontekst ja haavatavuste areng

### POC1 vorming (pärand)
**Kaks peamist haavatavust (aja-mälu kompromissid):**

1. **PoW jaotuse viga**
   - Tööst tuletatud tõestuse ebaühtlane jaotus scoop'ide vahel
   - Madalaid scoop numbreid sai arvutada lennult
   - **Mõju**: Vähendatud hoiustusnõuded ründajatele

2. **XOR kompressiooni rünnak** (50% aja-mälu kompromiss)
   - Kasutas ära matemaatilisi omadusi 50% hoiustuse vähendamiseks
   - **Mõju**: Ründajad said kaevandada poole nõutud hoiustusega

**Paigutuse optimeerimine**: Põhiline järjestikune scoop paigutus HDD tõhususeks

### POC2 vorming (Burstcoin)
- PoW jaotuse viga parandatud
- XOR-transponeeri haavatavus jäi lappimata
- **Paigutus**: Säilitas järjestikuse scoop optimeerimise

### PoCX vorming (praegune)
- **PoW jaotus parandatud** (päritud POC2-lt)
- **XOR-transponeeri haavatavus parandatud** (PoCX-i ainuomane)
- **Täiustatud SIMD/GPU paigutus** optimeeritud paralleeltöötluseks ja mälu koondamiseks
- **Skaleeritav tööst tuletatud tõestus** takistab aja-mälu kompromisse arvutusvõimsuse kasvades (PoW tehakse ainult graafikufailide loomisel või uuendamisel)

## XOR-transponeeri kodeering

### Probleem: 50% aja-mälu kompromiss

POC1/POC2 vormingutes said ründajad ära kasutada scoop'ide matemaatilist seost, et hoiustada ainult poole andmetest ja arvutada ülejäänu lennult kaevandamise ajal. See "XOR kompressiooni rünnak" õõnestas hoiustuse garantiid.

### Lahendus: XOR-transponeeri karastamine

PoCX tuletab oma kaevandusvormingu (X1), rakendades XOR-transponeeri kodeeringut baas-warp'ide (X0) paaridele:

**Scoop S konstrueerimiseks nonce N jaoks X1 warp'is:**
1. Võta scoop S nonce N-st esimesest X0 warp'ist (otsene positsioon)
2. Võta scoop N nonce S-st teisest X0 warp'ist (transponeeritud positsioon)
3. XOR-i kaks 64-baidist väärtust X1 scoop'i saamiseks

Transponeeri samm vahetab scoop ja nonce indeksid. Maatriksi mõttes - kus read esindavad scoop'e ja veerud nonce'e - kombineerib see elemendi positsioonilt (S, N) esimeses warp'is elemendiga positsioonilt (N, S) teises.

### Miks see elimineerib rünnaku

XOR-transponeeri lukustab iga scoop'i terve rea ja terve veeruga aluseks olevatest X0 andmetest. Ühe X1 scoop'i taastamine nõuab seega juurdepääsu andmetele, mis hõlmavad kõiki 4096 scoop indeksit. Igasugune katse puuduvaid andmeid arvutada nõuaks 4096 täieliku nonce'i regenereerimist ühe nonce'i asemel - eemaldades asümmeetrilise kulustruktuuri, mida XOR rünnak kasutas.

Selle tulemusena muutub täieliku X1 warp'i hoiustamine ainsaks arvutuslikult elujõuliseks strateegiaks kaevandajatele.

## Failinime metaandmete struktuur

Kõik graafikumetaandmed on kodeeritud failinimes täpselt selles vormingus:

```
{KONTO_KOOREM}_{SEEME}_{WARP_ID}_{SKALEERIMINE}.pocx
```

### Failinime komponendid

1. **KONTO_KOOREM** (40 hex tähemärki)
   - Töötlemata 20-baidine konto koorem suurtähtedes hex-na
   - Võrgust sõltumatu (pole võrgu ID-d ega kontrollsummat)
   - Näide: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEEME** (64 hex tähemärki)
   - 32-baidine seemeväärtus väiketähtedes hex-na
   - **PoCX-is uus**: Juhuslik 32-baidine seeme failinimes asendab järjestikuse nonce nummerdamise - takistab graafikute kattumist
   - Näide: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARP_ID** (kümnendnumber)
   - **PoCX-is uus suurusühik**: Asendab nonce-põhist suurust POC1/POC2-st
   - **XOR-transponeeri vastupidav disain**: Iga warp = täpselt 4096 nonce (XOR-transponeeri vastupidava teisenduse jaoks nõutav partitsiooni suurus)
   - **Suurus**: 1 warp = 1073741824 baiti = 1 GiB (mugav ühik)
   - Näide: `1024` (1 TiB graafik = 1024 warp'i)

4. **SKALEERIMINE** (X-prefiksiga kümnendnumber)
   - Skaleerimistase kui `X{tase}`
   - Kõrgemad väärtused = rohkem tööst tuletatud tõestust nõutud
   - Näide: `X4` (2^4 = 16× POC2 raskus)

### Näidisfailinimed
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Faili paigutus ja andmestruktuur

### Hierarhiline korraldus
```
Graafikufail (PÄIST POLE)
├── Scoop 0
│   ├── Warp 0 (Kõik nonce'd selle scoop/warp jaoks)
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

### Konstandid ja suurused

| Konstant        | Suurus                  | Kirjeldus                                       |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Ühe Shabal256 räsi väljund                      |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Räsipaar, mida loetakse kaevandamisringis       |
| **NUM\_SCOOPS** | 4096 (2^12)            | Scoop'e nonce'i kohta; üks valitakse ringi kohta |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Kõik nonce'i scoop'id (PoC1/PoC2 väikseim ühik) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Väikseim ühik PoCX-is                           |

### SIMD-optimeeritud graafikufaili paigutus

PoCX implementeerib SIMD-teadliku nonce juurdepääsumustri, mis võimaldab mitme nonce'i vektoriseeritud töötlemist samaaegselt. See tugineb kontseptsioonidele [POC2×16 optimeerimise uuringust](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/), et maksimeerida mälu läbilaskevõimet ja SIMD tõhusust.

---

#### Traditsiooniline järjestikune paigutus

Nonce'ide järjestikune hoiustamine:

```
[Nonce 0: Scoop andmed] [Nonce 1: Scoop andmed] [Nonce 2: Scoop andmed] ...
```

SIMD ebatõhusus: Iga SIMD rada vajab sama sõna erinevate nonce'ide vahel:

```
Sõna 0 Nonce 0-st -> nihe 0
Sõna 0 Nonce 1-st -> nihe 512
Sõna 0 Nonce 2-st -> nihe 1024
...
```

Hajutatud kogumine vähendab läbilaskevõimet.

---

#### PoCX SIMD-optimeeritud paigutus

PoCX hoiustab **sõnapositsioonid 16 nonce'i vahel** kõrvuti:

```
Vahemälu rida (64 baiti):

Sõna0_N0 Sõna0_N1 Sõna0_N2 ... Sõna0_N15
Sõna1_N0 Sõna1_N1 Sõna1_N2 ... Sõna1_N15
...
```

**ASCII diagramm**

```
Traditsiooniline paigutus:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX paigutus:

Sõna0: [N0][N1][N2][N3]...[N15]
Sõna1: [N0][N1][N2][N3]...[N15]
Sõna2: [N0][N1][N2][N3]...[N15]
```

---

#### Mälu juurdepääsu eelised

- Üks vahemälu rida varustab kõiki SIMD radasid.
- Elimineerib hajutatud kogumise operatsioonid.
- Vähendab vahemälu möödalaskmisi.
- Täielikult järjestikune mälu juurdepääs vektoriseeritud arvutuseks.
- GPU-d saavad samuti kasu 16-nonce joondamisest, maksimeerides vahemälu tõhusust.

---

#### SIMD skaleerimine

| SIMD       | Vektori laius* | Nonce'd | Töötlustsükleid vahemälu rea kohta |
|------------|----------------|---------|-----------------------------------|
| SSE2/AVX   | 128-bit        | 4       | 4 tsüklit                         |
| AVX2       | 256-bit        | 8       | 2 tsüklit                         |
| AVX512     | 512-bit        | 16      | 1 tsükkel                         |

\* Täisarvuoperatsioonide jaoks

---



## Tööst tuletatud tõestuse skaleerimine

### Skaleerimistasemed
- **X0**: Baas-nonce'd ilma XOR-transponeeri kodeeringuta (teoreetiline, ei kasutata kaevandamiseks)
- **X1**: XOR-transponeeri baastase - esimene karastatud vorming (1× töö)
- **X2**: 2× X1 töö (XOR 2 warp'i vahel)
- **X3**: 4× X1 töö (XOR 4 warp'i vahel)
- **...**
- **Xn**: 2^(n-1) × X1 töö manustatud

### Eelised
- **Kohandatav PoW raskus**: Suurendab arvutusnõudeid, et pidada sammu kiirema riistvaraga
- **Vormingu pikaealisus**: Võimaldab kaevandamise raskuse paindlikku skaleerimist aja jooksul

### Graafiku uuendamine / tagasiühilduvus

Kui võrk suurendab PoW (tööst tuletatud tõestuse) skaalat 1 võrra, vajavad olemasolevad graafikud uuendamist, et säilitada sama efektiivne graafikusuurus. Sisuliselt vajate nüüd kaks korda rohkem PoW-d oma graafikufailides, et saavutada sama panus teie kontole.

Hea uudis on see, et PoW, mille olete juba teinud oma graafikufailide loomisel, ei lähe kaotsi - peate lihtsalt lisama täiendava PoW olemasolevatele failidele. Pole vaja uuesti graafikuid koostada.

Alternatiivselt võite jätkata oma praeguste graafikute kasutamist ilma uuendamiseta, kuid pange tähele, et need annavad nüüd ainult 50% nende eelmisest efektiivsest suurusest teie konto jaoks. Teie kaevandamistarkvara saab graafikufaili skaleerida lennult.

## Võrdlus pärandvormingutega

| Omadus | POC1 | POC2 | PoCX |
|--------|------|------|------|
| PoW jaotus | Vigane | Parandatud | Parandatud |
| XOR-transponeeri vastupanu | Haavatav | Haavatav | Parandatud |
| SIMD optimeerimine | Puudub | Puudub | Täiustatud |
| GPU optimeerimine | Puudub | Puudub | Optimeeritud |
| Skaleeritav tööst tuletatud tõestus | Puudub | Puudub | Jah |
| Seemne tugi | Puudub | Puudub | Jah |

PoCX vorming esindab mahtutõestuse graafikuvormingute tipptaset, käsitledes kõiki teadaolevaid haavatavusi, pakkudes samal ajal olulisi jõudluse parandusi kaasaegsele riistvarale.

## Viited ja edasine lugemine

- **POC1/POC2 taust**: [Burstcoin kaevandamise ülevaade](https://www.burstcoin.community/burstcoin-mining/) - Põhjalik juhend traditsioonilistele mahtutõestuse kaevandusvormingutele
- **POC2×16 uuring**: [CIP teadaanne: POC2×16 - Uus optimeeritud graafikuvorming](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Algne SIMD optimeerimise uuring, mis inspireeris PoCX-i
- **Shabal räsialgoritm**: [Saphir projekt: Shabal, esildis NIST-i krüptograafilise räsialgoritmi konkursile](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Shabal256 algoritmi tehniline spetsifikatsioon, mida kasutatakse PoC kaevandamises

---

[<- Eelmine: Sissejuhatus](1-introduction.md) | [Sisukord](index.md) | [Järgmine: Konsensus ja kaevandamine ->](3-consensus-and-mining.md)

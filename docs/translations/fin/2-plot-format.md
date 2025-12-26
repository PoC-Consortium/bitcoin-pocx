[← Edellinen: Johdanto](1-introduction.md) | [Sisällysluettelo](index.md) | [Seuraava: Konsensus ja louhinta →](3-consensus-and-mining.md)

---

# Luku 2: PoCX-plottimuodon määrittely

Tämä dokumentti kuvaa PoCX-plottimuodon, joka on POC2-muodon parannettu versio parannetulla turvallisuudella, SIMD-optimoinneilla ja skaalautuvalla proof-of-workilla.

## Muodon yleiskatsaus

PoCX-plottitiedostot sisältävät esigeneroituja Shabal256-tiivistearvoja, jotka on järjestetty tehokkaita louhintaoperaatioita varten. PoC-perinnettä noudattaen POC1:stä lähtien, **kaikki metatiedot on upotettu tiedostonimeen** – tiedostolla ei ole otsikkoa.

### Tiedostopääte
- **Standardi**: `.pocx` (valmiit plotit)
- **Kesken**: `.tmp` (plotituksen aikana, nimetään uudelleen `.pocx`:ksi valmistuessa)

## Historiallinen konteksti ja haavoittuvuuksien kehitys

### POC1-muoto (vanha)
**Kaksi merkittävää haavoittuvuutta (aika–muisti-vaihtokaupat):**

1. **PoW-jakelun virhe**
   - Epätasainen proof-of-work-jakelu scoopien kesken
   - Matalan numeron scooppeja voitiin laskea lennossa
   - **Vaikutus**: Pienennetyt tallennusvaatimukset hyökkääjille

2. **XOR-pakkausshyökkäys** (50 % aika–muisti-vaihtokauppa)
   - Hyödynsi matemaattisia ominaisuuksia 50 % tallennusvähennyksen saavuttamiseksi
   - **Vaikutus**: Hyökkääjät saattoivat louhia puolella vaaditusta tallennustilasta

**Layout-optimointi**: Perusperäkkäinen scoop-layout HDD-tehokkuutta varten

### POC2-muoto (Burstcoin)
- ✅ **Korjattu PoW-jakelun virhe**
- ❌ **XOR-transpose-haavoittuvuus jäi paikkaamatta**
- **Layout**: Säilytti peräkkäisen scoop-optimoinnin

### PoCX-muoto (nykyinen)
- ✅ **Korjattu PoW-jakelu** (peritty POC2:lta)
- ✅ **Paikattu XOR-transpose-haavoittuvuus** (ainutlaatuinen PoCX:lle)
- ✅ **Parannettu SIMD/GPU-layout** optimoitu rinnakkaiselle käsittelylle ja muistin koaleskenssille
- ✅ **Skaalautuva proof-of-work** estää aika–muisti-vaihtokaupat laskentatehon kasvaessa (PoW suoritetaan vain luotaessa tai päivitettäessä plottitiedostoja)

## XOR-Transpose-koodaus

### Ongelma: 50 % aika–muisti-vaihtokauppa

POC1/POC2-muodoissa hyökkääjät saattoivat hyödyntää scoopien matemaattista suhdetta tallentaakseen vain puolet datasta ja laskea loput lennossa louhinnan aikana. Tämä "XOR-pakkausshyökkäys" heikensi tallennustakuuta.

### Ratkaisu: XOR-Transpose-kovetus

PoCX johtaa louhintamuotonsa (X1) soveltamalla XOR-transpose-koodausta perus-warp-pareihin (X0):

**X1-warpin scoopin S muodostaminen noncelle N:**
1. Ota scoop S noncesta N ensimmäisestä X0-warpista (suora sijainti)
2. Ota scoop N noncesta S toisesta X0-warpista (transponoitu sijainti)
3. XOR-operoi kaksi 64-tavuista arvoa saadaksesi X1-scoopin

Transponointi vaihtaa scoop- ja nonce-indeksit. Matriisitermein – missä rivit edustavat scooppeja ja sarakkeet nonceja – se yhdistää elementin positiossa (S, N) ensimmäisessä warpissa elementtiin (N, S) toisessa.

### Miksi tämä poistaa hyökkäyksen

XOR-transpose lukitsee jokaisen scoopin kokonaiseen riviin ja sarakkeeseen alla olevasta X0-datasta. Yhden X1-scoopin palauttaminen vaatii pääsyä dataan, joka kattaa kaikki 4096 scoop-indeksiä. Mikä tahansa yritys laskea puuttuvaa dataa vaatisi 4096 täyden noncen uudelleengeneroimista yksittäisen noncen sijaan – poistaen epäsymmetrisen kustannusrakenteen, jota XOR-hyökkäys hyödynsi.

Tämän seurauksena täyden X1-warpin tallentaminen on ainoa laskennallisesti toteuttamiskelpoinen strategia louhijoille.

## Tiedostonimen metadatarakenne

Kaikki plotin metatiedot on koodattu tiedostonimeen tällä täsmällisellä muodolla:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Tiedostonimen komponentit

1. **ACCOUNT_PAYLOAD** (40 heksamerkkiä)
   - Raaka 20-tavuinen tilin payload isokirjaimisena heksana
   - Verkkoriippumaton (ei verkkotunnistetta tai tarkistussummaa)
   - Esimerkki: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 heksamerkkiä)
   - 32-tavuinen seed-arvo pienikirjaimisena heksana
   - **Uutta PoCX:ssä**: Satunnainen 32-tavuinen seed tiedostonimessä korvaa peräkkäisen nonce-numeroinnin – estäen plottien päällekkäisyydet
   - Esimerkki: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (desimaaliluku)
   - **UUSI kokoyksikkö PoCX:ssä**: Korvaa nonce-pohjaisen koon määrityksen POC1/POC2:sta
   - **XOR-transpose-resistentti suunnittelu**: Jokainen warp = täsmälleen 4096 noncea (osioiden koko vaaditaan XOR-transpose-resistentille muunnokselle)
   - **Koko**: 1 warp = 1073741824 tavua = 1 GiB (kätevä yksikkö)
   - Esimerkki: `1024` (1 TiB plotti = 1024 warpia)

4. **SCALING** (X-etuliitteinen desimaaliluku)
   - Skaalaustaso muodossa `X{taso}`
   - Korkeammat arvot = enemmän proof-of-workia vaaditaan
   - Esimerkki: `X4` (2^4 = 16× POC2-vaikeus)

### Esimerkkitiedostonimet
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Tiedoston layout ja datarakenne

### Hierarkkinen organisointi
```
Plottitiedosto (EI OTSIKKOA)
├── Scoop 0
│   ├── Warp 0 (Kaikki noncet tälle scoop/warp-parille)
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

### Vakiot ja koot

| Vakio        | Koko                    | Kuvaus                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Yksittäisen Shabal256-tiivisteen tuloste        |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Tiivistepari, joka luetaan louhintakierroksella |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoopit per nonce; yksi valitaan per kierros    |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Kaikki noncen scoopit (PoC1/PoC2:n pienin yksikkö) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Pienin yksikkö PoCX:ssä                         |

### SIMD-optimoitu plottitiedoston layout

PoCX toteuttaa SIMD-tietoisen nonce-hakukuvion, joka mahdollistaa vektorisoidun käsittelyn useille nonceille samanaikaisesti. Se rakentuu käsitteille [POC2×16-optimointitutkimuksesta](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) maksimoidakseen muistin läpäisykyvyn ja SIMD-tehokkuuden.

---

#### Perinteinen peräkkäinen layout

Noncien peräkkäinen tallennus:

```
[Nonce 0: Scoop-data] [Nonce 1: Scoop-data] [Nonce 2: Scoop-data] ...
```

SIMD-tehottomuus: Jokainen SIMD-kaista tarvitsee saman sanan useista nonceista:

```
Sana 0 Noncesta 0 -> offset 0
Sana 0 Noncesta 1 -> offset 512
Sana 0 Noncesta 2 -> offset 1024
...
```

Hajakeruu-haku heikentää läpäisykykyä.

---

#### PoCX SIMD-optimoitu layout

PoCX tallentaa **sanasijainnit 16 noncen kesken** yhtenäisesti:

```
Välimuistirivi (64 tavua):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII-kaavio**

```
Perinteinen layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX-layout:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Muistinkäytön hyödyt

- Yksi välimuistirivi tarjoaa kaikille SIMD-kaistoille.
- Poistaa hajakeruu-operaatiot.
- Vähentää välimuistin ohituksia.
- Täysin peräkkäinen muistinkäyttö vektorisoidulle laskennalle.
- GPU:t hyötyvät myös 16-noncen tasauksesta, maksimoiden välimuistin tehokkuuden.

---

#### SIMD-skaalaus

| SIMD       | Vektorileveys* | Noncea | Käsittelysyklit per välimuistirivi |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bittinen  | 4      | 4 sykliä                        |
| AVX2       | 256-bittinen  | 8      | 2 sykliä                        |
| AVX512     | 512-bittinen  | 16     | 1 sykli                         |

\* Kokonaislukuoperaatioille

---



## Proof-of-Work-skaalaus

### Skaalaustasot
- **X0**: Perus-noncet ilman XOR-transpose-koodausta (teoreettinen, ei käytetä louhintaan)
- **X1**: XOR-transpose-perustaso – ensimmäinen kovennettu muoto (1× työ)
- **X2**: 2× X1-työ (XOR 2 warpin kesken)
- **X3**: 4× X1-työ (XOR 4 warpin kesken)
- **…**
- **Xn**: 2^(n-1) × X1-työ upotettuna

### Hyödyt
- **Säädettävä PoW-vaikeus**: Kasvattaa laskentavaatimuksia pysyäkseen nopeamman laitteiston perässä
- **Muodon pitkäikäisyys**: Mahdollistaa louhinnan vaikeuden joustavan skaalauksen ajan myötä

### Plotin päivitys / taaksepäin yhteensopivuus

Kun verkko nostaa PoW-skaalausta yhdellä, olemassa olevat plotit vaativat päivityksen säilyttääkseen saman tehollisen plottikoon. Käytännössä sinun on nyt sisällytettävä kaksinkertainen määrä PoW:ta plottitiedostoihisi saavuttaaksesi saman osuuden tililläsi.

Hyvä uutinen on, että jo tehtyä PoW:ta plottitiedostoja luodessasi ei menetetä – sinun täytyy vain lisätä PoW:ta olemassa oleviin tiedostoihin. Uudelleenplotitus ei ole tarpeen.

Vaihtoehtoisesti voit jatkaa nykyisten plottiesi käyttöä päivittämättä, mutta huomaa, että ne tuottavat nyt vain 50 % aiemmasta tehollisesta koostaan tililläsi. Louhintaohjelmistosi voi skaalata plottitiedoston lennossa.

## Vertailu aiempiin muotoihin

| Ominaisuus | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW-jakelu | ❌ Viallinen | ✅ Korjattu | ✅ Korjattu |
| XOR-Transpose-resistenssi | ❌ Haavoittuva | ❌ Haavoittuva | ✅ Korjattu |
| SIMD-optimointi | ❌ Ei mitään | ❌ Ei mitään | ✅ Edistynyt |
| GPU-optimointi | ❌ Ei mitään | ❌ Ei mitään | ✅ Optimoitu |
| Skaalautuva Proof-of-Work | ❌ Ei mitään | ❌ Ei mitään | ✅ Kyllä |
| Seed-tuki | ❌ Ei mitään | ❌ Ei mitään | ✅ Kyllä |

PoCX-muoto edustaa Proof of Capacity -plottimuotojen huippua, korjaten kaikki tunnetut haavoittuvuudet samalla tarjoten merkittäviä suorituskyvyn parannuksia modernille laitteistolle.

## Viitteet ja lisälukemista

- **POC1/POC2-tausta**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Kattava opas perinteisiin Proof of Capacity -louhintamuotoihin
- **POC2×16-tutkimus**: [CIP Announcement: POC2×16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Alkuperäinen SIMD-optimointitutkimus, joka inspiroi PoCX:ää
- **Shabal-tiivistealgoritmi**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - PoC-louhinnassa käytetyn Shabal256-algoritmin tekninen määrittely

---

[← Edellinen: Johdanto](1-introduction.md) | [Sisällysluettelo](index.md) | [Seuraava: Konsensus ja louhinta →](3-consensus-and-mining.md)

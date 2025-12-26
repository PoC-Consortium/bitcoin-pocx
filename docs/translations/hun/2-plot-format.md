[← Előző: Bevezetés](1-introduction.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Konszenzus és Bányászat →](3-consensus-and-mining.md)

---

# 2. Fejezet: PoCX Plotfájl Formátum Specifikáció

Ez a dokumentum a PoCX plotfájl formátumot írja le, amely a POC2 formátum továbbfejlesztett változata, javított biztonsággal, SIMD optimalizációkkal és skálázható proof-of-work-kel.

## Formátum Áttekintés

A PoCX plotfájlok előre kiszámított Shabal256 hash értékeket tartalmaznak, hatékony bányászati műveletekhez szervezett formában. A PoC hagyományt követve a POC1 óta, **minden metaadat a fájlnévbe van beágyazva** — nincs fájl fejléc.

### Fájl Kiterjesztés
- **Szabványos**: `.pocx` (befejezett plotok)
- **Folyamatban**: `.tmp` (plotolás közben, befejezéskor `.pocx`-re átnevezve)

## Történeti Háttér és Sebezhetőségi Fejlődés

### POC1 Formátum (Örökség)
**Két Fő Sebezhetőség (Idő-Memória Kompromisszumok):**

1. **PoW Eloszlási Hiba**
   - Nem egyenletes proof-of-work eloszlás a scoop-ok között
   - Alacsony scoop számok menet közben kiszámíthatók voltak
   - **Hatás**: Csökkentett tárolási követelmények a támadók számára

2. **XOR Tömörítési Támadás** (50% Idő-Memória Kompromisszum)
   - Matematikai tulajdonságokat használt ki 50% tároláscsökkentés eléréséhez
   - **Hatás**: A támadók fele tárolással bányászhattak

**Elrendezés Optimalizáció**: Alapvető szekvenciális scoop elrendezés HDD hatékonysághoz

### POC2 Formátum (Burstcoin)
- ✅ **Javított PoW eloszlási hiba**
- ❌ **XOR-transzponálás sebezhetőség javítatlan maradt**
- **Elrendezés**: Fenntartotta a szekvenciális scoop optimalizációt

### PoCX Formátum (Jelenlegi)
- ✅ **Javított PoW eloszlás** (POC2-ből örökölt)
- ✅ **Javított XOR-transzponálás sebezhetőség** (PoCX egyedi)
- ✅ **Fejlett SIMD/GPU elrendezés** párhuzamos feldolgozáshoz és memória egyesítéshez optimalizálva
- ✅ **Skálázható proof-of-work** megakadályozza az idő-memória kompromisszumokat a számítási teljesítmény növekedésével (PoW csak plotfájlok létrehozásakor vagy frissítésekor történik)

## XOR-Transzponálás Kódolás

### A Probléma: 50% Idő-Memória Kompromisszum

A POC1/POC2 formátumokban a támadók kihasználhatták a scoop-ok közötti matematikai kapcsolatot, hogy csak az adatok felét tárolják, a többit menet közben számítják ki bányászat közben. Ez az "XOR tömörítési támadás" aláásta a tárolási garanciát.

### A Megoldás: XOR-Transzponálás Megerősítés

A PoCX az alap warp-ok (X0) párjaira XOR-transzponálás kódolást alkalmazva származtatja a bányászati formátumát (X1):

**Egy X1 warp S scoop-jának N nonce-éhoz:**
1. Vegye az S scoop-ot N nonce-ból az első X0 warp-ból (közvetlen pozíció)
2. Vegye az N scoop-ot S nonce-ból a második X0 warp-ból (transzponált pozíció)
3. XOR-olja a két 64 bájtos értéket az X1 scoop előállításához

A transzponálás lépés felcseréli a scoop és nonce indexeket. Mátrix terminológiában — ahol a sorok a scoop-okat, az oszlopok a nonce-okat képviselik — az első warp (S, N) pozíciójának elemét kombinálja a második (N, S) elemével.

### Miért Szünteti Ez Meg a Támadást

Az XOR-transzponálás összekapcsol minden scoop-ot az alapjául szolgáló X0 adatok egy teljes sorával és egy teljes oszlopával. Egyetlen X1 scoop helyreállításához mind a 4096 scoop indexre kiterjedő adatokhoz kell hozzáférni. Bármilyen kísérlet a hiányzó adatok kiszámítására 4096 teljes nonce újragenerálását igényelné egyetlen nonce helyett — eltávolítva az XOR támadás által kihasznált aszimmetrikus költségstruktúrát.

Ennek eredményeként a teljes X1 warp tárolása válik az egyetlen számításilag életképes stratégiává a bányászok számára.

## Fájlnév Metaadat Struktúra

Minden plot metaadat a fájlnévben van kódolva ezzel a pontos formátummal:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Fájlnév Komponensek

1. **ACCOUNT_PAYLOAD** (40 hex karakter)
   - Nyers 20 bájtos account payload nagybetűs hex-ként
   - Hálózat-független (nincs hálózati ID vagy ellenőrző összeg)
   - Példa: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex karakter)
   - 32 bájtos seed érték kisbetűs hex-ként
   - **Új a PoCX-ben**: Véletlenszerű 32 bájtos seed a fájlnévben felváltja az egymást követő nonce számozást — megakadályozza a plot átfedéseket
   - Példa: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimális szám)
   - **ÚJ méretegység a PoCX-ben**: Felváltja a nonce-alapú méretezést a POC1/POC2-ből
   - **XOR-transzponálás ellenálló tervezés**: Minden warp = pontosan 4096 nonce (az XOR-transzponálás ellenálló transzformációhoz szükséges partíció méret)
   - **Méret**: 1 warp = 1073741824 bájt = 1 GiB (kényelmes egység)
   - Példa: `1024` (1 TiB plot = 1024 warp)

4. **SCALING** (X-előtagú decimális)
   - Skálázási szint mint `X{szint}`
   - Magasabb értékek = több proof-of-work szükséges
   - Példa: `X4` (2^4 = 16× POC2 nehézség)

### Példa Fájlnevek
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Fájl Elrendezés és Adatstruktúra

### Hierarchikus Szervezés
```
Plotfájl (NINCS FEJLÉC)
├── Scoop 0
│   ├── Warp 0 (Minden nonce ehhez a scoop/warp-hoz)
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

### Konstansok és Méretek

| Konstans        | Méret                   | Leírás                                          |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                    | Egyetlen Shabal256 hash kimenet                 |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)   | Hash pár egy bányászati körben olvasva          |
| **NUM\_SCOOPS** | 4096 (2¹²)              | Scoop-ok nonce-onként; egy kiválasztva körönként|
| **NONCE\_SIZE** | 262144 B (256 KiB)      | Egy nonce összes scoop-ja (PoC1/PoC2 legkisebb egység) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)    | Legkisebb egység a PoCX-ben                     |

### SIMD-Optimalizált Plotfájl Elrendezés

A PoCX egy SIMD-tudatos nonce hozzáférési mintát valósít meg, amely lehetővé teszi több nonce vektorizált feldolgozását egyidejűleg. A [POC2×16 optimalizációs kutatás](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) koncepcióira épít a memória átviteli sebesség és SIMD hatékonyság maximalizálása érdekében.

---

#### Hagyományos Szekvenciális Elrendezés

Nonce-ok szekvenciális tárolása:

```
[Nonce 0: Scoop Adat] [Nonce 1: Scoop Adat] [Nonce 2: Scoop Adat] ...
```

SIMD hatékonysági probléma: Minden SIMD sáv ugyanazt a szót igényli nonce-ok között:

```
Szó 0 Nonce 0-ból -> eltolás 0
Szó 0 Nonce 1-ből -> eltolás 512
Szó 0 Nonce 2-ből -> eltolás 1024
...
```

Szórt gyűjtés hozzáférés csökkenti az átvitelt.

---

#### PoCX SIMD-Optimalizált Elrendezés

A PoCX **szó pozíciókat tárol 16 nonce-on keresztül** összefüggően:

```
Gyorsítótár Sor (64 bájt):

Szó0_N0 Szó0_N1 Szó0_N2 ... Szó0_N15
Szó1_N0 Szó1_N1 Szó1_N2 ... Szó1_N15
...
```

**ASCII Diagram**

```
Hagyományos elrendezés:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX elrendezés:

Szó0: [N0][N1][N2][N3]...[N15]
Szó1: [N0][N1][N2][N3]...[N15]
Szó2: [N0][N1][N2][N3]...[N15]
```

---

#### Memória Hozzáférési Előnyök

- Egy gyorsítótár sor ellátja az összes SIMD sávot.
- Megszünteti a szórt-gyűjtés műveleteket.
- Csökkenti a gyorsítótár hibákat.
- Teljesen szekvenciális memória hozzáférés vektorizált számításhoz.
- A GPU-k is profitálnak a 16-nonce igazításból, maximalizálva a gyorsítótár hatékonyságot.

---

#### SIMD Skálázás

| SIMD       | Vektor Szélesség* | Nonce-ok | Feldolgozási Ciklusok Gyorsítótár Soronként |
|------------|-------------------|----------|--------------------------------------------|
| SSE2/AVX   | 128-bit           | 4        | 4 ciklus                                   |
| AVX2       | 256-bit           | 8        | 2 ciklus                                   |
| AVX512     | 512-bit           | 16       | 1 ciklus                                   |

\* Egész szám műveletekhez

---



## Proof-of-Work Skálázás

### Skálázási Szintek
- **X0**: Alap nonce-ok XOR-transzponálás kódolás nélkül (elméleti, nem használt bányászathoz)
- **X1**: XOR-transzponálás alapvonal — első megerősített formátum (1× munka)
- **X2**: 2× X1 munka (XOR 2 warp-on keresztül)
- **X3**: 4× X1 munka (XOR 4 warp-on keresztül)
- **…**
- **Xn**: 2^(n-1) × X1 munka beágyazva

### Előnyök
- **Állítható PoW nehézség**: Növeli a számítási követelményeket a gyorsabb hardverrel lépést tartva
- **Formátum hosszú élettartam**: Lehetővé teszi a bányászati nehézség rugalmas skálázását idővel

### Plot Frissítés / Visszafelé Kompatibilitás

Amikor a hálózat 1-gyel növeli a PoW (Proof of Work) skálát, a meglévő plotok frissítést igényelnek ugyanazon effektív plotméret fenntartásához. Lényegében most kétszer annyi PoW szükséges a plotfájlokban ugyanazon hozzájárulás eléréséhez a fiókjához.

A jó hír az, hogy a plotfájlok létrehozásakor már elvégzett PoW nem veszett el — egyszerűen csak további PoW-t kell hozzáadnia a meglévő fájlokhoz. Nincs szükség újraplotolásra.

Alternatívaként folytathatja a jelenlegi plotok használatát frissítés nélkül, de vegye figyelembe, hogy azok mostantól csak 50%-át fogják hozzájárulni korábbi effektív méretüknek a fiókjához. A bányászszoftver menet közben skálázhat egy plotfájlt.

## Összehasonlítás az Örökség Formátumokkal

| Jellemző | POC1 | POC2 | PoCX |
|----------|------|------|------|
| PoW Eloszlás | ❌ Hibás | ✅ Javított | ✅ Javított |
| XOR-Transzponálás Ellenállás | ❌ Sebezhető | ❌ Sebezhető | ✅ Javított |
| SIMD Optimalizáció | ❌ Nincs | ❌ Nincs | ✅ Fejlett |
| GPU Optimalizáció | ❌ Nincs | ❌ Nincs | ✅ Optimalizált |
| Skálázható Proof-of-Work | ❌ Nincs | ❌ Nincs | ✅ Igen |
| Seed Támogatás | ❌ Nincs | ❌ Nincs | ✅ Igen |

A PoCX formátum a Proof of Capacity plotfájl formátumok jelenlegi csúcstechnológiáját képviseli, minden ismert sebezhetőséget kezel, miközben jelentős teljesítményjavulást biztosít modern hardverhez.

## Hivatkozások és További Olvasmányok

- **POC1/POC2 Háttér**: [Burstcoin Bányászat Áttekintés](https://www.burstcoin.community/burstcoin-mining/) - Átfogó útmutató a hagyományos Proof of Capacity bányászati formátumokhoz
- **POC2×16 Kutatás**: [CIP Bejelentés: POC2×16 - Új optimalizált plot formátum](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Az eredeti SIMD optimalizációs kutatás, amely a PoCX-et inspirálta
- **Shabal Hash Algoritmus**: [A Saphir Projekt: Shabal, Beadvány a NIST Kriptográfiai Hash Algoritmus Versenyére](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - A PoC bányászatban használt Shabal256 algoritmus műszaki specifikációja

---

[← Előző: Bevezetés](1-introduction.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Konszenzus és Bányászat →](3-consensus-and-mining.md)

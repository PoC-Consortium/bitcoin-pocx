[📘 Tartalomjegyzék](index.md) | [Következő: Plotfájl Formátum →](2-plot-format.md)

---

# 1. Fejezet: Bevezetés és Áttekintés

## Mi a Bitcoin-PoCX?

A Bitcoin-PoCX egy Bitcoin Core integráció, amely **Proof of Capacity neXt generation (PoCX)** konszenzus támogatást biztosít. Fenntartja a Bitcoin Core meglévő architektúráját, miközben egy energiahatékony Proof of Capacity bányászati alternatívát tesz lehetővé a Proof of Work teljes helyettesítéseként.

**Fő Megkülönböztetés**: Ez egy **új lánc**, visszamenőleges kompatibilitás nélkül a Bitcoin PoW-val. A PoCX blokkok tervezésükből adódóan nem kompatibilisek a PoW csomópontokkal.

---

## Projekt Identitás

- **Szervezet**: Proof of Capacity Consortium
- **Projekt Név**: Bitcoin-PoCX
- **Teljes Név**: Bitcoin Core PoCX Integrációval
- **Állapot**: Teszthálózati Fázis

---

## Mi a Proof of Capacity?

A Proof of Capacity (PoC) egy konszenzus mechanizmus, ahol a bányászati teljesítmény a **lemezterülettel** arányos a számítási teljesítmény helyett. A bányászok nagy plotfájlokat generálnak előre, amelyek kriptográfiai hash-eket tartalmaznak, majd ezeket a plotokat használják érvényes blokkoldatok megtalálásához.

**Energiahatékonyság**: A plotfájlok egyszer generálódnak és korlátlan ideig újrafelhasználhatók. A bányászat minimális CPU-teljesítményt fogyaszt — elsősorban lemez I/O műveleteket.

**PoCX Fejlesztések**:
- Javított XOR-transzponálás tömörítési támadás (50% idő-memória kompromisszum a POC2-ben)
- 16-nonce igazított elrendezés modern hardverhez
- Skálázható proof-of-work a plotfájl generálásban (Xn skálázási szintek)
- Natív C++ integráció közvetlenül a Bitcoin Core-ba
- Time Bending algoritmus a jobb blokkidő eloszláshoz

---

## Architektúra Áttekintés

### Repository Struktúra

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.2 + PoCX integráció
│   └── src/pocx/        # PoCX implementáció
├── pocx/                # PoCX keretrendszer (almodul, csak olvasható)
└── docs/                # Ez a dokumentáció
```

### Integrációs Filozófia

**Minimális Integrációs Felület**: A módosítások a `/src/pocx/` könyvtárba vannak izolálva, tiszta kapcsolódási pontokkal a Bitcoin Core validációs, bányászati és RPC rétegeihez.

**Funkció Jelzés**: Minden módosítás `#ifdef ENABLE_POCX` előfeldolgozó direktívák alatt. A Bitcoin Core normálisan fordul, ha ki van kapcsolva.

**Upstream Kompatibilitás**: Rendszeres szinkronizáció a Bitcoin Core frissítésekkel az izolált integrációs pontokon keresztül.

**Natív C++ Implementáció**: Skaláris kriptográfiai algoritmusok (Shabal256, scoop számítás, tömörítés) közvetlenül integrálva a Bitcoin Core-ba a konszenzus validációhoz.

---

## Fő Jellemzők

### 1. Teljes Konszenzus Csere

- **Blokk Szerkezet**: PoCX-specifikus mezők helyettesítik a PoW nonce-t és a difficulty biteket
  - Generációs aláírás (determinisztikus bányászati entrópia)
  - Alap célérték (nehézség inverze)
  - PoCX bizonyíték (account ID, seed, nonce)
  - Blokk aláírás (plot tulajdonjog bizonyítása)

- **Validáció**: 5-lépcsős validációs folyamat a fejléc ellenőrzéstől a blokk csatlakoztatásig

- **Nehézség Beállítás**: Blokkonkénti beállítás a legutóbbi alap célértékek mozgóátlaga alapján

### 2. Time Bending Algoritmus

**Probléma**: A hagyományos PoC blokkidők exponenciális eloszlást követnek, ami hosszú blokkokhoz vezet, amikor egyetlen bányász sem talál jó megoldást.

**Megoldás**: Eloszlás transzformáció exponenciálisról chi-négyzetre köbgyök használatával: `Y = skála × (X^(1/3))`.

**Hatás**: Extremely fast blocks are delayed and extremely slow blocks are shortened, reducing variance while preserving average block time at 120 seconds.

**Részletek**: [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md)

### 3. Kovácsolási Megbízások Rendszere

**Képesség**: A plot tulajdonosok kovácsolási jogokat delegálhatnak más címekre, miközben megtartják a plot tulajdonjogát.

**Felhasználási Esetek**:
- Pool bányászat (plotok pool címhez rendelése)
- Hideg tárolás (bányász kulcs elkülönítése a plot tulajdonjogtól)
- Többrésztvevős bányászat (megosztott infrastruktúra)

**Architektúra**: Csak OP_RETURN tervezés — nincs speciális UTXO, a megbízások külön vannak nyilvántartva a chainstate adatbázisban.

**Részletek**: [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md)

### 4. Védelmi Kovácsolás

**Probléma**: A gyors órák időzítési előnyt biztosíthatnak a 15 másodperces jövőbeli tűréshatáron belül.

**Megoldás**: Amikor versengő blokkot kap azonos magasságon, automatikusan ellenőrzi a helyi minőséget. Ha jobb, azonnal kovácsol.

**Hatás**: Megszünteti az óramanipuláció ösztönzését — a gyors órák csak akkor segítenek, ha már a legjobb megoldással rendelkezik.

**Részletek**: [5. Fejezet: Időzítési Biztonság](5-timing-security.md)

### 5. Dinamikus Tömörítési Skálázás

**Gazdasági Összehangolás**: A skálázási szint követelmények exponenciális ütemterv szerint növekednek (4., 12., 28., 60., 124. év = 1., 3., 7., 15., 31. felezés).

**Hatás**: Ahogy a blokkjutalmak csökkennek, a plotfájl generálási nehézség növekszik. Fenntartja a biztonsági határt a plot létrehozási és keresési költségek között.

**Megakadályozza**: A kapacitás inflációt a gyorsabb hardver miatt az idő múlásával.

**Részletek**: [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md)

---

## Tervezési Filozófia

### Kód Biztonság

- Védelmi programozási gyakorlatok végig
- Átfogó hibakezelés a validációs útvonalakon
- Nincsenek beágyazott zárak (holtpont megelőzés)
- Atomi adatbázis műveletek (UTXO + megbízások együtt)

### Moduláris Architektúra

- Tiszta elválasztás a Bitcoin Core infrastruktúra és a PoCX konszenzus között
- A PoCX keretrendszer biztosítja a kriptográfiai primitíveket
- A Bitcoin Core biztosítja a validációs keretrendszert, adatbázist, hálózatkezelést

### Teljesítmény Optimalizációk

- Gyors-hiba validációs sorrend (olcsó ellenőrzések először)
- Egyetlen kontextus lekérés beküldésenként (nincs ismételt cs_main beszerzés)
- Atomi adatbázis műveletek a konzisztenciáért

### Reorganizáció Biztonság

- Teljes visszavonási adatok a megbízás állapotváltozásokhoz
- Kovácsolási állapot visszaállítás lánccsúcs változáskor
- Elavultság észlelés minden validációs ponton

---

## A PoCX Különbségei a Proof of Work-tól

| Aspektus | Bitcoin (PoW) | Bitcoin-PoCX |
|----------|---------------|--------------|
| **Bányászati Erőforrás** | Számítási teljesítmény (hash ráta) | Lemezterület (kapacitás) |
| **Energiafogyasztás** | Magas (folyamatos hash-elés) | Alacsony (csak lemez I/O) |
| **Bányászati Folyamat** | Nonce keresés hash < célérték | Nonce keresés határidő < eltelt idő |
| **Nehézség** | `bits` mező, minden 2016 blokkonként állítva | `base_target` mező, minden blokkonként állítva |
| **Blokkidő** | ~10 perc (exponenciális eloszlás) | 120 másodperc (time-bended, csökkentett szórás) |
| **Jutalom** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Hardver** | ASIC-ok (specializált) | HDD-k (általános hardver) |
| **Bányász Identitás** | Anonim | Plot tulajdonos vagy delegált |

---

## Rendszerkövetelmények

### Csomópont Üzemeltetés

**Megegyezik a Bitcoin Core-ral**:
- **CPU**: Modern x86_64 processzor
- **Memória**: 4-8 GB RAM
- **Tárhely**: Új lánc, jelenleg üres (körülbelül 5× gyorsabban nőhet, mint a Bitcoin a 2 perces blokkok és a megbízás adatbázis miatt)
- **Hálózat**: Stabil internetkapcsolat
- **Óra**: NTP szinkronizáció ajánlott az optimális működéshez

**Megjegyzés**: Plotfájlok NEM szükségesek a csomópont működéséhez.

### Bányászati Követelmények

**További követelmények bányászathoz**:
- **Plotfájlok**: Előre generálva `pocx_plotter` használatával (referencia implementáció)
- **Bányász Szoftver**: `pocx_miner` (referencia implementáció) RPC-n keresztül csatlakozik
- **Tárca**: `bitcoind` vagy `bitcoin-qt` privát kulcsokkal a bányász címhez. Pool bányászat nem igényel helyi tárcát.

---

## Első Lépések

### 1. Bitcoin-PoCX Fordítása

```bash
# Klónozás almodulokkal
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build
cmake -B build
cmake --build build
```

**Details**: See `bitcoin/doc/build-*.md` for platform-specific build instructions

### 2. Csomópont Futtatása

**Csak csomópont**:
```bash
./build/bin/bitcoind
# vagy
./build/bin/bitcoin-qt
```

**Bányászathoz** (engedélyezi az RPC hozzáférést külső bányászoknak):
```bash
./build/bin/bitcoind
# vagy
./build/bin/bitcoin-qt -server
```

**Részletek**: [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md)

### 3. Plotfájlok Generálása

Használja a `pocx_plotter`-t (referencia implementáció) PoCX formátumú plotfájlok generálásához.

**Részletek**: [2. Fejezet: Plotfájl Formátum](2-plot-format.md)

### 4. Bányászat Beállítása

Használja a `pocx_miner`-t (referencia implementáció) a csomópont RPC interfészéhez való csatlakozáshoz.

**Részletek**: [7. Fejezet: RPC Referencia](7-rpc-reference.md) és [8. Fejezet: Tárca Útmutató](8-wallet-guide.md)

---

## Attribúció

### Plotfájl Formátum

A POC2 formátumon alapul (Burstcoin) fejlesztésekkel:
- Javított biztonsági hiba (XOR-transzponálás tömörítési támadás)
- Skálázható proof-of-work
- SIMD-optimalizált elrendezés
- Seed funkcionalitás

### Forrásprojektek

- **pocx_miner**: Referencia implementáció a [scavenger](https://github.com/PoC-Consortium/scavenger) alapján
- **pocx_plotter**: Referencia implementáció az [engraver](https://github.com/PoC-Consortium/engraver) alapján

**Teljes Attribúció**: [2. Fejezet: Plotfájl Formátum](2-plot-format.md)

---

## Műszaki Specifikációk Összefoglaló

- **Blokkidő**: 120 másodperc (mainnet), 1 másodperc (regtest)
- **Blokk Jutalom**: 10 BTC kezdetben, felezés minden 1050000 blokkonként (~4 év)
- **Teljes Kínálat**: ~21 millió BTC (megegyezik a Bitcoin-nal)
- **Jövőbeli Tűrés**: 15 másodperc (legfeljebb 15mp-re előre lévő blokkok elfogadva)
- **Óra Figyelmeztetés**: 10 másodperc (figyelmezteti az üzemeltetőket időeltérésre)
- **Megbízás Késleltetés**: 30 blokk (~1 óra)
- **Visszavonás Késleltetés**: 720 blokk (~24 óra)
- **Cím Formátum**: Csak P2WPKH (bech32, pocx1q...) a PoCX bányászati műveletekhez és kovácsolási megbízásokhoz

---

## Kód Szervezés

**Bitcoin Core Módosítások**: Minimális változtatások a core fájlokban, `#ifdef ENABLE_POCX` direktívával jelölve

**Új PoCX Implementáció**: Izolálva az `src/pocx/` könyvtárban

---

## Biztonsági Megfontolások

### Időzítési Biztonság

- 15 másodperces jövőbeli tűrés megakadályozza a hálózat fragmentációt
- 10 másodperces figyelmeztetési küszöb riasztja az üzemeltetőket óraeltérésre
- Védelmi kovácsolás megszünteti az óramanipuláció ösztönzését
- Time Bending csökkenti az időzítési szórás hatását

**Részletek**: [5. Fejezet: Időzítési Biztonság](5-timing-security.md)

### Megbízás Biztonság

- Csak OP_RETURN tervezés (nincs UTXO manipuláció)
- Tranzakció aláírás bizonyítja a plot tulajdonjogát
- Aktiválási késleltetések megakadályozzák a gyors állapotmanipulációt
- Reorganizáció-biztos visszavonási adatok minden állapotváltozáshoz

**Részletek**: [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md)

### Konszenzus Biztonság

- Aláírás kizárva a blokk hash-ből (megakadályozza a módosíthatóságot)
- Korlátozott aláírás méretek (megakadályozza a DoS-t)
- Tömörítési határok validálása (megakadályozza a gyenge bizonyítékokat)
- Blokkonkénti nehézség beállítás (reagál a kapacitásváltozásokra)

**Részletek**: [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md)

---

## Hálózati Állapot

**Mainnet**: Még nem indult
**Tesztnet**: Elérhető tesztelésre
**Regtest**: Teljesen működőképes fejlesztéshez

**Genezis Blokk Paraméterek**: [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md)

---

## Következő Lépések

**A PoCX Megértéséhez**: Folytassa a [2. Fejezet: Plotfájl Formátum](2-plot-format.md) részben a plotfájl szerkezet és formátum fejlődésének megismeréséhez.

**Bányászat Beállításához**: Ugorjon a [7. Fejezet: RPC Referencia](7-rpc-reference.md) részhez az integrációs részletekért.

**Csomópont Futtatásához**: Tekintse át a [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md) részt a konfigurációs lehetőségekért.

---

[📘 Tartalomjegyzék](index.md) | [Következő: Plotfájl Formátum →](2-plot-format.md)

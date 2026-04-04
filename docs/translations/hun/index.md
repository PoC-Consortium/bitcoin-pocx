# Bitcoin-PoCX Műszaki Dokumentáció

**Verzió**: 1.0
**Bitcoin Core Alapverzió**: v30.2
**Állapot**: Teszthálózati Fázis
**Utolsó Frissítés**: 2025-12-25

---

## A Dokumentációról

Ez a Bitcoin-PoCX teljes műszaki dokumentációja, amely egy Bitcoin Core integráció, ami a Proof of Capacity neXt generation (PoCX) konszenzus támogatást biztosítja. A dokumentáció böngészhető útmutatóként van felépítve, összekapcsolt fejezetekkel, amelyek a rendszer minden aspektusát lefedik.

**Célközönség**:
- **Csomópont-üzemeltetők**: 1., 5., 6., 8. fejezet
- **Bányászok**: 2., 3., 7. fejezet
- **Fejlesztők**: Minden fejezet
- **Kutatók**: 3., 4., 5. fejezet




## Fordítások

| | | | | | |
|---|---|---|---|---|---|
| [🇬🇧 Angol](../../index.md) | [🇸🇦 Arab](../ara/index.md) | [🇧🇬 Bolgár](../bul/index.md) | [🇨🇿 Cseh](../ces/index.md) | [🇩🇰 Dán](../dan/index.md) | [🇪🇪 Észt](../est/index.md) |
| [🇵🇭 Filippínó](../fil/index.md) | [🇫🇮 Finn](../fin/index.md) | [🇫🇷 Francia](../fra/index.md) | [🇬🇷 Görög](../ell/index.md) | [🇮🇱 Héber](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) |
| [🇳🇱 Holland](../nld/index.md) | [🇮🇩 Indonéz](../ind/index.md) | [🇯🇵 Japán](../jpn/index.md) | [🇨🇳 Kínai](../zho/index.md) | [🇰🇷 Koreai](../kor/index.md) | [🇵🇱 Lengyel](../pol/index.md) |
| [🇱🇻 Lett](../lav/index.md) | [🇱🇹 Litván](../lit/index.md) | [🇩🇪 Német](../deu/index.md) | [🇳🇴 Norvég](../nor/index.md) | [🇮🇹 Olasz](../ita/index.md) | [🇷🇺 Orosz](../rus/index.md) |
| [🇵🇹 Portugál](../por/index.md) | [🇷🇴 Román](../ron/index.md) | [🇪🇸 Spanyol](../spa/index.md) | [🇸🇪 Svéd](../swe/index.md) | [🇰🇪 Szuahéli](../swa/index.md) | [🇷🇸 Szerb](../srp/index.md) |
| [🇹🇷 Török](../tur/index.md) | [🇺🇦 Ukrán](../ukr/index.md) | [🇻🇳 Vietnámi](../vie/index.md) | | | |


---

## Tartalomjegyzék

### I. Rész: Alapok

**[1. Fejezet: Bevezetés és Áttekintés](1-introduction.md)**
Projekt áttekintés, architektúra, tervezési filozófia, fő jellemzők, és a PoCX eltérései a Proof of Work-tól.

**[2. Fejezet: Plotfájl Formátum](2-plot-format.md)**
A PoCX plotfájl formátum teljes specifikációja, beleértve a SIMD optimalizációt, a proof-of-work skálázást és a POC1/POC2 formátum fejlődését.

**[3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md)**
A PoCX konszenzus mechanizmus teljes műszaki specifikációja: blokkszerkezet, generációs aláírás, alap célérték beállítása, bányászati folyamat, validációs folyamat és Time Bending algoritmus.

---

### II. Rész: Haladó Funkciók

**[4. Fejezet: Kovácsolási Megbízások Rendszere](4-forging-assignments.md)**
OP_RETURN-alapú architektúra a kovácsolási jogok delegálásához: tranzakciós szerkezet, adatbázis-tervezés, állapotgép, reorganizáció kezelés és RPC interfész.

**[5. Fejezet: Időszinkronizáció és Biztonság](5-timing-security.md)**
Óraeltérés-tűrés, védelmi kovácsolási mechanizmus, óramanipuláció elleni védelem és időzítéssel kapcsolatos biztonsági megfontolások.

**[6. Fejezet: Hálózati Paraméterek](6-network-parameters.md)**
Chainparams konfiguráció, genezis blokk, konszenzus paraméterek, coinbase szabályok, dinamikus skálázás és gazdasági modell.

---

### III. Rész: Használat és Integráció

**[7. Fejezet: RPC Interfész Referencia](7-rpc-reference.md)**
Teljes RPC parancs referencia bányászathoz, megbízásokhoz és blokklánc lekérdezésekhez. Alapvető a bányász és pool integrációhoz.

**[8. Fejezet: Tárca és GUI Útmutató](8-wallet-guide.md)**
Felhasználói útmutató a Bitcoin-PoCX Qt tárcához: kovácsolási megbízás párbeszédpanel, tranzakciótörténet, bányászat beállítása és hibaelhárítás.

---

## Gyors Navigáció

### Csomópont-üzemeltetőknek
→ Kezdje az [1. Fejezet: Bevezetés](1-introduction.md) résszel
→ Majd tekintse át a [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md) részt
→ Konfigurálja a bányászatot a [8. Fejezet: Tárca Útmutató](8-wallet-guide.md) segítségével

### Bányászoknak
→ Értse meg a [2. Fejezet: Plotfájl Formátum](2-plot-format.md) részt
→ Ismerje meg a folyamatot a [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md) részben
→ Integrálja a [7. Fejezet: RPC Referencia](7-rpc-reference.md) használatával

### Pool Üzemeltetőknek
→ Tekintse át a [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md) részt
→ Tanulmányozza a [7. Fejezet: RPC Referencia](7-rpc-reference.md) részt
→ Implementáljon megbízás RPC-k és submit_nonce használatával

### Fejlesztőknek
→ Olvassa végig az összes fejezetet sorrendben
→ Hivatkozzon a dokumentumokban szereplő implementációs fájlokra
→ Vizsgálja meg az `src/pocx/` könyvtárstruktúrát
→ Készítsen kiadásokat a [GUIX](../bitcoin/contrib/guix/README.md) segítségével

---

## Dokumentációs Konvenciók

**Fájl Hivatkozások**: Az implementációs részletek forrásfájlokra hivatkoznak mint `útvonal/fájl.cpp:sor`

**Kód Integráció**: Minden módosítás `#ifdef ENABLE_POCX` direktívával van védve

**Kereszthivatkozások**: A fejezetek relatív markdown linkekkel hivatkoznak a kapcsolódó szakaszokra

**Műszaki Szint**: A dokumentáció feltételezi a Bitcoin Core és a C++ fejlesztés ismeretét

---

## Fordítás

### Fejlesztői Build

```bash
# Klónozás almodulokkal
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configure
cmake -B build

# Fordítás
cmake --build build -j$(nproc)
```

**Build Változatok**:
```bash
# Qt GUI-val
cmake -B build -DBUILD_GUI=ON

# Debug build
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

**Függőségek**: Szabványos Bitcoin Core build függőségek. Lásd a [Bitcoin Core build dokumentációt](https://github.com/bitcoin/bitcoin/tree/master/doc#building) a platform-specifikus követelményekért.

### Kiadási Buildek

Reprodukálható kiadási binárisokhoz használja a GUIX build rendszert: Lásd [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## További Források

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Keretrendszer**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Kapcsolódó Projektek**:
- Plotter: Az [engraver](https://github.com/PoC-Consortium/engraver) alapján
- Bányász: A [scavenger](https://github.com/PoC-Consortium/scavenger) alapján

---

## A Dokumentáció Használata

**Soros Olvasás**: A fejezetek sorrendben történő olvasásra lettek tervezve, az előző fogalmakra építve.

**Referencia Olvasás**: Használja a tartalomjegyzéket specifikus témákhoz való közvetlen navigáláshoz. Minden fejezet önálló, kereszthivatkozásokkal a kapcsolódó anyagokra.

**Böngésző Navigáció**: Nyissa meg az `index.md` fájlt egy markdown megjelenítőben vagy böngészőben. Minden belső link relatív és offline is működik.

**PDF Export**: Ez a dokumentáció egyetlen PDF-be összefűzhető offline olvasáshoz.

---

## Projekt Állapot

**✅ Funkciók Teljesek**: Minden konszenzus szabály, bányászat, megbízások és tárca funkciók implementálva.

**✅ Dokumentáció Teljes**: Mind a 8 fejezet elkészült és a kódbázissal összevetett.

**🔬 Teszthálózat Aktív**: Jelenleg teszthálózati fázisban a közösségi teszteléshez.

---

## Közreműködés

A dokumentációhoz való hozzájárulásokat szívesen fogadjuk. Kérjük, tartsa be:
- Műszaki pontosság a bőbeszédűség helyett
- Rövid, lényegre törő magyarázatok
- Nincs kód vagy pszeudokód a dokumentációban (helyette forrásfájlokra hivatkozzon)
- Csak az implementált funkciók (nincs spekulatív funkció)

---

## Licenc

A Bitcoin-PoCX a Bitcoin Core MIT licencét örökli. Lásd `bitcoin/COPYING` a repository gyökerében.

PoCX keretrendszer attribúció a [2. Fejezet: Plotfájl Formátum](2-plot-format.md) részben dokumentálva.

---

**Olvasás Megkezdése**: [1. Fejezet: Bevezetés és Áttekintés →](1-introduction.md)

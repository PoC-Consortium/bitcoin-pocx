[← Előző: Kovácsolási Megbízások](4-forging-assignments.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Hálózati Paraméterek →](6-network-parameters.md)

---

# 5. Fejezet: Időszinkronizáció és Biztonság

## Áttekintés

A PoCX konszenzus pontos időszinkronizációt igényel a hálózaton keresztül. Ez a fejezet dokumentálja az idővel kapcsolatos biztonsági mechanizmusokat, az óraeltérés tűrését és a védelmi kovácsolási viselkedést.

**Fő Mechanizmusok**:
- 15 másodperces jövőbeli tűrés a blokk időbélyegekhez
- 10 másodperces óraeltérés figyelmeztetési rendszer
- Védelmi kovácsolás (óramanipuláció elleni védelem)
- Time Bending algoritmus integráció

---

## Tartalomjegyzék

1. [Időszinkronizációs Követelmények](#időszinkronizációs-követelmények)
2. [Óraeltérés Észlelés és Figyelmeztetések](#óraeltérés-észlelés-és-figyelmeztetések)
3. [Védelmi Kovácsolási Mechanizmus](#védelmi-kovácsolási-mechanizmus)
4. [Biztonsági Fenyegetés Elemzés](#biztonsági-fenyegetés-elemzés)
5. [Legjobb Gyakorlatok Csomópont-üzemeltetőknek](#legjobb-gyakorlatok-csomópont-üzemeltetőknek)

---

## Időszinkronizációs Követelmények

### Konstansok és Paraméterek

**Bitcoin-PoCX Konfiguráció:**
```cpp
// src/chain.h
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 másodperc

// src/node/timeoffsets.h
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 másodperc
```

### Validációs Ellenőrzések

**Blokk Időbélyeg Validáció** (`src/validation.cpp:ContextualCheckBlockHeader()`):
```cpp
// 1. Monoton ellenőrzés: időbélyeg >= előző blokk időbélyeg
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Jövő ellenőrzés: időbélyeg <= most + 15 másodperc
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Határidő ellenőrzés: eltelt idő >= határidő
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (poc_time > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Óraeltérés Hatás Táblázat

| Óra Eltolás | Szinkronizálhat? | Bányászhat? | Validációs Állapot | Versenyképességi Hatás |
|-------------|------------------|-------------|---------------------|------------------------|
| -30mp lassú | ❌ NEM - Jövő ellenőrzés sikertelen | N/A | **HALOTT CSOMÓPONT** | Nem tud részt venni |
| -14mp lassú | ✅ Igen | ✅ Igen | Késői kovácsolás, validáción átmegy | Versenyeket veszít |
| 0mp tökéletes | ✅ Igen | ✅ Igen | Optimális | Optimális |
| +14mp gyors | ✅ Igen | ✅ Igen | Korai kovácsolás, validáción átmegy | Versenyeket nyer ⚠️ |
| +16mp gyors | ✅ Igen | ❌ Jövő ellenőrzés sikertelen | Blokkok nem terjeszthetők | Szinkronizálhat, nem bányászhat |

**Fő Felismerés**: A 15 másodperces ablak szimmetrikus a részvételhez (±14.9mp), de a gyors órák tisztességtelen versenyelőnyt biztosítanak a tűréshatáron belül.

### Time Bending Integráció

A Time Bending algoritmus (részletesen a [3. Fejezet](3-consensus-and-mining.md#time-bending-számítás)) köbgyökkel transzformálja a nyers határidőket:

```
time_bended_deadline = skála × (deadline_seconds)^(1/3)
```

**Kölcsönhatás az Óraeltéréssel**:
- A jobb megoldások hamarabb kovácsolódnak (a köbgyök felerősíti a minőségbeli különbségeket)
- Az óraeltérés befolyásolja a kovácsolási időt a hálózathoz képest
- A védelmi kovácsolás biztosítja a minőség-alapú versenyt az időzítési variancia ellenére

---

## Óraeltérés Észlelés és Figyelmeztetések

### Figyelmeztetési Rendszer

A Bitcoin-PoCX figyeli az időeltolást a helyi csomópont és a hálózati társak között.

**Figyelmeztető Üzenet** (amikor az eltérés meghaladja a 10 másodpercet):
> "A számítógép dátuma és ideje több mint 10 másodperccel eltérni látszik a hálózattól, ez PoCX konszenzus hibához vezethet. Kérjük, ellenőrizze a rendszeróráját."

**Implementáció**: `src/node/timeoffsets.cpp`

### Tervezési Indoklás

**Miért 10 másodperc?**
- 5 másodperces biztonsági puffert biztosít a 15 másodperces tűréshatár előtt
- Szigorúbb, mint a Bitcoin Core alapértelmezése (10 perc)
- Megfelelő a PoC időzítési követelményeihez

**Megelőző Megközelítés**:
- Korai figyelmeztetés kritikus hiba előtt
- Lehetővé teszi az üzemeltetőknek a proaktív javítást
- Csökkenti a hálózati fragmentációt idővel kapcsolatos hibákból

---

## Védelmi Kovácsolási Mechanizmus

### Mi Ez

A védelmi kovácsolás szabványos bányász viselkedés a Bitcoin-PoCX-ben, amely megszünteti az időzítés-alapú előnyöket a blokkgyártásban. Amikor a bányász versengő blokkot kap azonos magasságon, automatikusan ellenőrzi, hogy van-e jobb megoldása. Ha igen, azonnal kovácsol, biztosítva a minőség-alapú versenyt az óramanipuláció-alapú verseny helyett.

### A Probléma

A PoCX konszenzus legfeljebb 15 másodperccel a jövőbe mutató időbélyegű blokkokat engedélyez. Ez a tűrés szükséges a globális hálózati szinkronizációhoz. Azonban lehetőséget teremt az óramanipulációra:

**Védelmi Kovácsolás Nélkül:**
- A Bányász: Helyes idő, 800-as minőség (jobb), megfelelő határidőt vár
- B Bányász: Gyors óra (+14mp), 1000-es minőség (rosszabb), 14 másodperccel korábban kovácsol
- Eredmény: B Bányász nyeri a versenyt a gyengébb proof-of-capacity munka ellenére

**A Probléma:** Az óramanipuláció előnyt biztosít még rosszabb minőség mellett is, aláássa a proof-of-capacity elvet.

### A Megoldás: Kétszintű Védelem

#### 1. Szint: Óraeltérés Figyelmeztetés (Megelőző)

A Bitcoin-PoCX figyeli az időeltolást a csomópont és a hálózati társak között. Ha az óra több mint 10 másodpercet tér el a hálózati konszenzustól, figyelmeztetést kap, amely jelzi az óraproblémák kijavítását, mielőtt azok problémákat okoznának.

#### 2. Szint: Védelmi Kovácsolás (Reaktív)

Amikor másik bányász blokkot publikál ugyanazon a magasságon, ahol bányászik:

1. **Észlelés**: A csomópont azonosítja az azonos magasságú versenyt
2. **Validáció**: Kinyeri és validálja a versengő blokk minőségét
3. **Összehasonlítás**: Ellenőrzi, hogy az Ön minősége jobb-e
4. **Válasz**: Ha jobb, azonnal kovácsolja az Ön blokkját

**Eredmény:** A hálózat mindkét blokkot megkapja és a jobbat választja szabványos elágazás-feloldással.

### Hogyan Működik

#### Forgatókönyv: Azonos Magasságú Verseny

```
150mp Idő: B Bányász (óra +10mp) kovácsol 1000-es minőséggel
           → Blokk időbélyeg 160mp mutat (10mp a jövőben)

150mp Idő: Az Ön csomópontja megkapja B Bányász blokkját
           → Észleli: azonos magasság, 1000-es minőség
           → Önnek van: 800-as minőség (jobb!)
           → Akció: Azonnali kovácsolás helyes időbélyeggel (150mp)

152mp Idő: A hálózat validálja mindkét blokkot
           → Mindkettő érvényes (15mp tűrésen belül)
           → 800-as minőség nyer (alacsonyabb = jobb)
           → Az Ön blokkja lesz a lánccsúcs
```

#### Forgatókönyv: Valódi Reorg

```
Az Ön bányászati magassága 100, versenyző 99-es blokkot publikál
→ Nem azonos magasságú verseny
→ Védelmi kovácsolás NEM aktiválódik
→ Normál reorg kezelés folytatódik
```

### Előnyök

**Nulla Ösztönzés az Óramanipulációra**
- A gyors órák csak akkor segítenek, ha egyébként is a legjobb minőséggel rendelkezik
- Az óramanipuláció gazdaságilag értelmetlenné válik

**Minőség-Alapú Verseny Érvényesítve**
- Kényszeríti a bányászokat, hogy tényleges proof-of-capacity munkával versenyezzenek
- Megőrzi a PoCX konszenzus integritását

**Hálózati Biztonság**
- Ellenáll az időzítés-alapú játékstratégiáknak
- Nincs szükség konszenzus változtatásra - tisztán bányász viselkedés

**Teljesen Automatikus**
- Nincs szükség konfigurációra
- Csak szükség esetén aktiválódik
- Szabványos viselkedés minden Bitcoin-PoCX csomópontban

### Kompromisszumok

**Minimális Árva Ráta Növekedés**
- Szándékos - a támadó blokkok árván maradnak
- Csak tényleges óramanipulációs kísérletek során fordul elő
- A minőség-alapú elágazás-feloldás természetes eredménye

**Rövid Hálózati Verseny**
- A hálózat rövid ideig két versengő blokkot lát
- Másodpercek alatt megoldódik szabványos validációval
- Ugyanaz a viselkedés, mint az egyidejű bányászat a Bitcoin-ban

### Műszaki Részletek

**Teljesítmény Hatás:** Elhanyagolható
- Csak azonos magasságú versenynél aktiválódik
- Memóriában lévő adatokat használ (nincs lemez I/O)
- Validáció milliszekundumok alatt befejeződik

**Erőforrás Használat:** Minimális
- Compact implementation in `scheduler.cpp` and `defensive_forge.cpp`
- Újrafelhasználja a meglévő validációs infrastruktúrát
- Egyetlen zár beszerzés

**Kompatibilitás:** Teljes
- Nincs konszenzus szabály változás
- Működik minden Bitcoin Core funkcióval
- Opcionális monitorozás debug naplókon keresztül

**Állapot**: Aktív minden Bitcoin-PoCX kiadásban
**Első Bevezetés**: 2025-10-10

---

## Biztonsági Fenyegetés Elemzés

### Gyors Óra Támadás (Védelmi Kovácsolással Mérsékelve)

**Támadási Vektor**:
Egy bányász **+14mp előre járó** órával:
1. Normálisan fogad blokkokat (régebbinek tűnnek neki)
2. Azonnal kovácsol blokkokat, amikor a határidő lejár
3. Blokkokat közvetít, amelyek 14mp "korainak" tűnnek a hálózatnak
4. **Blokkok elfogadva** (15mp tűrésen belül)
5. **Versenyeket nyer** becsületes bányászok ellen

**Hatás Védelmi Kovácsolás Nélkül**:
Az előny 14.9 másodpercre korlátozott (nem elég jelentős PoC munka kihagyásához), de konzisztens előnyt biztosít blokk versenyekben.

**Mérséklés (Védelmi Kovácsolás)**:
- Becsületes bányászok észlelik az azonos magasságú versenyt
- Minőségi értékeket hasonlítanak össze
- Azonnal kovácsolnak, ha a minőség jobb
- **Eredmény**: A gyors óra csak akkor segít, ha már a legjobb minőséggel rendelkezik
- **Ösztönzés**: Nulla - az óramanipuláció gazdaságilag értelmetlenné válik

### Lassú Óra Hiba (Kritikus)

**Hiba Mód**:
Egy **>15mp-cel lemaradó** csomópont katasztrofális:
- Nem tudja validálni a bejövő blokkokat (jövő ellenőrzés sikertelen)
- Elszigetelődik a hálózattól
- Nem tud bányászni vagy szinkronizálni

**Mérséklés**:
- Erős figyelmeztetés 10mp eltérésnél 5 másodperces puffert biztosít a kritikus hiba előtt
- Az üzemeltetők proaktívan javíthatják az óraproblémákat
- Tiszta hibaüzenetek segítik a hibaelhárítást

---

## Legjobb Gyakorlatok Csomópont-üzemeltetőknek

### Időszinkronizáció Beállítása

**Ajánlott Konfiguráció**:
1. **NTP Engedélyezése**: Használjon Network Time Protocol-t az automatikus szinkronizációhoz
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Állapot ellenőrzése
   timedatectl status
   ```

2. **Óra Pontosság Ellenőrzése**: Rendszeresen ellenőrizze az időeltolást
   ```bash
   # NTP szinkronizációs állapot ellenőrzése
   ntpq -p

   # Vagy chrony-val
   chronyc tracking
   ```

3. **Figyelmeztetések Figyelése**: Figyelje a Bitcoin-PoCX óraeltérés figyelmeztetéseket a naplókban

### Bányászoknak

**Nincs Szükség Beavatkozásra**:
- A funkció mindig aktív
- Automatikusan működik
- Csak tartsa pontosan a rendszeróráját

**Legjobb Gyakorlatok**:
- Használjon NTP időszinkronizációt
- Figyelje az óraeltérés figyelmeztetéseket
- Azonnal foglalkozzon a figyelmeztetésekkel, ha megjelennek

**Elvárt Viselkedés**:
- Szóló bányászat: Védelmi kovácsolás ritkán aktiválódik (nincs verseny)
- Hálózati bányászat: Véd az óramanipulációs kísérletek ellen
- Átlátható működés: A legtöbb bányász soha nem veszi észre

### Hibaelhárítás

**Figyelmeztetés: "10 másodperces eltérés a szinkronból"**
- Akció: Ellenőrizze és javítsa a rendszeróra szinkronizációt
- Hatás: 5 másodperces puffer a kritikus hiba előtt
- Eszközök: NTP, chrony, systemd-timesyncd

**Hiba: "time-too-new" bejövő blokkoknál**
- Ok: Az óra >15 másodperccel lassú
- Hatás: Nem tudja validálni a blokkokat, csomópont elszigetelődik
- Javítás: Azonnal szinkronizálja a rendszerórát

**Hiba: Nem tudja terjeszteni a kovácsolt blokkokat**
- Ok: Az óra >15 másodperccel gyors
- Hatás: Blokkokat a hálózat elutasítja
- Javítás: Azonnal szinkronizálja a rendszerórát

---

## Tervezési Döntések és Indoklás

### Miért 15 Másodperces Tűrés?

**Indoklás**:
- A Bitcoin-PoCX változó határidő időzítése kevésbé időkritikus, mint a fix-időzítésű konszenzus
- 15mp megfelelő védelmet biztosít, miközben megakadályozza a hálózati fragmentációt

**Kompromisszumok**:
- Szűkebb tűrés = több hálózati fragmentáció kisebb eltérésből
- Lazább tűrés = több lehetőség időzítési támadásokra
- 15mp egyensúlyoz a biztonság és robusztusság között

### Miért 10 Másodperces Figyelmeztetés?

**Indoklás**:
- 5 másodperces biztonsági puffert biztosít
- Megfelelőbb a PoC-hez, mint a Bitcoin 10 perces alapértelmezése
- Lehetővé teszi a proaktív javításokat kritikus hiba előtt

### Miért Védelmi Kovácsolás?

**Kezelt Probléma**:
- 15 másodperces tűrés gyors-óra előnyt tesz lehetővé
- A minőség-alapú konszenzust alááshatta az időzítési manipuláció

**Megoldás Előnyei**:
- Nulla költségű védelem (nincs konszenzus változás)
- Automatikus működés
- Megszünteti a támadási ösztönzést
- Megőrzi a proof-of-capacity elveket

### Miért Nincs Hálózaton Belüli Időszinkronizáció?

**Biztonsági Indoklás**:
- A modern Bitcoin Core eltávolította a társ-alapú idő beállítást
- Sebezhető Sybil támadásokra az észlelt hálózati idő ellen
- A PoCX szándékosan kerüli a hálózat-belső időforrásokra támaszkodást
- A rendszeróra megbízhatóbb, mint a társ konszenzus
- Az üzemeltetőknek NTP-vel vagy egyenértékű külső időforrással kell szinkronizálniuk
- A csomópontok figyelik saját eltérésüket és figyelmeztetéseket adnak, ha a helyi óra eltér a legutóbbi blokk időbélyegektől

---

## Implementációs Hivatkozások

**Központi Fájlok**:
- Idő validáció: `src/validation.cpp:ContextualCheckBlockHeader()`
- Jövőbeli tűrés konstans: `src/chain.h`
- Figyelmeztetési küszöb: `src/node/timeoffsets.h`
- Időeltolás figyelés: `src/node/timeoffsets.cpp`
- Védelmi kovácsolás: `src/pocx/mining/scheduler.cpp`

**Kapcsolódó Dokumentáció**:
- Time Bending algoritmus: [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md#time-bending-számítás)
- Blokk validáció: [3. Fejezet: Blokk Validáció](3-consensus-and-mining.md#blokk-validáció)

---

**Generálva**: 2025-10-10
**Állapot**: Teljes Implementáció
**Lefedettség**: Időszinkronizációs követelmények, óraeltérés kezelés, védelmi kovácsolás

---

[← Előző: Kovácsolási Megbízások](4-forging-assignments.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Hálózati Paraméterek →](6-network-parameters.md)

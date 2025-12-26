# Bitcoin-PoCX: Energiahatékony Konszenzus a Bitcoin Core-hoz

**Verzió**: 2.0 Tervezet
**Dátum**: 2025. december
**Szervezet**: Proof of Capacity Consortium

---

## Összefoglaló

A Bitcoin Proof-of-Work (PoW) konszenzusa robusztus biztonságot nyújt, de jelentős energiát fogyaszt a folyamatos valós idejű hash számítás miatt. Bemutatjuk a Bitcoin-PoCX-et, egy Bitcoin elágazást, amely a PoW-t Proof of Capacity-vel (PoC) váltja fel, ahol a bányászok nagy mennyiségű, lemezen tárolt hash-t előre kiszámítanak a plotolás során, majd a bányászatot könnyűsúlyú keresésekkel végzik folyamatos hash-elés helyett. A számítás áttelepítésével a bányászati fázisból egy egyszeri plotolási fázisba, a Bitcoin-PoCX drasztikusan csökkenti az energiafogyasztást, miközben lehetővé teszi a bányászatot általános hardverrel, csökkentve a belépési korlátokat és mérsékelve az ASIC-dominált PoW-ban rejlő centralizációs nyomást, mindezt a Bitcoin biztonsági feltételezéseinek és gazdasági viselkedésének megőrzése mellett.

Implementációnk számos kulcsfontosságú innovációt vezet be:
(1) Megerősített plotfájl formátumot, amely kiküszöböl minden ismert idő-memória-kompromisszumos támadást a meglévő PoC rendszerekben, biztosítva, hogy a hatékony bányászati teljesítmény szigorúan arányos maradjon az elkötelezett tárolási kapacitással;
(2) A Time-Bending algoritmust, amely exponenciálisról chi-négyzetre transzformálja a határidő eloszlásokat, csökkentve a blokkidő szórását az átlag megváltoztatása nélkül;
(3) OP_RETURN-alapú kovácsolási megbízási mechanizmust, amely lehetővé teszi a nem-letéteményes pool bányászatot; és
(4) Dinamikus tömörítési skálázást, amely a plotfájl generálási nehézséget a felezési ütemtervekkel összehangolva növeli, a hosszú távú biztonsági határok fenntartása érdekében a hardver fejlődésével.

A Bitcoin-PoCX megőrzi a Bitcoin Core architektúráját minimális, funkciójelzéssel ellátott módosításokkal, elkülönítve a PoC logikát a meglévő konszenzus kódtól. A rendszer megőrzi a Bitcoin monetáris politikáját 120 másodperces blokk intervallumot célozva és a blokk jutalmat 10 BTC-re állítva. A csökkentett jutalom ellensúlyozza az ötszörös blokk gyakoriság növekedést, a hosszú távú kibocsátási rátát a Bitcoin eredeti ütemtervéhez igazítva és fenntartva a ~21 millió maximális kínálatot.

---

## 1. Bevezetés

### 1.1 Motiváció

A Bitcoin Proof-of-Work (PoW) konszenzusa több mint egy évtized alatt bizonyítottan biztonságos, de jelentős költséggel: a bányászoknak folyamatosan számítási erőforrásokat kell felhasználniuk, ami magas energiafogyasztást eredményez. A hatékonysági aggályokon túl van egy szélesebb motiváció: alternatív konszenzus mechanizmusok feltárása, amelyek fenntartják a biztonságot, miközben csökkentik a részvételi korlátot. A PoC lehetővé teszi gyakorlatilag bárki számára, akinek általános tárolóhardvere van, hogy hatékonyan bányásszon, csökkentve az ASIC-dominált PoW bányászatban tapasztalható centralizációs nyomást.

A Proof of Capacity (PoC) ezt úgy éri el, hogy a bányászati teljesítményt tárolási elkötelezettségből származtatja a folyamatos számítás helyett. A bányászok nagy mennyiségű, lemezen tárolt hash-t — plotokat — előre kiszámítanak egy egyszeri plotolási fázis során. A bányászat ezután könnyűsúlyú keresésekből áll, drasztikusan csökkentve az energiafelhasználást, miközben megőrzi az erőforrás-alapú konszenzus biztonsági feltételezéseit.

### 1.2 Integráció a Bitcoin Core-ral

A Bitcoin-PoCX a PoC konszenzust a Bitcoin Core-ba integrálja, nem pedig új blokkláncot hoz létre. Ez a megközelítés kihasználja a Bitcoin Core bizonyított biztonságát, érett hálózati veremét és széles körben elfogadott eszköztárát, miközben a módosításokat minimálisra tartja és funkciójelzésekkel látja el. A PoC logika el van különítve a meglévő konszenzus kódtól, biztosítva, hogy az alapvető funkcionalitás — blokk validáció, tárca műveletek, tranzakció formátumok — nagyrészt változatlan marad.

### 1.3 Tervezési Célok

**Biztonság**: Bitcoin-egyenértékű robusztusság megtartása; a támadásokhoz többségi tárolókapacitás szükséges.

**Hatékonyság**: Folyamatos számítási terhelés csökkentése lemez I/O szintekre.

**Hozzáférhetőség**: Bányászat lehetővé tétele általános hardverrel, a belépési korlátok csökkentése.

**Minimális Integráció**: PoC konszenzus bevezetése minimális módosítási lábnyommal.

---

## 2. Háttér: Proof of Capacity

### 2.1 Történelem

A Proof of Capacity (PoC)-t a Burstcoin vezette be 2014-ben, mint energiahatékony alternatívát a Proof-of-Work (PoW)-val szemben. A Burstcoin demonstrálta, hogy a bányászati teljesítmény származhat elkötelezett tárolásból a folyamatos valós idejű hash-elés helyett: a bányászok egyszer előre kiszámítottak nagy adathalmazokat ("plotokat"), majd ezekből kis, rögzített részeket olvasva bányásztak.

A korai PoC implementációk életképesnek bizonyították a koncepciót, de feltárták, hogy a plotfájl formátum és kriptográfiai struktúra kritikus a biztonság szempontjából. Számos idő-memória kompromisszum lehetővé tette a támadók számára, hogy hatékonyan bányásszanak kevesebb tárolással, mint a becsületes résztvevők. Ez rávilágított arra, hogy a PoC biztonság a plot tervezéstől függ — nem csupán a tárolás erőforrásként való használatától.

A Burstcoin öröksége megalapozta a PoC-t, mint praktikus konszenzus mechanizmust, és biztosította az alapot, amelyre a PoCX épít.

### 2.2 Alapfogalmak

A PoC bányászat nagy, előre kiszámított plotfájlokon alapul, amelyeket lemezen tárolnak. Ezek a plotok "fagyasztott számítást" tartalmaznak: a költséges hash-elés egyszer történik a plotolás során, és a bányászat ezután könnyűsúlyú lemez olvasásokból és egyszerű ellenőrzésből áll. Az alapvető elemek:

**Nonce:**
A plot adat alapegysége. Minden nonce 4096 scoop-ot tartalmaz (256 KiB összesen), amelyeket Shabal256-tal generálnak a bányász címéből és nonce indexéből.

**Scoop:**
Egy 64 bájtos szegmens egy nonce-on belül. Minden blokknál a hálózat determinisztikusan választ egy scoop indexet (0–4095) az előző blokk generációs aláírása alapján. Nonce-onként csak ez a scoop-ot kell olvasni.

**Generációs Aláírás:**
Egy 256 bites érték, amely az előző blokkból származik. Entrópiát biztosít a scoop kiválasztáshoz és megakadályozza, hogy a bányászok előre megjósolják a jövőbeli scoop indexeket.

**Warp:**
4096 nonce strukturális csoportja (1 GiB). A warp-ok a releváns egységek a tömörítés-ellenálló plotfájl formátumokhoz.

### 2.3 Bányászati Folyamat és Minőségi Csővezeték

A PoC bányászat egy egyszeri plotolási lépésből és egy könnyűsúlyú blokkonkénti rutinból áll:

**Egyszeri Beállítás:**
- Plot generálás: Nonce-ok számítása Shabal256-tal és lemezre írásuk.

**Blokkonkénti Bányászat:**
- Scoop kiválasztás: Scoop index meghatározása a generációs aláírásból.
- Plot átnézés: A scoop olvasása minden nonce-ból a bányász plotjaiban.

**Minőségi Csővezeték:**
- Nyers minőség: Minden scoop hash-elése a generációs aláírással Shabal256Lite használatával, 64 bites minőség érték előállítása (alacsonyabb jobb).
- Határidő: Minőség átalakítása határidővé az alap célérték használatával (nehézséggel beállított paraméter, amely biztosítja, hogy a hálózat elérje a célzott blokk intervallumot): `határidő = minőség / alap_célérték`
- Hajlított határidő: Time-Bending transzformáció alkalmazása a szórás csökkentésére a várt blokkidő megőrzése mellett.

**Blokk Kovácsolás:**
A legrövidebb (hajlított) határidővel rendelkező bányász kovácsolja a következő blokkot, amint az idő eltelik.

A PoW-val ellentétben szinte minden számítás a plotolás során történik; az aktív bányászat elsősorban lemez-kötött és nagyon alacsony fogyasztású.

### 2.4 Ismert Sebezhetőségek a Korábbi Rendszerekben

**POC1 Eloszlási Hiba:**
Az eredeti Burstcoin POC1 formátum strukturális torzítást mutatott: az alacsony indexű scoop-ok menet közben jelentősen olcsóbban voltak újraszámíthatók, mint a magas indexű scoop-ok. Ez nem egyenletes idő-memória kompromisszumot vezetett be, lehetővé téve a támadók számára, hogy csökkentsék a szükséges tárolást ezekhez a scoop-okhoz, és megtörve azt a feltételezést, hogy minden előre kiszámított adat egyformán költséges.

**XOR Tömörítési Támadás (POC2):**
A POC2-ben egy támadó vehet bármilyen 8192 nonce-os halmazt és két 4096 nonce-os blokkra (A és B) oszthatja. Ahelyett, hogy mindkét blokkot tárolná, a támadó csak egy származtatott struktúrát tárol: `A ⊕ transzponált(B)`, ahol a transzponálás felcseréli a scoop és nonce indexeket — a B blokk N nonce-ának S scoop-ja az S nonce N scoop-jává válik.

Bányászat közben, amikor egy N nonce S scoop-jára van szükség, a támadó rekonstruálja azt:
1. A tárolt XOR érték olvasása az (S, N) pozícióban
2. Az A blokkból az N nonce számítása az S scoop megszerzéséhez
3. A B blokkból az S nonce számítása a transzponált N scoop megszerzéséhez
4. Mind a három érték XOR-olása az eredeti 64 bájtos scoop helyreállításához

Ez 50%-kal csökkenti a tárolást, miközben keresésenkénti csak két nonce számítás szükséges — ez jóval a teljes előszámítás kényszerítéséhez szükséges küszöb alatt van. A támadás azért működik, mert egy sor (egy nonce, 4096 scoop) számítása olcsó, míg egy oszlop (egyetlen scoop 4096 nonce-on keresztül) számítása az összes nonce újragenerálását igényelné. A transzponálás struktúra felfedi ezt az egyensúlytalanságot.

Ez demonstrálta a szükségletet egy olyan plotfájl formátumra, amely megakadályozza az ilyen strukturált újrakombinációt és eltávolítja az alapul szolgáló idő-memória kompromisszumot. A 3.3 szakasz leírja, hogyan kezeli és oldja meg a PoCX ezt a gyengeséget.

### 2.5 Átmenet a PoCX-re

A korábbi PoC rendszerek korlátai egyértelművé tették, hogy a biztonságos, tisztességes és decentralizált tárolási bányászat gondosan tervezett plotfájl struktúráktól függ. A Bitcoin-PoCX ezeket a problémákat megerősített plotfájl formátummal, javított határidő eloszlással és decentralizált pool bányászati mechanizmusokkal kezeli — a következő szakaszban leírtak szerint.

---

## 3. PoCX Plotfájl Formátum

### 3.1 Alap Nonce Konstrukció

A nonce egy 256 KiB-os adatstruktúra, amelyet determinisztikusan származtatnak három paraméterből: egy 20 bájtos cím payloadból, egy 32 bájtos seed-ből és egy 64 bites nonce indexből.

A konstrukció úgy kezdődik, hogy ezeket a bemeneteket kombináljuk és Shabal256-tal hash-eljük egy kezdeti hash előállításához. Ez a hash szolgál kiindulópontként egy iteratív bővítési folyamathoz: a Shabal256-ot ismételten alkalmazzuk, minden lépés a korábban generált adatoktól függ, amíg a teljes 256 KiB-os puffer meg nem telik. Ez a láncolt folyamat képviseli a plotolás során végzett számítási munkát.

Egy végső diffúziós lépés hash-eli a befejezett puffert és XOR-olja az eredményt minden bájton keresztül. Ez biztosítja, hogy a teljes puffer ki lett számítva és a bányászok nem kerülhetik meg a számítást. Ezután a PoC2 keverés alkalmazásra kerül, felcserélve minden scoop alsó és felső felét, garantálva, hogy minden scoop egyenértékű számítási erőfeszítést igényel.

A végleges nonce 4096 db 64 bájtos scoop-ból áll és alkotja a bányászatban használt alapegységet.

### 3.2 SIMD-Igazított Plotfájl Elrendezés

A modern hardver átvitelének maximalizálása érdekében a PoCX úgy szervezi a nonce adatokat a lemezen, hogy megkönnyítse a vektorizált feldolgozást. Ahelyett, hogy minden nonce-t szekvenciálisan tárolna, a PoCX a megfelelő 4 bájtos szavakat több egymást követő nonce-on keresztül összefüggően igazítja. Ez lehetővé teszi, hogy egyetlen memória lekérés adatot szolgáltasson minden SIMD sávnak, minimalizálva a gyorsítótár hibákat és kiküszöbölve a szórt-gyűjtés többletet.

```
Hagyományos elrendezés:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD elrendezés:
Szó0: [N0][N1][N2]...[N15]
Szó1: [N0][N1][N2]...[N15]
Szó2: [N0][N1][N2]...[N15]
```

Ez az elrendezés mind a CPU, mind a GPU bányászoknak előnyös, lehetővé téve a magas átvitelű, párhuzamosított scoop kiértékelést, miközben megtart egy egyszerű skaláris hozzáférési mintát a konszenzus ellenőrzéshez. Biztosítja, hogy a bányászatot a tárolási sávszélesség korlátozza, nem pedig a CPU számítás, fenntartva a Proof of Capacity alacsony fogyasztású természetét.

### 3.3 Warp Struktúra és XOR-Transzponálás Kódolás

A warp a PoCX alapvető tárolási egysége, amely 4096 nonce-ból áll (1 GiB). A tömörítetlen formátum, amelyet X0-nak nevezünk, pontosan úgy tartalmazza az alap nonce-okat, ahogy a 3.1 szakasz konstrukciója előállítja.

**XOR-Transzponálás Kódolás (X1)**

A korábbi PoC rendszerekben jelen lévő strukturális idő-memória kompromisszumok eltávolítása érdekében a PoCX egy megerősített bányászati formátumot, X1-et származtat XOR-transzponálás kódolás alkalmazásával X0 warp párokra.

Egy X1 warp N nonce-ának S scoop-jának felépítéséhez:

1. Vegye az S scoop-ot N nonce-ból az első X0 warp-ból (közvetlen pozíció)
2. Vegye az N scoop-ot S nonce-ból a második X0 warp-ból (transzponált pozíció)
3. XOR-olja a két 64 bájtos értéket az X1 scoop előállításához

A transzponálás lépés felcseréli a scoop és nonce indexeket. Mátrix terminológiában — ahol a sorok a scoop-okat, az oszlopok a nonce-okat képviselik — az első warp (S, N) pozíciójának elemét kombinálja a második (N, S) elemével.

**Miért Szünteti Ez Meg a Tömörítési Támadási Felületet**

Az XOR-transzponálás összekapcsol minden scoop-ot az alapul szolgáló X0 adatok egy teljes sorával és egy teljes oszlopával. Egyetlen X1 scoop helyreállításához tehát mind a 4096 scoop indexre kiterjedő adatokhoz szükséges hozzáférés. Bármilyen kísérlet a hiányzó adatok kiszámítására 4096 teljes nonce újragenerálását igényelné egyetlen nonce helyett — eltávolítva az aszimmetrikus költségstruktúrát, amelyet a POC2 XOR támadás kihasznált (2.4 szakasz).

Ennek eredményeként a teljes X1 warp tárolása válik az egyetlen számításilag életképes stratégiává a bányászok számára, bezárva a korábbi tervezésekben kihasznált idő-memória kompromisszumot.

### 3.4 Lemez Elrendezés

A PoCX plotfájlok számos egymást követő X1 warp-ból állnak. A bányászat közbeni működési hatékonyság maximalizálása érdekében az egyes fájlokon belüli adatok scoop szerint vannak szervezve: minden warp scoop 0 adata szekvenciálisan tárolva, majd minden scoop 1 adat, és így tovább scoop 4095-ig.

Ez a **scoop-szekvenciális rendezés** lehetővé teszi a bányászoknak, hogy a kiválasztott scoop-hoz szükséges teljes adatot egyetlen szekvenciális lemez hozzáféréssel olvassák be, minimalizálva a keresési időket és maximalizálva az átvitelt általános tárolóeszközökön.

A 3.3 szakasz XOR-transzponálás kódolásával kombinálva ez az elrendezés biztosítja, hogy a fájl egyszerre **strukturálisan megerősített** és **működésileg hatékony**: a szekvenciális scoop rendezés támogatja az optimális lemez I/O-t, míg a SIMD-igazított memória elrendezések (lásd 3.2 szakasz) lehetővé teszik a magas átvitelű, párhuzamosított scoop kiértékelést.

### 3.5 Proof-of-Work Skálázás (Xn)

A PoCX skálázható előszámítást valósít meg a skálázási szintek koncepcióján keresztül, amelyeket Xn-nel jelölnek, hogy alkalmazkodjon a fejlődő hardver teljesítményhez. Az alapvonal X1 formátum az első XOR-transzponálással megerősített warp struktúrát képviseli.

Minden Xn skálázási szint exponenciálisan növeli a warponként beágyazott proof-of-work-öt az X1-hez képest: az Xn szinten szükséges munka 2^(n-1)-szerese az X1-nek. Az Xn-ről Xn+1-re való átmenet működésileg egyenértékű a szomszédos warp párok közötti XOR alkalmazásával, fokozatosan több proof-of-work-öt ágyazva be az alapul szolgáló plotfájl méret megváltoztatása nélkül.

Az alacsonyabb skálázási szinteken létrehozott meglévő plotfájlok továbbra is használhatók bányászatra, de arányosan kevesebb munkát képviselnek a blokkgenerálás szempontjából, tükrözve alacsonyabb beágyazott proof-of-work-jüket. Ez a mechanizmus biztosítja, hogy a PoCX plotok biztonságosak, rugalmasak és gazdaságilag kiegyensúlyozottak maradjanak idővel.

### 3.6 Seed Funkcionalitás

A seed paraméter lehetővé teszi több, át nem fedő plot létrehozását címenként manuális koordináció nélkül.

**Probléma (POC2)**: A bányászoknak manuálisan kellett nyomon követniük a nonce tartományokat a plotfájlok között az átfedés elkerülése érdekében. Az átfedő nonce-ok tárolást pazarolnak anélkül, hogy növelnék a bányászati teljesítményt.

**Megoldás**: Minden `(cím, seed)` pár független kulcsteret definiál. A különböző seed-del rendelkező plotok soha nem fedik át egymást, függetlenül a nonce tartományoktól. A bányászok szabadon hozhatnak létre plotokat koordináció nélkül.

---

## 4. Proof of Capacity Konszenzus

A PoCX a Bitcoin Nakamoto konszenzusát tároláskötött bizonyítási mechanizmussal bővíti. Ahelyett, hogy energiát költene ismételt hash-elésre, a bányászok nagy mennyiségű előre kiszámított adatot — plotokat — tárolnak lemezen. A blokkgenerálás során meg kell találniuk ezen adatok egy kis, kiszámíthatatlan részét és bizonyítékká kell alakítaniuk. A várt időablakon belül a legjobb bizonyítékot nyújtó bányász kapja meg a jogot a következő blokk kovácsolására.

Ez a fejezet leírja, hogyan strukturálja a PoCX a blokk metaadatokat, honnan származik a kiszámíthatatlanság, és hogyan alakítja át a statikus tárolást biztonságos, alacsony szórású konszenzus mechanizmussá.

### 4.1 Blokkszerkezet

A PoCX megtartja az ismerős Bitcoin-stílusú blokk fejlécet, de további konszenzus mezőket vezet be a kapacitás-alapú bányászathoz. Ezek a mezők együttesen kötik a blokkot a bányász tárolt plotjához, a hálózat nehézségéhez és a kriptográfiai entrópiához, amely minden bányászati kihívást meghatároz.

Magas szinten egy PoCX blokk tartalmazza: a blokk magasságot, explicit módon rögzítve a kontextuális validáció egyszerűsítésére; a generációs aláírást, amely friss entrópia forrás, minden blokkot az előzőhöz kapcsolva; az alap célértéket, amely a hálózati nehézséget inverz formában reprezentálja (magasabb értékek könnyebb bányászatnak felelnek meg); a PoCX bizonyítékot, amely azonosítja a bányász plotját, a plotolás során használt tömörítési szintet, a kiválasztott nonce-t és az ebből származtatott minőséget; valamint egy aláíró kulcsot és aláírást, amely bizonyítja a blokk kovácsolásához használt kapacitás feletti kontrollt (vagy a megbízott kovácsolási kulcs felettit).

A bizonyíték minden konszenzus-releváns információt beágyaz, amelyre a validátoroknak szükségük van a kihívás újraszámításához, a kiválasztott scoop ellenőrzéséhez és a kapott minőség megerősítéséhez. A blokkszerkezet bővítésével, nem pedig újratervezésével, a PoCX koncepcionálisan igazodik a Bitcoin-hoz, miközben alapvetően eltérő bányászati munka forrást tesz lehetővé.

### 4.2 Generációs Aláírás Lánc

A generációs aláírás biztosítja a biztonságos Proof of Capacity bányászathoz szükséges kiszámíthatatlanságot. Minden blokk az előző blokk aláírásából és aláírójából származtatja a generációs aláírását, biztosítva, hogy a bányászok ne tudjanak előre jelezni jövőbeli kihívásokat vagy előre kiszámítani előnyös plot régiókat:

`generációsAláírás[n] = SHA256(generációsAláírás[n-1] || bányász_pubkey[n-1])`

Ez kriptográfiailag erős, bányász-függő entrópia értékek sorozatát állítja elő. Mivel a bányász publikus kulcsa ismeretlen az előző blokk közzétételéig, egyetlen résztvevő sem tudja előre megjósolni a jövőbeli scoop kiválasztásokat. Ez megakadályozza a szelektív előszámítást vagy stratégiai plotolást, és biztosítja, hogy minden blokk valóban friss bányászati munkát vezet be.

### 4.3 Kovácsolási Folyamat

A PoCX-ben a bányászat abból áll, hogy a tárolt adatokat a generációs aláírás által teljes mértékben vezérelt bizonyítékká alakítjuk. Bár a folyamat determinisztikus, az aláírás kiszámíthatatlansága biztosítja, hogy a bányászok ne tudjanak előre felkészülni, és ismételten hozzá kell férniük a tárolt plotjaikhoz.

**Kihívás Származtatás (Scoop Kiválasztás):** A bányász az aktuális generációs aláírást a blokk magassággal hash-eli, hogy scoop indexet kapjon a 0–4095 tartományban. Ez az index határozza meg, hogy minden tárolt nonce melyik 64 bájtos szegmense vesz részt a bizonyítékban. Mivel a generációs aláírás az előző blokk aláírójától függ, a scoop kiválasztás csak a blokk közzétételének pillanatában válik ismertté.

**Bizonyíték Kiértékelés (Minőség Számítás):** Egy plot minden nonce-ához a bányász lekéri a kiválasztott scoop-ot és a generációs aláírással együtt hash-eli, hogy minőséget kapjon — egy 64 bites értéket, amelynek nagysága meghatározza a bányász versenyképességét. Az alacsonyabb minőség jobb bizonyítéknak felel meg.

**Határidő Formálás (Time Bending):** A nyers határidő arányos a minőséggel és fordítottan arányos az alap célértékkel. Az örökség PoC tervezésekben ezek a határidők erősen torzított exponenciális eloszlást követtek, hosszú farok késéseket produkálva, amelyek nem biztosítottak további biztonságot. A PoCX a nyers határidőt Time Bending-gel transzformálja (4.4 szakasz), csökkentve a szórást és biztosítva a kiszámítható blokk intervallumokat. Amint a hajlított határidő letelik, a bányász kovácsol egy blokkot a bizonyíték beágyazásával és az effektív kovácsolási kulccsal való aláírásával.

### 4.4 Time Bending

A Proof of Capacity exponenciálisan eloszló határidőket produkál. Rövid idő után — jellemzően néhány tucat másodperc — minden bányász már azonosította a legjobb bizonyítékát, és bármilyen további várakozási idő csak késleltetést ad, nem biztonságot.

A Time Bending köbgyök transzformáció alkalmazásával átformálja az eloszlást:

`határidő_hajlított = skála × (minőség / alap_célérték)^(1/3)`

A skálatényező megőrzi a várt blokkidőt (120 másodperc), miközben drámaian csökkenti a szórást. A rövid határidők kiterjesztésre kerülnek, javítva a blokk terjesztést és hálózati biztonságot. A hosszú határidők tömörítésre kerülnek, megakadályozva, hogy a kiugró értékek késleltessék a láncot.

![Blokkidő Eloszlások](blocktime_distributions.svg)

A Time Bending megőrzi az alapul szolgáló bizonyíték információtartalmát. Nem módosítja a bányászok közötti versenyképességet; csak újraosztja a várakozási időt, simább, kiszámíthatóbb blokk intervallumokat produkálva. Az implementáció fixpontos aritmetikát (Q42 formátum) és 256 bites egészeket használ, determinisztikus eredményeket biztosítva minden platformon.

### 4.5 Nehézség Beállítás

A PoCX az alap célérték használatával szabályozza a blokkgyártást, amely inverz nehézségi mérték. A várt blokkidő arányos a `minőség / alap_célérték` aránnyal, így az alap célérték növelése felgyorsítja a blokkgyártást, csökkentése pedig lassítja a láncot.

A nehézség minden blokknál beállításra kerül a legutóbbi blokkok közötti mért idő és a cél intervallum összehasonlításával. Ez a gyakori beállítás szükséges, mert a tárolókapacitás gyorsan hozzáadható vagy eltávolítható — a Bitcoin hash-teljesítményétől eltérően, amely lassabban változik.

A beállítás két irányadó korlátozást követ: **Fokozatosság** — a blokkonkénti változások korlátozottak (maximum ±20%), az oszcillációk vagy manipuláció elkerülésére; **Megerősítés** — az alap célérték nem haladhatja meg a genezis értékét, megakadályozva, hogy a hálózat valaha is az eredeti biztonsági feltételezések alá csökkentse a nehézséget.

### 4.6 Blokk Érvényesség

A PoCX-ben egy blokk akkor érvényes, ha a konszenzus állapottal konzisztens, ellenőrizhető tárolásból származó bizonyítékot mutat be. A validátorok függetlenül újraszámolják a scoop kiválasztást, a beküldött nonce-ból és plot metaadatokból származtatják a várt minőséget, alkalmazzák a Time Bending transzformációt, és megerősítik, hogy a bányász jogosult volt a blokk kovácsolására a deklarált időpontban.

Konkrétan, egy érvényes blokk megköveteli: a határidő eltelt a szülő blokk óta; a beküldött minőség megegyezik a bizonyítékhoz számított minőséggel; a skálázási szint megfelel a hálózati minimumnak; a generációs aláírás megegyezik a várt értékkel; az alap célérték megegyezik a várt értékkel; a blokk aláírás az effektív aláírótól származik; és a coinbase az effektív aláíró címére fizet.

---

## 5. Kovácsolási Megbízások

### 5.1 Motiváció

A kovácsolási megbízások lehetővé teszik a plot tulajdonosoknak, hogy blokk-kovácsolási jogosultságot delegáljanak anélkül, hogy valaha is lemondanának a plotjaik tulajdonjogáról. Ez a mechanizmus lehetővé teszi a pool bányászatot és a hideg tárolási beállításokat, miközben megőrzi a PoCX biztonsági garanciáit.

Pool bányászatban a plot tulajdonosok felhatalmazhatnak egy pool-t, hogy blokkokat kovácsoljon a nevükben. A pool összeállítja a blokkokat és elosztja a jutalmakat, de soha nem szerez letéteményt a plotok felett. A delegálás bármikor visszavonható, és a plot tulajdonosok szabadon elhagyhatnak egy pool-t vagy változtathatnak konfigurációkon újraplotolás nélkül.

A megbízások támogatják a hideg és forró kulcsok tiszta elválasztását is. A plotot irányító privát kulcs offline maradhat, míg egy külön kovácsolási kulcs — online gépen tárolva — blokkokat produkál. A kovácsolási kulcs kompromittálása ezért csak a kovácsolási jogosultságot kompromittálja, nem a tulajdonjogot. A plot biztonságban marad és a megbízás visszavonható, azonnal bezárva a biztonsági rést.

A kovácsolási megbízások tehát működési rugalmasságot biztosítanak, miközben fenntartják azt az elvet, hogy a tárolt kapacitás feletti kontroll soha nem adható át közvetítőknek.

### 5.2 Megbízás Protokoll

A megbízások OP_RETURN tranzakciókon keresztül kerülnek deklarálásra, elkerülve az UTXO halmaz szükségtelen növekedését. A megbízás tranzakció meghatározza a plot címet és a kovácsolási címet, amely jogosult blokkokat produkálni a plot kapacitásával. A visszavonási tranzakció csak a plot címet tartalmazza. Mindkét esetben a plot tulajdonos a tranzakció költési bemenetének aláírásával bizonyítja a kontrollt.

Minden megbízás jól definiált állapotok sorozatán halad keresztül (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Miután egy megbízás tranzakció megerősítésre kerül, a rendszer rövid aktiválási fázisba lép. Ez a késleltetés — 30 blokk, körülbelül egy óra — stabilitást biztosít a blokk versenyek során és megakadályozza a kovácsolási identitások ellenséges gyors váltogatását. Miután ez az aktiválási időszak lejár, a megbízás aktívvá válik és az marad, amíg a plot tulajdonos visszavonást nem kezdeményez.

A visszavonások hosszabb késleltetési időszakba lépnek, 720 blokk, körülbelül egy nap. Ez idő alatt az előző kovácsolási cím aktív marad. Ez a hosszabb késleltetés működési stabilitást biztosít a pool-oknak, megakadályozva a stratégiai "megbízás ugrálást" és elegendő bizonyosságot adva az infrastruktúra szolgáltatóknak a hatékony működéshez. A visszavonási késleltetés lejárta után a visszavonás befejeződik, és a plot tulajdonos szabadon kijelölhet új kovácsolási kulcsot.

A megbízás állapot egy, az UTXO halmazzal párhuzamos konszenzus-réteg struktúrában van fenntartva, és támogatja a visszavonási adatokat a lánc reorganizációk biztonságos kezeléséhez.

### 5.3 Validációs Szabályok

Minden blokknál a validátorok meghatározzák az effektív aláírót — a címet, amelynek alá kell írnia a blokkot és meg kell kapnia a coinbase jutalmat. Ez az aláíró kizárólag a blokk magasságánál érvényes megbízás állapottól függ.

Ha nincs megbízás vagy a megbízás még nem fejezte be az aktiválási fázisát, a plot tulajdonos marad az effektív aláíró. Amint a megbízás aktívvá válik, a megbízott kovácsolási címnek kell aláírnia. Visszavonás alatt a kovácsolási cím folytatja az aláírást, amíg a visszavonási késleltetés le nem jár. Csak ezután tér vissza a jogosultság a plot tulajdonoshoz.

A validátorok érvényesítik, hogy a blokk aláírás az effektív aláírótól származik, hogy a coinbase ugyanarra a címre fizet, és hogy minden átmenet követi az előírt aktiválási és visszavonási késleltetéseket. Csak a plot tulajdonos hozhat létre vagy vonhat vissza megbízásokat; a kovácsolási kulcsok nem módosíthatják vagy bővíthetik saját engedélyeiket.

A kovácsolási megbízások tehát rugalmas delegálást vezetnek be bizalom bevezetése nélkül. Az alapul szolgáló kapacitás feletti tulajdonjog mindig kriptográfiailag horgonyzott marad a plot tulajdonoshoz, míg a kovácsolási jogosultság delegálható, forgatható vagy visszavonható, ahogy a működési igények fejlődnek.

---

## 6. Dinamikus Skálázás

Ahogy a hardver fejlődik, a plotok számításának költsége csökken az előre kiszámított munka lemezről való olvasásának költségéhez képest. Ellenintézkedések nélkül a támadók végül gyorsabban generálhatnának bizonyítékokat menet közben, mint a bányászok, akik a tárolt munkát olvassák, aláásva a Proof of Capacity biztonsági modelljét.

A tervezett biztonsági határ megőrzése érdekében a PoCX egy skálázási ütemtervet implementál: a plotok minimum szükséges skálázási szintje idővel növekszik. Minden Xn skálázási szint, a 3.5 szakaszban leírtak szerint, exponenciálisan több proof-of-work-öt ágyaz be a plotfájl struktúrába, biztosítva, hogy a bányászok továbbra is jelentős tárolási erőforrásokat kötelezzenek el még akkor is, amikor a számítás olcsóbbá válik.

Az ütemterv igazodik a hálózat gazdasági ösztönzőihez, különösen a blokkjutalom felezésekhez. Ahogy a blokkonkénti jutalom csökken, a minimum szint fokozatosan növekszik, megőrizve az egyensúlyt a plotolási erőfeszítés és a bányászati potenciál között:

| Időszak | Évek | Felezések | Min Skálázás | Plot Munka Szorzó |
|---------|------|-----------|-------------|-------------------|
| 0. Korszak | 0-4 | 0 | X1 | 2× alapvonal |
| 1. Korszak | 4-12 | 1-2 | X2 | 4× alapvonal |
| 2. Korszak | 12-28 | 3-6 | X3 | 8× alapvonal |
| 3. Korszak | 28-60 | 7-14 | X4 | 16× alapvonal |
| 4. Korszak | 60-124 | 15-30 | X5 | 32× alapvonal |
| 5. Korszak | 124+ | 31+ | X6 | 64× alapvonal |

A bányászok opcionálisan előkészíthetnek plotokat, amelyek egy szinttel meghaladják az aktuális minimumot, lehetővé téve számukra az előre tervezést és az azonnali frissítések elkerülését, amikor a hálózat a következő korszakba lép. Ez az opcionális lépés nem biztosít további előnyt a blokk valószínűség szempontjából — csupán simább működési átmenetet tesz lehetővé.

A magasságuknál érvényes minimum skálázási szint alatti bizonyítékokat tartalmazó blokkok érvénytelennek tekintendők. A validátorok ellenőrzik a bizonyítékban deklarált skálázási szintet az aktuális hálózati követelményhez képest a konszenzus validáció során, biztosítva, hogy minden résztvevő bányász megfeleljen a fejlődő biztonsági elvárásoknak.

---

## 7. Bányászati Architektúra

A PoCX elválasztja a konszenzus-kritikus műveleteket a bányászat erőforrás-intenzív feladataitól, lehetővé téve mind a biztonságot, mind a hatékonyságot. A csomópont fenntartja a blokkláncot, validálja a blokkokat, kezeli a mempool-t és RPC interfészt tesz elérhetővé. A külső bányászok kezelik a plot tárolást, scoop olvasást, minőség számítást és határidő kezelést. Ez az elválasztás egyszerűvé és auditálhatóvá tartja a konszenzus logikát, miközben lehetővé teszi a bányászoknak a lemez átvitelre való optimalizálást.

### 7.1 Bányászati RPC Interfész

A bányászok minimális RPC hívásokon keresztül kommunikálnak a csomóponttal. A get_mining_info RPC biztosítja az aktuális blokk magasságot, generációs aláírást, alap célértéket, cél határidőt és az elfogadható plot skálázási szintek tartományát. Ezen információk felhasználásával a bányászok jelölt nonce-okat számítanak. A submit_nonce RPC lehetővé teszi a bányászoknak egy javasolt megoldás beküldését, beleértve a plot azonosítót, nonce indexet, skálázási szintet és bányász fiókot. A csomópont kiértékeli a beküldést és a kiszámított határidővel válaszol, ha a bizonyíték érvényes.

### 7.2 Kovácsolási Ütemező

A csomópont egy kovácsolási ütemezőt tart fenn, amely nyomon követi a bejövő beküldéseket és minden blokk magasságra csak a legjobb megoldást tartja meg. A beküldött nonce-ok sorba kerülnek beépített védelemmel a beküldési elárasztás vagy szolgáltatásmegtagadási támadások ellen. Az ütemező vár, amíg a kiszámított határidő lejár vagy jobb megoldás érkezik, majd összeállít egy blokkot, aláírja az effektív kovácsolási kulccsal és közzéteszi a hálózatnak.

### 7.3 Védelmi Kovácsolás

Az időzítési támadások vagy az óramanipuláció ösztönzésének megakadályozására a PoCX védelmi kovácsolást implementál. Ha versengő blokk érkezik ugyanarra a magasságra, az ütemező összehasonlítja a helyi megoldást az új blokkal. Ha a helyi minőség jobb, a csomópont azonnal kovácsol ahelyett, hogy megvárná az eredeti határidőt. Ez biztosítja, hogy a bányászok ne szerezhessenek előnyt pusztán a helyi órák állításával; a legjobb megoldás mindig győz, megőrizve a tisztességességet és a hálózati biztonságot.

---

## 8. Biztonsági Elemzés

### 8.1 Fenyegetés Modell

A PoCX jelentős, de korlátozott képességekkel rendelkező ellenfeleket modellel. A támadók megpróbálhatják túlterhelni a hálózatot érvénytelen tranzakciókkal, rosszul formázott blokkokkal vagy gyártott bizonyítékokkal, hogy stressz-tesztelják a validációs útvonalakat. Szabadon manipulálhatják helyi órájukat és megpróbálhatják kihasználni a konszenzus viselkedés szélső eseteit, mint az időbélyeg kezelést, nehézség beállítási dinamikát vagy reorganizációs szabályokat. Az ellenfelek várhatóan keresik a lehetőségeket a történelem újraírására célzott lánc elágazásokon keresztül.

A modell feltételezi, hogy egyetlen fél sem kontrollálja a teljes hálózati tárolókapacitás többségét. Mint minden erőforrás-alapú konszenzus mechanizmusnál, egy 51%-os kapacitású támadó egyoldalúan reorganizálhatja a láncot; ez az alapvető korlátozás nem specifikus a PoCX-re. A PoCX azt is feltételezi, hogy a támadók nem tudnak gyorsabban plot adatot számítani, mint a becsületes bányászok lemezről olvasni. A skálázási ütemterv (6. szakasz) biztosítja, hogy a biztonsághoz szükséges számítási rés növekedjen idővel, ahogy a hardver fejlődik.

A következő szakaszok részletesen megvizsgálják minden fő támadási osztályt és leírják a PoCX-be épített ellenintézkedéseket.

### 8.2 Kapacitás Támadások

A PoW-hoz hasonlóan egy többségi kapacitással rendelkező támadó újraírhatja a történelmet (51%-os támadás). Ennek eléréséhez a becsületes hálózatnál nagyobb fizikai tároló lábnyomot kell megszerezni — egy költséges és logisztikailag igényes vállalkozás. Miután a hardvert megszerezték, a működési költségek alacsonyak, de a kezdeti befektetés erős gazdasági ösztönzést teremt a becsületes viselkedésre: a lánc aláásása károsítaná a támadó saját eszközállományának értékét.

A PoC elkerüli a PoS-hoz kapcsolódó nothing-at-stake problémát is. Bár a bányászok átnézhetik a plotokat több versengő elágazásra is, minden átnézés valós időt fogyaszt — jellemzően tíz másodperc nagyságrendben lánconként. 120 másodperces blokk intervallummal ez eredendően korlátozza a több-elágazásos bányászatot, és az egyszerre sok elágazáson való bányászási kísérlet rontja a teljesítményt mindegyiken. Az elágazás bányászat tehát nem költségmentes; alapvetően korlátozza az I/O átvitel.

Még ha a jövőbeli hardver lehetővé is tenné a közel azonnali plot átnézést (pl. nagy sebességű SSD-k), a támadónak még mindig jelentős fizikai erőforrás követelménnyel kellene szembenéznie a hálózati kapacitás többségének kontrollálásához, költségessé és logisztikailag nehézzé téve az 51%-stílusú támadást.

Végül, a kapacitás támadások sokkal nehezebben bérelhetők, mint a hash-teljesítmény támadások. A GPU számítási kapacitás igény szerint megszerezhető és azonnal átirányítható bármely PoW láncra. Ezzel szemben a PoC fizikai hardvert, időigényes plotolást és folyamatos I/O műveleteket igényel. Ezek a korlátok sokkal kevésbé megvalósíthatóvá teszik a rövid távú, opportunista támadásokat.

### 8.3 Időzítési Támadások

Az időzítés kritikusabb szerepet játszik a Proof of Capacity-ben, mint a Proof of Work-ben. A PoW-ban az időbélyegek elsősorban a nehézség beállítást befolyásolják; a PoC-ben meghatározzák, hogy a bányász határideje lejárt-e, és így a blokk jogosult-e kovácsolásra. A határidők a szülő blokk időbélyegéhez viszonyítva mérettek, de a csomópont helyi óráját használják annak megítélésére, hogy egy bejövő blokk túl messze van-e a jövőben. Ezért a PoCX szoros időbélyeg tűrést érvényesít: a blokkok nem térhetnek el több mint 15 másodpercet a csomópont helyi órájától (a Bitcoin 2 órás ablakával szemben). Ez a korlát mindkét irányban működik — a túl távoli jövőbeli blokkok elutasításra kerülnek, és a lassú órával rendelkező csomópontok helytelenül elutasíthatják az érvényes bejövő blokkokat.

A csomópontoknak ezért NTP-vel vagy egyenértékű időforrással szinkronizálniuk kell az órájukat. A PoCX szándékosan kerüli a hálózaton belüli időforrásokra támaszkodást, megakadályozva, hogy a támadók manipulálják az észlelt hálózati időt. A csomópontok figyelik saját eltérésüket és figyelmeztetéseket adnak, ha a helyi óra kezd eltérni a legutóbbi blokk időbélyegektől.

Az óra gyorsítás — gyors helyi óra futtatása a kissé korábbi kovácsoláshoz — csak marginális előnyt biztosít. Az engedélyezett tűrésen belül a védelmi kovácsolás (7.3 szakasz) biztosítja, hogy a jobb megoldással rendelkező bányász azonnal közzéteszi, ha gyengébb korai blokkot lát. A gyors óra csak abban segít a bányásznak, hogy egy már nyerő megoldást néhány másodperccel korábban tegyen közzé; nem tud egy gyengébb bizonyítékot nyerőre alakítani.

A nehézség időbélyegeken keresztüli manipulálási kísérleteit a blokkonkénti ±20%-os beállítási sapka és a 24 blokkos gördülő ablak korlátozza, megakadályozva, hogy a bányászok érdemben befolyásolják a nehézséget rövid távú időzítési játékokon keresztül.

### 8.4 Idő-Memória Kompromisszum Támadások

Az idő-memória kompromisszumok megpróbálják csökkenteni a tárolási követelményeket a plot részek igény szerinti újraszámításával. A korábbi Proof of Capacity rendszerek sebezhetőek voltak az ilyen támadásokra, különösen a POC1 scoop-egyensúlytalansági hibára és a POC2 XOR-transzponálás tömörítési támadásra (2.4 szakasz). Mindkettő a plot adatok bizonyos részeinek újragenerálási költségében rejlő aszimmetriákat használta ki, lehetővé téve az ellenfelek számára, hogy csökkentsék a tárolást, miközben csak kis számítási büntetést fizettek. Ezenkívül a PoC2-től eltérő alternatív plotfájl formátumok is szenvednek hasonló TMTO gyengeségektől; kiemelkedő példa a Chia, amelynek plotfájl formátuma tetszőlegesen csökkenthető 4-nél nagyobb tényezővel.

A PoCX teljesen eltávolítja ezeket a támadási felületeket a nonce konstrukción és warp formátumon keresztül. Minden nonce-on belül a végső diffúziós lépés hash-eli a teljesen kiszámított puffert és XOR-olja az eredményt minden bájton keresztül, biztosítva, hogy a puffer minden része függjön minden más résztől és ne lehessen megkerülni. Ezután a PoC2 keverés felcseréli minden scoop alsó és felső felét, kiegyenlítve bármely scoop helyreállításának számítási költségét.

A PoCX tovább kiküszöböli a POC2 XOR-transzponálás tömörítési támadást a megerősített X1 formátum származtatásával, ahol minden scoop egy közvetlen és egy transzponált pozíció XOR-ja párosított warp-okon keresztül; ez összekapcsol minden scoop-ot az alapul szolgáló X0 adatok egy teljes sorával és egy teljes oszlopával, a rekonstrukciót több ezer teljes nonce-ot igénylővé téve és ezáltal teljesen eltávolítva az aszimmetrikus idő-memória kompromisszumot.

Ennek eredményeként a teljes plot tárolása az egyetlen számításilag életképes stratégia a bányászok számára. Egyetlen ismert rövidítés — legyen az részleges plotolás, szelektív újragenerálás, strukturált tömörítés vagy hibrid számítás-tárolás megközelítés — nem biztosít érdemi előnyt. A PoCX biztosítja, hogy a bányászat szigorúan tárolás-kötött maradjon és a kapacitás valódi, fizikai elkötelezettséget tükrözzön.

### 8.5 Megbízás Támadások

A PoCX determinisztikus állapotgépet használ minden plot-kovácsoló megbízás irányítására. Minden megbízás jól definiált állapotokon halad keresztül — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — érvényesített aktiválási és visszavonási késleltetésekkel. Ez biztosítja, hogy egy bányász ne változtathassa azonnal a megbízásokat a rendszer kijátszására vagy a kovácsolási jogosultság gyors váltogatására.

Mivel minden átmenet kriptográfiai bizonyítékokat igényel — konkrétan a plot tulajdonos aláírásait, amelyek ellenőrizhetők a bemeneti UTXO-val szemben — a hálózat megbízhat minden megbízás jogosságában. Az állapotgép megkerülésének vagy megbízások hamisításának kísérletei automatikusan elutasításra kerülnek a konszenzus validáció során. Az újrajátszási támadásokat szintén megakadályozzák a szabványos Bitcoin-stílusú tranzakció újrajátszási védelmek, biztosítva, hogy minden megbízási akció egyedileg kötve legyen egy érvényes, el nem költött bemenethez.

Az állapotgép irányítás, az érvényesített késleltetések és a kriptográfiai bizonyíték kombinációja gyakorlatilag lehetetlenné teszi a megbízás-alapú csalást: a bányászok nem tudják eltéríteni a megbízásokat, gyors újrahozzárendelést végezni blokkversenyek során, vagy megkerülni a visszavonási ütemterveket.

### 8.6 Aláírás Biztonság

A PoCX-ben a blokk aláírások kritikus kapcsolatként szolgálnak a bizonyíték és az effektív kovácsolási kulcs között, biztosítva, hogy csak jogosult bányászok produkálhassanak érvényes blokkokat.

A módosíthatósági támadások megakadályozására az aláírások ki vannak zárva a blokk hash számításból. Ez kiküszöböli a módosítható aláírások kockázatát, amelyek alááshatnák a validációt vagy lehetővé tehetnék a blokk csere támadásokat.

A szolgáltatásmegtagadási vektorok mérséklésére az aláírás és publikus kulcs méretek rögzítettek — 65 bájt kompakt aláírásokhoz és 33 bájt tömörített publikus kulcsokhoz — megakadályozva, hogy a támadók felfújják a blokkokat erőforrás kimerítés kiváltására vagy a hálózati terjesztés lassítására.

---

## 9. Implementáció

A PoCX a Bitcoin Core moduláris kiterjesztéseként van implementálva, minden releváns kód a saját dedikált alkönyvtárában van és egy funkciójelzőn keresztül aktiválható. Ez a tervezés megőrzi az eredeti kód integritását, lehetővé téve a PoCX tiszta be- és kikapcsolását, ami egyszerűsíti a tesztelést, auditálást és az upstream változásokkal való szinkronban maradást.

Az integráció csak a Proof of Capacity támogatásához szükséges lényeges pontokat érinti. A blokk fejléc ki lett bővítve PoCX-specifikus mezőkkel, és a konszenzus validáció adaptálva lett a tárolás-alapú bizonyítékok feldolgozására a hagyományos Bitcoin ellenőrzések mellett. A kovácsolási rendszer, amely a határidők kezeléséért, ütemezésért és bányász beküldésekért felelős, teljes egészében a PoCX modulokon belül van, míg az RPC kiterjesztések a bányászati és megbízási funkcionalitást teszik elérhetővé külső kliensek számára. A felhasználók számára a tárca interfész ki lett bővítve a megbízások OP_RETURN tranzakciókon keresztüli kezelésére, lehetővé téve a zökkenőmentes interakciót az új konszenzus funkciókkal.

Minden konszenzus-kritikus művelet determinisztikus C++-ban van implementálva külső függőségek nélkül, biztosítva a platformok közötti konzisztenciát. A Shabal256-ot használják hash-elésre, míg a Time Bending és minőség számítás fixpontos aritmetikára és 256 bites műveletekre támaszkodik. A kriptográfiai műveletek, mint az aláírás ellenőrzés, a Bitcoin Core meglévő secp256k1 könyvtárát használják.

A PoCX funkcionalitás ilyen módon történő elkülönítésével az implementáció auditálható, karbantartható és teljesen kompatibilis marad a folyamatos Bitcoin Core fejlesztéssel, demonstrálva, hogy egy alapvetően új tárolás-kötött konszenzus mechanizmus együtt létezhet egy érett proof-of-work kódbázissal annak integritásának vagy használhatóságának megzavarása nélkül.

---

## 10. Hálózati Paraméterek

A PoCX a Bitcoin hálózati infrastruktúrájára épít és újrahasználja a lánc paraméter keretrendszerét. A kapacitás-alapú bányászat, megbízás kezelés és plot skálázás támogatásához számos paraméter ki lett bővítve vagy felülírva. Ez magában foglalja a blokkidő célt, kezdeti jutalmat, felezési ütemtervet, megbízás aktiválási és visszavonási késleltetéseket, valamint a hálózati azonosítókat, mint a magic bájtok, portok és Bech32 előtagok. A testnet és regtest környezetek tovább állítják ezeket a paramétereket a gyors iteráció és alacsony kapacitású tesztelés lehetővé tételéhez.

Az alábbi táblázatok összefoglalják az eredményül kapott mainnet, testnet és regtest beállításokat, kiemelve, hogyan adaptálja a PoCX a Bitcoin alapparamétereit egy tárolás-kötött konszenzus modellhez.

### 10.1 Mainnet

| Paraméter | Érték |
|-----------|-------|
| Magic bájtok | `0xa7 0x3c 0x91 0x5e` |
| Alapértelmezett port | 8888 |
| Bech32 HRP | `pocx` |
| Blokkidő cél | 120 másodperc |
| Kezdeti jutalom | 10 BTC |
| Felezési intervallum | 1050000 blokk (~4 év) |
| Teljes kínálat | ~21 millió BTC |
| Megbízás aktiválás | 30 blokk |
| Megbízás visszavonás | 720 blokk |
| Gördülő ablak | 24 blokk |

### 10.2 Testnet

| Paraméter | Érték |
|-----------|-------|
| Magic bájtok | `0x6d 0xf2 0x48 0xb3` |
| Alapértelmezett port | 18888 |
| Bech32 HRP | `tpocx` |
| Blokkidő cél | 120 másodperc |
| Egyéb paraméterek | Megegyezik a mainnet-tel |

### 10.3 Regtest

| Paraméter | Érték |
|-----------|-------|
| Magic bájtok | `0xfa 0xbf 0xb5 0xda` |
| Alapértelmezett port | 18444 |
| Bech32 HRP | `rpocx` |
| Blokkidő cél | 1 másodperc |
| Felezési intervallum | 500 blokk |
| Megbízás aktiválás | 4 blokk |
| Megbízás visszavonás | 8 blokk |
| Alacsony kapacitás mód | Engedélyezve (~4 MB plotok) |

---

## 11. Kapcsolódó Munkák

Az évek során számos blokklánc és konszenzus projekt vizsgálta a tárolás-alapú vagy hibrid bányászati modelleket. A PoCX erre az örökségre épít, miközben fejlesztéseket vezet be a biztonság, hatékonyság és kompatibilitás terén.

**Burstcoin / Signum.** A Burstcoin vezette be az első praktikus Proof-of-Capacity (PoC) rendszert 2014-ben, meghatározva az alapvető koncepciókat, mint a plotok, nonce-ok, scoop-ok és határidő-alapú bányászat. Utódai, különösen a Signum (korábban Burstcoin), kibővítették az ökoszisztémát és végül kifejlesztették a Proof-of-Commitment (PoC+) néven ismert rendszert, amely a tárolási elkötelezettséget opcionális stakinggel kombinálva befolyásolja a hatékony kapacitást. A PoCX örökli a tárolás-alapú bányászati alapot ezektől a projektektől, de jelentősen eltér a megerősített plotfájl formátummal (XOR-transzponálás kódolás), dinamikus plot-munka skálázással, határidő simítással ("Time Bending"), és rugalmas megbízási rendszerrel — mindezt a Bitcoin Core kódbázisba horgonyozva ahelyett, hogy önálló hálózati elágazást tartana fenn.

**Chia.** A Chia Proof of Space and Time-ot implementál, amely lemez-alapú tárolási bizonyítékokat kombinál egy VDF-ekkel (Verifiable Delay Functions) érvényesített idő komponenssel. A tervezés bizonyos aggályokat kezel a bizonyíték újrafelhasználás és a friss kihívás generálás kapcsán, ami különbözik a klasszikus PoC-től. A PoCX nem fogadja el ezt az időhöz kötött bizonyítási modellt; ehelyett fenntart egy tárolás-kötött konszenzust kiszámítható intervallumokkal, optimalizálva a hosszú távú kompatibilitásra az UTXO gazdaságtannal és a Bitcoin-származtatott eszköztárral.

**Spacemesh.** A Spacemesh egy Proof-of-Space-Time (PoST) sémát javasol DAG-alapú (mesh) hálózati topológiával. Ebben a modellben a résztvevőknek időszakosan bizonyítaniuk kell, hogy az allokált tárolás sértetlen marad az idő múlásával, ahelyett, hogy egyetlen előre kiszámított adathalmazra támaszkodnának. A PoCX ezzel szemben csak a blokk időpontjában ellenőrzi a tárolási elkötelezettséget — megerősített plotfájl formátumokkal és szigorú bizonyíték validációval — elkerülve a folyamatos tárolási bizonyítékok többletét, miközben megőrzi a hatékonyságot és decentralizációt.

---

## 12. Összefoglalás

A Bitcoin-PoCX demonstrálja, hogy az energiahatékony konszenzus integrálható a Bitcoin Core-ba, miközben megőrzi a biztonsági tulajdonságokat és a gazdasági modellt. A kulcsfontosságú hozzájárulások közé tartozik az XOR-transzponálás kódolás (kényszeríti a támadókat, hogy 4096 nonce-ot számítsanak keresésenkénti, kiküszöbölve a tömörítési támadást), a Time Bending algoritmus (eloszlás transzformáció csökkenti a blokkidő szórást), a kovácsolási megbízási rendszer (OP_RETURN-alapú delegálás lehetővé teszi a nem-letéteményes pool bányászatot), a dinamikus skálázás (felezésekhez igazított a biztonsági határok fenntartásához), és a minimális integráció (funkciójelzéssel ellátott kód dedikált könyvtárba izolálva).

A rendszer jelenleg teszthálózati fázisban van. A bányászati teljesítmény a tárolókapacitásból származik a hash ráta helyett, nagyságrendekkel csökkentve az energiafogyasztást, miközben fenntartja a Bitcoin bizonyított gazdasági modelljét.

---

## Hivatkozások

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licenc**: MIT
**Szervezet**: Proof of Capacity Consortium
**Állapot**: Teszthálózati Fázis

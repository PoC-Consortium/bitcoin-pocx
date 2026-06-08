[← Előző: RPC Referencia](7-rpc-reference.md) | [📘 Tartalomjegyzék](index.md)

---

# 8. Fejezet: Tárca és GUI Felhasználói Útmutató

Teljes útmutató a Bitcoin-PoCX Qt tárcához és a kovácsolási megbízások kezeléséhez.

---

## Tartalomjegyzék

1. [Áttekintés](#áttekintés)
2. [Pénznem Egységek](#pénznem-egységek)
3. [Kovácsolási Megbízás Párbeszédpanel](#kovácsolási-megbízás-párbeszédpanel)
4. [Tranzakciótörténet](#tranzakciótörténet)
5. [Cím Követelmények](#cím-követelmények)
6. [Bányászat Integráció](#bányászat-integráció)
7. [Hibaelhárítás](#hibaelhárítás)
8. [Biztonsági Legjobb Gyakorlatok](#biztonsági-legjobb-gyakorlatok)

---

## Áttekintés

### Bitcoin-PoCX Tárca Funkciók

A Bitcoin-PoCX Qt tárca (`bitcoin-qt`) biztosítja:
- Szabványos Bitcoin Core tárca funkcionalitás (küldés, fogadás, tranzakció kezelés)
- **Kovácsolási Megbízás Kezelő**: GUI megbízások létrehozásához/visszavonásához
- **Mining Features**: Mining RPCs and forging assignments are always available when compiled with `ENABLE_POCX=ON`
- **Tranzakciótörténet**: Megbízás és visszavonás tranzakciók megjelenítése

### Tárca Indítása

**Csak Csomópont** (bányászat nélkül):
```bash
./build/bin/bitcoin-qt
```

**With RPC** (for external miners):
```bash
./build/bin/bitcoin-qt -server
```

**Parancssori Alternatíva**:
```bash
./build/bin/bitcoind
```

### Bányászati Követelmények

**Bányászati Műveletekhez**:
- `` jelző szükséges
- Tárca P2WPKH címekkel és privát kulcsokkal
- Külső plotter (`pocx_plotter`) a plotfájl generáláshoz
- Külső bányász (`pocx_miner`) a bányászathoz

**Pool Bányászathoz**:
- Kovácsolási megbízás létrehozása a pool címre
- Tárcára nincs szükség a pool szerveren (a pool kezeli a kulcsokat)

---

## Pénznem Egységek

### Egység Megjelenítés

A Bitcoin-PoCX **BTCX** pénznem egységet használ (nem BTC):

| Egység | Satoshi | Megjelenítés |
|--------|---------|--------------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI Beállítások**: Beállítások → Megjelenítés → Egység

---

## Kovácsolási Megbízás Párbeszédpanel

### Párbeszédpanel Elérése

**Menü**: `Tárca → Kovácsolási Megbízások`
**Eszköztár**: Bányászat ikon (csak `` jelzővel látható)
**Ablak Méret**: 600×450 pixel

### Párbeszédpanel Módok

#### 1. Mód: Megbízás Létrehozása

**Cél**: Kovácsolási jogok delegálása pool-nak vagy másik címnek, miközben megtartja a plot tulajdonjogát.

**Felhasználási Esetek**:
- Pool bányászat (megbízás pool címre)
- Hideg tárolás (bányász kulcs elkülönítése a plot tulajdonjogtól)
- Megosztott infrastruktúra (delegálás forró tárcához)

**Követelmények**:
- Plot cím (P2WPKH bech32, privát kulccsal kell rendelkeznie)
- Kovácsolási cím (P2WPKH bech32, különbözik a plot címtől)
- Tárca feloldva (ha titkosított)
- Plot címnek megerősített UTXO-kkal kell rendelkeznie

**Lépések**:
1. Válassza a "Megbízás Létrehozása" módot
2. Válassza ki a plot címet a legördülőből vagy adja meg manuálisan
3. Adja meg a kovácsolási címet (pool vagy delegált)
4. Kattintson a "Megbízás Küldése" gombra (gomb engedélyezve, ha a bemenetek érvényesek)
5. Tranzakció azonnal közvetítve
6. Megbízás aktív `nForgingAssignmentDelay` blokk után:
   - Mainnet/Testnet: 30 blokk (~1 óra)
   - Regtest: 4 blokk (~8 perc 120mp-es ütemezésnél)

**Tranzakciós Díj**: Alapértelmezett 10× `minRelayFee` (testre szabható)

**Tranzakció Szerkezet**:
- Bemenet: UTXO a plot címről (tulajdonjog bizonyítása)
- OP_RETURN kimenet (46 bájtos szkript, 44 bájtos adatcsomag): `POCX` jelölő + plot_address + forging_address
- Visszajáró kimenet: Visszaadva a tárcának

#### 2. Mód: Megbízás Visszavonása

**Cél**: Kovácsolási megbízás törlése és jogok visszaadása a plot tulajdonosnak.

**Követelmények**:
- Plot cím (privát kulccsal kell rendelkeznie)
- Tárca feloldva (ha titkosított)
- Plot címnek megerősített UTXO-kkal kell rendelkeznie

**Lépések**:
1. Válassza a "Megbízás Visszavonása" módot
2. Válassza ki a plot címet
3. Kattintson a "Visszavonás Küldése" gombra
4. Tranzakció azonnal közvetítve
5. Visszavonás hatályos `nForgingRevocationDelay` blokk után:
   - Mainnet/Testnet: 720 blokk (~24 óra)
   - Regtest: 8 blokk (~16 perc 120mp-es ütemezésnél)

**Hatás**:
- Kovácsolási cím továbbra is kovácsolhat a késleltetési időszakban
- Plot tulajdonos visszanyeri a jogokat a visszavonás befejezése után
- Utána új megbízás létrehozható

**Tranzakció Szerkezet**:
- Bemenet: UTXO a plot címről (tulajdonjog bizonyítása)
- OP_RETURN kimenet (26 bájtos szkript, 24 bájtos adatcsomag): `XCOP` jelölő + plot_address
- Visszajáró kimenet: Visszaadva a tárcának

#### 3. Mód: Megbízás Állapot Ellenőrzése

**Cél**: Aktuális megbízás állapot lekérdezése bármely plot címhez.

**Követelmények**: Nincs (csak olvasható, nem szükséges tárca)

**Lépések**:
1. Válassza a "Megbízás Állapot Ellenőrzése" módot
2. Adja meg a plot címet
3. Kattintson az "Állapot Ellenőrzése" gombra
4. Állapot doboz megjeleníti az aktuális állapotot részletekkel

**Állapot Jelzők** (színkódolt):

**Szürke - UNASSIGNED (NINCS MEGBÍZÁS)**
```
UNASSIGNED - Nincs megbízás
```

**Narancssárga - ASSIGNING (MEGBÍZÁS FOLYAMATBAN)**
```
ASSIGNING - Megbízás aktiválásra vár
Kovácsolási Cím: pocx1qforger...
Létrehozva a magasságon: 12000
Aktiválás a magasságon: 12030 (5 blokk hátra)
```

**Zöld - ASSIGNED (MEGBÍZVA)**
```
ASSIGNED - Aktív megbízás
Kovácsolási Cím: pocx1qforger...
Létrehozva a magasságon: 12000
Aktiválva a magasságon: 12030
```

**Piros-Narancssárga - REVOKING (VISSZAVONÁS FOLYAMATBAN)**
```
REVOKING - Visszavonás függőben
Kovácsolási Cím: pocx1qforger... (még aktív)
Megbízás létrehozva a magasságon: 12000
Visszavonva a magasságon: 12300
Visszavonás hatályos a magasságon: 13020 (50 blokk hátra)
```

**Piros - REVOKED (VISSZAVONVA)**
```
REVOKED - Megbízás visszavonva
Korábban megbízva: pocx1qforger...
Megbízás létrehozva a magasságon: 12000
Visszavonva a magasságon: 12300
Visszavonás hatályos a magasságon: 13020
```

---

## Tranzakciótörténet

### Megbízás Tranzakció Megjelenítés

**Típus**: "Megbízás"
**Ikon**: Bányászat ikon (megegyezik a bányászott blokkokkal)

**Cím Oszlop**: Plot cím (amelynek kovácsolási jogai megbízásra kerülnek)
**Összeg Oszlop**: Tranzakciós díj (negatív, kimenő tranzakció)
**Állapot Oszlop**: Megerősítések száma (0-6+)

**Részletek** (kattintáskor):
- Tranzakció ID
- Plot cím
- Kovácsolási cím (OP_RETURN-ból elemezve)
- Létrehozás magassága
- Aktiválási magasság
- Tranzakciós díj
- Időbélyeg

### Visszavonás Tranzakció Megjelenítés

**Típus**: "Visszavonás"
**Ikon**: Bányászat ikon

**Cím Oszlop**: Plot cím
**Összeg Oszlop**: Tranzakciós díj (negatív)
**Állapot Oszlop**: Megerősítések száma

**Részletek** (kattintáskor):
- Tranzakció ID
- Plot cím
- Visszavonás magassága
- Visszavonás hatályossági magassága
- Tranzakciós díj
- Időbélyeg

### Tranzakció Szűrés

**Elérhető Szűrők**:
- "Összes" (alapértelmezett, tartalmazza a megbízásokat/visszavonásokat)
- Dátum tartomány
- Összeg tartomány
- Keresés cím szerint
- Keresés tranzakció ID szerint
- Keresés címke szerint (ha a cím címkézett)

**Megjegyzés**: A megbízás/visszavonás tranzakciók jelenleg az "Összes" szűrő alatt jelennek meg. Dedikált típus szűrő még nincs implementálva.

### Tranzakció Rendezés

**Rendezési Sorrend** (típus szerint):
- Generált (típus 0)
- Fogadott (típus 1-3)
- Megbízás (típus 4)
- Visszavonás (típus 5)
- Küldött (típus 6+)

---

## Cím Követelmények

### Csak P2WPKH (SegWit v0)

**Kovácsolási műveletekhez szükséges**:
- Bech32 kódolású címek ("pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest kezdetűek)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) formátum
- 20 bájtos kulcs hash

**NEM Támogatott**:
- P2PKH (örökség, "1"-gyel kezdődő)
- P2SH (burkolt SegWit, "3"-mal kezdődő)
- P2TR (Taproot, "bc1p"-vel kezdődő)

**Indoklás**: A PoCX blokk aláírások specifikus witness v0 formátumot igényelnek a bizonyíték validációhoz.

### Cím Legördülő Szűrés

**Plot Cím ComboBox**:
- Automatikusan kitöltve a tárca fogadási címeivel
- Kiszűri a nem-P2WPKH címeket
- Formátum: "Címke (cím)" ha címkézett, különben csak cím
- Első elem: "-- Egyéni cím megadása --" manuális bevitelhez

**Manuális Bevitel**:
- Formátum validálva bevitelkor
- Érvényes bech32 P2WPKH-nak kell lennie
- Gomb letiltva, ha érvénytelen formátum

### Validációs Hibaüzenetek

**Párbeszédpanel Hibák**:
- "Plot címnek P2WPKH-nak (bech32) kell lennie"
- Invalid forging address silently disables the Send button
- "Érvénytelen cím formátum"
- "Nincs elérhető érme a plot címen. Nem lehet bizonyítani a tulajdonjogot."
- "Nem lehet tranzakciókat létrehozni csak-figyelő tárcával"
- "Tárca nem elérhető"
- "Tárca zárolva" (RPC-ből)

---

## Bányászat Integráció

### Beállítási Követelmények

**Csomópont Konfiguráció**:
```bash
# bitcoin.conf
server=1
```

**Tárca Követelmények**:
- P2WPKH címek plot tulajdonjoghoz
- Privát kulcsok bányászathoz (vagy kovácsolási cím, ha megbízásokat használ)
- Megerősített UTXO-k tranzakció létrehozáshoz

**Külső Eszközök**:
- `pocx_plotter`: Plotfájlok generálása
- `pocx_miner`: Plotok átnézése és nonce-ok beküldése

### Munkafolyamat

#### Szóló Bányászat

1. **Plotfájlok Generálása**:
   ```bash
   pocx_plotter --account <plot_cím_hash160> --seed <32_bájt> --nonces <darab>
   ```

2. **Csomópont Indítása** bányász szerverrel:
   ```bash
   bitcoin-qt -server
   ```

3. **Bányász Konfigurálása**:
   - Mutasson a csomópont RPC végpontra
   - Adja meg a plotfájl könyvtárakat
   - Konfigurálja az account ID-t (plot címből)

4. **Bányászat Indítása**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /útvonal/plotokhoz
   ```

5. **Monitorozás**:
   - Bányász hívja a `get_mining_info`-t minden blokknál
   - Átnézi a plotokat a legjobb határidőért
   - Hívja a `submit_nonce`-t megoldás találatakor
   - Csomópont validálja és automatikusan kovácsolja a blokkot

#### Pool Bányászat

1. **Plotfájlok Generálása** (megegyezik a szóló bányászattal)

2. **Kovácsolási Megbízás Létrehozása**:
   - Nyissa meg a Kovácsolási Megbízás Párbeszédpanelt
   - Válassza ki a plot címet
   - Adja meg a pool kovácsolási címét
   - Kattintson a "Megbízás Küldése" gombra
   - Várjon az aktiválási késleltetésre (30 blocks mainnet/testnet))

3. **Bányász Konfigurálása**:
   - Mutasson a **pool** végpontra (nem a helyi csomópontra)
   - Pool kezeli a `submit_nonce`-t a láncra

4. **Pool Működés**:
   - Pool tárcának van kovácsolási cím privát kulcsa
   - Pool validálja a beküldéseket bányászoktól
   - Pool hívja a `submit_nonce`-t a blokkláncra
   - Pool elosztja a jutalmakat a pool szabályzat szerint

### Coinbase Jutalmak

**Nincs Megbízás**:
- Coinbase közvetlenül a plot tulajdonos címre fizet
- Ellenőrizze az egyenleget a plot címen

**Megbízással**:
- Coinbase a kovácsolási címre fizet
- Pool kapja a jutalmakat
- Bányász részesedést kap a pool-tól

**Jutalom Ütemterv**:
- Kezdeti: 10 BTCX blokkonként
- Felezés: Minden 1050000 blokkonként (~4 év)
- Ütemterv: 10 → 5 → 2.5 → 1.25 → ...

---

## Hibaelhárítás

### Gyakori Problémák

#### "Tárca nem rendelkezik privát kulccsal a plot címhez"

**Ok**: Tárca nem birtokolja a címet
**Megoldás**:
- Importálja a privát kulcsot `importprivkey` RPC-vel
- Vagy használjon másik, a tárca által birtokolt plot címet

#### "Megbízás már létezik ehhez a plothoz"

**Ok**: Plot már megbízva másik címre
**Megoldás**:
1. Vonja vissza a meglévő megbízást
2. Várjon a visszavonási késleltetésre (720 blocks mainnet/testnet))
3. Hozzon létre új megbízást

#### "Cím formátum nem támogatott"

**Ok**: Cím nem P2WPKH bech32
**Megoldás**:
- Használjon "pocx1q" (mainnet) vagy "tpocx1q" (testnet) kezdetű címeket
- Generáljon új címet, ha szükséges: `getnewaddress "" "bech32"`

#### "Tranzakciós díj túl alacsony"

**Ok**: Hálózati mempool torlódás vagy díj túl alacsony a továbbításhoz
**Megoldás**:
- Növelje a díj ráta paramétert
- Várjon a mempool kiürülésére

#### "Megbízás még nem aktív"

**Ok**: Aktiválási késleltetés még nem telt le
**Megoldás**:
- Ellenőrizze az állapotot: hátralévő blokkok az aktiválásig
- Várja meg a késleltetési periódus befejezését

#### "Nincs elérhető érme a plot címen"

**Ok**: Plot címnek nincs megerősített UTXO-ja
**Megoldás**:
1. Küldjön pénzt a plot címre
2. Várjon 1 megerősítésre
3. Próbálja újra a megbízás létrehozását

#### "Nem lehet tranzakciókat létrehozni csak-figyelő tárcával"

**Ok**: Tárca privát kulcs nélkül importálta a címet
**Megoldás**: Importálja a teljes privát kulcsot, nem csak a címet

### Hibakeresési Lépések

1. **Tárca Állapot Ellenőrzése**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Cím Tulajdonjog Ellenőrzése**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Ellenőrizze: "iswatchonly": false, "ismine": true
   ```

3. **Megbízás Állapot Ellenőrzése**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Legutóbbi Tranzakciók Megtekintése**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Csomópont Szinkronizáció Ellenőrzése**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Ellenőrizze: blocks == headers (teljesen szinkronizált)
   ```

---

## Biztonsági Legjobb Gyakorlatok

### Plot Cím Biztonság

**Kulcs Kezelés**:
- Plot cím privát kulcsok biztonságos tárolása
- Megbízás tranzakciók aláírással bizonyítják a tulajdonjogot
- Csak plot tulajdonos hozhat létre/vonhat vissza megbízásokat

**Biztonsági Mentés**:
- Rendszeres tárca mentés (`dumpwallet` vagy `backupwallet`)
- wallet.dat tárolása biztonságos helyen
- Helyreállítási mondatok rögzítése, ha HD tárcát használ

### Kovácsolási Cím Delegálás

**Biztonsági Modell**:
- Kovácsolási cím kapja a blokkjutalmakat
- Kovácsolási cím aláírhat blokkokat (bányászat)
- Kovácsolási cím **NEM tudja** módosítani vagy visszavonni a megbízást
- Plot tulajdonos megtartja a teljes kontrollt

**Felhasználási Esetek**:
- **Forró Tárca Delegálás**: Plot kulcs hideg tárolásban, kovácsolási kulcs forró tárcában bányászathoz
- **Pool Bányászat**: Delegálás pool-nak, plot tulajdonjog megtartása
- **Megosztott Infrastruktúra**: Több bányász, egy kovácsolási cím

### Hálózati Idő Szinkronizáció

**Fontosság**:
- PoCX konszenzus pontos időt igényel
- >10mp óraeltérés figyelmeztetést aktivál
- >15mp óraeltérés megakadályozza a bányászatot

**Megoldás**:
- Tartsa szinkronban a rendszerórát NTP-vel
- Monitorozza: `bitcoin-cli getnetworkinfo` időeltolás figyelmeztetésekért
- Használjon megbízható NTP szervereket

### Megbízás Késleltetések

**Aktiválási Késleltetés** (30 blocks mainnet/testnet)):
- Megakadályozza a gyors újrahozzárendelést lánc elágazások során
- Lehetővé teszi a hálózat konszenzusának elérését
- Nem kerülhető meg

**Visszavonási Késleltetés** (720 blocks mainnet/testnet)):
- Stabilitást biztosít bányász pool-oknak
- Megakadályozza a megbízás "griefing" támadásokat
- Kovácsolási cím aktív marad a késleltetés alatt

### Tárca Titkosítás

**Titkosítás Engedélyezése**:
```bash
bitcoin-cli encryptwallet "az_ön_jelszava"
```

**Feloldás Tranzakciókhoz**:
```bash
bitcoin-cli walletpassphrase "az_ön_jelszava" 300
```

**Legjobb Gyakorlatok**:
- Használjon erős jelszót (20+ karakter)
- Ne tárolja a jelszót egyszerű szövegben
- Zárolja a tárcát megbízások létrehozása után

---

## Kód Hivatkozások

**Kovácsolási Megbízás Párbeszédpanel**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Tranzakció Megjelenítés**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Tranzakció Elemzés**: `src/qt/transactionrecord.cpp`
**Tárca Integráció**: `src/pocx/assignments/transactions.cpp`
**Megbízás RPC-k**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Fő**: `src/qt/bitcoingui.cpp`

---

## Kereszthivatkozások

Kapcsolódó fejezetek:
- [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md) - Bányászati folyamat
- [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md) - Megbízás architektúra
- [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md) - Megbízás késleltetés értékek
- [7. Fejezet: RPC Referencia](7-rpc-reference.md) - RPC parancs részletek

---

[← Előző: RPC Referencia](7-rpc-reference.md) | [📘 Tartalomjegyzék](index.md)

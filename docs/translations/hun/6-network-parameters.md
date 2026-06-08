[← Előző: Időszinkronizáció](5-timing-security.md) | [📘 Tartalomjegyzék](index.md) | [Következő: RPC Referencia →](7-rpc-reference.md)

---

# 6. Fejezet: Hálózati Paraméterek és Konfiguráció

Teljes referencia a Bitcoin-PoCX hálózati konfigurációhoz minden hálózattípuson.

---

## Tartalomjegyzék

1. [Genezis Blokk Paraméterek](#genezis-blokk-paraméterek)
2. [Chainparams Konfiguráció](#chainparams-konfiguráció)
3. [Konszenzus Paraméterek](#konszenzus-paraméterek)
4. [Coinbase és Blokkjutalmak](#coinbase-és-blokkjutalmak)
5. [Dinamikus Skálázás](#dinamikus-skálázás)
6. [Hálózati Konfiguráció](#hálózati-konfiguráció)
7. [Adatkönyvtár Struktúra](#adatkönyvtár-struktúra)

---

## Genezis Blokk Paraméterek

### Alap Célérték Számítás

**Formula**: `genezis_alap_célérték = 2^42 / blokkidő_másodperc`

**Indoklás**:
- Minden nonce 256 KiB-ot képvisel (64 bájt × 4096 scoop)
- 1 TiB = 2^22 nonce (kiinduló hálózati kapacitás feltételezés)
- Várt minimum minőség n nonce-hoz ≈ 2^64 / n
- 1 TiB-hez: E(minőség) = 2^64 / 2^22 = 2^42
- Ezért: alap_célérték = 2^42 / blokkidő

**Számított Értékek**:
- Mainnet/Testnet/Signet (120mp): `36650387592`
- Regtest (1mp): Alacsony kapacitású kalibrációs módot használ

### Genezis Üzenet

Each network has its own genesis message. See `src/kernel/chainparams.cpp` for details.

---

## Chainparams Konfiguráció

### Mainnet Paraméterek

**Hálózati Azonosítás**:
- **Magic Bájtok**: `0xa7 0x3c 0x91 0x5e`
- **Alapértelmezett Port**: `8338`
- **Bech32 HRP**: `pocx`

**Cím Előtagok** (Base58):
- PUBKEY_ADDRESS: `85` (címek 'P'-vel kezdődnek)
- SCRIPT_ADDRESS: `90` (címek 'R'-rel kezdődnek)
- SECRET_KEY: `128`

**Blokk Időzítés**:
- **Blokk Idő Cél**: `120` másodperc (2 perc)
- **Cél Időtartam**: `1209600` másodperc (14 nap)
- **MAX_FUTURE_BLOCK_TIME**: `15` másodperc

**Blokkjutalmak**:
- **Kezdeti Jutalom**: `10 BTC`
- **Felezési Intervallum**: `1050000` blokk (~4 év)
- **Felezések Száma**: Maximum 64 felezés

**Nehézség Beállítás**:
- **Gördülő Ablak**: `24` blokk
- **Beállítás**: Minden blokk
- **Algoritmus**: Exponenciális mozgóátlag

**Megbízás Késleltetések**:
- **Aktiválás**: `30` blokk (~1 óra)
- **Visszavonás**: `720` blokk (~24 óra)

### Testnet Paraméterek

**Hálózati Azonosítás**:
- **Magic Bájtok**: `0x6d 0xf2 0x48 0xb4`
- **Alapértelmezett Port**: `18338`
- **Bech32 HRP**: `tpocx`

**Cím Előtagok** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `239`

**Blokk Időzítés**:
- **Blokk Idő Cél**: `120` másodperc
- **MAX_FUTURE_BLOCK_TIME**: `15` másodperc
- **Min Nehézség Engedélyezése**: `true`

**Blokkjutalmak**:
- **Kezdeti Jutalom**: `10 BTC`
- **Felezési Intervallum**: `1050000` blokk

**Nehézség Beállítás**:
- **Gördülő Ablak**: `24` blokk

**Megbízás Késleltetések**:
- **Aktiválás**: `30` blokk (~1 óra)
- **Visszavonás**: `720` blokk (~24 óra)

### Regtest Paraméterek

**Hálózati Azonosítás**:
- **Magic Bájtok**: `0xfa 0xbf 0xb5 0xda`
- **Alapértelmezett Port**: `18444`
- **Bech32 HRP**: `rpocx`

**Cím Előtagok** (Bitcoin-kompatibilis):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Blokk Időzítés**:
- **Blokk Idő Cél**: `1` másodperc (azonnali bányászat teszteléshez)
- **Cél Időtartam**: `86400` másodperc (1 nap)
- **MAX_FUTURE_BLOCK_TIME**: `15` másodperc

**Blokkjutalmak**:
- **Kezdeti Jutalom**: `10 BTC`
- **Felezési Intervallum**: `500` blokk

**Nehézség Beállítás**:
- **Gördülő Ablak**: `24` blokk
- **Min Nehézség Engedélyezése**: `true`
- **Nincs Újracélzás**: `true`
- **Alacsony Kapacitás Kalibráció**: `true` (16-nonce kalibrációt használ 1 TiB helyett)

**Megbízás Késleltetések**:
- **Aktiválás**: `4` blokk (~4 másodperc)
- **Visszavonás**: `8` blokk (~8 másodperc)

### Signet Paraméterek

**Hálózati Azonosítás**:
- **Magic Bájtok**: SHA256d(signet_challenge) első 4 bájtja
- **Alapértelmezett Port**: `38333`
- **Bech32 HRP**: `tpocx`

**Blokk Időzítés**:
- **Blokk Idő Cél**: `120` másodperc
- **MAX_FUTURE_BLOCK_TIME**: `15` másodperc

**Blokkjutalmak**:
- **Kezdeti Jutalom**: `10 BTC`
- **Felezési Intervallum**: `1050000` blokk

**Nehézség Beállítás**:
- **Gördülő Ablak**: `24` blokk

---

## Konszenzus Paraméterek

### Időzítési Paraméterek

**MAX_FUTURE_BLOCK_TIME**: `15` másodperc
- PoCX-specifikus (a Bitcoin 2 órát használ)
- Indoklás: A PoC időzítés közel valós idejű validációt igényel
- A 15mp-nél távolabbi jövőbeli blokkok elutasítva

**Időeltolás Figyelmeztetés**: `10` másodperc
- Üzemeltetők figyelmeztetése, ha a csomópont órája >10mp-vel eltér a hálózati időtől
- Nincs kényszerítés, csak tájékoztató jellegű

**Blokk Idő Célok**:
- Mainnet/Testnet/Signet: `120` másodperc
- Regtest: `1` másodperc

**TIMESTAMP_WINDOW**: `15` másodperc (megegyezik MAX_FUTURE_BLOCK_TIME-mal)

**Implementáció**: `src/chain.h`, `src/validation.cpp`

### Nehézség Beállítási Paraméterek

**Gördülő Ablak Méret**: `24` blokk (minden hálózat)
- Exponenciális mozgóátlag a legutóbbi blokkidőkből
- Minden-blokk beállítás
- Reagál a kapacitásváltozásokra

**Implementáció**: `src/consensus/params.h`, nehézség logika a blokk létrehozásban

### Megbízási Rendszer Paraméterek

**nForgingAssignmentDelay** (aktiválási késleltetés):
- Mainnet: `30` blokk (~1 óra)
- Testnet: `30` blokk (~1 óra)
- Regtest: `4` blokk (~4 másodperc)

**nForgingRevocationDelay** (visszavonási késleltetés):
- Mainnet: `720` blokk (~24 óra)
- Testnet: `720` blokk (~24 óra)
- Regtest: `8` blokk (~8 másodperc)

**Indoklás**:
- Aktiválási késleltetés megakadályozza a gyors újrahozzárendelést blokkversenyek során
- Visszavonási késleltetés stabilitást biztosít és megakadályozza a visszaélést

**Implementáció**: `src/consensus/params.h`

---

## Coinbase és Blokkjutalmak

### Blokk Jutalom Ütemterv

**Kezdeti Jutalom**: `10 BTC` (minden hálózat)

**Felezési Ütemterv**:
- Minden `1050000` blokk (mainnet/testnet)
- Minden `500` blokk (regtest)
- Maximum 64 felezésig folytatódik

**Felezési Progresszió**:
```
0. Felezés: 10.00000000 BTC  (0 - 1049999 blokkok)
1. Felezés:  5.00000000 BTC  (1050000 - 2099999 blokkok)
2. Felezés:  2.50000000 BTC  (2100000 - 3149999 blokkok)
3. Felezés:  1.25000000 BTC  (3150000 - 4199999 blokkok)
...
```

**Teljes Kínálat**: ~21 millió BTC (megegyezik a Bitcoin-nal)

### Coinbase Kimenet Szabályok

**Fizetési Célcím**:
- **Nincs Megbízás**: Coinbase a plot címre fizet (proof.account_id)
- **Megbízással**: Coinbase a kovácsolási címre fizet (effektív aláíró)

**Kimenet Formátum**: Csak P2WPKH
- Coinbase-nek bech32 SegWit v0 címre kell fizetnie
- Az effektív aláíró publikus kulcsából generálva

**Megbízás Feloldás**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementáció**: `src/pocx/mining/block_builder.cpp:BuildBlock()`

---

## Dinamikus Skálázás

### Skálázási Határok

**Cél**: A plotfájl generálási nehézség növelése a hálózat éréséve, a kapacitás infláció megakadályozására

**Struktúra**:
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Minimum elfogadott szint
    uint32_t nPoCXTargetCompression;  // Ajánlott szint
};
```

**Kapcsolat**: `cél = min + 1` (mindig egy szinttel a minimum felett)

### Skálázás Növelési Ütemterv

A skálázási szintek **exponenciális ütemterv** szerint növekednek a felezési intervallumok alapján:

| Időszak | Blokk Magasság | Felezések | Min | Cél |
|---------|----------------|-----------|-----|-----|
| 0-4 Év | 0 - 1049999 | 0 | X1 | X2 |
| 4-12 Év | 1050000 - 3149999 | 1-2 | X2 | X3 |
| 12-28 Év | 3150000 - 7349999 | 3-6 | X3 | X4 |
| 28-60 Év | 7350000 - 15749999 | 7-14 | X4 | X5 |
| 60-124 Év | 15750000 - 32549999 | 15-30 | X5 | X6 |
| 124+ Év | 32550000+ | 31+ | X6 | X7 |

**Kulcs Magasságok** (évek → felezések → blokkok):
- 4. Év: 1. Felezés a 1050000. blokknál
- 12. Év: 3. Felezés a 3150000. blokknál
- 28. Év: 7. Felezés a 7350000. blokknál
- 60. Év: 15. Felezés a 15750000. blokknál
- 124. Év: 31. Felezés a 32550000. blokknál

### Skálázási Szint Nehézség

**PoW Skálázás**:
- Skálázási szint X0: POC2 alapvonal (elméleti)
- Skálázási szint X1: XOR-transzponálás alapvonal
- Skálázási szint Xn: 2^(n-1) × X1 munka beágyazva
- Minden szint megduplázza a plotfájl generálási munkát

**Gazdasági Összehangolás**:
- Blokkjutalmak felezése → plotfájl generálási nehézség növekedése
- Fenntartja a biztonsági határt: plot létrehozási költség > keresési költség
- Megakadályozza a kapacitás inflációt a hardver fejlődéséből

### Plot Validáció

**Validációs Szabályok**:
- Beküldött bizonyítékoknak skálázási szint ≥ minimum kell legyen
- A célnál magasabb skálázású bizonyítékok elfogadva, de nem hatékonyak
- Minimum alatti bizonyítékok: elutasítva (elégtelen PoW)

**Határok Lekérése**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementáció**: `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Hálózati Konfiguráció

### Seed Csomópontok és DNS Seed-ek

**Állapot**: Aktív (mainnet élő 2026. május 3. óta)

**Mainnet DNS Seed-ek**:
- `seeds.bitcoin-pocx.org`
- `bitcoin-pocx.bootseed.net`

**Testnet DNS Seed-ek**:
- `testnet.seeds.bitcoin-pocx.org`

**Konfiguráció**:
- Rögzített seed-ek a `src/pocx/pocx_seeds.h` fájlban (BIP155 formátum)
- Manuális társ csatlakozások szintén támogatva `-addnode`-dal

**Implementáció**: `src/kernel/chainparams.cpp`

### Ellenőrzőpontok

**Genezis Ellenőrzőpont**: Mindig a 0. blokk

**További Ellenőrzőpontok**: Jelenleg nincs konfigurálva

**Jövő**: Ellenőrzőpontok hozzáadva a mainnet előrehaladtával

---

## P2P Protokoll Konfiguráció

### Protokoll Verzió

**Alap**: Bitcoin Core v30.2 protokoll
- **Protokoll Verzió**: Bitcoin Core-ból örökölt
- **Szolgáltatás Bitek**: Szabványos Bitcoin szolgáltatások
- **Üzenet Típusok**: Szabványos Bitcoin P2P üzenetek

**PoCX Kiterjesztések**:
- Blokk fejlécek PoCX-specifikus mezőket tartalmaznak
- Blokk üzenetek PoCX bizonyíték adatokat tartalmaznak
- Validációs szabályok érvényesítik a PoCX konszenzust

**Kompatibilitás**: PoCX csomópontok nem kompatibilisek Bitcoin PoW csomópontokkal (eltérő konszenzus)

**Implementáció**: `src/protocol.h`, `src/net_processing.cpp`

---

## Adatkönyvtár Struktúra

### Alapértelmezett Könyvtár

**Hely**: `.bitcoin/` (megegyezik a Bitcoin Core-ral)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Könyvtár Tartalom

```
.bitcoin/
├── blocks/              # Blokk adatok
│   ├── blk*.dat        # Blokk fájlok
│   ├── rev*.dat        # Visszavonási adatok
│   └── index/          # Blokk index (LevelDB)
├── chainstate/         # UTXO halmaz + kovácsolási megbízások (LevelDB)
├── wallets/            # Tárca fájlok
│   └── wallet.dat      # Alapértelmezett tárca
├── bitcoin.conf        # Konfigurációs fájl
├── debug.log           # Debug napló
├── peers.dat           # Társ címek
├── mempool.dat         # Mempool perzisztencia
└── banlist.dat         # Tiltott társak
```

### Fő Különbségek a Bitcoin-tól

**Chainstate Adatbázis**:
- Szabványos: UTXO halmaz
- **PoCX Kiegészítés**: Kovácsolási megbízás állapot
- Atomi frissítések: UTXO + megbízások együtt frissítve
- Reorg-biztos visszavonási adatok megbízásokhoz

**Blokk Fájlok**:
- Szabványos Bitcoin blokk formátum
- **PoCX Kiegészítés**: PoCX bizonyíték mezőkkel kibővítve (account_id, seed, nonce, aláírás, pubkey)

### Konfigurációs Fájl Példa

**bitcoin.conf**:
```ini
# Hálózat kiválasztás
#testnet=1
#regtest=1

# PoCX bányász szerver (külső bányászokhoz szükséges)

# RPC beállítások
server=1
rpcuser=felhasználónév
rpcpassword=jelszó
rpcallowip=127.0.0.1
rpcport=8332

# Kapcsolat beállítások
listen=1
port=8338
maxconnections=125

# Blokk idő cél (tájékoztató, konszenzus által érvényesített)
# 120 másodperc mainnet/testnet-hez
```

---

## Kód Hivatkozások

**Chainparams**: `src/kernel/chainparams.cpp`
**Konszenzus Paraméterek**: `src/consensus/params.h`
**Tömörítési Határok**: `src/pocx/consensus/params.h`, `src/pocx/consensus/params.cpp`
**Genezis Alap Célérték Számítás**: `src/pocx/consensus/params.cpp`
**Coinbase Fizetési Logika**: `src/pocx/mining/block_builder.cpp:BuildBlock()`
**Megbízás Állapot Tárolás**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache kiterjesztések)

---

## Kereszthivatkozások

Kapcsolódó fejezetek:
- [2. Fejezet: Plotfájl Formátum](2-plot-format.md) - Skálázási szintek a plotfájl generálásban
- [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md) - Skálázás validáció, megbízási rendszer
- [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md) - Megbízás késleltetési paraméterek
- [5. Fejezet: Időzítési Biztonság](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME indoklás

---

[← Előző: Időszinkronizáció](5-timing-security.md) | [📘 Tartalomjegyzék](index.md) | [Következő: RPC Referencia →](7-rpc-reference.md)

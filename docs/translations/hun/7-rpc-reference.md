[← Előző: Hálózati Paraméterek](6-network-parameters.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Tárca Útmutató →](8-wallet-guide.md)

---

# 7. Fejezet: RPC Interfész Referencia

Teljes referencia a Bitcoin-PoCX RPC parancsokhoz, beleértve a bányászati RPC-ket, megbízás kezelést és módosított blokklánc RPC-ket.

---

## Tartalomjegyzék

1. [Konfiguráció](#konfiguráció)
2. [PoCX Bányászati RPC-k](#pocx-bányászati-rpc-k)
3. [Megbízás RPC-k](#megbízás-rpc-k)
4. [Módosított Blokklánc RPC-k](#módosított-blokklánc-rpc-k)
5. [Letiltott RPC-k](#letiltott-rpc-k)
6. [Integrációs Példák](#integrációs-példák)

---

## Konfiguráció

### Bányász Szerver Mód

**Jelző**: `-miningserver`

**Cél**: Engedélyezi az RPC hozzáférést külső bányászoknak a bányászat-specifikus RPC-k hívásához

**Követelmények**:
- Szükséges a `submit_nonce` működéséhez
- Szükséges a kovácsolási megbízás párbeszédpanel láthatóságához a Qt tárcában

**Használat**:
```bash
# Parancssor
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Biztonsági Megfontolások**:
- Nincs további hitelesítés a szabványos RPC hitelesítésen túl
- A bányászati RPC-k sor kapacitással korlátozottak
- Szabványos RPC hitelesítés továbbra is szükséges

**Implementáció**: `src/pocx/rpc/mining.cpp`

---

## PoCX Bányászati RPC-k

### get_mining_info

**Kategória**: bányászat
**Bányász Szerver Szükséges**: Nem
**Tárca Szükséges**: Nem

**Cél**: Visszaadja az aktuális bányászati paramétereket, amelyekre a külső bányászoknak szükségük van a plotfájlok átnézéséhez és a határidők számításához.

**Paraméterek**: Nincs

**Visszatérési Értékek**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 karakter
  "base_target": 36650387593,                // numerikus
  "height": 12345,                           // numerikus, következő blokk magasság
  "block_hash": "def456...",                 // hex, előző blokk
  "target_quality": 18446744073709551615,    // uint64_max (minden megoldás elfogadott)
  "minimum_compression_level": 1,            // numerikus
  "target_compression_level": 2              // numerikus
}
```

**Mező Leírások**:
- `generation_signature`: Determinisztikus bányászati entrópia ehhez a blokk magassághoz
- `base_target`: Aktuális nehézség (magasabb = könnyebb)
- `height`: Blokk magasság, amit a bányászoknak célozniuk kell
- `block_hash`: Előző blokk hash (tájékoztató)
- `target_quality`: Minőség küszöb (jelenleg uint64_max, nincs szűrés)
- `minimum_compression_level`: Validációhoz szükséges minimum tömörítés
- `target_compression_level`: Ajánlott tömörítés optimális bányászathoz

**Hibakódok**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Csomópont még szinkronizál

**Példa**:
```bash
bitcoin-cli get_mining_info
```

**Implementáció**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategória**: bányászat
**Bányász Szerver Szükséges**: Igen
**Tárca Szükséges**: Igen (privát kulcsokhoz)

**Cél**: PoCX bányászati megoldás beküldése. Validálja a bizonyítékot, sorba állítja time-bended kovácsoláshoz, és automatikusan létrehozza a blokkot az ütemezett időben.

**Paraméterek**:
1. `height` (numerikus, kötelező) - Blokk magasság
2. `generation_signature` (string hex, kötelező) - Generációs aláírás (64 karakter)
3. `account_id` (string, kötelező) - Plot account ID (40 hex karakter = 20 bájt)
4. `seed` (string, kötelező) - Plot seed (64 hex karakter = 32 bájt)
5. `nonce` (numerikus, kötelező) - Bányászati nonce
6. `compression` (numerikus, kötelező) - Használt skálázási/tömörítési szint (1-255)
7. `quality` (numerikus, opcionális) - Minőség érték (újraszámolva, ha hiányzik)

**Visszatérési Értékek** (sikeres):
```json
{
  "accepted": true,
  "quality": 120,           // nehézség-állított határidő másodpercben
  "poc_time": 45            // time-bended kovácsolási idő másodpercben
}
```

**Visszatérési Értékek** (elutasított):
```json
{
  "accepted": false,
  "error": "Generációs aláírás eltérés"
}
```

**Validációs Lépések**:
1. **Formátum Validáció** (gyors-hiba):
   - Account ID: pontosan 40 hex karakter
   - Seed: pontosan 64 hex karakter
2. **Kontextus Validáció**:
   - Magasságnak egyeznie kell az aktuális csúcs + 1-gyel
   - Generációs aláírásnak egyeznie kell az aktuálissal
3. **Tárca Ellenőrzés**:
   - Effektív aláíró meghatározása (aktív megbízások ellenőrzése)
   - Ellenőrzés, hogy a tárca rendelkezik-e privát kulccsal az effektív aláíróhoz
4. **Bizonyíték Validáció** (költséges):
   - PoCX bizonyíték validálása tömörítési határokkal
   - Nyers minőség számítása
5. **Ütemező Beküldés**:
   - Nonce sorba állítása time-bended kovácsoláshoz
   - Blokk automatikusan létrehozva a kovácsolási időben

**Hibakódok**:
- `RPC_INVALID_PARAMETER`: Érvénytelen formátum (account_id, seed) vagy magasság eltérés
- `RPC_VERIFY_REJECTED`: Generációs aláírás eltérés vagy bizonyíték validáció sikertelen
- `RPC_INVALID_ADDRESS_OR_KEY`: Nincs privát kulcs az effektív aláíróhoz
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Beküldési sor megtelt
- `RPC_INTERNAL_ERROR`: PoCX ütemező inicializálása sikertelen

**Bizonyíték Validációs Hibakódok**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Példa**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_karakter..." \
  999888777 \
  1
```

**Megjegyzések**:
- Beküldés aszinkron - RPC azonnal visszatér, blokk később kovácsolva
- Time Bending késlelteti a jó megoldásokat, hogy a hálózat-szerte megtörténhessen a plot átnézés
- Megbízási rendszer: ha a plot megbízott, a tárcának a kovácsolási cím kulcsával kell rendelkeznie
- Tömörítési határok dinamikusan állítottak a blokk magasság alapján

**Implementáció**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Megbízás RPC-k

### get_assignment

**Kategória**: bányászat
**Bányász Szerver Szükséges**: Nem
**Tárca Szükséges**: Nem

**Cél**: Kovácsolási megbízás állapot lekérdezése plot címhez. Csak olvasható, nincs szükség tárcára.

**Paraméterek**:
1. `plot_address` (string, kötelező) - Plot cím (bech32 P2WPKH formátum)
2. `height` (numerikus, opcionális) - Blokk magasság lekérdezéshez (alapértelmezett: aktuális csúcs)

**Visszatérési Értékek** (nincs megbízás):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Visszatérési Értékek** (aktív megbízás):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Visszatérési Értékek** (visszavonás alatt):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Megbízás Állapotok**:
- `UNASSIGNED`: Nincs megbízás
- `ASSIGNING`: Megbízás tx megerősítve, aktiválási késleltetés folyamatban
- `ASSIGNED`: Megbízás aktív, kovácsolási jogok delegálva
- `REVOKING`: Visszavonás tx megerősítve, még aktív a késleltetés lejártáig
- `REVOKED`: Visszavonás befejezve, kovácsolási jogok visszaadva a plot tulajdonosnak

**Hibakódok**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Érvénytelen cím vagy nem P2WPKH (bech32)

**Példa**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementáció**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategória**: tárca
**Bányász Szerver Szükséges**: Nem
**Tárca Szükséges**: Igen (betöltve és feloldva kell legyen)

**Cél**: Kovácsolási megbízás tranzakció létrehozása kovácsolási jogok delegálásához másik címre (pl. bányász pool).

**Paraméterek**:
1. `plot_address` (string, kötelező) - Plot tulajdonos címe (privát kulccsal kell rendelkeznie, P2WPKH bech32)
2. `forging_address` (string, kötelező) - Cím, ahova a kovácsolási jogok delegálva lesznek (P2WPKH bech32)
3. `fee_rate` (numerikus, opcionális) - Díj ráta BTC/kvB-ben (alapértelmezett: 10× minRelayFee)

**Visszatérési Értékek**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Követelmények**:
- Tárca betöltve és feloldva
- Privát kulcs a plot_address-hez a tárcában
- Mindkét címnek P2WPKH-nak kell lennie (bech32 formátum: pocx1q... mainnet, tpocx1q... testnet)
- Plot címnek megerősített UTXO-kkal kell rendelkeznie (tulajdonjog bizonyítása)
- Plot nem rendelkezhet aktív megbízással (először használja a visszavonást)

**Tranzakció Szerkezet**:
- Bemenet: UTXO a plot címről (tulajdonjog bizonyítása)
- Kimenet: OP_RETURN (46 bájt): `POCX` jelölő + plot_address (20 bájt) + forging_address (20 bájt)
- Kimenet: Visszajáró visszaadva a tárcának

**Aktiválás**:
- Megbízás ASSIGNING-gá válik megerősítéskor
- ACTIVE lesz `nForgingAssignmentDelay` blokk után
- Késleltetés megakadályozza a gyors újrahozzárendelést lánc elágazások során

**Hibakódok**:
- `RPC_WALLET_NOT_FOUND`: Nincs elérhető tárca
- `RPC_WALLET_UNLOCK_NEEDED`: Tárca titkosítva és zárolva
- `RPC_WALLET_ERROR`: Tranzakció létrehozás sikertelen
- `RPC_INVALID_ADDRESS_OR_KEY`: Érvénytelen cím formátum

**Példa**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementáció**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategória**: tárca
**Bányász Szerver Szükséges**: Nem
**Tárca Szükséges**: Igen (betöltve és feloldva kell legyen)

**Cél**: Meglévő kovácsolási megbízás visszavonása, kovácsolási jogok visszaadása a plot tulajdonosnak.

**Paraméterek**:
1. `plot_address` (string, kötelező) - Plot cím (privát kulccsal kell rendelkeznie, P2WPKH bech32)
2. `fee_rate` (numerikus, opcionális) - Díj ráta BTC/kvB-ben (alapértelmezett: 10× minRelayFee)

**Visszatérési Értékek**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Követelmények**:
- Tárca betöltve és feloldva
- Privát kulcs a plot_address-hez a tárcában
- Plot címnek P2WPKH-nak kell lennie (bech32 formátum)
- Plot címnek megerősített UTXO-kkal kell rendelkeznie

**Tranzakció Szerkezet**:
- Bemenet: UTXO a plot címről (tulajdonjog bizonyítása)
- Kimenet: OP_RETURN (26 bájt): `XCOP` jelölő + plot_address (20 bájt)
- Kimenet: Visszajáró visszaadva a tárcának

**Hatás**:
- Állapot azonnal REVOKING-ra változik
- Kovácsolási cím továbbra is kovácsolhat a késleltetési időszakban
- REVOKED lesz `nForgingRevocationDelay` blokk után
- Plot tulajdonos kovácsolhat a visszavonás hatályossá válása után
- Új megbízás létrehozható a visszavonás befejezése után

**Hibakódok**:
- `RPC_WALLET_NOT_FOUND`: Nincs elérhető tárca
- `RPC_WALLET_UNLOCK_NEEDED`: Tárca titkosítva és zárolva
- `RPC_WALLET_ERROR`: Tranzakció létrehozás sikertelen

**Példa**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Megjegyzések**:
- Idempotens: visszavonható aktív megbízás nélkül is
- Nem lehet törölni a visszavonást beküldés után

**Implementáció**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Módosított Blokklánc RPC-k

### getdifficulty

**PoCX Módosítások**:
- **Számítás**: `referencia_alap_célérték / aktuális_alap_célérték`
- **Referencia**: 1 TiB hálózati kapacitás (alap_célérték = 36650387593)
- **Értelmezés**: Becsült hálózati tárolókapacitás TiB-ben
  - Példa: `1.0` = ~1 TiB
  - Példa: `1024.0` = ~1 PiB
- **Különbség a PoW-tól**: Kapacitást képvisel, nem hash teljesítményt

**Példa**:
```bash
bitcoin-cli getdifficulty
# Visszaad: 2048.5 (hálózat ~2 PiB)
```

**Implementáció**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX Hozzáadott Mezők**:
- `time_since_last_block` (numerikus) - Másodpercek az előző blokk óta (helyettesíti a mediantime-ot)
- `poc_time` (numerikus) - Time-bended kovácsolási idő másodpercben
- `base_target` (numerikus) - PoCX nehézség alap célérték
- `generation_signature` (string hex) - Generációs aláírás
- `pocx_proof` (objektum):
  - `account_id` (string hex) - Plot account ID (20 bájt)
  - `seed` (string hex) - Plot seed (32 bájt)
  - `nonce` (numerikus) - Bányászati nonce
  - `compression` (numerikus) - Használt skálázási szint
  - `quality` (numerikus) - Igényelt minőség érték
- `pubkey` (string hex) - Blokk aláíró publikus kulcsa (33 bájt)
- `signer_address` (string) - Blokk aláíró címe
- `signature` (string hex) - Blokk aláírás (65 bájt)

**PoCX Eltávolított Mezők**:
- `mediantime` - Eltávolítva (helyettesítve time_since_last_block-kal)

**Példa**:
```bash
bitcoin-cli getblockheader <blokkhash>
```

**Implementáció**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX Módosítások**: Ugyanaz, mint getblockheader, plusz teljes tranzakció adatok

**Példa**:
```bash
bitcoin-cli getblock <blokkhash>
bitcoin-cli getblock <blokkhash> 2  # bőbeszédű tx részletekkel
```

**Implementáció**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX Hozzáadott Mezők**:
- `base_target` (numerikus) - Aktuális alap célérték
- `generation_signature` (string hex) - Aktuális generációs aláírás

**PoCX Módosított Mezők**:
- `difficulty` - PoCX számítást használ (kapacitás-alapú)

**PoCX Eltávolított Mezők**:
- `mediantime` - Eltávolítva

**Példa**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementáció**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX Hozzáadott Mezők**:
- `generation_signature` (string hex) - Pool bányászathoz
- `base_target` (numerikus) - Pool bányászathoz

**PoCX Eltávolított Mezők**:
- `target` - Eltávolítva (PoW-specifikus)
- `noncerange` - Eltávolítva (PoW-specifikus)
- `bits` - Eltávolítva (PoW-specifikus)

**Megjegyzések**:
- Továbbra is tartalmazza a teljes tranzakció adatokat blokk konstrukcióhoz
- Pool szerverek használják koordinált bányászathoz

**Példa**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementáció**: `src/rpc/mining.cpp`

---

## Letiltott RPC-k

A következő PoW-specifikus RPC-k **letiltottak** PoCX módban:

### getnetworkhashps
- **Ok**: Hash ráta nem alkalmazható Proof of Capacity-re
- **Alternatíva**: Használja a `getdifficulty`-t hálózati kapacitás becsléshez

### getmininginfo
- **Ok**: PoW-specifikus információkat ad vissza
- **Alternatíva**: Használja a `get_mining_info`-t (PoCX-specifikus)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Ok**: CPU bányászat nem alkalmazható PoCX-re (előre generált plotok szükségesek)
- **Alternatíva**: Használjon külső plotter-t + bányászt + `submit_nonce`-t

**Implementáció**: `src/rpc/mining.cpp` (RPC-k hibát adnak vissza, amikor ENABLE_POCX definiálva)

---

## Integrációs Példák

### Külső Bányász Integráció

**Alapvető Bányász Ciklus**:
```python
import requests
import time

RPC_URL = "http://felhasználó:jelszó@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Bányász ciklus
while True:
    # 1. Bányászati paraméterek lekérése
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Plotfájlok átnézése (külső implementáció)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Legjobb megoldás beküldése
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Megoldás elfogadva! Minőség: {result['quality']}mp, "
              f"Kovácsolási idő: {result['poc_time']}mp")

    # 4. Várakozás a következő blokkra
    time.sleep(10)  # Lekérdezési intervallum
```

---

### Pool Integrációs Minta

**Pool Szerver Munkafolyamat**:
1. Bányászok kovácsolási megbízásokat hoznak létre a pool címre
2. Pool tárcát futtat kovácsolási cím kulcsokkal
3. Pool hívja a `get_mining_info`-t és szétosztja a bányászoknak
4. Bányászok megoldásokat küldenek be a pool-on keresztül (nem közvetlenül a láncra)
5. Pool validálja és hívja a `submit_nonce`-t a pool kulcsaival
6. Pool elosztja a jutalmakat a pool szabályzat szerint

**Megbízás Kezelés**:
```bash
# Bányász létrehozza a megbízást (bányász tárcájából)
bitcoin-cli create_assignment "pocx1qbányász_plot..." "pocx1qpool..."

# Várakozás aktiválásra (30 blokk mainnet)

# Pool ellenőrzi a megbízás állapotot
bitcoin-cli get_assignment "pocx1qbányász_plot..."

# Pool most már küldhet be nonce-okat ehhez a plothoz
# (pool tárcának rendelkeznie kell pocx1qpool... privát kulccsal)
```

---

### Blokk Felfedező Lekérdezések

**PoCX Blokk Adatok Lekérdezése**:
```bash
# Legújabb blokk lekérése
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Blokk részletek lekérése PoCX bizonyítékkal
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX-specifikus mezők kinyerése
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Megbízás Tranzakciók Észlelése**:
```bash
# Tranzakció átnézése OP_RETURN-ra
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Megbízás jelölő ellenőrzése (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Hibakezelés

### Gyakori Hiba Minták

**Magasság Eltérés**:
```json
{
  "accepted": false,
  "error": "Magasság eltérés: beküldött 12345, aktuális 12346"
}
```
**Megoldás**: Kérje le újra a bányászati információkat, a lánc előrehaladt

**Generációs Aláírás Eltérés**:
```json
{
  "accepted": false,
  "error": "Generációs aláírás eltérés"
}
```
**Megoldás**: Kérje le újra a bányászati információkat, új blokk érkezett

**Nincs Privát Kulcs**:
```json
{
  "code": -5,
  "message": "Nincs elérhető privát kulcs az effektív aláíróhoz"
}
```
**Megoldás**: Importálja a kulcsot a plot vagy kovácsolási címhez

**Megbízás Aktiválás Folyamatban**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Megoldás**: Várjon az aktiválási késleltetés lejártáig

---

## Kód Hivatkozások

**Bányászati RPC-k**: `src/pocx/rpc/mining.cpp`
**Megbízás RPC-k**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blokklánc RPC-k**: `src/rpc/blockchain.cpp`
**Bizonyíték Validáció**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Megbízás Állapot**: `src/pocx/assignments/assignment_state.cpp`
**Tranzakció Létrehozás**: `src/pocx/assignments/transactions.cpp`

---

## Kereszthivatkozások

Kapcsolódó fejezetek:
- [3. Fejezet: Konszenzus és Bányászat](3-consensus-and-mining.md) - Bányászati folyamat részletei
- [4. Fejezet: Kovácsolási Megbízások](4-forging-assignments.md) - Megbízási rendszer architektúra
- [6. Fejezet: Hálózati Paraméterek](6-network-parameters.md) - Megbízás késleltetés értékek
- [8. Fejezet: Tárca Útmutató](8-wallet-guide.md) - GUI megbízás kezeléshez

---

[← Előző: Hálózati Paraméterek](6-network-parameters.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Tárca Útmutató →](8-wallet-guide.md)

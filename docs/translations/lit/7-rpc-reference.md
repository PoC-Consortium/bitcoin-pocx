[← Ankstesnis: Tinklo parametrai](6-network-parameters.md) | [📘 Turinys](index.md) | [Toliau: Piniginės vadovas →](8-wallet-guide.md)

---

# 7 skyrius: RPC sąsajos informacija

Išsami Bitcoin-PoCX RPC komandų informacija, įskaitant kasimo RPC, priskyrimo valdymą ir modifikuotas blockchain RPC.

---

## Turinys

1. [Konfigūracija](#konfigūracija)
2. [PoCX kasimo RPC](#pocx-kasimo-rpc)
3. [Priskyrimo RPC](#priskyrimo-rpc)
4. [Modifikuotos blockchain RPC](#modifikuotos-blockchain-rpc)
5. [Išjungtos RPC](#išjungtos-rpc)
6. [Integracijos pavyzdžiai](#integracijos-pavyzdžiai)

---

## Konfigūracija

### Kasimo serverio režimas

**Vėliavė**: ``

**Paskirtis**: Įjungia RPC prieigą išoriniams kasėjams iškviesti kasimui specifines RPC

**Reikalavimai**:
- Reikalingas `submit_nonce` funkcionalumui
- Reikalingas kalimo priskyrimo dialogo matomumui Qt piniginėje

**Naudojimas**:
```bash
# Komandų eilutė
./bitcoind

# bitcoin.conf
```

**Saugumo svarstybos**:
- Jokios papildomos autentifikacijos be standartinių RPC kredencialų
- Kasimo RPC ribojamos eilės talpa
- Standartinė RPC autentifikacija vis dar reikalinga

**Įgyvendinimas**: `src/pocx/rpc/mining.cpp`

---

## PoCX kasimo RPC

### get_mining_info

**Kategorija**: kasimas
**Reikalauja piniginės**: Ne

**Paskirtis**: Grąžina dabartinius kasimo parametrus, reikalingus išoriniams kasėjams nuskaityti grafiko failus ir skaičiuoti terminus.

**Parametrai**: Nėra

**Grąžinamos reikšmės**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 simboliai
  "base_target": 36650387592,                // skaitinis
  "height": 12345,                           // skaitinis, kito bloko aukštis
  "block_hash": "def456...",                 // hex, ankstesnis blokas
  "target_quality": 18446744073709551615,    // uint64_max (visi sprendimai priimami)
  "minimum_compression_level": 1,            // skaitinis
  "target_compression_level": 2              // skaitinis
}
```

**Laukų aprašymai**:
- `generation_signature`: Deterministinė kasimo entropija šiam bloko aukščiui
- `base_target`: Dabartinis sudėtingumas (didesnis = lengviau)
- `height`: Bloko aukštis, kurį kasėjai turėtų taikyti
- `block_hash`: Ankstesnio bloko maiša (informacinis)
- `target_quality`: Kokybės riba (šiuo metu uint64_max, jokio filtravimo)
- `minimum_compression_level`: Minimalus suspaudimas reikalingas validacijai
- `target_compression_level`: Rekomenduojamas suspaudimas optimaliam kasimui

**Klaidų kodai**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Mazgas vis dar sinchronizuojasi

**Pavyzdys**:
```bash
bitcoin-cli get_mining_info
```

**Įgyvendinimas**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategorija**: kasimas
**Reikalauja piniginės**: Taip (privatiems raktams)

**Paskirtis**: Pateikti PoCX kasimo sprendimą. Validuoja įrodymą, įdeda į eilę laiko lenktam kalimui ir automatiškai sukuria bloką numatytu laiku.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (tiksliai 40 hex simbolių = 20 baitų; adresas nepriimamas)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Grąžinamos reikšmės** (sėkmė):
```json
{
  "raw_quality": 120,       // neapdorota kokybė iš įrodymo validacijos
  "poc_time": 45            // laiko lenktas kalimo laikas sekundėmis
}
```

Nėra `accepted` lauko. Atmetimo atveju RPC **negrąžina** JSON objekto — jis išmeta `JSONRPCError` (žr. Klaidų kodus žemiau).

**Validacijos žingsniai**:
1. **Formato validacija** (greitas atmetimas):
   - Paskyros ID: tiksliai 40 hex simbolių
   - Sėkla: tiksliai 64 hex simboliai
2. **Konteksto validacija**:
   - Block hash must match current tip
   - Aukštis turi atitikti dabartinę viršūnę + 1
   - Generavimo parašas turi atitikti dabartinį
   - Base target must match current
3. **Piniginės verifikacija**:
   - Nustatyti efektyvųjį pasirašytoją (patikrinti aktyvius priskyrimus)
   - Patikrinti, kad piniginė turi privatų raktą efektyviajam pasirašytojui
4. **Įrodymo validacija** (brangi):
   - Validuoti PoCX įrodymą su suspaudimo ribomis
   - Apskaičiuoti neapdorotą kokybę
5. **Planavimo pateikimas**:
   - Įdėti nonce į eilę laiko lenktam kalimui
   - Blokas bus sukurtas automatiškai forge_time metu

**Klaidų kodai** (išmetami kaip `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Neteisingas formatas (account_id, seed) arba aukščio neatitikimas (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Generavimo parašo neatitikimas arba įrodymo validacija nepavyko
- `RPC_INVALID_ADDRESS_OR_KEY`: Nėra privataus rakto efektyviajam pasirašytojui
- `RPC_WALLET_UNLOCK_NEEDED`: Piniginė, turinti efektyviojo pasirašytojo raktą, yra užrakinta (atrakinkite su `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Pateikimo eilė pilna
- `RPC_INTERNAL_ERROR`: Nepavyko inicializuoti PoCX planuotojo

**Įrodymo validacijos klaidų kodai**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Pavyzdys**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Pastabos**:
- Pateikimas yra asinchroninis - RPC grąžina iš karto, blokas kalamas vėliau
- Laiko lenkimas atideda gerus sprendimus, kad tinklas spėtų nuskaityti grafikus
- Priskyrimo sistema: jei grafikas priskirtas, piniginė turi turėti kalimo adreso raktą
- Suspaudimo ribos dinamiškai koreguojamos pagal bloko aukštį

**Įgyvendinimas**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Priskyrimo RPC

### get_assignment

**Kategorija**: kasimas
**Reikalauja piniginės**: Ne

**Paskirtis**: Užklausti kalimo priskyrimo būseną grafiko adresui. Tik skaitymas, piniginė nereikalinga.

**Parametrai**:
1. `plot_address` (eilutė, privalomas) - Grafiko adresas (bech32 P2WPKH formatas)
2. `height` (skaitinis, neprivalomas) - Bloko aukštis užklausai (numatytas: dabartinė viršūnė)

**Grąžinamos reikšmės** (nėra priskyrimo):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Grąžinamos reikšmės** (aktyvus priskyrimas):
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

**Grąžinamos reikšmės** (atšaukiamas):
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

**Priskyrimo būsenos**:
- `UNASSIGNED`: Nėra priskyrimo
- `ASSIGNING`: Priskyrimo tx patvirtinta, aktyvacijos atidėjimas vyksta
- `ASSIGNED`: Priskyrimas aktyvus, kalimo teisės deleguotos
- `REVOKING`: Atšaukimo tx patvirtinta, vis dar aktyvi kol praeina atidėjimas
- `REVOKED`: Atšaukimas užbaigtas, kalimo teisės grąžintos grafiko savininkui

**Klaidų kodai**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Neteisingas adresas arba ne P2WPKH (bech32)

**Pavyzdys**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Įgyvendinimas**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategorija**: piniginė
**Reikalauja piniginės**: Taip (turi būti įkelta ir atrakinta)

**Paskirtis**: Sukurti kalimo priskyrimo transakciją deleguoti kalimo teises kitam adresui (pvz., kasimo baseinui).

**Parametrai**:
1. `plot_address` (eilutė, privalomas) - Grafiko savininko adresas (turi turėti privatų raktą, P2WPKH bech32)
2. `forging_address` (eilutė, privalomas) - Adresas, kuriam priskirti kalimo teises (P2WPKH bech32)
3. `fee_rate` (skaitinis, neprivalomas) - Mokesčio dažnis BTCX/kvB (numatytas: `0` → piniginės standartinis minimalaus mokesčio įvertis; 10× minRelayFee numatytoji reikšmė taikoma tik Qt GUI dialogui, ne šiam RPC)

**Grąžinamos reikšmės**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Reikalavimai**:
- Piniginė įkelta ir atrakinta
- Privatus raktas plot_address piniginėje
- Abu adresai turi būti P2WPKH (bech32 formatas: pocx1q... pagrindinis tinklas, tpocx1q... testinis tinklas)
- Grafiko adresas turi turėti patvirtintų UTXO (įrodo nuosavybę)
- Grafikas neturi turėti aktyvaus priskyrimo (pirmiausia naudokite atšaukimą)

**Transakcijos struktūra**:
- Įvestis: UTXO iš grafiko adreso (įrodo nuosavybę)
- Išvestis: OP_RETURN scenarijus (46 baitai) = `OP_RETURN` opkodas + 1 baito stūmimo ilgis + 44 baitų duomenų naudingoji apkrova (`POCX` žymeklis 4 + plot_address 20 + forging_address 20)
- Išvestis: Grąža grąžinama į piniginę

**Aktyvacija**:
- Priskyrimas tampa ASSIGNING patvirtinimo metu
- Becomes ASSIGNED after `nForgingAssignmentDelay` blocks
- Atidėjimas apsaugo nuo greito perpriskyrimo grandinės šakų metu

**Klaidų kodai**:
- `RPC_WALLET_NOT_FOUND`: Nėra prieinamos piniginės
- `RPC_WALLET_UNLOCK_NEEDED`: Piniginė užšifruota ir užrakinta
- `RPC_WALLET_ERROR`: Transakcijos kūrimas nepavyko
- `RPC_INVALID_ADDRESS_OR_KEY`: Neteisingas adreso formatas

**Pavyzdys**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Įgyvendinimas**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategorija**: piniginė
**Reikalauja piniginės**: Taip (turi būti įkelta ir atrakinta)

**Paskirtis**: Atšaukti esamą kalimo priskyrimą, grąžinant kalimo teises grafiko savininkui.

**Parametrai**:
1. `plot_address` (eilutė, privalomas) - Grafiko adresas (turi turėti privatų raktą, P2WPKH bech32)
2. `fee_rate` (skaitinis, neprivalomas) - Mokesčio dažnis BTCX/kvB (numatytas: `0` → piniginės standartinis minimalaus mokesčio įvertis; 10× minRelayFee numatytoji reikšmė taikoma tik Qt GUI dialogui, ne šiam RPC)

**Grąžinamos reikšmės**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Reikalavimai**:
- Piniginė įkelta ir atrakinta
- Privatus raktas plot_address piniginėje
- Grafiko adresas turi būti P2WPKH (bech32 formatas)
- Grafiko adresas turi turėti patvirtintų UTXO

**Transakcijos struktūra**:
- Įvestis: UTXO iš grafiko adreso (įrodo nuosavybę)
- Išvestis: OP_RETURN scenarijus (26 baitai) = `OP_RETURN` opkodas + 1 baito stūmimo ilgis + 24 baitų duomenų naudingoji apkrova (`XCOP` žymeklis 4 + plot_address 20)
- Išvestis: Grąža grąžinama į piniginę

**Poveikis**:
- Būsena iš karto pereina į REVOKING
- Kalimo adresas vis dar gali kalti atidėjimo periodo metu
- Tampa REVOKED po `nForgingRevocationDelay` blokų
- Grafiko savininkas gali kalti po atšaukimo įsigaliojimo
- Gali sukurti naują priskyrimą po atšaukimo užbaigimo

**Klaidų kodai**:
- `RPC_WALLET_NOT_FOUND`: Nėra prieinamos piniginės
- `RPC_WALLET_UNLOCK_NEEDED`: Piniginė užšifruota ir užrakinta
- `RPC_WALLET_ERROR`: Transakcijos kūrimas nepavyko

**Pavyzdys**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Pastabos**:
- Idempotentus: galima atšaukti net jei nėra aktyvaus priskyrimo
- Negalima atšaukti atšaukimo po pateikimo

**Įgyvendinimas**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modifikuotos blockchain RPC

### getdifficulty

**PoCX modifikacijos**:
- **Skaičiavimas**: `referencinis_bazinis_tikslas / dabartinis_bazinis_tikslas`
- **Referencija**: 1 TiB tinklo talpa (base_target = 36650387592)
- **Interpretacija**: Įvertinta tinklo saugyklos talpa TiB
  - Pavyzdys: `1.0` = ~1 TiB
  - Pavyzdys: `1024.0` = ~1 PiB
- **Skirtumas nuo PoW**: Reprezentuoja talpą, ne maišos galią

**Pavyzdys**:
```bash
bitcoin-cli getdifficulty
# Grąžina: 2048.5 (tinklas ~2 PiB)
```

**Įgyvendinimas**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX pridėti laukai**:
- `time_since_last_block` (skaitinis) - Sekundės nuo ankstesnio bloko (pakeičia mediantime)
- `poc_time` (skaitinis) - Laiko lenktas kalimo laikas sekundėmis
- `base_target` (skaitinis) - PoCX sudėtingumo bazinis tikslas
- `generation_signature` (eilutė hex) - Generavimo parašas
- `pocx_proof` (objektas):
  - `account_id` (eilutė hex) - Grafiko paskyros ID (20 baitų)
  - `seed` (eilutė hex) - Grafiko sėkla (32 baitai)
  - `nonce` (skaitinis) - Kasimo nonce
  - `compression` (skaitinis) - Naudojamas mastelio lygis
  - `quality` (skaitinis) - Deklaruota kokybės reikšmė
- `pubkey` (eilutė hex) - Bloko pasirašytojo viešasis raktas (33 baitai)
- `signer_address` (eilutė) - Bloko pasirašytojo adresas
- `signature` (eilutė hex) - Bloko parašas (65 baitai)

**PoCX pašalinti laukai**:
- `mediantime` - Pašalinta (pakeista time_since_last_block)

**Pavyzdys**:
```bash
bitcoin-cli getblockheader <blokomaiša>
```

**Įgyvendinimas**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX modifikacijos**: Tos pačios kaip getblockheader, plius pilni transakcijos duomenys

**Pavyzdys**:
```bash
bitcoin-cli getblock <blokomaiša>
bitcoin-cli getblock <blokomaiša> 2  # išsamus su tx detalėmis
```

**Įgyvendinimas**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX pridėti laukai**:
- `base_target` (skaitinis) - Dabartinis bazinis tikslas
- `generation_signature` (eilutė hex) - Dabartinis generavimo parašas

**PoCX modifikuoti laukai**:
- `difficulty` - Naudoja PoCX skaičiavimą (talpos pagrįstas)

**PoCX pašalinti laukai**:
- `mediantime` - Pašalinta

**Pavyzdys**:
```bash
bitcoin-cli getblockchaininfo
```

**Įgyvendinimas**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX pridėti laukai**:
- `generation_signature` (eilutė hex) - Baseino kasimui
- `base_target` (skaitinis) - Baseino kasimui

**PoCX pašalinti laukai**:
- `target` - Removed (replaced by `base_target`)
- `noncerange` - Pašalinta (PoW specifinis)
- `bits` - Pašalinta (PoW specifinis)

**Pastabos**:
- Vis dar apima pilnus transakcijos duomenis bloko konstrukcijai
- Naudojamas baseino serverių koordinuotam kasimui

**Pavyzdys**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Įgyvendinimas**: `src/rpc/mining.cpp`

---

## Išjungtos RPC

Šios PoW specifinės RPC yra **išjungtos** PoCX režime:

### getnetworkhashps
- **Priežastis**: Maišos greitis netaikomas Proof of Capacity
- **Alternatyva**: Naudokite `getdifficulty` tinklo talpos įvertinimui

### getmininginfo
- **Priežastis**: Grąžina PoW specifinę informaciją
- **Alternatyva**: Naudokite `get_mining_info` (PoCX specifinis)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Integracijos pavyzdžiai

### Išorinio kasėjo integracija

**Bazinis kasimo ciklas**:
```python
import requests
import time

RPC_URL = "http://vartotojas:slaptažodis@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Kasimo ciklas
while True:
    # 1. Gauti kasimo parametrus
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Nuskaityti grafiko failus (išorinis įgyvendinimas)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Pateikti geriausią sprendimą (atmetus išmetamas JSONRPCError)
    try:
        result = rpc_call("submit_nonce", [
            info["block_hash"],
            height,
            gen_sig,
            base_target,
            best_nonce["account_id"],
            best_nonce["seed"],
            best_nonce["nonce"],
            best_nonce["compression"],
            best_nonce["raw_quality"]
        ])
        print(f"Sprendimas priimtas! Kokybė: {result['raw_quality']}, "
              f"Kalimo laikas: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Atmesta: {e}")

    # 4. Laukti kito bloko
    time.sleep(10)  # Apklausos intervalas
```

---

### Baseino integracijos šablonas

**Baseino serverio darbo eiga**:
1. Kasėjai sukuria kalimo priskyrimus baseino adresui
2. Baseinas valdo piniginę su kalimo adreso raktais
3. Baseinas iškviečia `get_mining_info` ir platina kasėjams
4. Kasėjai pateikia sprendimus per baseiną (ne tiesiogiai į grandinę)
5. Baseinas validuoja ir iškviečia `submit_nonce` su baseino raktais
6. Baseinas paskirsto atlygius pagal baseino politiką

**Priskyrimo valdymas**:
```bash
# Kasėjas sukuria priskyrimą (iš kasėjo piniginės)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Laukti aktyvacijos (30 blokų pagrindiniame tinkle)

# Baseinas tikrina priskyrimo būseną
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Baseinas dabar gali pateikti nonces šiam grafikui
# (baseino piniginė turi turėti pocx1qpool... privatų raktą)
```

---

### Blokų naršyklės užklausos

**PoCX bloko duomenų užklausa**:
```bash
# Gauti naujausią bloką
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Gauti bloko detales su PoCX įrodymu
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Išgauti PoCX specifinius laukus
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

**Priskyrimo transakcijų aptikimas**:
```bash
# Nuskaityti transakciją dėl OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Tikrinti priskyrimo žymeklį (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Klaidų tvarkymas

### Dažni klaidų šablonai

**Aukščio neatitikimas** (išmetamas `RPC_INVALID_PARAMETER`, kodas -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Sprendimas**: Pakartotinai gauti kasimo informaciją, grandinė pažengė

**Generavimo parašo neatitikimas** (išmetamas `RPC_VERIFY_REJECTED`, kodas -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Sprendimas**: Pakartotinai gauti kasimo informaciją, naujas blokas atėjo

**Nėra privataus rakto**:
```json
{
  "code": -5,
  "message": "Nėra privataus rakto efektyviajam pasirašytojui"
}
```
**Sprendimas**: Importuoti raktą grafikui arba kalimo adresui

**Priskyrimo aktyvacija laukia**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Sprendimas**: Laukti kol praeis aktyvacijos atidėjimas

---

## Kodo nuorodos

**Kasimo RPC**: `src/pocx/rpc/mining.cpp`
**Priskyrimo RPC**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain RPC**: `src/rpc/blockchain.cpp`
**Įrodymo validacija**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Priskyrimo būsena**: `src/pocx/assignments/assignment_state.cpp`
**Transakcijos kūrimas**: `src/pocx/assignments/transactions.cpp`

---

## Kryžminės nuorodos

Susiję skyriai:
- [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md) - Kasimo proceso detalės
- [4 skyrius: Kalimo priskyrimai](4-forging-assignments.md) - Priskyrimo sistemos architektūra
- [6 skyrius: Tinklo parametrai](6-network-parameters.md) - Priskyrimo atidėjimo reikšmės
- [8 skyrius: Piniginės vadovas](8-wallet-guide.md) - GUI priskyrimo valdymui

---

[← Ankstesnis: Tinklo parametrai](6-network-parameters.md) | [📘 Turinys](index.md) | [Toliau: Piniginės vadovas →](8-wallet-guide.md)

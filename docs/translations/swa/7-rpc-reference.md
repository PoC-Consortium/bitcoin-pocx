[← Iliyotangulia: Vigezo vya Mtandao](6-network-parameters.md) | [Yaliyomo](index.md) | [Inayofuata: Mwongozo wa Pochi →](8-wallet-guide.md)

---

# Sura ya 7: Marejeleo ya Kiolesura cha RPC

Marejeleo kamili ya amri za RPC za Bitcoin-PoCX, ikiwa ni pamoja na RPC za uchimbaji, usimamizi wa ugawaji, na RPC zilizobadilishwa za blockchain.

---

## Yaliyomo

1. [Usanidi](#usanidi)
2. [RPC za Uchimbaji za PoCX](#rpc-za-uchimbaji-za-pocx)
3. [RPC za Ugawaji](#rpc-za-ugawaji)
4. [RPC Zilizobadilishwa za Blockchain](#rpc-zilizobadilishwa-za-blockchain)
5. [RPC Zilizozimwa](#rpc-zilizozimwa)
6. [Mifano ya Muungano](#mifano-ya-muungano)

---

## Usanidi

### Hali ya Seva ya Uchimbaji

**Bendera**: `-miningserver`

**Madhumuni**: Inawezesha ufikiaji wa RPC kwa wachimbaji wa nje kuita RPC mahususi za uchimbaji

**Mahitaji**:
- Inahitajika kwa `submit_nonce` kufanya kazi
- Inahitajika kwa uonekano wa kisanduku cha mazungumzo cha ugawaji wa kuunda katika pochi ya Qt

**Matumizi**:
```bash
# Mstari wa amri
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Mazingatio ya Usalama**:
- Hakuna uthibitisho wa ziada zaidi ya vitambulisho vya kawaida vya RPC
- RPC za uchimbaji zimezuiwa kiwango na uwezo wa foleni
- Uthibitisho wa kawaida wa RPC bado unahitajika

**Utekelezaji**: `src/pocx/rpc/mining.cpp`

---

## RPC za Uchimbaji za PoCX

### get_mining_info

**Kategoria**: uchimbaji
**Inahitaji Seva ya Uchimbaji**: Hapana
**Inahitaji Pochi**: Hapana

**Madhumuni**: Inarudisha vigezo vya sasa vya uchimbaji vinavyohitajika na wachimbaji wa nje kuchanganua faili za plot na kuhesabu tarehe za mwisho.

**Vigezo**: Hakuna

**Thamani za Kurudishwa**:
```json
{
  "generation_signature": "abc123...",       // hex, herufi 64
  "base_target": 36650387593,                // nambari
  "height": 12345,                           // nambari, urefu wa bloku inayofuata
  "block_hash": "def456...",                 // hex, bloku iliyotangulia
  "target_quality": 18446744073709551615,    // uint64_max (suluhisho zote zinakubaliwa)
  "minimum_compression_level": 1,            // nambari
  "target_compression_level": 2              // nambari
}
```

**Maelezo ya Sehemu**:
- `generation_signature`: Entropi ya uamuzi wa uchimbaji kwa urefu huu wa bloku
- `base_target`: Ugumu wa sasa (juu zaidi = rahisi zaidi)
- `height`: Urefu wa bloku wachimbaji wanapaswa kulenga
- `block_hash`: Hash ya bloku iliyotangulia (habari)
- `target_quality`: Kizingiti cha ubora (kwa sasa uint64_max, hakuna uchujaji)
- `minimum_compression_level`: Ukandamizaji wa chini unaohitajika kwa uthibitishaji
- `target_compression_level`: Ukandamizaji unaopendekezwa kwa uchimbaji bora

**Nambari za Kosa**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nodi bado inasawazisha

**Mfano**:
```bash
bitcoin-cli get_mining_info
```

**Utekelezaji**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategoria**: uchimbaji
**Inahitaji Seva ya Uchimbaji**: Ndiyo
**Inahitaji Pochi**: Ndiyo (kwa funguo za kibinafsi)

**Madhumuni**: Wasilisha suluhisho la uchimbaji la PoCX. Inathiditisha uthibitisho, inaweka foleni kwa kuunda iliyopindwa muda, na inaunda moja kwa moja bloku wakati uliopangwa.

**Vigezo**:
1. `height` (nambari, inahitajika) - Urefu wa bloku
2. `generation_signature` (string hex, inahitajika) - Sahihi ya uzalishaji (herufi 64)
3. `account_id` (string, inahitajika) - Kitambulisho cha akaunti ya plot (herufi 40 za hex = byte 20)
4. `seed` (string, inahitajika) - Mbegu ya plot (herufi 64 za hex = byte 32)
5. `nonce` (nambari, inahitajika) - Nonce ya uchimbaji
6. `compression` (nambari, inahitajika) - Kiwango cha upanuzi/ukandamizaji kilichotumika (1-255)
7. `quality` (nambari, hiari) - Thamani ya ubora (inahesabiwa tena ikiwa imeachwa)

**Thamani za Kurudishwa** (mafanikio):
```json
{
  "accepted": true,
  "quality": 120,           // tarehe ya mwisho iliyorekebishwa na ugumu katika sekunde
  "poc_time": 45            // muda wa kuunda uliopindwa katika sekunde
}
```

**Thamani za Kurudishwa** (kukataliwa):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Hatua za Uthibitishaji**:
1. **Uthibitishaji wa Muundo** (kushindwa haraka):
   - Kitambulisho cha akaunti: haswa herufi 40 za hex
   - Mbegu: haswa herufi 64 za hex
2. **Uthibitishaji wa Muktadha**:
   - Urefu lazima ulingane na ncha ya sasa + 1
   - Sahihi ya uzalishaji lazima ilingane na ya sasa
3. **Uthibitishaji wa Pochi**:
   - Tambua msaini anayefanya kazi (angalia ugawaji unaofanya kazi)
   - Thibitisha pochi ina ufunguo wa kibinafsi wa msaini anayefanya kazi
4. **Uthibitishaji wa Uthibitisho** (ghali):
   - Thibitisha uthibitisho wa PoCX na mipaka ya ukandamizaji
   - Hesabu ubora usiobadilika
5. **Uwasilishaji kwa Kipangaji**:
   - Weka nonce foleni kwa kuunda iliyopindwa muda
   - Bloku itaundwa moja kwa moja wakati wa forge_time

**Nambari za Kosa**:
- `RPC_INVALID_PARAMETER`: Muundo batili (account_id, seed) au kutofautiana kwa urefu
- `RPC_VERIFY_REJECTED`: Kutofautiana kwa sahihi ya uzalishaji au uthibitishaji wa uthibitisho umeshindwa
- `RPC_INVALID_ADDRESS_OR_KEY`: Hakuna ufunguo wa kibinafsi kwa msaini anayefanya kazi
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Foleni ya uwasilishaji imejaa
- `RPC_INTERNAL_ERROR`: Imeshindwa kuanzisha kipangaji cha PoCX

**Nambari za Kosa za Uthibitishaji wa Uthibitisho**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Mfano**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Madokezo**:
- Uwasilishaji ni wa asynchronous - RPC inarudi mara moja, bloku inaundwa baadaye
- Kupinda Muda kunachelewesha suluhisho nzuri kuruhusu kuchanganua plot kote kwenye mtandao
- Mfumo wa ugawaji: ikiwa plot imekabidhiwa, pochi lazima iwe na ufunguo wa anwani ya kuunda
- Mipaka ya ukandamizaji inarekebishwa kwa nguvu kulingana na urefu wa bloku

**Utekelezaji**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC za Ugawaji

### get_assignment

**Kategoria**: uchimbaji
**Inahitaji Seva ya Uchimbaji**: Hapana
**Inahitaji Pochi**: Hapana

**Madhumuni**: Hoja hali ya ugawaji wa kuunda kwa anwani ya plot. Kusoma pekee, hakuna pochi inayohitajika.

**Vigezo**:
1. `plot_address` (string, inahitajika) - Anwani ya plot (muundo wa P2WPKH bech32)
2. `height` (nambari, hiari) - Urefu wa bloku wa kuhoji (default: ncha ya sasa)

**Thamani za Kurudishwa** (hakuna ugawaji):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Thamani za Kurudishwa** (ugawaji unaofanya kazi):
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

**Thamani za Kurudishwa** (inabatilisha):
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

**Hali za Ugawaji**:
- `UNASSIGNED`: Hakuna ugawaji uliopo
- `ASSIGNING`: Muamala wa ugawaji umethibitishwa, ucheleweshaji wa uanzishaji unaendelea
- `ASSIGNED`: Ugawaji unafanya kazi, haki za kuunda zimekabidhiwa
- `REVOKING`: Muamala wa kubatilisha umethibitishwa, bado unafanya kazi hadi ucheleweshaji upite
- `REVOKED`: Kubatilisha kumekamilika, haki za kuunda zimerudi kwa mmiliki wa plot

**Nambari za Kosa**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Anwani batili au si P2WPKH (bech32)

**Mfano**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Utekelezaji**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategoria**: pochi
**Inahitaji Seva ya Uchimbaji**: Hapana
**Inahitaji Pochi**: Ndiyo (lazima iwe imepakiwa na kufunguliwa)

**Madhumuni**: Unda muamala wa ugawaji wa kuunda kukabidhi haki za kuunda kwa anwani nyingine (k.m., dimbwi la uchimbaji).

**Vigezo**:
1. `plot_address` (string, inahitajika) - Anwani ya mmiliki wa plot (lazima umiliki ufunguo wa kibinafsi, P2WPKH bech32)
2. `forging_address` (string, inahitajika) - Anwani ya kukabidhi haki za kuunda (P2WPKH bech32)
3. `fee_rate` (nambari, hiari) - Kiwango cha ada katika BTC/kvB (default: 10× minRelayFee)

**Thamani za Kurudishwa**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Mahitaji**:
- Pochi imepakiwa na kufunguliwa
- Ufunguo wa kibinafsi wa plot_address katika pochi
- Anwani zote mbili lazima ziwe P2WPKH (muundo wa bech32: pocx1q... mainnet, tpocx1q... testnet)
- Anwani ya plot lazima iwe na UTXO zilizothibitishwa (zinathibitisha umiliki)
- Plot lazima isiwe na ugawaji unaofanya kazi (tumia revoke kwanza)

**Muundo wa Muamala**:
- Ingizo: UTXO kutoka anwani ya plot (inathibitisha umiliki)
- Tokeo: OP_RETURN (byte 46): alama ya `POCX` + plot_address (byte 20) + forging_address (byte 20)
- Tokeo: Chenji inarudi kwa pochi

**Uanzishaji**:
- Ugawaji unakuwa ASSIGNING wakati wa uthibitisho
- Unakuwa ACTIVE baada ya bloku `nForgingAssignmentDelay`
- Ucheleweshaji unazuia ugawaji upya wa haraka wakati wa fork za mtandao

**Nambari za Kosa**:
- `RPC_WALLET_NOT_FOUND`: Hakuna pochi inayopatikana
- `RPC_WALLET_UNLOCK_NEEDED`: Pochi imesimbwa na imefungwa
- `RPC_WALLET_ERROR`: Uundaji wa muamala umeshindwa
- `RPC_INVALID_ADDRESS_OR_KEY`: Muundo wa anwani batili

**Mfano**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Utekelezaji**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategoria**: pochi
**Inahitaji Seva ya Uchimbaji**: Hapana
**Inahitaji Pochi**: Ndiyo (lazima iwe imepakiwa na kufunguliwa)

**Madhumuni**: Batilisha ugawaji uliopo wa kuunda, kurudisha haki za kuunda kwa mmiliki wa plot.

**Vigezo**:
1. `plot_address` (string, inahitajika) - Anwani ya plot (lazima umiliki ufunguo wa kibinafsi, P2WPKH bech32)
2. `fee_rate` (nambari, hiari) - Kiwango cha ada katika BTC/kvB (default: 10× minRelayFee)

**Thamani za Kurudishwa**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Mahitaji**:
- Pochi imepakiwa na kufunguliwa
- Ufunguo wa kibinafsi wa plot_address katika pochi
- Anwani ya plot lazima iwe P2WPKH (muundo wa bech32)
- Anwani ya plot lazima iwe na UTXO zilizothibitishwa

**Muundo wa Muamala**:
- Ingizo: UTXO kutoka anwani ya plot (inathibitisha umiliki)
- Tokeo: OP_RETURN (byte 26): alama ya `XCOP` + plot_address (byte 20)
- Tokeo: Chenji inarudi kwa pochi

**Athari**:
- Hali inabadilika kuwa REVOKING mara moja
- Anwani ya kuunda bado inaweza kuunda wakati wa kipindi cha ucheleweshaji
- Inakuwa REVOKED baada ya bloku `nForgingRevocationDelay`
- Mmiliki wa plot anaweza kuunda baada ya kubatilisha kukuwa hai
- Anaweza kuunda ugawaji mpya baada ya kubatilisha kukamilika

**Nambari za Kosa**:
- `RPC_WALLET_NOT_FOUND`: Hakuna pochi inayopatikana
- `RPC_WALLET_UNLOCK_NEEDED`: Pochi imesimbwa na imefungwa
- `RPC_WALLET_ERROR`: Uundaji wa muamala umeshindwa

**Mfano**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Madokezo**:
- Idempotent: inaweza kubatilisha hata ikiwa hakuna ugawaji unaofanya kazi
- Haiwezi kughairi kubatilisha ikishawasilishwa

**Utekelezaji**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPC Zilizobadilishwa za Blockchain

### getdifficulty

**Marekebisho ya PoCX**:
- **Hesabu**: `reference_base_target / current_base_target`
- **Marejeleo**: Uwezo wa mtandao wa 1 TiB (base_target = 36650387593)
- **Tafsiri**: Uwezo wa hifadhi wa mtandao uliokadiriwa katika TiB
  - Mfano: `1.0` = ~1 TiB
  - Mfano: `1024.0` = ~1 PiB
- **Tofauti na PoW**: Inawakilisha uwezo, si nguvu ya hash

**Mfano**:
```bash
bitcoin-cli getdifficulty
# Inarudisha: 2048.5 (mtandao ~2 PiB)
```

**Utekelezaji**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Sehemu Zilizoongezwa za PoCX**:
- `time_since_last_block` (nambari) - Sekunde tangu bloku iliyotangulia (inabadilisha mediantime)
- `poc_time` (nambari) - Muda wa kuunda uliopindwa katika sekunde
- `base_target` (nambari) - Lengo la msingi la ugumu wa PoCX
- `generation_signature` (string hex) - Sahihi ya uzalishaji
- `pocx_proof` (kitu):
  - `account_id` (string hex) - Kitambulisho cha akaunti ya plot (byte 20)
  - `seed` (string hex) - Mbegu ya plot (byte 32)
  - `nonce` (nambari) - Nonce ya uchimbaji
  - `compression` (nambari) - Kiwango cha upanuzi kilichotumika
  - `quality` (nambari) - Thamani ya ubora iliyodaiwa
- `pubkey` (string hex) - Ufunguo wa umma wa msaini wa bloku (byte 33)
- `signer_address` (string) - Anwani ya msaini wa bloku
- `signature` (string hex) - Sahihi ya bloku (byte 65)

**Sehemu Zilizoondolewa za PoCX**:
- `mediantime` - Imeondolewa (imebadilishwa na time_since_last_block)

**Mfano**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Utekelezaji**: `src/rpc/blockchain.cpp`

---

### getblock

**Marekebisho ya PoCX**: Sawa na getblockheader, pamoja na data kamili ya miamala

**Mfano**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # kwa undani na maelezo ya tx
```

**Utekelezaji**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Sehemu Zilizoongezwa za PoCX**:
- `base_target` (nambari) - Lengo la msingi la sasa
- `generation_signature` (string hex) - Sahihi ya uzalishaji ya sasa

**Sehemu Zilizobadilishwa za PoCX**:
- `difficulty` - Inatumia hesabu ya PoCX (msingi wa uwezo)

**Sehemu Zilizoondolewa za PoCX**:
- `mediantime` - Imeondolewa

**Mfano**:
```bash
bitcoin-cli getblockchaininfo
```

**Utekelezaji**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Sehemu Zilizoongezwa za PoCX**:
- `generation_signature` (string hex) - Kwa uchimbaji wa dimbwi
- `base_target` (nambari) - Kwa uchimbaji wa dimbwi

**Sehemu Zilizoondolewa za PoCX**:
- `target` - Imeondolewa (mahususi kwa PoW)
- `noncerange` - Imeondolewa (mahususi kwa PoW)
- `bits` - Imeondolewa (mahususi kwa PoW)

**Madokezo**:
- Bado inajumuisha data kamili ya miamala kwa ujenzi wa bloku
- Inatumika na seva za dimbwi kwa uchimbaji ulioratibiwa

**Mfano**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Utekelezaji**: `src/rpc/mining.cpp`

---

## RPC Zilizozimwa

RPC zifuatazo mahususi za PoW **zimezimwa** katika hali ya PoCX:

### getnetworkhashps
- **Sababu**: Kiwango cha hash hakihusu Proof of Capacity
- **Mbadala**: Tumia `getdifficulty` kwa makadirio ya uwezo wa mtandao

### getmininginfo
- **Sababu**: Inarudisha habari mahususi za PoW
- **Mbadala**: Tumia `get_mining_info` (mahususi kwa PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Sababu**: Uchimbaji wa CPU hauhusu PoCX (unahitaji plot zilizozalishwa mapema)
- **Mbadala**: Tumia plotter wa nje + miner + `submit_nonce`

**Utekelezaji**: `src/rpc/mining.cpp` (RPC zinarudisha kosa wakati ENABLE_POCX imefafanuliwa)

---

## Mifano ya Muungano

### Muungano wa Mchimbaji wa Nje

**Mzunguko wa Msingi wa Uchimbaji**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Mzunguko wa uchimbaji
while True:
    # 1. Pata vigezo vya uchimbaji
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Changanua faili za plot (utekelezaji wa nje)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Wasilisha suluhisho bora zaidi
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Suluhisho limekubaliwa! Ubora: {result['quality']}s, "
              f"Muda wa kuunda: {result['poc_time']}s")

    # 4. Subiri bloku inayofuata
    time.sleep(10)  # Muda wa kuhoji
```

---

### Muundo wa Muungano wa Dimbwi

**Mtiririko wa Seva ya Dimbwi**:
1. Wachimbaji wanaunda ugawaji wa kuunda kwa anwani ya dimbwi
2. Dimbwi linaendesha pochi na funguo za anwani ya kuunda
3. Dimbwi linaita `get_mining_info` na kusambaza kwa wachimbaji
4. Wachimbaji wanawasilisha suluhisho kupitia dimbwi (sio moja kwa moja kwa mtandao)
5. Dimbwi linathiditisha na kuita `submit_nonce` na funguo za dimbwi
6. Dimbwi linasambaza zawadi kulingana na sera ya dimbwi

**Usimamizi wa Ugawaji**:
```bash
# Mchimbaji anaunda ugawaji (kutoka pochi ya mchimbaji)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Subiri uanzishaji (bloku 30 mainnet)

# Dimbwi linaangalia hali ya ugawaji
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Dimbwi sasa linaweza kuwasilisha nonce kwa plot hii
# (pochi ya dimbwi lazima iwe na ufunguo wa kibinafsi wa pocx1qpool...)
```

---

### Hoja za Block Explorer

**Kuhoji Data ya Bloku ya PoCX**:
```bash
# Pata bloku ya hivi karibuni
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Pata maelezo ya bloku na uthibitisho wa PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Toa sehemu mahususi za PoCX
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

**Kugundua Miamala ya Ugawaji**:
```bash
# Changanua muamala kwa OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Angalia alama ya ugawaji (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Kushughulikia Makosa

### Mifumo ya Kawaida ya Makosa

**Kutofautiana kwa Urefu**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Suluhisho**: Pata tena habari za uchimbaji, mtandao umesonga mbele

**Kutofautiana kwa Sahihi ya Uzalishaji**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Suluhisho**: Pata tena habari za uchimbaji, bloku mpya imefika

**Hakuna Ufunguo wa Kibinafsi**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Suluhisho**: Ingiza ufunguo kwa anwani ya plot au kuunda

**Uanzishaji wa Ugawaji Unasubiri**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Suluhisho**: Subiri ucheleweshaji wa uanzishaji upite

---

## Marejeleo ya Msimbo

**RPC za Uchimbaji**: `src/pocx/rpc/mining.cpp`
**RPC za Ugawaji**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC za Blockchain**: `src/rpc/blockchain.cpp`
**Uthibitishaji wa Uthibitisho**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Hali ya Ugawaji**: `src/pocx/assignments/assignment_state.cpp`
**Uundaji wa Muamala**: `src/pocx/assignments/transactions.cpp`

---

## Marejeleo ya Msalaba

Sura zinazohusiana:
- [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md) - Maelezo ya mchakato wa uchimbaji
- [Sura ya 4: Ugawaji wa Kuunda](4-forging-assignments.md) - Muundo wa mfumo wa ugawaji
- [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md) - Thamani za ucheleweshaji wa ugawaji
- [Sura ya 8: Mwongozo wa Pochi](8-wallet-guide.md) - GUI kwa usimamizi wa ugawaji

---

[← Iliyotangulia: Vigezo vya Mtandao](6-network-parameters.md) | [Yaliyomo](index.md) | [Inayofuata: Mwongozo wa Pochi →](8-wallet-guide.md)

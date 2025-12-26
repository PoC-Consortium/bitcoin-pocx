[← Nakaraan: Mga Parameter ng Network](6-network-parameters.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Gabay sa Wallet →](8-wallet-guide.md)

---

# Kabanata 7: Sanggunian ng RPC Interface

Kumpletong sanggunian para sa mga RPC command ng Bitcoin-PoCX, kabilang ang mga mining RPC, pamamahala ng assignment, at binagong mga blockchain RPC.

---

## Talaan ng mga Nilalaman

1. [Configuration](#configuration)
2. [Mga PoCX Mining RPC](#mga-pocx-mining-rpc)
3. [Mga Assignment RPC](#mga-assignment-rpc)
4. [Mga Binagong Blockchain RPC](#mga-binagong-blockchain-rpc)
5. [Mga Naka-disable na RPC](#mga-naka-disable-na-rpc)
6. [Mga Halimbawa ng Integrasyon](#mga-halimbawa-ng-integrasyon)

---

## Configuration

### Mining Server Mode

**Flag**: `-miningserver`

**Layunin**: Pinapagana ang RPC access para sa mga external miner na tawagan ang mga mining-specific RPC

**Mga Kinakailangan**:
- Kinakailangan para gumana ang `submit_nonce`
- Kinakailangan para makita ang forging assignment dialog sa Qt wallet

**Paggamit**:
```bash
# Command line
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Mga Konsiderasyon sa Seguridad**:
- Walang karagdagang authentication bukod sa standard RPC credential
- Ang mga mining RPC ay nililimitahan ng queue capacity
- Kinakailangan pa rin ang standard RPC authentication

**Implementasyon**: `src/pocx/rpc/mining.cpp`

---

## Mga PoCX Mining RPC

### get_mining_info

**Kategorya**: mining
**Kailangan ang Mining Server**: Hindi
**Kailangan ang Wallet**: Hindi

**Layunin**: Nagbabalik ng mga kasalukuyang mining parameter na kailangan ng mga external miner upang i-scan ang mga plot file at kalkulahin ang mga deadline.

**Mga Parameter**: Wala

**Mga Return Value**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 na karakter
  "base_target": 36650387593,                // numeric
  "height": 12345,                           // numeric, susunod na block height
  "block_hash": "def456...",                 // hex, nakaraang block
  "target_quality": 18446744073709551615,    // uint64_max (tinatanggap lahat ng solusyon)
  "minimum_compression_level": 1,            // numeric
  "target_compression_level": 2              // numeric
}
```

**Mga Paglalarawan ng Field**:
- `generation_signature`: Deterministic mining entropy para sa block height na ito
- `base_target`: Kasalukuyang difficulty (mas mataas = mas madali)
- `height`: Block height na dapat i-target ng mga miner
- `block_hash`: Hash ng nakaraang block (pang-impormasyon)
- `target_quality`: Quality threshold (kasalukuyang uint64_max, walang filtering)
- `minimum_compression_level`: Minimum compression na kinakailangan para sa validation
- `target_compression_level`: Inirerekomendang compression para sa optimal na mining

**Mga Error Code**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nagsi-sync pa ang node

**Halimbawa**:
```bash
bitcoin-cli get_mining_info
```

**Implementasyon**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategorya**: mining
**Kailangan ang Mining Server**: Oo
**Kailangan ang Wallet**: Oo (para sa mga private key)

**Layunin**: Magsumite ng solusyon sa PoCX mining. Vine-validate ang proof, kinuqueue para sa time-bended forging, at awtomatikong gumagawa ng block sa naka-iskedyul na oras.

**Mga Parameter**:
1. `height` (numeric, kinakailangan) - Block height
2. `generation_signature` (string hex, kinakailangan) - Generation signature (64 na karakter)
3. `account_id` (string, kinakailangan) - Plot account ID (40 hex na karakter = 20 byte)
4. `seed` (string, kinakailangan) - Plot seed (64 hex na karakter = 32 byte)
5. `nonce` (numeric, kinakailangan) - Mining nonce
6. `compression` (numeric, kinakailangan) - Scaling/compression level na ginamit (1-255)
7. `quality` (numeric, opsyonal) - Quality value (kinakalkula ulit kung wala)

**Mga Return Value** (tagumpay):
```json
{
  "accepted": true,
  "quality": 120,           // difficulty-adjusted deadline sa segundo
  "poc_time": 45            // time-bended forge time sa segundo
}
```

**Mga Return Value** (ni-reject):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Mga Hakbang ng Validation**:
1. **Format Validation** (fail-fast):
   - Account ID: eksaktong 40 hex na karakter
   - Seed: eksaktong 64 hex na karakter
2. **Context Validation**:
   - Ang height ay dapat tumugma sa kasalukuyang tip + 1
   - Ang generation signature ay dapat tumugma sa kasalukuyan
3. **Wallet Verification**:
   - Tukuyin ang effective signer (suriin kung may mga aktibong assignment)
   - I-verify na ang wallet ay may private key para sa effective signer
4. **Proof Validation** (mahal):
   - I-validate ang PoCX proof na may mga compression bound
   - Kalkulahin ang raw quality
5. **Scheduler Submission**:
   - I-queue ang nonce para sa time-bended forging
   - Awtomatikong gagawin ang block sa forge_time

**Mga Error Code**:
- `RPC_INVALID_PARAMETER`: Invalid na format (account_id, seed) o height mismatch
- `RPC_VERIFY_REJECTED`: Generation signature mismatch o nabigo ang proof validation
- `RPC_INVALID_ADDRESS_OR_KEY`: Walang private key para sa effective signer
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Puno ang submission queue
- `RPC_INTERNAL_ERROR`: Nabigong i-initialize ang PoCX scheduler

**Mga Proof Validation Error Code**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Halimbawa**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Mga Tala**:
- Ang pagsusumite ay asynchronous - agad na bumabalik ang RPC, nag-forge ng block sa ibang pagkakataon
- Ang Time Bending ay nagde-delay ng mga magagandang solusyon upang payagan ang network-wide plot scanning
- Sistema ng assignment: kung naka-assign ang plot, ang wallet ay dapat may key ng forging address
- Ang mga compression bound ay dynamic na inaayos batay sa block height

**Implementasyon**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Mga Assignment RPC

### get_assignment

**Kategorya**: mining
**Kailangan ang Mining Server**: Hindi
**Kailangan ang Wallet**: Hindi

**Layunin**: I-query ang forging assignment status para sa isang plot address. Read-only, hindi kailangan ang wallet.

**Mga Parameter**:
1. `plot_address` (string, kinakailangan) - Plot address (bech32 P2WPKH format)
2. `height` (numeric, opsyonal) - Block height na i-query (default: kasalukuyang tip)

**Mga Return Value** (walang assignment):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Mga Return Value** (aktibong assignment):
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

**Mga Return Value** (nagri-revoke):
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

**Mga Assignment State**:
- `UNASSIGNED`: Walang assignment
- `ASSIGNING`: Nakumpirma ang assignment tx, kasalukuyang nagaganap ang activation delay
- `ASSIGNED`: Aktibo ang assignment, naidelegado na ang mga karapatan sa forging
- `REVOKING`: Nakumpirma ang revocation tx, aktibo pa rin hanggang lumipas ang delay
- `REVOKED`: Kumpleto na ang revocation, ang mga karapatan sa forging ay bumalik sa may-ari ng plot

**Mga Error Code**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Invalid na address o hindi P2WPKH (bech32)

**Halimbawa**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementasyon**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategorya**: wallet
**Kailangan ang Mining Server**: Hindi
**Kailangan ang Wallet**: Oo (dapat na-load at naka-unlock)

**Layunin**: Gumawa ng forging assignment transaction upang magdelega ng mga karapatan sa forging sa ibang address (hal., mining pool).

**Mga Parameter**:
1. `plot_address` (string, kinakailangan) - Address ng may-ari ng plot (dapat nagmamay-ari ng private key, P2WPKH bech32)
2. `forging_address` (string, kinakailangan) - Address na ia-assign ng mga karapatan sa forging (P2WPKH bech32)
3. `fee_rate` (numeric, opsyonal) - Fee rate sa BTC/kvB (default: 10× minRelayFee)

**Mga Return Value**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Mga Kinakailangan**:
- Na-load at naka-unlock ang wallet
- Private key para sa plot_address na nasa wallet
- Ang parehong address ay dapat P2WPKH (bech32 format: pocx1q... mainnet, tpocx1q... testnet)
- Ang plot address ay dapat may mga nakumpirmang UTXO (nagpapatunay ng pagmamay-ari)
- Ang plot ay hindi dapat may aktibong assignment (i-revoke muna)

**Istruktura ng Transaksyon**:
- Input: UTXO mula sa plot address (nagpapatunay ng pagmamay-ari)
- Output: OP_RETURN (46 byte): `POCX` marker + plot_address (20 byte) + forging_address (20 byte)
- Output: Sukli na ibinabalik sa wallet

**Activation**:
- Ang assignment ay nagiging ASSIGNING sa confirmation
- Nagiging ACTIVE pagkatapos ng `nForgingAssignmentDelay` block
- Pinipigilan ng delay ang mabilis na reassignment sa panahon ng mga chain fork

**Mga Error Code**:
- `RPC_WALLET_NOT_FOUND`: Walang available na wallet
- `RPC_WALLET_UNLOCK_NEEDED`: Naka-encrypt at naka-lock ang wallet
- `RPC_WALLET_ERROR`: Nabigong gumawa ng transaksyon
- `RPC_INVALID_ADDRESS_OR_KEY`: Invalid na format ng address

**Halimbawa**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementasyon**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategorya**: wallet
**Kailangan ang Mining Server**: Hindi
**Kailangan ang Wallet**: Oo (dapat na-load at naka-unlock)

**Layunin**: Mag-revoke ng kasalukuyang forging assignment, ibinabalik ang mga karapatan sa forging sa may-ari ng plot.

**Mga Parameter**:
1. `plot_address` (string, kinakailangan) - Plot address (dapat nagmamay-ari ng private key, P2WPKH bech32)
2. `fee_rate` (numeric, opsyonal) - Fee rate sa BTC/kvB (default: 10× minRelayFee)

**Mga Return Value**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Mga Kinakailangan**:
- Na-load at naka-unlock ang wallet
- Private key para sa plot_address na nasa wallet
- Ang plot address ay dapat P2WPKH (bech32 format)
- Ang plot address ay dapat may mga nakumpirmang UTXO

**Istruktura ng Transaksyon**:
- Input: UTXO mula sa plot address (nagpapatunay ng pagmamay-ari)
- Output: OP_RETURN (26 byte): `XCOP` marker + plot_address (20 byte)
- Output: Sukli na ibinabalik sa wallet

**Epekto**:
- Agad na nagti-transition ang state sa REVOKING
- Ang forging address ay maaari pa ring mag-forge sa panahon ng delay period
- Nagiging REVOKED pagkatapos ng `nForgingRevocationDelay` block
- Ang may-ari ng plot ay maaaring mag-forge pagkatapos maging epektibo ang revocation
- Maaaring gumawa ng bagong assignment pagkatapos makumpleto ang revocation

**Mga Error Code**:
- `RPC_WALLET_NOT_FOUND`: Walang available na wallet
- `RPC_WALLET_UNLOCK_NEEDED`: Naka-encrypt at naka-lock ang wallet
- `RPC_WALLET_ERROR`: Nabigong gumawa ng transaksyon

**Halimbawa**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Mga Tala**:
- Idempotent: maaaring mag-revoke kahit walang aktibong assignment
- Hindi maaaring kanselahin ang revocation kapag naisumite na

**Implementasyon**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Mga Binagong Blockchain RPC

### getdifficulty

**Mga Modipikasyon ng PoCX**:
- **Kalkulasyon**: `reference_base_target / current_base_target`
- **Reference**: 1 TiB network capacity (base_target = 36650387593)
- **Interpretasyon**: Tinatayang kapasidad ng network storage sa TiB
  - Halimbawa: `1.0` = ~1 TiB
  - Halimbawa: `1024.0` = ~1 PiB
- **Pagkakaiba sa PoW**: Kumakatawan sa kapasidad, hindi hash power

**Halimbawa**:
```bash
bitcoin-cli getdifficulty
# Nagbabalik ng: 2048.5 (network ~2 PiB)
```

**Implementasyon**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Mga Idinagdag na Field ng PoCX**:
- `time_since_last_block` (numeric) - Mga segundo mula noong nakaraang block (pumapalit sa mediantime)
- `poc_time` (numeric) - Time-bended forge time sa segundo
- `base_target` (numeric) - PoCX difficulty base target
- `generation_signature` (string hex) - Generation signature
- `pocx_proof` (object):
  - `account_id` (string hex) - Plot account ID (20 byte)
  - `seed` (string hex) - Plot seed (32 byte)
  - `nonce` (numeric) - Mining nonce
  - `compression` (numeric) - Scaling level na ginamit
  - `quality` (numeric) - Claimed quality value
- `pubkey` (string hex) - Public key ng block signer (33 byte)
- `signer_address` (string) - Address ng block signer
- `signature` (string hex) - Block signature (65 byte)

**Mga Inalis na Field ng PoCX**:
- `mediantime` - Inalis (pinalitan ng time_since_last_block)

**Halimbawa**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementasyon**: `src/rpc/blockchain.cpp`

---

### getblock

**Mga Modipikasyon ng PoCX**: Pareho sa getblockheader, kasama ang buong data ng transaksyon

**Halimbawa**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose na may mga detalye ng tx
```

**Implementasyon**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Mga Idinagdag na Field ng PoCX**:
- `base_target` (numeric) - Kasalukuyang base target
- `generation_signature` (string hex) - Kasalukuyang generation signature

**Mga Binagong Field ng PoCX**:
- `difficulty` - Gumagamit ng kalkulasyon ng PoCX (batay sa kapasidad)

**Mga Inalis na Field ng PoCX**:
- `mediantime` - Inalis

**Halimbawa**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementasyon**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Mga Idinagdag na Field ng PoCX**:
- `generation_signature` (string hex) - Para sa pool mining
- `base_target` (numeric) - Para sa pool mining

**Mga Inalis na Field ng PoCX**:
- `target` - Inalis (tiyak sa PoW)
- `noncerange` - Inalis (tiyak sa PoW)
- `bits` - Inalis (tiyak sa PoW)

**Mga Tala**:
- Kasama pa rin ang buong data ng transaksyon para sa block construction
- Ginagamit ng mga pool server para sa coordinated mining

**Halimbawa**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementasyon**: `src/rpc/mining.cpp`

---

## Mga Naka-disable na RPC

Ang mga sumusunod na RPC na tiyak sa PoW ay **naka-disable** sa PoCX mode:

### getnetworkhashps
- **Dahilan**: Hindi applicable ang hash rate sa Proof of Capacity
- **Alternatibo**: Gamitin ang `getdifficulty` para sa tantiya ng kapasidad ng network

### getmininginfo
- **Dahilan**: Nagbabalik ng impormasyong tiyak sa PoW
- **Alternatibo**: Gamitin ang `get_mining_info` (tiyak sa PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Dahilan**: Hindi applicable ang CPU mining sa PoCX (nangangailangan ng mga pre-generated plot)
- **Alternatibo**: Gamitin ang external plotter + miner + `submit_nonce`

**Implementasyon**: `src/rpc/mining.cpp` (Ang mga RPC ay nagbabalik ng error kapag naka-define ang ENABLE_POCX)

---

## Mga Halimbawa ng Integrasyon

### Integrasyon ng External Miner

**Pangunahing Mining Loop**:
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

# Mining loop
while True:
    # 1. Kunin ang mga mining parameter
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. I-scan ang mga plot file (external implementation)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Isumite ang pinakamahusay na solusyon
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Tinanggap ang solusyon! Quality: {result['quality']}s, "
              f"Forge time: {result['poc_time']}s")

    # 4. Maghintay ng susunod na block
    time.sleep(10)  # Poll interval
```

---

### Pattern ng Integrasyon ng Pool

**Workflow ng Pool Server**:
1. Ang mga miner ay gumagawa ng mga forging assignment sa pool address
2. Ang pool ay nagpapatakbo ng wallet na may mga key ng forging address
3. Tinatawagan ng pool ang `get_mining_info` at ipinamamahagi sa mga miner
4. Nagsusumite ang mga miner ng mga solusyon sa pamamagitan ng pool (hindi direkta sa chain)
5. Vine-validate ng pool at tinatawagan ang `submit_nonce` gamit ang mga key ng pool
6. Ibinahagi ng pool ang mga reward ayon sa polisiya ng pool

**Pamamahala ng Assignment**:
```bash
# Gumagawa ang miner ng assignment (mula sa wallet ng miner)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Maghintay ng activation (30 block mainnet)

# Sinusuri ng pool ang assignment status
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Maaari na ngayong magsumite ang pool ng mga nonce para sa plot na ito
# (ang pool wallet ay dapat may pocx1qpool... private key)
```

---

### Mga Query ng Block Explorer

**Pag-query ng PoCX Block Data**:
```bash
# Kunin ang pinakabagong block
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Kunin ang mga detalye ng block na may PoCX proof
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# I-extract ang mga field na tiyak sa PoCX
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

**Pagtukoy ng mga Assignment Transaction**:
```bash
# I-scan ang transaksyon para sa OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Suriin ang assignment marker (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Paghawak ng Error

### Mga Karaniwang Pattern ng Error

**Height Mismatch**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Solusyon**: I-fetch ulit ang mining info, umusad ang chain

**Generation Signature Mismatch**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Solusyon**: I-fetch ulit ang mining info, dumating ang bagong block

**Walang Private Key**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Solusyon**: I-import ang key para sa plot o forging address

**Nakabinbin ang Assignment Activation**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solusyon**: Maghintay na lumipas ang activation delay

---

## Mga Sanggunian ng Code

**Mga Mining RPC**: `src/pocx/rpc/mining.cpp`
**Mga Assignment RPC**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Mga Blockchain RPC**: `src/rpc/blockchain.cpp`
**Proof Validation**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Assignment State**: `src/pocx/assignments/assignment_state.cpp`
**Paggawa ng Transaksyon**: `src/pocx/assignments/transactions.cpp`

---

## Mga Cross-Reference

Mga kaugnay na kabanata:
- [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md) - Mga detalye ng proseso ng mining
- [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md) - Arkitektura ng sistema ng assignment
- [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md) - Mga halaga ng assignment delay
- [Kabanata 8: Gabay sa Wallet](8-wallet-guide.md) - GUI para sa pamamahala ng assignment

---

[← Nakaraan: Mga Parameter ng Network](6-network-parameters.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Gabay sa Wallet →](8-wallet-guide.md)

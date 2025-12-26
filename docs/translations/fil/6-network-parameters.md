[← Nakaraan: Sinkronisasyon ng Oras](5-timing-security.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Sanggunian ng RPC →](7-rpc-reference.md)

---

# Kabanata 6: Mga Parameter ng Network at Configuration

Kumpletong sanggunian para sa configuration ng network ng Bitcoin-PoCX sa lahat ng uri ng network.

---

## Talaan ng mga Nilalaman

1. [Mga Parameter ng Genesis Block](#mga-parameter-ng-genesis-block)
2. [Configuration ng Chainparams](#configuration-ng-chainparams)
3. [Mga Parameter ng Consensus](#mga-parameter-ng-consensus)
4. [Coinbase at Block Reward](#coinbase-at-block-reward)
5. [Dynamic Scaling](#dynamic-scaling)
6. [Configuration ng Network](#configuration-ng-network)
7. [Istruktura ng Data Directory](#istruktura-ng-data-directory)

---

## Mga Parameter ng Genesis Block

### Kalkulasyon ng Base Target

**Formula**: `genesis_base_target = 2^42 / block_time_seconds`

**Rasyonal**:
- Ang bawat nonce ay kumakatawan sa 256 KiB (64 byte × 4096 scoop)
- 1 TiB = 2^22 nonce (ipinapalagay na panimulang kapasidad ng network)
- Inaasahang minimum quality para sa n nonce ≈ 2^64 / n
- Para sa 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Samakatuwid: base_target = 2^42 / block_time

**Mga Nakalkulang Halaga**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Gumagamit ng low-capacity calibration mode

### Genesis Message

Lahat ng network ay nagbabahagi ng Bitcoin genesis message:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementasyon**: `src/kernel/chainparams.cpp`

---

## Configuration ng Chainparams

### Mga Parameter ng Mainnet

**Pagkakakilanlan ng Network**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Default Port**: `8888`
- **Bech32 HRP**: `pocx`

**Mga Address Prefix** (Base58):
- PUBKEY_ADDRESS: `85` (mga address na nagsisimula sa 'P')
- SCRIPT_ADDRESS: `90` (mga address na nagsisimula sa 'R')
- SECRET_KEY: `128`

**Block Timing**:
- **Target na Block Time**: `120` segundo (2 minuto)
- **Target Timespan**: `1209600` segundo (14 araw)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundo

**Block Reward**:
- **Panimulang Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` block (~4 na taon)
- **Bilang ng Halving**: Maximum 64 halving

**Difficulty Adjustment**:
- **Rolling Window**: `24` block
- **Adjustment**: Bawat block
- **Algorithm**: Exponential moving average

**Mga Assignment Delay**:
- **Activation**: `30` block (~1 oras)
- **Revocation**: `720` block (~24 oras)

### Mga Parameter ng Testnet

**Pagkakakilanlan ng Network**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Default Port**: `18888`
- **Bech32 HRP**: `tpocx`

**Mga Address Prefix** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Block Timing**:
- **Target na Block Time**: `120` segundo
- **MAX_FUTURE_BLOCK_TIME**: `15` segundo
- **Allow Min Difficulty**: `true`

**Block Reward**:
- **Panimulang Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` block

**Difficulty Adjustment**:
- **Rolling Window**: `24` block

**Mga Assignment Delay**:
- **Activation**: `30` block (~1 oras)
- **Revocation**: `720` block (~24 oras)

### Mga Parameter ng Regtest

**Pagkakakilanlan ng Network**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Default Port**: `18444`
- **Bech32 HRP**: `rpocx`

**Mga Address Prefix** (Bitcoin-compatible):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Block Timing**:
- **Target na Block Time**: `1` segundo (instant mining para sa testing)
- **Target Timespan**: `86400` segundo (1 araw)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundo

**Block Reward**:
- **Panimulang Subsidy**: `10 BTC`
- **Halving Interval**: `500` block

**Difficulty Adjustment**:
- **Rolling Window**: `24` block
- **Allow Min Difficulty**: `true`
- **No Retargeting**: `true`
- **Low Capacity Calibration**: `true` (gumagamit ng 16-nonce calibration sa halip na 1 TiB)

**Mga Assignment Delay**:
- **Activation**: `4` block (~4 segundo)
- **Revocation**: `8` block (~8 segundo)

### Mga Parameter ng Signet

**Pagkakakilanlan ng Network**:
- **Magic Bytes**: Unang 4 byte ng SHA256d(signet_challenge)
- **Default Port**: `38333`
- **Bech32 HRP**: `tpocx`

**Block Timing**:
- **Target na Block Time**: `120` segundo
- **MAX_FUTURE_BLOCK_TIME**: `15` segundo

**Block Reward**:
- **Panimulang Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` block

**Difficulty Adjustment**:
- **Rolling Window**: `24` block

---

## Mga Parameter ng Consensus

### Mga Timing Parameter

**MAX_FUTURE_BLOCK_TIME**: `15` segundo
- Tiyak sa PoCX (gumagamit ang Bitcoin ng 2 oras)
- Rasyonal: Ang PoC timing ay nangangailangan ng halos real-time na validation
- Ang mga block na higit sa 15s sa hinaharap ay ni-reject

**Time Offset Warning**: `10` segundo
- Binabalaan ang mga operator kapag ang node clock ay lumihis ng >10s mula sa network time
- Walang enforcement, pang-impormasyon lamang

**Mga Target ng Block Time**:
- Mainnet/Testnet/Signet: `120` segundo
- Regtest: `1` segundo

**TIMESTAMP_WINDOW**: `15` segundo (katumbas ng MAX_FUTURE_BLOCK_TIME)

**Implementasyon**: `src/chain.h`, `src/validation.cpp`

### Mga Parameter ng Difficulty Adjustment

**Laki ng Rolling Window**: `24` block (lahat ng network)
- Exponential moving average ng mga kamakailang block time
- Bawat-block na adjustment
- Tumutugon sa mga pagbabago ng kapasidad

**Implementasyon**: `src/consensus/params.h`, difficulty logic sa block creation

### Mga Parameter ng Assignment System

**nForgingAssignmentDelay** (activation delay):
- Mainnet: `30` block (~1 oras)
- Testnet: `30` block (~1 oras)
- Regtest: `4` block (~4 segundo)

**nForgingRevocationDelay** (revocation delay):
- Mainnet: `720` block (~24 oras)
- Testnet: `720` block (~24 oras)
- Regtest: `8` block (~8 segundo)

**Rasyonal**:
- Ang activation delay ay pumipigil sa mabilis na reassignment sa panahon ng mga block race
- Ang revocation delay ay nagbibigay ng katatagan at pumipigil sa pang-aabuso

**Implementasyon**: `src/consensus/params.h`

---

## Coinbase at Block Reward

### Iskedyul ng Block Subsidy

**Panimulang Subsidy**: `10 BTC` (lahat ng network)

**Iskedyul ng Halving**:
- Bawat `1050000` block (mainnet/testnet)
- Bawat `500` block (regtest)
- Nagpapatuloy para sa maximum na 64 halving

**Progression ng Halving**:
```
Halving 0: 10.00000000 BTC  (block 0 - 1049999)
Halving 1:  5.00000000 BTC  (block 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (block 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (block 3150000 - 4199999)
...
```

**Kabuuang Supply**: ~21 milyong BTC (pareho sa Bitcoin)

### Mga Patakaran sa Coinbase Output

**Destinasyon ng Pagbabayad**:
- **Walang Assignment**: Ang coinbase ay nagbabayad sa plot address (proof.account_id)
- **May Assignment**: Ang coinbase ay nagbabayad sa forging address (effective signer)

**Format ng Output**: P2WPKH lamang
- Ang coinbase ay dapat magbayad sa bech32 SegWit v0 address
- Ginawa mula sa public key ng effective signer

**Assignment Resolution**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementasyon**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamic Scaling

### Mga Scaling Bound

**Layunin**: Pataasin ang difficulty ng plot generation habang umuunlad ang network upang maiwasan ang capacity inflation

**Istruktura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum na tinatanggap na level
    uint8_t nPoCXTargetCompression;  // Inirerekomendang level
};
```

**Relasyon**: `target = min + 1` (laging isang level sa itaas ng minimum)

### Iskedyul ng Pagtaas ng Scaling

Ang mga scaling level ay tumataas sa **exponential na iskedyul** batay sa mga halving interval:

| Panahon | Block Height | Mga Halving | Min | Target |
|-------------|--------------|----------|-----|--------|
| Taon 0-4 | 0 hanggang 1049999 | 0 | X1 | X2 |
| Taon 4-12 | 1050000 hanggang 3149999 | 1-2 | X2 | X3 |
| Taon 12-28 | 3150000 hanggang 7349999 | 3-6 | X3 | X4 |
| Taon 28-60 | 7350000 hanggang 15749999 | 7-14 | X4 | X5 |
| Taon 60-124 | 15750000 hanggang 32549999 | 15-30 | X5 | X6 |
| Taon 124+ | 32550000+ | 31+ | X6 | X7 |

**Mga Pangunahing Height** (taon → halving → block):
- Taon 4: Halving 1 sa block 1050000
- Taon 12: Halving 3 sa block 3150000
- Taon 28: Halving 7 sa block 7350000
- Taon 60: Halving 15 sa block 15750000
- Taon 124: Halving 31 sa block 32550000

### Difficulty ng Scaling Level

**Pag-scale ng PoW**:
- Scaling level X0: POC2 baseline (teoretikal)
- Scaling level X1: XOR-transpose baseline
- Scaling level Xn: 2^(n-1) × X1 work na naka-embed
- Ang bawat level ay nagdodoble ng plot generation work

**Pagkakahanay sa Ekonomiya**:
- Ang mga block reward ay nagha-halving → tumataas ang difficulty ng plot generation
- Pinapanatili ang safety margin: halaga ng paggawa ng plot > halaga ng lookup
- Pinipigilan ang capacity inflation mula sa mga pagpapabuti ng hardware

### Validation ng Plot

**Mga Patakaran sa Validation**:
- Ang mga isinumiteng proof ay dapat may scaling level ≥ minimum
- Ang mga proof na may scaling > target ay tinatanggap ngunit hindi mahusay
- Ang mga proof na mas mababa sa minimum: ni-reject (hindi sapat na PoW)

**Pagkuha ng Bound**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementasyon**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configuration ng Network

### Mga Seed Node at DNS Seed

**Katayuan**: Placeholder para sa mainnet launch

**Nakaplanong Configuration**:
- Mga seed node: TBD
- Mga DNS seed: TBD

**Kasalukuyang Katayuan** (testnet/regtest):
- Walang dedikadong seed infrastructure
- Sinusuportahan ang mga manual peer connection sa pamamagitan ng `-addnode`

**Implementasyon**: `src/kernel/chainparams.cpp`

### Mga Checkpoint

**Genesis Checkpoint**: Laging block 0

**Mga Karagdagang Checkpoint**: Wala pang nako-configure

**Hinaharap**: Ang mga checkpoint ay idadagdag habang umuunlad ang mainnet

---

## Configuration ng P2P Protocol

### Bersyon ng Protocol

**Base**: Bitcoin Core v30.0 protocol
- **Protocol Version**: Minana mula sa Bitcoin Core
- **Service Bits**: Mga standard Bitcoin service
- **Mga Uri ng Mensahe**: Mga standard Bitcoin P2P message

**Mga Extension ng PoCX**:
- Ang mga block header ay may kasamang mga field na tiyak sa PoCX
- Ang mga block message ay may kasamang PoCX proof data
- Ang mga patakaran sa validation ay nagpapatupad ng PoCX consensus

**Compatibility**: Ang mga PoCX node ay hindi compatible sa mga Bitcoin PoW node (iba ang consensus)

**Implementasyon**: `src/protocol.h`, `src/net_processing.cpp`

---

## Istruktura ng Data Directory

### Default na Direktoryo

**Lokasyon**: `.bitcoin/` (pareho sa Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Nilalaman ng Direktoryo

```
.bitcoin/
├── blocks/              # Block data
│   ├── blk*.dat        # Mga block file
│   ├── rev*.dat        # Undo data
│   └── index/          # Block index (LevelDB)
├── chainstate/         # UTXO set + forging assignment (LevelDB)
├── wallets/            # Mga wallet file
│   └── wallet.dat      # Default wallet
├── bitcoin.conf        # Configuration file
├── debug.log           # Debug log
├── peers.dat           # Mga peer address
├── mempool.dat         # Mempool persistence
└── banlist.dat         # Mga banned peer
```

### Mga Pangunahing Pagkakaiba mula sa Bitcoin

**Chainstate Database**:
- Standard: UTXO set
- **Karagdagan ng PoCX**: Forging assignment state
- Mga atomic update: UTXO + assignment na ina-update nang magkasama
- Reorg-safe undo data para sa mga assignment

**Mga Block File**:
- Standard Bitcoin block format
- **Karagdagan ng PoCX**: Pinalawak ng mga field ng PoCX proof (account_id, seed, nonce, signature, pubkey)

### Halimbawa ng Configuration File

**bitcoin.conf**:
```ini
# Pagpili ng network
#testnet=1
#regtest=1

# PoCX mining server (kinakailangan para sa mga external miner)
miningserver=1

# Mga setting ng RPC
server=1
rpcuser=yourusername
rpcpassword=yourpassword
rpcallowip=127.0.0.1
rpcport=8332

# Mga setting ng koneksyon
listen=1
port=8888
maxconnections=125

# Target na block time (pang-impormasyon, ipinatutupad ng consensus)
# 120 segundo para sa mainnet/testnet
```

---

## Mga Sanggunian ng Code

**Chainparams**: `src/kernel/chainparams.cpp`
**Mga Parameter ng Consensus**: `src/consensus/params.h`
**Mga Compression Bound**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis Base Target Calculation**: `src/pocx/consensus/params.cpp`
**Coinbase Payment Logic**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Assignment State Storage**: `src/coins.h`, `src/coins.cpp` (mga extension ng CCoinsViewCache)

---

## Mga Cross-Reference

Mga kaugnay na kabanata:
- [Kabanata 2: Format ng Plot](2-plot-format.md) - Mga scaling level sa plot generation
- [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md) - Scaling validation, sistema ng assignment
- [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md) - Mga parameter ng assignment delay
- [Kabanata 5: Seguridad sa Timing](5-timing-security.md) - Rasyonal ng MAX_FUTURE_BLOCK_TIME

---

[← Nakaraan: Sinkronisasyon ng Oras](5-timing-security.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Sanggunian ng RPC →](7-rpc-reference.md)

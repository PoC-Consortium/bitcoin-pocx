[← Previous: Time Synchronization](5-timing-security.md) | [📘 Table of Contents](index.md) | [Next: RPC Reference →](7-rpc-reference.md)

---

# Chapter 6: Network Parameters and Configuration

Complete reference for Bitcoin-PoCX network configuration across all network types.

---

## Table of Contents

1. [Genesis Block Parameters](#genesis-block-parameters)
2. [Chainparams Configuration](#chainparams-configuration)
3. [Consensus Parameters](#consensus-parameters)
4. [Coinbase and Block Rewards](#coinbase-and-block-rewards)
5. [Dynamic Scaling](#dynamic-scaling)
6. [Network Configuration](#network-configuration)
7. [Data Directory Structure](#data-directory-structure)

---

## Genesis Block Parameters

### Base Target Calculation

**Formula**: `genesis_base_target = 2^42 / block_time_seconds`

**Rationale**:
- Each nonce represents 256 KiB (64 bytes × 4096 scoops)
- 1 TiB = 2^22 nonces (starting network capacity assumption)
- Expected minimum quality for n nonces ≈ 2^64 / n
- For 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Therefore: base_target = 2^42 / block_time

**Calculated Values**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Uses low-capacity calibration mode

### Genesis Message

All networks share the Bitcoin genesis message:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementation**: `src/kernel/chainparams.cpp`

---

## Chainparams Configuration

### Mainnet Parameters

**Network Identity**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Default Port**: `8888`
- **Bech32 HRP**: `pocx`

**Address Prefixes** (Base58):
- PUBKEY_ADDRESS: `85` (addresses start with 'P')
- SCRIPT_ADDRESS: `90` (addresses start with 'R')
- SECRET_KEY: `128`

**Block Timing**:
- **Block Time Target**: `120` seconds (2 minutes)
- **Target Timespan**: `1209600` seconds (14 days)
- **MAX_FUTURE_BLOCK_TIME**: `15` seconds

**Block Rewards**:
- **Initial Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` blocks (~4 years)
- **Halving Count**: 64 halvings maximum

**Difficulty Adjustment**:
- **Rolling Window**: `24` blocks
- **Adjustment**: Every block
- **Algorithm**: Exponential moving average

**Assignment Delays**:
- **Activation**: `30` blocks (~1 hour)
- **Revocation**: `720` blocks (~24 hours)

### Testnet Parameters

**Network Identity**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Default Port**: `18888`
- **Bech32 HRP**: `tpocx`

**Address Prefixes** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Block Timing**:
- **Block Time Target**: `120` seconds
- **MAX_FUTURE_BLOCK_TIME**: `15` seconds
- **Allow Min Difficulty**: `true`

**Block Rewards**:
- **Initial Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` blocks

**Difficulty Adjustment**:
- **Rolling Window**: `24` blocks

**Assignment Delays**:
- **Activation**: `30` blocks (~1 hour)
- **Revocation**: `720` blocks (~24 hours)

### Regtest Parameters

**Network Identity**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Default Port**: `18444`
- **Bech32 HRP**: `rpocx`

**Address Prefixes** (Bitcoin-compatible):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Block Timing**:
- **Block Time Target**: `1` second (instant mining for testing)
- **Target Timespan**: `86400` seconds (1 day)
- **MAX_FUTURE_BLOCK_TIME**: `15` seconds

**Block Rewards**:
- **Initial Subsidy**: `10 BTC`
- **Halving Interval**: `500` blocks

**Difficulty Adjustment**:
- **Rolling Window**: `24` blocks
- **Allow Min Difficulty**: `true`
- **No Retargeting**: `true`
- **Low Capacity Calibration**: `true` (uses 16-nonce calibration instead of 1 TiB)

**Assignment Delays**:
- **Activation**: `4` blocks (~4 seconds)
- **Revocation**: `8` blocks (~8 seconds)

### Signet Parameters

**Network Identity**:
- **Magic Bytes**: First 4 bytes of SHA256d(signet_challenge)
- **Default Port**: `38333`
- **Bech32 HRP**: `tpocx`

**Block Timing**:
- **Block Time Target**: `120` seconds
- **MAX_FUTURE_BLOCK_TIME**: `15` seconds

**Block Rewards**:
- **Initial Subsidy**: `10 BTC`
- **Halving Interval**: `1050000` blocks

**Difficulty Adjustment**:
- **Rolling Window**: `24` blocks

---

## Consensus Parameters

### Timing Parameters

**MAX_FUTURE_BLOCK_TIME**: `15` seconds
- PoCX-specific (Bitcoin uses 2 hours)
- Rationale: PoC timing requires near real-time validation
- Blocks more than 15s in the future are rejected

**Time Offset Warning**: `10` seconds
- Operators warned when node clock drifts >10s from network time
- No enforcement, informational only

**Block Time Targets**:
- Mainnet/Testnet/Signet: `120` seconds
- Regtest: `1` second

**TIMESTAMP_WINDOW**: `15` seconds (equals MAX_FUTURE_BLOCK_TIME)

**Implementation**: `src/chain.h`, `src/validation.cpp`

### Difficulty Adjustment Parameters

**Rolling Window Size**: `24` blocks (all networks)
- Exponential moving average of recent block times
- Every-block adjustment
- Responsive to capacity changes

**Implementation**: `src/consensus/params.h`, difficulty logic in block creation

### Assignment System Parameters

**nForgingAssignmentDelay** (activation delay):
- Mainnet: `30` blocks (~1 hour)
- Testnet: `30` blocks (~1 hour)
- Regtest: `4` blocks (~4 seconds)

**nForgingRevocationDelay** (revocation delay):
- Mainnet: `720` blocks (~24 hours)
- Testnet: `720` blocks (~24 hours)
- Regtest: `8` blocks (~8 seconds)

**Rationale**:
- Activation delay prevents rapid reassignment during block races
- Revocation delay provides stability and prevents abuse

**Implementation**: `src/consensus/params.h`

---

## Coinbase and Block Rewards

### Block Subsidy Schedule

**Initial Subsidy**: `10 BTC` (all networks)

**Halving Schedule**:
- Every `1050000` blocks (mainnet/testnet)
- Every `500` blocks (regtest)
- Continues for 64 halvings maximum

**Halving Progression**:
```
Halving 0: 10.00000000 BTC  (blocks 0 - 1049999)
Halving 1:  5.00000000 BTC  (blocks 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (blocks 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (blocks 3150000 - 4199999)
...
```

**Total Supply**: ~21 million BTC (same as Bitcoin)

### Coinbase Output Rules

**Payment Destination**:
- **No Assignment**: Coinbase pays plot address (proof.account_id)
- **With Assignment**: Coinbase pays forging address (effective signer)

**Output Format**: P2WPKH only
- Coinbase must pay to bech32 SegWit v0 address
- Generated from effective signer's public key

**Assignment Resolution**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementation**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamic Scaling

### Scaling Bounds

**Purpose**: Increase plot generation difficulty as network matures to prevent capacity inflation

**Structure**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum accepted level
    uint8_t nPoCXTargetCompression;  // Recommended level
};
```

**Relationship**: `target = min + 1` (always one level above minimum)

### Scaling Increase Schedule

Scaling levels increase on **exponential schedule** based on halving intervals:

| Time Period | Block Height | Halvings | Min | Target |
|-------------|--------------|----------|-----|--------|
| Years 0-4 | 0 to 1049999 | 0 | X1 | X2 |
| Years 4-12 | 1050000 to 3149999 | 1-2 | X2 | X3 |
| Years 12-28 | 3150000 to 7349999 | 3-6 | X3 | X4 |
| Years 28-60 | 7350000 to 15749999 | 7-14 | X4 | X5 |
| Years 60-124 | 15750000 to 32549999 | 15-30 | X5 | X6 |
| Years 124+ | 32550000+ | 31+ | X6 | X7 |

**Key Heights** (years → halvings → blocks):
- Year 4: Halving 1 at block 1050000
- Year 12: Halving 3 at block 3150000
- Year 28: Halving 7 at block 7350000
- Year 60: Halving 15 at block 15750000
- Year 124: Halving 31 at block 32550000

### Scaling Level Difficulty

**PoW Scaling**:
- Scaling level X0: POC2 baseline (theoretical)
- Scaling level X1: XOR-transpose baseline
- Scaling level Xn: 2^(n-1) × X1 work embedded
- Each level doubles plot generation work

**Economic Alignment**:
- Block rewards halve → plot generation difficulty increases
- Maintains safety margin: plot creation cost > lookup cost
- Prevents capacity inflation from hardware improvements

### Plot Validation

**Validation Rules**:
- Submitted proofs must have scaling level ≥ minimum
- Proofs with scaling > target accepted but inefficient
- Proofs below minimum: rejected (insufficient PoW)

**Bounds Retrieval**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementation**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Network Configuration

### Seed Nodes and DNS Seeds

**Status**: Placeholder for mainnet launch

**Planned Configuration**:
- Seed nodes: TBD
- DNS seeds: TBD

**Current State** (testnet/regtest):
- No dedicated seed infrastructure
- Manual peer connections supported via `-addnode`

**Implementation**: `src/kernel/chainparams.cpp`

### Checkpoints

**Genesis Checkpoint**: Always block 0

**Additional Checkpoints**: None currently configured

**Future**: Checkpoints will be added as mainnet progresses

---

## P2P Protocol Configuration

### Protocol Version

**Base**: Bitcoin Core v30.0 protocol
- **Protocol Version**: Inherited from Bitcoin Core
- **Service Bits**: Standard Bitcoin services
- **Message Types**: Standard Bitcoin P2P messages

**PoCX Extensions**:
- Block headers include PoCX-specific fields
- Block messages include PoCX proof data
- Validation rules enforce PoCX consensus

**Compatibility**: PoCX nodes incompatible with Bitcoin PoW nodes (different consensus)

**Implementation**: `src/protocol.h`, `src/net_processing.cpp`

---

## Data Directory Structure

### Default Directory

**Location**: `.bitcoin/` (same as Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Directory Contents

```
.bitcoin/
├── blocks/              # Block data
│   ├── blk*.dat        # Block files
│   ├── rev*.dat        # Undo data
│   └── index/          # Block index (LevelDB)
├── chainstate/         # UTXO set + forging assignments (LevelDB)
├── wallets/            # Wallet files
│   └── wallet.dat      # Default wallet
├── bitcoin.conf        # Configuration file
├── debug.log           # Debug log
├── peers.dat           # Peer addresses
├── mempool.dat         # Mempool persistence
└── banlist.dat         # Banned peers
```

### Key Differences from Bitcoin

**Chainstate Database**:
- Standard: UTXO set
- **PoCX Addition**: Forging assignment state
- Atomic updates: UTXO + assignments updated together
- Reorg-safe undo data for assignments

**Block Files**:
- Standard Bitcoin block format
- **PoCX Addition**: Extended with PoCX proof fields (account_id, seed, nonce, signature, pubkey)

### Configuration File Example

**bitcoin.conf**:
```ini
# Network selection
#testnet=1
#regtest=1

# PoCX mining server (required for external miners)
miningserver=1

# RPC settings
server=1
rpcuser=yourusername
rpcpassword=yourpassword
rpcallowip=127.0.0.1
rpcport=8332

# Connection settings
listen=1
port=8888
maxconnections=125

# Block time target (informational, consensus enforced)
# 120 seconds for mainnet/testnet
```

---

## Code References

**Chainparams**: `src/kernel/chainparams.cpp`
**Consensus Parameters**: `src/consensus/params.h`
**Compression Bounds**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis Base Target Calculation**: `src/pocx/consensus/params.cpp`
**Coinbase Payment Logic**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Assignment State Storage**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache extensions)

---

## Cross-References

Related chapters:
- [Chapter 2: Plot Format](2-plot-format.md) - Scaling levels in plot generation
- [Chapter 3: Consensus and Mining](3-consensus-and-mining.md) - Scaling validation, assignment system
- [Chapter 4: Forging Assignments](4-forging-assignments.md) - Assignment delay parameters
- [Chapter 5: Timing Security](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME rationale

---

[← Previous: Time Synchronization](5-timing-security.md) | [📘 Table of Contents](index.md) | [Next: RPC Reference →](7-rpc-reference.md)

[📘 Table of Contents](index.md) | [Next: Plot Format →](2-plot-format.md)

---

# Chapter 1: Introduction and Overview

## What is Bitcoin-PoCX?

Bitcoin-PoCX is a Bitcoin Core integration that adds **Proof of Capacity neXt generation (PoCX)** consensus support. It maintains Bitcoin Core's existing architecture while enabling an energy-efficient Proof-of-Capacity mining alternative as a complete replacement for Proof of Work.

**Key Distinction**: This is a **new chain** without backward compatibility with Bitcoin PoW. PoCX blocks are incompatible with PoW nodes by design.

---

## Project Identity

- **Organization**: Proof of Capacity Consortium
- **Project Name**: Bitcoin-PoCX
- **Full Name**: Bitcoin Core with PoCX Integration
- **Status**: Testnet Phase

---

## What is Proof of Capacity?

Proof of Capacity (PoC) is a consensus mechanism where mining power is proportional to **disk space** rather than computational power. Miners pre-generate large plot files containing cryptographic hashes, then use these plots to find valid block solutions.

**Energy Efficiency**: Plot files are generated once and reused indefinitely. Mining consumes minimal CPU power—primarily disk I/O.

**PoCX Enhancements**:
- Fixed XOR-transpose compression attack (50% time-memory tradeoff in POC2)
- 16-nonce aligned layout for modern hardware
- Scalable proof-of-work in plot generation (Xn scaling levels)
- Native C++ integration directly into Bitcoin Core
- Time Bending algorithm for improved block time distribution

---

## Architecture Overview

### Repository Structure

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX integration
│   └── src/pocx/        # PoCX implementation
├── pocx/                # PoCX core framework (submodule, read-only)
└── docs/                # This documentation
```

### Integration Philosophy

**Minimal Integration Surface**: Changes isolated in `/src/pocx/` directory with clean hooks into Bitcoin Core validation, mining, and RPC layers.

**Feature Flagging**: All modifications under `#ifdef ENABLE_POCX` preprocessor guards. Bitcoin Core builds normally when disabled.

**Upstream Compatibility**: Regular sync with Bitcoin Core updates maintained through isolated integration points.

**Native C++ Implementation**: Scalar cryptographic algorithms (Shabal256, scoop calculation, compression) integrated directly into Bitcoin Core for consensus validation.

---

## Key Features

### 1. Complete Consensus Replacement

- **Block Structure**: PoCX-specific fields replace PoW nonce and difficulty bits
  - Generation signature (deterministic mining entropy)
  - Base target (inverse of difficulty)
  - PoCX proof (account ID, seed, nonce)
  - Block signature (proves plot ownership)

- **Validation**: 5-stage validation pipeline from header check through block connection

- **Difficulty Adjustment**: Every-block adjustment using moving average of recent base targets

### 2. Time Bending Algorithm

**Problem**: Traditional PoC block times follow exponential distribution, leading to long blocks when no miner finds a good solution.

**Solution**: Distribution transformation from exponential to chi-squared using cube root: `Y = scale × (X^(1/3))`.

**Effect**: Very good solutions forge later (network has time to scan all disks, reduces fast blocks), poor solutions improved. Average block time maintained at 120 seconds, long blocks reduced.

**Details**: [Chapter 3: Consensus and Mining](3-consensus-and-mining.md)

### 3. Forging Assignment System

**Capability**: Plot owners can delegate forging rights to other addresses while maintaining plot ownership.

**Use Cases**:
- Pool mining (plots assign to pool address)
- Cold storage (mining key separate from plot ownership)
- Multi-party mining (shared infrastructure)

**Architecture**: OP_RETURN-only design—no special UTXOs, assignments tracked separately in chainstate database.

**Details**: [Chapter 4: Forging Assignments](4-forging-assignments.md)

### 4. Defensive Forging

**Problem**: Fast clocks could provide timing advantages within the 15-second future tolerance.

**Solution**: When receiving a competing block at same height, automatically check local quality. If better, forge immediately.

**Effect**: Eliminates incentive for clock manipulation—fast clocks only help if you already have the best solution.

**Details**: [Chapter 5: Timing Security](5-timing-security.md)

### 5. Dynamic Compression Scaling

**Economic Alignment**: Scaling level requirements increase on exponential schedule (Years 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Effect**: As block rewards decrease, plot generation difficulty increases. Maintains safety margin between plot creation and lookup costs.

**Prevents**: Capacity inflation from faster hardware over time.

**Details**: [Chapter 6: Network Parameters](6-network-parameters.md)

---

## Design Philosophy

### Code Safety

- Defensive programming practices throughout
- Comprehensive error handling in validation paths
- No nested locks (deadlock prevention)
- Atomic database operations (UTXO + assignments together)

### Modular Architecture

- Clean separation between Bitcoin Core infrastructure and PoCX consensus
- PoCX core framework provides cryptographic primitives
- Bitcoin Core provides validation framework, database, networking

### Performance Optimizations

- Fast-fail validation ordering (cheap checks first)
- Single context fetch per submission (no repeated cs_main acquisitions)
- Atomic database operations for consistency

### Reorg Safety

- Full undo data for assignment state changes
- Forging state reset on chain tip changes
- Staleness detection at all validation points

---

## How PoCX Differs from Proof of Work

| Aspect | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Mining Resource** | Computational power (hash rate) | Disk space (capacity) |
| **Energy Consumption** | High (continuous hashing) | Low (disk I/O only) |
| **Mining Process** | Find nonce with hash < target | Find nonce with deadline < elapsed time |
| **Difficulty** | `bits` field, adjusted every 2016 blocks | `base_target` field, adjusted every block |
| **Block Time** | ~10 minutes (exponential distribution) | 120 seconds (time-bended, reduced variance) |
| **Subsidy** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Hardware** | ASICs (specialized) | HDDs (commodity hardware) |
| **Mining Identity** | Anonymous | Plot owner or delegate |

---

## System Requirements

### Node Operation

**Same as Bitcoin Core**:
- **CPU**: Modern x86_64 processor
- **Memory**: 4-8 GB RAM
- **Storage**: New chain, currently empty (can grow ~4× faster than Bitcoin due to 2-minute blocks and assignment database)
- **Network**: Stable internet connection
- **Clock**: NTP synchronization recommended for optimal operation

**Note**: Plot files are NOT required for node operation.

### Mining Requirements

**Additional requirements for mining**:
- **Plot Files**: Pre-generated using `pocx_plotter` (reference implementation)
- **Miner Software**: `pocx_miner` (reference implementation) connects via RPC
- **Wallet**: `bitcoind` or `bitcoin-qt` with private keys for mining address. Pool mining does not require local wallet.

---

## Getting Started

### 1. Build Bitcoin-PoCX

```bash
# Clone with submodules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build with PoCX enabled
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Details**: See `CLAUDE.md` in repository root

### 2. Run Node

**Node only**:
```bash
./build/bin/bitcoind
# or
./build/bin/bitcoin-qt
```

**For mining** (enables RPC access for external miners):
```bash
./build/bin/bitcoind -miningserver
# or
./build/bin/bitcoin-qt -server -miningserver
```

**Details**: [Chapter 6: Network Parameters](6-network-parameters.md)

### 3. Generate Plot Files

Use `pocx_plotter` (reference implementation) to generate PoCX-format plot files.

**Details**: [Chapter 2: Plot Format](2-plot-format.md)

### 4. Setup Mining

Use `pocx_miner` (reference implementation) to connect to your node's RPC interface.

**Details**: [Chapter 7: RPC Reference](7-rpc-reference.md) and [Chapter 8: Wallet Guide](8-wallet-guide.md)

---

## Attribution

### Plot Format

Based on POC2 format (Burstcoin) with enhancements:
- Fixed security flaw (XOR-transpose compression attack)
- Scalable proof-of-work
- SIMD-optimized layout
- Seed functionality

### Source Projects

- **pocx_miner**: Reference implementation based on [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Reference implementation based on [engraver](https://github.com/PoC-Consortium/engraver)

**Full Attribution**: [Chapter 2: Plot Format](2-plot-format.md)

---

## Technical Specifications Summary

- **Block Time**: 120 seconds (mainnet), 1 second (regtest)
- **Block Subsidy**: 10 BTC initial, halving every 1,050,000 blocks (~4 years)
- **Total Supply**: ~21 million BTC (same as Bitcoin)
- **Future Tolerance**: 15 seconds (blocks up to 15s ahead accepted)
- **Clock Warning**: 10 seconds (warns operators of time drift)
- **Assignment Delay**: 30 blocks (~1 hour)
- **Revocation Delay**: 720 blocks (~24 hours)
- **Address Format**: P2WPKH (bech32, bc1q...) only for PoCX mining operations and forging assignments

---

## Code Organization

**Bitcoin Core Modifications**: Minimal changes to core files, feature-flagged with `#ifdef ENABLE_POCX`

**New PoCX Implementation**: Isolated in `src/pocx/` directory

---

## Security Considerations

### Timing Security

- 15-second future tolerance prevents network fragmentation
- 10-second warning threshold alerts operators to clock drift
- Defensive forging eliminates incentive for clock manipulation
- Time bending reduces impact of timing variance

**Details**: [Chapter 5: Timing Security](5-timing-security.md)

### Assignment Security

- OP_RETURN-only design (no UTXO manipulation)
- Transaction signature proves plot ownership
- Activation delays prevent rapid state manipulation
- Reorg-safe undo data for all state changes

**Details**: [Chapter 4: Forging Assignments](4-forging-assignments.md)

### Consensus Security

- Signature excluded from block hash (prevents malleability)
- Bounded signature sizes (prevents DoS)
- Compression bounds validation (prevents weak proofs)
- Every-block difficulty adjustment (responsive to capacity changes)

**Details**: [Chapter 3: Consensus and Mining](3-consensus-and-mining.md)

---

## Network Status

**Mainnet**: Not yet launched
**Testnet**: Available for testing
**Regtest**: Fully functional for development

**Genesis Block Parameters**: [Chapter 6: Network Parameters](6-network-parameters.md)

---

## Next Steps

**For Understanding PoCX**: Continue to [Chapter 2: Plot Format](2-plot-format.md) to learn about plot file structure and format evolution.

**For Mining Setup**: Jump to [Chapter 7: RPC Reference](7-rpc-reference.md) for integration details.

**For Running a Node**: Review [Chapter 6: Network Parameters](6-network-parameters.md) for configuration options.

---

[📘 Table of Contents](index.md) | [Next: Plot Format →](2-plot-format.md)

# Bitcoin-PoCX

Bitcoin Core with Proof of Capacity neXt generation (PoCX) consensus integration.

**Status**: Testnet Phase
**Organization**: Proof of Capacity Consortium
**License**: MIT

---

## Documentation

📘 **[Complete Technical Documentation](docs/index.md)** - 8-chapter browseable guide covering all aspects of the system

📄 **[Whitepaper](docs/whitepaper.md)** - Academic overview, design rationale, and architecture

**Quick Links**:
- [Introduction and Overview](docs/1-introduction.md)
- [Consensus and Mining](docs/3-consensus-and-mining.md)
- [RPC Reference](docs/7-rpc-reference.md)
- [Wallet Guide](docs/8-wallet-guide.md)

---

## Quick Start

### Clone with Submodules

```bash
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin
```

### Build with PoCX

```bash
cmake -B build -DENABLE_POCX=ON
cmake --build build -j$(nproc)
```

### Run Node

```bash
# Node only
./build/bin/bitcoind

# With mining server enabled
./build/bin/bitcoind -miningserver

# Qt wallet
./build/bin/bitcoin-qt -server -miningserver
```

**Build Requirements**: Standard Bitcoin Core dependencies ([see Bitcoin Core docs](bitcoin/doc/build-unix.md))

---

## Repository Structure

```
bitcoin-pocx/                           # Main integration repository
├── bitcoin/                            # Bitcoin Core v30.0 + PoCX (submodule)
│   └── src/pocx/                      # PoCX implementation
├── pocx/                               # PoCX core framework (submodule, read-only)
├── docs/                               # Complete technical documentation
│   ├── index.md                       # Documentation hub
│   ├── whitepaper.md                  # Academic whitepaper
│   └── [1-8]-*.md                     # 8-chapter guide
└── README.md                           # This file
```

### Submodule Repositories

- **bitcoin/** → [PoC-Consortium/bitcoin](https://github.com/PoC-Consortium/bitcoin) - Bitcoin Core v30.0 with PoCX integration
- **pocx/** → [PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx) - PoCX core framework (read-only reference)

---

## What is Bitcoin-PoCX?

Bitcoin-PoCX integrates Proof of Capacity consensus into Bitcoin Core as a complete replacement for Proof of Work. Mining power derives from pre-generated plot files stored on disk rather than computational hashing, reducing energy consumption by several orders of magnitude.

**Key Features**:
- Energy-efficient Proof of Capacity consensus
- 120-second block time (2 minutes)
- 10 BTC initial subsidy, halving every 1,050,000 blocks (~4 years)
- ~21 million BTC total supply
- Native C++ implementation in `/src/pocx/`
- Feature-flagged integration (`#ifdef ENABLE_POCX`)
- Time Bending algorithm for reduced block time variance
- Forging assignment system (OP_RETURN-based delegation)
- Dynamic compression scaling

**Network Status**:
- Mainnet: Not yet launched
- Testnet: Available for testing
- Regtest: Fully functional for development

---

## Mining

Bitcoin-PoCX uses external mining tools that connect via RPC:

1. **Generate plot files** using `pocx_plotter` ([reference implementation](https://github.com/PoC-Consortium/pocx/tree/master/pocx_plotter))
2. **Run Bitcoin-PoCX node** with `-miningserver` flag
3. **Connect miner** using `pocx_miner` ([reference implementation](https://github.com/PoC-Consortium/pocx/tree/master/pocx_miner))

See [Chapter 3: Consensus and Mining](docs/3-consensus-and-mining.md) and [Chapter 7: RPC Reference](docs/7-rpc-reference.md) for complete details.

---

## Development

### Build Commands

```bash
# Clone with submodules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git

# Build Bitcoin Core with PoCX
cd bitcoin-pocx/bitcoin
cmake -B build -DENABLE_POCX=ON
cmake --build build

# Run tests
./build/src/test/test_bitcoin
```

### Developer Resources

- **[CLAUDE.md](CLAUDE.md)** - Development guidelines
- **[Documentation](docs/index.md)** - Complete technical reference
- **[Bitcoin Core docs](bitcoin/doc/)** - Upstream Bitcoin Core documentation

---

## Project Information

**Bitcoin Core Base**: v30.0
**PoCX Framework**: [github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)
**Integration Repository**: [github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Attribution**:
- Plot format based on POC2 (Burstcoin) with security enhancements
- Miner based on [scavenger](https://github.com/PoC-Consortium/scavenger)
- Plotter based on [engraver](https://github.com/PoC-Consortium/engraver)

Full attribution in [Chapter 2: Plot Format](docs/2-plot-format.md).

---

## License

Bitcoin-PoCX inherits Bitcoin Core's MIT license. See [COPYING](bitcoin/COPYING) for details.

---

## Support

- **Documentation**: [docs/index.md](docs/index.md)
- **Issues**: [GitHub Issues](https://github.com/PoC-Consortium/bitcoin-pocx/issues)
- **Technical Questions**: See comprehensive documentation chapters

---

**Get Started**: [📘 Read the Documentation →](docs/index.md)

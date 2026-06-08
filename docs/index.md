# Bitcoin-PoCX Technical Documentation

**Version**: 1.0
**Bitcoin Core Base**: v30.2
**Status**: Mainnet Live (since 3 May 2026)
**Last Updated**: 2026-06-08

---

## About This Documentation

This is the complete technical documentation for Bitcoin-PoCX, a Bitcoin Core integration that adds Proof of Capacity neXt generation (PoCX) consensus support. The documentation is organized as a browseable guide with interconnected chapters covering all aspects of the system.

**Target Audiences**:
- **Node Operators**: Chapters 1, 5, 6, 8
- **Miners**: Chapters 2, 3, 7
- **Developers**: All chapters
- **Researchers**: Chapters 3, 4, 5




## Translations

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabic](translations/ara/index.md) | [🇧🇬 Bulgarian](translations/bul/index.md) | [🇨🇳 Chinese](translations/zho/index.md) | [🇨🇿 Czech](translations/ces/index.md) | [🇩🇰 Danish](translations/dan/index.md) | [🇳🇱 Dutch](translations/nld/index.md) |
| [🇪🇪 Estonian](translations/est/index.md) | [🇵🇭 Filipino](translations/fil/index.md) | [🇫🇮 Finnish](translations/fin/index.md) | [🇫🇷 French](translations/fra/index.md) | [🇩🇪 German](translations/deu/index.md) | [🇬🇷 Greek](translations/ell/index.md) |
| [🇮🇱 Hebrew](translations/heb/index.md) | [🇮🇳 Hindi](translations/hin/index.md) | [🇭🇺 Hungarian](translations/hun/index.md) | [🇮🇩 Indonesian](translations/ind/index.md) | [🇮🇹 Italian](translations/ita/index.md) | [🇯🇵 Japanese](translations/jpn/index.md) |
| [🇰🇷 Korean](translations/kor/index.md) | [🇱🇻 Latvian](translations/lav/index.md) | [🇱🇹 Lithuanian](translations/lit/index.md) | [🇳🇴 Norwegian](translations/nor/index.md) | [🇵🇱 Polish](translations/pol/index.md) | [🇵🇹 Portuguese](translations/por/index.md) |
| [🇷🇴 Romanian](translations/ron/index.md) | [🇷🇺 Russian](translations/rus/index.md) | [🇷🇸 Serbian](translations/srp/index.md) | [🇪🇸 Spanish](translations/spa/index.md) | [🇰🇪 Swahili](translations/swa/index.md) | [🇸🇪 Swedish](translations/swe/index.md) |
| [🇹🇷 Turkish](translations/tur/index.md) | [🇺🇦 Ukrainian](translations/ukr/index.md) | [🇻🇳 Vietnamese](translations/vie/index.md) | | | |


---

## Table of Contents

### Part I: Fundamentals

**[Chapter 1: Introduction and Overview](1-introduction.md)**
Project overview, architecture, design philosophy, key features, and how PoCX differs from Proof of Work.

**[Chapter 2: Plot File Format](2-plot-format.md)**
Complete specification of the PoCX plot format including SIMD optimization, proof-of-work scaling, and format evolution from POC1/POC2.

**[Chapter 3: Consensus and Mining](3-consensus-and-mining.md)**
Complete technical specification of PoCX consensus mechanism: block structure, generation signatures, base target adjustment, mining process, validation pipeline, and time bending algorithm.

---

### Part II: Advanced Features

**[Chapter 4: Forging Assignment System](4-forging-assignments.md)**
OP_RETURN-only architecture for delegating forging rights: transaction structure, database design, state machine, reorg handling, and RPC interface.

**[Chapter 5: Time Synchronization and Security](5-timing-security.md)**
Clock drift tolerance, defensive forging mechanism, anti-clock manipulation, and timing-related security considerations.

**[Chapter 6: Network Parameters](6-network-parameters.md)**
Chainparams configuration, genesis block, consensus parameters, coinbase rules, dynamic scaling, and economic model.

---

### Part III: Usage and Integration

**[Chapter 7: RPC Interface Reference](7-rpc-reference.md)**
Complete RPC command reference for mining, assignments, and blockchain queries. Essential for miner and pool integration.

**[Chapter 8: Wallet and GUI Guide](8-wallet-guide.md)**
User guide for Bitcoin-PoCX Qt wallet: forging assignment dialog, transaction history, mining setup, and troubleshooting.

---

## Quick Navigation

### For Node Operators
→ Start with [Chapter 1: Introduction](1-introduction.md)
→ Then review [Chapter 6: Network Parameters](6-network-parameters.md)
→ Configure mining with [Chapter 8: Wallet Guide](8-wallet-guide.md)

### For Miners
→ Understand [Chapter 2: Plot Format](2-plot-format.md)
→ Learn the process in [Chapter 3: Consensus and Mining](3-consensus-and-mining.md)
→ Integrate using [Chapter 7: RPC Reference](7-rpc-reference.md)

### For Pool Operators
→ Review [Chapter 4: Forging Assignments](4-forging-assignments.md)
→ Study [Chapter 7: RPC Reference](7-rpc-reference.md)
→ Implement using assignment RPCs and submit_nonce

### For Developers
→ Read all chapters sequentially
→ Cross-reference implementation files noted throughout
→ Examine `src/pocx/` directory structure
→ Build releases with [GUIX](../bitcoin/contrib/guix/README.md)

---

## Documentation Conventions

**File References**: Implementation details reference source files as `path/to/file.cpp:line`

**Code Integration**: All changes are feature-flagged with `#ifdef ENABLE_POCX`

**Cross-References**: Chapters link to related sections using relative markdown links

**Technical Level**: Documentation assumes familiarity with Bitcoin Core and C++ development

---

## Building

### Development Build

```bash
# Clone with submodules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configure
cmake -B build

# Build
cmake --build build -j$(nproc)
```

**Build Variants**:
```bash
# With Qt GUI
cmake -B build -DBUILD_GUI=ON

# Debug build
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

**Dependencies**: Standard Bitcoin Core build dependencies. See [Bitcoin Core build documentation](https://github.com/bitcoin/bitcoin/tree/master/doc#building) for platform-specific requirements.

### Release Builds

For reproducible release binaries, use the GUIX build system: See [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Additional Resources

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Related Projects**:
- Plotter: Based on [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Based on [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## How to Read This Documentation

**Sequential Reading**: Chapters are designed to be read in order, building upon previous concepts.

**Reference Reading**: Use the table of contents to jump directly to specific topics. Each chapter is self-contained with cross-references to related material.

**Browser Navigation**: Open `index.md` in a markdown viewer or browser. All internal links are relative and work offline.

**PDF Export**: This documentation can be concatenated into a single PDF for offline reading.

---

## Project Status

**✅ Feature Complete**: All consensus rules, mining, assignments, and wallet features implemented.

**✅ Documentation Complete**: All 8 chapters complete and verified against codebase.

**🚀 Mainnet Live**: Mainnet has been live since 3 May 2026.

---

## Contributing

Contributions to documentation are welcome. Please maintain:
- Technical accuracy over verbosity
- Brief, to-the-point explanations
- No code or pseudo-code in documentation (reference source files instead)
- As-implemented only (no speculative features)

---

## License

Bitcoin-PoCX inherits Bitcoin Core's MIT license. See `bitcoin/COPYING` in repository root.

PoCX core framework attribution documented in [Chapter 2: Plot Format](2-plot-format.md).

---

**Begin Reading**: [Chapter 1: Introduction and Overview →](1-introduction.md)

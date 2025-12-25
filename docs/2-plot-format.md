[← Previous: Introduction](1-introduction.md) | [📘 Table of Contents](index.md) | [Next: Consensus and Mining →](3-consensus-and-mining.md)

---

# Chapter 2: PoCX Plot Format Specification

This document describes the PoCX plot format, an enhanced version of the POC2 format with improved security, SIMD optimizations, and scalable proof-of-work.

## Format Overview

PoCX plot files contain pre-computed Shabal256 hash values organized for efficient mining operations. Following the PoC tradition since POC1, **all metadata is embedded in the filename** - there is no file header.

### File Extension
- **Standard**: `.pocx` (completed plots)
- **In Progress**: `.tmp` (during plotting, renamed to `.pocx` when complete)

## Historical Context and Vulnerability Evolution

### POC1 Format (Legacy)
**Two Major Vulnerabilities (Time-Memory Tradeoffs):**

1. **PoW Distribution Flaw** 
   - Non-uniform distribution of proof-of-work across scoops
   - Low scoop numbers could be calculated on-the-fly
   - **Impact**: Reduced storage requirements for attackers

2. **XOR Compression Attack** (50% Time-Memory Tradeoff)
   - Exploited mathematical properties to achieve 50% storage reduction
   - **Impact**: Attackers could mine with half the required storage

**Layout Optimization**: Basic sequential scoop layout for HDD efficiency

### POC2 Format (Burstcoin)
- ✅ **Fixed PoW distribution flaw**
- ❌ **XOR-transpose vulnerability remained unpatched**
- **Layout**: Maintained sequential scoop optimization

### PoCX Format (Current)
- ✅ **Fixed PoW distribution** (inherited from POC2)
- ✅ **Patched XOR-transpose vulnerability** (unique to PoCX)
- ✅ **Enhanced SIMD/GPU layout** optimized for parallel processing and memory coalescing
- ✅ **Scalable proof-of-work** prevents time–memory tradeoffs as computation power grows (PoW is performed only when creating or upgrading plotfiles)

## XOR-Transpose Encoding

### The Problem: 50% Time-Memory Tradeoff

In POC1/POC2 formats, attackers could exploit the mathematical relationship between scoops to store only half the data and compute the rest on-the-fly during mining. This "XOR compression attack" undermined the storage guarantee.

### The Solution: XOR-Transpose Hardening

PoCX derives its mining format (X1) by applying XOR-transpose encoding to pairs of base warps (X0):

**To construct scoop S of nonce N in an X1 warp:**
1. Take scoop S of nonce N from the first X0 warp (direct position)
2. Take scoop N of nonce S from the second X0 warp (transposed position)
3. XOR the two 64-byte values to obtain the X1 scoop

The transpose step swaps scoop and nonce indices. In matrix terms—where rows represent scoops and columns represent nonces—it combines the element at position (S, N) in the first warp with the element at (N, S) in the second.

### Why This Eliminates the Attack

The XOR-transpose interlocks each scoop with an entire row and an entire column of the underlying X0 data. Recovering a single X1 scoop requires access to data spanning all 4096 scoop indices. Any attempt to compute missing data would require regenerating 4096 full nonces rather than a single nonce—removing the asymmetric cost structure exploited by the XOR attack.

As a result, storing the full X1 warp becomes the only computationally viable strategy for miners.

## Filename Metadata Structure

All plot metadata is encoded in the filename using this exact format:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Filename Components

1. **ACCOUNT_PAYLOAD** (40 hex characters)
   - Raw 20-byte account payload as uppercase hex
   - Network-independent (no network ID or checksum)
   - Example: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex characters)  
   - 32-byte seed value as lowercase hex
   - **New in PoCX**: Random 32-byte seed in filename replaces consecutive nonce numbering — preventing plot overlaps
   - Example: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimal number)
   - **NEW size unit in PoCX**: Replaces nonce-based sizing from POC1/POC2
   - **XOR-transpose resistant design**: Each warp = exactly 4096 nonces (partition size required for XOR-transpose resistant transformation)
   - **Size**: 1 warp = 1073741824 bytes = 1 GiB (convenient unit)
   - Example: `1024` (1 TiB plot = 1024 warps)

4. **SCALING** (X-prefixed decimal)
   - Scaling level as `X{level}`
   - Higher values = more proof-of-work required
   - Example: `X4` (2^4 = 16× POC2 difficulty)

### Example Filenames
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## File Layout and Data Structure

### Hierarchical Organization
```
Plot File (NO HEADER)
├── Scoop 0
│   ├── Warp 0 (All nonces for this scoop/warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Constants and Sizes

| Constant        | Size                    | Description                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Single Shabal256 hash output                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Hash pair read in a mining round                |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops per nonce; one selected per round        |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | All scoops of a nonce (PoC1/PoC2 smallest unit) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Smallest unit in PoCX                           |

### SIMD-Optimized Plot File Layout

PoCX implements a SIMD-aware nonce access pattern that enables vectorized processing 
of multiple nonces simultaneously. It builds on concepts from [POC2×16 optimization 
research](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) to maximize memory throughput and SIMD efficiency.

---

#### Traditional Sequential Layout

Sequential storage of nonces:

```
[Nonce 0: Scoop Data] [Nonce 1: Scoop Data] [Nonce 2: Scoop Data] ...
```

SIMD inefficiency: Each SIMD lane needs the same word across nonces:

```
Word 0 from Nonce 0 -> offset 0
Word 0 from Nonce 1 -> offset 512
Word 0 from Nonce 2 -> offset 1024
...
```

Scatter-gather access reduces throughput.

---

#### PoCX SIMD-Optimized Layout

PoCX stores **word positions across 16 nonces** contiguously:

```
Cache Line (64 bytes):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII Diagram**

```
Traditional layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX layout:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Memory Access Benefits

- One cache line supplies all SIMD lanes.
- Eliminates scatter-gather operations.
- Reduces cache misses.
- Fully sequential memory access for vectorized computation.
- GPUs also gain from 16-nonce alignment, maximizing cache efficiency.

---

#### SIMD Scaling

| SIMD       | Vector Width* | Nonces | Processing Cycles per Cache Line |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 cycles                        |
| AVX2       | 256-bit       | 8      | 2 cycles                        |
| AVX512     | 512-bit       | 16     | 1 cycle                         |

\* For integer operations

---



## Proof-of-Work Scaling

### Scaling Levels
- **X0**: Base nonces without XOR-transpose encoding (theoretical, not used for mining)
- **X1**: XOR-transpose baseline—first hardened format (1× work)
- **X2**: 2× X1 work (XOR across 2 warps)
- **X3**: 4× X1 work (XOR across 4 warps)
- **…**
- **Xn**: 2^(n-1) × X1 work embedded

### Benefits
- **Adjustable PoW difficulty**: Increases computational requirements to keep up with faster hardware
- **Format longevity**: Enables flexible scaling of mining difficulty over time

### Plot Upgrade / Backward Compatibility

When the network increases the PoW (Proof of Work) scale by 1, existing plots require an upgrade to maintain the same effective plot size. Essentially, you now need twice the PoW in your plot files to achieve the same contribution to your account.

The good news is that the PoW you have already completed when creating your plot files is not lost—you simply need to add additional PoW to the existing files. No need to replot. 

Alternatively, you may continue using your current plots without upgrading, but note that they will now only contribute 50% of their previous effective size toward your account. Your mining software can scale a plotfile on-the-fly.

## Comparison with Legacy Formats

| Feature | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW Distribution | ❌ Flawed | ✅ Fixed | ✅ Fixed |
| XOR-Transpose Resistance | ❌ Vulnerable | ❌ Vulnerable | ✅ Fixed |
| SIMD Optimization | ❌ None | ❌ None | ✅ Advanced |
| GPU Optimization | ❌ None | ❌ None | ✅ Optimized |
| Scalable Proof-of-Work | ❌ None | ❌ None | ✅ Yes |
| Seed Support | ❌ None | ❌ None | ✅ Yes |

The PoCX format represents the current state-of-the-art in Proof of Capacity plot formats, addressing all known vulnerabilities while providing significant performance improvements for modern hardware.

## References and Further Reading

- **POC1/POC2 Background**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Comprehensive guide to traditional Proof of Capacity mining formats
- **POC2×16 Research**: [CIP Announcement: POC2×16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Original SIMD optimization research that inspired PoCX
- **Shabal Hash Algorithm**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Technical specification of the Shabal256 algorithm used in PoC mining

---

[← Previous: Introduction](1-introduction.md) | [📘 Table of Contents](index.md) | [Next: Consensus and Mining →](3-consensus-and-mining.md)


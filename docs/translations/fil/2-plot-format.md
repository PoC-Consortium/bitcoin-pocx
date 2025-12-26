[← Nakaraan: Panimula](1-introduction.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Consensus at Mining →](3-consensus-and-mining.md)

---

# Kabanata 2: Ispesipikasyon ng PoCX Plot Format

Inilalarawan ng dokumentong ito ang format ng PoCX plot, isang pinahusay na bersyon ng POC2 format na may pinahusay na seguridad, mga SIMD optimization, at scalable proof-of-work.

## Pangkalahatang-tanaw ng Format

Ang mga PoCX plot file ay naglalaman ng mga pre-computed Shabal256 hash value na nakaayos para sa mahusay na mga operasyon ng mining. Kasunod ng tradisyon ng PoC mula pa noong POC1, **lahat ng metadata ay naka-embed sa filename** - walang file header.

### File Extension
- **Standard**: `.pocx` (mga natapos na plot)
- **In Progress**: `.tmp` (habang nagplo-plot, pinalitan ng pangalan sa `.pocx` kapag kumpleto)

## Makasaysayang Konteksto at Ebolusyon ng Vulnerability

### POC1 Format (Legacy)
**Dalawang Pangunahing Vulnerability (Mga Time-Memory Tradeoff):**

1. **PoW Distribution Flaw**
   - Hindi pantay na distribusyon ng proof-of-work sa mga scoop
   - Ang mga mababang scoop number ay maaaring kalkulahin nang on-the-fly
   - **Epekto**: Nabawasang mga kinakailangan sa storage para sa mga attacker

2. **XOR Compression Attack** (50% Time-Memory Tradeoff)
   - Sinamantala ang mga mathematical property upang makamit ang 50% na pagbawas sa storage
   - **Epekto**: Ang mga attacker ay maaaring mag-mine gamit ang kalahati ng kinakailangang storage

**Layout Optimization**: Pangunahing sequential scoop layout para sa kahusayan ng HDD

### POC2 Format (Burstcoin)
- ✅ **Naayos ang PoW distribution flaw**
- ❌ **Nananatiling hindi na-patch ang XOR-transpose vulnerability**
- **Layout**: Pinanatili ang sequential scoop optimization

### PoCX Format (Kasalukuyan)
- ✅ **Naayos na PoW distribution** (minana mula sa POC2)
- ✅ **Na-patch ang XOR-transpose vulnerability** (natatangi sa PoCX)
- ✅ **Pinahusay na SIMD/GPU layout** na na-optimize para sa parallel processing at memory coalescing
- ✅ **Scalable proof-of-work** na pumipigil sa mga time-memory tradeoff habang lumalaki ang computational power (ginagawa lamang ang PoW kapag gumagawa o nag-a-upgrade ng mga plotfile)

## XOR-Transpose Encoding

### Ang Problema: 50% Time-Memory Tradeoff

Sa mga format ng POC1/POC2, ang mga attacker ay maaaring samantalahin ang mathematical na relasyon sa pagitan ng mga scoop upang mag-imbak ng kalahati lamang ng data at kalkulahin ang natitira nang on-the-fly sa panahon ng mining. Ang "XOR compression attack" na ito ay sumira sa garantiya ng storage.

### Ang Solusyon: XOR-Transpose Hardening

Kinukuha ng PoCX ang mining format nito (X1) sa pamamagitan ng pag-apply ng XOR-transpose encoding sa mga pares ng base warp (X0):

**Upang buuin ang scoop S ng nonce N sa isang X1 warp:**
1. Kunin ang scoop S ng nonce N mula sa unang X0 warp (direktang posisyon)
2. Kunin ang scoop N ng nonce S mula sa pangalawang X0 warp (transposed na posisyon)
3. I-XOR ang dalawang 64-byte na halaga upang makuha ang X1 scoop

Ang transpose step ay nagpapalit ng mga scoop at nonce index. Sa mga termino ng matrix—kung saan ang mga row ay kumakatawan sa mga scoop at ang mga column ay kumakatawan sa mga nonce—pinagsasama nito ang elemento sa posisyon (S, N) sa unang warp kasama ang elemento sa (N, S) sa pangalawa.

### Bakit Ito Nag-aalis ng Attack

Ang XOR-transpose ay nag-i-interlock ng bawat scoop sa isang buong row at isang buong column ng underlying X0 data. Ang pag-recover ng isang solong X1 scoop ay nangangailangan ng access sa data na sumasaklaw sa lahat ng 4096 scoop index. Anumang pagtatangkang kalkulahin ang nawawalang data ay mangangailangan ng pag-regenerate ng 4096 buong nonce sa halip na isang solong nonce—inaalis ang asymmetric cost structure na sinamantala ng XOR attack.

Bilang resulta, ang pag-iimbak ng buong X1 warp ang nagiging tanging computationally viable na estratehiya para sa mga miner.

## Istruktura ng Filename Metadata

Lahat ng plot metadata ay naka-encode sa filename gamit ang eksaktong format na ito:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Mga Komponent ng Filename

1. **ACCOUNT_PAYLOAD** (40 hex character)
   - Raw 20-byte account payload bilang uppercase hex
   - Hindi nakadepende sa network (walang network ID o checksum)
   - Halimbawa: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex character)
   - 32-byte seed value bilang lowercase hex
   - **Bago sa PoCX**: Random 32-byte seed sa filename na pumapalit sa consecutive nonce numbering — pumipigil sa mga overlap ng plot
   - Halimbawa: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimal number)
   - **BAGONG unit ng laki sa PoCX**: Pumapalit sa nonce-based sizing mula sa POC1/POC2
   - **XOR-transpose resistant na disenyo**: Bawat warp = eksaktong 4096 nonce (laki ng partition na kinakailangan para sa XOR-transpose resistant transformation)
   - **Laki**: 1 warp = 1073741824 byte = 1 GiB (maginhawang unit)
   - Halimbawa: `1024` (1 TiB plot = 1024 warp)

4. **SCALING** (X-prefixed decimal)
   - Scaling level bilang `X{level}`
   - Mas mataas na halaga = mas maraming proof-of-work na kinakailangan
   - Halimbawa: `X4` (2^4 = 16× POC2 difficulty)

### Mga Halimbawa ng Filename
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## File Layout at Istruktura ng Data

### Hierarchical na Organisasyon
```
Plot File (WALANG HEADER)
├── Scoop 0
│   ├── Warp 0 (Lahat ng nonce para sa scoop/warp na ito)
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

### Mga Constant at Laki

| Constant        | Laki                    | Paglalarawan                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Isang Shabal256 hash output                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Hash pair na binabasa sa isang mining round                |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Mga scoop bawat nonce; isa ang pinipili bawat round        |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Lahat ng scoop ng isang nonce (pinakamaliit na unit ng PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Pinakamaliit na unit sa PoCX                           |

### SIMD-Optimized Plot File Layout

Nagpapatupad ang PoCX ng SIMD-aware na nonce access pattern na nagpapagana ng vectorized processing
ng maraming nonce nang sabay-sabay. Ito ay bumubuo sa mga konsepto mula sa [POC2×16 optimization
research](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) upang i-maximize ang memory throughput at SIMD efficiency.

---

#### Tradisyunal na Sequential Layout

Sequential storage ng mga nonce:

```
[Nonce 0: Scoop Data] [Nonce 1: Scoop Data] [Nonce 2: Scoop Data] ...
```

SIMD inefficiency: Ang bawat SIMD lane ay nangangailangan ng parehong word sa mga nonce:

```
Word 0 mula Nonce 0 -> offset 0
Word 0 mula Nonce 1 -> offset 512
Word 0 mula Nonce 2 -> offset 1024
...
```

Ang scatter-gather access ay nagpapababa ng throughput.

---

#### PoCX SIMD-Optimized Layout

Ang PoCX ay nag-iimbak ng **mga word position sa 16 nonce** nang magkakadikit:

```
Cache Line (64 bytes):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII Diagram**

```
Tradisyunal na layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX layout:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Mga Benepisyo ng Memory Access

- Isang cache line ang nagsu-supply sa lahat ng SIMD lane.
- Inaalis ang mga scatter-gather operation.
- Binabawasan ang mga cache miss.
- Ganap na sequential memory access para sa vectorized computation.
- Ang mga GPU ay nakikinabang din sa 16-nonce alignment, na nag-maximize ng cache efficiency.

---

#### SIMD Scaling

| SIMD       | Vector Width* | Mga Nonce | Processing Cycle bawat Cache Line |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 na cycle                        |
| AVX2       | 256-bit       | 8      | 2 cycle                        |
| AVX512     | 512-bit       | 16     | 1 cycle                         |

\* Para sa mga integer operation

---



## Proof-of-Work Scaling

### Mga Scaling Level
- **X0**: Base nonce na walang XOR-transpose encoding (teoretikal, hindi ginagamit para sa mining)
- **X1**: XOR-transpose baseline—unang hardened format (1× work)
- **X2**: 2× X1 work (XOR sa 2 warp)
- **X3**: 4× X1 work (XOR sa 4 warp)
- **...**
- **Xn**: 2^(n-1) × X1 work na naka-embed

### Mga Benepisyo
- **Adjustable PoW difficulty**: Pinapataas ang mga computational requirement upang makasabay sa mas mabilis na hardware
- **Matagal na format**: Nagpapagana ng flexible na pag-scale ng mining difficulty sa paglipas ng panahon

### Pag-upgrade ng Plot / Backward Compatibility

Kapag pinapataas ng network ang PoW (Proof of Work) scale ng 1, ang mga kasalukuyang plot ay nangangailangan ng upgrade upang mapanatili ang parehong epektibong laki ng plot. Sa esensya, kailangan mo na ngayon ng doble ng PoW sa iyong mga plot file upang makamit ang parehong kontribusyon sa iyong account.

Ang magandang balita ay ang PoW na natapos mo na noong gumagawa ng iyong mga plot file ay hindi nawawala—kailangan mo lamang magdagdag ng karagdagang PoW sa mga kasalukuyang file. Hindi kailangang mag-replot.

Bilang alternatibo, maaari mong patuloy na gamitin ang iyong mga kasalukuyang plot nang hindi nag-a-upgrade, ngunit tandaan na magko-contribute na lamang sila ng 50% ng kanilang nakaraang epektibong laki patungo sa iyong account. Maaaring i-scale ng iyong mining software ang isang plotfile nang on-the-fly.

## Paghahambing sa mga Legacy Format

| Tampok | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW Distribution | ❌ May Depekto | ✅ Naayos | ✅ Naayos |
| XOR-Transpose Resistance | ❌ Vulnerable | ❌ Vulnerable | ✅ Naayos |
| SIMD Optimization | ❌ Wala | ❌ Wala | ✅ Advanced |
| GPU Optimization | ❌ Wala | ❌ Wala | ✅ Na-optimize |
| Scalable Proof-of-Work | ❌ Wala | ❌ Wala | ✅ Oo |
| Seed Support | ❌ Wala | ❌ Wala | ✅ Oo |

Ang format ng PoCX ay kumakatawan sa kasalukuyang state-of-the-art sa mga format ng Proof of Capacity plot, na nagtutugon sa lahat ng mga kilalang vulnerability habang nagbibigay ng makabuluhang mga pagpapabuti sa performance para sa modernong hardware.

## Mga Sanggunian at Karagdagang Pagbabasa

- **POC1/POC2 Background**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Komprehensibong gabay sa mga tradisyunal na format ng Proof of Capacity mining
- **POC2×16 Research**: [CIP Announcement: POC2×16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Orihinal na SIMD optimization research na naging inspirasyon ng PoCX
- **Shabal Hash Algorithm**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Teknikal na ispesipikasyon ng Shabal256 algorithm na ginagamit sa PoC mining

---

[← Nakaraan: Panimula](1-introduction.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Consensus at Mining →](3-consensus-and-mining.md)

[📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Format ng Plot →](2-plot-format.md)

---

# Kabanata 1: Panimula at Pangkalahatang-tanaw

## Ano ang Bitcoin-PoCX?

Ang Bitcoin-PoCX ay isang integrasyon sa Bitcoin Core na nagdadagdag ng suporta para sa **Proof of Capacity neXt generation (PoCX)** na consensus. Pinapanatili nito ang kasalukuyang arkitektura ng Bitcoin Core habang pinapagana ang isang energy-efficient na alternatibong Proof of Capacity mining bilang kumpletong kapalit ng Proof of Work.

**Mahalagang Pagkakaiba**: Ito ay isang **bagong chain** na walang backward compatibility sa Bitcoin PoW. Ang mga PoCX block ay hindi compatible sa mga PoW node ayon sa disenyo.

---

## Pagkakakilanlan ng Proyekto

- **Organisasyon**: Proof of Capacity Consortium
- **Pangalan ng Proyekto**: Bitcoin-PoCX
- **Buong Pangalan**: Bitcoin Core na may PoCX Integration
- **Katayuan**: Yugto ng Testnet

---

## Ano ang Proof of Capacity?

Ang Proof of Capacity (PoC) ay isang mekanismo ng consensus kung saan ang kapangyarihan sa mining ay proporsyonal sa **espasyo ng disk** sa halip na computational power. Ang mga miner ay nag-pre-generate ng malalaking plot file na naglalaman ng mga cryptographic hash, pagkatapos ay ginagamit ang mga plot na ito upang humanap ng mga valid na solusyon sa block.

**Kahusayan sa Enerhiya**: Ang mga plot file ay nalilikha nang isang beses at ginagamit ulit nang walang hanggan. Ang mining ay kumukonsumo ng kaunting CPU power—pangunahin ay disk I/O lamang.

**Mga Pagpapahusay ng PoCX**:
- Naayos ang XOR-transpose compression attack (50% time-memory tradeoff sa POC2)
- 16-nonce-aligned na layout para sa modernong hardware
- Scalable proof-of-work sa plot generation (mga Xn scaling level)
- Native C++ integration direkta sa Bitcoin Core
- Time Bending algorithm para sa pinahusay na distribusyon ng block time

---

## Pangkalahatang-tanaw ng Arkitektura

### Istruktura ng Repository

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX integration
│   └── src/pocx/        # PoCX implementation
├── pocx/                # PoCX core framework (submodule, read-only)
└── docs/                # Ang dokumentasyong ito
```

### Pilosopiya ng Integrasyon

**Minimal na Integration Surface**: Ang mga pagbabago ay nakahiwalay sa direktoryo ng `/src/pocx/` na may malinis na mga hook sa Bitcoin Core validation, mining, at RPC layer.

**Feature Flagging**: Lahat ng modipikasyon ay nasa ilalim ng `#ifdef ENABLE_POCX` preprocessor guard. Normal na nagbu-build ang Bitcoin Core kapag naka-disable.

**Upstream Compatibility**: Regular na pag-sync sa mga update ng Bitcoin Core na pinapanatili sa pamamagitan ng mga nakahiwalay na integration point.

**Native C++ Implementation**: Ang mga scalar cryptographic algorithm (Shabal256, scoop calculation, compression) ay direktang naka-integrate sa Bitcoin Core para sa consensus validation.

---

## Mga Pangunahing Tampok

### 1. Kumpletong Pagpapalit ng Consensus

- **Istruktura ng Block**: Ang mga field na tiyak sa PoCX ay pumapalit sa PoW nonce at difficulty bits
  - Generation signature (deterministic mining entropy)
  - Base target (kabaligtaran ng difficulty)
  - PoCX proof (account ID, seed, nonce)
  - Block signature (nagpapatunay ng pagmamay-ari ng plot)

- **Validation**: 5-yugto na validation pipeline mula sa header check hanggang block connection

- **Pagsasaayos ng Difficulty**: Bawat-block na pagsasaayos gamit ang moving average ng mga kamakailang base target

### 2. Time Bending Algorithm

**Problema**: Ang tradisyunal na PoC block time ay sumusunod sa exponential distribution, na humahantong sa mahabang mga block kapag walang miner ang nakahanap ng magandang solusyon.

**Solusyon**: Pagbabago ng distribution mula exponential patungong chi-squared gamit ang cube root: `Y = scale × (X^(1/3))`.

**Epekto**: Ang mga napakagandang solusyon ay nag-fo-forge ng mas huli (ang network ay may oras na i-scan ang lahat ng disk, binabawasan ang mabibilis na block), ang mga mahinang solusyon ay napapabuti. Average na block time na napapanatili sa 120 segundo, nabawasan ang mahabang mga block.

**Detalye**: [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md)

### 3. Sistema ng Forging Assignment

**Kakayahan**: Ang mga may-ari ng plot ay maaaring magdelega ng mga karapatan sa forging sa ibang mga address habang pinapanatili ang pagmamay-ari ng plot.

**Mga Kaso ng Paggamit**:
- Pool mining (ang mga plot ay nag-a-assign sa pool address)
- Cold storage (ang mining key ay hiwalay sa pagmamay-ari ng plot)
- Multi-party mining (shared infrastructure)

**Arkitektura**: OP_RETURN-only na disenyo—walang espesyal na UTXO, ang mga assignment ay sinusubaybayan nang hiwalay sa chainstate database.

**Detalye**: [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md)

### 4. Defensive Forging

**Problema**: Ang mabilis na mga orasan ay maaaring magbigay ng timing advantage sa loob ng 15-segundo na future tolerance.

**Solusyon**: Kapag nakatanggap ng nakikipagkumpitensyang block sa parehong taas, awtomatikong suriin ang lokal na kalidad. Kung mas mabuti, mag-forge kaagad.

**Epekto**: Inaalis ang insentibo para sa clock manipulation—ang mabilis na mga orasan ay tumutulong lamang kung mayroon ka nang pinakamahusay na solusyon.

**Detalye**: [Kabanata 5: Seguridad sa Timing](5-timing-security.md)

### 5. Dynamic Compression Scaling

**Pagkakahanay sa Ekonomiya**: Ang mga kinakailangan sa scaling level ay tumataas sa exponential na iskedyul (Taon 4, 12, 28, 60, 124 = halving 1, 3, 7, 15, 31).

**Epekto**: Habang bumababa ang mga block reward, tumataas ang difficulty ng plot generation. Pinapanatili ang safety margin sa pagitan ng plot creation at lookup cost.

**Pinipigilan**: Capacity inflation mula sa mas mabilis na hardware sa paglipas ng panahon.

**Detalye**: [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md)

---

## Pilosopiya ng Disenyo

### Kaligtasan ng Code

- Mga defensive programming practice sa buong sistema
- Komprehensibong error handling sa mga validation path
- Walang nested lock (deadlock prevention)
- Mga atomic na database operation (UTXO + assignment nang magkasama)

### Modular na Arkitektura

- Malinis na paghihiwalay sa pagitan ng Bitcoin Core infrastructure at PoCX consensus
- Ang PoCX core framework ay nagbibigay ng mga cryptographic primitive
- Ang Bitcoin Core ay nagbibigay ng validation framework, database, networking

### Mga Pag-optimize sa Performance

- Fast-fail na pagkakasunud-sunod ng validation (murang mga pagsusuri muna)
- Isang context fetch bawat submission (walang paulit-ulit na cs_main acquisition)
- Mga atomic na database operation para sa consistency

### Kaligtasan sa Reorg

- Buong undo data para sa mga pagbabago sa assignment state
- Pag-reset ng forging state sa mga pagbabago ng chain tip
- Staleness detection sa lahat ng validation point

---

## Paano Naiiba ang PoCX sa Proof of Work

| Aspeto | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Mapagkukunan sa Mining** | Computational power (hash rate) | Espasyo ng disk (kapasidad) |
| **Pagkonsumo ng Enerhiya** | Mataas (tuloy-tuloy na hashing) | Mababa (disk I/O lamang) |
| **Proseso ng Mining** | Maghanap ng nonce na may hash < target | Maghanap ng nonce na may deadline < lumipas na oras |
| **Difficulty** | field ng `bits`, inaayos bawat 2016 block | field ng `base_target`, inaayos bawat block |
| **Block Time** | ~10 minuto (exponential distribution) | 120 segundo (time-bended, nabawasang variance) |
| **Subsidy** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Hardware** | ASIC (espesyalisado) | HDD (commodity hardware) |
| **Pagkakakilanlan sa Mining** | Anonymous | May-ari ng plot o delegado |

---

## Mga Kinakailangan ng Sistema

### Pagpapatakbo ng Node

**Pareho sa Bitcoin Core**:
- **CPU**: Modernong x86_64 processor
- **Memorya**: 4-8 GB RAM
- **Storage**: Bagong chain, kasalukuyang walang laman (maaaring lumaki ng ~4× na mas mabilis kaysa Bitcoin dahil sa 2-minutong mga block at assignment database)
- **Network**: Matatag na koneksyon sa internet
- **Orasan**: Inirerekomenda ang NTP synchronization para sa optimal na operasyon

**Tandaan**: Ang mga plot file ay HINDI kinakailangan para sa pagpapatakbo ng node.

### Mga Kinakailangan sa Mining

**Karagdagang mga kinakailangan para sa mining**:
- **Mga Plot File**: Naka-pre-generate gamit ang `pocx_plotter` (reference implementation)
- **Miner Software**: Ang `pocx_miner` (reference implementation) ay kumokonekta sa pamamagitan ng RPC
- **Wallet**: `bitcoind` o `bitcoin-qt` na may mga private key para sa mining address. Ang pool mining ay hindi nangangailangan ng lokal na wallet.

---

## Pagsisimula

### 1. Buuin ang Bitcoin-PoCX

```bash
# I-clone kasama ang mga submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Buuin na naka-enable ang PoCX
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detalye**: Tingnan ang `CLAUDE.md` sa root ng repository

### 2. Patakbuhin ang Node

**Node lamang**:
```bash
./build/bin/bitcoind
# o
./build/bin/bitcoin-qt
```

**Para sa mining** (pinapagana ang RPC access para sa mga external miner):
```bash
./build/bin/bitcoind -miningserver
# o
./build/bin/bitcoin-qt -server -miningserver
```

**Detalye**: [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md)

### 3. Gumawa ng mga Plot File

Gamitin ang `pocx_plotter` (reference implementation) upang mag-generate ng mga PoCX-format na plot file.

**Detalye**: [Kabanata 2: Format ng Plot](2-plot-format.md)

### 4. I-setup ang Mining

Gamitin ang `pocx_miner` (reference implementation) upang kumonekta sa RPC interface ng iyong node.

**Detalye**: [Kabanata 7: Sanggunian ng RPC](7-rpc-reference.md) at [Kabanata 8: Gabay sa Wallet](8-wallet-guide.md)

---

## Attribution

### Format ng Plot

Batay sa POC2 format (Burstcoin) na may mga pagpapahusay:
- Naayos ang security flaw (XOR-transpose compression attack)
- Scalable proof-of-work
- SIMD-optimized na layout
- Seed functionality

### Mga Source Project

- **pocx_miner**: Reference implementation na batay sa [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Reference implementation na batay sa [engraver](https://github.com/PoC-Consortium/engraver)

**Buong Attribution**: [Kabanata 2: Format ng Plot](2-plot-format.md)

---

## Buod ng mga Teknikal na Ispesipikasyon

- **Block Time**: 120 segundo (mainnet), 1 segundo (regtest)
- **Block Subsidy**: 10 BTC initial, nagha-halving bawat 1050000 block (~4 na taon)
- **Kabuuang Supply**: ~21 milyong BTC (pareho sa Bitcoin)
- **Future Tolerance**: 15 segundo (mga block na hanggang 15s nang maaga ay tinatanggap)
- **Clock Warning**: 10 segundo (nagbabala sa mga operator tungkol sa time drift)
- **Assignment Delay**: 30 block (~1 oras)
- **Revocation Delay**: 720 block (~24 oras)
- **Format ng Address**: P2WPKH (bech32, pocx1q...) lamang para sa mga operasyon ng PoCX mining at forging assignment

---

## Organisasyon ng Code

**Mga Modipikasyon sa Bitcoin Core**: Minimal na mga pagbabago sa mga core file, may feature-flag na `#ifdef ENABLE_POCX`

**Bagong PoCX Implementation**: Nakahiwalay sa direktoryo ng `src/pocx/`

---

## Mga Konsiderasyon sa Seguridad

### Seguridad sa Timing

- Ang 15-segundong future tolerance ay pumipigil sa network fragmentation
- Ang 10-segundong warning threshold ay nagbabala sa mga operator tungkol sa clock drift
- Ang defensive forging ay nag-aalis ng insentibo para sa clock manipulation
- Ang Time Bending ay nagpapababa ng epekto ng timing variance

**Detalye**: [Kabanata 5: Seguridad sa Timing](5-timing-security.md)

### Seguridad ng Assignment

- OP_RETURN-only na disenyo (walang UTXO manipulation)
- Ang transaction signature ay nagpapatunay ng pagmamay-ari ng plot
- Ang mga activation delay ay pumipigil sa mabilis na state manipulation
- Reorg-safe na undo data para sa lahat ng state change

**Detalye**: [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md)

### Seguridad ng Consensus

- Ang signature ay hindi kasama sa block hash (pumipigil sa malleability)
- Mga bounded signature size (pumipigil sa DoS)
- Compression bounds validation (pumipigil sa mga mahinang proof)
- Bawat-block na pagsasaayos ng difficulty (tumutugon sa mga pagbabago ng kapasidad)

**Detalye**: [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md)

---

## Katayuan ng Network

**Mainnet**: Hindi pa nalulunsad
**Testnet**: Available para sa pagsubok
**Regtest**: Ganap na gumagana para sa development

**Mga Parameter ng Genesis Block**: [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md)

---

## Mga Susunod na Hakbang

**Para sa Pag-unawa sa PoCX**: Magpatuloy sa [Kabanata 2: Format ng Plot](2-plot-format.md) upang matutunan ang tungkol sa istruktura at ebolusyon ng format ng plot file.

**Para sa Pag-setup ng Mining**: Pumunta sa [Kabanata 7: Sanggunian ng RPC](7-rpc-reference.md) para sa mga detalye ng integrasyon.

**Para sa Pagpapatakbo ng Node**: Suriin ang [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md) para sa mga opsyon sa configuration.

---

[📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Format ng Plot →](2-plot-format.md)

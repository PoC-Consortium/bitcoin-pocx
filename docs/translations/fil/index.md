# Teknikal na Dokumentasyon ng Bitcoin-PoCX

**Bersyon**: 1.0
**Base ng Bitcoin Core**: v30.0
**Katayuan**: Yugto ng Testnet
**Huling Pagbabago**: 2025-12-25

---

## Tungkol sa Dokumentasyong Ito

Ito ang kumpletong teknikal na dokumentasyon para sa Bitcoin-PoCX, isang integrasyon sa Bitcoin Core na nagdadagdag ng suporta para sa Proof of Capacity neXt generation (PoCX) na consensus. Ang dokumentasyon ay nakaayos bilang isang gabay na may magkakaugnay na mga kabanata na sumasaklaw sa lahat ng aspeto ng sistema.

**Mga Target na Mambabasa**:
- **Mga Tagapagpatakbo ng Node**: Kabanata 1, 5, 6, 8
- **Mga Miner**: Kabanata 2, 3, 7
- **Mga Developer**: Lahat ng kabanata
- **Mga Mananaliksik**: Kabanata 3, 4, 5




## Mga Salin

| | | | | | |
|---|---|---|---|---|---|
| [🇩🇪 Aleman](../deu/index.md) | [🇸🇦 Arabo](../ara/index.md) | [🇧🇬 Bulgarian](../bul/index.md) | [🇨🇿 Czech](../ces/index.md) | [🇩🇰 Danish](../dan/index.md) | [🇪🇸 Espanyol](../spa/index.md) |
| [🇪🇪 Estonian](../est/index.md) | [🇫🇮 Finnish](../fin/index.md) | [🇬🇷 Griyego](../ell/index.md) | [🇯🇵 Hapon](../jpn/index.md) | [🇮🇱 Hebreo](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) |
| [🇭🇺 Hungarian](../hun/index.md) | [🇮🇩 Indonesian](../ind/index.md) | [🇬🇧 Ingles](../../index.md) | [🇮🇹 Italyano](../ita/index.md) | [🇰🇷 Koreano](../kor/index.md) | [🇱🇻 Latvian](../lav/index.md) |
| [🇱🇹 Lithuanian](../lit/index.md) | [🇳🇴 Norwegian](../nor/index.md) | [🇳🇱 Olandes](../nld/index.md) | [🇵🇱 Polish](../pol/index.md) | [🇵🇹 Portuges](../por/index.md) | [🇫🇷 Pranses](../fra/index.md) |
| [🇷🇴 Romanian](../ron/index.md) | [🇷🇺 Ruso](../rus/index.md) | [🇷🇸 Serbian](../srp/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇸🇪 Swedish](../swe/index.md) | [🇨🇳 Tsino](../zho/index.md) |
| [🇹🇷 Turko](../tur/index.md) | [🇺🇦 Ukrainian](../ukr/index.md) | [🇻🇳 Vietnamese](../vie/index.md) | | | |


---

## Talaan ng mga Nilalaman

### Bahagi I: Mga Pangunahing Konsepto

**[Kabanata 1: Panimula at Pangkalahatang-tanaw](1-introduction.md)**
Pangkalahatang-tanaw ng proyekto, arkitektura, pilosopiya ng disenyo, mga pangunahing tampok, at kung paano naiiba ang PoCX sa Proof of Work.

**[Kabanata 2: Format ng Plot File](2-plot-format.md)**
Kumpletong ispesipikasyon ng format ng PoCX plot kabilang ang SIMD optimization, proof-of-work scaling, at ebolusyon ng format mula sa POC1/POC2.

**[Kabanata 3: Consensus at Mining](3-consensus-and-mining.md)**
Kumpletong teknikal na ispesipikasyon ng mekanismo ng PoCX consensus: istruktura ng block, mga generation signature, pagsasaayos ng base target, proseso ng mining, pipeline ng validation, at Time Bending algorithm.

---

### Bahagi II: Mga Advanced na Tampok

**[Kabanata 4: Sistema ng Forging Assignment](4-forging-assignments.md)**
Arkitektura na OP_RETURN-only para sa pagdelega ng mga karapatan sa forging: istruktura ng transaksyon, disenyo ng database, state machine, paghawak ng reorg, at RPC interface.

**[Kabanata 5: Sinkronisasyon ng Oras at Seguridad](5-timing-security.md)**
Toleransya sa clock drift, mekanismo ng defensive forging, anti-clock manipulation, at mga konsiderasyon sa seguridad na may kinalaman sa timing.

**[Kabanata 6: Mga Parameter ng Network](6-network-parameters.md)**
Pagsasaayos ng chainparams, genesis block, mga parameter ng consensus, mga patakaran sa coinbase, dynamic scaling, at modelong pang-ekonomiya.

---

### Bahagi III: Paggamit at Integrasyon

**[Kabanata 7: Sanggunian ng RPC Interface](7-rpc-reference.md)**
Kumpletong sanggunian ng mga RPC command para sa mining, assignments, at mga query sa blockchain. Mahalaga para sa integrasyon ng miner at pool.

**[Kabanata 8: Gabay sa Wallet at GUI](8-wallet-guide.md)**
Gabay para sa gumagamit ng Bitcoin-PoCX Qt wallet: forging assignment dialog, kasaysayan ng transaksyon, pag-setup ng mining, at troubleshooting.

---

## Mabilisang Nabigasyon

### Para sa mga Tagapagpatakbo ng Node
→ Magsimula sa [Kabanata 1: Panimula](1-introduction.md)
→ Pagkatapos ay suriin ang [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md)
→ I-configure ang mining gamit ang [Kabanata 8: Gabay sa Wallet](8-wallet-guide.md)

### Para sa mga Miner
→ Unawain ang [Kabanata 2: Format ng Plot](2-plot-format.md)
→ Aralin ang proseso sa [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md)
→ Mag-integrate gamit ang [Kabanata 7: Sanggunian ng RPC](7-rpc-reference.md)

### Para sa mga Tagapagpatakbo ng Pool
→ Suriin ang [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md)
→ Pag-aralan ang [Kabanata 7: Sanggunian ng RPC](7-rpc-reference.md)
→ Ipatupad gamit ang assignment RPCs at submit_nonce

### Para sa mga Developer
→ Basahin ang lahat ng kabanata nang sunud-sunod
→ I-cross-reference ang mga implementation file na nabanggit sa buong dokumentasyon
→ Suriin ang istruktura ng direktoryo ng `src/pocx/`
→ Bumuo ng mga release gamit ang [GUIX](../bitcoin/contrib/guix/README.md)

---

## Mga Kombensyon sa Dokumentasyon

**Mga Sanggunian ng File**: Ang mga detalye ng implementasyon ay nagrereperensya sa mga source file bilang `path/to/file.cpp:line`

**Integrasyon ng Code**: Lahat ng pagbabago ay may feature-flag na `#ifdef ENABLE_POCX`

**Mga Cross-Reference**: Ang mga kabanata ay nag-uugnay sa mga kaugnay na seksyon gamit ang mga relative markdown link

**Antas ng Teknikal**: Ipinapalagay ng dokumentasyon na may kaalaman sa Bitcoin Core at C++ development

---

## Pagbuo

### Development Build

```bash
# I-clone kasama ang mga submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# I-configure na naka-enable ang PoCX
cmake -B build -DENABLE_POCX=ON

# Buuin
cmake --build build -j$(nproc)
```

**Mga Variant ng Build**:
```bash
# May Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debug build
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Mga Dependency**: Karaniwang mga dependency ng Bitcoin Core build. Tingnan ang [dokumentasyon ng Bitcoin Core build](https://github.com/bitcoin/bitcoin/tree/master/doc#building) para sa mga kinakailangan ayon sa platform.

### Mga Release Build

Para sa mga reproducible release binary, gamitin ang GUIX build system: Tingnan ang [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Mga Karagdagang Mapagkukunan

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Mga Kaugnay na Proyekto**:
- Plotter: Batay sa [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Batay sa [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Paano Basahin ang Dokumentasyong Ito

**Sunud-sunod na Pagbabasa**: Ang mga kabanata ay idinisenyo upang basahin nang sunud-sunod, na binubuo sa mga nakaraang konsepto.

**Pagbabasa bilang Sanggunian**: Gamitin ang talaan ng mga nilalaman upang direktang pumunta sa mga tiyak na paksa. Ang bawat kabanata ay may sariling nilalaman na may mga cross-reference sa mga kaugnay na materyal.

**Nabigasyon sa Browser**: Buksan ang `index.md` sa isang markdown viewer o browser. Lahat ng internal link ay relative at gumagana offline.

**PDF Export**: Ang dokumentasyong ito ay maaaring pagsamahin sa isang PDF para sa offline na pagbabasa.

---

## Katayuan ng Proyekto

**✅ Kumpleto ang Tampok**: Lahat ng consensus rule, mining, assignment, at mga tampok ng wallet ay naipatupad na.

**✅ Kumpleto ang Dokumentasyon**: Lahat ng 8 kabanata ay kumpleto at na-verify laban sa codebase.

**🔬 Aktibo ang Testnet**: Kasalukuyang nasa yugto ng testnet para sa pagsubok ng komunidad.

---

## Pag-aambag

Malugod na tinatanggap ang mga kontribusyon sa dokumentasyon. Mangyaring panatilihin ang:
- Teknikal na katumpakan kaysa sa labis na salita
- Maikli at direktang mga paliwanag
- Walang code o pseudo-code sa dokumentasyon (sa halip ay mag-reference ng mga source file)
- Kung ano lang ang naipatupad (walang mga spekulatibong tampok)

---

## Lisensya

Ang Bitcoin-PoCX ay nagmamana ng MIT license ng Bitcoin Core. Tingnan ang `COPYING` sa root ng repository.

Ang attribution ng PoCX core framework ay dokumentado sa [Kabanata 2: Format ng Plot](2-plot-format.md).

---

**Magsimulang Magbasa**: [Kabanata 1: Panimula at Pangkalahatang-tanaw →](1-introduction.md)

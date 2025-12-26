[← Iliyotangulia: Usawazishaji wa Muda](5-timing-security.md) | [Yaliyomo](index.md) | [Inayofuata: Marejeleo ya RPC →](7-rpc-reference.md)

---

# Sura ya 6: Vigezo na Usanidi wa Mtandao

Marejeleo kamili ya usanidi wa mtandao wa Bitcoin-PoCX kwa aina zote za mtandao.

---

## Yaliyomo

1. [Vigezo vya Bloku ya Mwanzo](#vigezo-vya-bloku-ya-mwanzo)
2. [Usanidi wa Chainparams](#usanidi-wa-chainparams)
3. [Vigezo vya Makubaliano](#vigezo-vya-makubaliano)
4. [Coinbase na Zawadi za Bloku](#coinbase-na-zawadi-za-bloku)
5. [Upanuzi Wenye Nguvu](#upanuzi-wenye-nguvu)
6. [Usanidi wa Mtandao](#usanidi-wa-mtandao)
7. [Muundo wa Saraka ya Data](#muundo-wa-saraka-ya-data)

---

## Vigezo vya Bloku ya Mwanzo

### Hesabu ya Lengo la Msingi

**Fomula**: `genesis_base_target = 2^42 / block_time_seconds`

**Sababu**:
- Kila nonce inawakilisha 256 KiB (byte 64 × scoop 4096)
- 1 TiB = nonce 2^22 (dhana ya uwezo wa mtandao wa kuanzia)
- Ubora wa chini unaotarajiwa kwa nonce n ≈ 2^64 / n
- Kwa 1 TiB: E(ubora) = 2^64 / 2^22 = 2^42
- Kwa hivyo: base_target = 2^42 / block_time

**Thamani Zilizohesabiwa**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Inatumia hali ya urekebishaji wa uwezo mdogo

### Ujumbe wa Mwanzo

Mitandao yote inashiriki ujumbe wa mwanzo wa Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Utekelezaji**: `src/kernel/chainparams.cpp`

---

## Usanidi wa Chainparams

### Vigezo vya Mainnet

**Utambulisho wa Mtandao**:
- **Byte za Uchawi**: `0xa7 0x3c 0x91 0x5e`
- **Bandari ya Default**: `8888`
- **Bech32 HRP**: `pocx`

**Viambishi vya Anwani** (Base58):
- PUBKEY_ADDRESS: `85` (anwani zinaanza na 'P')
- SCRIPT_ADDRESS: `90` (anwani zinaanza na 'R')
- SECRET_KEY: `128`

**Muda wa Bloku**:
- **Lengo la Muda wa Bloku**: sekunde `120` (dakika 2)
- **Muda wa Lengo**: sekunde `1209600` (siku 14)
- **MAX_FUTURE_BLOCK_TIME**: sekunde `15`

**Zawadi za Bloku**:
- **Ruzuku ya Awali**: `10 BTC`
- **Muda wa Nusu**: bloku `1050000` (~miaka 4)
- **Idadi ya Nusu**: nusu 64 za juu zaidi

**Marekebisho ya Ugumu**:
- **Dirisha Linalosongelea**: bloku `24`
- **Marekebisho**: Kila bloku
- **Algorithm**: Wastani unaosogea wa exponential

**Ucheleweshaji wa Ugawaji**:
- **Uanzishaji**: bloku `30` (~saa 1)
- **Kubatilisha**: bloku `720` (~saa 24)

### Vigezo vya Testnet

**Utambulisho wa Mtandao**:
- **Byte za Uchawi**: `0x6d 0xf2 0x48 0xb3`
- **Bandari ya Default**: `18888`
- **Bech32 HRP**: `tpocx`

**Viambishi vya Anwani** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Muda wa Bloku**:
- **Lengo la Muda wa Bloku**: sekunde `120`
- **MAX_FUTURE_BLOCK_TIME**: sekunde `15`
- **Ruhusu Ugumu wa Chini**: `true`

**Zawadi za Bloku**:
- **Ruzuku ya Awali**: `10 BTC`
- **Muda wa Nusu**: bloku `1050000`

**Marekebisho ya Ugumu**:
- **Dirisha Linalosongelea**: bloku `24`

**Ucheleweshaji wa Ugawaji**:
- **Uanzishaji**: bloku `30` (~saa 1)
- **Kubatilisha**: bloku `720` (~saa 24)

### Vigezo vya Regtest

**Utambulisho wa Mtandao**:
- **Byte za Uchawi**: `0xfa 0xbf 0xb5 0xda`
- **Bandari ya Default**: `18444`
- **Bech32 HRP**: `rpocx`

**Viambishi vya Anwani** (Vinaendana na Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Muda wa Bloku**:
- **Lengo la Muda wa Bloku**: sekunde `1` (uchimbaji wa papo hapo kwa majaribio)
- **Muda wa Lengo**: sekunde `86400` (siku 1)
- **MAX_FUTURE_BLOCK_TIME**: sekunde `15`

**Zawadi za Bloku**:
- **Ruzuku ya Awali**: `10 BTC`
- **Muda wa Nusu**: bloku `500`

**Marekebisho ya Ugumu**:
- **Dirisha Linalosongelea**: bloku `24`
- **Ruhusu Ugumu wa Chini**: `true`
- **Hakuna Kulenga Upya**: `true`
- **Urekebishaji wa Uwezo Mdogo**: `true` (inatumia urekebishaji wa nonce-16 badala ya 1 TiB)

**Ucheleweshaji wa Ugawaji**:
- **Uanzishaji**: bloku `4` (~sekunde 4)
- **Kubatilisha**: bloku `8` (~sekunde 8)

### Vigezo vya Signet

**Utambulisho wa Mtandao**:
- **Byte za Uchawi**: Byte 4 za kwanza za SHA256d(signet_challenge)
- **Bandari ya Default**: `38333`
- **Bech32 HRP**: `tpocx`

**Muda wa Bloku**:
- **Lengo la Muda wa Bloku**: sekunde `120`
- **MAX_FUTURE_BLOCK_TIME**: sekunde `15`

**Zawadi za Bloku**:
- **Ruzuku ya Awali**: `10 BTC`
- **Muda wa Nusu**: bloku `1050000`

**Marekebisho ya Ugumu**:
- **Dirisha Linalosongelea**: bloku `24`

---

## Vigezo vya Makubaliano

### Vigezo vya Muda

**MAX_FUTURE_BLOCK_TIME**: sekunde `15`
- Mahususi kwa PoCX (Bitcoin inatumia saa 2)
- Sababu: Muda wa PoC unahitaji uthibitishaji wa karibu na wakati halisi
- Bloku zaidi ya sekunde 15 katika siku zijazo zinakataliwa

**Onyo la Mkengeuko wa Muda**: sekunde `10`
- Waendeshaji wanaoonywa saa ya nodi inapopotoka >10s kutoka muda wa mtandao
- Hakuna utekelezaji, habari pekee

**Malengo ya Muda wa Bloku**:
- Mainnet/Testnet/Signet: sekunde `120`
- Regtest: sekunde `1`

**TIMESTAMP_WINDOW**: sekunde `15` (sawa na MAX_FUTURE_BLOCK_TIME)

**Utekelezaji**: `src/chain.h`, `src/validation.cpp`

### Vigezo vya Marekebisho ya Ugumu

**Ukubwa wa Dirisha Linalosongelea**: bloku `24` (mitandao yote)
- Wastani unaosogea wa exponential wa muda wa bloku za hivi karibuni
- Marekebisho ya kila bloku
- Inajibu mabadiliko ya uwezo

**Utekelezaji**: `src/consensus/params.h`, mantiki ya ugumu katika uundaji wa bloku

### Vigezo vya Mfumo wa Ugawaji

**nForgingAssignmentDelay** (ucheleweshaji wa uanzishaji):
- Mainnet: bloku `30` (~saa 1)
- Testnet: bloku `30` (~saa 1)
- Regtest: bloku `4` (~sekunde 4)

**nForgingRevocationDelay** (ucheleweshaji wa kubatilisha):
- Mainnet: bloku `720` (~saa 24)
- Testnet: bloku `720` (~saa 24)
- Regtest: bloku `8` (~sekunde 8)

**Sababu**:
- Ucheleweshaji wa uanzishaji unazuia ugawaji upya wa haraka wakati wa mashindano ya bloku
- Ucheleweshaji wa kubatilisha unatoa uthabiti na kuzuia matumizi mabaya

**Utekelezaji**: `src/consensus/params.h`

---

## Coinbase na Zawadi za Bloku

### Ratiba ya Ruzuku ya Bloku

**Ruzuku ya Awali**: `10 BTC` (mitandao yote)

**Ratiba ya Nusu**:
- Kila bloku `1050000` (mainnet/testnet)
- Kila bloku `500` (regtest)
- Inaendelea kwa nusu 64 za juu zaidi

**Maendeleo ya Nusu**:
```
Nusu 0: 10.00000000 BTC  (bloku 0 - 1049999)
Nusu 1:  5.00000000 BTC  (bloku 1050000 - 2099999)
Nusu 2:  2.50000000 BTC  (bloku 2100000 - 3149999)
Nusu 3:  1.25000000 BTC  (bloku 3150000 - 4199999)
...
```

**Usambazaji wa Jumla**: ~milioni 21 BTC (sawa na Bitcoin)

### Sheria za Tokeo la Coinbase

**Lengwa la Malipo**:
- **Hakuna Ugawaji**: Coinbase inalipa anwani ya plot (proof.account_id)
- **Na Ugawaji**: Coinbase inalipa anwani ya kuunda (msaini anayefanya kazi)

**Muundo wa Tokeo**: P2WPKH pekee
- Coinbase lazima ilipe kwa anwani ya SegWit v0 ya bech32
- Inazalishwa kutoka kwa ufunguo wa umma wa msaini anayefanya kazi

**Utatuzi wa Ugawaji**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Utekelezaji**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Upanuzi Wenye Nguvu

### Mipaka ya Upanuzi

**Madhumuni**: Kuongeza ugumu wa uzalishaji wa plot kadri mtandao unavyokomaa kuzuia mfumuko wa uwezo

**Muundo**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Kiwango cha chini kinachokubaliwa
    uint8_t nPoCXTargetCompression;  // Kiwango kinachopendekezwa
};
```

**Uhusiano**: `target = min + 1` (daima kiwango kimoja juu ya chini)

### Ratiba ya Kuongeza Upanuzi

Viwango vya upanuzi vinaongezeka kwa **ratiba ya exponential** kulingana na vipindi vya nusu:

| Kipindi cha Muda | Urefu wa Bloku | Nusu | Chini | Lengo |
|-------------|--------------|----------|-----|--------|
| Miaka 0-4 | 0 hadi 1049999 | 0 | X1 | X2 |
| Miaka 4-12 | 1050000 hadi 3149999 | 1-2 | X2 | X3 |
| Miaka 12-28 | 3150000 hadi 7349999 | 3-6 | X3 | X4 |
| Miaka 28-60 | 7350000 hadi 15749999 | 7-14 | X4 | X5 |
| Miaka 60-124 | 15750000 hadi 32549999 | 15-30 | X5 | X6 |
| Miaka 124+ | 32550000+ | 31+ | X6 | X7 |

**Urefu Muhimu** (miaka → nusu → bloku):
- Mwaka 4: Nusu 1 katika bloku 1050000
- Mwaka 12: Nusu 3 katika bloku 3150000
- Mwaka 28: Nusu 7 katika bloku 7350000
- Mwaka 60: Nusu 15 katika bloku 15750000
- Mwaka 124: Nusu 31 katika bloku 32550000

### Ugumu wa Kiwango cha Upanuzi

**Upanuzi wa PoW**:
- Kiwango cha upanuzi X0: Msingi wa POC2 (wa kinadharia)
- Kiwango cha upanuzi X1: Msingi wa XOR-transpose
- Kiwango cha upanuzi Xn: Kazi 2^(n-1) × ya X1 iliyojumuishwa
- Kila kiwango kinaongeza mara mbili kazi ya uzalishaji wa plot

**Usawazishaji wa Kiuchumi**:
- Zawadi za bloku zinanusu → ugumu wa uzalishaji wa plot unaongezeka
- Inadumisha ukingo wa usalama: gharama ya kuunda plot > gharama ya kutafuta
- Inazuia mfumuko wa uwezo kutoka uboreshaji wa vifaa

### Uthibitishaji wa Plot

**Sheria za Uthibitishaji**:
- Uthibitisho uliowasilishwa lazima uwe na kiwango cha upanuzi ≥ chini
- Uthibitisho wenye upanuzi > lengo unakubaliwa lakini si wa ufanisi
- Uthibitisho chini ya chini: unakataliwa (PoW haitoshi)

**Kupata Mipaka**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Utekelezaji**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Usanidi wa Mtandao

### Nodi za Mbegu na DNS Seeds

**Hali**: Kishikilia nafasi kwa uzinduzi wa mainnet

**Usanidi Uliopangwa**:
- Nodi za mbegu: TBD
- DNS seeds: TBD

**Hali ya Sasa** (testnet/regtest):
- Hakuna miundombinu maalum ya mbegu
- Muunganisho wa mikono wa wenzake unaungwa mkono kupitia `-addnode`

**Utekelezaji**: `src/kernel/chainparams.cpp`

### Alama

**Alama ya Mwanzo**: Daima bloku 0

**Alama za Ziada**: Hakuna zilizosanidiwa kwa sasa

**Baadaye**: Alama zitaongezwa kadri mainnet inavyoendelea

---

## Usanidi wa Itifaki ya P2P

### Toleo la Itifaki

**Msingi**: Itifaki ya Bitcoin Core v30.0
- **Toleo la Itifaki**: Limerithi kutoka Bitcoin Core
- **Bits za Huduma**: Huduma za kawaida za Bitcoin
- **Aina za Ujumbe**: Ujumbe wa kawaida wa P2P wa Bitcoin

**Viendelezi vya PoCX**:
- Vichwa vya bloku vinajumuisha sehemu mahususi za PoCX
- Ujumbe wa bloku unajumuisha data ya uthibitisho wa PoCX
- Sheria za uthibitishaji zinatekeleza makubaliano ya PoCX

**Utangamano**: Nodi za PoCX haziendani na nodi za Bitcoin PoW (makubaliano tofauti)

**Utekelezaji**: `src/protocol.h`, `src/net_processing.cpp`

---

## Muundo wa Saraka ya Data

### Saraka ya Default

**Mahali**: `.bitcoin/` (sawa na Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Yaliyomo ya Saraka

```
.bitcoin/
├── blocks/              # Data ya bloku
│   ├── blk*.dat        # Faili za bloku
│   ├── rev*.dat        # Data ya kutengua
│   └── index/          # Fahirisi ya bloku (LevelDB)
├── chainstate/         # Seti ya UTXO + ugawaji wa kuunda (LevelDB)
├── wallets/            # Faili za pochi
│   └── wallet.dat      # Pochi ya default
├── bitcoin.conf        # Faili ya usanidi
├── debug.log           # Kumbukumbu ya utatuzi
├── peers.dat           # Anwani za wenzake
├── mempool.dat         # Kudumu kwa mempool
└── banlist.dat         # Wenzake waliopigwa marufuku
```

### Tofauti Muhimu kutoka Bitcoin

**Hifadhidata ya Chainstate**:
- Kawaida: Seti ya UTXO
- **Nyongeza ya PoCX**: Hali ya ugawaji wa kuunda
- Sasisho za atomiki: UTXO + ugawaji zinasasishwa pamoja
- Data ya kutengua salama kwa reorg kwa ugawaji

**Faili za Bloku**:
- Muundo wa kawaida wa bloku wa Bitcoin
- **Nyongeza ya PoCX**: Imeongezwa na sehemu za uthibitisho wa PoCX (account_id, seed, nonce, signature, pubkey)

### Mfano wa Faili ya Usanidi

**bitcoin.conf**:
```ini
# Uchaguzi wa mtandao
#testnet=1
#regtest=1

# Seva ya uchimbaji wa PoCX (inahitajika kwa wachimbaji wa nje)
miningserver=1

# Mipangilio ya RPC
server=1
rpcuser=jinalako
rpcpassword=nywilayako
rpcallowip=127.0.0.1
rpcport=8332

# Mipangilio ya muunganisho
listen=1
port=8888
maxconnections=125

# Lengo la muda wa bloku (habari, linatekelezwa na makubaliano)
# sekunde 120 kwa mainnet/testnet
```

---

## Marejeleo ya Msimbo

**Chainparams**: `src/kernel/chainparams.cpp`
**Vigezo vya Makubaliano**: `src/consensus/params.h`
**Mipaka ya Ukandamizaji**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Hesabu ya Lengo la Msingi ya Mwanzo**: `src/pocx/consensus/params.cpp`
**Mantiki ya Malipo ya Coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Hifadhi ya Hali ya Ugawaji**: `src/coins.h`, `src/coins.cpp` (viendelezi vya CCoinsViewCache)

---

## Marejeleo ya Msalaba

Sura zinazohusiana:
- [Sura ya 2: Muundo wa Plot](2-plot-format.md) - Viwango vya upanuzi katika uzalishaji wa plot
- [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md) - Uthibitishaji wa upanuzi, mfumo wa ugawaji
- [Sura ya 4: Ugawaji wa Kuunda](4-forging-assignments.md) - Vigezo vya ucheleweshaji wa ugawaji
- [Sura ya 5: Usalama wa Muda](5-timing-security.md) - Sababu ya MAX_FUTURE_BLOCK_TIME

---

[← Iliyotangulia: Usawazishaji wa Muda](5-timing-security.md) | [Yaliyomo](index.md) | [Inayofuata: Marejeleo ya RPC →](7-rpc-reference.md)

[<- Föregående: Tidssynkronisering](5-timing-security.md) | [Innehållsförteckning](index.md) | [Nästa: RPC-referens ->](7-rpc-reference.md)

---

# Kapitel 6: Nätverksparametrar och konfiguration

Fullständig referens för Bitcoin-PoCX-nätverkskonfiguration över alla nätverkstyper.

---

## Innehållsförteckning

1. [Genesisblockparametrar](#genesisblockparametrar)
2. [Chainparams-konfiguration](#chainparams-konfiguration)
3. [Konsensusparametrar](#konsensusparametrar)
4. [Coinbase och blockbelöningar](#coinbase-och-blockbelöningar)
5. [Dynamisk skalning](#dynamisk-skalning)
6. [Nätverkskonfiguration](#nätverkskonfiguration)
7. [Datakatalogstruktur](#datakatalogstruktur)

---

## Genesisblockparametrar

### Basmålberäkning

**Formel**: `genesis_base_target = 2^42 / block_time_seconds`

**Motivering**:
- Varje nonce representerar 256 KiB (64 bytes × 4096 scoops)
- 1 TiB = 2^22 nonces (startande nätverkskapacitetsantagande)
- Förväntad minimikvalitet för n nonces ≈ 2^64 / n
- För 1 TiB: E(kvalitet) = 2^64 / 2^22 = 2^42
- Därför: base_target = 2^42 / block_time

**Beräknade värden**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Använder lågkapacitetskalibreringläge

### Genesismeddelande

Alla nätverk delar Bitcoin-genesismeddelandet:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementation**: `src/kernel/chainparams.cpp`

---

## Chainparams-konfiguration

### Mainnet-parametrar

**Nätverksidentitet**:
- **Magiska bytes**: `0xa7 0x3c 0x91 0x5e`
- **Standardport**: `8888`
- **Bech32 HRP**: `pocx`

**Adressprefix** (Base58):
- PUBKEY_ADDRESS: `85` (adresser börjar med 'P')
- SCRIPT_ADDRESS: `90` (adresser börjar med 'R')
- SECRET_KEY: `128`

**Blocktiming**:
- **Blocktidsmål**: `120` sekunder (2 minuter)
- **Måltidsrymd**: `1209600` sekunder (14 dagar)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blockbelöningar**:
- **Initial subvention**: `10 BTC`
- **Halveringsintervall**: `1050000` block (~4 år)
- **Halveringsantal**: 64 halveringar maximalt

**Svårighetsjustering**:
- **Rullande fönster**: `24` block
- **Justering**: Varje block
- **Algoritm**: Exponentiellt glidande medelvärde

**Tilldelningsfördröjningar**:
- **Aktivering**: `30` block (~1 timme)
- **Återkallelse**: `720` block (~24 timmar)

### Testnet-parametrar

**Nätverksidentitet**:
- **Magiska bytes**: `0x6d 0xf2 0x48 0xb3`
- **Standardport**: `18888`
- **Bech32 HRP**: `tpocx`

**Adressprefix** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Blocktiming**:
- **Blocktidsmål**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- **Tillåt minimsvårighet**: `true`

**Blockbelöningar**:
- **Initial subvention**: `10 BTC`
- **Halveringsintervall**: `1050000` block

**Svårighetsjustering**:
- **Rullande fönster**: `24` block

**Tilldelningsfördröjningar**:
- **Aktivering**: `30` block (~1 timme)
- **Återkallelse**: `720` block (~24 timmar)

### Regtest-parametrar

**Nätverksidentitet**:
- **Magiska bytes**: `0xfa 0xbf 0xb5 0xda`
- **Standardport**: `18444`
- **Bech32 HRP**: `rpocx`

**Adressprefix** (Bitcoin-kompatibla):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Blocktiming**:
- **Blocktidsmål**: `1` sekund (omedelbar mining för testning)
- **Måltidsrymd**: `86400` sekunder (1 dag)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blockbelöningar**:
- **Initial subvention**: `10 BTC`
- **Halveringsintervall**: `500` block

**Svårighetsjustering**:
- **Rullande fönster**: `24` block
- **Tillåt minimsvårighet**: `true`
- **Ingen omjustering**: `true`
- **Lågkapacitetskalibrering**: `true` (använder 16-nonce-kalibrering istället för 1 TiB)

**Tilldelningsfördröjningar**:
- **Aktivering**: `4` block (~4 sekunder)
- **Återkallelse**: `8` block (~8 sekunder)

### Signet-parametrar

**Nätverksidentitet**:
- **Magiska bytes**: Första 4 bytes av SHA256d(signet_challenge)
- **Standardport**: `38333`
- **Bech32 HRP**: `tpocx`

**Blocktiming**:
- **Blocktidsmål**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blockbelöningar**:
- **Initial subvention**: `10 BTC`
- **Halveringsintervall**: `1050000` block

**Svårighetsjustering**:
- **Rullande fönster**: `24` block

---

## Konsensusparametrar

### Tidsparametrar

**MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- PoCX-specifik (Bitcoin använder 2 timmar)
- Motivering: PoC-timing kräver nära realtidsvalidering
- Block mer än 15s i framtiden avvisas

**Tidsavvikelsevarning**: `10` sekunder
- Operatörer varnas när nodklocka driftar >10s från nätverkstid
- Ingen tillämpning, endast information

**Blocktidsmål**:
- Mainnet/Testnet/Signet: `120` sekunder
- Regtest: `1` sekund

**TIMESTAMP_WINDOW**: `15` sekunder (lika med MAX_FUTURE_BLOCK_TIME)

**Implementation**: `src/chain.h`, `src/validation.cpp`

### Svårighetsjusteringsparametrar

**Rullande fönsterstorlek**: `24` block (alla nätverk)
- Exponentiellt glidande medelvärde av senaste blocktider
- Justering varje block
- Responsiv för kapacitetsändringar

**Implementation**: `src/consensus/params.h`, svårighetslogik i blockskapande

### Tilldelningssystemparametrar

**nForgingAssignmentDelay** (aktiveringsfördröjning):
- Mainnet: `30` block (~1 timme)
- Testnet: `30` block (~1 timme)
- Regtest: `4` block (~4 sekunder)

**nForgingRevocationDelay** (återkallelsefördröjning):
- Mainnet: `720` block (~24 timmar)
- Testnet: `720` block (~24 timmar)
- Regtest: `8` block (~8 sekunder)

**Motivering**:
- Aktiveringsfördröjning förhindrar snabb omtilldelning under blockraces
- Återkallelsefördröjning ger stabilitet och förhindrar missbruk

**Implementation**: `src/consensus/params.h`

---

## Coinbase och blockbelöningar

### Blocksubventionsschema

**Initial subvention**: `10 BTC` (alla nätverk)

**Halveringsschema**:
- Var `1050000`:e block (mainnet/testnet)
- Var `500`:e block (regtest)
- Fortsätter i 64 halveringar maximalt

**Halveringsprogression**:
```
Halvering 0: 10.00000000 BTC  (block 0 - 1049999)
Halvering 1:  5.00000000 BTC  (block 1050000 - 2099999)
Halvering 2:  2.50000000 BTC  (block 2100000 - 3149999)
Halvering 3:  1.25000000 BTC  (block 3150000 - 4199999)
...
```

**Total tillgång**: ~21 miljoner BTC (samma som Bitcoin)

### Coinbase-utdataregler

**Betalningsdestination**:
- **Ingen tilldelning**: Coinbase betalar plotadress (proof.account_id)
- **Med tilldelning**: Coinbase betalar forgningsadress (effektiv signerare)

**Utdataformat**: Endast P2WPKH
- Coinbase måste betala till bech32 SegWit v0-adress
- Genererad från effektiv signerares publika nyckel

**Tilldelningsupplösning**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementation**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamisk skalning

### Skalningsgränser

**Syfte**: Öka plotgenereringssvårighet när nätverket mognar för att förhindra kapacitetsinflation

**Struktur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minsta accepterade nivå
    uint8_t nPoCXTargetCompression;  // Rekommenderad nivå
};
```

**Förhållande**: `target = min + 1` (alltid en nivå över minimum)

### Schema för skalningsökning

Skalningsnivåer ökar enligt **exponentiellt schema** baserat på halveringsintervall:

| Tidsperiod | Blockhöjd | Halveringar | Min | Mål |
|------------|-----------|-------------|-----|-----|
| År 0-4 | 0 till 1049999 | 0 | X1 | X2 |
| År 4-12 | 1050000 till 3149999 | 1-2 | X2 | X3 |
| År 12-28 | 3150000 till 7349999 | 3-6 | X3 | X4 |
| År 28-60 | 7350000 till 15749999 | 7-14 | X4 | X5 |
| År 60-124 | 15750000 till 32549999 | 15-30 | X5 | X6 |
| År 124+ | 32550000+ | 31+ | X6 | X7 |

**Nyckelhöjder** (år -> halveringar -> block):
- År 4: Halvering 1 vid block 1050000
- År 12: Halvering 3 vid block 3150000
- År 28: Halvering 7 vid block 7350000
- År 60: Halvering 15 vid block 15750000
- År 124: Halvering 31 vid block 32550000

### Skalningsnivåsvårighet

**PoW-skalning**:
- Skalningsnivå X0: POC2-baslinje (teoretisk)
- Skalningsnivå X1: XOR-transponeringsbaslinje
- Skalningsnivå Xn: 2^(n-1) × X1-arbete inbäddat
- Varje nivå fördubblar plotgenereringsarbete

**Ekonomisk anpassning**:
- Blockbelöningar halveras -> plotgenereringssvårighet ökar
- Bibehåller säkerhetsmarginal: plotskapandekostnad > uppslagskostnad
- Förhindrar kapacitetsinflation från hårdvaruförbättringar

### Plotvalidering

**Valideringsregler**:
- Skickade bevis måste ha skalningsnivå >= minimum
- Bevis med skalning > mål accepteras men ineffektiva
- Bevis under minimum: avvisas (otillräckligt PoW)

**Gränshämtning**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementation**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Nätverkskonfiguration

### Seed-noder och DNS-seeds

**Status**: Platshållare för mainnet-lansering

**Planerad konfiguration**:
- Seed-noder: TBD
- DNS-seeds: TBD

**Nuvarande status** (testnet/regtest):
- Ingen dedikerad seed-infrastruktur
- Manuella peer-anslutningar stöds via `-addnode`

**Implementation**: `src/kernel/chainparams.cpp`

### Checkpoints

**Genesis-checkpoint**: Alltid block 0

**Ytterligare checkpoints**: Inga för närvarande konfigurerade

**Framtid**: Checkpoints kommer läggas till när mainnet fortskrider

---

## P2P-protokollkonfiguration

### Protokollversion

**Bas**: Bitcoin Core v30.0-protokoll
- **Protokollversion**: Ärvd från Bitcoin Core
- **Tjänstebitar**: Standard Bitcoin-tjänster
- **Meddelandetyper**: Standard Bitcoin P2P-meddelanden

**PoCX-utökningar**:
- Blockheaders inkluderar PoCX-specifika fält
- Blockmeddelanden inkluderar PoCX-bevisdata
- Valideringsregler upprätthåller PoCX-konsensus

**Kompatibilitet**: PoCX-noder inkompatibla med Bitcoin PoW-noder (olika konsensus)

**Implementation**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datakatalogstruktur

### Standardkatalog

**Plats**: `.bitcoin/` (samma som Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Kataloginnehåll

```
.bitcoin/
├── blocks/              # Blockdata
│   ├── blk*.dat        # Blockfiler
│   ├── rev*.dat        # Undo-data
│   └── index/          # Blockindex (LevelDB)
├── chainstate/         # UTXO-set + forgningstilldelningar (LevelDB)
├── wallets/            # Plånboksfiler
│   └── wallet.dat      # Standardplånbok
├── bitcoin.conf        # Konfigurationsfil
├── debug.log           # Debug-logg
├── peers.dat           # Peer-adresser
├── mempool.dat         # Mempoolpersistens
└── banlist.dat         # Förbjudna peers
```

### Viktiga skillnader från Bitcoin

**Chainstate-databas**:
- Standard: UTXO-set
- **PoCX-tillägg**: Forgningstilldelningsstatus
- Atomära uppdateringar: UTXO + tilldelningar uppdateras tillsammans
- Reorg-säker undo-data för tilldelningar

**Blockfiler**:
- Standard Bitcoin-blockformat
- **PoCX-tillägg**: Utökat med PoCX-bevisfält (account_id, seed, nonce, signatur, pubkey)

### Konfigurationsfilexempel

**bitcoin.conf**:
```ini
# Nätverksval
#testnet=1
#regtest=1

# PoCX-miningserver (krävs för externa miners)
miningserver=1

# RPC-inställningar
server=1
rpcuser=dittanvändarnamn
rpcpassword=dittlösenord
rpcallowip=127.0.0.1
rpcport=8332

# Anslutningsinställningar
listen=1
port=8888
maxconnections=125

# Blocktidsmål (information, konsensus upprätthålls)
# 120 sekunder för mainnet/testnet
```

---

## Kodreferenser

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensusparametrar**: `src/consensus/params.h`
**Kompressionsgränser**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis-basmålsberäkning**: `src/pocx/consensus/params.cpp`
**Coinbase-betalningslogik**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Tilldelningsstatslagring**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-utökningar)

---

## Korsreferenser

Relaterade kapitel:
- [Kapitel 2: Plotformat](2-plot-format.md) - Skalningsnivåer i plotgenerering
- [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md) - Skalningsvalidering, tilldelningssystem
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Tilldelningsfördröjningsparametrar
- [Kapitel 5: Tidssynkronisering och säkerhet](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-motivering

---

[<- Föregående: Tidssynkronisering](5-timing-security.md) | [Innehållsförteckning](index.md) | [Nästa: RPC-referens ->](7-rpc-reference.md)

[← Forrige: Tidssynkronisering](5-timing-security.md) | [Innholdsfortegnelse](index.md) | [Neste: RPC-referanse →](7-rpc-reference.md)

---

# Kapittel 6: Nettverksparametere og konfigurasjon

Fullstendig referanse for Bitcoin-PoCX nettverkskonfigurasjon på tvers av alle nettverkstyper.

---

## Innholdsfortegnelse

1. [Genesis-blokkparametere](#genesis-blokkparametere)
2. [Chainparams-konfigurasjon](#chainparams-konfigurasjon)
3. [Konsensusparametere](#konsensusparametere)
4. [Coinbase og blokkbelønninger](#coinbase-og-blokkbelønninger)
5. [Dynamisk skalering](#dynamisk-skalering)
6. [Nettverkskonfigurasjon](#nettverkskonfigurasjon)
7. [Datamappestruktur](#datamappestruktur)

---

## Genesis-blokkparametere

### Base target-beregning

**Formel**: `genesis_base_target = 2^42 / block_time_seconds`

**Begrunnelse**:
- Hver nonce representerer 256 KiB (64 bytes × 4096 scoops)
- 1 TiB = 2^22 nonces (startkapasitetantakelse for nettverk)
- Forventet minimumskvalitet for n nonces ≈ 2^64 / n
- For 1 TiB: E(kvalitet) = 2^64 / 2^22 = 2^42
- Derfor: base_target = 2^42 / block_time

**Beregnede verdier**:
- Mainnet/Testnett/Signet (120s): `36650387592`
- Regtest (1s): Bruker lavkapasitetskalibringsmodus

### Genesis-melding

Alle nettverk deler Bitcoin genesis-meldingen:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementasjon**: `src/kernel/chainparams.cpp`

---

## Chainparams-konfigurasjon

### Mainnet-parametere

**Nettverksidentitet**:
- **Magic bytes**: `0xa7 0x3c 0x91 0x5e`
- **Standardport**: `8888`
- **Bech32 HRP**: `pocx`

**Adresseprefikser** (Base58):
- PUBKEY_ADDRESS: `85` (adresser starter med 'P')
- SCRIPT_ADDRESS: `90` (adresser starter med 'R')
- SECRET_KEY: `128`

**Blokktiming**:
- **Blokktidsmål**: `120` sekunder (2 minutter)
- **Måltidsrom**: `1209600` sekunder (14 dager)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokkbelønninger**:
- **Initial subsidie**: `10 BTC`
- **Halveringsintervall**: `1050000` blokker (~4 år)
- **Halveringsantall**: Maksimum 64 halveringer

**Vanskelighetsjustering**:
- **Rullende vindu**: `24` blokker
- **Justering**: Hver blokk
- **Algoritme**: Eksponentielt glidende gjennomsnitt

**Tildelingsforsinkelser**:
- **Aktivering**: `30` blokker (~1 time)
- **Oppheving**: `720` blokker (~24 timer)

### Testnett-parametere

**Nettverksidentitet**:
- **Magic bytes**: `0x6d 0xf2 0x48 0xb3`
- **Standardport**: `18888`
- **Bech32 HRP**: `tpocx`

**Adresseprefikser** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Blokktiming**:
- **Blokktidsmål**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- **Tillat minimumsvanskelighet**: `true`

**Blokkbelønninger**:
- **Initial subsidie**: `10 BTC`
- **Halveringsintervall**: `1050000` blokker

**Vanskelighetsjustering**:
- **Rullende vindu**: `24` blokker

**Tildelingsforsinkelser**:
- **Aktivering**: `30` blokker (~1 time)
- **Oppheving**: `720` blokker (~24 timer)

### Regtest-parametere

**Nettverksidentitet**:
- **Magic bytes**: `0xfa 0xbf 0xb5 0xda`
- **Standardport**: `18444`
- **Bech32 HRP**: `rpocx`

**Adresseprefikser** (Bitcoin-kompatibel):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Blokktiming**:
- **Blokktidsmål**: `1` sekund (umiddelbar mining for testing)
- **Måltidsrom**: `86400` sekunder (1 dag)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokkbelønninger**:
- **Initial subsidie**: `10 BTC`
- **Halveringsintervall**: `500` blokker

**Vanskelighetsjustering**:
- **Rullende vindu**: `24` blokker
- **Tillat minimumsvanskelighet**: `true`
- **Ingen retargeting**: `true`
- **Lavkapasitetskalibrering**: `true` (bruker 16-nonce kalibrering i stedet for 1 TiB)

**Tildelingsforsinkelser**:
- **Aktivering**: `4` blokker (~4 sekunder)
- **Oppheving**: `8` blokker (~8 sekunder)

### Signet-parametere

**Nettverksidentitet**:
- **Magic bytes**: Første 4 bytes av SHA256d(signet_challenge)
- **Standardport**: `38333`
- **Bech32 HRP**: `tpocx`

**Blokktiming**:
- **Blokktidsmål**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokkbelønninger**:
- **Initial subsidie**: `10 BTC`
- **Halveringsintervall**: `1050000` blokker

**Vanskelighetsjustering**:
- **Rullende vindu**: `24` blokker

---

## Konsensusparametere

### Tidsparametere

**MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- PoCX-spesifikk (Bitcoin bruker 2 timer)
- Begrunnelse: PoC-timing krever nær sanntidsvalidering
- Blokker mer enn 15s i fremtiden avvises

**Tidsavvik-advarsel**: `10` sekunder
- Operatører advares når nodeklokke avviker >10s fra nettverkstid
- Ingen håndhevelse, kun informasjon

**Blokktidsmål**:
- Mainnet/Testnett/Signet: `120` sekunder
- Regtest: `1` sekund

**TIMESTAMP_WINDOW**: `15` sekunder (lik MAX_FUTURE_BLOCK_TIME)

**Implementasjon**: `src/chain.h`, `src/validation.cpp`

### Vanskelighetsjusteringsparametere

**Rullende vindsstørrelse**: `24` blokker (alle nettverk)
- Eksponentielt glidende gjennomsnitt av nylige blokktider
- Justering ved hver blokk
- Responsiv til kapasitetsendringer

**Implementasjon**: `src/consensus/params.h`, vanskelighetslogikk i blokkoppretting

### Tildelingssystemparametere

**nForgingAssignmentDelay** (aktiveringsforsinkelse):
- Mainnet: `30` blokker (~1 time)
- Testnett: `30` blokker (~1 time)
- Regtest: `4` blokker (~4 sekunder)

**nForgingRevocationDelay** (opphevingsforsinkelse):
- Mainnet: `720` blokker (~24 timer)
- Testnett: `720` blokker (~24 timer)
- Regtest: `8` blokker (~8 sekunder)

**Begrunnelse**:
- Aktiveringsforsinkelse forhindrer rask omtildeling under blokkras
- Opphevingsforsinkelse gir stabilitet og forhindrer misbruk

**Implementasjon**: `src/consensus/params.h`

---

## Coinbase og blokkbelønninger

### Blokksubsidieplan

**Initial subsidie**: `10 BTC` (alle nettverk)

**Halveringsplan**:
- Hver `1050000` blokk (mainnet/testnett)
- Hver `500` blokk (regtest)
- Fortsetter i maksimalt 64 halveringer

**Halveringsprogresjon**:
```
Halvering 0: 10.00000000 BTC  (blokk 0 - 1049999)
Halvering 1:  5.00000000 BTC  (blokk 1050000 - 2099999)
Halvering 2:  2.50000000 BTC  (blokk 2100000 - 3149999)
Halvering 3:  1.25000000 BTC  (blokk 3150000 - 4199999)
...
```

**Total forsyning**: ~21 millioner BTC (samme som Bitcoin)

### Coinbase-utdataregler

**Betalingsdestinasjon**:
- **Ingen tildeling**: Coinbase betaler plotadresse (proof.account_id)
- **Med tildeling**: Coinbase betaler forging-adresse (effektiv signerer)

**Utdataformat**: Kun P2WPKH
- Coinbase må betale til bech32 SegWit v0-adresse
- Genereres fra effektiv signerers offentlige nøkkel

**Tildelingsoppløsning**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementasjon**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamisk skalering

### Skaleringsgrenser

**Formål**: Øke plotgenereringsvanskelighet etter hvert som nettverk modnes for å forhindre kapasitetsinflasjon

**Struktur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum akseptert nivå
    uint8_t nPoCXTargetCompression;  // Anbefalt nivå
};
```

**Forhold**: `target = min + 1` (alltid ett nivå over minimum)

### Skaleringsøkningsplan

Skaleringsnivåer øker etter **eksponentiell plan** basert på halveringsintervaller:

| Tidsperiode | Blokkhøyde | Halveringer | Min | Mål |
|-------------|------------|-------------|-----|-----|
| År 0-4 | 0 til 1049999 | 0 | X1 | X2 |
| År 4-12 | 1050000 til 3149999 | 1-2 | X2 | X3 |
| År 12-28 | 3150000 til 7349999 | 3-6 | X3 | X4 |
| År 28-60 | 7350000 til 15749999 | 7-14 | X4 | X5 |
| År 60-124 | 15750000 til 32549999 | 15-30 | X5 | X6 |
| År 124+ | 32550000+ | 31+ | X6 | X7 |

**Nøkkelhøyder** (år → halveringer → blokker):
- År 4: Halvering 1 ved blokk 1050000
- År 12: Halvering 3 ved blokk 3150000
- År 28: Halvering 7 ved blokk 7350000
- År 60: Halvering 15 ved blokk 15750000
- År 124: Halvering 31 ved blokk 32550000

### Skaleringsnivåvanskelighet

**PoW-skalering**:
- Skaleringsnivå X0: POC2-grunnlinje (teoretisk)
- Skaleringsnivå X1: XOR-transpose-grunnlinje
- Skaleringsnivå Xn: 2^(n-1) × X1-arbeid innebygd
- Hvert nivå dobler plotgenereringsarbeid

**Økonomisk tilpasning**:
- Blokkbelønninger halveres → plotgenereringsvanskelighet øker
- Opprettholder sikkerhetsmargin: plotopprettingskostnad > oppslagskostnad
- Forhindrer kapasitetsinflasjon fra maskinvareforbedringer

### Plotvalidering

**Valideringsregler**:
- Innsendte bevis må ha skaleringsnivå ≥ minimum
- Bevis med skalering > mål aksepteres, men er ineffektive
- Bevis under minimum: avvist (utilstrekkelig PoW)

**Grensehenting**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementasjon**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Nettverkskonfigurasjon

### Seed-noder og DNS-seeds

**Status**: Plassholder for mainnet-lansering

**Planlagt konfigurasjon**:
- Seed-noder: TBD
- DNS-seeds: TBD

**Nåværende tilstand** (testnett/regtest):
- Ingen dedikert seed-infrastruktur
- Manuelle peer-forbindelser støttes via `-addnode`

**Implementasjon**: `src/kernel/chainparams.cpp`

### Sjekkpunkter

**Genesis-sjekkpunkt**: Alltid blokk 0

**Tilleggssjekkpunkter**: Ingen for øyeblikket konfigurert

**Fremtidig**: Sjekkpunkter vil legges til etter hvert som mainnet skrider frem

---

## P2P-protokollkonfigurasjon

### Protokollversjon

**Base**: Bitcoin Core v30.0-protokoll
- **Protokollversjon**: Arvet fra Bitcoin Core
- **Tjenestebiter**: Standard Bitcoin-tjenester
- **Meldingstyper**: Standard Bitcoin P2P-meldinger

**PoCX-utvidelser**:
- Blokkheadere inkluderer PoCX-spesifikke felt
- Blokkmeldinger inkluderer PoCX-bevisdata
- Valideringsregler håndhever PoCX-konsensus

**Kompatibilitet**: PoCX-noder inkompatible med Bitcoin PoW-noder (forskjellig konsensus)

**Implementasjon**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datamappestruktur

### Standardmappe

**Plassering**: `.bitcoin/` (samme som Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Mappeinnhold

```
.bitcoin/
├── blocks/              # Blokkdata
│   ├── blk*.dat        # Blokkfiler
│   ├── rev*.dat        # Undo-data
│   └── index/          # Blokkindeks (LevelDB)
├── chainstate/         # UTXO-sett + forging-tildelinger (LevelDB)
├── wallets/            # Lommebokfiler
│   └── wallet.dat      # Standard lommebok
├── bitcoin.conf        # Konfigurasjonsfil
├── debug.log           # Feilsøkingslogg
├── peers.dat           # Peer-adresser
├── mempool.dat         # Mempool-persistens
└── banlist.dat         # Utestengte peers
```

### Viktige forskjeller fra Bitcoin

**Chainstate-database**:
- Standard: UTXO-sett
- **PoCX-tillegg**: Forging-tildelingstilstand
- Atomiske oppdateringer: UTXO + tildelinger oppdateres sammen
- Reorg-sikker undo-data for tildelinger

**Blokkfiler**:
- Standard Bitcoin-blokkformat
- **PoCX-tillegg**: Utvidet med PoCX-bevisfelt (account_id, seed, nonce, signatur, pubkey)

### Eksempel på konfigurasjonsfil

**bitcoin.conf**:
```ini
# Nettverksvalg
#testnet=1
#regtest=1

# PoCX mining-server (påkrevd for eksterne minere)
miningserver=1

# RPC-innstillinger
server=1
rpcuser=dittbrukernavn
rpcpassword=dittpassord
rpcallowip=127.0.0.1
rpcport=8332

# Forbindelsesinnstillinger
listen=1
port=8888
maxconnections=125

# Blokktidsmål (informasjon, konsensus-håndhevet)
# 120 sekunder for mainnet/testnett
```

---

## Kodereferanser

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensusparametere**: `src/consensus/params.h`
**Komprimeringsbegrensninger**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis base target-beregning**: `src/pocx/consensus/params.cpp`
**Coinbase-betalingslogikk**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Tildelingstilstandslagring**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-utvidelser)

---

## Kryssreferanser

Relaterte kapitler:
- [Kapittel 2: Plotformat](2-plot-format.md) - Skaleringsnivåer i plotgenerering
- [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md) - Skaleringsvalidering, tildelingssystem
- [Kapittel 4: Forging assignments](4-forging-assignments.md) - Tildelingsforsinkelsesparametere
- [Kapittel 5: Tidssikkerhet](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-begrunnelse

---

[← Forrige: Tidssynkronisering](5-timing-security.md) | [Innholdsfortegnelse](index.md) | [Neste: RPC-referanse →](7-rpc-reference.md)

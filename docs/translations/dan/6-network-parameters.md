[<- Forrige: Tidssynkronisering](5-timing-security.md) | [Indholdsfortegnelse](index.md) | [Naeste: RPC-reference ->](7-rpc-reference.md)

---

# Kapitel 6: Netvaerksparametre og konfiguration

Komplet reference til Bitcoin-PoCX-netvaerkskonfiguration pa tvaers af alle netvaerkstyper.

---

## Indholdsfortegnelse

1. [Genesis-blokparametre](#genesis-blokparametre)
2. [Chainparams-konfiguration](#chainparams-konfiguration)
3. [Konsensusparametre](#konsensusparametre)
4. [Coinbase og blokbeloninger](#coinbase-og-blokbeloninger)
5. [Dynamisk skalering](#dynamisk-skalering)
6. [Netvaerkskonfiguration](#netvaerkskonfiguration)
7. [Datamappestruktur](#datamappestruktur)

---

## Genesis-blokparametre

### Base target-beregning

**Formel**: `genesis_base_target = 2^42 / block_time_seconds`

**Rationale**:
- Hver nonce repraesenterer 256 KiB (64 bytes x 4096 scoops)
- 1 TiB = 2^22 nonces (startnetvaerkskapacitetsantagelse)
- Forventet minimumskvalitet for n nonces ca. 2^64 / n
- For 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Derfor: base_target = 2^42 / bloktid

**Beregnede vaerdier**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (120s): Bruger lavkapacitetskalibreringtilstand (base_power 2^58)

### Genesis-meddelelse

Each network has its own genesis message. See `src/kernel/chainparams.cpp` for details.

---

## Chainparams-konfiguration

### Mainnet-parametre

**Netvaerksidentitet**:
- **Magic bytes**: `0xa7 0x3c 0x91 0x5e`
- **Standardport**: `8338`
- **Bech32 HRP**: `pocx`

**Adressepraefixer** (Base58):
- PUBKEY_ADDRESS: `85` (adresser starter med 'P')
- SCRIPT_ADDRESS: `90` (adresser starter med 'R')
- SECRET_KEY: `128`

**Bloktiming**:
- **Bloktidsmal**: `120` sekunder (2 minutter)
- **Maltidsrum**: `1209600` sekunder (14 dage)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokbeloninger**:
- **Indledende subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokke (~4 ar)
- **Halveringsantal**: 64 halveringer maksimalt

**Svaerhedsjustering**:
- **Rullende vindue**: `24` blokke
- **Justering**: Hver blok
- **Algoritme**: Vaegtet glidende gennemsnit (Burstcoin-stil, ±20% loft per blok)

**Assignment-forsinkelser**:
- **Aktivering**: `30` blokke (~1 time)
- **Tilbagekaldelse**: `720` blokke (~24 timer)

### Testnet-parametre

**Netvaerksidentitet**:
- **Magic bytes**: `0x6d 0xf2 0x48 0xb4`
- **Standardport**: `18338`
- **Bech32 HRP**: `tpocx`

**Adressepraefixer** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `239`

**Bloktiming**:
- **Bloktidsmal**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- **Tillad min. svaerhed**: `true`

**Blokbeloninger**:
- **Indledende subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokke

**Svaerhedsjustering**:
- **Rullende vindue**: `24` blokke

**Assignment-forsinkelser**:
- **Aktivering**: `30` blokke (~1 time)
- **Tilbagekaldelse**: `720` blokke (~24 timer)

### Regtest-parametre

**Netvaerksidentitet**:
- **Magic bytes**: `0xfa 0xbf 0xb5 0xda`
- **Standardport**: `18444`
- **Bech32 HRP**: `rpocx`

**Adressepraefixer** (Bitcoin-kompatible):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Bloktiming**:
- **Bloktidsmal**: `120` sekunder (mines on demand via `generatetoaddress` i regtest)
- **Maltidsrum**: `86400` sekunder (1 dag)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokbeloninger**:
- **Indledende subsidie**: `10 BTC`
- **Halveringsinterval**: `500` blokke

**Svaerhedsjustering**:
- **Rullende vindue**: `24` blokke
- **Tillad min. svaerhed**: `true`
- **Ingen retargeting**: `true`
- **Lavkapacitetskalibrering**: `true` (bruger 64-nonce kalibrering ≈ 16 MiB i stedet for 1 TiB)

**Assignment-forsinkelser**:
- **Aktivering**: `4` blokke (~8 minutter ved 120s-afstand)
- **Tilbagekaldelse**: `8` blokke (~16 minutter ved 120s-afstand)

### Signet-parametre

**Netvaerksidentitet**:
- **Magic bytes**: Forste 4 bytes af SHA256d(signet_challenge)
- **Standardport**: `38333`
- **Bech32 HRP**: `tpocx`

**Bloktiming**:
- **Bloktidsmal**: `120` sekunder
- **MAX_FUTURE_BLOCK_TIME**: `15` sekunder

**Blokbeloninger**:
- **Indledende subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokke

**Svaerhedsjustering**:
- **Rullende vindue**: `24` blokke

---

## Konsensusparametre

### Timingparametre

**MAX_FUTURE_BLOCK_TIME**: `15` sekunder
- PoCX-specifik (Bitcoin bruger 2 timer)
- Rationale: PoC-timing kraever naer-realtidsvalidering
- Blokke mere end 15s i fremtiden afvises

**Tidsforskydningsadvarsel**: `10` sekunder
- Operatorer advares, nar nodeens ur drifter >10s fra netvaerkstid
- Ingen haandhaevelse, kun informativ

**Bloktidsmal**:
- Mainnet/Testnet/Signet: `120` sekunder
- Regtest: `120` sekunder

**TIMESTAMP_WINDOW**: `15` sekunder (lig med MAX_FUTURE_BLOCK_TIME)

**Implementering**: `src/chain.h`, `src/validation.cpp`

### Svaerhedsjusteringsparametre

**Rullende vinduesstorrelse**: `24` blokke (alle netvaerk)
- Vaegtet glidende gennemsnit af nylige bloktider (Burstcoin-stil)
- Justering ved hver blok
- Responsiv over for kapacitetsaendringer

**Implementering**: `src/consensus/params.h`, svaerhedslogik i blokoprettelse

### Assignment-systemparametre

**nForgingAssignmentDelay** (aktiveringsforsinkelse):
- Mainnet: `30` blokke (~1 time)
- Testnet: `30` blokke (~1 time)
- Regtest: `4` blokke (~8 minutter ved 120s-afstand)

**nForgingRevocationDelay** (tilbagekaldelsesforsinkelse):
- Mainnet: `720` blokke (~24 timer)
- Testnet: `720` blokke (~24 timer)
- Regtest: `8` blokke (~16 minutter ved 120s-afstand)

**Rationale**:
- Aktiveringsforsinkelse forebygger hurtig omtildeling under blokveddelob
- Tilbagekaldelsesforsinkelse giver stabilitet og forebygger misbrug

**Implementering**: `src/consensus/params.h`

---

## Coinbase og blokbeloninger

### Bloksubsidietidsplan

**Indledende subsidie**: `10 BTC` (alle netvaerk)

**Halveringstidsplan**:
- Hver `1050000` blok (mainnet/testnet)
- Hver `500` blok (regtest)
- Fortsaetter i 64 halveringer maksimalt

**Halveringsprogression**:
```
Halvering 0: 10,00000000 BTC  (blokke 0 - 1049999)
Halvering 1:  5,00000000 BTC  (blokke 1050000 - 2099999)
Halvering 2:  2,50000000 BTC  (blokke 2100000 - 3149999)
Halvering 3:  1,25000000 BTC  (blokke 3150000 - 4199999)
...
```

**Samlet forsyning**: ~21 millioner BTC (samme som Bitcoin)

### Coinbase-outputregler

**Betalingsdestination**:
- **Ingen assignment**: Coinbase betaler plotadresse (proof.account_id)
- **Med assignment**: Coinbase betaler forging-adresse (effektiv underskriver)

**Outputformat**: Kun P2WPKH
- Coinbase skal betale til bech32 SegWit v0-adresse
- Genereret fra effektiv underskriverens offentlige nogle

**Assignment-oplosning**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementering**: `src/pocx/mining/block_builder.cpp:BuildBlock()`

---

## Dynamisk skalering

### Skaleringsgraenser

**Formal**: Forg plotgenereringssvaerhedsgrad, efterhanden som netvaerket modnes, for at forebygge kapacitetsinflation

**Struktur**:
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Minimum accepteret niveau
    uint32_t nPoCXTargetCompression;  // Anbefalet niveau
};
```

**Forhold**: `target = min + 1` (altid et niveau over minimum)

### Tidsplan for skaleringsforogelse

Skaleringsniveauer stiger efter **eksponentiel tidsplan** baseret pa halveringsintervaller:

| Tidsperiode | Blokhojde | Halveringer | Min | Mal |
|-------------|-----------|-------------|-----|-----|
| Ar 0-4 | 0 til 1049999 | 0 | X1 | X2 |
| Ar 4-12 | 1050000 til 3149999 | 1-2 | X2 | X3 |
| Ar 12-28 | 3150000 til 7349999 | 3-6 | X3 | X4 |
| Ar 28-60 | 7350000 til 15749999 | 7-14 | X4 | X5 |
| Ar 60-124 | 15750000 til 32549999 | 15-30 | X5 | X6 |
| Ar 124+ | 32550000+ | 31+ | X6 | X7 |

**Noglehojder** (ar -> halveringer -> blokke):
- Ar 4: Halvering 1 ved blok 1050000
- Ar 12: Halvering 3 ved blok 3150000
- Ar 28: Halvering 7 ved blok 7350000
- Ar 60: Halvering 15 ved blok 15750000
- Ar 124: Halvering 31 ved blok 32550000

### Skaleringsniveausvaerhedsgrad

**PoW-skalering**:
- Skaleringsniveau X0: POC2-baseline (teoretisk)
- Skaleringsniveau X1: XOR-transpose-baseline
- Skaleringsniveau Xn: 2^(n-1) x X1-arbejde indlejret
- Hvert niveau fordobler plotgenereringsarbejde

**Okonomisk tilpasning**:
- Blokbeloninger halveres -> plotgenereringssvaerhedsgrad stiger
- Opretholder sikkerhedsmargin: plotoprettelsesomkostning > opslagsomkostning
- Forebygger kapacitetsinflation fra hardwareforbedringer

### Plotvalidering

**Valideringsregler**:
- Indsendte beviser skal have skaleringsniveau >= minimum
- Beviser med skalering > mal accepteres, men er ineffektive
- Beviser under minimum: afvises (utilstraekkelig PoW)

**Graensehentning**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementering**: `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Netvaerkskonfiguration

### Seed-noder og DNS-seeds

**Status**: Aktiv (mainnet aktivt siden 3. maj 2026)

**Mainnet DNS-seeds**:
- `seeds.bitcoin-pocx.org`
- `bitcoin-pocx.bootseed.net`

**Testnet DNS-seeds**:
- `testnet.seeds.bitcoin-pocx.org`

**Konfiguration**:
- Faste seeds leveret i `src/pocx/pocx_seeds.h` (BIP155-format)
- Manuelle peer-forbindelser understottet ogsaa via `-addnode`

**Implementering**: `src/kernel/chainparams.cpp`

### Checkpoints

**Genesis-checkpoint**: Altid blok 0

**Yderligere checkpoints**: Ingen konfigureret i oejeblikket

**Fremtid**: Checkpoints vil blive tilfojet, efterhanden som mainnet skrider frem

---

## P2P-protokolkonfiguration

### Protokolversion

**Base**: Bitcoin Core v30.2-protokol
- **Protokolversion**: Arvet fra Bitcoin Core
- **Servicebits**: Standard Bitcoin-tjenester
- **Meddelelsestyper**: Standard Bitcoin P2P-meddelelser

**PoCX-udvidelser**:
- Blokheadere inkluderer PoCX-specifikke felter
- Blokmeddelelser inkluderer PoCX-bevisdata
- Valideringsregler haandhaever PoCX-konsensus

**Kompatibilitet**: PoCX-noder inkompatible med Bitcoin PoW-noder (forskellig konsensus)

**Implementering**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datamappestruktur

### Standardmappe

**Placering**: `.bitcoin/` (samme som Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Mappeindhold

```
.bitcoin/
-- blocks/              # Blokdata
|   -- blk*.dat        # Blokfiler
|   -- rev*.dat        # Undo-data
|   -- index/          # Blokindeks (LevelDB)
-- chainstate/         # UTXO-saet + forging assignments (LevelDB)
-- wallets/            # Wallet-filer
|   -- wallet.dat      # Standard-wallet
-- bitcoin.conf        # Konfigurationsfil
-- debug.log           # Debug-log
-- peers.dat           # Peer-adresser
-- mempool.dat         # Mempool-persistens
-- banlist.dat         # Bannede peers
```

### Vigtige forskelle fra Bitcoin

**Chainstate-database**:
- Standard: UTXO-saet
- **PoCX-tilojelse**: Forging assignment-tilstand
- Atomare opdateringer: UTXO + assignments opdateres sammen
- Reorg-sikre undo-data til assignments

**Blokfiler**:
- Standard Bitcoin-blokformat
- **PoCX-tilojelse**: Udvidet med PoCX-bevisfelter (account_id, seed, nonce, signatur, pubkey)

### Konfigurationsfileksempel

**bitcoin.conf**:
```ini
# Netvaerksvalg
#testnet=1
#regtest=1

# RPC-indstillinger
server=1
rpcuser=ditbrugernavn
rpcpassword=ditpassword
rpcallowip=127.0.0.1
rpcport=8332

# Forbindelsesindstillinger
listen=1
port=8338
maxconnections=125

# Bloktidsmal (informativ, konsensushaandhaevet)
# 120 sekunder for mainnet/testnet
```

---

## Kodereferencer

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensusparametre**: `src/consensus/params.h`
**Kompressionsgraenser**: `src/pocx/consensus/params.h`, `src/pocx/consensus/params.cpp`
**Genesis base target-beregning**: `src/pocx/consensus/params.cpp`
**Coinbase-betalingslogik**: `src/pocx/mining/block_builder.cpp:BuildBlock()`
**Assignment-tilstandslagring**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-udvidelser)

---

## Krydsreferencer

Relaterede kapitler:
- [Kapitel 2: Plotformat](2-plot-format.md) - Skaleringsniveauer i plotgenerering
- [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md) - Skaleringsvalidering, assignment-system
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Assignment-forsinkelsesparametre
- [Kapitel 5: Timingsikkerhed](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-rationale

---

[<- Forrige: Tidssynkronisering](5-timing-security.md) | [Indholdsfortegnelse](index.md) | [Naeste: RPC-reference ->](7-rpc-reference.md)

[Vorige: Tijdsynchronisatie](5-timing-security.md) | [Inhoudsopgave](index.md) | [Volgende: RPC-referentie](7-rpc-reference.md)

---

# Hoofdstuk 6: Netwerkparameters en configuratie

Volledige referentie voor Bitcoin-PoCX-netwerkconfiguratie over alle netwerktypes.

---

## Inhoudsopgave

1. [Genesisblokparameters](#genesisblokparameters)
2. [Chainparams-configuratie](#chainparams-configuratie)
3. [Consensusparameters](#consensusparameters)
4. [Coinbase en blokbeloningen](#coinbase-en-blokbeloningen)
5. [Dynamische schaling](#dynamische-schaling)
6. [Netwerkconfiguratie](#netwerkconfiguratie)
7. [Datamap-structuur](#datamap-structuur)

---

## Genesisblokparameters

### Base target-berekening

**Formule**: `genesis_base_target = 2^42 / block_time_seconden`

**Rationale**:
- Elke nonce vertegenwoordigt 256 KiB (64 bytes x 4096 scoops)
- 1 TiB = 2^22 nonces (aangenomen startnetwerkcapaciteit)
- Verwachte minimumkwaliteit voor n nonces ≈ 2^64 / n
- Voor 1 TiB: E(kwaliteit) = 2^64 / 2^22 = 2^42
- Daarom: base_target = 2^42 / bloktijd

**Berekende waarden**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Gebruikt lage-capaciteitskalibratiemodus

### Genesisbericht

Alle netwerken delen het Bitcoin-genesisbericht:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementatie**: `src/kernel/chainparams.cpp`

---

## Chainparams-configuratie

### Mainnet-parameters

**Netwerkidentiteit**:
- **Magic bytes**: `0xa7 0x3c 0x91 0x5e`
- **Standaardpoort**: `8888`
- **Bech32 HRP**: `pocx`

**Adresvoorvoegsels** (Base58):
- PUBKEY_ADDRESS: `85` (adressen beginnen met 'P')
- SCRIPT_ADDRESS: `90` (adressen beginnen met 'R')
- SECRET_KEY: `128`

**Bloktiming**:
- **Bloktijddoel**: `120` seconden (2 minuten)
- **Doeltijdspanne**: `1209600` seconden (14 dagen)
- **MAX_FUTURE_BLOCK_TIME**: `15` seconden

**Blokbeloningen**:
- **Initiele subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokken (~4 jaar)
- **Halveringsaantal**: Maximaal 64 halveringen

**Moeilijkheidsaanpassing**:
- **Rollend venster**: `24` blokken
- **Aanpassing**: Elk blok
- **Algoritme**: Exponentieel voortschrijdend gemiddelde

**Toewijzingsvertragingen**:
- **Activering**: `30` blokken (~1 uur)
- **Intrekking**: `720` blokken (~24 uur)

### Testnet-parameters

**Netwerkidentiteit**:
- **Magic bytes**: `0x6d 0xf2 0x48 0xb3`
- **Standaardpoort**: `18888`
- **Bech32 HRP**: `tpocx`

**Adresvoorvoegsels** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Bloktiming**:
- **Bloktijddoel**: `120` seconden
- **MAX_FUTURE_BLOCK_TIME**: `15` seconden
- **Sta minimummoeilijkheid toe**: `true`

**Blokbeloningen**:
- **Initiele subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokken

**Moeilijkheidsaanpassing**:
- **Rollend venster**: `24` blokken

**Toewijzingsvertragingen**:
- **Activering**: `30` blokken (~1 uur)
- **Intrekking**: `720` blokken (~24 uur)

### Regtest-parameters

**Netwerkidentiteit**:
- **Magic bytes**: `0xfa 0xbf 0xb5 0xda`
- **Standaardpoort**: `18444`
- **Bech32 HRP**: `rpocx`

**Adresvoorvoegsels** (Bitcoin-compatibel):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Bloktiming**:
- **Bloktijddoel**: `1` seconde (instant mining voor testen)
- **Doeltijdspanne**: `86400` seconden (1 dag)
- **MAX_FUTURE_BLOCK_TIME**: `15` seconden

**Blokbeloningen**:
- **Initiele subsidie**: `10 BTC`
- **Halveringsinterval**: `500` blokken

**Moeilijkheidsaanpassing**:
- **Rollend venster**: `24` blokken
- **Sta minimummoeilijkheid toe**: `true`
- **Geen hertargeting**: `true`
- **Lage-capaciteitskalibratie**: `true` (gebruikt 16-nonce kalibratie in plaats van 1 TiB)

**Toewijzingsvertragingen**:
- **Activering**: `4` blokken (~4 seconden)
- **Intrekking**: `8` blokken (~8 seconden)

### Signet-parameters

**Netwerkidentiteit**:
- **Magic bytes**: Eerste 4 bytes van SHA256d(signet_challenge)
- **Standaardpoort**: `38333`
- **Bech32 HRP**: `tpocx`

**Bloktiming**:
- **Bloktijddoel**: `120` seconden
- **MAX_FUTURE_BLOCK_TIME**: `15` seconden

**Blokbeloningen**:
- **Initiele subsidie**: `10 BTC`
- **Halveringsinterval**: `1050000` blokken

**Moeilijkheidsaanpassing**:
- **Rollend venster**: `24` blokken

---

## Consensusparameters

### Timingparameters

**MAX_FUTURE_BLOCK_TIME**: `15` seconden
- PoCX-specifiek (Bitcoin gebruikt 2 uur)
- Rationale: PoC-timing vereist near real-time validatie
- Blokken meer dan 15s in de toekomst worden afgewezen

**Tijdsverschuivingswaarschuwing**: `10` seconden
- Operators worden gewaarschuwd wanneer nodeklok >10s van netwerktijd afwijkt
- Geen handhaving, alleen informatief

**Bloktijddoelen**:
- Mainnet/Testnet/Signet: `120` seconden
- Regtest: `1` seconde

**TIMESTAMP_WINDOW**: `15` seconden (gelijk aan MAX_FUTURE_BLOCK_TIME)

**Implementatie**: `src/chain.h`, `src/validation.cpp`

### Moeilijkheidsaanpassingsparameters

**Rollend venstergrootte**: `24` blokken (alle netwerken)
- Exponentieel voortschrijdend gemiddelde van recente bloktijden
- Aanpassing elk blok
- Responsief op capaciteitswijzigingen

**Implementatie**: `src/consensus/params.h`, moeilijkheidslogica in blokcreatie

### Toewijzingssysteemparameters

**nForgingAssignmentDelay** (activeringsvertraging):
- Mainnet: `30` blokken (~1 uur)
- Testnet: `30` blokken (~1 uur)
- Regtest: `4` blokken (~4 seconden)

**nForgingRevocationDelay** (intrekkingsvertraging):
- Mainnet: `720` blokken (~24 uur)
- Testnet: `720` blokken (~24 uur)
- Regtest: `8` blokken (~8 seconden)

**Rationale**:
- Activeringsvertraging voorkomt snelle hertoewijzing tijdens blokraces
- Intrekkingsvertraging biedt stabiliteit en voorkomt misbruik

**Implementatie**: `src/consensus/params.h`

---

## Coinbase en blokbeloningen

### Bloksubsidieschema

**Initiele subsidie**: `10 BTC` (alle netwerken)

**Halveringsschema**:
- Elke `1050000` blokken (mainnet/testnet)
- Elke `500` blokken (regtest)
- Gaat door voor maximaal 64 halveringen

**Halveringsprogressie**:
```
Halvering 0: 10,00000000 BTC  (blokken 0 - 1049999)
Halvering 1:  5,00000000 BTC  (blokken 1050000 - 2099999)
Halvering 2:  2,50000000 BTC  (blokken 2100000 - 3149999)
Halvering 3:  1,25000000 BTC  (blokken 3150000 - 4199999)
...
```

**Totale voorraad**: ~21 miljoen BTC (zelfde als Bitcoin)

### Coinbase-uitvoerregels

**Betalingsbestemming**:
- **Geen toewijzing**: Coinbase betaalt plotadres (proof.account_id)
- **Met toewijzing**: Coinbase betaalt forgingadres (effectieve ondertekenaar)

**Uitvoerformaat**: Alleen P2WPKH
- Coinbase moet betalen aan bech32 SegWit v0-adres
- Gegenereerd uit publieke sleutel van effectieve ondertekenaar

**Toewijzingsresolutie**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementatie**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamische schaling

### Schaalgrenzen

**Doel**: Verhoog plotgeneratiemoeilijkheid naarmate netwerk volwassen wordt om capaciteitsinflatie te voorkomen

**Structuur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum geaccepteerd niveau
    uint8_t nPoCXTargetCompression;  // Aanbevolen niveau
};
```

**Relatie**: `target = min + 1` (altijd een niveau boven minimum)

### Schema voor schaalverhoging

Schaalniveaus nemen toe volgens **exponentieel schema** gebaseerd op halveringsintervallen:

| Tijdsperiode | Blokhoogte | Halveringen | Min | Doel |
|--------------|------------|-------------|-----|------|
| Jaren 0-4 | 0 tot 1049999 | 0 | X1 | X2 |
| Jaren 4-12 | 1050000 tot 3149999 | 1-2 | X2 | X3 |
| Jaren 12-28 | 3150000 tot 7349999 | 3-6 | X3 | X4 |
| Jaren 28-60 | 7350000 tot 15749999 | 7-14 | X4 | X5 |
| Jaren 60-124 | 15750000 tot 32549999 | 15-30 | X5 | X6 |
| Jaren 124+ | 32550000+ | 31+ | X6 | X7 |

**Belangrijke hoogtes** (jaren -> halveringen -> blokken):
- Jaar 4: Halvering 1 bij blok 1050000
- Jaar 12: Halvering 3 bij blok 3150000
- Jaar 28: Halvering 7 bij blok 7350000
- Jaar 60: Halvering 15 bij blok 15750000
- Jaar 124: Halvering 31 bij blok 32550000

### Schaalniveaumoeilijkheid

**PoW-schaling**:
- Schaalniveau X0: POC2-basislijn (theoretisch)
- Schaalniveau X1: XOR-transpose-basislijn
- Schaalniveau Xn: 2^(n-1) x X1-werk ingebed
- Elk niveau verdubbelt plotgeneratiewerk

**Economische afstemming**:
- Blokbeloningen halveren -> plotgeneratiemoeilijkheid neemt toe
- Behoudt veiligheidsmarge: plotcreatiekosten > opzoekkosten
- Voorkomt capaciteitsinflatie door hardwareverbeteringen

### Plotvalidatie

**Validatieregels**:
- Ingediende bewijzen moeten schaalniveau >= minimum hebben
- Bewijzen met schaling > doel worden geaccepteerd maar zijn inefficient
- Bewijzen onder minimum: afgewezen (onvoldoende PoW)

**Grenzenophaling**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementatie**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Netwerkconfiguratie

### Seed-nodes en DNS-seeds

**Status**: Placeholder voor mainnet-lancering

**Geplande configuratie**:
- Seed-nodes: Nog te bepalen
- DNS-seeds: Nog te bepalen

**Huidige status** (testnet/regtest):
- Geen toegewijde seed-infrastructuur
- Handmatige peerverbindingen ondersteund via `-addnode`

**Implementatie**: `src/kernel/chainparams.cpp`

### Checkpoints

**Genesischeckpoint**: Altijd blok 0

**Aanvullende checkpoints**: Momenteel geen geconfigureerd

**Toekomst**: Checkpoints worden toegevoegd naarmate mainnet vordert

---

## P2P-protocolconfiguratie

### Protocolversie

**Basis**: Bitcoin Core v30.0-protocol
- **Protocolversie**: Geerfd van Bitcoin Core
- **Servicebits**: Standaard Bitcoin-services
- **Berichttypes**: Standaard Bitcoin P2P-berichten

**PoCX-extensies**:
- Blokheaders bevatten PoCX-specifieke velden
- Blokberichten bevatten PoCX-bewijsgegevens
- Validatieregels handhaven PoCX-consensus

**Compatibiliteit**: PoCX-nodes incompatibel met Bitcoin PoW-nodes (verschillende consensus)

**Implementatie**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datamap-structuur

### Standaardmap

**Locatie**: `.bitcoin/` (zelfde als Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Mapinhoud

```
.bitcoin/
├── blocks/              # Blokgegevens
│   ├── blk*.dat        # Blokbestanden
│   ├── rev*.dat        # Undo-gegevens
│   └── index/          # Blokindex (LevelDB)
├── chainstate/         # UTXO-set + forging-toewijzingen (LevelDB)
├── wallets/            # Walletbestanden
│   └── wallet.dat      # Standaardwallet
├── bitcoin.conf        # Configuratiebestand
├── debug.log           # Debug-log
├── peers.dat           # Peeradressen
├── mempool.dat         # Mempool-persistentie
└── banlist.dat         # Verbannen peers
```

### Belangrijke verschillen met Bitcoin

**Chainstate-database**:
- Standaard: UTXO-set
- **PoCX-toevoeging**: Forging-toewijzingsstatus
- Atomische updates: UTXO + toewijzingen samen bijgewerkt
- Reorg-veilige undo-gegevens voor toewijzingen

**Blokbestanden**:
- Standaard Bitcoin-blokformaat
- **PoCX-toevoeging**: Uitgebreid met PoCX-bewijsvelden (account_id, seed, nonce, handtekening, pubkey)

### Configuratiebestandvoorbeeld

**bitcoin.conf**:
```ini
# Netwerkselectie
#testnet=1
#regtest=1

# PoCX miningserver (vereist voor externe miners)
miningserver=1

# RPC-instellingen
server=1
rpcuser=uwgebruikersnaam
rpcpassword=uwwachtwoord
rpcallowip=127.0.0.1
rpcport=8332

# Verbindingsinstellingen
listen=1
port=8888
maxconnections=125

# Bloktijddoel (informatief, consensus afgedwongen)
# 120 seconden voor mainnet/testnet
```

---

## Codereferenties

**Chainparams**: `src/kernel/chainparams.cpp`
**Consensusparameters**: `src/consensus/params.h`
**Compressiegrenzen**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis base target-berekening**: `src/pocx/consensus/params.cpp`
**Coinbase-betalingslogica**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Toewijzingsstatusopslag**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-extensies)

---

## Kruisverwijzingen

Gerelateerde hoofdstukken:
- [Hoofdstuk 2: Plotformaat](2-plot-format.md) - Schaalniveaus in plotgeneratie
- [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md) - Schaalvalidatie, toewijzingssysteem
- [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md) - Toewijzingsvertragingsparameters
- [Hoofdstuk 5: Timingbeveiliging](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-rationale

---

[Vorige: Tijdsynchronisatie](5-timing-security.md) | [Inhoudsopgave](index.md) | [Volgende: RPC-referentie](7-rpc-reference.md)

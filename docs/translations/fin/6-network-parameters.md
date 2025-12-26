[← Edellinen: Aikasynkronointi](5-timing-security.md) | [Sisällysluettelo](index.md) | [Seuraava: RPC-viite →](7-rpc-reference.md)

---

# Luku 6: Verkkoparametrit ja konfiguraatio

Täydellinen viite Bitcoin-PoCX-verkon konfiguraatiolle kaikille verkkotyypeille.

---

## Sisällysluettelo

1. [Genesis-lohkon parametrit](#genesis-lohkon-parametrit)
2. [Chainparams-konfiguraatio](#chainparams-konfiguraatio)
3. [Konsensusparametrit](#konsensusparametrit)
4. [Coinbase ja lohkopalkkiot](#coinbase-ja-lohkopalkkiot)
5. [Dynaaminen skaalaus](#dynaaminen-skaalaus)
6. [Verkkokonfiguraatio](#verkkokonfiguraatio)
7. [Datahakemiston rakenne](#datahakemiston-rakenne)

---

## Genesis-lohkon parametrit

### Perustavoitteen laskenta

**Kaava**: `genesis_base_target = 2^42 / block_time_seconds`

**Perustelu**:
- Jokainen nonce edustaa 256 KiB:tä (64 tavua × 4096 scooopia)
- 1 TiB = 2^22 noncea (oletettu verkon aloituskapasiteetti)
- Odotettu vähimmäislaatu n noncelle ≈ 2^64 / n
- 1 TiB:lle: E(quality) = 2^64 / 2^22 = 2^42
- Täten: base_target = 2^42 / block_time

**Lasketut arvot**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Käyttää matalan kapasiteetin kalibrointitilaa

### Genesis-viesti

Kaikki verkot jakavat Bitcoinin genesis-viestin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Toteutus**: `src/kernel/chainparams.cpp`

---

## Chainparams-konfiguraatio

### Mainnet-parametrit

**Verkon identiteetti**:
- **Magiikkatavut**: `0xa7 0x3c 0x91 0x5e`
- **Oletusportti**: `8888`
- **Bech32 HRP**: `pocx`

**Osoite-etuliitteet** (Base58):
- PUBKEY_ADDRESS: `85` (osoitteet alkavat 'P')
- SCRIPT_ADDRESS: `90` (osoitteet alkavat 'R')
- SECRET_KEY: `128`

**Lohkoajoitus**:
- **Lohkoajan tavoite**: `120` sekuntia (2 minuuttia)
- **Tavoiteaikaväli**: `1209600` sekuntia (14 päivää)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekuntia

**Lohkopalkkiot**:
- **Alkuperäinen palkkio**: `10 BTC`
- **Puolittumisväli**: `1050000` lohkoa (~4 vuotta)
- **Puolittumismäärä**: Maksimissaan 64 puolittumista

**Vaikeuden säätö**:
- **Liukuva ikkuna**: `24` lohkoa
- **Säätö**: Joka lohko
- **Algoritmi**: Eksponentiaalinen liukuva keskiarvo

**Delegointiviiveet**:
- **Aktivointi**: `30` lohkoa (~1 tunti)
- **Peruutus**: `720` lohkoa (~24 tuntia)

### Testnet-parametrit

**Verkon identiteetti**:
- **Magiikkatavut**: `0x6d 0xf2 0x48 0xb3`
- **Oletusportti**: `18888`
- **Bech32 HRP**: `tpocx`

**Osoite-etuliitteet** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Lohkoajoitus**:
- **Lohkoajan tavoite**: `120` sekuntia
- **MAX_FUTURE_BLOCK_TIME**: `15` sekuntia
- **Salli minimivaikeus**: `true`

**Lohkopalkkiot**:
- **Alkuperäinen palkkio**: `10 BTC`
- **Puolittumisväli**: `1050000` lohkoa

**Vaikeuden säätö**:
- **Liukuva ikkuna**: `24` lohkoa

**Delegointiviiveet**:
- **Aktivointi**: `30` lohkoa (~1 tunti)
- **Peruutus**: `720` lohkoa (~24 tuntia)

### Regtest-parametrit

**Verkon identiteetti**:
- **Magiikkatavut**: `0xfa 0xbf 0xb5 0xda`
- **Oletusportti**: `18444`
- **Bech32 HRP**: `rpocx`

**Osoite-etuliitteet** (Bitcoin-yhteensopiva):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Lohkoajoitus**:
- **Lohkoajan tavoite**: `1` sekunti (välitön louhinta testaukseen)
- **Tavoiteaikaväli**: `86400` sekuntia (1 päivä)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekuntia

**Lohkopalkkiot**:
- **Alkuperäinen palkkio**: `10 BTC`
- **Puolittumisväli**: `500` lohkoa

**Vaikeuden säätö**:
- **Liukuva ikkuna**: `24` lohkoa
- **Salli minimivaikeus**: `true`
- **Ei uudelleenkohdennusta**: `true`
- **Matalan kapasiteetin kalibrointi**: `true` (käyttää 16 noncen kalibrointia 1 TiB:n sijaan)

**Delegointiviiveet**:
- **Aktivointi**: `4` lohkoa (~4 sekuntia)
- **Peruutus**: `8` lohkoa (~8 sekuntia)

### Signet-parametrit

**Verkon identiteetti**:
- **Magiikkatavut**: SHA256d(signet_challenge):n ensimmäiset 4 tavua
- **Oletusportti**: `38333`
- **Bech32 HRP**: `tpocx`

**Lohkoajoitus**:
- **Lohkoajan tavoite**: `120` sekuntia
- **MAX_FUTURE_BLOCK_TIME**: `15` sekuntia

**Lohkopalkkiot**:
- **Alkuperäinen palkkio**: `10 BTC`
- **Puolittumisväli**: `1050000` lohkoa

**Vaikeuden säätö**:
- **Liukuva ikkuna**: `24` lohkoa

---

## Konsensusparametrit

### Ajoitusparametrit

**MAX_FUTURE_BLOCK_TIME**: `15` sekuntia
- PoCX-spesifinen (Bitcoin käyttää 2 tuntia)
- Perustelu: PoC-ajoitus vaatii lähes reaaliaikaisen validoinnin
- Yli 15s tulevaisuudessa olevat lohkot hylätään

**Aikaeron varoitus**: `10` sekuntia
- Operaattoreita varoitetaan kun solmun kello ajautuu >10s verkkoajasta
- Ei pakoteta, vain tiedoksi

**Lohkoajan tavoitteet**:
- Mainnet/Testnet/Signet: `120` sekuntia
- Regtest: `1` sekunti

**TIMESTAMP_WINDOW**: `15` sekuntia (yhtä suuri kuin MAX_FUTURE_BLOCK_TIME)

**Toteutus**: `src/chain.h`, `src/validation.cpp`

### Vaikeuden säätöparametrit

**Liukuvan ikkunan koko**: `24` lohkoa (kaikki verkot)
- Viimeaikaisten lohkoaikojen eksponentiaalinen liukuva keskiarvo
- Säätö joka lohkossa
- Reagoi kapasiteetin muutoksiin

**Toteutus**: `src/consensus/params.h`, vaikeuslogiikka lohkon luonnissa

### Delegointijärjestelmän parametrit

**nForgingAssignmentDelay** (aktivointiviive):
- Mainnet: `30` lohkoa (~1 tunti)
- Testnet: `30` lohkoa (~1 tunti)
- Regtest: `4` lohkoa (~4 sekuntia)

**nForgingRevocationDelay** (peruutusviive):
- Mainnet: `720` lohkoa (~24 tuntia)
- Testnet: `720` lohkoa (~24 tuntia)
- Regtest: `8` lohkoa (~8 sekuntia)

**Perustelu**:
- Aktivointiviive estää nopean uudelleendelegoinnin lohkokisojen aikana
- Peruutusviive tarjoaa vakautta ja estää väärinkäytön

**Toteutus**: `src/consensus/params.h`

---

## Coinbase ja lohkopalkkiot

### Lohkopalkkioaikataulu

**Alkuperäinen palkkio**: `10 BTC` (kaikki verkot)

**Puolittumisaikataulu**:
- Joka `1050000` lohko (mainnet/testnet)
- Joka `500` lohko (regtest)
- Jatkuu maksimissaan 64 puolittumista

**Puolittumisen eteneminen**:
```
Puolittuminen 0: 10.00000000 BTC  (lohkot 0 - 1049999)
Puolittuminen 1:  5.00000000 BTC  (lohkot 1050000 - 2099999)
Puolittuminen 2:  2.50000000 BTC  (lohkot 2100000 - 3149999)
Puolittuminen 3:  1.25000000 BTC  (lohkot 3150000 - 4199999)
...
```

**Kokonaistarjonta**: ~21 miljoonaa BTC (sama kuin Bitcoin)

### Coinbase-tulosteen säännöt

**Maksun kohde**:
- **Ei delegointia**: Coinbase maksaa plotin osoitteelle (proof.account_id)
- **Delegoinnilla**: Coinbase maksaa forging-osoitteelle (tehokas allekirjoittaja)

**Tulostemuoto**: Vain P2WPKH
- Coinbasen on maksettava bech32 SegWit v0 -osoitteelle
- Generoidaan tehokkaan allekirjoittajan julkisesta avaimesta

**Delegoinnin ratkaisu**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Toteutus**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynaaminen skaalaus

### Skaalausrajat

**Tarkoitus**: Kasvattaa plotin generoinnin vaikeutta verkon kypsyessä kapasiteetti-inflaation estämiseksi

**Rakenne**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Vähimmäishyväksytty taso
    uint8_t nPoCXTargetCompression;  // Suositeltu taso
};
```

**Suhde**: `tavoite = minimi + 1` (aina yksi taso minimin yläpuolella)

### Skaalauksen kasvatusaikataulu

Skaalaustasot kasvavat **eksponentiaalisella aikataululla** puolittumisvälejen perusteella:

| Aikajakso | Lohkon korkeus | Puolittumisia | Minimi | Tavoite |
|-------------|--------------|----------|-----|--------|
| Vuodet 0-4 | 0 - 1049999 | 0 | X1 | X2 |
| Vuodet 4-12 | 1050000 - 3149999 | 1-2 | X2 | X3 |
| Vuodet 12-28 | 3150000 - 7349999 | 3-6 | X3 | X4 |
| Vuodet 28-60 | 7350000 - 15749999 | 7-14 | X4 | X5 |
| Vuodet 60-124 | 15750000 - 32549999 | 15-30 | X5 | X6 |
| Vuodet 124+ | 32550000+ | 31+ | X6 | X7 |

**Avainkorkedet** (vuodet → puolittumisia → lohkoja):
- Vuosi 4: Puolittuminen 1 lohkossa 1050000
- Vuosi 12: Puolittuminen 3 lohkossa 3150000
- Vuosi 28: Puolittuminen 7 lohkossa 7350000
- Vuosi 60: Puolittuminen 15 lohkossa 15750000
- Vuosi 124: Puolittuminen 31 lohkossa 32550000

### Skaalaustason vaikeus

**PoW-skaalaus**:
- Skaalaustaso X0: POC2-perustaso (teoreettinen)
- Skaalaustaso X1: XOR-transpose-perustaso
- Skaalaustaso Xn: 2^(n-1) × X1-työ upotettuna
- Jokainen taso kaksinkertaistaa plotin generoinnin työn

**Taloudellinen yhdenmukaistaminen**:
- Lohkopalkkiot puolittuvat → plotin generoinnin vaikeus kasvaa
- Ylläpitää turvamarginaalia: plotin luontikustannus > hakukustannus
- Estää kapasiteetti-inflaation laitteistoparannuksista

### Plotin validointi

**Validointisäännöt**:
- Lähetettyjen todisteiden skaalaustason on oltava ≥ minimi
- Todisteet skaalauksella > tavoite hyväksytään mutta ovat tehottomia
- Todisteet alle minimin: hylätään (riittämätön PoW)

**Rajojen haku**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Toteutus**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Verkkokonfiguraatio

### Seed-solmut ja DNS-seedit

**Tila**: Paikkamerkki mainnetin käynnistystä varten

**Suunniteltu konfiguraatio**:
- Seed-solmut: Määritettävä
- DNS-seedit: Määritettävä

**Nykyinen tila** (testnet/regtest):
- Ei omistettua seed-infrastruktuuria
- Manuaaliset vertaisyhteydet tuettu `-addnode`-parametrilla

**Toteutus**: `src/kernel/chainparams.cpp`

### Tarkistuspisteet

**Genesis-tarkistuspiste**: Aina lohko 0

**Lisätarkistuspisteet**: Ei tällä hetkellä konfiguroitu

**Tulevaisuus**: Tarkistuspisteitä lisätään mainnetin edetessä

---

## P2P-protokollan konfiguraatio

### Protokollaversio

**Pohja**: Bitcoin Core v30.0 -protokolla
- **Protokollaversio**: Peritty Bitcoin Coresta
- **Palvelubitit**: Vakio Bitcoin-palvelut
- **Viestitypit**: Vakio Bitcoin P2P -viestit

**PoCX-laajennukset**:
- Lohko-otsikot sisältävät PoCX-spesifiset kentät
- Lohkoviestit sisältävät PoCX-todisteen datan
- Validointisäännöt pakottavat PoCX-konsensuksen

**Yhteensopivuus**: PoCX-solmut eivät ole yhteensopivia Bitcoin PoW -solmujen kanssa (eri konsensus)

**Toteutus**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datahakemiston rakenne

### Oletushakemisto

**Sijainti**: `.bitcoin/` (sama kuin Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Hakemiston sisältö

```
.bitcoin/
├── blocks/              # Lohkodata
│   ├── blk*.dat        # Lohkotiedostot
│   ├── rev*.dat        # Kumoamisdata
│   └── index/          # Lohkoindeksi (LevelDB)
├── chainstate/         # UTXO-joukko + forging-delegoinnit (LevelDB)
├── wallets/            # Lompakkotiedostot
│   └── wallet.dat      # Oletuslompakko
├── bitcoin.conf        # Konfiguraatiotiedosto
├── debug.log           # Debug-loki
├── peers.dat           # Vertaisosoitteet
├── mempool.dat         # Mempoolin pysyvyys
└── banlist.dat         # Estetyt vertaiset
```

### Keskeiset erot Bitcoiniin

**Chainstate-tietokanta**:
- Vakio: UTXO-joukko
- **PoCX-lisäys**: Forging-delegointien tila
- Atomiset päivitykset: UTXO + delegoinnit päivitetään yhdessä
- Reorg-turvallinen kumoamisdata delegoinneille

**Lohkotiedostot**:
- Vakio Bitcoin-lohkomuoto
- **PoCX-lisäys**: Laajennettu PoCX-todistekentillä (account_id, seed, nonce, allekirjoitus, pubkey)

### Esimerkki konfiguraatiotiedostosta

**bitcoin.conf**:
```ini
# Verkon valinta
#testnet=1
#regtest=1

# PoCX-louhintapalvelin (vaaditaan ulkoisille louhijoille)
miningserver=1

# RPC-asetukset
server=1
rpcuser=käyttäjänimesi
rpcpassword=salasanasi
rpcallowip=127.0.0.1
rpcport=8332

# Yhteysasetukset
listen=1
port=8888
maxconnections=125

# Lohkoajan tavoite (tiedoksi, konsensus pakottaa)
# 120 sekuntia mainnet/testnet
```

---

## Koodiviittaukset

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensusparametrit**: `src/consensus/params.h`
**Pakkausrajat**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis-perustavoitteen laskenta**: `src/pocx/consensus/params.cpp`
**Coinbase-maksulogiikka**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Delegointitilan tallennus**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache-laajennukset)

---

## Ristiviittaukset

Liittyvät luvut:
- [Luku 2: Plottimuoto](2-plot-format.md) - Skaalaustasot plotin generoinnissa
- [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md) - Skaalauksen validointi, delegointijärjestelmä
- [Luku 4: Forging-delegoinnit](4-forging-assignments.md) - Delegoinnin viiveparametrit
- [Luku 5: Aikasynkronointi ja turvallisuus](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME-perustelu

---

[← Edellinen: Aikasynkronointi](5-timing-security.md) | [Sisällysluettelo](index.md) | [Seuraava: RPC-viite →](7-rpc-reference.md)

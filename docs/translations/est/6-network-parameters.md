[<- Eelmine: Ajasünkroniseerimine](5-timing-security.md) | [Sisukord](index.md) | [Järgmine: RPC viide ->](7-rpc-reference.md)

---

# Peatükk 6: Võrguparameetrid ja konfiguratsioon

Täielik viide Bitcoin-PoCX võrgu konfiguratsioonile kõigis võrgutüüpides.

---

## Sisukord

1. [Geneesisploki parameetrid](#geneesisploki-parameetrid)
2. [Chainparams konfiguratsioon](#chainparams-konfiguratsioon)
3. [Konsensuse parameetrid](#konsensuse-parameetrid)
4. [Coinbase ja plokitasud](#coinbase-ja-plokitasud)
5. [Dünaamiline skaleerimine](#dünaamiline-skaleerimine)
6. [Võrgu konfiguratsioon](#võrgu-konfiguratsioon)
7. [Andmekataloogi struktuur](#andmekataloogi-struktuur)

---

## Geneesisploki parameetrid

### Baassihtmärgi arvutamine

**Valem**: `genesis_base_target = 2^42 / block_time_seconds`

**Põhjendus**:
- Iga nonce esindab 256 KiB (64 baiti × 4096 scoop'i)
- 1 TiB = 2^22 nonce (eeldatav võrgu algne maht)
- Eeldatav minimaalne kvaliteet n nonce jaoks ≈ 2^64 / n
- 1 TiB jaoks: E(quality) = 2^64 / 2^22 = 2^42
- Seega: base_target = 2^42 / block_time

**Arvutatud väärtused**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Kasutab madala mahtuvuse kalibreerimisrežiimi

### Genesisiteade

Kõik võrgud jagavad Bitcoin'i geneesisteadet:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementatsioon**: `src/kernel/chainparams.cpp`

---

## Chainparams konfiguratsioon

### Mainnet parameetrid

**Võrgu identiteet**:
- **Maagilised baidid**: `0xa7 0x3c 0x91 0x5e`
- **Vaikeport**: `8888`
- **Bech32 HRP**: `pocx`

**Aadressi prefiksid** (Base58):
- PUBKEY_ADDRESS: `85` (aadressid algavad 'P'-ga)
- SCRIPT_ADDRESS: `90` (aadressid algavad 'R'-ga)
- SECRET_KEY: `128`

**Ploki ajastus**:
- **Plokkide aja sihtmärk**: `120` sekundit (2 minutit)
- **Siht-ajavahemik**: `1209600` sekundit (14 päeva)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundit

**Ploki tasud**:
- **Algne subsiidium**: `10 BTC`
- **Poolnemise intervall**: `1050000` plokki (~4 aastat)
- **Poolnemiste arv**: Maksimaalselt 64 poolnemist

**Raskuse kohandamine**:
- **Libisev aken**: `24` plokki
- **Kohandamine**: Igal plokil
- **Algoritm**: Eksponentsiaalne libisev keskmine

**Ülesannete viivitused**:
- **Aktiveerimine**: `30` plokki (~1 tund)
- **Tühistamine**: `720` plokki (~24 tundi)

### Testnet parameetrid

**Võrgu identiteet**:
- **Maagilised baidid**: `0x6d 0xf2 0x48 0xb3`
- **Vaikeport**: `18888`
- **Bech32 HRP**: `tpocx`

**Aadressi prefiksid** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Ploki ajastus**:
- **Plokkide aja sihtmärk**: `120` sekundit
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundit
- **Luba min raskus**: `true`

**Ploki tasud**:
- **Algne subsiidium**: `10 BTC`
- **Poolnemise intervall**: `1050000` plokki

**Raskuse kohandamine**:
- **Libisev aken**: `24` plokki

**Ülesannete viivitused**:
- **Aktiveerimine**: `30` plokki (~1 tund)
- **Tühistamine**: `720` plokki (~24 tundi)

### Regtest parameetrid

**Võrgu identiteet**:
- **Maagilised baidid**: `0xfa 0xbf 0xb5 0xda`
- **Vaikeport**: `18444`
- **Bech32 HRP**: `rpocx`

**Aadressi prefiksid** (Bitcoin-ühilduv):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Ploki ajastus**:
- **Plokkide aja sihtmärk**: `1` sekund (kohene kaevandamine testimiseks)
- **Siht-ajavahemik**: `86400` sekundit (1 päev)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundit

**Ploki tasud**:
- **Algne subsiidium**: `10 BTC`
- **Poolnemise intervall**: `500` plokki

**Raskuse kohandamine**:
- **Libisev aken**: `24` plokki
- **Luba min raskus**: `true`
- **Pole ümbersihtimist**: `true`
- **Madala mahtuvuse kalibreerimine**: `true` (kasutab 16-nonce kalibreerimist 1 TiB asemel)

**Ülesannete viivitused**:
- **Aktiveerimine**: `4` plokki (~4 sekundit)
- **Tühistamine**: `8` plokki (~8 sekundit)

### Signet parameetrid

**Võrgu identiteet**:
- **Maagilised baidid**: SHA256d(signet_challenge) esimesed 4 baiti
- **Vaikeport**: `38333`
- **Bech32 HRP**: `tpocx`

**Ploki ajastus**:
- **Plokkide aja sihtmärk**: `120` sekundit
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundit

**Ploki tasud**:
- **Algne subsiidium**: `10 BTC`
- **Poolnemise intervall**: `1050000` plokki

**Raskuse kohandamine**:
- **Libisev aken**: `24` plokki

---

## Konsensuse parameetrid

### Ajastuse parameetrid

**MAX_FUTURE_BLOCK_TIME**: `15` sekundit
- PoCX-spetsiifiline (Bitcoin kasutab 2 tundi)
- Põhjendus: PoC ajastus nõuab peaaegu reaalajas valideerimist
- Plokid rohkem kui 15s tulevikus lükatakse tagasi

**Ajanihe hoiatus**: `10` sekundit
- Operaatoreid hoiatatakse, kui sõlme kell nihkub >10s võrguajast
- Pole jõustamist, ainult informatsiooniline

**Plokkide aja sihtmärgid**:
- Mainnet/Testnet/Signet: `120` sekundit
- Regtest: `1` sekund

**TIMESTAMP_WINDOW**: `15` sekundit (võrdub MAX_FUTURE_BLOCK_TIME-ga)

**Implementatsioon**: `src/chain.h`, `src/validation.cpp`

### Raskuse kohandamise parameetrid

**Libiseva akna suurus**: `24` plokki (kõik võrgud)
- Hiljutiste plokkide aegade eksponentsiaalne libisev keskmine
- Kohandamine igal plokil
- Reageerib mahu muutustele

**Implementatsioon**: `src/consensus/params.h`, raskuse loogika ploki loomisel

### Ülesannete süsteemi parameetrid

**nForgingAssignmentDelay** (aktiveerimise viivitus):
- Mainnet: `30` plokki (~1 tund)
- Testnet: `30` plokki (~1 tund)
- Regtest: `4` plokki (~4 sekundit)

**nForgingRevocationDelay** (tühistamise viivitus):
- Mainnet: `720` plokki (~24 tundi)
- Testnet: `720` plokki (~24 tundi)
- Regtest: `8` plokki (~8 sekundit)

**Põhjendus**:
- Aktiveerimise viivitus takistab kiiret ümberseadistamist plokkide võidujooksude ajal
- Tühistamise viivitus tagab stabiilsuse ja takistab kuritarvitamist

**Implementatsioon**: `src/consensus/params.h`

---

## Coinbase ja plokitasud

### Ploki subsiidiumi graafik

**Algne subsiidium**: `10 BTC` (kõik võrgud)

**Poolnemise graafik**:
- Iga `1050000` ploki järel (mainnet/testnet)
- Iga `500` ploki järel (regtest)
- Jätkub maksimaalselt 64 poolnemiseni

**Poolnemise areng**:
```
Poolnemine 0: 10.00000000 BTC  (plokid 0 - 1049999)
Poolnemine 1:  5.00000000 BTC  (plokid 1050000 - 2099999)
Poolnemine 2:  2.50000000 BTC  (plokid 2100000 - 3149999)
Poolnemine 3:  1.25000000 BTC  (plokid 3150000 - 4199999)
...
```

**Kogumaht**: ~21 miljonit BTC (sama mis Bitcoinil)

### Coinbase väljundi reeglid

**Maksesihtkoht**:
- **Ülesannet pole**: Coinbase maksab graafiku aadressile (proof.account_id)
- **Ülesandega**: Coinbase maksab sepistamise aadressile (efektiivne allkirjastaja)

**Väljundi vorming**: Ainult P2WPKH
- Coinbase peab maksma bech32 SegWit v0 aadressile
- Genereeritakse efektiivse allkirjastaja avalikust võtmest

**Ülesande lahendamine**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementatsioon**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dünaamiline skaleerimine

### Skaleerimise piirid

**Eesmärk**: Suurendada graafiku genereerimise raskust võrgu küpsedes, et takistada mahu inflatsiooni

**Struktuur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimaalne aktsepteeritud tase
    uint8_t nPoCXTargetCompression;  // Soovitatav tase
};
```

**Suhe**: `target = min + 1` (alati üks tase miinimumist kõrgemal)

### Skaleerimise kasvu graafik

Skaleerimistasemed suurenevad **eksponentsiaalsel graafikul** poolnemise intervallide põhjal:

| Ajaperiood | Ploki kõrgus | Poolnemised | Min | Sihtmärk |
|------------|--------------|-------------|-----|----------|
| Aastad 0-4 | 0 kuni 1049999 | 0 | X1 | X2 |
| Aastad 4-12 | 1050000 kuni 3149999 | 1-2 | X2 | X3 |
| Aastad 12-28 | 3150000 kuni 7349999 | 3-6 | X3 | X4 |
| Aastad 28-60 | 7350000 kuni 15749999 | 7-14 | X4 | X5 |
| Aastad 60-124 | 15750000 kuni 32549999 | 15-30 | X5 | X6 |
| Aastad 124+ | 32550000+ | 31+ | X6 | X7 |

**Võtmekõrgused** (aastad -> poolnemised -> plokid):
- Aasta 4: Poolnemine 1 plokil 1050000
- Aasta 12: Poolnemine 3 plokil 3150000
- Aasta 28: Poolnemine 7 plokil 7350000
- Aasta 60: Poolnemine 15 plokil 15750000
- Aasta 124: Poolnemine 31 plokil 32550000

### Skaleerimistaseme raskus

**PoW skaleerimine**:
- Skaleerimistase X0: POC2 baastase (teoreetiline)
- Skaleerimistase X1: XOR-transponeeri baastase
- Skaleerimistase Xn: 2^(n-1) × X1 töö manustatud
- Iga tase kahekordistab graafiku genereerimise tööd

**Majanduslik joondamine**:
- Ploki tasud poolnevad -> graafiku genereerimise raskus suureneb
- Säilitab ohutuspiiri: graafiku loomise kulu > otsimise kulu
- Takistab mahu inflatsiooni riistvara arengust

### Graafiku valideerimine

**Valideerimisreeglid**:
- Esitatud tõestustel peab olema skaleerimistase >= miinimum
- Tõestused skaleerimisega > sihtmärk aktsepteeritakse, kuid on ebatõhusad
- Tõestused alla miinimumi: lükatakse tagasi (ebapiisav PoW)

**Piiride hankimine**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementatsioon**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Võrgu konfiguratsioon

### Seemne sõlmed ja DNS seemned

**Staatus**: Kohahoidja mainnet käivitamiseks

**Planeeritud konfiguratsioon**:
- Seemne sõlmed: TBD
- DNS seemned: TBD

**Praegune seis** (testnet/regtest):
- Pole pühendatud seemneinfrastruktuuri
- Käsitsi partnerühendused toetatakse `-addnode` kaudu

**Implementatsioon**: `src/kernel/chainparams.cpp`

### Kontrollpunktid

**Genesise kontrollpunkt**: Alati plokk 0

**Täiendavad kontrollpunktid**: Praegu pole konfigureeritud

**Tulevik**: Kontrollpunkte lisatakse mainnet'i edenedes

---

## P2P protokolli konfiguratsioon

### Protokolli versioon

**Baas**: Bitcoin Core v30.0 protokoll
- **Protokolli versioon**: Päritud Bitcoin Core'ilt
- **Teenuse bitid**: Standardsed Bitcoin teenused
- **Sõnumitüübid**: Standardsed Bitcoin P2P sõnumid

**PoCX laiendused**:
- Ploki päised sisaldavad PoCX-spetsiifilisi välju
- Ploki sõnumid sisaldavad PoCX tõestusandmeid
- Valideerimisreeglid jõustavad PoCX konsensust

**Ühilduvus**: PoCX sõlmed on ühildumatud Bitcoin PoW sõlmedega (erinev konsensus)

**Implementatsioon**: `src/protocol.h`, `src/net_processing.cpp`

---

## Andmekataloogi struktuur

### Vaikekataloog

**Asukoht**: `.bitcoin/` (sama mis Bitcoin Core'il)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Kataloogi sisu

```
.bitcoin/
├── blocks/              # Ploki andmed
│   ├── blk*.dat        # Plokifailid
│   ├── rev*.dat        # Tagasivõtmise andmed
│   └── index/          # Ploki indeks (LevelDB)
├── chainstate/         # UTXO kogum + sepistamisülesanded (LevelDB)
├── wallets/            # Rahakoti failid
│   └── wallet.dat      # Vaikerahakott
├── bitcoin.conf        # Konfiguratsioonifail
├── debug.log           # Silumislogi
├── peers.dat           # Partneraadressid
├── mempool.dat         # Mempool'i püsivus
└── banlist.dat         # Keelatud partnerid
```

### Põhilised erinevused Bitcoinist

**Chainstate andmebaas**:
- Standardne: UTXO kogum
- **PoCX lisandus**: Sepistamisülesannete olek
- Aatomilised uuendused: UTXO + ülesanded uuendatakse koos
- Ümberkorralduskindlad tagasivõtmise andmed ülesannetele

**Plokifailid**:
- Standardne Bitcoin ploki vorming
- **PoCX lisandus**: Laiendatud PoCX tõestusväljadega (account_id, seed, nonce, allkiri, pubkey)

### Konfiguratsioonifaili näide

**bitcoin.conf**:
```ini
# Võrgu valik
#testnet=1
#regtest=1

# PoCX kaevandamisserver (vajalik väliste kaevandajate jaoks)
miningserver=1

# RPC seaded
server=1
rpcuser=sinukasutajanimi
rpcpassword=sinuparool
rpcallowip=127.0.0.1
rpcport=8332

# Ühenduse seaded
listen=1
port=8888
maxconnections=125

# Plokkide aja sihtmärk (informatsiooniline, konsensuse poolt jõustatud)
# 120 sekundit mainnet/testnet jaoks
```

---

## Koodi viited

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensuse parameetrid**: `src/consensus/params.h`
**Kompressiooni piirid**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesise baassihtmärgi arvutamine**: `src/pocx/consensus/params.cpp`
**Coinbase makse loogika**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Ülesannete oleku hoiustus**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache laiendused)

---

## Ristviited

Seotud peatükid:
- [Peatükk 2: Graafikuvorming](2-plot-format.md) - Skaleerimistasemed graafiku genereerimisel
- [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md) - Skaleerimise valideerimine, ülesannete süsteem
- [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md) - Ülesannete viivituse parameetrid
- [Peatükk 5: Ajastuse turvalisus](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME põhjendus

---

[<- Eelmine: Ajasünkroniseerimine](5-timing-security.md) | [Sisukord](index.md) | [Järgmine: RPC viide ->](7-rpc-reference.md)

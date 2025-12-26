[← Ankstesnis: Laiko sinchronizacija](5-timing-security.md) | [📘 Turinys](index.md) | [Toliau: RPC informacija →](7-rpc-reference.md)

---

# 6 skyrius: Tinklo parametrai ir konfigūracija

Išsami Bitcoin-PoCX tinklo konfigūracijos informacija visuose tinklo tipuose.

---

## Turinys

1. [Pradinio bloko parametrai](#pradinio-bloko-parametrai)
2. [Chainparams konfigūracija](#chainparams-konfigūracija)
3. [Konsensuso parametrai](#konsensuso-parametrai)
4. [Coinbase ir bloko atlyginimai](#coinbase-ir-bloko-atlyginimai)
5. [Dinaminis mastelio keitimas](#dinaminis-mastelio-keitimas)
6. [Tinklo konfigūracija](#tinklo-konfigūracija)
7. [Duomenų katalogo struktūra](#duomenų-katalogo-struktūra)

---

## Pradinio bloko parametrai

### Bazinio tikslo skaičiavimas

**Formulė**: `pradinis_bazinis_tikslas = 2^42 / bloko_laikas_sekundėmis`

**Pagrindimas**:
- Kiekvienas nonce reprezentuoja 256 KiB (64 baitai × 4096 scoops)
- 1 TiB = 2^22 nonces (pradinis tinklo talpos prielaida)
- Tikėtina minimali kokybė n nonces ≈ 2^64 / n
- 1 TiB: E(kokybė) = 2^64 / 2^22 = 2^42
- Todėl: bazinis_tikslas = 2^42 / bloko_laikas

**Apskaičiuotos reikšmės**:
- Pagrindinis tinklas/Testinis tinklas/Signet (120s): `36650387592`
- Regtest (1s): Naudoja mažos talpos kalibravimo režimą

### Pradinis pranešimas

Visi tinklai dalijasi Bitcoin pradiniu pranešimu:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Įgyvendinimas**: `src/kernel/chainparams.cpp`

---

## Chainparams konfigūracija

### Pagrindinio tinklo parametrai

**Tinklo tapatybė**:
- **Magiški baitai**: `0xa7 0x3c 0x91 0x5e`
- **Numatytasis prievadas**: `8888`
- **Bech32 HRP**: `pocx`

**Adresų prefiksai** (Base58):
- PUBKEY_ADDRESS: `85` (adresai prasideda 'P')
- SCRIPT_ADDRESS: `90` (adresai prasideda 'R')
- SECRET_KEY: `128`

**Bloko laikymas**:
- **Bloko laiko tikslas**: `120` sekundžių (2 minutės)
- **Tikslinis laiko intervalas**: `1209600` sekundžių (14 dienų)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundžių

**Bloko atlyginimai**:
- **Pradinė subsidija**: `10 BTC`
- **Pusės intervalas**: `1050000` blokų (~4 metai)
- **Pusių skaičius**: 64 pusės maksimum

**Sudėtingumo koregavimas**:
- **Slenkantis langas**: `24` blokai
- **Koregavimas**: Kiekvienas blokas
- **Algoritmas**: Eksponentinis slenkantis vidurkis

**Priskyrimo atidėjimai**:
- **Aktyvacija**: `30` blokų (~1 valanda)
- **Atšaukimas**: `720` blokų (~24 valandos)

### Testinio tinklo parametrai

**Tinklo tapatybė**:
- **Magiški baitai**: `0x6d 0xf2 0x48 0xb3`
- **Numatytasis prievadas**: `18888`
- **Bech32 HRP**: `tpocx`

**Adresų prefiksai** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Bloko laikymas**:
- **Bloko laiko tikslas**: `120` sekundžių
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundžių
- **Leisti minimalų sudėtingumą**: `true`

**Bloko atlyginimai**:
- **Pradinė subsidija**: `10 BTC`
- **Pusės intervalas**: `1050000` blokų

**Sudėtingumo koregavimas**:
- **Slenkantis langas**: `24` blokai

**Priskyrimo atidėjimai**:
- **Aktyvacija**: `30` blokų (~1 valanda)
- **Atšaukimas**: `720` blokų (~24 valandos)

### Regtest parametrai

**Tinklo tapatybė**:
- **Magiški baitai**: `0xfa 0xbf 0xb5 0xda`
- **Numatytasis prievadas**: `18444`
- **Bech32 HRP**: `rpocx`

**Adresų prefiksai** (Bitcoin-suderinami):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Bloko laikymas**:
- **Bloko laiko tikslas**: `1` sekundė (momentinis kasimas testavimui)
- **Tikslinis laiko intervalas**: `86400` sekundžių (1 diena)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundžių

**Bloko atlyginimai**:
- **Pradinė subsidija**: `10 BTC`
- **Pusės intervalas**: `500` blokų

**Sudėtingumo koregavimas**:
- **Slenkantis langas**: `24` blokai
- **Leisti minimalų sudėtingumą**: `true`
- **Be tikslinio koregavimo**: `true`
- **Mažos talpos kalibravimas**: `true` (naudoja 16-nonce kalibravimą vietoj 1 TiB)

**Priskyrimo atidėjimai**:
- **Aktyvacija**: `4` blokai (~4 sekundės)
- **Atšaukimas**: `8` blokai (~8 sekundės)

### Signet parametrai

**Tinklo tapatybė**:
- **Magiški baitai**: Pirmieji 4 baitai SHA256d(signet_challenge)
- **Numatytasis prievadas**: `38333`
- **Bech32 HRP**: `tpocx`

**Bloko laikymas**:
- **Bloko laiko tikslas**: `120` sekundžių
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundžių

**Bloko atlyginimai**:
- **Pradinė subsidija**: `10 BTC`
- **Pusės intervalas**: `1050000` blokų

**Sudėtingumo koregavimas**:
- **Slenkantis langas**: `24` blokai

---

## Konsensuso parametrai

### Laiko parametrai

**MAX_FUTURE_BLOCK_TIME**: `15` sekundžių
- PoCX specifinis (Bitcoin naudoja 2 valandas)
- Pagrindimas: PoC laikymui reikia beveik realaus laiko validacijos
- Blokai daugiau nei 15s ateityje atmetami

**Laiko poslinkio įspėjimas**: `10` sekundžių
- Operatoriai įspėjami kai mazgo laikrodis nukrypsta >10s nuo tinklo laiko
- Jokio priverstinio vykdymo, tik informacinis

**Bloko laiko tikslai**:
- Pagrindinis tinklas/Testinis tinklas/Signet: `120` sekundžių
- Regtest: `1` sekundė

**TIMESTAMP_WINDOW**: `15` sekundžių (lygu MAX_FUTURE_BLOCK_TIME)

**Įgyvendinimas**: `src/chain.h`, `src/validation.cpp`

### Sudėtingumo koregavimo parametrai

**Slenkančio lango dydis**: `24` blokai (visi tinklai)
- Eksponentinis slenkantis vidurkis paskutinių blokų laikų
- Kiekvieno bloko koregavimas
- Reaguoja į talpos pokyčius

**Įgyvendinimas**: `src/consensus/params.h`, sudėtingumo logika bloko kūrime

### Priskyrimo sistemos parametrai

**nForgingAssignmentDelay** (aktyvacijos atidėjimas):
- Pagrindinis tinklas: `30` blokų (~1 valanda)
- Testinis tinklas: `30` blokų (~1 valanda)
- Regtest: `4` blokai (~4 sekundės)

**nForgingRevocationDelay** (atšaukimo atidėjimas):
- Pagrindinis tinklas: `720` blokų (~24 valandos)
- Testinis tinklas: `720` blokų (~24 valandos)
- Regtest: `8` blokai (~8 sekundės)

**Pagrindimas**:
- Aktyvacijos atidėjimas apsaugo nuo greito perpriskyrimo blokų lenktynių metu
- Atšaukimo atidėjimas teikia stabilumą ir apsaugo nuo piktnaudžiavimo

**Įgyvendinimas**: `src/consensus/params.h`

---

## Coinbase ir bloko atlyginimai

### Bloko subsidijos grafikas

**Pradinė subsidija**: `10 BTC` (visi tinklai)

**Pusės grafikas**:
- Kas `1050000` blokų (pagrindinis tinklas/testinis tinklas)
- Kas `500` blokų (regtest)
- Tęsiasi 64 puses maksimum

**Pusės progresija**:
```
Pusė 0: 10.00000000 BTC  (blokai 0 - 1049999)
Pusė 1:  5.00000000 BTC  (blokai 1050000 - 2099999)
Pusė 2:  2.50000000 BTC  (blokai 2100000 - 3149999)
Pusė 3:  1.25000000 BTC  (blokai 3150000 - 4199999)
...
```

**Bendra pasiūla**: ~21 milijonų BTC (kaip Bitcoin)

### Coinbase išvesties taisyklės

**Mokėjimo tikslas**:
- **Be priskyrimo**: Coinbase moka grafiko adresui (proof.account_id)
- **Su priskyrimu**: Coinbase moka kalimo adresui (efektyvusis pasirašytojas)

**Išvesties formatas**: Tik P2WPKH
- Coinbase turi mokėti bech32 SegWit v0 adresui
- Generuojamas iš efektyviojo pasirašytojo viešojo rakto

**Priskyrimo sprendimas**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Įgyvendinimas**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dinaminis mastelio keitimas

### Mastelio ribos

**Paskirtis**: Didinti grafiko generavimo sudėtingumą tinklui bręstant, kad būtų išvengta talpos infliacijos

**Struktūra**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimalus priimamas lygis
    uint8_t nPoCXTargetCompression;  // Rekomenduojamas lygis
};
```

**Santykis**: `tikslas = min + 1` (visada vienas lygis aukščiau minimumo)

### Mastelio didinimo grafikas

Mastelio lygiai didėja **eksponentiniu grafiku** pagal pusės intervalus:

| Laikotarpis | Bloko aukštis | Pusės | Min | Tikslas |
|-------------|--------------|-------|-----|---------|
| Metai 0-4 | 0 iki 1049999 | 0 | X1 | X2 |
| Metai 4-12 | 1050000 iki 3149999 | 1-2 | X2 | X3 |
| Metai 12-28 | 3150000 iki 7349999 | 3-6 | X3 | X4 |
| Metai 28-60 | 7350000 iki 15749999 | 7-14 | X4 | X5 |
| Metai 60-124 | 15750000 iki 32549999 | 15-30 | X5 | X6 |
| Metai 124+ | 32550000+ | 31+ | X6 | X7 |

**Pagrindiniai aukščiai** (metai → pusės → blokai):
- 4 metai: Pusė 1 ties bloku 1050000
- 12 metų: Pusė 3 ties bloku 3150000
- 28 metai: Pusė 7 ties bloku 7350000
- 60 metų: Pusė 15 ties bloku 15750000
- 124 metai: Pusė 31 ties bloku 32550000

### Mastelio lygio sudėtingumas

**PoW mastelio keitimas**:
- Mastelio lygis X0: POC2 bazinė linija (teorinis)
- Mastelio lygis X1: XOR-transpozicijos bazinė linija
- Mastelio lygis Xn: 2^(n-1) × X1 darbas įterptas
- Kiekvienas lygis dvigubina grafiko generavimo darbą

**Ekonominis suderinimas**:
- Bloko atlyginimai pusėja → grafiko generavimo sudėtingumas didėja
- Išlaiko saugumo ribą: grafiko kūrimo kaina > paieškos kaina
- Apsaugo nuo talpos infliacijos dėl aparatinės įrangos tobulinimo

### Grafiko validacija

**Validacijos taisyklės**:
- Pateikti įrodymai turi turėti mastelio lygį ≥ minimalus
- Įrodymai su masteliuoju > tikslas priimami, bet neefektyvūs
- Įrodymai žemiau minimumo: atmesti (nepakankamas PoW)

**Ribų gavimas**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Įgyvendinimas**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Tinklo konfigūracija

### Sėkliniai mazgai ir DNS sėklos

**Būsena**: Laukiantis pagrindinio tinklo paleidimo

**Planuojama konfigūracija**:
- Sėkliniai mazgai: Bus nustatyta
- DNS sėklos: Bus nustatyta

**Dabartinė būsena** (testinis tinklas/regtest):
- Jokios dedikuotos sėklinės infrastruktūros
- Rankiniai kolegų prisijungimai palaikomi per `-addnode`

**Įgyvendinimas**: `src/kernel/chainparams.cpp`

### Kontroliniai taškai

**Pradinio bloko kontrolinis taškas**: Visada blokas 0

**Papildomi kontroliniai taškai**: Šiuo metu nekonfigūruota

**Ateitis**: Kontroliniai taškai bus pridėti pagrindiniam tinklui progresuojant

---

## P2P protokolo konfigūracija

### Protokolo versija

**Bazė**: Bitcoin Core v30.0 protokolas
- **Protokolo versija**: Paveldėta iš Bitcoin Core
- **Paslaugų bitai**: Standartinės Bitcoin paslaugos
- **Pranešimų tipai**: Standartiniai Bitcoin P2P pranešimai

**PoCX išplėtimai**:
- Blokų antraštės apima PoCX specifinius laukus
- Blokų pranešimai apima PoCX įrodymo duomenis
- Validacijos taisyklės vykdo PoCX konsensusą

**Suderinamumas**: PoCX mazgai nesuderinami su Bitcoin PoW mazgais (skirtingas konsensusas)

**Įgyvendinimas**: `src/protocol.h`, `src/net_processing.cpp`

---

## Duomenų katalogo struktūra

### Numatytasis katalogas

**Vieta**: `.bitcoin/` (kaip Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Katalogo turinys

```
.bitcoin/
├── blocks/              # Blokų duomenys
│   ├── blk*.dat        # Blokų failai
│   ├── rev*.dat        # Atšaukimo duomenys
│   └── index/          # Blokų indeksas (LevelDB)
├── chainstate/         # UTXO rinkinys + kalimo priskyrimai (LevelDB)
├── wallets/            # Piniginės failai
│   └── wallet.dat      # Numatytoji piniginė
├── bitcoin.conf        # Konfigūracijos failas
├── debug.log           # Derinimo žurnalas
├── peers.dat           # Kolegų adresai
├── mempool.dat         # Mempool išsaugojimas
└── banlist.dat         # Uždrausti kolegos
```

### Pagrindiniai skirtumai nuo Bitcoin

**Chainstate duomenų bazė**:
- Standartinis: UTXO rinkinys
- **PoCX papildymas**: Kalimo priskyrimo būsena
- Atominiai atnaujinimai: UTXO + priskyrimai atnaujinami kartu
- Reorg-saugūs atšaukimo duomenys priskyrimams

**Blokų failai**:
- Standartinis Bitcoin bloko formatas
- **PoCX papildymas**: Išplėsta PoCX įrodymo laukais (account_id, seed, nonce, signature, pubkey)

### Konfigūracijos failo pavyzdys

**bitcoin.conf**:
```ini
# Tinklo pasirinkimas
#testnet=1
#regtest=1

# PoCX kasimo serveris (reikalingas išoriniams kasėjams)
miningserver=1

# RPC nustatymai
server=1
rpcuser=jūsųvartotojas
rpcpassword=jūsųslaptažodis
rpcallowip=127.0.0.1
rpcport=8332

# Ryšio nustatymai
listen=1
port=8888
maxconnections=125

# Bloko laiko tikslas (informacinis, konsensuso vykdomas)
# 120 sekundžių pagrindiniam tinklui/testiniam tinklui
```

---

## Kodo nuorodos

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensuso parametrai**: `src/consensus/params.h`
**Suspaudimo ribos**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Pradinio bazinio tikslo skaičiavimas**: `src/pocx/consensus/params.cpp`
**Coinbase mokėjimo logika**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Priskyrimo būsenos saugykla**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache išplėtimai)

---

## Kryžminės nuorodos

Susiję skyriai:
- [2 skyrius: Grafiko formatas](2-plot-format.md) - Mastelio lygiai grafiko generavime
- [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md) - Mastelio validacija, priskyrimo sistema
- [4 skyrius: Kalimo priskyrimai](4-forging-assignments.md) - Priskyrimo atidėjimo parametrai
- [5 skyrius: Laiko saugumas](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME pagrindimas

---

[← Ankstesnis: Laiko sinchronizacija](5-timing-security.md) | [📘 Turinys](index.md) | [Toliau: RPC informacija →](7-rpc-reference.md)

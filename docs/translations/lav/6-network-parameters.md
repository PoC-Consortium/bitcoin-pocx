[← Iepriekšējā: Laika sinhronizācija](5-timing-security.md) | [📘 Satura rādītājs](index.md) | [Nākamā: RPC atsauce →](7-rpc-reference.md)

---

# 6. nodaļa: Tīkla parametri un konfigurācija

Pilnīga atsauce Bitcoin-PoCX tīkla konfigurācijai visos tīkla tipos.

---

## Satura rādītājs

1. [Ģenēzes bloka parametri](#ģenēzes-bloka-parametri)
2. [Chainparams konfigurācija](#chainparams-konfigurācija)
3. [Konsensa parametri](#konsensa-parametri)
4. [Coinbase un bloku atlīdzības](#coinbase-un-bloku-atlīdzības)
5. [Dinamiskā mērogošana](#dinamiskā-mērogošana)
6. [Tīkla konfigurācija](#tīkla-konfigurācija)
7. [Datu direktorijas struktūra](#datu-direktorijas-struktūra)

---

## Ģenēzes bloka parametri

### Bāzes mērķa aprēķins

**Formula**: `genesis_base_target = 2^42 / block_time_seconds`

**Pamatojums**:
- Katra nonce pārstāv 256 KiB (64 baiti × 4096 scoopi)
- 1 TiB = 2^22 nonces (pieņemtā sākuma tīkla jauda)
- Paredzamā minimālā kvalitāte n noncēm ≈ 2^64 / n
- 1 TiB: E(kvalitāte) = 2^64 / 2^22 = 2^42
- Tāpēc: base_target = 2^42 / block_time

**Aprēķinātās vērtības**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Izmanto zemas jaudas kalibrācijas režīmu

### Ģenēzes ziņojums

Visi tīkli dalās ar Bitcoin ģenēzes ziņojumu:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementācija**: `src/kernel/chainparams.cpp`

---

## Chainparams konfigurācija

### Mainnet parametri

**Tīkla identitāte**:
- **Maģiskie baiti**: `0xa7 0x3c 0x91 0x5e`
- **Noklusējuma ports**: `8888`
- **Bech32 HRP**: `pocx`

**Adrešu prefiksi** (Base58):
- PUBKEY_ADDRESS: `85` (adreses sākas ar 'P')
- SCRIPT_ADDRESS: `90` (adreses sākas ar 'R')
- SECRET_KEY: `128`

**Bloku laiks**:
- **Bloka laika mērķis**: `120` sekundes (2 minūtes)
- **Mērķa laika posms**: `1209600` sekundes (14 dienas)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundes

**Bloku atlīdzības**:
- **Sākotnējā subsīdija**: `10 BTC`
- **Dalīšanas intervāls**: `1050000` bloki (~4 gadi)
- **Dalīšanu skaits**: Maksimums 64 dalīšanas

**Grūtības pielāgošana**:
- **Ritošais logs**: `24` bloki
- **Pielāgošana**: Katru bloku
- **Algoritms**: Eksponenciālais mainīgais vidējais

**Piešķīrumu aizkaves**:
- **Aktivizācija**: `30` bloki (~1 stunda)
- **Atsaukšana**: `720` bloki (~24 stundas)

### Testnet parametri

**Tīkla identitāte**:
- **Maģiskie baiti**: `0x6d 0xf2 0x48 0xb3`
- **Noklusējuma ports**: `18888`
- **Bech32 HRP**: `tpocx`

**Adrešu prefiksi** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Bloku laiks**:
- **Bloka laika mērķis**: `120` sekundes
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundes
- **Atļaut minimālo grūtību**: `true`

**Bloku atlīdzības**:
- **Sākotnējā subsīdija**: `10 BTC`
- **Dalīšanas intervāls**: `1050000` bloki

**Grūtības pielāgošana**:
- **Ritošais logs**: `24` bloki

**Piešķīrumu aizkaves**:
- **Aktivizācija**: `30` bloki (~1 stunda)
- **Atsaukšana**: `720` bloki (~24 stundas)

### Regtest parametri

**Tīkla identitāte**:
- **Maģiskie baiti**: `0xfa 0xbf 0xb5 0xda`
- **Noklusējuma ports**: `18444`
- **Bech32 HRP**: `rpocx`

**Adrešu prefiksi** (Bitcoin saderīgi):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Bloku laiks**:
- **Bloka laika mērķis**: `1` sekunde (tūlītēja kalnrūpniecība testēšanai)
- **Mērķa laika posms**: `86400` sekundes (1 diena)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundes

**Bloku atlīdzības**:
- **Sākotnējā subsīdija**: `10 BTC`
- **Dalīšanas intervāls**: `500` bloki

**Grūtības pielāgošana**:
- **Ritošais logs**: `24` bloki
- **Atļaut minimālo grūtību**: `true`
- **Nav atkārtotas mērķēšanas**: `true`
- **Zemas jaudas kalibrācija**: `true` (izmanto 16 nonču kalibrāciju, nevis 1 TiB)

**Piešķīrumu aizkaves**:
- **Aktivizācija**: `4` bloki (~4 sekundes)
- **Atsaukšana**: `8` bloki (~8 sekundes)

### Signet parametri

**Tīkla identitāte**:
- **Maģiskie baiti**: Pirmie 4 baiti no SHA256d(signet_challenge)
- **Noklusējuma ports**: `38333`
- **Bech32 HRP**: `tpocx`

**Bloku laiks**:
- **Bloka laika mērķis**: `120` sekundes
- **MAX_FUTURE_BLOCK_TIME**: `15` sekundes

**Bloku atlīdzības**:
- **Sākotnējā subsīdija**: `10 BTC`
- **Dalīšanas intervāls**: `1050000` bloki

**Grūtības pielāgošana**:
- **Ritošais logs**: `24` bloki

---

## Konsensa parametri

### Laika parametri

**MAX_FUTURE_BLOCK_TIME**: `15` sekundes
- PoCX specifisks (Bitcoin izmanto 2 stundas)
- Pamatojums: PoC laika noteikšanai nepieciešama gandrīz reāllaika validācija
- Bloki vairāk nekā 15s nākotnē tiek noraidīti

**Laika nobīdes brīdinājums**: `10` sekundes
- Operatori tiek brīdināti, kad mezgla pulkstenis novirzās >10s no tīkla laika
- Nav izpildes, tikai informatīvs

**Bloku laika mērķi**:
- Mainnet/Testnet/Signet: `120` sekundes
- Regtest: `1` sekunde

**TIMESTAMP_WINDOW**: `15` sekundes (vienāds ar MAX_FUTURE_BLOCK_TIME)

**Implementācija**: `src/chain.h`, `src/validation.cpp`

### Grūtības pielāgošanas parametri

**Ritošā loga izmērs**: `24` bloki (visi tīkli)
- Eksponenciālais mainīgais vidējais no nesenajiem bloku laikiem
- Pielāgošana katru bloku
- Reaģē uz jaudas izmaiņām

**Implementācija**: `src/consensus/params.h`, grūtības loģika bloku izveidē

### Piešķīrumu sistēmas parametri

**nForgingAssignmentDelay** (aktivizācijas aizkave):
- Mainnet: `30` bloki (~1 stunda)
- Testnet: `30` bloki (~1 stunda)
- Regtest: `4` bloki (~4 sekundes)

**nForgingRevocationDelay** (atsaukšanas aizkave):
- Mainnet: `720` bloki (~24 stundas)
- Testnet: `720` bloki (~24 stundas)
- Regtest: `8` bloki (~8 sekundes)

**Pamatojums**:
- Aktivizācijas aizkave novērš ātru pārpiešķiršanu bloku sacensību laikā
- Atsaukšanas aizkave nodrošina stabilitāti un novērš ļaunprātīgu izmantošanu

**Implementācija**: `src/consensus/params.h`

---

## Coinbase un bloku atlīdzības

### Bloku subsīdijas grafiks

**Sākotnējā subsīdija**: `10 BTC` (visi tīkli)

**Dalīšanas grafiks**:
- Ik `1050000` blokus (mainnet/testnet)
- Ik `500` blokus (regtest)
- Turpinās maksimums 64 dalīšanas

**Dalīšanas progresija**:
```
Dalīšana 0: 10.00000000 BTC  (bloki 0 - 1049999)
Dalīšana 1:  5.00000000 BTC  (bloki 1050000 - 2099999)
Dalīšana 2:  2.50000000 BTC  (bloki 2100000 - 3149999)
Dalīšana 3:  1.25000000 BTC  (bloki 3150000 - 4199999)
...
```

**Kopējais piedāvājums**: ~21 miljons BTC (tāpat kā Bitcoin)

### Coinbase izvades noteikumi

**Maksājuma adresāts**:
- **Bez piešķīruma**: Coinbase maksā plotfaila adresei (proof.account_id)
- **Ar piešķīrumu**: Coinbase maksā kalšanas adresei (efektīvais parakstītājs)

**Izvades formāts**: Tikai P2WPKH
- Coinbase jāmaksā bech32 SegWit v0 adresei
- Ģenerēts no efektīvā parakstītāja publiskās atslēgas

**Piešķīruma atrisināšana**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementācija**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dinamiskā mērogošana

### Mērogošanas robežas

**Mērķis**: Palielināt plotfailu ģenerēšanas grūtību, tīklam nobriedot, lai novērstu jaudas inflāciju

**Struktūra**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimālais pieņemtais līmenis
    uint8_t nPoCXTargetCompression;  // Ieteicamais līmenis
};
```

**Attiecība**: `target = min + 1` (vienmēr vienu līmeni virs minimuma)

### Mērogošanas palielināšanas grafiks

Mērogošanas līmeņi palielinās pēc **eksponenciāla grafika**, balstoties uz dalīšanas intervāliem:

| Laika periods | Bloka augstums | Dalīšanas | Min | Mērķis |
|-------------|--------------|----------|-----|--------|
| 0-4 gadi | 0 līdz 1049999 | 0 | X1 | X2 |
| 4-12 gadi | 1050000 līdz 3149999 | 1-2 | X2 | X3 |
| 12-28 gadi | 3150000 līdz 7349999 | 3-6 | X3 | X4 |
| 28-60 gadi | 7350000 līdz 15749999 | 7-14 | X4 | X5 |
| 60-124 gadi | 15750000 līdz 32549999 | 15-30 | X5 | X6 |
| 124+ gadi | 32550000+ | 31+ | X6 | X7 |

**Galvenie augstumi** (gadi → dalīšanas → bloki):
- 4. gads: 1. dalīšana blokā 1050000
- 12. gads: 3. dalīšana blokā 3150000
- 28. gads: 7. dalīšana blokā 7350000
- 60. gads: 15. dalīšana blokā 15750000
- 124. gads: 31. dalīšana blokā 32550000

### Mērogošanas līmeņa grūtība

**PoW mērogošana**:
- Mērogošanas līmenis X0: POC2 bāzlīnija (teorētisks)
- Mērogošanas līmenis X1: XOR-transpozīcijas bāzlīnija
- Mērogošanas līmenis Xn: 2^(n-1) × X1 darbs iegults
- Katrs līmenis dubulto plotfailu ģenerēšanas darbu

**Ekonomiskā saskaņošana**:
- Bloku atlīdzības dalās uz pusēm → plotfailu ģenerēšanas grūtība palielinās
- Uztur drošības rezervi: plotfailu izveides izmaksas > meklēšanas izmaksas
- Novērš jaudas inflāciju no aparatūras uzlabojumiem

### Plotfailu validācija

**Validācijas noteikumi**:
- Iesniegtajiem pierādījumiem jābūt mērogošanas līmenim ≥ minimums
- Pierādījumi ar mērogošanu > mērķis tiek pieņemti, bet neefektīvi
- Pierādījumi zem minimuma: noraidīti (nepietiekams PoW)

**Robežu iegūšana**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementācija**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Tīkla konfigurācija

### Sēklu mezgli un DNS sēklas

**Statuss**: Vietturus mainnet palaišanai

**Plānotā konfigurācija**:
- Sēklu mezgli: Jānosaka
- DNS sēklas: Jānosaka

**Pašreizējais stāvoklis** (testnet/regtest):
- Nav veltītas sēklu infrastruktūras
- Manuāli vienaudžu savienojumi atbalstīti caur `-addnode`

**Implementācija**: `src/kernel/chainparams.cpp`

### Kontrolpunkti

**Ģenēzes kontrolpunkts**: Vienmēr bloks 0

**Papildu kontrolpunkti**: Pašlaik nav konfigurēti

**Nākotnē**: Kontrolpunkti tiks pievienoti, mainnet progresējot

---

## P2P protokola konfigurācija

### Protokola versija

**Bāze**: Bitcoin Core v30.0 protokols
- **Protokola versija**: Mantota no Bitcoin Core
- **Pakalpojumu biti**: Standarta Bitcoin pakalpojumi
- **Ziņojumu tipi**: Standarta Bitcoin P2P ziņojumi

**PoCX paplašinājumi**:
- Bloku galvenes ietver PoCX specifiskus laukus
- Bloku ziņojumi ietver PoCX pierādījuma datus
- Validācijas noteikumi ievieš PoCX konsensus

**Saderība**: PoCX mezgli nav saderīgi ar Bitcoin PoW mezgliem (atšķirīgs konsensuss)

**Implementācija**: `src/protocol.h`, `src/net_processing.cpp`

---

## Datu direktorijas struktūra

### Noklusējuma direktorija

**Atrašanās vieta**: `.bitcoin/` (tāpat kā Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Direktorijas saturs

```
.bitcoin/
├── blocks/              # Bloku dati
│   ├── blk*.dat        # Bloku faili
│   ├── rev*.dat        # Atsaukšanas dati
│   └── index/          # Bloku indekss (LevelDB)
├── chainstate/         # UTXO kopa + kalšanas piešķīrumi (LevelDB)
├── wallets/            # Maciņu faili
│   └── wallet.dat      # Noklusējuma maciņš
├── bitcoin.conf        # Konfigurācijas fails
├── debug.log           # Atkļūdošanas žurnāls
├── peers.dat           # Vienaudžu adreses
├── mempool.dat         # Mempool noturība
└── banlist.dat         # Bloķētie vienaudži
```

### Galvenās atšķirības no Bitcoin

**Chainstate datu bāze**:
- Standarta: UTXO kopa
- **PoCX papildinājums**: Kalšanas piešķīrumu stāvoklis
- Atomāri atjauninājumi: UTXO + piešķīrumi atjaunināti kopā
- Reorganizāciju droši atsaukšanas dati piešķīrumiem

**Bloku faili**:
- Standarta Bitcoin bloku formāts
- **PoCX papildinājums**: Paplašināts ar PoCX pierādījuma laukiem (account_id, seed, nonce, signature, pubkey)

### Konfigurācijas faila piemērs

**bitcoin.conf**:
```ini
# Tīkla izvēle
#testnet=1
#regtest=1

# PoCX kalnrūpniecības serveris (nepieciešams ārējiem kalnračiem)
miningserver=1

# RPC iestatījumi
server=1
rpcuser=jusu_lietotajvards
rpcpassword=jusu_parole
rpcallowip=127.0.0.1
rpcport=8332

# Savienojuma iestatījumi
listen=1
port=8888
maxconnections=125

# Bloka laika mērķis (informatīvs, konsensuss izpildīts)
# 120 sekundes mainnet/testnet
```

---

## Koda atsauces

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensa parametri**: `src/consensus/params.h`
**Kompresijas robežas**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Ģenēzes bāzes mērķa aprēķins**: `src/pocx/consensus/params.cpp`
**Coinbase maksājuma loģika**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Piešķīrumu stāvokļa glabāšana**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache paplašinājumi)

---

## Savstarpējās atsauces

Saistītās nodaļas:
- [2. nodaļa: Plotfaila formāts](2-plot-format.md) - Mērogošanas līmeņi plotfailu ģenerēšanā
- [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md) - Mērogošanas validācija, piešķīrumu sistēma
- [4. nodaļa: Kalšanas piešķīrumi](4-forging-assignments.md) - Piešķīrumu aizkaves parametri
- [5. nodaļa: Laika drošība](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME pamatojums

---

[← Iepriekšējā: Laika sinhronizācija](5-timing-security.md) | [📘 Satura rādītājs](index.md) | [Nākamā: RPC atsauce →](7-rpc-reference.md)

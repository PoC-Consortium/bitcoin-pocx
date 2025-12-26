[← Předchozí: Časová synchronizace](5-timing-security.md) | [Obsah](index.md) | [Další: Reference RPC →](7-rpc-reference.md)

---

# Kapitola 6: Síťové parametry a konfigurace

Kompletní reference pro konfiguraci sítě Bitcoin-PoCX napříč všemi typy sítí.

---

## Obsah

1. [Parametry genesis bloku](#parametry-genesis-bloku)
2. [Konfigurace chainparams](#konfigurace-chainparams)
3. [Konsensuální parametry](#konsensuální-parametry)
4. [Coinbase a odměny za bloky](#coinbase-a-odměny-za-bloky)
5. [Dynamické škálování](#dynamické-škálování)
6. [Konfigurace sítě](#konfigurace-sítě)
7. [Struktura datového adresáře](#struktura-datového-adresáře)

---

## Parametry genesis bloku

### Výpočet base target

**Vzorec**: `genesis_base_target = 2^42 / block_time_seconds`

**Zdůvodnění**:
- Každá nonce reprezentuje 256 KiB (64 bajtů × 4096 scoopů)
- 1 TiB = 2^22 nonces (předpoklad počáteční síťové kapacity)
- Očekávaná minimální kvalita pro n nonces ≈ 2^64 / n
- Pro 1 TiB: E(kvalita) = 2^64 / 2^22 = 2^42
- Proto: base_target = 2^42 / block_time

**Vypočítané hodnoty**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Používá režim kalibrace nízké kapacity

### Genesis zpráva

Všechny sítě sdílejí genesis zprávu Bitcoinu:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementace**: `src/kernel/chainparams.cpp`

---

## Konfigurace chainparams

### Parametry mainnetu

**Identita sítě**:
- **Magic bajty**: `0xa7 0x3c 0x91 0x5e`
- **Výchozí port**: `8888`
- **Bech32 HRP**: `pocx`

**Prefixy adres** (Base58):
- PUBKEY_ADDRESS: `85` (adresy začínají na 'P')
- SCRIPT_ADDRESS: `90` (adresy začínají na 'R')
- SECRET_KEY: `128`

**Časování bloků**:
- **Cílový čas bloku**: `120` sekund (2 minuty)
- **Cílový časový rozsah**: `1209600` sekund (14 dní)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Odměny za bloky**:
- **Počáteční subsidy**: `10 BTC`
- **Interval halvingu**: `1050000` bloků (~4 roky)
- **Počet halvingů**: Maximálně 64 halvingů

**Úprava obtížnosti**:
- **Klouzavé okno**: `24` bloků
- **Úprava**: Každý blok
- **Algoritmus**: Exponenciální klouzavý průměr

**Zpoždění přiřazení**:
- **Aktivace**: `30` bloků (~1 hodina)
- **Revokace**: `720` bloků (~24 hodin)

### Parametry testnetu

**Identita sítě**:
- **Magic bajty**: `0x6d 0xf2 0x48 0xb3`
- **Výchozí port**: `18888`
- **Bech32 HRP**: `tpocx`

**Prefixy adres** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Časování bloků**:
- **Cílový čas bloku**: `120` sekund
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund
- **Povolit min obtížnost**: `true`

**Odměny za bloky**:
- **Počáteční subsidy**: `10 BTC`
- **Interval halvingu**: `1050000` bloků

**Úprava obtížnosti**:
- **Klouzavé okno**: `24` bloků

**Zpoždění přiřazení**:
- **Aktivace**: `30` bloků (~1 hodina)
- **Revokace**: `720` bloků (~24 hodin)

### Parametry regtestu

**Identita sítě**:
- **Magic bajty**: `0xfa 0xbf 0xb5 0xda`
- **Výchozí port**: `18444`
- **Bech32 HRP**: `rpocx`

**Prefixy adres** (kompatibilní s Bitcoinem):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Časování bloků**:
- **Cílový čas bloku**: `1` sekunda (okamžitá těžba pro testování)
- **Cílový časový rozsah**: `86400` sekund (1 den)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Odměny za bloky**:
- **Počáteční subsidy**: `10 BTC`
- **Interval halvingu**: `500` bloků

**Úprava obtížnosti**:
- **Klouzavé okno**: `24` bloků
- **Povolit min obtížnost**: `true`
- **Bez retargetingu**: `true`
- **Kalibrace nízké kapacity**: `true` (používá 16-nonce kalibraci místo 1 TiB)

**Zpoždění přiřazení**:
- **Aktivace**: `4` bloky (~4 sekundy)
- **Revokace**: `8` bloků (~8 sekund)

### Parametry signetu

**Identita sítě**:
- **Magic bajty**: První 4 bajty SHA256d(signet_challenge)
- **Výchozí port**: `38333`
- **Bech32 HRP**: `tpocx`

**Časování bloků**:
- **Cílový čas bloku**: `120` sekund
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Odměny za bloky**:
- **Počáteční subsidy**: `10 BTC`
- **Interval halvingu**: `1050000` bloků

**Úprava obtížnosti**:
- **Klouzavé okno**: `24` bloků

---

## Konsensuální parametry

### Časové parametry

**MAX_FUTURE_BLOCK_TIME**: `15` sekund
- Specifické pro PoCX (Bitcoin používá 2 hodiny)
- Zdůvodnění: Časování PoC vyžaduje téměř real-time validaci
- Bloky více než 15s v budoucnosti jsou odmítnuty

**Varování časového offsetu**: `10` sekund
- Operátoři varováni, když hodiny uzlu driftují >10s od síťového času
- Žádné vynucování, pouze informativní

**Cílové časy bloků**:
- Mainnet/Testnet/Signet: `120` sekund
- Regtest: `1` sekunda

**TIMESTAMP_WINDOW**: `15` sekund (rovná se MAX_FUTURE_BLOCK_TIME)

**Implementace**: `src/chain.h`, `src/validation.cpp`

### Parametry úpravy obtížnosti

**Velikost klouzavého okna**: `24` bloků (všechny sítě)
- Exponenciální klouzavý průměr nedávných časů bloků
- Úprava při každém bloku
- Reaguje na změny kapacity

**Implementace**: `src/consensus/params.h`, logika obtížnosti při vytváření bloků

### Parametry systému přiřazení

**nForgingAssignmentDelay** (zpoždění aktivace):
- Mainnet: `30` bloků (~1 hodina)
- Testnet: `30` bloků (~1 hodina)
- Regtest: `4` bloky (~4 sekundy)

**nForgingRevocationDelay** (zpoždění revokace):
- Mainnet: `720` bloků (~24 hodin)
- Testnet: `720` bloků (~24 hodin)
- Regtest: `8` bloků (~8 sekund)

**Zdůvodnění**:
- Zpoždění aktivace zabraňuje rychlému přeřazení během závodů o bloky
- Zpoždění revokace poskytuje stabilitu a zabraňuje zneužití

**Implementace**: `src/consensus/params.h`

---

## Coinbase a odměny za bloky

### Harmonogram subsidy bloků

**Počáteční subsidy**: `10 BTC` (všechny sítě)

**Harmonogram halvingů**:
- Každých `1050000` bloků (mainnet/testnet)
- Každých `500` bloků (regtest)
- Pokračuje maximálně 64 halvingů

**Progrese halvingů**:
```
Halving 0: 10,00000000 BTC  (bloky 0 - 1049999)
Halving 1:  5,00000000 BTC  (bloky 1050000 - 2099999)
Halving 2:  2,50000000 BTC  (bloky 2100000 - 3149999)
Halving 3:  1,25000000 BTC  (bloky 3150000 - 4199999)
...
```

**Celková nabídka**: ~21 milionů BTC (stejně jako Bitcoin)

### Pravidla výstupu coinbase

**Cíl platby**:
- **Bez přiřazení**: Coinbase platí na adresu plotu (proof.account_id)
- **S přiřazením**: Coinbase platí na forging adresu (efektivní podpisující)

**Formát výstupu**: Pouze P2WPKH
- Coinbase musí platit na bech32 SegWit v0 adresu
- Generováno z veřejného klíče efektivního podpisujícího

**Rozlišení přiřazení**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementace**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamické škálování

### Hranice škálování

**Účel**: Zvýšit obtížnost generování plotů jak síť dozrává, aby se zabránilo inflaci kapacity

**Struktura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimální přijatá úroveň
    uint8_t nPoCXTargetCompression;  // Doporučená úroveň
};
```

**Vztah**: `target = min + 1` (vždy o jednu úroveň nad minimem)

### Harmonogram zvyšování škálování

Úrovně škálování se zvyšují podle **exponenciálního harmonogramu** založeného na intervalech halvingů:

| Časové období | Výška bloku | Halvingy | Min | Cíl |
|---------------|-------------|----------|-----|-----|
| Roky 0-4 | 0 až 1049999 | 0 | X1 | X2 |
| Roky 4-12 | 1050000 až 3149999 | 1-2 | X2 | X3 |
| Roky 12-28 | 3150000 až 7349999 | 3-6 | X3 | X4 |
| Roky 28-60 | 7350000 až 15749999 | 7-14 | X4 | X5 |
| Roky 60-124 | 15750000 až 32549999 | 15-30 | X5 | X6 |
| Roky 124+ | 32550000+ | 31+ | X6 | X7 |

**Klíčové výšky** (roky → halvingy → bloky):
- Rok 4: Halving 1 na bloku 1050000
- Rok 12: Halving 3 na bloku 3150000
- Rok 28: Halving 7 na bloku 7350000
- Rok 60: Halving 15 na bloku 15750000
- Rok 124: Halving 31 na bloku 32550000

### Obtížnost úrovně škálování

**Škálování PoW**:
- Úroveň škálování X0: POC2 baseline (teoretická)
- Úroveň škálování X1: XOR-transpose baseline
- Úroveň škálování Xn: 2^(n-1) × práce X1 vloženo
- Každá úroveň zdvojnásobuje práci generování plotu

**Ekonomické sladění**:
- Odměny za bloky se snižují na polovinu → obtížnost generování plotů se zvyšuje
- Udržuje bezpečnostní marži: náklady na vytvoření plotu > náklady na vyhledávání
- Zabraňuje inflaci kapacity z vylepšení hardwaru

### Validace plotů

**Pravidla validace**:
- Odeslané důkazy musí mít úroveň škálování ≥ minimum
- Důkazy s škálováním > cíl jsou přijaty, ale neefektivní
- Důkazy pod minimem: odmítnuty (nedostatečný PoW)

**Získání hranic**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementace**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Konfigurace sítě

### Seed uzly a DNS seedy

**Stav**: Zástupný symbol pro spuštění mainnetu

**Plánovaná konfigurace**:
- Seed uzly: TBD
- DNS seedy: TBD

**Aktuální stav** (testnet/regtest):
- Žádná vyhrazená seed infrastruktura
- Manuální připojení peerů podporováno přes `-addnode`

**Implementace**: `src/kernel/chainparams.cpp`

### Checkpointy

**Genesis checkpoint**: Vždy blok 0

**Další checkpointy**: Aktuálně nekonfigurovány

**Budoucnost**: Checkpointy budou přidány jak mainnet postupuje

---

## Konfigurace P2P protokolu

### Verze protokolu

**Základ**: P2P protokol Bitcoin Core v30.0
- **Verze protokolu**: Zděděna z Bitcoin Core
- **Servisní bity**: Standardní služby Bitcoinu
- **Typy zpráv**: Standardní P2P zprávy Bitcoinu

**Rozšíření PoCX**:
- Hlavičky bloků obsahují PoCX-specifická pole
- Zprávy bloků obsahují data PoCX důkazu
- Validační pravidla vynucují konsenzus PoCX

**Kompatibilita**: Uzly PoCX nekompatibilní s uzly Bitcoin PoW (odlišný konsenzus)

**Implementace**: `src/protocol.h`, `src/net_processing.cpp`

---

## Struktura datového adresáře

### Výchozí adresář

**Umístění**: `.bitcoin/` (stejné jako Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Obsah adresáře

```
.bitcoin/
├── blocks/              # Data bloků
│   ├── blk*.dat        # Soubory bloků
│   ├── rev*.dat        # Undo data
│   └── index/          # Index bloků (LevelDB)
├── chainstate/         # UTXO set + forging přiřazení (LevelDB)
├── wallets/            # Soubory peněženky
│   └── wallet.dat      # Výchozí peněženka
├── bitcoin.conf        # Konfigurační soubor
├── debug.log           # Debug log
├── peers.dat           # Adresy peerů
├── mempool.dat         # Perzistence mempoolu
└── banlist.dat         # Zakázaní peeři
```

### Klíčové rozdíly od Bitcoinu

**Databáze chainstate**:
- Standardní: UTXO set
- **Doplněk PoCX**: Stav forging přiřazení
- Atomické aktualizace: UTXO + přiřazení aktualizovány společně
- Reorg-safe undo data pro přiřazení

**Soubory bloků**:
- Standardní formát bloků Bitcoinu
- **Doplněk PoCX**: Rozšířeno o pole PoCX důkazu (account_id, seed, nonce, signature, pubkey)

### Příklad konfiguračního souboru

**bitcoin.conf**:
```ini
# Výběr sítě
#testnet=1
#regtest=1

# Těžební server PoCX (vyžadován pro externí těžaře)
miningserver=1

# Nastavení RPC
server=1
rpcuser=vasejmeno
rpcpassword=vasheslo
rpcallowip=127.0.0.1
rpcport=8332

# Nastavení připojení
listen=1
port=8888
maxconnections=125

# Cílový čas bloku (informativní, vynuceno konsenzem)
# 120 sekund pro mainnet/testnet
```

---

## Reference kódu

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensuální parametry**: `src/consensus/params.h`
**Hranice komprese**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Výpočet genesis base target**: `src/pocx/consensus/params.cpp`
**Logika platby coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Úložiště stavu přiřazení**: `src/coins.h`, `src/coins.cpp` (rozšíření CCoinsViewCache)

---

## Křížové odkazy

Související kapitoly:
- [Kapitola 2: Formát plotů](2-plot-format.md) - Úrovně škálování při generování plotů
- [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md) - Validace škálování, systém přiřazení
- [Kapitola 4: Forging přiřazení](4-forging-assignments.md) - Parametry zpoždění přiřazení
- [Kapitola 5: Časová bezpečnost](5-timing-security.md) - Zdůvodnění MAX_FUTURE_BLOCK_TIME

---

[← Předchozí: Časová synchronizace](5-timing-security.md) | [Obsah](index.md) | [Další: Reference RPC →](7-rpc-reference.md)

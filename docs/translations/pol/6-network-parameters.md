[← Poprzedni: Synchronizacja czasu](5-timing-security.md) | [Spis treści](index.md) | [Dalej: Dokumentacja RPC →](7-rpc-reference.md)

---

# Rozdział 6: Parametry sieci i konfiguracja

Kompletne odniesienie dla konfiguracji sieci Bitcoin-PoCX we wszystkich typach sieci.

---

## Spis treści

1. [Parametry bloku genesis](#parametry-bloku-genesis)
2. [Konfiguracja chainparams](#konfiguracja-chainparams)
3. [Parametry konsensusu](#parametry-konsensusu)
4. [Coinbase i nagrody za blok](#coinbase-i-nagrody-za-blok)
5. [Dynamiczne skalowanie](#dynamiczne-skalowanie)
6. [Konfiguracja sieci](#konfiguracja-sieci)
7. [Struktura katalogu danych](#struktura-katalogu-danych)

---

## Parametry bloku genesis

### Obliczenie base target

**Formuła**: `genesis_base_target = 2^42 / block_time_seconds`

**Uzasadnienie**:
- Każdy nonce reprezentuje 256 KiB (64 bajty × 4096 scoopów)
- 1 TiB = 2^22 nonce'ów (założenie początkowej pojemności sieci)
- Oczekiwana minimalna jakość dla n nonce'ów ≈ 2^64 / n
- Dla 1 TiB: E(jakość) = 2^64 / 2^22 = 2^42
- Dlatego: base_target = 2^42 / block_time

**Obliczone wartości**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Używa trybu kalibracji niskiej pojemności

### Wiadomość genesis

Wszystkie sieci dzielą wiadomość genesis Bitcoina:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementacja**: `src/kernel/chainparams.cpp`

---

## Konfiguracja chainparams

### Parametry mainnet

**Tożsamość sieci**:
- **Bajty magiczne**: `0xa7 0x3c 0x91 0x5e`
- **Domyślny port**: `8888`
- **Bech32 HRP**: `pocx`

**Prefiksy adresów** (Base58):
- PUBKEY_ADDRESS: `85` (adresy zaczynają się od 'P')
- SCRIPT_ADDRESS: `90` (adresy zaczynają się od 'R')
- SECRET_KEY: `128`

**Czasy bloków**:
- **Docelowy czas bloku**: `120` sekund (2 minuty)
- **Docelowy przedział czasowy**: `1209600` sekund (14 dni)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Nagrody za blok**:
- **Początkowa dotacja**: `10 BTC`
- **Interwał halvingu**: `1050000` bloków (~4 lata)
- **Liczba halvingów**: Maksymalnie 64 halvingi

**Dostosowanie trudności**:
- **Okno kroczące**: `24` bloki
- **Dostosowanie**: Przy każdym bloku
- **Algorytm**: Wykładnicza średnia krocząca

**Opóźnienia przydziałów**:
- **Aktywacja**: `30` bloków (~1 godzina)
- **Cofnięcie**: `720` bloków (~24 godziny)

### Parametry testnet

**Tożsamość sieci**:
- **Bajty magiczne**: `0x6d 0xf2 0x48 0xb3`
- **Domyślny port**: `18888`
- **Bech32 HRP**: `tpocx`

**Prefiksy adresów** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Czasy bloków**:
- **Docelowy czas bloku**: `120` sekund
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund
- **Dozwolona minimalna trudność**: `true`

**Nagrody za blok**:
- **Początkowa dotacja**: `10 BTC`
- **Interwał halvingu**: `1050000` bloków

**Dostosowanie trudności**:
- **Okno kroczące**: `24` bloki

**Opóźnienia przydziałów**:
- **Aktywacja**: `30` bloków (~1 godzina)
- **Cofnięcie**: `720` bloków (~24 godziny)

### Parametry regtest

**Tożsamość sieci**:
- **Bajty magiczne**: `0xfa 0xbf 0xb5 0xda`
- **Domyślny port**: `18444`
- **Bech32 HRP**: `rpocx`

**Prefiksy adresów** (kompatybilne z Bitcoinem):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Czasy bloków**:
- **Docelowy czas bloku**: `1` sekunda (natychmiastowe wydobycie do testów)
- **Docelowy przedział czasowy**: `86400` sekund (1 dzień)
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Nagrody za blok**:
- **Początkowa dotacja**: `10 BTC`
- **Interwał halvingu**: `500` bloków

**Dostosowanie trudności**:
- **Okno kroczące**: `24` bloki
- **Dozwolona minimalna trudność**: `true`
- **Brak ponownego celowania**: `true`
- **Kalibracja niskiej pojemności**: `true` (używa kalibracji 16-nonce zamiast 1 TiB)

**Opóźnienia przydziałów**:
- **Aktywacja**: `4` bloki (~4 sekundy)
- **Cofnięcie**: `8` bloków (~8 sekund)

### Parametry signet

**Tożsamość sieci**:
- **Bajty magiczne**: Pierwsze 4 bajty SHA256d(signet_challenge)
- **Domyślny port**: `38333`
- **Bech32 HRP**: `tpocx`

**Czasy bloków**:
- **Docelowy czas bloku**: `120` sekund
- **MAX_FUTURE_BLOCK_TIME**: `15` sekund

**Nagrody za blok**:
- **Początkowa dotacja**: `10 BTC`
- **Interwał halvingu**: `1050000` bloków

**Dostosowanie trudności**:
- **Okno kroczące**: `24` bloki

---

## Parametry konsensusu

### Parametry czasowe

**MAX_FUTURE_BLOCK_TIME**: `15` sekund
- Specyficzne dla PoCX (Bitcoin używa 2 godzin)
- Uzasadnienie: Czas PoC wymaga walidacji niemal w czasie rzeczywistym
- Bloki więcej niż 15s w przyszłości są odrzucane

**Ostrzeżenie przesunięcia czasu**: `10` sekund
- Operatorzy ostrzegani gdy zegar węzła odchyla się >10s od czasu sieci
- Bez wymuszania, tylko informacyjne

**Docelowe czasy bloków**:
- Mainnet/Testnet/Signet: `120` sekund
- Regtest: `1` sekunda

**TIMESTAMP_WINDOW**: `15` sekund (równe MAX_FUTURE_BLOCK_TIME)

**Implementacja**: `src/chain.h`, `src/validation.cpp`

### Parametry dostosowania trudności

**Rozmiar okna kroczącego**: `24` bloki (wszystkie sieci)
- Wykładnicza średnia krocząca ostatnich czasów bloków
- Dostosowanie przy każdym bloku
- Responsywne na zmiany pojemności

**Implementacja**: `src/consensus/params.h`, logika trudności przy tworzeniu bloku

### Parametry systemu przydziałów

**nForgingAssignmentDelay** (opóźnienie aktywacji):
- Mainnet: `30` bloków (~1 godzina)
- Testnet: `30` bloków (~1 godzina)
- Regtest: `4` bloki (~4 sekundy)

**nForgingRevocationDelay** (opóźnienie cofnięcia):
- Mainnet: `720` bloków (~24 godziny)
- Testnet: `720` bloków (~24 godziny)
- Regtest: `8` bloków (~8 sekund)

**Uzasadnienie**:
- Opóźnienie aktywacji zapobiega szybkim zmianom przydziałów podczas wyścigów bloków
- Opóźnienie cofnięcia zapewnia stabilność i zapobiega nadużyciom

**Implementacja**: `src/consensus/params.h`

---

## Coinbase i nagrody za blok

### Harmonogram dotacji blokowych

**Początkowa dotacja**: `10 BTC` (wszystkie sieci)

**Harmonogram halvingów**:
- Co `1050000` bloków (mainnet/testnet)
- Co `500` bloków (regtest)
- Kontynuuje przez maksymalnie 64 halvingi

**Progresja halvingów**:
```
Halving 0: 10.00000000 BTC  (bloki 0 - 1049999)
Halving 1:  5.00000000 BTC  (bloki 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (bloki 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (bloki 3150000 - 4199999)
...
```

**Całkowita podaż**: ~21 milionów BTC (tak jak Bitcoin)

### Zasady wyjścia coinbase

**Miejsce docelowe płatności**:
- **Bez przydziału**: Coinbase płaci adresowi plotu (proof.account_id)
- **Z przydziałem**: Coinbase płaci adresowi kucia (efektywny podpisujący)

**Format wyjścia**: Tylko P2WPKH
- Coinbase musi płacić na adres bech32 SegWit v0
- Generowany z klucza publicznego efektywnego podpisującego

**Rozwiązywanie przydziału**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementacja**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dynamiczne skalowanie

### Granice skalowania

**Cel**: Zwiększenie trudności generowania plotów w miarę dojrzewania sieci, aby zapobiec inflacji pojemności

**Struktura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimalny akceptowany poziom
    uint8_t nPoCXTargetCompression;  // Zalecany poziom
};
```

**Relacja**: `target = min + 1` (zawsze jeden poziom powyżej minimum)

### Harmonogram zwiększania skalowania

Poziomy skalowania rosną według **harmonogramu wykładniczego** opartego na interwałach halvingu:

| Okres | Wysokość bloku | Halvingi | Min | Cel |
|-------|----------------|----------|-----|-----|
| Lata 0-4 | 0 do 1049999 | 0 | X1 | X2 |
| Lata 4-12 | 1050000 do 3149999 | 1-2 | X2 | X3 |
| Lata 12-28 | 3150000 do 7349999 | 3-6 | X3 | X4 |
| Lata 28-60 | 7350000 do 15749999 | 7-14 | X4 | X5 |
| Lata 60-124 | 15750000 do 32549999 | 15-30 | X5 | X6 |
| Lata 124+ | 32550000+ | 31+ | X6 | X7 |

**Kluczowe wysokości** (lata → halvingi → bloki):
- Rok 4: Halving 1 przy bloku 1050000
- Rok 12: Halving 3 przy bloku 3150000
- Rok 28: Halving 7 przy bloku 7350000
- Rok 60: Halving 15 przy bloku 15750000
- Rok 124: Halving 31 przy bloku 32550000

### Trudność poziomu skalowania

**Skalowanie PoW**:
- Poziom skalowania X0: Bazowy POC2 (teoretyczny)
- Poziom skalowania X1: Bazowy XOR-transpose
- Poziom skalowania Xn: 2^(n-1) × praca X1 osadzona
- Każdy poziom podwaja pracę generowania plotu

**Wyrównanie ekonomiczne**:
- Nagrody za blok dzielone na pół → trudność generowania plotów rośnie
- Utrzymuje margines bezpieczeństwa: koszt tworzenia plotu > koszt wyszukiwania
- Zapobiega inflacji pojemności z powodu ulepszeń sprzętowych

### Walidacja plotów

**Reguły walidacji**:
- Zgłoszone dowody muszą mieć poziom skalowania ≥ minimum
- Dowody ze skalowaniem > celu akceptowane, ale nieefektywne
- Dowody poniżej minimum: odrzucone (niewystarczający PoW)

**Pobieranie granic**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementacja**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Konfiguracja sieci

### Węzły seed i seed DNS

**Status**: Symbol zastępczy dla uruchomienia mainnet

**Planowana konfiguracja**:
- Węzły seed: Do ustalenia
- Seedy DNS: Do ustalenia

**Aktualny stan** (testnet/regtest):
- Brak dedykowanej infrastruktury seed
- Ręczne połączenia z peerami obsługiwane przez `-addnode`

**Implementacja**: `src/kernel/chainparams.cpp`

### Checkpointy

**Checkpoint genesis**: Zawsze blok 0

**Dodatkowe checkpointy**: Aktualnie nieskonfigurowane

**Przyszłość**: Checkpointy będą dodawane w miarę postępu mainnetu

---

## Konfiguracja protokołu P2P

### Wersja protokołu

**Baza**: Protokół Bitcoin Core v30.0
- **Wersja protokołu**: Odziedziczona z Bitcoin Core
- **Bity usług**: Standardowe usługi Bitcoin
- **Typy wiadomości**: Standardowe wiadomości P2P Bitcoin

**Rozszerzenia PoCX**:
- Nagłówki bloków zawierają pola specyficzne dla PoCX
- Wiadomości bloków zawierają dane dowodu PoCX
- Reguły walidacji wymuszają konsensus PoCX

**Kompatybilność**: Węzły PoCX niekompatybilne z węzłami Bitcoin PoW (inny konsensus)

**Implementacja**: `src/protocol.h`, `src/net_processing.cpp`

---

## Struktura katalogu danych

### Domyślny katalog

**Lokalizacja**: `.bitcoin/` (tak jak Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Zawartość katalogu

```
.bitcoin/
├── blocks/              # Dane bloków
│   ├── blk*.dat        # Pliki bloków
│   ├── rev*.dat        # Dane cofania
│   └── index/          # Indeks bloków (LevelDB)
├── chainstate/         # Zbiór UTXO + przydziały kucia (LevelDB)
├── wallets/            # Pliki portfeli
│   └── wallet.dat      # Domyślny portfel
├── bitcoin.conf        # Plik konfiguracyjny
├── debug.log           # Log debugowania
├── peers.dat           # Adresy peerów
├── mempool.dat         # Trwałość mempoola
└── banlist.dat         # Zablokowani peerzy
```

### Kluczowe różnice od Bitcoina

**Baza danych chainstate**:
- Standardowa: Zbiór UTXO
- **Dodatek PoCX**: Stan przydziałów kucia
- Atomowe aktualizacje: UTXO + przydziały aktualizowane razem
- Dane cofania bezpieczne dla reorgów dla przydziałów

**Pliki bloków**:
- Standardowy format bloków Bitcoina
- **Dodatek PoCX**: Rozszerzone o pola dowodu PoCX (account_id, seed, nonce, signature, pubkey)

### Przykład pliku konfiguracyjnego

**bitcoin.conf**:
```ini
# Wybór sieci
#testnet=1
#regtest=1

# Serwer wydobywczy PoCX (wymagany dla zewnętrznych górników)
miningserver=1

# Ustawienia RPC
server=1
rpcuser=twojanazwauzytkownika
rpcpassword=twojehaslo
rpcallowip=127.0.0.1
rpcport=8332

# Ustawienia połączenia
listen=1
port=8888
maxconnections=125

# Docelowy czas bloku (informacyjny, wymuszany przez konsensus)
# 120 sekund dla mainnet/testnet
```

---

## Odniesienia do kodu

**Chainparams**: `src/kernel/chainparams.cpp`
**Parametry konsensusu**: `src/consensus/params.h`
**Granice kompresji**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Obliczenie genesis base target**: `src/pocx/consensus/params.cpp`
**Logika płatności coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Przechowywanie stanu przydziałów**: `src/coins.h`, `src/coins.cpp` (rozszerzenia CCoinsViewCache)

---

## Odnośniki wewnętrzne

Powiązane rozdziały:
- [Rozdział 2: Format plot](2-plot-format.md) - Poziomy skalowania w generowaniu plotów
- [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md) - Walidacja skalowania, system przydziałów
- [Rozdział 4: Przydziały kucia](4-forging-assignments.md) - Parametry opóźnień przydziałów
- [Rozdział 5: Bezpieczeństwo czasowe](5-timing-security.md) - Uzasadnienie MAX_FUTURE_BLOCK_TIME

---

[← Poprzedni: Synchronizacja czasu](5-timing-security.md) | [Spis treści](index.md) | [Dalej: Dokumentacja RPC →](7-rpc-reference.md)

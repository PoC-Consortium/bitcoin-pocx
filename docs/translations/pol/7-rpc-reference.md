[← Poprzedni: Parametry sieci](6-network-parameters.md) | [Spis treści](index.md) | [Dalej: Przewodnik po portfelu →](8-wallet-guide.md)

---

# Rozdział 7: Dokumentacja interfejsu RPC

Kompletna dokumentacja poleceń RPC Bitcoin-PoCX, w tym RPC wydobycia, zarządzanie przydziałami oraz zmodyfikowane RPC blockchainu.

---

## Spis treści

1. [Konfiguracja](#konfiguracja)
2. [RPC wydobycia PoCX](#rpc-wydobycia-pocx)
3. [RPC przydziałów](#rpc-przydziałów)
4. [Zmodyfikowane RPC blockchainu](#zmodyfikowane-rpc-blockchainu)
5. [Wyłączone RPC](#wyłączone-rpc)
6. [Przykłady integracji](#przykłady-integracji)

---

## Konfiguracja

### Tryb serwera wydobywczego

**Flaga**: `-miningserver`

**Cel**: Włącza dostęp RPC dla zewnętrznych górników do wywoływania RPC specyficznych dla wydobycia

**Wymagania**:
- Wymagany do działania `submit_nonce`
- Wymagany dla widoczności dialogu przydziału kucia w portfelu Qt

**Użycie**:
```bash
# Linia poleceń
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Rozważania bezpieczeństwa**:
- Brak dodatkowej autentykacji poza standardowymi poświadczeniami RPC
- RPC wydobycia są ograniczone przepustowością kolejki
- Standardowa autentykacja RPC nadal wymagana

**Implementacja**: `src/pocx/rpc/mining.cpp`

---

## RPC wydobycia PoCX

### get_mining_info

**Kategoria**: mining
**Wymaga serwera wydobywczego**: Nie
**Wymaga portfela**: Nie

**Cel**: Zwraca aktualne parametry wydobycia potrzebne zewnętrznym górnikom do skanowania plików plot i obliczania deadline'ów.

**Parametry**: Brak

**Wartości zwracane**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 znaki
  "base_target": 36650387593,                // numeryczny
  "height": 12345,                           // numeryczny, wysokość następnego bloku
  "block_hash": "def456...",                 // hex, poprzedni blok
  "target_quality": 18446744073709551615,    // uint64_max (wszystkie rozwiązania akceptowane)
  "minimum_compression_level": 1,            // numeryczny
  "target_compression_level": 2              // numeryczny
}
```

**Opisy pól**:
- `generation_signature`: Deterministyczna entropia wydobycia dla tej wysokości bloku
- `base_target`: Aktualna trudność (wyższa = łatwiejsza)
- `height`: Wysokość bloku, którą górnicy powinni celować
- `block_hash`: Hash poprzedniego bloku (informacyjny)
- `target_quality`: Próg jakości (obecnie uint64_max, bez filtrowania)
- `minimum_compression_level`: Minimalna kompresja wymagana do walidacji
- `target_compression_level`: Zalecana kompresja dla optymalnego wydobycia

**Kody błędów**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Węzeł nadal synchronizuje

**Przykład**:
```bash
bitcoin-cli get_mining_info
```

**Implementacja**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategoria**: mining
**Wymaga serwera wydobywczego**: Tak
**Wymaga portfela**: Tak (dla kluczy prywatnych)

**Cel**: Zgłoś rozwiązanie wydobywcze PoCX. Waliduje dowód, kolejkuje do zgiętego czasowo kucia i automatycznie tworzy blok w zaplanowanym czasie.

**Parametry**:
1. `height` (numeryczny, wymagany) - Wysokość bloku
2. `generation_signature` (string hex, wymagany) - Sygnatura generacji (64 znaki)
3. `account_id` (string, wymagany) - ID konta plotu (40 znaków hex = 20 bajtów)
4. `seed` (string, wymagany) - Seed plotu (64 znaki hex = 32 bajty)
5. `nonce` (numeryczny, wymagany) - Nonce wydobywczy
6. `compression` (numeryczny, wymagany) - Używany poziom skalowania/kompresji (1-255)
7. `quality` (numeryczny, opcjonalny) - Wartość jakości (przeliczana jeśli pominięta)

**Wartości zwracane** (sukces):
```json
{
  "accepted": true,
  "quality": 120,           // deadline dostosowany do trudności w sekundach
  "poc_time": 45            // zgięty czasowo czas kucia w sekundach
}
```

**Wartości zwracane** (odrzucone):
```json
{
  "accepted": false,
  "error": "Niezgodność sygnatury generacji"
}
```

**Kroki walidacji**:
1. **Walidacja formatu** (szybkie niepowodzenie):
   - ID konta: dokładnie 40 znaków hex
   - Seed: dokładnie 64 znaki hex
2. **Walidacja kontekstu**:
   - Wysokość musi pasować do aktualnej końcówki + 1
   - Sygnatura generacji musi pasować do aktualnej
3. **Weryfikacja portfela**:
   - Określ efektywnego podpisującego (sprawdź aktywne przydziały)
   - Zweryfikuj czy portfel ma klucz prywatny dla efektywnego podpisującego
4. **Walidacja dowodu** (kosztowna):
   - Zwaliduj dowód PoCX z granicami kompresji
   - Oblicz surową jakość
5. **Zgłoszenie do harmonogramu**:
   - Kolejkuj nonce do zgiętego czasowo kucia
   - Blok zostanie utworzony automatycznie w forge_time

**Kody błędów**:
- `RPC_INVALID_PARAMETER`: Nieprawidłowy format (account_id, seed) lub niezgodność wysokości
- `RPC_VERIFY_REJECTED`: Niezgodność sygnatury generacji lub niepowodzenie walidacji dowodu
- `RPC_INVALID_ADDRESS_OR_KEY`: Brak klucza prywatnego dla efektywnego podpisującego
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Kolejka zgłoszeń pełna
- `RPC_INTERNAL_ERROR`: Nie udało się zainicjalizować harmonogramu PoCX

**Kody błędów walidacji dowodu**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Przykład**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Uwagi**:
- Zgłoszenie jest asynchroniczne — RPC zwraca natychmiast, blok kuty później
- Time Bending opóźnia dobre rozwiązania, aby umożliwić skanowanie plotów w całej sieci
- System przydziałów: jeśli plot przydzielony, portfel musi mieć klucz adresu kucia
- Granice kompresji dynamicznie dostosowywane na podstawie wysokości bloku

**Implementacja**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC przydziałów

### get_assignment

**Kategoria**: mining
**Wymaga serwera wydobywczego**: Nie
**Wymaga portfela**: Nie

**Cel**: Zapytaj o status przydziału kucia dla adresu plotu. Tylko odczyt, portfel nie wymagany.

**Parametry**:
1. `plot_address` (string, wymagany) - Adres plotu (format bech32 P2WPKH)
2. `height` (numeryczny, opcjonalny) - Wysokość bloku do zapytania (domyślnie: aktualna końcówka)

**Wartości zwracane** (brak przydziału):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Wartości zwracane** (aktywny przydział):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Wartości zwracane** (cofanie):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Stany przydziałów**:
- `UNASSIGNED`: Brak przydziału
- `ASSIGNING`: Transakcja przydziału potwierdzona, opóźnienie aktywacji w trakcie
- `ASSIGNED`: Przydział aktywny, prawa kucia delegowane
- `REVOKING`: Transakcja cofnięcia potwierdzona, nadal aktywny do upływu opóźnienia
- `REVOKED`: Cofnięcie zakończone, prawa kucia zwrócone właścicielowi plotu

**Kody błędów**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Nieprawidłowy adres lub nie P2WPKH (bech32)

**Przykład**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementacja**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategoria**: wallet
**Wymaga serwera wydobywczego**: Nie
**Wymaga portfela**: Tak (musi być załadowany i odblokowany)

**Cel**: Utwórz transakcję przydziału kucia, aby delegować prawa kucia na inny adres (np. pulę wydobywczą).

**Parametry**:
1. `plot_address` (string, wymagany) - Adres właściciela plotu (musi posiadać klucz prywatny, P2WPKH bech32)
2. `forging_address` (string, wymagany) - Adres do przydzielenia praw kucia (P2WPKH bech32)
3. `fee_rate` (numeryczny, opcjonalny) - Stawka opłaty w BTC/kvB (domyślnie: 10× minRelayFee)

**Wartości zwracane**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Wymagania**:
- Portfel załadowany i odblokowany
- Klucz prywatny dla plot_address w portfelu
- Oba adresy muszą być P2WPKH (format bech32: pocx1q... mainnet, tpocx1q... testnet)
- Adres plotu musi mieć potwierdzone UTXO (dowodzi własności)
- Plot nie może mieć aktywnego przydziału (najpierw użyj revoke)

**Struktura transakcji**:
- Wejście: UTXO z adresu plotu (dowodzi własności)
- Wyjście: OP_RETURN (46 bajtów): znacznik `POCX` + adres_plotu (20 bajtów) + adres_kucia (20 bajtów)
- Wyjście: Reszta zwracana do portfela

**Aktywacja**:
- Przydział staje się ASSIGNING przy potwierdzeniu
- Staje się ACTIVE po `nForgingAssignmentDelay` blokach
- Opóźnienie zapobiega szybkim zmianom przydziałów podczas forków łańcucha

**Kody błędów**:
- `RPC_WALLET_NOT_FOUND`: Brak dostępnego portfela
- `RPC_WALLET_UNLOCK_NEEDED`: Portfel zaszyfrowany i zablokowany
- `RPC_WALLET_ERROR`: Niepowodzenie tworzenia transakcji
- `RPC_INVALID_ADDRESS_OR_KEY`: Nieprawidłowy format adresu

**Przykład**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementacja**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategoria**: wallet
**Wymaga serwera wydobywczego**: Nie
**Wymaga portfela**: Tak (musi być załadowany i odblokowany)

**Cel**: Cofnij istniejący przydział kucia, zwracając prawa kucia właścicielowi plotu.

**Parametry**:
1. `plot_address` (string, wymagany) - Adres plotu (musi posiadać klucz prywatny, P2WPKH bech32)
2. `fee_rate` (numeryczny, opcjonalny) - Stawka opłaty w BTC/kvB (domyślnie: 10× minRelayFee)

**Wartości zwracane**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Wymagania**:
- Portfel załadowany i odblokowany
- Klucz prywatny dla plot_address w portfelu
- Adres plotu musi być P2WPKH (format bech32)
- Adres plotu musi mieć potwierdzone UTXO

**Struktura transakcji**:
- Wejście: UTXO z adresu plotu (dowodzi własności)
- Wyjście: OP_RETURN (26 bajtów): znacznik `XCOP` + adres_plotu (20 bajtów)
- Wyjście: Reszta zwracana do portfela

**Efekt**:
- Stan przechodzi do REVOKING natychmiast
- Adres kucia nadal może kuć podczas okresu opóźnienia
- Staje się REVOKED po `nForgingRevocationDelay` blokach
- Właściciel plotu może kuć po wejściu w życie cofnięcia
- Można utworzyć nowy przydział po zakończeniu cofnięcia

**Kody błędów**:
- `RPC_WALLET_NOT_FOUND`: Brak dostępnego portfela
- `RPC_WALLET_UNLOCK_NEEDED`: Portfel zaszyfrowany i zablokowany
- `RPC_WALLET_ERROR`: Niepowodzenie tworzenia transakcji

**Przykład**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Uwagi**:
- Idempotentne: można cofnąć nawet jeśli brak aktywnego przydziału
- Nie można anulować cofnięcia po zgłoszeniu

**Implementacja**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Zmodyfikowane RPC blockchainu

### getdifficulty

**Modyfikacje PoCX**:
- **Obliczenie**: `referencyjny_base_target / aktualny_base_target`
- **Odniesienie**: Pojemność sieci 1 TiB (base_target = 36650387593)
- **Interpretacja**: Szacowana pojemność pamięci sieci w TiB
  - Przykład: `1.0` = ~1 TiB
  - Przykład: `1024.0` = ~1 PiB
- **Różnica od PoW**: Reprezentuje pojemność, nie moc hash

**Przykład**:
```bash
bitcoin-cli getdifficulty
# Zwraca: 2048.5 (sieć ~2 PiB)
```

**Implementacja**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Dodane pola PoCX**:
- `time_since_last_block` (numeryczny) - Sekundy od poprzedniego bloku (zastępuje mediantime)
- `poc_time` (numeryczny) - Zgięty czasowo czas kucia w sekundach
- `base_target` (numeryczny) - Base target trudności PoCX
- `generation_signature` (string hex) - Sygnatura generacji
- `pocx_proof` (obiekt):
  - `account_id` (string hex) - ID konta plotu (20 bajtów)
  - `seed` (string hex) - Seed plotu (32 bajty)
  - `nonce` (numeryczny) - Nonce wydobywczy
  - `compression` (numeryczny) - Użyty poziom skalowania
  - `quality` (numeryczny) - Zadeklarowana wartość jakości
- `pubkey` (string hex) - Klucz publiczny podpisującego blok (33 bajty)
- `signer_address` (string) - Adres podpisującego blok
- `signature` (string hex) - Sygnatura bloku (65 bajtów)

**Usunięte pola PoCX**:
- `mediantime` - Usunięty (zastąpiony przez time_since_last_block)

**Przykład**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementacja**: `src/rpc/blockchain.cpp`

---

### getblock

**Modyfikacje PoCX**: Takie same jak getblockheader, plus pełne dane transakcji

**Przykład**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose ze szczegółami tx
```

**Implementacja**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Dodane pola PoCX**:
- `base_target` (numeryczny) - Aktualny base target
- `generation_signature` (string hex) - Aktualna sygnatura generacji

**Zmodyfikowane pola PoCX**:
- `difficulty` - Używa obliczenia PoCX (oparte na pojemności)

**Usunięte pola PoCX**:
- `mediantime` - Usunięty

**Przykład**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementacja**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Dodane pola PoCX**:
- `generation_signature` (string hex) - Dla wydobycia w puli
- `base_target` (numeryczny) - Dla wydobycia w puli

**Usunięte pola PoCX**:
- `target` - Usunięty (specyficzny dla PoW)
- `noncerange` - Usunięty (specyficzny dla PoW)
- `bits` - Usunięty (specyficzny dla PoW)

**Uwagi**:
- Nadal zawiera pełne dane transakcji do konstrukcji bloku
- Używany przez serwery pul do skoordynowanego wydobycia

**Przykład**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementacja**: `src/rpc/mining.cpp`

---

## Wyłączone RPC

Następujące RPC specyficzne dla PoW są **wyłączone** w trybie PoCX:

### getnetworkhashps
- **Powód**: Hash rate nie dotyczy Proof of Capacity
- **Alternatywa**: Użyj `getdifficulty` dla szacunku pojemności sieci

### getmininginfo
- **Powód**: Zwraca informacje specyficzne dla PoW
- **Alternatywa**: Użyj `get_mining_info` (specyficzne dla PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Powód**: Wydobycie CPU nie dotyczy PoCX (wymaga wstępnie wygenerowanych plotów)
- **Alternatywa**: Użyj zewnętrznego plottera + minera + `submit_nonce`

**Implementacja**: `src/rpc/mining.cpp` (RPC zwracają błąd gdy zdefiniowane ENABLE_POCX)

---

## Przykłady integracji

### Integracja zewnętrznego górnika

**Podstawowa pętla wydobycia**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Pętla wydobycia
while True:
    # 1. Pobierz parametry wydobycia
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skanuj pliki plot (zewnętrzna implementacja)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Zgłoś najlepsze rozwiązanie
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Rozwiązanie zaakceptowane! Jakość: {result['quality']}s, "
              f"Czas kucia: {result['poc_time']}s")

    # 4. Czekaj na następny blok
    time.sleep(10)  # Interwał odpytywania
```

---

### Wzorzec integracji puli

**Przepływ pracy serwera puli**:
1. Górnicy tworzą przydziały kucia na adres puli
2. Pula uruchamia portfel z kluczami adresu kucia
3. Pula wywołuje `get_mining_info` i dystrybuuje do górników
4. Górnicy zgłaszają rozwiązania przez pulę (nie bezpośrednio do łańcucha)
5. Pula waliduje i wywołuje `submit_nonce` z kluczami puli
6. Pula dystrybuuje nagrody zgodnie z polityką puli

**Zarządzanie przydziałami**:
```bash
# Górnik tworzy przydział (z portfela górnika)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Czekaj na aktywację (30 bloków mainnet)

# Pula sprawdza status przydziału
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pula może teraz zgłaszać nonce'y dla tego plotu
# (portfel puli musi mieć klucz prywatny pocx1qpool...)
```

---

### Zapytania eksploratora bloków

**Zapytanie o dane bloku PoCX**:
```bash
# Pobierz najnowszy blok
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Pobierz szczegóły bloku z dowodem PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Wyodrębnij pola specyficzne dla PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Wykrywanie transakcji przydziałów**:
```bash
# Skanuj transakcję pod kątem OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Sprawdź znacznik przydziału (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Obsługa błędów

### Typowe wzorce błędów

**Niezgodność wysokości**:
```json
{
  "accepted": false,
  "error": "Niezgodność wysokości: zgłoszona 12345, aktualna 12346"
}
```
**Rozwiązanie**: Ponownie pobierz informacje wydobycia, łańcuch poszedł do przodu

**Niezgodność sygnatury generacji**:
```json
{
  "accepted": false,
  "error": "Niezgodność sygnatury generacji"
}
```
**Rozwiązanie**: Ponownie pobierz informacje wydobycia, przybył nowy blok

**Brak klucza prywatnego**:
```json
{
  "code": -5,
  "message": "Brak dostępnego klucza prywatnego dla efektywnego podpisującego"
}
```
**Rozwiązanie**: Zaimportuj klucz dla adresu plotu lub kucia

**Oczekiwanie na aktywację przydziału**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Rozwiązanie**: Czekaj na upłynięcie opóźnienia aktywacji

---

## Odniesienia do kodu

**RPC wydobycia**: `src/pocx/rpc/mining.cpp`
**RPC przydziałów**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC blockchainu**: `src/rpc/blockchain.cpp`
**Walidacja dowodu**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Stan przydziału**: `src/pocx/assignments/assignment_state.cpp`
**Tworzenie transakcji**: `src/pocx/assignments/transactions.cpp`

---

## Odnośniki wewnętrzne

Powiązane rozdziały:
- [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md) - Szczegóły procesu wydobycia
- [Rozdział 4: Przydziały kucia](4-forging-assignments.md) - Architektura systemu przydziałów
- [Rozdział 6: Parametry sieci](6-network-parameters.md) - Wartości opóźnień przydziałów
- [Rozdział 8: Przewodnik po portfelu](8-wallet-guide.md) - GUI do zarządzania przydziałami

---

[← Poprzedni: Parametry sieci](6-network-parameters.md) | [Spis treści](index.md) | [Dalej: Przewodnik po portfelu →](8-wallet-guide.md)

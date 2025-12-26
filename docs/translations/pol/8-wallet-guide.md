[← Poprzedni: Dokumentacja RPC](7-rpc-reference.md) | [Spis treści](index.md)

---

# Rozdział 8: Przewodnik po portfelu i GUI

Kompletny przewodnik po portfelu Qt Bitcoin-PoCX i zarządzaniu przydziałami kucia.

---

## Spis treści

1. [Przegląd](#przegląd)
2. [Jednostki waluty](#jednostki-waluty)
3. [Dialog przydziału kucia](#dialog-przydziału-kucia)
4. [Historia transakcji](#historia-transakcji)
5. [Wymagania adresów](#wymagania-adresów)
6. [Integracja wydobycia](#integracja-wydobycia)
7. [Rozwiązywanie problemów](#rozwiązywanie-problemów)
8. [Najlepsze praktyki bezpieczeństwa](#najlepsze-praktyki-bezpieczeństwa)

---

## Przegląd

### Funkcje portfela Bitcoin-PoCX

Portfel Qt Bitcoin-PoCX (`bitcoin-qt`) zapewnia:
- Standardową funkcjonalność portfela Bitcoin Core (wysyłanie, odbieranie, zarządzanie transakcjami)
- **Menedżer przydziałów kucia**: GUI do tworzenia/cofania przydziałów plotów
- **Tryb serwera wydobywczego**: Flaga `-miningserver` włącza funkcje związane z wydobyciem
- **Historia transakcji**: Wyświetlanie transakcji przydziałów i cofnięć

### Uruchamianie portfela

**Tylko węzeł** (bez wydobycia):
```bash
./build/bin/bitcoin-qt
```

**Z wydobyciem** (włącza dialog przydziałów):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternatywa linii poleceń**:
```bash
./build/bin/bitcoind -miningserver
```

### Wymagania wydobycia

**Do operacji wydobycia**:
- Wymagana flaga `-miningserver`
- Portfel z adresami P2WPKH i kluczami prywatnymi
- Zewnętrzny plotter (`pocx_plotter`) do generowania plotów
- Zewnętrzny górnik (`pocx_miner`) do wydobycia

**Do wydobycia w puli**:
- Utwórz przydział kucia na adres puli
- Portfel nie wymagany na serwerze puli (pula zarządza kluczami)

---

## Jednostki waluty

### Wyświetlanie jednostek

Bitcoin-PoCX używa jednostki waluty **BTCX** (nie BTC):

| Jednostka | Satoshi | Wyświetlanie |
|-----------|---------|--------------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Ustawienia GUI**: Preferencje → Wyświetlanie → Jednostka

---

## Dialog przydziału kucia

### Dostęp do dialogu

**Menu**: `Portfel → Przydziały kucia`
**Pasek narzędzi**: Ikona wydobycia (widoczna tylko z flagą `-miningserver`)
**Rozmiar okna**: 600×450 pikseli

### Tryby dialogu

#### Tryb 1: Utwórz przydział

**Cel**: Deleguj prawa kucia na pulę lub inny adres, zachowując własność plotu.

**Przypadki użycia**:
- Wydobycie w puli (przydziel do adresu puli)
- Zimne przechowywanie (klucz wydobywczy oddzielony od własności plotu)
- Współdzielona infrastruktura (deleguj do gorącego portfela)

**Wymagania**:
- Adres plotu (P2WPKH bech32, musi posiadać klucz prywatny)
- Adres kucia (P2WPKH bech32, inny niż adres plotu)
- Portfel odblokowany (jeśli zaszyfrowany)
- Adres plotu ma potwierdzone UTXO

**Kroki**:
1. Wybierz tryb "Utwórz przydział"
2. Wybierz adres plotu z listy rozwijanej lub wprowadź ręcznie
3. Wprowadź adres kucia (pula lub delegat)
4. Kliknij "Wyślij przydział" (przycisk włączony gdy dane wejściowe prawidłowe)
5. Transakcja rozgłaszana natychmiast
6. Przydział aktywny po `nForgingAssignmentDelay` blokach:
   - Mainnet/Testnet: 30 bloków (~1 godzina)
   - Regtest: 4 bloki (~4 sekundy)

**Opłata transakcyjna**: Domyślnie 10× `minRelayFee` (konfigurowalna)

**Struktura transakcji**:
- Wejście: UTXO z adresu plotu (dowodzi własności)
- Wyjście OP_RETURN: znacznik `POCX` + adres_plotu + adres_kucia (46 bajtów)
- Wyjście reszty: Zwracane do portfela

#### Tryb 2: Cofnij przydział

**Cel**: Anuluj przydział kucia i zwróć prawa właścicielowi plotu.

**Wymagania**:
- Adres plotu (musi posiadać klucz prywatny)
- Portfel odblokowany (jeśli zaszyfrowany)
- Adres plotu ma potwierdzone UTXO

**Kroki**:
1. Wybierz tryb "Cofnij przydział"
2. Wybierz adres plotu
3. Kliknij "Wyślij cofnięcie"
4. Transakcja rozgłaszana natychmiast
5. Cofnięcie wchodzi w życie po `nForgingRevocationDelay` blokach:
   - Mainnet/Testnet: 720 bloków (~24 godziny)
   - Regtest: 8 bloków (~8 sekund)

**Efekt**:
- Adres kucia nadal może kuć podczas okresu opóźnienia
- Właściciel plotu odzyskuje prawa po zakończeniu cofnięcia
- Można później utworzyć nowy przydział

**Struktura transakcji**:
- Wejście: UTXO z adresu plotu (dowodzi własności)
- Wyjście OP_RETURN: znacznik `XCOP` + adres_plotu (26 bajtów)
- Wyjście reszty: Zwracane do portfela

#### Tryb 3: Sprawdź status przydziału

**Cel**: Zapytaj o aktualny stan przydziału dla dowolnego adresu plotu.

**Wymagania**: Brak (tylko odczyt, portfel nie potrzebny)

**Kroki**:
1. Wybierz tryb "Sprawdź status przydziału"
2. Wprowadź adres plotu
3. Kliknij "Sprawdź status"
4. Pole statusu wyświetla aktualny stan ze szczegółami

**Wskaźniki stanu** (oznaczone kolorami):

**Szary - UNASSIGNED**
```
UNASSIGNED - Brak przydziału
```

**Pomarańczowy - ASSIGNING**
```
ASSIGNING - Przydział oczekuje na aktywację
Adres kucia: pocx1qforger...
Utworzony na wysokości: 12000
Aktywacja na wysokości: 12030 (5 bloków pozostało)
```

**Zielony - ASSIGNED**
```
ASSIGNED - Aktywny przydział
Adres kucia: pocx1qforger...
Utworzony na wysokości: 12000
Aktywowany na wysokości: 12030
```

**Czerwono-pomarańczowy - REVOKING**
```
REVOKING - Cofnięcie oczekuje
Adres kucia: pocx1qforger... (nadal aktywny)
Przydział utworzony na wysokości: 12000
Cofnięty na wysokości: 12300
Cofnięcie wchodzi w życie na wysokości: 13020 (50 bloków pozostało)
```

**Czerwony - REVOKED**
```
REVOKED - Przydział cofnięty
Poprzednio przydzielony do: pocx1qforger...
Przydział utworzony na wysokości: 12000
Cofnięty na wysokości: 12300
Cofnięcie weszło w życie na wysokości: 13020
```

---

## Historia transakcji

### Wyświetlanie transakcji przydziału

**Typ**: "Przydział"
**Ikona**: Ikona wydobycia (taka sama jak wykute bloki)

**Kolumna adresu**: Adres plotu (adres którego prawa kucia są przydzielane)
**Kolumna kwoty**: Opłata transakcyjna (ujemna, transakcja wychodząca)
**Kolumna statusu**: Liczba potwierdzeń (0-6+)

**Szczegóły** (po kliknięciu):
- ID transakcji
- Adres plotu
- Adres kucia (parsowany z OP_RETURN)
- Utworzony na wysokości
- Wysokość aktywacji
- Opłata transakcyjna
- Znacznik czasu

### Wyświetlanie transakcji cofnięcia

**Typ**: "Cofnięcie"
**Ikona**: Ikona wydobycia

**Kolumna adresu**: Adres plotu
**Kolumna kwoty**: Opłata transakcyjna (ujemna)
**Kolumna statusu**: Liczba potwierdzeń

**Szczegóły** (po kliknięciu):
- ID transakcji
- Adres plotu
- Cofnięty na wysokości
- Wysokość wejścia w życie cofnięcia
- Opłata transakcyjna
- Znacznik czasu

### Filtrowanie transakcji

**Dostępne filtry**:
- "Wszystkie" (domyślnie, zawiera przydziały/cofnięcia)
- Zakres dat
- Zakres kwot
- Szukaj po adresie
- Szukaj po ID transakcji
- Szukaj po etykiecie (jeśli adres ma etykietę)

**Uwaga**: Transakcje przydziałów/cofnięć obecnie pojawiają się pod filtrem "Wszystkie". Dedykowany filtr typu jeszcze nie zaimplementowany.

### Sortowanie transakcji

**Kolejność sortowania** (według typu):
- Wygenerowane (typ 0)
- Otrzymane (typ 1-3)
- Przydział (typ 4)
- Cofnięcie (typ 5)
- Wysłane (typ 6+)

---

## Wymagania adresów

### Tylko P2WPKH (SegWit v0)

**Operacje kucia wymagają**:
- Adresy zakodowane bech32 (zaczynające się od "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Format P2WPKH (Pay-to-Witness-Public-Key-Hash)
- 20-bajtowy hash klucza

**NIE obsługiwane**:
- P2PKH (starsze, zaczynające się od "1")
- P2SH (opakowany SegWit, zaczynający się od "3")
- P2TR (Taproot, zaczynający się od "bc1p")

**Uzasadnienie**: Sygnatury bloków PoCX wymagają specyficznego formatu witness v0 do walidacji dowodów.

### Filtrowanie listy rozwijanej adresów

**Lista adresów plotu**:
- Automatycznie wypełniana adresami odbiorczymi portfela
- Filtruje adresy nie-P2WPKH
- Pokazuje format: "Etykieta (adres)" jeśli ma etykietę, w przeciwnym razie sam adres
- Pierwsza pozycja: "-- Wprowadź własny adres --" do ręcznego wpisu

**Wpis ręczny**:
- Waliduje format przy wprowadzaniu
- Musi być prawidłowy bech32 P2WPKH
- Przycisk wyłączony przy nieprawidłowym formacie

### Komunikaty błędów walidacji

**Błędy dialogu**:
- "Adres plotu musi być P2WPKH (bech32)"
- "Adres kucia musi być P2WPKH (bech32)"
- "Nieprawidłowy format adresu"
- "Brak monet na adresie plotu. Nie można udowodnić własności."
- "Nie można tworzyć transakcji z portfela tylko do podglądu"
- "Portfel niedostępny"
- "Portfel zablokowany" (z RPC)

---

## Integracja wydobycia

### Wymagania konfiguracji

**Konfiguracja węzła**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Wymagania portfela**:
- Adresy P2WPKH dla własności plotu
- Klucze prywatne do wydobycia (lub adres kucia jeśli używane przydziały)
- Potwierdzone UTXO do tworzenia transakcji

**Zewnętrzne narzędzia**:
- `pocx_plotter`: Generowanie plików plot
- `pocx_miner`: Skanowanie plotów i zgłaszanie nonce'ów

### Przepływ pracy

#### Wydobycie solo

1. **Wygeneruj pliki plot**:
   ```bash
   pocx_plotter --account <hash160_adresu_plotu> --seed <32_bajty> --nonces <liczba>
   ```

2. **Uruchom węzeł** z serwerem wydobywczym:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Skonfiguruj górnika**:
   - Wskaż endpoint RPC węzła
   - Określ katalogi plików plot
   - Skonfiguruj ID konta (z adresu plotu)

4. **Uruchom wydobycie**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /sciezka/do/plotow
   ```

5. **Monitoruj**:
   - Górnik wywołuje `get_mining_info` przy każdym bloku
   - Skanuje ploty w poszukiwaniu najlepszego deadline'u
   - Wywołuje `submit_nonce` gdy rozwiązanie znalezione
   - Węzeł waliduje i automatycznie kuje blok

#### Wydobycie w puli

1. **Wygeneruj pliki plot** (tak samo jak solo)

2. **Utwórz przydział kucia**:
   - Otwórz dialog przydziału kucia
   - Wybierz adres plotu
   - Wprowadź adres kucia puli
   - Kliknij "Wyślij przydział"
   - Poczekaj na opóźnienie aktywacji (30 bloków testnet)

3. **Skonfiguruj górnika**:
   - Wskaż endpoint **puli** (nie lokalnego węzła)
   - Pula obsługuje `submit_nonce` do łańcucha

4. **Działanie puli**:
   - Portfel puli ma klucze prywatne adresu kucia
   - Pula waliduje zgłoszenia od górników
   - Pula wywołuje `submit_nonce` do blockchainu
   - Pula dystrybuuje nagrody zgodnie z polityką puli

### Nagrody coinbase

**Bez przydziału**:
- Coinbase płaci bezpośrednio do adresu właściciela plotu
- Sprawdź saldo na adresie plotu

**Z przydziałem**:
- Coinbase płaci do adresu kucia
- Pula otrzymuje nagrody
- Górnik otrzymuje udział od puli

**Harmonogram nagród**:
- Początkowe: 10 BTCX na blok
- Halving: Co 1050000 bloków (~4 lata)
- Harmonogram: 10 → 5 → 2.5 → 1.25 → ...

---

## Rozwiązywanie problemów

### Typowe problemy

#### "Portfel nie ma klucza prywatnego dla adresu plotu"

**Przyczyna**: Portfel nie jest właścicielem adresu
**Rozwiązanie**:
- Zaimportuj klucz prywatny przez RPC `importprivkey`
- Lub użyj innego adresu plotu będącego własnością portfela

#### "Przydział już istnieje dla tego plotu"

**Przyczyna**: Plot już przydzielony do innego adresu
**Rozwiązanie**:
1. Cofnij istniejący przydział
2. Poczekaj na opóźnienie cofnięcia (720 bloków testnet)
3. Utwórz nowy przydział

#### "Format adresu nie obsługiwany"

**Przyczyna**: Adres nie jest P2WPKH bech32
**Rozwiązanie**:
- Używaj adresów zaczynających się od "pocx1q" (mainnet) lub "tpocx1q" (testnet)
- Wygeneruj nowy adres jeśli potrzeba: `getnewaddress "" "bech32"`

#### "Opłata transakcyjna za niska"

**Przyczyna**: Zatłoczenie mempoola sieci lub opłata za niska do przekazania
**Rozwiązanie**:
- Zwiększ parametr stawki opłaty
- Poczekaj na opróżnienie mempoola

#### "Przydział jeszcze nieaktywny"

**Przyczyna**: Opóźnienie aktywacji jeszcze nie upłynęło
**Rozwiązanie**:
- Sprawdź status: bloków pozostałych do aktywacji
- Poczekaj na zakończenie okresu opóźnienia

#### "Brak monet na adresie plotu"

**Przyczyna**: Adres plotu nie ma potwierdzonych UTXO
**Rozwiązanie**:
1. Wyślij środki na adres plotu
2. Poczekaj na 1 potwierdzenie
3. Spróbuj ponownie utworzyć przydział

#### "Nie można tworzyć transakcji z portfela tylko do podglądu"

**Przyczyna**: Portfel zaimportował adres bez klucza prywatnego
**Rozwiązanie**: Zaimportuj pełny klucz prywatny, nie tylko adres

#### "Karta przydziału kucia niewidoczna"

**Przyczyna**: Węzeł uruchomiony bez flagi `-miningserver`
**Rozwiązanie**: Uruchom ponownie z `bitcoin-qt -server -miningserver`

### Kroki debugowania

1. **Sprawdź status portfela**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Zweryfikuj własność adresu**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Sprawdź: "iswatchonly": false, "ismine": true
   ```

3. **Sprawdź status przydziału**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Wyświetl ostatnie transakcje**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Sprawdź synchronizację węzła**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Zweryfikuj: blocks == headers (w pełni zsynchronizowany)
   ```

---

## Najlepsze praktyki bezpieczeństwa

### Bezpieczeństwo adresu plotu

**Zarządzanie kluczami**:
- Przechowuj klucze prywatne adresu plotu bezpiecznie
- Transakcje przydziału dowodzą własności przez sygnaturę
- Tylko właściciel plotu może tworzyć/cofać przydziały

**Kopia zapasowa**:
- Regularnie twórz kopię portfela (`dumpwallet` lub `backupwallet`)
- Przechowuj wallet.dat w bezpiecznej lokalizacji
- Zapisz frazy odzyskiwania jeśli używasz portfela HD

### Delegacja adresu kucia

**Model bezpieczeństwa**:
- Adres kucia otrzymuje nagrody za bloki
- Adres kucia może podpisywać bloki (wydobycie)
- Adres kucia **NIE MOŻE** modyfikować ani cofać przydziału
- Właściciel plotu zachowuje pełną kontrolę

**Przypadki użycia**:
- **Delegacja do gorącego portfela**: Klucz plotu w zimnym przechowywaniu, klucz kucia w gorącym portfelu do wydobycia
- **Wydobycie w puli**: Deleguj do puli, zachowaj własność plotu
- **Współdzielona infrastruktura**: Wielu górników, jeden adres kucia

### Synchronizacja czasu sieciowego

**Znaczenie**:
- Konsensus PoCX wymaga dokładnego czasu
- Dryf zegara >10s wyzwala ostrzeżenie
- Dryf zegara >15s uniemożliwia wydobycie

**Rozwiązanie**:
- Utrzymuj zegar systemowy zsynchronizowany z NTP
- Monitoruj: `bitcoin-cli getnetworkinfo` dla ostrzeżeń o przesunięciu czasu
- Używaj niezawodnych serwerów NTP

### Opóźnienia przydziałów

**Opóźnienie aktywacji** (30 bloków testnet):
- Zapobiega szybkim zmianom przydziałów podczas forków łańcucha
- Pozwala sieci osiągnąć konsensus
- Nie może być ominięte

**Opóźnienie cofnięcia** (720 bloków testnet):
- Zapewnia stabilność dla pul wydobywczych
- Zapobiega atakom "przeskakiwania przydziałów"
- Adres kucia pozostaje aktywny podczas opóźnienia

### Szyfrowanie portfela

**Włącz szyfrowanie**:
```bash
bitcoin-cli encryptwallet "twoje_haslo"
```

**Odblokuj do transakcji**:
```bash
bitcoin-cli walletpassphrase "twoje_haslo" 300
```

**Najlepsze praktyki**:
- Używaj silnego hasła (20+ znaków)
- Nie przechowuj hasła w zwykłym tekście
- Zablokuj portfel po utworzeniu przydziałów

---

## Odniesienia do kodu

**Dialog przydziału kucia**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Wyświetlanie transakcji**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsowanie transakcji**: `src/qt/transactionrecord.cpp`
**Integracja portfela**: `src/pocx/assignments/transactions.cpp`
**RPC przydziałów**: `src/pocx/rpc/assignments_wallet.cpp`
**Główne GUI**: `src/qt/bitcoingui.cpp`

---

## Odnośniki wewnętrzne

Powiązane rozdziały:
- [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md) - Proces wydobycia
- [Rozdział 4: Przydziały kucia](4-forging-assignments.md) - Architektura przydziałów
- [Rozdział 6: Parametry sieci](6-network-parameters.md) - Wartości opóźnień przydziałów
- [Rozdział 7: Dokumentacja RPC](7-rpc-reference.md) - Szczegóły poleceń RPC

---

[← Poprzedni: Dokumentacja RPC](7-rpc-reference.md) | [Spis treści](index.md)

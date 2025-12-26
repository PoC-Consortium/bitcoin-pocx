[Spis treści](index.md) | [Dalej: Format plot →](2-plot-format.md)

---

# Rozdział 1: Wprowadzenie i przegląd

## Czym jest Bitcoin-PoCX?

Bitcoin-PoCX to integracja Bitcoin Core dodająca wsparcie dla konsensusu **Proof of Capacity neXt generation (PoCX)**. Zachowuje istniejącą architekturę Bitcoin Core, jednocześnie umożliwiając energooszczędną alternatywę wydobycia Proof of Capacity jako pełne zastąpienie Proof of Work.

**Kluczowe rozróżnienie**: Jest to **nowy łańcuch** bez kompatybilności wstecznej z Bitcoin PoW. Bloki PoCX są celowo niekompatybilne z węzłami PoW.

---

## Tożsamość projektu

- **Organizacja**: Proof of Capacity Consortium
- **Nazwa projektu**: Bitcoin-PoCX
- **Pełna nazwa**: Bitcoin Core z integracją PoCX
- **Status**: Faza testowa (Testnet)

---

## Czym jest Proof of Capacity?

Proof of Capacity (PoC) to mechanizm konsensusu, w którym moc wydobywcza jest proporcjonalna do **przestrzeni dyskowej**, a nie mocy obliczeniowej. Górnicy wstępnie generują duże pliki plot zawierające kryptograficzne hasze, a następnie używają tych plotów do znajdowania prawidłowych rozwiązań bloków.

**Efektywność energetyczna**: Pliki plot są generowane raz i używane wielokrotnie w nieskończoność. Wydobycie zużywa minimalną moc CPU — głównie operacje wejścia/wyjścia dysku.

**Ulepszenia PoCX**:
- Naprawiony atak kompresji XOR-transpose (50% kompromis czas–pamięć w POC2)
- Układ wyrównany do 16 nonce'ów dla nowoczesnego sprzętu
- Skalowalny proof-of-work w generowaniu plotów (poziomy skalowania Xn)
- Natywna integracja C++ bezpośrednio w Bitcoin Core
- Algorytm Time Bending dla lepszego rozkładu czasów bloków

---

## Przegląd architektury

### Struktura repozytorium

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integracja PoCX
│   └── src/pocx/        # Implementacja PoCX
├── pocx/                # Framework core PoCX (submoduł, tylko do odczytu)
└── docs/                # Ta dokumentacja
```

### Filozofia integracji

**Minimalna powierzchnia integracji**: Zmiany izolowane w katalogu `/src/pocx/` z czystymi punktami zaczepienia do warstw walidacji, wydobycia i RPC Bitcoin Core.

**Flagi funkcji**: Wszystkie modyfikacje pod strażnikami preprocesora `#ifdef ENABLE_POCX`. Bitcoin Core kompiluje się normalnie, gdy są wyłączone.

**Kompatybilność z upstream**: Regularna synchronizacja z aktualizacjami Bitcoin Core utrzymywana poprzez izolowane punkty integracji.

**Natywna implementacja C++**: Skalarne algorytmy kryptograficzne (Shabal256, obliczanie scoop, kompresja) zintegrowane bezpośrednio w Bitcoin Core do walidacji konsensusu.

---

## Kluczowe funkcje

### 1. Całkowite zastąpienie konsensusu

- **Struktura bloku**: Pola specyficzne dla PoCX zastępują nonce PoW i bity trudności
  - Sygnatura generacji (deterministyczna entropia wydobycia)
  - Base target (odwrotność trudności)
  - Dowód PoCX (ID konta, seed, nonce)
  - Sygnatura bloku (dowód własności plotu)

- **Walidacja**: 5-etapowy potok walidacji od sprawdzenia nagłówka po połączenie bloku

- **Dostosowanie trudności**: Dostosowanie przy każdym bloku przy użyciu średniej kroczącej ostatnich base targetów

### 2. Algorytm Time Bending

**Problem**: Tradycyjne czasy bloków PoC podlegają rozkładowi wykładniczemu, co prowadzi do długich bloków, gdy żaden górnik nie znajduje dobrego rozwiązania.

**Rozwiązanie**: Transformacja rozkładu z wykładniczego do chi-kwadrat przy użyciu pierwiastka sześciennego: `Y = skala × (X^(1/3))`.

**Efekt**: Bardzo dobre rozwiązania są kute później (sieć ma czas na przeskanowanie wszystkich dysków, redukuje szybkie bloki), słabe rozwiązania są poprawiane. Średni czas bloku utrzymany na 120 sekundach, długie bloki zredukowane.

**Szczegóły**: [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md)

### 3. System przydziału kucia

**Możliwość**: Właściciele plotów mogą delegować prawa kucia na inne adresy, zachowując własność plotów.

**Przypadki użycia**:
- Wydobycie w puli (ploty przydzielone do adresu puli)
- Zimne przechowywanie (klucz wydobywczy oddzielony od własności plotu)
- Wydobycie wielostronowe (współdzielona infrastruktura)

**Architektura**: Projekt oparty wyłącznie na OP_RETURN — brak specjalnych UTXO, przydziały śledzone oddzielnie w bazie danych chainstate.

**Szczegóły**: [Rozdział 4: Przydziały kucia](4-forging-assignments.md)

### 4. Kucie obronne

**Problem**: Szybkie zegary mogą zapewnić przewagę czasową w ramach 15-sekundowej tolerancji przyszłości.

**Rozwiązanie**: Przy otrzymaniu konkurencyjnego bloku na tej samej wysokości, automatycznie sprawdź lokalną jakość. Jeśli lepsza, kuj natychmiast.

**Efekt**: Eliminuje zachętę do manipulacji zegarem — szybkie zegary pomagają tylko wtedy, gdy już masz najlepsze rozwiązanie.

**Szczegóły**: [Rozdział 5: Bezpieczeństwo czasowe](5-timing-security.md)

### 5. Dynamiczne skalowanie kompresji

**Wyrównanie ekonomiczne**: Wymagania poziomu skalowania rosną według harmonogramu wykładniczego (lata 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Efekt**: Wraz ze zmniejszaniem nagród za blok, trudność generowania plotów rośnie. Utrzymuje margines bezpieczeństwa między kosztami tworzenia plotu a kosztami wyszukiwania.

**Zapobiega**: Inflacji pojemności spowodowanej szybszym sprzętem w czasie.

**Szczegóły**: [Rozdział 6: Parametry sieci](6-network-parameters.md)

---

## Filozofia projektowa

### Bezpieczeństwo kodu

- Praktyki programowania defensywnego w całym kodzie
- Kompleksowa obsługa błędów w ścieżkach walidacji
- Brak zagnieżdżonych blokad (zapobieganie zakleszczeniom)
- Atomowe operacje bazodanowe (UTXO + przydziały razem)

### Architektura modularna

- Czyste rozdzielenie między infrastrukturą Bitcoin Core a konsensusem PoCX
- Framework core PoCX dostarcza prymitywy kryptograficzne
- Bitcoin Core dostarcza framework walidacji, bazę danych, sieć

### Optymalizacje wydajności

- Szybkie niepowodzenie w kolejności walidacji (tanie sprawdzenia najpierw)
- Pojedyncze pobranie kontekstu na zgłoszenie (brak powtarzanych pobrań cs_main)
- Atomowe operacje bazodanowe dla spójności

### Bezpieczeństwo reorganizacji

- Pełne dane cofania dla zmian stanu przydziałów
- Reset stanu kucia przy zmianach końcówki łańcucha
- Wykrywanie nieaktualności we wszystkich punktach walidacji

---

## Jak PoCX różni się od Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Zasób wydobywczy** | Moc obliczeniowa (hash rate) | Przestrzeń dyskowa (pojemność) |
| **Zużycie energii** | Wysokie (ciągłe haszowanie) | Niskie (tylko I/O dysku) |
| **Proces wydobycia** | Znajdź nonce z hashem < cel | Znajdź nonce z deadline < upływający czas |
| **Trudność** | Pole `bits`, dostosowywane co 2016 bloków | Pole `base_target`, dostosowywane przy każdym bloku |
| **Czas bloku** | ~10 minut (rozkład wykładniczy) | 120 sekund (time-bended, zmniejszona wariancja) |
| **Dotacja** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Sprzęt** | ASIC (wyspecjalizowany) | HDD (sprzęt konsumencki) |
| **Tożsamość wydobywcy** | Anonimowa | Właściciel plotu lub delegat |

---

## Wymagania systemowe

### Obsługa węzła

**Takie same jak Bitcoin Core**:
- **CPU**: Nowoczesny procesor x86_64
- **Pamięć**: 4-8 GB RAM
- **Dysk**: Nowy łańcuch, obecnie pusty (może rosnąć ~4× szybciej niż Bitcoin z powodu 2-minutowych bloków i bazy danych przydziałów)
- **Sieć**: Stabilne połączenie internetowe
- **Zegar**: Synchronizacja NTP zalecana dla optymalnego działania

**Uwaga**: Pliki plot NIE są wymagane do obsługi węzła.

### Wymagania wydobycia

**Dodatkowe wymagania do wydobycia**:
- **Pliki plot**: Wstępnie wygenerowane przy użyciu `pocx_plotter` (implementacja referencyjna)
- **Oprogramowanie górnicze**: `pocx_miner` (implementacja referencyjna) łączy się przez RPC
- **Portfel**: `bitcoind` lub `bitcoin-qt` z kluczami prywatnymi dla adresu wydobywczego. Wydobycie w puli nie wymaga lokalnego portfela.

---

## Pierwsze kroki

### 1. Zbuduj Bitcoin-PoCX

```bash
# Klonuj z submodułami
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Zbuduj z włączonym PoCX
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Szczegóły**: Zobacz `CLAUDE.md` w katalogu głównym repozytorium

### 2. Uruchom węzeł

**Tylko węzeł**:
```bash
./build/bin/bitcoind
# lub
./build/bin/bitcoin-qt
```

**Do wydobycia** (włącza dostęp RPC dla zewnętrznych górników):
```bash
./build/bin/bitcoind -miningserver
# lub
./build/bin/bitcoin-qt -server -miningserver
```

**Szczegóły**: [Rozdział 6: Parametry sieci](6-network-parameters.md)

### 3. Wygeneruj pliki plot

Użyj `pocx_plotter` (implementacja referencyjna) do generowania plików plot w formacie PoCX.

**Szczegóły**: [Rozdział 2: Format plot](2-plot-format.md)

### 4. Skonfiguruj wydobycie

Użyj `pocx_miner` (implementacja referencyjna) do połączenia z interfejsem RPC twojego węzła.

**Szczegóły**: [Rozdział 7: Dokumentacja RPC](7-rpc-reference.md) i [Rozdział 8: Przewodnik po portfelu](8-wallet-guide.md)

---

## Atrybucja

### Format plot

Oparty na formacie POC2 (Burstcoin) z ulepszeniami:
- Naprawiona luka bezpieczeństwa (atak kompresji XOR-transpose)
- Skalowalny proof-of-work
- Układ zoptymalizowany pod SIMD
- Funkcjonalność seed

### Projekty źródłowe

- **pocx_miner**: Implementacja referencyjna oparta na [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementacja referencyjna oparta na [engraver](https://github.com/PoC-Consortium/engraver)

**Pełna atrybucja**: [Rozdział 2: Format plot](2-plot-format.md)

---

## Podsumowanie specyfikacji technicznych

- **Czas bloku**: 120 sekund (mainnet), 1 sekunda (regtest)
- **Dotacja blokowa**: 10 BTC początkowe, halving co 1050000 bloków (~4 lata)
- **Całkowita podaż**: ~21 milionów BTC (tak jak Bitcoin)
- **Tolerancja przyszłości**: 15 sekund (bloki do 15s w przyszłości akceptowane)
- **Ostrzeżenie zegara**: 10 sekund (ostrzega operatorów o dryfie czasu)
- **Opóźnienie przydziału**: 30 bloków (~1 godzina)
- **Opóźnienie cofnięcia**: 720 bloków (~24 godziny)
- **Format adresu**: Tylko P2WPKH (bech32, pocx1q...) dla operacji wydobywczych PoCX i przydziałów kucia

---

## Organizacja kodu

**Modyfikacje Bitcoin Core**: Minimalne zmiany w plikach core, oznaczone flagą funkcji `#ifdef ENABLE_POCX`

**Nowa implementacja PoCX**: Izolowana w katalogu `src/pocx/`

---

## Kwestie bezpieczeństwa

### Bezpieczeństwo czasowe

- 15-sekundowa tolerancja przyszłości zapobiega fragmentacji sieci
- 10-sekundowy próg ostrzegawczy informuje operatorów o dryfie zegara
- Kucie obronne eliminuje zachętę do manipulacji zegarem
- Time Bending redukuje wpływ wariancji czasowej

**Szczegóły**: [Rozdział 5: Bezpieczeństwo czasowe](5-timing-security.md)

### Bezpieczeństwo przydziałów

- Projekt oparty wyłącznie na OP_RETURN (brak manipulacji UTXO)
- Sygnatura transakcji dowodzi własności plotu
- Opóźnienia aktywacji zapobiegają szybkiej manipulacji stanem
- Dane cofania bezpieczne dla reorganizacji dla wszystkich zmian stanu

**Szczegóły**: [Rozdział 4: Przydziały kucia](4-forging-assignments.md)

### Bezpieczeństwo konsensusu

- Sygnatura wyłączona z hasha bloku (zapobiega plastyczności)
- Ograniczone rozmiary sygnatur (zapobiega DoS)
- Walidacja granic kompresji (zapobiega słabym dowodom)
- Dostosowanie trudności przy każdym bloku (responsywne na zmiany pojemności)

**Szczegóły**: [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md)

---

## Status sieci

**Mainnet**: Jeszcze nie uruchomiony
**Testnet**: Dostępny do testowania
**Regtest**: W pełni funkcjonalny do rozwoju

**Parametry bloku genesis**: [Rozdział 6: Parametry sieci](6-network-parameters.md)

---

## Następne kroki

**Aby zrozumieć PoCX**: Kontynuuj do [Rozdziału 2: Format plot](2-plot-format.md), aby poznać strukturę plików plot i ewolucję formatu.

**Dla konfiguracji wydobycia**: Przejdź do [Rozdziału 7: Dokumentacja RPC](7-rpc-reference.md) po szczegóły integracji.

**Dla uruchomienia węzła**: Przejrzyj [Rozdział 6: Parametry sieci](6-network-parameters.md) dla opcji konfiguracji.

---

[Spis treści](index.md) | [Dalej: Format plot →](2-plot-format.md)

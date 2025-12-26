[← Poprzedni: Przydziały kucia](4-forging-assignments.md) | [Spis treści](index.md) | [Dalej: Parametry sieci →](6-network-parameters.md)

---

# Rozdział 5: Synchronizacja czasu i bezpieczeństwo

## Przegląd

Konsensus PoCX wymaga precyzyjnej synchronizacji czasu w całej sieci. Ten rozdział dokumentuje mechanizmy bezpieczeństwa związane z czasem, tolerancję dryfu zegara oraz zachowanie kucia obronnego.

**Kluczowe mechanizmy**:
- 15-sekundowa tolerancja przyszłości dla znaczników czasu bloków
- System ostrzegania o dryfie zegara 10 sekund
- Kucie obronne (ochrona przed manipulacją zegarem)
- Integracja algorytmu Time Bending

---

## Spis treści

1. [Wymagania synchronizacji czasu](#wymagania-synchronizacji-czasu)
2. [Wykrywanie dryfu zegara i ostrzeżenia](#wykrywanie-dryfu-zegara-i-ostrzeżenia)
3. [Mechanizm kucia obronnego](#mechanizm-kucia-obronnego)
4. [Analiza zagrożeń bezpieczeństwa](#analiza-zagrożeń-bezpieczeństwa)
5. [Najlepsze praktyki dla operatorów węzłów](#najlepsze-praktyki-dla-operatorów-węzłów)

---

## Wymagania synchronizacji czasu

### Stałe i parametry

**Konfiguracja Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekund

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekund
```

### Sprawdzenia walidacji

**Walidacja znacznika czasu bloku** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Sprawdzenie monotoniczne: znacznik czasu >= znacznik czasu poprzedniego bloku
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Sprawdzenie przyszłości: znacznik czasu <= teraz + 15 sekund
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Sprawdzenie deadline'u: upływający czas >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabela wpływu dryfu zegara

| Przesunięcie zegara | Może synchronizować? | Może wydobywać? | Status walidacji | Efekt konkurencyjny |
|---------------------|----------------------|-----------------|------------------|---------------------|
| -30s wolny | NIE - sprawdzenie przyszłości niepowodzenie | N/D | **MARTWY WĘZEŁ** | Nie może uczestniczyć |
| -14s wolny | TAK | TAK | Późne kucie, przechodzi walidację | Przegrywa wyścigi |
| 0s idealny | TAK | TAK | Optymalny | Optymalny |
| +14s szybki | TAK | TAK | Wczesne kucie, przechodzi walidację | Wygrywa wyścigi |
| +16s szybki | TAK | NIE - sprawdzenie przyszłości niepowodzenie | Nie może propagować bloków | Może synchronizować, nie może wydobywać |

**Kluczowy wniosek**: 15-sekundowe okno jest symetryczne dla uczestnictwa (±14.9s), ale szybkie zegary zapewniają nieuczciwą przewagę konkurencyjną w granicach tolerancji.

### Integracja Time Bending

Algorytm Time Bending (szczegółowo opisany w [Rozdziale 3](3-consensus-and-mining.md#obliczenie-time-bending)) transformuje surowe deadline'y używając pierwiastka sześciennego:

```
time_bended_deadline = skala × (deadline_seconds)^(1/3)
```

**Interakcja z dryfem zegara**:
- Lepsze rozwiązania kują szybciej (pierwiastek sześcienny wzmacnia różnice jakości)
- Dryf zegara wpływa na czas kucia względem sieci
- Kucie obronne zapewnia konkurencję opartą na jakości pomimo wariancji czasowej

---

## Wykrywanie dryfu zegara i ostrzeżenia

### System ostrzegawczy

Bitcoin-PoCX monitoruje przesunięcie czasu między lokalnym węzłem a peerami sieci.

**Komunikat ostrzegawczy** (gdy dryf przekracza 10 sekund):
> "Data i godzina twojego komputera wydają się być zsynchronizowane z siecią z dokładnością gorszą niż 10 sekund, co może prowadzić do niepowodzenia konsensusu PoCX. Sprawdź zegar systemowy."

**Implementacja**: `src/node/timeoffsets.cpp`

### Uzasadnienie projektowe

**Dlaczego 10 sekund?**
- Zapewnia 5-sekundowy bufor bezpieczeństwa przed limitem tolerancji 15 sekund
- Bardziej restrykcyjne niż domyślne Bitcoin Core (10 minut)
- Odpowiednie dla wymagań czasowych PoC

**Podejście prewencyjne**:
- Wczesne ostrzeżenie przed krytyczną awarią
- Pozwala operatorom proaktywnie naprawiać problemy
- Zmniejsza fragmentację sieci z powodu awarii związanych z czasem

---

## Mechanizm kucia obronnego

### Czym jest

Kucie obronne to standardowe zachowanie górnika w Bitcoin-PoCX, które eliminuje przewagi oparte na czasie w produkcji bloków. Gdy twój górnik otrzymuje konkurencyjny blok na tej samej wysokości, automatycznie sprawdza, czy masz lepsze rozwiązanie. Jeśli tak, natychmiast kuje twój blok, zapewniając konkurencję opartą na jakości, a nie na manipulacji zegarem.

### Problem

Konsensus PoCX pozwala na bloki ze znacznikami czasu do 15 sekund w przyszłości. Ta tolerancja jest niezbędna dla globalnej synchronizacji sieci. Jednakże tworzy to możliwość manipulacji zegarem:

**Bez kucia obronnego:**
- Górnik A: Poprawny czas, jakość 800 (lepsza), czeka na właściwy deadline
- Górnik B: Szybki zegar (+14s), jakość 1000 (gorsza), kuje 14 sekund wcześniej
- Wynik: Górnik B wygrywa wyścig pomimo gorszego dowodu proof-of-capacity

**Problem:** Manipulacja zegarem zapewnia przewagę nawet przy gorszej jakości, podważając zasadę proof-of-capacity.

### Rozwiązanie: Obrona dwuwarstwowa

#### Warstwa 1: Ostrzeżenie o dryfie zegara (prewencyjna)

Bitcoin-PoCX monitoruje przesunięcie czasu między twoim węzłem a peerami sieci. Jeśli twój zegar odchodzi więcej niż 10 sekund od konsensusu sieci, otrzymujesz ostrzeżenie informujące o konieczności naprawienia problemów z zegarem, zanim spowodują problemy.

#### Warstwa 2: Kucie obronne (reaktywna)

Gdy inny górnik publikuje blok na tej samej wysokości, którą wydobywasz:

1. **Wykrycie**: Twój węzeł identyfikuje konkurencję na tej samej wysokości
2. **Walidacja**: Wyodrębnia i waliduje jakość konkurencyjnego bloku
3. **Porównanie**: Sprawdza, czy twoja jakość jest lepsza
4. **Reakcja**: Jeśli lepsza, kuje twój blok natychmiast

**Wynik:** Sieć otrzymuje oba bloki i wybiera ten z lepszą jakością poprzez standardowe rozwiązywanie forków.

### Jak to działa

#### Scenariusz: Konkurencja na tej samej wysokości

```
Czas 150s: Górnik B (zegar +10s) kuje z jakością 1000
           → Znacznik czasu bloku pokazuje 160s (10s w przyszłości)

Czas 150s: Twój węzeł otrzymuje blok Górnika B
           → Wykrywa: ta sama wysokość, jakość 1000
           → Masz: jakość 800 (lepsza!)
           → Akcja: Kuj natychmiast z poprawnym znacznikiem czasu (150s)

Czas 152s: Sieć waliduje oba bloki
           → Oba prawidłowe (w granicach tolerancji 15s)
           → Jakość 800 wygrywa (niższa = lepsza)
           → Twój blok staje się końcówką łańcucha
```

#### Scenariusz: Prawdziwy reorg

```
Twoja wysokość wydobycia 100, konkurent publikuje blok 99
→ Nie jest to konkurencja na tej samej wysokości
→ Kucie obronne NIE wyzwala się
→ Normalna obsługa reorgu kontynuuje
```

### Korzyści

**Zero zachęty do manipulacji zegarem**
- Szybkie zegary pomagają tylko jeśli już masz najlepszą jakość
- Manipulacja zegarem staje się ekonomicznie bezcelowa

**Wymuszana konkurencja oparta na jakości**
- Zmusza górników do konkurowania na faktycznej pracy proof-of-capacity
- Zachowuje integralność konsensusu PoCX

**Bezpieczeństwo sieci**
- Odporne na strategie gier czasowych
- Nie wymaga zmian konsensusu — czysto zachowanie górnika

**W pełni automatyczne**
- Nie wymaga konfiguracji
- Wyzwala się tylko gdy konieczne
- Standardowe zachowanie we wszystkich węzłach Bitcoin-PoCX

### Kompromisy

**Minimalny wzrost współczynnika osieroceń**
- Zamierzony — bloki ataku zostają osierocone
- Występuje tylko podczas faktycznych prób manipulacji zegarem
- Naturalny rezultat rozwiązywania forków opartego na jakości

**Krótka konkurencja sieciowa**
- Sieć krótko widzi dwa konkurujące bloki
- Rozwiązuje się w sekundach poprzez standardową walidację
- To samo zachowanie jak jednoczesne wydobycie w Bitcoinie

### Szczegóły techniczne

**Wpływ na wydajność:** Zaniedbywalny
- Wyzwalane tylko przy konkurencji na tej samej wysokości
- Używa danych w pamięci (brak I/O dysku)
- Walidacja kończy się w milisekundach

**Użycie zasobów:** Minimalne
- ~20 linii podstawowej logiki
- Wykorzystuje istniejącą infrastrukturę walidacji
- Pojedyncze pozyskanie blokady

**Kompatybilność:** Pełna
- Brak zmian reguł konsensusu
- Działa ze wszystkimi funkcjami Bitcoin Core
- Opcjonalne monitorowanie przez logi debugowania

**Status**: Aktywny we wszystkich wydaniach Bitcoin-PoCX
**Pierwsze wprowadzenie**: 10.10.2025

---

## Analiza zagrożeń bezpieczeństwa

### Atak szybkim zegarem (zmitygowany przez kucie obronne)

**Wektor ataku**:
Górnik z zegarem **+14s do przodu** może:
1. Otrzymywać bloki normalnie (wyglądają dla niego jako stare)
2. Kuć bloki natychmiast gdy minie deadline
3. Rozgłaszać bloki, które wyglądają jako 14s "za wcześnie" dla sieci
4. **Bloki są akceptowane** (w granicach tolerancji 15s)
5. **Wygrywa wyścigi** przeciwko uczciwym górnikom

**Wpływ bez kucia obronnego**:
Przewaga jest ograniczona do 14.9 sekund (nie wystarcza do pominięcia znaczącej pracy PoC), ale zapewnia stałą przewagę w wyścigach bloków.

**Mitygacja (kucie obronne)**:
- Uczciwi górnicy wykrywają konkurencję na tej samej wysokości
- Porównują wartości jakości
- Natychmiast kują jeśli jakość jest lepsza
- **Wynik**: Szybki zegar pomaga tylko jeśli już masz najlepszą jakość
- **Zachęta**: Zero — manipulacja zegarem staje się ekonomicznie bezcelowa

### Awaria wolnego zegara (krytyczna)

**Tryb awarii**:
Węzeł **>15s za** jest katastrofalny:
- Nie może walidować przychodzących bloków (sprawdzenie przyszłości zawodzi)
- Staje się izolowany od sieci
- Nie może wydobywać ani synchronizować

**Mitygacja**:
- Silne ostrzeżenie przy dryfie 10s daje 5-sekundowy bufor przed krytyczną awarią
- Operatorzy mogą proaktywnie naprawiać problemy z zegarem
- Jasne komunikaty błędów kierują rozwiązywaniem problemów

---

## Najlepsze praktyki dla operatorów węzłów

### Konfiguracja synchronizacji czasu

**Zalecana konfiguracja**:
1. **Włącz NTP**: Użyj Network Time Protocol do automatycznej synchronizacji
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Sprawdź status
   timedatectl status
   ```

2. **Zweryfikuj dokładność zegara**: Regularnie sprawdzaj przesunięcie czasu
   ```bash
   # Sprawdź status synchronizacji NTP
   ntpq -p

   # Lub z chrony
   chronyc tracking
   ```

3. **Monitoruj ostrzeżenia**: Obserwuj ostrzeżenia o dryfie zegara Bitcoin-PoCX w logach

### Dla górników

**Nie wymagane żadne działania**:
- Funkcja jest zawsze aktywna
- Działa automatycznie
- Po prostu utrzymuj dokładny zegar systemowy

**Najlepsze praktyki**:
- Używaj synchronizacji czasu NTP
- Monitoruj ostrzeżenia o dryfie zegara
- Natychmiast reaguj na pojawiające się ostrzeżenia

**Oczekiwane zachowanie**:
- Wydobycie solo: Kucie obronne rzadko się wyzwala (brak konkurencji)
- Wydobycie sieciowe: Chroni przed próbami manipulacji zegarem
- Przejrzyste działanie: Większość górników nigdy tego nie zauważy

### Rozwiązywanie problemów

**Ostrzeżenie: "ponad 10 sekund rozsynchronizowany"**
- Akcja: Sprawdź i napraw synchronizację zegara systemowego
- Wpływ: 5-sekundowy bufor przed krytyczną awarią
- Narzędzia: NTP, chrony, systemd-timesyncd

**Błąd: "time-too-new" na przychodzących blokach**
- Przyczyna: Twój zegar jest >15 sekund wolny
- Wpływ: Nie może walidować bloków, węzeł izolowany
- Naprawa: Natychmiast zsynchronizuj zegar systemowy

**Błąd: Nie można propagować wykutych bloków**
- Przyczyna: Twój zegar jest >15 sekund szybki
- Wpływ: Bloki odrzucane przez sieć
- Naprawa: Natychmiast zsynchronizuj zegar systemowy

---

## Decyzje projektowe i uzasadnienie

### Dlaczego 15-sekundowa tolerancja?

**Uzasadnienie**:
- Zmienne czasy deadline'u Bitcoin-PoCX są mniej krytyczne czasowo niż konsensus o stałym czasie
- 15s zapewnia adekwatną ochronę przy jednoczesnym zapobieganiu fragmentacji sieci

**Kompromisy**:
- Ściślejsza tolerancja = większa fragmentacja sieci z powodu drobnego dryfu
- Luźniejsza tolerancja = więcej możliwości ataków czasowych
- 15s balansuje bezpieczeństwo i solidność

### Dlaczego 10-sekundowe ostrzeżenie?

**Uzasadnienie**:
- Zapewnia 5-sekundowy bufor bezpieczeństwa
- Bardziej odpowiednie dla PoC niż domyślne 10 minut Bitcoina
- Pozwala na proaktywne naprawy przed krytyczną awarią

### Dlaczego kucie obronne?

**Rozwiązywany problem**:
- 15-sekundowa tolerancja umożliwia przewagę szybkiego zegara
- Konsensus oparty na jakości mógłby być podważony przez manipulację czasem

**Korzyści rozwiązania**:
- Obrona bezkosztowa (brak zmian konsensusu)
- Automatyczne działanie
- Eliminuje zachętę do ataku
- Zachowuje zasady proof-of-capacity

### Dlaczego brak synchronizacji czasu wewnątrz sieci?

**Uzasadnienie bezpieczeństwa**:
- Nowoczesny Bitcoin Core usunął dostosowanie czasu oparte na peerach
- Podatne na ataki Sybil na postrzegany czas sieci
- PoCX celowo unika polegania na wewnętrznych źródłach czasu sieci
- Zegar systemowy jest bardziej godny zaufania niż konsensus peerów
- Operatorzy powinni synchronizować używając NTP lub równoważnego zewnętrznego źródła czasu
- Węzły monitorują własny dryf i emitują ostrzeżenia jeśli lokalny zegar odbiega od ostatnich znaczników czasu bloków

---

## Odniesienia do implementacji

**Główne pliki**:
- Walidacja czasu: `src/validation.cpp:4547-4561`
- Stała tolerancji przyszłości: `src/chain.h:31`
- Próg ostrzegawczy: `src/node/timeoffsets.h:27`
- Monitorowanie przesunięcia czasu: `src/node/timeoffsets.cpp`
- Kucie obronne: `src/pocx/mining/scheduler.cpp`

**Powiązana dokumentacja**:
- Algorytm Time Bending: [Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md#obliczenie-time-bending)
- Walidacja bloku: [Rozdział 3: Walidacja bloku](3-consensus-and-mining.md#walidacja-bloku)

---

**Wygenerowano**: 10.10.2025
**Status**: Kompletna implementacja
**Zakres**: Wymagania synchronizacji czasu, obsługa dryfu zegara, kucie obronne

---

[← Poprzedni: Przydziały kucia](4-forging-assignments.md) | [Spis treści](index.md) | [Dalej: Parametry sieci →](6-network-parameters.md)

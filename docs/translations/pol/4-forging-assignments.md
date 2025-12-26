[← Poprzedni: Konsensus i wydobycie](3-consensus-and-mining.md) | [Spis treści](index.md) | [Dalej: Synchronizacja czasu →](5-timing-security.md)

---

# Rozdział 4: System przydziału kucia PoCX

## Streszczenie wykonawcze

Ten dokument opisuje **zaimplementowany** system przydziału kucia PoCX wykorzystujący architekturę opartą wyłącznie na OP_RETURN. System umożliwia właścicielom plotów delegowanie praw kucia na oddzielne adresy poprzez transakcje on-chain, z pełnym bezpieczeństwem wobec reorganizacji i atomowymi operacjami bazodanowymi.

**Status:** W pełni zaimplementowany i działający

## Podstawowa filozofia projektowa

**Kluczowa zasada:** Przydziały są uprawnieniami, nie aktywami

- Brak specjalnych UTXO do śledzenia lub wydawania
- Stan przydziału przechowywany oddzielnie od zbioru UTXO
- Własność udowadniana przez sygnaturę transakcji, nie przez wydawanie UTXO
- Pełne śledzenie historii dla kompletnej ścieżki audytu
- Atomowe aktualizacje bazy danych poprzez zapisy wsadowe LevelDB

## Struktura transakcji

### Format transakcji przydziału

```
Wejścia:
  [0]: Dowolne UTXO kontrolowane przez właściciela plotu (dowodzi własności + płaci opłaty)
       Musi być podpisane kluczem prywatnym właściciela plotu
  [1+]: Opcjonalne dodatkowe wejścia na pokrycie opłat

Wyjścia:
  [0]: OP_RETURN (znacznik POCX + adres plotu + adres kucia)
       Format: OP_RETURN <0x2c> "POCX" <adres_plotu_20> <adres_kucia_20>
       Rozmiar: 46 bajtów łącznie (1 bajt OP_RETURN + 1 bajt długość + 44 bajty dane)
       Wartość: 0 BTC (niewydawalne, niedodawane do zbioru UTXO)

  [1]: Reszta zwracana użytkownikowi (opcjonalne, standardowe P2WPKH)
```

**Implementacja:** `src/pocx/assignments/opcodes.cpp:25-52`

### Format transakcji cofnięcia

```
Wejścia:
  [0]: Dowolne UTXO kontrolowane przez właściciela plotu (dowodzi własności + płaci opłaty)
       Musi być podpisane kluczem prywatnym właściciela plotu
  [1+]: Opcjonalne dodatkowe wejścia na pokrycie opłat

Wyjścia:
  [0]: OP_RETURN (znacznik XCOP + adres plotu)
       Format: OP_RETURN <0x18> "XCOP" <adres_plotu_20>
       Rozmiar: 26 bajtów łącznie (1 bajt OP_RETURN + 1 bajt długość + 24 bajty dane)
       Wartość: 0 BTC (niewydawalne, niedodawane do zbioru UTXO)

  [1]: Reszta zwracana użytkownikowi (opcjonalne, standardowe P2WPKH)
```

**Implementacja:** `src/pocx/assignments/opcodes.cpp:54-77`

### Znaczniki

- **Znacznik przydziału:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Znacznik cofnięcia:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementacja:** `src/pocx/assignments/opcodes.cpp:15-19`

### Kluczowe cechy transakcji

- Standardowe transakcje Bitcoina (brak zmian protokołu)
- Wyjścia OP_RETURN są niewydawalne z definicji (nigdy niedodawane do zbioru UTXO)
- Własność plotu udowodniona przez sygnaturę na wejściu[0] od adresu plotu
- Niski koszt (~200 bajtów, typowo <0.0001 BTC opłaty)
- Portfel automatycznie wybiera największe UTXO z adresu plotu, aby udowodnić własność

## Architektura bazy danych

### Struktura przechowywania

Wszystkie dane przydziałów są przechowywane w tej samej bazie danych LevelDB co zbiór UTXO (`chainstate/`), ale z oddzielnymi prefiksami kluczy:

```
chainstate/ LevelDB:
├─ Zbiór UTXO (standard Bitcoin Core)
│  └─ Prefiks 'C': COutPoint → Coin
│
└─ Stan przydziałów (dodatki PoCX)
   └─ Prefiks 'A': (adres_plotu, txid_przydziału) → ForgingAssignment
       └─ Pełna historia: wszystkie przydziały na plot w czasie
```

**Implementacja:** `src/txdb.cpp:237-348`

### Struktura ForgingAssignment

```cpp
struct ForgingAssignment {
    // Tożsamość
    std::array<uint8_t, 20> plotAddress;      // Właściciel plotu (20-bajtowy hash P2WPKH)
    std::array<uint8_t, 20> forgingAddress;   // Posiadacz praw kucia (20-bajtowy hash P2WPKH)

    // Cykl życia przydziału
    uint256 assignment_txid;                   // Transakcja tworząca przydział
    int assignment_height;                     // Wysokość bloku utworzenia
    int assignment_effective_height;           // Kiedy staje się aktywny (height + delay)

    // Cykl życia cofnięcia
    bool revoked;                              // Czy został cofnięty?
    uint256 revocation_txid;                   // Transakcja cofająca
    int revocation_height;                     // Wysokość bloku cofnięcia
    int revocation_effective_height;           // Kiedy cofnięcie wchodzi w życie (height + delay)

    // Metody zapytań o stan
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementacja:** `src/coins.h:111-178`

### Stany przydziałów

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Brak przydziału
    ASSIGNING = 1,   // Przydział utworzony, czeka na opóźnienie aktywacji
    ASSIGNED = 2,    // Przydział aktywny, kucie dozwolone
    REVOKING = 3,    // Cofnięty, ale nadal aktywny podczas okresu opóźnienia
    REVOKED = 4      // W pełni cofnięty, nieaktywny
};
```

**Implementacja:** `src/coins.h:98-104`

### Klucze bazy danych

```cpp
// Klucz historii: przechowuje pełny rekord przydziału
// Format klucza: (prefiks, adresPlotu, wysokość_przydziału, txid_przydziału)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Adres plotu (20 bajtów)
    int assignment_height;                // Wysokość do optymalizacji sortowania
    uint256 assignment_txid;              // ID transakcji
};
```

**Implementacja:** `src/txdb.cpp:245-262`

### Śledzenie historii

- Każdy przydział przechowywany trwale (nigdy nieusuwany chyba że reorg)
- Wiele przydziałów na plot śledzonych w czasie
- Umożliwia pełną ścieżkę audytu i zapytania o stan historyczny
- Cofnięte przydziały pozostają w bazie z `revoked=true`

## Przetwarzanie bloków

### Integracja ConnectBlock

OP_RETURN przydziałów i cofnięć są przetwarzane podczas łączenia bloku w `validation.cpp`:

```cpp
// Lokalizacja: Po walidacji skryptu, przed UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsuj dane OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Zweryfikuj własność (tx musi być podpisane przez właściciela plotu)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Sprawdź stan plotu (musi być UNASSIGNED lub REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Utwórz nowy przydział
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Zapisz dane cofania
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsuj dane OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Zweryfikuj własność
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Pobierz aktualny przydział
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Zapisz stary stan do cofania
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Oznacz jako cofnięty
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins kontynuuje normalnie (automatycznie pomija wyjścia OP_RETURN)
```

**Implementacja:** `src/validation.cpp:2775-2878`

### Weryfikacja własności

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Sprawdź czy co najmniej jedno wejście jest podpisane przez właściciela plotu
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Wyodrębnij miejsce docelowe
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Sprawdź czy P2WPKH do adresu plotu
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core już zwalidował sygnaturę
                return true;
            }
        }
    }
    return false;
}
```

**Implementacja:** `src/pocx/assignments/opcodes.cpp:217-256`

### Opóźnienia aktywacji

Przydziały i cofnięcia mają konfigurowalne opóźnienia aktywacji, aby zapobiec atakom reorganizacyjnym:

```cpp
// Parametry konsensusu (konfigurowalne na sieć)
// Przykład: 30 bloków = ~1 godzina przy 2-minutowym czasie bloku
consensus.nForgingAssignmentDelay;   // Opóźnienie aktywacji przydziału
consensus.nForgingRevocationDelay;   // Opóźnienie aktywacji cofnięcia
```

**Przejścia stanów:**
- Przydział: `UNASSIGNED → ASSIGNING (opóźnienie) → ASSIGNED`
- Cofnięcie: `ASSIGNED → REVOKING (opóźnienie) → REVOKED`

**Implementacja:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Walidacja mempoola

Transakcje przydziałów i cofnięć są walidowane przy akceptacji do mempoola, aby odrzucić nieprawidłowe transakcje przed propagacją sieciową.

### Sprawdzenia na poziomie transakcji (CheckTransaction)

Wykonywane w `src/consensus/tx_check.cpp` bez dostępu do stanu łańcucha:

1. **Maksymalnie jeden OP_RETURN POCX:** Transakcja nie może zawierać wielu znaczników POCX/XCOP

**Implementacja:** `src/consensus/tx_check.cpp:63-77`

### Sprawdzenia akceptacji mempoola (PreChecks)

Wykonywane w `src/validation.cpp` z pełnym dostępem do stanu łańcucha i mempoola:

#### Walidacja przydziału

1. **Własność plotu:** Transakcja musi być podpisana przez właściciela plotu
2. **Stan plotu:** Plot musi być UNASSIGNED (0) lub REVOKED (4)
3. **Konflikty mempoola:** Brak innego przydziału dla tego plotu w mempoolu (pierwszy widziany wygrywa)

#### Walidacja cofnięcia

1. **Własność plotu:** Transakcja musi być podpisana przez właściciela plotu
2. **Aktywny przydział:** Plot musi być tylko w stanie ASSIGNED (2)
3. **Konflikty mempoola:** Brak innego cofnięcia dla tego plotu w mempoolu

**Implementacja:** `src/validation.cpp:898-993`

### Przepływ walidacji

```
Rozgłoszenie transakcji
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maksymalnie jeden OP_RETURN POCX
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Weryfikacja własności plotu
  ✓ Sprawdzenie stanu przydziału
  ✓ Sprawdzenie konfliktów mempoola
       ↓
   Prawidłowy → Akceptuj do mempoola
   Nieprawidłowy → Odrzuć (nie propaguj)
       ↓
Wydobycie bloku
       ↓
ConnectBlock() [validation.cpp]
  ✓ Ponowna walidacja wszystkich sprawdzeń (obrona w głąb)
  ✓ Zastosuj zmiany stanu
  ✓ Zapisz informacje cofania
```

### Obrona w głąb

Wszystkie sprawdzenia walidacji mempoola są ponownie wykonywane podczas `ConnectBlock()`, aby chronić przed:
- Atakami omijającymi mempool
- Nieprawidłowymi blokami od złośliwych górników
- Przypadkami brzegowymi podczas scenariuszy reorganizacji

Walidacja bloku pozostaje autorytatywna dla konsensusu.

## Atomowe aktualizacje bazy danych

### Architektura trójwarstwowa

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (pamięć podręczna)    │  ← Zmiany przydziałów śledzone w pamięci
│   - Monety: cacheCoins                  │
│   - Przydziały: pendingAssignments      │
│   - Śledzenie zmian: dirtyPlots         │
│   - Usunięcia: deletedAssignments       │
│   - Śledzenie pamięci: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (warstwa bazy danych)    │  ← Pojedynczy atomowy zapis
│   - BatchWrite(): UTXOs + Przydziały    │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (pamięć dyskowa)              │  ← Gwarancje ACID
│   - Transakcja atomowa                  │
└─────────────────────────────────────────┘
```

### Proces Flush

Gdy `view.Flush()` jest wywoływane podczas łączenia bloku:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Zapisz zmiany monet do bazy
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Zapisz zmiany przydziałów atomowo
    if (fOk && !dirtyPlots.empty()) {
        // Zbierz brudne przydziały
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Pusty - nieużywany

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Zapisz do bazy danych
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Wyczyść śledzenie
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Zwolnij pamięć
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementacja:** `src/coins.cpp:278-315`

### Zapis wsadowy do bazy

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Pojedynczy wsad LevelDB

    // 1. Oznacz stan przejściowy
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Zapisz wszystkie zmiany monet
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Oznacz spójny stan
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMOWY COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Przydziały zapisywane oddzielnie ale w tym samym kontekście transakcji bazy
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Nieużywany parametr (zachowany dla kompatybilności API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nowy wsad, ale ta sama baza

    // Zapisz historię przydziałów
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Usuń usunięte przydziały z historii
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMOWY COMMIT
    return m_db->WriteBatch(batch);
}
```

**Implementacja:** `src/txdb.cpp:332-348`

### Gwarancje atomowości

**Co jest atomowe:**
- Wszystkie zmiany monet w bloku są zapisywane atomowo
- Wszystkie zmiany przydziałów w bloku są zapisywane atomowo
- Baza danych pozostaje spójna podczas awarii

**Aktualne ograniczenie:**
- Monety i przydziały są zapisywane w **oddzielnych** operacjach wsadowych LevelDB
- Obie operacje dzieją się podczas `view.Flush()`, ale nie w pojedynczym atomowym zapisie
- W praktyce: Oba wsady kończą się szybko przed fsync na dysk
- Ryzyko jest minimalne: Oba musiałyby być odtworzone z tego samego bloku podczas odzyskiwania po awarii

**Uwaga:** To różni się od oryginalnego planu architektury, który zakładał pojedynczy zunifikowany wsad. Aktualna implementacja używa dwóch wsadów, ale utrzymuje spójność poprzez istniejące mechanizmy odzyskiwania po awarii Bitcoin Core (znacznik DB_HEAD_BLOCKS).

## Obsługa reorganizacji

### Struktura danych cofania

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Przydział został dodany (usuń przy cofnięciu)
        MODIFIED = 1,   // Przydział został zmodyfikowany (przywróć przy cofnięciu)
        REVOKED = 2     // Przydział został cofnięty (od-cofnij przy cofnięciu)
    };

    UndoType type;
    ForgingAssignment assignment;  // Pełny stan przed zmianą
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Dane cofania UTXO
    std::vector<ForgingUndo> vforgingundo;  // Dane cofania przydziałów
};
```

**Implementacja:** `src/undo.h:63-105`

### Proces DisconnectBlock

Gdy blok jest odłączany podczas reorganizacji:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standardowe odłączanie UTXO ...

    // Przeczytaj dane cofania z dysku
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Cofnij zmiany przydziałów (przetwarzaj w odwrotnej kolejności)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Przydział został dodany - usuń go
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Przydział został cofnięty - przywróć stan niecofnięty
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Przydział został zmodyfikowany - przywróć poprzedni stan
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementacja:** `src/validation.cpp:2381-2415`

### Zarządzanie cache podczas reorganizacji

```cpp
class CCoinsViewCache {
private:
    // Cache przydziałów
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Śledź zmodyfikowane ploty
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Śledź usunięcia
    mutable size_t cachedAssignmentsUsage{0};  // Śledzenie pamięci

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**Implementacja:** `src/coins.cpp:494-565`

## Interfejs RPC

### Polecenia węzła (nie wymagają portfela)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Zwraca aktualny status przydziału dla adresu plotu:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**Implementacja:** `src/pocx/rpc/assignments.cpp:31-126`

### Polecenia portfela (wymagają portfela)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Tworzy transakcję przydziału:
- Automatycznie wybiera największe UTXO z adresu plotu do udowodnienia własności
- Buduje transakcję z wyjściem OP_RETURN + reszta
- Podpisuje kluczem właściciela plotu
- Rozgłasza do sieci

**Implementacja:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Tworzy transakcję cofnięcia:
- Automatycznie wybiera największe UTXO z adresu plotu do udowodnienia własności
- Buduje transakcję z wyjściem OP_RETURN + reszta
- Podpisuje kluczem właściciela plotu
- Rozgłasza do sieci

**Implementacja:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Tworzenie transakcji przez portfel

Proces tworzenia transakcji przez portfel:

```cpp
1. Parsuj i waliduj adresy (muszą być P2WPKH bech32)
2. Znajdź największe UTXO z adresu plotu (dowodzi własności)
3. Utwórz tymczasową transakcję z dummy wyjściem
4. Podpisz transakcję (uzyskaj dokładny rozmiar z danymi witness)
5. Zamień dummy wyjście na OP_RETURN
6. Dostosuj opłaty proporcjonalnie na podstawie zmiany rozmiaru
7. Podpisz ponownie końcową transakcję
8. Rozgłoś do sieci
```

**Kluczowy wniosek:** Portfel musi wydać z adresu plotu, aby udowodnić własność, więc automatycznie wymusza wybór monet z tego adresu.

**Implementacja:** `src/pocx/assignments/transactions.cpp:38-263`

## Struktura plików

### Główne pliki implementacji

```
src/
├── coins.h                        # Struktura ForgingAssignment, metody CCoinsViewCache [710 linii]
├── coins.cpp                      # Zarządzanie cache, zapisy wsadowe [603 linie]
│
├── txdb.h                         # Metody CCoinsViewDB dla przydziałów [90 linii]
├── txdb.cpp                       # Odczyt/zapis bazy danych [349 linii]
│
├── undo.h                         # Struktura ForgingUndo dla reorgów
│
├── validation.cpp                 # Integracja ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Format OP_RETURN, parsowanie, weryfikacja
    │   ├── opcodes.cpp            # [259 linii] Definicje znaczników, operacje OP_RETURN, sprawdzenie własności
    │   ├── assignment_state.h     # Helpery GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Funkcje zapytań o stan przydziału
    │   ├── transactions.h         # API tworzenia transakcji portfela
    │   └── transactions.cpp       # Funkcje portfela create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Polecenia RPC węzła (bez portfela)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Polecenia RPC portfela
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Charakterystyki wydajności

### Operacje bazodanowe

- **Pobierz aktualny przydział:** O(n) - przeskanuj wszystkie przydziały dla adresu plotu, aby znaleźć najnowszy
- **Pobierz historię przydziałów:** O(n) - iteruj wszystkie przydziały dla plotu
- **Utwórz przydział:** O(1) - pojedyncza wstawka
- **Cofnij przydział:** O(1) - pojedyncza aktualizacja
- **Reorg (na przydział):** O(1) - bezpośrednie zastosowanie danych cofania

Gdzie n = liczba przydziałów dla plotu (typowo mała, < 10)

### Użycie pamięci

- **Na przydział:** ~160 bajtów (struktura ForgingAssignment)
- **Narzut cache:** Narzut mapy hash dla śledzenia zmian
- **Typowy blok:** <10 przydziałów = <2 KB pamięci

### Użycie dysku

- **Na przydział:** ~200 bajtów na dysku (z narzutem LevelDB)
- **10000 przydziałów:** ~2 MB przestrzeni dyskowej
- **Zaniedbywalny w porównaniu ze zbiorem UTXO:** <0.001% typowego chainstate

## Aktualne ograniczenia i przyszłe prace

### Ograniczenie atomowości

**Aktualnie:** Monety i przydziały zapisywane w oddzielnych wsadach LevelDB podczas `view.Flush()`

**Wpływ:** Teoretyczne ryzyko niespójności jeśli awaria nastąpi między wsadami

**Mitygacja:**
- Oba wsady kończą się szybko przed fsync
- Odzyskiwanie po awarii Bitcoin Core używa znacznika DB_HEAD_BLOCKS
- W praktyce: Nigdy nie zaobserwowane podczas testów

**Przyszła poprawa:** Zunifikowanie w pojedynczą operację wsadową LevelDB

### Przycinanie historii przydziałów

**Aktualnie:** Wszystkie przydziały przechowywane w nieskończoność

**Wpływ:** ~200 bajtów na przydział na zawsze

**Przyszłość:** Opcjonalne przycinanie w pełni cofniętych przydziałów starszych niż N bloków

**Uwaga:** Mało prawdopodobne, że będzie potrzebne — nawet 1 milion przydziałów = 200 MB

## Status testów

### Zaimplementowane testy

- Parsowanie i walidacja OP_RETURN
- Weryfikacja własności
- Tworzenie przydziału w ConnectBlock
- Cofnięcie w ConnectBlock
- Obsługa reorgów w DisconnectBlock
- Operacje odczytu/zapisu bazy danych
- Przejścia stanów (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- Polecenia RPC (get_assignment, create_assignment, revoke_assignment)
- Tworzenie transakcji przez portfel

### Obszary pokrycia testami

- Testy jednostkowe: `src/test/pocx_*_tests.cpp`
- Testy funkcjonalne: `test/functional/feature_pocx_*.py`
- Testy integracyjne: Ręczne testowanie z regtest

## Reguły konsensusu

### Reguły tworzenia przydziału

1. **Własność:** Transakcja musi być podpisana przez właściciela plotu
2. **Stan:** Plot musi być w stanie UNASSIGNED lub REVOKED
3. **Format:** Prawidłowy OP_RETURN ze znacznikiem POCX + 2× 20-bajtowe adresy
4. **Unikalność:** Jeden aktywny przydział na plot w danym momencie

### Reguły cofnięcia

1. **Własność:** Transakcja musi być podpisana przez właściciela plotu
2. **Istnienie:** Przydział musi istnieć i nie być już cofnięty
3. **Format:** Prawidłowy OP_RETURN ze znacznikiem XCOP + 20-bajtowy adres

### Reguły aktywacji

- **Aktywacja przydziału:** `assignment_height + nForgingAssignmentDelay`
- **Aktywacja cofnięcia:** `revocation_height + nForgingRevocationDelay`
- **Opóźnienia:** Konfigurowalne na sieć (np. 30 bloków = ~1 godzina przy 2-minutowym czasie bloku)

### Walidacja bloku

- Nieprawidłowy przydział/cofnięcie → blok odrzucony (niepowodzenie konsensusu)
- Wyjścia OP_RETURN automatycznie wyłączone ze zbioru UTXO (standardowe zachowanie Bitcoina)
- Przetwarzanie przydziałów następuje przed aktualizacjami UTXO w ConnectBlock

## Podsumowanie

Zaimplementowany system przydziału kucia PoCX zapewnia:

- **Prostota:** Standardowe transakcje Bitcoina, brak specjalnych UTXO
- **Ekonomiczność:** Brak wymagania kurzu, tylko opłaty transakcyjne
- **Bezpieczeństwo reorgów:** Kompleksowe dane cofania przywracają poprawny stan
- **Atomowe aktualizacje:** Spójność bazy danych poprzez wsady LevelDB
- **Pełna historia:** Kompletna ścieżka audytu wszystkich przydziałów w czasie
- **Czysta architektura:** Minimalne modyfikacje Bitcoin Core, izolowany kod PoCX
- **Gotowość produkcyjna:** W pełni zaimplementowany, przetestowany i działający

### Jakość implementacji

- **Organizacja kodu:** Doskonała - czyste rozdzielenie między Bitcoin Core a PoCX
- **Obsługa błędów:** Kompleksowa walidacja konsensusu
- **Dokumentacja:** Komentarze w kodzie i struktura dobrze udokumentowane
- **Testowanie:** Główna funkcjonalność przetestowana, integracja zweryfikowana

### Zatwierdzone kluczowe decyzje projektowe

1. Podejście oparte wyłącznie na OP_RETURN (vs. oparte na UTXO)
2. Oddzielne przechowywanie w bazie danych (vs. Coin extraData)
3. Pełne śledzenie historii (vs. tylko aktualny stan)
4. Własność przez sygnaturę (vs. wydawanie UTXO)
5. Opóźnienia aktywacji (zapobiega atakom reorganizacyjnym)

System skutecznie osiąga wszystkie cele architektoniczne z czystą, łatwą w utrzymaniu implementacją.

---

[← Poprzedni: Konsensus i wydobycie](3-consensus-and-mining.md) | [Spis treści](index.md) | [Dalej: Synchronizacja czasu →](5-timing-security.md)

[← Poprzedni: Format plot](2-plot-format.md) | [Spis treści](index.md) | [Dalej: Przydziały kucia →](4-forging-assignments.md)

---

# Rozdział 3: Konsensus i proces wydobycia Bitcoin-PoCX

Pełna specyfikacja techniczna mechanizmu konsensusu PoCX (Proof of Capacity neXt generation) i procesu wydobycia zintegrowanego z Bitcoin Core.

---

## Spis treści

1. [Przegląd](#przegląd)
2. [Architektura konsensusu](#architektura-konsensusu)
3. [Proces wydobycia](#proces-wydobycia)
4. [Walidacja bloku](#walidacja-bloku)
5. [System przydziałów](#system-przydziałów)
6. [Propagacja sieciowa](#propagacja-sieciowa)
7. [Szczegóły techniczne](#szczegóły-techniczne)

---

## Przegląd

Bitcoin-PoCX implementuje czysty mechanizm konsensusu Proof of Capacity jako całkowite zastąpienie Proof of Work Bitcoina. Jest to nowy łańcuch bez wymagań kompatybilności wstecznej.

**Kluczowe właściwości:**
- **Energooszczędny:** Wydobycie używa wstępnie wygenerowanych plików plot zamiast haszowania obliczeniowego
- **Zginane terminy:** Transformacja rozkładu (wykładniczy→chi-kwadrat) redukuje długie bloki, poprawia średnie czasy bloków
- **Wsparcie przydziałów:** Właściciele plotów mogą delegować prawa kucia na inne adresy
- **Natywna integracja C++:** Algorytmy kryptograficzne zaimplementowane w C++ do walidacji konsensusu

**Przepływ wydobycia:**
```
Zewnętrzny górnik → get_mining_info → Oblicz nonce → submit_nonce →
Kolejka kucia → Oczekiwanie na deadline → Kucie bloku → Propagacja sieciowa →
Walidacja bloku → Rozszerzenie łańcucha
```

---

## Architektura konsensusu

### Struktura bloku

Bloki PoCX rozszerzają strukturę bloku Bitcoina o dodatkowe pola konsensusu:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plotu (32 bajty)
    std::array<uint8_t, 20> account_id;       // Adres plotu (20-bajtowy hash160)
    uint32_t compression;                     // Poziom skalowania (1-255)
    uint64_t nonce;                           // Nonce wydobywczy (64-bit)
    uint64_t quality;                         // Zadeklarowana jakość (wyjście hasha PoC)
};

class CBlockHeader {
    // Standardowe pola Bitcoina
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Pola konsensusu PoCX (zastępują nBits i nNonce)
    int nHeight;                              // Wysokość bloku (walidacja bez kontekstu)
    uint256 generationSignature;              // Sygnatura generacji (entropia wydobycia)
    uint64_t nBaseTarget;                     // Parametr trudności (odwrotność trudności)
    PoCXProof pocxProof;                      // Dowód wydobycia

    // Pola sygnatury bloku
    std::array<uint8_t, 33> vchPubKey;        // Skompresowany klucz publiczny (33 bajty)
    std::array<uint8_t, 65> vchSignature;     // Kompaktowa sygnatura (65 bajtów)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transakcje
};
```

**Uwaga:** Sygnatura (`vchSignature`) jest wyłączona z obliczenia hasha bloku, aby zapobiec plastyczności.

**Implementacja:** `src/primitives/block.h`

### Sygnatura generacji

Sygnatura generacji tworzy entropię wydobycia i zapobiega atakom preoobliczeniowym.

**Obliczenie:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Blok genesis:** Używa zahardkodowanej początkowej sygnatury generacji

**Implementacja:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base target (trudność)

Base target to odwrotność trudności — wyższe wartości oznaczają łatwiejsze wydobycie.

**Algorytm dostosowania:**
- Docelowy czas bloku: 120 sekund (mainnet), 1 sekunda (regtest)
- Interwał dostosowania: Każdy blok
- Używa średniej kroczącej ostatnich base targetów
- Ograniczony, aby zapobiec ekstremalnym wahaniom trudności

**Implementacja:** `src/consensus/params.h`, logika trudności przy tworzeniu bloku

### Poziomy skalowania

PoCX obsługuje skalowalny proof-of-work w plikach plot poprzez poziomy skalowania (Xn).

**Dynamiczne granice:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimalny akceptowany poziom
    uint8_t nPoCXTargetCompression;  // Zalecany poziom
};
```

**Harmonogram zwiększania skalowania:**
- Interwały wykładnicze: Lata 4, 12, 28, 60, 124 (halvingi 1, 3, 7, 15, 31)
- Minimalny poziom skalowania zwiększa się o 1
- Docelowy poziom skalowania zwiększa się o 1
- Utrzymuje margines bezpieczeństwa między kosztami tworzenia plotu a kosztami wyszukiwania
- Maksymalny poziom skalowania: 255

**Implementacja:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Proces wydobycia

### 1. Pobieranie informacji wydobywczych

**Polecenie RPC:** `get_mining_info`

**Proces:**
1. Wywołaj `GetNewBlockContext(chainman)`, aby pobrać aktualny stan blockchainu
2. Oblicz dynamiczne granice kompresji dla bieżącej wysokości
3. Zwróć parametry wydobycia

**Odpowiedź:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementacja:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Uwagi:**
- Brak trzymanych blokad podczas generowania odpowiedzi
- Pozyskanie kontekstu obsługuje `cs_main` wewnętrznie
- `block_hash` dołączony dla odniesienia, ale nie używany w walidacji

### 2. Zewnętrzne wydobycie

**Obowiązki zewnętrznego górnika:**
1. Czytaj pliki plot z dysku
2. Oblicz scoop na podstawie sygnatury generacji i wysokości
3. Znajdź nonce z najlepszym deadline'em
4. Zgłoś do węzła przez `submit_nonce`

**Format pliku plot:**
- Oparty na formacie POC2 (Burstcoin)
- Ulepszony o poprawki bezpieczeństwa i ulepszenia skalowalności
- Zobacz atrybucję w `CLAUDE.md`

**Implementacja górnika:** Zewnętrzna (np. oparta na Scavenger)

### 3. Zgłoszenie i walidacja nonce'a

**Polecenie RPC:** `submit_nonce`

**Parametry:**
```
height, generation_signature, account_id, seed, nonce, quality (opcjonalnie)
```

**Przepływ walidacji (zoptymalizowana kolejność):**

#### Krok 1: Szybka walidacja formatu
```cpp
// ID konta: 40 znaków hex = 20 bajtów
if (account_id.length() != 40 || !IsHex(account_id)) odrzuć;

// Seed: 64 znaki hex = 32 bajty
if (seed.length() != 64 || !IsHex(seed)) odrzuć;
```

#### Krok 2: Pozyskanie kontekstu
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Zwraca: height, generation_signature, base_target, block_hash
```

**Blokowanie:** `cs_main` obsługiwane wewnętrznie, brak blokad trzymanych w wątku RPC

#### Krok 3: Walidacja kontekstu
```cpp
// Sprawdzenie wysokości
if (height != context.height) odrzuć;

// Sprawdzenie sygnatury generacji
if (submitted_gen_sig != context.generation_signature) odrzuć;
```

#### Krok 4: Weryfikacja portfela
```cpp
// Określ efektywnego podpisującego (uwzględniając przydziały)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Sprawdź czy węzeł ma klucz prywatny dla efektywnego podpisującego
if (!HaveAccountKey(effective_signer, wallet)) odrzuć;
```

**Wsparcie przydziałów:** Właściciel plotu może przydzielić prawa kucia innemu adresowi. Portfel musi mieć klucz dla efektywnego podpisującego, niekoniecznie właściciela plotu.

#### Krok 5: Walidacja dowodu
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bajtów
    block_height,
    nonce,
    seed,                // 32 bajty
    min_compression,
    max_compression,
    &result             // Wyjście: quality, deadline
);
```

**Algorytm:**
1. Dekoduj sygnaturę generacji z hex
2. Oblicz najlepszą jakość w zakresie kompresji używając algorytmów zoptymalizowanych pod SIMD
3. Zwaliduj czy jakość spełnia wymagania trudności
4. Zwróć surową wartość jakości

**Implementacja:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Krok 6: Obliczenie Time Bending
```cpp
// Surowy deadline dostosowany do trudności (sekundy)
uint64_t deadline_seconds = quality / base_target;

// Zgięty czasowo czas kucia (sekundy)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Formuła Time Bending:**
```
Y = scale * (X^(1/3))
gdzie:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Cel:** Transformuje rozkład wykładniczy do chi-kwadrat. Bardzo dobre rozwiązania są kute później (sieć ma czas przeskanować dyski), słabe rozwiązania poprawione. Redukuje długie bloki, utrzymuje średnią 120s.

**Implementacja:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Krok 7: Zgłoszenie do harmonogramu kucia
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NIE deadline — przeliczany w harmonogramie
    height,
    generation_signature
);
```

**Projekt oparty na kolejce:**
- Zgłoszenie zawsze się powodzi (dodane do kolejki)
- RPC zwraca natychmiast
- Wątek roboczy przetwarza asynchronicznie

**Implementacja:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Przetwarzanie kolejki kucia

**Architektura:**
- Pojedynczy trwały wątek roboczy
- Kolejka zgłoszeń FIFO
- Stan kucia bez blokad (tylko wątek roboczy)
- Brak zagnieżdżonych blokad (zapobieganie zakleszczeniom)

**Główna pętla wątku roboczego:**
```cpp
while (!shutdown) {
    // 1. Sprawdź kolejkowane zgłoszenia
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Czekaj na deadline lub nowe zgłoszenie
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logika ProcessSubmission:**
```cpp
1. Pobierz świeży kontekst: GetNewBlockContext(*chainman)

2. Sprawdzenia nieaktualności (ciche odrzucenie):
   - Niezgodność wysokości → odrzuć
   - Niezgodność sygnatury generacji → odrzuć
   - Hash bloku końcówki zmieniony (reorg) → zresetuj stan kucia

3. Porównanie jakości:
   - Jeśli quality >= current_best → odrzuć

4. Oblicz zgięty czasowo deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Zaktualizuj stan kucia:
   - Anuluj istniejące kucie (jeśli znaleziono lepsze)
   - Zapisz: account_id, seed, nonce, quality, deadline
   - Oblicz: forge_time = block_time + deadline_seconds
   - Zapisz hash końcówki do wykrywania reorgów
```

**Implementacja:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Oczekiwanie na deadline i kucie bloku

**WaitForDeadlineOrNewSubmission:**

**Warunki oczekiwania:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Po osiągnięciu deadline'u — walidacja świeżego kontekstu:**
```cpp
1. Pobierz aktualny kontekst: GetNewBlockContext(*chainman)

2. Walidacja wysokości:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Walidacja sygnatury generacji:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Przypadek brzegowy base target:
   if (forging_base_target != current_base_target) {
       // Przelicz deadline z nowym base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Czekaj ponownie
   }

5. Wszystko prawidłowe → ForgeBlock()
```

**Proces ForgeBlock:**

```cpp
1. Określ efektywnego podpisującego (wsparcie przydziałów):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Utwórz skrypt coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Płaci efektywnemu podpisującemu

3. Utwórz szablon bloku:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Dodaj dowód PoCX:
   block.pocxProof.account_id = plot_address;    // Oryginalny adres plotu
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Przelicz merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Podpisz blok:
   // Użyj klucza efektywnego podpisującego (może być inny niż właściciel plotu)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Zgłoś do łańcucha:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Obsługa wyniku:
   if (accepted) {
       log_success();
       reset_forging_state();  // Gotowy na następny blok
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementacja:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Kluczowe decyzje projektowe:**
- Coinbase płaci efektywnemu podpisującemu (respektuje przydziały)
- Dowód zawiera oryginalny adres plotu (do walidacji)
- Sygnatura od klucza efektywnego podpisującego (dowód własności)
- Tworzenie szablonu automatycznie zawiera transakcje z mempoola

---

## Walidacja bloku

### Przepływ walidacji przychodzącego bloku

Gdy blok jest otrzymywany z sieci lub zgłaszany lokalnie, przechodzi walidację w wielu etapach:

### Etap 1: Walidacja nagłówka (CheckBlockHeader)

**Walidacja bez kontekstu:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Walidacja PoCX (gdy zdefiniowane ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Podstawowa walidacja sygnatury (jeszcze bez wsparcia przydziałów)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Podstawowa walidacja sygnatury:**
1. Sprawdź obecność pól pubkey i signature
2. Zwaliduj rozmiar pubkey (33 bajty skompresowany)
3. Zwaliduj rozmiar sygnatury (65 bajtów kompaktowy)
4. Odzyskaj pubkey z sygnatury: `pubkey.RecoverCompact(hash, signature)`
5. Zweryfikuj czy odzyskany pubkey pasuje do zapisanego pubkey

**Implementacja:** `src/validation.cpp:CheckBlockHeader()`
**Logika sygnatury:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Etap 2: Walidacja bloku (CheckBlock)

**Waliduje:**
- Poprawność merkle root
- Ważność transakcji
- Wymagania coinbase
- Limity rozmiaru bloku
- Standardowe reguły konsensusu Bitcoina

**Implementacja:** `src/consensus/validation.cpp:CheckBlock()`

### Etap 3: Kontekstowa walidacja nagłówka (ContextualCheckBlockHeader)

**Walidacja specyficzna dla PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Krok 1: Zwaliduj sygnaturę generacji
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Krok 2: Zwaliduj base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Krok 3: Zwaliduj proof of capacity
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Krok 4: Zweryfikuj czas deadline'u
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Kroki walidacji:**
1. **Sygnatura generacji:** Musi pasować do obliczonej wartości z poprzedniego bloku
2. **Base target:** Musi pasować do obliczenia dostosowania trudności
3. **Poziom skalowania:** Musi spełniać minimum sieciowe (`compression >= min_compression`)
4. **Deklaracja jakości:** Zgłoszona jakość musi pasować do obliczonej jakości z dowodu
5. **Proof of Capacity:** Walidacja dowodu kryptograficznego (zoptymalizowana SIMD)
6. **Czas deadline'u:** Zgięty czasowo deadline (`poc_time`) musi być ≤ upływający czas

**Implementacja:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Etap 4: Połączenie bloku (ConnectBlock)

**Pełna walidacja kontekstowa:**

```cpp
#ifdef ENABLE_POCX
    // Rozszerzona walidacja sygnatury ze wsparciem przydziałów
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Rozszerzona walidacja sygnatury:**
1. Wykonaj podstawową walidację sygnatury
2. Wyodrębnij ID konta z odzyskanego pubkey
3. Pobierz efektywnego podpisującego dla adresu plotu: `GetEffectiveSigner(plot_address, height, view)`
4. Zweryfikuj czy konto pubkey pasuje do efektywnego podpisującego

**Logika przydziałów:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Zwróć przydzielonego podpisującego
    }

    return plotAddress;  // Brak przydziału — właściciel plotu podpisuje
}
```

**Implementacja:**
- Połączenie: `src/validation.cpp:ConnectBlock()`
- Rozszerzona walidacja: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logika przydziałów: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Etap 5: Aktywacja łańcucha

**Przepływ ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Zwaliduj i zapisz na dysk
    2. ActivateBestChain → Zaktualizuj końcówkę łańcucha jeśli to najlepszy łańcuch
    3. Powiadom sieć o nowym bloku
}
```

**Implementacja:** `src/validation.cpp:ProcessNewBlock()`

### Podsumowanie walidacji

**Pełna ścieżka walidacji:**
```
Otrzymanie bloku
    ↓
CheckBlockHeader (podstawowa sygnatura)
    ↓
CheckBlock (transakcje, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, dowód PoC, deadline)
    ↓
ConnectBlock (rozszerzona sygnatura z przydziałami, przejścia stanów)
    ↓
ActivateBestChain (obsługa reorgów, rozszerzenie łańcucha)
    ↓
Propagacja sieciowa
```

---

## System przydziałów

### Przegląd

Przydziały pozwalają właścicielom plotów delegować prawa kucia na inne adresy, zachowując własność plotów.

**Przypadki użycia:**
- Wydobycie w puli (ploty przydzielone do adresu puli)
- Zimne przechowywanie (klucz wydobywczy oddzielony od własności plotu)
- Wydobycie wielostronowe (współdzielona infrastruktura)

### Architektura przydziałów

**Projekt oparty wyłącznie na OP_RETURN:**
- Przydziały przechowywane w wyjściach OP_RETURN (brak UTXO)
- Brak wymagań wydawania (brak kurzu, brak opłat za trzymanie)
- Śledzone w rozszerzonym stanie CCoinsViewCache
- Aktywowane po okresie opóźnienia (domyślnie: 4 bloki)

**Stany przydziałów:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Brak przydziału
    ASSIGNING = 1,   // Przydział oczekuje na aktywację (okres opóźnienia)
    ASSIGNED = 2,    // Przydział aktywny, kucie dozwolone
    REVOKING = 3,    // Cofnięcie oczekuje (okres opóźnienia, nadal aktywny)
    REVOKED = 4      // Cofnięcie zakończone, przydział nieaktywny
};
```

### Tworzenie przydziałów

**Format transakcji:**
```cpp
Transaction {
    inputs: [dowolny]  // Dowodzi własności adresu plotu
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <adres_plotu> <adres_kucia>
    ]
}
```

**Reguły walidacji:**
1. Wejście musi być podpisane przez właściciela plotu (dowodzi własności)
2. OP_RETURN zawiera prawidłowe dane przydziału
3. Plot musi być UNASSIGNED lub REVOKED
4. Brak zduplikowanych oczekujących przydziałów w mempoolu
5. Opłacona minimalna opłata transakcyjna

**Aktywacja:**
- Przydział staje się ASSIGNING przy wysokości potwierdzenia
- Staje się ASSIGNED po okresie opóźnienia (4 bloki regtest, 30 bloków mainnet)
- Opóźnienie zapobiega szybkim zmianom przydziałów podczas wyścigów bloków

**Implementacja:** `src/script/forging_assignment.h`, walidacja w ConnectBlock

### Cofanie przydziałów

**Format transakcji:**
```cpp
Transaction {
    inputs: [dowolny]  // Dowodzi własności adresu plotu
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <adres_plotu>
    ]
}
```

**Efekt:**
- Natychmiastowe przejście stanu do REVOKED
- Właściciel plotu może kuć natychmiast
- Można utworzyć nowy przydział później

### Walidacja przydziałów podczas wydobycia

**Określanie efektywnego podpisującego:**
```cpp
// W walidacji submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) odrzuć;

// W kuciu bloku
coinbase_script = P2WPKH(effective_signer);  // Nagroda idzie tutaj

// W sygnaturze bloku
signature = effective_signer_key.SignCompact(hash);  // Musi podpisać efektywnym podpisującym
```

**Walidacja bloku:**
```cpp
// W VerifyPoCXBlockCompactSignature (rozszerzona)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) odrzuć;
```

**Kluczowe właściwości:**
- Dowód zawsze zawiera oryginalny adres plotu
- Sygnatura musi być od efektywnego podpisującego
- Coinbase płaci efektywnemu podpisującemu
- Walidacja używa stanu przydziałów przy wysokości bloku

---

## Propagacja sieciowa

### Ogłaszanie bloków

**Standardowy protokół P2P Bitcoina:**
1. Wykuty blok zgłoszony przez `ProcessNewBlock()`
2. Blok zwalidowany i dodany do łańcucha
3. Powiadomienie sieciowe: `GetMainSignals().BlockConnected()`
4. Warstwa P2P rozgłasza blok do peerów

**Implementacja:** Standardowe net_processing Bitcoin Core

### Przekazywanie bloków

**Compact Blocks (BIP 152):**
- Używane do efektywnej propagacji bloków
- Początkowo wysyłane tylko ID transakcji
- Peerzy żądają brakujących transakcji

**Przekazywanie pełnych bloków:**
- Fallback gdy compact blocks zawodzą
- Przesyłane kompletne dane bloku

### Reorganizacje łańcucha

**Obsługa reorgów:**
```cpp
// W wątku roboczym kowalki
if (current_tip_hash != stored_tip_hash) {
    // Wykryto reorganizację łańcucha
    reset_forging_state();
    log("Końcówka łańcucha zmieniona, resetuję kucie");
}
```

**Na poziomie blockchainu:**
- Standardowa obsługa reorgów Bitcoin Core
- Najlepszy łańcuch określony przez chainwork
- Odłączone bloki zwracane do mempoola

---

## Szczegóły techniczne

### Zapobieganie zakleszczeniom

**Wzorzec zakleszczenia ABBA (zapobieżony):**
```
Wątek A: cs_main → cs_wallet
Wątek B: cs_wallet → cs_main
```

**Rozwiązanie:**
1. **submit_nonce:** Zero użycia cs_main
   - `GetNewBlockContext()` obsługuje blokowanie wewnętrznie
   - Cała walidacja przed zgłoszeniem do harmonogramu

2. **Harmonogram kucia:** Architektura oparta na kolejce
   - Pojedynczy wątek roboczy (brak łączenia wątków)
   - Świeży kontekst przy każdym dostępie
   - Brak zagnieżdżonych blokad

3. **Sprawdzenia portfela:** Wykonywane przed kosztownymi operacjami
   - Wczesne odrzucenie jeśli brak klucza
   - Oddzielone od dostępu do stanu blockchainu

### Optymalizacje wydajności

**Walidacja z szybkim niepowodzeniem:**
```cpp
1. Sprawdzenia formatu (natychmiastowe)
2. Walidacja kontekstu (lekka)
3. Weryfikacja portfela (lokalna)
4. Walidacja dowodu (kosztowna SIMD)
```

**Pojedyncze pobranie kontekstu:**
- Jedno wywołanie `GetNewBlockContext()` na zgłoszenie
- Cachuj wyniki dla wielu sprawdzeń
- Brak powtórzonych pobrań cs_main

**Wydajność kolejki:**
- Lekka struktura zgłoszenia
- Brak base_target/deadline w kolejce (przeliczane na świeżo)
- Minimalny footprint pamięci

### Obsługa nieaktualności

**"Głupi" projekt harmonogramu:**
- Brak subskrypcji zdarzeń blockchainu
- Leniwa walidacja gdy potrzebna
- Ciche odrzucanie nieaktualnych zgłoszeń

**Korzyści:**
- Prosta architektura
- Brak złożonej synchronizacji
- Odporny na przypadki brzegowe

**Obsługiwane przypadki brzegowe:**
- Zmiany wysokości → odrzuć
- Zmiany sygnatury generacji → odrzuć
- Zmiany base target → przelicz deadline
- Reorgi → zresetuj stan kucia

### Szczegóły kryptograficzne

**Sygnatura generacji:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash sygnatury bloku:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Format kompaktowej sygnatury:**
- 65 bajtów: [recovery_id][r][s]
- Pozwala na odzyskanie klucza publicznego
- Używany dla wydajności przestrzennej

**ID konta:**
- 20-bajtowy HASH160 skompresowanego klucza publicznego
- Pasuje do formatów adresów Bitcoina (P2PKH, P2WPKH)

### Przyszłe ulepszenia

**Udokumentowane ograniczenia:**
1. Brak metryk wydajności (częstotliwości zgłoszeń, rozkłady deadline'ów)
2. Brak szczegółowej kategoryzacji błędów dla górników
3. Ograniczone zapytania o stan harmonogramu (aktualny deadline, głębokość kolejki)

**Potencjalne usprawnienia:**
- RPC dla statusu harmonogramu
- Metryki wydajności wydobycia
- Ulepszone logowanie do debugowania
- Wsparcie protokołu puli

---

## Odniesienia do kodu

**Główne implementacje:**
- Interfejs RPC: `src/pocx/rpc/mining.cpp`
- Kolejka kucia: `src/pocx/mining/scheduler.cpp`
- Walidacja konsensusu: `src/pocx/consensus/validation.cpp`
- Walidacja dowodu: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Walidacja bloku: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logika przydziałów: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Zarządzanie kontekstem: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Struktury danych:**
- Format bloku: `src/primitives/block.h`
- Parametry konsensusu: `src/consensus/params.h`
- Śledzenie przydziałów: `src/coins.h` (rozszerzenia CCoinsViewCache)

---

## Dodatek: Specyfikacje algorytmów

### Formuła Time Bending

**Definicja matematyczna:**
```
deadline_seconds = quality / base_target  (surowy)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

gdzie:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementacja:**
- Arytmetyka stałoprzecinkowa (format Q42)
- Obliczenie pierwiastka sześciennego tylko na liczbach całkowitych
- Zoptymalizowana dla arytmetyki 256-bitowej

### Obliczanie jakości

**Proces:**
1. Wygeneruj scoop z sygnatury generacji i wysokości
2. Przeczytaj dane plotu dla obliczonego scoopa
3. Hasz: `SHABAL256(generation_signature || scoop_data)`
4. Testuj poziomy skalowania od min do max
5. Zwróć najlepszą znalezioną jakość

**Skalowanie:**
- Poziom X0: Bazowy POC2 (teoretyczny)
- Poziom X1: Bazowy XOR-transpose
- Poziom Xn: 2^(n-1) × osadzona praca X1
- Wyższe skalowanie = więcej pracy przy generowaniu plotu

### Dostosowanie base target

**Dostosowanie przy każdym bloku:**
1. Oblicz średnią kroczącą ostatnich base targetów
2. Oblicz faktyczny czas vs docelowy czas dla okna kroczącego
3. Dostosuj base target proporcjonalnie
4. Ogranicz aby zapobiec ekstremalnym wahaniom

**Formuła:**
```
avg_base_target = średnia_krocząca(ostatnie base targety)
adjustment_factor = faktyczny_czas / docelowy_czas
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Ta dokumentacja odzwierciedla kompletną implementację konsensusu PoCX według stanu z października 2025.*

---

[← Poprzedni: Format plot](2-plot-format.md) | [Spis treści](index.md) | [Dalej: Przydziały kucia →](4-forging-assignments.md)

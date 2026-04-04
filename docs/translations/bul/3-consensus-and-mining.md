[← Назад: Формат на Plot файловете](2-plot-format.md) | [📘 Съдържание](index.md) | [Напред: Делегиране на подписване →](4-forging-assignments.md)

---

# Глава 3: Bitcoin-PoCX консенсус и процес на копаене

Пълна техническа спецификация на консенсусния механизъм PoCX (Proof of Capacity от ново поколение) и процеса на копаене, интегрирани в Bitcoin Core.

---

## Съдържание

1. [Преглед](#преглед)
2. [Архитектура на консенсуса](#архитектура-на-консенсуса)
3. [Процес на копаене](#процес-на-копаене)
4. [Валидация на блокове](#валидация-на-блокове)
5. [Система за делегиране](#система-за-делегиране)
6. [Мрежово разпространение](#мрежово-разпространение)
7. [Технически детайли](#технически-детайли)

---

## Преглед

Bitcoin-PoCX имплементира чист Proof of Capacity консенсусен механизъм като пълна замяна на Bitcoin Proof of Work. Това е нова верига без изисквания за обратна съвместимост.

**Ключови свойства:**
- **Енергийно ефективен:** Копаенето използва предварително генерирани plot файлове вместо изчислително хеширане
- **Time Bended крайни срокове:** Трансформация на разпределението (експоненциално→хи-квадрат) намалява дългите блокове, подобрява средните времена на блокове
- **Поддръжка на делегиране:** Собствениците на plot файлове могат да делегират права за подписване на други адреси
- **Нативна C++ интеграция:** Криптографски алгоритми, имплементирани в C++ за консенсусна валидация

**Поток на копаене:**
```
Външен миньор → get_mining_info → Изчисляване на Nonce → submit_nonce →
Опашка за подписване → Изчакване на краен срок → Подписване на блок → Мрежово разпространение →
Валидация на блок → Разширяване на веригата
```

---

## Архитектура на консенсуса

### Структура на блок

PoCX блоковете разширяват структурата на Bitcoin блок с допълнителни консенсусни полета:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed на plot (32 байта)
    std::array<uint8_t, 20> account_id;       // Адрес на plot (20-байтов hash160)
    uint32_t compression;                     // Ниво на мащабиране (1-6)
    uint64_t nonce;                           // Nonce за копаене (64-бит)
    uint64_t quality;                         // Декларирано качество (изход на PoC хеш)
};

class CBlockHeader {
    // Стандартни Bitcoin полета
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX консенсусни полета (заместват nBits и nNonce)
    int nHeight;                              // Височина на блок (валидация без контекст)
    uint256 generationSignature;              // Генерационен подпис (ентропия за копаене)
    uint64_t nBaseTarget;                     // Параметър за трудност (обратна трудност)
    PoCXProof pocxProof;                      // Доказателство за копаене

    // Полета за подпис на блок
    std::array<uint8_t, 33> vchPubKey;        // Компресиран публичен ключ (33 байта)
    std::array<uint8_t, 65> vchSignature;     // Компактен подпис (65 байта)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Транзакции
};
```

**Забележка:** Подписът (`vchSignature`) е изключен от изчисляването на хеша на блока, за да се предотврати податливост.

**Имплементация:** `src/primitives/block.h`

### Генерационен подпис

Генерационният подпис създава ентропия за копаене и предотвратява атаки с предварително изчисляване.

**Изчисляване:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Генезис блок:** Използва твърдо кодиран начален генерационен подпис

**Имплементация:** `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

### Базова цел (трудност)

Базовата цел е обратната на трудността — по-високи стойности означават по-лесно копаене.

**Алгоритъм за корекция:**
- Целево време на блок: 120 секунди (mainnet), 1 секунда (regtest)
- Интервал на корекция: Всеки блок
- Използва плаваща средна на последните базови цели
- Ограничена, за да предотврати екстремни промени в трудността

**Имплементация:** `src/consensus/params.h`, логика за трудност в създаването на блок

### Нива на мащабиране

PoCX поддържа мащабируем proof-of-work в plot файлове чрез нива на мащабиране (Xn).

**Динамични граници:**
```cpp
struct CompressionBounds {
    uint32_t nPoCXMinCompression;     // Минимално приемано ниво
    uint32_t nPoCXTargetCompression;  // Препоръчително ниво
};
```

**График за увеличаване на мащабирането:**
- Експоненциални интервали: Години 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Минималното ниво на мащабиране се увеличава с 1
- Целевото ниво на мащабиране се увеличава с 1
- Поддържа предпазен марж между разходите за създаване и търсене на plot файлове
- Максимално ниво на мащабиране: 7 (target = min + 1, with min capping at 6)

**Имплементация:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## Процес на копаене

### 1. Извличане на информация за копаене

**RPC команда:** `get_mining_info`

**Процес:**
1. Извикване на `GetNewBlockContext(chainman)` за извличане на текущото състояние на блокчейна
2. Изчисляване на динамични граници на компресия за текущата височина
3. Връщане на параметри за копаене

**Отговор:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 1,
  "target_compression_level": 2
}
```

**Имплементация:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Забележки:**
- Не се държат заключвания по време на генериране на отговор
- Придобиването на контекст обработва `cs_main` вътрешно
- `block_hash` е включен за справка, но не се използва при валидация

### 2. Външно копаене

**Отговорности на външния миньор:**
1. Четене на plot файлове от диска
2. Изчисляване на scoop на базата на генерационен подпис и височина
3. Намиране на nonce с най-добър краен срок
4. Подаване към възела чрез `submit_nonce`

**Формат на Plot файл:**
- Базиран на POC2 формат (Burstcoin)
- Подобрен с поправки за сигурност и подобрения за мащабируемост
- Вижте признанието в `CLAUDE.md`

**Имплементация на миньор:** Външна (напр. базирана на Scavenger)

### 3. Подаване и валидация на Nonce

**RPC команда:** `submit_nonce`

**Параметри:**
```
height, generation_signature, account_id, seed, nonce, quality (незадължителен)
```

**Поток на валидация (оптимизиран ред):**

#### Стъпка 1: Бърза валидация на формат
```cpp
// Account ID: 40 hex символа = 20 байта
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex символа = 32 байта
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Стъпка 2: Придобиване на контекст
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Връща: height, generation_signature, base_target, block_hash
```

**Заключване:** `cs_main` се обработва вътрешно, не се държат заключвания в RPC нишка

#### Стъпка 3: Валидация на контекст
```cpp
// Проверка на височина
if (height != context.height) reject;

// Проверка на генерационен подпис
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Стъпка 4: Верификация на портфейл
```cpp
// Определяне на ефективен подписващ (с отчитане на делегирания)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Проверка дали възелът има частен ключ за ефективния подписващ
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Поддръжка на делегиране:** Собственикът на plot може да делегира права за подписване на друг адрес. Портфейлът трябва да има ключ за ефективния подписващ, не непременно за собственика на plot.

#### Step 5: Compression Validation
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
if (compression < bounds.nPoCXMinCompression || compression > bounds.nPoCXTargetCompression)
    reject;
```

#### Step 7: Time Bending: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 байта
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Алгоритъм:**
1. Декодиране на генерационен подпис от hex
2. Изчисляване на най-добро качество в диапазона на компресия с SIMD-оптимизирани алгоритми
3. Валидация, че качеството отговаря на изискванията за трудност
4. Връщане на сурова стойност на качество

**Имплементация:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### Стъпка 6: Изчисляване на Time Bending
```cpp
// Суров краен срок, коригиран за трудност (секунди)
uint64_t deadline_seconds = quality / base_target;

// Time Bended време за подписване (секунди)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Формула на Time Bending:**
```
Y = scale * (X^(1/3))
където:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Цел:** Трансформира експоненциално в хи-квадрат разпределение. Много добрите решения се подписват по-късно (мрежата има време да сканира дисковете), лошите решения се подобряват. Намалява дългите блокове, поддържа средно 120s.

**Имплементация:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission: Подаване към планировчика
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,
    compression,
    block_hash        // sole staleness indicator
);
```

**Дизайн, базиран на опашка:**
- Подаването винаги успява (добавя се към опашката)
- RPC връща незабавно
- Работническа нишка обработва асинхронно

**Имплементация:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Обработка на опашката за подписване

**Архитектура:**
- Една постоянна работническа нишка
- FIFO опашка за подаване
- Състояние за подписване без заключване (само работническа нишка)
- Без вложени заключвания (предотвратяване на deadlock)

**Главен цикъл на работническа нишка:**
```cpp
while (!shutdown) {
    // 1. Проверка за подадени в опашката
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Изчакване на краен срок или ново подаване
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Логика на ProcessSubmission:**
```cpp
1. Получаване на свеж контекст: GetNewBlockContext(*chainman)

2. Проверки за остарялост (тихо отхвърляне):
   - Несъответствие на височина → отхвърляне
   - Несъответствие на генерационен подпис → отхвърляне
   - Промяна на хеша на върха на блока (реорг) → нулиране на състоянието за подписване

3. Quality comparison (lower = better):
   - Ако quality >= current_best → отхвърляне

4. Изчисляване на Time Bended краен срок:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Актуализация на състоянието за подписване:
   - Отмяна на съществуващо подписване (ако е намерено по-добро)
   - Съхраняване: account_id, seed, nonce, quality, deadline
   - Изчисляване: forge_time = block_time + deadline_seconds
   - Съхраняване на хеш на върха за откриване на реорг
```

**Имплементация:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Изчакване на краен срок и подписване на блок

**WaitForDeadlineOrNewSubmission:**

**Условия за изчакване:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**При достигане на краен срок — валидация на свеж контекст:**
```cpp
1. Получаване на текущ контекст: GetNewBlockContext(*chainman)

2. Валидация на височина:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Валидация на генерационен подпис:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Граничен случай с базова цел:
   if (forging_base_target != current_base_target) {
       // Преизчисляване на краен срок с нова базова цел
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Изчакване отново
   }

5. Всичко валидно → ForgeBlock()
```

**Процес на ForgeBlock:**

```cpp
1. Определяне на ефективен подписващ (поддръжка на делегиране):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Създаване на coinbase скрипт:
   coinbase_script = P2WPKH(effective_signer);  // Плаща на ефективния подписващ

3. Създаване на шаблон за блок:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Добавяне на PoCX доказателство:
   block.pocxProof.account_id = plot_address;    // Оригинален адрес на plot
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Преизчисляване на merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Подписване на блок:
   // Използване на ключа на ефективния подписващ (може да е различен от собственика на plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Подаване към веригата:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Обработка на резултат:
   if (accepted) {
       log_success();
       reset_forging_state();  // Готов за следващ блок
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Имплементация:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**Ключови дизайнерски решения:**
- Coinbase плаща на ефективния подписващ (уважава делегиранията)
- Доказателството съдържа оригиналния адрес на plot (за валидация)
- Подпис от ключа на ефективния подписващ (доказателство за собственост)
- Създаването на шаблон включва транзакции от mempool автоматично

---

## Валидация на блокове

### Поток на валидация на входящ блок

Когато блок се получи от мрежата или се подаде локално, той преминава валидация на множество етапи:

### Етап 1: Валидация на заглавие (CheckBlockHeader)

**Валидация без контекст:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX валидация (когато ENABLE_POCX е дефиниран):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Базова валидация на подпис (без поддръжка на делегиране още)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Базова валидация на подпис:**
1. Проверка за наличие на полета за публичен ключ и подпис
2. Валидация на размер на публичен ключ (33 байта компресиран)
3. Валидация на размер на подпис (65 байта компактен)
4. Възстановяване на публичен ключ от подпис: `pubkey.RecoverCompact(hash, signature)`
5. Проверка дали възстановеният публичен ключ съвпада със съхранения

**Имплементация:** `src/validation.cpp:CheckBlockHeader()`
**Логика на подпис:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### Етап 2: Валидация на блок (CheckBlock)

**Валидира:**
- Коректност на Merkle root
- Валидност на транзакции
- Изисквания за coinbase
- Лимити за размер на блок
- Стандартни Bitcoin консенсусни правила

**Имплементация:** `src/consensus/validation.cpp:CheckBlock()`

### Етап 3: Контекстуална валидация на заглавие (ContextualCheckBlockHeader)

**PoCX-специфична валидация:**

```cpp
#ifdef ENABLE_POCX
    // Step 1: Validate block height
    if (block.nHeight != pindexPrev->nHeight + 1) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-height");
    }

    // Step 2: Validate generation signature
    uint256 expected_gen_sig = GetNextGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gensig");
    }

    // Step 3: Validate base target
    uint64_t expected_base_target = pindexPrev->nNextBaseTarget;
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Step 4: Verify deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (poc_time > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-timing");
    }
#endif
```

**Validation Steps:**
1. **Height:** Must be previous height + 1
2. **Generation Signature:** Must match calculated value from previous block
3. **Base Target:** Must match pre-computed value from previous block
4. **Deadline Timing:** Time-bended deadline (`poc_time`) must be ≤ elapsed time

**Имплементация:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Етап 4: Свързване на блок (ConnectBlock)

**Пълна контекстуална валидация:**

```cpp
#ifdef ENABLE_POCX
    // Разширена валидация на подпис с поддръжка на делегиране
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Разширена валидация на подпис:**
1. Извършване на базова валидация на подпис
2. Извличане на account ID от възстановен публичен ключ
3. Получаване на ефективен подписващ за адрес на plot: `GetEffectiveSigner(plot_address, height, view)`
4. Проверка дали акаунтът на публичния ключ съвпада с ефективния подписващ

**Логика на делегиране:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Връщане на делегиран подписващ
    }

    return plotAddress;  // Без делегиране — собственикът на plot подписва
}
```

**Имплементация:**
- Свързване: `src/validation.cpp:ConnectBlock()`
- Разширена валидация: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- Логика на делегиране: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### Етап 5: Активиране на верига

**Поток на ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Валидиране и съхраняване на диск
    2. ActivateBestChain → Актуализация на върха на веригата ако това е най-добрата верига
    3. Уведомяване на мрежата за нов блок
}
```

**Имплементация:** `src/validation.cpp:ProcessNewBlock()`

### Обобщение на валидацията

**Пълен път на валидация:**
```
Получаване на блок
    ↓
CheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
CheckBlock (транзакции, merkle)
    ↓
ContextualCheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
ConnectBlock (разширен подпис с делегиране, преходи на състояние)
    ↓
ActivateBestChain (обработка на реорг, разширяване на верига)
    ↓
Мрежово разпространение
```

---

## Система за делегиране

### Преглед

Делегиранията позволяват на собствениците на plot файлове да делегират права за подписване на други адреси, като запазват собствеността върху plot файловете.

**Случаи на употреба:**
- Копаене в пул (plot файловете се делегират на адрес на пула)
- Студено съхранение (ключът за копаене е отделен от собствеността върху plot)
- Многостранно копаене (споделена инфраструктура)

### Архитектура на делегиране

**Дизайн само с OP_RETURN:**
- Делегиранията се съхраняват в OP_RETURN изходи (без UTXO)
- Без изисквания за харчене (без прах, без такси за държане)
- Проследяват се в разширено състояние на CCoinsViewCache
- Активират се след период на забавяне (по подразбиране: 4 блока)

**Състояния на делегиране:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Не съществува делегиране
    ASSIGNING = 1,   // Делегиране в очакване на активиране (период на забавяне)
    ASSIGNED = 2,    // Делегиране активно, подписване разрешено
    REVOKING = 3,    // Отмяна в очакване (период на забавяне, все още активно)
    REVOKED = 4      // Отмяна завършена, делегирането вече не е активно
};
```

### Създаване на делегирания

**Формат на транзакция:**
```cpp
Transaction {
    inputs: [any]  // Доказва собственост върху адрес на plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Правила за валидация:**
1. Входът трябва да бъде подписан от собственика на plot (доказва собственост)
2. OP_RETURN съдържа валидни данни за делегиране
3. Plot трябва да бъде UNASSIGNED или REVOKED
4. Без дублиращи се чакащи делегирания в mempool
5. Платена минимална такса за транзакция

**Активиране:**
- Делегирането става ASSIGNING при височина на потвърждение
- Става ASSIGNED след период на забавяне (4 блока regtest, 30 блока mainnet)
- Забавянето предотвратява бързи пределегирания по време на състезания за блокове

**Имплементация:** `src/pocx/assignments/opcodes.h`, валидация в ConnectBlock

### Отмяна на делегирания

**Формат на транзакция:**
```cpp
Transaction {
    inputs: [any]  // Доказва собственост върху адрес на plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Ефект:**
- Незабавен преход на състояние към REVOKED
- Собственикът на plot може да подписва незабавно
- Може да създаде ново делегиране след това

### Валидация на делегиране при копаене

**Определяне на ефективен подписващ:**
```cpp
// При валидация на submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// При подписване на блок
coinbase_script = P2WPKH(effective_signer);  // Наградата отива тук

// При подпис на блок
signature = effective_signer_key.SignCompact(hash);  // Трябва да подпише с ефективен подписващ
```

**Валидация на блок:**
```cpp
// В VerifyPoCXBlockCompactSignature (разширена)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Ключови свойства:**
- Доказателството винаги съдържа оригиналния адрес на plot
- Подписът трябва да бъде от ефективния подписващ
- Coinbase плаща на ефективния подписващ
- Валидацията използва състояние на делегиране при височина на блока

---

## Мрежово разпространение

### Обявяване на блок

**Стандартен Bitcoin P2P протокол:**
1. Подписаният блок се подава чрез `ProcessNewBlock()`
2. Блокът се валидира и добавя към веригата
3. Мрежово уведомяване: `GetMainSignals().BlockConnected()`
4. P2P слоят разпространява блока към пиъри

**Имплементация:** Стандартен Bitcoin Core net_processing

### Препредаване на блок

**Компактни блокове (BIP 152):**
- Използват се за ефективно разпространение на блокове
- Първоначално се изпращат само ID на транзакции
- Пиърите заявяват липсващи транзакции

**Препредаване на пълен блок:**
- Резерва когато компактните блокове се провалят
- Предават се пълни данни на блок

### Реорганизации на верига

**Обработка на реорганизации:**
```cpp
// В работническата нишка на подписващия
if (current_tip_hash != stored_tip_hash) {
    // Открита реорганизация на верига
    reset_forging_state();
    log("Върхът на веригата се промени, нулиране на подписване");
}
```

**На ниво блокчейн:**
- Стандартна обработка на реорганизации от Bitcoin Core
- Най-добрата верига се определя от chainwork
- Отвързаните блокове се връщат в mempool

---

## Технически детайли

### Предотвратяване на Deadlock

**ABBA Deadlock модел (предотвратен):**
```
Нишка A: cs_main → cs_wallet
Нишка B: cs_wallet → cs_main
```

**Решение:**
1. **submit_nonce:** Нулево използване на cs_main
   - `GetNewBlockContext()` обработва заключването вътрешно
   - Цялата валидация преди подаване към подписващия

2. **Подписващ:** Архитектура, базирана на опашка
   - Една работническа нишка (без thread joins)
   - Свеж контекст при всеки достъп
   - Без вложени заключвания

3. **Проверки на портфейл:** Извършват се преди скъпи операции
   - Ранно отхвърляне ако няма наличен ключ
   - Отделено от достъп до състояние на блокчейн

### Оптимизации на производителност

**Бърз отказ при валидация:**
```cpp
1. Проверки на формат (незабавни)
2. Валидация на контекст (лека)
3. Верификация на портфейл (локална)
4. Валидация на доказателство (скъпа SIMD)
```

**Единично извличане на контекст:**
- Едно извикване на `GetNewBlockContext()` на подаване
- Кеширане на резултати за множество проверки
- Без повторни cs_main заключвания

**Ефективност на опашка:**
- Лека структура за подаване
- Без base_target/deadline в опашката (преизчисляват се свежи)
- Минимален отпечатък в паметта

### Обработка на остарялост

**"Прост" дизайн на подписващия:**
- Без абонаменти за събития на блокчейна
- Мързелива валидация когато е необходима
- Тихо отхвърляне на остарели подавания

**Предимства:**
- Проста архитектура
- Без сложна синхронизация
- Устойчивост към гранични случаи

**Обработени гранични случаи:**
- Промени на височина → отхвърляне
- Промени на генерационен подпис → отхвърляне
- Промени на базова цел → преизчисляване на краен срок
- Реорганизации → нулиране на състояние за подписване

### Криптографски детайли

**Генерационен подпис:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**Хеш за подпис на блок:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**Компактен формат на подпис:**
- 65 байта: [recovery_id][r][s]
- Позволява възстановяване на публичен ключ
- Използва се за ефективност на пространството

**Account ID:**
- 20-байтов HASH160 на компресиран публичен ключ
- Съвпада с Bitcoin формати на адреси (P2PKH, P2WPKH)

### Бъдещи подобрения

**Документирани ограничения:**
1. Без метрики за производителност (честота на подаване, разпределения на крайни срокове)
2. Без детайлна категоризация на грешки за миньори
3. Ограничено заявяване на статус на подписващия (текущ краен срок, дълбочина на опашка)

**Потенциални подобрения:**
- RPC за статус на подписващия
- Метрики за ефективност на копаене
- Подобрено логване за дебъгване
- Поддръжка на протокол за пул

---

## Препратки към код

**Основни имплементации:**
- RPC интерфейс: `src/pocx/rpc/mining.cpp`
- Опашка за подписване: `src/pocx/mining/scheduler.cpp`
- Консенсусна валидация: `src/pocx/consensus/proof.cpp`
- Валидация на доказателство: `src/pocx/consensus/signature.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Валидация на блок: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Логика на делегиране: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- Управление на контекст: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**Структури от данни:**
- Формат на блок: `src/primitives/block.h`
- Консенсусни параметри: `src/consensus/params.h`
- Проследяване на делегиране: `src/coins.h` (разширения на CCoinsViewCache)

---

## Приложение: Спецификации на алгоритми

### Формула на Time Bending

**Математическа дефиниция:**
```
deadline_seconds = quality / base_target  (суров)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

където:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Имплементация:**
- Аритметика с фиксирана точка (Q42 формат)
- Изчисляване на кубичен корен само с цели числа
- Оптимизирана за 256-битова аритметика

### Изчисляване на качество

**Процес:**
1. Генериране на scoop от генерационен подпис и височина
2. Четене на plot данни за изчисления scoop
3. Хеш: `Shabal256Lite(scoop_data, generation_signature)`
4. Тестване на нива на мащабиране от min до max
5. Връщане на най-доброто намерено качество

**Мащабиране:**
- Ниво X0: POC2 базова линия (теоретично)
- Ниво X1: XOR-transpose базова линия
- Ниво Xn: 2^(n-1) × X1 работа вградена
- По-високо мащабиране = повече работа при генериране на plot

### Корекция на базова цел

**Корекция при всеки блок:**
1. Изчисляване на плаваща средна на последните базови цели
2. Изчисляване на действителен период спрямо целеви период за плаващ прозорец
3. Пропорционална корекция на базова цел
4. Ограничаване за предотвратяване на екстремни промени

**Формула:**
```
avg_base_target = moving_average(последни базови цели)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*Тази документация отразява пълната PoCX консенсусна имплементация към октомври 2025.*

---

[← Назад: Формат на Plot файловете](2-plot-format.md) | [📘 Съдържание](index.md) | [Напред: Делегиране на подписване →](4-forging-assignments.md)

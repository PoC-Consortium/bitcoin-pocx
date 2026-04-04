[← Назад: Формат плотів](2-plot-format.md) | [📘 Зміст](index.md) | [Далі: Призначення кування →](4-forging-assignments.md)

---

# Розділ 3: Консенсус і процес майнінгу Bitcoin-PoCX

Повна технічна специфікація механізму консенсусу PoCX (Proof of Capacity наступного покоління) та процесу майнінгу, інтегрованого в Bitcoin Core.

---

## Зміст

1. [Огляд](#огляд)
2. [Архітектура консенсусу](#архітектура-консенсусу)
3. [Процес майнінгу](#процес-майнінгу)
4. [Валідація блоків](#валідація-блоків)
5. [Система призначень](#система-призначень)
6. [Мережеве розповсюдження](#мережеве-розповсюдження)
7. [Технічні деталі](#технічні-деталі)

---

## Огляд

Bitcoin-PoCX реалізує чистий механізм консенсусу Proof of Capacity як повну заміну Proof of Work Bitcoin. Це новий ланцюг без вимог зворотної сумісності.

**Ключові властивості:**
- **Енергоефективність:** Майнінг використовує попередньо згенеровані файли плотів замість обчислювального хешування
- **Time Bended дедлайни:** Трансформація розподілу (експоненційний→хі-квадрат) зменшує довгі блоки, покращує середній час блоків
- **Підтримка призначень:** Власники плотів можуть делегувати права кування іншим адресам
- **Нативна інтеграція C++:** Криптографічні алгоритми реалізовані на C++ для валідації консенсусу

**Потік майнінгу:**
```
Зовнішній майнер → get_mining_info → Обчислення Nonce → submit_nonce →
Черга кування → Очікування дедлайну → Кування блоку → Мережеве розповсюдження →
Валідація блоку → Розширення ланцюга
```

---

## Архітектура консенсусу

### Структура блоку

Блоки PoCX розширюють структуру блоку Bitcoin додатковими полями консенсусу:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed плоту (32 байти)
    std::array<uint8_t, 20> account_id;       // Адреса плоту (20-байтовий hash160)
    uint32_t compression;                     // Рівень масштабування (1-6)
    uint64_t nonce;                           // Nonce майнінгу (64-біт)
    uint64_t quality;                         // Заявлена якість (вивід хешу PoC)
};

class CBlockHeader {
    // Стандартні поля Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Поля консенсусу PoCX (замінюють nBits та nNonce)
    int nHeight;                              // Висота блоку (контекстно-незалежна валідація)
    uint256 generationSignature;              // Сигнатура генерації (ентропія майнінгу)
    uint64_t nBaseTarget;                     // Параметр складності (обернена складність)
    PoCXProof pocxProof;                      // Доказ майнінгу

    // Поля підпису блоку
    std::array<uint8_t, 33> vchPubKey;        // Стиснутий публічний ключ (33 байти)
    std::array<uint8_t, 65> vchSignature;     // Компактний підпис (65 байтів)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Транзакції
};
```

**Примітка:** Підпис (`vchSignature`) виключено з обчислення хешу блоку для запобігання ковкості.

**Реалізація:** `src/primitives/block.h`

### Сигнатура генерації

Сигнатура генерації створює ентропію майнінгу та запобігає атакам попереднього обчислення.

**Обчислення:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Блок генезису:** Використовує жорстко закодовану початкову сигнатуру генерації

**Реалізація:** `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

### Базова ціль (складність)

Базова ціль є оберненою до складності — вищі значення означають легший майнінг.

**Алгоритм налаштування:**
- Цільовий час блоку: 120 секунд (mainnet), 1 секунда (regtest)
- Інтервал налаштування: Кожен блок
- Використовує ковзне середнє недавніх базових цілей
- Обмежено для запобігання екстремальним коливанням складності

**Реалізація:** `src/consensus/params.h`, логіка складності в створенні блоку

### Рівні масштабування

PoCX підтримує масштабований proof-of-work у файлах плотів через рівні масштабування (Xn).

**Динамічні межі:**
```cpp
struct CompressionBounds {
    uint32_t nPoCXMinCompression;     // Мінімальний прийнятний рівень
    uint32_t nPoCXTargetCompression;  // Рекомендований рівень
};
```

**Графік збільшення масштабування:**
- Експоненційні інтервали: Роки 4, 12, 28, 60, 124 (халвінги 1, 3, 7, 15, 31)
- Мінімальний рівень масштабування збільшується на 1
- Цільовий рівень масштабування збільшується на 1
- Підтримує запас міцності між витратами на створення плотів і пошуком
- Максимальний рівень масштабування: 7 (target = min + 1, with min capping at 6)

**Реалізація:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## Процес майнінгу

### 1. Отримання інформації про майнінг

**Команда RPC:** `get_mining_info`

**Процес:**
1. Виклик `GetNewBlockContext(chainman)` для отримання поточного стану блокчейну
2. Обчислення динамічних меж стиснення для поточної висоти
3. Повернення параметрів майнінгу

**Відповідь:**
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

**Реалізація:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Примітки:**
- Під час генерації відповіді блокування не утримуються
- Отримання контексту обробляє `cs_main` внутрішньо
- `block_hash` включено для довідки, але не використовується у валідації

### 2. Зовнішній майнінг

**Обов'язки зовнішнього майнера:**
1. Читання файлів плотів з диска
2. Обчислення scoop на основі сигнатури генерації та висоти
3. Пошук nonce з найкращим дедлайном
4. Подання до вузла через `submit_nonce`

**Формат файлу плоту:**
- На основі формату POC2 (Burstcoin)
- Покращений виправленнями безпеки та покращеннями масштабованості
- Див. атрибуцію в `CLAUDE.md`

**Реалізація майнера:** Зовнішня (напр., на основі Scavenger)

### 3. Подання та валідація Nonce

**Команда RPC:** `submit_nonce`

**Параметри:**
```
height, generation_signature, account_id, seed, nonce, quality (опціонально)
```

**Потік валідації (оптимізований порядок):**

#### Крок 1: Швидка валідація формату
```cpp
// Account ID: 40 hex символів = 20 байтів
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex символи = 32 байти
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Крок 2: Отримання контексту
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Повертає: height, generation_signature, base_target, block_hash
```

**Блокування:** `cs_main` обробляється внутрішньо, блокування не утримуються в потоці RPC

#### Крок 3: Валідація контексту
```cpp
// Перевірка висоти
if (height != context.height) reject;

// Перевірка сигнатури генерації
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Крок 4: Перевірка гаманця
```cpp
// Визначення ефективного підписанта (з урахуванням призначень)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Перевірка чи вузол має приватний ключ для ефективного підписанта
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Підтримка призначень:** Власник плоту може призначити права кування іншій адресі. Гаманець повинен мати ключ для ефективного підписанта, не обов'язково для власника плоту.

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
    account_payload,     // 20 байтів
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Алгоритм:**
1. Декодування сигнатури генерації з hex
2. Обчислення найкращої якості в діапазоні стиснення з використанням SIMD-оптимізованих алгоритмів
3. Валідація відповідності якості вимогам складності
4. Повернення сирого значення якості

**Реалізація:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### Крок 6: Обчислення Time Bending
```cpp
// Сирий дедлайн з урахуванням складності (секунди)
uint64_t deadline_seconds = quality / base_target;

// Time Bended час кування (секунди)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Формула Time Bending:**
```
Y = scale * (X^(1/3))
де:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Призначення:** Трансформує експоненційний розподіл у хі-квадрат. Дуже хороші рішення куються пізніше (мережа має час просканувати диски), погані рішення покращуються. Зменшує довгі блоки, підтримує середні 120с.

**Реалізація:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission: Подання до кувача
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

**Дизайн на основі черги:**
- Подання завжди успішне (додається до черги)
- RPC повертається негайно
- Робочий потік обробляє асинхронно

**Реалізація:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Обробка черги кувача

**Архітектура:**
- Один постійний робочий потік
- FIFO черга подань
- Безблокувальний стан кування (тільки робочий потік)
- Без вкладених блокувань (запобігання взаємним блокуванням)

**Головний цикл робочого потоку:**
```cpp
while (!shutdown) {
    // 1. Перевірка на подання в черзі
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Очікування дедлайну або нового подання
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Логіка ProcessSubmission:**
```cpp
1. Отримання свіжого контексту: GetNewBlockContext(*chainman)

2. Перевірки на застарілість (мовчазне відкидання):
   - Невідповідність висоти → відкинути
   - Невідповідність сигнатури генерації → відкинути
   - Зміна хешу блоку верхівки (реорганізація) → скидання стану кування

3. Порівняння якості:
   - Якщо quality >= current_best → відкинути

4. Обчислення Time Bended дедлайну:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Оновлення стану кування:
   - Скасування існуючого кування (якщо знайдено краще)
   - Збереження: account_id, seed, nonce, quality, deadline
   - Обчислення: forge_time = block_time + deadline_seconds
   - Збереження хешу верхівки для виявлення реорганізацій
```

**Реалізація:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Очікування дедлайну та кування блоку

**WaitForDeadlineOrNewSubmission:**

**Умови очікування:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**При досягненні дедлайну — валідація свіжого контексту:**
```cpp
1. Отримання поточного контексту: GetNewBlockContext(*chainman)

2. Валідація висоти:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Валідація сигнатури генерації:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Крайній випадок базової цілі:
   if (forging_base_target != current_base_target) {
       // Перерахунок дедлайну з новою базовою ціллю
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Очікування знову
   }

5. Все валідно → ForgeBlock()
```

**Процес ForgeBlock:**

```cpp
1. Визначення ефективного підписанта (підтримка призначень):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Створення скрипту coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Платить ефективному підписанту

3. Створення шаблону блоку:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Додавання доказу PoCX:
   block.pocxProof.account_id = plot_address;    // Оригінальна адреса плоту
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Перерахунок кореня Merkle:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Підпис блоку:
   // Використання ключа ефективного підписанта (може відрізнятися від власника плоту)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Подання до ланцюга:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Обробка результату:
   if (accepted) {
       log_success();
       reset_forging_state();  // Готовий до наступного блоку
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Реалізація:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**Ключові проектні рішення:**
- Coinbase платить ефективному підписанту (дотримується призначень)
- Доказ містить оригінальну адресу плоту (для валідації)
- Підпис від ключа ефективного підписанта (доказ володіння)
- Створення шаблону автоматично включає транзакції mempool

---

## Валідація блоків

### Потік валідації вхідного блоку

Коли блок отримано з мережі або подано локально, він проходить валідацію в кількох етапах:

### Етап 1: Валідація заголовка (CheckBlockHeader)

**Контекстно-незалежна валідація:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Валідація PoCX (коли визначено ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Базова валідація підпису (ще без підтримки призначень)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Базова валідація підпису:**
1. Перевірка наявності полів pubkey та signature
2. Валідація розміру pubkey (33 байти стиснутий)
3. Валідація розміру підпису (65 байтів компактний)
4. Відновлення pubkey з підпису: `pubkey.RecoverCompact(hash, signature)`
5. Перевірка відповідності відновленого pubkey збереженому

**Реалізація:** `src/validation.cpp:CheckBlockHeader()`
**Логіка підпису:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### Етап 2: Валідація блоку (CheckBlock)

**Валідує:**
- Коректність кореня Merkle
- Валідність транзакцій
- Вимоги до coinbase
- Обмеження розміру блоку
- Стандартні правила консенсусу Bitcoin

**Реалізація:** `src/consensus/validation.cpp:CheckBlock()`

### Етап 3: Контекстна валідація заголовка (ContextualCheckBlockHeader)

**Валідація специфічна для PoCX:**

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

**Реалізація:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Етап 4: Підключення блоку (ConnectBlock)

**Повна контекстна валідація:**

```cpp
#ifdef ENABLE_POCX
    // Розширена валідація підпису з підтримкою призначень
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Розширена валідація підпису:**
1. Виконання базової валідації підпису
2. Витягування account ID з відновленого pubkey
3. Отримання ефективного підписанта для адреси плоту: `GetEffectiveSigner(plot_address, height, view)`
4. Перевірка відповідності облікового запису pubkey ефективному підписанту

**Логіка призначень:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Повернення призначеного підписанта
    }

    return plotAddress;  // Без призначення - підписує власник плоту
}
```

**Реалізація:**
- Підключення: `src/validation.cpp:ConnectBlock()`
- Розширена валідація: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- Логіка призначень: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### Етап 5: Активація ланцюга

**Потік ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Валідація та збереження на диск
    2. ActivateBestChain → Оновлення верхівки ланцюга якщо це найкращий ланцюг
    3. Сповіщення мережі про новий блок
}
```

**Реалізація:** `src/validation.cpp:ProcessNewBlock()`

### Підсумок валідації

**Повний шлях валідації:**
```
Отримання блоку
    ↓
CheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
CheckBlock (транзакції, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC доказ, дедлайн)
    ↓
ConnectBlock (розширений підпис з призначеннями, переходи стану)
    ↓
ActivateBestChain (обробка реорганізацій, розширення ланцюга)
    ↓
Мережеве розповсюдження
```

---

## Система призначень

### Огляд

Призначення дозволяють власникам плотів делегувати права кування іншим адресам, зберігаючи при цьому володіння плотом.

**Випадки використання:**
- Пул-майнінг (плоти призначаються на адресу пулу)
- Холодне зберігання (ключ майнінгу окремо від володіння плотом)
- Багатосторонній майнінг (спільна інфраструктура)

### Архітектура призначень

**Дизайн тільки на OP_RETURN:**
- Призначення зберігаються у виводах OP_RETURN (без UTXO)
- Без вимог витрачання (без dust, без комісій за утримання)
- Відстежуються в розширеному стані CCoinsViewCache
- Активуються після періоду затримки (за замовчуванням: 4 блоки)

**Стани призначень:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Призначення не існує
    ASSIGNING = 1,   // Призначення очікує активації (період затримки)
    ASSIGNED = 2,    // Призначення активне, кування дозволено
    REVOKING = 3,    // Скасування очікує (період затримки, ще активне)
    REVOKED = 4      // Скасування завершено, призначення більше не активне
};
```

### Створення призначень

**Формат транзакції:**
```cpp
Transaction {
    inputs: [any]  // Доводить володіння адресою плоту
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Правила валідації:**
1. Вхід повинен бути підписаний власником плоту (доводить володіння)
2. OP_RETURN містить валідні дані призначення
3. Плот повинен бути UNASSIGNED або REVOKED
4. Без дублікатів очікуваних призначень у mempool
5. Мінімальна комісія транзакції сплачена

**Активація:**
- Призначення стає ASSIGNING на висоті підтвердження
- Стає ASSIGNED після періоду затримки (4 блоки regtest, 30 блоків mainnet)
- Затримка запобігає швидким перепризначенням під час гонок блоків

**Реалізація:** `src/pocx/assignments/opcodes.h`, валідація в ConnectBlock

### Скасування призначень

**Формат транзакції:**
```cpp
Transaction {
    inputs: [any]  // Доводить володіння адресою плоту
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Ефект:**
- Негайний перехід стану до REVOKED
- Власник плоту може кувати негайно
- Можна створити нове призначення після цього

### Валідація призначень під час майнінгу

**Визначення ефективного підписанта:**
```cpp
// У валідації submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// У куванні блоку
coinbase_script = P2WPKH(effective_signer);  // Винагорода йде сюди

// У підписі блоку
signature = effective_signer_key.SignCompact(hash);  // Повинен підписати ефективним підписантом
```

**Валідація блоку:**
```cpp
// У VerifyPoCXBlockCompactSignature (розширена)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Ключові властивості:**
- Доказ завжди містить оригінальну адресу плоту
- Підпис повинен бути від ефективного підписанта
- Coinbase платить ефективному підписанту
- Валідація використовує стан призначення на висоті блоку

---

## Мережеве розповсюдження

### Оголошення блоку

**Стандартний P2P протокол Bitcoin:**
1. Скований блок подається через `ProcessNewBlock()`
2. Блок валідується та додається до ланцюга
3. Мережеве сповіщення: `GetMainSignals().BlockConnected()`
4. P2P рівень розсилає блок пірам

**Реалізація:** Стандартна обробка мережі Bitcoin Core

### Ретрансляція блоків

**Компактні блоки (BIP 152):**
- Використовуються для ефективного розповсюдження блоків
- Спочатку надсилаються лише ID транзакцій
- Піри запитують відсутні транзакції

**Ретрансляція повних блоків:**
- Резервний варіант коли компактні блоки не працюють
- Передаються повні дані блоку

### Реорганізації ланцюга

**Обробка реорганізацій:**
```cpp
// У робочому потоці кувача
if (current_tip_hash != stored_tip_hash) {
    // Виявлено реорганізацію ланцюга
    reset_forging_state();
    log("Верхівка ланцюга змінилася, скидання кування");
}
```

**Рівень блокчейну:**
- Стандартна обробка реорганізацій Bitcoin Core
- Найкращий ланцюг визначається за chainwork
- Від'єднані блоки повертаються до mempool

---

## Технічні деталі

### Запобігання взаємним блокуванням

**Патерн взаємного блокування ABBA (запобігається):**
```
Потік A: cs_main → cs_wallet
Потік B: cs_wallet → cs_main
```

**Рішення:**
1. **submit_nonce:** Нульове використання cs_main
   - `GetNewBlockContext()` обробляє блокування внутрішньо
   - Уся валідація до подання кувачу

2. **Кувач:** Архітектура на основі черги
   - Один робочий потік (без приєднання потоків)
   - Свіжий контекст при кожному доступі
   - Без вкладених блокувань

3. **Перевірки гаманця:** Виконуються до дорогих операцій
   - Раннє відхилення якщо ключ недоступний
   - Окремо від доступу до стану блокчейну

### Оптимізації продуктивності

**Швидкий провал валідації:**
```cpp
1. Перевірки формату (негайні)
2. Валідація контексту (легка)
3. Перевірка гаманця (локальна)
4. Валідація доказу (дорога SIMD)
```

**Одноразове отримання контексту:**
- Один виклик `GetNewBlockContext()` на подання
- Кешування результатів для кількох перевірок
- Без повторних захоплень cs_main

**Ефективність черги:**
- Легка структура подання
- Без base_target/deadline в черзі (перераховуються свіжі)
- Мінімальний відбиток пам'яті

### Обробка застарілості

**Дизайн "простого" кувача:**
- Без підписок на події блокчейну
- Ледача валідація коли потрібно
- Мовчазне відкидання застарілих подань

**Переваги:**
- Проста архітектура
- Без складної синхронізації
- Стійкість до крайніх випадків

**Оброблювані крайні випадки:**
- Зміни висоти → відкинути
- Зміни сигнатури генерації → відкинути
- Зміни базової цілі → перерахувати дедлайн
- Реорганізації → скинути стан кування

### Криптографічні деталі

**Сигнатура генерації:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**Хеш підпису блоку:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**Формат компактного підпису:**
- 65 байтів: [recovery_id][r][s]
- Дозволяє відновлення публічного ключа
- Використовується для економії простору

**Account ID:**
- 20-байтовий HASH160 стиснутого публічного ключа
- Відповідає форматам адрес Bitcoin (P2PKH, P2WPKH)

### Майбутні покращення

**Задокументовані обмеження:**
1. Без метрик продуктивності (частота подань, розподіл дедлайнів)
2. Без детальної категоризації помилок для майнерів
3. Обмежене запитування статусу кувача (поточний дедлайн, глибина черги)

**Можливі покращення:**
- RPC для статусу кувача
- Метрики ефективності майнінгу
- Покращене логування для налагодження
- Підтримка протоколу пулу

---

## Посилання на код

**Основні реалізації:**
- Інтерфейс RPC: `src/pocx/rpc/mining.cpp`
- Черга кувача: `src/pocx/mining/scheduler.cpp`
- Валідація консенсусу: `src/pocx/consensus/proof.cpp`
- Валідація доказу: `src/pocx/consensus/signature.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Валідація блоків: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Логіка призначень: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- Управління контекстом: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**Структури даних:**
- Формат блоку: `src/primitives/block.h`
- Параметри консенсусу: `src/consensus/params.h`
- Відстеження призначень: `src/coins.h` (розширення CCoinsViewCache)

---

## Додаток: Специфікації алгоритмів

### Формула Time Bending

**Математичне визначення:**
```
deadline_seconds = quality / base_target  (сирий)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

де:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Реалізація:**
- Арифметика з фіксованою точкою (формат Q42)
- Цілочисельне обчислення кубічного кореня
- Оптимізовано для 256-бітної арифметики

### Обчислення якості

**Процес:**
1. Генерація scoop з сигнатури генерації та висоти
2. Читання даних плоту для обчисленого scoop
3. Хеш: `Shabal256Lite(scoop_data, generation_signature)`
4. Тестування рівнів масштабування від min до max
5. Повернення найкращої знайденої якості

**Масштабування:**
- Рівень X0: Базовий рівень POC2 (теоретичний)
- Рівень X1: Базовий рівень XOR-transpose
- Рівень Xn: 2^(n-1) × вбудована робота X1
- Вище масштабування = більше роботи генерації плоту

### Налаштування базової цілі

**Налаштування кожного блоку:**
1. Обчислення ковзного середнього недавніх базових цілей
2. Обчислення фактичного часу vs цільового часу для ковзного вікна
3. Пропорційне налаштування базової цілі
4. Обмеження для запобігання екстремальних коливань

**Формула:**
```
avg_base_target = moving_average(недавні базові цілі)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*Ця документація відображає повну реалізацію консенсусу PoCX станом на жовтень 2025.*

---

[← Назад: Формат плотів](2-plot-format.md) | [📘 Зміст](index.md) | [Далі: Призначення кування →](4-forging-assignments.md)

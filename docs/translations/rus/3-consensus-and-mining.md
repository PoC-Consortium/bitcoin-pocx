[<- Назад: Формат графиков](2-plot-format.md) | [Содержание](index.md) | [Далее: Делегирование форджинга ->](4-forging-assignments.md)

---

# Глава 3: Консенсус и процесс майнинга Bitcoin-PoCX

Полная техническая спецификация механизма консенсуса PoCX (Proof of Capacity нового поколения) и процесса майнинга, интегрированного в Bitcoin Core.

---

## Содержание

1. [Обзор](#обзор)
2. [Архитектура консенсуса](#архитектура-консенсуса)
3. [Процесс майнинга](#процесс-майнинга)
4. [Валидация блоков](#валидация-блоков)
5. [Система делегирования](#система-делегирования)
6. [Распространение по сети](#распространение-по-сети)
7. [Технические детали](#технические-детали)

---

## Обзор

Bitcoin-PoCX реализует чистый механизм консенсуса Proof of Capacity в качестве полной замены Proof of Work в Bitcoin. Это новая цепочка без требований обратной совместимости.

**Ключевые свойства:**
- **Энергоэффективность:** Майнинг использует предварительно сгенерированные файлы графиков вместо вычислительного хеширования
- **Искривлённые дедлайны:** Преобразование распределения (экспоненциальное->хи-квадрат) уменьшает длинные блоки, улучшает среднее время блоков
- **Поддержка делегирования:** Владельцы графиков могут делегировать права форджинга другим адресам
- **Нативная интеграция C++:** Криптографические алгоритмы реализованы на C++ для валидации консенсуса

**Поток майнинга:**
```
Внешний майнер -> get_mining_info -> Вычисление нонса -> submit_nonce ->
Очередь форджера -> Ожидание дедлайна -> Форджинг блока -> Распространение по сети ->
Валидация блока -> Расширение цепочки
```

---

## Архитектура консенсуса

### Структура блока

Блоки PoCX расширяют структуру блока Bitcoin дополнительными полями консенсуса:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed графика (32 байта)
    std::array<uint8_t, 20> account_id;       // Адрес графика (20-байтный hash160)
    uint32_t compression;                     // Уровень масштабирования (1-255)
    uint64_t nonce;                           // Нонс майнинга (64-бит)
    uint64_t quality;                         // Заявленное качество (выход хеша PoC)
};

class CBlockHeader {
    // Стандартные поля Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Поля консенсуса PoCX (заменяют nBits и nNonce)
    int nHeight;                              // Высота блока (валидация без контекста)
    uint256 generationSignature;              // Сигнатура генерации (энтропия майнинга)
    uint64_t nBaseTarget;                     // Параметр сложности (обратная сложность)
    PoCXProof pocxProof;                      // Доказательство майнинга

    // Поля подписи блока
    std::array<uint8_t, 33> vchPubKey;        // Сжатый публичный ключ (33 байта)
    std::array<uint8_t, 65> vchSignature;     // Компактная подпись (65 байт)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Транзакции
};
```

**Примечание:** Подпись (`vchSignature`) исключена из вычисления хеша блока для предотвращения податливости.

**Реализация:** `src/primitives/block.h`

### Сигнатура генерации

Сигнатура генерации создаёт энтропию майнинга и предотвращает атаки предварительного вычисления.

**Вычисление:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Генезис-блок:** Использует жёстко закодированную начальную сигнатуру генерации

**Реализация:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Базовая цель (сложность)

Базовая цель — это обратная величина сложности: более высокие значения означают более лёгкий майнинг.

**Алгоритм корректировки:**
- Целевое время блока: 120 секунд (mainnet), 1 секунда (regtest)
- Интервал корректировки: Каждый блок
- Использует скользящее среднее недавних базовых целей
- Ограничено для предотвращения экстремальных скачков сложности

**Реализация:** `src/consensus/params.h`, логика корректировки сложности при создании блока

### Уровни масштабирования

PoCX поддерживает масштабируемое доказательство работы в файлах графиков через уровни масштабирования (Xn).

**Динамические границы:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Минимальный принимаемый уровень
    uint8_t nPoCXTargetCompression;  // Рекомендуемый уровень
};
```

**График увеличения масштабирования:**
- Экспоненциальные интервалы: годы 4, 12, 28, 60, 124 (халвинги 1, 3, 7, 15, 31)
- Минимальный уровень масштабирования увеличивается на 1
- Целевой уровень масштабирования увеличивается на 1
- Поддерживает запас безопасности между стоимостью создания и поиска в графиках
- Максимальный уровень масштабирования: 255

**Реализация:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Процесс майнинга

### 1. Получение информации о майнинге

**RPC-команда:** `get_mining_info`

**Процесс:**
1. Вызов `GetNewBlockContext(chainman)` для получения текущего состояния блокчейна
2. Вычисление динамических границ сжатия для текущей высоты
3. Возврат параметров майнинга

**Ответ:**
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

**Реализация:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Примечания:**
- Блокировки не удерживаются во время генерации ответа
- Получение контекста обрабатывает `cs_main` внутренне
- `block_hash` включён для справки, но не используется при валидации

### 2. Внешний майнинг

**Обязанности внешнего майнера:**
1. Чтение файлов графиков с диска
2. Вычисление скупа на основе сигнатуры генерации и высоты
3. Поиск нонса с лучшим дедлайном
4. Отправка на узел через `submit_nonce`

**Формат файла графика:**
- Основан на формате POC2 (Burstcoin)
- Улучшен с исправлениями безопасности и улучшениями масштабируемости
- См. атрибуцию в `CLAUDE.md`

**Реализация майнера:** Внешняя (например, на основе Scavenger)

### 3. Отправка и валидация нонса

**RPC-команда:** `submit_nonce`

**Параметры:**
```
height, generation_signature, account_id, seed, nonce, quality (опционально)
```

**Поток валидации (оптимизированный порядок):**

#### Шаг 1: Быстрая валидация формата
```cpp
// Account ID: 40 hex символов = 20 байт
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex символа = 32 байта
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Шаг 2: Получение контекста
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Возвращает: height, generation_signature, base_target, block_hash
```

**Блокировка:** `cs_main` обрабатывается внутренне, блокировки не удерживаются в потоке RPC

#### Шаг 3: Валидация контекста
```cpp
// Проверка высоты
if (height != context.height) reject;

// Проверка сигнатуры генерации
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Шаг 4: Проверка кошелька
```cpp
// Определение эффективного подписанта (с учётом делегирования)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Проверка, есть ли у узла приватный ключ для эффективного подписанта
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Поддержка делегирования:** Владелец графика может делегировать права форджинга другому адресу. Кошелёк должен иметь ключ для эффективного подписанта, не обязательно владельца графика.

#### Шаг 5: Валидация доказательства
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 байт
    block_height,
    nonce,
    seed,                // 32 байта
    min_compression,
    max_compression,
    &result             // Выход: quality, deadline
);
```

**Алгоритм:**
1. Декодирование сигнатуры генерации из hex
2. Вычисление лучшего качества в диапазоне сжатия с использованием SIMD-оптимизированных алгоритмов
3. Проверка соответствия качества требованиям сложности
4. Возврат сырого значения качества

**Реализация:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Шаг 6: Вычисление искривления времени
```cpp
// Сырой дедлайн с корректировкой сложности (секунды)
uint64_t deadline_seconds = quality / base_target;

// Искривлённое время форджинга (секунды)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Формула искривления времени:**
```
Y = scale * (X^(1/3))
где:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) приблизительно 0.892979511
```

**Цель:** Преобразует экспоненциальное распределение в хи-квадрат. Очень хорошие решения форджатся позже (сеть успевает просканировать диски), плохие решения улучшаются. Уменьшает длинные блоки, поддерживает среднее 120с.

**Реализация:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Шаг 7: Отправка в форджер
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // НЕ дедлайн — пересчитывается в форджере
    height,
    generation_signature
);
```

**Дизайн на основе очереди:**
- Отправка всегда успешна (добавляется в очередь)
- RPC возвращается немедленно
- Рабочий поток обрабатывает асинхронно

**Реализация:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Обработка очереди форджера

**Архитектура:**
- Единственный постоянный рабочий поток
- FIFO очередь отправок
- Состояние форджинга без блокировок (только рабочий поток)
- Без вложенных блокировок (предотвращение дедлоков)

**Основной цикл рабочего потока:**
```cpp
while (!shutdown) {
    // 1. Проверка отправок в очереди
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Ожидание дедлайна или новой отправки
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Логика ProcessSubmission:**
```cpp
1. Получить свежий контекст: GetNewBlockContext(*chainman)

2. Проверки устаревания (тихое отбрасывание):
   - Несовпадение высоты -> отбросить
   - Несовпадение сигнатуры генерации -> отбросить
   - Изменился хеш блока вершины (реорг) -> сбросить состояние форджинга

3. Сравнение качества:
   - Если quality >= current_best -> отбросить

4. Вычислить искривлённый дедлайн:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Обновить состояние форджинга:
   - Отменить существующий форджинг (если найден лучший)
   - Сохранить: account_id, seed, nonce, quality, deadline
   - Вычислить: forge_time = block_time + deadline_seconds
   - Сохранить хеш вершины для обнаружения реорга
```

**Реализация:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Ожидание дедлайна и форджинг блока

**WaitForDeadlineOrNewSubmission:**

**Условия ожидания:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**При достижении дедлайна — валидация свежего контекста:**
```cpp
1. Получить текущий контекст: GetNewBlockContext(*chainman)

2. Валидация высоты:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Валидация сигнатуры генерации:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Краевой случай базовой цели:
   if (forging_base_target != current_base_target) {
       // Пересчитать дедлайн с новой базовой целью
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Ждать снова
   }

5. Всё валидно -> ForgeBlock()
```

**Процесс ForgeBlock:**

```cpp
1. Определить эффективного подписанта (поддержка делегирования):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Создать скрипт coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Платит эффективному подписанту

3. Создать шаблон блока:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Добавить доказательство PoCX:
   block.pocxProof.account_id = plot_address;    // Оригинальный адрес графика
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Пересчитать корень Меркла:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Подписать блок:
   // Использовать ключ эффективного подписанта (может отличаться от владельца графика)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Отправить в цепочку:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Обработка результата:
   if (accepted) {
       log_success();
       reset_forging_state();  // Готов к следующему блоку
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Реализация:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Ключевые проектные решения:**
- Coinbase платит эффективному подписанту (уважает делегирование)
- Доказательство содержит оригинальный адрес графика (для валидации)
- Подпись от ключа эффективного подписанта (доказательство владения)
- Создание шаблона автоматически включает транзакции из мемпула

---

## Валидация блоков

### Поток валидации входящего блока

Когда блок получен из сети или отправлен локально, он проходит валидацию в несколько этапов:

### Этап 1: Валидация заголовка (CheckBlockHeader)

**Валидация без контекста:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Валидация PoCX (когда определён ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Базовая валидация подписи (без поддержки делегирования пока)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Базовая валидация подписи:**
1. Проверка наличия полей pubkey и signature
2. Валидация размера pubkey (33 байта сжатый)
3. Валидация размера подписи (65 байт компактная)
4. Восстановление pubkey из подписи: `pubkey.RecoverCompact(hash, signature)`
5. Проверка совпадения восстановленного pubkey с сохранённым

**Реализация:** `src/validation.cpp:CheckBlockHeader()`
**Логика подписи:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Этап 2: Валидация блока (CheckBlock)

**Валидирует:**
- Корректность корня Меркла
- Валидность транзакций
- Требования coinbase
- Ограничения размера блока
- Стандартные правила консенсуса Bitcoin

**Реализация:** `src/consensus/validation.cpp:CheckBlock()`

### Этап 3: Контекстная валидация заголовка (ContextualCheckBlockHeader)

**Валидация, специфичная для PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Шаг 1: Валидация сигнатуры генерации
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Шаг 2: Валидация базовой цели
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Шаг 3: Валидация proof of capacity
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

    // Шаг 4: Проверка времени дедлайна
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Шаги валидации:**
1. **Сигнатура генерации:** Должна совпадать с вычисленным значением из предыдущего блока
2. **Базовая цель:** Должна совпадать с вычислением корректировки сложности
3. **Уровень масштабирования:** Должен соответствовать минимуму сети (`compression >= min_compression`)
4. **Заявка качества:** Отправленное качество должно совпадать с вычисленным качеством из доказательства
5. **Proof of Capacity:** Валидация криптографического доказательства (SIMD-оптимизированная)
6. **Время дедлайна:** Искривлённый дедлайн (`poc_time`) должен быть <= прошедшего времени

**Реализация:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Этап 4: Подключение блока (ConnectBlock)

**Полная контекстная валидация:**

```cpp
#ifdef ENABLE_POCX
    // Расширенная валидация подписи с поддержкой делегирования
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Расширенная валидация подписи:**
1. Выполнить базовую валидацию подписи
2. Извлечь ID аккаунта из восстановленного pubkey
3. Получить эффективного подписанта для адреса графика: `GetEffectiveSigner(plot_address, height, view)`
4. Проверить совпадение аккаунта pubkey с эффективным подписантом

**Логика делегирования:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Вернуть делегированного подписанта
    }

    return plotAddress;  // Нет делегирования — владелец графика подписывает
}
```

**Реализация:**
- Подключение: `src/validation.cpp:ConnectBlock()`
- Расширенная валидация: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Логика делегирования: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Этап 5: Активация цепочки

**Поток ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Валидация и сохранение на диск
    2. ActivateBestChain -> Обновление вершины цепочки если это лучшая цепочка
    3. Уведомление сети о новом блоке
}
```

**Реализация:** `src/validation.cpp:ProcessNewBlock()`

### Сводка валидации

**Полный путь валидации:**
```
Получение блока
    |
CheckBlockHeader (базовая подпись)
    |
CheckBlock (транзакции, merkle)
    |
ContextualCheckBlockHeader (gen sig, base target, доказательство PoC, дедлайн)
    |
ConnectBlock (расширенная подпись с делегированием, переходы состояния)
    |
ActivateBestChain (обработка реоргов, расширение цепочки)
    |
Распространение по сети
```

---

## Система делегирования

### Обзор

Делегирование позволяет владельцам графиков делегировать права форджинга другим адресам, сохраняя при этом владение графиком.

**Варианты использования:**
- Пул-майнинг (графики делегируются адресу пула)
- Холодное хранение (ключ майнинга отделён от владения графиком)
- Многосторонний майнинг (общая инфраструктура)

### Архитектура делегирования

**Дизайн только на основе OP_RETURN:**
- Делегирования хранятся в выходах OP_RETURN (без UTXO)
- Без требований расходования (без пыли, без комиссий за хранение)
- Отслеживается в расширенном состоянии CCoinsViewCache
- Активируется после периода задержки (по умолчанию: 4 блока)

**Состояния делегирования:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Делегирование не существует
    ASSIGNING = 1,   // Делегирование ожидает активации (период задержки)
    ASSIGNED = 2,    // Делегирование активно, форджинг разрешён
    REVOKING = 3,    // Отзыв в ожидании (период задержки, всё ещё активно)
    REVOKED = 4      // Отзыв завершён, делегирование больше не активно
};
```

### Создание делегирования

**Формат транзакции:**
```cpp
Transaction {
    inputs: [any]  // Подтверждает владение адресом графика
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Правила валидации:**
1. Вход должен быть подписан владельцем графика (подтверждает владение)
2. OP_RETURN содержит валидные данные делегирования
3. Графику должен быть в состоянии UNASSIGNED или REVOKED
4. Нет дублирующих ожидающих делегирований в мемпуле
5. Минимальная комиссия за транзакцию оплачена

**Активация:**
- Делегирование становится ASSIGNING на высоте подтверждения
- Становится ASSIGNED после периода задержки (4 блока regtest, 30 блоков mainnet)
- Задержка предотвращает быстрые переназначения во время гонок блоков

**Реализация:** `src/script/forging_assignment.h`, валидация в ConnectBlock

### Отзыв делегирования

**Формат транзакции:**
```cpp
Transaction {
    inputs: [any]  // Подтверждает владение адресом графика
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Эффект:**
- Немедленный переход состояния в REVOKED
- Владелец графика может форджить немедленно
- Можно создать новое делегирование после

### Валидация делегирования при майнинге

**Определение эффективного подписанта:**
```cpp
// В валидации submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// При форджинге блока
coinbase_script = P2WPKH(effective_signer);  // Награда идёт сюда

// В подписи блока
signature = effective_signer_key.SignCompact(hash);  // Должен подписать эффективным подписантом
```

**Валидация блока:**
```cpp
// В VerifyPoCXBlockCompactSignature (расширенная)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Ключевые свойства:**
- Доказательство всегда содержит оригинальный адрес графика
- Подпись должна быть от эффективного подписанта
- Coinbase платит эффективному подписанту
- Валидация использует состояние делегирования на высоте блока

---

## Распространение по сети

### Объявление блока

**Стандартный P2P-протокол Bitcoin:**
1. Сформированный блок отправляется через `ProcessNewBlock()`
2. Блок валидируется и добавляется в цепочку
3. Уведомление сети: `GetMainSignals().BlockConnected()`
4. P2P-уровень транслирует блок пирам

**Реализация:** Стандартная net_processing Bitcoin Core

### Ретрансляция блока

**Компактные блоки (BIP 152):**
- Используются для эффективного распространения блоков
- Изначально отправляются только ID транзакций
- Пиры запрашивают отсутствующие транзакции

**Полная ретрансляция блока:**
- Резервный вариант при сбое компактных блоков
- Передаются полные данные блока

### Реорганизации цепочки

**Обработка реоргов:**
```cpp
// В рабочем потоке форджера
if (current_tip_hash != stored_tip_hash) {
    // Обнаружена реорганизация цепочки
    reset_forging_state();
    log("Вершина цепочки изменилась, сброс форджинга");
}
```

**На уровне блокчейна:**
- Стандартная обработка реоргов Bitcoin Core
- Лучшая цепочка определяется по chainwork
- Отключённые блоки возвращаются в мемпул

---

## Технические детали

### Предотвращение дедлоков

**Паттерн ABBA дедлока (предотвращён):**
```
Поток A: cs_main -> cs_wallet
Поток B: cs_wallet -> cs_main
```

**Решение:**
1. **submit_nonce:** Нулевое использование cs_main
   - `GetNewBlockContext()` обрабатывает блокировку внутренне
   - Вся валидация до отправки в форджер

2. **Форджер:** Архитектура на основе очереди
   - Единственный рабочий поток (без присоединений потоков)
   - Свежий контекст при каждом доступе
   - Без вложенных блокировок

3. **Проверки кошелька:** Выполняются до дорогих операций
   - Раннее отклонение если ключ недоступен
   - Отделено от доступа к состоянию блокчейна

### Оптимизации производительности

**Валидация с быстрым отказом:**
```cpp
1. Проверки формата (немедленно)
2. Валидация контекста (легковесная)
3. Проверка кошелька (локальная)
4. Валидация доказательства (дорогая SIMD)
```

**Единственная выборка контекста:**
- Один вызов `GetNewBlockContext()` на отправку
- Кеширование результатов для множественных проверок
- Без повторных захватов cs_main

**Эффективность очереди:**
- Легковесная структура отправки
- Без base_target/deadline в очереди (пересчитываются свежими)
- Минимальный объём памяти

### Обработка устаревания

**«Глупый» дизайн форджера:**
- Без подписок на события блокчейна
- Ленивая валидация когда нужно
- Тихое отбрасывание устаревших отправок

**Преимущества:**
- Простая архитектура
- Без сложной синхронизации
- Устойчивость к краевым случаям

**Обрабатываемые краевые случаи:**
- Изменения высоты -> отбросить
- Изменения сигнатуры генерации -> отбросить
- Изменения базовой цели -> пересчитать дедлайн
- Реорги -> сбросить состояние форджинга

### Криптографические детали

**Сигнатура генерации:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Хеш подписи блока:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Формат компактной подписи:**
- 65 байт: [recovery_id][r][s]
- Позволяет восстановить публичный ключ
- Используется для экономии места

**ID аккаунта:**
- 20-байтный HASH160 сжатого публичного ключа
- Соответствует форматам адресов Bitcoin (P2PKH, P2WPKH)

### Будущие улучшения

**Задокументированные ограничения:**
1. Нет метрик производительности (частота отправок, распределения дедлайнов)
2. Нет детальной категоризации ошибок для майнеров
3. Ограниченный запрос статуса форджера (текущий дедлайн, глубина очереди)

**Потенциальные улучшения:**
- RPC для статуса форджера
- Метрики эффективности майнинга
- Улучшенное логирование для отладки
- Поддержка протокола пулов

---

## Ссылки на код

**Основные реализации:**
- RPC-интерфейс: `src/pocx/rpc/mining.cpp`
- Очередь форджера: `src/pocx/mining/scheduler.cpp`
- Валидация консенсуса: `src/pocx/consensus/validation.cpp`
- Валидация доказательства: `src/pocx/consensus/pocx.cpp`
- Искривление времени: `src/pocx/algorithms/time_bending.cpp`
- Валидация блока: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Логика делегирования: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Управление контекстом: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Структуры данных:**
- Формат блока: `src/primitives/block.h`
- Параметры консенсуса: `src/consensus/params.h`
- Отслеживание делегирования: `src/coins.h` (расширения CCoinsViewCache)

---

## Приложение: Спецификации алгоритмов

### Формула искривления времени

**Математическое определение:**
```
deadline_seconds = quality / base_target  (сырое)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

где:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) приблизительно 0.892979511
```

**Реализация:**
- Арифметика с фиксированной точкой (формат Q42)
- Вычисление кубического корня только целыми числами
- Оптимизировано для 256-битной арифметики

### Вычисление качества

**Процесс:**
1. Генерация скупа из сигнатуры генерации и высоты
2. Чтение данных графика для вычисленного скупа
3. Хеширование: `SHABAL256(generation_signature || scoop_data)`
4. Тестирование уровней масштабирования от min до max
5. Возврат лучшего найденного качества

**Масштабирование:**
- Уровень X0: Базовая линия POC2 (теоретический)
- Уровень X1: Базовая линия XOR-транспонирования
- Уровень Xn: 2^(n-1) × встроенной работы X1
- Более высокое масштабирование = больше работы по генерации графика

### Корректировка базовой цели

**Корректировка каждый блок:**
1. Вычисление скользящего среднего недавних базовых целей
2. Вычисление фактического периода времени vs целевого периода для скользящего окна
3. Пропорциональная корректировка базовой цели
4. Ограничение для предотвращения экстремальных скачков

**Формула:**
```
avg_base_target = moving_average(недавние базовые цели)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Эта документация отражает полную реализацию консенсуса PoCX по состоянию на октябрь 2025.*

---

[<- Назад: Формат графиков](2-plot-format.md) | [Содержание](index.md) | [Далее: Делегирование форджинга ->](4-forging-assignments.md)

[← Претходно: Формат плотова](2-plot-format.md) | [📘 Садржај](index.md) | [Следеће: Додељивања ковања →](4-forging-assignments.md)

---

# Поглавље 3: Bitcoin-PoCX консензус и процес рударења

Комплетна техничка спецификација PoCX (Proof of Capacity нове генерације) механизма консензуса и процеса рударења интегрисаног у Bitcoin Core.

---

## Садржај

1. [Преглед](#преглед)
2. [Архитектура консензуса](#архитектура-консензуса)
3. [Процес рударења](#процес-рударења)
4. [Валидација блока](#валидација-блока)
5. [Систем додељивања](#систем-додељивања)
6. [Мрежно ширење](#мрежно-ширење)
7. [Технички детаљи](#технички-детаљи)

---

## Преглед

Bitcoin-PoCX имплементира чист механизам консензуса заснован на Proof of Capacity као комплетну замену за Bitcoin-ов Proof of Work. Ово је нови ланац без захтева за компатибилношћу уназад.

**Кључне особине:**
- **Енергетски ефикасан:** Рударење користи унапред генерисане плот датотеке уместо рачунарског хеширања
- **Рокови савијени временом:** Трансформација дистрибуције (експоненцијална→Вејбулова, параметар облика k=3) смањује дуге блокове, побољшава просечна времена блокова
- **Подршка за додељивање:** Власници плотова могу делегирати права ковања другим адресама
- **Нативна C++ интеграција:** Криптографски алгоритми имплементирани у C++ за валидацију консензуса

**Ток рударења:**
```
Спољни рудар → get_mining_info → Израчунај nonce → submit_nonce →
Ред чекања ковача → Чекање рока → Ковање блока → Мрежно ширење →
Валидација блока → Продужење ланца
```

---

## Архитектура консензуса

### Структура блока

PoCX блокови проширују Bitcoin-ову структуру блока са додатним пољима консензуса:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed плота (32 бајта)
    std::array<uint8_t, 20> account_id;       // Адреса плота (20-бајтни hash160)
    uint32_t compression;                     // Ниво скалирања (1-6)
    uint64_t nonce;                           // Nonce рударења (64-бит)
    uint64_t quality;                         // Пријављени квалитет (излаз PoC хеша)
};

class CBlockHeader {
    // Стандардна Bitcoin поља
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX поља консензуса (замењују nBits и nNonce)
    int nHeight;                              // Висина блока (валидација без контекста)
    uint256 generationSignature;              // Генерацијски потпис (ентропија рударења)
    uint64_t nBaseTarget;                     // Параметар тежине (инверзна тежина)
    PoCXProof pocxProof;                      // Доказ рударења

    // Поља потписа блока
    std::array<uint8_t, 33> vchPubKey;        // Компресован јавни кључ (33 бајта)
    std::array<uint8_t, 65> vchSignature;     // Компактни потпис (65 бајтова)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Трансакције
};
```

**Напомена:** Потпис (`vchSignature`) је искључен из израчунавања хеша блока да би се спречила малеабилност.

**Имплементација:** `src/primitives/block.h`

### Генерацијски потпис

Генерацијски потпис креира ентропију за рударење и спречава нападе претпретраживања.

**Израчунавање:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Генезис блок:** Користи хардкодирани иницијални генерацијски потпис

**Имплементација:** `src/pocx/consensus/difficulty.cpp:GetNextGenerationSignature()` (позива се из `src/pocx/mining/block_context.cpp:GetNewBlockContext()`)

### Базни циљ (тежина)

Базни циљ је инверзија тежине — више вредности значе лакше рударење.

**Алгоритам подешавања:**
- Циљано време блока: 120 секунди (све мреже)
- Интервал подешавања: Сваки блок
- Користи покретни просек недавних базних циљева
- Ограничен да спречи екстремне промене тежине

**Имплементација:** `src/consensus/params.h`, подешавање тежине у креирању блока

### Нивои скалирања

PoCX подржава скалабилни доказ рада у плот датотекама кроз нивое скалирања (Xn).

**Динамичке границе:**
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Минимални прихваћен ниво
    uint32_t nPoCXTargetCompression;  // Препоручени ниво
};
```

**Распоред повећања скалирања:**
- Експоненцијални интервали: Године 4, 12, 28, 60, 124 (преполовљавања 1, 3, 7, 15, 31)
- Минимални ниво скалирања се повећава за 1
- Циљани ниво скалирања се повећава за 1
- Одржава сигурносну маргину између трошкова креирања плота и претраживања
- Максимални ниво скалирања: 7 (target = min + 1, with min capping at 6)

**Имплементација:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## Процес рударења

### 1. Преузимање информација о рударењу

**RPC команда:** `get_mining_info`

**Процес:**
1. Позови `GetNewBlockContext(chainman)` да преузмеш тренутно стање блокчејна
2. Израчунај динамичке границе компресије за тренутну висину
3. Врати параметре рударења

**Одговор:**
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

**Имплементација:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Напомене:**
- Нема задржаних закључавања током генерисања одговора
- Преузимање контекста рукује `cs_main` интерно
- `block_hash` укључен за референцу али се не користи у валидацији

### 2. Спољно рударење

**Одговорности спољног рудара:**
1. Читај плот датотеке са диска
2. Израчунај scoop на основу генерацијског потписа и висине
3. Пронађи nonce са најбољим роком
4. Пошаљи на чвор преко `submit_nonce`

**Формат плот датотеке:**
- Заснован на POC2 формату (Burstcoin)
- Побољшан са безбедносним исправкама и побољшањима скалабилности
- Погледајте атрибуцију у `CLAUDE.md`

**Имплементација рудара:** Спољна (нпр. заснована на Scavenger)

### 3. Слање nonce-а и валидација

**RPC команда:** `submit_nonce`

**Параметри:**
```
height, generation_signature, account_id, seed, nonce, quality (опционо)
```

**Ток валидације (оптимизован редослед):**

#### Корак 1: Брза валидација формата
```cpp
// Account ID: 40 хекс карактера = 20 бајтова
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 хекс карактера = 32 бајта
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Корак 2: Преузимање контекста
```cpp
auto context = pocx::mining::GetNewBlockContext(chainman);
// Враћа: height, generation_signature, base_target, block_hash
```

**Закључавање:** `cs_main` се рукује интерно, нема закључавања у RPC нити

#### Корак 3: Валидација контекста
```cpp
// Провера висине
if (height != context.height) reject;

// Провера генерацијског потписа
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Корак 4: Верификација новчаника
```cpp
// Одреди ефективног потписника (узимајући у обзир додељивања)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Провери да ли чвор има приватни кључ за ефективног потписника
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Подршка за додељивање:** Власник плота може доделити права ковања другој адреси. Новчаник мора имати кључ за ефективног потписника, не обавезно за власника плота.

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
    account_payload,     // 20 бајтова
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Алгоритам:**
1. Декодирај генерацијски потпис из хекса
2. Израчунај најбољи квалитет у опсегу компресије користећи SIMD-оптимизоване алгоритме
3. Валидирај да квалитет задовољава захтеве тежине
4. Врати сирову вредност квалитета

**Имплементација:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### Корак 6: Израчунавање савијања времена
```cpp
// Сирови рок подешен тежином (секунде)
uint64_t deadline_seconds = quality / base_target;

// Време ковања савијено временом (секунде)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Формула савијања времена:**
```
Y = scale * (X^(1/3))
где:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Сврха:** Трансформише експоненцијалну у Вејбулову (параметар облика k=3) дистрибуцију. Веома добра решења се кују касније (мрежа има времена да скенира дискове), лоша решења су побољшана. Смањује дуге блокове, одржава просек од 120s.

**Имплементација:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission: Слање ковачу
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

**Дизајн заснован на реду чекања:**
- Слање увек успева (додаје се у ред чекања)
- RPC се одмах враћа
- Радна нит обрађује асинхроно

**Имплементација:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Обрада реда чекања ковача

**Архитектура:**
- Једна трајна радна нит
- FIFO ред чекања за слање
- Стање ковања без закључавања (само радна нит)
- Без угнежђених закључавања (превенција мртве петље)

**Главна петља радне нити:**
```cpp
while (!shutdown) {
    // 1. Провери за слања у реду чекања
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Чекај рок или ново слање
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Логика ProcessSubmission:**
```cpp
1. Добави свеж контекст: GetNewBlockContext(*chainman)

2. Провере застарелости (тихо одбацивање):
   - Неподударање висине → одбаци
   - Неподударање генерацијског потписа → одбаци
   - Промењен хеш врха блока (реорг) → ресетуј стање ковања

3. Поређење квалитета:
   - Ако је quality >= current_best → одбаци

4. Израчунај рок савијен временом:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Ажурирај стање ковања:
   - Откажи постојеће ковање (ако је пронађено боље)
   - Складишти: account_id, seed, nonce, quality, deadline
   - Израчунај: forge_time = block_time + deadline_seconds
   - Складишти хеш врха за детекцију реорга
```

**Имплементација:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Чекање рока и ковање блока

**WaitForDeadlineOrNewSubmission:**

**Услови чекања:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Када је рок достигнут - валидација свежег контекста:**
```cpp
1. Добави тренутни контекст: GetNewBlockContext(*chainman)

2. Валидација висине:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Валидација генерацијског потписа:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Гранични случај базног циља:
   if (forging_base_target != current_base_target) {
       // Прерачунај рок са новим базним циљем
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Чекај поново
   }

5. Све важи → ForgeBlock()
```

**Процес ForgeBlock:**

```cpp
1. Одреди ефективног потписника (подршка за додељивање):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Креирај coinbase скрипту:
   coinbase_script = P2WPKH(effective_signer);  // Плаћа ефективном потписнику

3. Креирај шаблон блока:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Додај PoCX доказ:
   block.pocxProof.account_id = plot_address;    // Оригинална адреса плота
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Прерачунај merkle корен:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Потпиши блок:
   // Користи кључ ефективног потписника (може бити другачији од власника плота)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Пошаљи у ланац:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Руковање резултатом:
   if (accepted) {
       log_success();
       reset_forging_state();  // Спремно за следећи блок
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Имплементација:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**Кључне дизајнерске одлуке:**
- Coinbase плаћа ефективном потписнику (поштује додељивања)
- Доказ садржи оригиналну адресу плота (за валидацију)
- Потпис од кључа ефективног потписника (доказ власништва)
- Креирање шаблона укључује mempool трансакције аутоматски

---

## Валидација блока

### Ток валидације долазећег блока

Када се блок прими од мреже или пошаље локално, пролази кроз валидацију у више фаза:

### Фаза 1: Валидација заглавља (CheckBlockHeader)

**Валидација без контекста:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX валидација (када је ENABLE_POCX дефинисан):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Основна валидација потписа (без подршке за додељивање још)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Основна валидација потписа:**
1. Провери присуство поља pubkey и signature
2. Валидирај величину pubkey-а (33 бајта компресовано)
3. Валидирај величину потписа (65 бајтова компактно)
4. Поврати pubkey из потписа: `pubkey.RecoverCompact(hash, signature)`
5. Верификуј да повраћени pubkey одговара складиштеном pubkey-у

**Имплементација:** `src/validation.cpp:CheckBlockHeader()`
**Логика потписа:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### Фаза 2: Валидација блока (CheckBlock)

**Валидира:**
- Тачност merkle корена
- Валидност трансакција
- Захтеви coinbase-а
- Ограничења величине блока
- Стандардна Bitcoin правила консензуса

**Имплементација:** `src/consensus/validation.cpp:CheckBlock()`

### Фаза 3: Контекстуална валидација заглавља (ContextualCheckBlockHeader)

**PoCX-специфична валидација:**

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

**Имплементација:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Фаза 4: Повезивање блока (ConnectBlock)

**Потпуна контекстуална валидација:**

```cpp
#ifdef ENABLE_POCX
    // Проширена валидација потписа са подршком за додељивање
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Проширена валидација потписа:**
1. Изврши основну валидацију потписа
2. Извуци account ID из повраћеног pubkey-а
3. Добави ефективног потписника за адресу плота: `GetEffectiveSigner(plot_address, height, view)`
4. Верификуј да account pubkey-а одговара ефективном потписнику

**Логика додељивања:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Врати додељеног потписника
    }

    return plotAddress;  // Нема додељивања - власник плота потписује
}
```

**Имплементација:**
- Повезивање: `src/validation.cpp:ConnectBlock()`
- Проширена валидација: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- Логика додељивања: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### Фаза 5: Активација ланца

**Ток ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Валидирај и сачувај на диск
    2. ActivateBestChain → Ажурирај врх ланца ако је ово најбољи ланац
    3. Обавести мрежу о новом блоку
}
```

**Имплементација:** `src/validation.cpp:ProcessNewBlock()`

### Резиме валидације

**Комплетна путања валидације:**
```
Прими блок
    ↓
CheckBlockHeader (основни потпис)
    ↓
CheckBlock (трансакције, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC доказ, рок)
    ↓
ConnectBlock (проширени потпис са додељивањима, прелази стања)
    ↓
ActivateBestChain (руковање реоргом, продужење ланца)
    ↓
Мрежно ширење
```

---

## Систем додељивања

### Преглед

Додељивања омогућавају власницима плотова да делегирају права ковања другим адресама док задржавају власништво над плотом.

**Случајеви употребе:**
- Рударење у пулу (плотови се додељују адреси пула)
- Хладно складиштење (кључ за рударење одвојен од власништва над плотом)
- Вишестраначко рударење (дељена инфраструктура)

### Архитектура додељивања

**Дизајн искључиво на OP_RETURN:**
- Додељивања складиштена у OP_RETURN излазима (без UTXO)
- Без захтева за трошење (без прашине, без накнада за држање)
- Праћено у проширеном стању CCoinsViewCache
- Активирано након периода кашњења (подразумевано: 30 блокова; 4 на regtest-у)

**Стања додељивања:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Нема додељивања
    ASSIGNING = 1,   // Додељивање чека активацију (период кашњења)
    ASSIGNED = 2,    // Додељивање активно, ковање дозвољено
    REVOKING = 3,    // Опозив у току (период кашњења, још увек активно)
    REVOKED = 4      // Опозив завршен, додељивање више није активно
};
```

### Креирање додељивања

**Формат трансакције:**
```cpp
Transaction {
    inputs: [any]  // Доказује власништво над адресом плота
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Правила валидације:**
1. Улаз мора бити потписан од стране власника плота (доказује власништво)
2. OP_RETURN садржи валидне податке о додељивању
3. Плот мора бити UNASSIGNED или REVOKED
4. Без дуплираних додељивања у mempool-у која чекају
5. Минимална накнада за трансакцију плаћена

**Активација:**
- Додељивање постаје ASSIGNING при потврди
- Постаје ASSIGNED након периода кашњења (4 блока regtest, 30 блокова mainnet)
- Кашњење спречава брзо поновно додељивање током трка блокова

**Имплементација:** `src/pocx/assignments/opcodes.h`, валидација у ConnectBlock

### Опозивање додељивања

**Формат трансакције:**
```cpp
Transaction {
    inputs: [any]  // Доказује власништво над адресом плота
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Ефекат:**
- Тренутни прелаз стања у REVOKED
- Власник плота може одмах ковати
- Може креирати ново додељивање после

### Валидација додељивања током рударења

**Одређивање ефективног потписника:**
```cpp
// У валидацији submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// У ковању блока
coinbase_script = P2WPKH(effective_signer);  // Награда иде овде

// У потпису блока
signature = effective_signer_key.SignCompact(hash);  // Мора потписати ефективни потписник
```

**Валидација блока:**
```cpp
// У VerifyPoCXBlockCompactSignature (проширено)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Кључне особине:**
- Доказ увек садржи оригиналну адресу плота
- Потпис мора бити од ефективног потписника
- Coinbase плаћа ефективном потписнику
- Валидација користи стање додељивања на висини блока

---

## Мрежно ширење

### Објављивање блока

**Стандардни Bitcoin P2P протокол:**
1. Исковани блок послат преко `ProcessNewBlock()`
2. Блок валидиран и додат у ланац
3. Мрежно обавештење: `GetMainSignals().BlockConnected()`
4. P2P слој емитује блок пировима

**Имплементација:** Стандардна Bitcoin Core net_processing

### Релеј блокова

**Компактни блокови (BIP 152):**
- Користе се за ефикасно ширење блокова
- Само ID-ови трансакција се шаљу иницијално
- Пирови захтевају трансакције које недостају

**Релеј пуних блокова:**
- Резервна опција када компактни блокови не успеју
- Преносе се комплетни подаци блока

### Реорганизације ланца

**Руковање реорганизацијом:**
```cpp
// У радној нити ковача
if (current_tip_hash != stored_tip_hash) {
    // Детектована реорганизација ланца
    reset_forging_state();
    log("Врх ланца промењен, ресетујем ковање");
}
```

**На нивоу блокчејна:**
- Стандардно Bitcoin Core руковање реорганизацијом
- Најбољи ланац одређен chainwork-ом
- Искључени блокови враћени у mempool

---

## Технички детаљи

### Превенција мртве петље

**ABBA образац мртве петље (спречен):**
```
Нит A: cs_main → cs_wallet
Нит B: cs_wallet → cs_main
```

**Решење:**
1. **submit_nonce:** Без употребе cs_main
   - `GetNewBlockContext()` рукује закључавањем интерно
   - Сва валидација пре слања ковачу

2. **Ковач:** Архитектура заснована на реду чекања
   - Једна радна нит (без спајања нити)
   - Свеж контекст при сваком приступу
   - Без угнежђених закључавања

3. **Провере новчаника:** Извршавају се пре скупих операција
   - Рано одбацивање ако кључ није доступан
   - Одвојено од приступа стању блокчејна

### Оптимизације перформанси

**Валидација са брзим неуспехом:**
```cpp
1. Провере формата (тренутно)
2. Валидација контекста (лагана)
3. Верификација новчаника (локална)
4. Валидација доказа (скупа SIMD)
```

**Једно преузимање контекста:**
- Један позив `GetNewBlockContext()` по слању
- Кеширање резултата за више провера
- Без поновљених преузимања cs_main

**Ефикасност реда чекања:**
- Лагана структура слања
- Без base_target/deadline у реду чекања (прерачунава се свеже)
- Минимални меморијски отисак

### Руковање застарелошћу

**„Глуп" дизајн ковача:**
- Без претплата на догађаје блокчејна
- Лења валидација када је потребна
- Тиха одбацивања застарелих слања

**Предности:**
- Једноставна архитектура
- Без сложене синхронизације
- Робустно против граничних случајева

**Руковање граничним случајевима:**
- Промене висине → одбаци
- Промене генерацијског потписа → одбаци
- Промене базног циља → прерачунај рок
- Реорганизације → ресетуј стање ковања

### Криптографски детаљи

**Генерацијски потпис:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**Хеш потписа блока:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**Формат компактног потписа:**
- 65 бајтова: [recovery_id][r][s]
- Омогућава поврат јавног кључа
- Користи се ради ефикасности простора

**Account ID:**
- 20-бајтни HASH160 компресованог јавног кључа
- Одговара Bitcoin форматима адреса (P2PKH, P2WPKH)

### Будућа унапређења

**Документована ограничења:**
1. Без метрика перформанси (стопе слања, дистрибуције рокова)
2. Без детаљне категоризације грешака за рударе
3. Ограничено упитивање статуса ковача (тренутни рок, дубина реда чекања)

**Потенцијална побољшања:**
- RPC за статус ковача
- Метрике за ефикасност рударења
- Побољшано логовање за отклањање грешака
- Подршка за протокол пулова

---

## Референце кода

**Основне имплементације:**
- RPC интерфејс: `src/pocx/rpc/mining.cpp`
- Ред чекања ковача: `src/pocx/mining/scheduler.cpp`
- Валидација консензуса: `src/pocx/consensus/proof.cpp`
- Валидација доказа: `src/pocx/consensus/signature.cpp`
- Савијање времена: `src/pocx/algorithms/time_bending.cpp`
- Валидација блока: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Логика додељивања: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- Управљање контекстом: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**Структуре података:**
- Формат блока: `src/primitives/block.h`
- Параметри консензуса: `src/consensus/params.h`
- Праћење додељивања: `src/coins.h` (проширења CCoinsViewCache)

---

## Додатак: Спецификације алгоритама

### Формула савијања времена

**Математичка дефиниција:**
```
deadline_seconds = quality / base_target  (сирово)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

где:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Имплементација:**
- Аритметика са фиксном тачком (Q42 формат)
- Израчунавање кубног корена само целим бројевима
- Оптимизовано за 256-битну аритметику

### Израчунавање квалитета

**Процес:**
1. Генериши scoop из генерацијског потписа и висине
2. Прочитај податке плота за израчунати scoop
3. Хеш: `Shabal256Lite(scoop_data, generation_signature)`
4. Тестирај нивое скалирања од min до max
5. Врати најбољи пронађени квалитет

**Скалирање:**
- Ниво X0: POC2 основа (теоријски)
- Ниво X1: XOR-transpose основа
- Ниво Xn: 2^(n-1) × X1 рад уграђен
- Веће скалирање = више рада генерисања плота

### Подешавање базног циља

**Подешавање на сваком блоку:**
1. Израчунај покретни просек недавних базних циљева
2. Израчунај стварни временски распон у односу на циљани за клизни прозор
3. Подеси базни циљ пропорционално
4. Ограничи да спречи екстремне промене

**Формула:**
```
avg_base_target = moving_average(недавни базни циљеви)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*Ова документација одражава комплетну имплементацију PoCX консензуса од октобра 2025.*

---

[← Претходно: Формат плотова](2-plot-format.md) | [📘 Садржај](index.md) | [Следеће: Додељивања ковања →](4-forging-assignments.md)

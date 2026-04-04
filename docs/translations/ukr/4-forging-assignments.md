[← Назад: Консенсус і майнінг](3-consensus-and-mining.md) | [📘 Зміст](index.md) | [Далі: Синхронізація часу →](5-timing-security.md)

---

# Розділ 4: Система призначення кування PoCX

## Виконавче резюме

Цей документ описує **реалізовану** систему призначення кування PoCX з використанням архітектури тільки на OP_RETURN. Система дозволяє власникам плотів делегувати права кування окремим адресам через транзакції в ланцюзі, з повною безпекою реорганізацій та атомарними операціями бази даних.

**Статус:** ✅ Повністю реалізовано та функціонує

## Основна філософія проектування

**Ключовий принцип:** Призначення — це дозволи, а не активи

- Без спеціальних UTXO для відстеження або витрачання
- Стан призначень зберігається окремо від набору UTXO
- Володіння доводиться підписом транзакції, а не витрачанням UTXO
- Повне відстеження історії для повного аудиторського сліду
- Атомарні оновлення бази даних через пакетний запис LevelDB

## Структура транзакцій

### Формат транзакції призначення

```
Входи:
  [0]: Будь-який UTXO, контрольований власником плоту (доводить володіння + сплачує комісії)
       Повинен бути підписаний приватним ключем власника плоту
  [1+]: Опціональні додаткові входи для покриття комісії

Виходи:
  [0]: OP_RETURN (маркер POCX + адреса плоту + адреса кування)
       Формат: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Розмір: 46 байтів загалом (1 байт OP_RETURN + 1 байт довжини + 44 байти даних)
       Значення: 0 BTC (невитрачуваний, не додається до набору UTXO)

  [1]: Решта повертається користувачу (опціонально, стандартний P2WPKH)
```

**Реалізація:** `src/pocx/assignments/opcodes.cpp`

### Формат транзакції скасування

```
Входи:
  [0]: Будь-який UTXO, контрольований власником плоту (доводить володіння + сплачує комісії)
       Повинен бути підписаний приватним ключем власника плоту
  [1+]: Опціональні додаткові входи для покриття комісії

Виходи:
  [0]: OP_RETURN (маркер XCOP + адреса плоту)
       Формат: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Розмір: 26 байтів загалом (1 байт OP_RETURN + 1 байт довжини + 24 байти даних)
       Значення: 0 BTC (невитрачуваний, не додається до набору UTXO)

  [1]: Решта повертається користувачу (опціонально, стандартний P2WPKH)
```

**Реалізація:** `src/pocx/assignments/opcodes.cpp`

### Маркери

- **Маркер призначення:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Маркер скасування:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Реалізація:** `src/pocx/assignments/opcodes.cpp`

### Ключові характеристики транзакцій

- Стандартні транзакції Bitcoin (без змін протоколу)
- Виходи OP_RETURN доказово невитрачувані (ніколи не додаються до набору UTXO)
- Володіння плотом доводиться підписом на input[0] з адреси плоту
- Низька вартість (~200 байтів, зазвичай <0.0001 BTC комісії)
- Гаманець автоматично вибирає найбільший UTXO з адреси плоту для доведення володіння

## Архітектура бази даних

### Структура зберігання

Усі дані призначень зберігаються в тій самій базі даних LevelDB, що й набір UTXO (`chainstate/`), але з окремими префіксами ключів:

```
chainstate/ LevelDB:
├─ Набір UTXO (стандарт Bitcoin Core)
│  └─ Префікс 'C': COutPoint → Coin
│
└─ Стан призначень (доповнення PoCX)
   └─ Префікс 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Повна історія: всі призначення для плоту з часом
```

**Реалізація:** `src/txdb.cpp`

### Структура ForgingAssignment

```cpp
struct ForgingAssignment {
    // Ідентичність
    std::array<uint8_t, 20> plotAddress;      // Власник плоту (20-байтовий хеш P2WPKH)
    std::array<uint8_t, 20> forgingAddress;   // Власник прав кування (20-байтовий хеш P2WPKH)

    // Життєвий цикл призначення
    uint256 assignment_txid;                   // Транзакція, що створила призначення
    int assignment_height;                     // Висота блоку створення
    int assignment_effective_height;           // Коли стає активним (висота + затримка)

    // Життєвий цикл скасування
    bool revoked;                              // Чи було це скасовано?
    uint256 revocation_txid;                   // Транзакція, що скасувала
    int revocation_height;                     // Висота блоку скасування
    int revocation_effective_height;           // Коли скасування ефективне (висота + затримка)

    // Методи запиту стану
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Реалізація:** `src/coins.h`

### Стани призначень

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Призначення не існує
    ASSIGNING = 1,   // Призначення створено, очікування затримки активації
    ASSIGNED = 2,    // Призначення активне, кування дозволено
    REVOKING = 3,    // Скасовано, але ще активне під час періоду затримки
    REVOKED = 4      // Повністю скасовано, більше не активне
};
```

**Реалізація:** `src/coins.h`

### Ключі бази даних

```cpp
// Ключ історії: зберігає повний запис призначення
// Формат ключа: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Адреса плоту (20 байтів)
    int assignment_height;                // Висота для оптимізації сортування
    uint256 assignment_txid;              // ID транзакції
};
```

**Реалізація:** `src/txdb.cpp`

### Відстеження історії

- Кожне призначення зберігається постійно (не видаляється якщо немає реорганізації)
- Кілька призначень для плоту відстежуються з часом
- Дозволяє повний аудиторський слід та запити історичного стану
- Скасовані призначення залишаються в базі даних з `revoked=true`

## Обробка блоків

### Інтеграція ConnectBlock

OP_RETURN призначень та скасувань обробляються під час підключення блоку в `validation.cpp`:

```cpp
// Розташування: Після валідації скриптів, перед UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Парсинг даних OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Перевірка володіння (tx повинна бути підписана власником плоту)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Перевірка стану плоту (повинен бути UNASSIGNED або REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Створення нового призначення
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Збереження даних скасування
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Парсинг даних OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Перевірка володіння
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Отримання поточного призначення
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Збереження старого стану для скасування
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Позначення як скасованого
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

// UpdateCoins продовжується нормально (автоматично пропускає виходи OP_RETURN)
```

**Реалізація:** `src/validation.cpp:ConnectBlock()`

### Перевірка володіння

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Перевірка, що принаймні один вхід підписаний власником плоту
    for (const auto& input : tx.vin) {
        auto coin = view.GetCoin(input.prevout);
        if (!coin.has_value()) continue;

        // Check if P2WPKH witness program matches plot address
        int wit_version;
        std::vector<unsigned char> wit_program;
        if (!coin->out.scriptPubKey.IsWitnessProgram(wit_version, wit_program)) continue;
        if (wit_version != 0 || wit_program.size() != 20) continue;

        if (std::equal(wit_program.begin(), wit_program.end(),
                      plotAddress.begin())) {
            return true;  // Bitcoin Core already validated signature
        }
    }
    return false;
}
```

**Реалізація:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Затримки активації

Призначення та скасування мають настроювані затримки активації для запобігання атак реорганізації:

```cpp
// Параметри консенсусу (настроювані для кожної мережі)
// Приклад: 30 блоків = ~1 година з 2-хвилинним часом блоку
consensus.nForgingAssignmentDelay;   // Затримка активації призначення
consensus.nForgingRevocationDelay;   // Затримка активації скасування
```

**Переходи стану:**
- Призначення: `UNASSIGNED → ASSIGNING (затримка) → ASSIGNED`
- Скасування: `ASSIGNED → REVOKING (затримка) → REVOKED`

**Реалізація:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Валідація mempool

Транзакції призначень та скасувань валідуються при прийнятті в mempool для відхилення невалідних транзакцій до розповсюдження в мережі.

### Перевірки рівня транзакції (CheckTransaction)

Виконуються в `src/consensus/tx_check.cpp` без доступу до стану ланцюга:

1. **Максимум один POCX OP_RETURN:** Транзакція не може містити кілька маркерів POCX/XCOP

**Реалізація:** `src/consensus/tx_check.cpp`

### Перевірки прийняття в mempool (PreChecks)

Виконуються в `src/validation.cpp` з повним доступом до стану ланцюга та mempool:

#### Валідація призначення

1. **Володіння плотом:** Транзакція повинна бути підписана власником плоту
2. **Стан плоту:** Плот повинен бути UNASSIGNED (0) або REVOKED (4)
3. **Конфлікти mempool:** Немає іншого призначення для цього плоту в mempool (виграє перший побачений)

#### Валідація скасування

1. **Володіння плотом:** Транзакція повинна бути підписана власником плоту
2. **Активне призначення:** Плот повинен бути лише в стані ASSIGNED (2)
3. **Конфлікти mempool:** Немає іншого скасування для цього плоту в mempool

**Реалізація:** `src/validation.cpp:PreChecks()`

### Потік валідації

```
Трансляція транзакції
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Максимум один POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Перевірка володіння плотом
  ✓ Перевірка стану призначення
  ✓ Перевірка конфліктів mempool
       ↓
   Валідно → Прийняття в mempool
   Невалідно → Відхилення (не розповсюджувати)
       ↓
Майнінг блоку
       ↓
ConnectBlock() [validation.cpp]
  ✓ Повторна валідація всіх перевірок (глибина захисту)
  ✓ Застосування змін стану
  ✓ Запис інформації скасування
```

### Глибина захисту

Усі перевірки валідації mempool повторно виконуються під час `ConnectBlock()` для захисту від:
- Атак обходу mempool
- Невалідних блоків від зловмисних майнерів
- Крайніх випадків під час сценаріїв реорганізації

Валідація блоку залишається авторитетною для консенсусу.

## Атомарні оновлення бази даних

### Трирівнева архітектура

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Кеш пам'яті)         │  ← Зміни призначень відстежуються в пам'яті
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Відстеження dirty: dirtyPlots      │
│   - Видалення: deletedAssignments       │
│   - Відстеження пам'яті: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Рівень бази даних)      │  ← Один атомарний запис
│   - BatchWrite(): UTXO + Assignments    │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Дискове сховище)             │  ← ACID гарантії
│   - Атомарна транзакція                 │
└─────────────────────────────────────────┘
```

### Процес Flush

Коли `view.Flush()` викликається під час підключення блоку:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Запис змін coins до бази
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Атомарний запис змін призначень
    if (fOk && !dirtyPlots.empty()) {
        // Збір dirty призначень
        ForgingAssignmentsMap assignmentsToWrite;
        DeletedAssignmentsSet deletedToWrite;

        // Collect dirty assignments

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    auto key = std::make_pair(plotAddr, assignment.assignment_txid);
                    assignmentsToWrite[key] = assignment;
                }
            }
        }

        // Запис до бази даних
        // Merge deleted assignments into assignmentsToWrite (needed for height lookup)
        // and build deletedToWrite set (plain key pairs)
        for (const auto& [key, assignment] : deletedAssignments) {
            assignmentsToWrite[key] = assignment;  // Provide assignment data for height
            deletedToWrite.insert(key);             // Mark for deletion
        }

        fOk = base->BatchWriteAssignments(assignmentsToWrite, deletedToWrite);
    }

    if (fOk) {
        cacheCoins.clear();
        ReallocateCache();
        pendingAssignments.clear();
        deletedAssignments.clear();
        dirtyPlots.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Реалізація:** `src/coins.cpp:Flush()`

### Пакетний запис бази даних

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Один пакет LevelDB

    // 1. Позначення стану переходу
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Запис усіх змін coins
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Позначення консистентного стану
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. АТОМАРНИЙ КОМІТ
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Призначення записуються окремо, але в тому ж контексті транзакції бази даних
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const DeletedAssignmentsSet& deletedAssignments)  // set of (plot_addr, txid) pairs
{
    CDBBatch batch(*m_db);

    // Write all assignment history entries
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, assignment.assignment_height, txid), assignment);
    }

    // Erase deleted assignments — look up height from assignments map
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        auto it = assignments.find({plot_addr, txid});
        if (it != assignments.end()) {
            batch.Erase(AssignmentHistoryKey(plot_addr, it->second.assignment_height, txid));
        }
    }

    // ATOMIC COMMIT
    return m_db->WriteBatch(batch);
}
```

**Реалізація:** `src/txdb.cpp:BatchWriteAssignments()`

### Гарантії атомарності

✅ **Що атомарне:**
- Усі зміни coins в межах блоку записуються атомарно
- Усі зміни призначень в межах блоку записуються атомарно
- База даних залишається консистентною при збоях

⚠️ **Поточне обмеження:**
- Coins та призначення записуються в **окремих** пакетних операціях LevelDB
- Обидві операції відбуваються під час `view.Flush()`, але не в одному атомарному записі
- На практиці: Обидва пакети завершуються швидко до fsync диска
- Ризик мінімальний: Обидва потребували б відтворення з того ж блоку під час відновлення після збою

**Примітка:** Це відрізняється від оригінального плану архітектури, який передбачав один уніфікований пакет. Поточна реалізація використовує два пакети, але підтримує консистентність через існуючі механізми відновлення після збоїв Bitcoin Core (маркер DB_HEAD_BLOCKS).

## Обробка реорганізацій

### Структура даних скасування

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Призначення було додано (видалити при скасуванні)
        MODIFIED = 1,   // Призначення було змінено (відновити при скасуванні)
        REVOKED = 2     // Призначення було скасовано (скасувати скасування при undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Повний стан до зміни
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Дані скасування UTXO
    std::vector<ForgingUndo> vforgingundo;  // Дані скасування призначень
};
```

**Реалізація:** `src/undo.h`

### Процес DisconnectBlock

Коли блок від'єднується під час реорганізації:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... стандартне від'єднання UTXO ...

    // Читання даних скасування з диска
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Скасування змін призначень (обробка у зворотному порядку)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Призначення було додано - видалити його
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Призначення було скасовано - відновити нескасований стан
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Призначення було змінено - відновити попередній стан
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Реалізація:** `src/validation.cpp:DisconnectBlock()`

### Управління кешем під час реорганізації

```cpp
class CCoinsViewCache {
private:
    // Кеші призначень
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Відстеження змінених плотів
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Відстеження видалень
    mutable size_t cachedAssignmentsUsage{0};  // Відстеження пам'яті

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments[key] = assignment;
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
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }
};
```

**Реалізація:** `src/coins.cpp`

## Інтерфейс RPC

### Команди вузла (без гаманця)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Повертає поточний статус призначення для адреси плоту:
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

**Реалізація:** `src/pocx/rpc/assignments.cpp`

### Команди гаманця (потрібен гаманець)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Створює транзакцію призначення:
- Автоматично вибирає найбільший UTXO з адреси плоту для доведення володіння
- Будує транзакцію з OP_RETURN + вихід решти
- Підписує ключем власника плоту
- Транслює в мережу

**Реалізація:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Створює транзакцію скасування:
- Автоматично вибирає найбільший UTXO з адреси плоту для доведення володіння
- Будує транзакцію з OP_RETURN + вихід решти
- Підписує ключем власника плоту
- Транслює в мережу

**Реалізація:** `src/pocx/rpc/assignments_wallet.cpp`

### Створення транзакцій гаманцем

Процес створення транзакції гаманцем:

```cpp
1. Парсинг та валідація адрес (повинні бути P2WPKH bech32)
2. Пошук найбільшого UTXO з адреси плоту (доводить володіння)
3. Створення тимчасової транзакції з фіктивним виходом
4. Підпис транзакції (отримання точного розміру з даними witness)
5. Заміна фіктивного виходу на OP_RETURN
6. Пропорційне коригування комісій на основі зміни розміру
7. Повторний підпис фінальної транзакції
8. Трансляція в мережу
```

**Ключове розуміння:** Гаманець повинен витратити з адреси плоту для доведення володіння, тому він автоматично примушує вибір coins з цієї адреси.

**Реалізація:** `src/pocx/assignments/transactions.cpp`

## Структура файлів

### Основні файли реалізації

```
src/
├── coins.h                        # Структура ForgingAssignment, методи CCoinsViewCache [710 рядків]
├── coins.cpp                      # Управління кешем, пакетні записи [603 рядки]
│
├── txdb.h                         # Методи CCoinsViewDB для призначень [90 рядків]
├── txdb.cpp                       # Читання/запис бази даних [349 рядків]
│
├── undo.h                         # Структура ForgingUndo для реорганізацій
│
├── validation.cpp                 # Інтеграція ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Формат OP_RETURN, парсинг, верифікація
    │   ├── opcodes.cpp            # [259 рядків] Визначення маркерів, операції OP_RETURN, перевірка володіння
    │   ├── assignment_state.h     # Хелпери GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Функції запиту стану призначення
    │   ├── transactions.h         # API створення транзакцій гаманця
    │   └── transactions.cpp       # Функції гаманця create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Команди RPC вузла (без гаманця)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Команди RPC гаманця
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Характеристики продуктивності

### Операції бази даних

- **Отримання поточного призначення:** O(n) - сканування всіх призначень для адреси плоту для пошуку найновішого
- **Отримання історії призначень:** O(n) - ітерація всіх призначень для плоту
- **Створення призначення:** O(1) - одна вставка
- **Скасування призначення:** O(1) - одне оновлення
- **Реорганізація (на призначення):** O(1) - пряме застосування даних скасування

Де n = кількість призначень для плоту (зазвичай мала, < 10)

### Використання пам'яті

- **На призначення:** ~160 байтів (структура ForgingAssignment)
- **Накладні витрати кешу:** Накладні витрати хеш-карти для dirty відстеження
- **Типовий блок:** <10 призначень = <2 KB пам'яті

### Використання диска

- **На призначення:** ~200 байтів на диску (з накладними витратами LevelDB)
- **10000 призначень:** ~2 MB дискового простору
- **Незначно порівняно з набором UTXO:** <0.001% типового chainstate

## Поточні обмеження та майбутня робота

### Обмеження атомарності

**Поточний стан:** Coins та призначення записуються в окремих пакетах LevelDB під час `view.Flush()`

**Вплив:** Теоретичний ризик неконсистентності якщо збій відбудеться між пакетами

**Пом'якшення:**
- Обидва пакети завершуються швидко до fsync
- Відновлення після збоїв Bitcoin Core використовує маркер DB_HEAD_BLOCKS
- На практиці: Ніколи не спостерігалося в тестуванні

**Майбутнє покращення:** Об'єднання в одну операцію пакету LevelDB

### Обрізання історії призначень

**Поточний стан:** Усі призначення зберігаються необмежено

**Вплив:** ~200 байтів на призначення назавжди

**Майбутнє:** Опціональне обрізання повністю скасованих призначень старших за N блоків

**Примітка:** Малоймовірно, що знадобиться - навіть 1 мільйон призначень = 200 MB

## Статус тестування

### Реалізовані тести

✅ Парсинг та валідація OP_RETURN
✅ Верифікація володіння
✅ Створення призначення ConnectBlock
✅ Скасування ConnectBlock
✅ Обробка реорганізації DisconnectBlock
✅ Операції читання/запису бази даних
✅ Переходи стану (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ Команди RPC (get_assignment, create_assignment, revoke_assignment)
✅ Створення транзакцій гаманцем

### Області покриття тестами

- Модульні тести: `src/test/pocx_*_tests.cpp`
- Функціональні тести: `test/functional/feature_pocx_*.py`
- Інтеграційні тести: Ручне тестування з regtest

## Правила консенсусу

### Правила створення призначення

1. **Володіння:** Транзакція повинна бути підписана власником плоту
2. **Стан:** Плот повинен бути в стані UNASSIGNED або REVOKED
3. **Формат:** Валідний OP_RETURN з маркером POCX + 2x 20-байтові адреси
4. **Унікальність:** Одне активне призначення на плот за раз

### Правила скасування

1. **Володіння:** Транзакція повинна бути підписана власником плоту
2. **Існування:** Призначення повинно існувати і ще не бути скасованим
3. **Формат:** Валідний OP_RETURN з маркером XCOP + 20-байтова адреса

### Правила активації

- **Активація призначення:** `assignment_height + nForgingAssignmentDelay`
- **Активація скасування:** `revocation_height + nForgingRevocationDelay`
- **Затримки:** Настроювані для кожної мережі (напр., 30 блоків = ~1 година з 2-хвилинним часом блоку)

### Валідація блоку

- Невалідне призначення/скасування → блок відхилено (провал консенсусу)
- Виходи OP_RETURN автоматично виключаються з набору UTXO (стандартна поведінка Bitcoin)
- Обробка призначень відбувається до оновлень UTXO в ConnectBlock

## Висновок

Система призначення кування PoCX як реалізована забезпечує:

✅ **Простота:** Стандартні транзакції Bitcoin, без спеціальних UTXO
✅ **Економічність:** Без вимоги dust, тільки комісії транзакцій
✅ **Безпека реорганізацій:** Комплексні дані скасування відновлюють правильний стан
✅ **Атомарні оновлення:** Консистентність бази даних через пакети LevelDB
✅ **Повна історія:** Повний аудиторський слід усіх призначень з часом
✅ **Чиста архітектура:** Мінімальні модифікації Bitcoin Core, ізольований код PoCX
✅ **Готовність до продакшену:** Повністю реалізовано, протестовано та функціонує

### Якість реалізації

- **Організація коду:** Відмінна - чітке розділення між Bitcoin Core та PoCX
- **Обробка помилок:** Комплексна валідація консенсусу
- **Документація:** Код добре прокоментований та структурований
- **Тестування:** Основна функціональність протестована, інтеграція перевірена

### Валідовані ключові проектні рішення

1. ✅ Підхід тільки на OP_RETURN (vs на основі UTXO)
2. ✅ Окреме зберігання в базі даних (vs Coin extraData)
3. ✅ Повне відстеження історії (vs тільки поточний стан)
4. ✅ Володіння через підпис (vs витрачання UTXO)
5. ✅ Затримки активації (запобігають атакам реорганізації)

Система успішно досягає всіх архітектурних цілей з чистою, підтримуваною реалізацією.

---

[← Назад: Консенсус і майнінг](3-consensus-and-mining.md) | [📘 Зміст](index.md) | [Далі: Синхронізація часу →](5-timing-security.md)

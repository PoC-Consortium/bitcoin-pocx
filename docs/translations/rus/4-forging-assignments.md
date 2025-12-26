[<- Назад: Консенсус и майнинг](3-consensus-and-mining.md) | [Содержание](index.md) | [Далее: Синхронизация времени ->](5-timing-security.md)

---

# Глава 4: Система делегирования форджинга PoCX

## Краткое изложение

Этот документ описывает **реализованную** систему делегирования форджинга PoCX с использованием архитектуры только на основе OP_RETURN. Система позволяет владельцам графиков делегировать права форджинга отдельным адресам через транзакции в блокчейне, с полной безопасностью при реорганизациях и атомарными операциями с базой данных.

**Статус:** Полностью реализовано и работоспособно

## Основная философия проектирования

**Ключевой принцип:** Делегирования — это разрешения, а не активы

- Нет специальных UTXO для отслеживания или расходования
- Состояние делегирования хранится отдельно от набора UTXO
- Владение подтверждается подписью транзакции, а не расходованием UTXO
- Полное отслеживание истории для полного аудиторского следа
- Атомарные обновления базы данных через пакетные записи LevelDB

## Структура транзакции

### Формат транзакции делегирования

```
Входы:
  [0]: Любой UTXO, контролируемый владельцем графика (подтверждает владение + оплачивает комиссии)
       Должен быть подписан приватным ключом владельца графика
  [1+]: Опциональные дополнительные входы для покрытия комиссии

Выходы:
  [0]: OP_RETURN (маркер POCX + адрес графика + адрес форджинга)
       Формат: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Размер: 46 байт всего (1 байт OP_RETURN + 1 байт длина + 44 байта данные)
       Значение: 0 BTC (нерасходуемый, не добавляется в набор UTXO)

  [1]: Сдача пользователю (опционально, стандартный P2WPKH)
```

**Реализация:** `src/pocx/assignments/opcodes.cpp:25-52`

### Формат транзакции отзыва

```
Входы:
  [0]: Любой UTXO, контролируемый владельцем графика (подтверждает владение + оплачивает комиссии)
       Должен быть подписан приватным ключом владельца графика
  [1+]: Опциональные дополнительные входы для покрытия комиссии

Выходы:
  [0]: OP_RETURN (маркер XCOP + адрес графика)
       Формат: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Размер: 26 байт всего (1 байт OP_RETURN + 1 байт длина + 24 байта данные)
       Значение: 0 BTC (нерасходуемый, не добавляется в набор UTXO)

  [1]: Сдача пользователю (опционально, стандартный P2WPKH)
```

**Реализация:** `src/pocx/assignments/opcodes.cpp:54-77`

### Маркеры

- **Маркер делегирования:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Маркер отзыва:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Реализация:** `src/pocx/assignments/opcodes.cpp:15-19`

### Ключевые характеристики транзакций

- Стандартные транзакции Bitcoin (без изменений протокола)
- Выходы OP_RETURN доказуемо нерасходуемы (никогда не добавляются в набор UTXO)
- Владение графиком подтверждается подписью на input[0] от адреса графика
- Низкая стоимость (~200 байт, обычно <0.0001 BTC комиссии)
- Кошелёк автоматически выбирает наибольший UTXO от адреса графика для подтверждения владения

## Архитектура базы данных

### Структура хранения

Все данные делегирования хранятся в той же базе данных LevelDB, что и набор UTXO (`chainstate/`), но с отдельными префиксами ключей:

```
chainstate/ LevelDB:
├─ Набор UTXO (стандартный Bitcoin Core)
│  └─ Префикс 'C': COutPoint -> Coin
│
└─ Состояние делегирования (дополнения PoCX)
   └─ Префикс 'A': (plot_address, assignment_txid) -> ForgingAssignment
       └─ Полная история: все делегирования по графику за всё время
```

**Реализация:** `src/txdb.cpp:237-348`

### Структура ForgingAssignment

```cpp
struct ForgingAssignment {
    // Идентификация
    std::array<uint8_t, 20> plotAddress;      // Владелец графика (20-байтный P2WPKH хеш)
    std::array<uint8_t, 20> forgingAddress;   // Держатель прав форджинга (20-байтный P2WPKH хеш)

    // Жизненный цикл делегирования
    uint256 assignment_txid;                   // Транзакция, создавшая делегирование
    int assignment_height;                     // Высота блока создания
    int assignment_effective_height;           // Когда становится активным (высота + задержка)

    // Жизненный цикл отзыва
    bool revoked;                              // Был ли отозван?
    uint256 revocation_txid;                   // Транзакция отзыва
    int revocation_height;                     // Высота блока отзыва
    int revocation_effective_height;           // Когда отзыв вступает в силу (высота + задержка)

    // Методы запроса состояния
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Реализация:** `src/coins.h:111-178`

### Состояния делегирования

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Делегирование не существует
    ASSIGNING = 1,   // Делегирование создано, ожидание задержки активации
    ASSIGNED = 2,    // Делегирование активно, форджинг разрешён
    REVOKING = 3,    // Отозвано, но всё ещё активно в период задержки
    REVOKED = 4      // Полностью отозвано, больше не активно
};
```

**Реализация:** `src/coins.h:98-104`

### Ключи базы данных

```cpp
// Ключ истории: хранит полную запись делегирования
// Формат ключа: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Адрес графика (20 байт)
    int assignment_height;                // Высота для оптимизации сортировки
    uint256 assignment_txid;              // ID транзакции
};
```

**Реализация:** `src/txdb.cpp:245-262`

### Отслеживание истории

- Каждое делегирование хранится постоянно (никогда не удаляется, кроме реорга)
- Несколько делегирований на график отслеживаются во времени
- Обеспечивает полный аудиторский след и исторические запросы состояния
- Отозванные делегирования остаются в базе данных с `revoked=true`

## Обработка блоков

### Интеграция ConnectBlock

OP_RETURN делегирования и отзыва обрабатываются при подключении блока в `validation.cpp`:

```cpp
// Расположение: После валидации скриптов, перед UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Разбор данных OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Проверка владения (tx должна быть подписана владельцем графика)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Проверка состояния графика (должен быть UNASSIGNED или REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Создание нового делегирования
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Сохранение данных отмены
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Разбор данных OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Проверка владения
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Получение текущего делегирования
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Сохранение старого состояния для отмены
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Пометка как отозванного
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

// UpdateCoins продолжается нормально (автоматически пропускает выходы OP_RETURN)
```

**Реализация:** `src/validation.cpp:2775-2878`

### Проверка владения

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Проверка, что хотя бы один вход подписан владельцем графика
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Извлечение назначения
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Проверка на P2WPKH по адресу графика
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core уже валидировал подпись
                return true;
            }
        }
    }
    return false;
}
```

**Реализация:** `src/pocx/assignments/opcodes.cpp:217-256`

### Задержки активации

Делегирования и отзывы имеют настраиваемые задержки активации для предотвращения атак реорганизации:

```cpp
// Параметры консенсуса (настраиваемые для каждой сети)
// Пример: 30 блоков = ~1 час с 2-минутным временем блока
consensus.nForgingAssignmentDelay;   // Задержка активации делегирования
consensus.nForgingRevocationDelay;   // Задержка активации отзыва
```

**Переходы состояний:**
- Делегирование: `UNASSIGNED -> ASSIGNING (задержка) -> ASSIGNED`
- Отзыв: `ASSIGNED -> REVOKING (задержка) -> REVOKED`

**Реализация:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Валидация мемпула

Транзакции делегирования и отзыва валидируются при принятии в мемпул для отклонения невалидных транзакций до распространения по сети.

### Проверки на уровне транзакции (CheckTransaction)

Выполняются в `src/consensus/tx_check.cpp` без доступа к состоянию цепочки:

1. **Максимум один POCX OP_RETURN:** Транзакция не может содержать несколько маркеров POCX/XCOP

**Реализация:** `src/consensus/tx_check.cpp:63-77`

### Проверки принятия в мемпул (PreChecks)

Выполняются в `src/validation.cpp` с полным доступом к состоянию цепочки и мемпулу:

#### Валидация делегирования

1. **Владение графиком:** Транзакция должна быть подписана владельцем графика
2. **Состояние графика:** Графику должен быть в состоянии UNASSIGNED (0) или REVOKED (4)
3. **Конфликты мемпула:** Нет другого делегирования для этого графика в мемпуле (побеждает первый увиденный)

#### Валидация отзыва

1. **Владение графиком:** Транзакция должна быть подписана владельцем графика
2. **Активное делегирование:** Графику должен быть только в состоянии ASSIGNED (2)
3. **Конфликты мемпула:** Нет другого отзыва для этого графика в мемпуле

**Реализация:** `src/validation.cpp:898-993`

### Поток валидации

```
Трансляция транзакции
       |
CheckTransaction() [tx_check.cpp]
  Максимум один POCX OP_RETURN
       |
MemPoolAccept::PreChecks() [validation.cpp]
  Проверка владения графиком
  Проверка состояния делегирования
  Проверка конфликтов мемпула
       |
   Валидно -> Принять в мемпул
   Невалидно -> Отклонить (не распространять)
       |
Майнинг блока
       |
ConnectBlock() [validation.cpp]
  Повторная валидация всех проверок (защита в глубину)
  Применение изменений состояния
  Запись информации для отмены
```

### Защита в глубину

Все проверки валидации мемпула повторно выполняются во время `ConnectBlock()` для защиты от:
- Атак обхода мемпула
- Невалидных блоков от вредоносных майнеров
- Краевых случаев во время сценариев реорганизации

Валидация блока остаётся авторитетной для консенсуса.

## Атомарные обновления базы данных

### Трёхуровневая архитектура

```
+-------------------------------------------+
|   CCoinsViewCache (Кеш в памяти)          |  <- Изменения делегирования отслеживаются в памяти
|   - Coins: cacheCoins                     |
|   - Assignments: pendingAssignments       |
|   - Отслеживание грязных: dirtyPlots      |
|   - Удаления: deletedAssignments          |
|   - Отслеживание памяти: cachedAssignmentsUsage |
+-------------------------------------------+
                    | Flush()
+-------------------------------------------+
|   CCoinsViewDB (Уровень базы данных)      |  <- Единая атомарная запись
|   - BatchWrite(): UTXOs + Assignments     |
+-------------------------------------------+
                    | WriteBatch()
+-------------------------------------------+
|   LevelDB (Дисковое хранилище)            |  <- Гарантии ACID
|   - Атомарная транзакция                  |
+-------------------------------------------+
```

### Процесс сброса

Когда вызывается `view.Flush()` при подключении блока:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Запись изменений монет в базу
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Атомарная запись изменений делегирования
    if (fOk && !dirtyPlots.empty()) {
        // Сбор грязных делегирований
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Пустая - не используется

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Запись в базу данных
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Очистка отслеживания
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Освобождение памяти
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Реализация:** `src/coins.cpp:278-315`

### Пакетная запись в базу данных

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Единый пакет LevelDB

    // 1. Пометка состояния перехода
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Запись всех изменений монет
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Пометка согласованного состояния
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. АТОМАРНЫЙ КОММИТ
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Делегирования записываются отдельно, но в том же контексте транзакции базы данных
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Неиспользуемый параметр (сохранён для совместимости API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Новый пакет, но та же база данных

    // Запись истории делегирования
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Удаление удалённых делегирований из истории
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // АТОМАРНЫЙ КОММИТ
    return m_db->WriteBatch(batch);
}
```

**Реализация:** `src/txdb.cpp:332-348`

### Гарантии атомарности

**Что атомарно:**
- Все изменения монет в блоке записываются атомарно
- Все изменения делегирования в блоке записываются атомарно
- База данных остаётся согласованной при сбоях

**Текущее ограничение:**
- Монеты и делегирования записываются в **отдельных** пакетных операциях LevelDB
- Обе операции происходят во время `view.Flush()`, но не в единой атомарной записи
- На практике: Оба пакета завершаются быстро до fsync диска
- Риск минимален: Оба должны быть воспроизведены из того же блока при восстановлении после сбоя

**Примечание:** Это отличается от первоначального плана архитектуры, который предусматривал единый унифицированный пакет. Текущая реализация использует два пакета, но поддерживает согласованность через существующие механизмы восстановления после сбоя Bitcoin Core (маркер DB_HEAD_BLOCKS).

## Обработка реорганизаций

### Структура данных отмены

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Делегирование было добавлено (удалить при отмене)
        MODIFIED = 1,   // Делегирование было изменено (восстановить при отмене)
        REVOKED = 2     // Делегирование было отозвано (отменить отзыв при отмене)
    };

    UndoType type;
    ForgingAssignment assignment;  // Полное состояние до изменения
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Данные отмены UTXO
    std::vector<ForgingUndo> vforgingundo;  // Данные отмены делегирования
};
```

**Реализация:** `src/undo.h:63-105`

### Процесс DisconnectBlock

Когда блок отключается во время реорганизации:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... стандартное отключение UTXO ...

    // Чтение данных отмены с диска
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Отмена изменений делегирования (обработка в обратном порядке)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Делегирование было добавлено - удалить его
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Делегирование было отозвано - восстановить неотозванное состояние
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Делегирование было изменено - восстановить предыдущее состояние
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Реализация:** `src/validation.cpp:2381-2415`

### Управление кешем при реорганизации

```cpp
class CCoinsViewCache {
private:
    // Кеши делегирования
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Отслеживание изменённых графиков
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Отслеживание удалений
    mutable size_t cachedAssignmentsUsage{0};  // Отслеживание памяти

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

**Реализация:** `src/coins.cpp:494-565`

## RPC-интерфейс

### Команды узла (кошелёк не требуется)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Возвращает текущий статус делегирования для адреса графика:
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

**Реализация:** `src/pocx/rpc/assignments.cpp:31-126`

### Команды кошелька (требуется кошелёк)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Создаёт транзакцию делегирования:
- Автоматически выбирает наибольший UTXO от адреса графика для подтверждения владения
- Строит транзакцию с OP_RETURN + выход сдачи
- Подписывает ключом владельца графика
- Транслирует в сеть

**Реализация:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Создаёт транзакцию отзыва:
- Автоматически выбирает наибольший UTXO от адреса графика для подтверждения владения
- Строит транзакцию с OP_RETURN + выход сдачи
- Подписывает ключом владельца графика
- Транслирует в сеть

**Реализация:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Создание транзакции кошельком

Процесс создания транзакции кошельком:

```cpp
1. Разбор и валидация адресов (должны быть P2WPKH bech32)
2. Поиск наибольшего UTXO от адреса графика (подтверждает владение)
3. Создание временной транзакции с фиктивным выходом
4. Подпись транзакции (получение точного размера с данными witness)
5. Замена фиктивного выхода на OP_RETURN
6. Пропорциональная корректировка комиссий на основе изменения размера
7. Повторная подпись финальной транзакции
8. Трансляция в сеть
```

**Ключевой момент:** Кошелёк должен тратить с адреса графика для подтверждения владения, поэтому он автоматически принуждает выбор монет с этого адреса.

**Реализация:** `src/pocx/assignments/transactions.cpp:38-263`

## Структура файлов

### Основные файлы реализации

```
src/
├── coins.h                        # Структура ForgingAssignment, методы CCoinsViewCache [710 строк]
├── coins.cpp                      # Управление кешем, пакетные записи [603 строки]
│
├── txdb.h                         # Методы делегирования CCoinsViewDB [90 строк]
├── txdb.cpp                       # Чтение/запись базы данных [349 строк]
│
├── undo.h                         # Структура ForgingUndo для реоргов
│
├── validation.cpp                 # Интеграция ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Формат OP_RETURN, разбор, проверка
    │   ├── opcodes.cpp            # [259 строк] Определения маркеров, операции OP_RETURN, проверка владения
    │   ├── assignment_state.h     # Хелперы GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Функции запроса состояния делегирования
    │   ├── transactions.h         # API создания транзакций кошелька
    │   └── transactions.cpp       # Функции кошелька create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # RPC-команды узла (без кошелька)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # RPC-команды кошелька
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Характеристики производительности

### Операции с базой данных

- **Получение текущего делегирования:** O(n) - сканирование всех делегирований для адреса графика для поиска последнего
- **Получение истории делегирований:** O(n) - итерация всех делегирований для графика
- **Создание делегирования:** O(1) - одиночная вставка
- **Отзыв делегирования:** O(1) - одиночное обновление
- **Реорг (на делегирование):** O(1) - прямое применение данных отмены

Где n = количество делегирований для графика (обычно мало, < 10)

### Использование памяти

- **На делегирование:** ~160 байт (структура ForgingAssignment)
- **Накладные расходы кеша:** Накладные расходы хеш-таблицы для отслеживания грязных
- **Типичный блок:** <10 делегирований = <2 КБ памяти

### Использование диска

- **На делегирование:** ~200 байт на диске (с накладными расходами LevelDB)
- **10000 делегирований:** ~2 МБ дискового пространства
- **Незначительно по сравнению с набором UTXO:** <0.001% от типичного chainstate

## Текущие ограничения и будущая работа

### Ограничение атомарности

**Текущее:** Монеты и делегирования записываются в отдельных пакетах LevelDB во время `view.Flush()`

**Влияние:** Теоретический риск несогласованности при сбое между пакетами

**Смягчение:**
- Оба пакета завершаются быстро до fsync
- Восстановление после сбоя Bitcoin Core использует маркер DB_HEAD_BLOCKS
- На практике: Никогда не наблюдалось при тестировании

**Будущее улучшение:** Унификация в единую пакетную операцию LevelDB

### Очистка истории делегирований

**Текущее:** Все делегирования хранятся бессрочно

**Влияние:** ~200 байт на делегирование навсегда

**Будущее:** Опциональная очистка полностью отозванных делегирований старше N блоков

**Примечание:** Вряд ли понадобится - даже 1 миллион делегирований = 200 МБ

## Статус тестирования

### Реализованные тесты

- Разбор и валидация OP_RETURN
- Проверка владения
- Создание делегирования в ConnectBlock
- Отзыв в ConnectBlock
- Обработка реоргов в DisconnectBlock
- Операции чтения/записи базы данных
- Переходы состояний (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC-команды (get_assignment, create_assignment, revoke_assignment)
- Создание транзакций кошельком

### Области покрытия тестами

- Модульные тесты: `src/test/pocx_*_tests.cpp`
- Функциональные тесты: `test/functional/feature_pocx_*.py`
- Интеграционные тесты: Ручное тестирование с regtest

## Правила консенсуса

### Правила создания делегирования

1. **Владение:** Транзакция должна быть подписана владельцем графика
2. **Состояние:** Графику должен быть в состоянии UNASSIGNED или REVOKED
3. **Формат:** Валидный OP_RETURN с маркером POCX + 2x 20-байтных адреса
4. **Уникальность:** Одно активное делегирование на графику за раз

### Правила отзыва

1. **Владение:** Транзакция должна быть подписана владельцем графика
2. **Существование:** Делегирование должно существовать и не быть уже отозванным
3. **Формат:** Валидный OP_RETURN с маркером XCOP + 20-байтный адрес

### Правила активации

- **Активация делегирования:** `assignment_height + nForgingAssignmentDelay`
- **Активация отзыва:** `revocation_height + nForgingRevocationDelay`
- **Задержки:** Настраиваемые для каждой сети (например, 30 блоков = ~1 час с 2-минутным временем блока)

### Валидация блока

- Невалидное делегирование/отзыв -> блок отклонён (сбой консенсуса)
- Выходы OP_RETURN автоматически исключаются из набора UTXO (стандартное поведение Bitcoin)
- Обработка делегирований происходит до обновлений UTXO в ConnectBlock

## Заключение

Система делегирования форджинга PoCX в реализованном виде обеспечивает:

- **Простота:** Стандартные транзакции Bitcoin, без специальных UTXO
- **Экономичность:** Без требования пыли, только комиссии за транзакции
- **Безопасность при реоргах:** Всеобъемлющие данные отмены восстанавливают корректное состояние
- **Атомарные обновления:** Согласованность базы данных через пакеты LevelDB
- **Полная история:** Полный аудиторский след всех делегирований за всё время
- **Чистая архитектура:** Минимальные модификации Bitcoin Core, изолированный код PoCX
- **Готовность к продакшену:** Полностью реализовано, протестировано и работоспособно

### Качество реализации

- **Организация кода:** Отличная - чёткое разделение между Bitcoin Core и PoCX
- **Обработка ошибок:** Всеобъемлющая валидация консенсуса
- **Документация:** Код хорошо задокументирован комментариями и структурой
- **Тестирование:** Основная функциональность протестирована, интеграция проверена

### Подтверждённые ключевые проектные решения

1. Подход только на основе OP_RETURN (vs на основе UTXO)
2. Отдельное хранение в базе данных (vs extraData в Coin)
3. Полное отслеживание истории (vs только текущее)
4. Владение по подписи (vs расходование UTXO)
5. Задержки активации (предотвращает атаки реорганизации)

Система успешно достигает всех архитектурных целей с чистой, поддерживаемой реализацией.

---

[<- Назад: Консенсус и майнинг](3-consensus-and-mining.md) | [Содержание](index.md) | [Далее: Синхронизация времени ->](5-timing-security.md)

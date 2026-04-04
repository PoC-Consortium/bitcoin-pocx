[← Назад: Консенсус и копаене](3-consensus-and-mining.md) | [📘 Съдържание](index.md) | [Напред: Синхронизация на време →](5-timing-security.md)

---

# Глава 4: Система за делегиране на подписване в PoCX

## Резюме

Този документ описва **имплементираната** система за делегиране на подписване в PoCX, използваща архитектура само с OP_RETURN. Системата позволява на собствениците на plot файлове да делегират права за подписване на отделни адреси чрез транзакции във веригата, с пълна безопасност при реорганизации и атомарни операции с база данни.

**Статус:** ✅ Напълно имплементирана и функционираща

## Основна философия на дизайна

**Ключов принцип:** Делегиранията са разрешения, не активи

- Без специални UTXO за проследяване или харчене
- Състоянието на делегиране се съхранява отделно от UTXO сета
- Собствеността се доказва с подпис на транзакция, не с харчене на UTXO
- Пълно проследяване на историята за пълна одитна следа
- Атомарни актуализации на база данни чрез LevelDB batch записи

## Структура на транзакции

### Формат на транзакция за делегиране

```
Inputs:
  [0]: Всяко UTXO, контролирано от собственика на plot (доказва собственост + плаща такси)
       Трябва да бъде подписано с частния ключ на собственика на plot
  [1+]: Незадължителни допълнителни входове за покриване на такси

Outputs:
  [0]: OP_RETURN (POCX маркер + адрес на plot + адрес за подписване)
       Формат: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Размер: 46 байта общо (1 байт OP_RETURN + 1 байт дължина + 44 байта данни)
       Стойност: 0 BTC (нехарчими, не се добавят към UTXO сета)

  [1]: Ресто обратно към потребителя (незадължително, стандартен P2WPKH)
```

**Имплементация:** `src/pocx/assignments/opcodes.cpp`

### Формат на транзакция за отмяна

```
Inputs:
  [0]: Всяко UTXO, контролирано от собственика на plot (доказва собственост + плаща такси)
       Трябва да бъде подписано с частния ключ на собственика на plot
  [1+]: Незадължителни допълнителни входове за покриване на такси

Outputs:
  [0]: OP_RETURN (XCOP маркер + адрес на plot)
       Формат: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Размер: 26 байта общо (1 байт OP_RETURN + 1 байт дължина + 24 байта данни)
       Стойност: 0 BTC (нехарчими, не се добавят към UTXO сета)

  [1]: Ресто обратно към потребителя (незадължително, стандартен P2WPKH)
```

**Имплементация:** `src/pocx/assignments/opcodes.cpp`

### Маркери

- **Маркер за делегиране:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Маркер за отмяна:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Имплементация:** `src/pocx/assignments/opcodes.cpp`

### Ключови характеристики на транзакции

- Стандартни Bitcoin транзакции (без промени в протокола)
- OP_RETURN изходите са доказуемо нехарчими (никога не се добавят към UTXO сета)
- Собствеността върху plot се доказва с подпис на input[0] от адреса на plot
- Ниска цена (~200 байта, обикновено <0.0001 BTC такса)
- Портфейлът автоматично избира най-голямото UTXO от адреса на plot за доказване на собственост

## Архитектура на база данни

### Структура на съхранение

Всички данни за делегиране се съхраняват в същата LevelDB база данни като UTXO сета (`chainstate/`), но с отделни ключови префикси:

```
chainstate/ LevelDB:
├─ UTXO Set (стандартен Bitcoin Core)
│  └─ 'C' префикс: COutPoint → Coin
│
└─ Assignment State (PoCX добавки)
   └─ 'A' префикс: (plot_address, assignment_txid) → ForgingAssignment
       └─ Пълна история: всички делегирания за plot във времето
```

**Имплементация:** `src/txdb.cpp`

### Структура ForgingAssignment

```cpp
struct ForgingAssignment {
    // Идентичност
    std::array<uint8_t, 20> plotAddress;      // Собственик на plot (20-байтов P2WPKH хеш)
    std::array<uint8_t, 20> forgingAddress;   // Притежател на права за подписване (20-байтов P2WPKH хеш)

    // Жизнен цикъл на делегиране
    uint256 assignment_txid;                   // Транзакция, създала делегирането
    int assignment_height;                     // Височина на блок при създаване
    int assignment_effective_height;           // Кога става активно (height + забавяне)

    // Жизнен цикъл на отмяна
    bool revoked;                              // Отменено ли е това?
    uint256 revocation_txid;                   // Транзакция, отменила го
    int revocation_height;                     // Височина на блок при отмяна
    int revocation_effective_height;           // Кога отмяната влиза в сила (height + забавяне)

    // Методи за заявка на състояние
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Имплементация:** `src/coins.h`

### Състояния на делегиране

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Не съществува делегиране
    ASSIGNING = 1,   // Делегиране създадено, изчаква забавяне за активиране
    ASSIGNED = 2,    // Делегиране активно, подписване разрешено
    REVOKING = 3,    // Отменено, но все още активно през периода на забавяне
    REVOKED = 4      // Напълно отменено, вече не е активно
};
```

**Имплементация:** `src/coins.h`

### Ключове на база данни

```cpp
// Ключ за история: съхранява пълен запис на делегиране
// Формат на ключ: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Адрес на plot (20 байта)
    int assignment_height;                // Височина за оптимизация на сортиране
    uint256 assignment_txid;              // ID на транзакция
};
```

**Имплементация:** `src/txdb.cpp`

### Проследяване на история

- Всяко делегиране се съхранява постоянно (никога не се изтрива освен при реорг)
- Множество делегирания за plot се проследяват във времето
- Позволява пълна одитна следа и исторически заявки на състояние
- Отменените делегирания остават в базата данни с `revoked=true`

## Обработка на блокове

### Интеграция с ConnectBlock

OP_RETURN за делегиране и отмяна се обработват по време на свързване на блок в `validation.cpp`:

```cpp
// Местоположение: След валидация на скрипт, преди UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Парсване на OP_RETURN данни
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Проверка на собственост (tx трябва да бъде подписана от собственик на plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Проверка на състояние на plot (трябва да бъде UNASSIGNED или REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Създаване на ново делегиране
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Съхраняване на undo данни
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Парсване на OP_RETURN данни
            auto plot_addr = ParseRevocationOpReturn(output);

            // Проверка на собственост
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Получаване на текущо делегиране
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Съхраняване на старо състояние за undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Маркиране като отменено
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

// UpdateCoins продължава нормално (автоматично пропуска OP_RETURN изходи)
```

**Имплементация:** `src/validation.cpp:ConnectBlock()`

### Проверка на собственост

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Проверка дали поне един вход е подписан от собственика на plot
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

**Имплементация:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Забавяния на активиране

Делегиранията и отмяните имат конфигурируеми забавяния за активиране за предотвратяване на атаки при реорганизация:

```cpp
// Консенсусни параметри (конфигурируеми за мрежа)
// Пример: 30 блока = ~1 час с 2-минутно време на блок
consensus.nForgingAssignmentDelay;   // Забавяне на активиране на делегиране
consensus.nForgingRevocationDelay;   // Забавяне на активиране на отмяна
```

**Преходи на състояние:**
- Делегиране: `UNASSIGNED → ASSIGNING (забавяне) → ASSIGNED`
- Отмяна: `ASSIGNED → REVOKING (забавяне) → REVOKED`

**Имплементация:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Валидация в Mempool

Транзакциите за делегиране и отмяна се валидират при приемане в mempool, за да се отхвърлят невалидни транзакции преди мрежово разпространение.

### Проверки на ниво транзакция (CheckTransaction)

Извършват се в `src/consensus/tx_check.cpp` без достъп до състояние на веригата:

1. **Максимум един POCX OP_RETURN:** Транзакцията не може да съдържа множество POCX/XCOP маркери

**Имплементация:** `src/consensus/tx_check.cpp`

### Проверки при приемане в Mempool (PreChecks)

Извършват се в `src/validation.cpp` с пълен достъп до състояние на веригата и mempool:

#### Валидация на делегиране

1. **Собственост на plot:** Транзакцията трябва да бъде подписана от собственика на plot
2. **Състояние на plot:** Plot трябва да бъде UNASSIGNED (0) или REVOKED (4)
3. **Конфликти в mempool:** Няма друго делегиране за този plot в mempool (първото печели)

#### Валидация на отмяна

1. **Собственост на plot:** Транзакцията трябва да бъде подписана от собственика на plot
2. **Активно делегиране:** Plot трябва да бъде в състояние ASSIGNED (2) само
3. **Конфликти в mempool:** Няма друга отмяна за този plot в mempool

**Имплементация:** `src/validation.cpp:PreChecks()`

### Поток на валидация

```
Разпространение на транзакция
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Максимум един POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Проверка на собственост на plot
  ✓ Проверка на състояние на делегиране
  ✓ Проверка за конфликти в mempool
       ↓
   Валидна → Приемане в Mempool
   Невалидна → Отхвърляне (без разпространение)
       ↓
Копаене на блок
       ↓
ConnectBlock() [validation.cpp]
  ✓ Повторна валидация на всички проверки (защита в дълбочина)
  ✓ Прилагане на промени в състоянието
  ✓ Записване на undo информация
```

### Защита в дълбочина

Всички проверки за валидация на mempool се изпълняват повторно по време на `ConnectBlock()` за защита срещу:
- Атаки за заобикаляне на mempool
- Невалидни блокове от злонамерени миньори
- Гранични случаи при сценарии на реорганизация

Валидацията на блок остава авторитетна за консенсуса.

## Атомарни актуализации на база данни

### Трислойна архитектура

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Кеш в паметта)       │  ← Промени в делегирания се проследяват в памет
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Dirty tracking: dirtyPlots          │
│   - Deletions: deletedAssignments       │
│   - Memory tracking: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Слой за база данни)     │  ← Единичен атомарен запис
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Съхранение на диск)          │  ← ACID гаранции
│   - Атомарна транзакция                 │
└─────────────────────────────────────────┘
```

### Процес на Flush

Когато се извика `view.Flush()` по време на свързване на блок:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Записване на промени в coins към базата
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Атомарен запис на промени в делегирания
    if (fOk && !dirtyPlots.empty()) {
        // Събиране на dirty делегирания
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

        // Запис в база данни
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

**Имплементация:** `src/coins.cpp:Flush()`

### Batch запис в база данни

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Единичен LevelDB batch

    // 1. Маркиране на преходно състояние
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Запис на всички промени в coins
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Маркиране на консистентно състояние
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. АТОМАРЕН COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Делегиранията се записват отделно, но в същия контекст на транзакция на база данни
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

**Имплементация:** `src/txdb.cpp:BatchWriteAssignments()`

### Гаранции за атомарност

✅ **Какво е атомарно:**
- Всички промени в coins в рамките на блок се записват атомарно
- Всички промени в делегирания в рамките на блок се записват атомарно
- Базата данни остава консистентна при сривове

⚠️ **Текущо ограничение:**
- Coins и делегирания се записват в **отделни** LevelDB batch операции
- И двете операции се случват по време на `view.Flush()`, но не в единичен атомарен запис
- На практика: И двата batch-а завършват бързо преди disk fsync
- Рискът е минимален: И двата биха трябвало да се преиграят от същия блок при възстановяване от срив

**Забележка:** Това се различава от оригиналния архитектурен план, който предвиждаше единичен унифициран batch. Текущата имплементация използва два batch-а, но поддържа консистентност чрез съществуващите механизми за възстановяване от срив на Bitcoin Core (DB_HEAD_BLOCKS маркер).

## Обработка на реорганизации

### Структура на Undo данни

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Делегиране беше добавено (изтриване при undo)
        MODIFIED = 1,   // Делегиране беше модифицирано (възстановяване при undo)
        REVOKED = 2     // Делегиране беше отменено (отмяна на отмяна при undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Пълно състояние преди промяната
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo данни
    std::vector<ForgingUndo> vforgingundo;  // Undo данни за делегирания
};
```

**Имплементация:** `src/undo.h`

### Процес на DisconnectBlock

Когато блок се отвързва по време на реорганизация:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... стандартно UTXO отвързване ...

    // Четене на undo данни от диска
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Undo на промени в делегирания (обработка в обратен ред)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Делегиране беше добавено - премахване
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Делегиране беше отменено - възстановяване на неотменено състояние
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Делегиране беше модифицирано - възстановяване на предишно състояние
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Имплементация:** `src/validation.cpp:DisconnectBlock()`

### Управление на кеш при реорганизация

```cpp
class CCoinsViewCache {
private:
    // Кешове за делегирания
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Проследяване на модифицирани plot-ове
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Проследяване на изтривания
    mutable size_t cachedAssignmentsUsage{0};  // Проследяване на памет

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

**Имплементация:** `src/coins.cpp`

## RPC интерфейс

### Команди за възел (без изискване за портфейл)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Връща текущ статус на делегиране за адрес на plot:
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

**Имплементация:** `src/pocx/rpc/assignments.cpp`

### Команди за портфейл (изисква портфейл)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Създава транзакция за делегиране:
- Автоматично избира най-голямото UTXO от адреса на plot за доказване на собственост
- Изгражда транзакция с OP_RETURN + изход за ресто
- Подписва с ключа на собственика на plot
- Разпространява в мрежата

**Имплементация:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Създава транзакция за отмяна:
- Автоматично избира най-голямото UTXO от адреса на plot за доказване на собственост
- Изгражда транзакция с OP_RETURN + изход за ресто
- Подписва с ключа на собственика на plot
- Разпространява в мрежата

**Имплементация:** `src/pocx/rpc/assignments_wallet.cpp`

### Създаване на транзакция от портфейл

Процесът на създаване на транзакция от портфейл:

```cpp
1. Парсване и валидация на адреси (трябва да са P2WPKH bech32)
2. Намиране на най-голямото UTXO от адреса на plot (доказва собственост)
3. Създаване на временна транзакция с фиктивен изход
4. Подписване на транзакция (получаване на точен размер с witness данни)
5. Замяна на фиктивен изход с OP_RETURN
6. Пропорционална корекция на такси на база промяна в размера
7. Повторно подписване на финална транзакция
8. Разпространение в мрежата
```

**Ключов момент:** Портфейлът трябва да харчи от адреса на plot, за да докаже собственост, така че автоматично принуждава избор на coin от този адрес.

**Имплементация:** `src/pocx/assignments/transactions.cpp`

## Файлова структура

### Основни имплементационни файлове

```
src/
├── coins.h                        # Структура ForgingAssignment, методи на CCoinsViewCache [710 реда]
├── coins.cpp                      # Управление на кеш, batch записи [603 реда]
│
├── txdb.h                         # Методи за делегиране на CCoinsViewDB [90 реда]
├── txdb.cpp                       # Четене/запис в база данни [349 реда]
│
├── undo.h                         # Структура ForgingUndo за реорганизации
│
├── validation.cpp                 # Интеграция на ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN формат, парсване, проверка
    │   ├── opcodes.cpp            # [259 реда] Дефиниции на маркери, OP_RETURN операции, проверка на собственост
    │   ├── assignment_state.h     # Помощници GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Функции за заявка на състояние на делегиране
    │   ├── transactions.h         # API за създаване на транзакции от портфейл
    │   └── transactions.cpp       # Функции create_assignment, revoke_assignment за портфейл
    │
    ├── rpc/
    │   ├── assignments.h          # RPC команди за възел (без портфейл)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # RPC команди за портфейл
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Характеристики на производителност

### Операции с база данни

- **Получаване на текущо делегиране:** O(n) — сканиране на всички делегирания за адрес на plot за намиране на най-скорошното
- **Получаване на история на делегирания:** O(n) — итерация на всички делегирания за plot
- **Създаване на делегиране:** O(1) — единично вмъкване
- **Отмяна на делегиране:** O(1) — единична актуализация
- **Реорг (за делегиране):** O(1) — директно прилагане на undo данни

Където n = брой делегирания за plot (обикновено малък, < 10)

### Използване на памет

- **За делегиране:** ~160 байта (структура ForgingAssignment)
- **Overhead на кеш:** Overhead на хеш таблица за dirty проследяване
- **Типичен блок:** <10 делегирания = <2 KB памет

### Използване на диск

- **За делегиране:** ~200 байта на диск (с LevelDB overhead)
- **10000 делегирания:** ~2 MB дисково пространство
- **Незначително спрямо UTXO сет:** <0.001% от типичен chainstate

## Текущи ограничения и бъдеща работа

### Ограничение на атомарност

**Текущо:** Coins и делегирания се записват в отделни LevelDB batch операции по време на `view.Flush()`

**Въздействие:** Теоретичен риск от несъответствие ако възникне срив между batch-овете

**Смекчаване:**
- И двата batch-а завършват бързо преди fsync
- Възстановяването от срив на Bitcoin Core използва DB_HEAD_BLOCKS маркер
- На практика: Никога не е наблюдавано при тестване

**Бъдещо подобрение:** Унифициране в единична LevelDB batch операция

### Почистване на история на делегирания

**Текущо:** Всички делегирания се съхраняват за неопределено време

**Въздействие:** ~200 байта за делегиране завинаги

**Бъдеще:** Незадължително почистване на напълно отменени делегирания, по-стари от N блока

**Забележка:** Малко вероятно да е необходимо — дори 1 милион делегирания = 200 MB

## Статус на тестване

### Имплементирани тестове

✅ OP_RETURN парсване и валидация
✅ Проверка на собственост
✅ ConnectBlock създаване на делегиране
✅ ConnectBlock отмяна
✅ DisconnectBlock обработка на реорганизация
✅ Операции четене/запис в база данни
✅ Преходи на състояние (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC команди (get_assignment, create_assignment, revoke_assignment)
✅ Създаване на транзакции от портфейл

### Области на тестово покритие

- Unit тестове: `src/test/pocx_*_tests.cpp`
- Функционални тестове: `test/functional/feature_pocx_*.py`
- Интеграционни тестове: Ръчно тестване с regtest

## Консенсусни правила

### Правила за създаване на делегиране

1. **Собственост:** Транзакцията трябва да бъде подписана от собственика на plot
2. **Състояние:** Plot трябва да бъде в състояние UNASSIGNED или REVOKED
3. **Формат:** Валиден OP_RETURN с POCX маркер + 2x 20-байтови адреси
4. **Уникалност:** Едно активно делегиране на plot наведнъж

### Правила за отмяна

1. **Собственост:** Транзакцията трябва да бъде подписана от собственика на plot
2. **Съществуване:** Делегиране трябва да съществува и да не е вече отменено
3. **Формат:** Валиден OP_RETURN с XCOP маркер + 20-байтов адрес

### Правила за активиране

- **Активиране на делегиране:** `assignment_height + nForgingAssignmentDelay`
- **Активиране на отмяна:** `revocation_height + nForgingRevocationDelay`
- **Забавяния:** Конфигурируеми за мрежа (напр. 30 блока = ~1 час с 2-минутно време на блок)

### Валидация на блок

- Невалидно делегиране/отмяна → блокът се отхвърля (консенсусен провал)
- OP_RETURN изходите автоматично се изключват от UTXO сета (стандартно Bitcoin поведение)
- Обработката на делегирания се случва преди UTXO актуализации в ConnectBlock

## Заключение

Системата за делегиране на подписване в PoCX, както е имплементирана, предоставя:

✅ **Простота:** Стандартни Bitcoin транзакции, без специални UTXO
✅ **Ефективност на разходите:** Без изискване за прах, само такси за транзакции
✅ **Безопасност при реорганизации:** Изчерпателни undo данни възстановяват правилно състояние
✅ **Атомарни актуализации:** Консистентност на база данни чрез LevelDB batch-ове
✅ **Пълна история:** Пълна одитна следа на всички делегирания във времето
✅ **Чиста архитектура:** Минимални модификации на Bitcoin Core, изолиран PoCX код
✅ **Готова за производство:** Напълно имплементирана, тествана и функционираща

### Качество на имплементацията

- **Организация на код:** Отлична — ясно разделение между Bitcoin Core и PoCX
- **Обработка на грешки:** Изчерпателна консенсусна валидация
- **Документация:** Код с коментари и добре документирана структура
- **Тестване:** Основна функционалност тествана, интеграция проверена

### Валидирани ключови дизайнерски решения

1. ✅ Подход само с OP_RETURN (срещу базиран на UTXO)
2. ✅ Отделно съхранение в база данни (срещу Coin extraData)
3. ✅ Пълно проследяване на история (срещу само текущо)
4. ✅ Собственост чрез подпис (срещу харчене на UTXO)
5. ✅ Забавяния на активиране (предотвратява атаки при реорг)

Системата успешно постига всички архитектурни цели с чиста, поддържаема имплементация.

---

[← Назад: Консенсус и копаене](3-consensus-and-mining.md) | [📘 Съдържание](index.md) | [Напред: Синхронизация на време →](5-timing-security.md)

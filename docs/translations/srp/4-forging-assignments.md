[← Претходно: Консензус и рударење](3-consensus-and-mining.md) | [📘 Садржај](index.md) | [Следеће: Синхронизација времена →](5-timing-security.md)

---

# Поглавље 4: PoCX систем додељивања ковања

## Извршни резиме

Овај документ описује **имплементирани** PoCX систем додељивања ковања који користи архитектуру искључиво на OP_RETURN. Систем омогућава власницима плотова да делегирају права ковања одвојеним адресама кроз трансакције на ланцу, са пуном безбедношћу реорганизације и атомским операцијама базе података.

**Статус:** ✅ Потпуно имплементирано и оперативно

## Основна филозофија дизајна

**Кључни принцип:** Додељивања су дозволе, не средства

- Нема специјалних UTXO-а за праћење или трошење
- Стање додељивања складиштено одвојено од UTXO скупа
- Власништво доказано потписом трансакције, не трошењем UTXO-а
- Комплетно праћење историје за потпуну ревизијску траг
- Атомска ажурирања базе података кроз LevelDB групне записе

## Структура трансакције

### Формат трансакције додељивања

```
Улази:
  [0]: Било који UTXO контролисан од власника плота (доказује власништво + плаћа накнаде)
       Мора бити потписан приватним кључем власника плота
  [1+]: Опциони додатни улази за покриће накнаде

Излази:
  [0]: OP_RETURN (POCX маркер + адреса плота + адреса ковања)
       Формат: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Величина: укупно 46 бајтова (1 бајт OP_RETURN + 1 бајт дужина + 44 бајта подаци)
       Вредност: 0 BTC (није потрошиво, не додаје се у UTXO скуп)

  [1]: Кусур назад кориснику (опционо, стандардни P2WPKH)
```

**Имплементација:** `src/pocx/assignments/opcodes.cpp`

### Формат трансакције опозива

```
Улази:
  [0]: Било који UTXO контролисан од власника плота (доказује власништво + плаћа накнаде)
       Мора бити потписан приватним кључем власника плота
  [1+]: Опциони додатни улази за покриће накнаде

Излази:
  [0]: OP_RETURN (XCOP маркер + адреса плота)
       Формат: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Величина: укупно 26 бајтова (1 бајт OP_RETURN + 1 бајт дужина + 24 бајта подаци)
       Вредност: 0 BTC (није потрошиво, не додаје се у UTXO скуп)

  [1]: Кусур назад кориснику (опционо, стандардни P2WPKH)
```

**Имплементација:** `src/pocx/assignments/opcodes.cpp`

### Маркери

- **Маркер додељивања:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Маркер опозива:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Имплементација:** `src/pocx/assignments/opcodes.cpp`

### Кључне карактеристике трансакција

- Стандардне Bitcoin трансакције (без промена протокола)
- OP_RETURN излази су доказиво непотрошиви (никада се не додају у UTXO скуп)
- Власништво над плотом доказано потписом на input[0] од адресе плота
- Ниска цена (~200 бајтова, типично <0.0001 BTC накнада)
- Новчаник аутоматски бира највећи UTXO од адресе плота да докаже власништво

## Архитектура базе података

### Структура складиштења

Сви подаци о додељивањима се чувају у истој LevelDB бази података као UTXO скуп (`chainstate/`), али са одвојеним префиксима кључева:

```
chainstate/ LevelDB:
├─ UTXO скуп (Bitcoin Core стандард)
│  └─ 'C' префикс: COutPoint → Coin
│
└─ Стање додељивања (PoCX додаци)
   └─ 'A' префикс: (plot_address, assignment_txid) → ForgingAssignment
       └─ Комплетна историја: сва додељивања по плоту током времена
```

**Имплементација:** `src/txdb.cpp`

### Структура ForgingAssignment

```cpp
struct ForgingAssignment {
    // Идентитет
    std::array<uint8_t, 20> plotAddress;      // Власник плота (20-бајтни P2WPKH хеш)
    std::array<uint8_t, 20> forgingAddress;   // Носилац права ковања (20-бајтни P2WPKH хеш)

    // Животни циклус додељивања
    uint256 assignment_txid;                   // Трансакција која је креирала додељивање
    int assignment_height;                     // Висина блока креирања
    int assignment_effective_height;           // Када постаје активно (height + delay)

    // Животни циклус опозива
    bool revoked;                              // Да ли је ово опозвано?
    uint256 revocation_txid;                   // Трансакција која је опозвала
    int revocation_height;                     // Висина блока опозива
    int revocation_effective_height;           // Када опозив постаје ефективан (height + delay)

    // Методе упита стања
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Имплементација:** `src/coins.h`

### Стања додељивања

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Нема додељивања
    ASSIGNING = 1,   // Додељивање креирано, чека кашњење активације
    ASSIGNED = 2,    // Додељивање активно, ковање дозвољено
    REVOKING = 3,    // Опозвано, али још увек активно током периода кашњења
    REVOKED = 4      // Потпуно опозвано, више није активно
};
```

**Имплементација:** `src/coins.h`

### Кључеви базе података

```cpp
// Кључ историје: чува комплетан запис додељивања
// Формат кључа: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Адреса плота (20 бајтова)
    int assignment_height;                // Висина за оптимизацију сортирања
    uint256 assignment_txid;              // ID трансакције
};
```

**Имплементација:** `src/txdb.cpp`

### Праћење историје

- Свако додељивање трајно складиштено (никада се не брише осим реорга)
- Више додељивања по плоту праћено током времена
- Омогућава потпуну ревизијску траг и упите историјског стања
- Опозвана додељивања остају у бази података са `revoked=true`

## Обрада блока

### ConnectBlock интеграција

OP_RETURN-ови додељивања и опозива се обрађују током повезивања блока у `validation.cpp`:

```cpp
// Локација: После валидације скрипте, пре UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Парсирај OP_RETURN податке
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Верификуј власништво (tx мора бити потписан од власника плота)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Провери стање плота (мора бити UNASSIGNED или REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Креирај ново додељивање
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Складишти податке за поништавање
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Парсирај OP_RETURN податке
            auto plot_addr = ParseRevocationOpReturn(output);

            // Верификуј власништво
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Добави тренутно додељивање
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Складишти старо стање за поништавање
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Означи као опозвано
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

// UpdateCoins наставља нормално (аутоматски прескаче OP_RETURN излазе)
```

**Имплементација:** `src/validation.cpp:ConnectBlock()`

### Верификација власништва

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Провери да је барем један улаз потписан од власника плота
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

**Имплементација:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### Кашњења активације

Додељивања и опозиви имају подесива кашњења активације да би спречили нападе реорганизације:

```cpp
// Параметри консензуса (подесиви по мрежи)
// Пример: 30 блокова = ~1 сат са 2-минутним временом блока
consensus.nForgingAssignmentDelay;   // Кашњење активације додељивања
consensus.nForgingRevocationDelay;   // Кашњење активације опозива
```

**Прелази стања:**
- Додељивање: `UNASSIGNED → ASSIGNING (кашњење) → ASSIGNED`
- Опозив: `ASSIGNED → REVOKING (кашњење) → REVOKED`

**Имплементација:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Валидација mempool-а

Трансакције додељивања и опозива се валидирају при прихватању у mempool да би се одбиле неважеће трансакције пре мрежног ширења.

### Провере на нивоу трансакције (CheckTransaction)

Изведене у `src/consensus/tx_check.cpp` без приступа стању ланца:

1. **Максимум један POCX OP_RETURN:** Трансакција не може садржати више POCX/XCOP маркера

**Имплементација:** `src/consensus/tx_check.cpp`

### Провере прихватања у mempool (PreChecks)

Изведене у `src/validation.cpp` са потпуним приступом стању ланца и mempool-а:

#### Валидација додељивања

1. **Власништво над плотом:** Трансакција мора бити потписана од власника плота
2. **Стање плота:** Плот мора бити UNASSIGNED (0) или REVOKED (4)
3. **Конфликти у mempool-у:** Нема другог додељивања за овај плот у mempool-у (први виђен побеђује)

#### Валидација опозива

1. **Власништво над плотом:** Трансакција мора бити потписана од власника плота
2. **Активно додељивање:** Плот мора бити само у ASSIGNED (2) стању
3. **Конфликти у mempool-у:** Нема другог опозива за овај плот у mempool-у

**Имплементација:** `src/validation.cpp:PreChecks()`

### Ток валидације

```
Емитовање трансакције
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Максимум један POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Верификуј власништво над плотом
  ✓ Провери стање додељивања
  ✓ Провери конфликте у mempool-у
       ↓
   Важеће → Прихвати у mempool
   Неважеће → Одбиј (не шири)
       ↓
Рударење блока
       ↓
ConnectBlock() [validation.cpp]
  ✓ Поново валидирај све провере (дубинска одбрана)
  ✓ Примени промене стања
  ✓ Забележи информације за поништавање
```

### Дубинска одбрана

Све провере валидације mempool-а се поново извршавају током `ConnectBlock()` за заштиту од:
- Напада заобилажења mempool-а
- Неважећих блокова од злонамерних рудара
- Граничних случајева током сценарија реорганизације

Валидација блока остаје ауторитативна за консензус.

## Атомска ажурирања базе података

### Трослојна архитектура

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (меморијски кеш)      │  ← Промене додељивања праћене у меморији
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Праћење измена: dirtyPlots          │
│   - Брисања: deletedAssignments         │
│   - Праћење меморије: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (слој базе података)     │  ← Један атомски запис
│   - BatchWrite(): UTXO + додељивања     │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (дисковно складиштење)        │  ← ACID гаранције
│   - Атомска трансакција                 │
└─────────────────────────────────────────┘
```

### Процес испирања

Када се позове `view.Flush()` током повезивања блока:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Упиши промене монета у базу
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Упиши промене додељивања атомски
    if (fOk && !dirtyPlots.empty()) {
        // Прикупи измењена додељивања
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

        // Упиши у базу података
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

**Имплементација:** `src/coins.cpp:Flush()`

### Групни запис базе података

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Једна LevelDB група

    // 1. Означи прелазно стање
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Упиши све промене монета
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Означи конзистентно стање
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. АТОМСКИ КОМИТ
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Додељивања се уписују одвојено али у истом контексту трансакције базе података
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

**Имплементација:** `src/txdb.cpp:BatchWriteAssignments()`

### Гаранције атомичности

✅ **Шта је атомско:**
- Све промене монета унутар блока се уписују атомски
- Све промене додељивања унутар блока се уписују атомски
- База података остаје конзистентна преко падова

⚠️ **Тренутно ограничење:**
- Монете и додељивања се уписују у **одвојеним** LevelDB групним операцијама
- Обе операције се дешавају током `view.Flush()`, али не у једном атомском запису
- У пракси: Обе групе се завршавају брзо пре fsync диска
- Ризик је минималан: Обе би требало поново покренути из истог блока током опоравка од пада

**Напомена:** Ово се разликује од оригиналног плана архитектуре који је захтевао једну унификовану групу. Тренутна имплементација користи две групе али одржава конзистентност кроз постојеће Bitcoin Core механизме опоравка од пада (DB_HEAD_BLOCKS маркер).

## Руковање реорганизацијом

### Структура података за поништавање

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Додељивање је додато (обриши при поништавању)
        MODIFIED = 1,   // Додељивање је модификовано (врати при поништавању)
        REVOKED = 2     // Додељивање је опозвано (поништи опозив при поништавању)
    };

    UndoType type;
    ForgingAssignment assignment;  // Пуно стање пре промене
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO подаци за поништавање
    std::vector<ForgingUndo> vforgingundo;  // Подаци за поништавање додељивања
};
```

**Имплементација:** `src/undo.h`

### Процес DisconnectBlock

Када се блок искључује током реорга:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... стандардно искључивање UTXO ...

    // Прочитај податке за поништавање са диска
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Поништи промене додељивања (обради обрнутим редоследом)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Додељивање је додато - уклони га
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Додељивање је опозвано - врати неопозвано стање
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Додељивање је модификовано - врати претходно стање
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Имплементација:** `src/validation.cpp:DisconnectBlock()`

### Управљање кешом током реорга

```cpp
class CCoinsViewCache {
private:
    // Кешеви додељивања
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Прати модификоване плотове
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // Прати брисања
    mutable size_t cachedAssignmentsUsage{0};  // Праћење меморије

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

**Имплементација:** `src/coins.cpp`

## RPC интерфејс

### Команде чвора (није потребан новчаник)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Враћа тренутни статус додељивања за адресу плота:
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

**Имплементација:** `src/pocx/rpc/assignments.cpp`

### Команде новчаника (потребан новчаник)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Креира трансакцију додељивања:
- Аутоматски бира највећи UTXO од адресе плота да докаже власништво
- Гради трансакцију са OP_RETURN + излазом за кусур
- Потписује кључем власника плота
- Емитује на мрежу

**Имплементација:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Креира трансакцију опозива:
- Аутоматски бира највећи UTXO од адресе плота да докаже власништво
- Гради трансакцију са OP_RETURN + излазом за кусур
- Потписује кључем власника плота
- Емитује на мрежу

**Имплементација:** `src/pocx/rpc/assignments_wallet.cpp`

### Креирање трансакције новчаника

Процес креирања трансакције новчаника:

```cpp
1. Парсирај и валидирај адресе (морају бити P2WPKH bech32)
2. Пронађи највећи UTXO од адресе плота (доказује власништво)
3. Креирај привремену трансакцију са dummy излазом
4. Потпиши трансакцију (добиј тачну величину са witness подацима)
5. Замени dummy излаз са OP_RETURN
6. Подеси накнаде пропорционално на основу промене величине
7. Поново потпиши финалну трансакцију
8. Емитуј на мрежу
```

**Кључни увид:** Новчаник мора потрошити од адресе плота да докаже власништво, тако да аутоматски форсира селекцију монета од те адресе.

**Имплементација:** `src/pocx/assignments/transactions.cpp`

## Структура датотека

### Основне датотеке имплементације

```
src/
├── coins.h                        # ForgingAssignment структура, CCoinsViewCache методе [710 линија]
├── coins.cpp                      # Управљање кешом, групни записи [603 линије]
│
├── txdb.h                         # CCoinsViewDB методе додељивања [90 линија]
├── txdb.cpp                       # Читање/писање базе података [349 линија]
│
├── undo.h                         # ForgingUndo структура за реорге
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock интеграција
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN формат, парсирање, верификација
    │   ├── opcodes.cpp            # [259 линија] Дефиниције маркера, OP_RETURN операције, провера власништва
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState помоћници
    │   ├── assignment_state.cpp   # Функције упита стања додељивања
    │   ├── transactions.h         # API за креирање трансакција новчаника
    │   └── transactions.cpp       # create_assignment, revoke_assignment функције новчаника
    │
    ├── rpc/
    │   ├── assignments.h          # RPC команде чвора (без новчаника)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # RPC команде новчаника
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC-ови
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Карактеристике перформанси

### Операције базе података

- **Добави тренутно додељивање:** O(n) - скенирај сва додељивања за адресу плота да пронађеш најновије
- **Добави историју додељивања:** O(n) - итерирај сва додељивања за плот
- **Креирај додељивање:** O(1) - један унос
- **Опозови додељивање:** O(1) - једно ажурирање
- **Реорг (по додељивању):** O(1) - директна примена података за поништавање

Где је n = број додељивања за плот (типично мали, < 10)

### Употреба меморије

- **По додељивању:** ~160 бајтова (ForgingAssignment структура)
- **Overhead кеша:** Overhead хеш мапе за праћење измена
- **Типичан блок:** <10 додељивања = <2 KB меморије

### Употреба диска

- **По додељивању:** ~200 бајтова на диску (са LevelDB overhead-ом)
- **10000 додељивања:** ~2 MB простора на диску
- **Занемарљиво у поређењу са UTXO скупом:** <0.001% типичног chainstate-а

## Тренутна ограничења и будући рад

### Ограничење атомичности

**Тренутно:** Монете и додељивања се уписују у одвојеним LevelDB групама током `view.Flush()`

**Утицај:** Теоријски ризик неконзистентности ако дође до пада између група

**Ублажење:**
- Обе групе се завршавају брзо пре fsync
- Bitcoin Core опоравак од пада користи DB_HEAD_BLOCKS маркер
- У пракси: Никада примећено током тестирања

**Будуће побољшање:** Уједини у једну LevelDB групну операцију

### Чишћење историје додељивања

**Тренутно:** Сва додељивања трајно складиштена

**Утицај:** ~200 бајтова по додељивању заувек

**Будуће:** Опционо чишћење потпуно опозваних додељивања старијих од N блокова

**Напомена:** Мало вероватно да ће бити потребно - чак и 1 милион додељивања = 200 MB

## Статус тестирања

### Имплементирани тестови

✅ OP_RETURN парсирање и валидација
✅ Верификација власништва
✅ ConnectBlock креирање додељивања
✅ ConnectBlock опозив
✅ DisconnectBlock руковање реоргом
✅ Операције читања/писања базе података
✅ Прелази стања (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC команде (get_assignment, create_assignment, revoke_assignment)
✅ Креирање трансакција новчаника

### Области покривености тестова

- Јединични тестови: `src/test/pocx_*_tests.cpp`
- Функционални тестови: `test/functional/feature_pocx_*.py`
- Интеграциони тестови: Ручно тестирање са regtest

## Правила консензуса

### Правила креирања додељивања

1. **Власништво:** Трансакција мора бити потписана од власника плота
2. **Стање:** Плот мора бити у UNASSIGNED или REVOKED стању
3. **Формат:** Важећи OP_RETURN са POCX маркером + 2x 20-бајтне адресе
4. **Јединственост:** Једно активно додељивање по плоту истовремено

### Правила опозива

1. **Власништво:** Трансакција мора бити потписана од власника плота
2. **Постојање:** Додељивање мора постојати и не сме већ бити опозвано
3. **Формат:** Важећи OP_RETURN са XCOP маркером + 20-бајтна адреса

### Правила активације

- **Активација додељивања:** `assignment_height + nForgingAssignmentDelay`
- **Активација опозива:** `revocation_height + nForgingRevocationDelay`
- **Кашњења:** Подесива по мрежи (нпр. 30 блокова = ~1 сат са 2-минутним временом блока)

### Валидација блока

- Неважеће додељивање/опозив → блок одбијен (неуспех консензуса)
- OP_RETURN излази аутоматски искључени из UTXO скупа (стандардно Bitcoin понашање)
- Обрада додељивања се дешава пре ажурирања UTXO у ConnectBlock

## Закључак

PoCX систем додељивања ковања како је имплементиран обезбеђује:

✅ **Једноставност:** Стандардне Bitcoin трансакције, без специјалних UTXO-а
✅ **Исплативост:** Без захтева за прашину, само накнаде за трансакцију
✅ **Безбедност реорга:** Свеобухватни подаци за поништавање враћају тачно стање
✅ **Атомска ажурирања:** Конзистентност базе података кроз LevelDB групе
✅ **Комплетна историја:** Потпуна ревизијска траг свих додељивања током времена
✅ **Чиста архитектура:** Минималне модификације Bitcoin Core, изолован PoCX код
✅ **Спремно за продукцију:** Потпуно имплементирано, тестирано и оперативно

### Квалитет имплементације

- **Организација кода:** Одлична - чисто раздвајање између Bitcoin Core и PoCX
- **Руковање грешкама:** Свеобухватна валидација консензуса
- **Документација:** Коментари кода и структура добро документовани
- **Тестирање:** Основна функционалност тестирана, интеграција верификована

### Валидиране кључне дизајнерске одлуке

1. ✅ Приступ искључиво на OP_RETURN (у односу на заснован на UTXO)
2. ✅ Одвојено складиштење у бази података (у односу на Coin extraData)
3. ✅ Праћење комплетне историје (у односу на само тренутно)
4. ✅ Власништво путем потписа (у односу на трошење UTXO-а)
5. ✅ Кашњења активације (спречава нападе реорганизације)

Систем успешно постиже све архитектонске циљеве са чистом, одрживом имплементацијом.

---

[← Претходно: Консензус и рударење](3-consensus-and-mining.md) | [📘 Садржај](index.md) | [Следеће: Синхронизација времена →](5-timing-security.md)

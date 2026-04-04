[← Назад: Параметри мережі](6-network-parameters.md) | [📘 Зміст](index.md) | [Далі: Посібник з гаманця →](8-wallet-guide.md)

---

# Розділ 7: Довідник інтерфейсу RPC

Повний довідник команд RPC Bitcoin-PoCX, включаючи RPC майнінгу, управління призначеннями та модифіковані RPC блокчейну.

---

## Зміст

1. [Конфігурація](#конфігурація)
2. [RPC майнінгу PoCX](#rpc-майнінгу-pocx)
3. [RPC призначень](#rpc-призначень)
4. [Модифіковані RPC блокчейну](#модифіковані-rpc-блокчейну)
5. [Вимкнені RPC](#вимкнені-rpc)
6. [Приклади інтеграції](#приклади-інтеграції)

---

## Конфігурація

### Режим сервера майнінгу

**Прапорець**: ``

**Призначення**: Вмикає RPC-доступ для зовнішніх майнерів для виклику специфічних для майнінгу RPC

**Вимоги**:
- Потрібен для функціонування `submit_nonce`
- Потрібен для видимості діалогу призначення кування в Qt гаманці

**Використання**:
```bash
# Командний рядок
./bitcoind

# bitcoin.conf
```

**Міркування безпеки**:
- Без додаткової автентифікації окрім стандартних облікових даних RPC
- RPC майнінгу обмежені за частотою ємністю черги
- Стандартна автентифікація RPC все ще потрібна

**Реалізація**: `src/pocx/rpc/mining.cpp`

---

## RPC майнінгу PoCX

### get_mining_info

**Категорія**: mining
**Потрібен сервер майнінгу**: Ні
**Потрібен гаманець**: Ні

**Призначення**: Повертає поточні параметри майнінгу, необхідні зовнішнім майнерам для сканування файлів плотів та обчислення дедлайнів.

**Параметри**: Немає

**Повертані значення**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 символи
  "base_target": 36650387592,                // числове
  "height": 12345,                           // числове, висота наступного блоку
  "block_hash": "def456...",                 // hex, попередній блок
  "target_quality": 18446744073709551615,    // uint64_max (усі рішення приймаються)
  "minimum_compression_level": 1,            // числове
  "target_compression_level": 2              // числове
}
```

**Опис полів**:
- `generation_signature`: Детермінована ентропія майнінгу для цієї висоти блоку
- `base_target`: Поточна складність (вище = легше)
- `height`: Висота блоку, на яку повинні орієнтуватися майнери
- `block_hash`: Хеш попереднього блоку (інформаційний)
- `target_quality`: Поріг якості (наразі uint64_max, без фільтрації)
- `minimum_compression_level`: Мінімальне стиснення, необхідне для валідації
- `target_compression_level`: Рекомендоване стиснення для оптимального майнінгу

**Коди помилок**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Вузол ще синхронізується

**Приклад**:
```bash
bitcoin-cli get_mining_info
```

**Реалізація**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Категорія**: mining
**Потрібен сервер майнінгу**: Так
**Потрібен гаманець**: Так (для приватних ключів)

**Призначення**: Подання рішення майнінгу PoCX. Валідує доказ, ставить у чергу для time-bended кування та автоматично створює блок у запланований час.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (20-byte hex or address)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Повертані значення** (успіх):
```json
{
  "accepted": true,
  "quality": 120,           // дедлайн з урахуванням складності в секундах
  "poc_time": 45            // time-bended час кування в секундах
}
```

**Повертані значення** (відхилено):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Кроки валідації**:
1. **Валідація формату** (швидкий провал):
   - Account ID: рівно 40 hex символів
   - Seed: рівно 64 hex символи
2. **Валідація контексту**:
   - Висота повинна відповідати поточній верхівці + 1
   - Сигнатура генерації повинна відповідати поточній
3. **Перевірка гаманця**:
   - Визначення ефективного підписанта (перевірка на активні призначення)
   - Перевірка наявності приватного ключа гаманця для ефективного підписанта
4. **Валідація доказу** (дорога):
   - Валідація доказу PoCX з межами стиснення
   - Обчислення сирої якості
5. **Подання планувальнику**:
   - Ставить nonce в чергу для time-bended кування
   - Блок буде створено автоматично в forge_time

**Коди помилок**:
- `RPC_INVALID_PARAMETER`: Невалідний формат (account_id, seed) або невідповідність висоти
- `RPC_VERIFY_REJECTED`: Невідповідність сигнатури генерації або провал валідації доказу
- `RPC_INVALID_ADDRESS_OR_KEY`: Немає приватного ключа для ефективного підписанта
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Черга подань заповнена
- `RPC_INTERNAL_ERROR`: Не вдалося ініціалізувати планувальник PoCX

**Коди помилок валідації доказу**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Приклад**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Примітки**:
- Подання асинхронне - RPC повертається негайно, блок кується пізніше
- Time Bending затримує хороші рішення, щоб дозволити мережеве сканування плотів
- Система призначень: якщо плот призначено, гаманець повинен мати ключ адреси кування
- Межі стиснення динамічно налаштовуються на основі висоти блоку

**Реалізація**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC призначень

### get_assignment

**Категорія**: mining
**Потрібен сервер майнінгу**: Ні
**Потрібен гаманець**: Ні

**Призначення**: Запит статусу призначення кування для адреси плоту. Тільки для читання, гаманець не потрібен.

**Параметри**:
1. `plot_address` (рядок, обов'язково) - Адреса плоту (формат bech32 P2WPKH)
2. `height` (числове, опціонально) - Висота блоку для запиту (за замовчуванням: поточна верхівка)

**Повертані значення** (без призначення):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Повертані значення** (активне призначення):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Повертані значення** (скасування):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Стани призначень**:
- `UNASSIGNED`: Призначення не існує
- `ASSIGNING`: Транзакція призначення підтверджена, затримка активації в процесі
- `ASSIGNED`: Призначення активне, права кування делеговані
- `REVOKING`: Транзакція скасування підтверджена, ще активне до закінчення затримки
- `REVOKED`: Скасування завершено, права кування повернуті власнику плоту

**Коди помилок**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Невалідна адреса або не P2WPKH (bech32)

**Приклад**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Реалізація**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Категорія**: wallet
**Потрібен сервер майнінгу**: Ні
**Потрібен гаманець**: Так (повинен бути завантажений та розблокований)

**Призначення**: Створення транзакції призначення кування для делегування прав кування іншій адресі (напр., пулу майнінгу).

**Параметри**:
1. `plot_address` (рядок, обов'язково) - Адреса власника плоту (повинен володіти приватним ключем, P2WPKH bech32)
2. `forging_address` (рядок, обов'язково) - Адреса для призначення прав кування (P2WPKH bech32)
3. `fee_rate` (числове, опціонально) - Ставка комісії в BTC/kvB (за замовчуванням: 10× minRelayFee)

**Повертані значення**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Вимоги**:
- Гаманець завантажений та розблокований
- Приватний ключ для plot_address в гаманці
- Обидві адреси повинні бути P2WPKH (формат bech32: pocx1q... mainnet, tpocx1q... testnet)
- Адреса плоту повинна мати підтверджені UTXO (доводить володіння)
- Плот не повинен мати активного призначення (спочатку скасуйте)

**Структура транзакції**:
- Вхід: UTXO з адреси плоту (доводить володіння)
- Вихід: OP_RETURN (46 байтів): маркер `POCX` + plot_address (20 байтів) + forging_address (20 байтів)
- Вихід: Решта повертається до гаманця

**Активація**:
- Призначення стає ASSIGNING при підтвердженні
- Стає ACTIVE після `nForgingAssignmentDelay` блоків
- Затримка запобігає швидкому перепризначенню під час форків ланцюга

**Коди помилок**:
- `RPC_WALLET_NOT_FOUND`: Гаманець недоступний
- `RPC_WALLET_UNLOCK_NEEDED`: Гаманець зашифрований та заблокований
- `RPC_WALLET_ERROR`: Створення транзакції не вдалося
- `RPC_INVALID_ADDRESS_OR_KEY`: Невалідний формат адреси

**Приклад**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Реалізація**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Категорія**: wallet
**Потрібен сервер майнінгу**: Ні
**Потрібен гаманець**: Так (повинен бути завантажений та розблокований)

**Призначення**: Скасування існуючого призначення кування, повернення прав кування власнику плоту.

**Параметри**:
1. `plot_address` (рядок, обов'язково) - Адреса плоту (повинен володіти приватним ключем, P2WPKH bech32)
2. `fee_rate` (числове, опціонально) - Ставка комісії в BTC/kvB (за замовчуванням: 10× minRelayFee)

**Повертані значення**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Вимоги**:
- Гаманець завантажений та розблокований
- Приватний ключ для plot_address в гаманці
- Адреса плоту повинна бути P2WPKH (формат bech32)
- Адреса плоту повинна мати підтверджені UTXO

**Структура транзакції**:
- Вхід: UTXO з адреси плоту (доводить володіння)
- Вихід: OP_RETURN (26 байтів): маркер `XCOP` + plot_address (20 байтів)
- Вихід: Решта повертається до гаманця

**Ефект**:
- Стан переходить у REVOKING негайно
- Адреса кування все ще може кувати під час періоду затримки
- Стає REVOKED після `nForgingRevocationDelay` блоків
- Власник плоту може кувати після завершення скасування
- Можна створити нове призначення після завершення скасування

**Коди помилок**:
- `RPC_WALLET_NOT_FOUND`: Гаманець недоступний
- `RPC_WALLET_UNLOCK_NEEDED`: Гаманець зашифрований та заблокований
- `RPC_WALLET_ERROR`: Створення транзакції не вдалося

**Приклад**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Примітки**:
- Ідемпотентна: можна скасувати навіть якщо немає активного призначення
- Не можна скасувати скасування після подання

**Реалізація**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Модифіковані RPC блокчейну

### getdifficulty

**Модифікації PoCX**:
- **Обчислення**: `reference_base_target / current_base_target`
- **Референс**: Мережева ємність 1 TiB (base_target = 36650387592)
- **Інтерпретація**: Приблизна ємність сховища мережі в TiB
  - Приклад: `1.0` = ~1 TiB
  - Приклад: `1024.0` = ~1 PiB
- **Відмінність від PoW**: Представляє ємність, а не хеш-потужність

**Приклад**:
```bash
bitcoin-cli getdifficulty
# Повертає: 2048.5 (мережа ~2 PiB)
```

**Реалізація**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Додані поля PoCX**:
- `time_since_last_block` (числове) - Секунди з попереднього блоку (замінює mediantime)
- `poc_time` (числове) - Time-bended час кування в секундах
- `base_target` (числове) - Базова ціль складності PoCX
- `generation_signature` (рядок hex) - Сигнатура генерації
- `pocx_proof` (об'єкт):
  - `account_id` (рядок hex) - ID облікового запису плоту (20 байтів)
  - `seed` (рядок hex) - Seed плоту (32 байти)
  - `nonce` (числове) - Nonce майнінгу
  - `compression` (числове) - Використаний рівень масштабування
  - `quality` (числове) - Заявлене значення якості
- `pubkey` (рядок hex) - Публічний ключ підписанта блоку (33 байти)
- `signer_address` (рядок) - Адреса підписанта блоку
- `signature` (рядок hex) - Підпис блоку (65 байтів)

**Видалені поля PoCX**:
- `mediantime` - Видалено (замінено на time_since_last_block)

**Приклад**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Реалізація**: `src/rpc/blockchain.cpp`

---

### getblock

**Модифікації PoCX**: Такі ж як getblockheader, плюс повні дані транзакцій

**Приклад**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose з деталями tx
```

**Реалізація**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Додані поля PoCX**:
- `base_target` (числове) - Поточна базова ціль
- `generation_signature` (рядок hex) - Поточна сигнатура генерації

**Модифіковані поля PoCX**:
- `difficulty` - Використовує обчислення PoCX (на основі ємності)

**Видалені поля PoCX**:
- `mediantime` - Видалено

**Приклад**:
```bash
bitcoin-cli getblockchaininfo
```

**Реалізація**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Додані поля PoCX**:
- `generation_signature` (рядок hex) - Для пул-майнінгу
- `base_target` (числове) - Для пул-майнінгу

**Видалені поля PoCX**:
- `target` - Видалено (специфічне для PoW)
- `noncerange` - Видалено (специфічне для PoW)
- `bits` - Видалено (специфічне для PoW)

**Примітки**:
- Все ще включає повні дані транзакцій для побудови блоку
- Використовується серверами пулів для координованого майнінгу

**Приклад**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Реалізація**: `src/rpc/mining.cpp`

---

## Вимкнені RPC

Наступні специфічні для PoW RPC **вимкнені** в режимі PoCX:

### getnetworkhashps
- **Причина**: Хешрейт не застосовується до Proof of Capacity
- **Альтернатива**: Використовуйте `getdifficulty` для оцінки ємності мережі

### getmininginfo
- **Причина**: Повертає інформацію, специфічну для PoW
- **Альтернатива**: Використовуйте `get_mining_info` (специфічний для PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Приклади інтеграції

### Інтеграція зовнішнього майнера

**Базовий цикл майнінгу**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Цикл майнінгу
while True:
    # 1. Отримання параметрів майнінгу
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Сканування файлів плотів (зовнішня реалізація)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Подання найкращого рішення
    result = rpc_call("submit_nonce", [
        info["block_hash"],
        height,
        gen_sig,
        base_target,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"],
        best_nonce["compression"],
        best_nonce["raw_quality"]
    ])

    if result["accepted"]:
        print(f"Рішення прийнято! Якість: {result['quality']}с, "
              f"Час кування: {result['poc_time']}с")

    # 4. Очікування наступного блоку
    time.sleep(10)  # Інтервал опитування
```

---

### Патерн інтеграції пулу

**Робочий процес сервера пулу**:
1. Майнери створюють призначення кування на адресу пулу
2. Пул запускає гаманець з ключами адреси кування
3. Пул викликає `get_mining_info` та розподіляє майнерам
4. Майнери подають рішення через пул (не напряму в ланцюг)
5. Пул валідує та викликає `submit_nonce` з ключами пулу
6. Пул розподіляє винагороди згідно політики пулу

**Управління призначеннями**:
```bash
# Майнер створює призначення (з гаманця майнера)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Очікування активації (30 блоків mainnet)

# Пул перевіряє статус призначення
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Пул тепер може подавати nonces для цього плоту
# (гаманець пулу повинен мати приватний ключ pocx1qpool...)
```

---

### Запити оглядача блоків

**Запит даних блоку PoCX**:
```bash
# Отримання останнього блоку
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Отримання деталей блоку з доказом PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Витягування специфічних для PoCX полів
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Виявлення транзакцій призначень**:
```bash
# Сканування транзакції на OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Перевірка на маркер призначення (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Обробка помилок

### Типові патерни помилок

**Невідповідність висоти**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Рішення**: Повторно отримайте інформацію майнінгу, ланцюг просунувся вперед

**Невідповідність сигнатури генерації**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Рішення**: Повторно отримайте інформацію майнінгу, надійшов новий блок

**Немає приватного ключа**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Рішення**: Імпортуйте ключ для адреси плоту або кування

**Активація призначення очікує**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Рішення**: Дочекайтеся закінчення затримки активації

---

## Посилання на код

**RPC майнінгу**: `src/pocx/rpc/mining.cpp`
**RPC призначень**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC блокчейну**: `src/rpc/blockchain.cpp`
**Валідація доказу**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Стан призначень**: `src/pocx/assignments/assignment_state.cpp`
**Створення транзакцій**: `src/pocx/assignments/transactions.cpp`

---

## Перехресні посилання

Пов'язані розділи:
- [Розділ 3: Консенсус і майнінг](3-consensus-and-mining.md) - Деталі процесу майнінгу
- [Розділ 4: Призначення кування](4-forging-assignments.md) - Архітектура системи призначень
- [Розділ 6: Параметри мережі](6-network-parameters.md) - Значення затримок призначень
- [Розділ 8: Посібник з гаманця](8-wallet-guide.md) - GUI для управління призначеннями

---

[← Назад: Параметри мережі](6-network-parameters.md) | [📘 Зміст](index.md) | [Далі: Посібник з гаманця →](8-wallet-guide.md)

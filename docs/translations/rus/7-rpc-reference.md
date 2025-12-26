[<- Назад: Сетевые параметры](6-network-parameters.md) | [Содержание](index.md) | [Далее: Руководство по кошельку ->](8-wallet-guide.md)

---

# Глава 7: Справочник по RPC-интерфейсу

Полный справочник по RPC-командам Bitcoin-PoCX, включая RPC майнинга, управление делегированием и модифицированные RPC блокчейна.

---

## Содержание

1. [Конфигурация](#конфигурация)
2. [RPC майнинга PoCX](#rpc-майнинга-pocx)
3. [RPC делегирования](#rpc-делегирования)
4. [Модифицированные RPC блокчейна](#модифицированные-rpc-блокчейна)
5. [Отключённые RPC](#отключённые-rpc)
6. [Примеры интеграции](#примеры-интеграции)

---

## Конфигурация

### Режим сервера майнинга

**Флаг**: `-miningserver`

**Цель**: Включает RPC-доступ для внешних майнеров к вызову специфичных для майнинга RPC

**Требования**:
- Требуется для работы `submit_nonce`
- Требуется для отображения диалога делегирования форджинга в Qt-кошельке

**Использование**:
```bash
# Командная строка
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Соображения безопасности**:
- Без дополнительной аутентификации помимо стандартных учётных данных RPC
- RPC майнинга ограничены по скорости ёмкостью очереди
- Стандартная RPC-аутентификация по-прежнему требуется

**Реализация**: `src/pocx/rpc/mining.cpp`

---

## RPC майнинга PoCX

### get_mining_info

**Категория**: mining
**Требует сервер майнинга**: Нет
**Требует кошелёк**: Нет

**Цель**: Возвращает текущие параметры майнинга, необходимые внешним майнерам для сканирования файлов графиков и вычисления дедлайнов.

**Параметры**: Нет

**Возвращаемые значения**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 символа
  "base_target": 36650387593,                // числовое
  "height": 12345,                           // числовое, высота следующего блока
  "block_hash": "def456...",                 // hex, предыдущий блок
  "target_quality": 18446744073709551615,    // uint64_max (все решения приняты)
  "minimum_compression_level": 1,            // числовое
  "target_compression_level": 2              // числовое
}
```

**Описание полей**:
- `generation_signature`: Детерминированная энтропия майнинга для этой высоты блока
- `base_target`: Текущая сложность (выше = легче)
- `height`: Высота блока, на которую должны целиться майнеры
- `block_hash`: Хеш предыдущего блока (информационно)
- `target_quality`: Порог качества (в настоящее время uint64_max, без фильтрации)
- `minimum_compression_level`: Минимальное сжатие, требуемое для валидации
- `target_compression_level`: Рекомендуемое сжатие для оптимального майнинга

**Коды ошибок**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Узел всё ещё синхронизируется

**Пример**:
```bash
bitcoin-cli get_mining_info
```

**Реализация**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Категория**: mining
**Требует сервер майнинга**: Да
**Требует кошелёк**: Да (для приватных ключей)

**Цель**: Отправить решение майнинга PoCX. Валидирует доказательство, ставит в очередь для искривлённого по времени форджинга и автоматически создаёт блок в запланированное время.

**Параметры**:
1. `height` (числовое, обязательно) — Высота блока
2. `generation_signature` (строка hex, обязательно) — Сигнатура генерации (64 символа)
3. `account_id` (строка, обязательно) — ID аккаунта графика (40 hex символов = 20 байт)
4. `seed` (строка, обязательно) — Seed графика (64 hex символа = 32 байта)
5. `nonce` (числовое, обязательно) — Нонс майнинга
6. `compression` (числовое, обязательно) — Используемый уровень масштабирования/сжатия (1-255)
7. `quality` (числовое, опционально) — Значение качества (пересчитывается если опущено)

**Возвращаемые значения** (успех):
```json
{
  "accepted": true,
  "quality": 120,           // дедлайн с корректировкой сложности в секундах
  "poc_time": 45            // искривлённое время форджинга в секундах
}
```

**Возвращаемые значения** (отклонено):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Шаги валидации**:
1. **Валидация формата** (быстрый отказ):
   - Account ID: ровно 40 hex символов
   - Seed: ровно 64 hex символа
2. **Валидация контекста**:
   - Высота должна совпадать с текущей вершиной + 1
   - Сигнатура генерации должна совпадать с текущей
3. **Проверка кошелька**:
   - Определение эффективного подписанта (проверка активных делегирований)
   - Проверка наличия в кошельке приватного ключа для эффективного подписанта
4. **Валидация доказательства** (дорогая):
   - Валидация доказательства PoCX с границами сжатия
   - Вычисление сырого качества
5. **Отправка в планировщик**:
   - Постановка нонса в очередь для искривлённого по времени форджинга
   - Блок будет создан автоматически в момент forge_time

**Коды ошибок**:
- `RPC_INVALID_PARAMETER`: Неверный формат (account_id, seed) или несовпадение высоты
- `RPC_VERIFY_REJECTED`: Несовпадение сигнатуры генерации или сбой валидации доказательства
- `RPC_INVALID_ADDRESS_OR_KEY`: Нет приватного ключа для эффективного подписанта
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Очередь отправки полна
- `RPC_INTERNAL_ERROR`: Не удалось инициализировать планировщик PoCX

**Коды ошибок валидации доказательства**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Пример**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Примечания**:
- Отправка асинхронна — RPC возвращается немедленно, блок форджится позже
- Искривление времени задерживает хорошие решения, чтобы позволить сканирование графиков по всей сети
- Система делегирования: если график делегирован, кошелёк должен иметь ключ адреса форджинга
- Границы сжатия динамически корректируются на основе высоты блока

**Реализация**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC делегирования

### get_assignment

**Категория**: mining
**Требует сервер майнинга**: Нет
**Требует кошелёк**: Нет

**Цель**: Запрос статуса делегирования форджинга для адреса графика. Только чтение, кошелёк не требуется.

**Параметры**:
1. `plot_address` (строка, обязательно) — Адрес графика (формат bech32 P2WPKH)
2. `height` (числовое, опционально) — Высота блока для запроса (по умолчанию: текущая вершина)

**Возвращаемые значения** (без делегирования):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Возвращаемые значения** (активное делегирование):
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

**Возвращаемые значения** (отзыв в процессе):
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

**Состояния делегирования**:
- `UNASSIGNED`: Делегирование не существует
- `ASSIGNING`: Транзакция делегирования подтверждена, идёт период задержки активации
- `ASSIGNED`: Делегирование активно, права форджинга переданы
- `REVOKING`: Транзакция отзыва подтверждена, всё ещё активно до истечения задержки
- `REVOKED`: Отзыв завершён, права форджинга вернулись владельцу графика

**Коды ошибок**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Неверный адрес или не P2WPKH (bech32)

**Пример**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Реализация**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Категория**: wallet
**Требует сервер майнинга**: Нет
**Требует кошелёк**: Да (должен быть загружен и разблокирован)

**Цель**: Создание транзакции делегирования форджинга для передачи прав форджинга другому адресу (например, пулу майнинга).

**Параметры**:
1. `plot_address` (строка, обязательно) — Адрес владельца графика (должен владеть приватным ключом, P2WPKH bech32)
2. `forging_address` (строка, обязательно) — Адрес для делегирования прав форджинга (P2WPKH bech32)
3. `fee_rate` (числовое, опционально) — Ставка комиссии в BTC/kvB (по умолчанию: 10x minRelayFee)

**Возвращаемые значения**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Требования**:
- Кошелёк загружен и разблокирован
- Приватный ключ для plot_address в кошельке
- Оба адреса должны быть P2WPKH (формат bech32: pocx1q... mainnet, tpocx1q... testnet)
- Адрес графика должен иметь подтверждённые UTXO (подтверждает владение)
- У графика не должно быть активного делегирования (сначала используйте отзыв)

**Структура транзакции**:
- Вход: UTXO от адреса графика (подтверждает владение)
- Выход: OP_RETURN (46 байт): маркер `POCX` + plot_address (20 байт) + forging_address (20 байт)
- Выход: Сдача возвращается в кошелёк

**Активация**:
- Делегирование становится ASSIGNING при подтверждении
- Становится ACTIVE после `nForgingAssignmentDelay` блоков
- Задержка предотвращает быстрое переназначение при форках цепочки

**Коды ошибок**:
- `RPC_WALLET_NOT_FOUND`: Кошелёк недоступен
- `RPC_WALLET_UNLOCK_NEEDED`: Кошелёк зашифрован и заблокирован
- `RPC_WALLET_ERROR`: Сбой создания транзакции
- `RPC_INVALID_ADDRESS_OR_KEY`: Неверный формат адреса

**Пример**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Реализация**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Категория**: wallet
**Требует сервер майнинга**: Нет
**Требует кошелёк**: Да (должен быть загружен и разблокирован)

**Цель**: Отзыв существующего делегирования форджинга, возврат прав форджинга владельцу графика.

**Параметры**:
1. `plot_address` (строка, обязательно) — Адрес графика (должен владеть приватным ключом, P2WPKH bech32)
2. `fee_rate` (числовое, опционально) — Ставка комиссии в BTC/kvB (по умолчанию: 10x minRelayFee)

**Возвращаемые значения**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Требования**:
- Кошелёк загружен и разблокирован
- Приватный ключ для plot_address в кошельке
- Адрес графика должен быть P2WPKH (формат bech32)
- Адрес графика должен иметь подтверждённые UTXO

**Структура транзакции**:
- Вход: UTXO от адреса графика (подтверждает владение)
- Выход: OP_RETURN (26 байт): маркер `XCOP` + plot_address (20 байт)
- Выход: Сдача возвращается в кошелёк

**Эффект**:
- Состояние немедленно переходит в REVOKING
- Адрес форджинга всё ещё может форджить в период задержки
- Становится REVOKED после `nForgingRevocationDelay` блоков
- Владелец графика может форджить после вступления отзыва в силу
- Можно создать новое делегирование после завершения отзыва

**Коды ошибок**:
- `RPC_WALLET_NOT_FOUND`: Кошелёк недоступен
- `RPC_WALLET_UNLOCK_NEEDED`: Кошелёк зашифрован и заблокирован
- `RPC_WALLET_ERROR`: Сбой создания транзакции

**Пример**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Примечания**:
- Идемпотентный: можно отозвать даже если нет активного делегирования
- Нельзя отменить отзыв после отправки

**Реализация**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Модифицированные RPC блокчейна

### getdifficulty

**Модификации PoCX**:
- **Вычисление**: `reference_base_target / current_base_target`
- **Эталон**: Ёмкость сети 1 ТиБ (base_target = 36650387593)
- **Интерпретация**: Оценочная ёмкость хранилища сети в ТиБ
  - Пример: `1.0` = ~1 ТиБ
  - Пример: `1024.0` = ~1 ПиБ
- **Отличие от PoW**: Представляет ёмкость, не хешрейт

**Пример**:
```bash
bitcoin-cli getdifficulty
# Возвращает: 2048.5 (сеть ~2 ПиБ)
```

**Реализация**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Добавленные поля PoCX**:
- `time_since_last_block` (числовое) — Секунды с предыдущего блока (заменяет mediantime)
- `poc_time` (числовое) — Искривлённое время форджинга в секундах
- `base_target` (числовое) — Базовая цель сложности PoCX
- `generation_signature` (строка hex) — Сигнатура генерации
- `pocx_proof` (объект):
  - `account_id` (строка hex) — ID аккаунта графика (20 байт)
  - `seed` (строка hex) — Seed графика (32 байта)
  - `nonce` (числовое) — Нонс майнинга
  - `compression` (числовое) — Использованный уровень масштабирования
  - `quality` (числовое) — Заявленное значение качества
- `pubkey` (строка hex) — Публичный ключ подписанта блока (33 байта)
- `signer_address` (строка) — Адрес подписанта блока
- `signature` (строка hex) — Подпись блока (65 байт)

**Удалённые поля PoCX**:
- `mediantime` — Удалено (заменено на time_since_last_block)

**Пример**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Реализация**: `src/rpc/blockchain.cpp`

---

### getblock

**Модификации PoCX**: Такие же, как у getblockheader, плюс полные данные транзакций

**Пример**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # подробно с деталями tx
```

**Реализация**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Добавленные поля PoCX**:
- `base_target` (числовое) — Текущая базовая цель
- `generation_signature` (строка hex) — Текущая сигнатура генерации

**Модифицированные поля PoCX**:
- `difficulty` — Использует вычисление PoCX (на основе ёмкости)

**Удалённые поля PoCX**:
- `mediantime` — Удалено

**Пример**:
```bash
bitcoin-cli getblockchaininfo
```

**Реализация**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Добавленные поля PoCX**:
- `generation_signature` (строка hex) — Для пул-майнинга
- `base_target` (числовое) — Для пул-майнинга

**Удалённые поля PoCX**:
- `target` — Удалено (специфично для PoW)
- `noncerange` — Удалено (специфично для PoW)
- `bits` — Удалено (специфично для PoW)

**Примечания**:
- Всё ещё включает полные данные транзакций для построения блока
- Используется серверами пулов для координированного майнинга

**Пример**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Реализация**: `src/rpc/mining.cpp`

---

## Отключённые RPC

Следующие специфичные для PoW RPC **отключены** в режиме PoCX:

### getnetworkhashps
- **Причина**: Хешрейт неприменим к Proof of Capacity
- **Альтернатива**: Используйте `getdifficulty` для оценки ёмкости сети

### getmininginfo
- **Причина**: Возвращает информацию, специфичную для PoW
- **Альтернатива**: Используйте `get_mining_info` (специфично для PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Причина**: Майнинг на CPU неприменим к PoCX (требуются предварительно сгенерированные графики)
- **Альтернатива**: Используйте внешний плоттер + майнер + `submit_nonce`

**Реализация**: `src/rpc/mining.cpp` (RPC возвращают ошибку когда определён ENABLE_POCX)

---

## Примеры интеграции

### Интеграция внешнего майнера

**Базовый цикл майнинга**:
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

# Цикл майнинга
while True:
    # 1. Получить параметры майнинга
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Сканировать файлы графиков (внешняя реализация)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Отправить лучшее решение
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Решение принято! Качество: {result['quality']}с, "
              f"Время форджинга: {result['poc_time']}с")

    # 4. Ждать следующего блока
    time.sleep(10)  # Интервал опроса
```

---

### Паттерн интеграции пула

**Рабочий процесс сервера пула**:
1. Майнеры создают делегирования форджинга на адрес пула
2. Пул запускает кошелёк с ключами адреса форджинга
3. Пул вызывает `get_mining_info` и распределяет майнерам
4. Майнеры отправляют решения через пул (не напрямую в цепочку)
5. Пул валидирует и вызывает `submit_nonce` с ключами пула
6. Пул распределяет награды согласно политике пула

**Управление делегированием**:
```bash
# Майнер создаёт делегирование (из кошелька майнера)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Ждать активации (30 блоков mainnet)

# Пул проверяет статус делегирования
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Пул теперь может отправлять нонсы для этого графика
# (кошелёк пула должен иметь приватный ключ pocx1qpool...)
```

---

### Запросы обозревателя блоков

**Запрос данных блока PoCX**:
```bash
# Получить последний блок
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Получить детали блока с доказательством PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Извлечь специфичные для PoCX поля
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

**Обнаружение транзакций делегирования**:
```bash
# Сканировать транзакцию на OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Проверить маркер делегирования (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Обработка ошибок

### Типичные паттерны ошибок

**Несовпадение высоты**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Решение**: Повторно запросить информацию о майнинге, цепочка продвинулась вперёд

**Несовпадение сигнатуры генерации**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Решение**: Повторно запросить информацию о майнинге, пришёл новый блок

**Нет приватного ключа**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Решение**: Импортировать ключ для адреса графика или форджинга

**Активация делегирования в ожидании**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Решение**: Дождаться истечения задержки активации

---

## Ссылки на код

**RPC майнинга**: `src/pocx/rpc/mining.cpp`
**RPC делегирования**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC блокчейна**: `src/rpc/blockchain.cpp`
**Валидация доказательства**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Состояние делегирования**: `src/pocx/assignments/assignment_state.cpp`
**Создание транзакций**: `src/pocx/assignments/transactions.cpp`

---

## Перекрёстные ссылки

Связанные главы:
- [Глава 3: Консенсус и майнинг](3-consensus-and-mining.md) — Детали процесса майнинга
- [Глава 4: Делегирование форджинга](4-forging-assignments.md) — Архитектура системы делегирования
- [Глава 6: Сетевые параметры](6-network-parameters.md) — Значения задержки делегирования
- [Глава 8: Руководство по кошельку](8-wallet-guide.md) — GUI для управления делегированием

---

[<- Назад: Сетевые параметры](6-network-parameters.md) | [Содержание](index.md) | [Далее: Руководство по кошельку ->](8-wallet-guide.md)

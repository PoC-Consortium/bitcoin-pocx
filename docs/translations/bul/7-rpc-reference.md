[← Назад: Мрежови параметри](6-network-parameters.md) | [📘 Съдържание](index.md) | [Напред: Ръководство за портфейл →](8-wallet-guide.md)

---

# Глава 7: Справочник за RPC интерфейса

Пълен справочник за RPC командите на Bitcoin-PoCX, включително RPC за копаене, управление на делегирания и модифицирани RPC за блокчейн.

---

## Съдържание

1. [Конфигурация](#конфигурация)
2. [PoCX RPC за копаене](#pocx-rpc-за-копаене)
3. [RPC за делегиране](#rpc-за-делегиране)
4. [Модифицирани RPC за блокчейн](#модифицирани-rpc-за-блокчейн)
5. [Деактивирани RPC](#деактивирани-rpc)
6. [Примери за интеграция](#примери-за-интеграция)

---

## Конфигурация

### Режим на Mining сървър

**Флаг**: ``

**Цел**: Позволява RPC достъп за външни миньори да извикват специфични за копаене RPC команди

**Изисквания**:
- Необходим за функциониране на `submit_nonce`
- Необходим за видимост на диалога за делегиране в Qt портфейла

**Употреба**:
```bash
# Команден ред
./bitcoind

# bitcoin.conf
```

**Съображения за сигурност**:
- Без допълнително удостоверяване отвъд стандартните RPC удостоверения
- RPC за копаене са rate-limited от капацитета на опашката
- Стандартното RPC удостоверяване все още се изисква

**Имплементация**: `src/pocx/rpc/mining.cpp`

---

## PoCX RPC за копаене

### get_mining_info

**Категория**: mining
**Изисква Mining сървър**: Не
**Изисква портфейл**: Не

**Цел**: Връща текущи параметри за копаене, необходими на външни миньори за сканиране на plot файлове и изчисляване на крайни срокове.

**Параметри**: Няма

**Върнати стойности**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 символа
  "base_target": 36650387592,                // числово
  "height": 12345,                           // числово, височина на следващия блок
  "block_hash": "def456...",                 // hex, предишен блок
  "target_quality": 18446744073709551615,    // uint64_max (всички решения се приемат)
  "minimum_compression_level": 1,            // числово
  "target_compression_level": 2              // числово
}
```

**Описание на полетата**:
- `generation_signature`: Детерминистична ентропия за копаене за тази височина на блок
- `base_target`: Текуща трудност (по-високо = по-лесно)
- `height`: Височина на блок, към която миньорите трябва да се насочат
- `block_hash`: Хеш на предишен блок (информационен)
- `target_quality`: Праг за качество (понастоящем uint64_max, без филтриране)
- `minimum_compression_level`: Минимална компресия, необходима за валидация
- `target_compression_level`: Препоръчителна компресия за оптимално копаене

**Кодове за грешка**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Възелът все още синхронизира

**Пример**:
```bash
bitcoin-cli get_mining_info
```

**Имплементация**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Категория**: mining
**Изисква Mining сървър**: Да
**Изисква портфейл**: Да (за частни ключове)

**Цел**: Подаване на PoCX решение за копаене. Валидира доказателство, поставя на опашка за time-bended подписване и автоматично създава блок в планираното време.

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

**Върнати стойности** (успех):
```json
{
  "accepted": true,
  "quality": 120,           // краен срок, коригиран за трудност, в секунди
  "poc_time": 45            // time-bended време за подписване в секунди
}
```

**Върнати стойности** (отхвърлено):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Стъпки на валидация**:
1. **Валидация на формат** (бърз отказ):
   - Account ID: точно 40 hex символа
   - Seed: точно 64 hex символа
2. **Валидация на контекст**:
   - Височината трябва да съвпада с текущ връх + 1
   - Генерационният подпис трябва да съвпада с текущия
3. **Верификация на портфейл**:
   - Определяне на ефективен подписващ (проверка за активни делегирания)
   - Проверка дали портфейлът има частен ключ за ефективния подписващ
4. **Валидация на доказателство** (скъпа):
   - Валидиране на PoCX доказателство с граници на компресия
   - Изчисляване на сурово качество
5. **Подаване към планировчик**:
   - Поставяне на nonce на опашка за time-bended подписване
   - Блокът ще бъде създаден автоматично в forge_time

**Кодове за грешка**:
- `RPC_INVALID_PARAMETER`: Невалиден формат (account_id, seed) или несъответствие на височина
- `RPC_VERIFY_REJECTED`: Несъответствие на генерационен подпис или провал на валидация на доказателство
- `RPC_INVALID_ADDRESS_OR_KEY`: Няма частен ключ за ефективен подписващ
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Опашката за подаване е пълна
- `RPC_INTERNAL_ERROR`: Неуспешна инициализация на PoCX планировчик

**Кодове за грешка при валидация на доказателство**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Пример**:
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

**Забележки**:
- Подаването е асинхронно — RPC връща незабавно, блокът се подписва по-късно
- Time Bending забавя добрите решения, за да позволи сканиране на plot файлове в цялата мрежа
- Система за делегиране: ако plot е делегиран, портфейлът трябва да има ключ за адреса за подписване
- Граници на компресия се коригират динамично на база височина на блок

**Имплементация**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC за делегиране

### get_assignment

**Категория**: mining
**Изисква Mining сървър**: Не
**Изисква портфейл**: Не

**Цел**: Заявка за статус на делегиране за адрес на plot. Само за четене, не изисква портфейл.

**Параметри**:
1. `plot_address` (string, задължителен) — Адрес на plot (bech32 P2WPKH формат)
2. `height` (числово, незадължителен) — Височина на блок за заявка (по подразбиране: текущ връх)

**Върнати стойности** (без делегиране):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Върнати стойности** (активно делегиране):
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

**Върнати стойности** (в процес на отмяна):
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

**Състояния на делегиране**:
- `UNASSIGNED`: Не съществува делегиране
- `ASSIGNING`: Tx за делегиране потвърдена, забавяне на активиране в процес
- `ASSIGNED`: Делегиране активно, права за подписване делегирани
- `REVOKING`: Tx за отмяна потвърдена, все още активно до изтичане на забавяне
- `REVOKED`: Отмяна завършена, права за подписване върнати на собственика на plot

**Кодове за грешка**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Невалиден адрес или не е P2WPKH (bech32)

**Пример**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Имплементация**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Категория**: wallet
**Изисква Mining сървър**: Не
**Изисква портфейл**: Да (трябва да е зареден и отключен)

**Цел**: Създаване на транзакция за делегиране за делегиране на права за подписване на друг адрес (напр. mining пул).

**Параметри**:
1. `plot_address` (string, задължителен) — Адрес на собственик на plot (трябва да притежава частен ключ, P2WPKH bech32)
2. `forging_address` (string, задължителен) — Адрес за делегиране на права за подписване (P2WPKH bech32)
3. `fee_rate` (числово, незадължителен) — Такса в BTC/kvB (по подразбиране: 10× minRelayFee)

**Върнати стойности**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Изисквания**:
- Портфейл зареден и отключен
- Частен ключ за plot_address в портфейла
- И двата адреса трябва да са P2WPKH (bech32 формат: pocx1q... mainnet, tpocx1q... testnet)
- Адресът на plot трябва да има потвърдени UTXO (доказва собственост)
- Plot не трябва да има активно делегиране (използвайте revoke първо)

**Структура на транзакция**:
- Вход: UTXO от адрес на plot (доказва собственост)
- Изход: OP_RETURN (46 байта): `POCX` маркер + plot_address (20 байта) + forging_address (20 байта)
- Изход: Ресто, върнато в портфейла

**Активиране**:
- Делегирането става ASSIGNING при потвърждение
- Става ACTIVE след `nForgingAssignmentDelay` блока
- Забавянето предотвратява бързо пределегиране при разклонения на веригата

**Кодове за грешка**:
- `RPC_WALLET_NOT_FOUND`: Няма наличен портфейл
- `RPC_WALLET_UNLOCK_NEEDED`: Портфейлът е криптиран и заключен
- `RPC_WALLET_ERROR`: Неуспешно създаване на транзакция
- `RPC_INVALID_ADDRESS_OR_KEY`: Невалиден формат на адрес

**Пример**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Имплементация**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Категория**: wallet
**Изисква Mining сървър**: Не
**Изисква портфейл**: Да (трябва да е зареден и отключен)

**Цел**: Отмяна на съществуващо делегиране, връщане на права за подписване на собственика на plot.

**Параметри**:
1. `plot_address` (string, задължителен) — Адрес на plot (трябва да притежава частен ключ, P2WPKH bech32)
2. `fee_rate` (числово, незадължителен) — Такса в BTC/kvB (по подразбиране: 10× minRelayFee)

**Върнати стойности**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Изисквания**:
- Портфейл зареден и отключен
- Частен ключ за plot_address в портфейла
- Адресът на plot трябва да е P2WPKH (bech32 формат)
- Адресът на plot трябва да има потвърдени UTXO

**Структура на транзакция**:
- Вход: UTXO от адрес на plot (доказва собственост)
- Изход: OP_RETURN (26 байта): `XCOP` маркер + plot_address (20 байта)
- Изход: Ресто, върнато в портфейла

**Ефект**:
- Състоянието преминава в REVOKING незабавно
- Адресът за подписване може все още да подписва по време на периода на забавяне
- Става REVOKED след `nForgingRevocationDelay` блока
- Собственикът на plot може да подписва след влизане в сила на отмяната
- Може да създаде ново делегиране след завършване на отмяната

**Кодове за грешка**:
- `RPC_WALLET_NOT_FOUND`: Няма наличен портфейл
- `RPC_WALLET_UNLOCK_NEEDED`: Портфейлът е криптиран и заключен
- `RPC_WALLET_ERROR`: Неуспешно създаване на транзакция

**Пример**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Забележки**:
- Идемпотентен: може да отменя дори ако няма активно делегиране
- Не може да отмени отмяна след подаване

**Имплементация**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Модифицирани RPC за блокчейн

### getdifficulty

**PoCX модификации**:
- **Изчисляване**: `reference_base_target / current_base_target`
- **Референция**: Мрежов капацитет от 1 TiB (base_target = 36650387592)
- **Интерпретация**: Оценен капацитет на мрежово съхранение в TiB
  - Пример: `1.0` = ~1 TiB
  - Пример: `1024.0` = ~1 PiB
- **Разлика от PoW**: Представлява капацитет, не хеш мощност

**Пример**:
```bash
bitcoin-cli getdifficulty
# Връща: 2048.5 (мрежа ~2 PiB)
```

**Имплементация**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX добавени полета**:
- `time_since_last_block` (числово) — Секунди от предишния блок (заменя mediantime)
- `poc_time` (числово) — Time-bended време за подписване в секунди
- `base_target` (числово) — PoCX базова цел за трудност
- `generation_signature` (string hex) — Генерационен подпис
- `pocx_proof` (обект):
  - `account_id` (string hex) — ID на акаунт на plot (20 байта)
  - `seed` (string hex) — Seed на plot (32 байта)
  - `nonce` (числово) — Nonce за копаене
  - `compression` (числово) — Използвано ниво на мащабиране
  - `quality` (числово) — Декларирана стойност на качество
- `pubkey` (string hex) — Публичен ключ на подписващия блок (33 байта)
- `signer_address` (string) — Адрес на подписващия блок
- `signature` (string hex) — Подпис на блок (65 байта)

**PoCX премахнати полета**:
- `mediantime` — Премахнат (заменен от time_since_last_block)

**Пример**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Имплементация**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX модификации**: Същите като getblockheader, плюс пълни данни за транзакции

**Пример**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose с детайли за tx
```

**Имплементация**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX добавени полета**:
- `base_target` (числово) — Текуща базова цел
- `generation_signature` (string hex) — Текущ генерационен подпис

**PoCX модифицирани полета**:
- `difficulty` — Използва PoCX изчисляване (базирано на капацитет)

**PoCX премахнати полета**:
- `mediantime` — Премахнат

**Пример**:
```bash
bitcoin-cli getblockchaininfo
```

**Имплементация**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX добавени полета**:
- `generation_signature` (string hex) — За pool копаене
- `base_target` (числово) — За pool копаене

**PoCX премахнати полета**:
- `target` — Премахнат (специфично за PoW)
- `noncerange` — Премахнат (специфично за PoW)
- `bits` — Премахнат (специфично за PoW)

**Забележки**:
- Все още включва пълни данни за транзакции за конструиране на блок
- Използва се от pool сървъри за координирано копаене

**Пример**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Имплементация**: `src/rpc/mining.cpp`

---

## Деактивирани RPC

Следните PoW-специфични RPC са **деактивирани** в PoCX режим:

### getnetworkhashps
- **Причина**: Hash rate не е приложим за Proof of Capacity
- **Алтернатива**: Използвайте `getdifficulty` за оценка на мрежов капацитет

### getmininginfo
- **Причина**: Връща PoW-специфична информация
- **Алтернатива**: Използвайте `get_mining_info` (PoCX-специфично)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Примери за интеграция

### Интеграция на външен миньор

**Основен цикъл за копаене**:
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

# Цикъл за копаене
while True:
    # 1. Получаване на параметри за копаене
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Сканиране на plot файлове (външна имплементация)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Подаване на най-доброто решение
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
        print(f"Решение прието! Качество: {result['quality']}s, "
              f"Време за подписване: {result['poc_time']}s")

    # 4. Изчакване на следващ блок
    time.sleep(10)  # Интервал на polling
```

---

### Модел за интеграция на пул

**Работен поток на Pool сървър**:
1. Миньорите създават делегирания към адрес на пула
2. Пулът работи с портфейл с ключове за адреса за подписване
3. Пулът извиква `get_mining_info` и разпределя към миньорите
4. Миньорите подават решения чрез пула (не директно към веригата)
5. Пулът валидира и извиква `submit_nonce` с ключовете на пула
6. Пулът разпределя награди според политиката на пула

**Управление на делегирания**:
```bash
# Миньорът създава делегиране (от портфейла на миньора)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Изчакване на активиране (30 блока mainnet)

# Пулът проверява статус на делегиране
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Пулът вече може да подава nonces за този plot
# (портфейлът на пула трябва да има частен ключ pocx1qpool...)
```

---

### Заявки за Block Explorer

**Заявка за PoCX данни на блок**:
```bash
# Получаване на последен блок
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Получаване на детайли на блок с PoCX доказателство
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Извличане на PoCX-специфични полета
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

**Откриване на транзакции за делегиране**:
```bash
# Сканиране на транзакция за OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Проверка за маркер на делегиране (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Обработка на грешки

### Често срещани модели на грешки

**Несъответствие на височина**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Решение**: Извлечете отново mining info, веригата се е придвижила напред

**Несъответствие на генерационен подпис**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Решение**: Извлечете отново mining info, пристигнал е нов блок

**Няма частен ключ**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Решение**: Импортирайте ключ за адрес на plot или подписване

**Чакащо активиране на делегиране**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Решение**: Изчакайте забавянето на активиране да изтече

---

## Препратки към код

**RPC за копаене**: `src/pocx/rpc/mining.cpp`
**RPC за делегиране**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC за блокчейн**: `src/rpc/blockchain.cpp`
**Валидация на доказателство**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Състояние на делегиране**: `src/pocx/assignments/assignment_state.cpp`
**Създаване на транзакции**: `src/pocx/assignments/transactions.cpp`

---

## Препратки

Свързани глави:
- [Глава 3: Консенсус и копаене](3-consensus-and-mining.md) — Детайли на процеса на копаене
- [Глава 4: Делегиране на подписване](4-forging-assignments.md) — Архитектура на системата за делегиране
- [Глава 6: Мрежови параметри](6-network-parameters.md) — Стойности на забавяне на делегиране
- [Глава 8: Ръководство за портфейл](8-wallet-guide.md) — GUI за управление на делегирания

---

[← Назад: Мрежови параметри](6-network-parameters.md) | [📘 Съдържание](index.md) | [Напред: Ръководство за портфейл →](8-wallet-guide.md)

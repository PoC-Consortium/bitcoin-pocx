[← Претходно: Мрежни параметри](6-network-parameters.md) | [📘 Садржај](index.md) | [Следеће: Водич за новчаник →](8-wallet-guide.md)

---

# Поглавље 7: Референца RPC интерфејса

Комплетна референца за Bitcoin-PoCX RPC команде, укључујући RPC-ове за рударење, управљање додељивањима и модификоване блокчејн RPC-ове.

---

## Садржај

1. [Конфигурација](#конфигурација)
2. [PoCX RPC-ови за рударење](#pocx-rpc-ови-за-рударење)
3. [RPC-ови додељивања](#rpc-ови-додељивања)
4. [Модификовани блокчејн RPC-ови](#модификовани-блокчејн-rpc-ови)
5. [Онемогућени RPC-ови](#онемогућени-rpc-ови)
6. [Примери интеграције](#примери-интеграције)

---

## Конфигурација

### Режим сервера за рударење

**Флаг**: ``

**Сврха**: Омогућава RPC приступ за спољне рударе да позивају RPC-ове специфичне за рударење

**Захтеви**:
- Потребан да `submit_nonce` функционише
- Потребан за видљивост дијалога додељивања ковања у Qt новчанику

**Употреба**:
```bash
# Командна линија
./bitcoind

# bitcoin.conf
```

**Безбедносна разматрања**:
- Без додатне аутентификације изван стандардних RPC акредитива
- RPC-ови за рударење су ограничени капацитетом реда чекања
- Стандардна RPC аутентификација је и даље потребна

**Имплементација**: `src/pocx/rpc/mining.cpp`

---

## PoCX RPC-ови за рударење

### get_mining_info

**Категорија**: mining
**Захтева сервер за рударење**: Не
**Захтева новчаник**: Не

**Сврха**: Враћа тренутне параметре рударења потребне спољним рударима за скенирање плот датотека и израчунавање рокова.

**Параметри**: Нема

**Повратне вредности**:
```json
{
  "generation_signature": "abc123...",       // хекс, 64 карактера
  "base_target": 36650387592,                // нумерички
  "height": 12345,                           // нумерички, висина следећег блока
  "block_hash": "def456...",                 // хекс, претходни блок
  "target_quality": 18446744073709551615,    // uint64_max (сва решења прихваћена)
  "minimum_compression_level": 1,            // нумерички
  "target_compression_level": 2              // нумерички
}
```

**Описи поља**:
- `generation_signature`: Детерминистичка ентропија рударења за ову висину блока
- `base_target`: Тренутна тежина (виша = лакше)
- `height`: Висина блока коју рудари треба да циљају
- `block_hash`: Хеш претходног блока (информативно)
- `target_quality`: Праг квалитета (тренутно uint64_max, без филтрирања)
- `minimum_compression_level`: Минимална компресија потребна за валидацију
- `target_compression_level`: Препоручена компресија за оптимално рударење

**Кодови грешака**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Чвор се још увек синхронизује

**Пример**:
```bash
bitcoin-cli get_mining_info
```

**Имплементација**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Категорија**: mining
**Захтева новчаник**: Да (за приватне кључеве)

**Сврха**: Шаље PoCX решење рударења. Валидира доказ, ставља у ред чекања за ковање са савијањем времена, и аутоматски креира блок у заказано време.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (тачно 40 хекс карактера = 20 бајтова; адреса се не прихвата)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Повратне вредности** (успех):
```json
{
  "raw_quality": 120,       // сирови квалитет из валидације доказа
  "poc_time": 45            // време ковања савијено временом у секундама
}
```

Не постоји поље `accepted`. При одбијању RPC **не** враћа JSON објекат — баца `JSONRPCError` (видети Кодове грешака испод).

**Кораци валидације**:
1. **Валидација формата** (брзи неуспех):
   - Account ID: тачно 40 хекс карактера
   - Seed: тачно 64 хекс карактера
2. **Валидација контекста**:
   - Висина мора одговарати тренутном врху + 1
   - Генерацијски потпис мора одговарати тренутном
3. **Верификација новчаника**:
   - Одреди ефективног потписника (провери активна додељивања)
   - Верификуј да новчаник има приватни кључ за ефективног потписника
4. **Валидација доказа** (скупа):
   - Валидирај PoCX доказ са границама компресије
   - Израчунај сирови квалитет
5. **Слање планеру**:
   - Стави nonce у ред чекања за ковање са савијањем времена
   - Блок ће бити аутоматски креиран у forge_time

**Кодови грешака** (бацају се као `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Неважећи формат (account_id, seed) или неподударање висине (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Неподударање генерацијског потписа или неуспела валидација доказа
- `RPC_INVALID_ADDRESS_OR_KEY`: Нема приватног кључа за ефективног потписника
- `RPC_WALLET_UNLOCK_NEEDED`: Новчаник који држи кључ ефективног потписника је закључан (откључајте са `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Ред чекања за слање је пун
- `RPC_INTERNAL_ERROR`: Неуспела иницијализација PoCX планера

**Кодови грешака валидације доказа**:
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

**Напомене**:
- Слање је асинхроно - RPC се одмах враћа, блок се кује касније
- Савијање времена одлаже добра решења да дозволи скенирање плотова широм мреже
- Систем додељивања: ако је плот додељен, новчаник мора имати кључ адресе ковања
- Границе компресије динамички подешене на основу висине блока

**Имплементација**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC-ови додељивања

### get_assignment

**Категорија**: mining
**Захтева сервер за рударење**: Не
**Захтева новчаник**: Не

**Сврха**: Упит статуса додељивања ковања за адресу плота. Само за читање, новчаник није потребан.

**Параметри**:
1. `plot_address` (стринг, обавезан) - Адреса плота (bech32 P2WPKH формат)
2. `height` (нумерички, опционо) - Висина блока за упит (подразумевано: тренутни врх)

**Повратне вредности** (без додељивања):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Повратне вредности** (активно додељивање):
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

**Повратне вредности** (опозивање):
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

**Стања додељивања**:
- `UNASSIGNED`: Нема додељивања
- `ASSIGNING`: Tx додељивања потврђен, кашњење активације у току
- `ASSIGNED`: Додељивање активно, права ковања делегирана
- `REVOKING`: Tx опозива потврђен, још увек активно до истека кашњења
- `REVOKED`: Опозив завршен, права ковања враћена власнику плота

**Кодови грешака**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Неважећа адреса или није P2WPKH (bech32)

**Пример**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Имплементација**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Категорија**: wallet
**Захтева сервер за рударење**: Не
**Захтева новчаник**: Да (мора бити учитан и откључан)

**Сврха**: Креира трансакцију додељивања за делегирање права ковања другој адреси (нпр. пулу за рударење).

**Параметри**:
1. `plot_address` (стринг, обавезан) - Адреса власника плота (мора имати приватни кључ, P2WPKH bech32)
2. `forging_address` (стринг, обавезан) - Адреса којој се додељују права ковања (P2WPKH bech32)
3. `fee_rate` (нумерички, опционо) - Стопа накнаде у BTCX/kvB (подразумевано: `0` → стандардна процена минималне накнаде новчаника; подразумевана вредност 10× minRelayFee примењује се само на Qt GUI дијалог, не на овај RPC)

**Повратне вредности**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Захтеви**:
- Новчаник учитан и откључан
- Приватни кључ за plot_address у новчанику
- Обе адресе морају бити P2WPKH (bech32 формат: pocx1q... mainnet, tpocx1q... testnet)
- Адреса плота мора имати потврђене UTXO-е (доказује власништво)
- Плот не сме имати активно додељивање (користите прво опозив)

**Структура трансакције**:
- Улаз: UTXO од адресе плота (доказује власништво)
- Излаз: OP_RETURN скрипта (46 бајтова) = `OP_RETURN` опкод + 1-бајтна дужина push-а + 44-бајтни корисни терет података (`POCX` маркер 4 + plot_address 20 + forging_address 20)
- Излаз: Кусур враћен новчанику

**Активација**:
- Додељивање постаје ASSIGNING при потврди
- Постаје ACTIVE након `nForgingAssignmentDelay` блокова
- Кашњење спречава брзо поновно додељивање током вилица ланца

**Кодови грешака**:
- `RPC_WALLET_NOT_FOUND`: Новчаник није доступан
- `RPC_WALLET_UNLOCK_NEEDED`: Новчаник шифрован и закључан
- `RPC_WALLET_ERROR`: Неуспело креирање трансакције
- `RPC_INVALID_ADDRESS_OR_KEY`: Неважећи формат адресе

**Пример**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Имплементација**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Категорија**: wallet
**Захтева сервер за рударење**: Не
**Захтева новчаник**: Да (мора бити учитан и откључан)

**Сврха**: Опозива постојеће додељивање ковања, враћајући права ковања власнику плота.

**Параметри**:
1. `plot_address` (стринг, обавезан) - Адреса плота (мора имати приватни кључ, P2WPKH bech32)
2. `fee_rate` (нумерички, опционо) - Стопа накнаде у BTCX/kvB (подразумевано: `0` → стандардна процена минималне накнаде новчаника; подразумевана вредност 10× minRelayFee примењује се само на Qt GUI дијалог, не на овај RPC)

**Повратне вредности**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Захтеви**:
- Новчаник учитан и откључан
- Приватни кључ за plot_address у новчанику
- Адреса плота мора бити P2WPKH (bech32 формат)
- Адреса плота мора имати потврђене UTXO-е

**Структура трансакције**:
- Улаз: UTXO од адресе плота (доказује власништво)
- Излаз: OP_RETURN скрипта (26 бајтова) = `OP_RETURN` опкод + 1-бајтна дужина push-а + 24-бајтни корисни терет података (`XCOP` маркер 4 + plot_address 20)
- Излаз: Кусур враћен новчанику

**Ефекат**:
- Стање одмах прелази у REVOKING
- Адреса ковања може још увек ковати током периода кашњења
- Постаје REVOKED након `nForgingRevocationDelay` блокова
- Власник плота може ковати након ефективног опозива
- Може креирати ново додељивање након завршетка опозива

**Кодови грешака**:
- `RPC_WALLET_NOT_FOUND`: Новчаник није доступан
- `RPC_WALLET_UNLOCK_NEEDED`: Новчаник шифрован и закључан
- `RPC_WALLET_ERROR`: Неуспело креирање трансакције

**Пример**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Напомене**:
- Идемпотентно: може опозвати чак и ако нема активног додељивања
- Не може отказати опозив када је послат

**Имплементација**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Модификовани блокчејн RPC-ови

### getdifficulty

**PoCX модификације**:
- **Израчунавање**: `reference_base_target / current_base_target`
- **Референца**: 1 TiB капацитет мреже (base_target = 36650387592)
- **Интерпретација**: Процењени капацитет складиштења мреже у TiB
  - Пример: `1.0` = ~1 TiB
  - Пример: `1024.0` = ~1 PiB
- **Разлика од PoW**: Представља капацитет, не hash power

**Пример**:
```bash
bitcoin-cli getdifficulty
# Враћа: 2048.5 (мрежа ~2 PiB)
```

**Имплементација**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX додата поља**:
- `time_since_last_block` (нумерички) - Секунди од претходног блока (замењује mediantime)
- `poc_time` (нумерички) - Време ковања савијено временом у секундама
- `base_target` (нумерички) - PoCX базни циљ тежине
- `generation_signature` (стринг хекс) - Генерацијски потпис
- `pocx_proof` (објекат):
  - `account_id` (стринг хекс) - ID налога плота (20 бајтова)
  - `seed` (стринг хекс) - Seed плота (32 бајта)
  - `nonce` (нумерички) - Nonce рударења
  - `compression` (нумерички) - Коришћени ниво скалирања
  - `quality` (нумерички) - Пријављена вредност квалитета
- `pubkey` (стринг хекс) - Јавни кључ потписника блока (33 бајта)
- `signer_address` (стринг) - Адреса потписника блока
- `signature` (стринг хекс) - Потпис блока (65 бајтова)

**PoCX уклоњена поља**:
- `mediantime` - Уклоњено (замењено са time_since_last_block)

**Пример**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Имплементација**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX модификације**: Исто као getblockheader, плус пуни подаци трансакција

**Пример**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # опширно са детаљима tx
```

**Имплементација**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX додата поља**:
- `base_target` (нумерички) - Тренутни базни циљ
- `generation_signature` (стринг хекс) - Тренутни генерацијски потпис

**PoCX модификована поља**:
- `difficulty` - Користи PoCX израчунавање (засновано на капацитету)

**PoCX уклоњена поља**:
- `mediantime` - Уклоњено

**Пример**:
```bash
bitcoin-cli getblockchaininfo
```

**Имплементација**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX додата поља**:
- `generation_signature` (стринг хекс) - За рударење у пулу
- `base_target` (нумерички) - За рударење у пулу

**PoCX уклоњена поља**:
- `target` - Removed (replaced by `base_target`)
- `noncerange` - Уклоњено (PoW-специфично)
- `bits` - Уклоњено (PoW-специфично)

**Напомене**:
- Још увек укључује пуне податке трансакција за конструкцију блока
- Користе га сервери пулова за координирано рударење

**Пример**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Имплементација**: `src/rpc/mining.cpp`

---

## Онемогућени RPC-ови

Следећи PoW-специфични RPC-ови су **онемогућени** у PoCX режиму:

### getnetworkhashps
- **Разлог**: Hash rate није примењив на Proof of Capacity
- **Алтернатива**: Користите `getdifficulty` за процену капацитета мреже

### getmininginfo
- **Разлог**: Враћа PoW-специфичне информације
- **Алтернатива**: Користите `get_mining_info` (PoCX-специфично)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Примери интеграције

### Интеграција спољног рудара

**Основна петља рударења**:
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

# Петља рударења
while True:
    # 1. Добави параметре рударења
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Скенирај плот датотеке (спољна имплементација)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Пошаљи најбоље решење (баца JSONRPCError при одбијању)
    try:
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
        print(f"Решење прихваћено! Квалитет: {result['raw_quality']}, "
              f"Време ковања: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Одбијено: {e}")

    # 4. Сачекај следећи блок
    time.sleep(10)  # Интервал испитивања
```

---

### Образац интеграције пула

**Ток рада сервера пула**:
1. Рудари креирају додељивања ковања на адресу пула
2. Пул покреће новчаник са кључевима адресе ковања
3. Пул позива `get_mining_info` и дистрибуира рударима
4. Рудари шаљу решења преко пула (не директно на ланац)
5. Пул валидира и позива `submit_nonce` са кључевима пула
6. Пул дистрибуира награде према политици пула

**Управљање додељивањима**:
```bash
# Рудар креира додељивање (из новчаника рудара)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Сачекај активацију (30 блокова mainnet)

# Пул проверава статус додељивања
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Пул сада може слати nonce-ове за овај плот
# (новчаник пула мора имати pocx1qpool... приватни кључ)
```

---

### Упити блок истраживача

**Упит података PoCX блока**:
```bash
# Добави најновији блок
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Добави детаље блока са PoCX доказом
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Извуци PoCX-специфична поља
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

**Детекција трансакција додељивања**:
```bash
# Скенирај трансакцију за OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Провери за маркер додељивања (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Руковање грешкама

### Уобичајени обрасци грешака

**Неподударање висине** (баца се `RPC_INVALID_PARAMETER`, код -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Решење**: Поново преузми информације о рударењу, ланац се померио унапред

**Неподударање генерацијског потписа** (баца се `RPC_VERIFY_REJECTED`, код -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Решење**: Поново преузми информације о рударењу, нови блок је стигао

**Нема приватног кључа**:
```json
{
  "code": -5,
  "message": "Нема доступног приватног кључа за ефективног потписника"
}
```
**Решење**: Увези кључ за адресу плота или ковања

**Активација додељивања у току**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Решење**: Сачекај да истекне кашњење активације

---

## Референце кода

**RPC-ови рударења**: `src/pocx/rpc/mining.cpp`
**RPC-ови додељивања**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Блокчејн RPC-ови**: `src/rpc/blockchain.cpp`
**Валидација доказа**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Стање додељивања**: `src/pocx/assignments/assignment_state.cpp`
**Креирање трансакција**: `src/pocx/assignments/transactions.cpp`

---

## Унакрсне референце

Повезана поглавља:
- [Поглавље 3: Консензус и рударење](3-consensus-and-mining.md) - Детаљи процеса рударења
- [Поглавље 4: Додељивања ковања](4-forging-assignments.md) - Архитектура система додељивања
- [Поглавље 6: Мрежни параметри](6-network-parameters.md) - Вредности кашњења додељивања
- [Поглавље 8: Водич за новчаник](8-wallet-guide.md) - GUI за управљање додељивањима

---

[← Претходно: Мрежни параметри](6-network-parameters.md) | [📘 Садржај](index.md) | [Следеће: Водич за новчаник →](8-wallet-guide.md)

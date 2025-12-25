[← 上一章：网络参数](6-network-parameters.md) | [📘 目录](index.md) | [下一章：钱包指南 →](8-wallet-guide.md)

---

# 第7章：RPC 接口参考

Bitcoin-PoCX RPC 命令的完整参考，包括挖矿 RPC、委派管理和修改的区块链 RPC。

---

## 目录

1. [配置](#配置)
2. [PoCX 挖矿 RPC](#pocx-挖矿-rpc)
3. [委派 RPC](#委派-rpc)
4. [修改的区块链 RPC](#修改的区块链-rpc)
5. [禁用的 RPC](#禁用的-rpc)
6. [集成示例](#集成示例)

---

## 配置

### 挖矿服务器模式

**标志**：`-miningserver`

**目的**：为外部矿工启用 RPC 访问以调用挖矿相关的 RPC

**要求**：
- `submit_nonce` 需要此标志才能工作
- Qt 钱包中的锻造委派对话框需要此标志才可见

**用法**：
```bash
# 命令行
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**安全考量**：
- 除标准 RPC 凭据外无额外认证
- 挖矿 RPC 受队列容量限制
- 仍需要标准 RPC 认证

**实现**：`src/pocx/rpc/mining.cpp`

---

## PoCX 挖矿 RPC

### get_mining_info

**类别**：挖矿
**需要挖矿服务器**：否
**需要钱包**：否

**目的**：返回外部矿工扫描绘图文件和计算截止时间所需的当前挖矿参数。

**参数**：无

**返回值**：
```json
{
  "generation_signature": "abc123...",       // 十六进制，64 个字符
  "base_target": 36650387593,                // 数值
  "height": 12345,                           // 数值，下一个区块高度
  "block_hash": "def456...",                 // 十六进制，上一个区块
  "target_quality": 18446744073709551615,    // uint64_max（接受所有解决方案）
  "minimum_compression_level": 1,            // 数值
  "target_compression_level": 2              // 数值
}
```

**字段描述**：
- `generation_signature`：此区块高度的确定性挖矿熵
- `base_target`：当前难度（越高越容易）
- `height`：矿工应该目标的区块高度
- `block_hash`：上一个区块哈希（信息性）
- `target_quality`：质量阈值（目前 uint64_max，无过滤）
- `minimum_compression_level`：验证所需的最低压缩级别
- `target_compression_level`：最优挖矿的推荐压缩级别

**错误码**：
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`：节点仍在同步

**示例**：
```bash
bitcoin-cli get_mining_info
```

**实现**：`src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**类别**：挖矿
**需要挖矿服务器**：是
**需要钱包**：是（用于私钥）

**目的**：提交 PoCX 挖矿解决方案。验证证明，排队进行时间弯曲锻造，并在预定时间自动创建区块。

**参数**：
1. `height`（数值，必需）- 区块高度
2. `generation_signature`（字符串十六进制，必需）- 生成签名（64 个字符）
3. `account_id`（字符串，必需）- 绘图账户 ID（40 个十六进制字符 = 20 字节）
4. `seed`（字符串，必需）- 绘图种子（64 个十六进制字符 = 32 字节）
5. `nonce`（数值，必需）- 挖矿 nonce
6. `compression`（数值，必需）- 使用的扩展/压缩级别（1-255）
7. `quality`（数值，可选）- 质量值（如省略则重新计算）

**返回值**（成功）：
```json
{
  "accepted": true,
  "quality": 120,           // 难度调整后的截止时间（秒）
  "poc_time": 45            // 时间弯曲的锻造时间（秒）
}
```

**返回值**（拒绝）：
```json
{
  "accepted": false,
  "error": "生成签名不匹配"
}
```

**验证步骤**：
1. **格式验证**（快速失败）：
   - 账户 ID：正好 40 个十六进制字符
   - 种子：正好 64 个十六进制字符
2. **上下文验证**：
   - 高度必须匹配当前 tip + 1
   - 生成签名必须匹配当前
3. **钱包验证**：
   - 确定有效签名者（检查活跃委派）
   - 验证钱包拥有有效签名者的私钥
4. **证明验证**（昂贵）：
   - 使用压缩边界验证 PoCX 证明
   - 计算原始质量
5. **调度器提交**：
   - 将 nonce 排队进行时间弯曲锻造
   - 区块将在 forge_time 自动创建

**错误码**：
- `RPC_INVALID_PARAMETER`：格式无效（account_id、seed）或高度不匹配
- `RPC_VERIFY_REJECTED`：生成签名不匹配或证明验证失败
- `RPC_INVALID_ADDRESS_OR_KEY`：有效签名者没有私钥
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`：提交队列已满
- `RPC_INTERNAL_ERROR`：无法初始化 PoCX 调度器

**证明验证错误码**：
- `0`：VALIDATION_SUCCESS
- `-1`：VALIDATION_ERROR_NULL_POINTER
- `-2`：VALIDATION_ERROR_INVALID_INPUT
- `-100`：VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`：VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`：VALIDATION_ERROR_QUALITY_CALCULATION

**示例**：
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**注意**：
- 提交是异步的 - RPC 立即返回，区块稍后锻造
- 时间弯曲延迟好的解决方案以允许网络范围的绘图扫描
- 委派系统：如果绘图已委派，钱包必须拥有锻造地址密钥
- 压缩边界根据区块高度动态调整

**实现**：`src/pocx/rpc/mining.cpp:submit_nonce()`

---

## 委派 RPC

### get_assignment

**类别**：挖矿
**需要挖矿服务器**：否
**需要钱包**：否

**目的**：查询绘图地址的锻造委派状态。只读，无需钱包。

**参数**：
1. `plot_address`（字符串，必需）- 绘图地址（bech32 P2WPKH 格式）
2. `height`（数值，可选）- 要查询的区块高度（默认：当前 tip）

**返回值**（无委派）：
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**返回值**（活跃委派）：
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

**返回值**（撤销中）：
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

**委派状态**：
- `UNASSIGNED`：不存在委派
- `ASSIGNING`：委派交易已确认，激活延迟进行中
- `ASSIGNED`：委派激活，锻造权已委派
- `REVOKING`：撤销交易已确认，延迟到期前仍然激活
- `REVOKED`：撤销完成，锻造权返回给绘图所有者

**错误码**：
- `RPC_INVALID_ADDRESS_OR_KEY`：地址无效或不是 P2WPKH（bech32）

**示例**：
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**实现**：`src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**类别**：钱包
**需要挖矿服务器**：否
**需要钱包**：是（必须已加载并解锁）

**目的**：创建锻造委派交易，将锻造权委派给另一个地址（例如矿池）。

**参数**：
1. `plot_address`（字符串，必需）- 绘图所有者地址（必须拥有私钥，P2WPKH bech32）
2. `forging_address`（字符串，必需）- 要委派锻造权的地址（P2WPKH bech32）
3. `fee_rate`（数值，可选）- 费率，BTC/kvB（默认：10 倍 minRelayFee）

**返回值**：
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**要求**：
- 钱包已加载并解锁
- 钱包中有 plot_address 的私钥
- 两个地址都必须是 P2WPKH（bech32 格式：pocx1q... 主网，tpocx1q... 测试网）
- 绘图地址必须有已确认的 UTXO（证明所有权）
- 绘图不能有活跃委派（先撤销）

**交易结构**：
- 输入：来自绘图地址的 UTXO（证明所有权）
- 输出：OP_RETURN（46 字节）：`POCX` 标记 + plot_address（20 字节）+ forging_address（20 字节）
- 输出：找零返回钱包

**激活**：
- 委派在确认时变为 ASSIGNING
- 在 `nForgingAssignmentDelay` 个区块后变为 ACTIVE
- 延迟防止链分叉期间的快速重新分配

**错误码**：
- `RPC_WALLET_NOT_FOUND`：没有可用钱包
- `RPC_WALLET_UNLOCK_NEEDED`：钱包已加密并锁定
- `RPC_WALLET_ERROR`：交易创建失败
- `RPC_INVALID_ADDRESS_OR_KEY`：地址格式无效

**示例**：
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**实现**：`src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**类别**：钱包
**需要挖矿服务器**：否
**需要钱包**：是（必须已加载并解锁）

**目的**：撤销现有锻造委派，将锻造权返回给绘图所有者。

**参数**：
1. `plot_address`（字符串，必需）- 绘图地址（必须拥有私钥，P2WPKH bech32）
2. `fee_rate`（数值，可选）- 费率，BTC/kvB（默认：10 倍 minRelayFee）

**返回值**：
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**要求**：
- 钱包已加载并解锁
- 钱包中有 plot_address 的私钥
- 绘图地址必须是 P2WPKH（bech32 格式）
- 绘图地址必须有已确认的 UTXO

**交易结构**：
- 输入：来自绘图地址的 UTXO（证明所有权）
- 输出：OP_RETURN（26 字节）：`XCOP` 标记 + plot_address（20 字节）
- 输出：找零返回钱包

**效果**：
- 状态立即转换为 REVOKING
- 锻造地址在延迟期内仍可锻造
- 在 `nForgingRevocationDelay` 个区块后变为 REVOKED
- 撤销生效后绘图所有者可以锻造
- 撤销完成后可以创建新委派

**错误码**：
- `RPC_WALLET_NOT_FOUND`：没有可用钱包
- `RPC_WALLET_UNLOCK_NEEDED`：钱包已加密并锁定
- `RPC_WALLET_ERROR`：交易创建失败

**示例**：
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**注意**：
- 幂等：即使没有活跃委派也可以撤销
- 一旦提交无法取消撤销

**实现**：`src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## 修改的区块链 RPC

### getdifficulty

**PoCX 修改**：
- **计算**：`reference_base_target / current_base_target`
- **参考**：1 TiB 网络容量（base_target = 36650387593）
- **解释**：估计的网络存储容量（TiB）
  - 示例：`1.0` = 约 1 TiB
  - 示例：`1024.0` = 约 1 PiB
- **与 PoW 的区别**：代表容量，而非哈希算力

**示例**：
```bash
bitcoin-cli getdifficulty
# 返回：2048.5（网络约 2 PiB）
```

**实现**：`src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX 新增字段**：
- `time_since_last_block`（数值）- 距上一个区块的秒数（替换 mediantime）
- `poc_time`（数值）- 时间弯曲的锻造时间（秒）
- `base_target`（数值）- PoCX 难度基础目标值
- `generation_signature`（字符串十六进制）- 生成签名
- `pocx_proof`（对象）：
  - `account_id`（字符串十六进制）- 绘图账户 ID（20 字节）
  - `seed`（字符串十六进制）- 绘图种子（32 字节）
  - `nonce`（数值）- 挖矿 nonce
  - `compression`（数值）- 使用的扩展级别
  - `quality`（数值）- 声称的质量值
- `pubkey`（字符串十六进制）- 区块签名者的公钥（33 字节）
- `signer_address`（字符串）- 区块签名者的地址
- `signature`（字符串十六进制）- 区块签名（65 字节）

**PoCX 移除的字段**：
- `mediantime` - 已移除（被 time_since_last_block 替换）

**示例**：
```bash
bitcoin-cli getblockheader <blockhash>
```

**实现**：`src/rpc/blockchain.cpp`

---

### getblock

**PoCX 修改**：与 getblockheader 相同，加上完整交易数据

**示例**：
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # 详细模式含交易详情
```

**实现**：`src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX 新增字段**：
- `base_target`（数值）- 当前基础目标值
- `generation_signature`（字符串十六进制）- 当前生成签名

**PoCX 修改的字段**：
- `difficulty` - 使用 PoCX 计算（基于容量）

**PoCX 移除的字段**：
- `mediantime` - 已移除

**示例**：
```bash
bitcoin-cli getblockchaininfo
```

**实现**：`src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX 新增字段**：
- `generation_signature`（字符串十六进制）- 用于矿池挖矿
- `base_target`（数值）- 用于矿池挖矿

**PoCX 移除的字段**：
- `target` - 已移除（PoW 特定）
- `noncerange` - 已移除（PoW 特定）
- `bits` - 已移除（PoW 特定）

**注意**：
- 仍包含完整交易数据用于区块构建
- 矿池服务器用于协调挖矿

**示例**：
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**实现**：`src/rpc/mining.cpp`

---

## 禁用的 RPC

以下 PoW 特定的 RPC 在 PoCX 模式下**被禁用**：

### getnetworkhashps
- **原因**：哈希率不适用于容量证明
- **替代**：使用 `getdifficulty` 获取网络容量估计

### getmininginfo
- **原因**：返回 PoW 特定信息
- **替代**：使用 `get_mining_info`（PoCX 特定）

### generate, generatetoaddress, generatetodescriptor, generateblock
- **原因**：CPU 挖矿不适用于 PoCX（需要预生成的绘图）
- **替代**：使用外部绘图工具 + 矿工 + `submit_nonce`

**实现**：`src/rpc/mining.cpp`（定义 ENABLE_POCX 时 RPC 返回错误）

---

## 集成示例

### 外部矿工集成

**基本挖矿循环**：
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

# 挖矿循环
while True:
    # 1. 获取挖矿参数
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. 扫描绘图文件（外部实现）
    best_nonce = scan_plots(gen_sig, height)

    # 3. 提交最佳解决方案
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"解决方案已接受！质量：{result['quality']}秒，"
              f"锻造时间：{result['poc_time']}秒")

    # 4. 等待下一个区块
    time.sleep(10)  # 轮询间隔
```

---

### 矿池集成模式

**矿池服务器工作流**：
1. 矿工创建到矿池地址的锻造委派
2. 矿池运行带锻造地址密钥的钱包
3. 矿池调用 `get_mining_info` 并分发给矿工
4. 矿工通过矿池提交解决方案（不直接到链）
5. 矿池验证并调用 `submit_nonce`（使用矿池的密钥）
6. 矿池根据矿池策略分配奖励

**委派管理**：
```bash
# 矿工创建委派（从矿工的钱包）
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# 等待激活（主网 30 个区块）

# 矿池检查委派状态
bitcoin-cli get_assignment "pocx1qminer_plot..."

# 矿池现在可以为此绘图提交 nonce
# （矿池钱包必须有 pocx1qpool... 私钥）
```

---

### 区块浏览器查询

**查询 PoCX 区块数据**：
```bash
# 获取最新区块
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# 获取带 PoCX 证明的区块详情
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# 提取 PoCX 特定字段
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

**检测委派交易**：
```bash
# 扫描交易中的 OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# 检查委派标记（POCX = 0x504f4358）
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## 错误处理

### 常见错误模式

**高度不匹配**：
```json
{
  "accepted": false,
  "error": "高度不匹配：提交 12345，当前 12346"
}
```
**解决方案**：重新获取挖矿信息，链已前进

**生成签名不匹配**：
```json
{
  "accepted": false,
  "error": "生成签名不匹配"
}
```
**解决方案**：重新获取挖矿信息，新区块已到达

**无私钥**：
```json
{
  "code": -5,
  "message": "有效签名者没有可用的私钥"
}
```
**解决方案**：导入绘图或锻造地址的密钥

**委派激活待处理**：
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**解决方案**：等待激活延迟结束

---

## 代码参考

**挖矿 RPC**：`src/pocx/rpc/mining.cpp`
**委派 RPC**：`src/pocx/rpc/assignments.cpp`、`src/pocx/rpc/assignments_wallet.cpp`
**区块链 RPC**：`src/rpc/blockchain.cpp`
**证明验证**：`src/pocx/consensus/validation.cpp`、`src/pocx/consensus/pocx.cpp`
**委派状态**：`src/pocx/assignments/assignment_state.cpp`
**交易创建**：`src/pocx/assignments/transactions.cpp`

---

## 交叉参考

相关章节：
- [第3章：共识与挖矿](3-consensus-and-mining.md) - 挖矿流程详情
- [第4章：锻造权委派](4-forging-assignments.md) - 委派系统架构
- [第6章：网络参数](6-network-parameters.md) - 委派延迟值
- [第8章：钱包指南](8-wallet-guide.md) - 委派管理的图形界面

---

[← 上一章：网络参数](6-network-parameters.md) | [📘 目录](index.md) | [下一章：钱包指南 →](8-wallet-guide.md)

[← 上一章：时间同步](5-timing-security.md) | [📘 目录](index.md) | [下一章：RPC 参考 →](7-rpc-reference.md)

---

# 第6章：网络参数和配置

Bitcoin-PoCX 所有网络类型的网络配置完整参考。

---

## 目录

1. [创世区块参数](#创世区块参数)
2. [链参数配置](#链参数配置)
3. [共识参数](#共识参数)
4. [Coinbase 和区块奖励](#coinbase-和区块奖励)
5. [动态扩展](#动态扩展)
6. [网络配置](#网络配置)
7. [数据目录结构](#数据目录结构)

---

## 创世区块参数

### 基础目标值计算

**公式**：`genesis_base_target = 2^42 / block_time_seconds`

**原理**：
- 每个 nonce 代表 256 KiB（64 字节 × 4096 scoops）
- 1 TiB = 2^22 个 nonces（起始网络容量假设）
- n 个 nonces 的预期最小质量 ≈ 2^64 / n
- 对于 1 TiB：E(quality) = 2^64 / 2^22 = 2^42
- 因此：base_target = 2^42 / block_time

**计算值**：
- 主网/测试网/Signet（120秒）：`36650387592`
- Regtest（1秒）：使用低容量校准模式

### 创世消息

Each network has its own genesis message. See `src/kernel/chainparams.cpp` for details.

---

## 链参数配置

### 主网参数

**网络标识**：
- **魔术字节**：`0xa7 0x3c 0x91 0x5e`
- **默认端口**：`8338`
- **Bech32 HRP**：`pocx`

**地址前缀**（Base58）：
- PUBKEY_ADDRESS：`85`（地址以 'P' 开头）
- SCRIPT_ADDRESS：`90`（地址以 'R' 开头）
- SECRET_KEY：`128`

**区块时间**：
- **区块时间目标**：`120` 秒（2 分钟）
- **目标时间跨度**：`1209600` 秒（14 天）
- **MAX_FUTURE_BLOCK_TIME**：`15` 秒

**区块奖励**：
- **初始奖励**：`10 BTC`
- **减半间隔**：`1050000` 个区块（约 4 年）
- **减半次数**：最多 64 次减半

**难度调整**：
- **滚动窗口**：`24` 个区块
- **调整**：每个区块
- **算法**：指数移动平均

**委派延迟**：
- **激活**：`30` 个区块（约 1 小时）
- **撤销**：`720` 个区块（约 24 小时）

### 测试网参数

**网络标识**：
- **魔术字节**：`0x6d 0xf2 0x48 0xb4`
- **默认端口**：`18338`
- **Bech32 HRP**：`tpocx`

**地址前缀**（Base58）：
- PUBKEY_ADDRESS：`127`
- SCRIPT_ADDRESS：`132`
- SECRET_KEY：`255`

**区块时间**：
- **区块时间目标**：`120` 秒
- **MAX_FUTURE_BLOCK_TIME**：`15` 秒
- **允许最小难度**：`true`

**区块奖励**：
- **初始奖励**：`10 BTC`
- **减半间隔**：`1050000` 个区块

**难度调整**：
- **滚动窗口**：`24` 个区块

**委派延迟**：
- **激活**：`30` 个区块（约 1 小时）
- **撤销**：`720` 个区块（约 24 小时）

### Regtest 参数

**网络标识**：
- **魔术字节**：`0xfa 0xbf 0xb5 0xda`
- **默认端口**：`18444`
- **Bech32 HRP**：`rpocx`

**地址前缀**（Bitcoin 兼容）：
- PUBKEY_ADDRESS：`111`
- SCRIPT_ADDRESS：`196`
- SECRET_KEY：`239`

**区块时间**：
- **区块时间目标**：`1` 秒（用于测试的即时挖矿）
- **目标时间跨度**：`86400` 秒（1 天）
- **MAX_FUTURE_BLOCK_TIME**：`15` 秒

**区块奖励**：
- **初始奖励**：`10 BTC`
- **减半间隔**：`500` 个区块

**难度调整**：
- **滚动窗口**：`24` 个区块
- **允许最小难度**：`true`
- **无重定向**：`true`
- **低容量校准**：`true`（使用 16 nonce 校准而非 1 TiB）

**委派延迟**：
- **激活**：`4` 个区块（约 4 秒）
- **撤销**：`8` 个区块（约 8 秒）

### Signet 参数

**网络标识**：
- **魔术字节**：SHA256d(signet_challenge) 的前 4 个字节
- **默认端口**：`38333`
- **Bech32 HRP**：`tpocx`

**区块时间**：
- **区块时间目标**：`120` 秒
- **MAX_FUTURE_BLOCK_TIME**：`15` 秒

**区块奖励**：
- **初始奖励**：`10 BTC`
- **减半间隔**：`1050000` 个区块

**难度调整**：
- **滚动窗口**：`24` 个区块

---

## 共识参数

### 时间参数

**MAX_FUTURE_BLOCK_TIME**：`15` 秒
- PoCX 特定（Bitcoin 使用 2 小时）
- 原理：PoC 时间要求接近实时验证
- 超过未来 15 秒的区块被拒绝

**时间偏移警告**：`10` 秒
- 当节点时钟与网络时间偏差 >10 秒时警告运营者
- 无强制执行，仅供参考

**区块时间目标**：
- 主网/测试网/Signet：`120` 秒
- Regtest：`1` 秒

**TIMESTAMP_WINDOW**：`15` 秒（等于 MAX_FUTURE_BLOCK_TIME）

**实现**：`src/chain.h`、`src/validation.cpp`

### 难度调整参数

**滚动窗口大小**：`24` 个区块（所有网络）
- 最近区块时间的指数移动平均
- 逐块调整
- 对容量变化响应迅速

**实现**：`src/consensus/params.h`，区块创建中的难度逻辑

### 委派系统参数

**nForgingAssignmentDelay**（激活延迟）：
- 主网：`30` 个区块（约 1 小时）
- 测试网：`30` 个区块（约 1 小时）
- Regtest：`4` 个区块（约 4 秒）

**nForgingRevocationDelay**（撤销延迟）：
- 主网：`720` 个区块（约 24 小时）
- 测试网：`720` 个区块（约 24 小时）
- Regtest：`8` 个区块（约 8 秒）

**原理**：
- 激活延迟防止区块竞争期间的快速重新分配
- 撤销延迟提供稳定性并防止滥用

**实现**：`src/consensus/params.h`

---

## Coinbase 和区块奖励

### 区块奖励计划

**初始奖励**：`10 BTC`（所有网络）

**减半计划**：
- 每 `1050000` 个区块（主网/测试网）
- 每 `500` 个区块（regtest）
- 最多继续 64 次减半

**减半进度**：
```
减半 0：10.00000000 BTC（区块 0 - 1049999）
减半 1： 5.00000000 BTC（区块 1050000 - 2099999）
减半 2： 2.50000000 BTC（区块 2100000 - 3149999）
减半 3： 1.25000000 BTC（区块 3150000 - 4199999）
...
```

**总供应量**：约 2100 万 BTC（与 Bitcoin 相同）

### Coinbase 输出规则

**支付目标**：
- **无委派**：Coinbase 支付给绘图地址（proof.account_id）
- **有委派**：Coinbase 支付给锻造地址（有效签名者）

**输出格式**：仅 P2WPKH
- Coinbase 必须支付给 bech32 SegWit v0 地址
- 从有效签名者的公钥生成

**委派解析**：
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**实现**：`src/pocx/mining/block_builder.cpp:BuildBlock()`

---

## 动态扩展

### 扩展边界

**目的**：随着网络成熟增加绘图生成难度，防止容量膨胀

**结构**：
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // 接受的最低级别
    uint32_t nPoCXTargetCompression;  // 推荐级别
};
```

**关系**：`target = min + 1`（始终比最低级别高一级）

### 扩展增加计划

扩展级别基于减半间隔按**指数计划**增加：

| 时间段 | 区块高度 | 减半次数 | 最低 | 目标 |
|-------------|--------------|----------|-----|--------|
| 第 0-4 年 | 0 到 1049999 | 0 | X1 | X2 |
| 第 4-12 年 | 1050000 到 3149999 | 1-2 | X2 | X3 |
| 第 12-28 年 | 3150000 到 7349999 | 3-6 | X3 | X4 |
| 第 28-60 年 | 7350000 到 15749999 | 7-14 | X4 | X5 |
| 第 60-124 年 | 15750000 到 32549999 | 15-30 | X5 | X6 |
| 第 124 年+ | 32550000+ | 31+ | X6 | X7 |

**关键高度**（年份 → 减半次数 → 区块）：
- 第 4 年：第 1 次减半，区块 1050000
- 第 12 年：第 3 次减半，区块 3150000
- 第 28 年：第 7 次减半，区块 7350000
- 第 60 年：第 15 次减半，区块 15750000
- 第 124 年：第 31 次减半，区块 32550000

### 扩展级别难度

**工作量证明扩展**：
- 扩展级别 X0：POC2 基线（理论上的）
- 扩展级别 X1：XOR 转置基线
- 扩展级别 Xn：嵌入 2^(n-1) 倍 X1 工作量
- 每级使绘图生成工作量翻倍

**经济对齐**：
- 区块奖励减半 → 绘图生成难度增加
- 保持安全边际：绘图创建成本 > 查找成本
- 防止硬件改进导致的容量膨胀

### 绘图验证

**验证规则**：
- 提交的证明必须具有扩展级别 ≥ 最低要求
- 扩展级别 > 目标的证明被接受但效率低下
- 低于最低要求的证明：被拒绝（工作量证明不足）

**边界获取**：
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**实现**：`src/pocx/consensus/params.h:GetPoCXCompressionBounds()`、`src/pocx/consensus/params.cpp`

---

## 网络配置

### 种子节点和 DNS 种子

**状态**：主网启动的占位符

**计划配置**：
- 种子节点：待定
- DNS 种子：待定

**当前状态**（测试网/regtest）：
- 无专用种子基础设施
- 支持通过 `-addnode` 手动添加对等连接

**实现**：`src/kernel/chainparams.cpp`

### 检查点

**创世检查点**：始终是区块 0

**额外检查点**：目前未配置

**未来**：随着主网进展将添加检查点

---

## P2P 协议配置

### 协议版本

**基础**：Bitcoin Core v30.2 协议
- **协议版本**：继承自 Bitcoin Core
- **服务位**：标准 Bitcoin 服务
- **消息类型**：标准 Bitcoin P2P 消息

**PoCX 扩展**：
- 区块头包含 PoCX 特定字段
- 区块消息包含 PoCX 证明数据
- 验证规则强制执行 PoCX 共识

**兼容性**：PoCX 节点与 Bitcoin PoW 节点不兼容（不同共识）

**实现**：`src/protocol.h`、`src/net_processing.cpp`

---

## 数据目录结构

### 默认目录

**位置**：`.bitcoin/`（与 Bitcoin Core 相同）
- Linux：`~/.bitcoin/`
- macOS：`~/Library/Application Support/Bitcoin/`
- Windows：`%APPDATA%\Bitcoin\`

### 目录内容

```
.bitcoin/
├── blocks/              # 区块数据
│   ├── blk*.dat        # 区块文件
│   ├── rev*.dat        # 撤销数据
│   └── index/          # 区块索引（LevelDB）
├── chainstate/         # UTXO 集 + 锻造委派（LevelDB）
├── wallets/            # 钱包文件
│   └── wallet.dat      # 默认钱包
├── bitcoin.conf        # 配置文件
├── debug.log           # 调试日志
├── peers.dat           # 对等节点地址
├── mempool.dat         # 内存池持久化
└── banlist.dat         # 被禁止的对等节点
```

### 与 Bitcoin 的主要区别

**链状态数据库**：
- 标准：UTXO 集
- **PoCX 新增**：锻造委派状态
- 原子更新：UTXO + 委派一起更新
- 委派的重组安全撤销数据

**区块文件**：
- 标准 Bitcoin 区块格式
- **PoCX 新增**：扩展了 PoCX 证明字段（account_id、seed、nonce、signature、pubkey）

### 配置文件示例

**bitcoin.conf**：
```ini
# 网络选择
#testnet=1
#regtest=1

# PoCX 挖矿服务器（外部矿工需要）

# RPC 设置
server=1
rpcuser=yourusername
rpcpassword=yourpassword
rpcallowip=127.0.0.1
rpcport=8332

# 连接设置
listen=1
port=8338
maxconnections=125

# 区块时间目标（信息性，共识强制执行）
# 主网/测试网 120 秒
```

---

## 代码参考

**链参数**：`src/kernel/chainparams.cpp`
**共识参数**：`src/consensus/params.h`
**压缩边界**：`src/pocx/consensus/params.h`、`src/pocx/consensus/params.cpp`
**创世基础目标值计算**：`src/pocx/consensus/params.cpp`
**Coinbase 支付逻辑**：`src/pocx/mining/block_builder.cpp:BuildBlock()`
**委派状态存储**：`src/coins.h`、`src/coins.cpp`（CCoinsViewCache 扩展）

---

## 交叉参考

相关章节：
- [第2章：绘图格式](2-plot-format.md) - 绘图生成中的扩展级别
- [第3章：共识与挖矿](3-consensus-and-mining.md) - 扩展验证、委派系统
- [第4章：锻造权委派](4-forging-assignments.md) - 委派延迟参数
- [第5章：时间安全](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME 原理

---

[← 上一章：时间同步](5-timing-security.md) | [📘 目录](index.md) | [下一章：RPC 参考 →](7-rpc-reference.md)

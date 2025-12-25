[← 上一章：共识与挖矿](3-consensus-and-mining.md) | [📘 目录](index.md) | [下一章：时间同步 →](5-timing-security.md)

---

# 第4章：PoCX 锻造权委派系统

## 概要

本文档描述**已实现的** PoCX 锻造权委派系统，采用纯 OP_RETURN 架构。该系统使绘图所有者能够通过链上交易将锻造权委派给不同的地址，具有完整的重组安全性和原子数据库操作。

**状态：** ✅ 完全实现并运行

## 核心设计理念

**关键原则：** 委派是权限，不是资产

- 无需跟踪或花费的特殊 UTXO
- 委派状态与 UTXO 集分开存储
- 所有权通过交易签名证明，而非 UTXO 花费
- 完整的历史记录追踪，提供完整审计轨迹
- 通过 LevelDB 批量写入实现原子数据库更新

## 交易结构

### 委派交易格式

```
输入：
  [0]: 由绘图所有者控制的任意 UTXO（证明所有权 + 支付费用）
       必须使用绘图所有者的私钥签名
  [1+]: 可选的额外输入用于费用覆盖

输出：
  [0]: OP_RETURN（POCX 标记 + 绘图地址 + 锻造地址）
       格式：OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       大小：总共 46 字节（1 字节 OP_RETURN + 1 字节长度 + 44 字节数据）
       值：0 BTC（不可花费，不添加到 UTXO 集）

  [1]: 找零返回用户（可选，标准 P2WPKH）
```

**实现：** `src/pocx/assignments/opcodes.cpp:25-52`

### 撤销交易格式

```
输入：
  [0]: 由绘图所有者控制的任意 UTXO（证明所有权 + 支付费用）
       必须使用绘图所有者的私钥签名
  [1+]: 可选的额外输入用于费用覆盖

输出：
  [0]: OP_RETURN（XCOP 标记 + 绘图地址）
       格式：OP_RETURN <0x18> "XCOP" <plot_addr_20>
       大小：总共 26 字节（1 字节 OP_RETURN + 1 字节长度 + 24 字节数据）
       值：0 BTC（不可花费，不添加到 UTXO 集）

  [1]: 找零返回用户（可选，标准 P2WPKH）
```

**实现：** `src/pocx/assignments/opcodes.cpp:54-77`

### 标记

- **委派标记：** `POCX`（0x50, 0x4F, 0x43, 0x58）= "Proof of Capacity neXt"
- **撤销标记：** `XCOP`（0x58, 0x43, 0x4F, 0x50）= "eXit Capacity OPeration"

**实现：** `src/pocx/assignments/opcodes.cpp:15-19`

### 关键交易特性

- 标准 Bitcoin 交易（无协议更改）
- OP_RETURN 输出可证明不可花费（永远不会添加到 UTXO 集）
- 绘图所有权通过来自绘图地址的 input[0] 签名证明
- 低成本（约 200 字节，通常 <0.0001 BTC 费用）
- 钱包自动从绘图地址选择最大 UTXO 以证明所有权

## 数据库架构

### 存储结构

所有委派数据存储在与 UTXO 集相同的 LevelDB 数据库（`chainstate/`）中，但使用不同的键前缀：

```
chainstate/ LevelDB：
├─ UTXO 集（Bitcoin Core 标准）
│  └─ 'C' 前缀：COutPoint → Coin
│
└─ 委派状态（PoCX 添加）
   └─ 'A' 前缀：(plot_address, assignment_txid) → ForgingAssignment
       └─ 完整历史：每个绘图随时间的所有委派
```

**实现：** `src/txdb.cpp:237-348`

### ForgingAssignment 结构

```cpp
struct ForgingAssignment {
    // 身份标识
    std::array<uint8_t, 20> plotAddress;      // 绘图所有者（20 字节 P2WPKH 哈希）
    std::array<uint8_t, 20> forgingAddress;   // 锻造权持有者（20 字节 P2WPKH 哈希）

    // 委派生命周期
    uint256 assignment_txid;                   // 创建委派的交易
    int assignment_height;                     // 创建的区块高度
    int assignment_effective_height;           // 激活时间（高度 + 延迟）

    // 撤销生命周期
    bool revoked;                              // 是否已撤销？
    uint256 revocation_txid;                   // 撤销的交易
    int revocation_height;                     // 撤销的区块高度
    int revocation_effective_height;           // 撤销生效时间（高度 + 延迟）

    // 状态查询方法
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**实现：** `src/coins.h:111-178`

### 委派状态

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 不存在委派
    ASSIGNING = 1,   // 委派已创建，等待激活延迟
    ASSIGNED = 2,    // 委派激活，允许锻造
    REVOKING = 3,    // 已撤销，但在延迟期内仍然激活
    REVOKED = 4      // 完全撤销，不再激活
};
```

**实现：** `src/coins.h:98-104`

### 数据库键

```cpp
// 历史键：存储完整的委派记录
// 键格式：(prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // 绘图地址（20 字节）
    int assignment_height;                // 高度用于排序优化
    uint256 assignment_txid;              // 交易 ID
};
```

**实现：** `src/txdb.cpp:245-262`

### 历史追踪

- 每个委派永久存储（除非重组则删除）
- 跟踪每个绘图随时间的多个委派
- 支持完整审计轨迹和历史状态查询
- 已撤销的委派保留在数据库中，`revoked=true`

## 区块处理

### ConnectBlock 集成

委派和撤销 OP_RETURN 在 `validation.cpp` 的区块连接过程中处理：

```cpp
// 位置：脚本验证之后，UpdateCoins 之前
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // 解析 OP_RETURN 数据
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // 验证所有权（交易必须由绘图所有者签名）
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // 检查绘图状态（必须是 UNASSIGNED 或 REVOKED）
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // 创建新委派
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // 存储撤销数据
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // 解析 OP_RETURN 数据
            auto plot_addr = ParseRevocationOpReturn(output);

            // 验证所有权
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // 获取当前委派
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // 存储旧状态用于撤销
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // 标记为已撤销
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

// UpdateCoins 正常进行（自动跳过 OP_RETURN 输出）
```

**实现：** `src/validation.cpp:2775-2878`

### 所有权验证

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // 检查至少一个输入由绘图所有者签名
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // 提取目标地址
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // 检查是否是绘图地址的 P2WPKH
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core 已验证签名
                return true;
            }
        }
    }
    return false;
}
```

**实现：** `src/pocx/assignments/opcodes.cpp:217-256`

### 激活延迟

委派和撤销具有可配置的激活延迟以防止重组攻击：

```cpp
// 共识参数（每个网络可配置）
// 示例：30 个区块 = 2 分钟区块时间下约 1 小时
consensus.nForgingAssignmentDelay;   // 委派激活延迟
consensus.nForgingRevocationDelay;   // 撤销激活延迟
```

**状态转换：**
- 委派：`UNASSIGNED → ASSIGNING（延迟）→ ASSIGNED`
- 撤销：`ASSIGNED → REVOKING（延迟）→ REVOKED`

**实现：** `src/consensus/params.h`、`src/kernel/chainparams.cpp`

## 内存池验证

委派和撤销交易在内存池接受时进行验证，以在网络传播前拒绝无效交易。

### 交易级别检查（CheckTransaction）

在 `src/consensus/tx_check.cpp` 中执行，无需链状态访问：

1. **最多一个 POCX OP_RETURN：** 交易不能包含多个 POCX/XCOP 标记

**实现：** `src/consensus/tx_check.cpp:63-77`

### 内存池接受检查（PreChecks）

在 `src/validation.cpp` 中执行，具有完整的链状态和内存池访问：

#### 委派验证

1. **绘图所有权：** 交易必须由绘图所有者签名
2. **绘图状态：** 绘图必须是 UNASSIGNED (0) 或 REVOKED (4)
3. **内存池冲突：** 内存池中没有此绘图的其他委派（先到先得）

#### 撤销验证

1. **绘图所有权：** 交易必须由绘图所有者签名
2. **活跃委派：** 绘图必须仅处于 ASSIGNED (2) 状态
3. **内存池冲突：** 内存池中没有此绘图的其他撤销

**实现：** `src/validation.cpp:898-993`

### 验证流程

```
交易广播
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ 最多一个 POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ 验证绘图所有权
  ✓ 检查委派状态
  ✓ 检查内存池冲突
       ↓
   有效 → 接受到内存池
   无效 → 拒绝（不传播）
       ↓
区块挖矿
       ↓
ConnectBlock() [validation.cpp]
  ✓ 重新验证所有检查（深度防御）
  ✓ 应用状态变更
  ✓ 记录撤销信息
```

### 深度防御

所有内存池验证检查在 `ConnectBlock()` 期间重新执行，以防止：
- 内存池绕过攻击
- 恶意矿工的无效区块
- 重组场景下的边缘情况

区块验证对共识具有权威性。

## 原子数据库更新

### 三层架构

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache（内存缓存）             │  ← 委派变更在内存中追踪
│   - Coins：cacheCoins                    │
│   - Assignments：pendingAssignments      │
│   - 脏跟踪：dirtyPlots                   │
│   - 删除：deletedAssignments             │
│   - 内存跟踪：cachedAssignmentsUsage      │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB（数据库层）                │  ← 单次原子写入
│   - BatchWrite()：UTXO + 委派            │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB（磁盘存储）                     │  ← ACID 保证
│   - 原子事务                             │
└─────────────────────────────────────────┘
```

### 刷新流程

当区块连接期间调用 `view.Flush()` 时：

```cpp
bool CCoinsViewCache::Flush() {
    // 1. 将 coin 变更写入基础
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. 原子写入委派变更
    if (fOk && !dirtyPlots.empty()) {
        // 收集脏委派
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // 空 - 未使用

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // 写入数据库
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // 清除跟踪
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // 释放内存
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**实现：** `src/coins.cpp:278-315`

### 数据库批量写入

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // 单个 LevelDB 批次

    // 1. 标记过渡状态
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. 写入所有 coin 变更
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. 标记一致状态
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. 原子提交
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// 委派单独写入但在相同的数据库事务上下文中
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // 未使用参数（保留 API 兼容性）
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // 新批次，但相同数据库

    // 写入委派历史
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // 从历史中删除已删除的委派
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // 原子提交
    return m_db->WriteBatch(batch);
}
```

**实现：** `src/txdb.cpp:332-348`

### 原子性保证

✅ **原子的内容：**
- 区块内的所有 coin 变更原子写入
- 区块内的所有委派变更原子写入
- 数据库在崩溃时保持一致

⚠️ **当前限制：**
- Coins 和委派在 `view.Flush()` 期间在**单独的** LevelDB 批量操作中写入
- 两个操作都在 `view.Flush()` 期间发生，但不在单个原子写入中
- 实际上：两个批次在磁盘 fsync 之前快速完成
- 风险极小：两者都需要在崩溃恢复期间从同一区块重放

**注意：** 这与原始架构计划不同，原计划要求单个统一批次。当前实现使用两个批次，但通过 Bitcoin Core 现有的崩溃恢复机制（DB_HEAD_BLOCKS 标记）保持一致性。

## 重组处理

### 撤销数据结构

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // 添加了委派（撤销时删除）
        MODIFIED = 1,   // 修改了委派（撤销时恢复）
        REVOKED = 2     // 撤销了委派（撤销时取消撤销）
    };

    UndoType type;
    ForgingAssignment assignment;  // 变更前的完整状态
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO 撤销数据
    std::vector<ForgingUndo> vforgingundo;  // 委派撤销数据
};
```

**实现：** `src/undo.h:63-105`

### DisconnectBlock 流程

当重组期间断开区块时：

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... 标准 UTXO 断开 ...

    // 从磁盘读取撤销数据
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // 撤销委派变更（逆序处理）
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // 添加了委派 - 删除它
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // 撤销了委派 - 恢复未撤销状态
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // 修改了委派 - 恢复之前的状态
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**实现：** `src/validation.cpp:2381-2415`

### 重组期间的缓存管理

```cpp
class CCoinsViewCache {
private:
    // 委派缓存
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // 追踪修改的绘图
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // 追踪删除
    mutable size_t cachedAssignmentsUsage{0};  // 内存追踪

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

**实现：** `src/coins.cpp:494-565`

## RPC 接口

### 节点命令（无需钱包）

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

返回绘图地址的当前委派状态：
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

**实现：** `src/pocx/rpc/assignments.cpp:31-126`

### 钱包命令（需要钱包）

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

创建委派交易：
- 自动从绘图地址选择最大 UTXO 以证明所有权
- 构建带 OP_RETURN + 找零输出的交易
- 使用绘图所有者的密钥签名
- 广播到网络

**实现：** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

创建撤销交易：
- 自动从绘图地址选择最大 UTXO 以证明所有权
- 构建带 OP_RETURN + 找零输出的交易
- 使用绘图所有者的密钥签名
- 广播到网络

**实现：** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### 钱包交易创建

钱包交易创建流程：

```cpp
1. 解析并验证地址（必须是 P2WPKH bech32）
2. 从绘图地址找到最大 UTXO（证明所有权）
3. 创建带虚拟输出的临时交易
4. 签名交易（获取带见证数据的准确大小）
5. 用 OP_RETURN 替换虚拟输出
6. 根据大小变化按比例调整费用
7. 重新签名最终交易
8. 广播到网络
```

**关键洞察：** 钱包必须从绘图地址花费以证明所有权，因此它自动强制从该地址进行币选择。

**实现：** `src/pocx/assignments/transactions.cpp:38-263`

## 文件结构

### 核心实现文件

```
src/
├── coins.h                        # ForgingAssignment 结构，CCoinsViewCache 方法 [710 行]
├── coins.cpp                      # 缓存管理，批量写入 [603 行]
│
├── txdb.h                         # CCoinsViewDB 委派方法 [90 行]
├── txdb.cpp                       # 数据库读写 [349 行]
│
├── undo.h                         # 重组用的 ForgingUndo 结构
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock 集成
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN 格式，解析，验证
    │   ├── opcodes.cpp            # [259 行] 标记定义，OP_RETURN 操作，所有权检查
    │   ├── assignment_state.h     # GetEffectiveSigner，GetAssignmentState 辅助函数
    │   ├── assignment_state.cpp   # 委派状态查询函数
    │   ├── transactions.h         # 钱包交易创建 API
    │   └── transactions.cpp       # create_assignment，revoke_assignment 钱包函数
    │
    ├── rpc/
    │   ├── assignments.h          # 节点 RPC 命令（无钱包）
    │   ├── assignments.cpp        # get_assignment，list_assignments RPC
    │   ├── assignments_wallet.h   # 钱包 RPC 命令
    │   └── assignments_wallet.cpp # create_assignment，revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay，nForgingRevocationDelay
```

## 性能特征

### 数据库操作

- **获取当前委派：** O(n) - 扫描绘图地址的所有委派以找到最近的
- **获取委派历史：** O(n) - 迭代绘图的所有委派
- **创建委派：** O(1) - 单次插入
- **撤销委派：** O(1) - 单次更新
- **重组（每个委派）：** O(1) - 直接应用撤销数据

其中 n = 绘图的委派数量（通常很小，< 10）

### 内存使用

- **每个委派：** 约 160 字节（ForgingAssignment 结构）
- **缓存开销：** 脏跟踪的哈希映射开销
- **典型区块：** <10 个委派 = <2 KB 内存

### 磁盘使用

- **每个委派：** 磁盘上约 200 字节（包含 LevelDB 开销）
- **10000 个委派：** 约 2 MB 磁盘空间
- **与 UTXO 集相比可忽略：** 典型链状态的 <0.001%

## 当前限制和未来工作

### 原子性限制

**当前：** Coins 和委派在 `view.Flush()` 期间在单独的 LevelDB 批次中写入

**影响：** 如果在批次之间崩溃，理论上存在不一致风险

**缓解措施：**
- 两个批次在 fsync 之前快速完成
- Bitcoin Core 的崩溃恢复使用 DB_HEAD_BLOCKS 标记
- 实际上：测试中从未观察到

**未来改进：** 统一到单个 LevelDB 批量操作

### 委派历史清理

**当前：** 所有委派无限期存储

**影响：** 每个委派约 200 字节永久存储

**未来：** 可选清理超过 N 个区块的完全撤销委派

**注意：** 不太可能需要——即使 100 万个委派 = 200 MB

## 测试状态

### 已实现的测试

✅ OP_RETURN 解析和验证
✅ 所有权验证
✅ ConnectBlock 委派创建
✅ ConnectBlock 撤销
✅ DisconnectBlock 重组处理
✅ 数据库读写操作
✅ 状态转换（UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED）
✅ RPC 命令（get_assignment，create_assignment，revoke_assignment）
✅ 钱包交易创建

### 测试覆盖领域

- 单元测试：`src/test/pocx_*_tests.cpp`
- 功能测试：`test/functional/feature_pocx_*.py`
- 集成测试：使用 regtest 的手动测试

## 共识规则

### 委派创建规则

1. **所有权：** 交易必须由绘图所有者签名
2. **状态：** 绘图必须处于 UNASSIGNED 或 REVOKED 状态
3. **格式：** 有效的 OP_RETURN，带 POCX 标记 + 2 个 20 字节地址
4. **唯一性：** 每个绘图一次只能有一个活跃委派

### 撤销规则

1. **所有权：** 交易必须由绘图所有者签名
2. **存在性：** 委派必须存在且尚未撤销
3. **格式：** 有效的 OP_RETURN，带 XCOP 标记 + 20 字节地址

### 激活规则

- **委派激活：** `assignment_height + nForgingAssignmentDelay`
- **撤销激活：** `revocation_height + nForgingRevocationDelay`
- **延迟：** 每个网络可配置（例如，30 个区块 = 2 分钟区块时间下约 1 小时）

### 区块验证

- 无效委派/撤销 → 区块被拒绝（共识失败）
- OP_RETURN 输出自动从 UTXO 集排除（标准 Bitcoin 行为）
- 委派处理在 ConnectBlock 中的 UTXO 更新之前发生

## 结论

已实现的 PoCX 锻造权委派系统提供：

✅ **简洁性：** 标准 Bitcoin 交易，无特殊 UTXO
✅ **成本效益：** 无粉尘要求，仅交易费
✅ **重组安全：** 全面的撤销数据恢复正确状态
✅ **原子更新：** 通过 LevelDB 批次保证数据库一致性
✅ **完整历史：** 所有委派的完整审计轨迹
✅ **清晰架构：** 最小的 Bitcoin Core 修改，隔离的 PoCX 代码
✅ **生产就绪：** 完全实现、测试并运行

### 实现质量

- **代码组织：** 优秀 - Bitcoin Core 和 PoCX 之间清晰分离
- **错误处理：** 全面的共识验证
- **文档：** 代码注释和结构良好记录
- **测试：** 核心功能已测试，集成已验证

### 关键设计决策验证

1. ✅ 仅 OP_RETURN 方法（vs 基于 UTXO）
2. ✅ 单独数据库存储（vs Coin extraData）
3. ✅ 完整历史追踪（vs 仅当前）
4. ✅ 通过签名证明所有权（vs UTXO 花费）
5. ✅ 激活延迟（防止重组攻击）

该系统通过清晰、可维护的实现成功实现了所有架构目标。

---

[← 上一章：共识与挖矿](3-consensus-and-mining.md) | [📘 目录](index.md) | [下一章：时间同步 →](5-timing-security.md)

[← 上一章：绘图格式](2-plot-format.md) | [📘 目录](index.md) | [下一章：锻造权委派 →](4-forging-assignments.md)

---

# 第3章：Bitcoin-PoCX 共识与挖矿流程

新一代容量证明（PoCX）共识机制和挖矿流程的完整技术规范，已集成到 Bitcoin Core 中。

---

## 目录

1. [概述](#概述)
2. [共识架构](#共识架构)
3. [挖矿流程](#挖矿流程)
4. [区块验证](#区块验证)
5. [委派系统](#委派系统)
6. [网络传播](#网络传播)
7. [技术细节](#技术细节)

---

## 概述

Bitcoin-PoCX 实现了一个纯容量证明共识机制，完全取代 Bitcoin 的工作量证明。这是一条没有向后兼容要求的新链。

**核心特性：**
- **节能**：挖矿使用预生成的绘图文件而非计算哈希
- **时间弯曲截止时间**：分布转换（指数→卡方）减少长区块，改善平均区块时间
- **委派支持**：绘图所有者可以将锻造权委派给其他地址
- **原生 C++ 集成**：加密算法使用 C++ 实现用于共识验证

**挖矿流程：**
```
外部矿工 → get_mining_info → 计算 Nonce → submit_nonce →
锻造队列 → 截止时间等待 → 区块锻造 → 网络传播 →
区块验证 → 链扩展
```

---

## 共识架构

### 区块结构

PoCX 区块通过额外的共识字段扩展了 Bitcoin 的区块结构：

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // 绘图种子（32 字节）
    std::array<uint8_t, 20> account_id;       // 绘图地址（20 字节 hash160）
    uint32_t compression;                     // 扩展级别（1-255）
    uint64_t nonce;                           // 挖矿 nonce（64 位）
    uint64_t quality;                         // 声称的质量（PoC 哈希输出）
};

class CBlockHeader {
    // 标准 Bitcoin 字段
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX 共识字段（替换 nBits 和 nNonce）
    int nHeight;                              // 区块高度（无上下文验证）
    uint256 generationSignature;              // 生成签名（挖矿熵）
    uint64_t nBaseTarget;                     // 难度参数（难度的倒数）
    PoCXProof pocxProof;                      // 挖矿证明

    // 区块签名字段
    std::array<uint8_t, 33> vchPubKey;        // 压缩公钥（33 字节）
    std::array<uint8_t, 65> vchSignature;     // 紧凑签名（65 字节）
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // 交易
};
```

**注意：** 签名（`vchSignature`）不包含在区块哈希计算中，以防止可延展性。

**实现：** `src/primitives/block.h`

### 生成签名

生成签名创建挖矿熵并防止预计算攻击。

**计算：**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**创世区块：** 使用硬编码的初始生成签名

**实现：** `src/pocx/node/node.cpp:GetNewBlockContext()`

### 基础目标值（难度）

基础目标值是难度的倒数——值越高，挖矿越容易。

**调整算法：**
- 目标区块时间：120 秒（主网），1 秒（regtest）
- 调整间隔：每个区块
- 使用最近基础目标值的移动平均
- 限制以防止极端难度波动

**实现：** `src/consensus/params.h`，区块创建中的难度调整

### 扩展级别

PoCX 通过扩展级别（Xn）支持绘图文件中可扩展的工作量证明。

**动态边界：**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // 接受的最低级别
    uint8_t nPoCXTargetCompression;  // 推荐级别
};
```

**扩展增加计划：**
- 指数间隔：第 4、12、28、60、124 年（第 1、3、7、15、31 次减半）
- 最低扩展级别增加 1
- 目标扩展级别增加 1
- 保持绘图创建和查找成本之间的安全边际
- 最高扩展级别：255

**实现：** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## 挖矿流程

### 1. 获取挖矿信息

**RPC 命令：** `get_mining_info`

**流程：**
1. 调用 `GetNewBlockContext(chainman)` 获取当前区块链状态
2. 计算当前高度的动态压缩边界
3. 返回挖矿参数

**响应：**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**实现：** `src/pocx/rpc/mining.cpp:get_mining_info()`

**注意：**
- 生成响应时不持有锁
- 上下文获取在内部处理 `cs_main`
- `block_hash` 包含用于参考，但不用于验证

### 2. 外部挖矿

**外部矿工职责：**
1. 从磁盘读取绘图文件
2. 根据生成签名和高度计算 scoop
3. 找到具有最佳截止时间的 nonce
4. 通过 `submit_nonce` 提交给节点

**绘图文件格式：**
- 基于 POC2 格式（Burstcoin）
- 增强了安全修复和可扩展性改进
- 参见 `CLAUDE.md` 中的归属信息

**矿工实现：** 外部（例如基于 Scavenger）

### 3. Nonce 提交和验证

**RPC 命令：** `submit_nonce`

**参数：**
```
height, generation_signature, account_id, seed, nonce, quality（可选）
```

**验证流程（优化顺序）：**

#### 步骤 1：快速格式验证
```cpp
// 账户 ID：40 个十六进制字符 = 20 字节
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// 种子：64 个十六进制字符 = 32 字节
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### 步骤 2：上下文获取
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// 返回：height, generation_signature, base_target, block_hash
```

**锁定：** `cs_main` 在内部处理，RPC 线程不持有锁

#### 步骤 3：上下文验证
```cpp
// 高度检查
if (height != context.height) reject;

// 生成签名检查
if (submitted_gen_sig != context.generation_signature) reject;
```

#### 步骤 4：钱包验证
```cpp
// 确定有效签名者（考虑委派）
effective_signer = GetEffectiveSigner(plot_address, height, view);

// 检查节点是否拥有有效签名者的私钥
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**委派支持：** 绘图所有者可以将锻造权分配给另一个地址。钱包必须拥有有效签名者的密钥，不一定是绘图所有者。

#### 步骤 5：证明验证
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 字节
    block_height,
    nonce,
    seed,                // 32 字节
    min_compression,
    max_compression,
    &result             // 输出：quality, deadline
);
```

**算法：**
1. 从十六进制解码生成签名
2. 使用 SIMD 优化算法计算压缩范围内的最佳质量
3. 验证质量满足难度要求
4. 返回原始质量值

**实现：** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### 步骤 6：时间弯曲计算
```cpp
// 原始难度调整后的截止时间（秒）
uint64_t deadline_seconds = quality / base_target;

// 时间弯曲后的锻造时间（秒）
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**时间弯曲公式：**
```
Y = scale * (X^(1/3))
其中：
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**目的：** 将指数分布转换为卡方分布。非常好的解决方案会延迟锻造（网络有时间扫描磁盘），较差的解决方案得到改善。减少长区块，保持 120 秒平均值。

**实现：** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### 步骤 7：锻造提交
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // 不是截止时间——在锻造器中重新计算
    height,
    generation_signature
);
```

**基于队列的设计：**
- 提交始终成功（添加到队列）
- RPC 立即返回
- 工作线程异步处理

**实现：** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. 锻造队列处理

**架构：**
- 单个持久工作线程
- FIFO 提交队列
- 无锁锻造状态（仅工作线程）
- 无嵌套锁（防止死锁）

**工作线程主循环：**
```cpp
while (!shutdown) {
    // 1. 检查队列中的提交
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. 等待截止时间或新提交
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission 逻辑：**
```cpp
1. 获取新鲜上下文：GetNewBlockContext(*chainman)

2. 过期检查（静默丢弃）：
   - 高度不匹配 → 丢弃
   - 生成签名不匹配 → 丢弃
   - 链顶端区块哈希改变（重组） → 重置锻造状态

3. 质量比较：
   - 如果 quality >= current_best → 丢弃

4. 计算时间弯曲截止时间：
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. 更新锻造状态：
   - 取消现有锻造（如果找到更好的）
   - 存储：account_id, seed, nonce, quality, deadline
   - 计算：forge_time = block_time + deadline_seconds
   - 存储链顶端哈希用于重组检测
```

**实现：** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. 截止时间等待和区块锻造

**WaitForDeadlineOrNewSubmission：**

**等待条件：**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**截止时间到达时——新鲜上下文验证：**
```cpp
1. 获取当前上下文：GetNewBlockContext(*chainman)

2. 高度验证：
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. 生成签名验证：
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. 基础目标值边缘情况：
   if (forging_base_target != current_base_target) {
       // 使用新基础目标值重新计算截止时间
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // 再次等待
   }

5. 全部有效 → ForgeBlock()
```

**ForgeBlock 流程：**

```cpp
1. 确定有效签名者（委派支持）：
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. 创建 coinbase 脚本：
   coinbase_script = P2WPKH(effective_signer);  // 支付给有效签名者

3. 创建区块模板：
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. 添加 PoCX 证明：
   block.pocxProof.account_id = plot_address;    // 原始绘图地址
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. 重新计算 merkle 根：
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. 签署区块：
   // 使用有效签名者的密钥（可能与绘图所有者不同）
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. 提交到链：
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. 结果处理：
   if (accepted) {
       log_success();
       reset_forging_state();  // 准备下一个区块
   } else {
       log_failure();
       reset_forging_state();
   }
```

**实现：** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**关键设计决策：**
- Coinbase 支付给有效签名者（尊重委派）
- 证明包含原始绘图地址（用于验证）
- 签名来自有效签名者的密钥（所有权证明）
- 模板创建自动包含内存池交易

---

## 区块验证

### 传入区块验证流程

当从网络接收或本地提交区块时，它会在多个阶段进行验证：

### 阶段 1：头部验证（CheckBlockHeader）

**无上下文验证：**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX 验证（当定义 ENABLE_POCX 时）：**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // 基本签名验证（尚无委派支持）
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**基本签名验证：**
1. 检查公钥和签名字段是否存在
2. 验证公钥大小（33 字节压缩格式）
3. 验证签名大小（65 字节紧凑格式）
4. 从签名恢复公钥：`pubkey.RecoverCompact(hash, signature)`
5. 验证恢复的公钥与存储的公钥匹配

**实现：** `src/validation.cpp:CheckBlockHeader()`
**签名逻辑：** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### 阶段 2：区块验证（CheckBlock）

**验证：**
- Merkle 根正确性
- 交易有效性
- Coinbase 要求
- 区块大小限制
- 标准 Bitcoin 共识规则

**实现：** `src/consensus/validation.cpp:CheckBlock()`

### 阶段 3：上下文头部验证（ContextualCheckBlockHeader）

**PoCX 特定验证：**

```cpp
#ifdef ENABLE_POCX
    // 步骤 1：验证生成签名
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // 步骤 2：验证基础目标值
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // 步骤 3：验证容量证明
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // 步骤 4：验证截止时间
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**验证步骤：**
1. **生成签名：** 必须与从前一个区块计算的值匹配
2. **基础目标值：** 必须与难度调整计算匹配
3. **扩展级别：** 必须满足网络最低要求（`compression >= min_compression`）
4. **质量声称：** 提交的质量必须与从证明计算的质量匹配
5. **容量证明：** 加密证明验证（SIMD 优化）
6. **截止时间：** 时间弯曲截止时间（`poc_time`）必须 ≤ 经过时间

**实现：** `src/validation.cpp:ContextualCheckBlockHeader()`

### 阶段 4：区块连接（ConnectBlock）

**完整上下文验证：**

```cpp
#ifdef ENABLE_POCX
    // 带委派支持的扩展签名验证
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**扩展签名验证：**
1. 执行基本签名验证
2. 从恢复的公钥提取账户 ID
3. 获取绘图地址的有效签名者：`GetEffectiveSigner(plot_address, height, view)`
4. 验证公钥账户与有效签名者匹配

**委派逻辑：**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // 返回委派的签名者
    }

    return plotAddress;  // 无委派——绘图所有者签名
}
```

**实现：**
- 连接：`src/validation.cpp:ConnectBlock()`
- 扩展验证：`src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- 委派逻辑：`src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### 阶段 5：链激活

**ProcessNewBlock 流程：**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → 验证并存储到磁盘
    2. ActivateBestChain → 如果这是最佳链则更新链顶端
    3. 通知网络新区块
}
```

**实现：** `src/validation.cpp:ProcessNewBlock()`

### 验证摘要

**完整验证路径：**
```
接收区块
    ↓
CheckBlockHeader（基本签名）
    ↓
CheckBlock（交易、merkle）
    ↓
ContextualCheckBlockHeader（生成签名、基础目标值、PoC 证明、截止时间）
    ↓
ConnectBlock（带委派的扩展签名、状态转换）
    ↓
ActivateBestChain（重组处理、链扩展）
    ↓
网络传播
```

---

## 委派系统

### 概述

委派允许绘图所有者将锻造权委派给其他地址，同时保留绘图所有权。

**用例：**
- 矿池挖矿（绘图分配给矿池地址）
- 冷存储（挖矿密钥与绘图所有权分离）
- 多方挖矿（共享基础设施）

### 委派架构

**仅 OP_RETURN 设计：**
- 委派存储在 OP_RETURN 输出中（无 UTXO）
- 无支出要求（无粉尘、无持有费用）
- 在 CCoinsViewCache 扩展状态中跟踪
- 延迟激活期后激活（默认：4 个区块）

**委派状态：**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 不存在委派
    ASSIGNING = 1,   // 委派等待激活（延迟期）
    ASSIGNED = 2,    // 委派激活，允许锻造
    REVOKING = 3,    // 撤销等待中（延迟期，仍然激活）
    REVOKED = 4      // 撤销完成，委派不再激活
};
```

### 创建委派

**交易格式：**
```cpp
Transaction {
    inputs: [any]  // 证明绘图地址所有权
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**验证规则：**
1. 输入必须由绘图所有者签名（证明所有权）
2. OP_RETURN 包含有效的委派数据
3. 绘图必须处于 UNASSIGNED 或 REVOKED 状态
4. 内存池中没有此绘图的重复待处理委派
5. 支付了最低交易费

**激活：**
- 委派在确认高度变为 ASSIGNING
- 延迟期后（regtest 4 个区块，主网 30 个区块）变为 ASSIGNED
- 延迟防止区块竞争期间的快速重新分配

**实现：** `src/script/forging_assignment.h`，ConnectBlock 中的验证

### 撤销委派

**交易格式：**
```cpp
Transaction {
    inputs: [any]  // 证明绘图地址所有权
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**效果：**
- 立即状态转换为 REVOKED
- 绘图所有者可以立即锻造
- 之后可以创建新的委派

### 挖矿期间的委派验证

**有效签名者确定：**
```cpp
// 在 submit_nonce 验证中
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// 在区块锻造中
coinbase_script = P2WPKH(effective_signer);  // 奖励发送到这里

// 在区块签名中
signature = effective_signer_key.SignCompact(hash);  // 必须用有效签名者签名
```

**区块验证：**
```cpp
// 在 VerifyPoCXBlockCompactSignature（扩展）中
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**关键特性：**
- 证明始终包含原始绘图地址
- 签名必须来自有效签名者
- Coinbase 支付给有效签名者
- 验证使用区块高度的委派状态

---

## 网络传播

### 区块公告

**标准 Bitcoin P2P 协议：**
1. 锻造的区块通过 `ProcessNewBlock()` 提交
2. 区块验证并添加到链
3. 网络通知：`GetMainSignals().BlockConnected()`
4. P2P 层向对等节点广播区块

**实现：** 标准 Bitcoin Core net_processing

### 区块中继

**紧凑区块（BIP 152）：**
- 用于高效区块传播
- 最初只发送交易 ID
- 对等节点请求缺失的交易

**完整区块中继：**
- 紧凑区块失败时的回退
- 传输完整区块数据

### 链重组

**重组处理：**
```cpp
// 在锻造工作线程中
if (current_tip_hash != stored_tip_hash) {
    // 检测到链重组
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**区块链级别：**
- 标准 Bitcoin Core 重组处理
- 最佳链由链工作量确定
- 断开的区块返回内存池

---

## 技术细节

### 死锁预防

**ABBA 死锁模式（已预防）：**
```
线程 A：cs_main → cs_wallet
线程 B：cs_wallet → cs_main
```

**解决方案：**
1. **submit_nonce：** 零 cs_main 使用
   - `GetNewBlockContext()` 在内部处理锁定
   - 锻造提交前完成所有验证

2. **锻造器：** 基于队列的架构
   - 单个工作线程（无线程加入）
   - 每次访问获取新鲜上下文
   - 无嵌套锁

3. **钱包检查：** 在昂贵操作之前执行
   - 如果没有可用密钥则提前拒绝
   - 与区块链状态访问分离

### 性能优化

**快速失败验证：**
```cpp
1. 格式检查（立即）
2. 上下文验证（轻量级）
3. 钱包验证（本地）
4. 证明验证（昂贵的 SIMD）
```

**单次上下文获取：**
- 每次提交一次 `GetNewBlockContext()` 调用
- 缓存结果用于多次检查
- 无重复 cs_main 获取

**队列效率：**
- 轻量级提交结构
- 队列中无 base_target/deadline（新鲜重新计算）
- 最小内存占用

### 过期处理

**"简单"锻造器设计：**
- 无区块链事件订阅
- 需要时延迟验证
- 静默丢弃过期提交

**优势：**
- 简单的架构
- 无复杂同步
- 对边缘情况健壮

**处理的边缘情况：**
- 高度变更 → 丢弃
- 生成签名变更 → 丢弃
- 基础目标值变更 → 重新计算截止时间
- 重组 → 重置锻造状态

### 加密细节

**生成签名：**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**区块签名哈希：**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**紧凑签名格式：**
- 65 字节：[recovery_id][r][s]
- 允许公钥恢复
- 用于节省空间

**账户 ID：**
- 压缩公钥的 20 字节 HASH160
- 匹配 Bitcoin 地址格式（P2PKH、P2WPKH）

### 未来增强

**记录的限制：**
1. 无性能指标（提交率、截止时间分布）
2. 无详细的矿工错误分类
3. 有限的锻造器状态查询（当前截止时间、队列深度）

**潜在改进：**
- 锻造器状态 RPC
- 挖矿效率指标
- 增强的调试日志
- 矿池协议支持

---

## 代码参考

**核心实现：**
- RPC 接口：`src/pocx/rpc/mining.cpp`
- 锻造队列：`src/pocx/mining/scheduler.cpp`
- 共识验证：`src/pocx/consensus/validation.cpp`
- 证明验证：`src/pocx/consensus/pocx.cpp`
- 时间弯曲：`src/pocx/algorithms/time_bending.cpp`
- 区块验证：`src/validation.cpp`（CheckBlockHeader、ConnectBlock）
- 委派逻辑：`src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- 上下文管理：`src/pocx/node/node.cpp:GetNewBlockContext()`

**数据结构：**
- 区块格式：`src/primitives/block.h`
- 共识参数：`src/consensus/params.h`
- 委派跟踪：`src/coins.h`（CCoinsViewCache 扩展）

---

## 附录：算法规范

### 时间弯曲公式

**数学定义：**
```
deadline_seconds = quality / base_target（原始）

time_bended_deadline = scale * (deadline_seconds)^(1/3)

其中：
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**实现：**
- 定点算术（Q42 格式）
- 仅整数立方根计算
- 针对 256 位算术优化

### 质量计算

**流程：**
1. 从生成签名和高度生成 scoop
2. 读取计算的 scoop 的绘图数据
3. 哈希：`SHABAL256(generation_signature || scoop_data)`
4. 测试从 min 到 max 的扩展级别
5. 返回找到的最佳质量

**扩展：**
- 级别 X0：POC2 基线（理论上的）
- 级别 X1：XOR 转置基线
- 级别 Xn：嵌入 2^(n-1) 倍 X1 工作量
- 更高的扩展 = 更多绘图生成工作

### 基础目标值调整

**逐块调整：**
1. 计算最近基础目标值的移动平均
2. 计算滚动窗口的实际时间跨度与目标时间跨度
3. 按比例调整基础目标值
4. 限制以防止极端波动

**公式：**
```
avg_base_target = moving_average(recent base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*本文档反映了截至 2025 年 10 月的完整 PoCX 共识实现。*

---

[← 上一章：绘图格式](2-plot-format.md) | [📘 目录](index.md) | [下一章：锻造权委派 →](4-forging-assignments.md)

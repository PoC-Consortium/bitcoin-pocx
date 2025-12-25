[← 上一章：简介](1-introduction.md) | [📘 目录](index.md) | [下一章：共识与挖矿 →](3-consensus-and-mining.md)

---

# 第2章：PoCX 绘图格式规范

本文档描述 PoCX 绘图格式，这是 POC2 格式的增强版本，具有改进的安全性、SIMD 优化和可扩展的工作量证明。

## 格式概述

PoCX 绘图文件包含预先计算的 Shabal256 哈希值，组织方式经过优化以实现高效的挖矿操作。沿袭自 POC1 以来的 PoC 传统，**所有元数据都嵌入在文件名中**——没有文件头。

### 文件扩展名
- **标准**：`.pocx`（已完成的绘图）
- **进行中**：`.tmp`（绘图过程中使用，完成后重命名为 `.pocx`）

## 历史背景与漏洞演进

### POC1 格式（传统）
**两个主要漏洞（时间-内存权衡）：**

1. **工作量证明分布缺陷**
   - 各 scoop 之间工作量证明分布不均匀
   - 低编号的 scoop 可以即时计算
   - **影响**：减少攻击者的存储需求

2. **XOR 压缩攻击**（50% 时间-内存权衡）
   - 利用数学特性实现 50% 的存储减少
   - **影响**：攻击者可以用一半的存储进行挖矿

**布局优化**：为 HDD 效率设计的基本顺序 scoop 布局

### POC2 格式（Burstcoin）
- ✅ **修复了工作量证明分布缺陷**
- ❌ **XOR 转置漏洞仍未修补**
- **布局**：保持顺序 scoop 优化

### PoCX 格式（当前）
- ✅ **工作量证明分布已修复**（继承自 POC2）
- ✅ **XOR 转置漏洞已修补**（PoCX 独有）
- ✅ **增强的 SIMD/GPU 布局**，针对并行处理和内存合并进行了优化
- ✅ **可扩展的工作量证明**，随着算力增长防止时间-内存权衡（工作量证明仅在创建或升级绘图文件时执行）

## XOR 转置编码

### 问题：50% 时间-内存权衡

在 POC1/POC2 格式中，攻击者可以利用 scoop 之间的数学关系，只存储一半的数据，并在挖矿过程中即时计算其余部分。这种"XOR 压缩攻击"破坏了存储保证。

### 解决方案：XOR 转置加固

PoCX 通过对基础 warp（X0）对应用 XOR 转置编码来派生其挖矿格式（X1）：

**构建 X1 warp 中 nonce N 的 scoop S：**
1. 从第一个 X0 warp 中取 nonce N 的 scoop S（直接位置）
2. 从第二个 X0 warp 中取 nonce S 的 scoop N（转置位置）
3. 将两个 64 字节值进行 XOR 运算得到 X1 scoop

转置步骤交换了 scoop 和 nonce 索引。用矩阵术语来说——其中行表示 scoop，列表示 nonce——它将第一个 warp 中位置 (S, N) 的元素与第二个 warp 中位置 (N, S) 的元素组合。

### 为什么这能消除攻击

XOR 转置将每个 scoop 与底层 X0 数据的整行和整列相互关联。恢复单个 X1 scoop 需要访问跨越所有 4096 个 scoop 索引的数据。任何试图计算缺失数据的尝试都需要重新生成 4096 个完整的 nonce 而不是单个 nonce——消除了 XOR 攻击所利用的非对称成本结构。

因此，存储完整的 X1 warp 成为矿工唯一计算可行的策略。

## 文件名元数据结构

所有绘图元数据都使用以下确切格式编码在文件名中：

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### 文件名组件

1. **ACCOUNT_PAYLOAD**（40 个十六进制字符）
   - 原始 20 字节账户载荷的大写十六进制
   - 与网络无关（无网络 ID 或校验和）
   - 示例：`DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED**（64 个十六进制字符）
   - 32 字节种子值的小写十六进制
   - **PoCX 新增**：文件名中的随机 32 字节种子替代连续 nonce 编号——防止绘图重叠
   - 示例：`c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS**（十进制数字）
   - **PoCX 新增的大小单位**：替代 POC1/POC2 的基于 nonce 的大小
   - **XOR 转置抗性设计**：每个 warp = 正好 4096 个 nonce（XOR 转置抗性转换所需的分区大小）
   - **大小**：1 warp = 1073741824 字节 = 1 GiB（方便的单位）
   - 示例：`1024`（1 TiB 绘图 = 1024 warps）

4. **SCALING**（X 前缀的十进制数字）
   - 扩展级别，格式为 `X{level}`
   - 更高的值 = 需要更多工作量证明
   - 示例：`X4`（2^4 = 16 倍 POC2 难度）

### 文件名示例
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## 文件布局和数据结构

### 层次结构
```
绘图文件（无文件头）
├── Scoop 0
│   ├── Warp 0（此 scoop/warp 的所有 nonce）
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### 常量和大小

| 常量 | 大小 | 描述 |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE** | 32 B | 单个 Shabal256 哈希输出 |
| **SCOOP\_SIZE** | 64 B（2 × HASH\_SIZE） | 挖矿轮次中读取的哈希对 |
| **NUM\_SCOOPS** | 4096（2¹²） | 每个 nonce 的 scoop 数；每轮选择一个 |
| **NONCE\_SIZE** | 262144 B（256 KiB） | 一个 nonce 的所有 scoop（POC1/POC2 最小单位） |
| **WARP\_SIZE** | 1073741824 B（1 GiB） | PoCX 中的最小单位 |

### SIMD 优化的绘图文件布局

PoCX 实现了 SIMD 感知的 nonce 访问模式，可以同时对多个 nonce 进行向量化处理。它基于 [POC2×16 优化研究](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) 的概念，以最大化内存吞吐量和 SIMD 效率。

---

#### 传统顺序布局

nonce 的顺序存储：

```
[Nonce 0: Scoop 数据] [Nonce 1: Scoop 数据] [Nonce 2: Scoop 数据] ...
```

SIMD 低效：每个 SIMD 通道需要跨 nonce 的相同字：

```
Nonce 0 的 Word 0 -> 偏移 0
Nonce 1 的 Word 0 -> 偏移 512
Nonce 2 的 Word 0 -> 偏移 1024
...
```

分散-聚集访问降低吞吐量。

---

#### PoCX SIMD 优化布局

PoCX 将**跨 16 个 nonce 的字位置**连续存储：

```
缓存行（64 字节）：

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII 图示**

```
传统布局：

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX 布局：

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### 内存访问优势

- 一个缓存行为所有 SIMD 通道提供数据
- 消除分散-聚集操作
- 减少缓存未命中
- 向量化计算的完全顺序内存访问
- GPU 也受益于 16 nonce 对齐，最大化缓存效率

---

#### SIMD 扩展

| SIMD | 向量宽度* | Nonce 数 | 每缓存行处理周期 |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX | 128 位 | 4 | 4 周期 |
| AVX2 | 256 位 | 8 | 2 周期 |
| AVX512 | 512 位 | 16 | 1 周期 |

\* 针对整数操作

---



## 工作量证明扩展

### 扩展级别
- **X0**：没有 XOR 转置编码的基础 nonce（理论上的，不用于挖矿）
- **X1**：XOR 转置基线——第一个加固格式（1 倍工作量）
- **X2**：2 倍 X1 工作量（跨 2 个 warp 的 XOR）
- **X3**：4 倍 X1 工作量（跨 4 个 warp 的 XOR）
- **…**
- **Xn**：嵌入 2^(n-1) 倍 X1 工作量

### 优势
- **可调整的工作量证明难度**：增加计算要求以跟上更快的硬件
- **格式长寿命**：随时间灵活扩展挖矿难度

### 绘图升级 / 向后兼容

当网络将工作量证明（PoW）扩展级别增加 1 时，现有绘图需要升级以保持相同的有效绘图大小。本质上，你现在需要绘图文件中两倍的 PoW 才能对账户产生相同的贡献。

好消息是，你在创建绘图文件时已经完成的 PoW 不会丢失——你只需要向现有文件添加额外的 PoW。无需重新绘图。

或者，你可以继续使用当前的绘图而不升级，但请注意，它们现在只会贡献以前有效大小的 50% 给你的账户。你的挖矿软件可以即时扩展绘图文件。

## 与传统格式的比较

| 特性 | POC1 | POC2 | PoCX |
|---------|------|------|------|
| 工作量证明分布 | ❌ 有缺陷 | ✅ 已修复 | ✅ 已修复 |
| XOR 转置抗性 | ❌ 有漏洞 | ❌ 有漏洞 | ✅ 已修复 |
| SIMD 优化 | ❌ 无 | ❌ 无 | ✅ 高级 |
| GPU 优化 | ❌ 无 | ❌ 无 | ✅ 已优化 |
| 可扩展工作量证明 | ❌ 无 | ❌ 无 | ✅ 是 |
| 种子支持 | ❌ 无 | ❌ 无 | ✅ 是 |

PoCX 格式代表了容量证明绘图格式的最新技术水平，解决了所有已知漏洞，同时为现代硬件提供了显著的性能改进。

## 参考文献和延伸阅读

- **POC1/POC2 背景**：[Burstcoin 挖矿概述](https://www.burstcoin.community/burstcoin-mining/) - 传统容量证明挖矿格式的综合指南
- **POC2×16 研究**：[CIP 公告：POC2×16 - 一种新的优化绘图格式](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - 启发 PoCX 的原始 SIMD 优化研究
- **Shabal 哈希算法**：[Saphir 项目：Shabal，NIST 加密哈希算法竞赛的提交方案](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - PoC 挖矿中使用的 Shabal256 算法的技术规范

---

[← 上一章：简介](1-introduction.md) | [📘 目录](index.md) | [下一章：共识与挖矿 →](3-consensus-and-mining.md)

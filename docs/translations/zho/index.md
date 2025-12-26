# Bitcoin-PoCX 技术文档

**版本**：1.0
**Bitcoin Core 基础版本**：v30.0
**状态**：测试网阶段
**最后更新**：2025-12-25

---

## 关于本文档

本文档是 Bitcoin-PoCX 的完整技术文档。Bitcoin-PoCX 是一个 Bitcoin Core 集成项目，添加了新一代容量证明（PoCX）共识支持。本文档以可浏览的指南形式组织，各章节相互关联，涵盖系统的所有方面。

**目标读者**：
- **节点运营者**：第1、5、6、8章
- **矿工**：第2、3、7章
- **开发者**：所有章节
- **研究人员**：第3、4、5章

## 翻译版本

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 阿拉伯语](../ara/index.md) | [🇪🇪 爱沙尼亚语](../est/index.md) | [🇧🇬 保加利亚语](../bul/index.md) | [🇵🇱 波兰语](../pol/index.md) | [🇩🇰 丹麦语](../dan/index.md) | [🇩🇪 德语](../deu/index.md) |
| [🇷🇺 俄语](../rus/index.md) | [🇫🇷 法语](../fra/index.md) | [🇵🇭 菲律宾语](../fil/index.md) | [🇫🇮 芬兰语](../fin/index.md) | [🇰🇷 韩语](../kor/index.md) | [🇳🇱 荷兰语](../nld/index.md) |
| [🇨🇿 捷克语](../ces/index.md) | [🇱🇻 拉脱维亚语](../lav/index.md) | [🇱🇹 立陶宛语](../lit/index.md) | [🇷🇴 罗马尼亚语](../ron/index.md) | [🇳🇴 挪威语](../nor/index.md) | [🇵🇹 葡萄牙语](../por/index.md) |
| [🇯🇵 日语](../jpn/index.md) | [🇸🇪 瑞典语](../swe/index.md) | [🇷🇸 塞尔维亚语](../srp/index.md) | [🇰🇪 斯瓦希里语](../swa/index.md) | [🇹🇷 土耳其语](../tur/index.md) | [🇺🇦 乌克兰语](../ukr/index.md) |
| [🇪🇸 西班牙语](../spa/index.md) | [🇬🇷 希腊语](../ell/index.md) | [🇮🇱 希伯来语](../heb/index.md) | [🇭🇺 匈牙利语](../hun/index.md) | [🇮🇳 印地语](../hin/index.md) | [🇮🇩 印度尼西亚语](../ind/index.md) |
| [🇮🇹 意大利语](../ita/index.md) | [🇻🇳 越南语](../vie/index.md) | | | | |

---

## 目录

### 第一部分：基础知识

**[第1章：简介与概述](1-introduction.md)**
项目概述、架构、设计理念、核心特性，以及 PoCX 与工作量证明的区别。

**[第2章：绘图文件格式](2-plot-format.md)**
PoCX 绘图格式的完整规范，包括 SIMD 优化、工作量证明扩展，以及从 POC1/POC2 的格式演进。

**[第3章：共识与挖矿](3-consensus-and-mining.md)**
PoCX 共识机制的完整技术规范：区块结构、生成签名、基础目标值调整、挖矿流程、验证管道和时间弯曲算法。

---

### 第二部分：高级特性

**[第4章：锻造权委派系统](4-forging-assignments.md)**
基于 OP_RETURN 的锻造权委派架构：交易结构、数据库设计、状态机、重组处理和 RPC 接口。

**[第5章：时间同步与安全](5-timing-security.md)**
时钟漂移容差、防御性锻造机制、防时钟操纵措施，以及时间相关的安全考量。

**[第6章：网络参数](6-network-parameters.md)**
链参数配置、创世区块、共识参数、coinbase 规则、动态扩展和经济模型。

---

### 第三部分：使用与集成

**[第7章：RPC 接口参考](7-rpc-reference.md)**
挖矿、委派和区块链查询的完整 RPC 命令参考。矿工和矿池集成必备。

**[第8章：钱包与图形界面指南](8-wallet-guide.md)**
Bitcoin-PoCX Qt 钱包用户指南：锻造权委派对话框、交易历史、挖矿设置和故障排除。

---

## 快速导航

### 节点运营者
→ 从[第1章：简介](1-introduction.md)开始
→ 然后阅读[第6章：网络参数](6-network-parameters.md)
→ 使用[第8章：钱包指南](8-wallet-guide.md)配置挖矿

### 矿工
→ 了解[第2章：绘图格式](2-plot-format.md)
→ 学习[第3章：共识与挖矿](3-consensus-and-mining.md)中的流程
→ 使用[第7章：RPC 参考](7-rpc-reference.md)进行集成

### 矿池运营者
→ 阅读[第4章：锻造权委派](4-forging-assignments.md)
→ 学习[第7章：RPC 参考](7-rpc-reference.md)
→ 使用委派 RPC 和 submit_nonce 进行实现

### 开发者
→ 按顺序阅读所有章节
→ 交叉参考文档中注明的实现文件
→ 查看 `src/pocx/` 目录结构
→ 使用 [GUIX](../bitcoin/contrib/guix/README.md) 构建发布版本

---

## 文档约定

**文件引用**：实现细节引用源文件，格式为 `路径/文件.cpp:行号`

**代码集成**：所有修改均使用 `#ifdef ENABLE_POCX` 进行特性标记

**交叉引用**：各章节使用相对 Markdown 链接引用相关章节

**技术层次**：本文档假定读者熟悉 Bitcoin Core 和 C++ 开发

---

## 构建

### 开发构建

```bash
# 克隆仓库（包含子模块）
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# 启用 PoCX 配置
cmake -B build -DENABLE_POCX=ON

# 构建
cmake --build build -j$(nproc)
```

**构建变体**：
```bash
# 包含 Qt 图形界面
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# 调试构建
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**依赖项**：标准 Bitcoin Core 构建依赖项。参见 [Bitcoin Core 构建文档](https://github.com/bitcoin/bitcoin/tree/master/doc#building) 了解特定平台要求。

### 发布构建

要获得可重现的发布二进制文件，请使用 GUIX 构建系统：参见 [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## 其他资源

**代码仓库**：[https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX 核心框架**：[https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**相关项目**：
- 绘图工具：基于 [engraver](https://github.com/PoC-Consortium/engraver)
- 矿工软件：基于 [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## 如何阅读本文档

**顺序阅读**：各章节按顺序设计，后续章节基于前面的概念构建。

**参考阅读**：使用目录直接跳转到特定主题。每章都是自包含的，并提供相关材料的交叉引用。

**浏览器导航**：在 Markdown 查看器或浏览器中打开 `index.md`。所有内部链接均为相对链接，可离线使用。

**PDF 导出**：本文档可合并为单个 PDF 供离线阅读。

---

## 项目状态

**功能完整**：所有共识规则、挖矿、委派和钱包功能均已实现。

**文档完整**：全部8章已完成并与代码库核对验证。

**测试网活跃**：目前处于测试网阶段，供社区测试。

---

## 贡献

欢迎对文档的贡献。请保持：
- 技术准确性优先于冗长描述
- 简明扼要的说明
- 文档中不包含代码或伪代码（改为引用源文件）
- 仅记录已实现的功能（不包含推测性特性）

---

## 许可证

Bitcoin-PoCX 继承 Bitcoin Core 的 MIT 许可证。参见仓库根目录下的 `COPYING` 文件。

PoCX 核心框架的归属信息记录在[第2章：绘图格式](2-plot-format.md)中。

---

**开始阅读**：[第1章：简介与概述 →](1-introduction.md)

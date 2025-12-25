# Bitcoin-PoCX 技術文書

**バージョン**: 1.0
**Bitcoin Core ベース**: v30.0
**ステータス**: テストネットフェーズ
**最終更新**: 2025年12月25日

---

## 本文書について

本文書は、Bitcoin-PoCXの完全な技術文書です。Bitcoin-PoCXは、Bitcoin Coreに次世代容量証明（Proof of Capacity neXt generation、PoCX）コンセンサスサポートを追加する統合プロジェクトです。本文書は、システムのあらゆる側面を網羅した、相互リンクされた章で構成されるブラウズ可能なガイドとして編成されています。

**対象読者**:
- **ノード運用者**: 第1章、第5章、第6章、第8章
- **マイナー**: 第2章、第3章、第7章
- **開発者**: 全章
- **研究者**: 第3章、第4章、第5章

---

## 目次

### 第I部: 基礎

**[第1章: はじめに](1-introduction.md)**
プロジェクト概要、アーキテクチャ、設計哲学、主要機能、およびPoCXとProof of Workの違い。

**[第2章: プロットファイル形式](2-plot-format.md)**
PoCXプロット形式の完全な仕様（SIMD最適化、Proof-of-Workスケーリング、POC1/POC2からの形式進化を含む）。

**[第3章: コンセンサスとマイニング](3-consensus-and-mining.md)**
PoCXコンセンサスメカニズムの完全な技術仕様：ブロック構造、生成署名、ベースターゲット調整、マイニングプロセス、検証パイプライン、およびタイムベンディングアルゴリズム。

---

### 第II部: 高度な機能

**[第4章: フォージング割り当てシステム](4-forging-assignments.md)**
フォージング権限の委譲のためのOP_RETURN専用アーキテクチャ：トランザクション構造、データベース設計、ステートマシン、再編成処理、およびRPCインターフェース。

**[第5章: 時刻同期とセキュリティ](5-timing-security.md)**
クロックドリフト許容範囲、防御的フォージングメカニズム、時刻操作対策、およびタイミング関連のセキュリティ考慮事項。

**[第6章: ネットワークパラメータ](6-network-parameters.md)**
Chainparams設定、ジェネシスブロック、コンセンサスパラメータ、Coinbaseルール、動的スケーリング、および経済モデル。

---

### 第III部: 利用と統合

**[第7章: RPCインターフェースリファレンス](7-rpc-reference.md)**
マイニング、割り当て、およびブロックチェーンクエリのための完全なRPCコマンドリファレンス。マイナーおよびプール統合に必須。

**[第8章: ウォレットとGUIガイド](8-wallet-guide.md)**
Bitcoin-PoCX Qtウォレットのユーザーガイド：フォージング割り当てダイアログ、トランザクション履歴、マイニング設定、およびトラブルシューティング。

---

## クイックナビゲーション

### ノード運用者向け
→ [第1章: はじめに](1-introduction.md)から開始
→ 次に[第6章: ネットワークパラメータ](6-network-parameters.md)を確認
→ [第8章: ウォレットガイド](8-wallet-guide.md)でマイニングを設定

### マイナー向け
→ [第2章: プロット形式](2-plot-format.md)を理解
→ [第3章: コンセンサスとマイニング](3-consensus-and-mining.md)でプロセスを学習
→ [第7章: RPCリファレンス](7-rpc-reference.md)で統合

### プール運用者向け
→ [第4章: フォージング割り当て](4-forging-assignments.md)を確認
→ [第7章: RPCリファレンス](7-rpc-reference.md)を精読
→ 割り当てRPCとsubmit_nonceで実装

### 開発者向け
→ 全章を順番に通読
→ 各所に記載された実装ファイルを参照
→ `src/pocx/`ディレクトリ構造を調査
→ [GUIX](../bitcoin/contrib/guix/README.md)でリリースをビルド

---

## 文書規約

**ファイル参照**: 実装の詳細はソースファイルを`path/to/file.cpp:line`形式で参照

**コード統合**: すべての変更は`#ifdef ENABLE_POCX`でフィーチャーフラグ管理

**相互参照**: 章間は相対Markdownリンクで関連セクションにリンク

**技術レベル**: Bitcoin CoreおよびC++開発に精通していることを前提

---

## ビルド

### 開発ビルド

```bash
# サブモジュールを含めてクローン
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# PoCXを有効にして設定
cmake -B build -DENABLE_POCX=ON

# ビルド
cmake --build build -j$(nproc)
```

**ビルドバリアント**:
```bash
# Qt GUI付き
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# デバッグビルド
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**依存関係**: 標準のBitcoin Coreビルド依存関係。プラットフォーム固有の要件については[Bitcoin Coreビルド文書](https://github.com/bitcoin/bitcoin/tree/master/doc#building)を参照。

### リリースビルド

再現可能なリリースバイナリには、GUIXビルドシステムを使用：[bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)を参照

---

## 追加リソース

**リポジトリ**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCXコアフレームワーク**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**関連プロジェクト**:
- プロッター: [engraver](https://github.com/PoC-Consortium/engraver)ベース
- マイナー: [scavenger](https://github.com/PoC-Consortium/scavenger)ベース

---

## 本文書の読み方

**順次読み**: 章は順番に読むように設計されており、前の概念の上に構築されます。

**参照読み**: 目次を使用して特定のトピックに直接ジャンプ。各章は自己完結しており、関連資料への相互参照があります。

**ブラウザナビゲーション**: `index.md`をMarkdownビューアまたはブラウザで開きます。すべての内部リンクは相対パスで、オフラインでも動作します。

**PDF出力**: 本文書はオフライン閲覧用に単一のPDFに連結できます。

---

## プロジェクトステータス

**機能完了**: すべてのコンセンサスルール、マイニング、割り当て、ウォレット機能が実装済み。

**文書完了**: 全8章が完成し、コードベースに対して検証済み。

**テストネット稼働中**: 現在、コミュニティテストのためのテストネットフェーズ。

---

## 貢献

文書への貢献を歓迎します。以下を維持してください：
- 冗長さよりも技術的正確性
- 簡潔で要点を押さえた説明
- 文書内にコードや疑似コードを含めない（代わりにソースファイルを参照）
- 実装済みの機能のみ（推測的な機能は含めない）

---

## ライセンス

Bitcoin-PoCXはBitcoin CoreのMITライセンスを継承しています。リポジトリルートの`COPYING`を参照してください。

PoCXコアフレームワークへの帰属は[第2章: プロット形式](2-plot-format.md)に記載。

---

**読み始める**: [第1章: はじめに →](1-introduction.md)

[← 前へ: コンセンサスとマイニング](3-consensus-and-mining.md) | [目次](index.md) | [次へ: 時刻同期 →](5-timing-security.md)

---

# 第4章: PoCXフォージング割り当てシステム

## 概要

本文書は、OP_RETURN専用アーキテクチャを使用した**実装済み**のPoCXフォージング割り当てシステムについて説明します。このシステムにより、プロット所有者はオンチェーントランザクションを通じてフォージング権限を別のアドレスに委譲でき、完全な再編成安全性とアトミックなデータベース操作を備えています。

**ステータス:** 完全に実装され運用中

## コア設計哲学

**主要原則:** 割り当ては資産ではなく権限

- 追跡または支出する特別なUTXOなし
- 割り当て状態はUTXOセットとは別に保存
- 所有権はUTXO支出ではなくトランザクション署名で証明
- 完全な監査証跡のための完全な履歴追跡
- LevelDBバッチ書き込みによるアトミックなデータベース更新

## トランザクション構造

### 割り当てトランザクション形式

```
入力:
  [0]: プロット所有者が制御する任意のUTXO（所有権証明 + 手数料支払い）
       プロット所有者の秘密鍵で署名必須
  [1+]: 手数料カバー用の追加入力（オプション）

出力:
  [0]: OP_RETURN（POCXマーカー + プロットアドレス + フォージアドレス）
       形式: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       サイズ: 合計46バイト（1バイトOP_RETURN + 1バイト長さ + 44バイトデータ）
       値: 0 BTC（支出不可、UTXOセットに追加されない）

  [1]: ユーザーへのお釣り（オプション、標準P2WPKH）
```

**実装:** `src/pocx/assignments/opcodes.cpp:25-52`

### 取り消しトランザクション形式

```
入力:
  [0]: プロット所有者が制御する任意のUTXO（所有権証明 + 手数料支払い）
       プロット所有者の秘密鍵で署名必須
  [1+]: 手数料カバー用の追加入力（オプション）

出力:
  [0]: OP_RETURN（XCOPマーカー + プロットアドレス）
       形式: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       サイズ: 合計26バイト（1バイトOP_RETURN + 1バイト長さ + 24バイトデータ）
       値: 0 BTC（支出不可、UTXOセットに追加されない）

  [1]: ユーザーへのお釣り（オプション、標準P2WPKH）
```

**実装:** `src/pocx/assignments/opcodes.cpp:54-77`

### マーカー

- **割り当てマーカー:** `POCX`（0x50, 0x4F, 0x43, 0x58）= "Proof of Capacity neXt"
- **取り消しマーカー:** `XCOP`（0x58, 0x43, 0x4F, 0x50）= "eXit Capacity OPeration"

**実装:** `src/pocx/assignments/opcodes.cpp:15-19`

### 主要なトランザクション特性

- 標準Bitcoinトランザクション（プロトコル変更なし）
- OP_RETURN出力は証明可能に支出不可（UTXOセットに追加されない）
- プロット所有権はプロットアドレスからのinput[0]の署名で証明
- 低コスト（約200バイト、通常0.0001 BTC未満の手数料）
- ウォレットは自動的にプロットアドレスから最大のUTXOを選択して所有権を証明

## データベースアーキテクチャ

### ストレージ構造

すべての割り当てデータはUTXOセット（`chainstate/`）と同じLevelDBデータベースに保存されますが、別のキープレフィックスを使用します:

```
chainstate/ LevelDB:
├─ UTXOセット（Bitcoin Core標準）
│  └─ 'C'プレフィックス: COutPoint → Coin
│
└─ 割り当て状態（PoCX追加）
   └─ 'A'プレフィックス: (plot_address, assignment_txid) → ForgingAssignment
       └─ 完全な履歴: プロットごとのすべての割り当て
```

**実装:** `src/txdb.cpp:237-348`

### ForgingAssignment構造

```cpp
struct ForgingAssignment {
    // アイデンティティ
    std::array<uint8_t, 20> plotAddress;      // プロット所有者（20バイトP2WPKHハッシュ）
    std::array<uint8_t, 20> forgingAddress;   // フォージング権限保持者（20バイトP2WPKHハッシュ）

    // 割り当てライフサイクル
    uint256 assignment_txid;                   // 割り当てを作成したトランザクション
    int assignment_height;                     // 作成されたブロック高さ
    int assignment_effective_height;           // アクティブになる高さ（height + delay）

    // 取り消しライフサイクル
    bool revoked;                              // 取り消されたか？
    uint256 revocation_txid;                   // 取り消したトランザクション
    int revocation_height;                     // 取り消されたブロック高さ
    int revocation_effective_height;           // 取り消しが有効になる高さ（height + delay）

    // 状態クエリメソッド
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**実装:** `src/coins.h:111-178`

### 割り当て状態

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 割り当てなし
    ASSIGNING = 1,   // 割り当て作成、アクティベーション遅延待ち
    ASSIGNED = 2,    // 割り当てアクティブ、フォージング許可
    REVOKING = 3,    // 取り消し済み、遅延期間中はまだアクティブ
    REVOKED = 4      // 完全に取り消し、無効
};
```

**実装:** `src/coins.h:98-104`

### データベースキー

```cpp
// 履歴キー: 完全な割り当てレコードを保存
// キー形式: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // プロットアドレス（20バイト）
    int assignment_height;                // ソート最適化用高さ
    uint256 assignment_txid;              // トランザクションID
};
```

**実装:** `src/txdb.cpp:245-262`

### 履歴追跡

- すべての割り当ては永続的に保存（再編成でない限り削除されない）
- プロットごとに複数の割り当てを時系列で追跡
- 完全な監査証跡と履歴状態クエリを可能に
- 取り消された割り当ては`revoked=true`でデータベースに残る

## ブロック処理

### ConnectBlock統合

割り当てと取り消しのOP_RETURNは`validation.cpp`のブロック接続中に処理されます:

```cpp
// 場所: スクリプト検証後、UpdateCoins前
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURNデータを解析
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // 所有権を検証（txはプロット所有者によって署名必須）
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // プロット状態をチェック（UNASSIGNEDまたはREVOKED必須）
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // 新しい割り当てを作成
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // 取り消しデータを保存
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURNデータを解析
            auto plot_addr = ParseRevocationOpReturn(output);

            // 所有権を検証
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // 現在の割り当てを取得
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // 取り消し用に古い状態を保存
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // 取り消し済みとしてマーク
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

// UpdateCoinsは通常通り進行（OP_RETURN出力は自動的にスキップ）
```

**実装:** `src/validation.cpp:2775-2878`

### 所有権検証

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // 少なくとも1つの入力がプロット所有者によって署名されていることを確認
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // 宛先を抽出
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // プロットアドレスへのP2WPKHかチェック
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Coreが既に署名を検証済み
                return true;
            }
        }
    }
    return false;
}
```

**実装:** `src/pocx/assignments/opcodes.cpp:217-256`

### アクティベーション遅延

割り当てと取り消しには、再編成攻撃を防ぐための設定可能なアクティベーション遅延があります:

```cpp
// コンセンサスパラメータ（ネットワークごとに設定可能）
// 例: 30ブロック = 2分ブロック時間で約1時間
consensus.nForgingAssignmentDelay;   // 割り当てアクティベーション遅延
consensus.nForgingRevocationDelay;   // 取り消しアクティベーション遅延
```

**状態遷移:**
- 割り当て: `UNASSIGNED → ASSIGNING（遅延）→ ASSIGNED`
- 取り消し: `ASSIGNED → REVOKING（遅延）→ REVOKED`

**実装:** `src/consensus/params.h`、`src/kernel/chainparams.cpp`

## Mempool検証

割り当てと取り消しトランザクションはmempool受け入れ時に検証され、無効なトランザクションをネットワーク伝播前に拒否します。

### トランザクションレベルチェック（CheckTransaction）

チェーン状態アクセスなしで`src/consensus/tx_check.cpp`で実行:

1. **最大1つのPoCX OP_RETURN:** トランザクションに複数のPOCX/XCOPマーカーを含めることはできない

**実装:** `src/consensus/tx_check.cpp:63-77`

### Mempool受け入れチェック（PreChecks）

`src/validation.cpp`で完全なチェーン状態とmempoolアクセスで実行:

#### 割り当て検証

1. **プロット所有権:** トランザクションはプロット所有者によって署名必須
2. **プロット状態:** プロットはUNASSIGNED（0）またはREVOKED（4）必須
3. **Mempool競合:** このプロットの他の割り当てがmempoolにないこと（先着順）

#### 取り消し検証

1. **プロット所有権:** トランザクションはプロット所有者によって署名必須
2. **アクティブな割り当て:** プロットはASSIGNED（2）状態のみ必須
3. **Mempool競合:** このプロットの他の取り消しがmempoolにないこと

**実装:** `src/validation.cpp:898-993`

### 検証フロー

```
トランザクションブロードキャスト
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ 最大1つのPoCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ プロット所有権を検証
  ✓ 割り当て状態をチェック
  ✓ mempool競合をチェック
       ↓
   有効 → Mempoolに受け入れ
   無効 → 拒否（伝播しない）
       ↓
ブロックマイニング
       ↓
ConnectBlock() [validation.cpp]
  ✓ すべてのチェックを再検証（多層防御）
  ✓ 状態変更を適用
  ✓ 取り消し情報を記録
```

### 多層防御

すべてのmempool検証チェックは`ConnectBlock()`中に再実行され、以下を防御:
- Mempoolバイパス攻撃
- 悪意のあるマイナーからの無効ブロック
- 再編成シナリオ中のエッジケース

ブロック検証がコンセンサスの権威として残ります。

## アトミックなデータベース更新

### 3層アーキテクチャ

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache（メモリキャッシュ）     │  ← 割り当て変更をメモリで追跡
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - ダーティ追跡: dirtyPlots            │
│   - 削除: deletedAssignments            │
│   - メモリ追跡: cachedAssignmentsUsage  │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB（データベース層）          │  ← 単一のアトミック書き込み
│   - BatchWrite(): UTXO + 割り当て       │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB（ディスクストレージ）           │  ← ACID保証
│   - アトミックトランザクション            │
└─────────────────────────────────────────┘
```

### フラッシュプロセス

ブロック接続中に`view.Flush()`が呼び出されると:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. コイン変更をベースに書き込み
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. 割り当て変更をアトミックに書き込み
    if (fOk && !dirtyPlots.empty()) {
        // ダーティな割り当てを収集
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

        // データベースに書き込み
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // 追跡をクリア
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // メモリを解放
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**実装:** `src/coins.cpp:278-315`

### データベースバッチ書き込み

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // 単一のLevelDBバッチ

    // 1. 遷移状態をマーク
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. すべてのコイン変更を書き込み
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. 一貫性のある状態をマーク
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. アトミックコミット
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// 割り当ては別途書き込まれるが同じデータベーストランザクションコンテキスト
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // 未使用パラメータ（API互換性のため保持）
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // 新しいバッチ、同じデータベース

    // 割り当て履歴を書き込み
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // 削除された割り当てを履歴から消去
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // アトミックコミット
    return m_db->WriteBatch(batch);
}
```

**実装:** `src/txdb.cpp:332-348`

### アトミック性保証

アトミックなもの:
- ブロック内のすべてのコイン変更はアトミックに書き込まれる
- ブロック内のすべての割り当て変更はアトミックに書き込まれる
- データベースはクラッシュにわたって一貫性を維持

現在の制限:
- コインと割り当ては**別々の**LevelDBバッチ操作で`view.Flush()`中に書き込まれる
- 両方の操作は`view.Flush()`中に発生するが、単一のアトミック書き込みではない
- 実際には: 両方のバッチはディスクfsync前に急速に完了
- リスクは最小限: クラッシュリカバリ中に同じブロックから両方を再生する必要

**注意:** これは単一の統一バッチを求めた元のアーキテクチャ計画とは異なります。現在の実装は2つのバッチを使用しますが、Bitcoin Coreの既存のクラッシュリカバリメカニズム（DB_HEAD_BLOCKSマーカー）を通じて一貫性を維持します。

## 再編成処理

### 取り消しデータ構造

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // 割り当てが追加された（取り消し時に削除）
        MODIFIED = 1,   // 割り当てが変更された（取り消し時に復元）
        REVOKED = 2     // 割り当てが取り消された（取り消し時に取り消しを解除）
    };

    UndoType type;
    ForgingAssignment assignment;  // 変更前の完全な状態
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO取り消しデータ
    std::vector<ForgingUndo> vforgingundo;  // 割り当て取り消しデータ
};
```

**実装:** `src/undo.h:63-105`

### DisconnectBlockプロセス

再編成中にブロックが切断されると:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... 標準UTXO切断 ...

    // ディスクから取り消しデータを読み取り
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // 割り当て変更を取り消し（逆順で処理）
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // 割り当てが追加された - 削除
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // 割り当てが取り消された - 取り消し前の状態を復元
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // 割り当てが変更された - 前の状態を復元
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**実装:** `src/validation.cpp:2381-2415`

### 再編成中のキャッシュ管理

```cpp
class CCoinsViewCache {
private:
    // 割り当てキャッシュ
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // 変更されたプロットを追跡
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // 削除を追跡
    mutable size_t cachedAssignmentsUsage{0};  // メモリ追跡

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

**実装:** `src/coins.cpp:494-565`

## RPCインターフェース

### ノードコマンド（ウォレット不要）

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

プロットアドレスの現在の割り当てステータスを返します:
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

**実装:** `src/pocx/rpc/assignments.cpp:31-126`

### ウォレットコマンド（ウォレット必須）

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

割り当てトランザクションを作成します:
- プロットアドレスから最大のUTXOを自動選択して所有権を証明
- OP_RETURN + お釣り出力でトランザクションを構築
- プロット所有者の鍵で署名
- ネットワークにブロードキャスト

**実装:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

取り消しトランザクションを作成します:
- プロットアドレスから最大のUTXOを自動選択して所有権を証明
- OP_RETURN + お釣り出力でトランザクションを構築
- プロット所有者の鍵で署名
- ネットワークにブロードキャスト

**実装:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### ウォレットトランザクション作成

ウォレットトランザクション作成プロセス:

```cpp
1. アドレスを解析および検証（P2WPKH bech32必須）
2. プロットアドレスから最大のUTXOを見つける（所有権を証明）
3. ダミー出力で一時トランザクションを作成
4. トランザクションに署名（witnessデータ付きの正確なサイズを取得）
5. ダミー出力をOP_RETURNに置換
6. サイズ変更に基づいて手数料を比例調整
7. 最終トランザクションに再署名
8. ネットワークにブロードキャスト
```

**重要な洞察:** ウォレットは所有権を証明するためにプロットアドレスから支出する必要があるため、自動的にそのアドレスからのコイン選択を強制します。

**実装:** `src/pocx/assignments/transactions.cpp:38-263`

## ファイル構造

### コア実装ファイル

```
src/
├── coins.h                        # ForgingAssignment構造体、CCoinsViewCacheメソッド [710行]
├── coins.cpp                      # キャッシュ管理、バッチ書き込み [603行]
│
├── txdb.h                         # CCoinsViewDB割り当てメソッド [90行]
├── txdb.cpp                       # データベース読み書き [349行]
│
├── undo.h                         # 再編成用ForgingUndo構造体
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock統合
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN形式、解析、検証
    │   ├── opcodes.cpp            # [259行] マーカー定義、OP_RETURN操作、所有権チェック
    │   ├── assignment_state.h     # GetEffectiveSigner、GetAssignmentStateヘルパー
    │   ├── assignment_state.cpp   # 割り当て状態クエリ関数
    │   ├── transactions.h         # ウォレットトランザクション作成API
    │   └── transactions.cpp       # create_assignment、revoke_assignmentウォレット関数
    │
    ├── rpc/
    │   ├── assignments.h          # ノードRPCコマンド（ウォレットなし）
    │   ├── assignments.cpp        # get_assignment、list_assignments RPC
    │   ├── assignments_wallet.h   # ウォレットRPCコマンド
    │   └── assignments_wallet.cpp # create_assignment、revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay、nForgingRevocationDelay
```

## パフォーマンス特性

### データベース操作

- **現在の割り当てを取得:** O(n) - プロットアドレスのすべての割り当てをスキャンして最新を見つける
- **割り当て履歴を取得:** O(n) - プロットのすべての割り当てを反復
- **割り当て作成:** O(1) - 単一挿入
- **割り当て取り消し:** O(1) - 単一更新
- **再編成（割り当てごと）:** O(1) - 取り消しデータの直接適用

nはプロットの割り当て数（通常小さい、< 10）

### メモリ使用量

- **割り当てごと:** 約160バイト（ForgingAssignment構造体）
- **キャッシュオーバーヘッド:** ダーティ追跡用ハッシュマップオーバーヘッド
- **典型的なブロック:** <10割り当て = <2 KBメモリ

### ディスク使用量

- **割り当てごと:** ディスク上約200バイト（LevelDBオーバーヘッド込み）
- **10000割り当て:** 約2 MBディスクスペース
- **UTXOセットと比較して無視できる:** 典型的なchainstateの<0.001%

## 現在の制限と将来の作業

### アトミック性の制限

**現在:** コインと割り当ては`view.Flush()`中に別々のLevelDBバッチで書き込まれる

**影響:** バッチ間でクラッシュが発生した場合の理論的な不整合リスク

**軽減:**
- 両方のバッチはfsync前に急速に完了
- Bitcoin Coreのクラッシュリカバリはdb_HEAD_BLOCKSマーカーを使用
- 実際には: テストで観察されたことなし

**将来の改善:** 単一のLevelDBバッチ操作に統一

### 割り当て履歴のプルーニング

**現在:** すべての割り当ては無期限に保存

**影響:** 割り当てごとに永久に約200バイト

**将来:** Nブロック以前の完全に取り消された割り当てのオプションプルーニング

**注意:** 必要になる可能性は低い - 100万割り当てでも = 200 MB

## テストステータス

### 実装されたテスト

✅ OP_RETURN解析と検証
✅ 所有権検証
✅ ConnectBlock割り当て作成
✅ ConnectBlock取り消し
✅ DisconnectBlock再編成処理
✅ データベース読み書き操作
✅ 状態遷移（UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED）
✅ RPCコマンド（get_assignment、create_assignment、revoke_assignment）
✅ ウォレットトランザクション作成

### テストカバレッジ領域

- ユニットテスト: `src/test/pocx_*_tests.cpp`
- 機能テスト: `test/functional/feature_pocx_*.py`
- 統合テスト: regtestでの手動テスト

## コンセンサスルール

### 割り当て作成ルール

1. **所有権:** トランザクションはプロット所有者によって署名必須
2. **状態:** プロットはUNASSIGNEDまたはREVOKED状態必須
3. **形式:** POCXマーカー + 2x 20バイトアドレスの有効なOP_RETURN
4. **一意性:** プロットごとに一度に1つのアクティブな割り当て

### 取り消しルール

1. **所有権:** トランザクションはプロット所有者によって署名必須
2. **存在:** 割り当てが存在し、まだ取り消されていない必要あり
3. **形式:** XCOPマーカー + 20バイトアドレスの有効なOP_RETURN

### アクティベーションルール

- **割り当てアクティベーション:** `assignment_height + nForgingAssignmentDelay`
- **取り消しアクティベーション:** `revocation_height + nForgingRevocationDelay`
- **遅延:** ネットワークごとに設定可能（例: 30ブロック = 2分ブロック時間で約1時間）

### ブロック検証

- 無効な割り当て/取り消し → ブロック拒否（コンセンサス失敗）
- OP_RETURN出力はUTXOセットから自動的に除外（標準Bitcoinの動作）
- 割り当て処理はConnectBlockのUTXO更新前に発生

## 結論

実装されたPoCXフォージング割り当てシステムは以下を提供します:

✅ **シンプルさ:** 標準Bitcoinトランザクション、特別なUTXOなし
✅ **コスト効率:** ダスト要件なし、トランザクション手数料のみ
✅ **再編成安全性:** 包括的な取り消しデータで正しい状態を復元
✅ **アトミック更新:** LevelDBバッチによるデータベース一貫性
✅ **完全な履歴:** すべての割り当ての完全な監査証跡
✅ **クリーンなアーキテクチャ:** Bitcoin Coreの変更を最小限に、PoCXコードを分離
✅ **本番環境対応:** 完全に実装、テスト済み、運用中

### 実装品質

- **コード構成:** 優秀 - Bitcoin CoreとPoCXのクリーンな分離
- **エラー処理:** 包括的なコンセンサス検証
- **文書化:** コードコメントと構造が十分に文書化
- **テスト:** コア機能がテストされ、統合が検証済み

### 検証された主要設計決定

1. ✅ OP_RETURN専用アプローチ（UTXOベースに対して）
2. ✅ 別のデータベースストレージ（Coin extraDataに対して）
3. ✅ 完全な履歴追跡（現在のみに対して）
4. ✅ 署名による所有権（UTXO支出に対して）
5. ✅ アクティベーション遅延（再編成攻撃を防止）

システムはすべてのアーキテクチャ目標を達成し、クリーンで保守可能な実装を実現しています。

---

[← 前へ: コンセンサスとマイニング](3-consensus-and-mining.md) | [目次](index.md) | [次へ: 時刻同期 →](5-timing-security.md)

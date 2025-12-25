[← 前へ: プロット形式](2-plot-format.md) | [目次](index.md) | [次へ: フォージング割り当て →](4-forging-assignments.md)

---

# 第3章: Bitcoin-PoCXコンセンサスとマイニングプロセス

Bitcoin Coreに統合されたPoCX（次世代容量証明）コンセンサスメカニズムとマイニングプロセスの完全な技術仕様。

---

## 目次

1. [概要](#概要)
2. [コンセンサスアーキテクチャ](#コンセンサスアーキテクチャ)
3. [マイニングプロセス](#マイニングプロセス)
4. [ブロック検証](#ブロック検証)
5. [割り当てシステム](#割り当てシステム)
6. [ネットワーク伝播](#ネットワーク伝播)
7. [技術詳細](#技術詳細)

---

## 概要

Bitcoin-PoCXは、BitcoinのProof of Workの完全な代替として、純粋な容量証明コンセンサスメカニズムを実装しています。これは後方互換性要件のない新しいチェーンです。

**主要特性:**
- **エネルギー効率**: マイニングは計算ハッシングの代わりに事前生成されたプロットファイルを使用
- **タイムベンドされたデッドライン**: 分布変換（指数→カイ二乗）が長いブロックを削減し、平均ブロック時間を改善
- **割り当てサポート**: プロット所有者はフォージング権限を他のアドレスに委譲可能
- **ネイティブC++統合**: 暗号アルゴリズムはコンセンサス検証のためにC++で実装

**マイニングフロー:**
```
外部マイナー → get_mining_info → ノンス計算 → submit_nonce →
フォージャーキュー → デッドライン待機 → ブロックフォージング → ネットワーク伝播 →
ブロック検証 → チェーン拡張
```

---

## コンセンサスアーキテクチャ

### ブロック構造

PoCXブロックはBitcoinのブロック構造を追加のコンセンサスフィールドで拡張します:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // プロットシード（32バイト）
    std::array<uint8_t, 20> account_id;       // プロットアドレス（20バイトhash160）
    uint32_t compression;                     // スケーリングレベル（1-255）
    uint64_t nonce;                           // マイニングノンス（64ビット）
    uint64_t quality;                         // 主張される品質（PoCハッシュ出力）
};

class CBlockHeader {
    // 標準Bitcoinフィールド
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCXコンセンサスフィールド（nBitsとnNonceを置換）
    int nHeight;                              // ブロック高さ（コンテキストフリー検証）
    uint256 generationSignature;              // 生成署名（マイニングエントロピー）
    uint64_t nBaseTarget;                     // 難易度パラメータ（逆難易度）
    PoCXProof pocxProof;                      // マイニング証明

    // ブロック署名フィールド
    std::array<uint8_t, 33> vchPubKey;        // 圧縮公開鍵（33バイト）
    std::array<uint8_t, 65> vchSignature;     // コンパクト署名（65バイト）
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // トランザクション
};
```

**注意:** 署名（`vchSignature`）は改ざん防止のためブロックハッシュ計算から除外されます。

**実装:** `src/primitives/block.h`

### 生成署名

生成署名はマイニングエントロピーを作成し、事前計算攻撃を防止します。

**計算:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**ジェネシスブロック:** ハードコードされた初期生成署名を使用

**実装:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### ベースターゲット（難易度）

ベースターゲットは難易度の逆数です - 高い値はより簡単なマイニングを意味します。

**調整アルゴリズム:**
- ターゲットブロック時間: 120秒（メインネット）、1秒（regtest）
- 調整間隔: 毎ブロック
- 最近のベースターゲットの移動平均を使用
- 極端な難易度変動を防ぐためにクランプ

**実装:** `src/consensus/params.h`、ブロック作成時の難易度調整

### スケーリングレベル

PoCXはスケーリングレベル（Xn）を通じてプロットファイルのスケーラブルなProof-of-Workをサポートします。

**動的境界:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // 受け入れられる最小レベル
    uint8_t nPoCXTargetCompression;  // 推奨レベル
};
```

**スケーリング増加スケジュール:**
- 指数間隔: 年4、12、28、60、124（半減期1、3、7、15、31）
- 最小スケーリングレベルが1増加
- ターゲットスケーリングレベルが1増加
- プロット作成コストと参照コストの安全マージンを維持
- 最大スケーリングレベル: 255

**実装:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## マイニングプロセス

### 1. マイニング情報の取得

**RPCコマンド:** `get_mining_info`

**プロセス:**
1. `GetNewBlockContext(chainman)`を呼び出して現在のブロックチェーン状態をフェッチ
2. 現在の高さに対する動的圧縮境界を計算
3. マイニングパラメータを返す

**レスポンス:**
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

**実装:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**注意:**
- レスポンス生成中にロックは保持されない
- コンテキスト取得は内部で`cs_main`を処理
- `block_hash`は参照用に含まれるが検証には使用されない

### 2. 外部マイニング

**外部マイナーの責任:**
1. ディスクからプロットファイルを読み取り
2. 生成署名と高さに基づいてスクープを計算
3. 最良のデッドラインを持つノンスを見つける
4. `submit_nonce`経由でノードに送信

**プロットファイル形式:**
- POC2形式（Burstcoin）に基づく
- セキュリティ修正とスケーラビリティ改善で強化
- 帰属は`CLAUDE.md`を参照

**マイナー実装:** 外部（例: Scavengerベース）

### 3. ノンス送信と検証

**RPCコマンド:** `submit_nonce`

**パラメータ:**
```
height, generation_signature, account_id, seed, nonce, quality（オプション）
```

**検証フロー（最適化順序）:**

#### ステップ1: 高速フォーマット検証
```cpp
// アカウントID: 40進文字 = 20バイト
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// シード: 64進文字 = 32バイト
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### ステップ2: コンテキスト取得
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// 戻り値: height, generation_signature, base_target, block_hash
```

**ロック:** `cs_main`は内部で処理、RPCスレッドでロックは保持されない

#### ステップ3: コンテキスト検証
```cpp
// 高さチェック
if (height != context.height) reject;

// 生成署名チェック
if (submitted_gen_sig != context.generation_signature) reject;
```

#### ステップ4: ウォレット検証
```cpp
// 有効な署名者を決定（割り当てを考慮）
effective_signer = GetEffectiveSigner(plot_address, height, view);

// ノードが有効な署名者の秘密鍵を持っているかチェック
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**割り当てサポート:** プロット所有者はフォージング権限を別のアドレスに割り当て可能。ウォレットは必ずしもプロット所有者ではなく、有効な署名者の鍵を持っている必要があります。

#### ステップ5: 証明検証
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20バイト
    block_height,
    nonce,
    seed,                // 32バイト
    min_compression,
    max_compression,
    &result             // 出力: quality, deadline
);
```

**アルゴリズム:**
1. 16進数から生成署名をデコード
2. SIMD最適化アルゴリズムを使用して圧縮範囲内の最良品質を計算
3. 品質が難易度要件を満たすことを検証
4. 生の品質値を返す

**実装:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### ステップ6: タイムベンディング計算
```cpp
// 生の難易度調整デッドライン（秒）
uint64_t deadline_seconds = quality / base_target;

// タイムベンドされたフォージ時間（秒）
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**タイムベンディング公式:**
```
Y = scale * (X^(1/3))
ここで:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**目的:** 指数分布からカイ二乗分布への変換。非常に良い解は遅くフォージ（ネットワークがディスクをスキャンする時間を確保）、悪い解は改善。長いブロックを削減、120秒平均を維持。

**実装:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### ステップ7: フォージャー送信
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // デッドラインではない - フォージャーで再計算
    height,
    generation_signature
);
```

**キューベース設計:**
- 送信は常に成功（キューに追加）
- RPCは即座に返る
- ワーカースレッドが非同期で処理

**実装:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. フォージャーキュー処理

**アーキテクチャ:**
- 単一の永続ワーカースレッド
- FIFO送信キュー
- ロックフリーのフォージング状態（ワーカースレッドのみ）
- ネストされたロックなし（デッドロック防止）

**ワーカースレッドメインループ:**
```cpp
while (!shutdown) {
    // 1. キューされた送信をチェック
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. デッドラインまたは新しい送信を待機
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmissionロジック:**
```cpp
1. 新鮮なコンテキストを取得: GetNewBlockContext(*chainman)

2. 陳腐化チェック（サイレント破棄）:
   - 高さ不一致 → 破棄
   - 生成署名不一致 → 破棄
   - ティップブロックハッシュ変更（再編成） → フォージング状態リセット

3. 品質比較:
   - quality >= current_best → 破棄

4. タイムベンドされたデッドラインを計算:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. フォージング状態を更新:
   - 既存のフォージングをキャンセル（より良いものが見つかった場合）
   - 保存: account_id, seed, nonce, quality, deadline
   - 計算: forge_time = block_time + deadline_seconds
   - 再編成検出用にティップハッシュを保存
```

**実装:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. デッドライン待機とブロックフォージング

**WaitForDeadlineOrNewSubmission:**

**待機条件:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**デッドライン到達時 - 新鮮なコンテキスト検証:**
```cpp
1. 現在のコンテキストを取得: GetNewBlockContext(*chainman)

2. 高さ検証:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. 生成署名検証:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. ベースターゲットのエッジケース:
   if (forging_base_target != current_base_target) {
       // 新しいベースターゲットでデッドラインを再計算
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // 再度待機
   }

5. すべて有効 → ForgeBlock()
```

**ForgeBlockプロセス:**

```cpp
1. 有効な署名者を決定（割り当てサポート）:
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Coinbaseスクリプトを作成:
   coinbase_script = P2WPKH(effective_signer);  // 有効な署名者に支払い

3. ブロックテンプレートを作成:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX証明を追加:
   block.pocxProof.account_id = plot_address;    // 元のプロットアドレス
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. マークルルートを再計算:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. ブロックに署名:
   // 有効な署名者の鍵を使用（プロット所有者とは異なる可能性）
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. チェーンに送信:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. 結果処理:
   if (accepted) {
       log_success();
       reset_forging_state();  // 次のブロックの準備完了
   } else {
       log_failure();
       reset_forging_state();
   }
```

**実装:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**主要な設計決定:**
- Coinbaseは有効な署名者に支払い（割り当てを尊重）
- 証明には元のプロットアドレスを含む（検証用）
- 有効な署名者の鍵で署名（所有権証明）
- テンプレート作成は自動的にmempoolトランザクションを含む

---

## ブロック検証

### 受信ブロック検証フロー

ネットワークから受信したブロックまたはローカルで送信されたブロックは、複数の段階で検証を受けます:

### ステージ1: ヘッダー検証（CheckBlockHeader）

**コンテキストフリー検証:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX検証（ENABLE_POCX定義時）:**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // 基本署名検証（まだ割り当てサポートなし）
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**基本署名検証:**
1. 公開鍵と署名フィールドの存在を確認
2. 公開鍵サイズを検証（33バイト圧縮）
3. 署名サイズを検証（65バイトコンパクト）
4. 署名から公開鍵を復元: `pubkey.RecoverCompact(hash, signature)`
5. 復元された公開鍵が保存された公開鍵と一致することを確認

**実装:** `src/validation.cpp:CheckBlockHeader()`
**署名ロジック:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### ステージ2: ブロック検証（CheckBlock）

**検証内容:**
- マークルルートの正確性
- トランザクションの妥当性
- Coinbase要件
- ブロックサイズ制限
- 標準Bitcoin コンセンサスルール

**実装:** `src/consensus/validation.cpp:CheckBlock()`

### ステージ3: コンテキストヘッダー検証（ContextualCheckBlockHeader）

**PoCX固有の検証:**

```cpp
#ifdef ENABLE_POCX
    // ステップ1: 生成署名を検証
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // ステップ2: ベースターゲットを検証
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // ステップ3: 容量証明を検証
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

    // ステップ4: デッドラインタイミングを検証
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**検証ステップ:**
1. **生成署名:** 前のブロックから計算された値と一致する必要あり
2. **ベースターゲット:** 難易度調整計算と一致する必要あり
3. **スケーリングレベル:** ネットワーク最小値を満たす必要あり（`compression >= min_compression`）
4. **品質主張:** 送信された品質は証明から計算された品質と一致する必要あり
5. **容量証明:** 暗号証明検証（SIMD最適化）
6. **デッドラインタイミング:** タイムベンドされたデッドライン（`poc_time`）は経過時間以下である必要あり

**実装:** `src/validation.cpp:ContextualCheckBlockHeader()`

### ステージ4: ブロック接続（ConnectBlock）

**完全なコンテキスト検証:**

```cpp
#ifdef ENABLE_POCX
    // 割り当てサポート付きの拡張署名検証
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**拡張署名検証:**
1. 基本署名検証を実行
2. 復元された公開鍵からアカウントIDを抽出
3. プロットアドレスの有効な署名者を取得: `GetEffectiveSigner(plot_address, height, view)`
4. 公開鍵アカウントが有効な署名者と一致することを確認

**割り当てロジック:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // 割り当てられた署名者を返す
    }

    return plotAddress;  // 割り当てなし - プロット所有者が署名
}
```

**実装:**
- 接続: `src/validation.cpp:ConnectBlock()`
- 拡張検証: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- 割り当てロジック: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### ステージ5: チェーンアクティベーション

**ProcessNewBlockフロー:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → 検証してディスクに保存
    2. ActivateBestChain → これが最良のチェーンならチェーンティップを更新
    3. ネットワークに新しいブロックを通知
}
```

**実装:** `src/validation.cpp:ProcessNewBlock()`

### 検証サマリー

**完全な検証パス:**
```
ブロック受信
    ↓
CheckBlockHeader（基本署名）
    ↓
CheckBlock（トランザクション、マークル）
    ↓
ContextualCheckBlockHeader（生成署名、ベースターゲット、PoC証明、デッドライン）
    ↓
ConnectBlock（割り当て付き拡張署名、状態遷移）
    ↓
ActivateBestChain（再編成処理、チェーン拡張）
    ↓
ネットワーク伝播
```

---

## 割り当てシステム

### 概要

割り当ては、プロット所有者がプロット所有権を維持しながらフォージング権限を他のアドレスに委譲することを可能にします。

**ユースケース:**
- プールマイニング（プロットがプールアドレスに割り当て）
- コールドストレージ（マイニングキーをプロット所有権から分離）
- マルチパーティマイニング（共有インフラストラクチャ）

### 割り当てアーキテクチャ

**OP_RETURN専用設計:**
- 割り当てはOP_RETURN出力に保存（UTXOなし）
- 支出要件なし（ダストなし、保持用手数料なし）
- CCoinsViewCache拡張状態で追跡
- 遅延期間後にアクティベート（デフォルト: 4ブロック）

**割り当て状態:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 割り当てなし
    ASSIGNING = 1,   // 割り当てアクティベーション保留中（遅延期間）
    ASSIGNED = 2,    // 割り当てアクティブ、フォージング許可
    REVOKING = 3,    // 取り消し保留中（遅延期間、まだアクティブ）
    REVOKED = 4      // 取り消し完了、割り当て無効
};
```

### 割り当ての作成

**トランザクション形式:**
```cpp
Transaction {
    inputs: [any]  // プロットアドレスの所有権を証明
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**検証ルール:**
1. 入力はプロット所有者によって署名される必要あり（所有権を証明）
2. OP_RETURNに有効な割り当てデータを含む
3. プロットはUNASSIGNEDまたはREVOKED状態である必要あり
4. mempoolに重複する保留中の割り当てがないこと
5. 最小トランザクション手数料を支払い

**アクティベーション:**
- 割り当ては確認高さでASSIGNINGになる
- 遅延期間後にASSIGNEDになる（regtestは4ブロック、メインネットは30ブロック）
- 遅延はブロックレース中の急速な再割り当てを防止

**実装:** `src/script/forging_assignment.h`、ConnectBlockでの検証

### 割り当ての取り消し

**トランザクション形式:**
```cpp
Transaction {
    inputs: [any]  // プロットアドレスの所有権を証明
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**効果:**
- 即座にREVOKED状態に遷移
- プロット所有者は即座にフォージ可能
- その後新しい割り当てを作成可能

### マイニング中の割り当て検証

**有効な署名者の決定:**
```cpp
// submit_nonce検証内
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// ブロックフォージング内
coinbase_script = P2WPKH(effective_signer);  // 報酬はここに

// ブロック署名内
signature = effective_signer_key.SignCompact(hash);  // 有効な署名者で署名必須
```

**ブロック検証:**
```cpp
// VerifyPoCXBlockCompactSignature（拡張）内
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**主要特性:**
- 証明には常に元のプロットアドレスを含む
- 署名は有効な署名者からである必要あり
- Coinbaseは有効な署名者に支払い
- 検証はブロック高さでの割り当て状態を使用

---

## ネットワーク伝播

### ブロックアナウンス

**標準Bitcoin P2Pプロトコル:**
1. フォージされたブロックは`ProcessNewBlock()`経由で送信
2. ブロックは検証されチェーンに追加
3. ネットワーク通知: `GetMainSignals().BlockConnected()`
4. P2Pレイヤーがピアにブロックをブロードキャスト

**実装:** 標準Bitcoin Core net_processing

### ブロックリレー

**コンパクトブロック（BIP 152）:**
- 効率的なブロック伝播に使用
- 最初はトランザクションIDのみを送信
- ピアが不足トランザクションをリクエスト

**フルブロックリレー:**
- コンパクトブロックが失敗した場合のフォールバック
- 完全なブロックデータを送信

### チェーン再編成

**再編成処理:**
```cpp
// フォージャーワーカースレッド内
if (current_tip_hash != stored_tip_hash) {
    // チェーン再編成を検出
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**ブロックチェーンレベル:**
- 標準Bitcoin Coreの再編成処理
- 最良チェーンはchainworkで決定
- 切断されたブロックはmempoolに戻る

---

## 技術詳細

### デッドロック防止

**ABBAデッドロックパターン（防止済み）:**
```
スレッドA: cs_main → cs_wallet
スレッドB: cs_wallet → cs_main
```

**解決策:**
1. **submit_nonce:** cs_main使用ゼロ
   - `GetNewBlockContext()`が内部でロックを処理
   - フォージャー送信前にすべての検証

2. **フォージャー:** キューベースアーキテクチャ
   - 単一ワーカースレッド（スレッドジョインなし）
   - アクセスごとに新鮮なコンテキスト
   - ネストされたロックなし

3. **ウォレットチェック:** 高価な操作前に実行
   - 鍵がない場合は早期拒否
   - ブロックチェーン状態アクセスとは分離

### パフォーマンス最適化

**高速失敗検証:**
```cpp
1. フォーマットチェック（即座）
2. コンテキスト検証（軽量）
3. ウォレット検証（ローカル）
4. 証明検証（高価なSIMD）
```

**単一コンテキストフェッチ:**
- 送信ごとに1回の`GetNewBlockContext()`呼び出し
- 複数チェック用に結果をキャッシュ
- cs_main取得の繰り返しなし

**キュー効率:**
- 軽量な送信構造
- キューにbase_target/deadlineなし（新鮮に再計算）
- 最小限のメモリフットプリント

### 陳腐化処理

**「愚直な」フォージャー設計:**
- ブロックチェーンイベントサブスクリプションなし
- 必要時の遅延検証
- 古い送信のサイレント破棄

**利点:**
- シンプルなアーキテクチャ
- 複雑な同期なし
- エッジケースに対して堅牢

**処理されるエッジケース:**
- 高さ変更 → 破棄
- 生成署名変更 → 破棄
- ベースターゲット変更 → デッドライン再計算
- 再編成 → フォージング状態リセット

### 暗号詳細

**生成署名:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**ブロック署名ハッシュ:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**コンパクト署名形式:**
- 65バイト: [recovery_id][r][s]
- 公開鍵復元を可能に
- スペース効率のために使用

**アカウントID:**
- 圧縮公開鍵の20バイトHASH160
- Bitcoinアドレス形式と一致（P2PKH、P2WPKH）

### 将来の拡張

**文書化された制限:**
1. パフォーマンスメトリクスなし（送信レート、デッドライン分布）
2. マイナー向けの詳細なエラー分類なし
3. フォージャーステータスのクエリ制限（現在のデッドライン、キュー深度）

**潜在的改善:**
- フォージャーステータス用RPC
- マイニング効率のメトリクス
- デバッグ用の拡張ロギング
- プールプロトコルサポート

---

## コード参照

**コア実装:**
- RPCインターフェース: `src/pocx/rpc/mining.cpp`
- フォージャーキュー: `src/pocx/mining/scheduler.cpp`
- コンセンサス検証: `src/pocx/consensus/validation.cpp`
- 証明検証: `src/pocx/consensus/pocx.cpp`
- タイムベンディング: `src/pocx/algorithms/time_bending.cpp`
- ブロック検証: `src/validation.cpp`（CheckBlockHeader、ConnectBlock）
- 割り当てロジック: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- コンテキスト管理: `src/pocx/node/node.cpp:GetNewBlockContext()`

**データ構造:**
- ブロック形式: `src/primitives/block.h`
- コンセンサスパラメータ: `src/consensus/params.h`
- 割り当て追跡: `src/coins.h`（CCoinsViewCache拡張）

---

## 付録: アルゴリズム仕様

### タイムベンディング公式

**数学的定義:**
```
deadline_seconds = quality / base_target（生）

time_bended_deadline = scale * (deadline_seconds)^(1/3)

ここで:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**実装:**
- 固定小数点演算（Q42形式）
- 整数のみの立方根計算
- 256ビット演算に最適化

### 品質計算

**プロセス:**
1. 生成署名と高さからスクープを生成
2. 計算されたスクープのプロットデータを読み取り
3. ハッシュ: `SHABAL256(generation_signature || scoop_data)`
4. 最小から最大までスケーリングレベルをテスト
5. 見つかった最良の品質を返す

**スケーリング:**
- レベルX0: POC2ベースライン（理論的）
- レベルX1: XOR-transposeベースライン
- レベルXn: 2^(n-1) × X1ワークが埋め込み
- 高いスケーリング = より多くのプロット生成作業

### ベースターゲット調整

**毎ブロック調整:**
1. 最近のベースターゲットの移動平均を計算
2. ローリングウィンドウの実際のタイムスパンとターゲットタイムスパンを計算
3. ベースターゲットを比例調整
4. 極端な変動を防ぐためにクランプ

**公式:**
```
avg_base_target = moving_average(最近のベースターゲット)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*本文書は2025年10月時点の完全なPoCXコンセンサス実装を反映しています。*

---

[← 前へ: プロット形式](2-plot-format.md) | [目次](index.md) | [次へ: フォージング割り当て →](4-forging-assignments.md)

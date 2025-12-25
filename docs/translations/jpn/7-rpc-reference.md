[← 前へ: ネットワークパラメータ](6-network-parameters.md) | [目次](index.md) | [次へ: ウォレットガイド →](8-wallet-guide.md)

---

# 第7章: RPCインターフェースリファレンス

マイニングRPC、割り当て管理、および変更されたブロックチェーンRPCを含む、Bitcoin-PoCX RPCコマンドの完全なリファレンス。

---

## 目次

1. [設定](#設定)
2. [PoCXマイニングRPC](#pocxマイニングrpc)
3. [割り当てRPC](#割り当てrpc)
4. [変更されたブロックチェーンRPC](#変更されたブロックチェーンrpc)
5. [無効化されたRPC](#無効化されたrpc)
6. [統合例](#統合例)

---

## 設定

### マイニングサーバーモード

**フラグ**: `-miningserver`

**目的**: 外部マイナーがマイニング固有のRPCを呼び出すためのRPCアクセスを有効化

**要件**:
- `submit_nonce`の動作に必要
- QTウォレットでのフォージング割り当てダイアログの表示に必要

**使用法**:
```bash
# コマンドライン
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**セキュリティ考慮事項**:
- 標準RPC認証情報以外の追加認証なし
- マイニングRPCはキュー容量によってレート制限
- 標準RPC認証は引き続き必要

**実装**: `src/pocx/rpc/mining.cpp`

---

## PoCXマイニングRPC

### get_mining_info

**カテゴリ**: mining
**マイニングサーバー必須**: いいえ
**ウォレット必須**: いいえ

**目的**: 外部マイナーがプロットファイルをスキャンしてデッドラインを計算するために必要な現在のマイニングパラメータを返す。

**パラメータ**: なし

**戻り値**:
```json
{
  "generation_signature": "abc123...",       // 16進数、64文字
  "base_target": 36650387593,                // 数値
  "height": 12345,                           // 数値、次のブロック高さ
  "block_hash": "def456...",                 // 16進数、前のブロック
  "target_quality": 18446744073709551615,    // uint64_max（すべての解を受け入れ）
  "minimum_compression_level": 1,            // 数値
  "target_compression_level": 2              // 数値
}
```

**フィールド説明**:
- `generation_signature`: このブロック高さの決定論的マイニングエントロピー
- `base_target`: 現在の難易度（高い = 簡単）
- `height`: マイナーがターゲットとするブロック高さ
- `block_hash`: 前のブロックハッシュ（情報提供用）
- `target_quality`: 品質しきい値（現在uint64_max、フィルタリングなし）
- `minimum_compression_level`: 検証に必要な最小圧縮
- `target_compression_level`: 最適マイニングの推奨圧縮

**エラーコード**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: ノードがまだ同期中

**例**:
```bash
bitcoin-cli get_mining_info
```

**実装**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**カテゴリ**: mining
**マイニングサーバー必須**: はい
**ウォレット必須**: はい（秘密鍵用）

**目的**: PoCXマイニング解を送信。証明を検証し、タイムベンドされたフォージング用にキューに入れ、予定時刻に自動的にブロックを作成。

**パラメータ**:
1. `height`（数値、必須）- ブロック高さ
2. `generation_signature`（文字列16進数、必須）- 生成署名（64文字）
3. `account_id`（文字列、必須）- プロットアカウントID（40進文字 = 20バイト）
4. `seed`（文字列、必須）- プロットシード（64進文字 = 32バイト）
5. `nonce`（数値、必須）- マイニングノンス
6. `compression`（数値、必須）- 使用されたスケーリング/圧縮レベル（1-255）
7. `quality`（数値、オプション）- 品質値（省略時は再計算）

**戻り値**（成功時）:
```json
{
  "accepted": true,
  "quality": 120,           // 難易度調整済みデッドライン（秒）
  "poc_time": 45            // タイムベンドされたフォージ時間（秒）
}
```

**戻り値**（拒否時）:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**検証ステップ**:
1. **フォーマット検証**（高速失敗）:
   - アカウントID: 正確に40進文字
   - シード: 正確に64進文字
2. **コンテキスト検証**:
   - 高さは現在のティップ + 1と一致必須
   - 生成署名は現在のものと一致必須
3. **ウォレット検証**:
   - 有効な署名者を決定（アクティブな割り当てをチェック）
   - ウォレットが有効な署名者の秘密鍵を持っていることを確認
4. **証明検証**（高コスト）:
   - 圧縮境界でPoCX証明を検証
   - 生の品質を計算
5. **スケジューラ送信**:
   - タイムベンドされたフォージング用にノンスをキューに入れる
   - ブロックはforge_timeに自動的に作成される

**エラーコード**:
- `RPC_INVALID_PARAMETER`: 無効なフォーマット（account_id、seed）または高さ不一致
- `RPC_VERIFY_REJECTED`: 生成署名不一致または証明検証失敗
- `RPC_INVALID_ADDRESS_OR_KEY`: 有効な署名者の秘密鍵なし
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: 送信キューが満杯
- `RPC_INTERNAL_ERROR`: PoCXスケジューラ初期化失敗

**証明検証エラーコード**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**例**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**注意**:
- 送信は非同期 - RPCは即座に返り、ブロックは後でフォージされる
- タイムベンディングは良い解を遅らせてネットワーク全体のプロットスキャンを可能に
- 割り当てシステム: プロットが割り当てられている場合、ウォレットはフォージングアドレスの鍵を持っている必要
- 圧縮境界はブロック高さに基づいて動的に調整

**実装**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## 割り当てRPC

### get_assignment

**カテゴリ**: mining
**マイニングサーバー必須**: いいえ
**ウォレット必須**: いいえ

**目的**: プロットアドレスのフォージング割り当てステータスをクエリ。読み取り専用、ウォレット不要。

**パラメータ**:
1. `plot_address`（文字列、必須）- プロットアドレス（bech32 P2WPKH形式）
2. `height`（数値、オプション）- クエリするブロック高さ（デフォルト: 現在のティップ）

**戻り値**（割り当てなし）:
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**戻り値**（アクティブな割り当て）:
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

**戻り値**（取り消し中）:
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

**割り当て状態**:
- `UNASSIGNED`: 割り当てなし
- `ASSIGNING`: 割り当てtx確認済み、アクティベーション遅延進行中
- `ASSIGNED`: 割り当てアクティブ、フォージング権限委譲済み
- `REVOKING`: 取り消しtx確認済み、遅延経過まで有効
- `REVOKED`: 取り消し完了、フォージング権限がプロット所有者に戻る

**エラーコード**:
- `RPC_INVALID_ADDRESS_OR_KEY`: 無効なアドレスまたはP2WPKH（bech32）でない

**例**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**実装**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**カテゴリ**: wallet
**マイニングサーバー必須**: いいえ
**ウォレット必須**: はい（ロードおよびアンロック必須）

**目的**: フォージング権限を別のアドレス（例: マイニングプール）に委譲するフォージング割り当てトランザクションを作成。

**パラメータ**:
1. `plot_address`（文字列、必須）- プロット所有者アドレス（秘密鍵を所有必須、P2WPKH bech32）
2. `forging_address`（文字列、必須）- フォージング権限を割り当てるアドレス（P2WPKH bech32）
3. `fee_rate`（数値、オプション）- BTC/kvBでの手数料率（デフォルト: 10× minRelayFee）

**戻り値**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**要件**:
- ウォレットがロードされアンロックされていること
- plot_addressの秘密鍵がウォレットにあること
- 両方のアドレスがP2WPKH（bech32形式: pocx1q... メインネット、tpocx1q... テストネット）であること
- プロットアドレスに確認済みUTXOがあること（所有権の証明）
- プロットにアクティブな割り当てがないこと（先に取り消しが必要）

**トランザクション構造**:
- 入力: プロットアドレスからのUTXO（所有権を証明）
- 出力: OP_RETURN（46バイト）: `POCX`マーカー + plot_address（20バイト）+ forging_address（20バイト）
- 出力: お釣りはウォレットに戻る

**アクティベーション**:
- 割り当ては確認時にASSIGNINGになる
- `nForgingAssignmentDelay`ブロック後にACTIVEになる
- 遅延はチェーンフォーク中の急速な再割り当てを防止

**エラーコード**:
- `RPC_WALLET_NOT_FOUND`: ウォレット利用不可
- `RPC_WALLET_UNLOCK_NEEDED`: ウォレットが暗号化されロック中
- `RPC_WALLET_ERROR`: トランザクション作成失敗
- `RPC_INVALID_ADDRESS_OR_KEY`: 無効なアドレス形式

**例**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**実装**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**カテゴリ**: wallet
**マイニングサーバー必須**: いいえ
**ウォレット必須**: はい（ロードおよびアンロック必須）

**目的**: 既存のフォージング割り当てを取り消し、フォージング権限をプロット所有者に戻す。

**パラメータ**:
1. `plot_address`（文字列、必須）- プロットアドレス（秘密鍵を所有必須、P2WPKH bech32）
2. `fee_rate`（数値、オプション）- BTC/kvBでの手数料率（デフォルト: 10× minRelayFee）

**戻り値**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**要件**:
- ウォレットがロードされアンロックされていること
- plot_addressの秘密鍵がウォレットにあること
- プロットアドレスがP2WPKH（bech32形式）であること
- プロットアドレスに確認済みUTXOがあること

**トランザクション構造**:
- 入力: プロットアドレスからのUTXO（所有権を証明）
- 出力: OP_RETURN（26バイト）: `XCOP`マーカー + plot_address（20バイト）
- 出力: お釣りはウォレットに戻る

**効果**:
- 状態は即座にREVOKINGに遷移
- フォージングアドレスは遅延期間中もフォージ可能
- `nForgingRevocationDelay`ブロック後にREVOKEDになる
- プロット所有者は取り消し有効後にフォージ可能
- 取り消し完了後に新しい割り当てを作成可能

**エラーコード**:
- `RPC_WALLET_NOT_FOUND`: ウォレット利用不可
- `RPC_WALLET_UNLOCK_NEEDED`: ウォレットが暗号化されロック中
- `RPC_WALLET_ERROR`: トランザクション作成失敗

**例**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**注意**:
- 冪等: アクティブな割り当てがなくても取り消し可能
- 一度送信した取り消しはキャンセル不可

**実装**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## 変更されたブロックチェーンRPC

### getdifficulty

**PoCX変更点**:
- **計算**: `reference_base_target / current_base_target`
- **参照**: 1 TiBネットワーク容量（base_target = 36650387593）
- **解釈**: 推定ネットワークストレージ容量（TiB単位）
  - 例: `1.0` = 約1 TiB
  - 例: `1024.0` = 約1 PiB
- **PoWとの違い**: ハッシュパワーではなく容量を表す

**例**:
```bash
bitcoin-cli getdifficulty
# 戻り値: 2048.5（ネットワーク約2 PiB）
```

**実装**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX追加フィールド**:
- `time_since_last_block`（数値）- 前のブロックからの秒数（mediantimeを置換）
- `poc_time`（数値）- タイムベンドされたフォージ時間（秒）
- `base_target`（数値）- PoCX難易度ベースターゲット
- `generation_signature`（文字列16進数）- 生成署名
- `pocx_proof`（オブジェクト）:
  - `account_id`（文字列16進数）- プロットアカウントID（20バイト）
  - `seed`（文字列16進数）- プロットシード（32バイト）
  - `nonce`（数値）- マイニングノンス
  - `compression`（数値）- 使用されたスケーリングレベル
  - `quality`（数値）- 主張された品質値
- `pubkey`（文字列16進数）- ブロック署名者の公開鍵（33バイト）
- `signer_address`（文字列）- ブロック署名者のアドレス
- `signature`（文字列16進数）- ブロック署名（65バイト）

**PoCX削除フィールド**:
- `mediantime` - 削除（time_since_last_blockで置換）

**例**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**実装**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX変更点**: getblockheaderと同じ、さらに完全なトランザクションデータ

**例**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # tx詳細付きverbose
```

**実装**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX追加フィールド**:
- `base_target`（数値）- 現在のベースターゲット
- `generation_signature`（文字列16進数）- 現在の生成署名

**PoCX変更フィールド**:
- `difficulty` - PoCX計算を使用（容量ベース）

**PoCX削除フィールド**:
- `mediantime` - 削除

**例**:
```bash
bitcoin-cli getblockchaininfo
```

**実装**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX追加フィールド**:
- `generation_signature`（文字列16進数）- プールマイニング用
- `base_target`（数値）- プールマイニング用

**PoCX削除フィールド**:
- `target` - 削除（PoW固有）
- `noncerange` - 削除（PoW固有）
- `bits` - 削除（PoW固有）

**注意**:
- ブロック構築用の完全なトランザクションデータを含む
- プールサーバーの連携マイニングに使用

**例**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**実装**: `src/rpc/mining.cpp`

---

## 無効化されたRPC

以下のPoW固有RPCはPoCXモードで**無効化**されています:

### getnetworkhashps
- **理由**: ハッシュレートは容量証明に適用されない
- **代替**: ネットワーク容量推定には`getdifficulty`を使用

### getmininginfo
- **理由**: PoW固有情報を返す
- **代替**: `get_mining_info`（PoCX固有）を使用

### generate, generatetoaddress, generatetodescriptor, generateblock
- **理由**: CPUマイニングはPoCXに適用されない（事前生成されたプロットが必要）
- **代替**: 外部プロッター + マイナー + `submit_nonce`を使用

**実装**: `src/rpc/mining.cpp`（ENABLE_POCX定義時にRPCはエラーを返す）

---

## 統合例

### 外部マイナー統合

**基本マイニングループ**:
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

# マイニングループ
while True:
    # 1. マイニングパラメータを取得
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. プロットファイルをスキャン（外部実装）
    best_nonce = scan_plots(gen_sig, height)

    # 3. 最良の解を送信
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"解が受け入れられました! 品質: {result['quality']}秒, "
              f"フォージ時間: {result['poc_time']}秒")

    # 4. 次のブロックを待機
    time.sleep(10)  # ポーリング間隔
```

---

### プール統合パターン

**プールサーバーワークフロー**:
1. マイナーがプールアドレスへのフォージング割り当てを作成
2. プールはフォージングアドレスの鍵を持つウォレットを実行
3. プールが`get_mining_info`を呼び出しマイナーに配布
4. マイナーはプール経由で解を送信（チェーンに直接ではなく）
5. プールが検証して自分の鍵で`submit_nonce`を呼び出す
6. プールがポリシーに従って報酬を分配

**割り当て管理**:
```bash
# マイナーが割り当てを作成（マイナーのウォレットから）
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# アクティベーションを待機（メインネット30ブロック）

# プールが割り当てステータスを確認
bitcoin-cli get_assignment "pocx1qminer_plot..."

# プールがこのプロットのノンスを送信可能に
# （プールウォレットはpocx1qpool...の秘密鍵を持っている必要）
```

---

### ブロックエクスプローラクエリ

**PoCXブロックデータのクエリ**:
```bash
# 最新ブロックを取得
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# PoCX証明付きブロック詳細を取得
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX固有フィールドを抽出
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

**割り当てトランザクションの検出**:
```bash
# トランザクションからOP_RETURNをスキャン
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# 割り当てマーカーをチェック（POCX = 0x504f4358）
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## エラー処理

### 一般的なエラーパターン

**高さ不一致**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**解決策**: マイニング情報を再取得、チェーンが進行した

**生成署名不一致**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**解決策**: マイニング情報を再取得、新しいブロックが到着した

**秘密鍵なし**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**解決策**: プロットまたはフォージングアドレスの鍵をインポート

**割り当てアクティベーション保留中**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**解決策**: アクティベーション遅延が経過するまで待機

---

## コード参照

**マイニングRPC**: `src/pocx/rpc/mining.cpp`
**割り当てRPC**: `src/pocx/rpc/assignments.cpp`、`src/pocx/rpc/assignments_wallet.cpp`
**ブロックチェーンRPC**: `src/rpc/blockchain.cpp`
**証明検証**: `src/pocx/consensus/validation.cpp`、`src/pocx/consensus/pocx.cpp`
**割り当て状態**: `src/pocx/assignments/assignment_state.cpp`
**トランザクション作成**: `src/pocx/assignments/transactions.cpp`

---

## 相互参照

関連章:
- [第3章: コンセンサスとマイニング](3-consensus-and-mining.md) - マイニングプロセスの詳細
- [第4章: フォージング割り当て](4-forging-assignments.md) - 割り当てシステムアーキテクチャ
- [第6章: ネットワークパラメータ](6-network-parameters.md) - 割り当て遅延値
- [第8章: ウォレットガイド](8-wallet-guide.md) - 割り当て管理のGUI

---

[← 前へ: ネットワークパラメータ](6-network-parameters.md) | [目次](index.md) | [次へ: ウォレットガイド →](8-wallet-guide.md)

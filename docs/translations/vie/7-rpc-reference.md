[← Trước: Tham số Mạng](6-network-parameters.md) | [Mục lục](index.md) | [Tiếp: Hướng dẫn Ví →](8-wallet-guide.md)

---

# Chương 7: Tham chiếu Giao diện RPC

Tham chiếu đầy đủ cho các lệnh RPC Bitcoin-PoCX, bao gồm các RPC đào, quản lý ủy quyền và các RPC blockchain được sửa đổi.

---

## Mục lục

1. [Cấu hình](#cấu-hình)
2. [RPC Đào PoCX](#rpc-đào-pocx)
3. [RPC Ủy quyền](#rpc-ủy-quyền)
4. [RPC Blockchain Được sửa đổi](#rpc-blockchain-được-sửa-đổi)
5. [RPC Bị vô hiệu hóa](#rpc-bị-vô-hiệu-hóa)
6. [Ví dụ Tích hợp](#ví-dụ-tích-hợp)

---

## Cấu hình

### Chế độ Mining Server

**Cờ**: `-miningserver`

**Mục đích**: Bật truy cập RPC cho thợ đào bên ngoài gọi các RPC đặc thù đào

**Yêu cầu**:
- Yêu cầu để `submit_nonce` hoạt động
- Yêu cầu để hiển thị hộp thoại ủy quyền forging trong ví Qt

**Sử dụng**:
```bash
# Dòng lệnh
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Cân nhắc Bảo mật**:
- Không có xác thực bổ sung ngoài thông tin RPC tiêu chuẩn
- Các RPC đào bị giới hạn bởi dung lượng hàng đợi
- Xác thực RPC tiêu chuẩn vẫn được yêu cầu

**Triển khai**: `src/pocx/rpc/mining.cpp`

---

## RPC Đào PoCX

### get_mining_info

**Danh mục**: mining
**Yêu cầu Mining Server**: Không
**Yêu cầu Ví**: Không

**Mục đích**: Trả về các tham số đào hiện tại cần thiết cho thợ đào bên ngoài quét tệp plot và tính deadline.

**Tham số**: Không

**Giá trị Trả về**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 ký tự
  "base_target": 36650387593,                // số
  "height": 12345,                           // số, chiều cao khối tiếp theo
  "block_hash": "def456...",                 // hex, khối trước
  "target_quality": 18446744073709551615,    // uint64_max (tất cả lời giải được chấp nhận)
  "minimum_compression_level": 1,            // số
  "target_compression_level": 2              // số
}
```

**Mô tả Trường**:
- `generation_signature`: Entropy đào xác định cho chiều cao khối này
- `base_target`: Độ khó hiện tại (cao hơn = dễ hơn)
- `height`: Chiều cao khối thợ đào nên nhắm đến
- `block_hash`: Hash khối trước (thông tin)
- `target_quality`: Ngưỡng chất lượng (hiện tại uint64_max, không lọc)
- `minimum_compression_level`: Nén tối thiểu cần thiết cho xác thực
- `target_compression_level`: Nén khuyến nghị cho đào tối ưu

**Mã Lỗi**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node vẫn đang đồng bộ

**Ví dụ**:
```bash
bitcoin-cli get_mining_info
```

**Triển khai**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Danh mục**: mining
**Yêu cầu Mining Server**: Có
**Yêu cầu Ví**: Có (cho khóa riêng)

**Mục đích**: Gửi lời giải đào PoCX. Xác thực bằng chứng, xếp hàng cho forging time-bended, và tự động tạo khối tại thời gian đã lên lịch.

**Tham số**:
1. `height` (số, bắt buộc) - Chiều cao khối
2. `generation_signature` (chuỗi hex, bắt buộc) - Chữ ký sinh (64 ký tự)
3. `account_id` (chuỗi, bắt buộc) - ID tài khoản plot (40 ký tự hex = 20 byte)
4. `seed` (chuỗi, bắt buộc) - Seed plot (64 ký tự hex = 32 byte)
5. `nonce` (số, bắt buộc) - Mining nonce
6. `compression` (số, bắt buộc) - Cấp độ mở rộng/nén sử dụng (1-255)
7. `quality` (số, tùy chọn) - Giá trị chất lượng (tính lại nếu bỏ qua)

**Giá trị Trả về** (thành công):
```json
{
  "accepted": true,
  "quality": 120,           // deadline đã điều chỉnh độ khó tính bằng giây
  "poc_time": 45            // thời gian forge time-bended tính bằng giây
}
```

**Giá trị Trả về** (từ chối):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Các Bước Xác thực**:
1. **Xác thực Định dạng** (thất bại nhanh):
   - Account ID: chính xác 40 ký tự hex
   - Seed: chính xác 64 ký tự hex
2. **Xác thực Ngữ cảnh**:
   - Chiều cao phải khớp tip hiện tại + 1
   - Chữ ký sinh phải khớp hiện tại
3. **Xác minh Ví**:
   - Xác định người ký hiệu quả (kiểm tra ủy quyền hoạt động)
   - Xác minh ví có khóa riêng cho người ký hiệu quả
4. **Xác thực Bằng chứng** (tốn kém):
   - Xác thực bằng chứng PoCX với giới hạn nén
   - Tính chất lượng thô
5. **Gửi Scheduler**:
   - Xếp hàng nonce cho forging time-bended
   - Khối sẽ được tạo tự động tại forge_time

**Mã Lỗi**:
- `RPC_INVALID_PARAMETER`: Định dạng không hợp lệ (account_id, seed) hoặc chiều cao không khớp
- `RPC_VERIFY_REJECTED`: Chữ ký sinh không khớp hoặc xác thực bằng chứng thất bại
- `RPC_INVALID_ADDRESS_OR_KEY`: Không có khóa riêng cho người ký hiệu quả
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Hàng đợi submission đầy
- `RPC_INTERNAL_ERROR`: Không thể khởi tạo PoCX scheduler

**Mã Lỗi Xác thực Bằng chứng**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Ví dụ**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Lưu ý**:
- Submission bất đồng bộ - RPC trả về ngay lập tức, khối được forge sau
- Time Bending trì hoãn lời giải tốt để cho phép quét plot toàn mạng
- Hệ thống ủy quyền: nếu plot được ủy quyền, ví phải có khóa địa chỉ forging
- Giới hạn nén được điều chỉnh động dựa trên chiều cao khối

**Triển khai**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC Ủy quyền

### get_assignment

**Danh mục**: mining
**Yêu cầu Mining Server**: Không
**Yêu cầu Ví**: Không

**Mục đích**: Truy vấn trạng thái ủy quyền forging cho một địa chỉ plot. Chỉ đọc, không yêu cầu ví.

**Tham số**:
1. `plot_address` (chuỗi, bắt buộc) - Địa chỉ plot (định dạng P2WPKH bech32)
2. `height` (số, tùy chọn) - Chiều cao khối để truy vấn (mặc định: tip hiện tại)

**Giá trị Trả về** (không có ủy quyền):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Giá trị Trả về** (ủy quyền hoạt động):
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

**Giá trị Trả về** (đang thu hồi):
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

**Các Trạng thái Ủy quyền**:
- `UNASSIGNED`: Không có ủy quyền
- `ASSIGNING`: Tx ủy quyền đã xác nhận, độ trễ kích hoạt đang tiến hành
- `ASSIGNED`: Ủy quyền hoạt động, quyền forging đã được ủy thác
- `REVOKING`: Tx thu hồi đã xác nhận, vẫn hoạt động cho đến khi độ trễ kết thúc
- `REVOKED`: Thu hồi hoàn tất, quyền forging trả về chủ sở hữu plot

**Mã Lỗi**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Địa chỉ không hợp lệ hoặc không phải P2WPKH (bech32)

**Ví dụ**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Triển khai**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Danh mục**: wallet
**Yêu cầu Mining Server**: Không
**Yêu cầu Ví**: Có (phải được tải và mở khóa)

**Mục đích**: Tạo giao dịch ủy quyền forging để ủy thác quyền forging cho địa chỉ khác (ví dụ, pool đào).

**Tham số**:
1. `plot_address` (chuỗi, bắt buộc) - Địa chỉ chủ sở hữu plot (phải sở hữu khóa riêng, P2WPKH bech32)
2. `forging_address` (chuỗi, bắt buộc) - Địa chỉ để ủy quyền quyền forging (P2WPKH bech32)
3. `fee_rate` (số, tùy chọn) - Tỷ lệ phí theo BTC/kvB (mặc định: 10× minRelayFee)

**Giá trị Trả về**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Yêu cầu**:
- Ví được tải và mở khóa
- Khóa riêng cho plot_address trong ví
- Cả hai địa chỉ phải là P2WPKH (định dạng bech32: pocx1q... mainnet, tpocx1q... testnet)
- Địa chỉ plot phải có UTXO đã xác nhận (chứng minh quyền sở hữu)
- Plot không được có ủy quyền hoạt động (thu hồi trước)

**Cấu trúc Giao dịch**:
- Input: UTXO từ địa chỉ plot (chứng minh quyền sở hữu)
- Output: OP_RETURN (46 byte): marker `POCX` + plot_address (20 byte) + forging_address (20 byte)
- Output: Tiền thừa trả về ví

**Kích hoạt**:
- Ủy quyền trở thành ASSIGNING khi xác nhận
- Trở thành ACTIVE sau `nForgingAssignmentDelay` khối
- Độ trễ ngăn tái ủy quyền nhanh trong fork chuỗi

**Mã Lỗi**:
- `RPC_WALLET_NOT_FOUND`: Không có ví khả dụng
- `RPC_WALLET_UNLOCK_NEEDED`: Ví được mã hóa và bị khóa
- `RPC_WALLET_ERROR`: Tạo giao dịch thất bại
- `RPC_INVALID_ADDRESS_OR_KEY`: Định dạng địa chỉ không hợp lệ

**Ví dụ**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Triển khai**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Danh mục**: wallet
**Yêu cầu Mining Server**: Không
**Yêu cầu Ví**: Có (phải được tải và mở khóa)

**Mục đích**: Thu hồi ủy quyền forging hiện có, trả quyền forging về chủ sở hữu plot.

**Tham số**:
1. `plot_address` (chuỗi, bắt buộc) - Địa chỉ plot (phải sở hữu khóa riêng, P2WPKH bech32)
2. `fee_rate` (số, tùy chọn) - Tỷ lệ phí theo BTC/kvB (mặc định: 10× minRelayFee)

**Giá trị Trả về**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Yêu cầu**:
- Ví được tải và mở khóa
- Khóa riêng cho plot_address trong ví
- Địa chỉ plot phải là P2WPKH (định dạng bech32)
- Địa chỉ plot phải có UTXO đã xác nhận

**Cấu trúc Giao dịch**:
- Input: UTXO từ địa chỉ plot (chứng minh quyền sở hữu)
- Output: OP_RETURN (26 byte): marker `XCOP` + plot_address (20 byte)
- Output: Tiền thừa trả về ví

**Hiệu quả**:
- Trạng thái chuyển sang REVOKING ngay lập tức
- Địa chỉ forging vẫn có thể forge trong khoảng độ trễ
- Trở thành REVOKED sau `nForgingRevocationDelay` khối
- Chủ sở hữu plot có thể forge sau khi thu hồi có hiệu lực
- Có thể tạo ủy quyền mới sau khi thu hồi hoàn tất

**Mã Lỗi**:
- `RPC_WALLET_NOT_FOUND`: Không có ví khả dụng
- `RPC_WALLET_UNLOCK_NEEDED`: Ví được mã hóa và bị khóa
- `RPC_WALLET_ERROR`: Tạo giao dịch thất bại

**Ví dụ**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Lưu ý**:
- Idempotent: có thể thu hồi ngay cả khi không có ủy quyền hoạt động
- Không thể hủy thu hồi một khi đã gửi

**Triển khai**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPC Blockchain Được sửa đổi

### getdifficulty

**Sửa đổi PoCX**:
- **Tính toán**: `reference_base_target / current_base_target`
- **Tham chiếu**: Dung lượng mạng 1 TiB (base_target = 36650387593)
- **Diễn giải**: Ước tính dung lượng lưu trữ mạng tính bằng TiB
  - Ví dụ: `1.0` = ~1 TiB
  - Ví dụ: `1024.0` = ~1 PiB
- **Khác biệt với PoW**: Đại diện cho dung lượng, không phải hash power

**Ví dụ**:
```bash
bitcoin-cli getdifficulty
# Trả về: 2048.5 (mạng ~2 PiB)
```

**Triển khai**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Trường PoCX Được thêm**:
- `time_since_last_block` (số) - Giây kể từ khối trước (thay thế mediantime)
- `poc_time` (số) - Thời gian forge time-bended tính bằng giây
- `base_target` (số) - Base target độ khó PoCX
- `generation_signature` (chuỗi hex) - Chữ ký sinh
- `pocx_proof` (đối tượng):
  - `account_id` (chuỗi hex) - ID tài khoản plot (20 byte)
  - `seed` (chuỗi hex) - Seed plot (32 byte)
  - `nonce` (số) - Mining nonce
  - `compression` (số) - Cấp độ mở rộng sử dụng
  - `quality` (số) - Giá trị chất lượng khai báo
- `pubkey` (chuỗi hex) - Khóa công khai người ký khối (33 byte)
- `signer_address` (chuỗi) - Địa chỉ người ký khối
- `signature` (chuỗi hex) - Chữ ký khối (65 byte)

**Trường PoCX Bị loại bỏ**:
- `mediantime` - Bị loại bỏ (thay thế bởi time_since_last_block)

**Ví dụ**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Triển khai**: `src/rpc/blockchain.cpp`

---

### getblock

**Sửa đổi PoCX**: Giống như getblockheader, cộng thêm dữ liệu giao dịch đầy đủ

**Ví dụ**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose với chi tiết tx
```

**Triển khai**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Trường PoCX Được thêm**:
- `base_target` (số) - Base target hiện tại
- `generation_signature` (chuỗi hex) - Chữ ký sinh hiện tại

**Trường PoCX Được sửa đổi**:
- `difficulty` - Sử dụng tính toán PoCX (dựa trên dung lượng)

**Trường PoCX Bị loại bỏ**:
- `mediantime` - Bị loại bỏ

**Ví dụ**:
```bash
bitcoin-cli getblockchaininfo
```

**Triển khai**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Trường PoCX Được thêm**:
- `generation_signature` (chuỗi hex) - Cho đào pool
- `base_target` (số) - Cho đào pool

**Trường PoCX Bị loại bỏ**:
- `target` - Bị loại bỏ (đặc thù PoW)
- `noncerange` - Bị loại bỏ (đặc thù PoW)
- `bits` - Bị loại bỏ (đặc thù PoW)

**Lưu ý**:
- Vẫn bao gồm dữ liệu giao dịch đầy đủ cho xây dựng khối
- Sử dụng bởi server pool cho đào phối hợp

**Ví dụ**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Triển khai**: `src/rpc/mining.cpp`

---

## RPC Bị vô hiệu hóa

Các RPC đặc thù PoW sau đây bị **vô hiệu hóa** trong chế độ PoCX:

### getnetworkhashps
- **Lý do**: Hash rate không áp dụng cho Proof of Capacity
- **Thay thế**: Sử dụng `getdifficulty` cho ước tính dung lượng mạng

### getmininginfo
- **Lý do**: Trả về thông tin đặc thù PoW
- **Thay thế**: Sử dụng `get_mining_info` (đặc thù PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Lý do**: Đào CPU không áp dụng cho PoCX (yêu cầu plot được tạo trước)
- **Thay thế**: Sử dụng plotter bên ngoài + miner + `submit_nonce`

**Triển khai**: `src/rpc/mining.cpp` (RPC trả về lỗi khi ENABLE_POCX được định nghĩa)

---

## Ví dụ Tích hợp

### Tích hợp Thợ đào Bên ngoài

**Vòng lặp Đào Cơ bản**:
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

# Vòng lặp đào
while True:
    # 1. Lấy tham số đào
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Quét tệp plot (triển khai bên ngoài)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Gửi lời giải tốt nhất
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Lời giải được chấp nhận! Chất lượng: {result['quality']}s, "
              f"Thời gian forge: {result['poc_time']}s")

    # 4. Chờ khối tiếp theo
    time.sleep(10)  # Khoảng poll
```

---

### Mẫu Tích hợp Pool

**Quy trình Server Pool**:
1. Thợ đào tạo ủy quyền forging cho địa chỉ pool
2. Pool chạy ví với khóa địa chỉ forging
3. Pool gọi `get_mining_info` và phân phối đến thợ đào
4. Thợ đào gửi lời giải qua pool (không trực tiếp đến chain)
5. Pool xác thực và gọi `submit_nonce` với khóa pool
6. Pool phân phối phần thưởng theo chính sách pool

**Quản lý Ủy quyền**:
```bash
# Thợ đào tạo ủy quyền (từ ví thợ đào)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Chờ kích hoạt (30 khối mainnet)

# Pool kiểm tra trạng thái ủy quyền
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool giờ có thể gửi nonce cho plot này
# (ví pool phải có khóa riêng pocx1qpool...)
```

---

### Truy vấn Block Explorer

**Truy vấn Dữ liệu Khối PoCX**:
```bash
# Lấy khối mới nhất
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Lấy chi tiết khối với bằng chứng PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Trích xuất các trường đặc thù PoCX
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

**Phát hiện Giao dịch Ủy quyền**:
```bash
# Quét giao dịch cho OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Kiểm tra marker ủy quyền (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Xử lý Lỗi

### Mẫu Lỗi Phổ biến

**Chiều cao Không khớp**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Giải pháp**: Lấy lại mining info, chuỗi đã tiến lên

**Chữ ký Sinh Không khớp**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Giải pháp**: Lấy lại mining info, khối mới đã đến

**Không có Khóa Riêng**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Giải pháp**: Import khóa cho địa chỉ plot hoặc forging

**Kích hoạt Ủy quyền Đang chờ**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Giải pháp**: Chờ độ trễ kích hoạt kết thúc

---

## Tham chiếu Mã

**Mining RPC**: `src/pocx/rpc/mining.cpp`
**Assignment RPC**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain RPC**: `src/rpc/blockchain.cpp`
**Xác thực Bằng chứng**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Trạng thái Ủy quyền**: `src/pocx/assignments/assignment_state.cpp`
**Tạo Giao dịch**: `src/pocx/assignments/transactions.cpp`

---

## Tham chiếu Chéo

Các chương liên quan:
- [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md) - Chi tiết quy trình đào
- [Chương 4: Ủy quyền Forging](4-forging-assignments.md) - Kiến trúc hệ thống ủy quyền
- [Chương 6: Tham số Mạng](6-network-parameters.md) - Giá trị độ trễ ủy quyền
- [Chương 8: Hướng dẫn Ví](8-wallet-guide.md) - GUI cho quản lý ủy quyền

---

[← Trước: Tham số Mạng](6-network-parameters.md) | [Mục lục](index.md) | [Tiếp: Hướng dẫn Ví →](8-wallet-guide.md)

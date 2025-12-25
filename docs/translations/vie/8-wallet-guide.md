[← Trước: Tham chiếu RPC](7-rpc-reference.md) | [Mục lục](index.md)

---

# Chương 8: Hướng dẫn Sử dụng Ví và GUI

Hướng dẫn đầy đủ cho ví Qt Bitcoin-PoCX và quản lý ủy quyền forging.

---

## Mục lục

1. [Tổng quan](#tổng-quan)
2. [Đơn vị Tiền tệ](#đơn-vị-tiền-tệ)
3. [Hộp thoại Ủy quyền Forging](#hộp-thoại-ủy-quyền-forging)
4. [Lịch sử Giao dịch](#lịch-sử-giao-dịch)
5. [Yêu cầu Địa chỉ](#yêu-cầu-địa-chỉ)
6. [Tích hợp Đào](#tích-hợp-đào)
7. [Khắc phục Sự cố](#khắc-phục-sự-cố)
8. [Thực hành Bảo mật Tốt nhất](#thực-hành-bảo-mật-tốt-nhất)

---

## Tổng quan

### Tính năng Ví Bitcoin-PoCX

Ví Qt Bitcoin-PoCX (`bitcoin-qt`) cung cấp:
- Chức năng ví Bitcoin Core tiêu chuẩn (gửi, nhận, quản lý giao dịch)
- **Quản lý Ủy quyền Forging**: GUI để tạo/thu hồi ủy quyền plot
- **Chế độ Mining Server**: Cờ `-miningserver` bật các tính năng liên quan đến đào
- **Lịch sử Giao dịch**: Hiển thị giao dịch ủy quyền và thu hồi

### Khởi động Ví

**Chỉ Node** (không đào):
```bash
./build/bin/bitcoin-qt
```

**Với Đào** (bật hộp thoại ủy quyền):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Thay thế Dòng lệnh**:
```bash
./build/bin/bitcoind -miningserver
```

### Yêu cầu Đào

**Cho Hoạt động Đào**:
- Cờ `-miningserver` bắt buộc
- Ví với địa chỉ P2WPKH và khóa riêng
- Plotter bên ngoài (`pocx_plotter`) để tạo plot
- Miner bên ngoài (`pocx_miner`) để đào

**Cho Đào Pool**:
- Tạo ủy quyền forging cho địa chỉ pool
- Không cần ví trên server pool (pool quản lý khóa)

---

## Đơn vị Tiền tệ

### Hiển thị Đơn vị

Bitcoin-PoCX sử dụng đơn vị tiền tệ **BTCX** (không phải BTC):

| Đơn vị | Satoshi | Hiển thị |
|--------|---------|----------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Cài đặt GUI**: Preferences → Display → Unit

---

## Hộp thoại Ủy quyền Forging

### Truy cập Hộp thoại

**Menu**: `Wallet → Forging Assignments`
**Thanh công cụ**: Biểu tượng đào (chỉ hiển thị với cờ `-miningserver`)
**Kích thước Cửa sổ**: 600×450 pixel

### Các Chế độ Hộp thoại

#### Chế độ 1: Tạo Ủy quyền

**Mục đích**: Ủy thác quyền forging cho pool hoặc địa chỉ khác trong khi vẫn giữ quyền sở hữu plot.

**Các Trường hợp Sử dụng**:
- Đào pool (ủy quyền cho địa chỉ pool)
- Cold storage (khóa đào tách biệt với quyền sở hữu plot)
- Cơ sở hạ tầng chia sẻ (ủy thác cho hot wallet)

**Yêu cầu**:
- Địa chỉ plot (P2WPKH bech32, phải sở hữu khóa riêng)
- Địa chỉ forging (P2WPKH bech32, khác với địa chỉ plot)
- Ví được mở khóa (nếu được mã hóa)
- Địa chỉ plot có UTXO đã xác nhận

**Các Bước**:
1. Chọn chế độ "Create Assignment"
2. Chọn địa chỉ plot từ dropdown hoặc nhập thủ công
3. Nhập địa chỉ forging (pool hoặc người được ủy thác)
4. Nhấp "Send Assignment" (nút được bật khi input hợp lệ)
5. Giao dịch phát sóng ngay lập tức
6. Ủy quyền hoạt động sau `nForgingAssignmentDelay` khối:
   - Mainnet/Testnet: 30 khối (~1 giờ)
   - Regtest: 4 khối (~4 giây)

**Phí Giao dịch**: Mặc định 10× `minRelayFee` (có thể tùy chỉnh)

**Cấu trúc Giao dịch**:
- Input: UTXO từ địa chỉ plot (chứng minh quyền sở hữu)
- Output OP_RETURN: marker `POCX` + plot_address + forging_address (46 byte)
- Output tiền thừa: Trả về ví

#### Chế độ 2: Thu hồi Ủy quyền

**Mục đích**: Hủy ủy quyền forging và trả quyền về chủ sở hữu plot.

**Yêu cầu**:
- Địa chỉ plot (phải sở hữu khóa riêng)
- Ví được mở khóa (nếu được mã hóa)
- Địa chỉ plot có UTXO đã xác nhận

**Các Bước**:
1. Chọn chế độ "Revoke Assignment"
2. Chọn địa chỉ plot
3. Nhấp "Send Revocation"
4. Giao dịch phát sóng ngay lập tức
5. Thu hồi có hiệu lực sau `nForgingRevocationDelay` khối:
   - Mainnet/Testnet: 720 khối (~24 giờ)
   - Regtest: 8 khối (~8 giây)

**Hiệu quả**:
- Địa chỉ forging vẫn có thể forge trong khoảng độ trễ
- Chủ sở hữu plot lấy lại quyền sau khi thu hồi hoàn tất
- Có thể tạo ủy quyền mới sau đó

**Cấu trúc Giao dịch**:
- Input: UTXO từ địa chỉ plot (chứng minh quyền sở hữu)
- Output OP_RETURN: marker `XCOP` + plot_address (26 byte)
- Output tiền thừa: Trả về ví

#### Chế độ 3: Kiểm tra Trạng thái Ủy quyền

**Mục đích**: Truy vấn trạng thái ủy quyền hiện tại cho bất kỳ địa chỉ plot nào.

**Yêu cầu**: Không (chỉ đọc, không cần ví)

**Các Bước**:
1. Chọn chế độ "Check Assignment Status"
2. Nhập địa chỉ plot
3. Nhấp "Check Status"
4. Hộp trạng thái hiển thị trạng thái hiện tại với chi tiết

**Chỉ báo Trạng thái** (mã màu):

**Xám - UNASSIGNED**
```
UNASSIGNED - Không có ủy quyền
```

**Cam - ASSIGNING**
```
ASSIGNING - Ủy quyền đang chờ kích hoạt
Forging Address: pocx1qforger...
Created at height: 12000
Activates at height: 12030 (còn 5 khối)
```

**Xanh lá - ASSIGNED**
```
ASSIGNED - Ủy quyền hoạt động
Forging Address: pocx1qforger...
Created at height: 12000
Activated at height: 12030
```

**Đỏ-Cam - REVOKING**
```
REVOKING - Thu hồi đang chờ
Forging Address: pocx1qforger... (vẫn hoạt động)
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020 (còn 50 khối)
```

**Đỏ - REVOKED**
```
REVOKED - Ủy quyền đã thu hồi
Previously assigned to: pocx1qforger...
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020
```

---

## Lịch sử Giao dịch

### Hiển thị Giao dịch Ủy quyền

**Loại**: "Assignment"
**Biểu tượng**: Biểu tượng đào (giống như khối đã đào)

**Cột Địa chỉ**: Địa chỉ plot (địa chỉ mà quyền forging đang được ủy quyền)
**Cột Số lượng**: Phí giao dịch (âm, giao dịch đi)
**Cột Trạng thái**: Số xác nhận (0-6+)

**Chi tiết** (khi nhấp):
- ID Giao dịch
- Địa chỉ plot
- Địa chỉ forging (phân tích từ OP_RETURN)
- Tạo tại chiều cao
- Chiều cao kích hoạt
- Phí giao dịch
- Timestamp

### Hiển thị Giao dịch Thu hồi

**Loại**: "Revocation"
**Biểu tượng**: Biểu tượng đào

**Cột Địa chỉ**: Địa chỉ plot
**Cột Số lượng**: Phí giao dịch (âm)
**Cột Trạng thái**: Số xác nhận

**Chi tiết** (khi nhấp):
- ID Giao dịch
- Địa chỉ plot
- Thu hồi tại chiều cao
- Chiều cao thu hồi có hiệu lực
- Phí giao dịch
- Timestamp

### Lọc Giao dịch

**Bộ lọc Có sẵn**:
- "All" (mặc định, bao gồm ủy quyền/thu hồi)
- Phạm vi ngày
- Phạm vi số lượng
- Tìm theo địa chỉ
- Tìm theo ID giao dịch
- Tìm theo nhãn (nếu địa chỉ có nhãn)

**Lưu ý**: Giao dịch Ủy quyền/Thu hồi hiện xuất hiện dưới bộ lọc "All". Bộ lọc loại chuyên dụng chưa được triển khai.

### Sắp xếp Giao dịch

**Thứ tự Sắp xếp** (theo loại):
- Generated (loại 0)
- Received (loại 1-3)
- Assignment (loại 4)
- Revocation (loại 5)
- Sent (loại 6+)

---

## Yêu cầu Địa chỉ

### Chỉ P2WPKH (SegWit v0)

**Hoạt động forging yêu cầu**:
- Địa chỉ mã hóa Bech32 (bắt đầu với "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Định dạng P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Key hash 20-byte

**KHÔNG Hỗ trợ**:
- P2PKH (legacy, bắt đầu với "1")
- P2SH (wrapped SegWit, bắt đầu với "3")
- P2TR (Taproot, bắt đầu với "bc1p")

**Lý do**: Chữ ký khối PoCX yêu cầu định dạng witness v0 cụ thể cho xác thực bằng chứng.

### Lọc Dropdown Địa chỉ

**ComboBox Địa chỉ Plot**:
- Tự động điền với địa chỉ nhận của ví
- Lọc bỏ địa chỉ không phải P2WPKH
- Hiển thị định dạng: "Nhãn (địa chỉ)" nếu có nhãn, ngược lại chỉ địa chỉ
- Mục đầu tiên: "-- Enter custom address --" để nhập thủ công

**Nhập Thủ công**:
- Xác thực định dạng khi nhập
- Phải là bech32 P2WPKH hợp lệ
- Nút bị tắt nếu định dạng không hợp lệ

### Thông báo Lỗi Xác thực

**Lỗi Hộp thoại**:
- "Plot address must be P2WPKH (bech32)"
- "Forging address must be P2WPKH (bech32)"
- "Invalid address format"
- "No coins available at the plot address. Cannot prove ownership."
- "Cannot create transactions with watch-only wallet"
- "Wallet not available"
- "Wallet locked" (từ RPC)

---

## Tích hợp Đào

### Yêu cầu Thiết lập

**Cấu hình Node**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Yêu cầu Ví**:
- Địa chỉ P2WPKH cho quyền sở hữu plot
- Khóa riêng cho đào (hoặc địa chỉ forging nếu sử dụng ủy quyền)
- UTXO đã xác nhận để tạo giao dịch

**Công cụ Bên ngoài**:
- `pocx_plotter`: Tạo tệp plot
- `pocx_miner`: Quét plot và gửi nonce

### Quy trình

#### Đào Solo

1. **Tạo Tệp Plot**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **Khởi động Node** với mining server:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Cấu hình Miner**:
   - Trỏ đến endpoint RPC node
   - Chỉ định thư mục tệp plot
   - Cấu hình account ID (từ địa chỉ plot)

4. **Bắt đầu Đào**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **Giám sát**:
   - Miner gọi `get_mining_info` mỗi khối
   - Quét plot để tìm deadline tốt nhất
   - Gọi `submit_nonce` khi tìm thấy lời giải
   - Node xác thực và forge khối tự động

#### Đào Pool

1. **Tạo Tệp Plot** (giống đào solo)

2. **Tạo Ủy quyền Forging**:
   - Mở Hộp thoại Ủy quyền Forging
   - Chọn địa chỉ plot
   - Nhập địa chỉ forging của pool
   - Nhấp "Send Assignment"
   - Chờ độ trễ kích hoạt (30 khối testnet)

3. **Cấu hình Miner**:
   - Trỏ đến endpoint **pool** (không phải node cục bộ)
   - Pool xử lý `submit_nonce` đến chain

4. **Hoạt động Pool**:
   - Ví pool có khóa riêng địa chỉ forging
   - Pool xác thực submission từ thợ đào
   - Pool gọi `submit_nonce` đến blockchain
   - Pool phân phối phần thưởng theo chính sách pool

### Phần thưởng Coinbase

**Không có Ủy quyền**:
- Coinbase trả trực tiếp địa chỉ chủ sở hữu plot
- Kiểm tra số dư trong địa chỉ plot

**Có Ủy quyền**:
- Coinbase trả địa chỉ forging
- Pool nhận phần thưởng
- Thợ đào nhận phần từ pool

**Lịch trình Phần thưởng**:
- Ban đầu: 10 BTCX mỗi khối
- Halving: Mỗi 1050000 khối (~4 năm)
- Lịch trình: 10 → 5 → 2.5 → 1.25 → ...

---

## Khắc phục Sự cố

### Vấn đề Phổ biến

#### "Wallet does not have private key for plot address"

**Nguyên nhân**: Ví không sở hữu địa chỉ
**Giải pháp**:
- Import khóa riêng qua RPC `importprivkey`
- Hoặc sử dụng địa chỉ plot khác thuộc sở hữu ví

#### "Assignment already exists for this plot"

**Nguyên nhân**: Plot đã được ủy quyền cho địa chỉ khác
**Giải pháp**:
1. Thu hồi ủy quyền hiện tại
2. Chờ độ trễ thu hồi (720 khối testnet)
3. Tạo ủy quyền mới

#### "Address format not supported"

**Nguyên nhân**: Địa chỉ không phải P2WPKH bech32
**Giải pháp**:
- Sử dụng địa chỉ bắt đầu với "pocx1q" (mainnet) hoặc "tpocx1q" (testnet)
- Tạo địa chỉ mới nếu cần: `getnewaddress "" "bech32"`

#### "Transaction fee too low"

**Nguyên nhân**: Mempool mạng bị tắc nghẽn hoặc phí quá thấp để relay
**Giải pháp**:
- Tăng tham số tỷ lệ phí
- Chờ mempool giảm tải

#### "Assignment not yet active"

**Nguyên nhân**: Độ trễ kích hoạt chưa kết thúc
**Giải pháp**:
- Kiểm tra trạng thái: số khối còn lại đến kích hoạt
- Chờ khoảng độ trễ hoàn tất

#### "No coins available at the plot address"

**Nguyên nhân**: Địa chỉ plot không có UTXO đã xác nhận
**Giải pháp**:
1. Gửi tiền đến địa chỉ plot
2. Chờ 1 xác nhận
3. Thử lại tạo ủy quyền

#### "Cannot create transactions with watch-only wallet"

**Nguyên nhân**: Ví import địa chỉ không có khóa riêng
**Giải pháp**: Import khóa riêng đầy đủ, không chỉ địa chỉ

#### "Forging Assignment tab not visible"

**Nguyên nhân**: Node khởi động không có cờ `-miningserver`
**Giải pháp**: Khởi động lại với `bitcoin-qt -server -miningserver`

### Các Bước Debug

1. **Kiểm tra Trạng thái Ví**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Xác minh Quyền sở hữu Địa chỉ**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Kiểm tra: "iswatchonly": false, "ismine": true
   ```

3. **Kiểm tra Trạng thái Ủy quyền**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Xem Giao dịch Gần đây**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Kiểm tra Đồng bộ Node**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Xác minh: blocks == headers (đã đồng bộ đầy đủ)
   ```

---

## Thực hành Bảo mật Tốt nhất

### Bảo mật Địa chỉ Plot

**Quản lý Khóa**:
- Lưu trữ khóa riêng địa chỉ plot an toàn
- Giao dịch ủy quyền chứng minh quyền sở hữu qua chữ ký
- Chỉ chủ sở hữu plot có thể tạo/thu hồi ủy quyền

**Sao lưu**:
- Sao lưu ví thường xuyên (`dumpwallet` hoặc `backupwallet`)
- Lưu wallet.dat ở vị trí an toàn
- Ghi lại cụm từ khôi phục nếu sử dụng ví HD

### Ủy thác Địa chỉ Forging

**Mô hình Bảo mật**:
- Địa chỉ forging nhận phần thưởng khối
- Địa chỉ forging có thể ký khối (đào)
- Địa chỉ forging **không thể** sửa đổi hoặc thu hồi ủy quyền
- Chủ sở hữu plot giữ toàn quyền kiểm soát

**Các Trường hợp Sử dụng**:
- **Ủy thác Hot Wallet**: Khóa plot trong cold storage, khóa forging trong hot wallet để đào
- **Đào Pool**: Ủy thác cho pool, giữ quyền sở hữu plot
- **Cơ sở hạ tầng Chia sẻ**: Nhiều thợ đào, một địa chỉ forging

### Đồng bộ Thời gian Mạng

**Tầm quan trọng**:
- Đồng thuận PoCX yêu cầu thời gian chính xác
- Lệch đồng hồ >10 giây kích hoạt cảnh báo
- Lệch đồng hồ >15 giây ngăn đào

**Giải pháp**:
- Giữ đồng hồ hệ thống đồng bộ với NTP
- Giám sát: `bitcoin-cli getnetworkinfo` cho cảnh báo độ lệch thời gian
- Sử dụng server NTP đáng tin cậy

### Độ trễ Ủy quyền

**Độ trễ Kích hoạt** (30 khối testnet):
- Ngăn tái ủy quyền nhanh trong fork chuỗi
- Cho phép mạng đạt đồng thuận
- Không thể bỏ qua

**Độ trễ Thu hồi** (720 khối testnet):
- Cung cấp ổn định cho pool đào
- Ngăn tấn công "griefing" ủy quyền
- Địa chỉ forging vẫn hoạt động trong độ trễ

### Mã hóa Ví

**Bật Mã hóa**:
```bash
bitcoin-cli encryptwallet "your_passphrase"
```

**Mở khóa cho Giao dịch**:
```bash
bitcoin-cli walletpassphrase "your_passphrase" 300
```

**Thực hành Tốt nhất**:
- Sử dụng passphrase mạnh (20+ ký tự)
- Không lưu passphrase dưới dạng text thuần
- Khóa ví sau khi tạo ủy quyền

---

## Tham chiếu Mã

**Hộp thoại Ủy quyền Forging**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Hiển thị Giao dịch**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Phân tích Giao dịch**: `src/qt/transactionrecord.cpp`
**Tích hợp Ví**: `src/pocx/assignments/transactions.cpp`
**RPC Ủy quyền**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Main**: `src/qt/bitcoingui.cpp`

---

## Tham chiếu Chéo

Các chương liên quan:
- [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md) - Quy trình đào
- [Chương 4: Ủy quyền Forging](4-forging-assignments.md) - Kiến trúc ủy quyền
- [Chương 6: Tham số Mạng](6-network-parameters.md) - Giá trị độ trễ ủy quyền
- [Chương 7: Tham chiếu RPC](7-rpc-reference.md) - Chi tiết lệnh RPC

---

[← Trước: Tham chiếu RPC](7-rpc-reference.md) | [Mục lục](index.md)

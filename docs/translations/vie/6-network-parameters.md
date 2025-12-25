[← Trước: Đồng bộ Thời gian](5-timing-security.md) | [Mục lục](index.md) | [Tiếp: Tham chiếu RPC →](7-rpc-reference.md)

---

# Chương 6: Tham số Mạng và Cấu hình

Tham chiếu đầy đủ cho cấu hình mạng Bitcoin-PoCX trên tất cả các loại mạng.

---

## Mục lục

1. [Tham số Khối Genesis](#tham-số-khối-genesis)
2. [Cấu hình Chainparams](#cấu-hình-chainparams)
3. [Tham số Đồng thuận](#tham-số-đồng-thuận)
4. [Coinbase và Phần thưởng Khối](#coinbase-và-phần-thưởng-khối)
5. [Mở rộng Động](#mở-rộng-động)
6. [Cấu hình Mạng](#cấu-hình-mạng)
7. [Cấu trúc Thư mục Dữ liệu](#cấu-trúc-thư-mục-dữ-liệu)

---

## Tham số Khối Genesis

### Tính toán Base Target

**Công thức**: `genesis_base_target = 2^42 / block_time_seconds`

**Lý do**:
- Mỗi nonce đại diện cho 256 KiB (64 byte × 4096 scoop)
- 1 TiB = 2^22 nonce (giả định dung lượng mạng ban đầu)
- Chất lượng tối thiểu kỳ vọng cho n nonce khoảng 2^64 / n
- Với 1 TiB: E(chất lượng) = 2^64 / 2^22 = 2^42
- Do đó: base_target = 2^42 / block_time

**Giá trị Được tính**:
- Mainnet/Testnet/Signet (120 giây): `36650387592`
- Regtest (1 giây): Sử dụng chế độ hiệu chuẩn dung lượng thấp

### Thông điệp Genesis

Tất cả mạng chia sẻ thông điệp genesis Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Triển khai**: `src/kernel/chainparams.cpp`

---

## Cấu hình Chainparams

### Tham số Mainnet

**Danh tính Mạng**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Cổng Mặc định**: `8888`
- **Bech32 HRP**: `pocx`

**Tiền tố Địa chỉ** (Base58):
- PUBKEY_ADDRESS: `85` (địa chỉ bắt đầu với 'P')
- SCRIPT_ADDRESS: `90` (địa chỉ bắt đầu với 'R')
- SECRET_KEY: `128`

**Timing Khối**:
- **Mục tiêu Thời gian Khối**: `120` giây (2 phút)
- **Target Timespan**: `1209600` giây (14 ngày)
- **MAX_FUTURE_BLOCK_TIME**: `15` giây

**Phần thưởng Khối**:
- **Trợ cấp Ban đầu**: `10 BTC`
- **Khoảng Halving**: `1050000` khối (~4 năm)
- **Số Halving**: Tối đa 64 halving

**Điều chỉnh Độ khó**:
- **Cửa sổ Cuộn**: `24` khối
- **Điều chỉnh**: Mỗi khối
- **Thuật toán**: Trung bình động mũ

**Độ trễ Ủy quyền**:
- **Kích hoạt**: `30` khối (~1 giờ)
- **Thu hồi**: `720` khối (~24 giờ)

### Tham số Testnet

**Danh tính Mạng**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Cổng Mặc định**: `18888`
- **Bech32 HRP**: `tpocx`

**Tiền tố Địa chỉ** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Timing Khối**:
- **Mục tiêu Thời gian Khối**: `120` giây
- **MAX_FUTURE_BLOCK_TIME**: `15` giây
- **Cho phép Độ khó Tối thiểu**: `true`

**Phần thưởng Khối**:
- **Trợ cấp Ban đầu**: `10 BTC`
- **Khoảng Halving**: `1050000` khối

**Điều chỉnh Độ khó**:
- **Cửa sổ Cuộn**: `24` khối

**Độ trễ Ủy quyền**:
- **Kích hoạt**: `30` khối (~1 giờ)
- **Thu hồi**: `720` khối (~24 giờ)

### Tham số Regtest

**Danh tính Mạng**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Cổng Mặc định**: `18444`
- **Bech32 HRP**: `rpocx`

**Tiền tố Địa chỉ** (Tương thích Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Timing Khối**:
- **Mục tiêu Thời gian Khối**: `1` giây (đào tức thì để test)
- **Target Timespan**: `86400` giây (1 ngày)
- **MAX_FUTURE_BLOCK_TIME**: `15` giây

**Phần thưởng Khối**:
- **Trợ cấp Ban đầu**: `10 BTC`
- **Khoảng Halving**: `500` khối

**Điều chỉnh Độ khó**:
- **Cửa sổ Cuộn**: `24` khối
- **Cho phép Độ khó Tối thiểu**: `true`
- **Không Retargeting**: `true`
- **Hiệu chuẩn Dung lượng Thấp**: `true` (sử dụng hiệu chuẩn 16-nonce thay vì 1 TiB)

**Độ trễ Ủy quyền**:
- **Kích hoạt**: `4` khối (~4 giây)
- **Thu hồi**: `8` khối (~8 giây)

### Tham số Signet

**Danh tính Mạng**:
- **Magic Bytes**: 4 byte đầu của SHA256d(signet_challenge)
- **Cổng Mặc định**: `38333`
- **Bech32 HRP**: `tpocx`

**Timing Khối**:
- **Mục tiêu Thời gian Khối**: `120` giây
- **MAX_FUTURE_BLOCK_TIME**: `15` giây

**Phần thưởng Khối**:
- **Trợ cấp Ban đầu**: `10 BTC`
- **Khoảng Halving**: `1050000` khối

**Điều chỉnh Độ khó**:
- **Cửa sổ Cuộn**: `24` khối

---

## Tham số Đồng thuận

### Tham số Timing

**MAX_FUTURE_BLOCK_TIME**: `15` giây
- Đặc thù PoCX (Bitcoin sử dụng 2 giờ)
- Lý do: Timing PoC yêu cầu xác thực gần thời gian thực
- Khối hơn 15 giây trong tương lai bị từ chối

**Cảnh báo Độ lệch Thời gian**: `10` giây
- Người vận hành được cảnh báo khi đồng hồ node lệch >10 giây so với thời gian mạng
- Không có enforcement, chỉ thông tin

**Mục tiêu Thời gian Khối**:
- Mainnet/Testnet/Signet: `120` giây
- Regtest: `1` giây

**TIMESTAMP_WINDOW**: `15` giây (bằng MAX_FUTURE_BLOCK_TIME)

**Triển khai**: `src/chain.h`, `src/validation.cpp`

### Tham số Điều chỉnh Độ khó

**Kích thước Cửa sổ Cuộn**: `24` khối (tất cả mạng)
- Trung bình động mũ của các thời gian khối gần đây
- Điều chỉnh mỗi khối
- Phản hồi với thay đổi dung lượng

**Triển khai**: `src/consensus/params.h`, logic độ khó trong tạo khối

### Tham số Hệ thống Ủy quyền

**nForgingAssignmentDelay** (độ trễ kích hoạt):
- Mainnet: `30` khối (~1 giờ)
- Testnet: `30` khối (~1 giờ)
- Regtest: `4` khối (~4 giây)

**nForgingRevocationDelay** (độ trễ thu hồi):
- Mainnet: `720` khối (~24 giờ)
- Testnet: `720` khối (~24 giờ)
- Regtest: `8` khối (~8 giây)

**Lý do**:
- Độ trễ kích hoạt ngăn tái ủy quyền nhanh trong các cuộc đua khối
- Độ trễ thu hồi cung cấp ổn định và ngăn lạm dụng

**Triển khai**: `src/consensus/params.h`

---

## Coinbase và Phần thưởng Khối

### Lịch trình Trợ cấp Khối

**Trợ cấp Ban đầu**: `10 BTC` (tất cả mạng)

**Lịch trình Halving**:
- Mỗi `1050000` khối (mainnet/testnet)
- Mỗi `500` khối (regtest)
- Tiếp tục tối đa 64 halving

**Tiến trình Halving**:
```
Halving 0: 10.00000000 BTC  (khối 0 - 1049999)
Halving 1:  5.00000000 BTC  (khối 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (khối 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (khối 3150000 - 4199999)
...
```

**Tổng Cung**: ~21 triệu BTC (giống Bitcoin)

### Quy tắc Đầu ra Coinbase

**Đích Thanh toán**:
- **Không có Ủy quyền**: Coinbase trả địa chỉ plot (proof.account_id)
- **Có Ủy quyền**: Coinbase trả địa chỉ forging (người ký hiệu quả)

**Định dạng Đầu ra**: Chỉ P2WPKH
- Coinbase phải trả đến địa chỉ bech32 SegWit v0
- Được tạo từ khóa công khai của người ký hiệu quả

**Giải quyết Ủy quyền**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Triển khai**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Mở rộng Động

### Giới hạn Mở rộng

**Mục đích**: Tăng độ khó tạo plot khi mạng trưởng thành để ngăn lạm phát dung lượng

**Cấu trúc**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Cấp độ tối thiểu được chấp nhận
    uint8_t nPoCXTargetCompression;  // Cấp độ khuyến nghị
};
```

**Mối quan hệ**: `target = min + 1` (luôn một cấp trên tối thiểu)

### Lịch trình Tăng Mở rộng

Các cấp độ mở rộng tăng theo **lịch trình mũ** dựa trên khoảng halving:

| Khoảng Thời gian | Chiều cao Khối | Halving | Min | Target |
|------------------|----------------|---------|-----|--------|
| Năm 0-4 | 0 đến 1049999 | 0 | X1 | X2 |
| Năm 4-12 | 1050000 đến 3149999 | 1-2 | X2 | X3 |
| Năm 12-28 | 3150000 đến 7349999 | 3-6 | X3 | X4 |
| Năm 28-60 | 7350000 đến 15749999 | 7-14 | X4 | X5 |
| Năm 60-124 | 15750000 đến 32549999 | 15-30 | X5 | X6 |
| Năm 124+ | 32550000+ | 31+ | X6 | X7 |

**Chiều cao Quan trọng** (năm → halving → khối):
- Năm 4: Halving 1 tại khối 1050000
- Năm 12: Halving 3 tại khối 3150000
- Năm 28: Halving 7 tại khối 7350000
- Năm 60: Halving 15 tại khối 15750000
- Năm 124: Halving 31 tại khối 32550000

### Độ khó Cấp độ Mở rộng

**Mở rộng PoW**:
- Cấp độ mở rộng X0: POC2 baseline (lý thuyết)
- Cấp độ mở rộng X1: XOR-transpose baseline
- Cấp độ mở rộng Xn: 2^(n-1) × X1 work được nhúng
- Mỗi cấp độ tăng gấp đôi công việc tạo plot

**Căn chỉnh Kinh tế**:
- Phần thưởng khối halving → độ khó tạo plot tăng
- Duy trì biên độ an toàn: chi phí tạo plot > chi phí tra cứu
- Ngăn lạm phát dung lượng từ cải thiện phần cứng

### Xác thực Plot

**Quy tắc Xác thực**:
- Bằng chứng gửi phải có cấp độ mở rộng >= tối thiểu
- Bằng chứng với mở rộng > target được chấp nhận nhưng không hiệu quả
- Bằng chứng dưới tối thiểu: bị từ chối (PoW không đủ)

**Lấy Giới hạn**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Triển khai**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Cấu hình Mạng

### Seed Node và DNS Seed

**Trạng thái**: Placeholder cho mainnet launch

**Cấu hình Dự kiến**:
- Seed node: Chưa xác định
- DNS seed: Chưa xác định

**Trạng thái Hiện tại** (testnet/regtest):
- Không có cơ sở hạ tầng seed chuyên dụng
- Hỗ trợ kết nối peer thủ công qua `-addnode`

**Triển khai**: `src/kernel/chainparams.cpp`

### Checkpoint

**Genesis Checkpoint**: Luôn là khối 0

**Checkpoint Bổ sung**: Chưa được cấu hình

**Tương lai**: Checkpoint sẽ được thêm khi mainnet tiến triển

---

## Cấu hình Giao thức P2P

### Phiên bản Giao thức

**Cơ sở**: Giao thức Bitcoin Core v30.0
- **Phiên bản Giao thức**: Kế thừa từ Bitcoin Core
- **Bit Dịch vụ**: Dịch vụ Bitcoin tiêu chuẩn
- **Loại Thông điệp**: Thông điệp P2P Bitcoin tiêu chuẩn

**Mở rộng PoCX**:
- Header khối bao gồm các trường đặc thù PoCX
- Thông điệp khối bao gồm dữ liệu bằng chứng PoCX
- Quy tắc xác thực thực thi đồng thuận PoCX

**Tương thích**: Node PoCX không tương thích với node Bitcoin PoW (đồng thuận khác)

**Triển khai**: `src/protocol.h`, `src/net_processing.cpp`

---

## Cấu trúc Thư mục Dữ liệu

### Thư mục Mặc định

**Vị trí**: `.bitcoin/` (giống Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Nội dung Thư mục

```
.bitcoin/
├── blocks/              # Dữ liệu khối
│   ├── blk*.dat        # Tệp khối
│   ├── rev*.dat        # Dữ liệu undo
│   └── index/          # Index khối (LevelDB)
├── chainstate/         # Tập UTXO + ủy quyền forging (LevelDB)
├── wallets/            # Tệp ví
│   └── wallet.dat      # Ví mặc định
├── bitcoin.conf        # Tệp cấu hình
├── debug.log           # Log debug
├── peers.dat           # Địa chỉ peer
├── mempool.dat         # Lưu mempool
└── banlist.dat         # Peer bị cấm
```

### Khác biệt Chính với Bitcoin

**Cơ sở Dữ liệu Chainstate**:
- Tiêu chuẩn: Tập UTXO
- **Bổ sung PoCX**: Trạng thái ủy quyền forging
- Cập nhật nguyên tử: UTXO + ủy quyền được cập nhật cùng nhau
- Dữ liệu undo an toàn reorg cho ủy quyền

**Tệp Khối**:
- Định dạng khối Bitcoin tiêu chuẩn
- **Bổ sung PoCX**: Mở rộng với các trường bằng chứng PoCX (account_id, seed, nonce, signature, pubkey)

### Ví dụ Tệp Cấu hình

**bitcoin.conf**:
```ini
# Chọn mạng
#testnet=1
#regtest=1

# Server đào PoCX (yêu cầu cho thợ đào bên ngoài)
miningserver=1

# Cài đặt RPC
server=1
rpcuser=yourusername
rpcpassword=yourpassword
rpcallowip=127.0.0.1
rpcport=8332

# Cài đặt kết nối
listen=1
port=8888
maxconnections=125

# Mục tiêu thời gian khối (thông tin, thực thi bởi đồng thuận)
# 120 giây cho mainnet/testnet
```

---

## Tham chiếu Mã

**Chainparams**: `src/kernel/chainparams.cpp`
**Tham số Đồng thuận**: `src/consensus/params.h`
**Giới hạn Nén**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Tính toán Base Target Genesis**: `src/pocx/consensus/params.cpp`
**Logic Thanh toán Coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Lưu trữ Trạng thái Ủy quyền**: `src/coins.h`, `src/coins.cpp` (mở rộng CCoinsViewCache)

---

## Tham chiếu Chéo

Các chương liên quan:
- [Chương 2: Định dạng Plot](2-plot-format.md) - Các cấp độ mở rộng trong tạo plot
- [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md) - Xác thực mở rộng, hệ thống ủy quyền
- [Chương 4: Ủy quyền Forging](4-forging-assignments.md) - Tham số độ trễ ủy quyền
- [Chương 5: Bảo mật Timing](5-timing-security.md) - Lý do MAX_FUTURE_BLOCK_TIME

---

[← Trước: Đồng bộ Thời gian](5-timing-security.md) | [Mục lục](index.md) | [Tiếp: Tham chiếu RPC →](7-rpc-reference.md)

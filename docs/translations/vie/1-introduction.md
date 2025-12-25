[Mục lục](index.md) | [Tiếp: Định dạng Plot →](2-plot-format.md)

---

# Chương 1: Giới thiệu và Tổng quan

## Bitcoin-PoCX là gì?

Bitcoin-PoCX là một bản tích hợp Bitcoin Core bổ sung hỗ trợ cơ chế đồng thuận **Proof of Capacity thế hệ mới (PoCX)**. Nó duy trì kiến trúc hiện có của Bitcoin Core đồng thời cho phép một giải pháp thay thế đào tiết kiệm năng lượng sử dụng Proof of Capacity như sự thay thế hoàn toàn cho Proof of Work.

**Điểm khác biệt Quan trọng**: Đây là một **chuỗi mới** không có khả năng tương thích ngược với Bitcoin PoW. Các khối PoCX được thiết kế không tương thích với các node PoW.

---

## Danh tính Dự án

- **Tổ chức**: Proof of Capacity Consortium
- **Tên Dự án**: Bitcoin-PoCX
- **Tên Đầy đủ**: Bitcoin Core với Tích hợp PoCX
- **Trạng thái**: Giai đoạn Testnet

---

## Proof of Capacity là gì?

Proof of Capacity (PoC) là một cơ chế đồng thuận trong đó năng lực đào tỷ lệ với **dung lượng ổ đĩa** thay vì năng lực tính toán. Thợ đào tạo trước các tệp plot lớn chứa các hash mật mã, sau đó sử dụng các plot này để tìm lời giải khối hợp lệ.

**Hiệu quả Năng lượng**: Các tệp plot được tạo một lần và tái sử dụng vô thời hạn. Đào tiêu thụ rất ít năng lượng CPU - chủ yếu là I/O ổ đĩa.

**Các cải tiến PoCX**:
- Sửa lỗi tấn công nén XOR-transpose (đánh đổi thời gian-bộ nhớ 50% trong POC2)
- Bố cục căn chỉnh 16-nonce cho phần cứng hiện đại
- Proof-of-work có thể mở rộng trong tạo plot (các cấp độ mở rộng Xn)
- Tích hợp C++ native trực tiếp vào Bitcoin Core
- Thuật toán Time Bending để cải thiện phân phối thời gian khối

---

## Tổng quan Kiến trúc

### Cấu trúc Repository

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + Tích hợp PoCX
│   └── src/pocx/        # Triển khai PoCX
├── pocx/                # PoCX core framework (submodule, chỉ đọc)
└── docs/                # Tài liệu này
```

### Triết lý Tích hợp

**Bề mặt Tích hợp Tối thiểu**: Các thay đổi được cô lập trong thư mục `/src/pocx/` với các hook sạch vào các lớp xác thực, đào và RPC của Bitcoin Core.

**Đánh dấu Tính năng**: Tất cả các sửa đổi nằm dưới các guard tiền xử lý `#ifdef ENABLE_POCX`. Bitcoin Core biên dịch bình thường khi bị tắt.

**Tương thích Upstream**: Đồng bộ thường xuyên với các bản cập nhật Bitcoin Core được duy trì thông qua các điểm tích hợp cô lập.

**Triển khai C++ Native**: Các thuật toán mật mã vô hướng (Shabal256, tính toán scoop, nén) được tích hợp trực tiếp vào Bitcoin Core để xác thực đồng thuận.

---

## Các Tính năng Chính

### 1. Thay thế Đồng thuận Hoàn toàn

- **Cấu trúc Khối**: Các trường đặc thù PoCX thay thế nonce PoW và bit độ khó
  - Chữ ký sinh (entropy đào xác định)
  - Mục tiêu cơ sở (nghịch đảo của độ khó)
  - Bằng chứng PoCX (ID tài khoản, seed, nonce)
  - Chữ ký khối (chứng minh quyền sở hữu plot)

- **Xác thực**: Pipeline xác thực 5 giai đoạn từ kiểm tra header đến kết nối khối

- **Điều chỉnh Độ khó**: Điều chỉnh mỗi khối sử dụng trung bình trượt của các mục tiêu cơ sở gần đây

### 2. Thuật toán Time Bending

**Vấn đề**: Thời gian khối PoC truyền thống tuân theo phân phối mũ, dẫn đến các khối dài khi không có thợ đào tìm được lời giải tốt.

**Giải pháp**: Biến đổi phân phối từ mũ sang chi bình phương sử dụng căn bậc ba: `Y = scale × (X^(1/3))`.

**Hiệu quả**: Các lời giải rất tốt được forge muộn hơn (mạng có thời gian quét tất cả ổ đĩa, giảm khối nhanh), các lời giải kém được cải thiện. Thời gian khối trung bình duy trì ở 120 giây, khối dài được giảm.

**Chi tiết**: [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md)

### 3. Hệ thống Ủy quyền Forging

**Khả năng**: Chủ sở hữu plot có thể ủy quyền quyền forging cho các địa chỉ khác trong khi vẫn duy trì quyền sở hữu plot.

**Các trường hợp Sử dụng**:
- Đào pool (plot ủy quyền cho địa chỉ pool)
- Cold storage (khóa đào tách biệt với quyền sở hữu plot)
- Đào đa bên (cơ sở hạ tầng chia sẻ)

**Kiến trúc**: Thiết kế chỉ dùng OP_RETURN - không có UTXO đặc biệt, các ủy quyền được theo dõi riêng trong cơ sở dữ liệu chainstate.

**Chi tiết**: [Chương 4: Ủy quyền Forging](4-forging-assignments.md)

### 4. Forging Phòng thủ

**Vấn đề**: Đồng hồ nhanh có thể cung cấp lợi thế về thời gian trong dung sai 15 giây tương lai.

**Giải pháp**: Khi nhận được khối cạnh tranh ở cùng độ cao, tự động kiểm tra chất lượng cục bộ. Nếu tốt hơn, forge ngay lập tức.

**Hiệu quả**: Loại bỏ động cơ thao túng đồng hồ - đồng hồ nhanh chỉ giúp ích nếu bạn đã có lời giải tốt nhất.

**Chi tiết**: [Chương 5: Đồng bộ Thời gian và Bảo mật](5-timing-security.md)

### 5. Mở rộng Nén Động

**Căn chỉnh Kinh tế**: Yêu cầu cấp độ mở rộng tăng theo lịch trình mũ (Năm 4, 12, 28, 60, 124 = halving 1, 3, 7, 15, 31).

**Hiệu quả**: Khi phần thưởng khối giảm, độ khó tạo plot tăng. Duy trì biên độ an toàn giữa chi phí tạo plot và chi phí tra cứu.

**Ngăn chặn**: Lạm phát dung lượng từ phần cứng nhanh hơn theo thời gian.

**Chi tiết**: [Chương 6: Tham số Mạng](6-network-parameters.md)

---

## Triết lý Thiết kế

### An toàn Mã nguồn

- Thực hành lập trình phòng thủ xuyên suốt
- Xử lý lỗi toàn diện trong các đường dẫn xác thực
- Không có khóa lồng nhau (ngăn ngừa deadlock)
- Hoạt động cơ sở dữ liệu nguyên tử (UTXO + ủy quyền cùng nhau)

### Kiến trúc Module

- Tách biệt rõ ràng giữa cơ sở hạ tầng Bitcoin Core và đồng thuận PoCX
- PoCX core framework cung cấp các primitive mật mã
- Bitcoin Core cung cấp framework xác thực, cơ sở dữ liệu, mạng

### Tối ưu hóa Hiệu năng

- Thứ tự xác thực thất bại nhanh (kiểm tra rẻ trước)
- Một lần lấy context duy nhất cho mỗi submission (không lấy cs_main lặp lại)
- Hoạt động cơ sở dữ liệu nguyên tử để đảm bảo nhất quán

### An toàn Reorg

- Dữ liệu undo đầy đủ cho các thay đổi trạng thái ủy quyền
- Đặt lại trạng thái forging khi thay đổi đỉnh chuỗi
- Phát hiện lỗi thời tại tất cả các điểm xác thực

---

## Sự khác biệt giữa PoCX và Proof of Work

| Khía cạnh | Bitcoin (PoW) | Bitcoin-PoCX |
|-----------|---------------|--------------|
| **Tài nguyên Đào** | Năng lực tính toán (hash rate) | Dung lượng ổ đĩa (capacity) |
| **Tiêu thụ Năng lượng** | Cao (hash liên tục) | Thấp (chỉ I/O ổ đĩa) |
| **Quy trình Đào** | Tìm nonce với hash < mục tiêu | Tìm nonce với deadline < thời gian đã trôi |
| **Độ khó** | Trường `bits`, điều chỉnh mỗi 2016 khối | Trường `base_target`, điều chỉnh mỗi khối |
| **Thời gian Khối** | ~10 phút (phân phối mũ) | 120 giây (time-bended, variance giảm) |
| **Trợ cấp** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Phần cứng** | ASIC (chuyên dụng) | HDD (phần cứng phổ thông) |
| **Danh tính Đào** | Ẩn danh | Chủ sở hữu plot hoặc người được ủy quyền |

---

## Yêu cầu Hệ thống

### Vận hành Node

**Tương tự Bitcoin Core**:
- **CPU**: Bộ xử lý x86_64 hiện đại
- **Bộ nhớ**: 4-8 GB RAM
- **Lưu trữ**: Chuỗi mới, hiện đang trống (có thể tăng ~4 lần nhanh hơn Bitcoin do khối 2 phút và cơ sở dữ liệu ủy quyền)
- **Mạng**: Kết nối internet ổn định
- **Đồng hồ**: Khuyến nghị đồng bộ NTP để hoạt động tối ưu

**Lưu ý**: Các tệp plot KHÔNG cần thiết cho vận hành node.

### Yêu cầu Đào

**Yêu cầu bổ sung cho đào**:
- **Tệp Plot**: Được tạo trước sử dụng `pocx_plotter` (triển khai tham chiếu)
- **Phần mềm Thợ đào**: `pocx_miner` (triển khai tham chiếu) kết nối qua RPC
- **Ví**: `bitcoind` hoặc `bitcoin-qt` với khóa riêng cho địa chỉ đào. Đào pool không yêu cầu ví cục bộ.

---

## Bắt đầu

### 1. Biên dịch Bitcoin-PoCX

```bash
# Clone với submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build với PoCX được bật
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Chi tiết**: Xem `CLAUDE.md` trong thư mục gốc repository

### 2. Chạy Node

**Chỉ Node**:
```bash
./build/bin/bitcoind
# hoặc
./build/bin/bitcoin-qt
```

**Để Đào** (bật truy cập RPC cho thợ đào bên ngoài):
```bash
./build/bin/bitcoind -miningserver
# hoặc
./build/bin/bitcoin-qt -server -miningserver
```

**Chi tiết**: [Chương 6: Tham số Mạng](6-network-parameters.md)

### 3. Tạo Tệp Plot

Sử dụng `pocx_plotter` (triển khai tham chiếu) để tạo các tệp plot định dạng PoCX.

**Chi tiết**: [Chương 2: Định dạng Plot](2-plot-format.md)

### 4. Thiết lập Đào

Sử dụng `pocx_miner` (triển khai tham chiếu) để kết nối với giao diện RPC của node.

**Chi tiết**: [Chương 7: Tham chiếu RPC](7-rpc-reference.md) và [Chương 8: Hướng dẫn Ví](8-wallet-guide.md)

---

## Ghi nhận Nguồn gốc

### Định dạng Plot

Dựa trên định dạng POC2 (Burstcoin) với các cải tiến:
- Sửa lỗ hổng bảo mật (tấn công nén XOR-transpose)
- Proof-of-work có thể mở rộng
- Bố cục tối ưu SIMD
- Chức năng seed

### Các Dự án Nguồn

- **pocx_miner**: Triển khai tham chiếu dựa trên [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Triển khai tham chiếu dựa trên [engraver](https://github.com/PoC-Consortium/engraver)

**Ghi nhận Đầy đủ**: [Chương 2: Định dạng Plot](2-plot-format.md)

---

## Tóm tắt Thông số Kỹ thuật

- **Thời gian Khối**: 120 giây (mainnet), 1 giây (regtest)
- **Trợ cấp Khối**: 10 BTC ban đầu, halving mỗi 1050000 khối (~4 năm)
- **Tổng Cung**: ~21 triệu BTC (giống như Bitcoin)
- **Dung sai Tương lai**: 15 giây (khối tối đa 15 giây trong tương lai được chấp nhận)
- **Cảnh báo Đồng hồ**: 10 giây (cảnh báo người vận hành về lệch thời gian)
- **Độ trễ Ủy quyền**: 30 khối (~1 giờ)
- **Độ trễ Thu hồi**: 720 khối (~24 giờ)
- **Định dạng Địa chỉ**: P2WPKH (bech32, pocx1q...) chỉ dùng cho các hoạt động đào PoCX và ủy quyền forging

---

## Tổ chức Mã nguồn

**Sửa đổi Bitcoin Core**: Thay đổi tối thiểu các tệp lõi, đánh dấu tính năng với `#ifdef ENABLE_POCX`

**Triển khai PoCX Mới**: Cô lập trong thư mục `src/pocx/`

---

## Các Vấn đề Bảo mật

### Bảo mật Thời gian

- Dung sai 15 giây tương lai ngăn phân mảnh mạng
- Ngưỡng cảnh báo 10 giây báo động người vận hành về lệch đồng hồ
- Forging phòng thủ loại bỏ động cơ thao túng đồng hồ
- Time Bending giảm tác động của variance thời gian

**Chi tiết**: [Chương 5: Đồng bộ Thời gian và Bảo mật](5-timing-security.md)

### Bảo mật Ủy quyền

- Thiết kế chỉ dùng OP_RETURN (không thao túng UTXO)
- Chữ ký giao dịch chứng minh quyền sở hữu plot
- Độ trễ kích hoạt ngăn thao túng trạng thái nhanh
- Dữ liệu undo an toàn reorg cho tất cả thay đổi trạng thái

**Chi tiết**: [Chương 4: Ủy quyền Forging](4-forging-assignments.md)

### Bảo mật Đồng thuận

- Chữ ký loại trừ khỏi hash khối (ngăn khả năng thay đổi)
- Kích thước chữ ký giới hạn (ngăn DoS)
- Xác thực giới hạn nén (ngăn bằng chứng yếu)
- Điều chỉnh độ khó mỗi khối (phản ứng với thay đổi dung lượng)

**Chi tiết**: [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md)

---

## Trạng thái Mạng

**Mainnet**: Chưa khởi chạy
**Testnet**: Khả dụng để thử nghiệm
**Regtest**: Hoạt động đầy đủ cho phát triển

**Tham số Khối Genesis**: [Chương 6: Tham số Mạng](6-network-parameters.md)

---

## Các Bước Tiếp theo

**Để Hiểu PoCX**: Tiếp tục đến [Chương 2: Định dạng Plot](2-plot-format.md) để tìm hiểu về cấu trúc tệp plot và quá trình phát triển định dạng.

**Để Thiết lập Đào**: Chuyển đến [Chương 7: Tham chiếu RPC](7-rpc-reference.md) để biết chi tiết tích hợp.

**Để Chạy Node**: Xem [Chương 6: Tham số Mạng](6-network-parameters.md) để biết các tùy chọn cấu hình.

---

[Mục lục](index.md) | [Tiếp: Định dạng Plot →](2-plot-format.md)

# Tài liệu Kỹ thuật Bitcoin-PoCX

**Phiên bản**: 1.0
**Nền tảng Bitcoin Core**: v30.0
**Trạng thái**: Giai đoạn Testnet
**Cập nhật lần cuối**: 25-12-2025

---

## Giới thiệu về Tài liệu này

Đây là tài liệu kỹ thuật đầy đủ cho Bitcoin-PoCX, một bản tích hợp Bitcoin Core bổ sung hỗ trợ cơ chế đồng thuận Proof of Capacity thế hệ mới (PoCX). Tài liệu được tổ chức dưới dạng hướng dẫn có thể duyệt với các chương liên kết với nhau, bao quát mọi khía cạnh của hệ thống.

**Đối tượng mục tiêu**:
- **Người vận hành Node**: Chương 1, 5, 6, 8
- **Thợ đào**: Chương 2, 3, 7
- **Nhà phát triển**: Tất cả các chương
- **Nhà nghiên cứu**: Chương 3, 4, 5

---

## Mục lục

### Phần I: Cơ bản

**[Chương 1: Giới thiệu và Tổng quan](1-introduction.md)**
Tổng quan dự án, kiến trúc, triết lý thiết kế, các tính năng chính và sự khác biệt giữa PoCX và Proof of Work.

**[Chương 2: Định dạng Tệp Plot](2-plot-format.md)**
Đặc tả đầy đủ định dạng plot PoCX bao gồm tối ưu hóa SIMD, mở rộng proof-of-work và quá trình phát triển từ POC1/POC2.

**[Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md)**
Đặc tả kỹ thuật đầy đủ về cơ chế đồng thuận PoCX: cấu trúc khối, chữ ký sinh, điều chỉnh mục tiêu cơ sở, quy trình đào, pipeline xác thực và thuật toán Time Bending.

---

### Phần II: Tính năng Nâng cao

**[Chương 4: Hệ thống Ủy quyền Forging](4-forging-assignments.md)**
Kiến trúc chỉ dùng OP_RETURN để ủy quyền quyền forging: cấu trúc giao dịch, thiết kế cơ sở dữ liệu, máy trạng thái, xử lý reorg và giao diện RPC.

**[Chương 5: Đồng bộ Thời gian và Bảo mật](5-timing-security.md)**
Dung sai lệch đồng hồ, cơ chế forging phòng thủ, chống thao túng đồng hồ và các vấn đề bảo mật liên quan đến thời gian.

**[Chương 6: Tham số Mạng](6-network-parameters.md)**
Cấu hình Chainparams, khối Genesis, tham số đồng thuận, quy tắc coinbase, mở rộng động và mô hình kinh tế.

---

### Phần III: Sử dụng và Tích hợp

**[Chương 7: Tham chiếu Giao diện RPC](7-rpc-reference.md)**
Tham chiếu đầy đủ các lệnh RPC cho đào, ủy quyền và truy vấn blockchain. Thiết yếu cho tích hợp thợ đào và pool.

**[Chương 8: Hướng dẫn Ví và GUI](8-wallet-guide.md)**
Hướng dẫn sử dụng ví Qt Bitcoin-PoCX: hộp thoại ủy quyền forging, lịch sử giao dịch, thiết lập đào và khắc phục sự cố.

---

## Điều hướng Nhanh

### Dành cho Người vận hành Node
→ Bắt đầu với [Chương 1: Giới thiệu](1-introduction.md)
→ Sau đó xem [Chương 6: Tham số Mạng](6-network-parameters.md)
→ Cấu hình đào với [Chương 8: Hướng dẫn Ví](8-wallet-guide.md)

### Dành cho Thợ đào
→ Hiểu [Chương 2: Định dạng Plot](2-plot-format.md)
→ Học quy trình trong [Chương 3: Đồng thuận và Đào](3-consensus-and-mining.md)
→ Tích hợp sử dụng [Chương 7: Tham chiếu RPC](7-rpc-reference.md)

### Dành cho Người vận hành Pool
→ Xem [Chương 4: Ủy quyền Forging](4-forging-assignments.md)
→ Nghiên cứu [Chương 7: Tham chiếu RPC](7-rpc-reference.md)
→ Triển khai sử dụng các RPC ủy quyền và submit_nonce

### Dành cho Nhà phát triển
→ Đọc tất cả các chương theo thứ tự
→ Tham chiếu chéo các tệp triển khai được ghi chú xuyên suốt
→ Khám phá cấu trúc thư mục `src/pocx/`
→ Build các bản phát hành với [GUIX](../bitcoin/contrib/guix/README.md)

---

## Quy ước Tài liệu

**Tham chiếu Tệp**: Chi tiết triển khai tham chiếu đến các tệp nguồn dạng `đường/dẫn/tệp.cpp:dòng`

**Tích hợp Mã**: Tất cả thay đổi được đánh dấu tính năng với `#ifdef ENABLE_POCX`

**Tham chiếu Chéo**: Các chương liên kết đến các phần liên quan sử dụng liên kết markdown tương đối

**Mức độ Kỹ thuật**: Tài liệu giả định sự quen thuộc với Bitcoin Core và phát triển C++

---

## Biên dịch

### Build Phát triển

```bash
# Clone với submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Cấu hình với PoCX được bật
cmake -B build -DENABLE_POCX=ON

# Build
cmake --build build -j$(nproc)
```

**Các biến thể Build**:
```bash
# Với Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Build Debug
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Phụ thuộc**: Các phụ thuộc build tiêu chuẩn của Bitcoin Core. Xem [Tài liệu build Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) cho yêu cầu từng nền tảng.

### Build Phát hành

Để có các tệp nhị phân phát hành có thể tái tạo, sử dụng hệ thống build GUIX: Xem [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Tài nguyên Bổ sung

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Các dự án Liên quan**:
- Plotter: Dựa trên [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Dựa trên [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Cách Đọc Tài liệu này

**Đọc Tuần tự**: Các chương được thiết kế để đọc theo thứ tự, xây dựng dựa trên các khái niệm trước đó.

**Đọc Tham khảo**: Sử dụng mục lục để nhảy trực tiếp đến các chủ đề cụ thể. Mỗi chương độc lập với các tham chiếu chéo đến tài liệu liên quan.

**Điều hướng Trình duyệt**: Mở `index.md` trong trình xem markdown hoặc trình duyệt. Tất cả liên kết nội bộ là tương đối và hoạt động ngoại tuyến.

**Xuất PDF**: Tài liệu này có thể được ghép thành một PDF duy nhất để đọc ngoại tuyến.

---

## Trạng thái Dự án

**Hoàn thành Tính năng**: Tất cả quy tắc đồng thuận, đào, ủy quyền và tính năng ví đã được triển khai.

**Hoàn thành Tài liệu**: Tất cả 8 chương hoàn chỉnh và đã xác minh với codebase.

**Testnet Hoạt động**: Hiện đang trong giai đoạn testnet để cộng đồng thử nghiệm.

---

## Đóng góp

Các đóng góp cho tài liệu được hoan nghênh. Vui lòng tuân thủ:
- Độ chính xác kỹ thuật hơn sự dài dòng
- Giải thích ngắn gọn, đi thẳng vào vấn đề
- Không có mã hoặc mã giả trong tài liệu (thay vào đó tham chiếu tệp nguồn)
- Chỉ những gì đã triển khai (không có tính năng suy đoán)

---

## Giấy phép

Bitcoin-PoCX kế thừa giấy phép MIT của Bitcoin Core. Xem `COPYING` trong thư mục gốc repository.

Ghi nhận nguồn gốc PoCX core framework được ghi trong [Chương 2: Định dạng Plot](2-plot-format.md).

---

**Bắt đầu Đọc**: [Chương 1: Giới thiệu và Tổng quan →](1-introduction.md)

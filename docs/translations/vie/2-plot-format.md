[← Trước: Giới thiệu](1-introduction.md) | [Mục lục](index.md) | [Tiếp: Đồng thuận và Đào →](3-consensus-and-mining.md)

---

# Chương 2: Đặc tả Định dạng Plot PoCX

Tài liệu này mô tả định dạng plot PoCX, một phiên bản nâng cao của định dạng POC2 với bảo mật được cải thiện, tối ưu hóa SIMD và proof-of-work có thể mở rộng.

## Tổng quan Định dạng

Các tệp plot PoCX chứa các giá trị hash Shabal256 được tính trước, được tổ chức để thực hiện các hoạt động đào hiệu quả. Theo truyền thống PoC từ POC1, **tất cả metadata được nhúng trong tên tệp** - không có header tệp.

### Phần mở rộng Tệp
- **Tiêu chuẩn**: `.pocx` (plot hoàn chỉnh)
- **Đang xử lý**: `.tmp` (trong quá trình plotting, đổi tên thành `.pocx` khi hoàn thành)

## Bối cảnh Lịch sử và Quá trình Phát triển Lỗ hổng

### Định dạng POC1 (Di sản)
**Hai Lỗ hổng Lớn (Đánh đổi Thời gian-Bộ nhớ):**

1. **Lỗi Phân phối PoW**
   - Phân phối proof-of-work không đồng đều giữa các scoop
   - Các số scoop thấp có thể được tính toán ngay lập tức
   - **Tác động**: Giảm yêu cầu lưu trữ cho kẻ tấn công

2. **Tấn công Nén XOR** (Đánh đổi Thời gian-Bộ nhớ 50%)
   - Khai thác các đặc tính toán học để đạt được giảm 50% lưu trữ
   - **Tác động**: Kẻ tấn công có thể đào với một nửa lưu trữ yêu cầu

**Tối ưu hóa Bố cục**: Bố cục scoop tuần tự cơ bản cho hiệu quả HDD

### Định dạng POC2 (Burstcoin)
- Đã sửa lỗi phân phối PoW
- Lỗ hổng XOR-transpose vẫn chưa được vá
- **Bố cục**: Duy trì tối ưu hóa scoop tuần tự

### Định dạng PoCX (Hiện tại)
- Đã sửa phân phối PoW (kế thừa từ POC2)
- Đã vá lỗ hổng XOR-transpose (duy nhất cho PoCX)
- **Bố cục SIMD/GPU nâng cao** được tối ưu hóa cho xử lý song song và hợp nhất bộ nhớ
- **Proof-of-work có thể mở rộng** ngăn đánh đổi thời gian-bộ nhớ khi năng lực tính toán tăng (PoW chỉ được thực hiện khi tạo hoặc nâng cấp plotfile)

## Mã hóa XOR-Transpose

### Vấn đề: Đánh đổi Thời gian-Bộ nhớ 50%

Trong các định dạng POC1/POC2, kẻ tấn công có thể khai thác mối quan hệ toán học giữa các scoop để chỉ lưu trữ một nửa dữ liệu và tính phần còn lại ngay lập tức trong quá trình đào. "Tấn công nén XOR" này làm suy yếu đảm bảo lưu trữ.

### Giải pháp: Gia cố XOR-Transpose

PoCX suy ra định dạng đào của nó (X1) bằng cách áp dụng mã hóa XOR-transpose cho các cặp warp cơ sở (X0):

**Để xây dựng scoop S của nonce N trong một X1 warp:**
1. Lấy scoop S của nonce N từ X0 warp đầu tiên (vị trí trực tiếp)
2. Lấy scoop N của nonce S từ X0 warp thứ hai (vị trí chuyển vị)
3. XOR hai giá trị 64-byte để có được X1 scoop

Bước chuyển vị hoán đổi chỉ số scoop và nonce. Theo thuật ngữ ma trận - trong đó hàng đại diện cho scoop và cột đại diện cho nonce - nó kết hợp phần tử tại vị trí (S, N) trong warp đầu tiên với phần tử tại (N, S) trong warp thứ hai.

### Tại sao Điều này Loại bỏ Tấn công

XOR-transpose liên kết mỗi scoop với toàn bộ hàng và toàn bộ cột của dữ liệu X0 cơ sở. Khôi phục một X1 scoop đơn lẻ do đó yêu cầu truy cập dữ liệu trải rộng trên tất cả 4096 chỉ số scoop. Bất kỳ nỗ lực nào để tính toán dữ liệu bị thiếu sẽ yêu cầu tái tạo 4096 nonce đầy đủ thay vì một nonce duy nhất - loại bỏ cấu trúc chi phí bất đối xứng bị khai thác bởi tấn công XOR.

Kết quả là, lưu trữ đầy đủ X1 warp trở thành chiến lược khả thi duy nhất về mặt tính toán cho thợ đào.

## Cấu trúc Metadata Tên tệp

Tất cả metadata plot được mã hóa trong tên tệp sử dụng định dạng chính xác này:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Các Thành phần Tên tệp

1. **ACCOUNT_PAYLOAD** (40 ký tự hex)
   - Payload tài khoản 20-byte thô dưới dạng hex viết hoa
   - Độc lập mạng (không có ID mạng hoặc checksum)
   - Ví dụ: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 ký tự hex)
   - Giá trị seed 32-byte dưới dạng hex viết thường
   - **Mới trong PoCX**: Seed 32-byte ngẫu nhiên trong tên tệp thay thế đánh số nonce liên tiếp - ngăn chồng chéo plot
   - Ví dụ: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (số thập phân)
   - **Đơn vị kích thước MỚI trong PoCX**: Thay thế kích thước dựa trên nonce từ POC1/POC2
   - **Thiết kế kháng XOR-transpose**: Mỗi warp = chính xác 4096 nonce (kích thước phân vùng cần thiết cho biến đổi kháng XOR-transpose)
   - **Kích thước**: 1 warp = 1073741824 byte = 1 GiB (đơn vị tiện lợi)
   - Ví dụ: `1024` (plot 1 TiB = 1024 warp)

4. **SCALING** (số thập phân có tiền tố X)
   - Cấp độ mở rộng dạng `X{level}`
   - Giá trị cao hơn = yêu cầu nhiều proof-of-work hơn
   - Ví dụ: `X4` (2^4 = 16× độ khó POC2)

### Ví dụ Tên tệp
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Bố cục Tệp và Cấu trúc Dữ liệu

### Tổ chức Phân cấp
```
Tệp Plot (KHÔNG CÓ HEADER)
├── Scoop 0
│   ├── Warp 0 (Tất cả nonce cho scoop/warp này)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Hằng số và Kích thước

| Hằng số         | Kích thước               | Mô tả                                           |
| --------------- | ------------------------ | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                    | Đầu ra hash Shabal256 đơn                       |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)   | Cặp hash được đọc trong một vòng đào            |
| **NUM\_SCOOPS** | 4096 (2¹²)              | Scoop mỗi nonce; một được chọn mỗi vòng         |
| **NONCE\_SIZE** | 262144 B (256 KiB)      | Tất cả scoop của một nonce (đơn vị nhỏ nhất PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)    | Đơn vị nhỏ nhất trong PoCX                      |

### Bố cục Tệp Plot Tối ưu SIMD

PoCX triển khai mẫu truy cập nonce nhận biết SIMD cho phép xử lý vector hóa nhiều nonce đồng thời. Nó xây dựng dựa trên các khái niệm từ [nghiên cứu tối ưu hóa POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) để tối đa hóa throughput bộ nhớ và hiệu quả SIMD.

---

#### Bố cục Tuần tự Truyền thống

Lưu trữ tuần tự các nonce:

```
[Nonce 0: Dữ liệu Scoop] [Nonce 1: Dữ liệu Scoop] [Nonce 2: Dữ liệu Scoop] ...
```

Không hiệu quả SIMD: Mỗi lane SIMD cần cùng word giữa các nonce:

```
Word 0 từ Nonce 0 -> offset 0
Word 0 từ Nonce 1 -> offset 512
Word 0 từ Nonce 2 -> offset 1024
...
```

Truy cập scatter-gather giảm throughput.

---

#### Bố cục Tối ưu SIMD PoCX

PoCX lưu trữ **vị trí word giữa 16 nonce** liền kề:

```
Cache Line (64 byte):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**Sơ đồ ASCII**

```
Bố cục truyền thống:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Bố cục PoCX:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Lợi ích Truy cập Bộ nhớ

- Một cache line cung cấp tất cả lane SIMD.
- Loại bỏ các hoạt động scatter-gather.
- Giảm cache miss.
- Truy cập bộ nhớ hoàn toàn tuần tự cho tính toán vector hóa.
- GPU cũng được hưởng lợi từ căn chỉnh 16-nonce, tối đa hóa hiệu quả cache.

---

#### Mở rộng SIMD

| SIMD       | Độ rộng Vector* | Nonce | Chu kỳ Xử lý mỗi Cache Line |
|------------|-----------------|-------|-----------------------------|
| SSE2/AVX   | 128-bit         | 4     | 4 chu kỳ                    |
| AVX2       | 256-bit         | 8     | 2 chu kỳ                    |
| AVX512     | 512-bit         | 16    | 1 chu kỳ                    |

\* Cho các hoạt động số nguyên

---



## Mở rộng Proof-of-Work

### Các Cấp độ Mở rộng
- **X0**: Nonce cơ sở không có mã hóa XOR-transpose (lý thuyết, không dùng cho đào)
- **X1**: Baseline XOR-transpose - định dạng được gia cố đầu tiên (1× work)
- **X2**: 2× X1 work (XOR giữa 2 warp)
- **X3**: 4× X1 work (XOR giữa 4 warp)
- **...**
- **Xn**: 2^(n-1) × X1 work được nhúng

### Lợi ích
- **Độ khó PoW có thể điều chỉnh**: Tăng yêu cầu tính toán để theo kịp phần cứng nhanh hơn
- **Tuổi thọ định dạng**: Cho phép mở rộng linh hoạt độ khó đào theo thời gian

### Nâng cấp Plot / Tương thích Ngược

Khi mạng tăng thang đo PoW (Proof of Work) lên 1, các plot hiện có yêu cầu nâng cấp để duy trì cùng kích thước plot hiệu quả. Về cơ bản, bạn hiện cần gấp đôi PoW trong các tệp plot để đạt được cùng đóng góp cho tài khoản của bạn.

Tin tốt là PoW bạn đã hoàn thành khi tạo các tệp plot không bị mất - bạn chỉ cần thêm PoW bổ sung vào các tệp hiện có. Không cần plot lại.

Ngoài ra, bạn có thể tiếp tục sử dụng các plot hiện tại mà không cần nâng cấp, nhưng lưu ý rằng chúng hiện chỉ đóng góp 50% kích thước hiệu quả trước đó cho tài khoản của bạn. Phần mềm đào của bạn có thể mở rộng plotfile ngay lập tức.

## So sánh với Định dạng Di sản

| Tính năng | POC1 | POC2 | PoCX |
|-----------|------|------|------|
| Phân phối PoW | Lỗi | Đã sửa | Đã sửa |
| Kháng XOR-Transpose | Dễ bị tấn công | Dễ bị tấn công | Đã sửa |
| Tối ưu hóa SIMD | Không | Không | Nâng cao |
| Tối ưu hóa GPU | Không | Không | Đã tối ưu |
| Proof-of-Work có thể Mở rộng | Không | Không | Có |
| Hỗ trợ Seed | Không | Không | Có |

Định dạng PoCX đại diện cho trạng thái nghệ thuật hiện tại trong các định dạng plot Proof of Capacity, giải quyết tất cả các lỗ hổng đã biết đồng thời cung cấp cải thiện hiệu năng đáng kể cho phần cứng hiện đại.

## Tài liệu Tham khảo và Đọc thêm

- **Nền tảng POC1/POC2**: [Tổng quan Đào Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Hướng dẫn toàn diện về các định dạng đào Proof of Capacity truyền thống
- **Nghiên cứu POC2×16**: [Thông báo CIP: POC2×16 - Một định dạng plot tối ưu mới](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Nghiên cứu tối ưu hóa SIMD gốc đã truyền cảm hứng cho PoCX
- **Thuật toán Hash Shabal**: [Dự án Saphir: Shabal, Một Bài nộp cho Cuộc thi Thuật toán Hash Mật mã của NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Đặc tả kỹ thuật thuật toán Shabal256 được sử dụng trong đào PoC

---

[← Trước: Giới thiệu](1-introduction.md) | [Mục lục](index.md) | [Tiếp: Đồng thuận và Đào →](3-consensus-and-mining.md)

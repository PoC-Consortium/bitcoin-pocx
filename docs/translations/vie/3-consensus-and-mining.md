[← Trước: Định dạng Plot](2-plot-format.md) | [Mục lục](index.md) | [Tiếp: Ủy quyền Forging →](4-forging-assignments.md)

---

# Chương 3: Quy trình Đồng thuận và Đào Bitcoin-PoCX

Đặc tả kỹ thuật đầy đủ về cơ chế đồng thuận và quy trình đào PoCX (Proof of Capacity thế hệ mới) được tích hợp vào Bitcoin Core.

---

## Mục lục

1. [Tổng quan](#tổng-quan)
2. [Kiến trúc Đồng thuận](#kiến-trúc-đồng-thuận)
3. [Quy trình Đào](#quy-trình-đào)
4. [Xác thực Khối](#xác-thực-khối)
5. [Hệ thống Ủy quyền](#hệ-thống-ủy-quyền)
6. [Lan truyền Mạng](#lan-truyền-mạng)
7. [Chi tiết Kỹ thuật](#chi-tiết-kỹ-thuật)

---

## Tổng quan

Bitcoin-PoCX triển khai một cơ chế đồng thuận Proof of Capacity thuần túy như sự thay thế hoàn toàn cho Proof of Work của Bitcoin. Đây là một chuỗi mới không có yêu cầu tương thích ngược.

**Các Thuộc tính Chính:**
- **Tiết kiệm Năng lượng:** Đào sử dụng các tệp plot được tạo trước thay vì hash tính toán
- **Deadline được Time Bend:** Biến đổi phân phối (mũ→chi bình phương) giảm khối dài, cải thiện thời gian khối trung bình
- **Hỗ trợ Ủy quyền:** Chủ sở hữu plot có thể ủy quyền quyền forging cho các địa chỉ khác
- **Tích hợp C++ Native:** Các thuật toán mật mã được triển khai trong C++ để xác thực đồng thuận

**Luồng Đào:**
```
Thợ đào Bên ngoài → get_mining_info → Tính toán Nonce → submit_nonce →
Hàng đợi Forger → Chờ Deadline → Forging Khối → Lan truyền Mạng →
Xác thực Khối → Mở rộng Chuỗi
```

---

## Kiến trúc Đồng thuận

### Cấu trúc Khối

Các khối PoCX mở rộng cấu trúc khối của Bitcoin với các trường đồng thuận bổ sung:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plot (32 byte)
    std::array<uint8_t, 20> account_id;       // Địa chỉ plot (20-byte hash160)
    uint32_t compression;                     // Cấp độ mở rộng (1-255)
    uint64_t nonce;                           // Mining nonce (64-bit)
    uint64_t quality;                         // Chất lượng được khai báo (đầu ra hash PoC)
};

class CBlockHeader {
    // Các trường Bitcoin tiêu chuẩn
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Các trường đồng thuận PoCX (thay thế nBits và nNonce)
    int nHeight;                              // Chiều cao khối (xác thực không cần ngữ cảnh)
    uint256 generationSignature;              // Chữ ký sinh (entropy đào)
    uint64_t nBaseTarget;                     // Tham số độ khó (độ khó nghịch đảo)
    PoCXProof pocxProof;                      // Bằng chứng đào

    // Các trường chữ ký khối
    std::array<uint8_t, 33> vchPubKey;        // Khóa công khai nén (33 byte)
    std::array<uint8_t, 65> vchSignature;     // Chữ ký compact (65 byte)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Các giao dịch
};
```

**Lưu ý:** Chữ ký (`vchSignature`) được loại trừ khỏi tính toán hash khối để ngăn khả năng thay đổi.

**Triển khai:** `src/primitives/block.h`

### Chữ ký Sinh

Chữ ký sinh tạo entropy đào và ngăn các tấn công tính toán trước.

**Tính toán:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Khối Genesis:** Sử dụng chữ ký sinh khởi tạo được hardcode

**Triển khai:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Mục tiêu Cơ sở (Độ khó)

Mục tiêu cơ sở là nghịch đảo của độ khó - giá trị cao hơn nghĩa là đào dễ hơn.

**Thuật toán Điều chỉnh:**
- Thời gian khối mục tiêu: 120 giây (mainnet), 1 giây (regtest)
- Khoảng điều chỉnh: Mỗi khối
- Sử dụng trung bình trượt của các mục tiêu cơ sở gần đây
- Được giới hạn để ngăn dao động độ khó cực đoan

**Triển khai:** `src/consensus/params.h`, logic điều chỉnh độ khó trong tạo khối

### Các Cấp độ Mở rộng

PoCX hỗ trợ proof-of-work có thể mở rộng trong các tệp plot thông qua các cấp độ mở rộng (Xn).

**Giới hạn Động:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Cấp độ tối thiểu được chấp nhận
    uint8_t nPoCXTargetCompression;  // Cấp độ khuyến nghị
};
```

**Lịch trình Tăng Mở rộng:**
- Khoảng mũ: Năm 4, 12, 28, 60, 124 (halving 1, 3, 7, 15, 31)
- Cấp độ mở rộng tối thiểu tăng thêm 1
- Cấp độ mở rộng mục tiêu tăng thêm 1
- Duy trì biên độ an toàn giữa chi phí tạo plot và chi phí tra cứu
- Cấp độ mở rộng tối đa: 255

**Triển khai:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Quy trình Đào

### 1. Lấy Thông tin Đào

**Lệnh RPC:** `get_mining_info`

**Quy trình:**
1. Gọi `GetNewBlockContext(chainman)` để lấy trạng thái blockchain hiện tại
2. Tính toán giới hạn nén động cho chiều cao hiện tại
3. Trả về các tham số đào

**Phản hồi:**
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

**Triển khai:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Lưu ý:**
- Không giữ khóa trong quá trình tạo phản hồi
- Việc lấy ngữ cảnh xử lý `cs_main` nội bộ
- `block_hash` được bao gồm để tham chiếu nhưng không được sử dụng trong xác thực

### 2. Đào Bên ngoài

**Trách nhiệm thợ đào bên ngoài:**
1. Đọc các tệp plot từ đĩa
2. Tính scoop dựa trên chữ ký sinh và chiều cao
3. Tìm nonce với deadline tốt nhất
4. Gửi đến node qua `submit_nonce`

**Định dạng Tệp Plot:**
- Dựa trên định dạng POC2 (Burstcoin)
- Được cải tiến với các bản sửa bảo mật và cải thiện khả năng mở rộng
- Xem ghi nhận trong `CLAUDE.md`

**Triển khai Thợ đào:** Bên ngoài (ví dụ, dựa trên Scavenger)

### 3. Gửi và Xác thực Nonce

**Lệnh RPC:** `submit_nonce`

**Tham số:**
```
height, generation_signature, account_id, seed, nonce, quality (tùy chọn)
```

**Luồng Xác thực (Thứ tự Tối ưu):**

#### Bước 1: Xác thực Định dạng Nhanh
```cpp
// Account ID: 40 ký tự hex = 20 byte
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 ký tự hex = 32 byte
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Bước 2: Lấy Ngữ cảnh
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Trả về: height, generation_signature, base_target, block_hash
```

**Khóa:** `cs_main` được xử lý nội bộ, không giữ khóa trong thread RPC

#### Bước 3: Xác thực Ngữ cảnh
```cpp
// Kiểm tra chiều cao
if (height != context.height) reject;

// Kiểm tra chữ ký sinh
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Bước 4: Xác minh Ví
```cpp
// Xác định người ký hiệu quả (xem xét ủy quyền)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Kiểm tra xem node có khóa riêng cho người ký hiệu quả
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Hỗ trợ Ủy quyền:** Chủ sở hữu plot có thể ủy quyền quyền forging cho địa chỉ khác. Ví phải có khóa cho người ký hiệu quả, không nhất thiết là chủ sở hữu plot.

#### Bước 5: Xác thực Bằng chứng
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 byte
    block_height,
    nonce,
    seed,                // 32 byte
    min_compression,
    max_compression,
    &result             // Đầu ra: quality, deadline
);
```

**Thuật toán:**
1. Giải mã chữ ký sinh từ hex
2. Tính chất lượng tốt nhất trong phạm vi nén sử dụng thuật toán tối ưu SIMD
3. Xác thực chất lượng đáp ứng yêu cầu độ khó
4. Trả về giá trị chất lượng thô

**Triển khai:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Bước 6: Tính toán Time Bending
```cpp
// Deadline đã điều chỉnh độ khó thô (giây)
uint64_t deadline_seconds = quality / base_target;

// Thời gian forge Time Bended (giây)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Công thức Time Bending:**
```
Y = scale * (X^(1/3))
trong đó:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Mục đích:** Biến đổi phân phối mũ thành chi bình phương. Các lời giải rất tốt được forge muộn hơn (mạng có thời gian quét đĩa), các lời giải kém được cải thiện. Giảm khối dài, duy trì trung bình 120 giây.

**Triển khai:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Bước 7: Gửi Forger
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // KHÔNG phải deadline - được tính lại trong forger
    height,
    generation_signature
);
```

**Thiết kế Dựa trên Hàng đợi:**
- Gửi luôn thành công (được thêm vào hàng đợi)
- RPC trả về ngay lập tức
- Thread worker xử lý bất đồng bộ

**Triển khai:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Xử lý Hàng đợi Forger

**Kiến trúc:**
- Thread worker đơn liên tục
- Hàng đợi gửi FIFO
- Trạng thái forging không khóa (chỉ thread worker)
- Không có khóa lồng nhau (ngăn ngừa deadlock)

**Vòng lặp Chính Thread Worker:**
```cpp
while (!shutdown) {
    // 1. Kiểm tra submission đã xếp hàng
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Chờ deadline hoặc submission mới
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logic ProcessSubmission:**
```cpp
1. Lấy ngữ cảnh mới: GetNewBlockContext(*chainman)

2. Kiểm tra lỗi thời (loại bỏ âm thầm):
   - Không khớp chiều cao → loại bỏ
   - Không khớp chữ ký sinh → loại bỏ
   - Hash khối đỉnh thay đổi (reorg) → đặt lại trạng thái forging

3. So sánh chất lượng:
   - Nếu quality >= current_best → loại bỏ

4. Tính deadline Time Bended:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Cập nhật trạng thái forging:
   - Hủy forging hiện tại (nếu tìm thấy tốt hơn)
   - Lưu: account_id, seed, nonce, quality, deadline
   - Tính: forge_time = block_time + deadline_seconds
   - Lưu hash đỉnh để phát hiện reorg
```

**Triển khai:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Chờ Deadline và Forging Khối

**WaitForDeadlineOrNewSubmission:**

**Điều kiện Chờ:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Khi Deadline Đạt được - Xác thực Ngữ cảnh Mới:**
```cpp
1. Lấy ngữ cảnh hiện tại: GetNewBlockContext(*chainman)

2. Xác thực chiều cao:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Xác thực chữ ký sinh:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Trường hợp biên base target:
   if (forging_base_target != current_base_target) {
       // Tính lại deadline với base target mới
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Chờ lại
   }

5. Tất cả hợp lệ → ForgeBlock()
```

**Quy trình ForgeBlock:**

```cpp
1. Xác định người ký hiệu quả (hỗ trợ ủy quyền):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Tạo coinbase script:
   coinbase_script = P2WPKH(effective_signer);  // Trả cho người ký hiệu quả

3. Tạo block template:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Thêm bằng chứng PoCX:
   block.pocxProof.account_id = plot_address;    // Địa chỉ plot gốc
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Tính lại merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Ký khối:
   // Sử dụng khóa người ký hiệu quả (có thể khác chủ sở hữu plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Gửi vào chuỗi:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Xử lý kết quả:
   if (accepted) {
       log_success();
       reset_forging_state();  // Sẵn sàng cho khối tiếp theo
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Triển khai:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Quyết định Thiết kế Quan trọng:**
- Coinbase trả cho người ký hiệu quả (tôn trọng ủy quyền)
- Bằng chứng chứa địa chỉ plot gốc (để xác thực)
- Chữ ký từ khóa người ký hiệu quả (bằng chứng sở hữu)
- Tạo template tự động bao gồm các giao dịch mempool

---

## Xác thực Khối

### Luồng Xác thực Khối Đến

Khi một khối được nhận từ mạng hoặc gửi cục bộ, nó trải qua xác thực trong nhiều giai đoạn:

### Giai đoạn 1: Xác thực Header (CheckBlockHeader)

**Xác thực Không cần Ngữ cảnh:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Xác thực PoCX (khi ENABLE_POCX được định nghĩa):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Xác thực chữ ký cơ bản (chưa có hỗ trợ ủy quyền)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Xác thực Chữ ký Cơ bản:**
1. Kiểm tra sự hiện diện của các trường pubkey và signature
2. Xác thực kích thước pubkey (33 byte nén)
3. Xác thực kích thước chữ ký (65 byte compact)
4. Khôi phục pubkey từ chữ ký: `pubkey.RecoverCompact(hash, signature)`
5. Xác minh pubkey khôi phục khớp pubkey đã lưu

**Triển khai:** `src/validation.cpp:CheckBlockHeader()`
**Logic Chữ ký:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Giai đoạn 2: Xác thực Khối (CheckBlock)

**Xác thực:**
- Tính đúng merkle root
- Tính hợp lệ giao dịch
- Yêu cầu coinbase
- Giới hạn kích thước khối
- Quy tắc đồng thuận Bitcoin tiêu chuẩn

**Triển khai:** `src/consensus/validation.cpp:CheckBlock()`

### Giai đoạn 3: Xác thực Header theo Ngữ cảnh (ContextualCheckBlockHeader)

**Xác thực Đặc thù PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Bước 1: Xác thực chữ ký sinh
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Bước 2: Xác thực base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Bước 3: Xác thực proof of capacity
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

    // Bước 4: Xác minh timing deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Các Bước Xác thực:**
1. **Chữ ký Sinh:** Phải khớp giá trị tính từ khối trước
2. **Base Target:** Phải khớp tính toán điều chỉnh độ khó
3. **Cấp độ Mở rộng:** Phải đáp ứng tối thiểu mạng (`compression >= min_compression`)
4. **Khai báo Chất lượng:** Chất lượng gửi phải khớp chất lượng tính từ bằng chứng
5. **Proof of Capacity:** Xác thực bằng chứng mật mã (tối ưu SIMD)
6. **Timing Deadline:** Deadline time-bended (`poc_time`) phải ≤ thời gian đã trôi

**Triển khai:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Giai đoạn 4: Kết nối Khối (ConnectBlock)

**Xác thực theo Ngữ cảnh Đầy đủ:**

```cpp
#ifdef ENABLE_POCX
    // Xác thực chữ ký mở rộng với hỗ trợ ủy quyền
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Xác thực Chữ ký Mở rộng:**
1. Thực hiện xác thực chữ ký cơ bản
2. Trích xuất account ID từ pubkey khôi phục
3. Lấy người ký hiệu quả cho địa chỉ plot: `GetEffectiveSigner(plot_address, height, view)`
4. Xác minh pubkey account khớp người ký hiệu quả

**Logic Ủy quyền:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Trả về người ký được ủy quyền
    }

    return plotAddress;  // Không có ủy quyền - chủ sở hữu plot ký
}
```

**Triển khai:**
- Kết nối: `src/validation.cpp:ConnectBlock()`
- Xác thực mở rộng: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logic ủy quyền: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Giai đoạn 5: Kích hoạt Chuỗi

**Luồng ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Xác thực và lưu vào đĩa
    2. ActivateBestChain → Cập nhật đỉnh chuỗi nếu đây là chuỗi tốt nhất
    3. Thông báo mạng về khối mới
}
```

**Triển khai:** `src/validation.cpp:ProcessNewBlock()`

### Tóm tắt Xác thực

**Đường dẫn Xác thực Hoàn chỉnh:**
```
Nhận Khối
    ↓
CheckBlockHeader (chữ ký cơ bản)
    ↓
CheckBlock (giao dịch, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC proof, deadline)
    ↓
ConnectBlock (chữ ký mở rộng với ủy quyền, chuyển đổi trạng thái)
    ↓
ActivateBestChain (xử lý reorg, mở rộng chuỗi)
    ↓
Lan truyền Mạng
```

---

## Hệ thống Ủy quyền

### Tổng quan

Ủy quyền cho phép chủ sở hữu plot ủy quyền quyền forging cho các địa chỉ khác trong khi vẫn duy trì quyền sở hữu plot.

**Các Trường hợp Sử dụng:**
- Đào pool (plot ủy quyền cho địa chỉ pool)
- Cold storage (khóa đào tách biệt với quyền sở hữu plot)
- Đào đa bên (cơ sở hạ tầng chia sẻ)

### Kiến trúc Ủy quyền

**Thiết kế Chỉ OP_RETURN:**
- Ủy quyền được lưu trong đầu ra OP_RETURN (không có UTXO)
- Không yêu cầu chi tiêu (không dust, không phí giữ)
- Theo dõi trong trạng thái mở rộng CCoinsViewCache
- Được kích hoạt sau khoảng trễ (mặc định: 4 khối)

**Các Trạng thái Ủy quyền:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Không có ủy quyền
    ASSIGNING = 1,   // Ủy quyền đang chờ kích hoạt (khoảng trễ)
    ASSIGNED = 2,    // Ủy quyền hoạt động, cho phép forging
    REVOKING = 3,    // Thu hồi đang chờ (khoảng trễ, vẫn hoạt động)
    REVOKED = 4      // Thu hồi hoàn tất, ủy quyền không còn hoạt động
};
```

### Tạo Ủy quyền

**Định dạng Giao dịch:**
```cpp
Transaction {
    inputs: [any]  // Chứng minh quyền sở hữu địa chỉ plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Quy tắc Xác thực:**
1. Input phải được ký bởi chủ sở hữu plot (chứng minh quyền sở hữu)
2. OP_RETURN chứa dữ liệu ủy quyền hợp lệ
3. Plot phải là UNASSIGNED hoặc REVOKED
4. Không có ủy quyền đang chờ trùng lặp trong mempool
5. Phí giao dịch tối thiểu đã được thanh toán

**Kích hoạt:**
- Ủy quyền trở thành ASSIGNING tại chiều cao xác nhận
- Trở thành ASSIGNED sau khoảng trễ (4 khối regtest, 30 khối mainnet)
- Độ trễ ngăn tái ủy quyền nhanh trong các cuộc đua khối

**Triển khai:** `src/script/forging_assignment.h`, xác thực trong ConnectBlock

### Thu hồi Ủy quyền

**Định dạng Giao dịch:**
```cpp
Transaction {
    inputs: [any]  // Chứng minh quyền sở hữu địa chỉ plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Hiệu quả:**
- Chuyển đổi trạng thái ngay lập tức sang REVOKED
- Chủ sở hữu plot có thể forge ngay lập tức
- Có thể tạo ủy quyền mới sau đó

### Xác thực Ủy quyền Trong Đào

**Xác định Người ký Hiệu quả:**
```cpp
// Trong xác thực submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Trong forging khối
coinbase_script = P2WPKH(effective_signer);  // Phần thưởng đến đây

// Trong chữ ký khối
signature = effective_signer_key.SignCompact(hash);  // Phải ký với người ký hiệu quả
```

**Xác thực Khối:**
```cpp
// Trong VerifyPoCXBlockCompactSignature (mở rộng)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Các Thuộc tính Chính:**
- Bằng chứng luôn chứa địa chỉ plot gốc
- Chữ ký phải từ người ký hiệu quả
- Coinbase trả cho người ký hiệu quả
- Xác thực sử dụng trạng thái ủy quyền tại chiều cao khối

---

## Lan truyền Mạng

### Thông báo Khối

**Giao thức P2P Bitcoin Tiêu chuẩn:**
1. Khối đã forge được gửi qua `ProcessNewBlock()`
2. Khối được xác thực và thêm vào chuỗi
3. Thông báo mạng: `GetMainSignals().BlockConnected()`
4. Lớp P2P phát sóng khối đến các peer

**Triển khai:** Standard Bitcoin Core net_processing

### Relay Khối

**Compact Blocks (BIP 152):**
- Được sử dụng để lan truyền khối hiệu quả
- Chỉ gửi ID giao dịch ban đầu
- Peer yêu cầu các giao dịch bị thiếu

**Relay Khối Đầy đủ:**
- Dự phòng khi compact block thất bại
- Truyền dữ liệu khối hoàn chỉnh

### Tái tổ chức Chuỗi

**Xử lý Reorg:**
```cpp
// Trong thread worker forger
if (current_tip_hash != stored_tip_hash) {
    // Phát hiện tái tổ chức chuỗi
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Cấp độ Blockchain:**
- Xử lý reorg tiêu chuẩn Bitcoin Core
- Chuỗi tốt nhất được xác định bởi chainwork
- Các khối bị ngắt kết nối được trả về mempool

---

## Chi tiết Kỹ thuật

### Ngăn ngừa Deadlock

**Mẫu Deadlock ABBA (Đã Ngăn ngừa):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Giải pháp:**
1. **submit_nonce:** Không sử dụng cs_main
   - `GetNewBlockContext()` xử lý khóa nội bộ
   - Tất cả xác thực trước khi gửi forger

2. **Forger:** Kiến trúc dựa trên hàng đợi
   - Thread worker đơn (không thread join)
   - Ngữ cảnh mới cho mỗi truy cập
   - Không có khóa lồng nhau

3. **Kiểm tra Ví:** Thực hiện trước các hoạt động tốn kém
   - Từ chối sớm nếu không có khóa khả dụng
   - Tách biệt với truy cập trạng thái blockchain

### Tối ưu hóa Hiệu năng

**Xác thực Thất bại Nhanh:**
```cpp
1. Kiểm tra định dạng (ngay lập tức)
2. Xác thực ngữ cảnh (nhẹ)
3. Xác minh ví (cục bộ)
4. Xác thực bằng chứng (SIMD tốn kém)
```

**Một lần Lấy Ngữ cảnh:**
- Một lệnh `GetNewBlockContext()` cho mỗi submission
- Cache kết quả cho nhiều kiểm tra
- Không lấy cs_main lặp lại

**Hiệu quả Hàng đợi:**
- Cấu trúc submission nhẹ
- Không có base_target/deadline trong hàng đợi (tính lại mới)
- Footprint bộ nhớ tối thiểu

### Xử lý Lỗi thời

**Thiết kế Forger "Đơn giản":**
- Không đăng ký sự kiện blockchain
- Xác thực lazy khi cần
- Loại bỏ âm thầm các submission lỗi thời

**Lợi ích:**
- Kiến trúc đơn giản
- Không đồng bộ hóa phức tạp
- Mạnh mẽ với các trường hợp biên

**Các Trường hợp Biên được Xử lý:**
- Thay đổi chiều cao → loại bỏ
- Thay đổi chữ ký sinh → loại bỏ
- Thay đổi base target → tính lại deadline
- Reorg → đặt lại trạng thái forging

### Chi tiết Mật mã

**Chữ ký Sinh:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash Chữ ký Khối:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Định dạng Chữ ký Compact:**
- 65 byte: [recovery_id][r][s]
- Cho phép khôi phục khóa công khai
- Sử dụng để tiết kiệm không gian

**Account ID:**
- HASH160 20-byte của khóa công khai nén
- Khớp với định dạng địa chỉ Bitcoin (P2PKH, P2WPKH)

### Cải tiến Tương lai

**Hạn chế Đã Ghi nhận:**
1. Không có metrics hiệu năng (tỷ lệ submission, phân phối deadline)
2. Không có phân loại lỗi chi tiết cho thợ đào
3. Truy vấn trạng thái forger hạn chế (deadline hiện tại, độ sâu hàng đợi)

**Cải tiến Tiềm năng:**
- RPC cho trạng thái forger
- Metrics cho hiệu quả đào
- Logging nâng cao để debug
- Hỗ trợ giao thức pool

---

## Tham chiếu Mã

**Triển khai Lõi:**
- Giao diện RPC: `src/pocx/rpc/mining.cpp`
- Hàng đợi Forger: `src/pocx/mining/scheduler.cpp`
- Xác thực Đồng thuận: `src/pocx/consensus/validation.cpp`
- Xác thực Bằng chứng: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Xác thực Khối: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logic Ủy quyền: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Quản lý Ngữ cảnh: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Cấu trúc Dữ liệu:**
- Định dạng Khối: `src/primitives/block.h`
- Tham số Đồng thuận: `src/consensus/params.h`
- Theo dõi Ủy quyền: `src/coins.h` (mở rộng CCoinsViewCache)

---

## Phụ lục: Đặc tả Thuật toán

### Công thức Time Bending

**Định nghĩa Toán học:**
```
deadline_seconds = quality / base_target  (thô)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

trong đó:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Triển khai:**
- Số học dấu phẩy cố định (định dạng Q42)
- Tính căn bậc ba chỉ số nguyên
- Tối ưu cho số học 256-bit

### Tính toán Chất lượng

**Quy trình:**
1. Sinh scoop từ chữ ký sinh và chiều cao
2. Đọc dữ liệu plot cho scoop đã tính
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Kiểm tra các cấp độ mở rộng từ min đến max
5. Trả về chất lượng tốt nhất tìm được

**Mở rộng:**
- Cấp độ X0: POC2 baseline (lý thuyết)
- Cấp độ X1: XOR-transpose baseline
- Cấp độ Xn: 2^(n-1) × X1 work được nhúng
- Mở rộng cao hơn = nhiều công việc tạo plot hơn

### Điều chỉnh Base Target

**Điều chỉnh mỗi khối:**
1. Tính trung bình trượt của các base target gần đây
2. Tính timespan thực tế so với timespan mục tiêu cho cửa sổ cuộn
3. Điều chỉnh base target tỷ lệ
4. Giới hạn để ngăn dao động cực đoan

**Công thức:**
```
avg_base_target = moving_average(recent base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Tài liệu này phản ánh triển khai đồng thuận PoCX hoàn chỉnh tính đến tháng 10 năm 2025.*

---

[← Trước: Định dạng Plot](2-plot-format.md) | [Mục lục](index.md) | [Tiếp: Ủy quyền Forging →](4-forging-assignments.md)

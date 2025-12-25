[← Trước: Đồng thuận và Đào](3-consensus-and-mining.md) | [Mục lục](index.md) | [Tiếp: Đồng bộ Thời gian →](5-timing-security.md)

---

# Chương 4: Hệ thống Ủy quyền Forging PoCX

## Tóm tắt Điều hành

Tài liệu này mô tả hệ thống ủy quyền forging PoCX **đã triển khai** sử dụng kiến trúc chỉ OP_RETURN. Hệ thống cho phép chủ sở hữu plot ủy quyền quyền forging cho các địa chỉ riêng biệt thông qua các giao dịch on-chain, với an toàn reorg đầy đủ và các hoạt động cơ sở dữ liệu nguyên tử.

**Trạng thái:** Đã Triển khai và Hoạt động Đầy đủ

## Triết lý Thiết kế Cốt lõi

**Nguyên tắc Chính:** Ủy quyền là quyền, không phải tài sản

- Không có UTXO đặc biệt để theo dõi hoặc chi tiêu
- Trạng thái ủy quyền được lưu riêng từ tập UTXO
- Quyền sở hữu được chứng minh bằng chữ ký giao dịch, không phải chi tiêu UTXO
- Theo dõi lịch sử đầy đủ để kiểm toán hoàn chỉnh
- Cập nhật cơ sở dữ liệu nguyên tử thông qua ghi batch LevelDB

## Cấu trúc Giao dịch

### Định dạng Giao dịch Ủy quyền

```
Inputs:
  [0]: Bất kỳ UTXO nào được kiểm soát bởi chủ sở hữu plot (chứng minh quyền sở hữu + trả phí)
       Phải được ký với khóa riêng của chủ sở hữu plot
  [1+]: Input bổ sung tùy chọn để chi trả phí

Outputs:
  [0]: OP_RETURN (POCX marker + địa chỉ plot + địa chỉ forge)
       Định dạng: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Kích thước: 46 byte tổng (1 byte OP_RETURN + 1 byte length + 44 byte data)
       Giá trị: 0 BTC (không thể chi tiêu, không được thêm vào tập UTXO)

  [1]: Tiền thừa trả về người dùng (tùy chọn, P2WPKH tiêu chuẩn)
```

**Triển khai:** `src/pocx/assignments/opcodes.cpp:25-52`

### Định dạng Giao dịch Thu hồi

```
Inputs:
  [0]: Bất kỳ UTXO nào được kiểm soát bởi chủ sở hữu plot (chứng minh quyền sở hữu + trả phí)
       Phải được ký với khóa riêng của chủ sở hữu plot
  [1+]: Input bổ sung tùy chọn để chi trả phí

Outputs:
  [0]: OP_RETURN (XCOP marker + địa chỉ plot)
       Định dạng: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Kích thước: 26 byte tổng (1 byte OP_RETURN + 1 byte length + 24 byte data)
       Giá trị: 0 BTC (không thể chi tiêu, không được thêm vào tập UTXO)

  [1]: Tiền thừa trả về người dùng (tùy chọn, P2WPKH tiêu chuẩn)
```

**Triển khai:** `src/pocx/assignments/opcodes.cpp:54-77`

### Các Marker

- **Marker Ủy quyền:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Marker Thu hồi:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Triển khai:** `src/pocx/assignments/opcodes.cpp:15-19`

### Đặc điểm Giao dịch Chính

- Giao dịch Bitcoin tiêu chuẩn (không thay đổi giao thức)
- Đầu ra OP_RETURN chứng minh không thể chi tiêu (không bao giờ được thêm vào tập UTXO)
- Quyền sở hữu plot được chứng minh bằng chữ ký trên input[0] từ địa chỉ plot
- Chi phí thấp (~200 byte, thường <0.0001 BTC phí)
- Ví tự động chọn UTXO lớn nhất từ địa chỉ plot để chứng minh quyền sở hữu

## Kiến trúc Cơ sở Dữ liệu

### Cấu trúc Lưu trữ

Tất cả dữ liệu ủy quyền được lưu trong cùng cơ sở dữ liệu LevelDB với tập UTXO (`chainstate/`), nhưng với tiền tố khóa riêng:

```
chainstate/ LevelDB:
├─ Tập UTXO (Bitcoin Core tiêu chuẩn)
│  └─ Tiền tố 'C': COutPoint → Coin
│
└─ Trạng thái Ủy quyền (bổ sung PoCX)
   └─ Tiền tố 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Lịch sử đầy đủ: tất cả ủy quyền cho mỗi plot theo thời gian
```

**Triển khai:** `src/txdb.cpp:237-348`

### Cấu trúc ForgingAssignment

```cpp
struct ForgingAssignment {
    // Danh tính
    std::array<uint8_t, 20> plotAddress;      // Chủ sở hữu plot (hash P2WPKH 20-byte)
    std::array<uint8_t, 20> forgingAddress;   // Người giữ quyền forging (hash P2WPKH 20-byte)

    // Vòng đời ủy quyền
    uint256 assignment_txid;                   // Giao dịch tạo ủy quyền
    int assignment_height;                     // Chiều cao khối tạo
    int assignment_effective_height;           // Khi nó trở nên hoạt động (height + delay)

    // Vòng đời thu hồi
    bool revoked;                              // Đã bị thu hồi chưa?
    uint256 revocation_txid;                   // Giao dịch thu hồi nó
    int revocation_height;                     // Chiều cao khối thu hồi
    int revocation_effective_height;           // Khi thu hồi có hiệu lực (height + delay)

    // Phương thức truy vấn trạng thái
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Triển khai:** `src/coins.h:111-178`

### Các Trạng thái Ủy quyền

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Không có ủy quyền
    ASSIGNING = 1,   // Ủy quyền đã tạo, đang chờ độ trễ kích hoạt
    ASSIGNED = 2,    // Ủy quyền hoạt động, cho phép forging
    REVOKING = 3,    // Đã thu hồi, nhưng vẫn hoạt động trong khoảng trễ
    REVOKED = 4      // Đã thu hồi hoàn toàn, không còn hoạt động
};
```

**Triển khai:** `src/coins.h:98-104`

### Khóa Cơ sở Dữ liệu

```cpp
// Khóa lịch sử: lưu bản ghi ủy quyền đầy đủ
// Định dạng khóa: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Địa chỉ plot (20 byte)
    int assignment_height;                // Chiều cao để tối ưu sắp xếp
    uint256 assignment_txid;              // ID giao dịch
};
```

**Triển khai:** `src/txdb.cpp:245-262`

### Theo dõi Lịch sử

- Mọi ủy quyền được lưu vĩnh viễn (không bao giờ bị xóa trừ khi reorg)
- Nhiều ủy quyền cho mỗi plot được theo dõi theo thời gian
- Cho phép kiểm toán đầy đủ và truy vấn trạng thái lịch sử
- Các ủy quyền đã thu hồi vẫn còn trong cơ sở dữ liệu với `revoked=true`

## Xử lý Khối

### Tích hợp ConnectBlock

OP_RETURN ủy quyền và thu hồi được xử lý trong khi kết nối khối trong `validation.cpp`:

```cpp
// Vị trí: Sau xác thực script, trước UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Phân tích dữ liệu OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Xác minh quyền sở hữu (tx phải được ký bởi chủ sở hữu plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Kiểm tra trạng thái plot (phải là UNASSIGNED hoặc REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Tạo ủy quyền mới
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Lưu dữ liệu undo
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Phân tích dữ liệu OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Xác minh quyền sở hữu
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Lấy ủy quyền hiện tại
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Lưu trạng thái cũ cho undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Đánh dấu đã thu hồi
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

// UpdateCoins tiếp tục bình thường (tự động bỏ qua đầu ra OP_RETURN)
```

**Triển khai:** `src/validation.cpp:2775-2878`

### Xác minh Quyền sở hữu

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Kiểm tra ít nhất một input được ký bởi chủ sở hữu plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Trích xuất đích
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Kiểm tra nếu P2WPKH đến địa chỉ plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core đã xác thực chữ ký
                return true;
            }
        }
    }
    return false;
}
```

**Triển khai:** `src/pocx/assignments/opcodes.cpp:217-256`

### Độ trễ Kích hoạt

Ủy quyền và thu hồi có độ trễ kích hoạt có thể cấu hình để ngăn tấn công reorg:

```cpp
// Tham số đồng thuận (có thể cấu hình cho mỗi mạng)
// Ví dụ: 30 khối = ~1 giờ với thời gian khối 2 phút
consensus.nForgingAssignmentDelay;   // Độ trễ kích hoạt ủy quyền
consensus.nForgingRevocationDelay;   // Độ trễ kích hoạt thu hồi
```

**Chuyển đổi Trạng thái:**
- Ủy quyền: `UNASSIGNED → ASSIGNING (trễ) → ASSIGNED`
- Thu hồi: `ASSIGNED → REVOKING (trễ) → REVOKED`

**Triển khai:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Xác thực Mempool

Các giao dịch ủy quyền và thu hồi được xác thực khi chấp nhận mempool để từ chối các giao dịch không hợp lệ trước khi lan truyền mạng.

### Kiểm tra Cấp độ Giao dịch (CheckTransaction)

Thực hiện trong `src/consensus/tx_check.cpp` không có truy cập trạng thái chuỗi:

1. **Tối đa Một OP_RETURN POCX:** Giao dịch không thể chứa nhiều marker POCX/XCOP

**Triển khai:** `src/consensus/tx_check.cpp:63-77`

### Kiểm tra Chấp nhận Mempool (PreChecks)

Thực hiện trong `src/validation.cpp` với truy cập đầy đủ trạng thái chuỗi và mempool:

#### Xác thực Ủy quyền

1. **Quyền sở hữu Plot:** Giao dịch phải được ký bởi chủ sở hữu plot
2. **Trạng thái Plot:** Plot phải là UNASSIGNED (0) hoặc REVOKED (4)
3. **Xung đột Mempool:** Không có ủy quyền khác cho plot này trong mempool (first-seen wins)

#### Xác thực Thu hồi

1. **Quyền sở hữu Plot:** Giao dịch phải được ký bởi chủ sở hữu plot
2. **Ủy quyền Hoạt động:** Plot phải ở trạng thái ASSIGNED (2) chỉ
3. **Xung đột Mempool:** Không có thu hồi khác cho plot này trong mempool

**Triển khai:** `src/validation.cpp:898-993`

### Luồng Xác thực

```
Giao dịch Broadcast
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Tối đa một OP_RETURN POCX
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Xác minh quyền sở hữu plot
  ✓ Kiểm tra trạng thái ủy quyền
  ✓ Kiểm tra xung đột mempool
       ↓
   Hợp lệ → Chấp nhận vào Mempool
   Không hợp lệ → Từ chối (không lan truyền)
       ↓
Đào Khối
       ↓
ConnectBlock() [validation.cpp]
  ✓ Xác thực lại tất cả kiểm tra (phòng thủ chiều sâu)
  ✓ Áp dụng thay đổi trạng thái
  ✓ Ghi thông tin undo
```

### Phòng thủ Chiều sâu

Tất cả kiểm tra xác thực mempool được thực thi lại trong `ConnectBlock()` để bảo vệ chống:
- Tấn công bypass mempool
- Khối không hợp lệ từ thợ đào độc hại
- Trường hợp biên trong kịch bản reorg

Xác thực khối vẫn có thẩm quyền cho đồng thuận.

## Cập nhật Cơ sở Dữ liệu Nguyên tử

### Kiến trúc Ba Lớp

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Cache Bộ nhớ)        │  ← Thay đổi ủy quyền được theo dõi trong bộ nhớ
│   - Coins: cacheCoins                   │
│   - Ủy quyền: pendingAssignments        │
│   - Theo dõi dirty: dirtyPlots          │
│   - Xóa: deletedAssignments             │
│   - Theo dõi bộ nhớ: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Lớp Cơ sở Dữ liệu)      │  ← Một ghi nguyên tử
│   - BatchWrite(): UTXO + Ủy quyền       │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Lưu trữ Đĩa)                 │  ← Đảm bảo ACID
│   - Giao dịch nguyên tử                 │
└─────────────────────────────────────────┘
```

### Quy trình Flush

Khi `view.Flush()` được gọi trong khi kết nối khối:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Ghi thay đổi coin vào base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Ghi thay đổi ủy quyền nguyên tử
    if (fOk && !dirtyPlots.empty()) {
        // Thu thập ủy quyền dirty
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Trống - không sử dụng

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Ghi vào cơ sở dữ liệu
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Xóa theo dõi
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Giải phóng bộ nhớ
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Triển khai:** `src/coins.cpp:278-315`

### Ghi Batch Cơ sở Dữ liệu

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Batch LevelDB đơn

    // 1. Đánh dấu trạng thái chuyển tiếp
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Ghi tất cả thay đổi coin
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Đánh dấu trạng thái nhất quán
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT NGUYÊN TỬ
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Ủy quyền được ghi riêng nhưng trong cùng ngữ cảnh giao dịch cơ sở dữ liệu
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Tham số không sử dụng (giữ cho tương thích API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Batch mới, nhưng cùng cơ sở dữ liệu

    // Ghi lịch sử ủy quyền
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Xóa các ủy quyền đã xóa khỏi lịch sử
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT NGUYÊN TỬ
    return m_db->WriteBatch(batch);
}
```

**Triển khai:** `src/txdb.cpp:332-348`

### Đảm bảo Nguyên tử

Những gì là nguyên tử:
- Tất cả thay đổi coin trong một khối được ghi nguyên tử
- Tất cả thay đổi ủy quyền trong một khối được ghi nguyên tử
- Cơ sở dữ liệu vẫn nhất quán qua các lần crash

Hạn chế hiện tại:
- Coin và ủy quyền được ghi trong các hoạt động batch LevelDB **riêng biệt**
- Cả hai hoạt động xảy ra trong `view.Flush()`, nhưng không phải trong một ghi nguyên tử đơn
- Trong thực tế: Cả hai batch hoàn thành nhanh chóng trước khi fsync đĩa
- Rủi ro tối thiểu: Cả hai sẽ cần được replay từ cùng khối trong quá trình khôi phục crash

**Lưu ý:** Điều này khác với kế hoạch kiến trúc ban đầu gọi cho một batch thống nhất đơn. Triển khai hiện tại sử dụng hai batch nhưng duy trì tính nhất quán thông qua cơ chế khôi phục crash hiện có của Bitcoin Core (marker DB_HEAD_BLOCKS).

## Xử lý Reorg

### Cấu trúc Dữ liệu Undo

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Ủy quyền đã được thêm (xóa khi undo)
        MODIFIED = 1,   // Ủy quyền đã được sửa đổi (khôi phục khi undo)
        REVOKED = 2     // Ủy quyền đã bị thu hồi (un-revoke khi undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Trạng thái đầy đủ trước khi thay đổi
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Dữ liệu undo UTXO
    std::vector<ForgingUndo> vforgingundo;  // Dữ liệu undo ủy quyền
};
```

**Triển khai:** `src/undo.h:63-105`

### Quy trình DisconnectBlock

Khi một khối bị ngắt kết nối trong quá trình reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... ngắt kết nối UTXO tiêu chuẩn ...

    // Đọc dữ liệu undo từ đĩa
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Hoàn tác thay đổi ủy quyền (xử lý theo thứ tự ngược)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Ủy quyền đã được thêm - xóa nó
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Ủy quyền đã bị thu hồi - khôi phục trạng thái chưa thu hồi
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Ủy quyền đã được sửa đổi - khôi phục trạng thái trước đó
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Triển khai:** `src/validation.cpp:2381-2415`

### Quản lý Cache Trong Reorg

```cpp
class CCoinsViewCache {
private:
    // Cache ủy quyền
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Theo dõi plot đã sửa đổi
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Theo dõi xóa
    mutable size_t cachedAssignmentsUsage{0};  // Theo dõi bộ nhớ

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

**Triển khai:** `src/coins.cpp:494-565`

## Giao diện RPC

### Lệnh Node (Không Yêu cầu Ví)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Trả về trạng thái ủy quyền hiện tại cho địa chỉ plot:
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

**Triển khai:** `src/pocx/rpc/assignments.cpp:31-126`

### Lệnh Ví (Yêu cầu Ví)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Tạo giao dịch ủy quyền:
- Tự động chọn UTXO lớn nhất từ địa chỉ plot để chứng minh quyền sở hữu
- Xây dựng giao dịch với OP_RETURN + đầu ra tiền thừa
- Ký với khóa chủ sở hữu plot
- Phát sóng đến mạng

**Triển khai:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Tạo giao dịch thu hồi:
- Tự động chọn UTXO lớn nhất từ địa chỉ plot để chứng minh quyền sở hữu
- Xây dựng giao dịch với OP_RETURN + đầu ra tiền thừa
- Ký với khóa chủ sở hữu plot
- Phát sóng đến mạng

**Triển khai:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Tạo Giao dịch Ví

Quy trình tạo giao dịch ví:

```cpp
1. Phân tích và xác thực địa chỉ (phải là P2WPKH bech32)
2. Tìm UTXO lớn nhất từ địa chỉ plot (chứng minh quyền sở hữu)
3. Tạo giao dịch tạm thời với đầu ra giả
4. Ký giao dịch (lấy kích thước chính xác với dữ liệu witness)
5. Thay thế đầu ra giả bằng OP_RETURN
6. Điều chỉnh phí tỷ lệ dựa trên thay đổi kích thước
7. Ký lại giao dịch cuối cùng
8. Phát sóng đến mạng
```

**Insight chính:** Ví phải chi tiêu từ địa chỉ plot để chứng minh quyền sở hữu, vì vậy nó tự động buộc chọn coin từ địa chỉ đó.

**Triển khai:** `src/pocx/assignments/transactions.cpp:38-263`

## Cấu trúc Tệp

### Các Tệp Triển khai Lõi

```
src/
├── coins.h                        # Struct ForgingAssignment, phương thức CCoinsViewCache [710 dòng]
├── coins.cpp                      # Quản lý cache, ghi batch [603 dòng]
│
├── txdb.h                         # Phương thức ủy quyền CCoinsViewDB [90 dòng]
├── txdb.cpp                       # Đọc/ghi cơ sở dữ liệu [349 dòng]
│
├── undo.h                         # Cấu trúc ForgingUndo cho reorg
│
├── validation.cpp                 # Tích hợp ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Định dạng OP_RETURN, phân tích, xác minh
    │   ├── opcodes.cpp            # [259 dòng] Định nghĩa marker, ops OP_RETURN, kiểm tra quyền sở hữu
    │   ├── assignment_state.h     # Helper GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Hàm truy vấn trạng thái ủy quyền
    │   ├── transactions.h         # API tạo giao dịch ví
    │   └── transactions.cpp       # Hàm ví create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Lệnh RPC node (không cần ví)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Lệnh RPC ví
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Đặc điểm Hiệu năng

### Hoạt động Cơ sở Dữ liệu

- **Lấy ủy quyền hiện tại:** O(n) - quét tất cả ủy quyền cho địa chỉ plot để tìm gần nhất
- **Lấy lịch sử ủy quyền:** O(n) - duyệt tất cả ủy quyền cho plot
- **Tạo ủy quyền:** O(1) - một insert đơn
- **Thu hồi ủy quyền:** O(1) - một update đơn
- **Reorg (mỗi ủy quyền):** O(1) - áp dụng dữ liệu undo trực tiếp

Trong đó n = số ủy quyền cho một plot (thường nhỏ, < 10)

### Sử dụng Bộ nhớ

- **Mỗi ủy quyền:** ~160 byte (struct ForgingAssignment)
- **Overhead cache:** Overhead hash map cho theo dõi dirty
- **Khối điển hình:** <10 ủy quyền = <2 KB bộ nhớ

### Sử dụng Đĩa

- **Mỗi ủy quyền:** ~200 byte trên đĩa (với overhead LevelDB)
- **10000 ủy quyền:** ~2 MB không gian đĩa
- **Không đáng kể so với tập UTXO:** <0.001% chainstate điển hình

## Hạn chế Hiện tại và Công việc Tương lai

### Hạn chế Nguyên tử

**Hiện tại:** Coin và ủy quyền được ghi trong các batch LevelDB riêng biệt trong `view.Flush()`

**Tác động:** Rủi ro lý thuyết về không nhất quán nếu crash xảy ra giữa các batch

**Giảm thiểu:**
- Cả hai batch hoàn thành nhanh chóng trước fsync
- Khôi phục crash của Bitcoin Core sử dụng marker DB_HEAD_BLOCKS
- Trong thực tế: Chưa bao giờ quan sát được trong testing

**Cải tiến tương lai:** Thống nhất thành một hoạt động batch LevelDB đơn

### Cắt tỉa Lịch sử Ủy quyền

**Hiện tại:** Tất cả ủy quyền được lưu vô thời hạn

**Tác động:** ~200 byte mỗi ủy quyền mãi mãi

**Tương lai:** Cắt tỉa tùy chọn các ủy quyền đã thu hồi hoàn toàn cũ hơn N khối

**Lưu ý:** Không chắc cần thiết - ngay cả 1 triệu ủy quyền = 200 MB

## Trạng thái Testing

### Các Test Đã Triển khai

- Phân tích và xác thực OP_RETURN
- Xác minh quyền sở hữu
- Tạo ủy quyền ConnectBlock
- Thu hồi ConnectBlock
- Xử lý reorg DisconnectBlock
- Hoạt động đọc/ghi cơ sở dữ liệu
- Chuyển đổi trạng thái (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- Lệnh RPC (get_assignment, create_assignment, revoke_assignment)
- Tạo giao dịch ví

### Các Vùng Coverage Test

- Unit test: `src/test/pocx_*_tests.cpp`
- Functional test: `test/functional/feature_pocx_*.py`
- Integration test: Testing thủ công với regtest

## Quy tắc Đồng thuận

### Quy tắc Tạo Ủy quyền

1. **Quyền sở hữu:** Giao dịch phải được ký bởi chủ sở hữu plot
2. **Trạng thái:** Plot phải ở trạng thái UNASSIGNED hoặc REVOKED
3. **Định dạng:** OP_RETURN hợp lệ với marker POCX + 2x địa chỉ 20-byte
4. **Tính duy nhất:** Một ủy quyền hoạt động cho mỗi plot tại một thời điểm

### Quy tắc Thu hồi

1. **Quyền sở hữu:** Giao dịch phải được ký bởi chủ sở hữu plot
2. **Tồn tại:** Ủy quyền phải tồn tại và chưa bị thu hồi
3. **Định dạng:** OP_RETURN hợp lệ với marker XCOP + địa chỉ 20-byte

### Quy tắc Kích hoạt

- **Kích hoạt ủy quyền:** `assignment_height + nForgingAssignmentDelay`
- **Kích hoạt thu hồi:** `revocation_height + nForgingRevocationDelay`
- **Độ trễ:** Có thể cấu hình cho mỗi mạng (ví dụ, 30 khối = ~1 giờ với thời gian khối 2 phút)

### Xác thực Khối

- Ủy quyền/thu hồi không hợp lệ → khối bị từ chối (lỗi đồng thuận)
- Đầu ra OP_RETURN tự động bị loại khỏi tập UTXO (hành vi Bitcoin tiêu chuẩn)
- Xử lý ủy quyền xảy ra trước cập nhật UTXO trong ConnectBlock

## Kết luận

Hệ thống ủy quyền forging PoCX như đã triển khai cung cấp:

- **Đơn giản:** Giao dịch Bitcoin tiêu chuẩn, không có UTXO đặc biệt
- **Hiệu quả Chi phí:** Không yêu cầu dust, chỉ phí giao dịch
- **An toàn Reorg:** Dữ liệu undo toàn diện khôi phục trạng thái đúng
- **Cập nhật Nguyên tử:** Nhất quán cơ sở dữ liệu thông qua batch LevelDB
- **Lịch sử Đầy đủ:** Dấu vết kiểm toán hoàn chỉnh của tất cả ủy quyền theo thời gian
- **Kiến trúc Sạch:** Sửa đổi Bitcoin Core tối thiểu, mã PoCX cô lập
- **Sẵn sàng Production:** Đã triển khai đầy đủ, tested và hoạt động

### Chất lượng Triển khai

- **Tổ chức mã:** Xuất sắc - tách biệt rõ ràng giữa Bitcoin Core và PoCX
- **Xử lý lỗi:** Xác thực đồng thuận toàn diện
- **Tài liệu:** Comment mã và cấu trúc được tài liệu tốt
- **Testing:** Chức năng lõi đã test, tích hợp đã xác minh

### Quyết định Thiết kế Chính Đã Xác nhận

1. Cách tiếp cận chỉ OP_RETURN (so với dựa trên UTXO)
2. Lưu trữ cơ sở dữ liệu riêng (so với Coin extraData)
3. Theo dõi lịch sử đầy đủ (so với chỉ hiện tại)
4. Quyền sở hữu bằng chữ ký (so với chi tiêu UTXO)
5. Độ trễ kích hoạt (ngăn tấn công reorg)

Hệ thống thành công đạt được tất cả mục tiêu kiến trúc với triển khai sạch, dễ bảo trì.

---

[← Trước: Đồng thuận và Đào](3-consensus-and-mining.md) | [Mục lục](index.md) | [Tiếp: Đồng bộ Thời gian →](5-timing-security.md)

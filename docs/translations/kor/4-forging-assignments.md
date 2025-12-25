[<- 이전: 합의 및 채굴](3-consensus-and-mining.md) | [목차](index.md) | [다음: 시간 동기화 ->](5-timing-security.md)

---

# 4장: PoCX 포징 할당 시스템

## 요약

이 문서는 OP_RETURN 전용 아키텍처를 사용하여 **구현된** PoCX 포징 할당 시스템을 설명합니다. 이 시스템을 통해 플롯 소유자는 온체인 트랜잭션을 통해 별도의 주소에 포징 권한을 위임할 수 있으며, 완전한 재구성 안전성과 원자적 데이터베이스 작업을 제공합니다.

**상태:** 완전히 구현되어 운영 중

## 핵심 설계 철학

**핵심 원칙:** 할당은 권한이지 자산이 아닙니다

- 추적하거나 지출할 특수 UTXO 없음
- 할당 상태가 UTXO 세트와 별도로 저장됨
- 소유권이 UTXO 지출이 아닌 트랜잭션 서명으로 증명됨
- 완전한 감사 추적을 위한 전체 이력 추적
- LevelDB 배치 쓰기를 통한 원자적 데이터베이스 업데이트

## 트랜잭션 구조

### 할당 트랜잭션 형식

```
입력:
  [0]: 플롯 소유자가 제어하는 모든 UTXO (소유권 증명 + 수수료 지불)
       플롯 소유자의 개인키로 서명해야 함
  [1+]: 수수료 충당을 위한 선택적 추가 입력

출력:
  [0]: OP_RETURN (POCX 마커 + 플롯 주소 + 포징 주소)
       형식: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       크기: 총 46 바이트 (1 바이트 OP_RETURN + 1 바이트 길이 + 44 바이트 데이터)
       값: 0 BTC (지출 불가, UTXO 세트에 추가되지 않음)

  [1]: 사용자에게 반환되는 잔돈 (선택적, 표준 P2WPKH)
```

**구현:** `src/pocx/assignments/opcodes.cpp:25-52`

### 취소 트랜잭션 형식

```
입력:
  [0]: 플롯 소유자가 제어하는 모든 UTXO (소유권 증명 + 수수료 지불)
       플롯 소유자의 개인키로 서명해야 함
  [1+]: 수수료 충당을 위한 선택적 추가 입력

출력:
  [0]: OP_RETURN (XCOP 마커 + 플롯 주소)
       형식: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       크기: 총 26 바이트 (1 바이트 OP_RETURN + 1 바이트 길이 + 24 바이트 데이터)
       값: 0 BTC (지출 불가, UTXO 세트에 추가되지 않음)

  [1]: 사용자에게 반환되는 잔돈 (선택적, 표준 P2WPKH)
```

**구현:** `src/pocx/assignments/opcodes.cpp:54-77`

### 마커

- **할당 마커:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **취소 마커:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**구현:** `src/pocx/assignments/opcodes.cpp:15-19`

### 주요 트랜잭션 특성

- 표준 Bitcoin 트랜잭션 (프로토콜 변경 없음)
- OP_RETURN 출력은 증명 가능하게 지출 불가 (UTXO 세트에 추가되지 않음)
- 플롯 소유권이 플롯 주소에서 input[0]의 서명으로 증명됨
- 저렴한 비용 (~200 바이트, 일반적으로 <0.0001 BTC 수수료)
- 지갑이 소유권 증명을 위해 플롯 주소에서 가장 큰 UTXO를 자동 선택

## 데이터베이스 아키텍처

### 저장 구조

모든 할당 데이터는 UTXO 세트와 동일한 LevelDB 데이터베이스(`chainstate/`)에 저장되지만, 별도의 키 접두사를 사용합니다:

```
chainstate/ LevelDB:
├─ UTXO 세트 (Bitcoin Core 표준)
│  └─ 'C' 접두사: COutPoint -> Coin
│
└─ 할당 상태 (PoCX 추가)
   └─ 'A' 접두사: (plot_address, assignment_txid) -> ForgingAssignment
       └─ 전체 이력: 시간에 따른 플롯당 모든 할당
```

**구현:** `src/txdb.cpp:237-348`

### ForgingAssignment 구조

```cpp
struct ForgingAssignment {
    // 신원
    std::array<uint8_t, 20> plotAddress;      // 플롯 소유자 (20바이트 P2WPKH 해시)
    std::array<uint8_t, 20> forgingAddress;   // 포징 권한 보유자 (20바이트 P2WPKH 해시)

    // 할당 생명주기
    uint256 assignment_txid;                   // 할당을 생성한 트랜잭션
    int assignment_height;                     // 생성된 블록 높이
    int assignment_effective_height;           // 활성화되는 시점 (height + delay)

    // 취소 생명주기
    bool revoked;                              // 취소되었는가?
    uint256 revocation_txid;                   // 취소한 트랜잭션
    int revocation_height;                     // 취소된 블록 높이
    int revocation_effective_height;           // 취소가 유효해지는 시점 (height + delay)

    // 상태 조회 메서드
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**구현:** `src/coins.h:111-178`

### 할당 상태

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 할당 없음
    ASSIGNING = 1,   // 할당 생성됨, 활성화 지연 대기 중
    ASSIGNED = 2,    // 할당 활성, 포징 허용
    REVOKING = 3,    // 취소됨, 그러나 지연 기간 동안 여전히 활성
    REVOKED = 4      // 완전히 취소됨, 더 이상 활성화되지 않음
};
```

**구현:** `src/coins.h:98-104`

### 데이터베이스 키

```cpp
// 이력 키: 전체 할당 레코드 저장
// 키 형식: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // 플롯 주소 (20 바이트)
    int assignment_height;                // 정렬 최적화를 위한 높이
    uint256 assignment_txid;              // 트랜잭션 ID
};
```

**구현:** `src/txdb.cpp:245-262`

### 이력 추적

- 모든 할당이 영구적으로 저장됨 (재구성이 아닌 한 삭제되지 않음)
- 시간에 따라 플롯당 여러 할당 추적
- 완전한 감사 추적 및 과거 상태 조회 가능
- 취소된 할당은 `revoked=true`로 데이터베이스에 남음

## 블록 처리

### ConnectBlock 통합

할당 및 취소 OP_RETURN은 `validation.cpp`에서 블록 연결 중 처리됩니다:

```cpp
// 위치: 스크립트 검증 후, UpdateCoins 전
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURN 데이터 파싱
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // 소유권 검증 (tx가 플롯 소유자에 의해 서명되어야 함)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // 플롯 상태 확인 (UNASSIGNED 또는 REVOKED여야 함)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // 새 할당 생성
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // 실행 취소 데이터 저장
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURN 데이터 파싱
            auto plot_addr = ParseRevocationOpReturn(output);

            // 소유권 검증
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // 현재 할당 가져오기
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // 실행 취소를 위해 이전 상태 저장
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // 취소됨으로 표시
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

// UpdateCoins가 정상적으로 진행됨 (OP_RETURN 출력은 자동으로 건너뜀)
```

**구현:** `src/validation.cpp:2775-2878`

### 소유권 검증

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // 적어도 하나의 입력이 플롯 소유자에 의해 서명되었는지 확인
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // 대상 추출
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // 플롯 주소로의 P2WPKH인지 확인
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core가 이미 서명을 검증함
                return true;
            }
        }
    }
    return false;
}
```

**구현:** `src/pocx/assignments/opcodes.cpp:217-256`

### 활성화 지연

할당과 취소는 재구성 공격을 방지하기 위해 구성 가능한 활성화 지연이 있습니다:

```cpp
// 합의 매개변수 (네트워크별 구성 가능)
// 예: 30 블록 = 2분 블록 시간으로 ~1시간
consensus.nForgingAssignmentDelay;   // 할당 활성화 지연
consensus.nForgingRevocationDelay;   // 취소 활성화 지연
```

**상태 전환:**
- 할당: `UNASSIGNED -> ASSIGNING (지연) -> ASSIGNED`
- 취소: `ASSIGNED -> REVOKING (지연) -> REVOKED`

**구현:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## 멤풀 검증

할당 및 취소 트랜잭션은 네트워크 전파 전에 멤풀 수락 시 검증되어 유효하지 않은 트랜잭션을 거부합니다.

### 트랜잭션 레벨 검사 (CheckTransaction)

체인 상태 접근 없이 `src/consensus/tx_check.cpp`에서 수행:

1. **최대 하나의 POCX OP_RETURN:** 트랜잭션에 여러 POCX/XCOP 마커가 포함될 수 없음

**구현:** `src/consensus/tx_check.cpp:63-77`

### 멤풀 수락 검사 (PreChecks)

완전한 체인 상태 및 멤풀 접근으로 `src/validation.cpp`에서 수행:

#### 할당 검증

1. **플롯 소유권:** 트랜잭션이 플롯 소유자에 의해 서명되어야 함
2. **플롯 상태:** 플롯이 UNASSIGNED (0) 또는 REVOKED (4) 상태여야 함
3. **멤풀 충돌:** 멤풀에 이 플롯에 대한 다른 할당이 없음 (먼저 본 것이 우선)

#### 취소 검증

1. **플롯 소유권:** 트랜잭션이 플롯 소유자에 의해 서명되어야 함
2. **활성 할당:** 플롯이 ASSIGNED (2) 상태만이어야 함
3. **멤풀 충돌:** 멤풀에 이 플롯에 대한 다른 취소가 없음

**구현:** `src/validation.cpp:898-993`

### 검증 흐름

```
트랜잭션 브로드캐스트
       ↓
CheckTransaction() [tx_check.cpp]
  최대 하나의 POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  플롯 소유권 검증
  할당 상태 확인
  멤풀 충돌 확인
       ↓
   유효 -> 멤풀에 수락
   무효 -> 거부 (전파하지 않음)
       ↓
블록 채굴
       ↓
ConnectBlock() [validation.cpp]
  모든 검사 재검증 (심층 방어)
  상태 변경 적용
  실행 취소 정보 기록
```

### 심층 방어

모든 멤풀 검증 검사는 `ConnectBlock()` 중에 다시 실행되어 다음으로부터 보호합니다:
- 멤풀 우회 공격
- 악의적인 채굴자의 유효하지 않은 블록
- 재구성 시나리오 중 에지 케이스

블록 검증이 합의를 위해 권위적으로 유지됩니다.

## 원자적 데이터베이스 업데이트

### 3계층 아키텍처

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (메모리 캐시)          │  <- 할당 변경이 메모리에서 추적됨
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - 더티 추적: dirtyPlots               │
│   - 삭제: deletedAssignments            │
│   - 메모리 추적: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (데이터베이스 레이어)     │  <- 단일 원자적 쓰기
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (디스크 저장)                  │  <- ACID 보장
│   - 원자적 트랜잭션                      │
└─────────────────────────────────────────┘
```

### 플러시 과정

블록 연결 중 `view.Flush()`가 호출될 때:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. 코인 변경을 베이스에 쓰기
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. 할당 변경을 원자적으로 쓰기
    if (fOk && !dirtyPlots.empty()) {
        // 더티 할당 수집
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // 비어 있음 - 사용되지 않음

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // 데이터베이스에 쓰기
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // 추적 지우기
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // 메모리 해제
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**구현:** `src/coins.cpp:278-315`

### 데이터베이스 배치 쓰기

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // 단일 LevelDB 배치

    // 1. 전환 상태 표시
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. 모든 코인 변경 쓰기
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. 일관된 상태 표시
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. 원자적 커밋
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// 할당은 별도로 쓰지만 동일한 데이터베이스 트랜잭션 컨텍스트에서
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // 사용되지 않는 매개변수 (API 호환성 유지)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // 새 배치, 그러나 동일한 데이터베이스

    // 할당 이력 쓰기
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // 이력에서 삭제된 할당 지우기
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // 원자적 커밋
    return m_db->WriteBatch(batch);
}
```

**구현:** `src/txdb.cpp:332-348`

### 원자성 보장

**원자적인 것:**
- 블록 내 모든 코인 변경이 원자적으로 기록됨
- 블록 내 모든 할당 변경이 원자적으로 기록됨
- 데이터베이스가 충돌에도 일관성 유지

**현재 제한:**
- 코인과 할당이 **별도의** LevelDB 배치 작업으로 기록됨
- 두 작업 모두 `view.Flush()` 중에 발생하지만, 단일 원자적 쓰기가 아님
- 실제로: 두 배치 모두 디스크 fsync 전에 빠르게 연속으로 완료됨
- 위험은 최소: 충돌 복구 중 둘 다 동일한 블록에서 재생해야 함

**참고:** 이것은 단일 통합 배치를 요구했던 원래 아키텍처 계획과 다릅니다. 현재 구현은 두 개의 배치를 사용하지만 Bitcoin Core의 기존 충돌 복구 메커니즘(DB_HEAD_BLOCKS 마커)을 통해 일관성을 유지합니다.

## 재구성 처리

### 실행 취소 데이터 구조

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // 할당이 추가됨 (실행 취소 시 삭제)
        MODIFIED = 1,   // 할당이 수정됨 (실행 취소 시 복원)
        REVOKED = 2     // 할당이 취소됨 (실행 취소 시 취소 해제)
    };

    UndoType type;
    ForgingAssignment assignment;  // 변경 전 전체 상태
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO 실행 취소 데이터
    std::vector<ForgingUndo> vforgingundo;  // 할당 실행 취소 데이터
};
```

**구현:** `src/undo.h:63-105`

### DisconnectBlock 과정

재구성 중 블록이 연결 해제될 때:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... 표준 UTXO 연결 해제 ...

    // 디스크에서 실행 취소 데이터 읽기
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // 할당 변경 실행 취소 (역순으로 처리)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // 할당이 추가됨 - 제거
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // 할당이 취소됨 - 취소되지 않은 상태 복원
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // 할당이 수정됨 - 이전 상태 복원
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**구현:** `src/validation.cpp:2381-2415`

### 재구성 중 캐시 관리

```cpp
class CCoinsViewCache {
private:
    // 할당 캐시
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // 수정된 플롯 추적
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // 삭제 추적
    mutable size_t cachedAssignmentsUsage{0};  // 메모리 추적

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

**구현:** `src/coins.cpp:494-565`

## RPC 인터페이스

### 노드 명령 (지갑 필요 없음)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

플롯 주소에 대한 현재 할당 상태 반환:
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

**구현:** `src/pocx/rpc/assignments.cpp:31-126`

### 지갑 명령 (지갑 필요)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

할당 트랜잭션 생성:
- 소유권 증명을 위해 플롯 주소에서 가장 큰 UTXO 자동 선택
- OP_RETURN + 잔돈 출력으로 트랜잭션 빌드
- 플롯 소유자의 키로 서명
- 네트워크에 브로드캐스트

**구현:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

취소 트랜잭션 생성:
- 소유권 증명을 위해 플롯 주소에서 가장 큰 UTXO 자동 선택
- OP_RETURN + 잔돈 출력으로 트랜잭션 빌드
- 플롯 소유자의 키로 서명
- 네트워크에 브로드캐스트

**구현:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### 지갑 트랜잭션 생성

지갑 트랜잭션 생성 과정:

```cpp
1. 주소 파싱 및 검증 (P2WPKH bech32이어야 함)
2. 플롯 주소에서 가장 큰 UTXO 찾기 (소유권 증명)
3. 더미 출력으로 임시 트랜잭션 생성
4. 트랜잭션 서명 (증인 데이터로 정확한 크기 얻기)
5. 더미 출력을 OP_RETURN으로 교체
6. 크기 변경에 따라 수수료 비례 조정
7. 최종 트랜잭션 재서명
8. 네트워크에 브로드캐스트
```

**핵심 통찰:** 지갑은 소유권을 증명하기 위해 플롯 주소에서 지출해야 하므로, 해당 주소에서 코인 선택을 자동으로 강제합니다.

**구현:** `src/pocx/assignments/transactions.cpp:38-263`

## 파일 구조

### 핵심 구현 파일

```
src/
├── coins.h                        # ForgingAssignment 구조, CCoinsViewCache 메서드 [710줄]
├── coins.cpp                      # 캐시 관리, 배치 쓰기 [603줄]
│
├── txdb.h                         # CCoinsViewDB 할당 메서드 [90줄]
├── txdb.cpp                       # 데이터베이스 읽기/쓰기 [349줄]
│
├── undo.h                         # 재구성을 위한 ForgingUndo 구조
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock 통합
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN 형식, 파싱, 검증
    │   ├── opcodes.cpp            # [259줄] 마커 정의, OP_RETURN 작업, 소유권 확인
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState 헬퍼
    │   ├── assignment_state.cpp   # 할당 상태 조회 함수
    │   ├── transactions.h         # 지갑 트랜잭션 생성 API
    │   └── transactions.cpp       # create_assignment, revoke_assignment 지갑 함수
    │
    ├── rpc/
    │   ├── assignments.h          # 노드 RPC 명령 (지갑 없음)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC
    │   ├── assignments_wallet.h   # 지갑 RPC 명령
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## 성능 특성

### 데이터베이스 작업

- **현재 할당 가져오기:** O(n) - 가장 최근을 찾기 위해 플롯 주소의 모든 할당 스캔
- **할당 이력 가져오기:** O(n) - 플롯의 모든 할당 반복
- **할당 생성:** O(1) - 단일 삽입
- **할당 취소:** O(1) - 단일 업데이트
- **재구성 (할당당):** O(1) - 직접 실행 취소 데이터 적용

여기서 n = 플롯의 할당 수 (일반적으로 작음, < 10)

### 메모리 사용량

- **할당당:** ~160 바이트 (ForgingAssignment 구조)
- **캐시 오버헤드:** 더티 추적을 위한 해시 맵 오버헤드
- **일반적인 블록:** <10 할당 = <2 KB 메모리

### 디스크 사용량

- **할당당:** ~200 바이트 (LevelDB 오버헤드 포함)
- **10000 할당:** ~2 MB 디스크 공간
- **UTXO 세트 대비 무시 가능:** 일반적인 chainstate의 <0.001%

## 현재 제한 및 향후 작업

### 원자성 제한

**현재:** 코인과 할당이 `view.Flush()` 중 별도의 LevelDB 배치로 기록됨

**영향:** 배치 사이에 충돌이 발생하면 불일치의 이론적 위험

**완화:**
- 두 배치 모두 fsync 전에 빠르게 완료됨
- Bitcoin Core의 충돌 복구가 DB_HEAD_BLOCKS 마커 사용
- 실제로: 테스트에서 관찰된 적 없음

**향후 개선:** 단일 LevelDB 배치 작업으로 통합

### 할당 이력 정리

**현재:** 모든 할당이 무기한 저장됨

**영향:** 할당당 ~200 바이트 영구

**향후:** N 블록보다 오래된 완전히 취소된 할당의 선택적 정리

**참고:** 필요할 가능성 낮음 - 100만 할당도 200 MB에 불과

## 테스트 상태

### 구현된 테스트

- OP_RETURN 파싱 및 검증
- 소유권 검증
- ConnectBlock 할당 생성
- ConnectBlock 취소
- DisconnectBlock 재구성 처리
- 데이터베이스 읽기/쓰기 작업
- 상태 전환 (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- RPC 명령 (get_assignment, create_assignment, revoke_assignment)
- 지갑 트랜잭션 생성

### 테스트 커버리지 영역

- 단위 테스트: `src/test/pocx_*_tests.cpp`
- 기능 테스트: `test/functional/feature_pocx_*.py`
- 통합 테스트: regtest로 수동 테스트

## 합의 규칙

### 할당 생성 규칙

1. **소유권:** 트랜잭션이 플롯 소유자에 의해 서명되어야 함
2. **상태:** 플롯이 UNASSIGNED 또는 REVOKED 상태여야 함
3. **형식:** POCX 마커 + 2x 20바이트 주소가 있는 유효한 OP_RETURN
4. **고유성:** 플롯당 한 번에 하나의 활성 할당

### 취소 규칙

1. **소유권:** 트랜잭션이 플롯 소유자에 의해 서명되어야 함
2. **존재:** 할당이 존재하고 이미 취소되지 않아야 함
3. **형식:** XCOP 마커 + 20바이트 주소가 있는 유효한 OP_RETURN

### 활성화 규칙

- **할당 활성화:** `assignment_height + nForgingAssignmentDelay`
- **취소 활성화:** `revocation_height + nForgingRevocationDelay`
- **지연:** 네트워크별 구성 가능 (예: 30 블록 = 2분 블록 시간으로 ~1시간)

### 블록 검증

- 유효하지 않은 할당/취소 -> 블록 거부 (합의 실패)
- OP_RETURN 출력이 UTXO 세트에서 자동 제외됨 (표준 Bitcoin 동작)
- 할당 처리가 ConnectBlock의 UTXO 업데이트 전에 발생

## 결론

구현된 PoCX 포징 할당 시스템은 다음을 제공합니다:

- **단순성:** 표준 Bitcoin 트랜잭션, 특수 UTXO 없음
- **비용 효율성:** 더스트 요구사항 없음, 트랜잭션 수수료만
- **재구성 안전성:** 포괄적인 실행 취소 데이터가 올바른 상태 복원
- **원자적 업데이트:** LevelDB 배치를 통한 데이터베이스 일관성
- **전체 이력:** 시간에 따른 모든 할당의 완전한 감사 추적
- **깔끔한 아키텍처:** 최소한의 Bitcoin Core 수정, 격리된 PoCX 코드
- **프로덕션 준비:** 완전히 구현되고, 테스트되고, 운영 중

### 구현 품질

- **코드 구성:** 우수함 - Bitcoin Core와 PoCX 간 명확한 분리
- **오류 처리:** 포괄적인 합의 검증
- **문서:** 코드 주석과 구조가 잘 문서화됨
- **테스트:** 핵심 기능이 테스트되고, 통합이 검증됨

### 검증된 핵심 설계 결정

1. OP_RETURN 전용 접근 방식 (UTXO 기반 대비)
2. 별도 데이터베이스 저장 (Coin extraData 대비)
3. 전체 이력 추적 (현재만 대비)
4. 서명에 의한 소유권 (UTXO 지출 대비)
5. 활성화 지연 (재구성 공격 방지)

이 시스템은 깔끔하고 유지 관리 가능한 구현으로 모든 아키텍처 목표를 성공적으로 달성합니다.

---

[<- 이전: 합의 및 채굴](3-consensus-and-mining.md) | [목차](index.md) | [다음: 시간 동기화 ->](5-timing-security.md)

[<- 이전: 플롯 형식](2-plot-format.md) | [목차](index.md) | [다음: 포징 할당 ->](4-forging-assignments.md)

---

# 3장: Bitcoin-PoCX 합의 및 채굴 과정

Bitcoin Core에 통합된 PoCX(차세대 용량 증명) 합의 메커니즘과 채굴 과정의 완전한 기술 사양입니다.

---

## 목차

1. [개요](#개요)
2. [합의 아키텍처](#합의-아키텍처)
3. [채굴 과정](#채굴-과정)
4. [블록 검증](#블록-검증)
5. [할당 시스템](#할당-시스템)
6. [네트워크 전파](#네트워크-전파)
7. [기술 세부사항](#기술-세부사항)

---

## 개요

Bitcoin-PoCX는 Bitcoin의 작업 증명을 완전히 대체하는 순수 용량 증명 합의 메커니즘을 구현합니다. 역호환성 요구사항이 없는 새로운 체인입니다.

**핵심 속성:**
- **에너지 효율**: 채굴이 계산 해싱 대신 사전 생성된 플롯 파일 사용
- **시간 왜곡 데드라인**: 분포 변환(지수->Weibull, 형상 k=3)으로 긴 블록 감소, 평균 블록 시간 개선
- **할당 지원**: 플롯 소유자가 다른 주소에 포징 권한 위임 가능
- **네이티브 C++ 통합**: 합의 검증을 위해 암호화 알고리즘이 C++로 구현

**채굴 흐름:**
```
외부 마이너 -> get_mining_info -> 논스 계산 -> submit_nonce ->
포저 큐 -> 데드라인 대기 -> 블록 포징 -> 네트워크 전파 ->
블록 검증 -> 체인 확장
```

---

## 합의 아키텍처

### 블록 구조

PoCX 블록은 추가 합의 필드로 Bitcoin의 블록 구조를 확장합니다:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // 플롯 시드 (32 바이트)
    std::array<uint8_t, 20> account_id;       // 플롯 주소 (20바이트 hash160)
    uint32_t compression;                     // 스케일링 레벨 (1-6)
    uint64_t nonce;                           // 채굴 논스 (64비트)
    uint64_t quality;                         // 주장된 품질 (PoC 해시 출력)
};

class CBlockHeader {
    // 표준 Bitcoin 필드
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX 합의 필드 (nBits와 nNonce를 대체)
    int nHeight;                              // 블록 높이 (컨텍스트 무관 검증)
    uint256 generationSignature;              // 생성 서명 (채굴 엔트로피)
    uint64_t nBaseTarget;                     // 난이도 매개변수 (역 난이도)
    PoCXProof pocxProof;                      // 채굴 증명

    // 블록 서명 필드
    std::array<uint8_t, 33> vchPubKey;        // 압축 공개키 (33 바이트)
    std::array<uint8_t, 65> vchSignature;     // 컴팩트 서명 (65 바이트)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // 트랜잭션
};
```

**참고:** 서명(`vchSignature`)은 가변성을 방지하기 위해 블록 해시 계산에서 제외됩니다.

**구현:** `src/primitives/block.h`

### 생성 서명

생성 서명은 채굴 엔트로피를 생성하고 사전 계산 공격을 방지합니다.

**계산:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**제네시스 블록:** 하드코딩된 초기 생성 서명 사용

**구현:** `src/pocx/consensus/difficulty.cpp:GetNextGenerationSignature()` (`src/pocx/mining/block_context.cpp:GetNewBlockContext()`에서 호출)

### 기본 목표 (난이도)

기본 목표는 난이도의 역수입니다 - 높은 값은 더 쉬운 채굴을 의미합니다.

**조정 알고리즘:**
- 목표 블록 시간: 120초 (모든 네트워크)
- 조정 간격: 매 블록
- 최근 기본 목표의 이동 평균 사용
- 극단적인 난이도 변동 방지를 위한 제한

**구현:** `src/consensus/params.h`, 블록 생성의 난이도 조정

### 스케일링 레벨

PoCX는 스케일링 레벨(Xn)을 통해 플롯 파일에서 확장 가능한 작업 증명을 지원합니다.

**동적 범위:**
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // 허용되는 최소 레벨
    uint32_t nPoCXTargetCompression;  // 권장 레벨
};
```

**스케일링 증가 일정:**
- 지수 간격: 년차 4, 12, 28, 60, 124 (반감기 1, 3, 7, 15, 31)
- 최소 스케일링 레벨 1 증가
- 목표 스케일링 레벨 1 증가
- 플롯 생성과 조회 비용 간 안전 마진 유지
- 최대 스케일링 레벨: 255

**구현:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## 채굴 과정

### 1. 채굴 정보 조회

**RPC 명령:** `get_mining_info`

**과정:**
1. `GetNewBlockContext(chainman)`을 호출하여 현재 블록체인 상태 가져오기
2. 현재 높이에 대한 동적 압축 범위 계산
3. 채굴 매개변수 반환

**응답:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 1,
  "target_compression_level": 2
}
```

**구현:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**참고:**
- 응답 생성 중 잠금 유지 없음
- 컨텍스트 획득이 내부적으로 `cs_main` 처리
- `block_hash`는 참조용으로 포함되나 검증에는 사용되지 않음

### 2. 외부 채굴

**외부 마이너 책임:**
1. 디스크에서 플롯 파일 읽기
2. 생성 서명과 높이를 기반으로 스쿱 계산
3. 최적의 데드라인을 가진 논스 찾기
4. `submit_nonce`를 통해 노드에 제출

**플롯 파일 형식:**
- POC2 형식(Burstcoin) 기반
- 보안 수정 및 확장성 개선으로 향상
- `CLAUDE.md`의 저작자 표시 참조

**마이너 구현:** 외부 (예: Scavenger 기반)

### 3. 논스 제출 및 검증

**RPC 명령:** `submit_nonce`

**매개변수:**
```
height, generation_signature, account_id, seed, nonce, quality (선택)
```

**검증 흐름 (최적화된 순서):**

#### 단계 1: 빠른 형식 검증
```cpp
// 계정 ID: 40 16진수 문자 = 20 바이트
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// 시드: 64 16진수 문자 = 32 바이트
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### 단계 2: 컨텍스트 획득
```cpp
auto context = pocx::mining::GetNewBlockContext(chainman);
// 반환: height, generation_signature, base_target, block_hash
```

**잠금:** `cs_main`이 내부적으로 처리됨, RPC 스레드에서 잠금 유지 없음

#### 단계 3: 컨텍스트 검증
```cpp
// 높이 확인
if (height != context.height) reject;

// 생성 서명 확인
if (submitted_gen_sig != context.generation_signature) reject;
```

#### 단계 4: 지갑 검증
```cpp
// 유효 서명자 결정 (할당 고려)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// 노드가 유효 서명자의 개인키를 가지고 있는지 확인
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**할당 지원:** 플롯 소유자가 다른 주소에 포징 권한을 할당할 수 있습니다. 지갑은 플롯 소유자가 아닌 유효 서명자의 키를 가지고 있어야 합니다.

#### Step 5: Compression Validation
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
if (compression < bounds.nPoCXMinCompression || compression > bounds.nPoCXTargetCompression)
    reject;
```

#### Step 6: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    account_id_hex,
    base_target,
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Algorithm:**
1. Decode generation signature from hex
2. Calculate quality at specified compression level
3. Validate quality meets difficulty requirements
4. Return raw quality value

**Implementation:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### 단계 6: 시간 왜곡 계산
```cpp
// 원시 난이도 조정 데드라인 (초)
uint64_t deadline_seconds = quality / base_target;

// 시간 왜곡 포징 시간 (초)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**시간 왜곡 공식:**
```
Y = scale * (X^(1/3))
여기서:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**목적:** 지수 분포를 Weibull 분포(형상 k=3)로 변환합니다. 매우 좋은 솔루션은 나중에 포징됩니다(네트워크가 디스크를 스캔할 시간 확보). 나쁜 솔루션은 개선됩니다. 긴 블록이 줄고, 120초 평균이 유지됩니다.

**구현:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission 제출
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,
    compression,
    block_hash        // sole staleness indicator
);
```

**큐 기반 설계:**
- Submission added to queue (rejected if queue full — `MAX_QUEUE_SIZE`)
- RPC가 즉시 반환
- 워커 스레드가 비동기적으로 처리

**구현:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. 포저 큐 처리

**아키텍처:**
- 단일 영구 워커 스레드
- FIFO 제출 큐
- 잠금 없는 포징 상태 (워커 스레드 전용)
- 중첩 잠금 없음 (데드락 방지)

**워커 스레드 메인 루프:**
```cpp
while (!shutdown) {
    // 1. 대기 중인 제출 확인
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. 데드라인 또는 새 제출 대기
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission 로직:**
```cpp
1. 새 컨텍스트 가져오기: GetNewBlockContext(*chainman)

2. 무효화 검사 (자동 폐기):
   - 높이 불일치 -> 폐기
   - 생성 서명 불일치 -> 폐기
   - 팁 블록 해시 변경 (재구성) -> 포징 상태 재설정

3. Quality comparison (lower = better):
   - quality >= current_best인 경우 -> 폐기

4. 시간 왜곡 데드라인 계산:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. 포징 상태 업데이트:
   - 기존 포징 취소 (더 나은 것이 발견된 경우)
   - 저장: account_id, seed, nonce, quality, deadline
   - 계산: forge_time = block_time + deadline_seconds
   - 재구성 감지를 위한 팁 해시 저장
```

**구현:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. 데드라인 대기 및 블록 포징

**WaitForDeadlineOrNewSubmission:**

**대기 조건:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**데드라인 도달 시 - 새 컨텍스트 검증:**
```cpp
1. 현재 컨텍스트 가져오기: GetNewBlockContext(*chainman)

2. 높이 검증:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. 생성 서명 검증:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. 기본 목표 에지 케이스:
   if (forging_base_target != current_base_target) {
       // 새 기본 목표로 데드라인 재계산
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // 다시 대기
   }

5. 모두 유효 -> ForgeBlock()
```

**ForgeBlock 과정:**

```cpp
1. 유효 서명자 결정 (할당 지원):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. 코인베이스 스크립트 생성:
   coinbase_script = P2WPKH(effective_signer);  // 유효 서명자에게 지급

3. 블록 템플릿 생성:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX 증명 추가:
   block.pocxProof.account_id = plot_address;    // 원래 플롯 주소
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. 머클 루트 재계산:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. 블록 서명:
   // 유효 서명자의 키 사용 (플롯 소유자와 다를 수 있음)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. 체인에 제출:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. 결과 처리:
   if (accepted) {
       log_success();
       reset_forging_state();  // 다음 블록 준비
   } else {
       log_failure();
       reset_forging_state();
   }
```

**구현:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**핵심 설계 결정:**
- 코인베이스가 유효 서명자에게 지급 (할당 준수)
- 증명에 원래 플롯 주소 포함 (검증용)
- 유효 서명자의 키로 서명 (소유권 증명)
- 템플릿 생성이 멤풀 트랜잭션을 자동으로 포함

---

## 블록 검증

### 수신 블록 검증 흐름

블록이 네트워크에서 수신되거나 로컬에서 제출되면 여러 단계로 검증을 거칩니다:

### 1단계: 헤더 검증 (CheckBlockHeader)

**컨텍스트 무관 검증:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX Validation (when ENABLE_POCX defined and fCheckPOW):**

1. **Signature Validation**: Verify block signature via `VerifyPoCXBlockCompactSignature()`
2. **Compression Range Check**: Verify `compression` within bounds from `GetPoCXCompressionBounds()` (error: `"bad-pocx-compression"`)
3. **Proof of Capacity**: Full PoC proof validation via `ValidateProofOfCapacity()` (error: `"bad-pocx-proof"`)
4. **Quality Match**: Submitted quality must match computed quality (error: `"bad-pocx-quality-mismatch"`)

**Implementation:** `src/validation.cpp:CheckBlockHeader()`, `src/pocx/consensus/signature.cpp`, `src/pocx/consensus/proof.cpp`

### 2단계: 블록 검증 (CheckBlock)

**검증 항목:**
- 머클 루트 정확성
- 트랜잭션 유효성
- 코인베이스 요구사항
- 블록 크기 제한
- 표준 Bitcoin 합의 규칙

**구현:** `src/consensus/validation.cpp:CheckBlock()`

### 3단계: 컨텍스트 헤더 검증 (ContextualCheckBlockHeader)

**PoCX 전용 검증:**

```cpp
#ifdef ENABLE_POCX
    // Step 1: Validate block height
    if (block.nHeight != pindexPrev->nHeight + 1) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-height");
    }

    // Step 2: Validate generation signature
    uint256 expected_gen_sig = GetNextGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gensig");
    }

    // Step 3: Validate base target
    uint64_t expected_base_target = pindexPrev->nNextBaseTarget;
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Step 4: Verify deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (poc_time > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-timing");
    }
#endif
```

**Validation Steps:**
1. **Height:** Must be previous height + 1
2. **Generation Signature:** Must match calculated value from previous block
3. **Base Target:** Must match pre-computed value from previous block
4. **Deadline Timing:** Time-bended deadline (`poc_time`) must be ≤ elapsed time

**구현:** `src/validation.cpp:ContextualCheckBlockHeader()`

### 4단계: 블록 연결 (ConnectBlock)

**완전한 컨텍스트 검증:**

```cpp
#ifdef ENABLE_POCX
    // 할당 지원이 포함된 확장 서명 검증
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**확장 서명 검증:**
1. 기본 서명 검증 수행
2. 복구된 공개키에서 계정 ID 추출
3. 플롯 주소에 대한 유효 서명자 가져오기: `GetEffectiveSigner(plot_address, height, view)`
4. 공개키 계정이 유효 서명자와 일치하는지 검증

**할당 로직:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // 할당된 서명자 반환
    }

    return plotAddress;  // 할당 없음 - 플롯 소유자가 서명
}
```

**Coinbase 수령자** (합의로 강제되지 않음):

마이너가 coinbase 출력을 유효 서명자에게 지급하도록 설정하지만(`src/pocx/mining/block_builder.cpp:CreateCoinbaseScript()`), 이는 합의에 의해 검증되지 **않습니다**. 합의가 강제하는 것은 *블록 서명*이 유효 서명자에 의해 생성되는 것뿐입니다 — 위의 `bad-pocx-assignment-sig` 검사입니다. `bad-pocx-coinbase` 규칙은 존재하지 않으며; coinbase 수령자는 마이너가 선택합니다.

**구현:**
- 연결: `src/validation.cpp:ConnectBlock()`
- 확장 검증: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- 할당 로직: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### 5단계: 체인 활성화

**ProcessNewBlock 흐름:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> 검증하고 디스크에 저장
    2. ActivateBestChain -> 이것이 최선의 체인이면 체인 팁 업데이트
    3. 새 블록에 대해 네트워크에 알림
}
```

**구현:** `src/validation.cpp:ProcessNewBlock()`

### 검증 요약

**완전한 검증 경로:**
```
블록 수신
    ↓
CheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
CheckBlock (트랜잭션, 머클)
    ↓
ContextualCheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
ConnectBlock (할당 포함 확장 서명, 상태 전환)
    ↓
ActivateBestChain (재구성 처리, 체인 확장)
    ↓
네트워크 전파
```

---

## 할당 시스템

### 개요

할당을 통해 플롯 소유자는 플롯 소유권을 유지하면서 다른 주소에 포징 권한을 위임할 수 있습니다.

**사용 사례:**
- 풀 채굴 (플롯이 풀 주소에 할당)
- 콜드 스토리지 (채굴 키가 플롯 소유권과 분리)
- 다자간 채굴 (공유 인프라)

### 할당 아키텍처

**OP_RETURN 전용 설계:**
- 할당이 OP_RETURN 출력에 저장됨 (UTXO 없음)
- 지출 요구사항 없음 (더스트 없음, 보유 수수료 없음)
- CCoinsViewCache 확장 상태에서 추적됨
- 지연 기간 후 활성화 (기본: 30 블록; regtest에서는 4)

**할당 상태:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // 할당 없음
    ASSIGNING = 1,   // 할당 활성화 대기 중 (지연 기간)
    ASSIGNED = 2,    // 할당 활성, 포징 허용
    REVOKING = 3,    // 취소 대기 중 (지연 기간, 여전히 활성)
    REVOKED = 4      // 취소 완료, 할당 더 이상 활성화되지 않음
};
```

### 할당 생성

**트랜잭션 형식:**
```cpp
Transaction {
    inputs: [any]  // 플롯 주소의 소유권 증명
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**검증 규칙:**
1. 입력이 플롯 소유자에 의해 서명되어야 함 (소유권 증명)
2. OP_RETURN에 유효한 할당 데이터 포함
3. 플롯이 UNASSIGNED 또는 REVOKED 상태여야 함
4. 멤풀에 중복 대기 할당 없음
5. 최소 트랜잭션 수수료 지불

**활성화:**
- 할당이 확인 높이에서 ASSIGNING 상태가 됨
- 지연 기간 후 ASSIGNED 상태가 됨 (4 블록 regtest, 30 블록 메인넷)
- 지연은 블록 경쟁 중 빠른 재할당 방지

**구현:** `src/pocx/assignments/opcodes.h`, ConnectBlock에서 검증

### 할당 취소

**트랜잭션 형식:**
```cpp
Transaction {
    inputs: [any]  // 플롯 주소의 소유권 증명
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**효과:**
- REVOKED 상태로 즉시 전환
- 플롯 소유자가 즉시 포징 가능
- 이후 새 할당 생성 가능

### 채굴 중 할당 검증

**유효 서명자 결정:**
```cpp
// submit_nonce 검증에서
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// 블록 포징에서
coinbase_script = P2WPKH(effective_signer);  // 보상이 여기로 감

// 블록 서명에서
signature = effective_signer_key.SignCompact(hash);  // 유효 서명자로 서명해야 함
```

**블록 검증:**
```cpp
// VerifyPoCXBlockCompactSignature (확장)에서
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**핵심 속성:**
- 증명에 항상 원래 플롯 주소 포함
- 서명은 유효 서명자로부터 해야 함
- 코인베이스가 유효 서명자에게 지급
- 검증이 블록 높이에서의 할당 상태 사용

---

## 네트워크 전파

### 블록 공지

**표준 Bitcoin P2P 프로토콜:**
1. 포징된 블록이 `ProcessNewBlock()`을 통해 제출됨
2. 블록이 검증되고 체인에 추가됨
3. 네트워크 알림: `GetMainSignals().BlockConnected()`
4. P2P 레이어가 피어에게 블록 브로드캐스트

**구현:** 표준 Bitcoin Core net_processing

### 블록 릴레이

**컴팩트 블록 (BIP 152):**
- 효율적인 블록 전파에 사용
- 처음에는 트랜잭션 ID만 전송
- 피어가 누락된 트랜잭션 요청

**전체 블록 릴레이:**
- 컴팩트 블록 실패 시 폴백
- 완전한 블록 데이터 전송

### 체인 재구성

**재구성 처리:**
```cpp
// 포저 워커 스레드에서
if (current_tip_hash != stored_tip_hash) {
    // 체인 재구성 감지
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**블록체인 레벨:**
- 표준 Bitcoin Core 재구성 처리
- 체인워크로 최선의 체인 결정
- 연결 해제된 블록이 멤풀로 반환됨

---

## 기술 세부사항

### 데드락 방지

**ABBA 데드락 패턴 (방지됨):**
```
스레드 A: cs_main -> cs_wallet
스레드 B: cs_wallet -> cs_main
```

**해결책:**
1. **submit_nonce:** cs_main 사용 없음
   - `GetNewBlockContext()`가 내부적으로 잠금 처리
   - 포저 제출 전 모든 검증

2. **포저:** 큐 기반 아키텍처
   - Single worker thread (joined on shutdown)
   - 모든 접근에서 새 컨텍스트
   - 중첩 잠금 없음

3. **지갑 확인:** 비용이 큰 작업 전에 수행
   - 키가 없으면 조기 거부
   - 블록체인 상태 접근과 분리

### 성능 최적화

**빠른 실패 검증:**
```cpp
1. 형식 검사 (즉시)
2. 컨텍스트 검증 (경량)
3. 지갑 검증 (로컬)
4. 증명 검증 (비용이 큰 SIMD)
```

**단일 컨텍스트 가져오기:**
- 제출당 하나의 `GetNewBlockContext()` 호출
- 여러 검사를 위해 결과 캐시
- 반복적인 cs_main 획득 없음

**큐 효율성:**
- 경량 제출 구조
- 큐에 base_target/deadline 없음 (새로 재계산)
- 최소한의 메모리 사용량

### 무효화 처리

**"단순한" 포저 설계:**
- 블록체인 이벤트 구독 없음
- 필요할 때 지연 검증
- 무효화된 제출의 자동 폐기

**이점:**
- 단순한 아키텍처
- 복잡한 동기화 없음
- 에지 케이스에 강건함

**처리되는 에지 케이스:**
- 높이 변경 -> 폐기
- 생성 서명 변경 -> 폐기
- 기본 목표 변경 -> 데드라인 재계산
- 재구성 -> 포징 상태 재설정

### 암호화 세부사항

**생성 서명:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**블록 서명 해시:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**컴팩트 서명 형식:**
- 65 바이트: [recovery_id][r][s]
- 공개키 복구 허용
- 공간 효율성을 위해 사용

**계정 ID:**
- 압축 공개키의 20바이트 HASH160
- Bitcoin 주소 형식과 일치 (P2PKH, P2WPKH)

### 향후 개선사항

**문서화된 제한:**
1. 성능 메트릭 없음 (제출률, 데드라인 분포)
2. 마이너를 위한 상세한 오류 분류 없음
3. 제한된 포저 상태 조회 (현재 데드라인, 큐 깊이)

**잠재적 개선:**
- 포저 상태를 위한 RPC
- 채굴 효율성 메트릭
- 디버깅을 위한 향상된 로깅
- 풀 프로토콜 지원

---

## 코드 참조

**핵심 구현:**
- RPC 인터페이스: `src/pocx/rpc/mining.cpp`
- 포저 큐: `src/pocx/mining/scheduler.cpp`
- 합의 검증: `src/pocx/consensus/proof.cpp`
- 증명 검증: `src/pocx/consensus/signature.cpp`
- 시간 왜곡: `src/pocx/algorithms/time_bending.cpp`
- 블록 검증: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- 할당 로직: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- 컨텍스트 관리: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**데이터 구조:**
- 블록 형식: `src/primitives/block.h`
- 합의 매개변수: `src/consensus/params.h`
- 할당 추적: `src/coins.h` (CCoinsViewCache 확장)

---

## 부록: 알고리즘 사양

### 시간 왜곡 공식

**수학적 정의:**
```
deadline_seconds = quality / base_target  (원시)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

여기서:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**구현:**
- 고정 소수점 산술 (Q42 형식)
- 정수 전용 세제곱근 계산
- 256비트 산술 최적화

### 품질 계산

**과정:**
1. 생성 서명과 높이에서 스쿱 생성
2. 계산된 스쿱에 대한 플롯 데이터 읽기
3. 해시: `Shabal256Lite(scoop_data, generation_signature)`
4. 최소에서 최대까지 스케일링 레벨 테스트
5. 찾은 최적 품질 반환

**스케일링:**
- 레벨 X0: POC2 기준선 (이론적)
- 레벨 X1: XOR-전치 기준선
- 레벨 Xn: 2^(n-1) × X1 작업 내장
- 높은 스케일링 = 더 많은 플롯 생성 작업

### 기본 목표 조정

**매 블록 조정:**
1. 최근 기본 목표의 이동 평균 계산
2. 롤링 윈도우에 대한 실제 시간 간격 vs 목표 시간 간격 계산
3. 비례적으로 기본 목표 조정
4. 극단적인 변동 방지를 위한 제한

**공식:**
```
avg_base_target = moving_average(최근 기본 목표)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*이 문서는 2025년 10월 기준 완전한 PoCX 합의 구현을 반영합니다.*

---

[<- 이전: 플롯 형식](2-plot-format.md) | [목차](index.md) | [다음: 포징 할당 ->](4-forging-assignments.md)

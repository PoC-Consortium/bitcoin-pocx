[<- 이전: 네트워크 매개변수](6-network-parameters.md) | [목차](index.md) | [다음: 지갑 가이드 ->](8-wallet-guide.md)

---

# 7장: RPC 인터페이스 참조

채굴 RPC, 할당 관리 및 수정된 블록체인 RPC를 포함한 Bitcoin-PoCX RPC 명령어의 완전한 참조입니다.

---

## 목차

1. [구성](#구성)
2. [PoCX 채굴 RPC](#pocx-채굴-rpc)
3. [할당 RPC](#할당-rpc)
4. [수정된 블록체인 RPC](#수정된-블록체인-rpc)
5. [비활성화된 RPC](#비활성화된-rpc)
6. [통합 예제](#통합-예제)

---

## 구성

### 채굴 서버 모드

**플래그**: `-miningserver`

**목적**: 외부 마이너가 채굴 전용 RPC를 호출할 수 있도록 RPC 접근 활성화

**요구사항**:
- `submit_nonce`가 작동하려면 필수
- Qt 지갑에서 포징 할당 대화상자가 보이려면 필수

**사용법**:
```bash
# 명령줄
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**보안 고려사항**:
- 표준 RPC 자격 증명 외 추가 인증 없음
- 채굴 RPC는 큐 용량으로 속도 제한됨
- 표준 RPC 인증은 여전히 필요

**구현**: `src/pocx/rpc/mining.cpp`

---

## PoCX 채굴 RPC

### get_mining_info

**카테고리**: mining
**채굴 서버 필요**: 아니오
**지갑 필요**: 아니오

**목적**: 외부 마이너가 플롯 파일을 스캔하고 데드라인을 계산하는 데 필요한 현재 채굴 매개변수를 반환합니다.

**매개변수**: 없음

**반환값**:
```json
{
  "generation_signature": "abc123...",       // 16진수, 64자
  "base_target": 36650387593,                // 숫자
  "height": 12345,                           // 숫자, 다음 블록 높이
  "block_hash": "def456...",                 // 16진수, 이전 블록
  "target_quality": 18446744073709551615,    // uint64_max (모든 솔루션 허용)
  "minimum_compression_level": 1,            // 숫자
  "target_compression_level": 2              // 숫자
}
```

**필드 설명**:
- `generation_signature`: 이 블록 높이에 대한 결정론적 채굴 엔트로피
- `base_target`: 현재 난이도 (높을수록 쉬움)
- `height`: 마이너가 목표로 해야 할 블록 높이
- `block_hash`: 이전 블록 해시 (정보 제공용)
- `target_quality`: 품질 임계값 (현재 uint64_max, 필터링 없음)
- `minimum_compression_level`: 검증에 필요한 최소 압축
- `target_compression_level`: 최적 채굴을 위한 권장 압축

**오류 코드**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: 노드가 아직 동기화 중

**예시**:
```bash
bitcoin-cli get_mining_info
```

**구현**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**카테고리**: mining
**채굴 서버 필요**: 예
**지갑 필요**: 예 (개인키용)

**목적**: PoCX 채굴 솔루션을 제출합니다. 증명을 검증하고, 시간 왜곡 포징을 위해 큐에 넣고, 예정된 시간에 자동으로 블록을 생성합니다.

**매개변수**:
1. `height` (숫자, 필수) - 블록 높이
2. `generation_signature` (문자열 16진수, 필수) - 생성 서명 (64자)
3. `account_id` (문자열, 필수) - 플롯 계정 ID (40 16진수 문자 = 20 바이트)
4. `seed` (문자열, 필수) - 플롯 시드 (64 16진수 문자 = 32 바이트)
5. `nonce` (숫자, 필수) - 채굴 논스
6. `compression` (숫자, 필수) - 사용된 스케일링/압축 레벨 (1-255)
7. `quality` (숫자, 선택) - 품질 값 (생략 시 재계산)

**반환값** (성공):
```json
{
  "accepted": true,
  "quality": 120,           // 난이도 조정된 데드라인 (초)
  "poc_time": 45            // 시간 왜곡된 포징 시간 (초)
}
```

**반환값** (거부):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**검증 단계**:
1. **형식 검증** (빠른 실패):
   - 계정 ID: 정확히 40 16진수 문자
   - 시드: 정확히 64 16진수 문자
2. **컨텍스트 검증**:
   - 높이가 현재 팁 + 1과 일치해야 함
   - 생성 서명이 현재와 일치해야 함
3. **지갑 확인**:
   - 유효 서명자 결정 (활성 할당 확인)
   - 지갑이 유효 서명자의 개인키를 가지고 있는지 확인
4. **증명 검증** (비용이 큰 작업):
   - 압축 범위로 PoCX 증명 검증
   - 원시 품질 계산
5. **스케줄러 제출**:
   - 시간 왜곡 포징을 위해 논스 큐에 추가
   - forge_time에 블록이 자동 생성됨

**오류 코드**:
- `RPC_INVALID_PARAMETER`: 잘못된 형식 (account_id, seed) 또는 높이 불일치
- `RPC_VERIFY_REJECTED`: 생성 서명 불일치 또는 증명 검증 실패
- `RPC_INVALID_ADDRESS_OR_KEY`: 유효 서명자의 개인키 없음
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: 제출 큐 가득 참
- `RPC_INTERNAL_ERROR`: PoCX 스케줄러 초기화 실패

**증명 검증 오류 코드**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**예시**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**참고**:
- 제출은 비동기 - RPC가 즉시 반환, 블록은 나중에 포징
- 시간 왜곡이 좋은 솔루션을 지연시켜 네트워크 전체 플롯 스캔 허용
- 할당 시스템: 플롯이 할당된 경우, 지갑이 포징 주소 키를 가지고 있어야 함
- 압축 범위가 블록 높이에 따라 동적으로 조정됨

**구현**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## 할당 RPC

### get_assignment

**카테고리**: mining
**채굴 서버 필요**: 아니오
**지갑 필요**: 아니오

**목적**: 플롯 주소에 대한 포징 할당 상태를 조회합니다. 읽기 전용, 지갑 필요 없음.

**매개변수**:
1. `plot_address` (문자열, 필수) - 플롯 주소 (bech32 P2WPKH 형식)
2. `height` (숫자, 선택) - 조회할 블록 높이 (기본: 현재 팁)

**반환값** (할당 없음):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**반환값** (활성 할당):
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

**반환값** (취소 중):
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

**할당 상태**:
- `UNASSIGNED`: 할당이 존재하지 않음
- `ASSIGNING`: 할당 tx 확인됨, 활성화 지연 진행 중
- `ASSIGNED`: 할당 활성, 포징 권한 위임됨
- `REVOKING`: 취소 tx 확인됨, 지연 경과까지 여전히 활성
- `REVOKED`: 취소 완료, 포징 권한이 플롯 소유자에게 반환됨

**오류 코드**:
- `RPC_INVALID_ADDRESS_OR_KEY`: 잘못된 주소 또는 P2WPKH (bech32) 아님

**예시**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**구현**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**카테고리**: wallet
**채굴 서버 필요**: 아니오
**지갑 필요**: 예 (로드되고 잠금 해제되어야 함)

**목적**: 다른 주소(예: 채굴 풀)에 포징 권한을 위임하는 포징 할당 트랜잭션을 생성합니다.

**매개변수**:
1. `plot_address` (문자열, 필수) - 플롯 소유자 주소 (개인키 소유 필수, P2WPKH bech32)
2. `forging_address` (문자열, 필수) - 포징 권한을 할당할 주소 (P2WPKH bech32)
3. `fee_rate` (숫자, 선택) - BTC/kvB 단위 수수료율 (기본: minRelayFee의 10배)

**반환값**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**요구사항**:
- 지갑이 로드되고 잠금 해제됨
- 지갑에 plot_address의 개인키 있음
- 두 주소 모두 P2WPKH (bech32 형식: 메인넷 pocx1q..., 테스트넷 tpocx1q...)
- 플롯 주소에 확인된 UTXO 있음 (소유권 증명)
- 플롯에 활성 할당 없음 (먼저 취소 필요)

**트랜잭션 구조**:
- 입력: 플롯 주소의 UTXO (소유권 증명)
- 출력: OP_RETURN (46 바이트): `POCX` 마커 + plot_address (20 바이트) + forging_address (20 바이트)
- 출력: 지갑에 반환되는 잔돈

**활성화**:
- 확인 시 할당이 ASSIGNING 상태가 됨
- `nForgingAssignmentDelay` 블록 후 ACTIVE 상태가 됨
- 지연은 체인 포크 중 빠른 재할당 방지

**오류 코드**:
- `RPC_WALLET_NOT_FOUND`: 사용 가능한 지갑 없음
- `RPC_WALLET_UNLOCK_NEEDED`: 지갑 암호화되고 잠김
- `RPC_WALLET_ERROR`: 트랜잭션 생성 실패
- `RPC_INVALID_ADDRESS_OR_KEY`: 잘못된 주소 형식

**예시**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**구현**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**카테고리**: wallet
**채굴 서버 필요**: 아니오
**지갑 필요**: 예 (로드되고 잠금 해제되어야 함)

**목적**: 기존 포징 할당을 취소하고 포징 권한을 플롯 소유자에게 반환합니다.

**매개변수**:
1. `plot_address` (문자열, 필수) - 플롯 주소 (개인키 소유 필수, P2WPKH bech32)
2. `fee_rate` (숫자, 선택) - BTC/kvB 단위 수수료율 (기본: minRelayFee의 10배)

**반환값**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**요구사항**:
- 지갑이 로드되고 잠금 해제됨
- 지갑에 plot_address의 개인키 있음
- 플롯 주소가 P2WPKH (bech32 형식)
- 플롯 주소에 확인된 UTXO 있음

**트랜잭션 구조**:
- 입력: 플롯 주소의 UTXO (소유권 증명)
- 출력: OP_RETURN (26 바이트): `XCOP` 마커 + plot_address (20 바이트)
- 출력: 지갑에 반환되는 잔돈

**효과**:
- 상태가 즉시 REVOKING으로 전환
- 지연 기간 동안 포징 주소가 여전히 포징 가능
- `nForgingRevocationDelay` 블록 후 REVOKED 상태가 됨
- 취소 유효 후 플롯 소유자가 포징 가능
- 취소 완료 후 새 할당 생성 가능

**오류 코드**:
- `RPC_WALLET_NOT_FOUND`: 사용 가능한 지갑 없음
- `RPC_WALLET_UNLOCK_NEEDED`: 지갑 암호화되고 잠김
- `RPC_WALLET_ERROR`: 트랜잭션 생성 실패

**예시**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**참고**:
- 멱등성: 활성 할당이 없어도 취소 가능
- 취소가 제출되면 취소 불가

**구현**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## 수정된 블록체인 RPC

### getdifficulty

**PoCX 수정사항**:
- **계산**: `reference_base_target / current_base_target`
- **참조**: 1 TiB 네트워크 용량 (base_target = 36650387593)
- **해석**: TiB 단위 예상 네트워크 스토리지 용량
  - 예: `1.0` = ~1 TiB
  - 예: `1024.0` = ~1 PiB
- **PoW와의 차이**: 해시 파워가 아닌 용량을 나타냄

**예시**:
```bash
bitcoin-cli getdifficulty
# 반환: 2048.5 (네트워크 ~2 PiB)
```

**구현**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX 추가 필드**:
- `time_since_last_block` (숫자) - 이전 블록 이후 초 (mediantime 대체)
- `poc_time` (숫자) - 시간 왜곡된 포징 시간 (초)
- `base_target` (숫자) - PoCX 난이도 기본 목표
- `generation_signature` (문자열 16진수) - 생성 서명
- `pocx_proof` (객체):
  - `account_id` (문자열 16진수) - 플롯 계정 ID (20 바이트)
  - `seed` (문자열 16진수) - 플롯 시드 (32 바이트)
  - `nonce` (숫자) - 채굴 논스
  - `compression` (숫자) - 사용된 스케일링 레벨
  - `quality` (숫자) - 주장된 품질 값
- `pubkey` (문자열 16진수) - 블록 서명자의 공개키 (33 바이트)
- `signer_address` (문자열) - 블록 서명자의 주소
- `signature` (문자열 16진수) - 블록 서명 (65 바이트)

**PoCX 제거 필드**:
- `mediantime` - 제거됨 (time_since_last_block으로 대체)

**예시**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**구현**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX 수정사항**: getblockheader와 동일, 추가로 전체 트랜잭션 데이터 포함

**예시**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # tx 세부사항 포함 상세
```

**구현**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX 추가 필드**:
- `base_target` (숫자) - 현재 기본 목표
- `generation_signature` (문자열 16진수) - 현재 생성 서명

**PoCX 수정 필드**:
- `difficulty` - PoCX 계산 사용 (용량 기반)

**PoCX 제거 필드**:
- `mediantime` - 제거됨

**예시**:
```bash
bitcoin-cli getblockchaininfo
```

**구현**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX 추가 필드**:
- `generation_signature` (문자열 16진수) - 풀 채굴용
- `base_target` (숫자) - 풀 채굴용

**PoCX 제거 필드**:
- `target` - 제거됨 (PoW 전용)
- `noncerange` - 제거됨 (PoW 전용)
- `bits` - 제거됨 (PoW 전용)

**참고**:
- 블록 구성을 위한 전체 트랜잭션 데이터는 여전히 포함
- 협력 채굴을 위해 풀 서버에서 사용

**예시**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**구현**: `src/rpc/mining.cpp`

---

## 비활성화된 RPC

다음 PoW 전용 RPC는 PoCX 모드에서 **비활성화**됩니다:

### getnetworkhashps
- **이유**: 해시율이 용량 증명에 적용되지 않음
- **대안**: 네트워크 용량 추정은 `getdifficulty` 사용

### getmininginfo
- **이유**: PoW 전용 정보 반환
- **대안**: PoCX 전용 `get_mining_info` 사용

### generate, generatetoaddress, generatetodescriptor, generateblock
- **이유**: CPU 채굴이 PoCX에 적용되지 않음 (사전 생성된 플롯 필요)
- **대안**: 외부 플로터 + 마이너 + `submit_nonce` 사용

**구현**: `src/rpc/mining.cpp` (ENABLE_POCX 정의 시 RPC가 오류 반환)

---

## 통합 예제

### 외부 마이너 통합

**기본 채굴 루프**:
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

# 채굴 루프
while True:
    # 1. 채굴 매개변수 가져오기
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. 플롯 파일 스캔 (외부 구현)
    best_nonce = scan_plots(gen_sig, height)

    # 3. 최적의 솔루션 제출
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"솔루션 수락됨! 품질: {result['quality']}초, "
              f"포징 시간: {result['poc_time']}초")

    # 4. 다음 블록 대기
    time.sleep(10)  # 폴링 간격
```

---

### 풀 통합 패턴

**풀 서버 워크플로우**:
1. 마이너가 풀 주소에 포징 할당 생성
2. 풀이 포징 주소 키가 있는 지갑 실행
3. 풀이 `get_mining_info` 호출하고 마이너에게 배포
4. 마이너가 풀을 통해 솔루션 제출 (체인에 직접 아님)
5. 풀이 검증하고 풀의 키로 `submit_nonce` 호출
6. 풀이 풀 정책에 따라 보상 분배

**할당 관리**:
```bash
# 마이너가 할당 생성 (마이너 지갑에서)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# 활성화 대기 (메인넷 30 블록)

# 풀이 할당 상태 확인
bitcoin-cli get_assignment "pocx1qminer_plot..."

# 풀이 이제 이 플롯에 대해 논스 제출 가능
# (풀 지갑이 pocx1qpool... 개인키를 가지고 있어야 함)
```

---

### 블록 탐색기 조회

**PoCX 블록 데이터 조회**:
```bash
# 최신 블록 가져오기
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# PoCX 증명이 포함된 블록 세부사항 가져오기
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX 전용 필드 추출
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

**할당 트랜잭션 감지**:
```bash
# OP_RETURN 트랜잭션 스캔
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# 할당 마커 확인 (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## 오류 처리

### 일반적인 오류 패턴

**높이 불일치**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**해결책**: 채굴 정보 다시 가져오기, 체인이 앞으로 이동함

**생성 서명 불일치**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**해결책**: 채굴 정보 다시 가져오기, 새 블록 도착

**개인키 없음**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**해결책**: 플롯 또는 포징 주소의 키 가져오기

**할당 활성화 대기 중**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**해결책**: 활성화 지연 경과 대기

---

## 코드 참조

**채굴 RPC**: `src/pocx/rpc/mining.cpp`
**할당 RPC**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**블록체인 RPC**: `src/rpc/blockchain.cpp`
**증명 검증**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**할당 상태**: `src/pocx/assignments/assignment_state.cpp`
**트랜잭션 생성**: `src/pocx/assignments/transactions.cpp`

---

## 상호 참조

관련 장:
- [3장: 합의 및 채굴](3-consensus-and-mining.md) - 채굴 과정 세부사항
- [4장: 포징 할당](4-forging-assignments.md) - 할당 시스템 아키텍처
- [6장: 네트워크 매개변수](6-network-parameters.md) - 할당 지연 값
- [8장: 지갑 가이드](8-wallet-guide.md) - 할당 관리용 GUI

---

[<- 이전: 네트워크 매개변수](6-network-parameters.md) | [목차](index.md) | [다음: 지갑 가이드 ->](8-wallet-guide.md)

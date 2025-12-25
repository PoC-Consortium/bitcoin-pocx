[<- 이전: 시간 동기화](5-timing-security.md) | [목차](index.md) | [다음: RPC 참조 ->](7-rpc-reference.md)

---

# 6장: 네트워크 매개변수 및 구성

모든 네트워크 유형에 대한 Bitcoin-PoCX 네트워크 구성의 완전한 참조입니다.

---

## 목차

1. [제네시스 블록 매개변수](#제네시스-블록-매개변수)
2. [체인 매개변수 구성](#체인-매개변수-구성)
3. [합의 매개변수](#합의-매개변수)
4. [코인베이스 및 블록 보상](#코인베이스-및-블록-보상)
5. [동적 스케일링](#동적-스케일링)
6. [네트워크 구성](#네트워크-구성)
7. [데이터 디렉토리 구조](#데이터-디렉토리-구조)

---

## 제네시스 블록 매개변수

### 기본 목표 계산

**공식**: `genesis_base_target = 2^42 / block_time_seconds`

**근거**:
- 각 논스는 256 KiB를 나타냄 (64 바이트 × 4096 스쿱)
- 1 TiB = 2^22 논스 (시작 네트워크 용량 가정)
- n 논스에 대한 예상 최소 품질 ≈ 2^64 / n
- 1 TiB의 경우: E(quality) = 2^64 / 2^22 = 2^42
- 따라서: base_target = 2^42 / block_time

**계산된 값**:
- 메인넷/테스트넷/시그넷 (120초): `36650387592`
- Regtest (1초): 저용량 캘리브레이션 모드 사용

### 제네시스 메시지

모든 네트워크가 Bitcoin 제네시스 메시지를 공유합니다:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**구현**: `src/kernel/chainparams.cpp`

---

## 체인 매개변수 구성

### 메인넷 매개변수

**네트워크 식별**:
- **매직 바이트**: `0xa7 0x3c 0x91 0x5e`
- **기본 포트**: `8888`
- **Bech32 HRP**: `pocx`

**주소 접두사** (Base58):
- PUBKEY_ADDRESS: `85` (주소가 'P'로 시작)
- SCRIPT_ADDRESS: `90` (주소가 'R'로 시작)
- SECRET_KEY: `128`

**블록 타이밍**:
- **블록 시간 목표**: `120`초 (2분)
- **목표 시간 범위**: `1209600`초 (14일)
- **MAX_FUTURE_BLOCK_TIME**: `15`초

**블록 보상**:
- **초기 보조금**: `10 BTC`
- **반감 간격**: `1050000` 블록 (~4년)
- **반감 횟수**: 최대 64회

**난이도 조정**:
- **롤링 윈도우**: `24` 블록
- **조정**: 매 블록
- **알고리즘**: 지수 이동 평균

**할당 지연**:
- **활성화**: `30` 블록 (~1시간)
- **취소**: `720` 블록 (~24시간)

### 테스트넷 매개변수

**네트워크 식별**:
- **매직 바이트**: `0x6d 0xf2 0x48 0xb3`
- **기본 포트**: `18888`
- **Bech32 HRP**: `tpocx`

**주소 접두사** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**블록 타이밍**:
- **블록 시간 목표**: `120`초
- **MAX_FUTURE_BLOCK_TIME**: `15`초
- **최소 난이도 허용**: `true`

**블록 보상**:
- **초기 보조금**: `10 BTC`
- **반감 간격**: `1050000` 블록

**난이도 조정**:
- **롤링 윈도우**: `24` 블록

**할당 지연**:
- **활성화**: `30` 블록 (~1시간)
- **취소**: `720` 블록 (~24시간)

### Regtest 매개변수

**네트워크 식별**:
- **매직 바이트**: `0xfa 0xbf 0xb5 0xda`
- **기본 포트**: `18444`
- **Bech32 HRP**: `rpocx`

**주소 접두사** (Bitcoin 호환):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**블록 타이밍**:
- **블록 시간 목표**: `1`초 (테스트용 즉시 채굴)
- **목표 시간 범위**: `86400`초 (1일)
- **MAX_FUTURE_BLOCK_TIME**: `15`초

**블록 보상**:
- **초기 보조금**: `10 BTC`
- **반감 간격**: `500` 블록

**난이도 조정**:
- **롤링 윈도우**: `24` 블록
- **최소 난이도 허용**: `true`
- **재타겟팅 없음**: `true`
- **저용량 캘리브레이션**: `true` (1 TiB 대신 16-논스 캘리브레이션 사용)

**할당 지연**:
- **활성화**: `4` 블록 (~4초)
- **취소**: `8` 블록 (~8초)

### 시그넷 매개변수

**네트워크 식별**:
- **매직 바이트**: SHA256d(signet_challenge)의 처음 4바이트
- **기본 포트**: `38333`
- **Bech32 HRP**: `tpocx`

**블록 타이밍**:
- **블록 시간 목표**: `120`초
- **MAX_FUTURE_BLOCK_TIME**: `15`초

**블록 보상**:
- **초기 보조금**: `10 BTC`
- **반감 간격**: `1050000` 블록

**난이도 조정**:
- **롤링 윈도우**: `24` 블록

---

## 합의 매개변수

### 타이밍 매개변수

**MAX_FUTURE_BLOCK_TIME**: `15`초
- PoCX 전용 (Bitcoin은 2시간 사용)
- 근거: PoC 타이밍은 거의 실시간 검증 필요
- 15초 이상 미래의 블록은 거부됨

**시간 오프셋 경고**: `10`초
- 노드 시계가 네트워크 시간에서 10초 이상 벗어나면 운영자에게 경고
- 강제 없음, 정보 제공용

**블록 시간 목표**:
- 메인넷/테스트넷/시그넷: `120`초
- Regtest: `1`초

**TIMESTAMP_WINDOW**: `15`초 (MAX_FUTURE_BLOCK_TIME과 동일)

**구현**: `src/chain.h`, `src/validation.cpp`

### 난이도 조정 매개변수

**롤링 윈도우 크기**: `24` 블록 (모든 네트워크)
- 최근 블록 시간의 지수 이동 평균
- 매 블록 조정
- 용량 변화에 대응

**구현**: `src/consensus/params.h`, 블록 생성의 난이도 로직

### 할당 시스템 매개변수

**nForgingAssignmentDelay** (활성화 지연):
- 메인넷: `30` 블록 (~1시간)
- 테스트넷: `30` 블록 (~1시간)
- Regtest: `4` 블록 (~4초)

**nForgingRevocationDelay** (취소 지연):
- 메인넷: `720` 블록 (~24시간)
- 테스트넷: `720` 블록 (~24시간)
- Regtest: `8` 블록 (~8초)

**근거**:
- 활성화 지연은 블록 경쟁 중 빠른 재할당 방지
- 취소 지연은 안정성 제공 및 남용 방지

**구현**: `src/consensus/params.h`

---

## 코인베이스 및 블록 보상

### 블록 보조금 일정

**초기 보조금**: `10 BTC` (모든 네트워크)

**반감 일정**:
- `1050000` 블록마다 (메인넷/테스트넷)
- `500` 블록마다 (regtest)
- 최대 64회 반감까지 계속

**반감 진행**:
```
반감 0: 10.00000000 BTC  (블록 0 - 1049999)
반감 1:  5.00000000 BTC  (블록 1050000 - 2099999)
반감 2:  2.50000000 BTC  (블록 2100000 - 3149999)
반감 3:  1.25000000 BTC  (블록 3150000 - 4199999)
...
```

**총 공급량**: ~2,100만 BTC (Bitcoin과 동일)

### 코인베이스 출력 규칙

**지급 대상**:
- **할당 없음**: 코인베이스가 플롯 주소(proof.account_id)에 지급
- **할당 있음**: 코인베이스가 포징 주소(유효 서명자)에 지급

**출력 형식**: P2WPKH만
- 코인베이스는 bech32 SegWit v0 주소에 지급해야 함
- 유효 서명자의 공개키에서 생성됨

**할당 해결**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**구현**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## 동적 스케일링

### 스케일링 범위

**목적**: 네트워크 성숙에 따라 용량 인플레이션을 방지하기 위해 플롯 생성 난이도 증가

**구조**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // 허용되는 최소 레벨
    uint8_t nPoCXTargetCompression;  // 권장 레벨
};
```

**관계**: `target = min + 1` (항상 최소보다 한 레벨 위)

### 스케일링 증가 일정

스케일링 레벨은 반감 간격에 따른 **지수 일정**에 따라 증가합니다:

| 기간 | 블록 높이 | 반감 횟수 | 최소 | 목표 |
|------|-----------|----------|------|------|
| 년차 0-4 | 0 ~ 1049999 | 0 | X1 | X2 |
| 년차 4-12 | 1050000 ~ 3149999 | 1-2 | X2 | X3 |
| 년차 12-28 | 3150000 ~ 7349999 | 3-6 | X3 | X4 |
| 년차 28-60 | 7350000 ~ 15749999 | 7-14 | X4 | X5 |
| 년차 60-124 | 15750000 ~ 32549999 | 15-30 | X5 | X6 |
| 년차 124+ | 32550000+ | 31+ | X6 | X7 |

**주요 높이** (년차 -> 반감 횟수 -> 블록):
- 년차 4: 반감 1, 블록 1050000
- 년차 12: 반감 3, 블록 3150000
- 년차 28: 반감 7, 블록 7350000
- 년차 60: 반감 15, 블록 15750000
- 년차 124: 반감 31, 블록 32550000

### 스케일링 레벨 난이도

**PoW 스케일링**:
- 스케일링 레벨 X0: POC2 기준선 (이론적)
- 스케일링 레벨 X1: XOR-전치 기준선
- 스케일링 레벨 Xn: 2^(n-1) × X1 작업 내장
- 각 레벨이 플롯 생성 작업을 두 배로 증가

**경제적 정렬**:
- 블록 보상 반감 -> 플롯 생성 난이도 증가
- 안전 마진 유지: 플롯 생성 비용 > 조회 비용
- 하드웨어 개선으로 인한 용량 인플레이션 방지

### 플롯 검증

**검증 규칙**:
- 제출된 증명은 스케일링 레벨 >= 최소여야 함
- 목표보다 높은 스케일링의 증명은 허용되나 비효율적
- 최소 미만의 증명: 거부됨 (불충분한 PoW)

**범위 조회**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**구현**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## 네트워크 구성

### 시드 노드 및 DNS 시드

**상태**: 메인넷 출시를 위한 플레이스홀더

**계획된 구성**:
- 시드 노드: 미정
- DNS 시드: 미정

**현재 상태** (테스트넷/regtest):
- 전용 시드 인프라 없음
- `-addnode`를 통한 수동 피어 연결 지원

**구현**: `src/kernel/chainparams.cpp`

### 체크포인트

**제네시스 체크포인트**: 항상 블록 0

**추가 체크포인트**: 현재 구성되지 않음

**향후**: 메인넷 진행에 따라 체크포인트 추가 예정

---

## P2P 프로토콜 구성

### 프로토콜 버전

**기반**: Bitcoin Core v30.0 프로토콜
- **프로토콜 버전**: Bitcoin Core에서 상속
- **서비스 비트**: 표준 Bitcoin 서비스
- **메시지 유형**: 표준 Bitcoin P2P 메시지

**PoCX 확장**:
- 블록 헤더에 PoCX 전용 필드 포함
- 블록 메시지에 PoCX 증명 데이터 포함
- 검증 규칙이 PoCX 합의 강제

**호환성**: PoCX 노드는 Bitcoin PoW 노드와 호환되지 않음 (다른 합의)

**구현**: `src/protocol.h`, `src/net_processing.cpp`

---

## 데이터 디렉토리 구조

### 기본 디렉토리

**위치**: `.bitcoin/` (Bitcoin Core와 동일)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### 디렉토리 내용

```
.bitcoin/
├── blocks/              # 블록 데이터
│   ├── blk*.dat        # 블록 파일
│   ├── rev*.dat        # 실행 취소 데이터
│   └── index/          # 블록 인덱스 (LevelDB)
├── chainstate/         # UTXO 세트 + 포징 할당 (LevelDB)
├── wallets/            # 지갑 파일
│   └── wallet.dat      # 기본 지갑
├── bitcoin.conf        # 구성 파일
├── debug.log           # 디버그 로그
├── peers.dat           # 피어 주소
├── mempool.dat         # 멤풀 지속성
└── banlist.dat         # 차단된 피어
```

### Bitcoin과의 주요 차이점

**Chainstate 데이터베이스**:
- 표준: UTXO 세트
- **PoCX 추가**: 포징 할당 상태
- 원자적 업데이트: UTXO + 할당이 함께 업데이트됨
- 할당을 위한 재구성 안전 실행 취소 데이터

**블록 파일**:
- 표준 Bitcoin 블록 형식
- **PoCX 추가**: PoCX 증명 필드로 확장 (account_id, seed, nonce, signature, pubkey)

### 구성 파일 예시

**bitcoin.conf**:
```ini
# 네트워크 선택
#testnet=1
#regtest=1

# PoCX 채굴 서버 (외부 마이너에 필요)
miningserver=1

# RPC 설정
server=1
rpcuser=yourusername
rpcpassword=yourpassword
rpcallowip=127.0.0.1
rpcport=8332

# 연결 설정
listen=1
port=8888
maxconnections=125

# 블록 시간 목표 (정보 제공용, 합의에서 강제)
# 메인넷/테스트넷에서 120초
```

---

## 코드 참조

**체인 매개변수**: `src/kernel/chainparams.cpp`
**합의 매개변수**: `src/consensus/params.h`
**압축 범위**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**제네시스 기본 목표 계산**: `src/pocx/consensus/params.cpp`
**코인베이스 지급 로직**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**할당 상태 저장**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache 확장)

---

## 상호 참조

관련 장:
- [2장: 플롯 형식](2-plot-format.md) - 플롯 생성의 스케일링 레벨
- [3장: 합의 및 채굴](3-consensus-and-mining.md) - 스케일링 검증, 할당 시스템
- [4장: 포징 할당](4-forging-assignments.md) - 할당 지연 매개변수
- [5장: 타이밍 보안](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME 근거

---

[<- 이전: 시간 동기화](5-timing-security.md) | [목차](index.md) | [다음: RPC 참조 ->](7-rpc-reference.md)

# Bitcoin-PoCX 기술 문서

**버전**: 1.0
**Bitcoin Core 기반**: v30.0
**상태**: 테스트넷 단계
**최종 업데이트**: 2025-12-25

---

## 이 문서에 대하여

이 문서는 Bitcoin-PoCX의 완전한 기술 문서입니다. Bitcoin-PoCX는 차세대 용량 증명(Proof of Capacity neXt generation, PoCX) 합의 메커니즘을 지원하는 Bitcoin Core 통합 프로젝트입니다. 이 문서는 시스템의 모든 측면을 다루는 상호 연결된 장들로 구성된 탐색 가능한 가이드 형태로 작성되었습니다.

**대상 독자**:
- **노드 운영자**: 1장, 5장, 6장, 8장
- **채굴자**: 2장, 3장, 7장
- **개발자**: 전체 장
- **연구자**: 3장, 4장, 5장

번역본: [영어 (원본)](../../index.md)

---

## 목차

### 제1부: 기초

**[1장: 개요 및 소개](1-introduction.md)**
프로젝트 개요, 아키텍처, 설계 철학, 핵심 기능 및 PoCX와 작업 증명의 차이점.

**[2장: 플롯 파일 형식](2-plot-format.md)**
SIMD 최적화, 작업 증명 스케일링, POC1/POC2로부터의 형식 발전을 포함한 PoCX 플롯 형식의 완전한 사양.

**[3장: 합의 및 채굴](3-consensus-and-mining.md)**
PoCX 합의 메커니즘의 완전한 기술 사양: 블록 구조, 생성 서명, 기본 목표 조정, 채굴 과정, 검증 파이프라인 및 시간 왜곡 알고리즘.

---

### 제2부: 고급 기능

**[4장: 포징 할당 시스템](4-forging-assignments.md)**
포징 권한 위임을 위한 OP_RETURN 전용 아키텍처: 트랜잭션 구조, 데이터베이스 설계, 상태 머신, 재구성 처리 및 RPC 인터페이스.

**[5장: 시간 동기화 및 보안](5-timing-security.md)**
시계 오차 허용, 방어적 포징 메커니즘, 시계 조작 방지 및 시간 관련 보안 고려사항.

**[6장: 네트워크 매개변수](6-network-parameters.md)**
체인 매개변수 구성, 제네시스 블록, 합의 매개변수, 코인베이스 규칙, 동적 스케일링 및 경제 모델.

---

### 제3부: 사용법 및 통합

**[7장: RPC 인터페이스 참조](7-rpc-reference.md)**
채굴, 할당 및 블록체인 조회를 위한 완전한 RPC 명령어 참조. 채굴자 및 풀 통합에 필수적입니다.

**[8장: 지갑 및 GUI 가이드](8-wallet-guide.md)**
Bitcoin-PoCX Qt 지갑 사용자 가이드: 포징 할당 대화상자, 트랜잭션 내역, 채굴 설정 및 문제 해결.

---

## 빠른 탐색

### 노드 운영자를 위한 안내
-> [1장: 소개](1-introduction.md)부터 시작하세요
-> 그 다음 [6장: 네트워크 매개변수](6-network-parameters.md)를 검토하세요
-> [8장: 지갑 가이드](8-wallet-guide.md)로 채굴을 구성하세요

### 채굴자를 위한 안내
-> [2장: 플롯 형식](2-plot-format.md)을 이해하세요
-> [3장: 합의 및 채굴](3-consensus-and-mining.md)에서 과정을 배우세요
-> [7장: RPC 참조](7-rpc-reference.md)를 사용하여 통합하세요

### 풀 운영자를 위한 안내
-> [4장: 포징 할당](4-forging-assignments.md)을 검토하세요
-> [7장: RPC 참조](7-rpc-reference.md)를 학습하세요
-> 할당 RPC와 submit_nonce를 사용하여 구현하세요

### 개발자를 위한 안내
-> 모든 장을 순서대로 읽으세요
-> 문서 전체에 표시된 구현 파일을 참조하세요
-> `src/pocx/` 디렉토리 구조를 확인하세요
-> [GUIX](../bitcoin/contrib/guix/README.md)로 릴리스를 빌드하세요

---

## 문서 규칙

**파일 참조**: 구현 세부 사항은 `경로/파일.cpp:줄번호` 형식으로 소스 파일을 참조합니다

**코드 통합**: 모든 변경 사항은 `#ifdef ENABLE_POCX`로 기능 플래그 처리되어 있습니다

**상호 참조**: 장들은 상대적 마크다운 링크를 사용하여 관련 섹션을 연결합니다

**기술 수준**: 이 문서는 Bitcoin Core 및 C++ 개발에 대한 이해를 전제로 합니다

---

## 빌드

### 개발 빌드

```bash
# 서브모듈과 함께 클론
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# PoCX 활성화하여 구성
cmake -B build -DENABLE_POCX=ON

# 빌드
cmake --build build -j$(nproc)
```

**빌드 변형**:
```bash
# Qt GUI 포함
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# 디버그 빌드
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**의존성**: 표준 Bitcoin Core 빌드 의존성이 필요합니다. 플랫폼별 요구사항은 [Bitcoin Core 빌드 문서](https://github.com/bitcoin/bitcoin/tree/master/doc#building)를 참조하세요.

### 릴리스 빌드

재현 가능한 릴리스 바이너리를 위해서는 GUIX 빌드 시스템을 사용하세요: [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md) 참조

---

## 추가 자료

**저장소**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX 코어 프레임워크**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**관련 프로젝트**:
- 플로터: [engraver](https://github.com/PoC-Consortium/engraver) 기반
- 마이너: [scavenger](https://github.com/PoC-Consortium/scavenger) 기반

---

## 이 문서를 읽는 방법

**순차적 읽기**: 각 장은 이전 개념을 기반으로 순서대로 읽도록 설계되었습니다.

**참조용 읽기**: 목차를 사용하여 특정 주제로 직접 이동하세요. 각 장은 관련 자료에 대한 상호 참조와 함께 독립적으로 구성되어 있습니다.

**브라우저 탐색**: 마크다운 뷰어나 브라우저에서 `index.md`를 여세요. 모든 내부 링크는 상대 경로이며 오프라인에서도 작동합니다.

**PDF 내보내기**: 이 문서는 오프라인 읽기를 위해 단일 PDF로 연결할 수 있습니다.

---

## 프로젝트 상태

**기능 완료**: 모든 합의 규칙, 채굴, 할당 및 지갑 기능이 구현되었습니다.

**문서 완료**: 8개의 모든 장이 완성되었으며 코드베이스와 검증되었습니다.

**테스트넷 활성화**: 현재 커뮤니티 테스트를 위한 테스트넷 단계에 있습니다.

---

## 기여

문서에 대한 기여를 환영합니다. 다음 사항을 준수해 주세요:
- 장황함보다 기술적 정확성 우선
- 간결하고 핵심적인 설명
- 문서에 코드나 의사 코드 없음 (대신 소스 파일 참조)
- 구현된 내용만 (추측성 기능 제외)

---

## 라이선스

Bitcoin-PoCX는 Bitcoin Core의 MIT 라이선스를 상속합니다. 저장소 루트의 `COPYING`을 참조하세요.

PoCX 코어 프레임워크 저작자 표시는 [2장: 플롯 형식](2-plot-format.md)에 문서화되어 있습니다.

---

**읽기 시작**: [1장: 소개 및 개요 ->](1-introduction.md)

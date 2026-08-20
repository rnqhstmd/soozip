---
phase: setup
status: in_progress
pipeline: gx-tdd
verify-status: passed
verify-fingerprint: "9845830:fac0c7b2ce15"
model-profile: standard
mode: all
intent-source: natural-language
vcs-type: git
branch: feat/editor-boundary
base: main
project-type: swift-ios
project-root: ./
args: "EDITOR-9 경계 — 캔버스 밖 클리핑·복원, 고스트 판정(30%), 레이어 중심이 작업 영역(캔버스 2배) 밖 금지"
flags: ""
started: 2026-08-20T13:20:00
last-known-head: 9845830ed87db2ebe9a13dfc5d748522611cb5df
config-setup-attempts: 0
auto-stashed: false
warnings-baseline: 0
baseline-tests: "SoozipGeometry 168 / SoozipLayout 95 / SoozipDraft 26 / app 169, 릴리스 빌드 성공"
current-step: "review 완료 (2회차) — complete 진입"
phases:
  setup: completed
  requirements: completed
  design: completed
  implement: completed
  review: completed
  complete: pending
steps:
  requirements:
    - PRD 작성: completed
    - G-W-T 게이트: completed
  design:
    - architect 설계: completed
    - design-critic 비판: completed
    - test-architect testability: completed
  implement:
    - 기준선 게이트: completed
    - 태스크 분해: completed
    - "RGR T1 (겹침 3분류, AC 1~11·17·18·20·21·22)":
        red: completed
        test-file-hash: 6e137ae8d66f5205ff9da70a9356ce3c916eb75f
        test-count: 184
        green: completed
        refactor: completed
    - "RGR T2 (중심 클램프, AC 12~16·19)":
        red: completed
        test-file-hash: e5df2a2cfc1dbb54c59dc7a399a36190e701babf
        test-count: 190
        green: completed
        refactor: "skipped (정리 대상 없음)"
    - 가시성 변경(clampedToWorkArea public 제거): completed
    - 변경사항 수집: completed
  review:
    - mechanical-gate (build + test): completed
    - spec-review: completed
    - quality-review + security: in_progress
execution-log:
  - phase: setup
    result: "브랜치 feat/editor-boundary 생성(base main@9845830). 스킬 규칙상 이슈 키 EDITOR-9가 브랜치명이 되지만 저장소 14개 단위 전부 feat/… 규약이고 gx-commit 타입 파싱이 접두사를 요구해 feat/editor-boundary 채택"
  - phase: setup
    result: "자동 stash 1건(로드맵 문서 수정) — 브랜치 전환 후 pop 성공, 워킹트리에 그대로 유지"
  - phase: setup
    result: "코드 맵 생성. workArea·clampedToWorkArea가 CanvasSurface.swift:70-88에 이미 있고 doc이 EDITOR-9의 재사용을 명시"
  - phase: requirements
    agent: product-owner
    result: "PRD 1라운드. 질문 0건으로 냈으나 오케스트레이터 검증에서 결정 분기 2건·보강 4건 발견"
  - phase: requirements
    result: "수치 주장 전부 Python 독립 재계산 — 거짓 0건. AC-4 코너 4점·AC-5 관통 성립·workArea(-540,-675)~(1620,2025)·clampedToWorkArea(inf)=1620·(NaN)=NaN 확인"
  - phase: requirements
    result: "사용자 결정 2건 — 비유한 center는 canvasCenter 후퇴(FR-4 변경) / AC-11 무효 단언 삭제 후 BR-1 주석으로 이전"
  - phase: requirements
    result: "오케스트레이터 보강 4건 — 한 점 접촉 AC 신설+BR-6 / AC-10을 3축 3입력으로 확장 / AC-13을 코너 무시 판정력 있는 형태로 재설계 / AC-14 y성분 약한 증인 교체 + NaN AC-15 신설"
  - phase: design
    agent: architect
    result: "중형. SAT 4축 + 캔버스축 포함 판정. 수치 주장 전수 재계산 — 실질 거짓 0건, 라벨 오류 1건(overlaps 부등호 서수)·환경 주장 거짓 1건(브랜치)"
  - phase: design
    agent: design-critic
    result: "MUST-ADDRESS 6건 전부 사실 확인 후 반영. 캔버스 치수 가드 누락 / .partial 넓이 계약 / 회전오차 근거 무효 / 두 클램프 시그니처 동일 / AC-13 무효화 / ResizeAnchor 인계 미수신"
  - phase: design
    agent: test-architect
    gate: testability
    result: "9/10 TESTABILITY PASS. 설계 변경 요구 0건. y축 무증인 신고는 타당했으나 제시 입력은 회전 0이라 판정력 없음(C_v 값 오전재) — 오케스트레이터가 재탐색해 x축도 무증인임을 발견"
  - phase: design
    result: "변이 킬셋 최종 실측 — 9종 전부 증인 확보. 레이어 축 유한성 가드만 원리적 무증인(Swift 5입력 확인)"
  - phase: implement
    result: "RGR T1 — RED(16테스트, 격리 오염 0건) → GREEN(184통과, 회귀 0) → REFACTOR(주석 3건 정정, 실행코드 diff 0줄)"
  - phase: implement
    result: "T1 REFACTOR에서 사실 오류 1건 정정 — 설계서·PRD·doc 3곳이 '레이어 유한성 가드는 무증인'이라 했으나 실제 코드 변이 측정에서 증인 있음 확인. reduce(±무한대) 씨앗값이 전부-NaN 투영을 뒤집힌 빈 구간으로 만들어 contains가 공허하게 참이 되고 inside가 나온다"
  - phase: implement
    result: "RGR T2 — RED(6테스트) → GREEN(190통과, 회귀 0) → REFACTOR skipped(정리 대상 0건)"
  - phase: implement
    result: "가시성 변경(오케스트레이터 직접): clampedToWorkArea에서 public 제거. 패키지 밖 소비자 0건 확인, 190통과 유지"
  - phase: implement
    result: "변이 킬셋 실제 swift test로 측정 — 16종 전부 증인 확보"
  - phase: review
    step: mechanical-gate
    result: "build 성공 · test 190 통과 · 경고 0"
  - phase: review
    agent: spec-reviewer
    result: "1차 SPEC FAIL(BR-1 프로덕션 주석 누락) → 주석 추가 후 재검증 SPEC PASS. AC 22/22, BR 7/7"
  - phase: review
    result: "spec-reviewer가 오케스트레이터 오기 1건 적발 — design.md의 '22건 → 20 @Test' (실제 22개). 정정함"
  - phase: review
    result: "설계 범위 이탈 1건 기록 — docs/plans 로드맵 수정은 이 단위 착수 직전 별건 요청분이며 코드 아님"
  - phase: requirements
    gate: G-W-T
    result: "PASS — 16/16. 1차 게이트 파서가 0건 파싱 후 PASS를 내는 무효 통과였고, 선언수==파싱수 어서션을 넣어 재실행"
---

# EDITOR-9 — 캔버스 경계와 레이어 이탈

## 이 단위의 입력 계약

- **`CanvasSurface.workArea`를 재정의하지 않는다.** 이미 공개돼 있고 doc이 EDITOR-9를 지목한다.
- 순수 로직. `SoozipGeometry`(Foundation only)에 들어간다.
- 설계 SSOT: v4 §5.10.

## 미해소 쟁점 (requirements에서 확정)

1. **"고스트 판정(30%)"의 30%가 무엇인가** — v4 원문상 불투명도이지 판정 임계가 아니다. 렌더 상수라면 EDITOR-9 범위 밖이다.
2. **회전 레이어의 캔버스 교차 판정** — `corner(_:)` 4점을 쓰는가, 별도 판정인가. SnapEngine의 AABB는 회전체에 못 쓴다.
3. **중심 클램프의 적용 지점** — `LayerFrame`이 스스로 클램프하는가, 호출부가 거치는가(EDITOR-7 `resizeLimits`는 후자였고 "타입이 강제하지 않는다"가 이월 항목으로 남았다).

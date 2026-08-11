---
phase: complete
status: completed
pipeline: gx-tdd
verify-status: passed
verify-fingerprint: "fb8e421:13dd06801de4"
model-profile: standard
mode: core
intent-source: user-selection
vcs-type: git
branch: feat/editor-layer-store
base: main
project-type: swift-ios
project-root: ./
args: "editor2 시작"
flags: --core
started: 2026-08-12T00:10:00
last-known-head: fb8e421
phases:
  setup: completed
  requirements: completed
  implement: completed
  complete: completed
steps:
  implement:
    - "RGR T1 (EDITOR-2 AC-1~13)":
        red: completed
        green: completed
        refactor: skipped
execution-log:
  - phase: requirements
    gate: G-W-T
    result: "PASS — AC-1~13 전부 Given-When-Then"
  - phase: implement
    agent: red-writer (T1)
    result: "테스트 13건 작성. LayerStore 부재로 컴파일 실패 — RED"
  - phase: implement
    agent: green-coder (T1)
    result: "LayerStore + Layer.transform setter. SoozipLayout 40 → 53"
  - phase: implement
    gate: 변이 검증 9종
    result: "8종 잡힘. A(안정 정렬 2차 키)는 stdlib이 이미 안정적이라 행위로 관찰 불가 — 원장에 기록"
  - phase: complete
    gate: verify
    result: "패키지 129 + 앱 169 = 298 통과, Release 빌드 성공"
---

# EDITOR-2 — 레이어 스토어

## 설계 핵심

**배열 순서가 진실이고 z는 인덱스에서 파생된다.** v4 §5.11의 "0부터 촘촘히
재정렬"이 지켜야 할 규칙이 아니라 **깨질 수 없는 성질**이 된다 — 재번호 코드가
아예 없다.

식별자는 **세션 한정**이다. `layoutJSON`에 레이어 id가 없고, `assetId`는
복제본끼리 공유해 키가 될 수 없다.

## 결과

- `SoozipLayout` 40 → **53**, 전체 285 → **298**
- `Layer.transform`에 setter 추가 (v4 §5.2의 "5종 동일 경로"를 코드로)
- 변이 9종 중 8종 잡힘

## 다음

`EDITOR-3`(타입별 상한) 또는 `EDITOR-4`(선택 상태).

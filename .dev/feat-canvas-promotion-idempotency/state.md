---
phase: complete
status: completed
pipeline: gx-tdd
verify-status: passed
verify-fingerprint: "425c100:c58ad4d7e466"
model-profile: standard
mode: core
intent-source: user-selection
vcs-type: git
branch: feat/canvas-promotion-idempotency
base: main
project-type: swift-ios
project-root: ./
args: "무결성 감사 [MEDIUM] 후속 — 멱등성 가드"
flags: --core
started: 2026-08-11T14:25:00
last-known-head: 425c100
phases:
  setup: completed
  requirements: completed
  implement: completed
  complete: completed
steps:
  implement:
    - "RGR T1 (CANVAS-3b AC-1·2·3)":
        red: completed
        green: completed
        refactor: skipped
execution-log:
  - phase: requirements
    gate: G-W-T
    result: "PASS — AC-1·2·3 전부 Given-When-Then"
  - phase: implement
    agent: red-writer (T1)
    result: "재승격 거부 3건 작성. alreadyPromoted 부재로 컴파일 실패 — RED"
  - phase: implement
    agent: green-coder (T1)
    result: "alreadyPromoted 케이스 + canvasExists 가드. 261개 통과"
  - phase: implement
    gate: 변이 검증
    result: "가드 제거 → 3건만 실패 / 렌더 뒤로 이동 → 순서 테스트 1건만 실패"
  - phase: complete
    gate: verify
    result: "패키지 92 + 앱 169 = 261 통과, Release 빌드 성공"
---

# CANVAS-3b — 승격 멱등성 가드

## 무엇이었나

무결성 감사가 찾은 [MEDIUM]. `@Attribute(.unique)`를 못 쓰는데(CloudKit 제약)
`promote()`에 존재 확인이 없어, 정리 실패로 초안이 남은 뒤 재승격하면 같은
`id`의 레코드가 둘 생겼다.

## 결과

- 테스트 258 → **261**
- `PromotionError.alreadyPromoted(canvasID:)` 추가
- 가드를 **렌더보다 먼저** 배치 (변이로 순서까지 검증)
- 로드맵의 ⚠️ 배선 전 처리 항목 중 하나 해소

## 남은 것

같은 감사의 [HIGH] — `createCanvas` 자체 실패의 보상. `save` 실패 주입 수단이
없어 `CANVAS-10` 배선 때 이음매와 함께 처리한다. 로드맵 ⚠️ 표에 남아 있다.

## 다음

`EDITOR-1`(캔버스 표면).

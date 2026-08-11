---
phase: complete
status: completed
pipeline: gx-tdd
verify-status: passed
verify-fingerprint: "5c8fb11:c318fd2c487e"
model-profile: standard
mode: core
intent-source: user-selection
vcs-type: git
branch: feat/editor-canvas-surface
base: main
project-type: swift-ios
project-root: ./
args: "editor1 시작"
flags: --core
started: 2026-08-11T14:40:00
last-known-head: 5c8fb11
phases:
  setup: completed
  requirements: completed
  implement: completed
  complete: completed
steps:
  implement:
    - "RGR T1 (EDITOR-1 AC-1~14)":
        red: completed
        green: completed
        refactor: skipped
execution-log:
  - phase: requirements
    gate: G-W-T
    result: "PASS — AC-1~14 전부 Given-When-Then. 팬 오프셋 해석은 ac.md에 명시"
  - phase: implement
    agent: red-writer (T1)
    result: "테스트 14건 작성. CanvasSurface 부재로 컴파일 실패 — RED"
  - phase: implement
    agent: green-coder (T1)
    result: "CanvasSurface 구현. SoozipGeometry 26 → 40 통과"
  - phase: implement
    gate: 변이 검증 1차 (A~F)
    result: "6종 전부 잡힘"
  - phase: implement
    gate: 변이 검증 2차 (G~I)
    result: "G(변환이 zoom 무시)를 아무도 못 잡음 — 테스트 추가 후 재검 통과. 41개"
  - phase: complete
    gate: verify
    result: "패키지 107 + 앱 169 = 276 통과, Release 빌드 성공"
---

# EDITOR-1 — 캔버스 표면

## 설계 핵심

**배율·뷰포트에 독립인 것만 저장한다.**

| 저장 | 파생 |
|---|---|
| `zoom` — fit 대비 배수 | `fitScale`, `scale` |
| `center` — 뷰포트 중앙에 오는 논리 지점 | 화면 오프셋 |

결과로 `viewportChanged`(기기 회전)가 **아무 계산도 하지 않는다.** 두 값을 그대로
넘기면 `fitScale`만 새 뷰포트로 다시 계산된다. 회전 관련 AC 4건이 전부 이
성질에서 나온다.

## 구현 중 발견

**변이 검증 2차에서 구멍이 하나 나왔다.** 변환이 `scale` 대신 `fitScale`을 쓰도록
바꾸면 `zoom`이 죽은 숫자가 되고 확대가 아예 동작하지 않는데, **당시 14개가
전부 초록이었다.** 왕복 항등·중앙 보존 같은 불변량은 배율에 무관해서 양쪽이 같이
틀리면 성립한다. 화면 **거리**를 재는 테스트를 추가해 막았다.

자세한 것은 `trust-ledger.md`.

## 결과

- `SoozipGeometry` 26 → **41**, 전체 261 → **276**
- 변이 9종 전부 잡힘

## 다음

`EDITOR-2`(레이어 스토어) — 의존 없음. `EDITOR-3·4`가 그 위에 얹힌다.

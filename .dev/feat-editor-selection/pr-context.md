# Background

`EDITOR-4` — 선택 상태 + 바운딩 박스 (v4 §5.7 · §5.11)

## 왜 필요했나

`EDITOR-1`(캔버스 표면)·`2`(레이어 스토어)·`3`(타입별 상한)이 끝나 있었지만, **레이어 하나를 조작 대상으로 지목하는 개념 자체가 없었다.** 선택이 없으면 이동·크기·회전·삭제가 어느 레이어에 적용될지 정할 방법이 없어 `EDITOR-5`·`6`·`7`·`8`이 전부 착수 불가였다.

두 가지 빚도 함께 있었다.

- `ResizeAnchor.resized(draggingEdge:)`가 레이어 타입을 전혀 보지 않아 **`photo`도 한 축 리사이즈가 됐다.** "사진을 한 축으로 늘이면 얼굴이 찌그러진다"(v4 §5.7)는 정책이 코드 어디에도 없었다.
- `LayerStore`의 주석이 이 단위를 미리 경고해 뒀다 — "낡은 z를 보면 맨 아래 레이어를 최상단으로 고른다", "선택된 레이어가 다른 경로로 지워진 뒤 속성바 버튼이 눌리는 경합이 실제로 있다".

## 무엇을 했나

**선택은 파생으로 만들었다.** `UUID`를 들되 조회는 `entries`를 거친다. 저장소에 없는 id는 `nil`로 풀리므로 "선택된 레이어가 삭제되면 선택이 해제된다"가 **지켜야 할 규칙이 아니라 성립할 수밖에 없는 성질**이 된다 — z를 필드로 들지 않고 인덱스에서 파생시킨 것과 같은 원리다.

**종류별 변 핸들 규칙을 `LayerKind.resizableEdges`에 세웠다.** `photo`·`stamp`·`drawing`은 비어 있고, `text`는 좌우만, `shape`는 네 변 전부. 다만 이것은 **종류 축의 문지기일 뿐**이며 `EDITOR-6`이 크기 축 필터(88pt/56pt)를 `HandlePlacement.init`에 얹는다.

**`HandlePlacement`는 화면 좌표를 낸다.** `SelectionOverlay`가 화면 좌표계에 살고(v4 §5.9), 논리좌표로 내면 28pt 오프셋이 두 표현으로 존재하게 된다. 핸들 순서를 `orderedHandles`로 명시하는 이유는 삭제가 좌상단 코너와 **정확히 같은 지점**이라 딕셔너리로는 히트 우선순위를 표현할 수 없기 때문이다.

## 확정된 결정 5건

| # | 결정 |
|---|---|
| 1 | 탭 지점 → 대상 레이어 히트 판정은 **제외** (`EDITOR-10`·`11`) |
| 2 | 삭제 버튼 = **좌상단 코너와 동일 지점** (스펙에 오프셋 수치가 없어 임의 값을 지어내지 않음) |
| 3 | 뒤집기 기준점 = **로컬 상단 중앙을 회전 변환한 지점** (재는 자리와 놓는 자리 일치) |
| 4 | 뒤집기 기준선 = **뷰포트 상단** (v4 §5.7 문면은 "캔버스 상단"이나 줌+팬에서 목적과 갈라짐 — 설계서에 각주 추가) |
| 5 | `resizableEdges` = **종류 축 문지기로 한정** (`EDITOR-6`이 크기 축을 얹음) |

## 검증

- **363개 전체 통과, 0 실패** (SoozipGeometry 74 · SoozipLayout 94 · SoozipDraft 26 · 앱 타깃 169) — 기준선 319 + 신규 44
- Release 빌드 성공 · **신규 경고 0건**(baseline 1건 대비)
- RGR **4사이클** (T1 선택 상태 · T2 핸들 배치 · T3 종류별 규칙 · T4 리뷰 지적 결함)
- spec-reviewer **SPEC PASS 15/15** · quality-reviewer **QUALITY PASS**(Critical 0 · Important 0)

## Audit Summary

- 총 12건 (CRITICAL: 0, HIGH: 0, MEDIUM: 3, Minor: 9)
- **[해소] 뒤집기가 회전 90°~270°에서 역효과** — `up = (sin r, −cos r)`가 레이어와 함께 회전하는데 판정은 `up`이 화면 위를 향한다고 가정. `r = π`에서 뒤집으면 회전 핸들이 화면 밖(`y = −38`). AC 14건이 전부 회전 0이거나 `up.y = 0`인 π/2라 어느 테스트에도 안 걸렸다 → `up.y <= 0` 게이트 추가 + AC-15/BR-6 신설
- **[해소] `select` 주석이 실제 의미와 불일치** — `move`는 상태를 보존하나 `select`는 기존 선택을 지운다. 특성화 테스트로 고정
- **[MEDIUM · `EDITOR-7`로 이월] 사진 왜곡 방지가 컴파일러가 아니라 규율 수준** — `resized(draggingEdge:)`와 `HandlePlacement.init`이 둘 다 `public`이라 배치를 우회할 수 있다. 현재 호출부 0건이라 도달 불가하나 `EDITOR-7` 착수 시 닫아야 한다
- **[MEDIUM · 선행 과제] `LayerStore`에 레이어 갱신 경로가 없다** — mutating API가 `select`/`deselect`/`insert`/`remove`/z-order 4종뿐. **`EDITOR-7`·`EDITOR-8`이 계산한 새 프레임을 되쓸 방법이 없다**
- **[MEDIUM] `CanvasSurface.init`이 유한성을 검증하지 않는다** — 전 호출부가 리터럴이라 현재 도달 경로 없음

상세: `.dev/feat-editor-selection/trust-ledger.md`

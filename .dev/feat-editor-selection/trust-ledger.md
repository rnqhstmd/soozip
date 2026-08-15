# Trust Ledger — EDITOR-4 (선택 상태 + 바운딩 박스)

## 통합 감사 (review)

### quality-reviewer

**Critical 0건.** 프로덕션 코드에 강제 해제(`!`) 0건, 전 타입 `struct`/`enum` + `Sendable`, 무한 루프·경합·데이터 손실 경로 없음.

**Important 2건**

- **[동작결함] 뒤집기 판정이 `up`이 화면 위를 향한다고 가정한다** (`HandlePlacement.swift:95-105`)
  - 근거: 판정은 `topScreen.y <= 40`인데 실제 핸들 위치는 `topScreen ± 28·up`이다. `up.y = -cos(rotation)`이므로 회전 90°~270°에서 `up`이 화면 **아래**를 향하고, 이때 뒤집은 위치 `bottomScreen.y − 28·up.y`는 **항상 판정선보다 위**에 놓인다.
  - 실측(오케스트레이터 직접 검증): 표면 `canvas 1080×1350 / viewport 540×700`(scale 0.5), `LayerFrame(center: (540, 5), size: 200×100, rotation: .pi)` → `topScreen.y = 40` → `flipped = true` → **`rotate.y = −38`(뷰포트 밖)**. 뒤집지 않았다면 `68`로 화면 안이었다.
  - AC-11·12·13은 회전 0, π/2 케이스는 `up.y = 0`이라 이 구간이 어느 테스트에도 걸리지 않는다.
  - 권고: `up.y > 0`일 때 뒤집기를 억제하거나 두 후보 중 화면 안쪽을 고른다. **기준선 40pt와 `<=` 경계를 고정한 기존 테스트(`HandlePlacementTests.swift:132-140`)를 깨지 않아야** 한다 — "판정식을 후보 위치 기준으로 교체"하는 단순 수정은 `topY=56`을 뒤집힘으로 바꿔 경계 계약을 깬다.

- **[동작불변] `select`의 주석이 실제 의미와 다르고, 그 차이를 고정하는 테스트가 없다** (`LayerStore.swift:103-109`)
  - 근거: 주석은 "`move`가 없는 id를 조용히 무시하는 것과 같은 경합 방어"라고 하지만, `move`는 없는 id에 대해 상태를 **보존**하고(`guard ... else { return }`) `select`는 **기존의 유효한 선택을 지운다.** 선택 중인 A가 있는 상태에서 방금 삭제된 B의 id로 `select(B)`가 오면 A의 선택이 함께 날아간다.
  - `없는_식별자를_선택해도_스토어_값은_그대로다`(`SelectionTests.swift:123-133`)는 **선택이 없는 스토어**에서 시작하므로 `guard ... else { return }` 변이도 통과한다 — "기존 선택을 지운다"는 쪽은 어느 테스트도 고정하지 않는다.
  - 참고: 이 **동작 자체는 확정된 결정**(파이프라인 중 사용자 승인: "저장소에 없는 id는 조용히 선택 없음이 된다")이다. 문제는 근거 문장이 부정확하고 특성화 테스트가 없다는 것.

**Minor 6건** (비차단): 루프 내 `#expect` 식별 메시지 누락 2곳 · `orderedHandles`/`edges` doc comment 부재 · `edges`의 프로덕션 소비자 0 · `Layer.baseSize`의 MARK 구역 배치 · `ResizeAnchor`의 로컬 반너비 계산이 `pointOnBoundary`와 중복(기존 코드).

### security-auditor

**CRITICAL 0 · HIGH 0 · MEDIUM 3.** 로컬 전용 순수 로직 패키지라 전통적 웹 보안 축은 해당 없음(네트워크·파일·로그·force-unwrap 0건 확인).

- **[GAP/MEDIUM]** `select`가 유효한 선택이 있는 상태에서 유령 id로 호출되면 그 선택을 지운다 — quality Important 2번과 동일 지적(독립 발견). 대칭 테스트 부재.
- **[GAP/MEDIUM]** `photo`·`stamp`·`drawing`의 변 핸들 금지가 **컴파일러가 아니라 `selectionHandles` 경유라는 관례로만** 강제된다. `resized(draggingEdge:)`와 `HandlePlacement.init`이 둘 다 `public`이고 `Edge: CaseIterable`이라 `Set(Edge.allCases)`를 직접 넘기는 한 줄이 가능하다. 현재 호출부 0건이라 도달 불가하나, **`EDITOR-7` 착수 시 닫아야 한다.** 설계서 §5가 이 한계를 이미 정직하게 명시함.
- **[ASSUMPTION/MEDIUM]** "`CanvasSurface`가 자기 입력을 이미 막고 있다"는 전제가 **부분적으로만 참**이다. `CanvasSurface.init`은 `canvas`/`viewport`의 유한성을 검증하지 않아, `NaN` 캔버스면 `center`가 즉시 `NaN`이 되고 `toScreen`이 `NaN·0 = NaN`을 흘린다 → `box != nil`인데 좌표가 `NaN`인 상태(설계 §2-e가 배제하려던 바로 그 상태). 전 호출부가 `Size2(1080, 1350/1920)` 리터럴만 써서 **현재 도달 경로 없음.**

### 검증 완료 (문제 없음)

- AC-9~13의 기하 값을 `toWorld`/`toScreen` 행렬로 재계산해 코드·PRD·테스트 세 값 일치 확인
- 크기 0·음수가 `box != nil`로 통과하는 계약이 테스트로 고정됨 → 결정 5(`EDITOR-6` 자리) 보존 확인
- `select`/`deselect`/`remove`/z-order가 `storage`를 건드리지 않음 → 선택 버그가 레이어 데이터 손실로 번질 경로 없음
- `Layer.baseSize`가 계산 프로퍼티라 layoutJSON 인코딩 무영향 (수동 `Codable` 구현 직접 확인)
- 새 타입 전부 값 타입 + `Sendable`, `@unchecked Sendable` 0건
- 항등식 테스트 0건 · `Double ==` 0건(좌표는 전부 `isClose`)

## 통합 감사 — 2회차 (수정 반영 후)

1회차 Important 2건을 각각 RGR 사이클(T4)과 refactor-coder로 처리한 뒤 재검증.

- **spec-reviewer: SPEC PASS 15/15.** AC-15(신규) 충족. AC-1~14는 회전값별 `up.y` 계산으로 영향 없음 확인 — `r=0` → `−1`, `r=π/2` → `0`, `r=π` → `+1`. 새 조건은 마지막 구간에서만 발동. 결정 4의 기준선(뷰포트 상단)은 훼손되지 않음(`up.y <= 0`은 AND로 덧붙는 **별개 게이트**).
- **quality-reviewer: QUALITY PASS.** Critical 0 · Important 0 · Minor 9.
  - Important 1(뒤집기 역효과) **해소** — `up.y > 0` 구간에서 새 위치가 항상 이전보다 나쁘지 않은 **단조적 개선**임을 확인. 기존 경계 계약(`flipThreshold = 40`, `<=`) 보존됨.
  - Important 2(`select` 주석·특성화) **해소** — 특성화 테스트가 `guard ... else { return }` 변이를 실제로 죽임. 기존 테스트(유령 id 미저장, `==` 축)와 신규 테스트(기존 선택 해제, 파생 조회 축)가 **서로 다른 축**을 잡아 상호 보완.

### Minor 9건 (전부 동작 불변 · 비차단)

**이번 수정이 새로 들인 것 (3건)**

- **N1** `HandlePlacement.swift` — 새 게이트 `up.y <= 0`의 **경계가 주석 문면과 어긋나고 테스트로도 고정되지 않음.** 주석은 "`up`이 화면 **위를 향할 때만**"인데 `up.y == 0`은 **수평**이고 그것도 통과한다. `<= 0` → `< 0` 변이를 죽이는 테스트가 없다(차이 조건이 `r = ±90° 정확 && topScreen.y ≤ 40`인데 해당 케이스 부재). 세로 결과가 동일해 비차단이나, 이 저장소가 `<= 40` 경계를 전용 테스트로 고정한 것과 대비된다. **회전 15° 스냅(`EDITOR-8`)이 들어오면 ±90°는 흔한 상태가 된다.**
- **N2** `HandlePlacementTests.swift` — AC-15 테스트가 `rotateFlipped`를 단언하지 않음. 기존 뒤집기 테스트 3종은 위치와 플래그를 함께 고정한다.
- **N3** `HandlePlacement.swift` — **뷰포트 하단은 어느 축에서도 방어하지 않음**(기존 성질, 이번 수정과 무관). v4 §5.7의 방어 대상이 툴바(상단)뿐이라 현 설계 범위 밖.

**1회차 이월 (6건)** — M1 루프 내 `#expect` 식별 메시지 누락 · M2 `orderedHandles`/`edges` doc comment 부재 · M3 `edges`의 프로덕션 소비자 0 · M4 `Layer.baseSize`의 MARK 구역 배치 · M5 유한성 가드가 `frame`만 봄(`CanvasSurface.init` 미검증) · M6 `ResizeAnchor`의 로컬 반너비 계산 중복.

## Minor 처리 결과

**N1·N2 정리함** (사용자 결정: 이번 수정이 새로 들인 것만).

- **N2 해소**: AC-15 테스트에 `rotateFlipped == false` 단언 추가.
- **N1 — 실측으로 성격이 바뀌었다.** 오케스트레이터가 `r = π/2`에서 `up.y == 0`이 되어 `<= 0` vs `< 0`이 갈린다고 계산했으나 **틀렸다.** 실측:
  ```
  cos(Double.pi/2) = 6.123233995736766e-17   (정확히 0이 아님)
  up.y = -cos(r)   = -6.123233995736766e-17  (이미 음수)
  → `<= 0`과 `< 0`이 둘 다 참 — 구별되지 않음
  ```
  refactor-coder가 실제로 변이를 주입해 생존을 확인했고, π/2 근방 400만 ULP를 탐색해도 `cos(x) == 0.0`인 `Double`이 없음을 확인했다. IEEE754 특성상 `Double` 회전값으로 `up.y`를 정확히 0으로 만들 수 없다.

  **결론: 이 변이는 커버리지 구멍이 아니라 등가 변이(equivalent mutant)다.** 주석을 실측 결과로 정정했고(거짓 주장을 코드에 남기지 않기 위함), 추가한 경계 테스트는 `flipThreshold = 40` × `rotation = π/2` 조합의 회귀 방어로서 유지했다.

**이월된 Minor 7건**(N3 + M1~M6)은 정리하지 않았다 — 전부 동작 불변·비차단이며, 아래 위험 수용에 기록한다.

## 인수 검증 (product-owner) — ACCEPT

AC-1~15 전부 충족. [Must] FR-1~10 · BR-1~6 16건 전수 구현, [Should] QE-1 충족.

**인수 조건으로 함께 기록된 비즈니스 관점 3건** (오케스트레이터가 코드로 직접 재확인):

- **[선행 과제] `LayerStore`에 레이어 갱신 경로가 없다.** mutating API가 `select`·`deselect`·`insert`·`remove`·z-order 4종뿐이고 `storage`는 `private`, `entries`는 사본을 내는 computed다. **`EDITOR-7`(리사이즈)·`EDITOR-8`(회전)은 계산한 새 `LayerFrame`을 스토어에 되쓸 방법이 없다.** EDITOR-4의 AC 범위 밖이라 인수를 막지 않으나, PRD 성공 지표("EDITOR-5~8이 이 단위 결과를 그대로 입력으로 받아 착수할 수 있다")는 **이 API 없이는 충족되지 않는다.** `EDITOR-7` 착수 전에 "선택된 레이어의 transform을 갱신하는 스토어 API"를 먼저 정의해야 한다.
- **[목표와 강제 수준의 괴리]** PRD 목표는 "사진 왜곡을 **애초에 할 수 없게** 만든다"인데 실제 강제는 "정상 경로(`selectionHandles`)만 쓰면 안전한" 규율 수준이다. `EDITOR-7`이 종류 확인 없이 `resized(draggingEdge:)`를 부르면 목표가 끝내 달성되지 않는다. (security-auditor GAP/MEDIUM과 동일 지점 — 아래 위험 수용에도 기록)
- **[문서 정합성] v4 §5.7:273이 아직 "박스 상단이 캔버스 상단에서 40pt 이내"로 적혀 있다.** 코드는 결정 4에 따라 **뷰포트 상단** 기준이다. 회귀 방어 테스트와 코드 주석이 리스크를 낮추지만, **설계 SSOT 자체가 코드와 어긋난 상태**라 문서만 보고 되돌리는 회귀가 가능하다.

## 위험 수용

- [Minor 7건 미정리] N3(뷰포트 하단 미방어 — v4 §5.7의 방어 대상이 상단뿐이라 설계 범위 밖) · M1(루프 내 `#expect` 식별 메시지) · M2(`orderedHandles`·`edges` doc comment) · M3(`edges`의 프로덕션 소비자 0) · M4(`Layer.baseSize` MARK 배치) · M5(`CanvasSurface.init` 유한성 미검증 — 전 호출부가 리터럴이라 현재 도달 경로 없음) · M6(`ResizeAnchor` 로컬 반너비 계산 중복, 기존 코드). 전부 동작 불변·비차단이며 게이트를 막지 않는다. (review 2회차 / 사용자 결정)
- [정책 강제가 관례 수준] `photo`·`stamp`·`drawing`의 변 핸들 금지가 컴파일러가 아니라 `selectionHandles` 경유 규율로만 강제된다. 현재 `resized(draggingEdge:)` 호출부 0건이라 도달 불가하나, **`EDITOR-7` 착수 시 닫아야 한다.** 설계서 §5가 이 한계를 명시적으로 기록함. (security-auditor GAP/MEDIUM)

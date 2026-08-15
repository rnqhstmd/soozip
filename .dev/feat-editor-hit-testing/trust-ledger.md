## Trust Ledger — EDITOR-5 (핸들 히트 판정)

### 통합 감사 (review) — security-auditor

- **[POLICY/HIGH] BR-3(삭제는 탭에서만 유효)의 단일 출처가 컴파일러로 강제되지 않는다.**
  - 근거: `HandleGesture.accepts(_:)`가 BR-3의 유일한 구현이고 저장소 전체 grep 결과 **현재는 복제가 없다.** 그러나 `hitCandidates`·`PlacedHandle.handle`·`Handle.delete`가 전부 `public`이라 `EDITOR-10`(제스처 라우팅, 미구현)이 `candidates.first { $0.handle != .delete }` 한 줄로 정책을 재기술하는 것을 막을 컴파일 타임 장치가 없다. 설계서 §1-b가 "`internal`은 재사용만 막고 복제는 못 막는다"고 **스스로 인정**한 지점이다.
  - 무게: 이 저장소는 "같은 규칙이 두 곳에 적히면 조용히 어긋난다"를 **4번** 겪었다 (`workArea`·`LayerCategory`·`LayerKind`·`resizableEdges`). 이 구조는 5번째 재발을 순전히 리뷰어의 주의력에 의존해 막는다.
  - 처리: **`EDITOR-10` 착수 조건으로 이월.** grep 기반 CI 아키텍처 테스트는 이 단위에 없던 새 장치라 범위 밖으로 판단했다. `EDITOR-10` 설계 시 "반드시 `hitHandle(at:for:)`을 거친다"를 MUST 요구사항으로 명문화할 것.

- **[ASSUMPTION/MEDIUM] `HandlePlacement.init`의 `.isFinite` 가드는 입력만 검사하며 연산 결과의 오버플로우를 막지 않는다.**
  - 도달 경로: `LayerTransform.frame(baseSize:)`(`Layer.swift:58-63`)가 `baseSize.width * scale`을 가드 없이 곱하고, `SelectionHandles.swift:34-35`가 "측정 실패 시 비유한 값 허용"을 명시적으로 계약한다. 손상된 `scale`과 결합하면 극단값이 `init`에 실제로 도달한다.
  - 검증: `abs(차) <= half` 구조라 `position`이 `Infinity`/`NaN`이 되어도 **거짓양성(오탐 히트)은 발생하지 않는다.** 수식 자체는 안전하다.
  - 처리: **닫힘** — A-6(`.infinity`)·A-7(`.greatestFiniteMagnitude`) 테스트로 고정했다.

- **[GAP/MEDIUM] `Infinity`·`greatestFiniteMagnitude` 미검증** → **닫힘** (위와 동일 조치). `EDITOR-4`의 `HandlePlacementTests`도 `.nan`/`.infinity` 10종은 재지만 `greatestFiniteMagnitude`(유한성 가드를 통과하는 극단값)는 안 쟀다 — 그 공백이 이 단위에서 처음 닫혔다.

- **[GAP/MEDIUM] §1-h "FR-3의 nil 분기는 현재 도달 불가능"의 세 근거는 코드에서 전부 사실로 확인됐다.**
  - 검증: ① `Box.delete`가 계산 프로퍼티 `{ topLeft }` ② `Box`의 멤버와이즈 init이 `internal` ③ `HandlePlacement.init(box:)`가 `private`.
  - 잔여 위험: **`EDITOR-6`이 코너를 박스 밖으로 밀어내며 1번 전제를 깨면 이 경로가 도달 가능해지는 동시에 무테스트 상태가 되고, 그 전이는 어떤 테스트도 실패시키지 않는다.**
  - 처리: **`EDITOR-6`로 이월.** 현재는 코드 주석과 설계서에만 존재하는 인계라, 그 자체가 과거 4번의 실패와 같은 패턴이다.

### 코드 품질 (quality-reviewer)

**1회차 — Critical 0 · Important 4(전부 `[동작불변]`) · Minor 3 → QUALITY FAIL**

| # | 지적 | 처리 |
|---|---|---|
| I-1 | 겹침 승자 규칙이 코드·주석·테스트 세 곳에서 다름. `hitHandle`은 거리를 계산하지 않는데 주석은 "동점만 순서가 정한다"로 읽힘. **`sorted(by: 거리).first { accepts }` 변이가 24건 전부 통과** | **닫힘** — 주석 2곳 정정 + 특성화 테스트 D-3 신규(탐침 (278,358), BR가 2.83pt 최근접인데 드래그는 좌상단). 사용자 결정: **현행 동작 유지**(PRD BR-4가 "겹침은 순서만으로"로 이미 정함) |
| I-2 | `orderedHandles` doc이 순회 방향 반대인 두 소비자에게 같은 배열을 약속. 정순 도포 시 ✕가 코너 밑에 깔림 | **닫힘** — "그리기는 역순으로 칠한다" 문단 추가 |
| I-3 | `edges` doc의 교차 참조가 실재하지 않는 표현을 가리킴. 그 표현은 **그것을 거부한 이유를 적은 주석**(`SelectionTests.swift:185`)에만 있음 | **닫힘** — `:223`·`:232` 리터럴 인용 + 해당 형태 금지 명시 |
| I-4 | 줌 400% 표면 정의가 두 곳에 복제. F-2(AC-12)는 음성 단언만 있고 "박스 파생 배율" 단독 방어선인데 유효성을 복제된 F-1에 기댐 | **닫힘** — `확대표면()`/`축소표면()` 추출, 역산 근거 주석 첨부 |

**2회차 — Critical 0 · Important 0 · Minor 2 → QUALITY PASS**

| # | 지적 | 처리 |
|---|---|---|
| M-1 | A-6·A-7 주석의 "유클리드 변이 방어" 주장이 거짓. 무한대에서는 유클리드도 미스한다 | **닫힘** — 실제 방어 대상(판정 반전·좌표 클램프)으로 정정 |
| M-2 | `Box.delete`·`orderedHandles` doc의 승자 귀속이 반쪽만 정확. `.tap.accepts`는 아무것도 거르지 않으므로 **탭의 승자는 제스처가 아니라 배열 순서**가 정한다 | **닫힘** — "제스처가 거르고, 순서가 고른다" 2단계로 정정 |

### 위험 수용

- [1회차 Minor 3건 미처리] 사용자 결정으로 이번 범위에서 제외 (`throws`인데 `try` 없음 3곳 · `표면()`이 `HandlePlacementTests.swift`와 교차 파일 중복 · 음성 케이스 3곳이 `.tap`만 잼). 전부 동작 불변·비차단. (phase-review Step 4c)
- [BR-3 구조적 보호 이월] grep 기반 CI 아키텍처 테스트를 이번 단위에 도입하지 않음 — `EDITOR-10` 착수 조건으로 이월. (phase-review Step 4)
- [§1-h 커버리지 공백 이월] `EDITOR-6`이 `Box.delete = { topLeft }` 전제를 깰 때 FR-3의 nil 분기가 무테스트로 도달 가능해짐. 지금 닫을 수 없어 `EDITOR-6`에 인계. (설계서 「테스트 가능성」 감점 1점)

### 다음 단위로 넘기는 것

| 항목 | 수신 단위 |
|---|---|
| BR-3 단일 출처의 구조적 강제 (`hitHandle`을 반드시 거치기) | `EDITOR-10` |
| `Box.delete`가 `{ topLeft }` 파생을 벗어날 때 FR-3 nil 분기 테스트 추가 | `EDITOR-6` |
| `orderedHandles` 정순/역순 도포 규약 (✕가 코너 밑에 깔리지 않게) | `EDITOR-11` |
| `placement.edges == kind.resizableEdges` 형태 금지 (동어반복) | `EDITOR-6` |
| 근접 우선 히트가 제품 의도가 될 경우 새 AC로 정의 | `EDITOR-6`·`EDITOR-10` |
| `LayerStore`에 레이어 transform 쓰기 경로 부재 | `EDITOR-7`·`EDITOR-8` 착수 전 |

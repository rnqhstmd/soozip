# 설계서(초안): EDITOR-7 — 리사이즈 (대각 고정점 + 하한 40 / 상한 캔버스 긴 변 ×4)

- PRD: `.dev/feat-editor-resize/prd.md` · 코드 맵: `.dev/feat-editor-resize/codemap.md`
- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §5.7 (line 291, 596)
- 프로덕션 호출부: **0건** (grep — `resized(dragging…)`는 `ResizeAnchor.swift` 자신과 테스트에만 있다)

## 설계 규모

**중형** — 프로덕션은 `ResizeAnchor.swift` 한 파일의 네 지점이고, 기존 테스트 7건 중 깨지는 것이 0건이다(전건 재전개, §산술 전개 7). 다만 신규 AC 7건 중 5건이 `clamped`/`resized(draggingCorner:)`의 같은 본문을 순차로 건드려 사이클 병렬화가 불가능하다.

## 변경 범위

| 파일 | 신규/수정 | 무엇을 |
|---|---|---|
| `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift` | **수정 (4지점)** | ① `resizeLimits(canvas:)` + `private static` 상수 2종 신설 ② `clamped` — 블록 순서 교체(상한→하한) + `aspectIfCollapsed: Double?` 매개변수 ③ `resized(draggingCorner:)` 진입 가드 2줄 ④ 변 드래그 호출부 `nil` 전달 + `clamped` doc에 F-4 결함 명시 + 보정 블록이 대수적 항등이라는 doc 정정 |
| `Packages/SoozipGeometry/Tests/SoozipGeometryTests/ResizeAnchorTests.swift` | **수정** | 상단 `minSide`/`maxSide` 리터럴 2줄 **삭제** → 프로덕션 유도 픽스처로 교체, 기존 7건 인자 표현 교체(단언 무변경), 신규 AC 7건 |
| `context/editor/status.md:28` | **수정 (문서만)** | "하한·상한 값 주입은 `EDITOR-7`" → 완료 + `LayerFrame.resizeLimits(canvas:)` 위치 명시 |

**신규 파일 0. `SoozipLayout` 무변경.** `CanvasAspect`를 참조하지 않는다(F-2).

## 적용 컨벤션

- Foundation 전용. Swift Testing, 테스트 함수명 한국어, 픽스처는 한국어 `private func`.
- 기하 테스트 파일마다 `private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }`.
- **`Double ==` 직접 비교 금지.** 예외는 상수 리터럴 단언뿐(`HandlePlacementTests.swift:586`의 `edgeHideThreshold == 88`). `resizeLimits(...).maxLongSide`는 **곱셈 결과**이므로 상수 리터럴이 아니다 → `isClose`.
- 파일 스코프 상수 선례: `CanvasSurfaceTests.swift:15,18`의 `private let post`/`story`. 한국어 상수도 선례 있음(`:20` `세로`, `:22` `가로`).
- doc comment는 "이렇게 안 하면 무엇이 깨지는가" — `HandlePlacement.swift:76-95`가 기준.

---

## 결정 D-1. 하한 40 / 상한 ×4의 단일 출처

**후보**

| # | 위치 | 평가 |
|---|---|---|
| A | `CanvasSurface`의 파생 프로퍼티 | 캔버스를 이미 들고 있어 가장 짧다. 단 AC-2의 Given이 `Size2`라 테스트가 무의미한 `viewport`를 지어내야 한다. 더 나쁜 것은 한계가 뷰포트·줌과 무관한데 `surface`에 붙으면 "줌하면 한계가 변한다"는 오해가 자연스러워지고, 언젠가 `scale`을 곱하는 변경이 합리적으로 보인다 — 그 순간 하한의 단위가 논리 px에서 화면 pt로 조용히 바뀐다 |
| B | `Size2`의 확장 | `Size2`는 순수 값 타입인데 리사이즈 **정책**을 얹게 된다 |
| C | `ResizeLimits` 구조체 + `init(canvas:)` 단일 생성자 + 시그니처 교체 | **유일하게 구조적 차단이 가능한 안.** 그러나 AC-1·3·4·5·6·7이 전부 `minShortSide:`/`maxLongSide:` 두 인자 호출을 명시하고 기존 7건이 그 형태다 — AC와 충돌 |
| D | **`extension LayerFrame`(`ResizeAnchor.swift`)의 정적 팩토리 + `private` 상수 2종** | 소비자 시그니처와 같은 파일. `Size2`를 받으므로 `CanvasAspect.size`·`LayoutDocument.canvas`·`CanvasSurface.canvas` 셋 다 그대로 넘어간다. AC-2의 Given과 같은 모양 |

**선택: D**

```swift
extension LayerFrame {
    private static let minShortSide: Double = 40
    private static let canvasLongSideMultiple: Double = 4

    public static func resizeLimits(canvas: Size2) -> (minShortSide: Double, maxLongSide: Double) {
        (minShortSide: minShortSide,
         maxLongSide: canvas.longSide * canvasLongSideMultiple)
    }
}
```

**접근 수준**: `HandlePlacement`의 혼재에서 직전 단위가 뽑아낸 규칙은 "public으로 통일하지 마라"가 아니라 **"모듈 밖 소비자가 없으면 열지 마라"**(`HandlePlacement.swift:69-74`)다.

- `resizeLimits(canvas:)` → **`public`**. 모듈 밖 소비자가 확정돼 있다 — `EDITOR-11` 배선이 `LayoutDocument.canvas`에서 한계를 유도해 넘겨야 하고, 이 경로 없이는 착수 불가.
- `minShortSide`·`canvasLongSideMultiple` → **`private`**. 소비자 0건이고, 열면 `canvas.longSide * LayerFrame.canvasLongSideMultiple`이라는 **재기술 경로**가 생긴다. `internal`도 아니다 — 테스트는 `resizeLimits(...)` 반환값으로 40을 관측하는 쪽이 **더 강한 관측**이다(두 캔버스에서 같은 값이 나오는 것까지 잰다).

> `resized(draggingCorner:…minShortSide:…)`의 **매개변수 이름**이 `private static let minShortSide`를 그늘 지운다. 함수 본문의 `minShortSide`는 언제나 매개변수이고 정적 상수는 `resizeLimits` 안에서만 쓰인다. 의도된 상태이므로 doc에 한 줄 남긴다.

**AC-2의 관측 형태**

```swift
private let post  = Size2(width: 1080, height: 1350)
private let story = Size2(width: 1080, height: 1920)
private let 포스트한계 = LayerFrame.resizeLimits(canvas: post)
private let 스토리한계 = LayerFrame.resizeLimits(canvas: story)
```

AC-2는 `isClose(포스트한계.minShortSide, 40)` · `isClose(스토리한계.minShortSide, 40)` · `isClose(포스트한계.maxLongSide, 5400)` · `isClose(스토리한계.maxLongSide, 7680)` 네 건. 좌변이 전부 프로덕션 반환값이다.

**`ResizeAnchorTests.swift:6-7` 처리 — 삭제한다.** 두 `private let` 자체는 무해하지만 **line 7의 주석(`// 캔버스 긴 변 1920 × 4`)이 유도 규칙의 두 번째 기술**이다. 프로덕션에 유도가 생긴 뒤에도 남기면 정확히 여섯 번째 재발이다. 기존 7건은 `스토리한계.minShortSide`/`.maxLongSide`를 쓴다 — **값이 40/7680으로 동일하므로 단언은 한 글자도 안 바뀌고 7건 전부 초록 유지**. 이 교체는 사이클 1의 REFACTOR다(그전엔 `resizeLimits` 심볼이 없어 컴파일 불가).

**고르지 않은 쪽의 비용**: A는 AC-2가 무의미한 `viewport`를 지어내야 하고 장기적으로 `scale` 오염 위험. C는 **진짜 구조적 차단**을 얻지만 AC 6건의 When 절과 기존 7건 호출 형태를 전부 다시 써야 한다 — PRD가 확정한 AC를 설계가 되짚는 것이다. 얻지 못한 것을 §보장하지 않는 것에 명시하고 `EDITOR-11`로 넘긴다.

## 결정 D-2. `(0,0)`에서 하한을 복원하는 방법

**후보**

| # | 방법 | 평가 |
|---|---|---|
| A | `clamped`에 `ratio: Double` 추가 | 변 드래그가 `Double`을 강제로 넘겨야 한다 — 원본 크기 `(0,0)`인 변 드래그에서 그 값은 `NaN`이고, 씨앗이 `NaN`이 되어 **오늘 `(0,0)`을 내는 입력이 `NaN`을 내게 된다**(회귀) |
| B | 호출부에서 `(0,0)`을 먼저 처리 | 복원식 `minShortSide * max(ratio,1)`이 **하한 규칙의 두 번째 기술** — 실패 패턴 #1 재발 |
| C | 클램프를 비율 기반으로 전면 재작성 | 변 드래그가 공유하므로 그쪽 계약까지 새로 정의해야 한다(F-4 정책 결정) = AC 밖 |
| D | **`aspectIfCollapsed: Double?` + 씨앗 `(비율, 1)`** | 아래 |

**선택: D**

```swift
    if w == 0, h == 0, let aspect = aspectIfCollapsed {
        w = aspect
        h = 1
    }
```

근거 셋:

1. **씨앗이 `(비율, 1)`이지 `(하한 × 비율, 하한)`이 아니다.** 씨앗이 크기까지 정하면 하한 규칙이 이 함수 안에 두 번 적히고, 한쪽만 바뀌는 날이 온다. 씨앗은 비율만 나르고 크기는 아래 하한 블록이 정한다.
2. **`Double?`가 "이 매개변수는 코너 경로에만 의미가 있다"를 타입으로 표현한다.** `EDITOR-6`의 `pushedFrom: Vec2?`와 같은 형태.
3. **F-4 상호작용 판정**: 변 드래그의 계약은 "한 축만 바꾼다"라 비율 보존이 계약이 아니고, 그 경로가 `(0,0)`에 닿으려면 원본 크기가 이미 `(0,0)`이어야 하는데 그때 비율은 `0/0 = NaN`이다. 따라서 `ratio`는 변 경로에서 의미가 없다 → `nil`. 후보 A였다면 그 `NaN`이 씨앗이 되어 회귀를 만들었을 것이다(검산: 원본 `(0,0)` + `.right`를 로컬 x=0으로 → `newW=0, newH=0` → 씨앗 `(NaN,1)` → `max(NaN,1)`은 Swift에서 `NaN` → 두 블록 스킵 → `(NaN, 1)`. 오늘은 `(0,0)`).

**FR-5 축과의 분리 유지**: PRD 산출 근거 §1이 원본 `(0,0)`을 별개 문제로 분리했다. 이 설계에서 그 경로는 코너 쪽은 D-4의 `ratio` 가드가, 변 쪽은 `nil`이 씨앗 분기를 닫는다 — 두 축이 코드상 다른 지점이라 **분리가 유지된다.**

## 결정 D-3. "하한 우선"(BR-1)의 구현

**선택: 블록 순서 교체(상한 → 하한).** (b) 하한 재적용은 규칙이 두 번 적히고, (c) 최종식 합산은 `shortSide == 0` 분기와 얽혀 읽히지 않는다. **순서가 곧 우선순위이고, 그 사실이 코드에서 읽히는 유일한 형태다.**

**정상 입력 불변**: 두 블록이 **둘 다 발동해야만** 순서가 결과를 바꾼다. 하나만 발동하거나 둘 다 스킵이면 같은 곱을 같은 횟수 적용하므로 비트 단위 동일. 기존 7건 중 동시 발동 입력은 0건(§전개 7 — 발동 조합은 없음 5건 / 하한만 1건 / 상한만 1건).

**`longSide = ratio × minShortSide` 유계**: 두 블록이 비율을 보존하므로 하한 블록 종료 시 `shortSide = minShortSide`, `longSide = minShortSide × ratio`. 상한 발동 여부와 무관하게 수렴.

**반례를 찾아봤다. 셋 찾았고 전부 기록한다.**

1. **`maxLongSide ≤ 0`이면 비율이 소실된다.** `k = 0` → `(0,0)` → 하한은 `shortSide > 0`이 거짓이라 스킵 → `(0,0)`. 진입 가드는 유한성만 보고 양수성은 안 본다. 도달 경로 실재: `resizeLimits(canvas: .zero)`. `LayoutDocument.init(from:)`(`:166-168`)이 캔버스 w/h를 검증 없이 읽는다.
2. **`ratio`가 극단이면 오버플로우한다.** `ratio = 1e300`이면 `rawH * ratio`가 이미 `Infinity`. "유계"는 **"원본 프레임이 가진 값으로 결정된다"는 뜻이지 "작다"는 뜻이 아니다.**
3. **순서 교체가 변 드래그 결과도 바꾼다.** 원본 `(30, 100000)`의 `.right`를 로컬 x=85로: 구 `(7.68, 7680)` / 신 `(40, 40000)`. 방향은 BR-1 문면과 일치하나 **"변 경로 무변경"이라고 쓰면 거짓**이다. 참인 것은 "변 드래그에서 새 분기(붕괴 복원)는 실행되지 않는다"뿐. 기존 7건 중 해당 입력 0건.

**되돌리는 변이(`상한 블록을 다시 아래로`)는 AC-6 단독으로 죽는다** — 방어선이 하나뿐이라 AC-6은 생략 불가.

## 결정 D-4. NaN 방어(FR-5·AC-7)의 위치

**선택: `resized(draggingCorner:)` 진입부 가드 + `ratio` 유한·양수 가드.** 후퇴 대상은 `self`.

```swift
        guard worldPoint.x.isFinite, worldPoint.y.isFinite,
              minShortSide.isFinite, maxLongSide.isFinite else { return self }

        let ratio = size.width / size.height
        guard ratio.isFinite, ratio > 0 else { return self }
```

근거:

- FR-5가 이름을 댄 세 입력을 그 이름이 등장하는 경계에서 막는다.
- **저장소 선례가 전부 진입부다**: `CanvasSurface.zoomed(to:)`(`:114`), `centered(on:)`(`:122`), `HandlePlacement.init`(`:128-133`). **결과 검사 선례는 0건.**
- **프레임 자신의 유한성은 검사하지 않는다.** 검사해도 후퇴 대상이 바로 그 비유한 프레임이라 결과가 여전히 비유한 — 아무것도 사지 못한다. `ratio` 가드는 다르다: 원본 크기 `(0,0)`은 **유한한데** 비율만 `NaN`이라 후퇴하면 유한한 프레임을 돌려줄 수 있다. **이 비대칭이 두 가드를 가른다.**

**사용자에게**: 그 드래그가 무시되고 레이어가 손대기 전 자리에 멈춘다.

**`EDITOR-6` 이월 HIGH(`fitScale` 오버플로우)와 다른 축이다.**

| | EDITOR-6 이월 | 이 단위의 가드 |
|---|---|---|
| 대상 | `CanvasSurface.fitScale`의 나눗셈 오버플로우 | `resized(draggingCorner:)`의 인자 |
| 좌표계 | 논리 → **화면** 변환 결과 | **논리** 좌표 입력 |
| 파일 | `CanvasSurface.swift`·`HandlePlacement.swift` | `ResizeAnchor.swift` (import는 Foundation뿐) |

**앞당기지 않는다.** 배선 시 `resized`의 인자는 `surface.toLogical(화면점)`에서 오는데 `toLogical`은 `guard s > 0`이 있어 `scale`이 `NaN`이면 `center`를, `Infinity`면 유한값을 낸다(`CanvasSurface.swift:97-104`). 즉 **그 이월 항목이 이 단위의 입력으로 새지 않는다.**

**(c)(결과 4필드 검사)를 안 골라서 남는 구멍**: 원본 크기 `(1e300, 1)` → `ratio = 1e300`(**유한·양수라 가드 통과**) → `rawH * ratio = Infinity` → `k = max/∞ = 0` → `∞ × 0 = NaN`. **결과가 `NaN`이 된다.** 반대로 (a)만이 잡는 것도 있다: `maxLongSide = .infinity`/`.nan`은 유한한 쓰레기를 낸다(비교가 전부 거짓이라 클램프 스킵) — (c)는 통과시킨다. **(a)만 채택하고 오버플로우 경로는 반례로 명시해 이월한다.**

## 결정 D-5. AC-1·AC-5는 특성화다

**`resized(draggingCorner:)`의 마지막 보정 블록(`:39-42`)은 대수적 항등이다.**

`toWorld(p) = center + R(p)`, `R` 선형. `result.center = self.center + R(newCenterLocal)`, `newCenterLocal = anchorLocal + cornerSign × new/2`. `result.corner(anchor) = result.center + R(anchorSign × new/2)`. `Corner.opposite.sign == −Corner.sign`(네 케이스 전수, `LayerFrame.swift:7-23`).

⇒ `result.corner(anchor) = self.center + R(anchorLocal + cornerSign×new/2 − cornerSign×new/2) = self.center + R(anchorLocal) = anchorWorld`.

**드래그 지점·회전·크기·코너와 무관하게 항상 성립한다.** 보정항은 언제나 0이며 흡수하는 것은 부동소수 반올림(~1e-13)뿐이다.

> **오케스트레이터 독립 검증**: 무작위 300회(중심·크기·회전·코너·드래그 전부 난수)에서 보정항 최대 절대값 **1.205e-11**. 항등 확인.

귀결:

- **기존 테스트 1·2와 AC-1·4·5의 "고정점 유지" 단언은 구조적으로 항상 참이다** — 결과가 유한하기만 하면 통과한다. `toLocal`의 어떤 변이도 죽이지 못한다. (`EDITOR-6`의 `delete == topLeft`가 같은 이유로 지적받았다.)
- **AC-1의 실질은 `size == (500, 250)` 절이다.** `toLocal`의 `sin(-rotation)` → `sin(rotation)` 변이: 0°는 무영향, 45°는 크기가 `(297.99, 148.99)`로 바뀌지만 기존 2건은 고정점만 재서 통과·기존 3건은 비율만 재서 통과. **π/2에서 `size`가 `(300,150)`이 된다** → AC-1의 size 절만 죽인다. **유일한 방어선이다.**
- **AC-4의 `bottomLeft`·AC-5의 `bottomLeft` 절도 공허하다.** 실질은 AC-4의 `shortSide 40 / longSide 80`, AC-5의 `size (100,50)` + `topRight (500,400)`.

**AC별 RED/특성화 판정 표**

| AC | 내용 | 판정 | 왜 | 죽이는 변이 |
|---|---|---|---|---|
| **AC-1** | 회전 90° 고정점 + `size (500,250)` | **특성화** (RED 미성립 — 정상) | 대수 항등 + `dragLocal (−100,−200)`, `rawW 0`, `rawH 250`, `newW 500` 재전개 일치 | `toLocal` 회전 부호 반전(**`size` 절만**) · **`abs()` 제거**(오케스트레이터 검증) |
| **AC-2** | 프로덕션이 캔버스에서 40/5400/7680 유도 | **RED (컴파일)** | `LayerFrame.resizeLimits` 부재 | `longSide→shortSide`(4320) · `×4→×3` · `40→다른 값` · 캔버스 인자 무시 |
| **AC-3** | 유도값으로 클램프 정지 | **RED (컴파일) + 값은 특성화** | 심볼이 생기는 순간 값 단언은 즉시 통과 | **under-clamp** — 기존 `크기_상한에서_정지한다`가 부등식만 재서 `(3840,1920)` 같은 과잉 클램프를 놓친다 |
| **AC-4** | `(0,0)` 붕괴에서 하한 복원 | **RED (동작)** | 현재 `(0,0)` | `shortSide > 0` 유지 · 씨앗 `(1,1)`(비율 소실) · 붕괴 분기 삭제 |
| **AC-5** | 고정점 너머에서 안 뒤집힘 | **특성화** (RED 미성립 — 정상) | 재전개 일치 | **`corner.sign` → 드래그 방향 부호** 변이. 기존 7건은 전부 "바깥 방향"이라 통과 → **유일한 방어선** |
| **AC-6** | 하한이 상한을 이긴다 `(8000,40)` | **RED (동작)** | 현재 `(7680, 38.4)` | **블록 순서 되돌리기 — 단독 방어선** |
| **AC-7** | `NaN` 드래그가 결과를 오염 안 시킴 | **RED (동작)** | 현재 네 필드 `NaN` | 진입 가드 삭제 · `worldPoint.y`만 검사 |

> **RED 미성립을 사고로 오인하지 마라.** AC-1·AC-5는 **처음부터 GREEN이며 그것이 정상**이다. 사이클 2~4가 `clamped`를 재구성할 때의 회귀 그물이라 **가장 먼저** 넣는다.

## 결정 D-6 / RGR 사이클 분해

```
0. [특성화] AC-1 · AC-5                      (의존: 없음) — 프로덕션 0줄
1. [Must]   AC-2 · AC-3 — 한계 단일 출처      (의존: 0)
2. [Must]   AC-6 — 하한 우선 (순서 교체)       (의존: 1)
3. [Must]   AC-4 — (0,0) 붕괴 복원            (의존: 2)
4. [Should] AC-7 — 비유한 입력 방어            (의존: 3)
```

| 사이클 | AC | 프로덕션 변경 | 죽이는 변이 (고유) | 기존 7건 |
|---|---|---|---|---|
| **0** `test:` | AC-1·AC-5 | **0줄** | `toLocal` 회전 부호 반전 · `abs()` 제거 · `corner.sign`→드래그 방향 부호 | **0건.** 전부 초록 |
| **1** | AC-2·AC-3 | `resizeLimits` + private 상수 2종 | 캔버스 유도 4종 · under-clamp | **0건 깨짐.** REFACTOR에서 인자 기계 교체(값 동일, 단언 무변경) |
| **2** | AC-6 | `clamped` 순서 교체 | 순서 되돌리기 | **0건** (동시 발동 입력 0건) |
| **3** | AC-4 | `aspectIfCollapsed` + 붕괴 분기 | 붕괴 분기 삭제 · 씨앗 `(1,1)` · `shortSide > 0` 되살리기 | **0건** (`(0,0)` 도달 0건) |
| **4** | AC-7 | 진입 가드 2줄 | 가드 삭제 · `worldPoint.y`만 검사 | **0건** (전부 유한 입력) |

**사이클 2와 3을 합치지 않는 이유**: 둘 다 `clamped` 본문을 고치지만 죽이는 변이가 완전히 다르고, **사이클 2의 GREEN이 "순서 교체가 기존 7건을 하나도 안 깬다"를 단독으로 증명**한다. 시그니처 변경을 섞으면 회귀 시 분리되지 않는다.

**AC-2와 AC-3을 한 사이클에 두되 둘 다 필요한 이유**: AC-3이 추가로 죽이는 것은 "상한만 안 넘으면 아무 값" 변이이고 AC-2도 기존 테스트 5도 그것을 못 죽인다(테스트 5는 부등식).

검증: `./scripts/test.sh`. 베이스라인 `SoozipGeometry 123` → 최종 **130**.

---

## 상세 설계

### 1. 리사이즈 한계 (신설)

```swift
extension LayerFrame {

    // MARK: - 리사이즈 한계 (v4 §5.7 · FR-2)

    /// 짧은 변 하한(논리 px). **캔버스와 무관하다** — 4:5든 9:16이든 40이다.
    ///
    /// 이유가 캔버스가 아니라 **손가락**이기 때문이다. 하한이 없으면 레이어가 점이 되어
    /// 다시 잡을 수 없고(v4 §5.7), 그 "잡을 수 없음"의 기준은 핸들 히트 사각형(44pt)이지
    /// 캔버스 치수가 아니다. 캔버스를 바꿔도 손가락 크기는 안 바뀐다.
    ///
    /// **`private`이다.** 열면 호출부가 40을 직접 읽어 `resizeLimits(canvas:)`를 우회하는
    /// 가장 짧은 경로가 생기고, 그러면 하한과 상한이 서로 다른 두 곳에서 온다 — 이
    /// 저장소가 다섯 번 겪은 "같은 규칙 두 곳"의 시작 모양이다
    /// (`HandlePlacement.edgeHideThreshold`가 같은 이유로 `internal`이다).
    ///
    /// `resized(draggingCorner:…minShortSide:…)`의 **매개변수**가 이 이름을 그늘 지운다.
    /// 그 함수 본문의 `minShortSide`는 언제나 매개변수이며 이 상수는 아래 팩토리에서만
    /// 쓰인다 — 의도된 상태다.
    private static let minShortSide: Double = 40

    /// 긴 변 상한의 캔버스 배수. **`private`인 이유는 위와 같다** — 열면
    /// `canvas.longSide * multiple`이라는 재기술 경로가 열린다.
    private static let canvasLongSideMultiple: Double = 4

    /// 리사이즈 클램프에 넘길 한계 한 쌍. **캔버스 크기가 유일한 입력이다.**
    ///
    /// `CanvasAspect`를 받지 않는다 — 그 타입은 `SoozipLayout`에 있고 이 패키지는 그것을
    /// 볼 수 없다(단방향 의존). `Size2`를 받으면 `CanvasAspect.size` ·
    /// `LayoutDocument.canvas` · `CanvasSurface.canvas` 셋 다 그대로 넘어간다.
    ///
    /// **`CanvasSurface`의 파생 프로퍼티가 아니다.** 한계는 뷰포트·줌과 무관한데
    /// `surface.resizeLimits`로 두면 "줌하면 한계가 변한다"는 오해가 자연스러워지고,
    /// 언젠가 `scale`을 곱하는 변경이 합리적으로 보인다. 그 순간 하한의 단위가 논리
    /// px에서 화면 pt로 조용히 바뀐다 — `edgeHideThreshold`(화면 pt)와 이것(논리 px)은
    /// 단위가 다르다는 것이 정확히 핵심이다.
    ///
    /// **둘을 한 값으로 낸다.** 하한만 따로 얻는 경로를 두면 상한은 캔버스에서, 하한은
    /// 리터럴에서 오는 호출부가 생긴다. `CanvasSurface.zoomLimits`가 같은 이유로 튜플이다.
    ///
    /// ⚠️ **타입이 이 값의 사용을 강제하지는 않는다.** `resized(…)`는 여전히 `Double`
    /// 둘을 받으므로 호출부가 리터럴을 넘길 수 있다. 구조적으로 닫으려면 생성자가
    /// `init(canvas:)` 하나뿐인 `ResizeLimits` 타입으로 시그니처를 바꿔야 하는데, 이
    /// 단위의 AC 6건이 두 인자 호출 형태를 명시한다. **`EDITOR-11`이 실제 호출부를
    /// 만들 때 다시 판단할 것.**
    public static func resizeLimits(canvas: Size2) -> (minShortSide: Double, maxLongSide: Double) {
        (minShortSide: minShortSide,
         maxLongSide: canvas.longSide * canvasLongSideMultiple)
    }
}
```

### 2. `resized(draggingCorner:)` — 진입 가드 + doc 정정

**(a) 진입부 가드 2개** (사이클 4)

```swift
        // 비유한 입력은 계산 전체를 오염시킨다 (FR-5).
        // `toLocal`에서 이미 **한 성분의 `NaN`이 두 성분으로 번진다** — 회전 0에서
        // `sin(-0) = -0.0`이라 `NaN × -0.0 = NaN`이고, 그 뒤로는 `max`·`min`·비교가
        // 전부 거짓이라 **클램프가 통째로 통과한다**(Swift `max(x,y)`는 `y >= x ? y : x`).
        // 결과 프레임의 네 필드가 모두 `NaN`이 되어 화면에서 레이어가 사라진다.
        //
        // **후퇴 대상은 `self`다** — 사용자에게는 "그 드래그가 무시된다"로 보인다.
        //
        // **프레임의 유한성은 검사하지 않는다.** 검사해도 후퇴 대상이 바로 그 비유한
        // 프레임이라 결과가 여전히 비유한이다 — 아무것도 사지 못한다. 아래 `ratio`는
        // 다르다: 원본 크기 `(0,0)`은 **유한한데** 비율만 `0/0 = NaN`이라, 후퇴하면
        // 유한한 `(0,0)` 프레임을 돌려줄 수 있다. 이 비대칭이 두 가드를 가른다.
        guard worldPoint.x.isFinite, worldPoint.y.isFinite,
              minShortSide.isFinite, maxLongSide.isFinite else { return self }

        // 비율 유지: 원본 종횡비에 맞춰 더 큰 쪽을 기준으로 삼는다.
        // 비율이 유한한 양수가 아니면 이 함수가 세우는 모든 것이 무너진다 —
        // `newH = newW / ratio`도, 붕괴 복원의 씨앗도. PRD 산출 근거 §1이 이 경로를
        // `(0,0)` 붕괴 결함과 **별개 문제**로 분리했고 이 가드가 그 분리를 유지한다.
        let ratio = size.width / size.height
        guard ratio.isFinite, ratio > 0 else { return self }
```

**(b) `clamped` 호출에 `aspectIfCollapsed: ratio`** (사이클 3)

**(c) 마지막 보정 블록의 doc 정정** (사이클 0의 REFACTOR)

```swift
        // **대수적으로는 항등이다.** `toWorld(p) = center + R(p)`이고 `R`은 선형이며,
        // `Corner.opposite.sign == −Corner.sign`(네 케이스 전수)이므로
        //   result.corner(anchor)
        //     = self.center + R(anchorLocal + cornerSign×new/2 − cornerSign×new/2)
        //     = self.center + R(anchorLocal) = self.corner(anchor)
        // 가 **드래그 지점·회전·크기·코너와 무관하게** 성립한다(무작위 300회 실측
        // 최대 편차 1.2e-11). 남는 것은 부동소수 반올림 흡수뿐이다.
        //
        // **그래서 "고정점이 유지된다"를 재는 단언은 이 함수의 어떤 변이도 죽이지
        // 못한다** — 결과가 유한하기만 하면 통과한다. 기존 2건과 AC-1·4·5의 고정점
        // 절이 그 상태다. 실제 관측면은 `size`와 `topRight` 쪽이다.
        // 이 블록을 지우지 않는 이유: 반올림 흡수는 실효가 있고, 제거해도 **어떤
        // 테스트도 차이를 관측하지 못한다**(안전망 없는 변경이다).
```

### 3. `clamped` — 순서 교체 + 붕괴 복원 (사이클 2·3)

```swift
    /// 짧은 변 하한과 긴 변 상한을 **입력 비율을 보존한 채** 적용한다.
    ///
    /// **상한을 먼저, 하한을 나중에 적용한다 (BR-1). 순서가 곧 우선순위다** — 나중에
    /// 적용한 쪽이 이긴다. 반대로 두면 비율이 `상한/하한`(9:16에서 192, 4:5에서 135)을
    /// 넘는 가는 레이어에서 짧은 변이 하한 아래로 샌다: `8000×40`을 제자리로 다시 끌면
    /// 상한이 `k = 0.96`을 곱해 **38.4**를 만들고 하한 블록은 이미 지나간 뒤다.
    /// 상한을 넘긴 채 두는 것이 의도된 손해다 — 상한을 넘은 레이어는 여전히 잡히지만,
    /// 하한 아래 레이어는 핸들이 겹쳐 다시 잡을 수 없다.
    ///
    /// 하한이 발동하면 결과는 **`(비율 × 하한, 하한)`으로 유일하게 결정되고 드래그
    /// 거리와 무관하게 수렴한다** — 두 블록이 전부 비율을 보존하기 때문이다. 비율은
    /// 드래그가 만드는 값이 아니라 원본 프레임이 이미 갖고 있던 값이다.
    /// **다만 "유계"는 "작다"는 뜻이 아니다** — 비율 1e6인 프레임의 긴 변은 4e7이 된다.
    ///
    /// **`aspectIfCollapsed`는 코너 드래그 전용이다.** `(0,0)`에는 어떤 배수를 곱해도
    /// `(0,0)`이라, 붕괴한 뒤에는 이 함수 안에서 비율을 되짚을 방법이 없다.
    /// **씨앗은 `(비율, 1)`이지 `(하한 × 비율, 하한)`이 아니다** — 씨앗이 크기까지
    /// 정하면 하한 규칙이 이 함수 안에 두 번 적히고, 그러면 한쪽만 바뀌는 날이 온다.
    ///
    /// **변 드래그는 `nil`을 넘긴다.** 한 축만 바꾸는 계약이라 되돌릴 "원본 비율"이라는
    /// 개념 자체가 없고, 그 경로가 `(0,0)`에 닿으려면 원본 크기가 이미 `(0,0)`이어야
    /// 하는데 그때 비율은 `0/0 = NaN`이다. `Double`을 강제로 받게 하면 그 `NaN`이
    /// 씨앗이 되어 **오늘 `(0,0)`을 내는 입력이 `NaN`을 내게 된다.**
    ///
    /// ⚠️ **이 함수는 코너·변 드래그가 공유하는데 양축을 함께 곱한다.** 코너 드래그는
    /// 비율 유지가 계약이라 맞지만, 변 드래그의 계약은 "한 축만 바꾼다"이다. 그래서
    /// 변 드래그에서 클램프가 발동하면 **불변이어야 할 축까지 바뀐다**:
    /// `50×100` 프레임의 `.right` 변을 로컬 x=0(중심)까지 끌면 `(25, 100)`이 하한에
    /// 걸려 **`(40, 160)`** 이 되어 높이가 100에서 160으로 늘어난다. 반대쪽 변 고정은
    /// 유지되지만(중심이 `deltaW/2`만큼 보정된다) "한 축만"은 깨진다.
    /// 기존 테스트는 **클램프가 발동하지 않는 입력만** 써서 이것을 잡지 못한다.
    /// **`EDITOR-7`은 이 결함을 고치지 않았다** — AC가 없고, 고치려면 "변 드래그에서
    /// 하한·상한이 무엇을 뜻하는가"를 새로 정해야 한다. **`EDITOR-11` 착수 전에 결정할 것.**
    private static func clamped(width: Double, height: Double,
                                aspectIfCollapsed: Double?,
                                minShortSide: Double,
                                maxLongSide: Double) -> (Double, Double) {
        var w = width
        var h = height

        // 붕괴 복원 — 곱셈으로는 빠져나올 수 없는 유일한 지점.
        if w == 0, h == 0, let aspect = aspectIfCollapsed {
            w = aspect
            h = 1
        }

        // 상한 먼저.
        let longSide = max(w, h)
        if longSide > maxLongSide {
            let k = maxLongSide / longSide
            w *= k
            h *= k
        }

        // 하한 나중 — BR-1: 하한이 상한을 이긴다.
        // `shortSide > 0`은 0으로 나누는 것을 막는다. **한 축만 정확히 0인 입력**
        // (원본 크기가 `(0, h)`인 변 드래그)은 여기서 여전히 통과한다 — 코너 드래그에서는
        // 도달할 수 없다(`newH = newW / 비율`이라 한쪽이 0이면 다른 쪽도 0이다).
        let shortSide = min(w, h)
        if shortSide < minShortSide, shortSide > 0 {
            let k = minShortSide / shortSide
            w *= k
            h *= k
        }
        return (w, h)
    }
```

`aspect`가 유한·양수라는 전제: `clamped`는 `private static`이라 호출부 집합이 파일 안에 닫혀 있고 **전수 확인했다** — 비-`nil` 호출부는 `resized(draggingCorner:)` 하나이며 그 함수의 진입 가드가 보장한다.

### 4. `resized(draggingEdge:)` — 호출부 한 줄 + doc 포인터

```swift
        (newW, newH) = Self.clamped(width: newW, height: newH,
                                    // 되돌릴 원본 비율이 없다 — 한 축만 바꾸는 계약이라
                                    // 비율 자체가 계약이 아니다. 자세한 것은 `clamped` doc의
                                    // ⚠️ 절(공유 클램프가 불변 축을 바꾸는 결함)을 볼 것.
                                    aspectIfCollapsed: nil,
                                    minShortSide: minShortSide,
                                    maxLongSide: maxLongSide)
```

기존 doc(`:46-57`)에 결함 설명을 **복제하지 않는다** — `EDITOR-5`의 `edges` doc이 정확히 그렇게 갈라졌다. 포인터만 둔다.

### 5. `ResizeAnchorTests.swift` 상단

```swift
private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

private let post  = Size2(width: 1080, height: 1350)
private let story = Size2(width: 1080, height: 1920)

/// **한계는 프로덕션에서만 온다.** 예전의 `private let maxSide = 7680 // 캔버스 긴 변
/// 1920 × 4`는 값이 아니라 **유도 규칙의 두 번째 기술**이었다. 프로덕션에 유도가 생긴
/// 지금 그것을 남기면 정확히 여섯 번째 "같은 규칙 두 곳"이 된다.
private let 포스트한계 = LayerFrame.resizeLimits(canvas: post)
private let 스토리한계 = LayerFrame.resizeLimits(canvas: story)
```

---

## 타입이 보장하는 것 / 보장하지 않는 것

> 모든 "보장한다" 항목은 **반례를 찾아본 뒤** 적었다.

### 구조가 보장한다

| 보장 | 근거 | 반례 탐색 |
|---|---|---|
| **`result.corner(corner.opposite) == self.corner(corner.opposite)`** — 드래그·회전·크기·코너 무관 | 대수 전개(§D-5) + 오케스트레이터 무작위 300회 실측(최대 편차 1.2e-11) | **찾지 못했다.** 유일한 예외는 비유한 값이고 D-4 가드가 좁힌다 |
| **`clamped`가 입력 비율을 보존한다** (`maxLongSide > 0`일 때) | 두 블록 모두 `w *= k; h *= k` | **찾았다** → 아래 1행 |
| **하한이 상한을 이긴다** — 발동 시 `(비율 × 하한, 하한)` | 하한 블록이 마지막, 두 블록이 비율 보존 | **찾았다** → 아래 2·3행 |
| **`aspectIfCollapsed`가 비-`nil`이면 유한·양수** | `private static`, 파일 내 호출부 2개 전수 확인 | 찾지 못했다 |
| **코너 드래그는 한 축만 0인 상태에 도달 불가** | `newH = newW / ratio`, `ratio` 유한 양수 ⇒ `newW == 0 ⟺ newH == 0` | 찾지 못했다 |
| 이 단위가 `SoozipLayout`에 의존하지 않는다 | import는 Foundation뿐, `resizeLimits`가 `Size2`를 받는다 | — |

### 보장하지 않는다

| # | 항목 | 정직한 상태 |
|---|---|---|
| 1 | **`maxLongSide ≤ 0`에서 비율 소실** | `k = 0` → `(0,0)` → 하한 스킵 → `(0,0)`. 진입 가드는 **유한성만** 본다. 도달 경로 실재: `resizeLimits(canvas: .zero)`. `LayoutDocument.init(from:)`(`:166-168`)이 캔버스를 검증 없이 읽는다 — **이월** |
| 2 | **한 축만 정확히 0이면 하한이 적용되지 않는다** | `shortSide > 0` 조건. 코너는 도달 불가, **변 드래그는 원본 `(0, h)`로 도달 가능**. `EDITOR-6` 원장의 ASSUMPTION 항목이 경고한 전제이며 이 단위는 **코너 경로만** 닫았다 |
| 3 | **`NaN`은 클램프를 그냥 통과한다** | Swift `max`/`min`이 `y >= x ? y : x`라 `NaN` 비교가 전부 거짓. 코너는 D-4 가드가 막지만 **변 경로에는 가드가 없다** |
| 4 | **순서 교체는 변 드래그 결과도 바꾼다** | 원본 `(30, 100000)`의 `.right` → 구 `(7.68, 7680)` / 신 `(40, 40000)`. **"변 경로 무변경"이라고 쓰면 거짓** |
| 5 | **공유 `clamped`가 변 드래그의 불변 축을 바꾼다 (F-4)** | `50×100`의 `.right`를 중심까지 → `(40, 160)`. **이번 단위에서 고치지 않는다** — `EDITOR-11` 이월 |
| 6 | **극단 비율에서 오버플로우 → `NaN`** | `ratio = 1e300`은 **유한·양수라 가드를 통과**하는데 `rawH * ratio = ∞`, `k = 0`, `∞ × 0 = NaN` — **이월** |
| 7 | **`maxLongSide`가 `∞`·`NaN`이면 상한이 조용히 사라진다** | 코너는 막힌다. **변 경로는 안 막힌다** |
| 8 | **호출부가 `resizeLimits`를 쓴다는 것** | **규율이다.** 구조적 차단은 `ResizeLimits` 타입뿐인데 AC 6건이 두 인자 형태를 명시 — `EDITOR-11` 재판단 |
| 9 | **"고정점 유지" 단언이 변이를 죽인다는 것** | **죽이지 못한다.** 대수 항등. 기존 2건 + AC-1·4·5의 고정점 절이 그 상태. **실질 관측면은 `size`와 `topRight`** |
| 10 | **보정 블록이 무언가를 보장한다는 것** | 항등이다. 지워도 어떤 테스트도 차이를 관측 못 한다(~1e-13 ≪ 0.01) |
| 11 | **`ratio > 0` 가드가 테스트로 고정된다는 것** | **증인이 없다** — AC-7은 `worldPoint` 축만 잰다 |

### F-4 판정 — **② 고치지 않고 현행 동작 유지**

**근거**: ① AC가 없다(AC 추가는 설계 권한 밖) ② 고치려면 "변 드래그에서 하한·상한이 무엇을 뜻하는가"라는 **정책**을 새로 정해야 한다 ③ `EDITOR-6`이 `fitScale` 오버플로우를 같은 이유로 doc 정정 + 이월 처리한 선례.

**새 구조가 결함을 더 숨기지 않는지 확인했다.**

| 축 | 오늘 | 이 설계 이후 |
|---|---|---|
| 문서화 | **0줄** — doc은 "비율을 유지한 채 적용한다"뿐이고 그 문장은 코너 관점에서만 참 | ⚠️ 절에 **재현 입력과 실측값** |
| 가시성 | 두 호출이 **똑같아 보인다** | `aspectIfCollapsed: ratio` vs `nil`로 **눈에 띄게 갈라진다** |
| 범위 | 하한 발동 시 | **+ 순서 교체로 새로 하한이 발동하게 된 구간.** 범위가 **넓어진다** |

**가시성은 개선되지만 범위는 넓어진다** — 원장에 그대로 적는다.

---

## 산술 전개

`rot 0`에서 `cos(-0)=1`, `sin(-0)=-0.0`이므로 `toLocal`은 `(dx, dy)` 그대로다.

### 1. AC-1 — 회전 π/2 (특성화)

| 단계 | 전개 | 값 |
|---|---|---|
| `anchorLocal` (bl) | `(-100, 50)` | |
| `anchorWorld` | `(500 + (-100)(0) − 50(1), 400 + (-100)(1) + 50(0))` | **`(450, 300)`** |
| `dragLocal` | `dx=200, dy=-100`; `c=0, s=-1` → `x = 200(0) − (−100)(−1) = −100`, `y = 200(−1) + (−100)(0) = −200` | `(-100, -200)` |
| `rawW, rawH` | `0`, `250` | |
| `newW, newH` | `max(0, 500) = 500`, `250` | **`(500, 250)`** |
| clamp | 양쪽 스킵 (**두 순서 동일**) | 무변경 |
| `newCenterLocal` | `(-100 + 250, 50 − 125)` | `(150, -75)` |
| `result.center` | `(575, 550)` | |
| `result.corner(bl)` | `(450, 300)` = anchorWorld | 보정항 0 |

### 2. AC-2 (이진 정확)

| 캔버스 | `longSide` | `× 4` | 하한 |
|---|---|---|---|
| `(1080,1350)` | `1350` | **`5400`** | **`40`** |
| `(1080,1920)` | `1920` | **`7680`** | **`40`** |

`longSide → shortSide` 변이는 둘 다 `4320`을 내므로 AC-2가 죽인다.

### 3. AC-3

`dragLocal (99499, −100399)`, `rawW 99599`, `rawH 100449`, `newW = max(99599, 200898) = 200898`, `newH = 100449`.
`max 5400`: `200898 = 2 × 100449`이므로 `w = 5400`, `h = 2700` → **`(5400, 2700)`**.
`max 7680`: → **`(7680, 3840)`** (기존 테스트 5의 값과 동일 → 부등식 단언은 현재도 통과).

### 4. AC-4 · AC-5

**AC-4** `topRight → (400,450)`: `dragLocal = anchorLocal = (-100,50)` → `rawW=rawH=0` → `newW=newH=0`.
현재: `0 > 0` 거짓 → 전체 스킵 → **`(0,0)`** ← 버그.
신규: 씨앗 `(2,1)` → 상한 스킵 → 하한 `k=40` → **`(80,40)`** (이진 정확). `newCenterLocal (-60,30)`, center `(440,430)`, `bl = (400,450)` ✓

세로 검산: `ratio 0.5` → 씨앗 `(0.5,1)` → `k=80` → `(40,80)` ✓
극단 검산: `ratio 20000` → 씨앗 `(20000,1)` → 상한 `k=0.384` → `(7680,0.384)` → 하한 `k=104.1667` → `(800000,40)` = `40 × ratio` ✓

**AC-5** `topRight → (300,500)`: `dragLocal (-200,100)`, `rawW 100`, `rawH 50`, `newW = max(100,100) = 100`, `newH 50`, clamp 스킵. `newCenterLocal (-50,25)`, center `(450,425)`, `bl (400,450)` ✓ `tr (500,400)` ✓
`corner.sign` → 드래그 방향 부호 변이: 부호가 `(−1,+1)` → center `(350,475)`, `tr = (400,450)` ≠ `(500,400)` → **AC-5가 죽인다.**

### 5. AC-6

`ratio = 200`, `anchorLocal (-4000, 20)`.

**(a) `(4000,-20)`**: `rawW 8000`, `rawH 40`, `newW = max(8000, 8000) = 8000`, `newH 40`

| 순서 | 상한 | 하한 | 결과 |
|---|---|---|---|
| **현재** | — | `40 < 40` 거짓 스킵 | `k=0.96` → **`(7680, 38.4)`** ← 누수 |
| **신규** | `k=0.96` → `(7680, 38.4)` | `38.4 < 40`, `k = 40/38.4` | **`(8000.000000000001, 40)`** |

**(b) `(999999999,-999999999)`**: `rawW 1000003999`, `rawH 1000000019`, `newW = 200000003800`, `newH = 1000000019`. 상한 `k = 7680/200000003800` → `(7680, 38.4)`. 하한 → **`(7999.999999999999, 40)`**

**두 드래그가 같은 값에 수렴** ✓. 오차 `1e-12` → **`isClose` 필수, `==` 금지.**

임계 비율: `192`(9:16) · `135`(4:5).

### 6. AC-7 (현재 코드)

`toLocal`: `x = NaN×1 − (−100)(−0.0) = NaN`, `y = NaN×(−0.0) + (−100)(1) = NaN` → **한 성분이 두 성분으로 번진다** ✓
`newW = max(NaN, NaN)`: `NaN >= NaN` 거짓 → `NaN`. `clamped`: 세 비교 전부 거짓 → **`(NaN, NaN)`** → 네 필드 전부 `NaN`. **RED 확정.**

### 7. 기존 7건 — 신규 `clamped` 하 전건 재전개

| # | 테스트 | clamp 전 | 상한 | 하한 | 결과 | 판정 |
|---|---|---|---|---|---|---|
| 1 | 대각고정(0°) | `(300,150)` | 스킵 | 스킵 | `(300,150)` | **통과** |
| 2 | 대각고정(45°) | `(495.9798, 247.9899)` | 스킵 | 스킵 | 무변경 | **통과** |
| 3 | 비율유지 | `(700,350)` | 스킵 | 스킵 | 비율 2 | **통과** |
| 4 | 하한정지 | `(2,1)` | 스킵 | `k=40` | **`(80,40)`** | **통과** — 구 순서도 동일 |
| 5 | 상한정지 | `(200898, 100449)` | `k` | 스킵 | **`(7680,3840)`** | **통과** — 구 순서도 동일 |
| 6 | 변핸들 한 축 | `(300,100)` | 스킵 | 스킵 | `(300,100)` | **통과** |
| 7 | 변핸들 반대쪽 고정 | 동일 | 스킵 | 스킵 | `topLeft.x = 400` | **통과** |

**동시 발동 0건 ⇒ 순서 교체가 결과를 바꾸는 케이스 0건.** 붕괴 씨앗 발동 0건. 비유한 입력 0건. **깨지는 테스트 0건.**

### 8. F-4 재현

`(50,100)`의 `.right`를 로컬 x=0으로: `newW = 25`, `newH = 100`. `min = 25 < 40` → `k = 1.6` → **`(40, 160)`**. 높이 100 → 160.
반대쪽 변 고정은 유지: `deltaW = −10`, shift `−5`, `left = center.x − 25` = 원래 `left` ✓ — **깨지는 계약은 "한 축만"뿐.**

### 9. 순서 교체가 변 드래그를 바꾸는 반례

`(30, 100000)`의 `.right`를 로컬 x=85로 → `newW = 100`, `newH = 100000`

| 순서 | 하한 | 상한 | 결과 |
|---|---|---|---|
| 구 | `100 ≥ 40` 스킵 | `k = 0.0768` | `(7.68, 7680)` |
| 신 | — | `k = 0.0768` → `(7.68, 7680)` | `7.68 < 40`, `k = 5.2083…` → **`(40, 40000)`** |

---

## red-writer 필수 인계

1. **AC-1과 AC-5는 처음부터 GREEN이다. 그것이 정상이다.** RED 미성립을 사고로 보고하지 마라. 사이클 0은 프로덕션 0줄이며 두 건 다 통과해야 한다. 하나라도 빨강이면 설계 전개가 틀린 것이니 구현을 고치지 말고 보고하라.
2. **AC-3은 "컴파일 RED"다.** `LayerFrame.resizeLimits` 심볼이 생기는 순간 값 단언이 **즉시 통과한다** — 현재 클램프 동작이 이미 맞기 때문이다. AC-3의 고유 가치는 기존 `크기_상한에서_정지한다`의 **부등식**이 못 잡는 과잉 클램프를 정확값으로 잡는 것이다.
3. **AC-1의 `size == (500, 250)` 절을 절대 생략하지 마라.** 고정점 절은 **대수적으로 항상 참**이라 어떤 변이도 죽이지 못한다. `toLocal` 회전 부호 반전 변이를 죽이는 것은 **오직 이 `size` 절**이다.
4. **같은 이유로 AC-4의 `bottomLeft`·AC-5의 `bottomLeft`도 공허하다.** 실질은 AC-4의 `shortSide 40 / longSide 80`, AC-5의 `size (100,50)` + `topRight (500,400)`. 셋 다 필수.
5. **AC-6은 `isClose` 필수, `==` 금지.** 실측 `8000.000000000001` / `7999.999999999999`. 두 드래그를 **모두** 넣어야 "수렴"이 관측된다.
6. **AC-6은 순서 교체 변이의 단독 방어선이다.** 기존 4·5가 두 순서에서 같은 값을 내므로 다른 그물이 없다.
7. **AC-5는 `corner.sign` → 드래그 방향 부호 변이의 단독 방어선이다.**
8. **AC-2는 두 캔버스 4단언을 전부 써라.** 하나만 쓰면 "캔버스 인자 무시" 변이가 산다. `resizeLimits(...)` 반환값은 곱셈 결과이므로 `isClose`(상수 리터럴 `==` 선례를 여기 적용하지 마라).
9. **AC-7은 `isFinite` 4건만 단언하고 `resized == frame`은 쓰지 마라.** AC는 "원본으로 후퇴"를 **허용**할 뿐 요구하지 않는다.
10. **`private let minSide`/`maxSide` 2줄은 사이클 1의 REFACTOR에서 지운다.** 그 전에 지우면 컴파일이 안 된다.
11. **`private static let minShortSide`는 `@testable`로도 안 보인다.** 관측은 `LayerFrame.resizeLimits(canvas:).minShortSide` 경유가 유일하다.
12. **`abs()` 제거 변이는 AC-1이 죽인다** (오케스트레이터 검증 — architect의 최초 판단은 틀렸다). 90°에서 `rawH = −250`이 되어 `newW = max(0, −500) = 0` → 붕괴 → `(80,40)` ≠ `(500,250)`. **특성화 추가 불필요.**
13. **`ratio > 0` 가드 분기에는 이 단위의 증인이 없다.**

---

## 의존성 및 영향도

- **새 의존성·새 파일·새 타입 0.** Foundation만.
- **공개 API 추가 1건**: `LayerFrame.resizeLimits(canvas:)`. 기존 `public` 시그니처 변경 0건.
- **`private static func clamped`의 시그니처 변경은 파일 내부에 갇힌다**(호출부 2개, 같은 파일).
- **동작 변경 범위**: ① `(0,0)` 붕괴(코너 전용) ② 하한·상한 **동시** 발동(코너·변 공통) ③ 비유한 입력(코너 전용). 그 외 비트 단위 동일.
- **사용자 영향 없음** — 프로덕션 호출부 0건이라 `EDITOR-11` 배선 전까지 보이지 않는다.

**다음 단위로 넘기는 것**

| 항목 | 수신 |
|---|---|
| **F-4** — 공유 `clamped`가 변 드래그의 불변 축을 바꾼다. **하한 우선 도입으로 발동 구간이 넓어졌다** | `EDITOR-11` (정책 결정 선행) |
| `maxLongSide ≤ 0`에서 비율 소실 → `(0,0)` | `EDITOR-9`/`EDITOR-11` |
| 극단 비율 오버플로우 → `NaN` (진입 가드를 통과한다) | `EDITOR-9` |
| 변 드래그 경로에 FR-5 가드 없음 | `EDITOR-11` |
| `resizeLimits`를 **쓰도록 강제하는** 구조(`ResizeLimits` 타입) | `EDITOR-11` |
| `LayerStore` transform 쓰기 경로 부재 — **PRD가 "5번째 이월 불허"로 못 박음** | **`EDITOR-11` 착수 시 반드시** |
| `LayerTransform`이 균일 `scale` 하나뿐 (PRD 범위 밖 C′) | `EDITOR-11` |

## 탐색 추가 항목

- `ResizeAnchor.swift:94-114` → `clamped` 현행. `shortSide > 0`이 `(0,0)`을 스킵하는 지점
- `LayerFrame.swift:7-23` → `Corner.opposite.sign == −sign`이 네 케이스 전부 성립 — 보정 항등의 전제
- `LayerFrame.swift:66-81` → `toLocal`/`toWorld`가 아핀 — 항등의 나머지 전제
- `CanvasSurface.swift:32` → `zoomLimits`가 **튜플 정적 상수** — `resizeLimits` 반환 형태 선례
- `CanvasSurface.swift:70-80` → `workArea`. "캔버스 유도 정책값을 공개해 두 벌을 막는다" 선례(D-1에서 위치는 기각)
- `CanvasSurface.swift:97-104` → `toLogical`의 `guard s > 0` — EDITOR-6 이월이 이 단위 입력으로 새지 않는 이유
- `HandlePlacement.swift:69-95` → 접근 수준 혼재와 그 정리 — D-1의 판단 기준
- `LayoutDocument.swift:8-20` → `CanvasAspect`. **`SoozipGeometry`에서 참조 불가**
- `LayoutDocument.swift:166-168` → 캔버스를 검증 없이 디코딩 — `maxLongSide = 0` 도달 경로
- `CanvasSurfaceTests.swift:15,18` → `private let post`/`story` 명명 선례
- `HandlePlacementTests.swift:581-586` → 상수 리터럴 `==` 선례(적용 범위 주의)
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:291` → 하한·상한 원문

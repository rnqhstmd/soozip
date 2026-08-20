# 설계: EDITOR-9 — 캔버스 경계와 레이어 이탈

- 작성일: 2026-08-20 · 브랜치 `feat/editor-boundary` (base `main@9845830`)
- PRD: `.dev/feat-editor-boundary/prd.md` (FR 4 · BR 7 · **AC 22**)
- 설계 규모: **중형**. 신규 파일 2 + 기존 파일 1 수정(가시성 1줄 + doc). 기존 코드 **동작 변경 0건**.

## 1. 개요

두 개의 순수 함수를 낸다. 서로 코드를 한 줄도 공유하지 않아 파일도 둘로 가른다.

| 산출 | 위치 | 입력 | 왜 거기인가 |
|---|---|---|---|
| **겹침 3분류** (FR-1·FR-3) | `LayerFrame`의 인스턴스 메서드 | `Size2`만 | 캔버스 **크기**만 필요하고 줌·뷰포트와 무관 |
| **중심 클램프** (FR-2·FR-4) | `CanvasSurface`의 인스턴스 메서드 | `Vec2` | BR-4가 `workArea` 재사용을 강제 → 인스턴스가 반드시 필요 |

**FR-1을 `CanvasSurface`에 두지 않는 근거는 이 저장소에 이미 적혀 있다** — `ResizeAnchor.swift:36-39`: *"`CanvasSurface`의 파생 프로퍼티가 아니다. 한계는 뷰포트·줌과 무관한데 `surface.resizeLimits`로 두면 '줌하면 한계가 변한다'는 오해가 자연스러워지고, 언젠가 `scale`을 곱하는 변경이 합리적으로 보인다."* 겹침 분류에 그 논증이 글자 그대로 적용된다.

FR-2는 반대다. `workArea`가 `CanvasSurface`의 인스턴스 프로퍼티이므로 확장이 유일한 선택지다. 오해 위험은 `workArea`가 `canvas`에만 의존한다는 사실로 닫히고(`CanvasSurface.swift:76-80`), **AC-19가 그것을 실행으로 고정한다**(줌 4배·가로 뷰포트에서 같은 결과).

**`enum LayerBoundary` 네임스페이스를 쓰지 않는 이유**: `RotationSnap`이 `enum` 네임스페이스인 것은 "단위 규약을 가진 판정 본체 + 어댑터 4개"라는 응집된 규칙 덩어리였기 때문이다. 여기는 독립 함수 둘이라 묶으면 호출부만 길어진다.

## 2. API

### 2-1. `Sources/SoozipGeometry/LayerBoundary.swift` (신규)

```swift
public enum CanvasOverlap: Equatable, Sendable { case inside, partial, outside }

extension LayerFrame {
    public func overlap(canvas: Size2) -> CanvasOverlap
}

private struct Interval {
    let lower: Double
    let upper: Double
    init(projecting points: [Vec2], onto axis: Vec2)
    func overlaps(_ other: Interval) -> Bool   // lower <= other.upper && other.lower <= upper
    func contains(_ other: Interval) -> Bool   // lower <= other.lower && other.upper <= upper
}
```

- `Equatable`을 **명시적으로 적는다.** 연관값 없는 enum은 자동 합성되지만, 나중에 연관값이 붙는 순간 `==`가 조용히 사라지지 않고 컴파일 에러로 드러난다.
- 프로퍼티 이름이 `min`/`max`가 **아닌** 이유: 이니셜라이저 안에서 `min(a,b)`가 자기 프로퍼티를 가려 `cannot call value of non-function type 'Double'`이 난다 — `RotationSnap.swift:191-199`가 기록한 것과 같은 가림.
- `Interval`은 `private`. `SnapEngine`의 `AABB`(`SnapEngine.swift:30`)와 같은 등급이고, 네 부등호는 공개 표면의 AC-6·9·11·18이 전부 팽팽하게 고정한다(§5).

### 2-2. `Sources/SoozipGeometry/LayerCenterClamp.swift` (신규)

```swift
extension CanvasSurface {
    public func clampedLayerCenter(_ p: Vec2) -> Vec2 {
        guard p.x.isFinite, p.y.isFinite else { return canvasCenter }
        return clampedToWorkArea(p)
    }
}
```

**`Vec2 → Vec2` 시그니처가 이 단위에서 가장 중요한 API 결정이다.** BR-2("클램프는 `center`에만")가 **타입 사실**이 된다 — `size`·`rotation`이 시그니처에 없으므로 만질 수 없고, "바운딩 박스를 작업 영역에 맞추는" 변이는 **작성 자체가 불가능**하다(코너를 계산할 `size`가 없다).

> ⚠️ **그 결과 AC-13의 판정력이 줄어든다.** AC-13이 죽이는 것은 바운딩 박스 변이가 아니라(그건 타입이 막는다) off-by-one과 "무조건 `canvasCenter`로 밀기"다. PRD가 이 정정을 확정 이력 #13에 기록했다. **AC-13의 Given에 있는 `size 5000×5000`·`rotation π/4`는 테스트 코드에 등장하지 않는다.**

### 2-3. `Sources/SoozipGeometry/CanvasSurface.swift` (수정)

**① 가시성 변경 — `public` 제거 (동작 변경 없음)**

```swift
- public func clampedToWorkArea(_ p: Vec2) -> Vec2
+ func clampedToWorkArea(_ p: Vec2) -> Vec2      // internal
```

두 클램프가 **같은 타입 · 같은 시그니처 · 인접한 이름**이라 자동완성에 나란히 뜨고, `EDITOR-11`이 잘못 고르면 `∞ → (1620, 999)`·`NaN → (540, NaN)`이 나와 문서 저장이 깨지는데 **22개 AC가 전부 초록이다**(AC는 함수 축만 보고 BR-5는 호출부 축의 규칙이다). `internal`로 좁히면 그 경로가 컴파일 단계에서 사라진다.

**선례**: `ResizeAnchor.swift:11-20`이 같은 상황에서 `swiftc`로 "잘못된 변이가 컴파일된다"를 확인하고 이름을 갈라 막았다.

**영향 없음 확인**: 패키지 밖 소비자 0건(`centered(on:)`만 호출). 테스트는 `@testable import`라 `internal`에 접근한다. **`workArea` 프로퍼티는 `public` 유지** — 읽기 전용 기하 사실이라 오용 위험이 없고 `EDITOR-11`이 작업 영역을 그릴 때 필요하다.

**② doc 안내판 추가** — `clampedToWorkArea`에 *"레이어 `center`에는 쓰지 마라. 비유한 방어가 없어 `∞`가 `1620`으로 조용히 바뀌고 `NaN`은 그대로 통과한다. 레이어 중심은 `clampedLayerCenter(_:)`를 거친다."*

## 3. 알고리즘

```
overlap(canvas:)
 ①  유한성 가드: center.x · center.y · size.width · size.height · rotation
                  · canvas.width · canvas.height  — 스칼라 7개
                  하나라도 !isFinite, 또는 canvas 치수가 <= 0  →  .outside      [FR-3]
 ②  점 집합:     L = corner(4점),   C = (0,0)·(W,0)·(W,H)·(0,H)
 ③  포함 판정:   캔버스 축 2개(x,y)로  proj(C).contains(proj(L))  둘 다 참  →  .inside
 ④  분리 판정:   4축 x=(1,0) y=(0,1) u=(cosθ,sinθ) v=(−sinθ,cosθ) 중
                  하나라도  !proj(C).overlaps(proj(L))  →  .outside
 ⑤  그 외                                                          →  .partial
```

네 부등호가 전부 `<=`이고 예외가 없다 — **BR-6("포함 규칙을 두 갈래로 쪼개지 않는다")이 구조로 성립한다.**

### 3-1. 왜 SAT인가 — 네 AC가 각각 후보를 죽인다

| 구현 후보 | AC-4 (45° 다이아몬드) | AC-5 (`10×4000` 관통) |
|---|---|---|
| AABB 교차 | `.partial` ✗ | `.partial` ✓ |
| 코너 포함 검사만 | `.outside` ✓ | **`.outside` ✗** (양쪽 다 0개) |
| **SAT 4축 + 캔버스축 포함** | `.outside` ✓ | `.partial` ✓ |

AC-9는 "캔버스가 레이어 안이면 `.inside`"로 뒤집는 구현을, AC-11·18은 경계 부등호를 각각 고정한다.

### 3-2. 축을 `rotation`에서 만든다 (코너 차분 금지)

`corner(.topRight) − corner(.topLeft)`는 `size 0×0`에서 `(0,0)`이고 정규화하면 `(NaN, NaN)`이다. **AC-7·AC-8이 그 입력을 실제로 지나간다.** `cos`/`sin`은 크기와 무관하므로 퇴화가 발생하지 않는다.

### 3-3. 회전 0에서 4축이 2축으로 **정확히** 퇴화한다

`cos(0) = 1.0`·`sin(0) = 0.0`(정확값)이므로 `p·u = p.x + (±0.0) = p.x`, `p·v = (∓0.0) + p.y = p.y`가 **비트 단위로** 성립한다(실측). 따라서 AC-6·7·11의 경계 등식(`0<=0`, `1080<=1080`)에 반올림이 없다.

> ⚠️ **이 퇴화가 테스트 설계를 지배한다.** 회전 0인 입력으로는 `x`축·`y`축 삭제 변이를 **절대** 잡을 수 없다 — 쌍둥이 축(`u`≡`x`, `v`≡`y`)이 대신 분리하기 때문이다. **AC-21·22가 회전 30°인 이유가 이것이다.**

**중복 축이 오답을 만들지 않는 이유**: "어떤 축에서 분리됨"은 서로소임의 충분 증명이다. 축을 더 넣으면 증명 기회가 늘 뿐, 겹치는 두 도형에서 거짓 분리가 나올 수 없다(겹치면 공유점이 모든 축에서 두 구간 모두에 투영된다).

**포함 판정에 캔버스 축 2개만 쓰는 이유**: 볼록집합이 직사각형에 들어갈 필요충분조건은 **담는 쪽의 면 법선**이다. `u`·`v`를 넣으면 불필요하고(참일 때 항상 함께 참), `u`·`v`만으로 판정하면 더 약한 명제가 되어 틀린다.

### 3-4. 유한성 가드는 진입부, 스칼라 **7개** (증인은 캔버스 축에만 있다)

`corner(_:)` 호출 **이전**, 함수 최상단. `HandlePlacement.init`(`HandlePlacement.swift:128-133`)의 가드와 같은 형태다.

> ⚠️ **정정 (구현 후 실측으로 뒤집힘 — 이 문단은 이력 보존용이다).** 아래 주장은 **거짓이다.** 레이어 축 유한성 가드에는 **증인이 있다** — 실제 코드에 가드 제거 변이를 넣고 `swift test`를 돌리면 `레이어_값이_하나라도_비유한이면_완전히_밖이다`가 세 입력 전부에서 죽고, 가드 없는 결과는 `.outside`가 아니라 **`.inside`**(세 답 중 가장 위험한 오판)다.
> **원인**: 이 문단이 가정한 접기(`lo = min(lo, x)`, 첫 원소 시작)와 실제 구현(`reduce(±∞, min/max)`)이 다르다. 전 원소가 `NaN`이면 씨앗값 접기는 **뒤집힌 빈 구간**(`lower = +∞`, `upper = −∞`)을 만들고 `contains`가 공허하게 참이 된다.
> **원장은 프로덕션이다** — `LayerBoundary.swift`의 `overlap(canvas:)` doc를 보라. ⚠️ **이월 5번(힙 할당, 수신 `EDITOR-11`)이 `Interval`의 접기 형태를 건드린다** — 씨앗값을 버리는 수동 루프로 바꾸면 이 가드의 증인이 조용히 사라진다.

~~**레이어 축(5개)의 증인은 원리적으로 만들 수 없다.** 가드를 지워도 비유한 입력은 결국 `.outside`가 된다 — `size.width = ∞`, `rot = 0`이면 `y = 675 + (±∞ × 0.0) + (±100) = NaN`이고(`∞ × 0 = NaN`), `NaN` 비교가 전부 거짓이라 분리축이 발견된다. Python과 실제 Swift 양쪽에서 다섯 입력으로 확인했다.~~ (모델 기준 측정이었고 구현과 달랐다)

> **Swift `min`/`max`는 NaN에서 인자 순서에 의존한다** — `min(NaN,1.0)=nan`이지만 `min(1.0,NaN)=1.0`이다. 접기에서 NaN이 탈락할 수 있는 구조인데, FR-3의 레이어 축 경로는 **코너 4개의 같은 성분이 전부 오염**되므로 순서와 무관하게 살아남는다. 부분 오염은 발생 불가다 — 코너 4점이 같은 `(center, size, rotation)`에서 나온다.

**그래도 가드를 남기는 이유**: `overlaps`를 유한 입력에서 **완전히 동치인** `separated(other) = upper < other.lower || other.upper < lower`로 바꾸는 리팩터링이 들어오면, `NaN`에서 `separated`가 **거짓**이 되어 비유한이 전부 `.partial`로 뒤집힌다. 유한 입력에서 두 표현은 한 비트도 다르지 않으므로 **어떤 테스트도 이 리팩터링을 잡지 못한다.** 가드는 오늘은 중복이고 그날은 유일한 방어선이다. (`ResizeAnchor.swift:66-69`가 `worldPoint` 중복 가드를 같은 이유로 남겼다.)

**캔버스 축(2개)의 증인은 있다 — AC-20 3건.** 이쪽은 부분 오염이 실제로 일어난다:
- `canvas.width = NaN` → 캔버스 코너 x값이 `[0, NaN, NaN, 0]`이고 `min`·`max`가 **둘 다 `0.0`**이 되어 캔버스가 조용히 폭 0으로 퇴화한다(Swift 실측). ⚠️ **정정**: 초안은 이유를 *"첫 원소가 `0`이라"*로 적었으나 틀렸다 — 씨앗값 접기는 **순서가 무관**하고, 비-NaN 원소가 **하나라도** 있으면 위치와 상관없이 그것이 남는다(`[NaN,0,0,NaN]`도 `[0,0]`이 된다. 실측). **전부 NaN일 때만** 씨앗값이 남는다.
- `canvas.height = ∞` → 캔버스가 무한 띠가 되어 **모든 레이어가 `.inside`**가 된다. 가드가 막는 것 중 가장 파괴적이다.
- `canvas.width <= 0` → 좌우가 뒤집힌 사각형. `CanvasSurface.fitScale`이 `> 0`과 `isFinite`를 함께 보는 선례를 따른다.

### 3-5. 유한 입력에서 코너가 넘치는 구간 (가드하지 않음, 기록만)

유한 입력에서도 코너는 `±∞`가 될 수 있지만 **`NaN`은 되지 않는다** — `|c|,|s| ≤ 1`이라 `px*c`는 넘치지 않고, `(center.x + px*c) − py*s`에서 무한대 항이 최대 하나라 `∞ − ∞`가 성립하지 않는다. **`Double.greatestFiniteMagnitude` 투입으로 Swift 실측 확인**(NaN 0건). 도달 조건은 `EDITOR-7` 크기 상한(5400)과 이 단위의 중심 클램프(±2025)를 거치면 **불가능**하다. 어떤 답을 내야 하는지 원칙이 없으므로 답을 지어내지 않는다.

### 3-6. 회전 경계 오차 — 허용오차를 넣지 않는다

캔버스와 정확히 같은 크기인 레이어가 **90°·180°·270°·360°에서 `.inside`가 아니라 `.partial`**이 된다(Swift 실측). 살아남는 편차는 90°에서 `3.3065e-14`(=`540 × cos(π/2)`)이고 **360°가 그 4배**다.

**근거는 BR-6이 아니다** — BR-6이 금지하는 것은 케이스별로 다른 부등호이지 부등호의 느슨함이 아니며, 허용오차를 `Interval` 한 곳에 넣으면 규칙은 여전히 한 벌이다. 실제 근거:

> **고정 절대 허용오차는 원리적으로 충분할 수 없다.** 필요한 크기가 `R × 각도오차`인데 `R`은 `EDITOR-7` 상한까지 커지고, **각도오차는 누적 바퀴 수 `k`에 비례해 무제한으로 커진다**(`EDITOR-8`이 바퀴 수 보존을 확정해 `rotation = 2πk`가 저장 가능한 값이다). 어떤 상수도 충분한 `k`에 초과된다.

**`SnapEngine`과 다르게 답하는 것은 의도다.** `isAxisAligned`는 같은 현상을 버그로 판정해 각도 허용오차 `0.0001` rad로 고쳤다. `rotation = 2π`이고 캔버스와 같은 크기인 레이어에 대해 `isAxisAligned`는 **참**, `overlap(canvas:)`는 **`.partial`**이다. 실패의 성질이 다르기 때문에 정당화된다 — 스냅 후보 탈락은 회수 가능하고 단위가 각도(rad)이며, 이쪽은 좌표(px)라 상수로 닫을 수 없다.

**⚠️ `EDITOR-11` 인계 제약**: 이 결정은 `EDITOR-11`이 `.partial`을 **①프레임당 렌더 패스 트리거**나 **②사용자 신호**로 쓰지 않을 때만 무해하다. **착수 시 먼저 확인할 것.**

## 4. 변경 범위

| 종류 | 파일 |
|---|---|
| 신규 프로덕션 | `Sources/SoozipGeometry/LayerBoundary.swift` · `Sources/SoozipGeometry/LayerCenterClamp.swift` |
| 신규 테스트 | `Tests/SoozipGeometryTests/LayerBoundaryTests.swift` · `Tests/SoozipGeometryTests/LayerCenterClampTests.swift` |
| 수정 | `Sources/SoozipGeometry/CanvasSurface.swift` — `clampedToWorkArea` 가시성 1줄 + doc |
| 수정(코드 아님) | `docs/plans/2026-08-11-00-tdd-roadmap-v1.md` — 로드맵 총계 산술 정정. **이 단위 착수 직전에 별건으로 요청받아 수행한 것**이며 설계 산출물이 아니다. spec-reviewer가 "설계 범위 이탈"로 잡았기에 여기 기록해 둔다 — AC·BR과 무관하고 코드 동작에 영향이 없다 |

**손대지 않는 것**: `Package.swift`(타깃이 디렉터리 전체를 잡는다) · `SnapEngine.AABB`(BR-3이 사용 금지) · `LayerFrame`·`ResizeAnchor`(호출만).

## 5. 검증 표 — 22개 AC 전수, 오케스트레이터 실측

**설계안은 22개 AC 전부에서 PRD 기대값과 일치한다(불일치 0건).** 아래는 변이 킬셋 **실측**이다.

| 변이 | 죽이는 AC |
|---|---|
| AABB 근사(`u`,`v` 삭제) | AC-4, AC-17 |
| `x`축 삭제 | **AC-21** |
| `y`축 삭제 | **AC-22** |
| `u`축 삭제 | AC-4 |
| `v`축 삭제 | AC-17 |
| `contains`를 `<`로 | AC-6 |
| `overlaps` ①(`lower <= other.upper`)을 `<`로 | AC-11 |
| `overlaps` ②(`other.lower <= upper`)를 `<`로 | AC-18 |
| 캔버스 가드 제거(5스칼라만) | AC-20a, AC-20b, AC-20c |
| 레이어 가드 제거 | **`레이어_값이_하나라도_비유한이면_완전히_밖이다`** ⚠️ 초안은 "★ 0건 — 원리적으로 불가"였다. 구현 후 실제 코드 변이 측정에서 뒤집혔다(§3-4 정정 블록 참조) |
| 클램프에 `zoom` 곱하기 | AC-19 |
| 캔버스 경계로 클램프 | AC-12 |
| 비유한 클램프를 `clampedToWorkArea`로 | AC-14, AC-15 |

**네 분리축의 유일 증인**: `x`→AC-21 · `y`→AC-22 · `u`→AC-4 · `v`→AC-17. **어느 하나를 지우면 그 축이 무증인이 된다** — 각 테스트 주석에 명시한다.

## 6. 구현 순서 (RGR) — **순차**

```
사이클 1/2 — 겹침 3분류
   LayerBoundary.swift + LayerBoundaryTests.swift
   AC-1~11, 17, 18, 20, 21, 22 (17건)
        ↓ 커밋
사이클 2/2 — 중심 클램프
   LayerCenterClamp.swift + LayerCenterClampTests.swift + CanvasSurface.swift(가시성+doc)
   AC-12~16, 19 (6건)
```

**병렬로 돌리지 않는다.** 격리 단위가 파일이 아니라 **모듈**이다 — `SoozipGeometryTests`가 타깃 하나라, 사이클 2의 RED(아직 없는 `clampedLayerCenter` 호출)가 **모듈 전체를 컴파일 실패**시켜 사이클 1은 자기 RED조차 "단언 실패"로 관측할 수 없다. 게이트(`./scripts/test.sh`)도 하나라도 실패하면 exit 1이라 전부-아니면-전무다. 사이클이 둘뿐이고 병렬 이득은 `.build` 락 경합으로 상쇄된다.

## Testability 평가 (test-architect)

### 컴포넌트별 테스트 전략

**`LayerFrame.overlap(canvas:)`** — 단위 테스트만. 값 하나 + `Size2` 하나를 넣고 enum을 `==`로 단언, 셋업 0줄. 모의 대상 **없음**(I/O·시계·난수·전역 상태·async 전부 0, 의존성 Foundation뿐). 격리 전략은 값 의미론이며, **인자가 `Size2`라 `zoom`·`viewport`·`center`가 타입 수준에서 접근 불가**하다 — 줌 오염이 이 표면에서는 구조적으로 발생할 수 없다.

**`private struct Interval`** — 직접 테스트 **불가능**(`@testable`은 `internal`까지만). **격리하지 않는 것이 옳다** — `internal`로 열어 직접 테스트하면 부등호 규칙이 두 곳에 기술되어 이 저장소가 반복 거부한 형태가 된다. 네 부등호는 공개 표면만으로 전부 팽팽하게 고정된다(AC-6·9·11·18).

**`CanvasSurface.clampedLayerCenter(_:)`** — **이 단위의 유일한 진짜 통합 축.** `clampedToWorkArea`를 직접 호출하는 테스트가 현재 0건이고 `workArea`는 `centered(on:)` 경로로만 증인이 있다(`CanvasSurfaceTests.swift:188-199`). AC-12·19가 그 두 번째 증인 축이 된다. `CanvasSurface`가 `zoom`·`viewport`를 들고 있어 `overlap`과 달리 **오염 표면이 열려 있으므로, AC-19는 "있으면 좋은 것"이 아니라 이 배치 결정의 필수 대가다.**

### Testability Score: **9/10** — ✅ TESTABILITY PASS

**가점**: 두 컴포넌트 모두 순수 함수 + 값 타입, 모의 대상 0건, 완전 결정적. 22개 AC 전부가 공개 표면 호출 한 줄로 번역된다.

**감점 1점**: ① 레이어 축 유한성 가드에 **원리적으로 증인이 불가능**(설계 결함이 아니라 문제의 성질) ② `Interval`이 비공개라 부등호가 간접 관측만 되고 **각 분리축의 증인이 정확히 1건씩**이라 테스트 삭제에 취약 ③ 회전축의 부등호 경계는 `Interval` 단일 출처라는 구조적 사실에 의존해 고정된다.

### 테스트 설계 결정 5건

1. **한 AC = 한 `@Test`, 예외는 AC-10·AC-20**(각각 3입력 1테스트). 저장소의 분할선은 *"단언이 다르면 쪼개고, 같은 단언을 여러 입력에 반복하면 묶는다"*이다 — 묶은 선례 `ResizeAnchorTests.swift:484-509`(비유한 변형 **8종**을 라벨 튜플로 한 테스트), 쪼갠 선례 `RotationSnapTests.swift:161-180`(NaN과 ∞를 나누고 *"중복이 아니다"*를 주석으로). AC-10·20은 세 입력의 단언이 문자 그대로 같으므로 묶고, **라벨 튜플 + `#expect(..., "\(label)")`로 실패 귀속**을 만든다.
2. **enum은 `==`로 단언하고 `CustomStringConvertible`을 넣지 않는다.** `HandleHitTestTests.swift`가 12곳에서 이미 그렇게 하고 `Packages/` 전체에 채택 0건이다. 연관값 없는 enum의 `String(describing:)`은 케이스 이름을 그대로 낸다.
3. **클램프 결과는 성분별 `==`**(`결과.x == 1620`). 값이 전부 정확히 표현되고 연산이 선택·덧셈뿐이라 반올림이 없다. 성분별인 이유는 실패 시 어느 축인지 보이기 때문이다.
4. **AC-4·17에서 코너 좌표를 단언하지 않는다.** 좌표 원장은 `LayerFrameTests.swift:37-58`이 이미 갖고 있고, 다시 적으면 회전 공식의 두 번째 기술이 된다. 대신 **같은 테스트에서 그 입력의 AABB를 함께 판정해 대조**한다 — 회전본은 `.outside`, AABB 상당(`rotation 0`)은 `.partial`. 이 쌍이 (a) AABB 변이를 죽이는 이유를 자기완결적으로 만들고 (b) `corner(_:)`가 회전을 잃는 회귀도 잡는다. 부수 효과로 **사이클 1 테스트 파일에는 `Double` 단언이 한 건도 없어 `isClose`가 불필요해진다.**
5. **테스트가 규칙을 두 번째로 기술하지 않는다.** 임계·경계값은 프로덕션에서만 온다(`ResizeAnchorTests.swift:1-21` 관례).

### 테스트 함수명 (AC 22건 → `@Test` 22개)

> **정정**: 이 표제는 처음에 `20 @Test`로 적혀 있었다. AC-10·AC-20이 각각 3입력을 라벨 튜플로 묶는 것을 "AC 3건이 테스트 1건으로 합쳐진다"로 잘못 센 것이다 — 두 AC는 각각 **AC 1건**이고 그 안에서 입력만 3개다. 실제는 `LayerBoundaryTests` 16 + `LayerCenterClampTests` 6 = **22개**이고, AC와 1:1 대응한다(spec-reviewer가 잡았다).

**사이클 1 — `LayerBoundaryTests.swift` (15개)**

| AC | 함수명 | 고정하는 것 |
|---|---|---|
| 1 | `캔버스에_다_들어간_레이어는_완전히_안이다` | `.inside` 양성 분기 |
| 2 | `한쪽_경계를_넘으면_부분_겹침이다` | `.partial` 양성 + ③의 x축 검사 |
| 3 | `캔버스와_떨어진_레이어는_완전히_밖이다` | `.outside` 양성 |
| 4 | `회전한_레이어는_바운딩박스가_아니라_실제_형태로_판정한다` | **`u`축의 유일 증인** |
| 5 | `코너가_하나도_안_겹쳐도_몸통이_관통하면_부분_겹침이다` | 코너 포함 검사만 하는 구현 |
| 6 | `캔버스와_정확히_같은_레이어는_경계를_안쪽으로_쳐서_완전히_안이다` | **`contains` 두 부등호 양쪽** |
| 7 | `크기_0_레이어가_안에_있으면_완전히_안이다` | 퇴화 구간 포함 |
| 8 | `크기_0_레이어가_밖에_있으면_완전히_밖이다` | 퇴화 구간 분리 |
| 9 | `캔버스를_통째로_덮는_레이어는_완전히_안이_아니라_부분_겹침이다` | **`contains` 인자 순서** |
| 10 | `레이어_값이_하나라도_비유한이면_완전히_밖이다` | FR-3 레이어 축 3입력 (라벨 튜플) |
| 11 | `좌상단_한_점만_닿아도_완전히_밖이_아니라_부분_겹침이다` | **`overlaps` ①** |
| 17 | `x_y_u축이_다_겹쳐도_v축_하나가_분리되면_완전히_밖이다` | **`v`축의 유일 증인** |
| 18 | `반대쪽_모서리에_한_점만_닿아도_부분_겹침이다` | **`overlaps` ②** |
| 20 | `캔버스_치수가_비유한이거나_0_이하면_완전히_밖이다` | **캔버스 가드** 3입력 (라벨 튜플) |
| 21 | `회전한_레이어가_x축에서만_분리되면_완전히_밖이다` | **`x`축의 유일 증인** |
| 22 | `회전한_레이어가_y축에서만_분리되면_완전히_밖이다` | **`y`축의 유일 증인** |

**사이클 2 — `LayerCenterClampTests.swift` (6개)**

| AC | 함수명 | 고정하는 것 |
|---|---|---|
| 12 | `중심은_캔버스가_아니라_작업_영역_경계에서_잘린다` | 경계값 원장 `(1620, 2025)` |
| 13 | `작업_영역_경계에_있는_중심은_안쪽으로_당겨지지_않는다` | off-by-one · 무조건 밀기 |
| 14 | `무한대_중심은_경계로_잘리지_않고_캔버스_중심으로_후퇴한다` | `min/max(∞)=1620` 조용한 유한화 |
| 15 | `NaN_중심도_무한대와_같은_캔버스_중심을_낸다` | `min/max(NaN)` 통과 |
| 16 | `이미_작업_영역_안인_중심은_두_번_클램프해도_그대로다` | 멱등성 |
| 19 | `클램프_결과는_줌과_뷰포트에_무관하다` | **`zoom` 곱하기 변이** |

### 프로덕션 주석에 기록할 무증인 항목

> ⚠️ **정정**: 초안은 "무증인 2건"이었고 1번이 레이어 축 유한성 가드였다. **구현 후 실측에서 그 가드에는 증인이 있는 것으로 드러났다**(§3-4 정정 블록). 따라서 **실제 무증인은 2번 하나뿐**이다. 이 절을 고치지 않으면 **설계서가 프로덕션에게 이미 반증된 문장을 적으라고 지시**하게 되고, 다음 spec-reviewer가 대조할 때 정확한 프로덕션 doc이 거꾸로 "설계 위반"으로 잡힌다.

1. ~~**레이어 축 유한성 가드** — §3-4 문단 전체.~~ → **증인 있음으로 정정됨.** 프로덕션 doc에 적을 것은 "무증인"이 아니라 **"이 가드의 증인은 `reduce`의 `±∞` 씨앗값이 만든다 — 씨앗값을 없애는 리팩터링은 동작을 안 바꾸면서 증인만 지운다"**이다.
2. **회전축 부등호의 경계**는 `Interval` 단일 출처 덕에 `x`/`y` 증인이 대신 지킨다. **축별로 비교를 인라인/분기시키면 회전축 부등호가 즉시 무증인이 된다.** 지금 회전 접선 케이스를 넣는 것은 순수 중복이므로 넣지 않고 기록만 한다.

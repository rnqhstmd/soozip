# 설계: EDITOR-10 — 제스처 라우팅

> 설계 규모: **대형** — 신규 3 + 수정 6 + 삭제 1이 **3개 타깃**(SoozipGeometry · SoozipLayout · 앱)에 걸치고, 공개 API 가시성을 두 패키지에서 좁힌다.
>
> 개정 이력: 1차본 → design-critic(MUST-ADDRESS 5 · CONSIDER 9) + test-architect(PASS 9/10 · 필수 정정 3 · 재배치 2) + 사용자 결정 2건을 반영한 2차본.

## 개요

두 개의 서로 독립인 산출물을 낸다. 코드를 한 줄도 공유하지 않으므로 파일도 가른다.

| 산출 | 위치 | 무엇 |
|---|---|---|
| **라우팅 상태 기계** (FR-1~4) | `SoozipGeometry/GestureRouter.swift` | 입력 어휘 `FingerPattern` 3종 · 출력 어휘 `GestureRoute` 4종 · 배타 잠금을 든 불변 값 `GestureRouter` |
| **중심 변경 게이트** (FR-5·BR-7) | `SoozipGeometry/ClampedLayerCenter.swift` + `SoozipLayout/LayerPlacement.swift` + `SoozipLayout/LayerStore.swift` | 클램프를 통과했다는 것을 **타입이 증언하는 토큰** 하나와, 그 토큰만 받는 이동 API 셋(기하·모델·저장소 각 1) |

라우팅은 값을 계산하지 않는다(BR-1). 게이트는 값을 계산하지만 **모듈 밖에서는 클램프 밖의 값을 만들 수 없다.**

## 타입 설계

### 1. 입력 어휘 — `FingerPattern`

```swift
/// v4 §5.9 우선순위 표의 **열**. 손가락 패턴은 이미 분류되어 들어온다(BR-3).
///
/// `HandleGesture`(tap/drag)와 **이름도 축도 다르다**. 그쪽은 "이 히트를 어떤
/// 제스처로 볼 것인가"(핸들 판정의 필터)이고, 이쪽은 "몇 손가락이 어떻게
/// 움직이는가"(라우팅 표의 열)다. 둘을 한 타입으로 합치면 `.drag`가 1손가락인지
/// 2손가락인지 알 수 없어 §5.9 표를 판정할 수 없다.
public enum FingerPattern: Equatable, Sendable {
    case oneFingerDrag
    case twoFingerPinchRotate
    case twoFingerDrag
}
```

- **BR-5는 이 타입이 전부다.** 손가락 **수를 필드로 받지 않으므로** 0개·3개 이상을 표현할 방법이 없다. `count: Int`를 받는 순간 `0`과 `5`가 표현 가능해지고, 표에 없는 분기가 판정 안에 생긴다.
- **`twoFingerPinch`가 아니라 `twoFingerPinchRotate`다.** 표의 셀이 "핀치·회전"이고, 이름을 줄이면 언젠가 `twoFingerRotate`를 네 번째 케이스로 추가하는 변경이 자연스러워 보인다 — 그 순간 BR-3("3종 한정")이 조용히 깨진다.
- **`CaseIterable`을 붙이지 않는다** — `HandleGesture.swift:12-16`의 선례와 같은 이유(전 케이스를 순회할 프로덕션 소비자가 0건). AC-1~6은 6쌍을 **명시 리터럴 배열**로 순회한다(`LayerCenterClampTests.swift:74`의 `for (라벨, s) in [...]` 관례. `@Test(arguments:)`는 저장소 실적 0건).
- `Equatable`을 **명시한다.** 연관값 없는 enum은 자동 합성되지만, 나중에 연관값이 붙으면 `==`가 조용히 사라진다 — `CanvasOverlap`(`LayerBoundary.swift:5`)이 같은 이유로 명시했다.

### 2. 출력 어휘 — `GestureRoute`

```swift
/// v4 §5.9 표의 **셀** 4종. 이 타입에 좌표·배율·각도가 없는 것이 BR-1의 전부다.
public enum GestureRoute: Equatable, Sendable {
    case moveLayer
    case resizeRotateLayer
    case panCanvas
    case zoomCanvas
}
```

- **`case idle`을 넣지 않는다.** 유휴는 `GestureRouter.active`의 `nil`이다. `HandleHitTest.swift:92-93`이 같은 결정을 기록했다 — *"'핸들 아님'을 별도 케이스로 만들지 않는다. `Optional`이 이미 그 뜻이고, `box: Box?`·`LayerStore.selection: Entry?`와 같은 표현이다."*
- **AC-15는 `Optional` 쪽이 더 자연스럽다.** `case idle`이면 "유휴에서 종료"가 `.idle → .idle` 케이스 전이가 되어 **switch 안에 관측되지 않는 분기**가 생긴다. `Optional`이면 `GestureRouter.idle.ended() == .idle`이라는 값 동등성 한 줄이다.
- `transformLayer`가 아니라 `resizeRotateLayer`다 — "transform"은 이동까지 포함해 `.moveLayer`와 경계가 흐려진다.

### 3. 상태 — `GestureRouter`

```swift
/// "지금 이 터치의 임자가 누구인가"를 **하나만** 붙잡고 있는 값 (v4 §13).
public struct GestureRouter: Equatable, Sendable {

    /// 활성 라우팅. 없으면 유휴.
    public private(set) var active: GestureRoute?

    /// **유일한 시작점.** `init`이 `private`이라 밖에서 임의의 활성 상태를 만들 수 없다.
    public static let idle = GestureRouter()
    private init() {}

    /// 시작 신호. **활성 중이면 무시하고 자기 자신을 낸다**(FR-3, §13 "먼저 시작된 쪽만 유지").
    public func started(_ pattern: FingerPattern, hasSelection: Bool) -> GestureRouter

    /// 종료 신호. 유휴로 돌아간다. **유휴에서 불러도 유휴다**(FR-4·AC-15).
    public func ended() -> GestureRouter

    /// v4 §5.9 표 그 자체. **`private`이다.**
    private static func route(_ pattern: FingerPattern, hasSelection: Bool) -> GestureRoute
}
```

**불변 값 + 전이 함수를 고른 근거:**

| | 근거 |
|---|---|
| 기존 문법 | `CanvasSurface`가 정확히 이 형태다 — `private(set)` 저장 프로퍼티 + `zoomed(to:)` · `centered(on:)` · `fitted()` · `viewportChanged(to:)`. **한 개도 `mutating`이 아니다** |
| `LayerStore`의 `mutating`을 따르지 않는 이유 | 그쪽은 **컬렉션 소유자**(`storage: [Entry]`)이고 배열 재배치가 본체다. 라우터는 필드 하나짜리 파생 상태다 |
| 테스트 | AC-7~13은 전이 **열**이다. `let a = .idle.started(…); let b = a.started(…)`가 중간 값을 전부 남긴다 |
| AC-15 | `#expect(GestureRouter.idle.ended() == .idle)` 한 줄 |
| EDITOR-11 배선 | SwiftUI `@State`에 `router = router.started(…)`로 대입 — `onChanged`/`onEnded`와 이름이 정렬된다 |

**`private init` + `static let idle`이 만드는 타입 사실:** 활성 상태는 **`started`를 통과해야만** 존재한다. AC-7~13의 Given("이미 활성 중")을 테스트가 날조할 수 없고, 반드시 진짜 전이를 지난다. test-architect 판정: 격리는 한 단계 나빠지지만(전이 2개가 한 테스트에 들어감) **거짓 초록 한 종류가 원천 제거되므로 순증**이다. 동반 적색 성질을 테스트 doc에 남길 것 — *"AC-7~13이 빨가면 먼저 AC-1~6을 보라. 표가 깨져도 여기가 함께 빨갛다."*

**`route(_:hasSelection:)`가 `private`인 이유가 이 설계에서 가장 중요한 가시성 결정이다.** `public`으로 열면 배선이 **매 프레임 이 함수를 부르는 경로**가 생기는데, 그것이 정확히 §13이 경고한 "동시에 물려 레이어가 순간이동"이다. 표는 `started`를 통해서만 닿아야 한다. (`HandleGesture.accepts(_:)`가 `internal`인 것과 같은 형태의 결정이며, 그 doc이 남긴 단서도 같다 — **"재사용만 막고 복제는 못 막는다."**)

**표는 6개 arm 전부를 명시하고 `_` 와일드카드를 쓰지 않는다.**

```swift
switch (pattern, hasSelection) {
case (.oneFingerDrag,        true):  return .moveLayer          // AC-1
case (.twoFingerPinchRotate, true):  return .resizeRotateLayer  // AC-2
case (.twoFingerDrag,        true):  return .panCanvas          // AC-3
case (.oneFingerDrag,        false): return .panCanvas          // AC-4
case (.twoFingerPinchRotate, false): return .zoomCanvas         // AC-5
case (.twoFingerDrag,        false): return .panCanvas          // AC-6
}
```

`case (.twoFingerDrag, _)`로 두 줄을 합치면 짧아지지만, **`FingerPattern`에 케이스를 추가하는 변경이 조용히 컴파일된다.** 6 arm 전수 열거는 컴파일러를 BR-3의 감시자로 만든다(`HandlePlacement.edgeOrder`가 `Edge.allCases`를 피한 것과 같은 계열).

**`hasSelection: Bool`의 위험을 기록한다.** 인자가 `Bool` 하나뿐이라 `store.selection == nil`을 반대로 넘겨도 컴파일된다. 결과는 "선택했는데 캔버스가 팬되는" 조용한 오작동이고 라우터 테스트는 전부 초록이다. **인자 라벨이 유일한 방어선이다** — `RotationSnap`이 도/라디안 오배선에 대해 남긴 문장과 같은 상황이다.

### 4. AC-7~13의 입력 인코딩

이 단위의 입력은 `started`·`ended` **둘뿐**이다. "손가락이 하나 더 닿았다"는 EDITOR-11에서 새 제스처의 시작으로 도착하므로 **새 시작 신호**로 인코딩된다. 7건이 서로 다른 삼중을 갖는 것을 여기서 고정한다 — 그러지 않으면 AC-7과 AC-10이 글자 그대로 같은 호출이 되어 AC-18이 삭제된 이유(PRD 확정 이력 6)를 되풀이한다.

**변이 = 활성 가드 제거(매 `started`마다 재판정). 7행 전수 계산 결과:**

| AC | 활성 | 2차 `started` | 기대 | 변이 시 | 판정 |
|---|---|---|---|---|---|
| 7 | `.moveLayer` | `(.twoFingerDrag, true)` | `.moveLayer` | `.panCanvas` | **죽임** |
| **8** | `.panCanvas` | `(.oneFingerDrag, false)` | `.panCanvas` | `.panCanvas` | **살아남음** |
| 9 | `.moveLayer` | `(.oneFingerDrag, false)` | `.moveLayer` | `.panCanvas` | **죽임** |
| 10 | `.moveLayer` | `(.twoFingerPinchRotate, true)` | `.moveLayer` | `.resizeRotateLayer` | **죽임** |
| 11 | `.zoomCanvas` | `(.oneFingerDrag, false)` | `.zoomCanvas` | `.panCanvas` | **죽임** |
| 12 | `.panCanvas` | `(.twoFingerPinchRotate, false)` | `.panCanvas` | `.zoomCanvas` | **죽임** |
| 13 | `.resizeRotateLayer` | `(.twoFingerDrag, true)` | `.resizeRotateLayer` | `.panCanvas` | **죽임** |

**6행이 죽이고 AC-8 하나만 살려 보낸다.**

> ⚠️ **1차본은 이 표를 정반대로 적었다**("AC-9가 유일한 강증인이고 나머지는 통과시킨다"). 오기였고, 이 저장소가 신뢰하는 "측정된 변이 킬셋" 원장에 검증되지 않은 항목이 들어갈 뻔했다. test-architect가 잡았고 오케스트레이터가 7행을 독립 재계산해 확인했다. **이 표가 정정본이다.**

**테스트 파일 doc에 그대로 들어갈 문구:**

> 이 7건 중 **6건**이 "활성 가드 제거 후 매 `started`마다 재판정" 변이를 죽인다. **AC-8만 살려 보낸다** — 선택 없음에서는 1손가락 드래그와 2손가락 드래그가 **둘 다** 캔버스 팬이라(AC-4·AC-6) 재판정해도 답이 같기 때문이다. 인코딩 실수가 아니라 PRD Given의 성질이고, **PRD를 바꾸지 않는 한 강화할 수 없다.**

**FR-2 절에는 독립 증인이 없다.** 입력이 `started`·`ended` 둘뿐이라 "선택 상태가 바뀌었다"·"손가락 수가 바뀌었다"를 알릴 입력이 애초에 없다. AC-7·8·9를 `started(…)`로 인코딩한 것은 **FR-3의 입력 그 자체**다. 즉 **FR-2 절이 실제로 재는 것은 FR-3이며, FR-2에는 관측 가능한 입력이 존재하지 않는다.** AC-9를 지우지 않는 이유는 위 6행 중 하나이기 때문이고, FR-2의 증인이라서가 아니다. 이 문장을 `GestureRouter.started` doc과 테스트 파일 doc 양쪽에 남긴다.

**AC-15의 킬셋은 하나다.** `ended()`가 `.idle`을 내든 `self`를 내든 유휴에서는 같은 값이고, 활성에서의 차이는 AC-14가 잡는다. **이 단언을 죽이는 변이는 `precondition(active != nil)` 같은 것을 넣는 변이 하나뿐이다.** PRD가 "크래시나 예외 없이"를 요구했으니 요구사항과는 정확히 일치한다 — 다만 판정력을 과대평가하지 않도록 이 한 줄을 테스트 doc에 적는다.

**AC-9의 이중성.** 이 잠금의 UX 귀결은 "조용한 무시"가 아니라 **"한 제스처 동안 먹통"** 이다. 활성이 `.moveLayer`인데 대상이 없으면 소비자가 무시하고, 그동안 **캔버스 팬도 거부된다**(FR-3). 손을 뗄 때까지 아무것도 움직이지 않는 구간이 사용자에게 보인다. 게다가 **드래그 중 선택이 사라지는 실제 경로가 이 앱에서 확인되지 않는다** — 삭제는 ✕ 핸들 **탭**이고, 로컬 단일 사용자라 동시성이 없다. 도달 경로가 없다면 **AC-9는 UX 방어가 아니라 순수 변이 킬러**다. 두 성격을 함께 doc에 적는다.

## FR-5 봉쇄 설계

### 사실 정정 2건

**정정 1.** `private(set)`은 `ResizeAnchor.swift:148-149`(`result.center.x += …`)를 깬다 — Swift에서 멤버의 `private`은 **같은 파일**까지다. 필요한 것은 `internal(set)`이고, 막고 싶은 것이 정확히 모듈 밖이다.

> 오케스트레이터 실측(2026-08-22, 별도 모듈 2개로 `swiftc` 컴파일):
> | 모듈 밖 소비자 | 결과 |
> |---|---|
> | `f.center = p` | **컴파일 실패** — `'center' setter is inaccessible` |
> | `f.center.x += 99999` | **컴파일 실패** — `left side of mutating operator isn't mutable` |
> | `F(center: p, size: f.size)` | **컴파일 성공 → `(99999, 99999)` 산출** |
> | (모듈 **안**) `.center.x += ` | **컴파일 성공** |
> | `internal(set)` + `Codable` 합성 왕복 | **성공** — 합성 `init(from:)`은 setter 접근 수준의 영향을 받지 않는다 |
>
> 봉쇄와 누수가 둘 다 설계 주장 그대로임이 실증됐다. 추정이 아니라 이 측정값을 프로덕션 원장에 적는다.

**정정 2 (1차본이 틀렸다).** `LayerStore`의 public mutating은 `select`(:110) · `deselect`(:115) · `insert`(:129) · `remove`(:159) · `bringToFront`(:168) · `sendToBack`(:174) · `bringForward`(:178) · `sendBackward`(:182) **8개뿐이고 중심을 바꾸는 것이 하나도 없다.** `storage`는 `private`(:52), `entries`(:69)·`layers`(:93)는 get-only다.

1. 오늘 "이미 존재하는 레이어의 중심을 바꾸는 공개 경로"는 1개가 아니라 **0개**다. 1차본이 "참인 문장"이라고 적은 것조차 과장이었다.
2. EDITOR-11은 `LayerStore`에 mutating 함수를 **반드시 새로 만들어야** 하고, 그것은 `SoozipLayout` **모듈 안**이라 `Layer.swift`의 `internal(set)`이 아무것도 막지 않는다.
3. 따라서 1차본의 *"토큰을 통과하지 않고는 저장 상태가 될 수 없다"* 와 대안 표의 *"모델 저장 경로 ✔ 닫힘"* 은 **거짓이다.**

**이 단위가 실제로 할 수 있는 일은 봉쇄가 아니라 선점이다** — 아직 비어 있는 그 자리에 **옳은 것을 먼저 놓아**, EDITOR-11이 새 경로를 발명할 이유를 없앤다.

### 대안 비교

| | A. 게이트 함수만 | B. A + `center` `internal(set)` | C. 토큰 + `placed(at:)`(기하) | D. C + `LayerTransform` 봉쇄 | **E. D + `LayerStore.place`** | F. `init`이 토큰 요구 |
|---|---|---|---|---|---|---|
| **수정할 호출 지점** | 0 | 1 (`S1:76`) | 1 | 1 + **0**(`transform.x/y` 대입 0건) | 1 + 0 + **`LayerStore.swift` 1파일** | **79**(비테스트 7·테스트 72) |
| 모듈 **밖** 대입 (`frame.center =`) | ✗ | ✔ 닫힘 | ✔ | ✔ | ✔ | ✔ |
| **`init` 우회로** | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ |
| **`ResizeAnchor` 2곳**(`:123`·`:246`) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ 구현 불가 |
| **`LayerStore`에 옳은 중심 변경 경로가 존재** | ✗ 0개 | ✗ 0개 | ✗ 0개 | ✗ 0개 | **✔ 1개 — 이 단위가 낸다** | ✗ 0개 |
| **`SoozipLayout` 모듈 내부 우회** | ✗ | ✗ | ✗ | **✗ 열림**(1차본 오기) | **✗ 열림 — 선점만 한다** | ✗ |
| 클램프가 모듈 경계를 넘는가 | ✗ | ✗ | ✔ | ✔ | ✔ | — |
| AC-16·17이 새 경로를 지나는가 | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| 실현 가능성 | ✔ | ✔ | ✔ | ✔ | ✔ | **✗ 불가** |

**F 기각(비용이 아니라 불가능):** `Layer.frame(baseSize:)`·`ResizeAnchor.swift:123`·`:246`은 **표면이 없는 자리**다. 토큰을 요구하면 `CanvasSurface`를 영속화 변환과 `LayerFrame` 내부 계산까지 끌고 들어가야 하고, 그것은 "`LayerFrame`은 `CanvasSurface`를 모른다"는 층 구조를 뒤집는다.

**A·B 기각:** 가장 짧은 경로가 여전히 `frame.center = p`이고, 저장소의 유일한 실제 소비자(S1 프로브)가 정확히 그것을 쓴다.

**C·D 기각:** 레이어의 저장 상태는 `LayerFrame`이 아니라 `LayerTransform.x`/`y`이고, 그 값을 바꾸는 코드는 **`LayerStore` 안**에 생긴다. C·D는 그 자리를 비워 두고 문 앞만 잠근다.

### 선택: **E** (사용자 결정)

```swift
// ── Packages/SoozipGeometry/Sources/SoozipGeometry/ClampedLayerCenter.swift (신규)

/// **인자로 준 표면의** 작업 영역 안으로 잘린 레이어 중심.
///
/// 생성자가 하나뿐이고 그 안에서 `clampedLayerCenter(_:)`를 부른다.
///
/// ⚠️ **이 타입이 증언하는 것은 "어떤 표면에 대해 잘렸다"이지 "이 문서의 작업
/// 영역 안이다"가 아니다.** `CanvasSurface.init(canvas:viewport:)`(`:34`)는
/// `canvas`를 **검증하지 않는다** — 네 필드를 그대로 대입할 뿐이고 `fitScale`만
/// 따로 가드한다. 그래서
/// `ClampedLayerCenter(p, on: CanvasSurface(canvas: Size2(width: 1e9, height: 1e9),
/// viewport: .zero))`는 `(99999, 99999)`를 그대로 담은 토큰을 낸다. 위조는 한
/// 줄이고 컴파일러가 막지 않는다. 같은 성질의 **도달 가능한** 형태가 위험 3이다.
public struct ClampedLayerCenter: Equatable, Sendable {
    public let value: Vec2

    /// **유일한 생성 경로.** 표면 없이는 만들 수 없다.
    public init(_ point: Vec2, on surface: CanvasSurface) {
        value = surface.clampedLayerCenter(point)
    }
}

extension LayerFrame {
    /// 레이어 중심을 바꾸는 기하 계층의 이동 경로.
    ///
    /// **인자로는 `size`·`rotation`에 닿을 수 없지만 `self`로는 닿는다.**
    /// `clampedLayerCenter`의 `Vec2 → Vec2`는 자유 함수라 크기 축이 문법적으로
    /// 없었지만, 이 함수는 `LayerFrame`의 메서드라
    /// `LayerFrame(center: c.value, size: .zero, rotation: 0)`이 **그대로
    /// 컴파일된다.** 크기·회전 보존은 타입이 아니라 **테스트가 막는다**.
    public func placed(at center: ClampedLayerCenter) -> LayerFrame
}
```

```swift
// ── Packages/SoozipLayout/Sources/SoozipLayout/LayerPlacement.swift (신규)
extension LayerTransform {
    /// 저장 좌표를 바꾸는 모델 계층의 이동 경로. 나머지 네 필드를 보존한다.
    ///
    /// **`LayerTransform(x:y:)`로 다시 만드는 우회로와 갈리는 지점이 여기다** —
    /// 그 생성자는 `scale`·`rotation`·`opacity`·`z`에 전부 기본값이 있어
    /// (`Layer.swift:44-48`) 우회하면 클램프만 빠지는 것이 아니라 **네 필드가
    /// 조용히 리셋된다.**
    public func placed(at center: ClampedLayerCenter) -> LayerTransform
}
```

```swift
// ── Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift (수정: import + 메서드 1)
+ import SoozipGeometry

// ⚠️ 다른 파일의 `extension LayerStore`로는 구현할 수 없다 — `storage`가
//    `private`(:52)이라 같은 파일 밖에서는 닿지 않는다. 이 메서드는 반드시
//    LayerStore.swift 안에 있어야 한다.

    /// 레이어를 옮긴다. **저장 상태의 중심이 바뀌는 유일한 공개 경로다.**
    ///
    /// **이름이 `move`가 아니다.** 같은 타입에 `private mutating func move(_:to:)`
    /// (z-order, `:190`)가 이미 있고, `move(id, to: token)`과
    /// `move(id, to: closure)`는 인자 타입만 다른 오버로드가 되어 자동완성에
    /// 나란히 뜬다. 이름을 갈라 그 혼동을 컴파일 단계에서 없앤다.
    ///
    /// **없는 식별자는 조용히 무시한다** — `move(_:to:)`(`:188-189`)·`remove(_:)`와
    /// 같은 관례이고, PRD BR-6("레이어 라우팅 결과는 대상 존재를 보장하지
    /// 않는다 — 없으면 크래시 없이 조용히 무시")과 정확히 같은 계약이다.
    /// **`Bool`을 반환하지 않는 이유**: 반환하면 호출부가 분기하게 되는데,
    /// BR-6이 요구하는 것은 분기가 아니라 무시다.
    ///
    /// **`transform.placed(at:)`에 위임한다** — 여기서 `x`/`y`를 직접 쓰면
    /// 규칙이 두 벌이 되고, 그때 한쪽만 나머지 네 필드를 보존한다.
    ///
    /// ⚠️ **이 함수가 있다고 두 번째 경로를 못 만드는 것이 아니다.**
    /// `storage`가 `private`이라 **이 파일 안에서는** `storage[i].layer.transform.x = …`가
    /// 그대로 컴파일된다(오케스트레이터 실측 확인). 이 함수가 하는 일은 봉쇄가
    /// 아니라 **선점**이다 — EDITOR-11이 없는 경로를 발명하는 대신 있는 경로를 쓰게 한다.
    public mutating func place(_ id: UUID, at center: ClampedLayerCenter)
```

```swift
// ── 가시성 축소 3건
// LayerFrame.swift:54       public var center              → public internal(set) var center
// LayerCenterClamp.swift:67 public func clampedLayerCenter → (internal)
// Layer.swift:37-38         public var x / y               → public internal(set) var x / y
//   ⚠️ `scale`(:39)은 열어 둔다 — 크기 축에는 강제할 계약이 없다(누수 8).
```

**토큰이 함수 게이트보다 나은 이유:** `clampedLayerCenter`는 `CanvasSurface`의 메서드이고 `CanvasSurface`는 `viewport`를 요구한다. 모델·저장소 계층에는 뷰포트가 없다. 함수 게이트라면 `SoozipLayout`이 `CanvasSurface(canvas: doc.canvas, viewport: .zero)` 같은 **가짜 뷰포트**를 지어내야 한다(`fitScale`이 0이 되는 값이다). 토큰은 **표면을 가진 쪽(뷰)에서 만들어 표면이 없는 쪽으로 내려간다.**

### AC-16·17이 새 경로를 지날 수밖에 없게 만드는 구조

1. **`clampedLayerCenter`를 `internal`로 좁힌다.** 공개 표면에서 사라지므로 프로덕션 소비자의 진입점은 토큰뿐이다. `EDITOR-9`가 `clampedToWorkArea`에 한 조치와 같고 근거도 같다(`CanvasSurface.swift:97-103`). 비용 0 — 현재 호출자는 `@testable` 테스트뿐이다.
2. **단언 대상을 `Vec2`가 아니라 `LayerFrame.center`로 못박고, 크기·회전 보존을 함께 단언한다.**
3. **픽스처 center는 캔버스 중심과 두 축 모두 달라야 한다.**

```swift
private let post = Size2(width: 1080, height: 1350)     // 캔버스 중심 (540, 675)

/// 시작 프레임의 center는 **캔버스 중심과 두 축 모두 다른** 값이어야 한다.
/// AC-17의 기대 출력이 캔버스 중심 `(540, 675)`이므로, 픽스처를 그 값으로 두면
/// `placed(at:) { return self }` 변이가 초록으로 통과한다.
/// `LayerCenterClampTests.swift:42-43`이 **입력** 쪽에서 같은 함정을 기록했다
/// ("y를 999로 둔 이유: 675로 두면 … 증인이 약해진다"). 이번엔 **픽스처** 쪽이다.
/// 이 규칙은 태스크 5·6의 `LayerTransform`·`LayerStore` 픽스처에도 그대로 적용한다.
private let 시작프레임 = LayerFrame(center: Vec2(x: 100, y: 200),
                                 size: Size2(width: 200, height: 100), rotation: 0.3)

@Test func 이동_경로로_들어온_작업_영역_밖_중심은_작업_영역_경계로_잘린다() {
    let s = CanvasSurface(canvas: post, viewport: 세로)
    let moved = 시작프레임.placed(at: ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: s))
    #expect(moved.center.x == 1620)
    #expect(moved.center.y == 2025)
    #expect(moved.size == 시작프레임.size)          // 타입이 막지 못한다
    #expect(moved.rotation == 시작프레임.rotation)
}
```

4. **경계 밖 증인**(`SoozipTests`, 비-`@testable`)을 태스크 4의 RED 안에 함께 둔다. **이 증인이 증명하는 참인 문장은 하나뿐이다 — "올바른 경로가 공개 표면만으로 닿는다."** Swift에는 "이것은 컴파일되지 않아야 한다"를 단언할 수단이 없으므로, 이 테스트가 *"우회 경로가 공개되어 있지 않다"* 를 증명한다고 적으면 안 된다.

### 남는 누수 — 전체

| # | 축 | 상태 | 무엇이 검증하는가 |
|---|---|---|---|
| 1 | 모듈 **밖** setter 대입(`frame.center =` · `transform.x =`) | **닫힘** | 컴파일러(`internal(set)` × 3). 오케스트레이터 실측 확인 |
| 2 | **`SoozipLayout` 모듈 내부 대입**(`storage[i].layer.transform.x = …`) | **열림** — `place`는 선점이지 봉쇄가 아니다 | **검증: 없음.** 코드 리뷰 + BR-7 인수 검증뿐 |
| 3 | 구성 축 — `LayerFrame.init` · `LayerTransform.init` · `Layer.transform` 통째 대입 | **열림 — 닫을 수 없다** | **검증: 없음**(테스트로 관측 불가라 BR-7이 AC를 두지 않았다). 다만 `LayerTransform.init`은 `scale`·`rotation`·`opacity`·`z`를 **기본값으로 리셋**하므로 `placed(at:)`가 유일하게 나머지를 보존하는 경로다 — 규율에 실질 유인이 생긴다 |
| 4 | **`workArea` 재기술** — `min(max(p.x, s.workArea.min.x), s.workArea.max.x)` | **열림, 그리고 AC-17을 깬다** | **검증: 없음.** `workArea`는 `public`이고(그래야 EDITOR-11이 경계를 그린다) 이 2줄에는 **비유한 가드가 없다**. 미리 `∞`를 `1620`으로 유한하게 만든 뒤 토큰에 넣으면 `isFinite` 가드가 발동하지 않아 결과가 `(1620, …)`가 되어 AC-17의 `(540, 675)`가 **공개 표면만으로** 깨진다 |
| 5 | **표면 위조** | **열림** | **검증: 없음.** `CanvasSurface.init`이 `canvas`를 검증하지 않는다(`:34`). 위험 3 참조 |
| 6 | `placed(at:)`가 `self.size`·`self.rotation`을 건드림 | 열림(타입은 못 막는다) | **테스트**: `moved.size == f.size` · `moved.rotation == f.rotation`를 기하·모델·저장소 세 경로 전부에 |
| 7 | `ResizeAnchor` 중간값(`:123`·`:246`) | 무클램프 중심을 계속 만든다 | **오늘 저장 상태가 될 수 없는 이유는 게이트가 막아서가 아니라 `LayerFrame → LayerTransform` 역변환이 저장소에 존재하지 않아서다.** 단방향 `frame(baseSize:)`뿐이다. EDITOR-11이 역변환을 만드는 날 이 근거는 사라진다 |
| 8 | **크기 축** | 게이트 **없음** | 역변환이 생기면 중심은 `x`/`y`(닫힘)를 지나지만 크기는 `scale`(`Layer.swift:39`, `public var` — 열림)을 지난다. 리사이즈 저장 경로의 절반에는 이 설계가 아무 장치도 두지 않는다 |

**참인 문장은 이것 하나다** — *"이미 존재하는 레이어의 중심을 **모듈 밖에서** 바꾸는 경로는 닫혔고, **모듈 안**에는 옳은 경로가 하나 놓였을 뿐 두 번째 경로를 막는 것은 없다. 원시 좌표로 새 값을 구성하는 축과 크기 축은 열려 있다."*

## 변경 범위

### 신규

| 파일 | 내용 |
|---|---|
| `SoozipGeometry/GestureRouter.swift` | `FingerPattern` · `GestureRoute` · `GestureRouter` |
| `SoozipGeometry/ClampedLayerCenter.swift` | `ClampedLayerCenter` + `extension LayerFrame { placed(at:) }` |
| `SoozipLayout/LayerPlacement.swift` | `extension LayerTransform { placed(at:) }` |
| `SoozipGeometryTests/GestureRouterTests.swift` | AC-1~15 |
| `SoozipGeometryTests/ClampedLayerCenterTests.swift` | AC-16·17 (+ 크기·회전 보존) |
| `SoozipLayoutTests/LayerPlacementTests.swift` | 모델 계층 계약 + 나머지 4필드 보존 |
| `SoozipLayoutTests/LayerStorePlacementTests.swift` | 저장소 계층 계약 + 없는 id 무시 + z 불변 |
| `SoozipTests/LayerCenterGateBoundaryTests.swift` | 경계 밖 증인(비-`@testable`) — 태스크 4 RED에 포함 |

### 수정

| 파일 | 내용 |
|---|---|
| `SoozipGeometry/LayerFrame.swift:54` | `public var center` → `public internal(set) var center` + 원장(왜 `size`·`rotation`은 열어 두는가) |
| `SoozipGeometry/LayerCenterClamp.swift:67` | `public` 제거. `:35-39`의 ⚠️ 인계 블록을 **"이동 축(모듈 밖 setter)은 닫혔고 생성·복제·리사이즈 중심 이동·모듈 내부는 남았다"** 로 좁혀 다시 쓴다 |
| `SoozipGeometry/CanvasSurface.swift:80` | 원장 *"좁힌 것은 가드가 없는 변환 함수 하나뿐이다"* 가 이 변경으로 **stale**이 된다(`clampedLayerCenter`도 좁아졌다). 문장 갱신 + `workArea` 2줄 재기술이 비유한 가드를 빠뜨려 AC-17을 깬다는 경고 추가 |
| `SoozipGeometry/ResizeAnchor.swift:123·246` | 코드 변경 없음. 두 반환 지점에 원장 — ① 무클램프 중간값 ② **오늘 저장 상태가 될 수 없는 이유는 게이트가 아니라 역변환 부재** ③ 역변환이 생겨도 크기 축은 `scale`로 샌다 ④ 고정점 vs 클램프 충돌은 `EDITOR-11` 정책 |
| `SoozipLayout/Layer.swift:37-38` | `x`·`y` → `public internal(set)`. `scale`(:39)·`rotation`·`opacity`·`z`는 그대로 + 원장(`init` 기본값이 4필드를 리셋한다는 사실 포함) |
| `SoozipLayout/LayerStore.swift` | **`import SoozipGeometry` 추가** + `place(_:at:)` 신설 + 원장 |
| `Soozip/Spikes/SpikeMenu.swift:28·31·36·43·56` | `:28` 안내를 "S2만 남음"으로 · `:31` `@State showingS1` 제거 · `:36` 버튼 제거 · `:43` `fullScreenCover` 제거 · **`:56` `showingS1 = false` 제거** |
| `Soozip.xcodeproj/project.pbxproj` | `xcodegen generate`(2.45.3 설치 확인)로 재생성 |
| `context/editor/architecture.md:85` · `status.md:34` · `glossary.md:36` | **지우지 않고 좁혀 다시 쓴다.** 그 줄들이 요구하는 것은 5개 경로인데 이 설계가 닫는 것은 이동 축 하나다. 새 문면: *"이동 축(모듈 밖 setter)은 `ClampedLayerCenter` 게이트로 닫혔다. **생성·복제·리사이즈로 인한 중심 이동·`SoozipLayout` 모듈 내부 우회는 남았다** — 수신자 `EDITOR-11`·`TOOL-3`."* |
| `context/editor/status.md:32` | 제스처 배타 행 ⬜ → ✅ + 요약 |

### 삭제

| 파일 | 이유 |
|---|---|
| `Soozip/Spikes/S1_GestureProbe.swift` | 사용자 결정. `internal(set)`이 `:76`을 컴파일 불가로 만들고 `scripts/test.sh:45·58`이 앱 Debug + Release 빌드를 게이트로 돈다. 파일 헤더(`:4`)·`SpikeMenu.swift:28`이 삭제를 허가했고 측정은 끝났다 |

## 구현 순서

```
cycle-0 (chore) S1 프로브 정리                       (의존: 없음)
1. [Must] 표 판정                                    (의존: 없음)
2. [Must] 배타 잠금·시작 거부                        (의존: 1)
3. [Must] 종료·재판정·멱등                           (의존: 2)
4. [Must] 지오메트리 게이트 + 경계 밖 증인            (의존: cycle-0)
5. [Must] 모델 계층 — LayerTransform                 (의존: 4)
6. [Must] 저장소 계층 — LayerStore.place             (의존: 5)
7. (chore) 원장 갱신                                 (의존: 4, 6)
```

cycle-0과 1은 병렬. 4는 cycle-0 **뒤**여야 한다(4가 `S1:76`을 컴파일 불가로 만든다). 5·6은 같은 모듈이라 직렬. 커밋은 사이클마다 가른다(PR은 하나 — 라우터와 게이트가 같은 부채 서사에 속한다).

| # | 태스크 | AC | Red | Green | 게이트 |
|---|---|---|---|---|---|
| **cycle-0** | S1 삭제 + `SpikeMenu` 5곳 + `xcodegen generate` | — | **없음**(삭제에는 단언할 새 동작이 없다. 진짜 RED는 태스크 4가 만든다) | — | ① `./scripts/test.sh` 전체 초록(삭제 **전·후 각 1회**) ② `rg -n 'S1_GestureProbe\|showingS1' Soozip/ Soozip.xcodeproj/` → **0건** ③ `git diff --stat` pbxproj가 S1 참조 제거만 담는가 |
| 1 | `FingerPattern`·`GestureRoute`·`GestureRouter.started` | **1·2·3·4·5·6** | 6쌍 리터럴 순회 | 6 arm 전수 switch(`_` 금지) | `swift test` (SoozipGeometry) |
| 2 | 활성 가드 | **7·8·9·10·11·12·13** | 위 7행 삼중 표 | `started`의 `guard active == nil` | 7건 중 **6건**이 가드 제거 변이를 죽인다(AC-8 제외 — doc 명시) |
| 3 | `ended()` | **14·15** | AC-14 3단 전이 · AC-15 `== .idle` | | AC-15 킬셋은 `precondition` 류 하나뿐임을 doc에 명시 |
| 4 | 토큰 + `LayerFrame.placed(at:)` + `center` `internal(set)` + `clampedLayerCenter` `internal` | **16·17** | **패키지 테스트(`@testable`)와 앱 경계 테스트(비-`@testable`)를 동시에 쓴다** — 둘 다 `cannot find type` 로 실패하고 `scripts/test.sh:47-51`이 컴파일 실패를 FAILED로 처리 | `public`을 빠뜨리면 **경계 테스트만 빨간 채 남는다** — 그것이 이 증인의 진짜 RED | 기존 `LayerCenterClampTests` 6건 유지 · 픽스처 center `(100, 200)` · 크기·회전 보존 단언 |
| 5 | `LayerTransform.placed(at:)` + `x`/`y` `internal(set)` | BR-7 | `(99999, 99999)` → `(1620, 2025)`, `(∞, 999)` → `(540, 675)` | | 4필드 보존 단언 · `LayoutDocumentTests`·`JSONContractTests` 유지 |
| 6 | `LayerStore.place(_:at:)` + `import SoozipGeometry` | BR-7 · BR-6 | ① 옮긴 뒤 `layers[i].transform.x/y` ② **없는 id는 아무것도 바꾸지 않고 크래시하지 않는다** ③ z 불변 | `storage.firstIndex` → `transform.placed(at:)` 위임 | `LayerStoreTests`·`SelectionTests` 유지 |
| 7 | 원장 갱신 — `context/editor/*.md` 3곳 **좁혀쓰기** · `CanvasSurface.swift:80` · `ResizeAnchor` 2곳 | — | 없음 | — | 문면에 "게이트 완료"로 읽히는 표현이 없는가 |

## 기존 패턴과의 정렬

| 이 설계의 결정 | 따르는 선례 |
|---|---|
| 불변 값 + `-> Self` 전이 | `CanvasSurface.zoomed(to:)`·`centered(on:)`·`fitted()`·`viewportChanged(to:)` |
| 유휴 = `Optional`, `case idle` 없음 | `HandleHitTest.swift:92-93` · `HandlePlacement.box: Box?` · `LayerStore.selection: Entry?` |
| `Equatable, Sendable` 명시 | `CanvasOverlap`(`LayerBoundary.swift:5`) |
| `CaseIterable` 미부착 | `HandleGesture`(`HandleHitTest.swift:12-16`) |
| 정책 함수를 좁혀 재기술 경로를 없앰 | `HandleGesture.accepts`(internal) · `HandlePlacement.hitSize`·`edgeHideThreshold`(internal) · `RotationSnap.turnDegrees`(private) |
| 공개 표면에서 위험한 쌍둥이 함수를 뺌 | `clampedToWorkArea` public → internal (`CanvasSurface.swift:97-103`) |
| 시그니처로 오용을 원천 차단 | `clampedLayerCenter`의 `Vec2 → Vec2` → `placed(at: ClampedLayerCenter)` |
| 없는 식별자를 조용히 무시 | `LayerStore.move(_:to:)`(:188-189) · `remove(_:)` |
| 이름을 갈라 오버로드 혼동을 없앰 | `ResizeAnchor`의 `shortSideFloor`/`minShortSide` |
| 파일 분리 + `extension`으로 얹기 | `LayerCenterClamp.swift` · `LayerBoundary.swift` |
| 테스트 함수명은 한국어 문장, 참조는 이름으로 | 저장소 전체 |
| 주석 = 설계 원장(실측·변이 킬셋 포함) | `LayerCenterClamp.swift:59-66` · `LayerBoundary.swift:114-134` |

**어긋나는 곳 1건 — `private init` + `static let idle`.** 이 저장소의 다른 값 타입은 전부 `public init`을 갖는다. 라우터만 닫는 이유는 **활성 상태를 밖에서 날조할 수 있으면 AC-7~13의 Given이 전이를 지나지 않기 때문**이다. test-architect는 이것을 어긋남이 아니라 testability 강화로 판정했다.

## 위험

각 항목에 **무엇이 검증하는가**를 붙인다. **"검증: 없음"을 숨기지 않는다.** 이 저장소는 "구조가 보장한다"가 반증된 전례를 최소 4회 기록했고(`.dev/feat-editor-selection/design.md:395` · `ResizeAnchor.swift:44-49` · `HandleHitTest.swift:30-39` · **이 설계 1차본의 "저장 상태가 될 수 없다"**), 마지막 하나는 이 문서 자신이다.

**1. 봉쇄의 증인이 프로덕션에 0건이다.** S1을 지우면 게이트를 쓰는 프로덕션 코드가 하나도 없다 — `EDITOR-9`가 `clampedLayerCenter`를 만들고 호출자 0건이었던 상태와 형식이 같다. 다른 점은 **잘못된 경로가 모듈 밖에서 컴파일되지 않는다**는 것뿐이고, 옳은 경로가 쓰인다는 보장이 생긴 것은 아니다.
→ **검증**: 태스크 4의 경계 밖 증인이 *"올바른 경로가 공개 표면만으로 닿는다"* 를 컴파일 단계에서 고정한다. **그 이상은 증명하지 않는다.** "EDITOR-11이 실제로 쓴다"는 BR-7의 인수 검증이 유일한 관측점이다.

**2. `SoozipLayout` 모듈 내부에 두 번째 경로를 만드는 것을 아무것도 막지 못한다.** `place(_:at:)`는 봉쇄가 아니라 **선점**이다.
→ **검증: 없음.** 코드 리뷰 + BR-7 인수 검증. 이 사실을 `place` doc에 ⚠️로 적어 다음 사람이 "닫혔다"고 읽지 않게 한다.

**3. 토큰의 보증은 인자로 준 `canvas`에 종속되고, 그 `canvas`는 검증되지 않는다.** (1차본의 risk 3·5를 합침 — **별개 위험이 아니라 같은 사실의 두 도달 경로**)
- **경로 ① 위조** — `CanvasSurface(canvas: Size2(width: 1e9, height: 1e9), viewport: .zero)`를 넘기면 `(99999, 99999)`를 담은 토큰이 한 줄로 나온다.
- **경로 ② 검증되지 않은 디코딩** — `LayoutDocument`가 `canvas.w`/`h`를 `isFinite`·`> 0` 검사 없이 디코딩한다(`LayerCenterClamp.swift:48-57`). `{"w": 0, "h": 1350}` 문서면 `workArea`가 수직 선분으로 납작해져 **모든 레이어 중심의 x가 0으로 붕괴**한다. `EDITOR-9`는 "호출부 0건이라 도달 불가"로 이월했는데, **이 단위가 게이트 통과를 강제하는 순간 이 붕괴가 실제 경로가 된다.**

→ **검증: 없음.** 수신자는 `SoozipLayout` 디코딩 검증(이미 이월된 항목)이며 **`EDITOR-11` 배선 착수 전에 닫아야 한다.**
→ ⚠️ **1차본의 지침 — "`ClampedLayerCenter(_:canvas: Size2)` 생성자를 추가하라(누수가 아니다)" — 는 삭제한다. 거짓이었다.** 그 생성자는 표면조차 없이 임의 캔버스를 받으므로 위조가 더 짧아진다.

**4. `workArea` 재기술이 AC-17을 공개 표면만으로 깬다.** `workArea`는 `public`이어야 한다(EDITOR-11이 경계를 그린다). 그래서 2줄 재기술이 언제나 가능하고 **거기에는 비유한 가드가 없다.**
→ **검증: 없음.** `CanvasSurface.swift:90-95`의 경고문이 유일한 방어다. `:80`의 원장이 stale이 되므로 태스크 7에서 함께 고친다.

**5. 크기 축과 리사이즈 저장 경로에는 게이트가 없다.** `LayerFrame → LayerTransform` 역변환은 저장소에 **존재하지 않는다**. 즉 `ResizeAnchor`의 무클램프 중심이 오늘 저장 상태가 될 수 없는 것은 **게이트가 막아서가 아니라 그 길이 아직 없어서다.**
→ **검증: 없음.** 근거를 강하게 읽으면 다음 사람이 역변환을 추가하면서 "게이트가 지킨다"고 착각한다.

**6. 구성 축(`init`)은 열려 있고, 그것을 이동에 쓰는 것을 막지 못한다.**
→ **검증: 없음.** 실질 억제는 하나뿐이다 — `LayerTransform.init`이 나머지 4필드를 기본값으로 리셋한다.

**7. 잠금에 주인이 없다 — 이 상태 기계가 막는 것은 동시 시작이지 해제 후 즉시 재잠금이 아니다.** 두 인식기가 동시에 살아 있으면 먼저 끝난 쪽의 `onEnded`가 잠금을 풀고, 살아 있는 쪽의 다음 `onChanged`가 **다른 라우트에 즉시 재잠금**한다 → §13의 순간이동이 그대로 재현된다.
→ **검증: 없음.** **`ended()`를 누가 보내는가가 §13 재발 여부를 정한다** — `ExclusiveGesture` 결합의 인계로 `GestureRouter.ended()` doc과 `context/editor/architecture.md` 제스처 절에 남긴다. 수신자 `EDITOR-11`.

**8. AC-9는 UX 방어가 아니라 순수 변이 킬러일 수 있고, 실제 귀결은 "한 제스처 동안 먹통"이다.**
→ **검증**: 변이 축은 태스크 2의 표가 고정한다. UX 축은 **검증 없음** — 도달 경로가 없기 때문이다.

**9. AC-7의 입력 인코딩이 PRD 의도와 다를 가능성.**
→ **검증**: 7행 삼중 표. 같은 삼중이 둘 나오면 red-writer 단계에서 즉시 드러난다.

**10. `hasSelection: Bool` 반전.** 반대로 넘기는 배선은 이 단위의 테스트 15건을 전부 통과한다.
→ **검증: 없음** (인자 라벨이 유일한 방어). 실제 관측은 `EDITOR-11`의 통합 축에서만 가능하다.

**11. 픽스처 "정리"가 증인을 지운다.** AC-16·17의 시작 프레임 center가 캔버스 중심과 같아지면 `return self` 변이가 AC-17에서 산다.
→ **검증**: 규칙과 근거를 테스트 파일 상단 doc에 남긴다.

**12. `LayerFrame`의 필드 가시성이 비대칭이 된다**(`center`만 `internal(set)`). "일관성"을 이유로 되돌리는 리팩터링이 자연스러워 보인다.
→ **검증: 없음** — 원장 주석뿐. 근거: **크기 축에는 강제할 계약이 없다**(`EDITOR-7`이 `resizeLimits` 봉쇄를 비용 판단으로 미뤘다).

## Testability 평가 (test-architect)

### 컴포넌트별 테스트 전략

| 컴포넌트 | 단위 | 통합 | 모의 | 격리 | AC |
|---|---|---|---|---|---|
| `FingerPattern`·`GestureRoute` | **직접 테스트하지 않는다** — 연관값 없는 enum이라 관측할 동작이 없다. BR-3·BR-5는 컴파일러가 진다 | `started`의 입출력으로만 관측 | 없음 | 불필요 | 없음(BR) |
| `GestureRouter` | `idle`에서 출발하는 순수 값 전이 체인. 입력 공간 `3×2=6` 전수 열거 | **없다** — SwiftUI 배선은 EDITOR-11로 인계(범위 결정이지 결함 아님) | **0건** | DI 불필요. `route`가 `private`이라 **테스트가 표를 재기술하는 경로도 타입으로 닫혀 있다** | 1~15 |
| `ClampedLayerCenter` | 단독 단언을 두지 않는다(그러면 `LayerCenterClampTests` 복제) | 토큰 → `placed(at:)` 합성 경로 | 없음 | 불필요 | 16·17(합성으로) |
| `LayerFrame.placed(at:)` | `.center` 단언 + **`size`·`rotation` 보존 단언 필수** | 태스크 4 경계 증인 | 없음 | `.center` 쓰기 지점이 `ResizeAnchor`(동일 모듈)·`S1`(삭제 대상) 둘뿐, 테스트엔 0건 | 16·17 |
| `LayerTransform.placed(at:)` | `(99999,99999)`·`(∞,999)` | `LayoutDocumentTests`·`JSONContractTests` 유지 | 없음 | `transform.x/y` 대입 지점 저장소 전체 **0건** → 회귀 위험 0 | BR-7 |
| `LayerStore.place` | 옮김 · 없는 id 무시 · z 불변 | `LayerStoreTests`·`SelectionTests` 유지 | 없음 | — | BR-7·BR-6 |
| 가시성 축소 3건 | **패키지 테스트로는 관측 불가**(`@testable`이 `internal`을 뚫는다) | `SoozipTests` 비-`@testable`. `project.yml:85-89`가 이미 `SoozipGeometry`를 물려 놓았고 `CGInteropTests.swift:3`이 그 형태를 쓴다 — **신규 인프라 0** | 없음 | 컴파일러 | 16·17(경계 축) |

### 특별 판정

- **A. AC-7~13 판정력** — 설계서 1차본 주장이 **정반대**였다. 7행 중 **6행이 재판정 변이를 죽이고 AC-8만 살아남는다**(오케스트레이터 독립 재계산으로 확인). §4의 표가 정정본.
- **B. AC-16·17의 함정** — 신규 2건은 기존 6건이 못 죽이는 M1(토큰 생성자 클램프 생략)·M2(`placed`가 토큰 무시)·M4(x만 토큰)를 **실제로 죽인다.** PRD의 "복제일 뿐" 우려는 해소. 단 픽스처 결함(캔버스 중심과 동일 → AC-17에서 M2 생존)과 미단언 축(`size`/`rotation`)을 고쳐야 제 값을 한다 — 2차본에 반영됨.
- **C. 태스크 6의 TDD 적합성** — 공허한 단언은 아니지만(킬셋 M5 실재) **RED가 없다.** 해법: 태스크 4의 RED 안으로 병합 — 타입이 없는 시점에 두 테스트를 동시에 쓰면 둘 다 컴파일 실패(진짜 RED)이고, GREEN에서 `public`을 빠뜨리면 경계 테스트만 빨갛게 남는다. 2차본에 반영됨.
- **D. 태스크 1(S1 삭제)** — 삭제에 RED는 없다. **cycle-0 chore**로 빼고 게이트 3종만 명시. 2차본에 반영됨.
- **E. `private init`** — 격리는 한 단계 나빠지지만(전이 2개/테스트) **`GestureRouter(active:)`로 Given을 날조하는 거짓 초록이 원천 제거**된다. 그 날조가 가능하면 "`started`가 `active`를 영영 설정하지 않는" 변이에 AC-7~13 일곱 건이 통째로 위장 통과한다. **순증.**

### Testability Score: **9/10** — ✅ TESTABILITY PASS

**감점하지 않은 이유**: 모의·DI 필요 표면 **0**(시계·네트워크·파일시스템·난수·`@MainActor`·SwiftData 어느 것도 없음) · 입력 공간 유한 전수 열거 가능 · 불변 값 전이가 중간 상태를 전부 남김 · 경계 축 테스트 인프라가 **이미 존재** · 가시성 축소 3건이 기존 테스트를 하나도 깨지 않음을 실측 확인 · 강결합·전역 가변 상태·숨은 싱글턴 **0건**.

**1점 감점**: 태스크 6·cycle-0의 RED 부재(재배치로 해소) · **BR-7에 자동 관측이 없다**(구조적으로 옳지만 인수 검증이 사람 눈에 걸린다) · 위험 6·7·10(구성 축 / 토큰 신선도·주인 없는 잠금 / `Bool` 반전)의 검증 0건.

**이월 권고(이번 단위 밖)**: BR-7을 사람 눈에서 떼려면 `scripts/test.sh`에 공개 표면 회귀 가드 한 줄이 싸다 — `rg -q 'public var center|public var x: Double' Packages/…`가 걸리면 실패. 저장소가 이미 셸 게이트를 갖고 있어 신규 인프라가 없다.

# EDITOR-8 — 회전 (15° 스냅) 기술 설계 (확정)

> 수치는 전부 `.dev/feat-editor-rotation/orchestrator-verification.md`(1~3차 실측)에서 인용한다. 설계서는 새 수치를 주장하지 않는다.

## 설계 규모

**중형** — 신규 파일 1 + 기존 파일 1의 판정 함수 1개 재정의 + 호출부 2곳. 새 의존 0건, 새 public 타입 1개(`enum` 네임스페이스).

## 배치 결정

| 무엇 | 어디 |
|---|---|
| 회전 그리드 흡착 · 한 바퀴 접기 · enter 판정 · 도↔라디안 변환 | **신규** `Packages/SoozipGeometry/Sources/SoozipGeometry/RotationSnap.swift` (`public enum RotationSnap`) |
| 축 정렬 판정 재정의 (FR-6) | **수정** `SnapEngine.swift:37-39`, 호출부 `:52`·`:55` |
| `SnapKind`에 회전을 넣지 않는 이유 | **수정(주석만)** `SnapEngine.swift:5` |
| "회전된 레이어는 제외" 문서의 의미 변화 | **수정(주석만)** `SnapEngine.swift:43-46` |
| 회전 스냅 테스트 | **신규** `Tests/SoozipGeometryTests/RotationSnapTests.swift` |
| 축 정렬 회귀·버그 수정 테스트 | **수정** `Tests/SoozipGeometryTests/SnapEngineTests.swift` |

`RotationSnap`은 `enum`이다 — 인스턴스 상태가 없고, `struct`면 암묵 `init()`이 생겨 `RotationSnap()`이 컴파일된다.

도↔라디안 변환을 범용 `Angle` 네임스페이스로 빼지 **않는다**. `.pi/180` 소비자는 이 단위 하나뿐이고(`HandlePlacement.swift:189`는 `sin/cos`에 라디안을 그대로 넣는다), 범용 네임스페이스는 두 번째 `.pi/180` 경로를 초대한다 — 그 두 벌은 3°에서 1 ulp 갈라진다(원장 1차 #2).

## 공개 API

```swift
public enum RotationSnap {

    // MARK: - 공개 상수 (FR-9 · BR-6 · AC-18)
    public static let gridStepDegrees: Double = 15
    public static let snapThresholdDegrees: Double = 3

    // MARK: - 흡착 (FR-1 · FR-2 · FR-4 · FR-7 · FR-8)
    public static func snapped(degrees: Double) -> (snapped: Bool, degrees: Double)
    public static func snapped(radians: Double) -> (snapped: Bool, radians: Double)

    // MARK: - 한 바퀴 접기 (FR-3 · BR-3 · FR-8)
    public static func normalized(degrees: Double) -> Double
    public static func normalized(radians: Double) -> Double

    // MARK: - 진입 판정 (FR-5 · FR-7)
    public static func entersSnap(fromDegrees previous: Double, toDegrees current: Double) -> Bool
    public static func entersSnap(fromRadians previous: Double, toRadians current: Double) -> Bool

    // MARK: - 단위 변환
    public static func degrees(fromRadians radians: Double) -> Double
    public static func radians(fromDegrees degrees: Double) -> Double

    // MARK: - 내부
    private static let radiansPerDegree: Double = .pi / 180
    private static let turnDegrees: Double = 360
    private static let turnRadians: Double = 2 * .pi
    private static func folded(_ value: Double, period: Double) -> Double
}
```

구현 골자:

```swift
// snapped(degrees:) — 판정의 유일한 본체
let index = (degrees / gridStepDegrees).rounded()
let candidate = index * gridStepDegrees
guard abs(degrees - candidate) < snapThresholdDegrees else { return (false, degrees) }
return (true, candidate)

// snapped(radians:) — 어댑터. 후퇴 대상이 입력 라디안이다
let core = snapped(degrees: Self.degrees(fromRadians: radians))
guard core.snapped else { return (false, radians) }
return (true, Self.radians(fromDegrees: core.degrees))

// folded(_:period:) — 한 바퀴 접기 규칙의 유일한 본체
var r = value.truncatingRemainder(dividingBy: period)
if r < 0 { r += period }
if r >= period { r = 0 }
return r

public static func normalized(degrees: Double) -> Double { folded(degrees, period: turnDegrees) }
public static func normalized(radians: Double) -> Double { folded(radians, period: turnRadians) }

// entersSnap(fromDegrees:toDegrees:)
guard previous.isFinite else { return false }
let now = snapped(degrees: current)
guard now.snapped else { return false }
let before = snapped(degrees: previous)
guard before.snapped else { return true }
return abs(normalized(degrees: before.degrees) - normalized(degrees: now.degrees)) >= gridStepDegrees

// entersSnap(fromRadians:toRadians:)
entersSnap(fromDegrees: Self.degrees(fromRadians: previous),
           toDegrees:   Self.degrees(fromRadians: current))

// 변환 — 같은 상수 한 벌
radians / radiansPerDegree      // degrees(fromRadians:)
degrees * radiansPerDegree      // radians(fromDegrees:)
```

`SnapEngine.swift`:

```swift
/// 정렬·간격 가이드 후보 자격의 허용오차(**라디안**).
/// `RotationSnap.snapThresholdDegrees`(3°)와 통합하지 않는다(BR-5).
private let axisAlignToleranceRadians: Double = 0.0001

/// FR-6 — 가장 가까운 360° 배수까지의 거리로 판정한다. `internal`이다.
func isAxisAligned(radians r: Double) -> Bool {
    let turn = 2 * Double.pi
    let folded = abs(r.truncatingRemainder(dividingBy: turn))
    return min(folded, turn - folded) < axisAlignToleranceRadians
}
```

호출부(`:52`·`:55`):

```swift
guard isAxisAligned(radians: moving.rotation) else { return [] }
let peers = others.filter { isAxisAligned(radians: $0.rotation) }.map(AABB.init)
```

**구현 세부 — `Self.` 한정자는 필수다(원장 C-10 실측).** `snapped(radians:)`·`entersSnap(fromRadians:)` 안에서 매개변수 `radians`가 정적 함수 `radians(fromDegrees:)`를 가려 `error: cannot call value of non-function type 'Double'`이 난다. 변환 호출에는 항상 `Self.`를 붙인다.

## 설계 결정

### ① `SnapCandidate`에 회전을 담을 수 없다 → 별도 `RotationSnap` + 라벨 튜플

⑴ `SnapCandidate`의 소비자는 가이드 **선** 렌더러인데 회전에는 그을 선이 없다(v4 표현은 각도 배지). `.rotation` 케이스를 넣으면 모든 소비자가 `axis`를 만지기 전에 `kind`로 분기해야 하고, 잊은 코드가 회전 후보의 `axis`를 좌표로 읽는다. ⑵ `snapCandidates`의 입력 넷 중 회전이 쓰는 것이 **하나도 없다**. ⑶ `SnapKind`는 `public`이라 케이스 추가가 **소비자 exhaustive switch를 깨는 소스 호환성 변경**이다. ⑷ 선례: `HandlePlacement`/`HandleHitTest`가 둘 다 "핸들"이지만 별도 타입.

라벨 튜플 선례 실재 확인: `LayerFrame.resizeLimits(canvas:)`(`ResizeAnchor.swift:50`), `CanvasSurface.zoomLimits`(`CanvasSurface.swift:32`).

### ② 판정 본체는 도(degree) 공간

- **AC-18이 라디안을 배제한다.** `15° = π/12`는 정확 표현 불가라 `#expect(gridStep == .pi/12)`는 정의의 재진술(공허). 도 상수면 `edgeHideThreshold == 88`과 같은 형태의 상수 리터럴 단언이 성립한다.
- **라디안 공간 비교는 AC-3을 실제로 깬다**(원장 1차 #3): 거리 `0.05235987755982985` < 임계 `0.05235987755982989` → 흡착 → AC-3 반증. 도 공간은 `3.0 < 3.0` = false.
- **변환 상수는 한 벌이어야 한다.** `15*(π/180)` ≡ `π/12`는 비트 동일(원장 #1)이지만 **3°는 1 ulp 갈라진다**(원장 #2). `radiansPerDegree` 하나만 두고 반대 방향도 같은 상수로 **나눈다**.

> ⚠️ 1회차의 "도 공간에서만 결정적"은 과장이라 좁힌다. 결정성은 **`snapped(degrees:)`의 비교 한 줄**에 있고, `snapped(radians:)`는 그 본체로 위임해 물려받는다. 위험은 **비교를 라디안 공간으로 옮기는** 리팩터링이지 라디안 표면의 존재가 아니다.

### ③ 후퇴 대상은 "입력 각도 그대로"

- `NaN` → `abs(NaN−NaN) = NaN` → `NaN < 3` 거짓 → `(false, NaN)` ✓ AC-15
- `∞` → `abs(∞−∞) = NaN` → 거짓 → `(false, ∞)` ✓ AC-16
- `1e308` rad → `degrees(fromRadians:)`가 `inf`(원장 C-1) → 같은 경로 → `(false, 1e308)` **유한** ✓ AC-17

> **근거 정정.** 1회차의 "도 공간 되곱은 넘치지 않는다"는 **거짓**이다(원장 1차 A: `gFM`에서 `idx*15 = inf`). FR-8이 성립하는 진짜 이유는 **넘쳐도 `abs(gFM − inf) = inf`이고 `inf < 3`이 거짓이라 입력으로 후퇴하기 때문**이다. `radians(fromDegrees:)`가 안전한 근거는 **"1보다 작은 상수를 곱해 크기가 줄어든다"**이다.

`ResizeAnchor`의 2단 가드를 이식하지 않는다 — 그 함수에는 **한계값이 조용히 사라져 완벽히 유한한 오답이 나오는 축**(`(2,1)`)이 있었지만 회전 스냅은 임계가 상수라 "사라질 한계"가 없다. 이식하면 증인 0건의 죽은 가드다.

### ④ `isAxisAligned` 재정의 → `min(folded, turn − folded)`, `internal` + `@testable`

원장 1차 #10 실측표(`tol = 0.0001`):

| 입력 | 새 방식 | 현재 구현 | `[0,2π)` 정규화 방식 |
|---|---|---|---|
| `-0.00005` | **참** | 참 | **거짓 (회귀)** |
| `2π` | **참** | **거짓 (버그)** | 참 |
| `2π − 0.00005` | **참** | 거짓 | 거짓 |
| `π/6`(기존 픽스처) | 거짓 | 거짓 | 거짓 |
| `0.5`(기존 픽스처) | 거짓 | 거짓 | 거짓 |

**M5는 식이 아니라 증인의 문제다.** `turn − folded` 가지의 유일한 증인이 `2π − 0.00005`이며(원장 C-5) 1회차 계획에 없었다 → 사이클 5에 신규 테스트로 추가.

**`RotationSnap.normalized(radians:)`로 접지 않는다** — BR-5가 통합을 금지하고(정규화는 값 변환, 이것은 거리 판정이며 결과 타입부터 다르다), 원장이 실측한 형태가 `abs(truncatingRemainder)` 쪽이다(등가성은 손유도이며 미실측).

**AC-11만 간접 관측을 추가한다**(Then이 두 절). AC-12는 Then이 한 절뿐이라 후보 리스트로 바꾸면 어느 축이 잘랐는지 구분되지 않는다. 픽스처는 `frame(x: 543, y: 400, rot: -0.00005)` — 중심 540에서 3pt라 두 구현이 실제로 갈린다.

**`LayerFrame` 오버로드를 남기지 않는다** — 같은 이름 오버로드 둘이 파일 스코프에 있으면 `others.filter(isAxisAligned)`가 문맥 타입으로 해소되어 한쪽을 지우는 변이가 조용히 컴파일된다. 호출부를 클로저로 바꾼다.

### ⑤ enter 규칙 — 다른 그리드로 넘어가면 발화, **목표 비교는 정규화값으로** *(사용자 결정 A)*

근거는 v4 §5.8.2 *"**같은 가이드**에 계속 붙어 있는 동안에는 재발화하지 않는다"*. 원장 2차 §제안 8건 실측 — raw 비교가 틀리는 **2건만 고치고 6건은 동일**:

| 직전 | 현재 | (a) | (b) raw | **채택(norm)** | 기대 |
|---|---|---|---|---|---|
| 20 | 17 | true | true | **true** | 발화 |
| 17 | 16 | false | false | **false** | 미발화 |
| 16 | 29 | false | true | **true** | 발화 — 다른 그리드 |
| **359** | **1** | false | **true** | **false** | **미발화 — 랩어라운드** |
| **1** | **359** | false | **true** | **false** | **미발화 — 역방향 랩** |
| 373 | 361 | false | true | **true** | 발화 (375→15, 360→0) |
| 44 | 46 | false | false | **false** | 미발화 |
| 44 | 61 | false | true | **true** | 발화 — 45→60 |

**부수 효과: 소비자가 0건이던 `normalized(degrees:)`에 프로덕션 소비자가 생긴다.**

**M7 — 구조적 근거를 좁힌다.** "같으면 0, 다르면 최소 `gridStepDegrees`"는 **거짓**이다(원장 C-7: `idx ≈ 4.5e15`, 약 1.9e14 바퀴에서 차가 `8.0`) — 그 구간에서 *다른 그리드인데 미발화*한다. 실사용 영향 없음. **정규화 후 잔존 여부는 미실측.**

**M4 — `guard previous.isFinite else { return false }`.** 없으면 `entersSnap(.nan, 17)` = **`true`**(원장 C-4). Bool 판정에서 FR-7의 후퇴는 거짓(미발화)이다.
`current` 조건은 두지 **않는다** — `now.snapped`가 이미 전부 막아 증인 0건의 가드가 된다.

### ⑥ 라디안 진입점을 직접 제공 — **접기 규칙을 `period`로 매개변수화** *(사용자 결정 B)*

| 방식 | 접기 규칙 벌 수 | FR-8 | 왕복 오차 |
|---|---|---|---|
| (가) 도 정규화를 라디안으로 감쌈 | 1벌 | **위반** — `degrees(fromRadians: 1e308)` = `inf` → `normalized(inf)` = **NaN**(원장 C-1) | 변환 2회 태움 |
| (나) 라디안에서 직접 접기(별도 본체) | **2벌** | 성립 | 없음 |
| **(다) 채택 — `folded(_:period:)` 한 벌 + 단위별 진입점 2개** | **1벌** | 성립 | 없음 |

**(가)는 M1 그 자체다.** 유한 라디안 `1e308`이 NaN을 내고, NaN `rotation`이 `LayerTransform`에 앉으면 `JSONEncoder`가 던져 **문서 저장이 실패한다.** 이 API의 목적이 EDITOR-11이 (가)를 손으로 짜지 않게 하는 것인데, 우리가 (가)를 내부에서 쓰면 목적을 배반한다.

**(나)와 (다)를 가르는 것은 "무엇이 규칙인가"**이다. 접기 규칙은 `truncatingRemainder` → 음수 보정 → 상한 클램프의 **세 단계**이고 단위는 `period` 하나로만 나타난다. 세 단계를 두 번 적으면 한쪽만 바뀌는 날이 온다.

(다)의 귀결 둘:
1. **FR-8이 구조적으로 성립한다** — `truncatingRemainder`는 유한 입력에 유한을 내고 변환을 태우지 않으므로 오버플로 지점 자체가 없다. **가드가 없는 것이 설계다.**
2. **변이 사살이 한 번으로 끝난다** — `floor`·클램프 삭제·음수 보정 삭제 변이의 증인이 **도 축 한 곳**에서 전부 확보된다. 라디안 축은 **배선만** 관측한다.

**진입점은 세 판정 전부 두 단위로 연다.** `LayerFrame.rotation`·`LayerTransform.rotation`이 라디안이므로 라디안이 소비 단위다. 하나라도 도 전용으로 남기면 EDITOR-11이 그 하나에 대해 (가)를 손으로 짠다.

`entersSnap(fromRadians:)`만 **합성으로 위임해도 안전하다** — **반환이 `Bool`이라 각도가 밖으로 나가지 않는다.** C-1의 NaN이 문서에 도달할 경로가 없고, 변환이 `inf`를 내면 `previous.isFinite` 가드나 `now.snapped`가 미발화로 후퇴시킨다. `normalized(radians:)`가 같은 합성을 쓸 수 **없는** 이유와 정확히 갈리는 지점이다.

**`gridStepRadians`는 두지 않는다** — 필요한 소비자는 `radians(fromDegrees: gridStepDegrees)`로 우리 상수를 통과한다.
**`turnDegrees`·`turnRadians`는 `private`** — 열면 EDITOR-11이 두 번째 접기를 짜는 가장 짧은 경로가 생긴다.
**`degrees(fromRadians:)`·`radians(fromDegrees:)`는 `public`** — 저장소 관례의 반대 방향이며 그것이 의도다. 정책 상수는 열면 재기술되지만, 변환은 **닫으면** 재기술된다.

### MUST-ADDRESS 해소 대응표

| # | 지적 | 해소 |
|---|---|---|
| **M1** | `degrees(fromRadians: 1e308)` = `inf` → 합성 NaN → 저장 실패 | 결정 ⑥ — `normalized(radians:)`를 닫힌 형태로 제공해 합성 경로를 프로덕션에서 제거. 증인: 테스트 #15 |
| **M2** | 도 API에 라디안이 컴파일되고 `\|r\| < 3 rad` 전 구간 붕괴 | 결정 ⑥ — 라디안 표면을 세 판정 전부로 완결해 오용 동기 제거. 타입으로는 닫지 않는다. **원장 C-2 붕괴표를 타입 doc에 기록**(위험 #3) |
| **M3** | `entersSnap` 정의역 미정의 | 결정 ⑤ — 정의역을 **"흡착 판정에 넣기 전의 원시 각도"**로 못박고 목표 비교만 `normalized`를 통과 |
| **M4** | `entersSnap(.nan, 17)` = `true` | `guard previous.isFinite`. 증인: 테스트 #25 |
| **M5** | `turn − folded` 가지 증인 0건 | 식 유지. 사이클 5에 `2π − 0.00005` 신설(테스트 #D) |
| **M6** | 왕복이 정확하다는 주장이 거짓 | 철회. **원장 C-8 표를 `snapped(radians:)` doc에 기록**하고, 테스트 (iii)이 `12°`에 의존함을 병기 |
| **M7** | `>= 15`의 "다르면 최소 15"가 거짓 | 구조적 단언을 좁혀 적고 원장 C-7 반례 기록. 정규화 후 잔존은 **미실측** |

## 수치 근거

전부 `orchestrator-verification.md` 인용. 새 계산 없음.

| # | 사실 | 출처 |
|---|---|---|
| 1 | `15*(π/180)` ≡ `π/12` 비트 동일 `0.2617993877991494` | 1차 #1 |
| 2 | `3*(π/180)` vs `π/60` **1 ulp 차** | 1차 #2 |
| 3 | 라디안 공간 비교는 AC-3을 깬다 | 1차 #3 |
| 4 | `360*(π/180)` ≡ `2π` | 1차 #4 |
| 5 | `fmod(2π, 2π)` = `+0.0` | 1차 #5 |
| 6 | rad→deg 오버플로 문턱 `\|r\| >= 3.1375664143845866e306` | 1차 #6 · C-1 |
| 7 | 클램프 없으면 `normalized(-1e-15)` = 정확히 `360.0` | 1차 #8 |
| 8 | `isAxisAligned` 5입력 표 | 1차 #10 |
| 9 | 도 공간 되곱 오버플로 실재 — `gFM`에서 `idx*15 = inf` | 1차 A |
| 10 | `floor` 변이는 `1e308`에서 `0.0`(범위 안). 올바른 값 **`296.0`** | 1차 B · C-6 |
| 11 | `truncatingRemainder(inf, 360)` = `NaN` → `normalized(inf)` = **NaN** | C-1 |
| 12 | 단위 오용 붕괴 — `\|r\| < 3 rad` 전 구간 `(true, 0.0)` | C-2 |
| 13 | raw 비교 랩어라운드 오발화 | C-3 |
| 14 | `entersSnap(.nan, 17)` = **`true`** | C-4 |
| 15 | `turn − folded` 증인 0건 | C-5 |
| 16 | 왕복 부정확 — `15` → `14.999999999999998`, `29` → `29.000000000000004` | C-8 |
| 17 | 도 공간 흡착은 유한 입력에 절대 비유한을 못 낸다 → **AC-17 흡착 축을 도 API로 재면 공허** | C-9 |
| 18 | `>= 15` 반례 — `idx ≈ 4.5e15`에서 차가 `8.0` | C-7 |
| 19 | 정규화 목표 비교 8건 표 | 2차 §제안 |
| 20 | **`Self.` 한정자 필수** — 없으면 `cannot call value of non-function type 'Double'` | C-10 |
| 21 | **`normalized(radians: 1e308)` = `5.720858487389101`** (유한, `[0,2π)`) | C-11 |
| 22 | `folded(1e308, period: 360)` = `296.0` → period 오배선은 범위 단언으로 잡힌다 | C-12 |
| 23 | `normalized(radians: 4.0)` = `4.0` | C-13 |

**미실측 (doc에 그대로 표시한다):**
- `snapped(radians: 1e308)`의 **합성 결과** — 조각(#6)만 실측. 사이클 3의 RED가 처음 관측한다
- `truncatingRemainder(±inf, 2π)` — period `360`에서만 실측
- C-7 반례가 정규화 통과 후에도 남는지
- 역수 상수 변이(`r * (180/.pi)`)의 어긋남 — #2가 잰 것은 `π/60` 변이다
- `degrees(fromRadians: .nan)` = `NaN` — 유도
- `normalized(degrees: -0.0)` = `-0.0` — 유도. `-0.0 == 0.0`이라 비교에는 영향 없음

## 변경 범위

| 파일 | 신규/수정 | 무엇 |
|---|---|---|
| `RotationSnap.swift` | **신규** | 공개 상수 2 · 흡착 2 · 정규화 2 · enter 2 · 변환 2 · private 상수 3 · private `folded` 1 |
| `SnapEngine.swift` | 수정 | `:5` doc · `:37-39` 재정의 + `axisAlignToleranceRadians` 명명 · `:43-46` doc · `:52`·`:55` 호출부 |
| `RotationSnapTests.swift` | **신규** | AC-1~10 · 13~18 + AC 밖 6건 + `isClose` (총 27건) |
| `SnapEngineTests.swift` | 수정 | 신규 4건. **기존 9건 전부 유지** |
| `HandlePlacement.swift` | **변경 없음** | `:230`의 15° 의존 사실은 `gridStepDegrees` doc에만 적는다 |
| `Package.swift` · `SoozipLayout/**` | **변경 없음** | 새 의존 0건 |

## 구현 순서 (RGR 사이클 분해)

**유도(RED)** = 없으면 구현이 덜 써지거나 잘못 써지는 것. **감시(회귀)** = 채택 구현에서 자동 통과하며 잘못된 대안으로 미끄러지는 것을 막는 것.

| 사이클 | 유도(RED) | 감시(회귀) | RED에서 무엇이 실패하는가 |
|---|---|---|---|
| **1. 도 그리드 흡착 + 공개 상수**<br>(의존 없음) | **AC-18 · AC-1 · AC-3** | AC-2 · AC-4 · AC-5 · AC-6 · AC-7 · AC-8 | 컴파일 실패. `return (false, degrees)` 최소 구현이면 AC-1 빨강 → 흡착 본체를 끌어낸다. 무조건 흡착이면 AC-3 빨강 → 임계 비교를 끌어낸다. `<=` 변이는 AC-3(거리 정확히 `3.0`)이 죽인다. 상수 변이는 AC-18이 죽인다.<br>**AC-4·7·8이 감시인 근거**: `(d/15).rounded()*15`가 AC-1을 통과하는 순간 **코드를 한 줄도 더 요구하지 않고 함께 통과한다.** 지키는 것은 "정규화를 먼저 하는" 대안으로 미끄러지는 것 |
| **2. 한 바퀴 접기 한 벌**<br>(의존 없음) | **AC-9 · AC-10 · AC-17 정규화 축(값 `296.0`) · 추가(ii) `-1e-15` · `normalized(radians: 4.0)` · `normalized(radians: 1e308)` 값 `5.720858487389101`** | AC-15 정규화 축 · BR-3 범위 | 컴파일 실패. 음수 보정이 없으면 AC-9 빨강. `>= period` 클램프가 없으면 `-1e-15`가 `360.0`이라 빨강. **`floor` 변이는 범위 단언으로 안 죽는다 — `296.0` 값 단언이 죽인다.** period를 라디안 쪽에 `360`으로 오배선하면 `1e308`이 `296.0`이라 빨강. `period = π` 변이는 `normalized(radians: 4.0)`이 `0.858`이 되어 빨강. **(가) 합성 구현이면 `1e308`에서 NaN → 빨강(M1의 증인).**<br>이 사이클은 `radiansPerDegree`를 쓰지 않는다 |
| **3. 라디안 흡착 어댑터 + 변환**<br>(의존 1) | **AC-17 흡착 축 · 추가(iii) 라디안 경로의 정확히 3°** | AC-15 흡착 축 · AC-16 | 컴파일 실패. 흡착 여부와 무관하게 되곱는 구현이면 `1e308`에서 `inf`가 나가 빨강. (iii)이 BR-2의 엄격 부등호가 라디안 표면에서도 성립함을 관측 — **`12°` 왕복이 정확하다는 C-8에 의존한다**(다른 값이면 깨질 수 있다).<br>**AC-15·16이 감시인 근거**: 사이클 1이 이미 비유한을 후퇴시키므로 어댑터가 `guard core.snapped` 형태이기만 하면 추가 코드 없이 통과. 지키는 것은 "비유한을 0으로 후퇴시키는" 변이 |
| **4. enter 판정**<br>(의존 1·2·3) | **AC-13 · AC-14 · 추가(i) `16→29` · `359→1` 미발화 · `(.nan, 17)` 미발화 · 라디안 진입점** | `(.nan, .nan)` 미발화 | 컴파일 실패. `return now.snapped`면 AC-14 빨강 → "직전" 항을 끌어낸다. `now ∧ ¬before`면 AC-13·14 통과, **추가(i)이 빨강** → 목표 비교 항을 끌어낸다. raw 비교면 **`359→1`이 빨강** → **결정 A의 `normalized` 감쌈을 끌어낸다.** 가드가 없으면 **`(.nan, 17)`이 빨강**(M4의 유일한 증인).<br>**`(.nan, .nan)`이 감시인 근거**: 가드가 없어도 `now.snapped`가 거짓이라 이미 통과 |
| **5. 축 정렬 재정의**<br>(의존 없음) | **AC-12(`2π`) · 신규 `2π − 0.00005`** | AC-11 직접 · AC-11 간접 · 기존 9건 | AC-12는 현재 구현이 거짓을 내므로 **빨강**(고치는 버그). 신규 `2π−0.00005`는 **`turn − folded` 가지의 유일한 증인**이라 `min(...)` → `folded` 변이를 여기서만 죽인다.<br>**AC-11이 감시인 근거**: 현재도 초록, 새 구현도 초록. 지키는 것은 **`[0,2π)` 정규화로 미끄러지는 회귀**다(PRD 배경이 지목한 자기 유발 회귀) |

**병렬 가능**: 1 · 2 · 5는 상호 의존 없음. 3은 1에, 4는 1·2·3에 의존.

### 테스트 목록 — `RotationSnapTests.swift` (27건)

| # | 이름(안) | 축 | 분류 |
|---|---|---|---|
| 1 | `그리드에_가까운_각도가_흡착된다` | AC-1 `14` → `(true, 15)` | 유도 |
| 2 | `임계_바로_안쪽에서도_흡착된다` | AC-2 `12.1` → `(true, 15)` | 감시 |
| 3 | `정확히_3도는_흡착되지_않는다` | AC-3 `12` → `(false, 12)` | 유도 |
| 4 | `음수_각도도_흡착된다` | AC-4 `-13` → `(true, -15)` | 감시 |
| 5 | `두_그리드_한가운데는_흡착되지_않는다` | AC-5 `7` → `(false, 7)` | 감시 |
| 6 | `이미_그리드_위인_각도는_움직이지_않는다` | AC-6 `30` ★`#expect(r.snapped)` 보강 | 감시 |
| 7 | `누적_바퀴수가_보존된다` | AC-7 `373` → `(true, 375)` | 감시 |
| 8 | `한_바퀴_경계에서도_접지_않는다` | AC-8 `359` → `(true, 360)` | 감시 |
| 9 | `그리드_간격과_흡착_임계가_공개_상수다` | AC-18 `== 15` · `== 3` | 유도 |
| 10 | `음수_각도가_양수로_정규화된다` | AC-9 `-30` → `330` | 유도 |
| 11 | `여러_바퀴_각도가_정규화된다` | AC-10 `725` → `5` | 유도 |
| 12 | `극단_유한각의_정규화는_296도다` | AC-17 정규화 축 — **값 단언** | 유도 |
| 13 | `미세_음수는_360으로_올라가지_않는다` | 추가(ii) `-1e-15` | 유도 |
| 14 | `한_바퀴_안의_라디안은_접히지_않는다` | `normalized(radians: 4.0)` | 유도 |
| 15 | `극단_유한_라디안도_한_바퀴_안으로_접힌다` | `normalized(radians: 1e308)` = `5.720858487389101` **값 단언**(원장 C-11) | 유도 (**M1**) |
| 16 | `NaN의_정규화는_비유한으로_남는다` | AC-15 정규화 축 | 감시 |
| 17 | `극단_유한_라디안의_흡착_결과는_유한하다` | AC-17 흡착 축 | 유도 |
| 18 | `NaN은_흡착되지_않고_비유한으로_남는다` | AC-15 흡착 축 | 감시 |
| 19 | `무한대도_안전하게_후퇴한다` | AC-16 ★`#expect(!r.radians.isFinite)` 보강 | 감시 |
| 20 | `라디안_경로에서도_정확히_3도는_흡착되지_않는다` | 추가(iii) | 유도 |
| 21 | `흡착_구간에_진입하는_순간_참이다` | AC-13 `(20, 17)` | 유도 |
| 22 | `같은_구간에_머무는_동안_재발화하지_않는다` | AC-14 `(17, 16)` | 유도 |
| 23 | `다른_그리드로_넘어가면_다시_발화한다` | 추가(i) `(16, 29)` | 유도 (**결정 ⑤**) |
| 24 | `한_바퀴_경계를_넘어도_같은_그리드면_발화하지_않는다` | `(359, 1)` 미발화 | 유도 (**결정 A**) |
| 25 | `직전이_NaN이면_발화하지_않는다` | `(.nan, 17)` 미발화 | 유도 (**M4**) |
| 26 | `양쪽이_NaN이면_발화하지_않는다` | `(.nan, .nan)` 미발화 | 감시 |
| 27 | `라디안_진입_판정도_같은_답을_낸다` | `entersSnap(fromRadians:toRadians:)` | 유도 |

> 24·25는 test-architect 목록에 **없다.** 24가 없으면 결정 A가 증인 0건, 25가 없으면 M4 가드가 증인 0건이 된다. 14·15·27은 결정 B가 만든 API의 증인이다. **test-architect 목록의 대체가 아니라 확장이다.**

**테스트 규칙 2건 (파일 상단 doc):**
- **튜플 단언 금지** — `#expect(r == (true, 15.0))`는 Swift 표준 튜플 `==`가 `Double ==`을 몰래 들여온다. 반드시 2단언 분리.
- `private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }` — 선례 `ResizeAnchorTests.swift:5`.

### 테스트 목록 — `SnapEngineTests.swift` (신규 4건, 기존 9건 유지)

| # | 이름(안) | 축 | 분류 |
|---|---|---|---|
| A | `미세_음수_회전은_축_정렬로_유지된다` | AC-11 직접 | 감시 |
| B | `미세_음수_회전_레이어가_스냅_후보에_포함된다` | AC-11 간접 — `frame(x: 543, y: 400, rot: -0.00005)` | 감시 |
| C | `한_바퀴_돈_레이어도_축_정렬로_인식된다` | AC-12 `2π` | 유도 |
| D | `한_바퀴에_거의_근접한_회전도_축_정렬이다` | `2π − 0.00005` | 유도 (**M5**) |

## 위험

1. **AC-3 경계의 결정성은 `snapped(degrees:)`의 비교 한 줄에 있다.** 비교를 라디안 공간으로 옮기는 리팩터링이 AC-3을 깬다(원장 #3). — **드러나는 곳: 그 리팩터링 직후 테스트(빨강).**
2. **`degrees(fromRadians:)` 합성이 문서 저장을 실패시킨다.** 유한 라디안 `|r| >= 3.1375664143845866e306`이 `inf`가 되고 `normalized(degrees:)`에 먹이면 **NaN**(C-1). 이 단위 안에서는 닫았지만 **함수가 `public`이라 EDITOR-11이 손으로 합성하면 되살아난다.** — **드러나는 곳: 사용자에게서(저장 실패). 가장 회수 비용이 큰 잔여 위험.** *(1회차 위험 #7 "결과 유한성 가드 없음"을 실제 위험 축으로 교체.)*
3. **단위 오용이 컴파일되고 조용히 파괴적이다.** `|r| < 3 rad`(±171.9°) 전 구간이 `(true, 0.0)`(C-2). 반환이 유한하고 `snapped == true`라 정상으로 보인다. 방어는 인자 라벨과 doc뿐 — 타입으로 닫으려면 `Degrees`/`Radians` 래퍼가 필요한데 AC-18의 리터럴 단언과 저장소 관례를 함께 깬다. — **드러나는 곳: 없다.** 화면에서 "돌리면 0°로 튄다"로만 관측된다.
4. **결정 A·⑤의 증인이 추가 테스트 2건뿐이다**(#23·#24). 둘 다 AC가 아니다. 지워지면 목표 비교 조건절과 `normalized` 감쌈이 죽은 코드가 된다. — **드러나는 곳: 없다.**
5. **`folded`의 `>= period` 클램프 증인이 `-1e-15` 한 입력이다**(#13). 도 축 한 곳에서만 관측되고 라디안 축에는 증인이 없다. — **드러나는 곳: 없다.**
6. **`HandlePlacement.swift:230`의 실측 문서가 `gridStepDegrees`에 의존한다.** 15를 바꾸면 "24개 눈금 중 13/12/12개"가 무효인데 컴파일러도 테스트도 잡지 않는다. — **드러나는 곳: 코드 리뷰뿐.**
7. **`isAxisAligned`를 `internal`로 여는 것** — 모듈 내부에서 두 임계(0.0001 rad vs 3°)의 혼동이 가능. BR-5는 규율로만 지켜진다. — **드러나는 곳: 없다.**
8. **`2π − 0.00005` 동작 변경에 AC가 없다.** 한 바퀴에 거의 근접한 레이어가 **새로** 후보에 들어온다. 신규 테스트 #D가 유일한 기록이다. — **드러나는 곳: 그 테스트를 지운 뒤에는 없다.**
9. **`entersSnap`의 `>= gridStepDegrees` 반례가 실재한다**(C-7, 약 1.9e14 바퀴). 실사용 도달 불가. 정규화 후 잔존은 미실측. — **드러나는 곳: 없다.**
10. **`entersSnap(fromRadians:)`가 극단 구간에서 발화하지 않는다.** `|r| >= 3.1375664143845866e306`이면 변환이 `inf`가 되어 가드가 미발화로 후퇴시킨다. 정직한 후퇴이며 실사용 도달 불가지만 **테스트 증인이 0건이다.** — **드러나는 곳: 없다.**
11. **공개 표면이 10개로 커졌다**(상수 2 + 함수 8). 결정 B가 합성을 없앤 대가다. EDITOR-11이 도 표면을 고르면 위험 #2·#3의 재료가 된다. 완화는 타입 doc의 단위 규약 문단 하나뿐이다. — **드러나는 곳: 코드 리뷰뿐.**

## doc 주석 계획

이 저장소는 **주석이 설계 원장**이다. 다음 단위가 주석에서 설계를 재구성한다.

**`RotationSnap`(타입 doc)** — `enum`인 이유 · `SnapKind`에 안 넣은 4근거(특히 `public` enum 케이스 추가는 소스 호환성 파괴) · **단위 규약**(도 = 판정 본체 + 테스트가 읽는 곳, 라디안 = 프로덕션 소비 단위, 세 판정 전부 두 단위로 열려 합성할 이유가 없다) · **M2 붕괴표(C-2) 그대로** — `15°`·`45°`·`90°`·`170°` 전부 `(true, 0.0)`, `171.9°`에서 처음 `(false, 3.000220984178253)`. **컴파일러가 막지 않으며 인자 라벨이 유일한 방어다.**

**`gridStepDegrees`** — 도인 이유(라디안이면 AC-18이 공허) · ⚠️ **`HandlePlacement.swift:230` 실측 문서가 이 값에 의존**(15를 바꾸면 무효인데 컴파일러도 테스트도 안 잡는다) · 라디안 눈금 상수를 두지 않는 이유.

**`snapThresholdDegrees`** — **엄격 부등호, 정확히 3°는 미흡착**(BR-2). 저장소 관례 3개 중 2개가 "경계는 이전 상태"(`edgeHideThreshold` `>= 88`, `cornerPushThreshold` `< 56`)이고 `flipThreshold`(`<= 40`)만 반대인데 `HandlePlacement.swift:86-89`가 예외로 명시 문서화한 자리 · `axisAlignToleranceRadians`와 통합 금지(BR-5) · **라디안 공간에서 재면 이 경계가 깨진다**(수치 병기).

**`snapped(degrees:)`** — 판정의 유일한 본체 · 정규화 이전 원본 기준(FR-4) · 후퇴 대상이 입력 자신이라 FR-7·FR-8이 서로를 방해하지 않음 · **FR-8이 성립하는 진짜 이유**(되곱이 안 넘쳐서가 아니라 `inf < 3`이 거짓이라 후퇴. *1차의 "15 × ulp/2 < ulp(gFM)" 유도는 거짓이니 물려받지 마라*) · **이 함수는 유한 입력에서 절대 비유한을 못 낸다(C-9) → AC-17 흡착 축을 여기로 재면 공허하다.**

**`snapped(radians:)`** — 합성이 안전한 이유(중간 `inf`도 `guard core.snapped`가 입력으로 후퇴시킴) · **합성 결과 자체는 미실측이며 사이클 3의 RED가 처음 관측한다** · 되돌릴 때 **같은 `radiansPerDegree`로 곱한다**(별도 `180/.pi`면 3°에서 갈라짐) · **M6 왕복 부정확 표(C-8) 그대로**: `12`·`3`·`2.9`·`17`·`16`·`373`·`359` 정확 / `15` → `14.999999999999998`, `29` → `29.000000000000004`. **라디안 테스트가 `12°`를 쓰는 것은 그 값이 정확하기 때문이며 다른 값이면 깨질 수 있다.**

**`normalized(degrees:)`** — `[0°,360°)` 항상 양수 · **`>= period` 클램프가 필요한 이유**(`-1e-15` → 정확히 `360.0`, 유일한 증인) · **`floor` 변이는 범위 단언으로 안 죽는다**(`1e308`에서 `0.0`). 올바른 값 `296.0`, **값을 단언해야 죽는다** · **프로덕션 소비자가 있다**(`entersSnap`의 목표 비교).

**`normalized(radians:)`** — **도 정규화를 감싸지 않는 이유(M1)**: `degrees(fromRadians: 1e308)` = `inf` → `normalized(inf)` = NaN → `JSONEncoder`가 던져 **문서 저장 실패** · **닫힌 형태라 FR-8이 구조적으로 성립 — 가드가 없는 것이 설계다** · `2π`와 360°는 같은 것의 두 표현이지만 binary64에서는 다른 수이며 **두 진입점의 결과가 마지막 몇 ulp에서 다를 수 있고 피할 수 없다.**

**`folded(_:period:)`** — 접기 규칙이 저장소에 한 벌만 있게 하는 장치. 세 단계가 규칙이고 단위는 `period` 하나 · **귀결**: 세 변이의 증인이 도 축 한 곳에서 전부 확보되고 라디안 축은 배선만 관측한다.

**`entersSnap(fromDegrees:toDegrees:)`** — 규칙과 v4 근거 · **M3 정의역**(두 인자는 **흡착 판정에 넣기 전의 원시 각도**이며 직전 *흡착 결과*나 정규화값이 아니다. `normalized`는 목표 비교 한 곳에만) · **목표 비교가 정규화값이어야 하는 이유**(8건 표 병기, raw는 `359°→1°`에서 같은 그리드인데 재발화) · **M7 구조적 근거를 좁혀 적음**(C-7 반례 + 그 구간의 오동작 + 정규화 후 잔존은 미실측) · **M4 `previous.isFinite` 가드**(없으면 `(.nan,17)` = `true`) · **`current.isFinite`를 두지 않는 이유**(`now.snapped`가 전부 막아 증인 0건) · ⚠️ **AC가 이 결정을 관측하지 않는다 — 유일한 증인은 #23·#24 두 테스트이며 지워지면 조건절 전체가 죽은 코드가 된다.**

**`entersSnap(fromRadians:toRadians:)`** — **합성으로 위임해도 안전한 이유는 반환이 `Bool`이기 때문**(각도가 밖으로 나가지 않아 C-1의 NaN이 `LayerTransform`에 도달할 수 없다. `normalized(radians:)`가 같은 합성을 쓸 수 없는 것과 정확히 갈리는 지점) · 유한성 가드는 도 본체에 한 번만 · ⚠️ 극단 구간에서 미발화(정직한 후퇴, 실사용 도달 불가).

**`degrees(fromRadians:)` / `radians(fromDegrees:)`** — `radiansPerDegree` 한 벌, 반대 방향은 같은 상수로 **나눈다** · **`degrees(fromRadians:)`는 FR-8을 만족하지 않으며 만족할 수 없다** — `|r| >= 3.1375664143845866e306`에서 `inf`. **올바른 값이 `Double`로 표현 불가능하므로 어떤 구현도 유한한 정답을 낼 수 없다.** 클램프하면 조용한 거짓말이고 `inf`는 넘쳤다는 IEEE-754 신호다(`ResizeAnchor.swift:156`의 판단과 같은 형태) · ⚠️ **이 함수의 출력을 다시 판정에 먹이지 마라 — 그 합성이 C-1이다** · `radians(fromDegrees:)`가 안전한 근거는 **1보다 작은 상수를 곱해 크기가 줄어들기 때문** · **`public`인 이유가 저장소 관례의 반대 방향임을 명시**(정책 상수는 열면 재기술되지만 변환은 닫으면 재기술된다) · **`Self.` 한정자가 필수**(C-10).

**`SnapEngine.swift`** — `SnapKind`(`:5`)에 회전을 안 넣은 이유 · `snapCandidates`(`:43-46`)의 **"회전됨"의 정의가 바뀌었음**(한 바퀴 돈 레이어는 이제 회전되지 않은 것으로 본다) · `axisAlignToleranceRadians`의 단위를 이름에 박는 이유 · `isAxisAligned(radians:)`에 **원장 1차 #10 실측표 5행 그대로** + `[0,2π)` 정규화로 바꾸면 AC-11 회귀 + **M5 `turn − folded`의 유일한 증인이 `2π − 0.00005`** + `normalized(radians:)`로 접지 않는 이유 + 비유한에서 `min`이 NaN이라 거짓(현재 동작과 같음) + `internal`인 이유 + 오버로드를 남기지 않는 이유.

**테스트 파일 doc** — 튜플 단언 금지 1줄 · `isClose` 선례 · `296.0`·`5.720858487389101` 값 단언이 가능한 이유(`truncatingRemainder`가 정확 연산) · #14가 `4.0`을 쓰는 이유(`period = π` 변이의 유일한 증인) · #D가 **AC 없는 동작 변경의 유일한 기록**임.

---

## Testability 평가 (test-architect)

### 컴포넌트별 테스트 전략

**전 컴포넌트가 `Double` → `Double`/`Bool`/튜플 순수 함수다. 모의 대상 0건, DI 불필요, 전역 가변 상태 0건, 시계·난수·I/O 0건.**

| 컴포넌트 | 단위 테스트 | 격리 전략 | AC 매핑 |
|---|---|---|---|
| `snapped(degrees:)` | 입력 리터럴 직접 주입, 2단언 분리 | `enum` + `static let`이라 인스턴스 상태가 없어 테스트 간 오염 경로가 구조적으로 부재 | AC-1~8 |
| `snapped(radians:)` | 동일. AC-17 흡착 축은 **반드시 이 API로** | `private radiansPerDegree` 단일 출처. 변환 2개가 `public`이라 **테스트가 `.pi/180`을 스스로 적을 필요가 없다**(두 번째 기술 회피) | AC-15~17, 추가(iii) |
| `normalized(degrees:)`/`(radians:)` | **값 단언**. 범위 단언 금지(`floor` 변이가 통과) | 흡착과 완전 분리 — 한쪽 변이가 다른 쪽 테스트로 새지 않는다 | AC-9·10·15·17, 추가(ii) |
| `entersSnap(...)` | 직전 상태를 **인자로** 받아 시퀀스 재생이 불필요 — testability 관점의 최대 강점 | 없어도 됨 | AC-13·14, 추가(i) |
| 공개 상수 | 상수 리터럴 단언. `15`·`3`은 binary64 정확 표현이라 `==`가 안전하며 `edgeHideThreshold == 88`과 같은 형태 | `public static let` — EDITOR-11의 단일 출처 | AC-18 |
| `isAxisAligned(radians:)` | `@testable`로 파일 스코프 internal 자유 함수 직접 호출. 현재는 `private func`이라 **RED에서 `cannot find in scope` 컴파일 실패가 정직하게 성립** | `internal` + `@testable`. **테스트 가능성을 전혀 깎지 않는다** | AC-11·12, 신규 `2π−0.00005` |

### 공허 단언 판정

| 대상 | 공허한가 | 근거 |
|---|---|---|
| **AC-18** `gridStepDegrees == 15` | ❌ 아니다 | `15 → 15+ε` 섭동은 AC-7(index 25, 증폭 25ε)이 최대 제약이라 `ε < 0.0004`면 AC-1~8을 전부 통과한다. `ε < 0`은 AC-3이 죽인다. **ε ∈ (0, 0.0004)가 AC-18에서만 죽는다** |
| **AC-17 정규화 축(유한성만)** | ✅ **공허** | `truncatingRemainder`는 오버플로 경로가 없고 `floor` 변이도 `1e308`에서 `0.0`(범위 안). **어떤 구현도 비유한을 못 낸다** → **값 단언으로 승격 필수** |
| **AC-17 흡착 축(도 API)** | ✅ **공허** | 도 공간은 유한 입력에서 비유한 불가(C-9) → **라디안 API로만 유효** |
| **AC-17 흡착 축(라디안 API)** | ❌ 아니다 | `degrees(fromRadians: 1e308)` = `inf`. 무조건 되변환 구현이 `inf`를 내 빨강 |
| **AC-11 간접 관측** | ❌ 아니다 / ⚠️ 킬셋 포섭 | `\|543−540\| = 3 ≤ 8`이라 새 구현은 후보 1건, `[0,2π)` 구현은 `[]`. **두 구현이 실제로 갈린다.** 다만 고유 킬셋 미발견 — 존재 이유는 킬셋이 아니라 **경로 커버리지**이며 그 이유를 doc에 적지 않으면 다음 리뷰에서 "중복"으로 지워진다 |
| **AC-6** `30° → 30°` | ⚠️ 준공허 | Then이 결과 각도만 요구 → `(false, 30)` 구현도 통과. **`#expect(r.snapped)` 보강 필요** |
| **AC-16** | ⚠️ 저출력 | `(false, 0.0)` 반환 변이가 통과. **`#expect(!r.radians.isFinite)` 보강 필요** |
| **AC-5 · AC-13** | ⚠️ 저출력 | 각각 AC-3·AC-14에 포섭. 고유 킬셋 미발견 |

### Testability Score: **8/10** — ✅ TESTABILITY PASS

**감점 2점** ⑴ 결정 ④의 `turn − folded` 가지 증인 0건 ⑵ RED가 성립하지 않는 AC 4건(AC-15·16, AC-17 정규화 축, AC-11 직·간접).

**둘 다 인터페이스·의존성 구조의 결함이 아니라 테스트 계획의 결함이다** — 함수 시그니처를 하나도 바꾸지 않고 테스트 추가 + 단언 강화로 닫힌다. **architect 재설계는 요구하지 않는다.**

### GREEN 진입 전 필수 조건 (전부 설계 2회차에 반영됨)

1. ✅ `2π − 0.00005` 축 정렬 테스트 추가 (테스트 #D)
2. ✅ AC-17 흡착 축은 라디안 API로만 (사이클 3)
3. ✅ AC-17 정규화 축을 값 단언(`296.0`)으로 승격 (테스트 #12)
4. ✅ AC 밖 추가 테스트 3건 전부 포함 (#13·#20·#23)
5. ✅ 단언 보강 3건 (#6·#19·#26)
6. ✅ 튜플 단언 금지 규칙 명문화
7. ✅ RED 재분류 — 사이클 표에 **유도/감시** 구분 표기

**설계 2회차가 추가로 넣은 것**: #24(`359→1` — 결정 A의 증인), #25(`(.nan,17)` — M4의 증인), #14·#15·#27(결정 B가 만든 API의 증인). test-architect 목록의 **확장**이다.

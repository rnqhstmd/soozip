# EDITOR-8 — 회전 (15° 스냅) 기술 설계 초안 (architect 1회차)

> 오케스트레이터 재검증 결과는 `.dev/feat-editor-rotation/orchestrator-verification.md`에 별도로 있다.
> **아래 §수치 검증의 항목 4(도 공간 오버플로)와 §구현 순서 사이클 2의 RED 근거는 재검증에서 거짓으로 판명됐다.**

## 설계 규모

**중형**

## 배치 결정

| 무엇 | 어디 |
|---|---|
| 회전 그리드 스냅 · 정규화 · enter 판정 · 도↔라디안 변환 | **신규** `Packages/SoozipGeometry/Sources/SoozipGeometry/RotationSnap.swift` (`public enum RotationSnap` — 네임스페이스) |
| 축 정렬 판정 재정의 (FR-6) | **수정** `SnapEngine.swift:37`, 호출부 `:52`·`:55` |
| `SnapKind`에 회전을 넣지 않는 이유 | **수정(주석만)** `SnapEngine.swift:5` |
| 신규 테스트 | **신규** `RotationSnapTests.swift` |
| 축 정렬 회귀·버그 수정 테스트 | **수정** `SnapEngineTests.swift` |

`RotationSnap`은 `enum`이다 — 인스턴스 상태가 없고, `struct`로 두면 암묵 `init()`이 생겨 `RotationSnap()`이 컴파일된다.

도↔라디안 변환을 별도 `Angle` 네임스페이스로 빼지 **않는다**. 이 저장소에서 `.pi/180`을 쓰는 소비자는 이 단위 하나뿐이고(`HandlePlacement.swift:189`는 `sin/cos`에 라디안을 그대로 넣는다), 범용 네임스페이스는 **두 번째 `.pi/180` 경로를 초대한다**.

## 공개 API

```swift
public enum RotationSnap {

    /// 15° 그리드 간격. **도(degree)다.** 라디안으로 두면 AC-18의
    /// "정확히 15°" 단언이 정의의 재진술이 되어 공허해진다(→ 결정 ②).
    /// ⚠️ `HandlePlacement.swift:230`의 실측 문서가 **이 값에 의존한다.**
    public static let gridStepDegrees: Double = 15

    /// 흡착 임계. **엄격 부등호 — 정확히 3°는 미흡착**(BR-2).
    public static let snapThresholdDegrees: Double = 3

    /// FR-1 · FR-2 · FR-4 — AC-1~AC-8. **판정의 유일한 본체.**
    public static func snapped(degrees: Double) -> (snapped: Bool, degrees: Double)

    /// FR-7 · FR-8 — AC-15 · AC-16 · AC-17. 라디안 배선용 어댑터.
    public static func snapped(radians: Double) -> (snapped: Bool, radians: Double)

    /// FR-3 · BR-3 — AC-9 · AC-10 · AC-17
    public static func normalized(degrees: Double) -> Double

    /// FR-5 — AC-13 · AC-14
    public static func entersSnap(fromDegrees previous: Double,
                                  toDegrees current: Double) -> Bool

    public static func degrees(fromRadians radians: Double) -> Double
    public static func radians(fromDegrees degrees: Double) -> Double

    private static let radiansPerDegree: Double = .pi / 180
}
```

`SnapEngine.swift`:

```swift
/// 정렬·간격 가이드 후보 자격의 허용오차(**라디안**).
/// **`RotationSnap.snapThresholdDegrees`(3°)와 통합하지 않는다**(BR-5).
private let axisAlignToleranceRadians: Double = 0.0001

/// FR-6 — 가장 가까운 360° 배수까지의 거리로 판정한다. `internal`이다.
func isAxisAligned(radians r: Double) -> Bool
```

구현 골자:

```swift
// snapped(degrees:)
let index = (degrees / gridStepDegrees).rounded()
let candidate = index * gridStepDegrees
guard abs(degrees - candidate) < snapThresholdDegrees else { return (false, degrees) }
return (true, candidate)

// snapped(radians:)
let core = snapped(degrees: degrees(fromRadians: radians))
guard core.snapped else { return (false, radians) }
return (true, radians(fromDegrees: core.degrees))

// normalized(degrees:)
var r = degrees.truncatingRemainder(dividingBy: 360)
if r < 0 { r += 360 }
if r >= 360 { r = 0 }
return r

// entersSnap
let now = snapped(degrees: current)
guard now.snapped else { return false }
let before = snapped(degrees: previous)
guard before.snapped else { return true }
return abs(before.degrees - now.degrees) >= gridStepDegrees

// isAxisAligned(radians:)
let turn = 2 * Double.pi
let folded = abs(r.truncatingRemainder(dividingBy: turn))
return min(folded, turn - folded) < axisAlignToleranceRadians
```

## 설계 긴장 5가지에 대한 결정

### ① `SnapCandidate`에 회전을 담을 수 없다 → **(c) 별도 모듈 + 라벨 튜플**

근거: ⑴ `SnapCandidate`의 소비자는 가이드 **선 렌더러**인데 회전에는 그을 선이 없다(v4가 지정한 표현은 **각도 배지**). `.rotation`을 넣으면 모든 소비자가 `axis`를 만지기 전에 `kind`로 분기해야 하고 잊은 코드가 회전 후보의 `axis`를 좌표로 읽는다. ⑵ `snapCandidates`의 입력 넷 중 회전이 쓰는 것이 **하나도 없다**. ⑶ `SnapKind`는 `public`이라 케이스 추가가 **소비자 exhaustive switch를 깨는 소스 호환성 변경**이다. ⑷ 선례: `HandlePlacement`/`HandleHitTest`가 둘 다 "핸들"이지만 별도 타입.

구조체 대신 **라벨 튜플** — `LayerFrame.resizeLimits(canvas:)`·`CanvasSurface.zoomLimits` 선례.

버린 비용: "이번 프레임의 스냅 전부"를 한 리스트로 보려는 소비자는 두 출처를 합쳐야 한다. 그 합류 지점(햅틱 우선순위)은 PRD가 이미 `EDITOR-11`로 이월했다.

### ② 라디안이냐 도냐 → **(b) 도 단위 공개 상수 + 도 공간 연산 + 라디안 어댑터**

**근거 1 — AC-18이 라디안을 배제한다.** `15° = π/12`는 정확 표현 불가라 `#expect(gridStep == .pi/12)`는 정의의 재진술(공허). 도 상수면 `#expect(gridStepDegrees == 15)` — `edgeHideThreshold == 88` 형태의 **상수 리터럴 단언**이 성립.

**근거 2 — 라디안 공간 연산은 AC-3을 실제로 깬다.** `|fl(12·fl(π/180)) − fl(15·fl(π/180))| = 1886463400540916 × 2⁻⁵⁵`, 임계 `fl(3·fl(π/180)) = 1886463400540917.5 × 2⁻⁵⁵` → **거리 < 임계 → 흡착 → AC-3 반증.** 도 공간은 `|12−15| = 3` 정확, `3 < 3` 거짓.

**근거 3 — 바퀴 수 보존도 도 공간에서만 깔끔하다.** `373/15 = 24.8666…` → `25` → `375` 정확. `359/15 = 23.9333…` → `24` → `360` 정확.

**변환 상수는 한 벌이어야 한다.** `fl(15·fl(π/180))`과 `fl(π/12)`는 비트 동일이지만 **3°는 1 ulp 갈라진다**(`fl(3·fl(π/180))` vs `fl(π/60)`). 따라서 `radiansPerDegree` 하나만 두고 반대 방향도 **같은 상수로 나눈다**.

### ③ 바퀴 수 + 엄격 부등호 + 오버플로 → **(b) 후퇴 대상을 "입력 각도 그대로"로**

```swift
guard abs(degrees - candidate) < snapThresholdDegrees else { return (false, degrees) }
```
- `NaN` → `abs(NaN−NaN) = NaN` → `NaN < 3` **거짓** → `(false, NaN)` ✓ AC-15
- `∞` → `abs(∞−∞) = NaN` → 거짓 → `(false, ∞)` ✓ AC-16
- `1e308` rad → rad→deg가 **∞로 넘침** → 같은 경로 → `(false, 1e308)` **유한** ✓ AC-17

**후퇴 대상이 입력 자신이라 FR-7과 FR-8이 서로를 방해하지 않는다.**

`ResizeAnchor`의 2단 가드를 이식하지 않는 이유: 그 함수는 **한계값이 조용히 사라져 완벽히 유한한 오답이 나오는 축**이 있었다(`(2,1)`). 회전 스냅에는 그 축이 없다 — 임계가 상수라 "사라질 한계"가 존재하지 않는다. 이유 없이 이식하면 증인 0건의 죽은 가드가 된다.

> ⚠️ **재검증에서 거짓으로 판명**: "도 공간 되곱은 넘치지 않는다"는 유도는 사실이 아니다(`d = gFM`에서 `idx*15 = inf`). 결론(FR-8 성립)은 유지되나 **근거는 "곱셈이 안 넘친다"가 아니라 "넘쳐도 `inf < 3`이 거짓이라 입력으로 후퇴한다"**여야 한다.

### ④ `isAxisAligned` 수정과 회귀 → **(b) fmod 후 양쪽 거리 최소**, 노출은 **(ii) internal + @testable**

```swift
let turn = 2 * Double.pi
let folded = abs(r.truncatingRemainder(dividingBy: turn))
return min(folded, turn - folded) < axisAlignToleranceRadians
```

세 입력: `-0.00005` → `0.00005` **참** / `2π` → `0` **참**(고치는 버그) / `2π−0.00005` → `0.00005` **참**.
`[0,2π)` 정규화 방식이면 `-0.00005`가 **거짓**이 되어 회귀(AC-11이 고정).

비유한: `NaN`·`±∞` 모두 `fmod`이 `NaN` → `min`이 `NaN` → 거짓. **현재 동작과 동일 — 회귀 없음.**

`public`을 피하는 이유: `RotationSnap` 옆에 **임계가 다른 두 번째 공개 판정**이 생겨 BR-5가 금지한 혼동을 호출부에서 만든다. `edgeHideThreshold`가 `internal`인 이유와 같다.

**AC-12는 간접 관측으로 잴 수 없다** — Then이 "축 정렬 판정이 참"뿐이라 후보 리스트로 바꾸면 다른 조건이 함께 필요해 어느 축이 잘랐는지 구분되지 않는다. **AC-11만 간접 관측을 추가**한다(Then이 두 절이므로). 픽스처 `frame(x: 543, y: 400, rot: -0.00005)`는 캔버스 수직 중심선(540)에서 3pt라 두 구현이 실제로 갈린다.

**호출부 정리**: `LayerFrame` 오버로드를 남기지 않는다 — 같은 이름 오버로드 둘이 파일 스코프에 있으면 함수 참조가 문맥 타입으로 해소되어 한쪽을 지우는 변이가 조용히 컴파일된다.

### ⑤ enter 판정 → **(b) `현재 흡착 ∧ (¬직전 흡착 ∨ 직전 목표 ≠ 현재 목표)`**

근거: v4 §5.8.2 원문이 *"**같은 가이드**에 계속 붙어 있는 동안에는 재발화하지 않는다"*. "같은"이 조건절의 핵심. `SnapKind.alignment`가 이미 같은 의미론.

목표 비교를 `==`로 쓰지 않는다 — 두 값이 모두 `index * gridStepDegrees`라 같으면 차가 **정확히 0**, 다르면 **최소 `gridStepDegrees`**. `abs(before.degrees - now.degrees) >= gridStepDegrees`로 쓴다.

⚠️ **이 결정은 AC-13·AC-14 어느 쪽으로도 관측되지 않는다.** 둘 다 (a)·(b)에서 똑같이 통과한다. 관측하려면 AC 밖 테스트 1건 필요:
`직전_16도에서_현재_29도로_넘어가면_다른_그리드에_새로_걸려_발화한다` (before 16°→15°, now 29°→30°, `|15−30| = 15 >= 15` → 참. (a) 구현이면 거짓 → 빨강)

## 수치 검증 (architect 산출 — 재검증 결과는 별도 문서 참조)

1. `fl(15·fl(π/180))` ≡ `fl(π/12)` = `4716158501352293 × 2⁻⁵⁴` ≈ `0.2617993877991494` ✅ 재검증 확인
2. `fl(3·fl(π/180))` = `7545853602163670 × 2⁻⁵⁷`, `fl(π/60)` = `7545853602163669 × 2⁻⁵⁷` — **1 ulp 차** ✅ 재검증 확인
3. 라디안 공간에서 AC-3 반증: `1886463400540916 < 1886463400540917.5` ✅ 재검증 확인
4. 오버플로: rad→deg가 **|r| ≳ 3.13757e306**에서 ∞ ✅ / **도 공간 되곱은 넘치지 않는다** ❌ **거짓 — 재검증 참조**
5. 왕복: `degrees(fromRadians: radians(fromDegrees: 12))` = 정확히 `12.0`
6. `normalized(-1e-15)`가 클램프 없으면 `360.0` ✅ 재검증 확인

## 변경 범위

| 파일 | 신규/수정 | 무엇 |
|---|---|---|
| `RotationSnap.swift` | **신규** | 상수 2, 흡착 2(도·라디안), 정규화 1, enter 1, 변환 2, private 변환상수 1 |
| `SnapEngine.swift` | 수정 | `:5` doc · `:37` `isAxisAligned(radians:)` · `axisAlignToleranceRadians` 명명 · `:52`·`:55` 호출부 |
| `RotationSnapTests.swift` | **신규** | AC-1~10, 13~18 + `isClose` |
| `SnapEngineTests.swift` | 수정 | AC-11(직접+간접) · AC-12. 기존 9건 전부 유지 |
| `HandlePlacement.swift` | **변경 없음** | `:230` 의존 사실은 `RotationSnap` doc에만 적는다 |
| `SoozipLayout/**` · `Package.swift` | **변경 없음** | 새 의존 0건 |

## 구현 순서 (RGR 사이클 분해)

| 사이클 | AC | RED에서 무엇이 실패하는가 |
|---|---|---|
| **1. 도 단위 그리드 흡착 + 공개 상수** | AC-18,1,2,3,5,6,4,7,8 | 컴파일 실패. "정규화 후 흡착" 최소 구현이면 AC-7(373→15)·AC-8(359→0)·AC-4(−13→345)가 빨강. `<=` 변이는 AC-3(거리 정확히 `3.0`)이 죽인다. 상수 변이는 AC-18이 죽인다 |
| **2. `[0°,360°)` 정규화** | AC-9,10,17(정규화축), BR-3 경계 | 컴파일 실패. **`floor` 변이 감지 근거는 재검증에서 무효** — 범위 단언이 아니라 **값 `296.0`을 단언**해야 죽는다. `>= 360` 클램프가 없으면 `-1e-15`가 `360.0` → 빨강 |
| **3. 라디안 어댑터 + 비유한 방어** | AC-15,16,17(흡착축) | 컴파일 실패. 흡착 무관하게 되돌리는 구현이면 `1e308`에서 ∞ → 빨강. 비유한을 0으로 후퇴시키면 AC-15 빨강. 별도 `180/.pi` 상수 변이는 3°에서 1 ulp 어긋남 |
| **4. enter 판정** | AC-13,14 (+ 다른-그리드 전이 1건) | 컴파일 실패. `now.snapped`만 보면 AC-14 빨강. `now && !before`만 보면 AC 둘 다 통과하지만 추가 1건이 빨강 — **결정 ⑤의 유일한 증인** |
| **5. 축 정렬 재정의** | AC-11,12 | AC-12(`2π`)가 현재 거짓이라 **빨강**. AC-11은 현재도 초록이며 **회귀 감시**로 넣는다. 기존 9건 전부 초록 유지 |

사이클 1·2·5는 상호 의존 없음. 3은 1에, 4는 1에 의존.

## 위험

1. **AC-3 경계는 도 공간에서만 결정적** — "라디안으로 통일하라"는 리팩터링이 AC-3을 깬다. 드러나는 곳: 그 리팩터링 직후 테스트.
2. **공개 진입점이 둘** — EDITOR-11이 도 버전 + 자기 변환을 짜면 `.pi/180`이 두 곳이 되어 3°에서 1 ulp 갈라진다. **드러나는 곳: 코드 리뷰뿐.**
3. **결정 ⑤가 AC로 관측되지 않는다** — 추가 테스트가 지워지면 조건절이 죽은 코드. **드러나는 곳: 없다.**
4. **`normalized`의 `>= 360` 클램프도 AC가 없다** — 유일한 증인이 `-1e-15`. **드러나는 곳: 없다.**
5. **`HandlePlacement.swift:230` 실측 문서가 `gridStepDegrees`에 의존** — 15°를 바꾸면 무효가 되는데 컴파일러도 테스트도 잡지 않는다.
6. **`isAxisAligned`를 `internal`로 여는 것** — 모듈 내부에서 두 임계 혼동이 가능. 규율뿐.
7. **결과 유한성 가드를 두지 않은 판단** — 틀렸다면 비유한 `rotation`이 `LayerTransform`에 앉아 `JSONEncoder`가 던져 **문서 저장이 실패**한다. **드러나는 곳: 사용자에게서.** 가장 회수 비용이 큰 가정.

## 확인이 필요한 사항 (architect 제기)

1. **AC-17의 `1e308`을 흡착에서는 라디안, 정규화에서는 도로 해석하는가?** (도 공간 흡착은 애초에 안 넘쳐 단언이 공허해진다)
   - (a) 흡착은 라디안 API, 정규화는 도 API로 각각 (권장) / (b) 둘 다 라디안 표면 추가 / (c) 둘 다 도 표면
2. **AC 밖 추가 테스트 3건을 포함하는가?**
   - (i) 다른-그리드 전이 발화 (ii) `-1e-15` 정규화 클램프 (iii) 라디안 경로의 정확히 3°
   - (a) 3건 모두 (권장) / (b) (i)·(ii)만 / (c) AC 18건만

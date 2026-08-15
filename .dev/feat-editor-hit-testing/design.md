# 설계서: EDITOR-5 — 핸들 히트 판정 (2회차)

- 작성일: 2026-08-15 (2회차 — MUST-ADDRESS 2건 + 픽스처 구멍 4건 반영)
- PRD: `.dev/feat-editor-hit-testing/prd.md` · 코드 맵: `.dev/feat-editor-hit-testing/codemap.md`
- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §5.7 · §5.9
- 선행: `EDITOR-4` (`main` = `94347ff`)

## 배경 및 목적

`EDITOR-4`가 "핸들이 화면 어디에 있는가"를 확정했다. 이 단위는 **"화면의 한 점을 눌렀을 때 그중 무엇이 잡히는가"** 를 정의한다. 후보 목록(제스처 종류 없이 조회 가능)과 제스처 확정 판정(BR-3 정책 포함)을 함께 낸다.

그리고 `EDITOR-4` 리뷰에서 Minor M2로 미뤄진 **`orderedHandles`·`edges`의 doc comment 부재**를 닫는다. 그 부재는 이미 비용을 냈다 — 이 단위의 PRD 초안이 `Box.delete`의 "누가 이기는지는 `orderedHandles`의 순서 하나가 정한다"만 읽고 제스처 축을 못 봐서 "좌상단 코너는 영원히 리사이즈 불가"를 수용한 채 나왔다.

**1회차가 같은 실수를 반복했다.** §1-g가 "FR-2·FR-6은 구조가 보장한다"고 단정했으나 `Box`가 코너 4개를 `public let`으로 공개해(`:27-30`) 회전·배율이 **박스에서 파생 복원된다**. `EDITOR-4`가 "막는 방식은 구조다"로 정정당한 것과 같은 형태다. 2회차는 그 문장을 **"테스트가 고정한다"** 로 다시 쓴다.

## 변경 범위

**영향 모듈**: `SoozipGeometry` 단독. Layout·Draft·앱·layoutJSON 무영향. 새 의존성 0.

**신규 파일**

| 경로 | 내용 |
|---|---|
| `…/SoozipGeometry/HandleHitTest.swift` | `HandleGesture` + `accepts(_:)`(internal) + `extension HandlePlacement`(`hitSize`(internal) · `hitCandidates(at:)` · `hitHandle(at:for:)` · `isHit(_:near:)`) |
| `…/SoozipGeometryTests/HandleHitTestTests.swift` | AC-1~14 + 변이 방어 M1~M7 (총 24건) |

**수정 파일** (동작 코드 0줄 — 전부 주석·문서)

| 경로 | 변경 |
|---|---|
| `HandlePlacement.swift:44-46` | `Box.delete` — "순서 하나가 정한다" → "제스처가 먼저, 순서는 폴백" **정정** |
| 동 `:122` | `orderedHandles` doc comment 신규 (M2 부채) |
| 동 `:136` | `edges` doc comment 신규 (M2 부채) |
| `context/editor/glossary.md` | 「히트 우선순위」 개정 + 「히트 영역」 보강 + 「후보 목록」 신규 |
| `docs/specs/…v4.md:269` | §5.7 아래 `EDITOR-5` 콜아웃 |

## 상세 설계

### 1-a. 어디에 두는가

**`extension HandlePlacement` + 전용 파일** 채택. 입력이 `HandlePlacement` 하나뿐이라 수신자가 자명하고 `ResizeAnchor.swift:3` 선례가 있다. `EDITOR-6`이 배치를 바꾸면 `orderedHandles`를 통과하므로 자동으로 따라간다.
기각: 자유 함수(`snapCandidates`는 입력이 이질적이라 주인이 없었다) · `HitTester` 타입(상태 0, 수명 질문 중복) · Layout 배치(`LayerKind`·`LayerStore` 입력 0).

### 1-b. 전체 시그니처 (이 블록이 구현 계약이다)

```swift
import Foundation

/// 히트 판정에 필요한 제스처 종류. **이 타입은 제스처를 인식하지 않는다.**
///
/// 탭/드래그를 가르는 임계값·타이머·배타 라우팅은 `EDITOR-10`의 몫이고, 여기
/// 들어오는 값은 **이미 확정된 결과**다. 인식을 이쪽으로 끌어오면 순수 값
/// 계산에 시간이 들어오고, 그 순간 이 패키지는 테스트에서 시계를 붙잡아야 한다.
///
/// 케이스가 둘뿐인 것은 **판정을 실제로 가르는 축이 둘뿐**이기 때문이다.
/// 롱프레스·핀치를 미리 넣지 않는다 — 지금 그것으로 갈리는 판정이 없다.
///
/// `CaseIterable`을 붙이지 않는다 — **전 케이스를 순회할 소비자가 지금 없다.**
/// (이 저장소가 `allCases`를 피한다는 뜻이 아니다. `Corner`·`Edge`는 둘 다
/// `CaseIterable`이고 `Set(Edge.allCases)`가 상시 쓰인다. `edgeOrder`가 명시
/// 상수인 이유는 별개다 — 선언 순서와 **달라야** "allCases를 대신 쓴다"는
/// 변이가 죽기 때문이다.)
public enum HandleGesture: Sendable {
    case tap
    case drag
}

extension HandleGesture {
    /// 이 제스처에서 **최종 후보로 유효한가** (BR-3).
    ///
    /// `.drag`가 `.delete`를 버리는 것이 전부다. 삭제에는 "즉시 삭제"라는 탭
    /// 동작만 정의돼 있고 드래그로 끌 대상이 아니다. 삭제는 좌상단 코너와
    /// **정확히 같은 화면 좌표**(`HandlePlacement.Box.delete`)라, 이 한 줄이
    /// 없으면 좌상단 코너는 영영 리사이즈할 수 없다.
    ///
    /// **`internal`인 이유는 "밖에서 이것만 따로 부를 시나리오가 없어서"다.**
    /// 정책 복제를 막기 위해서가 **아니다** — `hitCandidates`가 `public`이고
    /// `PlacedHandle.handle`·`Handle.delete`도 `public`이라
    /// `candidates.first { $0.handle != .delete }` 한 줄이면 누구나 정책을
    /// 재기술할 수 있다. `internal`은 재사용만 막고 복제는 못 막는다.
    ///
    /// **타입이 보장하는 것**: `hitHandle(at:for:)`가 정책을 적용한 **유일한
    /// 제공자**다. 그것을 부르는 호출부는 BR-3을 자동으로 얻는다.
    /// **타입이 보장하지 않는 것**: 후보 목록을 직접 거르는 것을 막지 못한다.
    /// 그것을 하지 않는 것은 **규율이지 컴파일러가 검사하는 사실이 아니다.**
    func accepts(_ handle: Handle) -> Bool {
        switch self {
        case .tap:  return true
        case .drag: return handle != .delete
        }
    }
}

extension HandlePlacement {

    /// 핸들 하나의 히트 사각형 **한 변**(pt). **화면 좌표축 정렬 정사각형**이다
    /// (v4 §5.7, Apple HIG 최소 터치 타깃).
    ///
    /// **`internal`이다.** 명명된 프로덕션 소비자가 이 파일 밖에 없고, 테스트는
    /// `@testable import`로 닿는다. `public`으로 열면 호출부가
    /// `hitSize / 2 * surface.scale`로 **자기 판정을 짜는 가장 짧은 경로**가
    /// 생기는데, 그것이 정확히 FR-6이 막으려는 것이다. 필요해지면 그때 연다.
    ///
    /// **시각 크기 12pt는 여기 없다.** 그리기는 `EDITOR-11`의 몫이고, 지금
    /// 상수를 세워 두면 소비자 없는 숫자가 된다(`LayoutDocument`가 호출부 없는
    /// 별칭을 지운 선례). 둘이 **다른 값인 것**이 §5.7의 요점이다.
    ///
    /// **반쪽(22)을 별도 상수로 두지 않는다.** 두 벌이 되는 순간 한쪽만 고치는
    /// 변경이 가능해지고, 그때 "44라고 적힌 사각형이 실제로는 40"이 된다.
    static let hitSize: Double = 44

    /// 이 지점에 겹치는 핸들 **전부**를, `orderedHandles`의 순서 그대로 (FR-1).
    ///
    /// **`orderedHandles`의 부분열이다.** 순서를 여기서 다시 정하지 않는다 —
    /// 두 벌이 되면 `EDITOR-6`이 `edgeOrder`를 건드릴 때 그리는 순서와 잡히는
    /// 순서가 갈라진다.
    ///
    /// **제스처 종류를 요구하지 않는다.** 손가락이 막 닿은 순간에는 아직 탭인지
    /// 드래그인지 알 수 없고, 그때도 "이 지점에 무엇이 겹쳐 있는지"는 즉시
    /// 나와야 눌린 핸들을 하이라이트할 수 있다.
    ///
    /// **선택이 없으면 빈 배열이다**(FR-5). `orderedHandles`가 `box == nil`에서
    /// 이미 `[]`를 내므로 분기가 없다.
    ///
    /// **비유한 지점은 자연히 빈 배열이다.** `NaN`은 `<=` 비교가 전부 거짓이라
    /// 어떤 사각형에도 들지 않는다. 판정을 `!(abs(d) > half)`로 뒤집으면 안 되는
    /// 이유이기도 하다 — 그 형태는 `NaN`을 **히트로** 만든다.
    public func hitCandidates(at point: Vec2) -> [PlacedHandle] {
        orderedHandles.filter { Self.isHit(point, near: $0.position) }
    }

    /// 제스처가 확정된 뒤의 최종 하나. **없으면 `nil` = "핸들 아님"** (FR-3·FR-4).
    ///
    /// **반드시 `hitCandidates(at:)`를 거친다.** 독립 구현하면 두 API가 서로 다른
    /// 답을 낼 수 있고, 그때 "하이라이트된 핸들과 실제로 잡힌 핸들이 다른"
    /// 증상이 나온다 — 사용자에게는 앱이 자기가 보여준 것을 배신하는 것으로 보인다.
    ///
    /// **"핸들 아님"을 별도 케이스로 만들지 않는다.** `Optional`이 이미 그 뜻이고,
    /// `box: Box?`·`LayerStore.selection: Entry?`와 같은 표현이다.
    public func hitHandle(at point: Vec2, for gesture: HandleGesture) -> PlacedHandle? {
        hitCandidates(at: point).first { gesture.accepts($0.handle) }
    }

    /// 화면 축 정렬 44×44 사각형 안인가 (FR-2·BR-1·BR-2).
    ///
    /// **두 축을 따로 비교한다 — 유클리드 거리로 바꾸지 않는다.** 거리로 바꾸면
    /// 사각형이 원이 되고 코너의 대각 여유가 √2배 좁아진다((20,20)이 사각형에서는
    /// 히트, 반지름 22 원에서는 28.28로 미스).
    ///
    /// **두 축 모두 `<=`다**(BR-2). x축만 `<=`로 두고 y축을 `<`로 바꾸는 변이는
    /// 픽스처 A의 y축 경계 쌍((270,78) / (270,77.5))에서만 죽는다.
    ///
    /// **`half`는 `surface`·`box`에서 파생하지 않는다.** 상수 하나를 반으로
    /// 나눈 것이 전부이며, 그것이 FR-6의 내용이다.
    private static func isHit(_ point: Vec2, near position: Vec2) -> Bool {
        let half = hitSize / 2
        return abs(point.x - position.x) <= half
            && abs(point.y - position.y) <= half
    }
}
```

**반환 타입**: `[PlacedHandle]` / `PlacedHandle?`. ① 결과가 `orderedHandles`의 **부분열**임이 타입에 드러난다. ② `position`이 함께 와서 M4가 "필터가 원소를 바꿔치지 않았다"를 잰다. ③ 두 API의 원소 타입이 같아 "확정 판정은 후보 중 하나"가 시그니처로 읽힌다.

### 1-g. FR-2·FR-6 — **구조가 아니라 이 네 테스트가 고정한다**

1회차의 "판정 함수가 `CanvasSurface`를 받지 않으므로 구조적으로 보장된다"는 **거짓이다.**

**타입이 보장하는 것**: `HandlePlacement`가 계산에 쓴 `surface`를 들고 있지 않다(`:20-24`). 따라서 `surface.scale`·`surface.zoom`의 **직접 참조**는 불가능하다.

**타입이 보장하지 않는 것 — 여기가 실제 위험이다**: `Box`가 코너 4개를 `public let`으로 공개한다(`:27-30`).
- **회전 복원 가능**: `atan2(topRight.y − topLeft.y, topRight.x − topLeft.x)`로 화면상 레이어 축을 얻어 델타를 역회전하는 로컬 축 정렬 구현이 **공개 시그니처를 한 글자도 안 바꾸고** `hitCandidates` 안에서 작성된다.
- **배율 복원 가능**: `half = 22 · |topRight − topLeft| / 기준폭` 형태의 박스 파생 배율 의존이 가능하다.
- 두 변이는 `EDITOR-6`이 코너를 밀어내며 코너 간 거리를 건드릴 때 **더 그럴듯해진다.**

**따라서 AC-4·11·12·13은 중복이 아니라 유일한 방어선이다.**

| 변이 | 죽이는 AC |
|---|---|
| 로컬 축 정렬(코너에서 회전 복원) | **AC-4 단독** — 회전 0에서는 두 해석이 구별되지 않는다 |
| 박스 파생 배율(400%에서 half 88) | **AC-12 단독** — `dx = 25 < 88`이 히트가 된다 |
| 박스 파생 배율(50%에서 half 11) | **AC-13 단독** — `dx = 20 > 11`이 미스가 된다 |
| 배율 파생인데 100%에서만 맞음 | AC-11(두 배율 동일 단언) |

**`hitSize` 값 변이의 담당은 별개다**(1회차의 "넷 다 죽인다"는 거짓): **축소는 AC-11·13**, **확대는 AC-12**가 죽인다. AC-4는 `hitSize ≥ 60`에서야 반응한다. `hitSize`가 **`[44, 45)`로 확정되는 것은 픽스처 B의 AC-2(≥44)·AC-3(<45)** 덕이다.

### 1-h. 도달 불가 경로 — 무엇이 참이라서 없는가

**FR-3의 "드래그에서 남는 후보가 없어 `nil`"은 현재 도달 불가능하다.** 근거는 "픽스처를 못 만들었다"가 아니라 세 사실이다.

1. `Box.delete`가 `{ topLeft }` **계산 프로퍼티**다(`:46`) — 값이 갈라질 자리가 없다.
2. `Box`의 멤버와이즈 init이 `internal`이라 모듈 밖에서 임의 `Box`를 못 만든다.
3. `HandlePlacement.init(box:)`가 `private`이라(`:62`) `box`를 직접 주입할 수 없다.

⚠️ **`EDITOR-6`이 코너를 밀어내면 1의 전제가 깨진다** — 이 경로는 **도달 가능해지는 동시에 무테스트 상태**가 되고, **그 전이는 어떤 테스트도 실패시키지 않는다.** `EDITOR-6` 설계가 이 문장을 읽고 테스트를 추가해야 한다.

**`dropFirst()` 변이**는 지금도 도달 가능하다. **AC-1을 드래그로도 재는 것이 유일한 방어**다.

### 2. `HandlePlacement.swift` — M2 부채

#### 2-a. `Box.delete` — 틀린 문장의 정정

```swift
/// 결정에 따라 좌상단 코너와 **정확히 같은 지점**이다. 거리로만 고르면 언제나
/// 동점이라, 누가 이기는지는 **제스처가 먼저 정한다** — 탭이면 삭제,
/// 드래그면 좌상단 코너(`HandleGesture.accepts(_:)`). `orderedHandles`의 순서는
/// **제스처로도 갈리지 않을 때의 폴백**이다.
///
/// **저장하지 않고 되짚는다** — 두 벌로 두면 `EDITOR-6`이 코너를 박스 밖으로
/// 밀어내는 순간 삭제만 제자리에 남아, 스펙에 없는 오프셋이 조용히 생긴다.
public var delete: Vec2 { topLeft }
```

#### 2-b. `orderedHandles` — doc comment 신규

```swift
/// **히트 판정과 그리기의 우선순위 순서다.** 딕셔너리로는 표현할 수 없다 —
/// `Dictionary` 순회 순서는 실행마다 다르고, `.delete`와 `.corner(.topLeft)`는
/// **정확히 같은 좌표**라 그 비결정성이 곧바로 관측된다.
///
/// 순서: `.delete` → 코너 4(TL·TR·BR·BL) → `.rotate` → 변(`edgeOrder`).
/// `.delete`가 맨 앞인 것은 오버레이가 ✕를 좌상단 코너 **위에** 그리기 때문이다.
///
/// **이 순서는 "유일한 규칙"이 아니라 폴백이다.** 겹침은 두 단계로 풀린다:
///
/// 1. **제스처가 가른다** — 탭이면 삭제, 드래그면 삭제를 뺀 나머지
///    (`hitHandle(at:for:)`). 삭제와 좌상단 코너의 동일 좌표 충돌은 **여기서만**
///    풀린다. 이 단계를 지우면 좌상단 코너는 영영 리사이즈할 수 없다.
/// 2. **제스처로도 안 갈리는 동점**(초소형 레이어의 인접 코너 등)만 이 순서가 정한다.
///
/// **이 주석의 부재가 실제로 비용을 냈다.** `EDITOR-5` PRD 초안이 코드만 읽고
/// 1단계를 못 봐서 "좌상단 코너는 리사이즈 불가"를 수용한 채 나왔다.
public var orderedHandles: [PlacedHandle] { ... }
```

#### 2-c. `edges` — 존치 + doc comment (근거 정정)

**"유일한 관측면"은 과장이었다.** `SelectionTests.swift:243-249`가 `shape`의 `orderedHandles` 전 시퀀스를 `.edge(...)`까지 리터럴 고정하고 `:207`이 `photo`를 `box.edgeHandles`로 고정한다. `edges`가 유일한 것은 **`text` 한 종류뿐**이다.

```swift
/// 실제로 제공된 변. **`edgeHandles`에서 파생한다 — 두 벌을 만들지 않는다.**
///
/// **2026-08-15 기준 프로덕션 소비자 0건이다.** 그래도 남기는 이유는 둘이다.
///
/// 1. **집합 축의 표현이다.** 좌표·순서를 벗겨낸 `Set<Edge>`라 "종류가 무엇을
///    허용했나"만 잰다. 같은 것을 `orderedHandles` 시퀀스 리터럴이나
///    `box.edgeHandles`로도 잴 수 있으므로 **유일한 관측면은 아니다** —
///    `text`(좌우 2변)에서만 가장 짧은 표현이다.
/// 2. `EDITOR-6` 이후: 크기 축 필터가 `init`에 얹히면 이 값은 **두 축을 모두
///    통과한 최종 집합**이 된다. 그때 `SelectionTests`의
///    `placement.edges == kind.resizableEdges`는 **깨져야 정상**이다.
///
/// 히트 판정은 이것을 쓰지 않는다. 변 핸들은 좌표까지 필요하고 그건
/// `orderedHandles`에 이미 있다.
public var edges: Set<Edge> { ... }
```

## 픽스처 규약 (전 항목 이진 정확, 2회차 검산 완료)

### 기준 표면 — `표면()`

```
CanvasSurface(canvas: Size2(1080, 1350), viewport: Size2(540, 700))
fitScale = 0.5 (정확), scale = 0.5, center = (540, 675), viewport/2 = (270, 350)

toScreen(p).x = p.x / 2              (정확)
toScreen(p).y = p.y / 2 + 12.5       (정확)
```

프레임 규약: 별도 표기 없으면 `size = 200 × 100`, `rotation = 0`, `edges = Set(Edge.allCases)`.

### A — `회전핸들프레임()` : center (540, 281) · AC-1 · M6 · M3

TL/delete **(220,128)** · TR (320,128) · BR (320,178) · BL (220,178) · top mid (270,128) · right mid (320,153) · bottom mid (270,178) · left mid (220,153) · **rotate (270,100)**(topScreen.y=128>40 안 뒤집힘, up=(0,−1))

| 탐침 | 기대 | 죽는 변이 |
|---|---|---|
| **(270,100)** AC-1 | `[.rotate]`, 탭·드래그 **모두** `.rotate` | top mid `dy=28>22` → 반쪽 22→28. 드래그 단언 → **`dropFirst()`** |
| **(270,78)** M6a **[신규]** | `[.rotate]` | rotate `dy=22` **포함**. top mid `dy=50`, 코너 `dx=50` → **y축만 `<`인 변이** |
| **(270,77.5)** M6b **[신규]** | `[]`, `nil` | rotate `dy=22.5>22` → y축 상한 |
| **(.nan,100)**, **(270,.nan)** M3 **[이동]** | `[]`, 두 제스처 `nil` | 반대 축이 rotate와 **0pt**라 `NaN` 축만 판정을 가른다 → `!(abs(d)>half)`. **`empty`로 재면 공허하므로 `box != nil`인 A에서 잰다** |

### B — `경계프레임()` : center (100, 125) · AC-2·3·M1

TL/delete (0,50) · TR (100,50) · **BR (100,100)** · BL (0,100) · top mid (50,50) · **right mid (100,75)** · bottom mid (50,100) · left mid (0,75) · rotate (50,22)

| 탐침 | 기대 | 죽는 변이 |
|---|---|---|
| **(122,100)** AC-2 | `[.corner(.bottomRight)]` | BR `dx=22` 포함. right mid `dy=25>22` 미스 → **`&&`→`‖`**. `hitSize ≥ 44` |
| **(122.5,100)** AC-3 | `[]`, `nil` | `dx=22.5>22` → **x축 `<` vs `<=`**. `hitSize < 45` |
| **(100,75)** M1 | `[.edge(.right)]`, **탭·드래그 모두** `.edge(.right)` | TR·BR `dy=25>22` → **"드래그는 코너만"** + **"탭은 변을 뺀다"** |

### C — `겹침프레임()` : center (500, 425) · AC-5·6·7·9 · M2+M4

**TL/delete (200,200)** · TR (300,200) · BR (300,250) · BL (200,250) · top mid (250,200) · right mid (300,225) · bottom mid (250,250) · **left mid (200,225)** · rotate (250,172)

| 탐침 | 기대 | 죽는 변이 |
|---|---|---|
| **(200,200)** AC-5·6·7 | 후보 `[.delete, .corner(.topLeft)]` 정확히 2개 / 탭→`.delete` / 드래그→`.corner(.topLeft)` | left mid `dy=25>22` → 22→25. **BR-3 제거** |
| **(220,220)** M2**+M4 [통합]** | `[.delete, .corner(.topLeft), .edge(.left)]` **+ 각 `position`이 (200,200)·(200,200)·(200,225)와 `isClose`** | TL max-norm 20≤22 히트 / 유클리드 28.28 미스 → **원·맨해튼**. 세 기대 position이 **전부 탐침과 다르므로** `PlacedHandle(position: point)` 바꿔치기가 죽는다 |
| **(200,400)** AC-9a | `[]`, `nil` | 최근접 BL `dy=150` → **`&&`→`‖`** |
| **(500,200)** AC-9b | `[]`, `nil` | 최근접 TR `dx=200` → 반대 축 |

### D — `초소형프레임()` : center (540,675), size **40×40** · AC-8 · M7

`edges: []` 기준 — TL **(260,340)** · TR **(280,340)** · BR (280,360) · BL (260,360) · delete (260,340) · rotate (270,312). **두 코너 거리 20pt**, 정중앙 **(270,340)**.

| 변형 | 탐침 | 기대 |
|---|---|---|
| `edges: []` — AC-8 | **(270,340)** | 후보 **5개** `[.delete, TL, TR, BR, BL]`(BR·BL은 `dx=10,dy=20`). rotate `dy=28` 미스. 드래그→`.corner(.topLeft)` / 탭→`.delete` |
| `edges: allCases` — **M7 [신규]** | **(270,350)** (박스 화면 중심) | 후보 **9개** `[.delete, TL, TR, BR, BL, .edge(.top), .edge(.right), .edge(.bottom), .edge(.left)]`. rotate `dy=38` 미스. **변 하위 순서(`edgeOrder` 시계방향)를 고정하는 유일한 탐침** |

### E — `회전45프레임()` : center (540,675), size **400×400**, `rotation = .pi/4` · AC-4

TL/delete (270, 208.579) · TR (411.421, 350) · BR (270, 491.421) · BL (128.579, 350) · top mid (340.711, 279.289) · rotate (360.510, 259.490)

**PRD AC-4의 (300,300)/(330,300)을 그대로 쓰지 않은 이유**: TL을 정확히 화면 (300,300)에 놓으려면 `center = (635.355339…, 681.066017…)`이 되어 **픽스처가 이진 정확을 잃는다.** 정사각형 400×400 + 캔버스 중심으로 코너를 축 위에 올리고 탐침을 정변환에서 만든다. **AC-4가 요구하는 성질(45°·화면 x축 30pt·미스)은 그대로 성립한다.**

```swift
let 기준 = surface.toScreen(frame.corner(.topLeft))
let 양성 = Vec2(x: 기준.x + 20, y: 기준.y)     // 대조군
let 탐침 = Vec2(x: 기준.x + 30, y: 기준.y)     // AC-4
```

| 탐침 | 기대 | 근거 |
|---|---|---|
| **기준+(20,0)** = (290, 208.579) — 양성 대조 **[신규]** | `[.delete, .corner(.topLeft)]` 2개 | E를 쓰는 테스트가 AC-4 하나뿐이라 **E 조립 실수로 모든 핸들이 멀어져도 `[]`로 초록**이 된다. **탐침 기준** top mid `dx ≈ 50.7`, rotate `dx ≈ 70.5` (기준 기준으로는 70.7·90.5 — 혼동 주의) |
| **기준+(30,0)** = (300, 208.579) — AC-4 | `[]`, 탭·드래그 모두 `nil` | TL `dx=30>22`, top mid `dx ≈ 40.7`, rotate `dx ≈ 60.5` |

**검산**: 로컬 축 정렬이었다면 (30,0)을 −45° 역회전해 (21.213, −21.213) — 양 성분 22 이내라 **히트**였다. **회전 0에서는 두 해석이 구별되지 않으므로 45°가 필수다.** §1-g의 "코너 `atan2` 회전 복원" 변이를 죽이는 **유일한** 픽스처다.

### F — 줌 3종, **같은 프레임 · 같은 화면 좌표** · AC-11·12·13

프레임: center (540,675), size 200×100, `rotation = 0`, **`edges: []`**

| 표면 | 정의 | scale | TL/delete | TR | BL | rotate |
|---|---|---|---|---|---|---|
| 줌 100% | `표면()` | 0.5 | **(220,325)** | (320,325) | (220,375) | (270,297) |
| 줌 400% | `표면().zoomed(to: 4).centered(on: Vec2(x: 465, y: 637.5))` | 2.0 | **(220,325)** | (620,325) | (220,525) | (420,297) |
| 줌 50% | `표면().zoomed(to: 0.5).centered(on: Vec2(x: 640, y: 725))` | 0.25 | **(220,325)** | (270,325) | (220,350) | (245,297) |

검산: 400% `(440−465)·2+270=220` ✓ `(625−637.5)·2+350=325` ✓ / 50% `(440−640)·0.25+270=220` ✓ `(625−725)·0.25+350=325` ✓ / 두 center 모두 `workArea` 안 ✓ / `zoomed(to:0.5)`는 `zoomLimits.min`과 같아 클램프 없음 ✓

| 탐침 | 표면 | 기대 | 죽는 변이 |
|---|---|---|---|
| **(240,325)** AC-11a | 100% | `[.delete, TL]` | TR `dx=80`, BL `dy=50`, rotate `dx=30` |
| **(240,325)** AC-11b | 400% | 동일 | TR **`dx=380`**, BL `dy=200`, rotate `dx=180` |
| **(245,325)** AC-12 | 400% | `[]`, `nil` | TL `dx=25>22` → **박스 파생 배율(half 88)**, `hitSize` 44→52 |
| **(240,325)** AC-13 | 50% | `[.delete, TL]` | TR `dx=30`·BL `dy=25`·rotate `dy=28` 전부 미스 → **박스 파생 배율(half 11)**, `hitSize` 44→38 |

**`edges: []`인 이유**: 줌 50%에서 레이어가 화면 50×25pt로 줄어 top mid (245,325)가 `dx=5`로 히트해 세 표면의 기대 시퀀스가 갈라진다. **세 케이스 단언을 글자 그대로 같게 유지하는 것이 이 픽스처의 요점**이다.

### G — `화면밖프레임()` : center (540, **−177**), `edges: allCases` · AC-14 **[좌표 개정]**

1회차의 center (540,−175) · 탐침 (270,−22)는 `max(point.y, 0)` 클램프 변이가 **우연히 경계에 정확히 걸려**(클램프 후 `dy = 22 ≤ 22`) 살아남았다. 2pt 옮겨 닫는다.

TL/delete (220,**−101**) · TR (320,−101) · BR (320,−51) · BL (220,−51) · top mid (270,−101) · bottom mid (270,**−51**) · right mid (320,**−76**) · left mid (220,**−76**) · **rotate (270,−23)**
(topScreen.y = −101 ≤ 40 **且** up.y = −1 ≤ 0 → **뒤집힘**. `rotate = bottomScreen − 28·up = (270, −51+28)`)

검산: `−177/2+12.5 = −76`, `−227/2+12.5 = −101`, `−127/2+12.5 = −51` — **전부 이진 정확** ✓

**탐침 (270,−23)** → `[.rotate]`, 탭 → `.rotate`. bottom mid `dy=28` 미스, 코너·좌우 변 `dx=50` 미스.
죽는 변이: **`max(point.y, 0)` 뷰포트 클램프**(클램프 후 `dy=23>22` 미스) + 지점 `abs()`.

### 픽스처 무관 — M5

`HandlePlacement.hitSize == 44` 리터럴(`@testable` 경유). 경계 테스트는 `hitSize/2`가 아니라 **리터럴 22 유도 좌표**를 쓴다.

## AC ↔ 컴포넌트 매핑

| AC | 검증 API | 픽스처 · 탐침 | 죽는 변이 (유일 담당 **굵게**) |
|---|---|---|---|
| AC-1 | `hitCandidates` + `.tap` **+ `.drag`** | A · (270,100) | 반쪽 22→28, **`dropFirst()`** |
| AC-2 | + `.tap` | B · (122,100) | **x축 하한**, `&&`→`‖`, `hitSize ≥ 44` |
| AC-3 | 동 | B · (122.5,100) | **x축 상한**, `hitSize < 45` |
| AC-4 | + 두 제스처 (+ 양성 대조) | E · 기준+(20,0) / +(30,0) | **로컬 축 정렬(코너 `atan2`)** |
| AC-5 | `hitCandidates` (제스처 없이) | C · (200,200) | 22→25, 순서 뒤바뀜 |
| AC-6 | `hitHandle(.tap)` | C · (200,200) | `.tap`도 삭제를 뺌 |
| AC-7 | `hitHandle(.drag)` | C · (200,200) | **BR-3 제거** |
| AC-8 | + `.drag` | D(`edges:[]`) · (270,340) | 코너 순서 재배열, `orderedHandles` 미경유 |
| AC-9 | + 두 제스처 | C · (200,400), (500,200) | `&&`→`‖` (양 축) |
| AC-10 | `empty` | 임의 지점, 두 제스처 | `box == nil` 미처리 |
| AC-11 | 줌 100%/400% | F · (240,325) | `hitSize` 축소, 100%에서만 맞는 배율 파생 |
| AC-12 | 줌 400% | F · (245,325) | **박스 파생 배율(half 88)**, `hitSize` 확대 |
| AC-13 | 줌 50% | F · (240,325) | **박스 파생 배율(half 11)**, `hitSize` 축소 |
| AC-14 | + `.tap` | G · (270,−23) | **뷰포트 클램프 `max(y,0)`**, 지점 `abs()` |

**AC 외 변이 방어 7건**

| # | 픽스처 · 탐침 | 죽이는 것 |
|---|---|---|
| M1 | B · (100,75), **두 제스처** | "드래그는 코너만" + **"탭은 변을 뺀다"** |
| M2+M4 | C · (220,220) — 시퀀스 **+ 각 `position` 대조** | 원·맨해튼 · `position` 바꿔치기 |
| M3 | A · (.nan,100), (270,.nan) | `!(abs(d)>half)` — `NaN`을 히트로 |
| M5 | `hitSize == 44` | 상수 변경 |
| M6 | A · (270,78) / (270,77.5) | **y축 `<` vs `<=`** — 다른 전부가 통과시킨다 |
| M7 | D(`edges:allCases`) · (270,350) — 후보 9개 | **변 하위 순서(`edgeOrder`)** |

**총 테스트 24건.**

## 테스트 가능성

**✅ test-architect TESTABILITY PASS 9/10 — 재설계 불필요.** 순수 값 계산, 강결합·전역·`static` 가변·I/O·시간·시각 의존 **0건**. 시뮬레이터 없이 `swift test`.

- **관측면 4개**: `hitCandidates` / `hitHandle` / `accepts`(`@testable`) / `hitSize`(`@testable`)
- **결정성**: `orderedHandles`가 배열이라 순서 고정 (`Dictionary`를 버린 `EDITOR-4` 결정의 배당금)
- **부동소수**: E(45°) 외 전 좌표 이진 정확. `isClose(abs<0.01)`, `==`는 `[Handle]`·`nil`·`hitSize`에만
- **남은 감점 1점**: §1-h 커버리지 공백. `EDITOR-6`이 코너를 밀어내면 도달 가능해지는데 **그 전이는 어떤 테스트도 실패시키지 않는다.** 지금 닫을 수 없어 `EDITOR-6`에 인계

## 설계 규모

**중형** — 신규 소스 1 · 신규 테스트 1 · 기존 소스 주석 수정 1 · 문서 2. 공개 API 3종 + internal 2종, 새 정책(BR-3), 기존 **틀린 계약 문장 정정**. 시그니처·스키마·의존성 변경 0.

## 구현 순서 (RGR 사이클)

```
1. [Must] HandleHitTest.swift (AC-1~14 + M1~M7, 24건)      (의존: 없음)  ── RGR 1/1
2. [Must] HandlePlacement.swift 주석 3곳                     (의존: 1)
3. [Should] glossary.md + v4 §5.7 콜아웃                     (의존: 1,2)
```

- **단일 RGR 사이클.** red 24건, green 약 60줄, refactor 없음.
- 2가 1의 API 이름을 인용하므로 순서 고정.
- 커밋: 1+2를 `feat: EDITOR-5 — 핸들 히트 판정 (RGR 사이클 1/1)`, 3은 `docs:`로 분리.

### red-writer 필수 인계 3건

1. 픽스처 G는 center **−177** / 탐침 **(270,−23)** — 1회차의 −175/−22가 **아니다**.
2. **M6·M7·양성 대조·M3 이동은 AC 외 추가분이며 생략하면 각 변이가 무방비**다.
3. `hitSize`·`accepts`는 `internal`이라 **`@testable import SoozipGeometry` 필수**.
4. **RED 진입 절차**: 시그니처 스텁(`hitCandidates` → `[]`, `hitHandle` → `nil`, `hitSize = 44`)을 먼저 세워 컴파일을 통과시킨 뒤 실패를 확인한다. 이때 **AC-3·AC-4(음성부)·AC-9·AC-10·AC-12·M3는 스텁에서도 통과**한다 — 정상이며, 양성 대조(AC-4)와 M3의 픽스처 지정이 그 상태를 구제한다.

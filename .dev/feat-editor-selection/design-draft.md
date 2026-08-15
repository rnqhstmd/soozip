# 설계 초안: EDITOR-4 — 선택 상태 + 바운딩 박스

## 배경 및 목적

`EDITOR-1`(표면)·`2`(스토어)·`3`(상한)이 끝나 있고, 지금은 **레이어 하나를 조작 대상으로 지목하는 개념 자체가 없다.** `EDITOR-5`·`6`·`7`·`8`이 전부 이 단위 위에 얹힌다.

두 가지 빚을 함께 갚는다.

1. `LayerFrame.resized(draggingEdge:)`(`ResizeAnchor.swift:63`)가 레이어 타입을 전혀 보지 않아 `photo`도 한 축 리사이즈가 된다.
2. `LayerStore.entries`(`LayerStore.swift:54-58`)와 `move`(`:151`) 주석이 이 단위를 미리 경고해 뒀다 — 낡은 z로 선택 대상을 고르는 문제, 선택된 레이어가 다른 경로로 사라지는 경합.

**이 단위의 핵심은 "네 번째 단일 출처"다.** `CanvasSurface.workArea`(팬 한계=레이어 한계) → `LayerCategory`(분류+상한) → `LayerKind`(값 없는 판별자)에 이어, **"어떤 변 핸들이 존재하는가"를 `LayerKind` 한 곳에 두고 뷰·히트판정·리사이즈가 전부 그것을 읽게 한다.**

## 변경 범위

**영향 모듈**: `SoozipGeometry`, `SoozipLayout` (단방향 의존 유지). `SoozipDraft`·앱 타깃·layoutJSON 스키마 무영향.

**신규 파일**

| 경로 | 내용 |
|---|---|
| `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` | `Handle` 열거형 + `HandlePlacement`(화면 좌표 배치 + 28/40 상수) |
| `Packages/SoozipLayout/Sources/SoozipLayout/SelectionHandles.swift` | `LayerKind.resizableEdges` + `LayerStore.selectionHandles(on:frameOf:)` |
| `Packages/SoozipGeometry/Tests/SoozipGeometryTests/HandlePlacementTests.swift` | AC-9~13 + 극단 입력 |
| `Packages/SoozipLayout/Tests/SoozipLayoutTests/SelectionTests.swift` | AC-1~8, AC-14 |

**수정 파일**

| 경로 | 변경 |
|---|---|
| `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift` | `Edge`를 여기로 이동(+`sign`, `Hashable`, `CaseIterable`), `LayerFrame.edgeMidpoint(_:)` 추가 |
| `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift` | `Edge` 선언 제거(이동), `resized(draggingEdge:)`에 "누가 이 변을 허락하는가" 주석 추가 |
| `Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift` | 선택 상태 3종(`selection`/`select`/`deselect`) + `remove` 정규화 |

## 적용 컨벤션

프로젝트에 `CLAUDE.md`·`conventions.md`가 **없다.** 기존 코드에서 학습한 규칙:

- **네이밍**: 타입 `UpperCamel`, 멤버 `lowerCamel`. 테스트 함수명·픽스처는 **한글 서술문**. 헬퍼는 `private`.
- **구조**: public 타입 전부 `struct`/`enum` + `Sendable`(+ 대부분 `Equatable`). 확장 하나가 파일 하나인 선례가 있다(`ResizeAnchor.swift` = `extension LayerFrame`).
- **에러**: 정책 위반은 던진다(`LayerLimitError`·`DraftStoreError`). **경합 방어는 조용히 무시**(`LayerStore.move:151-157`). 선택은 후자다.
- **주석**: doc comment가 "왜"를 적는다 — **그렇게 하지 않으면 무엇이 깨지는지**.
- **의존성 주입**: 필요해지기 전에 프로토콜로 빼지 않는다(`DraftStore.swift:72-79`). → 프레임 해석은 프로토콜이 아니라 클로저 파라미터.
- **패키지 경계**: 순수 3종은 Foundation만. `Vec2`/`Size2`가 CoreGraphics를 대신한다.

## 상세 설계

### 1. `LayerFrame.swift` — `Edge`를 `Corner` 옆으로 옮기고 `sign`을 붙인다

- **현재**: `Corner`(4종, `sign`, `opposite`)는 `LayerFrame.swift:3-24`, `Edge`(4종, `opposite`, `isHorizontal`)는 `ResizeAnchor.swift:3-17`. `Edge`에는 부호가 없다.
- **변경**: `Edge`를 `LayerFrame.swift`로 옮겨 `Corner` 바로 아래 둔다. **같은 모듈 안의 이동이라 API 변경이 아니다**(호출부 수정 0). `sign`을 추가하고 `Hashable`·`CaseIterable`을 채택한다. 이것이 없으면 다음 사람이 변의 부호를 배치 코드에 다시 적는다 — 코너와 변의 규약이 갈린다.

```swift
public enum Edge: CaseIterable, Hashable, Sendable {
    case left, right, top, bottom
    public var sign: (x: Double, y: Double)   // left(-1,0) right(1,0) top(0,-1) bottom(0,1)
    public var opposite: Edge                 // 기존
    public var isHorizontal: Bool             // 기존
}

extension LayerFrame {
    /// 변의 중점. **`corner(_:)`와 같은 규약으로 계산한다** — 부호만 다르다.
    /// BR-5의 "박스 상단"도 이 함수다(`edgeMidpoint(.top)`): 회전 핸들을 **재는 자리와
    /// 놓는 자리가 갈라지면**, 90° 회전한 레이어에서 판정은 위를 보고 배치는 옆에 붙는다.
    public func edgeMidpoint(_ edge: Edge) -> Vec2
}
```

- **고려사항**: `edgeMidpoint`는 **핸들 제공 여부와 무관하게 4변 전부 계산된다.** `photo`는 상단 변 핸들이 없지만 회전 핸들 기준점(`.top`)과 뒤집힌 위치(`.bottom`)는 필요하다. "존재하는 핸들"과 "박스의 해부학"을 섞으면 사진의 회전 핸들이 사라진다.

### 2. `HandlePlacement.swift` (신규, Geometry) — 화면 좌표 배치 한 덩어리

- **현재**: 없다. `CanvasSurface.toScreen`(`:92`)만 있고, 28pt·40pt를 아는 코드가 없다.
- **변경**: `Handle` 판별자와 배치 결과를 한 값 타입에 담는다. **결과는 화면 좌표(pt)다.** 논리좌표로 내면 28·40을 `scale`로 나눠야 하고(BR-3이 화면 기준이므로), 그 나눗셈은 뷰포트 0(=`GeometryReader` 첫 패스, `CanvasSurfaceTests.swift:57`가 실재 경로임을 증명)에서 `inf`를 만든다. 화면 좌표로 내면 상수가 변환 **뒤에** 붙어 줌 무관성이 계산 구조상 성립한다(AC-13).

```swift
/// 바운딩 박스가 내놓는 조작점. **삭제(✕)도 여기 들어간다** — 뷰가 따로 배치하면
/// "좌상단과 같은 지점"(결정 2)이 두 벌이 되어 한쪽만 인셋되는 순간 어긋난다.
public enum Handle: Hashable, Sendable {
    case corner(Corner)
    case edge(Edge)
    case rotate
    case delete
}

public struct HandlePlacement: Equatable, Sendable {
    /// v4 §5.7. **뷰가 숫자를 다시 적지 않도록 공개한다** — `EDITOR-11`이 28을
    /// 하드코딩하면 여백을 조정할 때 판정(여기)과 그림(뷰)이 갈라진다.
    public static let rotateGap: Double = 28
    public static let flipThreshold: Double = 40

    /// **화면 좌표(pt)다.** 논리좌표가 아닌 이유는 위 주석 참조.
    public let positions: [Handle: Vec2]
    /// 뒤집혔는가. `EDITOR-11`이 연결선을 그릴 때 같은 판정을 다시 하지 않게 함께 낸다.
    public let rotateFlipped: Bool

    /// **선택이 없을 때의 값**(AC-14). `nil` 대신 빈 값을 쓰면 호출부에 분기가 없다.
    public static let empty: HandlePlacement

    public init(frame: LayerFrame, edges: Set<Edge>, on surface: CanvasSurface)

    public subscript(handle: Handle) -> Vec2? { get }
    public var edges: Set<Edge> { get }   // positions 키에서 파생 — 두 벌을 만들지 않는다
    public var isEmpty: Bool { get }
}
```

**`init(frame:edges:on:)`의 계산 순서**

1. 코너 4개: `surface.toScreen(frame.corner(c))` — **`LayerFrame.corner`를 거친다.** 회전 반영 로직을 여기서 다시 쓰면 AC-9의 규약이 두 벌이 된다.
2. 변: `edges`에 있는 것만 `surface.toScreen(frame.edgeMidpoint(e))`. **집합에 없는 변은 키 자체가 없다.**
3. 삭제: `positions[.corner(.topLeft)]`와 **같은 값**. 오프셋을 지어내면 스펙에 없는 숫자가 코드의 SSOT가 된다(결정 2).
4. 회전: `up = (sin r, -cos r)`(로컬 -y를 회전 변환한 단위 벡터, 화면은 균등 배율이라 각도가 보존된다). `flipped = toScreen(frame.edgeMidpoint(.top)).y - toScreen(Vec2(x:0,y:0)).y <= 40`. 뒤집히면 `toScreen(edgeMidpoint(.bottom)) + 28 · (-up)`, 아니면 `toScreen(edgeMidpoint(.top)) + 28 · up`.

**고려사항**

- **판정을 부호 있는 거리로 한다.** 박스가 캔버스 상단보다 **위**에 있으면 값이 음수 → 뒤집힌다. 절댓값을 쓰면 화면 밖으로 나간 레이어의 핸들이 더 위로 올라간다.
- 경계값: "40pt 이내"를 **`<= 40`**(포함)으로 읽는다. `snapCandidates`의 `<= threshold`(`SnapEngine.swift:61`)와 같은 규약이다. 경계 테스트로 고정한다.
- `scale == 0`(뷰포트 0)이어도 `toScreen`이 유한값을 낸다(`CanvasSurface.swift:55-61`의 가드). 28pt 오프셋은 덧셈이라 `NaN`을 만들지 않는다 — **나눗셈이 없는 것이 이 표현을 고른 이유의 절반이다.**
- 저장 프로퍼티용 생성자는 `private`. 외부에서 임의 딕셔너리로 만들면 "삭제=좌상단" 같은 불변식이 우회된다.
- ⚠️ **삭제와 좌상단 코너가 같은 지점이다.** `EDITOR-5`(히트 판정)는 우선순위를 정해야 한다 — 이 사실을 `Handle.delete`의 doc comment에 경고로 남긴다.

### 3. `SelectionHandles.swift` (신규, Layout) — 네 번째 단일 출처

- **현재**: 변 핸들 3분할 규칙이 코드 어디에도 없다. `ResizeAnchor.resized(draggingEdge:)`는 어떤 타입에서든 호출된다.
- **변경**: 규칙을 **`LayerKind`에 붙인다.** `LayerKind.category`(`Layer.swift:156-163`)가 이미 "인스턴스 없이 판정하는 판별자"라는 자리를 만들어 뒀다.

```swift
extension LayerKind {
    /// 이 종류가 내주는 변 핸들 (v4 §5.7).
    ///
    /// **`photo`·`stamp`·`drawing`은 비어 있다** — 한 축으로 늘이면 얼굴이 찌그러지고,
    /// 그건 되돌리는 법을 알기 전까지 사용자가 실수로 인식하지 못하는 훼손이다.
    /// `text`가 좌우뿐인 것은 폭이 줄바꿈 지점이고 높이는 내용이 정하기 때문이다.
    ///
    /// **`resized(draggingEdge:)`는 타입을 보지 않는다.** 이 집합이 그 함수의
    /// 유일한 문지기다. 뷰가 "사진엔 변 핸들 없음"을 다시 적으면 문지기가 두 벌이 된다.
    public var resizableEdges: Set<Edge> {
        switch self {
        case .photo, .stamp, .drawing: return []
        case .text:                    return [.left, .right]
        case .shape:                   return Set(Edge.allCases)
        }
    }
}

extension LayerStore {
    /// 선택된 레이어의 핸들 배치. **선택이 없으면 `.empty`**(AC-14).
    ///
    /// `frameOf`를 주입받는 이유: **모델에 레이어의 기본 크기가 없다.** `PhotoLayer`는
    /// 픽셀 크기를 들지 않고 `TextLayer`는 렌더러가 재야 폭·높이가 나온다. 여기서
    /// 크기를 지어내면 핸들이 그림과 다른 자리에 뜬다. 프로토콜이 아니라 클로저인 것은
    /// `DraftStore`가 정한 관례다 — "정말 필요해지면 그때 프로토콜로 뺀다".
    public func selectionHandles(on surface: CanvasSurface,
                                 frameOf: (Layer) -> LayerFrame) -> HandlePlacement
}
```

**고려사항**

- `frameOf`는 **선택된 레이어에만** 적용된다. 호출부가 프레임을 직접 넘기는 설계를 버린 이유: 선택과 다른 레이어의 프레임을 넘기는 어긋남이 컴파일에 걸리지 않는다.
- `Layer.resizableEdges` 편의 접근자는 **만들지 않는다.** 호출부가 없다 — `LayoutDocument`가 "아무도 안 쓰는 되짚기는 되짚음이 맞는지도 검증되지 않는다"며 별칭을 지운 선례를 따른다.

### 4. `LayerStore.swift` — 선택 상태를 "깨질 수 없는 표현"으로

- **변경**: 선택을 **`UUID` 하나**로 들되, **조회는 반드시 `entries`를 거친다.** z가 인덱스에서 파생되듯, 선택 항목도 저장소에서 파생된다 — 저장소에 없는 id는 `nil`로 풀리므로 **AC-3(삭제 시 자동 해제)이 지켜야 할 규칙이 아니라 성립할 수밖에 없는 성질**이 된다.

```swift
/// 지금 조작 대상인 항목. **저장소에서 매번 되찾는다.**
///
/// id만 들고 조회를 거치지 않으면, 선택된 레이어가 다른 경로로 사라진 뒤에도
/// 유령을 가리킨다 — 속성바가 없는 레이어를 지우거나 앞으로 보낸다.
/// `entries`를 거치므로 **z도 같은 규칙으로 채워진다**(낡은 z를 되돌리지 않는다).
public var selection: Entry? { get }

/// 단일 선택. 이전 선택은 자동으로 밀려난다(AC-1).
/// **저장소에 없는 id는 "선택 없음"이 된다** — `move`와 같은 경합 방어다.
public mutating func select(_ id: UUID)
public mutating func deselect()
```

**구현 메모**

- `private var selectedID: UUID?`. `select`는 `storage`에 있을 때만 저장하고 아니면 `nil`(쓰기 정규화), `remove`는 지운 것이 선택이면 `nil`. **쓰기 정규화와 읽기 파생은 같은 규칙의 두 벌이 아니다** — 정규화는 `Equatable`이 관측 불가능한 상태로 갈라지지 않게 하고, 파생은 정규화를 빠뜨려도 유령이 새지 않게 한다.
- `selection`은 `entries.first { $0.id == selectedID }`로 구현한다. z 채우기를 여기서 다시 쓰면 `entries`와 두 벌이 된다(레이어 43개 상한이라 선형 탐색 비용은 무시 가능).
- **`insert`는 선택을 건드리지 않는다.** 자동 선택은 `TOOL-1`~`3` 몫이며 PRD 제외 범위다.
- z-order 4종은 **한 줄도 바뀌지 않는다.** 선택이 id 기준이라 배열이 재배치돼도 그대로 따라간다(AC-5·BR-1).
- `selectedID` 공개 접근자는 두지 않는다. `selection?.id`로 충분하고, 원시 필드를 노출하면 유령 id가 다시 밖으로 샌다.

### 5. `ResizeAnchor.swift` — 문지기가 누구인지 코드에 적는다

- **변경**: 시그니처는 **그대로 둔다**(실제 리사이즈 동작은 `EDITOR-7`). Geometry는 `LayerKind`를 볼 수 없으므로(단방향 의존) 여기서 타입 기반으로 던지는 것은 **불가능하다.** 대신 doc comment에 문지기를 명시한다.
- **막는 방식은 구조다** — 던지기가 아니라 **존재하지 않음**이다. 드래그 파이프라인에서 `Edge` 값이 만들어지는 유일한 출처는 `HandlePlacement.positions`의 `.edge(_)` 키이고, `photo`의 배치에는 그 키가 아예 없다. **잡을 수 없는 핸들은 끌 수 없다.** 이 사슬이 우연이 아니게 하려고 Layout 테스트가 `placement.edges == kind.resizableEdges`를 5종 전부에 대해 고정한다.

## 의존성 및 영향도

- **새 외부 의존성 없음.** Foundation만 쓴다. CoreGraphics·SwiftUI·UIKit 미사용 — Windows 빌드 유지.
- **패키지 의존 방향 불변**: Layout → Geometry. 3분할 규칙은 **Layout 쪽에서** `Edge`를 소비하는 형태로만 성립한다.
- **기존 코드 영향**
  - `LayerStore`에 저장 프로퍼티가 하나 늘어 **`Equatable` 의미가 바뀐다** (확인 질문 2).
  - `Edge`에 `Hashable`·`CaseIterable` 추가 = 순수 추가, 기존 호출부 무영향.
  - `Edge` 파일 이동 = 같은 모듈 내 이동, 컴파일 영향 없음.
  - 기존 319개 테스트에 깨질 것이 없다(`ResizeAnchorTests`는 `.right` 리터럴만 쓴다).
- **하위 호환성**: layoutJSON 스키마 변경 **없음.** 선택은 편집 세션 안에서만 살고 영속화되지 않는다.

## AC ↔ 컴포넌트 매핑

| AC | 검증 대상 API | 테스트 파일 |
|---|---|---|
| AC-1 | `LayerStore.select` → `selection?.id` | `SelectionTests` |
| AC-2 | `LayerStore.deselect` → `selection == nil` | `SelectionTests` |
| AC-3 | `remove` + `selection` 파생 조회 | `SelectionTests` |
| AC-4 | `remove` + `selection` | `SelectionTests` |
| AC-5 | `bringToFront` + `selection?.id` | `SelectionTests` |
| AC-6 | `LayerKind.resizableEdges` + `selectionHandles(...).positions` | `SelectionTests` |
| AC-7 | `HandlePlacement.edges` | `SelectionTests` |
| AC-8 | `HandlePlacement.edges` | `SelectionTests` |
| AC-9 | `LayerFrame.corner` ← `surface.toLogical(placement[.corner(.topLeft)])` | `HandlePlacementTests` |
| AC-10 | `LayerFrame.edgeMidpoint(.left)` ← 같은 왕복 | `HandlePlacementTests` |
| AC-11 | `placement[.rotate].y == topScreen.y - 28` | `HandlePlacementTests` |
| AC-12 | `placement[.rotate].y == bottomScreen.y + 28`, `rotateFlipped` | `HandlePlacementTests` |
| AC-13 | `rotateFlipped` 두 배율 비교 | `HandlePlacementTests` |
| AC-14 | `selectionHandles(...) == .empty`, `positions.isEmpty` | `SelectionTests` |

## 테스트 가능성

- **전부 순수 값 타입 + 순수 함수다.** I/O·시각·난수·전역 상태 없음. `HandlePlacement`는 입력 3개(`frame`·`edges`·`surface`)만으로 결정된다.
- **주입점 2개**: `CanvasSurface`(줌·뷰포트를 테스트가 자유롭게 만든다 — AC-13이 이것으로 성립), `frameOf` 클로저(모델에 없는 기본 크기를 테스트가 스텁으로 준다).
- **AC 값이 이미 구체값**이라 단언에 해석이 끼지 않는다.

**변이 저항 포인트**

- AC-11·12는 **리터럴 28**로 단언한다. `HandlePlacement.rotateGap`으로 단언하면 상수를 3으로 바꿔도 초록인 항등식이 된다. 상수 자체는 "스펙 숫자와 같은가" 테스트 하나로 따로 고정한다.
- AC-13은 **두 배율에서 같은 판정**을 확인해야 한다. 한 배율만 재면 논리좌표로 40을 비교하는 구현도 통과한다.
- AC-6은 `edges.isEmpty`만이 아니라 **`positions`에 `.edge(_)` 키가 하나도 없음**을 본다.
- 5종 전부에 대해 `placement.edges == kind.resizableEdges`를 고정한다.
- `positions[.delete] == positions[.corner(.topLeft)]`를 **값 동일성**으로 고정한다.
- 뷰포트 0·회전 π/2·경계값 40 정확히 — `CanvasSurfaceTests`의 극단 입력 관례를 따른다.
- 선택 테스트 픽스처는 **5종을 전부 담는다**(`LayerStoreTests`의 `다섯종()` 선례).

## 구현 순서 (RGR 사이클)

```
1. [Must] LayerStore 선택 상태 (AC-1~5)                 (의존: 없음)  ── RGR 1/2
2. [Must] Edge.sign + edgeMidpoint + HandlePlacement    (의존: 없음)  ┐
   (AC-9~13)                                                          ├─ RGR 2/2
3. [Must] LayerKind.resizableEdges + selectionHandles    (의존: 1, 2) ┘
   (AC-6~8, 14)
```

- **1과 2는 다른 패키지의 다른 파일이라 병렬 가능하다.**
- 3은 두 결과를 잇는 얇은 다리다.
- 검증은 `./scripts/test.sh` (SPM 3종 + 앱 타깃 + Release 빌드).

## 설계 규모

**중형**

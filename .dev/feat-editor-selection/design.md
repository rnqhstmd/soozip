# 설계서: EDITOR-4 — 선택 상태 + 바운딩 박스

- 작성일: 2026-08-15 (2회차 — design-critic MUST-ADDRESS 4건 반영)
- PRD: `.dev/feat-editor-selection/prd.md`
- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §5.7 · §5.9 · §5.11
- 기준 커밋: `1e93a18` (워킹트리 clean, `.dev/` 산출물 제외)

## 배경 및 목적

`EDITOR-1`(표면)·`2`(스토어)·`3`(상한)이 끝나 있고, 지금은 **레이어 하나를 조작 대상으로 지목하는 개념 자체가 없다.** `EDITOR-5`·`6`·`7`·`8`이 전부 이 단위 위에 얹힌다.

두 가지 빚을 함께 갚는다.

1. `LayerFrame.resized(draggingEdge:)`(`ResizeAnchor.swift:63`)가 레이어 타입을 전혀 보지 않아 `photo`도 한 축 리사이즈가 된다.
2. `LayerStore.entries`(`LayerStore.swift:54-58`)와 `move`(`:151-152`) 주석이 이 단위를 미리 경고해 뒀다 — 낡은 z로 선택 대상을 고르는 문제, 선택된 레이어가 다른 경로로 사라지는 경합.

### 1회차의 "네 번째 단일 출처"라는 자기규정을 취소한다

검증 결과 이 단위가 세우려던 출처 중 **실제로 새 것은 하나뿐**이다.

| 무엇 | 이미 있는 출처 | 이 단위가 하는 일 |
|---|---|---|
| 중심·회전 | `LayerTransform.x/y/rotation` (`Layer.swift:37-40`) | **경유만 한다** |
| scale 곱 → 프레임 | `LayerTransform.frame(baseSize:)` (`Layer.swift:57-63`) | **경유만 한다** |
| `shape`의 기본 크기 | `ShapeLayer.width/height` (`Layer.swift:102-103`) | **경유만 한다** |
| `photo`·`text`·`stamp`·`drawing`의 기본 크기 | **없다** | 주입받는다 (이것만) |
| 종류별 변 핸들 규칙 | 없다 | **`LayerKind.resizableEdges`로 새로 세운다** |

1회차는 `frameOf: (Layer) -> LayerFrame`으로 **네 칸 전부를 클로저 뒤로 밀어넣어**, 이미 있는 세 출처를 우회하는 네 번째 중복을 만들고 있었다. 진짜 결손은 `Size2` 하나다.

## 요구사항 (PRD 인용)

2회차에서 바뀐 것은 **FR-9 · BR-2 · BR-3 · AC-11 · AC-12 · AC-13**이다.

- [Must] FR-1~4: 단일 선택 / 해제 / 삭제 시 자동 해제 / z-order 변경에도 유지
- [Must] FR-5: `photo`·`stamp`·`drawing` 변 0 · `shape` 변 4 · `text` 변 2(좌우)
- [Must] FR-6·7: 코너 4 · 변 중점 배치에 **회전 반영**
- [Must] FR-8: 회전 핸들 = 박스 상단 중심에서 화면 **28pt**, 회전 방향 반영
- [Must] **FR-9 (개정)**: 박스 상단의 화면 좌표가 **뷰포트 상단(화면 y = 0)** 으로부터 40pt 이내이면 박스 하단에서 28pt 아래로 뒤집는다 (결정 4)
- [Must] FR-10: 삭제 = **좌상단 코너와 동일 지점** (결정 2)
- [Must] BR-1: 선택은 **레이어 자체**를 가리킨다 (순번 아님)
- [Must] **BR-2 (개정)**: **종류 축에서만** 변 핸들이 종류로 결정된다. 크기 축은 `EDITOR-6`의 몫 (결정 5)
- [Must] **BR-3 (개정)**: 40pt 임계는 **뷰포트 상단 기준 화면 좌표**, 줌 50~400% 무관
- [Must] BR-4: 박스는 회전값을 그대로 반영
- [Must] BR-5: 뒤집기 기준점 = **로컬 상단 중앙을 회전 변환한 지점** (결정 3)
- [Should] QE-1: 어느 줌에서든 뒤집히는 시점이 동일한 시각적 여백으로 느껴진다

## 변경 범위

**영향 모듈**: `SoozipGeometry`, `SoozipLayout` (단방향 의존 유지). `SoozipDraft`·앱 타깃·layoutJSON 스키마 무영향.

**신규 파일**

| 경로 | 내용 |
|---|---|
| `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` | `Handle`·`PlacedHandle`·`PlacedEdge` + `HandlePlacement`(화면 좌표 배치 · 28/40 상수 · 유한성 가드 · 우선순위 순서) |
| `Packages/SoozipLayout/Sources/SoozipLayout/SelectionHandles.swift` | `LayerKind.resizableEdges` + `LayerStore.selectionHandles(on:baseSizeOf:)` |
| `Packages/SoozipGeometry/Tests/SoozipGeometryTests/HandlePlacementTests.swift` | AC-9~13 + 순서 + 극단 입력 |
| `Packages/SoozipLayout/Tests/SoozipLayoutTests/SelectionTests.swift` | AC-1~8, AC-14 |

**수정 파일**

| 경로 | 변경 |
|---|---|
| `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift` | `Edge`를 여기로 이동(+`sign`, `Hashable`, `CaseIterable`), `edgeMidpoint(_:)` 추가 |
| `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift` | `Edge` 선언 제거(이동), 문지기 주석을 **실제 보장 수준으로** 다시 씀 |
| `Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift` | 선택 상태 3종 + `remove` 정규화 + `Equatable` 경고 주석 |
| `Packages/SoozipLayout/Sources/SoozipLayout/Layer.swift` | **`Layer.baseSize: Size2?` 추가** |

> 2회차 초안에 "작업 트리에 미커밋 변경이 있다"는 경고가 있었으나 **사실이 아니다.** EDITOR-3 후속(`LayerKind` 도입)은 `1e93a18`로 이미 병합됐고 워킹트리는 clean이다(`.dev/` 산출물 제외). 위 라인 번호는 `1e93a18` 기준이다.

## 적용 컨벤션

프로젝트에 `CLAUDE.md`·`conventions.md`가 **없다.** 기존 코드에서 학습한 규칙:

- **네이밍**: 타입 `UpperCamel`, 멤버 `lowerCamel`. 테스트 함수명·픽스처는 **한글 서술문**(`LayerStoreTests.swift:44` `다섯종()`, `LayerLimitTests.swift` `사진()`/`펜()`/…). 헬퍼는 `private`.
- **구조**: public 타입 전부 `struct`/`enum` + `Sendable`(+ 대부분 `Equatable`). 확장 하나가 파일 하나인 선례(`ResizeAnchor.swift` = `extension LayerFrame`).
- **에러**: 정책 위반은 던진다(`LayerLimitError`·`DraftStoreError`). **경합 방어는 조용히 무시**(`LayerStore.move:151-157`). 선택은 후자다.
- **비유한 입력**: 유한성 가드를 **값 타입 자기 경계에서** 든다 — `CanvasSurface.fitScale:55-60`, `zoomed:114`, `centered:122` + 대응 테스트(`CanvasSurfaceTests.swift:55-78`).
- **명시 순서**: `allCases`(선언 순서)에 **기대지 않는다** — `LayoutDocument.reportingOrder`가 "케이스 재배열이 사용자에게 보이는 결과를 바꾼다"는 이유로 명시 상수를 든다.
- **주석**: doc comment가 "왜"를 적는다 — **그렇게 하지 않으면 무엇이 깨지는지**.
- **의존성 주입**: 필요해지기 전에 프로토콜로 빼지 않는다(`DraftStore.swift:72-79`). → 클로저 파라미터.
- **죽은 API를 남기지 않는다**: `LayoutDocument.swift:99-102`가 호출부 없는 별칭을 지운 선례.
- **부동소수 단언**: `private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }` — 기하 테스트 3종 전부가 쓴다. `Double ==` 선례 0건.
- **패키지 경계**: 순수 3종은 Foundation만. `Vec2`/`Size2`가 CoreGraphics를 대신한다.

## 상세 설계

### 1. `LayerFrame.swift` — `Edge`를 `Corner` 옆으로 옮기고 `sign`을 붙인다

```swift
public enum Edge: CaseIterable, Hashable, Sendable {
    case left, right, top, bottom

    /// 중심 기준 로컬 좌표의 부호. **`Corner.sign`과 같은 규약이다** — 이것이
    /// 없으면 다음 사람이 변의 부호를 배치 코드에 다시 적고, 코너와 변이 다른
    /// 규약으로 갈라진 채 90° 회전에서만 어긋난다.
    public var sign: (x: Double, y: Double)   // left(-1,0) right(1,0) top(0,-1) bottom(0,1)
    public var opposite: Edge                 // 기존
    public var isHorizontal: Bool             // 기존
}

extension LayerFrame {
    /// 변의 중점. **`corner(_:)`와 같은 규약으로 계산한다** — 부호만 다르다.
    /// BR-5의 "박스 상단"도 이 함수다(`edgeMidpoint(.top)`): 회전 핸들을 **재는
    /// 자리와 놓는 자리가 갈라지면**, 90° 회전한 레이어에서 판정은 위를 보고
    /// 배치는 옆에 붙는다.
    public func edgeMidpoint(_ edge: Edge) -> Vec2
}
```

- `edgeMidpoint`는 **핸들 제공 여부와 무관하게 4변 전부 계산된다.** `photo`는 상단 변 핸들이 없지만 회전 핸들 기준점(`.top`)과 뒤집힌 위치(`.bottom`)는 필요하다. "존재하는 핸들"과 "박스의 해부학"을 섞으면 사진의 회전 핸들이 사라진다.
- 같은 모듈 안의 이동이라 **API 변경이 아니다**(호출부 수정 0). `Hashable`은 `Set<Edge>` 때문에, `CaseIterable`은 `.shape`의 "네 변 전부"를 적기 위해 필요하다.

### 2. `HandlePlacement.swift` (신규, Geometry)

#### 2-a. 화면 좌표를 고르는 근거

1회차가 든 근거("논리좌표면 28·40을 `scale`로 나눠야 하고 뷰포트 0에서 `inf`")는 **이 저장소에서 이미 반증돼 있다** — `Soozip/Spikes/S1_GestureProbe.swift:87`이 `threshold: 8 / Double(scale)`로 정확히 그 나눗셈을 하고, `SnapEngine.swift:45-46`이 그것을 정상 규약으로 문서화한다. 근거를 갈아 끼운다.

- **v4 §5.9** (`:345`): "줌 상태에서도 핸들의 화면상 크기는 일정하다 — 핸들은 논리좌표가 아니라 **화면 오버레이 레이어**에 그린다."
- **`context/editor/architecture.md:10,15`**: `SelectionOverlay`는 `★ 화면 좌표계`에 산다.

**소비자가 화면 좌표계에 산다.** 논리좌표로 내면 `EDITOR-11`이 모든 점에서 `toScreen`을 다시 부르고 28pt는 미리 나눠 둬야 한다 — **같은 오프셋이 두 표현으로 존재하게 된다.** 화면 좌표로 내면 상수가 변환 **뒤에** 붙어 줌 무관성이 계산 구조상 성립한다. (부수적으로 나눗셈이 없어지지만 그건 **결과이지 이유가 아니다.**)

#### 2-b. 수명과 무효화

```swift
/// 선택 오버레이가 그릴 조작점 전부. **화면 좌표(pt)다.**
///
/// **이 값은 `surface`가 바뀌는 순간 통째로 무효다.** 뷰포트·줌·팬 중 **하나만**
/// 달라져도 모든 좌표가 낡는다. 저장하지 말고 **매 프레임 다시 만든다.**
///
/// `EDITOR-5`가 제스처 시작 시점의 배치를 잡아 두고 팬 중에 쓰는 구현은 자연스럽게
/// 나오는데, 그러면 손가락은 새 화면 좌표에 있고 핸들은 옛 자리에 있어 **히트 판정이
/// 조용히 빗나간다** — 크래시도 로그도 없이 "가끔 안 잡히는" 버그가 된다.
/// 레이어 상한이 43개고 핸들이 10개 남짓이라 재계산은 산술 몇 줄이다. 아낄 것이 없다.
///
/// **계산에 쓴 `surface`를 일부러 들고 있지 않는다.** 들고 있으면 `isStale(for:)`
/// 같은 API가 따라 생기고, 그건 **보관을 정당화한다.**
```

#### 2-c. 표현 — 딕셔너리를 버린다

1회차의 `positions: [Handle: Vec2]`는 두 가지를 못 한다.

1. **순서를 표현하지 못한다.** `Dictionary` 순회 순서는 실행마다 다르다. 결정 2로 `.delete`와 `.corner(.topLeft)`는 **정확히 같은 좌표**를 갖는데, `EDITOR-5`가 거리 스캔으로 히트를 고르면 동점에서 매번 다른 핸들이 이긴다. 이 저장소는 같은 부류를 이미 지불했다 — `LayerStore.init:69-72`의 "Swift `sorted(by:)`는 안정성을 보장하지 않아 같은 파일이 열 때마다 다르게 보인다".
2. **"선택이 있으면 코너는 반드시 넷"을 표현하지 못한다.** `subscript -> Vec2?`는 분기를 없애는 게 아니라 `if let placement` 하나를 열 개 남짓으로 늘린다.

```swift
public enum Handle: Hashable, Sendable {
    case corner(Corner)
    case edge(Edge)
    case rotate
    /// 결정 2로 **좌상단 코너와 정확히 같은 지점**에 있다. `EDITOR-5`가 거리로만
    /// 고르면 동점이 나므로, 누가 이기는지는 `HandlePlacement.orderedHandles`의
    /// **순서 하나**가 정한다. 그 순서를 다른 곳에서 다시 정의하지 마라.
    case delete
}

public struct PlacedHandle: Equatable, Sendable {
    public let handle: Handle
    public let position: Vec2
}

public struct PlacedEdge: Equatable, Sendable {
    public let edge: Edge
    public let position: Vec2
}

public struct HandlePlacement: Equatable, Sendable {

    /// 선택이 있을 때의 배치. **`box == nil`이 "선택 없음"의 유일한 표현이다**(AC-14).
    /// 코너를 각각 옵셔널로 두면 "셋만 있는 박스"가 타입상 표현 가능해지고,
    /// 그리는 쪽에 옵셔널 분기가 넷 생긴다.
    public struct Box: Equatable, Sendable {
        public let topLeft: Vec2
        public let topRight: Vec2
        public let bottomRight: Vec2
        public let bottomLeft: Vec2

        /// 이 종류가 허용한 변만. **순서는 `HandlePlacement.edgeOrder`로 고정한다.**
        public let edgeHandles: [PlacedEdge]

        public let rotate: Vec2
        /// 뒤집혔는가. `EDITOR-11`이 연결선을 그릴 때 같은 판정을 다시 하지 않게 함께 낸다.
        public let rotateFlipped: Bool

        /// `LayerFrame.corner(_:)`의 화면 좌표 쌍둥이. 같은 이름·같은 규약이다.
        public func corner(_ corner: Corner) -> Vec2

        /// 결정 2: 좌상단 코너와 **같은 지점**이다. **저장하지 않고 되짚는다** —
        /// 두 벌로 두면 `EDITOR-6`이 코너를 박스 밖으로 밀어내는 순간 삭제만
        /// 제자리에 남아, 스펙에 없는 오프셋이 조용히 생긴다.
        public var delete: Vec2 { topLeft }
    }

    /// v4 §5.7. **뷰가 숫자를 다시 적지 않도록 공개한다** — `EDITOR-11`이 28을
    /// 하드코딩하면 여백을 조정할 때 판정(여기)과 그림(뷰)이 갈라진다.
    public static let rotateGap: Double = 28
    public static let flipThreshold: Double = 40

    /// 변 핸들을 늘어놓는 순서. **`Edge.allCases`에 기대지 않는다** —
    /// `LayerCategory.reportingOrder`가 같은 이유로 명시 상수를 든다: 케이스를
    /// 재배열하는 무해해 보이는 리팩터가 히트 우선순위를 조용히 바꾼다.
    ///
    /// **시계방향인 것이 이 불변식을 검증 가능하게 만든다.** `Edge`의 선언 순서는
    /// `left, right, top, bottom`이므로, 이 상수를 선언 순서대로 적으면
    /// `Edge.allCases`와 **완전히 같아져** "`allCases`를 대신 쓴다"는 변이가
    /// 어떤 테스트로도 죽지 않는다 — 불변식을 적어 놓고 지켜지는지는 못 재는 상태가 된다.
    /// 시계방향은 히트 우선순위로도 자연스럽고, 두 배열이 달라야 트립와이어가 산다.
    public static let edgeOrder: [Edge] = [.top, .right, .bottom, .left]

    public let box: Box?
    public static let empty = HandlePlacement(box: nil)   // private init(box:)

    public init(frame: LayerFrame, edges: Set<Edge>, on surface: CanvasSurface)

    /// **히트 판정과 그리기의 우선순위 순서다.** 딕셔너리는 이 순서를 표현할 수 없다.
    ///
    /// 순서: `.delete` → 코너 4(TL·TR·BR·BL) → `.rotate` → 변(`edgeOrder`).
    /// `.delete`가 앞인 것은 오버레이가 ✕를 코너 위에 그리기 때문이다 —
    /// **보이는 것이 잡히는 것과 같아야 한다.**
    ///
    /// 이 순서가 정하는 것은 **동점일 때 누가 이기는가**뿐이다. 탭(삭제)과
    /// 드래그(리사이즈)를 제스처 종류로 가르는 것은 `EDITOR-5`의 몫이고, 그
    /// 판단이 서면 이 순서는 폴백이 된다. 하지만 순서가 **없으면** 그 폴백이
    /// 실행마다 달라진다.
    public var orderedHandles: [PlacedHandle] { get }

    /// 실제로 제공된 변. `edgeHandles`에서 파생한다 — 두 벌을 만들지 않는다.
    public var edges: Set<Edge> { get }
}
```

**버린 것**: `subscript(Handle) -> Vec2?`와 `isEmpty`. 전자는 `orderedHandles`가 이미 좌표를 들고 다녀 실호출부가 없고, 후자는 `box == nil`과 같은 질문의 두 번째 표현이다.

#### 2-d. `init(frame:edges:on:)`의 계산 순서

0. **유한성 가드** (2-e). 통과 못 하면 `box = nil`.
1. 코너 4개: `surface.toScreen(frame.corner(c))` — **`LayerFrame.corner`를 거친다.** 회전 반영을 여기서 다시 쓰면 AC-9의 규약이 두 벌이 된다.
2. 변: `Self.edgeOrder.filter(edges.contains)` 순서로 `surface.toScreen(frame.edgeMidpoint(e))`. **집합에 없는 변은 원소 자체가 없다.**
3. 회전 방향: `up = Vec2(x: sin(r), y: -cos(r))` — 로컬 −y를 `LayerFrame.toWorld`와 **같은 행렬로** 회전한 단위 벡터다. `toScreen`은 x·y에 **같은 배율**을 쓰고 축을 뒤집지 않으므로(`CanvasSurface.swift:92-95`) 화면에서도 각도가 보존된다.
   - **정규화로 방향을 구하지 않는다.** `toScreen(top) − toScreen(center)`를 정규화하는 구현은 높이 0인 프레임에서 0으로 나눈다. 각도에서 직접 만들면 그 자리가 없다.
4. 뒤집기 판정: `rotateFlipped = surface.toScreen(frame.edgeMidpoint(.top)).y <= Self.flipThreshold`
5. 회전 위치: 뒤집혔으면 `toScreen(edgeMidpoint(.bottom)) − 28·up`, 아니면 `toScreen(edgeMidpoint(.top)) + 28·up`.

```swift
/// 기준선은 **뷰포트 상단(화면 y = 0)** 이다. v4 §5.7의 문면은 "캔버스 상단"이지만
/// 그 목적은 "위에 그리면 화면 밖이거나 툴바에 가린다"이고, **줌+팬에서 둘이 갈라진다.**
///
/// 실측: 뷰포트 390×844 · `post`(1080×1350)면 `fitScale ≈ 0.3611`. 줌 400%에서
/// 캔버스 하단을 보려고 `center.y = 1200`으로 팬하면 캔버스 상단의 화면 y ≈ −1311이다.
/// 이때 툴바 바로 아래(화면 y = 20)의 레이어는 캔버스 상단 기준 판정값이 1331 > 40이라
/// **뒤집히지 않고, 회전 핸들이 화면 y = −8 — 화면 밖에 놓인다.** 문면 대신 목적을 택했다.
///
/// **여기서 `scale`이 사라진 것처럼 보이지만 `toScreen`이 안에 들고 있다.**
/// 그래서 "논리좌표로 40을 비교"하는 변이는 여전히 죽는다 — 같은 화면 거리를 만드는
/// 논리 y가 줌 100%와 400%에서 서로 다르기 때문이다(AC-13이 정확히 그 둘을 잰다).
///
/// **부호 있는 거리로 판정한다.** 박스가 뷰포트 위로 나가면 y가 음수라 뒤집힌다.
/// 절댓값을 쓰면 화면 위로 벗어난 레이어의 회전 핸들이 더 위로 올라간다.
```

- 경계값: "40pt 이내"를 **`<= 40`**(포함)으로 읽는다. `snapCandidates`의 `<= threshold`(`SnapEngine.swift:61`)와 같은 규약이다.

#### 2-e. 비정상 입력의 계약 — 가드를 든다

`baseSizeOf`가 `EDITOR-11`에서 텍스트 렌더러 실측을 받고, 측정 실패 시 `NaN`·`inf`가 들어올 수 있다. `rotation`이 `NaN`이면 `sin`/`cos`가 `NaN`을 흘려 **모든 좌표가 `NaN`이 되고, `NaN <= 40`은 거짓이라 뒤집기조차 안 된다.**

**결정: `HandlePlacement.init`이 유한성 가드를 든다.** `CanvasSurface`가 세 곳에 같은 가드 + 극단 입력 테스트를 둔 전례를 따른다.

```swift
/// **비유한 프레임은 `box == nil`이 된다.** `NaN` 좌표를 낸 핸들은 화면에
/// 그려지지도, 잡히지도 않으면서 **있는 것처럼 값만 존재한다** — 그리는 쪽과
/// 잡는 쪽 어느 한쪽도 그것을 알아채지 못한다. 아예 없는 편이 낫다.
///
/// **크기 0·음수는 막지 않는다.** 유한하고, 좌표가 한 점으로 모이거나 좌우가
/// 뒤집힐 뿐이다. 작은 레이어를 다루는 것은 **크기 축(`EDITOR-6`)의 몫**이고,
/// 여기서 겸하면 두 축의 문지기가 다시 섞인다(결정 5가 갈라 놓은 것이다).
```

가드 대상: `frame.center.x/y`, `frame.size.width/height`, `frame.rotation`. `surface`는 **가드하지 않는다** — `CanvasSurface`가 자기 입력을 이미 막고 있어 두 벌이 된다. 뷰포트 0이면 모든 핸들이 한 점으로 모이지만 **전부 유한하다.**

### 3. `SelectionHandles.swift` (신규, Layout) — 주입 최소 단위는 `Size2` 하나다

```swift
extension Layer {
    /// 모델이 **스스로 아는** 기본 크기. `shape`만 안다(`ShapeLayer.width/height`).
    ///
    /// `nil`인 넷은 크기가 모델 밖에 있다 — `photo`는 픽셀 크기를 들지 않고,
    /// `text`는 렌더러가 재야 폭·높이가 나오며, `stamp`·`drawing`은 구운 이미지가
    /// 정한다. **그 넷만 주입받는다.**
    ///
    /// `shape`가 이 경로로 빠지는 것이 중요하다 — 주입 클로저가 `shape`에 대해
    /// 틀린 값을 내도 도형은 영향받지 않는다. **모델이 아는 것을 밖에 묻지 않는다.**
    public var baseSize: Size2? {
        switch self {
        case .shape(let l): return Size2(width: l.width, height: l.height)
        case .photo, .text, .stamp, .drawing: return nil
        }
    }
}

extension LayerKind {
    /// 이 **종류**가 원칙적으로 허용하는 변 (v4 §5.7).
    ///
    /// `photo`·`stamp`·`drawing`은 비어 있다 — 한 축으로 늘이면 얼굴이 찌그러지고,
    /// 그건 되돌리는 법을 알기 전까지 사용자가 실수로 인식하지 못하는 훼손이다.
    /// `text`가 좌우뿐인 것은 폭이 줄바꿈 지점이고 높이는 내용이 정하기 때문이다.
    ///
    /// **종류 축의 문지기이지 핸들 존재의 전부가 아니다(결정 5).** `EDITOR-6`이
    /// 화면 짧은 변 88pt 미만에서 변 핸들을 걷어내고 56pt 미만에서 코너를 박스
    /// 밖으로 미는 **크기 축 필터**를 `HandlePlacement.init` 안에 얹는다.
    /// "유일한 문지기"라고 적으면 그 시점에 이 주석이 거짓이 되고, 다음 사람은
    /// 크기 필터를 찾지 못한 채 이 집합만 고친다.
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
    /// `baseSizeOf`가 받는 것은 **`Layer.baseSize`가 `nil`인 넷뿐이다.**
    /// 중심·회전은 `LayerTransform.x/y/rotation`에서, scale 곱은
    /// `LayerTransform.frame(baseSize:)`에서 나온다 — **이 함수는 그 셋을 새로
    /// 만들지 않고 경유만 한다.** 프레임 전체를 주입받으면 호출부가 중심·회전을
    /// 조용히 덮어쓸 수 있고, 그때 핸들은 그림과 다른 자리에 뜬다.
    ///
    /// - Parameter baseSizeOf: 측정에 실패하면 **비유한 값을 그대로 내도 된다.**
    ///   `HandlePlacement`가 유한성을 가드하고 `.empty`를 낸다.
    public func selectionHandles(on surface: CanvasSurface,
                                 baseSizeOf: (Layer) -> Size2) -> HandlePlacement
}
```

**구현 골자**

```swift
guard let entry = selection else { return .empty }
let frame = entry.layer.transform.frame(baseSize: entry.layer.baseSize ?? baseSizeOf(entry.layer))
return HandlePlacement(frame: frame, edges: entry.layer.kind.resizableEdges, on: surface)
```

- `Layer.resizableEdges` 편의 접근자는 **만들지 않는다** — 위 한 줄이 `kind`를 거치면 충분하고, `LayoutDocument.swift:99-102` 선례가 호출부 없는 되짚기를 금한다.
- `Layer.baseSize`는 **`Layer.swift`에 둔다** — `frame(baseSize:)`가 거기 있고 두 함수는 같은 문장의 두 반쪽이다.

### 4. `LayerStore.swift` — 선택 상태를 "깨질 수 없는 표현"으로

```swift
/// 지금 조작 대상인 항목. **저장소에서 매번 되찾는다.**
///
/// id만 들고 조회를 거치지 않으면, 선택된 레이어가 다른 경로로 사라진 뒤에도
/// 유령을 가리킨다 — 속성바가 없는 레이어를 지우거나 앞으로 보낸다.
/// `entries`를 거치므로 **z도 같은 규칙으로 채워진다**(낡은 z를 되돌리지 않는다).
public var selection: Entry? { get }

/// 단일 선택. 이전 선택은 자동으로 밀려난다(AC-1).
/// **저장소에 없는 id는 조용히 "선택 없음"이 된다** — `move`(`:151-152`)가 없는
/// id를 조용히 무시하는 것과 같은 경합 방어다. 던지면 정상 흐름에 없는 예외를
/// 호출부가 매번 처리해야 한다.
public mutating func select(_ id: UUID)
public mutating func deselect()
```

**구현 메모**

- `private var selectedID: UUID?`. `select`는 `storage`에 있을 때만 저장하고 아니면 `nil`(쓰기 정규화), `remove`는 지운 것이 선택이면 `nil`. **쓰기 정규화와 읽기 파생은 두 벌이 아니다** — 정규화는 `Equatable`이 관측 불가능한 상태로 갈라지지 않게 하고, 파생은 정규화를 빠뜨려도 유령이 새지 않게 한다.
- `selection`은 `entries.first { $0.id == selectedID }`. z 채우기를 다시 쓰면 `entries`와 두 벌이 된다(43개 상한이라 선형 탐색 비용 무시 가능).
- **`insert`는 선택을 건드리지 않는다.** 자동 선택은 `TOOL-1`~`3` 몫.
- z-order 4종은 **한 줄도 바뀌지 않는다.**
- `selectedID` 공개 접근자는 두지 않는다.

```swift
/// 선택은 **합성 `Equatable`에 포함된다** — 저장 프로퍼티라 자동으로 들어간다.
///
/// ⚠️ **`LayerStore ==`로 저장 dirty를 판정하지 마라.** 선택은 `layoutJSON`(v4 §8)에
/// 없어서, 레이어를 **탭하기만 해도** `==`는 달라지지만 저장될 바이트는 그대로다.
/// `CANVAS-5`(1.5초 디바운스 자동 저장)나 실행취소 스냅샷이 이 비교를 dirty 판정에
/// 쓰면 탭마다 저장이 돌고, 실행취소 스택이 선택 변경으로 채워져 **사용자가
/// 되돌리려던 편집이 스택 밖으로 밀려난다.**
/// 판정 기준은 `layers`(또는 인코딩 결과)여야 한다.
private var selectedID: UUID?
```

### 5. `ResizeAnchor.swift` — 문지기를 실제 보장 수준으로 적는다

시그니처는 **그대로 둔다**(리사이즈 동작은 `EDITOR-7`). Geometry는 `LayerKind`를 볼 수 없어 타입 기반 거부가 **불가능하다.**

1회차의 "**막는 방식은 구조다** — 잡을 수 없는 핸들은 끌 수 없다"는 **거짓이다.** `HandlePlacement.init`이 `public`이고 임의 `Set<Edge>`를 받으며, `Edge`도 `public` + `CaseIterable`이라 `Set(Edge.allCases)`가 어디서든 한 줄이다. `resized(draggingEdge:)` 자체도 `public`이다.

**진짜 구조적 보장 — 검토하고 버렸다**

| 대안 | 왜 버렸나 |
|---|---|
| 배치만 만들 수 있는 토큰 타입(`EdgeHandle`)을 `resized`가 받게 한다 | `HandlePlacement.init`이 `Set<Edge>`를 받는 한 `photo`에 `.top` 토큰을 발급받는 길이 남는다 — **구멍이 한 층 위로 옮겨갈 뿐이다.** `ResizeAnchorTests`가 `.right` 리터럴로 부르고 있어 `EDITOR-7` API를 지금 바꾸게 된다 |
| `HandlePlacement.init`을 `internal`로 | Layout이 다른 모듈이라 부를 수 없다 |
| `HandlePlacement`를 Layout으로 이동 | Geometry가 화면 배치를 잃고 `EDITOR-5`·`6`·`9`가 Layout에 묶인다. 순수 기하 패키지의 성격을 깨는 값이 너무 크다 |

```swift
/// 변 핸들 드래그 — 한 축만 바꾸고 반대쪽 변을 고정한다.
///
/// **이 함수는 레이어 종류를 보지 않는다.** `photo`에 한 축 리사이즈를 금지한
/// 정책(v4 §5.7)은 여기서 막을 수 없다 — 이 패키지는 `LayerKind`를 볼 수 없다.
///
/// **타입이 보장하는 것**: `LayerStore.selectionHandles(on:baseSizeOf:)`에는
/// `edges` 매개변수가 **없다.** 그 경로로 배치를 얻는 호출부는 변 집합을 바꿀
/// 방법이 없고, `photo`의 배치에는 변 핸들 원소가 애초에 들어 있지 않다.
///
/// **타입이 보장하지 않는 것**: `HandlePlacement.init(frame:edges:on:)`은 `public`이고
/// 임의 `Set<Edge>`를 받는다. 이 함수도 `public`이라 배치를 건너뛰고 부를 수 있다.
/// 즉 **`EDITOR-7`·`EDITOR-11`이 배치가 낸 값만 쓰는 것은 규율이지 컴파일러가
/// 검사하는 사실이 아니다.** 지금 이 사슬을 고정하는 것은 Layout 쪽 테스트
/// (`placement.edges == kind.resizableEdges`, 5종 전부) 하나뿐이다.
```

## 의존성 및 영향도

- **새 외부 의존성 없음.** Foundation만. CoreGraphics·SwiftUI·UIKit 미사용 — Windows 빌드 유지.
- **패키지 의존 방향 불변**: Layout → Geometry.
- **기존 코드 영향**
  - `LayerStore`에 저장 프로퍼티가 늘어 **`Equatable` 의미가 바뀐다** (§4 경고 참조). 현재 `LayerStore ==`를 dirty 판정에 쓰는 코드는 없다.
  - `Layer.baseSize` = 계산 프로퍼티라 **인코딩되지 않는다** → layoutJSON·`JSONContractTests` 무영향.
  - `Edge`에 `sign`·`Hashable`·`CaseIterable` 추가 = 순수 추가. 파일 이동 = 모듈 내 이동.
  - 기존 319개 테스트에 깨질 것이 없다(`ResizeAnchorTests`는 `.right` 리터럴만 쓴다).
- **`EDITOR-6`이 얹힐 자리를 지금 확정한다** (결정 5)
  - **크기 축을 아는 타입은 `HandlePlacement`다.** 생성자가 `frame`(논리 크기)과 `surface`(배율)를 받으므로 화면 짧은 변 = `frame.size.shortSide * surface.scale`을 **여기서만** 계산할 수 있다.
  - 88pt 규칙은 `Box.edgeHandles`를 걸러내고, 56pt 규칙은 **코너 좌표 자체를 바꾼다** — 후자는 배치 밖에서는 원리상 불가능하다. 두 규칙 모두 `HandlePlacement.init` 안이다.
  - **`EDITOR-4`의 시그니처는 하나도 바뀌지 않는다.** 합성 지점이 생성자 한 곳이라 `EDITOR-6`은 그 본문만 넓힌다. 지금 필터 훅을 미리 뚫지 않는다.
  - `Box.edgeHandles`가 **배열**인 것이 여기서 값을 한다 — 걸러낸 결과가 순서를 유지한다.
- **하위 호환성**: layoutJSON 스키마 변경 **없음.**

## AC ↔ 컴포넌트 매핑

| AC | 검증 대상 API | 테스트 파일 |
|---|---|---|
| AC-1 | `LayerStore.select` → `selection?.id` | `SelectionTests` |
| AC-2 | `deselect` → `selection == nil` | `SelectionTests` |
| AC-3 | `remove` + `selection` 파생 조회 | `SelectionTests` |
| AC-4 | `remove` + `selection` | `SelectionTests` |
| AC-5 | `bringToFront` + `selection?.id` | `SelectionTests` |
| AC-6 | `resizableEdges` + `box.edgeHandles` + `orderedHandles` | `SelectionTests` |
| AC-7 | `HandlePlacement.edges` | `SelectionTests` |
| AC-8 | `HandlePlacement.edges` | `SelectionTests` |
| AC-9 | `box.corner(.topLeft) ≈ surface.toScreen(Vec2(550, 400))` | `HandlePlacementTests` |
| AC-10 | `box.edgeHandles[.left] ≈ surface.toScreen(Vec2(500, 400))` | `HandlePlacementTests` |
| AC-11 | `box.rotate.y ≈ topScreen.y - 28`, `rotateFlipped == false` | `HandlePlacementTests` |
| AC-12 | `box.rotate.y ≈ bottomScreen.y + 28`, `rotateFlipped == true` | `HandlePlacementTests` |
| AC-13 | `rotateFlipped` 두 배율(팬 포함) 비교 | `HandlePlacementTests` |
| AC-14 | `selectionHandles(...) == .empty`, `box == nil` | `SelectionTests` |

AC-9·10은 **역변환(`toLogical`) 대신 정변환 비교**를 쓴다 — PRD의 숫자 (550,400)·(500,400)이 테스트에 그대로 남으면서 왕복 부동소수 오차가 생기지 않는다.

## 구현 순서 (RGR 사이클)

```
1. [Must] LayerStore 선택 3종 + remove 정규화 + Equatable 경고        (의존: 없음)  ── RGR 1/2
   (AC-1~5)
2. [Must] Edge 이동·sign + LayerFrame.edgeMidpoint + HandlePlacement   (의존: 없음)  ┐
   (유한성 가드 · orderedHandles · 뷰포트 상단 기준 뒤집기)                          ├─ RGR 2/2
   (AC-9~13)                                                                        │
3. [Must] Layer.baseSize + LayerKind.resizableEdges + selectionHandles (의존: 1, 2) ┘
   (AC-6·7·8·14)
```

- **1과 2는 다른 패키지의 다른 파일이라 병렬 가능하다.**
- 3은 두 결과를 잇는 얇은 다리이며 `Layer.swift`를 만지는 유일한 단계다.
- 검증은 `./scripts/test.sh` (SPM 3종 + 앱 타깃 + Release 빌드).

## 설계 규모

**중형** — 신규 파일 2 + 수정 4, 기존 API 시그니처 변경 0, 스키마 변경 0.

---

## 픽스처 규약 (테스트 임계값 — 전 항목 이진 정확)

설계에 임계값이 없으면 red 단계가 픽스처를 즉흥으로 고르고, **그 순간 변이 저항이 우연에 맡겨진다.** 아래 값은 전부 검산했다.

### 뒤집기 전용 표면

```
CanvasSurface(canvas: Size2(1080, 1350), viewport: Size2(540, 700))
fitScale = min(540/1080, 700/1350) = min(0.5, 0.5185) = 0.5   (정확)
viewport.height / 2 = 350                                      (정확)
기본 center = (540, 675)
판정식 = (topY − center.y) · scale + 350
```

프레임 규약: `size = 200 × 100`, `rotation = 0` (M3·U1만 π/2).
**`h ≥ 100`이 필수다** — AC-12에서 "기준점을 박스 중심으로" 변이를 죽이려면 `h × scale > 40`이어야 한다(`scale 0.5`에서 여유 5pt: 20 + 25 = 45 > 40). `h = 60`으로 줄이면 그 변이가 살아난다.

| 목적 | 줌 | `center.y` | 논리 `topY` | 화면 y | 기대 | 죽는 변이 |
|---|---|---|---|---|---|---|
| AC-11 | 100% (0.5) | 675 | 175 | 100 | `flipped == false`, `rotate.y ≈ 72` | 28을 논리공간에 적용(U2), `up` 부호 |
| AC-12 | 100% | 675 | 15 | 20 | `flipped == true` | 중심 기준(M2) → 45 > 40 |
| 경계 (포함) | 100% | 675 | 55 | **40.0** | `flipped == true` | `<` vs `<=` |
| 경계 (초과) | 100% | 675 | 56 | **40.5** | `flipped == false` | `<=` vs `<` |
| M1 음수 거리 | 100% | 675 | −125 | −50 | `flipped == true` | `abs()` |
| **AC-13a 줌 축** | 100% / 400% | 675 / 675 | 35 / 515 | 30 / 30 | 둘 다 `true` | 논리좌표 40 비교(N2) → 515 > 40에서 사망 |
| **AC-13b 팬 (결정 4 회귀 방어)** | 400% (2.0) | **1200** | 1040 | 30 | `true` | **캔버스 상단 기준 복귀(N1)** → 2080 > 40에서 사망 |
| AC-13 역방향 (SHOULD) | 100% / 400% | 675 / 675 | **75 / 525** | 50 / 50 | 둘 다 `false` | N2를 반대편에서 |
| M3 회전 무시 | 100% | 675 | center (540, 75), r = π/2 | top 50 | `flipped == false` | `center.y − h/2` → 25 ≤ 40 |
| U1 `up` 방향 | 100% | 675 | 위와 동일 | — | `rotate ≈ (323, 50)` | `(−sin, −cos)` → (267, 50) |

**AC-13은 반드시 a/b로 쪼갠다.** 하나로 합치면 두 변이(N1·N2)가 같은 케이스에 몰려, 그 픽스처가 흔들릴 때 둘이 동시에 살아난다. **AC-13b가 결정 4(뷰포트 기준선)를 지키는 유일한 테스트다** — 팬이 없으면 캔버스 기준 구현도 통과한다.

### AC-9·10 전용 표면 (축 퇴화 회피)

```
CanvasSurface(canvas: post, viewport: Size2(390, 844))
    .zoomed(to: 2).centered(on: Vec2(x: 700, y: 300))
프레임: center (500, 500) · size (200, 100) · rotation π/2
```

기본 표면(줌 1·기본 center)을 쓰면 `center.x · fitScale = 540 × 390/1080 = 195 = viewport.width/2`라 **x축 오프셋 항이 소거되어 퇴화한다.** 팬·줌을 걸어 양 축 모두 비퇴화로 만든다.

단언은 정변환 비교: `box.corner(.topLeft) ≈ surface.toScreen(Vec2(550, 400))`, 네 코너 전부, `.left ≈ toScreen(Vec2(500, 400))`.
π/2 네 코너: `TL(550,400) TR(550,600) BR(450,600) BL(450,400)` — TL·TR이 x를 공유하고 TL·BL이 y를 공유하므로 **양 성분 모두** 단언해야 코너 복제 변이가 죽는다.

---

## Testability 평가 (test-architect)

**✅ TESTABILITY PASS — Score 9/10** (2회차 개정 설계 기준 재평가)

구조적 강결합·전역 상태·static 가변 상태·I/O·시각 의존 **0건**. 시뮬레이터 없이 `swift test`로 전부 돈다.

**1회차 대비 해소**: 비유한 입력 계약 미정의(§2-e), AC-9/10 왕복 공허화(정변환 전환), `Dictionary` 순회 비결정성(`orderedHandles`).
**개선**: 이음매 3 → 4개. 주입면 `LayerFrame`(4칸) → `Size2`(1칸). `shape` 단락이 **호출 횟수라는 새 관측 축**을 만들었다. `surface`를 보관하지 않는 결정(§2-b)은 수명 버그를 테스트가 아니라 타입이 막는다.

**남은 감점 1점** (전부 테스트 층위 — 재설계 불필요):
1. `edgeOrder == Edge.allCases` 사각지대 → **위에서 시계방향으로 바꿔 해소했다.**
2. `frame(baseSize:)` 경유에 검증 배정 없음 — 기존 픽스처가 전부 `scale = 1`, `rotation = 0` 기본값이라 **scale 곱 누락·rotation 누락 변이가 구조적으로 무증상**이다.
3. 픽스처 임계값 미명시 → **위 "픽스처 규약"으로 해소했다.**

### red-writer 인계 조건 (21건)

**RGR 1/2 — `SelectionTests`**

1. `bringToFront(A)` 후 `selection?.layer.transform.z == entries.count − 1` — **`storage.first{}` 파생 변이가 AC-1~5 전부를 통과한다.** PRD 배경과 `LayerStore.swift:54-58` 주석이 경고한 바로 그 버그
2. `select(id)` → `remove(id)` 후 `store == 원본` (쓰기 정규화)
3. `select(유령 UUID)` 후 `store == 원본`

**RGR 2/2 단계 2 — `HandlePlacementTests`**

4. 표면은 `scale ≠ 1`. AC-9/10은 팬·줌으로 축 퇴화 회피
5. 경계 40 표면 = `540×700`, `topY = 55` / `56`
6. **AC-13a(줌 축) / AC-13b(팬) 분리 필수**
7. M1 음수 · M2 큰 높이(`h ≥ 100`) · M3 π/2 뒤집기 · U1 π/2 `up` 방향
8. 뷰포트 0: **왕복 금지**, 원시 `.isFinite`만 + **`box != nil`** 도 함께 단언(`surface`는 가드 대상이 아니다)
9. (SHOULD) 줌 2배 → 코너 간 화면 거리 2배
10. 모든 `Double`은 `isClose(abs < 0.01)`. `==`는 `orderedHandles.map(\.handle)`·`edges`·`box == nil`·`== .empty`·동일 저장값 비교에만
14. `Box.corner(_:)` 4종 매핑을 π/2 네 값으로 (양 성분) — 저장 프로퍼티와 별개인 새 매핑 표면
15. `orderedHandles` 전체 `[Handle]` 시퀀스 리터럴 (`photo` 6 / `shape` 10) + `edgeOrder` 리터럴 + `edgeHandles.map(\.edge)` 순서
16. 유한성 가드 5필드 × `NaN`/`inf` 테이블 → `box == nil`
17. **크기 0·음수 → `box != nil`** — §2-e가 명시한 계약이자 **결정 5(`EDITOR-6` 자리)를 보존하는 유일한 테스트**
20. **AC-13b 독립 테스트에 "결정 4 회귀 방어"라고 이름 붙일 것**
21. 뷰포트 0에서 `rotateFlipped == true` 고정

**RGR 2/2 단계 3 — `SelectionTests` 후반**

11. `resizableEdges` **리터럴 5종 테이블** — `placement.edges == kind.resizableEdges`는 **양변이 같은 접근자에서 나오는 동어반복**이라, 이것 없이는 전 종류가 `Set(Edge.allCases)`를 반환해도 초록이다
12. `orderedHandles` 전체 시퀀스 (존재는 `Box` 비옵셔널이 타입 보장 — 값만 재면 된다)
13. AC-14는 **5종 스토어 + `deselect()`**, 스텁은 **kind별 서로 다른 `Size2`**, 선택은 **비-첫번째 레이어**
18. `baseSizeOf` 호출 **0회(shape) / 1회(나머지 4종)** + 넘어온 레이어 동일성 (비탈출 클로저라 로컬 `var` 캡처로 기록 가능)
19. 픽스처 최소 1건이 **`scale ≠ 1` · `rotation ≠ 0` · 비정사각형 shape** + 좌표 실제 단언 — 감점 사유 2를 닫는 조건

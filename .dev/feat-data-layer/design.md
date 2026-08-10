# 설계 최종본: Phase 1 데이터 레이어 — 모델 3종 + 리포지토리

> 확정: 2026-08-10 / 파이프라인: gx-tdd (mode: all, profile: standard)
> 설계 규모: **대형** / Testability: **8/10 ✅ PASS**
> 이 문서의 근거는 **전부 프로브 실측으로 확인된 것만** 남겼다. 초안의 미검증 가정 3건은 반증되어 교체됐다.

## 배경 및 목적

- 정식 데이터 계층이 없다. `Soozip/Spikes/S2_CloudKitProbe.swift`의 프로브 모델만 시뮬레이터에서 CloudKit 제약 검증을 마친 상태다.
- Phase 1은 UI 없이 영속성 계층을 완성한다. Phase 3~5(에디터)와 Phase 6(모음집 화면)이 전부 이 위에 얹힌다.
- 핵심 목표: **표지 불변식(QE-2)이 어떤 경로로도 깨지지 않는 것**, **cascade 삭제로 고아 레코드가 남지 않는 것**.

### QE-2의 근본 원인 (재정의)

초안은 원인을 "재계산 로직이 3지점에 흩어지는 것"으로 봤다. **틀렸다.**

> **`coverCanvasID ∈ {소속 캔버스의 id} ∪ {""}` 라는 불변식이 어디에도 선언되지도, 검사되지도 않는다.**

로직을 한 함수로 모으는 것은 *알려진* 3개 경로만 막는다. 아직 짜지 않은 네 번째 경로 — 실제로 초안의 `saveCanvas` 업서트가 그 네 번째였고 **실측으로 재현됐다** — 는 그대로 통과한다. 관계 타입으로 바꿔도 "그 캔버스가 이 모음집 소속"이라는 제약은 SwiftData가 걸어 주지 않으므로 v4 §7.1의 String 선택은 여전히 유효하다.

따라서 이번 설계는 **불변식을 코드로 선언하고, 테스트 하네스가 모든 테스트 종료 시점에 자동 검증**한다.

## 요구사항 및 수용 기준

PRD `.dev/feat-data-layer/prd.md`를 계약으로 삼되, 검증 과정에서 확정된 개정 3건을 반영한다.

| 개정 | 내용 |
|---|---|
| **AC-12** | 원문("A가 대표 아닌 캔버스 C3**만** 보유")은 자기모순이다 — C3만 있으면 FR-7상 C3이 대표여야 한다. 개정: **A = 대표 C4 + 비대표 C3, B = 대표 C9. C3을 A→B 이동 시 A는 C4 유지, B는 C9 유지** |
| **BR-9** | ① `now`의 오늘보다 **미래인 기록 날짜는 제외**(BR-3이 미래를 허용하므로 오타 1건이 30일 스트릭을 1로 만든다) ② 남은 저장일 중 최근이 **오늘 또는 어제**면 역산, 아니면 **0**(유예 1일) |
| **AC 신설** | **AC-25a** 미래 날짜가 섞여도 오늘·어제·그저께면 3 / **AC-25b** 최근 저장일이 3일 전이면 0 |

| 그룹 | AC | 설계 담당 |
|---|---|---|
| 모델·CloudKit 제약 | AC-1~5 | 모델 3종 + `SoozipSchema` + `ModelSchemaTests` |
| 표지 — 생성 | AC-6, 7 | `createCanvas` → `reconcileCover` |
| 표지 — 삭제 | AC-8, 9, 10 | `deleteCanvas` → `reconcileCover` |
| 표지 — 이동 | AC-11, 12(개정), 13 | `moveCanvas` → `reconcileCover` ×2 |
| sortIndex | AC-14, 15 | `createCollection` + `collections()` 2키 정렬 |
| cascade | AC-16, 17 | `@Relationship(deleteRule: .cascade)` **단독** |
| 표지 폴백 | AC-18 | `CoverPolicy.resolve` (읽기 전용) |
| 통계 | AC-19~25, **25a, 25b** | `StatsRepository` |
| 로컬 모드 | AC-26~28 | `SyncStatusResolver` |
| 입력 제약 | AC-29~32 | `InputLimits` + `RepositoryError` |
| **불변식 (QE-2)** | AC 무관, 전 테스트 자동 | `CoverPolicy.isConsistent` + `withLibrary` |

## 변경 범위

### 신규 파일

| 파일 | 책임 |
|---|---|
| `Soozip/Data/Models/Collection.swift` | `@Model final class Collection` |
| `Soozip/Data/Models/Canvas.swift` | `@Model final class Canvas` + `aspectPreset` 브리지 |
| `Soozip/Data/Models/CanvasPhoto.swift` | `@Model final class CanvasPhoto` |
| `Soozip/Data/Models/SoozipSchema.swift` | 모델 목록 SSOT |
| `Soozip/Data/Repository/RepositoryError.swift` | `RepositoryError` + `InputLimits` |
| `Soozip/Data/Repository/CoverPolicy.swift` | 표지 선택·재계산·**불변식 검사**. 전부 순수 |
| `Soozip/Data/Repository/LibraryRepository.swift` | 모음집·캔버스 CRUD, 표지 재계산 호출 |
| `Soozip/Data/Repository/StatsRepository.swift` | 통계 5종 |
| `Soozip/Data/Repository/SyncStatusResolver.swift` | 로컬 모드 판정 |
| `SoozipTests/TestContainer.swift` | `withLibrary` 헬퍼 + 고정 `Calendar`/앵커 |
| `SoozipTests/ModelSchemaTests.swift` | AC-1~5 + `deleteRule` 선언 계약 |
| `SoozipTests/CoverPolicyTests.swift` | 표지 순수 단위 테스트 (컨테이너 불필요) |
| `SoozipTests/LibraryRepositoryTests.swift` | AC-6~18, 29~32 + cascade 우회 경로 |
| `SoozipTests/StatsRepositoryTests.swift` | AC-19~25, 25a, 25b |
| `SoozipTests/SyncStatusResolverTests.swift` | AC-26~28 |

### 수정 파일

| 파일 | 변경 |
|---|---|
| `Soozip/App/SoozipApp.swift` | `.modelContainer(for: [ProbeCollection.self, ProbeCanvas.self])` → `.modelContainer(for: SoozipSchema.models)` |
| `Soozip/Spikes/S2_CloudKitProbe.swift` | 프로브 전용 컨테이너를 뷰 내부로 내린다 |
| `Soozip.xcodeproj` | 산출물. 파일 추가 후 `xcodegen generate` |

`project.yml`은 **수정 불필요** — `sources`가 폴더 단위라 새 파일이 자동 편입된다. 단 XcodeGen이 생성 시점 목록을 굽으므로 `xcodegen generate`를 반드시 돌린다.

### 명시적으로 만들지 않는 것 (검증 과정에서 삭제 결정)

| 항목 | 삭제 근거 |
|---|---|
| `ICloudAccountStatusProviding` | 구현체 0개·호출부 0개·AC 0건. 폐기 예정 타입이 스키마 동결 대상에 끼는 것을 경계한 것과 같은 논리. Phase 9가 실제 호출부를 가질 때 만든다 |
| `LibraryRepository.addPhoto` | FR·AC 어디에도 없고 존재 이유가 cascade 테스트 픽스처뿐. 테스트가 `CanvasPhoto`를 직접 `insert`하면 된다. **블롭을 쓰는 유일한 메서드를 안 만들면 Phase 2가 `LibraryRepository`를 건드리지 않고 별도 `@ModelActor` 사진 임포터를 붙일 수 있다** |
| `LibraryRepository.collection(id:)` | 호출부 0개. `createCanvas`가 `Collection`을 직접 받게 되면서 조회 필요가 사라졌다 |
| `RepositoryError.collectionNotFound` | 던지는 곳이 사라졌다. "모음집이 다른 기기에서 삭제됨"은 옵셔널 반환이 호출부 분기에 더 맞는다 |
| **`LibraryRepository.purge(_:)`** | **실측으로 존치 근거가 무너졌다. §8 참조** |
| `renameCollection` / `reorderCollections` | FR·AC 모두 없다. Phase 6이 필요로 할 때 추가 |

## 적용 컨벤션

기존 `DraftStore.swift`·`LayoutDocument.swift` 패턴을 따른다.

- **주석은 한국어로 "왜"를 적는다.** **틀린 "왜"는 없는 것보다 나쁘다** — 이 문서의 근거는 전부 실측 확인된 것만 남겼다
- 설계 문서 참조를 주석에 박는다 — `(v4 §7.1)` 형식
- 값 타입 선호 / 의존성은 생성자 주입
- **시각은 파라미터로 받는다. 예외를 두지 않는다** — `streakDays()`만 안 받게 뒀던 것이 정확히 BR-9 버그 지점이었다
- 에러는 `enum ...Error: Error, Equatable` + 케이스에 맥락
- 테스트 함수명은 한국어 / 테스트 헬퍼는 `with~` 클로저 스코프
- 강제 언래핑 대신 `try #require`
- `// MARK: -` 섹션 구분

### 이번 Phase에서 추가되는 컨벤션 3건

1. **`coverCanvasID`에 직접 대입하는 코드를 `CoverPolicy` 밖에 두지 않는다.** `UUID.uuidString`은 대문자를 내지만 `UUID(uuidString:)`은 소문자도 받는다. 비교가 대소문자를 구분하므로 대입 지점이 흩어지면 케이싱이 다른 값이 섞여 표지가 조용히 사라진다.
2. **앱·테스트 타깃에서 `<C: Collection>` 같은 stdlib 제네릭 제약을 쓰지 않는다.** 쓰려면 `Swift.Collection`으로 한정한다. 실측: 테스트 모듈에서 `Soozip.Collection`이 **모호성 에러 없이 조용히 이긴다.** 제네릭 제약 자리에서만 컴파일이 깨진다.
3. **`isDeleted`로 삭제를 검증하지 않는다.** 실측: `save()` 이후 `isDeleted`가 `false`로 되돌아온다. 삭제 검증은 `context.fetchCount(FetchDescriptor<T>())`로만 한다.

## 상세 설계

### 1. SoozipSchema — 모델 목록 SSOT

```swift
enum SoozipSchema {
    /// 앱 배선(`SoozipApp`)·테스트 컨테이너·스키마 검사 테스트가 **같은 목록**을 본다.
    /// 세 곳이 각자 배열을 들면 한 곳만 빠졌을 때 관계가 통째로 깨지는데
    /// 증상이 컴파일이 아니라 런타임에야 나온다.
    static let models: [any PersistentModel.Type] = [Collection.self, Canvas.self, CanvasPhoto.self]
}
```

> 초안은 "`[any PersistentModel.Type]`의 Sendable 적합성 때문에 `static let`이 Swift 6에서 진단에 걸린다"고 적었다. **실측 결과 `-swift-version 6`에서 진단 0건이다.** 근거를 SSOT로 교체하고 `static let`으로 되돌렸다.

### 2. Collection

```swift
@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0

    /// 관계가 아니라 문자열이다(v4 §7.1). 대표 캔버스로 관계를 하나 더 걸면
    /// CloudKit에서 순환 참조 구성이 까다로워진다. 대상이 삭제돼도 빈 문자열
    /// 취급하면 안전하게 폴백된다.
    ///
    /// **여기에 직접 대입하지 마라.** 유일한 대입 지점은 `CoverPolicy.reconcile`이다.
    var coverCanvasID: String = ""

    // 역관계(`inverse:`)는 **한쪽에만** 선언한다. 양쪽에 걸면 SwiftData가
    // 관계를 두 개로 보고 스키마 구성에서 죽는다.
    @Relationship(deleteRule: .cascade, inverse: \Canvas.collection)
    var canvases: [Canvas]? = []

    // iOS 26 SDK의 @Model은 전 속성에 기본값이 있어도 이니셜라이저를 요구한다.
    // (docs/reports/2026-08-10-spike-results.md S2-a)
    init() {}
}
```

**타입명 유지 확정.** 앱 타깃 4개 파일에 `Collection`·`Canvas` 사용은 0건이고 프로브 컴파일로 확인됐다. 타입명이 곧 CloudKit 레코드 타입명(`CD_Collection`)이라 첫 심사 후 개명이 불가능하므로 v4 설계서·PRD와 일치하는 이름을 그대로 간다.

### 3. Canvas

```swift
@Model final class Canvas {
    var id: UUID = UUID()
    var aspect: Int = 0            // CanvasAspect.rawValue (0=4:5, 1=9:16)
    var title: String = ""
    var createdAt: Date = Date()   // 사용자가 지정하는 기록 날짜. 미래 허용 (BR-3)
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \CanvasPhoto.canvas)
    var photos: [CanvasPhoto]? = []

    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: Collection?

    init() {}
}

extension Canvas {
    /// 저장은 Int, 사용은 enum. **extension에 두는 이유**: 클래스 본문의 계산
    /// 프로퍼티는 SwiftData가 스키마 후보로 훑는다. 첫 심사 후 스키마 동결이
    /// 걸리므로 저장 대상이 아닌 것은 확실히 밖에 둔다.
    ///
    /// 모르는 rawValue를 `.post`로 낮추는 이유: 상위 버전 기기가 만든 프리셋이
    /// 동기화로 내려와도 화면이 비지 않게 (v4 §7.1).
    var aspectPreset: CanvasAspect {
        get { CanvasAspect(rawValue: aspect) ?? .post }
        set { aspect = newValue.rawValue }
    }
}
```

### 4. CanvasPhoto

```swift
@Model final class CanvasPhoto {
    var id: UUID = UUID()

    /// 원본 2000px 사본. externalStorage → CloudKit에서 CKAsset이 된다.
    /// **레이어의 `assetId`가 이 `id`를 가리킨다** — 복제 레이어 5개가 같은
    /// 레코드를 공유한다(BR-5, v4 §7.1). 레이어 하나 지웠다고 여기를 지우면
    /// 나머지 복제본이 깨진다.
    @Attribute(.externalStorage) var data: Data = Data()

    var canvas: Canvas?
    init() {}
}
```

> 초안의 "인메모리에서는 테스트 블롭을 작게" 주의는 삭제한다. **실측: 300KB 블롭도 정상 왕복한다.**

### 5. CoverPolicy — 표지 판정 + 불변식

**전부 순수 함수다. `ModelContext`도 관계 배열도 읽지 않는다.** 후보 목록을 어떻게 얻을지는 리포지토리 책임이다.

```swift
enum CoverPolicy {

    /// 유효한 표지를 고른다. 저장된 식별자가 후보 안에 있으면 그것,
    /// 아니면 가장 최근 캔버스, 후보가 없으면 nil.
    ///
    /// **생성·삭제·이동 세 지점과 조회(AC-18)가 전부 이 판정 하나를 쓴다.**
    static func resolve(in canvases: [Canvas], coverID: String) -> Canvas? {
        guard !canvases.isEmpty else { return nil }                       // BR-4
        if let kept = canvases.first(where: { $0.id.uuidString == coverID }) {
            return kept                                                   // AC-7·9·12
        }
        // BR-6은 createdAt 최신값이다. id를 2차 키로 넣는 이유: createdAt이
        // 같은 캔버스가 둘이면 결과가 배열 순서에 의존하는데, SwiftData의
        // to-many 순서는 보장되지 않아 같은 데이터에서 표지가 실행마다 바뀐다.
        return canvases.max { l, r in
            (l.createdAt, l.id.uuidString) < (r.createdAt, r.id.uuidString)
        }
    }

    /// 고른 결과를 모음집에 기록한다. **`coverCanvasID`에 대입하는 유일한 지점이다.**
    static func reconcile(_ collection: Collection, candidates: [Canvas]) {
        let next = resolve(in: candidates, coverID: collection.coverCanvasID)?
            .id.uuidString ?? ""      // 후보가 0장이면 빈 문자열 (BR-4, AC-10, AC-13)

        // 값이 같으면 대입하지 않는다. 무조건 대입하면 Collection 레코드가 매번
        // 더티가 되어 CloudKit이 변경 없는 레코드를 계속 올리고, LWW 판정
        // 대상(v4 §6.9)이 늘어 충돌 표면이 넓어진다.
        guard next != collection.coverCanvasID else { return }
        collection.coverCanvasID = next
    }

    /// **이 계층의 불변식.** `coverCanvasID`는 빈 문자열이거나 소속 캔버스를 가리킨다.
    ///
    /// 개별 AC는 우리가 아는 경로만 막는다. 실제로 초안 설계의 `saveCanvas`
    /// 업서트는 AC 어디에도 안 걸리면서 "표지=C1인데 소속 캔버스 0장"을 만들었다.
    /// 불변식은 아직 짜지 않은 경로까지 막는다.
    static func isConsistent(_ collection: Collection, candidates: [Canvas]) -> Bool {
        collection.coverCanvasID.isEmpty
            || candidates.contains { $0.id.uuidString == collection.coverCanvasID }
    }
}
```

**테스트 가능성:** **실측 확인 — 컨테이너에 삽입하지 않은 `@Model` 인스턴스의 속성 읽기·쓰기·관계 대입이 전부 동작한다.** `CoverPolicyTests`는 `ModelContainer` 없이 `Canvas()` 몇 개로 돈다. **표지 AC 8건의 판정이 SwiftData·CloudKit과 완전히 분리된다** — S2 보류 상태의 최대 방어선이다.

### 6. RepositoryError + InputLimits

```swift
/// v4 §6.9 입력 한계. 텍스트 레이어 200자는 SoozipLayout 책임이라 없다.
enum InputLimits {
    static let collectionName: ClosedRange<Int> = 1...20
    static let canvasTitle: ClosedRange<Int> = 0...40
}

enum RepositoryError: Error, Equatable {
    case collectionNameOutOfRange(length: Int, allowed: ClosedRange<Int>)
    case canvasTitleOutOfRange(length: Int, allowed: ClosedRange<Int>)
}
```

- 길이 단위는 `String.count`(grapheme cluster) — 이모지 1자 = 1자(BR-1)
- 공백 트리밍은 하지 않는다 (PRD 무규정 + BR-2 정신). 트리밍은 Phase 6 UI 몫

### 7. LibraryRepository

```swift
/// 캔버스 생성 입력. **`collectionID`를 담지 않는다** — 소속은 `in collection:`
/// 파라미터로만 들어오고, 소속 *변경*은 `moveCanvas` 하나뿐이다.
struct CanvasInput: Equatable, Sendable {
    var id: UUID = UUID()
    var aspect: CanvasAspect
    var title: String = ""
    var createdAt: Date
    var layoutJSON: Data = Data()
    var renderedPNG: Data? = nil
}

enum CanvasOrder: Sendable { case newestFirst, oldestFirst }

@MainActor
struct LibraryRepository {
    let context: ModelContext

    // MARK: 모음집
    @discardableResult
    func createCollection(name: String, now: Date) throws -> Collection
    func collections() throws -> [Collection]
    func deleteCollection(_ collection: Collection) throws

    // MARK: 캔버스
    @discardableResult
    func createCanvas(_ input: CanvasInput, in collection: Collection, now: Date) throws -> Canvas
    func updateCanvas(_ canvas: Canvas, title: String, createdAt: Date,
                      layoutJSON: Data, now: Date) throws
    func deleteCanvas(_ canvas: Canvas) throws
    func moveCanvas(_ canvas: Canvas, to destination: Collection) throws
    func canvases(in collection: Collection, order: CanvasOrder = .newestFirst) -> [Canvas]
    func coverCanvas(of collection: Collection) -> Canvas?

    // MARK: 내부
    private func canvasesFetched(in collection: Collection) -> [Canvas]
    private func reconcileCover(of collection: Collection)
    private func nextSortIndex() throws -> Int
}
```

#### 업서트를 쪼갠 이유 (실측으로 재현된 구멍)

초안의 `saveCanvas`는 `input.collectionID`로 소속을 바꿀 수 있는 업서트였다.

```
A 표지=C1, B 표지=(빈값)
→ saveCanvas(id: C1.id, collectionID: B)
→ A 표지=C1인데 A의 캔버스 수=0     ← 불변식 위반. AC-13도 함께 깨진다
```

v4 §6.7의 **메타 수정 시트가 제목·날짜·소속 이동을 한 화면에서 받는다.** Phase 6/7의 실제 호출부가 정확히 이 모양이라 오용 시나리오가 아니다.

- `createCanvas(_:in:now:)` — 소속을 **받되 변경하지 않는다**
- `updateCanvas(_:title:createdAt:layoutJSON:now:)` — **소속을 아예 받지 않는다**
- `moveCanvas(_:to:)` — 소속 변경의 **단일 경로**

`updateCanvas`가 `renderedPNG`를 받지 않는 이유: **수 MB 블롭이라 제목만 고치는 호출에서도 다시 대입되면 레코드가 더티가 되어 CKAsset이 통째로 재업로드된다.** 렌더 갱신은 Phase 2 승격 트랜잭션 몫이다.

#### 동작 상세

**`createCollection(name:now:)`** — 길이 검증(AC-29, **insert보다 먼저**라 실패 시 부분 상태가 없다) → 중복 검사 안 함(AC-31) → `sortIndex = nextSortIndex()` → insert → save

**`nextSortIndex()`**
```swift
var d = FetchDescriptor<Collection>(sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
d.fetchLimit = 1        // 전량을 끌어와 max를 돌면 모음집이 늘수록 느려진다
return try context.fetch(d).first.map { $0.sortIndex + 1 } ?? 0   // 첫 모음집은 0
```

**`collections()`** — `sortIndex` 오름차순 + `createdAt` 오름차순 2키 (AC-15)

**`canvasesFetched(in:)` — 후보 목록의 유일한 출처**
```swift
/// 관계 배열(`collection.canvases`)이 아니라 fetch를 쓴다.
/// **실측: to-many 관계 배열은 save() 전까지 삭제·이동을 반영하지 않지만
/// fetch는 즉시 반영한다.** 이 비대칭이 유령 표지의 원천이라 조회를
/// 저장 시점에 의존시키지 않으려고 느린 쪽을 택했다.
private func canvasesFetched(in collection: Collection) -> [Canvas] {
    let owner = collection.id
    let all = (try? context.fetch(FetchDescriptor<Canvas>())) ?? []
    return all.filter { $0.collection?.id == owner }
}
```
`#Predicate`로 옵셔널 관계 경유 비교는 iOS 17에서 불안정하다는 보고가 있어 피한다.

**`createCanvas(_:in:now:)`** — 제목 검증(AC-30, insert 전) → `Canvas()` 생성·속성 대입 → `createdAt`은 **보정 없이 그대로**(AC-32, BR-3) → `updatedAt = now`, `collection` 대입, insert → `save()` → `reconcileCover` → `save()`

**`updateCanvas(...)`** — 제목 검증 → 속성 대입 → `save()` → `reconcileCover` → `save()`. 갱신 경로에서도 재계산을 부르는 이유는 **"모든 변경 뒤에 재계산"에 예외를 두지 않기 위해서**다 — 예외가 곧 빠뜨릴 자리다.

**`deleteCanvas(_:)`**
```swift
func deleteCanvas(_ canvas: Canvas) throws {
    // 삭제 후에도 `canvas.collection`은 non-nil로 살아 있다(실측 — `isDeleted`도 false다).
    // 그래도 먼저 잡는 이유는 삭제된 객체의 속성 접근에 의존하지 않기 위해서다.
    let owner = canvas.collection

    context.delete(canvas)   // 사진은 deleteRule: .cascade가 지운다 (§8)

    // ── 순서 고정: 변경 → save → reconcile → save ──
    // 관계 배열은 save() 전까지 삭제·이동을 반영하지 않는다(실측).
    // "save 두 번이 비효율적이니 합치자"는 평범한 리팩터가 유령 표지를 만든다.
    try context.save()
    if let owner { reconcileCover(of: owner); try context.save() }
}
```

**`moveCanvas(_:to:)`** — 같은 모음집이면 즉시 return → `collection = destination` → `save()` → 원본·목적지 각각 `reconcileCover` → `save()`. AC-12(개정)의 "양쪽 다 안 바뀜"은 `resolve` 규칙 2 + `reconcile` 가드가 처리한다.

**`deleteCollection(_:)`** — `context.delete(collection)` + `save()`. 표지 재계산 없음.

**`coverCanvas(of:)`** — **읽기 전용이다.** AC-18은 조회가 DB를 건드리지 않을 것을 전제한다.

### 8. cascade — `deleteRule` 단독 (초안의 `purge` 철회)

초안이 `purge`를 둔 근거는 "SwiftData의 cascade 발화 시점이 흔들린 전례가 있어 AC-16/17을 프레임워크에 맡길 수 없다"였다. **실측으로 반증됐다** — 두 검증자가 독립적으로 `deleteRule: .cascade` 단독으로 `(collection, canvas, photo) = (0, 0, 0)`을 확인했고 전이 cascade까지 발화한다.

근거가 사라진 중복 경로는 남기지 않는다. **남기면 오히려 새 버그를 만든다:**

> `purge`를 유지한 상태에서 누군가 `deleteRule`을 `.nullify`로 바꾸면 리포지토리 경로는 여전히 정상 동작하므로 AC-16/17이 초록이다. **조용히 깨지는 것은 Phase 6의 `@Query` + 스와이프 삭제 경로 하나뿐이다.** 이것이 정확히 우리가 피하려던 "한 곳만 고쳐 버그" 형태다.

대신 선언을 **유일한 계약**으로 두고 두 층으로 고정한다.

1. **`ModelSchemaTests`가 선언을 단언한다** — `deleteRule == .cascade`, `inverseName` 확인. 삭제 의미론을 바꾸면 스키마 테스트가 먼저 빨개진다.
2. **리포지토리를 우회하는 삭제 테스트 1건** — `context.delete(collection)` 직접 호출 후 `fetchCount`로 자식 소멸 확인. 이 테스트가 없으면 cascade가 죽어도 리포지토리 테스트는 전부 초록이다. 그리고 이 경로가 곧 Phase 6의 실제 호출부다.

CloudKit과 충돌 없음 — 미지원 규칙은 `.deny`이고 관계는 여전히 양쪽 optional이라 AC-3을 어기지 않는다.

### 9. StatsRepository

```swift
struct CollectionSummary: Equatable, Sendable {
    let id: UUID
    let name: String
    let canvasCount: Int
}

@MainActor
struct StatsRepository {
    let context: ModelContext
    /// **주입 대상이다.** "이번 달"과 "연속 기록"의 경계가 타임존에 걸려 있어
    /// `.current`를 박으면 CI 타임존이 바뀌는 순간 AC-21·24·25가 흔들린다.
    let calendar: Calendar

    func collectionCount() throws -> Int                      // AC-19
    func canvasCount() throws -> Int                          // AC-20
    func canvasCount(inMonthOf now: Date) throws -> Int       // AC-21
    func largestCollection() throws -> CollectionSummary?     // AC-22, 23
    func streakDays(now: Date) throws -> Int                  // AC-24, 25, 25a, 25b
}
```

- **`largestCollection()`**: `createdAt` 오름차순으로 훑으며 **엄격한 초과(`>`)일 때만 갱신**. 동률에서 갱신하지 않으므로 먼저 생성된 쪽이 남는다(BR-8, AC-23). `max(by:)`는 동률에서 마지막을 돌려주므로 쓰지 않는다.

**`streakDays(now:)` — BR-9 개정 반영**

```swift
func streakDays(now: Date) throws -> Int {
    let today = calendar.startOfDay(for: now)

    // BR-9①: now의 오늘보다 미래인 기록 날짜는 제외한다. BR-3이 미래를 허용하므로
    // 사용자가 날짜를 한 번 잘못 찍으면 30일 스트릭이 1로 무너진다.
    let days = Set(try context.fetch(FetchDescriptor<Canvas>())
        .map { calendar.startOfDay(for: $0.createdAt) }
        .filter { $0 <= today })

    guard let latest = days.max(),
          let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
    else { return 0 }

    // BR-9②: 유예 1일. 오늘 아직 저장하지 않았다는 이유만으로 끊기지 않되(AC-25),
    // 며칠씩 비어 있는데 옛 연속을 계속 보고하지도 않는다(AC-25b).
    guard latest == today || latest == yesterday else { return 0 }

    var streak = 0
    var cursor = latest
    while days.contains(cursor) {
        streak += 1
        // TimeInterval 산술(-86400) 대신 Calendar를 쓴다. DST 경계에서 하루가
        // 23/25시간이 되는 날 계산이 어긋난다.
        guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = prev
    }
    return streak
}
```

> 초안은 `streakDays()`가 `now`를 안 받는 것을 "실행 시점 독립"이라며 장점으로 적었다. **그게 버그 지점이었다.** `canvasCount(inMonthOf:)`는 받는데 이것만 안 받는 예외가 미래 날짜 오염과 무기한 스트릭을 동시에 만들었다.

검증: AC-24(3) ✓ / AC-25(2) ✓ / AC-25a(미래 제외 → 3) ✓ / AC-25b(유예 밖 → 0) ✓

### 10. SyncStatusResolver

```swift
enum SyncMode: Equatable, Sendable { case cloud, local }

/// **CloudKit 타입을 받지 않는다.** `CKAccountStatus`를 그대로 받으면 AC-26~28을
/// 검증하려고 실제 iCloud 계정이 필요해진다. 두 신호를 Bool로 좁혀 두면 판정이
/// 순수 값 연산이 되고, 실제 조회는 Phase 9의 어댑터로 밀려난다.
struct SyncStatusResolver: Equatable, Sendable {
    var accountAvailable: Bool = true
    var quotaExceeded: Bool = false

    /// 두 신호 중 하나라도 걸리면 로컬 모드(FR-13).
    var mode: SyncMode { (accountAvailable && !quotaExceeded) ? .cloud : .local }
    var isLocalMode: Bool { mode == .local }
}
```

용량 초과 신호의 출처는 저장 실패(`CKError.quotaExceeded`)다. 래칭은 Phase 9의 관찰 객체 몫이다.

### 11. TestContainer — 컨테이너 격리 + 불변식 자동 검증

```swift
/// 테스트마다 **새 컨테이너**를 만든다. Swift Testing은 기본이 병렬 실행이라
/// 컨테이너를 공유하면 다른 테스트가 넣은 모음집이 AC-19 같은 카운트 검증에
/// 그대로 섞여 들어온다.
///
/// `checksCoverInvariant`를 끄는 테스트는 **AC-18 하나뿐**이어야 한다 — 다른
/// 기기가 만든 유령 표지 상태를 재현하는 유일한 테스트다.
@MainActor
func withLibrary(checksCoverInvariant: Bool = true,
                 sourceLocation: SourceLocation = #_sourceLocation,
                 _ body: (LibraryRepository, ModelContext) throws -> Void) throws {
    let schema = Schema(SoozipSchema.models)
    let config = ModelConfiguration(
        UUID().uuidString,        // 이름을 매번 다르게
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none   // **필수.** 켜 두면 컨테이너 초기화가 iCloud를
                                  // 건드려 테스트가 계정·네트워크 상태에 묶인다
    )
    let container = try ModelContainer(for: schema, configurations: config)
    let context = ModelContext(container)

    // **실측: ModelContext(container)의 autosaveEnabled 기본값은 true다.**
    // 끄지 않으면 autosave가 "save → reconcile" 순서 버그를 가려 버린다 —
    // 순서를 틀리게 짜도 테스트가 초록이 되는 것이 가장 나쁜 상태다.
    context.autosaveEnabled = false

    try body(LibraryRepository(context: context), context)

    guard checksCoverInvariant else { return }

    // 클로저가 끝나면 전 모음집의 표지 불변식을 검사한다.
    // 개별 AC는 아는 경로만 막지만, 이 검사는 아직 짜지 않은 경로까지 막는다.
    try context.save()
    let collections = try context.fetch(FetchDescriptor<Collection>())
    let allCanvases = try context.fetch(FetchDescriptor<Canvas>())
    for c in collections {
        let candidates = allCanvases.filter { $0.collection?.id == c.id }
        #expect(CoverPolicy.isConsistent(c, candidates: candidates),
                "표지 불변식 위반 — 모음집 \(c.name): cover=\(c.coverCanvasID), 소속 \(candidates.count)장",
                sourceLocation: sourceLocation)
    }
}

// MARK: - 시간 픽스처

/// **timeZone을 박는다.** `Calendar(identifier: .gregorian)`은 `TimeZone.current`를
/// 물고 온다(실측). CI 타임존이 다르면 AC-21·24·25가 기기마다 다른 결과를 낸다.
@MainActor
var testCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return cal
}

/// 고정 앵커. `Date()`에서 역산하면 자정 직전에 돌릴 때 하루가 밀린다.
@MainActor
func testAnchor() throws -> Date {
    try #require(testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 12)))
}
```

### 12. ModelSchemaTests — AC-1~5를 기계 검증으로

**실측 확인: `Schema` 리플렉션 4종(`isUnique`/`defaultValue`/`isOptional`/`inverseName`)이 실존하고 Swift 기본값이 `defaultValue`에 채워진다. 폴백 불필요.**

```swift
// AC-1·2·3
let schema = Schema(SoozipSchema.models)
#expect(schema.entities.count == 3)

for entity in schema.entities {
    for attr in entity.attributes {
        #expect(!attr.isUnique)                                     // AC-2
        #expect(attr.isOptional || attr.defaultValue != nil)        // AC-1
    }
    for rel in entity.relationships {
        // **관계에도 unique를 걸 수 있다.** attributes만 도는 AC-2 검사는 반쪽이다.
        #expect(!rel.isUnique)                                      // AC-2
        #expect(rel.isOptional)                                     // AC-3
        #expect(rel.inverseName != nil)                             // AC-3
    }
}

// AC-4 — 화이트리스트로 배열 속성 배제 + 명시 타입 대조
let allowed: Set<String> = ["UUID", "String", "Date", "Int", "Data", "Optional<Data>"]
// ... sortIndex == Int.self, coverCanvasID == String.self 대조

// deleteRule 선언 계약 고정 (§8) — AC-16/17을 실제로 수행하는 메커니즘
#expect(canvases.deleteRule == .cascade)
#expect(photos.deleteRule == .cascade)
```

AC-5는 무인자 생성 + `context.insert` + `fetchCount`로 확인한다.

### 13. 앱·스파이크 컨테이너 분리

```swift
// SoozipApp.swift
.modelContainer(for: SoozipSchema.models)

// S2_CloudKitProbe.swift — NavigationStack에 붙인다
.modelContainer(for: [ProbeCollection.self, ProbeCanvas.self])
```

- 프로브 모델을 앱 스키마에 섞으면 S2 측정 쓰레기 레코드가 정식 스토어에 남고, 스키마 동결 대상에 폐기 예정 타입이 낀다
- SwiftUI에서 하위 뷰의 `.modelContainer`는 환경을 덮어쓰므로 스파이크와 충돌하지 않는다
- Phase 0 종료 시 `Soozip/Spikes/`를 통째로 지우면 프로브 컨테이너도 같이 사라진다
- `project.yml`에 `entitlements` 키가 없어 `.automatic`은 로컬 스토어로 낙착된다. Phase 1의 AC는 전부 로컬에서 성립한다

## 의존성 및 영향도

**새 외부 의존성 0개.** `SwiftData`·`Foundation`은 시스템 프레임워크. `SoozipLayout`에서 `CanvasAspect`만 가져온다.

- `SoozipApp.swift` 1줄 / `S2_CloudKitProbe.swift` 1줄 추가
- `Packages/` 3종 **영향 없음** — SwiftData를 패키지에 넣지 않으므로 Windows 빌드 가능성 유지
- 기존 앱 테스트 9개 영향 없음
- **타입 이름·필드 이름·관계 방향은 첫 심사 후 additive-only 제약을 받는다**

**Phase 2로 넘기는 것:** `collection(id:)` / `renderedPNG` 갱신 API / 사진 임포트(별도 `@ModelActor`) / 고아 `CanvasPhoto` 정리

## 구현 순서 (RGR 사이클 단위)

```
1.  모델 3종 + SoozipSchema                         (의존: 없음)   → AC-1,2,3,4,5
2.  ModelSchemaTests (제약 4종 + deleteRule 계약)     (의존: 1)      → AC-1,2,3,4,5
3.  RepositoryError + InputLimits                    (의존: 없음)   → AC-29/30 계약
4.  SyncStatusResolver                               (의존: 없음)   → AC-26,27,28
5.  CoverPolicy resolve/reconcile/isConsistent        (의존: 1)      → 표지 판정 + 불변식
6.  withLibrary 헬퍼 + 고정 Calendar/앵커             (의존: 1,5)    → 이후 전 단계의 전제
7.  모음집 CRUD·정렬                                  (의존: 3,6)    → AC-14,15,29,31
8.  createCanvas + 표지 재계산                        (의존: 5,7)    → AC-6,7,30,32
9.  updateCanvas (소속 미포함)                        (의존: 8)      → AC-30,32 갱신 경로
10. deleteCanvas + cascade                            (의존: 8)      → AC-8,9,10,17
11. deleteCollection + cascade 우회 경로 테스트         (의존: 10)     → AC-16
12. moveCanvas 양쪽 재계산                            (의존: 8)      → AC-11,12(개정),13
13. coverCanvas / canvases(in:order:)                 (의존: 5,8)    → AC-18, FR-6
14. StatsRepository (streakDays(now:) 포함)            (의존: 6)      → AC-19~25,25a,25b
15. SoozipApp·S2 컨테이너 분리 + xcodegen generate     (의존: 1)      → 회귀 방지
```

**병렬 가능:** 1·3·4 서로 무의존 / 2·5는 1 이후 / 14·15는 각각 6·1 이후 아무 때나. **9·10·12는 같은 파일이라 순차**, 11은 10 의존.

**초안 대비 변경점:** `saveCanvas` 단일 단계 → `createCanvas`/`updateCanvas`/`moveCanvas` 3단계 분리 / `purge` 구현 단계 삭제, cascade 우회 테스트 신설 / `ModelSchemaTests`를 2단계로 앞당김 / `withLibrary`에 불변식·autosave off 추가 / 14가 `streakDays(now:)` + AC-25a·25b 포함

**`xcodegen generate` 시점:** 1단계에서 파일이 생기는 즉시. 이후 파일 추가마다 반복.

**검증 명령:** `./scripts/test.sh`

---

## Testability 평가 (test-architect)

**Score: 8/10 — ✅ PASS** (아래 반영 조건 5건이 본 설계에 이미 반영된 상태 기준)

### 컴포넌트별 테스트 전략

| 컴포넌트 | 주입 지점 | 컨테이너 | 전략 |
|---|---|---|---|
| `CoverPolicy` | 없음 (순수 static) | **불필요** | **실측 — 미삽입 `@Model` 인스턴스의 속성 읽기·쓰기·관계 대입이 전부 동작.** 표지 AC 8건이 SwiftData·CloudKit과 완전 분리 |
| `SyncStatusResolver` | 값 2개 (Bool) | 불필요 | AC-26~28이 순수 값 테스트 3건 |
| `InputLimits`/`RepositoryError` | 없음 | 불필요 | 경계값(20/21자, 40/41자) 문자열만으로 |
| `SoozipSchema` + 모델 3종 | 없음 | 스키마만 | `Schema` 리플렉션으로 AC-1~4 기계 검증. AC-5는 컨테이너 삽입 |
| `LibraryRepository` | `init(context:)` + `now:` | 필요 | `withLibrary` — 고유 이름 인메모리, `cloudKitDatabase: .none`, `autosaveEnabled = false`, **종료 시 표지 불변식 자동 검증** |
| `StatsRepository` | `init(context:calendar:)` + `now:` | 필요 | 고정 timeZone Calendar + 고정 앵커에서 역산 |

### AC 커버리지

| AC | 검증 방식 |
|---|---|
| AC-1~4 | `Schema` 리플렉션 (attributes **및 relationships** 순회) |
| AC-5 | 무인자 생성 + `insert` + `fetchCount` |
| AC-6,7 / 8,9,10 / 11,12,13 | `createCanvas` / `deleteCanvas` / `moveCanvas` 후 `coverCanvasID` 대조 |
| AC-14,15 | `collections()` 순서 + `sortIndex` 값 |
| AC-16,17 | **`context.fetchCount(FetchDescriptor<T>())`로만.** `isDeleted` 금지 |
| AC-16 우회 | `context.delete(collection)` 직접 호출 → cascade 선언 계약 회귀 방지 |
| AC-18 | `coverCanvas(of:)` 반환값 + **`checksCoverInvariant: false`** (유일한 예외) |
| AC-19~23 | `StatsRepository` 카운트·요약 |
| AC-24,25,25a,25b | 고정 앵커 기준 상대일 캔버스 생성 |
| AC-26~28 | `SyncStatusResolver.mode` |
| AC-29,30 | `#expect(throws: RepositoryError.self)` + 케이스 대조 |
| AC-31,32 | 성공 경로 + 값 보존 대조 |
| **불변식** | AC 무관. **전 테스트 종료 시 자동** (AC-18 제외) |

### 반영 조건 5건 (전부 반영됨)

1. **AC-16/17은 `fetchCount`로만.** `isDeleted`는 `save()` 이후 `false`로 되돌아와 **위양성 테스트**가 된다 → 컨벤션 3번으로 명문화
2. **`reconcile`의 `resolve == nil` 동작 명시** — BR-4대로 `coverCanvasID = ""`. AC-12는 개정본 채택
3. **`withLibrary`에 `context.autosaveEnabled = false`** — 초안 주석("autosave가 꺼져 있다")은 **틀렸다**. 실측 `true`
4. **AC-4·AC-5 단언 신규 작성** + **AC-2는 `relationships`까지 순회** (관계에도 unique를 걸 수 있어 반쪽이었다)
5. **테스트 `Calendar`의 `timeZone`을 `Asia/Seoul`로 고정** + AC-21·24·25·25a·25b는 **고정 앵커**에서 역산

### 남은 2점의 위치

- **CloudKit 실동작 미검증** — S2 실기기 2대가 없어 동기화 경로는 어떤 테스트로도 닿지 않는다. 이번 설계는 그 사실을 인정하고 **모든 AC를 로컬에서 성립하도록** 짰다. 실기기 확인은 로드맵 게이트로 남는다.
- **`canvasesFetched`의 전량 fetch** — 관계 배열의 save-타이밍 비대칭을 피하려는 구조라 정합성에는 문제가 없지만 규모 테스트가 없다. P0 규모를 벗어나면 `Canvas.collectionID` 비정규화가 필요하고 그때 벤치마크가 붙어야 한다.

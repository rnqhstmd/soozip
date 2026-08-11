# Phase 6 — 모음집 화면 설계

- 작성일: 2026-08-11
- PRD: `.dev/feat-collection-screen/prd.md` (AC 28건)
- 규모: 대형 — 신규 12파일 내외, RGR 6사이클

## 1. 가장 중요한 제약 — 화면을 테스트할 수단이 없다

이 저장소의 테스트 204개는 **전부 로직 테스트**다. UI 테스트 타깃도, ViewInspector도, 스냅샷도 없다. 그런데 gx-tdd의 Iron Law는 실패 테스트 없이 코드를 쓰지 못하게 한다.

**해법: 표시할 값을 만드는 일과 그리는 일을 가른다.** 이 프로젝트가 이미 세 번 쓴 패턴이다 — `CoverPolicy`(순수 함수), `SyncStatusResolver`(순수 값 연산), `DraftMaintenance`(클로저 주입).

```
┌─ 테스트 대상 ────────────────────┐   ┌─ 테스트 밖 ──────────┐
│ CollectionCard      표시값 구조체 │   │ CollectionHomeView   │
│ CollectionPresenter 모델 → 표시값 │ → │ CollectionCarousel   │
│ DeletionPrompt      경고 문구     │   │ CollectionGridView   │
│ GhostHintPolicy     힌트 노출     │   │ CollectionDetailView │
│ LibraryRepository   쓰기          │   │ (그리기만)           │
└──────────────────────────────────┘   └──────────────────────┘
```

뷰는 **표시값을 받아 그리기만** 한다. 분기·계산·폴백이 뷰에 있으면 그만큼 테스트 밖으로 새는 것이므로, 뷰에 `if`가 늘면 설계가 틀린 신호다.

**이 전략이 덮지 못하는 것 (정직하게)**: "그 값이 실제로 화면에 그렇게 그려지는가"는 여전히 사람 눈이 봐야 한다. 레이아웃·제스처·애니메이션은 자동 검증 대상이 아니다. Phase 3에서 에디터가 붙어 실제 캔버스가 생기면 그때 수동 확인한다.

### Testability 평가

| 컴포넌트 | 단위 테스트 전략 | 격리 수단 | 점수 |
|---|---|---|---|
| `CollectionPresenter` | 모델 → 표시값 대조 | 인메모리 컨테이너 + 디코딩 판정 클로저 주입 | 9 |
| `CoverPolicy.designate` | 순수 함수 | 없어도 됨 | 10 |
| `LibraryRepository` 확장 | 기존 `withLibrary` 하네스 재사용 | 인메모리 + 불변식 자동 검사 | 9 |
| `DeletionPrompt` | 순수 값 | 없어도 됨 | 10 |
| `GhostHintPolicy` | 순수 값 | 닫힘 플래그 주입 | 10 |
| 초안 배너 판정 | 임시 폴더 하네스 재사용 | `withDraftStore` | 9 |
| SwiftUI 뷰 · 앱 루트 | **없음** | — | 2 |

**종합 8/10 — PASS** (기준 7). 뷰를 뺀 전 영역이 9 이상이고, 뷰가 2인 것은 전략상 의도된 결과다. 뷰에 로직이 없으면 2점 영역이 얇게 유지된다.

## 2. AC-28은 자동 검증이 불가능하다

"릴리스 빌드에 스파이크 진입 경로가 없다"는 `#if DEBUG` 컴파일 타임 분기인데, **테스트 자체가 DEBUG 빌드에서 돈다.** DEBUG에서 도는 테스트로 릴리스 산출물의 부재를 증명할 수 없다.

- 대응: `#if DEBUG` 사용을 코드 리뷰에서 눈으로 확인하고 trust-ledger에 위험 수용으로 기록한다
- 대안(채택 안 함): 릴리스 빌드 후 심볼 검사 — 이 규모에 과하다

## 3. 표지 — 디코딩 실패까지 테스트하려면 경계가 필요하다

AC-6은 "디코딩 불가능한 바이트면 단색으로 폴백"을 요구한다. `UIImage(data:)`를 프레젠터가 직접 부르면 순수성이 깨지고, 뷰가 부르면 AC-6을 테스트할 수 없다.

**디코딩 판정을 클로저로 주입한다.** `DraftMaintenance`가 조회 실패를 주입받은 것과 같은 이유·같은 형태다.

```swift
enum CoverArt: Equatable {
    case image(Data)   // 디코딩 가능이 **확인된** 데이터
    case empty         // 연한 단색 카드
}

struct CollectionCard: Equatable, Identifiable {
    let id: UUID
    let name: String
    let canvasCount: Int
    let cover: CoverArt
}

@MainActor
struct CollectionPresenter {
    let library: LibraryRepository
    /// 앱은 `{ UIImage(data: $0) != nil }`를 넘긴다.
    /// 테스트는 실패를 주입해 AC-6을 실제로 잰다.
    let canDecodeImage: (Data) -> Bool

    func cards() throws -> [CollectionCard]
    func card(for collection: Collection) throws -> CollectionCard
    func canvases(in: Collection, order: CanvasOrder) -> [Canvas]
}
```

표지 후보 선택은 **`CoverPolicy.resolve`를 그대로 쓴다** — 지정 → 최근 폴백이 이미 거기 있고, 세 번째 단계(단색)는 후보가 없거나 디코딩이 실패했을 때다.

## 4. 대표 캔버스 지정 — 컨벤션을 깨지 않는다

Phase 1이 못박은 것: **`coverCanvasID`에 대입하는 유일한 지점은 `CoverPolicy`다.** 근거는 대입 지점이 흩어지면 케이싱이 다른 값이 섞여 표지가 조용히 사라진다는 것이었다.

사용자 지정은 새 대입 경로를 요구하지만, **규약은 유지한다** — 지정도 `CoverPolicy` 안에서 일어난다.

```swift
extension CoverPolicy {
    /// 사용자가 대표를 직접 고른다. **대입은 여전히 여기서만 일어난다.**
    ///
    /// 후보에 없는 캔버스는 거부한다(BR-2). 다른 모음집의 캔버스가 표지가 되면
    /// 그것이 정확히 Phase 1이 불변식으로 막은 상태다 —
    /// "표지가 이 모음집에 없는 캔버스를 가리킨다".
    static func designate(_ canvas: Canvas, for collection: Collection,
                          candidates: [Canvas]) -> Bool
}
```

리포지토리가 후보를 fetch해 넘긴다:

```swift
func setCover(_ canvas: Canvas, of collection: Collection) throws
// 거부 시 RepositoryError.canvasNotInCollection(canvasID:collectionID:)
```

## 5. 리포지토리 확장 — 미뤄 뒀던 것이 호출부를 얻었다

Phase 1이 "호출부가 생길 때 만든다"고 미룬 둘이 이번에 필요해졌다.

```swift
func renameCollection(_ collection: Collection, to name: String) throws
func reorderCollections(_ ordered: [Collection]) throws
func setCover(_ canvas: Canvas, of collection: Collection) throws
```

- **`renameCollection`**: 길이 검증은 `createCollection`과 같은 규칙을 쓴다 — 검증을 한 곳으로 뽑아 두 경로가 어긋나지 않게 한다.
- **`reorderCollections`**: **보이는 순서 전체를 받는다.** 인덱스 이동(`from:to:`)이 아니라 배열을 받는 이유는 테스트가 기대 순서를 그대로 쓸 수 있고, `sortIndex`를 0..n-1로 다시 매기는 계약(BR-4)이 시그니처에 드러나기 때문이다. SwiftUI `onMove`는 뷰에서 배열을 재정렬해 넘긴다.
- **표지 재계산 없음**: 이름·순서 변경은 소속을 건드리지 않으므로 표지에 영향이 없다. `setCover`는 `CoverPolicy`가 직접 쓴다.

## 6. 초안 배너 — Phase 2와 같은 결함이 하나 더 남아 있다

`DraftStore.draft(forCollection:)`이 `==`로 비교한다. Phase 2에서 `pruneOrphans`만 정규화했고 이쪽은 그대로다.

```swift
try all().first { $0.meta.collectionID == collectionID }   // 대소문자 구분
```

**여기서는 데이터 손실이 아니라 "배너가 영영 안 뜬다"로 나타난다.** 증상이 조용해서 더 늦게 발견된다. AC-18이 이 경로를 직접 지나므로 같은 방식으로 정규화한다.

## 7. 삭제 경고 · 고스트 힌트 — 순수 값

```swift
enum DeletionPrompt: Equatable {
    case immediate                    // 캔버스 0장 — 즉시 삭제
    case warning(canvasCount: Int)    // N장 — 개수 명시 경고

    var message: String?              // 문구를 값이 들고 있어야 테스트가 잰다
    static func forCollection(canvasCount: Int) -> DeletionPrompt
}

struct GhostHintPolicy: Equatable {
    let hasDismissed: Bool            // 앱은 UserDefaults, 테스트는 직접 주입
    func shouldShow(collectionCount: Int) -> Bool
}
```

문구를 뷰가 아니라 값이 들고 있는 이유: AC-22가 "문구에 3이 포함된다"를 요구한다. 뷰에 두면 잴 수 없다.

## 8. 화면 구조

```
CollectionHomeView (앱 루트)
 ├─ CollectionCarousel        [+] 고정 + 카드 가로 스크롤
 │   └─ CollectionCardView    표지 / 이름 / 캔버스 수
 ├─ GhostHintOverlay          모음집 0개 + 미닫힘일 때만
 ├─ CollectionGridView        「전체 보기」 (같은 카드 재사용)
 ├─ CollectionEditSheet       생성 · 이름 변경
 └─ #if DEBUG SpikeMenu       S1 · S2 진입 (릴리스 미포함)

CollectionDetailView
 ├─ DraftBanner               초안 있을 때만
 ├─ CanvasGrid                최신순 / 오래된순 토글
 └─ [+]                       Phase 3 에디터 자리 (지금은 비활성)
```

**[+] 캔버스 추가는 이번 범위가 아니다.** 자리만 두고 비활성으로 남긴다 — 눌러서 아무 일도 안 일어나는 버튼보다 비활성이 정직하다.

## 9. 구현 순서 (RGR 사이클)

```
T1  리포지토리 확장 (rename · reorder · setCover) + CoverPolicy.designate   → AC-8~13
T2  CollectionCard + Presenter (표지 폴백 3단계)                            → AC-1~7, 14
T3  상세 표시값 (캔버스 정렬) + 초안 배너 판정 + 케이싱 정규화              → AC-15~19
T4  DeletionPrompt                                                          → AC-22~24
T5  GhostHintPolicy                                                         → AC-25~27
T6  SwiftUI 뷰 + 앱 루트 교체 + DEBUG 스파이크 진입점                       → AC-20·21·28 (뷰는 테스트 밖)
```

**T1~T5가 테스트로 덮이고, T6은 배선이다.** T6에 로직이 흘러들면 그만큼 검증 밖으로 새므로, T6에서 새 분기가 필요해지면 T1~T5로 되돌려 보낸다.

**검증 명령**: `./scripts/test.sh` (현재 204개) · 파일 추가 시 `xcodegen generate`

## 10. 이번 설계가 만들지 않는 것

| 항목 | 이유 |
|---|---|
| `CollectionViewModel` (ObservableObject) | `@Query`가 SwiftData 갱신을 이미 밀어준다. 상태 컨테이너를 하나 더 두면 두 출처가 어긋난다 |
| 표지 이미지 캐시 | 실측 없이 넣는 최적화다. Phase 3에서 실제 `renderedPNG`가 생기면 그때 측정하고 판단한다 |
| 검색·탭 셸·에디터 진입·뷰어 | 각각 Phase 8·8·3·7 |

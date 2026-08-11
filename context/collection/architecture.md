# collection 아키텍처

> 전체 구조 요약과 주제별 상세 문서 링크를 관리합니다.

## 시스템 구조

```
CollectionHomeView (탭1, 앱 첫 화면)
 ├─ CollectionCarousel        가로 스크롤 · 맨 좌측 [+] 고정
 │   └─ CollectionCard        표지(대표 캔버스 썸네일) + 이름 + 캔버스 수
 ├─ CollectionGridView        「전체 보기」
 ├─ CollectionEditSheet       생성 · 이름 변경
 └─ SearchView                모음집 이름 + 캔버스 제목 통합 검색

CollectionDetailView
 ├─ CanvasGrid                최신순 / 오래된순
 ├─ DraftBanner               "이어서 만들까요?"
 └─ [+] → canvas 도메인으로 위임
```

## 데이터 모델

**Phase 1에서 구현 완료.** 전체 모델과 CloudKit 제약은 [sync 아키텍처](../sync/architecture.md)에 있다.

```swift
@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0

    /// 여기에 직접 대입하지 마라 — 유일한 대입 지점은 `CoverPolicy.reconcile`이다.
    var coverCanvasID: String = ""      // 비면 가장 최근 캔버스

    @Relationship(deleteRule: .cascade, inverse: \Canvas.collection)
    var canvases: [Canvas]? = []

    init() {}
}
```

**`coverCanvasID`를 관계가 아니라 문자열로 둔 이유**: `Collection → Canvas` 관계가 이미 있는데 대표 캔버스로 관계를 하나 더 걸면 CloudKit에서 순환 참조 구성이 까다로워진다. UUID 문자열이면 대상이 사라져도 빈 값 취급으로 안전하게 폴백된다.

**대입 지점을 `CoverPolicy` 하나로 좁힌 이유**: `UUID.uuidString`은 대문자를 내는데 `UUID(uuidString:)`은 소문자도 받는다. 비교가 대소문자를 구분하므로 대입 지점이 흩어지면 케이싱이 다른 값이 섞여 **표지가 조용히 사라진다.**

## 표지 계산 규칙

```
coverCanvasID 가 비어 있지 않고 && 그 캔버스가 이 모음집에 존재하면
    → 그 캔버스의 renderedPNG                        (유지 규칙이 최신 우선을 이긴다)
아니면 가장 최근 캔버스가 있으면
    → 그 캔버스의 renderedPNG                        (createdAt 최대, 동률이면 id)
아니면
    → 연한 단색 카드 + 이름                           (coverCanvasID = "")
```

**`id`를 2차 키로 쓰는 이유**: `createdAt`이 같은 캔버스가 둘이면 결과가 배열 순서에 의존하는데, SwiftData의 to-many 순서는 보장되지 않아 같은 데이터에서 표지가 실행마다 바뀐다.

**재계산이 필요한 시점** — 이 셋을 빠뜨리면 표지가 사라진 캔버스나 남의 모음집 캔버스를 가리킨다.
1. 캔버스 저장(승격) 시 — 모음집이 비어 있었다면 이 캔버스를 대표로
2. 캔버스 삭제 시 — 대표였다면 비우고 최근 캔버스로 승계
3. **캔버스를 다른 모음집으로 이동 시 — 양쪽 모두 재계산**

### 표지 불변식 — 개별 규칙보다 위에 있는 것

```
coverCanvasID 가 비어 있거나, 그것이 이 모음집에 실제로 있는 캔버스를 가리킨다
```

**개별 규칙은 우리가 아는 경로만 막지만 불변식은 아직 짜지 않은 경로까지 막는다.** 실제로 초안 설계의 업서트가 요구사항 어디에도 안 걸리면서 아래를 만들어 냈다:

```
A 표지=C1, B 표지=(빈값)
→ C1을 A에서 B로 "저장"(소속 변경 포함)
→ A 표지=C1인데 A의 캔버스 수=0     ← 불변식 위반
```

그래서 소속을 바꾸는 경로를 **`moveCanvas` 하나로 좁혔고**, 테스트 하네스가 매 테스트 종료 시 전 모음집의 불변식을 검사한다.

### 재계산의 순서가 고정돼 있다

```
변경 → save() → 재계산 → save()
```

관계 배열이 `save()` 전까지 삭제·이동을 반영하지 않기 때문이다(실측). **"save 두 번을 하나로 합치자"는 평범한 리팩터가 곧 유령 표지를 만든다.** 자세한 내용은 [SwiftData 실측](../sync/swiftdata-measured.md) §1.

## 정렬

- 기본은 `createdAt` 오름차순 = 생성 순서
- 새 모음집의 `sortIndex`는 **기존 최댓값 + 1**이라 재배치 전에도 정렬 조회만으로 생성 순서가 성립한다
- 사용자가 드래그로 재배치하면 `sortIndex`를 다시 매긴다 (Phase 6)
- **두 기기에서 동시에 재배치해 `sortIndex`가 중복되면 `createdAt` 오름차순으로 타이브레이크**

## 리포지토리 API (Phase 1 완료)

```swift
@MainActor struct LibraryRepository {
    // 모음집
    func createCollection(name: String, now: Date) throws -> Collection
    func collections() throws -> [Collection]
    func deleteCollection(_ collection: Collection) throws

    // 캔버스 — 소속 변경은 moveCanvas 하나뿐이다
    func createCanvas(_ input: CanvasInput, in collection: Collection, now: Date) throws -> Canvas
    func updateCanvas(_ canvas: Canvas, title: String, createdAt: Date,
                      layoutJSON: Data, now: Date) throws
    func deleteCanvas(_ canvas: Canvas) throws
    func moveCanvas(_ canvas: Canvas, to destination: Collection) throws

    // 조회 — 읽기 전용. DB를 고치지 않는다
    func canvases(in collection: Collection, order: CanvasOrder = .newestFirst) -> [Canvas]
    func coverCanvas(of collection: Collection) -> Canvas?
}
```

- 이름 1~20자·제목 0~40자를 **리포지토리가 강제 거부한다** — UI 이전의 최후 방어선
- 중복 이름은 허용한다. 사용자가 같은 이름을 원할 수 있고 `@Attribute(.unique)`는 CloudKit에서 못 쓴다
- `updateCanvas`가 `renderedPNG`를 받지 않는다 — 수 MB 블롭이라 제목만 고치는 호출에서 재대입되면 CKAsset이 통째로 재업로드된다

## 주제 문서

| 주제 | 설명 |
|------|------|
| (없음) | 필요 시 추가 |

## 참조

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §2, §4

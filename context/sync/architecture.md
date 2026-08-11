# sync 아키텍처

## 저장소 두 곳

```
SwiftData + CloudKit (동기화됨)
 ├─ Collection      모음집
 ├─ Canvas          저장 확정된 캔버스
 └─ CanvasPhoto     사진 원본 2000px (복제 레이어들이 공유)

Application Support/Drafts/  (로컬 전용, 동기화 안 됨)
 └─ <canvas-uuid>/
     ├─ layout.json
     └─ photos/
```

## 전체 모델

**Phase 1에서 구현 완료** (`Soozip/Data/Models/`). 아래는 실제 코드다 — 특히
`@Relationship` 선언과 `init()`은 **장식이 아니라 계약**이라 빼면 동작이 바뀐다.

```swift
@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var coverCanvasID: String = ""

    // 역관계는 Canvas.collection 쪽에만 선언한다.
    // 양쪽에 걸면 SwiftData가 관계를 두 개로 보고 스키마 구성에서 죽는다.
    @Relationship(deleteRule: .cascade, inverse: \Canvas.collection)
    var canvases: [Canvas]? = []

    init() {}   // 전 속성에 기본값이 있어도 iOS 26 SDK가 요구한다
}

@Model final class Canvas {
    var id: UUID = UUID()
    var aspect: Int = 0
    var title: String = ""
    var createdAt: Date = Date()      // 기록 날짜 — 사용자가 정한다
    var updatedAt: Date = Date()      // 저장 시각 — 시스템이 정한다
    var layoutJSON: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \CanvasPhoto.canvas)
    var photos: [CanvasPhoto]? = []

    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: Collection?

    init() {}
}

@Model final class CanvasPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data = Data()
    var canvas: Canvas?

    init() {}
}
```

**`deleteRule: .cascade`가 AC-16·17을 지탱하는 유일한 계약이다.** 초안 설계의 수동
`purge`는 실측으로 근거가 무너져 철회했다 — 자세한 내용은 [SwiftData 실측](swiftdata-measured.md) §4.

**모델 목록은 `SoozipSchema.models` 하나에서 온다.** 앱 배선·테스트 컨테이너·스키마
검사가 같은 목록을 봐야 하며, 세 곳이 각자 배열을 들면 한 곳만 빠졌을 때 관계가
통째로 깨지는데 증상이 컴파일이 아니라 런타임에야 나온다.

## CloudKit 제약 체크리스트

`SoozipTests/ModelSchemaTests.swift`가 리플렉션으로 자동 검증한다(AC-1~5). 선언을
어기면 테스트가 먼저 빨개진다.

- [x] 전 속성이 기본값을 갖거나 optional인가
- [x] `@Attribute(.unique)`를 쓰지 않았는가 — 속성과 **관계** 양쪽 확인
- [x] 모든 관계가 양방향 optional인가
- [x] 배열 속성을 피했는가 (`sortIndex` Int, `coverCanvasID` String)
- [ ] 첫 심사 전에 프로덕션 스키마를 배포했는가 — Phase 9
- [ ] **실기기 2대 동기화 확인** — 하드웨어 대기 (S2)

## 리포지토리 계층

**Phase 1에서 구현 완료** (`Soozip/Data/Repository/`). UI 없이 단위 테스트만으로
완성되는 계층이다.

```
LibraryRepository (@MainActor)      모음집·캔버스 CRUD, 이동, 조회
 └─ CoverPolicy                     표지 판정·재계산·불변식 (순수 함수)
StatsRepository (@MainActor)        통계 5종. Calendar 주입
SyncStatusResolver                  로컬 모드 격하 판정 (순수 값 연산)
```

- **모음집과 캔버스를 한 리포지토리에 묶었다.** 표지 정합성이 두 모델에 걸친
  불변식이라, 모델별로 쪼개면 불변식이 두 타입의 *협력*에 걸리고 그 협력을
  빠뜨린 경로가 곧 사고가 된다.
- **`@MainActor`인 이유**: `ModelContext`와 `@Model`이 non-Sendable이라 액터 경계를
  넘지 못한다. 메인 액터 고정이면 모델을 그대로 반환할 수 있어 Phase 6의 `@Query`와
  마찰이 없다. 무거운 쓰기(Phase 2의 사진 블롭)는 그때 별도 `@ModelActor`로 뗀다.
- **`SyncStatusResolver`는 CloudKit 타입을 받지 않는다.** `CKAccountStatus`를 그대로
  받으면 검증에 실제 iCloud 계정이 필요해진다. 두 신호를 `Bool`로 좁혀 판정을 순수
  값 연산으로 만들고, 실제 조회는 어댑터 한 겹 밖으로 밀었다.

**의도적으로 만들지 않은 것** — 호출부가 생길 때 만든다:
`purge` · `addPhoto` · `collection(id:)` · `renameCollection` · `reorderCollections` ·
`ICloudAccountStatusProviding`. 특히 `addPhoto`를 안 만든 덕에 **블롭을 다루는
메서드가 리포지토리에 없어**, Phase 2가 이 타입을 건드리지 않고 별도 사진 임포터를
붙일 수 있다.

## `layoutJSON` — 확장 통로

```json
{
  "v": 1,
  "canvas": { "w": 1080, "h": 1350 },
  "background": { "color": "#FFFFFF" },
  "layers": [ /* photo · text · shape · stamp · drawing */ ]
}
```

**레이어 스펙이 아무리 늘어도 CloudKit 스키마는 그대로다.** v4에서 `shape` 레이어 9종, 폰트 5종, z-order 재정렬이 추가됐지만 DB 스키마 변경은 0건이었다. v2가 "레이어를 한 덩어리로 묶는다"고 확정해둔 것이 여기서 값을 한다.

## 충돌 정책

| 상황 | 정책 | 상태 |
|---|---|---|
| 같은 캔버스를 두 기기에서 편집 | **LWW, 판정 시점 = 저장 버튼.** 편집 중에는 초안이 로컬이라 아무것도 안 올라간다 | ⬜ Phase 2 |
| 모음집 순서 동시 변경 | `sortIndex` 중복 시 `createdAt` 오름차순 타이브레이크 | ✅ `collections()` |
| 대표 캔버스가 다른 기기에서 삭제됨 | `coverCanvasID` 대상이 없으면 빈 값 취급 → 최근 캔버스로 폴백 | ✅ `CoverPolicy.resolve` |
| 편집 중이던 모음집이 다른 기기에서 삭제됨 | 저장 시점에 존재 확인 → 없으면 "어디에 저장할까요?" | ⬜ Phase 2 |

**폴백은 조회 시점에 일어나고 DB를 고치지 않는다.** `coverCanvas(of:)`는 읽기
전용이다 — 조회가 슬쩍 쓰면 `@Query`가 도는 화면에서 스크롤만 해도 쓰기가 발생한다.

**`sortIndex` 타이브레이크가 정렬에만 있는 게 아니다.** 캔버스 목록과 표지 판정도
`createdAt`이 같을 때 `id`를 2차 키로 쓴다. SwiftData의 to-many 순서는 보장되지
않아, 2차 키가 없으면 같은 데이터에서 결과가 실행마다 바뀐다.

## 로컬 모드 격하

```
iCloud 미로그인 · 용량 초과 감지
  → 로컬 모드로 자동 전환 (앱은 정상 동작)
  → 설정 > 데이터에 상태 배너
  → 초안은 원래 로컬이라 영향 없음
```

**판정은 하나로 통합한다**(`SyncStatusResolver`, ✅ Phase 1). 두 신호는 알 수 있는
시점이 다르다 — 계정 상태는 앱 구동·주기 확인 시점에, 용량 초과는 실제 저장이
실패한 시점(`CKError.quotaExceeded`)에 온다. 그래도 호출부가 사유별로 분기할 일이
없고, 사유 구분이 필요한 곳은 설정 배너 문구뿐이라 Phase 9 몫이다.

기본값은 낙관적이다(`accountAvailable: true`) — 앱이 뜨자마자 배너를 띄우면 계정
조회가 끝나기도 전에 사용자를 놀라게 한다.

## 초안 정리

앱 시작 시 `Drafts/`를 스캔해 아래를 삭제한다.
- 소속 모음집이 존재하지 않는 폴더
- 7일 이상 방치된 폴더

정리하지 않으면 사진 사본이 계속 쌓여 사용자가 원인을 알 수 없는 용량을 먹는다.

## 주제 문서

| 주제 | 설명 |
|------|------|
| [SwiftData 실측](swiftdata-measured.md) | 문서로 알 수 없어 직접 재현한 동작 10건. **설계 초안의 가정을 뒤집은 것들** |
| (예정) | S2 스파이크 결과가 나오면 「CloudKit 동기화 실측」 추가 |

## 참조

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §6.2, §7, §8

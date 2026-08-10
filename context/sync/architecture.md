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

```swift
@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var coverCanvasID: String = ""
    var canvases: [Canvas]? = []
}

@Model final class Canvas {
    var id: UUID = UUID()
    var aspect: Int = 0
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()
    var photos: [CanvasPhoto]? = []
    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: Collection?
}

@Model final class CanvasPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data = Data()
    var canvas: Canvas?
}
```

## CloudKit 제약 체크리스트

- [ ] 전 속성이 기본값을 갖거나 optional인가
- [ ] `@Attribute(.unique)`를 쓰지 않았는가
- [ ] 모든 관계가 양방향 optional인가
- [ ] 배열 속성을 피했는가 (`sortIndex` Int, `coverCanvasID` String)
- [ ] 첫 심사 전에 프로덕션 스키마를 배포했는가

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

| 상황 | 정책 |
|---|---|
| 같은 캔버스를 두 기기에서 편집 | **LWW, 판정 시점 = 저장 버튼.** 편집 중에는 초안이 로컬이라 아무것도 안 올라간다 |
| 모음집 순서 동시 변경 | `sortIndex` 중복 시 `createdAt` 오름차순 타이브레이크 |
| 대표 캔버스가 다른 기기에서 삭제됨 | `coverCanvasID` 대상이 없으면 빈 값 취급 → 최근 캔버스로 폴백 |
| 편집 중이던 모음집이 다른 기기에서 삭제됨 | 저장 시점에 존재 확인 → 없으면 "어디에 저장할까요?" |

## 로컬 모드 격하

```
iCloud 미로그인 · 용량 초과 감지
  → 로컬 모드로 자동 전환 (앱은 정상 동작)
  → 설정 > 데이터에 상태 배너
  → 초안은 원래 로컬이라 영향 없음
```

## 초안 정리

앱 시작 시 `Drafts/`를 스캔해 아래를 삭제한다.
- 소속 모음집이 존재하지 않는 폴더
- 7일 이상 방치된 폴더

정리하지 않으면 사진 사본이 계속 쌓여 사용자가 원인을 알 수 없는 용량을 먹는다.

## 주제 문서

| 주제 | 설명 |
|------|------|
| (없음) | S2 스파이크 결과가 나오면 「CloudKit 동기화 실측」 추가 예정 |

## 참조

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §6.2, §7, §8

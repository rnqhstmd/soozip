# canvas 아키텍처

## 생명주기

```
        [+]                  [완료]              [편집]
없음 ──────→ 초안(Draft) ──────→ 저장됨 ⇄ 초안(재편집)
             │  ↑ 자동 임시저장     │            │
             │  └─ 1.5초 디바운스   │            └ [취소] → 원본 유지
             └─ [나가기] → 3지선다  └ [삭제] → 확인 → 소멸
```

## 초안 저장소

```
Application Support/
└── Drafts/
    └── <canvas-uuid>/
        ├── layout.json          ← 1.5초 디바운스로 갱신
        └── photos/
            ├── <asset-id>.jpg   ← 삽입 즉시 기록 (디바운스 제외)
            └── ...
```

- **CloudKit 동기화 대상이 아니다.** 로컬 전용
- 모음집당 1개만 유지. 다른 캔버스를 새로 만들려 하면 "이어서 / 버리고 새로"를 묻는다
- 앱 시작 시 스캔해 **소속 모음집이 없거나 7일 초과된 폴더를 삭제**한다

## 저장(승격) 트랜잭션

```
1. 검증        레이어 상한 · 사진 슬롯 · 손상 레이어 제거
2. 렌더        ImageRenderer(scale 1.0) → renderedPNG   ※ autoreleasepool
3. 사진 이관    Drafts/ 사본 → CanvasPhoto (2000px, externalStorage)
4. DB 쓰기     Canvas 삽입(또는 갱신) + Collection 연결 + updatedAt
5. 표지 갱신    Collection.coverCanvasID 가 비어 있으면 이 캔버스로
6. 정리        Drafts/<uuid>/ 폴더 삭제
7. 실패 시     draft 폴더를 그대로 두고 재시도 안내
```

**2~5가 전부 성공해야 6을 실행한다.** 순서를 바꾸면 저장 실패 시 작업물이 증발한다.

## 재편집

```
뷰어 [편집]
  → layoutJSON 로드 → 새 초안 세션 시작   ※ 원본 Canvas는 이 시점부터 저장 전까지 불변
  → [저장] → 위 트랜잭션 (4번이 갱신, renderedPNG 재생성)
  → [취소] → 초안 폐기, 원본 그대로
```

**저장 시점에 제거된 사진 레이어의 `CanvasPhoto`를 정리한다.** 고아 레코드가 externalStorage 용량을 계속 먹는다.

## 데이터 모델

```swift
@Model final class Canvas {
    var id: UUID = UUID()
    var aspect: Int = 0                 // 0 = 4:5(1080×1350), 1 = 9:16(1080×1920)
    var title: String = ""
    var createdAt: Date = Date()        // 사용자가 지정하는 기록 날짜
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()
    var photos: [CanvasPhoto]? = []
    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: Collection?
}
```

**`aspect`를 Int 열거값으로 둔 이유**: 폭·높이를 직접 저장하면 프리셋을 추가할 때 기존 데이터의 유효성을 재검증해야 한다. 열거값은 앱 상수 테이블을 갈아 끼우면 끝난다.

## 삭제 규칙

| 대상 | 확인 | 처리 |
|---|---|---|
| 캔버스 | "이 캔버스를 삭제할까요?" | `CanvasPhoto` cascade → 대표였으면 표지 승계 |
| 초안 | "만들던 캔버스를 삭제할까요?" | 폴더 삭제 |

## 주제 문서

| 주제 | 설명 |
|------|------|
| (없음) | 필요 시 추가 |

## 참조

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §3, §6, §7

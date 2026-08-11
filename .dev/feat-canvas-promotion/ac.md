# CANVAS-1·2 — 승격 트랜잭션 + 단계별 실패 주입

- 작성일: 2026-08-11
- 로드맵: `docs/plans/2026-08-11-00-tdd-roadmap-v1.md` (canvas 도메인)
- 설계 SSOT: v4 §6.6 (승격 트랜잭션 7단계)
- 브랜치: `feat/canvas-promotion` (base `main`)

## 배경

초안(`Drafts/<uuid>/`)을 저장 확정된 `Canvas` 레코드로 바꾸는 경로다. **이 도메인의 한 줄 약속은 "작업물이 절대 증발하지 않는다"이고, 이 단위가 그 약속의 전부다.**

v4 §6.6의 7단계:

```
1. 검증        레이어 상한 · 사진 슬롯 · 손상 레이어 제거
2. 렌더        ImageRenderer → renderedPNG
3. 사진 이관    Drafts/ 사본 → CanvasPhoto (externalStorage)
4. DB 쓰기     Canvas 삽입 + Collection 연결
5. 표지 갱신    coverCanvasID가 비어 있으면 이 캔버스로
6. 정리        Drafts/<uuid>/ 폴더 삭제
7. 실패 시      draft 폴더를 그대로 두고 사용자에게 알린다
```

**2~5가 전부 성공해야 6을 실행한다.** 순서를 바꿔 초안을 먼저 지우면 저장 실패 시 작업물이 증발한다.

### 이미 있는 것 — 새로 만들지 않는다

| 단계 | 쓸 것 | 어디 |
|---|---|---|
| 1 검증 | `LayoutDocument.validate()` → `LayoutViolation?` | `SoozipLayout` |
| 3 사진 | `DraftStore.photoIDs` · `readPhoto` | `SoozipDraft` |
| 4 DB | `LibraryRepository.createCanvas` | Phase 1 |
| 5 표지 | `createCanvas`가 이미 `CoverPolicy`로 재계산 | Phase 1 |
| 6 정리 | `DraftStore.delete` | `SoozipDraft` |

**없는 것은 2단계 렌더러 하나뿐이다.** 실제 렌더는 `MEDIA-3`이고 에디터 표면에 딸려 있어 지금 만들 수 없다.

### 렌더러를 주입받는다

`(LayoutDocument) throws -> Data` 클로저로 받는다. 이 저장소가 이미 세 번 쓴 패턴이다 — `DraftMaintenance`의 조회 실패, `CollectionPresenter`의 디코딩 판정, `SyncStatusResolver`의 계정 신호.

**주입이 아니면 CANVAS-2를 만들 수 없다.** 2단계 실패를 주입할 방법이 없으면 "렌더가 실패해도 초안이 남는가"를 잴 수 없고, 그게 이 단위의 존재 이유다.

## 요구사항

- FR-1: 초안을 `Canvas` 레코드로 승격한다. 7단계를 v4 §6.6 순서대로 수행한다.
- FR-2: 초안 폴더 삭제(6단계)는 **2~5가 전부 성공한 뒤에만** 실행한다.
- FR-3: 어느 단계에서 실패하든 **초안 폴더를 그대로 둔다.**
- FR-4: 레이어 상한을 넘으면 승격을 거부한다. 무엇이 몇 개 넘었는지 호출부가 알 수 있어야 한다.
- FR-5: 사진 레이어가 참조하는 원본을 `CanvasPhoto`로 옮긴다. **복제 레이어가 같은 `assetId`를 공유하면 `CanvasPhoto`는 하나만 만든다.**

## 수용 기준

### 성공 경로

- **AC-1**: Given 사진 2장과 텍스트 1개를 가진 초안이 모음집 A에 있을 때, When 승격하면, Then `Canvas` 1건이 A에 생기고 `renderedPNG`가 렌더러 결과와 같다.
- **AC-2**: Given 같은 상황에서, When 승격이 성공하면, Then 초안 폴더가 삭제된다.
- **AC-3**: Given 캔버스가 0장인 모음집 A의 초안일 때, When 승격하면, Then A의 `coverCanvasID`가 그 캔버스가 된다.
- **AC-4**: Given 초안의 `layoutJSON`이 있을 때, When 승격하면, Then `Canvas.layoutJSON`이 초안의 것과 바이트 단위로 같다.
- **AC-5**: Given 초안의 기록 날짜가 미래일 때, When 승격하면, Then 그 날짜가 보정 없이 보존된다.

### 사진 이관 (FR-5)

- **AC-6**: Given 사진 원본 2개를 가진 초안일 때, When 승격하면, Then `CanvasPhoto` 2건이 생기고 각 `data`가 초안 원본과 같다.
- **AC-7**: Given 사진 1장을 3번 복제해 레이어 4개가 **같은 `assetId`를 공유하는** 초안일 때, When 승격하면, Then `CanvasPhoto`는 **1건만** 생긴다.

### 검증 실패 (FR-4)

- **AC-8**: Given 사진 레이어가 9개인 초안일 때, When 승격을 시도하면, Then `photoLimitExceeded(count: 9, limit: 8)`로 거부되고 `Canvas`가 생기지 않는다.
- **AC-9**: Given 같은 상황에서, When 승격이 거부되면, Then **초안 폴더가 그대로 남는다.**

### 단계별 실패 주입 — 이 단위의 핵심 (FR-2·3)

- **AC-10**: Given 정상 초안이 있고 **렌더러(2단계)가 실패**할 때, When 승격을 시도하면, Then 던지고 초안 폴더가 남으며 `Canvas`가 생기지 않는다.
- **AC-11**: Given 정상 초안이 있고 **사진 읽기(3단계)가 실패**할 때, When 승격을 시도하면, Then 던지고 초안 폴더가 남으며 `Canvas`·`CanvasPhoto`가 생기지 않는다.
- **AC-12**: Given 정상 초안이 있고 **DB 쓰기(4단계)가 실패**할 때, When 승격을 시도하면, Then 던지고 초안 폴더가 남는다.
- **AC-13**: Given 정상 초안이 있고 **초안 삭제(6단계)가 실패**할 때, When 승격을 시도하면, Then **`Canvas`는 남는다.** 정리 실패는 저장을 되돌릴 이유가 아니다 — 고아 초안은 다음 실행의 `pruneOrphans`가 치운다.

### 소속

- **AC-14**: Given 초안의 `collectionID`가 존재하지 않는 모음집을 가리킬 때, When 승격을 시도하면, Then 거부되고 초안 폴더가 남는다.

## 범위 밖

- **실제 렌더러** — `MEDIA-3`. 여기서는 주입받는다
- **재편집 승격**(기존 `Canvas` 갱신) — `CANVAS-6`
- **제거된 사진 레이어의 `CanvasPhoto` 정리** — `CANVAS-8`
- 저장 시트·완료 화면·나가기 3지선다 — `CANVAS-10`
- 백그라운드 완주 — `CANVAS-12`

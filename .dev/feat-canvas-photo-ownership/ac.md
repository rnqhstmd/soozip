# CANVAS-3 — 사진 이관의 소유 관계

- 작성일: 2026-08-11
- 로드맵: `docs/plans/2026-08-11-00-tdd-roadmap-v1.md` (canvas 도메인)
- 브랜치: `feat/canvas-photo-ownership` (base `main`)
- 모드: 핵심(core) / 표준 프로파일

## 배경

로드맵의 `CANVAS-3`은 "**사진 이관** — `Drafts/` 사본 → `CanvasPhoto`, `assetId` 공유 유지"다.

**이관 자체는 `CANVAS-1`에서 이미 끝났다.** 승격 트랜잭션 3단계가 사진을 읽고,
`assetId` 기준으로 중복을 없애고, `CanvasPhoto.id`에 그 값을 그대로 옮긴다.
바이트 동일성(AC-6)·중복 제거(AC-7)·레이어↔사진 되짚기까지 테스트가 덮는다.

**덮이지 않은 것은 소유다 — 어느 사진이 어느 캔버스 것인가.**

### 무엇이 구멍인가

`CanvasPhoto`를 보는 테스트가 **전부 전역 조회**다:

| 테스트 | 조회 방식 |
|---|---|
| `사진_원본이_CanvasPhoto로_옮겨진다` | `context.fetch(FetchDescriptor<CanvasPhoto>())` |
| `같은_assetId를_공유하는_복제_레이어는_...` | `context.fetchCount(...)` |
| `레이어의_assetId로_그_레이어의_사진을_찾을_수_있다` | `context.fetch(...)` |
| `LibraryRepositoryTests`의 cascade 3건 | `fetchCount(...)` — **관계를 테스트가 직접 건다** |

마지막 줄이 핵심이다. cascade 테스트들은 `photo.canvas = canvas`를 손으로 걸어 두고
삭제를 재므로, **`CoverPolicy` 계약은 재지만 승격 경로가 그 관계를 거는지는 안 잰다.**

그래서 `CanvasPromoter.attach`에서 `record.canvas = canvas` 한 줄을 지워도
**254개가 전부 초록이다.** (이 브랜치에서 실제로 지워 확인했다.)

### 지워지면 무슨 일이 일어나는가

- **cascade가 안 닿는다.** 주인 없는 `CanvasPhoto`는 캔버스를 지워도, 모음집을 지워도
  남는다. `@Attribute(.externalStorage)`라 실제 파일이 계속 쌓인다
- **`canvas.photos`가 빈다.** 재편집(`CANVAS-6`)·재렌더가 사진을 못 찾는다
- **보상 삭제가 헛돈다.** `attach` 실패 시 `deleteCanvas`가 cascade로 사진을 치우는
  전제인데, 관계가 없으면 캔버스만 사라지고 블롭이 남는다

지난번 `assetId` 연결 끊김과 **같은 종류의 결함, 같은 종류의 사각지대**다 — 집합
비교와 개수 비교는 연결을 못 본다.

## 요구사항

- FR-1: 승격이 만든 `CanvasPhoto`는 그 캔버스에 속한다. 관계는 **승격 경로가** 건다.
- FR-2: 캔버스가 여럿일 때 각 캔버스는 자기 사진만 갖는다.
- FR-3: 승격으로 만든 캔버스를 지우면 그 사진도 함께 사라진다 (cascade가 닿는다).

## 수용 기준

- **AC-1**: Given 사진 2장을 가진 초안을 승격했을 때, When `canvas.photos`를 보면,
  Then 그 2장이 들어 있고 각 `photo.canvas`가 그 캔버스를 가리킨다.
- **AC-2**: Given 서로 다른 사진을 가진 초안 둘을 각각 승격했을 때, When 각
  캔버스의 `photos`를 보면, Then **자기 사진만** 있고 상대의 것은 없다.
- **AC-3**: Given 승격으로 만든 캔버스(사진 2장)를 지웠을 때, When `CanvasPhoto`를
  세면, Then **0건이다** — 승격이 건 관계를 타고 cascade가 닿는다.

## 범위 밖

- 사진 이관 자체(바이트 동일성·중복 제거·`assetId` 연결) — `CANVAS-1`에서 완료
- **제거된 사진 레이어의 `CanvasPhoto` 정리** — `CANVAS-8`
- 재편집 시 사진 공유 정책 — `CANVAS-6`

## 코드 맵: EDITOR-5 — 핸들 히트 판정

### 핵심 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` → **이 단위의 입력 전체.** `Handle`(corner/edge/rotate/delete) · `PlacedHandle(handle:position:)` · `Box`(코너 4 비옵셔널 + `edgeHandles: [PlacedEdge]` + `rotate` + `rotateFlipped`) · `orderedHandles`(**히트 우선순위 순서** — `.delete` → 코너 TL·TR·BR·BL → `.rotate` → `edgeOrder`) · 상수 `rotateGap 28` · `flipThreshold 40` · `edgeOrder [.top,.right,.bottom,.left]`. **모든 좌표가 화면 pt다**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift` → `toScreen`/`toLogical`/`scale`/`fitScale`/`zoom`(private(set))/`zoomed(to:)`/`centered(on:)`. 히트 판정 입력이 이미 화면 좌표라 **44pt가 줌과 무관해지는 근거**
- `Packages/SoozipLayout/Sources/SoozipLayout/SelectionHandles.swift` → `LayerStore.selectionHandles(on:baseSizeOf:)`. 배치를 얻는 **유일한 안전 경로**(`edges` 매개변수가 없음)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift` → `Corner`·`Edge`(+`sign`)·`LayerFrame`(`corner`/`edgeMidpoint`/`toLocal`/`toWorld`)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/Vec2.swift` → `Vec2`·`Size2`(`shortSide`/`longSide`)

### 참조 파일
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/HandlePlacementTests.swift` → 픽스처 관례(`표면()` = canvas 1080×1350 / viewport 540×700 → fitScale 0.5, `isClose(abs<0.01)`). **EDITOR-4가 확정한 이진 정확 픽스처를 그대로 재사용**
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:269` → §5.7 "핸들의 시각 크기는 12pt지만 **히트 영역은 44×44pt**(Apple HIG 최소치). 시각 크기를 44pt로 키우면 캔버스가 핸들로 뒤덮인다"
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:345` → §5.9 "줌 상태에서도 핸들의 화면상 크기는 일정하다 — 화면 오버레이 레이어에 그린다"
- `docs/plans/2026-08-11-00-tdd-roadmap-v1.md:118` → `EDITOR-5` 정의 + 의존(EDITOR-4). `EDITOR-6`이 이 위에 얹힘
- `context/editor/glossary.md` → **히트 영역**(시각 12pt와 별개로 44×44pt) · **히트 우선순위**(삭제 ✕가 좌상단 코너와 같은 지점이라 순서가 필요) — EDITOR-4에서 추가
- `context/editor/architecture.md` → `SelectionOverlay`가 화면 좌표계에 산다

### 설정
- `.claude/config.json` → `swift-ios`, test = `./scripts/test.sh`, warningPattern = `warning:`
- `scripts/test.sh` → SPM 3종 + 앱 타깃 + Release 빌드
- `project.yml` → XcodeGen 정의

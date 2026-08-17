## 코드 맵: EDITOR-7 — 리사이즈 (대각 고정점 + 하한 40 / 상한 캔버스 긴 변 ×4)

### 핵심 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift:6` → `resized(draggingCorner:to:minShortSide:maxLongSide:)` — 로컬 좌표에서 대각 고정 후 회전 보정. **이 단위의 주 대상**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift:58` → `resized(draggingEdge:to:minShortSide:maxLongSide:)` — 한 축만 변경. `LayerKind`를 보지 못해 `photo` 금지를 자체 강제 못 함(이월 항목)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift:94` → `clamped(width:height:minShortSide:maxLongSide:)` — 하한 조건이 `shortSide > 0`이라 **0이면 클램프 전체를 스킵**(이월 ASSUMPTION)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift:53` → `LayerFrame`(center·size·rotation) + `toLocal`/`toWorld`/`corner`/`edgeMidpoint`. `Corner.sign`·`opposite`, `Edge.sign`·`opposite`·`isHorizontal`
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/ResizeAnchorTests.swift:9` → 기존 7건. `minSide=40`, `maxSide=7680`(주석: 캔버스 긴 변 1920×4). 회전은 0과 π/4만 관측 — **90°는 미관측**

### 참조 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift:18` → `canvas`는 1080×1350(4:5) 또는 1080×1920(9:16). **상한 ×4의 피승수 출처**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/Vec2.swift:31` → `Size2.shortSide`/`longSide` — 하한·상한 판정 축
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` → 코너를 화면 밖으로 22pt 미는 `screenCorner`. **밀린 좌표를 논리로 되돌리면 22pt÷scale씩 튄다**(EDITOR-6 이월)
- `Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift` → mutating API가 `select`/`deselect`/`insert`/`remove`/z-order 4종뿐. **transform 쓰기 경로 부재**(EDITOR-4·5·6이 3회 이월)
- `Packages/SoozipLayout/Sources/SoozipLayout/SelectionHandles.swift` → `LayerKind.resizableEdges` 문지기. `photo`·`stamp`·`drawing` 빈 집합, `text` 좌우, `shape` 네 변
- `docs/plans/2026-08-11-00-tdd-roadmap-v1.md:120` → EDITOR-7 정의(의존 EDITOR-4)
- `context/editor/status.md:28` → "크기 하한 40px · 상한 캔버스 긴 변 ×4 — **값 주입은 EDITOR-7**"

### 설정
- `.claude/config.json` → `swift-ios`(test `./scripts/test.sh`, build `xcodebuild ... -scheme Soozip`)
- `Packages/SoozipGeometry/Package.swift` → Foundation 전용(CoreGraphics·SwiftUI 금지)

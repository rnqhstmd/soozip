## 코드 맵: EDITOR-8 — 회전 (15° 단위 스냅 · ±3° 흡착)

### 핵심 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/SnapEngine.swift:5` → `SnapKind`가 `alignment`/`equalSpacing`/`sizeMatch` 3종. **회전이 없다**(status.md:49가 지목한 빈틈). `SnapCandidate`가 `axis`(수평/수직) + `value` 구조라 **회전각을 담을 자리가 구조적으로 없다** — 이 단위의 첫 설계 결정점
- `Packages/SoozipGeometry/Sources/SoozipGeometry/SnapEngine.swift:37` → `isAxisAligned` = `abs(f.rotation) < 0.0001`. **정규화가 없다** — `rotation = 2π`(한 바퀴)면 시각적으로 축 정렬인데 후보에서 제외된다. 회전 단위가 각도를 누적시키면 이 판정이 먼저 무너진다
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift:56` → `public var rotation: Double // 라디안`. **값 범위 제약이 전혀 없다**(생성자에 정규화·유한성 검사 없음)
- `Packages/SoozipLayout/Sources/SoozipLayout/Layer.swift:40` → `LayerTransform.rotation`(라디안) — 저장·복원 경로. 회전 결과가 최종적으로 앉는 자리
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift:189` → `up = Vec2(x: sin(r), y: -cos(r))` — 회전 핸들 배치가 `rotation`을 읽는 유일한 소비처. 뒤집기 판정(`up.y <= 0`)이 각도에 의존

### 참조 파일
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/SnapEngineTests.swift:8` → 기존 9건 + `frame(x:y:...)` 픽스처. `회전된_레이어는_후보에서_제외된다`가 이미 회전 축을 관측 중
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift:74` → EDITOR-7의 **진입 가드 + 결과 가드** 2단 패턴. 비유한 입력이 public API 밖으로 나가면 `JSONEncoder`가 던져 문서 저장이 실패한다는 것이 그 단위의 결론
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift:130` → `frame.rotation.isFinite` 가드 선례. **비유한 `rotation`의 라이브 도달 경로를 EDITOR-7이 찾지 못하고 이월했다** — 회전 단위가 그 경로를 만들 수 있다
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:308` → 회전 15° 단위(0°·15°·30°…) + **각도 배지 표시**
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:317` → **±3° 흡착** · 임계 8pt는 화면 좌표(회전엔 무관) · enter 이벤트만 발화 · 동시 다중 히트에도 햅틱 1회
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:327` → 회전 스냅 햅틱은 `selection`
- `context/editor/status.md:49` → "회전 15° 스냅 (±3°) — `EDITOR-8` — `SnapKind`에 없다"

### 설정
- `.claude/config.json` → `swift-ios` (test `./scripts/test.sh`, build `xcodebuild ... -scheme Soozip`)
- `Packages/SoozipGeometry/Package.swift` → **Foundation 전용** (CoreGraphics·SwiftUI 금지 — Windows 빌드 유지)
- `Packages/SoozipLayout/Package.swift` → `SoozipLayout → SoozipGeometry` 단방향. `SoozipGeometry`는 `CanvasAspect`·`LayerKind`를 볼 수 없다

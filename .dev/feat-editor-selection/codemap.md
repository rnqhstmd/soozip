## 코드 맵: EDITOR-4 — 선택 상태 + 바운딩 박스

### 핵심 파일
- `Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift:36` → `Entry(id:layer:)` UUID 식별자 + 삽입/삭제/z-order 4종. **선택 식별자의 출처** — 주석이 "`EDITOR-4`가 선택 대상을 고를 때 낡은 z를 보면 맨 아래를 최상단으로 고른다"고 이미 경고
- `Packages/SoozipLayout/Sources/SoozipLayout/Layer.swift:150` → `LayerKind` 5종 판별자 + `category`. **변 핸들 3분할이 붙을 자리** (인스턴스 없이 판정하는 기존 패턴)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift:3` → `Corner`(sign·opposite), `LayerFrame.corner`/`toLocal`/`toWorld`. 바운딩 박스 네 꼭짓점 산출
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift:3` → `Edge` 4종 + `resized(draggingEdge:)`. **타입 제약이 없는 지점** — photo도 변 리사이즈가 가능한 상태
- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift:92` → `toScreen`/`toLogical`/`scale`. 핸들을 화면 좌표에 배치할 때의 입력 (줌 무관 크기 고정)

### 참조 파일
- `Packages/SoozipLayout/Sources/SoozipLayout/LayoutDocument.swift:64` → `LayerCategory`(limit·reportingOrder). 단일 출처 패턴의 선례
- `Packages/SoozipLayout/Tests/SoozipLayoutTests/LayerStoreTests.swift` → 스토어 테스트 스타일 (한글 함수명, `#expect`)
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/ResizeAnchorTests.swift` → 리사이즈 테스트 스타일
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/LayerFrameTests.swift` → 코너·회전 테스트 스타일
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:244` → §5.7 선택 UI 원본 스펙 (핸들 표·겹침 방지·회전 핸들 뒤집기)
- `docs/plans/2026-08-11-00-tdd-roadmap-v1.md` → EDITOR-4 단위 정의 + 의존 관계 (EDITOR-5·6·7·8이 이 위에 얹힘)
- `context/editor/architecture.md` → `SelectionOverlay` 계층 위치 + 크기별 핸들 표시 규칙

### 설정
- `.claude/config.json` → `swift-ios` 타입, test = `./scripts/test.sh`, warningPattern = `warning:`
- `scripts/test.sh` → SPM 3종(`swift test`) + 앱 타깃(`xcodebuild test`) + Release 빌드
- `project.yml` → XcodeGen 프로젝트 정의

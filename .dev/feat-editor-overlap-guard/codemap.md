## 코드 맵: EDITOR-6 — 핸들 겹침 방지

### 핵심 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` → **이 단위가 유일하게 바꾸는 프로덕션 파일이 될 가능성이 높다.** `init(frame:edges:on:)`(`:66-120`)가 코너 4·`edgeHandles`·`rotate`를 화면 좌표로 만든다. 크기 축 필터가 얹힐 자리. 상수 `rotateGap 28` · `flipThreshold 40` · `edgeOrder`. `Box.corner(_:)`·`delete`(= `topLeft`) · `orderedHandles`(히트/그리기 순서) · `edges`(= `edgeHandles` 파생)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandleHitTest.swift` → `hitSize = 44`(internal). **88 = 2×44**(두 히트 사각형이 나란히 들어가는 최소 폭)이라 임계값의 근거가 여기 있다. `hitCandidates`가 `orderedHandles`를 필터하므로 **변 핸들을 숨기면 히트 후보에서도 자동으로 빠진다**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift` → `Corner`(+`sign`·`opposite`) · `Edge`(+`sign`·`opposite`·`isHorizontal`) · `LayerFrame`(`corner`/`edgeMidpoint`/`toLocal`/`toWorld`). **코너를 박스 밖으로 미는 방향은 `Corner.sign`에서 나온다**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/Vec2.swift` → `Size2.shortSide`(`min(w,h)`) · `longSide`. **"짧은 변"의 기존 표현이 이미 있다 — 두 벌을 만들지 말 것**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift` → `toScreen`/`scale`/`fitScale`/`zoom`/`zoomLimits (0.5, 4.0)`. **88/56pt를 화면 pt로 재려면 `size × surface.scale`이 판정 입력이다**
- `Packages/SoozipLayout/Sources/SoozipLayout/SelectionHandles.swift` → `LayerStore.selectionHandles(on:baseSizeOf:)` · `LayerKind.resizableEdges`(**종류 축 문지기**). 크기 축이 얹히면 두 축이 합쳐지는 지점

### 참조 파일
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/HandlePlacementTests.swift` → `표면()`(fitScale **0.5**) · `π조사표면()`(fitScale 0.3611 × zoom 2 = **0.7222**). `orderedHandles는_삭제_코너_회전_변_순서다_변_4개`(`:232`) · 코너 좌표 리터럴 다수
- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/HandleHitTestTests.swift` → EDITOR-5의 픽스처 A~G 27건. 대부분 200×100 · 40×40
- `Packages/SoozipLayout/Tests/SoozipLayoutTests/SelectionTests.swift` → `표면()`이 canvas == viewport(**fitScale 1.0**)라 `toScreen`이 항등. `:223`·`:232`의 `placement.edges` 리터럴 단언
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:270` → §5.7 "**핸들 겹침 방지.** 짧은 변 < 88pt면 변 핸들을 먼저 숨기고, < 56pt면 코너를 박스 바깥으로 밀어낸다. 안쪽에 그리면 핸들끼리 붙어 어느 것을 잡았는지 알 수 없다"
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:272` → §5.7 `EDITOR-5` 콜아웃 — 44pt 사각형·겹침 승자 규칙·줌 무관
- `docs/plans/2026-08-11-00-tdd-roadmap-v1.md:120` → `EDITOR-6` 정의 + 의존(EDITOR-5)
- `context/editor/glossary.md` → 「핸들 배치」·「히트 영역」·「히트 우선순위」·「후보 목록」
- `.dev/feat-editor-hit-testing/design.md` → §1-h **"`EDITOR-6`이 코너를 밀어내면 `Box.delete = { topLeft }` 전제가 깨지고 FR-3의 nil 분기가 도달 가능해지는 동시에 무테스트가 된다. 그 전이는 어떤 테스트도 실패시키지 않는다"** — 이 단위가 받는 인계
- `.dev/feat-editor-hit-testing/trust-ledger.md` → EDITOR-6 수신 항목 3건

### 설정
- `.claude/config.json` → `swift-ios`, test = `./scripts/test.sh`, build = `xcodebuild build -scheme Soozip -destination 'generic/platform=iOS Simulator'`, warningPattern = `warning:`
- `scripts/test.sh` → SPM 3종 + 앱 타깃 + Release 빌드
- `project.yml` → XcodeGen 정의

### setup 단계에서 실측한 영향 범위 (임계값을 **화면 pt**로 볼 경우)

| 픽스처 | 논리 크기 | scale | 화면 짧은 변 | 88 | 56 |
|---|---|---|---|---|---|
| SoozipGeometry `표면()` 기본 | 200×100 | 0.5 | **50** | 미만 | **미만** |
| HandleHitTest D | 40×40 | 0.5 | **20** | 미만 | **미만** |
| HandleHitTest F 줌 50% | 200×100 | 0.25 | **25** | 미만 | **미만** |
| `π조사표면()` | 200×100 | 0.7222 | **72.2** | 미만 | 이상 |
| HandleHitTest E | 400×400 | 0.5 | 200 | 이상 | 이상 |
| HandleHitTest F 줌 400% | 200×100 | 2.0 | 200 | 이상 | 이상 |
| SelectionTests (전부) | 100×100 | 1.0 | **100** | 이상 | 이상 |

**⚠️ EDITOR-5 설계서 §2-c의 예측이 틀렸다.** "`EDITOR-6` 이후 `SelectionTests:223`·`:232`가 깨져야 정상"이라고 적혀 있으나, 그 픽스처는 `fitScale 1.0` · 100×100이라 **짧은 변이 100pt로 두 임계값 위**다. 깨지지 않는다. 대신 깨지는 것은 **`SoozipGeometry` 쪽 다수**다.

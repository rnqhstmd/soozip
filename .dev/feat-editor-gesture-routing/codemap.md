## 코드 맵: EDITOR-10 제스처 라우팅 (팬/줌/드래그 배타를 순수 상태 기계로)

### 핵심 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift:16` → 논리↔화면 변환. `zoom`(0.5~4.0)·`center`·`workArea`·`clampedToWorkArea`·`zoomed`/`centered`/`fitted`. **제스처가 바꾸는 상태의 본체** — 팬/줌은 전부 이 값을 갱신한다
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandleHitTest.swift:17` → `HandleGesture`(tap/drag) + `accepts` 필터 + `hitCandidates`/`hitHandle`. **기존 제스처 어휘의 유일한 선례** — EDITOR-10의 새 상태 기계가 이 타입과 어긋나면 배선에서 두 어휘가 충돌한다
- `Packages/SoozipLayout/Sources/SoozipLayout/LayerStore.swift` → `selection`/`select`/`deselect`. **우선순위 표의 행을 가르는 입력**(선택 있음 vs 없음)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerCenterClamp.swift` → `clampedLayerCenter(_:)`. **호출 강제 게이트의 대상**(6번째 연속 이월)
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift` → 이동·리사이즈·회전이 바꾸는 대상 모델(`center`·`size`·`rotation`)

### 참조 파일
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift` → 코너 드래그의 대각 고정점. 드래그가 레이어로 라우팅됐을 때의 수신자
- `Packages/SoozipGeometry/Sources/SoozipGeometry/RotationSnap.swift` → 15° 스냅. 두 손가락 회전의 수신자. **판정 본체는 도(degree)**
- `Packages/SoozipGeometry/Sources/SoozipGeometry/SnapEngine.swift` → 드래그 중 정렬·간격 가이드. 임계는 화면 8pt
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` → 핸들 배치. 화면 좌표계
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerBoundary.swift` → `overlap(canvas:)` 겹침 3분류(EDITOR-9)
- `Soozip/Spikes/S1_GestureProbe.swift:63` → 팬/줌/드래그를 SwiftUI로 얽어 놓은 **유일한 실물**. `.gesture(drag).gesture(magnify)`로 겹쳐 달고 `guard selected == nil`로 가르는 방식 — EDITOR-10이 대체할 대상. EDITOR-11에서 파일 삭제 예정
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:349` → §5.9 우선순위 표 SSOT (+ §5.10 경계, `:275` 히트 우선순위 부작용 노트)

### 설정
- `.claude/config.json` → `projectTypes.swift-ios` (test=`./scripts/test.sh`, build=`xcodebuild`)
- `project.yml` → XcodeGen. 새 타입 추가 시 SPM 타깃 경로 규약
- `Packages/SoozipGeometry/Package.swift` → Foundation 전용 의존(Windows 빌드 유지)

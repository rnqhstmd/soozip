## 코드 맵: Phase 1 데이터 레이어 (Collection · Canvas · CanvasPhoto + 리포지토리)

### 핵심 파일
- `Soozip/Data/Models/` → **아직 없음.** Phase 1이 여기에 정식 모델 3종을 만든다
- `Soozip/Data/Repository/` → **아직 없음.** 쿼리 · 표지 재계산 3지점 · sortIndex 타이브레이크
- `Soozip/Spikes/S2_CloudKitProbe.swift:12-46` → CloudKit 제약을 검증받은 프로브 모델. **Phase 1의 정식 모델이 이걸 대체하고 Phase 0 Task 8에서 삭제된다.** `@Model`이 `init()`을 요구한다는 사실을 여기서 확인했다
- `Soozip/App/SoozipApp.swift:10` → `.modelContainer(for:)` 배선 지점. 정식 모델로 교체 대상
- `Packages/SoozipLayout/Sources/SoozipLayout/LayoutDocument.swift:8-28` → `CanvasAspect` (post=0 / story=1). **`Canvas.aspect`의 Int raw value가 이 enum과 짝**이라 값을 바꾸면 기존 캔버스가 깨진다

### 참조 파일
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §7 → 모델 3종 정의 · §7.1 설계 판단 · §7.2 CloudKit 제약
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §6.7~6.9 → 표지 재계산 3지점 · sortIndex 타이브레이크 · cascade
- `context/sync/architecture.md:48-54` → CloudKit 제약 체크리스트 5항
- `context/collection/status.md` → 표지 폴백 3단계 · 표지 재계산 3지점 추적
- `context/canvas/status.md` → Canvas 모델 · cascade 추적
- `Packages/SoozipDraft/Sources/SoozipDraft/DraftStore.swift:60-120` → 초안 저장소. Phase 2 승격 트랜잭션이 이쪽에서 모델로 넘긴다
- `SoozipTests/CGInteropTests.swift` → 앱 타깃 테스트 작성 스타일 (Swift Testing `@Test`/`#expect`)

### 설정
- `project.yml` → 타깃 구성. **파일을 추가하면 `xcodegen generate`를 돌려야 프로젝트가 인식한다**
- `.claude/config.json` → `projectTypes.swift-ios.test = ./scripts/test.sh` (verify 게이트가 쓰는 명령)
- `scripts/test.sh` → 패키지 90 + 앱 9 통합 실행

### 주의 (Phase 0에서 확인된 것)
- **`@Model`은 `init()`을 명시해야 한다.** 모든 속성에 기본값이 있어도 매크로가 만들어 주지 않는다. v4 §7 스니펫에는 없으므로 그대로 옮기면 컴파일 실패
- **CloudKit 실기기 2대 동기화는 미검증**(S2 보류). 모델 형태와 `ModelContainer` 초기화만 시뮬레이터에서 확인됨

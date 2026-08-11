phase: review
status: in_progress
pipeline: gx-tdd
verify-status: pending
verify-fingerprint: ""
model-profile: standard
mode: all
intent-source: user-selection
vcs-type: git
branch: feat/collection-screen
base: main
project-type: swift-ios
project-root: ./
args: "phase6시작"
flags: ""
started: 2026-08-11T01:35:00
warnings-baseline: 0
current-step: "phase-review"
phases:
  setup: completed
  requirements: completed
  design: completed
  implement: completed
  review: in_progress
  complete: pending
steps:
  requirements:
    - PRD 작성: completed
    - G-W-T 게이트: completed (AC 28건)
  design:
    - 설계 + testability 평가: completed (8/10 PASS)
  implement:
    - "RGR T1 리포지토리 확장 + CoverPolicy.designate": { red: completed, green: completed, refactor: completed, test-count: 213 }
    - "RGR T2 카드 표시값 + 표지 폴백": { red: completed, green: completed, refactor: skipped (대상 없음), test-count: 223 }
    - "RGR T3 상세 정렬 + 초안 배너 + 케이싱": { red: completed, green: completed, refactor: completed, test-count: 230 }
    - "RGR T4 삭제 경고": { red: completed, green: completed, refactor: skipped, test-count: 234 }
    - "RGR T5 고스트 힌트": { red: completed, green: completed, refactor: skipped, test-count: 237 }
    - "RGR T6 SwiftUI 뷰 + 앱 루트 + DEBUG 진입점": completed (test-count: 237, 뷰는 테스트 밖)
execution-log:
  - phase: setup
    result: "에이전트 디스패치 없이 오케스트레이터가 직접 수행 — Phase 1 T3에서 사용자가 거부한 이력을 따름. 게이트와 Iron Law는 유지"
  - phase: requirements
    gate: G-W-T
    result: "PASS — AC 28건 전부 Given/When/Then 3절 + 구체 검증값"
  - phase: requirements
    decision: "앱 루트를 모음집 화면으로 교체하되 스파이크는 #if DEBUG 진입점으로 유지 — 로드맵이 측정 전 삭제를 금지했고 릴리스에 실려서도 안 된다"
  - phase: requirements
    decision: "탭 셸은 만들지 않는다 — 탭 하나짜리 TabView는 의미가 없고 호출부가 생길 때 만든다는 원칙을 따른다. Phase 8이 탭2와 함께 세운다"
  - phase: design
    gate: testability
    result: "PASS 8/10 — 뷰를 뺀 전 영역이 9 이상. 뷰가 2인 것은 '표시값과 그리기를 가른다' 전략의 의도된 결과"
  - phase: design
    decision: "표지 디코딩 판정을 클로저로 주입 — UIImage를 프레젠터가 직접 부르면 순수성이 깨지고 뷰가 부르면 AC-6을 잴 수 없다. DraftMaintenance와 같은 형태"
  - phase: design
    decision: "대표 지정도 CoverPolicy 안에서 대입 — Phase 1의 '대입 지점은 CoverPolicy뿐' 컨벤션을 유지한다"
  - phase: design
    finding: "DraftStore.draft(forCollection:)에 Phase 2와 같은 케이싱 결함 잔존. 여기서는 데이터 손실이 아니라 '초안 배너가 영영 안 뜸'으로 나타난다 — T3에서 처리"
  - phase: design
    result: "AC-28(릴리스에 스파이크 미포함)은 자동 검증 불가 — #if DEBUG는 컴파일 타임이고 테스트는 DEBUG에서 돈다. 코드 리뷰 확인 + 위험 수용 기록으로 대체"
  - phase: implement
    result: "T1 완료 — rename/reorder/setCover + CoverPolicy.designate + canvasNotInCollection. 9개 추가로 213개 통과(앱 122), 회귀 0건"
  - phase: implement
    result: "T2 완료 — CoverArt/CollectionCard/CarouselItem + CollectionPresenter. 10개 추가로 223개 통과(앱 132), 회귀 0건"
  - phase: implement
    decision: "[+]를 CarouselItem의 케이스로 둔다 — 뷰가 알아서 앞에 붙이게 하면 '맨 좌측 고정'이 테스트 밖 규칙이 된다"
  - phase: implement
    decision: "card(for:)는 던지지 않는다 — 표시 경로라 조회 실패를 빈 목록으로 접는다. 던지면 @Query가 도는 화면마다 오류 처리가 번진다"
  - phase: implement
    result: "T3 완료 — canvases(in:order:) 위임 + DraftBannerPolicy. 케이싱 결함 실제 재현 후 draft(forCollection:) 정규화(패키지 테스트 포함). 230개"
  - phase: implement
    result: "T3 REFACTOR — withDraftStore를 TestContainer 공용으로 이동(두 파일이 쓴다)"
  - phase: implement
    result: "T4·T5 완료 — DeletionPrompt + GhostHintPolicy. 둘 다 순수 값이라 문구와 노출 판정을 값이 들고 있다. 237개(앱 145), 소스 경고 0건"
  - phase: implement
    result: "T6 완료 — CollectionHomeView/GridView/DetailView/EditSheet/CardView + SpikeMenu(#if DEBUG) + 앱 루트 교체. 빌드 성공, 237개 유지, 소스 경고 0건"
  - phase: implement
    result: "시뮬레이터 실측으로 레이아웃 결함 1건 수정 — 고스트 힌트가 화면 정중앙 오버레이라 [+] 카드와 떨어져 무엇을 가리키는지 읽히지 않았다. 캐러셀 아래 흐름으로 이동"
  - phase: implement
    decision: "캐러셀 드래그 재배치 대신 「전체 보기」의 List.onMove로 먼저 구현 — 가로 스크롤 드래그 재정렬은 SwiftUI 기본 도구로 불가. UX가 v4와 다르므로 후속 과제로 기록"
  - phase: implement
    decision: "생성 후 상세 자동 진입은 보류 — 진입 직후 할 일이 캔버스 추가(Phase 3)라 지금 넣으면 빈 화면으로 떨어진다"
  - phase: review
    result: "보안 감사 — 삭제(방어됨: 개수 명시 확인 + cascade)와 이미지 디코딩(방어됨: 프레젠터가 미리 거름) 둘이 실질 위험. 네트워크·자격증명·역직렬화 표면 없음"
next-task:
  id: phase-complete
  step: RED
  scope: "verify 게이트 → 인수 검증 → PR"
  notes: "모음집이 있는 상태의 화면은 사람이 한 번 만져 봐야 한다 — 시뮬레이터 탭 수단이 없어 빈 상태만 확인했다"
  verify-command: "./scripts/test.sh  # 237개 (패키지 92 + 앱 145)"

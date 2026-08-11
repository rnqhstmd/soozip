phase: implement
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
current-step: "RGR T6: 뷰 배선"
phases:
  setup: completed
  requirements: completed
  design: completed
  implement: in_progress
  review: pending
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
    - "RGR T6 SwiftUI 뷰 + 앱 루트 + DEBUG 진입점": pending
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
next-task:
  id: T6
  step: RED
  scope: "SwiftUI 뷰 + 앱 루트 교체 + DEBUG 스파이크 진입점"
  ac: "AC-20·21·28 (뷰 자체는 테스트 밖)"
  spec: ".dev/feat-collection-screen/design.md §8"
  notes: "T1~T5가 표시값을 전부 만들어 뒀다. T6에서 새 분기가 필요해지면 그만큼 검증 밖으로 새는 것이므로 T1~T5로 되돌려 보낸다. AC-28은 자동 검증 불가 — 위험 수용 기록 예정"
  verify-command: "./scripts/test.sh  # 현재 237개 (패키지 92 + 앱 145)"

phase: implement
status: in_progress
pipeline: gx-tdd
verify-status: pending
verify-fingerprint: ""
model-profile: standard
mode: all
intent-source: user-selection
vcs-type: git
branch: feat/data-layer
base: main
project-type: swift-ios
project-root: ./
args: "phase1 구현 시작 — 데이터 레이어 (Collection · Canvas · CanvasPhoto + 리포지토리)"
flags: ""
started: 2026-08-10T22:40:00
last-known-head: 4a86c4217708ee430fe5333c3d51b24e3b0b0689
auto-stashed: false
config-setup-attempts: 1
warnings-baseline: 0
current-step: "RGR T5: RED"
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
    - G-W-T 게이트: completed
  design:
    - 설계 초안: completed
    - 비판 검토: completed
    - testability 평가: completed (8/10 PASS)
  implement:
    - 기준선 게이트: completed
    - 태스크 분해 승인: completed
    - "RGR T1 (AC-1~5) 모델+스키마": { red: completed, green: completed, refactor: completed, test-file-hash: d9acf17c45751d7a05879ac9d307c8dd17cfeb53 (REFACTOR 후 갱신), test-count: 113 }
    - "RGR T2 CoverPolicy": { red: completed, green: completed, refactor: completed, test-file-hash: dc7ed87139e34b7b19eb01064f9f0ba0d52fe698, test-count: 122 }
    - "RGR T3 SyncStatusResolver+Error": { red: completed, green: completed, refactor: skipped (대상 없음), test-count: 137 }
    - "RGR T4 하네스+모음집CRUD": { red: completed, green: completed, refactor: skipped, test-count: 146 }
    - "RGR T5 캔버스 생성·갱신": { red: completed, green: completed, refactor: completed, test-count: 159 }
    - "RGR T6 삭제+cascade": { red: completed, green: completed, refactor: skipped (대상 없음), test-count: 167 }
    - "RGR T7 이동+조회": { red: completed, green: completed, refactor: completed, test-count: 178 }
    - "RGR T8 StatsRepository": pending
    - "RGR T9 앱 배선": pending
    - 변경사항 수집: pending
  review:
    - mechanical-gate: pending
    - spec-review (1단계): pending
    - quality-review + security (2단계 병렬): pending
  complete:
    - verify-gate: pending
    - 인수검증: pending
execution-log:
  - phase: setup
    result: "베이스 main (단일 후보 자동 선택), 브랜치 feat/data-layer 생성"
  - phase: setup
    result: "프로젝트 타입 swift-ios — project.yml이 힌트 카탈로그의 Ceedling과 충돌해 인라인 등록으로 해결"
  - phase: setup
    result: "context/*/PROJECTS.md 6개의 낡은 레포 경로(D:\\SQ\\moumzip) 갱신 — 도메인 컨텍스트 매칭 복구"
  - phase: setup
    result: "도메인 컨텍스트 로드: sync(모델·CloudKit 제약·충돌 정책) · collection · canvas"
  - phase: requirements
    agent: product-owner
    result: "PRD 초안 — AC 30건 전부 G-W-T. 확인 사항 5건 제시"
  - phase: requirements
    decision: "sortIndex = 기존 최댓값+1 (재배치 전에도 생성 순서 보장)"
  - phase: requirements
    decision: "연속 기록 = 오늘 저장이 없어도 어제까지 이어진 연속 유지"
  - phase: requirements
    decision: "가장 많이 담은 모음집 동률 = createdAt 오름차순(먼저 생성된 쪽)"
  - phase: requirements
    decision: "이름 1~20자·제목 0~40자를 리포지토리가 강제 거부 (UI 이전의 최후 방어선)"
  - phase: requirements
    decision: "로컬 모드 격하 = 미로그인/용량초과 통합 판정 하나로"
  - phase: requirements
    gate: G-W-T
    result: "PASS — AC 32건 전부 Given/When/Then 3절 + 구체 검증값, 모호 표현 0건"
  - phase: requirements
    result: "FR-8 문구 오류 정정 — '소속 모음집의 사진' → '그 캔버스에 속한 사진' (AC-17과 어긋나 있었음)"
  - phase: requirements
    result: "PRD 사용자 승인 완료. .dev/feat-data-layer/prd.md 저장"
  - phase: implement
    agent: architect
    result: "설계 초안 — 규모 대형. 신규 15파일(모델 4·리포지토리 5·테스트 6), 구현 순서 13단계. 확인 사항 4건"
  - phase: implement
    decision: "타입 이름 Collection/Canvas 유지 — 타입명이 곧 CloudKit 레코드 타입명이라 심사 후 개명 불가. 문서·코드 일치 우선"
  - phase: implement
    decision: "동시성 경계 = @MainActor struct — Phase 6 @Query와 마찰 없음. Phase 2 승격만 나중에 @ModelActor로 분리"
  - phase: implement
    decision: "리포지토리 = LibraryRepository 단일 + StatsRepository 분리 — 표지 불변식을 한 타입에 가둔다(QE-2)"
  - phase: implement
    decision: "연속 기록 미래 날짜 = BR-9 문언대로 포함 — streakDays()가 now를 참조하지 않아 실행 시점 독립"
  - phase: implement
    agent: design-critic
    result: "MUST-ADDRESS 5 / CONSIDER 6. 프로브 실행으로 검증 — QE-2 사고를 saveCanvas 업서트로 실측 재현. 근본 원인을 '불변식 미선언'으로 재정의"
  - phase: implement
    agent: test-architect
    result: "Testability 8/10 ✅ PASS. AC 커버리지 누락 4건(AC-4·AC-5·AC-12·QE-2). 구현 착수 전 반영 조건 5건"
  - phase: implement
    gate: testability
    result: "PASS (8/10 ≥ 7) — Iron Law 통과"
  - phase: implement
    result: "실측 반증 3건 — ①cascade 단독 동작함(purge 존치 근거 무효) ②isDeleted는 save 후 false로 복귀(fetchCount 필수) ③ModelContext는 autosave 켜져 있음"
  - phase: implement
    decision: "연속 기록 결정 번복 — streakDays(now:)로 변경. 미래 날짜 제외 + 유예 1일. BR-9 개정, AC-25a·25b 신설"
  - phase: implement
    decision: "AC-12 전제 개정 — A에 표지 C4 + 비표지 C3 두 장. 원안은 FR-7과 모순이라 테스트 작성 불가였음"
  - phase: implement
    result: "경고 기준선 측정 — 앱 0건, 패키지 3종 0건. RGR 진입 전 baseline 확보"
  - phase: implement
    agent: architect
    result: "설계 최종본 — MUST-ADDRESS 5·CONSIDER 6·testability 조건 5 전부 반영. purge 철회(cascade 단독), saveCanvas 3분할, streakDays(now:), 불변식 자동 검증. 구현 15단계"
  - phase: implement
    result: "design-draft.md 삭제 — design.md 단일 출처 유지 (반증된 초안 가정은 design.md에 기록됨)"
  - phase: design
    result: "설계 사용자 승인 완료. design.md 저장 (신규 15·수정 3파일, 15단계, Testability 8/10)"
  - phase: implement
    agent: red-writer (T1)
    result: "ModelSchemaTests 14개 작성 + RED 확인(cannot find in scope). 격리 준수 — 프로덕션 Read 0건"
  - phase: implement
    agent: green-coder (T1)
    result: "모델 3종 + SoozipSchema 최소 구현. 앱 배선은 YAGNI로 T9 이월. 113개 통과, 회귀 0건"
  - phase: implement
    agent: refactor-coder (T1)
    result: "테스트 중복 2건 추출(soozipSchema/makeInMemoryContext). 프로덕션 정리 대상 없음. GREEN 유지 113개"
  - phase: implement
    agent: red-writer (T2)
    result: "CoverPolicyTests 9개. 타이브레이크 테스트가 배열 순서 의존 구현을 못 잡아 1회 보완 요구 → 두 순서 모두 검증하도록 수정"
  - phase: implement
    agent: green-coder (T2)
    result: "CoverPolicy 30줄 최소 구현. 122개 통과, 회귀 0건"
  - phase: implement
    agent: refactor-coder (T2)
    result: "테스트 중복 1건 추출(makeCollection). 프로덕션 정리 대상 없음"
  - phase: implement
    result: "T3 — 사용자가 에이전트 디스패치를 거부하여 오케스트레이터가 직접 RGR 수행. Iron Law(테스트 우선)는 유지: 테스트 작성 → RED 확인 → 구현 → GREEN 확인"
  - phase: implement
    result: "T3 완료 — SyncStatusResolver + InputLimits/RepositoryError. 137개 통과(앱 47), 회귀 0건. REFACTOR 대상 없음"
  - phase: implement
    result: "T5 완료 — CanvasInput + createCanvas/updateCanvas + reconcileCover/canvasesFetched. 13개 추가로 159개 통과(앱 69), 회귀 0건. 소스 경고 0건"
  - phase: implement
    result: "T5 REFACTOR — 한계초과 제목 픽스처와 기대 에러를 한 쌍으로 묶음(길이가 어긋나면 통과해도 검증한 것이 없다). 프로덕션 정리 대상 없음"
  - phase: implement
    result: "T6 완료 — deleteCanvas/deleteCollection. 8개 추가로 167개 통과(앱 77), 회귀 0건. cascade는 deleteRule 단독으로 전이까지 발화 확인(리포지토리 우회 경로 테스트 포함)"
  - phase: implement
    result: "T7 완료 — moveCanvas + canvases(in:order:) + coverCanvas. 11개 추가로 178개 통과(앱 88), 회귀 0건. LibraryRepository 전 메서드 완비"
  - phase: implement
    decision: "canvases(in:order:) 정렬 2차 키를 id.uuidString으로 — AC에 없지만 CoverPolicy와 같은 근거(to-many 순서 무보장). 기록 날짜 동률 시 목록이 실행마다 뒤집히는 것을 막는다"
  - phase: implement
    result: "T7 REFACTOR — applyThenReconcileCover를 가변 인자로 통합(moveCanvas 양쪽 재계산). 순서 고정이 한 곳에만 있어 호출부가 틀릴 수 없다. 테스트 픽스처 2건 추출(유령표지_상태 / 날짜가_뒤섞인_캔버스3장)"
next-task:
  id: T8
  step: RED
  scope: "StatsRepository 통계 5종 (streakDays(now:) 포함)"
  ac: "AC-19 ~ AC-25, AC-25a, AC-25b"
  spec: ".dev/feat-data-layer/design.md §9 (StatsRepository)"
  files:
    - "SoozipTests/StatsRepositoryTests.swift (신규)"
    - "Soozip/Data/Repository/StatsRepository.swift (신규)"
  notes: "신규 파일 2개 — 반드시 `xcodegen generate` 후 테스트. 시각은 파라미터로 받는다(streakDays(now:)는 BR-9 개정 결과). 동률은 createdAt 오름차순"
  remaining: "T8 StatsRepository / T9 앱 배선"
  after-implement: "phase-review (spec-reviewer → quality-reviewer + security-auditor) → phase-complete (verify 게이트 → 인수 → PR)"
  method: "사용자 요청으로 T3부터 에이전트 디스패치 없이 오케스트레이터가 직접 RGR 수행 중. Iron Law(실패 테스트 우선)는 유지"
  verify-command: "./scripts/test.sh  # 현재 146개 통과 (패키지 90 + 앱 56)"
  xcodegen: "파일을 추가하면 반드시 `xcodegen generate` — project.yml이 원본이라 재생성 없이는 xcodebuild가 새 파일을 못 본다"

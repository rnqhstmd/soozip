import Testing
@testable import SoozipGeometry

// 제스처 라우팅 — 손가락 패턴(FingerPattern)과 레이어 선택 여부(hasSelection)의
// 조합이 어떤 조작(GestureRoute)으로 이어지는지 고정한다. 판정 표(route)는
// private이라 테스트에서 직접 부를 수 없고, 반드시 GestureRouter.idle을
// 시작점으로 .started(_:hasSelection:) → .active를 관측해야 한다. init도
// private이라 idle이 아닌 임의의 활성 상태를 테스트가 조작해 만들 수 없다 —
// 이번 태스크의 모든 케이스는 유휴에서 시작하는 단일 전이다.

/// 6쌍을 리터럴 배열로 순회하는 이유와, 개별 테스트로 쪼갤 때의 대가.
///
/// 6개 조합은 "패턴 × 선택 여부 → 결과" 판정표의 각 행이며, 검증 절차(유휴에서
/// started 호출 → .active 비교)는 모든 행에서 완전히 동일하다 — 달라지는 것은
/// 입력 두 개와 기대값 하나뿐이다. 이런 표 형태를 6개 함수로 쪼개면 각 함수
/// 본문이 세 줄짜리 동일한 뼈대를 6번 복제하게 되고, 표의 여섯 행이 한눈에
/// 비교되지 않아 "표에 구멍이 있는지"를 보려면 파일을 끝까지 스크롤해야 한다.
/// 반대로 순회로 묶으면 실패 시 어떤 행이 깨졌는지가 assertion 메시지의 라벨
/// 하나로만 드러나 개별 함수명이 주는 것 같은 진단력을 잃는다 — 그래서 라벨을
/// "AC-N: 패턴/선택여부" 형태로 못박아 그 손실을 보전한다. 이 저장소는 이미
/// LayerCenterClampTests의 클램프_결과는_줌과_뷰포트에_무관하다에서 동일한
/// "동일 절차·다른 입력" 표를 리터럴 배열 순회로 표현한 선례가 있어 그 관례를
/// 따른다.
@Test func 유휴_상태에서_손가락_패턴과_선택_여부의_모든_조합이_설계된_라우트로_전이한다() {
    // AC-1~6. 각 행은 GestureRouter.idle에서 시작하는 단일 전이 하나를 뜻한다.
    //
    // `FingerPattern`에 CaseIterable을 붙이지 않은 이유.
    // 전 케이스를 순회해야 하는 프로덕션 소비자가 없다 — 라우팅 판정은 손가락
    // 개수·선택 여부로 갈리는 6-arm switch 하나로 끝나고, 그 switch는
    // FingerPattern 값 각각을 명시적으로 나열해 소비하지 allCases를 순회하지
    // 않는다. HandleGesture도 같은 이유로 CaseIterable을 붙이지 않았다. 그래서
    // 이 테스트도 allCases 순회가 아니라 6쌍을 명시 리터럴로 적는다.
    // 한계: 이 리스트는 명시 리터럴이라 FingerPattern에 새 case가 추가돼도
    // 컴파일도 실행도 조용히 그대로 통과한다 — 새 case를 라우팅 표에 반영하지
    // 않는 실수를 이 테스트는 잡지 못한다. 그 방어는 프로덕션의 6-arm 전수
    // switch(비exhaustive 분기가 있으면 컴파일이 깨지는 구조)가 진다.
    let 표: [(라벨: String, pattern: FingerPattern, hasSelection: Bool, expected: GestureRoute)] = [
        ("AC-1 선택있음/1손가락드래그", .oneFingerDrag, true, .moveLayer),
        ("AC-2 선택있음/2손가락핀치회전", .twoFingerPinchRotate, true, .resizeRotateLayer),
        ("AC-3 선택있음/2손가락드래그", .twoFingerDrag, true, .panCanvas),
        ("AC-4 선택없음/1손가락드래그", .oneFingerDrag, false, .panCanvas),
        ("AC-5 선택없음/2손가락핀치회전", .twoFingerPinchRotate, false, .zoomCanvas),
        ("AC-6 선택없음/2손가락드래그", .twoFingerDrag, false, .panCanvas),
    ]

    for (라벨, pattern, hasSelection, expected) in 표 {
        let 결과 = GestureRouter.idle.started(pattern, hasSelection: hasSelection).active
        #expect(결과 == expected, "\(라벨)")
    }
}

/// 활성 가드 부재 시 재판정 변이를 잡는 7건과, 유일하게 못 잡는 1건.
///
/// 이 7건 중 **6건**이 "활성 가드 제거 후 매 `started`마다 재판정" 변이를
/// 죽인다. **AC-8만 살려 보낸다** — 선택 없음에서는 1손가락 드래그와
/// 2손가락 드래그가 **둘 다** 캔버스 팬이라(AC-4·AC-6) 재판정해도 답이
/// 같기 때문이다. 인코딩 실수가 아니라 PRD Given의 성질이고, **PRD를
/// 바꾸지 않는 한 강화할 수 없다.**
///
/// FR-2에는 독립 증인이 없다. 입력이 `started`·`ended` 둘뿐이라 "선택
/// 상태가 바뀌었다"·"손가락 수가 바뀌었다"를 알릴 입력이 애초에 없다.
/// AC-7·8·9를 `started(…)`로 인코딩한 것은 **FR-3의 입력 그 자체**다.
/// 즉 "FR-2 — 배타 잠금 유지" 절이 실제로 재는 것은 FR-3이며, FR-2에는
/// 관측 가능한 입력이 존재하지 않는다. AC-9를 지우지 않는 이유는 아래
/// 표의 한 행이기 때문이지 FR-2의 증인이라서가 아니다.
///
/// 동반 적색: AC-7~13이 빨가면 먼저 AC-1~6(위 테스트)을 보라. 표(`route`)가
/// 깨져도 여기가 함께 빨갛다 — `private init` 때문에 활성 상태를 날조할
/// 수 없어 모든 Given이 진짜 전이를 지나기 때문이다. 그 대가로 얻는 것은
/// "`started`가 `active`를 영영 설정하지 않는" 변이가 거짓 초록으로
/// 통과하지 못한다는 것이다.
@Test func 활성_라우팅은_종료_신호_없는_재진입_started로_바뀌지_않는다() {
    // AC-7~13. 각 행은 GestureRouter.idle에서 1차 started로 활성을 만들고,
    // ended() 없이 2차 started를 다시 호출한 뒤에도 활성이 1차 결과 그대로
    // 유지되는지를 본다. 입력·기대값은 설계서가 고정한 7행 표를 그대로
    // 옮긴다.
    let 표: [(라벨: String, 일차패턴: FingerPattern, 일차선택: Bool, 이차패턴: FingerPattern, 이차선택: Bool, expected: GestureRoute)] = [
        ("AC-7 이동중_손가락추가", .oneFingerDrag, true, .twoFingerDrag, true, .moveLayer),
        ("AC-8 팬중_손가락감소", .twoFingerDrag, false, .oneFingerDrag, false, .panCanvas),
        ("AC-9 이동중_선택해제", .oneFingerDrag, true, .oneFingerDrag, false, .moveLayer),
        ("AC-10 이동중_핀치재진입", .oneFingerDrag, true, .twoFingerPinchRotate, true, .moveLayer),
        ("AC-11 줌중_1손가락재진입", .twoFingerPinchRotate, false, .oneFingerDrag, false, .zoomCanvas),
        ("AC-12 팬중_핀치재진입", .twoFingerDrag, false, .twoFingerPinchRotate, false, .panCanvas),
        ("AC-13 리사이즈중_드래그재진입", .twoFingerPinchRotate, true, .twoFingerDrag, true, .resizeRotateLayer),
    ]

    for (라벨, 일차패턴, 일차선택, 이차패턴, 이차선택, expected) in 표 {
        let 결과 = GestureRouter.idle
            .started(일차패턴, hasSelection: 일차선택)
            .started(이차패턴, hasSelection: 이차선택)
            .active
        #expect(결과 == expected, "\(라벨)")
    }
}

/// AC-14: 종료 신호(`ended()`)를 지나면 이전 세션의 판정이 끊긴다.
///
/// 위 두 테스트와 검증 대상이 다르다 — 저 둘은 "활성으로 가는 한 번의
/// 전이"·"활성 중 재진입이 막히는지"를 보지만, 이 테스트는 "활성 →
/// 종료 → 재활성"이라는 3단 전이에서 `ended()`가 실제로 유휴를 되돌려
/// 놓는지를 본다. 검증 절차 자체가 다르므로(표 순회가 아니라 단일
/// 시나리오이고, 이차 판정의 근거가 "종료를 지났다"는 것) 위 표에
/// 합류시키지 않고 별도 함수로 둔다.
///
/// 이 단언은 **작성 시점의 스텁(`ended()`가 `self`를 그대로 반환)에서는
/// 실패했다 — 그것이 이 테스트의 RED였다.** 그 스텁에서는 종료 후에도
/// 활성이 `.panCanvas`로 남고, 그 활성 상태에서 재진입한 `started`가
/// `started`의 활성 가드에 걸려 `self`를 그대로 냈다. 기대값은
/// `.moveLayer`이지만 실제 값은 `.panCanvas`였다 — 컴파일 에러가 아니라
/// 행동 수준의 RED였다.
@Test func 종료_신호_이후_재진입은_이전_세션의_판정을_이어받지_않는다() {
    // AC-14. 선택 없음에서 1손가락 드래그로 캔버스 팬을 활성화했다가 ended()로
    // 종료한다. 그 사이 사용자가 레이어를 선택했다고 가정하고, 선택 있음
    // 상태에서 같은 1손가락 드래그를 다시 시작하면 새 판정인 레이어 이동이
    // 나와야 한다 — 종료로 유휴에 복귀했으므로 활성 가드가 개입하지 않는다.
    let 결과 = GestureRouter.idle
        .started(.oneFingerDrag, hasSelection: false)
        .ended()
        .started(.oneFingerDrag, hasSelection: true)
        .active
    #expect(결과 == .moveLayer)
}

/// AC-15: 활성 라우팅이 없는 유휴 상태에서 종료 신호를 (중복으로) 받아도
/// 크래시·예외 없이 유휴를 유지한다(멱등).
///
/// **킬셋은 하나뿐이다.** `ended()`가 `.idle`을 내든 `self`를 내든
/// **유휴에서는 같은 값**이고, 활성에서의 차이는 위 AC-14가 잡는다. 이
/// 단언을 죽이는 변이는 `precondition(active != nil)` 같은 것을 끼워 넣는
/// 변이 하나뿐이다. PRD가 "크래시나 예외 없이"를 요구했으니 요구사항과
/// 정확히 일치하지만, 판정력을 과대평가하지 마라 — 이 테스트는 `ended()`의
/// **동작**을 검증하지 않는다. 그 검증은 AC-14가 진다.
///
/// 이 단언은 **작성 시점의 스텁(`ended()`가 `self`를 그대로 반환)에서도
/// 통과했다.** 유휴에서는 `self`가 곧 `.idle`이었기 때문이다. 이는 결함이
/// 아니라 이 AC의 성질이다 — AC-14와 짝을 지어야만 `ended()`의 실제 동작이
/// 드러난다.
@Test func 유휴_상태에서_종료_신호를_중복으로_받아도_유휴를_유지한다() {
    // AC-15. 단발 종료와 중복 종료 두 시점 모두에서 유휴가 유지되는지 본다.
    #expect(GestureRouter.idle.ended() == .idle)
    #expect(GestureRouter.idle.ended().ended() == .idle)
}

import Testing
import Foundation
@testable import SoozipGeometry

// 이 파일 전역 규칙: 튜플 단언 금지 — `#expect(r == (true, 15.0))`처럼 쓰면
// Swift 표준 튜플 `==`가 `Double ==`을 몰래 들여와 정확 일치 비교를 강제한다.
// 부동소수점 결과는 반드시 `snapped`와 `degrees`를 각각 별도 단언
// (`#expect(r.snapped)` / `isClose(r.degrees, ...)`)으로 분리한다.

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

@Test func 그리드에_가까운_각도가_흡착된다() {
    // 거리 1° < 3° — 흡착 게이트가 정상 발동하는지 확인하는 기본 양성 케이스.
    // 이 테스트가 죽이는 변이: `.rounded()` → `.rounded(.down)`, 항상 미흡착.
    let r = RotationSnap.snapped(degrees: 14)
    #expect(r.snapped)
    #expect(isClose(r.degrees, 15))
}

@Test func 임계_바로_안쪽에서도_흡착된다() {
    // 거리 2.9° — 임계 3.0°에 가깝지만 아직 미만이다.
    // 이 테스트가 죽이는 변이: `.rounded()` → `.rounded(.down)`, 항상 미흡착,
    // 임계를 3 → 2.5로 좁히는 변이.
    let r = RotationSnap.snapped(degrees: 12.1)
    #expect(r.snapped)
    #expect(isClose(r.degrees, 15))
}

@Test func 정확히_3도는_흡착되지_않는다() {
    // 거리 정확히 3.0° — 도 단위라 이진 부동소수점에서도 정확히 표현된다.
    // 이 테스트가 죽이는 변이: `<` → `<=`, `abs()` 제거, 임계를 3 → 5로
    // 넓히는 변이.
    let r = RotationSnap.snapped(degrees: 12)
    #expect(!r.snapped)
    #expect(isClose(r.degrees, 12))
}

@Test func 음수_각도도_흡착된다() {
    // 음수 각도에서도 가장 가까운 그리드(-15°)를 정확히 찾는지 확인한다.
    // 이 테스트가 죽이는 변이: `[0,360)` 정규화 선행, 항상 미흡착.
    let r = RotationSnap.snapped(degrees: -13)
    #expect(r.snapped)
    #expect(isClose(r.degrees, -15))
}

@Test func 두_그리드_한가운데는_흡착되지_않는다() {
    // 0°까지 7°, 15°까지 8° — 양쪽 모두 임계 3°를 넘는다. 측정한 변이 8종
    // 중 어느 것도 이 테스트를 죽이지 못했다(임계를 5로 키워도 가장 가까운
    // 그리드 0°에서 7° 떨어져 여전히 미흡착). 임계를 8 이상으로 대폭
    // 넓히는 변이에 대한 방어선이므로 제거 대상이 아니다.
    let r = RotationSnap.snapped(degrees: 7)
    #expect(!r.snapped)
    #expect(isClose(r.degrees, 7))
}

@Test func 이미_그리드_위인_각도는_움직이지_않는다() {
    // 거리 정확히 0 — 흡착 여부가 참이면서 값이 그대로인 경계 케이스.
    // 이 테스트가 죽이는 변이: 항상 미흡착.
    let r = RotationSnap.snapped(degrees: 30)
    #expect(r.snapped)
    #expect(isClose(r.degrees, 30))
}

@Test func 누적_바퀴수가_보존된다() {
    // 373°(한 바퀴 + 13°) → 375°. `truncatingRemainder(360)` 선행 변이와
    // `[0,360)` 정규화 선행 변이를 모두 죽이는 유일한 테스트다 — 즉 바퀴 수
    // 보존을 검증하는 유일한 증인이며, "중복이니 지워도 된다"는 판단은
    // 오판이다. `.rounded()` → `.rounded(.down)` 변이와 항상 미흡착 변이도
    // 함께 잡는다.
    let r = RotationSnap.snapped(degrees: 373)
    #expect(r.snapped)
    #expect(isClose(r.degrees, 375))
}

@Test func 한_바퀴_경계에서도_접지_않는다() {
    // 359° → 360°. 359 < 360이라 두 정규화 변이(모듈로 선행·[0,360) 정규화
    // 선행) 모두 항등이 되어 이 테스트를 죽이지 못한다 — 실제로 죽는 것은
    // `.rounded()` → `.rounded(.down)` 변이와 항상 미흡착 변이다.
    let r = RotationSnap.snapped(degrees: 359)
    #expect(r.snapped)
    #expect(isClose(r.degrees, 360))
}

@Test func 그리드_간격과_흡착_임계가_공개_상수다() {
    // `gridStepDegrees`를 15 → 15.0003으로 미세 섭동해도 나머지 8개 테스트는
    // 전부 통과한다(가장 민감한 `누적_바퀴수가_보존된다`도 373° 입력에서
    // 오차가 25배 증폭돼 0.0075가 되지만 `isClose` 임계 0.01 안에 든다) —
    // 이 상수 단언만이 그 섭동을 잡는다. 임계를 3 → 5나 3 → 2.5로 바꾸는
    // 변이도 이 단언이 함께 잡는다.
    #expect(RotationSnap.gridStepDegrees == 15)
    #expect(RotationSnap.snapThresholdDegrees == 3)
}

@Test func 음수_각도가_양수로_정규화된다() {
    // 음수 보정(`if r < 0 { r += period }`)을 제거하는 변이를 죽인다 — 그
    // 변이가 없으면 -30°는 그대로 -30으로 남는다.
    let r = RotationSnap.normalized(degrees: -30)
    #expect(isClose(r, 330))
}

@Test func 여러_바퀴_각도가_정규화된다() {
    // 오케스트레이터가 측정한 변이 5종(floor 기반 정규화·상한 클램프
    // 제거·라디안 정규화를 도 정규화 합성으로 대체·라디안 주기를 π로·
    // 음수 보정 제거) 중 이 테스트를 죽이는 것은 없다 — 725°는 두 바퀴를
    // 넘겨 truncatingRemainder 한 번으로 이미 충분히 접히기 때문이다.
    // 그래도 남기는 이유는 "한 바퀴만 빼고 마는" 뺄셈 1회 구현처럼 측정
    // 범위 밖의 다른 변이에 대한 방어선이기 때문이다.
    let r = RotationSnap.normalized(degrees: 725)
    #expect(isClose(r, 5))
}

@Test func 극단_유한각의_정규화는_296도다() {
    // floor 기반 정규화 변이를 죽인다 — 그 구현은 1e308에서 0.0을 내고도
    // `[0,360)` 범위 단언은 통과해버린다. 값 단언만이 그 구현을 죽인다.
    let r = RotationSnap.normalized(degrees: 1e308)
    #expect(isClose(r, 296))
}

@Test func 미세_음수는_360으로_올라가지_않는다() {
    // 상한 클램프 제거 변이의 유일한 증인이다 — 나머지 6건은 이 변이가
    // 있어도 전부 생존한다. -1e-15의 나머지에 360을 더하면 부동소수점
    // 반올림으로 정확히 360.0이 되는 경계 입력이다. 음수 보정 제거 변이도
    // 함께 죽인다.
    let r = RotationSnap.normalized(degrees: -1e-15)
    #expect(r < 360)
    #expect(r >= 0)
}

@Test func 한_바퀴_안의_라디안은_접히지_않는다() {
    // 라디안 주기를 π로 잘못 쓰는 변이를 죽인다(그 경우 0.858이 나온다).
    let r = RotationSnap.normalized(radians: 4.0)
    #expect(isClose(r, 4.0))
}

@Test func 극단_유한_라디안도_한_바퀴_안으로_접힌다() {
    // 라디안 정규화를 도 정규화 합성으로 대체하는 변이의 유일한 증인이다
    // — 그 변이는 1e308 라디안을 도로 환산하며 inf가 되고 fmod(inf, 360)이
    // NaN이 되어 유한성 단언에서 빨강이 된다. floor 기반 정규화 변이와
    // 라디안 주기를 π로 바꾸는 변이도 함께 죽인다.
    let r = RotationSnap.normalized(radians: 1e308)
    #expect(r.isFinite)
    #expect(isClose(r, 5.720858487389101))
}

@Test func NaN의_정규화는_비유한으로_남는다() {
    // NaN이 유한한 값으로 조용히 바뀌는 변이(예: NaN을 0으로 대체)를
    // 죽인다. Double ==으로는 NaN을 비교할 수 없어 isNaN을 직접 확인한다.
    let r = RotationSnap.normalized(degrees: .nan)
    #expect(r.isNaN)
}

@Test func 극단_유한_라디안의_흡착_결과는_유한하다() {
    // 흡착 여부와 무관하게 무조건 되변환하는 구현을 죽인다 — 1e308 라디안은
    // rad→deg 변환에서 오버플로해 inf가 되고, 그것을 되곱으면 inf가 밖으로
    // 나간다. 올바른 구현은 흡착 실패로 판정해 입력을 그대로 돌려주므로
    // 유한하다.
    let r = RotationSnap.snapped(radians: 1e308)
    #expect(r.radians.isFinite)
}

@Test func NaN은_흡착되지_않고_비유한으로_남는다() {
    // 비유한 입력을 0 같은 유한값으로 조용히 후퇴시키는 구현을 죽인다.
    // `무한대도_안전하게_후퇴한다`와 같은 변이를 함께 죽이지만 중복이
    // 아니다 — 이 테스트는 NaN을, 그 테스트는 +Infinity를 덮어 서로 다른
    // 비유한 종류를 확인한다.
    let r = RotationSnap.snapped(radians: .nan)
    #expect(!r.snapped)
    #expect(!r.radians.isFinite)
}

@Test func 무한대도_안전하게_후퇴한다() {
    // 결과 비유한 단언이 없으면 (false, 0.0)을 내는 구현도 통과해버린다 —
    // 크래시 없이 반환되고 흡착되지 않으며 결과도 비유한이어야 한다.
    // `NaN은_흡착되지_않고_비유한으로_남는다`와 같은 변이를 함께 죽이지만
    // 중복이 아니다 — 그 테스트는 NaN을, 이 테스트는 +Infinity를 덮어
    // 서로 다른 비유한 종류를 확인한다.
    let r = RotationSnap.snapped(radians: .infinity)
    #expect(!r.snapped)
    #expect(!r.radians.isFinite)
}

@Test func 라디안_경로에서도_정확히_3도는_흡착되지_않는다() {
    // **두 변이의 유일한 증인이다**: 비교를 라디안 공간으로 옮기는
    // 리팩터링과, 역수(라디안→도)를 별도 상수로 두는 변이. 지우면
    // `snapThresholdDegrees`의 설계 결정(도 공간 판정)과
    // `radiansPerDegree`의 단일 출처 결정이 동시에 증인 0건이 된다. 값
    // 유도 근거는 `snapThresholdDegrees`·`radiansPerDegree` 문서 참고.
    //
    // 왕복 정확도는 `snapped(radians:)` 문서 참고. 12°를 쓰는 이유는 그
    // 값의 왕복이 정확하기 때문이다. 다른 값으로 바꾸면 이 테스트가 깨질
    // 수 있다.
    let input = RotationSnap.radians(fromDegrees: 12)
    let r = RotationSnap.snapped(radians: input)
    #expect(!r.snapped)
}

@Test func 흡착_구간에_진입하는_순간_참이다() {
    // AC-13: 직전 20°(모든 그리드에서 3° 초과, 미흡착) → 현재 17°(15°까지
    // 2°, 흡착). 미흡착에서 흡착으로 바뀌는 기본 양성 케이스다. 측정한 5개
    // 변이(목표 비교에서 normalized 제거·목표 비교 조건절 제거·guard
    // previous.isFinite 제거·현재 흡착만 본다·라디안 어댑터 무력화) 중
    // 어느 것도 이 테스트를 죽이지 못했다 — 그래도 `return false` 같은 더
    // 거친 변이에 대한 방어선이므로 제거 대상이 아니다.
    let entered = RotationSnap.entersSnap(fromDegrees: 20, toDegrees: 17)
    #expect(entered)
}

@Test func 같은_구간에_머무는_동안_재발화하지_않는다() {
    // AC-14: 직전 17°와 현재 16° 모두 15°에 흡착된다 — 같은 목표에 계속
    // 붙어 있으므로 재발화하면 안 된다. "현재 흡착이면 무조건 참" 변이를
    // 죽인다.
    let entered = RotationSnap.entersSnap(fromDegrees: 17, toDegrees: 16)
    #expect(!entered)
}

@Test func 다른_그리드로_넘어가면_다시_발화한다() {
    // 16°는 15°에, 29°는 30°에 흡착된다 — 둘 다 흡착 중이지만 목표가
    // 다르므로 다시 발화해야 한다. **"현재 흡착 ∧ 직전 미흡착"만 보는
    // 단순 구현이 흡착_구간에_진입하는_순간_참이다·같은_구간에_머무는_
    // 동안_재발화하지_않는다를 둘 다 통과시켜버리는 것을 잡는 유일한
    // 증인이다 — 목표 비교 조건절 자체의 존재를 검증한다.** 실측: 목표
    // 비교 조건절을 제거하는 변이는 이 저장소가 측정한 변이 중 오직 이
    // 테스트만 죽인다.
    let entered = RotationSnap.entersSnap(fromDegrees: 16, toDegrees: 29)
    #expect(entered)
}

@Test func 한_바퀴_경계를_넘어도_같은_그리드면_발화하지_않는다() {
    // 359°는 360°에, 1°는 0°에 흡착된다 — 두 목표는 원 위에서 같은 지점
    // (0° ≡ 360°)이므로 재발화하면 안 된다. **목표를 정규화하지 않고
    // 그대로 빼는 구현(|360 − 0| = 360, "다른 그리드"로 오판)을 잡는
    // 유일한 증인이다.** 실측: 목표 비교에서 `normalized`를 제거하는
    // 변이는 이 저장소가 측정한 변이 중 오직 이 테스트만 죽인다.
    let entered = RotationSnap.entersSnap(fromDegrees: 359, toDegrees: 1)
    #expect(!entered)
}

@Test func 직전이_NaN이면_발화하지_않는다() {
    // 현재 17°는 흡착 중이다. 직전 유한성 가드가 없으면 NaN이 "직전
    // 미흡착"으로 분류되어 발화해버린다. **이 가드의 유일한 증인이다.**
    // 실측: `guard previous.isFinite`를 제거하는 변이는 이 저장소가
    // 측정한 변이 중 오직 이 테스트만 죽인다.
    let entered = RotationSnap.entersSnap(fromDegrees: .nan, toDegrees: 17)
    #expect(!entered)
}

@Test func 양쪽이_NaN이면_발화하지_않는다() {
    // 직전·현재 모두 NaN이면 흡착 여부를 판정할 수 없으므로 발화하지
    // 않아야 한다. 측정한 5개 변이 중 이 테스트를 죽이는 것은 없다 —
    // current가 NaN이면 `now.snapped`가 이미 거짓이 되어 그 뒤 어떤
    // 조건절 변이도 이 테스트에 도달하지 못하기 때문이다. **이 테스트는
    // 회귀 감시이며 구현을 끌어내지 않는다** — "가드의 증인"으로 오인하지
    // 말 것.
    let entered = RotationSnap.entersSnap(fromDegrees: .nan, toDegrees: .nan)
    #expect(!entered)
}

@Test func 라디안_진입_판정도_같은_답을_낸다() {
    // 도 단위 흡착_구간에_진입하는_순간_참이다와 동일한 시나리오를 라디안
    // 경로로 확인한다. 20°·17°는 그리드 여유가 커서(5°·2°) 왕복 오차 1
    // ulp로 판정이 뒤집히지 않는다. **라디안 어댑터가 도 판정으로
    // 위임하는지 확인하는 유일한 증인이다** — 실측: 라디안 어댑터를
    // 무력화하는 변이는 이 저장소가 측정한 변이 중 오직 이 테스트만
    // 죽인다.
    let previous = RotationSnap.radians(fromDegrees: 20)
    let current = RotationSnap.radians(fromDegrees: 17)
    let entered = RotationSnap.entersSnap(fromRadians: previous, toRadians: current)
    #expect(entered)
}

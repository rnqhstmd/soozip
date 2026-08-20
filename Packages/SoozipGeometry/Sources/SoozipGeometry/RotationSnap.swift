import Foundation

/// 회전 각도를 그리드에 흡착시키는 계산.
///
/// `enum`인 이유: `struct`였다면 암묵적으로 `init()`이 생겨 `RotationSnap()`이라는
/// 무의미한 인스턴스 생성이 컴파일된다. 이 타입은 상태 없는 네임스페이스이므로
/// 인스턴스화 자체를 막아야 한다.
///
/// `SnapEngine`의 `SnapKind`에 케이스로 추가하지 않은 이유:
/// 1. `SnapCandidate`의 소비자는 가이드 **선** 렌더러인데, 회전에는 그을 선이
///    없다(설계서가 지정한 표현은 각도 배지다).
/// 2. `snapCandidates`의 입력 넷 중 회전이 쓰는 것이 하나도 없다.
/// 3. `SnapKind`는 `public`이라 케이스를 추가하면 소비자의 exhaustive switch가
///    깨지는 소스 호환성 변경이 된다.
///
/// 단위 규약: 이 타입의 판정 본체는 **도(degree)**다. 프로덕션의 회전값
/// (`LayerFrame.rotation`·`LayerTransform.rotation`)은 **라디안**이므로 라디안
/// 진입점이 따로 있다 — `snapped(radians:)`·`normalized(radians:)`·
/// `entersSnap(fromRadians:toRadians:)` 셋이 이미 존재한다. **도 API에 라디안을 그대로 넣으면 컴파일은
/// 되지만 조용히 파괴적이다** — 실측: `15°`(0.261799 rad)·`45°`·`90°`·`170°`가
/// 전부 `(true, 0.0)`이 되고, `171.9°`(3.000221 rad)에 이르러서야 처음
/// 미흡착이 된다. 즉 `|r| < 3 rad`(약 ±171.9°) 전 구간이 0으로 붕괴하는데,
/// 반환값이 완벽히 유한하고 `snapped == true`라 겉보기엔 정상 동작으로 보인다.
/// 컴파일러가 이 오용을 막지 않으므로 인자 라벨(`degrees:`)이 유일한 방어선이다.
public enum RotationSnap {
    /// 흡착 그리드 간격(도).
    ///
    /// 도인 이유: 라디안(`.pi/12`)으로 두면 "정확히 15°" 단언이 정의의
    /// 재진술이 되어 공허해진다. `15`는 binary64로 정확히 표현되므로 상수
    /// 리터럴 단언(`== 15`)이 성립한다.
    ///
    /// ⚠️ `HandlePlacement.swift`의 코너 밀기 실측 문서가 이 값에 의존한다 —
    /// "15° 눈금 24개 중 정사각 200×200 13개 · 세로긴 100×300 12개 ·
    /// 가로긴 300×100 12개". 이 값을 바꾸면 그 문장이 통째로 무효가 되는데
    /// **컴파일러도 테스트도 잡지 못한다.**
    public static let gridStepDegrees: Double = 15
    /// 흡착이 발동하는 최대 거리(도).
    ///
    /// 엄격 부등호 — 정확히 3°는 미흡착. 이 저장소 임계 3개 중 2개가
    /// "경계는 이전 상태"이고(`edgeHideThreshold`는 `>= 88`이면 변이 있고,
    /// `cornerPushThreshold`는 `< 56`이면 민다), `flipThreshold`(`<= 40`)만
    /// 반대인데 그것은 `HandlePlacement.swift`가 예외로 명시 문서화한 자리다.
    ///
    /// **라디안 공간에서 이 비교를 하면 경계가 깨진다** — 실측: `|12° − 15°|`를
    /// 라디안으로 재면 `0.05235987755982985`이고 임계 3°는
    /// `0.05235987755982989`라 거리가 임계보다 작아 흡착된다. 도 공간은
    /// `3.0 < 3.0`이 거짓이라 미흡착이다. **"라디안으로 통일하라"는
    /// 리팩터링이 이 규칙을 깬다.**
    public static let snapThresholdDegrees: Double = 3

    /// 주어진 각도를 가장 가까운 그리드에 흡착 시도한다.
    ///
    /// 판정의 유일한 본체다 — 라디안 어댑터(`snapped(radians:)`)는 여기로 위임한다.
    /// **정규화 이전 원본 각도 기준**이라 누적 바퀴 수가 보존된다
    /// (`373 → 375`, `359 → 360`).
    ///
    /// 후퇴(fallback) 대상이 입력 자신(`degrees`)이므로, 비정상 입력이
    /// 유한값으로 조용히 바뀌지 않는다(`NaN` → `abs(NaN−NaN)`가 `NaN`,
    /// `NaN < 3`이 거짓 → `(false, NaN)`).
    public static func snapped(degrees: Double) -> (snapped: Bool, degrees: Double) {
        let index = (degrees / gridStepDegrees).rounded()
        let candidate = index * gridStepDegrees
        guard abs(degrees - candidate) < snapThresholdDegrees else { return (false, degrees) }
        return (true, candidate)
    }

    /// 한 바퀴(도).
    ///
    /// **`private`인 이유**: `public`으로 열면 호출부가
    /// `r.truncatingRemainder(dividingBy: RotationSnap.turnRadians)`로 두 번째
    /// 접기를 짜는 가장 짧은 경로가 생긴다. `normalized(radians:)`가 있으면
    /// 열 이유가 없다.
    ///
    /// `2π`와 `360°`는 같은 것의 두 표현이지만 binary64에서는 다른 수다.
    /// **두 진입점의 결과가 마지막 몇 ulp에서 다를 수 있고 피할 수 없다.**
    private static let turnDegrees: Double = 360
    /// 한 바퀴(라디안). `private`인 이유는 위 `turnDegrees` 문서 참고.
    private static let turnRadians: Double = 2 * .pi

    /// 값을 주어진 주기의 `[0, period)`로 접는다.
    ///
    /// **한 바퀴 접기 규칙이 저장소에 한 벌만 있게 하는 장치다.** 규칙은 세
    /// 단계(나머지 → 음수 보정 → 상한 클램프)이고 단위는 `period` 하나로만
    /// 나타난다. 세 단계를 도·라디안 두 벌로 적으면 한쪽만 바뀌는 날이 온다
    /// — 이 저장소가 다섯 번 겪은 실패다.
    ///
    /// **이 "한 벌" 주장은 이제 저장소 전체에서 참이다.** `SnapEngine`의
    /// `isAxisAligned(radians:)`가 한때 자체 `truncatingRemainder` 접기를
    /// 따로 갖고 있어 이 주장을 반증했다 — 그 접기를 `normalized(radians:)`
    /// 호출로 교체해 통합했다.
    ///
    /// **`truncatingRemainder`여야 하는 이유**: `value -
    /// (value/period).rounded(.down) * period` 같은 `floor` 기반 구현은
    /// `1e308`에서 **`0.0`**을 낸다. 그것도 `[0,360)` 안이라 **범위 단언은
    /// 통과한다.** 올바른 값은 `296`이고 `truncatingRemainder`가 정확
    /// 연산이라 결정적이다.
    ///
    /// **상한 클램프가 필요한 이유**: `-1e-15`의 나머지는 `-1e-15`이고
    /// 여기에 `360`을 더하면 **정확히 `360.0`으로 반올림**되어 `[0,360)`을
    /// 벗어난다.
    ///
    /// **부수 이득(실측)**: 본체를 공유하므로 `floor` 변이와 주기 오배선
    /// 변이가 **도 축과 라디안 축 양쪽에서** 죽는다.
    private static func folded(_ value: Double, period: Double) -> Double {
        var r = value.truncatingRemainder(dividingBy: period)
        if r < 0 { r += period }
        if r >= period { r = 0 }
        return r
    }

    /// 도 각도를 `[0, 360)`으로 정규화한다.
    ///
    /// 결과는 항상 `[0°, 360°)`의 음이 아닌 값.
    ///
    /// **프로덕션 소비자**: `entersSnap(fromDegrees:toDegrees:)`가 목표
    /// 비교에 이 함수를 쓴다 — 이유는 그 함수 문서 참고.
    public static func normalized(degrees: Double) -> Double { folded(degrees, period: turnDegrees) }

    /// 라디안 각도를 `[0, 2π)`으로 정규화한다.
    ///
    /// **도 정규화를 감싸지 않는 이유 — 이것이 이 사이클의 핵심이다.**
    /// `radians → degrees → normalized → radians` 합성은 유한 입력에서
    /// **NaN을 낸다**: `1e308` 라디안을 도로 바꾸면 `inf`가 되고(rad→deg
    /// 오버플로 문턱은 `|r| >= 3.1375664143845866e306`), `fmod(inf, 360)`이
    /// **`NaN`**이다. 그 NaN이 레이어의 `rotation`에 앉으면
    /// **`JSONEncoder`가 던져 문서 저장 자체가 실패한다.**
    /// `period`만 바꿔 같은 본체를 쓰면 변환을 태우지 않으므로 **오버플로
    /// 지점 자체가 없다 — 가드가 없는 것이 설계다.**
    ///
    /// 실측: `normalized(radians: 1e308)` = `5.720858487389101`(유한).
    ///
    /// **프로덕션 소비자**: `SnapEngine.isAxisAligned(radians:)`가 축 정렬
    /// 판정의 접기 단계로 이 함수를 쓴다(이전에는 소비자 0건이었다).
    public static func normalized(radians: Double) -> Double { folded(radians, period: turnRadians) }

    /// 도 1개당 라디안(단위 변환 상수).
    ///
    /// **한 벌만 둔다.** 반대 방향(라디안→도)도 별도 상수(`180 / .pi`)가
    /// 아니라 **이 상수로 나눈다.**
    ///
    /// 근거(실측): `3 * (.pi / 180)`은 `0x3faacee9f37bebd6`이고
    /// `.pi / 60`은 `0x3faacee9f37bebd5`로 **정확히 1 ulp 다르다.** 두 벌을
    /// 쓰면 3° 경계에서 갈라진다. 참고로 `15 * (.pi / 180)`과 `.pi / 12`는
    /// **비트 동일**하다 — 즉 "라디안 상수는 어떻게 써도 같다"는
    /// **일반적으로 거짓**이고 값에 따라 다르다.
    ///
    /// **증인이 있다(실측)**: 역수를 별도 상수로 바꾸면
    /// `라디안_경로에서도_정확히_3도는_흡착되지_않는다`가 빨강이 된다.
    private static let radiansPerDegree: Double = .pi / 180

    /// 라디안을 도로 바꾼다.
    ///
    /// ⚠️ **이 함수는 유한 입력에서 비유한을 낼 수 있고, 그것을 막을 방법이
    /// 없다.** `|radians| >= 3.1375664143845866e306`에서 `inf`가 된다(실측:
    /// `1e308 / (.pi / 180)` = `inf`). 올바른 값이 `Double`로 표현
    /// 불가능하므로 어떤 구현도 유한한 정답을 낼 수 없다. 클램프하면
    /// 조용한 거짓말이고 `inf`는 넘쳤다는 IEEE-754 신호다.
    ///
    /// ⚠️ **이 함수의 출력을 다시 판정에 먹이지 마라.** `degrees(fromRadians:)
    /// → normalized(degrees:)` 합성은 `inf`를 `NaN`으로 만들고, 그 `NaN`이
    /// 레이어 `rotation`에 앉으면 **`JSONEncoder`가 던져 문서 저장이
    /// 실패한다.** 라디안 판정이 필요하면 `snapped(radians:)`·
    /// `normalized(radians:)`를 써라 — 그 둘은 이 경로를 내부에서 닫았다.
    ///
    /// **`public`인 것이 이 저장소 관례의 반대 방향이며 그것이 의도다.**
    /// 정책 상수(`edgeHideThreshold` 등)는 **열면** 호출부가 재기술하지만,
    /// 변환은 **닫으면** 호출부가 `.pi / 180`을 재기술한다. 방향이 반대다.
    public static func degrees(fromRadians radians: Double) -> Double { radians / radiansPerDegree }

    /// 도를 라디안으로 바꾼다.
    ///
    /// **유한 입력에서 절대 넘치지 않는다** — 곱하는 상수가 1보다 작아
    /// 크기가 줄어드는 방향이다. `degrees(fromRadians:)`가 나눗셈이라
    /// 위험한 것과 대칭이다.
    public static func radians(fromDegrees degrees: Double) -> Double { degrees * radiansPerDegree }

    /// 라디안 입력을 도 판정(`snapped(degrees:)`)으로 위임하는 어댑터.
    ///
    /// **단위만 옮기는 어댑터다.** 규칙 본체는 `snapped(degrees:)`이고 이
    /// 함수는 규칙을 갖지 않는다.
    ///
    /// **`guard core.snapped else { return (false, radians) }`가 필수인
    /// 이유**: 중간에 `inf`가 나와도 흡착 실패로 판정해 **입력 라디안
    /// 그대로 후퇴**하므로 결과가 유한하다. 흡착 여부와 무관하게
    /// 되변환하면 `1e308`에서 `inf`가 밖으로 나간다. 후퇴 대상이 입력
    /// 자신이라 비유한 입력이 유한값으로 조용히 바뀌지 않는다.
    ///
    /// **흡착 성공 경로는 무조건 유한하다** — 되곱하는 상수가 1보다 작기
    /// 때문이다. 결과 유한성 가드가 없는 것이 설계다.
    ///
    /// **`Self.` 한정자가 필수한 자리는 하나뿐이다(실측)**: 아래
    /// `Self.radians(fromDegrees:)` 호출 — 매개변수 `radians`가 정적 함수
    /// `radians(fromDegrees:)`를 가려 `Self.` 없이 쓰면 `error: cannot call
    /// value of non-function type 'Double'`이 난다. 바로 앞의
    /// `Self.degrees(fromRadians:)` 호출과 `entersSnap(fromRadians:
    /// toRadians:)`의 `Self.degrees(fromRadians:)` 두 호출은 그 스코프의
    /// 매개변수 이름이 `degrees`가 아니므로(각각 `radians`·`previous`·
    /// `current`) `degrees(fromRadians:)`가 가려지지 않아 필수가 아니다 —
    /// 그래도 붙인 것은 일관성이 더 읽기 좋기 때문이다.
    ///
    /// ⚠️ **왕복이 정확하지 않다(실측)**: `12`·`3`·`2.9`·`17`·`16`·`373`·
    /// `359`는 도→라디안→도 왕복이 정확하지만 **`15`는
    /// `14.999999999999998`, `29`는 `29.000000000000004`가 된다.**
    public static func snapped(radians: Double) -> (snapped: Bool, radians: Double) {
        let core = snapped(degrees: Self.degrees(fromRadians: radians))
        guard core.snapped else { return (false, radians) }
        return (true, Self.radians(fromDegrees: core.degrees))
    }

    /// 회전이 이번 프레임에 새로 흡착에 진입했는지 판정한다(도).
    ///
    /// **정의역**: 두 인자는 흡착 판정에 넣기 전의 원시 각도(도)다 — 직전
    /// 프레임의 `snapped(degrees:)` 결과도, 정규화된 값도 아니다. 이 정의역을
    /// 혼동하면 아래 랩어라운드 로직이 무너진다.
    ///
    /// **규칙**: 현재가 흡착 중이고, (직전이 흡착 아니었거나 ‖ 직전과 현재의
    /// 흡착 목표가 다르면) 참이다. 상위 설계서의 "**같은 가이드**에 계속
    /// 붙어 있는 동안에는 재발화하지 않는다 — 걸리는 순간에만 발화한다"를
    /// 그대로 구현한 것이다.
    ///
    /// **목표 비교를 `normalized`에 통과시켜야 하는 이유(실측)**: 정규화
    /// 없이 그냥 빼면 `359° → 1°`에서 두 목표가 `360.0`과 `0.0`이 되어
    /// `|360 − 0| = 360 >= 15`로 "다른 그리드"로 오판하고 **발화한다.** 두
    /// 목표는 원 위에서 **같은 지점**(0° ≡ 360°)이다. 소비자 정보는
    /// `normalized(degrees:)` 문서 참고.
    ///
    /// **`guard previous.isFinite`가 필요한 이유(실측)**: 없으면 `NaN` 직전
    /// 각도가 "직전 미흡착"으로 분류되어 **발화한다**(현재가 흡착 중이면).
    /// Bool 판정에서 비유한 입력의 정직한 후퇴는 **거짓(미발화)**이다.
    ///
    /// **`current`에 유한성 가드를 두지 않는 이유**: `now.snapped`가 이미
    /// 전부 막는다 — 넣으면 증인 0건의 죽은 가드가 된다.
    ///
    /// **`>= gridStepDegrees` 비교의 근거를 좁혀 적는다.** "두 목표가 같으면
    /// 차가 정확히 0, 다르면 최소 `gridStepDegrees`"는 **일반적으로 참이
    /// 아니다** — 실측: 그리드 인덱스가 약 `4.5e15`(약 1.9e14 바퀴)에
    /// 이르면 되곱 반올림으로 인접 그리드 후보의 차가 **`8.0`**이 되어
    /// *다른 그리드인데 미발화*한다. 실사용 도달 불가지만 **"항상 그렇다"고
    /// 적지 않는다** — 이 저장소는 구조적 보장을 주장했다가 반증된 사례를
    /// 세 번 겪었다. 정규화를 통과한 뒤에도 이 반례가 남는지는
    /// **미실측**이다.
    ///
    /// **`Double ==`를 쓰지 않는 이유**: 이 저장소는 상수 리터럴 단언이
    /// 지배적이고(`edgeHideThreshold == 88`·`cornerPushThreshold == 56`·
    /// `hitSize == 44`), 정확히 표현되는 값에 한해 계산 결과 비교도
    /// 있다(`fitScale == 0`·`value == 250`). 오차가 누적되는 실수 비교에는
    /// `isClose`를 쓴다. 여기서 비교하는 두 정규화 목표값은 오차가 누적되는
    /// 계산 결과이므로 그 축에 속한다 — `abs(...) >= gridStepDegrees`는
    /// 임계가 `gridStepDegrees`에서 파생되므로 두 번째 상수를 만들지
    /// 않는다.
    public static func entersSnap(fromDegrees previous: Double, toDegrees current: Double) -> Bool {
        guard previous.isFinite else { return false }
        let now = snapped(degrees: current)
        guard now.snapped else { return false }
        let before = snapped(degrees: previous)
        guard before.snapped else { return true }
        return abs(normalized(degrees: before.degrees) - normalized(degrees: now.degrees)) >= gridStepDegrees
    }

    /// `entersSnap(fromDegrees:toDegrees:)`의 라디안 어댑터.
    ///
    /// **합성으로 위임해도 안전한 이유는 반환이 `Bool`이기 때문이다.** 각도가
    /// 밖으로 나가지 않으므로, `degrees(fromRadians:)`가 극단 입력에서
    /// `inf`를 내더라도 그 `inf`가 레이어 `rotation`에 앉을 경로가 없다.
    /// `normalized(radians:)`가 같은 합성을 쓸 수 **없었던 것**과 정확히
    /// 갈리는 지점이다(그쪽은 각도를 반환한다).
    ///
    /// 유한성 가드는 도 본체에 **한 번만** 있다 — 비유한 라디안은 비유한
    /// 도로 변환되므로 한 가드가 두 표면을 덮는다.
    ///
    /// ⚠️ `|r| >= 3.1375664143845866e306`이면 도 변환이 `inf`가 되어
    /// `previous.isFinite`가 거짓 → **진입이 발화하지 않는다.** 정직한
    /// 후퇴이며 실사용 도달 불가지만 **테스트 증인이 0건이다.**
    public static func entersSnap(fromRadians previous: Double, toRadians current: Double) -> Bool {
        entersSnap(fromDegrees: Self.degrees(fromRadians: previous),
                   toDegrees:   Self.degrees(fromRadians: current))
    }
}

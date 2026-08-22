import Foundation

/// 몇 손가락이 어떻게 움직이는가 (v4 §5.9 라우팅 표의 **열**).
///
/// **`HandleGesture`(탭/드래그)와 다른 축이다.** `HandleGesture`는 "이 히트를
/// 어떤 제스처로 볼 것인가"를 가르는 핸들 판정 필터고, 이쪽은 "몇 손가락이
/// 어떻게 움직이는가"를 가르는 라우팅 표의 열이다. 둘을 합치면 `.drag`
/// 하나가 1손가락 드래그인지 2손가락 드래그인지 표현할 수 없게 되어 §5.9
/// 표의 AC-1(1손가락)과 AC-3/AC-6(2손가락)을 애초에 구분해 판정할 수 없다.
///
/// **손가락 수를 `count: Int` 필드로 받지 않는다.** `Int`를 받으면 0개·3개
/// 이상도 표현 가능해져 표에 없는 분기가 판정 함수 안에 생긴다 — 그 분기를
/// 무엇으로 채울지는 코드가 아니라 사람이 매번 다시 결정해야 한다. 3종
/// 한정 `enum`은 표에 없는 입력 자체를 컴파일 시점에 없앤다.
///
/// **`twoFingerPinchRotate`를 줄이지 않는다.** §5.9 표의 셀이 "2손가락
/// 핀치·회전"(AC-2/AC-5) 하나이지 핀치와 회전이 별도 라우팅으로 갈리지
/// 않는다. 줄여서 `twoFingerPinch`로 두면 "핀치와 별개로 회전도 있다"는
/// 인상을 주어, 언젠가 `twoFingerRotate`를 네 번째 케이스로 추가하는
/// 변경이 자연스러워 보이게 된다 — 그 변경은 `route`의 6-arm 전수 switch를
/// 컴파일 에러로 깨뜨려야 맞는데, 이름을 미리 갈라 두면 그 방어가 무뎌진다.
public enum FingerPattern: Equatable, Sendable {
    case oneFingerDrag
    case twoFingerPinchRotate
    case twoFingerDrag
}

/// 제스처가 확정된 뒤 실제로 실행할 조작 (v4 §5.9 라우팅 표의 **결과**).
public enum GestureRoute: Equatable, Sendable {
    case moveLayer
    case resizeRotateLayer
    case panCanvas
    case zoomCanvas
}

/// 손가락 패턴(`FingerPattern`)과 선택 여부(`hasSelection`)로부터 조작
/// (`GestureRoute`)을 판정하는 상태 기계 (`EDITOR-10`, v4 §5.9).
public struct GestureRouter: Equatable, Sendable {
    /// 현재 진행 중인 라우트. **`case idle`을 별도로 만들지 않는다.**
    /// `Optional`이 이미 "활성 라우트 없음"이라는 뜻이고,
    /// `HandlePlacement.box: Box?`·`LayerStore.selection: Entry?`와 같은
    /// 표현이다.
    public private(set) var active: GestureRoute?

    public static let idle = GestureRouter()

    /// **`private`이다.** 밖에서 `active`를 날조해 만들 수 있게 열면
    /// `started`·`ended`가 실제로 거쳐야 하는 전이를 건너뛴 `GestureRouter`를
    /// 테스트가 `Given`으로 바로 구성할 수 있게 된다 — 그 상태는 표
    /// 판정(`route`)을 지나지 않았으므로 `활성_라우팅은_종료_신호_없는_재진입_started로_바뀌지_않는다`·
    /// `종료_신호_이후_재진입은_이전_세션의_판정을_이어받지_않는다`가 검증하는
    /// 대상 자체를 우회하는 거짓 초록이 된다. 활성 상태는 반드시
    /// `.idle.started(...)`를 거쳐서만 만들어져야 한다.
    private init(active: GestureRoute? = nil) {
        self.active = active
    }

    /// `started`가 표를 거쳐 새 활성 상태를 만든다.
    ///
    /// **왜 가드가 필요한가.** v4 §13: 두 인식기가 동시에 물리면 레이어가
    /// 순간이동한다. 활성 중 재판정을 허용하면 손가락 하나가 더 닿는 순간
    /// 라우트가 갈아타 그 증상이 그대로 재현된다 — 그래서 이미 활성 중이면
    /// 표를 다시 거치지 않고 자기 자신을 그대로 낸다. 유휴일 때만 `route`를
    /// 거친다.
    ///
    /// **이 가드가 막는 것과 막지 못하는 것.** 막는 것은 **동시 시작**이다.
    /// **해제 후 즉시 재잠금은 막지 못한다** — 두 인식기가 동시에 살아
    /// 있으면 먼저 끝난 쪽의 `onEnded`가 잠금을 풀고, 살아 있는 쪽의 다음
    /// `onChanged`가 `started`를 불러 **다른 라우트로 즉시 재잠금**한다 —
    /// §13의 순간이동이 그대로 재현된다. **`ended()`를 누가 언제 보내는가가
    /// 재발 여부를 정하며, 이 타입에는 그것을 통제할 입력이 없다.** 수신자는
    /// `EDITOR-11`(`ExclusiveGesture` 결합)이다.
    ///
    /// **측정된 변이 킬셋.** 이 가드를 제거하면 AC-7~13 7건 중 **6건**이
    /// 죽고 **AC-8만 살아남는다**(실측: 실제로 6 issues 실패, AC-8만 통과).
    /// AC-8이 약한 것은 인코딩 실수가 아니라 PRD Given의 성질이다 — 선택
    /// 없음에서 1손가락·2손가락 드래그가 둘 다 캔버스 팬이라 재판정해도
    /// 답이 같기 때문이다.
    public func started(_ pattern: FingerPattern, hasSelection: Bool) -> GestureRouter {
        guard active == nil else { return self }
        return GestureRouter(active: Self.route(pattern, hasSelection: hasSelection))
    }

    /// 활성 라우팅을 풀고 유휴로 되돌린다. 다음 `started`는 이 시점의 최신
    /// 선택 상태로 표를 다시 거쳐 새로 판정한다(AC-14).
    ///
    /// **멱등(AC-15)이지만 그 단언의 킬셋은 하나뿐이다.** `ended()`가
    /// `.idle`을 내든 `self`를 내든 유휴에서는 같은 값이라, AC-15를 죽이는
    /// 변이는 `precondition(active != nil)` 류를 끼워 넣는 것뿐이다.
    /// `ended()`의 **동작**을 실제로 검증하는 것은 AC-14다.
    ///
    /// ⚠️ **잠금에 주인이 없다 (인계 사항).** 이 함수는 **누가 언제
    /// 부르는지를 통제하지 못한다.** 두 제스처 인식기가 동시에 살아 있으면
    /// 먼저 끝난 쪽의 `onEnded`가 여기를 불러 잠금을 풀고, 아직 살아 있는
    /// 쪽의 다음 `onChanged`가 `started`를 불러 **다른 라우트로 즉시
    /// 재잠금**한다 — v4 §13이 경고한 순간이동이 그대로 재현된다.
    /// `started`의 활성 가드가 막는 것은 **동시 시작**이지 **해제 후 즉시
    /// 재잠금**이 아니다. **`ended()`를 누가 보내는가가 §13 재발 여부를
    /// 정하며, 수신자는 `EDITOR-11`(`ExclusiveGesture` 결합)이다.**
    public func ended() -> GestureRouter {
        .idle
    }

    /// v4 §5.9 라우팅 표 — 손가락 패턴 × 선택 여부 → 조작.
    ///
    /// **`private`이다.** `public`으로 열면 배선 쪽에서 매 프레임 이 함수를
    /// 직접 불러 `GestureRouter`의 상태 갱신을 건너뛰는 경로가 생기는데,
    /// 그것이 v4 §13이 경고한 "두 인식기가 동시에 물려 레이어가
    /// 순간이동"하는 상황이다. 표는 `started`를 거쳐서만 닿아야 한다.
    /// **단, 이것은 재사용만 막고 복제는 막지 못한다** — 호출부가
    /// `if hasSelection && pattern == .oneFingerDrag`를 직접 적는 것은
    /// 여전히 가능하다. `private`은 규율이지 그 복제를 잡아내는 컴파일
    /// 검사가 아니다.
    ///
    /// **6 arm을 전수 열거하고 `_` 와일드카드를 쓰지 않는다.**
    /// `case (.twoFingerDrag, _): return .panCanvas`로 AC-3/AC-6 두 줄을
    /// 합치면 코드는 짧아지지만, 훗날 `FingerPattern`에 케이스가 추가돼도
    /// 이 switch가 여전히 exhaustive해 보여 컴파일이 조용히 통과한다. 6개
    /// 조합을 그대로 나열하면 이 switch 자체가 "패턴은 3종으로 한정된다"는
    /// 규칙의 컴파일 시점 감시자가 된다.
    ///
    /// **`hasSelection: Bool` 인자의 위험(잡히지 않는 부분).** 인자가
    /// `Bool` 하나뿐이라 `store.selection == nil`을 실수로 뒤집어
    /// (`!= nil`) 넘겨도 타입은 통과한다. 결과는 "선택했는데 캔버스가
    /// 팬되는" 조용한 오작동이고, 이 단위(라우팅 표)의 테스트는 입력이
    /// 무엇이든 여전히 전부 초록이다 — 표는 자신에게 들어온 `Bool`이
    /// 올바른 값인지 검증할 수 없다. 인자 라벨 `hasSelection:`이 호출부
    /// 코드 리뷰에서의 유일한 방어선이고, 실제 오배선 관측은 `EDITOR-11`의
    /// 통합 축에서만 가능하다.
    private static func route(_ pattern: FingerPattern, hasSelection: Bool) -> GestureRoute {
        switch (pattern, hasSelection) {
        case (.oneFingerDrag,        true):  return .moveLayer          // AC-1
        case (.twoFingerPinchRotate, true):  return .resizeRotateLayer  // AC-2
        case (.twoFingerDrag,        true):  return .panCanvas          // AC-3
        case (.oneFingerDrag,        false): return .panCanvas          // AC-4
        case (.twoFingerPinchRotate, false): return .zoomCanvas         // AC-5
        case (.twoFingerDrag,        false): return .panCanvas          // AC-6
        }
    }
}

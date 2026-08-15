import Foundation

/// 히트 판정에 필요한 제스처 종류. **이 타입은 제스처를 인식하지 않는다.**
///
/// 탭/드래그를 가르는 임계값·타이머·배타 라우팅은 `EDITOR-10`의 몫이고, 여기
/// 들어오는 값은 **이미 확정된 결과**다. 인식을 이쪽으로 끌어오면 순수 값
/// 계산에 시간이 들어오고, 그 순간 이 패키지는 테스트에서 시계를 붙잡아야 한다.
///
/// 케이스가 둘뿐인 것은 **판정을 실제로 가르는 축이 둘뿐**이기 때문이다.
/// 롱프레스·핀치를 미리 넣지 않는다 — 지금 그것으로 갈리는 판정이 없다.
///
/// `CaseIterable`을 붙이지 않는다 — **전 케이스를 순회할 소비자가 지금 없다.**
/// (이 저장소가 `allCases`를 피한다는 뜻이 아니다. `Corner`·`Edge`는 둘 다
/// `CaseIterable`이고 `Set(Edge.allCases)`가 상시 쓰인다. `edgeOrder`가 명시
/// 상수인 이유는 별개다 — 선언 순서와 **달라야** "allCases를 대신 쓴다"는
/// 변이가 죽기 때문이다.)
public enum HandleGesture: Sendable {
    case tap
    case drag
}

extension HandleGesture {
    /// 이 제스처에서 **최종 후보로 유효한가** (BR-3).
    ///
    /// `.drag`가 `.delete`를 버리는 것이 전부다. 삭제에는 "즉시 삭제"라는 탭
    /// 동작만 정의돼 있고 드래그로 끌 대상이 아니다. 삭제는 좌상단 코너와
    /// **정확히 같은 화면 좌표**(`HandlePlacement.Box.delete`)라, 이 한 줄이
    /// 없으면 좌상단 코너는 영영 리사이즈할 수 없다.
    ///
    /// **`internal`인 이유는 "밖에서 이것만 따로 부를 시나리오가 없어서"다.**
    /// 정책 복제를 막기 위해서가 **아니다** — `hitCandidates`가 `public`이고
    /// `PlacedHandle.handle`·`Handle.delete`도 `public`이라
    /// `candidates.first { $0.handle != .delete }` 한 줄이면 누구나 정책을
    /// 재기술할 수 있다. `internal`은 재사용만 막고 복제는 못 막는다.
    ///
    /// **타입이 보장하는 것**: `hitHandle(at:for:)`가 정책을 적용한 **유일한
    /// 제공자**다. 그것을 부르는 호출부는 BR-3을 자동으로 얻는다.
    /// **타입이 보장하지 않는 것**: 후보 목록을 직접 거르는 것을 막지 못한다.
    /// 그것을 하지 않는 것은 **규율이지 컴파일러가 검사하는 사실이 아니다.**
    func accepts(_ handle: Handle) -> Bool {
        switch self {
        case .tap:  return true
        case .drag: return handle != .delete
        }
    }
}

extension HandlePlacement {

    /// 핸들 하나의 히트 사각형 **한 변**(pt). **화면 좌표축 정렬 정사각형**이다
    /// (v4 §5.7, Apple HIG 최소 터치 타깃).
    ///
    /// **`internal`이다.** 명명된 프로덕션 소비자가 이 파일 밖에 없고, 테스트는
    /// `@testable import`로 닿는다. `public`으로 열면 호출부가
    /// `hitSize / 2 * surface.scale`로 **자기 판정을 짜는 가장 짧은 경로**가
    /// 생기는데, 그것이 정확히 FR-6이 막으려는 것이다. 필요해지면 그때 연다.
    ///
    /// **시각 크기 12pt는 여기 없다.** 그리기는 `EDITOR-11`의 몫이고, 지금
    /// 상수를 세워 두면 소비자 없는 숫자가 된다(`LayoutDocument`가 호출부 없는
    /// 별칭을 지운 선례). 둘이 **다른 값인 것**이 §5.7의 요점이다.
    ///
    /// **반쪽(22)을 별도 상수로 두지 않는다.** 두 벌이 되는 순간 한쪽만 고치는
    /// 변경이 가능해지고, 그때 "44라고 적힌 사각형이 실제로는 40"이 된다.
    static let hitSize: Double = 44

    /// 이 지점에 겹치는 핸들 **전부**를, `orderedHandles`의 순서 그대로 (FR-1).
    ///
    /// **`orderedHandles`의 부분열이다.** 순서를 여기서 다시 정하지 않는다 —
    /// 두 벌이 되면 `EDITOR-6`이 `edgeOrder`를 건드릴 때 그리는 순서와 잡히는
    /// 순서가 갈라진다.
    ///
    /// **제스처 종류를 요구하지 않는다.** 손가락이 막 닿은 순간에는 아직 탭인지
    /// 드래그인지 알 수 없고, 그때도 "이 지점에 무엇이 겹쳐 있는지"는 즉시
    /// 나와야 눌린 핸들을 하이라이트할 수 있다.
    ///
    /// **선택이 없으면 빈 배열이다**(FR-5). `orderedHandles`가 `box == nil`에서
    /// 이미 `[]`를 내므로 분기가 없다.
    ///
    /// **비유한 지점은 자연히 빈 배열이다.** `NaN`은 `<=` 비교가 전부 거짓이라
    /// 어떤 사각형에도 들지 않는다. 판정을 `!(abs(d) > half)`로 뒤집으면 안 되는
    /// 이유이기도 하다 — 그 형태는 `NaN`을 **히트로** 만든다.
    public func hitCandidates(at point: Vec2) -> [PlacedHandle] {
        orderedHandles.filter { Self.isHit(point, near: $0.position) }
    }

    /// 제스처가 확정된 뒤의 최종 하나. **없으면 `nil` = "핸들 아님"** (FR-3·FR-4).
    ///
    /// **반드시 `hitCandidates(at:)`를 거친다.** 독립 구현하면 두 API가 서로 다른
    /// 답을 낼 수 있고, 그때 "하이라이트된 핸들과 실제로 잡힌 핸들이 다른"
    /// 증상이 나온다 — 사용자에게는 앱이 자기가 보여준 것을 배신하는 것으로 보인다.
    ///
    /// **"핸들 아님"을 별도 케이스로 만들지 않는다.** `Optional`이 이미 그 뜻이고,
    /// `box: Box?`·`LayerStore.selection: Entry?`와 같은 표현이다.
    public func hitHandle(at point: Vec2, for gesture: HandleGesture) -> PlacedHandle? {
        hitCandidates(at: point).first { gesture.accepts($0.handle) }
    }

    /// 화면 축 정렬 44×44 사각형 안인가 (FR-2·BR-1·BR-2).
    ///
    /// **두 축을 따로 비교한다 — 유클리드 거리로 바꾸지 않는다.** 거리로 바꾸면
    /// 사각형이 원이 되고 코너의 대각 여유가 √2배 좁아진다((20,20)이 사각형에서는
    /// 히트, 반지름 22 원에서는 28.28로 미스).
    ///
    /// **두 축 모두 `<=`다**(BR-2). x축만 `<=`로 두고 y축을 `<`로 바꾸는 변이는
    /// 픽스처 A의 y축 경계 쌍((270,78) / (270,77.5))에서만 죽는다.
    ///
    /// **`half`는 `surface`·`box`에서 파생하지 않는다.** 상수 하나를 반으로
    /// 나눈 것이 전부이며, 그것이 FR-6의 내용이다.
    private static func isHit(_ point: Vec2, near position: Vec2) -> Bool {
        let half = hitSize / 2
        return abs(point.x - position.x) <= half
            && abs(point.y - position.y) <= half
    }
}

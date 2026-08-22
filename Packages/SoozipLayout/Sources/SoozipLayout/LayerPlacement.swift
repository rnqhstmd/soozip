import Foundation
import SoozipGeometry

extension LayerTransform {

    /// 클램프를 지난 토큰으로 저장 좌표(`x`·`y`)를 옮긴 새 변형을 낸다.
    ///
    /// **왜 이 경로가 필요한가.** 레이어의 진짜 저장 상태는 `LayerFrame`이
    /// 아니라 여기다. `LayerFrame`은 매 프레임 만들어지는 중간값이고
    /// `Codable`이 아니다 — 문서에 영속화되는 것은 `LayerTransform`이다.
    /// 기하 계층(`LayerFrame.placed(at:)`, `EDITOR-10`)만 막으면
    /// `transform.x = surface.toLogical(point).x` 한 줄이 게이트를 통째로
    /// 우회하는데, 그 우회는 기하 쪽 테스트를 전혀 건드리지 않아 전부
    /// 초록으로 남는다 — 게이트가 장식이 된다.
    ///
    /// **`LayerTransform(x:y:)` 우회로와 갈리는 지점.** 그 생성자는
    /// `scale`·`rotation`·`opacity`·`z`에 전부 기본값이 있어서(`LayerTransform.init(x:y:scale:rotation:opacity:z:)`의
    /// 기본값), 우회하면 클램프만 빠지는 게 아니라 네 필드가 조용히 리셋된다
    /// (1·0·1·0). `placed(at:)`가 유일하게 나머지를 보존하는 경로라는
    /// 것이 이 게이트를 쓰게 만드는 실질 유인이다.
    ///
    /// **보존도 타입이 강제하지 못한다.** 이 함수는 `LayerTransform`의
    /// 메서드라 `self.scale` 등에 얼마든지 닿을 수 있다. 보존을 막는 것은
    /// 테스트다 — `placed는_scale_rotation_opacity_z를_그대로_보존한다`.
    ///
    /// **`var result = self`인 이유.** 명시 생성자로 쓰면 `LayerTransform`에
    /// 새 필드가 추가될 때 그 필드가 기본값으로 조용히 리셋된다 — init의
    /// 네 필드(`scale`·`rotation`·`opacity`·`z`)가 전부 기본값을 갖기
    /// 때문이다(`LayerTransform.init(x:y:scale:rotation:opacity:z:)`의
    /// 기본값). `var result = self`는 새 필드를
    /// 자동으로 보존한다. 보존을 테스트가 아니라 구조가 지게 하는 유일한
    /// 부분이다.
    ///
    /// **형제 함수 `LayerFrame.placed(at:)`는 반대로 명시 생성자를 쓰는데
    /// 그것도 옳다.** `LayerFrame.init`에는 기본값이 없어서 새 필드가
    /// 생기면 컴파일 에러로 즉시 드러나기 때문이다. 두 함수의 형태가
    /// 다른 것은 불일치가 아니라 각 타입의 생성자 성질에 맞춘 결과다.
    /// "일관성"을 이유로 이쪽을 명시 생성자로 바꾸지 마라.
    public func placed(at center: ClampedLayerCenter) -> LayerTransform {
        var result = self
        result.x = center.value.x
        result.y = center.value.y
        return result
    }
}

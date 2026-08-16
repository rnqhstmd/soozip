import Foundation
import SoozipGeometry

extension LayerKind {
    /// 이 **종류**가 원칙적으로 허용하는 변 (v4 §5.7).
    ///
    /// `photo`·`stamp`·`drawing`은 비어 있다 — 한 축으로 늘이면 얼굴이 찌그러지고,
    /// 그건 되돌리는 법을 알기 전까지 사용자가 실수로 인식하지 못하는 훼손이다.
    /// `text`가 좌우뿐인 것은 폭이 줄바꿈 지점이고 높이는 내용이 정하기 때문이다.
    ///
    /// **종류 축의 문지기이지 핸들 존재의 전부가 아니다.** `HandlePlacement.init`의
    /// `screenShortSide`(= `frame.size.shortSide × surface.scale`)가
    /// `edgeHideThreshold`(88) 미만이면 이 프로퍼티가 무엇을 반환하든 변 핸들이
    /// 전부 사라진다 — **크기 축이 실제로 얹혔다.**
    ///
    /// 따라서 **`resizableEdges`는 종류 축만 답한다.** 실제로 그려지고 잡히는 변은
    /// `HandlePlacement.edges`이며, **두 축이 거기서 합류한다.**
    ///
    /// **`placement.edges`가 비었다고 이 값이 비었다고 결론짓지 마라** — 어느 축이
    /// 잘랐는지는 값만으로 구별되지 않는다. `SelectionTests`의
    /// `크기_축이_코너를_밀면_종류_축이_허용한_변이_보이지_않는다`가 그 합류를
    /// 고정한다(도형은 네 변을 허용하는데 판정값 50에서 `edges`가 빈다).
    public var resizableEdges: Set<Edge> {
        switch self {
        case .photo, .stamp, .drawing: return []
        case .text:                    return [.left, .right]
        case .shape:                   return Set(Edge.allCases)
        }
    }
}

extension LayerStore {
    /// 선택된 레이어의 핸들 배치. **선택이 없으면 `.empty`**.
    ///
    /// `baseSizeOf`가 받는 것은 **`Layer.baseSize`가 `nil`인 넷뿐이다.**
    /// 중심·회전은 `LayerTransform.x/y/rotation`에서, scale 곱은
    /// `LayerTransform.frame(baseSize:)`에서 나온다 — **이 함수는 그 셋을 새로
    /// 만들지 않고 경유만 한다.** 프레임 전체를 주입받으면 호출부가 중심·회전을
    /// 조용히 덮어쓸 수 있고, 그때 핸들은 그림과 다른 자리에 뜬다.
    ///
    /// - Parameter baseSizeOf: 측정에 실패하면 **비유한 값을 그대로 내도 된다.**
    ///   `HandlePlacement`가 유한성을 가드하고 빈 배치를 낸다.
    public func selectionHandles(on surface: CanvasSurface,
                                 baseSizeOf: (Layer) -> Size2) -> HandlePlacement {
        guard let entry = selection else { return .empty }
        let frame = entry.layer.transform.frame(
            baseSize: entry.layer.baseSize ?? baseSizeOf(entry.layer))
        return HandlePlacement(frame: frame,
                               edges: entry.layer.kind.resizableEdges,
                               on: surface)
    }
}

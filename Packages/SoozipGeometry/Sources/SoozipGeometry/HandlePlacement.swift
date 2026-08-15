import Foundation

public enum Handle: Hashable, Sendable {
    case corner(Corner)
    case edge(Edge)
    case rotate
    case delete
}

public struct PlacedHandle: Equatable, Sendable {
    public let handle: Handle
    public let position: Vec2
}

public struct PlacedEdge: Equatable, Sendable {
    public let edge: Edge
    public let position: Vec2
}

/// 레이어 선택 시 그리는 핸들들의 화면 좌표 배치.
///
/// 이 값은 `surface`가 바뀌는 순간 통째로 무효다. 저장하지 말고 매 프레임
/// 다시 만든다 — 제스처 시작 시점의 배치를 잡아 두고 팬 중에 쓰면 손가락은
/// 새 화면 좌표에 있고 핸들은 옛 자리에 있어 히트 판정이 조용히 빗나간다.
public struct HandlePlacement: Equatable, Sendable {
    public struct Box: Equatable, Sendable {
        public let topLeft: Vec2
        public let topRight: Vec2
        public let bottomRight: Vec2
        public let bottomLeft: Vec2
        public let edgeHandles: [PlacedEdge]
        public let rotate: Vec2
        public let rotateFlipped: Bool

        public func corner(_ corner: Corner) -> Vec2 {
            switch corner {
            case .topLeft:     return topLeft
            case .topRight:    return topRight
            case .bottomRight: return bottomRight
            case .bottomLeft:  return bottomLeft
            }
        }

        /// 결정에 따라 좌상단 코너와 정확히 같은 지점이다. `EDITOR-5`가 거리로만
        /// 고르면 동점이 나므로, 누가 이기는지는 `orderedHandles`의 순서 하나가 정한다.
        public var delete: Vec2 { topLeft }
    }

    public static let rotateGap: Double = 28
    public static let flipThreshold: Double = 40

    /// `Edge.allCases`에 기대지 않는다. 시계방향인 것이 이 불변식을 검증
    /// 가능하게 만든다 — 선언 순서(`left, right, top, bottom`)대로 적으면
    /// `allCases`와 완전히 같아져, "`allCases`를 대신 쓴다"는 변이가 어떤
    /// 테스트로도 죽지 않는다.
    public static let edgeOrder: [Edge] = [.top, .right, .bottom, .left]

    public let box: Box?

    public static let empty = HandlePlacement(box: nil)

    private init(box: Box?) {
        self.box = box
    }

    public init(frame: LayerFrame, edges: Set<Edge>, on surface: CanvasSurface) {
        guard frame.center.x.isFinite, frame.center.y.isFinite,
              frame.size.width.isFinite, frame.size.height.isFinite,
              frame.rotation.isFinite else {
            self.box = nil
            return
        }

        let topLeft = surface.toScreen(frame.corner(.topLeft))
        let topRight = surface.toScreen(frame.corner(.topRight))
        let bottomRight = surface.toScreen(frame.corner(.bottomRight))
        let bottomLeft = surface.toScreen(frame.corner(.bottomLeft))

        let edgeHandles = Self.edgeOrder.filter(edges.contains).map {
            PlacedEdge(edge: $0, position: surface.toScreen(frame.edgeMidpoint($0)))
        }

        // 로컬 −y를 toWorld와 같은 행렬로 회전한 단위 벡터. 정규화로 구하지
        // 않는다 — 높이 0에서 0으로 나누게 된다.
        let up = Vec2(x: sin(frame.rotation), y: -cos(frame.rotation))

        let topScreen = surface.toScreen(frame.edgeMidpoint(.top))

        // 기준선은 뷰포트 상단이다. v4 §5.7의 문면은 '캔버스 상단'이지만 그
        // 목적은 '위에 그리면 화면 밖이거나 툴바에 가린다'이고, 줌+팬에서
        // 둘이 갈라진다. (실측: 뷰포트 390×844·post에서 줌 400%·center.y=1200이면
        // 캔버스 상단의 화면 y ≈ −1311이라, 툴바 바로 아래 레이어의 캔버스
        // 기준 판정값이 1331 > 40이 되어 뒤집히지 않고 회전 핸들이 화면 밖에
        // 놓인다.)
        //
        // up이 화면 아래를 향하면(up.y > 0) 뒤집기가 역효과다 — 안 뒤집은
        // 위치가 이미 툴바에서 멀어지는 방향인데 뒤집은 위치는 항상
        // 판정선보다 위가 된다(뒤집기가 막으려던 상황을 뒤집기가 만든다).
        // up은 레이어와 함께 회전하므로 이 역효과는 90°~270°에서 나타난다.
        // 수평(up.y == 0, 정확히 ±90°)은 세로로 무차별하므로 기존 동작을
        // 유지한다 — 뒤집든 안 뒤집든 rotate.y가 같고 핸들이 박스 반대쪽으로
        // 좌우 이동할 뿐이다. (실측: r=π, scale 0.5에서 뒤집으면
        // rotate.y = −38로 화면 밖, 안 뒤집으면 68로 화면 안.)
        let flipped = topScreen.y <= Self.flipThreshold && up.y <= 0

        let rotate: Vec2
        if flipped {
            let bottomScreen = surface.toScreen(frame.edgeMidpoint(.bottom))
            rotate = Vec2(x: bottomScreen.x - Self.rotateGap * up.x,
                          y: bottomScreen.y - Self.rotateGap * up.y)
        } else {
            rotate = Vec2(x: topScreen.x + Self.rotateGap * up.x,
                          y: topScreen.y + Self.rotateGap * up.y)
        }

        self.box = Box(topLeft: topLeft, topRight: topRight,
                       bottomRight: bottomRight, bottomLeft: bottomLeft,
                       edgeHandles: edgeHandles, rotate: rotate,
                       rotateFlipped: flipped)
    }

    public var orderedHandles: [PlacedHandle] {
        guard let box else { return [] }
        var result: [PlacedHandle] = [
            PlacedHandle(handle: .delete, position: box.delete),
            PlacedHandle(handle: .corner(.topLeft), position: box.topLeft),
            PlacedHandle(handle: .corner(.topRight), position: box.topRight),
            PlacedHandle(handle: .corner(.bottomRight), position: box.bottomRight),
            PlacedHandle(handle: .corner(.bottomLeft), position: box.bottomLeft),
            PlacedHandle(handle: .rotate, position: box.rotate),
        ]
        result += box.edgeHandles.map { PlacedHandle(handle: .edge($0.edge), position: $0.position) }
        return result
    }

    public var edges: Set<Edge> {
        guard let box else { return [] }
        return Set(box.edgeHandles.map { $0.edge })
    }
}

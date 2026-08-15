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

        /// 결정에 따라 좌상단 코너와 **정확히 같은 지점**이다. 판정은 거리를 보지
        /// 않으므로 이 둘은 언제나 함께 히트한다. 승자는 두 단계로 정해진다 —
        /// **제스처가 후보를 거르고**(`HandleGesture.accepts(_:)`), **살아남은 것 중
        /// `orderedHandles`의 순서가 고른다.**
        ///
        /// 그래서 탭이 삭제를 잡는 것은 **순서** 때문이고(`.tap`은 아무것도 거르지
        /// 않는다 — 배열에서 삭제가 좌상단보다 앞일 뿐이다), 드래그가 좌상단을 잡는
        /// 것만이 **제스처** 때문이다. 둘을 뭉뚱그려 "제스처가 정한다"로 읽으면
        /// 배열 순서를 재배열해도 탭 동작은 안 바뀔 것으로 오해하게 된다.
        ///
        /// **저장하지 않고 되짚는다** — 두 벌로 두면 `EDITOR-6`이 코너를 박스 밖으로
        /// 밀어내는 순간 삭제만 제자리에 남아, 스펙에 없는 오프셋이 조용히 생긴다.
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

    /// **히트 판정과 그리기의 우선순위 순서다.** 딕셔너리로는 표현할 수 없다 —
    /// `Dictionary` 순회 순서는 실행마다 다르고, `.delete`와 `.corner(.topLeft)`는
    /// **정확히 같은 좌표**라 그 비결정성이 곧바로 관측된다.
    ///
    /// 순서: `.delete` → 코너 4(TL·TR·BR·BL) → `.rotate` → 변(`edgeOrder`).
    /// `.delete`가 맨 앞인 것은 오버레이가 ✕를 좌상단 코너 **위에** 그리기 때문이다.
    ///
    /// **그리기는 이 배열을 역순으로 칠한다** — 정순으로 칠하면 먼저 칠한 ✕가
    /// 좌상단 코너 핸들 밑에 깔려 삭제 버튼이 조용히 사라진다. 겹친 좌표라
    /// 화면에서는 "✕가 원래 없는 것"처럼 보인다.
    ///
    /// **이 순서는 "유일한 규칙"이 아니라 폴백이다.** 겹침은 두 단계로 풀린다:
    ///
    /// 1. **제스처가 후보를 거른다** — 탭은 아무것도 거르지 않고, 드래그는 삭제를
    ///    뺀다(`hitHandle(at:for:)`). 삭제와 좌상단 코너의 동일 좌표 충돌이 **실제로
    ///    갈리는 것은 드래그 쪽뿐**이다 — 탭에서 삭제가 이기는 것은 아래 2번의 순서
    ///    덕이다. 이 거르기를 지우면 좌상단 코너는 영영 리사이즈할 수 없다.
    /// 2. **제스처로도 안 갈리면 이 순서가 정한다 — 「동점」이 아니라 「겹침 전부」다**
    ///    (BR-4). 히트 사각형이 44pt라 초소형 레이어에서는 네 코너가 서로의 사각형
    ///    안에 든다. 그때 손가락이 우하단 코너 **정중앙**에 있어도 드래그는 좌상단
    ///    코너를 잡는다 — **최근접이 아니라 순서가 이긴다.** 근접 우선이 필요해지면
    ///    그것은 이 배열의 문제가 아니라 `EDITOR-6`·`EDITOR-10`의 새 AC다.
    ///
    /// **이 주석의 부재가 실제로 비용을 냈다.** `EDITOR-5` PRD 초안이 코드만 읽고
    /// 1단계를 못 봐서 "좌상단 코너는 리사이즈 불가"를 수용한 채 나왔다.
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

    /// 실제로 제공된 변. **`edgeHandles`에서 파생한다 — 두 벌을 만들지 않는다.**
    ///
    /// **2026-08-15 기준 프로덕션 소비자 0건이다.** 그래도 남기는 이유는 둘이다.
    ///
    /// 1. **집합 축의 표현이다.** 좌표·순서를 벗겨낸 `Set<Edge>`라 "종류가 무엇을
    ///    허용했나"만 잰다. 같은 것을 `orderedHandles` 시퀀스 리터럴이나
    ///    `box.edgeHandles`로도 잴 수 있으므로 **유일한 관측면은 아니다** —
    ///    `text`(좌우 2변)에서만 가장 짧은 표현이다.
    /// 2. `EDITOR-6` 이후: 크기 축 필터가 `init`에 얹히면 이 값은 **두 축을 모두
    ///    통과한 최종 집합**이 된다. 그때 `SelectionTests.swift:223`
    ///    (`placement.edges == [.left, .right, .top, .bottom]`)와 `:232`
    ///    (`== [.left, .right]`)의 리터럴 단언은 **깨져야 정상**이다.
    ///    **`placement.edges == kind.resizableEdges` 형태로 고치지 말 것** —
    ///    같은 접근자로 양변을 만드는 동어반복이라 늘 초록이 되고,
    ///    `SelectionTests.swift:185`가 그 형태를 거부한 이유를 적어 뒀다.
    ///
    /// 히트 판정은 이것을 쓰지 않는다. 변 핸들은 좌표까지 필요하고 그건
    /// `orderedHandles`에 이미 있다.
    public var edges: Set<Edge> {
        guard let box else { return [] }
        return Set(box.edgeHandles.map { $0.edge })
    }
}

import Foundation

public enum Corner: CaseIterable, Hashable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    /// 중심 기준 로컬 좌표의 부호
    public var sign: (x: Double, y: Double) {
        switch self {
        case .topLeft:     return (-1, -1)
        case .topRight:    return ( 1, -1)
        case .bottomLeft:  return (-1,  1)
        case .bottomRight: return ( 1,  1)
        }
    }

    public var opposite: Corner {
        switch self {
        case .topLeft:     return .bottomRight
        case .topRight:    return .bottomLeft
        case .bottomLeft:  return .topRight
        case .bottomRight: return .topLeft
        }
    }
}

public enum Edge: CaseIterable, Hashable, Sendable {
    case left, right, top, bottom

    /// 중심 기준 로컬 좌표의 부호(퇴화한 축은 0)
    public var sign: (x: Double, y: Double) {
        switch self {
        case .left:   return (-1, 0)
        case .right:  return ( 1, 0)
        case .top:    return ( 0, -1)
        case .bottom: return ( 0, 1)
        }
    }

    /// 이 변을 끌 때 고정되는 반대쪽 변
    public var opposite: Edge {
        switch self {
        case .left:   return .right
        case .right:  return .left
        case .top:    return .bottom
        case .bottom: return .top
        }
    }

    public var isHorizontal: Bool { self == .left || self == .right }
}

/// 레이어의 기하 상태. 논리좌표계(폭 1080 고정)에서만 쓴다.
public struct LayerFrame: Equatable, Sendable {
    public var center: Vec2
    public var size: Size2
    public var rotation: Double   // 라디안

    public init(center: Vec2, size: Size2, rotation: Double) {
        self.center = center
        self.size = size
        self.rotation = rotation
    }

    /// 월드(논리) 좌표 → 레이어 로컬 좌표.
    /// 회전된 레이어를 드래그·리사이즈할 때 반드시 이 변환을 거친다.
    public func toLocal(_ p: Vec2) -> Vec2 {
        let dx = p.x - center.x
        let dy = p.y - center.y
        let c = cos(-rotation)
        let s = sin(-rotation)
        return Vec2(x: dx * c - dy * s,
                    y: dx * s + dy * c)
    }

    /// 레이어 로컬 좌표 → 월드(논리) 좌표.
    public func toWorld(_ p: Vec2) -> Vec2 {
        let c = cos(rotation)
        let s = sin(rotation)
        return Vec2(x: center.x + p.x * c - p.y * s,
                    y: center.y + p.x * s + p.y * c)
    }

    public func corner(_ corner: Corner) -> Vec2 {
        pointOnBoundary(sign: corner.sign)
    }

    /// 변의 중점. `corner(_:)`와 같은 규약(`toWorld` 경유)으로 계산한다 — 부호만 다르다.
    public func edgeMidpoint(_ edge: Edge) -> Vec2 {
        pointOnBoundary(sign: edge.sign)
    }

    /// `corner(_:)`·`edgeMidpoint(_:)`가 공유하는 계산. 중심 기준 로컬 좌표의
    /// 부호(±1 또는 퇴화한 축의 0)를 반너비·반높이에 곱해 `toWorld`로 옮긴다.
    private func pointOnBoundary(sign: (x: Double, y: Double)) -> Vec2 {
        toWorld(Vec2(x: sign.x * size.width  / 2,
                    y: sign.y * size.height / 2))
    }
}

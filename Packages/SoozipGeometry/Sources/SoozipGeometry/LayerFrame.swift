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
        let sign = corner.sign
        return toWorld(Vec2(x: sign.x * size.width  / 2,
                            y: sign.y * size.height / 2))
    }
}

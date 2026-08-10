import CoreGraphics
import SoozipGeometry

// SoozipGeometry는 CoreGraphics에 의존하지 않는다 — Windows에서도 빌드되어야 하고,
// 기하 로직이 UI에서 물리적으로 분리되는 효과가 덤으로 따라온다.
// SwiftUI와 잇는 지점이 이 파일 하나뿐이므로 변환 비용도 여기에만 있다.

public extension CGPoint {
    init(_ v: Vec2) { self.init(x: v.x, y: v.y) }
}

public extension Vec2 {
    init(_ p: CGPoint) { self.init(x: Double(p.x), y: Double(p.y)) }
}

public extension CGSize {
    init(_ s: Size2) { self.init(width: s.width, height: s.height) }
}

public extension Size2 {
    init(_ s: CGSize) { self.init(width: Double(s.width), height: Double(s.height)) }
}

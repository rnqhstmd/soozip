import Foundation

/// 플랫폼 독립 2D 좌표. Apple 플랫폼에서는 `CGPoint`와 상호 변환한다(CGInterop).
///
/// CoreGraphics를 쓰지 않는 이유: 이 패키지는 Windows에서도 빌드·테스트되어야 한다.
/// 기하 로직을 UI에서 물리적으로 분리하는 효과는 덤이다.
public struct Vec2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(x: 0, y: 0)
}

/// 플랫폼 독립 크기. Apple 플랫폼에서는 `CGSize`와 상호 변환한다.
public struct Size2: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = Size2(width: 0, height: 0)

    public var shortSide: Double { min(width, height) }
    public var longSide: Double { max(width, height) }
}

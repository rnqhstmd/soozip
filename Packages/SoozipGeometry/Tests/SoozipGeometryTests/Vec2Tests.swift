import Testing
@testable import SoozipGeometry

@Test func Vec2는_성분으로_생성되고_비교된다() {
    let a = Vec2(x: 3, y: 4)
    let b = Vec2(x: 3, y: 4)
    #expect(a == b)
    #expect(a.x == 3)
    #expect(a.y == 4)
}

@Test func Vec2_zero는_원점이다() {
    #expect(Vec2.zero == Vec2(x: 0, y: 0))
}

@Test func Size2는_폭과_높이를_갖는다() {
    let s = Size2(width: 200, height: 100)
    #expect(s.width == 200)
    #expect(s.height == 100)
}

@Test func Size2의_짧은변과_긴변() {
    let s = Size2(width: 200, height: 100)
    #expect(s.shortSide == 100)
    #expect(s.longSide == 200)
}

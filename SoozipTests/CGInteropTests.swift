import Testing
import CoreGraphics
import SoozipGeometry
@testable import Soozip

@Test func Vec2와_CGPoint는_상호변환된다() {
    let v = Vec2(x: 123.5, y: 456.75)
    let p = CGPoint(v)
    #expect(p.x == 123.5)
    #expect(p.y == 456.75)
    #expect(Vec2(p) == v)
}

@Test func Size2와_CGSize는_상호변환된다() {
    let s = Size2(width: 1080, height: 1350)
    let cg = CGSize(s)
    #expect(cg.width == 1080)
    #expect(cg.height == 1350)
    #expect(Size2(cg) == s)
}

@Test func 논리좌표_왕복변환은_값을_잃지_않는다() {
    // 논리좌표는 Double이고 CGFloat도 64비트 플랫폼에서 Double이다.
    // 왕복에서 값이 변하면 레이어가 저장할 때마다 조금씩 밀린다.
    let original = Vec2(x: 1079.9999, y: 1349.0001)
    #expect(Vec2(CGPoint(original)) == original)
}

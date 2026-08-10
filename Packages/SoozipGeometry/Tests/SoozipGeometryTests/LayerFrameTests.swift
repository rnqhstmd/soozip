import Testing
import Foundation
@testable import SoozipGeometry

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

@Test func 회전이_0이면_로컬좌표는_중심기준_평행이동이다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let local = frame.toLocal(Vec2(x: 600, y: 400))
    #expect(isClose(local.x, 100))
    #expect(isClose(local.y, 0))
}

@Test func 회전된_레이어는_역회전_행렬로_로컬좌표를_구한다() {
    // 45° 회전된 레이어에서 중심의 오른쪽 100pt 지점은
    // 로컬 좌표로 (100·cos(-45°), 100·sin(-45°)) = (70.71, -70.71)
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 4)
    let local = frame.toLocal(Vec2(x: 600, y: 400))
    #expect(isClose(local.x, 70.71))
    #expect(isClose(local.y, -70.71))
}

@Test func toLocal과_toWorld는_서로_역변환이다() {
    let frame = LayerFrame(center: Vec2(x: 320, y: 780),
                           size: Size2(width: 150, height: 90),
                           rotation: 0.7)
    let original = Vec2(x: 411, y: 623)
    let roundTrip = frame.toWorld(frame.toLocal(original))
    #expect(isClose(roundTrip.x, original.x))
    #expect(isClose(roundTrip.y, original.y))
}

@Test func 회전이_0인_레이어의_네_코너() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    #expect(isClose(frame.corner(.topLeft).x, 400))
    #expect(isClose(frame.corner(.topLeft).y, 350))
    #expect(isClose(frame.corner(.bottomRight).x, 600))
    #expect(isClose(frame.corner(.bottomRight).y, 450))
}

@Test func 회전된_레이어의_코너는_중심에서_같은_거리에_있다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 6)
    let expected = (100.0 * 100.0 + 50.0 * 50.0).squareRoot()   // 대각 반지름
    for corner in Corner.allCases {
        let p = frame.corner(corner)
        let dx = p.x - 500
        let dy = p.y - 400
        #expect(isClose((dx * dx + dy * dy).squareRoot(), expected))
    }
}

@Test func 코너의_대각_반대편() {
    #expect(Corner.topLeft.opposite == .bottomRight)
    #expect(Corner.topRight.opposite == .bottomLeft)
    #expect(Corner.bottomLeft.opposite == .topRight)
    #expect(Corner.bottomRight.opposite == .topLeft)
}

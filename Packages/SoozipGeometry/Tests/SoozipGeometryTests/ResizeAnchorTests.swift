import Testing
import Foundation
@testable import SoozipGeometry

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }
private let minSide: Double = 40
private let maxSide: Double = 7680   // 캔버스 긴 변 1920 × 4

@Test func 코너드래그시_대각_반대편_코너가_고정된다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 700, y: 300),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.bottomLeft).x, anchor.x))
    #expect(isClose(resized.corner(.bottomLeft).y, anchor.y))
}

@Test func 회전된_레이어도_대각_반대편이_고정된다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 4)
    let anchor = frame.corner(.bottomLeft)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 640, y: 260),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.bottomLeft).x, anchor.x))
    #expect(isClose(resized.corner(.bottomLeft).y, anchor.y))
}

@Test func 코너드래그는_원본_비율을_유지한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let ratio = frame.size.width / frame.size.height

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 900, y: 100),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.size.width / resized.size.height, ratio))
}

@Test func 크기_하한에서_정지한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    // 대각 반대편(bottomLeft)에 거의 붙도록 끌어당긴다
    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 401, y: 449),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(resized.size.shortSide >= minSide - 0.01)
}

@Test func 크기_상한에서_정지한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 99_999, y: -99_999),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(resized.size.longSide <= maxSide + 0.01)
}

@Test func 변핸들은_한_축만_바꾼다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingEdge: .right,
                                to: Vec2(x: 700, y: 400),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.size.width, 300))
    #expect(isClose(resized.size.height, 100))   // 높이 불변
}

@Test func 변핸들도_반대쪽_변이_고정된다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let leftEdgeX = frame.corner(.topLeft).x

    let resized = frame.resized(draggingEdge: .right,
                                to: Vec2(x: 700, y: 400),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.topLeft).x, leftEdgeX))
}

@Test func 회전된_레이어의_코너드래그는_반대편_코너와_크기를_함께_고정한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 2)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 700, y: 300),
                                minShortSide: minSide, maxLongSide: maxSide)

    // bottomLeft 절은 보정 블록이 중심 계산을 통째로 소거하는 대수적 항등식이라
    // 어떤 변이도 죽이지 못한다(무작위 300회 실측 편차 1.2e-11). 값이 두 벌로
    // 갈라질 수 있는 유일한 자리는 size 계산이며, toLocal의 회전 부호 반전
    // 변이와 abs() 제거 변이는 size 절에서만 드러난다.
    #expect(isClose(resized.corner(.bottomLeft).x, 450))
    #expect(isClose(resized.corner(.bottomLeft).y, 300))
    #expect(isClose(resized.size.width, 500))
    #expect(isClose(resized.size.height, 250))
}

@Test func 대각_고정점을_지나쳐_끌어도_도형이_뒤집히지_않는다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 300, y: 500),
                                minShortSide: minSide, maxLongSide: maxSide)

    // bottomLeft 절은 위와 같은 이유로 공허한 항등식이지만 AC가 요구하므로 유지한다.
    // 실질 관측면은 size와 topRight이며, 특히 topRight (500,400) 절이
    // Corner.topRight.sign 열거형 정의 변이((1,-1) -> (1,1))를 이 파일 안에서
    // 유일하게 죽인다.
    #expect(isClose(resized.corner(.bottomLeft).x, 400))
    #expect(isClose(resized.corner(.bottomLeft).y, 450))
    #expect(isClose(resized.size.width, 100))
    #expect(isClose(resized.size.height, 50))
    #expect(isClose(resized.corner(.topRight).x, 500))
    #expect(isClose(resized.corner(.topRight).y, 400))
}

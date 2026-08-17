import Testing
import Foundation
@testable import SoozipGeometry

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }
// EDITOR-7 — 리사이즈 한계: 리사이즈 한계를 캔버스 치수로부터 유도한다.
/// 4:5 피드 캔버스. 폭 1080은 두 프리셋 공통이다.
private let post  = Size2(width: 1080, height: 1350)
/// 9:16 스토리 캔버스. 폭은 같고 높이만 다르다.
private let story = Size2(width: 1080, height: 1920)
/// **한계는 프로덕션에서만 온다.** 예전의 `private let maxSide = 7680 // 캔버스 긴 변
/// 1920 × 4`는 값이 아니라 **유도 규칙의 두 번째 기술**이었다. 프로덕션에 유도가 생긴
/// 지금 그것을 남기면 정확히 여섯 번째 "같은 규칙 두 곳"이 된다.
///
/// ⚠️ **이 교체로 축이 하나 이동한다.** `크기_하한/상한에서_정지한다`의 단언은 예전엔
/// `minSide - 0.01` / `maxSide + 0.01`로 **입력 리터럴 자체**를 기준 삼았다. 이제
/// 좌·우변이 같은 출처가 되어 "한계값이 40/7680이다"라는 축을 잃고 "클램프가 받은 값을
/// 실제로 쓴다"만 남는다. **잃은 축은 `리사이즈_한계는_캔버스_비율에_따라…`가 리터럴로
/// 받는다 — 그 테스트는 생략 불가다.**
private let 포스트한계 = LayerFrame.resizeLimits(canvas: post)
private let 스토리한계 = LayerFrame.resizeLimits(canvas: story)

@Test func 코너드래그시_대각_반대편_코너가_고정된다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 700, y: 300),
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

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
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

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
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

    #expect(isClose(resized.size.width / resized.size.height, ratio))
}

@Test func 크기_하한에서_정지한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    // 대각 반대편(bottomLeft)에 거의 붙도록 끌어당긴다
    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 401, y: 449),
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

    #expect(resized.size.shortSide >= 스토리한계.minShortSide - 0.01)
}

@Test func 크기_상한에서_정지한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 99_999, y: -99_999),
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

    #expect(resized.size.longSide <= 스토리한계.maxLongSide + 0.01)
}

@Test func 변핸들은_한_축만_바꾼다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingEdge: .right,
                                to: Vec2(x: 700, y: 400),
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

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
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

    #expect(isClose(resized.corner(.topLeft).x, leftEdgeX))
}

@Test func 회전된_레이어의_코너드래그는_반대편_코너와_크기를_함께_고정한다() {
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 2)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 700, y: 300),
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

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
                                minShortSide: 스토리한계.minShortSide, maxLongSide: 스토리한계.maxLongSide)

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

// MARK: - EDITOR-7: 리사이즈 한계 (캔버스로부터 리사이즈 한계를 유도한다)

@Test func 리사이즈_한계는_캔버스_비율에_따라_하한은_공통이고_상한은_달라진다() {
    // Given: 논리 캔버스 (1080,1350)[4:5]와 (1080,1920)[9:16] — 폭이 같고
    // 높이만 달라, longSide → shortSide로 뒤바꾸는 변이는 두 캔버스 모두
    // 1080×4 = 4320을 내어 아래 두 상한 단언을 동시에 죽인다.
    // When: 프로덕션이 그 캔버스로부터 리사이즈 한계를 유도한다.
    // Then: 하한은 두 캔버스 모두 40, 상한은 4:5에서 5400·9:16에서 7680이다.
    //
    // maxLongSide는 곱셈 결과라 상수 리터럴이 아니므로 isClose로 비교한다.
    #expect(isClose(포스트한계.minShortSide, 40))
    #expect(isClose(스토리한계.minShortSide, 40))
    #expect(isClose(포스트한계.maxLongSide, 5400))
    #expect(isClose(스토리한계.maxLongSide, 7680))
}

@Test func 캔버스로부터_유도된_상한값으로_리사이즈하면_정확한_크기에서_멈춘다() {
    // Given: LayerFrame(center: (500,400), size: (200,100), rotation: 0)와
    // 위 테스트에서 검증된 프로덕션 유도 상한값.
    // When: topRight 코너를 (99999, -99999)로 끌되, minShortSide·maxLongSide로
    // 유도값(포스트한계/스토리한계)을 그대로 전달한다 — 리터럴 5400/7680을
    // 직접 넘기면 이 테스트가 유도 함수와 무관해진다.
    // Then: 4:5 유도값(5400) 사용 시 결과 size는 (5400, 2700),
    //       9:16 유도값(7680) 사용 시 결과 size는 (7680, 3840)이다.
    //
    // 기존 `크기_상한에서_정지한다`의 부등식(`<= maxSide + 0.01`)은 과잉
    // 클램프(예: (3840,1920))도 통과시킨다. 여기서는 유도된 상한값을 그대로
    // 넘겨 정확한 결과 크기를 단언함으로써 그 결함을 잡는다.
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)

    let 포스트결과 = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 99_999, y: -99_999),
                                minShortSide: 포스트한계.minShortSide,
                                maxLongSide: 포스트한계.maxLongSide)
    #expect(isClose(포스트결과.size.width, 5400))
    #expect(isClose(포스트결과.size.height, 2700))

    let 스토리결과 = frame.resized(draggingCorner: .topRight,
                                to: Vec2(x: 99_999, y: -99_999),
                                minShortSide: 스토리한계.minShortSide,
                                maxLongSide: 스토리한계.maxLongSide)
    #expect(isClose(스토리결과.size.width, 7680))
    #expect(isClose(스토리결과.size.height, 3840))
}

// MARK: - AC-6: 하한이 상한을 이긴다

@Test func 하한이_상한을_이겨_긴_변이_상한을_넘어도_짧은_변은_하한_아래로_새지_않는다() {
    // 임계 비율은 상한/하한이며 9:16에서 192, 4:5에서 135다. 그 비율을 넘는
    // 가는 레이어(여기서는 200:1 = 8000/40)에서 현재는 짧은 변이 하한 아래로 샌다.
    //
    // Given: 비율 200:1(8000×40)의 매우 가는 레이어.
    let frame = LayerFrame(center: Vec2(x: 0, y: 0),
                           size: Size2(width: 8000, height: 40),
                           rotation: 0)

    // When: topRight 코너를 자기 자신의 현재 위치(4000,-20)로 끈다(이동량 0에
    // 가까운 드래그) — 그리고 같은 프레임을 훨씬 먼 지점으로도 끈다. 두
    // 드래그 모두 "수렴"을 관측하기 위해 필요하며, minShortSide/maxLongSide는
    // 둘 다 스토리한계(40, 7680)를 쓴다.
    let 제자리결과 = frame.resized(draggingCorner: .topRight,
                                  to: Vec2(x: 4000, y: -20),
                                  minShortSide: 스토리한계.minShortSide,
                                  maxLongSide: 스토리한계.maxLongSide)
    let 먼거리결과 = frame.resized(draggingCorner: .topRight,
                                  to: Vec2(x: 999_999_999, y: -999_999_999),
                                  minShortSide: 스토리한계.minShortSide,
                                  maxLongSide: 스토리한계.maxLongSide)

    // Then: 두 결과 모두 size가 (8000, 40)이다 — 짧은 변 40이 유지되고,
    // 긴 변 8000이 상한 7680을 초과한 채로 확정된다(하한이 상한을 이긴다).
    //
    // 현재 동작은 (7680, 38.4)다 — 짧은 변이 하한 40 아래로 1.6px 샌다.
    // isClose 필수: 제자리 드래그의 실측값은 8000.000000000001,
    // 먼 드래그의 실측값은 7999.999999999999라 ==으로는 통과가 불가능하다.
    #expect(isClose(제자리결과.size.width, 8000))
    #expect(isClose(제자리결과.size.height, 40))
    #expect(isClose(먼거리결과.size.width, 8000))
    #expect(isClose(먼거리결과.size.height, 40))
}

// MARK: - 변 드래그 특성화 (AC 없음 — 하한 우선 순서 교체가 변 경로에도 미치는 영향)

@Test func 하한_우선_순서교체는_변드래그_결과와_불변축까지_함께_바꾼다() {
    // 목적: 하한 우선(블록 순서 교체)은 코너 경로만이 아니라 변 드래그 경로의
    // 결과도 바꾼다. 현재는 (7.68, 7680)이고 교체 후 (40, 40000)이다. 이
    // 테스트가 없으면 clamped를 쪼개 변 경로만 옛 순서로 되돌리는 변이를
    // 아무도 못 잡는다.
    //
    // 동시에 이 값은 공유 클램프가 변 드래그의 불변 축까지 바꾼다는 결함(F-4)의
    // 유일한 증인이기도 하다 — 불변이어야 할 높이가 100000 -> 40000으로
    // 바뀐다. EDITOR-7은 그 결함을 고치지 않았고(고치려면 "변 드래그에서
    // 하한·상한이 무엇을 뜻하는가"라는 새 정책이 필요하다), 발동 집합도
    // 넓히지 않았다(무작위 20,000회 대조로 확인 — 순서와 무관하게 발동 조건이
    // 같다). 바뀌는 것은 발동 시 이탈량뿐이며 방향은 케이스마다 갈린다.
    let frame = LayerFrame(center: Vec2(x: 0, y: 0),
                           size: Size2(width: 30, height: 100_000),
                           rotation: 0)

    let resized = frame.resized(draggingEdge: .right,
                                to: Vec2(x: 85, y: 0),
                                minShortSide: 스토리한계.minShortSide,
                                maxLongSide: 스토리한계.maxLongSide)

    #expect(isClose(resized.size.width, 40))
    #expect(isClose(resized.size.height, 40_000))
}

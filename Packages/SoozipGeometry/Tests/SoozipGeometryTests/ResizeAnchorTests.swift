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
    // 가는 레이어(여기서는 200:1 = 8000/40)에서 `EDITOR-7` 이전에는 짧은 변이
    // 하한 아래로 샜다(현재는 새지 않는다 — 아래 단언이 그것을 확인한다).
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
    // `EDITOR-7` 이전 동작은 (7680, 38.4)였다 — 짧은 변이 하한 40 아래로
    // 1.6px 샜다. 현재는 (8000, 40)이다(아래 단언).
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
    // 결과도 바꾼다. `EDITOR-7` 이전에는 (7.68, 7680)이었고, 교체 후(현재)는
    // (40, 40000)이다. 이 테스트가 없으면 clamped를 쪼개 변 경로만 옛 순서로
    // 되돌리는 변이를 아무도 못 잡는다.
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

// MARK: - AC-4: (0,0) 붕괴에서 하한 복원

@Test func 대각_고정점과_정확히_일치하도록_끌어도_하한에서_복원된다() {
    // Given: LayerFrame(center: (500,400), size: (200,100), rotation: 0).
    //
    // ⚠️ rotation은 반드시 0이어야 한다 — 회전이 붙으면 좌표 변환(회전 행렬
    // 곱)이 부동소수점 잔차 ~1e-14를 남겨 "폭·높이가 정확히 0"에 도달하지
    // 못하고, 곱셈 경로가 우연히 같은 값을 내 이 결함을 관측하지 못한다.
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)  // (400, 450)

    // When: topRight 코너를 대각 고정점(bottomLeft)의 정확한 좌표로 끈다.
    // 드래그 지점이 고정점과 정확히 일치하면 폭·높이가 둘 다 0이 되는데,
    // 클램프의 하한 조건이 "shortSide > 0"이면 통째로 스킵되어 레이어가
    // 점이 되어 다시 잡을 수 없다. `EDITOR-7` 이전에는 결과가 (0, 0)이었다
    // (현재는 아래 단언대로 (80, 40)으로 하한 복원된다).
    let resized = frame.resized(draggingCorner: .topRight,
                                to: anchor,
                                minShortSide: 스토리한계.minShortSide,
                                maxLongSide: 스토리한계.maxLongSide)

    // Then: 원본 비율 2:1을 유지한 채 하한(40)에서 복원되어 크기가
    // (80, 40)이 되고, bottomLeft 고정점은 그대로 유지된다.
    //
    // ⚠️ size.shortSide == 40 / size.longSide == 80 형태로 단언하면 축
    // 정보가 사라져 폭·높이가 뒤바뀐 구현((40, 80))도 그대로 통과한다.
    // 반드시 size.width·size.height를 직접 단언해야 그 변이가 죽는다.
    #expect(isClose(resized.size.width, 80))
    #expect(isClose(resized.size.height, 40))

    // bottomLeft 절은 이 테스트에서도 항등이라 변이를 죽이지 못한다 — 후퇴
    // 경로에서도 자동으로 참이다(후퇴하면 반환값이 원본 self이므로
    // corner(.bottomLeft) == anchor가 그대로 성립한다). 결과가 비유한이 아닌
    // 한 실패가 불가능하므로 실질 관측면은 위 size.width·size.height다.
    #expect(isClose(resized.corner(.bottomLeft).x, anchor.x))
    #expect(isClose(resized.corner(.bottomLeft).y, anchor.y))
}

// MARK: - 극단 비율 붕괴 특성화 (AC 없음 — AC-4 수정의 회귀 방지 증인)

@Test func 극단_비율의_레이어가_붕괴해도_결과는_유한하다() {
    // 목적: 위 테스트(AC-4)를 고치는 방식(하한 복원)이 이 입력에서는 회귀를
    // 만들 수 있다는 것을 특성화한다. 비율이 극단이면 복원된 값이 상한·
    // 하한 클램프를 거치며 Infinity로 넘치고, 좌표 계산이 inf - inf를 만나
    // NaN이 된다.
    //
    // Given: 비율 1e307(=1e307:1)의 극단적으로 가는 레이어. 임계는 비율
    // > 4.494e306 또는 그 미만 쪽 임계다 — 정확한 값과 유도는
    // `LayerFrame.clamped` doc 참조.
    let frame = LayerFrame(center: Vec2(x: 0, y: 0),
                           size: Size2(width: 1e307, height: 1),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)  // (-5e306, 0.5)

    // When: topRight 코너를 고정점의 정확한 좌표로 끌어 붕괴시킨다.
    let resized = frame.resized(draggingCorner: .topRight,
                                to: anchor,
                                minShortSide: 스토리한계.minShortSide,
                                maxLongSide: 스토리한계.maxLongSide)

    // Then: center.x·center.y·size.width·size.height가 전부 유한하다.
    //
    // (0,0)의 올바른 답인 40 × 1e307은 Double로 표현할 수 없으므로 어떤
    // 구현도 낼 수 없다. 정직한 선택지는 원본 프레임으로 후퇴뿐이고, 후퇴
    // 하려면 붕괴 검출이 필요하다. 이 테스트는 그 결과 유한성 검사의 유일한
    // 증인이다 — 이 검사를 지우는 변이를 다른 어떤 테스트도 죽이지 못한다.
    //
    // `EDITOR-7` 이전(붕괴 복원이 없던 시절)에는 이 지점에서 곧장 통과했다 —
    // 그때 결과는 크기 (0,0)·중심 유한이라 이미 유한했다. 붕괴 복원만 넣으면
    // 이 테스트는 빨강이 됐고(위 오버플로우), 결과 유한성 검사(붕괴 시 원본
    // 프레임으로 후퇴)까지 넣어 다시 초록이 됐다.
    //
    // **오늘은 원본 후퇴가 일어나서 유한한 것이다** — size는 (0,0)이 아니라
    // 원본 (1e307, 1)로 돌아간다. 이 테스트가 초록인 이유가 "애초에 위험이
    // 없어서"가 아니라 "가드가 실제로 원본으로 후퇴시켜서"라는 점이 중요하다 —
    // 만약 지금도 여전히 (0,0)이 났다면 그건 이 테스트가 아무것도 막지 못한다는
    // 뜻이었을 것이다.
    //
    // resized == frame 같은 등가 단언은 쓰지 않는다 — 원본으로의 후퇴는
    // 허용이지 요구가 아니다.
    #expect(resized.center.x.isFinite)
    #expect(resized.center.y.isFinite)
    #expect(resized.size.width.isFinite)
    #expect(resized.size.height.isFinite)
}

// MARK: - 유한성 가드: 드래그 좌표·리사이즈 한계값 오염 방어 (AC 없음 — 방어 요구사항)

@Test func 드래그_좌표나_리사이즈_한계값이_비유한이면_결과가_유한하다() {
    // worldPoint.x · worldPoint.y · minShortSide · maxLongSide 중 **하나라도**
    // 비유한(NaN 또는 Infinity)이면 결과 center.x · center.y · size.width ·
    // size.height가 전부 유한해야 한다(FR-5 전반부). 방어 대상 조건이 4개인데
    // 한 변형만 재면 나머지 3개를 통째로 지워도 이 테스트가 통과하므로, 각
    // 조건을 NaN·Infinity로 각각 오염시킨 여덟 변형을 배열로 순회한다
    // (`HandlePlacementTests.swift`의 `프레임_필드가_비유한이면_box가_nil이다`
    // 형식을 따른다).
    //
    // worldPoint 쪽(변형 1~4): 한 성분의 NaN이 좌표 변환을 거치며 두 성분으로
    // 번진다 — 회전 0에서 sin(-0) = -0.0이라 NaN × -0.0 = NaN이 되기 때문이다.
    // 그 뒤로는 모든 비교가 거짓이 되어 클램프가 통째로 스킵되고(Swift의
    // max(x, y)는 y >= x ? y : x로 정의돼 비교가 거짓이면 y를 그대로 반환한다),
    // 결과 네 필드가 전부 NaN으로 확정된다. **이 네 변형에는 등가 단언을
    // 넣지 않는다** — 결과 유한성 후퇴(비유한 결과를 원본 프레임으로 되돌리는
    // 처리)가 이미 원본 프레임을 복원해 주므로, 여기서 다시 등가를 못 박으면
    // 나중에 "유한값으로 클램프"(원본이 아닌 다른 유한 프레임으로 복구)하는
    // 구현으로 바뀔 때 요구사항 밖 테스트가 깨진다.
    //
    // 한계값 쪽(변형 5~8): 좌표 오염과 달리 결과를 NaN으로 오염시키지 **않고**
    // "한계를 조용히 무력화"한다 — 비유한 한계값은 클램프의 비교를
    // 전부 거짓으로 만들어 클램프 자체를 스킵시키고, 결과는 유한하지만 한계가
    // 적용되지 않은 값이 된다. 실측(오케스트레이터 재현):
    //   · 정상 하한 40, 대각 고정점 근접 드래그(401,449) → (80,40) — 하한이 지켜짐
    //   · 하한 .nan,  같은 드래그                          → (2,1)   — 하한이 조용히 사라짐
    //   · 정상 상한 7680, 거대 드래그(99999,-99999)        → (7680,3840) — 상한이 지켜짐
    //   · 상한 .nan,  같은 드래그                          → (200898,100449) — 상한이 조용히 사라짐
    // `(2,1)`도 `(200898,100449)`도 완벽하게 유한하므로 isFinite만으로는 이
    // 사고를 영영 관측할 수 없다 — 결과가 "원본 프레임을 벗어나지 않는다"는
    // FR-5 후반부를 직접 재는 등가 단언이 이 네 변형에서만 필요하다. 그래서
    // worldPoint도 변형 1~4의 (700,300)이 아니라, 실제로 각 한계가 발동하는
    // 지점(하한: 대각 고정점 근접, 상한: 초원거리)으로 바꿨다 — (700,300)은
    // 정상 한계에서도 클램프가 발동하지 않는 드래그라 한계 무력화를
    // 관측하지 못한다.
    //
    // ⚠️ **`.nan`과 `.infinity` 하한은 서로 반대 메커니즘으로 같은 결론(유한하고
    // 원본과 같음)에 도달한다 — 위 "비교를 전부 거짓으로 만들어 스킵시킨다"는
    // 설명은 `.nan`과 상한 쪽(`.nan`·`.infinity` 둘 다)에만 맞는다.** `.infinity`
    // **하한**은 `shortSide < .infinity`가 **참**이 되어 클램프를 스킵이 아니라
    // 오히려 **강제 발동**시킨다 — `k = ∞/shortSide = ∞`가 되어 `size (∞,∞)`를
    // 만들고, 뒤이은 코너 보정의 `∞ − ∞ = NaN`이 center를 오염시킨 뒤 **결과
    // 유한성 가드가 원본으로 후퇴시켜** 등가 단언을 통과시킨다(실측: 원본
    // (200,100) 그대로 — 무증인 통과, 즉 이 변형은 진입 가드가 아니라 결과
    // 가드가 살려낸다). 상한 `.nan`/`.infinity`는 대칭이 아니다 — 둘 다
    // `longSide > .nan`/`longSide > .infinity` 비교가 거짓이 되어 그대로
    // 스킵된다.
    //
    // (참고: 변 드래그 8변형(`변_드래그도_...`, 아래)에서는 이 함수에 결과
    // 유한성 가드가 추가되기 전 하한 `.infinity`가 실제로 실패했었다
    // (`size (∞,∞)`) — 그 경로엔 결과 가드가 없었기 때문이다. 지금은 코너·
    // 변 드래그 둘 다 결과 가드가 있어 둘 다 통과한다.)
    let frame = LayerFrame(center: Vec2(x: 500, y: 400),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)

    let 변형들: [(worldPoint: Vec2, minShortSide: Double, maxLongSide: Double, 한계값오염: Bool)] = [
        // 좌표 축 오염 — 결과 유한성 후퇴가 원본으로 되돌린다. isFinite만 잰다.
        (Vec2(x: .nan, y: 300), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        (Vec2(x: .infinity, y: 300), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        (Vec2(x: 700, y: .nan), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        (Vec2(x: 700, y: .infinity), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        // 하한 축 오염 — 대각 고정점(400,450) 근접 드래그라 정상 한계에서는
        // 하한 클램프가 실제로 발동한다(`크기_하한에서_정지한다`와 같은 지점).
        (Vec2(x: 401, y: 449), .nan, 스토리한계.maxLongSide, true),
        // 이 변형은 결과 가드의 증인이지 진입 가드의 증인이 아니다 — 위 설명 참조.
        (Vec2(x: 401, y: 449), .infinity, 스토리한계.maxLongSide, true),
        // 상한 축 오염 — 초원거리 드래그라 정상 한계에서는 상한 클램프가 실제로
        // 발동한다(`크기_상한에서_정지한다`와 같은 지점).
        (Vec2(x: 99_999, y: -99_999), 스토리한계.minShortSide, .nan, true),
        (Vec2(x: 99_999, y: -99_999), 스토리한계.minShortSide, .infinity, true),
    ]

    for 변형 in 변형들 {
        let resized = frame.resized(draggingCorner: .topRight,
                                    to: 변형.worldPoint,
                                    minShortSide: 변형.minShortSide,
                                    maxLongSide: 변형.maxLongSide)

        #expect(resized.center.x.isFinite)
        #expect(resized.center.y.isFinite)
        #expect(resized.size.width.isFinite)
        #expect(resized.size.height.isFinite)

        if 변형.한계값오염 {
            // FR-5 후반부: 한계가 무력화됐어도 결과가 원본 프레임을 벗어나지
            // 않아야 한다 — "레이어가 화면 밖 비유한 좌표로 튀지 않는다"는
            // 문면을, 유한하되 원본과 다른 값(2,1)이나 (200898,100449)까지
            // 잡도록 등가로 강화한 것이다.
            #expect(isClose(resized.center.x, 500))
            #expect(isClose(resized.center.y, 400))
            #expect(isClose(resized.size.width, 200))
            #expect(isClose(resized.size.height, 100))
        }
    }
}

// MARK: - 유한성 가드: 변 드래그 방어 (AC 없음 — FR-5는 코너로 한정하지 않는다)

@Test func 변_드래그도_좌표나_리사이즈_한계값이_비유한이면_결과가_유한하다() {
    // `드래그_좌표나_리사이즈_한계값이_비유한이면_결과가_유한하다`(위, coner 경로)와
    // 대칭이다. FR-5 원문("드래그 좌표·하한·상한 중 하나라도 비유한이면 리사이즈
    // 결과가 원본 프레임을 벗어나지 않는다")은 코너로 한정하지 않는데, 같은
    // 인자 목록을 받는 `resized(draggingEdge:)`에는 진입 가드도 결과 유한성
    // 후퇴도 없다. 그 결함을 여덟 변형으로 재현한다.
    //
    // 기본 프레임: LayerFrame(center: (500,400), size: (200,100), rotation: 0), .right 변.
    let 기본프레임 = LayerFrame(center: Vec2(x: 500, y: 400),
                            size: Size2(width: 200, height: 100),
                            rotation: 0)
    // 하한 클램프 전용 프레임: 기본 프레임(반폭 100)으로는 (500,400) 드래그가
    // newW = 100을 내어 하한 40에 걸리지 않는다. 반폭 25(폭 50)이면 같은 드래그
    // 지점(로컬 x = 0)이 newW = 25를 내어 하한이 실제로 발동한다.
    let 하한프레임 = LayerFrame(center: Vec2(x: 500, y: 400),
                            size: Size2(width: 50, height: 100),
                            rotation: 0)

    let 변형들: [(label: String, frame: LayerFrame, worldPoint: Vec2, minShortSide: Double, maxLongSide: Double, 한계값오염: Bool)] = [
        // 좌표 축 오염 — 기준 드래그 지점 (700,400)에서 한 성분만 오염시킨다.
        ("좌표.x = nan", 기본프레임, Vec2(x: .nan, y: 400), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        ("좌표.x = inf", 기본프레임, Vec2(x: .infinity, y: 400), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        ("좌표.y = nan", 기본프레임, Vec2(x: 700, y: .nan), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        ("좌표.y = inf", 기본프레임, Vec2(x: 700, y: .infinity), 스토리한계.minShortSide, 스토리한계.maxLongSide, false),
        // 하한 축 오염 — 하한프레임을 (500,400)(로컬 x = 0)으로 끌어 하한 클램프가
        // 실제로 발동하는 지점에서 오염시킨다.
        ("하한 = nan", 하한프레임, Vec2(x: 500, y: 400), .nan, 스토리한계.maxLongSide, true),
        ("하한 = inf", 하한프레임, Vec2(x: 500, y: 400), .infinity, 스토리한계.maxLongSide, true),
        // 상한 축 오염 — 초원거리 드래그라 정상 한계에서는 상한 클램프가 실제로
        // 발동한다.
        ("상한 = nan", 기본프레임, Vec2(x: 99_999, y: 400), 스토리한계.minShortSide, .nan, true),
        ("상한 = inf", 기본프레임, Vec2(x: 99_999, y: 400), 스토리한계.minShortSide, .infinity, true),
    ]

    for 변형 in 변형들 {
        let resized = 변형.frame.resized(draggingEdge: .right,
                                        to: 변형.worldPoint,
                                        minShortSide: 변형.minShortSide,
                                        maxLongSide: 변형.maxLongSide)

        #expect(resized.center.x.isFinite, "\(변형.label)")
        #expect(resized.center.y.isFinite, "\(변형.label)")
        #expect(resized.size.width.isFinite, "\(변형.label)")
        #expect(resized.size.height.isFinite, "\(변형.label)")

        if 변형.한계값오염 {
            // FR-5 후반부: 한계가 무력화됐어도 결과가 그 변형이 쓴 원본
            // 프레임을 벗어나지 않아야 한다.
            #expect(isClose(resized.center.x, 변형.frame.center.x), "\(변형.label)")
            #expect(isClose(resized.center.y, 변형.frame.center.y), "\(변형.label)")
            #expect(isClose(resized.size.width, 변형.frame.size.width), "\(변형.label)")
            #expect(isClose(resized.size.height, 변형.frame.size.height), "\(변형.label)")
        }
    }
}

// MARK: - 극단 비율 붕괴 특성화 (AC 없음 — 반대 방향 임계의 회귀 방지 증인)

@Test func 반대_비율로_붕괴해도_결과는_유한하다() {
    // `극단_비율의_레이어가_붕괴해도_결과는_유한하다`(비율 1e307)의 반대 방향
    // (비율 1e-307)을 고정한다.
    //
    // 붕괴 복원 경로에서 shortSide가 지나치게 작으면 하한 클램프의 배율
    // k = minShortSide / shortSide가 Double 표현 범위를 넘어 Infinity로
    // 오버플로우한다. 임계는 shortSide < minShortSide / Double.greatestFiniteMagnitude
    // 이고 실측 2.2250738585072018e-307이다(EDITOR-7 코드 리뷰 전에는 이 값이
    // 2.2249e-307로 적혀 있었다 — 오기였다). 반대 방향(비율이 큰 쪽) 임계는
    // Double.greatestFiniteMagnitude / minShortSide = 4.4942328371557894e306이다.
    // 이 테스트는 그 임계 근방의 거동을 고정하는 유일한 증인이며, 숫자 자체가
    // 아니라 "그 구간에서 결과 유한성 후퇴가 동작한다"를 잰다.
    //
    // Given: 비율 1e-307(=1:1e307)의 극단적으로 가는 레이어.
    let frame = LayerFrame(center: Vec2(x: 0, y: 0),
                           size: Size2(width: 1, height: 1e307),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)

    // When: topRight 코너를 고정점의 정확한 좌표로 끌어 붕괴시킨다.
    let resized = frame.resized(draggingCorner: .topRight,
                                to: anchor,
                                minShortSide: 스토리한계.minShortSide,
                                maxLongSide: 스토리한계.maxLongSide)

    // Then: center.x·center.y·size.width·size.height가 전부 유한하다.
    #expect(resized.center.x.isFinite)
    #expect(resized.center.y.isFinite)
    #expect(resized.size.width.isFinite)
    #expect(resized.size.height.isFinite)
}

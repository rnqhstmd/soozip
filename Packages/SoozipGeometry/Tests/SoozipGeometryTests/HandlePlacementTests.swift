import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-4 — 핸들 배치. 코너·변·회전·삭제 핸들의 화면 좌표를 계산한다.
//
// 계산 규약: 결과는 전부 화면 좌표(surface.toScreen 경유)다. 뒤집기 판정 기준선은
// **뷰포트 상단(화면 y = 0)** 이다 — 캔버스 상단이 아니다.

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

// MARK: - 뒤집기 판정 전용 표면
//
// fitScale = min(540/1080, 700/1350) = 0.5 정확. 기본 center = (540, 675).
// 판정식 = (topY − center.y) · scale + 350 (viewport.height/2 = 350)

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: Size2(width: 1080, height: 1350),
                  viewport: Size2(width: 540, height: 700))
}

/// 뒤집기 표면 전용 프레임(회전 0). 논리 topY로부터 center.y를 역산한다
/// (edgeMidpoint(.top).y == center.y − height/2, 회전 0에서).
private func 뒤집기프레임(topY: Double) -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: topY + 50),
               size: Size2(width: 200, height: 100),
               rotation: 0)
}

// MARK: - AC-9·10 전용 표면 (축 퇴화 회피)
//
// 기본 표면을 쓰면 center.x · fitScale = 540 × 390/1080 = 195 = viewport.width/2라
// x축 오프셋이 소거되어 퇴화한다. 그래서 별도 표면 + 팬을 쓴다.

private func π조사표면() -> CanvasSurface {
    CanvasSurface(canvas: Size2(width: 1080, height: 1350),
                  viewport: Size2(width: 390, height: 844))
        .zoomed(to: 2)
        .centered(on: Vec2(x: 700, y: 300))
}

private func π조사프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 500, y: 500),
               size: Size2(width: 200, height: 100),
               rotation: .pi / 2)
}

// MARK: - EDITOR-6 사전 이전 픽스처 (사이클 0, 프로덕션 0줄 — 정책 도입 전 준비)

/// 판정값 정확히 88 = 176 × 0.5 — `EDITOR-6`의 변 숨김 임계값 **경계**다.
/// 경계는 이전 상태이므로(v4 §5.7이 `< 88pt`) 변 핸들이 **있는** 쪽이다.
///
/// 변 핸들을 재는 테스트를 여기 두는 이유: 기본 `뒤집기프레임`(200×100)은
/// 판정값 50이라 `EDITOR-6` 이후 변이 사라져 단언이 통째로 무의미해진다.
private func 정책밖프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 176, height: 300), rotation: 0)
}

/// `π조사표면()`(fitScale 0.361111 × zoom 2 = 0.722222)에서 판정값 ≥ 88을 만든다.
/// 200 × 0.722222 = **144.44**.
///
/// **높이만 100 → 250으로 키운다.** left 변 중점은 `toWorld(-w/2, 0)`이라 높이에
/// 의존하지 않아 기대 좌표 (500,400)이 **글자 그대로 유지**된다. 폭을 건드리면
/// 그 값이 움직여 "변끼리 뒤바뀜" 변이를 죽이던 단언을 다시 써야 한다.
private func π조사프레임_변포함() -> LayerFrame {
    LayerFrame(center: Vec2(x: 500, y: 500),
               size: Size2(width: 200, height: 250), rotation: .pi / 2)
}

// MARK: - AC-9: π/2에서 네 코너 전부, 양 성분

@Test func π_2_회전에서_네_코너가_전부_정확한_화면_좌표에_온다() throws {
    // TL·TR이 x를 공유하고 TL·BL이 y를 공유한다 — 한 성분만 재면 코너가
    // 뒤바뀌는(예: bottomRight에 topRight 값을 넣는) 변이가 산다.
    // 네 코너, 양 성분을 전부 잰다.
    let surface = π조사표면()
    let frame = π조사프레임()
    let placement = HandlePlacement(frame: frame, edges: [], on: surface)
    let box = try #require(placement.box)

    let 기대 = [
        (box.topLeft, Vec2(x: 550, y: 400)),
        (box.topRight, Vec2(x: 550, y: 600)),
        (box.bottomRight, Vec2(x: 450, y: 600)),
        (box.bottomLeft, Vec2(x: 450, y: 400)),
    ]
    for (실제, 논리) in 기대 {
        let 기대화면 = surface.toScreen(논리)
        #expect(isClose(실제.x, 기대화면.x))
        #expect(isClose(실제.y, 기대화면.y))
    }
}

// MARK: - AC-10: left 변 핸들 위치

@Test func π_2_회전에서_left_변_핸들이_변_중점의_화면_좌표에_온다() throws {
    // shape처럼 4변을 전부 허용한 경우. left는 다른 세 변과 좌표가 다 달라서
    // 변끼리 뒤바뀌는(예: right 값을 left에 넣는) 변이를 잡는다.
    //
    // `π조사프레임_변포함()`을 쓴다 — 기본 `π조사프레임()`은 shortSide 100
    // (짧은 변은 height)이라 판정값 72.22로 `EDITOR-6` 이후 변이 사라져 이
    // 테스트가 통째로 무의미해진다. 높이만 250으로 키운 별도 픽스처로
    // 옮겨 판정값을 144.44로 올린다(설계서 「기존 테스트 영향 처리」 참조).
    // 기대 좌표 (500,400)은 높이 변경과 무관해 그대로 유지된다.
    let surface = π조사표면()
    let frame = π조사프레임_변포함()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    let left = try #require(box.edgeHandles.first { $0.edge == .left })
    let 기대화면 = surface.toScreen(Vec2(x: 500, y: 400))
    #expect(isClose(left.position.x, 기대화면.x))
    #expect(isClose(left.position.y, 기대화면.y))
}

// MARK: - Box.corner(_:) 매핑

@Test func Box_corner_메서드는_저장된_코너와_정확히_대응한다() throws {
    // corner(_:)는 저장 프로퍼티 4개와 별개인 매핑 함수다 — switch 케이스가
    // 뒤바뀌면(예: .topRight에 bottomLeft를 반환) 이 테스트만 잡는다.
    let placement = HandlePlacement(frame: π조사프레임(), edges: [], on: π조사표면())
    let box = try #require(placement.box)

    #expect(isClose(box.corner(.topLeft).x, box.topLeft.x))
    #expect(isClose(box.corner(.topLeft).y, box.topLeft.y))
    #expect(isClose(box.corner(.topRight).x, box.topRight.x))
    #expect(isClose(box.corner(.topRight).y, box.topRight.y))
    #expect(isClose(box.corner(.bottomRight).x, box.bottomRight.x))
    #expect(isClose(box.corner(.bottomRight).y, box.bottomRight.y))
    #expect(isClose(box.corner(.bottomLeft).x, box.bottomLeft.x))
    #expect(isClose(box.corner(.bottomLeft).y, box.bottomLeft.y))
}

// MARK: - AC-11·12: 회전 핸들 간격(리터럴 28)과 뒤집기

@Test func 뒤집히지_않은_상태에서_회전_핸들은_상단_중점보다_28pt_위에_있다() throws {
    // 리터럴 28로 고정한다 — HandlePlacement.rotateGap 상수를 그대로 쓰면
    // 상수를 3으로 바꿔도 항상 초록인 항등식이 된다.
    let surface = 표면()
    let frame = 뒤집기프레임(topY: 175)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)

    let topScreen = surface.toScreen(frame.edgeMidpoint(.top))
    #expect(box.rotateFlipped == false)
    #expect(isClose(box.rotate.y, topScreen.y - 28))
}

@Test func 뒤집힌_상태에서_회전_핸들은_하단_중점보다_28pt_아래에_있다() throws {
    let surface = 표면()
    let frame = 뒤집기프레임(topY: 15)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)

    let bottomScreen = surface.toScreen(frame.edgeMidpoint(.bottom))
    #expect(box.rotateFlipped == true)
    #expect(isClose(box.rotate.y, bottomScreen.y + 28))
}

// MARK: - 뒤집기 경계값(<=40 vs >40)

@Test func 뒤집힘_경계는_화면_y_40pt를_포함한다() throws {
    // 40.0pt는 뒤집힘(<=), 40.5pt는 안 뒤집힘 — 부등호 방향(<= vs <)을 고정한다.
    let surface = 표면()
    let 포함box = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 55), edges: [], on: surface).box)
    let 초과box = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 56), edges: [], on: surface).box)

    #expect(포함box.rotateFlipped == true)
    #expect(초과box.rotateFlipped == false)
}

@Test func 화면_밖_음수_거리에서도_뒤집힘_판정이_성립한다() throws {
    // abs()로 감싼 변이라면 -50과 50이 똑같이 처리돼 이 케이스를 놓친다.
    let surface = 표면()
    let box = try #require(HandlePlacement(frame: 뒤집기프레임(topY: -125), edges: [], on: surface).box)
    #expect(box.rotateFlipped == true)
}

// MARK: - AC-13: 줌·팬에 따른 뒤집기 판정

@Test func 줌을_올려도_같은_화면_위치면_뒤집힘_판정이_같다() throws {
    // 줌 축 방어 — scale이 판정식에 실제로 곱해지는지 확인한다.
    let 기본 = 표면()
    let 확대 = 표면().zoomed(to: 4)

    let box기본 = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 35), edges: [], on: 기본).box)
    let box확대 = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 515), edges: [], on: 확대).box)

    #expect(box기본.rotateFlipped == true)
    #expect(box확대.rotateFlipped == true)
}

@Test func 팬으로_캔버스가_이동해도_뷰포트_상단_기준으로_판정한다_결정4_회귀_방어() throws {
    // 결정 4 회귀 방어: 뒤집기 기준선이 캔버스 상단이 아니라 **뷰포트 상단
    // (화면 y = 0)** 임을 고정하는 유일한 테스트다. 캔버스 상단 기준으로
    // 되돌리는 변이를 여기서만 잡는다.
    let surface = 표면().zoomed(to: 4).centered(on: Vec2(x: 540, y: 1200))
    let box = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 1040), edges: [], on: surface).box)
    #expect(box.rotateFlipped == true)
}

@Test func 화면_50pt_지점은_두_배율_모두에서_뒤집히지_않는다() throws {
    let 기본 = 표면()
    let 확대 = 표면().zoomed(to: 4)

    let box기본 = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 75), edges: [], on: 기본).box)
    let box확대 = try #require(HandlePlacement(frame: 뒤집기프레임(topY: 525), edges: [], on: 확대).box)

    #expect(box기본.rotateFlipped == false)
    #expect(box확대.rotateFlipped == false)
}

// MARK: - 회전된 레이어의 뒤집기·up 방향

@Test func 회전된_레이어의_뒤집힘_판정은_회전된_변_중점을_쓴다() throws {
    // center.y − h/2로 재는 변이는 회전을 무시해 25pt(<=40, 뒤집힘)를 내지만
    // 실제 edgeMidpoint(.top)은 π/2 회전 때문에 75pt(>40, 안 뒤집힘)다.
    let surface = 표면()
    let frame = LayerFrame(center: Vec2(x: 540, y: 75),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 2)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)
    #expect(box.rotateFlipped == false)
}

@Test func 회전_pi_2에서_회전_핸들은_상단_중점_오른쪽_28pt에_있다() throws {
    // r=0에서는 (sin r, −cos r)·(−sin r, −cos r)·(sin(−r), −cos(−r))가 전부
    // (0,−1)로 같아 구별이 안 된다. π/2에서만 up의 수평 성분이 드러난다.
    let surface = 표면()
    let frame = LayerFrame(center: Vec2(x: 540, y: 75),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 2)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)

    let topScreen = surface.toScreen(frame.edgeMidpoint(.top))
    #expect(isClose(box.rotate.x, topScreen.x + 28))
    #expect(isClose(box.rotate.y, topScreen.y))
}

@Test func 회전_pi_2에서_뒤집기_게이트를_통과하고_회전_핸들이_bottom_기준에_온다() throws {
    // 실측 주의: r = π/2에서 수학적으로는 up.y = −cos(π/2) = 0이지만, Swift의
    // cos(Double.pi / 2)는 부동소수점 반올림으로 정확히 0이 아니라
    // 6.123233995736766e-17(아주 작은 양수)을 반환한다 — 즉 실제 up.y는
    // −6.12e-17로 이미 음수다. 그래서 이 픽스처는 <= 0과 < 0 게이트를
    // 구별하지 못한다(둘 다 true). frame.rotation: Double을 통해 up.y를
    // 정확히 0으로 만드는 입력은 삼각함수의 반올림 특성상 존재하지 않는 것으로
    // 보인다(실측: π/2 주변 400만 ULP 탐색에서 cos(x) == 0.0인 x를 찾지 못함).
    // 그래도 이 테스트는 r = π/2·화면 y가 정확히 flipThreshold(40)인 조합에서
    // flipped == true·rotate == (217, 40)임을 회귀 방어로 고정해 둔다.
    let surface = 표면()
    let frame = LayerFrame(center: Vec2(x: 540, y: 55),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi / 2)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)

    #expect(box.rotateFlipped == true)
    #expect(isClose(box.rotate.x, 217))
}

// MARK: - orderedHandles 전체 시퀀스

@Test func orderedHandles는_삭제_코너_회전_변_순서다_변_4개() {
    // `정책밖프레임()`(176×300, 판정값 88)을 쓴다 — 기본 `뒤집기프레임`
    // (200×100)은 판정값 50이라 `EDITOR-6` 이후 변이 사라져 이 단언이
    // 통째로 무의미해진다. 이 테스트는 배열 조립 순서만 재므로 어느
    // 정책 밖 프레임을 쓰든 결과는 같다.
    let surface = 표면()
    let frame = 정책밖프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)

    let 순서 = placement.orderedHandles.map { $0.handle }
    #expect(순서 == [
        .delete,
        .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
        .rotate,
        .edge(.top), .edge(.right), .edge(.bottom), .edge(.left),
    ])
}

@Test func orderedHandles는_변이_하나도_없으면_여섯_개다() {
    let surface = 표면()
    let frame = 뒤집기프레임(topY: 175)
    let placement = HandlePlacement(frame: frame, edges: [], on: surface)

    let 순서 = placement.orderedHandles.map { $0.handle }
    #expect(순서 == [
        .delete,
        .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
        .rotate,
    ])
}

@Test func orderedHandles의_삭제_핸들_위치는_topLeft와_같다() throws {
    // Box.delete는 { topLeft } 계산 프로퍼티라 그 자체를 재면 항상 초록인
    // 항등식이다. orderedHandles가 만드는 .delete 항목이 실제로 topLeft를
    // 쓰는지는(값이 두 벌로 갈라질 수 있는 유일한 자리) 여기서만 드러난다.
    let surface = 표면()
    let frame = 뒤집기프레임(topY: 175)
    let placement = HandlePlacement(frame: frame, edges: [], on: surface)
    let box = try #require(placement.box)

    let delete = try #require(placement.orderedHandles.first { $0.handle == .delete })
    #expect(isClose(delete.position.x, box.topLeft.x))
    #expect(isClose(delete.position.y, box.topLeft.y))
}

// MARK: - edgeOrder

@Test func edgeOrder는_시계방향_top_right_bottom_left_리터럴이다() {
    #expect(HandlePlacement.edgeOrder == [.top, .right, .bottom, .left])
}

@Test func edgeOrder는_모든_변을_빠짐없이_포함한다() {
    #expect(Set(HandlePlacement.edgeOrder) == Set(Edge.allCases))
}

// MARK: - 유한성 가드

@Test func 프레임_필드가_비유한이면_box가_nil이다() {
    // center.x/y · size.width/height · rotation 중 하나라도 비유한이면
    // box가 nil이어야 한다 — 각 필드를 개별로 오염시킨 열 개 변형을 전부 확인한다.
    let surface = 표면()
    let 변형들: [LayerFrame] = [
        LayerFrame(center: Vec2(x: .nan, y: 500), size: Size2(width: 200, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: .infinity, y: 500), size: Size2(width: 200, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: .nan), size: Size2(width: 200, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: .infinity), size: Size2(width: 200, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: .nan, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: .infinity, height: 100), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: 200, height: .nan), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: 200, height: .infinity), rotation: 0),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: 200, height: 100), rotation: .nan),
        LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: 200, height: 100), rotation: .infinity),
    ]
    for frame in 변형들 {
        let placement = HandlePlacement(frame: frame, edges: [], on: surface)
        #expect(placement.box == nil)
    }
}

@Test func 크기가_0이거나_음수여도_box는_존재한다() {
    // 설계가 명시한 계약이다 — 크기 가드는 이 컴포넌트의 책임이 아니고
    // EDITOR-6이 얹힐 자리를 보존한다.
    let surface = 표면()
    let 영크기 = LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: 0, height: 0), rotation: 0)
    let 음수크기 = LayerFrame(center: Vec2(x: 500, y: 500), size: Size2(width: -50, height: -30), rotation: 0)

    #expect(HandlePlacement(frame: 영크기, edges: [], on: surface).box != nil)
    #expect(HandlePlacement(frame: 음수크기, edges: [], on: surface).box != nil)
}

@Test func 뷰포트가_0이어도_box가_생기고_좌표가_유한하며_뒤집힘으로_판정된다() throws {
    // scale이 0이 되어 모든 점이 viewport/2 = (0,0)으로 모인다. toLogical
    // 왕복은 scale=0일 때 항상 center를 반환해 어떤 구현이든 통과시키므로
    // 원시 화면 값만 본다.
    let surface = CanvasSurface(canvas: Size2(width: 1080, height: 1350),
                                 viewport: Size2(width: 0, height: 0))
    let frame = LayerFrame(center: Vec2(x: 500, y: 500),
                           size: Size2(width: 200, height: 100),
                           rotation: 0)
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    let 좌표들 = [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft, box.rotate]
        + box.edgeHandles.map { $0.position }
    for p in 좌표들 {
        #expect(p.x.isFinite && p.y.isFinite)
    }
    #expect(box.rotateFlipped == true)
}

// MARK: - empty

@Test func empty_상수는_선택_없음_상태를_나타낸다() {
    #expect(HandlePlacement.empty.box == nil)
    #expect(HandlePlacement.empty.orderedHandles.isEmpty)
    #expect(HandlePlacement.empty.edges.isEmpty)
}

// MARK: - edges 파생

@Test func edges_프로퍼티는_edgeHandles에서_파생된다() {
    // `정책밖프레임()`을 쓴다 — 기본 `뒤집기프레임`(판정값 50)은 `EDITOR-6`
    // 이후 `edges`가 항상 빈 집합이 되어 이 테스트가 재려는 "허용 집합이
    // edgeHandles를 통해 그대로 파생된다"는 관측이 무의미해진다.
    let surface = 표면()
    let frame = 정책밖프레임()
    let 허용 = Set<Edge>([.top, .left])
    let placement = HandlePlacement(frame: frame, edges: 허용, on: surface)

    #expect(placement.edges == 허용)
}

// MARK: - AC-15: 180° 회전 레이어에서 회전 핸들이 화면 안에 남는다

@Test func 회전_180도_레이어에서_회전_핸들은_화면_안에_남는다() throws {
    // up = (sin r, −cos r)은 레이어와 함께 회전한다. r=π에서 up = (0, 1) —
    // 화면 아래를 향한다. edgeMidpoint(.top)의 화면 y는 정확히 40으로 뒤집기
    // 판정(<=40)에 걸리는데, 뒤집은 위치는 edgeMidpoint(.bottom) − 28·up =
    // −10 − 28×1 = −38(화면 밖)이 된다. 안 뒤집은 위치라면
    // 40 + 28×1 = 68(화면 안)이어야 한다. 회전 0·π/2에서는 up.y ≤ 0이라
    // 이 역효과가 드러나지 않고, π 근방(90°~270°)에서만 보인다.
    let surface = 표면()
    let frame = LayerFrame(center: Vec2(x: 540, y: 5),
                           size: Size2(width: 200, height: 100),
                           rotation: .pi)
    let box = try #require(HandlePlacement(frame: frame, edges: [], on: surface).box)

    #expect(box.rotateFlipped == false)
    #expect(box.rotate.y > 0)
    #expect(isClose(box.rotate.y, 68))
}

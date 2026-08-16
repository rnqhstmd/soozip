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

// MARK: - EDITOR-6 사이클 1 전용 픽스처 (변 핸들 숨김, 88)
//
// 이 사이클은 코너 밀기(56)를 구현하지 않는다 — 아래 픽스처는 전부
// `box.edgeHandles`/`placement.edges`/`orderedHandles` 세 관측면만 잰다.
// 좌표는 오케스트레이터가 `toScreen(p) = (p.x/2, p.y/2 + 12.5)`로 전량
// 재검산한 이진 정확 값이다.

/// 판정값 정확히 70 = 140 × 0.5 — 56 이상 88 미만 구간(FR-3의 절반: 변만
/// 숨고 코너는 이 사이클에서 다루지 않는다). AC-2.
private func 변핸들숨김프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 140, height: 300), rotation: 0)
}

/// 판정값 정확히 56 = 112 × 0.5. `EDITOR-6` 사이클 2의 코너 밀기 임계값과
/// 같은 숫자지만, 이 사이클은 코너 밀기를 구현하지 않으므로 여기서는
/// "56 < 88이라 변 숨김 게이트가 이미 닫혀 있다"만 잰다(AC-4의 변 부분).
private func 코너밀기경계프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 112, height: 300), rotation: 0)
}

/// 판정값 200 = 400 × 0.5 — 88을 크게 넘는 대형 레이어. `정책밖프레임()`
/// (경계 정확히 88)만으로는 잡지 못하는 "임계값 부근에서만 우연히 통과"
/// 변이의 방어선이다(AC-8).
private func 대형정책밖프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 400, height: 400), rotation: 0)
}

/// AC-11(변 부분) 전용 — 줌 400% 표면. `HandleHitTestTests.swift`의
/// `확대표면()`과 같은 값이다(EDITOR-5가 "세 배율에서 TL이 같은 화면
/// 좌표에 오도록" 역산해 둔 팬 지점).
private func 줌400표면() -> CanvasSurface {
    표면().zoomed(to: 4).centered(on: Vec2(x: 465, y: 637.5))
}

/// AC-11(변 부분) 전용 — 줌 50% 표면. `HandleHitTestTests.swift`의
/// `축소표면()`과 같은 값이다.
private func 줌50표면() -> CanvasSurface {
    표면().zoomed(to: 0.5).centered(on: Vec2(x: 640, y: 725))
}

/// AC-11(변 부분)의 **유일한** 프레임 — PRD가 명시한 "동일 논리 프레임"
/// (중심 (540,675) · 200×100 · 회전 0)이다. `줌400표면()`·`줌50표면()`
/// 둘 다에 이 프레임 하나를 그대로 넣는다.
///
/// | 표면 | scale | TL 화면 | 판정값 |
/// |---|---|---|---|
/// | `줌400표면()` | 2.0 | **(220, 325)** | **200** |
/// | `줌50표면()` | 0.25 | **(220, 325)** | **25** |
///
/// **두 배율에서 TL이 정확히 같은 화면 좌표에 온다.** 이게 이 픽스처의
/// 요점이다 — 화면 위치가 완전히 동일한데 정책 상태(변 유무)만 갈리므로,
/// 차이를 만드는 것이 오직 `surface.scale`임이 격리된다. 판정값 계산에서
/// `surface.scale`을 빼고 `shortSide`만 쓰는 변이라면 둘 다 논리 100으로
/// 고정돼 두 배율이 **같은 정책 상태**가 되어 이 테스트가 죽인다.
private func 줌비교대상프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 200, height: 100), rotation: 0)
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

// MARK: - EDITOR-6 사이클 1: 변 핸들 숨김 (판정값 = shortSide × scale, 임계값 88)
//
// 코너 밀기(56)는 사이클 2 — AC-3·5·6·7·9·10·13은 여기서 다루지 않는다.

@Test func 판정값이_정확히_88이면_변_핸들이_넷_다_있다() throws {
    // 경계는 이전 상태다 — v4 §5.7 원문이 `< 88pt`를 명시하므로 정확히
    // 88이면 변이 "있는" 쪽이다. `flipThreshold`의 `<= 40`·`hitSize`의
    // `<= 22`가 세운 "경계 포함" 관례와 이 상수만 **반대**라서, 그것을
    // 모르면 `<=`로 "통일"하는 변경이 자연스러워 보인다 — 이 테스트가
    // 그 변이(부등호 반전)를 죽인다.
    //
    // `정책밖프레임()`(176×300)을 재사용한다 — 사이클 0에서 이미 이
    // 픽스처가 "정책 도입 전 준비"로 옮겨져 있다. 이 테스트는 정책 도입
    // 전에도 통과한다(변이 항상 존재하므로) — 진짜 RED는 아래 두 테스트다.
    let surface = 표면()
    let frame = 정책밖프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(box.edgeHandles.count == 4)
    #expect(isClose(box.topLeft.x, 226))
    #expect(isClose(box.topLeft.y, 275))
}

@Test func 판정값이_88_미만이면_변_핸들이_전부_사라진다() throws {
    // 판정값 70 (56 이상 88 미만) — FR-1의 핵심 RED다. `box.edgeHandles`·
    // `placement.edges`·`orderedHandles` 세 파생 경로 모두에서 변이
    // 사라지는지 잰다(설계서 testability: "showsEdges 게이트 — 세 관측면
    // 전부"). 하나만 재면, 예컨대 `edgeHandles`는 걸러도 `orderedHandles`
    // 조립부가 여전히 옛 배열을 이어붙이는 변이를 놓친다.
    let surface = 표면()
    let frame = 변핸들숨김프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(box.edgeHandles.isEmpty)
    #expect(placement.edges.isEmpty)
    #expect(placement.orderedHandles.count == 6)
    #expect(placement.orderedHandles.allSatisfy {
        if case .edge = $0.handle { return false }
        return true
    })
}

@Test func 판정값이_56이면_변_핸들은_이미_숨어_있다() throws {
    // 이 사이클(사이클 1)은 코너 밀기(56)를 구현하지 않는다 — `topLeft`는
    // 다음 사이클의 관측 대상이므로 여기서 재지 않는다. 56 < 88이라 변
    // 숨김 게이트는 이미 닫혀 있어야 하고, 그것만이 이 테스트의 대상이다
    // (AC-4의 변 부분).
    let surface = 표면()
    let frame = 코너밀기경계프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(box.edgeHandles.isEmpty)
}

@Test func 판정값이_88을_크게_넘으면_변_핸들_10개_전부_존재한다() throws {
    // `정책밖프레임()`(판정값 정확히 88)만으로는 "경계 부근에서만 우연히
    // 통과"하는 변이(예: `>=` 를 `==`로 바꾸는 변이)를 못 죽인다. 400×400
    // (판정값 200)으로 임계값에서 멀찍이 떨어진 지점에서 회귀 없음(FR-4)을
    // 확인한다. 이 테스트도 정책 도입 전부터 통과한다 — 부등호 반전
    // 변이를 죽이는 방어선이지, RED 신호 자체는 아니다.
    let surface = 표면()
    let frame = 대형정책밖프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(box.edgeHandles.count == 4)
    #expect(placement.orderedHandles.count == 10)
    #expect(isClose(box.topLeft.x, 170))
    #expect(isClose(box.topLeft.y, 250))
}

@Test func 같은_논리_프레임도_줌만_바꾸면_변_핸들_유무가_달라진다() throws {
    // 결정 1(화면 pt)의 핵심 관측 — **같은 프레임**(줌비교대상프레임(),
    // 중심 (540,675))을 두 표면(400%·50%)에 그대로 넣는다.
    //
    // 두 표면은 같은 논리 프레임의 좌상단을 **밀기 전 기준으로는 똑같이
    // 화면 (220,325)에 놓도록** 역산돼 있다(`EDITOR-5`의 `확대표면()`·
    // `축소표면()`과 같은 값). 그래서 이 쌍은 위치가 아니라 **`surface.scale`
    // 하나만** 갈린다 — 판정값에서 `scale`을 빼면 둘 다 논리 100으로
    // 고정돼 같은 상태가 되고 400% 쪽 `count == 4`가 깨진다.
    //
    // **50%의 좌상단은 단언하지 않는다.** 판정값 25는 코너 밀기 구간
    // (< 56)이라 다음 사이클에서 밀린 좌상단 (198,303)으로 이동한다 —
    // 여기서 (220,325)로 고정하면 그 사이클이 이 테스트를 깨뜨린다.
    // 좌상단 이동은 코너 밀기 AC가 잰다.
    let 확대box = try #require(
        HandlePlacement(frame: 줌비교대상프레임(), edges: Set(Edge.allCases), on: 줌400표면()).box
    )
    #expect(확대box.edgeHandles.count == 4)
    #expect(isClose(확대box.topLeft.x, 220))
    #expect(isClose(확대box.topLeft.y, 325))

    let 축소placement = HandlePlacement(frame: 줌비교대상프레임(), edges: Set(Edge.allCases), on: 줌50표면())
    #expect(축소placement.edges.isEmpty)
}

@Test func edgeHideThreshold_상수는_88이다() {
    // `hitSize`(44)에서 파생하지 않는 독립 리터럴이어야 한다(BR-4). 지금
    // 상수 자체가 없어 이 참조 하나만으로 파일 전체가 컴파일에 실패한다 —
    // 이것이 이 사이클의 1차 RED 신호다(Swift에는 NoSuchMethodError가
    // 없으므로 컴파일 에러가 그 역할을 한다).
    #expect(HandlePlacement.edgeHideThreshold == 88)
}

// MARK: - EDITOR-6 사이클 2: 코너 밀기 (판정값 < 56, 화면 델타 부호 + 성분별 폴백)
//
// `cornerPushThreshold`·`cornerPush` 두 상수가 아직 소스에 없다 — 이 섹션의
// 어떤 테스트든 참조하는 순간 파일 전체가 컴파일에 실패한다. 그것이 이
// 사이클의 1차 RED 신호다(Swift에는 NoSuchMethodError가 없다).

// MARK: - 사이클 2 전용 픽스처

/// 판정값 정확히 50 = 100 × 0.5. 코너 밀기가 발동하는 표준 픽스처
/// (AC-5·6·9). 밀림 전 네 코너는 (245,275)·(295,275)·(295,425)·(245,425)다.
private func 코너밀림프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 100, height: 300), rotation: 0)
}

/// 판정값 정확히 40 = 80 × 0.5, 정사각형. `edges: []`인 종류(photo 등)에도
/// 코너 정책이 걸리는지 재는 AC-7 전용 픽스처다.
private func 변없는초소형프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 80, height: 80), rotation: 0)
}

/// `코너밀림프레임()`과 같은 크기(100×300)를 45°로 돌린 것 — AC-10. 판정값이
/// 회전에 무관함(결정 2)과 밀기 방향이 `Corner.sign`이 아니라 화면 델타
/// 부호임(결정 3-정정)을 동시에 고정하는 유일한 무리수 좌표 픽스처다.
private func 사십오도코너밀림프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 100, height: 300), rotation: .pi / 4)
}

/// 크기 (0,0) — AC-13. 네 코너가 화면 중심(밀기 기준점)과 완전히 겹쳐 델타가
/// (0,0)이 된다. **주의**: 이 픽스처는 "전체 벡터가 (0,0)일 때만 폴백"하는
/// 변이도 통과시킨다(두 성분이 동시에 0이라서) — 그 변이의 유일한 증인은
/// 아래 `영폭프레임()`·`영높이프레임()`이다.
private func 영크기프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 0, height: 0), rotation: 0)
}

/// 88×300을 π(180°)로 돌린 것 — 결정 3-정정의 핵심 방어선 중 하나(다른
/// 둘은 AC-10·인접겹침프레임, `HandleHitTestTests.swift` 참조). `Corner.sign`
/// (로컬 부호)을 화면 델타로 그대로 쓰는 변이는 밀린 좌상단·우상단을
/// **정확히 같은 점** (270,403)으로 만들어 간격을 88 → 0으로 무너뜨린다 —
/// 겹침을 막으려는 정책이 없던 겹침을 만드는 최악의 사례다. 화면 델타
/// 부호(채택안)는 반대로 간격을 88로 유지한다.
private func 반회전프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 88, height: 300), rotation: .pi)
}

/// 폭이 정확히 0 — 좌상단·우상단의 화면 x 델타가 0이 된다(y 델타는 −75로
/// 0이 아니다). "전체 벡터가 (0,0)일 때만 폴백"하는 변이는 x축 폴백을
/// 건너뛰어 두 코너를 한 점으로 붕괴시킨다. `영크기프레임()`(AC-13)은 두
/// 성분이 동시에 0이라 이 변이를 통과시키므로, 성분별 폴백의 증인은 이
/// 픽스처와 `영높이프레임()` 둘뿐이다.
private func 영폭프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 0, height: 300), rotation: 0)
}

/// 높이가 정확히 0 — `영폭프레임()`의 y축 짝. 좌상단·좌하단의 화면 y 델타가
/// 0이 되고(x는 −75로 0이 아니다), "전체 벡터" 폴백 변이는 둘을 y = 350 한
/// 점으로 붕괴시킨다.
private func 영높이프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 300, height: 0), rotation: 0)
}

// MARK: - AC-3: 56~88 구간에서는 코너가 밀리지 않는다

@Test func 판정값이_70이면_56_이상이라_코너가_밀리지_않는다() throws {
    // `변핸들숨김프레임()`(140×300, 판정값 70)을 재사용한다 — 사이클 1은 변
    // 숨김만 쟀고 코너 좌표는 손대지 않았다. (235,275)는 밀기 전 원래
    // 좌표이며, `cornerPushThreshold`가 도입된 뒤에도 56~88 구간에서는
    // 그대로여야 한다(FR-3).
    let surface = 표면()
    let placement = HandlePlacement(frame: 변핸들숨김프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 235))
    #expect(isClose(box.topLeft.y, 275))
}

// MARK: - AC-4: 판정값이 정확히 56이면 코너가 밀리지 않는다

@Test func 판정값이_정확히_56이면_코너가_밀리지_않는다() throws {
    // 경계는 이전 상태다 — v4 §5.7이 `< 56pt`를 명시하므로 정확히 56이면
    // 코너가 "밀리지 않는" 쪽이다(BR-1). **56 경계의 단독 방어선**이다 — 88
    // 경계는 정책밖프레임·B-3·C-6 등 6중 방어선이 있지만 56은 이 테스트
    // 하나뿐이다(설계서 testability "88 경계는 6중, 56 경계는 단독"). `<`를
    // `<=`로 뒤집는 변이는 여기서만 잡힌다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 코너밀기경계프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 242))
    #expect(isClose(box.topLeft.y, 275))
}

// MARK: - AC-5·6·9: 판정값 50 — 코너 밀기 + 삭제 동행 + 회전 무영향

@Test func 판정값이_50이면_네_코너가_화면_축_방향으로_22pt씩_밀린다() throws {
    // AC-5. 밀림 전 네 코너는 (245,275)·(295,275)·(295,425)·(245,425)다
    // (표면() 중심 (540,675) 기준). 화면 중심에서 각 코너로 향하는 델타
    // 부호대로 22pt씩 벌어진다. 네 코너·양 성분을 전부 재야 코너가
    // 뒤바뀌는 변이(예: bottomRight에 topRight 값을 밀어 넣는)를 잡는다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 코너밀림프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    let 기대 = [
        (box.topLeft, Vec2(x: 223, y: 253)),
        (box.topRight, Vec2(x: 317, y: 253)),
        (box.bottomRight, Vec2(x: 317, y: 447)),
        (box.bottomLeft, Vec2(x: 223, y: 447)),
    ]
    for (실제, 기대값) in 기대 {
        #expect(isClose(실제.x, 기대값.x))
        #expect(isClose(실제.y, 기대값.y))
    }
}

@Test func 코너가_밀리면_삭제_핸들도_밀린_좌상단을_그대로_따라간다() throws {
    // AC-6. `Box.delete = { topLeft }` 계산 프로퍼티라 코너가 밀린 뒤에도
    // 어긋나지 않아야 한다(FR-5) — 밀기를 topLeft에만 적용하고 delete를
    // 별도 저장 프로퍼티로 두는 변이가 있다면 여기서 두 값이 갈라진다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 코너밀림프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.delete.x, box.topLeft.x))
    #expect(isClose(box.delete.y, box.topLeft.y))
    #expect(isClose(box.delete.x, 223))
    #expect(isClose(box.delete.y, 253))
}

@Test func 코너가_밀려도_회전_핸들은_상단_변_중점_기준을_그대로_쓴다() throws {
    // AC-9. 회전 핸들은 상단 변 중점 (270,275)에서 28pt 위인 (270,247)이어야
    // 한다(FR-6). 밀린 좌상단(223,253)·우상단(317,253)의 중점 (270,253)을
    // 기준으로 삼는 변이는 대신 (270,225)를 낸다 — 22pt 차이가 이 두 구현을
    // 가르는 유일한 방어선이다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 코너밀림프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.rotate.x, 270))
    #expect(isClose(box.rotate.y, 247))
}

// MARK: - AC-7: 변 핸들이 없는 종류도 코너는 밀린다 (종류 축과 크기 축의 독립성)

@Test func 변_핸들이_없는_종류도_코너는_밀린다() throws {
    // AC-7. `edges: []`로 photo·stamp·drawing 같은 종류를 흉내낸다(FR-8).
    // 좌상단·우하단을 재고 개수(6 = 삭제1+코너4+회전1)까지 확인해 "변이
    // 아예 없으니 orderedHandles도 비어야 한다"는 잘못된 결합을 만드는
    // 변이를 잡는다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 변없는초소형프레임(), edges: [], on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 228))
    #expect(isClose(box.topLeft.y, 308))
    #expect(isClose(box.bottomRight.x, 312))
    #expect(isClose(box.bottomRight.y, 392))
    #expect(placement.orderedHandles.count == 6)
}

// MARK: - AC-10: 45° 회전 — 판정값 불변 + 화면 델타 부호 밀기 (결정 2·3-정정)

@Test func 사십오도_회전에서도_판정값은_불변이고_밀기는_화면_델타_부호를_따른다() throws {
    // AC-10 + 결정 3-정정의 핵심 증거. 밀기 전 좌상단은 화면 (305.3553,
    // 279.2893)이고 박스 화면 중심 (270,350) 기준 델타는 (+35.3553,
    // −70.7107)이다 — 부호 (+1,−1)로 밀리면 (327.3553,257.2893)이 된다.
    //
    // 검산 1(결정 2): 화면 축 바운딩 박스로 짧은 변을 쟀다면 45°에서
    // (50+150)·√2 × 0.5 ≈ 141.4 > 88이 되어 정책이 아예 발동하지 않았을
    // 것이다 — 이 테스트가 통과한다는 사실 자체가 `Size2.shortSide`가
    // **로컬** 값임을 증명한다.
    //
    // 검산 2(결정 3-정정): `Corner.sign`(로컬 부호, x=−1)을 그대로 밀기에
    // 쓰면 x가 −22 되어 (283.3553, 257.2893)을 낸다 — 이 테스트는 그 값과
    // x축 44pt 차이로 갈린다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 사십오도코너밀림프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 327.3553))
    #expect(isClose(box.topLeft.y, 257.2893))
}

// MARK: - AC-11(코너 부분): 줌 50%에서는 판정값이 25가 되어 코너가 밀린다

@Test func 줌_50_퍼센트에서는_판정값이_25가_되어_코너가_밀린다() throws {
    // AC-11의 코너 밀기 절반(사이클 2). 사이클 1은 같은 표면 쌍에서
    // `edges.isEmpty`만 쟀고 좌상단은 "다음 사이클이 잰다"며 비워 뒀다
    // (`같은_논리_프레임도_줌만_바꾸면_변_핸들_유무가_달라진다` 주석 참조).
    // 밀기 전 좌상단은 두 배율 모두 화면 (220,325)에 오도록 표면이
    // 역산돼 있다 — 여기서는 판정값 25(<56)로 코너가 밀려 박스 화면 중심
    // (245,337.5) 기준 델타 (−25,−12.5)만큼 22pt씩 더 밀린 (198,303)이어야
    // 한다.
    let surface = 줌50표면()
    let placement = HandlePlacement(frame: 줌비교대상프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 198))
    #expect(isClose(box.topLeft.y, 303))
}

// MARK: - AC-13: 크기 0에서 네 코너가 Corner.sign으로 폴백한다

@Test func 크기_0에서_네_코너가_모두_Corner_sign_방향으로_폴백한다() throws {
    // AC-13. 크기가 0이면 네 코너가 전부 화면 중심(밀기 기준점)과 겹쳐
    // 델타가 (0,0)이 된다 — 폴백이 없으면 네 점이 한 점으로 뭉친다. 어떤
    // 좌표에도 NaN이 없는지도 함께 잰다(BR-3).
    let surface = 표면()
    let placement = HandlePlacement(frame: 영크기프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    let 기대 = [
        (box.topLeft, Vec2(x: 248, y: 328)),
        (box.topRight, Vec2(x: 292, y: 328)),
        (box.bottomRight, Vec2(x: 292, y: 372)),
        (box.bottomLeft, Vec2(x: 248, y: 372)),
    ]
    for (실제, 기대값) in 기대 {
        #expect(isClose(실제.x, 기대값.x))
        #expect(isClose(실제.y, 기대값.y))
        #expect(실제.x.isFinite && 실제.y.isFinite)
    }
}

// MARK: - AC-14: cornerPushThreshold·cornerPush 리터럴

@Test func cornerPushThreshold와_cornerPush_상수는_56과_22다() {
    // `hitSize`에서 파생하지 않는 독립 리터럴이어야 한다(BR-4). 지금 두
    // 상수 모두 소스에 없어 이 참조만으로 파일 전체가 컴파일에 실패한다 —
    // 이것이 이 사이클의 1차 RED 신호다.
    #expect(HandlePlacement.cornerPushThreshold == 56)
    #expect(HandlePlacement.cornerPush == 22)
}

// MARK: - 결정 3-정정: 회전 π — Corner.sign 채택 시 간격이 0으로 무너지는 반례

@Test func 회전_180도_88폭_레이어에서_좌상단과_우상단이_88pt_간격을_유지한다() throws {
    // 결정 3-정정의 핵심 방어선(88×300·π). `Corner.sign`(로컬 부호)을 화면
    // 델타로 그대로 쓰는 변이는 밀린 좌상단·우상단을 **정확히 같은 점**
    // (270,403)으로 만들어 간격을 88 → 0으로 무너뜨린다 — 겹침을 막으려는
    // 정책이 없던 겹침을 만드는 최악의 사례다. 화면 델타 부호(채택안)는
    // 반대로 간격을 88로 유지한다.
    //
    // 이 변이를 죽이는 것은 이 테스트 하나만이 아니다 — AC-10(x가 44pt
    // 어긋난다)과 `HandleHitTestTests.swift`의 결정 8 특성화 테스트도 각각
    // 다른 각도에서 같은 변이를 죽인다(설계서 red-writer 필수 인계 #2).
    // 셋 다 필요하다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 반회전프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 314))
    #expect(isClose(box.topLeft.y, 447))
    #expect(isClose(box.topRight.x, 226))
    #expect(isClose(box.topRight.y, 447))
}

// MARK: - 성분별 폴백의 증인 (2회차 설계 감점을 메우는 3회차 신설 픽스처)

@Test func 폭이_0이면_x_축만_Corner_sign으로_폴백해_좌상단과_우상단이_갈라진다() throws {
    // 성분별 폴백의 증인 중 하나. `영크기프레임()`(AC-13)은 두 성분이
    // 동시에 0이라 "전체 벡터가 (0,0)일 때만 폴백"하는 변이도 통과시킨다.
    // 이 픽스처는 x 델타만 0이라(y는 −75로 0이 아님) 그 변이가 x 밀기를
    // 0으로 만들어 좌상단·우상단을 (270,253) 한 점으로 붕괴시킨다 —
    // 성분별 폴백(채택안)만이 이 둘을 (248,253)·(292,253)으로 갈라놓는다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 영폭프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 248))
    #expect(isClose(box.topLeft.y, 253))
    #expect(isClose(box.topRight.x, 292))
    #expect(isClose(box.topRight.y, 253))
}

@Test func 높이가_0이면_y_축만_Corner_sign으로_폴백해_좌상단과_좌하단이_갈라진다() throws {
    // `영폭프레임()`의 y축 짝. 높이가 0이라 좌상단·좌하단의 화면 y 델타가
    // 0이 되고(x는 −75로 0이 아니다), "전체 벡터" 폴백 변이는 둘을 y = 350
    // 한 점으로 붕괴시킨다.
    let surface = 표면()
    let placement = HandlePlacement(frame: 영높이프레임(), edges: Set(Edge.allCases), on: surface)
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 173))
    #expect(isClose(box.topLeft.y, 328))
    #expect(isClose(box.bottomLeft.x, 173))
    #expect(isClose(box.bottomLeft.y, 372))
}

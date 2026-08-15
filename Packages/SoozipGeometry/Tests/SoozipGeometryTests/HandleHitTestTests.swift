import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-5 — 핸들 히트 판정. "화면의 한 점을 눌렀을 때 그중 무엇이 잡히는가"를
// 검증한다. `hitCandidates(at:)`는 제스처 없이 겹친 핸들 전부를, `hitHandle(at:for:)`는
// 제스처(BR-3 정책 포함)가 확정된 최종 하나를 낸다.
//
// 좌표는 전부 설계서(`.dev/feat-editor-hit-testing/design.md`)가 검산해 둔 값을
// 그대로 옮긴 것이다 — 각 탐침은 특정 변이를 죽이도록 골라졌으므로 임의로 바꾸지 않는다.

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

// MARK: - 기준 표면 (EDITOR-4 픽스처와 동일)
//
// fitScale = 0.5 정확. toScreen(p).x = p.x/2, toScreen(p).y = p.y/2 + 12.5.

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: Size2(width: 1080, height: 1350),
                  viewport: Size2(width: 540, height: 700))
}

// MARK: - 픽스처 A: 회전핸들프레임() — AC-1 · M6 · M3
//
// center (540, 281), size 200×100, rotation 0. rotate 핸들이 화면 (270,100)에
// 온다(top mid=(270,128), 뒤집히지 않음, 28pt 위).

private func 회전핸들프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 281), size: Size2(width: 200, height: 100), rotation: 0)
}

// MARK: - 픽스처 B: 경계프레임() — AC-2·3 · M1
//
// center (100, 125), size 200×100, rotation 0. 우하단 코너가 화면 (100,100),
// 우측 변 중점이 화면 (100,75)에 온다.

private func 경계프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 100, y: 125), size: Size2(width: 200, height: 100), rotation: 0)
}

// MARK: - 픽스처 C: 겹침프레임() — AC-5·6·7·9 · M2+M4
//
// center (500, 425), size 200×100, rotation 0. 좌상단 코너와 삭제가 동일 좌표
// 화면 (200,200)에 겹친다.

private func 겹침프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 500, y: 425), size: Size2(width: 200, height: 100), rotation: 0)
}

// MARK: - 픽스처 D: 초소형프레임() — AC-8 · M7
//
// center (540, 675), size 40×40. 좌상단·우상단 코너의 화면 거리가 20pt로,
// 제스처로도 안 갈리는 진짜 동점 상황(BR-4 폴백)을 만든다.

private func 초소형프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 40, height: 40), rotation: 0)
}

// MARK: - 픽스처 E: 회전45프레임() — AC-4
//
// center (540, 675), size 400×400, rotation = π/4. 45°에서만 "로컬 축 정렬"과
// "화면 축 정렬" 두 해석이 갈린다 — 회전 0에서는 두 해석이 구별되지 않는다.

private func 회전45프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 400, height: 400), rotation: .pi / 4)
}

// MARK: - 픽스처 F: 줌비교프레임() — AC-11·12·13
//
// center (540, 675), size 200×100, rotation 0, edges: []. 세 표면(100%·400%·50%)
// 모두 같은 화면 좌표에 핸들이 오도록 표면 쪽에서 줌·팬을 맞춘다 — FR-6(줌과
// 무관하게 화면 44pt 고정)을 재는 것이 목적이라 프레임은 하나로 고정한다.
//
// edges: []인 이유: 50%에서 레이어가 화면 50×25pt로 줄어 top mid가 히트해
// 세 표면의 기대 시퀀스가 갈라진다. 변을 빼야 세 케이스를 글자 그대로 같게 잰다.

private func 줌비교프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 200, height: 100), rotation: 0)
}

/// 줌 400%(`zoomLimits.max`) 표면. center는 **TL이 100% 표면과 똑같이 화면
/// (220,325)에 오도록 역산한 값**이다 — `(440−465)·2+270 = 220`,
/// `(625−637.5)·2+350 = 325`. 세 배율의 기대 시퀀스를 글자 그대로 같게
/// 유지하는 것이 픽스처 F의 요점이라, 이 좌표가 어긋나면 AC-11의 비교가 무의미해진다.
private func 확대표면() -> CanvasSurface {
    표면().zoomed(to: 4).centered(on: Vec2(x: 465, y: 637.5))
}

/// 줌 50%(`zoomLimits.min`) 표면. 같은 역산 — `(440−640)·0.25+270 = 220`,
/// `(625−725)·0.25+350 = 325`.
private func 축소표면() -> CanvasSurface {
    표면().zoomed(to: 0.5).centered(on: Vec2(x: 640, y: 725))
}

// MARK: - 픽스처 G: 화면밖프레임() — AC-14
//
// center (540, −177), edges: allCases. 뷰포트(화면 y=0) 밖에 놓여 회전 핸들이
// 뒤집힌 채로 화면 (270,−23)에 온다.

private func 화면밖프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: -177), size: Size2(width: 200, height: 100), rotation: 0)
}

// MARK: - A-1 (AC-1): 탐침 (270,100) — rotate 핸들 정중앙

@Test func 회전_핸들_중심점은_탭과_드래그_모두에서_잡힌다() throws {
    // 드래그 단언이 핵심이다 — 후보가 [.rotate] 단 하나뿐인 지점에서
    // `hitCandidates(at:).dropFirst().first { ... }`처럼 첫 원소를 버리는 변이는
    // 드래그를 nil로 만든다. 탭만 재면 이 변이가 살아남는다.
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: 100)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.rotate])

    let 탭결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(탭결과.handle == .rotate)

    let 드래그결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(드래그결과.handle == .rotate)
}

// MARK: - A-2 (M6a): 탐침 (270,78) — rotate 상단 경계, dy=22 정확히

@Test func 회전_핸들_상단_경계_22pt는_포함된다() {
    // y축 상한 경계다. x축만 `<=`로 두고 y축을 `<`로 바꾸는 변이는 이 지점만
    // 죽인다 — 다른 23건은 이 변이를 전부 통과시킨다(설계서 §M6).
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: 78)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.rotate])
}

// MARK: - A-3 (M6b): 탐침 (270,77.5) — rotate 바로 밖, dy=22.5

@Test func 회전_핸들_경계_22_5pt는_제외된다() throws {
    // 위 경계-포함 테스트와 쌍을 이룬다. 이 지점 하나만으로는 `<` vs `<=`를
    // 구별 못 한다(둘 다 미스) — 반드시 (270,78) 쪽과 함께 있어야 방어선이 된다.
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: 77.5)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
}

// MARK: - A-4·A-5 (M3): NaN 지점 — 반대 축이 rotate와 0pt로 정확히 겹쳐야
// NaN 축 단독으로 판정을 가른다.
//
// `HandlePlacement.empty`로 재면 애초에 후보가 없어 공허한 통과가 되므로,
// 반드시 box != nil인 이 픽스처에서 잰다.

@Test func x_좌표가_비유한이면_y가_rotate와_같아도_핸들_아니다() throws {
    // (.nan, 100)에서 y=100은 rotate.y와 정확히 같다(0pt). 그래서 x축의 NaN
    // 처리만으로 판정이 갈린다. `!(abs(d) > half)`처럼 뒤집은 형태로 구현하면
    // `abs(NaN) > half`가 거짓이라 `!false = true`가 되어 NaN이 히트가 된다.
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: .nan, y: 100)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

@Test func y_좌표가_비유한이면_x가_rotate와_같아도_핸들_아니다() throws {
    // (270, .nan)에서 x=270은 rotate.x와 정확히 같다(0pt) — y축 짝.
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: .nan)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

// MARK: - A-6·A-7 (M8): 유한하지만 극단인 입력 — `.isFinite` 가드를 통과해 들어온다
//
// `HandlePlacement.init`의 가드는 **입력 프레임**의 유한성만 검사한다. 프레임이
// 유한해도 판정 지점은 `public` API로 임의 값이 들어오고, 특히
// `.greatestFiniteMagnitude`는 `.isFinite`가 참이라 **어떤 유한성 가드도
// 걸러내지 못한다.**
//
// 이 두 건이 방어하는 것은 **거리 공식 변경이 아니다** — 무한대에서는 유클리드로
// 바꿔도 `dx² → inf`라 똑같이 미스한다(유클리드 변이를 죽이는 것은 C-6의
// (220,220)이다). 방어하는 것은 **판정을 뒤집거나 좌표를 클램프하는 변이**다:
// `!(abs(d) > half)`는 `NaN`을 히트로 만들고, 지점 클램프는 극단값을 유한한
// 자리로 끌어와 히트로 만든다. 지금은 그 안전성이 테스트 없이 성립하는 상태다.

@Test func 무한대_지점은_핸들_아니다() {
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: .infinity, y: 100)   // y는 rotate와 0pt로 정확히 겹친다

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

@Test func 표현_가능한_최대값_지점은_핸들_아니다() {
    // `.isFinite`가 참이라 어떤 유한성 가드도 걸러내지 못하는 값이다.
    let placement = HandlePlacement(frame: 회전핸들프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: .greatestFiniteMagnitude, y: 100)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

// MARK: - B-1 (AC-2): 탐침 (122,100) — 우하단 코너 경계 안쪽

@Test func 우하단_코너_경계_22pt_이내는_탭으로_잡힌다() throws {
    // 우측 변 중점(100,75)은 이 탐침에서 dy=25>22라 미스여야 한다 — `&&`가
    // `‖`로 바뀌면 x축만 맞아도 히트가 되어 변까지 후보에 섞여 든다.
    let placement = HandlePlacement(frame: 경계프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 122, y: 100)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.corner(.bottomRight)])

    let 탭결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(탭결과.handle == .corner(.bottomRight))
}

// MARK: - B-2 (AC-3): 탐침 (122.5,100) — 경계 바로 밖

@Test func 우하단_코너_경계_22_5pt_초과는_탭으로_잡히지_않는다() {
    let placement = HandlePlacement(frame: 경계프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 122.5, y: 100)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
}

// MARK: - B-3 (M1): 탐침 (100,75) — 우측 변 중점 정확히

@Test func 우측_변_핸들은_탭과_드래그_모두에서_잡힌다() throws {
    // "드래그는 코너만 잡는다"는 틀렸다(변도 리사이즈 가능) — 드래그 단언이
    // 그 변이를 죽인다. "탭은 변을 뺀다"도 틀렸다 — 삭제만 드래그에서
    // 빠질 뿐, 탭은 변을 포함한 전부에서 최우선 후보를 낸다.
    let placement = HandlePlacement(frame: 경계프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 100, y: 75)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.edge(.right)])

    let 탭결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(탭결과.handle == .edge(.right))

    let 드래그결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(드래그결과.handle == .edge(.right))
}

// MARK: - C-1 (AC-5): 탐침 (200,200) — 삭제·좌상단 겹침, 제스처 없이 조회

@Test func 삭제와_좌상단_코너가_겹치면_후보_목록에_둘_다_삭제_우선으로_담긴다() {
    // 좌측 변 중점(200,225)은 dy=25>22라 미스해야 한다 — 22를 25로 넓히는
    // 변이는 후보가 3개로 늘어나 이 정확한 2개 비교에서 잡힌다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 200, y: 200)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.delete, .corner(.topLeft)])
}

// MARK: - C-2 (AC-6): 같은 지점, 탭

@Test func 삭제와_좌상단이_겹치면_탭은_삭제를_잡는다() throws {
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 200, y: 200)

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(결과.handle == .delete)
}

// MARK: - C-3 (AC-7): 같은 지점, 드래그 — BR-3의 핵심

@Test func 삭제와_좌상단이_겹치면_드래그는_좌상단_코너를_잡는다() throws {
    // BR-3이 없으면(제스처 무관 정책) 순서상 최우선인 삭제가 드래그에서도
    // 이겨 좌상단 코너는 영영 리사이즈할 수 없다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 200, y: 200)

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(결과.handle == .corner(.topLeft))
}

// MARK: - C-4·C-5 (AC-9a·9b): 먼 지점 — 한 축은 정확히 정렬, 다른 축만 멀다

@Test func 가장_가까운_핸들과_y축으로만_먼_지점은_두_제스처_모두_핸들_아니다() {
    // (200,400)은 좌하단(200,250)과 x가 정확히 0pt 일치하고 y만 150pt 멀다.
    // `&&`가 `‖`로 바뀌면 x축 일치만으로 히트가 되어 이 지점이 거짓양성이 된다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 200, y: 400)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

@Test func 가장_가까운_핸들과_x축으로만_먼_지점은_두_제스처_모두_핸들_아니다() {
    // (500,200)은 우상단(300,200)과 y가 정확히 0pt 일치하고 x만 200pt 멀다 —
    // 위 테스트의 반대 축 짝이다. 두 축 각각에서 `&&`→`‖` 변이를 잡는다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 500, y: 200)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

// MARK: - C-6 (M2+M4): 탐침 (220,220) — 원·맨해튼 구별 + position 바꿔치기 방어

@Test func 삭제_좌상단_좌측변이_겹치는_지점의_후보는_원래_핸들_위치를_보고한다() throws {
    // 좌상단(200,200)은 이 탐침에서 dx=20,dy=20이라 사각형(맨해튼 기준 각 축
    // 독립 22 이내)으로는 히트이지만, 유클리드 거리로 재면 √800≈28.28>22로
    // 미스가 된다 — "원·맨해튼" 변이가 이 지점에서만 갈린다.
    //
    // 세 기대 position(200,200)·(200,200)·(200,225)이 전부 탐침(220,220)과
    // 다르다 — `PlacedHandle(handle: h, position: point)`처럼 필터가 반환한
    // 원소의 위치를 탐침 좌표로 바꿔치기하는 변이는 이 대조가 아니면 안 잡힌다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 220, y: 220)

    let 후보 = placement.hitCandidates(at: 탐침)
    try #require(후보.count == 3)
    #expect(후보.map(\.handle) == [.delete, .corner(.topLeft), .edge(.left)])

    #expect(isClose(후보[0].position.x, 200))
    #expect(isClose(후보[0].position.y, 200))
    #expect(isClose(후보[1].position.x, 200))
    #expect(isClose(후보[1].position.y, 200))
    #expect(isClose(후보[2].position.x, 200))
    #expect(isClose(후보[2].position.y, 225))
}

// MARK: - D-1 (AC-8): 탐침 (270,340) — 좌상단·우상단 코너 거리 20pt, 진짜 동점

@Test func 코너_거리가_20pt인_초소형_레이어에서_드래그는_좌상단_코너를_잡는다() throws {
    // 좌상단과 우상단은 정중앙에서 거리가 완전히 같다(둘 다 dx=10,dy=0) —
    // 삭제와 무관한 진짜 동점이라 제스처가 갈라주지 못하고 `orderedHandles`
    // 순서(TL이 TR보다 앞)만이 승자를 정한다(BR-4). 이 순서를 재배열하는
    // 변이나 `orderedHandles`를 거치지 않는 구현은 이 결과를 뒤집는다.
    let placement = HandlePlacement(frame: 초소형프레임(), edges: [], on: 표면())
    let 탐침 = Vec2(x: 270, y: 340)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
    ])

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(결과.handle == .corner(.topLeft))
}

// MARK: - D-2 (M7): 같은 초소형 레이어, edges: allCases, 탐침 (270,350) — 박스 화면 중심

@Test func 모든_변이_허용되면_변_핸들_후보_순서는_시계방향_top_right_bottom_left다() {
    // 박스 화면 중심에서는 4코너 + 4변이 전부 22pt 이내로 들어와 후보가 9개다.
    // 변 하위 순서(top→right→bottom→left)를 다른 어떤 탐침도 고정하지
    // 못한다 — `edgeOrder`를 `allCases`(선언 순서: left,right,top,bottom)로
    // 대신 쓰는 변이를 잡는 유일한 테스트다.
    let placement = HandlePlacement(frame: 초소형프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: 350)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
        .edge(.top), .edge(.right), .edge(.bottom), .edge(.left),
    ])
}

// MARK: - D-3 (특성화): 탐침 (278,358) — BR가 2.83pt로 최근접인데 순서가 이긴다

@Test func 겹침에서는_최근접_핸들이_아니라_orderedHandles_순서가_이긴다() throws {
    // 판정은 거리를 **보지 않는다**(BR-4). 손가락이 우하단 코너 정중앙에서
    // 2.83pt 거리인데도 드래그는 좌상단 코너를 잡는다 — 좌상단이 2.83pt가
    // 아니라 25.5pt 떨어져 있는데도 그렇다.
    //
    // 이 테스트가 없으면 `hitCandidates(at:).sorted { 거리 }.first { accepts }`
    // 변이가 나머지 26건 전부를 통과한다 — 다른 모든 hitHandle 단언은 후보가
    // 1개이거나 거리가 정확히 동점이라 정렬해도 순서가 안 바뀐다.
    //
    // 근접 우선이 제품 의도가 되면 그것은 이 단위의 결함이 아니라
    // `EDITOR-6`·`EDITOR-10`의 새 AC다.
    let placement = HandlePlacement(frame: 초소형프레임(), edges: [], on: 표면())
    let 탐침 = Vec2(x: 278, y: 358)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
    ])

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(결과.handle == .corner(.topLeft))
}

// MARK: - E-1 (AC-4 양성 대조): 좌상단 코너 기준 화면 x축 +20pt — 히트

@Test func 사십오도_회전_레이어에서_좌상단_코너_기준_20pt는_히트다() {
    // E를 쓰는 테스트가 AC-4(아래) 하나뿐이라, E 조립을 실수해(예: 잘못된
    // center로 모든 핸들이 화면 밖으로 밀려남) 모든 탐침이 빈 결과를 내도
    // AC-4는 "핸들 아님"을 기대하므로 그대로 초록이 된다. 이 양성 대조가
    // 그 상태를 잡는다 — 여기서 실패하면 E 픽스처 자체가 잘못된 것이다.
    let surface = 표면()
    let frame = 회전45프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)

    let 기준 = surface.toScreen(frame.corner(.topLeft))
    let 양성 = Vec2(x: 기준.x + 20, y: 기준.y)

    #expect(placement.hitCandidates(at: 양성).map(\.handle) == [.delete, .corner(.topLeft)])
}

// MARK: - E-2 (AC-4): 같은 기준에서 화면 x축 +30pt — 미스, 화면 축 정렬의 핵심 증거

@Test func 사십오도_회전_레이어에서도_히트_사각형은_화면_축_정렬이다() {
    // 로컬 축 정렬(코너에서 atan2로 회전을 복원해 델타를 역회전)이었다면
    // (30,0)을 −45° 역회전한 (21.213,−21.213)이 양 성분 22 이내라 히트였을
    // 것이다. 회전 0에서는 두 해석이 구별되지 않으므로 45°가 필수다 — 이
    // 픽스처가 §1-g의 "코너 atan2 회전 복원" 변이를 죽이는 유일한 방어선이다.
    let surface = 표면()
    let frame = 회전45프레임()
    let placement = HandlePlacement(frame: frame, edges: Set(Edge.allCases), on: surface)

    let 기준 = surface.toScreen(frame.corner(.topLeft))
    let 탐침 = Vec2(x: 기준.x + 30, y: 기준.y)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

// MARK: - F-1 (AC-11): 줌 100% vs 400%, 같은 화면 지점 — 같은 결과여야 한다 (FR-6 핵심)

@Test func 줌_100_퍼센트와_400_퍼센트에서_같은_화면_지점은_같은_핸들을_잡는다() {
    // 박스에서 파생한 배율(예: 코너 간 거리 비례)을 쓰는 변이는 100%에서는
    // 우연히 맞고 400%에서만 어긋난다 — 두 배율을 같은 단언으로 비교해야
    // "100%에서만 맞는 배율 파생"이 잡힌다.
    let frame = 줌비교프레임()
    let 탐침 = Vec2(x: 240, y: 325)

    let 표준배율 = HandlePlacement(frame: frame, edges: [], on: 표면())
    let 확대배율 = HandlePlacement(frame: frame, edges: [], on: 확대표면())

    #expect(표준배율.hitCandidates(at: 탐침).map(\.handle) == [.delete, .corner(.topLeft)])
    #expect(확대배율.hitCandidates(at: 탐침).map(\.handle) == [.delete, .corner(.topLeft)])
}

// MARK: - F-2 (AC-12): 줌 400%, 화면 25pt — 미스 (박스 파생 배율이면 half 88이 되어 거짓양성)

@Test func 줌_400_퍼센트에서도_22pt_초과는_잡히지_않는다() {
    let frame = 줌비교프레임()
    let surface = 확대표면()
    let placement = HandlePlacement(frame: frame, edges: [], on: surface)
    let 탐침 = Vec2(x: 245, y: 325)

    #expect(placement.hitCandidates(at: 탐침).isEmpty)
    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
}

// MARK: - F-3 (AC-13): 줌 50%, 화면 20pt — 히트 (박스 파생 배율이면 half 11이 되어 거짓음성)

@Test func 줌_50_퍼센트에서도_22pt_이내는_잡힌다() throws {
    let frame = 줌비교프레임()
    let surface = 축소표면()
    let placement = HandlePlacement(frame: frame, edges: [], on: surface)
    let 탐침 = Vec2(x: 240, y: 325)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.delete, .corner(.topLeft)])

    let 탭결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(탭결과.handle == .delete)
}

// MARK: - G-1 (AC-14): 뷰포트 밖(화면 y 음수), 뒤집힌 회전 핸들

@Test func 뷰포트_밖_회전_핸들도_탭으로_판정된다() throws {
    // 죽는 변이: `max(point.y, 0)` 형태의 뷰포트 클램프(클램프하면 dy가
    // 23으로 바뀌어 미스가 된다) + 지점 좌표를 abs()로 감싸는 변이.
    // 1회차 좌표(center −175 / 탐침 (270,−22))는 클램프 변이가 경계에 정확히
    // 걸려 우연히 살아남았다 — 2pt 옮긴 이 좌표라야 닫힌다.
    let placement = HandlePlacement(frame: 화면밖프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: -23)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.rotate])

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(결과.handle == .rotate)
}

// MARK: - AC-10: 선택 없음(empty) — 임의 지점, 두 제스처 모두 핸들 아님

@Test func 선택_없음이면_탭과_드래그_모두_핸들_아니다() {
    let placement = HandlePlacement.empty
    let 탐침 = Vec2(x: 0, y: 0)

    #expect(placement.hitHandle(at: 탐침, for: .tap) == nil)
    #expect(placement.hitHandle(at: 탐침, for: .drag) == nil)
}

// MARK: - M5: hitSize 리터럴 44

@Test func hitSize는_44다() {
    // `hitSize / 2` 유도 좌표가 아니라 리터럴 44 자체를 고정한다 — 경계
    // 테스트들은 22를 직접 쓰므로, 상수가 바뀌어도 그 테스트들만으로는
    // 안 잡히는 변경(예: 44→45이면서 half를 여전히 22로 하드코딩)을 방어한다.
    #expect(HandlePlacement.hitSize == 44)
}

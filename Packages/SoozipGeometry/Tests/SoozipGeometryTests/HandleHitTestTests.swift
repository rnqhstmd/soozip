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
// center (100, 75), size 200×200, rotation 0. 우하단 코너가 화면 (100,100),
// 우측 변 중점이 화면 (100,50)에 온다.
//
// `EDITOR-6` 사전 이전(사이클 0): 판정값 **100**. 앵커인 우하단 코너를 화면
// (100,100)에 고정한 채 높이를 100 → 200으로 키웠다. 제약은 B-3(변 존재,
// 판정값 ≥ 88)과 B-1(우측 변 중점이 탐침에서 미스)뿐이라 176이면 경계에 딱
// 붙고 200이면 여유 12가 생긴다. **부수 효과**: 상단이 뷰포트 위로 올라가
// 회전 핸들이 뒤집힌다. BR을 (100,100)에 고정한 채 높이를 키우면 수학적으로
// 불가피하며, B의 세 테스트는 rotate를 단언하지 않아 무해하다.

private func 경계프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 100, y: 75), size: Size2(width: 200, height: 200), rotation: 0)
}

// MARK: - 픽스처 C: 겹침프레임() — AC-5·6·7·9 · M2+M4
//
// center (500, 463), size 200×176, rotation 0. 좌상단 코너와 삭제가 동일 좌표
// 화면 (200,200)에 겹친다.
//
// `EDITOR-6` 사전 이전(사이클 0): 판정값 **정확히 88**이고 **이 값이 유일하게
// 강제된다.** 좌상단과 좌측 변 중점의 화면 y 간격은 `판정값/2`인데, C-6이 한
// 탐침으로 둘을 동시에 히트하려면 그 간격이 44 이하 → 판정값 ≤ 88. 정책은
// ≥ 88을 요구한다. **여유 0은 우연이 아니다.**

private func 겹침프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 500, y: 463), size: Size2(width: 200, height: 176), rotation: 0)
}

// MARK: - 픽스처 D: 초소형프레임() — AC-8 · M7
//
// center (540, 675), size 40×40. 좌상단·우상단 코너의 화면 거리가 20pt로,
// 제스처로도 안 갈리는 진짜 동점 상황(BR-4 폴백)을 만든다.

private func 초소형프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 40, height: 40), rotation: 0)
}

// MARK: - 픽스처 D+: 팔십팔정사각프레임() — D-2 이전 (EDITOR-6 사전 이전, 사이클 0)
//
/// 판정값 정확히 88(= 176 × 0.5). 변 핸들이 살아 있으면서 **인접한 변 두 개가
/// 한 점에서 동시에 히트하는 유일한 크기**다.
///
/// 원래 D-2는 초소형 레이어(40×40)에서 한 탐침에 코너 4 + 변 4 + 삭제까지
/// 9개가 모이는 것을 이용해 변 하위 순서를 한 번에 고정했다. `EDITOR-6` 이후
/// 그것은 **구조적으로 불가능**하다 — 네 변이 한 점에서 동시에 히트하려면 양
/// 반변이 22 이하여야 하고, 그러면 판정값 ≤ 44라 변이 통째로 숨는다.
/// 인접 쌍을 **두 번** 관측해 대체한다.
private func 팔십팔정사각프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675),
               size: Size2(width: 176, height: 176), rotation: 0)
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
// center (640, 825), size 400×400, rotation 0, edges: []. 세 표면(100%·400%·50%)
// 모두 같은 화면 좌표에 핸들이 오도록 표면 쪽에서 줌·팬을 맞춘다 — FR-6(줌과
// 무관하게 화면 44pt 고정)을 재는 것이 목적이라 프레임은 하나로 고정한다.
//
// edges: []인 이유: 축소 표면에서 top 변 중점이 탐침에 가까워져 히트하면
// 세 표면의 기대 시퀀스가 갈라진다. 변을 빼야 세 케이스를 글자 그대로 같게 잰다.
//
// `EDITOR-6` 사전 이전(사이클 0): 좌상단 논리 좌표 (440,625)를 유지해 세
// 배율 전부 화면 (220,325)가 그대로 나온다 → `확대표면()`·`축소표면()` 정의와
// 역산 주석을 **한 글자도 안 바꾼다.** 가장 낮은 배율(0.25)에서도 판정값 ≥ 88
// 이어야 세 배율의 기대 시퀀스가 글자 그대로 같아지는데, 352면 정확히 88
// (여유 0)이라 400으로 잡아 100pt를 확보했다.

private func 줌비교프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 640, y: 825), size: Size2(width: 400, height: 400), rotation: 0)
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
    // 우측 변 중점(100,50)은 이 탐침에서 dy=50>22라 미스여야 한다 — `&&`가
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

// MARK: - B-3 (M1): 탐침 (100,50) — 우측 변 중점 정확히

@Test func 우측_변_핸들은_탭과_드래그_모두에서_잡힌다() throws {
    // "드래그는 코너만 잡는다"는 틀렸다(변도 리사이즈 가능) — 드래그 단언이
    // 그 변이를 죽인다. "탭은 변을 뺀다"도 틀렸다 — 삭제만 드래그에서
    // 빠질 뿐, 탭은 변을 포함한 전부에서 최우선 후보를 낸다.
    //
    // 탐침이 (100,75) → (100,50)으로 바뀌었다 — `경계프레임()`이 200×200으로
    // 커지며 우측 변 중점 화면 좌표가 이동했기 때문이다.
    let placement = HandlePlacement(frame: 경계프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 100, y: 50)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [.edge(.right)])

    let 탭결과 = try #require(placement.hitHandle(at: 탐침, for: .tap))
    #expect(탭결과.handle == .edge(.right))

    let 드래그결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(드래그결과.handle == .edge(.right))
}

// MARK: - C-1 (AC-5): 탐침 (200,200) — 삭제·좌상단 겹침, 제스처 없이 조회

@Test func 삭제와_좌상단_코너가_겹치면_후보_목록에_둘_다_삭제_우선으로_담긴다() {
    // 좌측 변 중점(200,244)은 dy=44>22라 미스해야 한다. `겹침프레임()`이
    // `EDITOR-6` 사전 이전으로 판정값 88까지 커지며 이 간격이 25 → 44로
    // 벌어져, 이제는 22를 25로 넓히는 변이를 이 지점 혼자서는 못 잡는다 —
    // 그 변이는 대신 B-2(dx 22.5)·A-3(dy 22.5)가 죽인다.
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
    // (200,400)은 좌하단(200,288)과 x가 정확히 0pt 일치하고 y만 112pt 멀다.
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

// MARK: - C-6 (M2+M4): 탐침 (220,222) — 원·맨해튼 구별 + position 바꿔치기 방어

@Test func 삭제_좌상단_좌측변이_겹치는_지점의_후보는_원래_핸들_위치를_보고한다() throws {
    // 좌상단(200,200)은 이 탐침에서 dx=20,dy=22라 사각형(맨해튼 기준 각 축
    // 독립 22 이내)으로는 히트이지만, 유클리드 거리로 재면 √884≈29.73>22로
    // 미스가 된다 — "원·맨해튼" 변이가 이 지점에서만 갈린다.
    //
    // 탐침이 (220,220) → (220,222)로 바뀌었다 — `겹침프레임()`이 판정값 88로
    // 커지며 좌측 변 중점이 (200,225) → (200,244)로 내려갔고, 좌상단(200,200)과
    // 좌측 변 중점을 한 탐침으로 동시에 히트하려면 두 점의 y 중점(222)이어야
    // 한다. 여유 0은 우연이 아니다 — 이 조건이 성립하는 판정값은 정확히 88뿐이다.
    //
    // 세 기대 position(200,200)·(200,200)·(200,244)이 전부 탐침(220,222)과
    // 다르다 — `PlacedHandle(handle: h, position: point)`처럼 필터가 반환한
    // 원소의 위치를 탐침 좌표로 바꿔치기하는 변이는 이 대조가 아니면 안 잡힌다.
    let placement = HandlePlacement(frame: 겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 220, y: 222)

    let 후보 = placement.hitCandidates(at: 탐침)
    try #require(후보.count == 3)
    #expect(후보.map(\.handle) == [.delete, .corner(.topLeft), .edge(.left)])

    #expect(isClose(후보[0].position.x, 200))
    #expect(isClose(후보[0].position.y, 200))
    #expect(isClose(후보[1].position.x, 200))
    #expect(isClose(후보[1].position.y, 200))
    #expect(isClose(후보[2].position.x, 200))
    #expect(isClose(후보[2].position.y, 244))
}

// MARK: - D-1 삭제 — EDITOR-6 코너 밀기가 이 픽스처에서 관측을 소멸시켰다
//
// 원래 D-1은 `초소형프레임()`(40×40, 판정값 20)에서 좌상단·우상단 코너가
// 화면 거리 20pt로 동점인 것을 이용해 orderedHandles 순서 승리를 쟀다
// (탐침 (270,340), 후보 5개: delete + 코너 4개). `EDITOR-6`의 코너 밀기
// (56 미만 → 화면 축 방향 22pt씩 바깥)가 이 프레임에도 적용되면, 밀린 뒤
// 탐침 (270,340)에서 네 코너 전부 dx 32로 미스가 되어 후보가 0개가 된다 —
// **그 픽스처에서는 관측 자체가 소멸했다.**
//
// 시나리오 자체는 사라지지 않고 두 곳으로 옮겨졌다(설계서 「D-1 처리」):
// (1) 크기 0 — 아래 `크기가_0인_레이어에서...`(`영크기프레임()`) — 판정값이
//     0이라 네 코너가 밀린 뒤에도 화면 중심에서 22pt 동점을 유지해 D-1의
//     원래 단언이 글자 그대로 보존된다.
// (2) 56~88 밴드 — 아래 `밴드_구간에서...`(`밴드겹침프레임()`) — 코너는
//     밀리지 않는 대신(56 이상) 45° 회전이 인접 코너를 22pt 이내로 몰아
//     같은 종류의 동점을 만든다.

// MARK: - 픽스처 D0: 영크기프레임() — D-1 이전 (1) 크기 0
//
// center (540,675), size (0,0). 네 코너가 화면 중심(밀기 기준점)과 겹쳐
// 델타가 (0,0)이 되고, `Corner.sign` 성분별 폴백으로 22pt씩 벌어진다 —
// 좌상단 (248,328)·우상단 (292,328)·우하단 (292,372)·좌하단 (248,372).

private func 영크기프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 0, height: 0), rotation: 0)
}

// MARK: - 픽스처 D1: 밴드겹침프레임() — D-1 이전 (2) 56~88 밴드 (design-critic 반례)
//
// center (540,675), size 120×300, rotation π/4. 판정값 = 120 × 0.5 = 60 —
// 56 이상이라 코너는 밀리지 않고, 88 미만이라 변은 숨는다. **결함을 초록으로
// 고정하는 특성화 픽스처다** — 이 구간(56~62.225)은 `cornerPushThreshold`·
// `edgeHideThreshold` 어느 쪽도 손대지 않는 미보호 구간이고, 45°에서
// 좌상단·우상단의 화면 간격이 `60 × cos45° ≈ 42.43`로 44 이하가 되어 한
// 지점이 두 코너를 동시에 히트한다 — `EDITOR-6`이 없애려던 바로 그 증상이
// 이 구간에 남는다. `EDITOR-8`이 15° 스냅이라 도달 가능하다.

private func 밴드겹침프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 120, height: 300), rotation: .pi / 4)
}

// MARK: - 픽스처 D2: 인접겹침프레임() — 결정 8 특성화
//
// center (540,675), size 40×200, rotation π/4. 판정값 = 40 × 0.5 = 20 —
// 56 미만이라 코너가 밀린다. 좌상단·우상단의 화면 델타 부호가 **양 축
// 모두 같아서**(둘 다 (+1,−1)) 나란히 밀려 간격 (14.14,14.14)이 밀기
// 전후로 불변이다 — FR-2a는 마주보는 쌍에만 참이라는 것을 고정한다.

private func 인접겹침프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: 40, height: 200), rotation: .pi / 4)
}

@Test func 크기가_0인_레이어에서_네_코너가_동점으로_히트하고_드래그는_좌상단_코너를_잡는다() throws {
    // D-1이 이전된 첫 번째 자리. 판정값 0이라 코너 밀기가 발동하고, 네
    // 코너가 전부 화면 중심 (270,350)과 22pt 동점을 이룬다(`isHit`이
    // `<=`라 경계 포함) — `orderedHandles` 순서(TL이 TR보다 앞)만이 승자를
    // 정한다(BR-4). `.rotate`는 dy 28로 미스해야 한다 — 밀린 코너 중점이
    // 아니라 상단 변 중점이 회전 핸들 기준임을 여기서도 재확인한다.
    let placement = HandlePlacement(frame: 영크기프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 270, y: 350)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
    ])

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(결과.handle == .corner(.topLeft))
}

@Test func 밴드_구간에서는_코너가_밀리지_않아_인접_코너와_회전_핸들이_한_탐침에_모인다() throws {
    // D-1이 이전된 두 번째 자리(design-critic 반례, 오케스트레이터 검산
    // 완료). 이것은 **결함을 초록으로 고정하는 특성화 테스트**다. 판정값
    // **56~62.225**는 밀기가 발동하지 않는데(≥ 56) 45° 근방에서 인접 코너
    // 간격이 `판정값 × cos45° ≤ 44`가 되어 **한 탐침이 두 코너를 동시에
    // 히트한다** — `EDITOR-6`이 없애려던 바로 그 증상이 이 구간에 남는다.
    // `EDITOR-8`이 15° 스냅이라 도달 가능하다. `EDITOR-10`이 이 구간을 덮으면
    // 이 테스트가 **의도적으로 실패해** 그 변경을 알린다.
    //
    // 게다가 `.rotate`가 코너보다 더 가깝게 들어온다(유클리드 rotate 28.0 <
    // 코너 30.0) — 그래도 `orderedHandles` 순서상 코너가 먼저라 드래그는
    // 좌상단을 잡는다.
    let placement = HandlePlacement(frame: 밴드겹침프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 323.0330, y: 296.9670)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .rotate,
    ])

    let 결과 = try #require(placement.hitHandle(at: 탐침, for: .drag))
    #expect(결과.handle == .corner(.topLeft))
}

@Test func 밀린_인접_코너가_회전_핸들과_새로_겹치는_지점의_후보는_네_개다() throws {
    // 결정 8 특성화 테스트 — **결함을 초록으로 고정한다.** 코너 밀기가
    // 45° 근방에서는 인접 코너의 겹침을 없애지 못할 뿐 아니라, 밀기 방향
    // (22,−22)가 회전 핸들 오프셋(rotateGap × up ≈ (19.8,−19.8))과 수렴해
    // 밀기 전에는 없던 코너-회전 겹침을 새로 만든다. 회전 0에서는 반대로
    // (`초소형프레임()`에서) 겹침을 없앤다 — 즉 정책은 코너-코너만 보고
    // 코너-회전은 보지 않는다. 나중에 인접 쌍까지 고치는 변경이 있다면 이
    // 테스트가 **의도적으로 실패해** 그 변경을 알려야 한다.
    let placement = HandlePlacement(frame: 인접겹침프레임(), edges: [], on: 표면())
    let 탐침 = Vec2(x: 327.3553, y: 292.6446)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .corner(.topRight), .rotate,
    ])
}

// MARK: - D-2 (M7): `팔십팔정사각프레임()` 이전 — 변 하위 순서를 인접 쌍 2회로 고정
//
// `EDITOR-6` 사전 이전(사이클 0): 원래 D-2는 초소형 레이어(40×40) 중심 한
// 탐침에 코너 4 + 변 4 + 삭제 9개가 모이는 것을 이용해 변 하위 순서
// (top→right→bottom→left)를 한 번에 고정했다. 정책 도입 후에는 그 배치가
// 구조적으로 불가능해지므로(네 변 동시 히트 ↔ 판정값 ≤ 44 ↔ 변 숨김),
// 인접한 변 쌍을 두 번 관측해 같은 순서를 고정한다.
//
// `Edge.allCases`(선언 순서: left,right,top,bottom)로 대신 쓰는 변이는 아래
// 두 탐침에서 각각 `[…, .edge(.right), .edge(.top)]`·
// `[…, .edge(.left), .edge(.bottom)]`이 되어 **둘 다 사망**한다. 다만
// **순환 회전 변이**(`[bottom,left,top,right]`)는 두 탐침 모두 통과하므로
// 그것은 `edgeOrder` 리터럴 테스트가 담당한다.

@Test func 팔십팔정사각_박스에서_topRight_코너와_top_right_변이_한_탐침에_모인다() {
    // 탐침 = 중심 + (22,−22): TR 코너와 top·right 변 중점이 전부 22pt
    // 이내로 들어온다 — **top이 right보다 앞**임을 고정한다.
    let placement = HandlePlacement(frame: 팔십팔정사각프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 292, y: 328)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .corner(.topRight), .edge(.top), .edge(.right),
    ])
}

@Test func 팔십팔정사각_박스에서_bottomLeft_코너와_bottom_left_변이_한_탐침에_모인다() {
    // 탐침 = 중심 + (−22,+22): BL 코너와 bottom·left 변 중점이 전부 22pt
    // 이내로 들어온다 — **bottom이 left보다 앞**임을 고정한다.
    let placement = HandlePlacement(frame: 팔십팔정사각프레임(), edges: Set(Edge.allCases), on: 표면())
    let 탐침 = Vec2(x: 248, y: 372)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .corner(.bottomLeft), .edge(.bottom), .edge(.left),
    ])
}

// MARK: - D-3 (특성화): 탐침 (278,358) — BR가 2.83pt로 최근접인데 순서가 이긴다

@Test func 겹침에서는_최근접_핸들이_아니라_orderedHandles_순서가_이긴다() throws {
    // 판정은 거리를 **보지 않는다**(BR-4). 이 지점은 `.rotate`가 유클리드
    // 12.17로 최근접인데(좌상단 코너는 20.40) 드래그는 좌상단 코너를 잡는다.
    //
    // 이 테스트가 없으면 `hitCandidates(at:).sorted { 거리 }.first { accepts }`
    // 변이가 살아남는다 — `EDITOR-6`의 코너 밀기 정책이 도입된 뒤에는 이
    // 지점이 **유일한** 방어선이다(설계서 red-writer 필수 인계 #3).
    //
    // 탐침이 (278,358) → (258,314)로 바뀌었다. `EDITOR-6`의 코너 밀기가
    // `초소형프레임()`(40×40, 판정값 20)에도 적용되면서 좌상단이 (230,320)
    // → (238,318)로, 우상단이 (310,320) → (302,318)로 이동해 옛 탐침에서는
    // 후보 구성 자체가 달라진다. 이 픽스처는 회전 0이라 두 밀기 규칙
    // (`Corner.sign` vs 화면 델타 부호)이 같은 값을 내므로 밀기 자체는 이
    // 테스트의 관심사가 아니다 — 재조준의 목적은 여전히 "회전 핸들이 더
    // 가까운데 순서가 이긴다"는 관측 하나뿐이다.
    //
    // 후보는 이제 코너 하나(좌상단)와 rotate 둘뿐이다 — 우상단(302,318)은
    // 탐침에서 dx 44로 미스, 좌하단(238,362)은 dy 48로 미스하기 때문이다.
    // 코너끼리의 상대 순서는 이 테스트가 못 잰다(후보에 코너가 하나뿐이라)
    // — 그것은 `영크기프레임()`·`밴드겹침프레임()`이 담당한다.
    //
    // 근접 우선이 제품 의도가 되면 그것은 이 단위의 결함이 아니라
    // `EDITOR-6`·`EDITOR-10`의 새 AC다.
    let placement = HandlePlacement(frame: 초소형프레임(), edges: [], on: 표면())
    let 탐침 = Vec2(x: 258, y: 314)

    #expect(placement.hitCandidates(at: 탐침).map(\.handle) == [
        .delete, .corner(.topLeft), .rotate,
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

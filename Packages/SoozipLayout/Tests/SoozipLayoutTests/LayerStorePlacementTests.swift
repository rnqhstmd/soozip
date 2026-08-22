import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// EDITOR-10 — 저장소 계층 (BR-6, AC 번호 없음 — PRD가 구조적 요구로 분류)
//
// SoozipGeometry의 게이트(ClampedLayerCenter 토큰 + LayerFrame.placed(at:) +
// LayerFrame.center를 internal(set)로 좁힘)가 이미 서 있다.
// `LayerTransform.placed(at:)`가 SoozipLayout 안에서 transform.x/y를
// 바꾸는 유일한 경로임은 이미 증명됐다. 하지만 편집 세션에서 레이어를
// 실제로 **소유**하는 것은 LayerTransform이 아니라 LayerStore이고, 그
// 안의 storage는 private다.
//
// 이 파일 착수 시점(place 추가 전) LayerStore의 public mutating API는
// 8개(select·deselect·insert·remove·z-order 4종: bringToFront·sendToBack·
// bringForward·sendBackward)였고, 그 가운데 **레이어의 중심을 바꾸는 것은
// 하나도 없었다** — "이미 존재하는 레이어를 옮기는 공개 경로"가 착수
// 시점 기준 0개였다.
//
// 그래서 이 파일이 하는 일은 봉쇄가 아니라 **선점**이다. EDITOR-11이
// 레이어를 드래그로 움직이려면 LayerStore에 mutating 함수를 새로
// 만들어야 하는데, 그건 SoozipLayout 모듈 **안**이라 `LayerTransform.placed(at:)`가
// 지키는 internal(set)이 그 자리를 전혀 막지 못한다(모듈 내부에서는
// 여전히 entry.layer.transform.x = ... 를 직접 대입할 수 있다). 이
// 파일은 착수 시점에 비어 있던 그 자리에 옳은 것 — 토큰을 강제로 거치는
// place(_:at:) — 을 놓아서, EDITOR-11이 두 번째(우회) 경로를 발명할
// 이유를 없앤다.
//
// 이름이 `move`가 아닌 이유: LayerStore에는 이미 z-order 내부 구현으로
// `private mutating func move(_:to:)`가 있다. 공개 API 이름도 move로
// 지으면 move(id, to: ClampedLayerCenter)와 move(id, to: <z-order 내부
// 클로저/인덱스 타입>)이 인자 타입만 다른 오버로드로 자동완성에 나란히
// 뜬다 — 호출자가 z-order용 내부 오버로드를 실수로 고를 여지를 만든다.
// place는 그 충돌이 없다.

/// 4:5 피드 캔버스. 중심 (540, 675), 작업 영역 경계 (1620, 2025).
private let 캔버스 = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: 캔버스, viewport: 세로)
}

/// 캔버스 중심 (540, 675)과 x·y 두 축 모두 다른 시작 변형. 같으면
/// place가 아무것도 안 해도 우연히 좌표가 일치해 no-op 변이가 초록으로
/// 통과한다 — LayerPlacementTests.swift · LayerCenterClampTests.swift가
/// 이미 원장에 적은 것과 같은 규칙이다.
private func 자리(_ i: Int, z: Int = 0) -> LayerTransform {
    LayerTransform(x: 100 + Double(i) * 10, y: 200, z: z)
}

private func 도형(_ tag: Int, z: Int = 0) -> Layer {
    .shape(ShapeLayer(kind: .circle, width: 100, height: 100,
                      fill: tag, stroke: nil, strokeWidth: 0,
                      transform: 자리(tag, z: z)))
}

private func 태그들(_ store: LayerStore) -> [Int] {
    store.layers.compactMap {
        if case .shape(let s) = $0 { return s.fill }
        return nil
    }
}

private func z값들(_ store: LayerStore) -> [Int] {
    store.layers.map(\.transform.z)
}

// MARK: - 계약 1: 옮기면 저장 좌표에 반영된다

@Test func 존재하는_레이어를_옮기면_저장_변형의_중심이_바뀌고_다른_레이어는_그대로다() {
    // 세 레이어를 담아 "지목한 것만 바뀌고 나머지는 그대로"까지 함께
    // 본다 — 대상 하나만 담으면 "전체 순회 후 마지막 요소에 좌표를
    // 대입" 같은 변이가 우연히 같은 결과를 내며 살아남는다.
    var store = LayerStore([도형(0), 도형(1), 도형(2)])
    let 대상id = store.entries[1].id
    let 토큰 = ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: 표면())

    store.place(대상id, at: 토큰)

    let 옮긴것 = store.entries.first { $0.id == 대상id }!
    #expect(옮긴것.layer.transform.x == 1620)
    #expect(옮긴것.layer.transform.y == 2025)

    let 안옮긴것들 = store.entries.filter { $0.id != 대상id }
    #expect(안옮긴것들.map { $0.layer.transform.x } == [100, 120])
    #expect(안옮긴것들.map { $0.layer.transform.y } == [200, 200])
}

// MARK: - 계약 2: 없는 식별자는 조용히 무시한다 (BR-6)

@Test func 없는_식별자로_옮기려_하면_크래시_없이_아무것도_바뀌지_않는다() {
    // PRD BR-6: "레이어 라우팅 결과는 그 시점에 조작 가능한 레이어가
    // 있다는 것을 보장하지 않는다 — 없으면 크래시 없이 조용히 무시."
    // LayerStore.move(_:to:)(z-order 내부 구현)가 이미 같은 관례를,
    // "선택된 레이어가 다른 경로로 지워진 뒤 속성바 버튼이 눌리는
    // 경합이 실제로 있다"는 근거로 쓴다. place도 그 관례를 따라야
    // 한다 — 존재하지 않는 id로 불려도 예외를 던지거나 강제
    // 언래핑으로 죽으면 안 되고, 저장소는 호출 전과 완전히 같아야
    // 한다.
    let 이전 = LayerStore([도형(0), 도형(1), 도형(2)])
    var store = 이전
    let 유령 = UUID()
    let 토큰 = ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: 표면())

    store.place(유령, at: 토큰)

    #expect(store == 이전)
}

// MARK: - 계약 3: z(순서)는 변하지 않는다

@Test func place는_z나_레이어_순서를_바꾸지_않는다() {
    // z-order 4종(bringToFront 등)과 달리 place는 배열 재배치가 없다 —
    // 중심 좌표만 바뀌고 인덱스·z는 그대로다. 만약 place가 대상을
    // 맨 앞/뒤로 옮기는 부작용을 곁들이는 변이가 있다면 태그 순서가
    // 흐트러진다.
    var store = LayerStore([도형(0), 도형(1), 도형(2)])
    let 대상id = store.entries[1].id
    let z이전 = z값들(store)
    let 토큰 = ClampedLayerCenter(Vec2(x: 300, y: 400), on: 표면())

    store.place(대상id, at: 토큰)

    // z값들 비교의 킬셋은 바로 위 태그들 비교에 완전히 포함된다(z는
    // 인덱스에서 파생돼 태그 순서가 고정되면 z도 함께 고정된다). 그래도
    // 단언은 지우지 않고 유지한다 — 이 테스트 이름이 "z나 순서를 바꾸지
    // 않는다"고 명시하므로 z를 직접 확인하는 단언이 있어야 이름과 본문이
    // 일치한다.
    #expect(태그들(store) == [0, 1, 2])
    #expect(z값들(store) == z이전)
}

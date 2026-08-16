import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// EDITOR-4 — 선택. `LayerStore`에 단일 선택 상태를 얹는다.
//
// **선택은 `entries`에서 파생된다.** 내부 저장 배열의 z는 항상 0이므로,
// 저장 배열에서 직접 항목을 찾아 돌려주는 구현은 z-order 조작 뒤 낡은 z를
// 흘린다. 그리고 `select`/`remove`는 **선택 상태를 정규화**해야 한다 —
// 안 그러면 `selection` 조회는 파생 덕에 맞아 보여도 `LayerStore`의 `==`가
// 조용히 갈라진다(undo 스택 비교·저장 diff에서 터진다).

// MARK: - 픽스처

private func 자리(_ i: Int, z: Int = 0) -> LayerTransform {
    LayerTransform(x: 100 + Double(i) * 10, y: 200, z: z)
}

private func 도형(_ tag: Int, z: Int = 0) -> Layer {
    .shape(ShapeLayer(kind: .circle, width: 100, height: 100,
                      fill: tag, stroke: nil, strokeWidth: 0,
                      transform: 자리(tag, z: z)))
}

// MARK: - AC-1: 단일 선택

@Test func 다른_레이어를_선택하면_이전_선택은_해제된다() {
    // 선택은 하나만 유지된다. 밀어내지 않으면 두 레이어 모두 하이라이트된
    // 채로 남아 속성 패널이 어느 쪽 값을 보여줄지 알 수 없다.
    var store = LayerStore([도형(0), 도형(1)])
    let (a, b) = (store.entries[0].id, store.entries[1].id)
    store.select(a)

    store.select(b)

    #expect(store.selection?.id == b)
}

// MARK: - AC-2: 선택 해제

@Test func 선택_해제하면_선택된_레이어가_없다() {
    var store = LayerStore([도형(0)])
    store.select(store.entries[0].id)

    store.deselect()

    #expect(store.selection == nil)
}

// MARK: - AC-3·4: 삭제와 선택의 상호작용

@Test func 선택된_레이어를_지우면_선택이_해제된다() {
    // 지운 레이어를 계속 선택 상태로 두면 존재하지 않는 레이어의 속성
    // 패널이 열려 있는 상태가 된다.
    var store = LayerStore([도형(0), 도형(1)])
    let a = store.entries[0].id
    store.select(a)

    store.remove(a)

    #expect(store.selection == nil)
}

@Test func 선택되지_않은_레이어를_지워도_선택은_그대로다() {
    var store = LayerStore([도형(0), 도형(1)])
    let (a, b) = (store.entries[0].id, store.entries[1].id)
    store.select(a)

    store.remove(b)

    #expect(store.selection?.id == a)
}

// MARK: - AC-5: z-order 재정렬 뒤에도 식별자 기준 유지

@Test func 맨_앞으로_보낸_뒤에도_식별자_기준으로_선택이_유지된다() {
    var store = LayerStore([도형(0), 도형(1)])
    let a = store.entries[0].id
    store.select(a)

    store.bringToFront(a)

    #expect(store.selection?.id == a)
}

// MARK: - 조건 1: selection은 entries에서 파생된다 (치명적)

@Test func 선택은_entries에서_파생되어_최신_z를_보여준다() {
    // 내부 저장 배열에서 직접 찾는 구현(`storage.first { $0.id == selectedID }`)은
    // AC-1~5를 전부 통과한다 — 전부 id 동일성만 보기 때문이다. 하지만 저장값의
    // z는 항상 0이라 낡은 z를 흘린다. `bringToFront` 뒤 선택된 항목의 z는
    // 배열 맨 끝의 인덱스와 같아야 한다.
    var store = LayerStore([도형(0), 도형(1), 도형(2)])
    let a = store.entries[0].id
    store.select(a)

    store.bringToFront(a)

    #expect(store.selection?.layer.transform.z == store.entries.count - 1)
}

// MARK: - 조건 2·3: 쓰기 정규화

@Test func 선택한_레이어를_지우면_select를_거치지_않고_지운_것과_값이_같다() {
    // `remove`가 선택 상태를 되돌리지 않아도 `selection` 조회는 파생 덕에
    // nil을 보여줘 앞의 AC-3을 통과한다. 그러면 `LayerStore`의 `==`만 조용히
    // 갈라진다 — 한 번도 select하지 않고 같은 레이어를 지운 스토어와 값이
    // 달라진다.
    let 시작 = LayerStore([도형(0), 도형(1)])
    let id = 시작.entries[0].id

    var 원본스토어 = 시작
    원본스토어.remove(id)   // select를 거치지 않은 대조군

    var a = 시작
    a.select(id)
    a.remove(id)

    #expect(a == 원본스토어)
}

@Test func 없는_식별자를_선택해도_스토어_값은_그대로다() {
    // 저장소에 없는 id를 select하면 `selection` 조회는 nil을 보여줘 맞아
    // 보이지만, 내부에 유령 id가 선택 상태로 남아 있으면 `LayerStore`의
    // `==`가 select를 한 번도 하지 않은 동일한 스토어와 갈라진다.
    let 원본스토어 = LayerStore([도형(0), 도형(1)])
    var b = 원본스토어

    b.select(UUID())

    #expect(b == 원본스토어)
}

@Test func 유효한_선택이_있어도_없는_식별자를_선택하면_기존_선택이_해제된다() {
    // 확정된 결정: `select`는 `move`와 달리 이전 상태를 보존하지 않고
    // "선택 없음"으로 정규화한다. 위 테스트는 선택이 없는 스토어에서
    // 시작하므로, `select`를 `move`처럼 `guard storage.contains { .. }
    // else { return }`(= 이전 상태 보존)으로 바꿔도 그대로 통과한다 —
    // 즉 "기존 선택을 지운다"는 동작이 어느 테스트로도 고정되지 않았다.
    // 이 테스트가 그 결정을 고정한다: A를 선택한 상태에서 저장소에 없는
    // id로 select를 호출하면 A의 선택도 함께 사라져야 한다.
    var store = LayerStore([도형(0), 도형(1)])
    let a = store.entries[0].id
    store.select(a)

    store.select(UUID())

    #expect(store.selection == nil)
}

// EDITOR-4 이어서 — 핸들 배치. `LayerStore.selectionHandles(on:baseSizeOf:)`가
// 선택된 레이어의 핸들 배치(`HandlePlacement`)를 만든다.

// MARK: - 새 픽스처

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

/// canvas == viewport인 표면. fitScale = 1, 기본 center = 캔버스 중심이라
/// `toScreen`이 항등 변환이 되어 코너 좌표를 손으로 계산해 바로 대조할 수 있다.
private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: Size2(width: 1000, height: 1000),
                  viewport: Size2(width: 1000, height: 1000))
}

private func 사진() -> Layer {
    .photo(PhotoLayer(assetId: UUID().uuidString, transform: LayerTransform(x: 100, y: 200), filter: nil))
}
private func 텍스트() -> Layer {
    .text(TextLayer(string: "가", font: .pretendard, size: 40,
                    color: "#000000", align: .left,
                    transform: LayerTransform(x: 110, y: 200)))
}
private func 도장() -> Layer {
    .stamp(StampLayer(date: "2026-08-12", style: "plain",
                      transform: LayerTransform(x: 130, y: 200)))
}
private func 펜() -> Layer {
    .drawing(DrawingLayer(assetId: UUID().uuidString, transform: LayerTransform(x: 140, y: 200)))
}

// MARK: - resizableEdges 리터럴 표

@Test func 종류별_변_상한이_설계와_일치한다() {
    // `placement.edges == kind.resizableEdges`처럼 같은 접근자로 양변을
    // 만들면 resizableEdges가 무엇을 반환하든 자기 자신과 비교하는 동어반복이
    // 되어 늘 초록이다(예: 모든 종류에 Set(Edge.allCases)를 반환해도 통과).
    // 리터럴로 고정해 값 자체를 명세와 대조한다.
    #expect(LayerKind.photo.resizableEdges == [])
    #expect(LayerKind.stamp.resizableEdges == [])
    #expect(LayerKind.drawing.resizableEdges == [])
    #expect(LayerKind.text.resizableEdges == [.left, .right])
    #expect(LayerKind.shape.resizableEdges == [.left, .right, .top, .bottom])
}

// MARK: - AC-6: photo·stamp·drawing은 변 핸들이 없다

@Test func 사진_도장_드로잉은_변_핸들이_없지만_코너_회전_삭제_핸들은_있다() {
    // "항상 .empty를 반환한다"는 변이를 잡으려면 부재(변 핸들 없음)뿐 아니라
    // 존재(코너 4 + 회전 1 + 삭제 1 = 6개)도 함께 재야 한다.
    for 만들기 in [사진, 도장, 펜] {
        var store = LayerStore([만들기()])
        store.select(store.entries[0].id)

        let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

        #expect(placement.box?.edgeHandles.isEmpty == true)
        #expect(!placement.orderedHandles.contains {
            if case .edge = $0.handle { return true } else { return false }
        })
        #expect(placement.orderedHandles.count == 6)
    }
}

// MARK: - AC-7·8: shape·text의 허용 변

@Test func 도형은_네_변_모두_리사이즈_핸들을_가진다() {
    var store = LayerStore([도형(0)])
    store.select(store.entries[0].id)

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

    #expect(placement.edges == [.left, .right, .top, .bottom])
}

@Test func 텍스트는_좌우_두_변만_리사이즈_핸들을_가진다() {
    var store = LayerStore([텍스트()])
    store.select(store.entries[0].id)

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

    #expect(placement.edges == [.left, .right])
}

// MARK: - orderedHandles 전체 시퀀스

@Test func 도형_선택시_orderedHandles는_삭제_코너_회전_변_순서로_열_개다() {
    var store = LayerStore([도형(0)])
    store.select(store.entries[0].id)

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

    #expect(placement.orderedHandles.map(\.handle) == [
        .delete,
        .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
        .rotate,
        .edge(.top), .edge(.right), .edge(.bottom), .edge(.left),
    ])
}

@Test func 사진_선택시_orderedHandles는_변_없이_삭제_코너_회전_여섯_개다() {
    var store = LayerStore([사진()])
    store.select(store.entries[0].id)

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

    #expect(placement.orderedHandles.map(\.handle) == [
        .delete,
        .corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft),
        .rotate,
    ])
}

// MARK: - AC-14: 선택 없음

@Test func 선택이_없으면_핸들_배치가_비어있다() {
    // 빈 스토어로 재면 "스토어가 비면 .empty"라는 변이가 살아남는다. 5종을
    // 전부 채우고 명시적으로 deselect한 상태로 재야 "선택이 없다"는 조건
    // 자체를 검증한다.
    var store = LayerStore([사진(), 텍스트(), 도형(4), 도장(), 펜()])
    store.deselect()

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 100, height: 100) }

    #expect(placement == .empty)
    #expect(placement.box == nil)
    #expect(placement.orderedHandles.isEmpty)
    #expect(placement.edges.isEmpty)
}

// MARK: - baseSizeOf 호출 계약

@Test func 도형을_선택하면_baseSizeOf가_호출되지_않는다() {
    // shape는 `Layer.baseSize`가 non-nil이라 스토어가 baseSizeOf 클로저를
    // 타지 않아야 한다.
    var store = LayerStore([도형(0)])
    store.select(store.entries[0].id)
    var 호출횟수 = 0

    _ = store.selectionHandles(on: 표면()) { _ in
        호출횟수 += 1
        return Size2(width: 999, height: 999)
    }

    #expect(호출횟수 == 0)
}

@Test func 사진_텍스트_도장_드로잉을_선택하면_baseSizeOf가_한_번_호출되고_선택된_레이어가_전달된다() {
    // `Layer.baseSize`가 nil인 넷은 반드시 baseSizeOf를 거쳐야 하고, 넘어오는
    // 인자는 다른 레이어가 아니라 지금 선택된 바로 그 레이어여야 한다.
    let 픽스처들: [(() -> Layer, LayerKind)] = [
        (사진, .photo), (텍스트, .text), (도장, .stamp), (펜, .drawing),
    ]
    for (만들기, kind) in 픽스처들 {
        var store = LayerStore([만들기()])
        store.select(store.entries[0].id)
        var 호출횟수 = 0
        var 전달된종류: LayerKind?

        _ = store.selectionHandles(on: 표면()) { layer in
            호출횟수 += 1
            전달된종류 = layer.kind
            return Size2(width: 100, height: 100)
        }

        #expect(호출횟수 == 1, "\(kind)")
        #expect(전달된종류 == kind, "\(kind)")
    }
}

@Test func baseSizeOf_스텁이_레이어마다_다른_값을_내면_선택된_그_레이어의_값이_박스에_반영된다() throws {
    // 상수 스텁을 쓰면 "항상 entries[0]을 넘긴다"는 변이가 무증상이다.
    // kind마다 다른 크기를 내는 스텁을 쓰고, 첫 번째가 아닌 인덱스 3(도장)을
    // 선택해 그 레이어의 스텁 값이 실제로 박스 크기에 반영되는지 좌표로 잰다.
    //
    // `EDITOR-6` 사전 이전(사이클 0): 도장 스텁을 60×40 → **120×100**으로
    // 키웠다. `표면()`은 fitScale 1.0이라 60×40은 판정값 40으로 `EDITOR-6`의
    // 두 임계값(56·88) 아래다. 120×100이면 판정값 100으로 정책 밖이다.
    // **비정사각을 유지**한다 — 폭·높이 뒤바꿈 변이가 계속 죽어야 한다. 다른
    // kind의 스텁 값(10·20·30)은 이 테스트에서 선택되지 않으므로 그대로 둔다.
    let layers: [Layer] = [사진(), 텍스트(), 펜(), 도장(), 도형(4)]
    var store = LayerStore(layers)
    store.select(store.entries[3].id)   // 도장: transform x=130, y=200

    let stub: (Layer) -> Size2 = { layer in
        switch layer.kind {
        case .photo: return Size2(width: 10, height: 10)
        case .text: return Size2(width: 20, height: 20)
        case .stamp: return Size2(width: 120, height: 100)
        case .drawing: return Size2(width: 30, height: 30)
        case .shape: return Size2(width: 999, height: 999)
        }
    }

    let placement = store.selectionHandles(on: 표면(), baseSizeOf: stub)
    let box = try #require(placement.box)

    // 도장 스텁(120×100), scale 1 → topLeft(70,150)·bottomRight(190,250).
    #expect(isClose(box.topLeft.x, 70))
    #expect(isClose(box.topLeft.y, 150))
    #expect(isClose(box.bottomRight.x, 190))
    #expect(isClose(box.bottomRight.y, 250))
}

// MARK: - frame(baseSize:) 경유 검증

@Test func 스케일과_회전이_있는_도형은_frame_baseSize를_경유해_코너_좌표가_계산된다() throws {
    // `LayerTransform.frame(baseSize:)`는 baseSize에 scale을 곱하고 rotation을
    // 실어 나른다. 기존 픽스처는 전부 scale=1·rotation=0이라 frame(baseSize:)를
    // 거치지 않고 LayerFrame을 직접 조립하는 변이(스케일 곱 누락·회전 누락)가
    // 구조적으로 무증상이다. scale=2·rotation=π/2인 비정사각형 도형(200×100,
    // 실효 400×200)으로 코너를 직접 확인한다.
    let transform = LayerTransform(x: 500, y: 500, scale: 2, rotation: .pi / 2)
    let shape = Layer.shape(ShapeLayer(kind: .circle, width: 200, height: 100, fill: 0,
                                       stroke: nil, strokeWidth: 0, transform: transform))
    var store = LayerStore([shape])
    store.select(store.entries[0].id)

    let placement = store.selectionHandles(on: 표면()) { _ in Size2(width: 999, height: 999) }
    let box = try #require(placement.box)

    #expect(isClose(box.topLeft.x, 600))
    #expect(isClose(box.topLeft.y, 300))
    #expect(isClose(box.topRight.x, 600))
    #expect(isClose(box.topRight.y, 700))
    #expect(isClose(box.bottomRight.x, 400))
    #expect(isClose(box.bottomRight.y, 700))
    #expect(isClose(box.bottomLeft.x, 400))
    #expect(isClose(box.bottomLeft.y, 300))
}

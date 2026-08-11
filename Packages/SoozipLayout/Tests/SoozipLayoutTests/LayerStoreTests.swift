import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// EDITOR-2 — 레이어 스토어. v4 §5.2(5종 공통 경로) · §5.11(z-order)
//
// **배열 순서가 진실이고 z는 인덱스에서 파생된다.** 그래서 "z는 0부터 촘촘하다"가
// 지켜야 할 규칙이 아니라 깨질 수 없는 성질이 된다.

// MARK: - 픽스처

private func 자리(_ i: Int, z: Int = 0) -> LayerTransform {
    LayerTransform(x: 100 + Double(i) * 10, y: 200, z: z)
}

/// 도형 레이어. 내용을 구별하려고 `fill`(파스텔 색 인덱스)을 태그로 쓴다.
private func 도형(_ tag: Int, z: Int = 0) -> Layer {
    .shape(ShapeLayer(kind: .circle, width: 100, height: 100,
                      fill: tag, stroke: nil, strokeWidth: 0,
                      transform: 자리(tag, z: z)))
}

/// 같은 원본을 참조하는 사진 레이어. **복제본은 `assetId`를 공유한다**(v4 §5.12.1).
private func 사진(assetID: String, z: Int = 0) -> Layer {
    .photo(PhotoLayer(assetId: assetID, transform: 자리(0, z: z), filter: nil))
}

private func 텍스트(z: Int = 0) -> Layer {
    .text(TextLayer(string: "가나다", font: .pretendard, size: 48,
                    color: "#000000", align: .left, transform: 자리(1, z: z)))
}

private func 도장(z: Int = 0) -> Layer {
    .stamp(StampLayer(date: "2026-08-12", style: "plain", transform: 자리(2, z: z)))
}

private func 필기(z: Int = 0) -> Layer {
    .drawing(DrawingLayer(assetId: UUID().uuidString, transform: 자리(3, z: z)))
}

/// **5종을 전부 담는다.** 픽스처가 한 종류뿐이면 `Layer.transform` setter가
/// 나머지 4종에서 no-op이어도 아무도 모른다(실측 확인).
private func 다섯종(z: Int = 0) -> [Layer] {
    [사진(assetID: UUID().uuidString, z: z), 텍스트(z: z), 도형(0, z: z),
     도장(z: z), 필기(z: z)]
}

/// 내용 태그 순서. 순서 비교를 읽기 쉽게 만든다.
private func 태그들(_ store: LayerStore) -> [Int] {
    store.layers.compactMap {
        if case .shape(let s) = $0 { return s.fill }
        return nil
    }
}

private func z값들(_ store: LayerStore) -> [Int] {
    store.layers.map(\.transform.z)
}

// MARK: - AC-1·2: 식별과 왕복

@Test func 같은_assetId를_공유해도_항목_식별자는_서로_다르다() {
    // **복제 사진은 `assetId`를 공유한다**(BR-5). `assetId`를 키로 쓰면 복제본
    // 중 하나를 앞으로 보낼 때 어느 것인지 지목할 수 없다.
    let 공유 = UUID().uuidString
    let store = LayerStore([사진(assetID: 공유), 사진(assetID: 공유), 사진(assetID: 공유)])

    #expect(Set(store.entries.map(\.id)).count == 3)
}

@Test func 내용이_똑같은_레이어도_지목한_것만_삭제된다() {
    // **식별자가 다르다는 것과 조작이 그것을 존중한다는 것은 다르다.**
    // 앞 테스트는 전자만 증명한다 — 개수 비교는 관계를 못 본다.
    //
    // 복제본은 `assetId`뿐 아니라 크기·회전·투명도·색까지 전부 승계하므로
    // (v4 §5.12.1) **값으로는 원본과 완전히 같다.** 값 동등성으로 지목하는
    // 구현은 복제본을 지울 때 원본까지 지운다.
    let 공유 = UUID().uuidString
    var store = LayerStore((0..<3).map { _ in 사진(assetID: 공유) })
    let 원래id = store.entries.map(\.id)

    store.remove(원래id[1])

    #expect(store.entries.map(\.id) == [원래id[0],원래id[2]])
}

@Test func 내용이_똑같은_레이어도_지목한_것만_이동한다() {
    let 공유 = UUID().uuidString
    var store = LayerStore((0..<3).map { _ in 사진(assetID: 공유) })
    let 원래id = store.entries.map(\.id)

    store.sendToBack(원래id[2])

    // 태그로는 구별할 수 없다 — id 순열로 단언해야 한다.
    #expect(store.entries.map(\.id) == [원래id[2], 원래id[0], 원래id[1]])
}

@Test func 넣은_순서와_내용이_그대로_나온다() {
    let store = LayerStore([도형(7), 도형(8), 도형(9)])
    #expect(태그들(store) == [7, 8, 9])
    #expect(z값들(store) == [0, 1, 2])
}

@Test func 다섯_종류_모두_z가_채워진다() {
    // v4 §5.2: "z-order는 5종이 완전히 동일한 경로를 탄다."
    // **`z: 99`를 줘야 한다** — 기본값 0을 주면 "채웠다"와 "안 채웠다"가
    // 첫 항목에서 구별되지 않는다.
    let store = LayerStore(다섯종(z: 99))

    #expect(store.layers.map(\.transform.z) == [0, 1, 2, 3, 4])
    #expect(store.layers.map(\.typeName) == ["photo", "text", "shape", "stamp", "drawing"])
}

@Test func entries와_layers의_z가_일치한다() {
    // 두 표면이 갈리면 `EDITOR-4`가 선택 대상을 고를 때(v4 §5.11 "같은 지점을
    // 탭하면 z-order 최상단") 낡은 z를 보고 **맨 아래를 최상단으로 고른다.**
    var store = LayerStore([도형(0, z: 10), 도형(1, z: 0), 도형(2, z: 7)])
    store.bringToFront(store.entries[0].id)

    #expect(store.entries.map(\.layer.transform.z) == store.layers.map(\.transform.z))
    #expect(store.entries.map(\.layer.transform.z) == [0, 1, 2])
}

// MARK: - AC-3~7: z-order 4종

@Test func 맨_앞으로_보내면_나머지_상대_순서는_그대로다() {
    var store = LayerStore([도형(0), 도형(1), 도형(2), 도형(3)])
    store.bringToFront(store.entries[0].id)

    #expect(태그들(store) == [1, 2, 3, 0])
    #expect(z값들(store) == [0, 1, 2, 3])
}

@Test func 앞으로는_바로_위와만_자리를_바꾼다() {
    var store = LayerStore([도형(0), 도형(1), 도형(2), 도형(3)])
    store.bringForward(store.entries[1].id)

    #expect(태그들(store) == [0, 2, 1, 3])
}

@Test func 뒤로는_바로_아래와만_자리를_바꾼다() {
    var store = LayerStore([도형(0), 도형(1), 도형(2), 도형(3)])
    store.sendBackward(store.entries[2].id)

    #expect(태그들(store) == [0, 2, 1, 3])
}

@Test func 맨_뒤로_보내면_나머지_상대_순서는_그대로다() {
    var store = LayerStore([도형(0), 도형(1), 도형(2), 도형(3)])
    store.sendToBack(store.entries[3].id)

    #expect(태그들(store) == [3, 0, 1, 2])
}

@Test func 끝에_있는_레이어를_더_밀어도_아무것도_바뀌지_않는다() {
    let 원본 = LayerStore([도형(0), 도형(1), 도형(2)])

    var 앞 = 원본
    앞.bringToFront(원본.entries[2].id)
    앞.bringForward(원본.entries[2].id)
    #expect(태그들(앞) == [0, 1, 2])

    var 뒤 = 원본
    뒤.sendToBack(원본.entries[0].id)
    뒤.sendBackward(원본.entries[0].id)
    #expect(태그들(뒤) == [0, 1, 2])
}

// MARK: - AC-8: 어떤 순서로 섞어도 z는 촘촘하다

@Test func 조작을_섞어도_순서가_예상대로_따라온다() {
    // **z만 단언하면 아무것도 증명하지 못한다.** `layers`가 z를 인덱스에서
    // 채우므로 `z값들 == Array(0..<count)`는 구조적으로 항상 참이다 —
    // 조작이 어떻게 망가져도 초록인 항등식이다(실측 확인).
    //
    // 그래서 **매 단계 태그열을 함께 본다.** z 촘촘함은 그 위에 얹어 확인한다.
    var store = LayerStore((0..<5).map { 도형($0) })

    func 확인(_ 단계: String, _ 기대: [Int]) {
        #expect(태그들(store) == 기대, "\(단계) 뒤")
        #expect(z값들(store) == Array(0..<기대.count), "\(단계) 뒤 z")
    }
    확인("시작", [0, 1, 2, 3, 4])

    store.bringToFront(store.entries[0].id);  확인("맨 앞으로", [1, 2, 3, 4, 0])
    store.sendBackward(store.entries[3].id);  확인("뒤로",     [1, 2, 4, 3, 0])
    store.remove(store.entries[1].id);        확인("삭제",     [1, 4, 3, 0])
    store.insert(도형(99));                    확인("삽입",     [1, 4, 3, 0, 99])
    store.sendToBack(store.entries[2].id);    확인("맨 뒤로",  [3, 1, 4, 0, 99])
    store.bringForward(store.entries[0].id);  확인("앞으로",   [1, 3, 4, 0, 99])
    store.remove(store.entries[0].id);        확인("삭제 2",   [3, 4, 0, 99])
}

// MARK: - AC-9~11: 삽입·삭제

@Test func 새_레이어는_맨_앞에_오고_그_식별자를_돌려준다() {
    var store = LayerStore([도형(0), 도형(1)])
    let 새id = store.insert(도형(9))

    #expect(태그들(store) == [0, 1, 9])
    #expect(store.layers.last?.transform.z == 2)
    // **반환값은 버리는 값이 아니다.** `TOOL-3`이 "복제본이 선택 상태가 된다"를
    // 구현하려면 이 값을 선택에 넣어야 하는데, 스토어에 없는 id를 돌려주면
    // 하이라이트가 안 뜨고 z-order 버튼이 조용히 먹통이 된다(없는 id는 무시).
    #expect(새id == store.entries.last?.id)
}

@Test func 가운데를_지우면_z에_구멍이_남지_않는다() {
    var store = LayerStore([도형(0), 도형(1), 도형(2)])
    store.remove(store.entries[1].id)

    #expect(태그들(store) == [0, 2])
    #expect(z값들(store) == [0, 1])
}

@Test func 없는_식별자를_지목하면_아무_일도_일어나지_않는다() {
    let 원본 = LayerStore([도형(0), 도형(1)])
    let 유령 = UUID()

    let 조작들: [(name: String, run: (inout LayerStore, UUID) -> Void)] = [
        ("맨 앞으로", { $0.bringToFront($1) }),
        ("앞으로",   { $0.bringForward($1) }),
        ("뒤로",     { $0.sendBackward($1) }),
        ("맨 뒤로",  { $0.sendToBack($1) }),
        ("삭제",     { $0.remove($1) }),
    ]

    for 조작 in 조작들 {
        var store = 원본
        조작.run(&store, 유령)
        #expect(태그들(store) == [0, 1], "\(조작.name)")
        #expect(z값들(store) == [0, 1], "\(조작.name)")
    }
}

// MARK: - AC-12·13: 손상된 문서

@Test func z가_전부_같으면_입력_배열_순서가_유지된다() {
    // **정렬이 불안정하면 같은 파일이 열 때마다 다른 순서로 보인다.**
    // Swift의 `sorted(by:)`는 안정 정렬을 보장하지 않는다.
    let store = LayerStore([도형(0, z: 5), 도형(1, z: 5), 도형(2, z: 5)])

    #expect(태그들(store) == [0, 1, 2])
    #expect(z값들(store) == [0, 1, 2])
}

@Test func z에_구멍이_있으면_오름차순으로_촘촘해진다() {
    let store = LayerStore([도형(0, z: 10), 도형(1, z: 0), 도형(2, z: 7)])

    #expect(태그들(store) == [1, 2, 0])   // z 0 · 7 · 10 순
    #expect(z값들(store) == [0, 1, 2])
}

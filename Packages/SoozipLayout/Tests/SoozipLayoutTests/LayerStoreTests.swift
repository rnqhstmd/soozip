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

@Test func 넣은_순서와_내용이_그대로_나온다() {
    let store = LayerStore([도형(7), 도형(8), 도형(9)])
    #expect(태그들(store) == [7, 8, 9])
    #expect(z값들(store) == [0, 1, 2])
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

@Test func 조작을_어떻게_섞어도_z는_0부터_촘촘하다() {
    // **이 단위의 핵심 불변식이다**(v4 §5.11 "빈 번호가 쌓이면 상한에 부딪힌다").
    // 조작이 6종이라 재번호를 한 곳에서만 빠뜨려도 구멍이 생긴다.
    var store = LayerStore((0..<5).map { 도형($0) })

    func 촘촘한가(_ 단계: String) {
        #expect(z값들(store) == Array(0..<store.entries.count), "\(단계) 뒤")
    }

    store.bringToFront(store.entries[0].id);   촘촘한가("맨 앞으로")
    store.sendBackward(store.entries[3].id);   촘촘한가("뒤로")
    store.remove(store.entries[1].id);         촘촘한가("삭제")
    store.insert(도형(99));                     촘촘한가("삽입")
    store.sendToBack(store.entries[2].id);     촘촘한가("맨 뒤로")
    store.bringForward(store.entries[0].id);   촘촘한가("앞으로")
    store.remove(store.entries[0].id);         촘촘한가("삭제 2")
}

// MARK: - AC-9~11: 삽입·삭제

@Test func 새_레이어는_맨_앞에_온다() {
    var store = LayerStore([도형(0), 도형(1)])
    store.insert(도형(9))

    #expect(태그들(store) == [0, 1, 9])
    #expect(store.layers.last?.transform.z == 2)
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

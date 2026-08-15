import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// EDITOR-3 — 타입별 상한 (v4 §5.13)
//
// 병목은 익스포트가 아니라 **디코딩된 비트맵**이라 상한을 전체가 아니라
// 타입별로 건다. `text`·`shape`·`stamp`는 **합산**된다.
//
// 분류와 상한은 `LayerCategory` 한 곳에 있고 `LayoutDocument.validate()`와
// `LayerStore`가 같은 것을 쓴다 — 두 벌이면 삽입은 막히는데 저장은 통과하는
// (또는 그 반대) 어긋남이 조용히 생긴다.

// MARK: - 픽스처

private func 자리(_ i: Int) -> LayerTransform {
    LayerTransform(x: 100 + Double(i) * 10, y: 200)
}

private func 사진() -> Layer {
    .photo(PhotoLayer(assetId: UUID().uuidString, transform: 자리(0), filter: nil))
}
private func 펜() -> Layer {
    .drawing(DrawingLayer(assetId: UUID().uuidString, transform: 자리(1)))
}
private func 텍스트() -> Layer {
    .text(TextLayer(string: "가", font: .pretendard, size: 40,
                    color: "#000000", align: .left, transform: 자리(2)))
}
private func 도형() -> Layer {
    .shape(ShapeLayer(kind: .circle, width: 50, height: 50, fill: 0,
                      stroke: nil, strokeWidth: 0, transform: 자리(3)))
}
private func 도장() -> Layer {
    .stamp(StampLayer(date: "2026-08-12", style: "plain", transform: 자리(4)))
}

private func 스토어(_ 만들기: () -> Layer, _ n: Int) -> LayerStore {
    LayerStore((0..<n).map { _ in 만들기() })
}

// MARK: - AC-1~4: 삽입 차단

@Test func 사진이_여덟이면_더_넣을_수_없다() {
    var store = 스토어(사진, 8)

    #expect(throws: LayerLimitError.limitReached(category: .photo, limit: 8)) {
        try store.insert(사진())
    }
}

@Test func 거부되면_스토어가_그대로다() {
    var store = 스토어(사진, 8)
    let 이전 = store.entries.map(\.id)

    #expect(throws: (any Error).self) { try store.insert(사진()) }

    #expect(store.entries.map(\.id) == 이전)
    #expect(store.layers.count == 8)
}

@Test func 펜은_다섯이_상한이다() {
    var store = 스토어(펜, 5)

    #expect(throws: LayerLimitError.limitReached(category: .drawing, limit: 5)) {
        try store.insert(펜())
    }
}

@Test func 장식이_서른이면_세_타입_무엇도_들어가지_않는다() {
    for 만들기 in [텍스트, 도형, 도장] {
        var store = 스토어(텍스트, 30)
        #expect(throws: LayerLimitError.limitReached(category: .decor, limit: 30)) {
            try store.insert(만들기())
        }
    }
}

// MARK: - AC-5·6: 합산과 독립

@Test func 텍스트_도형_도장은_합산된다() {
    // **각각 30이 아니다.** 10+10+10이면 이미 꽉 찬 것이다.
    var store = LayerStore((0..<10).map { _ in 텍스트() }
                         + (0..<10).map { _ in 도형() }
                         + (0..<10).map { _ in 도장() })

    #expect(store.layers.count == 30)
    #expect(throws: LayerLimitError.limitReached(category: .decor, limit: 30)) {
        try store.insert(도형())
    }
}

@Test func 범주가_다르면_상한은_독립이다() throws {
    var store = 스토어(사진, 8)

    try store.insert(텍스트())     // 사진이 꽉 찼어도 장식은 들어간다

    #expect(store.layers.count == 9)
}

// MARK: - AC-7~9: 도구 비활성 판정

@Test func 남은_개수를_알려준다() {
    let store = 스토어(사진, 7)

    #expect(store.canInsert(.photo))
    #expect(store.remaining(.photo) == 1)
    #expect(store.remaining(.drawing) == 5)
    #expect(store.remaining(.decor) == 30)
}

@Test func 상한에_도달하면_넣을_수_없다고_답한다() {
    let store = 스토어(사진, 8)

    #expect(!store.canInsert(.photo))
    #expect(store.remaining(.photo) == 0)
    #expect(store.canInsert(.decor))   // 다른 범주는 그대로
}

@Test func 하나를_지우면_다시_넣을_수_있다() throws {
    var store = 스토어(사진, 8)
    #expect(!store.canInsert(.photo))

    store.remove(store.entries[0].id)

    #expect(store.canInsert(.photo))
    try store.insert(사진())
    #expect(store.layers.count == 8)
}

// MARK: - AC-10·11: 상한을 넘긴 문서

@Test func 상한을_넘긴_문서를_불러와도_잘라내지_않는다() {
    // **사용자의 작업물을 임의로 버리지 않는다.** 다른 버전이 만들었거나
    // 손상된 문서일 수 있다 — 열어서 보여주고, 더 넣는 것만 막는다.
    let store = 스토어(사진, 12)

    #expect(store.layers.count == 12)
}

@Test func 이미_넘긴_상태에서_남은_개수는_음수가_아니다() {
    let store = 스토어(사진, 12)

    #expect(!store.canInsert(.photo))
    #expect(store.remaining(.photo) == 0)
    // **`count`는 상한 초과를 관측할 수 있는 유일한 API다.** `remaining`이
    // 0으로 클램프하므로 여기서 실제 개수를 함께 보지 않으면 `count`가
    // 상한으로 잘려도 아무도 모른다 — 배선이 "12/8"을 못 보여준다.
    #expect(store.count(.photo) == 12)
}

// MARK: - 위반 보고 (validate)

@Test func 위반_개수는_그_범주의_개수다_전체가_아니다() {
    // **위반 픽스처가 전부 단일 범주면 둘이 구별되지 않는다** — 그 문서에서는
    // `layers.count`와 범주 개수가 같기 때문이다(실측 확인).
    //
    // 사진 9장 + 텍스트 2개인 실제 문서에서 "사진 11장"이라고 안내하면
    // 사용자는 자기 캔버스와 맞지 않는 숫자를 본다. `CanvasPromoter`가
    // 이 위반을 그대로 흘린다(`PromotionError.layoutInvalid`).
    let doc = LayoutDocument(aspect: .post,
                             layers: (0..<9).map { _ in 사진() }
                                   + (0..<2).map { _ in 텍스트() })

    #expect(doc.validate() == .photoLimitExceeded(count: 9, limit: 8))
}

@Test func 여러_범주가_동시에_넘치면_사진부터_보고한다() {
    // **우선순위가 enum 선언 순서에 실려 있으면 안 된다.** 케이스를 재배열하는
    // 무해해 보이는 리팩터가 사용자 안내를 바꾼다 — 사진이 많은데
    // "스티커가 많아요"라고 말하게 된다(실측: 케이스 순서만 뒤집어도 그렇게 됐다).
    let doc = LayoutDocument(aspect: .post,
                             layers: (0..<9).map { _ in 사진() }
                                   + (0..<6).map { _ in 펜() }
                                   + (0..<31).map { _ in 도형() })

    #expect(doc.validate() == .photoLimitExceeded(count: 9, limit: 8))
}

@Test func 보고_순서에_빠진_범주가_없다() {
    // `reportingOrder`에서 빠진 범주는 **영원히 보고되지 않는다.**
    // 상한을 넘겨도 저장이 통과해 버린다.
    #expect(Set(LayerCategory.reportingOrder) == Set(LayerCategory.allCases))
    #expect(LayerCategory.reportingOrder.count == LayerCategory.allCases.count)
}

// MARK: - 팔레트용 판별자

@Test func 레이어를_만들기_전에도_범주를_알_수_있다() {
    // 도구 팔레트는 **레이어를 만들기 전에** 버튼을 비활성화해야 한다(v4 §5.13).
    // `Layer.category`만 있으면 뷰가 "텍스트·도형·도장 → decor" 매핑을 다시
    // 적게 되고, `LayerCategory`로 막았던 두 벌이 한 계층 위로 옮겨갈 뿐이다.
    #expect(LayerKind.photo.category == .photo)
    #expect(LayerKind.drawing.category == .drawing)
    for 종류 in [LayerKind.text, .shape, .stamp] {
        #expect(종류.category == .decor, "\(종류)")
    }
}

@Test func 인스턴스의_범주와_판별자의_범주가_같다() {
    // 두 경로가 갈라지면 팔레트 판정과 삽입 차단이 어긋난다.
    for (layer, kind) in [(사진(), LayerKind.photo), (펜(), .drawing),
                          (텍스트(), .text), (도형(), .shape), (도장(), .stamp)] {
        #expect(layer.kind == kind)
        #expect(layer.category == kind.category, "\(kind)")
        #expect(layer.typeName == kind.rawValue, "\(kind)")
    }
}

// MARK: - AC-12: 단일 출처

@Test func 스토어의_상한과_문서의_사후_판정이_같은_경계를_쓴다() {
    // **두 벌로 갈라지면 삽입은 막히는데 저장은 통과한다**(또는 반대).
    // 각 범주를 정확히 상한까지 채운 문서는 위반이 없어야 한다.
    var layers: [Layer] = []
    layers += (0..<LayerCategory.photo.limit).map { _ in 사진() }
    layers += (0..<LayerCategory.drawing.limit).map { _ in 펜() }
    layers += (0..<LayerCategory.decor.limit).map { _ in 도형() }

    let store = LayerStore(layers)
    let doc = LayoutDocument(aspect: .post, layers: store.layers)

    #expect(doc.validate() == nil)
    for 범주 in LayerCategory.allCases {
        #expect(!store.canInsert(범주), "\(범주)")
    }
}

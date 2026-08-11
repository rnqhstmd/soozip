import Testing
import Foundation
@testable import Soozip

// CoverPolicy: 표지 판정 + 불변식.
// ModelContainer 없이도 @Model 인스턴스의 속성 읽기/쓰기가 정상 동작한다(실측 확인됨).
// 따라서 여기서는 컨테이너를 만들지 않고 Canvas()/Collection()에 직접 대입한다.

private func makeCanvas(id: UUID, createdAt: Date) -> Canvas {
    let canvas = Canvas()
    canvas.id = id
    canvas.createdAt = createdAt
    return canvas
}

private func makeCollection(coverCanvasID: String) -> Collection {
    let collection = Collection()
    collection.coverCanvasID = coverCanvasID
    return collection
}

// 타이브레이크(id.uuidString 대소 비교)를 결정적으로 검증하기 위한 고정 UUID.
// "BBBB..."가 "AAAA..."보다 문자열상 크다.
private let uuidA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
private let uuidB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

// MARK: - resolve

@Test func 후보가_비면_resolve는_nil을_반환한다() {
    // BR-4: 캔버스 0장인 모음집은 표지 계산을 하지 않는다.
    let result = CoverPolicy.resolve(in: [], coverID: uuidA.uuidString)
    #expect(result == nil)
}

@Test func coverID와_일치하는_캔버스가_후보에_있으면_그대로_반환한다() throws {
    // 이미 지정된 표지는 최신순 재계산으로 바뀌지 않아야 한다.
    let older = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let newer = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))
    // coverID는 더 오래된 쪽을 가리키지만, 지정되어 있으므로 그대로 유지되어야 한다.
    let result = try #require(CoverPolicy.resolve(in: [older, newer], coverID: uuidA.uuidString))
    #expect(result.id == uuidA)
}

@Test func coverID가_후보에_없으면_createdAt이_가장_최신인_캔버스를_반환한다() throws {
    let older = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let newer = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))
    let result = try #require(CoverPolicy.resolve(in: [older, newer], coverID: ""))
    #expect(result.id == uuidB)
}

@Test func createdAt이_같으면_배열_순서와_무관하게_id_uuidString이_큰_쪽을_반환한다() throws {
    // 2차 키가 없으면 SwiftData to-many 순서가 보장되지 않아 실행마다 표지가 바뀔 수 있다.
    // "첫 번째/마지막을 그냥 반환"하는 틀린 구현을 잡으려면 두 순서 모두에서
    // 같은 결과(uuidB)가 나오는지를 봐야 한다 — 한쪽 순서만 보면 우연히 통과할 수 있다.
    let sameTime = Date(timeIntervalSince1970: 500)
    let canvasA = makeCanvas(id: uuidA, createdAt: sameTime)
    let canvasB = makeCanvas(id: uuidB, createdAt: sameTime)

    let resultAB = try #require(CoverPolicy.resolve(in: [canvasA, canvasB], coverID: ""))
    let resultBA = try #require(CoverPolicy.resolve(in: [canvasB, canvasA], coverID: ""))

    #expect(resultAB.id == uuidB)
    #expect(resultBA.id == uuidB)
}

// MARK: - reconcile

@Test func reconcile은_resolve_결과의_id를_coverCanvasID에_기록한다() {
    let collection = makeCollection(coverCanvasID: "")
    let older = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let newer = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))
    CoverPolicy.reconcile(collection, candidates: [older, newer])
    #expect(collection.coverCanvasID == uuidB.uuidString)
}

@Test func 후보가_0장이면_reconcile은_coverCanvasID를_빈_문자열로_만든다() {
    let collection = makeCollection(coverCanvasID: uuidA.uuidString)
    CoverPolicy.reconcile(collection, candidates: [])
    #expect(collection.coverCanvasID == "")
}

// MARK: - isConsistent

@Test func coverCanvasID가_빈_문자열이면_isConsistent는_true다() {
    let collection = makeCollection(coverCanvasID: "")
    let canvas = makeCanvas(id: uuidA, createdAt: Date())
    #expect(CoverPolicy.isConsistent(collection, candidates: [canvas]))
}

@Test func coverCanvasID가_후보_중_하나를_가리키면_isConsistent는_true다() {
    let collection = makeCollection(coverCanvasID: uuidA.uuidString)
    let canvas = makeCanvas(id: uuidA, createdAt: Date())
    #expect(CoverPolicy.isConsistent(collection, candidates: [canvas]))
}

@Test func coverCanvasID가_후보에_없는_유령_id를_가리키면_isConsistent는_false다() {
    let collection = makeCollection(coverCanvasID: uuidB.uuidString)
    let canvas = makeCanvas(id: uuidA, createdAt: Date())
    #expect(!CoverPolicy.isConsistent(collection, candidates: [canvas]))
}

// MARK: - designate — 사용자가 대표를 직접 고른다 (AC-8·9)

@Test func 후보에_있는_캔버스는_대표로_지정된다() {
    let a = makeCollection(coverCanvasID: "")
    let older = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let newer = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))

    let 성공 = CoverPolicy.designate(older, for: a, candidates: [older, newer])

    // 더 오래된 쪽을 골라야 "최신 우선이 사용자 지정을 이기지 않는다"가 측정된다.
    #expect(성공)
    #expect(a.coverCanvasID == uuidA.uuidString)
}

@Test func 후보에_없는_캔버스는_대표로_지정되지_않는다() {
    // 다른 모음집의 캔버스가 표지가 되면 그것이 정확히 Phase 1이 불변식으로 막은
    // 상태다 — "표지가 이 모음집에 없는 캔버스를 가리킨다".
    let a = makeCollection(coverCanvasID: uuidA.uuidString)
    let 내것 = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let 남의것 = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))

    let 성공 = CoverPolicy.designate(남의것, for: a, candidates: [내것])

    #expect(!성공)
    #expect(a.coverCanvasID == uuidA.uuidString)   // 그대로다
}

@Test func 지정된_표지는_불변식을_만족한다() {
    let a = makeCollection(coverCanvasID: "")
    let older = makeCanvas(id: uuidA, createdAt: Date(timeIntervalSince1970: 0))
    let newer = makeCanvas(id: uuidB, createdAt: Date(timeIntervalSince1970: 1000))

    _ = CoverPolicy.designate(older, for: a, candidates: [older, newer])

    #expect(CoverPolicy.isConsistent(a, candidates: [older, newer]))
}

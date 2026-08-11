import Testing
import Foundation
import SwiftData
import SoozipLayout
@testable import Soozip

// CollectionPresenter — 모델을 화면 표시값으로 바꾼다 (AC-1~7, 14).
//
// **뷰가 아니라 여기를 테스트한다.** 이 저장소에는 UI 테스트 수단이 없어서
// 분기·계산·폴백을 전부 뷰 밖으로 뺐다. 뷰에 `if`가 늘면 그만큼 검증 밖으로
// 새는 것이므로, 여기서 못 재는 표시 규칙이 생기면 설계가 틀린 신호다.

// MARK: - 픽스처

/// 디코딩 가능한 것으로 **간주할** 바이트. 실제 PNG일 필요가 없다 —
/// 디코딩 판정을 클로저로 주입하기 때문이다.
private let 성한이미지 = Data([0x89, 0x50, 0x4E, 0x47])
private let 깨진이미지 = Data([0xFF, 0xFF])

/// 앱의 `UIImage(data:)` 자리에 들어가는 테스트 대역.
/// **클로저 상수가 아니라 함수인 이유**: 전역 클로저 `let`은 `Sendable`이 아니라
/// Swift 6에서 진단에 걸린다.
private func 성한것만통과(_ data: Data) -> Bool { data == 성한이미지 }

@MainActor
private func canvasInput(createdAt: Date, title: String = "",
                         renderedPNG: Data? = nil) -> CanvasInput {
    CanvasInput(aspect: .post, title: title, createdAt: createdAt, renderedPNG: renderedPNG)
}

@MainActor
private func presenter(_ library: LibraryRepository,
                       canDecode: @escaping (Data) -> Bool = 성한것만통과) -> CollectionPresenter {
    CollectionPresenter(library: library, canDecodeImage: canDecode)
}

private extension CarouselItem {
    /// 항목이 모음집 카드면 이름, `[+]`면 `nil`.
    var cardName: String? {
        if case .collection(let card) = self { return card.name }
        return nil
    }
}

// MARK: - AC-1·2: 캐러셀은 [+]를 맨 앞에 고정한다

@Test @MainActor func 캐러셀은_새_모음집_항목_뒤에_생성_순서대로_나온다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        try library.createCollection(name: "가", now: anchor)
        try library.createCollection(name: "나", now: try day(1, from: anchor))
        try library.createCollection(name: "다", now: try day(2, from: anchor))

        let items = try presenter(library).carouselItems()

        #expect(items.first == .newCollection)
        #expect(items.dropFirst().compactMap(\.cardName) == ["가", "나", "다"])
    }
}

@Test @MainActor func 모음집이_없으면_캐러셀에_새_모음집_항목만_있다() throws {
    try withLibrary { library, _ in
        let items = try presenter(library).carouselItems()
        #expect(items == [.newCollection])
    }
}

// MARK: - AC-14: 전체 보기는 [+]를 포함하지 않는다

@Test @MainActor func 전체_보기는_캐러셀과_같은_순서이고_새_모음집_항목이_없다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        try library.createCollection(name: "가", now: anchor)
        try library.createCollection(name: "나", now: try day(1, from: anchor))
        try library.createCollection(name: "다", now: try day(2, from: anchor))

        let p = presenter(library)
        let cards = try p.cards()
        let carousel = try p.carouselItems()

        #expect(cards.map(\.name) == ["가", "나", "다"])
        #expect(cards.map(\.name) == carousel.dropFirst().compactMap(\.cardName))
    }
}

// MARK: - AC-3·7: 캔버스 수와 빈 모음집

@Test @MainActor func 캔버스가_없으면_표지가_비고_수가_0이다() throws {
    try withLibrary { library, _ in
        let a = try library.createCollection(name: "빈", now: try testAnchor())

        let card = presenter(library).card(for: a)

        #expect(card.cover == .empty)
        #expect(card.canvasCount == 0)
        #expect(card.name == "빈")
    }
}

@Test @MainActor func 캔버스_수가_그대로_나온다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        for i in 0..<5 {
            try library.createCanvas(canvasInput(createdAt: try day(i, from: anchor)),
                                     in: a, now: anchor)
        }

        #expect(presenter(library).card(for: a).canvasCount == 5)
    }
}

// MARK: - AC-4·5: 표지 폴백 — 지정 → 최근 → 단색

@Test @MainActor func 표지가_지정되지_않았으면_가장_최근_캔버스의_이미지다() throws {
    try withLibrary { library, context in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor, renderedPNG: 깨진이미지),
                                 in: a, now: anchor)
        let 최신 = try library.createCanvas(
            canvasInput(createdAt: try day(3, from: anchor), renderedPNG: 성한이미지),
            in: a, now: anchor)

        // 표지 미지정 상태를 만든다 — 실제로는 생성 시 첫 캔버스가 표지가 되므로
        // 직접 비워야 이 폴백 단계가 측정된다.
        a.coverCanvasID = ""
        try context.save()

        let card = presenter(library).card(for: a)

        #expect(card.cover == .image(성한이미지))
        #expect(최신.renderedPNG == 성한이미지)
    }
}

@Test @MainActor func 대표로_지정된_캔버스가_최신보다_우선한다() throws {
    // 지정이 최신 우선을 이기지 않으면 사용자가 고른 표지가 캔버스를 추가할 때마다
    // 밀려난다.
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        let 가장오래된것 = try library.createCanvas(
            canvasInput(createdAt: anchor, renderedPNG: 성한이미지), in: a, now: anchor)
        try library.createCanvas(
            canvasInput(createdAt: try day(1, from: anchor), renderedPNG: 깨진이미지),
            in: a, now: anchor)
        try library.createCanvas(
            canvasInput(createdAt: try day(2, from: anchor), renderedPNG: 깨진이미지),
            in: a, now: anchor)

        try library.setCover(가장오래된것, of: a)

        #expect(presenter(library).card(for: a).cover == .image(성한이미지))
    }
}

// MARK: - AC-6: 디코딩 실패는 단색으로 접는다 (BR-3)

@Test @MainActor func 표지_이미지를_디코딩할_수_없으면_단색으로_폴백한다() throws {
    // 빈 화면을 내지 않는 것이 요점이다. 캔버스 수는 실제 값을 유지해야
    // "사진은 안 보이는데 3장이라고 적힌" 정상 상태가 된다.
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        for i in 0..<3 {
            try library.createCanvas(
                canvasInput(createdAt: try day(i, from: anchor), renderedPNG: 깨진이미지),
                in: a, now: anchor)
        }

        let card = presenter(library).card(for: a)

        #expect(card.cover == .empty)
        #expect(card.canvasCount == 3)
    }
}

@Test @MainActor func 표지_캔버스에_렌더_이미지가_없으면_단색이다() throws {
    // AC에 없는 자리라 여기서 고정한다. 다음 후보로 넘어가지 **않는다** —
    // 넘어가면 "표지로 지정했는데 다른 그림이 나오는" 상태가 된다.
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        let 이미지없는것 = try library.createCanvas(canvasInput(createdAt: anchor),
                                                 in: a, now: anchor)
        try library.createCanvas(
            canvasInput(createdAt: try day(1, from: anchor), renderedPNG: 성한이미지),
            in: a, now: anchor)

        try library.setCover(이미지없는것, of: a)

        #expect(presenter(library).card(for: a).cover == .empty)
    }
}

// MARK: - 다른 모음집이 섞이지 않는다

@Test @MainActor func 카드의_캔버스_수는_그_모음집_것만_센다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "가", now: anchor)
        let b = try library.createCollection(name: "나", now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor), in: a, now: anchor)
        for i in 0..<3 {
            try library.createCanvas(canvasInput(createdAt: try day(i, from: anchor)),
                                     in: b, now: anchor)
        }

        let p = presenter(library)
        #expect(p.card(for: a).canvasCount == 1)
        #expect(p.card(for: b).canvasCount == 3)
    }
}

// MARK: - AC-15·16·17: 상세의 캔버스 정렬

@Test @MainActor func 상세는_기본이_최신순이다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        try library.createCanvas(canvasInput(createdAt: try day(1, from: anchor),
                                             title: "가운데"), in: a, now: anchor)
        try library.createCanvas(canvasInput(createdAt: try day(9, from: anchor),
                                             title: "최신"), in: a, now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor, title: "최고참"),
                                 in: a, now: anchor)

        let p = presenter(library)
        #expect(p.canvases(in: a).map(\.title) == ["최신", "가운데", "최고참"])
    }
}

@Test @MainActor func 오래된순으로_전환하면_정확히_뒤집힌다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        try library.createCanvas(canvasInput(createdAt: try day(1, from: anchor),
                                             title: "가운데"), in: a, now: anchor)
        try library.createCanvas(canvasInput(createdAt: try day(9, from: anchor),
                                             title: "최신"), in: a, now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor, title: "최고참"),
                                 in: a, now: anchor)

        let p = presenter(library)
        #expect(p.canvases(in: a, order: .oldestFirst).map(\.title)
                == p.canvases(in: a).map(\.title).reversed())
    }
}

@Test @MainActor func 상세에_다른_모음집의_캔버스는_섞이지_않는다() throws {
    try withLibrary { library, _ in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "가", now: anchor)
        let b = try library.createCollection(name: "나", now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor, title: "A것"), in: a, now: anchor)
        try library.createCanvas(canvasInput(createdAt: anchor, title: "B것"), in: b, now: anchor)

        let p = presenter(library)
        #expect(p.canvases(in: a).map(\.title) == ["A것"])
        #expect(p.canvases(in: b).map(\.title) == ["B것"])
    }
}

// MARK: - AC-18·19: 초안 배너

@Test @MainActor func 그_모음집에_초안이_있으면_배너가_노출된다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            try store.create(canvasID: UUID().uuidString,
                             collectionID: a.id.uuidString, aspect: .post, now: anchor)

            let banner = DraftBannerPolicy(store: store)
            #expect(try banner.shouldShow(for: a))
        }
    }
}

@Test @MainActor func 다른_모음집의_초안은_배너를_띄우지_않는다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "가", now: anchor)
            let b = try library.createCollection(name: "나", now: anchor)
            try store.create(canvasID: UUID().uuidString,
                             collectionID: b.id.uuidString, aspect: .post, now: anchor)

            let banner = DraftBannerPolicy(store: store)
            #expect(!(try banner.shouldShow(for: a)))
            #expect(try banner.shouldShow(for: b))
        }
    }
}

@Test @MainActor func 소문자로_기록된_초안도_같은_모음집으로_인식된다() throws {
    // Phase 2에서 pruneOrphans만 정규화했고 draft(forCollection:)은 `==` 그대로였다.
    // 여기서는 데이터 손실이 아니라 **배너가 영영 안 뜨는** 것으로 나타나
    // 증상이 더 조용하다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            try store.create(canvasID: UUID().uuidString,
                             collectionID: a.id.uuidString.lowercased(),
                             aspect: .post, now: anchor)

            let banner = DraftBannerPolicy(store: store)
            #expect(try banner.shouldShow(for: a))
        }
    }
}

import Testing
import Foundation
import SwiftData
import SoozipLayout
@testable import Soozip

// 삭제 경고(AC-22~24)와 첫 실행 고스트 힌트(AC-25~27).
//
// 둘 다 순수 값이다. 문구와 노출 판정을 뷰에 두면 잴 수 없어서 값이 들고 있다.

@MainActor
private func canvasInput(createdAt: Date) -> CanvasInput {
    CanvasInput(aspect: .post, createdAt: createdAt)
}

// MARK: - AC-22·23: 삭제 경고는 개수를 명시한다

@Test func 캔버스가_있으면_경고에_개수가_들어간다() throws {
    let prompt = DeletionPrompt.forCollection(canvasCount: 3)

    #expect(prompt == .warning(canvasCount: 3))
    let message = try #require(prompt.message)
    #expect(message.contains("3"))
}

@Test func 캔버스가_없으면_경고_없이_즉시_삭제다() {
    let prompt = DeletionPrompt.forCollection(canvasCount: 0)

    #expect(prompt == .immediate)
    #expect(prompt.message == nil)
}

@Test func 캔버스가_한_장이어도_경고한다() {
    // 경계값. 0장만 즉시 삭제이고 1장부터는 사용자 확인을 받는다 —
    // 한 장이라도 사용자가 만든 것이라 조용히 지우면 안 된다.
    #expect(DeletionPrompt.forCollection(canvasCount: 1) == .warning(canvasCount: 1))
}

// MARK: - AC-24: 삭제가 캔버스와 사진까지 지운다

@Test @MainActor func 모음집을_지우면_캔버스와_사진이_전부_사라진다() throws {
    // cascade 자체는 Phase 1이 검증했다. 여기서는 화면이 부르는 경로가
    // 그 cascade에 실제로 닿는지를 잰다.
    try withLibrary { library, context in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        for i in 0..<2 {
            let canvas = try library.createCanvas(
                canvasInput(createdAt: try day(i, from: anchor)), in: a, now: anchor)
            for _ in 0..<2 {
                let photo = CanvasPhoto()
                photo.canvas = canvas
                context.insert(photo)
            }
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 4)

        try library.deleteCollection(a)

        #expect(try context.fetchCount(FetchDescriptor<Collection>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 0)
    }
}

// MARK: - AC-25·26·27: 첫 실행 고스트 힌트 (BR-5)

@Test func 모음집이_없고_닫은_적이_없으면_힌트를_보여준다() {
    let policy = GhostHintPolicy(hasDismissed: false)
    #expect(policy.shouldShow(collectionCount: 0))
}

@Test func 모음집이_하나라도_있으면_힌트를_보여주지_않는다() {
    let policy = GhostHintPolicy(hasDismissed: false)
    #expect(!policy.shouldShow(collectionCount: 1))
}

@Test func 한_번_닫으면_모음집을_전부_지워도_다시_뜨지_않는다() {
    // "첫 실행 힌트"는 처음 한 번을 위한 것이다. 모음집을 지웠다고 다시 뜨면
    // 앱을 쓸수록 반복해서 보게 된다.
    let policy = GhostHintPolicy(hasDismissed: true)
    #expect(!policy.shouldShow(collectionCount: 0))
}

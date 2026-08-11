import Testing
import Foundation
import SwiftData
import SoozipDraft
import SoozipLayout
@testable import Soozip

// CANVAS-1·2 — 승격 트랜잭션 + 단계별 실패 주입.
//
// 이 도메인의 한 줄 약속은 **"작업물이 절대 증발하지 않는다"** 이고,
// 아래 실패 주입 4건이 그 약속을 재는 자리다. 순서를 바꿔 초안을 먼저 지우면
// 저장 실패 시 사용자의 작업물이 사라진다.

// MARK: - 픽스처

private let 렌더결과 = Data([0x89, 0x50, 0x4E, 0x47, 0x0D])

private struct 주입된실패: Error {}

@MainActor
private func 자리(_ i: Int) -> LayerTransform {
    LayerTransform(x: 100 + Double(i) * 10, y: 100, z: i)
}

@MainActor
private func layout(photos: Int = 0, texts: Int = 0,
                    sharedAssetID: String? = nil) -> LayoutDocument {
    var layers: [Layer] = []
    for i in 0..<photos {
        layers.append(.photo(PhotoLayer(assetId: sharedAssetID ?? "asset-\(i)",
                                        transform: 자리(i), filter: nil)))
    }
    for i in 0..<texts {
        layers.append(.text(TextLayer(string: "텍스트 \(i)", font: .pretendard,
                                      size: 48, color: "#000000", align: .left,
                                      transform: 자리(photos + i))))
    }
    return LayoutDocument(aspect: .post, layers: layers)
}

/// 초안 하나를 만들고 사진 원본까지 써 둔다.
@MainActor
@discardableResult
private func 초안준비(_ store: DraftStore, collectionID: String, canvasID: String,
                    document: LayoutDocument, now: Date,
                    photoBytes: [String: Data] = [:]) throws -> String {
    try store.create(canvasID: canvasID, collectionID: collectionID,
                     aspect: .post, now: now)
    try store.writeLayout(document, canvasID: canvasID, now: now)
    for (assetID, data) in photoBytes {
        try store.writePhoto(data, assetID: assetID, format: .jpeg, canvasID: canvasID)
    }
    return canvasID
}

@MainActor
private func promoter(_ store: DraftStore, _ library: LibraryRepository,
                      render: @escaping (LayoutDocument) throws -> Data = { _ in 렌더결과 })
    -> CanvasPromoter {
    CanvasPromoter(store: store, library: library, render: render)
}

// MARK: - AC-1~5: 성공 경로

@Test @MainActor func 승격하면_초안이_캔버스가_된다() throws {
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 2, texts: 1), now: anchor,
                       photoBytes: ["asset-0": Data([1]), "asset-1": Data([2])])

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(canvas.collection?.id == a.id)
            #expect(canvas.renderedPNG == 렌더결과)
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 1)
        }
    }
}

@Test @MainActor func 승격이_성공하면_초안_폴더가_삭제된다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(try store.load(canvasID: id) == nil)
        }
    }
}

@Test @MainActor func 첫_캔버스를_승격하면_그것이_모음집_표지가_된다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            #expect(a.coverCanvasID.isEmpty)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(a.coverCanvasID == canvas.id.uuidString)
        }
    }
}

@Test @MainActor func 레이아웃이_바이트_단위로_보존된다() throws {
    // layoutJSON은 이 앱의 확장 통로다. 승격이 재인코딩하면서 한 바이트라도
    // 달라지면, 재편집이 사용자가 만든 것과 다른 것을 연다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 1, texts: 2), now: anchor,
                       photoBytes: ["asset-0": Data([9])])
            let 초안레이아웃 = try store.readLayout(canvasID: id)

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            let 승격레이아웃 = try JSONDecoder().decode(LayoutDocument.self,
                                                    from: canvas.layoutJSON)
            #expect(승격레이아웃 == 초안레이아웃)
        }
    }
}

@Test @MainActor func 미래_기록_날짜가_보정_없이_보존된다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let future = try day(30, from: anchor)
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1), now: future)

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(canvas.createdAt == future)
        }
    }
}

// MARK: - AC-6·7: 사진 이관

@Test @MainActor func 사진_원본이_CanvasPhoto로_옮겨진다() throws {
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 2), now: anchor,
                       photoBytes: ["asset-0": Data([0xAA]), "asset-1": Data([0xBB])])

            try promoter(store, library).promote(canvasID: id, now: anchor)

            let photos = try context.fetch(FetchDescriptor<CanvasPhoto>())
            #expect(photos.count == 2)
            #expect(Set(photos.map(\.data)) == [Data([0xAA]), Data([0xBB])])
        }
    }
}

@Test @MainActor func 같은_assetId를_공유하는_복제_레이어는_사진을_하나만_만든다() throws {
    // 복제는 assetId를 공유한다(BR-5). 레이어마다 CanvasPhoto를 만들면 같은
    // 2000px 사진이 4벌 저장되어 용량이 4배가 된다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 4, sharedAssetID: "공유"), now: anchor,
                       photoBytes: ["공유": Data([0xCC])])

            try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 1)
        }
    }
}

// MARK: - AC-8·9: 검증 실패 (1단계)

@Test @MainActor func 사진_상한을_넘으면_승격이_거부된다() throws {
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 9), now: anchor)

            #expect(throws: PromotionError.layoutInvalid(
                .photoLimitExceeded(count: 9, limit: 8))) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
        }
    }
}

@Test @MainActor func 검증에_걸려도_초안은_남는다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 9), now: anchor)

            _ = try? promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(try store.load(canvasID: id) != nil)
        }
    }
}

// MARK: - AC-10~13: 단계별 실패 주입 — 이 단위의 핵심

@Test @MainActor func 렌더가_실패하면_초안이_남고_캔버스가_생기지_않는다() throws {
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            let 실패렌더 = promoter(store, library) { _ in throw 주입된실패() }
            #expect(throws: (any Error).self) {
                try 실패렌더.promote(canvasID: id, now: anchor)
            }

            #expect(try store.load(canvasID: id) != nil)
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
        }
    }
}

@Test @MainActor func 사진_읽기가_실패하면_초안이_남고_아무것도_생기지_않는다() throws {
    // 레이아웃은 사진을 참조하는데 원본 파일이 없다 — 3단계가 여기서 깨진다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(photos: 1), now: anchor)   // photoBytes 없음

            #expect(throws: (any Error).self) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }

            #expect(try store.load(canvasID: id) != nil)
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 0)
        }
    }
}

@Test @MainActor func 소속_모음집이_없으면_거부되고_초안이_남는다() throws {
    // 4단계(DB 쓰기)가 성립할 수 없는 경우다. 다른 기기에서 모음집을 지웠거나
    // 초안 메타가 손상됐다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let id = UUID().uuidString
            try 초안준비(store, collectionID: UUID().uuidString, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            #expect(throws: PromotionError.collectionNotFound(
                collectionID: id)) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }

            #expect(try store.load(canvasID: id) != nil)
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
        }
    }
}

@Test @MainActor func 초안_정리가_실패해도_캔버스는_남는다() throws {
    // **유일하게 되돌리지 않는 실패다.** 2~5가 다 됐는데 폴더 삭제만 실패했다고
    // 캔버스를 롤백하면, 사용자는 정리 실패 때문에 저장을 잃는다. 남은 고아
    // 초안은 다음 실행의 pruneOrphans가 치운다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            // 정리 대상 폴더를 미리 지워 6단계를 실패시킨다.
            let promoterUnderTest = promoter(store, library)
            let canvas = try promoterUnderTest.promote(canvasID: id, now: anchor,
                                                       cleanup: { _ in throw 주입된실패() })

            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 1)
            #expect(canvas.renderedPNG == 렌더결과)
        }
    }
}

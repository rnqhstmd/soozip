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

/// `assetId`는 **반드시 UUID 문자열**이다 — `CanvasPhoto.id`가 그 값을 그대로
/// 받기 때문이다(선언부 계약). 문자열이 자유로우면 승격이 연결을 못 만든다.
///
/// `aspect` 기본값이 `.post`인 것에 기대지 마라 — **`.post`의 rawValue는 0이고
/// `Canvas.aspect`의 기본값도 0이라, `.post` 초안만 쓰면 "이관했다"와 "아예 안
/// 넣었다"가 같은 바이트를 낸다.** 종횡비를 재는 테스트는 `.story`를 써야 한다.
@MainActor
private func layout(assetIDs: [UUID] = [], texts: Int = 0,
                    aspect: CanvasAspect = .post) -> LayoutDocument {
    var layers: [Layer] = []
    for (i, assetID) in assetIDs.enumerated() {
        layers.append(.photo(PhotoLayer(assetId: assetID.uuidString,
                                        transform: 자리(i), filter: nil)))
    }
    for i in 0..<texts {
        layers.append(.text(TextLayer(string: "텍스트 \(i)", font: .pretendard,
                                      size: 48, color: "#000000", align: .left,
                                      transform: 자리(assetIDs.count + i))))
    }
    return LayoutDocument(aspect: aspect, layers: layers)
}

/// 사진 n장을 서로 다른 `assetId`로.
@MainActor
private func 사진들(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

/// 초안 하나를 만들고 사진 원본까지 써 둔다.
@MainActor
@discardableResult
private func 초안준비(_ store: DraftStore, collectionID: String, canvasID: String,
                    document: LayoutDocument, now: Date,
                    photoBytes: [String: Data] = [:],
                    aspect: CanvasAspect = .post) throws -> String {
    try store.create(canvasID: canvasID, collectionID: collectionID,
                     aspect: aspect, now: now)
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
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: assets, texts: 1), now: anchor,
                       photoBytes: [assets[0].uuidString: Data([1]),
                                    assets[1].uuidString: Data([2])])

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            // **초안 식별자가 그대로 캔버스 식별자가 된다**(CanvasPromoter 주석의 계약).
            // 이 줄이 없으면 `id: canvasUUID`를 `id: UUID()`로 바꿔도 전부 초록이다 —
            // 그러면 6단계가 초안을 지운 뒤 초안↔캔버스 대응이 영구히 사라지고,
            // 재편집이 원본을 못 찾는데 아무 신호도 없다.
            #expect(canvas.id == UUID(uuidString: id))
            #expect(canvas.collection?.id == a.id)
            #expect(canvas.renderedPNG == 렌더결과)
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 1)
        }
    }
}

@Test @MainActor func 초안의_종횡비가_캔버스로_이관된다() throws {
    // **`.story`여야 한다.** `.post`의 rawValue는 0이고 `Canvas.aspect`의 기본값도
    // 0이라, `.post` 초안으로는 `aspect: draft.meta.aspect`를 통째로 지워도 초록이다.
    //
    // 어긋나면 스토리(9:16) 캔버스가 4:5 좌표계로 열려 재렌더·재편집의 기하가
    // 조용히 바뀐다. `layoutJSON` 안의 aspect와 `Canvas.aspect`가 갈라진 채 남는다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(texts: 1, aspect: .story), now: anchor,
                       aspect: .story)

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(canvas.aspectPreset == .story)
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
            let asset = UUID()
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: [asset], texts: 2), now: anchor,
                       photoBytes: [asset.uuidString: Data([9])])
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
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: assets), now: anchor,
                       photoBytes: [assets[0].uuidString: Data([0xAA]),
                                    assets[1].uuidString: Data([0xBB])])

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
            let 공유 = UUID()
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: Array(repeating: 공유, count: 4)), now: anchor,
                       photoBytes: [공유.uuidString: Data([0xCC])])

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
                       document: layout(assetIDs: 사진들(9)), now: anchor)

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
                       document: layout(assetIDs: 사진들(9)), now: anchor)

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
                       document: layout(assetIDs: 사진들(1)), now: anchor)   // photoBytes 없음

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
            let 없는모음집 = UUID().uuidString
            try 초안준비(store, collectionID: 없는모음집, canvasID: id,
                       document: layout(texts: 1), now: anchor)

            // 에러가 **모음집** 식별자를 들어야 한다. 캔버스 식별자를 담으면
            // 호출부·로그가 엉뚱한 레코드를 가리킨다.
            #expect(throws: PromotionError.collectionNotFound(
                collectionID: 없는모음집)) {
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

            let canvas = try promoter(store, library)
                .promote(canvasID: id, now: anchor, cleanup: { _ in throw 주입된실패() })

            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 1)
            #expect(canvas.renderedPNG == 렌더결과)
            #expect(try store.load(canvasID: id) != nil)   // 초안은 남는다
        }
    }
}

// MARK: - 레이어 ↔ 사진 연결 (CanvasPhoto 선언부 계약)

@Test @MainActor func 레이어의_assetId로_그_레이어의_사진을_찾을_수_있다() throws {
    // **`CanvasPhoto` 선언부의 계약이다** — 레이어의 `assetId`가 이 `id`를 가리킨다.
    // 새 UUID를 발급하면 `layoutJSON`의 `assetId`가 아무것도 못 가리키고,
    // **저장된 데이터만으로는 어느 레이어가 어느 사진인지 복원할 수 없다.**
    //
    // 앞의 `사진_원본이_CanvasPhoto로_옮겨진다`는 집합 비교라 이걸 못 잡는다 —
    // 바이트가 다 있어도 연결이 끊겨 있을 수 있다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let 바이트: [UUID: Data] = [assets[0]: Data([0xA1]), assets[1]: Data([0xB2])]
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: assets), now: anchor,
                       photoBytes: Dictionary(uniqueKeysWithValues:
                        바이트.map { ($0.key.uuidString, $0.value) }))

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            // 저장된 것만으로 레이어 → 사진을 되짚는다.
            let saved = try JSONDecoder().decode(LayoutDocument.self, from: canvas.layoutJSON)
            let photos = try context.fetch(FetchDescriptor<CanvasPhoto>())
            for layer in saved.layers {
                guard case .photo(let photoLayer) = layer else { continue }
                let assetID = try #require(UUID(uuidString: photoLayer.assetId))
                let matched = try #require(photos.first { $0.id == assetID })
                #expect(matched.data == 바이트[assetID])
            }
        }
    }
}

// MARK: - CANVAS-3: 사진의 소유 관계

// **여기 위의 사진 테스트들은 전부 전역 조회다** — `fetch`/`fetchCount`.
// 바이트가 다 있고 개수가 맞아도 **어느 사진이 어느 캔버스 것인지는 안 잰다.**
//
// `LibraryRepositoryTests`의 cascade 테스트들도 못 잡는다. 그쪽은 `photo.canvas`를
// **테스트가 직접 걸고** 삭제를 재므로, 승격 경로가 그 관계를 거는지는 밖에 있다.
//
// 실측: `CanvasPromoter.attach`에서 `record.canvas = canvas`를 지우면 **이 타깃의
// 나머지가 전부 초록이었다.** 그동안 사진은 주인 없는 레코드가 되어 cascade가 안 닿고
// (`externalStorage`라 파일이 계속 쌓인다), `canvas.photos`가 비어 재편집이
// 사진을 못 찾는다.

@Test @MainActor func 승격된_사진은_그_캔버스에_속한다() throws {
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: assets), now: anchor,
                       photoBytes: [assets[0].uuidString: Data([0xAA]),
                                    assets[1].uuidString: Data([0xBB])])

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            // 전역이 아니라 **캔버스를 통해** 되짚는다.
            // `#require`는 게이트가 아니다 — `photos`의 기본값은 nil이 아니라 `[]`라
            // 빈 배열도 그대로 통과한다. 개수를 따로 잰다.
            let owned = try #require(canvas.photos)
            #expect(owned.count == 2)
            #expect(Set(owned.map(\.data)) == [Data([0xAA]), Data([0xBB])])
            // **캔버스를 통해 `assetId` 계약까지 되짚는 유일한 자리다.**
            // 334행의 되짚기 테스트는 전역 조회라 캔버스가 둘이면 남의 사진을 집는다.
            //
            // `owned.allSatisfy { $0.canvas?.id == canvas.id }`는 여기 두지 않는다 —
            // SwiftData가 역관계 일관성을 유지하므로 `canvas.photos`의 원소는 정의상
            // 그 캔버스를 가리킨다. 참이 될 수밖에 없는 줄은 이빨이 없다.
            #expect(Set(owned.map(\.id)) == Set(assets))
        }
    }
}

@Test @MainActor func 캔버스가_둘이면_각자의_사진만_갖는다() throws {
    // 캔버스가 하나뿐이면 전역 조회와 소유 조회가 같은 답을 낸다 —
    // **둘이어야 구분된다.**
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)

            let 첫자산 = UUID(), 첫초안 = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: 첫초안,
                       document: layout(assetIDs: [첫자산]), now: anchor,
                       photoBytes: [첫자산.uuidString: Data([0xAA])])

            let 둘째자산 = UUID(), 둘째초안 = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: 둘째초안,
                       document: layout(assetIDs: [둘째자산]), now: anchor,
                       photoBytes: [둘째자산.uuidString: Data([0xBB])])

            let 첫캔버스 = try promoter(store, library).promote(canvasID: 첫초안, now: anchor)
            let 둘째캔버스 = try promoter(store, library).promote(canvasID: 둘째초안, now: anchor)

            // **배열 `==`를 쓰지 않는다.** SwiftData의 to-many 순서는 보장되지 않아
            // (`LibraryRepository` 주석 참조) 사진을 한 장만 더 붙여도 간헐 실패한다.
            #expect(Set(try #require(첫캔버스.photos).map(\.data)) == [Data([0xAA])])
            #expect(Set(try #require(둘째캔버스.photos).map(\.data)) == [Data([0xBB])])
        }
    }
}

@Test @MainActor func 승격으로_만든_캔버스를_지우면_사진도_사라진다() throws {
    // cascade 규칙 자체는 `LibraryRepositoryTests`가 잰다. 여기서 재는 것은
    // **승격이 그 규칙이 닿을 관계를 실제로 거는가**다. 안 걸면 캔버스만
    // 사라지고 `externalStorage` 블롭이 영원히 남는다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: assets), now: anchor,
                       photoBytes: [assets[0].uuidString: Data([0xAA]),
                                    assets[1].uuidString: Data([0xBB])])

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)
            #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 2)

            try library.deleteCanvas(canvas)

            #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 0)
        }
    }
}

// MARK: - CANVAS-3b: 멱등성 가드

// `@Attribute(.unique)`는 CloudKit 제약상 못 쓴다. **중복을 막을 수 있는 곳이
// 승격 경로밖에 없다.**
//
// 두 번 승격되는 경로는 실재한다 — 6단계 정리는 실패해도 되돌리지 않으므로
// (설계상 수용) "캔버스는 저장됐는데 초안이 남은" 상태가 정상적으로 존재하고,
// 그때 "이어서 만들까요?" 배너가 이미 저장된 캔버스의 초안을 연다.

/// 1차 승격에서 6단계만 실패시켜 **초안이 남은 상태**를 만든다.
/// AC가 말하는 재승격의 실제 발생 조건이 이것이다.
@MainActor
private func 정리실패로_초안이_남은_승격(_ store: DraftStore, _ library: LibraryRepository,
                                 collectionID: String, canvasID: String,
                                 assets: [UUID], now: Date) throws {
    try 초안준비(store, collectionID: collectionID, canvasID: canvasID,
               document: layout(assetIDs: assets), now: now,
               photoBytes: [assets[0].uuidString: Data([0xAA]),
                            assets[1].uuidString: Data([0xBB])])
    try promoter(store, library).promote(canvasID: canvasID, now: now,
                                         cleanup: { _ in throw 주입된실패() })
}

@Test @MainActor func 이미_승격된_초안을_다시_승격하면_거부된다() throws {
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 정리실패로_초안이_남은_승격(store, library, collectionID: a.id.uuidString,
                                   canvasID: id, assets: assets, now: anchor)
            #expect(try store.load(canvasID: id) != nil)   // 재승격의 전제

            #expect(throws: PromotionError.alreadyPromoted(canvasID: id)) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }

            // **중복 레코드가 생기지 않는다.** 이게 요점이다 — 같은 id의 Canvas가
            // 둘이면 layoutJSON의 assetId로 사진을 되짚을 때 어느 쪽이 나올지 모른다.
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<CanvasPhoto>()) == 2)
        }
    }
}

@Test @MainActor func 재승격이_거부돼도_초안은_남는다() throws {
    // 이 도메인의 불변 계약 — 거부는 초안을 지울 이유가 아니다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 정리실패로_초안이_남은_승격(store, library, collectionID: a.id.uuidString,
                                   canvasID: id, assets: assets, now: anchor)

            #expect(throws: PromotionError.alreadyPromoted(canvasID: id)) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }

            #expect(try store.load(canvasID: id) != nil)
        }
    }
}

@Test @MainActor func 재승격은_렌더보다_먼저_거부된다() throws {
    // FR-2. 거부가 렌더·사진 읽기보다 뒤에 있으면 수 MB 렌더를 헛돌리고,
    // 더 나쁘게는 **거부하기 전에 뭔가를 이미 만들었을 수** 있다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let assets = 사진들(2)
            let id = UUID().uuidString
            try 정리실패로_초안이_남은_승격(store, library, collectionID: a.id.uuidString,
                                   canvasID: id, assets: assets, now: anchor)

            // 렌더러가 불리면 그 자리에서 다른 에러가 난다. alreadyPromoted가
            // 나온다는 것은 **렌더까지 가지도 않았다**는 뜻이다.
            let 부르면터지는렌더러 = promoter(store, library,
                                       render: { _ in throw 주입된실패() })
            #expect(throws: PromotionError.alreadyPromoted(canvasID: id)) {
                try 부르면터지는렌더러.promote(canvasID: id, now: anchor)
            }
        }
    }
}

// MARK: - 식별자 계약

@Test @MainActor func UUID가_아닌_초안_식별자는_거부된다() throws {
    // 조용히 새 UUID를 발급하면 승격 전후로 같은 캔버스가 다른 것이 되고,
    // 재편집이 원본을 못 찾는데 아무 신호도 없다.
    try withDraftStore { store in
        try withLibrary { library, context in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: "not-a-uuid",
                       document: layout(texts: 1), now: anchor)

            #expect(throws: PromotionError.malformedIdentifier("not-a-uuid")) {
                try promoter(store, library).promote(canvasID: "not-a-uuid", now: anchor)
            }
            #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
            #expect(try store.load(canvasID: "not-a-uuid") != nil)
        }
    }
}

// MARK: - AC-4: 레이아웃이 바이트 단위로 보존된다

@Test @MainActor func 저장된_레이아웃이_초안_파일과_바이트까지_같다() throws {
    // 디코딩 후 재인코딩하면 양쪽 인코더 설정(키 순서·날짜 표기)이 갈라지는 순간
    // 사용자가 만든 것과 다른 바이트가 저장된다. 값 비교로는 그걸 못 잡는다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let asset = UUID()
            let id = UUID().uuidString
            try 초안준비(store, collectionID: a.id.uuidString, canvasID: id,
                       document: layout(assetIDs: [asset], texts: 2), now: anchor,
                       photoBytes: [asset.uuidString: Data([9])])
            let 초안바이트 = try store.readLayoutData(canvasID: id)

            let canvas = try promoter(store, library).promote(canvasID: id, now: anchor)

            #expect(canvas.layoutJSON == 초안바이트)
        }
    }
}

// MARK: - 실패 어휘

@Test @MainActor func 레이아웃_파일이_없으면_승격_에러로_바뀐다() throws {
    // `DraftStoreError`를 그대로 흘리면 호출부가 `PromotionError`만 보고
    // 분기할 수 없다. 이 API의 실패 어휘는 하나여야 한다.
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let a = try library.createCollection(name: "여행", now: anchor)
            let id = UUID().uuidString
            // layout.json 없이 폴더와 메타만 만든다 (쓰다가 죽은 상태)
            try store.create(canvasID: id, collectionID: a.id.uuidString,
                             aspect: .post, now: anchor)

            #expect(throws: PromotionError.layoutUnreadable(canvasID: id)) {
                try promoter(store, library).promote(canvasID: id, now: anchor)
            }
            #expect(try store.load(canvasID: id) != nil)
        }
    }
}

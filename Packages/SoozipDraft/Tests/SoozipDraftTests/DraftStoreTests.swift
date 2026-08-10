import Testing
import Foundation
import SoozipLayout
@testable import SoozipDraft

// 각 테스트는 고유 임시 폴더에서 돈다. 루트를 주입받는 설계라 가능하다.
private func withTempStore(_ body: (DraftStore) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("soozip-draft-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try body(DraftStore(root: root))
}

private func sampleDoc() -> LayoutDocument {
    LayoutDocument(aspect: .post, layers: [
        .text(TextLayer(string: "초안", font: .pretendard, size: 40,
                        color: "#000000", align: .left,
                        transform: LayerTransform(x: 540, y: 675, z: 0)))
    ])
}

private let week: TimeInterval = 7 * 24 * 3600

// MARK: - 생성과 조회

@Test func 초안을_만들면_폴더와_메타가_생긴다() throws {
    try withTempStore { store in
        let now = Date(timeIntervalSince1970: 1_000_000)
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: now)

        let draft = try store.load(canvasID: "c1")
        #expect(draft != nil)
        #expect(draft?.meta.collectionID == "col1")
        #expect(draft?.meta.canvasID == "c1")
        #expect(draft?.meta.aspect == .post)
        #expect(draft?.meta.createdAt == now)
        #expect(draft?.meta.updatedAt == now)
    }
}

@Test func 없는_초안을_로드하면_nil이다() throws {
    try withTempStore { store in
        let loaded = try store.load(canvasID: "nope")
        #expect(loaded == nil)
    }
}

@Test func 초안_목록을_조회한다() throws {
    try withTempStore { store in
        let now = Date()
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: now)
        try store.create(canvasID: "c2", collectionID: "col2", aspect: .story, now: now)

        let all = try store.all()
        #expect(all.count == 2)
        #expect(Set(all.map(\.meta.canvasID)) == ["c1", "c2"])
    }
}

@Test func 모음집당_초안은_하나만_조회된다() throws {
    // v4 §6.5: 초안은 모음집당 1개. 다른 캔버스를 새로 만들려 하면 물어본다.
    try withTempStore { store in
        let now = Date()
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: now)
        try store.create(canvasID: "c2", collectionID: "col2", aspect: .post, now: now)

        let d1 = try store.draft(forCollection: "col1")
        let d2 = try store.draft(forCollection: "col2")
        let none = try store.draft(forCollection: "없는모음집")
        #expect(d1?.meta.canvasID == "c1")
        #expect(d2?.meta.canvasID == "c2")
        #expect(none == nil)
    }
}

// MARK: - layout.json

@Test func layout을_쓰고_읽으면_동일하다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        let doc = sampleDoc()
        try store.writeLayout(doc, canvasID: "c1", now: Date())

        let read = try store.readLayout(canvasID: "c1")
        #expect(read == doc)
    }
}

@Test func layout을_쓰면_updatedAt이_갱신된다() throws {
    try withTempStore { store in
        let created = Date(timeIntervalSince1970: 1_000_000)
        let edited = Date(timeIntervalSince1970: 1_000_500)
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: created)
        try store.writeLayout(sampleDoc(), canvasID: "c1", now: edited)

        let meta = try store.load(canvasID: "c1")?.meta
        #expect(meta?.createdAt == created)   // 생성 시각은 그대로
        #expect(meta?.updatedAt == edited)    // 수정 시각만 갱신
    }
}

@Test func layout을_덮어써도_마지막_내용이_남는다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        try store.writeLayout(LayoutDocument(aspect: .post, layers: []), canvasID: "c1", now: Date())
        let second = sampleDoc()
        try store.writeLayout(second, canvasID: "c1", now: Date())

        let read = try store.readLayout(canvasID: "c1")
        #expect(read == second)
    }
}

@Test func layout이_없는_초안을_읽으면_에러다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        #expect(throws: DraftStoreError.layoutNotFound(canvasID: "c1")) {
            try store.readLayout(canvasID: "c1")
        }
    }
}

@Test func 없는_초안에_layout을_쓰면_에러다() throws {
    try withTempStore { store in
        #expect(throws: DraftStoreError.draftNotFound(canvasID: "없음")) {
            try store.writeLayout(sampleDoc(), canvasID: "없음", now: Date())
        }
    }
}

// MARK: - 사진

@Test func 사진을_쓰고_읽으면_동일하다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02])
        try store.writePhoto(bytes, assetID: "a1", format: .jpeg, canvasID: "c1")

        let read = try store.readPhoto(assetID: "a1", canvasID: "c1")
        #expect(read == bytes)
    }
}

@Test func 투명_이미지는_png로_저장된다() throws {
    // v4 §5.12.3: 알파가 있으면 PNG, 없으면 JPEG. 확장자가 형식을 따라간다.
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        try store.writePhoto(Data([0x89, 0x50, 0x4E, 0x47]), assetID: "a1", format: .png, canvasID: "c1")

        let ids = try store.photoIDs(canvasID: "c1")
        let format = try store.photoFormat(assetID: "a1", canvasID: "c1")
        #expect(ids == ["a1"])
        #expect(format == .png)
    }
}

@Test func 사진_목록을_조회한다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        try store.writePhoto(Data([1]), assetID: "a1", format: .jpeg, canvasID: "c1")
        try store.writePhoto(Data([2]), assetID: "a2", format: .png, canvasID: "c1")
        try store.writePhoto(Data([3]), assetID: "a3", format: .jpeg, canvasID: "c1")

        let ids = try store.photoIDs(canvasID: "c1").sorted()
        #expect(ids == ["a1", "a2", "a3"])
    }
}

@Test func 사진은_디바운스_없이_즉시_기록된다() throws {
    // v4 §6.5: 사진 사본은 삽입 즉시 기록한다. 크래시로 사진이 날아가면
    // 레이아웃만 복구해도 의미가 없다. layout.json 없이도 사진이 남아야 한다.
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        try store.writePhoto(Data([1, 2, 3]), assetID: "a1", format: .jpeg, canvasID: "c1")

        let ids = try store.photoIDs(canvasID: "c1")
        #expect(ids == ["a1"])
        #expect(throws: DraftStoreError.layoutNotFound(canvasID: "c1")) {
            try store.readLayout(canvasID: "c1")
        }
    }
}

@Test func 없는_사진을_읽으면_에러다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        #expect(throws: DraftStoreError.photoNotFound(assetID: "없음", canvasID: "c1")) {
            try store.readPhoto(assetID: "없음", canvasID: "c1")
        }
    }
}

// MARK: - 삭제

@Test func 초안을_지우면_폴더가_통째로_사라진다() throws {
    try withTempStore { store in
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
        try store.writeLayout(sampleDoc(), canvasID: "c1", now: Date())
        try store.writePhoto(Data([1]), assetID: "a1", format: .jpeg, canvasID: "c1")

        try store.delete(canvasID: "c1")

        let loaded = try store.load(canvasID: "c1")
        let all = try store.all()
        #expect(loaded == nil)
        #expect(all.isEmpty)
    }
}

@Test func 없는_초안_삭제는_조용히_넘어간다() throws {
    // 승격 트랜잭션의 마지막 단계(6번)에서 호출된다. 이미 없다고 실패하면
    // 저장은 성공했는데 에러가 나는 이상한 상황이 된다.
    try withTempStore { store in
        try store.delete(canvasID: "없음")
    }
}

// MARK: - 고아 정리 (v4 §6.9)

@Test func 소속_모음집이_없으면_고아다() throws {
    try withTempStore { store in
        let now = Date()
        try store.create(canvasID: "c1", collectionID: "살아있음", aspect: .post, now: now)
        try store.create(canvasID: "c2", collectionID: "삭제된모음집", aspect: .post, now: now)

        let removed = try store.pruneOrphans(knownCollectionIDs: ["살아있음"],
                                             now: now, maxAge: week)
        let alive = try store.load(canvasID: "c1")
        let gone = try store.load(canvasID: "c2")

        #expect(removed == ["c2"])
        #expect(alive != nil)
        #expect(gone == nil)
    }
}

@Test func 칠일_넘게_방치되면_고아다() throws {
    try withTempStore { store in
        let old = Date(timeIntervalSince1970: 0)
        let now = old.addingTimeInterval(8 * 24 * 3600)   // 8일 후
        try store.create(canvasID: "old", collectionID: "col1", aspect: .post, now: old)
        try store.create(canvasID: "fresh", collectionID: "col1", aspect: .post, now: now)

        let removed = try store.pruneOrphans(knownCollectionIDs: ["col1"], now: now, maxAge: week)
        let fresh = try store.load(canvasID: "fresh")

        #expect(removed == ["old"])
        #expect(fresh != nil)
    }
}

@Test func 경계값_정확히_칠일은_남긴다() throws {
    try withTempStore { store in
        let created = Date(timeIntervalSince1970: 0)
        let now = created.addingTimeInterval(week)   // 정확히 7일
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: created)

        let removed = try store.pruneOrphans(knownCollectionIDs: ["col1"], now: now, maxAge: week)
        let alive = try store.load(canvasID: "c1")

        #expect(removed.isEmpty)
        #expect(alive != nil)
    }
}

@Test func 방치_기간은_생성이_아니라_수정_시각_기준이다() throws {
    // 오래 전에 만들었어도 어제 편집했으면 살아있는 초안이다.
    try withTempStore { store in
        let created = Date(timeIntervalSince1970: 0)
        let edited = created.addingTimeInterval(10 * 24 * 3600)
        let now = edited.addingTimeInterval(1 * 24 * 3600)   // 마지막 편집 1일 후

        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: created)
        try store.writeLayout(sampleDoc(), canvasID: "c1", now: edited)

        let removed = try store.pruneOrphans(knownCollectionIDs: ["col1"], now: now, maxAge: week)
        #expect(removed.isEmpty)
    }
}

@Test func 정리할_고아가_없으면_빈_배열이다() throws {
    try withTempStore { store in
        let now = Date()
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: now)
        let removed = try store.pruneOrphans(knownCollectionIDs: ["col1"], now: now, maxAge: week)
        #expect(removed.isEmpty)
    }
}

@Test func 손상된_메타를_가진_폴더도_고아로_정리된다() throws {
    // meta.json이 깨지면 소속도 시각도 알 수 없다. 남겨두면 영원히 안 지워진다.
    try withTempStore { store in
        let now = Date()
        try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: now)

        let broken = store.root.appendingPathComponent("broken")
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: broken.appendingPathComponent("meta.json"))

        let removed = try store.pruneOrphans(knownCollectionIDs: ["col1"], now: now, maxAge: week)
        let alive = try store.load(canvasID: "c1")

        #expect(removed == ["broken"])
        #expect(alive != nil)
    }
}

// MARK: - 루트 디렉토리

@Test func 루트가_없어도_생성이_동작한다() throws {
    // 첫 실행에는 Drafts 폴더 자체가 없다.
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("soozip-nonexistent-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }

    let store = DraftStore(root: root)
    let empty = try store.all()
    #expect(empty.isEmpty)   // 루트가 없어도 빈 목록

    try store.create(canvasID: "c1", collectionID: "col1", aspect: .post, now: Date())
    let after = try store.all()
    #expect(after.count == 1)
}

@Test func 루트가_없어도_고아정리는_조용히_넘어간다() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("soozip-nonexistent-\(UUID().uuidString)")
    let store = DraftStore(root: root)
    let removed = try store.pruneOrphans(knownCollectionIDs: [], now: Date(), maxAge: week)
    #expect(removed.isEmpty)
}

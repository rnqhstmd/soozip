import Testing
import Foundation
import SwiftData
import SoozipDraft
import SoozipLayout
@testable import Soozip

// DraftMaintenance — 앱 시작 시 고아 초안 정리 (AC-1~5).
//
// `DraftStore.pruneOrphans`의 판정 자체는 `Packages/SoozipDraft`가 이미 검증했다.
// 여기서 재는 것은 **그것을 부르는 자리의 안전성**이다: `knownCollectionIDs`가
// 비면 pruneOrphans는 전 초안을 고아로 판정한다. 조회 **실패**와 모음집이 정말
// **0개**인 것을 구분하지 못하면 사용자 작업물이 전량 삭제된다.

// MARK: - 하네스

/// 테스트마다 새 임시 폴더를 쓴다. 클로저를 벗어나면 지운다 —
/// 실패해도 남지 않도록 `defer`로 건다.
@MainActor
private func withDraftStore(_ body: (DraftStore) throws -> Void) throws {
    let root = URL.temporaryDirectory.appending(path: "soozip-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(DraftStore(root: root))
}

/// 초안 1개를 만든다. `updatedAt`을 직접 정해야 방치 기간을 잴 수 있어
/// `create`의 `now`를 그대로 쓴다(생성 시각 = 마지막 수정 시각).
@MainActor
@discardableResult
private func 초안생성(_ store: DraftStore, collectionID: String,
                    updatedAt: Date) throws -> String {
    let canvasID = UUID().uuidString
    try store.create(canvasID: canvasID, collectionID: collectionID,
                     aspect: .post, now: updatedAt)
    return canvasID
}

private struct 조회실패: Error {}

// MARK: - AC-1: 소속이 사라진 초안만 지운다

@Test @MainActor func 소속_모음집이_사라진_초안만_삭제된다() throws {
    try withDraftStore { store in
        let anchor = try testAnchor()
        let 살아있는모음집 = UUID().uuidString
        let 지워진모음집 = UUID().uuidString

        let 남을것 = try 초안생성(store, collectionID: 살아있는모음집, updatedAt: anchor)
        let 지울것 = try 초안생성(store, collectionID: 지워진모음집, updatedAt: anchor)

        let maintenance = DraftMaintenance(store: store,
                                           knownCollectionIDs: { [살아있는모음집] })
        let removed = try maintenance.pruneOrphanedDrafts(now: anchor)

        #expect(removed == [지울것])
        #expect(try store.load(canvasID: 남을것) != nil)
        #expect(try store.load(canvasID: 지울것) == nil)
    }
}

// MARK: - AC-2·3: 방치 기간 경계는 7일이다

@Test @MainActor func 마지막_수정_후_여드레_지난_초안은_삭제된다() throws {
    try withDraftStore { store in
        let anchor = try testAnchor()
        let 모음집 = UUID().uuidString
        let 오래된것 = try 초안생성(store, collectionID: 모음집,
                                updatedAt: try day(-8, from: anchor))

        let maintenance = DraftMaintenance(store: store, knownCollectionIDs: { [모음집] })
        let removed = try maintenance.pruneOrphanedDrafts(now: anchor)

        #expect(removed == [오래된것])
    }
}

@Test @MainActor func 마지막_수정_후_엿새_지난_초안은_남는다() throws {
    // 경계 양쪽을 다 재지 않으면 "전부 지우기"도 위 테스트를 통과한다.
    try withDraftStore { store in
        let anchor = try testAnchor()
        let 모음집 = UUID().uuidString
        let 최근것 = try 초안생성(store, collectionID: 모음집,
                              updatedAt: try day(-6, from: anchor))

        let maintenance = DraftMaintenance(store: store, knownCollectionIDs: { [모음집] })
        let removed = try maintenance.pruneOrphanedDrafts(now: anchor)

        #expect(removed.isEmpty)
        #expect(try store.load(canvasID: 최근것) != nil)
    }
}

// MARK: - AC-4: 조회 실패를 "모음집 0개"로 접지 않는다

@Test @MainActor func 모음집_조회가_실패하면_아무것도_지우지_않는다() throws {
    // **이 테스트가 이 작업의 존재 이유다.** 실패를 빈 Set으로 접으면
    // pruneOrphans가 전 초안을 고아로 판정해 사용자 작업물이 전량 사라진다.
    try withDraftStore { store in
        let anchor = try testAnchor()
        let a = try 초안생성(store, collectionID: UUID().uuidString, updatedAt: anchor)
        let b = try 초안생성(store, collectionID: UUID().uuidString, updatedAt: anchor)

        let maintenance = DraftMaintenance(store: store,
                                           knownCollectionIDs: { throw 조회실패() })

        #expect(throws: 조회실패.self) {
            try maintenance.pruneOrphanedDrafts(now: anchor)
        }
        #expect(try store.load(canvasID: a) != nil)
        #expect(try store.load(canvasID: b) != nil)
    }
}

// MARK: - AC-5: 모음집이 정말 0개면 초안은 고아가 맞다

@Test @MainActor func 모음집이_하나도_없으면_초안은_고아로_삭제된다() throws {
    // AC-4와 입력이 같아 보이지만(둘 다 아는 모음집이 없다) 정반대로 행동해야 한다.
    // 초안은 소속 없이 존재할 수 없으므로, 소속이 실재하지 않으면 고아다.
    try withDraftStore { store in
        let anchor = try testAnchor()
        let 고아 = try 초안생성(store, collectionID: UUID().uuidString, updatedAt: anchor)

        let maintenance = DraftMaintenance(store: store, knownCollectionIDs: { [] })
        let removed = try maintenance.pruneOrphanedDrafts(now: anchor)

        #expect(removed == [고아])
        #expect(try store.load(canvasID: 고아) == nil)
    }
}

// MARK: - 리포지토리 연결 — 식별자 표기가 어긋나면 전부 고아가 된다

@Test @MainActor func 리포지토리에서_받은_모음집_식별자로_초안이_보존된다() throws {
    // `UUID.uuidString`은 대문자를 내는데 `UUID(uuidString:)`은 소문자도 받는다.
    // Set 비교는 대소문자를 구분하므로, 초안의 collectionID와 리포지토리가 내는
    // 표기가 어긋나면 **살아있는 모음집의 초안이 전부 고아로 판정된다.**
    try withDraftStore { store in
        try withLibrary { library, _ in
            let anchor = try testAnchor()
            let 모음집 = try library.createCollection(name: "여행", now: anchor)
            let 초안 = try 초안생성(store, collectionID: 모음집.id.uuidString,
                                 updatedAt: anchor)

            let maintenance = DraftMaintenance(store: store, library: library)
            let removed = try maintenance.pruneOrphanedDrafts(now: anchor)

            #expect(removed.isEmpty)
            #expect(try store.load(canvasID: 초안) != nil)
        }
    }
}

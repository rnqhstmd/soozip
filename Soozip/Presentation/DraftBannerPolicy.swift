import Foundation
import SoozipDraft

/// 상세 화면 상단의 "이어서 만들까요?" 배너 노출 판정 (v4 §6.5).
///
/// 배너는 **그 모음집의 초안이 있을 때만** 뜬다. 초안은 모음집당 1개다.
@MainActor
struct DraftBannerPolicy {

    let store: DraftStore

    init(store: DraftStore) {
        self.store = store
    }

    /// 조회 실패는 던진다. 여기서 삼키면 초안이 있는데도 배너가 안 뜨고,
    /// 사용자는 만들던 것이 사라졌다고 읽는다.
    func shouldShow(for collection: Collection) throws -> Bool {
        try store.draft(forCollection: collection.id.uuidString) != nil
    }
}

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

    /// 조회 실패를 **삼키지 않고 던진다** — 실패와 "초안 없음"은 다른 사실이라
    /// 이 계층이 둘을 뭉개면 호출부가 구분할 길이 사라진다.
    ///
    /// 무엇을 할지는 호출부가 정한다. 화면은 지금 "배너를 띄우지 않는" 쪽을
    /// 택했다 — 없는 초안을 있다고 하면 눌렀을 때 아무것도 없어 사용자가 작업물이
    /// 사라졌다고 읽기 때문이다. 오류를 보여줄 자리가 생기면 그때 바뀔 수 있다.
    func shouldShow(for collection: Collection) throws -> Bool {
        try store.draft(forCollection: collection.id.uuidString) != nil
    }
}

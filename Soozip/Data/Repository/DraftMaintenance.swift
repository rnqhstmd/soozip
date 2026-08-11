import Foundation
import SoozipDraft

/// 고아 초안 정리. 앱 시작 시 1회 부른다 (v4 §6.9).
///
/// 판정 자체는 `DraftStore.pruneOrphans`가 이미 한다 — 이 타입이 하는 일은
/// **소속 목록을 안전하게 건네주는 것**뿐이다. 그게 왜 별도 타입인지는 아래.
///
/// 정리하지 않으면 사진 사본이 계속 쌓여 사용자가 원인을 알 수 없는 용량을 먹는다.
@MainActor
struct DraftMaintenance {

    /// 방치 판정 기준. **생성이 아니라 마지막 수정 기준**이라, 오래 전에 만들었어도
    /// 어제 편집했으면 살아있는 초안이다.
    static let defaultMaxAge: TimeInterval = 7 * 24 * 60 * 60

    let store: DraftStore

    /// 살아있는 모음집 식별자를 읽어 오는 경로.
    ///
    /// **리포지토리를 직접 들지 않고 클로저를 받는 이유**: `pruneOrphans`는 이
    /// 집합에 없는 소속의 초안을 지운다. 조회가 실패했을 때 빈 집합을 넘기면
    /// **전 초안이 고아로 판정되어 사용자 작업물이 통째로 사라진다.** 클로저면
    /// 그 실패 경로를 테스트가 주입해 재현할 수 있다 — 구체 `ModelContext`로는
    /// fetch 실패를 만들 수단이 없다.
    let knownCollectionIDs: () throws -> Set<String>

    init(store: DraftStore, knownCollectionIDs: @escaping () throws -> Set<String>) {
        self.store = store
        self.knownCollectionIDs = knownCollectionIDs
    }

    /// 앱에서 쓰는 경로. 소속 목록을 `LibraryRepository`에서 가져온다.
    ///
    /// `uuidString`으로 맞추는 것이 계약이다. `UUID.uuidString`은 대문자를 내는데
    /// `UUID(uuidString:)`은 소문자도 받아, 초안의 `collectionID`와 표기가 어긋나면
    /// **살아있는 모음집의 초안까지 고아로 판정된다.** 승격 트랜잭션(Phase 2)도
    /// 같은 표기로 초안을 만들어야 한다.
    init(store: DraftStore, library: LibraryRepository) {
        self.init(store: store) {
            Set(try library.collections().map { $0.id.uuidString })
        }
    }

    /// 고아 초안을 지우고 지운 캔버스 식별자를 돌려준다.
    ///
    /// **소속 조회가 실패하면 던진다.** 삼키고 빈 집합으로 진행하지 않는다 —
    /// 조회 실패와 "모음집이 정말 0개"는 결과가 정반대여야 한다. 전자는 아무것도
    /// 지우면 안 되고, 후자는 초안이 실제로 고아다(초안은 소속 없이 존재할 수 없다).
    @discardableResult
    func pruneOrphanedDrafts(now: Date,
                             maxAge: TimeInterval = DraftMaintenance.defaultMaxAge)
        throws -> [String] {
        let known = try knownCollectionIDs()
        return try store.pruneOrphans(knownCollectionIDs: known, now: now, maxAge: maxAge)
    }
}

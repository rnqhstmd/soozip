import Foundation
import SwiftData

/// 모음집과 캔버스의 영속성 계층.
///
/// 둘을 **한 애그리게이트로 묶은 이유**: 표지 정합성이 두 모델에 걸친 불변식이라,
/// 리포지토리를 모델별로 쪼개면 불변식이 두 타입의 협력에 걸리고 그 협력을 빠뜨린
/// 경로가 곧 QE-2 사고가 된다(v4 §6.7이 경고한 "원래 모음집 표지가 다른 모음집에
/// 있는 캔버스를 계속 가리킨다").
///
/// `@MainActor`인 이유: `ModelContext`와 `@Model`이 non-Sendable이라 액터 경계를
/// 넘지 못한다. 메인 액터에 고정하면 모델 객체를 그대로 반환할 수 있어 Phase 6의
/// `@Query`·`@Bindable`과 마찰이 없다. 무거운 쓰기(Phase 2의 사진 블롭)는 그때
/// 별도 `@ModelActor` 임포터로 떼면 되고, 이 타입은 블롭을 다루지 않는다.
@MainActor
struct LibraryRepository {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 모음집

    /// 모음집을 만든다. `sortIndex`는 기존 최댓값 + 1이라 **재배치 전에도
    /// 정렬 조회만으로 생성 순서가 성립**한다(FR-4).
    ///
    /// 중복 이름을 막지 않는다(AC-31). 사용자가 같은 이름을 원할 수 있고,
    /// `@Attribute(.unique)`는 CloudKit에서 쓸 수 없다(AC-2).
    @discardableResult
    func createCollection(name: String, now: Date) throws -> Collection {
        // 검증이 insert보다 먼저다. 뒤에 두면 거부된 입력의 부분 상태가 남는다.
        guard InputLimits.collectionName.contains(name.count) else {
            throw RepositoryError.collectionNameOutOfRange(
                length: name.count, allowed: InputLimits.collectionName)
        }

        let collection = Collection()
        collection.name = name
        collection.createdAt = now
        collection.sortIndex = try nextSortIndex()

        context.insert(collection)
        try context.save()
        return collection
    }

    /// 정렬 순서로 조회한다. 2차 키가 `createdAt`인 이유는 두 기기가 동시에 순서를
    /// 바꾸면 `sortIndex`가 겹칠 수 있기 때문이다 — 그때도 결과가 결정적이어야
    /// 한다(v4 §6.9 타이브레이크).
    func collections() throws -> [Collection] {
        try context.fetch(FetchDescriptor<Collection>(sortBy: [
            SortDescriptor(\.sortIndex, order: .forward),
            SortDescriptor(\.createdAt, order: .forward)
        ]))
    }

    // MARK: - 내부

    /// 다음 `sortIndex`. 첫 모음집은 0이다.
    ///
    /// 전량을 끌어와 `max`를 돌지 않는 이유: 모음집이 늘수록 느려진다.
    /// 역순 정렬 + `fetchLimit = 1`이면 한 건만 읽는다.
    private func nextSortIndex() throws -> Int {
        var descriptor = FetchDescriptor<Collection>(
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { $0.sortIndex + 1 } ?? 0
    }
}

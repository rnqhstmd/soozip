import Foundation
import SwiftData
import SoozipLayout

/// 캔버스 생성 입력. **`collectionID`를 담지 않는다** — 소속은 `in collection:`
/// 파라미터로만 들어오고, 소속 *변경*은 `moveCanvas` 하나뿐이다. 입력 구조체가
/// 소속을 들고 있으면 "제목만 고치는" 호출이 소속까지 바꿀 수 있게 된다.
struct CanvasInput: Equatable, Sendable {
    var id: UUID = UUID()
    var aspect: CanvasAspect
    var title: String = ""
    var createdAt: Date
    var layoutJSON: Data = Data()
    var renderedPNG: Data? = nil
}

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

    // MARK: - 캔버스

    /// 캔버스를 만들어 `collection`에 넣는다. 소속을 **받되 변경하지 않는다**.
    ///
    /// `input.createdAt`을 **보정 없이 그대로** 쓴다(AC-32, BR-3). 기록 날짜는
    /// 사용자가 정하는 값이라 미래여도 손대지 않는다 — `now`를 따르는 것은
    /// `updatedAt` 하나뿐이다.
    @discardableResult
    func createCanvas(_ input: CanvasInput, in collection: Collection, now: Date) throws -> Canvas {
        // 검증이 insert보다 먼저다. 뒤에 두면 거부된 입력의 부분 상태가 남는다.
        try validate(title: input.title)

        let canvas = Canvas()
        canvas.id = input.id            // 입력의 식별자를 그대로 쓴다 — Phase 2의
                                        // 초안 승격이 초안 식별자를 들고 온다
        canvas.aspectPreset = input.aspect
        canvas.title = input.title
        canvas.createdAt = input.createdAt
        canvas.updatedAt = now
        canvas.layoutJSON = input.layoutJSON
        canvas.renderedPNG = input.renderedPNG
        canvas.collection = collection

        context.insert(canvas)
        try applyThenReconcileCover(of: collection)
        return canvas
    }

    /// 캔버스의 메타를 고친다. **소속을 아예 받지 않는다** — 이동의 단일 경로는
    /// `moveCanvas`다.
    ///
    /// `renderedPNG`를 받지 않는 이유: 수 MB 블롭이라 제목만 고치는 호출에서도 다시
    /// 대입되면 레코드가 더티가 되어 CKAsset이 통째로 재업로드된다. 렌더 갱신은
    /// Phase 2 승격 트랜잭션 몫이다.
    func updateCanvas(_ canvas: Canvas, title: String, createdAt: Date,
                      layoutJSON: Data, now: Date) throws {
        try validate(title: title)

        canvas.title = title
        canvas.createdAt = createdAt
        canvas.layoutJSON = layoutJSON
        canvas.updatedAt = now

        // 갱신 경로에서도 재계산을 부른다. "모든 변경 뒤에 재계산"에 예외를 두지
        // 않으려는 것 — 예외가 곧 빠뜨릴 자리다.
        try applyThenReconcileCover(of: canvas.collection)
    }

    // MARK: - 내부

    /// 제목 길이 검증(AC-30, BR-7). 하한이 0이라 빈 제목은 통과한다 —
    /// 제목은 선택이고 비면 목록에서 날짜로 표시한다(BR-2).
    private func validate(title: String) throws {
        guard InputLimits.canvasTitle.contains(title.count) else {
            throw RepositoryError.canvasTitleOutOfRange(
                length: title.count, allowed: InputLimits.canvasTitle)
        }
    }

    /// **순서 고정: 변경 → save → reconcile → save.**
    ///
    /// 두 번 저장하는 것이 낭비로 보이지만, 표지 재계산의 후보 목록은 `fetch`로
    /// 얻는데 그 결과가 첫 `save()` 전까지 방금의 변경을 반영하지 않는다(실측).
    /// "save 두 번을 하나로 합치자"는 평범한 리팩터가 곧 유령 표지를 만든다.
    private func applyThenReconcileCover(of collection: Collection?) throws {
        try context.save()
        guard let collection else { return }
        reconcileCover(of: collection)
        try context.save()
    }

    /// 표지 재계산. 후보 목록을 만들어 `CoverPolicy`에 넘기는 것이 전부다 —
    /// 판정 자체는 순수 함수 한 곳에만 있다.
    private func reconcileCover(of collection: Collection) {
        CoverPolicy.reconcile(collection, candidates: canvasesFetched(in: collection))
    }

    /// 후보 목록의 유일한 출처.
    ///
    /// 관계 배열(`collection.canvases`)이 아니라 `fetch`를 쓴다.
    /// **실측: to-many 관계 배열은 `save()` 전까지 삭제·이동을 반영하지 않지만
    /// fetch는 즉시 반영한다.** 이 비대칭이 유령 표지의 원천이라, 조회를 저장
    /// 시점에 의존시키지 않으려고 느린 쪽을 택했다.
    ///
    /// `#Predicate`로 옵셔널 관계를 경유해 비교하는 것은 iOS 17에서 불안정하다는
    /// 보고가 있어 피한다.
    private func canvasesFetched(in collection: Collection) -> [Canvas] {
        let owner = collection.id
        let all = (try? context.fetch(FetchDescriptor<Canvas>())) ?? []
        return all.filter { $0.collection?.id == owner }
    }

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

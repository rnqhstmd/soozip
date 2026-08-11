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

/// 캔버스 목록 정렬 기준 (FR-6). 키는 기록 날짜(`createdAt`)이지 저장 시각이 아니다 —
/// 사용자가 정한 날짜가 목록 순서를 정한다.
enum CanvasOrder: Sendable { case newestFirst, oldestFirst }

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

    /// 모음집을 지운다. 소속 캔버스와 그 사진은 `deleteRule: .cascade`가 전이로
    /// 지운다(AC-16) — 리포지토리가 자식을 손수 훑지 않는다.
    ///
    /// **표지 재계산이 없다.** 모음집 자체가 사라지므로 재계산할 대상이 없다.
    func deleteCollection(_ collection: Collection) throws {
        context.delete(collection)
        try context.save()
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

    /// 캔버스를 지우고 소속 모음집의 표지를 다시 계산한다(AC-8·9·10).
    /// 사진은 `deleteRule: .cascade`가 지운다(AC-17).
    func deleteCanvas(_ canvas: Canvas) throws {
        // 삭제 후에도 `canvas.collection`은 non-nil로 살아 있다(실측 — `isDeleted`도
        // false다). 그래도 먼저 잡는 이유는 삭제된 객체의 속성 접근에 의존하지
        // 않기 위해서다.
        let owner = canvas.collection

        context.delete(canvas)
        try applyThenReconcileCover(of: owner)
    }

    /// 캔버스를 다른 모음집으로 옮긴다. **소속 변경의 단일 경로다** —
    /// `createCanvas`는 소속을 받되 바꾸지 않고, `updateCanvas`는 아예 받지 않는다.
    ///
    /// 원본과 목적지 **양쪽**을 재계산한다(AC-11·12·13). 한쪽만 하면 초안 설계가
    /// 냈던 "표지=C1인데 소속 캔버스 0장"이 그대로 재현된다.
    func moveCanvas(_ canvas: Canvas, to destination: Collection) throws {
        let origin = canvas.collection
        // 같은 모음집이면 즉시 빠진다. 그냥 진행해도 결과는 같지만 Collection
        // 레코드를 헛되이 더티로 만들 이유가 없다.
        guard origin?.id != destination.id else { return }

        canvas.collection = destination
        try applyThenReconcileCover(of: origin, destination)
    }

    // MARK: - 조회

    /// 모음집의 캔버스 목록. **읽기 전용이다.**
    func canvases(in collection: Collection, order: CanvasOrder = .newestFirst) -> [Canvas] {
        // 2차 키가 `id`인 이유는 `CoverPolicy.resolve`와 같다 — 기록 날짜가 같은
        // 캔버스가 둘이면 순서가 배열 순서에 의존하는데 SwiftData의 to-many 순서는
        // 보장되지 않아 같은 데이터에서 목록이 실행마다 뒤집힌다.
        let oldestFirst = canvasesForDisplay(in: collection).sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }
        switch order {
        case .oldestFirst: return oldestFirst
        case .newestFirst: return oldestFirst.reversed()
        }
    }

    /// 표지 캔버스. **읽기 전용이다** — 저장된 식별자가 유령이어도 고쳐 쓰지 않고
    /// 폴백 결과만 돌려준다(AC-18, FR-11). 조회가 슬쩍 쓰면 `@Query`가 도는
    /// 화면에서 스크롤만 해도 쓰기가 발생한다.
    func coverCanvas(of collection: Collection) -> Canvas? {
        CoverPolicy.resolve(in: canvasesForDisplay(in: collection),
                            coverID: collection.coverCanvasID)
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
    ///
    /// 여러 모음집을 받는 이유는 `moveCanvas`가 원본·목적지 양쪽을 재계산해야
    /// 하기 때문이다. **순서 고정을 이 한 곳에만 두면 호출부가 그것을 틀릴 수 없다.**
    private func applyThenReconcileCover(of collections: Collection?...) throws {
        try context.save()

        var done: Set<UUID> = []
        for collection in collections.compactMap({ $0 }) where done.insert(collection.id).inserted {
            try reconcileCover(of: collection)
        }
        try context.save()
    }

    /// 표지 재계산. 후보 목록을 만들어 `CoverPolicy`에 넘기는 것이 전부다 —
    /// 판정 자체는 순수 함수 한 곳에만 있다.
    ///
    /// **여기서 fetch 실패를 삼키면 안 된다.** 후보 0장은 "캔버스가 없다"는 뜻이고
    /// `CoverPolicy.reconcile`은 그걸 보고 표지를 빈 문자열로 만든다(BR-4).
    /// 조회가 실패했을 뿐인데 표지가 지워지는 것 — 던져서 호출부가 쓰기를
    /// 통째로 포기하게 두는 편이 낫다.
    private func reconcileCover(of collection: Collection) throws {
        CoverPolicy.reconcile(collection, candidates: try canvasesFetched(in: collection))
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
    private func canvasesFetched(in collection: Collection) throws -> [Canvas] {
        let owner = collection.id
        return try context.fetch(FetchDescriptor<Canvas>())
            .filter { $0.collection?.id == owner }
    }

    /// 읽기 전용 경로용. **여기서는 실패를 빈 목록으로 접는다** — 목록이 잠시
    /// 비어 보이는 것은 화면이 감당할 수 있고, 읽기가 던지면 `@Query`가 도는
    /// 화면마다 오류 처리가 번진다. 쓰기 경로가 이 함수를 쓰지 않는 것이 요점이다.
    private func canvasesForDisplay(in collection: Collection) -> [Canvas] {
        (try? canvasesFetched(in: collection)) ?? []
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

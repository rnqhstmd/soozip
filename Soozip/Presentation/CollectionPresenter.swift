import Foundation
import SwiftData

/// 카드에 그릴 표지.
///
/// `.image`는 **디코딩 가능이 확인된** 데이터만 담는다. 뷰가 다시 판정하지 않도록
/// 여기서 이미 걸러 두는 것이 요점이다 — 뷰가 판정하면 그 분기는 테스트 밖이 된다.
enum CoverArt: Equatable {
    case image(Data)
    /// 연한 단색 카드. 캔버스가 없거나, 표지 이미지를 그릴 수 없을 때(BR-3).
    case empty
}

/// 모음집 카드 하나가 그릴 값 전부.
struct CollectionCard: Equatable, Identifiable {
    let id: UUID
    let name: String
    let canvasCount: Int
    let cover: CoverArt
}

/// 캐러셀 항목. 맨 좌측 `[+]`가 **데이터의 일부**다.
///
/// 뷰가 `[+]`를 알아서 앞에 붙이게 두면 "맨 좌측 고정"이 테스트 밖 규칙이 된다.
enum CarouselItem: Equatable, Identifiable {
    case newCollection
    case collection(CollectionCard)

    var id: String {
        switch self {
        case .newCollection: return "new-collection"
        case .collection(let card): return card.id.uuidString
        }
    }
}

/// 모델을 화면 표시값으로 바꾼다.
///
/// **이 계층이 있는 이유**: 이 저장소에는 UI 테스트 수단이 없다. 분기·계산·폴백을
/// 전부 뷰 밖으로 빼야 검증이 닿는다. 뷰에 `if`가 늘면 그만큼 검증 밖으로 새는
/// 것이므로, 여기서 못 재는 표시 규칙이 생기면 설계가 틀린 신호다.
@MainActor
struct CollectionPresenter {

    let library: LibraryRepository

    /// 이미지 디코딩 가능 여부. 앱은 `{ UIImage(data: $0) != nil }`를 넘긴다.
    ///
    /// **주입받는 이유**: 프레젠터가 `UIImage`를 직접 부르면 순수성이 깨지고,
    /// 뷰가 부르면 "디코딩 실패 시 단색 폴백"(BR-3)을 테스트가 잴 수 없다.
    /// `DraftMaintenance`가 조회 실패를 주입받은 것과 같은 이유다.
    let canDecodeImage: (Data) -> Bool

    init(library: LibraryRepository, canDecodeImage: @escaping (Data) -> Bool) {
        self.library = library
        self.canDecodeImage = canDecodeImage
    }

    /// 정렬 순서의 모음집 카드. 「전체 보기」가 이걸 그대로 쓴다.
    func cards() throws -> [CollectionCard] {
        try library.collections().map(card(for:))
    }

    /// 캐러셀 항목. `[+]`가 항상 맨 앞이다.
    func carouselItems() throws -> [CarouselItem] {
        [.newCollection] + (try cards()).map(CarouselItem.collection)
    }

    /// 카드 하나. **던지지 않는다** — 표시 경로라 조회 실패를 빈 목록으로 접는다.
    /// 목록이 잠시 비어 보이는 것은 화면이 감당할 수 있고, 여기서 던지면
    /// `@Query`가 도는 화면마다 오류 처리가 번진다.
    func card(for collection: Collection) -> CollectionCard {
        let canvases = library.canvases(in: collection)
        return CollectionCard(
            id: collection.id,
            name: collection.name,
            canvasCount: canvases.count,
            cover: coverArt(of: collection, among: canvases))
    }

    /// 상세 화면의 캔버스 목록. 정렬 자체는 리포지토리가 한다 —
    /// 여기서 다시 정렬하면 목록 순서 규칙이 두 곳으로 갈라진다.
    func canvases(in collection: Collection,
                  order: CanvasOrder = .newestFirst) -> [Canvas] {
        library.canvases(in: collection, order: order)
    }

    // MARK: - 내부

    /// 표지 폴백 3단계: 지정 → 최근 → 단색.
    ///
    /// 앞의 두 단계는 `CoverPolicy.resolve`가 이미 한다 — 여기서 다시 짜면 화면과
    /// 저장소의 표지 판정이 갈라진다. 세 번째 단계만 이 계층의 몫이다.
    ///
    /// **고른 캔버스에 그릴 것이 없어도 다음 후보로 넘어가지 않는다.** 넘어가면
    /// "표지로 지정했는데 다른 그림이 나오는" 상태가 된다.
    private func coverArt(of collection: Collection, among canvases: [Canvas]) -> CoverArt {
        guard let chosen = CoverPolicy.resolve(in: canvases,
                                               coverID: collection.coverCanvasID),
              let data = chosen.renderedPNG,
              canDecodeImage(data)
        else { return .empty }
        return .image(data)
    }
}

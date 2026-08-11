import SwiftUI
import SwiftData
import UIKit

extension CollectionPresenter {
    /// 앱이 쓰는 프레젠터. **디코딩 판정을 여기서 주입한다** — 프레젠터 자체는
    /// UIKit을 모르고, 그래서 테스트가 실패를 주입해 폴백을 잴 수 있다.
    @MainActor
    static func app(context: ModelContext) -> CollectionPresenter {
        CollectionPresenter(library: LibraryRepository(context: context),
                            canDecodeImage: { UIImage(data: $0) != nil })
    }
}

/// 모음집 카드 한 장.
///
/// **표시값을 받아 그리기만 한다.** 무엇을 보여줄지는 `CollectionPresenter`가
/// 이미 정했다 — 여기서 판단이 늘면 그만큼 테스트 밖으로 새는 것이다.
struct CollectionCardView: View {

    let card: CollectionCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .frame(width: Self.width, height: Self.coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(card.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("캔버스 \(card.canvasCount)장")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: Self.width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), 캔버스 \(card.canvasCount)장")
    }

    @ViewBuilder
    private var cover: some View {
        switch card.cover {
        case .image(let data):
            // 프레젠터가 디코딩 가능을 확인한 데이터만 넘긴다. 그래도 옵셔널
            // 언래핑이 필요한 것은 `UIImage(data:)`의 시그니처 탓이고,
            // 여기서 nil이면 같은 폴백으로 떨어진다.
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                emptyCover
            }
        case .empty:
            emptyCover
        }
    }

    /// 캔버스가 없거나 표지를 그릴 수 없을 때의 연한 단색 카드(BR-3).
    private var emptyCover: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
    }

    static let width: CGFloat = 150
    static let coverHeight: CGFloat = 188   // 4:5
}

/// 캐러셀 맨 좌측에 고정되는 [+] 카드.
struct NewCollectionCardView: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                Text("새 모음집")
                    .font(.subheadline.weight(.medium))
            }
            .frame(width: CollectionCardView.width,
                   height: CollectionCardView.coverHeight)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 모음집 만들기")
    }
}

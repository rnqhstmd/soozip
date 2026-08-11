import SwiftUI
import SwiftData
import SoozipDraft
import UIKit

/// 모음집 상세 — 캔버스 그리드 + 초안 배너 (v4 §2.2).
struct CollectionDetailView: View {

    let collection: Collection

    @Environment(\.modelContext) private var context
    @State private var order: CanvasOrder = .newestFirst
    @State private var hasDraft = false

    private var presenter: CollectionPresenter { .app(context: context) }

    var body: some View {
        ScrollView {
            if hasDraft { draftBanner }
            grid
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { orderMenu }
            ToolbarItem(placement: .topBarTrailing) { addCanvasButton }
        }
        .task { refreshDraftBanner() }
    }

    // MARK: - 캔버스 그리드

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
            ForEach(presenter.canvases(in: collection, order: order)) { canvas in
                CanvasThumbnail(canvas: canvas)
            }
        }
        .padding(16)
    }

    private var orderMenu: some View {
        Menu {
            Picker("정렬", selection: $order) {
                Text("최신순").tag(CanvasOrder.newestFirst)
                Text("오래된순").tag(CanvasOrder.oldestFirst)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("정렬 순서")
    }

    /// 캔버스 추가는 **에디터(Phase 3)의 몫**이다. 눌러도 아무 일이 없는 버튼보다
    /// 비활성이 정직하다 — 사용자가 고장으로 읽지 않는다.
    private var addCanvasButton: some View {
        Button { } label: { Image(systemName: "plus") }
            .disabled(true)
            .accessibilityLabel("캔버스 추가 (준비 중)")
    }

    // MARK: - 초안 배너

    private var draftBanner: some View {
        HStack {
            Image(systemName: "pencil.line")
            Text("이어서 만들까요?")
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    /// 실패하면 배너를 띄우지 않는다. 없는 초안을 있다고 하는 쪽이 더 나쁘다 —
    /// 눌렀는데 아무것도 없으면 사용자는 작업물이 사라졌다고 읽는다.
    private func refreshDraftBanner() {
        hasDraft = (try? DraftBannerPolicy(store: .appDefault).shouldShow(for: collection)) ?? false
    }
}

/// 캔버스 그리드의 한 칸.
private struct CanvasThumbnail: View {

    let canvas: Canvas

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnail
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(canvas.title.isEmpty ? .secondary : .primary)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = canvas.renderedPNG, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground))
        }
    }

    /// 무제목 캔버스는 기록 날짜로 표시한다(v4 §5.14).
    private var title: String {
        canvas.title.isEmpty
            ? canvas.createdAt.formatted(date: .abbreviated, time: .omitted)
            : canvas.title
    }
}

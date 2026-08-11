import SwiftUI
import SwiftData

/// 앱 첫 화면. 모음집 가로 캐러셀 (v4 §2.2).
struct CollectionHomeView: View {

    @Environment(\.modelContext) private var context

    // 정렬 두 키는 리포지토리의 `collections()`와 같다. 두 곳이 어긋나면 화면과
    // 저장소가 다른 순서를 말하게 된다.
    @Query(sort: [SortDescriptor(\Collection.sortIndex, order: .forward),
                  SortDescriptor(\Collection.createdAt, order: .forward)])
    private var collections: [Collection]

    @AppStorage("ghostHintDismissed") private var ghostHintDismissed = false

    @State private var creating = false
    @State private var renaming: Collection?
    @State private var deleting: Collection?
    @State private var showingAll = false
    @State private var failure: String?

    private var presenter: CollectionPresenter { .app(context: context) }
    private var repository: LibraryRepository { LibraryRepository(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                carousel
                // 힌트를 화면 중앙 오버레이가 아니라 **캐러셀 바로 아래**에 둔다.
                // 오버레이로 띄우면 [+] 카드와 멀찍이 떨어져, 무엇을 가리키는
                // 힌트인지 읽히지 않는다(시뮬레이터 실측).
                ghostHint
                if !collections.isEmpty { allCollectionsLink }
            }
            .navigationTitle("모음집")
            .spikeMenuToolbar()
            .sheet(isPresented: $creating) { createSheet }
            .sheet(item: $renaming) { renameSheet(for: $0) }
            .navigationDestination(isPresented: $showingAll) {
                CollectionGridView()
            }
            .confirmationDialog(deletionTitle,
                                isPresented: deletionDialogBinding,
                                titleVisibility: .visible) {
                deletionActions
            } message: {
                if let message = deletionPrompt?.message { Text(message) }
            }
            .alert("변경하지 못했습니다", isPresented: failureAlertBinding) {
                Button("확인", role: .cancel) { failure = nil }
            } message: {
                if let failure { Text(failure) }
            }
        }
    }

    /// **`.constant`를 쓰지 않는다.** 상수 바인딩은 SwiftUI가 닫을 때 쓰는
    /// `false`를 삼켜, 두 버튼을 거치지 않는 모든 닫기 경로(VoiceOver 이스케이프,
    /// 하드웨어 Esc, 시스템 강제 해제)에서 `deleting`이 남는다. 그러면 다음 본문
    /// 평가에서 같은 다이얼로그가 다시 떠 **사용자가 빠져나올 수 없다.**
    private var deletionDialogBinding: Binding<Bool> {
        Binding(get: { deleting != nil },
                set: { if !$0 { deleting = nil } })
    }

    private var failureAlertBinding: Binding<Bool> {
        Binding(get: { failure != nil },
                set: { if !$0 { failure = nil } })
    }

    // MARK: - 캐러셀

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                // 항목 목록을 프레젠터가 만든다 — [+]의 위치가 뷰의 재량이면
                // "맨 좌측 고정"이 테스트 밖 규칙이 된다.
                ForEach(presenter.carouselItems(for: collections)) { item in
                    switch item {
                    case .newCollection:
                        NewCollectionCardView { creating = true }
                    case .collection(let card):
                        cardLink(card)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func cardLink(_ card: CollectionCard) -> some View {
        if let collection = collections.first(where: { $0.id == card.id }) {
            NavigationLink {
                CollectionDetailView(collection: collection)
            } label: {
                CollectionCardView(card: card)
            }
            .buttonStyle(.plain)
            .contextMenu { contextActions(for: collection) }
        }
    }

    @ViewBuilder
    private func contextActions(for collection: Collection) -> some View {
        Button { renaming = collection } label: { Label("이름 변경", systemImage: "pencil") }
        Button { showingAll = true } label: { Label("순서 이동", systemImage: "arrow.up.arrow.down") }
        Button(role: .destructive) { deleting = collection } label: {
            Label("삭제", systemImage: "trash")
        }
    }

    private var allCollectionsLink: some View {
        Button { showingAll = true } label: {
            Label("전체 보기", systemImage: "square.grid.2x2")
        }
        .padding(.top, 8)
    }

    // MARK: - 첫 실행 고스트 힌트 (§12)

    @ViewBuilder
    private var ghostHint: some View {
        if GhostHintPolicy(hasDismissed: ghostHintDismissed)
            .shouldShow(collectionCount: collections.count) {
            Text("첫 모음집을 만들어보세요")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(24)
                .contentShape(Rectangle())
                .onTapGesture { ghostHintDismissed = true }
                .accessibilityHint("탭하면 사라집니다")
        }
    }

    // MARK: - 시트

    private var createSheet: some View {
        CollectionEditSheet(mode: .create) { name in
            // 생성 즉시 상세로 진입하는 것이 v4 §4의 규칙이지만, 그 이동은
            // Phase 3의 에디터 진입과 함께 다룬다 — 지금은 캐러셀에 추가만 한다.
            try repository.createCollection(name: name, now: Date())

            // **모음집을 만든 것도 힌트를 본 것이다.** 탭해서 닫을 때만 기록하면,
            // 힌트를 무시하고 [+]를 누른 사용자는 `hasDismissed`가 false로 남아
            // 나중에 모음집을 전부 지웠을 때 힌트가 되살아난다 — `GhostHintPolicy`
            // 주석이 금지한 바로 그 동작이다. 정책은 맞았고 배선이 빠져 있었다.
            ghostHintDismissed = true
        }
    }

    private func renameSheet(for collection: Collection) -> some View {
        CollectionEditSheet(mode: .rename(current: collection.name)) { name in
            try repository.renameCollection(collection, to: name)
        }
    }

    // MARK: - 삭제

    private var deletionPrompt: DeletionPrompt? {
        deleting.map { DeletionPrompt.forCollection(canvasCount: presenter.canvases(in: $0).count) }
    }

    private var deletionTitle: String {
        deleting.map { "\($0.name) 삭제" } ?? "삭제"
    }

    @ViewBuilder
    private var deletionActions: some View {
        Button("삭제", role: .destructive) {
            if let target = deleting {
                do { try repository.deleteCollection(target) }
                catch { failure = "삭제하지 못했습니다." }
            }
            deleting = nil
        }
        Button("취소", role: .cancel) { deleting = nil }
    }

}

/// 「전체 보기」 — 캐러셀이 길어졌을 때의 탈출구이자 **순서 재배치의 자리**다.
///
/// 재배치를 여기 둔 이유: v4는 캐러셀에서 길게 눌러 끄는 것을 말하지만, 가로
/// 스크롤에서의 드래그 재정렬은 SwiftUI 기본 도구로 만들 수 없다. `List`의
/// `onMove`가 접근성·햅틱까지 공짜로 주므로 우선 여기에 붙인다.
/// **가로 캐러셀 재배치는 Phase 6 후속 과제로 남긴다.**
struct CollectionGridView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Collection.sortIndex, order: .forward),
                  SortDescriptor(\Collection.createdAt, order: .forward)])
    private var collections: [Collection]

    @State private var failure: String?

    private var presenter: CollectionPresenter { .app(context: context) }

    var body: some View {
        List {
            ForEach(presenter.cards(for: collections)) { card in
                if let collection = collections.first(where: { $0.id == card.id }) {
                    NavigationLink {
                        CollectionDetailView(collection: collection)
                    } label: {
                        HStack(spacing: 12) {
                            CollectionCardView(card: card)
                                .scaleEffect(0.5, anchor: .leading)
                                .frame(width: CollectionCardView.width * 0.5)
                        }
                    }
                }
            }
            .onMove(perform: move)
        }
        .navigationTitle("전체 보기")
        .toolbar { EditButton() }
        .alert("순서를 저장하지 못했습니다", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인", role: .cancel) { failure = nil }
        } message: {
            if let failure { Text(failure) }
        }
    }

    /// 보이는 순서를 그대로 넘긴다. `sortIndex` 재계산은 리포지토리 몫이다.
    ///
    /// 실패를 삼키지 않는 이유: `List`는 이미 행을 옮겨 놓았는데 `sortIndex`는
    /// 그대로라, 다음 `@Query` 갱신에 **아무 설명 없이 순서가 되돌아간다.**
    /// 사용자는 앱이 고장 났다고 읽는다.
    private func move(from source: IndexSet, to destination: Int) {
        var ordered = collections
        ordered.move(fromOffsets: source, toOffset: destination)
        do {
            try LibraryRepository(context: context).reorderCollections(ordered)
        } catch {
            failure = "다시 시도해주세요. 목록은 저장된 순서로 되돌아갑니다."
        }
    }
}

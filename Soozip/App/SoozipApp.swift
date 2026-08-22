import SwiftUI
import SwiftData
import SoozipDraft

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 6부터 여기가 정식 첫 화면이다.
            //
            // 스파이크는 지운 것이 아니라 `#if DEBUG` 진입점(`SpikeMenu`)으로
            // 옮겼다 — 로드맵이 측정 전 삭제를 금지했고, 측정하려면 실행
            // 가능해야 하며, 릴리스 빌드에 실려서도 안 되기 때문이다. **S1은
            // `EDITOR-10`이 측정을 마치고 이미 지웠다** — 지금 남은 것은
            // S2뿐이다(`SpikeMenu.swift` 참고).
            CollectionHomeView()
                .pruneOrphanedDraftsOnLaunch()
        }
        // 앱 컨테이너는 정식 스키마만 싣는다. 목록을 여기 직접 적지 않는 이유는
        // 앱 배선·테스트 컨테이너·스키마 검사가 **같은 목록**을 봐야 하기 때문이다 —
        // 한 곳만 어긋나면 관계가 통째로 깨지는데 증상이 런타임에야 나온다.
        .modelContainer(for: SoozipSchema.models)
    }
}

extension DraftStore {
    /// 앱이 쓰는 초안 폴더. **`Application Support` 아래**라 사용자에게 보이지 않고
    /// iCloud 동기화 대상도 아니다(v4 §6.2).
    ///
    /// 경로를 한 곳에 둔 이유: 쓰는 곳과 지우는 곳이 어긋나면 정리가 조용히
    /// 아무 일도 안 하거나, 엉뚱한 폴더를 지운다. Phase 2의 승격 트랜잭션도
    /// 여기를 쓴다.
    static var appDefault: DraftStore {
        DraftStore(root: URL.applicationSupportDirectory.appending(path: "Drafts"))
    }
}

private struct PruneOrphanedDraftsOnLaunch: ViewModifier {

    /// 프로세스당 1회를 보장하는 빗장.
    ///
    /// **`.task`만으로는 "앱 시작 시 1회"가 아니다.** 뷰가 다시 나타나거나 씬이
    /// 재연결되면 다시 돈다. 정리는 파일을 지우는 동작이고, `DraftStore.create`는
    /// 폴더를 만든 뒤 `meta.json`을 쓰기까지 틈이 있다 — 그 틈에 정리가 끼어들면
    /// 메타를 못 읽어 **사용자가 지금 만들고 있는 초안을 고아로 보고 지운다.**
    /// 지금은 루트가 정적 프로브라 우연히 1회지만, Phase 3이 실제 화면을 끼우면
    /// 재진입이 열린다.
    @MainActor private static var hasRun = false

    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.task {
            guard !Self.hasRun else { return }
            Self.hasRun = true

            let maintenance = DraftMaintenance(
                store: .appDefault,
                library: LibraryRepository(context: context))
            do {
                try maintenance.pruneOrphanedDrafts(now: Date())
            } catch {
                // **삼키는 것이 맞는 자리다.** 여기까지 올라온 에러는 대부분 모음집
                // 조회 실패이고, 그때 해야 할 일은 정확히 "아무것도 지우지 않기"다.
                // 정리는 부수 작업이라 실패해도 앱은 정상 동작해야 하고, 다음 실행에
                // 다시 시도한다. 사용자에게 보여줄 것도 없다.
            }
        }
    }
}

private extension View {
    /// 앱 시작 시 고아 초안을 1회 정리한다(v4 §6.9).
    ///
    /// `App` 본문이 아니라 뷰 수정자인 이유: `ModelContext`가 환경으로만 오고,
    /// `.modelContainer`가 붙은 씬의 **내용물**에서만 읽을 수 있다.
    func pruneOrphanedDraftsOnLaunch() -> some View {
        modifier(PruneOrphanedDraftsOnLaunch())
    }
}

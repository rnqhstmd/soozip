import SwiftUI
import SwiftData
import SoozipDraft

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 0 전용. Phase 3~6의 정식 화면으로 대체하며 제거한다.
            //
            // 실기기 스파이크가 둘 남아 있고 한 번에 하나만 띄운다.
            // S2로 바꾸려면 아래 한 줄을 `S2_CloudKitProbe()`로 교체한다 —
            // **프로브는 자기 컨테이너를 직접 들고 있다.**
            S1_GestureProbe()
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

    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.task {
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

#if DEBUG
import SwiftUI

/// Phase 0 스파이크 진입점. **DEBUG 빌드에만 존재한다.**
///
/// 앱 루트가 모음집 화면이 되면서 프로브가 도달 불가능해졌는데, 로드맵은
/// "S1·S2 측정이 끝나기 전에는 지우지 않는다"고 못박았다 — **측정하려면 실행
/// 가능해야 한다.** 그렇다고 릴리스 빌드에 프로브가 실리면 안 된다.
/// 파일 전체를 `#if DEBUG`로 감싸 둘을 모두 만족시킨다.
///
/// S1·S2 측정이 끝나면 이 파일과 `S1_GestureProbe`·`S2_CloudKitProbe`를 함께 지운다.
struct SpikeMenu: View {

    @State private var showingS1 = false
    @State private var showingS2 = false

    var body: some View {
        Menu {
            Button("S1 제스처 프로브") { showingS1 = true }
            Button("S2 CloudKit 프로브") { showingS2 = true }
        } label: {
            Image(systemName: "wrench.and.screwdriver")
        }
        .accessibilityLabel("스파이크 (개발용)")
        .fullScreenCover(isPresented: $showingS1) {
            spikeSheet { S1_GestureProbe() }
        }
        .fullScreenCover(isPresented: $showingS2) {
            spikeSheet { S2_CloudKitProbe() }
        }
    }

    /// 프로브는 자기 화면을 통째로 쓰므로 닫을 길만 얹는다.
    private func spikeSheet<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { showingS1 = false; showingS2 = false }
                    }
                }
        }
    }
}
#endif

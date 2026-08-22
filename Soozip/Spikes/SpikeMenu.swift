import SwiftUI

extension View {
    /// 스파이크 진입점을 얹는다. **DEBUG 빌드에만 실제로 붙는다.**
    ///
    /// **`#if DEBUG`를 이 함수 안에 두는 이유**: 툴바 항목 쪽에 두면 릴리스에서
    /// `@ToolbarContentBuilder`의 본문이 비는데, `ToolbarContentBuilder`에는
    /// 인자 없는 `buildBlock()`이 없어 **릴리스 빌드가 컴파일되지 않는다.**
    /// 실제로 그렇게 짰다가 깨졌다 — Debug 빌드와 테스트는 이걸 전혀 못 잡는다.
    func spikeMenuToolbar() -> some View {
        #if DEBUG
        return toolbar {
            ToolbarItem(placement: .topBarTrailing) { SpikeMenu() }
        }
        #else
        return self
        #endif
    }
}

#if DEBUG
/// Phase 0 스파이크 진입점. **DEBUG 빌드에만 존재한다.**
///
/// 앱 루트가 모음집 화면이 되면서 프로브가 도달 불가능해졌는데, 로드맵은
/// "측정이 끝나기 전에는 지우지 않는다"고 못박았다 — **측정하려면 실행
/// 가능해야 한다.** 그렇다고 릴리스 빌드에 프로브가 실리면 안 된다.
///
/// **S1은 `EDITOR-10`에서 지웠다.** 측정은 끝났고(`docs/reports/2026-08-10-spike-results.md`),
/// 같은 단위가 `LayerFrame.center`를 `internal(set)`으로 좁히면서 프로브의
/// `frames[s].center = …`가 모듈 밖 대입이 되어 컴파일 불가가 됐다. 고쳐 살리려면
/// `CanvasSurface` 배선을 미리 해야 하는데 그것은 `EDITOR-11`의 일이고 그 코드에는
/// 테스트가 없다. **S2 측정이 끝나면 이 파일과 `S2_CloudKitProbe`를 함께 지운다.**
struct SpikeMenu: View {

    @State private var showingS2 = false

    var body: some View {
        Menu {
            Button("S2 CloudKit 프로브") { showingS2 = true }
        } label: {
            Image(systemName: "wrench.and.screwdriver")
        }
        .accessibilityLabel("스파이크 (개발용)")
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
                        Button("닫기") { showingS2 = false }
                    }
                }
        }
    }
}
#endif

import SwiftUI
import SwiftData

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
        }
        // 앱 컨테이너는 정식 스키마만 싣는다. 목록을 여기 직접 적지 않는 이유는
        // 앱 배선·테스트 컨테이너·스키마 검사가 **같은 목록**을 봐야 하기 때문이다 —
        // 한 곳만 어긋나면 관계가 통째로 깨지는데 증상이 런타임에야 나온다.
        .modelContainer(for: SoozipSchema.models)
    }
}

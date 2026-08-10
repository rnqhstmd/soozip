import SwiftUI
import SwiftData

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 0 전용. Task 8에서 제거하고 Phase 1의 정식 화면으로 대체한다.
            //
            // 실기기 스파이크가 둘 남아 있고 한 번에 하나만 띄운다.
            // S2로 바꾸려면 아래 한 줄을 `S2_CloudKitProbe()`로 교체한다
            // (모델 컨테이너는 이미 붙어 있다).
            S1_GestureProbe()
        }
        .modelContainer(for: [ProbeCollection.self, ProbeCanvas.self])
    }
}

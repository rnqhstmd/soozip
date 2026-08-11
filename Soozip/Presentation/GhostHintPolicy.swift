import Foundation

/// 첫 실행 고스트 힌트 노출 판정 (v4 §12).
///
/// 이 앱에는 온보딩 화면이 없다. 대신 캐러셀 위에 흐린 힌트("첫 모음집을
/// 만들어보세요") 하나를 얹고, 탭하면 사라진다.
///
/// **`hasDismissed`를 주입받는 이유**: 앱은 `UserDefaults`를 쓰지만 그걸 직접
/// 읽으면 테스트가 전역 상태에 묶여 순서에 따라 결과가 달라진다.
struct GhostHintPolicy: Equatable {

    let hasDismissed: Bool

    init(hasDismissed: Bool) {
        self.hasDismissed = hasDismissed
    }

    /// **"첫 실행"은 처음 한 번을 뜻한다.** 모음집을 전부 지웠다고 다시 뜨면
    /// 앱을 쓸수록 반복해서 보게 된다(BR-5).
    func shouldShow(collectionCount: Int) -> Bool {
        !hasDismissed && collectionCount == 0
    }
}

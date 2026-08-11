import Foundation

/// 모음집 삭제 확인 (v4 §4, §12.7).
///
/// **문구를 값이 들고 있는 이유**: "캔버스 N장이 함께 삭제됩니다"의 N이 실제
/// 개수인지가 이 기능의 전부인데, 문구를 뷰에 두면 그걸 잴 수 없다.
enum DeletionPrompt: Equatable {

    /// 캔버스가 없다. 물어볼 것이 없으니 바로 지운다.
    case immediate

    /// 캔버스가 있다. **개수를 명시해** 확인을 받는다 — 사용자는 모음집을 지운다고
    /// 생각하지 그 안의 것까지 지운다고 생각하지 않는다.
    case warning(canvasCount: Int)

    /// 0장만 즉시 삭제다. 한 장이라도 사용자가 만든 것이라 조용히 지우지 않는다.
    static func forCollection(canvasCount: Int) -> DeletionPrompt {
        canvasCount == 0 ? .immediate : .warning(canvasCount: canvasCount)
    }

    /// 확인 문구. 즉시 삭제면 `nil`.
    var message: String? {
        switch self {
        case .immediate:
            return nil
        case .warning(let count):
            return "이 모음집의 캔버스 \(count)장이 함께 삭제됩니다. 되돌릴 수 없습니다."
        }
    }
}

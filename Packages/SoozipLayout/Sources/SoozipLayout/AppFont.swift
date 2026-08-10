import Foundation

/// `layoutJSON`의 `font` 값과 번들 폰트를 잇는다.
///
/// **raw value가 곧 JSON에 저장되는 문자열이다. 바꾸면 기존 캔버스가 깨진다.**
public enum AppFont: String, CaseIterable, Codable, Sendable {
    case pretendard
    case gowunBatang
    case gowunDodum
    case nanumPen
    case playfair

    /// `UIFont(name:size:)`에 넘기는 이름. **파일명이 아니라 PostScript 이름**이다.
    ///
    /// 2026-08-10에 `fontTools`로 추출해 확정했다.
    /// 나눔손글씨는 파일(`NanumPenScript-Regular.ttf`)과 이름이 다르므로 주의한다.
    public var postScriptName: String {
        switch self {
        case .pretendard:  return "Pretendard-Regular"
        case .gowunBatang: return "GowunBatang-Regular"
        case .gowunDodum:  return "GowunDodum-Regular"
        case .nanumPen:    return "NanumPen-Regular"        // ← 파일명과 다름
        case .playfair:    return "PlayfairDisplay-Regular"
        }
    }

    /// 폰트 스와치에 보이는 이름.
    public var displayName: String {
        switch self {
        case .pretendard:  return "프리텐다드"
        case .gowunBatang: return "고운바탕"
        case .gowunDodum:  return "고운돋움"
        case .nanumPen:    return "나눔손글씨"
        case .playfair:    return "Playfair"
        }
    }

    /// 한글 음절 11,172자를 전부 담고 있는가.
    ///
    /// 용량 때문에 감성 3종은 KS X 1001 2,350자로 서브셋했다(합계 5.2MB).
    /// 그 폰트로 `뷁·힣·똠` 같은 희귀 음절을 쓰면 iOS가 시스템 폰트로 폴백한다 —
    /// 글자가 사라지지는 않고 한 문장 안에서 폰트가 섞여 보인다.
    public var coversFullHangul: Bool {
        self == .pretendard
    }
}

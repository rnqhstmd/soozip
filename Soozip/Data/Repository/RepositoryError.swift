import Foundation

/// 입력 한계 (v4 §6.9). 텍스트 레이어 200자는 `layoutJSON`의 영역이라
/// `SoozipLayout` 책임이고 여기 없다.
///
/// **길이는 `String.count`(grapheme cluster)로 센다.** BR-1이 "이모지 1자 = 1자"를
/// 명시하는데, `utf16.count`로 세면 이모지가 2자가 되어 20자 제한이 이모지를 쓰는
/// 사용자에게만 10자로 줄어든다.
enum InputLimits {
    /// 모음집 이름은 필수다. 중복은 허용한다 — 사용자가 같은 이름을 원할 수 있고,
    /// `@Attribute(.unique)`는 CloudKit에서 쓸 수 없다.
    static let collectionName: ClosedRange<Int> = 1...20

    /// 캔버스 제목은 선택이라 하한이 0이다. 비어 있으면 목록에서 날짜로 표시한다(BR-2).
    static let canvasTitle: ClosedRange<Int> = 0...40
}

/// 리포지토리 계층의 에러.
///
/// 케이스가 맥락(어떤 입력이 몇 자였고 허용 범위가 무엇인지)을 들고 있어야
/// 호출부가 사용자에게 보여줄 문구를 만들 수 있다. `DraftStoreError`가
/// `draftNotFound(canvasID:)` 형태로 같은 규칙을 따른다.
///
/// 이름 초과와 제목 초과를 **다른 케이스로 나눈 이유**: Phase 6의 입력 시트가
/// 어느 필드에 안내를 붙일지 `if case`로 즉시 갈라야 한다.
enum RepositoryError: Error, Equatable {
    case collectionNameOutOfRange(length: Int, allowed: ClosedRange<Int>)
    case canvasTitleOutOfRange(length: Int, allowed: ClosedRange<Int>)

    /// 대표 캔버스로 지정하려는 캔버스가 그 모음집에 속하지 않는다.
    ///
    /// 옵셔널 반환이 아니라 에러인 이유: 이건 "없어서 못 찾았다"가 아니라 **호출부가
    /// 잘못된 조합을 넘긴 것**이다. 조용히 무시하면 사용자가 대표를 골랐는데 아무
    /// 일도 안 일어나는 화면이 된다.
    case canvasNotInCollection(canvasID: UUID, collectionID: UUID)
}

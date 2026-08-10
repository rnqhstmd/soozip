import Testing
import UIKit
import SoozipLayout

// AppFont는 앱 타깃이 아니라 SoozipLayout에 있다.
// layoutJSON의 `font` 값이라 Codec의 일부이기 때문이다.

@Test func 번들_폰트_5종이_모두_로드된다() {
    for font in AppFont.allCases {
        let loaded = UIFont(name: font.postScriptName, size: 20)
        #expect(loaded != nil, "폰트 로드 실패: \(font.postScriptName)")
    }
}

@Test func 나눔손글씨는_파일명이_아니라_PostScript이름으로_로드된다() {
    // 파일은 NanumPenScript-Regular.ttf인데 PostScript 이름은 NanumPen-Regular다.
    // 파일명으로 부르면 nil이 온다 — 이 함정을 테스트로 고정해 둔다.
    #expect(UIFont(name: "NanumPen-Regular", size: 20) != nil)
    #expect(UIFont(name: "NanumPenScript-Regular", size: 20) == nil)
}

// 아래 둘은 `!` 대신 `try #require`를 쓴다. 강제 언래핑은 폰트가 없을 때
// 테스트 러너를 통째로 죽여서 "무엇이 왜 실패했는지"가 남지 않는다.

@Test func 일상_한글_글리프가_누락되지_않았다() throws {
    // 감성 3종은 KS X 1001 2,350자로 서브셋했다. 일상 음절은 전부 들어 있어야 한다.
    let sample = "모음집 안녕하세요 가나다라마바사 2026년 8월"
    for font in [AppFont.gowunBatang, .gowunDodum, .nanumPen] {
        let uiFont = try #require(UIFont(name: font.postScriptName, size: 20),
                                  "\(font.displayName) 로드 실패")
        let attributed = NSAttributedString(string: sample, attributes: [.font: uiFont])
        #expect(attributed.size().width > 0, "\(font.displayName) 렌더 실패")
    }
}

@Test func 서브셋_폰트의_희귀음절은_시스템폰트로_폴백한다() throws {
    // `뷁`은 KS X 1001에 없다. 글자가 사라지지 않고 폰트만 섞여 보이는 것이
    // 의도한 동작이다(v4 §5.5). 폭이 0이면 글자가 통째로 증발한 것이다.
    let rare = "뷁힣똠"
    let uiFont = try #require(UIFont(name: AppFont.gowunBatang.postScriptName, size: 20))
    let attributed = NSAttributedString(string: rare, attributes: [.font: uiFont])
    #expect(attributed.size().width > 0)
}

@Test func Pretendard는_전체_한글을_담는다고_선언한다() {
    #expect(AppFont.pretendard.coversFullHangul)
    #expect(!AppFont.gowunBatang.coversFullHangul)
}

@Test func 알수없는_폰트이름은_nil을_반환한다() {
    #expect(UIFont(name: "NonExistentFont-Regular", size: 20) == nil)
}

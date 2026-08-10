import Testing
import Foundation
@testable import SoozipLayout

@Test func 폰트_5종이_정의되어_있다() {
    #expect(AppFont.allCases.count == 5)
}

@Test func rawValue는_layoutJSON에_저장되는_문자열이다() {
    // raw value를 바꾸면 기존 캔버스가 깨진다. 값 자체를 못 박아 둔다.
    #expect(AppFont.pretendard.rawValue == "pretendard")
    #expect(AppFont.gowunBatang.rawValue == "gowunBatang")
    #expect(AppFont.gowunDodum.rawValue == "gowunDodum")
    #expect(AppFont.nanumPen.rawValue == "nanumPen")
    #expect(AppFont.playfair.rawValue == "playfair")
}

@Test func 나눔손글씨의_PostScript이름은_파일명과_다르다() {
    // 파일은 NanumPenScript-Regular.ttf 인데 PostScript 이름은 NanumPen-Regular.
    // UIFont(name:)은 PostScript 이름을 받으므로 파일명을 쓰면 로드에 실패한다.
    #expect(AppFont.nanumPen.postScriptName == "NanumPen-Regular")
}

@Test func 나머지_4종의_PostScript이름() {
    #expect(AppFont.pretendard.postScriptName == "Pretendard-Regular")
    #expect(AppFont.gowunBatang.postScriptName == "GowunBatang-Regular")
    #expect(AppFont.gowunDodum.postScriptName == "GowunDodum-Regular")
    #expect(AppFont.playfair.postScriptName == "PlayfairDisplay-Regular")
}

@Test func 폰트는_Codable_라운드트립을_견딘다() throws {
    for font in AppFont.allCases {
        let data = try JSONEncoder().encode(font)
        let decoded = try JSONDecoder().decode(AppFont.self, from: data)
        #expect(decoded == font)
    }
}

@Test func 알수없는_폰트값은_디코딩에_실패한다() {
    let json = Data(#""nonExistentFont""#.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(AppFont.self, from: json)
    }
}

@Test func 한글_전체를_커버하는_폰트는_Pretendard뿐이다() {
    // 감성 3종은 KS X 1001 2350자로 서브셋됐다. 희귀 음절은 시스템 폰트로 폴백된다.
    #expect(AppFont.pretendard.coversFullHangul)
    #expect(!AppFont.gowunBatang.coversFullHangul)
    #expect(!AppFont.gowunDodum.coversFullHangul)
    #expect(!AppFont.nanumPen.coversFullHangul)
    #expect(!AppFont.playfair.coversFullHangul)   // 영문 전용
}

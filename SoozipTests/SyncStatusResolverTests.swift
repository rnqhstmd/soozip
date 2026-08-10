import Testing
import Foundation
@testable import Soozip

// 로컬 모드 판정(FR-13)과 입력 한계 계약(BR-1·BR-7).
//
// SyncStatusResolver가 CloudKit 타입을 받지 않는 것이 이 테스트의 전제다.
// CKAccountStatus를 그대로 받으면 AC-26~28을 검증하려고 실제 iCloud 계정이
// 필요해진다. 두 신호를 Bool로 좁혀 두면 판정이 순수 값 연산이 된다.

// MARK: - AC-26·27·28: 로컬 모드 판정

@Test func 계정이_없으면_로컬모드다() {
    let resolver = SyncStatusResolver(accountAvailable: false, quotaExceeded: false)
    #expect(resolver.mode == .local)
}

@Test func 용량이_초과되면_로컬모드다() {
    let resolver = SyncStatusResolver(accountAvailable: true, quotaExceeded: true)
    #expect(resolver.mode == .local)
}

@Test func 계정이_있고_용량이_남으면_클라우드모드다() {
    let resolver = SyncStatusResolver(accountAvailable: true, quotaExceeded: false)
    #expect(resolver.mode == .cloud)
}

@Test func 두_신호가_동시에_걸려도_로컬모드다() {
    // FR-13은 "둘 중 하나라도 해당하면"이라 네 조합이 전부 규정돼 있다.
    // 이 조합을 빼면 && 대신 ^ 같은 잘못된 결합도 통과한다.
    let resolver = SyncStatusResolver(accountAvailable: false, quotaExceeded: true)
    #expect(resolver.mode == .local)
}

@Test func isLocalMode는_mode가_local일_때_참이다() {
    #expect(SyncStatusResolver(accountAvailable: false, quotaExceeded: false).isLocalMode)
    #expect(!SyncStatusResolver(accountAvailable: true, quotaExceeded: false).isLocalMode)
}

@Test func 기본값은_클라우드모드다() {
    // 앱이 뜨자마자 로컬 모드 배너를 띄우지 않으려면 낙관적 기본값이어야 한다.
    #expect(SyncStatusResolver().mode == .cloud)
}

// MARK: - BR-1·BR-7: 입력 한계 계약

@Test func 모음집_이름_범위는_1자에서_20자다() {
    #expect(InputLimits.collectionName == 1...20)
}

@Test func 캔버스_제목_범위는_0자에서_40자다() {
    // 제목은 선택이라 하한이 0이다(BR-2 — 비면 목록에서 날짜로 표시).
    #expect(InputLimits.canvasTitle == 0...40)
}

@Test func 빈_모음집_이름은_범위_밖이고_한_글자는_안이다() {
    #expect(!InputLimits.collectionName.contains("".count))
    #expect(InputLimits.collectionName.contains("가".count))
}

@Test func 스무자_모음집_이름은_안이고_스물한자는_밖이다() {
    let twenty = String(repeating: "가", count: 20)
    let twentyOne = String(repeating: "가", count: 21)
    #expect(InputLimits.collectionName.contains(twenty.count))
    #expect(!InputLimits.collectionName.contains(twentyOne.count))
}

@Test func 마흔자_캔버스_제목은_안이고_마흔한자는_밖이다() {
    let forty = String(repeating: "가", count: 40)
    let fortyOne = String(repeating: "가", count: 41)
    #expect(InputLimits.canvasTitle.contains(forty.count))
    #expect(!InputLimits.canvasTitle.contains(fortyOne.count))
}

@Test func 이모지는_한_글자로_센다() {
    // BR-1이 "이모지 1자 = 1자"를 명시한다. String.count는 grapheme cluster
    // 단위라 이것이 성립하지만, utf16.count로 세면 이모지가 2자가 되어
    // 20자 제한이 이모지 사용자에게만 10자로 줄어든다.
    let family = "👨‍👩‍👧‍👦"
    #expect(family.count == 1)

    let twentyEmoji = String(repeating: "🎨", count: 20)
    #expect(InputLimits.collectionName.contains(twentyEmoji.count))

    let twentyOneEmoji = String(repeating: "🎨", count: 21)
    #expect(!InputLimits.collectionName.contains(twentyOneEmoji.count))
}

// MARK: - RepositoryError

@Test func 이름_초과와_제목_초과는_다른_에러다() {
    // 호출부가 어느 입력이 문제인지 구분할 수 있어야 Phase 6 UI가
    // 해당 필드에 안내를 붙일 수 있다.
    let nameError = RepositoryError.collectionNameOutOfRange(length: 21, allowed: InputLimits.collectionName)
    let titleError = RepositoryError.canvasTitleOutOfRange(length: 41, allowed: InputLimits.canvasTitle)
    #expect(nameError != titleError)
}

@Test func 같은_케이스와_같은_연관값은_같은_에러다() {
    let a = RepositoryError.collectionNameOutOfRange(length: 21, allowed: 1...20)
    let b = RepositoryError.collectionNameOutOfRange(length: 21, allowed: 1...20)
    #expect(a == b)
}

@Test func 길이가_다르면_다른_에러다() {
    let a = RepositoryError.collectionNameOutOfRange(length: 21, allowed: 1...20)
    let b = RepositoryError.collectionNameOutOfRange(length: 99, allowed: 1...20)
    #expect(a != b)
}

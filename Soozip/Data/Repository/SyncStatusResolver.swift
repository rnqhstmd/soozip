import Foundation

/// 동기화 모드. 로컬 모드는 "iCloud를 못 쓰는 상태"이지 오류 상태가 아니다 —
/// 앱은 그대로 동작하고 설정에 배너만 뜬다 (v4 §7.2, §14).
enum SyncMode: Equatable, Sendable {
    case cloud
    case local
}

/// 로컬 모드 격하 판정 (FR-13, v4 §7.2).
///
/// **CloudKit 타입을 받지 않는다.** `CKAccountStatus`를 그대로 받으면 AC-26~28을
/// 검증하려고 실제 iCloud 계정이 필요해진다. 두 신호를 `Bool`로 좁혀 두면 판정이
/// 순수 값 연산이 되고, 실제 조회는 어댑터 한 겹 밖으로 밀려난다 — 스파이크 S2가
/// 보류라 CloudKit에 닿는 코드는 지금 테스트할 방법이 없다.
///
/// 두 신호는 알 수 있는 시점이 다르다. 계정 상태는 앱 구동·주기적 확인 시점에,
/// 용량 초과는 실제 저장이 실패한 시점(`CKError.quotaExceeded`)에 온다.
/// 그래도 **판정은 하나로 통합**한다 — 호출부가 사유별로 분기할 일이 없고,
/// 사유 구분이 필요한 곳은 설정 화면의 배너 문구뿐이라 Phase 9의 몫이다.
struct SyncStatusResolver: Equatable, Sendable {

    var accountAvailable: Bool
    var quotaExceeded: Bool

    /// 기본값이 낙관적인 이유: 앱이 뜨자마자 로컬 모드 배너를 띄우면
    /// 계정 조회가 끝나기도 전에 사용자를 놀라게 한다.
    init(accountAvailable: Bool = true, quotaExceeded: Bool = false) {
        self.accountAvailable = accountAvailable
        self.quotaExceeded = quotaExceeded
    }

    /// 두 신호 중 **하나라도** 걸리면 로컬 모드다 (FR-13).
    var mode: SyncMode {
        (accountAvailable && !quotaExceeded) ? .cloud : .local
    }

    var isLocalMode: Bool { mode == .local }
}

import Testing
import Foundation
import SwiftData
@testable import Soozip

// 리포지토리 테스트의 공용 하네스.
// `DraftStoreTests`의 `withTempStore` 클로저 헬퍼와 같은 형태다.

/// 테스트마다 **새 컨테이너**를 만든다. Swift Testing은 기본이 병렬 실행이라
/// 컨테이너를 공유하면 다른 테스트가 넣은 모음집이 카운트 검증에 섞여 들어온다.
///
/// `checksCoverInvariant`를 끄는 테스트는 **유령 표지 상태를 일부러 만드는
/// 테스트(AC-18)뿐**이어야 한다.
@MainActor
func withLibrary(checksCoverInvariant: Bool = true,
                 sourceLocation: SourceLocation = #_sourceLocation,
                 _ body: (LibraryRepository, ModelContext) throws -> Void) throws {
    let schema = Schema(SoozipSchema.models)
    let config = ModelConfiguration(
        UUID().uuidString,        // 이름을 매번 다르게 — 인메모리 저장소 공유를 원천 차단
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none   // **필수.** 켜 두면 컨테이너 초기화가 iCloud를 건드려
                                  // 테스트가 계정·네트워크 상태에 묶인다. 스파이크 S2가
                                  // 보류인 지금 이 격리가 전제다
    )
    let container = try ModelContainer(for: schema, configurations: config)
    let context = ModelContext(container)

    // **실측: `ModelContext(container)`의 `autosaveEnabled` 기본값은 `true`다.**
    // 끄지 않으면 autosave가 "save → reconcile" 순서 버그를 가려 버린다 —
    // 순서를 틀리게 짜도 테스트가 초록이 되는 것이 가장 나쁜 상태다.
    context.autosaveEnabled = false

    try body(LibraryRepository(context: context), context)

    guard checksCoverInvariant else { return }

    // 클로저가 끝나면 전 모음집의 표지 불변식을 검사한다.
    // 개별 AC는 우리가 아는 경로만 막지만, 이 검사는 아직 짜지 않은 경로까지 막는다 —
    // 초안 설계의 업서트가 AC 어디에도 안 걸리면서 "표지=C1인데 소속 캔버스 0장"을
    // 만들어 냈던 것이 이 검사가 있는 이유다.
    try context.save()
    let collections = try context.fetch(FetchDescriptor<Collection>())
    let allCanvases = try context.fetch(FetchDescriptor<Canvas>())
    for c in collections {
        let candidates = allCanvases.filter { $0.collection?.id == c.id }
        #expect(CoverPolicy.isConsistent(c, candidates: candidates),
                "표지 불변식 위반 — 모음집 \(c.name): cover=\(c.coverCanvasID), 소속 \(candidates.count)장",
                sourceLocation: sourceLocation)
    }
}

// MARK: - 시간 픽스처

/// **`timeZone`을 박는다.** `Calendar(identifier: .gregorian)`은 `TimeZone.current`를
/// 물고 온다. CI 타임존이 다르면 "이번 달"·"연속 기록" 경계가 기기마다 달라진다.
@MainActor
var testCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return cal
}

/// 고정 앵커. `Date()`에서 역산하면 자정 직전에 돌릴 때 하루가 밀린다.
@MainActor
func testAnchor() throws -> Date {
    try #require(testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 12)))
}

/// 앵커 기준 상대 날짜. `day(-1, from: anchor)`는 어제 정오.
@MainActor
func day(_ offset: Int, from anchor: Date) throws -> Date {
    try #require(testCalendar.date(byAdding: .day, value: offset, to: anchor))
}

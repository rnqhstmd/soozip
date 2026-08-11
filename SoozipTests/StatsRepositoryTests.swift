import Testing
import Foundation
import SwiftData
import SoozipLayout
@testable import Soozip

// StatsRepository — 통계 5종 (AC-19~25, 25a, 25b).
//
// 시각은 전부 파라미터로 들어온다. `streakDays()`만 `now`를 안 받게 뒀던 것이
// 정확히 BR-9 버그 지점이었다 — 미래 날짜 오염과 무기한 스트릭을 동시에 만들었다.

// MARK: - 픽스처

/// 기록 날짜만 지정해 캔버스를 만든다. 통계는 전부 `createdAt`을 보므로
/// 저장 시각(`now`)은 여기서 의미가 없다.
@MainActor
private func 캔버스저장(_ library: LibraryRepository, in collection: Collection,
                      on dates: Date...) throws {
    for date in dates {
        try library.createCanvas(CanvasInput(aspect: .post, createdAt: date),
                                 in: collection, now: date)
    }
}

/// 고정 타임존(`testCalendar`) 기준의 절대 시각. 경계 테스트가 분 단위를 쓴다.
@MainActor
private func 시각(_ year: Int, _ month: Int, _ day: Int,
                _ hour: Int = 12, _ minute: Int = 0) throws -> Date {
    try #require(testCalendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute)))
}

// MARK: - AC-19·20: 개수

@Test @MainActor func 모음집이_셋이면_모음집_수는_3이다() throws {
    try withStats { library, stats in
        let anchor = try testAnchor()
        try library.createCollection(name: "가", now: anchor)
        try library.createCollection(name: "나", now: anchor)
        try library.createCollection(name: "다", now: anchor)

        #expect(try stats.collectionCount() == 3)
    }
}

@Test @MainActor func 총_캔버스_수는_모음집을_가로질러_합산된다() throws {
    // 모음집 하나에 몰아 두면 "소속 무관 전체"인지 알 수 없다.
    try withStats { library, stats in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "가", now: anchor)
        let b = try library.createCollection(name: "나", now: anchor)
        try 캔버스저장(library, in: a, on: anchor, anchor, anchor)
        try 캔버스저장(library, in: b, on: anchor, anchor)

        #expect(try stats.canvasCount() == 5)
    }
}

@Test @MainActor func 아무것도_없으면_모든_개수가_0이다() throws {
    // **`try`를 문 수준으로 올린다.** `#expect(try ...)`만 있고 문 수준 `try`가 없으면
    // 클로저가 비throwing으로 추론된다 — 매크로 확장이 타입 추론보다 나중이라
    // 매크로 안의 `try`는 추론에 안 잡힌다. 확장된 코드가 "errors thrown from here
    // are not handled"로 깨진다.
    try withStats { _, stats in
        let 모음집수 = try stats.collectionCount()
        let 캔버스수 = try stats.canvasCount()
        let 이번달 = try stats.canvasCount(inMonthOf: try testAnchor())

        #expect(모음집수 == 0)
        #expect(캔버스수 == 0)
        #expect(이번달 == 0)
    }
}

// MARK: - AC-21: 이번 달 생성 수

@Test @MainActor func 이번_달_캔버스만_센다() throws {
    try withStats { library, stats in
        let anchor = try testAnchor()          // 2026-08-10
        let a = try library.createCollection(name: "여행", now: anchor)
        try 캔버스저장(library, in: a,
                    on: anchor,
                       try 시각(2026, 8, 3),
                       try 시각(2026, 7, 28))  // 지난달

        #expect(try stats.canvasCount(inMonthOf: anchor) == 2)
    }
}

@Test @MainActor func 이번_달_경계는_달의_첫_순간과_마지막_순간이다() throws {
    // 기준을 `now`로부터 30일 같은 상대 구간으로 잡으면 8월 1일에 물어봤을 때
    // 7월 캔버스가 섞인다. 경계는 달력의 달이다.
    try withStats { library, stats in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "여행", now: anchor)
        try 캔버스저장(library, in: a,
                    on: try 시각(2026, 7, 31, 23, 59),   // 지난달 마지막 — 제외
                       try 시각(2026, 8, 1, 0, 0),       // 이번달 첫 — 포함
                       try 시각(2026, 8, 31, 23, 59),    // 이번달 마지막 — 포함
                       try 시각(2026, 9, 1, 0, 0))       // 다음달 첫 — 제외

        #expect(try stats.canvasCount(inMonthOf: anchor) == 2)
    }
}

// MARK: - AC-22·23: 가장 많이 담은 모음집

@Test @MainActor func 캔버스가_가장_많은_모음집의_이름과_수가_나온다() throws {
    try withStats { library, stats in
        let anchor = try testAnchor()
        let a = try library.createCollection(name: "많은쪽", now: anchor)
        let b = try library.createCollection(name: "적은쪽", now: try day(1, from: anchor))
        try 캔버스저장(library, in: a, on: anchor, anchor, anchor)
        try 캔버스저장(library, in: b, on: anchor)

        let 최다 = try #require(try stats.largestCollection())
        #expect(최다.name == "많은쪽")
        #expect(최다.canvasCount == 3)
    }
}

@Test @MainActor func 동수이면_먼저_만든_모음집이_이긴다() throws {
    // `max(by:)`는 동률에서 **마지막**을 돌려준다. 그걸 쓰면 이 테스트가 빨개진다 —
    // 그러라고 나중에 만든 쪽을 뒤에 둔다(BR-8).
    try withStats { library, stats in
        let anchor = try testAnchor()
        let 먼저 = try library.createCollection(name: "먼저", now: anchor)
        let 나중 = try library.createCollection(name: "나중", now: try day(1, from: anchor))
        try 캔버스저장(library, in: 먼저, on: anchor, anchor)
        try 캔버스저장(library, in: 나중, on: anchor, anchor)

        let 최다 = try #require(try stats.largestCollection())
        #expect(최다.name == "먼저")
        #expect(최다.id == 먼저.id)
        #expect(최다.canvasCount == 2)
    }
}

@Test @MainActor func 모음집이_하나도_없으면_최다_모음집은_nil이다() throws {
    try withStats { _, stats in
        let 최다 = try stats.largestCollection()
        #expect(최다 == nil)
    }
}

@Test @MainActor func 전부_비어_있으면_먼저_만든_모음집이_0장으로_나온다() throws {
    // PRD에 규정이 없는 자리다. nil은 "모음집이 없다"는 뜻으로 남겨 두고,
    // 0장끼리도 동률로 보아 BR-8(먼저 생성된 쪽)을 그대로 적용한다.
    try withStats { library, stats in
        let anchor = try testAnchor()
        try library.createCollection(name: "먼저", now: anchor)
        try library.createCollection(name: "나중", now: try day(1, from: anchor))

        let 최다 = try #require(try stats.largestCollection())
        #expect(최다.name == "먼저")
        #expect(최다.canvasCount == 0)
    }
}

// MARK: - AC-24·25·25a·25b: 연속 기록 (BR-9)

@Test @MainActor func 오늘부터_사흘_연속이면_3이다() throws {
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        try 캔버스저장(library, in: a,
                    on: 오늘,
                       try day(-1, from: 오늘),
                       try day(-2, from: 오늘))
        // 3일 전은 비어 있다

        #expect(try stats.streakDays(now: 오늘) == 3)
    }
}

@Test @MainActor func 오늘_아직_저장하지_않아도_어제까지의_연속은_유지된다() throws {
    // 유예 1일. 이것이 BR-9가 지키려는 핵심이다 — 앱을 아침에 열었다는 이유로
    // 어제까지 쌓은 연속이 0으로 보이면 안 된다.
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        try 캔버스저장(library, in: a,
                    on: try day(-1, from: 오늘),
                       try day(-2, from: 오늘))

        #expect(try stats.streakDays(now: 오늘) == 2)
    }
}

@Test @MainActor func 미래_기록_날짜는_연속_계산을_오염시키지_않는다() throws {
    // BR-3이 미래 날짜를 허용하므로, 제외하지 않으면 잘못 찍은 1건이
    // 30일 스트릭을 1로 무너뜨린다.
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        try 캔버스저장(library, in: a,
                    on: 오늘,
                       try day(-1, from: 오늘),
                       try day(-2, from: 오늘),
                       try day(730, from: 오늘))   // 2년 뒤

        #expect(try stats.streakDays(now: 오늘) == 3)
    }
}

@Test @MainActor func 유예를_넘겨_사흘_전이_최근이면_0이다() throws {
    // 며칠씩 비어 있는데 옛 연속을 계속 보고하면 유예가 유예가 아니게 된다.
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        try 캔버스저장(library, in: a,
                    on: try day(-3, from: 오늘),
                       try day(-4, from: 오늘),
                       try day(-5, from: 오늘))

        #expect(try stats.streakDays(now: 오늘) == 0)
    }
}

@Test @MainActor func 저장_기록이_없으면_연속은_0이다() throws {
    try withStats { _, stats in
        let 연속 = try stats.streakDays(now: try testAnchor())
        #expect(연속 == 0)
    }
}

@Test @MainActor func 같은_날_여러_장을_저장해도_하루로_센다() throws {
    // 저장 "일"의 연속이지 저장 "건"의 연속이 아니다.
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        try 캔버스저장(library, in: a,
                    on: 오늘,
                       try 시각(2026, 8, 10, 9),
                       try 시각(2026, 8, 10, 23),
                       try day(-1, from: 오늘))

        #expect(try stats.streakDays(now: 오늘) == 2)
    }
}

@Test @MainActor func 연속_계산은_모음집을_가로지른다() throws {
    // 연속 기록은 사용자 단위 지표다. 모음집별로 끊으면 어제는 여행에,
    // 오늘은 일상에 저장한 사용자의 연속이 사라진다.
    try withStats { library, stats in
        let 오늘 = try testAnchor()
        let a = try library.createCollection(name: "여행", now: 오늘)
        let b = try library.createCollection(name: "일상", now: 오늘)
        try 캔버스저장(library, in: a, on: 오늘)
        try 캔버스저장(library, in: b, on: try day(-1, from: 오늘))

        #expect(try stats.streakDays(now: 오늘) == 2)
    }
}

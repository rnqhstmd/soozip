import Foundation
import SwiftData

/// 설정 화면의 통계 한 줄용 요약. 모델 객체를 그대로 넘기지 않는 이유는
/// 화면이 필요로 하는 것이 이름과 개수뿐이고, `Collection`을 넘기면 그 화면이
/// 표지·정렬 같은 관계까지 만질 수 있게 되기 때문이다.
struct CollectionSummary: Equatable, Sendable {
    let id: UUID
    let name: String
    let canvasCount: Int
}

/// 통계 조회 전용. `LibraryRepository`와 나눠 둔 이유는 이쪽이 **쓰기가 없어서**다 —
/// 표지 불변식을 지킬 책임이 없으니 같은 타입에 섞을 이유도 없다.
@MainActor
struct StatsRepository {

    let context: ModelContext

    /// **주입 대상이다.** "이번 달"과 "연속 기록"의 경계가 타임존에 걸려 있어
    /// `.current`를 박으면 CI 타임존이 바뀌는 순간 AC-21·24·25가 흔들린다.
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - 개수 (AC-19, 20)

    func collectionCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Collection>())
    }

    /// 소속과 무관한 전체 캔버스 수.
    func canvasCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Canvas>())
    }

    // MARK: - 이번 달 (AC-21)

    /// `now`가 속한 **달력상의 달**에 기록된 캔버스 수.
    ///
    /// "최근 30일" 같은 상대 구간이 아니다 — 8월 1일에 물어보면 7월 캔버스가
    /// 통째로 섞여 들어온다.
    func canvasCount(inMonthOf now: Date) throws -> Int {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }

        // **`month.contains(_:)`를 쓰지 않는다.** `DateInterval`은 닫힌 구간이라
        // `end`(= 다음 달 1일 00:00)를 포함한다 — 그 순간에 기록된 캔버스가
        // 이번 달로 새어 들어온다. 경계 테스트가 정확히 이걸로 빨개졌다.
        return try allCanvases()
            .count { month.start <= $0.createdAt && $0.createdAt < month.end }
    }

    // MARK: - 가장 많이 담은 모음집 (AC-22, 23)

    /// 캔버스가 가장 많은 모음집. 모음집이 하나도 없을 때만 `nil`이다 —
    /// 전부 비어 있으면 0장끼리 동률로 보고 BR-8을 적용한다.
    func largestCollection() throws -> CollectionSummary? {
        let counts = try canvasCountsByCollection()

        // `max(by:)`를 쓰지 않는다. 동률에서 **마지막**을 돌려주는데, BR-8은
        // 먼저 생성된 쪽을 원한다(AC-23).
        var best: CollectionSummary?
        for collection in try collectionsByCreation() {
            let count = counts[collection.id] ?? 0
            // 엄격한 초과일 때만 갱신 — 동률에서 갱신하지 않아야 앞선 것이 남는다.
            guard count > (best?.canvasCount ?? -1) else { continue }
            best = CollectionSummary(id: collection.id, name: collection.name,
                                     canvasCount: count)
        }
        return best
    }

    // MARK: - 연속 기록 (AC-24, 25, 25a, 25b / BR-9)

    /// `now` 기준 연속 저장 일수.
    ///
    /// 저장 **일**의 연속이지 저장 **건**의 연속이 아니고, 모음집을 가로지른다 —
    /// 사용자 단위 지표라 어제는 여행에 오늘은 일상에 저장해도 이어져야 한다.
    func streakDays(now: Date) throws -> Int {
        let today = calendar.startOfDay(for: now)

        // BR-9①: `now`의 오늘보다 미래인 기록 날짜는 뺀다. BR-3이 미래를 허용하므로
        // 빼지 않으면 날짜를 한 번 잘못 찍은 캔버스 1건이 스트릭 전체를 파괴한다.
        let days = Set(try allCanvases()
            .map { calendar.startOfDay(for: $0.createdAt) }
            .filter { $0 <= today })

        guard let latest = days.max(),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        else { return 0 }

        // BR-9②: 유예 1일. 오늘 아직 저장하지 않았다는 이유만으로 끊기지 않되(AC-25),
        // 며칠씩 비어 있는데 옛 연속을 계속 보고하지도 않는다(AC-25b).
        guard latest == today || latest == yesterday else { return 0 }

        var streak = 0
        var cursor = latest
        while days.contains(cursor) {
            streak += 1
            // `-86400` 같은 TimeInterval 산술을 쓰지 않는다. DST 경계에서 하루가
            // 23/25시간이 되는 날 계산이 어긋난다.
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor)
            else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - 내부

    /// 전량 캔버스. 통계 셋이 각자 같은 fetch를 적고 있어 한 곳으로 모았다.
    private func allCanvases() throws -> [Canvas] {
        try context.fetch(FetchDescriptor<Canvas>())
    }

    /// 생성 순서(오름차순)의 모음집. BR-8의 "먼저 생성된 쪽"이 이 순서를 뜻한다.
    private func collectionsByCreation() throws -> [Collection] {
        try context.fetch(FetchDescriptor<Collection>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    }

    /// 모음집별 캔버스 수. 모음집마다 따로 세면 모음집 수만큼 fetch가 도는데,
    /// 캔버스를 한 번 훑으면 한 번으로 끝난다.
    private func canvasCountsByCollection() throws -> [UUID: Int] {
        try allCanvases()
            .reduce(into: [:]) { counts, canvas in
                guard let owner = canvas.collection?.id else { return }
                counts[owner, default: 0] += 1
            }
    }
}

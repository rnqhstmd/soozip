import Testing
import Foundation
import SwiftData
import SoozipLayout
@testable import Soozip

// LibraryRepository — 모음집 CRUD와 정렬 (AC-14·15·29·31),
// 캔버스 생성·갱신과 표지 재계산 (AC-6·7·30·32).

// MARK: - AC-14: 생성 순서가 정렬 순서다

@Test @MainActor func 모음집을_순서대로_만들면_sortIndex가_0부터_증가한다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "가", now: anchor)
        let b = try repo.createCollection(name: "나", now: try day(1, from: anchor))
        let c = try repo.createCollection(name: "다", now: try day(2, from: anchor))

        #expect(a.sortIndex == 0)
        #expect(b.sortIndex == 1)
        #expect(c.sortIndex == 2)
    }
}

@Test @MainActor func 재배치하지_않아도_조회_순서는_생성_순서와_같다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        try repo.createCollection(name: "가", now: anchor)
        try repo.createCollection(name: "나", now: try day(1, from: anchor))
        try repo.createCollection(name: "다", now: try day(2, from: anchor))

        #expect(try repo.collections().map(\.name) == ["가", "나", "다"])
    }
}

// MARK: - AC-15: sortIndex가 겹치면 createdAt 오름차순

@Test @MainActor func sortIndex가_같으면_먼저_만든_모음집이_앞선다() throws {
    // 두 기기가 동시에 순서를 바꾸면 sortIndex가 겹칠 수 있다(v4 §6.9).
    // 2차 정렬 키가 없으면 그때 순서가 비결정적이 된다.
    try withLibrary { repo, context in
        let anchor = try testAnchor()
        let 먼저 = try repo.createCollection(name: "먼저", now: anchor)
        let 나중 = try repo.createCollection(name: "나중", now: try day(1, from: anchor))

        나중.sortIndex = 먼저.sortIndex   // 동기화 충돌로 값이 겹친 상황을 재현
        try context.save()

        #expect(try repo.collections().map(\.name) == ["먼저", "나중"])
    }
}

// MARK: - AC-29: 이름 길이 강제 (BR-7)

@Test @MainActor func 스물한자_모음집_이름은_거부된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let tooLong = String(repeating: "가", count: 21)
        #expect(throws: RepositoryError.collectionNameOutOfRange(
            length: 21, allowed: InputLimits.collectionName)) {
            try repo.createCollection(name: tooLong, now: anchor)
        }
    }
}

@Test @MainActor func 빈_모음집_이름은_거부된다() throws {
    // 이름은 필수다(BR-1). UI가 아직 없으니 리포지토리가 최후 방어선이다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()   // #expect(throws:) 클로저 밖에서 만든다 —
                                        // 안에서 던지면 검증 대상 에러와 섞인다
        #expect(throws: RepositoryError.self) {
            try repo.createCollection(name: "", now: anchor)
        }
    }
}

@Test @MainActor func 거부된_모음집은_저장되지_않는다() throws {
    // 검증이 insert보다 먼저여야 부분 상태가 남지 않는다.
    try withLibrary { repo, context in
        let anchor = try testAnchor()
        _ = try? repo.createCollection(name: String(repeating: "가", count: 21), now: anchor)
        #expect(try context.fetchCount(FetchDescriptor<Collection>()) == 0)
    }
}

@Test @MainActor func 스무자_모음집_이름은_허용된다() throws {
    try withLibrary { repo, _ in
        let name = String(repeating: "가", count: 20)
        let made = try repo.createCollection(name: name, now: try testAnchor())
        #expect(made.name == name)
    }
}

// MARK: - AC-31: 중복 이름 허용

@Test @MainActor func 같은_이름의_모음집도_만들어진다() throws {
    // 사용자가 같은 이름을 원할 수 있고, @Attribute(.unique)는 CloudKit에서 못 쓴다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        try repo.createCollection(name: "여행", now: anchor)
        try repo.createCollection(name: "여행", now: try day(1, from: anchor))

        #expect(try repo.collections().count == 2)
    }
}

// MARK: - 새 모음집은 표지가 비어 있다 (BR-4)

@Test @MainActor func 캔버스가_없는_모음집의_표지는_빈_문자열이다() throws {
    try withLibrary { repo, _ in
        let made = try repo.createCollection(name: "빈", now: try testAnchor())
        #expect(made.coverCanvasID.isEmpty)
    }
}

// MARK: - 캔버스 입력 픽스처

/// 한계를 1자 넘긴 제목과 그때 나와야 할 에러. **둘을 붙여 두는 이유**: 길이가
/// 서로 어긋나면 통과해도 검증한 것이 없다.
private let 한계초과_제목 = String(repeating: "가", count: 41)
private let 한계초과_제목_에러 = RepositoryError.canvasTitleOutOfRange(
    length: 한계초과_제목.count, allowed: InputLimits.canvasTitle)

/// `aspect`와 `createdAt`은 기본값이 없다(설계 §7) — 매 호출에 쓰면 본질이 묻힌다.
@MainActor
private func canvasInput(title: String = "",
                         createdAt: Date,
                         aspect: CanvasAspect = .post,
                         layoutJSON: Data = Data(),
                         renderedPNG: Data? = nil) -> CanvasInput {
    CanvasInput(aspect: aspect, title: title, createdAt: createdAt,
                layoutJSON: layoutJSON, renderedPNG: renderedPNG)
}

// MARK: - AC-6: 첫 캔버스가 표지가 된다

@Test @MainActor func 첫_캔버스를_만들면_그_캔버스가_표지가_된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        #expect(a.coverCanvasID.isEmpty)

        let c1 = try repo.createCanvas(canvasInput(createdAt: anchor), in: a, now: anchor)

        #expect(a.coverCanvasID == c1.id.uuidString)
    }
}

// MARK: - AC-7: 표지가 있으면 새 캔버스가 밀어내지 못한다

@Test @MainActor func 표지가_있는_모음집에_더_최신_캔버스를_넣어도_표지는_그대로다() throws {
    // 새 캔버스가 **더 최신**이어야 의미가 있다 — BR-6(최신 우선)이 유지
    // 규칙(AC-7)을 이기지 않는지가 이 테스트의 전부다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let c1 = try repo.createCanvas(canvasInput(createdAt: anchor), in: a, now: anchor)

        let later = try day(3, from: anchor)
        let c2 = try repo.createCanvas(canvasInput(createdAt: later), in: a, now: later)

        #expect(a.coverCanvasID == c1.id.uuidString)
        #expect(a.coverCanvasID != c2.id.uuidString)
    }
}

@Test @MainActor func 캔버스는_지정한_모음집에만_속하고_다른_모음집_표지를_건드리지_않는다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "가", now: anchor)
        let b = try repo.createCollection(name: "나", now: try day(1, from: anchor))

        let c1 = try repo.createCanvas(canvasInput(createdAt: anchor), in: b, now: anchor)

        #expect(c1.collection?.id == b.id)
        #expect(b.coverCanvasID == c1.id.uuidString)
        #expect(a.coverCanvasID.isEmpty)
    }
}

// MARK: - AC-30: 제목 길이 강제 (BR-7)

@Test @MainActor func 마흔한자_캔버스_제목은_거부된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)

        #expect(throws: 한계초과_제목_에러) {
            try repo.createCanvas(canvasInput(title: 한계초과_제목, createdAt: anchor),
                                  in: a, now: anchor)
        }
    }
}

@Test @MainActor func 거부된_캔버스는_저장되지_않고_표지도_그대로다() throws {
    // 검증이 insert보다 먼저여야 부분 상태가 남지 않는다.
    try withLibrary { repo, context in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        _ = try? repo.createCanvas(canvasInput(title: 한계초과_제목, createdAt: anchor),
                                   in: a, now: anchor)

        #expect(try context.fetchCount(FetchDescriptor<Canvas>()) == 0)
        #expect(a.coverCanvasID.isEmpty)
    }
}

@Test @MainActor func 마흔자_제목과_빈_제목은_허용된다() throws {
    // 제목은 선택이라 하한이 0이다(BR-2) — 비면 목록에서 날짜로 표시한다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let full = String(repeating: "가", count: 40)

        let long = try repo.createCanvas(canvasInput(title: full, createdAt: anchor),
                                         in: a, now: anchor)
        let empty = try repo.createCanvas(canvasInput(title: "", createdAt: anchor),
                                          in: a, now: anchor)

        #expect(long.title == full)
        #expect(empty.title.isEmpty)
    }
}

// MARK: - AC-32: 기록 날짜는 보정하지 않는다 (BR-3)

@Test @MainActor func 미래_기록_날짜는_보정_없이_그대로_저장된다() throws {
    // 기록 날짜는 사용자가 정한다. now로 깎으면 여행 뒤 몰아서 정리하거나
    // 날짜를 앞당겨 적는 사용 패턴이 그대로 깨진다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let future = try day(30, from: anchor)

        let made = try repo.createCanvas(canvasInput(createdAt: future), in: a, now: anchor)

        #expect(made.createdAt == future)
        #expect(made.updatedAt == anchor)   // now를 따르는 것은 updatedAt 하나뿐이다
    }
}

@Test @MainActor func 입력의_식별자와_비율이_그대로_캔버스에_실린다() throws {
    // Phase 2의 초안 승격이 초안 식별자를 그대로 들고 온다 — 여기서 새 UUID를
    // 발급하면 승격 전후로 같은 캔버스가 서로 다른 것이 된다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let id = UUID()

        let made = try repo.createCanvas(
            CanvasInput(id: id, aspect: .story, title: "제주", createdAt: anchor),
            in: a, now: anchor)

        #expect(made.id == id)
        #expect(made.aspectPreset == .story)
    }
}

// MARK: - updateCanvas (AC-30·32 갱신 경로)

@Test @MainActor func 갱신하면_제목_기록날짜_레이아웃이_바뀌고_updatedAt이_now가_된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let c = try repo.createCanvas(canvasInput(title: "제주", createdAt: anchor),
                                      in: a, now: anchor)

        let 기록날짜 = try day(-2, from: anchor)
        let 갱신시각 = try day(1, from: anchor)
        let layout = Data(#"{"v":2}"#.utf8)
        try repo.updateCanvas(c, title: "부산", createdAt: 기록날짜,
                              layoutJSON: layout, now: 갱신시각)

        #expect(c.title == "부산")
        #expect(c.createdAt == 기록날짜)
        #expect(c.layoutJSON == layout)
        #expect(c.updatedAt == 갱신시각)
    }
}

@Test @MainActor func 갱신은_소속과_렌더_이미지를_건드리지_않는다() throws {
    // updateCanvas는 소속을 아예 받지 않는다 — 소속 변경의 단일 경로는 moveCanvas다.
    // renderedPNG도 받지 않는다: 수 MB 블롭이라 제목만 고치는 호출에서 다시 대입되면
    // 레코드가 더티가 되어 CKAsset이 통째로 재업로드된다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let png = Data(repeating: 0xAB, count: 1024)
        let c = try repo.createCanvas(
            canvasInput(title: "제주", createdAt: anchor, renderedPNG: png),
            in: a, now: anchor)

        try repo.updateCanvas(c, title: "부산", createdAt: anchor,
                              layoutJSON: Data(), now: try day(1, from: anchor))

        #expect(c.collection?.id == a.id)
        #expect(c.renderedPNG == png)
    }
}

@Test @MainActor func 갱신_경로에서도_마흔한자_제목은_거부된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let c = try repo.createCanvas(canvasInput(title: "제주", createdAt: anchor),
                                      in: a, now: anchor)

        #expect(throws: 한계초과_제목_에러) {
            try repo.updateCanvas(c, title: 한계초과_제목,
                                  createdAt: anchor, layoutJSON: Data(), now: anchor)
        }
        #expect(c.title == "제주")   // 부분 반영이 없다
    }
}

@Test @MainActor func 갱신에서도_미래_기록_날짜가_보존된다() throws {
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let c = try repo.createCanvas(canvasInput(createdAt: anchor), in: a, now: anchor)
        let future = try day(30, from: anchor)

        try repo.updateCanvas(c, title: "", createdAt: future,
                              layoutJSON: Data(), now: anchor)

        #expect(c.createdAt == future)
    }
}

@Test @MainActor func 표지_캔버스의_날짜를_과거로_밀어도_표지는_유지된다() throws {
    // 갱신 경로에도 재계산을 부른다 — "모든 변경 뒤에 재계산"에 예외를 두면
    // 그 예외가 곧 빠뜨릴 자리가 된다. 재계산이 표지를 흔들지 않는지 본다.
    try withLibrary { repo, _ in
        let anchor = try testAnchor()
        let a = try repo.createCollection(name: "여행", now: anchor)
        let c1 = try repo.createCanvas(canvasInput(title: "첫", createdAt: anchor),
                                       in: a, now: anchor)
        let later = try day(2, from: anchor)
        try repo.createCanvas(canvasInput(title: "둘", createdAt: later), in: a, now: later)

        // 표지인 c1을 가장 오래된 캔버스로 만들어도 BR-6이 AC-7을 이기지 않는다.
        try repo.updateCanvas(c1, title: "첫", createdAt: try day(-10, from: anchor),
                              layoutJSON: Data(), now: try day(3, from: anchor))

        #expect(a.coverCanvasID == c1.id.uuidString)
    }
}

import Testing
import Foundation
import SwiftData
@testable import Soozip

// LibraryRepository — 모음집 CRUD와 정렬 (AC-14·15·29·31).

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

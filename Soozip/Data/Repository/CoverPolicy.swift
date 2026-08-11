import Foundation

/// 표지 판정 + 불변식. 생성·삭제·이동 세 지점과 조회(AC-18)가 전부 이 판정 하나를 쓴다.
enum CoverPolicy {
    static func resolve(in canvases: [Canvas], coverID: String) -> Canvas? {
        guard !canvases.isEmpty else { return nil }
        if let matched = canvases.first(where: { $0.id.uuidString == coverID }) {
            return matched
        }
        // (createdAt, id.uuidString) 최댓값. createdAt이 같은 캔버스가 둘이면
        // id.uuidString을 2차 키로 써서 결과를 결정적으로 만든다 — 그렇지 않으면
        // 배열 순서에 의존하게 되는데 SwiftData to-many 순서는 보장되지 않는다.
        return canvases.max { a, b in
            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
        }
    }

    static func reconcile(_ collection: Collection, candidates: [Canvas]) {
        // coverCanvasID에 대입하는 유일한 지점이다. 값이 같으면 대입하지 않는다 —
        // 무조건 대입하면 Collection 레코드가 매번 더티가 되어 CloudKit이 변경 없는
        // 레코드를 계속 올리고, LWW 판정 대상(v4 §6.9)이 늘어 충돌 표면이 넓어진다.
        let newValue = resolve(in: candidates, coverID: collection.coverCanvasID)?.id.uuidString ?? ""
        if collection.coverCanvasID != newValue {
            collection.coverCanvasID = newValue
        }
    }

    /// 사용자가 대표 캔버스를 직접 고른다. 성공하면 `true`.
    ///
    /// **대입은 여전히 이 타입 안에서만 일어난다.** 지정 경로가 생겼다고 리포지토리가
    /// `coverCanvasID`에 직접 쓰면, `uuidString`은 대문자를 내는데 `UUID(uuidString:)`은
    /// 소문자도 받는 비대칭이 대입 지점마다 스며들 자리를 얻는다.
    ///
    /// 후보에 없는 캔버스는 거부한다. 다른 모음집의 캔버스가 표지가 되는 것이
    /// 정확히 `isConsistent`가 막는 상태다 — "표지가 이 모음집에 없는 캔버스를 가리킨다".
    @discardableResult
    static func designate(_ canvas: Canvas, for collection: Collection,
                          candidates: [Canvas]) -> Bool {
        guard candidates.contains(where: { $0.id == canvas.id }) else { return false }
        collection.coverCanvasID = canvas.id.uuidString
        return true
    }

    static func isConsistent(_ collection: Collection, candidates: [Canvas]) -> Bool {
        // 이 계층의 불변식. 개별 AC는 아는 경로만 막지만 불변식은 아직 짜지 않은
        // 경로까지 막는다 — 실제로 초안 설계의 업서트가 AC 어디에도 안 걸리면서
        // "표지=C1인데 소속 캔버스 0장"을 만들었다.
        collection.coverCanvasID.isEmpty
            || candidates.contains { $0.id.uuidString == collection.coverCanvasID }
    }
}

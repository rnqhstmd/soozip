import Foundation

/// 편집 중인 레이어 목록 (v4 §5.2 · §5.11).
///
/// **배열 순서가 진실이고 z는 인덱스에서 파생된다.**
///
/// v4 §5.11이 "재정렬 시 0부터 다시 촘촘히 매긴다(빈 번호가 쌓이면 상한에
/// 부딪힌다)"고 요구하는데, z를 필드로 들고 조작마다 재번호하면 **조작 6종 중
/// 한 곳에서라도 빠뜨리면 구멍이 생긴다.** 순서를 진실로 삼으면 재번호 코드
/// 자체가 없어지고 촘촘함이 깨질 수 없는 성질이 된다.
///
/// `CanvasSurface`에서 "배율·뷰포트에 독립인 것만 저장한다"고 정한 것과 같은
/// 원리다 — 불변식을 지키는 코드를 쓰는 대신, **불변식이 성립할 수밖에 없는
/// 표현**을 고른다.
public struct LayerStore: Equatable, Sendable {

    /// 스토어 안의 레이어 하나. `id`는 **편집 세션 안에서만 산다.**
    ///
    /// `layoutJSON`(v4 §8)에 레이어 id 필드가 없고, 넣으면 저장 형식이 바뀐다.
    /// 재편집으로 문서를 열 때마다 새로 발급하면 되므로 영속화할 이유가 없다.
    ///
    /// **`PhotoLayer.assetId`를 키로 쓸 수 없다** — 복제본은 `assetId`를
    /// 공유하므로(v4 §5.12.1) 복제된 사진 넷이 같은 값을 갖는다.
    public struct Entry: Equatable, Sendable, Identifiable {
        public let id: UUID
        public var layer: Layer

        public init(id: UUID = UUID(), layer: Layer) {
            self.id = id
            self.layer = layer
        }
    }

    /// 뒤에서 앞 순서. **인덱스가 곧 z다.**
    public private(set) var entries: [Entry]

    /// 문서에서 불러온다. z 오름차순으로 정렬해 담는다.
    public init(_ layers: [Layer]) {
        // **안정 정렬이어야 한다.** Swift의 `sorted(by:)`는 안정성을 보장하지
        // 않아서, z가 같은 레이어들의 순서가 실행마다 달라질 수 있다 — 같은
        // 파일이 열 때마다 다르게 보인다. 원래 인덱스를 2차 키로 쓴다
        // (`LibraryRepository.canvases(in:)`가 같은 이유로 `id`를 2차 키로 쓴다).
        entries = layers.enumerated()
            .sorted { ($0.element.transform.z, $0.offset) < ($1.element.transform.z, $1.offset) }
            .map { Entry(layer: $0.element) }
    }

    /// 저장·렌더용 레이어 목록. **z가 인덱스로 채워져 나간다.**
    public var layers: [Layer] {
        entries.enumerated().map { index, entry in
            var layer = entry.layer
            layer.transform.z = index
            return layer
        }
    }

    // MARK: - 삽입·삭제

    /// 새 레이어를 **맨 앞**에 놓는다.
    @discardableResult
    public mutating func insert(_ layer: Layer) -> UUID {
        let entry = Entry(layer: layer)
        entries.append(entry)
        return entry.id
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    // MARK: - z-order (v4 §5.11)

    public mutating func bringToFront(_ id: UUID) {
        // `entries.count`를 클로저 안에서 읽으면 `move`의 배타 접근과 겹친다.
        // 개수는 `move`가 인자로 넘겨준다.
        move(id) { _, count in count - 1 }
    }

    public mutating func sendToBack(_ id: UUID) {
        move(id) { _, _ in 0 }
    }

    public mutating func bringForward(_ id: UUID) {
        move(id) { from, count in min(from + 1, count - 1) }
    }

    public mutating func sendBackward(_ id: UUID) {
        move(id) { from, _ in max(from - 1, 0) }
    }

    // MARK: - 내부

    /// **없는 식별자는 조용히 무시한다.** 선택된 레이어가 다른 경로로 지워진
    /// 뒤에 속성바 버튼이 눌리는 경합이 실제로 있고, 그때 크래시할 이유가 없다.
    private mutating func move(_ id: UUID, to destination: (Int, Int) -> Int) {
        guard let from = entries.firstIndex(where: { $0.id == id }) else { return }
        let to = destination(from, entries.count)
        guard to != from else { return }
        let entry = entries.remove(at: from)
        entries.insert(entry, at: to)
    }
}

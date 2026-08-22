import Foundation
import SoozipGeometry

/// 삽입 거부 사유 (v4 §5.13).
///
/// **조용히 `nil`을 돌려주지 않는다** — 호출부가 무시할 수 있고, 그러면 사용자가
/// 넣었다고 생각한 레이어가 없는 채로 진행된다. 케이스가 범주와 상한을 들고
/// 있어야 호출부가 "사진은 8장까지 넣을 수 있어요"를 만든다.
///
/// 정상 흐름에서는 도구 버튼이 이미 비활성이므로(`canInsert`) 던지는 일 자체가
/// 드물다 — **던진다는 것은 배선이 판정을 안 썼다는 신호다.**
public enum LayerLimitError: Error, Equatable {
    case limitReached(category: LayerCategory, limit: Int)
}

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
    ///
    /// 저장된 레이어의 `transform.z`는 **의미가 없다** — 0으로 눕혀 둔다. z는
    /// 읽을 때 인덱스에서 채운다(`entries`·`layers`). 저장해 두면 조작마다
    /// 갱신해야 하고, 빠뜨리면 저장값과 인덱스가 어긋난다. 값이 없으면
    /// 어긋날 수도 없고, `Equatable`도 순서만 보게 되어 정의가 분명해진다.
    private var storage: [Entry]

    /// 현재 선택된 레이어의 식별자. 없으면 `nil`.
    ///
    /// 선택은 합성 `Equatable`에 포함된다. **`LayerStore ==`로 저장 dirty를
    /// 판정하지 마라** — 선택은 layoutJSON에 없어서 레이어를 탭하기만 해도
    /// `==`는 달라지지만 저장될 바이트는 그대로다. `CANVAS-5`(1.5초 디바운스
    /// 자동 저장)나 실행취소 스냅샷이 이 비교를 dirty 판정에 쓰면 탭마다
    /// 저장이 돌고, 실행취소 스택이 선택 변경으로 채워져 사용자가 되돌리려던
    /// 편집이 밀려난다. 판정 기준은 `layers`(또는 인코딩 결과)여야 한다.
    private var selectedID: UUID?

    /// 뒤에서 앞 순서. **`z`가 인덱스로 채워져 나간다.**
    ///
    /// `layers`와 같은 규칙을 쓴다 — 한쪽만 채우면 `EDITOR-4`가 선택 대상을
    /// 고를 때(v4 §5.11 "같은 지점을 탭하면 z-order 최상단") 낡은 z를 보고
    /// **맨 아래 레이어를 최상단으로 고른다.**
    public var entries: [Entry] {
        storage.enumerated().map { index, entry in
            var filled = entry
            filled.layer.transform.z = index
            return filled
        }
    }

    /// 문서에서 불러온다. z 오름차순으로 정렬해 담는다.
    public init(_ layers: [Layer]) {
        // **안정 정렬이어야 한다.** Swift의 `sorted(by:)`는 안정성을 보장하지
        // 않아서, z가 같은 레이어들의 순서가 실행마다 달라질 수 있다 — 같은
        // 파일이 열 때마다 다르게 보인다. 원래 인덱스를 2차 키로 쓴다
        // (`LibraryRepository.canvases(in:)`가 같은 이유로 `id`를 2차 키로 쓴다).
        storage = layers.enumerated()
            .sorted { ($0.element.transform.z, $0.offset) < ($1.element.transform.z, $1.offset) }
            .map { pair in
                var layer = pair.element
                layer.transform.z = 0        // 저장값은 의미 없음 — 위 주석 참조
                return Entry(layer: layer)
            }
    }

    /// 저장·렌더용 레이어 목록. **z가 인덱스로 채워져 나간다.**
    public var layers: [Layer] { entries.map(\.layer) }

    // MARK: - 선택 (v4 §5.11)

    /// 현재 선택된 항목. **`entries`에서 파생한다** — `storage`에서 직접
    /// 찾으면 z가 항상 0이라 z-order 조작 뒤 낡은 값을 보여준다.
    public var selection: Entry? {
        entries.first { $0.id == selectedID }
    }

    /// 단일 선택. **저장소에 있는 id일 때만 선택한다.** `move`와 달리 이전
    /// 상태를 보존하지 않고 "선택 없음"으로 정규화한다 — 탭이 아무것도
    /// 맞히지 못한 것과 같게 본다. 유효한 선택이 있는 상태에서 사라진
    /// 레이어의 id로 불리면 그 선택도 함께 해제된다.
    ///
    /// 없는 id를 그대로 저장하면 `selection` 조회는 파생 덕에 nil을 보여줘도
    /// `Equatable`이 select를 하지 않은 동일한 스토어와 갈라진다.
    public mutating func select(_ id: UUID) {
        selectedID = storage.contains { $0.id == id } ? id : nil
    }

    /// `select`가 저장소에 없는 id를 정규화해 도달하는 상태와 같다 — 선택 없음.
    public mutating func deselect() {
        selectedID = nil
    }

    // MARK: - 삽입·삭제

    /// 새 레이어를 **맨 앞**에 놓고 그 식별자를 돌려준다.
    ///
    /// 반환값은 버리는 값이 아니다 — `TOOL-3`(복제)이 v4 §5.12.1의 "복제본이
    /// 선택 상태가 된다"를 구현하려면 이 값을 선택에 넣어야 한다.
    ///
    /// - Throws: 그 범주가 상한에 도달했으면 `LayerLimitError.limitReached`.
    ///   **복제도 이 경로를 타므로 상한에 함께 걸린다**(v4 §5.12.1).
    @discardableResult
    public mutating func insert(_ layer: Layer) throws -> UUID {
        let category = layer.category
        guard canInsert(category) else {
            throw LayerLimitError.limitReached(category: category, limit: category.limit)
        }
        var stored = layer
        stored.transform.z = 0
        let entry = Entry(layer: stored)
        storage.append(entry)
        return entry.id
    }

    // MARK: - 상한 (v4 §5.13)

    /// 그 범주의 레이어 수.
    public func count(_ category: LayerCategory) -> Int {
        storage.reduce(0) { $0 + ($1.layer.category == category ? 1 : 0) }
    }

    /// 더 넣을 수 있는 개수. **음수가 되지 않는다** — 다른 버전이 만들었거나
    /// 손상된 문서는 상한을 넘긴 채로 들어올 수 있다.
    public func remaining(_ category: LayerCategory) -> Int {
        max(0, category.limit - count(category))
    }

    /// 도구 버튼 활성 판정 (v4 §5.13 "상한 도달 시 해당 도구를 비활성화").
    public func canInsert(_ category: LayerCategory) -> Bool {
        remaining(category) > 0
    }

    public mutating func remove(_ id: UUID) {
        storage.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = nil
        }
    }

    // MARK: - 배치 (EDITOR-10)

    /// 저장된 레이어의 중심을 옮기는 **유일한 공개 경로**다.
    ///
    /// 이름이 `move`가 아닌 이유: 이 타입에는 이미 z-order 내부 구현으로
    /// `private mutating func move(_:to:)`가 있다. 공개 API 이름도 move로
    /// 지으면 `move(id, to: ClampedLayerCenter)`가 그 내부 오버로드와
    /// 인자 타입만 다른 형제로 자동완성에 나란히 뜬다 — 이름을 갈라 그
    /// 혼동을 없앤다.
    ///
    /// **없는 식별자는 크래시 없이 조용히 무시한다.** `move(_:to:)`·
    /// `remove(_:)`와 같은 관례이고, PRD BR-6("레이어 라우팅 결과는 대상
    /// 존재를 보장하지 않는다 — 없으면 크래시 없이 조용히 무시")과 정확히
    /// 같은 계약이다. 같은 이유로 `Bool`을 반환하지 않는다 — 반환하면
    /// 호출부가 성공·실패로 분기하게 되는데, BR-6이 요구하는 것은 분기가
    /// 아니라 무시다.
    ///
    /// `x`·`y`를 여기서 직접 대입하지 않고 `transform.placed(at:)`에
    /// 위임한다 — 직접 쓰면 좌표를 바꾸는 규칙이 두 벌이 되고, 그러면
    /// 한쪽만 나머지 네 필드(z 등)를 보존하는 사고가 난다.
    ///
    /// ⚠️ 이 함수는 봉쇄가 아니라 선점이다. `storage`가 `private`인 것은
    /// **모듈 밖에서** `entry.layer.transform.x = ...`를 막을 뿐이다 —
    /// `SoozipLayout` 모듈 **안**에서는 이 파일이 여전히 `storage`에 직접
    /// 접근할 수 있고, 그 사실 자체는 이 함수가 있어도 바뀌지 않는다. 이
    /// 함수가 하는 일은 `EDITOR-11`이 레이어를 옮길 때 없는 경로를 새로
    /// 발명하는 대신 있는 경로(`place`)를 쓰게 하는 것뿐이다 — 모듈 밖은
    /// 닫혀 있고, 모듈 안에는 옳은 경로가 하나 놓였을 뿐이다.
    public mutating func place(_ id: UUID, at center: ClampedLayerCenter) {
        guard let index = storage.firstIndex(where: { $0.id == id }) else { return }
        let placedTransform = storage[index].layer.transform.placed(at: center)
        storage[index].layer.transform = placedTransform
    }

    // MARK: - z-order (v4 §5.11)

    public mutating func bringToFront(_ id: UUID) {
        // `storage.count`를 클로저 안에서 읽으면 `move`의 배타 접근과 겹친다.
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
        // **식별자로 찾는다.** 레이어 값으로 찾으면 복제본(모든 속성을 승계하고
        // `assetId`까지 공유한다 — v4 §5.12.1)이 원본과 구별되지 않아, 복제본을
        // 앞으로 보내면 원본이 움직인다.
        guard let from = storage.firstIndex(where: { $0.id == id }) else { return }
        let to = destination(from, storage.count)
        guard to != from else { return }
        let entry = storage.remove(at: from)
        storage.insert(entry, at: to)
    }
}

import Foundation
import SwiftData
import SoozipDraft
import SoozipLayout

/// 승격 실패 사유. 케이스가 맥락을 들고 있어야 호출부가 사용자에게 보여줄
/// 문구를 만들 수 있다(`RepositoryError`와 같은 규칙).
enum PromotionError: Error, Equatable {
    /// 레이어 상한 위반. 무엇이 몇 개 넘었는지는 `LayoutViolation`이 안다.
    case layoutInvalid(LayoutViolation)
    /// 초안이 없다.
    case draftNotFound(canvasID: String)
    /// 초안이 가리키는 모음집이 없다 — 다른 기기에서 지웠거나 메타가 손상됐다.
    case collectionNotFound(collectionID: String)
}

/// 초안을 저장 확정된 `Canvas`로 승격한다 (v4 §6.6).
///
/// **이 타입의 존재 이유는 순서다.** 7단계 중 2~5가 전부 성공해야 6(초안 삭제)을
/// 실행한다. 순서를 바꿔 초안을 먼저 지우면 저장 실패 시 사용자의 작업물이
/// 증발한다 — 이 도메인의 한 줄 약속이 "작업물이 절대 증발하지 않는다"다.
@MainActor
struct CanvasPromoter {

    let store: DraftStore
    let library: LibraryRepository

    /// 2단계 렌더러. `layoutJSON` → `renderedPNG`.
    ///
    /// **주입받는 이유가 둘이다.** 실제 렌더러(`ImageRenderer`)는 에디터 표면에
    /// 딸려 있어 아직 없고, 더 중요하게는 **주입이 아니면 "렌더가 실패해도 초안이
    /// 남는가"를 테스트할 수 없다.** 그게 이 단위의 존재 이유라, 렌더러를 안에서
    /// 만들면 검증하려던 것을 검증 못 하게 된다.
    let render: (LayoutDocument) throws -> Data

    init(store: DraftStore, library: LibraryRepository,
         render: @escaping (LayoutDocument) throws -> Data) {
        self.store = store
        self.library = library
        self.render = render
    }

    /// 초안을 승격한다. 성공하면 만들어진 `Canvas`를 돌려준다.
    ///
    /// - Parameter cleanup: 6단계(초안 폴더 삭제). 기본은 `store.delete`이고,
    ///   테스트가 실패를 주입할 때만 바꾼다.
    @discardableResult
    func promote(canvasID: String, now: Date,
                 cleanup: ((String) throws -> Void)? = nil) throws -> Canvas {

        // ── 1. 검증 ─────────────────────────────────────────────
        // 상한 판정은 `LayoutDocument.validate()`가 이미 한다. 여기서 다시 세면
        // 상한 규칙이 두 곳으로 갈라진다.
        guard let draft = try store.load(canvasID: canvasID) else {
            throw PromotionError.draftNotFound(canvasID: canvasID)
        }
        let document = try store.readLayout(canvasID: canvasID)
        if let violation = document.validate() {
            throw PromotionError.layoutInvalid(violation)
        }
        guard let collection = try collection(withID: draft.meta.collectionID) else {
            throw PromotionError.collectionNotFound(collectionID: canvasID)
        }

        // ── 2. 렌더 ─────────────────────────────────────────────
        let rendered = try render(document)

        // ── 3. 사진 이관 ────────────────────────────────────────
        // **DB에 쓰기 전에 전부 읽는다.** 읽다가 실패하면 아무것도 안 만든 상태로
        // 빠져나와야 하는데, 중간에 쓰기 시작하면 반쯤 만들어진 캔버스가 남는다.
        let photoData = try photoBytes(of: document, canvasID: canvasID)

        // ── 4·5. DB 쓰기 + 표지 갱신 ────────────────────────────
        // `createCanvas`가 표지 재계산까지 한다(Phase 1). 여기서 따로 부르면
        // 재계산 지점이 늘어 `CoverPolicy` 단일 대입 규약이 흔들린다.
        let input = CanvasInput(id: UUID(uuidString: canvasID) ?? UUID(),
                                aspect: draft.meta.aspect,
                                createdAt: draft.meta.createdAt,
                                layoutJSON: try JSONEncoder.draft.encode(document),
                                renderedPNG: rendered)
        let canvas = try library.createCanvas(input, in: collection, now: now)
        try attach(photoData, to: canvas)

        // ── 6. 정리 ─────────────────────────────────────────────
        // **여기서 실패해도 되돌리지 않는다.** 2~5가 다 됐는데 폴더 삭제만
        // 실패했다고 캔버스를 롤백하면, 사용자는 정리 실패 때문에 저장을 잃는다.
        // 남은 고아 초안은 다음 실행의 `pruneOrphans`가 치운다.
        try? (cleanup ?? store.delete)(canvasID)

        return canvas
    }

    // MARK: - 내부

    private func collection(withID id: String) throws -> Collection? {
        // 대소문자를 구분하지 않는다 — `uuidString`은 대문자를 내지만
        // `UUID(uuidString:)`은 소문자도 받는다(`DraftStore`와 같은 계약).
        let target = id.uppercased()
        return try library.collections().first { $0.id.uuidString.uppercased() == target }
    }

    /// 레이아웃이 참조하는 사진 원본. **`assetId` 기준으로 중복을 없앤다.**
    ///
    /// 복제 레이어는 같은 `assetId`를 공유한다(BR-5). 레이어마다 읽어 저장하면
    /// 같은 2000px 사진이 레이어 수만큼 저장되어 용량이 배로 뛴다.
    private func photoBytes(of document: LayoutDocument,
                            canvasID: String) throws -> [String: Data] {
        var assetIDs: Set<String> = []
        for layer in document.layers {
            if case .photo(let photo) = layer { assetIDs.insert(photo.assetId) }
        }

        var bytes: [String: Data] = [:]
        for assetID in assetIDs.sorted() {
            bytes[assetID] = try store.readPhoto(assetID: assetID, canvasID: canvasID)
        }
        return bytes
    }

    private func attach(_ bytes: [String: Data], to canvas: Canvas) throws {
        for (_, data) in bytes.sorted(by: { $0.key < $1.key }) {
            let photo = CanvasPhoto()
            photo.data = data
            photo.canvas = canvas
            library.context.insert(photo)
        }
        try library.context.save()
    }
}

private extension JSONEncoder {
    /// 초안과 **같은 설정**으로 인코딩한다. 설정이 다르면 날짜 표기가 갈라져
    /// 재편집이 사용자가 만든 것과 다른 것을 연다.
    static var draft: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

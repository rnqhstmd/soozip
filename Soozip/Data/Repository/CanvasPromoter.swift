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
    /// `layout.json`을 읽을 수 없다 — 쓰다가 죽었거나 부분 복원됐다.
    case layoutUnreadable(canvasID: String)
    /// 식별자가 UUID 문자열이 아니다. **조용히 새 값을 발급하지 않는다** —
    /// 그러면 초안과 캔버스가 다른 것이 되고 아무도 모른다.
    case malformedIdentifier(String)
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
        // 초안 식별자가 그대로 캔버스 식별자가 된다. 파싱에 실패하면 **던진다** —
        // 새 UUID로 대체하면 승격 전후로 같은 캔버스가 다른 것이 되고, 재편집이
        // 원본을 못 찾는데 아무 신호도 없다.
        guard let canvasUUID = UUID(uuidString: canvasID) else {
            throw PromotionError.malformedIdentifier(canvasID)
        }

        // 원본 바이트와 디코딩본을 함께 얻는다. 저장에는 원본을 쓴다(아래 4단계).
        let layoutData: Data
        let document: LayoutDocument
        do {
            layoutData = try store.readLayoutData(canvasID: canvasID)
            document = try store.readLayout(canvasID: canvasID)
        } catch {
            // `DraftStoreError`를 그대로 흘리지 않는다. 이 API의 실패 어휘는
            // `PromotionError`이고, 호출부가 그것만 보고 분기할 수 있어야 한다.
            throw PromotionError.layoutUnreadable(canvasID: canvasID)
        }

        if let violation = document.validate() {
            throw PromotionError.layoutInvalid(violation)
        }
        guard let collection = try collection(withID: draft.meta.collectionID) else {
            throw PromotionError.collectionNotFound(collectionID: draft.meta.collectionID)
        }

        // ── 2. 렌더 ─────────────────────────────────────────────
        let rendered = try render(document)

        // ── 3. 사진 이관 ────────────────────────────────────────
        // **DB에 쓰기 전에 전부 읽는다.** 읽다가 실패하면 아무것도 안 만든 상태로
        // 빠져나와야 하는데, 중간에 쓰기 시작하면 반쯤 만들어진 캔버스가 남는다.
        let photos = try photoRecords(of: document, canvasID: canvasID)

        // ── 4·5. DB 쓰기 + 표지 갱신 ────────────────────────────
        // `createCanvas`가 표지 재계산까지 한다(Phase 1). 여기서 따로 부르면
        // 재계산 지점이 늘어 `CoverPolicy` 단일 대입 규약이 흔들린다.
        //
        // `layoutJSON`은 **초안의 원본 바이트 그대로**다. 디코딩본을 다시 인코딩하면
        // 양쪽 인코더 설정이 갈라지는 순간 사용자가 만든 것과 다른 바이트가 남는다.
        let input = CanvasInput(id: canvasUUID,
                                aspect: draft.meta.aspect,
                                createdAt: draft.meta.createdAt,
                                layoutJSON: layoutData,
                                renderedPNG: rendered)
        let canvas = try library.createCanvas(input, in: collection, now: now)

        do {
            try attach(photos, to: canvas)
        } catch {
            // **보상 삭제.** `createCanvas`는 이미 저장을 끝냈으므로(표지 재계산이
            // save를 요구한다) 여기서 손을 떼면 **사진이 빠진 캔버스가 남고, 그것이
            // 모음집 표지일 수도 있다.** 사용자가 재시도하면 같은 식별자의 캔버스가
            // 하나 더 생긴다 — `@Attribute(.unique)`는 CloudKit 제약상 못 쓴다.
            try? library.deleteCanvas(canvas)
            throw error
        }

        // ── 6. 정리 ─────────────────────────────────────────────
        // **여기서 실패해도 되돌리지 않는다.** 2~5가 다 됐는데 폴더 삭제만
        // 실패했다고 캔버스를 롤백하면, 사용자는 정리 실패 때문에 저장을 잃는다.
        //
        // 남은 초안은 **바로 치워지지 않는다** — `pruneOrphans`는 소속이 사라졌거나
        // 7일이 지난 것만 지우는데, 방금 저장한 캔버스의 초안은 둘 다 아니다.
        // 그동안 "이어서 만들까요?" 배너가 뜬다(`CANVAS-6`에서 함께 설계).
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

    /// 레이아웃이 참조하는 사진. **`assetId` 기준으로 중복을 없앤다.**
    ///
    /// 복제 레이어는 같은 `assetId`를 공유한다(BR-5). 레이어마다 읽어 저장하면
    /// 같은 2000px 사진이 레이어 수만큼 저장되어 용량이 배로 뛴다.
    private func photoRecords(of document: LayoutDocument,
                              canvasID: String) throws -> [(id: UUID, data: Data)] {
        var assetIDs: Set<String> = []
        for layer in document.layers {
            if case .photo(let photo) = layer { assetIDs.insert(photo.assetId) }
        }

        var records: [(id: UUID, data: Data)] = []
        for assetID in assetIDs.sorted() {
            guard let id = UUID(uuidString: assetID) else {
                throw PromotionError.malformedIdentifier(assetID)
            }
            records.append((id, try store.readPhoto(assetID: assetID, canvasID: canvasID)))
        }
        return records
    }

    /// **`assetId`를 `CanvasPhoto.id`로 그대로 옮긴다.**
    ///
    /// 이게 레이어와 사진을 잇는 유일한 끈이다(`CanvasPhoto` 선언부 참조).
    /// 새 UUID를 발급하면 `layoutJSON`의 `assetId`가 아무것도 가리키지 못하고,
    /// **저장된 데이터만으로는 어느 레이어가 어느 사진인지 복원할 수 없다** —
    /// 재편집도 재렌더도 그때부터 불가능해진다.
    private func attach(_ photos: [(id: UUID, data: Data)], to canvas: Canvas) throws {
        for photo in photos {
            let record = CanvasPhoto()
            record.id = photo.id
            record.data = photo.data
            record.canvas = canvas
            library.context.insert(record)
        }
        try library.context.save()
    }
}

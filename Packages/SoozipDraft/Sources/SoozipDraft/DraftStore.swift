import Foundation
import SoozipLayout

// MARK: - 사진 형식

/// 사진 사본의 저장 형식. 알파 채널이 있으면 PNG, 없으면 JPEG (v4 §5.12.3).
public enum PhotoFormat: String, Codable, Sendable, CaseIterable {
    case jpeg = "jpg"
    case png  = "png"

    var fileExtension: String { rawValue }
}

// MARK: - 메타

/// `meta.json`. 고아 정리의 판단 근거다.
///
/// 폴더명(UUID)만으로는 소속 모음집을 알 수 없고, 파일 mtime은 백업·복원·동기화로
/// 바뀌므로 방치 기간의 근거가 못 된다. 그래서 우리가 직접 기록한다.
public struct DraftMeta: Codable, Equatable, Sendable {
    public var canvasID: String
    public var collectionID: String
    public var aspect: CanvasAspect
    public var createdAt: Date
    public var updatedAt: Date

    public init(canvasID: String, collectionID: String, aspect: CanvasAspect,
                createdAt: Date, updatedAt: Date) {
        self.canvasID = canvasID
        self.collectionID = collectionID
        self.aspect = aspect
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 초안 하나.
public struct Draft: Equatable, Sendable {
    public let meta: DraftMeta
    public let directory: URL
}

// MARK: - 에러

public enum DraftStoreError: Error, Equatable {
    case draftNotFound(canvasID: String)
    case layoutNotFound(canvasID: String)
    case photoNotFound(assetID: String, canvasID: String)
}

// MARK: - 저장소

/// 초안 파일 저장소.
///
/// **루트 경로를 주입받는다.** 앱에서는 `Application Support/Drafts`를, 테스트에서는
/// 임시 폴더를 넘긴다. 이 설계 덕에 Foundation만으로 동작하며 플랫폼에 의존하지 않는다.
///
/// 초안은 **SwiftData에 넣지 않는다**(v4 §6.2). CloudKit이 미완성 캔버스를 다른 기기로
/// 동기화하는 것을 막고, 모든 쿼리에 `isDraft == false` 필터를 다는 일을 피하기 위해서다.
public struct DraftStore: Sendable {

    public let root: URL

    private static let metaFile = "meta.json"
    private static let layoutFile = "layout.json"
    private static let photosDir = "photos"

    public init(root: URL) {
        self.root = root
    }

    /// `FileManager`를 저장 프로퍼티로 들지 않는 이유:
    /// corelibs-foundation(Windows)에서는 `Sendable`이지만 **Darwin에서는 아니다.**
    /// 들고 있으면 이 구조체의 `Sendable` 선언이 macOS에서만 깨져,
    /// Windows에서 통과한 테스트가 Mac에서 컴파일조차 되지 않는다.
    ///
    /// 주입 파라미터를 없앤 것은 아무도 쓰지 않았기 때문이다. 테스트 24개 전부
    /// 임시 디렉터리 경로만 넘긴다. 정말 필요해지면 그때 프로토콜로 뺀다.
    /// `FileManager.default`는 여러 스레드에서 호출해도 안전하다고 문서화돼 있다.
    private var fm: FileManager { .default }

    // MARK: 경로

    private func directory(_ canvasID: String) -> URL {
        root.appendingPathComponent(canvasID, isDirectory: true)
    }

    private func metaURL(_ canvasID: String) -> URL {
        directory(canvasID).appendingPathComponent(Self.metaFile)
    }

    private func layoutURL(_ canvasID: String) -> URL {
        directory(canvasID).appendingPathComponent(Self.layoutFile)
    }

    private func photosURL(_ canvasID: String) -> URL {
        directory(canvasID).appendingPathComponent(Self.photosDir, isDirectory: true)
    }

    // MARK: 인코더

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: 생성 · 조회

    /// 초안 폴더와 `meta.json`을 만든다. 이미 있으면 메타를 덮어쓴다.
    @discardableResult
    public func create(canvasID: String, collectionID: String,
                       aspect: CanvasAspect, now: Date) throws -> Draft {
        let dir = directory(canvasID)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.createDirectory(at: photosURL(canvasID), withIntermediateDirectories: true)

        let meta = DraftMeta(canvasID: canvasID, collectionID: collectionID,
                             aspect: aspect, createdAt: now, updatedAt: now)
        try encoder.encode(meta).write(to: metaURL(canvasID), options: .atomic)
        return Draft(meta: meta, directory: dir)
    }

    /// 초안을 읽는다. 없거나 메타가 깨졌으면 `nil`.
    public func load(canvasID: String) throws -> Draft? {
        let url = metaURL(canvasID)
        guard fm.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let meta = try? decoder.decode(DraftMeta.self, from: data) else {
            return nil
        }
        return Draft(meta: meta, directory: directory(canvasID))
    }

    /// 모든 초안. 루트가 없으면 빈 배열 — 첫 실행에는 폴더 자체가 없다.
    public func all() throws -> [Draft] {
        guard fm.fileExists(atPath: root.path) else { return [] }
        let entries = try fm.contentsOfDirectory(atPath: root.path)
        return entries.compactMap { try? load(canvasID: $0) }.compactMap { $0 }
    }

    /// 해당 모음집의 초안. **초안은 모음집당 1개**다(v4 §6.5).
    public func draft(forCollection collectionID: String) throws -> Draft? {
        try all().first { $0.meta.collectionID == collectionID }
    }

    // MARK: layout.json

    /// 레이아웃을 덮어쓰고 `updatedAt`을 갱신한다. 1.5초 디바운스로 호출된다.
    public func writeLayout(_ document: LayoutDocument, canvasID: String, now: Date) throws {
        guard let draft = try load(canvasID: canvasID) else {
            throw DraftStoreError.draftNotFound(canvasID: canvasID)
        }
        try encoder.encode(document).write(to: layoutURL(canvasID), options: .atomic)

        var meta = draft.meta      // Draft는 조회 결과라 불변. 메타만 복사해 갱신한다
        meta.updatedAt = now
        try encoder.encode(meta).write(to: metaURL(canvasID), options: .atomic)
    }

    public func readLayout(canvasID: String) throws -> LayoutDocument {
        let url = layoutURL(canvasID)
        guard fm.fileExists(atPath: url.path) else {
            throw DraftStoreError.layoutNotFound(canvasID: canvasID)
        }
        return try decoder.decode(LayoutDocument.self, from: Data(contentsOf: url))
    }

    // MARK: 사진

    /// 사진 사본을 즉시 기록한다. **디바운스 대상이 아니다** — 크래시로 사진이
    /// 날아가면 레이아웃만 복구해도 의미가 없다(v4 §6.5).
    public func writePhoto(_ data: Data, assetID: String,
                           format: PhotoFormat, canvasID: String) throws {
        let dir = photosURL(canvasID)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(assetID).\(format.fileExtension)")
        try data.write(to: url, options: .atomic)
    }

    public func readPhoto(assetID: String, canvasID: String) throws -> Data {
        guard let url = photoURL(assetID: assetID, canvasID: canvasID) else {
            throw DraftStoreError.photoNotFound(assetID: assetID, canvasID: canvasID)
        }
        return try Data(contentsOf: url)
    }

    public func photoFormat(assetID: String, canvasID: String) throws -> PhotoFormat {
        guard let url = photoURL(assetID: assetID, canvasID: canvasID),
              let format = PhotoFormat(rawValue: url.pathExtension) else {
            throw DraftStoreError.photoNotFound(assetID: assetID, canvasID: canvasID)
        }
        return format
    }

    /// 이 초안에 저장된 사진 식별자들. 확장자는 뺀다.
    public func photoIDs(canvasID: String) throws -> [String] {
        let dir = photosURL(canvasID)
        guard fm.fileExists(atPath: dir.path) else { return [] }
        return try fm.contentsOfDirectory(atPath: dir.path)
            .filter { PhotoFormat(rawValue: ($0 as NSString).pathExtension) != nil }
            .map { ($0 as NSString).deletingPathExtension }
    }

    private func photoURL(assetID: String, canvasID: String) -> URL? {
        let dir = photosURL(canvasID)
        for format in PhotoFormat.allCases {
            let url = dir.appendingPathComponent("\(assetID).\(format.fileExtension)")
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: 삭제

    /// 초안 폴더를 통째로 지운다. **없어도 에러를 내지 않는다** — 승격 트랜잭션의
    /// 마지막 단계라, 이미 없다고 실패하면 저장은 성공했는데 에러가 나는 꼴이 된다.
    public func delete(canvasID: String) throws {
        let dir = directory(canvasID)
        guard fm.fileExists(atPath: dir.path) else { return }
        try fm.removeItem(at: dir)
    }

    // MARK: 고아 정리

    /// 앱 시작 시 호출한다. 지운 초안의 폴더명을 반환한다.
    ///
    /// 고아 판정 (v4 §6.9):
    /// 1. 소속 모음집이 더 이상 없다 — 다른 기기에서 모음집을 지웠거나 승격이 꼬였다
    /// 2. `updatedAt`이 `maxAge`를 넘겼다 — **생성이 아니라 마지막 수정 기준**이다.
    ///    오래 전에 만들었어도 어제 편집했으면 살아있는 초안이다
    /// 3. `meta.json`을 읽을 수 없다 — 소속도 시각도 모르므로 남기면 영영 안 지워진다
    @discardableResult
    public func pruneOrphans(knownCollectionIDs: Set<String>,
                             now: Date,
                             maxAge: TimeInterval) throws -> [String] {
        guard fm.fileExists(atPath: root.path) else { return [] }

        var removed: [String] = []
        for entry in try fm.contentsOfDirectory(atPath: root.path).sorted() {
            let dir = root.appendingPathComponent(entry, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let isOrphan: Bool
            if let draft = try load(canvasID: entry) {
                let stale = now.timeIntervalSince(draft.meta.updatedAt) > maxAge
                let lostCollection = !knownCollectionIDs.contains(draft.meta.collectionID)
                isOrphan = stale || lostCollection
            } else {
                isOrphan = true   // 메타 손상 또는 부재
            }

            if isOrphan {
                try fm.removeItem(at: dir)
                removed.append(entry)
            }
        }
        return removed
    }
}

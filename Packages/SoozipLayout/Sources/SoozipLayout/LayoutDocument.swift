import Foundation
import SoozipGeometry

// MARK: - 캔버스 규격

/// 캔버스 비율. **raw value가 SwiftData `Canvas.aspect`에 저장된다**(v4 §7).
/// 값을 바꾸면 기존 캔버스가 깨진다.
public enum CanvasAspect: Int, CaseIterable, Codable, Sendable {
    /// 인스타그램 피드용 4:5
    case post = 0
    /// 인스타그램 스토리용 9:16
    case story = 1

    /// 논리좌표 크기. **폭 1080은 두 프리셋 공통**이라 좌표계 변경이 y축에 그친다.
    public var size: Size2 {
        switch self {
        case .post:  return Size2(width: 1080, height: 1350)
        case .story: return Size2(width: 1080, height: 1920)
        }
    }

    public var displayName: String {
        switch self {
        case .post:  return "게시물"
        case .story: return "스토리"
        }
    }
}

// MARK: - 배경

/// P0는 흰색 고정이다. 종이 질감·단색 변경은 P1(v4 §3).
public struct Background: Codable, Equatable, Sendable {
    public var color: String

    public init(color: String = "#FFFFFF") {
        self.color = color
    }
}

// MARK: - 레이어 범주와 상한

/// 상한이 걸리는 단위 (v4 §5.13).
///
/// **병목은 익스포트 출력이 아니라 디코딩된 비트맵**이라 상한을 전체 개수가
/// 아니라 타입별로 건다. `text`·`shape`·`stamp`는 메모리가 아니라 조작성
/// 문제라 **셋을 합산해** 하나의 범주로 묶는다.
///
/// **분류와 상한이 여기 한 곳에만 있다.** `LayoutDocument.validate()`(사후 판정)와
/// `LayerStore`(삽입 차단)가 둘 다 이것을 쓴다. 두 벌로 갈라지면 삽입은 막히는데
/// 저장은 통과하는(또는 그 반대) 어긋남이 조용히 생긴다.
public enum LayerCategory: CaseIterable, Sendable {
    /// 2000px 한 장 디코딩이 약 16MB. PHPicker 선택 상한과 같은 8이다.
    case photo
    /// PencilKit을 캔버스 크기 비트맵으로 굽기 때문에 한 장이 사진과 맞먹는다.
    case drawing
    /// `text` + `shape` + `stamp` **합산**. 메모리보다 단일 선택 UI의 조작성 문제.
    case decor

    public var limit: Int {
        switch self {
        case .photo:   return 8
        case .drawing: return 5
        case .decor:   return 30
        }
    }

    /// 위반을 보고하는 우선순위.
    ///
    /// **`allCases`(선언 순서)에 기대지 않는다.** 케이스를 재배열하는, 정렬처럼
    /// 무해해 보이는 리팩터가 사용자에게 보이는 안내를 바꿔 버린다 — 사진이
    /// 많은데 "스티커가 많아요"라고 말하게 된다. 우선순위는 의도이므로 명시한다.
    public static let reportingOrder: [LayerCategory] = [.photo, .drawing, .decor]
}

// MARK: - 레이어 상한 위반

/// `LayoutDocument.validate()`의 결과. 상한은 v4 §5.13.
public enum LayoutViolation: Equatable, Sendable {
    /// 사진 레이어 상한. 2000px 디코딩이 약 16MB라 메모리가 병목이다.
    case photoLimitExceeded(count: Int, limit: Int)
    /// 펜 레이어 상한. PencilKit을 캔버스 크기 비트맵으로 굽는다.
    case drawingLimitExceeded(count: Int, limit: Int)
    /// 텍스트+도형+도장 **합산** 상한. 메모리보다 단일 선택 UI의 조작성 문제다.
    case decorLimitExceeded(count: Int, limit: Int)
}

// MARK: - 문서

/// `layoutJSON`의 최상위 구조 (v4 §8).
///
/// 이 한 덩어리가 SwiftData `Canvas.layoutJSON`에 통째로 들어간다. 레이어 스펙이
/// 아무리 늘어도 CloudKit 스키마를 건드리지 않는 이유가 이 설계다.
public struct LayoutDocument: Codable, Equatable, Sendable {

    /// 현재 스키마 버전. 상위 버전 문서는 디코딩을 거부한다.
    public static let currentVersion = 1

    // 상한은 `LayerCategory`에만 있다. 예전의 `photoLimit`/`drawingLimit`/
    // `decorLimit` 별칭은 **호출부가 하나도 없어서 지웠다** — 아무도 안 쓰는
    // 되짚기는 되짚음이 맞는지도 검증되지 않아, 나중에 배선이 붙는 순간
    // 조용히 틀린 상한을 흘릴 수 있다.

    public var v: Int
    public var canvas: Size2
    public var background: Background
    public var layers: [Layer]

    public init(aspect: CanvasAspect,
                background: Background = Background(),
                layers: [Layer]) {
        self.v = Self.currentVersion
        self.canvas = aspect.size
        self.background = background
        self.layers = layers
    }

    // MARK: 검증

    /// 레이어 상한 위반을 찾는다. 위반이 없으면 `nil`.
    public func validate() -> LayoutViolation? {
        // 분류는 `Layer.category`가 한다. 여기서 다시 `switch`를 쓰면 스토어의
        // 삽입 차단과 분류가 두 벌이 된다.
        var counts: [LayerCategory: Int] = [:]
        for layer in layers { counts[layer.category, default: 0] += 1 }

        for category in LayerCategory.reportingOrder {
            let count = counts[category] ?? 0
            guard count > category.limit else { continue }
            switch category {
            case .photo:   return .photoLimitExceeded(count: count, limit: category.limit)
            case .drawing: return .drawingLimitExceeded(count: count, limit: category.limit)
            case .decor:   return .decorLimitExceeded(count: count, limit: category.limit)
            }
        }
        return nil
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case v, canvas, background, layers
    }

    /// 캔버스 크기는 `{"w":1080,"h":1350}` 형태로 저장된다(v4 §8).
    /// `Size2`의 기본 키(width/height)와 다르므로 여기서 변환한다.
    private enum CanvasKeys: String, CodingKey {
        case w, h
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let version = try c.decode(Int.self, forKey: .v)
        guard version <= Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .v, in: c,
                debugDescription: """
                    지원하지 않는 layoutJSON 버전 \(version) \
                    (이 앱은 \(Self.currentVersion)까지 읽는다). \
                    반쯤 열어 보여주면 저장 시 모르는 필드가 소실된다.
                    """)
        }
        self.v = version

        let canvasContainer = try c.nestedContainer(keyedBy: CanvasKeys.self, forKey: .canvas)
        self.canvas = Size2(width: try canvasContainer.decode(Double.self, forKey: .w),
                            height: try canvasContainer.decode(Double.self, forKey: .h))

        self.background = try c.decode(Background.self, forKey: .background)
        self.layers = try c.decode([Layer].self, forKey: .layers)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)

        var canvasContainer = c.nestedContainer(keyedBy: CanvasKeys.self, forKey: .canvas)
        try canvasContainer.encode(canvas.width, forKey: .w)
        try canvasContainer.encode(canvas.height, forKey: .h)

        try c.encode(background, forKey: .background)
        try c.encode(layers, forKey: .layers)
    }
}

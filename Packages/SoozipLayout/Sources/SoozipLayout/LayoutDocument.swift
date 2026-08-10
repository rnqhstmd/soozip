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

    public static let photoLimit = 8
    public static let drawingLimit = 5
    public static let decorLimit = 30

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
        var photos = 0, drawings = 0, decor = 0
        for layer in layers {
            switch layer {
            case .photo:   photos += 1
            case .drawing: drawings += 1
            case .text, .shape, .stamp: decor += 1
            }
        }
        if photos > Self.photoLimit {
            return .photoLimitExceeded(count: photos, limit: Self.photoLimit)
        }
        if drawings > Self.drawingLimit {
            return .drawingLimitExceeded(count: drawings, limit: Self.drawingLimit)
        }
        if decor > Self.decorLimit {
            return .decorLimitExceeded(count: decor, limit: Self.decorLimit)
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

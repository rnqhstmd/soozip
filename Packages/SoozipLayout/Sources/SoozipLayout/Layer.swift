import Foundation
import SoozipGeometry

// MARK: - 도형 9종

/// `shape` 레이어의 형태. raw value가 layoutJSON에 저장된다.
public enum ShapeKind: String, CaseIterable, Codable, Sendable {
    case circle, rect, roundRect, line, star, heart, bubble, arrow, triangle
}

// MARK: - 텍스트 정렬

public enum TextAlign: String, Codable, Sendable {
    case left, center, right
}

// MARK: - 톤 필터

/// 사진에 입히는 색조. `colorIndex`는 파스텔 12색(0~11), `amount`는 0~1.
public struct ToneFilter: Codable, Equatable, Sendable {
    public var colorIndex: Int
    public var amount: Double

    public init(colorIndex: Int, amount: Double) {
        self.colorIndex = colorIndex
        self.amount = amount
    }
}

// MARK: - 공통 변형

/// 레이어 5종이 공유하는 배치 정보.
///
/// 좌표는 논리좌표계(폭 1080 고정)이며 **캔버스 밖 값도 유효하다** — 레이어는
/// 캔버스 경계를 넘어갈 수 있고 경계에서 잘려 보인다(v4 §5.10).
public struct LayerTransform: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var scale: Double
    public var rotation: Double     // 라디안
    public var opacity: Double
    public var z: Int

    public init(x: Double, y: Double,
                scale: Double = 1,
                rotation: Double = 0,
                opacity: Double = 1,
                z: Int = 0) {
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.z = z
    }

    /// 기하 계산용 `LayerFrame`으로 변환한다. `baseSize`에 scale이 곱해진다.
    public func frame(baseSize: Size2) -> LayerFrame {
        LayerFrame(center: Vec2(x: x, y: y),
                   size: Size2(width: baseSize.width * scale,
                               height: baseSize.height * scale),
                   rotation: rotation)
    }
}

// MARK: - 레이어 5종

public struct PhotoLayer: Codable, Equatable, Sendable {
    public var assetId: String
    public var transform: LayerTransform
    public var filter: ToneFilter?

    public init(assetId: String, transform: LayerTransform, filter: ToneFilter?) {
        self.assetId = assetId
        self.transform = transform
        self.filter = filter
    }
}

public struct TextLayer: Codable, Equatable, Sendable {
    public var string: String
    public var font: AppFont
    public var size: Double
    public var color: String        // "#RRGGBB"
    public var align: TextAlign
    public var transform: LayerTransform

    public init(string: String, font: AppFont, size: Double,
                color: String, align: TextAlign, transform: LayerTransform) {
        self.string = string
        self.font = font
        self.size = size
        self.color = color
        self.align = align
        self.transform = transform
    }
}

/// 도형은 텍스트를 품지 않는다(v4 §5.3). 말풍선 안 글자는 텍스트 레이어를 얹는다.
public struct ShapeLayer: Codable, Equatable, Sendable {
    public var kind: ShapeKind
    public var width: Double
    public var height: Double
    public var fill: Int            // 파스텔 12색 인덱스
    public var stroke: String?      // "#RRGGBB" 또는 nil
    public var strokeWidth: Double
    public var transform: LayerTransform

    public init(kind: ShapeKind, width: Double, height: Double,
                fill: Int, stroke: String?, strokeWidth: Double,
                transform: LayerTransform) {
        self.kind = kind
        self.width = width
        self.height = height
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.transform = transform
    }
}

public struct StampLayer: Codable, Equatable, Sendable {
    public var date: String         // "yyyy-MM-dd"
    public var style: String
    public var transform: LayerTransform

    public init(date: String, style: String, transform: LayerTransform) {
        self.date = date
        self.style = style
        self.transform = transform
    }
}

/// PencilKit 필기를 이미지로 구운 레이어. 획 재편집은 불가하다.
public struct DrawingLayer: Codable, Equatable, Sendable {
    public var assetId: String
    public var transform: LayerTransform

    public init(assetId: String, transform: LayerTransform) {
        self.assetId = assetId
        self.transform = transform
    }
}

// MARK: - 다형 레이어

/// layoutJSON의 `layers` 배열 원소.
///
/// `type` 필드로 판별해 디코딩한다. 알 수 없는 타입은 **조용히 무시하지 않고
/// 에러를 낸다** — 상위 버전에서 만든 캔버스를 반쯤 열어 보여주면 사용자가
/// 저장하는 순간 데이터가 소실된다.
public enum Layer: Equatable, Sendable {
    case photo(PhotoLayer)
    case text(TextLayer)
    case shape(ShapeLayer)
    case stamp(StampLayer)
    case drawing(DrawingLayer)

    /// v4 §5.2: **이동·핀치·회전·z-order·투명도는 5종이 완전히 동일한 경로를
    /// 탄다.** 그 경로가 타입별 분기 없이 쓸 수 있는 단일 접근자다.
    public var transform: LayerTransform {
        get {
            switch self {
            case .photo(let l):   return l.transform
            case .text(let l):    return l.transform
            case .shape(let l):   return l.transform
            case .stamp(let l):   return l.transform
            case .drawing(let l): return l.transform
            }
        }
        set {
            switch self {
            case .photo(var l):   l.transform = newValue; self = .photo(l)
            case .text(var l):    l.transform = newValue; self = .text(l)
            case .shape(var l):   l.transform = newValue; self = .shape(l)
            case .stamp(var l):   l.transform = newValue; self = .stamp(l)
            case .drawing(var l): l.transform = newValue; self = .drawing(l)
            }
        }
    }

    /// layoutJSON의 `type` 값.
    public var typeName: String {
        switch self {
        case .photo:   return "photo"
        case .text:    return "text"
        case .shape:   return "shape"
        case .stamp:   return "stamp"
        case .drawing: return "drawing"
        }
    }
}

extension Layer: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let type = try typeContainer.decode(String.self, forKey: .type)

        let single = try decoder.singleValueContainer()
        switch type {
        case "photo":   self = .photo(try single.decode(PhotoLayer.self))
        case "text":    self = .text(try single.decode(TextLayer.self))
        case "shape":   self = .shape(try single.decode(ShapeLayer.self))
        case "stamp":   self = .stamp(try single.decode(StampLayer.self))
        case "drawing": self = .drawing(try single.decode(DrawingLayer.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: typeContainer,
                debugDescription: "알 수 없는 레이어 타입: \(type)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .photo(let l):   try single.encode(l)
        case .text(let l):    try single.encode(l)
        case .shape(let l):   try single.encode(l)
        case .stamp(let l):   try single.encode(l)
        case .drawing(let l): try single.encode(l)
        }
        // payload를 flat하게 쓴 뒤 같은 레벨에 `type` 판별자를 덧붙인다.
        //
        // 주의: singleValueContainer로 인코딩한 뒤 같은 encoder에서 keyedContainer를
        // 다시 얻는 것은 Foundation 구현에 기대는 패턴이다. 실제 출력이 v4 §8 형식과
        // 일치하는지는 `JSONContractTests`가 키 단위로 검증한다 — Foundation 동작이
        // 바뀌면 그 테스트가 즉시 잡는다.
        var typed = encoder.container(keyedBy: TypeKey.self)
        try typed.encode(typeName, forKey: .type)
    }
}

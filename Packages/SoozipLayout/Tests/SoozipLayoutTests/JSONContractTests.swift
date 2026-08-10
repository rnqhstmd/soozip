import Testing
import Foundation
@testable import SoozipLayout

// v4 설계서 §8이 규정한 JSON 형태와 실제 출력이 일치하는지 검증한다.
// 라운드트립만으로는 "우리끼리만 통하는 형식"이 되어도 통과하므로, 실제 키와
// 값을 직접 확인한다. 이 형식은 저장된 캔버스의 호환성을 좌우한다.

private func jsonObject(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

@Test func photo_레이어는_flat_구조에_type_판별자를_갖는다() throws {
    let layer = Layer.photo(PhotoLayer(
        assetId: "abc-123",
        transform: LayerTransform(x: 540, y: 700, scale: 1.2, rotation: -0.08, z: 3),
        filter: ToneFilter(colorIndex: 5, amount: 0.4)
    ))
    let obj = try jsonObject(layer)

    #expect(obj["type"] as? String == "photo")
    #expect(obj["assetId"] as? String == "abc-123")

    // transform은 중첩 객체다
    let t = obj["transform"] as? [String: Any]
    #expect(t?["x"] as? Double == 540)
    #expect(t?["z"] as? Int == 3)

    let f = obj["filter"] as? [String: Any]
    #expect(f?["colorIndex"] as? Int == 5)
}

@Test func text_레이어의_font는_문자열로_저장된다() throws {
    let layer = Layer.text(TextLayer(
        string: "모음집", font: .gowunBatang, size: 42,
        color: "#3A3A3A", align: .center,
        transform: LayerTransform(x: 0, y: 0)
    ))
    let obj = try jsonObject(layer)

    #expect(obj["type"] as? String == "text")
    #expect(obj["font"] as? String == "gowunBatang")
    #expect(obj["align"] as? String == "center")
    #expect(obj["string"] as? String == "모음집")
}

@Test func shape_레이어의_kind와_fill() throws {
    let layer = Layer.shape(ShapeLayer(
        kind: .bubble, width: 220, height: 120, fill: 9,
        stroke: nil, strokeWidth: 0,
        transform: LayerTransform(x: 0, y: 0)
    ))
    let obj = try jsonObject(layer)

    #expect(obj["type"] as? String == "shape")
    #expect(obj["kind"] as? String == "bubble")
    #expect(obj["fill"] as? Int == 9)
    #expect(obj["stroke"] == nil)          // nil은 키 자체가 빠진다
}

@Test func 다섯_타입의_판별자가_모두_올바르다() throws {
    let cases: [(Layer, String)] = [
        (.photo(PhotoLayer(assetId: "a", transform: LayerTransform(x: 0, y: 0), filter: nil)), "photo"),
        (.text(TextLayer(string: "s", font: .pretendard, size: 10,
                         color: "#000000", align: .left,
                         transform: LayerTransform(x: 0, y: 0))), "text"),
        (.shape(ShapeLayer(kind: .rect, width: 1, height: 1, fill: 0,
                           stroke: nil, strokeWidth: 0,
                           transform: LayerTransform(x: 0, y: 0))), "shape"),
        (.stamp(StampLayer(date: "2026-08-10", style: "round",
                           transform: LayerTransform(x: 0, y: 0))), "stamp"),
        (.drawing(DrawingLayer(assetId: "d", transform: LayerTransform(x: 0, y: 0))), "drawing")
    ]
    for (layer, expected) in cases {
        let obj = try jsonObject(layer)
        #expect(obj["type"] as? String == expected,
                "\(expected) 판별자 누락 — 실제 키: \(obj.keys.sorted())")
    }
}

@Test func 외부에서_만든_JSON을_읽을_수_있다() throws {
    // 손으로 쓴 JSON — 우리 인코더를 거치지 않은 입력도 받아들여야 한다.
    let json = Data("""
    {
      "type": "shape",
      "kind": "star",
      "width": 100,
      "height": 100,
      "fill": 3,
      "strokeWidth": 0,
      "transform": { "x": -250, "y": 2400, "scale": 1, "rotation": 0, "opacity": 1, "z": 7 }
    }
    """.utf8)

    let layer = try JSONDecoder().decode(Layer.self, from: json)
    guard case .shape(let s) = layer else {
        Issue.record("shape로 디코딩되지 않았다")
        return
    }
    #expect(s.kind == .star)
    #expect(s.transform.x == -250)
    #expect(s.transform.z == 7)
    #expect(s.stroke == nil)
}

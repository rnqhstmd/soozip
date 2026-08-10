import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// MARK: - 도형 9종

@Test func 도형은_9종이다() {
    #expect(ShapeKind.allCases.count == 9)
}

@Test func 도형_rawValue는_layoutJSON에_저장되는_값이다() {
    #expect(ShapeKind.circle.rawValue == "circle")
    #expect(ShapeKind.roundRect.rawValue == "roundRect")
    #expect(ShapeKind.bubble.rawValue == "bubble")
    #expect(ShapeKind.triangle.rawValue == "triangle")
}

// MARK: - 공통 변형

@Test func 레이어_변형의_기본값() {
    let t = LayerTransform(x: 540, y: 700)
    #expect(t.scale == 1)
    #expect(t.rotation == 0)
    #expect(t.opacity == 1)
    #expect(t.z == 0)
}

@Test func 변형은_LayerFrame으로_변환된다() {
    let t = LayerTransform(x: 540, y: 700, scale: 2, rotation: 0.5)
    let frame = t.frame(baseSize: Size2(width: 100, height: 50))
    #expect(frame.center == Vec2(x: 540, y: 700))
    #expect(frame.size == Size2(width: 200, height: 100))   // scale 2 적용
    #expect(frame.rotation == 0.5)
}

// MARK: - 레이어 5종 라운드트립

private func roundTrip(_ layer: Layer) throws -> Layer {
    let data = try JSONEncoder().encode(layer)
    return try JSONDecoder().decode(Layer.self, from: data)
}

@Test func photo_레이어_라운드트립() throws {
    let layer = Layer.photo(PhotoLayer(
        assetId: "abc-123",
        transform: LayerTransform(x: 540, y: 700, scale: 1.2, rotation: -0.08, z: 0),
        filter: ToneFilter(colorIndex: 5, amount: 0.4)
    ))
    #expect(try roundTrip(layer) == layer)
}

@Test func photo_레이어는_필터가_없을_수_있다() throws {
    let layer = Layer.photo(PhotoLayer(
        assetId: "no-filter",
        transform: LayerTransform(x: 100, y: 200),
        filter: nil
    ))
    #expect(try roundTrip(layer) == layer)
}

@Test func text_레이어_라운드트립() throws {
    let layer = Layer.text(TextLayer(
        string: "모음집 안녕하세요",
        font: .gowunBatang,
        size: 42,
        color: "#3A3A3A",
        align: .center,
        transform: LayerTransform(x: 300, y: 400, z: 1)
    ))
    #expect(try roundTrip(layer) == layer)
}

@Test func shape_레이어_라운드트립() throws {
    let layer = Layer.shape(ShapeLayer(
        kind: .circle,
        width: 220,
        height: 220,
        fill: 9,
        stroke: nil,
        strokeWidth: 0,
        transform: LayerTransform(x: 400, y: 260, rotation: 0.1, opacity: 0.9, z: 2)
    ))
    #expect(try roundTrip(layer) == layer)
}

@Test func stamp_레이어_라운드트립() throws {
    let layer = Layer.stamp(StampLayer(
        date: "2026-08-10",
        style: "round",
        transform: LayerTransform(x: 800, y: 1200, rotation: 0.05, z: 3)
    ))
    #expect(try roundTrip(layer) == layer)
}

@Test func drawing_레이어_라운드트립() throws {
    let layer = Layer.drawing(DrawingLayer(
        assetId: "pen-1",
        transform: LayerTransform(x: 540, y: 675, z: 4)
    ))
    #expect(try roundTrip(layer) == layer)
}

// MARK: - 경계 조건

@Test func 캔버스_밖_좌표도_보존된다() throws {
    // 레이어는 캔버스 밖으로 자유롭게 나갈 수 있다(v4 §5.10). 음수·초과 좌표가
    // 인코딩/디코딩에서 잘리면 안 된다.
    let layer = Layer.shape(ShapeLayer(
        kind: .star, width: 100, height: 100, fill: 3,
        stroke: nil, strokeWidth: 0,
        transform: LayerTransform(x: -250, y: 2400, z: 0)
    ))
    let back = try roundTrip(layer)
    guard case .shape(let s) = back else { Issue.record("타입 불일치"); return }
    #expect(s.transform.x == -250)
    #expect(s.transform.y == 2400)
}

@Test func 알수없는_레이어_타입은_디코딩에_실패한다() {
    let json = Data(#"{"type":"video","x":0,"y":0}"#.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(Layer.self, from: json)
    }
}

@Test func 레이어_배열_라운드트립() throws {
    let layers: [Layer] = [
        .photo(PhotoLayer(assetId: "p1", transform: LayerTransform(x: 100, y: 100, z: 0), filter: nil)),
        .text(TextLayer(string: "제목", font: .pretendard, size: 60,
                        color: "#000000", align: .left,
                        transform: LayerTransform(x: 200, y: 200, z: 1))),
        .shape(ShapeLayer(kind: .heart, width: 80, height: 80, fill: 0,
                          stroke: "#FFFFFF", strokeWidth: 2,
                          transform: LayerTransform(x: 300, y: 300, z: 2))),
        .stamp(StampLayer(date: "2026-08-10", style: "square",
                          transform: LayerTransform(x: 400, y: 400, z: 3))),
        .drawing(DrawingLayer(assetId: "d1", transform: LayerTransform(x: 500, y: 500, z: 4)))
    ]
    let data = try JSONEncoder().encode(layers)
    let decoded = try JSONDecoder().decode([Layer].self, from: data)
    #expect(decoded == layers)
    #expect(decoded.count == 5)
}

@Test func z_순서로_정렬할_수_있다() {
    let layers: [Layer] = [
        .stamp(StampLayer(date: "2026-08-10", style: "round", transform: LayerTransform(x: 0, y: 0, z: 5))),
        .photo(PhotoLayer(assetId: "p", transform: LayerTransform(x: 0, y: 0, z: 1), filter: nil)),
        .drawing(DrawingLayer(assetId: "d", transform: LayerTransform(x: 0, y: 0, z: 3)))
    ]
    let sorted = layers.sorted { $0.transform.z < $1.transform.z }
    #expect(sorted.map(\.transform.z) == [1, 3, 5])
}

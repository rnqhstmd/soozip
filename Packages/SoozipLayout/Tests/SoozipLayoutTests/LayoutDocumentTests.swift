import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// MARK: - 캔버스 규격

@Test func 캔버스_비율은_2종이다() {
    #expect(CanvasAspect.allCases.count == 2)
}

@Test func 게시물은_1080x1350_스토리는_1080x1920() {
    #expect(CanvasAspect.post.size == Size2(width: 1080, height: 1350))
    #expect(CanvasAspect.story.size == Size2(width: 1080, height: 1920))
}

@Test func 비율의_rawValue는_Canvas_aspect_필드와_일치한다() {
    // SwiftData의 Canvas.aspect가 Int로 저장된다(v4 §7). 값이 바뀌면 기존 캔버스가 깨진다.
    #expect(CanvasAspect.post.rawValue == 0)
    #expect(CanvasAspect.story.rawValue == 1)
}

@Test func 폭은_두_프리셋_모두_1080이다() {
    for aspect in CanvasAspect.allCases {
        #expect(aspect.size.width == 1080)
    }
}

// MARK: - 문서 라운드트립

@Test func 빈_캔버스도_유효한_문서다() throws {
    // 레이어 0개 캔버스는 저장 가능해야 한다(v4 §5.14).
    let doc = LayoutDocument(aspect: .post, layers: [])
    let data = try JSONEncoder().encode(doc)
    let back = try JSONDecoder().decode(LayoutDocument.self, from: data)
    #expect(back == doc)
    #expect(back.layers.isEmpty)
}

@Test func 문서_라운드트립_레이어_5종() throws {
    let doc = LayoutDocument(aspect: .story, layers: [
        .photo(PhotoLayer(assetId: "p1", transform: LayerTransform(x: 540, y: 700, z: 0),
                          filter: ToneFilter(colorIndex: 5, amount: 0.4))),
        .text(TextLayer(string: "제주 4박", font: .gowunBatang, size: 42,
                        color: "#3A3A3A", align: .center,
                        transform: LayerTransform(x: 300, y: 400, z: 1))),
        .shape(ShapeLayer(kind: .circle, width: 220, height: 220, fill: 9,
                          stroke: nil, strokeWidth: 0,
                          transform: LayerTransform(x: 400, y: 260, z: 2))),
        .stamp(StampLayer(date: "2026-08-10", style: "round",
                          transform: LayerTransform(x: 800, y: 1600, z: 3))),
        .drawing(DrawingLayer(assetId: "d1", transform: LayerTransform(x: 540, y: 900, z: 4)))
    ])
    let data = try JSONEncoder().encode(doc)
    let back = try JSONDecoder().decode(LayoutDocument.self, from: data)
    #expect(back == doc)
}

@Test func 문서_JSON은_v4_스펙_형식이다() throws {
    let doc = LayoutDocument(aspect: .post, layers: [])
    let data = try JSONEncoder().encode(doc)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(obj["v"] as? Int == 1)

    let canvas = obj["canvas"] as? [String: Any]
    #expect(canvas?["w"] as? Double == 1080)
    #expect(canvas?["h"] as? Double == 1350)

    let bg = obj["background"] as? [String: Any]
    #expect(bg?["color"] as? String == "#FFFFFF")

    #expect((obj["layers"] as? [Any])?.isEmpty == true)
}

@Test func 배경은_기본이_흰색이다() {
    // P0는 흰색 고정. 종이 질감·단색 변경은 P1(v4 §3).
    #expect(LayoutDocument(aspect: .post, layers: []).background.color == "#FFFFFF")
}

@Test func 상위_버전_문서는_거부한다() {
    // 미래 버전으로 만든 캔버스를 반쯤 열어 보여주면, 사용자가 저장하는 순간
    // 모르는 필드가 소실된다.
    // 구분자를 ## 로 둔다 — 문자열 안의 "#FFFFFF"에서 "# 가 종료로 먹힌다.
    let json = Data(##"{"v":2,"canvas":{"w":1080,"h":1350},"background":{"color":"#FFFFFF"},"layers":[]}"##.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(LayoutDocument.self, from: json)
    }
}

// MARK: - 레이어 상한 (v4 §5.13)

@Test func 상한_내_문서는_검증을_통과한다() {
    let doc = LayoutDocument(aspect: .post, layers:
        (0..<8).map { i in .photo(PhotoLayer(assetId: "p\(i)",
                                             transform: LayerTransform(x: 0, y: 0, z: i),
                                             filter: nil)) })
    #expect(doc.validate() == nil)
}

@Test func 사진_9장은_상한_위반이다() {
    let doc = LayoutDocument(aspect: .post, layers:
        (0..<9).map { i in .photo(PhotoLayer(assetId: "p\(i)",
                                             transform: LayerTransform(x: 0, y: 0, z: i),
                                             filter: nil)) })
    #expect(doc.validate() == .photoLimitExceeded(count: 9, limit: 8))
}

@Test func 펜_6개는_상한_위반이다() {
    let doc = LayoutDocument(aspect: .post, layers:
        (0..<6).map { i in .drawing(DrawingLayer(assetId: "d\(i)",
                                                 transform: LayerTransform(x: 0, y: 0, z: i))) })
    #expect(doc.validate() == .drawingLimitExceeded(count: 6, limit: 5))
}

@Test func 텍스트_도형_도장_합_31개는_상한_위반이다() {
    // 세 타입은 개별이 아니라 **합산** 30개가 상한이다.
    var layers: [Layer] = []
    for i in 0..<11 {
        layers.append(.text(TextLayer(string: "t\(i)", font: .pretendard, size: 20,
                                      color: "#000000", align: .left,
                                      transform: LayerTransform(x: 0, y: 0, z: i))))
    }
    for i in 0..<10 {
        layers.append(.shape(ShapeLayer(kind: .circle, width: 10, height: 10, fill: 0,
                                        stroke: nil, strokeWidth: 0,
                                        transform: LayerTransform(x: 0, y: 0, z: i))))
    }
    for i in 0..<10 {
        layers.append(.stamp(StampLayer(date: "2026-08-10", style: "round",
                                        transform: LayerTransform(x: 0, y: 0, z: i))))
    }
    let doc = LayoutDocument(aspect: .post, layers: layers)
    #expect(doc.validate() == .decorLimitExceeded(count: 31, limit: 30))
}

@Test func 각_타입이_상한을_꽉_채운_문서는_통과한다() {
    var layers: [Layer] = []
    layers += (0..<8).map { i in .photo(PhotoLayer(assetId: "p\(i)", transform: LayerTransform(x: 0, y: 0, z: i), filter: nil)) }
    layers += (0..<5).map { i in .drawing(DrawingLayer(assetId: "d\(i)", transform: LayerTransform(x: 0, y: 0, z: i))) }
    layers += (0..<30).map { i in .stamp(StampLayer(date: "2026-08-10", style: "round", transform: LayerTransform(x: 0, y: 0, z: i))) }
    let doc = LayoutDocument(aspect: .post, layers: layers)
    #expect(doc.validate() == nil)
    #expect(doc.layers.count == 43)   // v4가 말하는 "최대 43개"의 근거
}

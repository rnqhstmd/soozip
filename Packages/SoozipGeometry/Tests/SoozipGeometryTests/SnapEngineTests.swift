import Testing
import Foundation
@testable import SoozipGeometry

private let canvas = Size2(width: 1080, height: 1350)
private let threshold: Double = 8

private func frame(x: Double, y: Double,
                   w: Double = 100, h: Double = 100,
                   rot: Double = 0) -> LayerFrame {
    LayerFrame(center: Vec2(x: x, y: y),
               size: Size2(width: w, height: h),
               rotation: rot)
}

@Test func 캔버스_수직중심선에_가까우면_정렬후보가_나온다() {
    let moving = frame(x: 543, y: 400)          // 중심 540에서 3pt 차이
    let candidates = snapCandidates(for: moving, among: [],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .alignment && $0.axis == .vertical })
}

@Test func 임계를_벗어나면_후보가_없다() {
    let moving = frame(x: 600, y: 400)          // 중심 540에서 60pt 차이
    let candidates = snapCandidates(for: moving, among: [],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.isEmpty)
}

@Test func 다른_레이어의_좌측_가장자리에_정렬된다() {
    let other = frame(x: 300, y: 200)           // left = 250
    let moving = frame(x: 303, y: 600)          // left = 253, 3pt 차이
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .alignment && $0.axis == .vertical })
}

@Test func 균등간격_후보는_같은축에_셋_이상일때만_나온다() {
    let a = frame(x: 200, y: 500)
    let b = frame(x: 400, y: 500)
    // a-b 간격이 200이므로 c가 600 근처면 균등해진다
    let moving = frame(x: 597, y: 500)
    let candidates = snapCandidates(for: moving, among: [a, b],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .equalSpacing })
}

@Test func 레이어가_둘뿐이면_균등간격_후보가_없다() {
    let a = frame(x: 200, y: 500)
    let moving = frame(x: 597, y: 500)
    let candidates = snapCandidates(for: moving, among: [a],
                                    canvasSize: canvas, threshold: threshold)
    #expect(!candidates.contains { $0.kind == .equalSpacing })
}

@Test func 회전된_레이어는_후보에서_제외된다() {
    // 회전체의 바운딩 박스는 실제 형태와 어긋나므로 계산에 넣지 않는다
    let rotated = frame(x: 300, y: 200, rot: .pi / 6)   // left = 250 이지만 회전됨
    let moving = frame(x: 303, y: 600)
    let candidates = snapCandidates(for: moving, among: [rotated],
                                    canvasSize: canvas, threshold: threshold)
    #expect(!candidates.contains { $0.kind == .alignment && $0.value == 250 })
}

@Test func 움직이는_레이어가_회전됐으면_후보가_없다() {
    let other = frame(x: 300, y: 200)
    let moving = frame(x: 303, y: 600, rot: 0.5)
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.isEmpty)
}

@Test func 크기가_같아지는_지점에서_크기일치_후보가_나온다() {
    let other = frame(x: 300, y: 200, w: 240, h: 100)
    let moving = frame(x: 700, y: 600, w: 237, h: 100)   // 3pt 차이
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .sizeMatch })
}

@Test func 레이어_43개에서도_후보_계산이_끝난다() {
    // Phase 4의 60fps 요구를 위한 최소 확인. 실제 프레임 측정은 S1에서 한다.
    // 타입을 명시한다. Double(100 + i * 20) 형태는 컴파일러 오버로드 탐색이
    // 폭발해 "unable to type-check in reasonable time"이 난다.
    let others: [LayerFrame] = (0..<42).map { (i: Int) -> LayerFrame in
        let x: Double = 100 + Double(i) * 20
        let y: Double = 200 + Double(i) * 25
        return frame(x: x, y: y)
    }
    let moving = frame(x: 543, y: 400)
    let candidates = snapCandidates(for: moving, among: others,
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.count >= 0)   // 크래시·무한루프 없이 반환되면 통과
}

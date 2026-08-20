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

@Test func 미세_음수_회전은_축_정렬로_유지된다() {
    // "[0, 2π)로 정규화한 뒤 0 근접 비교"로 바꾸는 변이를 죽인다.
    // 그 방식이면 -0.00005가 정규화 후 큰 양수(2π 근처)가 되어 결과가 false로 뒤집힌다.
    #expect(isAxisAligned(radians: -0.00005))
}

@Test func 미세_음수_회전_레이어가_스냅_후보에_포함된다() {
    // isAxisAligned를 snapCandidates 경유로 간접 관측한다.
    // [0, 2π) 정규화 변이가 적용되면 이 레이어가 회전체로 오판되어 후보 배열이 빈 채로 나온다.
    //
    // 고유 킬은 없다 — 위 미세_음수_회전_테스트와 함께 죽는다. 그래도 지우지
    // 않는 이유는 존재 이유가 킬셋이 아니라 경로 커버리지이기 때문이다: 이
    // 테스트는 isAxisAligned 판정이 실제로 snapCandidates에 배선돼 있는지를
    // 본다. 그 배선은 `others.filter`가 아니라 `moving` 진입 가드다(이
    // 케이스는 `among: []`라 `others.filter`에 도달하지 않는다) — 실측:
    // `others.filter` 경로는 기존 `회전된_레이어는_후보에서_제외된다`가
    // 지키고(호출부 filter 제거 변이가 그것을 죽인다), `moving` 진입
    // 가드는 `움직이는_레이어가_회전됐으면_후보가_없다`가 지킨다.
    //
    // 다만 그 기존 테스트는 가드의 "거부" 분기(rot: 0.5 → 빈 배열)만
    // 지킨다. 이 테스트는 같은 가드의 "통과" 분기를 경계값(-0.00005)에서
    // 확인하는 유일한 자리이므로 존치한다.
    let moving = frame(x: 543, y: 400, rot: -0.00005)   // 중심 540에서 3pt 차이
    let candidates = snapCandidates(for: moving, among: [],
                                    canvasSize: canvas, threshold: threshold)
    #expect(!candidates.isEmpty)
}

@Test func 한_바퀴_돈_레이어도_축_정렬로_인식된다() {
    // 위 두 변이(`turn - n` 항 제거 = 정규화 후 0-근접만 비교 / 호출부
    // 필터 제거) 중 어느 것도 이 테스트를 죽이지 못한다 — 이 테스트는
    // 이전 구현을 죽이는 테스트다. 정규화 없이 0 근접만 보는 기존
    // 판정식은 이 입력(2π)에서 false를 냈다. 그 버그를 고쳤다는 직접
    // 증인이다. 변이 킬셋 상세는 `isAxisAligned` 문서 참고.
    #expect(isAxisAligned(radians: 2 * .pi))
}

@Test func 한_바퀴에_거의_근접한_회전도_축_정렬이다() {
    // 이 입력(2π − 0.00005)과 미세_음수_회전_테스트의 입력(-0.00005)은
    // 접기 *후*에는 비트 동일(`6.283135307179586`)이지만 접기 *안*에서는
    // 서로 다른 분기를 탄다 — 전자는 음수 보정(`if r < 0 { r += period }`)
    // 없이 통과하고, 후자는 그 보정을 거친다. 이 테스트가 지키는 것은 그
    // 분기다(고유 킬은 아니다 — 셋이 함께 죽는다). 변이 킬셋 상세는
    // `isAxisAligned` 문서 참고.
    //
    // 또한 이 동작(한 바퀴 근접 회전의 신규 후보 편입)은 AC에 명시되지 않은
    // 변경이다. `snapCandidates` 문서가 그 변경을 설명하고, 이 테스트는
    // 그것을 자동으로 감시한다.
    #expect(isAxisAligned(radians: 2 * .pi - 0.00005))
}

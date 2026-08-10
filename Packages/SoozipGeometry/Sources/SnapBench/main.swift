import Foundation
import SoozipGeometry

// SnapEngine 성능 벤치마크.
//
// 목적: 스마트 가이드의 **계산 비용**이 60fps 예산(16.667ms) 중 얼마를 먹는지
// 재는 것. SwiftUI 렌더링 비용은 여기서 못 재므로, 이 수치는 하한이다.
//
// 판단 기준:
//   - 예산의 5% 미만  → 계산은 병목이 아니다. 실기기 병목은 렌더링 쪽
//   - 5~20%          → 주의. 스로틀링을 미리 설계에 넣는다
//   - 20% 이상       → 계산이 병목. 후보 축소·스로틀링을 v4 §5.8.4에 반영해야 한다
//
// 반드시 release 빌드로 실행한다: swift run -c release SnapBench

let canvas = Size2(width: 1080, height: 1350)
let threshold: Double = 8
let frameBudgetMs = 1000.0 / 60.0   // 16.667ms

/// 캔버스에 흩뿌린 레이어들. `rotatedCount`만큼은 회전시켜
/// SnapEngine의 필터링(회전 레이어 제외)이 실제로 비용을 줄이는지 본다.
func makeLayers(count: Int, rotatedCount: Int = 0) -> [LayerFrame] {
    (0..<count).map { (i: Int) -> LayerFrame in
        let col: Double = Double(i % 7)
        let row: Double = Double(i / 7)
        let rot: Double = i < rotatedCount ? 0.3 : 0
        return LayerFrame(center: Vec2(x: 120 + col * 140, y: 150 + row * 180),
                          size: Size2(width: 100, height: 100),
                          rotation: rot)
    }
}

/// 드래그 중인 레이어를 조금씩 옮기며 반복 측정한다.
/// 같은 좌표를 반복하면 분기 예측이 비현실적으로 유리해진다.
func bench(_ label: String, layers: [LayerFrame], iterations: Int) {
    var sink = 0
    let clock = ContinuousClock()

    // 워밍업 — 첫 호출의 지연을 측정에서 뺀다
    for i in 0..<1000 {
        let moving = LayerFrame(center: Vec2(x: 540 + Double(i % 20) - 10, y: 400),
                                size: Size2(width: 100, height: 100),
                                rotation: 0)
        sink += snapCandidates(for: moving, among: layers,
                               canvasSize: canvas, threshold: threshold).count
    }

    let elapsed = clock.measure {
        for i in 0..<iterations {
            let moving = LayerFrame(center: Vec2(x: 540 + Double(i % 20) - 10, y: 400),
                                    size: Size2(width: 100, height: 100),
                                    rotation: 0)
            sink += snapCandidates(for: moving, among: layers,
                                   canvasSize: canvas, threshold: threshold).count
        }
    }

    let totalMs = Double(elapsed.components.attoseconds) / 1e15
                + Double(elapsed.components.seconds) * 1000
    let perCallUs = totalMs * 1000 / Double(iterations)
    let budgetPct = (perCallUs / 1000) / frameBudgetMs * 100

    let verdict: String
    switch budgetPct {
    case ..<5:   verdict = "계산은 병목 아님"
    case ..<20:  verdict = "주의 — 스로틀링 검토"
    default:     verdict = "계산이 병목 — 설계 수정 필요"
    }

    // NSString.utf8String은 Windows Foundation에서 동작하지 않는다(빈 문자열 출력).
    // 순수 Swift로 패딩한다.
    let labelCol = label.padding(toLength: 30, withPad: " ", startingAt: 0)
    let usCol = String(format: "%8.2f", perCallUs)
    let pctCol = String(format: "%6.3f", budgetPct)
    print("\(labelCol) \(usCol) us/call  \(pctCol)% of frame   \(verdict)")
    if sink < 0 { print("unreachable \(sink)") }   // 최적화로 날아가지 않게 붙잡아 둔다
}

print("SnapEngine 성능 벤치마크")
print("60fps 프레임 예산: \(String(format: "%.3f", frameBudgetMs))ms")
print(String(repeating: "-", count: 84))

let iterations = 50_000

bench("레이어 10개 (전부 축정렬)",  layers: makeLayers(count: 10),  iterations: iterations)
bench("레이어 20개 (전부 축정렬)",  layers: makeLayers(count: 20),  iterations: iterations)
bench("레이어 42개 (전부 축정렬)",  layers: makeLayers(count: 42),  iterations: iterations)
bench("레이어 42개 (절반 회전)",    layers: makeLayers(count: 42, rotatedCount: 21), iterations: iterations)
bench("레이어 42개 (전부 회전)",    layers: makeLayers(count: 42, rotatedCount: 42), iterations: iterations)
bench("레이어 100개 (상한 초과)",   layers: makeLayers(count: 100), iterations: iterations)

print(String(repeating: "-", count: 84))
print("주의: 이 수치는 계산 비용만이다. SwiftUI 렌더링은 실기기(Task 7)에서 측정한다.")

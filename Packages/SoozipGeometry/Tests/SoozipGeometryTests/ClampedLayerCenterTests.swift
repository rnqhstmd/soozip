import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-10 — ClampedLayerCenter와 LayerFrame.placed(at:)의 계약.
//
// 이 파일이 갚는 부채: LayerCenterClampTests.swift는 CanvasSurface.clampedLayerCenter가
// 낸 Vec2를 직접 쟀다. 그 경로는 더 이상 "봉쇄된" 공개 경로 전체가 아니다 —
// 진짜 계약은 ClampedLayerCenter 토큰을 거쳐 LayerFrame.placed(at:)로 최종
// 중심이 프레임에 반영되는 것이다. 그래서 이 파일의 모든 단언은
// ClampedLayerCenter(...).value가 아니라 frame.placed(at: 토큰).center를
// 잰다. value를 직접 재면 이 계약을 거치지 않고도 통과하는 두 변이를 놓친다:
//   - placed(at:)가 토큰을 무시하고 self를 그대로 반환하는 변이
//   - 토큰 생성자가 클램프를 건너뛰고 value = point를 그대로 저장하는 변이
//
// 시작 프레임의 center는 반드시 캔버스 중심 (540, 675)과 x·y 두 축 모두
// 달라야 한다. LayerCenterClampTests.swift:42-43이 이미 이 함정을 원장에
// 적었다 — "y를 999로 둔 이유: 675로 두면 캔버스 중심의 y와 같아져 y 성분이
// 어느 구현에서도 안 바뀌어 증인이 약해진다." 이번엔 같은 함정이 입력이
// 아니라 시작 프레임 쪽에 있다: 시작 center를 (540, 675)로 두면
// `placed(at:) { return self }`라는 변이가 AC-17(기대 출력이 정확히
// (540, 675))에서 그대로 통과해 버린다. 그래서 시작 center를 (100, 200)으로
// 둔다 — (540, 675)와 x·y 두 축 모두 다르다.

/// 4:5 피드 캔버스.
private let 캔버스 = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: 캔버스, viewport: 세로)
}

/// 캔버스 중심 (540, 675)과 x·y 두 축 모두 다른 시작 프레임.
/// size·rotation도 기본값이 아닌 값으로 두어 "보존" 단언이 의미를 갖게 한다.
private func 시작프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 100, y: 200), size: Size2(width: 200, height: 100), rotation: 0.3)
}

@Test func 작업_영역_밖으로_밀린_중심은_경계에서_잘려_프레임에_반영된다() {
    // AC-16. 캔버스 경계 (1080, 1350)이 아니라 작업 영역 경계(캔버스의 2배
    // 범위) (1620, 2025)로 잘려야 한다. 이 값이 frame.placed(at:).center에
    // 그대로 나타나야 한다 — token.value가 아니라.
    let 토큰 = ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 1620)
    #expect(결과.center.y == 2025)
}

@Test func 무한대_중심으로_옮기면_프레임_중심이_캔버스_중심으로_후퇴한다() {
    // AC-17 전반. ∞가 그럴듯한 경계값(1620)으로 조용히 잘리면 안 된다 —
    // 방어 없이 클램프하면 min(max(∞, −540), 1620) = 1620이 나온다.
    let 토큰 = ClampedLayerCenter(Vec2(x: .infinity, y: 999), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 540)
    #expect(결과.center.y == 675)
}

@Test func NaN_중심으로_옮기면_프레임_중심도_캔버스_중심으로_후퇴한다() {
    // AC-17 후반. NaN은 ∞와 다른 경로다 — 방어 없이 클램프하면
    // min(max(NaN, −540), 1620)이 NaN 그대로 통과한다(실측). NaN이 프레임
    // 중심에 앉으면 이후 인코딩·비교가 전부 오염된다.
    let 토큰 = ClampedLayerCenter(Vec2(x: 540, y: .nan), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 540)
    #expect(결과.center.y == 675)
}

@Test func placed는_size와_rotation을_그대로_보존한다() {
    // "size·rotation은 인자에 없으니 건드릴 수 없다"는 설계 1차본의 주장은
    // 거짓이다 — placed(at:)는 LayerFrame의 메서드라 self.size·self.rotation에
    // 얼마든지 닿고, LayerFrame(center: 토큰.value, size: .zero, rotation: 0)이
    // 그대로 컴파일된다. 타입이 막지 못하므로 이 테스트가 막는다.
    let 시작 = 시작프레임()
    let 토큰 = ClampedLayerCenter(Vec2(x: 300, y: 400), on: 표면())
    let 결과 = 시작.placed(at: 토큰)
    #expect(결과.size == 시작.size)
    #expect(결과.rotation == 시작.rotation)
}

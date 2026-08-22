import Testing
import Foundation
import SoozipGeometry
@testable import SoozipLayout

// EDITOR-10 — 모델 계층 봉쇄 (BR-7, AC 번호 없음 — PRD가 구조적 요구로 분류)
//
// SoozipGeometry의 게이트(ClampedLayerCenter 토큰 + LayerFrame.placed(at:) +
// LayerFrame.center를 internal(set)으로 좁힘)가 이미 서 있다. 하지만
// 레이어의 진짜 저장 상태는 LayerFrame이 아니라 LayerTransform.x/y다.
// LayerFrame은 매 프레임 만들어지는 중간값이고, 문서에 영속화되는 것은
// LayerTransform이다(Codable). SoozipGeometry의 게이트까지만 있으면 다음
// 한 줄이 게이트를 통째로 우회한다:
//   entry.layer.transform.x = surface.toLogical(point).x   // 클램프 0회
// 그리고 SoozipGeometry 게이트의 테스트는 전부 초록이다 — 게이트가
// 장식이 된다. 이 파일은 LayerTransform.placed(at:)이 그 우회로를 막는
// 유일한 저장 경로임을 증명한다.

/// 4:5 피드 캔버스. 중심 (540, 675), 작업 영역 경계 (1620, 2025).
private let 캔버스 = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: 캔버스, viewport: 세로)
}

/// 캔버스 중심 (540, 675)과 x·y 두 축 모두 다른 시작 변형. scale·rotation·
/// opacity·z도 전부 기본값(1·0·1·0)이 아닌 값으로 두어 "보존" 단언이 의미를
/// 갖게 한다 — 기본값이면 "보존됐다"와 "리셋됐다"를 구분할 수 없다.
/// (LayerCenterClampTests.swift:42-43, ClampedLayerCenterTests.swift:16-23이
/// 이미 원장에 적은 것과 같은 규칙: 675로 두면 캔버스 중심의 y와 같아져
/// 증인이 약해진다.)
private func 시작변형() -> LayerTransform {
    LayerTransform(x: 100, y: 200, scale: 1.5, rotation: 0.3, opacity: 0.7, z: 4)
}

@Test func 작업_영역_밖으로_밀린_좌표는_작업_영역_경계에서_잘려_저장_변형에_반영된다() {
    // 캔버스 경계 (1080, 1350)이 아니라 작업 영역 경계(캔버스의 2배 범위)
    // (1620, 2025)로 잘려야 한다. 이 값이 transform.x/y에 그대로 나타나야
    // 한다 — token.value가 아니라, LayerFrame.center도 아니라 실제로
    // 영속화되는 LayerTransform에.
    let 토큰 = ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: 표면())
    let 결과 = 시작변형().placed(at: 토큰)
    #expect(결과.x == 1620)
    #expect(결과.y == 2025)
}

@Test func 무한대_좌표로_옮기면_저장_좌표가_캔버스_중심으로_후퇴한다() {
    // ∞가 그럴듯한 경계값(1620)으로 조용히 잘리면 안 된다 — 방어 없이
    // 클램프하면 min(max(∞, −540), 1620) = 1620이 나온다.
    let 토큰 = ClampedLayerCenter(Vec2(x: .infinity, y: 999), on: 표면())
    let 결과 = 시작변형().placed(at: 토큰)
    #expect(결과.x == 540)
    #expect(결과.y == 675)
}

@Test func NaN_좌표로_옮기면_저장_좌표도_캔버스_중심으로_후퇴한다() {
    // NaN은 ∞와 다른 경로다 — 방어 없이 클램프하면
    // min(max(NaN, −540), 1620)이 NaN 그대로 통과한다(실측). NaN이 저장
    // 좌표에 앉으면 JSONEncoder가 던져 문서 저장이 실패한다.
    let 토큰 = ClampedLayerCenter(Vec2(x: 540, y: .nan), on: 표면())
    let 결과 = 시작변형().placed(at: 토큰)
    #expect(결과.x == 540)
    #expect(결과.y == 675)
}

@Test func placed는_scale_rotation_opacity_z를_그대로_보존한다() {
    // 우회로 `LayerTransform(x: p.x, y: p.y)`는 클램프만 빠뜨리는 게
    // 아니다 — 그 생성자는 나머지 네 필드에 전부 기본값이 있어서, 우회하면
    // scale·rotation·opacity·z가 조용히 리셋된다(1·0·1·0). placed(at:)가
    // 유일하게 나머지를 보존하는 경로라는 것이 이 게이트를 쓰게 만드는
    // 실질 유인이다. 그런데 placed(at:)도 LayerTransform의 메서드라
    // self.scale 등에 얼마든지 닿을 수 있으므로 타입이 보존을 강제하지
    // 못한다 — 이 테스트가 막는다.
    let 시작 = 시작변형()
    let 토큰 = ClampedLayerCenter(Vec2(x: 300, y: 400), on: 표면())
    let 결과 = 시작.placed(at: 토큰)
    #expect(결과.scale == 시작.scale)
    #expect(결과.rotation == 시작.rotation)
    #expect(결과.opacity == 시작.opacity)
    #expect(결과.z == 시작.z)
}

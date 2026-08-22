import Testing
import SoozipGeometry

// EDITOR-10 — 경계 밖 증인.
//
// 이 파일은 @testable이 아닌 일반 import로 SoozipGeometry를 본다. 즉 public이
// 아닌 어떤 선언도 이 파일에서는 보이지 않는다. 이 파일이 증명하는 참인
// 문장은 하나뿐이다 — "AC-16·17이 요구하는 경로(ClampedLayerCenter 생성자 →
// LayerFrame.placed(at:))가 공개 표면만으로 닿는다."
//
// Swift에는 "이것은 컴파일되지 않아야 한다"를 단언할 수단이 없다. 그래서
// 이 파일은 "클램프를 우회하는 다른 경로가 공개되어 있지 않다"는 것을
// 증명하지 않는다 — 애초에 증명할 수 없다. 이 파일이 보증하는 것은 오직
// "의도된 경로는 최소한 공개되어 있고, 그 경로로 계약을 관측할 수 있다"
// 뿐이다. GREEN 구현에서 ClampedLayerCenter나 placed(at:)에 public을
// 빠뜨리면, Packages/SoozipGeometry의 @testable 테스트는 여전히 통과할 수
// 있지만 이 파일만 컴파일 실패로 남는다 — 그것이 이 파일의 유일한 역할이다.
//
// 이 파일의 세 테스트는 킬셋이 같다. ClampedLayerCenter.init이나
// LayerFrame.placed(at:)에서 public이 빠지면 셋 다 컴파일 실패하고, 있으면
// 셋 다 통과한다. 셋을 가르는 변이는 존재하지 않는다.
//
// 값 축의 변이는 이 파일이 잡지 않는다. 같은 코드를 부르는 패키지 테스트
// (ClampedLayerCenterTests.swift, @testable)가 이미 잡는다. 이 파일이
// 유일하게 잡는 것은 가시성 회귀 하나뿐이다.
//
// 그래서 이 파일에 테스트를 더 늘려도 방어가 강해지지 않는다. 새 공개
// API가 생겼을 때만 그 API에 대한 증인을 하나 추가하면 된다.
//
// 셋을 남겨 둔 판단 — 킬셋이 겹치지만 실행 비용이 무시할 만하고 값 교차
// 확인의 소소한 가치가 있어 남겼다. 지우고 하나만 남겨도 방어력은 같다.

/// 4:5 피드 캔버스.
private let 캔버스 = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)

private func 표면() -> CanvasSurface {
    CanvasSurface(canvas: 캔버스, viewport: 세로)
}

/// 캔버스 중심 (540, 675)과 x·y 두 축 모두 다른 시작 프레임.
private func 시작프레임() -> LayerFrame {
    LayerFrame(center: Vec2(x: 100, y: 200), size: Size2(width: 200, height: 100), rotation: 0.3)
}

@Test func 공개_표면만으로_작업_영역_경계_클램프에_닿는다() {
    // AC-16. Packages 쪽과 동일한 경계값을 공개 표면만으로 재확인한다.
    let 토큰 = ClampedLayerCenter(Vec2(x: 99999, y: 99999), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 1620)
    #expect(결과.center.y == 2025)
}

@Test func 공개_표면만으로_무한대_중심의_캔버스_중심_후퇴에_닿는다() {
    // AC-17 전반. 경계로 잘리는(1620) 것이 아니라 캔버스 중심으로 후퇴해야
    // 한다.
    let 토큰 = ClampedLayerCenter(Vec2(x: .infinity, y: 999), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 540)
    #expect(결과.center.y == 675)
}

@Test func 공개_표면만으로_NaN_중심의_캔버스_중심_후퇴에_닿는다() {
    // AC-17 후반. NaN이 방어 없이 그대로 통과하는 것이 아니라 캔버스
    // 중심으로 후퇴해야 한다.
    let 토큰 = ClampedLayerCenter(Vec2(x: 540, y: .nan), on: 표면())
    let 결과 = 시작프레임().placed(at: 토큰)
    #expect(결과.center.x == 540)
    #expect(결과.center.y == 675)
}

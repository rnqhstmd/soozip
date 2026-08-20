import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-9 — 레이어 중심 클램프. 레이어를 캔버스 밖으로 아무리 밀어도 작업
// 영역(캔버스의 2배 범위) 경계까지만 이동하고, 비유한 입력은 캔버스 중심으로
// 후퇴한다.

/// 4:5 피드 캔버스.
private let post = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)
/// 같은 기기 가로.
private let 가로 = Size2(width: 844, height: 390)

private func 표면(_ viewport: Size2 = 세로) -> CanvasSurface {
    CanvasSurface(canvas: post, viewport: viewport)
}

@Test func 중심은_캔버스가_아니라_작업_영역_경계에서_잘린다() {
    // 경계값 원장. 캔버스 경계 (1080, 1350)으로 자르는 구현이 여기서 죽는다 —
    // 작업 영역은 캔버스의 2배 범위다.
    let r = 표면().clampedLayerCenter(Vec2(x: 99999, y: 99999))
    #expect(r.x == 1620)
    #expect(r.y == 2025)
}

@Test func 작업_영역_경계에_있는_중심은_안쪽으로_당겨지지_않는다() {
    // 경계에 정확히 있는 중심이 안쪽으로 당겨지지 않는지 확인한다.
    // "바운딩 박스를 작업 영역에 맞추는 변이"는 이 테스트가 아니라 타입이
    // 막는다 — 시그니처가 Vec2 → Vec2라 size·rotation이 함수에 들어오지
    // 않아 코너를 계산할 수단이 없다. 이 테스트가 죽이는 것은 off-by-one과
    // "무조건 캔버스 중심으로 밀기"다.
    let r = 표면().clampedLayerCenter(Vec2(x: 1620, y: 2025))
    #expect(r.x == 1620)
    #expect(r.y == 2025)
}

@Test func 무한대_중심은_경계로_잘리지_않고_캔버스_중심으로_후퇴한다() {
    // ∞가 조용히 유한해지는 것을 막는다. 방어 없이
    // min(max(∞, −540), 1620)을 하면 1620이 나온다 — 그럴듯한 좌표라 아무도
    // 눈치채지 못한다. y를 999로 둔 이유: 675로 두면 캔버스 중심의 y와
    // 같아져 y 성분이 어느 구현에서도 안 바뀌어 증인이 약해진다.
    let r = 표면().clampedLayerCenter(Vec2(x: .infinity, y: 999))
    #expect(r.x == 540)
    #expect(r.y == 675)
}

@Test func NaN_중심도_무한대와_같은_캔버스_중심을_낸다() {
    // NaN은 ∞와 다른 경로다 — 방어 없이 클램프하면
    // min(max(NaN, −540), 1620)이 NaN 그대로 통과한다(실측). NaN이 레이어
    // 중심에 앉으면 JSONEncoder가 던져 문서 저장이 실패한다. 그래서 두
    // 비유한 종류에 각각 증인이 필요하다.
    let r = 표면().clampedLayerCenter(Vec2(x: 540, y: .nan))
    #expect(r.x == 540)
    #expect(r.y == 675)
}

@Test func 이미_작업_영역_안인_중심은_두_번_클램프해도_그대로다() {
    // 멱등성. 후퇴 경로도 멱등인 이유는 캔버스 중심 (540,675)가 작업 영역
    // 안이기 때문이다 — 후퇴 목표가 작업 영역 밖이었다면 이 성질이 깨진다.
    let s = 표면()
    let 한번 = s.clampedLayerCenter(Vec2(x: 200, y: 300))
    let 두번 = s.clampedLayerCenter(한번)
    #expect(두번.x == 200)
    #expect(두번.y == 300)
}

@Test func 클램프_결과는_줌과_뷰포트에_무관하다() {
    // 작업 영역이 zoom·viewport와 무관함을 고정한다. 경계에 zoom이나 scale을
    // 곱하는 구현이 ⓑ에서 (6480, 8100)을 내어 죽는다 — 표면 하나만 쓰는
    // 12번(경계 잘림) 테스트는 이 변이를 통과시킨다.
    let 입력 = Vec2(x: 99999, y: 99999)
    for (라벨, s) in [("기본", 표면()),
                     ("줌4배", 표면().zoomed(to: 4)),
                     ("가로뷰포트", 표면(가로))] {
        let r = s.clampedLayerCenter(입력)
        #expect(r.x == 1620, "\(라벨)")
        #expect(r.y == 2025, "\(라벨)")
    }
}

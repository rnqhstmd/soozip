import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-1 — 캔버스 표면. 논리좌표 ↔ 화면좌표.
//
// 설계 SSOT: v4 §1.2(기기 회전) · §5.9(줌·팬) · §5.10(작업 영역)
//
// 이 타입의 저장 상태는 **배율·뷰포트에 독립인 것뿐**이다 — fit 대비 줌 배수와
// 뷰포트 중앙에 오는 논리 지점. 그래서 회전·줌에 보정 코드가 붙지 않는다.

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

/// 4:5 피드 캔버스. 폭 1080은 두 프리셋 공통이다.
private let post = Size2(width: 1080, height: 1350)
/// iPhone 세로 논리 해상도.
private let 세로 = Size2(width: 390, height: 844)
/// 같은 기기 가로.
private let 가로 = Size2(width: 844, height: 390)

private func 표면(_ viewport: Size2 = 세로) -> CanvasSurface {
    CanvasSurface(canvas: post, viewport: viewport)
}

// MARK: - AC-1·2: fit은 식 하나다

@Test func 세로_화면에서는_폭이_fit을_결정한다() {
    // min(390/1080, 844/1350) = min(0.361, 0.625)
    #expect(isClose(표면(세로).fitScale, 390.0 / 1080.0))
}

@Test func 가로_화면에서는_높이가_fit을_결정한다() {
    // **AC-1과 같은 식에서 나온다.** v4 §1.2 표가 "세로는 폭에, 가로는 높이에"라고
    // 적은 것은 두 규칙이 아니라 min() 하나의 결과다. 분기로 짜면 정사각형에
    // 가까운 뷰포트에서 어긋난다.
    // min(844/1080, 390/1350) = min(0.781, 0.289)
    #expect(isClose(표면(가로).fitScale, 390.0 / 1350.0))
}

// MARK: - AC-3·4: 변환

@Test func 논리에서_화면으로_갔다_오면_제자리다() {
    let s = 표면().zoomed(to: 2.3).centered(on: Vec2(x: 700, y: 300))
    let 원본 = Vec2(x: 411, y: 623)
    let 왕복 = s.toLogical(s.toScreen(원본))
    #expect(isClose(왕복.x, 원본.x))
    #expect(isClose(왕복.y, 원본.y))
}

@Test func 기본_상태에서_캔버스_중심은_뷰포트_중심에_온다() {
    let s = 표면()
    let 화면 = s.toScreen(Vec2(x: 540, y: 675))
    #expect(isClose(화면.x, 195))
    #expect(isClose(화면.y, 422))
}

// MARK: - AC-5·6·7: 줌 50~400%

@Test func 줌은_400퍼센트에서_잘린다() {
    #expect(isClose(표면().zoomed(to: 5).zoom, 4))
}

@Test func 줌은_50퍼센트에서_잘린다() {
    // **fit 아래로 내려가는 것은 의도된 동작이다**(§5.10) — 캔버스 밖으로
    // 밀어낸 레이어를 보고 다시 잡으려면 축소가 필요하다.
    #expect(isClose(표면().zoomed(to: 0.1).zoom, 0.5))
}

@Test func 절대_배율은_fit_곱하기_줌이다() {
    let s = 표면().zoomed(to: 2)
    #expect(isClose(s.scale, s.fitScale * 2))
}

@Test func 줌을_키우면_같은_논리_거리가_화면에서_그만큼_멀어진다() {
    // **`scale`을 속성으로 확인하는 것만으로는 부족하다.** 변환이 `scale` 대신
    // `fitScale`을 쓰면 `zoom`은 아무 데도 안 쓰이는 죽은 숫자가 되는데,
    // 왕복·중앙 보존 같은 성질은 배율에 무관해서 전부 통과한다.
    // 실측으로 확인했다 — 이 테스트가 없을 때 그 변이를 아무도 못 잡았다.
    let 기본 = 표면()
    let 확대 = 기본.zoomed(to: 2)

    let 논리거리 = 100.0
    for (a, b) in [(Vec2(x: 500, y: 675), Vec2(x: 500 + 논리거리, y: 675)),
                   (Vec2(x: 540, y: 600), Vec2(x: 540, y: 600 + 논리거리))] {
        let 기본거리 = Vec2(x: 기본.toScreen(b).x - 기본.toScreen(a).x,
                        y: 기본.toScreen(b).y - 기본.toScreen(a).y)
        let 확대거리 = Vec2(x: 확대.toScreen(b).x - 확대.toScreen(a).x,
                        y: 확대.toScreen(b).y - 확대.toScreen(a).y)

        #expect(isClose(기본거리.x + 기본거리.y, 논리거리 * 기본.fitScale))
        #expect(isClose(확대거리.x + 확대거리.y, 논리거리 * 기본.fitScale * 2))
    }
}

// MARK: - AC-8·9: 팬은 작업 영역까지

@Test func 작업_영역_안의_지점은_그대로_화면_중앙에_온다() {
    let 목표 = Vec2(x: 900, y: 400)
    let s = 표면().centered(on: 목표)
    let 화면 = s.toScreen(목표)
    #expect(isClose(화면.x, 195))
    #expect(isClose(화면.y, 422))
}

@Test func 작업_영역_밖으로는_팬되지_않는다() {
    // §5.10: 작업 영역은 캔버스의 2배 범위다. 그 밖은 줌 아웃으로도 볼 수 없어
    // 레이어를 영영 잡을 수 없게 된다.
    //
    // 캔버스 중심(540)에서 폭의 2배(2160)만큼 떨어진 지점을 요구하면,
    // 경계인 "중심에서 폭(1080)만큼"으로 잘린다.
    let s = 표면().centered(on: Vec2(x: 540 + 2160, y: 675))
    #expect(isClose(s.center.x, 540 + 1080))
    #expect(isClose(s.center.y, 675))
}

// MARK: - AC-10: 줌이 보던 지점을 밀지 않는다

@Test func 줌을_바꿔도_화면_중앙의_논리_지점은_그대로다() {
    let 보던곳 = Vec2(x: 800, y: 900)
    let s = 표면().centered(on: 보던곳)
    let 확대 = s.zoomed(to: 3.5)

    let 중앙 = 확대.toLogical(Vec2(x: 195, y: 422))
    #expect(isClose(중앙.x, 보던곳.x))
    #expect(isClose(중앙.y, 보던곳.y))
}

// MARK: - AC-11~14: 기기 회전

@Test func 회전해도_줌_비율은_그대로고_절대_배율만_새_fit을_따른다() {
    // v4 §1.2: "가로에서 100%였던 것이 세로에서는 100%가 아니다" —
    // 100%는 절대 배율이 아니라 **캔버스가 화면에 꼭 맞는 상태**다.
    let 세로표면 = 표면(세로).zoomed(to: 1.5)
    let 가로표면 = 세로표면.viewportChanged(to: 가로)

    #expect(isClose(가로표면.zoom, 1.5))
    #expect(isClose(가로표면.scale, (390.0 / 1350.0) * 1.5))
    // 절대 배율은 실제로 달라진다 — 안 달라지면 fit 재계산이 안 된 것이다.
    #expect(!isClose(가로표면.scale, 세로표면.scale))
}

@Test func 회전해도_논리좌표는_아무것도_바뀌지_않는다() {
    let s = 표면(세로).zoomed(to: 2).centered(on: Vec2(x: 700, y: 300))
    let 회전 = s.viewportChanged(to: 가로)

    let 원본 = Vec2(x: 411, y: 623)
    let 왕복 = 회전.toLogical(회전.toScreen(원본))
    #expect(isClose(왕복.x, 원본.x))
    #expect(isClose(왕복.y, 원본.y))
}

@Test func 회전해도_보던_논리_지점이_화면_중앙에_남는다() {
    // **캔버스 중심이 아닌 지점**이어야 한다 — 중심이면 팬을 화면 오프셋으로
    // 저장하는 잘못된 구현도 통과한다(둘 다 0이라서).
    let 보던곳 = Vec2(x: 800, y: 900)
    let s = 표면(세로).zoomed(to: 1.5).centered(on: 보던곳)

    let 회전 = s.viewportChanged(to: 가로)

    let 중앙 = 회전.toLogical(Vec2(x: 422, y: 195))
    #expect(isClose(중앙.x, 보던곳.x))
    #expect(isClose(중앙.y, 보던곳.y))
}

@Test func 경계까지_팬한_상태로_회전해도_여전히_경계다() {
    // 작업 영역 제한을 **논리 단위**로 표현한 결과다 — 배율이 바뀌어도 경계
    // 판정이 흔들리지 않아 회전 경로에 재클램프가 필요 없다.
    // 안으로 튕기면 사용자가 보던 것이 사라지고, 밖으로 새면 제한이 무의미해진다.
    let s = 표면(세로).centered(on: Vec2(x: 540 + 5000, y: 675))
    #expect(isClose(s.center.x, 540 + 1080))   // 경계에 닿았다

    let 회전 = s.viewportChanged(to: 가로)

    #expect(isClose(회전.center.x, 540 + 1080))
}

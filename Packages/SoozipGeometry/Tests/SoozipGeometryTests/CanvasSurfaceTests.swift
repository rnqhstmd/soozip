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
/// 9:16 스토리 캔버스. 폭은 같고 높이만 다르다 — **세로 화면에서는 두 프리셋의
/// fit이 같아서, 캔버스 치수를 실제로 읽는지는 가로에서만 드러난다.**
private let story = Size2(width: 1080, height: 1920)
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

@Test func fit은_두_프리셋_모두에서_캔버스_치수를_실제로_읽는다() {
    // **9:16을 한 번도 안 만들면 캔버스 치수를 1080×1350으로 하드코딩해도
    // 전부 초록이다**(실측 확인). 그리고 세로에서는 두 프리셋 모두 폭이 제약이라
    // 값이 같아서, **가로에서만 드러난다** — 가장 늦게 발견되는 종류다.
    for (캔버스, 뷰포트, 기대) in [(post, 세로, 390.0 / 1080.0),
                              (post, 가로, 390.0 / 1350.0),
                              (story, 세로, 390.0 / 1080.0),
                              (story, 가로, 390.0 / 1920.0)] {
        #expect(isClose(CanvasSurface(canvas: 캔버스, viewport: 뷰포트).fitScale, 기대))
    }
}

// MARK: - 극단 입력

@Test func 뷰포트가_0이어도_NaN이_새어나오지_않는다() {
    // **SwiftUI GeometryReader는 첫 레이아웃 패스에서 .zero를 준다** — 실제 경로다.
    let s = CanvasSurface(canvas: post, viewport: Size2(width: 0, height: 0))

    #expect(s.fitScale == 0)
    let 논리 = s.toLogical(Vec2(x: 0, y: 0))       // 나누기 0/0 자리
    #expect(논리.x.isFinite && 논리.y.isFinite)
    let 화면 = s.toScreen(Vec2(x: 540, y: 675))
    #expect(화면.x.isFinite && 화면.y.isFinite)
}

@Test func 영_크기_뷰포트에서_얻은_값을_되먹여도_상태가_오염되지_않는다() {
    // **NaN은 클램프를 그냥 통과한다** — Swift `min`/`max`는 `y >= x ? y : x`라
    // NaN 비교가 전부 거짓이다. 한 번 들어오면 정상 뷰포트가 와도 복구되지 않는다.
    let 영 = CanvasSurface(canvas: post, viewport: Size2(width: 0, height: 0))
    let 되먹임 = 영.centered(on: 영.toLogical(Vec2(x: 100, y: 200)))

    let 복구 = 되먹임.viewportChanged(to: 세로)
    let 화면 = 복구.toScreen(복구.center)
    #expect(isClose(화면.x, 195))
    #expect(isClose(화면.y, 422))
}

@Test func 음수나_비정상_치수는_배율을_0으로_만든다() {
    // **0×0만으로는 `fitScale`의 유효성 가드를 검증하지 못한다** — 가드가 없어도
    // `min(0, 0) = 0`이라 결과가 같다(실측 확인). 가드가 실제로 막는 것은 이쪽이다.
    //
    // 음수 뷰포트: `min`이 음수를 골라 화면이 **좌우 반전 렌더**된다
    // NaN 뷰포트: `min`이 NaN을 그대로 흘린다
    // 캔버스 0: 나누기가 `inf`가 되어 `toScreen`이 NaN을 낸다
    for viewport in [Size2(width: -390, height: 844),
                     Size2(width: .nan, height: 844),
                     Size2(width: .infinity, height: 844)] {
        #expect(CanvasSurface(canvas: post, viewport: viewport).fitScale == 0)
    }

    let 영캔버스 = CanvasSurface(canvas: Size2(width: 0, height: 0), viewport: 세로)
    #expect(영캔버스.fitScale == 0)
    let 화면 = 영캔버스.toScreen(Vec2(x: 10, y: 10))
    #expect(화면.x.isFinite && 화면.y.isFinite)
}

@Test func NaN_줌과_NaN_팬은_무시된다() {
    let s = 표면().zoomed(to: 2).centered(on: Vec2(x: 800, y: 900))

    #expect(isClose(s.zoomed(to: .nan).zoom, 2))
    #expect(isClose(s.centered(on: Vec2(x: .nan, y: .nan)).center.x, 800))
    #expect(isClose(s.centered(on: Vec2(x: .infinity, y: 900)).center.x, 800))
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

    // **성분별로 잰다.** `x + y` 합산은 x/y 전치에 불변이라, 축이 뒤바뀐 구현도
    // 통과시킨다 — "양쪽이 같이 틀리면 성립하는" 단언의 전형이다(실측 확인).
    let 논리거리 = 100.0
    let f = 기본.fitScale

    let 수평 = (Vec2(x: 500, y: 675), Vec2(x: 500 + 논리거리, y: 675))
    #expect(isClose(기본.toScreen(수평.1).x - 기본.toScreen(수평.0).x, 논리거리 * f))
    #expect(isClose(기본.toScreen(수평.1).y - 기본.toScreen(수평.0).y, 0))
    #expect(isClose(확대.toScreen(수평.1).x - 확대.toScreen(수평.0).x, 논리거리 * f * 2))

    let 수직 = (Vec2(x: 540, y: 600), Vec2(x: 540, y: 600 + 논리거리))
    #expect(isClose(기본.toScreen(수직.1).y - 기본.toScreen(수직.0).y, 논리거리 * f))
    #expect(isClose(기본.toScreen(수직.1).x - 기본.toScreen(수직.0).x, 0))
    #expect(isClose(확대.toScreen(수직.1).y - 확대.toScreen(수직.0).y, 논리거리 * f * 2))
}

@Test func 캔버스_모서리가_화면의_정해진_자리에_온다() {
    // **전방 변환의 절대 좌표를 고정하는 유일한 자리다.** 나머지 변환 테스트는
    // 전부 왕복이거나 `center`와 같은 점(델타 0)이라 축이 뒤바뀌어도 성립한다.
    let s = 표면()
    let f = 390.0 / 1080.0

    // 좌상단은 화면 왼쪽 가장자리(fit이 폭 제약이므로 x = 0)
    #expect(isClose(s.toScreen(Vec2(x: 0, y: 0)).x, 0))
    #expect(isClose(s.toScreen(Vec2(x: 0, y: 0)).y, 422 - 675 * f))
    // 우상단은 오른쪽 가장자리
    #expect(isClose(s.toScreen(Vec2(x: 1080, y: 0)).x, 390))
}

// MARK: - AC-8·9: 팬은 작업 영역까지

@Test func 작업_영역_안의_지점은_그대로_화면_중앙에_온다() {
    let 목표 = Vec2(x: 900, y: 400)
    let s = 표면().centered(on: 목표)
    let 화면 = s.toScreen(목표)
    #expect(isClose(화면.x, 195))
    #expect(isClose(화면.y, 422))
}

@Test func 작업_영역_밖으로는_네_방향_모두_팬되지_않는다() {
    // §5.10: 작업 영역은 캔버스의 2배 범위다. 그 밖은 줌 아웃으로도 볼 수 없어
    // 레이어를 영영 잡을 수 없게 된다.
    //
    // **네 방향을 다 잰다.** x 양방향 하나만 재면 y 클램프를 통째로 지워도,
    // y 반경을 `canvas.width`로 잘못 써도, 하한을 지워도 전부 초록이다(실측 확인).
    // y 반경이 `canvas.height`(1350)라는 사실이 코드에만 있으면 안 된다.
    let c = Vec2(x: 540, y: 675)
    for (요청, 기대) in [(Vec2(x: c.x + 9999, y: c.y), Vec2(x: c.x + 1080, y: c.y)),
                       (Vec2(x: c.x - 9999, y: c.y), Vec2(x: c.x - 1080, y: c.y)),
                       (Vec2(x: c.x, y: c.y + 9999), Vec2(x: c.x, y: c.y + 1350)),
                       (Vec2(x: c.x, y: c.y - 9999), Vec2(x: c.x, y: c.y - 1350))] {
        let s = 표면().centered(on: 요청)
        #expect(isClose(s.center.x, 기대.x))
        #expect(isClose(s.center.y, 기대.y))
    }
}

@Test func 연속으로_팬해도_작업_영역을_벗어나지_못한다() {
    // **클램프 기준이 캔버스 중심으로 고정돼 있는가.** 현재 `center`를 기준으로
    // 삼는 구현도 *첫 호출*은 똑같이 통과한다 — 기본 `center`가 곧 캔버스
    // 중심이라서다. 팬은 본질적으로 드래그 프레임마다 연속 호출되므로,
    // 기준이 따라가면 한 번의 플릭으로 무제한 이탈한다.
    let s = 표면()
        .centered(on: Vec2(x: 540 + 1080, y: 675))   // 경계
        .centered(on: Vec2(x: 540 + 2160, y: 675))   // 더 밀어 본다

    #expect(isClose(s.center.x, 540 + 1080))
}

@Test func 팬해도_줌은_그대로다() {
    // F(줌이 center를 리셋)의 대칭. 확대 상태에서 두 손가락 드래그로 팬할 때
    // 줌이 fit으로 튀면 세밀 배치 중에 화면이 통째로 축소된다.
    let s = 표면().zoomed(to: 3).centered(on: Vec2(x: 800, y: 900))
    #expect(isClose(s.zoom, 3))
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

@Test func fit_복귀는_배율과_보던_지점을_함께_되돌린다() {
    // **`zoom = 1`만으로는 부족하다.** 작업 영역 끝까지 팬해 둔 상태에서 배율만
    // 되돌리면 캔버스가 화면 밖에 그대로 남는다 — 사용자는 "맞춤으로 복귀"를
    // 눌렀는데 빈 화면을 본다.
    let 멀리 = 표면().zoomed(to: 3).centered(on: Vec2(x: 540 + 5000, y: 675))
    let 복귀 = 멀리.fitted()

    #expect(isClose(복귀.zoom, 1))
    let 화면 = 복귀.toScreen(복귀.canvasCenter)
    #expect(isClose(화면.x, 195))
    #expect(isClose(화면.y, 422))
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

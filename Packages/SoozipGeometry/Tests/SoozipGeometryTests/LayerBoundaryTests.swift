import Testing
import Foundation
@testable import SoozipGeometry

// EDITOR-9 — 캔버스 경계. 레이어가 캔버스와 어떻게 겹치는가.
//
// 설계 SSOT: v4 §5.10
//
// 레이어 프레임(회전 포함)이 캔버스 사각형과 완전히 안(.inside), 일부(.partial),
// 완전히 밖(.outside)인지 판정하는 overlap(canvas:)의 계약을 고정한다.
// SAT(분리축 정리) 기반 구현을 가정해 x·y·u·v 네 축 각각의 유일한 증인과
// 포함 판정의 부등호 양쪽, 비유한 값 가드를 개별 테스트로 고정한다.

/// 4:5 피드 캔버스.
private let post = Size2(width: 1080, height: 1350)

private func 레이어(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double, rot: Double = 0) -> LayerFrame {
    LayerFrame(center: Vec2(x: cx, y: cy), size: Size2(width: w, height: h), rotation: rot)
}

@Test func 캔버스에_다_들어간_레이어는_완전히_안이다() {
    #expect(레이어(540, 675, 200, 200).overlap(canvas: post) == .inside)
}

@Test func 한쪽_경계를_넘으면_부분_겹침이다() {
    #expect(레이어(1080, 675, 200, 200).overlap(canvas: post) == .partial)
}

@Test func 캔버스와_떨어진_레이어는_완전히_밖이다() {
    #expect(레이어(-500, 675, 200, 200).overlap(canvas: post) == .outside)
}

@Test func 회전한_레이어는_바운딩박스가_아니라_실제_형태로_판정한다() {
    // u축의 유일한 증인. 이 테스트를 지우면 AABB 근사 구현이 AC-17 하나에만 걸린다.
    // 회전한 다이아몬드는 실제로 캔버스 밖(.outside)인데, AABB로 근사하면 겹치는
    // 것처럼(.partial) 보인다.
    let 대각 = (2.0).squareRoot() * 100
    #expect(레이어(-60, -60, 대각, 대각, rot: .pi / 4).overlap(canvas: post) == .outside)

    // 같은 중심의 AABB 상당 도형(회전 0)은 실제로 .partial이어야 한다.
    // 두 값이 같아지면(둘 다 .partial) 회전이 무시된 것 — 좌표를 단언하지
    // 않고도 위 입력이 정말 회전한 다이아몬드인지를 이 대조가 고정한다.
    #expect(레이어(-60, -60, 200, 200, rot: 0).overlap(canvas: post) == .partial)
}

@Test func 코너가_하나도_안_겹쳐도_몸통이_관통하면_부분_겹침이다() {
    // 코너 포함 검사만 하는 구현을 죽인다. 레이어 코너 4점 중 캔버스 안: 0개,
    // 캔버스 꼭짓점 4점 중 레이어 안: 0개인데도 얇고 긴 레이어가 캔버스를 관통한다.
    #expect(레이어(540, 675, 10, 4000, rot: 0).overlap(canvas: post) == .partial)
}

@Test func 캔버스와_정확히_같은_레이어는_경계를_안쪽으로_쳐서_완전히_안이다() {
    // contains의 두 부등호 양쪽을 고정한다. 양축 동시 등호(0<=0, 1080<=1080)라
    // 어느 쪽을 엄격 부등호로 바꿔도 이 테스트가 죽는다.
    #expect(레이어(540, 675, 1080, 1350, rot: 0).overlap(canvas: post) == .inside)
}

@Test func 크기_0_레이어가_안에_있으면_완전히_안이다() {
    // 퇴화 구간(lower == upper)에서 포함이 성립하는지.
    #expect(레이어(540, 675, 0, 0, rot: 0).overlap(canvas: post) == .inside)
}

@Test func 크기_0_레이어가_밖에_있으면_완전히_밖이다() {
    // 퇴화 구간(lower == upper)에서 분리가 성립하는지.
    #expect(레이어(-10, -10, 0, 0, rot: 0).overlap(canvas: post) == .outside)
}

@Test func 캔버스를_통째로_덮는_레이어는_완전히_안이_아니라_부분_겹침이다() {
    // contains의 인자 순서를 고정한다. 6번(캔버스와 정확히 같은 레이어)은
    // 좌우 대칭이라 순서를 뒤집어도 통과하지만, 레이어가 캔버스보다 훨씬 크면
    // "캔버스가 레이어 안" 판정과 "레이어가 캔버스 안" 판정이 갈린다.
    #expect(레이어(540, 675, 2000, 2500, rot: 0).overlap(canvas: post) == .partial)
}

@Test func 레이어_값이_하나라도_비유한이면_완전히_밖이다() {
    // 이 테스트는 레이어 유한성 가드의 유일 증인이다. 가드를 지우면 세 입력
    // 전부 .outside가 아니라 .inside가 된다(Swift 실측) — 세 값 중 가장
    // 위험한 오판이다("정상 렌더, 고스트 없음"으로 보인다). 이유: 전 원소가
    // NaN인 투영이 Interval의 ±∞ 씨앗값 때문에 뒤집힌 빈 구간(lower = +∞,
    // upper = −∞)이 되고, contains가 0 <= +∞ && −∞ <= 1080으로 공허하게
    // 참이 되기 때문이다. 상세는 LayerBoundary.swift의 overlap(canvas:) doc
    // 참조(프로덕션이 원장, 테스트는 포인터).
    let 케이스들: [(라벨: String, 대상: LayerFrame)] = [
        ("center.x가 NaN", 레이어(.nan, 675, 200, 200)),
        ("width가 무한대", LayerFrame(center: Vec2(x: 540, y: 675), size: Size2(width: .infinity, height: 200), rotation: 0)),
        ("rotation이 NaN", 레이어(540, 675, 200, 200, rot: .nan)),
    ]
    for (라벨, 대상) in 케이스들 {
        #expect(대상.overlap(canvas: post) == .outside, "\(라벨)")
    }
}

@Test func 좌상단_한_점만_닿아도_완전히_밖이_아니라_부분_겹침이다() {
    // 겹침 판정 부등호의 한쪽(캔버스.lower <= 레이어.upper)을 고정한다.
    #expect(레이어(-100, -100, 200, 200, rot: 0).overlap(canvas: post) == .partial)
}

@Test func x_y_u축이_다_겹쳐도_v축_하나가_분리되면_완전히_밖이다() {
    // v축의 유일한 증인. 신설 전 이 축은 증인이 0건이었다. x·y·u 세 축은
    // 전부 겹침을 보고하고 v만 분리한다.
    let 대각 = (2.0).squareRoot() * 100
    #expect(레이어(1140, -60, 대각, 대각, rot: .pi / 4).overlap(canvas: post) == .outside)

    // AABB 상당 도형(회전 0)은 실제로 .partial — 회전이 무시되면 두 값이 같아진다.
    #expect(레이어(1140, -60, 200, 200, rot: 0).overlap(canvas: post) == .partial)
}

@Test func 반대쪽_모서리에_한_점만_닿아도_부분_겹침이다() {
    // 겹침 판정 부등호의 반대쪽(레이어.lower <= 캔버스.upper)을 고정한다.
    // 11번(좌상단 한 점)만으로는 이 변이가 살아남는다.
    #expect(레이어(1180, 1450, 200, 200, rot: 0).overlap(canvas: post) == .partial)
}

@Test func 캔버스_치수가_비유한이거나_0_이하면_완전히_밖이다() {
    // 캔버스 치수 가드의 증인. 세 입력 전부 가드 없는 구현과 답이 갈리도록
    // 골랐다 — 가드가 없으면 ⓐ는 .partial, ⓑ는 .inside(무한 캔버스라 모든
    // 레이어가 안에 들어간다), ⓒ는 .partial이 된다.
    let 케이스들: [(라벨: String, 캔버스: Size2, 대상: LayerFrame)] = [
        ("캔버스 width가 NaN", Size2(width: .nan, height: 1350), 레이어(0, 675, 200, 200)),
        ("캔버스 height가 무한대", Size2(width: 1080, height: .infinity), 레이어(540, 675, 200, 200)),
        ("캔버스 width가 0", Size2(width: 0, height: 1350), 레이어(0, 675, 200, 200)),
    ]
    for (라벨, 캔버스, 대상) in 케이스들 {
        #expect(대상.overlap(canvas: 캔버스) == .outside, "\(라벨)")
    }
}

@Test func 회전한_레이어가_x축에서만_분리되면_완전히_밖이다() {
    // x축의 유일한 증인. 회전이 반드시 필요하다 — 회전 0에서는 cos(0)=1,
    // sin(0)=0이 정확값이라 u ≡ x가 되어 쌍둥이 축이 대신 분리한다.
    // 회전 0인 입력으로는 이 변이를 절대 못 잡는다.
    #expect(레이어(-260, 675, 200, 200, rot: .pi / 6).overlap(canvas: post) == .outside)
}

@Test func 회전한_레이어가_y축에서만_분리되면_완전히_밖이다() {
    // y축의 유일한 증인. 같은 이유로 회전 필수(v ≡ y).
    #expect(레이어(540, -260, 200, 200, rot: .pi / 6).overlap(canvas: post) == .outside)
}

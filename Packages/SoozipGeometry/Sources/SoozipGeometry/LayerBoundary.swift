import Foundation

/// 레이어 프레임(회전 포함)이 캔버스 사각형과 어떻게 겹치는지의 세 값
/// (`EDITOR-9`, v4 §5.10). `LayerFrame.overlap(canvas:)`가 반환한다.
public enum CanvasOverlap: Equatable, Sendable { case inside, partial, outside }

extension LayerFrame {

    /// 이 레이어(회전 포함)가 캔버스 사각형과 겹치는 방식을 판정한다.
    ///
    /// **`.partial`의 계약**: "겹침 영역이 존재한다"만 뜻하고 **넓이가
    /// 양수임을 뜻하지 않는다.** 코너 하나만 캔버스에 닿는 레이어는 겹침
    /// 넓이가 정확히 0인데도 `.partial`이다
    /// (`좌상단_한_점만_닿아도_완전히_밖이_아니라_부분_겹침이다` ·
    /// `반대쪽_모서리에_한_점만_닿아도_부분_겹침이다`). `EDITOR-11`은 이
    /// 판정이 낸 빈 클립 경로를 받을 수 있고, 그것을 오류로 다루거나
    /// 겹침 넓이로 나누면 안 된다 — 렌더 패스 트리거나 사용자 신호로도
    /// 쓰면 안 된다.
    ///
    /// **이 판정은 조회 전용이다** — 레이어의 `center`·`size`·`rotation`을
    /// 잘라내거나 변형하지 않는다(v4 §5.10의 "잘린 데이터는 버리지 않는다").
    /// ⚠️ **그것을 단언하는 테스트는 일부러 두지 않았다.** 비변경 메서드에
    /// struct를 값으로 넘기면 호출부 사본은 Swift 값 의미론상 **구조적으로**
    /// 안 바뀌므로, 단언을 두면 어떤 변이도 죽이지 못하는 무효 단언이 된다.
    /// 이 문단이 그 보장의 기록이고, 테스트 슬롯은 실제 판정력이 있는
    /// 케이스에 썼다.
    ///
    /// **`.inside`의 기준은 "레이어가" 캔버스 안에 있느냐다.** 캔버스를
    /// 통째로 덮는(레이어가 캔버스보다 큰) 레이어는 `.inside`가 아니라
    /// `.partial`이다
    /// (`캔버스를_통째로_덮는_레이어는_완전히_안이_아니라_부분_겹침이다`) —
    /// "캔버스가 레이어 안"과는 다른 명제다.
    ///
    /// **판정 순서(SAT, 분리축 정리)**:
    /// 1. 유한성 가드. 레이어·캔버스 스칼라 중 하나라도 `NaN`/무한대이거나
    ///    캔버스 치수가 0 이하이면 그 자리에서 `.outside`.
    /// 2. 레이어 코너 4점(`corner(_:)`)과 캔버스 코너 4점을 각각 x·y·u·v
    ///    네 축에 투영해 구간(`Interval`)을 만든다.
    /// 3. 포함 판정 — **캔버스 축(x·y) 두 개만** 쓴다. 볼록집합이 직사각형에
    ///    들어갈 필요충분조건은 **담는 쪽(캔버스)의 면 법선**이다. 레이어
    ///    축(u·v)을 섞으면 불필요하고, u·v만으로 판정하면 더 약한 명제가
    ///    되어 틀린다.
    /// 4. 분리 판정 — x·y·u·v 네 축 전부. 네 축 중 **어느 하나에서라도**
    ///    투영 구간이 겹치지 않으면 두 사각형은 서로소다 — "어떤 축에서
    ///    분리됨"은 서로소임의 충분 증명이라, 축을 더 넣으면 증명 기회가
    ///    늘 뿐 거짓 분리가 나올 수 없다(중복 축이 오답을 만들지 않는
    ///    이유).
    /// 5. 3·4를 모두 피하면 `.partial`.
    ///
    /// **회전 0에서 `u ≡ x`, `v ≡ y`가 비트 단위로 정확히 성립한다**
    /// (`cos(0)=1.0`·`sin(0)=0.0`이 정확값). 그래서 x·y만으로 분리되는
    /// 입력을 x·y 축 하나를 지운 변이가 여전히 통과할 수 있다 — 쌍둥이
    /// 축(u·v)이 대신 분리하기 때문이다. x·y 축 각각의 유일한 증인은
    /// 회전한(0이 아닌) 입력으로만 만들 수 있다
    /// (`회전한_레이어가_x축에서만_분리되면_완전히_밖이다` ·
    /// `회전한_레이어가_y축에서만_분리되면_완전히_밖이다`).
    ///
    /// **레이어 축(rotation) 유한성 가드에는 증인이 있다**(실측:
    /// `레이어_값이_하나라도_비유한이면_완전히_밖이다`가 세 입력 전부에서
    /// 가드 없는 구현과 갈린다). 가드를 지우면 결과는 `.outside`가 아니라
    /// **`.inside`**가 된다 — 세 값 중 가장 위험한 오판이다("정상 렌더,
    /// 고스트 없음"으로 보인다).
    ///
    /// **그 증인을 만드는 것은 `Interval.init`의 `reduce` 씨앗값(`±∞`)이다.**
    /// 투영이 전부 `NaN`이면 `reduce(Double.infinity, min)`은
    /// `min(+∞, NaN)`에서 `NaN < +∞`가 거짓이라 씨앗값 `+∞`를 그대로
    /// 유지한다(`upper`도 대칭으로 `-∞`를 유지). 결과는 `lower = +∞`,
    /// `upper = -∞`인 **뒤집힌 빈 구간**이고, `contains`가
    /// `0 <= +∞ && -∞ <= 1080`으로 **공허하게 참**이 되어 `.inside`가
    /// 나온다.
    ///
    /// **대조**: 씨앗값 없이 첫 원소에서 시작하는 접기(`var lo =
    /// projections[0]; for x in projections.dropFirst() { lo = min(lo, x) }`)
    /// 였다면 `lower`·`upper`가 둘 다 `NaN`이 되고, 그때는 `contains`가
    /// 거짓이라 `.outside`가 나온다 — 그 구현에서는 정말로 증인이 없다.
    /// 즉 씨앗값을 없애는 리팩터링은 **가드가 있고 아래 "유한 입력에서
    /// 코너가 넘치는 구간"이 도달 불가인 한** 동작을 바꾸지 않지만, 이
    /// 가드의 증인 하나를 조용히 지운다. (그 구간에서는 투영이 *부분*
    /// NaN이 되어 두 접기가 갈린다 — 씨앗 접기는 `[-∞, 유한]`, 첫-원소
    /// 접기는 `NaN`. `EDITOR-7` 크기 상한과 이 단위의 중심 클램프를
    /// 거치면 도달 불가라 실무 영향은 없다.)
    ///
    /// 그래도 가드를 남기는 또 다른 이유는, `overlaps`를 유한 입력에서
    /// 완전히 동치인 `separated` 형태(`upper < other.lower || other.upper
    /// < lower`)로 바꾸는 리팩터링이 들어오면 `NaN` 비교에서 그 식이
    /// 거짓이 되어 결과가 뒤집히는데, 유한 입력에서는 두 표현이 한
    /// 비트도 다르지 않아 어떤 테스트도 그 리팩터링을 잡지 못하기
    /// 때문이다. 오늘은 중복 방어이고 그날은 유일한 방어선이다.
    ///
    /// **캔버스 치수 가드에는 증인이 있다**
    /// (`캔버스_치수가_비유한이거나_0_이하면_완전히_밖이다`). `canvas.width`가
    /// `NaN`이면 캔버스 코너 x값이 `[0, NaN, NaN, 0]`인데, 씨앗값 접기에서는
    /// 순서가 무관하다 — 비-NaN 원소가 하나라도 있으면 위치와 무관하게
    /// 그것이 남는다(전부 NaN일 때만 씨앗값이 남는다). 그래서 `Interval`
    /// 접기에서 NaN이 전부 탈락해 `lower`·`upper`가 둘 다 `0.0`이 된다 —
    /// 캔버스가 조용히 폭 0으로 퇴화한다.
    /// `canvas.height = .infinity`면 캔버스가 무한 띠가 되어 모든
    /// 레이어가 `.inside`가 된다.
    ///
    /// **허용오차를 넣지 않는다.** 캔버스와 정확히 같은 크기인 레이어가
    /// 90°·180°·270°·360° 회전에서는 부동소수 오차(`cos(π/2)`가 정확히
    /// 0이 아님)로 `.inside`가 아니라 `.partial`이 될 수 있다. 고정
    /// 절대 ε는 원리적으로 충분할 수 없다 — 필요한 오차 크기가
    /// `반지름 × 각도오차`인데 반지름은 `EDITOR-7` 상한까지 커지고
    /// 각도오차는 누적 바퀴 수에 비례해 무제한으로 커진다(`EDITOR-8`이
    /// 바퀴 수 보존을 확정했다). `SnapEngine.isAxisAligned`가 같은
    /// 현상을 각도 허용오차로 고친 것과 다르게 답하는 것은 의도다 —
    /// 스냅 후보 탈락은 회수 가능한 실패이고 단위가 각도지만, 이쪽은
    /// 좌표라 상수로 닫을 수 없다. 이 부동소수 오차로 인한 `.partial`도
    /// 위 `.partial` 계약의 적용 대상이다 — `EDITOR-11`은 이것을 렌더
    /// 패스 트리거나 사용자 신호로 쓰면 안 된다. 캔버스를 꽉 채운 배경
    /// 사진이 180°에서 매 프레임 빈 고스트 패스를 열게 된다.
    ///
    /// **측정된 변이 킬셋(실측, `swift test`로 변이 적용해 확인)**:
    ///
    /// | 변이 | 죽는 테스트 |
    /// |---|---|
    /// | `u`·`v` 축 둘 다 삭제(AABB 근사) | `회전한_레이어는_바운딩박스가_아니라_실제_형태로_판정한다` · `x_y_u축이_다_겹쳐도_v축_하나가_분리되면_완전히_밖이다` |
    /// | `x`축만 삭제 | `회전한_레이어가_x축에서만_분리되면_완전히_밖이다` |
    /// | `y`축만 삭제 | `회전한_레이어가_y축에서만_분리되면_완전히_밖이다` |
    /// | `u`축만 삭제 | `회전한_레이어는_바운딩박스가_아니라_실제_형태로_판정한다` |
    /// | `v`축만 삭제 | `x_y_u축이_다_겹쳐도_v축_하나가_분리되면_완전히_밖이다` |
    /// | 포함 판정에서 y축 검사 제거 | `코너가_하나도_안_겹쳐도_몸통이_관통하면_부분_겹침이다` · `회전한_레이어가_y축에서만_분리되면_완전히_밖이다` |
    /// | `contains` 두 부등호를 `<`로 | `캔버스와_정확히_같은_레이어는_경계를_안쪽으로_쳐서_완전히_안이다` |
    /// | `contains` 인자 뒤집기 | `캔버스에_다_들어간_레이어는_완전히_안이다` · `캔버스를_통째로_덮는_레이어는_완전히_안이_아니라_부분_겹침이다` · `크기_0_레이어가_안에_있으면_완전히_안이다` |
    /// | `overlaps` 첫 부등호를 `<`로 | `좌상단_한_점만_닿아도_완전히_밖이_아니라_부분_겹침이다` |
    /// | `overlaps` 둘째 부등호를 `<`로 | `반대쪽_모서리에_한_점만_닿아도_부분_겹침이다` |
    /// | 레이어 유한성 가드 제거 | `레이어_값이_하나라도_비유한이면_완전히_밖이다` |
    /// | 캔버스 치수 가드 제거 | `캔버스_치수가_비유한이거나_0_이하면_완전히_밖이다` |
    ///
    /// **네 분리축(`x`·`y`·`u`·`v`) 각각에 유일 증인이 1건씩 있다** — 표의
    /// "`x`축만 삭제"·"`y`축만 삭제"·"`u`축만 삭제"·"`v`축만 삭제" 네 줄이
    /// 각각 서로 다른 테스트 하나씩을 죽인다. 어느 하나를 지우면 그 축이
    /// 무증인이 된다.
    public func overlap(canvas: Size2) -> CanvasOverlap {
        // ① 유한성 가드. corner(_:)를 부르기 전에 반드시 여기서 걸러야
        // 한다 — 코너를 만든 뒤 검사하면 이미 NaN이 생긴 뒤다
        // (예: size.width = .infinity, rotation = 0이면
        // toWorld의 y 성분이 675 + (±∞ × 0.0) + (±100) = NaN).
        guard center.x.isFinite, center.y.isFinite,
              size.width.isFinite, size.height.isFinite,
              rotation.isFinite,
              canvas.width.isFinite, canvas.height.isFinite,
              canvas.width > 0, canvas.height > 0
        else {
            return .outside
        }

        // ② 점 집합.
        let layerPoints = [corner(.topLeft), corner(.topRight),
                            corner(.bottomRight), corner(.bottomLeft)]
        let canvasPoints = [Vec2(x: 0, y: 0), Vec2(x: canvas.width, y: 0),
                             Vec2(x: canvas.width, y: canvas.height), Vec2(x: 0, y: canvas.height)]

        // 축은 rotation에서 직접 만든다. corner(.topRight) - corner(.topLeft)
        // 같은 코너 차분으로 만들면 size 0×0에서 두 코너가 같은 점이 되어
        // 차분이 (0,0)이 되고, 그 정규화가 (NaN,NaN)을 낸다 —
        // 크기_0_레이어가_안에_있으면_완전히_안이다·
        // 크기_0_레이어가_밖에_있으면_완전히_밖이다가 그 입력을 실제로 지나간다.
        let x = Vec2(x: 1, y: 0)
        let y = Vec2(x: 0, y: 1)
        let u = Vec2(x: cos(rotation), y: sin(rotation))
        let v = Vec2(x: -sin(rotation), y: cos(rotation))

        let layerOnX = Interval(projecting: layerPoints, onto: x)
        let layerOnY = Interval(projecting: layerPoints, onto: y)
        let canvasOnX = Interval(projecting: canvasPoints, onto: x)
        let canvasOnY = Interval(projecting: canvasPoints, onto: y)

        // ③ 포함 판정 — 캔버스 축 2개만.
        if canvasOnX.contains(layerOnX), canvasOnY.contains(layerOnY) {
            return .inside
        }

        // ④ 분리 판정 — x·y·u·v 네 축.
        let layerOnU = Interval(projecting: layerPoints, onto: u)
        let layerOnV = Interval(projecting: layerPoints, onto: v)
        let canvasOnU = Interval(projecting: canvasPoints, onto: u)
        let canvasOnV = Interval(projecting: canvasPoints, onto: v)

        guard canvasOnX.overlaps(layerOnX),
              canvasOnY.overlaps(layerOnY),
              canvasOnU.overlaps(layerOnU),
              canvasOnV.overlaps(layerOnV)
        else {
            return .outside
        }

        // ⑤ 포함도 분리도 아니면 부분 겹침.
        return .partial
    }
}

/// 점 집합을 한 축에 투영한 폐구간.
///
/// **`private`인 이유**: `overlap(canvas:)`의 x·y·u·v 네 축 비교가 전부
/// 이 하나의 `overlaps`/`contains`를 거치게 하기 위해서다. 축별로
/// 비교를 인라인하거나 분기시키면(예: x축만 `<`, u축만 `<=`) 회전축
/// 부등호가 곧바로 무증인이 된다 — `overlap(canvas:)` 문서의 x·y 축
/// 증인(`회전한_레이어가_x축에서만_분리되면_완전히_밖이다` ·
/// `회전한_레이어가_y축에서만_분리되면_완전히_밖이다`)이 지키는 것은
/// 실제로는 `Interval`의 부등호 하나이지, 축마다 따로 있는 게 아니다.
///
/// **프로퍼티 이름을 `min`/`max`로 짓지 않는다.** 이니셜라이저 안에서
/// `min(a, b)`를 부르면 그 이름의 자기 프로퍼티가 전역 `min` 함수를
/// 가려 `cannot call value of non-function type 'Double'`이 난다.
///
/// **`points`는 비지 않아야 한다.** 비면 뒤집힌 빈 구간이 되어
/// `contains`가 공허하게 참이 된다 — NaN 경로와 같은 실패 모드이고
/// 진입 경로만 다르다. 지금은 점 배열이 2개(레이어·캔버스)뿐이고
/// 둘 다 4점 리터럴이라(호출 지점은 축 4개 × 배열 2개 = 8곳) 도달
/// 불가하고, `private`이 그것을 유지한다.
private struct Interval {
    let lower: Double
    let upper: Double

    init(projecting points: [Vec2], onto axis: Vec2) {
        let projections = points.map { $0.x * axis.x + $0.y * axis.y }
        lower = projections.reduce(Double.infinity, min)
        upper = projections.reduce(-Double.infinity, max)
    }

    /// 두 구간이 최소 한 점을 공유하는가. 양쪽 부등호가 전부 `<=`다 —
    /// 한 점만 닿는 경우(구간이 딱 맞닿는 경우)를 겹침으로 본다
    /// (`overlap(canvas:)`의
    /// `좌상단_한_점만_닿아도_완전히_밖이_아니라_부분_겹침이다` ·
    /// `반대쪽_모서리에_한_점만_닿아도_부분_겹침이다`가 이 두 부등호를
    /// 각각 고정한다).
    func overlaps(_ other: Interval) -> Bool {
        lower <= other.upper && other.lower <= upper
    }

    /// `self`가 `other`를 담는가. 양쪽 부등호가 전부 `<=`라 경계가
    /// 정확히 맞닿아도(등호) 포함이다 (`overlap(canvas:)`의
    /// `캔버스와_정확히_같은_레이어는_경계를_안쪽으로_쳐서_완전히_안이다`가
    /// 양축 동시 등호로 이 두 부등호를 고정한다).
    func contains(_ other: Interval) -> Bool {
        lower <= other.lower && other.upper <= upper
    }
}

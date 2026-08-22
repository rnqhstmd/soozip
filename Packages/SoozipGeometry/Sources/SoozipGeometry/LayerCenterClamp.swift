import Foundation

extension CanvasSurface {

    /// 레이어 중심을 작업 영역 안으로 자른다(`EDITOR-9`, v4 §5.10).
    ///
    /// **`clampedToWorkArea`를 그대로 부르고 다시 계산하지 않는다.** 이 경계는
    /// `workArea`에 이미 공개되어 있고, `centered(on:)`(팬)도 같은 경계를
    /// 쓴다. 두 벌로 갈라지면 "팬으로 못 닿는 곳에 레이어가 놓이거나,
    /// 레이어가 못 가는 곳까지 팬되는" 어긋남이 조용히 생긴다(BR-4).
    ///
    /// **비유한 가드가 필요한 이유(실측)**: `clampedToWorkArea`는 방어가
    /// 없다. `∞`를 방어 없이 넣으면 `min(max(∞, −540), 1620)`이
    /// `1620`을 내 **조용히 유한해진다** — 그럴듯한 좌표라 아무도
    /// 눈치채지 못한다. `NaN`은 다른 경로다: `min(max(NaN, −540),
    /// 1620)`이 `NaN` 그대로 통과한다(Swift `min`/`max`는 `y >= x ? y
    /// : x` 형태라 `NaN` 비교가 전부 거짓이라서다). 두 비유한 종류가
    /// 서로 다르게 처리되고 **둘 다 방어가 아니다.** `NaN`이 레이어
    /// 중심에 앉으면 `JSONEncoder`가 던져 문서 저장 자체가 실패한다
    /// (`EDITOR-8`이 `rotation` 축에서 실제로 발견해 제거한 실패와 같은
    /// 형태다).
    ///
    /// **후퇴 목표가 `canvasCenter`인 이유**: `CanvasSurface.toLogical`이
    /// 배율 0일 때 "`NaN`을 흘리는 대신 유일하게 방어 가능한 답인
    /// `center`를 낸다"는 선례를 따른다. 그리고 `canvasCenter`는 언제나
    /// 작업 영역 안이라(캔버스는 작업 영역의 절반 크기) 후퇴 경로도
    /// 멱등이다 — 후퇴 목표가 작업 영역 밖이었다면
    /// `clamp(clamp(x)) ≠ clamp(x)`가 되어 멱등성이 깨진다.
    ///
    /// **시그니처가 `Vec2 → Vec2`인 것이 의도다.** `size`·`rotation`이
    /// 들어오지 않으므로 "바운딩 박스를 작업 영역에 맞추는" 구현은
    /// 작성 자체가 불가능하다 — 클램프가 중심에만 적용된다는 규칙을
    /// 타입이 강제한다.
    ///
    /// ⚠️ **`EDITOR-11` 인계 (`EDITOR-10`이 좁힘)**: 레이어 중심을 바꾸는
    /// 경로와 각각의 상태는 `context/editor/architecture.md`의 「중심을
    /// 바꾸는 경로」 표가 단일 출처다 — `EDITOR-10`이 닫은 것은 그중 **이동
    /// 축(모듈 밖 세터) 하나뿐이며**, 여기에 목록을 복제하지 않는다(복제하면
    /// 갈라진다). `LayerFrame.center`가 `internal(set)`이 되어 모듈 밖에서는
    /// `frame.center = …`도 부분 대입도 컴파일되지 않고, 이 함수 자신도
    /// `internal`로 좁혀 모듈 밖에서 직접 부를 수 없다. 이 함수를 거치지
    /// 않는 경로가 여전히 있다는 사실만 국소적으로 남긴다 —
    /// `LayerFrame.init`은 `center`를 검증 없이 그대로 받고,
    /// `ResizeAnchor`의 리사이즈 경로도 이 함수를 거치지 않는다(둘 다 예시일
    /// 뿐, 전체 목록은 위 표를 본다). 그리고 이 함수가 `internal`이 되었다는 것 자체가
    /// `SoozipGeometry` 모듈 내부(선언 모듈 안)에서는 여전히 아무 제약 없이
    /// 호출 가능하다는 뜻이다 — "게이트가 완료됐다"로 읽으면 안 된다.
    ///
    /// **입력 `p`의 유한성만 검사하고 `canvas` 유효성은 검사하지 않는다
    /// — 자매 함수 `overlap(canvas:)`와의 이 비대칭은 의도다.**
    /// `overlap(canvas: Size2)`는 임의의 인자를 받는다 — 호출부가
    /// 실수로 `viewport`를 넘길 수 있다(둘 다 `Size2`라 컴파일된다).
    /// 그래서 방어한다. `clampedLayerCenter`는 생성 시 확정된 자기
    /// 상태(`self.canvas`)를 읽는다. 검증은 그 값이 들어오는 디코딩
    /// 경계에서 한 번 하는 것이 맞다.
    /// ⚠️ **그런데 그 검증이 지금 없다.** `LayoutDocument`가
    /// `canvas.w`/`h`를 `isFinite`·`> 0` 검사 없이 디코딩한다
    /// (`Packages/SoozipLayout/Sources/SoozipLayout/LayoutDocument.swift`의
    /// `init(from:)`). `{"w": 0, "h": 1350}` 같은 문서로 도달 가능하고,
    /// 그러면 `workArea`가 `x = 0`인 **수직 선분**(`y ∈ [-675, 2025]`)으로
    /// 납작해져 모든 레이어 중심의 x가 `0`으로 붕괴한다. `{"w": 0, "h": 0}`
    /// 이면 `workArea`가 **한 점 `(0,0)`**이 되어 모든 중심이 그 한 점으로
    /// 뭉개진다. 크래시는 없지만 "영영 못 잡음"과 사실상 같은 기능 붕괴다.
    /// `LayoutDocument` 디코딩 검증은 이월 항목이다(이 단위 범위 밖 —
    /// `SoozipLayout` 소관).
    ///
    /// **측정된 변이 킬셋**:
    ///
    /// | 변이 | 죽는 테스트 |
    /// |---|---|
    /// | 작업 영역 대신 캔버스 경계로 클램프 | `중심은_캔버스가_아니라_작업_영역_경계에서_잘린다` |
    /// | 비유한 가드 제거(`clampedToWorkArea` 직접 호출) | `무한대_중심은_경계로_잘리지_않고_캔버스_중심으로_후퇴한다` · `NaN_중심도_무한대와_같은_캔버스_중심을_낸다` |
    /// | 경계에 `zoom`/`scale` 곱하기 | `클램프_결과는_줌과_뷰포트에_무관하다` |
    /// | 무조건 `canvasCenter`로 밀기 | `작업_영역_경계에_있는_중심은_안쪽으로_당겨지지_않는다` · `이미_작업_영역_안인_중심은_두_번_클램프해도_그대로다` |
    /// **`EDITOR-10`이 `public`을 뗐다** — `EDITOR-9`가
    /// `clampedToWorkArea`에 한 것과 같은 조치다(`CanvasSurface.clampedToWorkArea`
    /// doc의 "internal인 이유" 참고). 이 값을 감싸는 `ClampedLayerCenter`가
    /// 이제 유일한 공개 경로다. 기존 호출자는 `@testable` 테스트뿐이라
    /// 비용 0이다.
    func clampedLayerCenter(_ p: Vec2) -> Vec2 {
        guard p.x.isFinite, p.y.isFinite else { return canvasCenter }
        return clampedToWorkArea(p)
    }
}

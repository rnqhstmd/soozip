import Foundation

/// 논리좌표(캔버스)와 화면좌표(뷰포트) 사이의 변환. 에디터의 모든 좌표 계산이
/// 딛고 서는 바닥이다 (v4 §1.2 · §5.9 · §5.10).
///
/// **저장하는 것은 배율·뷰포트에 독립인 둘뿐이다.**
///
/// | 저장 | 파생 |
/// |---|---|
/// | `zoom` — fit 대비 배수 | `fitScale`, `scale` |
/// | `center` — 뷰포트 중앙에 오는 논리 지점 | 화면 오프셋 |
///
/// 절대 배율이나 화면 오프셋을 저장하면 뷰포트가 바뀔 때마다 보정이 필요하고,
/// 그 보정을 한 곳에서라도 빠뜨리면 화면이 튄다. 독립인 것만 들고 있으면
/// **기기 회전에 아무 코드도 필요 없다** — `fitScale`이 새 뷰포트로 다시 계산될 뿐이다.
public struct CanvasSurface: Equatable, Sendable {

    /// 논리 크기. 폭 1080 고정, 높이 1350(4:5) 또는 1920(9:16).
    public let canvas: Size2
    /// 화면 크기(pt).
    public let viewport: Size2

    /// fit 대비 배수. **100%는 절대 배율이 아니라 "캔버스가 화면에 꼭 맞는 상태"** 다
    /// (v4 §1.2: "가로에서 100%였던 것이 세로에서는 100%가 아니다").
    public private(set) var zoom: Double
    /// 뷰포트 중앙에 오는 논리 지점. 팬 상태를 화면 오프셋이 아니라 이것으로
    /// 들고 있어서, 줌·회전이 보던 지점을 밀지 않는다.
    public private(set) var center: Vec2

    /// 줌 범위 50%~400% (v4 §5.9). **fit 아래로 내려가는 것은 의도된 동작이다** —
    /// 캔버스 밖으로 밀어낸 레이어를 보고 다시 잡기 위해서다(§5.10).
    public static let zoomLimits = (min: 0.5, max: 4.0)

    public init(canvas: Size2, viewport: Size2) {
        self.canvas = canvas
        self.viewport = viewport
        self.zoom = 1
        self.center = Vec2(x: canvas.width / 2, y: canvas.height / 2)
    }

    // MARK: - 파생

    /// 캔버스 전체가 뷰포트에 들어가는 최대 배율.
    ///
    /// **식 하나가 세로·가로를 다 설명한다.** v4 §1.2 표의 "세로는 폭에 맞춰,
    /// 가로는 높이에 맞춰"는 두 규칙이 아니라 이 `min`의 결과다. 방향으로
    /// 분기하면 정사각형에 가까운 뷰포트에서 어긋난다.
    /// **뷰포트나 캔버스가 유효하지 않으면 0을 낸다.**
    ///
    /// SwiftUI `GeometryReader`는 **첫 레이아웃 패스에서 `.zero`를 준다** — 실제로
    /// 지나가는 경로다. 나누기를 그대로 두면 `scale`이 0이 되고 `toLogical`이
    /// `inf`/`NaN`을 뱉는데, **`NaN`은 클램프를 그냥 통과한다**(Swift `min`/`max`는
    /// `y >= x ? y : x` 형태라 `NaN` 비교가 전부 거짓이다). 그러면 `center`가
    /// `NaN`으로 굳어 정상 뷰포트가 와도 복구되지 않는다.
    public var fitScale: Double {
        guard canvas.width > 0, canvas.height > 0,
              viewport.width > 0, viewport.height > 0,
              canvas.width.isFinite, canvas.height.isFinite,
              viewport.width.isFinite, viewport.height.isFinite else { return 0 }
        return min(viewport.width / canvas.width, viewport.height / canvas.height)
    }

    /// 논리 1단위가 화면 몇 pt인가.
    public var scale: Double { fitScale * zoom }

    public var canvasCenter: Vec2 {
        Vec2(x: canvas.width / 2, y: canvas.height / 2)
    }

    /// 팬이 갈 수 있는 한계이자 **레이어 중심이 나갈 수 없는 한계**(v4 §5.10).
    /// 캔버스의 2배 범위다.
    ///
    /// `EDITOR-9`(레이어 경계)가 이 사각형을 다시 정의하지 않도록 공개한다.
    /// 두 벌로 갈라지면 한쪽만 바뀌었을 때 "팬으로 못 닿는 곳에 레이어가 놓이거나,
    /// 레이어가 못 가는 곳까지 팬되는" 어긋남이 조용히 생긴다.
    ///
    /// `EDITOR-9`가 실제로 그렇게 했다 — `clampedLayerCenter(_:)`가 이 사각형을
    /// 재계산하지 않고 `clampedToWorkArea(_:)`를 그대로 부른다. **읽기 전용
    /// 기하 사실이라 `public`을 유지한다**(`EDITOR-11`이 작업 영역 경계를 그릴 때
    /// 필요하다). 좁힌 것은 가드가 없는 변환 함수 하나뿐이다.
    public var workArea: (min: Vec2, max: Vec2) {
        let c = canvasCenter
        return (Vec2(x: c.x - canvas.width, y: c.y - canvas.height),
                Vec2(x: c.x + canvas.width, y: c.y + canvas.height))
    }

    /// 작업 영역 안으로 자른다. **기준은 언제나 캔버스 중심이다** — 현재 `center`를
    /// 기준으로 삼으면 팬할 때마다 기준이 따라가 무한히 벗어난다.
    ///
    /// ⚠️ **레이어 중심에는 이것을 쓰지 마라. `clampedLayerCenter(_:)`를 거쳐라.**
    /// 이 함수에는 비유한 방어가 없어서 두 비유한 종류가 **서로 다르게** 처리된다
    /// (실측): `min(max(∞, −540), 1620)`은 **`1620`** — 그럴듯한 좌표라 아무도
    /// 눈치채지 못하고, `min(max(NaN, …), …)`은 **`NaN` 그대로 통과**한다. `NaN`이
    /// 레이어 `center`에 앉으면 `JSONEncoder`가 던져 **문서 저장 자체가 실패한다**
    /// (`EDITOR-8`이 `rotation` 축에서 실제로 발견해 제거한 실패와 같은 형태).
    ///
    /// **`internal`인 이유가 이것이다** (`EDITOR-9`에서 `public`을 뗐다). 두 클램프는
    /// 같은 타입에 같은 시그니처(`Vec2 → Vec2`)를 갖고 이름도 인접해 자동완성에
    /// 나란히 뜬다. 공개 표면에 둘 다 있으면 배선이 잘못 고를 수 있는데, 그때
    /// **`EDITOR-9`의 테스트 22건은 전부 초록이다** — 그 테스트들은 함수를 직접
    /// 부르는 단위 테스트라 호출부가 무엇을 고르는지 보지 못한다. 그래서 주석이
    /// 아니라 컴파일러가 막게 했다 (`ResizeAnchor`가 `shortSideFloor`/`minShortSide`
    /// 이름을 갈라 막은 것과 같은 대응).
    ///
    /// 패키지 안에서는 `centered(on:)`(팬)과 `clampedLayerCenter(_:)`(레이어 중심)
    /// 둘만 부른다. 팬 경로는 `centered(on:)`이 진입부에서 `isFinite`를 이미
    /// 거르므로 방어 부재에 닿지 않는다.
    func clampedToWorkArea(_ p: Vec2) -> Vec2 {
        let area = workArea
        return Vec2(x: min(max(p.x, area.min.x), area.max.x),
                    y: min(max(p.y, area.min.y), area.max.y))
    }

    // MARK: - 변환

    public func toScreen(_ p: Vec2) -> Vec2 {
        Vec2(x: (p.x - center.x) * scale + viewport.width / 2,
             y: (p.y - center.y) * scale + viewport.height / 2)
    }

    public func toLogical(_ p: Vec2) -> Vec2 {
        // 배율이 0이면 화면의 어느 점도 논리 지점으로 되돌릴 수 없다.
        // `NaN`을 흘리는 대신 **유일하게 방어 가능한 답인 `center`** 를 낸다.
        let s = scale
        guard s > 0 else { return center }
        return Vec2(x: (p.x - viewport.width / 2) / s + center.x,
                    y: (p.y - viewport.height / 2) / s + center.y)
    }

    // MARK: - 변경

    /// 줌을 바꾼다. 범위 밖은 잘라낸다.
    ///
    /// `center`를 건드리지 않으므로 **확대해도 보던 지점이 안 밀린다.**
    /// (핀치 중심을 기준으로 확대하는 것은 제스처 배선의 몫이다 — `EDITOR-10`.)
    public func zoomed(to value: Double) -> CanvasSurface {
        // `NaN`은 클램프를 통과한다 — 막지 않으면 `scale`이 통째로 죽는다.
        guard value.isFinite else { return self }
        var copy = self
        copy.zoom = min(max(value, Self.zoomLimits.min), Self.zoomLimits.max)
        return copy
    }

    /// 화면 중앙에 올 논리 지점을 지정한다(팬). 작업 영역 밖은 경계로 자른다.
    public func centered(on point: Vec2) -> CanvasSurface {
        guard point.x.isFinite, point.y.isFinite else { return self }
        var copy = self
        copy.center = clampedToWorkArea(point)
        return copy
    }

    /// fit으로 되돌린다(더블탭).
    ///
    /// **`zoom = 1`만으로는 부족하다.** 배율만 되돌리고 `center`를 두면, 작업 영역
    /// 끝까지 팬해 둔 상태에서 캔버스가 화면 밖에 그대로 남는다 — 사용자는
    /// "맞춤으로 복귀"를 눌렀는데 빈 화면을 본다.
    public func fitted() -> CanvasSurface {
        CanvasSurface(canvas: canvas, viewport: viewport)
    }

    /// 뷰포트가 바뀐다(기기 회전).
    ///
    /// **`zoom`도 `center`도 그대로 넘긴다.** 줌은 fit 대비 배수라 새 fit 위에서
    /// 같은 비율을 뜻하고, `center`는 논리 지점이라 보던 곳이 그대로 남는다.
    /// 작업 영역 제한도 논리 단위라 배율이 바뀌어도 경계 판정이 흔들리지 않는다 —
    /// 그래서 여기에 재클램프가 없다.
    public func viewportChanged(to newViewport: Size2) -> CanvasSurface {
        var copy = CanvasSurface(canvas: canvas, viewport: newViewport)
        copy.zoom = zoom
        copy.center = center
        return copy
    }

}

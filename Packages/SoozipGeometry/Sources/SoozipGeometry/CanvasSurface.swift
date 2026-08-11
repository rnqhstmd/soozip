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
    public var fitScale: Double {
        min(viewport.width / canvas.width, viewport.height / canvas.height)
    }

    /// 논리 1단위가 화면 몇 pt인가.
    public var scale: Double { fitScale * zoom }

    public var canvasCenter: Vec2 {
        Vec2(x: canvas.width / 2, y: canvas.height / 2)
    }

    // MARK: - 변환

    public func toScreen(_ p: Vec2) -> Vec2 {
        Vec2(x: (p.x - center.x) * scale + viewport.width / 2,
             y: (p.y - center.y) * scale + viewport.height / 2)
    }

    public func toLogical(_ p: Vec2) -> Vec2 {
        Vec2(x: (p.x - viewport.width / 2) / scale + center.x,
             y: (p.y - viewport.height / 2) / scale + center.y)
    }

    // MARK: - 변경

    /// 줌을 바꾼다. 범위 밖은 잘라낸다.
    ///
    /// `center`를 건드리지 않으므로 **확대해도 보던 지점이 안 밀린다.**
    /// (핀치 중심을 기준으로 확대하는 것은 제스처 배선의 몫이다 — `EDITOR-10`.)
    public func zoomed(to value: Double) -> CanvasSurface {
        var copy = self
        copy.zoom = min(max(value, Self.zoomLimits.min), Self.zoomLimits.max)
        return copy
    }

    /// 화면 중앙에 올 논리 지점을 지정한다(팬). 작업 영역 밖은 경계로 자른다.
    public func centered(on point: Vec2) -> CanvasSurface {
        var copy = self
        copy.center = clampedToWorkArea(point)
        return copy
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

    // MARK: - 내부

    /// 작업 영역은 **캔버스의 2배 범위**다(v4 §5.10). 중심에서 캔버스 크기만큼이
    /// 반경이 된다. 그 밖은 줌 아웃으로도 볼 수 없어 레이어를 영영 잡을 수 없다.
    private func clampedToWorkArea(_ p: Vec2) -> Vec2 {
        let c = canvasCenter
        return Vec2(x: min(max(p.x, c.x - canvas.width), c.x + canvas.width),
                    y: min(max(p.y, c.y - canvas.height), c.y + canvas.height))
    }
}

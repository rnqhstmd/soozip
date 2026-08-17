import Foundation

public enum Handle: Hashable, Sendable {
    case corner(Corner)
    case edge(Edge)
    case rotate
    case delete
}

public struct PlacedHandle: Equatable, Sendable {
    public let handle: Handle
    public let position: Vec2
}

public struct PlacedEdge: Equatable, Sendable {
    public let edge: Edge
    public let position: Vec2
}

/// 레이어 선택 시 그리는 핸들들의 화면 좌표 배치.
///
/// 이 값은 `surface`가 바뀌는 순간 통째로 무효다. 저장하지 말고 매 프레임
/// 다시 만든다 — 제스처 시작 시점의 배치를 잡아 두고 팬 중에 쓰면 손가락은
/// 새 화면 좌표에 있고 핸들은 옛 자리에 있어 히트 판정이 조용히 빗나간다.
public struct HandlePlacement: Equatable, Sendable {
    public struct Box: Equatable, Sendable {
        public let topLeft: Vec2
        public let topRight: Vec2
        public let bottomRight: Vec2
        public let bottomLeft: Vec2
        public let edgeHandles: [PlacedEdge]
        public let rotate: Vec2
        public let rotateFlipped: Bool

        public func corner(_ corner: Corner) -> Vec2 {
            switch corner {
            case .topLeft:     return topLeft
            case .topRight:    return topRight
            case .bottomRight: return bottomRight
            case .bottomLeft:  return bottomLeft
            }
        }

        /// 결정에 따라 좌상단 코너와 **정확히 같은 지점**이다. 판정은 거리를 보지
        /// 않으므로 이 둘은 언제나 함께 히트한다. 승자는 두 단계로 정해진다 —
        /// **제스처가 후보를 거르고**(`HandleGesture.accepts(_:)`), **살아남은 것 중
        /// `orderedHandles`의 순서가 고른다.**
        ///
        /// 그래서 탭이 삭제를 잡는 것은 **순서** 때문이고(`.tap`은 아무것도 거르지
        /// 않는다 — 배열에서 삭제가 좌상단보다 앞일 뿐이다), 드래그가 좌상단을 잡는
        /// 것만이 **제스처** 때문이다. 둘을 뭉뚱그려 "제스처가 정한다"로 읽으면
        /// 배열 순서를 재배열해도 탭 동작은 안 바뀔 것으로 오해하게 된다.
        ///
        /// **저장하지 않고 되짚는다.** `EDITOR-6`이 실제로 그 일을 했다 — 판정값이
        /// `cornerPushThreshold`(56) 미만이면 코너가 화면 축 방향 22pt씩 밀리는데,
        /// 계산 프로퍼티라 삭제가 **자동으로 따라간다.** 두 벌로 뒀다면 삭제만
        /// 제자리에 남아 스펙에 없는 오프셋이 조용히 생겼을 것이다.
        ///
        /// 이 항등식이 유지되는 한 **`EDITOR-5` §1-h가 경고한 경로는 열리지 않는다** —
        /// 드래그가 `.delete`를 걸러도 `.corner(.topLeft)`가 **정확히 같은 좌표**에서
        /// 함께 히트하므로, "후보가 전부 제스처에 거부되어 nil"이 되는 상태는
        /// 여전히 도달 불가다.
        public var delete: Vec2 { topLeft }
    }

    public static let rotateGap: Double = 28
    public static let flipThreshold: Double = 40

    // MARK: - 크기 축 정책 (EDITOR-6 / v4 §5.7)
    //
    // 셋 다 `internal`이다. 바로 위의 `rotateGap`·`flipThreshold`가 `public`인 것은
    // `EDITOR-4`의 잔재이며 **파일 밖 소비자가 0건**이다(테스트조차 리터럴 28·40을
    // 쓰며 피한다). 오늘 쓴다면 그 둘도 `internal`이다. **이 셋을 `public`으로
    // "통일"하지 마라** — 방향이 반대다.

    /// 판정값이 이 값 **미만**이면 변 핸들을 배치에서 뺀다 (FR-1·BR-1).
    ///
    /// 판정값은 `frame.size.shortSide * surface.scale` — **화면 pt**다(결정 1).
    /// 논리 px로 재면 줌아웃해서 핸들이 실제로 겹쳐도 정책이 안 깨어난다.
    ///
    /// **`hitSize`(44)에서 파생하지 않는다**(BR-4). 88 = 2×44는 "히트 사각형 두 개가
    /// 나란히 들어가는 최소 폭"이라는 **유래**일 뿐이다. `hitSize * 2`로 적으면
    /// 터치 타깃을 48로 키우는 순간 겹침 정책이 96으로 조용히 따라 움직여,
    /// 손댄 적 없는 레이어에서 변 핸들이 사라진다.
    ///
    /// **경계는 이전 상태다 — 정확히 88이면 변이 있다.** `flipThreshold`의 `<= 40`과
    /// `HandleHitTest`의 `hitSize` 반쪽 `<= 22`가 "경계 포함" 관례를 세웠으나 v4 §5.7
    /// 원문이 `< 88pt`를 명시한다. **이 한 군데만 반대**라는 것을 모르면 `<=`로
    /// "통일"하는 변경이 자연스러워 보인다.
    ///
    /// **`internal`이다 — `hitSize`와 같은 이유다.** `public`으로 열면 호출부가
    /// `size.shortSide * scale < 88`을 재기술하는 가장 짧은 경로가 생기고, 그것이
    /// 정확히 "유일한 반영 지점"이 막으려는 것이다. 그릴 것과 잡을 것은 전부
    /// `orderedHandles`·`hitCandidates`에서 나온다.
    static let edgeHideThreshold: Double = 88

    /// 판정값이 이 값 **미만**이면 코너를 박스 바깥으로 민다 (FR-2·BR-1).
    /// 정확히 56이면 밀지 않는다 — v4 §5.7 원문이 `<`다.
    ///
    /// **`edgeHideThreshold`보다 작아야 한다.** 뒤집으면 "코너는 밀렸는데 변은
    /// 남아 있는" 구간이 생겨 밀린 코너와 제자리 변이 오히려 더 붙는다 —
    /// 정책이 목적의 반대로 동작한다. **타입은 이 순서를 강제하지 않는다.**
    static let cornerPushThreshold: Double = 56

    /// 코너를 미는 화면 거리(pt). 축마다 독립으로 더한다 (FR-2 · 결정 3).
    ///
    /// **`hitSize / 2`가 아니다.** 값이 22로 같은 것은 우연이 아니지만(반쪽만큼
    /// 벌리면 마주보는 코너의 히트 사각형이 정확히 맞닿는다) 결합을 만들지
    /// 않는다(BR-4). `hitSize` doc의 "반쪽을 별도 상수로 두지 않는다"는
    /// **히트 판정 축**의 이야기이고, 이것은 **배치 축**의 다른 22다.
    static let cornerPush: Double = 22

    /// `Edge.allCases`에 기대지 않는다. 시계방향인 것이 이 불변식을 검증
    /// 가능하게 만든다 — 선언 순서(`left, right, top, bottom`)대로 적으면
    /// `allCases`와 완전히 같아져, "`allCases`를 대신 쓴다"는 변이가 어떤
    /// 테스트로도 죽지 않는다.
    public static let edgeOrder: [Edge] = [.top, .right, .bottom, .left]

    public let box: Box?

    public static let empty = HandlePlacement(box: nil)

    private init(box: Box?) {
        self.box = box
    }

    public init(frame: LayerFrame, edges: Set<Edge>, on surface: CanvasSurface) {
        guard frame.center.x.isFinite, frame.center.y.isFinite,
              frame.size.width.isFinite, frame.size.height.isFinite,
              frame.rotation.isFinite else {
            self.box = nil
            return
        }

        // 겹침 방지 판정값 = **화면에서 잰 짧은 변**(pt) — 결정 1·2 · FR-7.
        //
        // `Size2.shortSide`를 그대로 쓴다. "짧은 변"을 여기서 다시 정의하면 두 벌이
        // 되고, 이 저장소는 그 실패를 네 번 겪었다.
        //
        // **회전을 반영하지 않는다.** 화면 축 정렬 바운딩 박스로 재면 로컬 100×300을
        // 45° 돌렸을 때 짧은 변이 100에서 282.8로 뛰어(× 0.5 = 141.4), 사용자가 크기를
        // 건드리지 않았는데 **회전만으로 정책이 꺼진다.**
        //
        // **`surface.scale`을 곱한다.** 정책의 단위를 `hitSize`(44pt)와 같은 화면 pt로
        // 맞추는 것이 88 = 2×44의 전제다. 논리 px로 재면 줌아웃해서 핸들이 실제로
        // 겹쳐도 발동하지 않는다.
        //
        // **`scale`이 유한하다는 보장은 없다** — `CanvasSurface.fitScale`은 canvas·
        // viewport가 각각 양수·유한인지만 보고 **나눗셈 결과의 오버플로우는 막지
        // 않는다.** canvas.width에 비정규수(5e-324, 양수이며 `isFinite`)를 주고
        // viewport가 크면 `fitScale`이 `Infinity`가 되고, 그때 `shortSide == 0`이면
        // 판정값이 `0 × ∞ = NaN`이 된다.
        //
        // `NaN` 판정값은 두 비교(`>=`·`<`)가 전부 거짓이라 **변은 숨고 코너는 안
        // 밀리는** 상태로 간다. 좌표 자체는 이미 같은 경로에서 `toScreen`이 `NaN`을
        // 낸 뒤이므로 **이 정책이 새 실패 모드를 만들지는 않지만, 막지도 않는다.**
        // 이 구멍은 `EDITOR-4`의 가드 설계부터 있던 것이고 여기서 좁히지 않는다 —
        // 좁히려면 `fitScale` 쪽이거나 `init`에 `scale` 유한성 가드가 필요하며,
        // 둘 다 이 단위의 AC 밖이다.
        let screenShortSide = frame.size.shortSide * surface.scale
        let showsEdges = screenShortSide >= Self.edgeHideThreshold

        // 밀기 기준점. **발동 여부와 기준점을 한 값으로 묶는다** — 호출부가
        // "밀기는 켰는데 중심을 안 넘긴" 상태를 만들 수 없고, 네 코너가 같은
        // 기준을 쓰는 것이 마주보는 쌍의 대칭성이 성립하는 전제다.
        let pushCenter = screenShortSide < Self.cornerPushThreshold
                       ? surface.toScreen(frame.center) : nil

        let topLeft     = Self.screenCorner(.topLeft,     of: frame, on: surface, pushedFrom: pushCenter)
        let topRight    = Self.screenCorner(.topRight,    of: frame, on: surface, pushedFrom: pushCenter)
        let bottomRight = Self.screenCorner(.bottomRight, of: frame, on: surface, pushedFrom: pushCenter)
        let bottomLeft  = Self.screenCorner(.bottomLeft,  of: frame, on: surface, pushedFrom: pushCenter)

        // **크기 축이 종류 축보다 앞에서, 통째로 자른다** (FR-1 · FR-8).
        // `filter { showsEdges && edges.contains($0) }`로 적으면 결과는 같지만 크기 축이
        // 변마다 따로 판정되는 것처럼 읽혀, "짧은 축의 변만 숨긴다" 같은 스펙에 없는
        // 변형이 다음 사람에게 자연스러워 보인다. **전부 아니면 전무다.**
        let edgeHandles = showsEdges
            ? Self.edgeOrder.filter(edges.contains).map {
                  PlacedEdge(edge: $0, position: surface.toScreen(frame.edgeMidpoint($0)))
              }
            : []

        // **밀린 코너를 쓰지 않는다** (FR-6). topLeft/topRight의 중점을 넣으면
        // 코너가 밀리는 순간 회전 핸들이 22pt 더 위로 딸려 올라간다
        // (AC-9: (270,247)이 (270,225)가 된다). v4 §5.7 원문은 코너만 명시한다.
        // 로컬 −y를 toWorld와 같은 행렬로 회전한 단위 벡터. 정규화로 구하지
        // 않는다 — 높이 0에서 0으로 나누게 된다.
        let up = Vec2(x: sin(frame.rotation), y: -cos(frame.rotation))

        let topScreen = surface.toScreen(frame.edgeMidpoint(.top))

        // 기준선은 뷰포트 상단이다. v4 §5.7의 문면은 '캔버스 상단'이지만 그
        // 목적은 '위에 그리면 화면 밖이거나 툴바에 가린다'이고, 줌+팬에서
        // 둘이 갈라진다. (실측: 뷰포트 390×844·post에서 줌 400%·center.y=1200이면
        // 캔버스 상단의 화면 y ≈ −1311이라, 툴바 바로 아래 레이어의 캔버스
        // 기준 판정값이 1331 > 40이 되어 뒤집히지 않고 회전 핸들이 화면 밖에
        // 놓인다.)
        //
        // up이 화면 아래를 향하면(up.y > 0) 뒤집기가 역효과다 — 안 뒤집은
        // 위치가 이미 툴바에서 멀어지는 방향인데 뒤집은 위치는 항상
        // 판정선보다 위가 된다(뒤집기가 막으려던 상황을 뒤집기가 만든다).
        // up은 레이어와 함께 회전하므로 이 역효과는 90°~270°에서 나타난다.
        // 수평(up.y == 0, 정확히 ±90°)은 세로로 무차별하므로 기존 동작을
        // 유지한다 — 뒤집든 안 뒤집든 rotate.y가 같고 핸들이 박스 반대쪽으로
        // 좌우 이동할 뿐이다. (실측: r=π, scale 0.5에서 뒤집으면
        // rotate.y = −38로 화면 밖, 안 뒤집으면 68로 화면 안.)
        let flipped = topScreen.y <= Self.flipThreshold && up.y <= 0

        let rotate: Vec2
        if flipped {
            let bottomScreen = surface.toScreen(frame.edgeMidpoint(.bottom))
            rotate = Vec2(x: bottomScreen.x - Self.rotateGap * up.x,
                          y: bottomScreen.y - Self.rotateGap * up.y)
        } else {
            rotate = Vec2(x: topScreen.x + Self.rotateGap * up.x,
                          y: topScreen.y + Self.rotateGap * up.y)
        }

        self.box = Box(topLeft: topLeft, topRight: topRight,
                       bottomRight: bottomRight, bottomLeft: bottomLeft,
                       edgeHandles: edgeHandles, rotate: rotate,
                       rotateFlipped: flipped)
    }

    /// 코너 하나의 최종 화면 좌표. `pushedFrom`이 `nil`이면 정책 밖이라 변환만 한다.
    ///
    /// **`Corner.sign`을 화면 델타로 쓰지 마라.** 그것은 **로컬** 좌표의 부호이고
    /// (`LayerFrame.swift`), 화면 델타로 직접 쓰면 **회전 범위의 절반에서 안쪽으로
    /// 민다.** 실측(15° 눈금 24개 중 안쪽으로 미는 회전): 정사각 200×200 **13개**
    /// (90°~270° 전 구간) · 세로긴 100×300 **12개**(75°~240°) · 가로긴 300×100
    /// **12개**(120°~285°). `EDITOR-8`이 15° 스냅이라 전부 도달 가능하다.
    ///
    /// 최악은 회전 π · 화면 폭 44pt다 — 밀린 좌상단과 우상단이 **정확히 같은 점**이
    /// 되어, 겹침을 막으려는 정책이 없던 겹침을 만든다(간격 88 → 0).
    ///
    /// **회전 0에서는 두 규칙이 같은 값을 낸다.** 그래서 회전 0 픽스처만 보고
    /// `Corner.sign`으로 되돌리는 변이는 그것들을 전부 통과한다. 죽이는 것은
    /// 회전이 있는 셋뿐이다 — `반회전프레임()`(간격 88 → 0) · 45° 코너 밀기
    /// (x가 +22 대신 −22가 되어 44pt 어긋남) · `인접겹침프레임()`.
    ///
    /// **`dx.sign`(`FloatingPointSign`)을 쓰지 않는다** — `(-0.0).sign == .minus`라
    /// `-0.0`이 들어오면 폴백을 건너뛰고 조용히 한쪽으로 쏠린다. `dx == 0`은
    /// `-0.0`에도 참이다.
    ///
    /// **폴백은 성분별이다.** 전체 벡터가 (0,0)일 때만 폴백하면, 논리 크기 (0,300)
    /// (폭 0)에서 델타의 x만 0이라 폴백이 안 걸려 x 밀기가 0이 되고 **좌상단과
    /// 우상단이 같은 점으로 붕괴한다**. **성분이 0인 축에는 "안쪽"이 없다** —
    /// `|0| → 22`이므로 어느 부호를 골라도 중심에서 멀어진다.
    ///
    /// ⚠️ **이 구제는 회전이 0 또는 π일 때만 성립한다.** 폭 0에서 두 상단 코너는
    /// 로컬 x가 `∓0.0`이라 **월드 좌표가 완전히 같고**, 축 정렬 회전에서만 화면
    /// 델타의 x가 정확히 0이 되어 폴백이 갈라준다. 45°에서는 두 코너의 델타가
    /// **양 축 모두 `(+53.0330, −53.0330)`으로 동일**해 부호가 갈리지 않고 둘 다
    /// `(345.0330, 274.9670)`으로 남는다. 실측한 밀기 후 좌상단–우상단 간격:
    /// 0° **44** · 15° **0** · 30° **0** · 45° **0** · 90° **0** · 180° **44**.
    /// 높이 0(300×0)의 좌상단–좌하단도 같다.
    ///
    /// **프로덕션 회귀는 아니다** — 폭 0이면 `EDITOR-6` 이전에도 두 코너가 같은
    /// 점이었고 이 변경은 축 정렬 회전에서만 **개선**했다. 다만 증인 픽스처
    /// `영폭프레임()`·`영높이프레임()`이 둘 다 `rotation: 0`이라 **이 조건이
    /// 어디에도 고정돼 있지 않다.** 회전 구간까지 넓히는 것은 `EDITOR-10`의 몫이다.
    ///
    /// **비유한 `dx`는 여기서 막지 않는다.** `NaN`이면 `== 0`도 `< 0`도 거짓이라
    /// 폴백이 아니라 `+1` 가지를 타는데, `dx`가 `NaN`이 되는 유일한 경로는
    /// `toScreen`이 이미 비유한을 낸 경우라 **결과가 어차피 비유한이다** — 새 실패
    /// 모드가 아니다. 이 검토를 다음 사람이 처음부터 다시 하지 않도록 적어 둔다.
    private static func screenCorner(_ corner: Corner, of frame: LayerFrame,
                                     on surface: CanvasSurface,
                                     pushedFrom screenCenter: Vec2?) -> Vec2 {
        let p = surface.toScreen(frame.corner(corner))
        guard let c = screenCenter else { return p }
        let dx = p.x - c.x, dy = p.y - c.y
        let sx = dx == 0 ? corner.sign.x : (dx < 0 ? -1.0 : 1.0)
        let sy = dy == 0 ? corner.sign.y : (dy < 0 ? -1.0 : 1.0)
        return Vec2(x: p.x + sx * cornerPush, y: p.y + sy * cornerPush)
    }

    /// **히트 판정과 그리기의 우선순위 순서다.** 딕셔너리로는 표현할 수 없다 —
    /// `Dictionary` 순회 순서는 실행마다 다르고, `.delete`와 `.corner(.topLeft)`는
    /// **정확히 같은 좌표**라 그 비결정성이 곧바로 관측된다.
    ///
    /// 순서: `.delete` → 코너 4(TL·TR·BR·BL) → `.rotate` → 변(`edgeOrder`).
    /// `.delete`가 맨 앞인 것은 오버레이가 ✕를 좌상단 코너 **위에** 그리기 때문이다.
    ///
    /// **그리기는 이 배열을 역순으로 칠한다** — 정순으로 칠하면 먼저 칠한 ✕가
    /// 좌상단 코너 핸들 밑에 깔려 삭제 버튼이 조용히 사라진다. 겹친 좌표라
    /// 화면에서는 "✕가 원래 없는 것"처럼 보인다.
    ///
    /// **이 순서는 "유일한 규칙"이 아니라 폴백이다.** 겹침은 두 단계로 풀린다:
    ///
    /// 1. **제스처가 후보를 거른다** — 탭은 아무것도 거르지 않고, 드래그는 삭제를
    ///    뺀다(`hitHandle(at:for:)`). 삭제와 좌상단 코너의 동일 좌표 충돌이 **실제로
    ///    갈리는 것은 드래그 쪽뿐**이다 — 탭에서 삭제가 이기는 것은 아래 2번의 순서
    ///    덕이다. 이 거르기를 지우면 좌상단 코너는 영영 리사이즈할 수 없다.
    /// 2. **제스처로도 안 갈리면 이 순서가 정한다 — 「동점」이 아니라 「겹침 전부」다**
    ///    (BR-4). 히트 사각형이 44pt라 초소형 레이어에서는 네 코너가 서로의 사각형
    ///    안에 든다. 그때 손가락이 우하단 코너 **정중앙**에 있어도 드래그는 좌상단
    ///    코너를 잡는다 — **최근접이 아니라 순서가 이긴다.** 근접 우선이 필요해지면
    ///    그것은 이 배열의 문제가 아니라 `EDITOR-6`·`EDITOR-10`의 새 AC다.
    ///
    /// **이 주석의 부재가 실제로 비용을 냈다.** `EDITOR-5` PRD 초안이 코드만 읽고
    /// 1단계를 못 봐서 "좌상단 코너는 리사이즈 불가"를 수용한 채 나왔다.
    public var orderedHandles: [PlacedHandle] {
        guard let box else { return [] }
        var result: [PlacedHandle] = [
            PlacedHandle(handle: .delete, position: box.delete),
            PlacedHandle(handle: .corner(.topLeft), position: box.topLeft),
            PlacedHandle(handle: .corner(.topRight), position: box.topRight),
            PlacedHandle(handle: .corner(.bottomRight), position: box.bottomRight),
            PlacedHandle(handle: .corner(.bottomLeft), position: box.bottomLeft),
            PlacedHandle(handle: .rotate, position: box.rotate),
        ]
        result += box.edgeHandles.map { PlacedHandle(handle: .edge($0.edge), position: $0.position) }
        return result
    }

    /// 실제로 제공된 변. **`edgeHandles`에서 파생한다 — 두 벌을 만들지 않는다.**
    ///
    /// **2026-08-15 기준 프로덕션 소비자 0건이다.** 그래도 남기는 이유는 둘이다.
    ///
    /// 1. **집합 축의 표현이다.** 좌표·순서를 벗겨낸 `Set<Edge>`라 "종류가 무엇을
    ///    허용했나"만 잰다. 같은 것을 `orderedHandles` 시퀀스 리터럴이나
    ///    `box.edgeHandles`로도 잴 수 있으므로 **유일한 관측면은 아니다** —
    ///    `text`(좌우 2변)에서만 가장 짧은 표현이다.
    /// 2. **`EDITOR-6` 이후 이 값은 두 축을 모두 통과한 최종 집합이다** — 종류 축
    ///    (`LayerKind.resizableEdges`)과 크기 축(`edgeHideThreshold` 88pt)이 여기서
    ///    합류한다. 그래서 **비어 있다는 사실만으로는 어느 축이 잘랐는지 알 수 없다.**
    ///
    ///    ⚠️ `EDITOR-5`가 이 자리에 "`EDITOR-6` 이후 `SelectionTests.swift:223`·`:232`의
    ///    리터럴 단언이 깨져야 정상"이라고 적어 뒀는데 **틀린 예측이었다.** 그 픽스처는
    ///    `canvas == viewport`라 fitScale 1.0이고 크기가 100×100이라 판정값이 **100** —
    ///    두 임계값 위다. 정책을 넣은 뒤에도 두 단언은 한 글자도 안 바뀌었다. 실제로
    ///    깨진 것은 `SoozipGeometry` 쪽(fitScale 0.5에서 200×100 → 판정값 50)과
    ///    `SelectionTests`의 `baseSizeOf` 도장 스텁(60×40 → 판정값 40)이었다.
    ///
    ///    **`placement.edges == kind.resizableEdges` 형태로 고치지 말 것** — 같은
    ///    접근자로 양변을 만드는 동어반복이라 늘 초록이 되고, `SelectionTests.swift:185`가
    ///    그 형태를 거부한 이유를 적어 뒀다. **이제는 그것이 두 축을 하나로 뭉개기까지
    ///    한다** — 크기 축이 잘라도 양변이 함께 비어 통과한다.
    ///
    /// 히트 판정은 이것을 쓰지 않는다. 변 핸들은 좌표까지 필요하고 그건
    /// `orderedHandles`에 이미 있다.
    public var edges: Set<Edge> {
        guard let box else { return [] }
        return Set(box.edgeHandles.map { $0.edge })
    }
}

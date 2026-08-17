import Foundation

extension LayerFrame {

    // MARK: - 리사이즈 한계 (v4 §5.7 · FR-2)

    /// 짧은 변 하한(논리 px). **캔버스와 무관하다** — 4:5든 9:16이든 40이다.
    /// 이유가 캔버스가 아니라 **손가락**이기 때문이다. 하한이 없으면 레이어가 점이 되어
    /// 다시 잡을 수 없고(v4 §5.7), 그 기준은 핸들 히트 사각형(44pt)이지 캔버스 치수가 아니다.
    ///
    /// **이름이 `resizeLimits`의 튜플 라벨(`minShortSide`)과 일부러 다르다.**
    /// `clamped`·`resized(…)`가 `minShortSide`라는 **매개변수**를 갖는데, `clamped`는
    /// `private static func`라 같은 타입의 정적 멤버를 한정자 없이 조회한다. 이름이 같으면
    /// **매개변수를 통째로 지우고 이 상수에 조용히 결합하는 변이가 컴파일된다**
    /// (`swiftc`로 확인: 결과가 정상과 동일). 기존·신규 테스트가 예외 없이 하한에 40만
    /// 넘기므로 그 변이를 죽일 테스트가 없다. **이름을 갈라 컴파일 단계에서 막는다.**
    /// (인스턴스 메서드인 `resized(draggingCorner:)`는 `static member cannot be used on
    /// instance` 오류라 원래 안전하다 — 위험은 `clamped` 쪽뿐이다.)
    ///
    /// **`private`이다.** 열면 호출부가 40을 직접 읽어 `resizeLimits(canvas:)`를 우회하는
    /// 가장 짧은 경로가 생긴다 — `HandlePlacement.edgeHideThreshold`가 같은 이유로 `internal`이다.
    private static let shortSideFloor: Double = 40

    /// 긴 변 상한의 캔버스 배수. **`private`인 이유는 위와 같다** — 열면
    /// `canvas.longSide * multiple`이라는 재기술 경로가 열린다.
    private static let canvasLongSideMultiple: Double = 4

    /// 리사이즈 클램프에 넘길 한계 한 쌍. **캔버스 크기가 유일한 입력이다.**
    ///
    /// `CanvasAspect`를 받지 않는다 — 그 타입은 `SoozipLayout`에 있고 이 패키지는 볼 수 없다
    /// (단방향 의존). `Size2`를 받으면 `CanvasAspect.size` · `LayoutDocument.canvas` ·
    /// `CanvasSurface.canvas` 셋 다 그대로 넘어간다.
    ///
    /// **`CanvasSurface`의 파생 프로퍼티가 아니다.** 한계는 뷰포트·줌과 무관한데
    /// `surface.resizeLimits`로 두면 "줌하면 한계가 변한다"는 오해가 자연스러워지고, 언젠가
    /// `scale`을 곱하는 변경이 합리적으로 보인다. 그 순간 하한의 단위가 논리 px에서 화면 pt로
    /// 조용히 바뀐다 — `edgeHideThreshold`(화면 pt)와 이것(논리 px)의 단위가 다른 것이 핵심이다.
    ///
    /// **둘을 한 값으로 낸다.** 하한만 따로 얻는 경로를 두면 상한은 캔버스에서, 하한은
    /// 리터럴에서 오는 호출부가 생긴다. `CanvasSurface.zoomLimits`가 같은 이유로 튜플이다.
    ///
    /// ⚠️ **타입이 이 값의 사용을 강제하지 않는다.** `resized(…)`는 여전히 `Double` 둘을 받아
    /// 호출부가 리터럴을 넘길 수 있다. 구조적으로 닫으려면 생성자가 `init(canvas:)` 하나뿐인
    /// `ResizeLimits` 타입으로 시그니처를 바꿔야 한다. **PRD는 그 형태를 설계에 위임했고 AC와
    /// 충돌하지 않는다** — 이 단위가 팩토리를 고른 것은 **비용 판단**이다(public 시그니처 2개 +
    /// 호출부 9곳 + 호출부가 0건이라 차단 형태를 검증할 수 없음).
    /// **`EDITOR-11`은 이 결정을 제약 없이 재검토할 것 — AC가 막은 것이 아니다.**
    public static func resizeLimits(canvas: Size2) -> (minShortSide: Double, maxLongSide: Double) {
        (minShortSide: shortSideFloor,
         maxLongSide: canvas.longSide * canvasLongSideMultiple)
    }

    /// 코너 핸들 드래그 — 비율을 유지하고 대각 반대편 코너를 고정한다.
    public func resized(draggingCorner corner: Corner,
                        to worldPoint: Vec2,
                        minShortSide: Double,
                        maxLongSide: Double) -> LayerFrame {

        let anchorCorner = corner.opposite
        let anchorWorld = self.corner(anchorCorner)

        // 로컬 좌표에서 계산한다. 회전을 여기서 제거해야 대각 고정이 성립한다.
        let dragLocal = toLocal(worldPoint)
        let anchorLocal = Vec2(x: anchorCorner.sign.x * size.width  / 2,
                               y: anchorCorner.sign.y * size.height / 2)

        let rawW = abs(dragLocal.x - anchorLocal.x)
        let rawH = abs(dragLocal.y - anchorLocal.y)

        // 비율 유지: 원본 종횡비에 맞춰 더 큰 쪽을 기준으로 삼는다
        let ratio = size.width / size.height
        var newW = max(rawW, rawH * ratio)
        var newH = newW / ratio

        (newW, newH) = Self.clamped(width: newW, height: newH,
                                    minShortSide: minShortSide,
                                    maxLongSide: maxLongSide)

        // 고정점에서 드래그 방향으로 새 중심을 잡는다
        let newCenterLocal = Vec2(x: anchorLocal.x + corner.sign.x * newW / 2,
                                  y: anchorLocal.y + corner.sign.y * newH / 2)

        var result = LayerFrame(center: toWorld(newCenterLocal),
                                size: Size2(width: newW, height: newH),
                                rotation: rotation)

        // **대수적으로 항등이며, 그 이상이다.**
        //   center_final = nc + (anchorWorld − moved)
        //                = nc + anchorWorld − (nc + R(anchorSign × new/2))
        //                = anchorWorld − R(anchorSign × new/2)
        // **`nc`가 완전히 소거된다.** `toWorld`가 아핀이고 `R`이 선형이며
        // `Corner.opposite.sign == −Corner.sign`(네 케이스 전수)이기 때문이다.
        // 즉 위 `newCenterLocal` 계산을 **어떻게 하든 결과가 같다** —
        // `corner.sign`을 드래그 방향 부호로 바꾸는 변이는 실측 차이 `0.0`인
        // **등가 변이**이고, 아래 `+=`를 `-=`로 바꾸는 것도 등가다(보정항이 0이므로).
        // (무작위 300회 실측: 보정항 최대 절대값 1.205e-11 — 반올림뿐이다.)
        //
        // 귀결 1: **"고정점이 유지된다"를 재는 단언이 재는 축은 `corner.opposite`
        // 하나뿐이다.** `toLocal`·`newCenterLocal`·`clamped`의 어떤 변이도 그 절로는
        // 죽지 않는다 — 결과가 유한하기만 하면 통과한다. 실제 관측면은 `size`와
        // 끌린 코너 쪽이다. `ResizeAnchorTests`의 기존 두 건이 그 상태다.
        //
        // 귀결 2: **위 `newCenterLocal` 계산과 이 보정 블록 중 한쪽은 관측 불가능한
        // 죽은 코드다.** 어느 쪽을 지워도 어떤 테스트도 차이를 관측하지 못한다.
        // `EDITOR-7`은 정리하지 않았다 — 어느 쪽을 살릴지는 정책 결정이고(읽기 쉬운
        // 쪽? 반올림에 강한 쪽?), 지금 정리하면 **안전망 없는 변경**이 된다.
        let moved = result.corner(anchorCorner)
        result.center.x += anchorWorld.x - moved.x
        result.center.y += anchorWorld.y - moved.y
        return result
    }

    /// 변 핸들 드래그 — 한 축만 바꾸고 반대쪽 변을 고정한다.
    ///
    /// 이 함수는 레이어 종류를 보지 않는다. `photo`에 한 축 리사이즈를 금지한
    /// 정책(v4 §5.7)은 여기서 막을 수 없다 — 이 패키지는 `LayerKind`를 볼 수 없다.
    ///
    /// 타입이 보장하는 것: `LayerStore.selectionHandles(...)`에는 `edges` 매개변수가
    /// 없어, 그 경로로 배치를 얻는 호출부는 변 집합을 바꿀 방법이 없고 `photo`의
    /// 배치에는 변 핸들 원소가 애초에 없다.
    ///
    /// 타입이 보장하지 않는 것: `HandlePlacement.init(frame:edges:on:)`은 `public`이고
    /// 임의 `Set<Edge>`를 받는다. 이 함수도 `public`이라 배치를 건너뛰고 부를 수 있다.
    /// 즉 배치가 낸 값만 쓰는 것은 규율이지 컴파일러가 검사하는 사실이 아니다.
    public func resized(draggingEdge edge: Edge,
                        to worldPoint: Vec2,
                        minShortSide: Double,
                        maxLongSide: Double) -> LayerFrame {

        let dragLocal = toLocal(worldPoint)
        var newW = size.width
        var newH = size.height

        if edge.isHorizontal {
            newW = abs(dragLocal.x) + size.width / 2
        } else {
            newH = abs(dragLocal.y) + size.height / 2
        }

        (newW, newH) = Self.clamped(width: newW, height: newH,
                                    minShortSide: minShortSide,
                                    maxLongSide: maxLongSide)

        // 반대쪽 변을 고정하려면 중심을 늘어난 절반만큼 이동시킨다
        let deltaW = newW - size.width
        let deltaH = newH - size.height
        let shiftLocal: Vec2
        switch edge {
        case .right:  shiftLocal = Vec2(x:  deltaW / 2, y: 0)
        case .left:   shiftLocal = Vec2(x: -deltaW / 2, y: 0)
        case .bottom: shiftLocal = Vec2(x: 0, y:  deltaH / 2)
        case .top:    shiftLocal = Vec2(x: 0, y: -deltaH / 2)
        }

        return LayerFrame(center: toWorld(shiftLocal),
                          size: Size2(width: newW, height: newH),
                          rotation: rotation)
    }

    /// 짧은 변 하한과 긴 변 상한을 **입력 비율을 보존한 채** 적용한다.
    ///
    /// **상한을 먼저, 하한을 나중에 적용한다. 순서가 곧 우선순위다** — 나중에 적용한 쪽이
    /// 이긴다. 반대로 두면 비율이 `상한/하한`(9:16에서 192, 4:5에서 135)을 넘는 가는
    /// 레이어에서 짧은 변이 하한 아래로 샌다: `8000×40`을 제자리로 다시 끌면 상한이
    /// `k = 0.96`을 곱해 **38.4**를 만들고 하한 블록은 이미 지나간 뒤다.
    /// 상한을 넘긴 채 두는 것이 의도된 손해다 — 상한을 넘은 레이어는 여전히 잡히지만,
    /// 하한 아래 레이어는 핸들이 겹쳐 다시 잡을 수 없다.
    ///
    /// **어느 블록이 발동하는지 자체가 순서에 의존한다.** `(20, 5000)`은 옛 순서에서 둘 다
    /// 발동해 `(30.72, 7680)`, 새 순서에서 하한만 발동해 `(40, 10000)`이다. 따라서
    /// "둘 다 발동할 때만 순서가 문제"라는 요약은 틀렸다 — **어느 한 순서에서라도 둘 다
    /// 발동하면 결과가 갈릴 수 있다.** 기존 테스트가 안 깨지는 근거는 "동시 발동이 없다"가
    /// 아니라 **"구·신 양쪽 순서에서 각각 발동 블록이 최대 1개"** 를 확인한 것이다.
    ///
    /// 하한이 발동하면 결과는 **`(비율 × 하한, 하한)`으로 유일하게 결정되고 드래그 거리와
    /// 무관하게 수렴한다** — 두 블록이 전부 비율을 보존하기 때문이다. 비율은 드래그가 만드는
    /// 값이 아니라 원본 프레임이 이미 갖고 있던 값이다. **단 정상 범위에서만 참이다**:
    /// `shortSide < 2.2249e-307`이면 `k = 하한/shortSide`가 `Infinity`로 오버플로우한다
    /// (`(2e-307, 1e-307)` → `(inf, inf)`, **비정규수 없이 정규수만으로 발생**).
    ///
    /// ⚠️ **이 함수는 코너·변 드래그가 공유하는데 양축을 함께 곱한다.** 코너 드래그는 비율
    /// 유지가 계약이라 맞지만, 변 드래그의 계약은 "한 축만 바꾼다"이다. 그래서 변 드래그에서
    /// 클램프가 발동하면 **불변이어야 할 축까지 바뀐다**: `50×100` 프레임의 `.right` 변을
    /// 로컬 x=0까지 끌면 `(25, 100)`이 하한에 걸려 **`(40, 160)`** 이 되어 높이가 100에서
    /// 160으로 늘어난다. 반대쪽 변 고정은 유지되지만(중심이 `deltaW/2`만큼 보정된다)
    /// "한 축만"은 깨진다.
    ///
    /// **`EDITOR-7`은 이 결함을 고치지 않았다 — 그리고 넓히지도 않았다.** 순서 교체는
    /// **발동 집합을 바꾸지 않는다**(어느 순서에서도 "발동 없음"의 조건이
    /// `min ≥ 하한 ∧ max ≤ 상한`으로 같다 — 무작위 20,000회 대조 불일치 0건). 바뀌는 것은
    /// 발동 시 **이탈량**뿐이고 방향은 케이스마다 갈린다: clamp 입력 `(100, 100000)`은 새
    /// 순서가 원본에 더 가깝고(Δ 60000 vs 92320), `(20, 8000)`은 옛 순서가 더 가깝다
    /// (Δ 320 vs 8000). 고치려면 "변 드래그에서 하한·상한이 무엇을 뜻하는가"(변경 축만
    /// 자르는가? 짧은 변 규칙은 어디로 가는가? 불변 축이 이미 하한 아래면?)를 새로 정해야
    /// 하며 그것은 정책 결정이다. **`EDITOR-11` 배선 착수 전에 결정할 것.**
    /// 이 결함의 유일한 증인은 `하한_우선_순서교체는_변드래그_결과와_불변축까지_함께_바꾼다`다.
    private static func clamped(width: Double, height: Double,
                                minShortSide: Double,
                                maxLongSide: Double) -> (Double, Double) {
        var w = width
        var h = height

        // 상한 먼저.
        let longSide = max(w, h)
        if longSide > maxLongSide {
            let k = maxLongSide / longSide
            w *= k
            h *= k
        }

        // 하한 나중 — 하한이 상한을 이긴다.
        // `shortSide > 0`은 0으로 나누는 것을 막는다. **한 축만 정확히 0인 입력**(원본
        // 크기가 `(0, h)`인 변 드래그)은 여기서 여전히 통과한다 — 그 경우 하한이 적용되지
        // 않는다. 코너 드래그에서 그 상태는 정상 범위에서는 도달할 수 없다
        // (`newH = newW / 비율`이라 한쪽이 0이면 다른 쪽도 0이다).
        let shortSide = min(w, h)
        if shortSide < minShortSide, shortSide > 0 {
            let k = minShortSide / shortSide
            w *= k
            h *= k
        }
        return (w, h)
    }
}

import Foundation

/// 어떤 표면(`CanvasSurface`)에 대해 이미 클램프를 지난 레이어 중심 하나를
/// 담는 토큰(`EDITOR-10`).
///
/// **무엇을 증언하는가.** 생성자가 단 하나뿐이고, 그 생성자 안에서만
/// `CanvasSurface.clampedLayerCenter(_:)`를 부른다. 다른 방법으로는
/// `value`를 채울 수 없다 — 그래서 `ClampedLayerCenter` 값이 존재한다는
/// 사실 자체가 "이 값은 클램프를 지났다"는 증언이다. `LayerFrame.placed(at:)`
/// 가 `Vec2`가 아니라 이 타입을 받게 해, 클램프를 거치지 않은 좌표가
/// 프레임 중심에 앉는 경로를 타입으로 막는다.
///
/// ⚠️ **증언의 범위 — 과장 금지.** 이 타입이 증언하는 것은 "인자로 준
/// `표면`에 대해 잘렸다"이지 "이 문서의 작업 영역 안이다"가 아니다.
/// `CanvasSurface.init(canvas:viewport:)`는 `canvas`를 검증하지 않는다 —
/// `canvas`·`viewport` 둘만 그대로 대입하고(`zoom`은 리터럴 1, `center`는
/// `canvas`에서 파생한다) `fitScale`만 따로 가드한다. 그래서
/// `ClampedLayerCenter(p, on: CanvasSurface(canvas: Size2(width: 1e9,
/// height: 1e9), viewport: .zero))`는 `(99999, 99999)`를 그대로 담은
/// 토큰을 낸다 — 위조는 한 줄이고 컴파일러가 막지 않는다.
///
/// ⚠️ **저장하지 마라.** 토큰은 표면 스냅샷에 대한 증언이지 영구
/// 불변식이 아니다. 캔버스 비율이 바뀌면(4:5 ↔ 9:16) 이전 토큰의 값은
/// 새 작업 영역 밖일 수 있다. `HandlePlacement`가 핸들 배치에 대해 남긴
/// 규약과 같다 — 매 프레임 다시 만든다.
public struct ClampedLayerCenter: Equatable, Sendable {
    public let value: Vec2

    public init(_ point: Vec2, on surface: CanvasSurface) {
        value = surface.clampedLayerCenter(point)
    }
}

extension LayerFrame {

    /// 클램프를 지난 토큰으로 중심을 옮긴 새 프레임을 낸다.
    ///
    /// **인자로는 `size`·`rotation`에 닿을 수 없지만 `self`로는 닿는다.**
    /// `clampedLayerCenter`의 `Vec2 → Vec2`는 자유 함수라 크기 축이
    /// 문법적으로 없었지만, 이 함수는 `LayerFrame`의 메서드라
    /// `LayerFrame(center: c.value, size: .zero, rotation: 0)`이 그대로
    /// 컴파일된다. 크기·회전 보존은 타입이 아니라 테스트가 막는다 —
    /// `placed는_size와_rotation을_그대로_보존한다`.
    public func placed(at center: ClampedLayerCenter) -> LayerFrame {
        LayerFrame(center: center.value, size: size, rotation: rotation)
    }
}

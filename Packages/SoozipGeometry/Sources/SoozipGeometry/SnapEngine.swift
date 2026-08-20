import Foundation

public enum Axis: Sendable { case horizontal, vertical }

/// 회전이 여기 케이스로 없는 것은 누락이 아니다. 회전 스냅은 `RotationSnap`에 있다.
///
/// 케이스로 합치지 않는 이유 셋:
/// 1. `SnapCandidate`의 소비자는 가이드 **선** 렌더러인데, 회전에는 그을 선이
///    없다(표현은 각도 배지다).
/// 2. `snapCandidates`의 입력 넷(`moving`·`others`·`canvasSize`·`threshold`) 중
///    회전이 쓰는 것이 하나도 없다 — 특히 화면 좌표 임계 `threshold`는 회전과
///    무관하다.
/// 3. 이 enum은 `public`이라 케이스 추가가 소비자의 exhaustive switch를 깨는
///    소스 호환성 변경이다.
public enum SnapKind: Sendable { case alignment, equalSpacing, sizeMatch }

public struct SnapCandidate: Equatable, Sendable {
    public let axis: Axis
    public let value: Double
    public let kind: SnapKind

    public init(axis: Axis, value: Double, kind: SnapKind) {
        self.axis = axis
        self.value = value
        self.kind = kind
    }
}

/// 회전값이 0인 레이어의 축 정렬 바운딩 박스.
private struct AABB {
    let minX, midX, maxX: Double
    let minY, midY, maxY: Double
    let width, height: Double

    init(_ f: LayerFrame) {
        minX = f.center.x - f.size.width / 2
        maxX = f.center.x + f.size.width / 2
        midX = f.center.x
        minY = f.center.y - f.size.height / 2
        maxY = f.center.y + f.size.height / 2
        midY = f.center.y
        width = f.size.width
        height = f.size.height
    }
}

/// 정렬·간격 가이드 후보 자격의 허용오차(라디안).
///
/// 단위가 라디안이라 이름에 박았다. 이 저장소에서 단위 혼동은 조용히
/// 파괴적이다.
///
/// **`RotationSnap.snapThresholdDegrees`(3°)와 통합하지 않는다.** 목적이
/// 다르다 — 이쪽은 "정렬·간격 가이드 후보 자격"이고 저쪽은 "회전 핸들의
/// 15° 그리드 흡착"이다. 하나의 임계로 합치면 두 기능이 함께 움직인다.
///
/// ⚠️ 이 값 자체를 고정하는 테스트가 없다. 기존 픽스처가 `π/6`·`0.5`뿐이라
/// `(0.00005, 0.5]` 어디로 바꿔도 전부 통과한다. 이번 단위가 만든 결함은
/// 아니지만 기록해 둔다.
private let axisAlignToleranceRadians: Double = 0.0001

/// FR: 가장 가까운 360° 배수까지의 거리로 판정한다.
///
/// 실측표(허용오차 `0.0001` 라디안 기준):
///
/// | 입력 | 새 방식 | 이전 구현 | 정규화 후 0-근접만 비교(`turn − n` 생략) |
/// |---|---|---|---|
/// | `-0.00005` | 참 | 참 | 거짓(회귀) |
/// | `2π` | 참 | 거짓(고친 버그) | 참 |
/// | `2π − 0.00005` | 참 | 거짓 | 거짓 |
/// | `π/6`(기존 픽스처) | 거짓 | 거짓 | 거짓 |
/// | `0.5`(기존 픽스처) | 거짓 | 거짓 | 거짓 |
///
/// 마지막 열 이름을 "`[0,2π)` 정규화 방식"이라 적지 않는 이유: 현재
/// 구현의 `n`도 이미 `RotationSnap.normalized(radians:)`로 `[0,2π)`
/// 정규화된 값이다. 정규화 여부가 다른 게 아니라, 그 정규화된 값의 양쪽
/// 거리를 `min(n, turn - n)`으로 재는지(현재 구현) 아니면 `n`이 0에
/// 가까운지만 보는지(이 열)가 다르다.
///
/// **`[0, 2π)`로 정규화한 뒤 0 근접 비교로 바꾸면 안 되는 이유**: `-0.00005`가
/// `6.28313…`이 되어 오늘 통과하던 입력이 깨진다.
///
/// **`min`의 두 항이 다 필요한 이유(실측)**: `turn - n` 항을 지우는 변이
/// (= 위 표의 마지막 열과 같은 변이)를 통과하는 입력은 `2π` 하나뿐이다
/// (접기 결과가 정확히 `0.0`이라 `n < tol`이 참이다). `-0.00005`와
/// `2π − 0.00005`는 접기 후 비트 동일(`6.283135307179586`)이라 둘 다
/// `n < tol`이 거짓이 되어 이 변이를 죽인다 — 이 변이의 킬셋은
/// `SnapEngineTests`의 `미세_음수_회전은_축_정렬로_유지된다` ·
/// `미세_음수_회전_레이어가_스냅_후보에_포함된다` ·
/// `한_바퀴에_거의_근접한_회전도_축_정렬이다` 3건이다.
///
/// **`RotationSnap.normalized(radians:)`로 접는 이유**: 한 바퀴 접기 규칙을
/// 저장소에 한 벌만 두기 위해서다(`RotationSnap.folded` 문서 참고). 이전
/// 버전은 이 함수 안에 자체 `truncatingRemainder` 접기를 따로 갖고 있어
/// 그 "한 벌" 약속을 깨고 있었다.
///
/// **BR-5 — 접기는 재사용하되 임계는 통합하지 않는다.** 접기 본체는 이제
/// `normalized(radians:)` 하나로 합쳐졌지만, `axisAlignToleranceRadians`
/// (0.0001 rad)와 `RotationSnap.snapThresholdDegrees`(3°)는 여전히 별개
/// 상수다 — 목적이 다른 이유는 위 상수 문서 참고.
///
/// **`turn` 지역 변수가 남아 있는 이유**: 접기 자체에는 더 이상 쓰이지
/// 않지만(그건 `normalized(radians:)`가 한다), `min(n, turn - n)`으로 "한
/// 바퀴 쪽에서 잰 거리"를 구하는 데 여전히 필요하다.
///
/// **교차 파일 수치 결합(기록 전용)**: `turn`은
/// `RotationSnap.normalized(radians:)`가 내부에서 접는 주기(`private
/// turnRadians`)와 반드시 같은 값이어야 한다. 두 파일에 따로 선언돼 있어
/// 이 일치를 강제하는 것도 기록하는 것도 이 문장 전에는 없었다. 어긋나면
/// `n > turn`인 구간에서 `turn - n`이 음수가 되고 `min`이 그 음수를 골라
/// 모든 회전이 축 정렬로 판정된다 — 컴파일러도 현재 테스트도 잡지 못한다.
///
/// **비유한 입력**: 나머지가 `NaN`이 되고 Swift의 `min`은 `y < x ? y : x`라
/// `NaN` 비교가 전부 거짓이라 `NaN`이 반환되며, `NaN < tol`이 거짓이라
/// 판정이 거짓이다. 이전 구현과 같다 — 회귀 없음.
///
/// **`internal`인 이유**: `public`으로 열면 `RotationSnap` 옆에 임계가 다른
/// 두 번째 공개 판정이 생겨 호출부에서 혼동을 만든다. 같은 파일의 다른
/// 상수들이 `internal`인 이유와 같다.
///
/// **`LayerFrame` 오버로드를 남기지 않은 이유**: 같은 이름 오버로드 둘이
/// 파일 스코프에 있으면 `others.filter(isAxisAligned)` 같은 함수 참조가
/// 문맥 타입으로 해소되어, 한쪽을 지우는 변이가 조용히 컴파일된다. 그래서
/// 호출부를 클로저로 바꿨다.
func isAxisAligned(radians r: Double) -> Bool {
    let turn = 2 * Double.pi
    let n = RotationSnap.normalized(radians: r)
    return min(n, turn - n) < axisAlignToleranceRadians
}

/// 드래그·리사이즈 중 걸리는 스냅 후보를 모두 계산한다.
///
/// - 회전된 레이어는 움직이는 쪽이든 상대 쪽이든 전부 제외한다.
///   회전체의 바운딩 박스는 실제 형태와 어긋나서, 박스를 맞춰도 눈에는 안 맞아 보인다.
///   단, "회전됨"의 정의가 이번에 바뀌었다 — 한 바퀴(또는 여러 바퀴) 돈
///   레이어는 이제 회전되지 않은 것으로 본다. 시각적으로 축에 정렬돼 있는데
///   후보에서 빠지던 버그를 고친 것이다. 부수적으로 한 바퀴에 거의 근접한
///   회전도 새로 후보에 들어온다 — 이것은 상위 AC에 없는 동작 변경이다. 이
///   설명이 그 변경의 기록이고, `SnapEngineTests`의
///   `한_바퀴에_거의_근접한_회전도_축_정렬이다`는 그 변경을 자동으로
///   감시한다.
/// - `threshold`는 **화면 좌표 기준**으로 넘겨받는다. 논리좌표로 계산하면
///   줌 배율에 따라 감각이 달라진다.
public func snapCandidates(for moving: LayerFrame,
                           among others: [LayerFrame],
                           canvasSize: Size2,
                           threshold: Double) -> [SnapCandidate] {

    guard isAxisAligned(radians: moving.rotation) else { return [] }

    let m = AABB(moving)
    let peers = others.filter { isAxisAligned(radians: $0.rotation) }.map(AABB.init)
    var result: [SnapCandidate] = []

    // ── 1. 정렬: 캔버스 중심선
    let canvasMidX = canvasSize.width / 2
    let canvasMidY = canvasSize.height / 2
    if abs(m.midX - canvasMidX) <= threshold {
        result.append(.init(axis: .vertical, value: canvasMidX, kind: .alignment))
    }
    if abs(m.midY - canvasMidY) <= threshold {
        result.append(.init(axis: .horizontal, value: canvasMidY, kind: .alignment))
    }

    // ── 2. 정렬: 다른 레이어의 6개 기준선
    for p in peers {
        for value in [p.minX, p.midX, p.maxX] {
            for mine in [m.minX, m.midX, m.maxX] where abs(mine - value) <= threshold {
                result.append(.init(axis: .vertical, value: value, kind: .alignment))
            }
        }
        for value in [p.minY, p.midY, p.maxY] {
            for mine in [m.minY, m.midY, m.maxY] where abs(mine - value) <= threshold {
                result.append(.init(axis: .horizontal, value: value, kind: .alignment))
            }
        }
    }

    // ── 3. 균등 간격: 같은 축에 자기 포함 3개 이상일 때만
    if peers.count >= 2 {
        let sortedX = peers.map(\.midX).sorted()
        for i in 0..<(sortedX.count - 1) {
            let gap = sortedX[i + 1] - sortedX[i]
            guard gap > 0 else { continue }
            for target in [sortedX[i] - gap, sortedX[i + 1] + gap]
            where abs(m.midX - target) <= threshold {
                result.append(.init(axis: .vertical, value: target, kind: .equalSpacing))
            }
        }
        let sortedY = peers.map(\.midY).sorted()
        for i in 0..<(sortedY.count - 1) {
            let gap = sortedY[i + 1] - sortedY[i]
            guard gap > 0 else { continue }
            for target in [sortedY[i] - gap, sortedY[i + 1] + gap]
            where abs(m.midY - target) <= threshold {
                result.append(.init(axis: .horizontal, value: target, kind: .equalSpacing))
            }
        }
    }

    // ── 4. 크기 일치
    for p in peers {
        if abs(m.width - p.width) <= threshold {
            result.append(.init(axis: .vertical, value: p.width, kind: .sizeMatch))
        }
        if abs(m.height - p.height) <= threshold {
            result.append(.init(axis: .horizontal, value: p.height, kind: .sizeMatch))
        }
    }

    return result
}

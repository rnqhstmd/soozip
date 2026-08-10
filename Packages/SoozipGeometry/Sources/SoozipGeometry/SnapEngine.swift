import Foundation

public enum Axis: Sendable { case horizontal, vertical }

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

private func isAxisAligned(_ f: LayerFrame) -> Bool {
    abs(f.rotation) < 0.0001
}

/// 드래그·리사이즈 중 걸리는 스냅 후보를 모두 계산한다.
///
/// - 회전된 레이어는 움직이는 쪽이든 상대 쪽이든 전부 제외한다.
///   회전체의 바운딩 박스는 실제 형태와 어긋나서, 박스를 맞춰도 눈에는 안 맞아 보인다.
/// - `threshold`는 **화면 좌표 기준**으로 넘겨받는다. 논리좌표로 계산하면
///   줌 배율에 따라 감각이 달라진다.
public func snapCandidates(for moving: LayerFrame,
                           among others: [LayerFrame],
                           canvasSize: Size2,
                           threshold: Double) -> [SnapCandidate] {

    guard isAxisAligned(moving) else { return [] }

    let m = AABB(moving)
    let peers = others.filter(isAxisAligned).map(AABB.init)
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

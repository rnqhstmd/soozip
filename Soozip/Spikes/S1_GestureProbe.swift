import SwiftUI
import SoozipGeometry

/// S1 스파이크 전용. Phase 3에서 정식 구현으로 대체하고 이 파일은 삭제한다.
///
/// 목적은 "예쁘게 만들기"가 아니라 **레이어 43개에서 60fps가 나오는지**만 보는 것이다.
/// 계산 비용은 이미 병목이 아님이 확인됐으므로(42개에서 프레임 예산의 0.014%),
/// 여기서 재는 것은 SwiftUI 렌더링과 제스처 응답이다.
struct S1_GestureProbe: View {
    @State private var frames: [LayerFrame] = (0..<43).map { i in
        LayerFrame(center: Vec2(x: 120 + Double(i % 7) * 140,
                                y: 150 + Double(i / 7) * 180),
                   size: Size2(width: 100, height: 100),
                   rotation: 0)
    }
    @State private var selected: Int? = nil
    @State private var zoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var activeSnaps: [SnapCandidate] = []

    private let canvasSize = Size2(width: 1080, height: 1350)

    var body: some View {
        GeometryReader { geo in
            let fit = min(geo.size.width / canvasSize.width,
                          geo.size.height / canvasSize.height)
            let scale = fit * zoom

            ZStack {
                Color.white

                ForEach(frames.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i == selected ? Color.pink.opacity(0.5)
                                            : Color.gray.opacity(0.3))
                        .frame(width: frames[i].size.width * scale,
                               height: frames[i].size.height * scale)
                        .rotationEffect(.radians(frames[i].rotation))
                        .position(x: frames[i].center.x * scale + pan.width,
                                  y: frames[i].center.y * scale + pan.height)
                        .onTapGesture { selected = i }
                }

                // 스냅 가이드선
                ForEach(activeSnaps.indices, id: \.self) { i in
                    let snap = activeSnaps[i]
                    Rectangle()
                        .fill(Color(red: 1, green: 0, blue: 1))   // SwiftUI에 Color.magenta는 없다
                        .frame(width: snap.axis == .vertical ? 1 : geo.size.width,
                               height: snap.axis == .vertical ? geo.size.height : 1)
                        .position(x: snap.axis == .vertical
                                     ? snap.value * scale + pan.width
                                     : geo.size.width / 2,
                                  y: snap.axis == .vertical
                                     ? geo.size.height / 2
                                     : snap.value * scale + pan.height)
                }

                if let s = selected {
                    SelectionOverlayProbe(frame: frames[s], scale: scale, pan: pan)
                }
            }
            .gesture(dragGesture(scale: scale))
            .gesture(magnifyGesture())
        }
    }

    private func dragGesture(scale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let s = selected else {
                    pan = value.translation
                    return
                }
                // 화면 좌표 → 논리좌표. 팬 오프셋을 먼저 빼야 한다.
                frames[s].center = Vec2(x: (value.location.x - pan.width) / scale,
                                        y: (value.location.y - pan.height) / scale)

                let others = frames.enumerated()
                    .filter { $0.offset != s }
                    .map(\.element)
                // 임계는 **화면 좌표 8pt**다. 논리좌표로 계산하면 줌 배율에 따라
                // 걸리는 감각이 달라진다(v4 §5.8.2).
                activeSnaps = snapCandidates(for: frames[s],
                                             among: others,
                                             canvasSize: canvasSize,
                                             threshold: 8 / Double(scale))
            }
            .onEnded { _ in activeSnaps = [] }
    }

    private func magnifyGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard selected == nil else { return }   // 선택이 있으면 레이어가 임자다
                zoom = min(max(value.magnification, 0.5), 4.0)
            }
    }
}

private struct SelectionOverlayProbe: View {
    let frame: LayerFrame
    let scale: CGFloat
    let pan: CGSize

    var body: some View {
        ZStack {
            ForEach(Corner.allCases, id: \.self) { corner in
                let p = frame.corner(corner)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)          // 시각 12pt
                    .overlay(Rectangle().stroke(Color.blue, lineWidth: 1))
                    .frame(width: 44, height: 44)          // 히트 영역은 44pt (HIG 최소치)
                    .contentShape(Rectangle())             // 넓힌 프레임 전체를 탭 대상으로
                    .position(x: p.x * scale + pan.width,
                              y: p.y * scale + pan.height)
            }
        }
    }
}

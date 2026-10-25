import SwiftUI
import SpriteKit
import FitnaKit

struct BallTrackingView: View {
    let model: BallTrackingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(instruction)
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)
                .frame(minHeight: 28)
                .animation(.easeInOut, value: model.phase)

            Spacer(minLength: 0)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
                    SpriteView(scene: model.scene, isPaused: model.isClockPaused, options: [.allowsTransparency])
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    // Tap targets (and VoiceOver buttons) over each slot.
                    if model.phase == .choose {
                        ForEach(0..<model.ballCount, id: \.self) { slot in
                            Button { model.pick(slot) } label: {
                                Circle().fill(Color.white.opacity(0.001)).frame(width: 76, height: 76)
                            }
                            .buttonStyle(.plain)
                            .position(slotPoint(slot, in: geo.size))
                            .accessibilityLabel(L("bt.a11y.ball", String(slot + 1)))
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var instruction: String {
        switch model.phase {
        case .showTarget: return L("bt.watch")
        case .swapping: return L("bt.follow")
        case .choose: return L("bt.choose")
        case .feedback: return model.lastCorrect ? L("feedback.correct") : L("feedback.wrong")
        }
    }

    /// Mirrors BallTrackingScene's slot layout in SwiftUI coordinates.
    private func slotPoint(_ slot: Int, in size: CGSize) -> CGPoint {
        let n = model.ballCount
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard n > 1 else { return center }
        let radius = min(size.width, size.height) * 0.36
        let angle = CGFloat.pi / 2 - CGFloat(slot) * 2 * .pi / CGFloat(n)
        // SpriteKit's y axis points up; SwiftUI's points down.
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }
}

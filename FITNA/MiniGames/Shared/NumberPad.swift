import SwiftUI

/// Large numeric keypad used by number games. Laid out like a phone keypad
/// (always left-to-right so digits sit where players expect them).
struct NumberPad: View {
    var tint: Color = Theme.purple
    var isEnabled: Bool = true
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    var onSubmit: (() -> Void)? = nil

    private let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { d in key(String(d)) { onDigit(d) } }
                }
            }
            HStack(spacing: 10) {
                Button(action: onDelete) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.hairline))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L("pad.delete"))
                key("0") { onDigit(0) }
                if let onSubmit {
                    Button(action: onSubmit) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L("pad.submit"))
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 58)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.fitnaNumber(28, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: Theme.ink.opacity(0.06), radius: 4, y: 2)
                )
        }
        .buttonStyle(PressableStyle())
    }
}

/// Shakes a view horizontally (wrong-answer cue that does not rely on color).
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// Correct/wrong symbol badge (shape + color, so it's color-blind friendly).
struct FlashBadge: View {
    let flash: AnswerFlash

    var body: some View {
        Group {
            switch flash {
            case .correct:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    .accessibilityLabel(L("feedback.correct"))
            case .wrong:
                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.error)
                    .accessibilityLabel(L("feedback.wrong"))
            case .none:
                EmptyView()
            }
        }
        .font(.system(size: 44, weight: .bold))
        .transition(.scale.combined(with: .opacity))
    }
}

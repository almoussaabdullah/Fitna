import SwiftUI
import FitnaKit

struct MentalMathView: View {
    let model: MentalMathViewModel
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .stroke(borderColor, lineWidth: model.flash == .none ? 0 : 3)
                    )

                VStack(spacing: 10) {
                    Text(ltr("\(model.question.text) ="))
                        .font(.fitnaNumber(40, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .id(model.question.text + String(model.answeredCount))
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        .accessibilityLabel(spoken(model.question))

                    Text(model.input.isEmpty ? "?" : ltr(model.input))
                        .font(.fitnaNumber(44, weight: .bold))
                        .foregroundStyle(model.input.isEmpty ? Theme.inkTertiary : GameID.mentalMath.color)
                        .frame(minWidth: 110, minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: 14).fill(GameID.mentalMath.color.opacity(0.08)))
                        .modifier(ShakeEffect(animatableData: shake))

                    if let mistake = model.lastMistake, model.flash == .wrong {
                        Text(ltr(mistake))
                            .font(.fitnaNumber(17, weight: .semibold))
                            .foregroundStyle(Theme.success)
                            .transition(.opacity)
                    }
                }
                .padding()

                VStack {
                    HStack { Spacer(); FlashBadge(flash: model.flash).padding(10) }
                    Spacer()
                }
            }
            .frame(height: 230)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.answeredCount)
            .animation(.easeInOut(duration: 0.2), value: model.flash)

            HStack(spacing: 16) {
                Label(String(model.correctCount), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                Label(String(model.answeredCount - model.correctCount), systemImage: "xmark.circle.fill")
                    .foregroundStyle(Theme.error)
                Spacer()
                Text(L("mm.penaltyNote")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
            }
            .font(.fitnaCallout)

            Spacer(minLength: 4)

            NumberPad(tint: GameID.mentalMath.color, onDigit: model.press, onDelete: model.deleteLast)
        }
        .onChange(of: model.flash) { _, f in
            if f == .wrong { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
        }
    }

    private var borderColor: Color {
        switch model.flash {
        case .correct: return Theme.success
        case .wrong: return Theme.error
        case .none: return .clear
        }
    }

    private func spoken(_ e: MathExpression) -> String {
        let op: String
        switch e.op {
        case .add: op = L("op.plus")
        case .subtract: op = L("op.minus")
        case .multiply: op = L("op.times")
        case .divide: op = L("op.divide")
        }
        return "\(e.lhs) \(op) \(e.rhs)"
    }
}

import SwiftUI
import FitnaKit

struct ValueComparisonView: View {
    let model: ValueComparisonViewModel

    var body: some View {
        VStack(spacing: 18) {
            Text(L("vc.instruction"))
                .font(.fitnaTitle2)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            let pair = model.displayedPair
            VStack(spacing: 14) {
                card(pair.firstIsPlainNumber ? String(pair.first.value) : pair.first.text,
                     value: pair.first.value, side: .first, pair: pair)
                Text(L("vc.or")).font(.fitnaHeadline).foregroundStyle(Theme.inkTertiary)
                card(pair.second.text, value: pair.second.value, side: .second, pair: pair)
            }
            .id(model.pairCounter)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.2), value: model.pairCounter)
    }

    private func card(_ text: String, value: Int, side: ValueComparisonEngine.Side, pair: ValueComparisonEngine.Pair) -> some View {
        let reveal = model.reveal
        let isLarger = pair.larger == side
        let stroke: Color = {
            guard let r = reveal else { return .clear }
            if isLarger { return Theme.success }
            if r.chosen == side { return Theme.error }
            return .clear
        }()
        return Button { model.choose(side) } label: {
            VStack(spacing: 6) {
                Text(ltr(text))
                    .font(.fitnaNumber(40, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if reveal != nil {
                    Text(ltr("= \(value)"))
                        .font(.fitnaNumber(18, weight: .semibold))
                        .foregroundStyle(isLarger ? Theme.success : Theme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface)
                .shadow(color: Theme.ink.opacity(0.07), radius: 10, y: 5))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(stroke, lineWidth: 3))
            .overlay(alignment: .topLeading) {
                if reveal != nil && isLarger {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.success).padding(10)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(reveal != nil)
        .accessibilityLabel(ltr(text))
    }
}

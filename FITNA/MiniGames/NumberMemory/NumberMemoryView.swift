import SwiftUI
import FitnaKit

struct NumberMemoryView: View {
    let model: NumberMemoryViewModel
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            Text(instruction)
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)
                .animation(.easeInOut, value: model.isShowing)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)

                if model.isShowing {
                    VStack(spacing: 16) {
                        digitsRow(model.sequence.map(String.init), highlight: true)
                        TimelineView(.animation) { _ in
                            ProgressBar(fraction: model.showFraction, tint: AnyShapeStyle(GameID.numberMemory.color), height: 6)
                        }
                        .padding(.horizontal, 30)
                    }
                    .transition(.opacity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L("nm.a11y.sequence", model.sequence.map(String.init).joined(separator: " ")))
                } else {
                    VStack(spacing: 14) {
                        slotsRow
                            .modifier(ShakeEffect(animatableData: shake))
                        if model.isShowingFeedback && model.flash == .wrong {
                            VStack(spacing: 4) {
                                Text(L("nm.correctWas")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                                Text(ltr(model.sequence.map(String.init).joined(separator: " ")))
                                    .font(.fitnaNumber(22))
                                    .foregroundStyle(Theme.success)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                VStack {
                    HStack {
                        Spacer()
                        FlashBadge(flash: model.flash).padding(12)
                    }
                    Spacer()
                }
            }
            .frame(height: 210)
            .animation(.easeInOut(duration: 0.25), value: model.isShowing)
            .animation(.spring(response: 0.3), value: model.flash)

            HStack(spacing: 6) {
                ForEach(0..<model.engine.maxMistakes, id: \.self) { i in
                    Image(systemName: i < model.mistakesLeft ? "heart.fill" : "heart")
                        .foregroundStyle(i < model.mistakesLeft ? Theme.error : Theme.inkTertiary)
                }
            }
            .font(.system(size: 16, weight: .bold))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("nm.a11y.lives", String(model.mistakesLeft)))

            Spacer(minLength: 8)

            NumberPad(tint: GameID.numberMemory.color,
                      isEnabled: model.phase == .input,
                      onDigit: model.press,
                      onDelete: model.deleteLast)
        }
        .onChange(of: model.flash) { _, newValue in
            if newValue == .wrong { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
        }
    }

    private var instruction: String {
        if model.isShowing { return L("nm.memorize") }
        if model.isShowingFeedback { return model.flash == .correct ? L("feedback.correct") : L("feedback.wrong") }
        return L("nm.typeIt")
    }

    private var slotsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<model.sequence.count, id: \.self) { i in
                let filled = i < model.entered.count
                Text(filled ? String(model.entered[i]) : "")
                    .font(.fitnaNumber(digitSize))
                    .foregroundStyle(Theme.ink)
                    .frame(width: slotWidth, height: slotWidth * 1.25)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(filled ? GameID.numberMemory.color : Theme.hairline, lineWidth: 2)
                    )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("nm.a11y.entered", String(model.entered.count), String(model.sequence.count)))
    }

    private func digitsRow(_ digits: [String], highlight: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(.fitnaNumber(digitSize + 8, weight: .heavy))
                    .foregroundStyle(highlight ? GameID.numberMemory.color : Theme.ink)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 16)
    }

    private var digitSize: CGFloat { model.sequence.count > 10 ? 18 : model.sequence.count > 7 ? 24 : 32 }
    /// Fits up to 14 slots across a 320pt-wide card.
    private var slotWidth: CGFloat {
        let n = CGFloat(max(1, model.sequence.count))
        return min(38, (300 - (n - 1) * 8) / n)
    }
}

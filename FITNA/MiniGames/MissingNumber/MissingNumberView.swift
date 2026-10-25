import SwiftUI
import FitnaKit

struct MissingNumberView: View {
    let model: MissingNumberViewModel

    var body: some View {
        VStack(spacing: 18) {
            Text(L("mn.instruction"))
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)

            Spacer(minLength: 0)

            if let p = model.puzzle {
                sequence(p)
                Label(L("mn.direction"), systemImage: "arrow.left")
                    .font(.fitnaCaption)
                    .foregroundStyle(Theme.inkTertiary)

                Spacer(minLength: 0)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(p.options, id: \.self) { value in
                        Button { model.choose(value) } label: {
                            Text(String(value))
                                .font(.fitnaNumber(30))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill(value, p))
                                    .shadow(color: Theme.ink.opacity(0.06), radius: 5, y: 2))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(stroke(value, p), lineWidth: 3))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(model.isRevealing)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isRevealing)
    }

    private func sequence(_ p: MissingNumberEngine.Puzzle) -> some View {
        let perRow = p.terms.count <= 6 ? p.terms.count : (p.terms.count + 1) / 2
        let rows = stride(from: 0, to: p.terms.count, by: perRow).map { Array($0..<min($0 + perRow, p.terms.count)) }
        let maxDigits: Int = p.terms.map { String($0).count }.max() ?? 1
        let numberSize: CGFloat = maxDigits > 3 ? 18 : 24
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { i in
                        let missing = i == p.missingIndex
                        Text(missing ? (model.isRevealing ? String(p.answer) : "?") : String(p.terms[i]))
                            .font(.fitnaNumber(numberSize, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(missing ? (model.isRevealing ? Theme.success : Theme.purple) : Theme.ink)
                            .frame(width: 50, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(missing ? Theme.purpleSoft : Theme.background)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(missing ? Theme.purple : .clear, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .fitnaCard(padding: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(p.terms.enumerated().map { $0.offset == p.missingIndex ? L("mn.a11y.missing") : String($0.element) }.joined(separator: "، "))
    }

    private func fill(_ value: Int, _ p: MissingNumberEngine.Puzzle) -> Color {
        guard let f = model.feedback else { return Theme.surface }
        if value == p.answer { return Theme.success.opacity(0.14) }
        if value == f.chosen { return Theme.error.opacity(0.14) }
        return Theme.surface
    }

    private func stroke(_ value: Int, _ p: MissingNumberEngine.Puzzle) -> Color {
        guard let f = model.feedback else { return .clear }
        if value == p.answer { return Theme.success }
        if value == f.chosen { return Theme.error }
        return .clear
    }
}

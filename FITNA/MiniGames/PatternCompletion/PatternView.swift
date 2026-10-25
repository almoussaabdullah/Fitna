import SwiftUI
import FitnaKit

struct PatternView: View {
    let model: PatternViewModel

    var body: some View {
        VStack(spacing: 18) {
            Text(L("pattern.instruction"))
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)

            if let p = model.puzzle {
                sequence(p)
                    .fitnaCard(padding: 14)

                Label(L("pattern.direction"), systemImage: "arrow.left")
                    .font(.fitnaCaption)
                    .foregroundStyle(Theme.inkTertiary)

                Spacer(minLength: 0)

                Text(L("pattern.chooseMissing")).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(Array(p.options.enumerated()), id: \.offset) { index, item in
                        Button { model.choose(index) } label: {
                            PatternItemView(item: item, size: 30)
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
                                    .shadow(color: Theme.ink.opacity(0.06), radius: 5, y: 2))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(stroke(index: index, item: item, puzzle: p), lineWidth: 3))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(model.isRevealing)
                        .accessibilityLabel(PatternItemView.describe(item))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isRevealing)
    }

    private func stroke(index: Int, item: PatternCompletionEngine.Item, puzzle: PatternCompletionEngine.Puzzle) -> Color {
        guard let f = model.feedback else { return .clear }
        if item == puzzle.answer { return Theme.success }
        if index == f.chosen { return Theme.error }
        return .clear
    }

    private func sequence(_ p: PatternCompletionEngine.Puzzle) -> some View {
        let perRow = p.items.count <= 5 ? p.items.count : (p.items.count + 1) / 2
        let rows = stride(from: 0, to: p.items.count, by: perRow).map { Array($0..<min($0 + perRow, p.items.count)) }
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { i in
                        Group {
                            if i == p.missingIndex {
                                if model.isRevealing {
                                    PatternItemView(item: p.answer, size: 22)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.success, lineWidth: 2))
                                } else {
                                    Text("?")
                                        .font(.fitnaNumber(28, weight: .heavy))
                                        .foregroundStyle(Theme.purple)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.purple, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                                }
                            } else {
                                PatternItemView(item: p.items[i], size: 22)
                            }
                        }
                        .frame(width: 54, height: 62)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.background))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(p.items.enumerated().map { $0.offset == p.missingIndex ? "?" : PatternItemView.describe($0.element) }.joined(separator: "، "))
    }
}

/// One pattern element: `count` copies of a symbol in a color, rotated.
struct PatternItemView: View {
    let item: PatternCompletionEngine.Item
    let size: CGFloat

    var body: some View {
        let color = Theme.accent(item.color)
        let symbols = Array(repeating: item.symbolName, count: item.count)
        Group {
            if item.count <= 2 {
                HStack(spacing: 2) { ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in glyph(s, color) } }
            } else {
                VStack(spacing: 2) {
                    HStack(spacing: 2) { ForEach(0..<2, id: \.self) { _ in glyph(item.symbolName, color) } }
                    HStack(spacing: 2) { ForEach(0..<(item.count - 2), id: \.self) { _ in glyph(item.symbolName, color) } }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func glyph(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: item.count > 1 ? size * 0.72 : size, weight: .bold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(Double(item.rotation)))
    }

    static func describe(_ item: PatternCompletionEngine.Item) -> String {
        let colorKey = ["color.purple", "color.turquoise", "color.orange", "color.coral"][item.color % 4]
        var parts = [L("pattern.a11y.count", String(item.count)), L(colorKey)]
        if item.usesDirectionalShape { parts.append(L("pattern.a11y.rotation", String(item.rotation))) }
        return parts.joined(separator: " ")
    }
}

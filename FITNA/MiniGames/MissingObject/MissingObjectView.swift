import SwiftUI
import FitnaKit

struct MissingObjectView: View {
    let model: MissingObjectViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(instruction)
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)
                .frame(minHeight: 28)

            if let round = model.round {
                board(round)
                    .aspectRatio(1, contentMode: .fit)

                if case .memorize = model.phase {
                    TimelineView(.animation) { _ in
                        ProgressBar(fraction: model.memorizeFraction, tint: AnyShapeStyle(GameID.missingObject.color), height: 6)
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 0)

                options(round)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.phase)
    }

    private var instruction: String {
        switch model.phase {
        case .memorize: return L("mo.memorize")
        case .blank: return L("mo.wait")
        case .choose: return L("mo.choose")
        case .feedback: return model.lastCorrect ? L("feedback.correct") : L("feedback.wrong")
        }
    }

    private var showsAll: Bool {
        if case .memorize = model.phase { return true }
        return false
    }

    private var isBlank: Bool {
        if case .blank = model.phase { return true }
        return false
    }

    private var revealMissing: Bool {
        if case .feedback = model.phase { return true }
        return false
    }

    private func board(_ round: MissingObjectEngine.Round) -> some View {
        let objectsBySlot = Dictionary(uniqueKeysWithValues: round.objects.map { ($0.slot, $0) })
        return GeometryReader { geo in
            let cell = (geo.size.width - 3 * 8) / 4
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<MissingObjectEngine.boardSlots, id: \.self) { slot in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.surface)
                            .shadow(color: Theme.ink.opacity(0.05), radius: 3, y: 2)
                        if let obj = objectsBySlot[slot], !isBlank {
                            let isMissing = obj == round.missing
                            if !isMissing || showsAll {
                                symbol(obj, size: cell * 0.5)
                            } else if revealMissing {
                                symbol(obj, size: cell * 0.5)
                                    .opacity(0.9)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Theme.success, style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                                            .frame(width: cell * 0.85, height: cell * 0.85)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .frame(width: cell * 0.7, height: cell * 0.7)
                            }
                        }
                    }
                    .frame(width: cell, height: cell)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("mo.a11y.board", String(round.objects.count)))
    }

    private func symbol(_ obj: MissingObjectEngine.PlacedObject, size: CGFloat) -> some View {
        Image(systemName: SymbolCatalog.objects[obj.symbolIndex].name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.accent(obj.colorIndex))
    }

    private func options(_ round: MissingObjectEngine.Round) -> some View {
        let columns = round.options.count <= 4 ? 4 : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(round.options, id: \.self) { option in
                Button { model.choose(option) } label: {
                    Image(systemName: SymbolCatalog.objects[option].name)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(optionFill(option, round)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(optionStroke(option, round), lineWidth: 2.5))
                }
                .buttonStyle(PressableStyle())
                .disabled(model.phase != .choose)
                .accessibilityLabel(L("mo.a11y.option"))
            }
        }
        .opacity(showsAll || isBlank ? 0.35 : 1)
    }

    private func optionFill(_ option: Int, _ round: MissingObjectEngine.Round) -> Color {
        guard case .feedback(_, let chosen) = model.phase else { return Theme.surface }
        if option == round.missing.symbolIndex { return Theme.success.opacity(0.15) }
        if option == chosen { return Theme.error.opacity(0.15) }
        return Theme.surface
    }

    private func optionStroke(_ option: Int, _ round: MissingObjectEngine.Round) -> Color {
        guard case .feedback(_, let chosen) = model.phase else { return Theme.hairline }
        if option == round.missing.symbolIndex { return Theme.success }
        if option == chosen { return Theme.error }
        return Theme.hairline
    }
}

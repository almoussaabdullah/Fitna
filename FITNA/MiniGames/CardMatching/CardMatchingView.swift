import SwiftUI
import FitnaKit

struct CardMatchingView: View {
    let model: CardMatchingViewModel

    var body: some View {
        GeometryReader { geo in
            let cols = model.columns
            let rows = Int(ceil(Double(model.cards.count) / Double(cols)))
            let spacing: CGFloat = 10
            let w = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let h = min(w * 1.25, (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
            let grid = Array(repeating: GridItem(.fixed(min(w, h / 1.25)), spacing: spacing), count: cols)

            LazyVGrid(columns: grid, spacing: spacing) {
                ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                    CardTile(card: card, height: h, wrongPulse: model.lastMismatch.contains(index))
                        .onTapGesture { model.flip(index) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityText(card, index: index))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.flip(index) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func accessibilityText(_ card: CardMatchingEngine.Card, index: Int) -> String {
        switch card.state {
        case .hidden: return L("cm.a11y.hidden", String(index + 1))
        case .revealed: return L("cm.a11y.revealed", String(index + 1))
        case .matched: return L("cm.a11y.matched", String(index + 1))
        }
    }
}

private struct CardTile: View {
    let card: CardMatchingEngine.Card
    let height: CGFloat
    let wrongPulse: Bool

    private var isFaceUp: Bool { card.state != .hidden }
    private var faceColor: Color { Theme.accent(card.face) }

    var body: some View {
        ZStack {
            // Back
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.heroGradient)
                .overlay(
                    Image(systemName: "brain")
                        .font(.system(size: height * 0.28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                )
                .opacity(isFaceUp ? 0 : 1)

            // Face
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(card.state == .matched ? Theme.success : (wrongPulse ? Theme.error : faceColor.opacity(0.35)),
                                lineWidth: card.state == .matched || wrongPulse ? 3 : 1.5)
                )
                .overlay(
                    Image(systemName: SymbolCatalog.cardFaces[card.face % SymbolCatalog.cardFaces.count])
                        .font(.system(size: height * 0.36, weight: .bold))
                        .foregroundStyle(faceColor)
                )
                .overlay(alignment: .topTrailing) {
                    if card.state == .matched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.success)
                            .padding(5)
                    }
                }
                .opacity(isFaceUp ? 1 : 0)
                .scaleEffect(x: -1, y: 1) // pre-mirrored so the flip reads correctly
        }
        .frame(height: height)
        .rotation3DEffect(.degrees(isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: card.state)
        .opacity(card.state == .matched ? 0.75 : 1)
        .shadow(color: Theme.ink.opacity(0.08), radius: 5, y: 3)
    }
}

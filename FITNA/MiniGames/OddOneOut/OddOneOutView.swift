import SwiftUI
import FitnaKit

struct OddOneOutView: View {
    let model: OddOneOutViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(L("odd.instruction"))
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: 0)
            if let r = model.displayed {
                grid(r)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface)
                        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6))
            }
            Spacer(minLength: 0)
        }
    }

    private func grid(_ r: OddOneOutEngine.Round) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = r.gridSize >= 6 ? 4 : 8
            let cell = (geo.size.width - spacing * CGFloat(r.gridSize - 1)) / CGFloat(r.gridSize)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: r.gridSize), spacing: spacing) {
                ForEach(0..<r.cellCount, id: \.self) { i in
                    Button { model.tap(i) } label: {
                        cellView(r, index: i, size: cell)
                            .frame(width: cell, height: cell)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L("odd.a11y.cell", String(i / r.gridSize + 1), String(i % r.gridSize + 1)))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .id(r.oddIndex * 1000 + r.cellCount + (model.revealed == nil ? 0 : 1))
        .transition(.opacity)
    }

    @ViewBuilder
    private func cellView(_ r: OddOneOutEngine.Round, index: Int, size: CGFloat) -> some View {
        let isOdd = index == r.oddIndex
        let base = Theme.accent(r.colorIndex)
        let revealing = model.revealed != nil
        ZStack {
            if revealing && isOdd {
                Circle().stroke(Theme.success, lineWidth: 3).frame(width: size * 0.95, height: size * 0.95)
            } else if revealing, let tapped = model.revealed?.tapped, tapped == index {
                Circle().stroke(Theme.error, lineWidth: 3).frame(width: size * 0.95, height: size * 0.95)
            }
            symbol(r, isOdd: isOdd, base: base, size: size * 0.62)
        }
    }

    @ViewBuilder
    private func symbol(_ r: OddOneOutEngine.Round, isOdd: Bool, base: Color, size: CGFloat) -> some View {
        switch r.difference {
        case .rotation(let deg):
            Image(systemName: r.baseSymbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(base)
                .rotationEffect(.degrees(isOdd ? deg : 0))
        case .shade(let amount):
            Image(systemName: r.baseSymbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(base)
                .brightness(isOdd ? amount * 0.9 : 0)
        case .size(let factor):
            Image(systemName: r.baseSymbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(base)
                .scaleEffect(isOdd ? factor : 1)
        case .symbol(let odd):
            Image(systemName: isOdd ? odd : r.baseSymbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(base)
        }
    }
}

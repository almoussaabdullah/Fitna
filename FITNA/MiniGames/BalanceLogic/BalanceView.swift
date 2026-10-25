import SwiftUI
import FitnaKit

struct BalanceView: View {
    let model: BalanceViewModel

    var body: some View {
        VStack(spacing: 14) {
            if let p = model.puzzle {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(p.clues.enumerated()), id: \.offset) { _, clue in
                            if p.visualScales {
                                ScaleClueView(clue: clue, objects: p.objects)
                            } else {
                                sentence(clue, objects: p.objects)
                            }
                        }
                    }
                    .padding(2)
                }
                .frame(maxHeight: .infinity)

                Text(L(p.question.key))
                    .font(.fitnaTitle2)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: p.objects.count <= 4 ? p.objects.count : 3), spacing: 10) {
                    ForEach(Array(p.objects.enumerated()), id: \.offset) { index, obj in
                        Button { model.choose(index) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: obj.symbol)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Theme.accent(obj.colorIndex))
                                Text(L(obj.nameKey)).font(.fitnaCaptionBold).foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 78)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
                                .shadow(color: Theme.ink.opacity(0.06), radius: 4, y: 2))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(stroke(index, p), lineWidth: 3))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(model.isRevealing)
                        .accessibilityLabel(L(obj.nameKey))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isRevealing)
    }

    private func stroke(_ index: Int, _ p: BalanceLogicEngine.Puzzle) -> Color {
        guard let f = model.feedback else { return .clear }
        if index == p.answer { return Theme.success }
        if index == f.chosen { return Theme.error }
        return .clear
    }

    private func sentence(_ clue: BalanceLogicEngine.Clue, objects: [BalanceLogicEngine.Object]) -> some View {
        let heavy = objects[clue.heavier], light = objects[clue.lighter]
        let text = clue.phrasedAsLighter
            ? L("balance.lighterThan", L(light.nameKey), L(heavy.nameKey))
            : L("balance.heavierThan", L(heavy.nameKey), L(light.nameKey))
        return HStack(spacing: 10) {
            Image(systemName: "scalemass.fill").foregroundStyle(GameID.balanceLogic.color)
            Text(text).font(.fitnaBodyMedium).foregroundStyle(Theme.ink)
            Spacer()
        }
        .fitnaCard(padding: 14)
    }
}

/// A balance beam tilted toward the heavier object (the heavier side sits lower,
/// and a downward arrow marks it — the cue never relies on color).
struct ScaleClueView: View {
    let clue: BalanceLogicEngine.Clue
    let objects: [BalanceLogicEngine.Object]

    var body: some View {
        // Put the phrased subject on the right (reading start in Arabic).
        let rightIndex = clue.phrasedAsLighter ? clue.lighter : clue.heavier
        let leftIndex = clue.phrasedAsLighter ? clue.heavier : clue.lighter
        let rightIsHeavy = rightIndex == clue.heavier
        let tilt: Double = rightIsHeavy ? 9 : -9

        VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Theme.ink.opacity(0.75))
                    .frame(height: 6)
                    .padding(.horizontal, 30)
                HStack {
                    pan(objects[leftIndex], heavy: !rightIsHeavy)
                    Spacer()
                    pan(objects[rightIndex], heavy: rightIsHeavy)
                }
                .padding(.horizontal, 12)
                .offset(y: -26)
            }
            .rotationEffect(.degrees(tilt))
            .frame(height: 70)
            Triangle()
                .fill(Theme.ink.opacity(0.75))
                .frame(width: 26, height: 22)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .fitnaCard(padding: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("balance.heavierThan", L(objects[clue.heavier].nameKey), L(objects[clue.lighter].nameKey)))
    }

    private func pan(_ obj: BalanceLogicEngine.Object, heavy: Bool) -> some View {
        VStack(spacing: 2) {
            if heavy {
                Image(systemName: "arrow.down").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.inkSecondary)
            }
            Image(systemName: obj.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.accent(obj.colorIndex))
            Text(L(obj.nameKey)).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
        }
        .frame(width: 72)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

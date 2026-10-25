import SwiftUI
import FitnaKit

struct SortingView: View {
    let model: SortingViewModel

    private let groupColors: [Color] = [Theme.purple, Color(hex: 0x1FA597)]
    private let groupSymbols = ["circle.fill", "square.fill"]

    var body: some View {
        VStack(spacing: 16) {
            if let r = model.round {
                ruleBanner(r)
                    .id(model.roundNumber)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))

                Spacer(minLength: 0)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 18) {
                    ForEach(r.items) { item in
                        tile(item, rule: r.rule)
                    }
                }
                .padding(.vertical, 8)

                Spacer(minLength: 0)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.roundNumber)
    }

    private func ruleBanner(_ r: SortingChallengeEngine.Round) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ruleSymbol(r.rule))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(GameID.sortingChallenge.color))
            VStack(alignment: .leading, spacing: 2) {
                if model.ruleChanges && model.roundNumber > 1 {
                    Text(L("sort.newRule")).font(.fitnaCaptionBold).foregroundStyle(Theme.orange)
                }
                Text(ruleText(r)).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .fitnaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func ruleText(_ r: SortingChallengeEngine.Round) -> String {
        if r.rule == .alternatingColors {
            return L("sort.rule.alternatingColors", L(r.startGroup == 0 ? "sort.group0" : "sort.group1"))
        }
        return L(r.rule.key)
    }

    private func ruleSymbol(_ rule: SortingChallengeEngine.Rule) -> String {
        switch rule {
        case .ascending: return "arrow.up.right"
        case .descending: return "arrow.down.right"
        case .alphabetical: return "textformat.abc"
        case .alternatingColors: return "circle.lefthalf.filled"
        }
    }

    private func tile(_ item: SortingChallengeEngine.Item, rule: SortingChallengeEngine.Rule) -> some View {
        let done = model.tapped.contains(item.id)
        let wrong = model.wrongItemID == item.id
        let tint = rule == .alternatingColors ? groupColors[item.colorGroup] : GameID.sortingChallenge.color
        let offset = model.jitter[item.id] ?? .init(dx: 0, dy: 0)
        return Button { model.tap(item) } label: {
            ZStack {
                Circle()
                    .fill(done ? Theme.success.opacity(0.15) : tint.opacity(0.14))
                Circle()
                    .stroke(wrong ? Theme.error : (done ? Theme.success : tint), lineWidth: wrong ? 4 : 2.5)
                Text(item.label)
                    .font(rule == .alphabetical ? FitnaFont.font(34, .bold) : .fitnaNumber(30))
                    .foregroundStyle(done ? Theme.success : Theme.ink)
                if rule == .alternatingColors {
                    // Shape marker so the color groups are distinguishable without color.
                    Image(systemName: groupSymbols[item.colorGroup])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                        .offset(y: 28)
                }
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .offset(x: 28, y: -28)
                }
            }
            .frame(width: 84, height: 84)
            .scaleEffect(done ? 0.88 : 1)
            .offset(x: offset.dx, y: offset.dy)
            .modifier(ShakeEffect(animatableData: wrong ? 1 : 0))
        }
        .buttonStyle(PressableStyle())
        .disabled(done)
        .animation(.spring(response: 0.3), value: done)
        .animation(.linear(duration: 0.35), value: wrong)
        .accessibilityLabel(item.label)
        .accessibilityValue(done ? L("sort.a11y.done") : "")
    }
}

import SwiftUI
import FitnaKit

/// Results screen after a standalone game.
struct GameResultsView: View {
    let summary: RecordSummary
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var outcome: SessionOutcome { summary.outcome }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(symbol: "target", value: NumberText.percent(outcome.accuracy), label: L("results.accuracy"), tint: Theme.turquoise)
                    StatTile(symbol: "gauge.with.dots.needle.67percent", value: NumberText.score(summary.performance),
                             label: L("results.performance"), tint: Theme.purple)
                    StatTile(symbol: "sparkles", value: "+\(summary.xpEarned)", label: L("results.xp"), tint: Theme.orange)
                    if let median = outcome.medianResponseTime {
                        StatTile(symbol: "stopwatch.fill", value: L("results.secondsValue", NumberText.seconds(median)),
                                 label: L("results.medianTime"), tint: Theme.color(for: .speed))
                    } else {
                        StatTile(symbol: "flame.fill", value: String(outcome.bestStreak), label: L("results.bestStreak"), tint: Theme.error)
                    }
                    if let h = outcome.highlightValue, outcome.gameID == .numberMemory {
                        StatTile(symbol: "number", value: String(h), label: L("results.longestSpan"), tint: outcome.gameID.color)
                    }
                    StatTile(symbol: "clock.fill", value: NumberText.duration(outcome.duration), label: L("results.duration"), tint: Theme.inkSecondary)
                }

                difficultyCard

                if summary.leveledUp {
                    banner(symbol: "arrow.up.circle.fill", text: L("results.levelUp", String(summary.newLevel)), tint: Theme.orange)
                }
                ForEach(summary.newAchievements, id: \.self) { ach in
                    banner(symbol: ach.symbol, text: L("results.achievement", L(ach.titleKey)), tint: Theme.purple)
                }

                Text(L("results.performanceNote"))
                    .font(.fitnaCaption)
                    .foregroundStyle(Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    Button(action: onReplay) { Label(L("results.replay"), systemImage: "arrow.clockwise") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button(L("results.done"), action: onExit).buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(Theme.padding)
        }
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(outcome.gameID.color.opacity(0.12)).frame(width: 150, height: 150)
                    .scaleEffect(appeared ? 1 : 0.6)
                VStack(spacing: 2) {
                    Text(String(outcome.rawScore))
                        .font(.fitnaNumber(46, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(L("game.points")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Text(headline).font(.fitnaTitle).foregroundStyle(Theme.ink)
            if summary.isPersonalBest {
                Chip(text: L("results.newRecord"), symbol: "trophy.fill", tint: Theme.orange)
            } else if let best = summary.previousBest {
                Text(L("results.bestScore", String(best))).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.top, 10)
    }

    private var headline: String {
        switch outcome.accuracy {
        case 0.9...: return L("results.headline.great")
        case 0.7..<0.9: return L("results.headline.good")
        case 0.4..<0.7: return L("results.headline.ok")
        default: return L("results.headline.keepGoing")
        }
    }

    private var difficultyCard: some View {
        let change = summary.difficultyAfter - summary.difficultyBefore
        let (symbol, text, tint): (String, String, Color) = {
            if change > 0 { return ("arrow.up.right", L("results.difficultyUp", String(summary.difficultyAfter)), Theme.success) }
            if change < 0 { return ("arrow.down.right", L("results.difficultyDown", String(summary.difficultyAfter)), Theme.orange) }
            return ("equal", L("results.difficultySame", String(summary.difficultyAfter)), Theme.inkSecondary)
        }()
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.13)))
            Text(text).font(.fitnaCallout).foregroundStyle(Theme.ink)
            Spacer()
        }
        .fitnaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func banner(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Text(text).font(.fitnaHeadline).foregroundStyle(.white)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(tint.gradient))
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
    }
}

import SwiftUI
import FitnaKit

/// Short how-to card shown before a game.
struct GameTutorialView: View {
    let game: GameID
    let level: Int
    let launch: GameLaunch
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                }
                .accessibilityLabel(L("common.close"))
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 20) {
                    IconBadge(symbol: game.symbol, tint: game.color, size: 88)
                        .padding(.top, 12)
                    VStack(spacing: 8) {
                        Text(game.name).font(.fitnaDisplay).foregroundStyle(Theme.ink)
                        HStack(spacing: 8) {
                            Chip(text: game.skill.name, symbol: game.skill.symbol, tint: game.color)
                            Chip(text: L("game.levelN", String(level)), symbol: "chart.bar.fill", tint: Theme.inkSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L("tutorial.howTo"), systemImage: "lightbulb.fill")
                            .font(.fitnaHeadline)
                            .foregroundStyle(Theme.purple)
                        Text(game.tutorial)
                            .font(.fitnaBody)
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fitnaCard()

                    if launch != .free {
                        Label(L(launch == .workout ? "tutorial.workoutNote" : "tutorial.assessmentNote"), systemImage: "timer")
                            .font(.fitnaCallout)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(.horizontal, Theme.padding)
            }

            Button(action: onStart) {
                Label(L("tutorial.start"), systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(Theme.padding)
        }
    }
}

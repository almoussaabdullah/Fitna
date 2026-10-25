import SwiftUI
import SwiftData
import FitnaKit

struct GamesView: View {
    @Query(sort: \GameSession.endedAt) private var sessions: [GameSession]
    @Query private var difficulties: [DifficultyProgress]
    @State private var filter: CognitiveSkill?
    @State private var playing: GameID?

    private var bestScores: [GameID: Int] {
        var map: [GameID: Int] = [:]
        for s in sessions where s.completed {
            if let g = s.gameID, let r = s.result { map[g] = max(map[g] ?? 0, r.rawScore) }
        }
        return map
    }

    private var levels: [GameID: Int] {
        var map: [GameID: Int] = [:]
        for d in difficulties { if let g = GameID(rawValue: d.gameRaw) { map[g] = d.difficulty.level } }
        return map
    }

    private var games: [GameID] {
        guard let filter else { return GameID.allCases }
        return GameID.allCases.filter { $0.skill == filter }
    }

    var body: some View {
        let best = bestScores
        let lv = levels
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(games) { game in
                            GameCard(game: game, level: lv[game] ?? 1, best: best[game]) { playing = game }
                        }
                    }
                }
                .padding(Theme.padding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.games"))
        }
        .fullScreenCover(item: $playing) { game in
            GameHostView(game: game, launch: .free) { playing = nil }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, title: L("games.all"), symbol: "square.grid.2x2.fill", tint: Theme.ink)
                ForEach(CognitiveSkill.allCases) { skill in
                    filterChip(skill, title: skill.name, symbol: skill.symbol, tint: skill.color)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(_ skill: CognitiveSkill?, title: String, symbol: String, tint: Color) -> some View {
        let selected = filter == skill
        return Button {
            withAnimation(.snappy) { filter = skill }
            Feedback.tap()
        } label: {
            Label(title, systemImage: symbol)
                .font(.fitnaCaptionBold)
                .foregroundStyle(selected ? .white : tint)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Capsule().fill(selected ? tint : tint.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct GameCard: View {
    let game: GameID
    let level: Int
    let best: Int?
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    IconBadge(symbol: game.symbol, tint: game.color, size: 50)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(game.color)
                }
                Text(game.name)
                    .font(.fitnaHeadline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Chip(text: game.skill.name, symbol: game.skill.symbol, tint: game.color)
                HStack(spacing: 6) {
                    LevelDots(level: level, tint: game.color)
                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("game.levelN", String(level)))
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill").font(.system(size: 11)).foregroundStyle(Theme.orange)
                    Text(best.map { L("games.best", String($0)) } ?? L("games.notPlayed"))
                        .font(.fitnaCaption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fitnaCard(padding: 14)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("games.a11y.playHint"))
    }
}

/// Ten small bars showing the adaptive difficulty level.
struct LevelDots: View {
    let level: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...Difficulty.maxLevel, id: \.self) { i in
                Capsule()
                    .fill(i <= level ? tint : Theme.hairline)
                    .frame(width: 8, height: 8 + CGFloat(i) * 0.8)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

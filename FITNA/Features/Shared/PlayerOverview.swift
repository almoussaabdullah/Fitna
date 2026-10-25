import Foundation
import FitnaKit

/// Derived, read-only view of the player's progress, built from real stored sessions.
struct PlayerOverview {
    struct RecentItem: Identifiable {
        let id: UUID
        let game: GameID
        let date: Date
        let rawScore: Int
        let performance: Double?
        let accuracy: Double
    }

    let statistics: PlayerStatistics
    let levelInfo: Progression.LevelInfo
    let totalXP: Int
    let currentStreak: Int
    let longestStreak: Int
    let recent: [RecentItem]
    let lastPlayed: [GameID: Date]
    let playedToday: Bool

    var tier: BrainTier? { statistics.overallScore.map(BrainTier.tier(forScore:)) }

    static func make(sessions: [GameSession], totalXP: Int, now: Date = Date(), calendar: Calendar = .current) -> PlayerOverview {
        let summaries = sessions.compactMap(\.summary)
        let stats = PlayerStatistics.compute(from: summaries, calendar: calendar)
        var lastPlayed: [GameID: Date] = [:]
        for s in summaries where s.completed {
            if (lastPlayed[s.gameID] ?? .distantPast) < s.date { lastPlayed[s.gameID] = s.date }
        }
        let recent = sessions
            .filter(\.completed)
            .sorted { $0.endedAt > $1.endedAt }
            .prefix(6)
            .compactMap { s -> RecentItem? in
                guard let g = s.gameID, let r = s.result else { return nil }
                return RecentItem(id: s.id, game: g, date: s.endedAt, rawScore: r.rawScore, performance: r.performance, accuracy: r.accuracy)
            }
        return PlayerOverview(statistics: stats,
                              levelInfo: Progression.levelInfo(totalXP: totalXP),
                              totalXP: totalXP,
                              currentStreak: Streaks.current(activeDays: stats.activeDays, today: now, calendar: calendar),
                              longestStreak: Streaks.longest(activeDays: stats.activeDays, calendar: calendar),
                              recent: Array(recent),
                              lastPlayed: lastPlayed,
                              playedToday: stats.activeDays.contains(DayKey.key(for: now, calendar: calendar)))
    }

    /// Games to suggest: the weakest category first, preferring games not played recently.
    func recommendations(count: Int = 3) -> [GameID] {
        let scores = statistics.categoryScores
        let skills = CognitiveSkill.allCases.sorted { (scores[$0] ?? -1) < (scores[$1] ?? -1) }
        var picks: [GameID] = []
        for skill in skills {
            let game = skill.games.min { (lastPlayed[$0] ?? .distantPast) < (lastPlayed[$1] ?? .distantPast) }
            if let game { picks.append(game) }
            if picks.count == count { break }
        }
        return picks
    }

    /// Game of the day, the same for everyone on a given date.
    static func dailyChallenge(for date: Date = Date(), calendar: Calendar = .current) -> GameID {
        let seed = DayKey.seed(for: date, calendar: calendar, salt: "challenge")
        return GameID.allCases[Int(seed % UInt64(GameID.allCases.count))]
    }
}

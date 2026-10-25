import Foundation

/// A lightweight, persistence-agnostic view of one stored session,
/// used to compute statistics, category scores and achievements.
public struct SessionSummary: Equatable, Sendable {
    public var gameID: GameID
    public var date: Date
    public var level: Int
    public var rawScore: Int
    public var performance: Double?
    public var accuracy: Double
    public var medianResponseTime: Double?
    public var duration: Double
    public var completed: Bool
    public var highlightValue: Int?

    public init(gameID: GameID, date: Date, level: Int, rawScore: Int, performance: Double?, accuracy: Double,
                medianResponseTime: Double?, duration: Double, completed: Bool, highlightValue: Int? = nil) {
        self.gameID = gameID
        self.date = date
        self.level = level
        self.rawScore = rawScore
        self.performance = performance
        self.accuracy = accuracy
        self.medianResponseTime = medianResponseTime
        self.duration = duration
        self.completed = completed
        self.highlightValue = highlightValue
    }

    public init(outcome: SessionOutcome, date: Date) {
        self.init(gameID: outcome.gameID, date: date, level: outcome.level, rawScore: outcome.rawScore,
                  performance: ScoringModel.performance(outcome), accuracy: outcome.accuracy,
                  medianResponseTime: outcome.medianResponseTime, duration: outcome.duration,
                  completed: outcome.completed, highlightValue: outcome.highlightValue)
    }
}

/// Aggregated statistics derived from real session history (never invented).
public struct PlayerStatistics: Equatable, Sendable {
    public var completedSessions: Int
    public var totalPlayTime: Double
    public var sessionsPerGame: [GameID: Int]
    public var sessionsPerSkill: [CognitiveSkill: Int]
    public var bestRawScore: [GameID: Int]
    public var bestHighlight: [GameID: Int]
    public var categoryScores: [CognitiveSkill: Double]
    public var overallScore: Double?
    public var activeDays: Set<String>
    /// Number of completed speed-weighted sessions where the median response
    /// time beat the game's `fast` reference time with ≥ 90% accuracy.
    public var lightningSessions: Int

    public static let empty = PlayerStatistics(completedSessions: 0, totalPlayTime: 0, sessionsPerGame: [:], sessionsPerSkill: [:],
                                               bestRawScore: [:], bestHighlight: [:], categoryScores: [:], overallScore: nil,
                                               activeDays: [], lightningSessions: 0)

    public init(completedSessions: Int, totalPlayTime: Double, sessionsPerGame: [GameID: Int], sessionsPerSkill: [CognitiveSkill: Int],
                bestRawScore: [GameID: Int], bestHighlight: [GameID: Int], categoryScores: [CognitiveSkill: Double], overallScore: Double?,
                activeDays: Set<String>, lightningSessions: Int) {
        self.completedSessions = completedSessions
        self.totalPlayTime = totalPlayTime
        self.sessionsPerGame = sessionsPerGame
        self.sessionsPerSkill = sessionsPerSkill
        self.bestRawScore = bestRawScore
        self.bestHighlight = bestHighlight
        self.categoryScores = categoryScores
        self.overallScore = overallScore
        self.activeDays = activeDays
        self.lightningSessions = lightningSessions
    }

    public static func compute(from sessions: [SessionSummary], calendar: Calendar = .current) -> PlayerStatistics {
        var stats = PlayerStatistics.empty
        let completed = sessions.filter(\.completed)
        stats.completedSessions = completed.count
        stats.totalPlayTime = sessions.reduce(0) { $0 + $1.duration }
        for s in completed {
            stats.sessionsPerGame[s.gameID, default: 0] += 1
            stats.sessionsPerSkill[s.gameID.skill, default: 0] += 1
            stats.bestRawScore[s.gameID] = max(stats.bestRawScore[s.gameID] ?? 0, s.rawScore)
            if let h = s.highlightValue { stats.bestHighlight[s.gameID] = max(stats.bestHighlight[s.gameID] ?? 0, h) }
            stats.activeDays.insert(DayKey.key(for: s.date, calendar: calendar))
            if s.gameID.speedMatters, let median = s.medianResponseTime, s.accuracy >= 0.9,
               median <= s.gameID.referenceTimes(level: s.level).fast {
                stats.lightningSessions += 1
            }
        }
        let newestFirst = completed.sorted { $0.date > $1.date }
        for skill in CognitiveSkill.allCases {
            let perf = newestFirst.filter { $0.gameID.skill == skill }.compactMap(\.performance)
            if let score = ScoringModel.categoryScore(recentPerformancesNewestFirst: perf) {
                stats.categoryScores[skill] = score
            }
        }
        stats.overallScore = ScoringModel.overallScore(stats.categoryScores)
        return stats
    }
}

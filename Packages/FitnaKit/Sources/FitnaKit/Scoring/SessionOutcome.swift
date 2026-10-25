import Foundation

/// Everything a finished (or abandoned) game session reports.
/// Produced by each game engine and consumed by the scoring model,
/// the difficulty engine and persistence.
public struct SessionOutcome: Codable, Equatable, Sendable {
    public var gameID: GameID
    /// Difficulty level the session was played at (1...10).
    public var level: Int
    public var length: SessionLength
    /// Number of correct answers / successful trials.
    public var correct: Int
    /// Total answers / trials attempted (correct + incorrect).
    public var attempts: Int
    /// Response times (seconds) of individual answers, used for the speed component.
    public var responseTimes: [Double]
    /// Game-specific raw points shown to the player and kept as records.
    public var rawScore: Int
    /// Longest run of consecutive correct answers in the session.
    public var bestStreak: Int
    /// Wall-clock play time in seconds (pauses excluded).
    public var duration: Double
    /// False when the player quit before the session ended.
    public var completed: Bool
    /// Optional game-specific headline metric (e.g. longest digit span).
    public var highlightValue: Int?

    public init(
        gameID: GameID,
        level: Int,
        length: SessionLength = .standard,
        correct: Int,
        attempts: Int,
        responseTimes: [Double] = [],
        rawScore: Int,
        bestStreak: Int = 0,
        duration: Double,
        completed: Bool = true,
        highlightValue: Int? = nil
    ) {
        self.gameID = gameID
        self.level = Difficulty.clamp(level)
        self.length = length
        self.correct = max(0, correct)
        self.attempts = max(0, attempts)
        self.responseTimes = responseTimes
        self.rawScore = max(0, rawScore)
        self.bestStreak = bestStreak
        self.duration = max(0, duration)
        self.completed = completed
        self.highlightValue = highlightValue
    }

    /// Fraction of attempts that were correct (0 when nothing was attempted).
    public var accuracy: Double {
        attempts == 0 ? 0 : min(1, Double(correct) / Double(attempts))
    }

    /// Median response time — robust against one long hesitation.
    public var medianResponseTime: Double? {
        guard !responseTimes.isEmpty else { return nil }
        let sorted = responseTimes.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}

/// Small helper engines use to accumulate answers during a session.
public struct AnswerTally: Codable, Equatable, Sendable {
    public private(set) var correct = 0
    public private(set) var attempts = 0
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    public private(set) var responseTimes: [Double] = []

    public init() {}

    public mutating func record(correct isCorrect: Bool, responseTime: Double?) {
        attempts += 1
        if isCorrect {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
        if let t = responseTime, t.isFinite, t >= 0 {
            responseTimes.append(t)
        }
    }
}

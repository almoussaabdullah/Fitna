import Foundation

/// FITNA scoring model — documented and deliberately simple so the numbers
/// shown to players can be explained.
///
/// 1. **Quality (0…1)** — how well the session went at its own difficulty:
///        quality = wA · accuracy + wS · speed
///    where `speed` maps the median response time linearly between the game's
///    reference `fast` (1.0) and `slow` (0.0) times. Games whose skill is not
///    speed-driven (memory, logic, tracking) use wS = 0.10, the rest wS = 0.30.
///    Without measured response times the speed term falls back to accuracy.
///
/// 2. **Performance (0…100)** — the normalized, comparable score:
///        performance = 100 · quality · difficultyWeight(level)
///        difficultyWeight(level) = 0.40 + 0.60 · (level − 1) / 9
///    A perfect session at level 1 is worth 40, at level 10 it is worth 100.
///    So a rating can never rise just because a challenge became easier —
///    playing easier puzzles caps the achievable performance.
///
/// 3. **Category score** — exponentially weighted average of the most recent
///    completed sessions' performances in that category (newest weighs most).
///
/// 4. **Overall brain score** — plain mean of the category scores that have data.
///
/// Abandoned sessions are stored but never contribute to performance or difficulty.
/// Raw game points are tracked separately as personal records.
public enum ScoringModel {
    public static let maxPerformance = 100.0

    public static func speedComponent(_ outcome: SessionOutcome) -> Double? {
        guard let median = outcome.medianResponseTime else { return nil }
        let ref = outcome.gameID.referenceTimes(level: outcome.level)
        guard ref.slow > ref.fast else { return nil }
        let value = (ref.slow - median) / (ref.slow - ref.fast)
        return min(1, max(0, value))
    }

    public static func speedWeight(for game: GameID) -> Double {
        game.speedMatters ? 0.30 : 0.10
    }

    public static func quality(_ outcome: SessionOutcome) -> Double {
        guard outcome.attempts > 0 else { return 0 }
        let wS = speedWeight(for: outcome.gameID)
        let speed = speedComponent(outcome) ?? outcome.accuracy
        let q = (1 - wS) * outcome.accuracy + wS * speed
        return min(1, max(0, q))
    }

    public static func difficultyWeight(level: Int) -> Double {
        0.40 + 0.60 * Double(Difficulty.clamp(level) - 1) / Double(Difficulty.maxLevel - 1)
    }

    /// Normalized performance (0…100). Returns nil for abandoned sessions.
    public static func performance(_ outcome: SessionOutcome) -> Double? {
        guard outcome.completed, outcome.attempts > 0 else { return nil }
        let value = maxPerformance * quality(outcome) * difficultyWeight(level: outcome.level)
        return (value * 10).rounded() / 10
    }

    /// Exponentially-weighted mean, newest first. `decay` = weight ratio between
    /// consecutive sessions (0.8 → the previous session counts 80% as much).
    public static func categoryScore(recentPerformancesNewestFirst values: [Double], window: Int = 12, decay: Double = 0.8) -> Double? {
        let slice = values.prefix(window)
        guard !slice.isEmpty else { return nil }
        var weightSum = 0.0
        var total = 0.0
        var w = 1.0
        for v in slice {
            total += v * w
            weightSum += w
            w *= decay
        }
        return (total / weightSum * 10).rounded() / 10
    }

    /// Mean of the categories that have data.
    public static func overallScore(_ categoryScores: [CognitiveSkill: Double]) -> Double? {
        let values = CognitiveSkill.allCases.compactMap { categoryScores[$0] }
        guard !values.isEmpty else { return nil }
        return ((values.reduce(0, +) / Double(values.count)) * 10).rounded() / 10
    }
}

/// "مستوى العقل" — a playful, explicitly fictional tier derived from the overall
/// score. It is an entertainment label, not a measurement of age, IQ or health.
public enum BrainTier: Int, CaseIterable, Sendable {
    case spark = 0, curious, sharp, agile, brilliant, master

    public static func tier(forScore score: Double) -> BrainTier {
        switch score {
        case ..<20: return .spark
        case ..<35: return .curious
        case ..<50: return .sharp
        case ..<65: return .agile
        case ..<80: return .brilliant
        default: return .master
        }
    }

    public var nameKey: String { "tier.\(rawValue).name" }
    public var descriptionKey: String { "tier.\(rawValue).desc" }
    public var symbol: String {
        switch self {
        case .spark: return "sparkle"
        case .curious: return "lightbulb.fill"
        case .sharp: return "scope"
        case .agile: return "hare.fill"
        case .brilliant: return "star.fill"
        case .master: return "crown.fill"
        }
    }
    /// Lower bound of the score band.
    public var minimumScore: Double { [0, 20, 35, 50, 65, 80][rawValue] }
}

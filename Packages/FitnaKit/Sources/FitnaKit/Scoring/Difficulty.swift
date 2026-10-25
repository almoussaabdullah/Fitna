import Foundation

/// Adaptive difficulty, stored independently per game.
///
/// Each game keeps a continuous `rating` in [1, 10.99]; the playable level is
/// `floor(rating)`. After every completed session the rating moves by:
///
///     base     = (quality − 0.70) × 1.2        // 0.70 quality holds steady
///     failure  = −0.25 when accuracy < 0.50    // recent-failure relief
///     momentum = +0.15 after two strong sessions in a row (quality ≥ 0.85)
///              = −0.15 after two weak sessions in a row (quality < 0.45)
///     delta    = clamp(base + failure + momentum, −0.6, +0.6)
///
/// Because |delta| ≤ 0.6 the level can change by at most one step per session,
/// which prevents sudden difficulty spikes or drops.
public struct Difficulty: Codable, Equatable, Sendable {
    public static let minLevel = 1
    public static let maxLevel = 10
    public static let maxStep = 0.6

    public var rating: Double
    /// Last few session qualities, newest last (used for momentum).
    public var recentQualities: [Double]
    public var sessionsPlayed: Int

    public init(rating: Double = 1.0, recentQualities: [Double] = [], sessionsPlayed: Int = 0) {
        self.rating = Difficulty.clampRating(rating)
        self.recentQualities = recentQualities
        self.sessionsPlayed = sessionsPlayed
    }

    public var level: Int { Difficulty.clamp(Int(rating.rounded(.down))) }

    public static func clamp(_ level: Int) -> Int { min(maxLevel, max(minLevel, level)) }
    static func clampRating(_ r: Double) -> Double { min(Double(maxLevel) + 0.99, max(Double(minLevel), r)) }

    /// Rating change for a session — exposed for tests and documentation.
    public func delta(for outcome: SessionOutcome) -> Double {
        guard outcome.completed, outcome.attempts > 0 else { return 0 }
        let q = ScoringModel.quality(outcome)
        var d = (q - 0.70) * 1.2
        if outcome.accuracy < 0.5 { d -= 0.25 }
        if let last = recentQualities.last {
            if last >= 0.85 && q >= 0.85 { d += 0.15 }
            if last < 0.45 && q < 0.45 { d -= 0.15 }
        }
        return min(Difficulty.maxStep, max(-Difficulty.maxStep, d))
    }

    /// Returns the updated state after a session. Sessions played at a level other
    /// than the current one (e.g. fixed-level assessments) still adjust the rating,
    /// but only half as much.
    public func updated(with outcome: SessionOutcome) -> Difficulty {
        guard outcome.completed, outcome.attempts > 0 else { return self }
        var next = self
        var d = delta(for: outcome)
        if outcome.level != level { d *= 0.5 }
        next.rating = Difficulty.clampRating(rating + d)
        next.recentQualities = Array((recentQualities + [ScoringModel.quality(outcome)]).suffix(5))
        next.sessionsPlayed += 1
        return next
    }
}

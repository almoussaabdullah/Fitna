import Foundation

/// Common surface of every mini-game engine.
///
/// Engines are value types that hold rules and state only. Time is never read
/// inside an engine: view models measure response times and pass them in, which
/// keeps every rule deterministic and testable.
public protocol GameEngine {
    var gameID: GameID { get }
    var level: Int { get }
    var length: SessionLength { get }
    var tally: AnswerTally { get }
    var rawScore: Int { get }
    var isFinished: Bool { get }
    /// Optional headline metric (e.g. longest digit span).
    var highlightValue: Int? { get }
}

public extension GameEngine {
    var highlightValue: Int? { nil }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        SessionOutcome(gameID: gameID, level: level, length: length, correct: tally.correct, attempts: tally.attempts,
                       responseTimes: tally.responseTimes, rawScore: rawScore, bestStreak: tally.bestStreak,
                       duration: duration, completed: completed, highlightValue: highlightValue)
    }

    /// Multiplier applied to raw points so harder levels earn more.
    var levelMultiplier: Double { 1.0 + Double(level - 1) * 0.12 }
}

/// Result of a single answer, returned by engines to drive feedback.
public enum AnswerResult: Equatable, Sendable {
    case correct
    case wrong
}

/// Linear interpolation of a per-level parameter between level 1 and level 10.
@inlinable
public func levelLerp(_ level: Int, from a: Double, to b: Double) -> Double {
    let t = Double(Difficulty.clamp(level) - 1) / Double(Difficulty.maxLevel - 1)
    return a + (b - a) * t
}

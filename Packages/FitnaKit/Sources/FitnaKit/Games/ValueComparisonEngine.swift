import Foundation

/// الأكبر أم الأصغر؟ — tap the expression with the larger value.
///
/// Values are never equal. The relative gap between the two values shrinks with
/// level (from ≥ 25% at level 1 to as little as 1–4% at level 10) and the time
/// allowed per pair gets shorter.
public struct ValueComparisonEngine: GameEngine {
    public enum Side: Int, Sendable { case first = 0, second = 1 }

    public struct Pair: Equatable, Sendable {
        /// `nil` operator means a plain number.
        public let first: MathExpression
        public let second: MathExpression
        public let firstIsPlainNumber: Bool
        public var larger: Side { first.value > second.value ? .first : .second }
    }

    public let gameID = GameID.valueComparison
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var pair: Pair
    public private(set) var trialsPlayed = 0
    private var rng: AnyRNG

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        var rng = rng
        self.level = Difficulty.clamp(level)
        self.length = length
        self.pair = ValueComparisonEngine.makePair(level: self.level, rng: &rng)
        self.rng = rng
    }

    public var totalTrials: Int { length == .standard ? 15 : 8 }
    public var trialTimeLimit: Double { levelLerp(level, from: 7.0, to: 3.0) }
    public var isFinished: Bool { trialsPlayed >= totalTrials }

    /// Allowed relative gap range |a − b| / max(a, b) at a level.
    public static func gapRange(level: Int) -> ClosedRange<Double> {
        let hi = levelLerp(level, from: 0.60, to: 0.06)
        let lo = levelLerp(level, from: 0.25, to: 0.01)
        return lo...hi
    }

    @discardableResult
    public mutating func choose(_ side: Side, responseTime: Double) -> AnswerResult {
        let isCorrect = side == pair.larger
        record(isCorrect, responseTime)
        return isCorrect ? .correct : .wrong
    }

    public mutating func timeout() { record(false, trialTimeLimit) }

    private mutating func record(_ isCorrect: Bool, _ responseTime: Double) {
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            rawScore += Int((Double(10 + 2 * level) * levelMultiplier).rounded()) + min(8, tally.streak)
        }
        trialsPlayed += 1
        if !isFinished { pair = ValueComparisonEngine.makePair(level: level, rng: &rng) }
    }

    static func makePair(level: Int, rng: inout AnyRNG) -> Pair {
        let gap = gapRange(level: level)
        for _ in 0..<500 {
            let plain = level <= 2 && Bool.random(using: &rng)
            let a = MathLevels.expression(level: level, using: &rng)
            let b = MathLevels.expression(level: level, using: &rng)
            let first = plain ? MathExpression(a.value, .add, 0) : a
            guard first.value != b.value, max(first.value, b.value) > 0 else { continue }
            let rel = Double(abs(first.value - b.value)) / Double(max(first.value, b.value))
            guard gap.contains(rel) else { continue }
            // Mixed operators read better: avoid two identical operators from level 5.
            if level >= 5 && !plain && a.op == b.op && Bool.random(using: &rng) { continue }
            return Pair(first: first, second: b, firstIsPlainNumber: plain)
        }
        // Practically unreachable; keep a valid, clearly-sized fallback.
        return Pair(first: MathExpression(7, .multiply, 8), second: MathExpression(60, .subtract, 3), firstIsPlainNumber: false)
    }
}

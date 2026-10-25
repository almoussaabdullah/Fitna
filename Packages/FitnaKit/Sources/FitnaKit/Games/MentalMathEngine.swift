import Foundation

/// حساب البرق — answer as many arithmetic questions as possible before time runs out.
///
/// * Points per correct answer: (10 + 2 × level) × multiplier, plus up to 5 speed points.
/// * A wrong answer costs 5 points and `penaltySeconds` of remaining time.
/// * Input auto-checks: the answer is judged once the typed digits reach the
///   answer's length (or match it exactly).
public struct MentalMathEngine: GameEngine {
    public enum InputState: Equatable, Sendable { case incomplete, correct, wrong }

    public let gameID = GameID.mentalMath
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var current: MathExpression
    public private(set) var timeExpired = false
    private var rng: AnyRNG
    private var previous: MathExpression?

    public let penaltySeconds = 2.0

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        var rng = rng
        self.level = Difficulty.clamp(level)
        self.length = length
        self.current = MathLevels.expression(level: level, using: &rng)
        self.rng = rng
    }

    public var sessionDuration: Double { length == .standard ? 60 : 35 }
    public var isFinished: Bool { timeExpired }

    /// Evaluates the digits typed so far.
    public func evaluate(_ input: String) -> InputState {
        let answer = String(current.value)
        if input == answer { return .correct }
        if input.count >= answer.count { return .wrong }
        return .incomplete
    }

    /// Records a judged answer and moves to the next question.
    @discardableResult
    public mutating func commit(_ input: String, responseTime: Double) -> AnswerResult {
        let isCorrect = evaluate(input) == .correct
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            let fast = gameID.referenceTimes(level: level).fast
            let speedBonus = responseTime <= fast ? 5 : responseTime <= fast * 2 ? 2 : 0
            rawScore += Int((Double(10 + 2 * level) * levelMultiplier).rounded()) + speedBonus
        } else {
            rawScore = max(0, rawScore - 5)
        }
        nextQuestion()
        return isCorrect ? .correct : .wrong
    }

    public mutating func timeUp() { timeExpired = true }

    private mutating func nextQuestion() {
        previous = current
        var next = MathLevels.expression(level: level, using: &rng)
        var guardCount = 0
        while next == previous && guardCount < 10 {
            next = MathLevels.expression(level: level, using: &rng)
            guardCount += 1
        }
        current = next
    }
}

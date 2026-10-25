import Foundation

/// ذاكرة الأرقام — memorize a digit sequence, then type it back.
///
/// * Starts at 3 digits on level 1 (one more starting digit every 3 levels).
/// * Each success adds a digit, each failure removes one (never below 3).
/// * Display time per digit shrinks with level.
/// * The session ends after `maxTrials` trials or `maxMistakes` mistakes.
public struct NumberMemoryEngine: GameEngine {
    public let gameID = GameID.numberMemory
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var currentLength: Int
    public private(set) var currentSequence: [Int] = []
    public private(set) var trialsPlayed = 0
    public private(set) var mistakes = 0
    public private(set) var longestRecalled = 0
    private var rng: AnyRNG

    public static let minimumLength = 3
    public static let maximumLength = 14

    public var maxTrials: Int { length == .standard ? 10 : 5 }
    public var maxMistakes: Int { length == .standard ? 3 : 2 }

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
        self.currentLength = NumberMemoryEngine.startLength(level: level)
    }

    public static func startLength(level: Int) -> Int {
        minimumLength + (Difficulty.clamp(level) - 1) / 3
    }

    /// Seconds each digit stays on screen at this level.
    public var secondsPerDigit: Double { levelLerp(level, from: 0.9, to: 0.4) }

    /// Total time the sequence is shown before it hides.
    public var displayDuration: Double { 0.8 + secondsPerDigit * Double(currentLength) }

    public var isFinished: Bool { trialsPlayed >= maxTrials || mistakes >= maxMistakes }

    public var highlightValue: Int? { longestRecalled > 0 ? longestRecalled : nil }

    /// Generates the next sequence. Avoids three identical digits in a row so
    /// sequences never look like a typo.
    @discardableResult
    public mutating func startTrial() -> [Int] {
        var digits: [Int] = []
        while digits.count < currentLength {
            let d = Int.random(in: 0...9, using: &rng)
            if digits.count >= 2, digits[digits.count - 1] == d, digits[digits.count - 2] == d { continue }
            digits.append(d)
        }
        currentSequence = digits
        return digits
    }

    /// Checks the player's answer and adapts the next sequence length.
    @discardableResult
    public mutating func submit(_ answer: [Int], responseTime: Double?) -> AnswerResult {
        precondition(!currentSequence.isEmpty, "startTrial() must be called first")
        let isCorrect = answer == currentSequence
        trialsPlayed += 1
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            longestRecalled = max(longestRecalled, currentLength)
            rawScore += Int((Double(currentLength * 10) * levelMultiplier).rounded())
            currentLength = min(NumberMemoryEngine.maximumLength, currentLength + 1)
        } else {
            mistakes += 1
            currentLength = max(NumberMemoryEngine.minimumLength, currentLength - 1)
        }
        currentSequence = []
        return isCorrect ? .correct : .wrong
    }
}

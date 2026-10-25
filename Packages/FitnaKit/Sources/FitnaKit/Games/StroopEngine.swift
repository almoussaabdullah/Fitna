import Foundation

/// اللون المخادع — an Arabic Stroop challenge: tap the *ink* color, not the word.
public struct StroopEngine: GameEngine {
    /// Colors used by the challenge. Raw values are localization suffixes ("color.red").
    public enum InkColor: String, CaseIterable, Sendable {
        case red, blue, green, yellow, purple, orange
        public var nameKey: String { "color.\(rawValue)" }
    }

    public struct Stimulus: Equatable, Sendable {
        public let word: InkColor
        public let ink: InkColor
        /// Button order for this stimulus.
        public let choices: [InkColor]
        public var isCongruent: Bool { word == ink }
    }

    public let gameID = GameID.stroopChallenge
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var stimulus: Stimulus
    public private(set) var timeExpired = false
    private var rng: AnyRNG
    private var baseOrder: [InkColor]

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        var rng = rng
        self.level = Difficulty.clamp(level)
        self.length = length
        let active = Array(InkColor.allCases.prefix(StroopEngine.colorCount(level: level)))
        baseOrder = active.shuffled(using: &rng)
        stimulus = StroopEngine.makeStimulus(level: self.level, active: active, baseOrder: baseOrder, previous: nil, rng: &rng)
        self.rng = rng
    }

    public static func colorCount(level: Int) -> Int { 3 + (Difficulty.clamp(level) - 1) / 3 }

    public var sessionDuration: Double { length == .standard ? 45 : 25 }
    /// Seconds per stimulus before it counts as a miss.
    public var stimulusTimeLimit: Double { levelLerp(level, from: 4.0, to: 1.6) }
    public var congruentProbability: Double { levelLerp(level, from: 0.35, to: 0.10) }
    /// From level 6 the buttons reshuffle every stimulus.
    public var shufflesChoices: Bool { level >= 6 }
    public var isFinished: Bool { timeExpired }

    @discardableResult
    public mutating func answer(_ color: InkColor, responseTime: Double) -> AnswerResult {
        let isCorrect = color == stimulus.ink
        record(isCorrect, responseTime)
        return isCorrect ? .correct : .wrong
    }

    public mutating func stimulusTimedOut() { record(false, stimulusTimeLimit) }
    public mutating func timeUp() { timeExpired = true }

    private mutating func record(_ isCorrect: Bool, _ responseTime: Double) {
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            let streakBonus = min(10, tally.streak)
            rawScore += Int((Double(10 + level) * levelMultiplier).rounded()) + streakBonus
        }
        let active = Array(InkColor.allCases.prefix(StroopEngine.colorCount(level: level)))
        stimulus = StroopEngine.makeStimulus(level: level, active: active, baseOrder: baseOrder, previous: stimulus, rng: &rng)
    }

    static func makeStimulus(level: Int, active: [InkColor], baseOrder: [InkColor], previous: Stimulus?, rng: inout AnyRNG) -> Stimulus {
        let pCongruent = levelLerp(level, from: 0.35, to: 0.10)
        var ink = active.randomElement(using: &rng)!
        // Avoid the same ink twice in a row so every stimulus requires a fresh decision.
        if let prev = previous, ink == prev.ink, active.count > 1 {
            ink = active.filter { $0 != prev.ink }.randomElement(using: &rng)!
        }
        let word: InkColor
        if Double.random(in: 0..<1, using: &rng) < pCongruent {
            word = ink
        } else {
            word = active.filter { $0 != ink }.randomElement(using: &rng)!
        }
        let choices = level >= 6 ? active.shuffled(using: &rng) : baseOrder
        return Stimulus(word: word, ink: ink, choices: choices)
    }
}

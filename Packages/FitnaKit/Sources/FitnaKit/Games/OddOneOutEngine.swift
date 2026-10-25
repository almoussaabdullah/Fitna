import Foundation

/// صائد الاختلاف — find the single element that differs from the rest.
///
/// The difference is one of: rotation, color shade, size, or a look-alike symbol.
/// Grids grow and differences shrink with level. Every grid has exactly one odd cell.
public struct OddOneOutEngine: GameEngine {
    public enum Difference: Equatable, Sendable {
        /// Odd cell rotated by `degrees`.
        case rotation(degrees: Double)
        /// Odd cell's brightness shifted by `amount` (0…1, applied in HSB space by the view).
        case shade(amount: Double)
        /// Odd cell scaled by `factor`.
        case size(factor: Double)
        /// Odd cell uses a look-alike symbol.
        case symbol(odd: String)
    }

    public struct Round: Equatable, Sendable {
        public let gridSize: Int
        public let baseSymbol: String
        public let colorIndex: Int
        public let oddIndex: Int
        public let difference: Difference
        public var cellCount: Int { gridSize * gridSize }
    }

    public let gameID = GameID.oddOneOut
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var round: Round?
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 10 : 6 }
    public var gridSize: Int { [3, 3, 4, 4, 5, 5, 6, 6, 7, 7][level - 1] }
    /// Seconds before an unanswered round counts as a miss.
    public var roundTimeLimit: Double { levelLerp(level, from: 10, to: 7) }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    public var rotationDegrees: Double { levelLerp(level, from: 90, to: 18) }
    public var shadeAmount: Double { levelLerp(level, from: 0.35, to: 0.10) }
    public var sizeFactor: Double { levelLerp(level, from: 0.62, to: 0.86) }

    @discardableResult
    public mutating func startRound() -> Round {
        let kinds = level <= 2 ? [0, 1, 3] : [0, 1, 2, 3]
        let kind = kinds.randomElement(using: &rng)!
        let n = gridSize
        let odd = Int.random(in: 0..<(n * n), using: &rng)
        let color = Int.random(in: 0..<4, using: &rng)
        let r: Round
        switch kind {
        case 0:
            let sym = SymbolCatalog.directional.randomElement(using: &rng)!
            let sign: Double = Bool.random(using: &rng) ? 1 : -1
            r = Round(gridSize: n, baseSymbol: sym, colorIndex: color, oddIndex: odd, difference: .rotation(degrees: sign * rotationDegrees))
        case 1:
            let sym = SymbolCatalog.patternShapes.randomElement(using: &rng)!
            r = Round(gridSize: n, baseSymbol: sym, colorIndex: color, oddIndex: odd, difference: .shade(amount: shadeAmount))
        case 2:
            let sym = SymbolCatalog.patternShapes.randomElement(using: &rng)!
            r = Round(gridSize: n, baseSymbol: sym, colorIndex: color, oddIndex: odd, difference: .size(factor: sizeFactor))
        default:
            let pair = SymbolCatalog.lookAlikePairs.randomElement(using: &rng)!
            r = Round(gridSize: n, baseSymbol: pair.0, colorIndex: color, oddIndex: odd, difference: .symbol(odd: pair.1))
        }
        round = r
        return r
    }

    @discardableResult
    public mutating func tap(cell: Int, responseTime: Double) -> AnswerResult {
        guard let r = round else { return .wrong }
        let isCorrect = cell == r.oddIndex
        record(isCorrect, responseTime)
        return isCorrect ? .correct : .wrong
    }

    /// Round timer expired without an answer.
    public mutating func timeout() {
        guard round != nil else { return }
        record(false, roundTimeLimit)
    }

    private mutating func record(_ isCorrect: Bool, _ responseTime: Double) {
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            let fast = gameID.referenceTimes(level: level).fast
            rawScore += Int((Double(10 + level) * levelMultiplier).rounded()) + (responseTime <= fast * 1.5 ? 5 : 0)
        }
        roundsPlayed += 1
        round = nil
    }
}

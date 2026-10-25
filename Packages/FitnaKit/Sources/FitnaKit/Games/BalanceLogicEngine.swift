import Foundation

/// الميزان — deduce weight order from comparison clues.
///
/// Objects get a hidden strict order. Clues are comparisons between pairs.
/// The clue set always contains a chain linking every object (so the full order is
/// derivable); higher levels add redundant transitive clues, shuffle phrasing
/// ("heavier"/"lighter") and ask harder questions. `solve` re-derives the answer from
/// the clues alone and the generator only accepts puzzles whose answer is unique.
public struct BalanceLogicEngine: GameEngine {
    public struct Object: Equatable, Sendable {
        public let symbol: String
        public let nameKey: String
        public let colorIndex: Int
    }

    /// "lhs is heavier than rhs" — phrased as heavier or lighter in the UI.
    public struct Clue: Equatable, Sendable {
        public let heavier: Int
        public let lighter: Int
        public let phrasedAsLighter: Bool
    }

    public enum Question: String, Equatable, Sendable {
        case heaviest, lightest, secondHeaviest
        public var key: String { "balance.q.\(rawValue)" }
    }

    public struct Puzzle: Equatable, Sendable {
        public let objects: [Object]
        public let clues: [Clue]
        public let question: Question
        public let answer: Int
        /// Show clues as balance scales instead of sentences.
        public let visualScales: Bool
    }

    public static let catalog: [Object] = [
        Object(symbol: "carrot.fill", nameKey: "obj.carrot", colorIndex: 2),
        Object(symbol: "basketball.fill", nameKey: "obj.ball", colorIndex: 2),
        Object(symbol: "shippingbox.fill", nameKey: "obj.box", colorIndex: 2),
        Object(symbol: "bell.fill", nameKey: "obj.bell", colorIndex: 2),
        Object(symbol: "star.fill", nameKey: "obj.star", colorIndex: 2),
        Object(symbol: "heart.fill", nameKey: "obj.heart", colorIndex: 3),
        Object(symbol: "book.closed.fill", nameKey: "obj.book", colorIndex: 0),
        Object(symbol: "cup.and.saucer.fill", nameKey: "obj.cup", colorIndex: 1)
    ]

    public let gameID = GameID.balanceLogic
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var puzzle: Puzzle?
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 6 : 4 }
    public var objectCount: Int { [3, 3, 4, 4, 5, 5, 5, 6, 6, 6][level - 1] }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    @discardableResult
    public mutating func startRound() -> Puzzle {
        while true {
            let p = BalanceLogicEngine.generate(level: level, count: objectCount, rng: &rng)
            if BalanceLogicEngine.solve(p) == p.answer {
                puzzle = p
                return p
            }
        }
    }

    @discardableResult
    public mutating func answer(objectIndex: Int, responseTime: Double?) -> AnswerResult {
        guard let p = puzzle else { return .wrong }
        let isCorrect = objectIndex == p.answer
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect { rawScore += Int((Double(20 + 4 * objectCount) * levelMultiplier).rounded()) }
        roundsPlayed += 1
        puzzle = nil
        return isCorrect ? .correct : .wrong
    }

    static func generate(level: Int, count: Int, rng: inout AnyRNG) -> Puzzle {
        let objects = catalog.randomSample(count, using: &rng)
        // order[0] is heaviest.
        let order = Array(0..<count).shuffled(using: &rng)
        var clues: [Clue] = []
        for i in 0..<(count - 1) {
            clues.append(Clue(heavier: order[i], lighter: order[i + 1],
                              phrasedAsLighter: level >= 3 && Bool.random(using: &rng)))
        }
        // Redundant transitive clues add noise without changing the answer.
        let extras = level >= 8 ? 2 : level >= 5 ? 1 : 0
        var added = 0
        var guardCount = 0
        while added < extras && guardCount < 50 && count >= 3 {
            guardCount += 1
            let i = Int.random(in: 0..<(count - 2), using: &rng)
            let j = Int.random(in: (i + 2)..<count, using: &rng)
            let c = Clue(heavier: order[i], lighter: order[j], phrasedAsLighter: Bool.random(using: &rng))
            if !clues.contains(where: { $0.heavier == c.heavier && $0.lighter == c.lighter }) {
                clues.append(c)
                added += 1
            }
        }
        clues.shuffle(using: &rng)

        let question: Question
        switch level {
        case 1...2: question = .heaviest
        case 3...6: question = Bool.random(using: &rng) ? .heaviest : .lightest
        default: question = [.heaviest, .lightest, .secondHeaviest].randomElement(using: &rng)!
        }
        let answer: Int
        switch question {
        case .heaviest: answer = order[0]
        case .lightest: answer = order[count - 1]
        case .secondHeaviest: answer = order[1]
        }
        return Puzzle(objects: objects, clues: clues, question: question, answer: answer, visualScales: level >= 4)
    }

    /// Derives the answer from the clues alone (transitive closure). Returns nil if the
    /// clues don't single out exactly one object for the question.
    public static func solve(_ p: Puzzle) -> Int? {
        let n = p.objects.count
        var heavier = Array(repeating: Array(repeating: false, count: n), count: n) // heavier[a][b]: a > b
        for c in p.clues { heavier[c.heavier][c.lighter] = true }
        for k in 0..<n { for i in 0..<n { for j in 0..<n where heavier[i][k] && heavier[k][j] { heavier[i][j] = true } } }
        // Contradiction check.
        for i in 0..<n where heavier[i][i] { return nil }
        func beats(_ i: Int) -> Int { (0..<n).filter { heavier[i][$0] }.count }
        func beatenBy(_ i: Int) -> Int { (0..<n).filter { heavier[$0][i] }.count }
        let candidates: [Int]
        switch p.question {
        case .heaviest: candidates = (0..<n).filter { beats($0) == n - 1 }
        case .lightest: candidates = (0..<n).filter { beatenBy($0) == n - 1 }
        case .secondHeaviest: candidates = (0..<n).filter { beatenBy($0) == 1 && beats($0) == n - 2 }
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}

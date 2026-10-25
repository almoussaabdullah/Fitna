import Foundation

/// الرقم المفقود — find the missing term of a number sequence.
///
/// Sequences come from simple rule families. Before a puzzle is used, every option is
/// substituted into the gap and checked against *all* rule families; exactly one option
/// (the answer) may produce a sequence that follows any family. This rules out
/// sequences with several plausible answers among the choices.
public struct MissingNumberEngine: GameEngine {
    public enum Family: String, CaseIterable, Sendable {
        case arithmetic       // +d
        case geometric        // ×r
        case quadratic        // differences grow by a constant (3, 6, 11, 18 …)
        case interleaved      // two arithmetic sequences alternating
        case fibonacci        // each term is the sum of the previous two
        case multiplyAdd      // ×r then +c
    }

    public struct Puzzle: Equatable, Sendable {
        public let terms: [Int]        // full sequence
        public let missingIndex: Int
        public let options: [Int]      // includes the answer exactly once
        public let family: Family
        public var answer: Int { terms[missingIndex] }
    }

    public let gameID = GameID.missingNumber
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

    public var totalRounds: Int { length == .standard ? 8 : 5 }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    public static func families(level: Int) -> [Family] {
        switch Difficulty.clamp(level) {
        case 1: return [.arithmetic]
        case 2: return [.arithmetic, .geometric]
        case 3...4: return [.arithmetic, .geometric, .quadratic]
        case 5: return [.geometric, .quadratic, .interleaved]
        case 6: return [.quadratic, .interleaved, .fibonacci]
        default: return [.quadratic, .interleaved, .fibonacci, .multiplyAdd]
        }
    }

    @discardableResult
    public mutating func startRound() -> Puzzle {
        while true {
            if let p = MissingNumberEngine.generate(level: level, rng: &rng), MissingNumberEngine.isValid(p) {
                puzzle = p
                return p
            }
        }
    }

    @discardableResult
    public mutating func answer(_ value: Int, responseTime: Double?) -> AnswerResult {
        guard let p = puzzle else { return .wrong }
        let isCorrect = value == p.answer
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect { rawScore += Int((Double(20 + 3 * level) * levelMultiplier).rounded()) }
        roundsPlayed += 1
        puzzle = nil
        return isCorrect ? .correct : .wrong
    }

    // MARK: Generation

    static func generate(level: Int, rng: inout AnyRNG) -> Puzzle? {
        let family = families(level: level).randomElement(using: &rng)!
        let big = level >= 6
        var terms: [Int] = []
        var count = 6
        switch family {
        case .arithmetic:
            let start = Int.random(in: 1...(big ? 50 : 20), using: &rng)
            let step = Int.random(in: 2...(level >= 3 ? 15 : 9), using: &rng) * (level >= 3 && Bool.random(using: &rng) ? -1 : 1)
            terms = (0..<count).map { start + step * $0 }
        case .geometric:
            let ratio = Int.random(in: 2...3, using: &rng)
            let start = Int.random(in: 1...(ratio == 2 ? 6 : 3), using: &rng)
            count = 5
            terms = (0..<count).map { start * Int(pow(Double(ratio), Double($0))) }
        case .quadratic:
            let start = Int.random(in: 1...20, using: &rng)
            let firstDiff = Int.random(in: 1...6, using: &rng)
            let growth = Int.random(in: 1...(level >= 6 ? 4 : 3), using: &rng)
            terms = [start]
            for i in 1..<count { terms.append(terms[i - 1] + firstDiff + growth * (i - 1)) }
        case .interleaved:
            count = 8
            let a0 = Int.random(in: 1...20, using: &rng), da = Int.random(in: 1...5, using: &rng)
            let b0 = Int.random(in: 20...60, using: &rng), db = Int.random(in: 2...10, using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
            terms = (0..<count).map { $0 % 2 == 0 ? a0 + da * ($0 / 2) : b0 + db * ($0 / 2) }
        case .fibonacci:
            let a = Int.random(in: 1...6, using: &rng), b = Int.random(in: 1...8, using: &rng)
            terms = [a, b]
            for i in 2..<count { terms.append(terms[i - 1] + terms[i - 2]) }
        case .multiplyAdd:
            let r = 2, c = Int.random(in: -3...4, using: &rng)
            guard c != 0 else { return nil }
            terms = [Int.random(in: 1...6, using: &rng)]
            for i in 1..<count { terms.append(terms[i - 1] * r + c) }
        }
        guard terms.allSatisfy({ $0 >= 0 && $0 < 10_000 }) else { return nil }

        // Gap: last term at low levels, any non-initial term later (interior gaps need neighbours).
        let missingIndex: Int
        if level <= 4 {
            missingIndex = count - 1
        } else {
            let lowest = family == .fibonacci || family == .multiplyAdd || family == .quadratic ? 3 : 2
            missingIndex = Int.random(in: lowest...(count - 1), using: &rng)
        }
        let answer = terms[missingIndex]

        // Plausible distractors: near misses and common rule slips.
        var pool: [Int] = []
        let prev = terms[missingIndex - 1]
        let diff = prev - terms[missingIndex - 2]
        pool += [answer + 1, answer - 1, answer + 2, answer - 2, prev + diff, answer + diff, answer - diff,
                 answer + 10, answer - 10, prev * 2, answer + 3, answer - 3]
        let distractors = pool.filter { $0 >= 0 && $0 != answer }.uniqued().shuffled(using: &rng).prefix(3)
        guard distractors.count == 3 else { return nil }
        let options = (Array(distractors) + [answer]).shuffled(using: &rng)
        return Puzzle(terms: terms, missingIndex: missingIndex, options: options, family: family)
    }

    /// Exactly one option must make the sequence follow some known family.
    public static func isValid(_ p: Puzzle) -> Bool {
        guard p.options.filter({ $0 == p.answer }).count == 1, Set(p.options).count == p.options.count else { return false }
        let fitting = p.options.filter { option in
            var seq = p.terms
            seq[p.missingIndex] = option
            return Family.allCases.contains { follows(seq, $0) }
        }
        return fitting == [p.answer]
    }

    /// Whether a complete sequence follows a family.
    public static func follows(_ s: [Int], _ family: Family) -> Bool {
        guard s.count >= 4 else { return false }
        let d = zip(s.dropFirst(), s).map { $0 - $1 }
        switch family {
        case .arithmetic:
            return Set(d).count == 1
        case .geometric:
            guard s.allSatisfy({ $0 != 0 }) else { return false }
            let r = s[1] / s[0]
            guard r >= 2 else { return false }
            return zip(s.dropFirst(), s).allSatisfy { $0 == $1 * r }
        case .quadratic:
            let d2 = zip(d.dropFirst(), d).map { $0 - $1 }
            return Set(d2).count == 1
        case .interleaved:
            guard s.count >= 6 else { return false }
            let even = stride(from: 0, to: s.count, by: 2).map { s[$0] }
            let odd = stride(from: 1, to: s.count, by: 2).map { s[$0] }
            return isArithmetic(even) && isArithmetic(odd)
        case .fibonacci:
            return (2..<s.count).allSatisfy { s[$0] == s[$0 - 1] + s[$0 - 2] }
        case .multiplyAdd:
            for r in 2...3 {
                let c = s[1] - s[0] * r
                if (1..<s.count).allSatisfy({ s[$0] == s[$0 - 1] * r + c }) { return true }
            }
            return false
        }
    }

    private static func isArithmetic(_ s: [Int]) -> Bool {
        guard s.count >= 3 else { return false }
        return Set(zip(s.dropFirst(), s).map { $0 - $1 }).count == 1
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

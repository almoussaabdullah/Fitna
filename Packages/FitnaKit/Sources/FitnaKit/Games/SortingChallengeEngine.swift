import Foundation

/// ترتيب الفوضى — tap scattered items in the order the rule demands.
///
/// Rules: ascending numbers, descending numbers, Arabic alphabetical order, and
/// alternating colors (ascending within each color, starting with a given color).
/// From level 5 the rule changes between rounds. Wrong taps count as errors but
/// don't advance, so every round ends with the full correct order.
public struct SortingChallengeEngine: GameEngine {
    public enum Rule: String, CaseIterable, Sendable {
        case ascending, descending, alphabetical, alternatingColors
        public var key: String { "sort.rule.\(rawValue)" }
    }

    public struct Item: Identifiable, Equatable, Sendable {
        public let id: Int
        /// Number value, or the letter's alphabet index for `alphabetical`.
        public let value: Int
        public let label: String
        /// 0 or 1 for `alternatingColors`, otherwise 0.
        public let colorGroup: Int
    }

    public struct Round: Equatable, Sendable {
        public let rule: Rule
        public let items: [Item]
        public let expectedOrder: [Int]   // item ids
        /// Color group to start with for `alternatingColors`.
        public let startGroup: Int
    }

    /// Arabic alphabet in standard (hijā'ī) order.
    public static let arabicLetters: [String] = ["ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر", "ز", "س", "ش", "ص",
                                                 "ض", "ط", "ظ", "ع", "غ", "ف", "ق", "ك", "ل", "م", "ن", "ه", "و", "ي"]

    public let gameID = GameID.sortingChallenge
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var round: Round?
    public private(set) var progress = 0   // how many items are already tapped correctly this round
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG
    private var fixedRule: Rule?

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        var rng = rng
        self.level = Difficulty.clamp(level)
        self.length = length
        if level < 5 { fixedRule = SortingChallengeEngine.availableRules(level: level).randomElement(using: &rng) }
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 6 : 4 }
    public var itemCount: Int { min(9, 4 + level / 2) }
    public var changesRuleEachRound: Bool { level >= 5 }
    public var isFinished: Bool { roundsPlayed >= totalRounds }
    public var tappedIDs: [Int] { round.map { Array($0.expectedOrder.prefix(progress)) } ?? [] }

    public static func availableRules(level: Int) -> [Rule] {
        switch Difficulty.clamp(level) {
        case 1...2: return [.ascending]
        case 3: return [.ascending, .descending]
        case 4...5: return [.ascending, .descending, .alphabetical]
        default: return Rule.allCases
        }
    }

    @discardableResult
    public mutating func startRound() -> Round {
        let rules = SortingChallengeEngine.availableRules(level: level)
        var rule = fixedRule ?? rules.randomElement(using: &rng)!
        // When rules change, avoid repeating the previous round's rule.
        if changesRuleEachRound, let prev = round?.rule ?? lastRule, rules.count > 1, rule == prev {
            rule = rules.filter { $0 != prev }.randomElement(using: &rng)!
        }
        let r = SortingChallengeEngine.makeRound(rule: rule, count: itemCount, level: level, rng: &rng)
        round = r
        lastRule = rule
        progress = 0
        return r
    }
    private var lastRule: Rule?

    /// Returns `.correct` when the tapped item is the next in order.
    @discardableResult
    public mutating func tap(itemID: Int, responseTime: Double?) -> AnswerResult {
        guard let r = round, progress < r.expectedOrder.count else { return .wrong }
        let isCorrect = r.expectedOrder[progress] == itemID
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect {
            progress += 1
            rawScore += Int((Double(5 + level) * levelMultiplier).rounded())
            if progress == r.expectedOrder.count {
                roundsPlayed += 1
                rawScore += 10 * level
            }
        }
        return isCorrect ? .correct : .wrong
    }

    public var roundComplete: Bool {
        guard let r = round else { return false }
        return progress == r.expectedOrder.count
    }

    static func makeRound(rule: Rule, count: Int, level: Int, rng: inout AnyRNG) -> Round {
        let maxValue = level <= 2 ? 20 : level <= 5 ? 60 : 99
        switch rule {
        case .ascending, .descending:
            // Higher levels use tighter clusters of close numbers.
            let span = max(count + 2, Int(levelLerp(level, from: Double(maxValue), to: Double(count * 3))))
            let low = Int.random(in: 1...max(1, maxValue - span), using: &rng)
            let values = Array(low...(low + span)).randomSample(count, using: &rng)
            let items = values.enumerated().map { Item(id: $0.offset, value: $0.element, label: String($0.element), colorGroup: 0) }
            let sorted = items.sorted { rule == .ascending ? $0.value < $1.value : $0.value > $1.value }
            return Round(rule: rule, items: items.shuffled(using: &rng), expectedOrder: sorted.map(\.id), startGroup: 0)
        case .alphabetical:
            let indices = Array(arabicLetters.indices).randomSample(count, using: &rng)
            let items = indices.enumerated().map { Item(id: $0.offset, value: $0.element, label: arabicLetters[$0.element], colorGroup: 0) }
            let sorted = items.sorted { $0.value < $1.value }
            return Round(rule: rule, items: items.shuffled(using: &rng), expectedOrder: sorted.map(\.id), startGroup: 0)
        case .alternatingColors:
            let start = Int.random(in: 0...1, using: &rng)
            let firstCount = (count + 1) / 2
            let secondCount = count / 2
            let values = Array(1...maxValue).randomSample(count, using: &rng)
            var items: [Item] = []
            for (i, v) in values.enumerated() {
                let group = i < firstCount ? start : 1 - start
                items.append(Item(id: i, value: v, label: String(v), colorGroup: group))
            }
            let a = items.filter { $0.colorGroup == start }.sorted { $0.value < $1.value }
            let b = items.filter { $0.colorGroup != start }.sorted { $0.value < $1.value }
            var order: [Int] = []
            for i in 0..<max(firstCount, secondCount) {
                if i < a.count { order.append(a[i].id) }
                if i < b.count { order.append(b[i].id) }
            }
            return Round(rule: rule, items: items.shuffled(using: &rng), expectedOrder: order, startGroup: start)
        }
    }
}

import Foundation

/// تطابق البطاقات — classic pairs memory game.
///
/// Accuracy counts *memory* errors only (see `wasAvoidable`): unavoidable first-look
/// mismatches are free, so a flawless memory scores 100%.
/// Pairs left when time runs out count as errors.
public struct CardMatchingEngine: GameEngine {
    public enum CardState: Equatable, Sendable { case hidden, revealed, matched }

    public struct Card: Identifiable, Equatable, Sendable {
        public let id: Int
        /// Index into the symbol pool; both cards of a pair share it.
        public let face: Int
        public var state: CardState
    }

    public enum FlipResult: Equatable, Sendable {
        case ignored
        case firstCard
        case match(Int, Int)
        case mismatch(Int, Int)
    }

    public let gameID = GameID.cardMatching
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var cards: [Card]
    public private(set) var moves = 0
    public private(set) var timedOut = false
    private var firstIndex: Int?
    private var pendingMismatch: (Int, Int)?
    private var seen: Set<Int> = []

    public static let facePoolSize = 16

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        var rng = rng
        self.level = Difficulty.clamp(level)
        self.length = length
        let pairs = CardMatchingEngine.pairCount(level: level, length: length)
        let faces = Array(0..<CardMatchingEngine.facePoolSize).randomSample(pairs, using: &rng)
        let deck = (faces + faces).shuffled(using: &rng)
        cards = deck.enumerated().map { Card(id: $0.offset, face: $0.element, state: .hidden) }
    }

    public static func pairCount(level: Int, length: SessionLength) -> Int {
        let table = [3, 4, 6, 6, 8, 8, 10, 10, 12, 12]
        let base = table[Difficulty.clamp(level) - 1]
        return length == .standard ? base : max(3, base - 2)
    }

    public var pairCount: Int { cards.count / 2 }

    /// Grid columns that keep cards large on a phone.
    public var columns: Int { cards.count <= 6 ? 3 : 4 }

    /// Total time allowed for the board.
    public var timeLimit: Double { Double(pairCount) * levelLerp(level, from: 7.0, to: 3.5) + 4 }

    public var matchedPairs: Int { cards.filter { $0.state == .matched }.count / 2 }
    public var isFinished: Bool { timedOut || matchedPairs == pairCount }
    public var isWaitingToHide: Bool { pendingMismatch != nil }

    public mutating func flip(_ index: Int) -> FlipResult {
        guard !isFinished, pendingMismatch == nil, cards.indices.contains(index), cards[index].state == .hidden else {
            return .ignored
        }
        cards[index].state = .revealed
        guard let first = firstIndex else {
            firstIndex = index
            return .firstCard
        }
        firstIndex = nil
        moves += 1
        if cards[first].face == cards[index].face {
            cards[first].state = .matched
            cards[index].state = .matched
            tally.record(correct: true, responseTime: nil)
            rawScore += Int((20 * levelMultiplier).rounded())
            seen.insert(first); seen.insert(index)
            return .match(first, index)
        }
        if wasAvoidable(first, index) {
            tally.record(correct: false, responseTime: nil)
        }
        seen.insert(first); seen.insert(index)
        pendingMismatch = (first, index)
        return .mismatch(first, index)
    }

    /// Hides a mismatched pair (called by the view after a short reveal).
    public mutating func hideMismatch() {
        guard let (a, b) = pendingMismatch else { return }
        if cards[a].state == .revealed { cards[a].state = .hidden }
        if cards[b].state == .revealed { cards[b].state = .hidden }
        pendingMismatch = nil
    }

    /// Ends the board when the timer expires; unmatched pairs count as errors.
    public mutating func timeUp() {
        guard !isFinished else { return }
        let remaining = pairCount - matchedPairs
        for _ in 0..<remaining { tally.record(correct: false, responseTime: nil) }
        timedOut = true
    }

    /// Adds the time bonus once the board is cleared.
    public mutating func applyTimeBonus(secondsRemaining: Double) {
        guard matchedPairs == pairCount, secondsRemaining > 0 else { return }
        rawScore += Int(secondsRemaining.rounded(.down)) * 2
    }

    /// A mismatch is a memory error when the player had the information to avoid it:
    /// the first card's partner had already been seen (they should have picked it), or the
    /// second card had already been seen (they deliberately picked a known non-match).
    /// Discovering a brand-new second card is never an error.
    private func wasAvoidable(_ first: Int, _ second: Int) -> Bool {
        let firstPartnerSeen = cards.indices.contains { $0 != first && cards[$0].face == cards[first].face && seen.contains($0) }
        return firstPartnerSeen || seen.contains(second)
    }
}

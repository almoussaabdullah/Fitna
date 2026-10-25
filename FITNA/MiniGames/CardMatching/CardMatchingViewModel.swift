import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class CardMatchingViewModel: GameViewModel {
    private(set) var engine: CardMatchingEngine
    private let clock: GameClock
    private var startedAt: Double = 0
    private var hideAt: Double?
    private(set) var lastMatch: [Int] = []
    private(set) var lastMismatch: [Int] = []
    private var finishedAt: Double?

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = CardMatchingEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    /// Small delay after the last match so the final flip is visible.
    var isFinished: Bool {
        guard engine.isFinished, let f = finishedAt else { return false }
        return clock.now - f > 0.6
    }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { "\(engine.matchedPairs) / \(engine.pairCount)" }
    var hudTimeFraction: Double? { max(0, 1 - (clock.now - startedAt) / engine.timeLimit) }
    var cards: [CardMatchingEngine.Card] { engine.cards }
    var columns: Int { engine.columns }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() { startedAt = clock.now }

    func tick() {
        let now = clock.now
        if let h = hideAt, now >= h {
            engine.hideMismatch()
            lastMismatch = []
            hideAt = nil
        }
        if !engine.isFinished && now - startedAt >= engine.timeLimit {
            engine.timeUp()
            Feedback.wrong()
        }
        if engine.isFinished && finishedAt == nil { finishedAt = now }
    }

    func flip(_ index: Int) {
        // A tap while a mismatch is showing hides it immediately (keeps the pace snappy).
        if hideAt != nil {
            engine.hideMismatch()
            lastMismatch = []
            hideAt = nil
        }
        switch engine.flip(index) {
        case .ignored:
            break
        case .firstCard:
            Feedback.flip()
        case .match(let a, let b):
            lastMatch = [a, b]
            Feedback.correct()
            if engine.matchedPairs == engine.pairCount {
                engine.applyTimeBonus(secondsRemaining: engine.timeLimit - (clock.now - startedAt))
            }
        case .mismatch(let a, let b):
            lastMismatch = [a, b]
            Feedback.flip()
            hideAt = clock.now + 0.8
        }
    }
}

import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class ValueComparisonViewModel: GameViewModel {
    private(set) var engine: ValueComparisonEngine
    private let clock: GameClock
    private var shownAt: Double = 0
    /// The pair just answered, kept on screen briefly with the result.
    private(set) var reveal: (pair: ValueComparisonEngine.Pair, chosen: ValueComparisonEngine.Side?, correct: Bool)?
    private var revealUntil: Double = 0
    private(set) var pairCounter = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = ValueComparisonEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished && reveal == nil }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.trialsPlayed, engine.totalTrials) }
    /// Per-pair timer.
    var hudTimeFraction: Double? {
        guard reveal == nil else { return 0 }
        return max(0, 1 - (clock.now - shownAt) / engine.trialTimeLimit)
    }
    var displayedPair: ValueComparisonEngine.Pair { reveal?.pair ?? engine.pair }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() { shownAt = clock.now }

    func tick() {
        let now = clock.now
        if reveal != nil {
            if now >= revealUntil {
                reveal = nil
                shownAt = now
                pairCounter += 1
            }
            return
        }
        if !engine.isFinished && now - shownAt >= engine.trialTimeLimit {
            let pair = engine.pair
            engine.timeout()
            Feedback.wrong()
            reveal = (pair, nil, false)
            revealUntil = now + 1.0
        }
    }

    func choose(_ side: ValueComparisonEngine.Side) {
        guard reveal == nil, !engine.isFinished else { return }
        let pair = engine.pair
        let r = engine.choose(side, responseTime: clock.now - shownAt)
        if r == .correct { Feedback.correct() } else { Feedback.wrong() }
        reveal = (pair, side, r == .correct)
        revealUntil = clock.now + (r == .correct ? 0.35 : 1.1)
    }
}

import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class OddOneOutViewModel: GameViewModel {
    private(set) var engine: OddOneOutEngine
    private let clock: GameClock
    private(set) var round: OddOneOutEngine.Round?
    private(set) var revealed: (round: OddOneOutEngine.Round, tapped: Int?)?
    private var roundStartedAt: Double = 0
    private var revealUntil: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = OddOneOutEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished && revealed == nil }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.roundsPlayed, engine.totalRounds) }
    /// Per-round timer.
    var hudTimeFraction: Double? {
        guard round != nil else { return 0 }
        return max(0, 1 - (clock.now - roundStartedAt) / engine.roundTimeLimit)
    }

    /// The grid currently on screen (live round or the one being revealed).
    var displayed: OddOneOutEngine.Round? { revealed?.round ?? round }

    func begin() { nextRound() }

    func tick() {
        let now = clock.now
        if revealed != nil {
            if now >= revealUntil {
                revealed = nil
                if !engine.isFinished { nextRound() }
            }
            return
        }
        if let r = round, now - roundStartedAt >= engine.roundTimeLimit {
            engine.timeout()
            Feedback.wrong()
            reveal(r, tapped: nil, correct: false)
        }
    }

    func tap(_ cell: Int) {
        guard let r = round, revealed == nil else { return }
        let result = engine.tap(cell: cell, responseTime: clock.now - roundStartedAt)
        if result == .correct { Feedback.correct() } else { Feedback.wrong() }
        reveal(r, tapped: cell, correct: result == .correct)
    }

    private func reveal(_ r: OddOneOutEngine.Round, tapped: Int?, correct: Bool) {
        round = nil
        revealed = (r, tapped)
        revealUntil = clock.now + (correct ? 0.35 : 1.1)
    }

    private func nextRound() {
        round = engine.startRound()
        roundStartedAt = clock.now
    }
}

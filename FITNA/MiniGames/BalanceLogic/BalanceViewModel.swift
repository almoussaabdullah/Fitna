import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class BalanceViewModel: GameViewModel {
    private(set) var engine: BalanceLogicEngine
    private let clock: GameClock
    private(set) var puzzle: BalanceLogicEngine.Puzzle?
    private(set) var feedback: (chosen: Int, correct: Bool)?
    private var feedbackUntil: Double = 0
    private var shownAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = BalanceLogicEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished && feedback == nil }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.roundsPlayed, engine.totalRounds) }
    var hudTimeFraction: Double? { nil }
    var isRevealing: Bool { feedback != nil }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() { next() }

    func tick() {
        if feedback != nil && clock.now >= feedbackUntil {
            feedback = nil
            if !engine.isFinished { next() }
        }
    }

    func choose(_ objectIndex: Int) {
        guard feedback == nil, puzzle != nil else { return }
        let r = engine.answer(objectIndex: objectIndex, responseTime: clock.now - shownAt)
        if r == .correct { Feedback.correct() } else { Feedback.wrong() }
        feedback = (objectIndex, r == .correct)
        feedbackUntil = clock.now + (r == .correct ? 0.9 : 2.0)
    }

    private func next() {
        puzzle = engine.startRound()
        shownAt = clock.now
    }
}

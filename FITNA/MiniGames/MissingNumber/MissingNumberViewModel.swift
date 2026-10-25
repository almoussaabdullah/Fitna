import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class MissingNumberViewModel: GameViewModel {
    private(set) var engine: MissingNumberEngine
    private let clock: GameClock
    private(set) var puzzle: MissingNumberEngine.Puzzle?
    private(set) var feedback: (chosen: Int, correct: Bool)?
    private var feedbackUntil: Double = 0
    private var shownAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = MissingNumberEngine(level: level, length: length)
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

    func choose(_ value: Int) {
        guard feedback == nil, puzzle != nil else { return }
        let r = engine.answer(value, responseTime: clock.now - shownAt)
        if r == .correct { Feedback.correct() } else { Feedback.wrong() }
        feedback = (value, r == .correct)
        feedbackUntil = clock.now + (r == .correct ? 0.8 : 1.8)
    }

    private func next() {
        puzzle = engine.startRound()
        shownAt = clock.now
    }
}

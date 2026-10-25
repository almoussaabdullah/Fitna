import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class PatternViewModel: GameViewModel {
    private(set) var engine: PatternCompletionEngine
    private let clock: GameClock
    private(set) var puzzle: PatternCompletionEngine.Puzzle?
    private(set) var feedback: (chosen: Int, correct: Bool)?
    private var feedbackUntil: Double = 0
    private var shownAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = PatternCompletionEngine(level: level, length: length)
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

    func begin() { next() }

    func tick() {
        if feedback != nil && clock.now >= feedbackUntil {
            feedback = nil
            if !engine.isFinished { next() }
        }
    }

    func choose(_ index: Int) {
        guard feedback == nil, puzzle != nil else { return }
        let r = engine.answer(optionIndex: index, responseTime: clock.now - shownAt)
        if r == .correct { Feedback.correct() } else { Feedback.wrong() }
        feedback = (index, r == .correct)
        feedbackUntil = clock.now + (r == .correct ? 0.8 : 1.8)
    }

    private func next() {
        puzzle = engine.startRound()
        shownAt = clock.now
    }
}

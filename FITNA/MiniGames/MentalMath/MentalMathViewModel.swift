import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class MentalMathViewModel: GameViewModel {
    private(set) var engine: MentalMathEngine
    private let clock: GameClock
    private var startedAt: Double = 0
    private var questionShownAt: Double = 0
    private var penalties: Double = 0
    private(set) var input = ""
    private(set) var flash: AnswerFlash = .none
    private var flashUntil: Double = 0
    /// Last question with its correct answer, shown briefly after a mistake.
    private(set) var lastMistake: String?

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = MentalMathEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { nil }
    var hudTimeFraction: Double? { max(0, 1 - elapsed / engine.sessionDuration) }
    var question: MathExpression { engine.current }
    var answeredCount: Int { engine.tally.attempts }
    var correctCount: Int { engine.tally.correct }

    private var elapsed: Double { clock.now - startedAt + penalties }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() {
        startedAt = clock.now
        questionShownAt = clock.now
    }

    func tick() {
        if flash != .none && clock.now >= flashUntil { flash = .none }
        if !engine.isFinished && elapsed >= engine.sessionDuration { engine.timeUp() }
    }

    func press(_ digit: Int) {
        guard !engine.isFinished, input.count < 6 else { return }
        if input == "0" { input = "" }
        input.append(String(digit))
        Feedback.tap()
        evaluate()
    }

    func deleteLast() {
        guard !input.isEmpty else { return }
        input.removeLast()
        Feedback.tap()
    }

    private func evaluate() {
        switch engine.evaluate(input) {
        case .incomplete:
            return
        case .correct:
            engine.commit(input, responseTime: clock.now - questionShownAt)
            Feedback.correct()
            show(.correct)
            lastMistake = nil
        case .wrong:
            let q = engine.current
            lastMistake = "\(q.text) = \(q.value)"
            engine.commit(input, responseTime: clock.now - questionShownAt)
            penalties += engine.penaltySeconds
            Feedback.wrong()
            show(.wrong)
        }
        input = ""
        questionShownAt = clock.now
    }

    private func show(_ f: AnswerFlash) {
        flash = f
        flashUntil = clock.now + (f == .wrong ? 1.2 : 0.45)
    }
}

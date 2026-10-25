import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class StroopViewModel: GameViewModel {
    private(set) var engine: StroopEngine
    private let clock: GameClock
    private var startedAt: Double = 0
    private var stimulusShownAt: Double = 0
    private(set) var flash: AnswerFlash = .none
    private var flashUntil: Double = 0
    private(set) var stimulusCount = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = StroopEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { nil }
    var hudTimeFraction: Double? { max(0, 1 - (clock.now - startedAt) / engine.sessionDuration) }
    var stimulus: StroopEngine.Stimulus { engine.stimulus }
    var streak: Int { engine.tally.streak }

    /// Fraction of the per-stimulus time left.
    var stimulusFraction: Double {
        max(0, 1 - (clock.now - stimulusShownAt) / engine.stimulusTimeLimit)
    }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() {
        startedAt = clock.now
        stimulusShownAt = clock.now
    }

    func tick() {
        let now = clock.now
        if flash != .none && now >= flashUntil { flash = .none }
        if engine.isFinished { return }
        if now - startedAt >= engine.sessionDuration {
            engine.timeUp()
            return
        }
        if now - stimulusShownAt >= engine.stimulusTimeLimit {
            engine.stimulusTimedOut()
            Feedback.wrong()
            show(.wrong)
            next()
        }
    }

    func answer(_ color: StroopEngine.InkColor) {
        guard !engine.isFinished else { return }
        let r = engine.answer(color, responseTime: clock.now - stimulusShownAt)
        if r == .correct { Feedback.correct() } else { Feedback.wrong() }
        show(r == .correct ? .correct : .wrong)
        next()
    }

    private func next() {
        stimulusShownAt = clock.now
        stimulusCount += 1
    }

    private func show(_ f: AnswerFlash) {
        flash = f
        flashUntil = clock.now + 0.35
    }
}

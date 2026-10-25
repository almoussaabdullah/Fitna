import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class NumberMemoryViewModel: GameViewModel {
    enum Phase: Equatable {
        case showing(until: Double)
        case input
        case feedback(until: Double)
    }

    private(set) var engine: NumberMemoryEngine
    private let clock: GameClock
    private(set) var phase: Phase = .input
    private(set) var sequence: [Int] = []
    private(set) var entered: [Int] = []
    private(set) var flash: AnswerFlash = .none
    private var inputStartedAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = NumberMemoryEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished && !isShowingFeedback }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.trialsPlayed, engine.maxTrials) }
    var hudTimeFraction: Double? { nil }
    var mistakesLeft: Int { engine.maxMistakes - engine.mistakes }

    var isShowingFeedback: Bool {
        if case .feedback = phase { return true }
        return false
    }

    var isShowing: Bool {
        if case .showing = phase { return true }
        return false
    }

    /// Fraction of display time remaining (for the reveal bar).
    var showFraction: Double {
        guard case .showing(let until) = phase else { return 0 }
        return max(0, (until - clock.now) / engine.displayDuration)
    }

    func begin() { nextTrial() }

    func tick() {
        let now = clock.now
        switch phase {
        case .showing(let until) where now >= until:
            phase = .input
            inputStartedAt = now
        case .feedback(let until) where now >= until:
            flash = .none
            if !engine.isFinished { nextTrial() } else { phase = .input }
        default:
            break
        }
    }

    func press(_ digit: Int) {
        guard phase == .input, entered.count < sequence.count else { return }
        Feedback.tap()
        entered.append(digit)
        if entered.count == sequence.count { submit() }
    }

    func deleteLast() {
        guard phase == .input, !entered.isEmpty else { return }
        entered.removeLast()
        Feedback.tap()
    }

    private func submit() {
        let result = engine.submit(entered, responseTime: clock.now - inputStartedAt)
        flash = result == .correct ? .correct : .wrong
        if result == .correct { Feedback.correct() } else { Feedback.wrong() }
        phase = .feedback(until: clock.now + (result == .correct ? 0.8 : 1.6))
    }

    private func nextTrial() {
        entered = []
        sequence = engine.startTrial()
        phase = .showing(until: clock.now + engine.displayDuration)
    }
}

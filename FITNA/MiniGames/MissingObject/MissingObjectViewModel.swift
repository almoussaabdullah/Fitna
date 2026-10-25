import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class MissingObjectViewModel: GameViewModel {
    enum Phase: Equatable {
        case memorize(until: Double)
        case blank(until: Double)
        case choose
        case feedback(until: Double, chosen: Int)
    }

    private(set) var engine: MissingObjectEngine
    private let clock: GameClock
    private(set) var phase: Phase = .choose
    private(set) var round: MissingObjectEngine.Round?
    private(set) var lastCorrect = false
    private var chooseStartedAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = MissingObjectEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool {
        if case .feedback = phase { return false }
        return engine.isFinished
    }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.roundsPlayed, engine.totalRounds) }
    var hudTimeFraction: Double? { nil }

    var memorizeFraction: Double {
        guard case .memorize(let until) = phase else { return 0 }
        return max(0, (until - clock.now) / engine.memorizeDuration)
    }

    func begin() { nextRound() }

    func tick() {
        let now = clock.now
        switch phase {
        case .memorize(let until) where now >= until:
            phase = .blank(until: now + 0.5)
        case .blank(let until) where now >= until:
            phase = .choose
            chooseStartedAt = now
        case .feedback(let until, _) where now >= until:
            if !engine.isFinished { nextRound() } else { phase = .choose }
        default:
            break
        }
    }

    func choose(_ symbolIndex: Int) {
        guard phase == .choose, round != nil else { return }
        let result = engine.answer(symbolIndex: symbolIndex, responseTime: clock.now - chooseStartedAt)
        lastCorrect = result == .correct
        if lastCorrect { Feedback.correct() } else { Feedback.wrong() }
        phase = .feedback(until: clock.now + (lastCorrect ? 0.9 : 1.6), chosen: symbolIndex)
    }

    private func nextRound() {
        round = engine.startRound()
        phase = .memorize(until: clock.now + engine.memorizeDuration)
    }
}

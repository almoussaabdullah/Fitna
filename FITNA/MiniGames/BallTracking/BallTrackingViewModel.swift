import Foundation
import Observation
import SpriteKit
import FitnaKit

@Observable
@MainActor
final class BallTrackingViewModel: GameViewModel {
    enum Phase: Equatable {
        case showTarget(until: Double)
        case swapping(until: Double)
        case choose
        case feedback(until: Double)
    }

    private(set) var engine: BallTrackingEngine
    private let clock: GameClock
    @ObservationIgnored let scene: BallTrackingScene
    private(set) var phase: Phase = .choose
    private(set) var round: BallTrackingEngine.Round?
    private(set) var lastCorrect = false
    private var chooseStartedAt: Double = 0

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = BallTrackingEngine(level: level, length: length)
        self.clock = clock
        scene = BallTrackingScene(size: CGSize(width: 340, height: 340))
        scene.isUserInteractionEnabled = false
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
    var ballCount: Int { round?.ballCount ?? engine.ballCount }
    var isClockPaused: Bool { clock.isPaused }

    /// Keeps SpriteKit actions frozen while the game is paused.
    func syncPause() { scene.isPaused = clock.isPaused }

    func begin() { nextRound() }

    func tick() {
        syncPause()
        let now = clock.now
        switch phase {
        case .showTarget(let until) where now >= until:
            guard let r = round else { return }
            scene.hideTarget()
            let total = Double(r.swaps.count) * r.swapDuration
            scene.runSwaps(r.swaps.map { ($0.a, $0.b) }, duration: r.swapDuration)
            phase = .swapping(until: now + total + 0.15)
        case .swapping(let until) where now >= until:
            phase = .choose
            chooseStartedAt = now
        case .feedback(let until) where now >= until:
            if !engine.isFinished { nextRound() } else { phase = .choose }
        default:
            break
        }
    }

    func pick(_ slot: Int) {
        guard phase == .choose, let r = round else { return }
        let result = engine.pick(slot: slot, responseTime: clock.now - chooseStartedAt)
        lastCorrect = result == .correct
        if lastCorrect { Feedback.correct() } else { Feedback.wrong() }
        scene.reveal(correctSlot: r.targetFinalSlot, tappedSlot: slot)
        phase = .feedback(until: clock.now + (lastCorrect ? 1.0 : 1.8))
    }

    private func nextRound() {
        let r = engine.startRound()
        round = r
        scene.setUp(ballCount: r.ballCount)
        scene.showTarget(slot: r.targetStartSlot)
        Feedback.tick()
        phase = .showTarget(until: clock.now + 1.6)
    }
}

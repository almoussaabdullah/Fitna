import Foundation
import Observation
import FitnaKit

@Observable
@MainActor
final class SortingViewModel: GameViewModel {
    private(set) var engine: SortingChallengeEngine
    private let clock: GameClock
    private(set) var round: SortingChallengeEngine.Round?
    private(set) var wrongItemID: Int?
    private var wrongUntil: Double = 0
    private var lastTapAt: Double = 0
    private var roundDoneUntil: Double?
    private(set) var roundNumber = 0
    /// Small random offsets that make the layout look scattered.
    private(set) var jitter: [Int: CGSizeLike] = [:]

    struct CGSizeLike: Equatable { let dx: Double; let dy: Double }

    init(level: Int, length: SessionLength, clock: GameClock) {
        engine = SortingChallengeEngine(level: level, length: length)
        self.clock = clock
    }

    var gameID: GameID { engine.gameID }
    var level: Int { engine.level }
    var length: SessionLength { engine.length }
    var isFinished: Bool { engine.isFinished && roundDoneUntil == nil }
    var hudScore: Int { engine.rawScore }
    var hudProgress: String? { progressText(engine.roundsPlayed, engine.totalRounds) }
    var hudTimeFraction: Double? { nil }
    var tapped: Set<Int> { Set(engine.tappedIDs) }
    var ruleChanges: Bool { engine.changesRuleEachRound }

    func outcome(duration: Double, completed: Bool) -> SessionOutcome {
        engine.outcome(duration: duration, completed: completed)
    }

    func begin() { nextRound() }

    func tick() {
        let now = clock.now
        if wrongItemID != nil && now >= wrongUntil { wrongItemID = nil }
        if let until = roundDoneUntil, now >= until {
            roundDoneUntil = nil
            if !engine.isFinished { nextRound() }
        }
    }

    func tap(_ item: SortingChallengeEngine.Item) {
        guard roundDoneUntil == nil, !tapped.contains(item.id) else { return }
        let now = clock.now
        let r = engine.tap(itemID: item.id, responseTime: now - lastTapAt)
        lastTapAt = now
        if r == .correct {
            Feedback.tap()
            if engine.roundComplete {
                Feedback.correct()
                roundDoneUntil = now + 0.7
            }
        } else {
            Feedback.wrong()
            wrongItemID = item.id
            wrongUntil = now + 0.5
        }
    }

    private func nextRound() {
        let r = engine.startRound()
        round = r
        roundNumber += 1
        var j: [Int: CGSizeLike] = [:]
        for item in r.items {
            j[item.id] = CGSizeLike(dx: Double.random(in: -10...10), dy: Double.random(in: -10...10))
        }
        jitter = j
        lastTapAt = clock.now
    }
}

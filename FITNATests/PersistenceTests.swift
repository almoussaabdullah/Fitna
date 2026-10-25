import XCTest
import SwiftData
import FitnaKit
@testable import FITNA

/// Integration tests for recording sessions against an in-memory SwiftData store.
@MainActor
final class PersistenceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func outcome(_ game: GameID = .mentalMath, level: Int = 1, correct: Int = 10, attempts: Int = 10,
                         raw: Int = 100, completed: Bool = true) -> SessionOutcome {
        SessionOutcome(gameID: game, level: level, correct: correct, attempts: attempts, responseTimes: [1, 1, 1],
                       rawScore: raw, duration: 40, completed: completed)
    }

    func testRecordingPersistsSessionAndResult() throws {
        let summary = GameRecorder.record(outcome(), context: .free, startedAt: Date(), in: context)
        let sessions = try context.fetch(FetchDescriptor<GameSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.result?.rawScore, 100)
        XCTAssertEqual(sessions.first?.gameID, .mentalMath)
        XCTAssertGreaterThan(summary.xpEarned, 0)
        XCTAssertEqual(Store.profile(in: context).totalXP, summary.xpEarned)
        XCTAssertTrue(summary.newAchievements.contains(.smartStart))
    }

    func testDifficultyIsStoredPerGame() {
        for _ in 0..<4 { GameRecorder.record(outcome(.mentalMath, level: Store.difficulty(for: .mentalMath, in: context).difficulty.level), context: .free, startedAt: Date(), in: context) }
        XCTAssertGreaterThan(Store.difficulty(for: .mentalMath, in: context).difficulty.level, 1)
        XCTAssertEqual(Store.difficulty(for: .cardMatching, in: context).difficulty.level, 1)
    }

    func testAbandonedSessionDoesNotChangeDifficultyOrXP() {
        let s = GameRecorder.record(outcome(completed: false), context: .free, startedAt: Date(), in: context)
        XCTAssertEqual(s.xpEarned, 0)
        XCTAssertNil(s.performance)
        XCTAssertEqual(Store.difficulty(for: .mentalMath, in: context).rating, 1.0)
    }

    func testPersonalBest() {
        let first = GameRecorder.record(outcome(raw: 50), context: .free, startedAt: Date(), in: context)
        XCTAssertTrue(first.isPersonalBest)
        let lower = GameRecorder.record(outcome(raw: 40), context: .free, startedAt: Date(), in: context)
        XCTAssertFalse(lower.isPersonalBest)
        XCTAssertEqual(lower.previousBest, 50)
    }

    func testResetClearsEverything() throws {
        GameRecorder.record(outcome(), context: .free, startedAt: Date(), in: context)
        Store.resetAll(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GameSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Achievement>()), 0)
    }

    func testOverviewUsesOnlyRealData() {
        let empty = PlayerOverview.make(sessions: [], totalXP: 0)
        XCTAssertNil(empty.statistics.overallScore)
        XCTAssertTrue(empty.recent.isEmpty)
        XCTAssertEqual(empty.currentStreak, 0)
        GameRecorder.record(outcome(), context: .free, startedAt: Date(), in: context)
        let ov = PlayerOverview.make(sessions: Store.sessions(in: context), totalXP: Store.profile(in: context).totalXP)
        XCTAssertEqual(ov.recent.count, 1)
        XCTAssertEqual(ov.currentStreak, 1)
        XCTAssertNotNil(ov.statistics.categoryScores[.math])
    }

    func testEveryGameViewModelCanStart() {
        for game in GameID.allCases {
            let clock = GameClock()
            clock.start()
            let vm = GameFactory.makeViewModel(for: game, level: 5, length: .short, clock: clock)
            vm.begin()
            vm.tick()
            XCTAssertEqual(vm.gameID, game)
            XCTAssertFalse(vm.isFinished, "\(game) finished immediately")
            let o = vm.outcome(duration: 1, completed: false)
            XCTAssertEqual(o.gameID, game)
        }
    }
}

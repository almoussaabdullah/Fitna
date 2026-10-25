import XCTest
@testable import FitnaKit

final class ScoringTests: XCTestCase {
    private func outcome(_ game: GameID = .mentalMath, level: Int, correct: Int, attempts: Int,
                         times: [Double] = [], completed: Bool = true) -> SessionOutcome {
        SessionOutcome(gameID: game, level: level, correct: correct, attempts: attempts, responseTimes: times,
                       rawScore: 100, duration: 60, completed: completed)
    }

    func testAccuracy() {
        XCTAssertEqual(outcome(level: 1, correct: 3, attempts: 4).accuracy, 0.75, accuracy: 1e-9)
        XCTAssertEqual(outcome(level: 1, correct: 0, attempts: 0).accuracy, 0)
    }

    func testMedianResponseTime() {
        XCTAssertEqual(outcome(level: 1, correct: 1, attempts: 1, times: [1, 9, 3]).medianResponseTime, 3)
        XCTAssertEqual(outcome(level: 1, correct: 1, attempts: 1, times: [1, 2, 3, 4]).medianResponseTime, 2.5)
        XCTAssertNil(outcome(level: 1, correct: 1, attempts: 1).medianResponseTime)
    }

    func testSpeedComponentIsClampedAndLinear() {
        let ref = GameID.mentalMath.referenceTimes(level: 1)
        let fast = outcome(level: 1, correct: 1, attempts: 1, times: [ref.fast / 2])
        let slow = outcome(level: 1, correct: 1, attempts: 1, times: [ref.slow * 2])
        let mid = outcome(level: 1, correct: 1, attempts: 1, times: [(ref.fast + ref.slow) / 2])
        XCTAssertEqual(ScoringModel.speedComponent(fast), 1)
        XCTAssertEqual(ScoringModel.speedComponent(slow), 0)
        XCTAssertEqual(ScoringModel.speedComponent(mid)!, 0.5, accuracy: 1e-9)
    }

    func testPerfectSessionPerformanceDependsOnDifficulty() {
        let fastTime = GameID.mentalMath.referenceTimes(level: 1).fast / 2
        let easy = outcome(level: 1, correct: 10, attempts: 10, times: Array(repeating: fastTime, count: 10))
        let hardFast = GameID.mentalMath.referenceTimes(level: 10).fast / 2
        let hard = outcome(level: 10, correct: 10, attempts: 10, times: Array(repeating: hardFast, count: 10))
        XCTAssertEqual(ScoringModel.performance(easy), 40)
        XCTAssertEqual(ScoringModel.performance(hard), 100)
    }

    func testEasierChallengeNeverRaisesPerformance() {
        // Same quality at a lower level must never beat the higher level.
        for level in 2...10 {
            let hi = outcome(.numberMemory, level: level, correct: 8, attempts: 10)
            let lo = outcome(.numberMemory, level: level - 1, correct: 8, attempts: 10)
            XCTAssertGreaterThan(ScoringModel.performance(hi)!, ScoringModel.performance(lo)!)
        }
    }

    func testAbandonedSessionHasNoPerformance() {
        XCTAssertNil(ScoringModel.performance(outcome(level: 5, correct: 5, attempts: 5, completed: false)))
        XCTAssertNil(ScoringModel.performance(outcome(level: 5, correct: 0, attempts: 0)))
    }

    func testPerformanceRange() {
        for level in 1...10 {
            for correct in 0...10 {
                let o = outcome(level: level, correct: correct, attempts: 10, times: [Double(correct)])
                let p = ScoringModel.performance(o)!
                XCTAssertGreaterThanOrEqual(p, 0)
                XCTAssertLessThanOrEqual(p, 100)
            }
        }
    }

    func testCategoryScoreWeightsRecentSessions() {
        let improving = ScoringModel.categoryScore(recentPerformancesNewestFirst: [80, 40, 40])!
        let declining = ScoringModel.categoryScore(recentPerformancesNewestFirst: [40, 80, 80])!
        XCTAssertGreaterThan(improving, 40)
        XCTAssertLessThan(improving, 80)
        XCTAssertLessThan(declining, 80)
        XCTAssertNil(ScoringModel.categoryScore(recentPerformancesNewestFirst: []))
        XCTAssertEqual(ScoringModel.categoryScore(recentPerformancesNewestFirst: [55]), 55)
    }

    func testOverallScoreIsMeanOfAvailableCategories() {
        XCTAssertEqual(ScoringModel.overallScore([.memory: 60, .math: 40]), 50)
        XCTAssertNil(ScoringModel.overallScore([:]))
    }

    func testBrainTierBands() {
        XCTAssertEqual(BrainTier.tier(forScore: 0), .spark)
        XCTAssertEqual(BrainTier.tier(forScore: 34.9), .curious)
        XCTAssertEqual(BrainTier.tier(forScore: 50), .agile)
        XCTAssertEqual(BrainTier.tier(forScore: 100), .master)
        for tier in BrainTier.allCases {
            XCTAssertEqual(BrainTier.tier(forScore: tier.minimumScore), tier)
        }
    }
}

final class DifficultyTests: XCTestCase {
    private func session(level: Int, correct: Int, attempts: Int = 10, completed: Bool = true) -> SessionOutcome {
        SessionOutcome(gameID: .numberMemory, level: level, correct: correct, attempts: attempts, rawScore: 0, duration: 30, completed: completed)
    }

    func testStartsAtLevelOne() {
        XCTAssertEqual(Difficulty().level, 1)
    }

    func testSuccessRaisesAndFailureLowers() {
        var d = Difficulty(rating: 5.5)
        d = d.updated(with: session(level: 5, correct: 10))
        XCTAssertGreaterThan(d.rating, 5.5)
        var e = Difficulty(rating: 5.5)
        e = e.updated(with: session(level: 5, correct: 2))
        XCTAssertLessThan(e.rating, 5.5)
    }

    func testNoSpikes() {
        // At most one level per session, in either direction, from every rating.
        for r in stride(from: 1.0, through: 10.9, by: 0.1) {
            let d = Difficulty(rating: r, recentQualities: [1])
            let up = d.updated(with: session(level: d.level, correct: 10))
            XCTAssertLessThanOrEqual(up.level - d.level, 1)
            let d2 = Difficulty(rating: r, recentQualities: [0])
            let down = d2.updated(with: session(level: d2.level, correct: 0))
            XCTAssertLessThanOrEqual(d2.level - down.level, 1)
        }
    }

    func testBounds() {
        var d = Difficulty(rating: 10.9)
        for _ in 0..<20 { d = d.updated(with: session(level: d.level, correct: 10)) }
        XCTAssertEqual(d.level, 10)
        var e = Difficulty(rating: 1)
        for _ in 0..<20 { e = e.updated(with: session(level: e.level, correct: 0)) }
        XCTAssertEqual(e.level, 1)
    }

    func testConsistentSuccessClimbsAllLevels() {
        var d = Difficulty()
        var sessions = 0
        while d.level < 10 && sessions < 60 {
            d = d.updated(with: session(level: d.level, correct: 10))
            sessions += 1
        }
        XCTAssertEqual(d.level, 10)
        XCTAssertGreaterThan(sessions, 9, "climbing must be gradual")
    }

    func testSteadyAtSeventyPercent() {
        let d = Difficulty(rating: 5.5)
        XCTAssertEqual(d.delta(for: session(level: 5, correct: 7)), 0, accuracy: 0.0001)
    }

    func testAbandonedSessionsAreIgnored() {
        let d = Difficulty(rating: 4.2)
        XCTAssertEqual(d.updated(with: session(level: 4, correct: 0, completed: false)), d)
    }

    func testOffLevelSessionMovesHalfAsMuch() {
        let d = Difficulty(rating: 5.5)
        let on = d.updated(with: session(level: 5, correct: 10)).rating - 5.5
        let off = d.updated(with: session(level: 3, correct: 10)).rating - 5.5
        XCTAssertEqual(off, on / 2, accuracy: 1e-9)
    }
}

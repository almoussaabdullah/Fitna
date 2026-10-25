import XCTest
@testable import FitnaKit

final class ProgressionTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Amman")!
        return c
    }()

    func day(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    func testLevelThresholds() {
        XCTAssertEqual(Progression.totalXP(toReach: 1), 0)
        XCTAssertEqual(Progression.totalXP(toReach: 2), 100)
        XCTAssertEqual(Progression.totalXP(toReach: 3), 250)
        XCTAssertEqual(Progression.levelInfo(totalXP: 0).level, 1)
        XCTAssertEqual(Progression.levelInfo(totalXP: 99).level, 1)
        XCTAssertEqual(Progression.levelInfo(totalXP: 100).level, 2)
        let info = Progression.levelInfo(totalXP: 175)
        XCTAssertEqual(info.level, 2)
        XCTAssertEqual(info.xpIntoLevel, 75)
        XCTAssertEqual(info.xpForNextLevel, 150)
        XCTAssertEqual(info.fraction, 0.5, accuracy: 1e-9)
    }

    func testLevelInfoRoundTrip() {
        for level in 1...30 {
            XCTAssertEqual(Progression.levelInfo(totalXP: Progression.totalXP(toReach: level)).level, level)
        }
    }

    func testSessionXP() {
        let perfect = SessionOutcome(gameID: .cardMatching, level: 5, correct: 8, attempts: 8, rawScore: 0, duration: 30)
        XCTAssertEqual(Progression.xp(for: perfect), 10 + 20 + 10)
        let abandoned = SessionOutcome(gameID: .cardMatching, level: 5, correct: 8, attempts: 8, rawScore: 0, duration: 30, completed: false)
        XCTAssertEqual(Progression.xp(for: abandoned), 0)
    }

    func testCurrentStreak() {
        let days: Set<String> = ["2026-10-23", "2026-10-24", "2026-10-25"]
        XCTAssertEqual(Streaks.current(activeDays: days, today: day("2026-10-25 22:00"), calendar: cal), 3)
        // Not played today yet: streak from yesterday is still alive.
        XCTAssertEqual(Streaks.current(activeDays: days, today: day("2026-10-26 09:00"), calendar: cal), 3)
        // Missed a whole day: broken.
        XCTAssertEqual(Streaks.current(activeDays: days, today: day("2026-10-27 09:00"), calendar: cal), 0)
        XCTAssertEqual(Streaks.current(activeDays: [], today: day("2026-10-27 09:00"), calendar: cal), 0)
    }

    func testLongestStreak() {
        let days: Set<String> = ["2026-10-01", "2026-10-02", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-31", "2026-11-01"]
        XCTAssertEqual(Streaks.longest(activeDays: days, calendar: cal), 3)
        XCTAssertEqual(Streaks.longest(activeDays: [], calendar: cal), 0)
    }

    func testDayKeyAndSeedStable() {
        XCTAssertEqual(DayKey.key(for: day("2026-10-25 23:59"), calendar: cal), "2026-10-25")
        XCTAssertEqual(DayKey.seed(for: day("2026-10-25 01:00"), calendar: cal), DayKey.seed(for: day("2026-10-25 23:00"), calendar: cal))
        XCTAssertNotEqual(DayKey.seed(for: day("2026-10-25 01:00"), calendar: cal), DayKey.seed(for: day("2026-10-26 01:00"), calendar: cal))
    }

    func testStatisticsAndAchievements() {
        var sessions: [SessionSummary] = []
        for i in 0..<10 {
            let o = SessionOutcome(gameID: .numberMemory, level: 3, correct: 8, attempts: 10, rawScore: 100 + i,
                                   duration: 40, highlightValue: 8)
            sessions.append(SessionSummary(outcome: o, date: day("2026-10-2\(i % 3 + 1) 10:00")))
        }
        let abandoned = SessionOutcome(gameID: .mentalMath, level: 3, correct: 1, attempts: 2, rawScore: 5, duration: 10, completed: false)
        sessions.append(SessionSummary(outcome: abandoned, date: day("2026-10-25 10:00")))

        let stats = PlayerStatistics.compute(from: sessions, calendar: cal)
        XCTAssertEqual(stats.completedSessions, 10)
        XCTAssertEqual(stats.totalPlayTime, 410)
        XCTAssertEqual(stats.bestRawScore[.numberMemory], 109)
        XCTAssertNil(stats.bestRawScore[.mentalMath], "abandoned sessions are not records")
        XCTAssertEqual(stats.activeDays.count, 3)
        XCTAssertNotNil(stats.categoryScores[.memory])
        XCTAssertNil(stats.categoryScores[.math])

        let ctx = AchievementContext(statistics: stats, playerLevel: 2, workoutDayKeys: [], assessmentsCompleted: 0,
                                     currentPlayStreak: 3, longestPlayStreak: 3)
        let unlocked = Set(AchievementID.newlyUnlocked(in: ctx, alreadyUnlocked: []))
        XCTAssertTrue(unlocked.contains(.smartStart))
        XCTAssertTrue(unlocked.contains(.ironMemory))
        XCTAssertTrue(unlocked.contains(.threeDayStreak))
        XCTAssertTrue(unlocked.contains(.spanEight))
        XCTAssertFalse(unlocked.contains(.unstoppableMind))
        XCTAssertFalse(unlocked.contains(.weekOfChallenge))
        XCTAssertTrue(AchievementID.newlyUnlocked(in: ctx, alreadyUnlocked: unlocked).isEmpty)
    }

    func testWeekOfChallengeNeedsConsecutiveWorkouts() {
        let ctxBroken = AchievementContext(statistics: .empty, playerLevel: 1,
                                           workoutDayKeys: ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08"],
                                           assessmentsCompleted: 0, currentPlayStreak: 0, longestPlayStreak: 0)
        XCTAssertFalse(AchievementID.weekOfChallenge.isUnlocked(in: ctxBroken))
        let keys = Set((1...7).map { String(format: "2026-10-%02d", $0) })
        let ctx = AchievementContext(statistics: .empty, playerLevel: 1, workoutDayKeys: keys,
                                     assessmentsCompleted: 0, currentPlayStreak: 0, longestPlayStreak: 0)
        XCTAssertTrue(AchievementID.weekOfChallenge.isUnlocked(in: ctx))
    }

    func testAvatarCatalog() {
        XCTAssertEqual(Set(AvatarOption.all.map(\.id)).count, AvatarOption.all.count)
        XCTAssertTrue(AvatarOption.all.contains { $0.unlockLevel == 1 })
        XCTAssertEqual(AvatarOption.option(id: "missing").id, AvatarOption.all[0].id)
    }
}

final class PlannerTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func testWorkoutCoversEveryCategoryOnce() {
        for offset in 0..<60 {
            let date = Date(timeIntervalSince1970: 1_760_000_000 + Double(offset) * 86_400)
            let plan = DailyWorkoutPlanner.plan(for: date, categoryScores: [:], lastPlayed: [:], previousWorkoutGames: [], calendar: cal)
            XCTAssertEqual(plan.count, DailyWorkoutPlanner.challengeCount)
            XCTAssertEqual(Set(plan.map(\.skill)), Set(CognitiveSkill.allCases))
        }
    }

    func testWorkoutIsStableForTheDay() {
        let morning = Date(timeIntervalSince1970: 1_760_000_000)
        let a = DailyWorkoutPlanner.plan(for: morning, categoryScores: [.math: 30], lastPlayed: [:], previousWorkoutGames: [], calendar: cal)
        let b = DailyWorkoutPlanner.plan(for: morning.addingTimeInterval(60), categoryScores: [.math: 30], lastPlayed: [:], previousWorkoutGames: [], calendar: cal)
        XCTAssertEqual(a, b)
    }

    func testWorkoutStartsWithWeakestCategory() {
        let scores: [CognitiveSkill: Double] = [.memory: 70, .attention: 60, .logic: 20, .speed: 55, .math: 80]
        let plan = DailyWorkoutPlanner.plan(for: Date(), categoryScores: scores, lastPlayed: [:], previousWorkoutGames: [], calendar: cal)
        XCTAssertEqual(plan.first?.skill, .logic)
        XCTAssertEqual(plan.last?.skill, .math)
    }

    func testWorkoutAvoidsYesterdaysGames() {
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let yesterday = DailyWorkoutPlanner.plan(for: date.addingTimeInterval(-86_400), categoryScores: [:], lastPlayed: [:], previousWorkoutGames: [], calendar: cal)
        let today = DailyWorkoutPlanner.plan(for: date, categoryScores: [:], lastPlayed: [:], previousWorkoutGames: yesterday, calendar: cal)
        for game in today {
            // Every category has at least two games, so yesterday's pick is always avoidable.
            XCTAssertFalse(yesterday.contains(game), "\(game) repeated")
        }
    }

    func testAssessmentPlan() {
        let plan = AssessmentPlanner.plan(levels: [.numberMemory: 7, .cardMatching: 5, .missingObject: 3], seed: 42)
        XCTAssertEqual(plan.map(\.skill), CognitiveSkill.allCases)
        XCTAssertEqual(plan.first { $0.skill == .memory }?.level, 5)
        XCTAssertEqual(plan.first { $0.skill == .math }?.level, 3)
        for item in plan { XCTAssertEqual(item.game.skill, item.skill) }
        XCTAssertEqual(AssessmentPlanner.overall([.memory: 50, .attention: 50, .logic: 50, .speed: 50, .math: 100]), 60)
    }

    func testWorkoutSummary() {
        let p: [CognitiveSkill: Double] = [.memory: 40, .math: 90, .logic: 40]
        XCTAssertEqual(WorkoutSummary.strongest(p), .math)
        XCTAssertEqual(WorkoutSummary.weakest(p), .memory)
        XCTAssertNil(WorkoutSummary.weakest([:]))
    }

    func testCatalogIntegrity() {
        XCTAssertEqual(GameID.allCases.count, 12)
        for skill in CognitiveSkill.allCases { XCTAssertGreaterThanOrEqual(skill.games.count, 2) }
        for game in GameID.allCases {
            for level in 1...10 {
                let r = game.referenceTimes(level: level)
                XCTAssertLessThan(r.fast, r.slow)
            }
        }
        XCTAssertEqual(SymbolCatalog.cardFaces.count, CardMatchingEngine.facePoolSize)
    }
}

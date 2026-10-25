import Foundation
import SwiftData
import FitnaKit

/// What changed after recording a session — drives the results screen.
struct RecordSummary {
    let outcome: SessionOutcome
    let performance: Double?
    let xpEarned: Int
    let previousLevel: Int
    let newLevel: Int
    let isPersonalBest: Bool
    let previousBest: Int?
    let difficultyBefore: Int
    let difficultyAfter: Int
    let newAchievements: [AchievementID]

    var leveledUp: Bool { newLevel > previousLevel }
}

/// Single entry point that persists a finished session and applies every
/// side effect: difficulty, XP, records and achievements.
@MainActor
enum GameRecorder {
    @discardableResult
    static func record(_ outcome: SessionOutcome, context playContext: PlayContext, startedAt: Date,
                       in context: ModelContext, now: Date = Date()) -> RecordSummary {
        let profile = Store.profile(in: context)
        let previousLevel = Progression.levelInfo(totalXP: profile.totalXP).level

        // Personal best is computed before inserting this session.
        let previousBest = bestRawScore(for: outcome.gameID, in: context)
        let isBest = outcome.completed && outcome.rawScore > 0 && outcome.rawScore > (previousBest ?? 0)

        let xp = Progression.xp(for: outcome)
        let performance = ScoringModel.performance(outcome)
        let session = GameSession(gameRaw: outcome.gameID.rawValue, contextRaw: playContext.rawValue, startedAt: startedAt,
                                  endedAt: now, level: outcome.level, lengthRaw: outcome.length.rawValue, completed: outcome.completed)
        let result = GameResult(correct: outcome.correct, attempts: outcome.attempts, accuracy: outcome.accuracy,
                                medianResponseTime: outcome.medianResponseTime, rawScore: outcome.rawScore, performance: performance,
                                quality: ScoringModel.quality(outcome), bestStreak: outcome.bestStreak, duration: outcome.duration,
                                highlightValue: outcome.highlightValue, xpEarned: xp)
        context.insert(session)
        context.insert(result)
        session.result = result

        // Adaptive difficulty (abandoned sessions leave it untouched).
        let progress = Store.difficulty(for: outcome.gameID, in: context)
        let before = progress.difficulty.level
        progress.difficulty = progress.difficulty.updated(with: outcome)
        progress.lastPlayed = now
        let after = progress.difficulty.level

        profile.totalXP += xp
        let newLevel = Progression.levelInfo(totalXP: profile.totalXP).level

        let achievements = evaluateAchievements(in: context, now: now)
        try? context.save()

        return RecordSummary(outcome: outcome, performance: performance, xpEarned: xp, previousLevel: previousLevel,
                             newLevel: newLevel, isPersonalBest: isBest, previousBest: previousBest,
                             difficultyBefore: before, difficultyAfter: after, newAchievements: achievements)
    }

    /// Adds bonus XP (workout / assessment completion) and re-checks achievements.
    @discardableResult
    static func awardBonus(xp: Int, in context: ModelContext, now: Date = Date()) -> [AchievementID] {
        let profile = Store.profile(in: context)
        profile.totalXP += xp
        let unlocked = evaluateAchievements(in: context, now: now)
        try? context.save()
        return unlocked
    }

    static func bestRawScore(for game: GameID, in context: ModelContext) -> Int? {
        let raw = game.rawValue
        let descriptor = FetchDescriptor<GameSession>(predicate: #Predicate { $0.gameRaw == raw && $0.completed })
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.compactMap { $0.result?.rawScore }.max()
    }

    /// Evaluates achievements from real history and persists newly unlocked ones.
    static func evaluateAchievements(in context: ModelContext, now: Date = Date()) -> [AchievementID] {
        let ctx = achievementContext(in: context, now: now)
        let already = Store.unlockedAchievements(in: context)
        let fresh = AchievementID.newlyUnlocked(in: ctx, alreadyUnlocked: already)
        for id in fresh { context.insert(Achievement(idRaw: id.rawValue, unlockedAt: now)) }
        return fresh
    }

    static func achievementContext(in context: ModelContext, now: Date = Date()) -> AchievementContext {
        let stats = PlayerStatistics.compute(from: Store.summaries(in: context))
        let workouts = (try? context.fetch(FetchDescriptor<DailyWorkout>(predicate: #Predicate { $0.isCompleted }))) ?? []
        let assessments = (try? context.fetchCount(FetchDescriptor<BrainAssessment>())) ?? 0
        let profile = Store.profile(in: context)
        return AchievementContext(statistics: stats,
                                  playerLevel: Progression.levelInfo(totalXP: profile.totalXP).level,
                                  workoutDayKeys: Set(workouts.map(\.dayKey)),
                                  assessmentsCompleted: assessments,
                                  currentPlayStreak: Streaks.current(activeDays: stats.activeDays, today: now),
                                  longestPlayStreak: Streaks.longest(activeDays: stats.activeDays))
    }
}

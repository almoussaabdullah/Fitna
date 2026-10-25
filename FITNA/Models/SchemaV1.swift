import Foundation
import SwiftData

/// Version 1 of the on-device store. Future changes add `SchemaV2` and a
/// migration stage to `FitnaMigrationPlan` instead of editing these models.
///
/// Note: `MiniGame` (the 12-game catalog) and `PlayerStatistics` (aggregates) are
/// not persisted — they live in FitnaKit and are derived from stored sessions.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlayerProfile.self, GameSession.self, GameResult.self, DifficultyProgress.self,
         DailyWorkout.self, BrainAssessment.self, CognitiveSkillScore.self, Achievement.self]
    }

    @Model
    final class PlayerProfile {
        var id: UUID = UUID()
        var nickname: String = ""
        var avatarID: String = "brain"
        var createdAt: Date = Date()
        var totalXP: Int = 0

        init(nickname: String = "", avatarID: String = "brain") {
            self.nickname = nickname
            self.avatarID = avatarID
            self.createdAt = Date()
        }
    }

    /// One play of one mini-game, in any context.
    @Model
    final class GameSession {
        var id: UUID = UUID()
        var gameRaw: String = ""
        /// "free", "workout" or "assessment".
        var contextRaw: String = "free"
        var startedAt: Date = Date()
        var endedAt: Date = Date()
        var level: Int = 1
        var lengthRaw: String = "standard"
        var completed: Bool = false
        @Relationship(deleteRule: .cascade, inverse: \GameResult.session)
        var result: GameResult?

        init(gameRaw: String, contextRaw: String, startedAt: Date, endedAt: Date, level: Int, lengthRaw: String, completed: Bool) {
            self.gameRaw = gameRaw
            self.contextRaw = contextRaw
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.level = level
            self.lengthRaw = lengthRaw
            self.completed = completed
        }
    }

    /// Measured results of a session (raw and normalized are kept separately).
    @Model
    final class GameResult {
        var correct: Int = 0
        var attempts: Int = 0
        var accuracy: Double = 0
        var medianResponseTime: Double?
        var rawScore: Int = 0
        /// Normalized 0–100 performance (nil for abandoned sessions).
        var performance: Double?
        var quality: Double = 0
        var bestStreak: Int = 0
        var duration: Double = 0
        var highlightValue: Int?
        var xpEarned: Int = 0
        var session: GameSession?

        init(correct: Int, attempts: Int, accuracy: Double, medianResponseTime: Double?, rawScore: Int, performance: Double?,
             quality: Double, bestStreak: Int, duration: Double, highlightValue: Int?, xpEarned: Int) {
            self.correct = correct
            self.attempts = attempts
            self.accuracy = accuracy
            self.medianResponseTime = medianResponseTime
            self.rawScore = rawScore
            self.performance = performance
            self.quality = quality
            self.bestStreak = bestStreak
            self.duration = duration
            self.highlightValue = highlightValue
            self.xpEarned = xpEarned
        }
    }

    /// Adaptive difficulty state, one row per game.
    @Model
    final class DifficultyProgress {
        @Attribute(.unique) var gameRaw: String = ""
        var rating: Double = 1
        var recentQualities: [Double] = []
        var sessionsPlayed: Int = 0
        var lastPlayed: Date?

        init(gameRaw: String) {
            self.gameRaw = gameRaw
        }
    }

    /// One row per day the daily workout was opened.
    @Model
    final class DailyWorkout {
        @Attribute(.unique) var dayKey: String = ""
        var date: Date = Date()
        var gamesRaw: [String] = []
        var completedGamesRaw: [String] = []
        var performances: [Double] = []
        var totalPoints: Int = 0
        var correct: Int = 0
        var attempts: Int = 0
        var xpEarned: Int = 0
        var isCompleted: Bool = false
        var completedAt: Date?

        init(dayKey: String, date: Date, gamesRaw: [String]) {
            self.dayKey = dayKey
            self.date = date
            self.gamesRaw = gamesRaw
        }
    }

    @Model
    final class BrainAssessment {
        var id: UUID = UUID()
        var date: Date = Date()
        var overallScore: Double = 0
        @Relationship(deleteRule: .cascade, inverse: \CognitiveSkillScore.assessment)
        var skillScores: [CognitiveSkillScore] = []

        init(date: Date, overallScore: Double) {
            self.date = date
            self.overallScore = overallScore
        }
    }

    @Model
    final class CognitiveSkillScore {
        var skillRaw: String = ""
        var score: Double = 0
        var gameRaw: String = ""
        var level: Int = 1
        var assessment: BrainAssessment?

        init(skillRaw: String, score: Double, gameRaw: String, level: Int) {
            self.skillRaw = skillRaw
            self.score = score
            self.gameRaw = gameRaw
            self.level = level
        }
    }

    @Model
    final class Achievement {
        @Attribute(.unique) var idRaw: String = ""
        var unlockedAt: Date = Date()

        init(idRaw: String, unlockedAt: Date) {
            self.idRaw = idRaw
            self.unlockedAt = unlockedAt
        }
    }
}

typealias PlayerProfile = SchemaV1.PlayerProfile
typealias GameSession = SchemaV1.GameSession
typealias GameResult = SchemaV1.GameResult
typealias DifficultyProgress = SchemaV1.DifficultyProgress
typealias DailyWorkout = SchemaV1.DailyWorkout
typealias BrainAssessment = SchemaV1.BrainAssessment
typealias CognitiveSkillScore = SchemaV1.CognitiveSkillScore
typealias Achievement = SchemaV1.Achievement

enum FitnaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

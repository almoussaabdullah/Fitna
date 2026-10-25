import Foundation
import SwiftData
import FitnaKit

enum PersistenceController {
    /// The app's persistent container. Falls back to an in-memory store only if the
    /// on-disk store can't be opened, so the app always launches.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        // SwiftData doesn't always create Application Support on first launch.
        if !inMemory, let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        }
        let config = ModelConfiguration("FITNA", schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, migrationPlan: FitnaMigrationPlan.self, configurations: [config])
        } catch {
            assertionFailure("Failed to open store: \(error)")
            let memory = ModelConfiguration("FITNA-fallback", schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }
}

/// Where a session was played.
enum PlayContext: String {
    case free, workout, assessment
}

extension GameSession {
    var gameID: GameID? { GameID(rawValue: gameRaw) }
    var context: PlayContext { PlayContext(rawValue: contextRaw) ?? .free }

    var summary: SessionSummary? {
        guard let game = gameID, let r = result else { return nil }
        return SessionSummary(gameID: game, date: endedAt, level: level, rawScore: r.rawScore, performance: r.performance,
                              accuracy: r.accuracy, medianResponseTime: r.medianResponseTime, duration: r.duration,
                              completed: completed, highlightValue: r.highlightValue)
    }
}

extension DifficultyProgress {
    var difficulty: Difficulty {
        get { Difficulty(rating: rating, recentQualities: recentQualities, sessionsPlayed: sessionsPlayed) }
        set {
            rating = newValue.rating
            recentQualities = newValue.recentQualities
            sessionsPlayed = newValue.sessionsPlayed
        }
    }
}

extension DailyWorkout {
    var games: [GameID] { gamesRaw.compactMap(GameID.init(rawValue:)) }
    var completedGames: [GameID] { completedGamesRaw.compactMap(GameID.init(rawValue:)) }
    var nextGame: GameID? { games.first { !completedGamesRaw.contains($0.rawValue) } }
    var progressFraction: Double { games.isEmpty ? 0 : Double(completedGamesRaw.count) / Double(games.count) }
}

extension BrainAssessment {
    var scoresBySkill: [CognitiveSkill: Double] {
        var map: [CognitiveSkill: Double] = [:]
        for s in skillScores { if let skill = CognitiveSkill(rawValue: s.skillRaw) { map[skill] = s.score } }
        return map
    }
}

/// Read helpers shared by screens and services.
@MainActor
enum Store {
    static func profile(in context: ModelContext) -> PlayerProfile {
        if let existing = try? context.fetch(FetchDescriptor<PlayerProfile>()).first { return existing }
        let p = PlayerProfile(nickname: "")
        context.insert(p)
        try? context.save()
        return p
    }

    static func difficulty(for game: GameID, in context: ModelContext) -> DifficultyProgress {
        let raw = game.rawValue
        var descriptor = FetchDescriptor<DifficultyProgress>(predicate: #Predicate { $0.gameRaw == raw })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }
        let d = DifficultyProgress(gameRaw: raw)
        context.insert(d)
        return d
    }

    static func allLevels(in context: ModelContext) -> [GameID: Int] {
        let rows = (try? context.fetch(FetchDescriptor<DifficultyProgress>())) ?? []
        var map: [GameID: Int] = [:]
        for row in rows { if let g = GameID(rawValue: row.gameRaw) { map[g] = row.difficulty.level } }
        return map
    }

    static func sessions(in context: ModelContext) -> [GameSession] {
        (try? context.fetch(FetchDescriptor<GameSession>(sortBy: [SortDescriptor(\.endedAt)]))) ?? []
    }

    static func summaries(in context: ModelContext) -> [SessionSummary] {
        sessions(in: context).compactMap(\.summary)
    }

    static func workout(dayKey: String, in context: ModelContext) -> DailyWorkout? {
        var descriptor = FetchDescriptor<DailyWorkout>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func unlockedAchievements(in context: ModelContext) -> Set<AchievementID> {
        let rows = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        return Set(rows.compactMap { AchievementID(rawValue: $0.idRaw) })
    }

    /// Deletes all progress (keeps the store and settings).
    static func resetAll(in context: ModelContext) {
        try? context.delete(model: GameResult.self)
        try? context.delete(model: GameSession.self)
        try? context.delete(model: DifficultyProgress.self)
        try? context.delete(model: DailyWorkout.self)
        try? context.delete(model: CognitiveSkillScore.self)
        try? context.delete(model: BrainAssessment.self)
        try? context.delete(model: Achievement.self)
        try? context.delete(model: PlayerProfile.self)
        try? context.save()
    }
}

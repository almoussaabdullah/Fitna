import Foundation

/// Inputs needed to evaluate achievements — all derived from real history.
public struct AchievementContext: Equatable, Sendable {
    public var statistics: PlayerStatistics
    public var playerLevel: Int
    public var workoutDayKeys: Set<String>
    public var assessmentsCompleted: Int
    public var currentPlayStreak: Int
    public var longestPlayStreak: Int

    public init(statistics: PlayerStatistics, playerLevel: Int, workoutDayKeys: Set<String>,
                assessmentsCompleted: Int, currentPlayStreak: Int, longestPlayStreak: Int) {
        self.statistics = statistics
        self.playerLevel = playerLevel
        self.workoutDayKeys = workoutDayKeys
        self.assessmentsCompleted = assessmentsCompleted
        self.currentPlayStreak = currentPlayStreak
        self.longestPlayStreak = longestPlayStreak
    }

    public var longestWorkoutStreak: Int { Streaks.longest(activeDays: workoutDayKeys) }
}

/// Achievement catalog. Raw values are persisted — never rename them.
public enum AchievementID: String, CaseIterable, Codable, Sendable, Identifiable {
    case smartStart        // بداية ذكية — first completed game
    case ironMemory        // ذاكرة حديدية — 10 memory sessions
    case quickWitted       // سريع البديهة — 3 lightning-fast sessions
    case weekOfChallenge   // أسبوع من التحدي — 7 consecutive daily workouts
    case unstoppableMind   // عقل لا يتوقف — 100 completed sessions
    case firstWorkout      // first daily workout
    case explorer          // played all 12 games
    case firstAssessment   // first brain test
    case sharpAttention    // 10 attention sessions
    case logician          // 10 logic sessions
    case mathWhiz          // 10 math sessions
    case threeDayStreak    // 3-day play streak
    case risingMind        // reach player level 5
    case highScorer        // overall score ≥ 60
    case spanEight         // remember 8 digits in Number Memory

    public var id: String { rawValue }
    public var titleKey: String { "ach.\(rawValue).title" }
    public var detailKey: String { "ach.\(rawValue).detail" }

    public var symbol: String {
        switch self {
        case .smartStart: return "flag.checkered"
        case .ironMemory: return "brain.head.profile"
        case .quickWitted: return "bolt.circle.fill"
        case .weekOfChallenge: return "calendar.badge.checkmark"
        case .unstoppableMind: return "infinity.circle.fill"
        case .firstWorkout: return "figure.mind.and.body"
        case .explorer: return "map.fill"
        case .firstAssessment: return "chart.pie.fill"
        case .sharpAttention: return "eye.fill"
        case .logician: return "puzzlepiece.fill"
        case .mathWhiz: return "function"
        case .threeDayStreak: return "flame.fill"
        case .risingMind: return "arrow.up.forward.circle.fill"
        case .highScorer: return "trophy.fill"
        case .spanEight: return "8.circle.fill"
        }
    }

    /// Progress toward the goal: (current, target). Unlocked when current ≥ target.
    public func progress(in ctx: AchievementContext) -> (current: Int, target: Int) {
        let s = ctx.statistics
        switch self {
        case .smartStart: return (s.completedSessions, 1)
        case .ironMemory: return (s.sessionsPerSkill[.memory] ?? 0, 10)
        case .quickWitted: return (s.lightningSessions, 3)
        case .weekOfChallenge: return (ctx.longestWorkoutStreak, 7)
        case .unstoppableMind: return (s.completedSessions, 100)
        case .firstWorkout: return (ctx.workoutDayKeys.count, 1)
        case .explorer: return (s.sessionsPerGame.keys.count, GameID.allCases.count)
        case .firstAssessment: return (ctx.assessmentsCompleted, 1)
        case .sharpAttention: return (s.sessionsPerSkill[.attention] ?? 0, 10)
        case .logician: return (s.sessionsPerSkill[.logic] ?? 0, 10)
        case .mathWhiz: return (s.sessionsPerSkill[.math] ?? 0, 10)
        case .threeDayStreak: return (max(ctx.currentPlayStreak, ctx.longestPlayStreak), 3)
        case .risingMind: return (ctx.playerLevel, 5)
        case .highScorer: return (Int(s.overallScore ?? 0), 60)
        case .spanEight: return (s.bestHighlight[.numberMemory] ?? 0, 8)
        }
    }

    public func isUnlocked(in ctx: AchievementContext) -> Bool {
        let p = progress(in: ctx)
        return p.current >= p.target
    }

    /// All achievements unlocked in `ctx` that are not in `alreadyUnlocked`.
    public static func newlyUnlocked(in ctx: AchievementContext, alreadyUnlocked: Set<AchievementID>) -> [AchievementID] {
        allCases.filter { !alreadyUnlocked.contains($0) && $0.isUnlocked(in: ctx) }
    }
}

/// Cosmetic avatars unlocked by player level.
public struct AvatarOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    /// Index into the design-system accent palette.
    public let paletteIndex: Int
    public let unlockLevel: Int

    public static let all: [AvatarOption] = [
        AvatarOption(id: "brain", symbol: "brain", paletteIndex: 0, unlockLevel: 1),
        AvatarOption(id: "owl", symbol: "bird.fill", paletteIndex: 1, unlockLevel: 1),
        AvatarOption(id: "bolt", symbol: "bolt.fill", paletteIndex: 2, unlockLevel: 1),
        AvatarOption(id: "leaf", symbol: "leaf.fill", paletteIndex: 3, unlockLevel: 2),
        AvatarOption(id: "moon", symbol: "moon.stars.fill", paletteIndex: 0, unlockLevel: 3),
        AvatarOption(id: "flame", symbol: "flame.fill", paletteIndex: 2, unlockLevel: 4),
        AvatarOption(id: "atom", symbol: "atom", paletteIndex: 1, unlockLevel: 5),
        AvatarOption(id: "puzzle", symbol: "puzzlepiece.extension.fill", paletteIndex: 3, unlockLevel: 6),
        AvatarOption(id: "rocket", symbol: "airplane", paletteIndex: 0, unlockLevel: 8),
        AvatarOption(id: "crown", symbol: "crown.fill", paletteIndex: 2, unlockLevel: 10),
        AvatarOption(id: "sparkles", symbol: "sparkles", paletteIndex: 1, unlockLevel: 12),
        AvatarOption(id: "star", symbol: "star.circle.fill", paletteIndex: 3, unlockLevel: 15)
    ]

    public static func option(id: String) -> AvatarOption { all.first { $0.id == id } ?? all[0] }
}

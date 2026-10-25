import Foundation

/// XP and player levels.
///
/// * Completed game session: 10 + round(20 × quality) + 2 × difficulty level XP.
/// * Daily workout completion bonus: 50 XP. Brain test completion bonus: 40 XP.
/// * Reaching player level n+1 from n costs 100 + 50 × (n − 1) XP.
public enum Progression {
    public static let workoutBonusXP = 50
    public static let assessmentBonusXP = 40

    public static func xp(for outcome: SessionOutcome) -> Int {
        guard outcome.completed, outcome.attempts > 0 else { return 0 }
        let q = ScoringModel.quality(outcome)
        return 10 + Int((20 * q).rounded()) + 2 * outcome.level
    }

    /// XP needed to go from `level` to `level + 1`.
    public static func xpToAdvance(from level: Int) -> Int {
        100 + 50 * (max(1, level) - 1)
    }

    /// Total XP required to *reach* `level` (level 1 needs 0).
    public static func totalXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { $0 + xpToAdvance(from: $1) }
    }

    public struct LevelInfo: Equatable, Sendable {
        public let level: Int
        public let xpIntoLevel: Int
        public let xpForNextLevel: Int
        public var fraction: Double {
            xpForNextLevel == 0 ? 0 : Double(xpIntoLevel) / Double(xpForNextLevel)
        }
    }

    public static func levelInfo(totalXP: Int) -> LevelInfo {
        var level = 1
        var remaining = max(0, totalXP)
        while remaining >= xpToAdvance(from: level) {
            remaining -= xpToAdvance(from: level)
            level += 1
        }
        return LevelInfo(level: level, xpIntoLevel: remaining, xpForNextLevel: xpToAdvance(from: level))
    }
}

/// Day-streak calculations over a set of active days.
public enum Streaks {
    /// Current streak: consecutive active days ending today, or ending yesterday
    /// if today has no activity yet (the streak is still alive until midnight).
    public static func current(activeDays: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !activeDays.contains(DayKey.key(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  activeDays.contains(DayKey.key(for: yesterday, calendar: calendar)) else { return 0 }
            day = yesterday
        }
        var count = 0
        while activeDays.contains(DayKey.key(for: day, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Longest run of consecutive active days ever.
    public static func longest(activeDays: Set<String>, calendar: Calendar = .current) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = activeDays.compactMap { formatter.date(from: $0) }.map { calendar.startOfDay(for: $0) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for d in dates {
            if let p = previous, let next = calendar.date(byAdding: .day, value: 1, to: p), calendar.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = d
        }
        return best
    }
}

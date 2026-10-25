import Foundation

/// Builds the five-challenge daily workout.
///
/// Rules:
/// * one short challenge from each of the five skill categories;
/// * categories are ordered weakest-first (by category score; untested ones count as weakest),
///   so the skills needing practice come while the player is fresh;
/// * within a category, games used in yesterday's workout are avoided, games not played
///   for longer are preferred, and the remaining tie is broken by a seed derived from the date —
///   so the plan is stable for the whole day.
public enum DailyWorkoutPlanner {
    public static let challengeCount = 5

    public static func plan(
        for date: Date,
        categoryScores: [CognitiveSkill: Double],
        lastPlayed: [GameID: Date],
        previousWorkoutGames: [GameID],
        calendar: Calendar = .current
    ) -> [GameID] {
        var rng = SeededGenerator(seed: DayKey.seed(for: date, calendar: calendar, salt: "workout"))
        var keyed: [(skill: CognitiveSkill, key: Double)] = []
        for skill in CognitiveSkill.allCases {
            let score: Double = categoryScores[skill] ?? -1
            let jitter: Double = Double.random(in: 0..<0.01, using: &rng)
            keyed.append((skill, score + jitter))
        }
        let orderedSkills: [CognitiveSkill] = keyed.sorted { $0.key < $1.key }.map { $0.skill }

        return orderedSkills.map { skill in
            let candidates = skill.games
            let scored = candidates.map { game -> (GameID, Double) in
                var score = 0.0
                if previousWorkoutGames.contains(game) { score -= 100 }
                if let last = lastPlayed[game] {
                    let days = date.timeIntervalSince(last) / 86_400
                    score += min(30, max(0, days))
                } else {
                    score += 40 // never played: surface it
                }
                score += Double.random(in: 0..<5, using: &rng)
                return (game, score)
            }
            return scored.max { $0.1 < $1.1 }!.0
        }
    }
}

/// The brain test: one short challenge per category, played at a fixed,
/// calibrated level so results are comparable between attempts.
///
/// The level used for every category is the median of the player's current levels
/// in that category's games (level 3 for a brand-new player), so the test neither
/// punishes beginners nor flatters experienced players.
public enum AssessmentPlanner {
    public struct Item: Equatable, Sendable {
        public let skill: CognitiveSkill
        public let game: GameID
        public let level: Int
    }

    public static func plan(levels: [GameID: Int], seed: UInt64) -> [Item] {
        var rng = SeededGenerator(seed: seed)
        return CognitiveSkill.allCases.map { skill in
            let game = skill.games.randomElement(using: &rng)!
            let known = skill.games.compactMap { levels[$0] }.sorted()
            let level = known.isEmpty ? 3 : known[known.count / 2]
            return Item(skill: skill, game: game, level: Difficulty.clamp(level))
        }
    }

    /// Converts the assessment's per-category performances into the final report.
    /// The overall score is the mean of the five category performances (0…100).
    public static func overall(_ categoryPerformances: [CognitiveSkill: Double]) -> Double {
        let values = CognitiveSkill.allCases.map { categoryPerformances[$0] ?? 0 }
        return ((values.reduce(0, +) / Double(values.count)) * 10).rounded() / 10
    }
}

/// Summary helpers for a finished workout (strongest / weakest category).
public enum WorkoutSummary {
    /// Highest-scoring category; ties resolve in catalog order.
    public static func strongest(_ performances: [CognitiveSkill: Double]) -> CognitiveSkill? {
        var best: (CognitiveSkill, Double)?
        for skill in CognitiveSkill.allCases {
            guard let v = performances[skill] else { continue }
            if best == nil || v > best!.1 { best = (skill, v) }
        }
        return best?.0
    }

    /// Lowest-scoring category; ties resolve in catalog order.
    public static func weakest(_ performances: [CognitiveSkill: Double]) -> CognitiveSkill? {
        var worst: (CognitiveSkill, Double)?
        for skill in CognitiveSkill.allCases {
            guard let v = performances[skill] else { continue }
            if worst == nil || v < worst!.1 { worst = (skill, v) }
        }
        return worst?.0
    }
}

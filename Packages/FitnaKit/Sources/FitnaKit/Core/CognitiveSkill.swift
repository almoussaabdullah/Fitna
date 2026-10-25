import Foundation

/// The five skill categories measured by FITNA.
/// Raw values are stable identifiers used in persistence — never rename them.
public enum CognitiveSkill: String, CaseIterable, Codable, Sendable, Identifiable {
    case memory
    case attention
    case logic
    case speed
    case math

    public var id: String { rawValue }

    /// Localization key for the display name (e.g. "skill.memory" → "الذاكرة").
    public var nameKey: String { "skill.\(rawValue)" }

    /// Localization key for a one-line description.
    public var descriptionKey: String { "skill.\(rawValue).desc" }

    /// Games that train this skill, in catalog order.
    public var games: [GameID] { GameID.allCases.filter { $0.skill == self } }
}

import Foundation

/// The twelve mini-games. Raw values are persisted — never rename them.
public enum GameID: String, CaseIterable, Codable, Sendable, Identifiable {
    case numberMemory
    case missingObject
    case cardMatching
    case oddOneOut
    case stroopChallenge
    case ballTracking
    case patternCompletion
    case balanceLogic
    case missingNumber
    case mentalMath
    case valueComparison
    case sortingChallenge

    public var id: String { rawValue }

    /// The cognitive category this game contributes to.
    public var skill: CognitiveSkill {
        switch self {
        case .numberMemory, .missingObject, .cardMatching: return .memory
        case .oddOneOut, .ballTracking: return .attention
        case .patternCompletion, .balanceLogic, .missingNumber: return .logic
        case .stroopChallenge, .sortingChallenge: return .speed
        case .mentalMath, .valueComparison: return .math
        }
    }

    public var nameKey: String { "game.\(rawValue).name" }
    public var tutorialKey: String { "game.\(rawValue).tutorial" }

    /// Short rule reminder shown during play.
    public var hintKey: String { "game.\(rawValue).hint" }

    /// SF Symbol used as the game icon.
    public var symbol: String {
        switch self {
        case .numberMemory: return "number.square.fill"
        case .missingObject: return "eye.slash.fill"
        case .cardMatching: return "rectangle.on.rectangle.angled.fill"
        case .oddOneOut: return "scope"
        case .stroopChallenge: return "paintpalette.fill"
        case .ballTracking: return "circle.grid.cross.fill"
        case .patternCompletion: return "square.grid.3x3.middle.filled"
        case .balanceLogic: return "scalemass.fill"
        case .missingNumber: return "questionmark.square.dashed"
        case .mentalMath: return "bolt.fill"
        case .valueComparison: return "greaterthan.square.fill"
        case .sortingChallenge: return "arrow.up.arrow.down.square.fill"
        }
    }

    /// Whether response speed meaningfully reflects skill in this game.
    /// Memory games measure retention, so speed carries little weight there.
    public var speedMatters: Bool {
        switch self {
        case .numberMemory, .missingObject, .cardMatching, .ballTracking, .balanceLogic, .patternCompletion, .missingNumber:
            return false
        case .oddOneOut, .stroopChallenge, .mentalMath, .valueComparison, .sortingChallenge:
            return true
        }
    }

    /// Reference response times (seconds) at a given level used by the scoring model:
    /// `fast` earns full speed credit, `slow` earns none.
    public func referenceTimes(level: Int) -> (fast: Double, slow: Double) {
        let l = Double(Difficulty.clamp(level) - 1)
        switch self {
        case .numberMemory: return (2.0 + l * 0.3, 8.0 + l * 0.8)
        case .missingObject: return (1.5, 6.0)
        case .cardMatching: return (1.2, 4.0)
        case .oddOneOut: return (1.0 + l * 0.15, 5.0 + l * 0.4)
        case .stroopChallenge: return (0.7, 2.5)
        case .ballTracking: return (1.0, 4.0)
        case .patternCompletion: return (3.0 + l * 0.3, 14.0 + l * 0.8)
        case .balanceLogic: return (3.0 + l * 0.5, 15.0 + l * 1.0)
        case .missingNumber: return (3.0 + l * 0.4, 15.0 + l * 1.0)
        case .mentalMath: return (1.5 + l * 0.25, 6.0 + l * 0.6)
        case .valueComparison: return (1.2 + l * 0.15, 5.0 + l * 0.3)
        case .sortingChallenge: return (0.5, 1.8)
        }
    }
}

/// Session length: the full standalone game or a shorter version used inside
/// the daily workout and the brain test.
public enum SessionLength: String, Codable, Sendable {
    case standard
    case short
}

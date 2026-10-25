import SwiftUI
import FitnaKit

/// All user-facing text lives in `Resources/<lang>.lproj/Localizable.strings`.
/// Arabic is the development language; adding English means adding `en.lproj`.
///
/// Formatted strings use `%@` placeholders only (numbers are passed pre-formatted),
/// which keeps argument order safe across languages.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let strings: [CVarArg] = args.map { String(describing: $0) as NSString }
    return String(format: NSLocalizedString(key, comment: ""), arguments: strings)
}

/// Number formatting that keeps Western digits (best readability in math games).
enum NumberText {
    static func int(_ value: Int) -> String { String(value) }

    static func score(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(Int(v.rounded()))
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))٪"
    }

    static func seconds(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// "12:05" style duration.
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return L("time.hm", String(h), String(m)) }
        if m > 0 { return L("time.ms", String(m), String(s)) }
        return L("time.s", String(s))
    }
}

/// Wraps text in a Left-to-Right isolate so math stays "24 + 18" inside RTL layouts.
func ltr(_ s: String) -> String { "\u{2066}\(s)\u{2069}" }

extension CognitiveSkill {
    var name: String { L(nameKey) }
    var detail: String { L(descriptionKey) }
    var color: Color { Theme.color(for: CognitiveSkillToken(rawValue: rawValue) ?? .memory) }
    var symbol: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .attention: return "eye.fill"
        case .logic: return "puzzlepiece.fill"
        case .speed: return "hare.fill"
        case .math: return "plus.forwardslash.minus"
        }
    }
}

extension GameID {
    var name: String { L(nameKey) }
    var tutorial: String { L(tutorialKey) }
    var hint: String { L(hintKey) }
    var color: Color { skill.color }
}

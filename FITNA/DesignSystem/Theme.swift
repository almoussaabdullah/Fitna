import SwiftUI

/// FITNA design tokens: colors, typography, spacing and shapes.
enum Theme {
    // MARK: Brand palette
    static let background = Color(hex: 0xF7F8FC)
    static let surface = Color.white
    static let purple = Color(hex: 0x6654E8)
    static let turquoise = Color(hex: 0x35C9B8)
    static let orange = Color(hex: 0xFFB547)
    static let ink = Color(hex: 0x20243A)
    static let success = Color(hex: 0x32C48D)
    static let error = Color(hex: 0xFF6B75)

    static let inkSecondary = Color(hex: 0x20243A).opacity(0.62)
    static let inkTertiary = Color(hex: 0x20243A).opacity(0.38)
    static let hairline = Color(hex: 0x20243A).opacity(0.08)
    static let purpleSoft = Color(hex: 0x6654E8).opacity(0.10)
    static let turquoiseSoft = Color(hex: 0x35C9B8).opacity(0.14)
    static let orangeSoft = Color(hex: 0xFFB547).opacity(0.18)

    /// Accent palette used by game objects (indices come from FitnaKit generators).
    /// Darker variants keep ≥ 3:1 contrast against white surfaces.
    static let accents: [Color] = [
        Color(hex: 0x6654E8),
        Color(hex: 0x1FA597),
        Color(hex: 0xE8920C),
        Color(hex: 0xE84C5A)
    ]

    static func accent(_ index: Int) -> Color { accents[((index % accents.count) + accents.count) % accents.count] }

    static let heroGradient = LinearGradient(colors: [Color(hex: 0x7A68F2), Color(hex: 0x5442D6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let turquoiseGradient = LinearGradient(colors: [Color(hex: 0x4FD8C8), Color(hex: 0x23A99A)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let orangeGradient = LinearGradient(colors: [Color(hex: 0xFFC56E), Color(hex: 0xF59E1B)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: Layout
    static let corner: CGFloat = 22
    static let smallCorner: CGFloat = 14
    static let padding: CGFloat = 20
    static let minTouch: CGFloat = 48
}

/// Color per cognitive skill (paired with a symbol so color is never the only cue).
extension Theme {
    static func color(for skill: CognitiveSkillToken) -> Color {
        switch skill {
        case .memory: return purple
        case .attention: return Color(hex: 0x1FA597)
        case .logic: return Color(hex: 0x3B7BE8)
        case .speed: return Color(hex: 0xE8920C)
        case .math: return Color(hex: 0xE84C5A)
        }
    }
}

/// Mirror of FitnaKit's CognitiveSkill raw values used by the design system,
/// so DesignSystem has no dependency on game logic.
enum CognitiveSkillToken: String {
    case memory, attention, logic, speed, math
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Typography

/// Tajawal (SIL Open Font License, bundled) with system-font fallback.
/// Every style is tied to a Dynamic Type text style so it scales with the user's setting.
enum FitnaFont {
    enum Weight: String {
        case regular = "Tajawal-Regular"
        case medium = "Tajawal-Medium"
        case bold = "Tajawal-Bold"
        case heavy = "Tajawal-ExtraBold"

        var systemWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .bold: return .bold
            case .heavy: return .heavy
            }
        }
    }

    static let isAvailable: Bool = UIFont(name: Weight.regular.rawValue, size: 12) != nil

    static func font(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        if isAvailable {
            return .custom(weight.rawValue, size: size, relativeTo: style)
        }
        return .system(size: size, weight: weight.systemWeight, design: .rounded)
    }
}

extension Font {
    static let fitnaDisplay = FitnaFont.font(34, .heavy, relativeTo: .largeTitle)
    static let fitnaTitle = FitnaFont.font(26, .heavy, relativeTo: .title)
    static let fitnaTitle2 = FitnaFont.font(21, .bold, relativeTo: .title2)
    static let fitnaHeadline = FitnaFont.font(17, .bold, relativeTo: .headline)
    static let fitnaBody = FitnaFont.font(16, .regular, relativeTo: .body)
    static let fitnaBodyMedium = FitnaFont.font(16, .medium, relativeTo: .body)
    static let fitnaCallout = FitnaFont.font(15, .medium, relativeTo: .callout)
    static let fitnaCaption = FitnaFont.font(13, .medium, relativeTo: .caption)
    static let fitnaCaptionBold = FitnaFont.font(13, .bold, relativeTo: .caption)
    /// Numbers in games: rounded system font with monospaced digits for stable layouts.
    static func fitnaNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

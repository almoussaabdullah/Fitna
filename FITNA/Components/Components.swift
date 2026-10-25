import SwiftUI

// MARK: - Card

struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.padding
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.06), radius: 14, x: 0, y: 6)
            )
    }
}

extension View {
    func fitnaCard(padding: CGFloat = Theme.padding) -> some View { modifier(CardBackground(padding: padding)) }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.heroGradient)
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.fitnaHeadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
            .shadow(color: Theme.purple.opacity(configuration.isPressed ? 0.1 : 0.28), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.fitnaHeadline)
            .foregroundStyle(Theme.purple)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.purpleSoft))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Generic pressable style for tappable game tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.fitnaTitle2).foregroundStyle(Theme.ink)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.fitnaCallout)
                    .foregroundStyle(Theme.purple)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.purple
    var track: Color = Theme.hairline

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: fraction)
        }
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let fraction: Double
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.heroGradient)
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * max(0, min(1, fraction))))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: fraction)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    var tint: Color = Theme.purple

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.13)))
            Text(value)
                .font(.fitnaNumber(22))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.fitnaCaption)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitnaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chip

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Theme.purple

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.fitnaCaptionBold)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Icon badge

struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.3), radius: 8, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.purple.opacity(0.7))
            Text(title).font(.fitnaHeadline).foregroundStyle(Theme.ink)
            Text(message)
                .font(.fitnaCallout)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .fitnaCard()
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.15))
            Image(systemName: symbol)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

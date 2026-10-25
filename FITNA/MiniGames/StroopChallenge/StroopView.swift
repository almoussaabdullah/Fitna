import SwiftUI
import FitnaKit

extension StroopEngine.InkColor {
    /// Ink colors chosen to stay distinguishable and readable on white.
    var swiftUIColor: Color {
        switch self {
        case .red: return Color(hex: 0xE5484D)
        case .blue: return Color(hex: 0x2F6FED)
        case .green: return Color(hex: 0x1E9E5A)
        case .yellow: return Color(hex: 0xD9A400)
        case .purple: return Color(hex: 0x8B5CF6)
        case .orange: return Color(hex: 0xF07316)
        }
    }

    var name: String { L(nameKey) }
}

struct StroopView: View {
    let model: StroopViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(L("stroop.instruction"))
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
                VStack(spacing: 14) {
                    Text(model.stimulus.word.name)
                        .font(FitnaFont.font(64, .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(model.stimulus.ink.swiftUIColor)
                        .id(model.stimulusCount)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .accessibilityLabel(L("stroop.a11y.stimulus", model.stimulus.word.name, model.stimulus.ink.name))
                    TimelineView(.animation) { _ in
                        ProgressBar(fraction: model.stimulusFraction, tint: AnyShapeStyle(Theme.inkTertiary), height: 4)
                    }
                    .frame(width: 140)
                }
                VStack {
                    HStack {
                        if model.streak >= 3 {
                            Chip(text: L("stroop.streak", String(model.streak)), symbol: "flame.fill", tint: Theme.orange)
                                .padding(12)
                        }
                        Spacer()
                        FlashBadge(flash: model.flash).padding(12)
                    }
                    Spacer()
                }
            }
            .frame(height: 220)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: model.stimulusCount)
            .animation(.easeOut(duration: 0.15), value: model.flash)

            Spacer(minLength: 0)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(model.stimulus.choices, id: \.self) { color in
                    Button { model.answer(color) } label: {
                        HStack(spacing: 10) {
                            Circle().fill(color.swiftUIColor).frame(width: 22, height: 22)
                            Text(color.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
                            .shadow(color: Theme.ink.opacity(0.06), radius: 4, y: 2))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(color.name)
                }
            }
        }
    }
}

import SwiftUI
import FitnaKit

struct OnboardingView: View {
    enum Choice { case assessment, games, skip }

    let onFinish: (Choice) -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < 3 {
                        Button(L("onb.skip")) { onFinish(.skip) }
                            .font(.fitnaCallout)
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(minHeight: Theme.minTouch)
                    }
                }
                .padding(.horizontal, Theme.padding)

                TabView(selection: $page) {
                    welcome.tag(0)
                    skills.tag(1)
                    daily.tag(2)
                    ready.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut, value: page)

                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Theme.purple : Theme.hairline)
                            .frame(width: i == page ? 24 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.3), value: page)
                .padding(.bottom, 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("onb.a11y.page", String(page + 1), "4"))

                if page < 3 {
                    Button(L("onb.next")) { withAnimation { page += 1 } }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, Theme.padding)
                        .padding(.bottom, 24)
                } else {
                    VStack(spacing: 10) {
                        Button { onFinish(.assessment) } label: { Label(L("onb.startTest"), systemImage: "brain.head.profile") }
                            .buttonStyle(PrimaryButtonStyle())
                        Button { onFinish(.games) } label: { Label(L("onb.explore"), systemImage: "square.grid.2x2.fill") }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal, Theme.padding)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func onboardingPage<Extra: View>(symbol: String, gradient: LinearGradient, title: String, subtitle: String, @ViewBuilder extra: () -> Extra) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(gradient).frame(width: 170, height: 170)
                        .shadow(color: Theme.purple.opacity(0.25), radius: 24, y: 12)
                    Image(systemName: symbol)
                        .font(.system(size: 74, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 30)
                .accessibilityHidden(true)
                Text(title)
                    .font(.fitnaDisplay)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.fitnaBody)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                extra()
            }
            .padding(.horizontal, Theme.padding)
        }
    }

    private var welcome: some View {
        onboardingPage(symbol: "brain", gradient: Theme.heroGradient, title: L("onb.1.title"), subtitle: L("onb.1.subtitle")) {
            Text(L("app.tagline"))
                .font(.fitnaHeadline)
                .foregroundStyle(Theme.purple)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Theme.purpleSoft))
        }
    }

    private var skills: some View {
        onboardingPage(symbol: "sparkles", gradient: Theme.turquoiseGradient, title: L("onb.2.title"), subtitle: L("onb.2.subtitle")) {
            VStack(spacing: 10) {
                ForEach(CognitiveSkill.allCases) { skill in
                    HStack(spacing: 12) {
                        IconBadge(symbol: skill.symbol, tint: skill.color, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                            Text(skill.detail).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                    }
                    .fitnaCard(padding: 12)
                }
            }
        }
    }

    private var daily: some View {
        onboardingPage(symbol: "timer", gradient: Theme.orangeGradient, title: L("onb.3.title"), subtitle: L("onb.3.subtitle")) {
            HStack(spacing: 10) {
                Chip(text: L("onb.3.chip1"), symbol: "5.circle.fill", tint: Theme.purple)
                Chip(text: L("onb.3.chip2"), symbol: "flame.fill", tint: Theme.orange)
                Chip(text: L("onb.3.chip3"), symbol: "chart.line.uptrend.xyaxis", tint: Theme.turquoise)
            }
        }
    }

    private var ready: some View {
        onboardingPage(symbol: "flag.checkered", gradient: Theme.heroGradient, title: L("onb.4.title"), subtitle: L("onb.4.subtitle")) {
            EmptyView()
        }
    }
}
